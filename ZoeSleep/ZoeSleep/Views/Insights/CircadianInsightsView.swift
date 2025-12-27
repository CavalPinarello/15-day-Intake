//
//  CircadianInsightsView.swift
//  ZoeSleep
//
//  Displays circadian rhythm insights including light exposure,
//  outdoor activity, and temperature patterns.
//  Progressive reveal: Requires 3+ days for basic insights,
//  7+ days for patterns and recommendations.
//

import SwiftUI
import Charts

// MARK: - Circadian Insights View

struct CircadianInsightsView: View {
    @StateObject private var viewModel = CircadianInsightsViewModel()
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }
    private var palette: CircadianPalette { themeManager.circadianPalette }

    var body: some View {
        ZStack {
            DashboardWaveBackground()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    if viewModel.isLoading {
                        loadingView
                    } else if !viewModel.hasEnoughData {
                        dataRequirementView
                    } else {
                        insightsContent
                    }
                }
                .padding(.vertical)
            }
        }
        .toolbarColorScheme(palette.isDark ? .dark : .light, for: .navigationBar)
        .refreshable {
            await viewModel.refreshData()
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Circadian Insights")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(palette.textPrimary)

            if viewModel.daysOfData > 0 {
                Text("\(viewModel.daysOfData) days of data")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.yellow)
            Text("Loading circadian data...")
                .font(.subheadline)
                .foregroundColor(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Data Requirement View

    private var dataRequirementView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.daysOfData) / 3.0)
                    .stroke(Color.yellow, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.yellow)

                    Text("\(viewModel.daysOfData)/3")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(palette.textPrimary)

                    Text("days")
                        .font(.caption)
                        .foregroundColor(palette.textSecondary)
                }
            }

            VStack(spacing: 8) {
                Text("Building Your Circadian Profile")
                    .font(.headline)
                    .foregroundColor(palette.textPrimary)

                Text("We need at least 3 days of light exposure data to generate insights. Keep wearing your Apple Watch outdoors!")
                    .font(.subheadline)
                    .foregroundColor(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Tips while waiting
            VStack(alignment: .leading, spacing: 12) {
                tipRow(
                    icon: "sunrise.fill",
                    title: "Morning Light",
                    description: "Get 20-30 minutes of bright light within an hour of waking"
                )
                tipRow(
                    icon: "figure.walk",
                    title: "Outdoor Activity",
                    description: "Take walks outside to boost your light exposure"
                )
                tipRow(
                    icon: "moon.stars.fill",
                    title: "Evening Dimming",
                    description: "Reduce bright light 2 hours before bedtime"
                )
            }
            .padding()
            .background(GlassyCardBackground(opacity: 0.5))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }

    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textOnCard)
                Text(description)
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)
            }
        }
    }

    // MARK: - Insights Content

    private var insightsContent: some View {
        VStack(spacing: 20) {
            // Today's Status Card
            todayStatusCard

            // Circadian Score Card
            if let score = viewModel.circadianScore {
                circadianScoreCard(score: score)
            }

            // 7-Day Light Exposure Chart
            if !viewModel.dailyData.isEmpty {
                lightExposureChart
            }

            // Morning vs Afternoon Distribution
            if viewModel.hasTimeOfDayData {
                timeDistributionCard
            }

            // Temperature Pattern (Series 8+)
            if viewModel.hasTemperatureData {
                temperatureCard
            }

            // Outdoor Activity Card
            if viewModel.hasOutdoorData {
                outdoorActivityCard
            }

            // Recommendations
            if !viewModel.recommendations.isEmpty {
                recommendationsSection
            }

            Spacer(minLength: 20)
        }
    }

    // MARK: - Today's Status Card

    private var todayStatusCard: some View {
        HStack(spacing: 16) {
            // Light exposure
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 6)
                        .frame(width: 50, height: 50)

                    Circle()
                        .trim(from: 0, to: viewModel.todayProgressPercent)
                        .stroke(viewModel.todayProgressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                }

                Text("\(viewModel.todayLightMins) min")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textOnCard)

                Text("of 90 min")
                    .font(.caption2)
                    .foregroundColor(theme.textOnCardSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 60)

            // Morning light
            VStack(spacing: 4) {
                Image(systemName: "sunrise.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                Text("\(viewModel.todayMorningMins) min")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textOnCard)

                Text("before noon")
                    .font(.caption2)
                    .foregroundColor(theme.textOnCardSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 60)

            // Status
            VStack(spacing: 4) {
                Image(systemName: viewModel.todayNeedsMoreLight ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.todayNeedsMoreLight ? .orange : .green)

                Text(viewModel.todayNeedsMoreLight ? "Go outside!" : "On track")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textOnCard)

                Text("today")
                    .font(.caption2)
                    .foregroundColor(theme.textOnCardSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Circadian Score Card

    private func circadianScoreCard(score: Int) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Circadian Score")
                    .font(.headline)
                    .foregroundColor(theme.textOnCard)
                Spacer()
                if let trend = viewModel.scoreTrend {
                    HStack(spacing: 4) {
                        Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text(trend > 0 ? "+\(trend)" : "\(trend)")
                            .font(.caption)
                    }
                    .foregroundColor(trend >= 0 ? .green : .red)
                }
            }

            HStack(spacing: 24) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(
                            scoreColor(score),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(score)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(theme.textOnCard)
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(theme.textOnCardSecondary)
                    }
                }

                // Score breakdown
                VStack(alignment: .leading, spacing: 8) {
                    if let breakdown = viewModel.scoreBreakdown {
                        breakdownRow("Light Exposure", value: breakdown.light, max: 60)
                        breakdownRow("Morning Bonus", value: breakdown.morning, max: 10)
                        breakdownRow("Temperature", value: breakdown.temperature, max: 15)
                        breakdownRow("Outdoor Activity", value: breakdown.outdoor, max: 15)
                    }
                }
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func breakdownRow(_ label: String, value: Int, max: Int) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.textOnCardSecondary)
            Spacer()
            Text("\(value)/\(max)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(theme.textOnCard)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }

    // MARK: - Light Exposure Chart

    private var lightExposureChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Light Exposure (7 Days)")
                .font(.headline)
                .foregroundColor(theme.textOnCard)

            Chart {
                // 90-min target line
                RuleMark(y: .value("Target", 90))
                    .foregroundStyle(.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                ForEach(viewModel.dailyData) { day in
                    BarMark(
                        x: .value("Day", day.dayLabel),
                        y: .value("Minutes", day.daylightMins)
                    )
                    .foregroundStyle(barColor(for: day.daylightMins))
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 30, 60, 90, 120]) { value in
                    AxisValueLabel {
                        if let mins = value.as(Int.self) {
                            Text("\(mins)")
                                .font(.caption2)
                                .foregroundColor(theme.textOnCardSecondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                                .foregroundColor(theme.textOnCardSecondary)
                        }
                    }
                }
            }
            .frame(height: 180)

            // Legend
            HStack(spacing: 16) {
                legendItem(color: .green, label: "Target met (90+ min)")
                legendItem(color: .yellow, label: "Partial (60-90)")
                legendItem(color: .orange, label: "Low (<60)")
            }
            .font(.caption2)
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func barColor(for mins: Int) -> Color {
        if mins >= 90 { return .green }
        if mins >= 60 { return .yellow }
        return .orange
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(theme.textOnCardSecondary)
        }
    }

    // MARK: - Time Distribution Card

    private var timeDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Morning vs Afternoon Light")
                .font(.headline)
                .foregroundColor(theme.textOnCard)

            HStack(spacing: 20) {
                // Morning
                VStack(spacing: 8) {
                    Image(systemName: "sunrise.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("\(viewModel.avgMorningMins) min")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textOnCard)

                    Text("Before noon")
                        .font(.caption)
                        .foregroundColor(theme.textOnCardSecondary)

                    Text("(+10 pts bonus)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)

                // Afternoon
                VStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)

                    Text("\(viewModel.avgAfternoonMins) min")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textOnCard)

                    Text("After noon")
                        .font(.caption)
                        .foregroundColor(theme.textOnCardSecondary)

                    Text(" ")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }

            if viewModel.morningLightRatio < 0.3 {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    Text("Tip: Morning light is more effective for circadian entrainment. Try to get outside earlier!")
                        .font(.caption)
                        .foregroundColor(theme.textOnCardSecondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Temperature Card

    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Wrist Temperature")
                    .font(.headline)
                    .foregroundColor(theme.textOnCard)

                Spacer()

                Text("Series 8+ only")
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)
            }

            if let avgDeviation = viewModel.avgTempDeviation {
                HStack(spacing: 20) {
                    // Deviation indicator
                    VStack {
                        Image(systemName: "thermometer.medium")
                            .font(.largeTitle)
                            .foregroundColor(tempColor(avgDeviation))

                        Text(String(format: "%+.2f\u{00B0}C", avgDeviation))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textOnCard)

                        Text("Avg deviation")
                            .font(.caption)
                            .foregroundColor(theme.textOnCardSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Trend
                    VStack {
                        Image(systemName: viewModel.tempTrend == "rising" ? "arrow.up.circle.fill" :
                                        viewModel.tempTrend == "falling" ? "arrow.down.circle.fill" : "equal.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)

                        Text(viewModel.tempTrend?.capitalized ?? "Stable")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textOnCard)

                        Text("Trend")
                            .font(.caption)
                            .foregroundColor(theme.textOnCardSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("Small, stable temperature deviations indicate good circadian rhythm regularity.")
                .font(.caption)
                .foregroundColor(theme.textOnCardSecondary)
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func tempColor(_ deviation: Double) -> Color {
        if abs(deviation) < 0.2 { return .green }
        if abs(deviation) < 0.5 { return .yellow }
        return .orange
    }

    // MARK: - Outdoor Activity Card

    private var outdoorActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Outdoor Workouts")
                .font(.headline)
                .foregroundColor(theme.textOnCard)

            HStack(spacing: 20) {
                // Total minutes
                VStack {
                    Image(systemName: "figure.walk")
                        .font(.largeTitle)
                        .foregroundColor(.green)

                    Text("\(viewModel.weeklyOutdoorMins) min")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textOnCard)

                    Text("This week")
                        .font(.caption)
                        .foregroundColor(theme.textOnCardSecondary)
                }
                .frame(maxWidth: .infinity)

                // Workout count
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)

                    Text("\(viewModel.weeklyOutdoorCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textOnCard)

                    Text("workouts")
                        .font(.caption)
                        .foregroundColor(theme.textOnCardSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
                .foregroundColor(palette.textPrimary)
                .padding(.horizontal)

            ForEach(viewModel.recommendations, id: \.self) { recommendation in
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)

                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundColor(theme.textOnCard)

                    Spacer()
                }
                .padding()
                .background(GlassyCardBackground(opacity: 0.3))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - View Model

@MainActor
class CircadianInsightsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var daysOfData = 0
    @Published var dailyData: [CircadianDayData] = []
    @Published var circadianScore: Int?
    @Published var scoreTrend: Int?
    @Published var scoreBreakdown: ScoreBreakdown?

    @Published var todayLightMins = 0
    @Published var todayMorningMins = 0
    @Published var todayNeedsMoreLight = true

    @Published var avgMorningMins = 0
    @Published var avgAfternoonMins = 0
    @Published var morningLightRatio: Double = 0

    @Published var avgTempDeviation: Double?
    @Published var tempTrend: String?

    @Published var weeklyOutdoorMins = 0
    @Published var weeklyOutdoorCount = 0

    @Published var recommendations: [String] = []

    var hasEnoughData: Bool { daysOfData >= 3 }
    var hasTimeOfDayData: Bool { avgMorningMins > 0 || avgAfternoonMins > 0 }
    var hasTemperatureData: Bool { avgTempDeviation != nil }
    var hasOutdoorData: Bool { weeklyOutdoorMins > 0 || weeklyOutdoorCount > 0 }

    var todayProgressPercent: Double {
        min(1.0, Double(todayLightMins) / 90.0)
    }

    var todayProgressColor: Color {
        if todayLightMins >= 90 { return .green }
        if todayLightMins >= 60 { return .yellow }
        return .orange
    }

    struct ScoreBreakdown {
        let light: Int
        let morning: Int
        let temperature: Int
        let outdoor: Int
    }

    struct CircadianDayData: Identifiable {
        let id = UUID()
        let date: String
        let dayLabel: String
        let daylightMins: Int
        let morningMins: Int
        let afternoonMins: Int
        let outdoorMins: Int
        let score: Int?
    }

    func loadData() async {
        isLoading = true

        do {
            // Get circadian data from Convex
            let data = try await ConvexService.shared.getCircadianData(days: 7)
            daysOfData = data.count

            // Process daily data
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"

            dailyData = data.map { record in
                var dayLabel = "?"
                if let date = formatter.date(from: record.date) {
                    dayLabel = dayFormatter.string(from: date)
                }

                return CircadianDayData(
                    date: record.date,
                    dayLabel: dayLabel,
                    daylightMins: record.timeInDaylightMins ?? 0,
                    morningMins: record.morningLightMins ?? 0,
                    afternoonMins: record.afternoonLightMins ?? 0,
                    outdoorMins: record.outdoorWorkoutMins ?? 0,
                    score: record.circadianScore
                )
            }

            // Get today's status
            let status = try await ConvexService.shared.getCircadianStatus()
            todayLightMins = status.daylightMins
            todayMorningMins = status.morningLightMins
            todayNeedsMoreLight = status.needsMoreLight
            circadianScore = status.circadianScore

            // Calculate averages
            if !dailyData.isEmpty {
                let totalMorning = dailyData.map(\.morningMins).reduce(0, +)
                let totalAfternoon = dailyData.map(\.afternoonMins).reduce(0, +)
                avgMorningMins = totalMorning / dailyData.count
                avgAfternoonMins = totalAfternoon / dailyData.count

                let total = totalMorning + totalAfternoon
                morningLightRatio = total > 0 ? Double(totalMorning) / Double(total) : 0

                weeklyOutdoorMins = dailyData.map(\.outdoorMins).reduce(0, +)
                weeklyOutdoorCount = dailyData.filter { $0.outdoorMins > 0 }.count

                // Score trend (compare first vs last)
                if dailyData.count >= 3 {
                    let recentScores = dailyData.suffix(3).compactMap(\.score)
                    let olderScores = dailyData.prefix(3).compactMap(\.score)
                    if !recentScores.isEmpty && !olderScores.isEmpty {
                        let recentAvg = recentScores.reduce(0, +) / recentScores.count
                        let olderAvg = olderScores.reduce(0, +) / olderScores.count
                        scoreTrend = recentAvg - olderAvg
                    }
                }

                // Temperature data
                let temps = data.compactMap(\.sleepingWristTempDeviation)
                if !temps.isEmpty {
                    avgTempDeviation = temps.reduce(0, +) / Double(temps.count)
                    tempTrend = data.last?.wristTempTrend
                }
            }

            // Generate recommendations
            generateRecommendations()

        } catch {
            print("[CircadianInsightsView] Error loading data: \(error)")
        }

        isLoading = false
    }

    func refreshData() async {
        await loadData()
    }

    private func generateRecommendations() {
        recommendations.removeAll()

        // Low overall light
        if daysOfData >= 3 {
            let avgLight = dailyData.map(\.daylightMins).reduce(0, +) / max(1, dailyData.count)
            if avgLight < 60 {
                recommendations.append("Your average daily light exposure is below target. Aim for at least 90 minutes of daylight.")
            }
        }

        // Low morning light
        if morningLightRatio < 0.3 && (avgMorningMins + avgAfternoonMins) > 30 {
            recommendations.append("Most of your light exposure is in the afternoon. Morning light (before noon) is more effective for circadian entrainment.")
        }

        // Temperature variability
        if let deviation = avgTempDeviation, abs(deviation) > 0.5 {
            recommendations.append("Your wrist temperature shows higher than normal variability. Maintain consistent sleep and wake times to stabilize your circadian rhythm.")
        }

        // Low outdoor activity
        if weeklyOutdoorMins < 60 && daysOfData >= 3 {
            recommendations.append("Try scheduling outdoor walks or workouts. Natural light is more effective than indoor lighting for circadian health.")
        }

        // Good score encouragement
        if let score = circadianScore, score >= 80 {
            recommendations.append("Great job! Your circadian signals are strong. Keep up your outdoor light exposure routine.")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CircadianInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CircadianInsightsView()
                .environmentObject(ThemeManager.shared)
        }
    }
}
#endif
