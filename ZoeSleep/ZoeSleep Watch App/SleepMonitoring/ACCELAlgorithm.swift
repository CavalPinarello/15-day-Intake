//
//  ACCELAlgorithm.swift
//  ZoeSleep Watch App
//
//  Implementation of the ACCEL (ACceleration-based Classification and Estimation
//  of Long-term sleep-wake cycles) algorithm from Ode et al., iScience 2022.
//
//  Key insights from the paper:
//  - Uses JERK (derivative of acceleration) instead of raw acceleration
//  - Jerk reduces individual differences in acceleration variability
//  - Power spectrum of jerk (0-2 Hz) provides 60-dimensional features
//  - Uses 9 epochs (current + 4 before + 4 after) for classification
//  - Achieves >90% sensitivity and >80% specificity for sleep-wake
//
//  Reference: https://doi.org/10.1016/j.isci.2021.103727
//

import Foundation
import Accelerate

// MARK: - ACCEL Configuration

struct ACCELConfiguration {
    /// Epoch duration in seconds (standard is 30s)
    var epochDuration: TimeInterval = 30.0

    /// Number of neighboring epochs to include (k=4 means 9 total epochs)
    var neighboringEpochs: Int = 4

    /// Frequency range for power spectrum (0-2 Hz)
    var minFrequency: Double = 0.0
    var maxFrequency: Double = 2.0

    /// Number of frequency bins (60 dimensions per epoch as in paper)
    var frequencyBins: Int = 60

    /// Sampling rate of accelerometer in Hz
    var samplingRate: Double = 50.0

    /// Threshold for sleep-wake classification
    var sleepThreshold: Double = 0.5

    /// Minimum stillness standard deviation for non-wear detection (13 mg)
    var nonWearStdThreshold: Double = 0.013

    /// Minimum value range for non-wear detection (50 mg)
    var nonWearRangeThreshold: Double = 0.050
}

// MARK: - Jerk Sample

/// Represents jerk (derivative of acceleration) at a point in time
struct JerkSample {
    let timestamp: Date
    let x: Double  // g/s
    let y: Double  // g/s
    let z: Double  // g/s

    /// L2 norm of jerk vector
    var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }
}

// MARK: - ACCEL Epoch Features

/// Features extracted from one epoch for ACCEL classification
struct ACCELEpochFeatures {
    let epochIndex: Int
    let startTime: Date
    let endTime: Date

    /// Power spectrum of jerk (0-2 Hz), 60 dimensions
    let jerkPowerSpectrum: [Double]

    /// Raw acceleration statistics for non-wear detection
    let accelerationStdDev: Double
    let accelerationRange: Double

    /// Computed properties
    var isLikelyNonWear: Bool {
        accelerationStdDev <= 0.013 || accelerationRange <= 0.050
    }

    /// Total power in spectrum (for debugging)
    var totalPower: Double {
        jerkPowerSpectrum.reduce(0, +)
    }
}

// MARK: - ACCEL Classification Result

struct ACCELClassificationResult {
    let epochIndex: Int
    let timestamp: Date
    let isAsleep: Bool
    let sleepProbability: Double
    let confidence: Double
    let features: ACCELEpochFeatures?

    /// Non-wear detected
    let isNonWear: Bool
}

// MARK: - ACCEL Algorithm

/// Implementation of the jerk-based ACCEL algorithm for sleep-wake classification
class ACCELAlgorithm {

    // MARK: - Configuration

    var config = ACCELConfiguration()

    // MARK: - State

    /// Raw acceleration samples for current epoch
    private var currentEpochSamples: [(timestamp: Date, x: Double, y: Double, z: Double)] = []

    /// Processed epoch features buffer (for sliding window)
    private var epochFeaturesBuffer: [ACCELEpochFeatures] = []

    /// Classification history
    private var classificationHistory: [ACCELClassificationResult] = []

    /// Current epoch index
    private var currentEpochIndex: Int = 0

    /// Epoch start time
    private var epochStartTime: Date?

    // MARK: - Pre-trained Weights (Simplified Decision Tree)

