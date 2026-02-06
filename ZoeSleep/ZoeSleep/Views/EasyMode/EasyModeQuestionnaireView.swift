//
//  EasyModeQuestionnaireView.swift
//  ZoeSleep
//
//  Seamless hands-free voice questionnaire for Easy Mode
//  Designed for elderly patients - no scrolling, continuous listening, auto-advance
//

import SwiftUI

/// Main Easy Mode questionnaire view - seamless hands-free experience
/// - Questions read aloud automatically (TTS)
/// - Recording starts automatically after TTS
/// - Silence detection auto-stops recording
/// - High confidence answers auto-advance
/// - Options always visible as fallback
struct EasyModeQuestionnaireView: View {
    let questions: [Question]
    let dayNumber: Int
    let section: String  // "sleepLog" or "assessment"
    let onComplete: ([String: Any]) -> Void
    let onDismiss: () -> Void

    @ObservedObject var easyModeManager = EasyModeManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var audioManager = AudioSessionManager.shared

    // Navigation state
    @State private var currentIndex = 0
    @State private var responses: [String: Any] = [:]

    // Voice flow state
    @State private var isProcessingVoice = false
    @State private var showConfirmationToast = false
    @State private var confirmationMessage = ""
    @State private var confirmationIsSuccess = true
    @State private var lowConfidenceRetryVisible = false
    @State private var ttsSkipped = false  // True if TTS failed/skipped
    @State private var recordingTimeoutTask: Task<Void, Never>?

    private var theme: ColorTheme { themeManager.currentTheme }

