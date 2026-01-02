//
//  HeartRateAnalyzer.swift
//  ZoeSleep Watch App
//
//  EXPERIMENTAL: Analyzes heart rate patterns for sleep stage detection.
//  Uses HR level, variability, and trends to distinguish sleep stages.
//
//  Key patterns:
//  - Deep sleep: Lowest HR, stable, high HRV
//  - REM: Variable HR (close to awake levels), higher HRV than light sleep
//  - Light sleep: Moderate HR, lower HRV than deep
//  - Awake: Highest HR, reactive to stimuli
//

import Foundation

// MARK: - Heart Rate Metrics

struct HeartRateEpochMetrics {
    let avgHeartRate: Double?
    let minHeartRate: Double?
    let maxHeartRate: Double?
    let hrv: Double?               // SDNN-like metric
    let slope: Double?             // Trend: negative = decreasing (entering sleep)
    let variability: Double?       // Beat-to-beat variability
    let pattern: HeartRatePattern
}

enum HeartRatePattern {
    case stable             // Very consistent - deep sleep
    case slowlyDecreasing   // Entering sleep
    case slowlyIncreasing   // Waking up
    case variable           // REM sleep characteristic
    case reactive           // Quick changes - awake
    case elevated           // Higher than baseline - stress/awake
    case insufficient       // Not enough data
}

// MARK: - Heart Rate Analyzer

/// Analyzes heart rate data for sleep stage classification
class HeartRateAnalyzer {
    // MARK: - Configuration

    struct Configuration {
        // Baseline thresholds (personalized over time)
        var restingHeartRate: Double = 60.0
        var sleepHeartRateRange: ClosedRange<Double> = 45...70
        var deepSleepHRThreshold: Double = 50.0

        // Pattern detection
        var stabilityThreshold: Double = 3.0      // BPM variance for "stable"
        var slopeThreshold: Double = 0.5          // BPM/epoch for trend
        var variabilityHighThreshold: Double = 50 // ms RMSSD for high HRV

        // Learning
        var baselineWindow: Int = 7               // Days to establish baseline
    }

    var config = Configuration()

    // MARK: - State

    private var epochSamples: [HeartRateSample] = []
    private var baselineHeartRates: [Double] = []    // For personalization
    private var nightlyMinHeartRates: [Double] = []  // Track circadian nadir

    struct HeartRateSample {
        let timestamp: Date
        let bpm: Double
        let interval: TimeInterval?  // RR interval if available
    }

    // MARK: - Processing

    /// Process incoming heart rate sample
    func processHeartRateSample(_ sample: SensorSample) {
        guard sample.type == .heartRate, let bpm = sample.values.first else { return }

        let hrSample = HeartRateSample(
            timestamp: sample.timestamp,
            bpm: bpm,
            interval: nil
        )

        epochSamples.append(hrSample)
    }

    /// Process HRV sample if available
    func processHRVSample(_ sample: SensorSample) {
        // HRV data can be processed for additional insights
    }

    // MARK: - Epoch Analysis

    /// Get aggregated metrics for the current epoch
    func getEpochMetrics() -> HeartRateEpochMetrics {
        guard epochSamples.count >= 2 else {
            return HeartRateEpochMetrics(
                avgHeartRate: epochSamples.first?.bpm,
                minHeartRate: epochSamples.first?.bpm,
                maxHeartRate: epochSamples.first?.bpm,
                hrv: nil,
                slope: nil,
                variability: nil,
                pattern: .insufficient
            )
        }

        let bpms = epochSamples.map { $0.bpm }

        let avg = bpms.reduce(0, +) / Double(bpms.count)
        let minHR = bpms.min()
        let maxHR = bpms.max()

        // Calculate pseudo-HRV (SDNN approximation from BPM variance)
        let variance = calculateVariance(bpms)
        let sdnn = sqrt(variance)
        let hrv = sdnnToHRV(sdnn)

        // Calculate slope (trend)
        let slope = calculateSlope(bpms)

        // Calculate beat-to-beat variability
        let variability = calculateBeatVariability(bpms)

        // Determine pattern
        let pattern = classifyPattern(
            avg: avg,
            variance: variance,
            slope: slope,
            range: (maxHR ?? 0) - (minHR ?? 0)
        )

        return HeartRateEpochMetrics(
            avgHeartRate: avg,
            minHeartRate: minHR,
            maxHeartRate: maxHR,
            hrv: hrv,
            slope: slope,
            variability: variability,
            pattern: pattern
        )
    }

    /// Reset for new epoch
    func resetEpoch() {
        epochSamples = []
    }

