//
//  PerceptionVsRealityCard.swift
//  ZoeSleep
//
//  Compares subjective sleep quality rating with objective HealthKit metrics.
//  Shows the gap between perception and reality with interpretation.
//

import SwiftUI

struct PerceptionVsRealityCard: View {
    @ObservedObject var viewModel: SleepInsightsViewModel

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(theme.primary)

                Text("Perception vs Reality")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                // Info button
                Button {
                    // TODO: Show explanation sheet
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(theme.textSecondary)
                }
            }

            // Last night comparison
            if let subjective = viewModel.lastNightSubjective,
               let objective = viewModel.lastNightObjective {
                comparisonView(subjective: subjective, objective: objective)
            } else {
                noDataView
            }

            // Correlation over time (if available)
            if let correlation = viewModel.correlation {
                Divider()
                correlationView(correlation: correlation)
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.4))
        .cornerRadius(16)
    }

    // MARK: - Comparison View

    private func comparisonView(subjective: SubjectiveSleepData, objective: ObjectiveSleepData) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Subjective (Your Rating)
                VStack(spacing: 4) {
                    Text("Your Rating")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)

                    Text("\(Int(subjective.quality))/10")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(theme.secondary)

                    Text("Last night")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                // Gap indicator
                VStack(spacing: 4) {
                    Image(systemName: viewModel.gapIndicatorIcon)
                        .font(.title2)
                        .foregroundColor(gapIndicatorColor)

                    Text(viewModel.gapIndicatorLabel)
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                }

                // Objective (Actual Data)
                VStack(spacing: 4) {
                    Text("Actual Sleep")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)

                    Text(viewModel.lastNightDurationFormatted)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primary)

                    Text("\(viewModel.lastNightEfficiencyFormatted) efficient")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)

            // Interpretation text
            Text(viewModel.interpretationText)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .padding(12)
                .background(theme.backgroundTint)
                .cornerRadius(8)
        }
    }

    // MARK: - No Data View

    private var noDataView: some View {
        Text("Complete your sleep log to see the comparison")
            .font(.subheadline)
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding()
    }

    // MARK: - Correlation View

    private func correlationView(correlation: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Perception Accuracy")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)

                Text(viewModel.correlationDescription)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary)
            }

            Spacer()

            // Correlation gauge
            CorrelationGauge(value: correlation)
                .environmentObject(themeManager)
        }
    }

    // MARK: - Computed Properties

    private var gapIndicatorColor: Color {
        guard let subjective = viewModel.lastNightSubjective,
              let objective = viewModel.lastNightObjective else {
            return theme.textSecondary
        }

        let normalizedSubjective = subjective.quality * 10
        let objectiveScore = normalizeObjectiveScore(objective)
        let gap = normalizedSubjective - objectiveScore

        if abs(gap) <= 15 { return theme.success }
        return theme.warning
    }

    private func normalizeObjectiveScore(_ objective: ObjectiveSleepData) -> Double {
        let durationScore = min(100, (Double(objective.totalSleepMins) / 420.0) * 100)
        return (objective.efficiency * 0.6) + (durationScore * 0.4)
    }
}

// MARK: - Correlation Gauge

struct CorrelationGauge: View {
    let value: Double  // 0 to 1

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, value)))
                .stroke(gaugeColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))

            Text("\(Int(value * 100))%")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
        }
    }

    private var gaugeColor: Color {
        if value >= 0.7 { return theme.success }
        if value >= 0.4 { return theme.warning }
        return theme.error
    }
}

// MARK: - Preview

#if DEBUG
struct PerceptionVsRealityCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PerceptionVsRealityCard(viewModel: .preview)
                .environmentObject(ThemeManager.shared)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
