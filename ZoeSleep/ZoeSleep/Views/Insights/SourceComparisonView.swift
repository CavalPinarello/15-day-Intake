//
//  SourceComparisonView.swift
//  ZoeSleep
//
//  Multi-source wearable comparison view for Sleep Insights Dashboard.
//  Shows data from multiple devices (Apple Watch, Oura, Fitbit, etc.)
//  with comparison charts and quality indicators.
//

import SwiftUI
import Charts

// MARK: - Source Color Mapping

struct SourceColors {
    static let colors: [String: Color] = [
        "Apple Watch": .green,
        "Oura": .purple,
        "Oura Ring": .purple,
        "Fitbit": .teal,
        "Garmin": .blue,
        "WHOOP": .orange,
        "Questionnaire": .orange,
        "Sleep Log": .orange,
        "Unknown": .gray
    ]

    static func color(for source: String) -> Color {
        // Check for partial matches
        let upper = source.uppercased()
        if upper.contains("APPLE") || upper.contains("WATCH") {
            return .green
        }
        if upper.contains("OURA") {
            return .purple
        }
        if upper.contains("FITBIT") {
            return .teal
        }
        if upper.contains("GARMIN") {
            return .blue
        }
        if upper.contains("WHOOP") {
            return .orange
        }
        return colors[source] ?? .gray
    }

    static func icon(for source: String) -> String {
        let upper = source.uppercased()
        if upper.contains("WATCH") || upper.contains("FITBIT") || upper.contains("GARMIN") {
            return "applewatch"
        }
        if upper.contains("OURA") || upper.contains("WHOOP") {
            return "circle.dotted"
        }
        return "iphone"
    }
}

// MARK: - Data Quality Badge