    // MARK: - Analysis Helpers

    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }

    private func calculateSlope(_ values: [Double]) -> Double {
        guard values.count >= 3 else { return 0 }

        // Simple linear regression slope
        let n = Double(values.count)
        let xMean = (n - 1) / 2.0
        let yMean = values.reduce(0, +) / n

        var numerator: Double = 0
        var denominator: Double = 0

        for (i, y) in values.enumerated() {
            let x = Double(i)
            numerator += (x - xMean) * (y - yMean)
            denominator += pow(x - xMean, 2)
        }

        return denominator > 0 ? numerator / denominator : 0
    }

    private func calculateBeatVariability(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }

        var diffs: [Double] = []
        for i in 1..<values.count {
            diffs.append(abs(values[i] - values[i-1]))
        }

        return diffs.reduce(0, +) / Double(diffs.count)
    }

    /// Convert BPM standard deviation to approximate HRV (SDNN in ms)
    private func sdnnToHRV(_ sdnn: Double) -> Double {
        // Rough approximation: higher BPM variance correlates with higher HRV
        // This is a simplified model - real HRV requires RR intervals
        return sdnn * 15  // Scaling factor
    }

    private func classifyPattern(
        avg: Double,
        variance: Double,
        slope: Double,
        range: Double
    ) -> HeartRatePattern {

        // Check for elevated heart rate (stress or awake)
        if avg > config.restingHeartRate + 15 {
            return .elevated
        }

        // Very stable - deep sleep characteristic
        if variance < pow(config.stabilityThreshold, 2) && range < 5 {
            return .stable
        }

        // Variable with moderate average - REM characteristic
        if variance > pow(config.stabilityThreshold * 2, 2) && avg < config.restingHeartRate + 10 {
            return .variable
        }

        // Decreasing trend - falling asleep
        if slope < -config.slopeThreshold {
            return .slowlyDecreasing
        }

        // Increasing trend - waking up
        if slope > config.slopeThreshold {
            return .slowlyIncreasing
        }

        // High variability with quick changes - reactive/awake
        if range > 15 {
            return .reactive
        }

        return .stable
    }

    // MARK: - Stage Inference

    /// Infer sleep stage from heart rate pattern alone
    func inferSleepStageFromHR(_ metrics: HeartRateEpochMetrics) -> (stage: SleepStage, confidence: Double) {
        guard let avgHR = metrics.avgHeartRate else {
            return (.awake, 0.2)
        }

        switch metrics.pattern {
        case .stable:
            // Stable low HR = deep sleep
            if avgHR < config.deepSleepHRThreshold {
                return (.deepN3, 0.7)
            } else {
                return (.lightN2, 0.6)
            }

        case .variable:
            // Variable HR is REM characteristic
            return (.rem, 0.65)

        case .slowlyDecreasing:
            // Transitioning to sleep
            return (.lightN1, 0.6)

        case .slowlyIncreasing:
            // Transitioning to wake
            return (.lightN1, 0.5)

        case .reactive, .elevated:
            // Quick changes or elevated = awake
            return (.awake, 0.75)

        case .insufficient:
            return (.awake, 0.2)
        }
    }

    // MARK: - Baseline Learning

    /// Update baseline with new night's data
    func updateBaseline(minHeartRate: Double, avgHeartRate: Double) {
        nightlyMinHeartRates.append(minHeartRate)
        baselineHeartRates.append(avgHeartRate)

        // Keep only recent history
        if nightlyMinHeartRates.count > config.baselineWindow {
            nightlyMinHeartRates.removeFirst()
        }
        if baselineHeartRates.count > config.baselineWindow {
            baselineHeartRates.removeFirst()
        }

        // Update configuration based on personal baseline
        if baselineHeartRates.count >= 3 {
            config.restingHeartRate = baselineHeartRates.reduce(0, +) / Double(baselineHeartRates.count)
        }

        if nightlyMinHeartRates.count >= 3 {
            config.deepSleepHRThreshold = nightlyMinHeartRates.reduce(0, +) / Double(nightlyMinHeartRates.count) + 3
        }
    }

    // MARK: - Temperature Nadir Detection

    /// Detect circadian temperature nadir from HR patterns
    /// HR typically reaches minimum around 4-5 AM (temperature nadir)
    func detectCircadianNadir(epochs: [SleepEpoch]) -> Date? {
        guard epochs.count >= 20 else { return nil } // Need sufficient data

        // Find the epoch with lowest heart rate
        var lowestHR: Double = .infinity
        var nadirTime: Date?

        for epoch in epochs {
            if let hr = epoch.avgHeartRate, hr < lowestHR {
                lowestHR = hr
                nadirTime = epoch.startTime
            }
        }

        // Validate timing - nadir should be in typical window (2-6 AM)
        if let time = nadirTime {
            let hour = Calendar.current.component(.hour, from: time)
            if hour >= 2 && hour <= 6 {
                return time
            }
        }

        return nadirTime
    }

    // MARK: - REM Detection

    /// Detect REM sleep from HR variability patterns
    /// REM has high HR variability but low movement
    func detectREMPattern(
        hrMetrics: HeartRateEpochMetrics,
        motionIntensity: Double
    ) -> Double {
        var remConfidence: Double = 0

        // High HRV is REM indicator
        if let hrv = hrMetrics.hrv, hrv > config.variabilityHighThreshold {
            remConfidence += 0.3
        }

        // Variable HR pattern
        if hrMetrics.pattern == .variable {
            remConfidence += 0.3
        }

        // Low movement (REM atonia)
        if motionIntensity < 0.05 {
            remConfidence += 0.2
        }

        // Moderate HR (not as low as deep sleep)
        if let avgHR = hrMetrics.avgHeartRate,
           avgHR > config.deepSleepHRThreshold &&
           avgHR < config.restingHeartRate + 5 {
            remConfidence += 0.2
        }

        return min(1.0, remConfidence)
    }

    // MARK: - Deep Sleep Detection

    /// Detect deep sleep from HR patterns
    func detectDeepSleepPattern(
        hrMetrics: HeartRateEpochMetrics,
        motionIntensity: Double
    ) -> Double {
        var deepConfidence: Double = 0

        // Stable low HR
        if hrMetrics.pattern == .stable {
            deepConfidence += 0.3
        }

        if let avgHR = hrMetrics.avgHeartRate, avgHR < config.deepSleepHRThreshold {
            deepConfidence += 0.3
        }

        // Very low movement
        if motionIntensity < 0.02 {
            deepConfidence += 0.2
        }

        // Low HR range within epoch
        if let minHR = hrMetrics.minHeartRate,
           let maxHR = hrMetrics.maxHeartRate,
           (maxHR - minHR) < 5 {
            deepConfidence += 0.2
        }

        return min(1.0, deepConfidence)
    }
}
