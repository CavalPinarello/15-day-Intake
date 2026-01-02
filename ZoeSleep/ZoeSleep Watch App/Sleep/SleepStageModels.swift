//
//  SleepStageModels.swift
//  ZoeSleep Watch App
//
//  Comprehensive sleep stage data models with chronotype integration.
//  Goes beyond Apple's basic tracking with personalized circadian analysis.
//

import Foundation
import SwiftUI

// MARK: - Sleep Stage Types

/// Extended sleep stages with more granular classification
enum SleepStage: String, CaseIterable, Codable {
    case awake = "awake"
    case remLight = "rem_light"      // Transitional REM
    case rem = "rem"                  // Full REM
    case lightN1 = "light_n1"        // N1 - Drowsy
    case lightN2 = "light_n2"        // N2 - True light sleep
    case deepN3 = "deep_n3"          // N3 - Slow wave sleep
    case deepN4 = "deep_n4"          // N4 - Deepest restorative

    var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .remLight: return "Light REM"
        case .rem: return "REM"
        case .lightN1: return "Drowsy"
        case .lightN2: return "Light"
        case .deepN3: return "Deep"
        case .deepN4: return "Deep+"
        }
    }

    var shortName: String {
        switch self {
        case .awake: return "W"
        case .remLight: return "R-"
        case .rem: return "R"
        case .lightN1: return "N1"
        case .lightN2: return "N2"
        case .deepN3: return "N3"
        case .deepN4: return "N4"
        }
    }

    var color: Color {
        switch self {
        case .awake: return .red.opacity(0.7)
        case .remLight: return .purple.opacity(0.6)
        case .rem: return .purple
        case .lightN1: return .cyan.opacity(0.5)
        case .lightN2: return .cyan
        case .deepN3: return .indigo
        case .deepN4: return .indigo.opacity(0.8)
        }
    }

    var category: SleepStageCategory {
        switch self {
        case .awake: return .awake
        case .remLight, .rem: return .rem
        case .lightN1, .lightN2: return .light
        case .deepN3, .deepN4: return .deep
        }
    }

    /// Restorative value (0-1) for scoring
    var restorativeValue: Double {
        switch self {
        case .awake: return 0.0
        case .remLight: return 0.6
        case .rem: return 0.8         // Mental restoration
        case .lightN1: return 0.3
        case .lightN2: return 0.5
        case .deepN3: return 0.9      // Physical restoration
        case .deepN4: return 1.0      // Peak restoration
        }
    }
}

enum SleepStageCategory: String, CaseIterable {
    case awake = "Awake"
    case light = "Light"
    case deep = "Deep"
    case rem = "REM"

    var color: Color {
        switch self {
        case .awake: return .red.opacity(0.7)
        case .light: return .cyan
        case .deep: return .indigo
        case .rem: return .purple
        }
    }

    var icon: String {
        switch self {
        case .awake: return "eye.fill"
        case .light: return "moon.fill"
        case .deep: return "moon.zzz.fill"
        case .rem: return "brain.head.profile"
        }
    }
}

// MARK: - Chronotype

/// The four main chronotypes based on circadian preference
enum Chronotype: String, CaseIterable, Codable {
    case earlyRiser = "early_riser"   // Early bird - peaks early morning
    case balanced = "balanced"         // Most common - follows solar cycle
    case nightOwl = "night_owl"        // Night owl - peaks late evening
    case adaptive = "adaptive"         // Light sleeper - irregular patterns

    var displayName: String {
        switch self {
        case .earlyRiser: return "Early Riser"
        case .balanced: return "Balanced"
        case .nightOwl: return "Night Owl"
        case .adaptive: return "Adaptive"
        }
    }

    var emoji: String {
        switch self {
        case .earlyRiser: return "☀️"
        case .balanced: return "⚖️"
        case .nightOwl: return "🌙"
        case .adaptive: return "🔄"
        }
    }

    var description: String {
        switch self {
        case .earlyRiser: return "Most productive in the morning, naturally wakes early"
        case .balanced: return "Follows the solar cycle, peaks mid-morning to afternoon"
        case .nightOwl: return "Most creative in the evening, prefers later bedtimes"
        case .adaptive: return "Variable sleep patterns, sensitive to environment"
        }
    }

