//
//  HealthKitWatchManager.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  HealthKit integration specifically for Apple Watch
//

import HealthKit
import WatchKit
import Foundation
import Combine

@MainActor
class HealthKitWatchManager: ObservableObject {
    static let shared = HealthKitWatchManager()

    private let healthStore = HKHealthStore()
    @Published var lastNightSleep: SleepData?
    @Published var lastNightSleepSession: SleepSession?  // Detailed sleep stages
    @Published var todayActivity: ActivityData?
    @Published var heartRateData: [HeartRateReading] = []
    @Published var daylightExposure: DaylightExposureData?
    @Published var isAuthorized = false
    @Published var isLoadingSleepData = false

    // Watch-specific health data types
    private var watchHealthTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        // Time in Daylight available in watchOS 10+
        if #available(watchOS 10.0, *) {
            if let daylightType = HKObjectType.quantityType(forIdentifier: .timeInDaylight) {
                types.insert(daylightType)
            }
        }
        return types
    }
    
    private init() {
        checkHealthKitAvailability()
    }
    
    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        healthStore.requestAuthorization(toShare: [], read: watchHealthTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.loadInitialData()
                    self?.setupBackgroundObservers()
                } else if let error = error {
                    print("HealthKit authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func syncHealthData() {
        guard isAuthorized else { return }

        Task {
            await loadSleepData()
            await loadActivityData()
            await loadHeartRateData()
            await loadDaylightExposure()
        }
    }
    
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
    }
    
    private func loadInitialData() {
        Task {
            await loadSleepData()
            await loadActivityData()
            await loadHeartRateData()
            await loadDaylightExposure()
        }
    }
    
    private func setupBackgroundObservers() {
        // Set up observers for real-time health data updates
        for healthType in watchHealthTypes {
            if let quantityType = healthType as? HKQuantityType {
                setupObserver(for: quantityType)
            } else if let categoryType = healthType as? HKCategoryType {
                setupCategoryObserver(for: categoryType)
            }
        }
    }
    
    private func setupObserver(for quantityType: HKQuantityType) {
        let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Observer query error: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self?.syncHealthData()
            }
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery setup error: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupCategoryObserver(for categoryType: HKCategoryType) {
        let query = HKObserverQuery(sampleType: categoryType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Category observer query error: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self?.syncHealthData()
            }
        }
        
        healthStore.execute(query)
    }
    
    @MainActor
    private func loadSleepData() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfYesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday) ?? now
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: endOfYesterday, options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
                
                if let error = error {
                    print("Sleep data query error: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume()
                    return
                }
                
                let totalSleep = sleepSamples.reduce(0.0) { total, sample in
                    if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                        return total + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                    return total
                }
                
                DispatchQueue.main.async {
                    self?.lastNightSleep = SleepData(
                        duration: totalSleep / 3600.0, // Convert to hours
                        quality: self?.calculateSleepQuality(from: sleepSamples) ?? 0,
                        date: startOfYesterday
                    )
                }
                
                continuation.resume()
            }
            
            healthStore.execute(query)
        }
    }
    
    @MainActor
    private func loadActivityData() async {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // Load steps
        let steps = await loadQuantityData(type: stepType, predicate: predicate, unit: HKUnit.count())
        
        // Load active energy
        let activeEnergy = await loadQuantityData(type: energyType, predicate: predicate, unit: HKUnit.kilocalorie())
        
        // Load exercise time
        let exerciseTime = await loadQuantityData(type: exerciseType, predicate: predicate, unit: HKUnit.minute())
        
        self.todayActivity = ActivityData(
            steps: Int(steps),
            activeEnergy: activeEnergy,
            exerciseMinutes: Int(exerciseTime),
            date: startOfDay
        )
    }
    
    @MainActor
    private func loadHeartRateData() async {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 100, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { [weak self] _, samples, error in
                
                if let error = error {
                    print("Heart rate query error: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                
                guard let heartRateSamples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                
                let heartRateReadings = heartRateSamples.map { sample in
                    HeartRateReading(
                        value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())),
                        timestamp: sample.startDate
                    )
                }
                
                DispatchQueue.main.async {
                    self?.heartRateData = heartRateReadings
                }
                
                continuation.resume()
            }
            
            healthStore.execute(query)
        }
    }
    
    private func loadQuantityData(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                
                if let error = error {
                    print("Quantity query error: \(error.localizedDescription)")
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                continuation.resume(returning: value)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func calculateSleepQuality(from samples: [HKCategorySample]) -> Double {
        // Simple sleep quality calculation based on sleep continuity
        // In a real app, this would be more sophisticated
        let totalSamples = samples.count
        let asleepSamples = samples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }.count

        return totalSamples > 0 ? Double(asleepSamples) / Double(totalSamples) * 100 : 0
    }

    // MARK: - Daylight Exposure

    /// Load today's time in daylight from HealthKit (watchOS 10+)
    @MainActor
    private func loadDaylightExposure() async {
        guard #available(watchOS 10.0, *) else {
            print("Time in Daylight requires watchOS 10+")
            return
        }

        guard let daylightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else {
            print("Time in Daylight type not available")
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        // Also get morning light (before 10 AM) for circadian optimization
        let morningEnd = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
        let morningPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: morningEnd, options: .strictStartDate)

        // Load total daylight
        let totalMinutes = await loadDaylightMinutes(type: daylightType, predicate: predicate)

        // Load morning daylight
        let morningMinutes = await loadDaylightMinutes(type: daylightType, predicate: morningPredicate)

        self.daylightExposure = DaylightExposureData(
            totalMinutes: Int(totalMinutes),
            morningMinutes: Int(morningMinutes),
            targetMinutes: 90, // Recommended daily target
            date: startOfDay
        )

        print("Daylight exposure loaded: \(Int(totalMinutes)) min total, \(Int(morningMinutes)) min morning")
    }

    @available(watchOS 10.0, *)
    private func loadDaylightMinutes(type: HKQuantityType, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in

                if let error = error {
                    print("Daylight query error: \(error.localizedDescription)")
                    continuation.resume(returning: 0.0)
                    return
                }

                // Time in daylight is measured in seconds, convert to minutes
                let seconds = result?.sumQuantity()?.doubleValue(for: HKUnit.second()) ?? 0.0
                let minutes = seconds / 60.0
                continuation.resume(returning: minutes)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Detailed Sleep Stage Data (Real HealthKit)

    /// Load detailed sleep stages from HealthKit for last night
    /// This returns REAL data from Apple Watch sleep tracking
    func loadDetailedSleepStages() async -> SleepSession? {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] Not available on this device")
            return nil
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("[HealthKit] Sleep analysis type not available")
            return nil
        }

        await MainActor.run {
            isLoadingSleepData = true
        }

        let calendar = Calendar.current
        let now = Date()

        // Look for sleep from yesterday 6 PM to today noon (covers typical sleep window)
        let yesterdayEvening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now)!)!
        let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!

        let predicate = HKQuery.predicateForSamples(withStart: yesterdayEvening, end: todayNoon, options: .strictStartDate)

        let sleepSession: SleepSession? = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in

                if let error = error {
                    print("[HealthKit] Sleep query error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    print("[HealthKit] No sleep samples found")
                    continuation.resume(returning: nil)
                    return
                }

                // Log all sources found
                let allSources = Set(sleepSamples.map { $0.sourceRevision.source.name })
                print("[HealthKit] Found \(sleepSamples.count) sleep samples from sources: \(allSources)")

                // Watch app ALWAYS uses Apple Watch data only
                // Filter out Oura, Garmin, and other third-party sources
                let filteredSamples = sleepSamples.filter {
                    let name = $0.sourceRevision.source.name.lowercased()
                    return name.contains("watch") || name.contains("apple")
                }

                print("[HealthKit] Using \(filteredSamples.count)/\(sleepSamples.count) Apple Watch samples")

                guard !filteredSamples.isEmpty else {
                    print("[HealthKit] No samples after source filtering")
                    continuation.resume(returning: nil)
                    return
                }

                // Convert HealthKit samples to our sleep stage segments
                var segments: [SleepStageSegment] = []
                var bedtime: Date?
                var wakeTime: Date?

                for sample in filteredSamples {
                    // Map HealthKit sleep values to our SleepStage enum
                    let stage: SleepStage

                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        // In bed but not asleep - treat as awake
                        stage = .awake
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        // Generic asleep (older data) - treat as light sleep
                        stage = .lightN2
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        stage = .awake
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        // Core sleep = Light sleep (N1/N2)
                        stage = .lightN2
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        // Deep sleep (N3/N4)
                        stage = .deepN3
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        stage = .rem
                    default:
                        // Unknown - skip
                        continue
                    }

                    // Track bedtime and wake time
                    if bedtime == nil || sample.startDate < bedtime! {
                        bedtime = sample.startDate
                    }
                    if wakeTime == nil || sample.endDate > wakeTime! {
                        wakeTime = sample.endDate
                    }

                    let segment = SleepStageSegment(
                        id: UUID(),
                        stage: stage,
                        startTime: sample.startDate,
                        endTime: sample.endDate
                    )
                    segments.append(segment)

                    print("[HealthKit] Stage: \(stage.displayName) from \(sample.startDate) to \(sample.endDate)")
                }

                guard let actualBedtime = bedtime, let actualWakeTime = wakeTime, !segments.isEmpty else {
                    print("[HealthKit] Could not determine bedtime/waketime")
                    continuation.resume(returning: nil)
                    return
                }

                // Sort segments by start time
                segments.sort { $0.startTime < $1.startTime }

                // CRITICAL: Merge overlapping segments to prevent double-counting
                // HealthKit can return overlapping samples from multiple sources (Watch, iPhone, etc.)
                segments = self.mergeOverlappingSegments(segments)

                // Create the sleep session with real data
                let session = SleepSession(
                    id: UUID(),
                    date: now,
                    bedtime: actualBedtime,
                    wakeTime: actualWakeTime,
                    stages: segments,
                    heartRateData: nil,  // Could be loaded separately
                    respiratoryRate: nil,
                    hrv: nil,
                    skinTemperature: nil,
                    bloodOxygen: nil,
                    movementScore: nil
                )

                let totalHours = session.totalDurationHours
                let efficiency = session.sleepEfficiency
                let percentages = session.stagePercentages

                print("[HealthKit] Sleep session created:")
                print("  Duration: \(String(format: "%.1f", totalHours)) hours")
                print("  Efficiency: \(Int(efficiency * 100))%")
                print("  Deep: \(Int((percentages[.deep] ?? 0) * 100))%")
                print("  REM: \(Int((percentages[.rem] ?? 0) * 100))%")
                print("  Light: \(Int((percentages[.light] ?? 0) * 100))%")
                print("  Awake: \(Int((percentages[.awake] ?? 0) * 100))%")

                continuation.resume(returning: session)
            }

            healthStore.execute(query)
        }

        await MainActor.run {
            self.lastNightSleepSession = sleepSession
            isLoadingSleepData = false
        }

        return sleepSession
    }

    // MARK: - Segment Merging (Fix for Overlapping Samples)

    /// Merge overlapping sleep segments to prevent double-counting time
    /// When segments overlap, prioritize the most specific sleep stage
    nonisolated private func mergeOverlappingSegments(_ segments: [SleepStageSegment]) -> [SleepStageSegment] {
        guard !segments.isEmpty else { return [] }

        // Priority: higher value = more important to keep when merging
        // Deep sleep > REM > Light > Awake (we want to count the most restorative stage)
        func stagePriority(_ stage: SleepStage) -> Int {
            switch stage {
            case .deepN4: return 6
            case .deepN3: return 5
            case .rem: return 4
            case .remLight: return 3
            case .lightN2: return 2
            case .lightN1: return 1
            case .awake: return 0
            }
        }

        // Create time-point events for all segment starts and ends
        struct TimeEvent: Comparable {
            let time: Date
            let isStart: Bool
            let segment: SleepStageSegment

            static func == (lhs: TimeEvent, rhs: TimeEvent) -> Bool {
                lhs.time == rhs.time && lhs.isStart == rhs.isStart
            }

            static func < (lhs: TimeEvent, rhs: TimeEvent) -> Bool {
                if lhs.time == rhs.time {
                    // Process starts before ends at same time
                    return lhs.isStart && !rhs.isStart
                }
                return lhs.time < rhs.time
            }
        }

        var events: [TimeEvent] = []
        for segment in segments {
            events.append(TimeEvent(time: segment.startTime, isStart: true, segment: segment))
            events.append(TimeEvent(time: segment.endTime, isStart: false, segment: segment))
        }
        events.sort()

        // Process events to create non-overlapping segments
        var result: [SleepStageSegment] = []
        var activeSegments: [SleepStageSegment] = []
        var lastTime: Date?

        for event in events {
            // If we have active segments and time has advanced, create output segment
            if let last = lastTime, last < event.time, !activeSegments.isEmpty {
                // Find highest priority stage among active segments
                let bestSegment = activeSegments.max(by: { stagePriority($0.stage) < stagePriority($1.stage) })!

                let merged = SleepStageSegment(
                    id: UUID(),
                    stage: bestSegment.stage,
                    startTime: last,
                    endTime: event.time
                )
                result.append(merged)
            }

            // Update active segments
            if event.isStart {
                activeSegments.append(event.segment)
            } else {
                activeSegments.removeAll { $0.id == event.segment.id }
            }

            lastTime = event.time
        }

        // Merge consecutive segments with the same stage
        var consolidated: [SleepStageSegment] = []
        for segment in result {
            if let last = consolidated.last, last.stage == segment.stage, last.endTime == segment.startTime {
                // Extend the previous segment
                consolidated[consolidated.count - 1] = SleepStageSegment(
                    id: last.id,
                    stage: last.stage,
                    startTime: last.startTime,
                    endTime: segment.endTime
                )
            } else {
                consolidated.append(segment)
            }
        }

        print("[HealthKit] Merged \(segments.count) overlapping samples into \(consolidated.count) segments")

        return consolidated
    }

    // MARK: - Sleep Data Source Discovery

    /// Query HealthKit for all sources that have contributed sleep data
    /// Returns list of available sources (Apple Watch, Oura, etc.)
    func getAvailableSleepDataSources() async -> [WatchSleepDataSource] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("[HealthKit] Sleep analysis type not available")
            return []
        }

        return await withCheckedContinuation { continuation in
            let query = HKSourceQuery(sampleType: sleepType, samplePredicate: nil) { _, sources, error in
                if let error = error {
                    print("[HealthKit] Source query error: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let sources = sources else {
                    continuation.resume(returning: [])
                    return
                }

                let dataSources = sources.map { WatchSleepDataSource.from(source: $0) }
                    .sorted { $0.name < $1.name }

                print("[HealthKit] Found \(dataSources.count) sleep data sources:")
                for source in dataSources {
                    print("  - \(source.name) (\(source.id))")
                }

                continuation.resume(returning: dataSources)
            }

            healthStore.execute(query)
        }
    }
}

