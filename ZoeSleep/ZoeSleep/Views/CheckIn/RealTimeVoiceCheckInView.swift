//
//  RealTimeVoiceCheckInView.swift
//  ZoeSleep
//
//  Real-time voice-based check-in using ElevenLabs Conversational AI.
//  Provides instant transcription and natural conversation flow.
//

import SwiftUI
import Combine

/// Real-time voice check-in view using ElevenLabs Conversational AI
struct RealTimeVoiceCheckInView: View {
    @StateObject private var viewModel: RealTimeVoiceCheckInViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    @Environment(\.dismiss) private var dismiss

    let timeSlot: CheckInTimeSlot
    let onComplete: () -> Void

    init(timeSlot: CheckInTimeSlot, onComplete: @escaping () -> Void) {
        self.timeSlot = timeSlot
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: RealTimeVoiceCheckInViewModel(timeSlot: timeSlot))
    }

    var body: some View {
        ZStack {
            // Background
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                Spacer()

                // Central orb and status
                centralContent

                Spacer()

                // Transcript display
                transcriptView

                // Bottom controls
                controlsView
            }
        }
        .onAppear {
            Task {
                await viewModel.startSession()
            }
        }
        .onDisappear {
            viewModel.endSession()
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete {
                onComplete()
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button {
                viewModel.endSession()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(theme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(theme.cardBackground.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(timeSlot.label)
                    .font(.headline)
                    .foregroundColor(theme.primaryText)

                Text("Check-In")
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index < viewModel.completedSteps ? theme.success : theme.cardBackground)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 44)
        }
        .padding()
    }

    // MARK: - Central Content

    private var centralContent: some View {
        VStack(spacing: 24) {
            // Status text
            Text(viewModel.statusMessage)
                .font(.title3)
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .animation(.easeInOut, value: viewModel.statusMessage)

            // Animated orb
            ZoeConversationOrb(
                state: viewModel.orbState,
                audioLevel: viewModel.audioLevel,
                theme: theme
            )
            .frame(width: 160, height: 160)

            // Current step indicator
            if let currentStep = viewModel.currentStep {
                HStack(spacing: 8) {
                    Image(systemName: currentStep.icon)
                        .font(.title2)
                    Text(currentStep.label)
                        .font(.headline)
                }
                .foregroundColor(theme.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(theme.accent.opacity(0.15))
                .cornerRadius(20)
            }
        }
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        VStack(spacing: 8) {
            // Agent message
            if !viewModel.agentMessage.isEmpty {
                Text(viewModel.agentMessage)
                    .font(.body)
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            // User transcript (real-time)
            if !viewModel.userTranscript.isEmpty && viewModel.isListening {
                Text(viewModel.userTranscript)
                    .font(.title3)
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            // Captured values
            if viewModel.capturedEnergy != nil || viewModel.capturedMood != nil || viewModel.capturedFocus != nil {
                HStack(spacing: 16) {
                    if let energy = viewModel.capturedEnergy {
                        CapturedValueBadge(icon: "bolt.fill", label: energy.label, color: energy.color)
                    }
                    if let mood = viewModel.capturedMood {
                        CapturedValueBadge(icon: "face.smiling.fill", label: mood.label, color: mood.color)
                    }
                    if let focus = viewModel.capturedFocus {
                        CapturedValueBadge(icon: "eye.fill", label: focus.label, color: focus.color)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(minHeight: 100)
        .padding(.horizontal)
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: 16) {
            // Main action button
            Button {
                if viewModel.isListening {
                    viewModel.stopListening()
                } else if viewModel.isConnected {
                    viewModel.startListening()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isListening ? Color.red : theme.accent)
                        .frame(width: 80, height: 80)
                        .shadow(color: (viewModel.isListening ? Color.red : theme.accent).opacity(0.4), radius: 10)

                    Image(systemName: viewModel.isListening ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .disabled(!viewModel.isConnected)
            .opacity(viewModel.isConnected ? 1.0 : 0.5)

            // Hint text
            Text(viewModel.isListening ? "Tap to finish speaking" : "Tap to speak")
                .font(.caption)
                .foregroundColor(theme.secondaryText)

            // Manual input fallback
            if viewModel.showManualFallback {
                Button("Type instead") {
                    viewModel.switchToManualInput()
                }
                .font(.subheadline)
                .foregroundColor(theme.accent)
            }
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Captured Value Badge

private struct CapturedValueBadge: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption.bold())
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Zoe Conversation Orb

struct ZoeConversationOrb: View {
    let state: ConversationOrbState
    let audioLevel: Float
    let theme: ColorTheme

    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(orbColor.opacity(0.3), lineWidth: 2)
                .frame(width: 160, height: 160)
                .scaleEffect(pulseScale)

            // Middle ring
            Circle()
                .stroke(orbColor.opacity(0.5), lineWidth: 3)
                .frame(width: 130, height: 130)
                .scaleEffect(state == .listening ? 1.0 + CGFloat(audioLevel) * 0.2 : 1.0)

            // Inner orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [orbColor, orbColor.opacity(0.7)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)

            // Icon
            Image(systemName: orbIcon)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.white)
                .rotationEffect(.degrees(state == .thinking ? rotationAngle : 0))
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: state) { _, _ in
            startAnimations()
        }
    }

    private var orbColor: Color {
        switch state {
        case .idle: return theme.accent
        case .listening: return Color.green
        case .thinking: return Color.orange
        case .speaking: return theme.accent
        case .error: return Color.red
        }
    }

    private var orbIcon: String {
        switch state {
        case .idle: return "waveform"
        case .listening: return "mic.fill"
        case .thinking: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = state == .idle ? 1.0 : 1.1
        }

        if state == .thinking {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        } else {
            rotationAngle = 0
        }
    }
}

enum ConversationOrbState {
    case idle
    case listening
    case thinking
    case speaking
    case error
}

// MARK: - Check-In Step

enum RealTimeCheckInStep {
    case energy
    case mood
    case focus

    var label: String {
        switch self {
        case .energy: return "Energy"
        case .mood: return "Mood"
        case .focus: return "Focus"
        }
    }

    var icon: String {
        switch self {
        case .energy: return "bolt.fill"
        case .mood: return "face.smiling.fill"
        case .focus: return "eye.fill"
        }
    }

    var next: RealTimeCheckInStep? {
        switch self {
        case .energy: return .mood
        case .mood: return .focus
        case .focus: return nil
        }
    }
}

// MARK: - Preview

#Preview {
    RealTimeVoiceCheckInView(
        timeSlot: .morning,
        onComplete: {}
    )
    .environmentObject(ThemeManager.shared)
}
