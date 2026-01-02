//
//  FalsePositiveEliminator.swift
//  ZoeSleep Watch App
//
//  EXPERIMENTAL: Detects false sleep classifications.
//
//  The problem: Devices like Oura often classify lying still while watching
//  Netflix as sleep. This leads to:
//  - Inflated sleep duration
//  - Incorrect sleep timing
//  - Skewed sleep stage ratios
//
//  Our solution: Multi-signal analysis to detect "engaged stillness" vs "sleep stillness"
//
//  Key differentiators:
//  1. Micro-fidgeting pattern (small adjustments while watching vs. true stillness)
//  2. Heart rate reactivity (engaged watching has more HR variability)
//  3. Duration patterns (can't fall asleep in 30 seconds of stillness)
//  4. Movement regularity (periodic adjustments vs. random sleep movements)
//  5. Time context (watching TV at 11pm vs. 3am)
//

import Foundation

// MARK: - False Positive Result

struct FalsePositiveResult {
    let isLikelyAwake: Bool
    let confidence: Double           // 0-1, how sure we are they're awake
    let reason: FalsePositiveReason
    let signals: [FalsePositiveSignal]
}

enum FalsePositiveReason {
    case microFidgeting              // Small constant movements
    case heartRateReactive           // HR responding to stimuli
    case tooQuickSleepOnset          // Can't fall asleep that fast
    case periodicMovement            // Regular adjustment pattern
    case elevatedHeartRate           // HR too high for sleep
    case insufficientStillness       // Not still enough long enough
    case recentActivity              // Was moving recently
    case likelySleeping              // No red flags - probably asleep
}

struct FalsePositiveSignal {
    let name: String
    let value: Double
    let threshold: Double
    let triggered: Bool
}

// MARK: - False Positive Eliminator

/// Detects when "sleep" is actually lying awake (watching TV, etc.)
class FalsePositiveEliminator {

    // MARK: - Configuration

    struct Configuration {
        // Micro-fidgeting thresholds
        var microMovementThreshold: Int = 10        // Micro-movements per epoch
        var fidgetPatternWindowSize: Int = 5        // Epochs to analyze

        // Heart rate thresholds
        var maxSleepHeartRate: Double = 75.0        // Above this = awake
        var hrReactivityThreshold: Double = 8.0     // BPM range indicating reactivity

        // Timing thresholds
        var minTimeToSleepOnset: TimeInterval = 120 // 2 min minimum to fall asleep
        var suspiciousQuickSleep: TimeInterval = 60 // <1 min is very suspicious

        // Movement thresholds
        var periodicMovementIntervalMin: TimeInterval = 45  // Min suspicious regularity
        var periodicMovementIntervalMax: TimeInterval = 120 // Max suspicious regularity
        var maxStillnessBeforeSleep: TimeInterval = 300        // 5 min max to fall asleep

        // Duration thresholds
        var minimumSleepBout: TimeInterval = 300    // 5 min minimum sleep bout
    }

    var config = Configuration()

    // MARK: - State

    private var lastMovementTime: Date?
    private var stillnessStartTime: Date?
    private var movementTimes: [Date] = []         // For periodicity detection
    private var recentEvaluations: [FalsePositiveResult] = []

    // MARK: - Evaluation

    /// Evaluate an epoch for false positive sleep detection
    func evaluate(_ epoch: SleepEpoch, recentEpochs: [SleepEpoch]) -> FalsePositiveResult {
        var signals: [FalsePositiveSignal] = []
        var totalScore: Double = 0
        var maxScore: Double = 0

        // 1. Micro-fidgeting analysis
        let fidgetResult = analyzeMicroFidgeting(epoch, recentEpochs: recentEpochs)
        signals.append(fidgetResult.signal)
        totalScore += fidgetResult.score
        maxScore += 1.0

        // 2. Heart rate reactivity
        let hrResult = analyzeHeartRateReactivity(epoch, recentEpochs: recentEpochs)
        signals.append(hrResult.signal)
        totalScore += hrResult.score
        maxScore += 1.0

        // 3. Quick sleep onset detection
        let onsetResult = analyzeQuickSleepOnset(epoch, recentEpochs: recentEpochs)
        signals.append(onsetResult.signal)
        totalScore += onsetResult.score
        maxScore += 1.0

        // 4. Movement periodicity
        let periodicResult = analyzeMovementPeriodicity(epoch, recentEpochs: recentEpochs)
        signals.append(periodicResult.signal)
        totalScore += periodicResult.score
        maxScore += 0.5  // Lower weight

        // 5. Elevated heart rate
        let elevatedHRResult = analyzeElevatedHeartRate(epoch)
        signals.append(elevatedHRResult.signal)
        totalScore += elevatedHRResult.score
        maxScore += 1.0

        // 6. Recent activity context
        let activityResult = analyzeRecentActivity(epoch, recentEpochs: recentEpochs)
        signals.append(activityResult.signal)
        totalScore += activityResult.score
        maxScore += 0.5

        // Calculate confidence
        let confidence = totalScore / maxScore

        // Determine primary reason
        let primaryReason = determinePrimaryReason(signals: signals, confidence: confidence)

        let result = FalsePositiveResult(
            isLikelyAwake: confidence > 0.5,
            confidence: confidence,
            reason: primaryReason,
            signals: signals
        )

        // Store for pattern analysis
        recentEvaluations.append(result)
        if recentEvaluations.count > 20 {
            recentEvaluations.removeFirst()
        }

        return result
    }

