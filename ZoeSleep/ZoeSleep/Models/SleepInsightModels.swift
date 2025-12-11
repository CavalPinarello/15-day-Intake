//
//  SleepInsightModels.swift
//  Zoe Sleep for Longevity System
//
//  Models for sleep insights and analytics
//

import Foundation

// MARK: - Sleep Data Models

/// Subjective sleep data from Sleep Log questionnaire
struct SubjectiveSleepData: Codable, Equatable {
    let quality: Double  // 1-10 rating
    let date: String?
}

/// Objective sleep data from HealthKit
struct ObjectiveSleepData: Codable, Equatable {
    let totalSleepMins: Int
    let efficiency: Double
    let deepSleepMins: Int?
    let remSleepMins: Int?
    let lightSleepMins: Int?
    let date: String?
}

/// Perception gap analysis result
struct PerceptionGap: Codable, Equatable {
    let gap: Double
    let direction: String  // "underestimate", "overestimate", "accurate"
    let magnitude: Double
}

/// Trend analysis for perception gaps
struct PerceptionGapTrend: Codable, Equatable {
    let avgGap: Double
    let consistentUnderestimate: Bool
    let confidence: Double
}

/// Workday vs weekend sleep pattern comparison
struct WorkdayWeekendPattern: Codable, Equatable {
    let workdayAvgSleep: Double
    let weekendAvgSleep: Double
    let workdayAvgDeep: Double
    let weekendAvgDeep: Double
    let workdayAvgEfficiency: Double
    let weekendAvgEfficiency: Double
    let sleepDifference: Double
    let deepDifference: Double
}

/// Optimal bedtime analysis
struct OptimalBedtime: Codable, Equatable {
    let time: String
    let avgLatencyMinutes: Double
    let latencyDiff: Double
    let confidence: Double
}

/// Sleep stage distribution patterns
struct SleepStagePatterns: Codable, Equatable {
    let avgDeepPercent: Double
    let avgRemPercent: Double
    let avgLightPercent: Double
    let deepBelowRecommended: Bool
    let remBelowRecommended: Bool
}

// MARK: - Sleep Insight Model

/// Individual actionable insight
struct SleepInsight: Identifiable, Codable, Equatable {
    let id: String
    let type: String           // optimization, pattern, cognitive, positive, warning
    let title: String
    let text: String
    let confidence: Double     // 0.0 - 1.0
    let actionable: Bool

    init(id: String, type: String, title: String, text: String, confidence: Double, actionable: Bool = false) {
        self.id = id
        self.type = type
        self.title = title
        self.text = text
        self.confidence = confidence
        self.actionable = actionable
    }
}

// MARK: - Insight Types

enum InsightType: String, CaseIterable {
    case optimization = "optimization"
    case pattern = "pattern"
    case cognitive = "cognitive"
    case positive = "positive"
    case warning = "warning"
}

// MARK: - Chart Data Models

/// Daily comparison data point for charts
struct DailyComparison: Identifiable, Equatable {
    let id = UUID()
    let date: String
    let subjectiveScore: Double  // Normalized 0-100
    let objectiveScore: Double   // Normalized 0-100

    static func == (lhs: DailyComparison, rhs: DailyComparison) -> Bool {
        lhs.date == rhs.date &&
        lhs.subjectiveScore == rhs.subjectiveScore &&
        lhs.objectiveScore == rhs.objectiveScore
    }
}

/// Weekly average summary
struct WeeklyAverage: Codable, Equatable {
    let sleepMins: Int
    let efficiency: Int
    let deepMins: Int
    let remMins: Int
}

/// Last night's sleep summary
struct LastNightSleep: Codable, Equatable {
    let date: String
    let totalSleepMins: Int?
    let efficiency: Double?
    let deepMins: Int?
    let remMins: Int?
    let primarySource: String?
}
