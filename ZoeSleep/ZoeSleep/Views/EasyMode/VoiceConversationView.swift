//
//  VoiceConversationView.swift
//  ZoeSleep
//
//  Full-screen voice conversation interface with Zoe
//  Shows the Zoe orb, real-time transcript, and question progress
//

import SwiftUI
import Combine

/// Full-screen voice conversation view for Easy Mode questionnaires
struct VoiceConversationView: View {
    let questions: [Question]
    let onComplete: ([String: Any]) -> Void
    let onDismiss: () -> Void

    @StateObject private var viewModel = VoiceConversationViewModel()
    @ObservedObject var themeManager = ThemeManager.shared

    @State private var showingExitConfirmation = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient

            VStack(spacing: 0) {
                // Header with progress and close button
                headerView

                Spacer()

                // Current question text
                questionTextView

                // Zoe Orb
                ZoeOrbView(
                    state: viewModel.orbState,
                    audioLevel: viewModel.audioLevel
                )
                .frame(height: 300)

                // Real-time transcript area
                transcriptArea

                Spacer()

                // Bottom controls
                bottomControls
            }
            .padding(.horizontal, Spacing.lg)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.configure(questions: questions)
            viewModel.startConversation()
        }
        .onDisappear {
            viewModel.endConversation()
        }
        .alert("End Conversation?", isPresented: $showingExitConfirmation) {
            Button("Continue", role: .cancel) { }
            Button("End", role: .destructive) {
                viewModel.endConversation()
                onDismiss()
            }
        } message: {
            Text("Your progress will be saved. You can continue later.")
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete {
                onComplete(viewModel.collectedAnswers)
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.08, green: 0.08, blue: 0.2),
                Color(red: 0.05, green: 0.1, blue: 0.2)
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
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            // Progress indicator
            VStack(spacing: 2) {
                Text("Question \(viewModel.currentQuestionIndex + 1) of \(questions.count)")
                    .font(.system(size: Typography.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)

                        Capsule()
                            .fill(theme.accent)
                            .frame(width: geo.size.width * viewModel.progress, height: 4)
                    }
                }
                .frame(width: 120, height: 4)
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Question Text

    private var questionTextView: some View {
        VStack(spacing: Spacing.sm) {
            if let question = viewModel.currentQuestion {
                Text(question.text)
                    .font(.system(size: Typography.title2, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.lg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .id(question.id) // Force view recreation for animation

                // Show options if applicable
                if let options = question.options, !options.isEmpty {
                    Text("Options: \(options.joined(separator: " • "))")
                        .font(.system(size: Typography.caption, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(minHeight: 100)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentQuestionIndex)
    }

    // MARK: - Transcript Area

    private var transcriptArea: some View {
        VStack(spacing: Spacing.sm) {
            // What Zoe said
            if !viewModel.agentMessage.isEmpty {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(theme.accent.opacity(0.7))
                        .font(.system(size: 12))
                    Text("Zoe:")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }

                Text(viewModel.agentMessage)
                    .font(.system(size: Typography.body, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(theme.accent.opacity(0.15))
                    )
            }

            // What user is saying (real-time)
            if !viewModel.userTranscript.isEmpty || viewModel.isListening {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(viewModel.isListening ? .green : .white.opacity(0.7))
                        .font(.system(size: 12))
                    Text("You:")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()

                    if viewModel.isListening {
                        Text("Listening...")
                            .font(.system(size: Typography.caption, weight: .medium))
                            .foregroundColor(.green)
                    }
                }

                Text(viewModel.userTranscript.isEmpty ? "..." : viewModel.userTranscript)
                    .font(.system(size: Typography.body, weight: .regular))
                    .foregroundColor(viewModel.userTranscript.isEmpty ? .white.opacity(0.4) : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.white.opacity(0.1))
                    )
            }

            // Detected answer
            if let detected = viewModel.detectedAnswer {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Detected: \(detected)")
                        .font(.system(size: Typography.subheadline, weight: .semibold))
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.green.opacity(0.15))
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(Spacing.md)
        .frame(minHeight: 150)
        .animation(.easeInOut(duration: 0.2), value: viewModel.userTranscript)
        .animation(.easeInOut(duration: 0.3), value: viewModel.detectedAnswer)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: Spacing.lg) {
            // Skip button
            Button(action: { viewModel.skipQuestion() }) {
                HStack {
                    Image(systemName: "forward.fill")
                    Text("Skip")
                }
                .font(.system(size: Typography.subheadline, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }

            // Main mic button (interrupt/resume)
            Button(action: { viewModel.toggleListening() }) {
                ZStack {
                    Circle()
                        .fill(viewModel.isListening ? Color.red : theme.accent)
                        .frame(width: 64, height: 64)

                    Image(systemName: viewModel.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(viewModel.isListening ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isListening)

            // Confirm button (when answer detected)
            Button(action: { viewModel.confirmAnswer() }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Confirm")
                }
                .font(.system(size: Typography.subheadline, weight: .medium))
                .foregroundColor(viewModel.detectedAnswer != nil ? .white : .white.opacity(0.4))
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(viewModel.detectedAnswer != nil ? Color.green : Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
            .disabled(viewModel.detectedAnswer == nil)
        }
        .padding(.bottom, Spacing.xl)
    }
}

// MARK: - View Model

@MainActor
class VoiceConversationViewModel: ObservableObject {
    @Published var currentQuestionIndex = 0
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var userTranscript = ""
    @Published var agentMessage = ""
    @Published var detectedAnswer: String?
    @Published var audioLevel: Float = 0.0
    @Published var isComplete = false
    @Published var collectedAnswers: [String: Any] = [:]

    private var questions: [Question] = []
    private var conversationService: ElevenLabsConversationService?
    private var cancellables = Set<AnyCancellable>()

    // Agent ID - this should be configured in your ElevenLabs dashboard
    private let agentId = "your_agent_id_here" // TODO: Set actual agent ID

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

    func configure(questions: [Question]) {
        self.questions = questions
    }

    func startConversation() {
        // Build system prompt with all questions
        let systemPrompt = buildQuestionnairePrompt()

        conversationService = ElevenLabsConversationService.shared

        // Subscribe to events
        conversationService?.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)

        // Start the conversation
        Task {
            do {
                try await conversationService?.startConversation(
                    agentId: agentId,
                    systemPrompt: systemPrompt
                )
            } catch {
                print("VoiceConversation: Failed to start: \(error)")
                agentMessage = "Failed to connect. Please try again."
            }
        }
    }

    func endConversation() {
        conversationService?.endConversation()
        cancellables.removeAll()
    }

    func toggleListening() {
        if isListening {
            conversationService?.stopListening()
            isListening = false
        } else {
            // If agent is speaking, interrupt
            if isSpeaking {
                conversationService?.interruptAgent()
            }
            conversationService?.startListening()
            isListening = true
        }
    }

    func skipQuestion() {
        advanceToNextQuestion()
    }

    func confirmAnswer() {
        guard let answer = detectedAnswer, let question = currentQuestion else { return }

        // Store the answer
        collectedAnswers[question.id] = answer

        // Advance to next question
        advanceToNextQuestion()
    }

    private func advanceToNextQuestion() {
        detectedAnswer = nil
        userTranscript = ""

        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            isComplete = true
        }
    }

    private func handleEvent(_ event: ConversationEvent) {
        switch event {
        case .connected:
            print("VoiceConversation: Connected")

        case .disconnected(let error):
            if let error = error {
                print("VoiceConversation: Disconnected with error: \(error)")
            }

        case .userTranscript(let text, let isFinal):
            userTranscript = text
            if isFinal {
                // Try to parse the answer
                parseAnswer(from: text)
            }

        case .agentMessage(let text):
            agentMessage = text

        case .agentAudioStart:
            isSpeaking = true

        case .agentAudioEnd:
            isSpeaking = false
            // Auto-start listening after agent finishes
            if !isListening {
                toggleListening()
            }

        case .turnTaken(let by):
            isListening = (by == .user)
            isSpeaking = (by == .agent)

        case .error(let message):
            agentMessage = "Error: \(message)"
        }
    }

    private func parseAnswer(from transcript: String) {
        guard let question = currentQuestion else { return }

        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch question.questionType {
        case .yesNo, .yesNoDontKnow:
            if normalized.contains("yes") || normalized.contains("yeah") || normalized.contains("yep") {
                detectedAnswer = "Yes"
            } else if normalized.contains("no") || normalized.contains("nope") || normalized.contains("nah") {
                detectedAnswer = "No"
            } else if normalized.contains("don't know") || normalized.contains("not sure") {
                detectedAnswer = "Don't know"
            }

        case .scale:
            // Look for numbers
            let numbers = ["zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
                          "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10]
            for (word, value) in numbers {
                if normalized.contains(word) {
                    detectedAnswer = "\(value)"
                    return
                }
            }
            // Check for digits
            if let match = normalized.range(of: #"\d+"#, options: .regularExpression) {
                detectedAnswer = String(normalized[match])
            }

        case .singleSelect:
            if let options = question.options {
                for option in options {
                    if normalized.contains(option.lowercased()) {
                        detectedAnswer = option
                        return
                    }
                }
            }

        default:
            // For other types, use the transcript directly
            if !normalized.isEmpty {
                detectedAnswer = transcript
            }
        }
    }

    private func buildQuestionnairePrompt() -> String {
        var prompt = """
        You are Zoe, a friendly sleep health assistant conducting a questionnaire.
        Your voice is warm, calm, and reassuring - perfect for discussing sleep.

        INSTRUCTIONS:
        1. Read each question clearly and wait for the user's answer
        2. When you understand their answer, confirm it briefly ("Got it, you said...")
        3. Then move to the next question
        4. Be patient and supportive
        5. If the user seems confused, offer to repeat or clarify

        QUESTIONS TO ASK (in order):

        """

        for (index, question) in questions.enumerated() {
            prompt += "\(index + 1). \(question.text)"
            if let options = question.options, !options.isEmpty {
                prompt += " (Options: \(options.joined(separator: ", ")))"
            }
            if question.questionType == .scale {
                let min = question.scaleMin ?? 1
                let max = question.scaleMax ?? 10
                prompt += " (Scale: \(min) to \(max))"
            }
            prompt += "\n"
        }

        prompt += """

        Start by warmly greeting the user, then ask the first question.
        After completing all questions, thank them and say goodbye.
        """

        return prompt
    }
}

// MARK: - Preview

#Preview("Voice Conversation") {
    VoiceConversationView(
        questions: [
            Question(
                id: "q1",
                text: "Did you take any sleep medication last night?",
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
                text: "On a scale of 1 to 10, how would you rate your sleep quality?",
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
        onComplete: { answers in
            print("Completed with answers: \(answers)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}
