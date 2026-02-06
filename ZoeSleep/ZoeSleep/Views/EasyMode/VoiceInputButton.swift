//
//  VoiceInputButton.swift
//  ZoeSleep
//
//  Large microphone button for Easy Mode voice input
//  Shows visual feedback for recording state and audio levels
//

import SwiftUI

/// Large, accessible microphone button for voice input
/// Designed for elderly users with oversized tap target (80pt+)
struct VoiceInputButton: View {
    // State
    @ObservedObject var easyModeManager = EasyModeManager.shared
    @ObservedObject var audioManager = AudioSessionManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    // Callbacks
    let onRecordingStarted: () -> Void
    let onRecordingStopped: () -> Void

    // Animation state
    @State private var isPressing = false
    @State private var pulseScale: CGFloat = 1.0

    private var theme: ColorTheme { themeManager.currentTheme }
    private var isRecording: Bool { audioManager.isRecording }
    private var isProcessing: Bool { easyModeManager.voiceState.isProcessing }

    // Button size - extra large for elderly users
    private let buttonSize: CGFloat = 100
    private let pulseRingSize: CGFloat = 130

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Main button
            ZStack {
                // Pulse ring (visible when recording)
                if isRecording {
                    Circle()
                        .stroke(theme.accent.opacity(0.3), lineWidth: 3)
                        .frame(width: pulseRingSize, height: pulseRingSize)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)

                    // Audio level ring
                    Circle()
                        .stroke(theme.accent.opacity(0.5), lineWidth: 4)
                        .frame(width: buttonSize + CGFloat(audioManager.audioLevel * 30), height: buttonSize + CGFloat(audioManager.audioLevel * 30))
                        .animation(.easeOut(duration: 0.1), value: audioManager.audioLevel)
                }

                // Button background
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(color: theme.accent.opacity(0.3), radius: isRecording ? 15 : 8, x: 0, y: 4)

                // Microphone icon or processing indicator
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.textOnPrimary))
                        .scaleEffect(1.5)
                } else {
                    Image(systemName: isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(theme.textOnPrimary)
                        .symbolEffect(.variableColor, isActive: isRecording)
                }
            }
            .scaleEffect(isPressing ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressing)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing && !isProcessing {
                            startRecording()
                        }
                    }
                    .onEnded { _ in
                        if isPressing {
                            stopRecording()
                        }
                    }
            )
            .disabled(isProcessing)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Hold to speak your answer")
            .accessibilityAddTraits(isRecording ? .startsMediaSession : [])

            // Status text
            Text(statusText)
                .font(.system(size: Typography.headline, weight: .semibold, design: .rounded))
                .foregroundColor(statusTextColor)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: easyModeManager.voiceState)
        }
        .onAppear {
            startPulseAnimation()
        }
    }

    // MARK: - Computed Properties

    private var buttonBackgroundColor: Color {
        if isProcessing {
            return theme.accent.opacity(0.6)
        } else if isRecording {
            return Color.red
        } else {
            return theme.accent
        }
    }

    private var statusText: String {
        switch easyModeManager.voiceState {
        case .idle:
            return "Hold to speak"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .parsing:
            return "Understanding..."
        case .confirming:
            return "Is this correct?"
        case .error(let error):
            return error.userMessage
        }
    }

    private var statusTextColor: Color {
        switch easyModeManager.voiceState {
        case .error:
            return theme.error
        case .listening:
            return Color.red
        default:
            return theme.secondaryText
        }
    }

    private var accessibilityLabel: String {
        if isProcessing {
            return "Processing your response"
        } else if isRecording {
            return "Recording. Release to stop."
        } else {
            return "Voice input button"
        }
    }

    // MARK: - Actions

    private func startRecording() {
        isPressing = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        Task {
            do {
                try await easyModeManager.startRecording()
                onRecordingStarted()
            } catch {
                isPressing = false
                print("VoiceInputButton: Failed to start recording: \(error)")
            }
        }
    }

    private func stopRecording() {
        isPressing = false

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        onRecordingStopped()
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulseScale = 1.5
        }
    }
}

// MARK: - Compact Voice Button (for inline use)

/// Smaller voice input button for use in forms
struct CompactVoiceInputButton: View {
    @ObservedObject var easyModeManager = EasyModeManager.shared
    @ObservedObject var audioManager = AudioSessionManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    let onRecordingStarted: () -> Void
    let onRecordingStopped: () -> Void

    @State private var isPressing = false

    private var theme: ColorTheme { themeManager.currentTheme }
    private var isRecording: Bool { audioManager.isRecording }
    private var isProcessing: Bool { easyModeManager.voiceState.isProcessing }

    private let buttonSize: CGFloat = 60

    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(isRecording ? Color.red : theme.accent)
                .frame(width: buttonSize, height: buttonSize)

            // Audio level indicator
            if isRecording {
                Circle()
                    .stroke(theme.accent.opacity(0.5), lineWidth: 2)
                    .frame(width: buttonSize + CGFloat(audioManager.audioLevel * 20), height: buttonSize + CGFloat(audioManager.audioLevel * 20))
                    .animation(.easeOut(duration: 0.1), value: audioManager.audioLevel)
            }

            // Icon
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: theme.textOnPrimary))
            } else {
                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(theme.textOnPrimary)
            }
        }
        .scaleEffect(isPressing ? 0.9 : 1.0)
        .animation(.spring(response: 0.2), value: isPressing)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressing && !isProcessing {
                        isPressing = true
                        Task {
                            try? await easyModeManager.startRecording()
                            onRecordingStarted()
                        }
                    }
                }
                .onEnded { _ in
                    if isPressing {
                        isPressing = false
                        onRecordingStopped()
                    }
                }
        )
        .disabled(isProcessing)
        .accessibilityLabel(isRecording ? "Recording" : "Voice input")
        .accessibilityHint("Hold to speak")
    }
}

// MARK: - Preview

#Preview("Voice Input Button") {
    VStack(spacing: 40) {
        VoiceInputButton(
            onRecordingStarted: { print("Started") },
            onRecordingStopped: { print("Stopped") }
        )

        CompactVoiceInputButton(
            onRecordingStarted: { print("Started") },
            onRecordingStopped: { print("Stopped") }
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
