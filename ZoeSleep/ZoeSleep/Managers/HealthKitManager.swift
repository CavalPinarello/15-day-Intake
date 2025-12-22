//
//  HealthKitManager.swift
//  ZOE Sleep Platform
//
//  HealthKit integration for syncing sleep, heart rate, and activity data
//

import Foundation
import HealthKit

/// Demographics data fetched from Apple Health
struct HealthKitDemographics {
    var dateOfBirth: Date?
    var biologicalSex: String?
    var heightCm: Double?
    var weightKg: Double?

    /// Calculate age from date of birth
    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dob, to: now)
        return ageComponents.year
    }
}

// MARK: - Sleep Data Source Tracking

/// Tracks the source device/app that contributed sleep data
struct SleepDataSource: Codable, Equatable {
    let name: String           // e.g., "Apple Watch", "Oura", "Fitbit"
    let bundleIdentifier: String
    let priority: Int          // 1 = highest (Apple Watch), 2 = iPhone, 3 = third-party

    /// Create a SleepDataSource from an HKSourceRevision
    static func from(sourceRevision: HKSourceRevision) -> SleepDataSource {
        let name = sourceRevision.source.name
        let bundleId = sourceRevision.source.bundleIdentifier

        // Priority assignment: Apple Watch > iPhone native > third-party
        let priority: Int
        if name.lowercased().contains("apple watch") ||
           name.lowercased().contains("watch") {
            priority = 1  // Apple Watch = highest priority
        } else if bundleId.hasPrefix("com.apple") {
            priority = 2  // iPhone native apps
        } else {
            priority = 3  // Third-party (Oura, Fitbit, WHOOP, Garmin, etc.)
        }

        return SleepDataSource(name: name, bundleIdentifier: bundleId, priority: priority)
    }
}

/// Enhanced sleep sample with source metadata for deduplication
struct SourcedSleepSample {
    let sample: HKCategorySample
    let source: SleepDataSource
    let stage: String
    let durationMins: Int
    let startTime: Date
    let endTime: Date
}

