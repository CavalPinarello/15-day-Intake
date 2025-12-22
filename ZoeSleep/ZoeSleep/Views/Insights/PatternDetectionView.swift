//
//  PatternDetectionView.swift
//  ZoeSleep
//
//  Displays detected sleep patterns: workday vs weekend, optimal bedtime, sleep stages.
//  Only shown when 7+ days of data are available.
//

import SwiftUI

struct PatternDetectionView: View {
    let workdayVsWeekend: WorkdayWeekendPattern?
    let optimalBedtime: OptimalBedtime?
    let sleepStagePatterns: SleepStagePatterns?

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    // MARK: - Circadian-Aware Colors
    private var palette: CircadianPalette {
        CircadianPalette.forPeriod(themeManager.currentTimePeriod)
    }

    private var circadianTextPrimary: Color {
        palette.textPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Patterns")
                .font(.headline)
                .foregroundColor(circadianTextPrimary)

            if let pattern = workdayVsWeekend {
                workdayWeekendCard(pattern)
            }

            if let bedtime = optimalBedtime {
                optimalBedtimeCard(bedtime)
            }

            if let stages = sleepStagePatterns {
                sleepStagesCard(stages)
            }

            if workdayVsWeekend == nil && optimalBedtime == nil && sleepStagePatterns == nil {
                noPatternView
            }
        }
    }

    // MARK: - Workday vs Weekend Card

    private func workdayWeekendCard(_ pattern: WorkdayWeekendPattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(theme.primary)
                Text("Workday vs Weekend")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textOnCard)

                Spacer()

                // Data source indicator
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                    Text("Sleep Log")
                        .font(.caption2)
                }
                .foregroundColor(theme.textOnCardMuted)
            }

            HStack(spacing: 12) {
                // Workday
                VStack(spacing: 4) {
                    Text("Workday")
                        .font(.caption2)
                        .foregroundColor(theme.textOnCardSecondary)

                    Text(formatDuration(Int(pattern.workdayAvgSleep)))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textOnCard)

                    Text("\(Int(pattern.workdayAvgEfficiency))% eff")
                        .font(.caption2)
                        .foregroundColor(theme.textOnCardSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(theme.primary.opacity(0.10))
                .cornerRadius(8)

                // Comparison arrow
                VStack {
                    if pattern.sleepDifference > 0 {
                        Image(systemName: "arrow.right")
                            .foregroundColor(theme.success)
                        Text("+\(formatDuration(Int(pattern.sleepDifference)))")
                            .font(.caption2)
                            .foregroundColor(theme.success)
                    } else if pattern.sleepDifference < 0 {
                        Image(systemName: "arrow.right")
                            .foregroundColor(theme.warning)
                        Text(formatDuration(Int(pattern.sleepDifference)))
                            .font(.caption2)
                            .foregroundColor(theme.warning)
                    }
                }

                // Weekend
                VStack(spacing: 4) {
                    Text("Weekend")
                        .font(.caption2)
                        .foregroundColor(theme.textOnCardSecondary)

                    Text(formatDuration(Int(pattern.weekendAvgSleep)))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textOnCard)

                    Text("\(Int(pattern.weekendAvgEfficiency))% eff")
                        .font(.caption2)
                        .foregroundColor(theme.textOnCardSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(theme.primary.opacity(0.10))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(12)
    }

    // MARK: - Optimal Bedtime Card

    private func optimalBedtimeCard(_ bedtime: OptimalBedtime) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.title2)
                .foregroundColor(theme.primary)
                .frame(width: 40, height: 40)
                .background(theme.primary.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text("Optimal Bedtime")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textOnCard)

                Text("Around \(bedtime.time)")
                    .font(.callout)
                    .foregroundColor(theme.primary)

                Text("You fall asleep \(Int(bedtime.latencyDiff)) min faster")
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)
            }

            Spacer()

            // Confidence indicator
            VStack {
                Text("\(Int(bedtime.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(theme.success)
                Text("confidence")
                    .font(.caption2)
                    .foregroundColor(theme.textOnCardSecondary)
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(12)
    }

    // MARK: - Sleep Stages Card

    private func sleepStagesCard(_ stages: SleepStagePatterns) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundColor(theme.primary)
                Text("Sleep Stages")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textOnCard)

                Spacer()

                // Data source indicator - stages REQUIRE wearable data
                HStack(spacing: 4) {
                    Image(systemName: "applewatch")
                        .font(.caption2)
                    Text("Wearable")
                        .font(.caption2)
                }
                .foregroundColor(theme.success)
            }

            HStack(spacing: 8) {
                // Deep Sleep
                stageBar(
                    label: "Deep",
                    percent: stages.avgDeepPercent,
                    color: theme.primary,
                    belowRecommended: stages.deepBelowRecommended
                )

                // REM Sleep
                stageBar(
                    label: "REM",
                    percent: stages.avgRemPercent,
                    color: theme.secondary,
                    belowRecommended: stages.remBelowRecommended
                )

                // Light Sleep
                stageBar(
                    label: "Light",
                    percent: stages.avgLightPercent,
                    color: theme.textOnCardSecondary,
                    belowRecommended: false
                )
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(12)
    }

    private func stageBar(label: String, percent: Double, color: Color, belowRecommended: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(theme.textOnCardSecondary)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .frame(height: 60)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(height: CGFloat(percent) / 100 * 60)
            }

            HStack(spacing: 2) {
                Text("\(Int(percent))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(belowRecommended ? theme.warning : theme.textOnCard)

                if belowRecommended {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundColor(theme.warning)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - No Pattern View

    private var noPatternView: some View {
        Text("Patterns will appear as more data is collected")
            .font(.subheadline)
            .foregroundColor(theme.textOnCardSecondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(GlassyCardBackground(opacity: 0.5))
            .cornerRadius(12)
    }

    // MARK: - Helper Methods

    private func formatDuration(_ minutes: Int) -> String {
        let hours = abs(minutes) / 60
        let mins = abs(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Preview

#if DEBUG
struct PatternDetectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PatternDetectionView(
                workdayVsWeekend: WorkdayWeekendPattern(
                    workdayAvgSleep: 390,
                    weekendAvgSleep: 450,
                    workdayAvgDeep: 50,
                    weekendAvgDeep: 65,
                    workdayAvgEfficiency: 78,
                    weekendAvgEfficiency: 85,
                    sleepDifference: 60,
                    deepDifference: 15
                ),
                optimalBedtime: OptimalBedtime(
                    time: "10:30 PM",
                    avgLatencyMinutes: 8,
                    latencyDiff: 18,
                    confidence: 0.85
                ),
                sleepStagePatterns: SleepStagePatterns(
                    avgDeepPercent: 15,
                    avgRemPercent: 22,
                    avgLightPercent: 55,
                    deepBelowRecommended: false,
                    remBelowRecommended: false
                )
            )
            .environmentObject(ThemeManager.shared)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
