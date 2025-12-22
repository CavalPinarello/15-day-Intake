//
//  ProtocolCardView.swift
//  ZoeSleep
//
//  Protocol card displaying grouped treatment tasks.
//  Shows Morning Protocol or Evening Protocol with individual task checkboxes.
//
//  Features:
//  - Protocol header with icon and progress
//  - Collapsible task list
//  - Individual task completion
//  - Adaptive difficulty banner when applicable
//

import SwiftUI

struct ProtocolCardView: View {
    let protocol_: ProtocolData
    let isExpanded: Bool
    let onToggle: () -> Void
    let onCompleteTask: (ProtocolTask) async -> Void
    let onSkipTask: (ProtocolTask, String?) async -> Void

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    private var completedCount: Int {
        protocol_.tasks.filter { $0.isCompleted }.count
    }

    private var totalCount: Int {
        protocol_.tasks.count
    }

    private var progressPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Difficulty Banner (if applicable)
            if protocol_.difficultyReduced {
                difficultyBanner
            }

            // Task List
            if isExpanded && !protocol_.tasks.isEmpty {
                taskListSection
            }
        }
        .background(theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Header

    private var headerSection: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Protocol icon
                ZStack {
                    Circle()
                        .fill(protocol_.color.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: protocol_.icon)
                        .font(.title3)
                        .foregroundColor(protocol_.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(protocol_.name)
                        .font(.headline)
                        .foregroundColor(theme.primaryText)

                    HStack(spacing: 4) {
                        Text(protocol_.timeRange)
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)

                        if protocol_.isActive {
                            Text("• Active now")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(protocol_.color)
                        }
                    }
                }

                Spacer()

                // Progress
                HStack(spacing: 12) {
                    // Mini progress ring
                    ZStack {
                        Circle()
                            .stroke(theme.secondaryText.opacity(0.2), lineWidth: 3)
                            .frame(width: 32, height: 32)

                        Circle()
                            .trim(from: 0, to: progressPercentage)
                            .stroke(
                                completedCount == totalCount ? Color.green : protocol_.color,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))

                        Text("\(completedCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.primaryText)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
            }
            .padding()
        }
        .background(protocol_.isActive ? protocol_.color.opacity(0.08) : Color.clear)
    }

    // MARK: - Difficulty Banner

    private var difficultyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundColor(.blue)

            Text("We've simplified this to help you succeed")
                .font(.caption)
                .foregroundColor(.blue)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
    }

    // MARK: - Task List

    private var taskListSection: some View {
        VStack(spacing: 0) {
            Divider()

            ForEach(protocol_.tasks) { task in
                ProtocolTaskRow(
                    task: task,
                    protocolColor: protocol_.color,
                    onComplete: { await onCompleteTask(task) },
                    onSkip: { reason in await onSkipTask(task, reason) }
                )

                if task.id != protocol_.tasks.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
    }
}

// MARK: - Protocol Task Row

struct ProtocolTaskRow: View {
    let task: ProtocolTask
    let protocolColor: Color
    let onComplete: () async -> Void
    let onSkip: (String?) async -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isCompletingTask = false
    @State private var showingDetail = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: {
                guard !task.isCompleted && !isCompletingTask else { return }
                isCompletingTask = true
                Task {
                    await onComplete()
                    isCompletingTask = false
                }
            }) {
                Group {
                    if isCompletingTask {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(task.isCompleted ? .green : theme.secondaryText)
                    }
                }
            }
            .disabled(task.isCompleted || isCompletingTask)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? theme.secondaryText : theme.primaryText)

                if let subtitle = task.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }

                // Difficulty indicator
                if let difficulty = task.currentDifficulty, difficulty < task.originalDifficulty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption2)
                        Text("Simplified")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }

            Spacer()

            // Info button
            Button(action: { showingDetail = true }) {
                Image(systemName: "info.circle")
                    .foregroundColor(theme.secondaryText)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .sheet(isPresented: $showingDetail) {
            ProtocolTaskDetailSheet(task: task, onSkip: onSkip)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Protocol Task Detail Sheet

struct ProtocolTaskDetailSheet: View {
    let task: ProtocolTask
    let onSkip: (String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var skipReason = ""
    @State private var showSkipConfirm = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task Name
                    Text(task.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)

                    // Status
                    HStack {
                        if task.isCompleted {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Pending", systemImage: "circle")
                                .foregroundColor(theme.accent)
                        }
                    }
                    .font(.subheadline)

                    Divider()

                    // Instructions
                    Text("How to do this")
                        .font(.headline)
                        .foregroundColor(theme.primaryText)

                    Text(task.instructions)
                        .font(.body)
                        .foregroundColor(theme.secondaryText)

                    // Difficulty info
                    if let difficulty = task.currentDifficulty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Difficulty Level")
                                .font(.headline)
                                .foregroundColor(theme.primaryText)

                            HStack {
                                ForEach(1...5, id: \.self) { level in
                                    Circle()
                                        .fill(level <= difficulty ? theme.accent : theme.secondaryText.opacity(0.3))
                                        .frame(width: 10, height: 10)
                                }

                                if difficulty < task.originalDifficulty {
                                    Text("(reduced)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)

                    // Skip button
                    if !task.isCompleted && !task.isSkipped {
                        Button(action: { showSkipConfirm = true }) {
                            Text("Skip This Task")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(theme.backgroundGradient)
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Skip Task?", isPresented: $showSkipConfirm) {
                TextField("Reason (optional)", text: $skipReason)
                Button("Skip", role: .destructive) {
                    Task {
                        await onSkip(skipReason.isEmpty ? nil : skipReason)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to skip this task?")
            }
        }
    }
}

// MARK: - Data Types

struct ProtocolData: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let timeRange: String
    let isActive: Bool
    let tasks: [ProtocolTask]
    let difficultyReduced: Bool

    static let morningProtocol = ProtocolData(
        id: "morning_protocol",
        name: "Morning Protocol",
        icon: "sun.max.fill",
        color: .orange,
        timeRange: "6:00 AM - 12:00 PM",
        isActive: false,
        tasks: [],
        difficultyReduced: false
    )

    static let eveningProtocol = ProtocolData(
        id: "evening_protocol",
        name: "Evening Protocol",
        icon: "moon.stars.fill",
        color: .indigo,
        timeRange: "6:00 PM - 10:00 PM",
        isActive: false,
        tasks: [],
        difficultyReduced: false
    )
}

struct ProtocolTask: Identifiable {
    let id: String
    let name: String
    let subtitle: String?
    let instructions: String
    let isCompleted: Bool
    let isSkipped: Bool
    let currentDifficulty: Int?
    let originalDifficulty: Int
    let interventionId: String?
}

// MARK: - Preview

#if DEBUG
struct ProtocolCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ProtocolCardView(
                protocol_: ProtocolData(
                    id: "morning",
                    name: "Morning Protocol",
                    icon: "sun.max.fill",
                    color: .orange,
                    timeRange: "6:00 AM - 12:00 PM",
                    isActive: true,
                    tasks: [
                        ProtocolTask(
                            id: "1",
                            name: "Light exposure",
                            subtitle: "Get 15 min of bright light",
                            instructions: "Step outside or use a light therapy lamp for 15 minutes within an hour of waking.",
                            isCompleted: true,
                            isSkipped: false,
                            currentDifficulty: 2,
                            originalDifficulty: 3,
                            interventionId: nil
                        ),
                        ProtocolTask(
                            id: "2",
                            name: "Morning exercise",
                            subtitle: "10-20 min moderate activity",
                            instructions: "Do some light exercise like walking, yoga, or stretching.",
                            isCompleted: false,
                            isSkipped: false,
                            currentDifficulty: 3,
                            originalDifficulty: 3,
                            interventionId: nil
                        )
                    ],
                    difficultyReduced: true
                ),
                isExpanded: true,
                onToggle: {},
                onCompleteTask: { _ in },
                onSkipTask: { _, _ in }
            )

            ProtocolCardView(
                protocol_: ProtocolData(
                    id: "evening",
                    name: "Evening Protocol",
                    icon: "moon.stars.fill",
                    color: .indigo,
                    timeRange: "6:00 PM - 10:00 PM",
                    isActive: false,
                    tasks: [
                        ProtocolTask(
                            id: "3",
                            name: "Screen time limit",
                            subtitle: nil,
                            instructions: "Reduce screen brightness and avoid screens 1 hour before bed.",
                            isCompleted: false,
                            isSkipped: false,
                            currentDifficulty: nil,
                            originalDifficulty: 2,
                            interventionId: nil
                        )
                    ],
                    difficultyReduced: false
                ),
                isExpanded: false,
                onToggle: {},
                onCompleteTask: { _ in },
                onSkipTask: { _, _ in }
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .environmentObject(ThemeManager.shared)
    }
}
#endif
