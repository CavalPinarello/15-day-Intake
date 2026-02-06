//
//  HRVRecoveryView.swift
//  Zoe Sleep for Longevity System
//
//  Displays HRV Charge score and recovery curve visualization
//

import SwiftUI
import Charts

struct HRVRecoveryView: View {
    @ObservedObject var viewModel: SleepDataViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // HRV Charge Gauge
                if let charge = viewModel.todayHRVCharge {
                    HRVChargeGaugeCard(charge: charge, theme: theme)
                }

                // Recovery Curve Chart
                if !viewModel.currentNightHRVSamples.isEmpty {
                    HRVRecoveryCurveCard(
                        samples: viewModel.currentNightHRVSamples,
                        summary: viewModel.todayHRVSummary,
                        theme: theme
                    )
                } else if let summary = viewModel.todayHRVSummary, summary.hasMinimumData {
                    // Show simplified view without curve
                    HRVSummaryCard(summary: summary, theme: theme)
                } else {
                    NoHRVDataCard(theme: theme)
                }

                // 7-Day HRV Trend
                if !viewModel.hrvChargeHistory.isEmpty {
                    HRVTrendCard(charges: viewModel.hrvChargeHistory, theme: theme)
                }

                // Baseline Info
                if let baseline = viewModel.hrvBaseline {
                    HRVBaselineCard(baseline: baseline, theme: theme)
                }
            }
            .padding()
        }
        .navigationTitle("HRV Recovery")
        .navigationBarTitleDisplayMode(.large)
        .background(theme.cardBackground.opacity(0.3))
    }
}

// MARK: - HRV Charge Gauge Card

struct HRVChargeGaugeCard: View {
    let charge: HRVChargeResult
    let theme: ColorTheme

    var body: some View {
        VStack(spacing: 16) {
            Text("HRV Charge")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            // Gauge
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.0, to: 0.75)
                    .stroke(theme.cardBackground, lineWidth: 20)
                    .rotationEffect(.degrees(135))

                // Value arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(charge.chargeScore) / 100.0 * 0.75)
                    .stroke(
                        charge.recoveryTrajectory.color(theme: theme),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))

                // Score
                VStack(spacing: 4) {
                    Text("\(charge.chargeScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(charge.recoveryTrajectory.color(theme: theme))

                    Text(charge.recoveryTrajectory.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(charge.recoveryTrajectory.color(theme: theme))
                }
            }
            .frame(width: 180, height: 180)

            // Confidence indicator
            HStack {
                Image(systemName: confidenceIcon)
                    .foregroundColor(theme.textSecondary)
                Text("Confidence: \(Int(charge.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }

            // Baseline type
            Text(baselineLabel)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }

    private var confidenceIcon: String {
        if charge.confidence >= 0.8 { return "checkmark.circle.fill" }
        if charge.confidence >= 0.5 { return "circle.lefthalf.filled" }
        return "exclamationmark.circle"
    }

    private var baselineLabel: String {
        switch charge.baselineType {
        case .personal:
            return "Based on your personal baseline"
        case .population:
            return "Based on population norms (building your baseline)"
        }
    }
}

// MARK: - Recovery Curve Card

struct HRVRecoveryCurveCard: View {
    let samples: [HRVSample]
    let summary: HRVNightlySummary?
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Curve")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            // Chart
            Chart {
                // Evening baseline reference line
                if let eveningAvg = summary?.eveningAvg {
                    RuleMark(y: .value("Evening", eveningAvg))
                        .lineStyle(StrokeStyle(dash: [5, 5]))
                        .foregroundStyle(theme.secondary.opacity(0.5))
                        .annotation(position: .leading, alignment: .leading) {
                            Text("Evening")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                }

                // HRV line
                ForEach(samples) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("HRV", sample.value)
                    )
                    .foregroundStyle(lineColor(for: sample))
                    .interpolationMethod(.catmullRom)
                }

                // Points
                ForEach(samples) { sample in
                    PointMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("HRV", sample.value)
                    )
                    .foregroundStyle(lineColor(for: sample))
                    .symbolSize(sample.value == peakValue ? 60 : 20)
                }

                // Peak annotation
                if let peakSample = peakSample {
                    PointMark(
                        x: .value("Time", peakSample.timestamp),
                        y: .value("HRV", peakSample.value)
                    )
                    .foregroundStyle(theme.success)
                    .symbolSize(80)
                    .annotation(position: .top) {
                        Text("Peak")
                            .font(.caption2)
                            .foregroundColor(theme.success)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 200)

            // Legend
            HStack(spacing: 16) {
                HRVLegendItem(color: theme.primary, label: "During Sleep")
                HRVLegendItem(color: theme.secondary, label: "Evening", dashed: true)
                if peakSample != nil {
                    HRVLegendItem(color: theme.success, label: "Peak")
                }
            }
            .font(.caption)
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }

    private func lineColor(for sample: HRVSample) -> Color {
        switch sample.sampleType {
        case .evening:
            return theme.secondary
        case .intraNight:
            return theme.primary
        case .morning:
            return theme.accent
        }
    }

    private var peakValue: Double? {
        samples.map { $0.value }.max()
    }

    private var peakSample: HRVSample? {
        samples.max(by: { $0.value < $1.value })
    }
}

// MARK: - Legend Item

struct HRVLegendItem: View {
    let color: Color
    let label: String
    var dashed: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if dashed {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(color)
                            .frame(width: 4, height: 2)
                    }
                }
                .frame(width: 16)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }

            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - HRV Summary Card

