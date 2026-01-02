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
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    /// Handle deep links from Watch or other sources
    /// URL format: zoesleep://[action]?[parameters]
    /// Examples:
    ///   zoesleep://sleeplog - Open sleep log questionnaire
    ///   zoesleep://assessment - Open assessment questionnaire
    ///   zoesleep://home - Open home/dashboard
    private func handleDeepLink(_ url: URL) {
        print("[iOS] Received deep link: \(url)")

        guard url.scheme == "zoesleep" else { return }

        let action = url.host ?? ""

        switch action {
        case "sleeplog":
            // Post notification to navigate to sleep log
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": "sleeplog"]
            )
        case "assessment":
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": "assessment"]
            )
        case "home", "":
            // Just opening the app - no specific navigation needed
            print("[iOS] Deep link to home - app opened")
        default:
            print("[iOS] Unknown deep link action: \(action)")
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

/// App root that handles: Splash → JourneyIntro → Auth → Onboarding → Content
/// Flow: Splash seamlessly transitions to JourneyIntro for ALL first-time users
struct AppRootView: View {
    @State private var showSplash = true
    @State private var splashOpacity: Double = 1.0
    @State private var minSplashTimeElapsed = false
    @State private var showJourneyIntro = false
    @State private var splashTransitioning = false
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var onboardingManager: OnboardingManager

    // Track if this is a fresh install (no install marker in UserDefaults)
    private static let installMarkerKey = "app_install_marker_v1"

    // Splash should stay until:
    // 1. Minimum time elapsed (3.5s to appreciate the logo)
    // 2. Session check is complete (isCheckingSession == false)
    private var shouldHideSplash: Bool {
        minSplashTimeElapsed && !authManager.isCheckingSession
    }

    // Show journey intro for first-time app users (BEFORE auth)
    // This explains the app before asking them to sign up
    private var shouldShowJourneyIntro: Bool {
        let shouldShow = !onboardingManager.hasSeenJourneyIntro
        print("[AppRoot] shouldShowJourneyIntro: \(shouldShow) (hasSeenJourneyIntro: \(onboardingManager.hasSeenJourneyIntro))")
        return shouldShow
    }

    /// Check if this is a fresh install and reset journey intro if so
    private func checkFreshInstall() {
        let hasInstallMarker = UserDefaults.standard.bool(forKey: Self.installMarkerKey)
        print("[AppRoot] Fresh install check: hasInstallMarker=\(hasInstallMarker)")

        if !hasInstallMarker {
            // Fresh install - reset journey intro to ensure it shows
            print("[AppRoot] Fresh install detected - resetting journey intro flag")
            onboardingManager.resetJourneyIntro()
            UserDefaults.standard.set(true, forKey: Self.installMarkerKey)
        }
    }

    var body: some View {
        ZStack {
            // Main content (underneath splash/intro)
            mainContent
                .opacity(showSplash || showJourneyIntro ? 0 : 1)

            // Journey intro - shows right after splash for first-time users
            // Uses same aurora background for seamless transition
            if showJourneyIntro {
                JourneyIntroView(isPresented: $showJourneyIntro)
                    .environmentObject(ThemeManager.shared)
                    .transition(.opacity)
            }

            // Splash screen - shows loading indicator while checking session
            if showSplash {
                SplashScreenView(
                    onComplete: {
                        // Mark minimum time elapsed
                        minSplashTimeElapsed = true
                    },
                    duration: 3.5,  // Longer duration to appreciate the logo
                    isLoading: authManager.isCheckingSession,
                    loadingMessage: "Signing in",
                    isTransitioning: $splashTransitioning
                )
                .opacity(splashOpacity)
            }
        }
        .onAppear {
            // Check for fresh install and reset journey intro if needed
            checkFreshInstall()
        }
        .onChange(of: shouldHideSplash) { _, shouldHide in
            if shouldHide {
                print("[AppRoot] Splash hiding - shouldShowJourneyIntro: \(shouldShowJourneyIntro)")
                // Check if we should show journey intro (seamless transition)
                if shouldShowJourneyIntro {
                    // Step 1: Start logo moving up animation
                    splashTransitioning = true

                    // Step 2: After logo moves, fade splash and show intro
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            splashOpacity = 0
                            showJourneyIntro = true
                        }
                    }

                    // Step 3: Remove splash from view hierarchy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showSplash = false
                    }
                } else {
                    // Normal fade out to main content
                    withAnimation(.easeOut(duration: 0.3)) {
                        splashOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSplash = false
                    }
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
        // Step 2: Check onboarding (after auth AND after journey intro)
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
