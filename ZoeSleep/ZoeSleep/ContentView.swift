//
//  ContentView.swift
//  Zoe Sleep for Longevity System
//
//  Main app content with dashboard and navigation
//  Note: Authentication and onboarding routing is handled by AppRootView in ZoeSleepApp.swift
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            MainDashboardView()
        }
    }
}

struct MainDashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var questionnaireManager = QuestionnaireManager.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var currentDay: Int = 1
    @State private var showingJourneyOverview = false
    @State private var lastRefreshTime: Date = Date()
    @State private var needsRefresh = false
    @State private var refreshTimer: Timer?
    @State private var isRefreshing = false

    // Poll every 5 seconds when app is active (for cross-device sync)
    private let refreshInterval: TimeInterval = 5.0

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            // Animated wave background for dashboard
            DashboardWaveBackground()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    headerView

                    // Journey Progress Card
                    journeyProgressCard

                    // Today's Tasks Card
                    todaysTasksCard

                    // Gateway Status (if any triggered)
                    gatewayStatusCard

                    // Quick Actions
                    quickActionsCard
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingJourneyOverview) {
            JourneyOverviewView(currentDay: $currentDay)
                .environmentObject(themeManager)
        }
        .onAppear {
            loadProgress()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Refresh immediately when app becomes active
                Task {
                    await refreshFromConvex()
                }
                // Start polling timer for cross-device sync
                startRefreshTimer()
            case .inactive, .background:
                // Stop polling when app is not active
                stopRefreshTimer()
            @unknown default:
                break
            }
        }
        .onChange(of: questionnaireManager.journeyProgress?.currentDay) { _, newDay in
            // Update UI when journey progress changes (from other device)
            if let day = newDay {
                withAnimation {
                    currentDay = day
                }
            }
        }
        .onChange(of: questionnaireManager.journeyProgress?.sleepLogCompleted) { _, newValue in
            // Log section completion change for debugging
            print("[iOS Dashboard] sleepLogCompleted changed to: \(newValue ?? false)")
        }
        .onChange(of: questionnaireManager.journeyProgress?.assessmentCompleted) { _, newValue in
            // Log section completion change for debugging
            print("[iOS Dashboard] assessmentCompleted changed to: \(newValue ?? false)")
        }
        .refreshable {
            // Pull-to-refresh to manually sync from Convex
            await refreshFromConvex(silent: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .questionnaireProgressDidChange)) { _ in
            // Refresh when questionnaire signals progress change
            Task {
                await refreshFromConvex(silent: false)
            }
        }
    }

    // MARK: - Refresh Timer (for cross-device sync)

    private func startRefreshTimer() {
        // Don't start if already running
        guard refreshTimer == nil else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshFromConvex(silent: true)
            }
        }
        print("[iOS Dashboard] Started refresh timer (interval: \(refreshInterval)s)")
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("[iOS Dashboard] Stopped refresh timer")
    }

    private func refreshFromConvex(silent: Bool = false) async {
        // Avoid refreshing too frequently (min 2 seconds between refreshes)
        guard Date().timeIntervalSince(lastRefreshTime) > 2 else {
            if !silent {
                print("[iOS Dashboard] Skipping refresh (too soon)")
            }
            return
        }

        // Don't refresh if already refreshing
        guard !isRefreshing else { return }
        isRefreshing = true
        lastRefreshTime = Date()

        if !silent {
            print("[iOS Dashboard] Refreshing from Convex...")
        }

        await questionnaireManager.loadJourneyProgress()

        await MainActor.run {
            if let progress = questionnaireManager.journeyProgress {
                // Only update if there's a change
                if currentDay != progress.currentDay {
                    withAnimation {
                        currentDay = progress.currentDay
                    }
                    print("[iOS Dashboard] Day updated: \(progress.currentDay)")
                }

                if !silent {
                    print("[iOS Dashboard] Refreshed: Day \(progress.currentDay), sleepLog=\(progress.sleepLogCompleted), assessment=\(progress.assessmentCompleted)")
                }
            }
            isRefreshing = false
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

                // Personalized greeting with user's name
                if !OnboardingManager.shared.profile.name.isEmpty {
                    Text("\(getGreeting()), \(OnboardingManager.shared.profile.name)")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text(getGreeting())
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
            }

            Spacer()

            // Sync button - manually refresh from Convex
            Button {
                Task {
                    print("[iOS] Manual sync triggered")
                    await questionnaireManager.loadJourneyProgress()
                    if let progress = questionnaireManager.journeyProgress {
                        currentDay = progress.currentDay
                        print("[iOS] Synced from Convex: Day \(progress.currentDay)")
                    }
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(theme.primary)
            }
            .padding(.trailing, 8)

            // Profile button - navigates to unified profile/settings view
            NavigationLink {
                ProfileSettingsView()
                    .environmentObject(themeManager)
                    .environmentObject(authManager)
                    .environmentObject(healthKitManager)
            } label: {
                // Profile avatar with user initial or icon
                ZStack {
                    Circle()
                        .fill(theme.primary.opacity(0.2))
                        .frame(width: 40, height: 40)

                    if !OnboardingManager.shared.profile.name.isEmpty {
                        Text(String(OnboardingManager.shared.profile.name.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(theme.primary)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.body)
                            .foregroundColor(theme.primary)
                    }
                }
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
                        .foregroundColor(theme.textPrimary)
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
                        .foregroundColor(theme.textSecondary)
                }
            } else {
                HStack {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundColor(theme.expansionPhase)
                    Text("Personalized Expansion Phase")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.4))
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

    // MARK: - Today's Tasks Card

    private var isDayComplete: Bool {
        (questionnaireManager.journeyProgress?.sleepLogCompleted ?? false) &&
        (questionnaireManager.journeyProgress?.assessmentCompleted ?? false)
    }

    private var todaysTasksCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Tasks")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if isDayComplete {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                        Text("Complete")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(theme.success)
                    }
                } else if let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }) {
                    Text("~\(config.estimatedMinutes + 2) min total")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.backgroundTint)
                        .cornerRadius(8)
                }
            }

            // Day Complete Celebration View
            if isDayComplete {
                DayCompleteCelebrationView(
                    currentDay: currentDay,
                    isDebugMode: themeManager.debugMode,
                    onAdvanceDay: advanceToNextDay
                )
            }

            // Sleep Log Section Card (Blue) - Stanford Sleep Log, done daily
            NavigationLink(destination: QuestionnaireView(currentDay: $currentDay, startSection: .sleepLog, sectionOnly: true).environmentObject(healthKitManager).environmentObject(themeManager)) {
                SectionTaskCard(
                    section: .sleepLog,
                    questionCount: 5,
                    estimatedMinutes: 2,
                    isCompleted: questionnaireManager.journeyProgress?.sleepLogCompleted ?? false,
                    whyExplanation: getSleepLogWhyExplanation()
                )
            }
            .disabled(questionnaireManager.journeyProgress?.sleepLogCompleted ?? false)

            // Day Assessment Section Card (Purple) - Adaptive questionnaire with gateway questions
            NavigationLink(destination: QuestionnaireView(currentDay: $currentDay, startSection: .assessment, sectionOnly: true).environmentObject(healthKitManager).environmentObject(themeManager)) {
                SectionTaskCard(
                    section: .assessment,
                    title: getDayTitle(),
                    subtitle: getDayDescription(),
                    questionCount: getAssessmentQuestionCount(),
                    estimatedMinutes: getAssessmentMinutes(),
                    isCompleted: questionnaireManager.journeyProgress?.assessmentCompleted ?? false,
                    whyExplanation: getAssessmentWhyExplanation()
                )
            }
            .disabled(questionnaireManager.journeyProgress?.assessmentCompleted ?? false)
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.4))
        .cornerRadius(16)
    }

    private func advanceToNextDay() {
        guard currentDay < 15 else { return }
        Task {
            do {
                // Pass debugMode flag - only bypasses time check, NOT completion check
                let response = try await ConvexService.shared.advanceToNextDay(debugMode: themeManager.debugMode)

                if response.success {
                    await questionnaireManager.loadJourneyProgress()
                    await MainActor.run {
                        if let newDay = response.newDay {
                            withAnimation {
                                currentDay = newDay
                            }
                        }
                        NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)
                    }
                    print("[iOS] Advanced to Day \(response.newDay ?? currentDay)")
                } else {
                    // Server rejected advancement - sections not complete
                    print("[iOS] Cannot advance: \(response.error ?? "Unknown error")")
                    print("[iOS] Sleep Log: \(response.sleepLogCompleted ?? false), Assessment: \(response.assessmentCompleted ?? false)")
                }
            } catch {
                print("[iOS] Error advancing day: \(error)")
            }
        }
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

    /// Get contextual explanation for why the sleep log matters
    private func getSleepLogWhyExplanation() -> String {
        return "Recording your subjective sleep perception daily helps us compare it with your wearable data and identify patterns."
    }

    /// Get contextual explanation for why this day's assessment matters
    private func getAssessmentWhyExplanation() -> String {
        let explanations: [Int: String] = [
            1: "We're getting to know you and establishing your baseline sleep quality.",
            2: "Understanding your sleep history and patterns helps identify what might be causing your sleep issues.",
            3: "Sleep and mental health are closely connected. These questions help us see the full picture.",
            4: "Physical health factors can significantly impact sleep. We're checking for anything relevant.",
            5: "Your environment and daily habits play a big role in sleep quality.",
            6: "Based on your responses, we're taking a deeper look at insomnia symptoms.",
            7: "Your natural sleep-wake cycle affects when you sleep best.",
            8: "We're checking in on mood and anxiety, which can affect sleep quality.",
            9: "Daytime sleepiness tells us important things about your sleep quality.",
            10: "We're screening for sleep apnea, a common but often undiagnosed condition.",
            11: "Pain and physical discomfort can disrupt sleep. We're assessing if this applies to you.",
            12: "Your body clock affects when you feel sleepy and alert.",
            13: "What you eat can affect how you sleep. We're looking at dietary factors.",
            14: "Sometimes our beliefs about sleep can make problems worse.",
            15: "We're wrapping up your assessment and preparing your personalized recommendations.",
        ]
        return explanations[currentDay] ?? "These questions help us understand your unique sleep needs."
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
                    .foregroundColor(theme.textSecondary)

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
            .background(GlassyCardBackground(opacity: 0.35, tint: theme.warning))
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
                    .foregroundColor(theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.success)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(12)
        .background(GlassyCardBackground(opacity: 0.35))
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
                    .foregroundColor(theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(theme.textSecondary)
        }
        .padding(12)
        .background(GlassyCardBackground(opacity: 0.35))
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
    var whyExplanation: String? = nil  // Contextual explanation for why this matters
    var theme: ColorTheme = ColorTheme.shared

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
                .foregroundColor(theme.textOnPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.primary)  // Use circadian-safe primary color
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
                    .foregroundColor(theme.textSecondary)
                }
            }

            // Title
            Text(title ?? section.title)
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            // Subtitle/Description
            Text(subtitle ?? section.description)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .lineLimit(2)

            // Why this matters (contextual explanation)
            if let why = whyExplanation, !isCompleted {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(theme.primary)
                    Text(why)
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(3)
                }
                .padding(10)
                .background(theme.primary.opacity(0.15))
                .cornerRadius(8)
            }

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
                .foregroundColor(isCompleted ? .green : theme.primary)
            }
        }
        .padding(16)
        .background(GlassyCardBackground(opacity: 0.35, tint: theme.primary))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            theme.primary.opacity(0.4),
                            theme.primary.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
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
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)

                if config.isExpansionDay {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.circle")
                            .font(.caption2)
                        Text("Expansion Day")
                            .font(.caption2)
                    }
                    .foregroundColor(theme.textSecondary)
                }
            }

            Spacer()

            Text("~\(config.estimatedMinutes) min")
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
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
                .foregroundColor(ColorTheme.shared.textSecondary)

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
                .foregroundColor(ColorTheme.shared.textSecondary)
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

