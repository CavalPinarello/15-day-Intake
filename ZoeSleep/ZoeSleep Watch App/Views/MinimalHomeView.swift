//
//  MinimalHomeView.swift
//  ZoeSleep Watch App
//
//  The main hub for the minimal watch app.
//  Shows garden, time-locked check-ins, and categorized tasks.
//

import SwiftUI
import WatchKit
import Charts

// MARK: - Minimal Home View

struct MinimalHomeView: View {
    @StateObject private var gardenManager = GardenManager.shared
    @StateObject private var convexService = WatchConvexService.shared
    @StateObject private var healthKitManager = HealthKitWatchManager()
    @State private var checkInStatus: WatchCheckInStatus?
    @State private var taskStatus: WatchTaskStatus?
    @State private var circadianStatus: WatchCircadianStatusResponse?
    @State private var showCheckInFlow = false
    @State private var showTasks = false
    @State private var showTrends = false
    @State private var showSleepStages = false
    @State private var showLightEducation = false
    @AppStorage("hasSeenLightEducation") private var hasSeenLightEducation = false
    @State private var isLoading = true
    @State private var isSigningIn = false
    @State private var signInError: String?
    @State private var currentHour = Calendar.current.component(.hour, from: Date())
    @State private var encouragementMessage: String?
    @State private var checkInError: String?

    private let palette = WatchCircadianPalette.current

    // Card background color - always light on dark since we use dark background
    private var cardBackground: Color {
        Color.white.opacity(0.1)
    }

    // Time-based check-in window
    private var currentCheckInWindow: CheckInWindow {
        CheckInWindow.current(hour: currentHour)
    }

