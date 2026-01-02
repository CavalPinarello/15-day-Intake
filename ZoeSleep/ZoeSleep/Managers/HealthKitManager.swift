//
//  HealthKitManager.swift
//  ZOE Sleep Platform
//
//  HealthKit integration for syncing sleep, heart rate, and activity data
//

import Foundation
import HealthKit
import UIKit

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

/// Sync progress tracking for UI feedback
struct HealthKitSyncProgress {
    enum Step: String, CaseIterable {
        case idle = "Ready"
        case fetchingSleep = "Fetching sleep data..."
        case fetchingHeartRate = "Fetching heart rate..."
        case fetchingHRV = "Fetching HRV data..."
        case fetchingActivity = "Fetching activity..."
        case uploadingSleep = "Uploading sleep data..."
        case uploadingHeartRate = "Uploading heart rate..."
        case uploadingActivity = "Uploading activity..."
        case complete = "Sync complete!"
        case failed = "Sync failed"

        var stepNumber: Int {
            switch self {
            case .idle: return 0
            case .fetchingSleep: return 1
            case .fetchingHeartRate: return 2
            case .fetchingHRV: return 3
            case .fetchingActivity: return 4
            case .uploadingSleep: return 5
            case .uploadingHeartRate: return 6
            case .uploadingActivity: return 7
            case .complete, .failed: return 8
            }
        }

        static var totalSteps: Int { 7 }
    }

    var currentStep: Step = .idle
    var progress: Double = 0.0 // 0.0 to 1.0
    var statusMessage: String = ""
    var recordsFetched: Int = 0
    var recordsUploaded: Int = 0
    var isActive: Bool = false

    mutating func update(step: Step, message: String? = nil) {
        currentStep = step
        progress = Double(step.stepNumber) / Double(Step.totalSteps)
        statusMessage = message ?? step.rawValue
        isActive = step != .idle && step != .complete && step != .failed
    }
}

