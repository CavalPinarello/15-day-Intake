//
//  ProgressiveInsightsView.swift
//  Zoe Sleep for Longevity System
//
//  Shows progressive insight unlocking UI
//  Insights unlock based on days completed and data collected
//

import SwiftUI

// MARK: - Insight Unlock Status

struct InsightUnlockStatus: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let unlockDay: Int
    let isUnlocked: Bool
    let category: InsightCategory

    enum InsightCategory: String, CaseIterable {
        case pattern = "Pattern"
        case comparison = "Comparison"
        case recommendation = "Recommendation"
        case advanced = "Advanced"

        var color: Color {
            switch self {
            case .pattern: return .blue
            case .comparison: return .purple
            case .recommendation: return .green
            case .advanced: return .orange
            }
        }
    }
}

// MARK: - Progressive Insights View

struct ProgressiveInsightsView: View {
    let currentDay: Int
    @State private var selectedInsight: InsightUnlockStatus?
    @State private var animatedProgress: Double = 0

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var insights: [InsightUnlockStatus] {
        [
            // Day 1-4: Basic data collection
            InsightUnlockStatus(
                title: "Sleep Duration Pattern",
                description: "Understand your average sleep duration",
                icon: "clock.fill",
                unlockDay: 5,
                isUnlocked: currentDay >= 5,
                category: .pattern
            ),
            InsightUnlockStatus(
                title: "Sleep Timing Consistency",
                description: "See how consistent your bedtime is",
                icon: "calendar.badge.clock",
                unlockDay: 5,
                isUnlocked: currentDay >= 5,
                category: .pattern
            ),

            // Day 5-7: First insights
            InsightUnlockStatus(
                title: "Sleep Quality Trends",
                description: "Track how your sleep quality changes over time",
                icon: "chart.line.uptrend.xyaxis",
                unlockDay: 7,
                isUnlocked: currentDay >= 7,
                category: .pattern
            ),
            InsightUnlockStatus(
                title: "Community Comparison",
                description: "See how you compare to others with similar profiles",
                icon: "person.2.fill",
                unlockDay: 7,
                isUnlocked: currentDay >= 7,
                category: .comparison
            ),

            // Day 8-10: Deeper insights
            InsightUnlockStatus(
                title: "Perception Gap Analysis",
                description: "Compare how you feel vs. objective sleep data",
                icon: "eye.fill",
                unlockDay: 8,
                isUnlocked: currentDay >= 8,
                category: .pattern
            ),
            InsightUnlockStatus(
                title: "Weekday vs Weekend Patterns",
                description: "Discover differences in your sleep schedule",
                icon: "calendar",
                unlockDay: 10,
                isUnlocked: currentDay >= 10,
                category: .pattern
            ),

            // Day 11-14: Advanced insights
            InsightUnlockStatus(
                title: "Optimal Bedtime",
                description: "Find your ideal sleep window for best quality",
                icon: "bed.double.fill",
                unlockDay: 12,
                isUnlocked: currentDay >= 12,
                category: .recommendation
            ),
            InsightUnlockStatus(
                title: "Sleep Phenotype",
                description: "Understand your unique sleep pattern type",
                icon: "brain.head.profile",
                unlockDay: 14,
                isUnlocked: currentDay >= 14,
                category: .advanced
            ),

            // Day 15: Complete profile
            InsightUnlockStatus(
                title: "Full Sleep Profile",
                description: "Your complete personalized sleep analysis",
                icon: "doc.richtext.fill",
                unlockDay: 15,
                isUnlocked: currentDay >= 15,
                category: .advanced
            ),
            InsightUnlockStatus(
                title: "Intervention Recommendations",
                description: "Personalized suggestions for better sleep",
                icon: "lightbulb.fill",
                unlockDay: 15,
                isUnlocked: currentDay >= 15,
                category: .recommendation
            ),
        ]
    }

    private var unlockedCount: Int {
        insights.filter { $0.isUnlocked }.count
    }

    private var nextUnlock: InsightUnlockStatus? {
        insights.first { !$0.isUnlocked }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header with progress
            headerSection

            // Next unlock teaser
            if let next = nextUnlock {
                nextUnlockCard(next)
            }

            // Insights grid
            insightsGrid

            Spacer()
        }
        .padding()
        .background(
            isEvening
                ? Color(red: 0.05, green: 0.05, blue: 0.08)
                : Color(.systemGroupedBackground)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = Double(unlockedCount) / Double(insights.count)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Insights")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                    Text("\(unlockedCount) of \(insights.count) unlocked")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(animatedProgress * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
        )
    }

    // MARK: - Next Unlock Card

    private func nextUnlockCard(_ insight: InsightUnlockStatus) -> some View {
        HStack(spacing: 16) {
            // Locked icon with pulse
            ZStack {
                Circle()
                    .fill(insight.category.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(insight.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Next Unlock")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(insight.category.color)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(insight.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Text("Unlocks on Day \(insight.unlockDay)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Days remaining
            VStack {
                Text("\(insight.unlockDay - currentDay)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(insight.category.color)
                Text("days")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [insight.category.color.opacity(0.1), insight.category.color.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(insight.category.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Insights Grid

    private var insightsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(insights) { insight in
                InsightUnlockCard(
                    insight: insight,
                    currentDay: currentDay
                )
                .onTapGesture {
                    if insight.isUnlocked {
                        selectedInsight = insight
                    }
                }
            }
        }
    }
}

// MARK: - Insight Unlock Card

struct InsightUnlockCard: View {
    let insight: InsightUnlockStatus
    let currentDay: Int

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(insight.isUnlocked ? insight.category.color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)

                if insight.isUnlocked {
                    Image(systemName: insight.icon)
                        .font(.system(size: 20))
                        .foregroundColor(insight.category.color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }

            // Title
            Text(insight.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(
                    insight.isUnlocked
                        ? (isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)
                        : .gray
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Status
            if insight.isUnlocked {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Unlocked")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.green)
                }
            } else {
                Text("Day \(insight.unlockDay)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    insight.isUnlocked ? insight.category.color.opacity(0.3) : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
        .opacity(insight.isUnlocked ? 1.0 : 0.6)
    }
}

// MARK: - Compact Progress Card (for Dashboard)

struct InsightProgressCard: View {
    let currentDay: Int
    let unlockedCount: Int
    let totalCount: Int

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        HStack(spacing: 16) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: CGFloat(unlockedCount) / CGFloat(totalCount))
                    .stroke(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text("\(unlockedCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Insights Unlocked")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Text("\(unlockedCount) of \(totalCount) available")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
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
struct ProgressiveInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressiveInsightsView(currentDay: 7)
            .environmentObject(ThemeManager.shared)
    }
}
#endif