struct DataQualityBadge: View {
    let score: Int
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var qualityLevel: (label: String, color: Color) {
        switch score {
        case 5: return ("Excellent", .green)
        case 4: return ("Good", .green)
        case 3: return ("Good", .yellow)
        case 2: return ("Fair", .orange)
        case 1: return ("Limited", .orange)
        default: return ("No Data", .gray)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption2)
            Text(qualityLevel.label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(qualityLevel.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(qualityLevel.color.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Source Badge

struct SourceBadge: View {
    let source: String
    let stats: MultiSourceSleepData.SourceStat?
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 8) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(SourceColors.color(for: source).opacity(0.2))
                    .frame(width: 28, height: 28)

                Image(systemName: SourceColors.icon(for: source))
                    .font(.system(size: 12))
                    .foregroundColor(SourceColors.color(for: source))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(source)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primaryText)

                if let stats = stats {
                    HStack(spacing: 4) {
                        Text("\(stats.dataPoints) days")
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText)

                        if let eff = stats.avgEfficiency {
                            Text("· \(Int(eff))%")
                                .font(.caption2)
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                }
            }

            // Capability badges
            if let stats = stats {
                Spacer()
                if stats.hasDeepSleep {
                    Text("Stages")
                        .font(.system(size: 9))
                        .foregroundColor(theme.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.success.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.secondaryText.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Multi-Source Comparison Chart

@available(iOS 16.0, *)
struct MultiSourceComparisonChart: View {
    let data: MultiSourceSleepData
    @State private var selectedMetric: MetricType = .efficiency
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    enum MetricType: String, CaseIterable {
        case efficiency = "Efficiency"
        case totalSleep = "Sleep Hours"
        case deepSleep = "Deep Sleep"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Metric picker
            Picker("Metric", selection: $selectedMetric) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            // Chart
            Chart {
                ForEach(data.comparisonData, id: \.date) { point in
                    ForEach(data.sources, id: \.self) { source in
                        if let sourceData = point.sources[source], let data = sourceData {
                            let value = getValue(for: selectedMetric, from: data)
                            if let val = value {
                                LineMark(
                                    x: .value("Date", formatDate(point.date)),
                                    y: .value(selectedMetric.rawValue, val)
                                )
                                .foregroundStyle(SourceColors.color(for: source))
                                .symbol {
                                    Circle()
                                        .fill(SourceColors.color(for: source))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 180)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(formatYValue(val))
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 16) {
                ForEach(data.sources, id: \.self) { source in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(SourceColors.color(for: source))
                            .frame(width: 8, height: 8)
                        Text(source)
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
        }
    }

    private func getValue(for metric: MetricType, from data: MultiSourceSleepData.ComparisonDataPoint.SourceDayData) -> Double? {
        switch metric {
        case .efficiency:
            return data.efficiency
        case .totalSleep:
            guard let mins = data.totalSleepMins else { return nil }
            return Double(mins) / 60.0
        case .deepSleep:
            guard let mins = data.deepMins else { return nil }
            return Double(mins)
        }
    }

    private var yDomain: ClosedRange<Double> {
        switch selectedMetric {
        case .efficiency: return 60...100
        case .totalSleep: return 4...10
        case .deepSleep: return 0...120
        }
    }

    private func formatYValue(_ value: Double) -> String {
        switch selectedMetric {
        case .efficiency: return "\(Int(value))%"
        case .totalSleep: return "\(String(format: "%.1f", value))h"
        case .deepSleep: return "\(Int(value))m"
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Source Comparison Summary

struct SourceComparisonSummary: View {
    let sourceStats: [MultiSourceSleepData.SourceStat]
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        if sourceStats.count >= 2 {
            let sorted = sourceStats
                .filter { $0.avgEfficiency != nil }
                .sorted { ($0.avgEfficiency ?? 0) > ($1.avgEfficiency ?? 0) }

            if sorted.count >= 2 {
                let best = sorted[0]
                let worst = sorted[sorted.count - 1]
                let diff = (best.avgEfficiency ?? 0) - (worst.avgEfficiency ?? 0)

                if diff < 5 {
                    // Consistent data
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Your wearables show consistent data with only \(String(format: "%.1f", diff))% variance.")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    // Significant difference
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("\(best.source) reports \(String(format: "%.1f", diff))% higher efficiency than \(worst.source).\(diff > 15 ? " Consider reviewing device placement." : "")")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Main Source Comparison View

struct SourceComparisonView: View {
    let viewModel: SleepInsightsViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(theme.primary)
                Text("Multi-Device Comparison")
                    .font(.headline)
                    .foregroundColor(theme.textOnCard)

                Spacer()

                if let data = viewModel.multiSourceData {
                    Text("\(data.sources.count) devices")
                        .font(.caption)
                        .foregroundColor(theme.textOnCardSecondary)
                }
            }

            // Source badges
            if let data = viewModel.multiSourceData {
                ForEach(data.sources, id: \.self) { source in
                    let stats = data.sourceStats.first { $0.source == source }
                    SourceBadge(source: source, stats: stats)
                }

                // Chart
                if #available(iOS 16.0, *) {
                    MultiSourceComparisonChart(data: data)
                        .padding(.top, 8)
                } else {
                    // Fallback for older iOS
                    Text("Charts require iOS 16+")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .padding()
                }

                // Summary
                SourceComparisonSummary(sourceStats: data.sourceStats)
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }
}

// MARK: - Data Source Card (Single Source Display)

struct DataSourceCard: View {
    let source: String?
    let qualityScore: Int
    let daysOfData: Int
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    /// Determines what type of data is being shown
    private var dataTypeLabel: String {
        guard let source = source else {
            return "Questionnaire data only"
        }
        let upper = source.uppercased()
        if upper.contains("WATCH") || upper.contains("OURA") || upper.contains("FITBIT") || upper.contains("GARMIN") || upper.contains("WHOOP") {
            return "Wearable + Questionnaire"
        }
        return "Questionnaire data"
    }

    /// Icon for no device state
    private var noDeviceMessage: String {
        "Sleep patterns derived from your daily sleep log questionnaire responses"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Device icon
                ZStack {
                    Circle()
                        .fill(sourceColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: sourceIcon)
                        .font(.title3)
                        .foregroundColor(sourceColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(source ?? "No Device")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.textOnCard)

                    Text("\(daysOfData) days of data")
                        .font(.caption)
                        .foregroundColor(theme.textOnCardSecondary)
                }

                Spacer()

                DataQualityBadge(score: qualityScore)
            }

            // Data source explanation
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: source == nil ? "info.circle" : "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(source == nil ? theme.warning : theme.success)

                Text(source == nil ? noDeviceMessage : dataTypeLabel)
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    private var sourceColor: Color {
        guard let source = source else { return .gray }
        return SourceColors.color(for: source)
    }

    private var sourceIcon: String {
        guard let source = source else { return "questionmark" }
        return SourceColors.icon(for: source)
    }
}

// MARK: - Previews

#if DEBUG
struct SourceComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                DataSourceCard(
                    source: "Apple Watch",
                    qualityScore: 5,
                    daysOfData: 10
                )

                DataSourceCard(
                    source: "Oura Ring",
                    qualityScore: 4,
                    daysOfData: 8
                )

                DataQualityBadge(score: 5)
                DataQualityBadge(score: 3)
                DataQualityBadge(score: 1)
            }
            .padding()
        }
        .background(Color.black)
        .environmentObject(ThemeManager.shared)
    }
}
#endif