    /// Frequency band weights learned from the paper's findings
    /// Higher weights for 0.5-1.5 Hz range (pulse-like signals during sleep)
    private let frequencyWeights: [Double] = {
        var weights = [Double](repeating: 1.0, count: 60)
        // The paper found that pulse-like signals (~1 Hz) are detectable during sleep
        // Lower frequencies (0-0.5 Hz) relate to slow movements
        // Higher frequencies (1.5-2 Hz) relate to faster movements
        for i in 0..<60 {
            let freq = Double(i) / 30.0  // 0-2 Hz range
            if freq >= 0.5 && freq <= 1.5 {
                // Pulse range - important for sleep detection
                weights[i] = 2.0
            } else if freq < 0.3 {
                // Very low frequency - body position changes
                weights[i] = 1.5
            } else {
                // Higher frequencies - more movement
                weights[i] = 1.0
            }
        }
        return weights
    }()

    // MARK: - Processing

    /// Process incoming accelerometer sample
    func processAccelerometerSample(timestamp: Date, x: Double, y: Double, z: Double) {
        // Initialize epoch start if needed
        if epochStartTime == nil {
            epochStartTime = timestamp
        }

        currentEpochSamples.append((timestamp, x, y, z))

        // Check if epoch is complete
        if let start = epochStartTime,
           timestamp.timeIntervalSince(start) >= config.epochDuration {
            processCompletedEpoch()
        }
    }

    /// Process a batch of samples from SensorSample
    func processSensorSample(_ sample: SensorSample) {
        guard sample.type == .accelerometer, sample.values.count >= 3 else { return }
        processAccelerometerSample(
            timestamp: sample.timestamp,
            x: sample.values[0],
            y: sample.values[1],
            z: sample.values[2]
        )
    }

    // MARK: - Epoch Processing

    private func processCompletedEpoch() {
        guard currentEpochSamples.count >= 10 else {
            resetCurrentEpoch()
            return
        }

        let features = extractFeatures(from: currentEpochSamples, epochIndex: currentEpochIndex)
        epochFeaturesBuffer.append(features)

        // Keep buffer size manageable (need k*2 + 1 epochs for sliding window)
        let maxBufferSize = config.neighboringEpochs * 2 + 10
        if epochFeaturesBuffer.count > maxBufferSize {
            epochFeaturesBuffer.removeFirst()
        }

        // Try to classify the epoch that now has enough context
        // We can classify epoch at index (buffer.count - neighboringEpochs - 1)
        if epochFeaturesBuffer.count > config.neighboringEpochs {
            let targetIndex = epochFeaturesBuffer.count - config.neighboringEpochs - 1
            if targetIndex >= 0 && targetIndex < epochFeaturesBuffer.count {
                classifyEpoch(at: targetIndex)
            }
        }

        currentEpochIndex += 1
        resetCurrentEpoch()
    }

    private func resetCurrentEpoch() {
        currentEpochSamples = []
        epochStartTime = Date()
    }

    // MARK: - Feature Extraction

    /// Extract ACCEL features from raw acceleration samples
    private func extractFeatures(
        from samples: [(timestamp: Date, x: Double, y: Double, z: Double)],
        epochIndex: Int
    ) -> ACCELEpochFeatures {

        guard let firstSample = samples.first, let lastSample = samples.last else {
            return createEmptyFeatures(epochIndex: epochIndex)
        }

        // Step 1: Calculate jerk (derivative of acceleration)
        let jerkSamples = calculateJerk(from: samples)

        // Step 2: Calculate power spectrum of jerk magnitude (0-2 Hz)
        let jerkMagnitudes = jerkSamples.map { $0.magnitude }
        let powerSpectrum = calculatePowerSpectrum(
            signal: jerkMagnitudes,
            samplingRate: config.samplingRate,
            numBins: config.frequencyBins,
            maxFrequency: config.maxFrequency
        )

        // Step 3: Calculate raw acceleration statistics for non-wear detection
        let xValues = samples.map { $0.x }
        let yValues = samples.map { $0.y }
        let zValues = samples.map { $0.z }

        let stdDevs = [
            standardDeviation(xValues),
            standardDeviation(yValues),
            standardDeviation(zValues)
        ].sorted()

        // Break up range calculations for compiler performance
        let xRange = (xValues.max() ?? 0) - (xValues.min() ?? 0)
        let yRange = (yValues.max() ?? 0) - (yValues.min() ?? 0)
        let zRange = (zValues.max() ?? 0) - (zValues.min() ?? 0)
        let ranges = [xRange, yRange, zRange].sorted()

        // Use second-largest values as per the paper
        let stdDev = stdDevs.count >= 2 ? stdDevs[1] : stdDevs.first ?? 0
        let range = ranges.count >= 2 ? ranges[1] : ranges.first ?? 0

        return ACCELEpochFeatures(
            epochIndex: epochIndex,
            startTime: firstSample.timestamp,
            endTime: lastSample.timestamp,
            jerkPowerSpectrum: powerSpectrum,
            accelerationStdDev: stdDev,
            accelerationRange: range
        )
    }

