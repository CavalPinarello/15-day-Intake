//
//  EveningReportView.swift
//  ZoeSleep
//
//  Evening report view for task completion summary and reflection.
//  Shown at 10:00 PM notification or when user opens app in the evening.
//
//  Contents:
//  - Task completion summary (X of Y completed)
//  - Visual celebration or encouragement
//  - Reflection prompt (optional text entry)
//  - Tomorrow's task preview
//  - Reminder for missed tasks
//

import SwiftUI

struct EveningReportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var reflectionText: String = ""
    @State private var dayRating: Int = 0
    @State private var todaysTasks: [TodayTask] = []
    @State private var tomorrowTasks: [TodayTask] = []
    @State private var isLoading = true
    @State private var hasSubmitted = false
    @State private var showTomorrowPreview = false
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?

    private var theme: ColorTheme { themeManager.currentTheme }

    private var completedCount: Int {
        todaysTasks.filter { $0.isCompleted }.count
    }

    private var totalCount: Int {
        todaysTasks.count
    }

    private var completionPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(completedCount) / Double(totalCount)) * 100)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    eveningHeader

                    // Completion Summary
                    completionSummaryCard

                    // Missed Tasks (if any)
                    if completedCount < totalCount {
                        missedTasksSection
                    }

                    // Day Rating
                    dayRatingSection

                    // Reflection
                    reflectionSection

                    // Tomorrow Preview
                    if showTomorrowPreview {
                        tomorrowPreviewSection
                    } else {
                        Button {
                            withAnimation {
                                showTomorrowPreview = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                Text("Preview Tomorrow's Tasks")
                            }
                            .font(.subheadline)
                            .foregroundColor(theme.primary)
                        }
                    }

                    // Submit Button
                    submitButton
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hue: 0.75, saturation: 0.3, brightness: 0.15),
                        Color(hue: 0.70, saturation: 0.4, brightness: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Evening Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .onAppear {
                loadData()
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .overlay {
            if showingSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.indigo)

                Text("Evening Report Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Sleep well tonight")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground).opacity(0.95))
            )
        }
        .transition(.opacity)
    }

    // MARK: - Evening Header

    private var eveningHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 48))
                .foregroundColor(.indigo)

            Text("Time to wind down")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(Date().formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 8)
    }

    // MARK: - Completion Summary Card

    private var completionSummaryCard: some View {
        VStack(spacing: 16) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(completionPercentage) / 100)
                    .stroke(
                        completionPercentage == 100 ? Color.green :
                            completionPercentage >= 50 ? Color.yellow : Color.orange,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: completionPercentage)

                VStack(spacing: 2) {
                    Text("\(completionPercentage)%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("\(completedCount)/\(totalCount)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Message based on completion
            Text(completionMessage)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Streak indicator if 100%
            if completionPercentage == 100 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Perfect day!")
                        .fontWeight(.semibold)
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(20)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }

    private var completionMessage: String {
        switch completionPercentage {
        case 100:
            return "Amazing! You completed all your tasks today!"
        case 75...99:
            return "Great job! Almost there!"
        case 50...74:
            return "Good progress. Every step counts!"
        case 25...49:
            return "Some tasks completed. Tomorrow is a new day!"
        default:
            return "Remember, consistency is key. Let's try again tomorrow!"
        }
    }

    // MARK: - Day Rating Section

    private var dayRatingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Rate your day")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            HStack(spacing: 16) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            dayRating = rating
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: rating <= dayRating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(rating <= dayRating ? .yellow : .white.opacity(0.3))

                            Text(dayRatingLabel(for: rating))
                                .font(.caption2)
                                .foregroundColor(rating == dayRating ? .white : .white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }

    private func dayRatingLabel(for rating: Int) -> String {
        switch rating {
        case 1: return "Rough"
        case 2: return "Hard"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return ""
        }
    }

    // MARK: - Missed Tasks Section

    private var missedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)
                Text("Incomplete Tasks")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            ForEach(todaysTasks.filter { !$0.isCompleted }) { task in
                HStack(spacing: 10) {
                    Circle()
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    Text(task.name)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    // Quick complete button
                    Button {
                        completeTask(task)
                    } label: {
                        Text("Complete")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.3))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                    }
                }
                .padding(.vertical, 4)
            }

            Text("It's okay if you couldn't complete everything. Focus on what you can do.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 4)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Reflection Section

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.purple)
                Text("Reflection (optional)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("How do you feel about today?")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            TextEditor(text: $reflectionText)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
                .overlay(
                    Group {
                        if reflectionText.isEmpty {
                            Text("Share your thoughts about today's tasks...")
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Tomorrow Preview Section

    private var tomorrowPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sunrise.fill")
                    .foregroundColor(.orange)
                Text("Tomorrow's Tasks")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(tomorrowTasks.count) tasks")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            if tomorrowTasks.isEmpty {
                Text("No tasks scheduled for tomorrow yet.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                ForEach(TimeBlock.allCases) { block in
                    let blockTasks = tomorrowTasks.filter { $0.timeBlock == block }
                    if !blockTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: block.icon)
                                    .font(.caption)
                                    .foregroundColor(block.color)
                                Text(block.label)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            ForEach(blockTasks) { task in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 6, height: 6)

                                    Text(task.name)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        VStack(spacing: 12) {
            Button {
                submitReport()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Evening Report")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(dayRating == 0 || isSubmitting)
            .opacity(dayRating == 0 ? 0.5 : 1)

            // Validation message
            if dayRating == 0 && !isSubmitting {
                Text("Please rate your day to continue")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func loadData() {
        isLoading = true

        Task {
            do {
                let interventions = try await ConvexService.shared.getActiveInterventions()
                await MainActor.run {
                    todaysTasks = interventions.map { TodayTask(from: $0) }
                    // Tomorrow's tasks are the same (daily recurring)
                    tomorrowTasks = interventions.map { TodayTask(from: $0, forTomorrow: true) }
                    isLoading = false
                }
            } catch {
                print("[EveningReport] Error loading tasks: \(error)")
                await MainActor.run {
                    todaysTasks = []
                    tomorrowTasks = []
                    isLoading = false
                }
            }
        }
    }

    private func completeTask(_ task: TodayTask) {
        // Update local state
        if let index = todaysTasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = todaysTasks[index]
            todaysTasks[index] = TodayTask(
                id: updatedTask.id,
                name: updatedTask.name,
                timeBlock: updatedTask.timeBlock,
                isCompleted: true
            )
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Sync with Convex
        Task {
            do {
                _ = try await ConvexService.shared.completeTask(userInterventionId: task.id)
                print("[EveningReport] Task completed: \(task.name)")
            } catch {
                print("[EveningReport] Error completing task: \(error)")
            }
        }
    }

    private func submitReport() {
        isSubmitting = true

        // Collect missed task reasons as JSON string if any tasks were missed
        let missedTasksJson: String? = {
            let missedTasks = todaysTasks.filter { !$0.isCompleted }
            guard !missedTasks.isEmpty else { return nil }

            let tasksData = missedTasks.map { task in
                ["taskId": task.id, "taskName": task.name]
            }

            if let data = try? JSONSerialization.data(withJSONObject: tasksData),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return nil
        }()

        Task {
            do {
                try await ConvexService.shared.submitEveningCheckIn(
                    overallDayRating: dayRating,
                    reflectionText: reflectionText.isEmpty ? nil : reflectionText,
                    tasksMissedReasons: missedTasksJson
                )

                await MainActor.run {
                    isSubmitting = false
                    hasSubmitted = true

                    // Haptic success
                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    // Show success overlay
                    withAnimation {
                        showingSuccess = true
                    }

                    // Dismiss after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to save report. Please try again."
                    print("[EveningReport] Error: \(error)")
                }
            }
        }
    }
}

// MARK: - Extended TodayTask

extension TodayTask {
    init(id: String, name: String, timeBlock: TimeBlock, isCompleted: Bool) {
        self.id = id
        self.name = name
        self.timeBlock = timeBlock
        self.isCompleted = isCompleted
    }

    init(from intervention: ActiveIntervention, forTomorrow: Bool = false) {
        self.id = intervention._id
        self.name = intervention.name
        self.isCompleted = forTomorrow ? false : intervention.todayCompleted

        // Map timing to time block
        switch intervention.timing?.lowercased() {
        case "morning":
            self.timeBlock = .morning
        case "afternoon":
            self.timeBlock = .afternoon
        case "evening":
            self.timeBlock = .evening
        case "before bed", "bedtime":
            self.timeBlock = .bedtime
        default:
            self.timeBlock = .afternoon
        }
    }
}

// MARK: - Preview

#if DEBUG
struct EveningReportView_Previews: PreviewProvider {
    static var previews: some View {
        EveningReportView()
            .environmentObject(ThemeManager.shared)
    }
}
#endif
