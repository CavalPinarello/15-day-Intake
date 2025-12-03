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

/// App root that handles: Splash → Auth → Onboarding → Content
/// IMPORTANT: Onboarding only happens AFTER authentication
struct AppRootView: View {
    @State private var showSplash = true
    @State private var splashOpacity: Double = 1.0
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var onboardingManager: OnboardingManager

    var body: some View {
        ZStack {
            // Main content (underneath splash)
            mainContent
                .opacity(showSplash ? 0 : 1)

            // Fast splash screen (0.6s)
            if showSplash {
                SplashScreenView(onComplete: {
                    // Quick fade out
                    withAnimation(.easeOut(duration: 0.2)) {
                        splashOpacity = 0
                    }
                    // Remove splash
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showSplash = false
                    }
                }, duration: 0.6)
                .opacity(splashOpacity)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        // Step 1: Check authentication first
        if !authManager.isAuthenticated {
            // Not logged in → Show login/signup
            AuthenticationView()
        }
        // Step 2: Check onboarding (only after authenticated)
        else if !onboardingManager.hasCompletedOnboarding {
            // Logged in but needs onboarding → Show onboarding
            OnboardingView(onboardingManager: onboardingManager)
        }
        // Step 3: Everything complete → Show main app
        else {
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