    // MARK: - Individual Analyses

    /// Analyze micro-fidgeting pattern
    /// Key insight: Watching TV involves small constant adjustments
    /// Sleep involves true stillness with occasional larger movements
    private func analyzeMicroFidgeting(
        _ epoch: SleepEpoch,
        recentEpochs: [SleepEpoch]
    ) -> (signal: FalsePositiveSignal, score: Double) {

        let microCount = epoch.microMovements
        let recentMicroCounts = recentEpochs.map { $0.microMovements }

        // Check for sustained micro-fidgeting pattern
        var sustainedFidgeting = false
        if recentMicroCounts.count >= 3 {
            let avgMicro = Double(recentMicroCounts.reduce(0, +)) / Double(recentMicroCounts.count)
            sustainedFidgeting = avgMicro > 8
        }

        let triggered = microCount > config.microMovementThreshold || sustainedFidgeting
        let score: Double = triggered ? 0.8 : 0

        return (
            signal: FalsePositiveSignal(
                name: "Micro-fidgeting",
                value: Double(microCount),
                threshold: Double(config.microMovementThreshold),
                triggered: triggered
            ),
            score: score
        )
    }

    /// Analyze heart rate reactivity
    /// Engaged watching shows more HR variation (responding to content)
    /// Sleep has smoother, more predictable HR
    private func analyzeHeartRateReactivity(
        _ epoch: SleepEpoch,
        recentEpochs: [SleepEpoch]
    ) -> (signal: FalsePositiveSignal, score: Double) {

        guard let minHR = epoch.minHeartRate,
              let maxHR = epoch.maxHeartRate else {
            return (
                signal: FalsePositiveSignal(
                    name: "HR Reactivity",
                    value: 0,
                    threshold: config.hrReactivityThreshold,
                    triggered: false
                ),
                score: 0
            )
        }

        let range = maxHR - minHR

        // Also check for sudden spikes in recent epochs
        var recentSpikes = 0
        for recent in recentEpochs {
            if let prevMin = recent.minHeartRate,
               let prevMax = recent.maxHeartRate,
               (prevMax - prevMin) > config.hrReactivityThreshold {
                recentSpikes += 1
            }
        }

        let triggered = range > config.hrReactivityThreshold || recentSpikes >= 2
        let score: Double = triggered ? 0.6 : 0

        return (
            signal: FalsePositiveSignal(
                name: "HR Reactivity",
                value: range,
                threshold: config.hrReactivityThreshold,
                triggered: triggered
            ),
            score: score
        )
    }

    /// Analyze quick sleep onset
    /// Real sleep onset takes at least 5-15 minutes
    /// Instant "sleep" after lying down = probably not sleeping
    private func analyzeQuickSleepOnset(
        _ epoch: SleepEpoch,
        recentEpochs: [SleepEpoch]
    ) -> (signal: FalsePositiveSignal, score: Double) {

        // Look for transition from high movement to low movement
        let wasRecentlyActive = recentEpochs.suffix(4).contains { $0.movementIntensity > 0.2 }

        if !wasRecentlyActive {
            // No recent activity, can't evaluate quick onset
            return (
                signal: FalsePositiveSignal(
                    name: "Quick Sleep Onset",
                    value: 0,
                    threshold: config.minTimeToSleepOnset,
                    triggered: false
                ),
                score: 0
            )
        }

        // Count epochs since last significant activity
        var epochsSinceActivity = 0
        for recent in recentEpochs.reversed() {
            if recent.movementIntensity > 0.2 {
                break
            }
            epochsSinceActivity += 1
        }

        let timeSinceActivity = TimeInterval(epochsSinceActivity * 30) // 30s epochs

        // If claiming "asleep" within 2 min of activity, suspicious
        let triggered = timeSinceActivity < config.minTimeToSleepOnset && epoch.movementIntensity < 0.05
        let score: Double

        if timeSinceActivity < config.suspiciousQuickSleep {
            score = 0.9  // Very suspicious
        } else if timeSinceActivity < config.minTimeToSleepOnset {
            score = 0.6
        } else {
            score = 0
        }

        return (
            signal: FalsePositiveSignal(
                name: "Quick Sleep Onset",
                value: timeSinceActivity,
                threshold: config.minTimeToSleepOnset,
                triggered: triggered
            ),
            score: score
        )
    }

