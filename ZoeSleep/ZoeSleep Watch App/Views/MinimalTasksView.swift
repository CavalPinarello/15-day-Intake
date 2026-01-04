//
//  MinimalTasksView.swift
//  ZoeSleep Watch App
//
//  Categorized task list: Sleep Log, Assessment, and Protocol.
//  Protocol displays physician-prescribed interventions.
//

import SwiftUI
import WatchKit

// MARK: - Day Configuration (Mirrors iPhone)

struct DayAssessmentConfig {
    let title: String
    let questionnaire: String
    let mission: String
    let questionCount: Int
    let estimatedMinutes: Int
}

/// Day-specific assessment configurations matching iPhone app
let dayAssessmentConfigs: [Int: DayAssessmentConfig] = [
    1: DayAssessmentConfig(
        title: "Getting Started",
        questionnaire: "Demographics",
        mission: "Tell us about yourself so we can personalize your sleep journey.",
        questionCount: 15,
        estimatedMinutes: 12
    ),
    2: DayAssessmentConfig(
        title: "Sleep Quality",
        questionnaire: "PSQI Part 1",
        mission: "Measure the true quality of your sleep—not just hours, but depth and restoration.",
        questionCount: 12,
        estimatedMinutes: 12
    ),
    3: DayAssessmentConfig(
        title: "Sleep Patterns",
        questionnaire: "PSQI Part 2",
        mission: "Understand your sleep patterns and what disrupts your nights.",
        questionCount: 11,
        estimatedMinutes: 10
    ),
    4: DayAssessmentConfig(
        title: "Physical Health",
        questionnaire: "Health Screen",
        mission: "Discover how your physical health affects your sleep quality.",
        questionCount: 14,
        estimatedMinutes: 12
    ),
    5: DayAssessmentConfig(
        title: "Lifestyle Factors",
        questionnaire: "Nutrition & Social",
        mission: "Explore how diet, activity, and social rhythms impact your rest.",
        questionCount: 13,
        estimatedMinutes: 11
    ),
    // Expansion Pack Phase (Days 6-10) - Consolidated from 9 to 5 days
    6: DayAssessmentConfig(
        title: "Insomnia Assessment",
        questionnaire: "ISI + SWDSQ + DBAS",
        mission: "Assess insomnia severity, shift work, and sleep beliefs.",
        questionCount: 17,
        estimatedMinutes: 5
    ),
    7: DayAssessmentConfig(
        title: "Mental Health & Arousal",
        questionnaire: "PHQ-9 + GAD-7 + PSAS",
        mission: "Screen for depression, anxiety, and pre-sleep arousal.",
        questionCount: 32,
        estimatedMinutes: 9
    ),
    8: DayAssessmentConfig(
        title: "Breathing & Energy",
        questionnaire: "STOP-BANG + ESS + FSS",
        mission: "Screen for sleep apnea and measure daytime sleepiness.",
        questionCount: 25,
        estimatedMinutes: 7
    ),
    9: DayAssessmentConfig(
        title: "Function & Behavior",
        questionnaire: "Sleep Hygiene + BPI + FOSQ",
        mission: "Assess sleep habits, pain, and functional outcomes.",
        questionCount: 33,
        estimatedMinutes: 9
    ),
    10: DayAssessmentConfig(
        title: "Lifestyle & Rhythm",
        questionnaire: "PROMIS + MEDAS + MEQ",
        mission: "Complete your 10-day journey with lifestyle assessment.",
        questionCount: 39,
        estimatedMinutes: 11
    )
]

// MARK: - Minimal Tasks View