    /// Optimal sleep window start (24-hour format)
    var optimalBedtimeStart: Double {
        switch self {
        case .earlyRiser: return 21.0      // 9:00 PM
        case .balanced: return 22.0        // 10:00 PM
        case .nightOwl: return 23.5        // 11:30 PM
        case .adaptive: return 23.0        // 11:00 PM
        }
    }

    /// Optimal sleep window end
    var optimalBedtimeEnd: Double {
        switch self {
        case .earlyRiser: return 22.0      // 10:00 PM
        case .balanced: return 23.0        // 11:00 PM
        case .nightOwl: return 0.5         // 12:30 AM
        case .adaptive: return 24.0        // Midnight
        }
    }

    /// Optimal wake time
    var optimalWakeTime: Double {
        switch self {
        case .earlyRiser: return 5.5       // 5:30 AM
        case .balanced: return 7.0         // 7:00 AM
        case .nightOwl: return 7.5         // 7:30 AM
        case .adaptive: return 6.5         // 6:30 AM
        }
    }

    /// Ideal sleep duration in hours
    var idealSleepDuration: Double {
        switch self {
        case .earlyRiser: return 7.5
        case .balanced: return 8.0
        case .nightOwl: return 7.5
        case .adaptive: return 6.0    // Adaptive types often need less but struggle
        }
    }

    /// Expected deep sleep percentage
    var expectedDeepPercent: ClosedRange<Double> {
        switch self {
        case .earlyRiser: return 0.15...0.25
        case .balanced: return 0.13...0.23
        case .nightOwl: return 0.12...0.22
        case .adaptive: return 0.10...0.18
        }
    }

    /// Expected REM percentage
    var expectedREMPercent: ClosedRange<Double> {
        switch self {
        case .earlyRiser: return 0.20...0.25
        case .balanced: return 0.20...0.25
        case .nightOwl: return 0.22...0.28
        case .adaptive: return 0.18...0.24
        }
    }

    var color: Color {
        switch self {
        case .earlyRiser: return .orange
        case .balanced: return .green
        case .nightOwl: return .purple
        case .adaptive: return .cyan
        }
    }
}

// MARK: - Sleep Session

/// A complete sleep session with stage data
struct SleepSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let bedtime: Date
    let wakeTime: Date
    let stages: [SleepStageSegment]
    let heartRateData: [HeartRatePoint]?
    let respiratoryRate: Double?
    let hrv: Double?                    // Heart Rate Variability
    let skinTemperature: Double?
    let bloodOxygen: Double?
    let movementScore: Double?          // 0-1, lower is better

    var totalDuration: TimeInterval {
        wakeTime.timeIntervalSince(bedtime)
    }

    var totalDurationHours: Double {
        totalDuration / 3600.0
    }

    var timeAsleep: TimeInterval {
        stages.filter { $0.stage != .awake }.reduce(0) { $0 + $1.duration }
    }

    var sleepEfficiency: Double {
        guard totalDuration > 0 else { return 0 }
        return timeAsleep / totalDuration
    }

    var stageBreakdown: [SleepStageCategory: TimeInterval] {
        var breakdown: [SleepStageCategory: TimeInterval] = [:]
        for stage in stages {
            let category = stage.stage.category
            breakdown[category, default: 0] += stage.duration
        }
        return breakdown
    }

    var stagePercentages: [SleepStageCategory: Double] {
        let sleepTime = timeAsleep
        guard sleepTime > 0 else { return [:] }
        return stageBreakdown.mapValues { $0 / sleepTime }
    }

    /// Number of times woken up during the night
    var awakenings: Int {
        var count = 0
        var wasAsleep = false
        for segment in stages {
            if segment.stage == .awake && wasAsleep {
                count += 1
            }
            wasAsleep = segment.stage != .awake
        }
        return count
    }

    /// Time to fall asleep (sleep onset latency)
    var sleepOnsetLatency: TimeInterval {
        var latency: TimeInterval = 0
        for segment in stages {
            if segment.stage == .awake {
                latency += segment.duration
            } else {
                break
            }
        }
        return latency
    }

    /// Average time for first deep sleep cycle
    var timeToFirstDeep: TimeInterval? {
        var elapsed: TimeInterval = 0
        for segment in stages {
            if segment.stage == .deepN3 || segment.stage == .deepN4 {
                return elapsed
            }
            elapsed += segment.duration
        }
        return nil
    }

    /// Sleep cycles detected (roughly 90-minute cycles)
    var sleepCycles: Int {
        // Count transitions from deep -> REM as cycle markers
        var cycles = 0
        var inDeep = false
        for segment in stages {
            if segment.stage.category == .deep {
                inDeep = true
            } else if inDeep && segment.stage.category == .rem {
                cycles += 1
                inDeep = false
            }
        }
        return max(cycles, 1)
    }
}

