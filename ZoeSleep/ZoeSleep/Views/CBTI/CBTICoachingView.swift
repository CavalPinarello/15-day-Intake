//
//  CBTICoachingView.swift
//  ZoeSleep
//
//  Main view for CBT-I (Cognitive Behavioral Therapy for Insomnia) coaching sessions.
//  Provides real-time voice-based therapy using ElevenLabs Conversational AI.
//

import SwiftUI

struct CBTICoachingView: View {
    @StateObject private var sessionManager = CBTISessionManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    let sessionType: CBTISessionType

    @State private var showEndConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                sessionHeader

                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // Session state indicator
                        sessionStateView

                        // Conversation display
                        conversationView

                        // Current exercise or thought record
                        activeComponentView
                    }
                    .padding()
                }

                // Voice control area
                voiceControlArea
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showEndConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.secondaryText)
                }
            }

            ToolbarItem(placement: .principal) {
                Text(sessionType.displayName)
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
            }
        }
        .alert("End Session?", isPresented: $showEndConfirmation) {
            Button("Continue Session", role: .cancel) { }
            Button("End Session", role: .destructive) {
                Task {
                    await sessionManager.endSession()
                    dismiss()
                }
            }
        } message: {
            Text("Your progress will be saved. You can continue this session later.")
        }
        .task {
            await startSession()
        }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        VStack(spacing: 8) {
            // Progress indicator
            HStack {
                ForEach(CBTISessionType.allCases, id: \.self) { type in
                    Circle()
                        .fill(sessionManager.progress.sessionsCompleted.contains(type) ? theme.accent : theme.cardBackground.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 8)

            // Session info
            HStack {
                Image(systemName: sessionType.sfSymbol)
                    .font(.title3)
                Text("\(sessionType.estimatedMinutes) min")
                    .font(.caption)
            }
            .foregroundColor(theme.secondaryText)
        }
        .padding(.horizontal)
    }

    // MARK: - Session State View

    @ViewBuilder
    private var sessionStateView: some View {
        switch sessionManager.sessionState {
        case .notStarted:
            connectingView

        case .introduction:
            introductionView

        case .mainContent, .review, .homework:
            mainSessionView

        case .exercise(let exercise):
            RelaxationExerciseView(exercise: exercise)

        case .paused:
            pausedView

        case .completed:
            completedView

        case .error(let message):
            errorView(message)
        }
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(theme.accent)

            Text("Connecting to Zoe...")
                .font(.headline)
                .foregroundColor(theme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var introductionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 48))
                .foregroundColor(theme.accent)

            Text("Getting Started")
                .font(.title2.bold())
                .foregroundColor(theme.primaryText)

            Text(sessionType.description)
                .font(.body)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var mainSessionView: some View {
        VStack(spacing: 16) {
            // Zoe avatar with speaking indicator
            ZoeAvatarView(isSpeaking: sessionManager.isSpeaking)

            // Current message
            if !sessionManager.agentMessage.isEmpty {
                Text(sessionManager.agentMessage)
                    .font(.body)
                    .foregroundColor(theme.primaryText)
                    .padding()
                    .background(theme.cardBackground)
                    .cornerRadius(16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.vertical)
    }

    private var pausedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(theme.accent)

            Text("Session Paused")
                .font(.title2.bold())
                .foregroundColor(theme.primaryText)

            Button {
                sessionManager.resumeSession()
            } label: {
                Label("Resume Session", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundColor(theme.textOnPrimary)
                    .padding()
                    .background(theme.accent)
                    .cornerRadius(12)
            }
        }
    }

    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Session Complete!")
                .font(.title2.bold())
                .foregroundColor(theme.primaryText)

            Text("Great work on completing today's session.")
                .font(.body)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(theme.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.accent)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                Task { await startSession() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(theme.textOnPrimary)
                    .padding()
                    .background(theme.accent)
                    .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Conversation View

    private var conversationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(sessionManager.conversationHistory.suffix(5).enumerated()), id: \.offset) { index, message in
                ConversationBubble(
                    text: message.text,
                    isUser: message.role == "user",
                    theme: theme
                )
            }
        }
        .animation(.easeInOut, value: sessionManager.conversationHistory.count)
    }

    // MARK: - Active Component View

    @ViewBuilder
    private var activeComponentView: some View {
        // Thought record if active
        if let record = sessionManager.currentThoughtRecord {
            ThoughtRecordCardView(record: record)
        }

        // Sleep window if calculated
        if let window = sessionManager.currentSleepWindow {
            SleepWindowCard(sleepWindow: window)
        }
    }

    // MARK: - Voice Control Area

    private var voiceControlArea: some View {
        VStack(spacing: 16) {
            // User transcript display
            if !sessionManager.userTranscript.isEmpty && sessionManager.isListening {
                Text(sessionManager.userTranscript)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            // Voice button
            HStack(spacing: 24) {
                // Mute/unmute button
                Button {
                    if sessionManager.isListening {
                        sessionManager.stopListening()
                    } else {
                        sessionManager.startListening()
                    }
                } label: {
                    VoiceOrbView(
                        isListening: sessionManager.isListening,
                        audioLevel: 0.5,
                        size: 80
                    )
                }
                .disabled(!sessionManager.isConnected || sessionManager.isSpeaking)

                // Interrupt button (shown when agent is speaking)
                if sessionManager.isSpeaking {
                    Button {
                        sessionManager.interruptAgent()
                    } label: {
                        Image(systemName: "hand.raised.fill")
                            .font(.title2)
                            .foregroundColor(theme.primaryText)
                            .padding()
                            .background(theme.cardBackground)
                            .clipShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: sessionManager.isSpeaking)

            // Hint text
            Text(voiceHintText)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
        }
        .padding()
        .background(
            theme.cardBackground
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var voiceHintText: String {
        if !sessionManager.isConnected {
            return "Connecting..."
        } else if sessionManager.isSpeaking {
            return "Tap hand to interrupt"
        } else if sessionManager.isListening {
            return "Listening... tap when done"
        } else {
            return "Tap to speak"
        }
    }

    // MARK: - Actions

    private func startSession() async {
        do {
            try await sessionManager.startSession(type: sessionType)
        } catch {
            print("[CBTICoachingView] Failed to start session: \(error)")
        }
    }
}

// MARK: - Conversation Bubble

struct ConversationBubble: View {
    let text: String
    let isUser: Bool
    let theme: ColorTheme

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(text)
                .font(.subheadline)
                .foregroundColor(isUser ? theme.textOnPrimary : theme.primaryText)
                .padding(12)
                .background(isUser ? theme.accent : theme.cardBackground)
                .cornerRadius(16)

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Zoe Avatar View

struct ZoeAvatarView: View {
    let isSpeaking: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }
    @State private var animationPhase: Double = 0

    var body: some View {
        ZStack {
            // Outer ring (speaking indicator)
            Circle()
                .stroke(theme.accent.opacity(isSpeaking ? 0.3 : 0), lineWidth: 4)
                .frame(width: 100, height: 100)
                .scaleEffect(isSpeaking ? 1.2 : 1.0)
                .animation(
                    isSpeaking ?
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                        .easeInOut,
                    value: isSpeaking
                )

            // Avatar circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.accent, theme.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)

            // Zoe letter
            Text("Z")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(theme.textOnPrimary)
        }
    }
}

// MARK: - Voice Orb View

struct VoiceOrbView: View {
    let isListening: Bool
    let audioLevel: Float
    let size: CGFloat

    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer pulse
            if isListening {
                Circle()
                    .fill(theme.accent.opacity(0.2))
                    .frame(width: size * 1.5, height: size * 1.5)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
            }

            // Main orb
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.accent,
                            theme.accent.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Microphone icon
            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: size * 0.35))
                .foregroundColor(theme.textOnPrimary)
        }
        .onAppear {
            if isListening {
                pulseScale = 1.2
            }
        }
        .onChange(of: isListening) { _, newValue in
            pulseScale = newValue ? 1.2 : 1.0
        }
    }
}

