//
//  QuestionnaireView.swift
//  Sleep 360 Platform
//
//  Complete 15-day adaptive questionnaire interface with HealthKit integration
//

import SwiftUI
import Combine

struct QuestionnaireView: View {
    @Binding var currentDay: Int
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var questionnaireManager = QuestionnaireManager.shared

    @State private var questions: [Question] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var responses: [String: Any] = [:]
    @State private var healthKitSleepSummary: HealthKitSleepSummary?
    @State private var isLoadingHealthKit: Bool = false
    @State private var showingCompletionAlert: Bool = false
    @State private var showingSleepComparison: Bool = false
    @State private var startTime: Date = Date()
    @State private var questionStartTime: Date = Date()

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // Progress Header
            if !questions.isEmpty {
                QuestionnaireProgressHeader(
                    currentIndex: currentQuestionIndex,
                    totalQuestions: questions.count,
                    dayNumber: currentDay,
                    pillarColor: Color(hex: questions[currentQuestionIndex].pillar.color) ?? .blue
                )
            }

            // Main Content
            ScrollView {
                VStack(spacing: 20) {
                    // HealthKit Sleep Summary (show at start of day)
                    if currentQuestionIndex == 0 && healthKitSleepSummary != nil {
                        HealthKitSleepCard(summary: healthKitSleepSummary!)
                    }

                    // Current Question
                    if !questions.isEmpty && currentQuestionIndex < questions.count {
                        questionView(for: questions[currentQuestionIndex])
                    }

                    // Gateway alerts
                    ForEach(questionnaireManager.gatewayStates.filter { $0.triggered }, id: \.id) { gateway in
                        GatewayAlertBanner(gatewayType: gateway.gatewayType, isTriggered: true)
                    }
                }
                .padding()
            }

            // Navigation Buttons
            navigationButtons
        }
        .navigationTitle("Day \(currentDay) Questionnaire")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadQuestions()
            fetchHealthKitSleepData()
        }
        .alert("Day Complete!", isPresented: $showingCompletionAlert) {
            Button("Continue") {
                completeDay()
            }
        } message: {
            Text("Great job! You've completed Day \(currentDay).\(getCompletionMessage())")
        }
    }

    // MARK: - Question View

    @ViewBuilder
    private func questionView(for question: Question) -> some View {
        QuestionCard(question: question) {
            switch question.questionType {
            case .scale:
                ScaleInput(
                    question: question,
                    value: Binding(
                        get: { (responses[question.id] as? Double) ?? Double(question.scaleMin ?? 1) },
                        set: { responses[question.id] = $0 }
                    )
                )

            case .yesNo, .yesNoDontKnow:
                YesNoInput(
                    question: question,
                    value: Binding(
                        get: { (responses[question.id] as? String) ?? "" },
                        set: { responses[question.id] = $0 }
                    )
                )

            case .singleSelect:
                SingleSelectInput(
                    question: question,
                    value: Binding(
                        get: { (responses[question.id] as? String) ?? "" },
                        set: { responses[question.id] = $0 }
                    )
                )

            case .multiSelect:
                MultiSelectInput(
                    question: question,
                    values: Binding(
                        get: { (responses[question.id] as? [String]) ?? [] },
                        set: { responses[question.id] = $0 }
                    )
                )

            case .number, .numberScroll:
                NumberInput(
                    question: question,
                    value: Binding(
                        get: { (responses[question.id] as? Double) ?? Double(question.defaultValue ?? question.minValue ?? 0) },
                        set: { responses[question.id] = $0 }
                    )
                )

            case .time:
                TimeInput(
                    question: question,
                    value: Binding(
                        get: { (responses[question.id] as? Date) ?? Date() },
                        set: { responses[question.id] = $0 }
                    )
                )

            case .date:
                DateInputView(
                    question: question,
                    value: Binding(
                        get: { (responses[question.id] as? Date) ?? Date() },
                        set: { responses[question.id] = $0 }
                    )
                )

            case .text, .email:
                TextInputView(
                    question: question,
                    value: Binding(
                        get: { (responses[question.id] as? String) ?? "" },
                        set: { responses[question.id] = $0 }
                    ),
                    placeholder: question.questionType == .email ? "email@example.com" : "Enter your answer"
                )

            case .minutesScroll:
                MinutesScrollPicker(
                    question: question,
                    value: Binding(
                        get: { (responses[question.id] as? Int) ?? (question.defaultValue ?? 0) },
                        set: { responses[question.id] = $0 }
                    )
                )

            case .info:
                InfoCard(question: question)

            case .repeatingGroup:
                Text("Repeating group input (coming soon)")
                    .foregroundColor(.secondary)
            }
        }
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
            .disabled(currentQuestionIndex == 0)
            .opacity(currentQuestionIndex == 0 ? 0.5 : 1)

            // Next/Submit button
            Button(action: nextQuestion) {
                HStack {
                    Text(isLastQuestion ? "Submit" : "Next")
                    Image(systemName: isLastQuestion ? "checkmark.circle.fill" : "chevron.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canProceed)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Properties

    private var isLastQuestion: Bool {
        currentQuestionIndex == questions.count - 1
    }

    private var canProceed: Bool {
        guard !questions.isEmpty && currentQuestionIndex < questions.count else { return false }
        let question = questions[currentQuestionIndex]

        // Info questions don't require response
        if question.questionType == .info { return true }

        // Non-required questions can proceed
        if !question.required { return true }

        // Check if response exists
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
        questions = questionnaireManager.getQuestionsForDay(currentDay)
        currentQuestionIndex = 0
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
        if currentQuestionIndex > 0 {
            currentQuestionIndex -= 1
            questionStartTime = Date()
        }
    }

    private func nextQuestion() {
        // Save current response
        saveCurrentResponse()

        if isLastQuestion {
            showingCompletionAlert = true
        } else {
            currentQuestionIndex += 1
            questionStartTime = Date()
        }
    }

    private func saveCurrentResponse() {
        guard !questions.isEmpty && currentQuestionIndex < questions.count else { return }
        let question = questions[currentQuestionIndex]

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

    private func getCompletionMessage() -> String {
        let triggeredGateways = questionnaireManager.gatewayStates.filter { $0.triggered }
        if triggeredGateways.isEmpty {
            return ""
        }
        let names = triggeredGateways.map { $0.gatewayType.displayName }.joined(separator: ", ")
        return "\n\nBased on your responses, additional assessments have been added: \(names)"
    }
}

// MARK: - HealthKit Sleep Card

struct HealthKitSleepCard: View {
    let summary: HealthKitSleepSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Last Night's Sleep (Apple Health)")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 20) {
                // Total sleep
                VStack {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
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
                        .foregroundColor(.green)
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
                        .foregroundColor(.orange)
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
                .foregroundColor(.blue)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        QuestionnaireView(currentDay: .constant(1))
            .environmentObject(HealthKitManager(authManager: AuthenticationManager()))
    }
}
