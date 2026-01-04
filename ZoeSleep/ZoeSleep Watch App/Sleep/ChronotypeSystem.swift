//
//  ChronotypeSystem.swift
//  ZoeSleep Watch App
//
//  Determines and manages user's chronotype (Early Riser/Balanced/Night Owl/Adaptive).
//  Uses MEQ (Morningness-Eveningness Questionnaire) principles.
//

import Foundation
import SwiftUI

// MARK: - Chronotype Determination

/// Determines user's chronotype from questionnaire or sleep pattern analysis
@MainActor
class ChronotypeManager: ObservableObject {
    static let shared = ChronotypeManager()

    @Published var chronotype: Chronotype = .balanced  // Default to most common
    @Published var confidence: Double = 0.0        // 0-1 confidence in determination
    @Published var isAssessed: Bool = false
    @Published var assessmentDate: Date?

    private let userDefaultsKey = "userChronotype"
    private let confidenceKey = "chronotypeConfidence"
    private let assessmentDateKey = "chronotypeAssessmentDate"

    private init() {
        loadSavedChronotype()
    }

    // MARK: - Persistence

    private func loadSavedChronotype() {
        if let savedType = UserDefaults.standard.string(forKey: userDefaultsKey),
           let type = Chronotype(rawValue: savedType) {
            chronotype = type
            confidence = UserDefaults.standard.double(forKey: confidenceKey)
            assessmentDate = UserDefaults.standard.object(forKey: assessmentDateKey) as? Date
            isAssessed = true
        }
    }

    func saveChronotype(_ type: Chronotype, confidence: Double) {
        self.chronotype = type
        self.confidence = confidence
        self.isAssessed = true
        self.assessmentDate = Date()

        UserDefaults.standard.set(type.rawValue, forKey: userDefaultsKey)
        UserDefaults.standard.set(confidence, forKey: confidenceKey)
        UserDefaults.standard.set(Date(), forKey: assessmentDateKey)
    }

    // MARK: - Questionnaire-Based Assessment

    /// MEQ-inspired questions for chronotype determination
    struct ChronotypeQuestion: Identifiable {
        let id: Int
        let question: String
        let options: [ChronotypeOption]
    }

    struct ChronotypeOption {
        let text: String
        let scores: [Chronotype: Int]  // How much this answer suggests each type
    }

    /// 5-question chronotype quiz based on MEQ principles
    /// Each type can score max 25 points for balanced scoring
    static let assessmentQuestions: [ChronotypeQuestion] = [
        ChronotypeQuestion(
            id: 1,
            question: "If free to choose, when would you wake up?",
            options: [
                ChronotypeOption(text: "5:00-6:30 AM", scores: [.earlyRiser: 5, .balanced: 1, .nightOwl: 0]),
                ChronotypeOption(text: "6:30-7:45 AM", scores: [.earlyRiser: 3, .balanced: 4, .nightOwl: 1]),
                ChronotypeOption(text: "7:45-9:30 AM", scores: [.earlyRiser: 1, .balanced: 4, .nightOwl: 3]),
                ChronotypeOption(text: "9:30-11:00 AM", scores: [.earlyRiser: 0, .balanced: 1, .nightOwl: 5]),
                ChronotypeOption(text: "After 11:00 AM", scores: [.earlyRiser: 0, .balanced: 0, .nightOwl: 5]),
            ]
        ),
        ChronotypeQuestion(
            id: 2,
            question: "If free to choose, when would you go to bed?",
            options: [
                ChronotypeOption(text: "8:00-9:30 PM", scores: [.earlyRiser: 5, .balanced: 1, .nightOwl: 0]),
                ChronotypeOption(text: "9:30-10:30 PM", scores: [.earlyRiser: 3, .balanced: 4, .nightOwl: 1]),
                ChronotypeOption(text: "10:30 PM-12:00 AM", scores: [.earlyRiser: 1, .balanced: 4, .nightOwl: 3]),
                ChronotypeOption(text: "12:00-1:30 AM", scores: [.earlyRiser: 0, .balanced: 1, .nightOwl: 5]),
                ChronotypeOption(text: "After 1:30 AM", scores: [.earlyRiser: 0, .balanced: 0, .nightOwl: 5]),
            ]
        ),
        ChronotypeQuestion(
            id: 3,
            question: "How alert do you feel in the first 30 minutes after waking?",
            options: [
                ChronotypeOption(text: "Very alert", scores: [.earlyRiser: 5, .balanced: 2, .nightOwl: 0]),
                ChronotypeOption(text: "Fairly alert", scores: [.earlyRiser: 2, .balanced: 5, .nightOwl: 2]),
                ChronotypeOption(text: "Fairly tired", scores: [.earlyRiser: 0, .balanced: 2, .nightOwl: 5]),
                ChronotypeOption(text: "Very tired", scores: [.earlyRiser: 0, .balanced: 0, .nightOwl: 5]),
            ]
        ),
        ChronotypeQuestion(
            id: 4,
            question: "When do you feel mentally at your best?",
            options: [
                ChronotypeOption(text: "Morning (8-10 AM)", scores: [.earlyRiser: 5, .balanced: 1, .nightOwl: 0]),
                ChronotypeOption(text: "Late morning (10-12)", scores: [.earlyRiser: 2, .balanced: 5, .nightOwl: 1]),
                ChronotypeOption(text: "Afternoon (12-5 PM)", scores: [.earlyRiser: 0, .balanced: 5, .nightOwl: 2]),
                ChronotypeOption(text: "Evening (5-9 PM)", scores: [.earlyRiser: 0, .balanced: 1, .nightOwl: 5]),
                ChronotypeOption(text: "Night (after 9 PM)", scores: [.earlyRiser: 0, .balanced: 0, .nightOwl: 5]),
            ]
        ),
        ChronotypeQuestion(
            id: 5,
            question: "Are you a morning person or an evening person?",
            options: [
                ChronotypeOption(text: "Definitely morning", scores: [.earlyRiser: 5, .balanced: 0, .nightOwl: 0]),
                ChronotypeOption(text: "More morning", scores: [.earlyRiser: 3, .balanced: 3, .nightOwl: 0]),
                ChronotypeOption(text: "More evening", scores: [.earlyRiser: 0, .balanced: 3, .nightOwl: 3]),
                ChronotypeOption(text: "Definitely evening", scores: [.earlyRiser: 0, .balanced: 0, .nightOwl: 5]),
            ]
        ),
    ]

