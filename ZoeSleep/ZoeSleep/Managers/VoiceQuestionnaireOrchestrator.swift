//
//  VoiceQuestionnaireOrchestrator.swift
//  ZoeSleep
//
//  Manages the conversational flow for voice-based questionnaire intake.
//  Feeds questions to Hume EVI as a natural conversation, receives answers,
//  extracts structured data, and saves to Convex for the physician dashboard.
//
//  Replaces: VoiceAssessmentSessionManager (conversation logic)
//

import Foundation
import Combine

// MARK: - Voice Question State

struct VoiceQuestionState: Identifiable {
    let id: String           // question_id (e.g., "D1", "PHQ9_1")
    let text: String         // Clinical question text
    let type: String         // answer_format: time_picker, slider_scale, etc.
    let options: [String]?   // For single/multi select
    let formatConfig: [String: AnyCodable]?
    var status: QuestionStatus = .pending

    enum QuestionStatus {
        case pending
        case asked          // Hume has asked this question
        case answered(value: Any, confidence: Double)
        case confirmed      // Answer saved to Convex
        case skipped        // Conditionally skipped
    }
}

// MARK: - Orchestrator State

enum OrchestratorState: Equatable {
    case idle
    case loading
    case conversing
    case extractingAnswer
    case clarifying
    case saving
    case completed
    case error(String)

    static func == (lhs: OrchestratorState, rhs: OrchestratorState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.conversing, .conversing),
             (.extractingAnswer, .extractingAnswer), (.clarifying, .clarifying),
             (.saving, .saving), (.completed, .completed):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Voice Questionnaire Orchestrator

@MainActor
class VoiceQuestionnaireOrchestrator: ObservableObject {

    // MARK: - Published State

    @Published var state: OrchestratorState = .idle
    @Published var currentQuestionIndex: Int = 0
    @Published var totalQuestions: Int = 0
    @Published var progress: Double = 0.0
    @Published var currentQuestion: VoiceQuestionState?
    @Published var questionsCompleted: Int = 0
    @Published var sessionDuration: TimeInterval = 0
    @Published var useManualInput: Bool = false  // "I'd rather type" fallback

    // Emotion tracking per question
    @Published var emotionSnapshots: [String: EmotionSnapshot] = [:]  // questionId -> snapshot

    // MARK: - Private State

    private let voiceService = HumeVoiceService.shared
    private let convexService = ConvexService.shared
    private let emotionService = HumeEmotionService.shared

    private var questions: [VoiceQuestionState] = []
    private var dayNumber: Int = 1
    private var section: String = "all"  // "sleepLog", "assessment", or "all"
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartTime: Date?
    private var clarificationAttempts: Int = 0
    private let maxClarifications = 2
    private var userName: String = ""

    // MARK: - Conversation Personality Per Day

    private static let dayPersonality: [Int: String] = [
        1: "warm and welcoming, like a first meeting with a caring friend",
        2: "curious and gentle, like catching up the next morning",
        3: "sensitive and careful, especially around emotional topics",
        4: "matter-of-fact but friendly, like a thorough but kind doctor",
        5: "casual and non-judgmental, like chatting about daily habits",
        6: "focused and supportive, helping work through detailed sleep questions",
        7: "gentle and compassionate, handling sensitive mental health topics with care",
        8: "professional but warm, discussing breathing and physical symptoms",
        9: "encouraging and practical, exploring daily function and pain",
        10: "celebratory and thorough, wrapping up the assessment journey"
    ]

    // MARK: - Start Session

