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
    @State private var mood: Int = 0
    @State private var focusLevel: Int = 0
    @State private var todaysTasks: [TodayTask] = []
    @State private var isLoading = true
    @State private var hasSubmitted = false
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?

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

                    // Mood Section
                    moodSection

                    // Focus Section
                    focusSection

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
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("Check-in Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Have a great day!")
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

    // MARK: - Mood Section

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How's your mood?")
                .font(.headline)
                .foregroundColor(theme.textOnCard)

            HStack(spacing: 12) {
                ForEach(MoodOption.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            mood = option.rawValue
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            Text(option.emoji)
                                .font(.title)

                            Text(option.label)
                                .font(.caption)
                                .foregroundColor(mood == option.rawValue ? theme.textOnCard : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(mood == option.rawValue ? option.color.opacity(0.2) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    mood == option.rawValue ? option.color : Color.clear,
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

    // MARK: - Focus Section

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mental clarity?")
                .font(.headline)
                .foregroundColor(theme.textOnCard)

            HStack(spacing: 12) {
                ForEach(FocusOption.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            focusLevel = option.rawValue
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            Text(option.emoji)
                                .font(.title)

                            Text(option.label)
                                .font(.caption)
                                .foregroundColor(focusLevel == option.rawValue ? theme.textOnCard : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(focusLevel == option.rawValue ? option.color.opacity(0.2) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    focusLevel == option.rawValue ? option.color : Color.clear,
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
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.primary))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Check-in")
                    }
                }
                .font(.headline)
                .foregroundColor(theme.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.primary.opacity(0.15))
                .cornerRadius(12)
            }
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)

            // Validation message
            if !canSubmit && !isSubmitting {
                Text("Please rate your sleep, energy, mood, and focus")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var canSubmit: Bool {
        sleepQuality > 0 && energyLevel > 0 && mood > 0 && focusLevel > 0 && !isSubmitting
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
        isSubmitting = true

        Task {
            do {
                try await ConvexService.shared.submitMorningCheckIn(
                    sleepQuality: sleepQuality,
                    energyLevel: energyLevel,
                    mood: mood,
                    focusLevel: focusLevel
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
                    errorMessage = "Failed to save check-in. Please try again."
                    print("[MorningCheckIn] Error: \(error)")
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum MoodOption: Int, CaseIterable, Identifiable {
    case veryLow = 1
    case low = 2
    case neutral = 3
    case good = 4
    case great = 5

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .veryLow: return "😢"
        case .low: return "😔"
        case .neutral: return "😐"
        case .good: return "🙂"
        case .great: return "😄"
        }
    }

    var label: String {
        switch self {
        case .veryLow: return "Bad"
        case .low: return "Low"
        case .neutral: return "Okay"
        case .good: return "Good"
        case .great: return "Great"
        }
    }

    var color: Color {
        switch self {
        case .veryLow: return .red
        case .low: return .orange
        case .neutral: return .yellow
        case .good: return .green
        case .great: return .mint
        }
    }
}

enum FocusOption: Int, CaseIterable, Identifiable {
    case foggy = 1
    case hazy = 2
    case clearing = 3
    case clear = 4
    case sharp = 5

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .foggy: return "🌫️"
        case .hazy: return "☁️"
        case .clearing: return "⛅"
        case .clear: return "🧠"
        case .sharp: return "💎"
        }
    }

    var label: String {
        switch self {
        case .foggy: return "Foggy"
        case .hazy: return "Hazy"
        case .clearing: return "Okay"
        case .clear: return "Clear"
        case .sharp: return "Sharp"
        }
    }

    var color: Color {
        switch self {
        case .foggy: return .gray
        case .hazy: return .blue.opacity(0.6)
        case .clearing: return .teal
        case .clear: return .cyan
        case .sharp: return .purple
        }
    }
}

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
