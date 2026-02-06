//
//  ZoeSleepScoreCalculator.swift
//  Zoe Sleep for Longevity System
//
//  Calculates unified Zoe Sleep Score across all wearable devices
//  Normalizes data from different sources to provide consistent scoring
//

import Foundation

/// Calculator for unified Zoe Sleep Score
/// Creates consistent 0-100 score regardless of wearable device
class ZoeSleepScoreCalculator {

    // MARK: - Configuration

    /// Weight for duration component (30%)
    private let durationWeight: Double = 0.30

    /// Weight for efficiency component (25%)
    private let efficiencyWeight: Double = 0.25

    /// Weight for deep sleep component (20%)
    private let deepSleepWeight: Double = 0.20

    /// Weight for REM sleep component (15%)
    private let remSleepWeight: Double = 0.15

    /// Weight for consistency component (10%)
    private let consistencyWeight: Double = 0.10

    // MARK: - Optimal Ranges

    /// Optimal sleep duration range (hours)
    private let optimalDurationRange = 7.0...9.0

    /// Acceptable sleep duration range (hours)
    private let acceptableDurationRange = 6.0...10.0

    /// Optimal sleep efficiency (%)
    private let optimalEfficiency: Double = 85.0

    /// Optimal deep sleep percentage (%)
    private let optimalDeepRange = 15.0...25.0

    /// Optimal REM sleep percentage (%)
    private let optimalRemRange = 20.0...25.0

    // MARK: - Main Calculation

    /// Calculate Zoe Sleep Score from sleep data
    /// - Parameters:
    ///   - data: Sleep data for scoring
    ///   - historicalData: Previous nights for consistency calculation
    ///   - hrvCharge: Optional HRV Charge result to include
    /// - Returns: Complete sleep score result
    func calculateScore(
        from data: SleepDataForScoring,
        historicalData: [SleepDataForScoring] = [],
        hrvCharge: HRVChargeResult? = nil
    ) -> ZoeSleepScoreResult {
        // Calculate component scores
        let durationScore = calculateDurationScore(sleepHours: data.sleepHours)
        let efficiencyScore = calculateEfficiencyScore(efficiency: data.efficiency)
        let deepScore = calculateDeepSleepScore(deepPercent: data.deepPercent)
        let remScore = calculateRemSleepScore(remPercent: data.remPercent)
        let consistencyScore = calculateConsistencyScore(
            currentBedtime: data.inBedTime,
            historicalData: historicalData
        )

        // Create components
        let components = ZoeScoreComponents(
            duration: durationScore,
            efficiency: efficiencyScore,
            deepSleep: deepScore,
            remSleep: remScore,
            consistency: consistencyScore
        )

        // Calculate weighted total
        let zoeScore = Int(round(components.weightedTotal))

        // Calculate confidence based on data completeness
        let confidence = calculateConfidence(data: data)

        // Create device score
        let deviceScore = DeviceSleepScore(
            deviceName: data.source,
            wearableType: data.source,
            bundleId: data.sourceBundleId,
            nativeScore: data.nativeScore,
            zoeScore: zoeScore
        )

        return ZoeSleepScoreResult(
            date: data.date,
            zoeScore: zoeScore,
            components: components,
            deviceScores: [deviceScore],
            hrvCharge: hrvCharge?.chargeScore,
            hrvChargeTrajectory: hrvCharge?.recoveryTrajectory.rawValue,
            primarySource: data.source,
            allSources: [data.source],
            confidence: confidence
        )
    }

    // MARK: - Duration Score

    /// Calculate duration score (0-100)
    /// Optimal: 7-9 hours
    private func calculateDurationScore(sleepHours: Double) -> Double {
        switch sleepHours {
        case optimalDurationRange:
            return 100.0
        case 6.0..<7.0:
            // Slightly short - linear interpolation to 80
            return 80.0 + (sleepHours - 6.0) * 20.0
        case 9.0..<10.0:
            // Slightly long - linear interpolation to 80
            return 100.0 - (sleepHours - 9.0) * 20.0
        case 5.0..<6.0:
            // Short - interpolate to 60
            return 60.0 + (sleepHours - 5.0) * 20.0
        case 10.0..<11.0:
            // Long - interpolate to 60
            return 80.0 - (sleepHours - 10.0) * 20.0
        case 4.0..<5.0:
            // Very short - interpolate to 40
            return 40.0 + (sleepHours - 4.0) * 20.0
        default:
            // Extreme - low score
            if sleepHours < 4.0 {
                return max(0, sleepHours * 10.0)
            } else {
                return max(40, 100 - (sleepHours - 8.0) * 10.0)
            }
        }
    }

    // MARK: - Efficiency Score

