//
//  MotionAnalyzer.swift
//  ZoeSleep Watch App
//
//  EXPERIMENTAL: Analyzes accelerometer and device motion data to detect:
//  - Movement intensity (stillness indicates sleep)
//  - Position changes (rolling over)
//  - Micro-movements (fidgeting = likely awake)
//  - False sleep detection (watching TV in bed)
//

import Foundation
import CoreMotion

// MARK: - Motion Metrics

struct MotionEpochMetrics {
    let intensity: Double           // 0-1, overall movement intensity
    let movementCount: Int          // Significant movements
    let positionChanges: Int        // Major body position changes
    let microMovements: Int         // Small fidgets (awake indicator)
    let stillnessDuration: TimeInterval // Longest period of no movement
    let movementPattern: MovementPattern
}

enum MovementPattern {
    case deepStillness      // Almost no movement - deep sleep
    case lightStillness     // Very minimal movement - light sleep
    case occasional         // Occasional movements - REM or light
    case periodic           // Regular movements - restless or awake
    case continuous         // Constant movement - definitely awake
    case microFidgeting     // Small constant movements - watching something
}

// MARK: - Motion Analyzer

/// Analyzes accelerometer data for sleep/wake detection
class MotionAnalyzer {
    // MARK: - Configuration

    struct Configuration {
        // Movement thresholds (in g, where 1g = 9.8 m/s²)
        var stillnessThreshold: Double = 0.02      // Below this = stillness
        var microMovementThreshold: Double = 0.05  // Small fidgets
        var movementThreshold: Double = 0.15       // Significant movement
        var positionChangeThreshold: Double = 0.4  // Major position shift

        // Time windows
        var stillnessMinDuration: TimeInterval = 3.0  // Min time to count as still
        var movementDebounce: TimeInterval = 0.5      // Ignore movements within this time

        // Sampling
        var vectorMagnitudeSmoothing: Int = 5  // Rolling average samples
    }

    var config = Configuration()

    // MARK: - State

    private var epochSamples: [AccelerometerSample] = []
    private var orientationSamples: [OrientationSample] = []
    private var lastMovementTime: Date?
    private var stillnessStartTime: Date?

    // Rolling state for real-time updates
    private(set) var currentMovementIntensity: Double = 0
    private var magnitudeHistory: [Double] = []

    // MARK: - Sample Types

    struct AccelerometerSample {
        let timestamp: Date
        let x: Double
        let y: Double
        let z: Double

        var magnitude: Double {
            sqrt(x * x + y * y + z * z)
        }

        // Remove gravity component (approximate 1g)
        var dynamicMagnitude: Double {
            abs(magnitude - 1.0)
        }
    }

    struct OrientationSample {
        let timestamp: Date
        let pitch: Double
        let roll: Double
        let yaw: Double
    }

    // MARK: - Processing

    /// Process incoming accelerometer sample
    func processAccelerometerSample(_ sample: SensorSample) {
        guard sample.type == .accelerometer, sample.values.count >= 3 else { return }

        let accelSample = AccelerometerSample(
            timestamp: sample.timestamp,
            x: sample.values[0],
            y: sample.values[1],
            z: sample.values[2]
        )

        epochSamples.append(accelSample)

        // Update rolling magnitude for real-time intensity
        magnitudeHistory.append(accelSample.dynamicMagnitude)
        if magnitudeHistory.count > config.vectorMagnitudeSmoothing {
            magnitudeHistory.removeFirst()
        }

        // Calculate smoothed intensity
        let smoothedMagnitude = magnitudeHistory.reduce(0, +) / Double(magnitudeHistory.count)
        currentMovementIntensity = normalizeIntensity(smoothedMagnitude)

        // Track stillness periods
        if smoothedMagnitude < config.stillnessThreshold {
            if stillnessStartTime == nil {
                stillnessStartTime = sample.timestamp
            }
        } else {
            stillnessStartTime = nil
            if smoothedMagnitude > config.movementThreshold {
                lastMovementTime = sample.timestamp
            }
        }
    }

