//
//  TrendChartView.swift
//  ZoeSleep
//
//  7-day rolling chart comparing subjective and objective sleep scores.
//  Uses Swift Charts with circadian-safe colors.
//

import SwiftUI
import Charts

struct TrendChartView: View {
    let comparisons: [DailyComparison]

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Trend")
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            chartView

            // Legend
            legendView
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.4))
        .cornerRadius(16)
    }

    // MARK: - Chart View

    private var chartView: some View {
        Chart {
            // Objective line (HealthKit data) - solid
            ForEach(comparisons) { point in
                LineMark(
                    x: .value("Date", shortDate(point.date)),
                    y: .value("Score", point.objectiveScore),
                    series: .value("Type", "Actual")
                )
                .foregroundStyle(theme.primary)
                .symbol(.circle)
                .interpolationMethod(.catmullRom)
            }

            // Subjective line (Sleep Log rating) - dashed
            ForEach(comparisons) { point in
                LineMark(
                    x: .value("Date", shortDate(point.date)),
                    y: .value("Score", point.subjectiveScore),
                    series: .value("Type", "Your Rating")
                )
                .foregroundStyle(theme.secondary)
                .lineStyle(StrokeStyle(dash: [5, 5]))
                .symbol(.square)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine()
                    .foregroundStyle(theme.textSecondary.opacity(0.2))
                AxisValueLabel()
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(height: 200)
    }

    // MARK: - Legend View

    private var legendView: some View {
        HStack(spacing: 20) {
            HStack(spacing: 4) {
                Circle()
                    .fill(theme.primary)
                    .frame(width: 8, height: 8)
                Text("Actual (HealthKit)")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }

            HStack(spacing: 4) {
                Rectangle()
                    .fill(theme.secondary)
                    .frame(width: 12, height: 2)
                Text("Your Rating")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    // MARK: - Helper Methods

    private func shortDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
struct TrendChartView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TrendChartView(comparisons: SleepInsightsViewModel.preview.dailyComparisons)
                .environmentObject(ThemeManager.shared)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
