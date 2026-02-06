//
//  VoiceAssistantPanel.swift
//  ZoeSleep
//
//  Floating voice assistant panel that overlays on the original questionnaire
//  Provides continuous listening with real-time transcription and answer extraction
//

import SwiftUI

/// Floating voice assistant panel for Easy Mode
/// Overlays on the questionnaire without replacing the original UI
struct VoiceAssistantPanel: View {
    /// Current question being answered
    let currentQuestion: Question?
    /// Callback when a voice answer is confirmed
    let onAnswerConfirmed: (Any) -> Void
    /// Callback to advance to next question
    let onNextQuestion: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var audioManager = AudioSessionManager.shared
    @StateObject private var voiceProcessor = ContinuousVoiceProcessor()

    @State private var isExpanded = false
    @State private var isListening = false
    @State private var errorMessage: String?

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Main panel
            VStack(spacing: Spacing.sm) {
                // Header with toggle
                panelHeader

                if isExpanded {
                    // Transcript area
                    transcriptArea

                    // Detected answer (if any)
                    if let detected = voiceProcessor.detectedAnswer {
                        detectedAnswerView(detected)
                    }

                    // Status and controls
                    controlsArea
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: isExpanded ? CornerRadius.large : CornerRadius.extraLarge)
                    .fill(theme.cardBackground)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -4)
            )
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)
        }
        .animation(.spring(response: 0.3), value: isExpanded)
        .animation(.spring(response: 0.3), value: voiceProcessor.detectedAnswer != nil)
        .onAppear {
            voiceProcessor.setCurrentQuestion(currentQuestion)
        }
        .onChange(of: currentQuestion?.id) { _, _ in
            voiceProcessor.setCurrentQuestion(currentQuestion)
        }
    }

    // MARK: - Panel Header

    private var panelHeader: some View {
        HStack {
            // Mic button / status
            Button(action: toggleListening) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isListening ? theme.accent : theme.primaryText)

                    if isExpanded {
                        Text(isListening ? "Listening..." : "Tap to speak")
                            .font(.system(size: Typography.subheadline, weight: .medium))
                            .foregroundColor(isListening ? theme.accent : theme.secondaryText)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(isListening ? theme.accent.opacity(0.15) : theme.primaryText.opacity(0.05))
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Stop button (when listening)
            if isListening {
                Button(action: manualStop) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Done")
                            .font(.system(size: Typography.subheadline, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(theme.success)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            // Expand/collapse button
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
                    .padding(Spacing.sm)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Transcript Area

    private var transcriptArea: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("I heard:")
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                if voiceProcessor.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Transcribing...")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(theme.accent)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(theme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(theme.error.opacity(0.1))
                    )
            } else {
                Text(voiceProcessor.currentTranscript.isEmpty ? "Tap mic, speak, then tap 'Done'" : voiceProcessor.currentTranscript)
                    .font(.system(size: Typography.body, weight: .regular, design: .rounded))
                    .foregroundColor(voiceProcessor.currentTranscript.isEmpty ? theme.secondaryText.opacity(0.5) : theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(theme.primaryText.opacity(0.03))
                    )
            }
        }
    }

    // MARK: - Detected Answer View

    @ViewBuilder
    private func detectedAnswerView(_ answer: DetectedAnswer) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(theme.accent)
                Text("Detected answer:")
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(theme.secondaryText)
                Spacer()
            }

            HStack(spacing: Spacing.md) {
                // Show the detected value
                Text(answer.displayValue)
                    .font(.system(size: Typography.headline, weight: .bold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                // Confirm button
                Button(action: {
                    confirmAnswer(answer)
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark")
                        Text("Use this")
                    }
                    .font(.system(size: Typography.subheadline, weight: .semibold))
                    .foregroundColor(theme.textOnPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(theme.success)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(theme.success.opacity(0.1))
            )
        }
    }

    // MARK: - Controls Area

    private var controlsArea: some View {
        HStack {
            // Audio level indicator when listening
            if isListening {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.accent)
                            .frame(width: 4, height: CGFloat(8 + (audioManager.audioLevel * 20 * Float((i % 3) + 1))))
                            .animation(.easeInOut(duration: 0.08), value: audioManager.audioLevel)
                    }
                }
                .frame(height: 30)
            }

            Spacer()

            // Clear transcript button
            if !voiceProcessor.currentTranscript.isEmpty {
                Button(action: {
                    voiceProcessor.clearTranscript()
                }) {
                    Text("Clear")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Actions

    private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    private func startListening() {
        // Expand panel when starting to listen
        if !isExpanded {
            isExpanded = true
        }

        Task {
            do {
                // Request mic permission if needed
                if audioManager.hasMicrophonePermission != true {
                    let granted = await audioManager.requestMicrophonePermission()
                    if !granted {
                        print("VoiceAssistantPanel: Mic permission denied")
                        return
                    }
                }

                try await voiceProcessor.startListening()
                await MainActor.run {
                    isListening = true
                }
            } catch {
                print("VoiceAssistantPanel: Failed to start listening: \(error)")
            }
        }
    }

    private func stopListening() {
        voiceProcessor.stopListening()
        isListening = false
    }

    private func manualStop() {
        print("VoiceAssistantPanel: Manual stop triggered")
        errorMessage = nil

        Task {
            do {
                try await voiceProcessor.stopAndTranscribe()
                await MainActor.run {
                    isListening = false
                }
            } catch {
                print("VoiceAssistantPanel: Manual stop error: \(error)")
                await MainActor.run {
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                    isListening = false
                }
            }
        }
    }

    private func confirmAnswer(_ answer: DetectedAnswer) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Pass the answer to the questionnaire
        onAnswerConfirmed(answer.value)

        // Clear the detected answer
        voiceProcessor.clearDetectedAnswer()

        // Optionally advance to next question
        // onNextQuestion()
    }
}

// MARK: - Detected Answer Model

struct DetectedAnswer: Equatable {
    let value: Any
    let displayValue: String
    let confidence: Double

    static func == (lhs: DetectedAnswer, rhs: DetectedAnswer) -> Bool {
        lhs.displayValue == rhs.displayValue && lhs.confidence == rhs.confidence
    }
}

// MARK: - Continuous Voice Processor

/// Handles continuous voice transcription and answer extraction
class ContinuousVoiceProcessor: ObservableObject {
    @Published var currentTranscript: String = ""
    @Published var detectedAnswer: DetectedAnswer?
    @Published var isProcessing: Bool = false

    private var currentQuestion: Question?
    private let audioManager = AudioSessionManager.shared
    private var transcriptionTask: Task<Void, Never>?

    func setCurrentQuestion(_ question: Question?) {
        currentQuestion = question
        // Re-analyze transcript if we have one
        if !currentTranscript.isEmpty {
            analyzeTranscript()
        }
    }

    func startListening() async throws {
        // Start recording
        try await audioManager.startRecording()

        // Set up silence detection for chunked transcription
        audioManager.onSilenceDetected = { [weak self] in
            self?.processCurrentAudio()
        }
    }

    func stopListening() {
        // Stop recording and process final audio
        if let audioData = audioManager.stopRecording() {
            transcribeAndAnalyze(audioData)
        }
        audioManager.onSilenceDetected = nil
    }

    /// Stop recording and transcribe with better error handling
    func stopAndTranscribe() async throws {
        audioManager.onSilenceDetected = nil

        guard let audioData = audioManager.stopRecording() else {
            throw VoiceError.noAudioRecorded
        }

        print("ContinuousVoiceProcessor: Got audio data: \(audioData.count) bytes")

        if audioData.count < 1000 {
            throw VoiceError.audioTooShort
        }

        await MainActor.run {
            isProcessing = true
        }

        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        // Call Convex to transcribe
        let base64Audio = audioData.base64EncodedString()
        print("ContinuousVoiceProcessor: Sending \(base64Audio.count) base64 chars to Convex")

        let transcript = try await ConvexService.shared.callVoiceTranscribe(audioBase64: base64Audio)

        print("ContinuousVoiceProcessor: Got transcript: \(transcript)")

        await MainActor.run {
            if currentTranscript.isEmpty {
                currentTranscript = transcript
            } else {
                currentTranscript += " " + transcript
            }
            analyzeTranscript()
        }
    }

    func clearTranscript() {
        currentTranscript = ""
        detectedAnswer = nil
    }

    func clearDetectedAnswer() {
        detectedAnswer = nil
    }

    private func processCurrentAudio() {
        // Get current audio data without stopping
        // For now, we'll process on silence detection
        if let audioData = audioManager.stopRecording() {
            transcribeAndAnalyze(audioData)

            // Restart recording for continuous listening
            Task {
                try? await audioManager.startRecording()
            }
        }
    }

    private func transcribeAndAnalyze(_ audioData: Data) {
        transcriptionTask?.cancel()

        transcriptionTask = Task {
            await MainActor.run {
                isProcessing = true
            }

            do {
                // Call Convex to transcribe
                let base64Audio = audioData.base64EncodedString()
                let transcript = try await ConvexService.shared.callVoiceTranscribe(audioBase64: base64Audio)

                await MainActor.run {
                    // Append to current transcript
                    if currentTranscript.isEmpty {
                        currentTranscript = transcript
                    } else {
                        currentTranscript += " " + transcript
                    }
                    isProcessing = false

                    // Analyze for answer
                    analyzeTranscript()
                }
            } catch {
                print("ContinuousVoiceProcessor: Transcription error: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }

    private func analyzeTranscript() {
        guard let question = currentQuestion, !currentTranscript.isEmpty else { return }

        // Parse the transcript based on question type
        let parsed = parseForAnswer(currentTranscript, question: question)
        if let answer = parsed {
            detectedAnswer = answer
        }
    }

    /// Parse transcript to extract an answer based on question type
    private func parseForAnswer(_ transcript: String, question: Question) -> DetectedAnswer? {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch question.questionType {
        case .yesNo, .yesNoDontKnow:
            return parseYesNo(normalized, question: question)
        case .scale:
            return parseScale(normalized, question: question)
        case .number, .numberScroll:
            return parseNumber(normalized)
        case .time:
            return parseTime(normalized)
        case .singleSelect:
            return parseOptions(normalized, options: question.options ?? [])
        case .minutesScroll, .hoursMinutesScroll:
            return parseDuration(normalized)
        default:
            // For text and complex types, just use the transcript directly
            if !normalized.isEmpty {
                return DetectedAnswer(value: transcript, displayValue: transcript, confidence: 0.7)
            }
            return nil
        }
    }

    // MARK: - Parsing Helpers

    private func parseYesNo(_ text: String, question: Question) -> DetectedAnswer? {
        let yesPatterns = ["yes", "yeah", "yep", "uh huh", "sure", "correct", "that's right", "absolutely", "definitely"]
        let noPatterns = ["no", "nope", "nah", "not really", "negative", "i don't think so"]
        let dontKnowPatterns = ["i don't know", "don't know", "not sure", "unsure", "maybe", "i'm not sure"]

        if yesPatterns.contains(where: { text.contains($0) }) {
            return DetectedAnswer(value: "Yes", displayValue: "Yes", confidence: 0.9)
        }

        if noPatterns.contains(where: { text.contains($0) }) {
            return DetectedAnswer(value: "No", displayValue: "No", confidence: 0.9)
        }

        if question.questionType == .yesNoDontKnow && dontKnowPatterns.contains(where: { text.contains($0) }) {
            return DetectedAnswer(value: "Don't know", displayValue: "Don't know", confidence: 0.85)
        }

        return nil
    }

    private func parseScale(_ text: String, question: Question) -> DetectedAnswer? {
        let wordToNumber: [String: Int] = [
            "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
            "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
        ]

        // Check for word numbers
        for (word, value) in wordToNumber {
            if text.contains(word) {
                let min = question.scaleMin ?? 0
                let max = question.scaleMax ?? 10
                if value >= min && value <= max {
                    return DetectedAnswer(value: value, displayValue: "\(value)", confidence: 0.9)
                }
            }
        }

        // Check for digits
        let pattern = #"(\d+)"#
        if let match = text.range(of: pattern, options: .regularExpression),
           let value = Int(text[match]) {
            let min = question.scaleMin ?? 0
            let max = question.scaleMax ?? 10
            if value >= min && value <= max {
                return DetectedAnswer(value: value, displayValue: "\(value)", confidence: 0.9)
            }
        }

        return nil
    }

    private func parseNumber(_ text: String) -> DetectedAnswer? {
        let pattern = #"(\d+(?:\.\d+)?)"#
        if let match = text.range(of: pattern, options: .regularExpression),
           let value = Double(text[match]) {
            let displayValue = value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : String(format: "%.1f", value)
            return DetectedAnswer(value: value, displayValue: displayValue, confidence: 0.85)
        }
        return nil
    }

    private func parseTime(_ text: String) -> DetectedAnswer? {
        // Simple time patterns
        let patterns = [
            #"(\d{1,2}):(\d{2})\s*(am|pm|a\.m\.|p\.m\.)?"#,
            #"(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)"#,
            #"(\d{1,2})\s*o'?\s*clock"#
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let timeString = String(text[match])
                return DetectedAnswer(value: timeString, displayValue: timeString, confidence: 0.8)
            }
        }

        return nil
    }

    private func parseOptions(_ text: String, options: [String]) -> DetectedAnswer? {
        for option in options {
            let optionLower = option.lowercased()
            if text.contains(optionLower) {
                return DetectedAnswer(value: option, displayValue: option, confidence: 0.85)
            }
        }
        return nil
    }

    private func parseDuration(_ text: String) -> DetectedAnswer? {
        var totalMinutes = 0

        // Hours
        let hourPattern = #"(\d+)\s*(?:hours?|hrs?)"#
        if let match = text.range(of: hourPattern, options: [.regularExpression, .caseInsensitive]) {
            let hourStr = String(text[match])
            if let hours = Int(hourStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                totalMinutes += hours * 60
            }
        }

        // Minutes
        let minPattern = #"(\d+)\s*(?:minutes?|mins?)"#
        if let match = text.range(of: minPattern, options: [.regularExpression, .caseInsensitive]) {
            let minStr = String(text[match])
            if let mins = Int(minStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                totalMinutes += mins
            }
        }

        // Special cases
        if text.contains("half an hour") || text.contains("half hour") {
            totalMinutes += 30
        }
        if text.contains("quarter") && text.contains("hour") {
            totalMinutes += 15
        }

        if totalMinutes > 0 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            let displayValue = hours > 0 ? "\(hours)h \(mins)m" : "\(mins) min"
            return DetectedAnswer(value: totalMinutes, displayValue: displayValue, confidence: 0.85)
        }

        return nil
    }
}

// MARK: - Preview

#Preview("Voice Assistant Panel") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VoiceAssistantPanel(
            currentQuestion: Question(
                id: "test",
                text: "How would you rate your sleep?",
                pillar: .sleepQuality,
                tier: .core,
                questionType: .scale,
                estimatedMinutes: 0.5,
                required: true,
                options: nil,
                scaleMin: 1,
                scaleMax: 10,
                scaleMinLabel: "Very poor",
                scaleMaxLabel: "Excellent",
                minValue: nil, maxValue: nil, step: nil, unit: nil, defaultValue: nil,
                unitImperial: nil, defaultImperial: nil, helpText: nil, helpTextImperial: nil,
                isGateway: false, gatewayType: nil, gatewayThreshold: nil,
                conditionalLogic: nil, group: nil, repeatingFields: nil
            ),
            onAnswerConfirmed: { value in
                print("Answer confirmed: \(value)")
            },
            onNextQuestion: {
                print("Next question")
            }
        )
    }
}
