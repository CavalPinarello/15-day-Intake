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
    static func timeUntil5AM() -> (hours: Int, minutes: Int, seconds: Int, isReady: Bool) {
        let now = Date()
        let calendar = Calendar.current

        // Get today at 5 AM
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 5
        components.minute = 0
        components.second = 0

        guard let todayAt5AM = calendar.date(from: components) else {
            return (0, 0, 0, true)
        }

        let targetDate: Date
        if now >= todayAt5AM {
            // Already past 5 AM today, target is tomorrow at 5 AM
            targetDate = calendar.date(byAdding: .day, value: 1, to: todayAt5AM) ?? todayAt5AM
        } else {
            targetDate = todayAt5AM
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

// MARK: - Animated Background

struct CircadianBackground: View {
    @EnvironmentObject var themeManager: WatchThemeManager

    private var accentColor: Color { themeManager.accentColor }

    var body: some View {
        ZStack {
            // Deep gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.15),
                    Color(red: 0.08, green: 0.12, blue: 0.22),
                    Color(red: 0.05, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated ribbons
            CircadianRibbon(index: 0, color: accentColor)
            CircadianRibbon(index: 1, color: accentColor.opacity(0.7))
            CircadianRibbon(index: 2, color: Color.teal.opacity(0.5))
            CircadianRibbon(index: 3, color: Color.cyan.opacity(0.3))
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
    @State private var showingAssessment = false
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
    private var isDayComplete: Bool { sleepLogCompleted && assessmentCompleted }
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

                        // Motivational message
                        motivationCard
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 10)

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
            .navigationDestination(isPresented: $showingAssessment) {
                QuestionnaireView(mode: .assessment)
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
        .onChange(of: showingAssessment) { _, isShowing in
            // Refresh when returning from assessment
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
        let countdown = CountdownTimer.timeUntil5AM()
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
        VStack(spacing: 4) {
            Text("DAY \(currentDay)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("of 15")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            // Progress dots
            HStack(spacing: 3) {
                ForEach(1...15, id: \.self) { day in
                    Circle()
                        .fill(day <= currentDay ? accentColor : Color.white.opacity(0.2))
                        .frame(width: day == currentDay ? 6 : 4, height: day == currentDay ? 6 : 4)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Motivation Card

    private var motivationCard: some View {
        VStack(spacing: 8) {
            Text(motivation.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)

            Text(motivation.message)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Day Complete Celebration (if both tasks done)
            if isDayComplete {
                dayCompleteCelebration
            }

            // Sleep Log Button
            Button {
                if !sleepLogCompleted {
                    showingSleepLog = true
                }
            } label: {
                HStack {
                    Image(systemName: sleepLogCompleted ? "checkmark.circle.fill" : "moon.stars.fill")
                        .font(.system(size: 18))
                        .foregroundColor(sleepLogCompleted ? .green : .white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Log")
                            .font(.system(size: 14, weight: .semibold))
                        Text(sleepLogCompleted ? "Completed" : "Record last night")
                            .font(.system(size: 10))
                            .foregroundColor(sleepLogCompleted ? .green.opacity(0.8) : .white.opacity(0.7))
                    }

                    Spacer()

                    if !sleepLogCompleted {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(sleepLogCompleted ? Color.green.opacity(0.2) : Color.blue.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(sleepLogCompleted ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .opacity(sleepLogCompleted ? 0.8 : 1.0)

            // Assessment Button
            Button {
                if !assessmentCompleted {
                    showingAssessment = true
                }
            } label: {
                HStack {
                    Image(systemName: assessmentCompleted ? "checkmark.circle.fill" : "list.clipboard.fill")
                        .font(.system(size: 18))
                        .foregroundColor(assessmentCompleted ? .green : .white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Assessment")
                            .font(.system(size: 14, weight: .semibold))
                        Text(assessmentCompleted ? "Completed" : "Day \(currentDay) questions")
                            .font(.system(size: 10))
                            .foregroundColor(assessmentCompleted ? .green.opacity(0.8) : .white.opacity(0.7))
                    }

                    Spacer()

                    if !assessmentCompleted {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(assessmentCompleted ? Color.green.opacity(0.2) : Color.purple.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(assessmentCompleted ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .opacity(assessmentCompleted ? 0.8 : 1.0)
        }
        .foregroundColor(.white)
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
        VStack(spacing: 6) {
            Text("Day \(currentDay + 1) unlocks in")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))

            if isCountdownReady {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Ready now!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
            } else {
                HStack(spacing: 2) {
                    // Hours
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", countdownHours))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor)
                        Text("hr")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Text(":")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))

                    // Minutes
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", countdownMinutes))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor)
                        Text("min")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Text(":")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))

                    // Seconds
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", countdownSeconds))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor)
                        Text("sec")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Journey Progress Card

    private var journeyProgressCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                Text("Your 15-Day Journey")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text("\(currentDay)/15")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accentColor)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
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
                        .fill(day <= currentDay ? accentColor : Color.white.opacity(0.2))
                        .frame(width: 5, height: 5)
                }
            }

            // Days remaining message
            let daysLeft = 15 - currentDay
            Text(daysLeft == 1 ? "1 day left!" : "\(daysLeft) days remaining")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
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
        VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundColor(.yellow)

            Text("Journey Complete!")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.yellow)

            Text("Congratulations! You've completed your 15-day sleep intake.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if !treatmentTasks.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.vertical, 4)

                Button {
                    showingTreatmentTasks = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(accentColor)
                        Text("View Treatment Plan")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(accentColor.opacity(0.2))
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
