//
//  EasyModeManager.swift
//  ZoeSleep
//
//  Central manager for Easy Mode voice-first questionnaire interface
//  Coordinates audio recording, transcription, TTS, and response parsing
//

import Foundation
import Combine
import SwiftUI
import Network

/// Manages Easy Mode voice input, TTS playback, and response parsing
/// All API calls are proxied through Convex backend (no API keys on device)
class EasyModeManager: ObservableObject {
    static let shared = EasyModeManager()

    // MARK: - Published State

    @Published private(set) var voiceState: VoiceInputState = .idle
    @Published private(set) var retryState = VoiceRetryState()
    @Published private(set) var isOnline = true

    /// Currently playing TTS audio (for visual indicator)
    @Published private(set) var isSpeaking = false

    /// Last TTS error (for UI display)
    @Published private(set) var ttsError: String?

    /// Selected TTS voice
    @Published var selectedVoiceId: String = "rachel" {
        didSet {
            UserDefaults.standard.set(selectedVoiceId, forKey: "easyMode_selectedVoice")
        }
    }

    /// TTS playback speed (0.75 to 1.25)
    @Published var ttsSpeed: Double = 0.9 {
        didSet {
            UserDefaults.standard.set(ttsSpeed, forKey: "easyMode_ttsSpeed")
        }
    }

