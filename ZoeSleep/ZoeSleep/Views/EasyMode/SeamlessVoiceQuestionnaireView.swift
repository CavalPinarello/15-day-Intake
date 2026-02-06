//
//  SeamlessVoiceQuestionnaireView.swift
//  ZoeSleep
//
//  Full-screen seamless voice questionnaire with Zoe Orb
//  - Questions are spoken aloud via TTS
//  - Continuous listening with real-time transcript
//  - Auto-advance when answer is detected
//  - Hands-free experience
//

import SwiftUI
import Combine
import Speech
import AVFoundation

/// Full-screen seamless voice questionnaire
struct SeamlessVoiceQuestionnaireView: View {
    let questions: [Question]
    let sectionTitle: String
    let onComplete: ([String: Any]) -> Void
    let onDismiss: () -> Void

    @StateObject private var vm = SeamlessVoiceViewModel()
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var showingExitConfirmation = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            // Dark gradient background
            backgroundGradient

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, Spacing.md)

                // Question area
                questionArea
                    .padding(.top, Spacing.xl)

                Spacer()

                // Zoe Orb
                ZoeOrbView(
                    state: vm.orbState,
                    audioLevel: vm.audioLevel
                )
                .frame(height: 280)

                Spacer()

                // Transcript area
                transcriptArea
                    .padding(.horizontal, Spacing.lg)

                // Bottom hint
                bottomHint
                    .padding(.bottom, Spacing.xl)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            vm.configure(questions: questions)
            vm.start()
        }
        .onDisappear {
            vm.stop()
        }
        .onChange(of: vm.isComplete) { _, isComplete in
            if isComplete {
                onComplete(vm.collectedAnswers)
            }
        }
        .alert("End Voice Session?", isPresented: $showingExitConfirmation) {
            Button("Continue", role: .cancel) { }
            Button("End", role: .destructive) {
                vm.stop()
                onDismiss()
            }
        } message: {
            Text("Your progress will be saved.")
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.03, blue: 0.12),
                Color(red: 0.05, green: 0.07, blue: 0.18),
                Color(red: 0.04, green: 0.08, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Close button
            Button(action: { showingExitConfirmation = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            // Progress
            VStack(spacing: 4) {
                Text(sectionTitle)
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Text("\(vm.currentQuestionIndex + 1) of \(questions.count)")
                    .font(.system(size: Typography.subheadline, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))

                        Capsule()
                            .fill(theme.accent)
                            .frame(width: geo.size.width * vm.progress)
                    }
                }
                .frame(width: 100, height: 4)
            }

            Spacer()

            // Skip button
            Button(action: { vm.skipQuestion() }) {
                Text("Skip")
                    .font(.system(size: Typography.subheadline, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Question Area

    private var questionArea: some View {
        VStack(spacing: Spacing.md) {
            if let question = vm.currentQuestion {
                // Question text
                Text(question.text)
                    .font(.system(size: Typography.title3, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, Spacing.xl)
                    .id(question.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                // Options hint if applicable
                if let options = question.options, !options.isEmpty {
                    Text(options.joined(separator: " · "))
                        .font(.system(size: Typography.caption, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }

                // Scale hint
                if question.questionType == .scale {
                    let min = question.scaleMin ?? 1
                    let max = question.scaleMax ?? 10
                    HStack {
                        if let minLabel = question.scaleMinLabel {
                            Text("\(min): \(minLabel)")
                        }
                        Spacer()
                        if let maxLabel = question.scaleMaxLabel {
                            Text("\(max): \(maxLabel)")
                        }
                    }
                    .font(.system(size: Typography.caption, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, Spacing.xl)
                }
            }
        }
        .frame(minHeight: 120)
        .animation(.easeInOut(duration: 0.4), value: vm.currentQuestionIndex)
    }

    // MARK: - Transcript Area

    private var transcriptArea: some View {
        VStack(spacing: Spacing.sm) {
            // Status indicator with audio level
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(vm.statusColor)
                    .frame(width: 8, height: 8)

                Text(vm.statusText)
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                // Audio level meter (only when listening)
                if vm.isListening {
                    AudioLevelMeter(
                        level: vm.audioLevel,
                        hasDetectedSpeech: vm.hasDetectedSpeech,
                        timeoutProgress: vm.timeoutProgress
                    )
                }
            }

            // Transcript box
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // What you're saying
                if !vm.currentTranscript.isEmpty || vm.isListening {
                    Text(vm.currentTranscript.isEmpty ? "Listening..." : vm.currentTranscript)
                        .font(.system(size: Typography.body, weight: .regular))
                        .foregroundColor(vm.currentTranscript.isEmpty ? .white.opacity(0.3) : .white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeOut(duration: 0.1), value: vm.currentTranscript)
                }

                // Detected answer
                if let detected = vm.detectedAnswer {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)

                        Text("Got it: ")
                            .foregroundColor(.white.opacity(0.6))
                        +
                        Text(detected)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)

                        Spacer()

                        // Auto-advance countdown
                        if vm.autoAdvanceCountdown > 0 {
                            Text("(\(vm.autoAdvanceCountdown))")
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .font(.system(size: Typography.subheadline))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(Spacing.md)
            .frame(minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(vm.detectedAnswer != nil ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .animation(.easeInOut(duration: 0.2), value: vm.detectedAnswer)
    }

    // MARK: - Bottom Hint

    private var bottomHint: some View {
        VStack(spacing: Spacing.xs) {
            if vm.isSpeaking {
                Text("Zoe is speaking...")
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(theme.accent.opacity(0.8))
            } else if vm.isListening {
                if vm.hasDetectedSpeech {
                    Text("Listening... pause when done")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(.green.opacity(0.8))
                } else if vm.timeoutProgress > 0.5 {
                    Text("Speak louder or move closer to mic")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(.orange.opacity(0.8))
                } else {
                    Text("Just speak naturally")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                Text("Tap anywhere to continue")
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - View Model

@MainActor
class SeamlessVoiceViewModel: ObservableObject {
    // MARK: - Published State

    @Published var currentQuestionIndex = 0
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var currentTranscript = ""
    @Published var detectedAnswer: String?
    @Published var audioLevel: Float = 0.0
    @Published var isComplete = false
    @Published var autoAdvanceCountdown = 0
    @Published var hasDetectedSpeech = false
    @Published var timeoutProgress: Double = 0.0  // 0.0 to 1.0 for timeout indicator

    // MARK: - Data

    var collectedAnswers: [String: Any] = [:]
    private var questions: [Question] = []

    // MARK: - Native Speech Recognition

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var useNativeSpeechRecognition = true
    private var lastTranscriptUpdateTime: Date?
    private var silenceCheckTimer: Timer?

    // MARK: - Services

    private let audioManager = AudioSessionManager.shared
    private var listeningTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?
    private var speakTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    // Timeout configuration
    private let listeningTimeoutSeconds: Double = 10.0  // Auto-submit after 10 seconds if no speech detected
    private let maxListeningDurationSeconds: Double = 20.0  // Maximum total listening time before forcing processing
    private var listeningStartTime: Date?

    // MARK: - Computed

    var currentQuestion: Question? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex) / Double(questions.count)
    }

    var orbState: ZoeOrbState {
        if isSpeaking { return .speaking }
        if isListening { return .listening }
        if detectedAnswer != nil { return .thinking }
        return .idle
    }

    var statusText: String {
        if isSpeaking { return "Zoe is speaking" }
        if detectedAnswer != nil { return "Answer detected" }
        if isListening { return "Listening" }
        return "Ready"
    }

    var statusColor: Color {
        if isSpeaking { return .blue }
        if detectedAnswer != nil { return .green }
        if isListening { return .orange }
        return .gray
    }

    // MARK: - Setup

    func configure(questions: [Question]) {
        self.questions = questions
    }

    func start() {
        guard !questions.isEmpty else { return }
        speakCurrentQuestion()
    }

    func stop() {
        listeningTask?.cancel()
        autoAdvanceTask?.cancel()
        speakTask?.cancel()
        timeoutTask?.cancel()
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil
        audioManager.stopPlayback()
        _ = audioManager.stopRecording()

        // Clean up native speech recognition
        stopNativeRecognition()
        isListening = false
    }

    // MARK: - Question Flow

    private func speakCurrentQuestion() {
        guard let question = currentQuestion else {
            isComplete = true
            return
        }

        speakTask = Task {
            isSpeaking = true
            currentTranscript = ""
            detectedAnswer = nil

            do {
                // Get TTS audio
                let audioData = try await ConvexService.shared.callVoiceSynthesize(
                    text: question.text,
                    voiceId: "rachel",
                    speed: 1.0
                )

                // Play it
                try await audioManager.playAudio(data: audioData)

                // Wait for playback to finish
                await audioManager.waitForPlaybackCompletion(timeout: 30)

                await MainActor.run {
                    isSpeaking = false
                }

                // Small pause then start listening
                try await Task.sleep(nanoseconds: 500_000_000)

                await startListening()

            } catch {
                print("SeamlessVoice: TTS error: \(error)")
                await MainActor.run {
                    isSpeaking = false
                }
                // Start listening anyway even if TTS failed
                await startListening()
            }
        }
    }

    private func startListening() async {
        guard !Task.isCancelled else { return }

        print("SeamlessVoice: startListening() called - using native speech recognition")

        // Track when listening started (for max duration check)
        listeningStartTime = Date()

        // Reset speech detection state for new listening session
        await MainActor.run {
            hasDetectedSpeech = false
            timeoutProgress = 0.0
            currentTranscript = ""
        }

        // Check speech recognition authorization
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard authStatus == .authorized else {
            print("SeamlessVoice: Speech recognition not authorized, falling back to Whisper")
            useNativeSpeechRecognition = false
            await startWhisperListening()
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("SeamlessVoice: Speech recognizer unavailable, falling back to Whisper")
            useNativeSpeechRecognition = false
            await startWhisperListening()
            return
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("SeamlessVoice: Audio session error: \(error), falling back to Whisper")
            useNativeSpeechRecognition = false
            await startWhisperListening()
            return
        }

        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("SeamlessVoice: Could not create recognition request")
            await startWhisperListening()
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation

        // Configure audio engine input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap for audio capture
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level for visualization
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData?[i] ?? 0)
            }
            let avgLevel = sum / Float(frameLength)

            Task { @MainActor in
                self?.audioLevel = min(1.0, avgLevel * 10)

                // Track if speech detected
                if avgLevel > 0.02 && self?.hasDetectedSpeech == false {
                    self?.hasDetectedSpeech = true
                    self?.timeoutTask?.cancel()
                    print("SeamlessVoice: 🎤 Speech detected via native recognition")
                }
            }
        }

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.currentTranscript = transcript
                    self.lastTranscriptUpdateTime = Date()
                    self.hasDetectedSpeech = true

                    print("SeamlessVoice: 📝 Live transcript: \"\(transcript)\"")

                    // If final result, process it
                    if result.isFinal {
                        print("SeamlessVoice: ✅ Final transcript received")
                        self.stopNativeRecognition()
                        await self.processNativeTranscript(transcript)
                    }
                }

                if let error = error {
                    print("SeamlessVoice: Recognition error: \(error.localizedDescription)")
                    // Don't restart on error, just process what we have
                    if !self.currentTranscript.isEmpty {
                        self.stopNativeRecognition()
                        await self.processNativeTranscript(self.currentTranscript)
                    }
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()

            await MainActor.run {
                isListening = true
            }

            print("SeamlessVoice: ✅ Native speech recognition started")

            // Start silence detection timer
            startNativeSilenceDetection()

            // Start timeout for max duration
            startListeningTimeout()

        } catch {
            print("SeamlessVoice: Audio engine error: \(error)")
            await startWhisperListening()
        }
    }

    /// Fallback to Whisper-based listening (original implementation)
    private func startWhisperListening() async {
        print("SeamlessVoice: Using Whisper fallback")

        // Request mic permission if needed
        if audioManager.hasMicrophonePermission != true {
            let granted = await audioManager.requestMicrophonePermission()
            if !granted {
                print("SeamlessVoice: Mic permission denied")
                return
            }
        }

        do {
            audioManager.onSilenceDetected = { [weak self] in
                print("SeamlessVoice: >>> SILENCE DETECTED - processing audio <<<")
                Task { @MainActor in
                    self?.timeoutTask?.cancel()
                    await self?.processCurrentAudio()
                }
            }

            try await audioManager.startRecording()
            print("SeamlessVoice: Whisper recording started")

            await MainActor.run {
                isListening = true
            }

            startAudioLevelPolling()

        } catch {
            print("SeamlessVoice: Whisper recording error: \(error)")
        }
    }

    /// Start silence detection for native speech recognition
    private func startNativeSilenceDetection() {
        lastTranscriptUpdateTime = Date()

        silenceCheckTimer?.invalidate()
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isListening, self.useNativeSpeechRecognition else { return }

                // Check if 1.5 seconds of silence after speech
                if let lastUpdate = self.lastTranscriptUpdateTime,
                   Date().timeIntervalSince(lastUpdate) > 1.5,
                   self.hasDetectedSpeech,
                   !self.currentTranscript.isEmpty {
                    print("SeamlessVoice: 🔇 Silence detected after speech - processing transcript")
                    self.stopNativeRecognition()
                    await self.processNativeTranscript(self.currentTranscript)
                }

                // Check max duration
                if let startTime = self.listeningStartTime,
                   Date().timeIntervalSince(startTime) >= self.maxListeningDurationSeconds {
                    print("SeamlessVoice: ⏰ Max duration reached")
                    self.stopNativeRecognition()
                    if !self.currentTranscript.isEmpty {
                        await self.processNativeTranscript(self.currentTranscript)
                    } else {
                        await self.restartListening()
                    }
                }
            }
        }
    }

    /// Stop native speech recognition
    private func stopNativeRecognition() {
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        audioLevel = 0
    }

    /// Process transcript from native speech recognition
    private func processNativeTranscript(_ transcript: String) async {
        print("SeamlessVoice: Processing native transcript: \"\(transcript)\"")

        // Filter hallucinations (less common with native recognition, but still check)
        if isHallucination(transcript) {
            print("SeamlessVoice: ⚠️ Filtered potential hallucination")
            if isListening {
                await restartListening()
            }
            return
        }

        // Parse the answer
        await parseAnswerWithLLM()
    }

    private func startAudioLevelPolling() {
        let silenceThreshold: Float = 0.05
        var logCounter = 0

        // Start the timeout countdown (only active until speech is detected)
        startListeningTimeout()

        listeningTask = Task {
            while !Task.isCancelled && isListening {
                let currentLevel = audioManager.audioLevel

                await MainActor.run {
                    audioLevel = currentLevel

                    // Track if speech has been detected (level above threshold)
                    if currentLevel > silenceThreshold && !hasDetectedSpeech {
                        hasDetectedSpeech = true
                        print("SeamlessVoice: 🎤 Speech detected! Cancelling initial timeout.")
                        // Cancel the initial timeout - silence detection will now take over
                        timeoutTask?.cancel()
                        timeoutProgress = 0.0
                    }
                }

                // Check max listening duration (safety net if silence detection fails)
                if let startTime = listeningStartTime,
                   Date().timeIntervalSince(startTime) >= maxListeningDurationSeconds {
                    print("SeamlessVoice: ⏰ Max listening duration reached (\(maxListeningDurationSeconds)s) - forcing audio processing")
                    await processCurrentAudio()
                    break
                }

                // Log every 20 iterations (every 1 second)
                logCounter += 1
                if logCounter % 20 == 0 {
                    let elapsed = listeningStartTime.map { Date().timeIntervalSince($0) } ?? 0
                    let speechStatus = hasDetectedSpeech ? "✓ speech detected" : "waiting for speech..."
                    print("SeamlessVoice: Audio level: \(String(format: "%.3f", currentLevel)) (threshold: \(silenceThreshold)) - \(speechStatus) - \(String(format: "%.1f", elapsed))s elapsed")
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }

    /// Start a timeout that auto-processes audio if no speech is detected
    private func startListeningTimeout() {
        timeoutTask?.cancel()
        timeoutProgress = 0.0

        timeoutTask = Task {
            let startTime = Date()
            let checkInterval: UInt64 = 100_000_000 // 100ms

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / listeningTimeoutSeconds, 1.0)

                await MainActor.run {
                    timeoutProgress = progress
                }

                if elapsed >= listeningTimeoutSeconds {
                    print("SeamlessVoice: ⏰ Timeout reached (\(listeningTimeoutSeconds)s) - auto-processing audio")
                    await MainActor.run {
                        timeoutProgress = 1.0
                    }
                    // Process whatever audio we have
                    await processCurrentAudio()
                    break
                }

                try? await Task.sleep(nanoseconds: checkInterval)
            }
        }
    }

    // Common Whisper hallucinations to filter out
    private let whisperHallucinations: Set<String> = [
        "thank you",
        "thanks",
        "thanks for watching",
        "thank you for watching",
        "bye",
        "goodbye",
        "see you",
        "please subscribe",
        "like and subscribe",
        "you",
        "...",
        "",
        "hmm",
        "um",
        "uh",
        "ah",
        "oh",
        "okay",
        "ok",
        // Foreign language artifacts
        "sous-titres",
        "subtítulos",
        "untertitel",
        "sottotitoli"
    ]

    /// Check if a transcript is likely a Whisper hallucination
    private func isHallucination(_ transcript: String) -> Bool {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty or very short
        if normalized.count < 2 {
            return true
        }

        // Exact match hallucinations
        if whisperHallucinations.contains(normalized) {
            return true
        }

        // Partial match for common patterns
        if normalized.hasPrefix("thank") && normalized.count < 20 {
            return true
        }

        // Only punctuation/symbols
        let letters = normalized.filter { $0.isLetter }
        if letters.count < 2 {
            return true
        }

        return false
    }

    private func processCurrentAudio() async {
        print("SeamlessVoice: processCurrentAudio() called")

        // Check if we actually detected speech before processing
        let hadSpeech = hasDetectedSpeech
        print("SeamlessVoice: Had speech detected: \(hadSpeech)")

        let audioData = audioManager.stopRecording()
        print("SeamlessVoice: Audio data size: \(audioData?.count ?? 0) bytes")

        guard let audioData = audioData, audioData.count > 1000 else {
            print("SeamlessVoice: Audio too small (<1000 bytes), restarting listening")
            // Restart listening if no meaningful audio
            if isListening {
                await restartListening()
            }
            return
        }

        // If no speech was detected, don't bother transcribing (saves API calls and avoids hallucinations)
        guard hadSpeech else {
            print("SeamlessVoice: No speech was detected, skipping transcription")
            if isListening {
                await restartListening()
            }
            return
        }

        do {
            // Transcribe
            let base64Audio = audioData.base64EncodedString()
            print("SeamlessVoice: Sending \(base64Audio.count) base64 chars to Convex for transcription...")

            let transcript = try await ConvexService.shared.callVoiceTranscribe(audioBase64: base64Audio)
            print("SeamlessVoice: Got transcript: \"\(transcript)\"")

            // Filter out hallucinations
            if isHallucination(transcript) {
                print("SeamlessVoice: ⚠️ Filtered hallucination: \"\(transcript)\"")
                if isListening {
                    await restartListening()
                }
                return
            }

            await MainActor.run {
                // Replace transcript instead of appending (cleaner for single-answer questions)
                currentTranscript = transcript

                print("SeamlessVoice: Valid transcript: \"\(currentTranscript)\"")
            }

            // Use LLM-based parsing for better accuracy
            await parseAnswerWithLLM()

        } catch {
            print("SeamlessVoice: Transcription error: \(error)")
            // Restart listening
            if isListening {
                await restartListening()
            }
        }
    }

    /// Restart listening with fresh state
    private func restartListening() async {
        print("SeamlessVoice: Restarting listening...")

        // Reset state
        await MainActor.run {
            hasDetectedSpeech = false
            timeoutProgress = 0.0
            currentTranscript = ""
        }

        // Use the appropriate listening mode
        if useNativeSpeechRecognition {
            // Stop any existing native recognition
            stopNativeRecognition()

            // Brief pause
            try? await Task.sleep(nanoseconds: 200_000_000)

            // Restart native listening
            await startListening()
        } else {
            // Whisper mode
            listeningStartTime = Date()

            audioManager.onSilenceDetected = { [weak self] in
                print("SeamlessVoice: >>> SILENCE DETECTED - processing audio <<<")
                Task { @MainActor in
                    self?.timeoutTask?.cancel()
                    await self?.processCurrentAudio()
                }
            }

            try? await audioManager.startRecording()
            startAudioLevelPolling()
        }
    }

    // MARK: - Answer Parsing (LLM-based)

    /// Parse the answer using the LLM-based parser for better accuracy
    private func parseAnswerWithLLM() async {
        guard let question = currentQuestion, !currentTranscript.isEmpty else {
            print("SeamlessVoice: parseAnswerWithLLM() skipped - no question or empty transcript")
            return
        }

        print("SeamlessVoice: parseAnswerWithLLM() for question type: \(question.questionType)")
        print("SeamlessVoice: Transcript to parse: \"\(currentTranscript)\"")

        // First try quick local parsing for simple cases (yes/no, numbers)
        if let quickAnswer = tryQuickParse(transcript: currentTranscript, question: question) {
            print("SeamlessVoice: ✅ Quick parse success: \"\(quickAnswer)\"")
            await MainActor.run {
                detectedAnswer = quickAnswer
                startAutoAdvanceCountdown()
            }
            return
        }

        // For complex cases, use LLM parsing
        do {
            let context = VoiceParsingContext(
                questionId: question.id,
                questionText: question.text,
                questionType: question.questionType.rawValue,
                options: question.options,
                minValue: question.scaleMin ?? question.minValue,
                maxValue: question.scaleMax ?? question.maxValue
            )

            print("SeamlessVoice: Calling LLM parser...")
            let response = try await ConvexService.shared.callVoiceParseResponse(
                transcript: currentTranscript,
                context: context
            )

            print("SeamlessVoice: LLM response - type: \(response.value), confidence: \(response.confidence)")

            // Only accept high-confidence results
            guard response.confidence >= 0.5 else {
                print("SeamlessVoice: Low confidence (\(response.confidence)), showing alternatives")
                // For low confidence, restart listening to get more input
                if isListening {
                    await restartListening()
                }
                return
            }

            // Extract the display value
            let displayValue = extractDisplayValue(from: response, question: question)

            if let answer = displayValue {
                print("SeamlessVoice: ✅ LLM ANSWER DETECTED: \"\(answer)\" (confidence: \(response.confidence))")
                await MainActor.run {
                    detectedAnswer = answer
                    startAutoAdvanceCountdown()
                }
            } else {
                print("SeamlessVoice: Could not extract display value from LLM response")
                if isListening {
                    await restartListening()
                }
            }

        } catch {
            print("SeamlessVoice: LLM parsing error: \(error)")
            // Fall back to local parsing
            await MainActor.run {
                if let fallbackAnswer = fallbackLocalParse(transcript: currentTranscript, question: question) {
                    print("SeamlessVoice: ✅ Fallback parse: \"\(fallbackAnswer)\"")
                    detectedAnswer = fallbackAnswer
                    startAutoAdvanceCountdown()
                } else if isListening {
                    Task { await restartListening() }
                }
            }
        }
    }

    /// Quick local parsing for simple, unambiguous cases
    private func tryQuickParse(transcript: String, question: Question) -> String? {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch question.questionType {
        case .yesNo, .yesNoDontKnow:
            // Strong yes patterns
            let strongYes = ["yes", "yeah", "yep", "yup", "absolutely", "definitely", "of course", "sure", "correct", "right", "i do", "i did", "i have", "i am"]
            for pattern in strongYes {
                if normalized == pattern || normalized.hasPrefix(pattern + " ") || normalized.hasPrefix(pattern + ",") {
                    return "Yes"
                }
            }

            // Strong no patterns
            let strongNo = ["no", "nope", "nah", "never", "not at all", "i don't", "i didn't", "i haven't", "i'm not", "not really"]
            for pattern in strongNo {
                if normalized == pattern || normalized.hasPrefix(pattern + " ") || normalized.hasPrefix(pattern + ",") {
                    return "No"
                }
            }

            // Don't know patterns
            if question.questionType == .yesNoDontKnow {
                let dontKnow = ["don't know", "not sure", "i'm not sure", "maybe", "uncertain", "hard to say"]
                for pattern in dontKnow {
                    if normalized.contains(pattern) {
                        return "Don't know"
                    }
                }
            }

        case .scale:
            let numberWords: [String: Int] = [
                "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
                "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
            ]
            let min = question.scaleMin ?? 1
            let max = question.scaleMax ?? 10

            // Check word numbers at start of transcript
            for (word, value) in numberWords {
                if (normalized == word || normalized.hasPrefix(word + " ")) && value >= min && value <= max {
                    return "\(value)"
                }
            }

            // Check for standalone digits
            let pattern = #"^(\d+)(?:\s|$|\.)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
               let range = Range(match.range(at: 1), in: normalized),
               let value = Int(normalized[range]),
               value >= min && value <= max {
                return "\(value)"
            }

        default:
            break
        }

        return nil
    }

    /// Extract a display-friendly value from the parsed response
    private func extractDisplayValue(from response: ParsedResponse, question: Question) -> String? {
        // Use the built-in displayString property from ParsedValue
        let display = response.value.displayString

        // Return nil for unknown or empty values
        if case .unknown = response.value {
            return nil
        }

        return display.isEmpty ? nil : display
    }

    /// Fallback local parsing when LLM fails
    private func fallbackLocalParse(transcript: String, question: Question) -> String? {
        // Just use quick parse as fallback
        return tryQuickParse(transcript: transcript, question: question)
    }

    private func startAutoAdvanceCountdown() {
        autoAdvanceTask?.cancel()
        autoAdvanceCountdown = 3

        autoAdvanceTask = Task {
            for i in (1...3).reversed() {
                await MainActor.run {
                    autoAdvanceCountdown = i
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                if Task.isCancelled { return }
            }

            await MainActor.run {
                autoAdvanceCountdown = 0
                confirmAndAdvance()
            }
        }
    }

    // MARK: - Actions

    func skipQuestion() {
        advanceToNextQuestion()
    }

    func confirmAndAdvance() {
        guard let answer = detectedAnswer, let question = currentQuestion else {
            advanceToNextQuestion()
            return
        }

        // Store answer
        collectedAnswers[question.id] = answer

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        advanceToNextQuestion()
    }

    private func advanceToNextQuestion() {
        // Stop current listening
        listeningTask?.cancel()
        autoAdvanceTask?.cancel()
        timeoutTask?.cancel()
        _ = audioManager.stopRecording()
        audioManager.onSilenceDetected = nil
        isListening = false

        // Reset state
        currentTranscript = ""
        detectedAnswer = nil
        autoAdvanceCountdown = 0
        hasDetectedSpeech = false
        timeoutProgress = 0.0
        listeningStartTime = nil

        // Move to next
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1

            // Small delay then speak next question
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                speakCurrentQuestion()
            }
        } else {
            isComplete = true
        }
    }
}

// MARK: - Audio Level Meter

/// Visual indicator showing audio input level and speech detection status
struct AudioLevelMeter: View {
    let level: Float
    let hasDetectedSpeech: Bool
    let timeoutProgress: Double

    private let threshold: Float = 0.05
    private let barCount = 5

    var body: some View {
        HStack(spacing: 3) {
            // Timeout indicator (circular progress)
            if !hasDetectedSpeech && timeoutProgress > 0 {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 16, height: 16)

                    Circle()
                        .trim(from: 0, to: timeoutProgress)
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(-90))
                }
                .padding(.trailing, 4)
            }

            // Speech detected indicator
            if hasDetectedSpeech {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            }

            // Level bars
            ForEach(0..<barCount, id: \.self) { index in
                let barThreshold = Float(index + 1) / Float(barCount)
                let isActive = level >= barThreshold * 0.5 // Scale to make it more responsive

                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index, isActive: isActive))
                    .frame(width: 4, height: barHeight(for: index))
            }

            // Mic status icon
            Image(systemName: level > threshold ? "mic.fill" : "mic")
                .font(.system(size: 10))
                .foregroundColor(level > threshold ? .green : .white.opacity(0.4))
        }
        .animation(.easeOut(duration: 0.1), value: level)
        .animation(.easeInOut(duration: 0.2), value: hasDetectedSpeech)
    }

    private func barColor(for index: Int, isActive: Bool) -> Color {
        guard isActive else { return Color.white.opacity(0.2) }

        // Green for normal, yellow for medium, red for high
        if index < 2 {
            return .green
        } else if index < 4 {
            return .yellow
        } else {
            return .orange
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        CGFloat(8 + index * 2)
    }
}

// MARK: - Preview

#Preview("Seamless Voice Questionnaire") {
    SeamlessVoiceQuestionnaireView(
        questions: [
            Question(
                id: "q1",
                text: "Did you take any sleep-related medication yesterday or last night?",
                pillar: .sleepQuality,
                tier: .core,
                questionType: .yesNo,
                estimatedMinutes: 0.5,
                required: true,
                options: nil,
                scaleMin: nil, scaleMax: nil, scaleMinLabel: nil, scaleMaxLabel: nil,
                minValue: nil, maxValue: nil, step: nil, unit: nil, defaultValue: nil,
                unitImperial: nil, defaultImperial: nil, helpText: nil, helpTextImperial: nil,
                isGateway: false, gatewayType: nil, gatewayThreshold: nil,
                conditionalLogic: nil, group: nil, repeatingFields: nil
            ),
            Question(
                id: "q2",
                text: "On a scale of 1 to 10, how would you rate your overall sleep quality last night?",
                pillar: .sleepQuality,
                tier: .core,
                questionType: .scale,
                estimatedMinutes: 0.5,
                required: true,
                options: nil,
                scaleMin: 1, scaleMax: 10, scaleMinLabel: "Very poor", scaleMaxLabel: "Excellent",
                minValue: nil, maxValue: nil, step: nil, unit: nil, defaultValue: nil,
                unitImperial: nil, defaultImperial: nil, helpText: nil, helpTextImperial: nil,
                isGateway: false, gatewayType: nil, gatewayThreshold: nil,
                conditionalLogic: nil, group: nil, repeatingFields: nil
            )
        ],
        sectionTitle: "Sleep Log",
        onComplete: { answers in
            print("Completed: \(answers)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}
