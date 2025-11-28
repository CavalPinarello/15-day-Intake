//
//  SettingsView.swift
//  Zoe Sleep for Longevity System
//
//  Settings screen with appearance, accessibility, and debug options
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var questionnaireManager: QuestionnaireManager

    @State private var showingAdvanceDayConfirmation = false
    @State private var showingResetConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var isAdvancingDay = false

    var body: some View {
        List {
            // MARK: - Appearance Section
            Section {
                // Color Theme Picker
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

                // Accent Color Picker
                Picker(selection: $themeManager.accentColorOption) {
                    ForEach(ThemeManager.AccentColorOption.allCases) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 20, height: 20)
                            Text(color.rawValue)
                        }
                        .tag(color)
                    }
                } label: {
                    Label("Accent Color", systemImage: "paintpalette.fill")
                }

                // Color Preview
                HStack(spacing: 12) {
                    Text("Preview:")
                        .foregroundColor(.secondary)

                    ForEach(ThemeManager.AccentColorOption.allCases) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(themeManager.accentColorOption == color ? Color.primary : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                themeManager.accentColorOption = color
                            }
                    }
                }
                .padding(.vertical, 4)

            } header: {
                Text("Appearance")
            }

            // MARK: - Accessibility Section
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

            // MARK: - Developer Section
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

                // Debug Options (only shown when debug mode is on)
                if themeManager.debugMode {
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
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset Journey Progress", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                    .accessibleTapTarget()

                    // View Raw Data (placeholder)
                    NavigationLink {
                        DebugDataView()
                    } label: {
                        Label("View Raw Data", systemImage: "doc.text.magnifyingglass")
                            .foregroundColor(.orange)
                    }
                    .accessibleTapTarget()
                }

            } header: {
                Text("Developer")
            } footer: {
                if themeManager.debugMode {
                    Text("Debug mode enables testing features. Use 'Advance to Next Day' to skip waiting.")
                        .font(.caption)
                }
            }

            // MARK: - Account Section
            Section {
                // Profile
                NavigationLink {
                    ProfileView()
                } label: {
                    Label("Profile", systemImage: "person.circle.fill")
                }
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

            // MARK: - About Section
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
                    Text("2025.11.26")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            } footer: {
                Text("Zoe Sleep for Longevity System\nThe best sleep of your life and maximum daily energy while protecting your health.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(themeManager.currentColorScheme)
        .tint(themeManager.accentColor)

        // MARK: - Confirmations

        .confirmationDialog("Advance to Next Day?", isPresented: $showingAdvanceDayConfirmation) {
            Button("Advance to Day \(min(questionnaireManager.currentDay + 1, 15))") {
                advanceDay()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move your journey to the next day. This action is for testing purposes.")
        }

        .confirmationDialog("Reset Journey Progress?", isPresented: $showingResetConfirmation) {
            Button("Reset to Day 1", role: .destructive) {
                resetProgress()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all your progress and start the 15-day journey from Day 1. All responses will be cleared.")
        }

        .confirmationDialog("Sign Out?", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Actions

    private func advanceDay() {
        isAdvancingDay = true

        Task {
            do {
                // Call Convex to advance day
                try await ConvexService.shared.advanceToNextDay()
                await MainActor.run {
                    questionnaireManager.currentDay = min(questionnaireManager.currentDay + 1, 15)
                    isAdvancingDay = false
                }
            } catch {
                await MainActor.run {
                    isAdvancingDay = false
                    // Show error (in production, use proper error handling)
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

    private func signOut() {
        authManager.signOut()
    }
}

// MARK: - Placeholder Views
// Note: ProfileView is defined in AuthenticationView.swift

struct NotificationsSettingsView: View {
    var body: some View {
        Text("Notification Settings")
            .navigationTitle("Notifications")
    }
}

struct DebugDataView: View {
    @EnvironmentObject var questionnaireManager: QuestionnaireManager

    var body: some View {
        List {
            Section("Current State") {
                HStack {
                    Text("Current Day")
                    Spacer()
                    Text("\(questionnaireManager.currentDay)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Responses Count")
                    Spacer()
                    Text("\(questionnaireManager.responses.count)")
                        .foregroundColor(.secondary)
                }
            }

            Section("Gateway States") {
                ForEach(questionnaireManager.gatewayStates, id: \.gatewayType) { state in
                    HStack {
                        Text(state.gatewayType.rawValue)
                        Spacer()
                        if state.triggered {
                            Text("Triggered")
                                .foregroundColor(.orange)
                        } else {
                            Text("Not Triggered")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("Responses") {
                ForEach(questionnaireManager.responses.sorted(by: { $0.key < $1.key }), id: \.key) { key, response in
                    VStack(alignment: .leading) {
                        Text(key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(response.stringValue ?? response.numberValue.map { String($0) } ?? "N/A")
                            .font(.body)
                    }
                }
            }
        }
        .navigationTitle("Debug Data")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AuthenticationManager())
            .environmentObject(QuestionnaireManager.shared)
    }
}
