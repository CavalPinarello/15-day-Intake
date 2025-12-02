//
//  QuestionComponents.swift
//  Zoe Sleep for Longevity System
//
//  Reusable UI components for different question types
//

import SwiftUI

// MARK: - Question Card Container

struct QuestionCard<Content: View>: View {
    let question: Question
    let content: () -> Content
    var theme: ColorTheme = ColorTheme.shared

    init(question: Question, theme: ColorTheme = ColorTheme.shared, @ViewBuilder content: @escaping () -> Content) {
        self.question = question
        self.theme = theme
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pillar badge
            HStack {
                Text(question.pillar.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(question.pillar.themeColor)
                    .cornerRadius(4)

                Spacer()

                if question.required {
                    Text("Required")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Question text
            Text(question.text)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Help text
            if let helpText = question.helpText {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(theme.primary)
                        .font(.caption)
                    Text(helpText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(theme.backgroundTint)
                .cornerRadius(8)
            }

            // Answer content
            content()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Scale Input

struct ScaleInput: View {
    let question: Question
    @Binding var value: Double
    var theme: ColorTheme = ColorTheme.shared
    @State private var hasSetInitialValue = false

    // Smart default values for scale questions
    private var smartDefaultValue: Double {
        let minVal = Double(question.scaleMin ?? 1)
        let maxVal = Double(question.scaleMax ?? 10)

        switch question.id {
        // Sleep quality (1-10) - neutral/slightly good
        case "SL_QUALITY", "1":
            return 6
        default:
            // Smart inference based on question text
            let lowerText = question.text.lowercased()
            if lowerText.contains("quality") && lowerText.contains("sleep") {
                return 6  // Sleep quality - neutral
            } else if lowerText.contains("stress") {
                return 5  // Stress level - moderate
            } else if lowerText.contains("pain") {
                return 2  // Pain level - low (optimistic)
            } else if lowerText.contains("energy") || lowerText.contains("refreshed") {
                return 6  // Energy/refreshed - neutral
            }
            // Default to middle of range
            return (minVal + maxVal) / 2
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(question.scaleMinLabel ?? "\(question.scaleMin ?? 0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(question.scaleMaxLabel ?? "\(question.scaleMax ?? 10)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Slider(
                value: $value,
                in: Double(question.scaleMin ?? 1)...Double(question.scaleMax ?? 10),
                step: 1
            )
            .accentColor(question.pillar.themeColor)

            Text("\(Int(value))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(question.pillar.themeColor)
        }
        .onAppear {
            // Only set smart default once on first appear
            if !hasSetInitialValue {
                hasSetInitialValue = true
                let smartDefault = smartDefaultValue
                // Ensure within bounds
                let minVal = Double(question.scaleMin ?? 1)
                let maxVal = Double(question.scaleMax ?? 10)
                value = min(max(smartDefault, minVal), maxVal)
            }
        }
    }
}

// MARK: - Yes/No Input

struct YesNoInput: View {
    let question: Question
    @Binding var value: String
    var theme: ColorTheme = ColorTheme.shared

    private var pillarColor: Color { question.pillar.themeColor }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(getOptions(), id: \.self) { option in
                Button(action: { value = option }) {
                    Text(option)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(value == option ? pillarColor.opacity(0.2) : Color(.secondarySystemBackground))
                        .foregroundColor(value == option ? pillarColor : .primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(value == option ? pillarColor : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func getOptions() -> [String] {
        switch question.questionType {
        case .yesNo:
            return ["Yes", "No"]
        case .yesNoDontKnow:
            return ["Yes", "No", "Don't know"]
        default:
            return ["Yes", "No"]
        }
    }
}

// MARK: - Single Select Input

struct SingleSelectInput: View {
    let question: Question
    @Binding var value: String
    var theme: ColorTheme = ColorTheme.shared

    private var pillarColor: Color { question.pillar.themeColor }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(question.options ?? [], id: \.self) { option in
                Button(action: { value = option }) {
                    HStack {
                        Text(option)
                            .font(.subheadline)
                        Spacer()
                        if value == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(pillarColor)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(value == option ? pillarColor.opacity(0.1) : Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Multi Select Input

struct MultiSelectInput: View {
    let question: Question
    @Binding var values: [String]
    var theme: ColorTheme = ColorTheme.shared

    private var pillarColor: Color { question.pillar.themeColor }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(question.options ?? [], id: \.self) { option in
                Button(action: { toggleOption(option) }) {
                    HStack {
                        Text(option)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: values.contains(option) ? "checkmark.square.fill" : "square")
                            .foregroundColor(values.contains(option) ? pillarColor : .secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(values.contains(option) ? pillarColor.opacity(0.1) : Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleOption(_ option: String) {
        if let index = values.firstIndex(of: option) {
            values.remove(at: index)
        } else {
            values.append(option)
        }
    }
}

// MARK: - Number Input

struct NumberInput: View {
    let question: Question
    @Binding var value: Double
    var theme: ColorTheme = ColorTheme.shared
    @State private var hasSetInitialValue = false

    private var pillarColor: Color { question.pillar.themeColor }

    // Smart default values based on question context
    private var smartDefaultValue: Double {
        switch question.id {
        // Demographics
        case "D1":
            return 35    // Age - median adult
        case "D5":
            return 170   // Height in cm - average
        case "D6":
            return 70    // Weight in kg - average
        // Sleep-related
        case "SL_AWAKENINGS":
            return 1     // Night awakenings - typical
        case "PSQI_2":
            return 15    // Time to fall asleep (minutes)
        case "PSQI_4":
            return 7     // Hours of actual sleep
        default:
            // Smart inference based on question text
            let lowerText = question.text.lowercased()
            if lowerText.contains("age") {
                return 35
            } else if lowerText.contains("height") {
                return 170
            } else if lowerText.contains("weight") {
                return 70
            } else if lowerText.contains("wake") && lowerText.contains("times") {
                return 1
            } else if lowerText.contains("hours") && lowerText.contains("sleep") {
                return 7
            } else if lowerText.contains("minutes") && (lowerText.contains("fall asleep") || lowerText.contains("latency")) {
                return 15
            } else if lowerText.contains("caffeine") || lowerText.contains("coffee") {
                return 2
            } else if lowerText.contains("screen") && lowerText.contains("hours") {
                return 6
            }
            // Default to middle of range or explicit defaultValue
            if let defaultVal = question.defaultValue {
                return Double(defaultVal)
            }
            let minVal = Double(question.minValue ?? 0)
            let maxVal = Double(question.maxValue ?? 100)
            return (minVal + maxVal) / 2
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(question.minValue ?? 0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let unit = question.unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(question.maxValue ?? 100)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                Button(action: { decrementValue() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(pillarColor)
                }
                .disabled(value <= Double(question.minValue ?? 0))

                Text(formatValue())
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(minWidth: 80)

                Button(action: { incrementValue() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(pillarColor)
                }
                .disabled(value >= Double(question.maxValue ?? 100))
            }
        }
        .onAppear {
            // Only set smart default once on first appear
            if !hasSetInitialValue {
                hasSetInitialValue = true
                let smartDefault = smartDefaultValue
                // Ensure within bounds
                let minVal = Double(question.minValue ?? 0)
                let maxVal = Double(question.maxValue ?? 100)
                value = min(max(smartDefault, minVal), maxVal)
            }
        }
    }

    private func formatValue() -> String {
        let step = question.step ?? 1
        if step < 1 {
            return String(format: "%.1f", value)
        }
        return "\(Int(value))"
    }

    private func incrementValue() {
        let step = question.step ?? 1
        let maxValue = Double(question.maxValue ?? 100)
        value = min(value + step, maxValue)
    }

    private func decrementValue() {
        let step = question.step ?? 1
        let minValue = Double(question.minValue ?? 0)
        value = max(value - step, minValue)
    }
}

// MARK: - Time Input

struct TimeInput: View {
    let question: Question
    @Binding var value: Date
    var previousBedtime: Date? = nil  // Used to calculate smart defaults for wake/asleep times
    @ObservedObject private var themeManager = ThemeManager.shared

    // Smart default times based on question context and previous answers
    private var smartDefaultTime: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.minute = 0

        switch question.id {
        // Stanford Sleep Log questions
        case "SL_BEDTIME":
            components.hour = 22  // 10:00 PM - typical bedtime

        case "SL_ASLEEP_TIME":
            // If we have a bedtime answer, default to 15-30 min after
            if let bedtime = previousBedtime {
                return calendar.date(byAdding: .minute, value: 15, to: bedtime) ?? bedtime
            }
            components.hour = 22  // 10:30 PM - slightly after bedtime
            components.minute = 30

        case "SL_WAKE_TIME":
            // If we have a bedtime answer, default to ~8 hours after
            if let bedtime = previousBedtime {
                return calendar.date(byAdding: .hour, value: 8, to: bedtime) ?? Date()
            }
            components.hour = 7   // 7:00 AM - typical wake time

        // PSQI questions
        case "PSQI_1":
            components.hour = 22  // 10:30 PM - usual bedtime
            components.minute = 30
        case "PSQI_3":
            // If we have PSQI_1 (bedtime) answer, default to ~8 hours after
            if let bedtime = previousBedtime {
                return calendar.date(byAdding: .hour, value: 8, to: bedtime) ?? Date()
            }
            components.hour = 7   // 7:00 AM - usual wake time

        default:
            // Smart inference based on question text
            let lowerText = question.text.lowercased()
            if lowerText.contains("wake") || lowerText.contains("morning") || lowerText.contains("get up") {
                // Wake-related: use bedtime + 8 hours if available
                if let bedtime = previousBedtime {
                    return calendar.date(byAdding: .hour, value: 8, to: bedtime) ?? Date()
                }
                components.hour = 7   // 7:00 AM for wake-related
            } else if lowerText.contains("fall asleep") || lowerText.contains("fell asleep") {
                // Fall asleep: use bedtime + 15 min if available
                if let bedtime = previousBedtime {
                    return calendar.date(byAdding: .minute, value: 15, to: bedtime) ?? bedtime
                }
                components.hour = 22  // 10:30 PM for fall asleep
                components.minute = 30
            } else if lowerText.contains("bed") || lowerText.contains("sleep") || lowerText.contains("night") {
                components.hour = 22  // 10:00 PM for bedtime-related
            } else {
                components.hour = 12  // Noon for unknown
            }
        }

        return calendar.date(from: components) ?? Date()
    }

    var body: some View {
        VStack(spacing: 8) {
            DatePicker(
                "",
                selection: $value,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: themeManager.largeIconsMode ? 180 : 150)
            .scaleEffect(themeManager.largeIconsMode ? 1.15 : 1.0)
        }
        .id(question.id) // Force view recreation when question changes
        .onAppear {
            // Always set smart default when view appears for this question
            value = smartDefaultTime
        }
    }
}

// MARK: - Date Input

struct DateInputView: View {
    let question: Question
    @Binding var value: Date

    var body: some View {
        DatePicker(
            "",
            selection: $value,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
    }
}

// MARK: - Text Input

struct TextInputView: View {
    let question: Question
    @Binding var value: String
    var placeholder: String = "Enter your answer"

    var body: some View {
        TextField(placeholder, text: $value)
            .textFieldStyle(.roundedBorder)
            .autocapitalization(question.questionType == .email ? .none : .words)
            .keyboardType(question.questionType == .email ? .emailAddress : .default)
    }
}

// MARK: - Minutes Scroll Picker

struct MinutesScrollPicker: View {
    let question: Question
    @Binding var value: Int

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $value) {
                ForEach((question.minValue ?? 0)...(question.maxValue ?? 180), id: \.self) { minute in
                    Text("\(minute) min")
                        .tag(minute)
                }
                if let specialValue = question.specialValue, let specialLabel = question.specialLabel {
                    Text(specialLabel)
                        .tag(specialValue)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
    }
}

// MARK: - Info Card (for messages)

struct InfoCard: View {
    let question: Question
    var theme: ColorTheme = ColorTheme.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(theme.success)
                .font(.title2)

            Text(question.text)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(16)
        .background(theme.success.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Sleep Log Summary Card

struct SleepLogSummaryCard: View {
    let healthKitSummary: HealthKitSleepSummary?
    let userResponses: [String: QuestionResponse]
    var theme: ColorTheme = ColorTheme.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Comparison")
                .font(.headline)

            HStack {
                // User perception
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Perception")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let bedtime = userResponses["SL_BEDTIME"]?.stringValue {
                        Label(bedtime, systemImage: "bed.double")
                            .font(.subheadline)
                    }
                    if let wakeTime = userResponses["SL_WAKE_TIME"]?.stringValue {
                        Label(wakeTime, systemImage: "sun.max")
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 60)

                // HealthKit data
                VStack(alignment: .leading, spacing: 8) {
                    Text("HealthKit Data")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let summary = healthKitSummary {
                        if let bedtime = summary.formattedInBedTime {
                            Label(bedtime, systemImage: "bed.double")
                                .font(.subheadline)
                        }
                        if let wakeTime = summary.formattedWakeTime {
                            Label(wakeTime, systemImage: "sun.max")
                                .font(.subheadline)
                        }
                    } else {
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(theme.sleepDiary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Progress Header

struct QuestionnaireProgressHeader: View {
    let currentIndex: Int
    let totalQuestions: Int
    let dayNumber: Int
    let pillarColor: Color
    var theme: ColorTheme = ColorTheme.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Day \(dayNumber)")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(currentIndex + 1) of \(totalQuestions)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(currentIndex + 1), total: Double(totalQuestions))
                .progressViewStyle(LinearProgressViewStyle(tint: pillarColor))
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Gateway Alert Banner

struct GatewayAlertBanner: View {
    let gatewayType: GatewayType
    let isTriggered: Bool
    var theme: ColorTheme = ColorTheme.shared

    var body: some View {
        if isTriggered {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(theme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(gatewayType.displayName) Assessment Triggered")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Additional questions will be added to your journey")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(theme.warning.opacity(0.15))
            .cornerRadius(8)
        }
    }
}

// Note: Color extension for hex is defined in QuestionModels.swift