    /// Start a voice questionnaire session for a specific day and section
    func startSession(dayNumber: Int, section: String = "all", userName: String = "") async {
        self.dayNumber = dayNumber
        self.section = section
        self.userName = userName
        self.state = .loading
        self.sessionStartTime = Date()
        self.questionsCompleted = 0
        self.clarificationAttempts = 0

        do {
            // 1. Load questions for this day
            let response = try await convexService.getQuestionsForUserDay(
                dayNumber: dayNumber,
                section: section
            )

            // Combine sleep log + assessment into ordered list
            var allQuestions: [ConvexQuestion] = []
            if section == "all" || section == "sleepLog" {
                allQuestions.append(contentsOf: response.sleepLog)
            }
            if section == "all" || section == "assessment" {
                allQuestions.append(contentsOf: response.assessment.filter { $0.id != "INFO_NO_QUESTIONS" })
            }

            questions = allQuestions.map { q in
                VoiceQuestionState(
                    id: q.id,
                    text: q.text,
                    type: q.type,
                    options: q.options,
                    formatConfig: q.formatConfig
                )
            }

            totalQuestions = questions.count

            guard !questions.isEmpty else {
                state = .completed
                return
            }

            // 2. Build system prompt with all questions for this session
            let systemPrompt = buildSystemPrompt(
                questions: questions,
                dayNumber: dayNumber,
                section: section,
                userName: userName
            )

            // 3. Build tools for answer extraction
            let tools = buildTools()

            // 4. Connect to Hume EVI
            try await voiceService.connect(
                systemPrompt: systemPrompt,
                tools: tools
            )

            // 5. Subscribe to voice events
            subscribeToVoiceEvents()

            // Start emotion tracking
            emotionService.startSession(
                sessionId: "voice_intake_day\(dayNumber)_\(UUID().uuidString.prefix(8))",
                sessionType: "voice_questionnaire"
            )

            state = .conversing
            currentQuestionIndex = 0
            currentQuestion = questions.first

            print("[VoiceOrchestrator] Session started: Day \(dayNumber), \(questions.count) questions")

        } catch {
            state = .error(error.localizedDescription)
            print("[VoiceOrchestrator] Failed to start: \(error)")
        }
    }

    /// End the current session
    func endSession() async {
        voiceService.disconnect()

        // Save emotion summary
        let emotionSummary = await emotionService.endSession()

        if let startTime = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(startTime)
        }

        state = .completed
        cancellables.removeAll()

        print("[VoiceOrchestrator] Session ended: \(questionsCompleted)/\(totalQuestions) questions answered in \(Int(sessionDuration))s")
    }

    /// Switch to manual input mode
    func switchToManualInput() {
        useManualInput = true
        voiceService.disconnect()
        cancellables.removeAll()
        print("[VoiceOrchestrator] Switched to manual input")
    }

    // MARK: - Private: System Prompt

    private func buildSystemPrompt(
        questions: [VoiceQuestionState],
        dayNumber: Int,
        section: String,
        userName: String
    ) -> String {
        let personality = Self.dayPersonality[dayNumber] ?? "warm and professional"
        let greeting = userName.isEmpty ? "the user" : userName

        // Build question list for the prompt
        var questionList = ""
        for (i, q) in questions.enumerated() {
            questionList += "\n\(i + 1). [ID: \(q.id)] \(q.text)"
            if let options = q.options, !options.isEmpty {
                questionList += " (Options: \(options.joined(separator: ", ")))"
            }
            questionList += " [Type: \(q.type)]"
        }

        return """
        You are Zoe, a warm and empathic sleep health companion helping \(greeting) with their daily sleep assessment (Day \(dayNumber) of 10).

        YOUR PERSONALITY TODAY: Be \(personality).

        YOUR TASK:
        You need to collect answers to the following questions through natural conversation. Do NOT read the clinical text verbatim. Instead, rephrase each question in a casual, friendly way. Group related questions together naturally.

        QUESTIONS TO ASK:\(questionList)

        RULES:
        1. NEVER read question IDs or clinical text verbatim. Rephrase naturally.
        2. Ask 1-3 related questions at a time, not one by one robotically.
        3. When you have enough information for a question, call the save_answer tool immediately.
        4. If the user's answer is ambiguous, ask ONE natural clarifying question. Don't ask more than twice.
        5. If the user seems distressed (especially on mental health questions), acknowledge their feelings warmly before continuing.
        6. Keep the conversation flowing - don't pause awkwardly between questions.
        7. \(section == "sleepLog" ? "This is the morning sleep diary - keep it under 3 minutes. Be efficient but warm." : "Take your time but stay focused.")
        8. When all questions are answered, wrap up warmly and call the session_complete tool.
        9. If the user says "I'd rather type" or similar, call the switch_to_manual tool.

        ANSWER TYPES:
        - time_picker: Extract times like "10:30 PM" -> "22:30" (24hr format)
        - minutes_scroll: Extract durations like "about 45 minutes" -> 45
        - slider_scale: Extract ratings like "maybe a 7" -> 7
        - single_select_chips: Match to one of the provided options
        - multi_select_chips: Match to multiple options (JSON array)
        - number_scroll: Extract numbers like "one seventy five" -> 175
        - yes_no: Extract "yes" or "no"

        Remember: You're not an interviewer. You're a friend who genuinely cares about how they slept.
        """
    }

