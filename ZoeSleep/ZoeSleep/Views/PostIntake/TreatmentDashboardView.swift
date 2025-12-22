//
//  TreatmentDashboardView.swift
//  Zoe Sleep for Longevity System
//
//  Main treatment view showing intervention tasks grouped by time window
//  Displays 4 collapsible session cards: Morning, Afternoon, Evening, Night
//

import SwiftUI

struct TreatmentDashboardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var journeyManager = JourneyPhaseManager.shared
    @ObservedObject var checkInManager = CheckInManager.shared

    @State private var expandedWindows: Set<String> = []
    @State private var showingMorningCheckIn = false
    @State private var showingMiddayCheckIn = false
    @State private var showingEveningReport = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with greeting
                headerSection

                // Check-in Status Card
                checkInStatusCard

                // Daily Progress Summary
                dailyProgressCard

                // Session Cards (4 time windows)
                ForEach(TimeWindow.all, id: \.id) { window in
                    SessionCard(
                        window: window,
                        tasks: journeyManager.tasks(for: window),
                        isExpanded: expandedWindows.contains(window.id) || window.isActive,
                        onToggle: { toggleWindow(window.id) },
                        onCompleteTask: { task in
                            await completeTask(task)
                        },
                        onSkipTask: { task, reason in
                            await skipTask(task, reason: reason)
                        }
                    )
                }

                // Weekly Compliance Card
                weeklyComplianceCard

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(theme.backgroundGradient)
        .onAppear {
            loadTasks()
            loadCheckInStatus()
            // Auto-expand current window
            expandedWindows.insert(TimeWindow.current().id)
        }
        .refreshable {
            loadTasks()
            loadCheckInStatus()
        }
        .sheet(isPresented: $showingMorningCheckIn) {
            MorningCheckInView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingMiddayCheckIn) {
            MiddayCheckInView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingEveningReport) {
            EveningReportView()
                .environmentObject(themeManager)
        }
    }

    // MARK: - Check-In Status Card

    private var checkInStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(theme.accent)
                Text("Daily Check-ins")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)

                Spacer()

                Text("\(checkInManager.completedCount)/3")
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
            }

            // Check-in status pills
            HStack(spacing: 12) {
                CheckInPill(
                    title: "Morning",
                    icon: "sun.max.fill",
                    color: .orange,
                    isCompleted: checkInManager.morningCompleted,
                    isActive: checkInManager.shouldShowCheckInPrompt(for: .morning),
                    action: { showingMorningCheckIn = true }
                )

                CheckInPill(
                    title: "Midday",
                    icon: "clock.fill",
                    color: .blue,
                    isCompleted: checkInManager.middayCompleted,
                    isActive: checkInManager.shouldShowCheckInPrompt(for: .midday),
                    action: { showingMiddayCheckIn = true }
                )

                CheckInPill(
                    title: "Evening",
                    icon: "moon.stars.fill",
                    color: .indigo,
                    isCompleted: checkInManager.eveningCompleted,
                    isActive: checkInManager.shouldShowCheckInPrompt(for: .evening),
                    action: { showingEveningReport = true }
                )
            }
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.primaryText)

            Text("Your personalized treatment plan is active")
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    // MARK: - Daily Progress Card

    private var dailyProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Progress")
                        .font(.headline)
                        .foregroundColor(theme.primaryText)

                    Text("\(journeyManager.completedTaskCount) of \(journeyManager.totalTaskCount) tasks completed")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(theme.secondaryText.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: journeyManager.completionPercentage)
                        .stroke(theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(journeyManager.completionPercentage * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.secondaryText.opacity(0.2))

                    Capsule()
                        .fill(theme.accent)
                        .frame(width: geo.size.width * journeyManager.completionPercentage)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Weekly Compliance Card

    private var weeklyComplianceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(theme.accent)
                Text("This Week")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
            }

            // Week days (simplified view)
            HStack(spacing: 8) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    VStack(spacing: 4) {
                        Text(day)
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText)

                        Circle()
                            .fill(theme.accent.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(theme.accent)
                                    .opacity(0.5)
                            )
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Actions

    private func toggleWindow(_ windowId: String) {
        if expandedWindows.contains(windowId) {
            expandedWindows.remove(windowId)
        } else {
            expandedWindows.insert(windowId)
        }
    }

    private func loadTasks() {
        guard let userId = authManager.user?.id else { return }
        Task {
            await journeyManager.loadWindowedTasks(userId: userId)
        }
    }

    private func loadCheckInStatus() {
        Task {
            await checkInManager.loadTodayStatus()
        }
    }

    private func completeTask(_ task: WindowedTask) async {
        let result = await journeyManager.completeTask(taskId: task.id)
        if !result.success {
            // Show error
            print("Failed to complete task: \(result.error ?? "Unknown error")")
        }
    }

    private func skipTask(_ task: WindowedTask, reason: String?) async {
        _ = await journeyManager.skipTask(taskId: task.id, reason: reason)
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let window: TimeWindow
    let tasks: [WindowedTask]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onCompleteTask: (WindowedTask) async -> Void
    let onSkipTask: (WindowedTask, String?) async -> Void

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Window icon with glow if active
                    ZStack {
                        if window.isActive {
                            Circle()
                                .fill(window.color.opacity(0.2))
                                .frame(width: 44, height: 44)
                        }
                        Image(systemName: window.icon)
                            .font(.title3)
                            .foregroundColor(window.isActive ? window.color : theme.secondaryText)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(window.name)
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                        Text(window.timeRange)
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                    }

                    Spacer()

                    // Progress + Lock
                    HStack(spacing: 8) {
                        if tasks.isEmpty {
                            Text("No tasks")
                                .font(.caption)
                                .foregroundColor(theme.secondaryText)
                        } else {
                            Text("\(completedCount)/\(tasks.count)")
                                .font(.subheadline)
                                .foregroundColor(theme.secondaryText)
                        }

                        if !window.isActive && !tasks.isEmpty {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(theme.secondaryText)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                .padding()
            }
            .background(window.isActive ? window.color.opacity(0.1) : theme.cardBackground)

            // Expandable task list
            if isExpanded && !tasks.isEmpty {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskCheckInRow(
                            task: task,
                            windowActive: window.isActive,
                            onComplete: { await onCompleteTask(task) },
                            onSkip: { reason in await onSkipTask(task, reason) }
                        )

                        if task.id != tasks.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(theme.cardBackground)
            }
        }
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Task Check-In Row

struct TaskCheckInRow: View {
    let task: WindowedTask
    let windowActive: Bool
    let onComplete: () async -> Void
    let onSkip: (String?) async -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDetail = false
    @State private var isCompletingTask = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 12) {
            // Completion toggle
            Button(action: {
                guard !task.isLocked && !task.isCompleted && !isCompletingTask else { return }
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
                            .foregroundColor(checkboxColor)
                    }
                }
            }
            .disabled(task.isLocked || task.isCompleted || isCompletingTask)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.taskName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? theme.secondaryText : theme.primaryText)

                if task.isLocked, let unlocksAt = task.unlocksAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Unlocks at \(unlocksAt)")
                            .font(.caption)
                    }
                    .foregroundColor(theme.secondaryText)
                } else if task.isSkipped {
                    Text("Skipped")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Button(action: { showingDetail = true }) {
                Image(systemName: "info.circle")
                    .foregroundColor(theme.secondaryText)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .opacity(task.isLocked ? 0.6 : 1.0)
        .sheet(isPresented: $showingDetail) {
            TaskDetailSheet(task: task, onSkip: onSkip)
                .environmentObject(themeManager)
        }
    }

    private var checkboxColor: Color {
        if task.isCompleted {
            return .green
        } else if task.isLocked {
            return theme.secondaryText.opacity(0.5)
        } else {
            return theme.secondaryText
        }
    }
}

