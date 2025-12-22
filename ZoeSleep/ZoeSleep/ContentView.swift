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
    @ObservedObject private var journeyPhaseManager = JourneyPhaseManager.shared

    var body: some View {
        NavigationStack {
            phaseAwareContent
        }
        .onAppear {
            // Load journey status when view appears
            if let userId = authManager.user?.id {
                Task {
                    await journeyPhaseManager.loadJourneyStatus(userId: userId)
                }
            }
        }
    }

    @ViewBuilder
    private var phaseAwareContent: some View {
        switch journeyPhaseManager.currentPhase {
        case .intake:
            // 14-day data collection journey
            MainDashboardView()

        case .analysis:
            // Waiting for physician analysis (Day 16+)
            AnalysisPendingView()
                .environmentObject(themeManager)

        case .treatmentPending, .treatmentActive:
            // Treatment plan with session cards
            TreatmentDashboardView()
                .environmentObject(themeManager)
                .environmentObject(authManager)
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

    // Sync status tracking
    @State private var syncStatus: SyncStatus = .synced
    @State private var lastSyncError: String? = nil

    // Navigation to Sleep Diary with pre-selected day
    @State private var navigateToSleepDiary = false
    @State private var sleepDiarySelectedDay: Int? = nil

    // Journey introduction for first-time users
    @State private var showJourneyIntro = false

    // Motivational message - stored to prevent flickering on re-renders
    @State private var motivationalMessage: String = ""

    // Poll every 5 seconds when app is active (for cross-device sync)
    private let refreshInterval: TimeInterval = 5.0

    private var theme: ColorTheme { themeManager.currentTheme }

    enum SyncStatus {
        case synced
        case syncing
        case error
    }

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
        // Journey Introduction for first-time users
        .fullScreenCover(isPresented: $showJourneyIntro) {
            JourneyIntroView(isPresented: $showJourneyIntro)
                .environmentObject(themeManager)
        }
        // Hidden NavigationLink for programmatic navigation to Sleep Diary
        .background(
            NavigationLink(
                destination: SleepDiaryHistoryView(initialDay: sleepDiarySelectedDay)
                    .environmentObject(themeManager),
                isActive: $navigateToSleepDiary
            ) {
                EmptyView()
            }
            .hidden()
        )
        .onAppear {
            loadProgress()
            startRefreshTimer()

            // Set motivational message once to prevent flickering
            if motivationalMessage.isEmpty {
                motivationalMessage = FriendlyCopy.randomDayMessage()
            }

            // Show journey introduction for first-time users
            if !OnboardingManager.shared.hasSeenJourneyIntro {
                // Small delay to ensure dashboard is visible first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showJourneyIntro = true
                }
            }
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
            // Use force=true to bypass throttle since this is an explicit completion notification
            Task {
                await refreshFromConvex(silent: false, force: true)
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

    private func refreshFromConvex(silent: Bool = false, force: Bool = false) async {
        // Avoid refreshing too frequently (min 2 seconds between refreshes)
        // Unless force=true (e.g., after section completion notification)
        guard force || Date().timeIntervalSince(lastRefreshTime) > 2 else {
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
            syncStatus = .syncing
        }

        await questionnaireManager.loadJourneyProgress()

        // Load expansion schedule for Days 6+ (dynamic expansion from Convex)
        if let progress = questionnaireManager.journeyProgress, progress.currentDay >= 6 {
            await questionnaireManager.loadExpansionScheduleForDay(progress.currentDay)
        }

        await MainActor.run {
            // Check if there was an error during the refresh
            if let error = questionnaireManager.error {
                syncStatus = .error
                lastSyncError = error
                print("[iOS Dashboard] Sync error: \(error)")
            } else if let progress = questionnaireManager.journeyProgress {
                syncStatus = .synced
                lastSyncError = nil

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

    // MARK: - Header View (Calm, friendly design)

    private var headerView: some View {
        VStack(spacing: Spacing.lg) {
            // Top bar with sync status and profile
            HStack {
                // Sync status indicator (subtle, only shows when there's an issue)
                if syncStatus == .error {
                    Button {
                        // Tap to retry sync
                        Task {
                            await refreshFromConvex()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.icloud")
                                .font(.caption)
                            Text("Sync issue")
                                .font(.caption2)
                        }
                        .foregroundColor(theme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.warning.opacity(0.15))
                        .clipShape(Capsule())
                    }
                } else if syncStatus == .syncing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Syncing...")
                            .font(.caption2)
                    }
                    .foregroundColor(theme.textSecondary)
                }

                Spacer()

                // Profile button - navigates to unified profile/settings view
                NavigationLink {
                    ProfileSettingsView()
                        .environmentObject(themeManager)
                        .environmentObject(authManager)
                        .environmentObject(healthKitManager)
                } label: {
                    ZStack {
                        Circle()
                            .fill(theme.primary.opacity(0.15))
                            .frame(width: 44, height: 44)

                        if !OnboardingManager.shared.profile.name.isEmpty {
                            Text(String(OnboardingManager.shared.profile.name.prefix(1)).uppercased())
                                .font(.system(size: Typography.headline, weight: .bold, design: .rounded))
                                .foregroundColor(theme.primary)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.body)
                                .foregroundColor(theme.primary)
                        }
                    }
                }
            }

            // Greeting - large, warm, centered
            VStack(spacing: Spacing.xs) {
                let hour = Calendar.current.component(.hour, from: Date())
                let userName = OnboardingManager.shared.profile.name.isEmpty ? nil : OnboardingManager.shared.profile.name

                Text(FriendlyCopy.greeting(for: hour, name: userName))
                    .font(.system(size: Typography.title, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(motivationalMessage)
                    .font(.system(size: Typography.body, weight: .regular, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, Spacing.sm)
        }
    }

    // MARK: - Journey Progress Card (Simplified, calm design)

    private var completedDaysCount: Int {
        questionnaireManager.journeyProgress?.completedDays.count ?? 0
    }

    /// Sanitized completed days - only days before currentDay can be marked as completed
    /// This prevents data integrity issues from showing incorrect progress
    private var validatedCompletedDays: [Int] {
        (questionnaireManager.journeyProgress?.completedDays ?? [])
            .filter { $0 < currentDay }
    }

    private var journeyProgressCard: some View {
        VStack(spacing: Spacing.lg) {
            // Day indicator with percentage
            HStack {
                // Day X of 14
                HStack(spacing: Spacing.xs) {
                    Text("Day \(currentDay)")
                        .font(.system(size: Typography.title3, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textOnCard)

                    Text("of 14")
                        .font(.system(size: Typography.title3, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textOnCardSecondary)
                }

                Spacer()

                // Percentage complete
                Text("\(progressPercentage)%")
                    .font(.system(size: Typography.headline, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primary)
            }

            // Interactive progress dots - tap completed days to view history
            InteractiveProgressDots(
                current: currentDay,
                total: 14,
                completedDays: validatedCompletedDays
            ) { day in
                sleepDiarySelectedDay = day
                navigateToSleepDiary = true
            }

            // Encouraging message based on progress - HIGH CONTRAST
            Text(progressMessage(completedCount: max(0, currentDay - 1)))
                .font(.system(size: Typography.subheadline, weight: .regular, design: .rounded))
                .foregroundColor(theme.textOnCardSecondary)
                .multilineTextAlignment(.center)

            // Hint text for interactive dots
            if currentDay > 1 {
                Text("Tap a completed day to view details")
                    .font(.system(size: Typography.caption, design: .rounded))
                    .foregroundColor(theme.textOnCardMuted)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            GlassyCardBackground(opacity: 0.6)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        )
    }

    private var progressPercentage: Int {
        // Start with completed days (days before current day)
        var daysCompleted = max(0, currentDay - 1)

        // If current day's sections are BOTH complete, count current day as completed too
        // This fixes the 93% bug where Day 14 completion wasn't counted
        if isDayComplete {
            daysCompleted = currentDay
        }

        return Int((Double(daysCompleted) / 14.0) * 100)
    }

    private func progressMessage(completedCount: Int) -> String {
        switch completedCount {
        case 0:
            return "Let's start your sleep journey"
        case 1...4:
            return "Building your sleep profile"
        case 5...9:
            return "Halfway there! Great progress"
        case 10...12:
            return "Almost done! Keep going"
        case 13:
            return "Final day tomorrow!"
        case 14:
            return "Journey complete! Analysis begins soon."
        default:
            return "Journey complete!"
        }
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

    private var sleepLogDone: Bool {
        questionnaireManager.journeyProgress?.sleepLogCompleted ?? false
    }

    private var assessmentDone: Bool {
        questionnaireManager.journeyProgress?.assessmentCompleted ?? false
    }

    /// Check if expansion pack was completed today
    private var expansionPackCompletedToday: Bool {
        questionnaireManager.journeyProgress?.expansionPackCompleted ?? false
    }

    /// Check if there were gateways triggered that HAD expansion options (even if now completed)
    private var hadExpansionPackToday: Bool {
        // Check if any triggered gateways have expansion modules available
        let triggeredGateways = questionnaireManager.gatewayStates.filter { $0.triggered }
        let expansionGateways = triggeredGateways.filter { state in
            QuestionnaireManager.sameDayExpansionModules.keys.contains(state.gatewayType)
        }
        return !expansionGateways.isEmpty && currentDay <= 5
    }

    /// Returns expansion pack info if gateways were triggered and assessment is done
    private var availableExpansionPack: ExpansionPackInfo? {
        // Only show expansion pack after assessment is complete
        guard assessmentDone else { return nil }
        return questionnaireManager.getExpansionPackForDay(currentDay)
    }

    private var todaysTasksCard: some View {
        VStack(spacing: Spacing.lg) {
            // Day Complete Celebration (only if no expansion pack available AND no expansion was done)
            if isDayComplete && availableExpansionPack == nil && !hadExpansionPackToday {
                DayCompleteCelebrationView(
                    currentDay: currentDay,
                    isDebugMode: themeManager.debugMode,
                    onAdvanceDay: advanceToNextDay
                )
            } else if let expansionPack = availableExpansionPack {
                // Show expansion pack card when gateways triggered and assessment done
                VStack(spacing: Spacing.md) {
                    // Header with completion status
                    HStack {
                        Text("Today's focus")
                            .font(.system(size: Typography.subheadline, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textOnCardSecondary)
                        Spacer()
                        Text("2 of 3")
                            .font(.system(size: Typography.caption, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textOnCardMuted)
                    }

                    // Completed tasks
                    TaskRowView(
                        icon: "moon.zzz.fill",
                        title: "Sleep Log",
                        subtitle: "Completed",
                        isCompleted: true
                    )

                    TaskRowView(
                        icon: "list.bullet.clipboard",
                        title: "Assessment",
                        subtitle: "Completed",
                        isCompleted: true
                    )

                    // Expansion pack prompt
                    NavigationLink(destination: ExpansionPackQuestionnaireView(
                        currentDay: $currentDay,
                        expansionInfo: expansionPack
                    ).environmentObject(healthKitManager).environmentObject(themeManager)) {
                        TaskRowView(
                            icon: "sparkles",
                            title: "Deeper Dive",
                            subtitle: expansionPack.shortExplanation,
                            duration: "~\(expansionPack.totalEstimatedMinutes) min",
                            isCompleted: false
                        )
                    }

                    // Skip option
                    Button {
                        // TODO: Mark expansion as skipped and show day complete
                    } label: {
                        Text("Skip for now")
                            .font(.caption)
                            .foregroundColor(theme.textOnCardMuted)
                    }
                }
            } else if isDayComplete && hadExpansionPackToday && expansionPackCompletedToday {
                // Show all 3 tasks completed (including Deeper Dive)
                VStack(spacing: Spacing.md) {
                    // Header with completion status
                    HStack {
                        Text("Today's focus")
                            .font(.system(size: Typography.subheadline, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textOnCardSecondary)
                        Spacer()
                        Text("3 of 3")
                            .font(.system(size: Typography.caption, weight: .medium, design: .rounded))
                            .foregroundColor(theme.success)
                    }

                    // All tasks completed
                    TaskRowView(
                        icon: "moon.zzz.fill",
                        title: "Sleep Log",
                        subtitle: "Completed",
                        isCompleted: true
                    )

                    TaskRowView(
                        icon: "list.bullet.clipboard",
                        title: "Assessment",
                        subtitle: "Completed",
                        isCompleted: true
                    )

                    TaskRowView(
                        icon: "sparkles",
                        title: "Deeper Dive",
                        subtitle: "Completed",
                        isCompleted: true
                    )

                    // Day complete celebration button
                    DayCompleteCelebrationView(
                        currentDay: currentDay,
                        isDebugMode: themeManager.debugMode,
                        onAdvanceDay: advanceToNextDay
                    )
                }
            } else {
                // Today's focus - clean task list
                VStack(spacing: Spacing.md) {
                    // Header with completion counter
                    HStack {
                        Text("Today's focus")
                            .font(.system(size: Typography.subheadline, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textOnCardSecondary)
                        Spacer()
                        Text("\(completedTaskCount) of \(totalTaskCount)")
                            .font(.system(size: Typography.caption, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textOnCardMuted)
                    }

                    // Sleep Log row
                    if sleepLogDone {
                        TaskRowView(
                            icon: "moon.zzz.fill",
                            title: "Sleep Log",
                            subtitle: "Quick check-in about last night",
                            isCompleted: true
                        )
                    } else {
                        NavigationLink(destination: QuestionnaireView(currentDay: $currentDay, startSection: .sleepLog, sectionOnly: true).environmentObject(healthKitManager).environmentObject(themeManager)) {
                            TaskRowView(
                                icon: "moon.zzz.fill",
                                title: "Sleep Log",
                                subtitle: "Quick check-in about last night",
                                duration: "~3 min",
                                isCompleted: false
                            )
                        }
                    }

                    // Assessment row
                    if assessmentDone {
                        TaskRowView(
                            icon: currentDay > 5 ? "sparkles" : "list.bullet.clipboard",
                            title: getAssessmentTitle(),
                            subtitle: getDayDescription(),
                            isCompleted: true
                        )
                    } else {
                        let minutes = getAssessmentMinutes()
                        if minutes > 0 {
                            NavigationLink(destination: QuestionnaireView(currentDay: $currentDay, startSection: .assessment, sectionOnly: true).environmentObject(healthKitManager).environmentObject(themeManager)) {
                                TaskRowView(
                                    icon: currentDay > 5 ? "sparkles" : "list.bullet.clipboard",
                                    title: getAssessmentTitle(),
                                    subtitle: getDayDescription(),
                                    duration: "~\(minutes) min",
                                    isCompleted: false
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            GlassyCardBackground(opacity: 0.6)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        )
    }

    private var hasAssessmentToday: Bool {
        // Core days (1-7) always have assessment
        if currentDay <= 7 { return true }
        // Expansion days (8-14) only have assessment if gateways are triggered
        return !getTriggeredGatewaysForToday().isEmpty
    }

    private var completedTaskCount: Int {
        var count = 0
        if sleepLogDone { count += 1 }
        if hasAssessmentToday && assessmentDone { count += 1 }
        return count
    }

    private var totalTaskCount: Int {
        // Always have sleep log (1), assessment only if content exists
        return hasAssessmentToday ? 2 : 1
    }

    private func advanceToNextDay() {
        guard currentDay < Config.totalJourneyDays else { return }
        Task {
            do {
                // Pass debugMode or unlockTimeOverride - bypasses time check, NOT completion check
                let bypassTimeCheck = themeManager.debugMode || themeManager.unlockTimeOverride
                let response = try await ConvexService.shared.advanceToNextDay(debugMode: bypassTimeCheck)

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
        // For core days (1-5), use config estimates
        if currentDay <= 5 {
            guard let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }) else {
                return 10
            }
            return config.estimatedMinutes
        }

        // For expansion days (6-14), calculate based on triggered gateways for today
        let todayGateways = getTriggeredGatewaysForToday()
        if todayGateways.isEmpty {
            return 0  // No expansion content if no gateways triggered
        }

        // Sum up estimated minutes for each triggered gateway
        let totalMinutes = todayGateways.reduce(0.0) { $0 + $1.estimatedMinutes }
        return max(Int(ceil(totalMinutes)), 3)
    }

    /// Get the gateways that are both triggered AND scheduled for today
    private func getTriggeredGatewaysForToday() -> [GatewayType] {
        guard let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }),
              let requiredGateways = config.requiredGateways else {
            return []
        }

        // Get user's triggered gateways
        let triggeredGatewayTypes = Set(questionnaireManager.gatewayStates
            .filter { $0.triggered }
            .map { $0.gatewayType })

        // Return only gateways that are both required for today AND triggered
        return requiredGateways.filter { triggeredGatewayTypes.contains($0) }
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
                        .foregroundColor(theme.textOnCard)  // HIGH CONTRAST - circadian-aware
                }

                Text("Based on your responses, the following specialized assessments have been added to your journey:")
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST - circadian-aware

                ForEach(triggeredGateways, id: \.id) { gateway in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                            .font(.caption)
                        Text(gateway.gatewayType.displayName)
                            .font(.subheadline)
                            .foregroundColor(theme.textOnCard)  // HIGH CONTRAST - circadian-aware
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
            // Treatment Mode (visible after Day 14 or with active interventions)
            if currentDay > 14 {
                NavigationLink(destination: TreatmentView().environmentObject(themeManager)) {
                    QuickActionRow(
                        icon: "list.bullet.clipboard.fill",
                        iconColor: theme.accent,
                        title: "Treatment Tasks",
                        subtitle: "Daily tasks from your physician"
                    )
                    .environmentObject(themeManager)
                }
            }

            NavigationLink(destination: SleepDiaryHistoryView()) {
                QuickActionRow(
                    icon: "calendar",
                    iconColor: theme.sleepDiary,
                    title: "Sleep Diary History",
                    subtitle: "View your sleep log entries"
                )
                .environmentObject(themeManager)
            }

            NavigationLink(destination: InsightsView()) {
                QuickActionRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: theme.insights,
                    title: "Sleep Insights",
                    subtitle: "View patterns and recommendations"
                )
                .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Helper Methods

    private func getDayTitle() -> String {
        guard let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }) else {
            return "Day \(currentDay) Assessment"
        }
        return config.title
    }

    /// Get the title for today's assessment task
    private func getAssessmentTitle() -> String {
        // For core days (1-7), use "Assessment"
        if currentDay <= 7 {
            return "Assessment"
        }

        // For expansion days, use "Deep Dive" or specific area
        let todayGateways = getTriggeredGatewaysForToday()
        if todayGateways.isEmpty {
            return "Assessment"  // Fallback
        }

        if todayGateways.count == 1 {
            return "Deep Dive: \(todayGateways[0].shortName)"
        }
        return "Deep Dive"
    }

    private func getDayDescription() -> String {
        // For core days (1-7), show config description
        if currentDay <= 7 {
            guard let config = QuestionnaireManager.dayConfigurations.first(where: { $0.dayNumber == currentDay }) else {
                return "Complete today's questions"
            }
            return config.description
        }

        // For expansion days (8-14), show what's being assessed
        let todayGateways = getTriggeredGatewaysForToday()
        if todayGateways.isEmpty {
            return "No additional assessments today"
        }

        // Show what areas are being assessed (without times - duration field handles that)
        if todayGateways.count == 1 {
            return "Detailed \(todayGateways[0].shortName.lowercased()) assessment"
        } else {
            // List areas: "Pain, Nutrition assessment"
            let names = todayGateways.prefix(3).map { $0.shortName }
            if todayGateways.count <= 2 {
                return "\(names.joined(separator: " & ")) assessment"
            } else {
                return "\(names.dropLast().joined(separator: ", ")) & \(names.last!) assessment"
            }
        }
    }

    private func loadProgress() {
        Task {
            await questionnaireManager.loadJourneyProgress()
            if let progress = questionnaireManager.journeyProgress {
                currentDay = progress.currentDay

                // Load expansion schedule for Days 6+ (dynamic expansion from Convex)
                if progress.currentDay >= 6 {
                    await questionnaireManager.loadExpansionScheduleForDay(progress.currentDay)
                }
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

    // Observe ThemeManager for reactive circadian updates
    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

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
                    .foregroundColor(theme.textOnCard)  // HIGH CONTRAST - circadian-aware
                    .fixedSize(horizontal: true, vertical: false)  // Title never truncates
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST - circadian-aware
                    .lineLimit(1)
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.success)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(theme.textOnCardMuted)  // HIGH CONTRAST - circadian-aware
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

    // Observe ThemeManager for reactive circadian updates
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

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
                    .foregroundColor(theme.textOnCard)  // HIGH CONTRAST - circadian-aware
                    .fixedSize(horizontal: true, vertical: false)  // Title never truncates
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST - circadian-aware
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(theme.textOnCardMuted)  // HIGH CONTRAST - circadian-aware
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

    // Observe ThemeManager for reactive circadian updates
    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

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
                .foregroundColor(theme.textOnPrimary)  // Circadian-aware
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.primary)  // Circadian-safe primary color
                .cornerRadius(6)

                Spacer()

                if isCompleted {
                    // More prominent completion indicator
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)  // Circadian-aware
                            .font(.title2)
                        Text("Done")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(theme.success)  // Circadian-aware
                    }
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
                    .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST - circadian-aware
                }
            }

            // Title - HIGH CONTRAST on card
            Text(title ?? section.title)
                .font(.headline)
                .foregroundColor(theme.textOnCard)  // Circadian-aware
                .fixedSize(horizontal: true, vertical: false)  // Title never truncates

            // Subtitle/Description - HIGH CONTRAST on card
            Text(subtitle ?? section.description)
                .font(.subheadline)
                .foregroundColor(theme.textOnCardSecondary)  // Circadian-aware
                .lineLimit(1)

            // Why this matters (contextual explanation)
            if let why = whyExplanation, !isCompleted {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(theme.primary)
                    Text(why)
                        .font(.caption2)
                        .foregroundColor(theme.textOnCardMuted)  // HIGH CONTRAST - circadian-aware
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
                .foregroundColor(isCompleted ? theme.success : theme.primary)  // Circadian-aware
            }
        }
        .padding(16)
        .background(GlassyCardBackground(opacity: 0.35, tint: isCompleted ? theme.success : theme.primary))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: isCompleted ? [
                            theme.success.opacity(0.5),
                            theme.success.opacity(0.2)
                        ] : [
                            theme.primary.opacity(0.4),
                            theme.primary.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isCompleted ? 2 : 1
                )
        )
        .opacity(isCompleted ? 0.85 : 1.0)
    }
}

// MARK: - Calm Task Card (Headspace-inspired)

struct CalmTaskCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let duration: String

    // Observe ThemeManager for reactive circadian updates - MUST use this for all colors!
    @ObservedObject private var themeManager = ThemeManager.shared

    // Get fresh theme from ThemeManager - NOT from passed parameter
    private var theme: ColorTheme { themeManager.currentTheme }

    private var currentPeriod: TimePeriod {
        themeManager.currentTimePeriod
    }

    var body: some View {
        HStack(spacing: Spacing.lg) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(theme.primary.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(theme.primary)
            }

            // Content - HIGH CONTRAST on card background (circadian-aware)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.system(size: Typography.headline, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textOnCard)  // Cream text in evening/night
                    .fixedSize(horizontal: true, vertical: false)  // Title never truncates

                Text(subtitle)
                    .font(.system(size: Typography.subheadline, design: .rounded))
                    .foregroundColor(theme.textOnCardSecondary)  // Golden amber in evening/night
                    .lineLimit(1)
            }

            Spacer()

            // Duration and arrow - HIGH CONTRAST (circadian-aware)
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(duration)
                    .font(.system(size: Typography.caption, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textOnCardMuted)  // Warm amber in evening/night

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textOnCard)  // Cream in evening/night
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(Spacing.lg)
        .background(
            GlassyCardBackground(opacity: 0.6)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(theme.primary.opacity(currentPeriod == .evening || currentPeriod == .night ? 0.3 : 0.2), lineWidth: 1)
        )
    }
}

// MARK: - Task Row View (Clean horizontal task display)

struct TaskRowView: View {
    let icon: String
    let title: String
    let subtitle: String
    var duration: String? = nil
    let isCompleted: Bool

    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon with completion state
            ZStack {
                Circle()
                    .fill(isCompleted ? theme.success.opacity(0.15) : theme.primary.opacity(0.15))
                    .frame(width: 40, height: 40)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.success)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(theme.primary)
                }
            }

            // Title and subtitle - horizontal flow
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: Typography.body, weight: .semibold, design: .rounded))
                    .foregroundColor(isCompleted ? theme.textOnCardMuted : theme.textOnCard)
                    .strikethrough(isCompleted, color: theme.textOnCardMuted)
                    .fixedSize(horizontal: true, vertical: false)  // Title never truncates

                Text(subtitle)
                    .font(.system(size: Typography.caption, design: .rounded))
                    .foregroundColor(theme.textOnCardSecondary)
                    .lineLimit(2)  // Allow 2 lines to prevent truncation of longer subtitles
                    .fixedSize(horizontal: false, vertical: true)  // Allow vertical expansion
            }

            Spacer()

            // Duration and chevron (only for incomplete tasks)
            if !isCompleted {
                HStack(spacing: Spacing.xs) {
                    if let duration = duration {
                        Text(duration)
                            .font(.system(size: Typography.caption, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textOnCardMuted)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textOnCardMuted)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(isCompleted ? Color.clear : theme.backgroundTint.opacity(0.3))
        )
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
                        DayOverviewCard(config: config, currentDay: currentDay)
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

    // Observe ThemeManager for reactive circadian updates
    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 12) {
            // Day number circle
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 44, height: 44)
                Text("\(config.dayNumber)")
                    .font(.headline)
                    .foregroundColor(theme.textOnPrimary)  // Circadian-aware
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(config.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textOnCard)  // HIGH CONTRAST - circadian-aware
                Text(config.description)
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST - circadian-aware
                    .lineLimit(2)

                if config.isExpansionDay {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.circle")
                            .font(.caption2)
                        Text("Expansion Day")
                            .font(.caption2)
                    }
                    .foregroundColor(theme.textOnCardMuted)  // HIGH CONTRAST - circadian-aware
                }
            }

            Spacer()

            Text("~\(config.estimatedMinutes) min")
                .font(.caption2)
                .foregroundColor(theme.textOnCardMuted)  // HIGH CONTRAST - circadian-aware
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.4))  // Circadian-aware background
        .cornerRadius(12)
    }

    private var circleColor: Color {
        if config.dayNumber < currentDay {
            return theme.completed
        } else if config.dayNumber == currentDay {
            return theme.active
        } else {
            return theme.textOnCardMuted.opacity(0.5)  // Circadian-aware gray
        }
    }
}

/// Model for a single assessment response with readable question and answer
struct AssessmentResponse: Identifiable {
    let id = UUID()
    let questionId: String
    let questionText: String
    let answerText: String
    let category: String  // e.g., "Demographics", "Mental Health", etc.
}

struct SleepDiaryHistoryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var questionnaireManager = QuestionnaireManager.shared
    @State private var selectedDay: Int
    @State private var sleepEntries: [Int: SleepDiaryEntry] = [:]
    @State private var assessmentResponses: [Int: [AssessmentResponse]] = [:]  // Assessment responses by day
    @State private var isLoading = true
    @State private var showAssessmentDetails = false  // Collapsible toggle
    private let hasInitialDay: Bool

    /// Initialize with an optional pre-selected day
    init(initialDay: Int? = nil) {
        // Default to 1, will be updated in loadSleepHistory to most recent day if no initial day provided
        _selectedDay = State(initialValue: initialDay ?? 1)
        hasInitialDay = initialDay != nil
    }

    private var theme: ColorTheme { themeManager.currentTheme }
    private var completedDays: [Int] {
        questionnaireManager.journeyProgress?.completedDays ?? []
    }

    // MARK: - Circadian-Aware Colors (8-phase interpolated palette)
    private var palette: CircadianPalette {
        themeManager.circadianPalette
    }

    private var circadianTextPrimary: Color {
        palette.textPrimary
    }

    private var circadianTextSecondary: Color {
        palette.textSecondary
    }

    private var circadianCardBackground: Color {
        if palette.isDark {
            return Color(red: 0.20, green: 0.13, blue: 0.09).opacity(0.90)
        } else {
            return Color(red: 1.0, green: 0.99, blue: 0.96).opacity(0.85)
        }
    }

    var body: some View {
        ZStack {
            // Circadian wave background - syncs with ThemeManager
            DashboardWaveBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Day Selector
                    daySelectorView

                    // Selected Day Details
                    if completedDays.isEmpty {
                        emptyStateView
                    } else if isLoading {
                        loadingView
                    } else if let entry = sleepEntries[selectedDay] {
                        dayDetailView(entry: entry)
                    } else {
                        noDayDataView
                    }

                    // Sleep Metrics Chart (after 3+ days)
                    if completedDays.count >= 3 {
                        sleepTrendChart
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)  // Ensure background doesn't interfere
        }
        .navigationTitle("Sleep Diary")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(palette.isDark ? .dark : .light, for: .navigationBar)
        .onAppear {
            loadSleepHistory()
        }
        .onChange(of: selectedDay) { _, _ in
            // Data already loaded, no action needed
        }
    }

    // MARK: - Day Selector

    private var daySelectorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select a Day")
                .font(.headline)
                .foregroundColor(circadianTextPrimary)

            // Use negative margin to extend ScrollView edge-to-edge, then add content padding
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(1...14, id: \.self) { day in
                        DayPillButton(
                            day: day,
                            isSelected: day == selectedDay,
                            isCompleted: completedDays.contains(day)
                        ) {
                            if completedDays.contains(day) {
                                selectedDay = day
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)  // Content padding to match parent VStack padding
            }
            .padding(.horizontal, -16)  // Extend ScrollView to screen edges for smooth scrolling
        }
    }

    // MARK: - Day Detail View

    private func dayDetailView(entry: SleepDiaryEntry) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Day \(selectedDay)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textOnCard)

                    if let date = entry.date {
                        Text(date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(theme.textOnCardSecondary)
                    }
                }
                Spacer()

                // Quality badge
                if let quality = entry.sleepQuality {
                    qualityBadge(quality: quality)
                }
            }
            .padding()
            .background(GlassyCardBackground(opacity: 0.5))
            .cornerRadius(16)

            // Sleep Timing Card
            sleepTimingCard(entry: entry)

            // Sleep Metrics Card
            sleepMetricsCard(entry: entry)

            // Context Card (if data exists)
            if entry.hasContextData {
                contextCard(entry: entry)
            }

            // Assessment Responses Card (collapsible)
            if let responses = assessmentResponses[selectedDay], !responses.isEmpty {
                assessmentResponsesCard(responses: responses)
            }
        }
    }

    // MARK: - Assessment Responses Card

    private func assessmentResponsesCard(responses: [AssessmentResponse]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with collapse toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAssessmentDetails.toggle()
                }
            }) {
                HStack {
                    Label("Assessment Responses", systemImage: "list.clipboard.fill")
                        .font(.headline)
                        .foregroundColor(theme.primary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(responses.count) answers")
                            .font(.caption)
                            .foregroundColor(theme.textOnCardSecondary)
                        Image(systemName: showAssessmentDetails ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(theme.textOnCardMuted)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            if showAssessmentDetails {
                // Group by category
                let groupedResponses = Dictionary(grouping: responses) { $0.category }
                let sortedCategories = groupedResponses.keys.sorted()

                ForEach(sortedCategories, id: \.self) { category in
                    if let categoryResponses = groupedResponses[category] {
                        VStack(alignment: .leading, spacing: 8) {
                            // Category header
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.primary.opacity(0.8))
                                .padding(.top, 8)

                            // Questions in this category
                            ForEach(categoryResponses) { response in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(response.questionText)
                                        .font(.caption)
                                        .foregroundColor(theme.textOnCardSecondary)
                                        .lineLimit(2)

                                    Text(response.answerText)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(theme.textOnCard)
                                }
                                .padding(.vertical, 4)

                                if response.id != categoryResponses.last?.id {
                                    Divider()
                                        .background(theme.textOnCardMuted.opacity(0.2))
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    private func sleepTimingCard(entry: SleepDiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sleep Timing", systemImage: "clock.fill")
                .font(.headline)
                .foregroundColor(theme.primary)

            VStack(spacing: 8) {
                if let intoBed = entry.intoBedTime {
                    timingRow(label: "Got into bed", time: intoBed, icon: "bed.double.fill")
                }
                if let trySleep = entry.trySleepTime {
                    timingRow(label: "Tried to sleep", time: trySleep, icon: "moon.fill")
                }
                if let finalWake = entry.finalWakeTime {
                    timingRow(label: "Final awakening", time: finalWake, icon: "sunrise.fill")
                }
                if let outBed = entry.outOfBedTime {
                    timingRow(label: "Got out of bed", time: outBed, icon: "figure.walk")
                }
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    private func sleepMetricsCard(entry: SleepDiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sleep Metrics", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundColor(theme.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let duration = entry.totalSleepDuration {
                    metricTile(label: "Total Sleep", value: formatDuration(duration), icon: "bed.double.fill")
                }
                if let latency = entry.sleepLatency {
                    metricTile(label: "Fall Asleep", value: "\(latency) min", icon: "hourglass")
                }
                if let awakenings = entry.awakenings {
                    metricTile(label: "Awakenings", value: "\(awakenings)", icon: "exclamationmark.circle")
                }
                if let waso = entry.waso {
                    metricTile(label: "Time Awake", value: "\(waso) min", icon: "clock.badge.exclamationmark")
                }
                if let efficiency = entry.sleepEfficiency {
                    metricTile(label: "Efficiency", value: "\(Int(efficiency))%", icon: "percent")
                }
                if let refreshed = entry.refreshedRating {
                    metricTile(label: "Refreshed", value: "\(refreshed)/5", icon: "sparkles")
                }
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    private func contextCard(entry: SleepDiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Context", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(theme.primary)

            VStack(alignment: .leading, spacing: 8) {
                if let dayType = entry.dayType {
                    contextRow(label: "Day type", value: dayType)
                }
                if let caffeine = entry.caffeineCount, caffeine > 0 {
                    contextRow(label: "Caffeine drinks", value: "\(caffeine)")
                }
                if entry.hadAlcohol == true {
                    contextRow(label: "Alcohol", value: "Yes")
                }
                if entry.tookSleepMeds == true {
                    contextRow(label: "Sleep medication", value: entry.sleepMedsName ?? "Yes")
                }
                if entry.didNap == true, let napDuration = entry.napDuration {
                    contextRow(label: "Napped", value: "\(napDuration) min")
                }
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    // MARK: - Sleep Trend Chart

    private var sleepTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sleep Quality Trend", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundColor(theme.primary)

            // Simple bar chart for quality ratings
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(completedDays.sorted(), id: \.self) { day in
                    if let entry = sleepEntries[day], let quality = entry.sleepQuality {
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(qualityColor(quality: quality))
                                .frame(width: 24, height: CGFloat(quality) * 20)
                                .cornerRadius(4)

                            Text("\(day)")
                                .font(.caption2)
                                .foregroundColor(theme.textOnCardMuted)
                        }
                    }
                }
            }
            .frame(height: 120)
            .padding(.vertical, 8)

            // Legend
            HStack(spacing: 16) {
                legendItem(color: theme.success, label: "Good (4-5)")
                legendItem(color: theme.warning, label: "Fair (3)")
                legendItem(color: theme.error, label: "Poor (1-2)")
            }
            .font(.caption)
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    // MARK: - Helper Views

    private func qualityBadge(quality: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: qualityIcon(quality: quality))
            Text("\(quality)/5")
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(qualityColor(quality: quality))
        .cornerRadius(20)
    }

    private func timingRow(label: String, time: Date, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(theme.primary)
                .frame(width: 24)
            Text(label)
                .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST
            Spacer()
            Text(time, style: .time)
                .fontWeight(.medium)
                .foregroundColor(theme.textOnCard)  // HIGH CONTRAST
        }
    }

    private func metricTile(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(theme.primary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(theme.textOnCard)

            Text(label)
                .font(.caption)
                .foregroundColor(theme.textOnCardSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(GlassyCardBackground(opacity: 0.3))
        .cornerRadius(12)
    }

    private func contextRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(theme.textOnCard)  // HIGH CONTRAST
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundColor(theme.primary.opacity(0.5))

            Text("No sleep data yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(circadianTextPrimary)

            Text("Complete your daily sleep log to see your history here")
                .font(.subheadline)
                .foregroundColor(circadianTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(theme.primary)
            Text("Loading sleep history...")
                .foregroundColor(circadianTextSecondary)
        }
        .padding(40)
    }

    private var noDayDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(theme.warning)

            Text("No data for Day \(selectedDay)")
                .font(.headline)
                .foregroundColor(circadianTextPrimary)

            Text("Select a completed day to view details")
                .font(.subheadline)
                .foregroundColor(circadianTextSecondary)
        }
        .padding(40)
    }

    // MARK: - Helper Functions

    private func qualityColor(quality: Int) -> Color {
        switch quality {
        case 4...5: return theme.success
        case 3: return theme.warning
        default: return theme.error
        }
    }

    private func qualityIcon(quality: Int) -> String {
        switch quality {
        case 4...5: return "star.fill"
        case 3: return "star.leadinghalf.filled"
        default: return "star"
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    // MARK: - Data Loading

    private func loadSleepHistory() {
        isLoading = true

        // Only auto-select most recent day if no initial day was provided
        if !hasInitialDay, let lastDay = completedDays.max() {
            selectedDay = lastDay
        }

        // Load sleep entries and assessment responses
        Task {
            var entries: [Int: SleepDiaryEntry] = [:]
            var allAssessmentResponses: [Int: [AssessmentResponse]] = [:]

            for day in completedDays {
                let (entry, dayAssessmentResponses) = await loadDayData(day: day)
                if let entry = entry {
                    entries[day] = entry
                }
                if !dayAssessmentResponses.isEmpty {
                    allAssessmentResponses[day] = dayAssessmentResponses
                }
            }

            await MainActor.run {
                sleepEntries = entries
                assessmentResponses = allAssessmentResponses
                isLoading = false
            }
        }
    }

    /// Load both sleep diary entry and assessment responses for a day
    private func loadDayData(day: Int) async -> (SleepDiaryEntry?, [AssessmentResponse]) {
        do {
            let savedResponses = try await ConvexService.shared.getSavedResponses(dayNumber: day)

            #if DEBUG
            print("[SleepDiaryHistory] Day \(day) - loaded \(savedResponses.count) responses")
            #endif

            // Separate CSD/sleep log responses from assessment responses
            var sleepLogResponses: [String: Any] = [:]
            var assessmentResponsesList: [AssessmentResponse] = []

            for (questionId, responseValue) in savedResponses {
                // Check if this is a sleep log question (CSD_, SL_, SD_ prefixes)
                let isSleepLog = questionId.hasPrefix("CSD_") || questionId.hasPrefix("SL_") || questionId.hasPrefix("SD_")

                // Parse the response value
                var parsedValue: Any = ""
                if let stringValue = responseValue.stringValue {
                    // Check if it's a time string (ISO8601) and convert to Date
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = isoFormatter.date(from: stringValue) {
                        parsedValue = date
                    } else {
                        isoFormatter.formatOptions = [.withInternetDateTime]
                        if let date = isoFormatter.date(from: stringValue) {
                            parsedValue = date
                        } else {
                            parsedValue = stringValue
                        }
                    }
                } else if let numberValue = responseValue.numberValue {
                    parsedValue = numberValue
                } else if let arrayValue = responseValue.arrayValue {
                    parsedValue = arrayValue
                }

                if isSleepLog {
                    sleepLogResponses[questionId] = parsedValue
                } else {
                    // Create assessment response with readable question text
                    let assessmentResponse = createAssessmentResponse(
                        questionId: questionId,
                        value: parsedValue
                    )
                    if let response = assessmentResponse {
                        assessmentResponsesList.append(response)
                    }
                }
            }

            // Create sleep diary entry
            let entry = SleepDiaryEntry(from: sleepLogResponses, day: day)

            #if DEBUG
            print("[SleepDiaryHistory] Day \(day): \(sleepLogResponses.count) sleep log, \(assessmentResponsesList.count) assessment")
            #endif

            return (entry, assessmentResponsesList)
        } catch {
            print("[SleepDiaryHistory] Failed to load day \(day): \(error)")
            return (nil, [])
        }
    }

    /// Create an AssessmentResponse from a question ID and value
    private func createAssessmentResponse(questionId: String, value: Any) -> AssessmentResponse? {
        // Look up question text from QuestionnaireManager
        let questionText = questionnaireManager.getQuestionText(for: questionId) ?? questionId
        let category = questionnaireManager.getQuestionCategory(for: questionId) ?? "Other"

        // Format the answer text based on value type
        let answerText: String
        if let stringValue = value as? String {
            // Check if it's a date string (yyyy-MM-dd) and format nicely
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: stringValue) {
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                answerText = dateFormatter.string(from: date)
            } else {
                answerText = stringValue
            }
        } else if let numberValue = value as? Double {
            // Check if it's likely an integer
            if numberValue == floor(numberValue) {
                answerText = String(Int(numberValue))
            } else {
                answerText = String(format: "%.1f", numberValue)
            }
        } else if let intValue = value as? Int {
            answerText = String(intValue)
        } else if let dateValue = value as? Date {
            // Format based on question type
            let formatter = DateFormatter()
            if questionnaireManager.getQuestionType(for: questionId) == .date {
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
            } else {
                formatter.dateStyle = .none
                formatter.timeStyle = .short
            }
            answerText = formatter.string(from: dateValue)
        } else if let arrayValue = value as? [String] {
            answerText = arrayValue.joined(separator: ", ")
        } else {
            answerText = String(describing: value)
        }

        // Skip empty or very short answers
        guard !answerText.isEmpty else { return nil }

        return AssessmentResponse(
            questionId: questionId,
            questionText: questionText,
            answerText: answerText,
            category: category
        )
    }

    private func loadDayEntry(day: Int) async -> SleepDiaryEntry? {
        // Fetch responses for this day from Convex
        do {
            let savedResponses = try await ConvexService.shared.getSavedResponses(dayNumber: day)

            #if DEBUG
            print("[SleepDiaryHistory] Day \(day) - loaded \(savedResponses.count) responses")
            for (key, value) in savedResponses.sorted(by: { $0.key < $1.key }) {
                if let str = value.stringValue {
                    print("  \(key): string=\"\(str)\"")
                } else if let num = value.numberValue {
                    print("  \(key): number=\(num)")
                } else if let arr = value.arrayValue {
                    print("  \(key): array=\(arr)")
                }
            }
            #endif

            // Convert QuestionResponseValue to [String: Any] for SleepDiaryEntry
            var responses: [String: Any] = [:]
            for (questionId, responseValue) in savedResponses {
                if let stringValue = responseValue.stringValue {
                    // Check if it's a time string (ISO8601) and convert to Date
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = isoFormatter.date(from: stringValue) {
                        responses[questionId] = date
                    } else {
                        // Try without fractional seconds
                        isoFormatter.formatOptions = [.withInternetDateTime]
                        if let date = isoFormatter.date(from: stringValue) {
                            responses[questionId] = date
                        } else {
                            responses[questionId] = stringValue
                        }
                    }
                } else if let numberValue = responseValue.numberValue {
                    // IMPORTANT: Keep as Double to preserve timestamp precision
                    // SleepDiaryEntry.parseDate handles both Int and Double
                    responses[questionId] = numberValue
                } else if let arrayValue = responseValue.arrayValue {
                    responses[questionId] = arrayValue
                }
            }

            let entry = SleepDiaryEntry(from: responses, day: day)

            #if DEBUG
            print("[SleepDiaryHistory] Day \(day) parsed entry:")
            print("  intoBedTime: \(entry.intoBedTime?.description ?? "nil")")
            print("  trySleepTime: \(entry.trySleepTime?.description ?? "nil")")
            print("  finalWakeTime: \(entry.finalWakeTime?.description ?? "nil")")
            print("  sleepQuality: \(entry.sleepQuality?.description ?? "nil")")
            print("  awakenings: \(entry.awakenings?.description ?? "nil")")
            #endif

            return entry
        } catch {
            print("[SleepDiaryHistory] Failed to load day \(day): \(error)")
            return nil
        }
    }
}

// MARK: - Day Pill Button

struct DayPillButton: View {
    let day: Int
    let isSelected: Bool
    let isCompleted: Bool
    let action: () -> Void

    // Observe ThemeManager for reactive circadian updates
    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.headline)
                    .fontWeight(isSelected ? .bold : .regular)

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                }
            }
            .frame(width: 44, height: 56)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? theme.primary : Color.clear, lineWidth: 2)
            )
        }
        .disabled(!isCompleted)
    }

    private var foregroundColor: Color {
        if isSelected {
            return theme.textOnPrimary  // Circadian-aware text on primary background
        } else if isCompleted {
            return theme.textOnCard  // Circadian-aware - visible on background
        } else {
            // Unselected/incomplete - still needs to be visible!
            return theme.textOnCardMuted  // Full opacity for visibility
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return theme.primary
        } else if isCompleted {
            return theme.backgroundTint  // Circadian-aware background tint
        } else {
            return Color.clear
        }
    }
}

// MARK: - Sleep Diary Entry Model

struct SleepDiaryEntry {
    let day: Int
    let date: Date?

    // Core timing
    let intoBedTime: Date?
    let trySleepTime: Date?
    let finalWakeTime: Date?
    let outOfBedTime: Date?

    // Metrics
    let sleepLatency: Int?  // minutes to fall asleep
    let awakenings: Int?
    let waso: Int?  // wake after sleep onset (minutes)
    let totalSleepDuration: Int?  // in minutes
    let sleepEfficiency: Double?  // percentage

    // Ratings
    let sleepQuality: Int?  // 1-5
    let refreshedRating: Int?  // 1-5

    // Context
    let dayType: String?
    let caffeineCount: Int?
    let hadAlcohol: Bool?
    let tookSleepMeds: Bool?
    let sleepMedsName: String?
    let didNap: Bool?
    let napDuration: Int?

    var hasContextData: Bool {
        dayType != nil || (caffeineCount ?? 0) > 0 || hadAlcohol == true || tookSleepMeds == true || didNap == true
    }

    init(from responses: [String: Any], day: Int) {
        self.day = day
        self.date = Self.parseDate(responses["_date"]) ?? Date()

        // Parse timing responses (support both Date and timestamp formats)
        self.intoBedTime = Self.parseDate(responses["CSD_INTO_BED"]) ?? Self.parseDate(responses["SL_BEDTIME"])
        self.trySleepTime = Self.parseDate(responses["CSD_TRY_SLEEP"]) ?? Self.parseDate(responses["SL_ASLEEP_TIME"])
        self.finalWakeTime = Self.parseDate(responses["CSD_FINAL_WAKE"]) ?? Self.parseDate(responses["SL_WAKE_TIME"])
        self.outOfBedTime = Self.parseDate(responses["CSD_OUT_BED"])

        // Parse metrics (handle both Int and Double from Convex)
        self.sleepLatency = Self.parseIntValue(responses["CSD_LATENCY"])
        self.awakenings = Self.parseIntValue(responses["CSD_AWAKENINGS"]) ?? Self.parseIntValue(responses["SL_AWAKENINGS"])
        self.waso = Self.parseIntValue(responses["CSD_WASO"])

        // Calculate total sleep and efficiency if we have timing data
        if let trySleep = self.trySleepTime, let finalWake = self.finalWakeTime {
            let totalTimeInBed = finalWake.timeIntervalSince(trySleep) / 60  // minutes
            let latency = Double(self.sleepLatency ?? 0)
            let wasoMinutes = Double(self.waso ?? 0)
            let actualSleep = totalTimeInBed - latency - wasoMinutes
            self.totalSleepDuration = max(0, Int(actualSleep))
            self.sleepEfficiency = totalTimeInBed > 0 ? (actualSleep / totalTimeInBed) * 100 : nil
        } else {
            self.totalSleepDuration = nil
            self.sleepEfficiency = nil
        }

        // Parse ratings (handle both Int and Double)
        if let quality = Self.parseIntValue(responses["CSD_QUALITY"]) {
            self.sleepQuality = quality
        } else if let quality = Self.parseIntValue(responses["SL_QUALITY"]) {
            // SL_QUALITY is 1-5 scale (same as CSD), no conversion needed
            self.sleepQuality = max(1, min(5, quality))
        } else {
            self.sleepQuality = nil
        }
        self.refreshedRating = Self.parseIntValue(responses["CSD_REFRESHED"])

        // Parse context (handle both Int and Double for numeric fields)
        self.dayType = responses["CSD_DAY_TYPE"] as? String
        self.caffeineCount = Self.parseIntValue(responses["CSD_CAFFEINE"])
        self.hadAlcohol = (responses["CSD_ALCOHOL"] as? String) == "Yes"
        self.tookSleepMeds = (responses["CSD_MEDS"] as? String) == "Yes"
        self.sleepMedsName = responses["CSD_MEDS_NAME"] as? String
        self.didNap = (responses["CSD_NAPS"] as? String) == "Yes"
        self.napDuration = Self.parseIntValue(responses["CSD_NAP_DURATION"])
    }

    /// Parse numeric value that could be Int or Double from Convex
    private static func parseIntValue(_ value: Any?) -> Int? {
        guard let value = value else { return nil }
        if let intVal = value as? Int {
            return intVal
        }
        if let doubleVal = value as? Double {
            return Int(doubleVal)
        }
        // Try parsing from string
        if let strVal = value as? String, let intVal = Int(strVal) {
            return intVal
        }
        return nil
    }

    /// Parse various date formats (Date, timestamp, ISO8601 string)
    private static func parseDate(_ value: Any?) -> Date? {
        guard let value = value else { return nil }

        // Already a Date
        if let date = value as? Date {
            return date
        }

        // Timestamp (milliseconds since epoch)
        if let timestamp = value as? Double {
            return Date(timeIntervalSince1970: timestamp / 1000)
        }
        if let timestamp = value as? Int {
            return Date(timeIntervalSince1970: Double(timestamp) / 1000)
        }

        // ISO8601 string
        if let string = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) {
                return date
            }
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: string)
        }

        return nil
    }
}

