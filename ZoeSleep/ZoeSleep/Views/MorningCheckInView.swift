//
//  MorningCheckInView.swift
//  ZoeSleep
//
//  Morning check-in view for quick sleep quality rating and task preview.
//  Shown at 7:00 AM notification or when user opens app in the morning.
//
//  Contents:
//  - Sleep quality quick rating (1-5 stars)
//  - Energy level assessment
//  - Today's task preview with time blocks
//  - Link to log last night's sleep
//

import SwiftUI

struct MorningCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var sleepQuality: Int = 0
    @State private var energyLevel: Int = 0
    @State private var todaysTasks: [TodayTask] = []
    @State private var isLoading = true
    @State private var hasSubmitted = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    greetingHeader

                    // Sleep Quality Rating
                    sleepQualitySection

                    // Energy Level
                    energyLevelSection

                    // Today's Tasks Preview
                    taskPreviewSection

                    // Actions
                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Morning Check-in")
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
                loadTodaysTasks()
            }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(getGreeting())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.textOnCard)

            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundColor(theme.textOnCardSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Sleep Quality Section

    private var sleepQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did you sleep?")
                .font(.headline)
                .foregroundColor(theme.textOnCard)

            HStack(spacing: 16) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            sleepQuality = rating
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: rating <= sleepQuality ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(rating <= sleepQuality ? .yellow : .gray.opacity(0.5))

                            Text(sleepQualityLabel(for: rating))
                                .font(.caption2)
                                .foregroundColor(rating == sleepQuality ? theme.textOnCard : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    // MARK: - Energy Level Section

    private var energyLevelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy level right now?")
                .font(.headline)
                .foregroundColor(theme.textOnCard)

            HStack(spacing: 12) {
                ForEach(EnergyOption.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            energyLevel = option.rawValue
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            Text(option.emoji)
                                .font(.title)

                            Text(option.label)
                                .font(.caption)
                                .foregroundColor(energyLevel == option.rawValue ? theme.textOnCard : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(energyLevel == option.rawValue ? option.color.opacity(0.2) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    energyLevel == option.rawValue ? option.color : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    // MARK: - Task Preview Section

    private var taskPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Tasks")
                    .font(.headline)
                    .foregroundColor(theme.textOnCard)

                Spacer()

                Text("\(todaysTasks.count) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if todaysTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("No tasks scheduled for today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                // Group by time block
                ForEach(TimeBlock.allCases) { block in
                    let blockTasks = todaysTasks.filter { $0.timeBlock == block }
                    if !blockTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: block.icon)
                                    .foregroundColor(block.color)
                                Text(block.label)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }

                            ForEach(blockTasks) { task in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(task.isCompleted ? Color.green : Color.gray.opacity(0.3))
                                        .frame(width: 8, height: 8)

                                    Text(task.name)
                                        .font(.subheadline)
                                        .foregroundColor(task.isCompleted ? .secondary : theme.textOnCard)
                                        .strikethrough(task.isCompleted)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Log sleep button
            NavigationLink {
                // Navigate to sleep log questionnaire
                Text("Sleep Log") // TODO: Replace with actual SleepLogView
            } label: {
                HStack {
                    Image(systemName: "bed.double.fill")
                    Text("Log Last Night's Sleep")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [theme.primary, theme.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            // Submit check-in
            Button {
                submitCheckIn()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Check-in")
                }
                .font(.headline)
                .foregroundColor(theme.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.primary.opacity(0.15))
                .cornerRadius(12)
            }
            .disabled(sleepQuality == 0 || energyLevel == 0)
            .opacity((sleepQuality == 0 || energyLevel == 0) ? 0.5 : 1)
        }
    }

    // MARK: - Helpers

    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning!" }
        if hour < 17 { return "Good afternoon!" }
        return "Good evening!"
    }

    private func sleepQualityLabel(for rating: Int) -> String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return ""
        }
    }

    private func loadTodaysTasks() {
        isLoading = true

        Task {
            do {
                let interventions = try await ConvexService.shared.getActiveInterventions()
                await MainActor.run {
                    todaysTasks = interventions.map { TodayTask(from: $0) }
                    isLoading = false
                }
            } catch {
                print("[MorningCheckIn] Error loading tasks: \(error)")
                await MainActor.run {
                    todaysTasks = []
                    isLoading = false
                }
            }
        }
    }

    private func submitCheckIn() {
        // Save check-in data
        let checkInData: [String: Any] = [
            "date": Date().ISO8601Format(),
            "sleepQuality": sleepQuality,
            "energyLevel": energyLevel,
            "type": "morning"
        ]

        print("[MorningCheckIn] Submitted: \(checkInData)")

        // TODO: Save to Convex when endpoint is ready
        // For now, just dismiss
        hasSubmitted = true

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Dismiss after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - Supporting Types

enum EnergyOption: Int, CaseIterable, Identifiable {
    case exhausted = 1
    case tired = 2
    case okay = 3
    case energized = 4

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .exhausted: return "😫"
        case .tired: return "😴"
        case .okay: return "🙂"
        case .energized: return "⚡"
        }
    }

    var label: String {
        switch self {
        case .exhausted: return "Exhausted"
        case .tired: return "Tired"
        case .okay: return "Okay"
        case .energized: return "Energized"
        }
    }

    var color: Color {
        switch self {
        case .exhausted: return .red
        case .tired: return .orange
        case .okay: return .yellow
        case .energized: return .green
        }
    }
}

enum TimeBlock: String, CaseIterable, Identifiable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case bedtime = "Bedtime"

    var id: String { rawValue }

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .afternoon: return "sun.min.fill"
        case .evening: return "sunset.fill"
        case .bedtime: return "moon.fill"
        }
    }

    var color: Color {
        switch self {
        case .morning: return .orange
        case .afternoon: return .blue
        case .evening: return .purple
        case .bedtime: return .indigo
        }
    }
}

struct TodayTask: Identifiable {
    let id: String
    let name: String
    let timeBlock: TimeBlock
    let isCompleted: Bool

    init(from intervention: ActiveIntervention) {
        self.id = intervention._id
        self.name = intervention.name
        self.isCompleted = intervention.todayCompleted

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
            self.timeBlock = .afternoon // Default
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MorningCheckInView_Previews: PreviewProvider {
    static var previews: some View {
        MorningCheckInView()
            .environmentObject(ThemeManager.shared)
    }
}
#endif
