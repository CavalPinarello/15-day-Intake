//
//  MinimalHomeView.swift
//  ZoeSleep Watch App
//
//  The main hub for the minimal watch app.
//  Shows garden, time-locked check-ins, and categorized tasks.
//

import SwiftUI
import WatchKit

// MARK: - Minimal Home View

struct MinimalHomeView: View {
    @StateObject private var gardenManager = GardenManager.shared
    @StateObject private var convexService = WatchConvexService.shared
    @State private var checkInStatus: WatchCheckInStatus?
    @State private var taskStatus: WatchTaskStatus?
    @State private var showCheckInFlow = false
    @State private var showTasks = false
    @State private var isLoading = true
    @State private var currentHour = Calendar.current.component(.hour, from: Date())

    private let palette = WatchCircadianPalette.current

    // Card background color derived from palette
    private var cardBackground: Color {
        palette.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }

    // Time-based check-in window
    private var currentCheckInWindow: CheckInWindow {
        CheckInWindow.current(hour: currentHour)
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
                            .foregroundColor(palette.textSecondary)
                        Text(convexService.username ?? "unknown")
                            .font(.system(size: 10))
                            .foregroundColor(palette.textSecondary)
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

                    // Streak Card
                    streakCard
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .background(
            LinearGradient(colors: palette.background, startPoint: .top, endPoint: .bottom)
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
        .onAppear {
            loadData()
            startTimeUpdates()
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
                        .foregroundColor(isDone ? palette.textSecondary : palette.textPrimary)

                    Text(window)
                        .font(.system(size: 9))
                        .foregroundColor(palette.textSecondary)
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
                        .foregroundColor(palette.textSecondary)
                } else {
                    Text("Locked")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(palette.textSecondary.opacity(0.6))
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
                        .foregroundColor(palette.textPrimary)

                    Text(taskSummary)
                        .font(.system(size: 9))
                        .foregroundColor(palette.textSecondary)
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

    // MARK: - Not Authenticated Card

    private var notAuthenticatedCard: some View {
        VStack(spacing: 12) {
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
                .foregroundColor(palette.textPrimary)

            Text("Open the Zoe Sleep app on your iPhone to sync your account")
                .font(.system(size: 11))
                .foregroundColor(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // Manual sign-in for simulator testing
            #if DEBUG
            Button(action: {
                Task {
                    // Try to sign in as the same test user
                    // In production, this would come from iPhone
                    _ = await convexService.signInForTesting(username: "user1", password: "1")
                    loadData()
                }
            }) {
                Text("Debug: Sign in as user1")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            #endif
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
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
                    .foregroundColor(palette.textPrimary)

                Text("Best: \(gardenManager.garden?.longestStreak ?? 0) days")
                    .font(.system(size: 9))
                    .foregroundColor(palette.textSecondary)
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
        }
    }

    private func submitCheckIn(energy: EnergyLevel, mood: MoodLevel, focus: FocusLevel, type: CheckInType) {
        // TODO: Submit via WatchConvexService
        print("Check-in submitted: \(energy.label), \(mood.label), \(focus.label)")

        // Update local state
        let todayDate = formatDate(Date())
        let newCheckInsCount = (checkInStatus?.totalDone ?? 0) + 1

        gardenManager.updateDayBloom(
            date: todayDate,
            checkInsCompleted: newCheckInsCount,
            tasksCompleted: taskStatus?.completedCount ?? 0,
            totalTasks: taskStatus?.totalCount ?? 0
        )

        // Update check-in status based on type
        guard let oldStatus = checkInStatus else { return }

        switch type {
        case .morning:
            checkInStatus = WatchCheckInStatus(
                morningDone: true,
                middayDone: oldStatus.middayDone,
                eveningDone: oldStatus.eveningDone,
                totalDone: newCheckInsCount,
                recommendedNext: "midday",
                lastEnergyLevel: energy.rawValue,
                lastMoodLevel: mood.rawValue,
                lastFocusLevel: focus.rawValue
            )
        case .midday:
            checkInStatus = WatchCheckInStatus(
                morningDone: oldStatus.morningDone,
                middayDone: true,
                eveningDone: oldStatus.eveningDone,
                totalDone: newCheckInsCount,
                recommendedNext: "evening",
                lastEnergyLevel: energy.rawValue,
                lastMoodLevel: mood.rawValue,
                lastFocusLevel: focus.rawValue
            )
        case .evening:
            checkInStatus = WatchCheckInStatus(
                morningDone: oldStatus.morningDone,
                middayDone: oldStatus.middayDone,
                eveningDone: true,
                totalDone: newCheckInsCount,
                recommendedNext: nil,
                lastEnergyLevel: energy.rawValue,
                lastMoodLevel: mood.rawValue,
                lastFocusLevel: focus.rawValue
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
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
