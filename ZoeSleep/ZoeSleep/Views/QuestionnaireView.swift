//
//  QuestionnaireView.swift
//  Zoe Sleep for Longevity System
//
//  Complete 15-day adaptive questionnaire interface with HealthKit integration
//  Features distinct Sleep Log and Assessment sections
//

import SwiftUI
import Combine


struct QuestionnaireView: View {
    @Binding var currentDay: Int
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var questionnaireManager = QuestionnaireManager.shared

    // Which section to start with (and optionally limit to)
    var startSection: QuestionnaireSection = .sleepLog
    var sectionOnly: Bool = false  // If true, only show this section (don't transition to next)

    // Section State
    @State private var currentSection: QuestionnaireSection = .sleepLog
    @State private var showingTransition: Bool = false
    @State private var showingCompletion: Bool = false
    @State private var completedSectionAtFinish: QuestionnaireSection? = nil  // Tracks which section triggered completion

    // Sleep Log State
    @State private var sleepLogQuestions: [Question] = []
    @State private var sleepLogIndex: Int = 0
    @State private var sleepLogResponses: [String: Any] = [:]

    // Assessment State
    @State private var assessmentQuestions: [Question] = []
    @State private var assessmentIndex: Int = 0
    @State private var assessmentResponses: [String: Any] = [:]

    // HealthKit
    @State private var healthKitSleepSummary: HealthKitSleepSummary?
    @State private var isLoadingHealthKit: Bool = false

    // Timing
    @State private var startTime: Date = Date()
    @State private var questionStartTime: Date = Date()

    @Environment(\.presentationMode) var presentationMode

    private var theme: ColorTheme { themeManager.currentTheme }

    // Current section questions and index
    private var currentQuestions: [Question] {
        currentSection == .sleepLog ? sleepLogQuestions : assessmentQuestions
    }

    private var currentIndex: Int {
        currentSection == .sleepLog ? sleepLogIndex : assessmentIndex
    }

    private var currentResponses: [String: Any] {
        currentSection == .sleepLog ? sleepLogResponses : assessmentResponses
    }