    /// Process device motion for orientation tracking
    func processDeviceMotionSample(_ sample: SensorSample) {
        guard sample.type == .deviceMotion, sample.values.count >= 3 else { return }

        let orientSample = OrientationSample(
            timestamp: sample.timestamp,
            pitch: sample.values[0],
            roll: sample.values[1],
            yaw: sample.values[2]
        )

        orientationSamples.append(orientSample)
    }

    // MARK: - Epoch Analysis

    /// Get aggregated metrics for the current epoch
    func getEpochMetrics() -> MotionEpochMetrics {
        guard !epochSamples.isEmpty else {
            return MotionEpochMetrics(
                intensity: 0,
                movementCount: 0,
                positionChanges: 0,
                microMovements: 0,
                stillnessDuration: 30,
                movementPattern: .deepStillness
            )
        }

        // Calculate overall intensity
        let magnitudes = epochSamples.map { $0.dynamicMagnitude }
        let avgMagnitude = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let maxMagnitude = magnitudes.max() ?? 0
        let intensity = normalizeIntensity(avgMagnitude)

        // Count significant movements
        let movementCount = countMovements(magnitudes)

        // Count position changes from orientation
        let positionChanges = countPositionChanges()

        // Count micro-movements (small fidgets that indicate wakefulness)
        let microMovements = countMicroMovements(magnitudes)

        // Calculate longest stillness period
        let stillnessDuration = calculateLongestStillness(magnitudes)

        // Determine movement pattern
        let pattern = classifyMovementPattern(
            intensity: intensity,
            movementCount: movementCount,
            microMovements: microMovements,
            maxMagnitude: maxMagnitude
        )

        return MotionEpochMetrics(
            intensity: intensity,
            movementCount: movementCount,
            positionChanges: positionChanges,
            microMovements: microMovements,
            stillnessDuration: stillnessDuration,
            movementPattern: pattern
        )
    }

    /// Reset for new epoch
    func resetEpoch() {
        epochSamples = []
        orientationSamples = []
    }

    // MARK: - Analysis Helpers

    private func normalizeIntensity(_ magnitude: Double) -> Double {
        // Map magnitude to 0-1 scale
        // 0g = 0, 0.5g+ = 1
        return min(1.0, magnitude / 0.5)
    }

    private func countMovements(_ magnitudes: [Double]) -> Int {
        var count = 0
        var lastMovementIndex = -100 // Start far back

        for (i, mag) in magnitudes.enumerated() {
            if mag > config.movementThreshold {
                // Debounce - don't count movements too close together
                let sampleInterval = 1.0 / 50.0 // Assuming 50Hz
                let timeSinceLastMovement = Double(i - lastMovementIndex) * sampleInterval

                if timeSinceLastMovement > config.movementDebounce {
                    count += 1
                    lastMovementIndex = i
                }
            }
        }

        return count
    }

    private func countMicroMovements(_ magnitudes: [Double]) -> Int {
        // Micro-movements are small but consistent movements
        // This is a key indicator of being awake (fidgeting while watching TV)

        var microCount = 0
        var inMicroMovement = false

        for mag in magnitudes {
            if mag > config.stillnessThreshold && mag < config.microMovementThreshold {
                if !inMicroMovement {
                    microCount += 1
                    inMicroMovement = true
                }
            } else {
                inMicroMovement = false
            }
        }

        return microCount
    }

    private func countPositionChanges() -> Int {
        guard orientationSamples.count >= 2 else { return 0 }

        var changes = 0
        var lastSignificantOrientation = orientationSamples.first!

        for sample in orientationSamples.dropFirst() {
            let pitchDiff = abs(sample.pitch - lastSignificantOrientation.pitch)
            let rollDiff = abs(sample.roll - lastSignificantOrientation.roll)

            // Position change = significant rotation in pitch or roll
            // (yaw changes while lying down don't usually indicate position change)
            if pitchDiff > 0.5 || rollDiff > 0.5 { // ~30 degrees
                changes += 1
                lastSignificantOrientation = sample
            }
        }

        return changes
    }