@MainActor
class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var demographics: HealthKitDemographics = HealthKitDemographics()

    // API Configuration
    private let apiService = APIService.shared
    private var authManager: AuthenticationManager?

    init(authManager: AuthenticationManager? = nil) {
        self.authManager = authManager
    }
    
    // Check if HealthKit is available
    var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    // Request authorization for all required data types
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard isHealthKitAvailable else {
            completion(false, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"]))
            return
        }
        
        // Define data types to read
        var readTypes: Set<HKObjectType> = []
        
        // Sleep Analysis
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)
        }
        
        // Heart Rate
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRateType)
        }
        
        // Heart Rate Variability
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            readTypes.insert(hrvType)
        }
        
        // Resting Heart Rate
        if let restingHRType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            readTypes.insert(restingHRType)
        }
        
        // Steps
        if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(stepsType)
        }
        
        // Active Energy
        if let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergyType)
        }
        
        // Exercise Time
        if let exerciseTimeType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            readTypes.insert(exerciseTimeType)
        }
        
        // Respiratory Rate
        if let respiratoryRateType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            readTypes.insert(respiratoryRateType)
        }
        
        // Oxygen Saturation
        if let oxygenSaturationType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            readTypes.insert(oxygenSaturationType)
        }
        
        // Workouts
        readTypes.insert(HKObjectType.workoutType())

        // MARK: - Demographics (for auto-filling questionnaire)

        // Date of Birth (Characteristic - read-only)
        if let dobType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            readTypes.insert(dobType)
        }

        // Biological Sex (Characteristic - read-only)
        if let sexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            readTypes.insert(sexType)
        }

        // Height (Quantity - can change over time)
        if let heightType = HKObjectType.quantityType(forIdentifier: .height) {
            readTypes.insert(heightType)
        }

        // Body Mass / Weight (Quantity - can change over time)
        if let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            readTypes.insert(weightType)
        }

        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    // Automatically fetch demographics after authorization
                    self.fetchDemographics()
                }
                completion(success, error)
            }
        }
    }
    
    // MARK: - Demographics Data (for auto-filling questionnaire)

    /// Fetches all available demographic data from HealthKit
    /// This includes: Date of Birth, Biological Sex, Height, and Weight
    func fetchDemographics() {
        var newDemographics = HealthKitDemographics()

        // Fetch Date of Birth (characteristic - set once in Health app)
        do {
            let dobComponents = try healthStore.dateOfBirthComponents()
            newDemographics.dateOfBirth = Calendar.current.date(from: dobComponents)
        } catch {
            print("[HealthKit] Could not fetch date of birth: \(error.localizedDescription)")
        }

        // Fetch Biological Sex (characteristic - set once in Health app)
        do {
            let biologicalSex = try healthStore.biologicalSex()
            switch biologicalSex.biologicalSex {
            case .female:
                newDemographics.biologicalSex = "Female"
            case .male:
                newDemographics.biologicalSex = "Male"
            case .other:
                newDemographics.biologicalSex = "Other"
            case .notSet:
                newDemographics.biologicalSex = nil
            @unknown default:
                newDemographics.biologicalSex = nil
            }
        } catch {
            print("[HealthKit] Could not fetch biological sex: \(error.localizedDescription)")
        }

        // Fetch Height (most recent sample)
        fetchMostRecentHeight { height in
            DispatchQueue.main.async {
                self.demographics.heightCm = height
            }
        }

        // Fetch Weight (most recent sample)
        fetchMostRecentWeight { weight in
            DispatchQueue.main.async {
                self.demographics.weightKg = weight
            }
        }

        // Update published demographics (DOB and Sex are synchronous)
        DispatchQueue.main.async {
            self.demographics.dateOfBirth = newDemographics.dateOfBirth
            self.demographics.biologicalSex = newDemographics.biologicalSex
        }
    }

    /// Fetches the most recent height measurement from HealthKit
    private func fetchMostRecentHeight(completion: @escaping (Double?) -> Void) {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                print("[HealthKit] Could not fetch height: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            let heightInCm = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
            completion(heightInCm)
        }

        healthStore.execute(query)
    }

    /// Fetches the most recent weight measurement from HealthKit
    private func fetchMostRecentWeight(completion: @escaping (Double?) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                print("[HealthKit] Could not fetch weight: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            completion(weightInKg)
        }

        healthStore.execute(query)
    }

    /// Returns pre-filled responses for demographic questions based on HealthKit data
    /// Use this to auto-populate the questionnaire
    func getDemographicResponses() -> [String: Any] {
        var responses: [String: Any] = [:]

        // D2: Date of Birth
        if let dob = demographics.dateOfBirth {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            responses["D2"] = formatter.string(from: dob)
        }

        // D4: Biological Sex
        if let sex = demographics.biologicalSex {
            responses["D4"] = sex
        }

        // D5: Height in cm
        if let height = demographics.heightCm {
            responses["D5"] = Int(round(height))
        }

        // D6: Weight in kg
        if let weight = demographics.weightKg {
            responses["D6"] = Int(round(weight))
        }

        return responses
    }

    /// Check if a specific demographic field is available from HealthKit
    func hasDemographicData(for questionId: String) -> Bool {
        switch questionId {
        case "D2":
            return demographics.dateOfBirth != nil
        case "D4":
            return demographics.biologicalSex != nil
        case "D5":
            return demographics.heightCm != nil
        case "D6":
            return demographics.weightKg != nil
        default:
            return false
        }
    }

    // MARK: - Sleep Data

    func fetchSleepData(daysBack: Int = 90, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sleep analysis type not available"])))
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date calculation"])))
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { [weak self] query, samples, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let samples = samples as? [HKCategorySample] else {
                completion(.success([]))
                return
            }
            
            let processedData = self.processSleepSamples(samples)
            completion(.success(processedData))
        }
        
        healthStore.execute(query)
    }
    
    /// Maps HKCategoryValueSleepAnalysis to stage string
    private nonisolated func mapSleepStage(_ value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            return "light"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            return "light"
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            return "deep"
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return "rem"
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return "awake"
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return "inBed"
        default:
            return "unknown"
        }
    }

    /// Deduplicates overlapping sleep samples by prioritizing higher-priority sources
    /// Priority: Apple Watch (1) > iPhone native (2) > Third-party apps (3)
    private nonisolated func deduplicateSleepSamples(_ samples: [SourcedSleepSample]) -> [SourcedSleepSample] {
        // Group by date first
        let calendar = Calendar.current
        let byDate = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.startTime)
        }

        var result: [SourcedSleepSample] = []

        for (_, dateSamples) in byDate {
            // Sort by start time
            let sorted = dateSamples.sorted { $0.startTime < $1.startTime }
            var deduped: [SourcedSleepSample] = []

            for sample in sorted {
                // Check for overlap with existing samples
                let overlappingIndex = deduped.firstIndex { existing in
                    sample.startTime < existing.endTime && sample.endTime > existing.startTime
                }

                if let idx = overlappingIndex {
                    // Keep higher priority (lower number = higher priority)
                    if sample.source.priority < deduped[idx].source.priority {
                        deduped.remove(at: idx)
                        deduped.append(sample)
                    }
                    // else: keep existing, discard this sample
                } else {
                    deduped.append(sample)
                }
            }
            result.append(contentsOf: deduped)
        }

        return result
    }

    private nonisolated func processSleepSamples(_ samples: [HKCategorySample]) -> [[String: Any]] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Step 1: Convert to SourcedSleepSample with source metadata
        let sourcedSamples: [SourcedSleepSample] = samples.compactMap { sample in
            let source = SleepDataSource.from(sourceRevision: sample.sourceRevision)
            let stage = mapSleepStage(sample.value)
            let duration = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)

            // Skip "inBed" samples for sleep stage calculations
            guard stage != "inBed" && stage != "unknown" else { return nil }

            return SourcedSleepSample(
                sample: sample,
                source: source,
                stage: stage,
                durationMins: duration,
                startTime: sample.startDate,
                endTime: sample.endDate
            )
        }

        // Step 2: Deduplicate overlapping samples from multiple sources
        let deduplicatedSamples = deduplicateSleepSamples(sourcedSamples)

        // Step 3: Track unique sources per date for metadata
        var sourcesByDate: [String: Set<String>] = [:]
        var primarySourceByDate: [String: SleepDataSource] = [:]

        for sample in deduplicatedSamples {
            let dateKey = String(dateFormatter.string(from: sample.startTime).prefix(10))
            sourcesByDate[dateKey, default: Set()].insert(sample.source.name)

            // Track the highest priority source as primary
            if let existing = primarySourceByDate[dateKey] {
                if sample.source.priority < existing.priority {
                    primarySourceByDate[dateKey] = sample.source
                }
            } else {
                primarySourceByDate[dateKey] = sample.source
            }
        }

        // Step 4: Convert to processed stages format
        var processedStages: [[String: Any]] = []
        for sample in deduplicatedSamples {
            let dateKey = String(dateFormatter.string(from: sample.startTime).prefix(10))
            processedStages.append([
                "date": dateKey,
                "start_time": dateFormatter.string(from: sample.startTime),
                "end_time": dateFormatter.string(from: sample.endTime),
                "stage": sample.stage,
                "duration_mins": sample.durationMins,
                "source_name": sample.source.name
            ])
        }

        // Step 5: Group by date and calculate totals
        let grouped = Dictionary(grouping: processedStages) { $0["date"] as! String }
        var sleepData: [[String: Any]] = []

        for (date, stages) in grouped {
            let totalMins = stages.reduce(0) { $0 + ($1["duration_mins"] as! Int) }
            let deepMins = stages.filter { ($0["stage"] as! String) == "deep" }
                .reduce(0) { $0 + ($1["duration_mins"] as! Int) }
            let remMins = stages.filter { ($0["stage"] as! String) == "rem" }
                .reduce(0) { $0 + ($1["duration_mins"] as! Int) }
            let lightMins = stages.filter { ($0["stage"] as! String) == "light" }
                .reduce(0) { $0 + ($1["duration_mins"] as! Int) }
            let awakeMins = stages.filter { ($0["stage"] as! String) == "awake" }
                .reduce(0) { $0 + ($1["duration_mins"] as! Int) }

            // Find in-bed and wake times
            let sortedStages = stages.sorted {
                ($0["start_time"] as! String) < ($1["start_time"] as! String)
            }
            let inBedTime = sortedStages.first?["start_time"] as? String
            let asleepTime = sortedStages.first(where: { ($0["stage"] as! String) != "awake" })?["start_time"] as? String
            let wakeTime = sortedStages.last?["end_time"] as? String

            let sleepMins = totalMins - awakeMins
            let efficiency = totalMins > 0 ? Double(sleepMins) / Double(totalMins) * 100.0 : 0.0

            // Calculate sleep latency (time from in-bed to asleep)
            var sleepLatencyMins: Int? = nil
            if let inBedStr = inBedTime, let asleepStr = asleepTime {
                let inBedDate = dateFormatter.date(from: inBedStr) ?? Date()
                let asleepDate = dateFormatter.date(from: asleepStr) ?? Date()
                sleepLatencyMins = Int(asleepDate.timeIntervalSince(inBedDate) / 60)
            }

            // Get source metadata
            let allSources = Array(sourcesByDate[date] ?? Set())
            let primarySource = primarySourceByDate[date]
            let isMultiSource = allSources.count > 1

            sleepData.append([
                "date": date,
                "in_bed_time": inBedTime ?? "",
                "asleep_time": asleepTime ?? "",
                "wake_time": wakeTime ?? "",
                "total_sleep_mins": sleepMins,
                "sleep_efficiency": round(efficiency * 10) / 10,
                "deep_sleep_mins": deepMins,
                "light_sleep_mins": lightMins,
                "rem_sleep_mins": remMins,
                "awake_mins": awakeMins,
                "interruptions_count": stages.filter { ($0["stage"] as! String) == "awake" }.count,
                "sleep_latency_mins": sleepLatencyMins ?? 0,
                // Source tracking fields
                "primary_source": primarySource?.name ?? "Unknown",
                "source_bundle_id": primarySource?.bundleIdentifier ?? "",
                "all_sources": allSources,
                "is_multi_source": isMultiSource
            ])
        }

        return sleepData
    }
    
    // MARK: - Heart Rate Data
    
    func fetchHeartRateData(daysBack: Int = 30, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Heart rate type not available"])))
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date calculation"])))
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { [weak self] query, samples, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let samples = samples as? [HKQuantitySample] else {
                completion(.success([]))
                return
            }
            
            let processedData = self.processHeartRateSamples(samples)
            completion(.success(processedData))
        }
        
        healthStore.execute(query)
    }
    
    private nonisolated func processHeartRateSamples(_ samples: [HKQuantitySample]) -> [[String: Any]] {
        var heartRateData: [String: [Double]] = [:]
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Group heart rate readings by date
        for sample in samples {
            let dateKey = dateFormatter.string(from: sample.startDate).prefix(10)
            let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            
            if heartRateData[String(dateKey)] == nil {
                heartRateData[String(dateKey)] = []
            }
            heartRateData[String(dateKey)]?.append(heartRate)
        }
        
        // Process grouped data
        var processedData: [[String: Any]] = []
        for (date, rates) in heartRateData {
            let avgHR = rates.reduce(0, +) / Double(rates.count)
            let restingRates = rates.filter { $0 < 100 }
            let restingHR = restingRates.isEmpty ? avgHR : restingRates.reduce(0, +) / Double(restingRates.count)
            
            processedData.append([
                "date": date,
                "resting_hr": Int(restingHR),
                "avg_hr": Int(avgHR)
            ])
        }
        
        return processedData
    }
    
    // MARK: - HRV Data
    
    func fetchHRVData(daysBack: Int = 30, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "HRV type not available"])))
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date calculation"])))
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { [weak self] query, samples, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let samples = samples as? [HKQuantitySample] else {
                completion(.success([]))
                return
            }
            
            let processedData = self.processHRVSamples(samples)
            completion(.success(processedData))
        }
        
        healthStore.execute(query)
    }
    
    private nonisolated func processHRVSamples(_ samples: [HKQuantitySample]) -> [[String: Any]] {
        var hrvData: [String: [Double]] = [:]
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for sample in samples {
            let dateKey = dateFormatter.string(from: sample.startDate).prefix(10)
            let hrv = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            
            if hrvData[String(dateKey)] == nil {
                hrvData[String(dateKey)] = []
            }
            hrvData[String(dateKey)]?.append(hrv)
        }
        
        var processedData: [[String: Any]] = []
        for (date, values) in hrvData {
            // Morning HRV is typically the first reading of the day
            let morningHRV = values.first ?? 0
            let avgHRV = values.reduce(0, +) / Double(values.count)
            
            processedData.append([
                "date": date,
                "hrv_morning": round(morningHRV * 10) / 10,
                "hrv_avg": round(avgHRV * 10) / 10
            ])
        }
        
        return processedData
    }
    
    // MARK: - Activity Data
    
    func fetchActivityData(daysBack: Int = 30, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date calculation"])))
            return
        }
        
        var activityData: [[String: Any]] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Fetch steps
        fetchSteps(startDate: startDate, endDate: endDate) { [weak self] stepsResult in
            guard let self = self else { return }
            
            // Fetch active energy
            self.fetchActiveEnergy(startDate: startDate, endDate: endDate) { energyResult in
                // Fetch exercise time
                self.fetchExerciseTime(startDate: startDate, endDate: endDate) { exerciseResult in
                    // Combine all activity data
                    let dates = Set(stepsResult.keys).union(Set(energyResult.keys)).union(Set(exerciseResult.keys))
                    
                    for date in dates {
                        let steps = stepsResult[date] ?? 0
                        let calories = energyResult[date] ?? 0
                        let exerciseMins = exerciseResult[date] ?? 0
                        
                        activityData.append([
                            "date": date,
                            "steps": steps,
                            "active_mins": exerciseMins,
                            "exercise_mins": exerciseMins,
                            "calories_burned": Int(calories)
                        ])
                    }
                    
                    completion(.success(activityData))
                }
            }
        }
    }
    
    private func fetchSteps(startDate: Date, endDate: Date, completion: @escaping ([String: Int]) -> Void) {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion([:])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { query, results, error in
            var stepsData: [String: Int] = [:]
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            
            results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let quantity = statistics.sumQuantity() {
                    let dateKey = dateFormatter.string(from: statistics.startDate)
                    stepsData[dateKey] = Int(quantity.doubleValue(for: HKUnit.count()))
                }
            }
            
            completion(stepsData)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchActiveEnergy(startDate: Date, endDate: Date, completion: @escaping ([String: Double]) -> Void) {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion([:])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { query, results, error in
            var energyData: [String: Double] = [:]
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            
            results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let quantity = statistics.sumQuantity() {
                    let dateKey = dateFormatter.string(from: statistics.startDate)
                    energyData[dateKey] = quantity.doubleValue(for: HKUnit.kilocalorie())
                }
            }
            
            completion(energyData)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchExerciseTime(startDate: Date, endDate: Date, completion: @escaping ([String: Int]) -> Void) {
        guard let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
            completion([:])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: exerciseType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { query, results, error in
            var exerciseData: [String: Int] = [:]
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            
            results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let quantity = statistics.sumQuantity() {
                    let dateKey = dateFormatter.string(from: statistics.startDate)
                    exerciseData[dateKey] = Int(quantity.doubleValue(for: HKUnit.minute()))
                }
            }
            
            completion(exerciseData)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - API Sync
    
    func syncAllHealthData(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        Task { @MainActor in
            guard let authManager = authManager, let token = authManager.getAuthToken() else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please sign in first."])))
            return
        }
        
        let group = DispatchGroup()
        var sleepData: [[String: Any]] = []
        var sleepStages: [[String: Any]] = []
        var heartRateData: [[String: Any]] = []
        var hrvData: [[String: Any]] = []
        var activityData: [[String: Any]] = []
        var syncError: Error?
        
        // Fetch sleep data
        group.enter()
        fetchSleepData { result in
            switch result {
            case .success(let data):
                // Separate sleep data and stages
                let _ = data.flatMap { sleepDay -> [[String: Any]] in
                    // Extract stages from sleep data processing
                    return []
                }
                sleepData = data
            case .failure(let error):
                syncError = error
            }
            group.leave()
        }
        
        // Fetch heart rate data
        group.enter()
        fetchHeartRateData { result in
            switch result {
            case .success(let data):
                heartRateData = data
            case .failure(let error):
                if syncError == nil { syncError = error }
            }
            group.leave()
        }
        
        // Fetch HRV data
        group.enter()
        fetchHRVData { result in
            switch result {
            case .success(let data):
                hrvData = data
            case .failure(let error):
                if syncError == nil { syncError = error }
            }
            group.leave()
        }
        
        // Fetch activity data
        group.enter()
        fetchActivityData { result in
            switch result {
            case .success(let data):
                activityData = data
            case .failure(let error):
                if syncError == nil { syncError = error }
            }
            group.leave()
        }
        
        // Wait for all fetches to complete
        group.notify(queue: .main) {
            if let error = syncError {
                completion(.failure(error))
                return
            }
            
            // Merge HRV data into heart rate data
            var mergedHeartRateData = heartRateData
            for hrv in hrvData {
                if let index = mergedHeartRateData.firstIndex(where: { $0["date"] as! String == hrv["date"] as! String }) {
                    mergedHeartRateData[index]["hrv_morning"] = hrv["hrv_morning"]
                    mergedHeartRateData[index]["hrv_avg"] = hrv["hrv_avg"]
                } else {
                    mergedHeartRateData.append(hrv)
                }
            }
            
            // Sync to API using new authentication system
            self.syncToAPIWithAuth(
                sleepData: sleepData,
                sleepStages: sleepStages,
                heartRateData: mergedHeartRateData,
                activityData: activityData,
                token: token,
                completion: completion
            )
        }
        }
    }
    
    private func syncToAPIWithAuth(
        sleepData: [[String: Any]],
        sleepStages: [[String: Any]],
        heartRateData: [[String: Any]],
        activityData: [[String: Any]],
        token: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let payload: [String: Any] = [
            "sleepData": sleepData,
            "sleepStages": sleepStages,
            "heartRateData": heartRateData,
            "activityData": activityData
        ]

        Task {
            do {
                let result = try await apiService.syncHealthData(payload, token: token)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Data Verification (for debugging)

    /// Verification result containing diagnostic information about HealthKit data
    struct HealthKitVerificationResult {
        let isHealthKitAvailable: Bool
        let isAuthorized: Bool
        let sleepDataDays: Int
        let sleepDataSources: [String]
        let hasSleepStages: Bool
        let hasHeartRateData: Bool
        let hasActivityData: Bool
        let lastSleepDate: String?
        let sampleSleepEntry: [String: Any]?
        let errorMessage: String?

        var summary: String {
            var lines: [String] = []
            lines.append("═══════════════════════════════════════")
            lines.append("HEALTHKIT VERIFICATION REPORT")
            lines.append("═══════════════════════════════════════")
            lines.append("HealthKit Available: \(isHealthKitAvailable ? "✓" : "✗")")
            lines.append("Authorization: \(isAuthorized ? "✓ Granted" : "✗ Not Granted")")
            lines.append("───────────────────────────────────────")
            lines.append("SLEEP DATA:")
            lines.append("  Days of data: \(sleepDataDays)")
            lines.append("  Sources: \(sleepDataSources.isEmpty ? "None" : sleepDataSources.joined(separator: ", "))")
            lines.append("  Has sleep stages: \(hasSleepStages ? "✓" : "✗")")
            lines.append("  Last sleep date: \(lastSleepDate ?? "N/A")")
            lines.append("───────────────────────────────────────")
            lines.append("OTHER DATA:")
            lines.append("  Heart rate: \(hasHeartRateData ? "✓" : "✗")")
            lines.append("  Activity: \(hasActivityData ? "✓" : "✗")")
            if let error = errorMessage {
                lines.append("───────────────────────────────────────")
                lines.append("ERROR: \(error)")
            }
            if let sample = sampleSleepEntry {
                lines.append("───────────────────────────────────────")
                lines.append("SAMPLE ENTRY:")
                for (key, value) in sample.sorted(by: { $0.key < $1.key }) {
                    lines.append("  \(key): \(value)")
                }
            }
            lines.append("═══════════════════════════════════════")
            return lines.joined(separator: "\n")
        }
    }

    /// Performs a comprehensive verification of HealthKit data availability
    /// Call this from debug tools to diagnose data issues
    func verifyHealthKitData() async -> HealthKitVerificationResult {
        print("[HealthKit] Starting data verification...")

        let isAvailable = isHealthKitAvailable
        let isAuth = isAuthorized

        // Early return if not available or not authorized
        guard isAvailable else {
            let result = HealthKitVerificationResult(
                isHealthKitAvailable: false,
                isAuthorized: false,
                sleepDataDays: 0,
                sleepDataSources: [],
                hasSleepStages: false,
                hasHeartRateData: false,
                hasActivityData: false,
                lastSleepDate: nil,
                sampleSleepEntry: nil,
                errorMessage: "HealthKit is not available on this device"
            )
            print(result.summary)
            return result
        }

        guard isAuth else {
            let result = HealthKitVerificationResult(
                isHealthKitAvailable: true,
                isAuthorized: false,
                sleepDataDays: 0,
                sleepDataSources: [],
                hasSleepStages: false,
                hasHeartRateData: false,
                hasActivityData: false,
                lastSleepDate: nil,
                sampleSleepEntry: nil,
                errorMessage: "HealthKit authorization not granted. Go to Settings > Privacy > Health > Zoe Sleep to enable."
            )
            print(result.summary)
            return result
        }

        // Fetch sleep data for verification
        return await withCheckedContinuation { continuation in
            fetchSleepData(daysBack: 30) { sleepResult in
                var sleepData: [[String: Any]] = []
                var sleepError: String? = nil

                switch sleepResult {
                case .success(let data):
                    sleepData = data
                    print("[HealthKit] Fetched \(data.count) days of sleep data")
                case .failure(let error):
                    sleepError = error.localizedDescription
                    print("[HealthKit] Sleep data error: \(error.localizedDescription)")
                }

                // Extract sources from sleep data
                var allSources = Set<String>()
                var hasSleepStages = false
                var lastSleepDate: String? = nil
                var sampleEntry: [String: Any]? = nil

                for entry in sleepData {
                    if let sources = entry["all_sources"] as? [String] {
                        allSources.formUnion(sources)
                    }
                    if let primary = entry["primary_source"] as? String, primary != "Unknown" {
                        allSources.insert(primary)
                    }
                    // Check for sleep stages (deep/REM indicates wearable data)
                    if let deepMins = entry["deep_sleep_mins"] as? Int, deepMins > 0 {
                        hasSleepStages = true
                    }
                    if let remMins = entry["rem_sleep_mins"] as? Int, remMins > 0 {
                        hasSleepStages = true
                    }
                    // Track last sleep date
                    if let date = entry["date"] as? String {
                        if lastSleepDate == nil || date > lastSleepDate! {
                            lastSleepDate = date
                            sampleEntry = entry
                        }
                    }
                }

                // Log detailed info about sources
                print("[HealthKit] Unique sources found: \(allSources)")
                print("[HealthKit] Has sleep stages (Deep/REM): \(hasSleepStages)")
                print("[HealthKit] Most recent sleep date: \(lastSleepDate ?? "None")")

                // Check for heart rate and activity data
                self.fetchHeartRateData(daysBack: 7) { hrResult in
                    let hasHR = (try? hrResult.get())?.isEmpty == false

                    self.fetchActivityData(daysBack: 7) { activityResult in
                        let hasActivity = (try? activityResult.get())?.isEmpty == false

                        let result = HealthKitVerificationResult(
                            isHealthKitAvailable: true,
                            isAuthorized: true,
                            sleepDataDays: sleepData.count,
                            sleepDataSources: Array(allSources).sorted(),
                            hasSleepStages: hasSleepStages,
                            hasHeartRateData: hasHR,
                            hasActivityData: hasActivity,
                            lastSleepDate: lastSleepDate,
                            sampleSleepEntry: sampleEntry,
                            errorMessage: sleepError
                        )

                        print(result.summary)
                        continuation.resume(returning: result)
                    }
                }
            }
        }
    }
}

