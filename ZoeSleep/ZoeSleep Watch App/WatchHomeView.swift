//
//  WatchHomeView.swift
//  Zoe Sleep - Sleep Better, Live Longer (watchOS)
//
//  Beautiful start screen with animated circadian ribbons
//  and motivational messaging for each day of the journey
//

import SwiftUI
import WatchKit

// MARK: - Countdown Timer Helper

struct CountdownTimer {
    /// Calculate time until 4 AM (day unlock time)
    static func timeUntil4AM() -> (hours: Int, minutes: Int, seconds: Int, isReady: Bool) {
        let now = Date()
        let calendar = Calendar.current

        // Get today at 4 AM
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 4
        components.minute = 0
        components.second = 0

        guard let todayAt4AM = calendar.date(from: components) else {
            return (0, 0, 0, true)
        }

        let targetDate: Date
        if now >= todayAt4AM {
            // Already past 4 AM today, target is tomorrow at 4 AM
            targetDate = calendar.date(byAdding: .day, value: 1, to: todayAt4AM) ?? todayAt4AM
        } else {
            targetDate = todayAt4AM
        }

        let interval = targetDate.timeIntervalSince(now)

        if interval <= 0 {
            return (0, 0, 0, true)
        }

        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return (hours, minutes, seconds, false)
    }
}

// MARK: - Motivational Messages

struct DayMotivation {
    static let messages: [Int: (title: String, message: String)] = [
        1: ("Welcome", "Your journey to better sleep begins today. Small steps lead to big changes."),
        2: ("Building Habits", "Every answer helps us understand your unique sleep patterns."),
        3: ("You're Doing Great", "Three days in! Consistency is the key to transformation."),
        4: ("Keep Going", "Your dedication to better sleep will pay dividends in energy and health."),
        5: ("Halfway There", "You've built momentum. Your future self will thank you."),
        6: ("Deep Insights", "We're learning what makes your sleep unique. Keep sharing."),
        7: ("One Week Strong", "A full week of commitment! You're building lasting change."),
        8: ("Finding Patterns", "Your sleep story is becoming clearer with each day."),
        9: ("Stay Focused", "Great sleep isn't just rest—it's renewal for mind and body."),
        10: ("Double Digits", "Day 10! Your commitment to wellness is inspiring."),
        11: ("Almost There", "The finish line is in sight. Every day counts."),
        12: ("Building Tomorrow", "Better sleep today means more energy tomorrow."),
        13: ("Final Stretch", "Three more days. You've come so far already."),
        14: ("Penultimate Day", "Tomorrow completes your intake. Keep the momentum!"),
        15: ("Celebration Day", "You made it! Your personalized sleep plan awaits.")
    ]

    static func get(for day: Int) -> (title: String, message: String) {
        return messages[min(max(day, 1), 15)] ?? messages[1]!
    }
}

// MARK: - Animated Circadian Ribbon

struct CircadianRibbon: View {
    let index: Int
    let color: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let midY = height / 2

                // Calculate wave parameters
                let frequency = 0.015 + Double(index) * 0.005
                let amplitude = 15.0 + Double(index) * 8.0
                let verticalOffset = CGFloat(index - 2) * 25.0
                let timeOffset = timeline.date.timeIntervalSinceReferenceDate * (0.5 + Double(index) * 0.2)

                var path = Path()
                path.move(to: CGPoint(x: 0, y: midY + verticalOffset))

                for x in stride(from: 0, to: width, by: 2) {
                    let y = midY + verticalOffset + sin(x * frequency + timeOffset) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                context.stroke(
                    path,
                    with: .color(color.opacity(0.6 - Double(index) * 0.1)),
                    lineWidth: 2.5 - CGFloat(index) * 0.3
                )
            }
        }
    }
}

// MARK: - Animated Background (Sleep-Optimized Circadian Colors)

struct CircadianBackground: View {
    @EnvironmentObject var themeManager: WatchThemeManager

    /// Uses circadian palette - NO blue/teal after dusk for sleep health
    private var palette: WatchCircadianPalette { WatchCircadianPalette.current }

