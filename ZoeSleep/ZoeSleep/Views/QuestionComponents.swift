//
//  QuestionComponents.swift
//  Zoe Sleep for Longevity System
//
//  Reusable UI components for different question types
//  CIRCADIAN-AWARE: All colors adapt to time of day (warm amber at night)
//

import SwiftUI

// MARK: - Circadian Color Helper

/// Provides circadian-aware colors for question components
/// Evening/Night: Warm amber/orange colors (sleep-safe, no blue light)
/// Morning/Afternoon: Standard system colors
struct CircadianColors {
    static var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    /// Primary text color - high visibility
    static var primary: Color {
        if isEvening {
            return Color(red: 0.996, green: 0.953, blue: 0.780)  // Bright cream #FEF3C7
        } else {
            return Color.primary
        }
    }

    /// Secondary text color - medium visibility
    static var secondary: Color {
        if isEvening {
            return Color(red: 0.988, green: 0.827, blue: 0.302)  // Golden yellow #FCD34D
        } else {
            return Color.secondary
        }
    }

    /// Muted text color - lower visibility but still readable
    static var muted: Color {
        if isEvening {
            return Color(red: 0.961, green: 0.620, blue: 0.043)  // Amber #F59E0B
        } else {
            return Color.secondary.opacity(0.7)
        }
    }

    /// Background for secondary elements
    static var secondaryBackground: Color {
        if isEvening {
            return Color(red: 0.25, green: 0.15, blue: 0.1)  // Dark brown
        } else {
            return Color(.secondarySystemBackground)
        }
    }

