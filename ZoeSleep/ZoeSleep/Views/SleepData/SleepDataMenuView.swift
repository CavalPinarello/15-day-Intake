//
//  SleepDataMenuView.swift
//  Zoe Sleep for Longevity System
//
//  Main menu for exploring sleep data from multiple wearables
//

import SwiftUI

struct SleepDataMenuView: View {
    @StateObject private var viewModel = SleepDataViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var healthKitManager: HealthKitManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            List {
                // Connected Devices Section
                connectedDevicesSection

                // Today's Summary Section
                if viewModel.todayZoeScore != nil || viewModel.todayHRVCharge != nil {
                    todaySummarySection
                }

                // Detailed Analysis Section
                detailedAnalysisSection

                // History Section
                historySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sleep Data")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(themeManager.currentColorScheme)
            .tint(themeManager.accentColor)
            .refreshable {
                await viewModel.syncLatestData()
            }
            .task {
                await viewModel.loadData()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .background(Color(UIColor.systemBackground).opacity(0.9))
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Connected Devices Section

    private var connectedDevicesSection: some View {
        Section {
            ForEach(viewModel.connectedSources) { source in
                SourceToggleRow(
                    source: source,
                    isVisible: viewModel.isSourceVisible(source),
                    theme: theme,
                    onToggle: { viewModel.toggleSource(source) }
                )
            }

            if viewModel.connectedSources.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(theme.warning)
                    Text("No sleep data sources found")
                        .foregroundColor(theme.textSecondary)
                }
            }
        } header: {
            Text("Connected Devices")
        } footer: {
            Text("Toggle devices to show or hide their data in charts")
                .foregroundColor(theme.textSecondary)
        }
    }

    // MARK: - Today's Summary Section

    private var todaySummarySection: some View {
        Section("Today") {
            NavigationLink {
                SleepScoreDetailView(viewModel: viewModel)
            } label: {
                SleepScoreSummaryRow(
                    zoeScore: viewModel.todayZoeScore?.zoeScore,
                    hrvCharge: viewModel.todayHRVCharge?.chargeScore,
                    hrvTrajectory: viewModel.todayHRVCharge?.recoveryTrajectory,
                    theme: theme
                )
            }
        }
    }

    // MARK: - Detailed Analysis Section

    private var detailedAnalysisSection: some View {
        Section("Detailed Analysis") {
            NavigationLink {
                HRVRecoveryView(viewModel: viewModel)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HRV Recovery")
                            .foregroundColor(theme.primaryText)
                        Text("Track your nighttime recovery")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "heart.text.square")
                        .foregroundColor(theme.accent)
                }
            }

            NavigationLink {
                SleepPatternsView(viewModel: viewModel)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Patterns")
                            .foregroundColor(theme.primaryText)
                        Text("Bedtime consistency & awakenings")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundColor(theme.accent)
                }
            }

            NavigationLink {
                SleepStagesView(viewModel: viewModel)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Stages")
                            .foregroundColor(theme.primaryText)
                        Text("Deep, REM, and light sleep")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "moon.zzz")
                        .foregroundColor(theme.accent)
                }
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        Section("History") {
            NavigationLink {
                WeeklyTrendsView(viewModel: viewModel)
            } label: {
                Label {
                    HStack {
                        Text("7-Day Trends")
                            .foregroundColor(theme.primaryText)
                        Spacer()
                        if let summary = viewModel.weeklySummary {
                            TrendBadge(trend: summary.trend, theme: theme)
                        }
                    }
                } icon: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(theme.accent)
                }
            }
        }
    }
}

// MARK: - Source Toggle Row

struct SourceToggleRow: View {
    let source: ConnectedSleepSource
    let isVisible: Bool
    let theme: ColorTheme
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            Image(systemName: source.iconName)
                .font(.title2)
                .foregroundColor(isVisible ? theme.accent : theme.textSecondary)
                .frame(width: 32)

            // Device info
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .foregroundColor(isVisible ? theme.primaryText : theme.textSecondary)