    var body: some View {
        ZStack {
            // Base gradient background - circadian-aware
            LinearGradient(
                colors: palette.background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated ribbons using circadian wave/accent colors
            CircadianRibbon(index: 0, color: palette.wave)
            CircadianRibbon(index: 1, color: palette.wave.opacity(0.7))
            CircadianRibbon(index: 2, color: palette.accent.opacity(0.5))
            CircadianRibbon(index: 3, color: palette.accent.opacity(0.3))
        }
        .ignoresSafeArea()
    }
}

// MARK: - Main Home View

struct WatchHomeView: View {
    @EnvironmentObject var themeManager: WatchThemeManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @ObservedObject private var convexService = WatchConvexService.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingSleepLog = false
    @State private var showingTreatmentTasks = false
    @State private var animateContent = false
    @State private var lastRefreshTime: Date = Date.distantPast

    // Countdown timer state
    @State private var countdownHours = 0
    @State private var countdownMinutes = 0
    @State private var countdownSeconds = 0
    @State private var isCountdownReady = false

    // Treatment tasks state
    @State private var treatmentTasks: [WatchTreatmentTask] = []
    @State private var pendingTasksCount = 0

    private var currentDay: Int { convexService.currentDay }
    private var motivation: (title: String, message: String) { DayMotivation.get(for: currentDay) }
    private var accentColor: Color { themeManager.accentColor }
    private var sleepLogCompleted: Bool { convexService.sleepLogCompleted }
    private var assessmentCompleted: Bool { convexService.assessmentCompleted }
    private var hasExpansionPackToday: Bool { convexService.hasExpansionPackToday }
    private var expansionPackCompleted: Bool { convexService.expansionPackCompleted }

    private var isDayComplete: Bool {
        // Base requirement: sleep log and assessment
        let baseDone = sleepLogCompleted && assessmentCompleted
        // If there's an expansion pack today, require that too
        if hasExpansionPackToday {
            return baseDone && expansionPackCompleted
        }
        return baseDone
    }

    /// Total tasks for today (1-3 based on what's available)
    private var totalTaskCount: Int {
        var count = 2 // Sleep Log + Assessment
        if hasExpansionPackToday { count += 1 }
        return count
    }

    /// Completed tasks for today
    private var completedTaskCount: Int {
        var count = 0
        if sleepLogCompleted { count += 1 }
        if assessmentCompleted { count += 1 }
        if hasExpansionPackToday && expansionPackCompleted { count += 1 }
        return count
    }

    private var journeyComplete: Bool { currentDay >= 15 && isDayComplete }

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background
                CircadianBackground()
                    .environmentObject(themeManager)

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Day indicator
                        dayHeader
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : -10)

