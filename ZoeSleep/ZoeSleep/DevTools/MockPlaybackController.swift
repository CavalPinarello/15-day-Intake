//
//  MockPlaybackController.swift
//  ZoeSleep
//
//  Orchestrates mock data generation day-by-day, question-by-question
//  Uses real ConvexService for data persistence
//
//  NOTE: Available in all builds (including TestFlight) when Debug Mode is enabled
//

import Foundation
import Combine

/// Orchestrates the mock data generation process
@MainActor
class MockPlaybackController: ObservableObject {

    // MARK: - Published State

    @Published var state: MockGeneratorState = .idle
    @Published var progress: MockGenerationProgress = MockGenerationProgress()
    @Published var debugLog: [String] = []

    // MARK: - Dependencies

    private let config: MockGeneratorConfig
    private var generator: MockDataGenerator
    private var questionnaireManager: QuestionnaireManager { QuestionnaireManager.shared }
    private var convexService: ConvexService { ConvexService.shared }

    // MARK: - Control

    private var isCancelled = false
    private var generationTask: Task<Void, Never>?

    // MARK: - Initialization

    init(config: MockGeneratorConfig = MockGeneratorConfig()) {
        self.config = config
        self.generator = MockDataGenerator(config: config)
    }

    // MARK: - Public Methods

    /// Start the mock data generation process
    func startGeneration() {
        guard state == .idle || state == .cancelled || state.displayText.contains("Failed") else {
            return
        }

        isCancelled = false
        progress.reset()
        debugLog = []
        generator = MockDataGenerator(config: config)  // Fresh generator

        generationTask = Task {
            await runGeneration()
        }
    }

    /// Cancel the generation process
    func cancel() {
        isCancelled = true
        generationTask?.cancel()
        progress.markComplete()  // Freeze the elapsed time
        state = .cancelled
    }

    /// Reset to idle state
    func reset() {
        cancel()
        state = .idle
        progress.reset()
        debugLog = []
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        debugLog.append(logMessage)
        print("[MockGen] \(message)")
    }

    // MARK: - Generation Logic

