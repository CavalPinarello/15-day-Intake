//
//  DataRequirementView.swift
//  ZoeSleep
//
//  Displayed when insufficient data is available for insights.
//  Shows progress toward unlocking features and what's coming.
//

import SwiftUI

struct DataRequirementView: View {
    let currentDays: Int
    let requiredDays: Int

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    private var daysRemaining: Int {
        max(0, requiredDays - currentDays)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(theme.primary.opacity(0.5))

            // Title
            Text("Collecting Sleep Data")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)

            // Description
            Text("We need at least \(requiredDays) days of data to generate meaningful insights. You have \(currentDays) day\(currentDays == 1 ? "" : "s") so far.")
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            // Progress indicator
            VStack(spacing: 8) {
                ProgressView(value: Double(currentDays), total: Double(requiredDays))
                    .tint(theme.primary)

                Text("\(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") to go")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.top, 10)

            // What insights will be available
            upcomingInsightsSection
        }
        .padding(.top, 40)
    }

    // MARK: - Upcoming Insights Section

    private var upcomingInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coming Soon:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.textPrimary)

            UpcomingInsightRow(
                icon: "brain.head.profile",
                text: "Perception vs Reality comparison",
                daysRequired: 5,
                currentDays: currentDays
            )
            .environmentObject(themeManager)

            UpcomingInsightRow(
                icon: "calendar",
                text: "Workday vs Weekend patterns",
                daysRequired: 7,
                currentDays: currentDays
            )
            .environmentObject(themeManager)

            UpcomingInsightRow(
                icon: "clock",
                text: "Optimal bedtime analysis",
                daysRequired: 7,
                currentDays: currentDays
            )
            .environmentObject(themeManager)

            UpcomingInsightRow(
                icon: "lightbulb",
                text: "Personalized recommendations",
                daysRequired: 7,
                currentDays: currentDays
            )
            .environmentObject(themeManager)
        }
        .padding()
        .background(theme.backgroundTint)
        .cornerRadius(12)
    }
}

// MARK: - Upcoming Insight Row

struct UpcomingInsightRow: View {
    let icon: String
    let text: String
    let daysRequired: Int
    let currentDays: Int

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    private var isUnlocked: Bool { currentDays >= daysRequired }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isUnlocked ? "checkmark.circle.fill" : icon)
                .foregroundColor(isUnlocked ? theme.success : theme.textSecondary)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(isUnlocked ? theme.success : theme.textSecondary)

            Spacer()

            if !isUnlocked {
                Text("Day \(daysRequired)")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(theme.backgroundTint)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DataRequirementView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            DataRequirementView(currentDays: 3, requiredDays: 5)
                .environmentObject(ThemeManager.shared)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