// Watch-specific health data models
struct SleepData {
    let duration: Double // in hours
    let quality: Double // percentage 0-100
    let date: Date
}

struct ActivityData {
    let steps: Int
    let activeEnergy: Double // in kcal
    let exerciseMinutes: Int
    let date: Date
}

struct HeartRateReading {
    let value: Double // BPM
    let timestamp: Date
}

struct DaylightExposureData {
    let totalMinutes: Int      // Total time in daylight today
    let morningMinutes: Int    // Morning light exposure (before 10 AM)
    let targetMinutes: Int     // Daily target (default 90 min)
    let date: Date

    var percentOfTarget: Int {
        guard targetMinutes > 0 else { return 0 }
        return min(100, (totalMinutes * 100) / targetMinutes)
    }

    var needsMoreLight: Bool {
        totalMinutes < targetMinutes
    }
}

/// Represents a sleep data source from HealthKit (e.g., Apple Watch, Oura Ring)
struct WatchSleepDataSource: Identifiable, Hashable, Codable {
    let id: String       // bundleIdentifier
    let name: String     // Human-readable name (e.g., "Apple Watch", "Oura")

    var isAppleWatch: Bool {
        name.lowercased().contains("watch")
    }

    static func from(source: HKSource) -> WatchSleepDataSource {
        WatchSleepDataSource(
            id: source.bundleIdentifier,
            name: source.name
        )
    }
}