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
    @ObservedObject private var guideManager = FirstTimeGuideManager.shared

    // Which section to start with (and optionally limit to)
    var startSection: QuestionnaireSection = .sleepLog
    var sectionOnly: Bool = false  // If true, only show this section (don't transition to next)
    var isCatchUp: Bool = false  // If true, this is a catch-up for a missed day (not current day)

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

    // Loading State - prevents showing EmptyAssessmentView before questions are loaded
    @State private var isLoadingQuestions: Bool = true

    // Expansion Modules (for dynamic splash screens)
    @State private var currentDayExpansionModules: [String] = []  // Module IDs for expansion splash

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

    // Day Splash Screen (hero-framed intro for ALL 14 days)
    @State private var showingDaySplash: Bool = false
    @State private var daySplashInfo: DaySplashInfo? = nil

    // Legacy Expansion Pack Splash Screen (detailed questionnaire info)
    @State private var showingExpansionSplash: Bool = false
    @State private var expansionSplashInfo: [QuestionnaireValidationInfo] = []

    // Smart Pre-fill for Sleep Log (after Day 1)
    @State private var showingPreFillConfirmation: Bool = false
    @State private var preFillSuggestions: [String: Any] = [:]

    // Gateway notification state - track which gateways have been acknowledged to only show NEW triggers
    @State private var acknowledgedGateways: Set<GatewayType> = []
    @State private var newlyTriggeredGateway: GatewayType? = nil

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

    // Hardcoded background color to avoid white flash during navigation
    private var loadingBackgroundColor: Color {
        if TimePeriod.current == .evening || TimePeriod.current == .night {
            return Color(red: 0.08, green: 0.06, blue: 0.04) // Dark evening brown
        } else {
            return Color(red: 0.98, green: 0.96, blue: 0.93) // Warm cream for daytime
        }
    }

    var body: some View {
        ZStack {
            // Background layer - always present to prevent white flash
            loadingBackgroundColor
                .ignoresSafeArea()

            // Content layer
            if showingDaySplash, let splashInfo = daySplashInfo {
                // Hero-framed day splash for ALL 14 days
                DaySplashView(
                    dayInfo: splashInfo,
                    triggeredGateways: questionnaireManager.gatewayStates.filter { $0.triggered }.map { $0.gatewayType },
                    onContinue: {
                        withAnimation {
                            showingDaySplash = false
                        }
                    }
                )
            } else if showingExpansionSplash && !expansionSplashInfo.isEmpty {
                // Legacy: Detailed expansion pack splash with questionnaire rationale (for detailed clinical info)
                if expansionSplashInfo.count == 1, let info = expansionSplashInfo.first {
                    ExpansionQuestionnaireSplashView(
                        info: info,
                        triggeredGateways: questionnaireManager.gatewayStates.filter { $0.triggered }.map { $0.gatewayType },
                        onContinue: {
                            withAnimation {
                                showingExpansionSplash = false
                            }
                        }
                    )
                } else {
                    ExpansionDaySplashView(
                        questionnaires: expansionSplashInfo,
                        dayNumber: currentDay,
                        triggeredGateways: questionnaireManager.gatewayStates.filter { $0.triggered }.map { $0.gatewayType },
                        onContinue: {
                            withAnimation {
                                showingExpansionSplash = false
                            }
                        }
                    )
                }
            } else if showingTransition {
                SectionTransitionView(
                    fromSection: .sleepLog,
                    toSection: .assessment,
                    onContinue: {
                        withAnimation {
                            showingTransition = false
                            currentSection = .assessment
                        }
                        // Show first-time Assessment guide after transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            guideManager.showGuideIfNeeded(for: .assessment)
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
                    // Only show "Proceed to Assessment" if there ARE assessment questions
                    onProceedToNextSection: sectionOnly && completedSectionAtFinish == .sleepLog && !assessmentQuestions.isEmpty ? {
                        proceedToAssessment()
                    } : nil,
                    // Pass actual completion status from backend to correctly show checkmarks
                    completedSleepLog: questionnaireManager.journeyProgress?.sleepLogCompleted ?? false,
                    completedAssessment: questionnaireManager.journeyProgress?.assessmentCompleted ?? false
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
            } else if isLoadingQuestions {
                // Loading state - background ZStack handles the color
                EmptyView()
            } else if currentQuestions.isEmpty {
                // Empty state: Assessment section was opened but no questions exist
                // This can happen on expansion days when required gateways weren't triggered
                EmptyAssessmentView(
                    dayNumber: currentDay,
                    onDismiss: { presentationMode.wrappedValue.dismiss() }
                )
            } else {
                mainQuestionnaireView
            }
        }
        .disableSwipeBack()  // Prevent accidental back navigation when using sliders
        .navigationTitle(currentSection == .sleepLog ? "Sleep Log" : "Day \(currentDay) Assessment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(navBarBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isEvening ? .dark : .light, for: .navigationBar)
        .onAppear(perform: handleViewAppear)
        .onDisappear {
            // When leaving the questionnaire (back button or dismissal),
            // save any in-progress responses BEFORE posting refresh notification
            // This ensures partial progress is persisted
            print("[iOS Questionnaire] View disappearing - saving in-progress responses")
            saveInProgressResponses()
            NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)
        }
        .onChange(of: questionnaireManager.gatewayStates) { _, newStates in
            handleGatewayStateChange(newStates)
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
        // Gamification Overlays (PARKED - enable via Debug Panel > Experimental Features)
        .overlay {
            // Badge Unlock Animation
            if themeManager.gamificationEnabled,
               gamificationManager.showBadgeUnlockedAnimation,
               let badge = gamificationManager.unlockedBadge {
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
            if themeManager.gamificationEnabled,
               gamificationManager.showLevelUpAnimation,
               let levelInfo = gamificationManager.newLevelInfo {
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
        // First-Time Feature Guides
        .fullScreenCover(isPresented: $guideManager.isShowingGuide) {
            if let guide = guideManager.currentGuide {
                FirstTimeGuideView(guide: guide) {
                    guideManager.dismissGuide()
                }
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
                        // NOTE: HealthKit sleep card removed - sleep log is about SUBJECTIVE sleep experience,
                        // not objective Apple Health data which can be unreliable/incomplete for new users

                        // Current Question
                        if !currentQuestions.isEmpty && currentIndex < currentQuestions.count {
                            questionView(for: currentQuestions[currentIndex])
                                .padding(.horizontal)
                        }

                        // Gateway alert (only show NEWLY triggered gateway in assessment section)
                        gatewayAlertBannerView
                    }
                    .padding(.vertical)
                }

                // Navigation Buttons
                navigationButtons
            }

            // Debug Auto-Complete FAB (only in debug mode)
            if themeManager.debugMode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        DebugAutoCompleteButton(onTap: debugAutoCompleteAndSubmit)
                            .padding(.trailing, 20)
                            .padding(.bottom, 100)
                    }
                }
            }
        }
    }

    // MARK: - Question View

    @ViewBuilder
    private func questionView(for question: Question) -> some View {
        SectionQuestionCard(section: currentSection, question: question) {
            switch question.questionType {
            case .scale:
                // UNIFIED 1-10 SCALE: All scale questions use the same slider
                // User sees 1-10, internally mapped to clinical scale (0-3, 0-4, 1-5, etc.)
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
                    previousBedtime: getPreviousBedtime(for: question.id),
                    onValueChange: { newValue in
                        // CRITICAL: Always save the current picker value directly to responses
                        // This ensures dependent questions get the correct previous value
                        // Note: This saves without marking user-interacted (that happens in binding setter)
                        if currentSection == .sleepLog {
                            sleepLogResponses[question.id] = newValue
                        } else {
                            assessmentResponses[question.id] = newValue
                        }
                    }
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

            case .hoursMinutesScroll:
                HoursMinutesScrollPicker(
                    question: question,
                    totalMinutes: intBinding(for: question.id, default: (question.defaultValue ?? 7) * 60)
                )

            case .info:
                InfoCard(question: question, theme: theme)

            case .repeatingGroup:
                Text("Repeating group input (coming soon)")
                    .foregroundColor(.secondary)

            case .napDetails:
                NapDetailsInput(
                    question: question,
                    napEntries: napEntriesBinding(for: question.id),
                    napCount: getNapCount(),
                    theme: theme
                )

            case .medicationSelect:
                MedicationSelectInput(
                    question: question,
                    medications: medicationsBinding(for: question.id),
                    theme: theme
                )

            case .caffeineSelect:
                CaffeineSelectInput(
                    question: question,
                    entries: caffeineEntriesBinding(for: question.id),
                    theme: theme
                )

            case .prescriptionMedSelect:
                PrescriptionMedSelectInput(
                    question: question,
                    medications: medicationsWithTimingBinding(for: question.id),
                    theme: theme
                )

            case .supplementSelect:
                SupplementSelectInput(
                    question: question,
                    supplements: medicationsWithTimingBinding(for: question.id),
                    theme: theme
                )

            case .surgeryDetails:
                SurgeryDetailsInput(
                    question: question,
                    entries: surgeryEntriesBinding(for: question.id),
                    theme: theme
                )
            }
        }
    }

    // MARK: - Scale Type Detection (DEPRECATED)
    // NOTE: shouldUseDiscreteScale is no longer used - all scales now use unified 1-10 slider
    // The ScaleMapper handles conversion between display (1-10) and clinical values

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
        return Binding(
            get: {
                // Check for existing response first
                if currentSection == .sleepLog {
                    if let existingValue = sleepLogResponses[questionId] as? Date {
                        return existingValue
                    }
                } else {
                    if let existingValue = assessmentResponses[questionId] as? Date {
                        return existingValue
                    }
                }

                // Calculate smart default dynamically (not captured at binding creation time)
                // This ensures dependent questions get the latest previous answers
                let currentPreviousBedtime = getPreviousBedtime(for: questionId)
                if let q = question {
                    return TimeInput.smartDefault(for: q, previousBedtime: currentPreviousBedtime)
                }
                return Date()
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

    /// Binding for nap entries (stored as JSON array)
    private func napEntriesBinding(for questionId: String) -> Binding<[NapEntry]> {
        Binding(
            get: {
                // Try to get existing nap entries from responses
                if currentSection == .sleepLog {
                    if let entries = sleepLogResponses[questionId] as? [NapEntry] {
                        return entries
                    }
                    // Try to decode from JSON string
                    if let jsonString = sleepLogResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let entries = try? JSONDecoder().decode([NapEntry].self, from: data) {
                        return entries
                    }
                } else {
                    if let entries = assessmentResponses[questionId] as? [NapEntry] {
                        return entries
                    }
                    if let jsonString = assessmentResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let entries = try? JSONDecoder().decode([NapEntry].self, from: data) {
                        return entries
                    }
                }
                // Return empty array - will be populated by NapDetailsInput on appear
                return []
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

    /// Binding for medication selections (stored as JSON array with dose info)
    private func medicationsBinding(for questionId: String) -> Binding<[MedicationSelection]> {
        Binding(
            get: {
                // Try to get existing medication selections from responses
                if currentSection == .sleepLog {
                    if let selections = sleepLogResponses[questionId] as? [MedicationSelection] {
                        return selections
                    }
                    // Try to decode from JSON string
                    if let jsonString = sleepLogResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let selections = try? JSONDecoder().decode([MedicationSelection].self, from: data) {
                        return selections
                    }
                    // Legacy support: convert old [String] format to [MedicationSelection]
                    if let oldCategories = sleepLogResponses[questionId] as? [String] {
                        return oldCategories.map { MedicationSelection(categoryId: $0, dose: nil, medicationName: nil) }
                    }
                } else {
                    if let selections = assessmentResponses[questionId] as? [MedicationSelection] {
                        return selections
                    }
                    if let jsonString = assessmentResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let selections = try? JSONDecoder().decode([MedicationSelection].self, from: data) {
                        return selections
                    }
                    // Legacy support: convert old [String] format to [MedicationSelection]
                    if let oldCategories = assessmentResponses[questionId] as? [String] {
                        return oldCategories.map { MedicationSelection(categoryId: $0, dose: nil, medicationName: nil) }
                    }
                }
                return []
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

    /// Binding for caffeine entries (stored as JSON array with type and count)
    private func caffeineEntriesBinding(for questionId: String) -> Binding<[CaffeineEntry]> {
        Binding(
            get: {
                // Try to get existing caffeine entries from responses
                if currentSection == .sleepLog {
                    if let entries = sleepLogResponses[questionId] as? [CaffeineEntry] {
                        return entries
                    }
                    // Try to decode from JSON string
                    if let jsonString = sleepLogResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let entries = try? JSONDecoder().decode([CaffeineEntry].self, from: data) {
                        return entries
                    }
                } else {
                    if let entries = assessmentResponses[questionId] as? [CaffeineEntry] {
                        return entries
                    }
                    if let jsonString = assessmentResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let entries = try? JSONDecoder().decode([CaffeineEntry].self, from: data) {
                        return entries
                    }
                }
                return []
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

    /// Binding for medications with timing (stored as JSON array with dose + timing info)
    /// Used for prescriptionMedSelect and supplementSelect question types
    private func medicationsWithTimingBinding(for questionId: String) -> Binding<[MedicationWithTiming]> {
        Binding(
            get: {
                // Try to get existing medication selections from responses
                if currentSection == .sleepLog {
                    if let selections = sleepLogResponses[questionId] as? [MedicationWithTiming] {
                        return selections
                    }
                    // Try to decode from JSON string
                    if let jsonString = sleepLogResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let selections = try? JSONDecoder().decode([MedicationWithTiming].self, from: data) {
                        return selections
                    }
                } else {
                    if let selections = assessmentResponses[questionId] as? [MedicationWithTiming] {
                        return selections
                    }
                    if let jsonString = assessmentResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let selections = try? JSONDecoder().decode([MedicationWithTiming].self, from: data) {
                        return selections
                    }
                }
                return []
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

    /// Binding for surgery entries (stored as JSON array with procedure name + date)
    private func surgeryEntriesBinding(for questionId: String) -> Binding<[SurgeryEntry]> {
        Binding(
            get: {
                // Try to get existing surgery entries from responses
                if currentSection == .sleepLog {
                    if let entries = sleepLogResponses[questionId] as? [SurgeryEntry] {
                        return entries
                    }
                    // Try to decode from JSON string
                    if let jsonString = sleepLogResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let entries = try? JSONDecoder().decode([SurgeryEntry].self, from: data) {
                        return entries
                    }
                } else {
                    if let entries = assessmentResponses[questionId] as? [SurgeryEntry] {
                        return entries
                    }
                    if let jsonString = assessmentResponses[questionId] as? String,
                       let data = jsonString.data(using: .utf8),
                       let entries = try? JSONDecoder().decode([SurgeryEntry].self, from: data) {
                        return entries
                    }
                }
                return []
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

    /// Gets the nap count from SD_NAPS_COUNT or CSD_NAP_COUNT response
    private func getNapCount() -> Int {
        // Question IDs to check (SD_ is current format, CSD_ is legacy)
        let napCountIds = ["SD_NAPS_COUNT", "CSD_NAP_COUNT"]

        let responses = currentSection == .sleepLog ? sleepLogResponses : assessmentResponses

        for id in napCountIds {
            // Check for Double first (common from number input)
            if let count = responses[id] as? Double {
                return max(1, Int(count))
            }
            // Check for Int
            if let count = responses[id] as? Int {
                return max(1, count)
            }
        }
        // Default to 1 nap if not specified
        return 1
    }

    // MARK: - Smart Default Helpers

    /// Returns the previously answered bedtime to help set smart defaults for subsequent time questions
    /// If the previous answer doesn't exist, calculates what it would have been based on the chain of defaults
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

            // Stanford Sleep Diary question dependencies (SD_ prefix)
            case "SD_LIGHTS_OUT":
                // Return bedtime so smartDefault can add 10 min for lights out
                if let bedtime = sleepLogResponses["SD_GOT_INTO_BED"] as? Date {
                    return bedtime
                }
                // Fallback: Use smart default for bedtime (10 PM)
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.hour = 22
                components.minute = 0
                return calendar.date(from: components)
            // Note: SL_ASLEEP_TIME/SD_SLEEP_ONSET removed - sleep onset derived from lights_out + latency
            case "SD_FINAL_WAKE", "SL_WAKE_TIME":
                // Wake time depends on lights out (typically 8 hours later)
                if let lightsOut = sleepLogResponses["SD_LIGHTS_OUT"] as? Date {
                    return lightsOut
                }
                if let bedtime = sleepLogResponses["SD_GOT_INTO_BED"] as? Date {
                    // bedtime + 10min (lights out delay)
                    let calendar = Calendar.current
                    return calendar.date(byAdding: .minute, value: 10, to: bedtime)
                }
                // Fallback: 10:15 PM (typical lights out)
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.hour = 22
                components.minute = 15
                return calendar.date(from: components)
            case "SD_OUT_OF_BED":
                // Out of bed depends on wake time - use SD_FINAL_WAKE (not SL_WAKE_TIME)
                // Return the wake time so smartTimeDefault can add 15 min
                if let wakeTime = sleepLogResponses["SD_FINAL_WAKE"] as? Date {
                    return wakeTime
                }
                // Fallback: try SL_WAKE_TIME for backward compatibility
                if let wakeTime = sleepLogResponses["SL_WAKE_TIME"] as? Date {
                    return wakeTime
                }
                // Fall back to calculating wake time from earlier answers
                let calendar = Calendar.current
                if let lightsOut = sleepLogResponses["SD_LIGHTS_OUT"] as? Date {
                    // lights out + 15min (fall asleep) + 8 hours = wake time
                    return calendar.date(byAdding: .minute, value: 8 * 60 + 15, to: lightsOut)
                }
                if let bedtime = sleepLogResponses["SD_GOT_INTO_BED"] as? Date {
                    // bedtime + 10min (lights out) + 15min (fall asleep) + 8 hours = wake time
                    return calendar.date(byAdding: .minute, value: 8 * 60 + 25, to: bedtime)
                }
                // Ultimate fallback: 7:00 AM (typical wake time)
                var components = DateComponents()
                components.hour = 7
                components.minute = 0
                return calendar.date(from: components)
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

    @ViewBuilder
    private var gatewayAlertBannerView: some View {
        if currentSection == .assessment, let newGateway = newlyTriggeredGateway {
            GatewayAlertBanner(gatewayType: newGateway, isTriggered: true, theme: theme)
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear { scheduleGatewayDismissal(newGateway) }
                .onTapGesture { dismissGateway(newGateway) }
        }
    }

    private func scheduleGatewayDismissal(_ gateway: GatewayType) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation {
                acknowledgedGateways.insert(gateway)
                newlyTriggeredGateway = nil
            }
        }
    }

    private func dismissGateway(_ gateway: GatewayType) {
        withAnimation {
            acknowledgedGateways.insert(gateway)
            newlyTriggeredGateway = nil
        }
    }

    private func handleViewAppear() {
        // Ensure loading state is true when view appears (handles view reuse)
        isLoadingQuestions = true
        loadQuestions()
        // Initialize acknowledged gateways with any that are already triggered
        // This prevents showing notifications for gateways triggered in previous sessions
        for gateway in questionnaireManager.gatewayStates where gateway.triggered {
            acknowledgedGateways.insert(gateway.gatewayType)
        }

        // Show first-time guide for the starting section (with slight delay for smooth UX)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if startSection == .sleepLog {
                guideManager.showGuideIfNeeded(for: .sleepLog)
            } else if startSection == .assessment {
                guideManager.showGuideIfNeeded(for: .assessment)
            }
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
            // Number inputs with +/- buttons show a visible default that user can accept
            // Allow proceeding without interaction - if they don't change it, they're accepting it
            // The value will be saved when they tap Next (handled in saveCurrentResponse)
            return true
        case .scale, .time, .date, .minutesScroll, .hoursMinutesScroll:
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
        case .napDetails:
            // Nap details shows pre-initialized entries, allow proceeding immediately
            // User can accept the defaults or modify them
            return true
        case .medicationSelect:
            // Medication select requires at least one selection
            guard let response = responses[question.id] else { return false }
            // Check for new MedicationSelection format
            if let selections = response as? [MedicationSelection] {
                return !selections.isEmpty
            }
            // Legacy support for old [String] format
            return !(response as? [String] ?? []).isEmpty
        case .caffeineSelect:
            // Caffeine select requires at least one entry
            guard let response = responses[question.id] else { return false }
            if let entries = response as? [CaffeineEntry] {
                return !entries.isEmpty
            }
            return false
        case .prescriptionMedSelect, .supplementSelect:
            // Prescription/supplement select requires at least one selection
            guard let response = responses[question.id] else { return false }
            if let selections = response as? [MedicationWithTiming] {
                return !selections.isEmpty
            }
            return false
        case .surgeryDetails:
            // Surgery details requires at least one entry with a procedure name
            guard let response = responses[question.id] else { return false }
            if let entries = response as? [SurgeryEntry] {
                return entries.contains { !$0.procedureName.isEmpty }
            }
            return false
        default:
            // For other types, check if user interacted OR if response exists
            return userInteracted.contains(question.id) || responses[question.id] != nil
        }
    }

    // MARK: - Actions

    // MARK: Debug Auto-Complete

    /// Debug mode: Auto-complete all questions in current section and submit
    /// Generates gateway-triggering answers for assessment questions
    private func debugAutoCompleteAndSubmit() {
        guard themeManager.debugMode else { return }

        print("[Debug] Auto-completing \(currentSection.rawValue) section for Day \(currentDay)")

        // Create generator that forces all gateways to trigger
        let generator = MockDataGenerator(forceAllGateways: true)
        let questions = currentSection == .sleepLog ? sleepLogQuestions : assessmentQuestions
        var filledCount = 0

        for question in questions {
            let answer = generator.generateAnswer(for: question, dayNumber: currentDay)

            // Check if we have any value to set
            let hasValue = answer.stringValue != nil || answer.numberValue != nil ||
                           answer.arrayValue != nil || answer.objectValue != nil

            guard hasValue else {
                // Skip questions where generator returns nil (e.g., name fields)
                print("[Debug] Skipping \(question.id) - no generated value")
                continue
            }

            // Fill response dictionary based on current section
            if currentSection == .sleepLog {
                if let str = answer.stringValue {
                    sleepLogResponses[question.id] = str
                } else if let num = answer.numberValue {
                    sleepLogResponses[question.id] = num
                } else if let arr = answer.arrayValue {
                    sleepLogResponses[question.id] = arr
                } else if let obj = answer.objectValue {
                    sleepLogResponses[question.id] = obj
                }
                sleepLogUserInteracted.insert(question.id)
            } else {
                if let str = answer.stringValue {
                    assessmentResponses[question.id] = str
                } else if let num = answer.numberValue {
                    assessmentResponses[question.id] = num
                } else if let arr = answer.arrayValue {
                    assessmentResponses[question.id] = arr
                } else if let obj = answer.objectValue {
                    assessmentResponses[question.id] = obj
                }
                assessmentUserInteracted.insert(question.id)
            }
            filledCount += 1
        }

        print("[Debug] Filled \(filledCount) of \(questions.count) questions, saving and completing section...")

        // Capture values needed for async work before dismissing
        let sectionToComplete = currentSection
        let responsesToSave = currentSection == .sleepLog ? sleepLogResponses : assessmentResponses
        let questionsForSave = questions

        // Save locally to QuestionnaireManager (synchronous)
        for (questionId, value) in responsesToSave {
            saveResponseFromDictionary(questionId: questionId, value: value, questions: questionsForSave)
        }

        // Complete section in background (async) - will continue after view dismisses
        completeSectionInBackground(section: sectionToComplete)

        // Dismiss immediately - background task is fire-and-forget
        presentationMode.wrappedValue.dismiss()
    }

    private func loadQuestions() {
        // Update HealthKit demographics cache BEFORE loading questions
        // This ensures shouldSkipDemographicQuestion() has access to HealthKit data
        let demographics = healthKitManager.demographics
        questionnaireManager.updateHealthKitDemographics(
            dateOfBirth: demographics.dateOfBirth,
            biologicalSex: demographics.biologicalSex,
            heightCm: demographics.heightCm,
            weightKg: demographics.weightKg
        )

        // Use async task to fetch questions from Convex (THE SINGLE SOURCE OF TRUTH)
        Task {
            do {
                // Inject demographic responses from profile BEFORE loading questions (any day)
                // This ensures scoring calculations and conditional logic (e.g., gender-specific questions)
                // have the data they need. The backend will only update if profile data exists.
                do {
                    try await ConvexService.shared.injectProfileResponses(dayNumber: currentDay)
                    print("[iOS] Injected demographic responses from profile for Day \(currentDay)")
                } catch {
                    print("[iOS] Warning: Failed to inject demographic responses: \(error.localizedDescription)")
                    // Continue anyway - conditional logic will exclude questions if demographics missing
                }

                print("[iOS] Fetching questions from Convex for Day \(currentDay)...")
                let questionsResponse = try await ConvexService.shared.getQuestionsForUserDay(dayNumber: currentDay, section: "all")

                // Convert Convex questions to iOS Question type
                let convertedSleepLog = questionsResponse.sleepLog.map { convertConvexQuestion($0, isSleepLog: true) }

                // Filter out demographic questions (D2, D4, D5, D6) if profile has the data
                // The data is auto-injected as responses, so scoring still works
                print("[iOS] Filtering assessment questions. Original count: \(questionsResponse.assessment.count)")
                print("[iOS] Question IDs before filter: \(questionsResponse.assessment.map { $0.id })")
                let filteredAssessment = questionsResponse.assessment
                    .filter { !shouldSkipDemographicQuestion($0.id) }
                    .map { convertConvexQuestion($0, isSleepLog: false) }
                print("[iOS] Questions after filter: \(filteredAssessment.count)")
                let convertedAssessment = filteredAssessment

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

                    // Smart pre-fill for Sleep Log (Day 2+ only)
                    // Load previous day's responses to reduce friction
                    if currentDay > 1 && startSection == .sleepLog && !sleepLogQuestions.isEmpty {
                        let suggestions = loadPreFillSuggestions()
                        if !suggestions.isEmpty {
                            preFillSuggestions = suggestions
                            // Apply pre-fill silently - user confirms via normal interaction
                            applyPreFillSuggestions()
                        }
                    }

                    // Store expansion modules for this day (used by splash screens and proceedToAssessment)
                    let expansionModules = questionsResponse.metadata.modules?.filter { $0.hasPrefix("expansion_") } ?? []
                    currentDayExpansionModules = expansionModules
                    print("[iOS] Day \(currentDay) expansion modules: \(expansionModules.isEmpty ? "none" : expansionModules.joined(separator: ", "))")

                    // Show appropriate splash for assessment section
                    if startSection == .assessment && !assessmentQuestions.isEmpty {
                        if !expansionModules.isEmpty && currentDay >= 6 {
                            // Show detailed expansion splash with questionnaire info (DASS-21, PHQ-9, etc.)
                            print("[iOS] Day \(currentDay) has \(expansionModules.count) expansion modules - showing expansion splash")
                            checkAndShowExpansionSplash(modules: expansionModules)
                        } else {
                            // Show hero-framed day splash for core days (1-5) or days without expansion
                            // Calculate assessment-only time (~15 seconds per question)
                            let assessmentMinutes = max(1, (assessmentQuestions.count + 3) / 4)
                            checkAndShowDaySplash(
                                questionCount: assessmentQuestions.count,
                                estimatedMinutes: assessmentMinutes
                            )
                        }
                    }

                    // Load saved progress from Convex (cross-device sync)
                    print("[iOS] About to call loadSavedProgress()...")
                    loadSavedProgress()

                    // Mark loading complete - now EmptyAssessmentView can show if truly empty
                    isLoadingQuestions = false
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

                    // Mark loading complete even on fallback
                    isLoadingQuestions = false
                }
            }
        }
    }

    /// Convert a ConvexQuestion to the iOS Question type
    private func convertConvexQuestion(_ cq: ConvexQuestion, isSleepLog: Bool) -> Question {
        // Map Convex question type to iOS QuestionType
        // NOTE: Convex watch.ts mapAnswerFormatToType() must match these mappings!
        let questionType: QuestionType
        switch cq.type {
        // Time inputs
        case "time": questionType = .time

        // Scale/slider inputs
        case "scale": questionType = .scale

        // Number inputs
        case "number": questionType = .number
        case "numberScroll": questionType = .numberScroll

        // Scroll pickers (specialized)
        case "minutesScroll": questionType = .minutesScroll
        case "hoursMinutesScroll": questionType = .hoursMinutesScroll

        // Yes/No
        case "yesNo": questionType = .yesNo

        // Selection inputs
        case "singleSelect": questionType = .singleSelect
        case "multiSelect": questionType = .multiSelect

        // Text inputs
        case "text": questionType = .text

        // Date inputs
        case "date": questionType = .date

        // Specialized inputs
        case "info": questionType = .info
        case "napDetails": questionType = .napDetails
        case "medicationSelect": questionType = .medicationSelect
        case "caffeineSelect": questionType = .caffeineSelect

        // New intake follow-up question types
        case "prescriptionMedSelect", "prescription_med_select": questionType = .prescriptionMedSelect
        case "supplementSelect", "supplement_select": questionType = .supplementSelect
        case "surgeryDetails", "surgery_details": questionType = .surgeryDetails

        default:
            print("[iOS] WARNING: Unknown question type '\(cq.type)' for question \(cq.id), defaulting to text")
            questionType = .text
        }

        // Extract scale config from formatConfig if available
        // Convex uses: scaleMin, scaleMax, labels (array)
        // Legacy uses: min, max, minLabel, maxLabel
        var scaleMin: Int? = nil
        var scaleMax: Int? = nil
        var scaleMinLabel: String? = nil
        var scaleMaxLabel: String? = nil
        var minValue: Int? = nil
        var maxValue: Int? = nil

        // Unit-related fields for metric/imperial switching
        var unit: String? = nil
        var unitImperial: String? = nil
        var step: Double? = nil
        var defaultValue: Int? = nil
        var minImperial: Int? = nil
        var maxImperial: Int? = nil
        var defaultImperial: Int? = nil

        if let config = cq.formatConfig {
            // Try Convex format first (scaleMin/scaleMax)
            if let min = config["scaleMin"]?.value as? Int { scaleMin = min; minValue = min }
            if let max = config["scaleMax"]?.value as? Int { scaleMax = max; maxValue = max }
            // Fallback to legacy format (min/max)
            if scaleMin == nil, let min = config["min"]?.value as? Int { scaleMin = min; minValue = min }
            if scaleMax == nil, let max = config["max"]?.value as? Int { scaleMax = max; maxValue = max }

            // Extract labels from Convex labels array OR legacy minLabel/maxLabel
            if let labels = config["labels"]?.value as? [String], !labels.isEmpty {
                scaleMinLabel = labels.first
                scaleMaxLabel = labels.last
            } else {
                if let minLabel = config["minLabel"]?.value as? String { scaleMinLabel = minLabel }
                if let maxLabel = config["maxLabel"]?.value as? String { scaleMaxLabel = maxLabel }
            }

            // Extract unit-related fields for metric/imperial switching
            if let u = config["unit"]?.value as? String { unit = u }
            if let uImp = config["unitImperial"]?.value as? String { unitImperial = uImp }
            if let s = config["step"]?.value as? Double { step = s }
            else if let s = config["step"]?.value as? Int { step = Double(s) }
            if let dv = config["defaultValue"]?.value as? Int { defaultValue = dv }
            if let minImp = config["minImperial"]?.value as? Int { minImperial = minImp }
            if let maxImp = config["maxImperial"]?.value as? Int { maxImperial = maxImp }
            if let defImp = config["defaultImperial"]?.value as? Int { defaultImperial = defImp }
        }

        // Convert conditional logic if present (handles compound all/any conditions)
        var conditionalLogic: ConditionalLogic? = nil
        if let convexLogic = cq.conditionalLogic {
            conditionalLogic = convertConditionalLogic(convexLogic)
            if let all = convexLogic.all {
                print("[iOS] Question \(cq.id) has COMPOUND conditionalLogic: all=\(all.count) conditions")
            } else if let any = convexLogic.any {
                print("[iOS] Question \(cq.id) has COMPOUND conditionalLogic: any=\(any.count) conditions")
            } else {
                print("[iOS] Question \(cq.id) has conditionalLogic: questionId=\(convexLogic.questionId ?? "nil"), equals=\(convexLogic.equals ?? "nil")")
            }
        } else {
            print("[iOS] Question \(cq.id) has NO conditionalLogic")
        }

        // Fallback options for known multiSelect questions if Convex options are missing
        var resolvedOptions = cq.options
        if questionType == .multiSelect && (resolvedOptions == nil || resolvedOptions?.isEmpty == true) {
            // Hardcoded fallback for Q33D - sleep aids
            if cq.id == "33D" {
                print("[iOS] WARNING: Q33D has no options from Convex, using fallback options")
                resolvedOptions = ["None", "Melatonin", "Prescription sleep medication", "Over-the-counter sleep aid", "Antihistamines (Benadryl, etc.)", "Herbal supplements (valerian, chamomile, etc.)", "CBD or cannabis", "Alcohol", "Other"]
            }
        }

        return Question(
            id: cq.id,
            text: cq.text,
            pillar: isSleepLog ? .sleepLog : .sleepQuality,
            tier: .core,
            questionType: questionType,
            estimatedMinutes: 0.5,
            required: cq.required,
            options: resolvedOptions,
            scaleMin: scaleMin,
            scaleMax: scaleMax,
            scaleMinLabel: scaleMinLabel,
            scaleMaxLabel: scaleMaxLabel,
            minValue: minValue,
            maxValue: maxValue,
            step: step,
            unit: unit,
            defaultValue: defaultValue,
            unitImperial: unitImperial,
            minImperial: minImperial,
            maxImperial: maxImperial,
            defaultImperial: defaultImperial,
            helpText: cq.helpText,
            helpTextImperial: cq.helpTextImperial,
            isGateway: false,
            conditionalLogic: conditionalLogic,
            group: isSleepLog ? "sleep_log" : nil
        )
    }

    /// Recursively convert ConvexConditionalLogic to iOS ConditionalLogic
    /// Handles simple conditions (questionId + equals) and compound conditions (all/any arrays)
    private func convertConditionalLogic(_ convexLogic: ConvexConditionalLogic) -> ConditionalLogic {
        var logic = ConditionalLogic()

        // Copy simple condition fields
        logic.questionId = convexLogic.questionId
        logic.equals = convexLogic.equals
        logic.greaterThan = convexLogic.greaterThan
        logic.lessThan = convexLogic.lessThan
        logic.greaterThanOrEqual = convexLogic.greaterThanOrEqual
        logic.lessThanOrEqual = convexLogic.lessThanOrEqual
        logic.contains = convexLogic.contains
        logic.inValues = convexLogic.inValues

        // Copy age-based conditions
        logic.ageUnder = convexLogic.ageUnder
        logic.ageOver = convexLogic.ageOver

        // Recursively convert compound conditions
        if let all = convexLogic.all {
            logic.all = all.map { convertConditionalLogic($0) }
        }
        if let any = convexLogic.any {
            logic.any = any.map { convertConditionalLogic($0) }
        }

        return logic
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
                    completeSectionInBackground(section: .sleepLog)
                    withAnimation {
                        completedSectionAtFinish = .sleepLog  // Capture which section we completed
                        showingCompletion = true
                    }
                } else {
                    // Show transition to assessment - also complete sleep log section immediately
                    completeSectionInBackground(section: .sleepLog)
                    withAnimation {
                        showingTransition = true
                    }
                }
            } else {
                // Check if reward should show BEFORE advancing (respects Sleep Science Cards setting)
                if themeManager.showSleepScienceCards && rewardManager.shouldShowReward {
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
                completeSectionInBackground(section: .assessment)
                withAnimation {
                    completedSectionAtFinish = .assessment  // Capture which section we completed
                    showingCompletion = true
                }
            } else {
                // Check if reward should show BEFORE advancing (respects Sleep Science Cards setting)
                if themeManager.showSleepScienceCards && rewardManager.shouldShowReward {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showingRewardCard = true
                    }
                } else {
                    advanceToNextQuestion()
                }
            }
        }
    }

    /// Check if a demographic question should be skipped because profile already has this data.
    /// Skips D2 (DOB), D4 (Sex), D5 (Height), D6 (Weight) if valid profile data exists.
    /// The data is auto-injected as responses via the backend to ensure scoring works.
    private func shouldSkipDemographicQuestion(_ questionId: String) -> Bool {
        let profile = OnboardingManager.shared.profile
        let currentYear = Calendar.current.component(.year, from: Date())

        switch questionId {
        case "D2": // Date of Birth
            // Skip if birthYear is valid (between 1900 and current year)
            let shouldSkip = profile.birthYear > 1900 && profile.birthYear < currentYear
            print("[iOS] D2 check: birthYear=\(profile.birthYear), currentYear=\(currentYear), shouldSkip=\(shouldSkip)")
            return shouldSkip
        case "D4": // Sex
            // Skip if gender is set and not "prefer not to say"
            let gender = profile.gender.lowercased()
            let shouldSkip = !gender.isEmpty && gender != "prefer not to say"
            print("[iOS] D4 check: gender='\(profile.gender)', shouldSkip=\(shouldSkip)")
            return shouldSkip
        case "D5": // Height
            // Skip if height is valid (100-250 cm reasonable range)
            if let height = profile.heightCm {
                let shouldSkip = height >= 100 && height <= 250
                print("[iOS] D5 check: heightCm=\(height), shouldSkip=\(shouldSkip)")
                return shouldSkip
            }
            print("[iOS] D5 check: heightCm=nil, shouldSkip=false")
            return false
        case "D6": // Weight
            // Skip if weight is valid (30-300 kg reasonable range)
            if let weight = profile.weightKg {
                let shouldSkip = weight >= 30 && weight <= 300
                print("[iOS] D6 check: weightKg=\(weight), shouldSkip=\(shouldSkip)")
                return shouldSkip
            }
            print("[iOS] D6 check: weightKg=nil, shouldSkip=false")
            return false
        default:
            return false
        }
    }

    /// Check if a question should be shown based on its conditional logic
    private func shouldShowQuestion(_ question: Question, responses: [String: Any]) -> Bool {
        guard let condition = question.conditionalLogic else {
            print("[iOS] shouldShowQuestion(\(question.id)): No condition, showing")
            return true // No condition = always show
        }

        let result = evaluateCondition(condition, responses: responses, questionId: question.id)
        print("[iOS] shouldShowQuestion(\(question.id)): Final result = \(result)")
        return result
    }

    /// Recursively evaluate conditional logic including compound conditions (all/any) and age checks
    private func evaluateCondition(_ condition: ConditionalLogic, responses: [String: Any], questionId: String) -> Bool {
        // Handle compound AND conditions (all must be true)
        if let allConditions = condition.all {
            print("[iOS] evaluateCondition(\(questionId)): Evaluating ALL (\(allConditions.count) conditions)")
            for (index, subCondition) in allConditions.enumerated() {
                let subResult = evaluateCondition(subCondition, responses: responses, questionId: questionId)
                print("[iOS] evaluateCondition(\(questionId)): ALL[\(index)] = \(subResult)")
                if !subResult {
                    return false
                }
            }
            return true
        }

        // Handle compound OR conditions (at least one must be true)
        if let anyConditions = condition.any {
            print("[iOS] evaluateCondition(\(questionId)): Evaluating ANY (\(anyConditions.count) conditions)")
            for (index, subCondition) in anyConditions.enumerated() {
                let subResult = evaluateCondition(subCondition, responses: responses, questionId: questionId)
                print("[iOS] evaluateCondition(\(questionId)): ANY[\(index)] = \(subResult)")
                if subResult {
                    return true
                }
            }
            return false
        }

        // Handle age-based conditions (calculated from D2 birth date)
        if let ageUnder = condition.ageUnder {
            guard let age = calculateUserAge(from: responses) else {
                print("[iOS] evaluateCondition(\(questionId)): ageUnder=\(ageUnder), no DOB found, hiding")
                return false
            }
            let result = age < ageUnder
            print("[iOS] evaluateCondition(\(questionId)): age \(age) < \(ageUnder) = \(result)")
            return result
        }

        if let ageOver = condition.ageOver {
            guard let age = calculateUserAge(from: responses) else {
                print("[iOS] evaluateCondition(\(questionId)): ageOver=\(ageOver), no DOB found, hiding")
                return false
            }
            let result = age > ageOver
            print("[iOS] evaluateCondition(\(questionId)): age \(age) > \(ageOver) = \(result)")
            return result
        }

        // Handle simple question-based conditions
        guard let refQuestionId = condition.questionId else {
            // No questionId and not a compound/age condition - default to show
            return true
        }

        guard let dependentResponse = responses[refQuestionId] else {
            print("[iOS] evaluateCondition(\(questionId)): No response for '\(refQuestionId)', hiding")
            return false
        }

        print("[iOS] evaluateCondition(\(questionId)): Found response '\(dependentResponse)' for '\(refQuestionId)'")

        // Check equals condition
        if let equalsValue = condition.equals {
            if let stringResponse = dependentResponse as? String {
                let matches = stringResponse.lowercased() == equalsValue.lowercased()
                print("[iOS] evaluateCondition(\(questionId)): '\(stringResponse)' == '\(equalsValue)' => \(matches)")
                return matches
            }
            print("[iOS] evaluateCondition(\(questionId)): Response is not a string for equals check")
            return false
        }

        // Check greaterThan condition
        if let greaterThanValue = condition.greaterThan {
            if let numValue = extractNumericValue(from: dependentResponse) {
                return numValue > greaterThanValue
            }
            return false
        }

        // Check lessThan condition
        if let lessThanValue = condition.lessThan {
            if let numValue = extractNumericValue(from: dependentResponse) {
                return numValue < lessThanValue
            }
            return false
        }

        // Check greaterThanOrEqual condition
        if let gteValue = condition.greaterThanOrEqual {
            if let numValue = extractNumericValue(from: dependentResponse) {
                return numValue >= gteValue
            }
            return false
        }

        // Check lessThanOrEqual condition
        if let lteValue = condition.lessThanOrEqual {
            if let numValue = extractNumericValue(from: dependentResponse) {
                return numValue <= lteValue
            }
            return false
        }

        // Check contains condition (for array responses like medication categories)
        if let containsValue = condition.contains {
            // Check if response is an array of strings
            if let arrayResponse = dependentResponse as? [String] {
                let matches = arrayResponse.contains { $0.lowercased() == containsValue.lowercased() }
                print("[iOS] evaluateCondition(\(questionId)): Array contains '\(containsValue)' => \(matches)")
                return matches
            }
            // Check if response is a JSON string array
            if let stringResponse = dependentResponse as? String,
               let data = stringResponse.data(using: .utf8),
               let arrayResponse = try? JSONDecoder().decode([String].self, from: data) {
                let matches = arrayResponse.contains { $0.lowercased() == containsValue.lowercased() }
                print("[iOS] evaluateCondition(\(questionId)): JSON array contains '\(containsValue)' => \(matches)")
                return matches
            }
            print("[iOS] evaluateCondition(\(questionId)): Response is not an array for contains check")
            return false
        }

        // Check inValues condition (value must be in the array of allowed values)
        if let inValues = condition.inValues {
            let responseStr: String
            if let stringResponse = dependentResponse as? String {
                responseStr = stringResponse
            } else if let intResponse = dependentResponse as? Int {
                responseStr = String(intResponse)
            } else if let doubleResponse = dependentResponse as? Double {
                responseStr = String(Int(doubleResponse))
            } else {
                print("[iOS] evaluateCondition(\(questionId)): Response type not supported for 'in' check")
                return false
            }

            let matches = inValues.contains { $0.lowercased() == responseStr.lowercased() }
            print("[iOS] evaluateCondition(\(questionId)): '\(responseStr)' IN [\(inValues.joined(separator: ", "))] => \(matches)")
            return matches
        }

        return true
    }

    /// Extract numeric value from various response types
    private func extractNumericValue(from response: Any) -> Double? {
        if let numResponse = response as? Double {
            return numResponse
        } else if let numResponse = response as? Int {
            return Double(numResponse)
        } else if let stringResponse = response as? String,
                  let numValue = Double(stringResponse) {
            return numValue
        }
        return nil
    }

    /// Calculate user's age from D2 (Date of Birth) response
    private func calculateUserAge(from responses: [String: Any]) -> Int? {
        // Try to get DOB from current responses first
        var dobString: String? = nil

        if let dobResponse = responses["D2"] {
            if let strResponse = dobResponse as? String {
                dobString = strResponse
            }
        }

        // Fallback: check assessmentResponses (might have been answered earlier in session)
        if dobString == nil, let dobResponse = assessmentResponses["D2"] {
            if let strResponse = dobResponse as? String {
                dobString = strResponse
            }
        }

        // Fallback: check questionnaire manager's responses (might have been persisted)
        if dobString == nil, let managerResponse = questionnaireManager.responses["D2"] {
            dobString = managerResponse.stringValue
        }

        guard let dob = dobString else {
            print("[iOS] calculateUserAge: No D2 response found in any source")
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        guard let birthDate = dateFormatter.date(from: dob) else {
            print("[iOS] calculateUserAge: Failed to parse DOB '\(dob)'")
            return nil
        }

        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        let age = ageComponents.year
        print("[iOS] calculateUserAge: Calculated age = \(age ?? -1) from DOB '\(dob)'")
        return age
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

        // CRITICAL FIX: If we've skipped past all remaining questions, trigger end-of-section
        // This prevents the "16 of 15" bug where index exceeds question count
        if nextIndex >= questions.count {
            print("[iOS] advanceToNextQuestion: Skipped past all questions (nextIndex=\(nextIndex), count=\(questions.count)) - triggering section completion")
            if currentSection == .sleepLog {
                // Finished sleep log via conditional skipping
                completeSectionInBackground(section: .sleepLog)
                if sectionOnly || assessmentQuestions.isEmpty {
                    withAnimation {
                        completedSectionAtFinish = .sleepLog
                        showingCompletion = true
                    }
                } else {
                    withAnimation {
                        showingTransition = true
                    }
                }
            } else {
                // Finished assessment via conditional skipping
                completeSectionInBackground(section: .assessment)
                withAnimation {
                    completedSectionAtFinish = .assessment
                    showingCompletion = true
                }
            }
            return
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

        // Generate derived PSQI responses from sleep log data (e.g., PSQI_4 sleep hours)
        questionnaireManager.generateDerivedPSQIResponses(forDay: currentDay)

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

                    // Transition to assessment section
                    currentSection = .assessment
                    assessmentIndex = 0
                    questionStartTime = Date()

                    // Check if we should show a splash screen for the assessment
                    // This ensures the splash appears when proceeding from Sleep Log completion
                    print("[iOS] proceedToAssessment: assessmentQuestions.count = \(assessmentQuestions.count)")
                    if !assessmentQuestions.isEmpty {
                        let estimatedMinutes = max(1, (assessmentQuestions.count + 3) / 4) // ~15 seconds per question, min 1

                        // Use expansion splash for expansion days, day splash for core days
                        if !currentDayExpansionModules.isEmpty && currentDay >= 6 {
                            print("[iOS] proceedToAssessment: Day \(currentDay) has expansion modules - showing expansion splash")
                            checkAndShowExpansionSplash(modules: currentDayExpansionModules)
                        } else {
                            print("[iOS] proceedToAssessment: Calling checkAndShowDaySplash with \(assessmentQuestions.count) questions, ~\(estimatedMinutes) min")
                            checkAndShowDaySplash(questionCount: assessmentQuestions.count, estimatedMinutes: estimatedMinutes)
                        }
                        print("[iOS] proceedToAssessment: After splash setup - showingDaySplash=\(showingDaySplash), showingExpansionSplash=\(showingExpansionSplash)")
                    }

                    // Dismiss the completion view AFTER potentially setting up the splash
                    // The splash view takes priority in the view hierarchy (checked first in body)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingCompletion = false
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

        // For number/numberScroll questions, user can accept the smart default by tapping Next
        if question.questionType == .number || question.questionType == .numberScroll {
            let valueToSave: Double
            let defaultValue = NumberInput.smartDefault(for: question)
            if currentSection == .sleepLog {
                if let existingValue = sleepLogResponses[question.id] as? Double {
                    valueToSave = existingValue
                } else if let existingInt = sleepLogResponses[question.id] as? Int {
                    valueToSave = Double(existingInt)
                } else {
                    valueToSave = defaultValue
                    sleepLogResponses[question.id] = valueToSave
                }
                sleepLogUserInteracted.insert(question.id)
            } else {
                if let existingValue = assessmentResponses[question.id] as? Double {
                    valueToSave = existingValue
                } else if let existingInt = assessmentResponses[question.id] as? Int {
                    valueToSave = Double(existingInt)
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

                    // Record gamification progress (PARKED - enable via Debug Panel)
                    if themeManager.gamificationEnabled {
                        let triggeredGateways = questionnaireManager.gatewayStates
                            .filter { $0.triggered }
                            .map { $0.gatewayType.rawValue }

                        _ = await GamificationManager.shared.recordDayComplete(
                            dayNumber: currentDay,
                            completedSleepLog: section == .sleepLog || result.sleepLogCompleted,
                            completedAssessment: section == .assessment || result.assessmentCompleted,
                            triggeredGateways: triggeredGateways.isEmpty ? nil : triggeredGateways
                        )
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

                    // Record gamification progress for full day (PARKED - enable via Debug Panel)
                    if themeManager.gamificationEnabled {
                        let triggeredGateways = questionnaireManager.gatewayStates
                            .filter { $0.triggered }
                            .map { $0.gatewayType.rawValue }

                        _ = await GamificationManager.shared.recordDayComplete(
                            dayNumber: currentDay,
                            completedSleepLog: true,
                            completedAssessment: true,
                            triggeredGateways: triggeredGateways.isEmpty ? nil : triggeredGateways
                        )
                    }

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
                // Add unit if this is a question with unit configuration
                if let unit = getUnitForQuestion(questionId) {
                    response["responseUnit"] = unit
                }
            } else if let intValue = value as? Int {
                response["responseNumber"] = Double(intValue)
                // Add unit if this is a question with unit configuration
                if let unit = getUnitForQuestion(questionId) {
                    response["responseUnit"] = unit
                }
            } else if let dateValue = value as? Date {
                // Format based on question type: use full date for .date, time only for .time
                let formatter = DateFormatter()
                if questionnaireManager.getQuestionType(for: questionId) == .date {
                    formatter.dateFormat = "yyyy-MM-dd"  // Full date for date of birth, etc.
                } else {
                    formatter.dateFormat = "HH:mm"  // Time only for bedtime/wake time
                }
                response["responseValue"] = formatter.string(from: dateValue)
            } else if let arrayValue = value as? [String] {
                response["responseArray"] = arrayValue
            } else if let medSelections = value as? [MedicationSelection] {
                // Serialize medication selections to JSON
                if let jsonData = try? JSONEncoder().encode(medSelections),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response["responseObject"] = jsonString
                    print("[iOS] Encoded \(medSelections.count) medication selections for \(questionId)")
                }
            } else if let napEntries = value as? [NapEntry] {
                // Serialize nap entries to JSON
                if let jsonData = try? JSONEncoder().encode(napEntries),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response["responseObject"] = jsonString
                    print("[iOS] Encoded \(napEntries.count) nap entries for \(questionId)")
                }
            } else if let caffeineEntries = value as? [CaffeineEntry] {
                // Serialize caffeine entries to JSON
                if let jsonData = try? JSONEncoder().encode(caffeineEntries),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response["responseObject"] = jsonString
                    print("[iOS] Encoded \(caffeineEntries.count) caffeine entries for \(questionId)")
                }
            } else if let medsWithTiming = value as? [MedicationWithTiming] {
                // Serialize medications with timing to JSON
                if let jsonData = try? JSONEncoder().encode(medsWithTiming),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response["responseObject"] = jsonString
                    print("[iOS] Encoded \(medsWithTiming.count) medications with timing for \(questionId)")
                }
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
                // Add unit if this is a question with unit configuration
                if let unit = getUnitForQuestion(questionId) {
                    response["responseUnit"] = unit
                }
            } else if let intValue = value as? Int {
                response["responseNumber"] = Double(intValue)
                // Add unit if this is a question with unit configuration
                if let unit = getUnitForQuestion(questionId) {
                    response["responseUnit"] = unit
                }
            } else if let dateValue = value as? Date {
                // Format based on question type: use full date for .date, time only for .time
                let formatter = DateFormatter()
                if questionnaireManager.getQuestionType(for: questionId) == .date {
                    formatter.dateFormat = "yyyy-MM-dd"  // Full date for date of birth, etc.
                } else {
                    formatter.dateFormat = "HH:mm"  // Time only for bedtime/wake time
                }
                response["responseValue"] = formatter.string(from: dateValue)
            } else if let arrayValue = value as? [String] {
                response["responseArray"] = arrayValue
            } else if let medSelections = value as? [MedicationSelection] {
                // Serialize medication selections to JSON
                if let jsonData = try? JSONEncoder().encode(medSelections),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response["responseObject"] = jsonString
                    print("[iOS] Encoded \(medSelections.count) medication selections for \(questionId)")
                }
            } else if let napEntries = value as? [NapEntry] {
                // Serialize nap entries to JSON
                if let jsonData = try? JSONEncoder().encode(napEntries),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response["responseObject"] = jsonString
                    print("[iOS] Encoded \(napEntries.count) nap entries for \(questionId)")
                }
            } else if let caffeineEntries = value as? [CaffeineEntry] {
                // Serialize caffeine entries to JSON
                if let jsonData = try? JSONEncoder().encode(caffeineEntries),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response["responseObject"] = jsonString
                    print("[iOS] Encoded \(caffeineEntries.count) caffeine entries for \(questionId)")
                }
            } else if let medsWithTiming = value as? [MedicationWithTiming] {
                // Serialize medications with timing to JSON
                if let jsonData = try? JSONEncoder().encode(medsWithTiming),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    response["responseObject"] = jsonString
                    print("[iOS] Encoded \(medsWithTiming.count) medications with timing for \(questionId)")
                }
            }

            convexResponses.append(response)
        }

        // Add derived responses for complete clinical scoring
        // These are answers auto-populated from equivalent questions that were asked
        let derivedResponses = questionnaireManager.getDerivedResponsesForScoring()
        for derived in derivedResponses {
            var response: [String: Any] = [
                "questionId": derived.questionId,
                "isDerived": true  // Mark as derived for the physician dashboard
            ]

            if let stringValue = derived.stringValue {
                response["responseValue"] = stringValue
            } else if let numberValue = derived.numberValue {
                response["responseNumber"] = numberValue
            } else if let arrayValue = derived.arrayValue {
                response["responseArray"] = arrayValue
            }

            convexResponses.append(response)
        }

        if !derivedResponses.isEmpty {
            print("[iOS] Added \(derivedResponses.count) derived responses for complete clinical scoring")
        }

        // Only sync if we have responses
        print("[iOS] Total responses to sync: \(convexResponses.count) (user + derived)")
        if !convexResponses.isEmpty {
            print("[iOS] Calling ConvexService.saveResponses for day \(currentDay)...")
            let result = try await ConvexService.shared.saveResponses(dayNumber: currentDay, responses: convexResponses)
            print("[iOS] Synced \(result.savedCount) responses to Convex")
        } else {
            print("[iOS] No responses to sync!")
        }
    }

    /// Get the appropriate unit for a question based on user's measurement preference
    /// Returns nil if the question doesn't have unit configuration
    private func getUnitForQuestion(_ questionId: String) -> String? {
        // Look up question in both sleep log and assessment questions
        let question = sleepLogQuestions.first(where: { $0.id == questionId })
            ?? assessmentQuestions.first(where: { $0.id == questionId })
        guard let question = question else { return nil }

        // Check if user prefers imperial and question has imperial unit config
        let useImperial = OnboardingManager.shared.profile.measurementSystem == MeasurementSystem.imperial.rawValue
            && question.unitImperial != nil

        return useImperial ? question.unitImperial : question.unit
    }

    /// Helper function to convert a response value to Convex format dictionary
    /// Handles all types including complex objects (medications, naps, caffeine)
    private func convertValueToConvexFormat(questionId: String, value: Any) -> [String: Any]? {
        var response: [String: Any] = ["questionId": questionId]

        if let stringValue = value as? String {
            response["responseValue"] = stringValue
        } else if let numberValue = value as? Double {
            response["responseNumber"] = numberValue
            if let unit = getUnitForQuestion(questionId) {
                response["responseUnit"] = unit
            }
        } else if let intValue = value as? Int {
            response["responseNumber"] = Double(intValue)
            if let unit = getUnitForQuestion(questionId) {
                response["responseUnit"] = unit
            }
        } else if let dateValue = value as? Date {
            let formatter = DateFormatter()
            if questionnaireManager.getQuestionType(for: questionId) == .date {
                formatter.dateFormat = "yyyy-MM-dd"
            } else {
                formatter.dateFormat = "HH:mm"
            }
            response["responseValue"] = formatter.string(from: dateValue)
        } else if let arrayValue = value as? [String] {
            response["responseArray"] = arrayValue
        } else if let medSelections = value as? [MedicationSelection] {
            // Serialize medication selections to JSON
            if let jsonData = try? JSONEncoder().encode(medSelections),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                response["responseObject"] = jsonString
                print("[iOS] Encoded \(medSelections.count) medication selections for \(questionId)")
            }
        } else if let napEntries = value as? [NapEntry] {
            // Serialize nap entries to JSON
            if let jsonData = try? JSONEncoder().encode(napEntries),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                response["responseObject"] = jsonString
                print("[iOS] Encoded \(napEntries.count) nap entries for \(questionId)")
            }
        } else if let caffeineEntries = value as? [CaffeineEntry] {
            // Serialize caffeine entries to JSON
            if let jsonData = try? JSONEncoder().encode(caffeineEntries),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                response["responseObject"] = jsonString
                print("[iOS] Encoded \(caffeineEntries.count) caffeine entries for \(questionId)")
            }
        } else if let medsWithTiming = value as? [MedicationWithTiming] {
            // Serialize medications with timing to JSON
            if let jsonData = try? JSONEncoder().encode(medsWithTiming),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                response["responseObject"] = jsonString
                print("[iOS] Encoded \(medsWithTiming.count) medications with timing for \(questionId)")
            }
        } else {
            print("[iOS] Warning: Unknown response type for \(questionId): \(type(of: value))")
            return nil
        }

        return response
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

    /// Handle gateway state changes and show notification for newly triggered gateways
    private func handleGatewayStateChange(_ newStates: [GatewayState]) {
        // Detect newly triggered gateways and show notification for just that gateway
        for gateway in newStates where gateway.triggered {
            // Only show if not already acknowledged and not currently showing another
            if !acknowledgedGateways.contains(gateway.gatewayType) && newlyTriggeredGateway == nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    newlyTriggeredGateway = gateway.gatewayType
                }
                print("[iOS] New gateway triggered: \(gateway.gatewayType.displayName)")
                break // Only show one at a time
            }
        }
    }

    /// Save any in-progress responses when leaving the questionnaire (e.g., via back button)
    /// This ensures partial progress is persisted and the user can resume later
    private func saveInProgressResponses() {
        // Only save if we have responses that the user interacted with
        guard !sleepLogUserInteracted.isEmpty || !assessmentUserInteracted.isEmpty else {
            print("[iOS] No user-interacted responses to save on dismiss")
            return
        }

        // Fire-and-forget async save - we don't want to block the dismiss
        Task {
            do {
                // Build the responses array using helper function (handles complex types)
                var convexResponses: [[String: Any]] = []

                // Save sleep log responses that user interacted with
                for (questionId, value) in sleepLogResponses {
                    guard sleepLogUserInteracted.contains(questionId) else { continue }
                    if let response = convertValueToConvexFormat(questionId: questionId, value: value) {
                        convexResponses.append(response)
                    }
                }

                // Save assessment responses that user interacted with
                for (questionId, value) in assessmentResponses {
                    guard assessmentUserInteracted.contains(questionId) else { continue }
                    if let response = convertValueToConvexFormat(questionId: questionId, value: value) {
                        convexResponses.append(response)
                    }
                }

                if !convexResponses.isEmpty {
                    let result = try await ConvexService.shared.saveResponses(dayNumber: currentDay, responses: convexResponses)
                    print("[iOS] Saved \(result.savedCount) in-progress responses on dismiss")
                }
            } catch {
                print("[iOS] Warning: Failed to save in-progress responses on dismiss: \(error.localizedDescription)")
                // We intentionally don't show an error to the user here - it's a background save
            }
        }
    }

    /// Complete the section immediately in the background when showing completion screen
    /// This ensures the section is marked as complete even if user taps back instead of proceeding
    private func completeSectionInBackground(section: QuestionnaireSection) {
        Task {
            do {
                // First save all responses for this section
                let responses = section == .sleepLog ? sleepLogResponses : assessmentResponses
                let userInteracted = section == .sleepLog ? sleepLogUserInteracted : assessmentUserInteracted
                let questions = section == .sleepLog ? sleepLogQuestions : assessmentQuestions

                // Save responses locally
                for (questionId, value) in responses {
                    saveResponseFromDictionary(questionId: questionId, value: value, questions: questions)
                }

                // Build Convex responses for sync using helper function (handles complex types)
                var convexResponses: [[String: Any]] = []
                for (questionId, value) in responses {
                    guard userInteracted.contains(questionId) else { continue }
                    if let response = convertValueToConvexFormat(questionId: questionId, value: value) {
                        convexResponses.append(response)
                    }
                }

                // Sync responses to Convex
                if !convexResponses.isEmpty {
                    let result = try await ConvexService.shared.saveResponses(dayNumber: currentDay, responses: convexResponses)
                    print("[iOS] Background save: synced \(result.savedCount) responses")
                }

                // Mark section as complete
                let sectionName = section == .sleepLog ? "sleepLog" : "assessment"
                let result = try await ConvexService.shared.completeSection(dayNumber: currentDay, section: sectionName)
                print("[iOS] Background completion: \(sectionName) marked complete (sleepLog=\(result.sleepLogCompleted), assessment=\(result.assessmentCompleted))")

                // CRITICAL: Sync gateway states to Convex after assessment completion
                // This enables proper expansion pack filtering on Days 6-14
                if section == .assessment && currentDay <= 5 {
                    print("[iOS] Syncing gateway states to Convex after Day \(currentDay) assessment...")
                    questionnaireManager.evaluateGateways()
                    for gateway in questionnaireManager.gatewayStates {
                        do {
                            try await ConvexService.shared.updateGatewayState(
                                gatewayId: gateway.gatewayType.rawValue,
                                isTriggered: gateway.triggered,
                                triggerQuestionId: nil,
                                triggerValue: nil
                            )
                        } catch {
                            print("[iOS] Warning: Failed to sync gateway \(gateway.gatewayType.rawValue): \(error.localizedDescription)")
                        }
                    }
                    let triggeredCount = questionnaireManager.gatewayStates.filter { $0.triggered }.count
                    print("[iOS] Gateway sync complete: \(triggeredCount) gateways triggered")
                }

                // Refresh journey progress so dashboard shows correct state
                await questionnaireManager.loadJourneyProgress()

                // Notify dashboard to refresh
                await MainActor.run {
                    NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)

                    // Save sleep log responses for smart pre-fill on next day
                    if section == .sleepLog {
                        saveSleepLogForPreFill()
                    }
                }
            } catch {
                print("[iOS] Warning: Background section completion failed: \(error.localizedDescription)")
                // Don't show error to user - they'll see it when they explicitly try to proceed
            }
        }
    }

    // MARK: - Smart Pre-fill for Sleep Log

    /// Save current sleep log responses for next day's pre-fill
    private func saveSleepLogForPreFill() {
        // Save time-based responses that make sense to pre-fill
        // Note: Quality, awakenings, and nap details are NEVER pre-filled (must be fresh each day)
        //
        // Pre-fillable questions (times tend to be consistent):
        // - Bed times: SD_GOT_INTO_BED, SD_LIGHTS_OUT, SD_FINAL_WAKE, SD_OUT_OF_BED
        // - Medication: SD_MEDICATION_TAKEN (pattern), SD_MEDICATION_TIME
        // - Day type: SD_DAY_TYPE (for reference)
        //
        // NEVER pre-fill (changes daily):
        // - SD_SLEEP_QUALITY, SD_SLEEP_LATENCY, SD_AWAKENINGS_COUNT, SD_AWAKENINGS_DURATION
        // - SD_NAPS_TAKEN, SD_NAPS_COUNT, SD_NAP_DETAILS
        let preFillableQuestionIds = [
            // Time questions (tend to be consistent day-to-day)
            "SD_GOT_INTO_BED", "SD_LIGHTS_OUT", "SD_FINAL_WAKE", "SD_OUT_OF_BED",
            // Medication pattern (consistent unless they stop)
            "SD_MEDICATION_TAKEN", "SD_MEDICATION_TIME",
            // Day type for reference
            "SD_DAY_TYPE"
        ]

        var preFillData: [String: Any] = [:]
        for questionId in preFillableQuestionIds {
            if let value = sleepLogResponses[questionId] {
                // Store Date as string for UserDefaults
                if let dateValue = value as? Date {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    preFillData[questionId] = formatter.string(from: dateValue)
                } else {
                    preFillData[questionId] = value
                }
            }
        }

        // Store with day type info for smart matching
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let dayType = (weekday == 1 || weekday == 7) ? "Weekend" : "Weekday"
        preFillData["_dayType"] = dayType
        preFillData["_savedDay"] = currentDay

        UserDefaults.standard.set(preFillData, forKey: "sleepLogPreFill")
        print("[iOS] Saved \(preFillData.count - 2) sleep log responses for next day pre-fill (dayType: \(dayType))")
    }

    /// Load previous day's sleep log for pre-fill suggestions
    /// Returns dictionary of suggested values
    private func loadPreFillSuggestions() -> [String: Any] {
        guard currentDay > 1 else { return [:] }

        guard let saved = UserDefaults.standard.dictionary(forKey: "sleepLogPreFill") else {
            print("[iOS] No previous sleep log data for pre-fill")
            return [:]
        }

        // Check if same day type (workday vs weekend) for better accuracy
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let todayDayType = (weekday == 1 || weekday == 7) ? "Weekend" : "Weekday"
        let savedDayType = saved["_dayType"] as? String ?? ""

        if todayDayType != savedDayType {
            print("[iOS] Day type mismatch (today: \(todayDayType), saved: \(savedDayType)) - still offering pre-fill with note")
        }

        print("[iOS] Loaded \(saved.count - 2) pre-fill suggestions from previous sleep log")
        return saved
    }

    /// Apply pre-fill suggestions to current sleep log
    private func applyPreFillSuggestions() {
        let suggestions = loadPreFillSuggestions()

        for (questionId, value) in suggestions {
            // Skip metadata keys
            if questionId.hasPrefix("_") { continue }

            // Convert time strings back to Date
            if let timeString = value as? String,
               sleepLogQuestions.first(where: { $0.id == questionId })?.questionType == .time {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                if let date = formatter.date(from: timeString) {
                    sleepLogResponses[questionId] = date
                }
            } else {
                sleepLogResponses[questionId] = value
            }
            // Note: NOT marking as user-interacted - user must confirm or change
        }

        print("[iOS] Applied \(suggestions.count - 2) pre-fill suggestions (user must confirm)")
    }

    // MARK: - Day Splash Screen Logic

    /// Check if we should show the hero-framed day splash for ANY day (1-14)
    /// Shows once per day when user first enters the assessment section
    private func checkAndShowDaySplash(questionCount: Int, estimatedMinutes: Int) {
        // Get the key for tracking if splash was shown for this day's assessment
        let splashKey = "daySplashShown_day\(currentDay)_assessment"

        // Check if already shown for this day
        if UserDefaults.standard.bool(forKey: splashKey) {
            print("[iOS] Day splash already shown for day \(currentDay) assessment, skipping")
            return
        }

        // Get splash info from library (with dynamic question count from backend)
        guard let info = DaySplashLibrary.info(for: currentDay, questionCount: questionCount, estimatedMinutes: estimatedMinutes) else {
            print("[iOS] No day splash info found for day \(currentDay)")
            return
        }

        print("[iOS] Showing day splash for day \(currentDay): \"\(info.title)\" (\(questionCount) questions, ~\(estimatedMinutes) min)")

        // Mark as shown for this day
        UserDefaults.standard.set(true, forKey: splashKey)

        // Set the splash info and show it
        daySplashInfo = info
        showingDaySplash = true
    }

    // MARK: - Expansion Splash Screen Logic

    /// Check if we should show an expansion pack splash screen and populate the info
    /// Shows detailed clinical questionnaire info (DASS-21, PHQ-9, etc.) for expansion days (Day 6+)
    /// Only shows once per day when user first enters the assessment section
    private func checkAndShowExpansionSplash(modules: [String]) {
        // Get the key for tracking if splash was shown for this day
        let splashKey = "expansionSplashShown_day\(currentDay)"

        // Check if already shown for this day
        if UserDefaults.standard.bool(forKey: splashKey) {
            print("[iOS] Expansion splash already shown for day \(currentDay), skipping")
            return
        }

        // Get questionnaire info for the modules in today's assessment
        // Filter for expansion modules only (those starting with "expansion_")
        let expansionModules = modules.filter { $0.hasPrefix("expansion_") }

        if expansionModules.isEmpty {
            print("[iOS] No expansion modules for day \(currentDay), skipping splash")
            return
        }

        // Get validation info for these modules
        let infos = QuestionnaireLibrary.infos(for: expansionModules)

        if infos.isEmpty {
            print("[iOS] No validation info found for modules: \(expansionModules)")
            return
        }

        print("[iOS] Showing expansion splash for day \(currentDay) with \(infos.count) questionnaires")

        // Mark as shown for this day
        UserDefaults.standard.set(true, forKey: splashKey)

        // Set the splash info and show it
        expansionSplashInfo = infos
        showingExpansionSplash = true
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