struct SleepStageSegment: Identifiable, Codable {
    let id: UUID
    let stage: SleepStage
    let startTime: Date
    let endTime: Date

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }
}

struct HeartRatePoint: Codable {
    let timestamp: Date
    let bpm: Int
}

// MARK: - Sleep Analysis Results

/// Comprehensive sleep analysis with chronotype-aware scoring
struct SleepAnalysis {
    let session: SleepSession
    let chronotype: Chronotype

    // Scores (0-100)
    let overallScore: Int
    let architectureScore: Int       // Stage composition quality
    let timingScore: Int             // Circadian alignment
    let continuityScore: Int         // Sleep fragmentation
    let durationScore: Int           // Adequate duration
    let recoveryScore: Int           // HRV/HR restoration

    // Insights
    let insights: [SleepInsight]
    let recommendations: [SleepRecommendation]

    // Alignment metrics
    let bedtimeDeviation: TimeInterval    // Minutes from optimal
    let wakeTimeDeviation: TimeInterval
    let isWithinOptimalWindow: Bool

    // Architecture analysis
    let deepSleepQuality: SleepQualityRating
    let remQuality: SleepQualityRating
    let lightSleepQuality: SleepQualityRating

    // Trends (compared to 7-day average)
    let deepSleepTrend: TrendDirection
    let remTrend: TrendDirection
    let efficiencyTrend: TrendDirection
    let scoreTrend: TrendDirection

    var gradeLabel: String {
        switch overallScore {
        case 90...100: return "Excellent"
        case 80..<90: return "Very Good"
        case 70..<80: return "Good"
        case 60..<70: return "Fair"
        case 50..<60: return "Poor"
        default: return "Needs Work"
        }
    }

    var gradeColor: Color {
        switch overallScore {
        case 90...100: return .green
        case 80..<90: return .mint
        case 70..<80: return .cyan
        case 60..<70: return .yellow
        case 50..<60: return .orange
        default: return .red
        }
    }
}

enum SleepQualityRating: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case low = "Low"
    case veryLow = "Very Low"

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .mint
        case .fair: return .yellow
        case .low: return .orange
        case .veryLow: return .red
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "hand.thumbsup.fill"
        case .fair: return "minus.circle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .veryLow: return "xmark.circle.fill"
        }
    }
}

enum TrendDirection {
    case improving
    case stable
    case declining

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .gray
        case .declining: return .red
        }
    }
}

// MARK: - Insights & Recommendations

struct SleepInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let severity: InsightSeverity
    let relatedMetric: String?

    enum InsightType {
        case positive       // Something good
        case neutral        // Observation
        case actionable     // Something to improve
        case warning        // Something concerning
    }

    enum InsightSeverity {
        case low, medium, high
    }

    var icon: String {
        switch type {
        case .positive: return "checkmark.circle.fill"
        case .neutral: return "info.circle.fill"
        case .actionable: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch type {
        case .positive: return .green
        case .neutral: return .blue
        case .actionable: return .orange
        case .warning: return .red
        }
    }
}

struct SleepRecommendation: Identifiable {
    let id = UUID()
    let category: RecommendationCategory
    let title: String
    let description: String
    let priority: Int  // 1 = highest
    let actionType: ActionType

    enum RecommendationCategory: String {
        case timing = "Timing"
        case environment = "Environment"
        case habits = "Habits"
        case recovery = "Recovery"
        case chronotype = "Chronotype"
    }

    enum ActionType {
        case schedule      // Change bedtime/wake time
        case behavior      // Change daily habits
        case environment   // Change sleep environment
        case medical       // Consider medical consultation
    }

