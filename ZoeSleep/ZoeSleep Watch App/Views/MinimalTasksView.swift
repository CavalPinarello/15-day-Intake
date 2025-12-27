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
    6: DayAssessmentConfig(
        title: "Insomnia Deep Dive",
        questionnaire: "ISI Assessment",
        mission: "Assess insomnia severity with clinical-grade screening.",
        questionCount: 16,
        estimatedMinutes: 14
    ),
    7: DayAssessmentConfig(
        title: "Sleepiness Check",
        questionnaire: "ESS & FSS",
        mission: "Measure daytime sleepiness and fatigue levels.",
        questionCount: 15,
        estimatedMinutes: 12
    ),
    8: DayAssessmentConfig(
        title: "Mental Wellness",
        questionnaire: "PHQ-9 & GAD-7",
        mission: "Screen for mood and anxiety factors affecting sleep.",
        questionCount: 18,
        estimatedMinutes: 15
    ),
    9: DayAssessmentConfig(
        title: "Breathing Check",
        questionnaire: "STOP-BANG",
        mission: "Screen for sleep apnea risk factors.",
        questionCount: 12,
        estimatedMinutes: 10
    ),
    10: DayAssessmentConfig(
        title: "Pain Assessment",
        questionnaire: "Brief Pain",
        mission: "Understand how pain interferes with your sleep.",
        questionCount: 14,
        estimatedMinutes: 12
    ),
    11: DayAssessmentConfig(
        title: "Your Chronotype",
        questionnaire: "MEQ",
        mission: "Discover if you're a morning lark or night owl.",
        questionCount: 19,
        estimatedMinutes: 15
    ),
    12: DayAssessmentConfig(
        title: "Diet & Sleep",
        questionnaire: "MEDAS",
        mission: "Explore the connection between nutrition and rest.",
        questionCount: 14,
        estimatedMinutes: 12
    ),
    13: DayAssessmentConfig(
        title: "Cognitive Health",
        questionnaire: "PROMIS Cognitive",
        mission: "Assess how sleep affects your thinking and focus.",
        questionCount: 12,
        estimatedMinutes: 10
    ),
    14: DayAssessmentConfig(
        title: "Final Review",
        questionnaire: "Comprehensive",
        mission: "Complete your 14-day journey with a final assessment.",
        questionCount: 20,
        estimatedMinutes: 18
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Sleep Log Card (Info Only - Must complete on iPhone)

    private var sleepLogCard: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(localTaskStatus.sleepLogDone ? Color.green.opacity(0.2) : Color.purple.opacity(0.2))
                    .frame(width: 36, height: 36)

                if localTaskStatus.sleepLogDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Sleep Log")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(localTaskStatus.sleepLogDone ? .white.opacity(0.6) : .white)

                Text(localTaskStatus.sleepLogDone ? "Completed" : "Complete on iPhone")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            if !localTaskStatus.sleepLogDone {
                Image(systemName: "iphone")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground.opacity(localTaskStatus.sleepLogDone ? 0.5 : 1))
        )
        .opacity(localTaskStatus.sleepLogDone ? 0.7 : 1)
    }

    // MARK: - Assessment Card (Info Only - Must complete on iPhone)

    private var assessmentCard: some View {
        VStack(spacing: 0) {
            // Main card content
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(localTaskStatus.assessmentDone ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 36, height: 36)

                    if localTaskStatus.assessmentDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "clipboard.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    // Show questionnaire name (e.g., "PSQI Part 1")
                    Text(dayConfig.questionnaire)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(localTaskStatus.assessmentDone ? .white.opacity(0.6) : .white)

                    Text(localTaskStatus.assessmentDone ? "Completed" : "Complete on iPhone")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                if !localTaskStatus.assessmentDone {
                    Image(systemName: "iphone")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(10)

            // Mission statement (only show if not completed)
            if !localTaskStatus.assessmentDone {
                VStack(alignment: .leading, spacing: 6) {
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 8)

                    // Mission text
                    Text(dayConfig.mission)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(3)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)

                    // Stats row
                    HStack(spacing: 8) {
                        // Question count
                        HStack(spacing: 3) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 8))
                            Text("\(dayConfig.questionCount) Q")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.blue.opacity(0.8))

                        // Time estimate
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text("~\(dayConfig.estimatedMinutes) min")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        // Day badge
                        Text("Day \(convexService.currentDay)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground.opacity(localTaskStatus.assessmentDone ? 0.5 : 1))
        )
        .opacity(localTaskStatus.assessmentDone ? 0.7 : 1)
    }

    // MARK: - Deeper Dive Card (Today's Expansion Pack)

    /// Gateway descriptions for deeper dive explanation
    private var deeperDiveDescription: String {
        // Based on current day and triggered gateways, provide context
        // This is a simplified version - ideally would fetch from Convex
        switch convexService.currentDay {
        case 1...5:
            return "Understanding your sleep patterns"
        default:
            return "Personalized for you"
        }
    }

    private var deeperDiveCard: some View {
        let isCompleted = convexService.expansionPackCompleted

        return VStack(spacing: 0) {
            // Main card content
            HStack(spacing: 10) {
                // Icon - sparkles for deeper dive
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green.opacity(0.2) : Color(red: 0.85, green: 0.55, blue: 0.25).opacity(0.2))
                        .frame(width: 36, height: 36)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.25))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Deeper Dive")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isCompleted ? .white.opacity(0.6) : .white)

                    Text(isCompleted ? "Completed" : deeperDiveDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                if !isCompleted {
                    Image(systemName: "iphone")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(10)

            // Additional info (only show if not completed)
            if !isCompleted {
                VStack(alignment: .leading, spacing: 4) {
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 8)

                    // Stats row
                    HStack(spacing: 8) {
                        // Time estimate
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text("~7 min")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        // Badge
                        Text("Triggered by your answers")
                            .font(.system(size: 8))
                            .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.25))
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground.opacity(isCompleted ? 0.5 : 1))
                .overlay(
                    isCompleted ? nil : RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.85, green: 0.55, blue: 0.25).opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(isCompleted ? 0.7 : 1)
    }

    // MARK: - Expansion Pack Card (Pending/Overdue Deep Dives)

    private var expansionPackCard: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Deep Dive Pending")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text("\(overdueExpansionsCount) questionnaire\(overdueExpansionsCount == 1 ? "" : "s") on iPhone")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Badge showing count
            Text("\(overdueExpansionsCount)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.orange))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Protocol Section

    private var protocolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "stethoscope")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)

                Text("Protocol")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(localTaskStatus.pendingProtocolCount) remaining")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 4)

            // Protocol tasks
            ForEach(Array(localTaskStatus.protocolTasks.enumerated()), id: \.element.id) { index, task in
                ProtocolTaskRow(
                    task: task,
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
            HStack(spacing: 10) {
                // Checkbox
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? Color.green : Color.orange.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                            .scaleEffect(checkmarkScale)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(task.isCompleted ? .white.opacity(0.6) : .white)
                        .strikethrough(task.isCompleted, color: .white.opacity(0.6))
                        .lineLimit(1)

                    Text(task.timing)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
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
