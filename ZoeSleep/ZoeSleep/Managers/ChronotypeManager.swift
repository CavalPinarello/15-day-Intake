//
//  ChronotypeManager.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Analyzes sleep patterns to determine chronotype (Early Riser/Balanced/Night Owl/Adaptive)
//  and calculate usual sleep midpoint.
//

import Foundation
import SwiftUI

// MARK: - Chronotype Enum

enum Chronotype: String, CaseIterable, Codable {
    case earlyRiser = "early_riser"
    case balanced = "balanced"
    case nightOwl = "night_owl"
    case adaptive = "adaptive"

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
        case .earlyRiser: return "🌅"
        case .balanced: return "⚖️"
        case .nightOwl: return "🦉"
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

    var color: Color {
        switch self {
        case .earlyRiser: return .orange
        case .balanced: return Color(red: 0.3, green: 0.7, blue: 0.6) // Teal
        case .nightOwl: return .purple
        case .adaptive: return .gray
        }
    }

    /// Optimal bedtime start (24-hour format)
    var optimalBedtimeStart: Double {
        switch self {
        case .earlyRiser: return 21.0    // 9:00 PM
        case .balanced: return 22.0      // 10:00 PM
        case .nightOwl: return 23.5      // 11:30 PM
        case .adaptive: return 23.0      // 11:00 PM
        }
    }

    /// Optimal wake time
    var optimalWakeTime: Double {
        switch self {
        case .earlyRiser: return 5.5     // 5:30 AM
        case .balanced: return 7.0       // 7:00 AM
        case .nightOwl: return 7.5       // 7:30 AM
        case .adaptive: return 6.5       // 6:30 AM
        }
    }
}

// MARK: - Chronotype Result

struct ChronotypeResult: Codable {
    var chronotype: String              // early_riser, balanced, night_owl, adaptive
    var avgSleepMidpoint: Double        // Hours (e.g., 3.5 = 3:30 AM)
    var avgBedtime: Double              // Hours (e.g., 23.0 = 11:00 PM)
    var avgWakeTime: Double             // Hours (e.g., 7.0 = 7:00 AM)
    var daysAnalyzed: Int
    var confidence: Double              // 0-1 based on data consistency
    var assessedAt: Date

    var chronotypeEnum: Chronotype {
        Chronotype(rawValue: chronotype) ?? .balanced
    }

    var displayName: String {
        chronotypeEnum.displayName
    }

    var emoji: String {
        chronotypeEnum.emoji
    }
}

// MARK: - Chronotype Manager

@MainActor
class ChronotypeManager: ObservableObject {
    static let shared = ChronotypeManager()

    @Published var result: ChronotypeResult?
    @Published var isAnalyzing = false
    @Published var analysisProgress: String = ""
    @Published var nightsFound: Int = 0

    private let userDefaultsKey = "chronotypeResult"
    private let minimumNightsRequired = 90

    private init() {
        loadSavedResult()
    }

    // MARK: - Persistence