    // MARK: - Private: Tool Definitions

    private func buildTools() -> [[String: Any]] {
        return [
            [
                "type": "function",
                "name": "save_answer",
                "description": "Save a structured answer extracted from the user's conversational response",
                "parameters": """
                {
                    "type": "object",
                    "properties": {
                        "question_id": {
                            "type": "string",
                            "description": "The question ID (e.g., CSD_INTO_BED, D1, PHQ9_1)"
                        },
                        "answer_format": {
                            "type": "string",
                            "enum": ["time_picker", "minutes_scroll", "slider_scale", "single_select_chips", "multi_select_chips", "number_scroll", "number_input", "yes_no", "date_picker"],
                            "description": "The answer format type"
                        },
                        "value": {
                            "type": "string",
                            "description": "The extracted value as a string. Times in 24hr format (22:30), numbers as digits (45), options as option text"
                        },
                        "array_value": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "For multi_select_chips only - array of selected options"
                        },
                        "confidence": {
                            "type": "number",
                            "description": "Confidence in extraction accuracy (0.0-1.0). Use 0.9+ for clear answers, 0.5-0.8 for inferred answers"
                        }
                    },
                    "required": ["question_id", "answer_format", "value", "confidence"]
                }
                """
            ],
            [
                "type": "function",
                "name": "session_complete",
                "description": "Call when all questions have been answered",
                "parameters": """
                {
                    "type": "object",
                    "properties": {
                        "summary": {
                            "type": "string",
                            "description": "Brief summary of the session"
                        }
                    },
                    "required": ["summary"]
                }
                """
            ],
            [
                "type": "function",
                "name": "switch_to_manual",
                "description": "Call when the user wants to switch to typing answers instead of voice",
                "parameters": """
                {
                    "type": "object",
                    "properties": {
                        "reason": {
                            "type": "string",
                            "description": "Why the user wants to switch"
                        }
                    }
                }
                """
            ]
        ]
    }

    // MARK: - Private: Voice Event Handling

