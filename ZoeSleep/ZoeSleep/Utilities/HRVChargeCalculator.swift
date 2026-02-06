//
//  HRVChargeCalculator.swift
//  Zoe Sleep for Longevity System
//
//  Calculates HRV Charge (recovery score) based on nighttime HRV patterns
//  Uses evening baseline, intra-night recovery curve, and personal baseline
//

import Foundation

/// Calculator for HRV Charge (recovery/readiness score)
/// Based on parasympathetic recovery patterns during sleep
class HRVChargeCalculator {

    // MARK: - Configuration

    /// Weight for evening component in final score (30%)
    private let eveningWeight: Double = 0.30

    /// Weight for recovery component in final score (70%)
    private let recoveryWeight: Double = 0.70

    /// Maximum trend modifier adjustment (±10%)
    private let maxTrendModifier: Double = 0.10

    // MARK: - Main Calculation

    /// Calculate HRV Charge from nightly summary data
    /// - Parameters:
    ///   - summary: HRV nightly summary with evening/night/morning data
    ///   - personalBaseline: User's personal HRV baseline (if available)
    ///   - userAge: User's age for population norms
    ///   - userSex: User's biological sex for population norms
    /// - Returns: HRV Charge result with score and components
    func calculateCharge(
        from summary: HRVNightlySummary,
        personalBaseline: PersonalHRVBaseline?,
        userAge: Int?,
        userSex: String?
    ) -> HRVChargeResult {
        // Determine which baseline to use
        let baseline: PersonalHRVBaseline
        let baselineType: HRVBaselineType

        if let personal = personalBaseline, personal.isPersonalized {
            baseline = personal
            baselineType = .personal
        } else {
            // Use population norms
            baseline = PopulationHRVNorms.pseudoBaseline(
                age: userAge ?? 40,
                sex: userSex
            )
            baselineType = .population
        }

        // Calculate evening component (30% of score)
        let eveningComponent = calculateEveningComponent(
            eveningHRV: summary.eveningAvg,
            baseline: baseline
        )

        // Calculate recovery component (70% of score)
        let recoveryComponent = calculateRecoveryComponent(
            summary: summary,
            baseline: baseline
        )

        // Calculate trend modifier (personal baseline comparison)
        let trendModifier = calculateTrendModifier(
            summary: summary,
            personalBaseline: personalBaseline
        )

        // Calculate raw score
        let rawScore = (eveningComponent * eveningWeight + recoveryComponent * recoveryWeight) * trendModifier

        // Clamp to 0-100
        let chargeScore = Int(round(min(100, max(0, rawScore))))

        // Determine trajectory
        let trajectory = RecoveryTrajectory.from(score: chargeScore)

        // Calculate confidence based on data quality
        let confidence = calculateConfidence(summary: summary, baselineType: baselineType)

        // Calculate deviation from baseline
        var deviationFromBaseline: Double? = nil
        if let personal = personalBaseline, personal.isPersonalized {
            let currentAvg = (eveningComponent + recoveryComponent) / 2
            let baselineAvg = 70.0 // Expected average for a typical night
            deviationFromBaseline = currentAvg - baselineAvg
        }

        let components = HRVChargeComponents(
            eveningComponent: eveningComponent,
            recoveryComponent: recoveryComponent,
            trendModifier: trendModifier,
            eveningHRVUsed: summary.eveningAvg,
            peakHRVUsed: summary.intraNightPeak,
            morningHRVUsed: summary.morningAvg
        )

        return HRVChargeResult(
            date: summary.date,
            chargeScore: chargeScore,
            recoveryTrajectory: trajectory,
            confidence: confidence,
            components: components,
            baselineType: baselineType,
            deviationFromBaseline: deviationFromBaseline
        )
    }

    // MARK: - Evening Component

    /// Calculate evening component score (0-100)
    /// Compares evening HRV to baseline evening HRV
    private func calculateEveningComponent(
        eveningHRV: Double?,
        baseline: PersonalHRVBaseline
    ) -> Double {
        guard let evening = eveningHRV, evening > 0 else {
            return 50.0 // Neutral if no evening data
        }

        // Compare to baseline evening HRV
        let ratio = evening / baseline.avgEveningHRV

        // Map ratio to 0-100 score
        // ratio 0.8 = 40 pts, 1.0 = 50 pts, 1.2 = 60 pts, 1.4 = 70 pts
        let score = 50.0 + (ratio - 1.0) * 50.0

        return min(100, max(0, score))
    }