    /// Auto-read questions aloud
    @Published var autoReadEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(autoReadEnabled, forKey: "easyMode_autoRead")
        }
    }

    // MARK: - Dependencies

    private let audioManager = AudioSessionManager.shared
    private let networkMonitor = NWPathMonitor()
    private var networkQueue = DispatchQueue(label: "com.zoesleep.easymode.network")
    private var cancellables = Set<AnyCancellable>()

    // TTS audio cache (question text -> audio data)
    private var ttsCache = NSCache<NSString, NSData>()

    // MARK: - Initialization

    private init() {
        loadSettings()
        setupNetworkMonitoring()
        setupAudioStateObservation()
    }

    private func loadSettings() {
        if let voice = UserDefaults.standard.string(forKey: "easyMode_selectedVoice") {
            selectedVoiceId = voice
        }

        let speed = UserDefaults.standard.double(forKey: "easyMode_ttsSpeed")
        if speed > 0 {
            ttsSpeed = speed
        }

        if UserDefaults.standard.object(forKey: "easyMode_autoRead") != nil {
            autoReadEnabled = UserDefaults.standard.bool(forKey: "easyMode_autoRead")
        }
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func setupAudioStateObservation() {
        // Observe audio manager's playing state
        audioManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isSpeaking = isPlaying
            }
            .store(in: &cancellables)
    }

    // MARK: - Voice Recording

    /// Start recording voice input
    func startRecording() async throws {
        guard isOnline else {
            await MainActor.run {
                voiceState = .error(.networkError)
            }
            return
        }

        // Request permission if needed
        if audioManager.hasMicrophonePermission != true {
            let granted = await audioManager.requestMicrophonePermission()
            if !granted {
                await MainActor.run {
                    voiceState = .error(.microphonePermissionDenied)
                }
                return
            }
        }

        // Stop any TTS playback
        audioManager.stopPlayback()

        await MainActor.run {
            voiceState = .listening
        }

        try await audioManager.startRecording()
    }

    /// Stop recording and process the audio
    /// - Parameter question: The current question for context in parsing
    func stopRecordingAndProcess(for question: Question) async {
        guard let audioData = audioManager.stopRecording() else {
            await MainActor.run {
                voiceState = .error(.noAudioRecorded)
            }
            return
        }

        await MainActor.run {
            voiceState = .processing
        }

        do {
            // Step 1: Transcribe via Convex -> Whisper
            let transcript = try await transcribeAudio(audioData)

            // Step 2: Parse transcript based on question type
            await MainActor.run {
                voiceState = .parsing
            }

            let parsedResponse = try await parseTranscript(transcript, for: question)

            // Step 3: Show confirmation
            await MainActor.run {
                voiceState = .confirming(parsedResponse)
                retryState.reset()
            }

        } catch let error as VoiceError {
            await MainActor.run {
                voiceState = .error(error)
                retryState.recordAttempt()
            }
        } catch {
            await MainActor.run {
                voiceState = .error(.transcriptionFailed(error.localizedDescription))
                retryState.recordAttempt()
            }
        }
    }

    /// Cancel current recording
    func cancelRecording() {
        audioManager.cancelRecording()
        voiceState = .idle
    }

    /// Confirm the parsed response
    func confirmResponse() -> ParsedValue? {
        guard case .confirming(let response) = voiceState else {
            return nil
        }
        voiceState = .idle
        return response.value
    }

    /// Retry voice input
    func retry() {
        voiceState = .idle
    }

    /// Reset to idle state
    func reset() {
        cancelRecording()
        audioManager.stopPlayback()
        voiceState = .idle
        retryState.reset()
    }

    // MARK: - Transcription (via Convex)

    private func transcribeAudio(_ audioData: Data) async throws -> String {
        // Call Convex function: voice.transcribe
        // This proxies to OpenAI Whisper API

        let base64Audio = audioData.base64EncodedString()
        print("EasyModeManager: Transcribing audio (\(audioData.count) bytes)...")

        // Use ConvexService to call the voice.transcribe function
        let result = try await ConvexService.shared.callVoiceTranscribe(audioBase64: base64Audio)
        print("EasyModeManager: Transcription result: \(result.prefix(100))...")

        return result
    }

    // MARK: - Response Parsing

    private func parseTranscript(_ transcript: String, for question: Question) async throws -> ParsedResponse {
        let strategy = ParsingStrategy.forQuestionType(question.questionType.rawValue)

        switch strategy {
        case .keywordMatch:
            return parseKeywords(transcript, for: question)

        case .numberExtraction:
            return parseNumber(transcript, for: question)

        case .timeExtraction:
            return try await parseTime(transcript, for: question)

        case .durationExtraction:
            return parseDuration(transcript, for: question)

        case .optionMatching:
            return parseOptions(transcript, for: question)

        case .llmFull:
            // Complex parsing via Convex -> Claude/GPT
            return try await parseLLM(transcript, for: question)

        case .directTranscript:
            return ParsedResponse(
                transcript: transcript,
                value: .string(transcript),
                confidence: 1.0,
                alternativeInterpretations: nil
            )

        case .energyLevelParsing:
            if let parsed = CheckInLevelParser.parse(transcript: transcript, for: .energy) {
                return ParsedResponse(transcript: transcript, value: parsed, confidence: 0.9, alternativeInterpretations: nil)
            }
            return try await parseLLM(transcript, for: question)

        case .moodLevelParsing:
            if let parsed = CheckInLevelParser.parse(transcript: transcript, for: .mood) {
                return ParsedResponse(transcript: transcript, value: parsed, confidence: 0.9, alternativeInterpretations: nil)
            }
            return try await parseLLM(transcript, for: question)

        case .focusLevelParsing:
            if let parsed = CheckInLevelParser.parse(transcript: transcript, for: .focus) {
                return ParsedResponse(transcript: transcript, value: parsed, confidence: 0.9, alternativeInterpretations: nil)
            }
            return try await parseLLM(transcript, for: question)
        }
    }

    // MARK: - Simple Parsing Strategies

    private func parseKeywords(_ transcript: String, for question: Question) -> ParsedResponse {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Yes patterns
        let yesPatterns = ["yes", "yeah", "yep", "uh huh", "sure", "correct", "that's right", "affirmative", "absolutely"]
        // No patterns
        let noPatterns = ["no", "nope", "nah", "not really", "negative", "i don't think so"]
        // Don't know patterns
        let dontKnowPatterns = ["i don't know", "don't know", "not sure", "unsure", "maybe", "i'm not sure"]

        if yesPatterns.contains(where: { normalized.contains($0) }) {
            return ParsedResponse(
                transcript: transcript,
                value: .boolean(true),
                confidence: 0.95,
                alternativeInterpretations: nil
            )
        }

        if noPatterns.contains(where: { normalized.contains($0) }) {
            return ParsedResponse(
                transcript: transcript,
                value: .boolean(false),
                confidence: 0.95,
                alternativeInterpretations: nil
            )
        }

        if question.questionType == .yesNoDontKnow && dontKnowPatterns.contains(where: { normalized.contains($0) }) {
            return ParsedResponse(
                transcript: transcript,
                value: .string("Don't know"),
                confidence: 0.9,
                alternativeInterpretations: nil
            )
        }

        // Low confidence - couldn't clearly match
        return ParsedResponse(
            transcript: transcript,
            value: .string(transcript),
            confidence: 0.3,
            alternativeInterpretations: ["Yes", "No"]
        )
    }

    private func parseNumber(_ transcript: String, for question: Question) -> ParsedResponse {
        let normalized = transcript.lowercased()

        // Map word numbers to digits
        let wordToNumber: [String: Double] = [
            "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
            "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
        ]

        // Try to find a number
        var number: Double?

        // Check for word numbers first
        for (word, value) in wordToNumber {
            if normalized.contains(word) {
                number = value
                break
            }
        }

        // Try regex for digits
        if number == nil {
            let pattern = #"(\d+(?:\.\d+)?)"#
            if let match = normalized.range(of: pattern, options: .regularExpression),
               let value = Double(normalized[match]) {
                number = value
            }
        }

        if let num = number {
            // Validate against question bounds
            let min = Double(question.scaleMin ?? question.minValue ?? 0)
            let max = Double(question.scaleMax ?? question.maxValue ?? 100)
            let clampedNum = Swift.min(Swift.max(num, min), max)

            return ParsedResponse(
                transcript: transcript,
                value: .number(clampedNum),
                confidence: num == clampedNum ? 0.95 : 0.7,  // Lower confidence if clamped
                alternativeInterpretations: nil
            )
        }

        return ParsedResponse(
            transcript: transcript,
            value: .unknown,
            confidence: 0.2,
            alternativeInterpretations: nil
        )
    }

    private func parseTime(_ transcript: String, for question: Question) async throws -> ParsedResponse {
        // For time parsing, use LLM for better accuracy
        return try await parseLLM(transcript, for: question)
    }

    private func parseDuration(_ transcript: String, for question: Question) -> ParsedResponse {
        let normalized = transcript.lowercased()

        var totalMinutes = 0
        let confidence: Double = 0.9

        // Parse hours
        let hourPatterns = [
            #"(\d+)\s*(?:hours?|hrs?)"#,
            #"(\w+)\s*(?:hours?|hrs?)"#
        ]

        for pattern in hourPatterns {
            if let match = normalized.range(of: pattern, options: .regularExpression) {
                let matchStr = String(normalized[match])
                if let hourNum = extractNumber(from: matchStr) {
                    totalMinutes += hourNum * 60
                }
            }
        }

        // Parse minutes
        let minPatterns = [
            #"(\d+)\s*(?:minutes?|mins?)"#,
            #"(\w+)\s*(?:minutes?|mins?)"#
        ]

        for pattern in minPatterns {
            if let match = normalized.range(of: pattern, options: .regularExpression) {
                let matchStr = String(normalized[match])
                if let minNum = extractNumber(from: matchStr) {
                    totalMinutes += minNum
                }
            }
        }

        // Handle "half an hour", "quarter hour"
        if normalized.contains("half an hour") || normalized.contains("half hour") {
            totalMinutes += 30
        }
        if normalized.contains("quarter") && normalized.contains("hour") {
            totalMinutes += 15
        }

        if totalMinutes > 0 {
            return ParsedResponse(
                transcript: transcript,
                value: .duration(minutes: totalMinutes),
                confidence: confidence,
                alternativeInterpretations: nil
            )
        }

        return ParsedResponse(
            transcript: transcript,
            value: .unknown,
            confidence: 0.2,
            alternativeInterpretations: nil
        )
    }

    private func extractNumber(from text: String) -> Int? {
        let wordToNumber: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40,
            "forty-five": 45, "forty five": 45, "sixty": 60, "ninety": 90
        ]

        let normalized = text.lowercased()

        for (word, value) in wordToNumber {
            if normalized.contains(word) {
                return value
            }
        }

        // Try regex for digits
        let pattern = #"(\d+)"#
        if let match = normalized.range(of: pattern, options: .regularExpression),
           let value = Int(normalized[match]) {
            return value
        }

        return nil
    }

    private func parseOptions(_ transcript: String, for question: Question) -> ParsedResponse {
        guard let options = question.options else {
            return ParsedResponse(
                transcript: transcript,
                value: .string(transcript),
                confidence: 0.5,
                alternativeInterpretations: nil
            )
        }

        let normalized = transcript.lowercased()
        var matches: [(option: String, score: Double)] = []

        for option in options {
            let optionLower = option.lowercased()

            // Exact match
            if normalized == optionLower || normalized.contains(optionLower) {
                matches.append((option, 1.0))
                continue
            }

            // Partial match - check if words overlap
            let transcriptWords = Set(normalized.components(separatedBy: .whitespaces))
            let optionWords = Set(optionLower.components(separatedBy: .whitespaces))
            let overlap = transcriptWords.intersection(optionWords)

            if !overlap.isEmpty {
                let score = Double(overlap.count) / Double(optionWords.count)
                if score > 0.5 {
                    matches.append((option, score))
                }
            }
        }

        // Sort by score
        matches.sort { $0.score > $1.score }

        if let bestMatch = matches.first, bestMatch.score >= 0.7 {
            let isMultiSelect = question.questionType == .multiSelect

            if isMultiSelect && matches.count > 1 {
                // Return all high-confidence matches for multi-select
                let goodMatches = matches.filter { $0.score >= 0.7 }
                return ParsedResponse(
                    transcript: transcript,
                    value: .array(goodMatches.map { $0.option }),
                    confidence: goodMatches.map { $0.score }.reduce(0, +) / Double(goodMatches.count),
                    alternativeInterpretations: nil
                )
            } else {
                return ParsedResponse(
                    transcript: transcript,
                    value: .string(bestMatch.option),
                    confidence: bestMatch.score,
                    alternativeInterpretations: matches.dropFirst().prefix(2).map { $0.option }
                )
            }
        }

        return ParsedResponse(
            transcript: transcript,
            value: .unknown,
            confidence: 0.2,
            alternativeInterpretations: options.prefix(3).map { $0 }
        )
    }

    // MARK: - LLM Parsing (via Convex)

    private func parseLLM(_ transcript: String, for question: Question) async throws -> ParsedResponse {
        // Call Convex function: voice.parseResponse
        // This proxies to Claude or GPT for complex parsing

        let context = VoiceParsingContext(
            questionId: question.id,
            questionText: question.text,
            questionType: question.questionType.rawValue,
            options: question.options,
            minValue: question.scaleMin ?? question.minValue,
            maxValue: question.scaleMax ?? question.maxValue
        )

        let result = try await ConvexService.shared.callVoiceParseResponse(
            transcript: transcript,
            context: context
        )

        return result
    }

    // MARK: - Text-to-Speech

    /// Speak the question text using ElevenLabs TTS
    /// - Returns: true if TTS started successfully, false if skipped or failed
    @discardableResult
    func speakQuestion(_ text: String) async -> Bool {
        guard autoReadEnabled else {
            print("EasyModeManager: TTS disabled (autoReadEnabled=false)")
            return false
        }
        guard isOnline else {
            print("EasyModeManager: TTS skipped (offline)")
            await MainActor.run {
                self.ttsError = "No internet connection"
            }
            return false
        }

        print("EasyModeManager: Speaking text: \(text.prefix(50))...")

        // Check cache first
        let cacheKey = "\(selectedVoiceId)_\(ttsSpeed)_\(text)" as NSString
        if let cachedData = ttsCache.object(forKey: cacheKey) {
            do {
                try await audioManager.playAudio(data: cachedData as Data)
                print("EasyModeManager: Playing cached TTS audio")
                return true
            } catch {
                print("EasyModeManager: Failed to play cached TTS: \(error)")
            }
        }

        // Request TTS from Convex -> ElevenLabs
        do {
            print("EasyModeManager: Calling Convex voice:synthesize...")
            let audioData = try await ConvexService.shared.callVoiceSynthesize(
                text: text,
                voiceId: selectedVoiceId,
                speed: ttsSpeed
            )

            print("EasyModeManager: TTS returned \(audioData.count) bytes")

            // Verify audio data is valid
            guard audioData.count > 100 else {
                print("EasyModeManager: TTS returned invalid/empty audio data")
                await MainActor.run {
                    self.ttsError = "Invalid audio received"
                }
                return false
            }

            // Cache the audio
            ttsCache.setObject(audioData as NSData, forKey: cacheKey)

            // Play the audio
            try await audioManager.playAudio(data: audioData)
            return true

        } catch {
            print("EasyModeManager: TTS FAILED: \(error)")
            await MainActor.run {
                self.ttsError = "Voice not available: \(error.localizedDescription)"
            }
            return false
        }
    }

    /// Stop any currently playing TTS
    func stopSpeaking() {
        audioManager.stopPlayback()
    }

    /// Wait for TTS to complete before proceeding (with timeout)
    func waitForSpeechCompletion() async {
        await audioManager.waitForPlaybackCompletion(timeout: 30)
    }

    /// Speak text (convenience wrapper for speakQuestion)
    /// - Parameter text: The text to speak
    @discardableResult
    func speak(_ text: String) async -> Bool {
        return await speakQuestion(text)
    }

    /// Speak text with custom rate (for accessibility)
    /// - Parameters:
    ///   - text: The text to speak
    ///   - rate: Speech rate (0.5-1.0, currently uses default)
    @discardableResult
    func speak(_ text: String, rate: Float) async -> Bool {
        // For now, use default speed - rate parameter reserved for future use
        return await speakQuestion(text)
    }

    /// Simple stop recording without processing (for accessibility)
    func stopRecording() {
        _ = audioManager.stopRecording()
    }

    // MARK: - Hands-Free Mode

    /// Speak question and automatically start recording after TTS completes
    /// This creates a seamless hands-free experience for elderly users
    func speakAndAutoRecord(question: Question, onRecordingComplete: @escaping () -> Void) async {
        // Clear any previous TTS error
        await MainActor.run {
            ttsError = nil
        }

        // Build the text to read
        var textToRead = question.text

        // Add options for select questions (limit to first few to keep audio short)
        if let options = question.options, !options.isEmpty {
            let displayOptions = options.prefix(5)  // Only read first 5 options aloud
            let optionsText = displayOptions.joined(separator: ", or ")
            textToRead += ". Your options are: \(optionsText)"
            if options.count > 5 {
                textToRead += ", or others shown below"
            }
        }

        // Add scale description
        if question.questionType == .scale {
            if let minLabel = question.scaleMinLabel, let maxLabel = question.scaleMaxLabel {
                textToRead += ". On a scale of 1 to 10, where 1 means \(minLabel) and 10 means \(maxLabel)."
            }
        }

        print("EasyModeManager: speakAndAutoRecord starting for question: \(question.id)")

        // Speak the question (returns true if TTS started successfully)
        let ttsStarted = await speakQuestion(textToRead)

        if ttsStarted {
            // TTS started - wait for it to complete
            print("EasyModeManager: TTS started, waiting for completion...")
            await waitForSpeechCompletion()
            print("EasyModeManager: TTS complete")

            // Delay before recording (gives user time to prepare after hearing question)
            try? await Task.sleep(nanoseconds: 800_000_000)  // 0.8 seconds
        } else {
            // TTS failed - show error state and let user tap to speak manually
            print("EasyModeManager: TTS failed/skipped - user must tap to speak")
            // Don't auto-start recording if TTS failed - wait for user tap
            return
        }

        // Auto-start recording only if we successfully played TTS
        guard isOnline else {
            await MainActor.run {
                voiceState = .error(.networkError)
            }
            return
        }

        do {
            // Set up silence detection callback to auto-stop
            audioManager.onSilenceDetected = { [weak self] in
                guard let self = self else { return }
                Task {
                    await self.stopRecordingAndProcess(for: question)
                    await MainActor.run {
                        onRecordingComplete()
                    }
                }
            }

            try await startRecording()
            print("EasyModeManager: Recording started successfully")
        } catch {
            print("EasyModeManager: Failed to auto-start recording: \(error)")
            await MainActor.run {
                voiceState = .error(.microphonePermissionDenied)
            }
        }
    }

    /// Clear silence detection callback
    func clearAutoStopCallback() {
        audioManager.onSilenceDetected = nil
    }

    // MARK: - Cleanup

    deinit {
        networkMonitor.cancel()
    }
}

// MARK: - Parsing Context

/// Context for LLM parsing
struct VoiceParsingContext: Codable {
    let questionId: String
    let questionText: String
    let questionType: String
    let options: [String]?
    let minValue: Int?
    let maxValue: Int?
}
