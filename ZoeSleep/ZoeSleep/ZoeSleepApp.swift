//
//  ZoeSleepApp.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Main app entry point for iOS
//

import SwiftUI
import WatchConnectivity

@main
struct ZoeSleepApp: App {
    @StateObject private var authManager: AuthenticationManager
    @StateObject private var healthKitManager: HealthKitManager
    @StateObject private var onboardingManager = OnboardingManager.shared
    @Environment(\.scenePhase) private var scenePhase

    // Watch connectivity - initialized as singleton
    private let watchConnectivity = iOSWatchConnectivityManager.shared

    init() {
        // Create authManager first, then pass it to healthKitManager
        let auth = AuthenticationManager()
        _authManager = StateObject(wrappedValue: auth)
        _healthKitManager = StateObject(wrappedValue: HealthKitManager(authManager: auth))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(authManager)
                .environmentObject(healthKitManager)
                .environmentObject(ThemeManager.shared)
                .environmentObject(onboardingManager)
                .onAppear {
                    // Request HealthKit authorization when authenticated
                    if authManager.isAuthenticated {
                        healthKitManager.requestAuthorization { success, error in
                            if let error = error {
                                print("HealthKit authorization error: \(error)")
                            }
                        }

                        // Send current state to Watch (including theme settings)
                        watchConnectivity.sendUserDataToWatch()
                        watchConnectivity.sendThemeSettingsToWatch()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Refresh journey state when app becomes active
                        refreshJourneyState()
                    }
                }
        }
    }

    private func refreshJourneyState() {
        guard authManager.isAuthenticated else { return }
        Task {
            await QuestionnaireManager.shared.loadJourneyProgress()
            print("[iOS] Refreshed journey state on app activation")
        }
    }
}

/// App root that handles authentication -> onboarding -> content flow
struct AppRootView: View {
    @State private var showSplash = true
    @State private var splashOpacity: Double = 1.0
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var onboardingManager: OnboardingManager

    var body: some View {
        ZStack {
            // Main content (underneath)
            mainContent
                .opacity(showSplash ? 0 : 1)

            // Splash screen (on top) - brief, circadian-aware
            if showSplash {
                SplashScreenView(onComplete: {
                    // Quick fade out
                    withAnimation(.easeInOut(duration: 0.3)) {
                        splashOpacity = 0
                    }

                    // Remove splash after fade
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            showSplash = false
                        }
                    }
                }, duration: 1.2)
                .opacity(splashOpacity)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !authManager.isAuthenticated {
            // User not logged in - show authentication
            AuthenticationView()
        } else if !onboardingManager.hasCompletedOnboarding {
            // User logged in but hasn't completed onboarding
            OnboardingView(onboardingManager: onboardingManager)
        } else {
            // User logged in and completed onboarding - show main app
            ThemedRootView()
        }
    }
}

/// Wrapper view that ensures theme changes trigger re-renders
struct ThemedRootView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ContentView()
            .preferredColorScheme(themeManager.currentColorScheme)
            .tint(themeManager.accentColor)
            .onChange(of: themeManager.appearanceMode) { _, _ in
                // Force UI update
            }
            .onChange(of: themeManager.accentColorOption) { _, _ in
                // Force UI update - sync to watch
                iOSWatchConnectivityManager.shared.sendThemeSettingsToWatch()
            }
    }
}
