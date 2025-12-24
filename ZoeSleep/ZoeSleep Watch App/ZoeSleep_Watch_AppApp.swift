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
    @StateObject private var watchConnectivity = WatchConnectivityManager()
    @StateObject private var healthManager = HealthKitWatchManager()
    @StateObject private var convexService = WatchConvexService.shared
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
                .preferredColorScheme(themeManager.currentColorScheme)
                .tint(themeManager.accentColor)
                .onAppear {
                    setupWatch()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Refresh state from Convex when app becomes active
                        refreshFromConvex()
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
}

struct WatchContentView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var themeManager: WatchThemeManager
    @State private var currentTab: WatchTab = .home
    @ObservedObject private var convexService = WatchConvexService.shared

    enum WatchTab {
        case home
        case health
        case settings
    }

    var body: some View {
        TabView(selection: $currentTab) {
            // Home - Minimal garden-based check-in hub
            MinimalHomeView()
                .tag(WatchTab.home)
                .tabItem {
                    Image(systemName: "leaf.fill")
                    Text("Garden")
                }

            // Health summary
            HealthSummaryView()
                .tag(WatchTab.health)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Health")
                }

            // Settings
            WatchSettingsView()
                .tag(WatchTab.settings)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .onAppear {
            // Request latest data from iPhone
            watchConnectivity.requestDataFromiPhone()
            // Schedule check-in notifications
            Task {
                let granted = await WatchNotificationManager.shared.requestAuthorization()
                if granted {
                    WatchNotificationManager.shared.scheduleCheckInReminders()
                    WatchNotificationManager.shared.registerNotificationCategories()
                }
            }
        }
        .onChange(of: currentTab) { _, newTab in
            // Refresh state from Convex when switching to home tab
            if newTab == .home {
                refreshFromConvex()
            }
        }
    }

    private func refreshFromConvex() {
        Task {
            guard convexService.isAuthenticated else { return }
            do {
                _ = try await convexService.fetchJourneyState()
                print("[Watch] Tab switch refresh: Day \(convexService.currentDay)")
            } catch {
                print("[Watch] Tab switch refresh failed: \(error.localizedDescription)")
            }
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
