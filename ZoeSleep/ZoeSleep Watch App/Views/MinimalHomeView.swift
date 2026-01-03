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
    @StateObject private var convexService = WatchConvexService.shared
    @State private var checkInStatus: WatchCheckInStatus?
    @State private var taskStatus: WatchTaskStatus?
    @State private var showCheckInFlow = false
    @State private var showTasks = false
    @State private var showSleepStages = false
    @State private var isLoading = true
    @State private var isSigningIn = false
    @State private var signInError: String?
    @State private var currentHour = Calendar.current.component(.hour, from: Date())

    private let palette = WatchCircadianPalette.current
    private let watchSize = WatchSizeDetector.current

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
            VStack(spacing: 16) {
                // Show connection status if not authenticated
                if !convexService.isAuthenticated {
                    notAuthenticatedCard
                } else {
                    // MARK: - Group 1: Sleep
                    sleepCard

                    // MARK: - Group 2: Energy, Focus, Mood (Check-ins)
                    checkInCard

                    // MARK: - Group 3: Protocol
                    protocolCard

                    // Debug info (dev only)
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil {
                        debugInfoRow
                    }
                    #endif
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
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
        .sheet(isPresented: $showSleepStages) {
            SleepStagesView()
        }
        .sheet(isPresented: $showTasks) {
            MinimalTasksView(
                taskStatus: taskStatus ?? .empty,
                overdueExpansionsCount: convexService.overdueExpansionsCount
            )
        }
        .onAppear {
            loadData()
            startTimeUpdates()
            WatchNotificationManager.shared.resetForNewDay()
        }
    }

    // MARK: - Group 1: Sleep Card

    private var sleepCard: some View {
        Button(action: { showSleepStages = true }) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.indigo.opacity(0.3))
                        .frame(width: 56, height: 56)

                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.indigo)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep")
                        .font(.system(size: watchSize.titleFontSize, weight: .bold))
                        .foregroundColor(.white)

                    Text("Stages & Timing")
                        .font(.system(size: watchSize.captionFontSize))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Group 2: Check-In Card (Energy, Mood, Focus)

    private var checkInCard: some View {
        let canDoCurrentCheckIn = canDoCheckIn(for: currentCheckInWindow.checkInType ?? .morning)
        let allDone = (checkInStatus?.morningDone ?? false) &&
                      (checkInStatus?.middayDone ?? false) &&
                      (checkInStatus?.eveningDone ?? false)

        return Button(action: {
            if canDoCurrentCheckIn {
                showCheckInFlow = true
            }
        }) {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(palette.accent.opacity(0.3))
                            .frame(width: 56, height: 56)

                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(palette.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check-in")
                            .font(.system(size: watchSize.titleFontSize, weight: .bold))
                            .foregroundColor(.white)

                        Text("Energy · Mood · Focus")
                            .font(.system(size: watchSize.captionFontSize))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    if allDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                    } else if canDoCurrentCheckIn {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                // Status dots for AM / PM / Eve
                HStack(spacing: 20) {
                    checkInDot(label: "AM", isDone: checkInStatus?.morningDone ?? false, isActive: currentCheckInWindow == .morning)
                    checkInDot(label: "PM", isDone: checkInStatus?.middayDone ?? false, isActive: currentCheckInWindow == .afternoon)
                    checkInDot(label: "Eve", isDone: checkInStatus?.eveningDone ?? false, isActive: currentCheckInWindow == .evening)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canDoCurrentCheckIn && !allDone)
        .opacity(canDoCurrentCheckIn || allDone ? 1 : 0.6)
    }

    private func checkInDot(label: String, isDone: Bool, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isDone ? Color.green : (isActive ? palette.accent : Color.gray.opacity(0.3)))
                .frame(width: 14, height: 14)

            Text(label)
                .font(.system(size: watchSize.captionFontSize - 2, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Group 3: Protocol Card

    private var protocolCard: some View {
        let hasTasks = taskStatus?.protocolTasks.isEmpty == false
        let pendingCount = taskStatus?.pendingProtocolCount ?? 0

        return Button(action: { showTasks = true }) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 56, height: 56)

                    Image(systemName: "stethoscope")
                        .font(.system(size: 26))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Protocol")
                        .font(.system(size: watchSize.titleFontSize, weight: .bold))
                        .foregroundColor(.white)

                    if hasTasks {
                        Text("\(pendingCount) remaining")
                            .font(.system(size: watchSize.captionFontSize))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Text("No tasks yet")
                            .font(.system(size: watchSize.captionFontSize))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()

                if hasTasks && pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.system(size: watchSize.fontSize, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.orange))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Debug Info Row

    #if DEBUG
    private var debugInfoRow: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Text(convexService.username ?? "?")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Text("Day \(convexService.currentDay)")
                .font(.system(size: 12))
                .foregroundColor(palette.accent.opacity(0.7))

            Spacer()

            Button(action: { convexService.clearCredentials() }) {
                Image(systemName: "arrow.right.square")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }
    #endif

    // MARK: - Helper Functions

    private func canDoCheckIn(for type: CheckInType) -> Bool {
        guard let status = checkInStatus else { return true }
        switch type {
        case .morning: return !status.morningDone && currentCheckInWindow == .morning
        case .midday: return !status.middayDone && currentCheckInWindow == .afternoon
        case .evening: return !status.eveningDone && currentCheckInWindow == .evening
        }
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

        Task {
            do {
                // Refresh journey state
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

            // Update task status
            await MainActor.run {
                taskStatus = WatchTaskStatus(
                    sleepLogDone: convexService.sleepLogCompleted,
                    assessmentDone: convexService.assessmentCompleted,
                    protocolTasks: []
                )
                isLoading = false
            }
        }
    }

    private func submitCheckIn(energy: EnergyLevel, mood: MoodLevel, focus: FocusLevel, type: CheckInType) {
        print("[MinimalHomeView] Check-in submitted: \(energy.label), \(mood.label), \(focus.label)")

        // Play success haptic
        WKInterfaceDevice.current().play(.success)

        let newCheckInsCount = (checkInStatus?.totalDone ?? 0) + 1

        // Mark check-in complete for notifications
        WatchNotificationManager.shared.markCheckInComplete(
            type: type.rawValue,
            energy: energy.rawValue,
            mood: mood.rawValue,
            focus: focus.rawValue,
            streak: 1
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
                let response = try await convexService.submitWatchCheckIn(
                    checkInType: type.rawValue,
                    energyLevel: energy.rawValue,
                    moodLevel: mood.rawValue,
                    focusLevel: focus.rawValue
                )
                print("[MinimalHomeView] Check-in saved: \(response.success)")
            } catch {
                print("[MinimalHomeView] Failed to submit check-in: \(error)")
                await MainActor.run {
                    WKInterfaceDevice.current().play(.failure)
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
