//
//  SleepLogView.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Optimized 60-second Stanford Sleep Log for ALL Apple Watch sizes
//

import SwiftUI
import WatchKit

struct SleepLogView: View {
    @State private var currentQuestion = 0
    @State private var isCompleted = false

    // Responses
    @State private var bedtime = Date()
    @State private var fellAsleepTime = Date()
    @State private var awakenings = 0
    @State private var wakeTime = Date()
    @State private var sleepQuality = 5

    private let watchSize = WatchSizeDetector.current

    var body: some View {
        Group {
            if isCompleted {
                completionView
            } else {
                questionView
            }
        }
    }

    // MARK: - Question Views

    @ViewBuilder
    private var questionView: some View {
        VStack(spacing: 0) {
            // Progress header
            WatchProgressHeader(
                currentQuestion: currentQuestion + 1,
                totalQuestions: 5,
                sectionTitle: "Sleep Log"
            )

            Divider()
                .padding(.vertical, 4)

            // Question content
            TabView(selection: $currentQuestion) {
                // Q1: Bedtime
                WatchTimePicker(
                    title: "What time did you go to bed?",
                    selectedTime: $bedtime,
                    questionId: "SL_BEDTIME"
                )
                .tag(0)
                .onSubmit { nextQuestion() }

                // Q2: Fell asleep time
                WatchTimePicker(
                    title: "What time did you fall asleep?",
                    selectedTime: $fellAsleepTime,
                    questionId: "SL_ASLEEP_TIME"
                )
                .tag(1)
                .onSubmit { nextQuestion() }

                // Q3: Awakenings
                WatchNumberGrid(
                    title: "How many times did you wake up?",
                    range: 0...7,
                    selectedValue: $awakenings,
                    onSelect: { nextQuestion() }
                )
                .tag(2)

                // Q4: Wake time
                WatchTimePicker(
                    title: "What time did you wake up?",
                    selectedTime: $wakeTime,
                    questionId: "SL_WAKE_TIME"
                )
                .tag(3)
                .onSubmit { nextQuestion() }

                // Q5: Sleep quality
                WatchScaleSlider(
                    title: "Rate your sleep quality",
                    minLabel: "Poor",
                    maxLabel: "Great",
                    range: 1...10,
                    value: $sleepQuality
                )
                .tag(4)
                .onSubmit { completeLog() }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Sleep Log")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Completion View

    private var completionView: some View {
        WatchCompletionView(
            title: "Sleep Log Done!",
            message: "Great start to your day!",
            onContinue: {
                // Send message to iPhone to continue
                sendToiPhone()
            },
            onDone: {
                // Dismiss and save
                saveAndDismiss()
            }
        )
    }

    // MARK: - Actions

    private func nextQuestion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if currentQuestion < 4 {
                currentQuestion += 1
                WKInterfaceDevice.current().play(.click)
            } else {
                completeLog()
            }
        }
    }

    private func completeLog() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isCompleted = true
            WKInterfaceDevice.current().play(.success)
        }
        saveResponses()
    }

    private func saveResponses() {
        // Create response data
        let responses: [String: Any] = [
            "SL_BEDTIME": formatTime(bedtime),
            "SL_ASLEEP_TIME": formatTime(fellAsleepTime),
            "SL_AWAKENINGS": awakenings,
            "SL_WAKE_TIME": formatTime(wakeTime),
            "SL_QUALITY": sleepQuality,
            "completed_at": Date().timeIntervalSince1970,
            "device": "watch"
        ]

        // Save to UserDefaults for sync
        if let encoded = try? JSONSerialization.data(withJSONObject: responses) {
            UserDefaults.standard.set(encoded, forKey: "pendingSleepLogResponse")
        }

        // TODO: Send to Convex via WatchConnectivity
    }

    private func sendToiPhone() {
        // Trigger WatchConnectivity message to open iPhone app
        // For now, just provide feedback
        WKInterfaceDevice.current().play(.notification)
    }

    private func saveAndDismiss() {
        WKInterfaceDevice.current().play(.success)
        // Dismiss is handled by navigation
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Watch Section Colors (matching iOS QuestionnaireSections.swift)

enum WatchSectionColors {
    static let sleepLogAccent = Color(red: 0.13, green: 0.59, blue: 0.95) // Blue #2196F3
    static let sleepLogBackground = Color(red: 0.89, green: 0.95, blue: 0.99) // Soft blue #E3F2FD
    static let assessmentAccent = Color(red: 0.61, green: 0.35, blue: 0.71) // Purple #9C27B0
    static let assessmentBackground = Color(red: 0.95, green: 0.90, blue: 0.96) // Soft purple #F3E5F5
}

// MARK: - Sleep Log Card (for main view)

struct SleepLogCard: View {
    let isCompleted: Bool
    var onTap: () -> Void

    private let watchSize = WatchSizeDetector.current

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Section badge
                    HStack(spacing: 4) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.caption)
                        Text("SLEEP LOG")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WatchSectionColors.sleepLogAccent)
                    .cornerRadius(6)

                    Spacer()

                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("5 Q")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Daily Sleep Log")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))

                Text(isCompleted ? "Completed today" : "About last night's sleep")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if !isCompleted {
                    HStack {
                        Spacer()
                        Text("~60 sec")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(WatchSectionColors.sleepLogAccent)
                    }
                }
            }
            .padding()
            .background(WatchSectionColors.sleepLogBackground.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(WatchSectionColors.sleepLogAccent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
        .opacity(isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Day Assessment Card (for main view)

struct DayAssessmentCard: View {
    let dayNumber: Int
    let title: String
    let questionCount: Int
    let estimatedMinutes: Int
    let isCompleted: Bool
    var onTap: () -> Void

    private let watchSize = WatchSizeDetector.current

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Section badge
                    HStack(spacing: 4) {
                        Image(systemName: "clipboard.fill")
                            .font(.caption)
                        Text("ASSESSMENT")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WatchSectionColors.assessmentAccent)
                    .cornerRadius(6)

                    Spacer()

                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("\(questionCount) Q")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Day \(dayNumber): \(title)")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .lineLimit(2)

                if !isCompleted {
                    HStack {
                        Spacer()
                        Text("~\(estimatedMinutes) min")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(WatchSectionColors.assessmentAccent)
                    }
                } else {
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(WatchSectionColors.assessmentBackground.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(WatchSectionColors.assessmentAccent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
        .opacity(isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Preview

#Preview("Sleep Log") {
    NavigationStack {
        SleepLogView()
    }
}

#Preview("Sleep Log Card") {
    VStack {
        SleepLogCard(isCompleted: false, onTap: {})
        SleepLogCard(isCompleted: true, onTap: {})
    }
    .padding()
}