// MARK: - Day Complete Celebration View

struct DayCompleteCelebrationView: View {
    let currentDay: Int
    let isDebugMode: Bool
    let onAdvanceDay: () -> Void

    @State private var timeUntilUnlock: String = ""
    @State private var isUnlocked: Bool = false
    @State private var timer: Timer?

    private var theme: ColorTheme { ColorTheme.shared }

    var body: some View {
        VStack(spacing: 16) {
            // Celebration header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.success.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundColor(theme.success)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Day \(currentDay) Complete!")
                        .font(.headline)
                        .foregroundColor(theme.success)
                    Text(currentDay < 15 ? "Great progress on your sleep journey" : "Congratulations! Journey complete!")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()
            }

            // Next day info
            if currentDay < 15 {
                Divider()

                if isDebugMode {
                    // Debug mode: Show advance button immediately (bypasses time check only)
                    Button(action: onAdvanceDay) {
                        HStack {
                            Image(systemName: "forward.fill")
                                .font(.subheadline)
                            Text("Advance to Day \(currentDay + 1)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.primary)
                        .cornerRadius(10)
                    }

                    Text("Debug mode: Time check bypassed")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                } else if isUnlocked {
                    // Day unlocked (past 4 AM) - show advance button
                    Button(action: onAdvanceDay) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.subheadline)
                            Text("Start Day \(currentDay + 1)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.primary)
                        .cornerRadius(10)
                    }
                } else {
                    // Countdown to 4 AM
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(theme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Day \(currentDay + 1) unlocks at 4:00 AM")
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimary)
                            Text(timeUntilUnlock)
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                                .monospacedDigit()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            } else {
                // Journey complete message
                Divider()
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text("You've completed the 15-day sleep assessment!")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(16)
        .background(theme.success.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.success.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            updateCountdown()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateCountdown()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateCountdown() {
        let now = Date()
        let calendar = Calendar.current

        // Find next 4 AM (not 5 AM - changed per user request)
        var nextUnlock: Date
        let todayAt4AM = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: now)!

        if now < todayAt4AM {
            // Today's 4 AM hasn't happened yet
            nextUnlock = todayAt4AM
        } else {
            // Next 4 AM is tomorrow
            nextUnlock = calendar.date(byAdding: .day, value: 1, to: todayAt4AM)!
        }

        // Check if already unlocked
        if now >= nextUnlock {
            isUnlocked = true
            timeUntilUnlock = "Ready now!"
            return
        }

        isUnlocked = false

        // Calculate time remaining
        let components = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextUnlock)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0

        if hours > 0 {
            timeUntilUnlock = "\(hours)h \(minutes)m \(seconds)s remaining"
        } else if minutes > 0 {
            timeUntilUnlock = "\(minutes)m \(seconds)s remaining"
        } else {
            timeUntilUnlock = "\(seconds)s remaining"
        }
    }
}

// MARK: - Preview

#Preview {
    let authManager = AuthenticationManager()
    ContentView()
        .environmentObject(authManager)
        .environmentObject(HealthKitManager(authManager: authManager))
}