    var body: some View {
        Group {
            if showingTransition {
                SectionTransitionView(
                    fromSection: .sleepLog,
                    toSection: .assessment,
                    onContinue: {
                        withAnimation {
                            showingTransition = false
                            currentSection = .assessment
                        }
                    }
                )
            } else if showingCompletion {
                DayCompletionView(
                    dayNumber: currentDay,
                    sleepLogQuestionsCount: sleepLogQuestions.count,
                    assessmentQuestionsCount: assessmentQuestions.count,
                    triggeredGateways: questionnaireManager.gatewayStates.filter { $0.triggered }.map { $0.gatewayType },
                    onDone: {
                        completeDay()
                    },
                    // Pass which section was completed (nil = full day)
                    // Use the captured section from when completion was triggered
                    completedSection: sectionOnly ? completedSectionAtFinish : nil,
                    onProceedToNextSection: sectionOnly && completedSectionAtFinish == .sleepLog ? {
                        proceedToAssessment()
                    } : nil
                )
            } else {
                mainQuestionnaireView
            }
        }
        .navigationTitle(currentSection == .sleepLog ? "Sleep Log" : "Day \(currentDay) Assessment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadQuestions()
            if startSection == .sleepLog {
                fetchHealthKitSleepData()
            }
        }
        .onDisappear {
            // When leaving the questionnaire (back button or dismissal),
            // notify dashboard to refresh from Convex
            print("[iOS Questionnaire] View disappearing - posting refresh notification")
            NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)
        }
    }

    // MARK: - Main Questionnaire View

    private var mainQuestionnaireView: some View {
        ZStack {
            // Simplified wave background for questionnaire (reduced animations for performance)
            QuestionnaireWaveBackground()

            VStack(spacing: 0) {
                // Section Header
                SectionHeaderView(
                    section: currentSection,
                    currentQuestion: currentIndex + 1,
                    totalQuestions: currentQuestions.count
                )

                // Progress
                SectionProgressView(
                    section: currentSection,
                    currentIndex: currentIndex,
                    totalQuestions: currentQuestions.count
                )
                .padding(.vertical, 8)

                // Main Content
                ScrollView {
                    VStack(spacing: 20) {
                        // HealthKit Sleep Summary (show at start of sleep log)
                        if currentSection == .sleepLog && currentIndex == 0 && healthKitSleepSummary != nil {
                            HealthKitSleepCard(summary: healthKitSleepSummary!, theme: theme)
                                .padding(.horizontal)
                        }

                        // Current Question
                        if !currentQuestions.isEmpty && currentIndex < currentQuestions.count {
                            questionView(for: currentQuestions[currentIndex])
                                .padding(.horizontal)
                        }

                        // Gateway alerts (only show in assessment section)
                        if currentSection == .assessment {
                            ForEach(questionnaireManager.gatewayStates.filter { $0.triggered }, id: \.id) { gateway in
                                GatewayAlertBanner(gatewayType: gateway.gatewayType, isTriggered: true, theme: theme)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }

                // Navigation Buttons
                navigationButtons
            }
        }
    }

    // MARK: - Question View

    @ViewBuilder
    private func questionView(for question: Question) -> some View {
        SectionQuestionCard(section: currentSection, question: question) {
            switch question.questionType {
            case .scale:
                ScaleInput(
                    question: question,
                    value: binding(for: question.id, default: Double(question.scaleMin ?? 1)),
                    theme: theme
                )

            case .yesNo, .yesNoDontKnow:
                YesNoInput(
                    question: question,
                    value: stringBinding(for: question.id),
                    theme: theme
                )

            case .singleSelect:
                SingleSelectInput(
                    question: question,
                    value: stringBinding(for: question.id),
                    theme: theme
                )

            case .multiSelect:
                MultiSelectInput(
                    question: question,
                    values: arrayBinding(for: question.id),
                    theme: theme
                )

            case .number, .numberScroll:
                NumberInput(
                    question: question,
                    value: binding(for: question.id, default: Double(question.defaultValue ?? question.minValue ?? 0)),
                    theme: theme
                )

            case .time:
                TimeInput(
                    question: question,
                    value: dateBinding(for: question.id)
                )

            case .date:
                DateInputView(
                    question: question,
                    value: dateBinding(for: question.id)
                )

            case .text, .email:
                TextInputView(
                    question: question,
                    value: stringBinding(for: question.id),
                    placeholder: question.questionType == .email ? "email@example.com" : "Enter your answer"
                )

            case .minutesScroll:
                MinutesScrollPicker(
                    question: question,
                    value: intBinding(for: question.id, default: question.defaultValue ?? 0)
                )

            case .info:
                InfoCard(question: question, theme: theme)

            case .repeatingGroup:
                Text("Repeating group input (coming soon)")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Binding Helpers

    private func binding(for questionId: String, default defaultValue: Double) -> Binding<Double> {
        Binding(
            get: {
                if currentSection == .sleepLog {
                    return (sleepLogResponses[questionId] as? Double) ?? defaultValue
                } else {
                    return (assessmentResponses[questionId] as? Double) ?? defaultValue
                }
            },
            set: { newValue in
                if currentSection == .sleepLog {
                    sleepLogResponses[questionId] = newValue
                } else {
                    assessmentResponses[questionId] = newValue
                }
            }
        )
    }

    private func stringBinding(for questionId: String) -> Binding<String> {
        Binding(
            get: {
                if currentSection == .sleepLog {
                    return (sleepLogResponses[questionId] as? String) ?? ""
                } else {
                    return (assessmentResponses[questionId] as? String) ?? ""
                }
            },
            set: { newValue in
                if currentSection == .sleepLog {
                    sleepLogResponses[questionId] = newValue
                } else {
                    assessmentResponses[questionId] = newValue
                }
            }
        )
    }

    private func arrayBinding(for questionId: String) -> Binding<[String]> {
        Binding(
            get: {
                if currentSection == .sleepLog {
                    return (sleepLogResponses[questionId] as? [String]) ?? []
                } else {
                    return (assessmentResponses[questionId] as? [String]) ?? []
                }
            },
            set: { newValue in
                if currentSection == .sleepLog {
                    sleepLogResponses[questionId] = newValue
                } else {
                    assessmentResponses[questionId] = newValue
                }
            }
        )
    }

    private func dateBinding(for questionId: String) -> Binding<Date> {
        Binding(
            get: {
                if currentSection == .sleepLog {
                    return (sleepLogResponses[questionId] as? Date) ?? Date()
                } else {
                    return (assessmentResponses[questionId] as? Date) ?? Date()
                }
            },
            set: { newValue in
                if currentSection == .sleepLog {
                    sleepLogResponses[questionId] = newValue
                } else {
                    assessmentResponses[questionId] = newValue
                }
            }
        )
    }

    private func intBinding(for questionId: String, default defaultValue: Int) -> Binding<Int> {
        Binding(
            get: {
                if currentSection == .sleepLog {
                    return (sleepLogResponses[questionId] as? Int) ?? defaultValue
                } else {
                    return (assessmentResponses[questionId] as? Int) ?? defaultValue
                }
            },
            set: { newValue in
                if currentSection == .sleepLog {
                    sleepLogResponses[questionId] = newValue
                } else {
                    assessmentResponses[questionId] = newValue
                }
            }
        )
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: previousQuestion) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
            .disabled(currentIndex == 0 && currentSection == .sleepLog)
            .opacity((currentIndex == 0 && currentSection == .sleepLog) ? 0.5 : 1)

            // Next/Submit button
            Button(action: nextQuestion) {
                HStack {
                    Text(buttonText)
                    Image(systemName: buttonIcon)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed ? currentSection.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canProceed)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var buttonText: String {
        if currentSection == .sleepLog && isLastQuestionInSection {
            if sectionOnly {
                return "Complete"
            }
            return assessmentQuestions.isEmpty ? "Complete" : "Continue"
        } else if currentSection == .assessment && isLastQuestionInSection {
            return sectionOnly ? "Complete" : "Complete Day"
        }
        return "Next"
    }

    private var buttonIcon: String {
        if isLastQuestionInSection {
            if currentSection == .sleepLog && !sectionOnly && !assessmentQuestions.isEmpty {
                return "arrow.right.circle.fill"
            }
            return "checkmark.circle.fill"
        }
        return "chevron.right"
    }

    // MARK: - Properties

    private var isLastQuestionInSection: Bool {
        currentIndex == currentQuestions.count - 1
    }

    private var canProceed: Bool {
        guard !currentQuestions.isEmpty && currentIndex < currentQuestions.count else { return false }
        let question = currentQuestions[currentIndex]

        // Info questions don't require response
        if question.questionType == .info { return true }

        // Non-required questions can proceed
        if !question.required { return true }

        // Check if response exists
        let responses = currentSection == .sleepLog ? sleepLogResponses : assessmentResponses
        guard let response = responses[question.id] else { return false }

        // Validate based on type
        switch question.questionType {
        case .text, .email:
            return !(response as? String ?? "").isEmpty
        case .singleSelect, .yesNo, .yesNoDontKnow:
            return !(response as? String ?? "").isEmpty
        case .multiSelect:
            return !(response as? [String] ?? []).isEmpty
        default:
            return true
        }
    }

    // MARK: - Actions

    private func loadQuestions() {
        let allQuestions = questionnaireManager.getQuestionsForDay(currentDay)

        // Separate sleep log from assessment questions
        sleepLogQuestions = allQuestions.filter { $0.group == "sleep_log" || $0.pillar == .sleepLog }
        assessmentQuestions = allQuestions.filter { $0.group != "sleep_log" && $0.pillar != .sleepLog }

        // Start with the specified section (startSection is set in onAppear before this is called)
        currentSection = startSection
        sleepLogIndex = 0
        assessmentIndex = 0
        startTime = Date()
        questionStartTime = Date()

        // Pre-fill demographics from HealthKit (Day 1 only)
        if currentDay == 1 {
            prefillDemographicsFromHealthKit()
        }

        // Load saved progress from Convex (cross-device sync)
        loadSavedProgress()
    }

    /// Pre-fill demographic questions (D2, D4, D5, D6) from Apple Health
    private func prefillDemographicsFromHealthKit() {
        // Get HealthKit demographic data
        let demographicResponses = healthKitManager.getDemographicResponses()

        for (questionId, value) in demographicResponses {
            // Only pre-fill assessment responses (demographics are in assessment, not sleep log)
            if assessmentResponses[questionId] == nil {
                assessmentResponses[questionId] = value
                print("[iOS] Pre-filled \(questionId) from Apple Health")
            }
        }

        // Also update the questionnaire manager's responses
        questionnaireManager.prefillDemographicsFromHealthKit(healthKitManager)
    }

    /// Load saved progress and responses from Convex for cross-device sync
    private func loadSavedProgress() {
        Task {
            do {
                let section = startSection == .sleepLog ? "sleepLog" : "assessment"

                // Load question progress (which question user was on)
                if let progress = try await ConvexService.shared.getQuestionProgress(dayNumber: currentDay, section: section) {
                    await MainActor.run {
                        // Only resume if not completed
                        if !progress.completed {
                            let resumeIndex = progress.currentQuestionIndex
                            if startSection == .sleepLog && resumeIndex < sleepLogQuestions.count {
                                sleepLogIndex = resumeIndex
                                print("[iOS] Resuming sleep log at question \(resumeIndex + 1)/\(sleepLogQuestions.count) (last device: \(progress.lastDevice))")
                            } else if startSection == .assessment && resumeIndex < assessmentQuestions.count {
                                assessmentIndex = resumeIndex
                                print("[iOS] Resuming assessment at question \(resumeIndex + 1)/\(assessmentQuestions.count) (last device: \(progress.lastDevice))")
                            }
                        }
                    }
                }

                // Load saved responses to pre-fill answers
                let savedResponses = try await ConvexService.shared.getSavedResponses(dayNumber: currentDay)
                await MainActor.run {
                    for (questionId, value) in savedResponses {
                        // Determine which section this question belongs to
                        if sleepLogQuestions.contains(where: { $0.id == questionId }) {
                            if let str = value.stringValue {
                                sleepLogResponses[questionId] = str
                            } else if let num = value.numberValue {
                                sleepLogResponses[questionId] = num
                            } else if let arr = value.arrayValue {
                                sleepLogResponses[questionId] = arr
                            }
                        } else {
                            if let str = value.stringValue {
                                assessmentResponses[questionId] = str
                            } else if let num = value.numberValue {
                                assessmentResponses[questionId] = num
                            } else if let arr = value.arrayValue {
                                assessmentResponses[questionId] = arr
                            }
                        }
                    }
                    print("[iOS] Loaded \(savedResponses.count) saved responses from Convex")
                }
            } catch {
                print("[iOS] Failed to load saved progress: \(error)")
            }
        }
    }

    /// Save question progress to Convex after each question
    private func syncProgressToConvex() {
        let section = currentSection == .sleepLog ? "sleepLog" : "assessment"
        let index = currentSection == .sleepLog ? sleepLogIndex : assessmentIndex
        let total = currentSection == .sleepLog ? sleepLogQuestions.count : assessmentQuestions.count

        Task {
            do {
                try await ConvexService.shared.updateQuestionProgress(
                    dayNumber: currentDay,
                    section: section,
                    questionIndex: index,
                    totalQuestions: total
                )
                print("[iOS] Synced progress: \(section) question \(index + 1)/\(total)")
            } catch {
                print("[iOS] Failed to sync progress: \(error)")
            }
        }
    }

    private func fetchHealthKitSleepData() {
        guard healthKitManager.isAuthorized else { return }

        isLoadingHealthKit = true
        healthKitManager.fetchSleepData(daysBack: 1) { result in
            DispatchQueue.main.async {
                isLoadingHealthKit = false
                switch result {
                case .success(let data):
                    if let lastNight = data.first {
                        self.healthKitSleepSummary = parseHealthKitData(lastNight)
                    }
                case .failure(let error):
                    print("HealthKit fetch error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func parseHealthKitData(_ data: [String: Any]) -> HealthKitSleepSummary {
        let dateFormatter = ISO8601DateFormatter()

        return HealthKitSleepSummary(
            date: Date(),
            inBedTime: dateFormatter.date(from: data["in_bed_time"] as? String ?? ""),
            asleepTime: dateFormatter.date(from: data["asleep_time"] as? String ?? ""),
            wakeTime: dateFormatter.date(from: data["wake_time"] as? String ?? ""),
            totalSleepMinutes: data["total_sleep_mins"] as? Int,
            awakeningsCount: data["interruptions_count"] as? Int,
            awakeDurationMinutes: data["awake_mins"] as? Int,
            sleepEfficiency: data["sleep_efficiency"] as? Double,
            deepSleepMinutes: data["deep_sleep_mins"] as? Int,
            remSleepMinutes: data["rem_sleep_mins"] as? Int,
            lightSleepMinutes: data["light_sleep_mins"] as? Int
        )
    }

    private func previousQuestion() {
        if currentSection == .sleepLog {
            if sleepLogIndex > 0 {
                sleepLogIndex -= 1
                questionStartTime = Date()
            }
        } else {
            if assessmentIndex > 0 {
                assessmentIndex -= 1
                questionStartTime = Date()
            } else {
                // Go back to sleep log
                withAnimation {
                    currentSection = .sleepLog
                    sleepLogIndex = sleepLogQuestions.count - 1
                }
            }
        }
    }

    private func nextQuestion() {
        // Save current response
        saveCurrentResponse()

        if currentSection == .sleepLog {
            if isLastQuestionInSection {
                // Finished sleep log
                if sectionOnly || assessmentQuestions.isEmpty {
                    // Sleep log only mode OR no assessment questions - complete section
                    withAnimation {
                        completedSectionAtFinish = .sleepLog  // Capture which section we completed
                        showingCompletion = true
                    }
                } else {
                    // Show transition to assessment
                    withAnimation {
                        showingTransition = true
                    }
                }
            } else {
                sleepLogIndex += 1
                questionStartTime = Date()
                // Sync progress to Convex for cross-device sync
                syncProgressToConvex()
            }
        } else {
            if isLastQuestionInSection {
                // Finished assessment - show completion
                withAnimation {
                    completedSectionAtFinish = .assessment  // Capture which section we completed
                    showingCompletion = true
                }
            } else {
                assessmentIndex += 1
                questionStartTime = Date()
                // Sync progress to Convex for cross-device sync
                syncProgressToConvex()
            }
        }
    }

    /// Proceed from sleep log to assessment section
    /// This saves the sleep log responses, marks the section as complete in Convex,
    /// and transitions to the assessment questions within the same view
    private func proceedToAssessment() {
        // First, save all sleep log responses to the manager
        for (questionId, value) in sleepLogResponses {
            saveResponseFromDictionary(questionId: questionId, value: value, questions: sleepLogQuestions)
        }

        // Mark sleep log as complete in Convex (async, but don't block UI)
        Task {
            do {
                let result = try await ConvexService.shared.completeSection(dayNumber: currentDay, section: "sleepLog")
                print("[iOS] Sleep log section completed: sleepLog=\(result.sleepLogCompleted), assessment=\(result.assessmentCompleted)")

                // Refresh the journey progress so dashboard shows correct state if user navigates back
                await questionnaireManager.loadJourneyProgress()

                // Notify dashboard to refresh
                await MainActor.run {
                    NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)
                }
            } catch {
                print("[iOS] Error saving sleep log completion: \(error)")
            }
        }

        // Immediately transition to assessment section (don't wait for async)
        withAnimation(.easeInOut(duration: 0.3)) {
            showingCompletion = false
            currentSection = .assessment
            assessmentIndex = 0
            questionStartTime = Date()
        }
    }

    private func saveCurrentResponse() {
        let questions = currentSection == .sleepLog ? sleepLogQuestions : assessmentQuestions
        let index = currentSection == .sleepLog ? sleepLogIndex : assessmentIndex
        let responses = currentSection == .sleepLog ? sleepLogResponses : assessmentResponses

        guard !questions.isEmpty && index < questions.count else { return }
        let question = questions[index]

        guard let responseValue = responses[question.id] else { return }

        let answerTime = Int(Date().timeIntervalSince(questionStartTime))

        var response = QuestionResponse(
            questionId: question.id,
            dayNumber: currentDay,
            answeredAt: Date(),
            answeredInSeconds: answerTime
        )

        // Set the appropriate value based on type
        switch responseValue {
        case let str as String:
            response.stringValue = str
        case let num as Double:
            response.numberValue = num
        case let num as Int:
            response.numberValue = Double(num)
        case let date as Date:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            response.stringValue = formatter.string(from: date)
        case let arr as [String]:
            response.arrayValue = arr
        default:
            break
        }

        questionnaireManager.saveResponse(response)
    }

    private func completeDay() {
        // Save all remaining responses locally first
        for (questionId, value) in sleepLogResponses {
            saveResponseFromDictionary(questionId: questionId, value: value, questions: sleepLogQuestions)
        }
        for (questionId, value) in assessmentResponses {
            saveResponseFromDictionary(questionId: questionId, value: value, questions: assessmentQuestions)
        }

        print("[iOS] completeDay() called - sectionOnly=\(sectionOnly), completedSectionAtFinish=\(String(describing: completedSectionAtFinish))")

        // Determine what to complete based on which section just finished
        // completedSectionAtFinish tells us which section triggered the completion screen
        Task {
            do {
                // CRITICAL: Sync responses to Convex BEFORE completing the section
                // This is required because Convex validates that responses exist
                try await syncResponsesToConvex()

                if let section = completedSectionAtFinish {
                    // Mark the specific section as complete
                    let sectionName = section == .sleepLog ? "sleepLog" : "assessment"
                    print("[iOS] Calling completeSection for '\(sectionName)' on day \(currentDay)...")
                    let result = try await ConvexService.shared.completeSection(dayNumber: currentDay, section: sectionName)
                    print("[iOS] Section '\(sectionName)' completed: sleepLog=\(result.sleepLogCompleted), assessment=\(result.assessmentCompleted), dayComplete=\(result.dayFullyCompleted), newDay=\(result.currentDay)")

                    // If both sections are now complete, day advances automatically
                    if result.dayFullyCompleted {
                        print("[iOS] Day fully completed! Advancing to day \(result.currentDay)")
                        await MainActor.run {
                            currentDay = result.currentDay
                        }
                    }

                    // Refresh journey progress to update dashboard
                    await questionnaireManager.loadJourneyProgress()

                    // Post notification to ensure dashboard refreshes
                    await MainActor.run {
                        NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)
                    }
                } else {
                    // Legacy full day completion (non-sectionOnly mode)
                    print("[iOS] Legacy mode - completing full day \(currentDay)")
                    // Sync both sections' responses
                    try await syncResponsesToConvex()
                    try await questionnaireManager.completeDay(currentDay)
                    await MainActor.run {
                        currentDay = min(currentDay + 1, 15)
                    }
                }

                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("[iOS] Error completing: \(error.localizedDescription)")
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    /// Sync all responses to Convex before completing a section
    /// This ensures server-side validation can verify responses exist
    private func syncResponsesToConvex() async throws {
        var convexResponses: [[String: Any]] = []

        // Convert sleep log responses
        for (questionId, value) in sleepLogResponses {
            var response: [String: Any] = ["questionId": questionId]

            if let stringValue = value as? String {
                response["responseValue"] = stringValue
            } else if let numberValue = value as? Double {
                response["responseNumber"] = numberValue
            } else if let intValue = value as? Int {
                response["responseNumber"] = Double(intValue)
            } else if let dateValue = value as? Date {
                // Convert Date to time string
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                response["responseValue"] = formatter.string(from: dateValue)
            } else if let arrayValue = value as? [String] {
                response["responseArray"] = arrayValue
            }

            convexResponses.append(response)
        }

        // Convert assessment responses
        for (questionId, value) in assessmentResponses {
            var response: [String: Any] = ["questionId": questionId]

            if let stringValue = value as? String {
                response["responseValue"] = stringValue
            } else if let numberValue = value as? Double {
                response["responseNumber"] = numberValue
            } else if let intValue = value as? Int {
                response["responseNumber"] = Double(intValue)
            } else if let dateValue = value as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                response["responseValue"] = formatter.string(from: dateValue)
            } else if let arrayValue = value as? [String] {
                response["responseArray"] = arrayValue
            }

            convexResponses.append(response)
        }

        // Only sync if we have responses
        if !convexResponses.isEmpty {
            let result = try await ConvexService.shared.saveResponses(dayNumber: currentDay, responses: convexResponses)
            print("[iOS] Synced \(result.savedCount) responses to Convex")
        }
    }

    private func saveResponseFromDictionary(questionId: String, value: Any, questions: [Question]) {
        guard let question = questions.first(where: { $0.id == questionId }) else { return }

        var response = QuestionResponse(
            questionId: questionId,
            dayNumber: currentDay,
            answeredAt: Date(),
            answeredInSeconds: 0
        )

        switch value {
        case let str as String:
            response.stringValue = str
        case let num as Double:
            response.numberValue = num
        case let num as Int:
            response.numberValue = Double(num)
        case let date as Date:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            response.stringValue = formatter.string(from: date)
        case let arr as [String]:
            response.arrayValue = arr
        default:
            break
        }

        questionnaireManager.saveResponse(response)
    }
}

// MARK: - HealthKit Sleep Card

struct HealthKitSleepCard: View {
    let summary: HealthKitSleepSummary
    var theme: ColorTheme = ColorTheme.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(theme.health)
                Text("Last Night's Sleep (Apple Health)")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 20) {
                // Total sleep
                VStack {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                        .foregroundColor(QuestionnaireSection.sleepLog.accentColor)
                    if let mins = summary.totalSleepMinutes {
                        Text("\(mins / 60)h \(mins % 60)m")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("Total Sleep")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Sleep efficiency
                VStack {
                    Image(systemName: "percent")
                        .font(.title2)
                        .foregroundColor(theme.success)
                    if let eff = summary.sleepEfficiency {
                        Text("\(Int(eff))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("Efficiency")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Awakenings
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(theme.warning)
                    if let count = summary.awakeningsCount {
                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("Awakenings")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Time range
            HStack {
                if let inBed = summary.formattedInBedTime {
                    Label(inBed, systemImage: "bed.double.fill")
                        .font(.caption)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let wake = summary.formattedWakeTime {
                    Label(wake, systemImage: "sun.max.fill")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)

            Text("Now tell us your subjective experience - how YOU perceived your sleep")
                .font(.caption)
                .foregroundColor(QuestionnaireSection.sleepLog.accentColor)
                .padding(.top, 4)
        }
        .padding(16)
        .background(QuestionnaireSection.sleepLog.backgroundColor)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Sleep Log Only") {
    NavigationView {
        QuestionnaireView(currentDay: .constant(1), startSection: .sleepLog, sectionOnly: true)
            .environmentObject(HealthKitManager(authManager: AuthenticationManager()))
            .environmentObject(ThemeManager.shared)
    }
}

#Preview("Assessment Only") {
    NavigationView {
        QuestionnaireView(currentDay: .constant(1), startSection: .assessment, sectionOnly: true)
            .environmentObject(HealthKitManager(authManager: AuthenticationManager()))
            .environmentObject(ThemeManager.shared)
    }
}

#Preview("Full Day (Both)") {
    NavigationView {
        QuestionnaireView(currentDay: .constant(1), startSection: .sleepLog, sectionOnly: false)
            .environmentObject(HealthKitManager(authManager: AuthenticationManager()))
            .environmentObject(ThemeManager.shared)
    }
}
