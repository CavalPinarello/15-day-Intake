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
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: watchSize.fontSize, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            // Large time display - very prominent
            Text(timeString)
                .font(.system(size: watchSize.timeDisplayFontSize, weight: .bold, design: .rounded))
                .foregroundColor(.teal)
                .padding(.vertical, 4)

            // Confirm button - full width, easy to tap
            Button {
                WKInterfaceDevice.current().play(.click)
            } label: {
                Text("Confirm")
                    .font(.system(size: watchSize.fontSize, weight: .bold))
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
        // Use TimeFormatManager for consistent time format (respects user preference)
        return TimeFormatManager.shared.formatTime(selectedTime)
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
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: watchSize.fontSize, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            LazyVGrid(columns: gridItems, spacing: 6) {
                ForEach(Array(range), id: \.self) { number in
                    Button {
                        selectedValue = number
                        WKInterfaceDevice.current().play(.click)
                        onSelect?()
                    } label: {
                        Text(number == range.upperBound ? "\(number)+" : "\(number)")
                            .font(.system(size: watchSize.titleFontSize, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: watchSize.buttonHeight)
                            .background(selectedValue == number ? Color.teal : Color.gray.opacity(0.3))
                            .foregroundColor(selectedValue == number ? .white : .primary)
                            .cornerRadius(12)
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
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: watchSize.fontSize, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            // Labels - larger and clearer
            HStack {
                Text(minLabel)
                    .font(.system(size: watchSize.captionFontSize, weight: .medium))
                Spacer()
                Text(maxLabel)
                    .font(.system(size: watchSize.captionFontSize, weight: .medium))
            }
            .foregroundColor(.secondary)

            // Visual progress bar - thicker
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.teal)
                        .frame(width: geometry.size.width * CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound), height: 16)
                }
            }
            .frame(height: 16)

            // Large value display - very prominent
            Text("\(value)")
                .font(.system(size: watchSize.scaleValueFontSize, weight: .bold, design: .rounded))
                .foregroundColor(.teal)
                .padding(.vertical, 2)

            // Confirm button - full width
            Button {
                WKInterfaceDevice.current().play(.click)
            } label: {
                Text("Confirm")
                    .font(.system(size: watchSize.fontSize, weight: .bold))
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
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: watchSize.fontSize, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)

            // YES Button - large and prominent
            Button {
                selectedValue = true
                WKInterfaceDevice.current().play(.click)
                onSelect?()
            } label: {
                Text("Yes")
                    .font(.system(size: watchSize.titleFontSize, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: watchSize.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedValue == true ? .teal : .gray.opacity(0.5))

            // NO Button - large and prominent
            Button {
                selectedValue = false
                WKInterfaceDevice.current().play(.click)
                onSelect?()
            } label: {
                Text("No")
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
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .padding(.bottom, 4)

                ForEach(options, id: \.self) { option in
                    Button {
                        selectedOption = option
                        WKInterfaceDevice.current().play(.click)
                        onSelect?()
                    } label: {
                        HStack(spacing: 10) {
                            Text(option)
                                .font(.system(size: watchSize.fontSize, weight: .medium))
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            Spacer()
                            if selectedOption == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.teal)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: watchSize.rowHeight)
                        .background(selectedOption == option ? Color.teal.opacity(0.25) : Color.gray.opacity(0.2))
                        .cornerRadius(12)
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
        VStack(spacing: 6) {
            Text(sectionTitle)
                .font(.system(size: watchSize.captionFontSize, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)

            // Progress dots - larger
            HStack(spacing: 6) {
                ForEach(1...totalQuestions, id: \.self) { index in
                    Circle()
                        .fill(index <= currentQuestion ? Color.teal : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }

            Text("\(currentQuestion) of \(totalQuestions)")
                .font(.system(size: watchSize.captionFontSize, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
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
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text(title)
                .font(.system(size: watchSize.titleFontSize, weight: .bold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: watchSize.fontSize, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let onContinue = onContinue {
                Button {
                    onContinue()
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Image(systemName: "iphone")
                            .font(.system(size: 18))
                    }
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: watchSize.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }

            if let onDone = onDone {
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(.system(size: watchSize.fontSize, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: watchSize.buttonHeight)
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
