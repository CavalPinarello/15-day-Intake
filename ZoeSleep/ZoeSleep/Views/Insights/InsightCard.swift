//
//  InsightCard.swift
//  ZoeSleep
//
//  Displays an individual actionable insight with icon, title, and description.
//  Styled based on insight type (optimization, pattern, cognitive, warning).
//

import SwiftUI

struct InsightCard: View {
    let insight: SleepInsight

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon based on insight type
            Image(systemName: iconForType(insight.type))
                .font(.title2)
                .foregroundColor(colorForType(insight.type))
                .frame(width: 40, height: 40)
                .background(colorForType(insight.type).opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 6) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Text(insight.text)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Confidence indicator
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                    Text("\(Int(insight.confidence * 100))% confidence")
                        .font(.caption2)
                }
                .foregroundColor(theme.textSecondary.opacity(0.7))
            }

            Spacer()

            if insight.actionable {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.35))
        .cornerRadius(12)
    }

    // MARK: - Helper Methods

    private func iconForType(_ type: String) -> String {
        switch type {
        case "optimization":
            return "slider.horizontal.3"
        case "pattern":
            return "waveform.path.ecg"
        case "cognitive":
            return "brain.head.profile"
        case "positive":
            return "checkmark.circle"
        case "warning":
            return "exclamationmark.triangle"
        default:
            return "lightbulb"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "optimization":
            return theme.primary
        case "pattern":
            return theme.success
        case "cognitive":
            return theme.warning
        case "positive":
            return theme.success
        case "warning":
            return theme.error
        default:
            return theme.primary
        }
    }
}

// MARK: - Preview

#if DEBUG
struct InsightCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            InsightCard(insight: SleepInsight(
                id: "bedtime_latency",
                type: "optimization",
                title: "Optimal Bedtime Found",
                text: "You fall asleep 18 minutes faster when going to bed before 10:30 PM.",
                confidence: 0.85,
                actionable: true
            ))
            .environmentObject(ThemeManager.shared)

            InsightCard(insight: SleepInsight(
                id: "weekend_deep_sleep",
                type: "pattern",
                title: "Weekend Sleep Pattern",
                text: "Your deep sleep is 22% better on weekends. Consider stress management during the week.",
                confidence: 0.78,
                actionable: true
            ))
            .environmentObject(ThemeManager.shared)

            InsightCard(insight: SleepInsight(
                id: "perception_gap",
                type: "cognitive",
                title: "Sleep Perception Gap",
                text: "You tend to rate your sleep lower than your objective metrics suggest. Your sleep may be better than you think!",
                confidence: 0.82,
                actionable: true
            ))
            .environmentObject(ThemeManager.shared)

            InsightCard(insight: SleepInsight(
                id: "efficiency_declining",
                type: "warning",
                title: "Sleep Efficiency Declining",
                text: "Your sleep efficiency has decreased by 8% recently. Consider reviewing your sleep environment.",
                confidence: 0.80,
                actionable: true
            ))
            .environmentObject(ThemeManager.shared)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
