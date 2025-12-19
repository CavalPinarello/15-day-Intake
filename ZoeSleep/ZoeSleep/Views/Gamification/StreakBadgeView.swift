//
//  StreakBadgeView.swift
//  Zoe Sleep for Longevity System
//
//  Displays the user's current streak with fire icon animation
//

import SwiftUI

struct StreakBadgeView: View {
    let currentStreak: Int
    let isAtRisk: Bool

    @State private var isAnimating = false
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 4) {
            // Fire icon with animation
            Image(systemName: fireIconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(fireColor)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // Streak count
            Text("\(currentStreak)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(textColor)

            // "day" label (optional, for larger displays)
            if currentStreak > 0 {
                Text(currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(backgroundColor)
                .overlay(
                    Capsule()
                        .strokeBorder(borderColor, lineWidth: 1)
                )
        )
        .onAppear {
            // Animate fire for active streaks
            if currentStreak > 0 {
                isAnimating = true
            }
        }
    }

    private var fireIconName: String {
        if currentStreak >= 30 {
            return "flame.fill"
        } else if currentStreak >= 7 {
            return "flame.fill"
        } else if currentStreak > 0 {
            return "flame"
        } else {
            return "flame"
        }
    }

    private var fireColor: Color {
        if isAtRisk {
            return .orange
        } else if currentStreak >= 30 {
            return .red
        } else if currentStreak >= 7 {
            return .orange
        } else if currentStreak > 0 {
            return .yellow
        } else {
            return theme.textSecondary.opacity(0.5)
        }
    }

    private var textColor: Color {
        if currentStreak > 0 {
            return theme.textPrimary
        } else {
            return theme.textSecondary
        }
    }

    private var backgroundColor: Color {
        if isAtRisk {
            return Color.orange.opacity(0.15)
        } else if currentStreak >= 7 {
            return Color.orange.opacity(0.1)
        } else if currentStreak > 0 {
            return Color.yellow.opacity(0.1)
        } else {
            return theme.textSecondary.opacity(0.08)
        }
    }

    private var borderColor: Color {
        if isAtRisk {
            return Color.orange.opacity(0.3)
        } else if currentStreak > 0 {
            return Color.orange.opacity(0.2)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Expanded Streak Card (for dashboard)

struct StreakCardView: View {
    let currentStreak: Int
    let longestStreak: Int
    let totalDaysCompleted: Int
    let isAtRisk: Bool
    let hasFreezeAvailable: Bool
    let onUseFreeze: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Header with streak counter
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Streak")
                        .font(.system(size: Typography.subheadline, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textSecondary)

                    HStack(spacing: 8) {
                        StreakBadgeView(currentStreak: currentStreak, isAtRisk: isAtRisk)
                            .environmentObject(themeManager)

                        if isAtRisk && hasFreezeAvailable {
                            Button(action: onUseFreeze) {
                                HStack(spacing: 4) {
                                    Image(systemName: "snowflake")
                                        .font(.caption)
                                    Text("Freeze")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }

                Spacer()

                // Best streak
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Personal Best")
                        .font(.system(size: Typography.caption, design: .rounded))
                        .foregroundColor(theme.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("\(longestStreak)")
                            .font(.system(size: Typography.headline, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }

            // Streak at risk warning
            if isAtRisk {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Complete today's tasks to keep your streak!")
                        .font(.system(size: Typography.caption, design: .rounded))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(CornerRadius.medium)
            }

            // Stats row
            HStack {
                StatItem(label: "Total Days", value: "\(totalDaysCompleted)", icon: "calendar.badge.checkmark")
                Spacer()
                StatItem(label: "This Week", value: "\(min(currentStreak, 7))/7", icon: "chart.bar.fill")
            }
        }
        .padding(Spacing.lg)
        .background(
            GlassyCardBackground(opacity: 0.6)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        )
    }
}

private struct StatItem: View {
    let label: String
    let value: String
    let icon: String

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(theme.primary)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: Typography.subheadline, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Text(label)
                    .font(.system(size: Typography.caption2, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct StreakBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StreakBadgeView(currentStreak: 0, isAtRisk: false)
            StreakBadgeView(currentStreak: 3, isAtRisk: false)
            StreakBadgeView(currentStreak: 7, isAtRisk: false)
            StreakBadgeView(currentStreak: 7, isAtRisk: true)
            StreakBadgeView(currentStreak: 30, isAtRisk: false)
        }
        .padding()
        .background(Color.black)
        .environmentObject(ThemeManager.shared)
    }
}
#endif
