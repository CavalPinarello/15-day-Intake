//
//  QuestionnaireView.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Watch-optimized questionnaire interface for 15-day intake journey
//  Works standalone without iPhone connection
//

import SwiftUI
import WatchKit

struct QuestionnaireView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @AppStorage("watchCurrentDay") private var currentDay: Int = 1
    @AppStorage("watchCompletedDays") private var completedDaysData: Data = Data()

    @State private var questions: [WatchQuestion] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var responses: [String: Any] = [:]
    @State private var isLoading = true
    @State private var showingQuestions = false

    private var theme: WatchColorTheme { WatchColorTheme.shared }

    private var completedDays: [Int] {
        get {
            (try? JSONDecoder().decode([Int].self, from: completedDaysData)) ?? []
        }
    }

    private var isDayCompleted: Bool {
        completedDays.contains(currentDay)
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading...")
                    .tint(theme.primary)
                    .onAppear {
                        loadCurrentDay()
                    }
            } else if isDayCompleted && !showingQuestions {
                completedView
            } else if questions.isEmpty {
                noQuestionsView
            } else {
                questionnaireContent
            }
        }
    }

    private var questionnaireContent: some View {
        VStack(spacing: 0) {
            // Compact header: Day + Progress
            HStack {
                Text("Day \(currentDay)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.primary)

                Spacer()

                Text("\(currentQuestionIndex + 1)/\(questions.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)

            // Thin progress bar
            ProgressView(value: Double(currentQuestionIndex + 1), total: Double(questions.count))
                .progressViewStyle(LinearProgressViewStyle(tint: theme.primary))
                .scaleEffect(y: 0.5)
                .padding(.horizontal, 12)

            // Current question in scrollable area
            if currentQuestionIndex < questions.count {
                let question = questions[currentQuestionIndex]

                ScrollView {
                    VStack(spacing: 6) {
                        // Question text
                        Text(question.text)
                            .font(.system(size: 15, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .padding(.top, 2)

                        // Answer input
                        questionInputView(for: question)
                            .padding(.horizontal, 4)

                        // Navigation buttons inside scroll
                        HStack(spacing: 20) {
                            if currentQuestionIndex > 0 {
                                Button {
                                    currentQuestionIndex -= 1
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .buttonStyle(.bordered)
                                .frame(width: 55, height: 44)
                            } else {
                                Spacer()
                                    .frame(width: 55)
                            }

                            Spacer()

                            Button {
                                if currentQuestionIndex == questions.count - 1 {
                                    completeQuestionnaire()
                                } else {
                                    currentQuestionIndex += 1
                                }
                            } label: {
                                if currentQuestionIndex == questions.count - 1 {
                                    Text("Done")
                                        .font(.system(size: 14, weight: .bold))
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 18, weight: .bold))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.primary)
                            .frame(width: currentQuestionIndex == questions.count - 1 ? 70 : 55, height: 44)
                            .disabled(!isCurrentQuestionAnswered())
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    private var completedView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(theme.success)

                Text("Day \(currentDay) Complete!")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Great job!")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if currentDay < 15 {
                    Divider()
                        .padding(.vertical, 4)

                    Text("See you tomorrow")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Day \(currentDay + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.primary)
                } else {
                    Divider()
                        .padding(.vertical, 4)

                    Text("Journey Complete!")
                        .font(.caption)
                        .foregroundColor(theme.success)
                }

                Divider()
                    .padding(.vertical, 4)

                // Debug: Reset button right on completed view
                Button("Reset & Start Over") {
                    resetAllProgress()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .font(.caption2)
            }
            .padding()
        }
    }

    private func resetAllProgress() {
        // Force clear all data
        currentDay = 1
        completedDaysData = Data()
        questions = []
        currentQuestionIndex = 0
        responses = [:]
        showingQuestions = false
        isLoading = false

        // Clear UserDefaults directly as backup
        UserDefaults.standard.removeObject(forKey: "watchCurrentDay")
        UserDefaults.standard.removeObject(forKey: "watchCompletedDays")
        UserDefaults.standard.synchronize()

        WKInterfaceDevice.current().play(.success)
    }

    private var noQuestionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.primary)

            Text("Day \(currentDay)")
                .font(.headline)

            Text("Ready to start")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Begin") {
                loadQuestions()
                showingQuestions = true
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .padding()
    }

    @ViewBuilder
    private func questionInputView(for question: WatchQuestion) -> some View {
        switch question.type {
        case .scale:
            VStack(spacing: 4) {
                Text(String(format: "%.0f", responses[question.id] as? Double ?? 5.0))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primary)

                Slider(value: Binding(
                    get: { responses[question.id] as? Double ?? 5.0 },
                    set: { responses[question.id] = $0 }
                ), in: 1...10, step: 1)
                .tint(theme.primary)
            }

        case .radio:
            if let options = question.options {
                VStack(spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            responses[question.id] = option
                        }) {
                            HStack {
                                Image(systemName: responses[question.id] as? String == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(responses[question.id] as? String == option ? theme.primary : .secondary)
                                    .font(.caption)
                                Text(option)
                                    .font(.caption2)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(responses[question.id] as? String == option ? theme.primary : .primary)
                    }
                }
            }

        case .checkbox:
            if let options = question.options {
                VStack(spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            toggleCheckboxOption(question.id, option: option)
                        }) {
                            HStack {
                                Image(systemName: isOptionSelected(question.id, option: option) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(isOptionSelected(question.id, option: option) ? theme.primary : .secondary)
                                    .font(.caption)
                                Text(option)
                                    .font(.caption2)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(isOptionSelected(question.id, option: option) ? theme.primary : .primary)
                    }
                }
            }

        case .text:
            TextField("Answer", text: Binding(
                get: { responses[question.id] as? String ?? "" },
                set: { responses[question.id] = $0 }
            ))
            .textFieldStyle(.automatic)

        case .time:
            WatchTimePickerView(
                selectedTime: Binding(
                    get: {
                        if let dateValue = responses[question.id] as? Date {
                            return dateValue
                        }
                        return Date()
                    },
                    set: { responses[question.id] = $0 }
                ),
                theme: theme
            )

        case .yesNo:
            HStack(spacing: 12) {
                Button("Yes") {
                    responses[question.id] = "Yes"
                }
                .buttonStyle(.bordered)
                .tint(responses[question.id] as? String == "Yes" ? theme.primary : .gray)

                Button("No") {
                    responses[question.id] = "No"
                }
                .buttonStyle(.bordered)
                .tint(responses[question.id] as? String == "No" ? theme.primary : .gray)
            }

        case .number:
            VStack(spacing: 4) {
                Text("\(Int(responses[question.id] as? Double ?? 0))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primary)

                Slider(value: Binding(
                    get: { responses[question.id] as? Double ?? 0 },
                    set: { responses[question.id] = $0 }
                ), in: 0...20, step: 1)
                .tint(theme.primary)
            }
        }
    }

    private func loadCurrentDay() {
        // Load questions for current day directly (standalone mode)
        loadQuestions()
        isLoading = false
    }

    private func loadQuestions() {
        // Built-in Stanford Sleep Log questions for Watch
        questions = WatchQuestionBank.getQuestionsForDay(currentDay)
        currentQuestionIndex = 0
        responses = [:]
    }

    private func isCurrentQuestionAnswered() -> Bool {
        guard currentQuestionIndex < questions.count else { return false }
        let question = questions[currentQuestionIndex]

        // Time, scale, and number questions are always "answered" (have default values)
        if question.type == .time || question.type == .scale || question.type == .number {
            return true
        }

        return responses[question.id] != nil
    }

    private func completeQuestionnaire() {
        // Mark day as completed locally
        var days = completedDays
        if !days.contains(currentDay) {
            days.append(currentDay)
            if let encoded = try? JSONEncoder().encode(days) {
                completedDaysData = encoded
            }
        }

        // Try to sync to iPhone if connected
        watchConnectivity.sendResponses(responses, forDay: currentDay) { _ in }

        // Show completion
        showingQuestions = false
        questions = []

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
    }

    private func toggleCheckboxOption(_ questionId: String, option: String) {
        var selectedOptions = responses[questionId] as? [String] ?? []
        if selectedOptions.contains(option) {
            selectedOptions.removeAll { $0 == option }
        } else {
            selectedOptions.append(option)
        }
        responses[questionId] = selectedOptions
    }

    private func isOptionSelected(_ questionId: String, option: String) -> Bool {
        let selectedOptions = responses[questionId] as? [String] ?? []
        return selectedOptions.contains(option)
    }
}

// MARK: - Watch Question Model

struct WatchQuestion {
    let id: String
    let text: String
    let type: WatchQuestionType
    let options: [String]?

    init(id: String, text: String, type: WatchQuestionType, options: [String]? = nil) {
        self.id = id
        self.text = text
        self.type = type
        self.options = options
    }
}

enum WatchQuestionType: String, CaseIterable {
    case text
    case radio
    case checkbox
    case scale
    case time
    case yesNo
    case number
}

// MARK: - Watch Question Bank (Built-in Questions)

struct WatchQuestionBank {

    // Stanford Sleep Log - asked every day
    static let sleepLogQuestions: [WatchQuestion] = [
        WatchQuestion(
            id: "SL_BEDTIME",
            text: "What time did you go to bed last night?",
            type: .time
        ),
        WatchQuestion(
            id: "SL_ASLEEP_TIME",
            text: "What time did you fall asleep?",
            type: .time
        ),
        WatchQuestion(
            id: "SL_AWAKENINGS",
            text: "How many times did you wake up?",
            type: .number
        ),
        WatchQuestion(
            id: "SL_WAKE_TIME",
            text: "What time did you wake up this morning?",
            type: .time
        ),
        WatchQuestion(
            id: "SL_QUALITY",
            text: "Rate your sleep quality (1-10)",
            type: .scale
        ),
        WatchQuestion(
            id: "SL_REFRESHED",
            text: "How refreshed do you feel? (1-10)",
            type: .scale
        )
    ]

    // Day-specific additional questions
    static let day1Questions: [WatchQuestion] = [
        WatchQuestion(
            id: "D1_SLEEP_PROBLEM",
            text: "Do you have trouble sleeping?",
            type: .yesNo
        ),
        WatchQuestion(
            id: "D1_CAFFEINE",
            text: "Do you consume caffeine?",
            type: .yesNo
        )
    ]

    static let day2Questions: [WatchQuestion] = [
        WatchQuestion(
            id: "D2_NAPS",
            text: "Do you take naps during the day?",
            type: .yesNo
        ),
        WatchQuestion(
            id: "D2_EXERCISE",
            text: "Do you exercise regularly?",
            type: .yesNo
        )
    ]

    static let day3Questions: [WatchQuestion] = [
        WatchQuestion(
            id: "D3_SCREENS",
            text: "Do you use screens before bed?",
            type: .yesNo
        ),
        WatchQuestion(
            id: "D3_STRESS",
            text: "Rate your stress level (1-10)",
            type: .scale
        )
    ]

    static func getQuestionsForDay(_ day: Int) -> [WatchQuestion] {
        var questions = sleepLogQuestions

        switch day {
        case 1:
            questions.append(contentsOf: day1Questions)
        case 2:
            questions.append(contentsOf: day2Questions)
        case 3:
            questions.append(contentsOf: day3Questions)
        default:
            // Days 4+ just use sleep log for now
            break
        }

        return questions
    }
}

// MARK: - Watch Time Picker View

struct WatchTimePickerView: View {
    @Binding var selectedTime: Date
    let theme: WatchColorTheme

    @State private var hour: Int = 12
    @State private var minute: Int = 0

    private let hours = Array(0...23)
    private let minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    var body: some View {
        VStack(spacing: 2) {
            // Display current selection - larger and prominent
            Text(formattedTime)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.primary)

            // Compact hour and minute pickers
            HStack(spacing: 0) {
                // Hour picker
                Picker("Hour", selection: $hour) {
                    ForEach(hours, id: \.self) { h in
                        Text(String(format: "%02d", h))
                            .font(.system(size: 16))
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 45, height: 50)
                .clipped()

                Text(":")
                    .font(.system(size: 16, weight: .bold))

                // Minute picker
                Picker("Minute", selection: $minute) {
                    ForEach(minutes, id: \.self) { m in
                        Text(String(format: "%02d", m))
                            .font(.system(size: 16))
                            .tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 45, height: 50)
                .clipped()
            }
        }
        .onAppear {
            let calendar = Calendar.current
            hour = calendar.component(.hour, from: selectedTime)
            let currentMinute = calendar.component(.minute, from: selectedTime)
            // Round to nearest 5
            minute = (currentMinute / 5) * 5
        }
        .onChange(of: hour) { _, _ in
            updateSelectedTime()
        }
        .onChange(of: minute) { _, _ in
            updateSelectedTime()
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: selectedTime)
    }

    private func updateSelectedTime() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        if let newDate = Calendar.current.date(from: components) {
            selectedTime = newDate
        }
    }
}

// MARK: - Color Extension for Watch

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    QuestionnaireView()
        .environmentObject(WatchConnectivityManager())
}
