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
                    // Only request HealthKit authorization AFTER onboarding is complete
                    // During onboarding, HealthKit is requested at the HealthConnect step
                    if authManager.isAuthenticated && onboardingManager.hasCompletedOnboarding {
                        healthKitManager.requestAuthorization { success, error in
                            if let error = error {
                                print("HealthKit authorization error: \(error)")
                            }
                        }

                        // Schedule notifications from saved settings (using comprehensive system)
                        Task {
                            await NotificationManager.shared.scheduleAllNotificationsFromSettings()
                        }
                    }

                    // Send Watch sync even during onboarding (for theme settings)
                    if authManager.isAuthenticated {
                        watchConnectivity.sendUserDataToWatch()
                        watchConnectivity.sendThemeSettingsToWatch()
                        // Sync notification times to Watch
                        if iOSWatchConnectivityManager.shared.isWatchAppInstalled {
                            watchConnectivity.syncNotificationTimesToWatch()
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Refresh journey state when app becomes active
                        refreshJourneyState()

                        // Reschedule notifications from saved settings when app becomes active
                        // This ensures notifications are scheduled even after being cancelled
                        if authManager.isAuthenticated {
                            Task {
                                await NotificationManager.shared.scheduleAllNotificationsFromSettings()
                            }
                            // Sync notification times to Watch on app activation
                            if iOSWatchConnectivityManager.shared.isWatchAppInstalled {
                                watchConnectivity.syncNotificationTimesToWatch()
                            }

                            // Smart sync: sync HealthKit data on app launch if >30 mins since last sync
                            if onboardingManager.hasCompletedOnboarding && healthKitManager.isAuthorized {
                                performSmartHealthKitSync()
                            }
                        }
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
    ///   zoesleep://checkin/morning - Open morning check-in
    ///   zoesleep://checkin/midday - Open midday check-in
    ///   zoesleep://checkin/evening - Open evening check-in
    ///   zoesleep://home - Open home/dashboard
    private func handleDeepLink(_ url: URL) {
        print("[iOS] Received deep link: \(url)")

        guard url.scheme == "zoesleep" else { return }

        let action = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

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
        case "checkin":
            // Handle check-in deep links: zoesleep://checkin/morning, zoesleep://checkin/midday, zoesleep://checkin/evening
            let checkInType = pathComponents.first ?? "morning"
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": "checkin_\(checkInType)"]
            )
        case "home", "":
            // Just opening the app - navigate to home
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": "home"]
            )
        default:
            print("[iOS] Unknown deep link action: \(action)")
        }
    }

    private func refreshJourneyState() {
        guard authManager.isAuthenticated else { return }
        Task {
            await QuestionnaireManager.shared.loadJourneyProgress()
            print("[iOS] Refreshed journey state on app activation")

            // Check if we need to refresh notifications for a new day
            await checkAndRefreshNotificationsForNewDay()
        }
    }

    /// Perform smart HealthKit sync if enough time has passed since last sync
    /// Syncs sleep and HRV data on app launch to keep data fresh
    /// Smart sync: sync HealthKit data on app launch if >30 mins since last sync
    /// Fetches last 7 days of sleep data and syncs to Convex
    private func performSmartHealthKitSync() {
        healthKitManager.smartSync { didSync in
            if didSync {
                print("[iOS] ✅ Smart sync completed on app launch")
            }
        }
    }

    /// Check if it's a new day and refresh notification messages
    /// This ensures variety in notification messages (not the same every day)
    private func checkAndRefreshNotificationsForNewDay() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastRefreshKey = "lastNotificationRefreshDate"

        // Get the last refresh date
        if let lastRefreshDate = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date {
            let lastRefreshDay = calendar.startOfDay(for: lastRefreshDate)

            // If same day, no need to refresh
            if lastRefreshDay == today {
                return
            }
        }

        // New day - reschedule notifications with fresh random messages
        print("[iOS] New day detected - refreshing notification messages")
        await NotificationManager.shared.scheduleFromSavedSettings()

        // Update the last refresh date
        UserDefaults.standard.set(Date(), forKey: lastRefreshKey)
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