                HStack(spacing: 8) {
                    if source.hasSleepStages {
                        Label("Stages", systemImage: "moon.zzz")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }

                    if source.hrvCapability != "none" {
                        Label("HRV", systemImage: "heart")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }

                    if source.hasNativeScore {
                        Label("Score", systemImage: "star")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }

            Spacer()

            // Visibility toggle
            Toggle("", isOn: Binding(
                get: { isVisible },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(theme.accent)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Sleep Score Summary Row

struct SleepScoreSummaryRow: View {
    let zoeScore: Int?
    let hrvCharge: Int?
    let hrvTrajectory: RecoveryTrajectory?
    let theme: ColorTheme

    var body: some View {
        HStack(spacing: 16) {
            // Zoe Sleep Score
            if let score = zoeScore {
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(ScoreCategory.from(score: score).color(theme: theme))

                    Text("Sleep Score")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Divider
            if zoeScore != nil && hrvCharge != nil {
                Divider()
                    .frame(height: 40)
            }

            // HRV Charge
            if let charge = hrvCharge {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(charge)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(hrvTrajectory?.color(theme: theme) ?? theme.primaryText)

                        if let trajectory = hrvTrajectory {
                            Text(trajectory.label)
                                .font(.caption)
                                .foregroundColor(trajectory.color(theme: theme))
                        }
                    }

                    Text("HRV Charge")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Trend Badge

struct TrendBadge: View {
    let trend: ScoreTrend
    let theme: ColorTheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.iconName)
                .font(.caption)

            Text(trend.label)
                .font(.caption)
        }
        .foregroundColor(trendColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trendColor.opacity(0.15))
        .cornerRadius(8)
    }

    private var trendColor: Color {
        switch trend {
        case .improving:
            return theme.success
        case .stable:
            return theme.secondary
        case .declining:
            return theme.warning
        case .insufficient:
            return theme.textSecondary
        }
    }
}

// MARK: - Color Extensions

extension ScoreCategory {
    func color(theme: ColorTheme) -> Color {
        switch self {
        case .excellent:
            return theme.success
        case .good:
            return theme.primary
        case .fair:
            return theme.warning
        case .poor:
            return theme.error
        }
    }
}

extension RecoveryTrajectory {
    func color(theme: ColorTheme) -> Color {
        switch self {
        case .excellent:
            return theme.success
        case .good:
            return theme.primary
        case .moderate:
            return theme.secondary
        case .poor:
            return theme.warning
        case .veryLow:
            return theme.error
        case .insufficientData:
            return theme.textSecondary
        }
    }
}

// MARK: - Sleep Score Detail View

struct SleepScoreDetailView: View {
    @ObservedObject var viewModel: SleepDataViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Today's Score Card
                if let score = viewModel.todayZoeScore {
                    SleepScoreCard(score: score, theme: theme)
                }

                // Score Breakdown
                if let score = viewModel.todayZoeScore {
                    ScoreBreakdownCard(score: score, theme: theme)
                }

                // No data state
                if viewModel.todayZoeScore == nil {
                    NoDataCard(
                        icon: "moon.zzz",
                        title: "No Sleep Score",
                        message: "Sleep data will appear after your first tracked night.",
                        theme: theme
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Sleep Score")
        .navigationBarTitleDisplayMode(.large)
        .background(theme.cardBackground.opacity(0.3))
    }
}

struct SleepScoreCard: View {
    let score: ZoeSleepScoreResult
    let theme: ColorTheme

    var body: some View {
        VStack(spacing: 16) {
            Text("Zoe Sleep Score")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            ZStack {
                Circle()
                    .stroke(theme.cardBackground, lineWidth: 16)

                Circle()
                    .trim(from: 0, to: CGFloat(score.zoeScore) / 100)
                    .stroke(
                        ScoreCategory.from(score: score.zoeScore).color(theme: theme),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(score.zoeScore)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(ScoreCategory.from(score: score.zoeScore).color(theme: theme))

                    Text(ScoreCategory.from(score: score.zoeScore).label)
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
            }
            .frame(width: 180, height: 180)

            Text(score.date)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

struct ScoreBreakdownCard: View {
    let score: ZoeSleepScoreResult
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Score Breakdown")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            VStack(spacing: 12) {
                ScoreComponentRow(
                    label: "Duration",
                    value: Int(score.components.duration),
                    weight: "30%",
                    icon: "clock",
                    theme: theme
                )
                ScoreComponentRow(
                    label: "Efficiency",
                    value: Int(score.components.efficiency),
                    weight: "25%",
                    icon: "percent",
                    theme: theme
                )
                ScoreComponentRow(
                    label: "Deep Sleep",
                    value: Int(score.components.deepSleep),
                    weight: "20%",
                    icon: "moon.fill",
                    theme: theme
                )
                ScoreComponentRow(
                    label: "REM Sleep",
                    value: Int(score.components.remSleep),
                    weight: "15%",
                    icon: "brain.head.profile",
                    theme: theme
                )
                ScoreComponentRow(
                    label: "Consistency",
                    value: Int(score.components.consistency),
                    weight: "10%",
                    icon: "calendar",
                    theme: theme
                )
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

struct ScoreComponentRow: View {
    let label: String
    let value: Int
    let weight: String
    let icon: String
    let theme: ColorTheme

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(theme.accent)
                .frame(width: 24)

            Text(label)
                .foregroundColor(theme.primaryText)

            Spacer()

            Text(weight)
                .font(.caption)
                .foregroundColor(theme.textSecondary)

            Text("\(value)")
                .fontWeight(.semibold)
                .foregroundColor(scoreColor)
                .frame(width: 30, alignment: .trailing)
        }
        .font(.subheadline)
    }

    private var scoreColor: Color {
        if value >= 80 { return theme.success }
        if value >= 60 { return theme.primary }
        if value >= 40 { return theme.warning }
        return theme.error
    }
}

// MARK: - Sleep Patterns View

struct SleepPatternsView: View {
    @ObservedObject var viewModel: SleepDataViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Bedtime Consistency Card
                BedtimeConsistencyCard(scores: viewModel.sleepScoreHistory, theme: theme)

                // Awakenings Card
                AwakeningsCard(scores: viewModel.sleepScoreHistory, theme: theme)

                // Sleep Timing Card
                SleepTimingCard(scores: viewModel.sleepScoreHistory, theme: theme)

                if viewModel.sleepScoreHistory.isEmpty {
                    NoDataCard(
                        icon: "chart.xyaxis.line",
                        title: "No Pattern Data",
                        message: "Sleep patterns will appear after a few nights of tracking.",
                        theme: theme
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Sleep Patterns")
        .navigationBarTitleDisplayMode(.large)
        .background(theme.cardBackground.opacity(0.3))
    }
}

struct BedtimeConsistencyCard: View {
    let scores: [ZoeSleepScoreResult]
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bedtime Consistency", systemImage: "bed.double")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            if scores.isEmpty {
                Text("Not enough data")
                    .foregroundColor(theme.textSecondary)
            } else {
                // Show bedtime variance
                let avgConsistency = Int(scores.map { $0.components.consistency }.reduce(0, +)) / max(scores.count, 1)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Consistency Score")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                        Text("\(avgConsistency)/100")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.primaryText)
                    }

                    Spacer()

                    ConsistencyIndicator(score: avgConsistency, theme: theme)
                }

                Text(consistencyMessage(for: avgConsistency))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }

    private func consistencyMessage(for score: Int) -> String {
        if score >= 80 { return "Excellent! Your sleep schedule is very consistent." }
        if score >= 60 { return "Good consistency. Try to keep your bedtime within 30 minutes." }
        if score >= 40 { return "Your bedtime varies quite a bit. A regular schedule helps sleep quality." }
        return "Irregular sleep schedule detected. Consider setting a consistent bedtime."
    }
}

struct ConsistencyIndicator: View {
    let score: Int
    let theme: ColorTheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.cardBackground, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(indicatorColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 50, height: 50)
    }

    private var indicatorColor: Color {
        if score >= 80 { return theme.success }
        if score >= 60 { return theme.primary }
        if score >= 40 { return theme.warning }
        return theme.error
    }
}

struct AwakeningsCard: View {
    let scores: [ZoeSleepScoreResult]
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Awakenings", systemImage: "bell")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            if scores.isEmpty {
                Text("Not enough data")
                    .foregroundColor(theme.textSecondary)
            } else {
                Text("Average efficiency score indicates sleep continuity")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)

                let avgEfficiency = Int(scores.map { $0.components.efficiency }.reduce(0, +)) / max(scores.count, 1)

                HStack {
                    Text("Sleep Efficiency")
                        .foregroundColor(theme.primaryText)
                    Spacer()
                    Text("\(avgEfficiency)%")
                        .fontWeight(.semibold)
                        .foregroundColor(avgEfficiency >= 85 ? theme.success : theme.warning)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

struct SleepTimingCard: View {
    let scores: [ZoeSleepScoreResult]
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sleep Duration", systemImage: "clock")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            if scores.isEmpty {
                Text("Not enough data")
                    .foregroundColor(theme.textSecondary)
            } else {
                let avgDuration = Int(scores.map { $0.components.duration }.reduce(0, +)) / max(scores.count, 1)

                HStack {
                    Text("Duration Score")
                        .foregroundColor(theme.primaryText)
                    Spacer()
                    Text("\(avgDuration)/100")
                        .fontWeight(.semibold)
                        .foregroundColor(avgDuration >= 80 ? theme.success : theme.warning)
                }
                .font(.subheadline)

                Text("Optimal sleep duration is 7-9 hours for most adults.")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

// MARK: - Sleep Stages View

struct SleepStagesView: View {
    @ObservedObject var viewModel: SleepDataViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Today's Stages
                if let score = viewModel.todayZoeScore {
                    SleepStagesCard(score: score, theme: theme)
                }

                // Stage Info Cards
                StageInfoCard(
                    stage: "Deep Sleep",
                    icon: "moon.fill",
                    color: theme.primary,
                    description: "Essential for physical recovery, immune function, and memory consolidation.",
                    optimal: "15-25% of total sleep",
                    score: viewModel.todayZoeScore.map { Int($0.components.deepSleep) },
                    theme: theme
                )

                StageInfoCard(
                    stage: "REM Sleep",
                    icon: "brain.head.profile",
                    color: theme.accent,
                    description: "Critical for emotional processing, learning, and creativity.",
                    optimal: "20-25% of total sleep",
                    score: viewModel.todayZoeScore.map { Int($0.components.remSleep) },
                    theme: theme
                )

                StageInfoCard(
                    stage: "Light Sleep",
                    icon: "moon",
                    color: theme.secondary,
                    description: "Transition stage that prepares your body for deeper sleep.",
                    optimal: "50-60% of total sleep",
                    score: nil,
                    theme: theme
                )

                if viewModel.todayZoeScore == nil {
                    NoDataCard(
                        icon: "moon.zzz",
                        title: "No Stage Data",
                        message: "Sleep stage data requires a compatible wearable device.",
                        theme: theme
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Sleep Stages")
        .navigationBarTitleDisplayMode(.large)
        .background(theme.cardBackground.opacity(0.3))
    }
}

struct SleepStagesCard: View {
    let score: ZoeSleepScoreResult
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last Night's Stages")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            // Stage bars
            VStack(spacing: 12) {
                StageBar(
                    label: "Deep",
                    percentage: score.components.deepSleep / 100 * 25,
                    color: theme.primary,
                    theme: theme
                )
                StageBar(
                    label: "REM",
                    percentage: score.components.remSleep / 100 * 25,
                    color: theme.accent,
                    theme: theme
                )
                StageBar(
                    label: "Light",
                    percentage: 55, // Estimated
                    color: theme.secondary,
                    theme: theme
                )
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

struct StageBar: View {
    let label: String
    let percentage: Double
    let color: Color
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text(String(format: "%.0f%%", percentage))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primaryText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.cardBackground)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percentage / 100))
                }
            }
            .frame(height: 8)
        }
    }
}

struct StageInfoCard: View {
    let stage: String
    let icon: String
    let color: Color
    let description: String
    let optimal: String
    let score: Int?
    let theme: ColorTheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stage)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    if let score = score {
                        Text("\(score)/100")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(score >= 70 ? theme.success : theme.warning)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)

                Text("Optimal: \(optimal)")
                    .font(.caption2)
                    .foregroundColor(theme.accent)
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

// MARK: - Weekly Trends View

struct WeeklyTrendsView: View {
    @ObservedObject var viewModel: SleepDataViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Weekly Summary
                if let summary = viewModel.weeklySummary {
                    WeeklySummaryCard(summary: summary, theme: theme)
                }

                // Score Trend Chart
                if !viewModel.sleepScoreHistory.isEmpty {
                    ScoreTrendCard(scores: viewModel.sleepScoreHistory, theme: theme)
                }

                // HRV Trend
                if !viewModel.hrvChargeHistory.isEmpty {
                    HRVWeeklyTrendCard(charges: viewModel.hrvChargeHistory, theme: theme)
                }

                // Tips based on trends
                if let summary = viewModel.weeklySummary {
                    TrendInsightsCard(summary: summary, theme: theme)
                }

                if viewModel.sleepScoreHistory.isEmpty && viewModel.hrvChargeHistory.isEmpty {
                    NoDataCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No Trend Data",
                        message: "Track your sleep for a few days to see trends.",
                        theme: theme
                    )
                }
            }
            .padding()
        }
        .navigationTitle("7-Day Trends")
        .navigationBarTitleDisplayMode(.large)
        .background(theme.cardBackground.opacity(0.3))
    }
}

