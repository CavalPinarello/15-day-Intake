//
//  VoiceCheckInView.swift
//  ZoeSleep
//
//  Full-screen voice check-in experience
//  Three-step flow: Energy -> Mood -> Focus using voice input
//  Designed for accessibility with large touch targets and TTS
//

import SwiftUI

/// Full-screen voice check-in view
struct VoiceCheckInView: View {
    @StateObject private var viewModel: VoiceCheckInFlowViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var audioManager = AudioSessionManager.shared
    @Environment(\.dismiss) private var dismiss

    private var theme: ColorTheme { themeManager.currentTheme }

    init(timeSlot: CheckInTimeSlot) {
        _viewModel = StateObject(wrappedValue: VoiceCheckInFlowViewModel(timeSlot: timeSlot))
    }

    var body: some View {
        ZStack {
            // Background
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                Spacer()

                // Main content
                mainContent

                Spacer()

                // Bottom controls
                bottomControls
            }
            .padding()

            // Success overlay
            if viewModel.flowState == .completed {
                completionOverlay
            }
        }
        .onAppear {
            Task {
                // Speak the initial prompt
                await viewModel.speakCurrentPrompt()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.md) {
            // Close button and title
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                        .frame(width: 44, height: 44)
                        .background(theme.cardBackground.opacity(0.5))
                        .clipShape(Circle())
                }

                Spacer()

                // Time slot indicator
                HStack(spacing: 4) {
                    Image(systemName: viewModel.timeSlot.sfSymbol)
                    Text(viewModel.timeSlot.label)
                }
                .font(.system(size: Typography.body, weight: .medium))
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.cardBackground.opacity(0.5))
                .clipShape(Capsule())
            }

            // Progress indicator
            progressIndicator
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: Spacing.md) {
            ForEach(VoiceCheckInStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    // Step icon
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 44, height: 44)

                        if isStepCompleted(step) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(theme.textOnPrimary)
                        } else {
                            Image(systemName: step.sfSymbol)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(step == viewModel.currentStep ? theme.textOnPrimary : theme.secondaryText)
                        }
                    }

                    // Step label
                    Text(step.title)
                        .font(.system(size: Typography.caption, weight: step == viewModel.currentStep ? .semibold : .regular))
                        .foregroundColor(step == viewModel.currentStep ? theme.primaryText : theme.secondaryText)
                }

                if step != .focus {
                    // Connector line
                    Rectangle()
                        .fill(isStepCompleted(step) ? theme.accent : theme.cardBackground)
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                }
            }
        }
        .padding(.top, Spacing.sm)
    }

    private func stepColor(for step: VoiceCheckInStep) -> Color {
        if isStepCompleted(step) {
            return theme.success
        } else if step == viewModel.currentStep {
            return theme.accent
        } else {
            return theme.cardBackground
        }
    }

    private func isStepCompleted(_ step: VoiceCheckInStep) -> Bool {
        switch step {
        case .energy: return viewModel.selectedEnergy != nil
        case .mood: return viewModel.selectedMood != nil
        case .focus: return viewModel.selectedFocus != nil
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: Spacing.xl) {
            // Zoe Orb
            ZoeOrbView(state: viewModel.orbState, audioLevel: audioManager.audioLevel)
                .frame(width: 200, height: 200)

            // Current step prompt
            VStack(spacing: Spacing.sm) {
                Text(viewModel.currentStep.promptText)
                    .font(.system(size: Typography.title2, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.primaryText)
                    .multilineTextAlignment(.center)

                Text(viewModel.currentStep.helpText)
                    .font(.system(size: Typography.body))
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.lg)

            // Confirmation display
            if viewModel.showConfirmation, let displayValue = viewModel.currentDisplayValue {
                confirmationCard(displayValue)
            }

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: Typography.body))
                    .foregroundColor(theme.error)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(theme.error.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }

    private func confirmationCard(_ value: String) -> some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                if let icon = viewModel.currentDisplayIcon {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.currentDisplayColor ?? theme.accent)
                }

                Text(value)
                    .font(.system(size: Typography.title2, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primaryText)
            }

            HStack(spacing: Spacing.md) {
                Button(action: { viewModel.retry() }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Try Again")
                    }
                    .font(.system(size: Typography.body, weight: .medium))
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(theme.cardBackground)
                    .cornerRadius(12)
                }

                Button(action: { viewModel.confirmAndContinue() }) {
                    HStack {
                        Image(systemName: viewModel.currentStep.isLast ? "checkmark" : "arrow.right")
                        Text(viewModel.currentStep.isLast ? "Submit" : "Next")
                    }
                    .font(.system(size: Typography.body, weight: .semibold))
                    .foregroundColor(theme.textOnPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(theme.accent)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3), value: viewModel.showConfirmation)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: Spacing.lg) {
            // Voice input button
            if !viewModel.showConfirmation {
                voiceInputButton
            }

            // Manual selection fallback
            manualSelectionRow
        }
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
                        .shadow(color: theme.accent.opacity(0.3), radius: viewModel.isRecording ? 15 : 8)

                    // Audio level ring
                    if viewModel.isRecording {
                        Circle()
                            .stroke(theme.accent.opacity(0.5), lineWidth: 3)
                            .frame(width: 80 + CGFloat(audioManager.audioLevel * 30),
                                   height: 80 + CGFloat(audioManager.audioLevel * 30))
                            .animation(.easeOut(duration: 0.1), value: audioManager.audioLevel)
                    }

                    // Icon
                    if viewModel.flowState == .processing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.textOnPrimary))
                            .scaleEffect(1.5)
                    } else {
                        Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(theme.textOnPrimary)
                            .symbolEffect(.variableColor, isActive: viewModel.isRecording)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if viewModel.flowState == .ready {
                            Task { await viewModel.startRecording() }
                        }
                    }
                    .onEnded { _ in
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        }
                    }
            )
            .disabled(viewModel.flowState == .processing || viewModel.flowState == .submitting)

            // Status text
            Text(statusText)
                .font(.system(size: Typography.body, weight: .medium))
                .foregroundColor(viewModel.isRecording ? Color.red : theme.secondaryText)
        }
    }

    private var buttonBackgroundColor: Color {
        if viewModel.flowState == .processing {
            return theme.accent.opacity(0.6)
        } else if viewModel.isRecording {
            return Color.red
        } else {
            return theme.accent
        }
    }

    private var statusText: String {
        switch viewModel.flowState {
        case .ready:
            return "Hold to speak"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .confirming:
            return "Is this correct?"
        case .transitioning:
            return "Moving on..."
        case .submitting:
            return "Saving..."
        case .completed:
            return "Done!"
        case .error:
            return "Try again"
        }
    }

    private var manualSelectionRow: some View {
        VStack(spacing: Spacing.sm) {
            Text("Or tap to select:")
                .font(.system(size: Typography.caption))
                .foregroundColor(theme.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    switch viewModel.currentStep {
                    case .energy:
                        ForEach(EnergyLevel.allCases, id: \.rawValue) { level in
                            manualOptionButton(
                                label: level.shortLabel,
                                icon: level.sfSymbol,
                                color: level.color,
                                isSelected: viewModel.selectedEnergy == level
                            ) {
                                viewModel.selectEnergy(level)
                            }
                        }
                    case .mood:
                        ForEach(MoodLevel.allCases, id: \.rawValue) { level in
                            manualOptionButton(
                                label: level.label,
                                icon: level.sfSymbol,
                                color: level.color,
                                isSelected: viewModel.selectedMood == level
                            ) {
                                viewModel.selectMood(level)
                            }
                        }
                    case .focus:
                        ForEach(FocusLevel.allCases, id: \.rawValue) { level in
                            manualOptionButton(
                                label: level.label,
                                icon: level.sfSymbol,
                                color: level.color,
                                isSelected: viewModel.selectedFocus == level
                            ) {
                                viewModel.selectFocus(level)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func manualOptionButton(
        label: String,
        icon: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: Typography.caption2, weight: .medium))
            }
            .foregroundColor(isSelected ? theme.textOnPrimary : color)
            .frame(width: 60, height: 60)
            .background(isSelected ? color : theme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.5), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(theme.success)
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Check-in Complete!")
                    .font(.system(size: Typography.title2, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Summary
                VStack(spacing: Spacing.md) {
                    if let energy = viewModel.selectedEnergy {
                        summaryRow(label: "Energy", value: energy.label, icon: energy.sfSymbol, color: energy.color)
                    }
                    if let mood = viewModel.selectedMood {
                        summaryRow(label: "Mood", value: mood.label, icon: mood.sfSymbol, color: mood.color)
                    }
                    if let focus = viewModel.selectedFocus {
                        summaryRow(label: "Focus", value: focus.label, icon: focus.sfSymbol, color: focus.color)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.system(size: Typography.body, weight: .semibold))
                        .foregroundColor(theme.textOnPrimary)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(theme.accent)
                        .cornerRadius(16)
                }
            }
            .padding()
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: viewModel.flowState)
    }

    private func summaryRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: Typography.body))
                .foregroundColor(theme.secondaryText)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: Typography.body, weight: .medium))
                    .foregroundColor(theme.primaryText)
            }
        }
    }
}

// MARK: - Preview

#Preview("Voice Check-In") {
    VoiceCheckInView(timeSlot: .morning)
}