    // Always use dark background for watchOS (OLED-friendly, better readability)
    private var darkBackground: [Color] {
        [
            Color(red: 0.08, green: 0.08, blue: 0.10),
            Color(red: 0.12, green: 0.12, blue: 0.14)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Show connection status if not authenticated
                if !convexService.isAuthenticated {
                    notAuthenticatedCard
                } else {
                    // Weekly Garden
                    if let garden = gardenManager.garden {
                        WeeklyGardenView(garden: garden)
                    } else {
                        WeeklyGardenView(garden: GardenManager.createEmptyGarden())
                    }

                    // Show logged-in user for debugging
                    #if DEBUG
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        Text(convexService.username ?? "unknown")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Day \(convexService.currentDay)")
                            .font(.system(size: 10))
                            .foregroundColor(palette.accent)

                        // Sign out button for testing
                        Button(action: {
                            convexService.clearCredentials()
                        }) {
                            Image(systemName: "arrow.right.square")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    #endif

                    // Check-In Cards (time-locked)
                    checkInSection

                    // Tasks Card
                    tasksCard

                    // Circadian Light Exposure Card
                    circadianCard

                    // Trends Card
                    trendsCard

                    // Sleep Stages Card (Experimental)
                    sleepStagesCard

                    // Streak Card
                    streakCard

                    // Encouragement message (shows briefly after check-in)
                    if let message = encouragementMessage {
                        Text(message)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.15))
                            )
                            .transition(.opacity.combined(with: .scale))
                    }

                    // Error message (shows when check-in fails)
                    if let error = checkInError {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text("Check-in failed!")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.red)

                            Text(error)
                                .font(.system(size: 9))
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(4)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.15))
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .background(
            LinearGradient(
                colors: darkBackground,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showCheckInFlow) {
            if let type = currentCheckInWindow.checkInType, canDoCheckIn(for: type) {
                QuickCheckInFlowView(checkInType: type) { energy, mood, focus in
                    submitCheckIn(energy: energy, mood: mood, focus: focus, type: type)
                }
            }
        }
        .sheet(isPresented: $showTasks) {
            MinimalTasksView(
                taskStatus: taskStatus ?? .empty,
                overdueExpansionsCount: convexService.overdueExpansionsCount
            )
        }
        .sheet(isPresented: $showTrends) {
            CheckInTrendsView()
        }
        .sheet(isPresented: $showSleepStages) {
            SleepStagesView()
        }
        .sheet(isPresented: $showLightEducation) {
            LightExposureEducationView()
        }
        .onAppear {
            loadData()
            startTimeUpdates()
            // Reset notification tracking for new day
            WatchNotificationManager.shared.resetForNewDay()
        }
    }

    // MARK: - Check-In Section

    private var checkInSection: some View {
        VStack(spacing: 8) {
            // Morning
            checkInRow(
                type: .morning,
                window: "5 AM – 12 PM",
                isActive: currentCheckInWindow == .morning,
                isDone: checkInStatus?.morningDone ?? false
            )

            // Afternoon
            checkInRow(
                type: .midday,
                window: "12 PM – 6 PM",
                isActive: currentCheckInWindow == .afternoon,
                isDone: checkInStatus?.middayDone ?? false
            )

            // Evening
            checkInRow(
                type: .evening,
                window: "6 PM – 12 AM",
                isActive: currentCheckInWindow == .evening,
                isDone: checkInStatus?.eveningDone ?? false
            )
        }
    }

    private func checkInRow(type: CheckInType, window: String, isActive: Bool, isDone: Bool) -> some View {
        let canTap = isActive && !isDone

        return Button(action: {
            if canTap {
                showCheckInFlow = true
            }
        }) {
            HStack(spacing: 8) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(rowColor(isActive: isActive, isDone: isDone).opacity(0.2))
                        .frame(width: 32, height: 32)

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: type.sfSymbol)
                            .font(.system(size: 14))
                            .foregroundColor(rowColor(isActive: isActive, isDone: isDone))
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(type.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isDone ? .white.opacity(0.6) : .white)

                    Text(window)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Status badge
                if isDone {
                    Text("Done")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Capsule())
                } else if isActive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Locked")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6).opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardBackground.opacity(isDone ? 0.5 : 1))
            )
            .opacity(canTap ? 1 : (isDone ? 0.7 : 0.5))
        }
        .buttonStyle(.plain)
        .disabled(!canTap)
    }

    private func rowColor(isActive: Bool, isDone: Bool) -> Color {
        if isDone { return .green }
        if isActive { return palette.accent }
        return .gray
    }

    private func canDoCheckIn(for type: CheckInType) -> Bool {
        guard let status = checkInStatus else { return true }
        switch type {
        case .morning: return !status.morningDone && currentCheckInWindow == .morning
        case .midday: return !status.middayDone && currentCheckInWindow == .afternoon
        case .evening: return !status.eveningDone && currentCheckInWindow == .evening
        }
    }

    // MARK: - Tasks Card

    private var tasksCard: some View {
        Button(action: { showTasks = true }) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Today's Tasks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)

                    Text(taskSummary)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Badge
                if let status = taskStatus, status.pendingCount > 0 {
                    Text("\(status.pendingCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.blue))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var taskSummary: String {
        guard let status = taskStatus else { return "Loading..." }
        if status.pendingCount == 0 { return "All done!" }
        var items: [String] = []
        if !status.sleepLogDone { items.append("Sleep Log") }
        if !status.assessmentDone { items.append("Assessment") }
        if status.pendingProtocolCount > 0 { items.append("Protocol") }
        return items.prefix(2).joined(separator: ", ")
    }

    // MARK: - Trends Card

    private var trendsCard: some View {
        Button(action: { showTrends = true }) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("My Trends")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)

                    Text("Energy, Mood & Focus")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sleep Stages Card (Experimental)

    private var sleepStagesCard: some View {
        Button(action: { showSleepStages = true }) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.indigo)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("Sleep Stages")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)

                        Text("BETA")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.indigo)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.3))
                            .clipShape(Capsule())
                    }

                    Text("Chronotype & Circadian Fit")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Not Authenticated Card

    private var notAuthenticatedCard: some View {
        VStack(spacing: 12) {
            Spacer()
                .frame(height: 20)  // Space for status bar

            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "iphone.and.arrow.forward")
                    .font(.system(size: 22))
                    .foregroundColor(.orange)
            }

            Text("Connect to iPhone")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text("Open the Zoe Sleep app on your iPhone to sync your account")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // Manual sign-in for simulator testing
            #if DEBUG
            VStack(spacing: 6) {
                // Try auto-generated username (from email prefix)
                Button(action: {
                    trySignIn(username: "caval.apps")
                }) {
                    Text(isSigningIn ? "Signing in..." : "Sign in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSigningIn)

                if let error = signInError {
                    Text(error)
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.top, 8)
            #endif

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Circadian Card

    @ViewBuilder
    private var circadianCard: some View {
        // Prefer local HealthKit data (real-time from Watch sensors)
        if let localData = healthKitManager.daylightExposure {
            CircadianExposureCard(
                status: CircadianStatus(
                    hasData: true,
                    daylightMins: localData.totalMinutes,
                    targetMins: localData.targetMinutes,
                    percentOfTarget: localData.percentOfTarget,
                    circadianScore: circadianStatus?.circadianScore, // Use backend score if available
                    needsMoreLight: localData.needsMoreLight,
                    morningLightMins: localData.morningMinutes
                ),
                onTap: { handleLightCardTap() },
                onInfoTap: hasSeenLightEducation ? { showLightEducation = true } : nil
            )
        } else if let status = circadianStatus {
            // Fall back to backend data
            CircadianExposureCard(
                status: CircadianStatus(
                    hasData: status.hasData,
                    daylightMins: status.daylightMins,
                    targetMins: status.targetMins,
                    percentOfTarget: status.percentOfTarget,
                    circadianScore: status.circadianScore,
                    needsMoreLight: status.needsMoreLight,
                    morningLightMins: status.morningLightMins
                ),
                onTap: { handleLightCardTap() },
                onInfoTap: hasSeenLightEducation ? { showLightEducation = true } : nil
            )
        } else {
            // Show empty state card with "Go outside!" nudge
            Button(action: { handleLightCardTap() }) {
                CircadianExposureEmptyCard()
            }
            .buttonStyle(.plain)
        }
    }

    private func handleLightCardTap() {
        // Show education only on first tap
        if !hasSeenLightEducation {
            showLightEducation = true
            hasSeenLightEducation = true
        }
        // After first view, info button appears for on-demand access
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack {
            // Flame icon
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(gardenManager.garden?.currentStreak ?? 0) Day Streak")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text("Best: \(gardenManager.garden?.longestStreak ?? 0) days")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground.opacity(0.7))
        )
    }

    // MARK: - Time Updates

    private func startTimeUpdates() {
        // Update current hour periodically
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentHour = Calendar.current.component(.hour, from: Date())
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        isLoading = true

        // Request HealthKit permissions and sync daylight exposure data
        healthKitManager.requestPermissions()

        // Load garden (use empty for now, will sync from Convex)
        if gardenManager.garden == nil {
            gardenManager.garden = GardenManager.createEmptyGarden()
        }

        // Fetch actual state from Convex
        Task {
            do {
                // Refresh journey state (includes sleepLogCompleted, assessmentCompleted, overdueExpansionsCount)
                await convexService.refreshFromConvex()

                // Fetch check-in status
                let checkInResponse = try await convexService.getWatchCheckInStatus()
                await MainActor.run {
                    checkInStatus = WatchCheckInStatus(
                        morningDone: checkInResponse.morningDone,
                        middayDone: checkInResponse.middayDone,
                        eveningDone: checkInResponse.eveningDone,
                        totalDone: checkInResponse.totalDone,
                        recommendedNext: checkInResponse.recommendedNext,
                        lastEnergyLevel: checkInResponse.lastEnergyLevel,
                        lastMoodLevel: checkInResponse.lastMoodLevel,
                        lastFocusLevel: checkInResponse.lastFocusLevel
                    )
                }
            } catch {
                print("[MinimalHomeView] Failed to fetch check-in status: \(error)")
                // Use default status on error
                await MainActor.run {
                    checkInStatus = WatchCheckInStatus(
                        morningDone: false,
                        middayDone: false,
                        eveningDone: false,
                        totalDone: 0,
                        recommendedNext: currentCheckInWindow.checkInType?.rawValue,
                        lastEnergyLevel: nil,
                        lastMoodLevel: nil,
                        lastFocusLevel: nil
                    )
                }
            }

            // Update task status from Convex service state
            await MainActor.run {
                taskStatus = WatchTaskStatus(
                    sleepLogDone: convexService.sleepLogCompleted,
                    assessmentDone: convexService.assessmentCompleted,
                    protocolTasks: []  // Protocol tasks will be populated when physician assigns interventions
                )
                isLoading = false
            }

            // Fetch circadian status for light exposure card
            do {
                let circadianResponse = try await convexService.getCircadianStatus()
                await MainActor.run {
                    circadianStatus = circadianResponse
                }
            } catch {
                print("[MinimalHomeView] Failed to fetch circadian status: \(error)")
                // Leave circadianStatus as nil - empty state card will show
            }
        }
    }

    private func submitCheckIn(energy: EnergyLevel, mood: MoodLevel, focus: FocusLevel, type: CheckInType) {
        print("[MinimalHomeView] Check-in submitted: \(energy.label), \(mood.label), \(focus.label)")

        // Clear any previous error
        withAnimation {
            checkInError = nil
        }

        // Save old status for potential rollback
        let oldStatus = checkInStatus

        // Play success haptic (optimistic)
        WKInterfaceDevice.current().play(.success)

        // Update local state optimistically
        let todayDate = formatDate(Date())
        let newCheckInsCount = (checkInStatus?.totalDone ?? 0) + 1

        gardenManager.updateDayBloom(
            date: todayDate,
            checkInsCompleted: newCheckInsCount,
            tasksCompleted: taskStatus?.completedCount ?? 0,
            totalTasks: taskStatus?.totalCount ?? 0
        )

        // Show encouragement message with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            encouragementMessage = EncouragementMessages.personalizedMessage(
                energy: energy.rawValue,
                mood: mood.rawValue,
                focus: focus.rawValue
            )
        }

        // Hide message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                encouragementMessage = nil
            }
        }

        // Cancel remaining reminders for this slot (streak is from garden manager)
        let currentStreak = gardenManager.garden?.currentStreak ?? 1
        WatchNotificationManager.shared.markCheckInComplete(
            type: type.rawValue,
            energy: energy.rawValue,
            mood: mood.rawValue,
            focus: focus.rawValue,
            streak: currentStreak
        )

        // Update check-in status optimistically based on type
        if let currentStatus = checkInStatus {
            switch type {
            case .morning:
                checkInStatus = WatchCheckInStatus(
                    morningDone: true,
                    middayDone: currentStatus.middayDone,
                    eveningDone: currentStatus.eveningDone,
                    totalDone: newCheckInsCount,
                    recommendedNext: "midday",
                    lastEnergyLevel: energy.rawValue,
                    lastMoodLevel: mood.rawValue,
                    lastFocusLevel: focus.rawValue
                )
            case .midday:
                checkInStatus = WatchCheckInStatus(
                    morningDone: currentStatus.morningDone,
                    middayDone: true,
                    eveningDone: currentStatus.eveningDone,
                    totalDone: newCheckInsCount,
                    recommendedNext: "evening",
                    lastEnergyLevel: energy.rawValue,
                    lastMoodLevel: mood.rawValue,
                    lastFocusLevel: focus.rawValue
                )
            case .evening:
                checkInStatus = WatchCheckInStatus(
                    morningDone: currentStatus.morningDone,
                    middayDone: currentStatus.middayDone,
                    eveningDone: true,
                    totalDone: newCheckInsCount,
                    recommendedNext: nil,
                    lastEnergyLevel: energy.rawValue,
                    lastMoodLevel: mood.rawValue,
                    lastFocusLevel: focus.rawValue
                )
            }
        }

        // Submit to Convex
        Task {
            do {
                print("[MinimalHomeView] Calling Convex submitWatchCheckIn...")
                print("[MinimalHomeView] - checkInType: \(type.rawValue)")
                print("[MinimalHomeView] - energyLevel: \(energy.rawValue)")
                print("[MinimalHomeView] - moodLevel: \(mood.rawValue)")
                print("[MinimalHomeView] - focusLevel: \(focus.rawValue)")
                print("[MinimalHomeView] - userId: \(convexService.userId ?? "nil")")

                let response = try await convexService.submitWatchCheckIn(
                    checkInType: type.rawValue,
                    energyLevel: energy.rawValue,
                    moodLevel: mood.rawValue,
                    focusLevel: focus.rawValue
                )
                print("[MinimalHomeView] Check-in saved to Convex! success=\(response.success), checkInId=\(response.checkInId ?? "nil")")

                // Sync garden after check-in
                _ = try await convexService.syncGardenAfterCheckIn(
                    checkInsCompletedToday: response.checkInsCompletedToday
                )
            } catch {
                print("[MinimalHomeView] ❌ FAILED to submit check-in: \(error)")
                print("[MinimalHomeView] Error details: \(String(describing: error))")

                // Rollback optimistic UI update
                await MainActor.run {
                    checkInStatus = oldStatus

                    // Play failure haptic
                    WKInterfaceDevice.current().play(.failure)

                    // Show error with animation
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        encouragementMessage = nil
                        checkInError = error.localizedDescription
                    }

                    // Hide error after 8 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            checkInError = nil
                        }
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    #if DEBUG
    private func trySignIn(username: String) {
        guard !isSigningIn else { return }
        isSigningIn = true
        signInError = nil
        Task {
            var error: String? = nil

            // Try combinations: username+test, username+1, email+test, email+1
            let attempts: [(String, String)] = [
                (username, "test"),
                (username, "1"),
                ("caval.apps@gmail.com", "test"),
                ("caval.apps@gmail.com", "1"),
            ]

            for (user, pass) in attempts {
                error = await convexService.signInForTesting(username: user, password: pass)
                if error == nil {
                    break  // Success!
                }
                print("[Watch] Sign-in attempt failed: \(user) / \(pass) - \(error ?? "")")
            }

            await MainActor.run {
                isSigningIn = false
                if error == nil {
                    loadData()
                } else {
                    // Show a cleaner error message
                    let cleanError = error ?? "Unknown error"
                    if cleanError.contains("User not found") {
                        signInError = "User not found"
                    } else if cleanError.contains("Invalid password") {
                        signInError = "Wrong password"
                    } else {
                        signInError = String(cleanError.prefix(50))
                    }
                }
            }
        }
    }
    #endif
}

