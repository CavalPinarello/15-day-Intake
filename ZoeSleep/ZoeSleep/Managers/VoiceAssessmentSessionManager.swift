//
//  VoiceAssessmentSessionManager.swift
//  ZoeSleep
//
//  Orchestrates voice-based assessment sessions.
//  Manages conversation flow, guardrails, and answer collection.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class VoiceAssessmentSessionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = VoiceAssessmentSessionManager()

    // MARK: - Published State

    @Published var state: VoiceAssessmentState = .notStarted
    @Published var progress: VoiceAssessmentProgress = .empty
    @Published var currentScript: DayConversationScript?
    @Published var currentPrompt: ConversationalPrompt?
    @Published var currentTranscript: String = ""
    @Published var zoeMessage: String = ""
    @Published var isZoeSpeaking: Bool = false
    @Published var showConfirmation: Bool = false
    @Published var pendingAnswer: ParsedConversationalAnswer?

    // MARK: - Dependencies

    private let easyModeManager = EasyModeManager.shared
    private let audioManager = AudioSessionManager.shared
    private let questionnaireManager = QuestionnaireManager.shared

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var sessionStartTime: Date?
    private var maxRedirectsBeforeFallback = 3
    private var consecutiveRedirects = 0

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Observe voice state changes from EasyModeManager
        easyModeManager.$voiceState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] voiceState in
                self?.handleVoiceStateChange(voiceState)
            }
            .store(in: &cancellables)
    }

    // MARK: - Session Lifecycle

    /// Start a new voice assessment session for the given day
    func startSession(forDay dayNumber: Int) async {
        sessionStartTime = Date()
        progress = .empty
        progress.currentDayNumber = dayNumber
        consecutiveRedirects = 0

        // Load the conversation script for this day
        currentScript = ConversationScriptLibrary.script(forDay: dayNumber)

        guard let script = currentScript else {
            state = .error("Could not load assessment for day \(dayNumber)")
            return
        }

        progress.totalQuestionsInDay = script.allQuestionIds.count

        // Determine if this is first time (Day 1, never done before)
        let isFirstTime = dayNumber == 1 && progress.totalQuestionsAnswered == 0

        // Build Zoe's introduction
        let intro = ZoeIntroduction.introForDay(
            dayNumber,
            topic: script.title,
            minutes: script.estimatedMinutes,
            isFirstTime: isFirstTime
        )

        state = .introducingZoe
        await speakAndWait(intro)

        // Start the first section
        await startSection(at: 0)
    }

    /// Resume a paused session
    func resumeSession() async {
        guard state == .paused else { return }

        let resumeMessage = "Welcome back! Let's continue where we left off."
        state = .introducingZoe
        await speakAndWait(resumeMessage)

        // Resume from current position
        await askCurrentPrompt()
    }

    /// Pause the session
    func pauseSession() {
        state = .paused
        progress.lastActivityTime = Date()
        // TODO: Save progress to Convex for persistence
    }

    /// End the session
    func endSession() {
        state = .notStarted
        currentScript = nil
        currentPrompt = nil
        currentTranscript = ""
        zoeMessage = ""
    }

    // MARK: - Navigation

    private func startSection(at index: Int) async {
        guard let script = currentScript, index < script.sections.count else {
            await completeDay()
            return
        }

        let section = script.sections[index]
        progress.currentSectionIndex = index
        progress.currentPromptIndex = 0

        // Check if this section's gateways are triggered (for expansion days)
        if let requiredGateways = section.requiredGateways {
            let hasRequiredGateway = requiredGateways.contains { progress.gatewaysTriggered.contains($0) }
            if !hasRequiredGateway {
                // Skip this section
                await startSection(at: index + 1)
                return
            }
        }

        // Introduce the section
        await speakAndWait(section.introduction)

        // Ask the first prompt
        await askCurrentPrompt()
    }

    private func askCurrentPrompt() async {
        guard let script = currentScript,
              progress.currentSectionIndex < script.sections.count else {
            await completeDay()
            return
        }

        let section = script.sections[progress.currentSectionIndex]

        guard progress.currentPromptIndex < section.prompts.count else {
            // Section complete
            await completeSection()
            return
        }

        let prompt = section.prompts[progress.currentPromptIndex]
        currentPrompt = prompt

        state = .awaitingResponse
        await speakAndWait(prompt.spokenPrompt)

        // Now ready for user response
        state = .awaitingResponse
    }

    private func completeSection() async {
        guard let script = currentScript,
              progress.currentSectionIndex < script.sections.count else {
            await completeDay()
            return
        }

        let section = script.sections[progress.currentSectionIndex]
        state = .sectionComplete

        // Speak section conclusion
        await speakAndWait(section.conclusion)

        // Move to next section
        await startSection(at: progress.currentSectionIndex + 1)
    }

    private func completeDay() async {
        guard let script = currentScript else { return }

        state = .dayComplete
        await speakAndWait(script.closingMessage)

        // Calculate and save scores if this is an expansion day
        await calculateScoresIfNeeded()
    }

    private func moveToNextPrompt() async {
        guard let script = currentScript,
              progress.currentSectionIndex < script.sections.count else {
            await completeDay()
            return
        }

        let section = script.sections[progress.currentSectionIndex]
        progress.currentPromptIndex += 1

        if progress.currentPromptIndex < section.prompts.count {
            // Transition phrase
            if let transition = currentPrompt?.transitionPhrase {
                await speakAndWait(transition)
            }
            await askCurrentPrompt()
        } else {
            await completeSection()
        }
    }

    // MARK: - Voice Interaction

    func startListening() async {
        guard state == .awaitingResponse else { return }

        state = .listening
        do {
            try await easyModeManager.startRecording()
        } catch {
            state = .error("Couldn't access microphone")
        }
    }

    func stopListening() {
        audioManager.stopRecording()
    }

    private func handleVoiceStateChange(_ voiceState: VoiceInputState) {
        switch voiceState {
        case .idle:
            if state == .listening {
                // Recording stopped, process
                Task { await processRecording() }
            }
        case .listening:
            state = .listening
        case .processing, .parsing:
            state = .processing
        case .confirming(let response):
            handleParsedResponse(response)
        case .error(let error):
            handleError(error)
        }
    }

    private func processRecording() async {
        state = .processing

        do {
            guard let audioData = audioManager.getRecordedAudioData() else {
                throw VoiceError.noAudioRecorded
            }

            // Transcribe
            let transcript = try await ConvexService.shared.callVoiceTranscribe(
                audioBase64: audioData.base64EncodedString()
            )
            currentTranscript = transcript

            // Check for guardrails first
            await checkGuardrails(transcript)

        } catch {
            handleError(.transcriptionFailed(error.localizedDescription))
        }
    }

    // MARK: - Guardrails

    private func checkGuardrails(_ transcript: String) async {
        // Check if user wants to repeat
        if GuardrailPatterns.wantsRepeat(transcript) {
            await repeatCurrentPrompt()
            return
        }

        // Check if user wants to pause
        if GuardrailPatterns.wantsPause(transcript) {
            await handlePauseRequest()
            return
        }

        // Check for guardrail triggers
        if let redirectType = GuardrailPatterns.checkForGuardrails(transcript) {
            await handleGuardrailRedirect(redirectType)
            return
        }

        // No guardrails triggered, parse the answer
        await parseAnswer(transcript)
    }

    private func handleGuardrailRedirect(_ type: GuardrailRedirectType) async {
        consecutiveRedirects += 1
        progress.redirectCount += 1
        state = .redirecting

        // Speak the redirect
        await speakAndWait(type.redirectPrompt)

        if type == .emotionalDistress {
            // Offer to pause
            zoeMessage = "Would you like to continue or take a break?"
            state = .awaitingResponse
            return
        }

        // If too many redirects, offer manual input
        if consecutiveRedirects >= maxRedirectsBeforeFallback {
            await offerManualFallback()
            return
        }

        // Re-ask the question with clarification
        if let prompt = currentPrompt, let clarification = prompt.clarificationPrompt {
            await speakAndWait(clarification)
        } else {
            await repeatCurrentPrompt()
        }
    }

    private func repeatCurrentPrompt() async {
        guard let prompt = currentPrompt else { return }
        await speakAndWait(prompt.spokenPrompt)
        state = .awaitingResponse
    }

    private func handlePauseRequest() async {
        let pauseMessage = "No problem! Your progress is saved. Just come back when you're ready."
        await speakAndWait(pauseMessage)
        pauseSession()
    }

    private func offerManualFallback() async {
        let fallbackMessage = "I'm having trouble understanding. You can tap on the screen to answer this one manually, or try speaking again."
        await speakAndWait(fallbackMessage)
        state = .awaitingResponse
        // TODO: Show manual input option in UI
    }

    // MARK: - Answer Parsing

    private func parseAnswer(_ transcript: String) async {
        guard let prompt = currentPrompt else { return }

        state = .processing

        do {
            // Build context for parsing
            let context = buildParsingContext(for: prompt)

            // Call Convex to parse the answer
            let parseResult = try await ConvexService.shared.callConversationalParse(
                transcript: transcript,
                questionIds: prompt.questionIds,
                expectedType: prompt.expectedAnswerType.rawValue,
                context: context
            )

            // Build ParsedConversationalAnswer
            let parsedAnswer = ParsedConversationalAnswer(
                questionIds: prompt.questionIds,
                rawTranscript: transcript,
                parsedValues: parseResult.values,
                confidence: parseResult.confidence,
                needsClarification: parseResult.confidence < 0.7,
                clarificationReason: parseResult.clarificationNeeded,
                triggersGateway: parseResult.triggersGateway,
                gatewayType: parseResult.gatewayType
            )

            if parsedAnswer.needsClarification {
                await requestClarification(parsedAnswer)
            } else {
                await confirmAnswer(parsedAnswer)
            }

        } catch {
            handleError(.parsingFailed(error.localizedDescription))
        }
    }

    private func buildParsingContext(for prompt: ConversationalPrompt) -> [String: Any] {
        var context: [String: Any] = [
            "questionIds": prompt.questionIds,
            "spokenPrompt": prompt.spokenPrompt,
            "expectedType": prompt.expectedAnswerType.rawValue
        ]

        if let rules = prompt.validationRules {
            if let min = rules.minValue { context["minValue"] = min }
            if let max = rules.maxValue { context["maxValue"] = max }
            if let options = rules.acceptableOptions { context["options"] = options }
        }

        return context
    }

    private func requestClarification(_ answer: ParsedConversationalAnswer) async {
        state = .redirecting
        consecutiveRedirects += 1

        let clarificationMessage: String
        if let reason = answer.clarificationReason {
            clarificationMessage = "I want to make sure I got that right. \(reason)"
        } else if let prompt = currentPrompt, let clarification = prompt.clarificationPrompt {
            clarificationMessage = clarification
        } else {
            clarificationMessage = "Could you say that again in a different way?"
        }

        await speakAndWait(clarificationMessage)
        state = .awaitingResponse
    }

    private func confirmAnswer(_ answer: ParsedConversationalAnswer) async {
        pendingAnswer = answer
        consecutiveRedirects = 0 // Reset on successful parse

        // Build confirmation message
        let confirmationMessage = buildConfirmationMessage(answer)
        zoeMessage = confirmationMessage

        state = .confirming(confirmationMessage)
        showConfirmation = true

        // For high confidence, auto-confirm after brief pause
        if answer.confidence >= 0.9 {
            await speakAndWait(confirmationMessage)

            // Brief pause then auto-confirm
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            if state == .confirming(confirmationMessage) {
                await acceptAnswer()
            }
        } else {
            await speakAndWait(confirmationMessage + " Is that right?")
        }
    }

    private func buildConfirmationMessage(_ answer: ParsedConversationalAnswer) -> String {
        // Build a natural confirmation based on the answer type
        guard let prompt = currentPrompt else { return "Got it." }

        switch prompt.expectedAnswerType {
        case .yesNo, .yesNoDontKnow:
            if let value = answer.parsedValues.values.first as? Bool {
                return value ? "Yes, got it." : "No, understood."
            }
        case .scale1to10, .scale0to4, .scale0to3:
            if let value = answer.parsedValues.values.first as? Int {
                return "That's a \(value)."
            }
        case .time:
            if let value = answer.parsedValues.values.first as? String {
                return "Around \(value)."
            }
        case .duration:
            if let value = answer.parsedValues.values.first as? Int {
                let hours = value / 60
                let mins = value % 60
                if hours > 0 {
                    return mins > 0 ? "About \(hours) hours and \(mins) minutes." : "About \(hours) hours."
                }
                return "About \(mins) minutes."
            }
        default:
            break
        }

        return "Got it."
    }

    // MARK: - Answer Acceptance

    func acceptAnswer() async {
        guard let answer = pendingAnswer else { return }

        showConfirmation = false
        state = .transitioning

        // Save the answer
        await saveAnswer(answer)

        // Check for gateway triggers
        if answer.triggersGateway, let gateway = answer.gatewayType {
            progress.gatewaysTriggered.insert(gateway)
        }

        // Update progress
        for questionId in answer.questionIds {
            progress.answeredQuestionIds.insert(questionId)
        }
        progress.questionsAnsweredToday += answer.questionIds.count
        progress.totalQuestionsAnswered += answer.questionIds.count
        progress.lastActivityTime = Date()

        // Transition phrase and move on
        if let transition = currentPrompt?.transitionPhrase {
            await speakAndWait(transition)
        }

        await moveToNextPrompt()
    }

    func rejectAnswer() async {
        showConfirmation = false
        pendingAnswer = nil

        await speakAndWait("Let me ask that again.")
        await repeatCurrentPrompt()
    }

    private func saveAnswer(_ answer: ParsedConversationalAnswer) async {
        // Save to QuestionnaireManager using existing saveResponse method
        for (questionId, value) in answer.parsedValues {
            var response: QuestionResponse

            // Handle different value types
            if let stringValue = value as? String {
                response = QuestionResponse(
                    questionId: questionId,
                    dayNumber: progress.currentDayNumber,
                    stringValue: stringValue
                )
            } else if let numberValue = value as? Double {
                response = QuestionResponse(
                    questionId: questionId,
                    dayNumber: progress.currentDayNumber,
                    numberValue: numberValue
                )
            } else if let intValue = value as? Int {
                response = QuestionResponse(
                    questionId: questionId,
                    dayNumber: progress.currentDayNumber,
                    numberValue: Double(intValue)
                )
            } else if let arrayValue = value as? [String] {
                response = QuestionResponse(
                    questionId: questionId,
                    dayNumber: progress.currentDayNumber,
                    arrayValue: arrayValue
                )
            } else {
                // Fallback to string representation
                response = QuestionResponse(
                    questionId: questionId,
                    dayNumber: progress.currentDayNumber,
                    stringValue: String(describing: value)
                )
            }

            await MainActor.run {
                questionnaireManager.saveResponse(response)
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: VoiceError) {
        state = .error(error.userMessage)

        Task {
            await speakAndWait("I'm having a bit of trouble. " + error.userMessage)

            if error.canRetry {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await repeatCurrentPrompt()
            }
        }
    }

    private func handleParsedResponse(_ response: ParsedResponse) {
        // Convert ParsedResponse to ParsedConversationalAnswer
        guard let prompt = currentPrompt else { return }

        var values: [String: Any] = [:]
        for questionId in prompt.questionIds {
            values[questionId] = response.value.responseValue
        }

        let answer = ParsedConversationalAnswer(
            questionIds: prompt.questionIds,
            rawTranscript: response.transcript,
            parsedValues: values,
            confidence: response.confidence,
            needsClarification: !response.isHighConfidence,
            clarificationReason: nil
        )

        Task {
            if answer.needsClarification {
                await requestClarification(answer)
            } else {
                await confirmAnswer(answer)
            }
        }
    }

    // MARK: - TTS

    private func speakAndWait(_ text: String) async {
        zoeMessage = text
        isZoeSpeaking = true

        await easyModeManager.speak(text)

        isZoeSpeaking = false
    }

    // MARK: - Scoring

    private func calculateScoresIfNeeded() async {
        // For expansion days (6-10), calculate relevant scores
        let day = progress.currentDayNumber

        switch day {
        case 6:
            // ISI, DBAS-6 scores
            await calculateScore(instrument: "ISI")
            await calculateScore(instrument: "DBAS")
        case 7:
            // PHQ-9, GAD-7, PSAS scores
            await calculateScore(instrument: "PHQ9")
            await calculateScore(instrument: "GAD7")
        case 8:
            // STOP-BANG, ESS, FSS scores
            await calculateScore(instrument: "STOPBANG")
            await calculateScore(instrument: "ESS")
        case 9:
            // Sleep Hygiene, BPI, FOSQ scores
            await calculateScore(instrument: "SHI")
            await calculateScore(instrument: "BPI")
        case 10:
            // PROMIS, MEDAS, MEQ scores
            await calculateScore(instrument: "PROMIS")
            await calculateScore(instrument: "MEQ")
        default:
            break
        }
    }

    private func calculateScore(instrument: String) async {
        // Delegate to ConvexService for backend scoring
        // Scores are calculated in physician.ts
        do {
            try await ConvexService.shared.calculateClinicalScore(instrument: instrument)
        } catch {
            print("Failed to calculate \(instrument) score: \(error)")
        }
    }
}

// MARK: - ConvexService Extension

extension ConvexService {

    /// Parse conversational response for assessment using dedicated Convex action
    func callConversationalParse(
        transcript: String,
        questionIds: [String],
        expectedType: String,
        context: [String: Any]
    ) async throws -> ConversationalParseResult {
        // Call the new parseConversationalResponse Convex action
        let dayNumber = context["dayNumber"] as? Int ?? 1
        let spokenPrompt = context["spokenPrompt"] as? String ?? ""
        let sectionTitle = context["sectionTitle"] as? String
        let isGateway = context["isGateway"] as? Bool ?? false
        let gatewayType = context["gatewayType"] as? String

        // Build validation rules
        var validationRules: [String: Any] = [:]
        if let minValue = context["minValue"] as? Double {
            validationRules["minValue"] = minValue
        }
        if let maxValue = context["maxValue"] as? Double {
            validationRules["maxValue"] = maxValue
        }
        if let options = context["options"] as? [String] {
            validationRules["acceptableOptions"] = options
        }

        // Build context for Convex
        var convexContext: [String: Any] = [
            "spokenPrompt": spokenPrompt,
            "dayNumber": dayNumber,
        ]
        if let sectionTitle = sectionTitle {
            convexContext["sectionTitle"] = sectionTitle
        }
        if !validationRules.isEmpty {
            convexContext["validationRules"] = validationRules
        }
        if isGateway {
            convexContext["isGateway"] = true
            if let gatewayType = gatewayType {
                convexContext["gatewayType"] = gatewayType
            }
        }

        do {
            // Call the Convex action
            let result = try await callParseConversationalResponse(
                transcript: transcript,
                questionIds: questionIds,
                expectedType: expectedType,
                context: convexContext
            )

            return result
        } catch {
            // Fallback to basic parsing if new action fails
            print("VoiceAssessmentSessionManager: Falling back to basic parsing: \(error)")

            let result = try await callVoiceParseResponse(
                transcript: transcript,
                context: VoiceParsingContext(
                    questionId: questionIds.first ?? "unknown",
                    questionText: spokenPrompt,
                    questionType: expectedType,
                    options: context["options"] as? [String],
                    minValue: context["minValue"] as? Int,
                    maxValue: context["maxValue"] as? Int
                )
            )

            var values: [String: Any] = [:]
            for questionId in questionIds {
                values[questionId] = result.value.responseValue
            }

            return ConversationalParseResult(
                values: values,
                confidence: result.confidence,
                clarificationNeeded: result.confidence < 0.7 ? "Could you be more specific?" : nil,
                triggersGateway: false,
                gatewayType: nil
            )
        }
    }

    /// Call the new parseConversationalResponse Convex action
    private func callParseConversationalResponse(
        transcript: String,
        questionIds: [String],
        expectedType: String,
        context: [String: Any]
    ) async throws -> ConversationalParseResult {
        guard let userId = ConvexService.shared.userId else {
            throw VoiceError.noUser
        }

        // Use ConvexService to call the conversational parse action
        let result = try await ConvexService.shared.parseConversationalResponse(
            transcript: transcript,
            questionIds: questionIds,
            expectedType: expectedType,
            context: context
        )

        return result
    }

    /// Calculate clinical score
    func calculateClinicalScore(instrument: String) async throws {
        // This calls physician.ts scoring functions
        // TODO: Implement
    }
}

// Note: ConversationalParseResult is defined in ConvexService.swift
