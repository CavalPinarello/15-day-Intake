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

    /// Clear saved result to force re-analysis with updated algorithm
    func clearSavedResult() {
        result = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("[Chronotype] Cleared saved result - will re-analyze on next data fetch")
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

            // CRITICAL: Use the timezone where sleep was RECORDED, not device's current timezone
            // This fixes incorrect calculations for travelers (e.g., sleep in Europe viewed from California)
            var calendar = Calendar.current
            if let recordedTz = night["recorded_timezone"] as? String,
               !recordedTz.isEmpty,
               let timezone = TimeZone(identifier: recordedTz) {
                calendar.timeZone = timezone
            }

            // Calculate bedtime hour (normalized to "sleep night" scale: noon=12, midnight=24, 6AM=30)
            // This ensures times around midnight average correctly
            var bedHour = Double(calendar.component(.hour, from: asleepDate))
            let bedMinute = Double(calendar.component(.minute, from: asleepDate))
            bedHour += bedMinute / 60.0
            if bedHour < 12 { bedHour += 24 }  // Normalize: 1 AM -> 25, 11 PM -> 23
            bedtimeHours.append(bedHour)

            // Calculate wake time hour (also normalized to sleep night scale)
            var wakeHour = Double(calendar.component(.hour, from: wakeDate))
            let wakeMinute = Double(calendar.component(.minute, from: wakeDate))
            wakeHour += wakeMinute / 60.0
            if wakeHour < 12 { wakeHour += 24 }  // Normalize: 7 AM -> 31, keeping it in same scale as bedtime
            wakeTimeHours.append(wakeHour)

            // Calculate midpoint using actual Date objects (most accurate, avoids hour math issues)
            let sleepDuration = wakeDate.timeIntervalSince(asleepDate)
            let midpointDate = asleepDate.addingTimeInterval(sleepDuration / 2)
            var midpointHour = Double(calendar.component(.hour, from: midpointDate))
            let midpointMinute = Double(calendar.component(.minute, from: midpointDate))
            midpointHour += midpointMinute / 60.0
            // Normalize midpoint to sleep night scale for correct averaging
            if midpointHour < 12 { midpointHour += 24 }
            midpointHours.append(midpointHour)
        }

        guard !bedtimeHours.isEmpty else {
            print("[Chronotype] No valid sleep entries found")
            return nil
        }

        // Calculate averages (still in normalized "sleep night" scale)
        let avgBedtimeNorm = bedtimeHours.reduce(0, +) / Double(bedtimeHours.count)
        let avgWakeTimeNorm = wakeTimeHours.reduce(0, +) / Double(wakeTimeHours.count)
        let avgMidpointNorm = midpointHours.reduce(0, +) / Double(midpointHours.count)

        // Calculate variability (std dev)
        let bedtimeStdDev = standardDeviation(bedtimeHours)
        let midpointStdDev = standardDeviation(midpointHours)

        // Convert back to 0-24 range for storage and display
        let avgBedtime = normalizedToStandardHour(avgBedtimeNorm)
        let avgWakeTime = normalizedToStandardHour(avgWakeTimeNorm)
        let avgMidpoint = normalizedToStandardHour(avgMidpointNorm)

        print("[Chronotype] Avg bedtime: \(formatMidpointTime(avgBedtime)), avg wake: \(formatMidpointTime(avgWakeTime)), avg midpoint: \(formatMidpointTime(avgMidpoint))")
        print("[Chronotype] Bedtime std dev: \(String(format: "%.2f", bedtimeStdDev))h, midpoint std dev: \(String(format: "%.2f", midpointStdDev))h")

        // Determine chronotype based on midpoint and variability
        // Use normalized midpoint for classification (keeps the scale consistent for comparison)
        let (chronotype, confidence) = classifyChronotype(
            avgMidpointNorm: avgMidpointNorm,
            avgBedtimeNorm: avgBedtimeNorm,
            avgWakeTimeNorm: avgWakeTimeNorm,
            bedtimeStdDev: bedtimeStdDev,
            midpointStdDev: midpointStdDev,
            nightCount: sleepData.count
        )

        let newResult = ChronotypeResult(
            chronotype: chronotype.rawValue,
            avgSleepMidpoint: avgMidpoint,
            avgBedtime: avgBedtime,
            avgWakeTime: avgWakeTime,
            daysAnalyzed: sleepData.count,
            confidence: confidence,
            assessedAt: Date()
        )

        saveResult(newResult)
        return newResult
    }

    /// Convert normalized hour (noon=12, midnight=24, 6AM=30) back to standard 0-24 range
    private func normalizedToStandardHour(_ normalized: Double) -> Double {
        var hour = normalized
        while hour >= 24 { hour -= 24 }
        while hour < 0 { hour += 24 }
        return hour
    }

    // MARK: - Classification

    /// Classify chronotype based on normalized sleep midpoint
    /// Normalized scale: noon=12, midnight=24, 1 AM=25, 6 AM=30
    private func classifyChronotype(
        avgMidpointNorm: Double,
        avgBedtimeNorm: Double,
        avgWakeTimeNorm: Double,
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
        // Using normalized scale where midnight=24, 1 AM=25, etc.
        var scores: [Chronotype: Double] = [:]

        // Early Riser: midpoint ~1.5-2.5 AM → normalized 25.5-26.5
        scores[.earlyRiser] = gaussianScore(avgMidpointNorm, mean: 26.0, stdDev: 0.75)

        // Balanced: midpoint ~3.0-3.5 AM → normalized 27-27.5
        scores[.balanced] = gaussianScore(avgMidpointNorm, mean: 27.25, stdDev: 0.75)

        // Night Owl: midpoint ~4.0-5.0 AM → normalized 28-29
        scores[.nightOwl] = gaussianScore(avgMidpointNorm, mean: 28.5, stdDev: 0.75)

        // Find winner
        let sorted = scores.sorted { $0.value > $1.value }
        let winner = sorted[0]

        // Calculate confidence based on data amount and pattern clarity
        let dataConfidence = min(1.0, Double(nightCount) / 90.0)
        let patternClarity = winner.value
        let confidence = (dataConfidence * 0.4 + patternClarity * 0.6)

        // Convert normalized midpoint to display time for logging
        let displayMidpoint = normalizedToStandardHour(avgMidpointNorm)
        print("[Chronotype] Midpoint \(formatMidpointTime(displayMidpoint)) (norm: \(String(format: "%.2f", avgMidpointNorm)))")
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

    // MARK: - Location Epoch Detection (for Travel History)

    /// A period of time where the user was consistently in one timezone region
    struct LocationEpoch: Identifiable {
        let id = UUID()
        let startDate: Date
        let endDate: Date
        let inferredTimezone: String      // IANA identifier or UTC offset description
        let avgUtcBedtimeHour: Double     // Average bedtime in UTC (for detection)
        let nightCount: Int
        let isJetLagged: Bool             // First 3 nights after a shift

        var displayName: String {
            // Convert "America/Los_Angeles" to "Los Angeles" or show UTC offset
            if inferredTimezone.contains("/") {
                return inferredTimezone.split(separator: "/").last.map(String.init) ?? inferredTimezone
            }
            return inferredTimezone
        }

        var dateRange: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }

    /// Published travel history for debug view
    @Published var detectedEpochs: [LocationEpoch] = []
    @Published var isAnalyzingTravel = false

    /// Internal struct for tracking night data during epoch detection
    private struct NightData {
        let date: Date
        let utcBedtimeHour: Double
        let recordedTimezone: String?
    }

    /// Detect location epochs from sleep data by finding UTC bedtime shifts
    /// Works by detecting >4 hour shifts in UTC sleep times, which indicate travel
    func detectLocationEpochs(from sleepData: [[String: Any]]) -> [LocationEpoch] {
        guard !sleepData.isEmpty else { return [] }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Step 1: Extract UTC bedtime hour for each night
        var nights: [NightData] = []

        for night in sleepData {
            guard let asleepTimeStr = night["asleep_time"] as? String,
                  let asleepDate = isoFormatter.date(from: asleepTimeStr) else {
                continue
            }

            // Get UTC hour (use UTC timezone, not device timezone)
            var utcCalendar = Calendar.current
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!
            let utcHour = Double(utcCalendar.component(.hour, from: asleepDate))
            let utcMinute = Double(utcCalendar.component(.minute, from: asleepDate))
            let utcBedtimeHour = utcHour + utcMinute / 60.0

            let recordedTz = night["recorded_timezone"] as? String

            nights.append(NightData(
                date: asleepDate,
                utcBedtimeHour: utcBedtimeHour,
                recordedTimezone: recordedTz
            ))
        }

        // Sort chronologically
        nights.sort { $0.date < $1.date }

        guard !nights.isEmpty else { return [] }

        // Step 2: Detect shifts and group into epochs
        var epochs: [LocationEpoch] = []
        var currentEpochStart = nights[0].date
        var currentEpochNights: [NightData] = [nights[0]]
        var previousUtcHour = nights[0].utcBedtimeHour

        for i in 1..<nights.count {
            let night = nights[i]
            let shift = abs(night.utcBedtimeHour - previousUtcHour)

            // Handle wrap-around (e.g., 23:00 to 01:00 is only 2 hours, not 22)
            let normalizedShift = min(shift, 24 - shift)

            if normalizedShift > 4 {
                // Detected a timezone shift - close current epoch
                if !currentEpochNights.isEmpty {
                    let epoch = createEpoch(from: currentEpochNights, startDate: currentEpochStart, isJetLagged: false)
                    epochs.append(epoch)
                }

                // Start new epoch
                currentEpochStart = night.date
                currentEpochNights = [night]
            } else {
                // Same timezone region - add to current epoch
                currentEpochNights.append(night)
            }

            previousUtcHour = night.utcBedtimeHour
        }

        // Close final epoch
        if !currentEpochNights.isEmpty {
            let epoch = createEpoch(from: currentEpochNights, startDate: currentEpochStart, isJetLagged: false)
            epochs.append(epoch)
        }

        // Step 3: Mark first 3 nights of each epoch (after the first) as jet-lagged
        var finalEpochs: [LocationEpoch] = []
        for (index, epoch) in epochs.enumerated() {
            if index == 0 {
                // First epoch - no jet lag (we don't know if they traveled before our data)
                finalEpochs.append(epoch)
            } else if epoch.nightCount <= 3 {
                // Short epoch - mark entire thing as jet lag transition
                let jetLagEpoch = LocationEpoch(
                    startDate: epoch.startDate,
                    endDate: epoch.endDate,
                    inferredTimezone: epoch.inferredTimezone,
                    avgUtcBedtimeHour: epoch.avgUtcBedtimeHour,
                    nightCount: epoch.nightCount,
                    isJetLagged: true
                )
                finalEpochs.append(jetLagEpoch)
            } else {
                // Longer epoch - split into jet lag portion and stable portion
                // (In a more sophisticated implementation, we'd actually split the nights)
                finalEpochs.append(epoch)
            }
        }

        detectedEpochs = finalEpochs
        return finalEpochs
    }

    /// Create a LocationEpoch from a group of nights
    private func createEpoch(from nights: [NightData], startDate: Date, isJetLagged: Bool) -> LocationEpoch {
        guard !nights.isEmpty else {
            return LocationEpoch(
                startDate: startDate,
                endDate: startDate,
                inferredTimezone: "Unknown",
                avgUtcBedtimeHour: 0,
                nightCount: 0,
                isJetLagged: isJetLagged
            )
        }

        // Calculate average UTC bedtime and find end date
        let totalUtcHour = nights.reduce(0.0) { $0 + $1.utcBedtimeHour }
        let avgUtcHour = totalUtcHour / Double(nights.count)
        let endDate = nights.max(by: { $0.date < $1.date })?.date ?? startDate

        // Use recorded timezone if available, otherwise infer from UTC bedtime
        let inferredTz = nights.first(where: { $0.recordedTimezone != nil && !($0.recordedTimezone?.isEmpty ?? true) })?.recordedTimezone
        let timezone = inferredTz ?? inferTimezone(fromUtcBedtimeHour: avgUtcHour)

        return LocationEpoch(
            startDate: startDate,
            endDate: endDate,
            inferredTimezone: timezone,
            avgUtcBedtimeHour: avgUtcHour,
            nightCount: nights.count,
            isJetLagged: isJetLagged
        )
    }

    /// Infer timezone from UTC bedtime hour
    /// Assumes people sleep in the 9 PM - 3 AM local window
    private func inferTimezone(fromUtcBedtimeHour utcHour: Double) -> String {
        // Find offset that places UTC hour within 21:00-03:00 local range
        // This covers early risers (9 PM) to night owls (3 AM)

        // Target: 23:00 local (11 PM) as typical bedtime
        let targetLocalHour = 23.0
        var offsetHours = Int(targetLocalHour - utcHour)

        // Normalize to -12 to +12 range
        while offsetHours > 12 { offsetHours -= 24 }
        while offsetHours < -12 { offsetHours += 24 }

        // Return as UTC offset string
        let sign = offsetHours >= 0 ? "+" : ""
        return "UTC\(sign)\(offsetHours)"
    }

    /// Analyze travel history from 1 year of HealthKit data
    func analyzeTravel(from sleepData: [[String: Any]]) {
        isAnalyzingTravel = true

        // Run detection
        let epochs = detectLocationEpochs(from: sleepData)

        isAnalyzingTravel = false

        // Log summary
        let stableNights = epochs.filter { !$0.isJetLagged }.reduce(0) { $0 + $1.nightCount }
        let jetLagNights = epochs.filter { $0.isJetLagged }.reduce(0) { $0 + $1.nightCount }
        let uniqueLocations = Set(epochs.map { $0.inferredTimezone }).count

        print("[Chronotype] Travel analysis complete:")
        print("  - \(epochs.count) location epochs detected")
        print("  - \(uniqueLocations) unique timezone regions")
        print("  - \(stableNights) stable nights, \(jetLagNights) jet lag nights")
    }
}