    /// Analyze movement periodicity
    /// Watching TV: periodic adjustments every 1-2 min
    /// Sleeping: random movements, not periodic
    private func analyzeMovementPeriodicity(
        _ epoch: SleepEpoch,
        recentEpochs: [SleepEpoch]
    ) -> (signal: FalsePositiveSignal, score: Double) {

        // Find movement intervals
        var intervals: [TimeInterval] = []
        var lastMovementTime: Date?

        for recent in recentEpochs {
            if recent.movementCount > 0 {
                if let last = lastMovementTime {
                    let interval = recent.startTime.timeIntervalSince(last)
                    intervals.append(interval)
                }
                lastMovementTime = recent.startTime
            }
        }

        guard intervals.count >= 3 else {
            return (
                signal: FalsePositiveSignal(
                    name: "Periodic Movement",
                    value: 0,
                    threshold: 0,
                    triggered: false
                ),
                score: 0
            )
        }

        // Check for regularity
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - avgInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)

        // Low variance = periodic pattern (suspicious)
        let isRegular = stdDev < 20 && avgInterval > 30 && avgInterval < 180
        let score: Double = isRegular ? 0.4 : 0

        return (
            signal: FalsePositiveSignal(
                name: "Periodic Movement",
                value: stdDev,
                threshold: 20,
                triggered: isRegular
            ),
            score: score
        )
    }

    /// Analyze elevated heart rate
    /// Sleep HR should be low; elevated HR = awake
    private func analyzeElevatedHeartRate(
        _ epoch: SleepEpoch
    ) -> (signal: FalsePositiveSignal, score: Double) {

        guard let avgHR = epoch.avgHeartRate else {
            return (
                signal: FalsePositiveSignal(
                    name: "Elevated HR",
                    value: 0,
                    threshold: config.maxSleepHeartRate,
                    triggered: false
                ),
                score: 0
            )
        }

        let triggered = avgHR > config.maxSleepHeartRate
        let score: Double

        if avgHR > 85 {
            score = 0.9
        } else if avgHR > config.maxSleepHeartRate {
            score = 0.5
        } else {
            score = 0
        }

        return (
            signal: FalsePositiveSignal(
                name: "Elevated HR",
                value: avgHR,
                threshold: config.maxSleepHeartRate,
                triggered: triggered
            ),
            score: score
        )
    }

    /// Analyze recent activity context
    /// Just got into bed vs. been there a while
    private func analyzeRecentActivity(
        _ epoch: SleepEpoch,
        recentEpochs: [SleepEpoch]
    ) -> (signal: FalsePositiveSignal, score: Double) {

        let recentMovement = recentEpochs.suffix(2).map { $0.movementIntensity }.max() ?? 0

        // If still lots of movement in last minute, probably not asleep
        let triggered = recentMovement > 0.15
        let score: Double = triggered ? 0.3 : 0

        return (
            signal: FalsePositiveSignal(
                name: "Recent Activity",
                value: recentMovement,
                threshold: 0.15,
                triggered: triggered
            ),
            score: score
        )
    }

    // MARK: - Reason Determination

    private func determinePrimaryReason(
        signals: [FalsePositiveSignal],
        confidence: Double
    ) -> FalsePositiveReason {

        if confidence < 0.3 {
            return .likelySleeping
        }

        // Find strongest signal
        let triggeredSignals = signals.filter { $0.triggered }

        if triggeredSignals.isEmpty {
            return .likelySleeping
        }

        // Priority order
        for signal in triggeredSignals {
            switch signal.name {
            case "Micro-fidgeting":
                return .microFidgeting
            case "HR Reactivity":
                return .heartRateReactive
            case "Quick Sleep Onset":
                return .tooQuickSleepOnset
            case "Elevated HR":
                return .elevatedHeartRate
            case "Periodic Movement":
                return .periodicMovement
            case "Recent Activity":
                return .recentActivity
            default:
                continue
            }
        }

        return .likelySleeping
    }

    // MARK: - Sustained Analysis

    /// Check if "sleep" has been consistently flagged as suspicious
    func getSustainedFalsePositiveConfidence() -> Double {
        guard recentEvaluations.count >= 5 else { return 0 }

        let recentConfidences = recentEvaluations.suffix(10).map { $0.confidence }
        let avgConfidence = recentConfidences.reduce(0, +) / Double(recentConfidences.count)

        // If sustained high confidence of being awake, very likely awake
        return avgConfidence
    }

    /// Reset state for new sleep session
    func reset() {
        lastMovementTime = nil
        stillnessStartTime = nil
        movementTimes = []
        recentEvaluations = []
    }
}