    private func runGeneration() async {
        do {
            // Phase 1: Reset user progress
            state = .preparing
            log("Starting mock data generation...")

            do {
                log("Resetting user progress...")
                _ = try await convexService.resetJourneyProgress()
                log("Reset successful")
            } catch {
                log("Reset warning: \(error.localizedDescription) - continuing anyway")
            }

            // Brief pause after reset
            try await Task.sleep(nanoseconds: 200_000_000)

            guard !isCancelled else { return }

            // Phase 2: Generate data for each day
            for day in config.dayRange {
                guard !isCancelled else { return }

                state = .generatingDay(day)
                progress.currentDay = day
                progress.totalDays = config.dayRange.upperBound

                log("Starting Day \(day)...")

                // Generate and save Sleep Log
                let sleepLogQuestions = QuestionnaireManager.consensusSleepDiaryQuestions
                log("Generating \(sleepLogQuestions.count) sleep log questions...")

                try await generateAndSaveSection(
                    dayNumber: day,
                    sectionName: "Sleep Log",
                    sectionKey: "sleepLog",
                    questions: sleepLogQuestions
                )

                // Compute and persist sleep metrics to user_sleep_data table
                // This populates the dashboard's Sleep Quality Trend chart
                let dateForDay = dateString(forDayOffset: day - 1)
                do {
                    try await convexService.computeSleepMetricsFromResponses(dayNumber: day, date: dateForDay)
                    log("Computed sleep metrics for Day \(day)")
                } catch {
                    log("Sleep metrics warning: \(error.localizedDescription)")
                }

                guard !isCancelled else { return }

                // Get assessment questions for this day
                let assessmentQuestions = getAssessmentQuestions(for: day)
                log("Generating \(assessmentQuestions.count) assessment questions...")

                // Generate and save Assessment
                try await generateAndSaveSection(
                    dayNumber: day,
                    sectionName: "Assessment",
                    sectionKey: "assessment",
                    questions: assessmentQuestions
                )

                guard !isCancelled else { return }

                // Update triggered gateways from the generator (which pre-determines triggers)
                // We do this after Day 5 so the UI shows them during expansion days
                if day == 5 {
                    progress.triggeredGateways = Array(generator.gatewaysToTrigger)
                    if !generator.gatewaysToTrigger.isEmpty {
                        log("Triggered gateways: \(generator.gatewaysToTrigger.map { $0.displayName }.joined(separator: ", "))")
                    } else {
                        log("No gateways triggered (healthy sleeper profile)")
                    }
                }

                // Day transition
                state = .savingDay(day)

                // Advance to next day if not the last
                if day < config.dayRange.upperBound {
                    state = .transitioning(from: day, to: day + 1)
                    do {
                        _ = try await convexService.advanceToNextDay(debugMode: true)
                        log("Day \(day) complete, advanced to Day \(day + 1)")
                    } catch {
                        log("Advance day warning: \(error.localizedDescription) - continuing")
                    }
                    try await Task.sleep(nanoseconds: 50_000_000)  // 0.05s transition
                } else {
                    log("Day \(day) complete - final day!")
                }
            }

            // Persist calculated questionnaire scores to database
            // This populates the dashboard's Clinical Scores section
            state = .computingScores
            log("Computing and persisting questionnaire scores...")
            do {
                try await convexService.persistCalculatedScores()
                log("Questionnaire scores persisted successfully")
            } catch {
                log("Scores warning: \(error.localizedDescription)")
            }

            // Sync gateway states to Convex and local QuestionnaireManager
            log("Syncing gateway states...")
            for gatewayType in GatewayType.allCases {
                let isTriggered = generator.gatewaysToTrigger.contains(gatewayType)
                do {
                    try await convexService.updateGatewayState(
                        gatewayId: gatewayType.rawValue,
                        isTriggered: isTriggered,
                        triggerQuestionId: nil,
                        triggerValue: nil
                    )
                } catch {
                    log("Gateway sync warning for \(gatewayType.rawValue): \(error.localizedDescription)")
                }
            }
            log("Gateway states synced to Convex")

            // Update local QuestionnaireManager gateway states to match
            for i in 0..<questionnaireManager.gatewayStates.count {
                let gatewayType = questionnaireManager.gatewayStates[i].gatewayType
                let isTriggered = generator.gatewaysToTrigger.contains(gatewayType)
                questionnaireManager.gatewayStates[i].triggered = isTriggered
                if isTriggered {
                    questionnaireManager.gatewayStates[i].triggeredAt = Date()
                }
            }
            log("Local gateway states updated")

            // Success!
            progress.markComplete()  // Freeze the elapsed time
            state = .completed
            log("Mock data generation complete! Generated \(progress.totalQuestionsAnswered) answers.")

            // Post notification so dashboard updates
            NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)

        } catch {
            if !isCancelled {
                progress.markComplete()  // Freeze the elapsed time
                log("FAILED: \(error.localizedDescription)")
                state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Section Generation

    private func generateAndSaveSection(dayNumber: Int, sectionName: String, sectionKey: String, questions: [Question]) async throws {
        progress.currentSection = sectionName
        progress.totalQuestionsForSection = questions.count
        progress.currentQuestionIndex = 0

        var responses: [[String: Any]] = []

        for (index, question) in questions.enumerated() {
            guard !isCancelled else { return }

            // Update progress
            progress.currentQuestionIndex = index + 1
            progress.currentQuestionId = question.id
            progress.currentQuestionText = question.text

            // Generate mock answer
            let mockResponse = generator.generateAnswer(for: question, dayNumber: dayNumber)

            // Skip empty responses (e.g., name field that should preserve user's real name)
            if mockResponse.isEmpty {
                progress.currentAnswer = "(skipped - preserving existing value)"
                continue
            }

            progress.currentAnswer = generator.displayValue(for: mockResponse)
            progress.totalQuestionsAnswered += 1

            // Add to batch
            responses.append(mockResponse.toDictionary())

            // Brief visual feedback delay
            try await Task.sleep(nanoseconds: UInt64(config.questionDelay * 1_000_000_000))
        }

        // Batch save all responses for this section
        if !responses.isEmpty {
            do {
                _ = try await convexService.saveResponses(dayNumber: dayNumber, responses: responses)
                log("Saved \(responses.count) responses for \(sectionName)")
            } catch {
                log("Save warning: \(error.localizedDescription)")
                // Continue anyway - some saves might partially succeed
            }
        }

        // Complete the section
        do {
            _ = try await convexService.completeSection(dayNumber: dayNumber, section: sectionKey)
            log("\(sectionName) section completed")
        } catch {
            log("Complete section warning: \(error.localizedDescription)")
            // Continue - the responses are saved even if completion marking fails
        }
    }

    // MARK: - Helper Methods

    /// Get assessment questions (not sleep log) for a specific day
    private func getAssessmentQuestions(for dayNumber: Int) -> [Question] {
        // Days 1-5: Core assessment questions
        if dayNumber <= 5 {
            return QuestionnaireManager.coreQuestionsByDay[dayNumber] ?? []
        }

        // Days 6-15: Check for expansion questions based on triggered gateways
        // Use generator.gatewaysToTrigger instead of questionnaireManager (which doesn't have mock data)
        guard let dayConfig = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == dayNumber }) else {
            return []
        }

        // Check if any required gateway is triggered (using our pre-determined triggers)
        let triggeredGateways = generator.gatewaysToTrigger
        let shouldShowExpansion = dayConfig.requiredGateways?.contains(where: { triggeredGateways.contains($0) }) ?? false

        if shouldShowExpansion {
            var questions: [Question] = []
            for moduleId in dayConfig.moduleIds {
                if let moduleQuestions = QuestionnaireManager.expansionQuestionsByModule[moduleId] {
                    questions.append(contentsOf: moduleQuestions)
                }
            }
            return questions
        }

        // No expansion triggered - return empty array
        // The iOS client properly handles empty assessments by not showing the "Proceed to Assessment" button
        return []
    }

    // MARK: - Date Helpers

    /// Generate a date string (YYYY-MM-DD) for a given day offset from today
    /// Day 1 = today, Day 2 = yesterday, etc. (sleep logs report previous night)
    private func dateString(forDayOffset offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
