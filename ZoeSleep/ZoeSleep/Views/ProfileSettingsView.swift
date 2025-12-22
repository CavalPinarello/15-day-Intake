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
    @State private var showingBodyMetricsEditor = false

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

                // MARK: - Units Section
                unitsSection

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

            // Body Metrics Editor Sheet
            .sheet(isPresented: $showingBodyMetricsEditor) {
                BodyMetricsEditorView(onboardingManager: onboardingManager, themeManager: themeManager)
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
                        Text("Day \(questionnaireManager.currentDay) of 14")
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

            // Height - show "Not set" if nil, tap to edit
            Button {
                showingBodyMetricsEditor = true
            } label: {
                HStack {
                    Label("Height", systemImage: "ruler")
                        .foregroundColor(.primary)
                    Spacer()
                    if let height = onboardingManager.profile.heightCm {
                        if onboardingManager.profile.measurementSystem == MeasurementSystem.metric.rawValue {
                            Text("\(Int(height)) cm")
                                .foregroundColor(.secondary)
                        } else if let feet = onboardingManager.profile.heightFeet,
                                  let inches = onboardingManager.profile.heightInches {
                            Text("\(feet)' \(inches)\"")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Not set")
                            .foregroundColor(theme.primary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Weight - show "Not set" if nil, tap to edit
            Button {
                showingBodyMetricsEditor = true
            } label: {
                HStack {
                    Label("Weight", systemImage: "scalemass")
                        .foregroundColor(.primary)
                    Spacer()
                    if let weight = onboardingManager.profile.weightKg {
                        if onboardingManager.profile.measurementSystem == MeasurementSystem.metric.rawValue {
                            Text("\(Int(weight)) kg")
                                .foregroundColor(.secondary)
                        } else if let lbs = onboardingManager.profile.weightLbs {
                            Text("\(Int(lbs)) lbs")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Not set")
                            .foregroundColor(theme.primary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
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
        } header: {
            Text("Personal Information")
        }
    }

    // MARK: - Units Section

    private var unitsSection: some View {
        Section {
            Picker(selection: Binding(
                get: {
                    MeasurementSystem(rawValue: onboardingManager.profile.measurementSystem) ?? .metric
                },
                set: { newValue in
                    onboardingManager.profile.measurementSystem = newValue.rawValue
                    onboardingManager.updateImperialFromMetric()
                    saveUnitsToServer()
                }
            )) {
                ForEach(MeasurementSystem.allCases) { system in
                    Text(system.rawValue).tag(system)
                }
            } label: {
                Label("Units", systemImage: "ruler.fill")
            }
        } header: {
            Text("Measurement Units")
        } footer: {
            Text("Changes how height and weight are displayed throughout the app.")
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
            // Enhanced Readability Mode - Main toggle for elderly users
            Toggle(isOn: $themeManager.enhancedReadabilityMode) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Enhanced Readability", systemImage: "text.magnifyingglass")
                        .font(.headline)
                    Text("50% larger text, bigger buttons, high contrast")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.green)
            .accessibleTapTarget()

            // Divider row to separate enhanced mode from individual settings
            if themeManager.enhancedReadabilityMode {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Enhanced mode is active")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            // Individual settings (shown but disabled when enhanced mode is on)
            Group {
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
                .disabled(themeManager.enhancedReadabilityMode)
                .opacity(themeManager.enhancedReadabilityMode ? 0.6 : 1.0)

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
                .disabled(themeManager.enhancedReadabilityMode)
                .opacity(themeManager.enhancedReadabilityMode ? 0.6 : 1.0)

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
                .disabled(themeManager.enhancedReadabilityMode)
                .opacity(themeManager.enhancedReadabilityMode ? 0.6 : 1.0)

                // Text Size Slider
                VStack(alignment: .leading, spacing: 8) {
                    Label("Text Size", systemImage: "textformat.size")
                        .font(.headline)

                    HStack {
                        Text("A")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Slider(value: $themeManager.textSizeMultiplier, in: 0.8...1.5, step: 0.1)
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
                .disabled(themeManager.enhancedReadabilityMode)
                .opacity(themeManager.enhancedReadabilityMode ? 0.6 : 1.0)
            }
        } header: {
            Text("Accessibility")
        } footer: {
            if themeManager.enhancedReadabilityMode {
                Text("Turn off Enhanced Readability to customize individual settings.")
            }
        }
    }

    // MARK: - Developer Section

    private var developerSection: some View {
        Section {
            // Unified Debug Tools (combines all debug functionality)
            // Available in all builds (including TestFlight) when Debug Mode is enabled
            NavigationLink {
                UnifiedDebugPanel()
                    .environmentObject(themeManager)
                    .environmentObject(questionnaireManager)
            } label: {
                HStack {
                    Label("Debug Tools", systemImage: "hammer.fill")
                        .foregroundColor(.purple)
                    Spacer()
                    Text("Data, Controls, Repair")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibleTapTarget()

            // View Raw Data (quick access)
            NavigationLink {
                DebugDataView()
                    .environmentObject(questionnaireManager)
            } label: {
                Label("View Raw Data", systemImage: "doc.text.magnifyingglass")
                    .foregroundColor(.orange)
            }
            .accessibleTapTarget()

            // Reset Onboarding
            Button {
                showingResetOnboardingConfirmation = true
            } label: {
                Label("Reset Onboarding", systemImage: "person.crop.circle.badge.minus")
                    .foregroundColor(.red)
            }
            .accessibleTapTarget()

        } header: {
            Text("Developer")
        } footer: {
            Text("Debug Tools provides mock data generation, journey controls, gateway testing, and repair utilities in one place.")
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

    private func saveUnitsToServer() {
        Task {
            do {
                try await ConvexService.shared.updateUserProfile(updates: [
                    "measurementSystem": onboardingManager.profile.measurementSystem
                ])
                print("[Profile] Units saved to server: \(onboardingManager.profile.measurementSystem)")
            } catch {
                print("[Profile] Failed to save units: \(error)")
            }
        }
    }
}

// MARK: - Body Metrics Editor View

struct BodyMetricsEditorView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var tempHeightCm: Double
    @State private var tempWeightKg: Double
    @State private var tempHeightFeet: Int
    @State private var tempHeightInches: Int
    @State private var tempWeightLbs: Double

    private var isMetric: Bool {
        onboardingManager.profile.measurementSystem == MeasurementSystem.metric.rawValue
    }

    init(onboardingManager: OnboardingManager, themeManager: ThemeManager) {
        self.onboardingManager = onboardingManager
        self.themeManager = themeManager

        // Initialize with existing values or defaults
        let heightCm = onboardingManager.profile.heightCm ?? 170
        let weightKg = onboardingManager.profile.weightKg ?? 70

        _tempHeightCm = State(initialValue: heightCm)
        _tempWeightKg = State(initialValue: weightKg)

        let totalInches = heightCm / 2.54
        _tempHeightFeet = State(initialValue: Int(totalInches / 12))
        _tempHeightInches = State(initialValue: Int(totalInches) % 12)
        _tempWeightLbs = State(initialValue: weightKg * 2.20462)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isMetric {
                        // Metric height input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Height")
                                .font(.headline)
                            HStack {
                                Slider(value: $tempHeightCm, in: 100...250, step: 1)
                                    .tint(themeManager.accentColor)
                                Text("\(Int(tempHeightCm)) cm")
                                    .frame(width: 70, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Metric weight input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight")
                                .font(.headline)
                            HStack {
                                Slider(value: $tempWeightKg, in: 30...200, step: 0.5)
                                    .tint(themeManager.accentColor)
                                Text("\(Int(tempWeightKg)) kg")
                                    .frame(width: 70, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // Imperial height input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Height")
                                .font(.headline)
                            HStack {
                                Picker("Feet", selection: $tempHeightFeet) {
                                    ForEach(3...8, id: \.self) { ft in
                                        Text("\(ft) ft").tag(ft)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100)

                                Picker("Inches", selection: $tempHeightInches) {
                                    ForEach(0...11, id: \.self) { inches in
                                        Text("\(inches) in").tag(inches)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100)
                            }
                            .frame(height: 120)
                        }

                        // Imperial weight input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight")
                                .font(.headline)
                            HStack {
                                Slider(value: $tempWeightLbs, in: 66...440, step: 1)
                                    .tint(themeManager.accentColor)
                                Text("\(Int(tempWeightLbs)) lbs")
                                    .frame(width: 80, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Body Measurements")
                } footer: {
                    Text("Connect Apple Health in settings to sync these values automatically.")
                }
            }
            .navigationTitle("Edit Body Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMetrics()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveMetrics() {
        if isMetric {
            onboardingManager.profile.heightCm = tempHeightCm
            onboardingManager.profile.weightKg = tempWeightKg
        } else {
            // Convert imperial to metric
            let totalInches = Double(tempHeightFeet * 12 + tempHeightInches)
            onboardingManager.profile.heightCm = totalInches * 2.54
            onboardingManager.profile.weightKg = tempWeightLbs / 2.20462
        }

        // Update temp values in OnboardingManager
        onboardingManager.updateImperialFromMetric()

        // Save to server
        Task {
            do {
                var updates: [String: Any] = [:]
                if let height = onboardingManager.profile.heightCm {
                    updates["heightCm"] = height
                }
                if let weight = onboardingManager.profile.weightKg {
                    updates["weightKg"] = weight
                }
                if !updates.isEmpty {
                    try await ConvexService.shared.updateUserProfile(updates: updates)
                    print("[Profile] Body metrics saved to server")
                }
            } catch {
                print("[Profile] Failed to save body metrics: \(error)")
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
