//
//  ProfileSettingsView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Unified Profile view containing user info, Apple Health, and Settings
//

import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var onboardingManager = OnboardingManager.shared
    @ObservedObject var questionnaireManager = QuestionnaireManager.shared

    @State private var showingSignOutConfirmation = false
    @State private var showingResetOnboardingConfirmation = false
    @State private var showingAdvanceDayConfirmation = false
    @State private var showingResetJourneyConfirmation = false
    @State private var isAdvancingDay = false
    @State private var isRepairingSleepData = false
    @State private var repairSleepDataResult: String?

    @Environment(\.dismiss) private var dismiss

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Header
                profileHeaderSection

                // MARK: - Apple Health Section
                appleHealthSection

                // MARK: - Personal Info Section
                personalInfoSection

                // MARK: - Appearance Section
                appearanceSection

                // MARK: - Accessibility Section
                accessibilitySection

                // MARK: - Developer Section
                if themeManager.debugMode {
                    developerSection
                }

                // MARK: - Account Section
                accountSection

                // MARK: - About Section
                aboutSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(themeManager.currentColorScheme)
            .tint(themeManager.accentColor)

            // MARK: - Confirmations
            .confirmationDialog("Sign Out?", isPresented: $showingSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    // Dismiss this view first, then sign out
                    // This ensures we navigate back before auth state changes
                    dismiss()
                    authManager.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }

            .confirmationDialog("Reset Onboarding?", isPresented: $showingResetOnboardingConfirmation) {
                Button("Reset", role: .destructive) {
                    onboardingManager.resetOnboarding()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset your profile information and show the onboarding again.")
            }

            .confirmationDialog("Advance to Next Day?", isPresented: $showingAdvanceDayConfirmation) {
                Button("Advance to Day \(min(questionnaireManager.currentDay + 1, 15))") {
                    advanceDay()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will move your journey to the next day. This action is for testing purposes.")
            }

            .confirmationDialog("Reset Journey Progress?", isPresented: $showingResetJourneyConfirmation) {
                Button("Reset to Day 1", role: .destructive) {
                    resetProgress()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all your progress and start the 15-day journey from Day 1. All responses will be cleared.")
            }
        }
    }

    // MARK: - Profile Header Section

    private var profileHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                // Profile avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.primary.opacity(0.3), theme.primary.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)

                    if !onboardingManager.profile.name.isEmpty {
                        Text(String(onboardingManager.profile.name.prefix(1)).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(theme.primary)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundColor(theme.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !onboardingManager.profile.name.isEmpty {
                        Text(onboardingManager.profile.name)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    if let user = authManager.user {
                        Text(user.email ?? user.username)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("Day \(questionnaireManager.currentDay) of 15")
                            .font(.caption)
                    }
                    .foregroundColor(theme.primary)
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Apple Health Section

    private var appleHealthSection: some View {
        Section {
            // Connection status
            HStack {
                Image(systemName: healthKitManager.isAuthorized ? "heart.fill" : "heart")
                    .foregroundColor(healthKitManager.isAuthorized ? .red : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health")
                        .font(.body)
                    Text(healthKitManager.isAuthorized ? "Connected" : "Not connected")
                        .font(.caption)
                        .foregroundColor(healthKitManager.isAuthorized ? .green : .secondary)
                }

                Spacer()

                if !healthKitManager.isAuthorized {
                    Button("Connect") {
                        connectHealthKit()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .accessibleTapTarget()

            // Health data sync (if connected)
            if healthKitManager.isAuthorized {
                NavigationLink {
                    HealthKitIntegrationView()
                        .environmentObject(healthKitManager)
                        .environmentObject(authManager)
                } label: {
                    Label("Health Data Settings", systemImage: "waveform.path.ecg")
                }
                .accessibleTapTarget()
            }
        } header: {
            Text("Health Integration")
        } footer: {
            if !healthKitManager.isAuthorized {
                Text("Connect Apple Health to import sleep data and get personalized insights.")
            }
        }
    }

    // MARK: - Personal Info Section

    private var personalInfoSection: some View {
        Section {
            // Name
            HStack {
                Label("Name", systemImage: "person")
                Spacer()
                Text(onboardingManager.profile.name.isEmpty ? "Not set" : onboardingManager.profile.name)
                    .foregroundColor(.secondary)
            }

            // Age
            HStack {
                Label("Age", systemImage: "calendar")
                Spacer()
                Text("\(onboardingManager.profile.age) years")
                    .foregroundColor(.secondary)
            }

            // Height
            HStack {
                Label("Height", systemImage: "ruler")
                Spacer()
                if onboardingManager.profile.measurementSystem == MeasurementSystem.metric.rawValue {
                    Text("\(Int(onboardingManager.profile.heightCm)) cm")
                        .foregroundColor(.secondary)
                } else {
                    Text("\(onboardingManager.profile.heightFeet)' \(onboardingManager.profile.heightInches)\"")
                        .foregroundColor(.secondary)
                }
            }

            // Weight
            HStack {
                Label("Weight", systemImage: "scalemass")
                Spacer()
                if onboardingManager.profile.measurementSystem == MeasurementSystem.metric.rawValue {
                    Text("\(Int(onboardingManager.profile.weightKg)) kg")
                        .foregroundColor(.secondary)
                } else {
                    Text("\(Int(onboardingManager.profile.weightLbs)) lbs")
                        .foregroundColor(.secondary)
                }
            }

            // Wearables
            if !onboardingManager.profile.wearables.isEmpty {
                HStack {
                    Label("Devices", systemImage: "applewatch")
                    Spacer()
                    Text(onboardingManager.profile.wearables.joined(separator: ", "))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Note: Profile editing requires Debug Mode > Reset Onboarding
            // A proper profile editor could be added in the future
        } header: {
            Text("Personal Information")
        } footer: {
            if themeManager.debugMode {
                Text("Enable Debug Mode in Settings to reset and edit profile.")
                    .font(.caption)
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            // Color Theme Picker (simplified - removed accent color selector per Issue 15)
            Picker(selection: $themeManager.appearanceMode) {
                ForEach(ThemeManager.AppearanceMode.allCases) { mode in
                    HStack {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                    }
                    .tag(mode)
                }
            } label: {
                Label("Color Theme", systemImage: "paintbrush.fill")
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Circadian mode automatically adjusts colors based on time of day to support healthy sleep.")
        }
    }

    // MARK: - Accessibility Section

    private var accessibilitySection: some View {
        Section {
            // Large Icons Mode
            Toggle(isOn: $themeManager.largeIconsMode) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Large Icons Mode", systemImage: "textformat.size.larger")
                        .font(.headline)
                    Text("Makes buttons & text 30% larger")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(themeManager.accentColor)
            .accessibleTapTarget()

            // High Contrast
            Toggle(isOn: $themeManager.highContrast) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("High Contrast", systemImage: "circle.lefthalf.filled")
                        .font(.headline)
                    Text("Bolder colors, clearer borders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(themeManager.accentColor)
            .accessibleTapTarget()

            // Reduce Motion
            Toggle(isOn: $themeManager.reduceMotion) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Reduce Motion", systemImage: "figure.walk")
                        .font(.headline)
                    Text("Minimizes animations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(themeManager.accentColor)
            .accessibleTapTarget()

            // Text Size Slider
            VStack(alignment: .leading, spacing: 8) {
                Label("Text Size", systemImage: "textformat.size")
                    .font(.headline)

                HStack {
                    Text("A")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Slider(value: $themeManager.textSizeMultiplier, in: 0.8...1.4, step: 0.1)
                        .tint(themeManager.accentColor)

                    Text("A")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }

                Text("Preview: \(Int(themeManager.textSizeMultiplier * 100))%")
                    .font(.system(size: themeManager.scaledFontSize(14)))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

        } header: {
            Text("Accessibility")
        }
    }

    // MARK: - Developer Section

    private var developerSection: some View {
        Section {
            // Advance to Next Day
            Button {
                showingAdvanceDayConfirmation = true
            } label: {
                HStack {
                    Label("Advance to Next Day", systemImage: "forward.fill")
                        .foregroundColor(.orange)

                    Spacer()

                    if isAdvancingDay {
                        ProgressView()
                            .tint(.orange)
                    } else {
                        Text("Day \(questionnaireManager.currentDay) → \(min(questionnaireManager.currentDay + 1, 15))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .accessibleTapTarget()
            .disabled(questionnaireManager.currentDay >= 15 || isAdvancingDay)

            // Reset Journey Progress
            Button {
                showingResetJourneyConfirmation = true
            } label: {
                Label("Reset Journey Progress", systemImage: "arrow.counterclockwise")
                    .foregroundColor(.red)
            }
            .accessibleTapTarget()

            // Reset Onboarding (Debug only)
            Button {
                showingResetOnboardingConfirmation = true
            } label: {
                Label("Reset Onboarding", systemImage: "person.crop.circle.badge.minus")
                    .foregroundColor(.red)
            }
            .accessibleTapTarget()

            // View Raw Data
            NavigationLink {
                DebugDataView()
                    .environmentObject(questionnaireManager)
            } label: {
                Label("View Raw Data", systemImage: "doc.text.magnifyingglass")
                    .foregroundColor(.orange)
            }
            .accessibleTapTarget()

            // Repair Sleep Insights Data
            Button {
                repairSleepInsightsData()
            } label: {
                HStack {
                    Label("Repair Sleep Insights", systemImage: "wrench.and.screwdriver.fill")
                        .foregroundColor(.blue)

                    Spacer()

                    if isRepairingSleepData {
                        ProgressView()
                            .tint(.blue)
                    } else if let result = repairSleepDataResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Error") ? .red : .green)
                    }
                }
            }
            .accessibleTapTarget()
            .disabled(isRepairingSleepData)

            // Developer Panel (full controls)
            NavigationLink {
                DevPanelView(currentDay: $questionnaireManager.currentDay)
                    .environmentObject(themeManager)
                    .environmentObject(questionnaireManager)
            } label: {
                Label("Developer Panel", systemImage: "gearshape.2.fill")
                    .foregroundColor(.orange)
            }
            .accessibleTapTarget()

            #if DEBUG
            // Mock Data Generator
            NavigationLink {
                MockPlaybackView()
                    .environmentObject(themeManager)
                    .environmentObject(questionnaireManager)
            } label: {
                HStack {
                    Label("Generate Mock Data", systemImage: "wand.and.stars")
                        .foregroundColor(.purple)
                    Spacer()
                    Text("15 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibleTapTarget()
            #endif

        } header: {
            Text("Developer")
        } footer: {
            Text("Debug mode enables testing features. Use 'Generate Mock Data' to create 15 days of test questionnaire responses.")
                .font(.caption)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            // Debug Mode Toggle
            Toggle(isOn: $themeManager.debugMode) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Debug Mode", systemImage: "hammer.fill")
                        .font(.headline)
                    Text("Enable testing features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.orange)
            .accessibleTapTarget()

            // Notifications
            NavigationLink {
                NotificationsSettingsView()
            } label: {
                Label("Notifications", systemImage: "bell.badge.fill")
            }
            .accessibleTapTarget()

            // Sign Out
            Button(role: .destructive) {
                showingSignOutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
            }
            .accessibleTapTarget()

        } header: {
            Text("Account")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text("2025.12.02")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("About")
        } footer: {
            Text("Zoé Sleep for Longevity System\nThe best sleep of your life and maximum daily energy while protecting your health.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func connectHealthKit() {
        healthKitManager.requestAuthorization { success, error in
            if success {
                onboardingManager.markHealthKitConnected()
                onboardingManager.populateFromHealthKit(demographics: healthKitManager.demographics)
            }
        }
    }

    private func advanceDay() {
        isAdvancingDay = true

        Task {
            do {
                let response = try await ConvexService.shared.advanceToNextDay(debugMode: true)
                await MainActor.run {
                    if response.success, let newDay = response.newDay {
                        questionnaireManager.currentDay = newDay
                    }
                    isAdvancingDay = false
                }
            } catch {
                await MainActor.run {
                    isAdvancingDay = false
                    print("Failed to advance day: \(error)")
                }
            }
        }
    }

    private func resetProgress() {
        Task {
            do {
                try await ConvexService.shared.resetJourneyProgress()
                await MainActor.run {
                    questionnaireManager.currentDay = 1
                    questionnaireManager.responses = [:]
                }
            } catch {
                print("Failed to reset progress: \(error)")
            }
        }
    }

    private func repairSleepInsightsData() {
        isRepairingSleepData = true
        repairSleepDataResult = nil

        Task {
            do {
                let daysProcessed = try await ConvexService.shared.computeAllSleepMetricsFromResponses()
                await MainActor.run {
                    repairSleepDataResult = "\(daysProcessed) days"
                    isRepairingSleepData = false
                }
            } catch {
                await MainActor.run {
                    repairSleepDataResult = "Error"
                    isRepairingSleepData = false
                    print("Failed to repair sleep data: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileSettingsView()
        .environmentObject(AuthenticationManager())
        .environmentObject(HealthKitManager(authManager: nil))
        .environmentObject(ThemeManager.shared)
}
