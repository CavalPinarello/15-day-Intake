//
//  HumeVoiceIntakeView.swift
//  ZoeSleep
//
//  Voice-first questionnaire intake powered by Hume EVI.
//  Replaces: VoiceConversationView, SeamlessVoiceQuestionnaireView
//

import SwiftUI

struct HumeVoiceIntakeView: View {
    let dayNumber: Int
    let section: String  // "sleepLog", "assessment", or "all"
    let userName: String
    let onComplete: () -> Void
    let onSwitchToManual: ([VoiceQuestionState]) -> Void

    @StateObject private var orchestrator = VoiceQuestionnaireOrchestrator()
    @ObservedObject private var voiceService = HumeVoiceService.shared
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var showEndConfirmation = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            // Circadian background
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer()

                // Main content area
                mainContent

                Spacer()

                // Transcript area
                transcriptArea

                // Bottom controls
                bottomControls
            }
            .padding()
        }
        .task {
            await orchestrator.startSession(
                dayNumber: dayNumber,
                section: section,
                userName: userName
            )
        }
        .onChange(of: orchestrator.state) { newState in
            if case .completed = newState {
                onComplete()
            }
        }
        .onChange(of: orchestrator.useManualInput) { switchedToManual in
            if switchedToManual {
                onSwitchToManual(orchestrator.remainingQuestions)
            }
        }
        .alert("End Session?", isPresented: $showEndConfirmation) {
            Button("Continue", role: .cancel) {}
            Button("End Session", role: .destructive) {
                Task { await orchestrator.endSession() }
            }
        } message: {
            Text("You've answered \(orchestrator.questionsCompleted) of \(orchestrator.totalQuestions) questions. End early?")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Progress
            VStack(alignment: .leading, spacing: 4) {
                Text("Day \(dayNumber) - \(sectionTitle)")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)

                HStack(spacing: 8) {
                    ProgressView(value: orchestrator.progress)
                        .tint(theme.accent)
                        .frame(width: 120)

                    Text("\(orchestrator.questionsCompleted)/\(orchestrator.totalQuestions)")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
            }

            Spacer()

            // Emotion indicator
            if !voiceService.currentEmotions.isEmpty {
                emotionBadge
            }

            // Close button
            Button {
                showEndConfirmation = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(theme.secondaryText)
            }
        }
    }

    // MARK: - Main Content (Orb)

    private var mainContent: some View {
        VStack(spacing: 24) {
            // Zoe Orb
            ZoeOrbView(
                state: orbState,
                audioLevel: voiceService.audioLevel
            )
            .frame(width: 200, height: 200)

            // State label
            Text(stateLabel)
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
                .animation(.easeInOut, value: stateLabel)
        }
    }

    // MARK: - Transcript Area

    private var transcriptArea: some View {
        VStack(spacing: 12) {
            // Assistant message
            if !voiceService.currentAssistantMessage.isEmpty {
                Text(voiceService.currentAssistantMessage)
                    .font(.body)
                    .foregroundColor(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            // User transcript
            if !voiceService.currentUserTranscript.isEmpty {
                Text(voiceService.currentUserTranscript)
                    .font(.callout)
                    .foregroundColor(theme.secondaryText)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
        }
        .frame(minHeight: 80)
        .animation(.easeInOut(duration: 0.3), value: voiceService.currentAssistantMessage)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 20) {
            // Switch to typing
            Button {
                orchestrator.switchToManualInput()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                    Text("Type instead")
                }
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(theme.cardBackground)
                )
            }

            Spacer()

            // Mute toggle
            Button {
                // TODO: implement mute (send silence frames)
            } label: {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundColor(theme.accent)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(theme.cardBackground)
                    )
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Emotion Badge

    private var emotionBadge: some View {
        let dominantEmotion = voiceService.currentEmotions
            .max(by: { $0.value < $1.value })
            .flatMap { SleepRelevantEmotion(rawValue: $0.key) }

        return Group {
            if let emotion = dominantEmotion {
                HStack(spacing: 4) {
                    Image(systemName: emotion.sfSymbol)
                        .font(.caption)
                    Text(emotion.displayName)
                        .font(.caption2)
                }
                .foregroundColor(emotion.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(emotion.color.opacity(0.15))
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var sectionTitle: String {
        switch section {
        case "sleepLog": return "Sleep Diary"
        case "assessment": return "Assessment"
        default: return "Check-in"
        }
    }

    private var orbState: ZoeOrbState {
        switch voiceService.state {
        case .listening: return .listening
        case .speaking: return .speaking
        case .thinking: return .thinking
        default: return .idle
        }
    }

    private var stateLabel: String {
        switch orchestrator.state {
        case .loading: return "Loading questions..."
        case .conversing:
            switch voiceService.state {
            case .listening: return "Listening..."
            case .speaking: return "Zoe is speaking..."
            case .thinking: return "Thinking..."
            default: return "Ready to listen"
            }
        case .extractingAnswer: return "Processing your answer..."
        case .clarifying: return "Let me clarify..."
        case .saving: return "Saving..."
        case .completed: return "All done!"
        case .error(let msg): return msg
        case .idle: return ""
        }
    }
}
