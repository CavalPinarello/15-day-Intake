//
//  ChallengesView.swift
//  Zoe Sleep for Longevity System
//
//  Daily and weekly challenges UI
//  Provides micro-goals to boost engagement
//

import SwiftUI

// MARK: - Challenge Data Models

struct DailyChallenge: Identifiable {
    let id: String
    let name: String
    let description: String
    let xpReward: Int
    let icon: String
    let isCompleted: Bool
    let category: ChallengeCategory
}

struct WeeklyChallenge: Identifiable {
    let id: String
    let name: String
    let description: String
    let xpReward: Int
    let icon: String
    let isCompleted: Bool
    let progress: Int
    let progressTarget: Int
    let category: ChallengeCategory
}

enum ChallengeCategory: String, CaseIterable {
    case timing = "Timing"
    case consistency = "Consistency"
    case engagement = "Engagement"
    case quality = "Quality"

    var color: Color {
        switch self {
        case .timing: return .orange
        case .consistency: return .blue
        case .engagement: return .purple
        case .quality: return .green
        }
    }

    var icon: String {
        switch self {
        case .timing: return "clock.fill"
        case .consistency: return "checkmark.circle.fill"
        case .engagement: return "star.fill"
        case .quality: return "heart.fill"
        }
    }
}

// MARK: - Challenges Dashboard

struct ChallengesDashboardView: View {
    @State private var selectedTab: ChallengeTab = .daily
    @State private var dailyChallenges: [DailyChallenge] = []
    @State private var weeklyChallenges: [WeeklyChallenge] = []

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    enum ChallengeTab: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Challenges")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                    Text("Complete challenges to earn XP")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // XP badge
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                    Text("+\(totalAvailableXP) XP")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.15))
                )
            }

            // Tab selector
            HStack(spacing: 0) {
                ForEach(ChallengeTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular, design: .rounded))
                                .foregroundColor(selectedTab == tab ? .white : .secondary)

                            // Completion indicator
                            Text(tab == .daily ? "\(completedDaily)/\(dailyChallenges.count)" : "\(completedWeekly)/\(weeklyChallenges.count)")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(selectedTab == tab ? .white.opacity(0.8) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedTab == tab ? Color.blue : Color.clear)
                        )
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEvening ? Color(white: 0.15) : Color(.systemGray6))
            )

            // Challenges list
            ScrollView {
                LazyVStack(spacing: 12) {
                    if selectedTab == .daily {
                        ForEach(dailyChallenges) { challenge in
                            DailyChallengeCard(challenge: challenge)
                        }
                    } else {
                        ForEach(weeklyChallenges) { challenge in
                            WeeklyChallengeCard(challenge: challenge)
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            loadChallenges()
        }
    }

    private var totalAvailableXP: Int {
        let dailyXP = dailyChallenges.filter { !$0.isCompleted }.reduce(0) { $0 + $1.xpReward }
        let weeklyXP = weeklyChallenges.filter { !$0.isCompleted }.reduce(0) { $0 + $1.xpReward }
        return dailyXP + weeklyXP
    }

    private var completedDaily: Int {
        dailyChallenges.filter { $0.isCompleted }.count
    }

    private var completedWeekly: Int {
        weeklyChallenges.filter { $0.isCompleted }.count
    }

    private func loadChallenges() {
        // TODO: Load from Convex
        // For now, use sample data
        dailyChallenges = [
            DailyChallenge(id: "morning_logger", name: "Morning Logger", description: "Complete your sleep log before 9 AM", xpReward: 30, icon: "sunrise", isCompleted: false, category: .timing),
            DailyChallenge(id: "early_assessment", name: "Early Bird Assessment", description: "Complete today's assessment before noon", xpReward: 25, icon: "sun.max", isCompleted: false, category: .timing),
            DailyChallenge(id: "reflective_logger", name: "Reflective Logger", description: "Add a note to your sleep log today", xpReward: 20, icon: "pencil", isCompleted: true, category: .engagement),
            DailyChallenge(id: "insight_explorer", name: "Insight Explorer", description: "View at least one insight today", xpReward: 15, icon: "lightbulb", isCompleted: false, category: .engagement),
            DailyChallenge(id: "perfect_day", name: "Perfect Day", description: "Complete both sleep log and assessment today", xpReward: 50, icon: "star.fill", isCompleted: false, category: .consistency),
        ]

        weeklyChallenges = [
            WeeklyChallenge(id: "week_warrior", name: "Week Warrior", description: "Complete all 14 tasks this week", xpReward: 200, icon: "trophy", isCompleted: false, progress: 6, progressTarget: 14, category: .consistency),
            WeeklyChallenge(id: "consistent_sleeper", name: "Consistent Sleeper", description: "Log bedtime within 30 min of average for 5 days", xpReward: 150, icon: "clock", isCompleted: false, progress: 3, progressTarget: 5, category: .quality),
            WeeklyChallenge(id: "morning_champion", name: "Morning Champion", description: "Complete sleep log before 9 AM for 5 days", xpReward: 100, icon: "sunrise", isCompleted: false, progress: 2, progressTarget: 5, category: .timing),
            WeeklyChallenge(id: "streak_builder", name: "Streak Builder", description: "Don't break your streak this week", xpReward: 100, icon: "flame", isCompleted: false, progress: 4, progressTarget: 7, category: .consistency),
        ]
    }
}

// MARK: - Daily Challenge Card

struct DailyChallengeCard: View {
    let challenge: DailyChallenge

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(challenge.isCompleted ? Color.green.opacity(0.2) : challenge.category.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                if challenge.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: challenge.icon)
                        .font(.system(size: 18))
                        .foregroundColor(challenge.category.color)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)
                    .strikethrough(challenge.isCompleted)

                Text(challenge.description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // XP Reward
            if !challenge.isCompleted {
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("+\(challenge.xpReward)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.15))
                )
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .opacity(challenge.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Weekly Challenge Card

struct WeeklyChallengeCard: View {
    let challenge: WeeklyChallenge

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var progressPercent: CGFloat {
        CGFloat(challenge.progress) / CGFloat(challenge.progressTarget)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(challenge.isCompleted ? Color.green.opacity(0.2) : challenge.category.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    if challenge.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: challenge.icon)
                            .font(.system(size: 18))
                            .foregroundColor(challenge.category.color)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)
                        .strikethrough(challenge.isCompleted)

                    Text(challenge.description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // XP Reward
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("+\(challenge.xpReward)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(challenge.isCompleted ? .green : .yellow)

                    Text("\(challenge.progress)/\(challenge.progressTarget)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            challenge.isCompleted
                                ? AnyShapeStyle(Color.green)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [challenge.category.color, challenge.category.color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                        .frame(width: geometry.size.width * progressPercent, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .opacity(challenge.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Compact Challenges Summary (for Dashboard)

struct ChallengesSummaryCard: View {
    let dailyCompleted: Int
    let dailyTotal: Int
    let weeklyCompleted: Int
    let weeklyTotal: Int
    let nextXP: Int

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today's Challenges")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Spacer()

                Text("\(dailyCompleted)/\(dailyTotal)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.blue)
            }

            // Progress
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(dailyCompleted) / CGFloat(max(dailyTotal, 1)), height: 8)
                }
            }
            .frame(height: 8)

            // Next XP teaser
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)

                Text("Complete next challenge for +\(nextXP) XP")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChallengesDashboardView()
                .background(Color(.systemGroupedBackground))
        }
        .environmentObject(ThemeManager.shared)
    }
}
#endif
