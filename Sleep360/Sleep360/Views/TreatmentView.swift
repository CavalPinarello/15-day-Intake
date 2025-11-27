//
//  TreatmentView.swift
//  Zoe Sleep for Longevity System
//
//  Treatment Mode: Daily tasks and interventions from physician
//

import SwiftUI

// MARK: - Treatment Task Model

struct TreatmentTask: Identifiable {
    let id: String
    let name: String
    let category: String?
    let instructions: String
    let timing: String?
    let frequency: String?
    var isCompleted: Bool
}

// MARK: - Treatment View

struct TreatmentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var tasks: [TreatmentTask] = []
    @State private var completedCount: Int = 0
    @State private var isLoading = true
    @State private var showingNoteSheet = false
    @State private var selectedTask: TreatmentTask?
    @State private var noteText = ""
    @State private var treatmentWeek: Int = 1

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView

                // Progress Card
                progressCard

                // Tasks by Time of Day
                tasksSection

                // Weekly Streak
                weeklyStreakCard
            }
            .padding()
        }
        .navigationTitle("Treatment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTasks()
        }
        .sheet(isPresented: $showingNoteSheet) {
            noteSheet
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(getGreeting())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.primary)

            Text("Week \(treatmentWeek) of your treatment plan")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Progress")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(completedCount) of \(tasks.count) tasks completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(progressPercentage)%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(theme.accent)
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [theme.accent, theme.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progressPercentage) / 100, height: 12)
                        .animation(.spring(response: 0.5), value: progressPercentage)
                }
            }
            .frame(height: 12)

            // Completion celebration
            if progressPercentage == 100 {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("All tasks completed!")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Great job staying on track today.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Tasks Section

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(timingGroups, id: \.0) { timing, timingTasks in
                VStack(alignment: .leading, spacing: 12) {
                    // Timing Header
                    HStack(spacing: 8) {
                        Image(systemName: timingIcon(for: timing))
                            .foregroundColor(timingColor(for: timing))
                            .padding(8)
                            .background(timingColor(for: timing).opacity(0.15))
                            .cornerRadius(8)

                        Text(timing)
                            .font(.headline)

                        Text("(\(timingTasks.filter { $0.isCompleted }.count)/\(timingTasks.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Tasks
                    ForEach(timingTasks) { task in
                        TaskCard(
                            task: task,
                            theme: theme,
                            onToggle: { toggleTask(task) },
                            onNote: {
                                selectedTask = task
                                showingNoteSheet = true
                            }
                        )
                    }
                }
            }

            if tasks.isEmpty && !isLoading {
                emptyStateView
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("No treatment tasks yet")
                .font(.headline)

            Text("Complete your 15-day intake to receive personalized treatment recommendations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Weekly Streak Card

    private var weeklyStreakCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(theme.accent)
                Text("7-Day Streak")
                    .font(.headline)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let percentage = mockWeeklyProgress[index]
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 36, height: 60)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(streakColor(for: percentage))
                                .frame(width: 36, height: CGFloat(percentage) * 0.6)
                        }

                        Text(dayLabel(for: index))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Note Sheet

    private var noteSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let task = selectedTask {
                    Text("Note for: \(task.name)")
                        .font(.headline)
                        .padding(.top)
                }

                TextEditor(text: $noteText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Spacer()
            }
            .padding()
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingNoteSheet = false
                        noteText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(noteText.isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private var progressPercentage: Int {
        guard !tasks.isEmpty else { return 0 }
        return Int((Double(completedCount) / Double(tasks.count)) * 100)
    }

    private var timingGroups: [(String, [TreatmentTask])] {
        let grouped = Dictionary(grouping: tasks) { $0.timing ?? "Anytime" }
        let order = ["Morning", "Afternoon", "Evening", "Before bed", "With meals", "Anytime"]
        return order.compactMap { timing in
            if let tasks = grouped[timing], !tasks.isEmpty {
                return (timing, tasks)
            }
            return nil
        }
    }

    private func timingIcon(for timing: String) -> String {
        switch timing {
        case "Morning": return "sun.max.fill"
        case "Afternoon": return "sun.min.fill"
        case "Evening": return "sunset.fill"
        case "Before bed": return "moon.fill"
        case "With meals": return "fork.knife"
        default: return "clock"
        }
    }

    private func timingColor(for timing: String) -> Color {
        switch timing {
        case "Morning": return .orange
        case "Afternoon": return .blue
        case "Evening": return .purple
        case "Before bed": return .indigo
        case "With meals": return .green
        default: return .gray
        }
    }

    private func streakColor(for percentage: Int) -> Color {
        if percentage >= 80 { return theme.accent }
        if percentage >= 50 { return .yellow }
        if percentage > 0 { return .red.opacity(0.7) }
        return .gray.opacity(0.3)
    }

    private func dayLabel(for index: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -(6 - index), to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning!" }
        if hour < 17 { return "Good afternoon!" }
        return "Good evening!"
    }

    // Mock weekly data
    private var mockWeeklyProgress: [Int] {
        [75, 100, 80, 90, 100, 60, progressPercentage]
    }

    // MARK: - Data Loading

    private func loadTasks() {
        isLoading = true

        // TODO: Replace with actual Convex API call
        // For now, use mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            tasks = [
                TreatmentTask(
                    id: "1",
                    name: "Sleep Restriction Therapy",
                    category: "CBT-I",
                    instructions: "Go to bed at 11:00 PM. Wake up at 6:30 AM. Do not nap during the day.",
                    timing: "Before bed",
                    frequency: "Daily",
                    isCompleted: false
                ),
                TreatmentTask(
                    id: "2",
                    name: "Relaxation Exercise",
                    category: "Relaxation",
                    instructions: "Practice deep breathing for 10 minutes using the 4-7-8 technique.",
                    timing: "Evening",
                    frequency: "Daily",
                    isCompleted: true
                ),
                TreatmentTask(
                    id: "3",
                    name: "Melatonin",
                    category: "Supplement",
                    instructions: "Take 3mg melatonin 30 minutes before your scheduled bedtime.",
                    timing: "Before bed",
                    frequency: "Daily",
                    isCompleted: false
                ),
                TreatmentTask(
                    id: "4",
                    name: "Caffeine Cutoff",
                    category: "Lifestyle",
                    instructions: "No caffeine after 2:00 PM. This includes coffee, tea, and sodas.",
                    timing: "Afternoon",
                    frequency: "Daily",
                    isCompleted: true
                ),
                TreatmentTask(
                    id: "5",
                    name: "Morning Light Exposure",
                    category: "Light Therapy",
                    instructions: "Get 30 minutes of bright light exposure within 1 hour of waking.",
                    timing: "Morning",
                    frequency: "Daily",
                    isCompleted: false
                ),
            ]
            completedCount = tasks.filter { $0.isCompleted }.count
            isLoading = false
        }
    }

    private func toggleTask(_ task: TreatmentTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            completedCount = tasks.filter { $0.isCompleted }.count

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            // TODO: Sync with Convex
        }
    }

    private func saveNote() {
        // TODO: Save note to Convex
        showingNoteSheet = false
        noteText = ""
        selectedTask = nil
    }
}

// MARK: - Task Card Component

struct TaskCard: View {
    let task: TreatmentTask
    let theme: ColorTheme
    let onToggle: () -> Void
    let onNote: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(task.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    if let category = task.category {
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                Text(task.instructions)
                    .font(.caption)
                    .foregroundColor(task.isCompleted ? .secondary.opacity(0.7) : .secondary)
                    .lineLimit(2)

                if let frequency = task.frequency {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.caption2)
                        Text(frequency)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary.opacity(0.7))
                }
            }

            Spacer()

            // Note button
            Button(action: onNote) {
                Image(systemName: "text.bubble")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            task.isCompleted
                ? Color.green.opacity(0.08)
                : Color(.systemBackground)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    task.isCompleted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TreatmentView()
            .environmentObject(ThemeManager.shared)
    }
}
