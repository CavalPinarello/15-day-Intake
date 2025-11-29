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
                    }
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
    }

    // MARK: - Main Questionnaire View

    private var mainQuestionnaireView: some View {
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
            .background(currentSection.backgroundColor.opacity(0.3))

            // Navigation Buttons
            navigationButtons
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
            }
        } else {
            if isLastQuestionInSection {
                // Finished assessment - show completion
                withAnimation {
                    showingCompletion = true
                }
            } else {
                assessmentIndex += 1
                questionStartTime = Date()
            }
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
        // Save all remaining responses based on which section(s) we completed
        if currentSection == .sleepLog || !sectionOnly {
            for (questionId, value) in sleepLogResponses {
                saveResponseFromDictionary(questionId: questionId, value: value, questions: sleepLogQuestions)
            }
        }
        if currentSection == .assessment || !sectionOnly {
            for (questionId, value) in assessmentResponses {
                saveResponseFromDictionary(questionId: questionId, value: value, questions: assessmentQuestions)
            }
        }

        // If sectionOnly, just dismiss without advancing day
        if sectionOnly {
            presentationMode.wrappedValue.dismiss()
            return
        }

        // Full day completion - advance to next day
        Task {
            do {
                try await questionnaireManager.completeDay(currentDay)
                currentDay = min(currentDay + 1, 15)
                presentationMode.wrappedValue.dismiss()
            } catch {
                print("Error completing day: \(error.localizedDescription)")
                // Still advance locally even if sync fails
                currentDay = min(currentDay + 1, 15)
                presentationMode.wrappedValue.dismiss()
            }
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
