//
//  SleepMonitoringEngine.swift
//  ZoeSleep Watch App
//
//  EXPERIMENTAL: Custom sleep monitoring engine that doesn't rely on Apple HealthKit.
//  Uses raw sensor data (accelerometer, heart rate, HRV) to determine sleep stages.
//  Designed to be more accurate than consumer devices by eliminating false positives.
//

import Foundation
import CoreMotion
import HealthKit
import WatchKit
import Combine

// MARK: - Sleep Monitoring State

enum SleepMonitoringState: Equatable {
    case idle
    case preparing
    case monitoring
    case paused
    case analyzing
    case completed
    case error(String)

    static func == (lhs: SleepMonitoringState, rhs: SleepMonitoringState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.preparing, .preparing), (.monitoring, .monitoring),
             (.paused, .paused), (.analyzing, .analyzing), (.completed, .completed):
            return true
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Raw Sensor Sample

/// A timestamped sensor reading
struct SensorSample: Codable {
    let timestamp: Date
    let type: SensorType
    let values: [Double]

    enum SensorType: String, Codable {
        case accelerometer      // [x, y, z] in g
        case gyroscope         // [x, y, z] in rad/s
        case heartRate         // [bpm]
        case hrv               // [SDNN in ms]
        case bloodOxygen       // [SpO2 %]
        case skinTemperature   // [celsius]
        case deviceMotion      // [pitch, roll, yaw, userAccelX, Y, Z]
    }
}

// MARK: - Sleep Epoch

/// A 30-second epoch with aggregated sensor data and classification
struct SleepEpoch: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date

    // Motion metrics
    var movementIntensity: Double      // 0-1, derived from accelerometer
    var movementCount: Int             // Number of significant movements
    var positionChanges: Int           // Major position shifts
    var microMovements: Int            // Small fidgets (awake indicator)

    // Heart metrics
    var avgHeartRate: Double?
    var minHeartRate: Double?
    var maxHeartRate: Double?
    var heartRateVariability: Double?  // SDNN
    var heartRateSlope: Double?        // Trend direction

    // Environmental
    var bloodOxygen: Double?
    var skinTemperature: Double?

    // Classification
    var classifiedStage: SleepStage?
    var stageConfidence: Double        // 0-1
    var isLikelyAwake: Bool           // False positive check
    var awakeConfidence: Double        // How sure we are they're awake

    // Timestamps for raw data ranges
    var rawDataStartIndex: Int
    var rawDataEndIndex: Int

    init(startTime: Date) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = startTime.addingTimeInterval(30)
        self.movementIntensity = 0
        self.movementCount = 0
        self.positionChanges = 0
        self.microMovements = 0
        self.stageConfidence = 0
        self.isLikelyAwake = false
        self.awakeConfidence = 0
        self.rawDataStartIndex = 0
        self.rawDataEndIndex = 0
    }
}

// MARK: - Sleep Monitoring Engine

/// The main coordinator for experimental sleep monitoring
@MainActor
class SleepMonitoringEngine: ObservableObject {
    static let shared = SleepMonitoringEngine()

    // MARK: - Published State

    @Published var state: SleepMonitoringState = .idle
    @Published var currentEpoch: SleepEpoch?
    @Published var epochs: [SleepEpoch] = []
    @Published var currentStage: SleepStage = .awake
    @Published var monitoringStartTime: Date?
    @Published var lastHeartRate: Double?
    @Published var lastMovementIntensity: Double = 0
    @Published var sleepOnsetDetected: Bool = false
    @Published var sleepOnsetTime: Date?

    // MARK: - Components

    private let motionAnalyzer = MotionAnalyzer()
    private let heartRateAnalyzer = HeartRateAnalyzer()
    private let stageClassifier = SleepStageClassifier()
    private let falsePositiveEliminator = FalsePositiveEliminator()

    /// ACCEL algorithm for jerk-based sleep-wake classification
    /// Reference: Ode et al., iScience 2022 - achieves >90% sensitivity, >80% specificity
    private let accelAlgorithm = ACCELAlgorithm()

    // MARK: - Sensor Management

    private let motionManager = CMMotionManager()
    private var healthStore: HKHealthStore?
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // MARK: - Data Storage

    private var rawSamples: [SensorSample] = []
    private var epochTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    struct Configuration {
        var epochDuration: TimeInterval = 30          // Standard 30-second epochs
        var accelerometerFrequency: Double = 50       // Hz
        var useHealthKitHeartRate: Bool = true        // Can be disabled
        var useBloodOxygen: Bool = true               // If available
        var falsePositiveThreshold: Double = 0.7      // Confidence threshold
        var minimumSleepDuration: TimeInterval = 300  // 5 min minimum sleep bout
    }