// MARK: - Check-In Window

enum CheckInWindow: Equatable {
    case morning    // 5 AM - 12 PM
    case afternoon  // 12 PM - 6 PM
    case evening    // 6 PM - 12 AM
    case night      // 12 AM - 5 AM (no check-in)

    static func current(hour: Int) -> CheckInWindow {
        switch hour {
        case 5..<12: return .morning
        case 12..<18: return .afternoon
        case 18..<24: return .evening
        default: return .night
        }
    }

    var checkInType: CheckInType? {
        switch self {
        case .morning: return .morning
        case .afternoon: return .midday
        case .evening: return .evening
        case .night: return nil
        }
    }
}

// MARK: - Task Status Models

struct WatchTaskStatus {
    var sleepLogDone: Bool
    var assessmentDone: Bool
    var protocolTasks: [ProtocolTask]

    var pendingCount: Int {
        var count = 0
        if !sleepLogDone { count += 1 }
        if !assessmentDone { count += 1 }
        count += protocolTasks.filter { !$0.isCompleted }.count
        return count
    }

    var completedCount: Int {
        var count = 0
        if sleepLogDone { count += 1 }
        if assessmentDone { count += 1 }
        count += protocolTasks.filter { $0.isCompleted }.count
        return count
    }

    var totalCount: Int {
        2 + protocolTasks.count
    }