    /// Calculate jerk (time derivative of acceleration)
    private func calculateJerk(
        from samples: [(timestamp: Date, x: Double, y: Double, z: Double)]
    ) -> [JerkSample] {

        guard samples.count >= 2 else { return [] }

        var jerkSamples: [JerkSample] = []

        for i in 1..<samples.count {
            let current = samples[i]
            let previous = samples[i - 1]

            let dt = current.timestamp.timeIntervalSince(previous.timestamp)
            guard dt > 0 else { continue }

            // Jerk = d(acceleration)/dt
            let jerkX = (current.x - previous.x) / dt
            let jerkY = (current.y - previous.y) / dt
            let jerkZ = (current.z - previous.z) / dt

            jerkSamples.append(JerkSample(
                timestamp: current.timestamp,
                x: jerkX,
                y: jerkY,
                z: jerkZ
            ))
        }

        return jerkSamples
    }

    /// Calculate power spectrum using FFT
    private func calculatePowerSpectrum(
        signal: [Double],
        samplingRate: Double,
        numBins: Int,
        maxFrequency: Double
    ) -> [Double] {

        guard !signal.isEmpty else {
            return [Double](repeating: 0, count: numBins)
        }

        // Pad signal to power of 2 for FFT efficiency
        let n = signal.count
        let log2n = vDSP_Length(ceil(log2(Double(n))))
        let fftSize = Int(1 << log2n)

        var paddedSignal = signal
        if paddedSignal.count < fftSize {
            paddedSignal.append(contentsOf: [Double](repeating: 0, count: fftSize - paddedSignal.count))
        }

        // Apply Hann window to reduce spectral leakage
        var window = [Double](repeating: 0, count: fftSize)
        vDSP_hann_windowD(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var windowedSignal = [Double](repeating: 0, count: fftSize)
        vDSP_vmulD(paddedSignal, 1, window, 1, &windowedSignal, 1, vDSP_Length(fftSize))

        // Prepare for FFT
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return [Double](repeating: 0, count: numBins)
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        // Split complex format
        var realPart = [Double](repeating: 0, count: fftSize / 2)
        var imagPart = [Double](repeating: 0, count: fftSize / 2)

        // Convert to split complex
        windowedSignal.withUnsafeBufferPointer { signalPtr in
            realPart.withUnsafeMutableBufferPointer { realPtr in
                imagPart.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPDoubleSplitComplex(
                        realp: realPtr.baseAddress!,
                        imagp: imagPtr.baseAddress!
                    )
                    vDSP_ctozD(
                        UnsafePointer<DSPDoubleComplex>(OpaquePointer(signalPtr.baseAddress!)),
                        2,
                        &splitComplex,
                        1,
                        vDSP_Length(fftSize / 2)
                    )

                    // Perform FFT
                    vDSP_fft_zripD(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
                }
            }
        }

        // Calculate power spectrum (magnitude squared)
        var magnitudeSquared = [Double](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize / 2 {
            magnitudeSquared[i] = realPart[i] * realPart[i] + imagPart[i] * imagPart[i]
        }

        // Convert to dB scale
        var powerSpectrum = [Double](repeating: 0, count: fftSize / 2)
        var one: Double = 1.0
        vDSP_vsaddD(magnitudeSquared, 1, &one, &powerSpectrum, 1, vDSP_Length(fftSize / 2))

        for i in 0..<powerSpectrum.count {
            powerSpectrum[i] = 10 * log10(powerSpectrum[i] + 1e-10)
        }

        // Extract bins in 0-2 Hz range
        let frequencyResolution = samplingRate / Double(fftSize)
        let maxBinIndex = Int(maxFrequency / frequencyResolution)

        // Resample to exactly numBins
        var result = [Double](repeating: 0, count: numBins)
        let binWidth = Double(min(maxBinIndex, powerSpectrum.count)) / Double(numBins)

        for i in 0..<numBins {
            let startBin = Int(Double(i) * binWidth)
            let endBin = min(Int(Double(i + 1) * binWidth), powerSpectrum.count)

            if startBin < endBin && startBin < powerSpectrum.count {
                var sum: Double = 0
                for j in startBin..<endBin {
                    sum += powerSpectrum[j]
                }
                result[i] = sum / Double(endBin - startBin)
            }
        }

        return result
    }

    // MARK: - Classification

    /// Classify an epoch using the sliding window approach
    private func classifyEpoch(at bufferIndex: Int) {
        let targetFeatures = epochFeaturesBuffer[bufferIndex]

        // Check for non-wear
        if targetFeatures.isLikelyNonWear {
            let result = ACCELClassificationResult(
                epochIndex: targetFeatures.epochIndex,
                timestamp: targetFeatures.startTime,
                isAsleep: false,
                sleepProbability: 0,
                confidence: 0.9,
                features: targetFeatures,
                isNonWear: true
            )
            classificationHistory.append(result)
            return
        }

        // Build large feature vector from surrounding epochs
        var largeFeature: [Double] = []

        let startIndex = max(0, bufferIndex - config.neighboringEpochs)
        let endIndex = min(epochFeaturesBuffer.count - 1, bufferIndex + config.neighboringEpochs)

        for i in startIndex...endIndex {
            largeFeature.append(contentsOf: epochFeaturesBuffer[i].jerkPowerSpectrum)
        }

        // Classify using simplified decision tree (approximating XGBoost)
        let sleepProbability = classifyWithFeatures(largeFeature, targetFeatures: targetFeatures)
        let isAsleep = sleepProbability > config.sleepThreshold

        // Calculate confidence based on how far from threshold
        let confidence = abs(sleepProbability - config.sleepThreshold) * 2

        let result = ACCELClassificationResult(
            epochIndex: targetFeatures.epochIndex,
            timestamp: targetFeatures.startTime,
            isAsleep: isAsleep,
            sleepProbability: sleepProbability,
            confidence: min(1.0, confidence),
            features: targetFeatures,
            isNonWear: false
        )

        classificationHistory.append(result)
    }

    /// Simplified classifier based on ACCEL paper findings
    private func classifyWithFeatures(_ largeFeature: [Double], targetFeatures: ACCELEpochFeatures) -> Double {
        // The paper found that jerk PS in 0-2 Hz range is highly predictive
        // Key findings:
        // 1. Lower total jerk power = more likely asleep
        // 2. Pulse-like signals (0.5-1.5 Hz) visible during sleep
        // 3. Subsequent epochs more important than preceding

        // Calculate weighted sum of power spectrum
        var weightedPower: Double = 0
        let targetPS = targetFeatures.jerkPowerSpectrum

        for i in 0..<min(targetPS.count, frequencyWeights.count) {
            weightedPower += targetPS[i] * frequencyWeights[i]
        }

        // Normalize to 0-1 range
        // Lower power = higher sleep probability
        _ = (weightedPower + 100) / 200  // Rough normalization for dB scale (reserved for future ML model)

        // Calculate total activity level
        let totalPower = targetPS.reduce(0, +)
        let activityLevel = (totalPower + 100) / 150

        // High activity = wake, low activity = sleep
        // But need to account for "engaged stillness" (watching TV)
        var sleepProbability = 1.0 - min(1.0, max(0, activityLevel))

        // Check for pulse-like signal (indicates actual sleep vs lying still awake)
        let pulseRangeStart = 15  // ~0.5 Hz
        let pulseRangeEnd = 45    // ~1.5 Hz
        let pulsePower = targetPS[pulseRangeStart..<pulseRangeEnd].reduce(0, +)
        let totalRangePower = targetPS.reduce(0, +)

        let pulseRatio = totalRangePower != 0 ? pulsePower / totalRangePower : 0

        // Strong pulse signal during stillness = likely actually asleep
        if pulseRatio > 0.4 && activityLevel < 0.3 {
            sleepProbability += 0.2
        }

        // Very high activity = definitely awake
        if activityLevel > 0.6 {
            sleepProbability = max(0, sleepProbability - 0.3)
        }

        // Use surrounding epochs (subsequent epochs have higher weight per paper)
        if largeFeature.count > config.frequencyBins {
            // Check subsequent epochs
            let subsequentStart = config.frequencyBins * (config.neighboringEpochs + 1)
            if subsequentStart + config.frequencyBins <= largeFeature.count {
                let subsequentPower = largeFeature[subsequentStart..<(subsequentStart + config.frequencyBins)].reduce(0, +)
                let subsequentActivity = (subsequentPower + 100) / 150

                // If subsequent epochs show continued low activity, more likely asleep
                if subsequentActivity < 0.3 {
                    sleepProbability += 0.1
                }
            }
        }

        return min(1.0, max(0, sleepProbability))
    }

    // MARK: - Public Interface

    /// Get the latest classification result
    func getLatestClassification() -> ACCELClassificationResult? {
        classificationHistory.last
    }

    /// Get classification for a specific epoch
    func getClassification(forEpoch index: Int) -> ACCELClassificationResult? {
        classificationHistory.first { $0.epochIndex == index }
    }

    /// Get all classifications
    func getAllClassifications() -> [ACCELClassificationResult] {
        classificationHistory
    }

    /// Get sleep-wake classification for use with SleepStageClassifier
    func getSleepWakeClassification() -> (isAsleep: Bool, confidence: Double)? {
        guard let latest = classificationHistory.last, !latest.isNonWear else {
            return nil
        }
        return (latest.isAsleep, latest.confidence)
    }

    /// Reset all state
    func reset() {
        currentEpochSamples = []
        epochFeaturesBuffer = []
        classificationHistory = []
        currentEpochIndex = 0
        epochStartTime = nil
    }

    // MARK: - Utility Functions

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }

    private func createEmptyFeatures(epochIndex: Int) -> ACCELEpochFeatures {
        ACCELEpochFeatures(
            epochIndex: epochIndex,
            startTime: Date(),
            endTime: Date(),
            jerkPowerSpectrum: [Double](repeating: 0, count: config.frequencyBins),
            accelerationStdDev: 0,
            accelerationRange: 0
        )
    }
}

// MARK: - Integration with SleepEpoch

extension ACCELAlgorithm {

    /// Update a SleepEpoch with ACCEL classification results
    func enhanceEpoch(_ epoch: inout SleepEpoch) {
        guard let classification = getClassification(forEpoch: epoch.rawDataStartIndex) else {
            return
        }

        // If ACCEL says awake with high confidence, flag the epoch
        if !classification.isAsleep && classification.confidence > 0.6 {
            epoch.isLikelyAwake = true
            epoch.awakeConfidence = max(epoch.awakeConfidence, classification.confidence)
        }

        // If ACCEL says asleep with high confidence and epoch was marked awake,
        // reconsider (might be actual sleep, not Netflix watching)
        if classification.isAsleep && classification.confidence > 0.7 && epoch.isLikelyAwake {
            // Check if confidence is higher than false positive confidence
            if classification.confidence > epoch.awakeConfidence {
                epoch.isLikelyAwake = false
                epoch.awakeConfidence = 1.0 - classification.sleepProbability
            }
        }
    }
}
