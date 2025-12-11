//
//  SleepInsightsViewModel.swift
//  ZoeSleep
//
//  ViewModel for Sleep Insights Dashboard
//  Manages data fetching, state, and business logic for sleep analytics
//

import Foundation
import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
class SleepInsightsViewModel: ObservableObject {
    // MARK: - Published State

    /// Number of days of data available
    @Published var daysOfData: Int = 0

    /// Timestamp of last HealthKit sync
    @Published var lastHealthKitSync: Date?

    /// Last night's subjective rating
    @Published var lastNightSubjective: SubjectiveSleepData?

    /// Last night's objective metrics
    @Published var lastNightObjective: ObjectiveSleepData?

    /// Correlation between subjective and objective (requires 7+ days)
    @Published var correlation: Double?

    /// Perception gap trend analysis
    @Published var perceptionGapTrend: PerceptionGapTrend?

    /// Workday vs weekend pattern (requires 7+ days)
    @Published var workdayWeekendPattern: WorkdayWeekendPattern?

    /// Optimal bedtime analysis (requires 7+ days)
    @Published var optimalBedtime: OptimalBedtime?

    /// Sleep stage distribution patterns
    @Published var stagePatterns: SleepStagePatterns?

    /// Generated actionable insights
    @Published var insights: [SleepInsight] = []

    /// Daily comparisons for trend chart
    @Published var dailyComparisons: [DailyComparison] = []

    /// Weekly averages
    @Published var weeklyAverage: WeeklyAverage?

    /// Last night's data
    @Published var lastNight: LastNightSleep?

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error state
    @Published var error: Error?

    /// Days until basic insights unlock (0 if already unlocked)
    @Published var daysUntilInsights: Int = 5

    /// Days until pattern detection unlocks (0 if already unlocked)
    @Published var daysUntilPatterns: Int = 7

    // MARK: - Computed Properties

    /// Whether we have enough data for basic insights (5+ days)
    var hasEnoughForInsights: Bool {
        daysOfData >= 5
    }

    /// Whether we have enough data for pattern detection (7+ days)
    var hasEnoughForPatterns: Bool {
        daysOfData >= 7
    }

    /// Formatted last night's sleep duration
    var lastNightDurationFormatted: String {
        guard let mins = lastNightObjective?.totalSleepMins else { return "--" }
        let hours = mins / 60
        let remainingMins = mins % 60
        return "\(hours)h \(remainingMins)m"
    }

    /// Formatted last night's efficiency
    var lastNightEfficiencyFormatted: String {
        guard let eff = lastNightObjective?.efficiency else { return "--%"}
        return "\(Int(eff))%"
    }

    /// Gap indicator icon name based on perception gap
    var gapIndicatorIcon: String {
        guard let subjective = lastNightSubjective,
              let objective = lastNightObjective else {
            return "equal.circle"
        }

        let normalizedSubjective = subjective.quality * 10
        let objectiveScore = normalizeObjectiveScore(objective)
        let gap = normalizedSubjective - objectiveScore

        if gap < -15 { return "arrow.down.circle.fill" }  // Underestimate
        if gap > 15 { return "arrow.up.circle.fill" }     // Overestimate
        return "checkmark.circle.fill"                     // Accurate
    }

    /// Gap indicator label
    var gapIndicatorLabel: String {
        guard let subjective = lastNightSubjective,
              let objective = lastNightObjective else {
            return "No data"
        }

        let normalizedSubjective = subjective.quality * 10
        let objectiveScore = normalizeObjectiveScore(objective)
        let gap = normalizedSubjective - objectiveScore

        if gap < -15 { return "Underestimate" }
        if gap > 15 { return "Overestimate" }
        return "Accurate"
    }

    /// Interpretation text for perception comparison
    var interpretationText: String {
        guard let subjective = lastNightSubjective,
              let objective = lastNightObjective else {
            return "Complete your sleep log to see the comparison"
        }

        let hoursSlept = Double(objective.totalSleepMins) / 60.0

        if subjective.quality <= 4 && objective.efficiency >= 85 && hoursSlept >= 7 {
            return "You rated last night poorly, but you got \(String(format: "%.1f", hoursSlept)) hours with \(Int(objective.efficiency))% efficiency. This perception gap is worth exploring."
        } else if subjective.quality >= 7 && objective.efficiency < 75 {
            return "You felt well-rested despite lower efficiency. Sometimes how you feel matters more than the numbers!"
        } else if abs(subjective.quality * 10 - normalizeObjectiveScore(objective)) <= 15 {
            return "Your perception aligns well with your objective sleep data. Great self-awareness!"
        } else {
            return "There's a gap between how you felt and what the data shows. Let's explore this pattern."
        }
    }

    /// Correlation description text
    var correlationDescription: String {
        guard let r = correlation else { return "Collecting data..." }

        if r >= 0.7 { return "Excellent - Your perception matches reality" }
        if r >= 0.4 { return "Good - Generally aligned" }
        if r >= 0.2 { return "Moderate - Some perception gaps" }
        return "Low - Significant perception gaps"
    }

    // MARK: - Initialization

    init() {
        // Initial state is set via published properties
    }

    // MARK: - Public Methods

    /// Load all insights data from backend
    func loadInsights() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            // In production, these would call ConvexService
            // For now, we'll use placeholder implementation
            await loadDashboardSummary()

            if hasEnoughForInsights {
                await loadPerceptionVsReality()
            }

