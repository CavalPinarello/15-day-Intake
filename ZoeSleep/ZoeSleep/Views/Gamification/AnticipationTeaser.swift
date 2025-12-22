//
//  AnticipationTeaser.swift
//  Zoe Sleep for Longevity System
//
//  Shows anticipation messages like "Tomorrow you'll unlock..."
//  Builds excitement for upcoming content
//

import SwiftUI

// MARK: - Tomorrow Teaser View

struct TomorrowTeaserView: View {
    let currentDay: Int
    let triggeredGateways: [String]

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var teaserContent: (icon: String, title: String, description: String)? {
        getTeaserForDay(currentDay + 1, triggeredGateways: triggeredGateways)
    }

    var body: some View {
        if let content = teaserContent {
            HStack(spacing: 16) {
                // Sparkle icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: content.icon)
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Coming Tomorrow")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.purple)
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(content.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                    Text(content.description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                isEvening ? Color(white: 0.12) : Color(.systemBackground),
                                isEvening ? Color(white: 0.08) : Color(.systemGray6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .purple.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }

    private func getTeaserForDay(_ day: Int, triggeredGateways: [String]) -> (icon: String, title: String, description: String)? {
        // Core journey teasers
        switch day {
        case 2:
            return ("moon.stars.fill", "Sleep Habits Deep Dive", "Discover how your daily routines affect your sleep")
        case 3:
            return ("bed.double.fill", "Bedroom Environment", "Learn what makes the perfect sleep sanctuary")
        case 4:
            return ("brain.head.profile", "Mind & Sleep Connection", "Explore how thoughts affect your rest")
        case 5:
            return ("chart.bar.fill", "First Insights Unlock!", "See your personalized sleep patterns")
        case 6:
            return ("waveform.path.ecg", "Sleep Quality Analysis", "Understand what affects your sleep quality")
        case 7:
            return ("sparkles", "Week 1 Complete!", "Celebrate and review your progress")
        case 8:
            if !triggeredGateways.isEmpty {
                return ("microscope", "Personalized Deep Dive", "Explore topics tailored to your needs")
            }
            return ("arrow.triangle.branch", "New Path Ahead", "Your journey continues based on your responses")
        case 9...14:
            if !triggeredGateways.isEmpty {
                return ("star.fill", "Continued Exploration", "More personalized insights await")
            }
            return nil
        case 15:
            return ("trophy.fill", "Journey Finale!", "Complete your assessment and unlock your full report")
        default:
            return nil
        }
    }
}

// MARK: - Unlock Progress Teaser

struct UnlockProgressTeaser: View {
    let currentDay: Int
    let totalDays: Int = Config.totalJourneyDays

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var daysUntilNextMilestone: Int {
        if currentDay < 5 { return 5 - currentDay }
        if currentDay < 7 { return 7 - currentDay }
        if currentDay < Config.totalJourneyDays { return Config.totalJourneyDays - currentDay }
        return 0
    }

    private var nextMilestone: String {
        if currentDay < 5 { return "first insights" }
        if currentDay < 7 { return "Week 1 Complete badge" }
        if currentDay <= Config.totalJourneyDays { return "your full sleep profile" }
        return "completion"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(currentDay) / CGFloat(totalDays), height: 12)

                    // Milestone markers
                    ForEach([5, 7, 15], id: \.self) { milestone in
                        Circle()
                            .fill(currentDay >= milestone ? Color.purple : Color.gray.opacity(0.4))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .position(
                                x: geometry.size.width * CGFloat(milestone) / CGFloat(totalDays),
                                y: 6
                            )
                    }
                }
            }
            .frame(height: 16)

            // Teaser text
            HStack {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.purple)

                Text("\(daysUntilNextMilestone) \(daysUntilNextMilestone == 1 ? "day" : "days") until you unlock \(nextMilestone)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780).opacity(0.8) : .secondary)

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
        )
    }
}

// MARK: - Insight Unlock Countdown

struct InsightUnlockCountdown: View {
    let daysUntilUnlock: Int
    let insightType: String

    @State private var pulse = false

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        HStack(spacing: 14) {
            // Lock icon with pulse
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .scaleEffect(pulse ? 1.1 : 1.0)

                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(insightType) Insights")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Text("Unlocks in \(daysUntilUnlock) \(daysUntilUnlock == 1 ? "day" : "days")")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.blue)

                Text("Keep logging to reveal your patterns")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Gateway Unlock Teaser

struct GatewayUnlockTeaser: View {
    let gatewayName: String
    let gatewayIcon: String

    @State private var shimmer = false

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        HStack(spacing: 14) {
            // Gateway icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Text(gatewayIcon)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("NEW DEEP DIVE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                        .tracking(1)

                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                }

                Text("\(gatewayName) Exploration Unlocked")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Text("Personalized questions based on your responses")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.purple)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.1), .pink.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.4), .pink.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct AnticipationTeaser_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                TomorrowTeaserView(currentDay: 4, triggeredGateways: [])

                UnlockProgressTeaser(currentDay: 4)

                InsightUnlockCountdown(daysUntilUnlock: 1, insightType: "Sleep Pattern")

                GatewayUnlockTeaser(gatewayName: "Insomnia", gatewayIcon: "🌙")
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .environmentObject(ThemeManager.shared)
    }
}
#endif