    /// Calculate efficiency score (0-100)
    /// Optimal: 85%+
    private func calculateEfficiencyScore(efficiency: Double) -> Double {
        if efficiency >= optimalEfficiency {
            // At or above optimal - full score
            return 100.0
        } else if efficiency >= 75.0 {
            // Good efficiency - interpolate 75-100
            return 75.0 + (efficiency - 75.0) / 10.0 * 25.0
        } else if efficiency >= 65.0 {
            // Fair efficiency - interpolate 50-75
            return 50.0 + (efficiency - 65.0) / 10.0 * 25.0
        } else {
            // Poor efficiency - interpolate 0-50
            return max(0, efficiency / 65.0 * 50.0)
        }
    }

    // MARK: - Deep Sleep Score

    /// Calculate deep sleep score (0-100)
    /// Optimal: 15-25% of total sleep
    private func calculateDeepSleepScore(deepPercent: Double?) -> Double {
        guard let deep = deepPercent else {
            // No deep sleep data - return neutral
            return 70.0
        }

        switch deep {
        case optimalDeepRange:
            return 100.0
        case 10..<15:
            // Slightly low - interpolate 75-100
            return 75.0 + (deep - 10.0) / 5.0 * 25.0
        case 25..<30:
            // Slightly high (unusual) - interpolate 75-100
            return 100.0 - (deep - 25.0) / 5.0 * 25.0
        case 5..<10:
            // Low - interpolate 50-75
            return 50.0 + (deep - 5.0) / 5.0 * 25.0
        default:
            if deep < 5 {
                // Very low
                return max(0, deep * 10.0)
            } else {
                // Very high (rare)
                return max(50, 100 - (deep - 20) * 2.0)
            }
        }
    }

    // MARK: - REM Sleep Score

    /// Calculate REM sleep score (0-100)
    /// Optimal: 20-25% of total sleep
    private func calculateRemSleepScore(remPercent: Double?) -> Double {
        guard let rem = remPercent else {
            // No REM data - return neutral
            return 70.0
        }

        switch rem {
        case optimalRemRange:
            return 100.0
        case 15..<20:
            // Slightly low - interpolate 75-100
            return 75.0 + (rem - 15.0) / 5.0 * 25.0
        case 25..<30:
            // Slightly high - interpolate 75-100
            return 100.0 - (rem - 25.0) / 5.0 * 25.0
        case 10..<15:
            // Low - interpolate 50-75
            return 50.0 + (rem - 10.0) / 5.0 * 25.0
        default:
            if rem < 10 {
                // Very low
                return max(0, rem * 5.0)
            } else {
                // Very high (rare)
                return max(50, 100 - (rem - 22.5) * 2.0)
            }
        }
    }

    // MARK: - Consistency Score

    /// Calculate consistency score (0-100)
    /// Based on bedtime variance over historical data
    private func calculateConsistencyScore(
        currentBedtime: Date?,
        historicalData: [SleepDataForScoring]
    ) -> Double {
        // Need at least 3 days for consistency calculation
        guard historicalData.count >= 3 else {
            return 70.0 // Default neutral score
        }

        // Extract bedtime hours
        let bedtimeHours: [Double] = historicalData.compactMap { data in
            guard let bedtime = data.inBedTime else { return nil }
            let components = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
            var hour = Double(components.hour ?? 0)
            // Adjust for after-midnight bedtimes (e.g., 1 AM = 25)
            if hour < 12 {
                hour += 24
            }
            return hour + Double(components.minute ?? 0) / 60.0
        }

        guard bedtimeHours.count >= 3 else {
            return 70.0
        }

        // Calculate variance
        let mean = bedtimeHours.reduce(0, +) / Double(bedtimeHours.count)
        let squaredDiffs = bedtimeHours.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(bedtimeHours.count)
        let stdDev = sqrt(variance)

        // Map standard deviation to score
        // stdDev 0 = 100 (perfect consistency)
        // stdDev 0.5 hours (30 mins) = 85 (good)
        // stdDev 1 hour = 70 (fair)
        // stdDev 2 hours = 40 (poor)

        if stdDev < 0.25 {
            return 100.0
        } else if stdDev < 0.5 {
            return 100.0 - (stdDev - 0.25) * 60.0 // 100 -> 85
        } else if stdDev < 1.0 {
            return 85.0 - (stdDev - 0.5) * 30.0 // 85 -> 70
        } else if stdDev < 2.0 {
            return 70.0 - (stdDev - 1.0) * 30.0 // 70 -> 40
        } else {
            return max(20, 40 - (stdDev - 2.0) * 10.0)
        }
    }

    // MARK: - Confidence