// MARK: - Sleep Window Card

struct SleepWindowCard: View {
    let sleepWindow: SleepWindow
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundColor(theme.accent)
                Text("Your Sleep Window")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                Spacer()
            }

            HStack(spacing: 24) {
                VStack {
                    Text("Bedtime")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    Text(timeFormatter.string(from: sleepWindow.bedtime))
                        .font(.title2.bold())
                        .foregroundColor(theme.primaryText)
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(theme.secondaryText)

                VStack {
                    Text("Wake Time")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    Text(timeFormatter.string(from: sleepWindow.wakeTime))
                        .font(.title2.bold())
                        .foregroundColor(theme.primaryText)
                }
            }

            Text(sleepWindow.timeInBed + " in bed")
                .font(.subheadline)
                .foregroundColor(theme.accent)
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Thought Record Card

struct ThoughtRecordCardView: View {
    let record: ThoughtRecord
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(theme.accent)
                Text("Thought Record")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                Spacer()

                if record.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            if !record.situation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Situation")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    Text(record.situation)
                        .font(.subheadline)
                        .foregroundColor(theme.primaryText)
                }
            }

            if !record.automaticThought.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic Thought")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    Text(record.automaticThought)
                        .font(.subheadline)
                        .foregroundColor(theme.primaryText)
                }
            }

            if let balanced = record.balancedThought {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balanced Thought")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    Text(balanced)
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }

            // Emotion intensity comparison
            if let reduction = record.emotionReduction, reduction > 0 {
                HStack {
                    Text("Emotion reduced by")
                    Text("\(reduction)%")
                        .bold()
                        .foregroundColor(.green)
                }
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            }
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Relaxation Exercise View

struct RelaxationExerciseView: View {
    let exercise: RelaxationExercise
    @StateObject private var sessionManager = CBTISessionManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 24) {
            // Exercise icon
            Image(systemName: exercise.sfSymbol)
                .font(.system(size: 60))
                .foregroundColor(theme.accent)

            Text(exercise.displayName)
                .font(.title2.bold())
                .foregroundColor(theme.primaryText)

            Text(exercise.description)
                .font(.body)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)

            // Progress indicator
            VStack(spacing: 8) {
                ProgressView(value: sessionManager.exerciseProgress)
                    .tint(theme.accent)

                Text("\(Int(sessionManager.exerciseProgress * 100))% complete")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.vertical)

            // Skip button
            Button {
                sessionManager.skipRelaxationExercise()
            } label: {
                Text("Skip Exercise")
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
            }
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(20)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CBTICoachingView(sessionType: .introduction)
            .environmentObject(ThemeManager.shared)
    }
}