    var pendingProtocolCount: Int {
        protocolTasks.filter { !$0.isCompleted }.count
    }

    static var empty: WatchTaskStatus {
        WatchTaskStatus(sleepLogDone: false, assessmentDone: false, protocolTasks: [])
    }
}

struct ProtocolTask: Identifiable {
    let id: String
    let name: String
    let timing: String
    var isCompleted: Bool
}

// MARK: - Preview

#if DEBUG
struct MinimalHomeView_Previews: PreviewProvider {
    static var previews: some View {
        MinimalHomeView()
    }
}
#endif

// MARK: - Check-In Trends View

/// A data point for the trends chart
struct TrendDataPoint: Identifiable {
    let id = UUID()
    let dayIndex: Int        // 0 = 7 days ago, 6 = today
    let dayLabel: String     // "Mon", "Tue", etc. or "AM", "Noon", "PM"
    let energy: Int?         // nil = no data
    let mood: Int?
    let focus: Int?
    let hasData: Bool

    var energyValue: Int { energy ?? 0 }
    var moodValue: Int { mood ?? 0 }
    var focusValue: Int { focus ?? 0 }
}

/// Observable class to manage trends data loading from Convex
@MainActor
class TrendsDataManager: ObservableObject {
    static let shared = TrendsDataManager()

