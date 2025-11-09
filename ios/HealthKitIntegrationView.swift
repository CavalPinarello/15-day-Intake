//
//  HealthKitIntegrationView.swift
//  ZOE Sleep Platform
//
//  SwiftUI view for HealthKit integration
//

import SwiftUI
import HealthKit

struct HealthKitIntegrationView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var isAuthorized = false
    @State private var isSyncing = false
    @State private var syncStatus: String = ""
    @State private var lastSyncDate: Date?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Health Data Sync")
                .font(.largeTitle)
                .bold()
                .padding()
            
            // HealthKit Availability
            if healthKitManager.isHealthKitAvailable {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("HealthKit Available")
                            .font(.headline)
                    }
                    
                    if isAuthorized {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.blue)
                            Text("Authorized")
                                .font(.subheadline)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Not Authorized")
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            } else {
                Text("HealthKit is not available on this device")
                    .foregroundColor(.red)
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
                    .background(Color.blue)
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
                    .background(isSyncing ? Color.gray : Color.green)
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
                    .foregroundColor(syncStatus.contains("success") ? .green : .red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            // Last Sync Date
            if let lastSync = lastSyncDate {
                Text("Last synced: \(lastSync, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.gray)
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
        HealthKitIntegrationView()
    }
}

