//
//  QuestionComponents.swift
//  Sleep 360 Platform
//
//  Reusable UI components for different question types
//

import SwiftUI

// MARK: - Question Card Container

struct QuestionCard<Content: View>: View {
    let question: Question
    let content: () -> Content

    init(question: Question, @ViewBuilder content: @escaping () -> Content) {
        self.question = question
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
                    .background(Color(hex: question.pillar.color) ?? .blue)
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
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(helpText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
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
            .accentColor(Color(hex: question.pillar.color) ?? .blue)

            Text("\(Int(value))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: question.pillar.color) ?? .blue)
        }
    }
}

// MARK: - Yes/No Input

struct YesNoInput: View {
    let question: Question
    @Binding var value: String

    var body: some View {
        HStack(spacing: 12) {
            ForEach(getOptions(), id: \.self) { option in
                Button(action: { value = option }) {
                    Text(option)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(value == option ? Color(hex: question.pillar.color)?.opacity(0.2) ?? Color.blue.opacity(0.2) : Color(.secondarySystemBackground))
                        .foregroundColor(value == option ? Color(hex: question.pillar.color) ?? .blue : .primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(value == option ? Color(hex: question.pillar.color) ?? .blue : Color.clear, lineWidth: 2)
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
                                .foregroundColor(Color(hex: question.pillar.color) ?? .blue)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(value == option ? Color(hex: question.pillar.color)?.opacity(0.1) ?? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
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

    var body: some View {
        VStack(spacing: 8) {
            ForEach(question.options ?? [], id: \.self) { option in
                Button(action: { toggleOption(option) }) {
                    HStack {
                        Text(option)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: values.contains(option) ? "checkmark.square.fill" : "square")
                            .foregroundColor(values.contains(option) ? Color(hex: question.pillar.color) ?? .blue : .secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(values.contains(option) ? Color(hex: question.pillar.color)?.opacity(0.1) ?? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
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
                        .foregroundColor(Color(hex: question.pillar.color) ?? .blue)
                }
                .disabled(value <= Double(question.minValue ?? 0))

                Text(formatValue())
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(minWidth: 80)

                Button(action: { incrementValue() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: question.pillar.color) ?? .blue)
                }
                .disabled(value >= Double(question.maxValue ?? 100))
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

    var body: some View {
        DatePicker(
            "",
            selection: $value,
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(height: 150)
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)

            Text(question.text)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Sleep Log Summary Card

struct SleepLogSummaryCard: View {
    let healthKitSummary: HealthKitSleepSummary?
    let userResponses: [String: QuestionResponse]

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
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Progress Header

struct QuestionnaireProgressHeader: View {
    let currentIndex: Int
    let totalQuestions: Int
    let dayNumber: Int
    let pillarColor: Color

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

    var body: some View {
        if isTriggered {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

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
            .background(Color.orange.opacity(0.15))
            .cornerRadius(8)
        }
    }
}

// MARK: - Color Extension

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