@MainActor
class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false {
        didSet {
            // Persist authorization state to survive app restarts
            UserDefaults.standard.set(isAuthorized, forKey: Self.healthKitAuthorizedKey)
            print("[HealthKit] Authorization state saved: \(isAuthorized)")
        }
    }
    @Published var demographics: HealthKitDemographics = HealthKitDemographics()
    @Published var syncProgress = HealthKitSyncProgress()

    // Persistence key for authorization state
    private static let healthKitAuthorizedKey = "healthKitAuthorized"

    // API Configuration
    private let apiService = APIService.shared
    private var authManager: AuthenticationManager?

    init(authManager: AuthenticationManager? = nil) {
        self.authManager = authManager
        // Load cached authorization state immediately for better UX
        // (actual verification happens on requestAuthorization call)
        let cachedAuth = UserDefaults.standard.bool(forKey: Self.healthKitAuthorizedKey)
        if cachedAuth {
            self.isAuthorized = cachedAuth
            print("[HealthKit] Loaded cached authorization state: \(cachedAuth)")
        }
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

        // MARK: - Circadian Signal Types (iOS 17+ / watchOS 10+)

        // Time in Daylight - measures outdoor light exposure
        if #available(iOS 17.0, watchOS 10.0, *) {
            if let timeInDaylightType = HKObjectType.quantityType(forIdentifier: .timeInDaylight) {
                readTypes.insert(timeInDaylightType)
            }
        }

        // Sleeping Wrist Temperature - deviation from baseline (Apple Watch Series 8+)
        if #available(iOS 17.0, watchOS 10.0, *) {
            if let wristTempType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                readTypes.insert(wristTempType)
            }
        }

        // UV Exposure (optional, rarely populated)
        if let uvExposureType = HKObjectType.quantityType(forIdentifier: .uvExposure) {
            readTypes.insert(uvExposureType)
        }

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
                // NOTE: iOS returns success=true even if user DENIES permission
                // success only means the dialog was shown successfully
                // We need to verify actual data access separately
                if success {
                    // Automatically fetch demographics after authorization
                    self.fetchDemographics()

                    // Verify we can actually read data by checking authorization status
                    self.verifyDataAccess { hasAccess in
                        self.isAuthorized = hasAccess
                        completion(hasAccess, error)
                    }
                } else {
                    self.isAuthorized = false
                    completion(false, error)
                }
            }
        }
    }

    /// Verifies that we actually have access to HealthKit data
    /// This is necessary because requestAuthorization returns success even when user denies
    func verifyDataAccess(completion: @escaping (Bool) -> Void) {
        // Check authorization status for sleep data (our primary data type)
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(false)
            return
        }

        let status = healthStore.authorizationStatus(for: sleepType)

        // For read-only types, .sharingAuthorized means we have read access
        // .notDetermined means user hasn't been asked yet
        // .sharingDenied means user denied (but note: Apple returns this even when denied for privacy)

        // The most reliable check is to actually attempt to read data
        // If we get any data back (even empty results), we have access
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            end: Date(),
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, samples, error in
            DispatchQueue.main.async {
                // If we got here without an error, we have read access
                // (Even if samples is empty, that just means no data, not no access)
                if error == nil {
                    print("[HealthKit] ✅ Verified data access - authorization granted")
                    completion(true)
                } else {
                    // Check specific error codes
                    let nsError = error as? NSError
                    if nsError?.code == 5 { // HKErrorAuthorizationDenied
                        print("[HealthKit] ⚠️ Data access denied by user")
                        completion(false)
                    } else {
                        // Other errors might be transient - assume access is granted
                        print("[HealthKit] ⚠️ Query error but may have access: \(error?.localizedDescription ?? "unknown")")
                        completion(true)
                    }
                }
            }
        }

        healthStore.execute(query)
    }

    /// Check current authorization status (for UI display)
    /// Returns a status that can be used to show appropriate UI
    func checkAuthorizationStatus() -> HKAuthorizationStatus {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return .notDetermined
        }
        return healthStore.authorizationStatus(for: sleepType)
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
    ///
    /// IMPORTANT: This function groups by "sleep night" not calendar day.
    /// A sleep session is defined by when you WAKE UP, not when you go to bed.
    /// This ensures overnight sleep (11pm-7am) is properly deduplicated as one session.
    private nonisolated func deduplicateSleepSamples(_ samples: [SourcedSleepSample]) -> [SourcedSleepSample] {
        let calendar = Calendar.current

        // Group by "sleep night" - use the END time to determine which night's sleep this belongs to
        // Sleep ending at 7am Dec 31 = Dec 31's sleep, even if it started at 11pm Dec 30
        let byNight = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.endTime)
        }

        var result: [SourcedSleepSample] = []

        for (_, nightSamples) in byNight {
            // Sort by start time
            let sorted = nightSamples.sorted { $0.startTime < $1.startTime }
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
        // Use END time to determine the "sleep night" - this ensures overnight sleep is attributed
        // to the day you wake up (e.g., sleep 11pm Dec 30 to 7am Dec 31 = Dec 31's sleep)
        var sourcesByDate: [String: Set<String>] = [:]
        var primarySourceByDate: [String: SleepDataSource] = [:]

        for sample in deduplicatedSamples {
            let dateKey = String(dateFormatter.string(from: sample.endTime).prefix(10))
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
        // Use END time to group by sleep night (when you wake up)
        var processedStages: [[String: Any]] = []
        for sample in deduplicatedSamples {
            let dateKey = String(dateFormatter.string(from: sample.endTime).prefix(10))
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
    
    // MARK: - API Sync (Convex Backend)

    func syncAllHealthData(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        Task { @MainActor in
            // Reset progress
            syncProgress = HealthKitSyncProgress()

            // Use ConvexService for sync (the primary backend)
            guard ConvexService.shared.isAuthenticated else {
                syncProgress.update(step: .failed, message: "Not authenticated")
                completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please sign in first."])))
                return
            }

            // Get device ID for sync
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

            var sleepData: [[String: Any]] = []
            var heartRateData: [[String: Any]] = []
            var hrvData: [[String: Any]] = []
            var activityData: [[String: Any]] = []

            // Step 1: Fetch sleep data
            syncProgress.update(step: .fetchingSleep, message: "Fetching sleep data (up to 6 months)...")
            do {
                sleepData = try await withCheckedThrowingContinuation { continuation in
                    fetchSleepData { result in
                        switch result {
                        case .success(let data):
                            continuation.resume(returning: data)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                syncProgress.recordsFetched += sleepData.count
                print("[HealthKit] Fetched \(sleepData.count) days of sleep data")
            } catch {
                print("[HealthKit] Sleep fetch error: \(error.localizedDescription)")
                // Continue with empty data - don't fail entire sync
            }

            // Step 2: Fetch heart rate data
            syncProgress.update(step: .fetchingHeartRate, message: "Fetching heart rate data...")
            do {
                heartRateData = try await withCheckedThrowingContinuation { continuation in
                    fetchHeartRateData { result in
                        switch result {
                        case .success(let data):
                            continuation.resume(returning: data)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                syncProgress.recordsFetched += heartRateData.count
            } catch {
                print("[HealthKit] Heart rate fetch error: \(error.localizedDescription)")
            }

            // Step 3: Fetch HRV data
            syncProgress.update(step: .fetchingHRV, message: "Fetching HRV data...")
            do {
                hrvData = try await withCheckedThrowingContinuation { continuation in
                    fetchHRVData { result in
                        switch result {
                        case .success(let data):
                            continuation.resume(returning: data)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                syncProgress.recordsFetched += hrvData.count
            } catch {
                print("[HealthKit] HRV fetch error: \(error.localizedDescription)")
            }

            // Step 4: Fetch activity data
            syncProgress.update(step: .fetchingActivity, message: "Fetching activity data...")
            do {
                activityData = try await withCheckedThrowingContinuation { continuation in
                    fetchActivityData { result in
                        switch result {
                        case .success(let data):
                            continuation.resume(returning: data)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                syncProgress.recordsFetched += activityData.count
            } catch {
                print("[HealthKit] Activity fetch error: \(error.localizedDescription)")
            }

            // Merge HRV data into heart rate data
            var mergedHeartRateData = heartRateData
            for hrv in hrvData {
                if let hrvDate = hrv["date"] as? String,
                   let index = mergedHeartRateData.firstIndex(where: { $0["date"] as? String == hrvDate }) {
                    mergedHeartRateData[index]["hrv_morning"] = hrv["hrv_morning"]
                    mergedHeartRateData[index]["hrv_avg"] = hrv["hrv_avg"]
                } else {
                    mergedHeartRateData.append(hrv)
                }
            }

            syncProgress.update(step: .uploadingSleep, message: "Fetched \(syncProgress.recordsFetched) records. Uploading...")

            // Sync to Convex backend with progress updates
            syncToConvexWithProgress(
                deviceId: deviceId,
                sleepData: sleepData,
                heartRateData: mergedHeartRateData,
                activityData: activityData,
                completion: completion
            )
        }
    }

    /// Sync to Convex with progress tracking
    private func syncToConvexWithProgress(
        deviceId: String,
        sleepData: [[String: Any]],
        heartRateData: [[String: Any]],
        activityData: [[String: Any]],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        Task { @MainActor in
            do {
                var results: [String: Any] = [:]
                var totalRecords = 0

                // Step 5: Upload sleep data
                if !sleepData.isEmpty {
                    syncProgress.update(step: .uploadingSleep, message: "Uploading \(sleepData.count) sleep records...")
                    let transformedSleep = transformSleepDataForConvex(sleepData)
                    print("[HealthKit] Syncing \(transformedSleep.count) sleep records")
                    let sleepResult = try await ConvexService.shared.syncSleepData(
                        deviceId: deviceId,
                        sleepData: transformedSleep
                    )
                    results["sleepData"] = ["synced": sleepResult.recordsSynced ?? sleepData.count]
                    totalRecords += sleepResult.recordsSynced ?? sleepData.count
                    syncProgress.recordsUploaded += sleepResult.recordsSynced ?? sleepData.count
                }

                // Step 6: Upload heart rate data
                if !heartRateData.isEmpty {
                    syncProgress.update(step: .uploadingHeartRate, message: "Uploading \(heartRateData.count) heart rate records...")
                    let transformedHR = transformHeartRateDataForConvex(heartRateData)
                    let hrResult = try await ConvexService.shared.syncHeartRateData(
                        deviceId: deviceId,
                        heartRateData: transformedHR
                    )
                    results["heartRateData"] = ["synced": hrResult.recordsSynced ?? heartRateData.count]
                    totalRecords += hrResult.recordsSynced ?? heartRateData.count
                    syncProgress.recordsUploaded += hrResult.recordsSynced ?? heartRateData.count
                }

                // Step 7: Upload activity data
                if !activityData.isEmpty {
                    syncProgress.update(step: .uploadingActivity, message: "Uploading \(activityData.count) activity records...")
                    let transformedActivity = transformActivityDataForConvex(activityData)
                    let activityResult = try await ConvexService.shared.syncActivityData(
                        deviceId: deviceId,
                        activityData: transformedActivity
                    )
                    results["activityData"] = ["synced": activityResult.recordsSynced ?? activityData.count]
                    totalRecords += activityResult.recordsSynced ?? activityData.count
                    syncProgress.recordsUploaded += activityResult.recordsSynced ?? activityData.count
                }

                results["totalRecordsSynced"] = totalRecords
                syncProgress.update(step: .complete, message: "Sync complete! \(totalRecords) records uploaded.")
                completion(.success(results))

            } catch {
                print("[HealthKit] Convex sync error: \(error)")
                syncProgress.update(step: .failed, message: "Upload failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Transform sleep data keys from snake_case to camelCase for Convex
    /// Also converts ISO8601 time strings to Unix timestamps in milliseconds
    private func transformSleepDataForConvex(_ data: [[String: Any]]) -> [[String: Any]] {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Helper to convert ISO8601 string to Unix timestamp (ms)
        func toTimestamp(_ value: Any?) -> Int? {
            guard let str = value as? String, !str.isEmpty else { return nil }
            if let date = iso8601Formatter.date(from: str) {
                return Int(date.timeIntervalSince1970 * 1000)
            }
            return nil
        }

        return data.map { entry in
            var transformed: [String: Any] = [:]
            transformed["date"] = entry["date"]
            // Convert time strings to Unix timestamps (ms)
            if let ts = toTimestamp(entry["in_bed_time"]) {
                transformed["inBedTime"] = ts
            }
            if let ts = toTimestamp(entry["asleep_time"]) {
                transformed["asleepTime"] = ts
            }
            if let ts = toTimestamp(entry["wake_time"]) {
                transformed["wakeTime"] = ts
            }
            transformed["totalSleepMins"] = entry["total_sleep_mins"]
            transformed["sleepEfficiency"] = entry["sleep_efficiency"]
            transformed["deepSleepMins"] = entry["deep_sleep_mins"]
            transformed["lightSleepMins"] = entry["light_sleep_mins"]
            transformed["remSleepMins"] = entry["rem_sleep_mins"]
            transformed["awakeMins"] = entry["awake_mins"]
            transformed["interruptionsCount"] = entry["interruptions_count"]
            transformed["sleepLatencyMins"] = entry["sleep_latency_mins"]
            // Source tracking fields
            transformed["primarySource"] = entry["primary_source"]
            transformed["sourceBundleId"] = entry["source_bundle_id"]
            if let allSources = entry["all_sources"] as? [String],
               let jsonData = try? JSONSerialization.data(withJSONObject: allSources) {
                transformed["allSourcesJson"] = String(data: jsonData, encoding: .utf8)
            }
            transformed["isMultiSource"] = entry["is_multi_source"]
            return transformed
        }
    }

    /// Transform heart rate data keys from snake_case to camelCase for Convex
    private func transformHeartRateDataForConvex(_ data: [[String: Any]]) -> [[String: Any]] {
        return data.map { entry in
            var transformed: [String: Any] = [:]
            transformed["date"] = entry["date"]
            transformed["restingHr"] = entry["resting_hr"]
            transformed["avgHr"] = entry["avg_hr"]
            transformed["hrvMorning"] = entry["hrv_morning"]
            transformed["hrvAvg"] = entry["hrv_avg"]
            return transformed
        }
    }

    /// Transform activity data keys from snake_case to camelCase for Convex
    private func transformActivityDataForConvex(_ data: [[String: Any]]) -> [[String: Any]] {
        return data.map { entry in
            var transformed: [String: Any] = [:]
            transformed["date"] = entry["date"]
            transformed["steps"] = entry["steps"]
            transformed["activeMins"] = entry["active_mins"]
            transformed["exerciseMins"] = entry["exercise_mins"]
            transformed["caloriesBurned"] = entry["calories_burned"]
            return transformed
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

    // MARK: - Circadian Signal Data Fetching

    /// Circadian data result structure
    struct CircadianData {
        var date: String
        var timeInDaylightMins: Double?
        var morningLightMins: Double?
        var afternoonLightMins: Double?
        var sleepingWristTempDeviation: Double?
        var outdoorWorkoutMins: Double?
        var outdoorWorkoutCount: Int?
        var circadianScore: Int?
        var scoreBreakdown: [String: Int]?
    }

    /// Fetch time spent in daylight for the specified date range
    /// Only available on iOS 17+ / watchOS 10+
    @available(iOS 17.0, watchOS 10.0, *)
    func fetchTimeInDaylight(daysBack: Int = 14, completion: @escaping (Result<[(date: String, totalMins: Double, morningMins: Double, afternoonMins: Double)], Error>) -> Void) {
        guard let daylightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Time in daylight type not available"])))
            return
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date calculation"])))
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // Query individual samples to separate morning vs afternoon
        let query = HKSampleQuery(
            sampleType: daylightType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            var dailyData: [String: (total: Double, morning: Double, afternoon: Double)] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for sample in (samples as? [HKQuantitySample]) ?? [] {
                let dateKey = dateFormatter.string(from: sample.startDate)
                let minutes = sample.quantity.doubleValue(for: .minute())

                // Determine if morning (before noon) or afternoon
                let hour = calendar.component(.hour, from: sample.startDate)
                let isMorning = hour < 12

                var current = dailyData[dateKey] ?? (total: 0, morning: 0, afternoon: 0)
                current.total += minutes
                if isMorning {
                    current.morning += minutes
                } else {
                    current.afternoon += minutes
                }
                dailyData[dateKey] = current
            }

            let result = dailyData.map { (date: $0.key, totalMins: $0.value.total, morningMins: $0.value.morning, afternoonMins: $0.value.afternoon) }
                .sorted { $0.date > $1.date }

            completion(.success(result))
        }

        healthStore.execute(query)
    }

    /// Fetch sleeping wrist temperature deviation
    /// Only available on Apple Watch Series 8+ with iOS 17+
    @available(iOS 17.0, watchOS 10.0, *)
    func fetchSleepingWristTemperature(daysBack: Int = 14, completion: @escaping (Result<[(date: String, deviation: Double)], Error>) -> Void) {
        guard let tempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Wrist temperature type not available"])))
            return
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date calculation"])))
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: tempType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            var dailyData: [(date: String, deviation: Double)] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for sample in (samples as? [HKQuantitySample]) ?? [] {
                let dateKey = dateFormatter.string(from: sample.startDate)
                let deviation = sample.quantity.doubleValue(for: .degreeCelsius())
                dailyData.append((date: dateKey, deviation: deviation))
            }

            // Sort by date descending
            dailyData.sort { $0.date > $1.date }
            completion(.success(dailyData))
        }

        healthStore.execute(query)
    }

    /// Fetch outdoor workout minutes (workouts where indoor = false)
    func fetchOutdoorWorkoutMinutes(daysBack: Int = 14, completion: @escaping (Result<[(date: String, minutes: Double, count: Int)], Error>) -> Void) {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else {
            completion(.failure(NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date calculation"])))
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            var dailyData: [String: (minutes: Double, count: Int)] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for workout in (samples as? [HKWorkout]) ?? [] {
                // Check if workout is outdoor (HKMetadataKeyIndoorWorkout = false or nil for outdoor types)
                let isIndoor = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool ?? false

                // Also consider activity types that are inherently outdoor
                let inherentlyOutdoor: Set<HKWorkoutActivityType> = [
                    .running, .cycling, .walking, .hiking, .golf, .soccer,
                    .tennis, .snowSports, .surfingSports, .swimming
                ]

                let isOutdoor = !isIndoor || inherentlyOutdoor.contains(workout.workoutActivityType)

                if isOutdoor {
                    let dateKey = dateFormatter.string(from: workout.startDate)
                    let durationMins = workout.duration / 60.0

                    var current = dailyData[dateKey] ?? (minutes: 0, count: 0)
                    current.minutes += durationMins
                    current.count += 1
                    dailyData[dateKey] = current
                }
            }

            let result = dailyData.map { (date: $0.key, minutes: $0.value.minutes, count: $0.value.count) }
                .sorted { $0.date > $1.date }

            completion(.success(result))
        }

        healthStore.execute(query)
    }

    /// Compute circadian score from available data
    /// Score: 0-100 based on light exposure (60%), morning bonus (10%), temperature (15%), outdoor activity (15%)
    func computeCircadianScore(
        timeInDaylightMins: Double?,
        morningLightMins: Double?,
        temperatureDeviation: Double?,
        outdoorWorkoutMins: Double?
    ) -> (score: Int, breakdown: [String: Int]) {
        var score = 0
        var breakdown: [String: Int] = [:]

        // Light exposure score (60 points max)
        // Target: 80-120 minutes daily
        if let daylight = timeInDaylightMins {
            let lightScore: Int
            if daylight >= 80 && daylight <= 120 {
                lightScore = 60 // Optimal
            } else if daylight >= 60 && daylight < 80 {
                lightScore = 50 // Good
            } else if daylight >= 30 && daylight < 60 {
                lightScore = 35 // Fair
            } else if daylight > 120 {
                lightScore = 55 // Slightly over but still good
            } else {
                lightScore = Int((daylight / 30.0) * 20) // Below 30 mins
            }
            score += lightScore
            breakdown["light_exposure"] = lightScore
        }

        // Morning light bonus (up to 10 points) - weighted higher per plan
        if let morningLight = morningLightMins {
            let bonus: Int
            if morningLight >= 30 {
                bonus = 10 // Full bonus
            } else if morningLight >= 20 {
                bonus = 7
            } else {
                bonus = Int((morningLight / 20.0) * 7)
            }
            score += bonus
            breakdown["morning_light_bonus"] = bonus
        }

        // Temperature regularity score (15 points max)
        // Lower deviation is better (< 0.2C is excellent)
        if let tempDev = temperatureDeviation {
            let absDeviation = abs(tempDev)
            let tempScore: Int
            if absDeviation < 0.2 {
                tempScore = 15
            } else if absDeviation < 0.3 {
                tempScore = 12
            } else if absDeviation < 0.5 {
                tempScore = 9
            } else if absDeviation < 0.8 {
                tempScore = 5
            } else {
                tempScore = 2
            }
            score += tempScore
            breakdown["temperature"] = tempScore
        }

        // Outdoor activity score (15 points max)
        // Target: 30+ minutes outdoor exercise
        if let outdoorMins = outdoorWorkoutMins {
            let outdoorScore: Int
            if outdoorMins >= 60 {
                outdoorScore = 15
            } else if outdoorMins >= 30 {
                outdoorScore = 12
            } else if outdoorMins >= 15 {
                outdoorScore = 8
            } else {
                outdoorScore = Int((outdoorMins / 15.0) * 5)
            }
            score += outdoorScore
            breakdown["outdoor_activity"] = outdoorScore
        }

        return (score: min(100, score), breakdown: breakdown)
    }

    /// Fetch all circadian data and compute scores for the specified date range
    func fetchCircadianData(daysBack: Int = 14, completion: @escaping (Result<[CircadianData], Error>) -> Void) {
        var allDaylightData: [(date: String, totalMins: Double, morningMins: Double, afternoonMins: Double)] = []
        var allTempData: [(date: String, deviation: Double)] = []
        var allOutdoorData: [(date: String, minutes: Double, count: Int)] = []
        var fetchError: Error?

        let group = DispatchGroup()

        // Fetch time in daylight (iOS 17+)
        if #available(iOS 17.0, watchOS 10.0, *) {
            group.enter()
            fetchTimeInDaylight(daysBack: daysBack) { result in
                switch result {
                case .success(let data):
                    allDaylightData = data
                case .failure(let error):
                    print("[HealthKit] Time in daylight fetch error: \(error.localizedDescription)")
                    // Don't fail - this data may not be available
                }
                group.leave()
            }

            // Fetch wrist temperature
            group.enter()
            fetchSleepingWristTemperature(daysBack: daysBack) { result in
                switch result {
                case .success(let data):
                    allTempData = data
                case .failure(let error):
                    print("[HealthKit] Wrist temp fetch error: \(error.localizedDescription)")
                    // Don't fail - this requires Series 8+
                }
                group.leave()
            }
        }

        // Fetch outdoor workouts (always available)
        group.enter()
        fetchOutdoorWorkoutMinutes(daysBack: daysBack) { result in
            switch result {
            case .success(let data):
                allOutdoorData = data
            case .failure(let error):
                if fetchError == nil { fetchError = error }
            }
            group.leave()
        }

        // Combine all data by date
        group.notify(queue: .main) {
            // Get all unique dates
            var allDates = Set<String>()
            allDaylightData.forEach { allDates.insert($0.date) }
            allTempData.forEach { allDates.insert($0.date) }
            allOutdoorData.forEach { allDates.insert($0.date) }

            // Build combined data for each date
            var results: [CircadianData] = []

            for date in allDates {
                let daylightEntry = allDaylightData.first { $0.date == date }
                let tempEntry = allTempData.first { $0.date == date }
                let outdoorEntry = allOutdoorData.first { $0.date == date }

                // Compute score
                let scoreResult = self.computeCircadianScore(
                    timeInDaylightMins: daylightEntry?.totalMins,
                    morningLightMins: daylightEntry?.morningMins,
                    temperatureDeviation: tempEntry?.deviation,
                    outdoorWorkoutMins: outdoorEntry?.minutes
                )

                results.append(CircadianData(
                    date: date,
                    timeInDaylightMins: daylightEntry?.totalMins,
                    morningLightMins: daylightEntry?.morningMins,
                    afternoonLightMins: daylightEntry?.afternoonMins,
                    sleepingWristTempDeviation: tempEntry?.deviation,
                    outdoorWorkoutMins: outdoorEntry?.minutes,
                    outdoorWorkoutCount: outdoorEntry?.count,
                    circadianScore: scoreResult.score,
                    scoreBreakdown: scoreResult.breakdown
                ))
            }

            // Sort by date descending
            results.sort { $0.date > $1.date }
            completion(.success(results))
        }
    }
}

