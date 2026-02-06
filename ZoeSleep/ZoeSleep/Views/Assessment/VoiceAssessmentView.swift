//
//  VoiceAssessmentView.swift
//  ZoeSleep
//
//  Full-screen voice-based assessment experience with Zoe.
//  Conversational flow through the 10-day journey, with guardrails
//  to keep the conversation on track.
//

import SwiftUI
import Combine

/// Full-screen voice assessment view for conversational intake
struct VoiceAssessmentView: View {
    let dayNumber: Int
    let onComplete: () -> Void
    let onDismiss: () -> Void

    @StateObject private var sessionManager = VoiceAssessmentSessionManager.shared
    @ObservedObject private var audioManager = AudioSessionManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showExitConfirmation = false
    @State private var showManualFallback = false
    @State private var holdingToRecord = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with progress
                headerView
                    .padding(.top, Spacing.md)
                    .padding(.horizontal, Spacing.lg)

                Spacer()

                // Zoe's message area
                zoeMessageArea
                    .padding(.horizontal, Spacing.lg)

                Spacer()

                // Zoe Orb
                ZoeOrbView(state: orbState, audioLevel: audioManager.audioLevel)
                    .frame(height: 280)

                Spacer()

                // Input area (transcript + voice button)
                inputArea
                    .padding(.horizontal, Spacing.lg)