struct MinimalTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var convexService = WatchConvexService.shared

    let taskStatus: WatchTaskStatus
    var overdueExpansionsCount: Int = 0

    @State private var localTaskStatus: WatchTaskStatus

    private let palette = WatchCircadianPalette.current
    private let watchSize = WatchSizeDetector.current

    /// Get current day config
    private var dayConfig: DayAssessmentConfig {
        dayAssessmentConfigs[convexService.currentDay] ?? dayAssessmentConfigs[1]!
    }

    // Card background color - always light on dark since we use dark background
    private var cardBackground: Color {
        Color.white.opacity(0.1)
    }

    // Always use dark background for watchOS (OLED-friendly, better readability)
    private var darkBackground: [Color] {
        [
            Color(red: 0.08, green: 0.08, blue: 0.10),
            Color(red: 0.12, green: 0.12, blue: 0.14)
        ]
    }

    init(taskStatus: WatchTaskStatus, overdueExpansionsCount: Int = 0) {
        self.taskStatus = taskStatus
        self.overdueExpansionsCount = overdueExpansionsCount
        self._localTaskStatus = State(initialValue: taskStatus)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Sleep Log Section (info only - must complete on iPhone)
                    sleepLogCard

                    // Assessment Section (info only - must complete on iPhone)
                    assessmentCard

                    // Today's Deeper Dive (expansion pack triggered today)
                    if convexService.hasExpansionPackToday {
                        deeperDiveCard
                    }

                    // Overdue Expansion Pack Section (if any pending from previous days)
                    if overdueExpansionsCount > 0 {
                        expansionPackCard
                    }

                    // Protocol Section (physician interventions - only after intake)
                    if !localTaskStatus.protocolTasks.isEmpty {
                        protocolSection
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .background(
                LinearGradient(colors: darkBackground, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
            }
        }
    }

    // MARK: - Sleep Log Card (Informational)

    private var sleepLogCard: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(localTaskStatus.sleepLogDone ? Color.green.opacity(0.2) : Color.purple.opacity(0.2))
                    .frame(width: 44, height: 44)

                if localTaskStatus.sleepLogDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Sleep Log")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .foregroundColor(localTaskStatus.sleepLogDone ? .white.opacity(0.6) : .white)

                Text(localTaskStatus.sleepLogDone ? "Done" : "Complete on iPhone")
                    .font(.system(size: watchSize.captionFontSize))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(12)
        .frame(minHeight: watchSize.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground.opacity(localTaskStatus.sleepLogDone ? 0.5 : 1))
        )
        .opacity(localTaskStatus.sleepLogDone ? 0.7 : 1)
    }

    // MARK: - Assessment Card (Informational)

    private var assessmentCard: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(localTaskStatus.assessmentDone ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)

                if localTaskStatus.assessmentDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "clipboard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Assessment")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .foregroundColor(localTaskStatus.assessmentDone ? .white.opacity(0.6) : .white)

                Text(localTaskStatus.assessmentDone ? "Done" : "Complete on iPhone")
                    .font(.system(size: watchSize.captionFontSize))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(12)
        .frame(minHeight: watchSize.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground.opacity(localTaskStatus.assessmentDone ? 0.5 : 1))
        )
        .opacity(localTaskStatus.assessmentDone ? 0.7 : 1)
    }

    // MARK: - Deeper Dive Card (Today's Expansion Pack)

    /// Gateway descriptions for deeper dive explanation
    private var deeperDiveDescription: String {
        let questionCount = convexService.expansionQuestionCount
        if questionCount > 0 {
            return "\(questionCount) questions • Complete on iPhone"
        }
        // Fallback based on current day
        switch convexService.currentDay {
        case 1...5:
            return "Understanding your sleep patterns"
        default:
            return "Personalized for you"
        }
    }

    private var deeperDiveCard: some View {
        let isCompleted = convexService.expansionPackCompleted
        let accentColor = Color(red: 0.85, green: 0.55, blue: 0.25)

        return HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green.opacity(0.2) : accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Deeper Dive")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .foregroundColor(isCompleted ? .white.opacity(0.6) : .white)

                Text(isCompleted ? "Done" : "Complete on iPhone")
                    .font(.system(size: watchSize.captionFontSize))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(12)
        .frame(minHeight: watchSize.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground.opacity(isCompleted ? 0.5 : 1))
                .overlay(
                    isCompleted ? nil : RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(isCompleted ? 0.7 : 1)
    }

    // MARK: - Expansion Pack Card (Pending/Overdue Deep Dives)

    private var expansionPackCard: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Pending")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .foregroundColor(.white)

                Text("Complete on iPhone")
                    .font(.system(size: watchSize.captionFontSize))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Badge showing count
            Text("\(overdueExpansionsCount)")
                .font(.system(size: watchSize.captionFontSize, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.orange))
        }
        .padding(12)
        .frame(minHeight: watchSize.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Protocol Section

    private var protocolSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header - larger text
            HStack {
                Image(systemName: "stethoscope")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)

                Text("Protocol")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(localTaskStatus.pendingProtocolCount) left")
                    .font(.system(size: watchSize.captionFontSize))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 4)

            // Protocol tasks
            ForEach(Array(localTaskStatus.protocolTasks.enumerated()), id: \.element.id) { index, task in
                ProtocolTaskRow(
                    task: task,
                    watchSize: watchSize,
                    onTap: {
                        completeProtocolTask(at: index)
                    }
                )
            }
        }
    }

    // MARK: - Actions

    private func completeProtocolTask(at index: Int) {
        WKInterfaceDevice.current().play(.success)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            localTaskStatus.protocolTasks[index].isCompleted.toggle()
        }
        // TODO: Sync to Convex
    }
}

// MARK: - Protocol Task Row

struct ProtocolTaskRow: View {
    let task: ProtocolTask
    let watchSize: WatchSizeDetector
    let onTap: () -> Void

    @State private var checkmarkScale: CGFloat = 1.0

    private let palette = WatchCircadianPalette.current

    private var cardBackground: Color {
        palette.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                checkmarkScale = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    checkmarkScale = 1.0
                }
            }
            onTap()
        }) {
            HStack(spacing: 12) {
                // Checkbox - larger for elderly
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? Color.green : Color.orange.opacity(0.5), lineWidth: 2.5)
                        .frame(width: 28, height: 28)

                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                            .scaleEffect(checkmarkScale)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(size: watchSize.fontSize - 1, weight: .medium))
                        .foregroundColor(task.isCompleted ? .white.opacity(0.6) : .white)
                        .strikethrough(task.isCompleted, color: .white.opacity(0.6))
                        .lineLimit(2)

                    Text(task.timing)
                        .font(.system(size: watchSize.captionFontSize))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(minHeight: watchSize.rowHeight - 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground.opacity(task.isCompleted ? 0.5 : 1.0))
            )
            .opacity(task.isCompleted ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct MinimalTasksView_Previews: PreviewProvider {
    static var previews: some View {
        // During intake (Days 1-14): No protocol tasks
        MinimalTasksView(taskStatus: WatchTaskStatus(
            sleepLogDone: false,
            assessmentDone: false,
            protocolTasks: []  // Empty during intake phase
        ))
    }
}
#endif
