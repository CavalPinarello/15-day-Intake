//
//  SleepInsightsDashboardView.swift
//  ZoeSleep
//
//  Main dashboard for sleep insights and analytics.
//  Progressively reveals features as data accumulates:
//  - Day 1-4: DataRequirementView with countdown
//  - Day 5+: PerceptionVsReality + basic trends
//  - Day 7+: Full patterns + actionable insights
//

import SwiftUI

struct SleepInsightsDashboardView: View {
    @StateObject private var viewModel = SleepInsightsViewModel()
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }

    // MARK: - Circadian-Aware Colors (for text on circadian background)
    private var palette: CircadianPalette {
        CircadianPalette.forPeriod(themeManager.currentTimePeriod)
    }

    private var circadianTextPrimary: Color {
        palette.textPrimary
    }

    private var circadianTextSecondary: Color {
        palette.textSecondary
    }

    var body: some View {
        ZStack {
            // Circadian wave background - syncs with ThemeManager
            DashboardWaveBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Header with last sync info
                    headerSection

                    if viewModel.isLoading {
                        loadingView
                    } else if !viewModel.hasEnoughForInsights {
                        // Not enough data yet - show progress
                        DataRequirementView(
                            currentDays: viewModel.daysOfData,
                            requiredDays: 5
                        )
                        .padding(.horizontal)
                    } else {
                        // Has enough data - show insights
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
            await viewModel.loadInsights()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Sleep Insights")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(circadianTextPrimary)

            if let lastSync = viewModel.lastHealthKitSync {
                Text("Last synced \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(circadianTextSecondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(theme.primary)
            Text("Loading insights...")
                .font(.subheadline)
                .foregroundColor(circadianTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Insights Content

    private var insightsContent: some View {
        VStack(spacing: 20) {
            // Last night summary (always shown with data)
            if viewModel.lastNightSubjective != nil || viewModel.lastNightObjective != nil {
                lastNightSummaryCard
            }

            // Perception vs Reality (5+ days)
            PerceptionVsRealityCard(viewModel: viewModel)
                .padding(.horizontal)

            // 7-day trend chart (5+ days)
            if !viewModel.dailyComparisons.isEmpty {
                TrendChartView(comparisons: viewModel.dailyComparisons)
                    .padding(.horizontal)
            }

            // Patterns section (7+ days)
            if viewModel.hasEnoughForPatterns {
                PatternDetectionView(
                    workdayVsWeekend: viewModel.workdayWeekendPattern,
                    optimalBedtime: viewModel.optimalBedtime,
                    sleepStagePatterns: viewModel.stagePatterns
                )
                .padding(.horizontal)
            }

            // Actionable Insights (7+ days)
            if !viewModel.insights.isEmpty {
                insightsSection
            }

            // Weekly averages
            if let weeklyAvg = viewModel.weeklyAverage {
                weeklyAveragesCard(weeklyAvg)
            }

            Spacer(minLength: 20)
        }
    }

    // MARK: - Last Night Summary Card

    private var lastNightSummaryCard: some View {
        HStack(spacing: 16) {
            // Sleep duration
            VStack(spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundColor(theme.primary)

                Text(viewModel.lastNightDurationFormatted)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textOnCard)

                Text("Last Night")
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 50)

            // Efficiency
            VStack(spacing: 4) {
                Image(systemName: "percent")
                    .font(.title2)
                    .foregroundColor(theme.success)

                Text(viewModel.lastNightEfficiencyFormatted)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textOnCard)

                Text("Efficiency")
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 50)

            // Your rating
            VStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(theme.warning)

                if let subjective = viewModel.lastNightSubjective {
                    Text("\(Int(subjective.quality))/10")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textOnCard)
                } else {
                    Text("--")
                        .font(.title3)
                        .foregroundColor(theme.textOnCardSecondary)
                }

                Text("Your Rating")
                    .font(.caption)
                    .foregroundColor(theme.textOnCardSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
                .foregroundColor(circadianTextPrimary)
                .padding(.horizontal)

            ForEach(viewModel.insights) { insight in
                InsightCard(insight: insight)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Weekly Averages Card

    private func weeklyAveragesCard(_ avg: WeeklyAverage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Averages")
                .font(.headline)
                .foregroundColor(theme.textOnCard)

            HStack(spacing: 16) {
                avgStatView(
                    icon: "bed.double.fill",
                    value: viewModel.formatDuration(avg.sleepMins),
                    label: "Sleep"
                )

                avgStatView(
                    icon: "percent",
                    value: "\(avg.efficiency)%",
                    label: "Efficiency"
                )

                avgStatView(
                    icon: "waveform.path.ecg",
                    value: viewModel.formatDuration(avg.deepMins),
                    label: "Deep"
                )

                avgStatView(
                    icon: "brain.head.profile",
                    value: viewModel.formatDuration(avg.remMins),
                    label: "REM"
                )
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func avgStatView(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(theme.primary)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.textOnCard)

            Text(label)
                .font(.caption2)
                .foregroundColor(theme.textOnCardSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
struct SleepInsightsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With sufficient data
            NavigationView {
                SleepInsightsDashboardView()
                    .environmentObject(ThemeManager.shared)
            }
            .previewDisplayName("With Data")

            // Insufficient data state
            NavigationView {
                ScrollView {
                    DataRequirementView(currentDays: 3, requiredDays: 5)
                        .environmentObject(ThemeManager.shared)
                        .padding()
                }
                .background(Color(.systemBackground))
            }
            .previewDisplayName("Insufficient Data")
        }
    }
}
#endif
