//
//  WatchQuestionComponents.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Adaptive question UI components for ALL Apple Watch sizes (40mm-49mm Ultra)
//

import SwiftUI
import WatchKit

// MARK: - Watch Time Picker

struct WatchTimePicker: View {
    let title: String
    @Binding var selectedTime: Date
    let questionId: String

    @AppStorage("largeTextMode") private var largeTextMode: Bool = false
    private let watchSize = WatchSizeDetector.current

    // Track time as seconds from midnight for Digital Crown rotation
    @State private var timeInSeconds: Double = 0

    // Smart defaults based on question context
    private var smartDefaultTime: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.minute = 0

        switch questionId {
        case "SL_BEDTIME":
            components.hour = 21  // 9:00 PM
        case "SL_ASLEEP_TIME":
            components.hour = 21
            components.minute = 30  // 9:30 PM
        case "SL_WAKE_TIME":
            components.hour = 7   // 7:00 AM
        default:
            if title.lowercased().contains("wake") || title.lowercased().contains("morning") {
                components.hour = 7
            } else {
                components.hour = 21
            }
        }

        return calendar.date(from: components) ?? Date()
    }

    private var smartDefaultSeconds: Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: smartDefaultTime)
        return Double((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60)
    }

    var body: some View {
        VStack(spacing: watchSize.isUltra ? 12 : 8) {
            Text(title)
                .font(.system(size: watchSize.fontSize, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Large time display
            Text(timeString)
                .font(.system(size: watchSize.timeDisplayFontSize, weight: .bold, design: .rounded))
                .foregroundColor(.teal)

            Text("Rotate Crown")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Confirm button
            Button {
                WKInterfaceDevice.current().play(.click)
            } label: {
                Text("Confirm")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: watchSize.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .focusable(true)
        .digitalCrownRotation(
            $timeInSeconds,
            from: 0.0,
            through: 86399.0, // 23:59:59 in seconds
            by: 900.0, // 15-minute increments
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: timeInSeconds) { _, newValue in
            // Convert seconds to Date
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            selectedTime = startOfDay.addingTimeInterval(newValue)
        }
        .onAppear {
            // Initialize timeInSeconds from selectedTime or smart default
            let calendar = Calendar.current
            let now = Date()
            let hourDiff = abs(calendar.component(.hour, from: selectedTime) - calendar.component(.hour, from: now))
            if hourDiff <= 1 {
                timeInSeconds = smartDefaultSeconds
                selectedTime = smartDefaultTime
            } else {
                let components = calendar.dateComponents([.hour, .minute], from: selectedTime)
                timeInSeconds = Double((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60)
            }
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: selectedTime)
    }
}

// MARK: - Watch Number Grid

struct WatchNumberGrid: View {
    let title: String
    let range: ClosedRange<Int>
    @Binding var selectedValue: Int
    var onSelect: (() -> Void)?

    @AppStorage("largeTextMode") private var largeTextMode: Bool = false
    private let watchSize = WatchSizeDetector.current

    private var columns: Int {
        watchSize.gridColumns
    }

    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: columns)
    }

    var body: some View {
        VStack(spacing: watchSize.isUltra ? 10 : 6) {
            Text(title)
                .font(.system(size: watchSize.fontSize, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            LazyVGrid(columns: gridItems, spacing: 4) {
                ForEach(Array(range), id: \.self) { number in
                    Button {
                        selectedValue = number
                        WKInterfaceDevice.current().play(.click)
                        onSelect?()
                    } label: {
                        Text(number == range.upperBound ? "\(number)+" : "\(number)")
                            .font(.system(size: largeTextMode ? watchSize.fontSize + 2 : watchSize.fontSize, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: watchSize.buttonHeight - 10)
                            .background(selectedValue == number ? Color.teal : Color.gray.opacity(0.3))
                            .foregroundColor(selectedValue == number ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Watch Scale Slider

struct WatchScaleSlider: View {
    let title: String
    let minLabel: String
    let maxLabel: String
    let range: ClosedRange<Int>
    @Binding var value: Int

    @AppStorage("largeTextMode") private var largeTextMode: Bool = false
    private let watchSize = WatchSizeDetector.current

    @State private var crownValue: Double = 5

    var body: some View {
        VStack(spacing: watchSize.isUltra ? 12 : 8) {
            Text(title)
                .font(.system(size: watchSize.fontSize, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Emoji labels
            HStack {
                Text(minLabel)
                    .font(.caption2)
                Spacer()
                Text(maxLabel)
                    .font(.caption2)
            }
            .foregroundColor(.secondary)

            // Visual progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 12)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.teal)
                        .frame(width: geometry.size.width * CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound), height: 12)
                }
            }
            .frame(height: 12)

            // Large value display
            Text("\(value)")
                .font(.system(size: watchSize.scaleValueFontSize, weight: .bold, design: .rounded))
                .foregroundColor(.teal)

            Text("Rotate Crown")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Confirm button
            Button {
                WKInterfaceDevice.current().play(.click)
            } label: {
                Text("Confirm")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: watchSize.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .focusable(true)
        .digitalCrownRotation(
            $crownValue,
            from: Double(range.lowerBound),
            through: Double(range.upperBound),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            value = Int(newValue.rounded())
        }
        .onAppear {
            crownValue = Double(value)
        }
    }
}

// MARK: - Watch Yes/No Buttons

struct WatchYesNoButtons: View {
    let title: String
    @Binding var selectedValue: Bool?
    var onSelect: (() -> Void)?

    @AppStorage("largeTextMode") private var largeTextMode: Bool = false
    private let watchSize = WatchSizeDetector.current

    var body: some View {
        VStack(spacing: watchSize.isUltra ? 12 : 8) {
            Text(title)
                .font(.system(size: watchSize.fontSize, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            // YES Button
            Button {
                selectedValue = true
                WKInterfaceDevice.current().play(.click)
                onSelect?()
            } label: {
                Text("YES")
                    .font(.system(size: watchSize.titleFontSize, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: watchSize.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedValue == true ? .teal : .gray.opacity(0.5))

            // NO Button
            Button {
                selectedValue = false
                WKInterfaceDevice.current().play(.click)
                onSelect?()
            } label: {
                Text("NO")
                    .font(.system(size: watchSize.titleFontSize, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: watchSize.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedValue == false ? .gray : .gray.opacity(0.5))
        }
    }
}

// MARK: - Watch Single Select List

struct WatchSingleSelectList: View {
    let title: String
    let options: [String]
    @Binding var selectedOption: String?
    var onSelect: (() -> Void)?

    @AppStorage("largeTextMode") private var largeTextMode: Bool = false
    private let watchSize = WatchSizeDetector.current

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: watchSize.fontSize, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.bottom, 4)

                ForEach(options, id: \.self) { option in
                    Button {
                        selectedOption = option
                        WKInterfaceDevice.current().play(.click)
                        onSelect?()
                    } label: {
                        HStack {
                            Text(option)
                                .font(.system(size: largeTextMode ? watchSize.fontSize : watchSize.fontSize - 1))
                                .lineLimit(2)
                            Spacer()
                            if selectedOption == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.teal)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: watchSize.rowHeight)
                        .background(selectedOption == option ? Color.teal.opacity(0.2) : Color.gray.opacity(0.15))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Watch Progress Header

struct WatchProgressHeader: View {
    let currentQuestion: Int
    let totalQuestions: Int
    let sectionTitle: String

    private let watchSize = WatchSizeDetector.current

    var body: some View {
        VStack(spacing: 4) {
            Text(sectionTitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)

            // Progress dots
            HStack(spacing: 4) {
                ForEach(1...totalQuestions, id: \.self) { index in
                    Circle()
                        .fill(index <= currentQuestion ? Color.teal : Color.gray.opacity(0.3))
                        .frame(width: watchSize.isUltra ? 8 : 6, height: watchSize.isUltra ? 8 : 6)
                }
            }

            Text("\(currentQuestion) of \(totalQuestions)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Watch Completion View

struct WatchCompletionView: View {
    let title: String
    let message: String
    var onContinue: (() -> Void)?
    var onDone: (() -> Void)?

    private let watchSize = WatchSizeDetector.current

    var body: some View {
        VStack(spacing: watchSize.isUltra ? 16 : 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: watchSize.isUltra ? 50 : 40))
                .foregroundColor(.green)

            Text(title)
                .font(.system(size: watchSize.titleFontSize, weight: .bold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: watchSize.fontSize - 2))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let onContinue = onContinue {
                Button {
                    onContinue()
                } label: {
                    HStack {
                        Text("Continue on")
                        Image(systemName: "iphone")
                    }
                    .font(.system(size: watchSize.fontSize - 1, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: watchSize.buttonHeight - 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }

            if let onDone = onDone {
                Button {
                    onDone()
                } label: {
                    Text("Done for now")
                        .font(.system(size: watchSize.fontSize - 1, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: watchSize.buttonHeight - 6)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Time Picker") {
    WatchTimePicker(
        title: "What time did you go to bed?",
        selectedTime: .constant(Date()),
        questionId: "SL_BEDTIME"
    )
}

#Preview("Number Grid") {
    WatchNumberGrid(
        title: "How many times did you wake up?",
        range: 0...7,
        selectedValue: .constant(2)
    )
}

#Preview("Scale") {
    WatchScaleSlider(
        title: "Rate your sleep quality",
        minLabel: "Poor",
        maxLabel: "Great",
        range: 1...10,
        value: .constant(7)
    )
}

#Preview("Yes/No") {
    WatchYesNoButtons(
        title: "Did you take any sleep medication?",
        selectedValue: .constant(nil)
    )
}