    /// Calculate confidence score (0-1) based on data completeness
    private func calculateConfidence(data: SleepDataForScoring) -> Double {
        var confidence = 1.0

        // Reduce confidence if missing sleep stages
        if data.deepSleepMins == nil {
            confidence *= 0.85
        }
        if data.remSleepMins == nil {
            confidence *= 0.85
        }

        // Reduce confidence if missing timing data
        if data.inBedTime == nil {
            confidence *= 0.9
        }

        // Reduce confidence for very short or long sleep
        let hours = data.sleepHours
        if hours < 4 || hours > 12 {
            confidence *= 0.8
        }

        return min(1.0, max(0.3, confidence))
    }

    // MARK: - Multi-Source Scoring

    /// Calculate scores for multiple sources and combine
    /// - Parameters:
    ///   - dataBySource: Dictionary of source name to sleep data
    ///   - historicalData: Previous nights for consistency
    ///   - hrvCharge: Optional HRV Charge result
    /// - Returns: Combined score result with all device scores
    func calculateMultiSourceScore(
        dataBySource: [String: SleepDataForScoring],
        historicalData: [SleepDataForScoring] = [],
        hrvCharge: HRVChargeResult? = nil
    ) -> ZoeSleepScoreResult? {
        guard let primaryData = dataBySource.values.first else {
            return nil
        }

        // Calculate score for each source
        var deviceScores: [DeviceSleepScore] = []
        var bestScore: Int = 0
        var bestComponents: ZoeScoreComponents?
        var allSources: [String] = []

        for (source, data) in dataBySource {
            let result = calculateScore(from: data, historicalData: historicalData)
            let deviceScore = DeviceSleepScore(
                deviceName: source,
                wearableType: data.source,
                bundleId: data.sourceBundleId,
                nativeScore: data.nativeScore,
                zoeScore: result.zoeScore
            )
            deviceScores.append(deviceScore)
            allSources.append(source)

            // Track best score (from highest priority source)
            if result.zoeScore > bestScore || bestComponents == nil {
                bestScore = result.zoeScore
                bestComponents = result.components
            }
        }

        guard let components = bestComponents else {
            return nil
        }

        // Use primary source's date
        let date = primaryData.date

        return ZoeSleepScoreResult(
            date: date,
            zoeScore: bestScore,
            components: components,
            deviceScores: deviceScores,
            hrvCharge: hrvCharge?.chargeScore,
            hrvChargeTrajectory: hrvCharge?.recoveryTrajectory.rawValue,
            primarySource: primaryData.source,
            allSources: allSources,
            confidence: calculateConfidence(data: primaryData)
        )
    }

    // MARK: - Weekly Summary

    /// Calculate weekly sleep score summary
    /// - Parameter scores: Array of daily sleep scores
    /// - Returns: Weekly summary with averages and trends
    func calculateWeeklySummary(from scores: [ZoeSleepScoreResult]) -> WeeklySleepScoreSummary? {
        guard !scores.isEmpty else { return nil }

        // Calculate averages
        let zoeScores = scores.compactMap { $0.zoeScore }
        let hrvCharges = scores.compactMap { $0.hrvCharge }

        let avgZoe = zoeScores.isEmpty ? nil : Int(zoeScores.reduce(0, +) / zoeScores.count)
        let avgHrv = hrvCharges.isEmpty ? nil : Int(hrvCharges.reduce(0, +) / hrvCharges.count)

        // Find best and worst days
        let sortedByScore = scores.sorted { ($0.zoeScore ) > ($1.zoeScore) }
        let bestDay = sortedByScore.first?.date
        let worstDay = sortedByScore.last?.date

        // Calculate trend
        let trend = calculateTrend(scores: scores)

        // Get week start date (Sunday)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sortedDates = scores.map { $0.date }.sorted()
        let weekStart = sortedDates.first ?? ""

        return WeeklySleepScoreSummary(
            weekStartDate: weekStart,
            avgZoeScore: avgZoe,
            avgHrvCharge: avgHrv,
            daysWithData: scores.count,
            bestDay: bestDay,
            worstDay: worstDay,
            trend: trend
        )
    }

    /// Calculate score trend direction
    private func calculateTrend(scores: [ZoeSleepScoreResult]) -> ScoreTrend {
        guard scores.count >= 3 else {
            return .insufficient
        }

        // Sort by date
        let sorted = scores.sorted { $0.date < $1.date }

        // Compare first half to second half
        let midpoint = sorted.count / 2
        let firstHalf = Array(sorted.prefix(midpoint))
        let secondHalf = Array(sorted.suffix(sorted.count - midpoint))

        let firstAvg = Double(firstHalf.map { $0.zoeScore }.reduce(0, +)) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.map { $0.zoeScore }.reduce(0, +)) / Double(secondHalf.count)

        let change = secondAvg - firstAvg

        if change > 5 {
            return .improving
        } else if change < -5 {
            return .declining
        } else {
            return .stable
        }
    }
}
