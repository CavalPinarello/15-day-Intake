//
//  MinimalTasksView.swift
//  ZoeSleep Watch App
//
//  Categorized task list: Sleep Log, Assessment, and Protocol.
//  Protocol displays physician-prescribed interventions.
//

import SwiftUI
import WatchKit

// MARK: - Minimal Tasks View

struct MinimalTasksView: View {
    @Environment(\.dismiss) private var dismiss

    let taskStatus: WatchTaskStatus
    var overdueExpansionsCount: Int = 0

    @State private var localTaskStatus: WatchTaskStatus

    private let palette = WatchCircadianPalette.current

    // Card background color derived from palette
    private var cardBackground: Color {
        palette.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
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

                    // Expansion Pack Section (if any pending)
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
                LinearGradient(colors: palette.background, startPoint: .top, endPoint: .bottom)
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
                    .foregroundColor(localTaskStatus.sleepLogDone ? palette.textSecondary : palette.textPrimary)

                Text(localTaskStatus.sleepLogDone ? "Completed" : "Complete on iPhone")
                    .font(.system(size: 10))
                    .foregroundColor(palette.textSecondary)
            }

            Spacer()

            if !localTaskStatus.sleepLogDone {
                Image(systemName: "iphone")
                    .font(.system(size: 12))
                    .foregroundColor(palette.textSecondary)
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
                Text("Assessment")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(localTaskStatus.assessmentDone ? palette.textSecondary : palette.textPrimary)

                Text(localTaskStatus.assessmentDone ? "Completed" : "Complete on iPhone")
                    .font(.system(size: 10))
                    .foregroundColor(palette.textSecondary)
            }

            Spacer()

            if !localTaskStatus.assessmentDone {
                Image(systemName: "iphone")
                    .font(.system(size: 12))
                    .foregroundColor(palette.textSecondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground.opacity(localTaskStatus.assessmentDone ? 0.5 : 1))
        )
        .opacity(localTaskStatus.assessmentDone ? 0.7 : 1)
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
                    .foregroundColor(palette.textPrimary)

                Text("\(overdueExpansionsCount) questionnaire\(overdueExpansionsCount == 1 ? "" : "s") on iPhone")
                    .font(.system(size: 10))
                    .foregroundColor(palette.textSecondary)
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
                    .foregroundColor(palette.textPrimary)

                Spacer()

                Text("\(localTaskStatus.pendingProtocolCount) remaining")
                    .font(.system(size: 10))
                    .foregroundColor(palette.textSecondary)
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
                        .foregroundColor(task.isCompleted ? palette.textSecondary : palette.textPrimary)
                        .strikethrough(task.isCompleted, color: palette.textSecondary)
                        .lineLimit(1)

                    Text(task.timing)
                        .font(.system(size: 9))
                        .foregroundColor(palette.textSecondary)
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