    @Published var todayData: [TrendDataPoint] = []
    @Published var weekData: [TrendDataPoint] = []
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    func loadTrends(forceRefresh: Bool = true) async {
        guard WatchConvexService.shared.isAuthenticated else {
            error = "Not signed in"
            return
        }

        isLoading = true
        error = nil

        // Clear previous data to ensure fresh load
        if forceRefresh {
            todayData = []
            weekData = []
        }

        do {
            let response = try await WatchConvexService.shared.getWatchCheckInTrends()

            #if DEBUG
            print("TrendsDataManager: Loaded trends data")
            print("  Today morning: \(response.today.morning != nil ? "✓" : "✗")")
            print("  Today midday: \(response.today.midday != nil ? "✓" : "✗")")
            print("  Today evening: \(response.today.evening != nil ? "✓" : "✗")")
            if let midday = response.today.midday {
                print("  Midday data: E=\(midday.energy) M=\(midday.mood) F=\(midday.focus)")
            }
            print("  Week data days: \(response.week.count), with data: \(response.week.filter { $0.hasData }.count)")
            #endif

            // Build today's data from response
            var today: [TrendDataPoint] = []

            // Morning slot
            if let morning = response.today.morning {
                today.append(TrendDataPoint(
                    dayIndex: 0,
                    dayLabel: "AM",
                    energy: morning.energy,
                    mood: morning.mood,
                    focus: morning.focus,
                    hasData: true
                ))
            } else {
                today.append(TrendDataPoint(
                    dayIndex: 0,
                    dayLabel: "AM",
                    energy: nil,
                    mood: nil,
                    focus: nil,
                    hasData: false
                ))
            }

            // Midday slot
            if let midday = response.today.midday {
                today.append(TrendDataPoint(
                    dayIndex: 1,
                    dayLabel: "Noon",
                    energy: midday.energy,
                    mood: midday.mood,
                    focus: midday.focus,
                    hasData: true
                ))
            } else {
                today.append(TrendDataPoint(
                    dayIndex: 1,
                    dayLabel: "Noon",
                    energy: nil,
                    mood: nil,
                    focus: nil,
                    hasData: false
                ))
            }

            // Evening slot
            if let evening = response.today.evening {
                today.append(TrendDataPoint(
                    dayIndex: 2,
                    dayLabel: "PM",
                    energy: evening.energy,
                    mood: evening.mood,
                    focus: evening.focus,
                    hasData: true
                ))
            } else {
                today.append(TrendDataPoint(
                    dayIndex: 2,
                    dayLabel: "PM",
                    energy: nil,
                    mood: nil,
                    focus: nil,
                    hasData: false
                ))
            }

            self.todayData = today

            // Build week data from response
            self.weekData = response.week.enumerated().map { index, day in
                if day.hasData {
                    return TrendDataPoint(
                        dayIndex: index,
                        dayLabel: String(day.dayOfWeek.prefix(1)), // "Mon" -> "M"
                        energy: day.avgEnergy.map { Int(round($0)) },
                        mood: day.avgMood.map { Int(round($0)) },
                        focus: day.avgFocus.map { Int(round($0)) },
                        hasData: true
                    )
                } else {
                    return TrendDataPoint(
                        dayIndex: index,
                        dayLabel: String(day.dayOfWeek.prefix(1)),
                        energy: nil,
                        mood: nil,
                        focus: nil,
                        hasData: false
                    )
                }
            }

            print("[TrendsData] Loaded: \(today.filter { $0.hasData }.count) today, \(self.weekData.filter { $0.hasData }.count) week days")

        } catch {
            self.error = error.localizedDescription
            print("[TrendsData] Error loading trends: \(error)")
        }

        isLoading = false
    }
}

