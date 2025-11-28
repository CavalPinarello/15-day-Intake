//
//  ContentView.swift
//  Zoe Sleep for Longevity System
//
//  Main app content with dashboard and navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            if authManager.isAuthenticated {
                MainDashboardView()
            } else {
                AuthenticationView()
            }
        }
        .onAppear {
            authManager.checkAuthenticationStatus()
        }
    }
}

struct MainDashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var questionnaireManager = QuestionnaireManager.shared

    @State private var currentDay: Int = 1
    @State private var showingHealthKit = false
    @State private var showingJourneyOverview = false

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView

                // Journey Progress Card
                journeyProgressCard

                // HealthKit Status Card
                healthKitStatusCard

                // Today's Tasks Card
                todaysTasksCard

                // Gateway Status (if any triggered)
                gatewayStatusCard

                // Quick Actions
                quickActionsCard
            }
            .padding()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingHealthKit) {
            HealthKitIntegrationView()
        }
        .sheet(isPresented: $showingJourneyOverview) {
            JourneyOverviewView(currentDay: $currentDay)
                .environmentObject(themeManager)
        }
        .onAppear {
            loadProgress()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Zoe Sleep")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primary)

                Text(getGreeting())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Settings gear icon
            NavigationLink {
                SettingsView()
                    .environmentObject(themeManager)
                    .environmentObject(authManager)
                    .environmentObject(questionnaireManager)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(theme.primary)
            }
            .padding(.trailing, 8)

            Menu {
                Button(action: { showingJourneyOverview = true }) {
                    Label("Journey Overview", systemImage: "calendar")
                }
                Button(action: { showingHealthKit = true }) {
                    Label("HealthKit Settings", systemImage: "heart")
                }
                Divider()
                Button(role: .destructive, action: { authManager.signOut() }) {
                    Label("Sign Out", systemImage: "arrow.right.square")
                }
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(theme.primary)
            }
        }
    }

    // MARK: - Journey Progress Card

    private var journeyProgressCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("15-Day Sleep Journey")
                        .font(.headline)
                    Text("Day \(currentDay) of 15")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primary)
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(theme.inactive, lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: CGFloat(currentDay) / 15.0)
                        .stroke(theme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int((Double(currentDay) / 15.0) * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }

            // Day indicators
            HStack(spacing: 4) {
                ForEach(1...15, id: \.self) { day in
                    Circle()
                        .fill(dayColor(for: day))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(day == currentDay ? "\(day)" : "")
                                .font(.system(size: 8))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            }

            // Day type indicator
            if currentDay <= 5 {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(theme.corePhase)
                    Text("Core Assessment Phase (Days 1-5)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundColor(theme.expansionPhase)
                    Text("Personalized Expansion Phase")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(theme.backgroundTint)
        .cornerRadius(16)
    }

    private func dayColor(for day: Int) -> Color {
        if day < currentDay {
            return theme.completed
        } else if day == currentDay {
            return theme.active
        } else {
            return theme.inactive
        }
    }

    // MARK: - HealthKit Status Card

    private var healthKitStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: healthKitManager.isAuthorized ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(healthKitManager.isAuthorized ? theme.health : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(healthKitManager.isAuthorized ? "Apple Health Connected" : "Connect Apple Health")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(healthKitManager.isAuthorized ? "Sleep data will be auto-synced" : "Enable automatic sleep tracking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !healthKitManager.isAuthorized {
                    Button("Connect") {
                        showingHealthKit = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary)
                    .controlSize(.small)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.success)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Today's Tasks Card

    private var todaysTasksCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Tasks")
                    .font(.headline)
                Spacer()
                if let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }) {
                    Text("~\(config.estimatedMinutes + 2) min total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.backgroundTint)
                        .cornerRadius(8)
                }
            }

            // Sleep Log Section Card (Blue)
            NavigationLink(destination: QuestionnaireView(currentDay: $currentDay).environmentObject(healthKitManager).environmentObject(themeManager)) {
                SectionTaskCard(
                    section: .sleepLog,
                    questionCount: 5,
                    estimatedMinutes: 2,
                    isCompleted: false
                )
            }

            // Day Assessment Section Card (Purple)
            NavigationLink(destination: QuestionnaireView(currentDay: $currentDay).environmentObject(healthKitManager).environmentObject(themeManager)) {
                SectionTaskCard(
                    section: .assessment,
                    title: getDayTitle(),
                    subtitle: getDayDescription(),
                    questionCount: getAssessmentQuestionCount(),
                    estimatedMinutes: getAssessmentMinutes(),
                    isCompleted: false
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private func getAssessmentQuestionCount() -> Int {
        guard let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }) else {
            return 10
        }
        // Rough estimate based on day
        switch currentDay {
        case 1: return 12
        case 2: return 12
        case 3: return 8
        case 4: return 9
        case 5: return 10
        default: return config.estimatedMinutes / 2 // Expansion days vary
        }
    }

    private func getAssessmentMinutes() -> Int {
        guard let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }) else {
            return 10
        }
        return config.estimatedMinutes
    }

    // MARK: - Gateway Status Card

    @ViewBuilder
    private var gatewayStatusCard: some View {
        let triggeredGateways = questionnaireManager.gatewayStates.filter { $0.triggered }

        if !triggeredGateways.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.warning)
                    Text("Personalized Assessments Triggered")
                        .font(.headline)
                }

                Text("Based on your responses, the following specialized assessments have been added to your journey:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(triggeredGateways, id: \.id) { gateway in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                            .font(.caption)
                        Text(gateway.gatewayType.displayName)
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(theme.warning.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Quick Actions Card

    private var quickActionsCard: some View {
        VStack(spacing: 12) {
            // Treatment Mode (visible after Day 15 or with active interventions)
            if currentDay > 15 {
                NavigationLink(destination: TreatmentView().environmentObject(themeManager)) {
                    QuickActionRow(
                        icon: "list.bullet.clipboard.fill",
                        iconColor: theme.accent,
                        title: "Treatment Tasks",
                        subtitle: "Daily tasks from your physician",
                        theme: theme
                    )
                }
            }

            NavigationLink(destination: SleepDiaryHistoryView()) {
                QuickActionRow(
                    icon: "calendar",
                    iconColor: theme.sleepDiary,
                    title: "Sleep Diary History",
                    subtitle: "View your sleep log entries",
                    theme: theme
                )
            }

            NavigationLink(destination: InsightsView()) {
                QuickActionRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: theme.insights,
                    title: "Sleep Insights",
                    subtitle: "View patterns and recommendations",
                    theme: theme
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    private func getDayTitle() -> String {
        guard let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }) else {
            return "Day \(currentDay) Assessment"
        }
        return config.title
    }

    private func getDayDescription() -> String {
        guard let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }) else {
            return "Complete today's questions"
        }
        return config.description
    }

    private func loadProgress() {
        Task {
            await questionnaireManager.loadJourneyProgress()
            if let progress = questionnaireManager.journeyProgress {
                currentDay = progress.currentDay
            }
        }
    }
}