    private func loadSavedResult() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode(ChronotypeResult.self, from: data) {
            result = saved
            print("[Chronotype] Loaded saved result: \(saved.chronotype), midpoint: \(formatMidpointTime(saved.avgSleepMidpoint))")
        }
    }

    func saveResult(_ newResult: ChronotypeResult) {
        result = newResult
        if let encoded = try? JSONEncoder().encode(newResult) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
        print("[Chronotype] Saved result: \(newResult.chronotype), midpoint: \(formatMidpointTime(newResult.avgSleepMidpoint))")
    }

    // MARK: - Analysis

    /// Analyze sleep data from HealthKit to determine chronotype
    /// Returns nil if insufficient data (< 90 days)
    func analyzeFromSleepData(_ sleepData: [[String: Any]]) -> ChronotypeResult? {
        guard !sleepData.isEmpty else {
            print("[Chronotype] No sleep data to analyze")
            return nil
        }

        nightsFound = sleepData.count
        print("[Chronotype] Analyzing \(sleepData.count) nights of sleep data")

        // Check minimum data requirement
        guard sleepData.count >= minimumNightsRequired else {
            print("[Chronotype] Insufficient data: \(sleepData.count) < \(minimumNightsRequired) nights required")
            return nil
        }

        // Extract sleep times
        var bedtimeHours: [Double] = []
        var wakeTimeHours: [Double] = []
        var midpointHours: [Double] = []

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for night in sleepData {
            guard let asleepTimeStr = night["asleep_time"] as? String,
                  let wakeTimeStr = night["wake_time"] as? String,
                  let asleepDate = isoFormatter.date(from: asleepTimeStr),
                  let wakeDate = isoFormatter.date(from: wakeTimeStr) else {
                continue
            }

            let calendar = Calendar.current

            // Calculate bedtime hour (normalized around midnight)
            var bedHour = Double(calendar.component(.hour, from: asleepDate))
            let bedMinute = Double(calendar.component(.minute, from: asleepDate))
            bedHour += bedMinute / 60.0
            if bedHour < 12 { bedHour += 24 }  // Normalize: 1 AM -> 25, 11 PM -> 23
            bedtimeHours.append(bedHour)

            // Calculate wake time hour
            var wakeHour = Double(calendar.component(.hour, from: wakeDate))
            let wakeMinute = Double(calendar.component(.minute, from: wakeDate))
            wakeHour += wakeMinute / 60.0
            wakeTimeHours.append(wakeHour)

            // Calculate midpoint
            var midpoint = (bedHour + wakeHour) / 2
            if midpoint > 24 { midpoint -= 24 }
            midpointHours.append(midpoint)
        }

        guard !bedtimeHours.isEmpty else {
            print("[Chronotype] No valid sleep entries found")
            return nil
        }

        // Calculate averages
        let avgBedtime = bedtimeHours.reduce(0, +) / Double(bedtimeHours.count)
        let avgWakeTime = wakeTimeHours.reduce(0, +) / Double(wakeTimeHours.count)
        let avgMidpoint = midpointHours.reduce(0, +) / Double(midpointHours.count)

        // Calculate variability (std dev)
        let bedtimeStdDev = standardDeviation(bedtimeHours)
        let midpointStdDev = standardDeviation(midpointHours)

        print("[Chronotype] Avg bedtime: \(formatHourAsTime(avgBedtime)), avg wake: \(formatHourAsTime(avgWakeTime)), avg midpoint: \(formatMidpointTime(avgMidpoint))")
        print("[Chronotype] Bedtime std dev: \(String(format: "%.2f", bedtimeStdDev))h, midpoint std dev: \(String(format: "%.2f", midpointStdDev))h")

        // Determine chronotype based on midpoint and variability
        let (chronotype, confidence) = classifyChronotype(
            avgMidpoint: avgMidpoint,
            avgBedtime: avgBedtime,
            avgWakeTime: avgWakeTime,
            bedtimeStdDev: bedtimeStdDev,
            midpointStdDev: midpointStdDev,
            nightCount: sleepData.count
        )

        let newResult = ChronotypeResult(
            chronotype: chronotype.rawValue,
            avgSleepMidpoint: avgMidpoint,
            avgBedtime: avgBedtime > 24 ? avgBedtime - 24 : avgBedtime,  // Convert back to 0-24 range
            avgWakeTime: avgWakeTime,
            daysAnalyzed: sleepData.count,
            confidence: confidence,
            assessedAt: Date()
        )

        saveResult(newResult)
        return newResult
    }

    // MARK: - Classification

    private func classifyChronotype(
        avgMidpoint: Double,
        avgBedtime: Double,
        avgWakeTime: Double,
        bedtimeStdDev: Double,
        midpointStdDev: Double,
        nightCount: Int
    ) -> (Chronotype, Double) {

        // High variability = Adaptive type
        if bedtimeStdDev > 1.5 || midpointStdDev > 1.0 {
            let confidence = min(1.0, Double(nightCount) / 90.0) * 0.7
            print("[Chronotype] Classified as ADAPTIVE due to high variability")
            return (.adaptive, confidence)
        }

        // Score each chronotype based on midpoint using Gaussian scoring
        var scores: [Chronotype: Double] = [:]

        // Early Riser: midpoint ~1.5-2.5 AM
        scores[.earlyRiser] = gaussianScore(avgMidpoint, mean: 2.0, stdDev: 0.75)

        // Balanced: midpoint ~3.0-3.5 AM
        scores[.balanced] = gaussianScore(avgMidpoint, mean: 3.25, stdDev: 0.75)

        // Night Owl: midpoint ~4.0-5.0 AM
        scores[.nightOwl] = gaussianScore(avgMidpoint, mean: 4.5, stdDev: 0.75)

        // Find winner
        let sorted = scores.sorted { $0.value > $1.value }
        let winner = sorted[0]

        // Calculate confidence based on data amount and pattern clarity
        let dataConfidence = min(1.0, Double(nightCount) / 90.0)
        let patternClarity = winner.value
        let confidence = (dataConfidence * 0.4 + patternClarity * 0.6)

        print("[Chronotype] Scores - Early: \(String(format: "%.2f", scores[.earlyRiser] ?? 0)), Balanced: \(String(format: "%.2f", scores[.balanced] ?? 0)), Night Owl: \(String(format: "%.2f", scores[.nightOwl] ?? 0))")
        print("[Chronotype] Classified as \(winner.key.displayName) with confidence \(String(format: "%.2f", confidence))")

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

    /// Format hours as time string (e.g., 3.5 -> "3:30 AM")
    func formatMidpointTime(_ hours: Double) -> String {
        var h = hours
        if h >= 24 { h -= 24 }
        if h < 0 { h += 24 }

        let wholeHour = Int(h)
        let minutes = Int((h - Double(wholeHour)) * 60)
        let displayHour = wholeHour == 0 ? 12 : (wholeHour > 12 ? wholeHour - 12 : wholeHour)
        let amPm = wholeHour < 12 ? "AM" : "PM"

        return String(format: "%d:%02d %@", displayHour, minutes, amPm)
    }

    /// Format hours as time (handling overnight normalization)
    private func formatHourAsTime(_ hours: Double) -> String {
        var h = hours
        if h >= 24 { h -= 24 }
        return formatMidpointTime(h)
    }

    // MARK: - Display Helpers

    var hasEnoughData: Bool {
        nightsFound >= minimumNightsRequired
    }

    var dataStatusMessage: String {
        if nightsFound == 0 {
            return "No sleep data found"
        } else if nightsFound < minimumNightsRequired {
            return "We found \(nightsFound) nights of data. We need \(minimumNightsRequired) nights to accurately determine your chronotype. We'll estimate it as you use the app over the coming weeks."
        } else {
            return "Analyzed \(nightsFound) nights of sleep data"
        }
    }
}