struct CheckInTrendsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var trendsManager = TrendsDataManager.shared
    @State private var selectedPage = 0

    private var darkBackground: [Color] {
        [
            Color(red: 0.08, green: 0.08, blue: 0.10),
            Color(red: 0.12, green: 0.12, blue: 0.14)
        ]
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPage) {
                // Page 1: Today
                TodayTrendsPage(trendsManager: trendsManager)
                    .tag(0)

                // Page 2: Week
                WeekTrendsPage(trendsManager: trendsManager)
                    .tag(1)
            }
            .tabViewStyle(.verticalPage)
            .background(
                LinearGradient(colors: darkBackground, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle(selectedPage == 0 ? "Today" : "Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            Task {
                await trendsManager.loadTrends()
            }
        }
    }
}

// MARK: - Today's Trends Page

struct TodayTrendsPage: View {
    @ObservedObject var trendsManager: TrendsDataManager

    private var dataWithValues: [TrendDataPoint] {
        trendsManager.todayData.filter { $0.hasData }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Vertical page indicator (matches vertical swipe)
                VStack(spacing: 3) {
                    Circle().fill(Color.white).frame(width: 5, height: 5)
                    Circle().fill(Color.white.opacity(0.3)).frame(width: 5, height: 5)
                }
                .padding(.top, 4)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text("Today's Check-ins")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                if trendsManager.isLoading {
                    loadingState
                } else if let error = trendsManager.error {
                    errorState(error)
                } else if dataWithValues.isEmpty {
                    emptyTodayState
                } else {
                    todayChart
                    todayStats
                }

                // Live data indicator
                if !trendsManager.isLoading && trendsManager.error == nil {
                    liveDataNote
                }

                Text("Swipe down for week view")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 20)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 6) {
            ProgressView()
                .tint(.white)
            Text("Loading...")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(height: 80)
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            Text("Couldn't load data")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            Text(error)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
                .lineLimit(2)
        }
        .frame(height: 80)
    }

    private var emptyTodayState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.4))
            Text("No check-ins yet today")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            Text("Complete a check-in to see data")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(height: 80)
    }

    private var todayChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart {
                ForEach(dataWithValues) { point in
                    PointMark(x: .value("Time", point.dayLabel), y: .value("Level", point.energyValue))
                        .foregroundStyle(.orange)
                        .symbolSize(40)
                    PointMark(x: .value("Time", point.dayLabel), y: .value("Level", point.moodValue))
                        .foregroundStyle(.yellow)
                        .symbolSize(40)
                    PointMark(x: .value("Time", point.dayLabel), y: .value("Level", point.focusValue))
                        .foregroundStyle(.cyan)
                        .symbolSize(40)
                }

                ForEach(dataWithValues) { point in
                    LineMark(x: .value("Time", point.dayLabel), y: .value("Level", point.energyValue), series: .value("Type", "E"))
                        .foregroundStyle(.orange.opacity(0.7))
                    LineMark(x: .value("Time", point.dayLabel), y: .value("Level", point.moodValue), series: .value("Type", "M"))
                        .foregroundStyle(.yellow.opacity(0.7))
                    LineMark(x: .value("Time", point.dayLabel), y: .value("Level", point.focusValue), series: .value("Type", "F"))
                        .foregroundStyle(.cyan.opacity(0.7))
                }
            }
            .chartYScale(domain: 1...6)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label).font(.system(size: 9)).foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            .frame(height: 70)

            // Compact legend
            HStack(spacing: 10) {
                legendDot(color: .orange, label: "Energy")
                legendDot(color: .yellow, label: "Mood")
                legendDot(color: .cyan, label: "Focus")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
    }

    private var todayStats: some View {
        HStack(spacing: 6) {
            statBubble(value: avgValue(\.energy), label: "E", color: .orange)
            statBubble(value: avgValue(\.mood), label: "M", color: .yellow)
            statBubble(value: avgValue(\.focus), label: "F", color: .cyan)
        }
    }

    private func avgValue(_ keyPath: KeyPath<TrendDataPoint, Int?>) -> String {
        let values = dataWithValues.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return "-" }
        return String(format: "%.1f", Double(values.reduce(0, +)) / Double(values.count))
    }

    private func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 2) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.6))
        }
    }

    private var liveDataNote: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 8))
            Text("Live from Convex")
                .font(.system(size: 8))
        }
        .foregroundColor(.green.opacity(0.8))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.1)))
    }
}