struct WeeklySummaryCard: View {
    let summary: WeeklySleepScoreSummary
    let theme: ColorTheme

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Weekly Average")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)

                Spacer()

                TrendBadge(trend: summary.trend, theme: theme)
            }

            HStack(spacing: 24) {
                VStack {
                    if let avgScore = summary.avgZoeScore {
                        Text("\(avgScore)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(ScoreCategory.from(score: avgScore).color(theme: theme))
                    } else {
                        Text("—")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }

                    Text("Avg Score")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text("\(summary.daysWithData)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primaryText)

                    Text("Nights")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    if let bestDay = summary.bestDay {
                        Text(bestDay.suffix(2))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(theme.success)
                    } else {
                        Text("—")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }

                    Text("Best Day")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }
}

struct ScoreTrendCard: View {
    let scores: [ZoeSleepScoreResult]
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Score Trend")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            // Simple bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(scores.prefix(7).reversed(), id: \.date) { score in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ScoreCategory.from(score: score.zoeScore).color(theme: theme))
                            .frame(width: 30, height: CGFloat(score.zoeScore) * 0.8)

                        Text(dayLabel(for: score.date))
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
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
}

struct HRVWeeklyTrendCard: View {
    let charges: [HRVChargeResult]
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HRV Recovery Trend")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(charges.prefix(7).reversed()) { charge in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(charge.recoveryTrajectory.color(theme: theme))
                            .frame(width: 30, height: CGFloat(charge.chargeScore) * 0.8)

                        Text(dayLabel(for: charge.date))
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)

            if let avg = averageCharge {
                HStack {
                    Text("Average HRV Charge:")
                        .foregroundColor(theme.textSecondary)
                    Text("\(avg)")
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
        return charges.map { $0.chargeScore }.reduce(0, +) / charges.count
    }
}

struct TrendInsightsCard: View {
    let summary: WeeklySleepScoreSummary
    let theme: ColorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Insights", systemImage: "lightbulb")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            Text(insightText)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
        }
        .padding()
        .background(GlassyCardBackground())
        .cornerRadius(16)
    }

    private var insightText: String {
        switch summary.trend {
        case .improving:
            return "Great job! Your sleep quality is improving. Keep up the consistent sleep schedule."
        case .stable:
            return "Your sleep quality is stable. Consider optimizing your sleep environment for better scores."
        case .declining:
            return "Your sleep quality has been declining. Try reducing screen time before bed and maintaining a consistent schedule."
        case .insufficient:
            return "Keep tracking to see your sleep trends over time."
        }
    }
}

// MARK: - No Data Card (Reusable)

struct NoDataCard: View {
    let icon: String
    let title: String
    let message: String
    let theme: ColorTheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(theme.textSecondary)

            Text(title)
                .font(.headline)
                .foregroundColor(theme.primaryText)

            Text(message)
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
    SleepDataMenuView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(HealthKitManager.shared)
}