    // MARK: - Recovery Component

    /// Calculate recovery component score (0-100)
    /// Based on recovery ratio (peak HRV / evening HRV)
    private func calculateRecoveryComponent(
        summary: HRVNightlySummary,
        baseline: PersonalHRVBaseline
    ) -> Double {
        // If we have intra-night data, use recovery ratio
        if let recoveryRatio = summary.recoveryRatio, summary.intraNightSampleCount >= 3 {
            return scoreFromRecoveryRatio(recoveryRatio)
        }

        // Fallback: use morning vs evening comparison
        if let morning = summary.morningAvg, let evening = summary.eveningAvg, evening > 0 {
            let ratio = morning / evening
            // Morning is typically slightly lower than peak, so adjust
            let adjustedRatio = ratio * 1.1 // Estimate peak is ~10% higher than morning
            return scoreFromRecoveryRatio(adjustedRatio)
        }

        // Insufficient data
        return 50.0
    }

    /// Convert recovery ratio to 0-100 score
    private func scoreFromRecoveryRatio(_ ratio: Double) -> Double {
        // Healthy recovery: 15-40% increase from evening to peak
        // ratio 1.0 = no change = 20 pts (stressed/sick)
        // ratio 1.15 = 40 pts (minimal recovery)
        // ratio 1.25 = 60 pts (moderate recovery)
        // ratio 1.35 = 80 pts (good recovery)
        // ratio 1.50+ = 100 pts (excellent recovery)

        switch ratio {
        case ...1.0:
            // No recovery or decline - concerning
            return 20.0
        case 1.0..<1.10:
            // Minimal recovery
            return 20.0 + (ratio - 1.0) * 200 // 20-40
        case 1.10..<1.20:
            // Below average recovery
            return 40.0 + (ratio - 1.10) * 200 // 40-60
        case 1.20..<1.35:
            // Good recovery
            return 60.0 + (ratio - 1.20) * 133 // 60-80
        case 1.35..<1.50:
            // Excellent recovery
            return 80.0 + (ratio - 1.35) * 133 // 80-100
        default:
            // Outstanding recovery
            return 100.0
        }
    }

    // MARK: - Trend Modifier

    /// Calculate trend modifier based on personal baseline deviation
    /// Returns multiplier (0.9 - 1.1) to adjust final score
    private func calculateTrendModifier(
        summary: HRVNightlySummary,
        personalBaseline: PersonalHRVBaseline?
    ) -> Double {
        guard let baseline = personalBaseline, baseline.isPersonalized else {
            return 1.0 // No adjustment without personal baseline
        }

        // Compare current night to personal average
        var deviations: [Double] = []

        if let evening = summary.eveningAvg, baseline.stdEveningHRV > 0 {
            let deviation = (evening - baseline.avgEveningHRV) / baseline.stdEveningHRV
            deviations.append(deviation)
        }

        if let morning = summary.morningAvg, baseline.stdMorningHRV > 0 {
            let deviation = (morning - baseline.avgMorningHRV) / baseline.stdMorningHRV
            deviations.append(deviation)
        }

        if let ratio = summary.recoveryRatio {
            // Compare recovery ratio to baseline
            let deviation = (ratio - baseline.avgRecoveryRatio) / 0.1 // Assume ~0.1 std dev
            deviations.append(deviation)
        }

        guard !deviations.isEmpty else {
            return 1.0
        }

        // Average deviation
        let avgDeviation = deviations.reduce(0, +) / Double(deviations.count)

        // Map to modifier: +1 std dev = +10%, -1 std dev = -10%
        let modifier = 1.0 + (avgDeviation * maxTrendModifier)

        return min(1.0 + maxTrendModifier, max(1.0 - maxTrendModifier, modifier))
    }

    // MARK: - Confidence