                // Bottom controls
                bottomControls
                    .padding(.bottom, Spacing.xl)
            }

            // Confirmation overlay
            if sessionManager.showConfirmation {
                confirmationOverlay
            }

            // Day complete overlay
            if sessionManager.state == .dayComplete {
                dayCompleteOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startSession()
        }
        .onDisappear {
            sessionManager.endSession()
        }
        .alert("End Assessment?", isPresented: $showExitConfirmation) {
            Button("Continue", role: .cancel) { }
            Button("Save & Exit", role: .destructive) {
                sessionManager.pauseSession()
                onDismiss()
            }
        } message: {
            Text("Your progress will be saved. You can continue later.")
        }
        .sheet(isPresented: $showManualFallback) {
            manualInputSheet
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
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                // Close button
                Button(action: { showExitConfirmation = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }

                Spacer()

                // Day indicator
                VStack(spacing: 2) {
                    Text("Day \(dayNumber)")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    if let script = sessionManager.currentScript {
                        Text(script.title)
                            .font(.system(size: Typography.subheadline, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Spacer()

                // Manual input toggle
                Button(action: { showManualFallback = true }) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }

            // Progress bar
            progressBar
        }
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            // Section progress
            if let script = sessionManager.currentScript,
               sessionManager.progress.currentSectionIndex < script.sections.count {
                let section = script.sections[sessionManager.progress.currentSectionIndex]
                Text(section.title)
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Overall day progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))

                    Capsule()
                        .fill(theme.accent)
                        .frame(width: geo.size.width * sessionManager.progress.dayProgress)
                }
            }
            .frame(height: 4)

            // Question count
            HStack {
                Text("\(sessionManager.progress.questionsAnsweredToday) of \(sessionManager.progress.totalQuestionsInDay)")
                    .font(.system(size: Typography.caption2))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                if let script = sessionManager.currentScript {
                    Text("~\(script.estimatedMinutes) min")
                        .font(.system(size: Typography.caption2))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Zoe Message Area

    private var zoeMessageArea: some View {
        VStack(spacing: Spacing.md) {
            // Status indicator
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Zoe's message
            Text(sessionManager.zoeMessage.isEmpty ? currentPromptText : sessionManager.zoeMessage)
                .font(.system(size: Typography.title3, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, Spacing.md)
                .animation(.easeInOut(duration: 0.3), value: sessionManager.zoeMessage)
        }
        .frame(minHeight: 120)
    }

    private var currentPromptText: String {
        sessionManager.currentPrompt?.spokenPrompt ?? "Let's begin your assessment..."
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: Spacing.md) {
            // Transcript box
            if sessionManager.state == .listening || !sessionManager.currentTranscript.isEmpty {
                transcriptBox
            }

            // Voice input button
            voiceInputButton
        }
    }

    private var transcriptBox: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(sessionManager.currentTranscript.isEmpty ? "Listening..." : sessionManager.currentTranscript)
                .font(.system(size: Typography.body))
                .foregroundColor(sessionManager.currentTranscript.isEmpty ? .white.opacity(0.3) : .white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.1), value: sessionManager.currentTranscript)
        }
        .padding(Spacing.md)
        .frame(minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var voiceInputButton: some View {
        VStack(spacing: Spacing.sm) {
            // Main mic button
            Button(action: {}) { // Action handled by gesture
                ZStack {
                    // Background
                    Circle()
                        .fill(buttonBackgroundColor)
                        .frame(width: 80, height: 80)
                        .shadow(color: theme.accent.opacity(0.3), radius: isRecording ? 15 : 8)

                    // Audio level ring
                    if isRecording {
                        Circle()
                            .stroke(theme.accent.opacity(0.5), lineWidth: 3)
                            .frame(width: 80 + CGFloat(audioManager.audioLevel * 30),
                                   height: 80 + CGFloat(audioManager.audioLevel * 30))
                            .animation(.easeOut(duration: 0.1), value: audioManager.audioLevel)
                    }

                    // Icon
                    if sessionManager.state == .processing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.textOnPrimary))
                            .scaleEffect(1.5)
                    } else {
                        Image(systemName: isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(theme.textOnPrimary)
                            .symbolEffect(.variableColor, isActive: isRecording)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if canStartRecording {
                            holdingToRecord = true
                            Task { await sessionManager.startListening() }
                        }
                    }
                    .onEnded { _ in
                        if holdingToRecord {
                            holdingToRecord = false
                            sessionManager.stopListening()
                        }
                    }
            )
            .disabled(!canInteract)

            // Status text
            Text(buttonStatusText)
                .font(.system(size: Typography.body, weight: .medium))
                .foregroundColor(isRecording ? Color.red : theme.secondaryText)
        }
    }

    private var buttonBackgroundColor: Color {
        if sessionManager.state == .processing {
            return theme.accent.opacity(0.6)
        } else if isRecording {
            return Color.red
        } else {
            return theme.accent
        }
    }

    private var buttonStatusText: String {
        switch sessionManager.state {
        case .notStarted, .introducingZoe:
            return "Getting ready..."
        case .awaitingResponse:
            return "Hold to speak"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .confirming:
            return "Is this correct?"
        case .transitioning:
            return "Moving on..."
        case .redirecting:
            return "Let me clarify..."
        case .sectionComplete:
            return "Section complete!"
        case .dayComplete:
            return "Assessment complete!"
        case .paused:
            return "Paused"
        case .error(let msg):
            return msg
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: Spacing.lg) {
            // Repeat button
            Button(action: {
                Task {
                    await sessionManager.rejectAnswer()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Repeat")
                }
                .font(.system(size: Typography.subheadline, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
            .opacity(canRepeat ? 1 : 0.3)
            .disabled(!canRepeat)

            Spacer()

            // Skip button
            Button(action: {
                Task {
                    await sessionManager.acceptAnswer()
                }
            }) {
                HStack(spacing: 6) {
                    Text("Skip")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: Typography.subheadline, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
            .opacity(canSkip ? 1 : 0.3)
            .disabled(!canSkip)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss by tapping outside
                }

            VStack(spacing: Spacing.lg) {
                // Confirmation message
                Text(sessionManager.zoeMessage)
                    .font(.system(size: Typography.title3, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // Parsed answer display
                if let answer = sessionManager.pendingAnswer {
                    parsedAnswerCard(answer)
                }

                // Action buttons
                HStack(spacing: Spacing.md) {
                    Button(action: {
                        Task { await sessionManager.rejectAnswer() }
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Try Again")
                        }
                        .font(.system(size: Typography.body, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(theme.cardBackground)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        Task { await sessionManager.acceptAnswer() }
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Correct")
                        }
                        .font(.system(size: Typography.body, weight: .semibold))
                        .foregroundColor(theme.textOnPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(theme.accent)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
            )
            .padding(Spacing.lg)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: sessionManager.showConfirmation)
    }

    private func parsedAnswerCard(_ answer: ParsedConversationalAnswer) -> some View {
        VStack(spacing: Spacing.sm) {
            // Display the parsed value
            if let firstValue = answer.parsedValues.values.first {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)

                    Text(displayValue(for: firstValue))
                        .font(.system(size: Typography.title2, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // Confidence indicator
            HStack(spacing: 4) {
                Text("Confidence:")
                    .font(.system(size: Typography.caption))
                    .foregroundColor(.white.opacity(0.5))

                Text("\(Int(answer.confidence * 100))%")
                    .font(.system(size: Typography.caption, weight: .semibold))
                    .foregroundColor(answer.confidence >= 0.8 ? .green : .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func displayValue(for value: Any) -> String {
        if let bool = value as? Bool {
            return bool ? "Yes" : "No"
        } else if let int = value as? Int {
            return "\(int)"
        } else if let double = value as? Double {
            return String(format: "%.1f", double)
        } else if let string = value as? String {
            return string
        }
        return "..."
    }

    // MARK: - Day Complete Overlay

    private var dayCompleteOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                // Success animation
                ZStack {
                    Circle()
                        .fill(theme.success)
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Day \(dayNumber) Complete!")
                    .font(.system(size: Typography.title, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Summary
                VStack(spacing: Spacing.sm) {
                    summaryRow(label: "Questions Answered", value: "\(sessionManager.progress.questionsAnsweredToday)")
                    summaryRow(label: "Time", value: sessionDuration)

                    if !sessionManager.progress.gatewaysTriggered.isEmpty {
                        summaryRow(label: "Additional Topics Unlocked", value: "\(sessionManager.progress.gatewaysTriggered.count)")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )

                // Continue button
                Button(action: {
                    onComplete()
                }) {
                    Text("Continue")
                        .font(.system(size: Typography.body, weight: .semibold))
                        .foregroundColor(theme.textOnPrimary)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(theme.accent)
                        .cornerRadius(16)
                }
            }
            .padding(Spacing.xl)
        }
        .transition(.opacity)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: Typography.body))
                .foregroundColor(theme.secondaryText)

            Spacer()

            Text(value)
                .font(.system(size: Typography.body, weight: .semibold))
                .foregroundColor(theme.primaryText)
        }
    }

    private var sessionDuration: String {
        let startTime = sessionManager.progress.sessionStartTime
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }

    // MARK: - Manual Input Sheet

    private var manualInputSheet: some View {
        NavigationView {
            VStack(spacing: Spacing.lg) {
                Text("Manual Input")
                    .font(.system(size: Typography.title2, weight: .bold))

                if let prompt = sessionManager.currentPrompt {
                    Text(prompt.spokenPrompt)
                        .font(.system(size: Typography.body))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)

                    // Show options based on expected answer type
                    manualInputOptions(for: prompt)
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showManualFallback = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func manualInputOptions(for prompt: ConversationalPrompt) -> some View {
        switch prompt.expectedAnswerType {
        case .yesNo:
            HStack(spacing: Spacing.md) {
                manualOptionButton("Yes") {
                    submitManualAnswer(true)
                }
                manualOptionButton("No") {
                    submitManualAnswer(false)
                }
            }

        case .yesNoDontKnow:
            HStack(spacing: Spacing.md) {
                manualOptionButton("Yes") {
                    submitManualAnswer(true)
                }
                manualOptionButton("No") {
                    submitManualAnswer(false)
                }
                manualOptionButton("Don't Know") {
                    submitManualAnswer("dontknow")
                }
            }

        case .scale1to10:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: Spacing.sm) {
                ForEach(1...10, id: \.self) { value in
                    manualOptionButton("\(value)") {
                        submitManualAnswer(value)
                    }
                }
            }

        case .scale0to4:
            VStack(spacing: Spacing.sm) {
                ForEach(0...4, id: \.self) { value in
                    manualOptionButton(severityLabel(for: value)) {
                        submitManualAnswer(value)
                    }
                }
            }

        case .scale0to3:
            VStack(spacing: Spacing.sm) {
                ForEach(0...3, id: \.self) { value in
                    manualOptionButton(frequencyLabel(for: value)) {
                        submitManualAnswer(value)
                    }
                }
            }

        default:
            Text("Please use voice input for this question type.")
                .font(.system(size: Typography.body))
                .foregroundColor(theme.secondaryText)
        }
    }

    private func manualOptionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: Typography.body, weight: .medium))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.cardBackground)
                .cornerRadius(10)
        }
    }

    private func severityLabel(for value: Int) -> String {
        switch value {
        case 0: return "None"
        case 1: return "Mild"
        case 2: return "Moderate"
        case 3: return "Severe"
        case 4: return "Very Severe"
        default: return "\(value)"
        }
    }

    private func frequencyLabel(for value: Int) -> String {
        switch value {
        case 0: return "Not at all"
        case 1: return "Several days"
        case 2: return "More than half the days"
        case 3: return "Nearly every day"
        default: return "\(value)"
        }
    }

    private func submitManualAnswer(_ value: Any) {
        showManualFallback = false
        // TODO: Submit manual answer through session manager
    }

    // MARK: - Computed Properties

    private var orbState: ZoeOrbState {
        switch sessionManager.state {
        case .introducingZoe, .transitioning, .redirecting:
            return sessionManager.isZoeSpeaking ? .speaking : .idle
        case .listening:
            return .listening
        case .processing:
            return .thinking
        default:
            return sessionManager.isZoeSpeaking ? .speaking : .idle
        }
    }

    private var statusColor: Color {
        switch sessionManager.state {
        case .listening:
            return .red
        case .processing:
            return .orange
        case .confirming:
            return .green
        case .error:
            return .red
        default:
            return sessionManager.isZoeSpeaking ? .blue : .gray
        }
    }

    private var statusText: String {
        switch sessionManager.state {
        case .introducingZoe:
            return "Zoe is speaking"
        case .awaitingResponse:
            return "Your turn"
        case .listening:
            return "Listening"
        case .processing:
            return "Processing"
        case .confirming:
            return "Confirming"
        case .transitioning:
            return "Moving on"
        case .redirecting:
            return "Clarifying"
        case .error:
            return "Error"
        default:
            return "Ready"
        }
    }

    private var isRecording: Bool {
        sessionManager.state == .listening
    }

    private var canStartRecording: Bool {
        sessionManager.state == .awaitingResponse
    }

    private var canInteract: Bool {
        switch sessionManager.state {
        case .awaitingResponse, .listening:
            return true
        default:
            return false
        }
    }

    private var canRepeat: Bool {
        switch sessionManager.state {
        case .awaitingResponse, .confirming:
            return true
        default:
            return false
        }
    }

    private var canSkip: Bool {
        sessionManager.state == .awaitingResponse
    }

    // MARK: - Actions

    private func startSession() {
        Task {
            await sessionManager.startSession(forDay: dayNumber)
        }
    }
}

// MARK: - Preview

#Preview("Voice Assessment - Day 1") {
    VoiceAssessmentView(
        dayNumber: 1,
        onComplete: { print("Complete") },
        onDismiss: { print("Dismiss") }
    )
}

#Preview("Voice Assessment - Day 7") {
    VoiceAssessmentView(
        dayNumber: 7,
        onComplete: { print("Complete") },
        onDismiss: { print("Dismiss") }
    )
}