    private var currentQuestion: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    private var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(questions.count)
    }

    /// Get display options for current question (for tappable fallback)
    private var currentOptions: [String] {
        guard let question = currentQuestion else { return [] }

        // For yes/no questions
        if question.questionType == .yesNo {
            return ["Yes", "No"]
        }
        if question.questionType == .yesNoDontKnow {
            return ["Yes", "No", "Don't know"]
        }
        // For scale questions, show a few key values
        if question.questionType == .scale {
            return ["1-3 (Low)", "4-6 (Medium)", "7-10 (High)"]
        }
        // For select questions with options - show ALL options
        if let options = question.options, !options.isEmpty {
            return options
        }
        return []
    }

    var body: some View {
        ZStack {
            // Background
            theme.backgroundGradient
                .ignoresSafeArea()

            // Main fixed layout - no scrolling
            VStack(spacing: 0) {
                // Top: Progress bar + close button
                headerBar

                // Middle: Question + voice status (flexible space)
                Spacer(minLength: Spacing.md)
                questionArea
                Spacer(minLength: Spacing.md)

                // Bottom: Always-visible option buttons
                optionButtonsArea
            }

            // Confirmation toast overlay
            if showConfirmationToast {
                confirmationToastOverlay
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
        .animation(.spring(response: 0.3), value: easyModeManager.voiceState)
        .onAppear {
            startVoiceFlowForCurrentQuestion()
        }
        .onChange(of: currentIndex) { _, _ in
            // Reset and start voice flow for new question
            recordingTimeoutTask?.cancel()
            easyModeManager.reset()
            lowConfidenceRetryVisible = false
            ttsSkipped = false
            startVoiceFlowForCurrentQuestion()
        }
        .onDisappear {
            recordingTimeoutTask?.cancel()
            easyModeManager.clearAutoStopCallback()
            easyModeManager.reset()
        }
    }

    // MARK: - Header Bar (Progress + Close)

    private var headerBar: some View {
        HStack(spacing: Spacing.md) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.primaryText.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.accent)
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.spring(response: 0.3), value: progress)
                }
            }
            .frame(height: 6)

            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(theme.secondaryText)
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Question Area (Center)

    private var questionArea: some View {
        VStack(spacing: Spacing.lg) {
            if let question = currentQuestion {
                // Question text
                Text(question.text)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.lg)
                    .id(question.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                // Voice status indicator
                voiceStatusIndicator

                // Low confidence retry area
                if lowConfidenceRetryVisible {
                    lowConfidenceRetryView
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Voice Status Indicator

    @ViewBuilder
    private var voiceStatusIndicator: some View {
        VStack(spacing: Spacing.sm) {
            switch easyModeManager.voiceState {
            case .idle:
                // Show TTS status or waiting
                if easyModeManager.isSpeaking {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.accent)
                            .symbolEffect(.variableColor)
                        Text("Reading question...")
                            .font(.system(size: Typography.body, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }
                } else if ttsSkipped {
                    // TTS failed - show manual start option
                    VStack(spacing: Spacing.sm) {
                        Text("Voice not available")
                            .font(.system(size: Typography.subheadline))
                            .foregroundColor(theme.warning)

                        Button(action: {
                            startRecordingManually()
                        }) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "mic.fill")
                                Text("Tap to Speak")
                            }
                            .font(.system(size: Typography.body, weight: .semibold))
                            .foregroundColor(theme.textOnPrimary)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(theme.accent)
                            )
                        }

                        Text("or tap an option below")
                            .font(.system(size: Typography.caption))
                            .foregroundColor(theme.secondaryText)
                    }
                } else {
                    // Waiting or ready for voice
                    EmptyView()
                }

            case .listening:
                // Active recording with waveform
                VStack(spacing: Spacing.sm) {
                    // Waveform visualization
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.accent)
                                .frame(width: 6, height: CGFloat(15 + (audioManager.audioLevel * 35 * Float((i % 3) + 1))))
                                .animation(.easeInOut(duration: 0.08), value: audioManager.audioLevel)
                        }
                    }
                    .frame(height: 50)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(theme.accent)
                        Text("Listening...")
                            .font(.system(size: Typography.body, weight: .semibold))
                            .foregroundColor(theme.accent)
                    }

                    // Manual done button
                    Button(action: {
                        manuallyStopRecording()
                    }) {
                        Text("Done Speaking")
                            .font(.system(size: Typography.subheadline, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                            .underline()
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(theme.accent.opacity(0.1))
                )

            case .processing, .parsing:
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .tint(theme.accent)
                    Text("Processing...")
                        .font(.system(size: Typography.body, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(Spacing.md)

            case .confirming(let response):
                // Show what was transcribed and how it was understood
                VStack(spacing: Spacing.md) {
                    // Transcription display
                    VStack(spacing: Spacing.xs) {
                        Text("I heard:")
                            .font(.system(size: Typography.subheadline, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                        Text("\"\(response.transcript)\"")
                            .font(.system(size: Typography.body, weight: .regular, design: .rounded))
                            .foregroundColor(theme.primaryText.opacity(0.8))
                            .italic()
                            .multilineTextAlignment(.center)
                    }

                    // Parsed value display
                    VStack(spacing: Spacing.xs) {
                        Text("Understood as:")
                            .font(.system(size: Typography.subheadline, weight: .medium))
                            .foregroundColor(theme.secondaryText)

                        HStack(spacing: Spacing.sm) {
                            if response.isHighConfidence {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(theme.success)
                            }
                            Text(response.displayValue)
                                .font(.system(size: Typography.title3, weight: .bold))
                                .foregroundColor(theme.primaryText)
                        }
                    }

                    // Action buttons - always show for explicit control
                    HStack(spacing: Spacing.md) {
                        // Retry button
                        Button(action: {
                            easyModeManager.retry()
                            startRecordingManually()
                        }) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Retry")
                            }
                            .font(.system(size: Typography.subheadline, weight: .medium))
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .stroke(theme.accent, lineWidth: 1)
                            )
                        }

                        // Confirm button
                        Button(action: {
                            confirmAndAdvance(value: response.value, displayValue: response.displayValue)
                        }) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "checkmark")
                                Text("Correct")
                            }
                            .font(.system(size: Typography.subheadline, weight: .semibold))
                            .foregroundColor(theme.textOnPrimary)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .fill(theme.success)
                            )
                        }
                    }

                    // Auto-advance hint
                    Text(response.isHighConfidence ? "Auto-confirming..." : "Or wait to auto-confirm")
                        .font(.system(size: Typography.caption))
                        .foregroundColor(theme.secondaryText.opacity(0.7))
                }
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(theme.accent.opacity(0.1))
                )
                .onAppear {
                    // Delay the auto-confirmation so user can see the result
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        handleVoiceConfirmation(response)
                    }
                }

            case .error(let error):
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(theme.warning)
                    Text(error.userMessage)
                        .font(.system(size: Typography.subheadline))
                        .foregroundColor(theme.warning)
                        .multilineTextAlignment(.center)

                    // Retry button
                    Button(action: {
                        easyModeManager.retry()
                        startVoiceFlowForCurrentQuestion()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "mic.fill")
                            Text("Try Again")
                        }
                        .font(.system(size: Typography.body, weight: .medium))
                        .foregroundColor(theme.textOnPrimary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(theme.accent)
                        )
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    // MARK: - Low Confidence Retry View

    private var lowConfidenceRetryView: some View {
        VStack(spacing: Spacing.md) {
            Text("I didn't catch that clearly")
                .font(.system(size: Typography.body, weight: .medium))
                .foregroundColor(theme.warning)

            Button(action: {
                lowConfidenceRetryVisible = false
                easyModeManager.retry()
                startVoiceFlowForCurrentQuestion()
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "mic.fill")
                    Text("Speak Again")
                }
                .font(.system(size: Typography.body, weight: .semibold))
                .foregroundColor(theme.textOnPrimary)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(theme.accent)
                )
            }

            Text("or tap an option below")
                .font(.system(size: Typography.subheadline))
                .foregroundColor(theme.secondaryText)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(theme.warning.opacity(0.1))
        )
    }

    // MARK: - Option Buttons Area (Always Visible)

    private var optionButtonsArea: some View {
        VStack(spacing: Spacing.sm) {
            // Option buttons in horizontal layout
            if !currentOptions.isEmpty {
                optionButtonsGrid
            }

            // Back button (if not first question)
            if currentIndex > 0 {
                Button(action: previousQuestion) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: Typography.subheadline, weight: .medium))
                    .foregroundColor(theme.secondaryText)
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.lg)
        .background(
            theme.cardBackground.opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private var optionButtonsGrid: some View {
        let options = currentOptions

        if options.count <= 2 {
            // Two buttons side by side
            HStack(spacing: Spacing.md) {
                ForEach(options, id: \.self) { option in
                    optionButton(for: option)
                }
            }
        } else if options.count == 3 {
            // Two on top, one below
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    optionButton(for: options[0])
                    optionButton(for: options[1])
                }
                optionButton(for: options[2])
            }
        } else if options.count == 4 {
            // 2x2 grid
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    optionButton(for: options[0])
                    optionButton(for: options[1])
                }
                HStack(spacing: Spacing.md) {
                    optionButton(for: options[2])
                    optionButton(for: options[3])
                }
            }
        } else {
            // 5+ options: horizontal scroll view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(options, id: \.self) { option in
                        compactOptionButton(for: option)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func compactOptionButton(for option: String) -> some View {
        Button(action: {
            handleOptionTap(option)
        }) {
            Text(option)
                .font(.system(size: Typography.body, weight: .semibold))
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(theme.cardBackground)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func optionButton(for option: String) -> some View {
        Button(action: {
            handleOptionTap(option)
        }) {
            Text(option)
                .font(.system(size: Typography.headline, weight: .semibold))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(theme.cardBackground)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Confirmation Toast Overlay

    private var confirmationToastOverlay: some View {
        VStack {
            Spacer()

            HStack(spacing: Spacing.sm) {
                Image(systemName: confirmationIsSuccess ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(confirmationIsSuccess ? theme.success : theme.warning)

                Text(confirmationMessage)
                    .font(.system(size: Typography.body, weight: .medium))
                    .foregroundColor(theme.primaryText)
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(theme.cardBackground)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            )
            .padding(.bottom, 150)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Voice Flow Control

    private func startVoiceFlowForCurrentQuestion() {
        guard let question = currentQuestion else { return }

        // Reset TTS skipped state
        ttsSkipped = false

        // Cancel any existing timeout
        recordingTimeoutTask?.cancel()

        Task {
            // Request mic permission if needed
            if audioManager.hasMicrophonePermission != true {
                let granted = await audioManager.requestMicrophonePermission()
                if !granted {
                    print("EasyMode: Microphone permission denied")
                    // User will need to tap option buttons instead
                    await MainActor.run {
                        ttsSkipped = true  // Show manual controls
                    }
                    return
                }
            }

            // Start the hands-free voice flow
            // This will either:
            // 1. Play TTS, wait for completion, then auto-start recording
            // 2. If TTS fails, return early and we'll show manual controls
            await easyModeManager.speakAndAutoRecord(question: question) {
                // This callback is called when recording completes (via silence detection)
                // The voice state will transition to .processing -> .confirming
                recordingTimeoutTask?.cancel()
            }

            // Small delay to let state settle
            try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3s

            await MainActor.run {
                // Check if TTS failed - if so, show manual controls
                if easyModeManager.ttsError != nil {
                    print("EasyMode: TTS failed, showing manual controls")
                    ttsSkipped = true
                }

                // Start recording timeout if we're now listening
                if case .listening = easyModeManager.voiceState {
                    startRecordingTimeout(for: question)
                }
            }
        }
    }

    /// Start recording manually when TTS fails
    private func startRecordingManually() {
        guard let question = currentQuestion else { return }

        ttsSkipped = false

        Task {
            do {
                // Set up silence detection callback
                audioManager.onSilenceDetected = { [self] in
                    Task {
                        await easyModeManager.stopRecordingAndProcess(for: question)
                        recordingTimeoutTask?.cancel()
                    }
                }

                try await easyModeManager.startRecording()

                // Start timeout
                await MainActor.run {
                    startRecordingTimeout(for: question)
                }
            } catch {
                print("EasyMode: Failed to start manual recording: \(error)")
            }
        }
    }

    /// Start a timeout for recording - auto-stop if user doesn't speak
    private func startRecordingTimeout(for question: Question) {
        recordingTimeoutTask?.cancel()

        recordingTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)  // 15 seconds

            guard !Task.isCancelled else { return }

            await MainActor.run {
                // If still listening after 15 seconds, show timeout message
                if case .listening = easyModeManager.voiceState {
                    easyModeManager.cancelRecording()
                    lowConfidenceRetryVisible = true
                    showToast(message: "No speech detected", isSuccess: false)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        hideToast()
                    }
                }
            }
        }
    }

    /// Manually stop recording (when user taps "Done Speaking")
    private func manuallyStopRecording() {
        guard let question = currentQuestion else { return }

        recordingTimeoutTask?.cancel()

        Task {
            await easyModeManager.stopRecordingAndProcess(for: question)
        }
    }

    private func handleVoiceConfirmation(_ response: ParsedResponse) {
        guard currentQuestion != nil else { return }

        if response.isHighConfidence {
            // High confidence: show the confirmation briefly, then auto-advance
            // Give user 1.5 seconds to see what was understood before advancing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if case .confirming = easyModeManager.voiceState {
                    confirmAndAdvance(value: response.value, displayValue: response.displayValue)
                }
            }
        } else if response.confidence >= 0.6 {
            // Medium confidence: show longer (2.5s) and add a toast reminder
            showToast(message: "Tap to correct if needed", isSuccess: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if case .confirming = easyModeManager.voiceState {
                    confirmAndAdvance(value: response.value, displayValue: response.displayValue)
                }
            }
        } else {
            // Low confidence: show retry option + keep options visible
            easyModeManager.reset()
            lowConfidenceRetryVisible = true
        }
    }

    private func confirmAndAdvance(value: ParsedValue, displayValue: String) {
        guard let question = currentQuestion else { return }

        // Store response
        responses[question.id] = value.responseValue

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Reset manager
        easyModeManager.reset()

        // Show brief confirmation
        showToast(message: "Got it!", isSuccess: true)

        // Advance after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            hideToast()
            if currentIndex < questions.count - 1 {
                withAnimation {
                    currentIndex += 1
                }
            } else {
                completeQuestionnaire()
            }
        }
    }

    // MARK: - Option Tap Handler

    private func handleOptionTap(_ option: String) {
        guard let question = currentQuestion else { return }

        // Stop any voice activity
        easyModeManager.cancelRecording()
        easyModeManager.stopSpeaking()
        easyModeManager.clearAutoStopCallback()
        easyModeManager.reset()
        lowConfidenceRetryVisible = false

        // Parse the tapped option to get the actual value
        let value = parseOptionValue(option, for: question)

        // Store response
        responses[question.id] = value

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Show confirmation and advance
        showToast(message: "Got it!", isSuccess: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            hideToast()
            if currentIndex < questions.count - 1 {
                withAnimation {
                    currentIndex += 1
                }
            } else {
                completeQuestionnaire()
            }
        }
    }

    private func parseOptionValue(_ option: String, for question: Question) -> Any {
        // For scale questions with range labels, parse to middle value
        if question.questionType == .scale {
            switch option {
            case "1-3 (Low)": return 2
            case "4-6 (Medium)": return 5
            case "7-10 (High)": return 8
            default: return option
            }
        }
        // For yes/no
        if option == "Yes" { return true }
        if option == "No" { return false }
        // Otherwise return as string
        return option
    }

    // MARK: - Navigation

    private func previousQuestion() {
        guard currentIndex > 0 else { return }

        easyModeManager.stopSpeaking()
        easyModeManager.cancelRecording()
        easyModeManager.reset()
        lowConfidenceRetryVisible = false

        withAnimation {
            currentIndex -= 1
        }
    }

    private func completeQuestionnaire() {
        onComplete(responses)
    }

    // MARK: - Toast Helpers

    private func showToast(message: String, isSuccess: Bool) {
        confirmationMessage = message
        confirmationIsSuccess = isSuccess
        withAnimation(.spring(response: 0.3)) {
            showConfirmationToast = true
        }
    }

    private func hideToast() {
        withAnimation(.spring(response: 0.3)) {
            showConfirmationToast = false
        }
    }
}

// MARK: - Easy Mode Welcome View

/// Welcome/onboarding view for Easy Mode first use
struct EasyModeWelcomeView: View {
    let onContinue: () -> Void
    let onCancel: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

    @State private var hasRequestedPermission = false
    @State private var micPermissionGranted = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(theme.accent)

            // Title
            Text("Voice Mode")
                .font(.system(size: Typography.largeTitle, weight: .bold, design: .rounded))
                .foregroundColor(theme.primaryText)

            // Description
            Text("Answer questions by speaking.\nQuestions will be read aloud to you.")
                .font(.system(size: Typography.title3, weight: .regular))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()

            // Features list
            VStack(alignment: .leading, spacing: Spacing.md) {
                featureRow(icon: "speaker.wave.2.fill", text: "Questions read aloud")
                featureRow(icon: "mic.fill", text: "Just speak your answer")
                featureRow(icon: "arrow.right.circle.fill", text: "Auto-advances when done")
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(theme.cardBackground)
            )

            Spacer()

            // Microphone permission status
            if hasRequestedPermission && !micPermissionGranted {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.warning)
                    Text("Microphone access required")
                        .font(.system(size: Typography.subheadline, weight: .medium))
                        .foregroundColor(theme.warning)
                }
                .padding(Spacing.md)
            }

            // Continue button
            Button(action: requestPermissionAndContinue) {
                Text(hasRequestedPermission && micPermissionGranted ? "Start" : "Enable Microphone & Start")
                    .font(.system(size: Typography.headline, weight: .semibold))
                    .foregroundColor(theme.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(theme.accent)
                    )
            }
            .frame(height: 60)

            // Cancel button
            Button(action: onCancel) {
                Text("Use Standard Mode")
                    .font(.system(size: Typography.body, weight: .medium))
                    .foregroundColor(theme.secondaryText)
                    .underline()
            }
        }
        .padding(Spacing.xl)
        .background(theme.backgroundGradient.ignoresSafeArea())
    }

    @ViewBuilder
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(theme.accent)
                .frame(width: 40)

            Text(text)
                .font(.system(size: Typography.body, weight: .medium))
                .foregroundColor(theme.primaryText)
        }
    }

    private func requestPermissionAndContinue() {
        Task {
            let granted = await AudioSessionManager.shared.requestMicrophonePermission()

            await MainActor.run {
                hasRequestedPermission = true
                micPermissionGranted = granted

                if granted {
                    onContinue()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Easy Mode Questionnaire") {
    let questions = [
        Question(
            id: "Q1",
            text: "How would you rate the quality of your sleep last night?",
            pillar: .sleepQuality,
            tier: .core,
            questionType: .scale,
            estimatedMinutes: 0.5,
            required: true,
            options: nil,
            scaleMin: 0,
            scaleMax: 10,
            scaleMinLabel: "Very poor",
            scaleMaxLabel: "Excellent",
            minValue: nil, maxValue: nil, step: nil, unit: nil, defaultValue: nil,
            unitImperial: nil, defaultImperial: nil, helpText: nil, helpTextImperial: nil,
            isGateway: false, gatewayType: nil, gatewayThreshold: nil,
            conditionalLogic: nil, group: nil, repeatingFields: nil
        ),
        Question(
            id: "Q2",
            text: "Did you take any sleep medications last night?",
            pillar: .sleepQuality,
            tier: .core,
            questionType: .yesNo,
            estimatedMinutes: 0.25,
            required: true,
            options: nil,
            scaleMin: nil, scaleMax: nil, scaleMinLabel: nil, scaleMaxLabel: nil,
            minValue: nil, maxValue: nil, step: nil, unit: nil, defaultValue: nil,
            unitImperial: nil, defaultImperial: nil, helpText: nil, helpTextImperial: nil,
            isGateway: false, gatewayType: nil, gatewayThreshold: nil,
            conditionalLogic: nil, group: nil, repeatingFields: nil
        )
    ]

    EasyModeQuestionnaireView(
        questions: questions,
        dayNumber: 1,
        section: "sleepLog",
        onComplete: { responses in
            print("Completed with: \(responses)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}