    var icon: String {
        switch category {
        case .timing: return "clock.fill"
        case .environment: return "bed.double.fill"
        case .habits: return "figure.walk"
        case .recovery: return "heart.fill"
        case .chronotype: return "sun.and.horizon.fill"
        }
    }
}

// MARK: - Sleep Debt & Recovery

struct SleepDebt {
    let currentDebtHours: Double      // Accumulated sleep debt
    let weeklyAverage: Double         // Hours per night this week
    let idealWeeklyTotal: Double      // Based on chronotype
    let daysToRecover: Int            // At 30min extra per night
    let recoveryProgress: Double      // 0-1 if paying back debt

    var debtLevel: DebtLevel {
        switch currentDebtHours {
        case ..<2: return .minimal
        case 2..<5: return .moderate
        case 5..<10: return .significant
        default: return .severe
        }
    }

    enum DebtLevel {
        case minimal, moderate, significant, severe

        var description: String {
            switch self {
            case .minimal: return "Well Rested"
            case .moderate: return "Slight Debt"
            case .significant: return "Sleep Debt"
            case .severe: return "Severe Debt"
            }
        }

        var color: Color {
            switch self {
            case .minimal: return .green
            case .moderate: return .yellow
            case .significant: return .orange
            case .severe: return .red
            }
        }
    }
}

// MARK: - Social Jetlag

struct SocialJetlag {
    let weekdayMidpoint: Date     // Average midpoint of sleep on weekdays
    let weekendMidpoint: Date     // Average midpoint on weekends
    let jetlagHours: Double       // Difference in hours

    var severity: JetlagSeverity {
        switch abs(jetlagHours) {
        case ..<1: return .none
        case 1..<2: return .mild
        case 2..<3: return .moderate
        default: return .severe
        }
    }

    enum JetlagSeverity: String {
        case none = "None"
        case mild = "Mild"
        case moderate = "Moderate"
        case severe = "Severe"

        var color: Color {
            switch self {
            case .none: return .green
            case .mild: return .yellow
            case .moderate: return .orange
            case .severe: return .red
            }
        }
    }
}

// MARK: - Optimal Sleep Windows

struct OptimalSleepWindow {
    let chronotype: Chronotype
    let bedtimeStart: Date
    let bedtimeEnd: Date
    let wakeTimeStart: Date
    let wakeTimeEnd: Date
    let peakProductivityStart: Date
    let peakProductivityEnd: Date

    /// How many minutes the user's actual bedtime differs from optimal
    func bedtimeDeviation(from actualBedtime: Date) -> TimeInterval {
        let calendar = Calendar.current
        let actualHour = calendar.component(.hour, from: actualBedtime)
        let actualMinute = calendar.component(.minute, from: actualBedtime)
        let actualTimeValue = Double(actualHour) + Double(actualMinute) / 60.0

        let optimalMidpoint = (chronotype.optimalBedtimeStart + chronotype.optimalBedtimeEnd) / 2

        // Handle midnight crossing
        var deviation = actualTimeValue - optimalMidpoint
        if deviation > 12 { deviation -= 24 }
        if deviation < -12 { deviation += 24 }

        return deviation * 3600  // Convert to seconds
    }

    var formattedBedtimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: bedtimeStart)) - \(formatter.string(from: bedtimeEnd))"
    }

    var formattedWakeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: wakeTimeStart)) - \(formatter.string(from: wakeTimeEnd))"
    }
}

// MARK: - Week Summary

struct WeeklySleepSummary {
    let sessions: [SleepSession]
    let chronotype: Chronotype
    let averageScore: Int
    let averageDuration: Double
    let averageEfficiency: Double
    let averageDeepPercent: Double
    let averageREMPercent: Double
    let bestNight: SleepSession?
    let worstNight: SleepSession?
    let sleepDebt: SleepDebt
    let socialJetlag: SocialJetlag
    let consistencyScore: Int         // How consistent bedtime/wake times were
    let overallTrend: TrendDirection

    var nightsTracked: Int { sessions.count }

    var chronotypeAlignment: Double {
        // How well the week's sleep aligned with chronotype
        guard !sessions.isEmpty else { return 0 }
        // Calculate based on bedtime deviations
        return 0.75 // Placeholder
    }
}