    /// Calculate chronotype from questionnaire responses
    func calculateChronotypeFromResponses(_ responses: [Int: Int]) -> (Chronotype, Double) {
        var scores: [Chronotype: Int] = [
            .earlyRiser: 0,
            .balanced: 0,
            .nightOwl: 0
        ]

        for (questionId, optionIndex) in responses {
            guard let question = Self.assessmentQuestions.first(where: { $0.id == questionId }),
                  optionIndex < question.options.count else { continue }

            let option = question.options[optionIndex]
            for (type, score) in option.scores {
                scores[type, default: 0] += score
            }
        }

        // Normalize scores (max 25 points per type with 5 questions)
        let maxPossible = Double(Self.assessmentQuestions.count * 5)
        let normalizedScores = scores.mapValues { Double($0) / maxPossible }

        // Find winner
        let sorted = normalizedScores.sorted { $0.value > $1.value }
        let winner = sorted[0]
        let runnerUp = sorted[1]

        // Calculate confidence based on margin between winner and runner-up
        let margin = winner.value - runnerUp.value
        let confidence: Double
        if margin > 0.25 {
            confidence = 0.95  // Clear winner
        } else if margin > 0.15 {
            confidence = 0.80  // Likely
        } else if margin > 0.08 {
            confidence = 0.65  // Probable
        } else {
            confidence = 0.50  // Close call
        }

        return (winner.key, confidence)
    }

    // MARK: - Pattern-Based Assessment

    /// Detect chronotype from actual sleep patterns (7+ days of data)
    func detectChronotypeFromPatterns(_ sessions: [SleepSession]) -> (Chronotype, Double) {
        guard sessions.count >= 7 else {
            return (.balanced, 0.5)  // Not enough data, default to balanced
        }

        let calendar = Calendar.current

        // Calculate average bedtime and wake time
        var bedtimeHours: [Double] = []
        var wakeTimeHours: [Double] = []

        for session in sessions {
            let bedHour = Double(calendar.component(.hour, from: session.bedtime))
            let bedMinute = Double(calendar.component(.minute, from: session.bedtime))
            var bedtimeValue = bedHour + bedMinute / 60.0
            if bedtimeValue < 12 { bedtimeValue += 24 }  // Handle past midnight
            bedtimeHours.append(bedtimeValue)

            let wakeHour = Double(calendar.component(.hour, from: session.wakeTime))
            let wakeMinute = Double(calendar.component(.minute, from: session.wakeTime))
            wakeTimeHours.append(wakeHour + wakeMinute / 60.0)
        }

        let avgBedtime = bedtimeHours.reduce(0, +) / Double(bedtimeHours.count)
        let avgWakeTime = wakeTimeHours.reduce(0, +) / Double(wakeTimeHours.count)

        // Calculate sleep midpoint (key indicator of chronotype)
        var midpoint = (avgBedtime + avgWakeTime + 24) / 2
        if midpoint > 24 { midpoint -= 24 }

        // Score each chronotype based on patterns
        var scores: [Chronotype: Double] = [:]

        // Early Riser: Early bedtime (21-22), early wake (5-6), midpoint around 1-2 AM
        let earlyBedScore = gaussianScore(avgBedtime, mean: 21.5, stdDev: 1.0)
        let earlyWakeScore = gaussianScore(avgWakeTime, mean: 5.5, stdDev: 1.0)
        let earlyMidScore = gaussianScore(midpoint, mean: 1.5, stdDev: 1.0)
        scores[.earlyRiser] = (earlyBedScore + earlyWakeScore + earlyMidScore) / 3

        // Balanced: Normal bedtime (22-23), normal wake (7), midpoint around 3 AM
        let balancedBedScore = gaussianScore(avgBedtime, mean: 22.5, stdDev: 1.0)
        let balancedWakeScore = gaussianScore(avgWakeTime, mean: 7.0, stdDev: 1.0)
        let balancedMidScore = gaussianScore(midpoint, mean: 3.0, stdDev: 1.0)
        scores[.balanced] = (balancedBedScore + balancedWakeScore + balancedMidScore) / 3

        // Night Owl: Late bedtime (23:30+), late wake (8+), midpoint around 4 AM
        let nightOwlBedScore = gaussianScore(avgBedtime, mean: 24.0, stdDev: 1.0)  // Midnight
        let nightOwlWakeScore = gaussianScore(avgWakeTime, mean: 8.0, stdDev: 1.0)
        let nightOwlMidScore = gaussianScore(midpoint, mean: 4.0, stdDev: 1.0)
        scores[.nightOwl] = (nightOwlBedScore + nightOwlWakeScore + nightOwlMidScore) / 3

        // Find winner and runner-up
        let sorted = scores.sorted { $0.value > $1.value }
        let winner = sorted[0]
        let runnerUp = sorted[1]

        // Confidence based on data amount and margin
        let dataConfidence = min(1.0, Double(sessions.count) / 14.0)
        let margin = winner.value - runnerUp.value
        let marginConfidence: Double
        if margin > 0.3 {
            marginConfidence = 0.95
        } else if margin > 0.2 {
            marginConfidence = 0.80
        } else if margin > 0.1 {
            marginConfidence = 0.65
        } else {
            marginConfidence = 0.50
        }

        let confidence = (dataConfidence + marginConfidence) / 2

        return (winner.key, confidence)
    }