    var configuration = Configuration()

    // MARK: - Initialization

    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }

    // MARK: - Public API

    /// Start sleep monitoring session
    func startMonitoring() async throws {
        guard state == .idle else {
            throw SleepMonitoringError.alreadyMonitoring
        }

        state = .preparing

        // Request permissions
        try await requestPermissions()

        // Start sensors
        try startAccelerometer()

        if configuration.useHealthKitHeartRate {
            try await startHeartRateMonitoring()
        }

        // Initialize tracking
        monitoringStartTime = Date()
        rawSamples = []
        epochs = []
        sleepOnsetDetected = false
        sleepOnsetTime = nil

        // Start epoch processing
        startEpochTimer()

        state = .monitoring
        print("[SleepMonitor] Started monitoring at \(Date())")
    }

    /// Stop monitoring and analyze results
    func stopMonitoring() async -> SleepSession? {
        guard state == .monitoring || state == .paused else { return nil }

        state = .analyzing

        // Stop sensors
        stopAccelerometer()
        await stopHeartRateMonitoring()
        epochTimer?.invalidate()
        epochTimer = nil

        // Final epoch processing
        processCurrentEpoch()

        // Run full analysis
        let session = await analyzeSession()

        state = .completed
        print("[SleepMonitor] Completed monitoring. Epochs: \(epochs.count)")

        return session
    }

    /// Pause monitoring (e.g., bathroom break)
    func pauseMonitoring() {
        guard state == .monitoring else { return }
        state = .paused
        stopAccelerometer()
        epochTimer?.invalidate()
    }

    /// Resume after pause
    func resumeMonitoring() throws {
        guard state == .paused else { return }
        try startAccelerometer()
        startEpochTimer()
        state = .monitoring
    }

    /// Reset to idle state
    func reset() {
        epochTimer?.invalidate()
        epochTimer = nil
        stopAccelerometer()

        rawSamples = []
        epochs = []
        currentEpoch = nil
        monitoringStartTime = nil
        sleepOnsetDetected = false
        sleepOnsetTime = nil
        state = .idle

        // Reset all analyzers
        motionAnalyzer.resetEpoch()
        heartRateAnalyzer.resetEpoch()
        stageClassifier.reset()
        falsePositiveEliminator.reset()
        accelAlgorithm.reset()
    }

    // MARK: - Permissions

    private func requestPermissions() async throws {
        // Motion permissions are requested on first use

        // HealthKit permissions
        guard let healthStore = healthStore else { return }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
        ]

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }

    // MARK: - Accelerometer

    private func startAccelerometer() throws {
        guard motionManager.isAccelerometerAvailable else {
            throw SleepMonitoringError.sensorUnavailable("Accelerometer")
        }

        motionManager.accelerometerUpdateInterval = 1.0 / configuration.accelerometerFrequency

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }

            let sample = SensorSample(
                timestamp: Date(),
                type: .accelerometer,
                values: [data.acceleration.x, data.acceleration.y, data.acceleration.z]
            )

            Task { @MainActor in
                self.rawSamples.append(sample)
                self.motionAnalyzer.processAccelerometerSample(sample)
                self.lastMovementIntensity = self.motionAnalyzer.currentMovementIntensity

                // Feed data to ACCEL algorithm for jerk-based classification
                self.accelAlgorithm.processAccelerometerSample(
                    timestamp: sample.timestamp,
                    x: data.acceleration.x,
                    y: data.acceleration.y,
                    z: data.acceleration.z
                )
            }
        }

        // Also start device motion for better orientation tracking
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 10  // 10 Hz for orientation
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self = self, let motion = motion else { return }

                let sample = SensorSample(
                    timestamp: Date(),
                    type: .deviceMotion,
                    values: [
                        motion.attitude.pitch,
                        motion.attitude.roll,
                        motion.attitude.yaw,
                        motion.userAcceleration.x,
                        motion.userAcceleration.y,
                        motion.userAcceleration.z
                    ]
                )

                Task { @MainActor in
                    self.rawSamples.append(sample)
                }
            }
        }
    }

    private func stopAccelerometer() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Heart Rate Monitoring

    private func startHeartRateMonitoring() async throws {
        guard let healthStore = healthStore else {
            throw SleepMonitoringError.healthKitUnavailable
        }

        // Create a "sleep tracking" workout session for continuous HR
        // Note: .sleep is not available, use .mindAndBody for passive monitoring
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Set up heart rate observer
            workoutBuilder?.dataSource?.enableCollection(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!, predicate: nil)

            // Start the session
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            try await workoutBuilder?.beginCollection(at: startDate)

            // Observe heart rate updates
            setupHeartRateObserver()

        } catch {
            print("[SleepMonitor] Failed to start workout session: \(error)")
            throw SleepMonitoringError.workoutSessionFailed
        }
    }

    private func setupHeartRateObserver() {
        guard let healthStore = healthStore else { return }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHeartRateSamples(samples as? [HKQuantitySample] ?? [])
            }
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHeartRateSamples(samples as? [HKQuantitySample] ?? [])
            }
        }

        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKQuantitySample]) {
        for sample in samples {
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

            let sensorSample = SensorSample(
                timestamp: sample.startDate,
                type: .heartRate,
                values: [bpm]
            )

            Task { @MainActor in
                self.rawSamples.append(sensorSample)
                self.heartRateAnalyzer.processHeartRateSample(sensorSample)
                self.lastHeartRate = bpm
            }
        }
    }

    private func stopHeartRateMonitoring() async {
        guard let workoutSession = workoutSession,
              let workoutBuilder = workoutBuilder else { return }

        let endDate = Date()
        workoutSession.end()

        do {
            try await workoutBuilder.endCollection(at: endDate)
            try await workoutBuilder.finishWorkout()
        } catch {
            print("[SleepMonitor] Error ending workout: \(error)")
        }

        self.workoutSession = nil
        self.workoutBuilder = nil
    }

    // MARK: - Epoch Processing

    private func startEpochTimer() {
        currentEpoch = SleepEpoch(startTime: Date())

        epochTimer = Timer.scheduledTimer(withTimeInterval: configuration.epochDuration, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processCurrentEpoch()
                self?.currentEpoch = SleepEpoch(startTime: Date())
            }
        }
    }

    private func processCurrentEpoch() {
        guard var epoch = currentEpoch else { return }

        // Get motion metrics
        let motionMetrics = motionAnalyzer.getEpochMetrics()
        epoch.movementIntensity = motionMetrics.intensity
        epoch.movementCount = motionMetrics.movementCount
        epoch.positionChanges = motionMetrics.positionChanges
        epoch.microMovements = motionMetrics.microMovements

        // Get heart rate metrics
        let hrMetrics = heartRateAnalyzer.getEpochMetrics()
        epoch.avgHeartRate = hrMetrics.avgHeartRate
        epoch.minHeartRate = hrMetrics.minHeartRate
        epoch.maxHeartRate = hrMetrics.maxHeartRate
        epoch.heartRateVariability = hrMetrics.hrv
        epoch.heartRateSlope = hrMetrics.slope

        // Check for false positives (Netflix watching, etc.)
        let fpResult = falsePositiveEliminator.evaluate(epoch, recentEpochs: epochs.suffix(10).map { $0 })
        epoch.isLikelyAwake = fpResult.isLikelyAwake
        epoch.awakeConfidence = fpResult.confidence

        // Apply ACCEL algorithm for enhanced sleep-wake classification
        // ACCEL uses jerk (derivative of acceleration) with >90% sensitivity, >80% specificity
        if let accelResult = accelAlgorithm.getSleepWakeClassification() {
            // ACCEL says awake with high confidence - override if needed
            if !accelResult.isAsleep && accelResult.confidence > 0.7 {
                // Combine with false positive detection
                let combinedAwakeConfidence = max(epoch.awakeConfidence, accelResult.confidence)
                epoch.isLikelyAwake = true
                epoch.awakeConfidence = combinedAwakeConfidence
            }
            // ACCEL says asleep with high confidence - may override false positive
            else if accelResult.isAsleep && accelResult.confidence > 0.8 {
                // If ACCEL is very confident about sleep, reduce awake confidence
                if epoch.isLikelyAwake && accelResult.confidence > epoch.awakeConfidence {
                    epoch.isLikelyAwake = false
                    epoch.awakeConfidence = 1.0 - accelResult.confidence
                }
            }
        }

        // Classify sleep stage
        let classification = stageClassifier.classify(
            epoch,
            recentEpochs: epochs.suffix(5).map { $0 },
            chronotype: ChronotypeManager.shared.chronotype
        )
        epoch.classifiedStage = classification.stage
        epoch.stageConfidence = classification.confidence

        // Detect sleep onset
        if !sleepOnsetDetected && classification.stage != .awake && !epoch.isLikelyAwake {
            // Need sustained non-wake for sleep onset
            let recentNonWake = epochs.suffix(3).filter { $0.classifiedStage != .awake && !$0.isLikelyAwake }
            if recentNonWake.count >= 2 {
                sleepOnsetDetected = true
                sleepOnsetTime = epochs.suffix(3).first?.startTime ?? Date()
                print("[SleepMonitor] Sleep onset detected at \(sleepOnsetTime!)")
            }
        }

        // Store epoch
        epochs.append(epoch)
        currentStage = classification.stage

        // Reset analyzers for next epoch
        motionAnalyzer.resetEpoch()
        heartRateAnalyzer.resetEpoch()
    }

    // MARK: - Session Analysis

    private func analyzeSession() async -> SleepSession? {
        guard let startTime = monitoringStartTime else { return nil }

        // Apply smoothing to reduce noisy transitions
        smoothStageTransitions()

        // Build stage segments from epochs
        let segments = buildStageSegments()

        // Calculate session metrics
        let wakeTime = epochs.last?.endTime ?? Date()

        return SleepSession(
            id: UUID(),
            date: startTime,
            bedtime: startTime,
            wakeTime: wakeTime,
            stages: segments,
            heartRateData: buildHeartRateData(),
            respiratoryRate: nil,
            hrv: calculateAverageHRV(),
            skinTemperature: nil,
            bloodOxygen: nil,
            movementScore: calculateMovementScore()
        )
    }

    private func smoothStageTransitions() {
        // Don't allow single-epoch transitions to unlikely stages
        for i in 1..<(epochs.count - 1) {
            let prev = epochs[i - 1].classifiedStage
            let curr = epochs[i].classifiedStage
            let next = epochs[i + 1].classifiedStage

            // If this epoch is different from both neighbors, it's probably noise
            if curr != prev && curr != next && prev == next {
                epochs[i].classifiedStage = prev
            }
        }
    }

    private func buildStageSegments() -> [SleepStageSegment] {
        var segments: [SleepStageSegment] = []
        var currentStage: SleepStage?
        var segmentStart: Date?

        for epoch in epochs {
            guard let stage = epoch.classifiedStage else { continue }

            if stage != currentStage {
                // End previous segment
                if let prevStage = currentStage, let start = segmentStart {
                    segments.append(SleepStageSegment(
                        id: UUID(),
                        stage: prevStage,
                        startTime: start,
                        endTime: epoch.startTime
                    ))
                }

                // Start new segment
                currentStage = stage
                segmentStart = epoch.startTime
            }
        }

        // Close final segment
        if let stage = currentStage, let start = segmentStart {
            segments.append(SleepStageSegment(
                id: UUID(),
                stage: stage,
                startTime: start,
                endTime: epochs.last?.endTime ?? Date()
            ))
        }

        return segments
    }

    private func countAwakenings() -> Int {
        var count = 0
        var wasAsleep = false

        for epoch in epochs {
            let isAwake = epoch.classifiedStage == .awake || epoch.isLikelyAwake

            if wasAsleep && isAwake {
                count += 1
            }

            wasAsleep = !isAwake
        }

        return count
    }

    private func buildHeartRateData() -> [HeartRatePoint] {
        epochs.compactMap { epoch in
            guard let hr = epoch.avgHeartRate else { return nil }
            return HeartRatePoint(timestamp: epoch.startTime, bpm: Int(hr))
        }
    }

    private func calculateAverageHRV() -> Double? {
        let hrvValues = epochs.compactMap { $0.heartRateVariability }
        guard !hrvValues.isEmpty else { return nil }
        return hrvValues.reduce(0, +) / Double(hrvValues.count)
    }

    private func calculateMovementScore() -> Double {
        let intensities = epochs.map { $0.movementIntensity }
        guard !intensities.isEmpty else { return 0 }
        return intensities.reduce(0, +) / Double(intensities.count)
    }
}

// MARK: - Errors

enum SleepMonitoringError: Error, LocalizedError {
    case alreadyMonitoring
    case sensorUnavailable(String)
    case healthKitUnavailable
    case workoutSessionFailed
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .alreadyMonitoring:
            return "Sleep monitoring is already in progress"
        case .sensorUnavailable(let sensor):
            return "\(sensor) sensor is not available"
        case .healthKitUnavailable:
            return "HealthKit is not available on this device"
        case .workoutSessionFailed:
            return "Failed to start heart rate monitoring session"
        case .insufficientData:
            return "Not enough data to analyze sleep"
        }
    }
}
