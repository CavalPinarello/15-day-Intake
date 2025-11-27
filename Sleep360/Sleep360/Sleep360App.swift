//
//  Sleep360App.swift
//  Zoe Sleep for Longevity System
//
//  Main app entry point for iOS
//

import SwiftUI

@main
struct Sleep360App: App {
    @StateObject private var authManager: AuthenticationManager
    @StateObject private var healthKitManager: HealthKitManager

    init() {
        // Create authManager first, then pass it to healthKitManager
        let auth = AuthenticationManager()
        _authManager = StateObject(wrappedValue: auth)
        _healthKitManager = StateObject(wrappedValue: HealthKitManager(authManager: auth))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(healthKitManager)
                .onAppear {
                    // Request HealthKit authorization when authenticated
                    if authManager.isAuthenticated {
                        healthKitManager.requestAuthorization { success, error in
                            if let error = error {
                                print("HealthKit authorization error: \(error)")
                            }
                        }
                    }
                }
        }
    }
}