    /// Calculate confidence score (0-1) based on data quality
    private func calculateConfidence(
        summary: HRVNightlySummary,
        baselineType: HRVBaselineType
    ) -> Double {
        var confidence = 1.0

        // Reduce confidence if using population baseline
        if baselineType == .population {
            confidence *= 0.8
        }

        // Reduce confidence based on data availability
        if summary.eveningSampleCount == 0 {
            confidence *= 0.85
        }

        if summary.intraNightSampleCount < 3 {
            confidence *= 0.7
        } else if summary.intraNightSampleCount < 6 {
            confidence *= 0.85
        }

        if summary.morningSampleCount == 0 {
            confidence *= 0.9
        }

        // Reduce confidence for devices with limited HRV capability
        if !summary.hrvCapability.supportsRecoveryCurve {
            confidence *= 0.75
        }

        return min(1.0, max(0.1, confidence))
    }

    // MARK: - Baseline Calculation

    /// Calculate personal HRV baseline from historical summaries
    /// - Parameters:
    ///   - summaries: Array of HRV nightly summaries (should be last 7+ days)
    /// - Returns: Personal baseline or nil if insufficient data
    func calculatePersonalBaseline(from summaries: [HRVNightlySummary]) -> PersonalHRVBaseline? {
        // Need at least 3 days for any baseline
        guard summaries.count >= 3 else { return nil }

        // Filter to summaries with sufficient data
        let validSummaries = summaries.filter { $0.hasMinimumData }
        guard validSummaries.count >= 3 else { return nil }

        // Collect values
        var eveningValues: [Double] = []
        var morningValues: [Double] = []
        var peakValues: [Double] = []
        var recoveryRatios: [Double] = []

        for summary in validSummaries {
            if let evening = summary.eveningAvg {
                eveningValues.append(evening)
            }
            if let morning = summary.morningAvg {
                morningValues.append(morning)
            }
            if let peak = summary.intraNightPeak {
                peakValues.append(peak)
            }
            if let ratio = summary.recoveryRatio {
                recoveryRatios.append(ratio)
            }
        }

        // Calculate averages
        let avgEvening = eveningValues.isEmpty ? 40.0 : eveningValues.reduce(0, +) / Double(eveningValues.count)
        let avgMorning = morningValues.isEmpty ? 45.0 : morningValues.reduce(0, +) / Double(morningValues.count)
        let avgPeak = peakValues.isEmpty ? 55.0 : peakValues.reduce(0, +) / Double(peakValues.count)
        let avgRatio = recoveryRatios.isEmpty ? 1.2 : recoveryRatios.reduce(0, +) / Double(recoveryRatios.count)

        // Calculate standard deviations
        let stdEvening = calculateStandardDeviation(eveningValues) ?? avgEvening * 0.15
        let stdMorning = calculateStandardDeviation(morningValues) ?? avgMorning * 0.15

        // Get date range
        let sortedDates = validSummaries.map { $0.date }.sorted()
        let oldestDate = sortedDates.first ?? ""
        let newestDate = sortedDates.last ?? ""

        return PersonalHRVBaseline(
            avgEveningHRV: round(avgEvening * 10) / 10,
            avgMorningHRV: round(avgMorning * 10) / 10,
            avgPeakHRV: round(avgPeak * 10) / 10,
            avgRecoveryRatio: round(avgRatio * 100) / 100,
            stdEveningHRV: round(stdEvening * 10) / 10,
            stdMorningHRV: round(stdMorning * 10) / 10,
            daysInBaseline: validSummaries.count,
            oldestDate: oldestDate,
            newestDate: newestDate,
            lastUpdated: Date()
        )
    }

    /// Calculate standard deviation of an array of values
    private func calculateStandardDeviation(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }

        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count - 1)

        return sqrt(variance)
    }

    // MARK: - Batch Calculation

    /// Calculate HRV Charge for multiple nights
    /// Also updates personal baseline as part of calculation
    func calculateChargesForHistory(
        summaries: [HRVNightlySummary],
        existingBaseline: PersonalHRVBaseline?,
        userAge: Int?,
        userSex: String?
    ) -> (charges: [HRVChargeResult], updatedBaseline: PersonalHRVBaseline?) {
        // Calculate/update baseline from all summaries
        let baseline = calculatePersonalBaseline(from: summaries) ?? existingBaseline

        // Calculate charge for each summary
        var charges: [HRVChargeResult] = []

        for summary in summaries {
            let charge = calculateCharge(
                from: summary,
                personalBaseline: baseline,
                userAge: userAge,
                userSex: userSex
            )
            charges.append(charge)
        }

        return (charges, baseline)
    }
}
