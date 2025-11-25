//
//  HealthKitManager.swift
//  ZOE Sleep Platform
//
//  HealthKit integration for syncing sleep, heart rate, and activity data
//

import Foundation
import HealthKit

@MainActor
class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    
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
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                completion(success, error)
            }
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
    
    private func processSleepSamples(_ samples: [HKCategorySample]) -> [[String: Any]] {
        var sleepStages: [[String: Any]] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Process individual sleep stages
        for sample in samples {
            let dateKey = dateFormatter.string(from: sample.startDate).prefix(10) // YYYY-MM-DD
            
            let value = sample.value
            let stage: String
            
            switch value {
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                stage = "light"
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                stage = "light"
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                stage = "deep"
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                stage = "rem"
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                stage = "awake"
            default:
                stage = "unknown"
            }
            
            let duration = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60) // minutes
            
            sleepStages.append([
                "date": String(dateKey),
                "start_time": dateFormatter.string(from: sample.startDate),
                "end_time": dateFormatter.string(from: sample.endDate),
                "stage": stage,
                "duration_mins": duration
            ])
        }
        
        // Group by date and calculate totals
        let grouped = Dictionary(grouping: sleepStages) { $0["date"] as! String }
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
            
            sleepData.append([
                "date": date,
                "in_bed_time": inBedTime ?? "",
                "asleep_time": asleepTime ?? "",
                "wake_time": wakeTime ?? "",
                "total_sleep_mins": sleepMins,
                "sleep_efficiency": round(efficiency * 10) / 10, // Round to 1 decimal
                "deep_sleep_mins": deepMins,
                "light_sleep_mins": lightMins,
                "rem_sleep_mins": remMins,
                "awake_mins": awakeMins,
                "interruptions_count": stages.filter { ($0["stage"] as! String) == "awake" }.count,
                "sleep_latency_mins": sleepLatencyMins ?? 0
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
    
    private func processHeartRateSamples(_ samples: [HKQuantitySample]) -> [[String: Any]] {
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
    
    private func processHRVSamples(_ samples: [HKQuantitySample]) -> [[String: Any]] {
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
            guard let authManager = authManager, let token = await authManager.getAuthToken() else {
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
}