struct InsightsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        SleepInsightsDashboardView()
            .environmentObject(themeManager)
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

    // Observe ThemeManager for reactive circadian updates
    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

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
                    Text(currentDay < Config.totalJourneyDays ? "Great progress on your sleep journey" : "Congratulations! Journey complete!")
                        .font(.subheadline)
                        .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST - circadian-aware
                }

                Spacer()
            }

            // Next day info
            if currentDay < Config.totalJourneyDays {
                Divider()
                    .background(theme.textOnCardMuted.opacity(0.3))  // Circadian-aware divider

                if isDebugMode || themeManager.unlockTimeOverride {
                    // Debug mode or unlock override: Show advance button immediately (bypasses time check)
                    Button(action: onAdvanceDay) {
                        HStack {
                            Image(systemName: "forward.fill")
                                .font(.subheadline)
                            Text("Advance to Day \(currentDay + 1)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(theme.textOnPrimary)  // Circadian-aware
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.primary)
                        .cornerRadius(10)
                    }

                    Text(isDebugMode ? "Debug mode: Time check bypassed" : "Unlock override enabled in Settings")
                        .font(.caption2)
                        .foregroundColor(theme.textOnCardSecondary)  // HIGH CONTRAST - circadian-aware
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
                        .foregroundColor(theme.textOnPrimary)  // Circadian-aware
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.primary)
                        .cornerRadius(10)
                    }
                } else {
                    // Locked state - show padlock with "We'll unlock tomorrow"
                    HStack(spacing: 12) {
                        // Semi-transparent padlock icon
                        ZStack {
                            Circle()
                                .fill(theme.textOnCardMuted.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18))
                                .foregroundColor(theme.textOnCardSecondary.opacity(0.7))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Day \(currentDay + 1)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(theme.textOnCard)
                            Text("We'll unlock tomorrow at 4:00 AM")
                                .font(.caption)
                                .foregroundColor(theme.textOnCardSecondary)
                            Text(timeUntilUnlock)
                                .font(.caption2)
                                .foregroundColor(theme.textOnCardMuted)
                                .monospacedDigit()
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            } else {
                // Journey complete - show transition to analysis phase
                Divider()
                    .background(theme.textOnCardMuted.opacity(0.3))

                VStack(spacing: 16) {
                    // Celebration header
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.title2)
                            .foregroundColor(theme.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Journey Complete!")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.textOnCard)
                            Text("You've completed the \(Config.totalJourneyDays)-day sleep assessment")
                                .font(.caption)
                                .foregroundColor(theme.textOnCardSecondary)
                        }
                        Spacer()
                    }

                    // What happens next info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "stethoscope")
                                .font(.caption)
                                .foregroundColor(theme.accent)
                            Text("Our sleep medicine team is now reviewing your data")
                                .font(.caption)
                                .foregroundColor(theme.textOnCardSecondary)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "bell.badge")
                                .font(.caption)
                                .foregroundColor(theme.accent)
                            Text("You'll receive your personalized sleep protocol soon")
                                .font(.caption)
                                .foregroundColor(theme.textOnCardSecondary)
                        }
                    }
                    .padding(.horizontal, 4)

                    // Continue button
                    Button(action: {
                        Task {
                            await JourneyPhaseManager.shared.transitionToAnalysis()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.subheadline)
                            Text("View Analysis Status")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(theme.textOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.accent)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(GlassyCardBackground(opacity: 0.5, tint: theme.success))  // Circadian-aware card background
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

// MARK: - Expansion Pack Task Card

struct ExpansionPackTaskCard: View {
    let expansionInfo: ExpansionPackInfo

    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

    private var currentPeriod: TimePeriod {
        themeManager.currentTimePeriod
    }

    var body: some View {
        HStack(spacing: Spacing.lg) {
            // Sparkle icon circle
            ZStack {
                Circle()
                    .fill(QuestionnaireSection.expansionPack.accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(QuestionnaireSection.expansionPack.accentColor)
            }

            // Content
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Deeper Dive")
                    .font(.system(size: Typography.headline, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textOnCard)
                    .fixedSize(horizontal: true, vertical: false)  // Title never truncates

                Text(expansionInfo.shortExplanation)
                    .font(.system(size: Typography.subheadline, design: .rounded))
                    .foregroundColor(theme.textOnCardSecondary)
                    .lineLimit(1)

                // Gateway tags
                HStack(spacing: 6) {
                    ForEach(expansionInfo.triggeredGateways.prefix(3), id: \.self) { gateway in
                        Text(gateway.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(QuestionnaireSection.expansionPack.accentColor)
                            .cornerRadius(10)
                    }
                }
            }

            Spacer()

            // Duration and arrow
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text("~\(expansionInfo.totalEstimatedMinutes) min")
                    .font(.system(size: Typography.caption, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textOnCardMuted)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textOnCard)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(Spacing.lg)
        .background(
            GlassyCardBackground(opacity: 0.6, tint: QuestionnaireSection.expansionPack.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(QuestionnaireSection.expansionPack.accentColor.opacity(currentPeriod == .evening || currentPeriod == .night ? 0.4 : 0.3), lineWidth: 1)
        )
    }
}

// MARK: - Expansion Pack Questionnaire View

struct ExpansionPackQuestionnaireView: View {
    @Binding var currentDay: Int
    let expansionInfo: ExpansionPackInfo

    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var questionnaireManager = QuestionnaireManager.shared

    @State private var showingIntro = true
    @State private var currentIndex = 0
    @State private var responses: [String: Any] = [:]
    @State private var userInteracted: Set<String> = []
    @State private var showingCompletion = false
    @State private var isSaving = false

    @Environment(\.presentationMode) var presentationMode

    private var theme: ColorTheme { themeManager.currentTheme }
    private var questions: [Question] { expansionInfo.questions }

    // Circadian-aware button colors
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var buttonBackgroundColor: Color {
        if isEvening {
            return Color(red: 0.25, green: 0.15, blue: 0.1)
        } else {
            return Color(.secondarySystemBackground)
        }
    }

    private var buttonTextColor: Color {
        if isEvening {
            return Color(red: 0.988, green: 0.827, blue: 0.302)
        } else {
            return Color.primary
        }
    }

    private var navBarBackgroundColor: Color {
        if isEvening {
            return Color(red: 0.15, green: 0.08, blue: 0.05)
        } else {
            return Color(.systemBackground)
        }
    }

    var body: some View {
        Group {
            if showingIntro {
                ExpansionPackIntroView(
                    expansionInfo: expansionInfo,
                    onContinue: {
                        withAnimation {
                            showingIntro = false
                        }
                    },
                    onSkip: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else if showingCompletion {
                ExpansionCompletionView(
                    expansionInfo: expansionInfo,
                    onDone: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else {
                questionnaireContent
            }
        }
        .navigationTitle("Deeper Dive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(navBarBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isEvening ? .dark : .light, for: .navigationBar)
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(QuestionnaireSection.expansionPack.accentColor)
                        Text("Saving your responses...")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.cardBackground.opacity(0.95))
                    )
                }
            }
        }
    }

    private var questionnaireContent: some View {
        ZStack {
            QuestionnaireWaveBackground()

            VStack(spacing: 0) {
                // Header
                SectionHeaderView(
                    section: .expansionPack,
                    currentQuestion: currentIndex + 1,
                    totalQuestions: questions.count
                )

                // Progress
                SectionProgressView(
                    section: .expansionPack,
                    currentIndex: currentIndex,
                    totalQuestions: questions.count
                )
                .padding(.vertical, 8)

                // Question content
                ScrollView {
                    VStack(spacing: 20) {
                        if !questions.isEmpty && currentIndex < questions.count {
                            SectionQuestionCard(section: .expansionPack, question: questions[currentIndex]) {
                                questionInputView(for: questions[currentIndex])
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }

                // Navigation buttons
                navigationButtons
            }
        }
    }

    @ViewBuilder
    private func questionInputView(for question: Question) -> some View {
        switch question.questionType {
        case .scale:
            ScaleInput(
                question: question,
                value: scaleBinding(for: question.id, default: ScaleInput.smartDefault(for: question)),
                theme: theme
            )
        case .yesNo, .yesNoDontKnow:
            YesNoInput(
                question: question,
                value: stringBinding(for: question.id),
                theme: theme
            )
        case .singleSelect:
            SingleSelectInput(
                question: question,
                value: stringBinding(for: question.id),
                theme: theme
            )
        case .multiSelect:
            MultiSelectInput(
                question: question,
                values: arrayBinding(for: question.id),
                theme: theme
            )
        default:
            TextInputView(
                question: question,
                value: stringBinding(for: question.id),
                placeholder: "Enter your answer"
            )
        }
    }

    // MARK: - Bindings

    private func scaleBinding(for questionId: String, default defaultValue: Double) -> Binding<Double> {
        Binding(
            get: { (responses[questionId] as? Double) ?? defaultValue },
            set: {
                responses[questionId] = $0
                userInteracted.insert(questionId)
            }
        )
    }

    private func stringBinding(for questionId: String) -> Binding<String> {
        Binding(
            get: { (responses[questionId] as? String) ?? "" },
            set: {
                responses[questionId] = $0
                userInteracted.insert(questionId)
            }
        )
    }

    private func arrayBinding(for questionId: String) -> Binding<[String]> {
        Binding(
            get: { (responses[questionId] as? [String]) ?? [] },
            set: {
                responses[questionId] = $0
                userInteracted.insert(questionId)
            }
        )
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            Button(action: previousQuestion) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonBackgroundColor)
                .foregroundColor(buttonTextColor)
                .cornerRadius(12)
            }
            .disabled(currentIndex == 0)
            .opacity(currentIndex == 0 ? 0.5 : 1)

            Button(action: nextQuestion) {
                HStack {
                    Text(currentIndex == questions.count - 1 ? "Complete" : "Next")
                    Image(systemName: currentIndex == questions.count - 1 ? "checkmark.circle.fill" : "chevron.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed ? QuestionnaireSection.expansionPack.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canProceed)
        }
        .padding()
        .background(navBarBackgroundColor)
    }

    private var canProceed: Bool {
        guard !questions.isEmpty && currentIndex < questions.count else { return false }
        let question = questions[currentIndex]

        if !question.required { return true }

        switch question.questionType {
        case .scale:
            return userInteracted.contains(question.id)
        case .singleSelect, .yesNo, .yesNoDontKnow:
            guard let response = responses[question.id] else { return false }
            return !(response as? String ?? "").isEmpty
        case .multiSelect:
            guard let response = responses[question.id] else { return false }
            return !(response as? [String] ?? []).isEmpty
        default:
            return userInteracted.contains(question.id) || responses[question.id] != nil
        }
    }

    private func previousQuestion() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }

    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
        } else {
            completeExpansion()
        }
    }

    private func completeExpansion() {
        isSaving = true

        Task {
            do {
                // Save expansion responses
                var convexResponses: [[String: Any]] = []
                for (questionId, value) in responses {
                    guard userInteracted.contains(questionId) else { continue }
                    var response: [String: Any] = ["questionId": questionId]
                    if let stringValue = value as? String {
                        response["responseValue"] = stringValue
                    } else if let numberValue = value as? Double {
                        response["responseNumber"] = numberValue
                    } else if let arrayValue = value as? [String] {
                        response["responseArray"] = arrayValue
                    }
                    convexResponses.append(response)
                }

                // Also save auto-derived responses from profile (for STOP-BANG scoring)
                let derivedResponses = getDerivedResponsesFromProfile()
                for response in derivedResponses {
                    convexResponses.append(response)
                }

                if !convexResponses.isEmpty {
                    _ = try await ConvexService.shared.saveResponses(dayNumber: currentDay, responses: convexResponses)
                }

                // For Days 6+, mark the scheduled expansion as completed in Convex
                if currentDay >= 6 {
                    try await ConvexService.shared.markDayExpansionCompleted(dayNumber: currentDay)
                    print("[ExpansionPack] Marked day \(currentDay) expansion as completed in Convex")
                }

                await MainActor.run {
                    // Mark these gateways as having completed their expansion (for Days 1-5)
                    QuestionnaireManager.shared.markExpansionCompleted(gateways: expansionInfo.triggeredGateways)

                    // Also clear the cached scheduled expansion so UI updates
                    if currentDay >= 6 {
                        QuestionnaireManager.shared.scheduledExpansionForToday = nil
                    }

                    isSaving = false
                    withAnimation {
                        showingCompletion = true
                    }
                }
            } catch {
                print("[ExpansionPack] Error saving: \(error)")
                await MainActor.run {
                    // Still mark as completed locally
                    QuestionnaireManager.shared.markExpansionCompleted(gateways: expansionInfo.triggeredGateways)

                    // Clear the cached expansion even on error - user completed it
                    if currentDay >= 6 {
                        QuestionnaireManager.shared.scheduledExpansionForToday = nil
                    }

                    isSaving = false
                    // Still show completion - responses saved locally
                    withAnimation {
                        showingCompletion = true
                    }
                }
            }
        }
    }

    /// Get responses that can be auto-derived from onboarding profile and previous gateway answers
    /// This ensures clinical scoring instruments get complete data without asking redundant questions
    private func getDerivedResponsesFromProfile() -> [[String: Any]] {
        var derivedResponses: [[String: Any]] = []
        let profile = OnboardingManager.shared.profile
        let qm = QuestionnaireManager.shared

        // ===== STOP-BANG Auto-Derived =====

        // SB_5: BMI > 35?
        if let heightCm = profile.heightCm, let weightKg = profile.weightKg,
           heightCm > 0 && weightKg > 0 {
            let heightM = heightCm / 100.0
            let bmi = weightKg / (heightM * heightM)
            let bmiOver35 = bmi > 35
            derivedResponses.append([
                "questionId": "SB_5",
                "responseValue": bmiOver35 ? "Yes" : "No"
            ])
        }

        // SB_6: Age > 50?
        if profile.birthYear > 1900 {
            let currentYear = Calendar.current.component(.year, from: Date())
            let age = currentYear - profile.birthYear
            let ageOver50 = age > 50
            derivedResponses.append([
                "questionId": "SB_6",
                "responseValue": ageOver50 ? "Yes" : "No"
            ])
        }

        // SB_8: Gender = Male?
        let isMale = profile.gender.lowercased() == "male"
        derivedResponses.append([
            "questionId": "SB_8",
            "responseValue": isMale ? "Yes" : "No"
        ])

        // SB_1: Snoring - from Question 19 (gateway)
        if let q19 = qm.responses["19"]?.stringValue {
            let snoringYes = q19 == "Yes"
            derivedResponses.append([
                "questionId": "SB_1",
                "responseValue": snoringYes ? "Yes" : "No"
            ])
        }

        // SB_2: Tired - from Question 17 (gateway, 5-point scale)
        // Q17: ["Never", "Rarely", "Sometimes", "Often", "Always"]
        // STOP-BANG considers "Often" or "Always" as Yes
        if let q17 = qm.responses["17"]?.stringValue {
            let tiredYes = q17 == "Often" || q17 == "Always"
            derivedResponses.append([
                "questionId": "SB_2",
                "responseValue": tiredYes ? "Yes" : "No"
            ])
        }

        // SB_3: Observed stop breathing - from Question 20 (gateway)
        if let q20 = qm.responses["20"]?.stringValue {
            let observedYes = q20 == "Yes"
            derivedResponses.append([
                "questionId": "SB_3",
                "responseValue": observedYes ? "Yes" : "No"
            ])
        }

        // ===== PHQ-9 Auto-Derived =====

        // PHQ9_2: "Feeling down, depressed, or hopeless?" - from Question 15 (gateway)
        // Q15 uses: ["Not at all", "Several days", "More than half the days", "Nearly every day"]
        // PHQ9 uses the same scale, so we can copy directly
        if let q15 = qm.responses["15"]?.stringValue {
            derivedResponses.append([
                "questionId": "PHQ9_2",
                "responseValue": q15
            ])
        }

        // ===== GAD-7 Auto-Derived =====

        // GAD7_1: "Feeling nervous, anxious, or on edge?" - from Question 16 (gateway)
        // Q16 uses: ["Not at all", "Several days", "More than half the days", "Nearly every day"]
        // GAD7 uses the same scale, so we can copy directly
        if let q16 = qm.responses["16"]?.stringValue {
            derivedResponses.append([
                "questionId": "GAD7_1",
                "responseValue": q16
            ])
        }

        return derivedResponses
    }
}

// MARK: - Expansion Completion View

struct ExpansionCompletionView: View {
    let expansionInfo: ExpansionPackInfo
    let onDone: () -> Void

    @State private var isAnimating = false

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var primaryTextColor: Color {
        if isEvening {
            return Color(red: 0.996, green: 0.953, blue: 0.780)
        } else {
            return Color.primary
        }
    }

    private var secondaryTextColor: Color {
        if isEvening {
            return Color(red: 0.988, green: 0.827, blue: 0.302)
        } else {
            return Color.secondary
        }
    }

    private var backgroundColor: Color {
        if isEvening {
            return Color(red: 0.12, green: 0.08, blue: 0.05)
        } else {
            return Color(.systemBackground)
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .opacity(isAnimating ? 0.5 : 1)

                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(QuestionnaireSection.expansionPack.accentColor)
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
            }

            VStack(spacing: 8) {
                Text("Deeper Dive Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(primaryTextColor)

                Text("Thank you for helping us understand you better")
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
            }

            // Summary
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(expansionInfo.questions.count) questions answered")
                        .foregroundColor(primaryTextColor)
                    Spacer()
                }

                ForEach(expansionInfo.triggeredGateways, id: \.self) { gateway in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(QuestionnaireSection.expansionPack.accentColor)
                        Text("\(gateway.displayName) assessment complete")
                            .foregroundColor(secondaryTextColor)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(QuestionnaireSection.expansionPack.backgroundColor)
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            Button(action: onDone) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(backgroundColor)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
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