    /// Border color
    static var border: Color {
        if isEvening {
            return Color(red: 0.4, green: 0.25, blue: 0.15)  // Warm brown border
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

// MARK: - Question Card Container (Calm, Headspace-inspired)

struct QuestionCard<Content: View>: View {
    let question: Question
    let content: () -> Content
    var theme: ColorTheme = ColorTheme.shared
    @State private var showHelpText = false

    init(question: Question, theme: ColorTheme = ColorTheme.shared, @ViewBuilder content: @escaping () -> Content) {
        self.question = question
        self.theme = theme
        self.content = content
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Question text - large, centered, friendly
            VStack(spacing: Spacing.md) {
                Text(question.text)
                    .font(.system(size: Typography.title2, weight: .semibold, design: .rounded))
                    .foregroundColor(CircadianColors.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Help text - tap to expand
                if let helpText = question.helpText {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showHelpText.toggle()
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: showHelpText ? "questionmark.circle.fill" : "questionmark.circle")
                                .font(.system(size: Typography.subheadline))
                            if showHelpText {
                                Text(helpText)
                                    .font(.system(size: Typography.subheadline, design: .rounded))
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Need help?")
                                    .font(.system(size: Typography.subheadline, design: .rounded))
                            }
                        }
                        .foregroundColor(CircadianColors.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.md)

            // Answer content - ample space
            content()
                .frame(maxWidth: .infinity)
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.extraLarge)
                .fill(CircadianColors.secondaryBackground)
        )
    }
}

// MARK: - Scale Input

struct ScaleInput: View {
    let question: Question
    @Binding var value: Double
    var theme: ColorTheme = ColorTheme.shared
    // NOTE: Smart defaults are now handled by the binding getter in QuestionnaireView
    // This component should NOT set values on appear, as that would incorrectly
    // mark the question as user-interacted before the user actually touches the slider

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(question.scaleMinLabel ?? "\(question.scaleMin ?? 0)")
                    .font(.caption)
                    .foregroundColor(CircadianColors.secondary)
                Spacer()
                Text(question.scaleMaxLabel ?? "\(question.scaleMax ?? 10)")
                    .font(.caption)
                    .foregroundColor(CircadianColors.secondary)
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
        // REMOVED: .onAppear that was setting smart defaults
        // This was causing values to be saved before user interaction
    }

    /// Static helper to compute smart default for a question
    /// Call this from the binding's default parameter
    /// Returns a value relative to the question's actual scale range
    static func smartDefault(for question: Question) -> Double {
        let minVal = Double(question.scaleMin ?? 1)
        let maxVal = Double(question.scaleMax ?? 10)
        let range = maxVal - minVal

        // Helper to convert percentage (0-1) to scale value
        func percentToValue(_ percent: Double) -> Double {
            return minVal + (range * percent)
        }

        // Default to middle of range (50%)
        let middleValue = percentToValue(0.5)

        switch question.id {
        // Known question IDs with specific defaults
        case "SL_QUALITY", "1":
            // Sleep quality - slightly above middle (60%)
            return round(percentToValue(0.6))
        default:
            // Smart inference based on question text
            let lowerText = question.text.lowercased()
            if lowerText.contains("quality") && lowerText.contains("sleep") {
                return round(percentToValue(0.6))  // Sleep quality - slightly above middle
            } else if lowerText.contains("stress") {
                return round(percentToValue(0.5))  // Stress level - middle
            } else if lowerText.contains("pain") {
                return round(percentToValue(0.2))  // Pain level - low (optimistic)
            } else if lowerText.contains("energy") || lowerText.contains("refreshed") {
                return round(percentToValue(0.6))  // Energy/refreshed - slightly above middle
            }
            // Default to middle of range
            return round(middleValue)
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
                        .background(value == option ? pillarColor.opacity(0.2) : CircadianColors.secondaryBackground)
                        .foregroundColor(value == option ? pillarColor : CircadianColors.primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(value == option ? pillarColor : CircadianColors.border, lineWidth: value == option ? 2 : 1)
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
                    .background(value == option ? pillarColor.opacity(0.1) : CircadianColors.secondaryBackground)
                    .foregroundColor(CircadianColors.primary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(value == option ? pillarColor : CircadianColors.border, lineWidth: value == option ? 2 : 1)
                    )
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
                            .foregroundColor(values.contains(option) ? pillarColor : CircadianColors.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(values.contains(option) ? pillarColor.opacity(0.1) : CircadianColors.secondaryBackground)
                    .foregroundColor(CircadianColors.primary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(values.contains(option) ? pillarColor : CircadianColors.border, lineWidth: values.contains(option) ? 2 : 1)
                    )
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
    // NOTE: Smart defaults are now handled by the binding getter in QuestionnaireView
    // This component should NOT set values on appear

    // Get user's measurement preference (reads from OnboardingManager)
    private var useImperial: Bool {
        OnboardingManager.shared.measurementSystem == .imperial && question.unitImperial != nil
    }

    // Computed properties for unit-aware values
    private var currentUnit: String? {
        useImperial ? question.unitImperial : question.unit
    }

    private var currentMinValue: Int {
        useImperial ? (question.minImperial ?? question.minValue ?? 0) : (question.minValue ?? 0)
    }

    private var currentMaxValue: Int {
        useImperial ? (question.maxImperial ?? question.maxValue ?? 100) : (question.maxValue ?? 100)
    }

    private var pillarColor: Color { question.pillar.themeColor }

    /// Static helper to compute smart default for a question
    /// Call this from the binding's default parameter
    static func smartDefault(for question: Question) -> Double {
        // Check if user prefers imperial and question has imperial settings
        let useImperial = OnboardingManager.shared.measurementSystem == .imperial && question.unitImperial != nil

        switch question.id {
        // Demographics
        case "D1":
            return 35    // Age - median adult
        case "D5":
            return useImperial ? 67 : 170   // Height: 5'7" or 170cm
        case "D6":
            return useImperial ? 154 : 70   // Weight: 154lbs or 70kg
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
                return useImperial ? 67 : 170
            } else if lowerText.contains("weight") {
                return useImperial ? 154 : 70
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
            // Use imperial default if available and user prefers imperial
            if useImperial, let imperialDefault = question.defaultImperial {
                return Double(imperialDefault)
            }
            // Default to explicit defaultValue or middle of range
            if let defaultVal = question.defaultValue {
                return Double(defaultVal)
            }
            let minVal = Double(useImperial ? (question.minImperial ?? question.minValue ?? 0) : (question.minValue ?? 0))
            let maxVal = Double(useImperial ? (question.maxImperial ?? question.maxValue ?? 100) : (question.maxValue ?? 100))
            return (minVal + maxVal) / 2
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(currentMinValue)")
                    .font(.caption)
                    .foregroundColor(CircadianColors.secondary)
                Spacer()
                if let unit = currentUnit {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(CircadianColors.secondary)
                }
                Spacer()
                Text("\(currentMaxValue)")
                    .font(.caption)
                    .foregroundColor(CircadianColors.secondary)
            }

            HStack(spacing: 20) {
                Button(action: { decrementValue() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(pillarColor)
                }
                .disabled(value <= Double(currentMinValue))

                Text(formatValue())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(CircadianColors.primary)
                    .frame(minWidth: 80)

                Button(action: { incrementValue() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(pillarColor)
                }
                .disabled(value >= Double(currentMaxValue))
            }
        }
        // REMOVED: .onAppear that was setting smart defaults
        // This was causing values to be saved before user interaction
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
        value = min(value + step, Double(currentMaxValue))
    }

    private func decrementValue() {
        let step = question.step ?? 1
        value = max(value - step, Double(currentMinValue))
    }
}

// MARK: - Time Input

struct TimeInput: View {
    let question: Question
    @Binding var value: Date
    var previousBedtime: Date? = nil  // Used to calculate smart defaults for wake/asleep times
    @ObservedObject private var themeManager = ThemeManager.shared
    // NOTE: Smart defaults are now handled by the dateBinding getter in QuestionnaireView
    // This component should NOT set values on appear

    // Circadian-aware check
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
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
            // Apply circadian-aware styling to picker text
            // Force dark mode for the picker in evening/night to get light text,
            // then tint with warm amber color
            .colorScheme(isEvening ? .dark : .light)
            .tint(isEvening ? Color(red: 0.988, green: 0.827, blue: 0.302) : nil) // Golden amber tint
        }
        .id("\(question.id)-\(previousBedtime?.timeIntervalSince1970 ?? 0)") // Force view recreation when question or context changes
        // REMOVED: .task and .onChange that were setting smart defaults
        // This was causing values to be marked as user-interacted before the user actually touched the picker
        // Smart defaults are now provided via the dateBinding getter in QuestionnaireView
    }

    /// Static helper to compute smart default time for a question
    /// Call this from the binding's default parameter
    static func smartDefault(for question: Question, previousBedtime: Date? = nil) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.minute = 0

        switch question.id {
        // Consensus Sleep Diary (CSD) question IDs
        case "CSD_INTO_BED":
            components.hour = 22  // 10:00 PM - when you got into bed

        case "CSD_TRY_SLEEP":
            // Typically 5-15 min after getting into bed
            if let gotIntoBed = previousBedtime {
                return calendar.date(byAdding: .minute, value: 10, to: gotIntoBed) ?? gotIntoBed
            }
            components.hour = 22
            components.minute = 15

        case "CSD_FINAL_WAKE":
            // Typically ~7-8 hours after trying to sleep
            if let trySleep = previousBedtime {
                return calendar.date(byAdding: .hour, value: 8, to: trySleep) ?? Date()
            }
            components.hour = 6
            components.minute = 30

        case "CSD_OUT_BED":
            // Typically 5-15 min after final wake
            if let wakeTime = previousBedtime {
                return calendar.date(byAdding: .minute, value: 10, to: wakeTime) ?? wakeTime
            }
            components.hour = 6
            components.minute = 45

        case "CSD_CAFFEINE_LAST":
            // Default to 2 PM for last caffeine
            components.hour = 14
            components.minute = 0

        case "CSD_ALCOHOL_LAST":
            // Default to 8 PM for last alcohol
            components.hour = 20
            components.minute = 0

        // Legacy Stanford Sleep Log IDs (backward compatibility)
        case "SL_BEDTIME", "SD_GOT_INTO_BED":
            components.hour = 22  // 10:00 PM - typical bedtime

        case "SD_LIGHTS_OUT":
            if let gotIntoBed = previousBedtime {
                return calendar.date(byAdding: .minute, value: 10, to: gotIntoBed) ?? gotIntoBed
            }
            components.hour = 22
            components.minute = 15

        case "SL_ASLEEP_TIME":
            if let lightsOut = previousBedtime {
                return calendar.date(byAdding: .minute, value: 15, to: lightsOut) ?? lightsOut
            }
            components.hour = 22
            components.minute = 30

        case "SL_WAKE_TIME":
            if let asleepTime = previousBedtime {
                return calendar.date(byAdding: .hour, value: 8, to: asleepTime) ?? Date()
            }
            components.hour = 6
            components.minute = 30

        case "SD_OUT_OF_BED":
            if let wakeTime = previousBedtime {
                return calendar.date(byAdding: .minute, value: 10, to: wakeTime) ?? wakeTime
            }
            components.hour = 6
            components.minute = 45

        // PSQI questions
        case "PSQI_1":
            components.hour = 22
            components.minute = 30
        case "PSQI_3":
            if let bedtime = previousBedtime {
                return calendar.date(byAdding: .hour, value: 8, to: bedtime) ?? Date()
            }
            components.hour = 7

        default:
            // Smart inference based on question text
            let lowerText = question.text.lowercased()
            if lowerText.contains("wake") || lowerText.contains("morning") || lowerText.contains("get up") || lowerText.contains("out of bed") {
                if let bedtime = previousBedtime {
                    return calendar.date(byAdding: .hour, value: 8, to: bedtime) ?? Date()
                }
                components.hour = 7
            } else if lowerText.contains("fall asleep") || lowerText.contains("fell asleep") {
                if let bedtime = previousBedtime {
                    return calendar.date(byAdding: .minute, value: 15, to: bedtime) ?? bedtime
                }
                components.hour = 22
                components.minute = 30
            } else if lowerText.contains("lights") || lowerText.contains("try to sleep") {
                if let bedtime = previousBedtime {
                    return calendar.date(byAdding: .minute, value: 10, to: bedtime) ?? bedtime
                }
                components.hour = 22
                components.minute = 15
            } else if lowerText.contains("caffeine") {
                components.hour = 14  // 2 PM default for caffeine
            } else if lowerText.contains("alcohol") {
                components.hour = 20  // 8 PM default for alcohol
            } else if lowerText.contains("bed") || lowerText.contains("sleep") || lowerText.contains("night") {
                components.hour = 22
            } else {
                components.hour = 12  // Noon for unknown
            }
        }

        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - Date Input

struct DateInputView: View {
    let question: Question
    @Binding var value: Date

    // Circadian-aware check
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        DatePicker(
            "",
            selection: $value,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
        // Apply circadian-aware styling
        .colorScheme(isEvening ? .dark : .light)
        .tint(isEvening ? Color(red: 0.988, green: 0.827, blue: 0.302) : nil) // Golden amber tint
    }
}

// MARK: - Text Input

struct TextInputView: View {
    let question: Question
    @Binding var value: String
    var placeholder: String = "Enter your answer"

    // Circadian-aware colors
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var textColor: Color {
        if isEvening {
            return Color(red: 0.996, green: 0.953, blue: 0.780)  // Bright cream #FEF3C7
        } else {
            return Color.primary
        }
    }

    private var placeholderColor: Color {
        if isEvening {
            return Color(red: 0.961, green: 0.620, blue: 0.043)  // Amber #F59E0B
        } else {
            return Color.secondary
        }
    }

    private var backgroundColor: Color {
        if isEvening {
            return Color(red: 0.2, green: 0.12, blue: 0.08)  // Dark brown
        } else {
            return Color(.systemBackground)
        }
    }

    private var borderColor: Color {
        if isEvening {
            return Color(red: 0.4, green: 0.25, blue: 0.15)  // Warm brown border
        } else {
            return Color.gray.opacity(0.3)
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Custom placeholder for circadian visibility
            if value.isEmpty {
                Text(placeholder)
                    .foregroundColor(placeholderColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }

            TextField("", text: $value)
                .foregroundColor(textColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(backgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .autocapitalization(question.questionType == .email ? .none : .words)
                .keyboardType(question.questionType == .email ? .emailAddress : .default)
        }
    }
}

// MARK: - Minutes Scroll Picker

struct MinutesScrollPicker: View {
    let question: Question
    @Binding var value: Int

    // Circadian-aware check
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

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
            // Apply circadian-aware styling to picker text
            .colorScheme(isEvening ? .dark : .light)
            .tint(isEvening ? Color(red: 0.988, green: 0.827, blue: 0.302) : nil) // Golden amber tint
        }
    }
}

// MARK: - Hours & Minutes Scroll Picker (for sleep duration with 15-min increments)

struct HoursMinutesScrollPicker: View {
    let question: Question
    @Binding var totalMinutes: Int

    // Circadian-aware check
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    // Derived hours and minutes
    private var hours: Int {
        totalMinutes / 60
    }

    private var minutes: Int {
        totalMinutes % 60
    }

    // Minute options (15-minute increments)
    private let minuteOptions = [0, 15, 30, 45]

    // Max hours (default 14 if not specified)
    private var maxHours: Int {
        question.maxValue ?? 14
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                // Hours picker
                Picker("Hours", selection: Binding(
                    get: { hours },
                    set: { newHours in
                        totalMinutes = newHours * 60 + minutes
                    }
                )) {
                    ForEach(0...maxHours, id: \.self) { hour in
                        Text("\(hour) hr")
                            .tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100, height: 150)
                .clipped()

                // Minutes picker (15-min increments)
                Picker("Minutes", selection: Binding(
                    get: {
                        // Round to nearest 15
                        let roundedMinutes = (minutes / 15) * 15
                        return roundedMinutes
                    },
                    set: { newMinutes in
                        totalMinutes = hours * 60 + newMinutes
                    }
                )) {
                    ForEach(minuteOptions, id: \.self) { min in
                        Text("\(min) min")
                            .tag(min)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100, height: 150)
                .clipped()
            }
            // Apply circadian-aware styling
            .colorScheme(isEvening ? .dark : .light)
            .tint(isEvening ? Color(red: 0.988, green: 0.827, blue: 0.302) : nil)

            // Show total duration
            Text(formatDuration(totalMinutes))
                .font(.caption)
                .foregroundColor(CircadianColors.secondary)
        }
    }

    private func formatDuration(_ totalMins: Int) -> String {
        let h = totalMins / 60
        let m = totalMins % 60
        if m == 0 {
            return "\(h) hours"
        } else {
            return "\(h) hours \(m) minutes"
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
                .foregroundColor(CircadianColors.primary)  // Circadian-aware
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
                .foregroundColor(CircadianColors.primary)

            HStack {
                // User perception
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Perception")
                        .font(.caption)
                        .foregroundColor(CircadianColors.secondary)

                    if let bedtime = userResponses["SL_BEDTIME"]?.stringValue {
                        Label(bedtime, systemImage: "bed.double")
                            .font(.subheadline)
                            .foregroundColor(CircadianColors.primary)
                    }
                    if let wakeTime = userResponses["SL_WAKE_TIME"]?.stringValue {
                        Label(wakeTime, systemImage: "sun.max")
                            .font(.subheadline)
                            .foregroundColor(CircadianColors.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 60)

                // HealthKit data
                VStack(alignment: .leading, spacing: 8) {
                    Text("HealthKit Data")
                        .font(.caption)
                        .foregroundColor(CircadianColors.secondary)

                    if let summary = healthKitSummary {
                        if let bedtime = summary.formattedInBedTime {
                            Label(bedtime, systemImage: "bed.double")
                                .font(.subheadline)
                                .foregroundColor(CircadianColors.primary)
                        }
                        if let wakeTime = summary.formattedWakeTime {
                            Label(wakeTime, systemImage: "sun.max")
                                .font(.subheadline)
                                .foregroundColor(CircadianColors.primary)
                        }
                    } else {
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(CircadianColors.muted)
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
                    .foregroundColor(CircadianColors.primary)

                Spacer()

                Text("\(currentIndex + 1) of \(totalQuestions)")
                    .font(.subheadline)
                    .foregroundColor(CircadianColors.secondary)
            }

            ProgressView(value: Double(currentIndex + 1), total: Double(totalQuestions))
                .progressViewStyle(LinearProgressViewStyle(tint: pillarColor))
        }
        .padding()
        .background(CircadianColors.secondaryBackground)
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
                        .foregroundColor(CircadianColors.primary)
                    Text("Additional questions will be added to your journey")
                        .font(.caption2)
                        .foregroundColor(CircadianColors.muted)
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
