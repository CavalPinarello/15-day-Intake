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
    @ObservedObject private var gamificationManager = GamificationManager.shared

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
    @State private var sleepLogUserInteracted: Set<String> = []  // Track which questions user actually touched

    // Assessment State
    @State private var assessmentQuestions: [Question] = []
    @State private var assessmentIndex: Int = 0
    @State private var assessmentResponses: [String: Any] = [:]
    @State private var assessmentUserInteracted: Set<String> = []  // Track which questions user actually touched

    // HealthKit
    @State private var healthKitSleepSummary: HealthKitSleepSummary?
    @State private var isLoadingHealthKit: Bool = false

    // Timing
    @State private var startTime: Date = Date()
    @State private var questionStartTime: Date = Date()

    // Reward Moments
    @StateObject private var rewardManager = RewardMomentManager()
    @State private var showingRewardCard: Bool = false

    // Save Status & Error Handling
    @State private var isSaving: Bool = false
    @State private var saveError: String? = nil
    @State private var showingSaveError: Bool = false
    @State private var retryAction: (() -> Void)? = nil

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
            } else if showingRewardCard, let fact = rewardManager.currentFact {
                // Reward moment with sleep fact
                SleepFactRewardCard(
                    fact: fact,
                    onDismiss: {
                        withAnimation {
                            showingRewardCard = false
                            rewardManager.dismissReward()
                            // Continue to next question after dismissing reward
                            advanceToNextQuestion()
                        }
                    }
                )
            } else {
                mainQuestionnaireView
            }
        }
        .navigationTitle(currentSection == .sleepLog ? "Sleep Log" : "Day \(currentDay) Assessment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(navBarBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isEvening ? .dark : .light, for: .navigationBar)
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
        .overlay {
            // Saving overlay
            if isSaving {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(theme.primary)

                        Text("Saving your responses...")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.cardBackground.opacity(0.95))
                    )
                }
                .transition(.opacity)
            }
        }
        .alert("Save Failed", isPresented: $showingSaveError) {
            Button("Try Again") {
                retryAction?()
            }
            Button("Cancel", role: .cancel) {
                // Stay on current screen, don't dismiss
            }
        } message: {
            Text(saveError ?? "An error occurred while saving your responses. Please check your internet connection and try again.")
        }
        // Gamification Overlays
        .overlay {
            // Badge Unlock Animation
            if gamificationManager.showBadgeUnlockedAnimation, let badge = gamificationManager.unlockedBadge {
                BadgeUnlockView(badge: badge) {
                    gamificationManager.showBadgeUnlockedAnimation = false
                    gamificationManager.unlockedBadge = nil
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .overlay {
            // Level Up Animation
            if gamificationManager.showLevelUpAnimation, let levelInfo = gamificationManager.newLevelInfo {
                LevelUpCelebration(
                    newLevel: levelInfo.level,
                    levelName: levelInfo.name,
                    isVisible: true
                ) {
                    gamificationManager.showLevelUpAnimation = false
                    gamificationManager.newLevelInfo = nil
                }
                .transition(.opacity)
                .zIndex(101)
            }
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
                    value: binding(for: question.id, default: ScaleInput.smartDefault(for: question)),
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
                    value: binding(for: question.id, default: NumberInput.smartDefault(for: question)),
                    theme: theme
                )

            case .time:
                TimeInput(
                    question: question,
                    value: dateBinding(for: question.id, question: question, previousBedtime: getPreviousBedtime(for: question.id)),
                    previousBedtime: getPreviousBedtime(for: question.id)
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
                print("[iOS BINDING] Setting \(questionId) = \(newValue), userInteracted=true")
                if currentSection == .sleepLog {
                    sleepLogResponses[questionId] = newValue
                    sleepLogUserInteracted.insert(questionId)
                } else {
                    assessmentResponses[questionId] = newValue
                    assessmentUserInteracted.insert(questionId)
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
                    sleepLogUserInteracted.insert(questionId)
                } else {
                    assessmentResponses[questionId] = newValue
                    assessmentUserInteracted.insert(questionId)
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
                    sleepLogUserInteracted.insert(questionId)
                } else {
                    assessmentResponses[questionId] = newValue
                    assessmentUserInteracted.insert(questionId)
                }
            }
        )
    }

    private func dateBinding(for questionId: String) -> Binding<Date> {
        dateBinding(for: questionId, question: nil, previousBedtime: nil)
    }

    private func dateBinding(for questionId: String, question: Question?, previousBedtime: Date?) -> Binding<Date> {
        // Calculate smart default based on question context
        let defaultDate: Date
        if let q = question {
            defaultDate = TimeInput.smartDefault(for: q, previousBedtime: previousBedtime)
        } else {
            defaultDate = Date()
        }

        return Binding(
            get: {
                if currentSection == .sleepLog {
                    return (sleepLogResponses[questionId] as? Date) ?? defaultDate
                } else {
                    return (assessmentResponses[questionId] as? Date) ?? defaultDate
                }
            },
            set: { newValue in
                if currentSection == .sleepLog {
                    sleepLogResponses[questionId] = newValue
                    sleepLogUserInteracted.insert(questionId)
                } else {
                    assessmentResponses[questionId] = newValue
                    assessmentUserInteracted.insert(questionId)
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
                    sleepLogUserInteracted.insert(questionId)
                } else {
                    assessmentResponses[questionId] = newValue
                    assessmentUserInteracted.insert(questionId)
                }
            }
        )
    }

    // MARK: - Smart Default Helpers

    /// Returns the previously answered bedtime to help set smart defaults for subsequent time questions
    private func getPreviousBedtime(for questionId: String) -> Date? {
        // For Consensus Sleep Diary questions, chain the time dependencies
        if currentSection == .sleepLog {
            switch questionId {
            // CSD Question Dependencies
            case "CSD_TRY_SLEEP":
                // Try to sleep is shortly after getting into bed
                return sleepLogResponses["CSD_INTO_BED"] as? Date
            case "CSD_FINAL_WAKE":
                // Final wake is ~8 hours after trying to sleep
                return sleepLogResponses["CSD_TRY_SLEEP"] as? Date ?? sleepLogResponses["CSD_INTO_BED"] as? Date
            case "CSD_OUT_BED":
                // Out of bed is shortly after final wake
                return sleepLogResponses["CSD_FINAL_WAKE"] as? Date
            case "CSD_CAFFEINE_LAST":
                // No dependency, but might use a midday default
                return nil
            case "CSD_ALCOHOL_LAST":
                // No dependency, but might use an evening default
                return nil

            // Legacy Stanford Sleep Diary question dependencies
            case "SD_LIGHTS_OUT":
                return sleepLogResponses["SD_GOT_INTO_BED"] as? Date
            case "SL_ASLEEP_TIME":
                return sleepLogResponses["SD_LIGHTS_OUT"] as? Date ?? sleepLogResponses["SD_GOT_INTO_BED"] as? Date
            case "SL_WAKE_TIME":
                return sleepLogResponses["SL_ASLEEP_TIME"] as? Date ?? sleepLogResponses["SD_LIGHTS_OUT"] as? Date
            case "SD_OUT_OF_BED":
                return sleepLogResponses["SL_WAKE_TIME"] as? Date
            default:
                break
            }
        }

        // For assessment questions, check for PSQI bedtime
        if currentSection == .assessment {
            // PSQI_3 (wake time) should use PSQI_1 (bedtime)
            if questionId == "PSQI_3" {
                return assessmentResponses["PSQI_1"] as? Date
            }
            // Questions 8, 10 (weekend/weekday wake times) should use corresponding bedtime
            if questionId == "8" {
                return assessmentResponses["7"] as? Date  // weekday wake uses weekday bed
            }
            if questionId == "10" {
                return assessmentResponses["9"] as? Date  // weekend wake uses weekend bed
            }
        }

        return nil
    }

    // MARK: - Navigation Buttons

    // Circadian-aware button colors
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var buttonBackgroundColor: Color {
        if isEvening {
            return Color(red: 0.25, green: 0.15, blue: 0.1)  // Dark brown
        } else {
            return Color(.secondarySystemBackground)
        }
    }

    private var buttonTextColor: Color {
        if isEvening {
            return Color(red: 0.988, green: 0.827, blue: 0.302)  // Golden yellow #FCD34D
        } else {
            return Color.primary
        }
    }

    private var navBarBackgroundColor: Color {
        if isEvening {
            return Color(red: 0.15, green: 0.08, blue: 0.05)  // Very dark brown
        } else {
            return Color(.systemBackground)
        }
    }

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
                .background(buttonBackgroundColor)
                .foregroundColor(buttonTextColor)
                .cornerRadius(12)
            }
            .disabled(isBackButtonDisabled)
            .opacity(isBackButtonDisabled ? 0.5 : 1)

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
        .background(navBarBackgroundColor)
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

    /// Back button should be disabled when:
    /// - Sleep Log at first question (can't go back further)
    /// - Assessment at first question AND in sectionOnly mode (can't go back to Sleep Log)
    private var isBackButtonDisabled: Bool {
        if currentSection == .sleepLog {
            return currentIndex == 0
        } else {
            // Assessment section
            return currentIndex == 0 && sectionOnly
        }
    }

    private var canProceed: Bool {
        guard !currentQuestions.isEmpty && currentIndex < currentQuestions.count else { return false }
        let question = currentQuestions[currentIndex]

        // Info questions don't require response
        if question.questionType == .info { return true }

        // Non-required questions can proceed
        if !question.required { return true }

        // Check if user has actually interacted with this question
        let userInteracted = currentSection == .sleepLog ? sleepLogUserInteracted : assessmentUserInteracted
        let responses = currentSection == .sleepLog ? sleepLogResponses : assessmentResponses

        switch question.questionType {
        case .number, .numberScroll:
            // Number inputs with +/- buttons - user MUST interact to proceed
            // (otherwise they might accidentally skip without noticing the default)
            return userInteracted.contains(question.id)
        case .scale, .time, .date, .minutesScroll:
            // Scale sliders, time/date/minutes pickers show a visible default that user can accept
            // Allow proceeding without interaction - if they don't change it, they're accepting it
            // The value will be saved when they tap Next (marked as interacted in saveCurrentResponse)
            return true
        case .text, .email:
            guard let response = responses[question.id] else { return false }
            return !(response as? String ?? "").isEmpty
        case .singleSelect, .yesNo, .yesNoDontKnow:
            guard let response = responses[question.id] else { return false }
            return !(response as? String ?? "").isEmpty
        case .multiSelect:
            guard let response = responses[question.id] else { return false }
            return !(response as? [String] ?? []).isEmpty
        default:
            // For other types, check if user interacted OR if response exists
            return userInteracted.contains(question.id) || responses[question.id] != nil
        }
    }

    // MARK: - Actions

    private func loadQuestions() {
        // Use async task to fetch questions from Convex (THE SINGLE SOURCE OF TRUTH)
        Task {
            do {
                print("[iOS] Fetching questions from Convex for Day \(currentDay)...")
                let questionsResponse = try await ConvexService.shared.getQuestionsForUserDay(dayNumber: currentDay, section: "all")

                // Convert Convex questions to iOS Question type
                let convertedSleepLog = questionsResponse.sleepLog.map { convertConvexQuestion($0, isSleepLog: true) }
                let convertedAssessment = questionsResponse.assessment.map { convertConvexQuestion($0, isSleepLog: false) }

                await MainActor.run {
                    sleepLogQuestions = convertedSleepLog
                    assessmentQuestions = convertedAssessment

                    print("[iOS] === QUESTIONS LOADED ===")
                    print("[iOS] Loaded \(sleepLogQuestions.count) sleep log + \(assessmentQuestions.count) assessment questions from Convex")
                    print("[iOS] Triggered gateways: \(questionsResponse.metadata.triggeredGateways.joined(separator: ", "))")

                    // Start with the specified section
                    currentSection = startSection
                    print("[iOS] BEFORE RESET: sleepLogIndex=\(sleepLogIndex), assessmentIndex=\(assessmentIndex)")
                    sleepLogIndex = 0
                    assessmentIndex = 0
                    print("[iOS] AFTER RESET: sleepLogIndex=\(sleepLogIndex), assessmentIndex=\(assessmentIndex)")
                    startTime = Date()
                    questionStartTime = Date()

                    // Pre-fill demographics from HealthKit (Day 1 only)
                    if currentDay == 1 {
                        prefillDemographicsFromHealthKit()
                    }

                    // Load saved progress from Convex (cross-device sync)
                    print("[iOS] About to call loadSavedProgress()...")
                    loadSavedProgress()
                }
            } catch {
                print("[iOS] Error fetching questions from Convex: \(error.localizedDescription)")
                // Fallback to local questions if Convex fails
                await MainActor.run {
                    let allQuestions = questionnaireManager.getQuestionsForDay(currentDay)
                    sleepLogQuestions = allQuestions.filter { $0.group == "sleep_log" || $0.pillar == .sleepLog }
                    assessmentQuestions = allQuestions.filter { $0.group != "sleep_log" && $0.pillar != .sleepLog }

                    print("[iOS] Fallback: Using local questions (\(sleepLogQuestions.count) sleep log + \(assessmentQuestions.count) assessment)")

                    currentSection = startSection
                    sleepLogIndex = 0
                    assessmentIndex = 0
                    startTime = Date()
                    questionStartTime = Date()

                    if currentDay == 1 {
                        prefillDemographicsFromHealthKit()
                    }
                    loadSavedProgress()
                }
            }
        }
    }

    /// Convert a ConvexQuestion to the iOS Question type
    private func convertConvexQuestion(_ cq: ConvexQuestion, isSleepLog: Bool) -> Question {
        // Map Convex question type to iOS QuestionType
        let questionType: QuestionType
        switch cq.type {
        case "time": questionType = .time
        case "scale": questionType = .scale
        case "number": questionType = .number
        case "yesNo": questionType = .yesNo
        case "singleSelect": questionType = .singleSelect
        case "multiSelect": questionType = .multiSelect
        case "text": questionType = .text
        case "info": questionType = .info
        default: questionType = .text
        }

        // Extract scale config from formatConfig if available
        var scaleMin: Int? = nil
        var scaleMax: Int? = nil
        var scaleMinLabel: String? = nil
        var scaleMaxLabel: String? = nil
        var minValue: Int? = nil
        var maxValue: Int? = nil

        if let config = cq.formatConfig {
            if let min = config["min"]?.value as? Int { scaleMin = min; minValue = min }
            if let max = config["max"]?.value as? Int { scaleMax = max; maxValue = max }
            if let minLabel = config["minLabel"]?.value as? String { scaleMinLabel = minLabel }
            if let maxLabel = config["maxLabel"]?.value as? String { scaleMaxLabel = maxLabel }
        }

        // Convert conditional logic if present
        var conditionalLogic: ConditionalLogic? = nil
        if let convexLogic = cq.conditionalLogic {
            conditionalLogic = ConditionalLogic(
                questionId: convexLogic.questionId,
                equals: convexLogic.equals,
                greaterThan: convexLogic.greaterThan
            )
        }

        return Question(
            id: cq.id,
            text: cq.text,
            pillar: isSleepLog ? .sleepLog : .sleepQuality,
            tier: .core,
            questionType: questionType,
            estimatedMinutes: 0.5,
            required: cq.required,
            options: cq.options,
            scaleMin: scaleMin,
            scaleMax: scaleMax,
            scaleMinLabel: scaleMinLabel,
            scaleMaxLabel: scaleMaxLabel,
            minValue: minValue,
            maxValue: maxValue,
            helpText: cq.helpText,
            isGateway: false,
            conditionalLogic: conditionalLogic,
            group: isSleepLog ? "sleep_log" : nil
        )
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
        print("[iOS] loadSavedProgress() called - startSection=\(startSection), currentDay=\(currentDay)")
        print("[iOS] Current indices before load: sleepLogIndex=\(sleepLogIndex), assessmentIndex=\(assessmentIndex)")
        print("[iOS] Current responses before load: sleepLog=\(sleepLogResponses.count), assessment=\(assessmentResponses.count)")

        Task {
            do {
                let section = startSection == .sleepLog ? "sleepLog" : "assessment"

                // First, load saved responses so we can validate progress against them
                var loadedResponseCount = 0
                let savedResponses = try await ConvexService.shared.getSavedResponses(dayNumber: currentDay)
                print("[iOS] Convex returned \(savedResponses.count) saved responses")
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
                            // Mark as user-interacted since it was previously saved
                            sleepLogUserInteracted.insert(questionId)
                        } else {
                            if let str = value.stringValue {
                                assessmentResponses[questionId] = str
                            } else if let num = value.numberValue {
                                assessmentResponses[questionId] = num
                            } else if let arr = value.arrayValue {
                                assessmentResponses[questionId] = arr
                            }
                            // Mark as user-interacted since it was previously saved
                            assessmentUserInteracted.insert(questionId)
                        }
                    }
                    loadedResponseCount = savedResponses.count
                    print("[iOS] Loaded \(savedResponses.count) saved responses from Convex (marked as user-interacted)")
                }

                // Load question progress (which question user was on)
                if let progress = try await ConvexService.shared.getQuestionProgress(dayNumber: currentDay, section: section) {
                    await MainActor.run {
                        // Only resume if:
                        // 1. Session is not marked as completed
                        // 2. The saved question index is valid for current question set
                        // 3. We have at least some saved responses to support the progress
                        //    (prevents jumping to a stale position from old sessions)
                        let resumeIndex = progress.currentQuestionIndex
                        let hasResponses = loadedResponseCount > 0

                        if !progress.completed && resumeIndex > 0 && hasResponses {
                            if startSection == .sleepLog && resumeIndex < sleepLogQuestions.count {
                                sleepLogIndex = resumeIndex
                                print("[iOS] Resuming sleep log at question \(resumeIndex + 1)/\(sleepLogQuestions.count) (last device: \(progress.lastDevice))")
                            } else if startSection == .assessment && resumeIndex < assessmentQuestions.count {
                                assessmentIndex = resumeIndex
                                print("[iOS] Resuming assessment at question \(resumeIndex + 1)/\(assessmentQuestions.count) (last device: \(progress.lastDevice))")
                            }
                        } else if resumeIndex > 0 {
                            // Log why we're not resuming
                            print("[iOS] Ignoring stale progress for \(section): index=\(resumeIndex), completed=\(progress.completed), responseCount=\(loadedResponseCount)")
                        }
                    }
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
            } else if !sectionOnly {
                // Only go back to sleep log if we're in full-day mode (not section-only)
                withAnimation {
                    currentSection = .sleepLog
                    sleepLogIndex = sleepLogQuestions.count - 1
                }
            }
            // If sectionOnly is true, do nothing - the Back button should already be disabled
        }
    }

    private func nextQuestion() {
        // Save current response
        saveCurrentResponse()

        if currentSection == .sleepLog {
            // SLEEP LOG SECTION - Check for reward moment (calibration encouragement)
            let isFirst = sleepLogIndex == 0
            let isLast = isLastQuestionInSection

            // Notify reward manager for encouragement during calibration period
            if !isFirst && !isLast && !sleepLogQuestions.isEmpty {
                let currentQuestion = sleepLogQuestions[sleepLogIndex]
                rewardManager.onQuestionAnswered(
                    question: currentQuestion,
                    isFirstInSection: isFirst,
                    isLastInSection: isLast,
                    section: currentSection
                )
            }

            if isLast {
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
                // Check if reward should show BEFORE advancing
                if rewardManager.shouldShowReward {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showingRewardCard = true
                    }
                } else {
                    advanceToNextQuestion()
                }
            }
        } else {
            // ASSESSMENT SECTION - Check for reward moment
            let isFirst = assessmentIndex == 0
            let isLast = isLastQuestionInSection

            // Notify reward manager (only for non-first, non-last questions)
            if !isFirst && !isLast {
                let currentQuestion = assessmentQuestions[assessmentIndex]
                rewardManager.onQuestionAnswered(
                    question: currentQuestion,
                    isFirstInSection: isFirst,
                    isLastInSection: isLast,
                    section: currentSection
                )
            }

            if isLast {
                // Finished assessment - show completion
                withAnimation {
                    completedSectionAtFinish = .assessment  // Capture which section we completed
                    showingCompletion = true
                }
            } else {
                // Check if reward should show BEFORE advancing
                if rewardManager.shouldShowReward {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showingRewardCard = true
                    }
                } else {
                    advanceToNextQuestion()
                }
            }
        }
    }

    /// Check if a question should be shown based on its conditional logic
    private func shouldShowQuestion(_ question: Question, responses: [String: Any]) -> Bool {
        guard let condition = question.conditionalLogic else {
            return true // No condition = always show
        }

        // Get the response to the dependent question
        guard let dependentResponse = responses[condition.questionId] else {
            return false // No response to dependent question = hide
        }

        // Check equals condition
        if let equalsValue = condition.equals {
            if let stringResponse = dependentResponse as? String {
                return stringResponse.lowercased() == equalsValue.lowercased()
            }
            return false
        }

        // Check greaterThan condition
        if let greaterThanValue = condition.greaterThan {
            if let numResponse = dependentResponse as? Double {
                return numResponse > greaterThanValue
            } else if let numResponse = dependentResponse as? Int {
                return Double(numResponse) > greaterThanValue
            } else if let stringResponse = dependentResponse as? String,
                      let numValue = Double(stringResponse) {
                return numValue > greaterThanValue
            }
            return false
        }

        return true
    }

    /// Advance to the next question (called after reward dismissal or directly)
    /// Skips questions whose conditional logic is not met
    private func advanceToNextQuestion() {
        let questions = currentSection == .sleepLog ? sleepLogQuestions : assessmentQuestions
        let responses = currentSection == .sleepLog ? sleepLogResponses : assessmentResponses
        var nextIndex = (currentSection == .sleepLog ? sleepLogIndex : assessmentIndex) + 1

        // Skip questions whose conditions are not met
        while nextIndex < questions.count && !shouldShowQuestion(questions[nextIndex], responses: responses) {
            print("[iOS] Skipping question \(questions[nextIndex].id) - conditional logic not met")
            nextIndex += 1
        }

        if currentSection == .sleepLog {
            sleepLogIndex = nextIndex
        } else {
            assessmentIndex = nextIndex
        }
        questionStartTime = Date()
        syncProgressToConvex()
    }

    /// Proceed from sleep log to assessment section
    /// This saves the sleep log responses, marks the section as complete in Convex,
    /// and transitions to the assessment questions within the same view
    private func proceedToAssessment() {
        // First, save all sleep log responses to the manager
        for (questionId, value) in sleepLogResponses {
            saveResponseFromDictionary(questionId: questionId, value: value, questions: sleepLogQuestions)
        }

        // Show saving indicator and sync to Convex BEFORE transitioning
        isSaving = true

        Task {
            do {
                // CRITICAL: Sync responses FIRST, then mark complete
                try await syncResponsesToConvex()

                let result = try await ConvexService.shared.completeSection(dayNumber: currentDay, section: "sleepLog")
                print("[iOS] Sleep log section completed: sleepLog=\(result.sleepLogCompleted), assessment=\(result.assessmentCompleted)")

                // Refresh the journey progress so dashboard shows correct state if user navigates back
                await questionnaireManager.loadJourneyProgress()

                // Notify dashboard to refresh
                await MainActor.run {
                    NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)
                    isSaving = false

                    // Only transition after successful save
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingCompletion = false
                        currentSection = .assessment
                        assessmentIndex = 0
                        questionStartTime = Date()
                    }
                }
            } catch {
                print("[iOS] Error saving sleep log: \(error)")
                print("[iOS] Sleep log responses count: \(sleepLogResponses.count)")
                print("[iOS] Sleep log response keys: \(Array(sleepLogResponses.keys))")
                await MainActor.run {
                    isSaving = false
                    // Show detailed error for debugging
                    let errorDetail = (error as? ConvexError)?.localizedDescription ?? error.localizedDescription
                    saveError = "Failed to save your sleep log. \(errorDetail)"
                    showingSaveError = true
                    retryAction = { proceedToAssessment() }
                }
            }
        }
    }

    private func saveCurrentResponse() {
        let questions = currentSection == .sleepLog ? sleepLogQuestions : assessmentQuestions
        let index = currentSection == .sleepLog ? sleepLogIndex : assessmentIndex

        guard !questions.isEmpty && index < questions.count else { return }
        let question = questions[index]

        let answerTime = Int(Date().timeIntervalSince(questionStartTime))

        // For scale questions, user can accept the smart default by tapping Next
        if question.questionType == .scale {
            let valueToSave: Double
            let defaultValue = ScaleInput.smartDefault(for: question)
            if currentSection == .sleepLog {
                if let existingValue = sleepLogResponses[question.id] as? Double {
                    valueToSave = existingValue
                } else {
                    valueToSave = defaultValue
                    sleepLogResponses[question.id] = valueToSave
                }
                sleepLogUserInteracted.insert(question.id)
            } else {
                if let existingValue = assessmentResponses[question.id] as? Double {
                    valueToSave = existingValue
                } else {
                    valueToSave = defaultValue
                    assessmentResponses[question.id] = valueToSave
                }
                assessmentUserInteracted.insert(question.id)
            }

            var response = QuestionResponse(
                questionId: question.id,
                dayNumber: currentDay,
                answeredAt: Date(),
                answeredInSeconds: answerTime
            )
            response.numberValue = valueToSave
            questionnaireManager.saveResponse(response)
            return
        }

        // For time/date questions, user can accept the smart default by tapping Next
        if question.questionType == .time || question.questionType == .date {
            let valueToSave: Date
            if currentSection == .sleepLog {
                if let existingValue = sleepLogResponses[question.id] as? Date {
                    valueToSave = existingValue
                } else {
                    let prevBedtime = getPreviousBedtime(for: question.id)
                    valueToSave = TimeInput.smartDefault(for: question, previousBedtime: prevBedtime)
                    sleepLogResponses[question.id] = valueToSave
                }
                sleepLogUserInteracted.insert(question.id)
            } else {
                if let existingValue = assessmentResponses[question.id] as? Date {
                    valueToSave = existingValue
                } else {
                    let prevBedtime = getPreviousBedtime(for: question.id)
                    valueToSave = TimeInput.smartDefault(for: question, previousBedtime: prevBedtime)
                    assessmentResponses[question.id] = valueToSave
                }
                assessmentUserInteracted.insert(question.id)
            }

            var response = QuestionResponse(
                questionId: question.id,
                dayNumber: currentDay,
                answeredAt: Date(),
                answeredInSeconds: answerTime
            )
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            response.stringValue = formatter.string(from: valueToSave)
            questionnaireManager.saveResponse(response)
            return
        }

        // For minutesScroll questions, user can accept the smart default by tapping Next
        if question.questionType == .minutesScroll {
            let valueToSave: Int
            let defaultMinutes = question.defaultValue ?? 15  // Default to 15 minutes if not specified
            if currentSection == .sleepLog {
                if let existingValue = sleepLogResponses[question.id] as? Int {
                    valueToSave = existingValue
                } else {
                    valueToSave = defaultMinutes
                    sleepLogResponses[question.id] = valueToSave
                }
                sleepLogUserInteracted.insert(question.id)
            } else {
                if let existingValue = assessmentResponses[question.id] as? Int {
                    valueToSave = existingValue
                } else {
                    valueToSave = defaultMinutes
                    assessmentResponses[question.id] = valueToSave
                }
                assessmentUserInteracted.insert(question.id)
            }

            var response = QuestionResponse(
                questionId: question.id,
                dayNumber: currentDay,
                answeredAt: Date(),
                answeredInSeconds: answerTime
            )
            response.numberValue = Double(valueToSave)
            questionnaireManager.saveResponse(response)
            return
        }

        // For other question types, only save if response exists
        let responses = currentSection == .sleepLog ? sleepLogResponses : assessmentResponses
        guard let responseValue = responses[question.id] else { return }

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

        // Show saving indicator
        isSaving = true

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

                    // Record gamification progress
                    let triggeredGateways = questionnaireManager.gatewayStates
                        .filter { $0.triggered }
                        .map { $0.gatewayType.rawValue }

                    await GamificationManager.shared.recordDayComplete(
                        dayNumber: currentDay,
                        completedSleepLog: section == .sleepLog || result.sleepLogCompleted,
                        completedAssessment: section == .assessment || result.assessmentCompleted,
                        triggeredGateways: triggeredGateways.isEmpty ? nil : triggeredGateways
                    )

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

                    // Record gamification progress for full day
                    let triggeredGateways = questionnaireManager.gatewayStates
                        .filter { $0.triggered }
                        .map { $0.gatewayType.rawValue }

                    await GamificationManager.shared.recordDayComplete(
                        dayNumber: currentDay,
                        completedSleepLog: true,
                        completedAssessment: true,
                        triggeredGateways: triggeredGateways.isEmpty ? nil : triggeredGateways
                    )

                    await MainActor.run {
                        currentDay = min(currentDay + 1, 15)
                    }
                }

                await MainActor.run {
                    isSaving = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("[iOS] Error completing: \(error)")
                print("[iOS] Sleep log responses: \(sleepLogResponses.count), Assessment responses: \(assessmentResponses.count)")
                await MainActor.run {
                    isSaving = false
                    let sectionName = completedSectionAtFinish == .sleepLog ? "sleep log" : "assessment"
                    let errorDetail = (error as? ConvexError)?.localizedDescription ?? error.localizedDescription
                    saveError = "Failed to save your \(sectionName). \(errorDetail)"
                    showingSaveError = true
                    retryAction = { completeDay() }
                }
            }
        }
    }

    /// Sync all responses to Convex before completing a section
    /// This ensures server-side validation can verify responses exist
    /// IMPORTANT: Only sync responses where user actually interacted (not smart defaults)
    private func syncResponsesToConvex() async throws {
        print("[iOS] syncResponsesToConvex called")
        print("[iOS] sleepLogResponses: \(sleepLogResponses.count) items, userInteracted: \(sleepLogUserInteracted.count)")
        print("[iOS] assessmentResponses: \(assessmentResponses.count) items, userInteracted: \(assessmentUserInteracted.count)")

        var convexResponses: [[String: Any]] = []

        // Convert sleep log responses - only those user actually interacted with
        for (questionId, value) in sleepLogResponses {
            // CRITICAL: Only sync if user explicitly interacted with this question
            guard sleepLogUserInteracted.contains(questionId) else {
                print("[iOS] Skipping \(questionId) - user did not interact (smart default)")
                continue
            }

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
            } else {
                print("[iOS] Warning: Unknown response type for \(questionId): \(type(of: value))")
            }

            convexResponses.append(response)
        }

        // Convert assessment responses - only those user actually interacted with
        for (questionId, value) in assessmentResponses {
            // CRITICAL: Only sync if user explicitly interacted with this question
            guard assessmentUserInteracted.contains(questionId) else {
                print("[iOS] Skipping \(questionId) - user did not interact (smart default)")
                continue
            }

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
        print("[iOS] Total user-interacted responses to sync: \(convexResponses.count)")
        if !convexResponses.isEmpty {
            print("[iOS] Calling ConvexService.saveResponses for day \(currentDay)...")
            let result = try await ConvexService.shared.saveResponses(dayNumber: currentDay, responses: convexResponses)
            print("[iOS] Synced \(result.savedCount) responses to Convex")
        } else {
            print("[iOS] No user-interacted responses to sync!")
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

    // Circadian-aware text colors
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var primaryTextColor: Color {
        if isEvening {
            return Color(red: 0.996, green: 0.953, blue: 0.780)  // Bright cream #FEF3C7
        } else {
            return Color.primary
        }
    }

    private var secondaryTextColor: Color {
        if isEvening {
            return Color(red: 0.988, green: 0.827, blue: 0.302)  // Golden yellow #FCD34D
        } else {
            return Color.secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(theme.health)
                Text("Last Night's Sleep (Apple Health)")
                    .font(.headline)
                    .foregroundColor(primaryTextColor)
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
                            .foregroundColor(primaryTextColor)
                    }
                    Text("Total Sleep")
                        .font(.caption2)
                        .foregroundColor(secondaryTextColor)
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
                            .foregroundColor(primaryTextColor)
                    }
                    Text("Efficiency")
                        .font(.caption2)
                        .foregroundColor(secondaryTextColor)
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
                            .foregroundColor(primaryTextColor)
                    }
                    Text("Awakenings")
                        .font(.caption2)
                        .foregroundColor(secondaryTextColor)
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
                    .foregroundColor(secondaryTextColor)
                Spacer()
                if let wake = summary.formattedWakeTime {
                    Label(wake, systemImage: "sun.max.fill")
                        .font(.caption)
                }
            }
            .foregroundColor(secondaryTextColor)

            Text("Now tell us your subjective experience - how YOU perceived your sleep")
                .font(.caption)
                .foregroundColor(QuestionnaireSection.sleepLog.descriptionTextColor)
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
