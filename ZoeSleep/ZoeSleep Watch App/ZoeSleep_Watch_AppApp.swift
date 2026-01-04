//
//  ZoeSleep_Watch_AppApp.swift
//  Zoe Sleep - Sleep Better, Live Longer (watchOS)
//
//  Main app entry point for Apple Watch
//

import SwiftUI
import WatchKit
import WatchConnectivity

@main
struct ZoeSleep_Watch_App: App {
    @ObservedObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var healthManager = HealthKitWatchManager.shared
    @StateObject private var convexService = WatchConvexService.shared
    @StateObject private var notificationManager = WatchNotificationManager.shared
    @ObservedObject private var themeManager = WatchThemeManager.shared
    @State private var isAuthenticated = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(watchConnectivity)
                .environmentObject(healthManager)
                .environmentObject(themeManager)
                .environmentObject(convexService)
                .environmentObject(notificationManager)
                .preferredColorScheme(themeManager.currentColorScheme)
                .tint(themeManager.accentColor)
                .onAppear {
                    setupWatch()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Refresh state from Convex when app becomes active
                        refreshFromConvex()
                        // Check if new day and reschedule notifications
                        notificationManager.resetForNewDay()
                    }
                }
        }
    }

    private func setupWatch() {
        // Initialize watch connectivity
        watchConnectivity.activate()

        // Request HealthKit permissions
        healthManager.requestPermissions()

        // Check authentication status
        checkAuthenticationStatus()

        // Initial sync with Convex (will auto-login if needed)
        refreshFromConvex()

        // Setup notifications
        setupNotifications()
    }

    private func checkAuthenticationStatus() {
        // Check if user is authenticated via iPhone sync
        isAuthenticated = watchConnectivity.isUserAuthenticated
    }

    private func refreshFromConvex() {
        Task {
            // This will auto-login if not authenticated, then fetch state
            await convexService.refreshFromConvex()
            print("[Watch] Current day: \(convexService.currentDay)")
        }
    }

    private func setupNotifications() {
        Task {
            // Request notification authorization
            let granted = await notificationManager.requestAuthorization()
            if granted {
                // Register notification categories for actions
                notificationManager.registerNotificationCategories()
                // Schedule all notifications based on Convex status
                await notificationManager.scheduleAllNotifications()
                // Debug: Print scheduled notifications
                notificationManager.debugPrintScheduledNotifications()
            }
        }
    }
}

struct WatchContentView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var themeManager: WatchThemeManager
    @EnvironmentObject var notificationManager: WatchNotificationManager
    @ObservedObject private var convexService = WatchConvexService.shared

    var body: some View {
        // Simple single-screen experience - no tabs
        MinimalHomeView()
            .onAppear {
                // Request latest data from iPhone (syncs credentials)
                watchConnectivity.requestDataFromiPhone()
            }
    }
}

struct HealthSummaryView: View {
    @EnvironmentObject var healthManager: HealthKitWatchManager
    @EnvironmentObject var themeManager: WatchThemeManager

    private var theme: WatchColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 8) {
            Text("Health Summary")
                .font(.headline)
                .foregroundColor(theme.primary)
                .padding(.bottom)

            if let sleepData = healthManager.lastNightSleep {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Night's Sleep")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(sleepData.duration, specifier: "%.1f") hours")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.primary)
                }
                .padding(.bottom)
            }

            Button("Sync Health Data") {
                healthManager.syncHealthData()
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.accentColor)
        }
        .padding()
    }
}

#Preview {
    WatchContentView()
}
