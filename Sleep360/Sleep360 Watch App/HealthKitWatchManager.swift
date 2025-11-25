//
//  HealthKitWatchManager.swift
//  Sleep 360 Platform - watchOS
//
//  HealthKit integration specifically for Apple Watch
//

import HealthKit
import WatchKit
import Foundation
import Combine

@MainActor
class HealthKitWatchManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var lastNightSleep: SleepData?
    @Published var todayActivity: ActivityData?
    @Published var heartRateData: [HeartRateReading] = []
    @Published var isAuthorized = false
    
    // Watch-specific health data types
    private let watchHealthTypes: Set<HKSampleType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
    ]
    
    init() {
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
                        value: sample.quantity.doubleValue(for: HKUnit.beatsPerMinute()),
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