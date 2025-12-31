//
//  HealthKitIntegrationView.swift
//  Zoe Sleep for Longevity System
//
//  SwiftUI view for HealthKit integration
//

import SwiftUI
import HealthKit

struct HealthKitIntegrationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var isAuthorized = false
    @State private var isSyncing = false
    @State private var syncStatus: String = ""
    @State private var lastSyncDate: Date?

    private var theme: ColorTheme { ColorTheme.shared }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Health Data Sync")
                .font(.largeTitle)
                .bold()
                .foregroundColor(theme.primary)
                .padding()

            // Authentication Status
            if !authManager.isAuthenticated {
                VStack(spacing: 15) {
                    Text("Sign in required to sync health data")
                        .font(.headline)
                        .foregroundColor(theme.warning)
                        .multilineTextAlignment(.center)

                    Text("Please sign in to your Zoé Sleep account to enable health data synchronization with our platform.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(theme.warning.opacity(0.1))
                .cornerRadius(10)

                Spacer()
            }

            // HealthKit Availability
            if healthKitManager.isHealthKitAvailable {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                        Text("HealthKit Available")
                            .font(.headline)
                    }

                    if isAuthorized {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(theme.primary)
                            Text("Authorized")
                                .font(.subheadline)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(theme.warning)
                            Text("Not Authorized")
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(theme.backgroundTint)
                .cornerRadius(10)
            } else {
                Text("HealthKit is not available on this device")
                    .foregroundColor(theme.error)
                    .padding()
            }

            // Authorization Button
            if !isAuthorized {
                Button(action: {
                    requestAuthorization()
                }) {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("Request HealthKit Authorization")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }

            // Sync Button and Progress
            if isAuthorized {
                VStack(spacing: 12) {
                    // Progress View (shown during sync)
                    if healthKitManager.syncProgress.isActive || healthKitManager.syncProgress.currentStep == .complete {
                        VStack(spacing: 8) {
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 12)

                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(progressColor)
                                        .frame(width: geometry.size.width * healthKitManager.syncProgress.progress, height: 12)
                                        .animation(.easeInOut(duration: 0.3), value: healthKitManager.syncProgress.progress)
                                }
                            }
                            .frame(height: 12)

                            // Step indicator
                            HStack {
                                if healthKitManager.syncProgress.isActive {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if healthKitManager.syncProgress.currentStep == .complete {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if healthKitManager.syncProgress.currentStep == .failed {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }

                                Text(healthKitManager.syncProgress.statusMessage)
                                    .font(.subheadline)
                                    .foregroundColor(statusTextColor)

                                Spacer()

                                Text("\(Int(healthKitManager.syncProgress.progress * 100))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }

                            // Records info
                            if healthKitManager.syncProgress.recordsFetched > 0 || healthKitManager.syncProgress.recordsUploaded > 0 {
                                HStack(spacing: 16) {
                                    Label("\(healthKitManager.syncProgress.recordsFetched) fetched", systemImage: "arrow.down.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Label("\(healthKitManager.syncProgress.recordsUploaded) uploaded", systemImage: "arrow.up.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(theme.backgroundTint)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Sync Button
                    Button(action: {
                        syncHealthData()
                    }) {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isSyncing ? "Syncing..." : "Sync Health Data (6 months)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSyncing ? Color.gray : theme.success)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isSyncing)
                    .padding(.horizontal)
                }
            }

            // Debug: Test Sync with Mock Data (Simulator)
            #if DEBUG
            Button(action: {
                syncMockData()
            }) {
                HStack {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "ladybug")
                    }
                    Text(isSyncing ? "Syncing..." : "Test Sync (Mock Data)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSyncing ? Color.gray : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isSyncing)
            .padding(.horizontal)
            #endif

            // Sync Status (for errors or when not actively syncing)
            if !syncStatus.isEmpty && !healthKitManager.syncProgress.isActive {
                Text(syncStatus)
                    .font(.caption)
                    .foregroundColor(syncStatus.contains("success") || syncStatus.contains("Sync successful") ? theme.success : theme.error)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(theme.backgroundTint)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }

            // Last Sync Date
            if let lastSync = lastSyncDate {
                Text("Last synced: \(lastSync, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            checkAuthorizationStatus()
        }
    }

    // MARK: - Progress UI Helpers

    private var progressColor: Color {
        switch healthKitManager.syncProgress.currentStep {
        case .complete:
            return .green
        case .failed:
            return .red
        default:
            return theme.primary
        }
    }

    private var statusTextColor: Color {
        switch healthKitManager.syncProgress.currentStep {
        case .complete:
            return .green
        case .failed:
            return .red
        default:
            return .primary
        }
    }

    private func checkAuthorizationStatus() {
        // Check if we have authorization by verifying actual data access
        if healthKitManager.isHealthKitAvailable {
            // First check the manager's cached authorization state
            if healthKitManager.isAuthorized {
                isAuthorized = true
            } else {
                // Verify by attempting to access data
                healthKitManager.verifyDataAccess { hasAccess in
                    isAuthorized = hasAccess
                    if hasAccess {
                        syncStatus = "Authorization verified. Ready to sync."
                    }
                }
            }
        } else {
            isAuthorized = false
        }
    }
    
    private func requestAuthorization() {
        healthKitManager.requestAuthorization { success, error in
            DispatchQueue.main.async {
                if success {
                    isAuthorized = true
                    syncStatus = "Authorization granted! You can now sync your health data."
                } else {
                    isAuthorized = false
                    // Provide helpful guidance when authorization is denied
                    if let error = error {
                        syncStatus = "Authorization failed: \(error.localizedDescription)"
                    } else {
                        syncStatus = "Authorization not granted. To enable, go to Settings > Privacy & Security > Health > Zoe Sleep and turn on access."
                    }
                }
            }
        }
    }
    
    private func syncHealthData() {
        isSyncing = true
        syncStatus = "Starting sync..."

        healthKitManager.syncAllHealthData { result in
            DispatchQueue.main.async {
                isSyncing = false

                switch result {
                case .success(let response):
                    lastSyncDate = Date()

                    // Build detailed sync status
                    var statusParts: [String] = []

                    if let sleepInfo = response["sleepData"] as? [String: Any],
                       let synced = sleepInfo["synced"] as? Int {
                        statusParts.append("Sleep: \(synced) days")
                    }
                    if let hrInfo = response["heartRateData"] as? [String: Any],
                       let synced = hrInfo["synced"] as? Int, synced > 0 {
                        statusParts.append("Heart rate: \(synced) days")
                    }
                    if let actInfo = response["activityData"] as? [String: Any],
                       let synced = actInfo["synced"] as? Int, synced > 0 {
                        statusParts.append("Activity: \(synced) days")
                    }

                    let total = response["totalRecordsSynced"] as? Int ?? 0
                    if total > 0 {
                        syncStatus = "Sync successful! \(total) records synced."
                        if !statusParts.isEmpty {
                            syncStatus += "\n" + statusParts.joined(separator: ", ")
                        }
                    } else {
                        syncStatus = "Sync completed. No new data to sync."
                    }

                case .failure(let error):
                    syncStatus = "Sync failed: \(error.localizedDescription)"
                }
            }
        }
    }

    #if DEBUG
    /// Test sync with mock data - works in simulator without real HealthKit
    private func syncMockData() {
        isSyncing = true
        syncStatus = "Generating mock data..."

        Task {
            do {
                // Generate mock sleep data for last 7 days
                let mockSleepData = generateMockSleepData(days: 7)

                syncStatus = "Syncing \(mockSleepData.count) days of mock data..."

                // Get device ID
                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "simulator-test"

                // Transform to Convex format (same as real sync)
                let transformedData = transformMockSleepData(mockSleepData)

                print("[MockSync] Sending \(transformedData.count) records to Convex")
                print("[MockSync] Sample data: \(transformedData.first ?? [:])")

                // Sync to Convex
                let result = try await ConvexService.shared.syncSleepData(
                    deviceId: deviceId,
                    sleepData: transformedData
                )

                await MainActor.run {
                    isSyncing = false
                    lastSyncDate = Date()
                    if result.success {
                        syncStatus = "Sync successful! \(result.recordsSynced ?? mockSleepData.count) mock records synced."
                    } else {
                        syncStatus = "Sync completed but reported failure"
                    }
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncStatus = "Mock sync failed: \(error.localizedDescription)"
                    print("[MockSync] Error: \(error)")
                }
            }
        }
    }

    private func generateMockSleepData(days: Int) -> [[String: Any]] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var sleepData: [[String: Any]] = []

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateStr = dateFormatter.string(from: date)

            // Generate realistic sleep times (10pm - 7am with variation)
            let baseHour = 22 // 10 PM
            let sleepVariation = Int.random(in: -60...60) // +/- 1 hour in minutes

            var inBedComponents = calendar.dateComponents([.year, .month, .day], from: date)
            inBedComponents.hour = baseHour
            inBedComponents.minute = sleepVariation > 0 ? sleepVariation : 0
            let inBedDate = calendar.date(from: inBedComponents) ?? date

            let latencyMins = Int.random(in: 5...30)
            let asleepDate = calendar.date(byAdding: .minute, value: latencyMins, to: inBedDate) ?? inBedDate

            let totalSleepMins = Int.random(in: 360...480) // 6-8 hours
            let wakeDate = calendar.date(byAdding: .minute, value: totalSleepMins, to: asleepDate) ?? asleepDate

            // Sleep stages (should add up roughly to totalSleepMins)
            let deepPct = Double.random(in: 0.15...0.25)
            let remPct = Double.random(in: 0.20...0.25)
            let awakePct = Double.random(in: 0.05...0.10)
            let lightPct = 1.0 - deepPct - remPct - awakePct

            let deepMins = Int(Double(totalSleepMins) * deepPct)
            let remMins = Int(Double(totalSleepMins) * remPct)
            let awakeMins = Int(Double(totalSleepMins) * awakePct)
            let lightMins = totalSleepMins - deepMins - remMins - awakeMins

            let actualSleepMins = totalSleepMins - awakeMins
            let efficiency = Double(actualSleepMins) / Double(totalSleepMins) * 100.0

            sleepData.append([
                "date": dateStr,
                "in_bed_time": iso8601Formatter.string(from: inBedDate),
                "asleep_time": iso8601Formatter.string(from: asleepDate),
                "wake_time": iso8601Formatter.string(from: wakeDate),
                "total_sleep_mins": actualSleepMins,
                "sleep_efficiency": round(efficiency * 10) / 10,
                "deep_sleep_mins": deepMins,
                "light_sleep_mins": lightMins,
                "rem_sleep_mins": remMins,
                "awake_mins": awakeMins,
                "interruptions_count": Int.random(in: 0...5),
                "sleep_latency_mins": latencyMins,
                "primary_source": "Mock Data (Simulator)",
                "source_bundle_id": "com.zoesleep.mock",
                "all_sources": ["Mock Data"],
                "is_multi_source": false
            ])
        }

        return sleepData
    }

    private func transformMockSleepData(_ data: [[String: Any]]) -> [[String: Any]] {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

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
    #endif
}

struct HealthKitIntegrationView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        HealthKitIntegrationView()
            .environmentObject(authManager)
            .environmentObject(HealthKitManager(authManager: authManager))
    }
}