struct HRVSummaryCard: View {
    let summary: HRVNightlySummary
    let theme: ColorTheme

    var body: some View {
        VStack(spacing: 16) {
            Text("HRV Summary")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            // Metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                HRVMetricBox(
                    label: "Evening",
                    value: summary.eveningAvg.map { String(format: "%.0f ms", $0) } ?? "—",
                    icon: "sun.horizon",
                    theme: theme
                )

                HRVMetricBox(
                    label: "Peak",
                    value: summary.intraNightPeak.map { String(format: "%.0f ms", $0) } ?? "—",
                    icon: "arrow.up.circle",
                    theme: theme
                )

                HRVMetricBox(
                    label: "Morning",
                    value: summary.morningAvg.map { String(format: "%.0f ms", $0) } ?? "—",
                    icon: "sunrise",
                    theme: theme
                )

                HRVMetricBox(
                    label: "Recovery",
                    value: summary.recoveryRatio.map { String(format: "+%.0f%%", ($0 - 1) * 100) } ?? "—",
                    icon: "heart.text.square",
                    theme: theme
                )
            }

            // Data quality note
            if summary.intraNightSampleCount < 3 {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Limited intra-night data - recovery curve unavailable")
                }
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

// MARK: - Metric Box

struct HRVMetricBox: View {
    let label: String
    let value: String
    let icon: String
    let theme: ColorTheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(theme.accent)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryText)

            Text(label)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(theme.cardBackground.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - HRV Trend Card

struct HRVTrendCard: View {
    let charges: [HRVChargeResult]
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day HRV Charge")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            // Mini bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(charges.reversed().prefix(7)) { charge in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(charge.recoveryTrajectory.color(theme: theme))
                            .frame(width: 30, height: CGFloat(charge.chargeScore) * 0.8)

                        // Day label
                        Text(dayLabel(for: charge.date))
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)

            // Average
            if let avgCharge = averageCharge {
                HStack {
                    Text("Average:")
                        .foregroundColor(theme.textSecondary)
                    Text("\(avgCharge)")
                        .fontWeight(.semibold)
                        .foregroundColor(theme.primaryText)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }

    private func dayLabel(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return dayFormatter.string(from: date)
    }

    private var averageCharge: Int? {
        guard !charges.isEmpty else { return nil }
        let sum = charges.map { $0.chargeScore }.reduce(0, +)
        return sum / charges.count
    }
}

// MARK: - HRV Baseline Card

struct HRVBaselineCard: View {
    let baseline: PersonalHRVBaseline
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your HRV Baseline")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)

                Spacer()

                if baseline.isPersonalized {
                    Label("Personalized", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(theme.success)
                } else {
                    Label("Building...", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(theme.warning)
                }
            }

            // Baseline metrics
            VStack(spacing: 8) {
                HRVBaselineRow(
                    label: "Avg Evening HRV",
                    value: String(format: "%.0f ms", baseline.avgEveningHRV),
                    theme: theme
                )
                HRVBaselineRow(
                    label: "Avg Morning HRV",
                    value: String(format: "%.0f ms", baseline.avgMorningHRV),
                    theme: theme
                )
                HRVBaselineRow(
                    label: "Avg Recovery Ratio",
                    value: String(format: "%.0f%%", (baseline.avgRecoveryRatio - 1) * 100),
                    theme: theme
                )
                HRVBaselineRow(
                    label: "Days in Baseline",
                    value: "\(baseline.daysInBaseline) nights",
                    theme: theme
                )
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

struct HRVBaselineRow: View {
    let label: String
    let value: String
    let theme: ColorTheme

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)
        }
        .font(.subheadline)
    }
}

// MARK: - No HRV Data Card

struct NoHRVDataCard: View {
    let theme: ColorTheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundColor(theme.textSecondary)

            Text("No HRV Data Available")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            Text("HRV data requires a compatible wearable like Apple Watch Series 4+ or Oura Ring.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack {
        HRVRecoveryView(viewModel: SleepDataViewModel())
            .environmentObject(ThemeManager.shared)
    }
}