// MARK: - Task Row Component

struct TaskRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isCompleted: Bool
    var theme: ColorTheme = ColorTheme.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.success)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Quick Action Row Component

struct QuickActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var theme: ColorTheme = ColorTheme.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Section Task Card

struct SectionTaskCard: View {
    let section: QuestionnaireSection
    var title: String? = nil
    var subtitle: String? = nil
    let questionCount: Int
    let estimatedMinutes: Int
    let isCompleted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with section badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: section.icon)
                        .font(.caption)
                    Text(section == .sleepLog ? "SLEEP LOG" : "ASSESSMENT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(section.accentColor)
                .cornerRadius(6)

                Spacer()

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    HStack(spacing: 4) {
                        Text("\(questionCount) Q")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("•")
                            .font(.caption)
                        Text("~\(estimatedMinutes) min")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            // Title
            Text(title ?? section.title)
                .font(.headline)
                .foregroundColor(.primary)

            // Subtitle/Description
            Text(subtitle ?? section.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Action indicator
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text(isCompleted ? "Completed" : "Start")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: isCompleted ? "checkmark" : "arrow.right")
                        .font(.caption)
                }
                .foregroundColor(isCompleted ? .green : section.accentColor)
            }
        }
        .padding(16)
        .background(section.backgroundColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(section.accentColor.opacity(0.3), lineWidth: 1)
        )
        .opacity(isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Placeholder Views

struct JourneyOverviewView: View {
    @Binding var currentDay: Int
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(QuestionnaireManager.dayConfigurations, id: \.id) { config in
                        DayOverviewCard(config: config, currentDay: currentDay, theme: theme)
                    }
                }
                .padding()
            }
            .navigationTitle("Journey Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.primary)
                }
            }
        }
    }
}

struct DayOverviewCard: View {
    let config: DayConfiguration
    let currentDay: Int
    var theme: ColorTheme = ColorTheme.shared

    var body: some View {
        HStack(spacing: 12) {
            // Day number circle
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 44, height: 44)
                Text("\(config.dayNumber)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(config.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(config.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if config.isExpansionDay {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.circle")
                            .font(.caption2)
                        Text("Expansion Day")
                            .font(.caption2)
                    }
                    .foregroundColor(theme.secondary)
                }
            }

            Spacer()

            Text("~\(config.estimatedMinutes) min")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
    }

    private var circleColor: Color {
        if config.dayNumber < currentDay {
            return theme.completed
        } else if config.dayNumber == currentDay {
            return theme.active
        } else {
            return Color.gray
        }
    }

    private var backgroundColor: Color {
        if config.dayNumber == currentDay {
            return theme.backgroundTint
        }
        return Color(.secondarySystemBackground)
    }
}

struct SleepDiaryHistoryView: View {
    var body: some View {
        VStack {
            Text("Sleep Diary History")
                .font(.title)
                .padding()

            Text("Your sleep log entries will appear here")
                .foregroundColor(.secondary)

            Spacer()
        }
        .navigationTitle("Sleep Diary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InsightsView: View {
    var body: some View {
        VStack {
            Text("Sleep Insights")
                .font(.title)
                .padding()

            Text("Personalized insights will appear after completing the assessment")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SleepDiaryView: View {
    var body: some View {
        SleepDiaryHistoryView()
    }
}

// MARK: - Preview

#Preview {
    let authManager = AuthenticationManager()
    ContentView()
        .environmentObject(authManager)
        .environmentObject(HealthKitManager(authManager: authManager))
}
