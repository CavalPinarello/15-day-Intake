//
//  CBTISessionManager.swift
//  ZoeSleep
//
//  Orchestrates CBT-I (Cognitive Behavioral Therapy for Insomnia) sessions.
//  Manages conversation flow with ElevenLabs, tracks progress, and saves session data.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CBTISessionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = CBTISessionManager()

    // MARK: - Published State

    @Published var sessionState: CBTISessionState = .notStarted
    @Published var currentSessionType: CBTISessionType?
    @Published var progress: CBTIProgress = .empty
    @Published var currentSleepWindow: SleepWindow?

    // Conversation state
    @Published var isConnected: Bool = false
    @Published var isListening: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var userTranscript: String = ""
    @Published var agentMessage: String = ""
    @Published var conversationHistory: [(role: String, text: String)] = []

    // Relaxation exercise state
    @Published var currentExercise: RelaxationExercise?
    @Published var exerciseProgress: Double = 0.0

    // Thought record state
    @Published var currentThoughtRecord: ThoughtRecord?
    @Published var savedThoughtRecords: [ThoughtRecord] = []

    // MARK: - Dependencies

    private let conversationService = ElevenLabsConversationService.shared
    private let emotionService = HumeEmotionService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Session Data

    private var sessionId: String?
    private var sessionStartTime: Date?
    private var sessionTranscript: [(timestamp: Date, role: String, text: String)] = []

    // MARK: - Configuration

    private let cbtiAgentId: String = "cbti_agent" // Replace with actual ElevenLabs agent ID

    // MARK: - Initialization

    private init() {
        setupObservers()
        loadProgress()
    }

    private func setupObservers() {
        // Observe conversation events
        conversationService.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleConversationEvent(event)
            }
            .store(in: &cancellables)

        // Observe conversation state
        conversationService.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)

        conversationService.$isSpeaking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSpeaking)

        conversationService.$currentUserTranscript
            .receive(on: DispatchQueue.main)
            .assign(to: &$userTranscript)

        conversationService.$currentAgentMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$agentMessage)
    }

    // MARK: - Session Lifecycle

    /// Start a new CBT-I session of the given type
    func startSession(type: CBTISessionType) async throws {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        currentSessionType = type
        sessionState = .introduction
        sessionTranscript = []
        conversationHistory = []

        // Start emotion analysis
        emotionService.startSession(
            sessionId: sessionId!,
            sessionType: "cbti_\(type.rawValue)"
        )

        // Build user context for the agent
        let userContext = await buildUserContext()

        // Build system prompt
        let systemPrompt = CBTIAgentPrompts.buildSystemPrompt(
            sessionType: type,
            userContext: userContext
        )

        // Start the ElevenLabs conversation
        try await conversationService.startConversation(
            agentId: cbtiAgentId,
            systemPrompt: systemPrompt
        )

        sessionState = .mainContent
        print("[CBTISessionManager] Started \(type.displayName) session")
    }

    /// End the current session
    func endSession() async {
        // End the conversation
        conversationService.endConversation()

        // End emotion analysis and get summary
        let emotionSummary = await emotionService.endSession()

        // Save session to backend
        if let sessionId = sessionId,
           let sessionType = currentSessionType,
           let startTime = sessionStartTime {
            await saveSession(
                sessionId: sessionId,
                sessionType: sessionType,
                startTime: startTime,
                emotionSummary: emotionSummary
            )
        }

        // Update progress
        if let sessionType = currentSessionType {
            progress.sessionsCompleted.append(sessionType)
        }

        // Reset state
        sessionState = .completed
        currentSessionType = nil
        sessionId = nil
        sessionStartTime = nil

        // Save progress
        await saveProgress()

        print("[CBTISessionManager] Session ended")
    }

    /// Pause the current session
    func pauseSession() {
        sessionState = .paused
        conversationService.stopListening()
    }

    /// Resume a paused session
    func resumeSession() {
        guard sessionState == .paused else { return }
        sessionState = .mainContent
    }

    // MARK: - Conversation Handling

    private func handleConversationEvent(_ event: ConversationEvent) {
        switch event {
        case .connected:
            print("[CBTISessionManager] Connected to conversation")

        case .disconnected(let error):
            if let error = error {
                sessionState = .error(error.localizedDescription)
            }

        case .userTranscript(let text, let isFinal):
            if isFinal {
                sessionTranscript.append((Date(), "user", text))
                conversationHistory.append((role: "user", text: text))

                // Analyze emotion from transcript timing
                checkForDistressKeywords(text)
            }

        case .agentMessage(let text):
            sessionTranscript.append((Date(), "agent", text))
            conversationHistory.append((role: "agent", text: text))
            agentMessage = text

            // Check for session state transitions based on agent response
            detectSessionTransition(from: text)

        case .agentAudioStart:
            isSpeaking = true

        case .agentAudioEnd:
            isSpeaking = false

        case .turnTaken(let by):
            isListening = (by == .user)

        case .error(let message):
            print("[CBTISessionManager] Error: \(message)")
            sessionState = .error(message)
        }
    }

    /// Start listening for user input
    func startListening() {
        guard isConnected, !isSpeaking else { return }
        conversationService.startListening()
        isListening = true
    }

    /// Stop listening
    func stopListening() {
        conversationService.stopListening()
        isListening = false
    }

    /// Interrupt the agent
    func interruptAgent() {
        conversationService.interruptAgent()
    }

    // MARK: - Safety & Guardrails

    private func checkForDistressKeywords(_ text: String) {
        let lowercased = text.lowercased()

        let crisisKeywords = [
            "hurt myself", "kill myself", "want to die", "end it all",
            "can't go on", "no point", "better off dead", "suicidal"
        ]

        for keyword in crisisKeywords {
            if lowercased.contains(keyword) {
                handleCrisisDetected()
                return
            }
        }
    }

    private func handleCrisisDetected() {
        // Log for clinician review
        print("[CBTISessionManager] CRISIS DETECTED - flagging for review")

        // The agent should handle this via its system prompt
        // But we also want to ensure it's logged
        Task {
            await flagSessionForReview(reason: "crisis_keywords_detected")
        }
    }

    // MARK: - Session Transitions

    private func detectSessionTransition(from agentMessage: String) {
        let lowercased = agentMessage.lowercased()

        // Detect relaxation exercise start
        if lowercased.contains("let's try") && (
            lowercased.contains("breathing") ||
            lowercased.contains("relaxation") ||
            lowercased.contains("body scan") ||
            lowercased.contains("muscle relaxation")
        ) {
            // Determine which exercise
            if lowercased.contains("breathing") {
                startRelaxationExercise(.diaphragmaticBreathing)
            } else if lowercased.contains("muscle") || lowercased.contains("pmr") {
                startRelaxationExercise(.progressiveMuscleRelaxation)
            } else if lowercased.contains("body scan") {
                startRelaxationExercise(.bodyScanning)
            } else if lowercased.contains("imagery") || lowercased.contains("peaceful") {
                startRelaxationExercise(.visualImagery)
            }
        }

        // Detect thought record start
        if lowercased.contains("thought record") || lowercased.contains("let's challenge") {
            startThoughtRecord()
        }

        // Detect sleep window discussion
        if lowercased.contains("sleep window") || lowercased.contains("bedtime") && lowercased.contains("wake time") {
            sessionState = .mainContent
        }

        // Detect homework assignment
        if lowercased.contains("this week") && (lowercased.contains("try") || lowercased.contains("practice")) {
            sessionState = .homework
        }

        // Detect session ending
        if lowercased.contains("we'll pick up") || lowercased.contains("see you next") || lowercased.contains("great session") {
            sessionState = .review
        }
    }

    // MARK: - Relaxation Exercises

    func startRelaxationExercise(_ exercise: RelaxationExercise) {
        currentExercise = exercise
        exerciseProgress = 0.0
        sessionState = .exercise(exercise)

        print("[CBTISessionManager] Starting relaxation exercise: \(exercise.displayName)")
    }

    func updateExerciseProgress(_ progress: Double) {
        exerciseProgress = min(1.0, max(0.0, progress))

        if exerciseProgress >= 1.0 {
            completeRelaxationExercise()
        }
    }

    func completeRelaxationExercise() {
        guard let exercise = currentExercise else { return }

        progress.relaxationPracticeMinutes += exercise.durationMinutes
        currentExercise = nil
        exerciseProgress = 0.0
        sessionState = .mainContent

        print("[CBTISessionManager] Completed relaxation exercise")
    }

    func skipRelaxationExercise() {
        currentExercise = nil
        exerciseProgress = 0.0
        sessionState = .mainContent
    }

    // MARK: - Thought Records

    func startThoughtRecord() {
        currentThoughtRecord = ThoughtRecord(
            id: UUID().uuidString,
            createdAt: Date(),
            situation: "",
            automaticThought: "",
            emotion: "",
            emotionIntensity: 50
        )

        print("[CBTISessionManager] Starting thought record")
    }

    func updateThoughtRecord(_ record: ThoughtRecord) {
        currentThoughtRecord = record
    }

    func saveThoughtRecord() async {
        guard let record = currentThoughtRecord else { return }

        savedThoughtRecords.append(record)
        progress.thoughtRecordsCount += 1

        // Save to backend
        await saveThoughtRecordToBackend(record)

        currentThoughtRecord = nil
    }

    func discardThoughtRecord() {
        currentThoughtRecord = nil
    }

    // MARK: - Sleep Window

    func calculateSleepWindow(averageSleepMinutes: Int, desiredWakeTime: Date) {
        currentSleepWindow = SleepWindow.calculateInitial(
            averageTotalSleepMinutes: averageSleepMinutes,
            desiredWakeTime: desiredWakeTime
        )
        progress.currentSleepWindow = currentSleepWindow

        print("[CBTISessionManager] Calculated sleep window: \(currentSleepWindow?.timeInBed ?? "nil")")
    }

    func adjustSleepWindow(weeklyEfficiency: Double) {
        guard let current = currentSleepWindow else { return }

        let adjusted = current.adjusted(forSleepEfficiency: weeklyEfficiency)
        currentSleepWindow = adjusted
        progress.currentSleepWindow = adjusted
        progress.sleepEfficiencyHistory.append(weeklyEfficiency)

        print("[CBTISessionManager] Adjusted sleep window for \(Int(weeklyEfficiency * 100))% efficiency")
    }

    // MARK: - User Context

    private func buildUserContext() async -> CBTIUserContext {
        // Fetch user's sleep data from backend
        // For now, use defaults
        return CBTIUserContext(
            weekNumber: progress.weekNumber,
            sleepEfficiency: progress.sleepEfficiencyHistory.last ?? 0.75,
            isiScore: 15, // Would fetch from backend
            currentSleepWindow: progress.currentSleepWindow,
            mainConcerns: ["difficulty falling asleep", "waking during night"]
        )
    }

    // MARK: - Progress Management

    private func loadProgress() {
        // Load from UserDefaults for now
        if let data = UserDefaults.standard.data(forKey: "cbti_progress"),
           let decoded = try? JSONDecoder().decode(CBTIProgress.self, from: data) {
            progress = decoded
        }
    }

    private func saveProgress() async {
        if let encoded = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(encoded, forKey: "cbti_progress")
        }

        // Also save to backend
        await saveProgressToBackend()
    }

    // MARK: - Backend Integration

    private func saveSession(
        sessionId: String,
        sessionType: CBTISessionType,
        startTime: Date,
        emotionSummary: SessionEmotionSummary?
    ) async {
        do {
            try await ConvexService.shared.saveCBTISession(
                sessionId: sessionId,
                sessionType: sessionType.rawValue,
                transcript: sessionTranscript,
                sleepWindow: currentSleepWindow,
                emotionSummary: emotionSummary
            )
        } catch {
            print("[CBTISessionManager] Failed to save session: \(error)")
        }
    }

    private func saveProgressToBackend() async {
        do {
            try await ConvexService.shared.saveCBTIProgress(progress)
        } catch {
            print("[CBTISessionManager] Failed to save progress: \(error)")
        }
    }

    private func saveThoughtRecordToBackend(_ record: ThoughtRecord) async {
        do {
            try await ConvexService.shared.saveThoughtRecord(record, sessionId: sessionId)
        } catch {
            print("[CBTISessionManager] Failed to save thought record: \(error)")
        }
    }

    private func flagSessionForReview(reason: String) async {
        guard let sessionId = sessionId else { return }

        do {
            try await ConvexService.shared.flagCBTISessionForReview(
                sessionId: sessionId,
                reason: reason
            )
        } catch {
            print("[CBTISessionManager] Failed to flag session: \(error)")
        }
    }

    // MARK: - Recommended Sessions

    /// Get the next recommended session based on progress
    func getRecommendedSession() -> CBTISessionType {
        // Week 1: Introduction, then Sleep Restriction + Stimulus Control
        // Week 2: Cognitive Restructuring
        // Week 3+: Weekly reviews with continued practice

        if !progress.sessionsCompleted.contains(.introduction) {
            return .introduction
        }

        if !progress.sessionsCompleted.contains(.sleepRestriction) {
            return .sleepRestriction
        }

        if !progress.sessionsCompleted.contains(.stimulusControl) {
            return .stimulusControl
        }

        if progress.weekNumber >= 2 && progress.sessionsCompleted.filter({ $0 == .cognitiveRestructuring }).count < 2 {
            return .cognitiveRestructuring
        }

        if progress.weekNumber >= 2 && progress.sessionsCompleted.filter({ $0 == .relaxationTraining }).count < 2 {
            return .relaxationTraining
        }

        if !progress.sessionsCompleted.contains(.sleepHygiene) {
            return .sleepHygiene
        }

        // Default to weekly review
        return .weeklyReview
    }

    /// Check if user has completed the CBT-I program
    var isProgramComplete: Bool {
        // Program is complete after 6-8 weeks with good sleep efficiency
        progress.weekNumber >= 6 &&
        (progress.sleepEfficiencyHistory.last ?? 0) >= 0.85 &&
        progress.sessionsCompleted.count >= 10
    }
}

// MARK: - CBT-I Convex Response Models

struct CBTIMutationResponse: Decodable {
    let id: String?
}

struct EmptyResponse: Decodable {}
