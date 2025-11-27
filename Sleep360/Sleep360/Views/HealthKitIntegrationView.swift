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

                    Text("Please sign in to your Zoe Sleep account to enable health data synchronization with our platform.")
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

            // Sync Button
            if isAuthorized {
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
                        Text(isSyncing ? "Syncing..." : "Sync Health Data")
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

            // Sync Status
            if !syncStatus.isEmpty {
                Text(syncStatus)
                    .font(.caption)
                    .foregroundColor(syncStatus.contains("success") ? theme.success : theme.error)
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
    
    private func checkAuthorizationStatus() {
        // Check if we have authorization
        // This is a simplified check - in production, check specific types
        if healthKitManager.isHealthKitAvailable {
            // You would check actual authorization status here
            // For now, we'll assume not authorized until user requests it
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
                    syncStatus = "Authorization failed: \(error?.localizedDescription ?? "Unknown error")"
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
                    syncStatus = "Sync successful! Data has been uploaded to the server."
                    lastSyncDate = Date()
                    
                    // Show sync results
                    if let results = response["results"] as? [String: Any] {
                        var statusParts: [String] = []
                        if let sleep = results["sleepData"] as? [String: Any] {
                            let inserted = sleep["inserted"] as? Int ?? 0
                            statusParts.append("Sleep: \(inserted) records")
                        }
                        if let activity = results["activityData"] as? [String: Any] {
                            let inserted = activity["inserted"] as? Int ?? 0
                            statusParts.append("Activity: \(inserted) records")
                        }
                        if !statusParts.isEmpty {
                            syncStatus += "\n" + statusParts.joined(separator: ", ")
                        }
                    }
                    
                case .failure(let error):
                    syncStatus = "Sync failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct HealthKitIntegrationView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        HealthKitIntegrationView()
            .environmentObject(authManager)
            .environmentObject(HealthKitManager(authManager: authManager))
    }
}