// MARK: - Week Trends Page

struct WeekTrendsPage: View {
    @ObservedObject var trendsManager: TrendsDataManager

    private var dataWithValues: [TrendDataPoint] {
        trendsManager.weekData.filter { $0.hasData }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Vertical page indicator (matches vertical swipe)
                VStack(spacing: 3) {
                    Circle().fill(Color.white.opacity(0.3)).frame(width: 5, height: 5)
                    Circle().fill(Color.white).frame(width: 5, height: 5)
                }
                .padding(.top, 4)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text("Weekly Trends")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                if trendsManager.isLoading {
                    loadingState
                } else if let error = trendsManager.error {
                    errorState(error)
                } else {
                    weekChart

                    if trendsManager.weekData.contains(where: { !$0.hasData }) {
                        gapNote
                    }

                    weekStats

                    // Live data indicator
                    liveDataNote
                }

                Text("Swipe up for today")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 20)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 6) {
            ProgressView()
                .tint(.white)
            Text("Loading...")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(height: 80)
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            Text("Couldn't load data")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(height: 80)
    }

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart {
                // Data points
                ForEach(dataWithValues) { point in
                    PointMark(x: .value("Day", point.dayLabel), y: .value("Level", point.energyValue))
                        .foregroundStyle(.orange)
                        .symbolSize(25)
                    PointMark(x: .value("Day", point.dayLabel), y: .value("Level", point.moodValue))
                        .foregroundStyle(.yellow)
                        .symbolSize(25)
                    PointMark(x: .value("Day", point.dayLabel), y: .value("Level", point.focusValue))
                        .foregroundStyle(.cyan)
                        .symbolSize(25)
                }

                // Lines with dashed style for gaps
                ForEach(dataWithValues) { point in
                    LineMark(x: .value("Day", point.dayLabel), y: .value("Level", point.energyValue), series: .value("Type", "E"))
                        .foregroundStyle(.orange.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: hasGapBefore(point) ? [3, 2] : []))
                    LineMark(x: .value("Day", point.dayLabel), y: .value("Level", point.moodValue), series: .value("Type", "M"))
                        .foregroundStyle(.yellow.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: hasGapBefore(point) ? [3, 2] : []))
                    LineMark(x: .value("Day", point.dayLabel), y: .value("Level", point.focusValue), series: .value("Type", "F"))
                        .foregroundStyle(.cyan.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: hasGapBefore(point) ? [3, 2] : []))
                }

                // X marks for missing days
                ForEach(trendsManager.weekData.filter { !$0.hasData }) { point in
                    PointMark(x: .value("Day", point.dayLabel), y: .value("Level", 3.5))
                        .foregroundStyle(.white.opacity(0.2))
                        .annotation {
                            Text("X")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                }
            }
            .chartYScale(domain: 1...6)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            .frame(height: 80)

            // Legend
            HStack(spacing: 10) {
                legendDot(color: .orange, label: "Energy")
                legendDot(color: .yellow, label: "Mood")
                legendDot(color: .cyan, label: "Focus")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
    }

    private func hasGapBefore(_ point: TrendDataPoint) -> Bool {
        guard let currentIndex = dataWithValues.firstIndex(where: { $0.id == point.id }) else { return false }
        guard currentIndex > 0 else { return false }
        let previousPoint = dataWithValues[currentIndex - 1]
        return point.dayIndex - previousPoint.dayIndex > 1
    }

    private var gapNote: some View {
        HStack(spacing: 3) {
            Text("---")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            Text("= missed days")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var weekStats: some View {
        HStack(spacing: 6) {
            statBubble(value: avgValue(\.energy), label: "E", color: .orange)
            statBubble(value: avgValue(\.mood), label: "M", color: .yellow)
            statBubble(value: avgValue(\.focus), label: "F", color: .cyan)

            // Days tracked
            VStack(spacing: 1) {
                Text("\(dataWithValues.count)/7")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("days")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
        }
    }

    private func avgValue(_ keyPath: KeyPath<TrendDataPoint, Int?>) -> String {
        let values = dataWithValues.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return "-" }
        return String(format: "%.1f", Double(values.reduce(0, +)) / Double(values.count))
    }

    private func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 2) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.6))
        }
    }

    private var liveDataNote: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 8))
            Text("Live from Convex")
                .font(.system(size: 8))
        }
        .foregroundColor(.green.opacity(0.8))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.1)))
    }
}
