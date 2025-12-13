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
    @State private var minSplashTimeElapsed = false
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var onboardingManager: OnboardingManager

    // Splash should stay until:
    // 1. Minimum time elapsed (0.6s for animation)
    // 2. Session check is complete (isCheckingSession == false)
    private var shouldHideSplash: Bool {
        minSplashTimeElapsed && !authManager.isCheckingSession
    }

    var body: some View {
        ZStack {
            // Main content (underneath splash)
            mainContent
                .opacity(showSplash ? 0 : 1)

            // Splash screen - shows loading indicator while checking session
            if showSplash {
                SplashScreenView(
                    onComplete: {
                        // Mark minimum time elapsed
                        minSplashTimeElapsed = true
                    },
                    duration: 0.6,
                    isLoading: authManager.isCheckingSession,
                    loadingMessage: "Signing in"
                )
                .opacity(splashOpacity)
            }
        }
        .onChange(of: shouldHideSplash) { _, shouldHide in
            if shouldHide {
                // Quick fade out
                withAnimation(.easeOut(duration: 0.2)) {
                    splashOpacity = 0
                }
                // Remove splash
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showSplash = false
                }
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

    /// Convert text size multiplier to DynamicTypeSize for system-wide scaling
    private var dynamicTypeSize: DynamicTypeSize {
        switch themeManager.textSizeMultiplier {
        case ..<0.85: return .xSmall
        case 0.85..<0.95: return .small
        case 0.95..<1.05: return .medium
        case 1.05..<1.15: return .large
        case 1.15..<1.25: return .xLarge
        case 1.25..<1.35: return .xxLarge
        default: return .xxxLarge
        }
    }

    var body: some View {
        ContentView()
            .preferredColorScheme(themeManager.currentColorScheme)
            .tint(themeManager.accentColor)
            .dynamicTypeSize(dynamicTypeSize)  // Apply text size scaling app-wide
            .onChange(of: themeManager.appearanceMode) { _, _ in
                // Force UI update
            }
            .onChange(of: themeManager.accentColorOption) { _, _ in
                // Force UI update - sync to watch
                iOSWatchConnectivityManager.shared.sendThemeSettingsToWatch()
            }
            .onChange(of: themeManager.textSizeMultiplier) { _, _ in
                // Force UI update for text size changes
            }
            .onChange(of: themeManager.largeIconsMode) { _, _ in
                // Force UI update for large icons mode
            }
            .onChange(of: themeManager.highContrast) { _, _ in
                // Force UI update for high contrast mode
            }
            .onChange(of: themeManager.reduceMotion) { _, _ in
                // Force UI update for reduce motion
            }
    }
}