                        // Today's Focus invitation card (hero-framed mission)
                        if currentDay <= 14 && !isDayComplete {
                            WatchTodaysFocusCard(
                                dayNumber: currentDay,
                                sleepLogDone: sleepLogCompleted,
                                assessmentDone: assessmentCompleted
                            )
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 10)
                        }

                        // Motivational message
                        motivationCard
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 15)

                        // Action buttons
                        actionButtons
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
            }
            .navigationDestination(isPresented: $showingSleepLog) {
                QuestionnaireView(mode: .sleepLog)
            }
            .navigationDestination(isPresented: $showingTreatmentTasks) {
                TreatmentTasksView()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
            // Refresh from Convex when view appears
            refreshFromConvex()
            updateCountdown()
            loadTreatmentTasks()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // Update countdown every second when day is complete
            if isDayComplete && currentDay < 15 {
                updateCountdown()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Refresh when app becomes active
            if newPhase == .active {
                refreshFromConvex()
                updateCountdown()
                loadTreatmentTasks()
            }
        }
        .onChange(of: showingSleepLog) { _, isShowing in
            // Refresh when returning from sleep log
            if !isShowing {
                refreshFromConvex()
            }
        }
        .onChange(of: showingTreatmentTasks) { _, isShowing in
            // Refresh tasks when returning
            if !isShowing {
                loadTreatmentTasks()
            }
        }
    }

    private func updateCountdown() {
        let countdown = CountdownTimer.timeUntil4AM()
        countdownHours = countdown.hours
        countdownMinutes = countdown.minutes
        countdownSeconds = countdown.seconds
        isCountdownReady = countdown.isReady
    }

    private func loadTreatmentTasks() {
        guard watchConnectivity.isConnected else {
            treatmentTasks = []
            pendingTasksCount = 0
            return
        }

        watchConnectivity.requestTreatmentTasks { tasks in
            DispatchQueue.main.async {
                self.treatmentTasks = tasks
                self.pendingTasksCount = tasks.filter { !$0.isCompleted }.count
            }
        }
    }

    private func refreshFromConvex() {
        // Avoid refreshing too frequently (min 2 seconds between refreshes)
        guard Date().timeIntervalSince(lastRefreshTime) > 2 else { return }
        lastRefreshTime = Date()

        Task {
            guard convexService.isAuthenticated else {
                print("[Watch Home] Not authenticated, skipping refresh")
                return
            }
            do {
                let _ = try await convexService.fetchJourneyState()
                print("[Watch Home] Refreshed: Day \(convexService.currentDay), sleepLog=\(convexService.sleepLogCompleted), assessment=\(convexService.assessmentCompleted)")
            } catch {
                print("[Watch Home] Refresh failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        let palette = WatchCircadianPalette.current

        return VStack(spacing: 4) {
            Text("DAY \(currentDay)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [palette.accent, palette.accent.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("of 14")
                .font(.caption)
                .foregroundColor(palette.textSecondary)

            // Progress dots
            HStack(spacing: 3) {
                ForEach(1...14, id: \.self) { day in
                    Circle()
                        .fill(day <= currentDay ? palette.accent : palette.textSecondary.opacity(0.3))
                        .frame(width: day == currentDay ? 6 : 4, height: day == currentDay ? 6 : 4)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Motivation Card

    private var motivationCard: some View {
        let palette = WatchCircadianPalette.current

        return VStack(spacing: 8) {
            Text(motivation.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(palette.accent)

            Text(motivation.message)
                .font(.system(size: 12))
                .foregroundColor(palette.textPrimary.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.isDark ? Color(red: 0.18, green: 0.12, blue: 0.10).opacity(0.5) : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(palette.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        let palette = WatchCircadianPalette.current
        // Use warm amber for incomplete states at night instead of blue/purple
        let incompleteColor = palette.isDark ? palette.wave.opacity(0.4) : Color.blue.opacity(0.3)
        let incompleteAssessmentColor = palette.isDark ? palette.accent.opacity(0.35) : Color.purple.opacity(0.3)

        return VStack(spacing: 10) {
            // Day Complete Celebration (if both tasks done)
            if isDayComplete {
                dayCompleteCelebration
            }

            // Sleep Log Button (the primary Watch action)
            Button {
                if !sleepLogCompleted {
                    showingSleepLog = true
                }
            } label: {
                HStack {
                    Image(systemName: sleepLogCompleted ? "checkmark.circle.fill" : "moon.stars.fill")
                        .font(.system(size: 18))
                        .foregroundColor(sleepLogCompleted ? .green : palette.textPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Log")
                            .font(.system(size: 14, weight: .semibold))
                        Text(sleepLogCompleted ? "Completed" : "Record last night")
                            .font(.system(size: 10))
                            .foregroundColor(sleepLogCompleted ? .green.opacity(0.8) : palette.textSecondary)
                    }

                    Spacer()

                    if !sleepLogCompleted {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(palette.textSecondary.opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(sleepLogCompleted ? Color.green.opacity(0.2) : incompleteColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(sleepLogCompleted ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .opacity(sleepLogCompleted ? 0.8 : 1.0)

            // Assessment - Display only (complete on iPhone)
            HStack {
                Image(systemName: assessmentCompleted ? "checkmark.circle.fill" : "iphone")
                    .font(.system(size: 18))
                    .foregroundColor(assessmentCompleted ? .green : palette.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Assessment")
                        .font(.system(size: 14, weight: .semibold))
                    Text(assessmentCompleted ? "Completed" : "Complete on iPhone")
                        .font(.system(size: 10))
                        .foregroundColor(assessmentCompleted ? .green.opacity(0.8) : palette.textSecondary)
                }

                Spacer()

                if !assessmentCompleted {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 12))
                        .foregroundColor(palette.textSecondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(assessmentCompleted ? Color.green.opacity(0.2) : incompleteAssessmentColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(assessmentCompleted ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
            .opacity(assessmentCompleted ? 0.8 : 1.0)

            // Expansion Pack (Deeper Dive) - Only shown if triggered, complete on iPhone
            if hasExpansionPackToday {
                let questionCount = convexService.expansionQuestionCount
                HStack {
                    Image(systemName: expansionPackCompleted ? "checkmark.circle.fill" : "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(expansionPackCompleted ? .green : .purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deeper Dive")
                            .font(.system(size: 14, weight: .semibold))
                        if expansionPackCompleted {
                            Text("Completed")
                                .font(.system(size: 10))
                                .foregroundColor(.green.opacity(0.8))
                        } else {
                            Text("\(questionCount > 0 ? "\(questionCount) questions • " : "")Complete on iPhone")
                                .font(.system(size: 10))
                                .foregroundColor(palette.textSecondary)
                        }
                    }

                    Spacer()

                    if !expansionPackCompleted {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                            .foregroundColor(palette.textSecondary.opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(expansionPackCompleted ? Color.green.opacity(0.2) : Color.purple.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(expansionPackCompleted ? Color.green.opacity(0.5) : Color.purple.opacity(0.4), lineWidth: 1)
                        )
                )
                .opacity(expansionPackCompleted ? 0.8 : 1.0)
            }

            // Treatment tasks (if any pending after journey starts)
            if pendingTasksCount > 0 && !isDayComplete {
                treatmentTasksCard
            }

            // Overdue expansion packs reminder (complete on iPhone)
            if convexService.overdueExpansionsCount > 0 {
                overdueExpansionsReminder
            }
        }
        .foregroundColor(palette.textPrimary)
    }

    // MARK: - Overdue Expansions Reminder

    private var overdueExpansionsReminder: some View {
        let palette = WatchCircadianPalette.current
        let count = convexService.overdueExpansionsCount

        return HStack {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 16))
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text("Overdue Deep Dives")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(palette.textPrimary)
                Text("\(count) pack\(count > 1 ? "s" : "") on iPhone")
                    .font(.system(size: 10))
                    .foregroundColor(palette.textSecondary)
            }

            Spacer()

            Image(systemName: "iphone.badge.exclamationmark")
                .font(.system(size: 14))
                .foregroundColor(.purple.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.purple.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Day Complete Celebration (Enhanced)

    private var dayCompleteCelebration: some View {
        VStack(spacing: 12) {
            // Success header
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                Text("Day \(currentDay) Complete!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
            }

            if journeyComplete {
                // Journey complete state
                journeyCompleteCard
            } else {
                // Live countdown to next day
                countdownCard

                // Journey progress visualization
                journeyProgressCard

                // Treatment tasks (if any pending)
                if pendingTasksCount > 0 {
                    treatmentTasksCard
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Countdown Card

    private var countdownCard: some View {
        let palette = WatchCircadianPalette.current

        return VStack(spacing: 6) {
            if themeManager.debugMode {
                // Debug mode: Show advance button immediately (bypasses time check only)
                Button {
                    advanceToNextDay()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                        Text("Advance to Day \(currentDay + 1)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(palette.isDark ? Color(red: 0.1, green: 0.08, blue: 0.06) : .white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(palette.accent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Text("Debug mode: Time check bypassed")
                    .font(.system(size: 9))
                    .foregroundColor(palette.textSecondary.opacity(0.7))
            } else if isCountdownReady {
                // Time unlocked - show advance button
                Button {
                    advanceToNextDay()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                        Text("Start Day \(currentDay + 1)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(palette.isDark ? Color(red: 0.1, green: 0.08, blue: 0.06) : .white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(palette.accent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                // Show countdown to 4 AM
                Text("Day \(currentDay + 1) unlocks in")
                    .font(.system(size: 10))
                    .foregroundColor(palette.textSecondary)

                HStack(spacing: 2) {
                    // Hours
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", countdownHours))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(palette.accent)
                        Text("hr")
                            .font(.system(size: 8))
                            .foregroundColor(palette.textSecondary.opacity(0.7))
                    }

                    Text(":")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(palette.textSecondary.opacity(0.5))

                    // Minutes
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", countdownMinutes))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(palette.accent)
                        Text("min")
                            .font(.system(size: 8))
                            .foregroundColor(palette.textSecondary.opacity(0.7))
                    }

                    Text(":")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(palette.textSecondary.opacity(0.5))

                    // Seconds
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", countdownSeconds))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(palette.accent)
                        Text("sec")
                            .font(.system(size: 8))
                            .foregroundColor(palette.textSecondary.opacity(0.7))
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.isDark ? Color(red: 0.18, green: 0.12, blue: 0.10).opacity(0.4) : Color.white.opacity(0.05))
        )
    }

    // MARK: - Advance Day Action

    private func advanceToNextDay() {
        Task {
            do {
                // Pass debugMode flag - only bypasses time check, NOT completion check
                let response = try await convexService.advanceDay(debugMode: themeManager.debugMode)

                if response.success {
                    print("[Watch] Advanced to Day \(response.newDay ?? currentDay)")
                    // State is already updated in WatchConvexService
                } else {
                    // Server rejected - sections not complete
                    print("[Watch] Cannot advance: \(response.error ?? "Unknown error")")
                    print("[Watch] Sleep Log: \(response.sleepLogCompleted ?? false), Assessment: \(response.assessmentCompleted ?? false)")
                }
            } catch {
                print("[Watch] Error advancing day: \(error)")
            }
        }
    }

    // MARK: - Journey Progress Card

    private var journeyProgressCard: some View {
        let palette = WatchCircadianPalette.current

        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12))
                    .foregroundColor(palette.accent)
                Text("Your 14-Day Journey")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.textPrimary.opacity(0.9))
                Spacer()
                Text("\(currentDay)/14")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(palette.accent)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(palette.textSecondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accent.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(currentDay) / 15, height: 8)
                        .animation(.spring(response: 0.4), value: currentDay)
                }
            }
            .frame(height: 8)

            // Day dots (compact)
            HStack(spacing: 2) {
                ForEach(1...15, id: \.self) { day in
                    Circle()
                        .fill(day <= currentDay ? palette.accent : palette.textSecondary.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }

            // Days remaining message
            let daysLeft = 14 - currentDay
            Text(daysLeft == 1 ? "1 day left!" : "\(daysLeft) days remaining")
                .font(.system(size: 9))
                .foregroundColor(palette.textSecondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.isDark ? Color(red: 0.18, green: 0.12, blue: 0.10).opacity(0.4) : Color.white.opacity(0.05))
        )
    }

    // MARK: - Treatment Tasks Card

    private var treatmentTasksCard: some View {
        Button {
            showingTreatmentTasks = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ZOE Tasks")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(pendingTasksCount) task\(pendingTasksCount == 1 ? "" : "s") pending")
                        .font(.system(size: 10))
                        .foregroundColor(.orange.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Journey Complete Card

    private var journeyCompleteCard: some View {
        let palette = WatchCircadianPalette.current
        // Use warm gold for trophy/celebration at night
        let celebrationColor = palette.isDark ? Color(red: 1.0, green: 0.80, blue: 0.30) : Color.yellow

        return VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundColor(celebrationColor)

            Text("Journey Complete!")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(celebrationColor)

            Text("Congratulations! You've completed your 10-day sleep intake.")
                .font(.system(size: 11))
                .foregroundColor(palette.textPrimary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if !treatmentTasks.isEmpty {
                Divider()
                    .background(palette.textSecondary.opacity(0.3))
                    .padding(.vertical, 4)

                Button {
                    showingTreatmentTasks = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(palette.accent)
                        Text("View Treatment Plan")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(palette.accent.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    WatchHomeView()
        .environmentObject(WatchThemeManager.shared)
        .environmentObject(WatchConnectivityManager())
}
