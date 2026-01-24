//
//  SleepDataViewModel.swift
//  Zoe Sleep for Longevity System
//
//  ViewModel for Sleep Data menu and visualizations
//

import Foundation
import Combine

/// ViewModel for Sleep Data menu
@MainActor
class SleepDataViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isLoading = false
    @Published var errorMessage: String?

    // Today's data
    @Published var todayZoeScore: ZoeSleepScoreResult?
    @Published var todayHRVCharge: HRVChargeResult?
    @Published var todayHRVSummary: HRVNightlySummary?

    // Historical data
    @Published var sleepScoreHistory: [ZoeSleepScoreResult] = []
    @Published var hrvChargeHistory: [HRVChargeResult] = []
    @Published var hrvSummaryHistory: [HRVNightlySummary] = []
    @Published var weeklySummary: WeeklySleepScoreSummary?

    // Source management
    @Published var connectedSources: [ConnectedSleepSource] = []
    @Published var visibleSourceIds: Set<String> = []

    // HRV samples for charting (current night)
    @Published var currentNightHRVSamples: [HRVSample] = []

    // Personal baseline
    @Published var hrvBaseline: PersonalHRVBaseline?

    // MARK: - Dependencies

    private let healthKitManager: HealthKitManager
    private let hrvChargeCalculator = HRVChargeCalculator()
    private let sleepScoreCalculator = ZoeSleepScoreCalculator()

    // MARK: - Initialization

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    /// Convenience initializer using shared instance - must be called from MainActor
    @MainActor
    convenience init() {
        self.init(healthKitManager: HealthKitManager.shared)
    }

    // MARK: - Data Loading

    /// Load all sleep data for the menu
    func loadData() async {
        isLoading = true
        errorMessage = nil

        // Load connected sources
        await loadConnectedSources()

        // Load HRV data
        await loadHRVData()

        // Load sleep scores
        await loadSleepScores()

        // Calculate weekly summary
        calculateWeeklySummary()

        isLoading = false
    }

    /// Sync latest data from HealthKit
    func syncLatestData() async {
        isLoading = true
        errorMessage = nil

        // Fetch HRV profiles for last 7 days
        await withCheckedContinuation { continuation in
            healthKitManager.fetchHRVProfiles(daysBack: 7) { [weak self] result in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                switch result {
                case .success(let summaries):
                    Task { @MainActor in
                        self.hrvSummaryHistory = summaries
                        self.todayHRVSummary = summaries.first

                        // Calculate HRV charges
                        self.calculateHRVCharges(from: summaries)
                        continuation.resume()
                    }

                case .failure(let error):
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                        continuation.resume()
                    }
                }
            }
        }

        isLoading = false
    }

    // MARK: - Source Management

    /// Load connected sleep data sources, consolidating by wearable type
    /// (e.g., all Apple Watches become one "Apple Watch" entry)
    private func loadConnectedSources() async {
        // Get available sources from HealthKit (async call)
        let sources = await healthKitManager.getAvailableSleepSources()

        // Group sources by wearable type to consolidate (e.g., all Apple Watches → one entry)
        var sourcesByType: [String: [SleepDataSource]] = [:]
        for source in sources {
            let typeKey = source.wearableType.rawValue
            if sourcesByType[typeKey] == nil {
                sourcesByType[typeKey] = []
            }
            sourcesByType[typeKey]?.append(source)
        }

        // Create consolidated ConnectedSleepSource for each wearable type
        var consolidated: [ConnectedSleepSource] = []
        for (wearableType, typeSources) in sourcesByType {
            // Use the highest priority source as the representative
            guard let bestSource = typeSources.min(by: { $0.priority < $1.priority }) else { continue }

            // Collect all bundle IDs for this type (for filtering data later)
            let allBundleIds = typeSources.map { $0.bundleIdentifier }

            // Determine display name based on type
            let displayName: String
            let wearable = WearableType(rawValue: wearableType) ?? WearableType.unknown
            switch wearable {
            case .appleWatch:
                displayName = "Apple Watch"
            case .ouraRing:
                displayName = "Oura Ring"
            case .whoop:
                displayName = "WHOOP"
            case .garmin:
                displayName = "Garmin"
            case .fitbit:
                displayName = "Fitbit"
            case .unknown:
                // Check if it's actually iPhone based on bundle ID
                if bestSource.bundleIdentifier.contains("apple") && !bestSource.name.lowercased().contains("watch") {
                    displayName = "iPhone"
                } else {
                    displayName = bestSource.name
                }
            }

            // Check if this is iPhone (no sleep stages capability)
            let isIPhone = bestSource.bundleIdentifier.contains("apple") && !bestSource.name.lowercased().contains("watch") && wearable == .unknown

            consolidated.append(ConnectedSleepSource(
                id: wearableType, // Use wearable type as ID for consolidation
                bundleId: allBundleIds.joined(separator: ","), // Store all bundle IDs
                name: displayName,
                wearableType: wearableType,
                deviceModel: nil, // Don't show specific model for consolidated
                lastSyncDate: nil,
                priority: bestSource.priority,
                hrvCapability: healthKitManager.detectHRVCapability(for: wearable).rawValue,
                hasSleepStages: !isIPhone, // iPhone doesn't have sleep stages
                hasNativeScore: wearable == .ouraRing || wearable == .whoop
            ))
        }

        // Sort by priority (lower = better)
        connectedSources = consolidated.sorted { $0.priority < $1.priority }

        // Default all sources to visible (use the wearable type ID)
        visibleSourceIds = Set(connectedSources.map { $0.id })
    }

    /// Toggle source visibility
    func toggleSource(_ source: ConnectedSleepSource) {
        if visibleSourceIds.contains(source.id) {
            visibleSourceIds.remove(source.id)
        } else {
            visibleSourceIds.insert(source.id)
        }
    }

    /// Check if source is visible
    func isSourceVisible(_ source: ConnectedSleepSource) -> Bool {
        visibleSourceIds.contains(source.id)
    }

    // MARK: - HRV Data

    /// Load HRV data from history
    private func loadHRVData() async {
        await withCheckedContinuation { continuation in
            healthKitManager.fetchHRVProfiles(daysBack: 7) { [weak self] result in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                switch result {
                case .success(let summaries):
                    Task { @MainActor in
                        self.hrvSummaryHistory = summaries
                        self.todayHRVSummary = summaries.first

                        // Calculate HRV charges
                        self.calculateHRVCharges(from: summaries)

                        // Load HRV samples for current night if available
                        if let todaySummary = summaries.first {
                            await self.loadHRVSamplesForNight(date: todaySummary.date)
                        }

                        continuation.resume()
                    }

                case .failure(let error):
                    Task { @MainActor in
                        print("[SleepDataVM] HRV fetch error: \(error)")
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Calculate HRV Charge from summaries
    private func calculateHRVCharges(from summaries: [HRVNightlySummary]) {
        // Calculate/update baseline
        let (charges, baseline) = hrvChargeCalculator.calculateChargesForHistory(
            summaries: summaries,
            existingBaseline: hrvBaseline,
            userAge: nil, // TODO: Get from user profile
            userSex: nil  // TODO: Get from user profile
        )

        hrvChargeHistory = charges
        todayHRVCharge = charges.first
        hrvBaseline = baseline
    }

    /// Load HRV samples for a specific night (for charting)
    private func loadHRVSamplesForNight(date: String) async {
        // Get sleep session for the date
        await withCheckedContinuation { continuation in
            healthKitManager.fetchSleepData(daysBack: 7) { [weak self] result in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                switch result {
                case .success(let sleepData):
                    // Find the night matching the date
                    guard let night = sleepData.first(where: { ($0["date"] as? String) == date }),
                          let inBedStr = night["in_bed_time"] as? String,
                          let asleepStr = night["asleep_time"] as? String,
                          let wakeStr = night["wake_time"] as? String,
                          let inBedTime = self.parseTimeString(inBedStr),
                          let asleepTime = self.parseTimeString(asleepStr),
                          let wakeTime = self.parseTimeString(wakeStr) else {
                        continuation.resume()
                        return
                    }

                    let sourceStr = night["primary_source"] as? String ?? "Apple Watch"
                    let wearableType = WearableType(rawValue: sourceStr) ?? .appleWatch

                    let session = HealthKitManager.SleepSession(
                        inBedTime: inBedTime,
                        asleepTime: asleepTime,
                        wakeTime: wakeTime,
                        outOfBedTime: nil,
                        primarySource: wearableType
                    )

                    // Fetch HRV samples
                    self.healthKitManager.fetchHRVSamplesForChart(sleepSession: session) { samplesResult in
                        Task { @MainActor in
                            switch samplesResult {
                            case .success(let samples):
                                self.currentNightHRVSamples = samples
                            case .failure:
                                break
                            }
                            continuation.resume()
                        }
                    }

                case .failure:
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Sleep Scores

    /// Load sleep scores
    private func loadSleepScores() async {
        await withCheckedContinuation { continuation in
            healthKitManager.fetchSleepData(daysBack: 7) { [weak self] result in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                switch result {
                case .success(let sleepData):
                    Task { @MainActor in
                        // Convert to scoring format and calculate scores
                        var scores: [ZoeSleepScoreResult] = []

                        for (index, night) in sleepData.enumerated() {
                            guard let date = night["date"] as? String else { continue }

                            let data = SleepDataForScoring(
                                date: date,
                                totalSleepMins: night["total_sleep_mins"] as? Int ?? 0,
                                timeInBedMins: self.calculateTimeInBed(night),
                                deepSleepMins: night["deep_sleep_mins"] as? Int,
                                remSleepMins: night["rem_sleep_mins"] as? Int,
                                lightSleepMins: night["light_sleep_mins"] as? Int,
                                inBedTime: self.parseTimeString(night["in_bed_time"] as? String ?? ""),
                                wakeTime: self.parseTimeString(night["wake_time"] as? String ?? ""),
                                awakenings: night["interruptions_count"] as? Int,
                                source: night["primary_source"] as? String ?? "Apple Watch",
                                sourceBundleId: night["source_bundle_id"] as? String ?? "",
                                nativeScore: nil
                            )

                            // Get HRV charge for this date
                            let hrvCharge = self.hrvChargeHistory.first { $0.date == date }

                            // Calculate historical data for consistency
                            let historicalData = sleepData.dropFirst(index + 1).prefix(6).compactMap { pastNight -> SleepDataForScoring? in
                                guard let pastDate = pastNight["date"] as? String else { return nil }
                                return SleepDataForScoring(
                                    date: pastDate,
                                    totalSleepMins: pastNight["total_sleep_mins"] as? Int ?? 0,
                                    timeInBedMins: self.calculateTimeInBed(pastNight),
                                    deepSleepMins: pastNight["deep_sleep_mins"] as? Int,
                                    remSleepMins: pastNight["rem_sleep_mins"] as? Int,
                                    lightSleepMins: pastNight["light_sleep_mins"] as? Int,
                                    inBedTime: self.parseTimeString(pastNight["in_bed_time"] as? String ?? ""),
                                    wakeTime: self.parseTimeString(pastNight["wake_time"] as? String ?? ""),
                                    awakenings: pastNight["interruptions_count"] as? Int,
                                    source: pastNight["primary_source"] as? String ?? "Apple Watch",
                                    sourceBundleId: pastNight["source_bundle_id"] as? String ?? "",
                                    nativeScore: nil
                                )
                            }

                            let score = self.sleepScoreCalculator.calculateScore(
                                from: data,
                                historicalData: Array(historicalData),
                                hrvCharge: hrvCharge
                            )
                            scores.append(score)
                        }

                        self.sleepScoreHistory = scores
                        self.todayZoeScore = scores.first
                        continuation.resume()
                    }

                case .failure:
                    continuation.resume()
                }
            }
        }
    }

    /// Calculate time in bed from sleep data
    private func calculateTimeInBed(_ night: [String: Any]) -> Int {
        guard let inBedTime = parseTimeString(night["in_bed_time"] as? String ?? ""),
              let wakeTime = parseTimeString(night["wake_time"] as? String ?? "") else {
            return night["total_sleep_mins"] as? Int ?? 0
        }

        return Int(wakeTime.timeIntervalSince(inBedTime) / 60)
    }

    /// Calculate weekly summary
    private func calculateWeeklySummary() {
        weeklySummary = sleepScoreCalculator.calculateWeeklySummary(from: sleepScoreHistory)
    }

    // MARK: - Helpers

    /// Parse time string to Date
    private func parseTimeString(_ timeString: String?) -> Date? {
        guard let timeString = timeString, !timeString.isEmpty else { return nil }

        // Try ISO format first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: timeString) {
            return date
        }

        // Try standard ISO without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: timeString) {
            return date
        }

        // Try simple date-time format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = dateFormatter.date(from: timeString) {
            return date
        }

        return nil
    }
}