    private func subscribeToVoiceEvents() {
        voiceService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.handleVoiceEvent(event)
                }
            }
            .store(in: &cancellables)
    }

    private func handleVoiceEvent(_ event: HumeVoiceEvent) {
        switch event {
        case .toolCall(let name, let parameters, let toolCallId):
            Task { await handleToolCall(name: name, parameters: parameters, toolCallId: toolCallId) }

        case .emotionUpdate(let emotions, let arousal, let valence):
            // Capture emotion for current question
            if let q = currentQuestion {
                let snapshot = EmotionSnapshot(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    emotions: emotions,
                    dominantEmotion: mapDominantEmotion(emotions),
                    arousalLevel: arousal,
                    valence: valence,
                    speechRate: nil,
                    voicePitch: nil
                )
                emotionSnapshots[q.id] = snapshot

                // Feed to emotion service
                emotionService.sessionSnapshots.append(snapshot)
                emotionService.currentSnapshot = snapshot

                // Check for distress
                if snapshot.isDistressed {
                    print("[VoiceOrchestrator] Distress detected on question \(q.id)")
                }
            }

        case .error(let msg):
            print("[VoiceOrchestrator] Voice error: \(msg)")

        case .disconnected:
            if state == .conversing {
                state = .error("Voice connection lost")
            }

        default:
            break
        }
    }

    // MARK: - Private: Tool Call Handling

    private func handleToolCall(name: String, parameters: String, toolCallId: String) async {
        guard let paramData = parameters.data(using: .utf8),
              let params = try? JSONSerialization.jsonObject(with: paramData) as? [String: Any] else {
            try? await voiceService.sendToolError(toolCallId: toolCallId, error: "Invalid parameters")
            return
        }

        switch name {
        case "save_answer":
            await handleSaveAnswer(params: params, toolCallId: toolCallId)

        case "session_complete":
            let summary = params["summary"] as? String ?? "Session completed"
            print("[VoiceOrchestrator] Session complete: \(summary)")
            try? await voiceService.sendToolResponse(toolCallId: toolCallId, content: "Session marked as complete. Thank you!")
            await endSession()

        case "switch_to_manual":
            let reason = params["reason"] as? String ?? "User preference"
            print("[VoiceOrchestrator] Switch to manual: \(reason)")
            try? await voiceService.sendToolResponse(toolCallId: toolCallId, content: "Switching to manual input.")
            switchToManualInput()

        default:
            try? await voiceService.sendToolError(toolCallId: toolCallId, error: "Unknown tool: \(name)")
        }
    }

    private func handleSaveAnswer(params: [String: Any], toolCallId: String) async {
        guard let questionId = params["question_id"] as? String,
              let answerFormat = params["answer_format"] as? String,
              let valueStr = params["value"] as? String,
              let confidence = params["confidence"] as? Double else {
            try? await voiceService.sendToolError(toolCallId: toolCallId, error: "Missing required fields")
            return
        }

        state = .extractingAnswer

        // Check confidence threshold
        if confidence < 0.7 && clarificationAttempts < maxClarifications {
            clarificationAttempts += 1
            state = .clarifying
            try? await voiceService.sendToolResponse(
                toolCallId: toolCallId,
                content: "Confidence too low (\(String(format: "%.0f", confidence * 100))%). Please ask a natural clarifying question for question \(questionId)."
            )
            return
        }

        // Save to Convex
        do {
            state = .saving

            // Determine value type based on format
            let value: Any?
            let arrayValue: [String]?

            switch answerFormat {
            case "minutes_scroll", "number_scroll", "number_input", "slider_scale":
                value = Double(valueStr) ?? Int(valueStr)
                arrayValue = nil
            case "multi_select_chips":
                value = nil
                if let arrData = (params["array_value"] as? [String]) {
                    arrayValue = arrData
                } else {
                    // Try parsing value as JSON array
                    arrayValue = valueStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            default:
                value = valueStr
                arrayValue = nil
            }

            let _ = try await convexService.submitQuestionnaireResponse(
                questionId: questionId,
                answerFormat: answerFormat,
                value: value,
                arrayValue: arrayValue,
                dayNumber: dayNumber
            )

            // Update question state
            if let index = questions.firstIndex(where: { $0.id == questionId }) {
                questions[index].status = .confirmed
                questionsCompleted += 1
                progress = Double(questionsCompleted) / Double(totalQuestions)

                // Advance to next unanswered question
                if let nextIndex = questions.firstIndex(where: {
                    if case .pending = $0.status { return true }
                    if case .asked = $0.status { return true }
                    return false
                }) {
                    currentQuestionIndex = nextIndex
                    currentQuestion = questions[nextIndex]
                } else {
                    currentQuestion = nil
                }
            }

            clarificationAttempts = 0
            state = .conversing

            try? await voiceService.sendToolResponse(
                toolCallId: toolCallId,
                content: "Answer saved successfully for \(questionId). \(totalQuestions - questionsCompleted) questions remaining."
            )

            print("[VoiceOrchestrator] Saved \(questionId) = \(valueStr) (confidence: \(String(format: "%.0f", confidence * 100))%)")

        } catch {
            state = .conversing
            try? await voiceService.sendToolError(
                toolCallId: toolCallId,
                error: "Failed to save: \(error.localizedDescription)"
            )
            print("[VoiceOrchestrator] Save error for \(questionId): \(error)")
        }
    }

    // MARK: - Private: Helpers

    private func mapDominantEmotion(_ emotions: [String: Double]) -> SleepRelevantEmotion {
        guard let (name, _) = emotions.max(by: { $0.value < $1.value }) else {
            return .calm
        }
        return SleepRelevantEmotion(rawValue: name) ?? .calm
    }

    // MARK: - Public: Get Remaining Questions (for manual fallback)

    /// Returns questions that haven't been answered yet (for switching to manual mode)
    var remainingQuestions: [VoiceQuestionState] {
        questions.filter {
            switch $0.status {
            case .confirmed, .skipped: return false
            default: return true
            }
        }
    }
}
