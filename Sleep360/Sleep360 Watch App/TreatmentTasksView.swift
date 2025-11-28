//
//  TreatmentTasksView.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Treatment Mode: Daily tasks optimized for Apple Watch
//

import SwiftUI
import WatchKit

// MARK: - Watch Treatment Task

struct WatchTreatmentTask: Identifiable {
    let id: String
    let name: String
    let timing: String?
    let shortInstructions: String
    var isCompleted: Bool
}

// MARK: - Treatment Tasks View

struct TreatmentTasksView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var themeManager: WatchThemeManager
    @State private var tasks: [WatchTreatmentTask] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var selectedTask: WatchTreatmentTask?

    private let watchSize = WatchSizeDetector.current
    private var theme: WatchColorTheme { themeManager.currentTheme }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if tasks.isEmpty {
                emptyView
            } else {
                taskListView
            }
        }
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTasks()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())

            Text("Loading tasks...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 36))
                    .foregroundColor(themeManager.accentColor)

                Text("No Tasks")
                    .font(.headline)

                Text("Complete your 15-day intake to get personalized tasks")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !watchConnectivity.isConnected {
                    Divider()
                        .padding(.vertical, 4)

                    HStack(spacing: 4) {
                        Image(systemName: "iphone")
                            .font(.caption2)
                        Text("Open iPhone app to sync")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    // MARK: - Task List View

    private var taskListView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Progress Summary
                progressHeader

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                    .padding(.vertical, 4)

                // Tasks
                ForEach(tasks) { task in
                    WatchTaskRow(
                        task: task,
                        onTap: {
                            toggleTask(task)
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        let completed = tasks.filter { $0.isCompleted }.count
        let total = tasks.count
        let percentage = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0

        return VStack(spacing: 8) {
            HStack {
                Text("Today")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))

                Spacer()

                Text("\(percentage)%")
                    .font(.system(size: watchSize.fontSize + 2, weight: .bold))
                    .foregroundColor(percentage == 100 ? theme.success : themeManager.accentColor)
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [themeManager.accentColor, theme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(percentage) / 100, height: 6)
                        .animation(.spring(response: 0.3), value: percentage)
                }
            }
            .frame(height: 6)

            Text("\(completed) of \(total) tasks done")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Celebration
            if percentage == 100 {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text("All done!")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func loadTasks() {
        isLoading = true
        loadError = nil

        // Check if iPhone is connected
        guard watchConnectivity.isConnected else {
            // Show normal empty state when iPhone not connected
            // Treatment tasks aren't critical - user can see them on iPhone
            isLoading = false
            tasks = []
            return
        }

        // Request tasks from iPhone via WatchConnectivity
        watchConnectivity.requestTreatmentTasks { fetchedTasks in
            DispatchQueue.main.async {
                self.tasks = fetchedTasks
                self.isLoading = false
            }
        }
    }

    private func toggleTask(_ task: WatchTreatmentTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let newCompletedState = !tasks[index].isCompleted
            tasks[index].isCompleted = newCompletedState

            // Haptic feedback
            WKInterfaceDevice.current().play(newCompletedState ? .success : .click)

            // Sync with iPhone via WatchConnectivity
            watchConnectivity.completeTreatmentTask(taskId: task.id) { success in
                if !success {
                    // Revert on failure
                    DispatchQueue.main.async {
                        if let idx = self.tasks.firstIndex(where: { $0.id == task.id }) {
                            self.tasks[idx].isCompleted = !newCompletedState
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Watch Task Row

struct WatchTaskRow: View {
    let task: WatchTreatmentTask
    let onTap: () -> Void

    private let watchSize = WatchSizeDetector.current

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Checkbox
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: watchSize.buttonHeight * 0.5))
                    .foregroundColor(task.isCompleted ? .green : .gray)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if let timing = task.timing {
                            Image(systemName: timingIcon(for: timing))
                                .font(.caption2)
                                .foregroundColor(timingColor(for: timing))
                        }

                        Text(task.name)
                            .font(.system(size: watchSize.fontSize - 1, weight: .medium))
                            .strikethrough(task.isCompleted)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .lineLimit(1)
                    }

                    Text(task.shortInstructions)
                        .font(.system(size: max(10, watchSize.fontSize - 4)))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                task.isCompleted
                    ? Color.green.opacity(0.15)
                    : Color(.darkGray).opacity(0.3)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func timingIcon(for timing: String) -> String {
        switch timing {
        case "Morning": return "sun.max.fill"
        case "Afternoon": return "sun.min.fill"
        case "Evening": return "sunset.fill"
        case "Before bed": return "moon.fill"
        default: return "clock"
        }
    }

    private func timingColor(for timing: String) -> Color {
        switch timing {
        case "Morning": return .orange
        case "Afternoon": return .blue
        case "Evening": return .purple
        case "Before bed": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Treatment Card for Main View

struct TreatmentTasksCard: View {
    @EnvironmentObject var themeManager: WatchThemeManager
    let completedCount: Int
    let totalCount: Int
    var onTap: () -> Void

    private let watchSize = WatchSizeDetector.current
    private var theme: WatchColorTheme { themeManager.currentTheme }

    var percentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(completedCount) / Double(totalCount)) * 100)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Section badge
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.caption)
                        Text("TREATMENT")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.accentColor)
                    .cornerRadius(6)

                    Spacer()

                    if percentage == 100 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                    } else {
                        Text("\(percentage)%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.accentColor)
                    }
                }

                Text("Daily Tasks")
                    .font(.system(size: watchSize.fontSize, weight: .semibold))

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(themeManager.accentColor)
                            .frame(width: geo.size.width * CGFloat(percentage) / 100, height: 4)
                    }
                }
                .frame(height: 4)

                Text("\(completedCount) of \(totalCount) completed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(themeManager.accentColor.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Treatment Tasks") {
    NavigationStack {
        TreatmentTasksView()
            .environmentObject(WatchConnectivityManager())
            .environmentObject(WatchThemeManager.shared)
    }
}

#Preview("Treatment Card") {
    VStack {
        TreatmentTasksCard(completedCount: 3, totalCount: 5, onTap: {})
        TreatmentTasksCard(completedCount: 5, totalCount: 5, onTap: {})
    }
    .padding()
    .environmentObject(WatchThemeManager.shared)
}