    private func calculateLongestStillness(_ magnitudes: [Double]) -> TimeInterval {
        var longestStillness: TimeInterval = 0
        var currentStillness: TimeInterval = 0
        let sampleInterval = 1.0 / 50.0 // Assuming 50Hz

        for mag in magnitudes {
            if mag < config.stillnessThreshold {
                currentStillness += sampleInterval
                longestStillness = max(longestStillness, currentStillness)
            } else {
                currentStillness = 0
            }
        }

        return longestStillness
    }

    private func classifyMovementPattern(
        intensity: Double,
        movementCount: Int,
        microMovements: Int,
        maxMagnitude: Double
    ) -> MovementPattern {

        // Deep stillness: almost no movement at all
        if intensity < 0.02 && movementCount == 0 && microMovements < 2 {
            return .deepStillness
        }

        // Light stillness: very minimal movement
        if intensity < 0.05 && movementCount <= 1 && microMovements < 5 {
            return .lightStillness
        }

        // Micro-fidgeting: lots of small movements (watching TV)
        // This is KEY for detecting false sleep while watching Netflix
        if microMovements > 15 && intensity < 0.15 && movementCount < 3 {
            return .microFidgeting
        }

        // Continuous movement: definitely awake
        if intensity > 0.3 || movementCount > 10 {
            return .continuous
        }

        // Periodic movement: regular movements, restless
        if movementCount > 5 {
            return .periodic
        }

        // Occasional movement: could be REM or light sleep
        return .occasional
    }

    // MARK: - Advanced Detection

    /// Detect if movement pattern suggests watching video/TV
    /// Key characteristics:
    /// - Long periods of relative stillness punctuated by small adjustments
    /// - Consistent micro-fidgeting (adjusting position while watching)
    /// - No major position changes
    /// - Duration too long to be falling asleep
    func detectPossibleVideoWatching(epochs: [SleepEpoch]) -> Double {
        guard epochs.count >= 5 else { return 0 }

        var confidence: Double = 0

        // Check for micro-fidgeting pattern across epochs
        let avgMicroMovements = Double(epochs.map { $0.microMovements }.reduce(0, +)) / Double(epochs.count)
        if avgMicroMovements > 10 {
            confidence += 0.3
        }

        // Check for low but non-zero intensity
        let avgIntensity = epochs.map { $0.movementIntensity }.reduce(0, +) / Double(epochs.count)
        if avgIntensity > 0.02 && avgIntensity < 0.1 {
            confidence += 0.2
        }

        // Check for lack of position changes (people move around more when actually sleeping)
        let totalPositionChanges = epochs.map { $0.positionChanges }.reduce(0, +)
        if totalPositionChanges < 2 {
            confidence += 0.2
        }

        // Check timing - this pattern sustained for >15 min is suspicious
        if epochs.count > 30 { // 30 epochs = 15 minutes
            confidence += 0.2
        }

        return min(1.0, confidence)
    }

    /// Detect transition to sleep (gradual decrease in movement)
    func detectSleepTransition(epochs: [SleepEpoch]) -> Bool {
        guard epochs.count >= 6 else { return false }

        let recent = Array(epochs.suffix(6))
        let intensities = recent.map { $0.movementIntensity }

        // Check for decreasing trend
        var decreasing = 0
        for i in 1..<intensities.count {
            if intensities[i] < intensities[i-1] {
                decreasing += 1
            }
        }

        // Also check final intensity is very low
        let finalIntensity = intensities.last ?? 1.0

        return decreasing >= 4 && finalIntensity < 0.03
    }
}
