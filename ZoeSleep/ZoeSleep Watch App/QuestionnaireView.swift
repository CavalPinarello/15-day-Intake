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
    @StateObject private var convexService = WatchConvexService.shared

    // Local storage for offline capability
    @AppStorage("watchCurrentDay") private var localCurrentDay: Int = 1
    @AppStorage("watchCompletedDays") private var completedDaysData: Data = Data()

    @State private var questions: [WatchQuestion] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var responses: [String: Any] = [:]
    @State private var isLoading = true
    @State private var showingQuestions = false
    @State private var isSyncing = false
    @State private var syncError: String?

    private var theme: WatchColorTheme { WatchColorTheme.shared }

    // Use Convex state if authenticated, otherwise local state
    private var currentDay: Int {
        convexService.isAuthenticated ? convexService.currentDay : localCurrentDay
    }

    private var completedDays: [Int] {
        if convexService.isAuthenticated {
            return convexService.completedDays
        }
        return (try? JSONDecoder().decode([Int].self, from: completedDaysData)) ?? []
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
        GeometryReader { geometry in
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    // Progress bar inline - very compact
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 3)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(theme.primary)
                                    .frame(width: max(0, (geometry.size.width - 40) * CGFloat(currentQuestionIndex + 1) / CGFloat(max(1, questions.count))), height: 3)
                            }

                        Text("\(currentQuestionIndex + 1)/\(questions.count)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 2)

                    if currentQuestionIndex < questions.count {
                        let question = questions[currentQuestionIndex]

                        // Question text - compact
                        Text(question.text)
                            .font(.system(size: 13, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)
                            .padding(.top, 2)

                        // Answer input area - leave room for nav buttons (28pt)
                        questionInputView(for: question)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 32)
                    }

                    Spacer(minLength: 0)
                }

                // Navigation buttons - anchored to bottom corners
                if currentQuestionIndex < questions.count {
                    VStack {
                        Spacer()
                        HStack {
                            // Back button (left)
                            if currentQuestionIndex > 0 {
                                Button {
                                    currentQuestionIndex -= 1
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(theme.primary)
                                }
                                .frame(width: 36, height: 28)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }

                            Spacer()

                            // Next/Done button (right)
                            Button {
                                if currentQuestionIndex == questions.count - 1 {
                                    completeQuestionnaire()
                                } else {
                                    currentQuestionIndex += 1
                                }
                            } label: {
                                if currentQuestionIndex == questions.count - 1 {
                                    Text("Done")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(width: currentQuestionIndex == questions.count - 1 ? 50 : 36, height: 28)
                            .background(theme.primary)
                            .cornerRadius(8)
                            .disabled(!isCurrentQuestionAnswered())
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 2)
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
        // Force clear all local data
        localCurrentDay = 1
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

        // Sync reset to Convex in background
        Task {
            await syncResetToConvex()
        }

        // Also notify iPhone via WatchConnectivity
        watchConnectivity.resetJourneyProgress { _, _ in }
    }

    private func syncResetToConvex() async {
        guard convexService.isAuthenticated else {
            print("[Watch] Not authenticated - reset saved locally only")
            return
        }

        do {
            let result = try await convexService.resetProgress()
            print("[Watch] Reset synced to Convex, new day: \(result.newDay)")
        } catch {
            print("[Watch] Failed to sync reset to Convex: \(error.localizedDescription)")
        }
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
            // Scale 1-10 with large value display and easy slider
            VStack(spacing: 6) {
                Text(String(format: "%.0f", responses[question.id] as? Double ?? 5.0))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primary)

                // Scale labels
                HStack {
                    Text("1")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("10")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)

                Slider(value: Binding(
                    get: { responses[question.id] as? Double ?? 5.0 },
                    set: { responses[question.id] = $0 }
                ), in: 1...10, step: 1)
                .tint(theme.primary)
            }
            .padding(.horizontal, 4)

        case .radio:
            if let options = question.options {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                responses[question.id] = option
                                WKInterfaceDevice.current().play(.click)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: responses[question.id] as? String == option ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(responses[question.id] as? String == option ? theme.primary : .secondary)
                                    Text(option)
                                        .font(.system(size: 14))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(responses[question.id] as? String == option ? theme.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        case .checkbox:
            if let options = question.options {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                toggleCheckboxOption(question.id, option: option)
                                WKInterfaceDevice.current().play(.click)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: isOptionSelected(question.id, option: option) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 18))
                                        .foregroundColor(isOptionSelected(question.id, option: option) ? theme.primary : .secondary)
                                    Text(option)
                                        .font(.system(size: 14))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isOptionSelected(question.id, option: option) ? theme.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        case .text:
            TextField("Answer", text: Binding(
                get: { responses[question.id] as? String ?? "" },
                set: { responses[question.id] = $0 }
            ))
            .textFieldStyle(.automatic)
            .font(.system(size: 16))

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
            // Large, easy-to-tap Yes/No buttons
            HStack(spacing: 16) {
                Button {
                    responses[question.id] = "Yes"
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("Yes")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(responses[question.id] as? String == "Yes" ? theme.primary : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(responses[question.id] as? String == "Yes" ? .black : .primary)
                }
                .buttonStyle(.plain)

                Button {
                    responses[question.id] = "No"
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("No")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(responses[question.id] as? String == "No" ? theme.primary : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(responses[question.id] as? String == "No" ? .black : .primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

        case .number:
            // Number input with large display and +/- buttons for easier control
            VStack(spacing: 6) {
                Text("\(Int(responses[question.id] as? Double ?? 0))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primary)

                // +/- stepper buttons
                HStack(spacing: 20) {
                    Button {
                        let current = responses[question.id] as? Double ?? 0
                        if current > 0 {
                            responses[question.id] = current - 1
                            WKInterfaceDevice.current().play(.click)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(theme.primary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        let current = responses[question.id] as? Double ?? 0
                        if current < 20 {
                            responses[question.id] = current + 1
                            WKInterfaceDevice.current().play(.click)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(theme.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadCurrentDay() {
        // Try to sync with Convex first
        Task {
            await syncWithConvex()
            await MainActor.run {
                loadQuestions()
                isLoading = false
            }
        }
    }

    private func syncWithConvex() async {
        // If not authenticated, try to auto-login with saved credentials
        if !convexService.isAuthenticated {
            // Check if we have saved credentials from previous session
            if let savedUsername = UserDefaults.standard.string(forKey: "lastUsername") {
                // For now, just mark as not authenticated - user needs to login via iPhone
                print("[Watch] Not authenticated - user should login via iPhone first")
            }
            return
        }

        do {
            let state = try await convexService.fetchJourneyState()
            await MainActor.run {
                // Update local storage to match Convex
                localCurrentDay = state.currentDay
                if let encoded = try? JSONEncoder().encode(state.completedDays) {
                    completedDaysData = encoded
                }
            }
            print("[Watch] Synced with Convex: Day \(state.currentDay), Completed: \(state.completedDays)")
        } catch {
            print("[Watch] Failed to sync with Convex: \(error.localizedDescription)")
            // Continue with local data
        }
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
        let dayToComplete = currentDay

        // Mark day as completed locally first (for offline support)
        var days = completedDays
        if !days.contains(dayToComplete) {
            days.append(dayToComplete)
            if let encoded = try? JSONEncoder().encode(days) {
                completedDaysData = encoded
            }
        }

        // Show completion immediately
        showingQuestions = false
        questions = []

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)

        // Sync to Convex in background
        Task {
            await syncCompletionToConvex(dayNumber: dayToComplete)
        }

        // Also try to sync to iPhone via WatchConnectivity
        watchConnectivity.sendResponses(responses, forDay: dayToComplete) { _ in }
    }

    private func syncCompletionToConvex(dayNumber: Int) async {
        guard convexService.isAuthenticated else {
            print("[Watch] Not authenticated - completion saved locally only")
            return
        }

        do {
            // First save all responses
            var convexResponses: [[String: Any]] = []
            for (questionId, value) in responses {
                var response: [String: Any] = ["questionId": questionId]

                if let stringValue = value as? String {
                    response["responseValue"] = stringValue
                } else if let numberValue = value as? Double {
                    response["responseNumber"] = numberValue
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

            if !convexResponses.isEmpty {
                _ = try await convexService.saveResponses(dayNumber: dayNumber, responses: convexResponses)
                print("[Watch] Saved \(convexResponses.count) responses to Convex")
            }

            // Then mark day as complete
            let result = try await convexService.completeDay(dayNumber: dayNumber)
            print("[Watch] Day \(dayNumber) marked complete in Convex, new day: \(result.newDay)")

            // Update local state to match
            await MainActor.run {
                localCurrentDay = result.newDay
            }
        } catch {
            print("[Watch] Failed to sync completion to Convex: \(error.localizedDescription)")
            // Local state is already updated, so user experience is preserved
        }
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
        VStack(spacing: 4) {
            // Display current selection - large and prominent
            Text(formattedTime)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.primary)

            // Large, easy-to-use pickers
            HStack(spacing: 6) {
                Picker("Hour", selection: $hour) {
                    ForEach(hours, id: \.self) { h in
                        Text(String(format: "%02d", h))
                            .font(.system(size: 20, weight: .semibold))
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 65)
                .clipped()

                Text(":")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.secondary)

                Picker("Minute", selection: $minute) {
                    ForEach(minutes, id: \.self) { m in
                        Text(String(format: "%02d", m))
                            .font(.system(size: 20, weight: .semibold))
                            .tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 65)
                .clipped()
            }
        }
        .onAppear {
            let calendar = Calendar.current
            hour = calendar.component(.hour, from: selectedTime)
            let currentMinute = calendar.component(.minute, from: selectedTime)
            minute = (currentMinute / 5) * 5
        }
        .onChange(of: hour) { _, _ in
            updateSelectedTime()
            WKInterfaceDevice.current().play(.click)
        }
        .onChange(of: minute) { _, _ in
            updateSelectedTime()
            WKInterfaceDevice.current().play(.click)
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