    // MARK: - Helpers

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }

    private func gaussianScore(_ value: Double, mean: Double, stdDev: Double) -> Double {
        let exponent = -pow(value - mean, 2) / (2 * pow(stdDev, 2))
        return exp(exponent)
    }

    // MARK: - Optimal Sleep Window Calculation

    func getOptimalSleepWindow(for date: Date = Date()) -> OptimalSleepWindow {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        // Create optimal times based on chronotype
        func makeTime(hour: Double) -> Date {
            let wholeHour = Int(hour) % 24
            let minutes = Int((hour - Double(Int(hour))) * 60)
            var dayOffset = 0
            if hour >= 24 { dayOffset = 1 }
            let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            return calendar.date(bySettingHour: wholeHour, minute: minutes, second: 0, of: targetDay)!
        }

        let bedtimeStart = makeTime(hour: chronotype.optimalBedtimeStart)
        let bedtimeEnd = makeTime(hour: chronotype.optimalBedtimeEnd)
        let wakeStart = makeTime(hour: chronotype.optimalWakeTime - 0.5)
        let wakeEnd = makeTime(hour: chronotype.optimalWakeTime + 0.5)

        // Peak productivity varies by chronotype
        let peakStart: Date
        let peakEnd: Date
        switch chronotype {
        case .earlyRiser:
            peakStart = makeTime(hour: 8.0)
            peakEnd = makeTime(hour: 12.0)
        case .balanced:
            peakStart = makeTime(hour: 10.0)
            peakEnd = makeTime(hour: 14.0)
        case .nightOwl:
            peakStart = makeTime(hour: 17.0)
            peakEnd = makeTime(hour: 21.0)
        }

        return OptimalSleepWindow(
            chronotype: chronotype,
            bedtimeStart: bedtimeStart,
            bedtimeEnd: bedtimeEnd,
            wakeTimeStart: wakeStart,
            wakeTimeEnd: wakeEnd,
            peakProductivityStart: peakStart,
            peakProductivityEnd: peakEnd
        )
    }
}

// MARK: - Chronotype Profile Card Data

struct ChronotypeProfile {
    let chronotype: Chronotype
    let confidence: Double
    let assessmentMethod: AssessmentMethod

    enum AssessmentMethod {
        case questionnaire
        case patternDetection
        case combined
    }

    var strengthLabel: String {
        switch chronotype {
        case .earlyRiser: return "Early Morning Power"
        case .balanced: return "Balanced Energy"
        case .nightOwl: return "Evening Creativity"
        }
    }

    var tips: [String] {
        switch chronotype {
        case .earlyRiser:
            return [
                "Schedule important tasks before noon",
                "Protect your early bedtime",
                "Light exercise in early morning",
                "Avoid screens after 8 PM"
            ]
        case .balanced:
            return [
                "Follow the sun's natural cycle",
                "Most productive mid-morning",
                "Brief afternoon naps OK",
                "Consistent schedule is key"
            ]
        case .nightOwl:
            return [
                "Don't fight your late energy",
                "Morning light helps shift earlier",
                "Creative work in evening",
                "Avoid early morning meetings"
            ]
        }
    }
}
