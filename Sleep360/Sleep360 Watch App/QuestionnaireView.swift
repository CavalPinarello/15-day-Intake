//
//  QuestionnaireView.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Watch-optimized questionnaire interface for 15-day intake journey
//

import SwiftUI
import WatchKit

struct QuestionnaireView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State private var currentDay: Int = 1
    @State private var questions: [Question] = []
    @State private var currentQuestionIndex: Int = 0
    @State private var responses: [String: Any] = [:]
    @State private var isLoading = true

    private var theme: WatchColorTheme { WatchColorTheme.shared }

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                        .tint(theme.primary)
                        .onAppear {
                            loadCurrentDay()
                        }
                } else if questions.isEmpty {
                    completedView
                } else {
                    questionnaireContent
                }
            }
            .navigationTitle("Day \(currentDay)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var questionnaireContent: some View {
        VStack(spacing: 12) {
            // Progress indicator
            ProgressView(value: Double(currentQuestionIndex), total: Double(questions.count))
                .progressViewStyle(LinearProgressViewStyle(tint: theme.primary))
                .padding(.horizontal)

            Text("\(currentQuestionIndex + 1) of \(questions.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            // Current question
            if currentQuestionIndex < questions.count {
                let question = questions[currentQuestionIndex]

                ScrollView {
                    VStack(spacing: 16) {
                        Text(question.text)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        questionInputView(for: question)
                    }
                }

                // Navigation buttons
                HStack {
                    if currentQuestionIndex > 0 {
                        Button("Back") {
                            currentQuestionIndex -= 1
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button(currentQuestionIndex == questions.count - 1 ? "Complete" : "Next") {
                        if currentQuestionIndex == questions.count - 1 {
                            completeQuestionnaire()
                        } else {
                            currentQuestionIndex += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary)
                    .disabled(!isCurrentQuestionAnswered())
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.success)

            Text("Day \(currentDay) Complete!")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Great job! Your responses have been saved.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Next Day") {
                advanceToNextDay()
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .padding()
    }

    @ViewBuilder
    private func questionInputView(for question: Question) -> some View {
        switch question.type {
        case .scale:
            VStack {
                Text("Rate from 1-10")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { responses[question.id] as? Double ?? 5.0 },
                    set: { responses[question.id] = $0 }
                ), in: 1...10, step: 1)
                .tint(theme.primary)

                Text("\(Int(responses[question.id] as? Double ?? 5.0))")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.primary)
            }

        case .radio:
            if let options = question.options {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            responses[question.id] = option
                        }) {
                            HStack {
                                Image(systemName: responses[question.id] as? String == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(responses[question.id] as? String == option ? theme.primary : .secondary)
                                Text(option)
                                    .font(.caption)
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
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            toggleCheckboxOption(option)
                        }) {
                            HStack {
                                Image(systemName: isOptionSelected(option) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(isOptionSelected(option) ? theme.primary : .secondary)
                                Text(option)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(isOptionSelected(option) ? theme.primary : .primary)
                    }
                }
            }

        case .text:
            TextField("Your answer", text: Binding(
                get: { responses[question.id] as? String ?? "" },
                set: { responses[question.id] = $0 }
            ))
            .textFieldStyle(.automatic)

        default:
            Text("Question type not supported on Watch")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    private func loadCurrentDay() {
        // Request current day and questions from iPhone via WatchConnectivity
        watchConnectivity.requestCurrentDayQuestions { day, questionsList in
            DispatchQueue.main.async {
                self.currentDay = day
                self.questions = questionsList
                self.isLoading = false
            }
        }
    }
    
    private func isCurrentQuestionAnswered() -> Bool {
        guard currentQuestionIndex < questions.count else { return false }
        let question = questions[currentQuestionIndex]
        return responses[question.id] != nil
    }
    
    private func completeQuestionnaire() {
        // Send responses to iPhone and Convex
        watchConnectivity.sendResponses(responses, forDay: currentDay) { success in
            DispatchQueue.main.async {
                if success {
                    // Clear questions to show completion view
                    self.questions = []
                }
            }
        }
    }
    
    private func advanceToNextDay() {
        watchConnectivity.advanceDay { newDay in
            DispatchQueue.main.async {
                self.currentDay = newDay
                self.responses = [:]
                self.currentQuestionIndex = 0
                self.loadCurrentDay()
            }
        }
    }
    
    private func toggleCheckboxOption(_ option: String) {
        var selectedOptions = responses[questions[currentQuestionIndex].id] as? [String] ?? []
        if selectedOptions.contains(option) {
            selectedOptions.removeAll { $0 == option }
        } else {
            selectedOptions.append(option)
        }
        responses[questions[currentQuestionIndex].id] = selectedOptions
    }
    
    private func isOptionSelected(_ option: String) -> Bool {
        let selectedOptions = responses[questions[currentQuestionIndex].id] as? [String] ?? []
        return selectedOptions.contains(option)
    }
}

// Question model for watch app
struct Question {
    let id: String
    let text: String
    let type: QuestionType
    let options: [String]?

    enum QuestionType: String, CaseIterable {
        case text
        case radio
        case checkbox
        case scale
        case time
        case date

        // Note: Some question types like textarea, number, select are handled by iPhone app
        // Watch focuses on quick interaction types
    }
}

// MARK: - Time Period Enum

enum WatchTimePeriod {
    case morning    // 5 AM - 12 PM: Bright, energetic
    case afternoon  // 12 PM - 5 PM: Transitioning warmth
    case evening    // 5 PM - 9 PM: Full sunset warmth
    case night      // 9 PM - 5 AM: Deep, calming

    static var current: WatchTimePeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }
}

// MARK: - Watch Color Theme

struct WatchColorTheme {

    static var shared: WatchColorTheme {
        WatchColorTheme(period: WatchTimePeriod.current)
    }

    let period: WatchTimePeriod

    init(period: WatchTimePeriod = .current) {
        self.period = period
    }

    // MARK: - Primary Colors (Time-Based)

    var primary: Color {
        switch period {
        case .morning:
            return Color(hex: "#0EA5E9")!  // Sky blue
        case .afternoon:
            return Color(hex: "#F59E0B")!  // Amber
        case .evening:
            return Color(hex: "#EA580C")!  // Orange
        case .night:
            return Color(hex: "#7C3AED")!  // Purple
        }
    }

    var secondary: Color {
        switch period {
        case .morning:
            return Color(hex: "#38BDF8")!  // Light sky blue
        case .afternoon:
            return Color(hex: "#FBBF24")!  // Golden amber
        case .evening:
            return Color(hex: "#FB923C")!  // Warm orange
        case .night:
            return Color(hex: "#A78BFA")!  // Soft lavender
        }
    }

    // MARK: - Status Colors

    var success: Color {
        Color(hex: "#10B981")!  // Emerald green
    }

    var warning: Color {
        Color(hex: "#F59E0B")!  // Amber
    }

    var error: Color {
        Color(hex: "#EF4444")!  // Red
    }

    // MARK: - Category Colors

    func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "sleep":
            return primary
        case "exercise":
            return success
        case "nutrition":
            return secondary
        case "stress":
            return Color(hex: "#8B5CF6")!  // Purple
        case "environment":
            return Color(hex: "#14B8A6")!  // Teal
        case "medication":
            return Color(hex: "#EF4444")!  // Red
        default:
            return primary
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