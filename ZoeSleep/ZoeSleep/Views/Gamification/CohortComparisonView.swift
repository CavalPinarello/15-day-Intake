//
//  CohortComparisonView.swift
//  Zoe Sleep for Longevity System
//
//  Shows anonymous cohort comparisons for clinical scores
//  Example: "Your ISI score is better than 60% of similar users"
//

import SwiftUI

// MARK: - Score Percentile View

struct ScorePercentileView: View {
    let scoreType: String
    let scoreName: String
    let userScore: Int
    let percentile: Int?
    let interpretation: String
    let sampleSize: Int

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var accentColor: Color {
        guard let percentile = percentile else { return .gray }
        if percentile >= 70 { return .green }
        if percentile >= 40 { return .yellow }
        return .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scoreName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                    Text("Score: \(userScore)")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let percentile = percentile {
                    PercentileRing(percentile: percentile, color: accentColor)
                }
            }

            // Interpretation
            Text(interpretation)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780).opacity(0.8) : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Community comparison
            if let percentile = percentile {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(accentColor)

                    Text("Better than \(percentile)% of community members")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(accentColor)

                    Spacer()

                    Text("\(sampleSize)+ compared")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Percentile Ring

struct PercentileRing: View {
    let percentile: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: CGFloat(percentile) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(percentile)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text("%")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(color.opacity(0.8))
            }
        }
    }
}

// MARK: - Community Stats View

struct CommunityStatsView: View {
    let totalUsers: Int
    let activeThisMonth: Int
    let journeysCompleted: Int
    let averageStreak: Int

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)

                Text("Sleep Community")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Spacer()
            }

            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                CommunityStatCell(
                    icon: "person.fill",
                    value: formatNumber(totalUsers),
                    label: "Members",
                    color: .blue
                )

                CommunityStatCell(
                    icon: "bolt.fill",
                    value: formatNumber(activeThisMonth),
                    label: "Active this month",
                    color: .green
                )

                CommunityStatCell(
                    icon: "trophy.fill",
                    value: formatNumber(journeysCompleted),
                    label: "Journeys completed",
                    color: .yellow
                )

                CommunityStatCell(
                    icon: "flame.fill",
                    value: "\(averageStreak)",
                    label: "Avg streak days",
                    color: .orange
                )
            }

            // Motivation message
            Text("You're part of a community improving their sleep together")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return "\(num / 1000)K+"
        }
        return "\(num)+"
    }
}

struct CommunityStatCell: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)
            }

            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Gateway Insight View

struct GatewayInsightView: View {
    let gateway: String
    let prevalence: String
    let successRate: String
    let message: String
    let citation: String

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var gatewayIcon: String {
        switch gateway {
        case "insomnia": return "moon.zzz.fill"
        case "mental_health": return "brain.head.profile"
        case "sleep_apnea": return "lungs.fill"
        case "perimenopause": return "heart.fill"
        case "pain": return "bandage.fill"
        case "circadian": return "clock.fill"
        default: return "info.circle.fill"
        }
    }

    private var gatewayColor: Color {
        switch gateway {
        case "insomnia": return .purple
        case "mental_health": return .blue
        case "sleep_apnea": return .orange
        case "perimenopause": return .pink
        case "pain": return .red
        case "circadian": return .yellow
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: gatewayIcon)
                    .font(.system(size: 20))
                    .foregroundColor(gatewayColor)

                Text("You're Not Alone")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Spacer()
            }

            // Prevalence
            VStack(alignment: .leading, spacing: 4) {
                Text(prevalence)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)
            }

            // Success Rate
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                    .foregroundColor(.green)

                Text(successRate)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.green)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.1))
            )

            // Message
            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780).opacity(0.8) : .secondary)
                .italic()

            // Citation
            HStack {
                Spacer()
                Text("Source: \(citation)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Streak Comparison View

struct StreakComparisonView: View {
    let currentStreak: Int
    let percentile: Int?
    let message: String

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        HStack(spacing: 16) {
            // Flame icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
            }

            // Message
            VStack(alignment: .leading, spacing: 4) {
                Text("\(currentStreak)-day streak")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Text(message)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let percentile = percentile, percentile >= 75 {
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.yellow)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct CohortComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScorePercentileView(
                    scoreType: "ISI",
                    scoreName: "Insomnia Severity Index",
                    userScore: 15,
                    percentile: 65,
                    interpretation: "Moderate insomnia - you're in the right place for help.",
                    sampleSize: 1247
                )

                CommunityStatsView(
                    totalUsers: 12500,
                    activeThisMonth: 3200,
                    journeysCompleted: 1847,
                    averageStreak: 8
                )

                GatewayInsightView(
                    gateway: "perimenopause",
                    prevalence: "40-60% of women experience sleep changes during perimenopause",
                    successRate: "Targeted interventions can significantly improve sleep quality",
                    message: "Hormone fluctuations affect sleep. Your experience is valid and treatable.",
                    citation: "Menopause Review, 2020"
                )

                StreakComparisonView(
                    currentStreak: 8,
                    percentile: 78,
                    message: "Your 8-day streak is in the top 25%!"
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .environmentObject(ThemeManager.shared)
    }
}
#endif