            if hasEnoughForPatterns {
                await loadPatterns()
                await loadGeneratedInsights()
            }

        } catch {
            self.error = error
            print("[SleepInsights] Error loading insights: \(error)")
        }
    }

    /// Refresh all data
    func refreshData() async {
        await loadInsights()
    }

    // MARK: - Private Methods

    /// Load dashboard summary from Convex
    private func loadDashboardSummary() async {
        // TODO: Implement Convex call to sleepInsights.getDashboardSummary
        // For now, this is a placeholder that would be replaced with actual API call

        // Example of what the Convex response would look like:
        // let summary = try await ConvexService.shared.query("sleepInsights:getDashboardSummary", args: ["userId": userId])

        // Placeholder: These values would come from the API
        // self.daysOfData = summary.daysOfData
        // self.daysUntilInsights = summary.daysUntilInsights
        // self.daysUntilPatterns = summary.daysUntilPatterns
        // self.weeklyAverage = summary.weeklyAverage
        // self.lastNight = summary.lastNight
        // self.lastHealthKitSync = Date(timeIntervalSince1970: summary.lastSyncTime / 1000)
    }

    /// Load perception vs reality comparison data
    private func loadPerceptionVsReality() async {
        // TODO: Implement Convex call to sleepInsights.getPerceptionVsReality

        // Example:
        // let data = try await ConvexService.shared.query("sleepInsights:getPerceptionVsReality", args: ["userId": userId])
        // self.lastNightSubjective = data.lastNightSubjective
        // self.lastNightObjective = data.lastNightObjective
        // self.correlation = data.correlation
        // self.perceptionGapTrend = data.gapTrend
        // self.dailyComparisons = data.comparisons.map { ... }
    }

    /// Load pattern detection data
    private func loadPatterns() async {
        // TODO: Implement Convex call to sleepInsights.detectPatterns

        // Example:
        // let patterns = try await ConvexService.shared.query("sleepInsights:detectPatterns", args: ["userId": userId])
        // self.workdayWeekendPattern = patterns.workdayWeekend
        // self.optimalBedtime = patterns.optimalBedtime
        // self.stagePatterns = patterns.sleepStages
    }

    /// Load generated actionable insights
    private func loadGeneratedInsights() async {
        // TODO: Implement Convex call to sleepInsights.generateInsights

        // Example:
        // let insightsData = try await ConvexService.shared.query("sleepInsights:generateInsights", args: ["userId": userId])
        // self.insights = insightsData
    }

    /// Normalize objective sleep score to 0-100 scale
    private func normalizeObjectiveScore(_ objective: ObjectiveSleepData) -> Double {
        let durationScore = min(100, (Double(objective.totalSleepMins) / 420.0) * 100)
        return (objective.efficiency * 0.6) + (durationScore * 0.4)
    }

    // MARK: - Helper Methods for UI

    /// Get icon for insight type
    func iconForInsightType(_ type: String) -> String {
        switch type {
        case "optimization": return "slider.horizontal.3"
        case "pattern": return "waveform.path.ecg"
        case "cognitive": return "brain.head.profile"
        case "positive": return "checkmark.circle"
        case "warning": return "exclamationmark.triangle"
        default: return "lightbulb"
        }
    }

    /// Format date string to short day name (e.g., "Mon")
    func shortDayName(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// Format minutes to hours and minutes string
    func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension SleepInsightsViewModel {
    /// Create a preview instance with sample data
    static var preview: SleepInsightsViewModel {
        let vm = SleepInsightsViewModel()
        vm.daysOfData = 10
        vm.daysUntilInsights = 0
        vm.daysUntilPatterns = 0
        vm.lastNightSubjective = SubjectiveSleepData(quality: 6, date: "2025-12-02")
        vm.lastNightObjective = ObjectiveSleepData(
            totalSleepMins: 420,
            efficiency: 85,
            deepSleepMins: 60,
            remSleepMins: 90,
            lightSleepMins: 240,
            date: "2025-12-02"
        )
        vm.correlation = 0.72
        vm.perceptionGapTrend = PerceptionGapTrend(
            avgGap: -12.5,
            consistentUnderestimate: true,
            confidence: 0.85
        )
        vm.weeklyAverage = WeeklyAverage(
            sleepMins: 415,
            efficiency: 82,
            deepMins: 55,
            remMins: 85
        )
        vm.insights = [
            SleepInsight(
                id: "bedtime_latency",
                type: "optimization",
                title: "Optimal Bedtime Found",
                text: "You fall asleep 18 minutes faster when going to bed before 10:30 PM.",
                confidence: 0.85,
                actionable: true
            ),
            SleepInsight(
                id: "weekend_deep_sleep",
                type: "pattern",
                title: "Weekend Sleep Pattern",
                text: "Your deep sleep is 22% better on weekends. Consider stress management during the week.",
                confidence: 0.78,
                actionable: true
            )
        ]
        vm.dailyComparisons = [
            DailyComparison(date: "2025-12-02", subjectiveScore: 60, objectiveScore: 75),
            DailyComparison(date: "2025-12-01", subjectiveScore: 70, objectiveScore: 72),
            DailyComparison(date: "2025-11-30", subjectiveScore: 50, objectiveScore: 68),
            DailyComparison(date: "2025-11-29", subjectiveScore: 80, objectiveScore: 82),
            DailyComparison(date: "2025-11-28", subjectiveScore: 55, objectiveScore: 70),
            DailyComparison(date: "2025-11-27", subjectiveScore: 65, objectiveScore: 75),
            DailyComparison(date: "2025-11-26", subjectiveScore: 75, objectiveScore: 78),
        ]
        return vm
    }

    /// Create a preview instance with insufficient data
    static var previewInsufficientData: SleepInsightsViewModel {
        let vm = SleepInsightsViewModel()
        vm.daysOfData = 3
        vm.daysUntilInsights = 2
        vm.daysUntilPatterns = 4
        return vm
    }
}
#endif