// MARK: - Task Detail Sheet

struct TaskDetailSheet: View {
    let task: WindowedTask
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
                    Text(task.taskName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)

                    // Status Badge
                    HStack {
                        if task.isCompleted {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if task.isLocked {
                            Label("Locked", systemImage: "lock.fill")
                                .foregroundColor(theme.secondaryText)
                        } else {
                            Label("Available", systemImage: "circle")
                                .foregroundColor(theme.accent)
                        }
                    }
                    .font(.subheadline)

                    Divider()

                    // Instructions
                    Text("Instructions")
                        .font(.headline)
                        .foregroundColor(theme.primaryText)

                    Text(task.taskInstructions)
                        .font(.body)
                        .foregroundColor(theme.secondaryText)

                    Divider()

                    // Time Window
                    HStack {
                        Image(systemName: "clock")
                        Text("Time Window: \(task.timeWindow.capitalized)")
                    }
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)

                    if let scheduledTime = task.scheduledTime {
                        HStack {
                            Image(systemName: "alarm")
                            Text("Scheduled: \(scheduledTime)")
                        }
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryText)
                    }

                    Spacer(minLength: 40)

                    // Skip Button (if not completed)
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
                    Button("Done") {
                        dismiss()
                    }
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
                Text("Are you sure you want to skip this task? You can provide an optional reason.")
            }
        }
    }
}

// MARK: - Check-In Pill

struct CheckInPill: View {
    let title: String
    let icon: String
    let color: Color
    let isCompleted: Bool
    let isActive: Bool
    let action: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        Button(action: {
            if !isCompleted {
                action()
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green.opacity(0.2) : (isActive ? color.opacity(0.2) : theme.secondaryText.opacity(0.1)))
                        .frame(width: 40, height: 40)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: icon)
                            .font(.subheadline)
                            .foregroundColor(isActive ? color : theme.secondaryText)
                    }
                }

                Text(title)
                    .font(.caption2)
                    .foregroundColor(isCompleted ? .green : (isActive ? color : theme.secondaryText))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
    }
}

// MARK: - Preview

#Preview {
    TreatmentDashboardView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(AuthenticationManager())
}
