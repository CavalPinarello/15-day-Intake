//
//  VoiceNavigationView.swift
//  ZoeSleep
//
//  Voice-based navigation menu for accessibility mode.
//  Provides spoken options and voice-controlled navigation.
//

import SwiftUI
import Combine

struct VoiceNavigationView: View {
    @StateObject private var accessibilityManager = AccessibilityVoiceManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    @State private var selectedIndex: Int = 0
    @State private var isListening: Bool = false

    let navigationItems: [VoiceNavigationItem]
    let onSelect: (VoiceNavigationItem) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                header

                // Navigation list
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(navigationItems.enumerated()), id: \.element.id) { index, item in
                                NavigationItemButton(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    index: index + 1,
                                    accessibilityManager: accessibilityManager
                                ) {
                                    selectItem(item)
                                }
                                .id(index)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }

                // Voice input area
                voiceInputArea

                // Navigation hint
                Text("Say a number, or 'next' and 'previous' to navigate")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
            }
        }
        .onAppear {
            announceNavigation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityNavigateBack)) { _ in
            dismiss()
        }
    }

    // MARK: - Background

    private var backgroundColor: some View {
        Group {
            if accessibilityManager.highContrastMode {
                Color.black
            } else {
                theme.backgroundGradient
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                accessibilityManager.speak("Going back")
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(textColor)
                    .frame(width: accessibilityManager.minimumTouchTargetSize,
                           height: accessibilityManager.minimumTouchTargetSize)
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Go back")

            Spacer()

            Text("Navigation")
                .font(.title2.bold())
                .foregroundColor(textColor)

            Spacer()

            // Help button
            Button {
                announceNavigation()
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(textColor)
                    .frame(width: accessibilityManager.minimumTouchTargetSize,
                           height: accessibilityManager.minimumTouchTargetSize)
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Read options aloud")
        }
        .padding()
    }

    // MARK: - Voice Input Area

    private var voiceInputArea: some View {
        HStack(spacing: 20) {
            // Previous button
            Button {
                navigatePrevious()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.title)
                    .foregroundColor(textColor)
                    .frame(width: accessibilityManager.minimumTouchTargetSize,
                           height: accessibilityManager.minimumTouchTargetSize)
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Previous option")

            // Voice button
            Button {
                toggleListening()
            } label: {
                ZStack {
                    Circle()
                        .fill(isListening ? Color.green : accentColor)
                        .frame(width: 80, height: 80)

                    Image(systemName: isListening ? "waveform" : "mic.fill")
                        .font(.title)
                        .foregroundColor(accessibilityManager.highContrastMode ? .black : theme.textOnPrimary)
                }
            }
            .accessibilityLabel(isListening ? "Stop listening" : "Start listening")

            // Next button
            Button {
                navigateNext()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title)
                    .foregroundColor(textColor)
                    .frame(width: accessibilityManager.minimumTouchTargetSize,
                           height: accessibilityManager.minimumTouchTargetSize)
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Next option")
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var textColor: Color {
        accessibilityManager.highContrastMode ? .white : theme.primaryText
    }

    private var secondaryTextColor: Color {
        accessibilityManager.highContrastMode ? .white.opacity(0.7) : theme.secondaryText
    }

    private var buttonBackgroundColor: Color {
        accessibilityManager.highContrastMode ? .white.opacity(0.2) : theme.cardBackground
    }

    private var accentColor: Color {
        accessibilityManager.highContrastMode ? .white : theme.accent
    }

    // MARK: - Actions

    private func announceNavigation() {
        var announcement = "Navigation menu. "
        announcement += "\(navigationItems.count) options available. "

        for (index, item) in navigationItems.enumerated() {
            announcement += "Option \(index + 1): \(item.title). "
        }

        announcement += "Say a number to select, or say 'next' and 'previous' to move through options."

        accessibilityManager.speak(announcement)
    }

    private func navigateNext() {
        selectedIndex = (selectedIndex + 1) % navigationItems.count
        let item = navigationItems[selectedIndex]
        accessibilityManager.speak("\(selectedIndex + 1). \(item.title). \(item.description)")
    }

    private func navigatePrevious() {
        selectedIndex = (selectedIndex - 1 + navigationItems.count) % navigationItems.count
        let item = navigationItems[selectedIndex]
        accessibilityManager.speak("\(selectedIndex + 1). \(item.title). \(item.description)")
    }

    private func selectItem(_ item: VoiceNavigationItem) {
        accessibilityManager.speak("Opening \(item.title)")
        onSelect(item)
    }

    private func toggleListening() {
        isListening.toggle()

        if isListening {
            // Start listening for navigation commands
            // In a full implementation, this would integrate with speech recognition
            accessibilityManager.speak("Listening. Say a number, or 'select' to choose current option.")
        } else {
            // Stop listening
        }
    }

    private func processVoiceInput(_ transcript: String) {
        let lowercased = transcript.lowercased()

        // Check for number
        if let number = extractNumber(from: lowercased), number > 0, number <= navigationItems.count {
            selectedIndex = number - 1
            selectItem(navigationItems[selectedIndex])
            return
        }

        // Check for navigation commands
        if lowercased.contains("next") {
            navigateNext()
        } else if lowercased.contains("previous") || lowercased.contains("back") {
            navigatePrevious()
        } else if lowercased.contains("select") || lowercased.contains("choose") || lowercased.contains("open") {
            selectItem(navigationItems[selectedIndex])
        } else if lowercased.contains("repeat") || lowercased.contains("again") {
            let item = navigationItems[selectedIndex]
            accessibilityManager.speak("\(selectedIndex + 1). \(item.title). \(item.description)")
        } else if lowercased.contains("help") {
            announceNavigation()
        }
    }

    private func extractNumber(from text: String) -> Int? {
        let numberWords: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5
        ]

        // Check for number words
        for (word, number) in numberWords {
            if text.contains(word) {
                return number
            }
        }

        // Check for digits
        let digits = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits)
    }
}

// MARK: - Navigation Item Model

struct VoiceNavigationItem: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let destination: NavigationDestination

    static func == (lhs: VoiceNavigationItem, rhs: VoiceNavigationItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum NavigationDestination {
    case dashboard
    case sleepLog
    case assessment
    case checkIn
    case cbti
    case settings
    case profile
    case help
    case custom(String)
}

// MARK: - Navigation Item Button

struct NavigationItemButton: View {
    let item: VoiceNavigationItem
    let isSelected: Bool
    let index: Int
    let accessibilityManager: AccessibilityVoiceManager
    let action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Number badge
                Text("\(index)")
                    .font(.headline)
                    .foregroundColor(isSelected ? buttonTextColor : secondaryTextColor)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? accentColor : badgeBackgroundColor)
                    .clipShape(Circle())

                // Icon
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? accentColor : textColor)
                    .frame(width: 32)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(textColor)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(accentColor)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: accessibilityManager.buttonHeight)
            .background(isSelected ? selectedBackgroundColor : buttonBackgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
        }
        .accessibilityLabel("\(index). \(item.title). \(item.description)")
        .accessibilityHint("Double tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Colors

    private var textColor: Color {
        accessibilityManager.highContrastMode ? .white : theme.primaryText
    }

    private var secondaryTextColor: Color {
        accessibilityManager.highContrastMode ? .white.opacity(0.7) : theme.secondaryText
    }

    private var buttonBackgroundColor: Color {
        accessibilityManager.highContrastMode ? .white.opacity(0.1) : theme.cardBackground
    }

    private var selectedBackgroundColor: Color {
        accessibilityManager.highContrastMode ? .white.opacity(0.2) : theme.accent.opacity(0.15)
    }

    private var accentColor: Color {
        accessibilityManager.highContrastMode ? .white : theme.accent
    }

    private var badgeBackgroundColor: Color {
        accessibilityManager.highContrastMode ? .white.opacity(0.2) : theme.cardBackground.opacity(0.5)
    }

    private var buttonTextColor: Color {
        accessibilityManager.highContrastMode ? .black : theme.textOnPrimary
    }
}

// MARK: - Default Navigation Items

extension VoiceNavigationItem {
    static let defaultItems: [VoiceNavigationItem] = [
        VoiceNavigationItem(
            id: "dashboard",
            title: "Dashboard",
            description: "View your sleep progress and daily tasks",
            icon: "chart.bar.fill",
            destination: .dashboard
        ),
        VoiceNavigationItem(
            id: "sleep_log",
            title: "Sleep Log",
            description: "Record last night's sleep",
            icon: "moon.fill",
            destination: .sleepLog
        ),
        VoiceNavigationItem(
            id: "assessment",
            title: "Assessment",
            description: "Complete your daily questions",
            icon: "list.clipboard.fill",
            destination: .assessment
        ),
        VoiceNavigationItem(
            id: "check_in",
            title: "Energy Check-In",
            description: "Track your energy, mood, and focus",
            icon: "bolt.fill",
            destination: .checkIn
        ),
        VoiceNavigationItem(
            id: "cbti",
            title: "Sleep Coaching",
            description: "CBT-I therapy sessions with Zoe",
            icon: "person.fill.questionmark",
            destination: .cbti
        ),
        VoiceNavigationItem(
            id: "settings",
            title: "Settings",
            description: "Adjust app settings and preferences",
            icon: "gearshape.fill",
            destination: .settings
        ),
        VoiceNavigationItem(
            id: "profile",
            title: "Profile",
            description: "View and edit your profile",
            icon: "person.circle.fill",
            destination: .profile
        ),
        VoiceNavigationItem(
            id: "help",
            title: "Help",
            description: "Get help using the app",
            icon: "questionmark.circle.fill",
            destination: .help
        )
    ]
}

// MARK: - Preview

#Preview {
    VoiceNavigationView(
        navigationItems: VoiceNavigationItem.defaultItems,
        onSelect: { item in
            print("Selected: \(item.title)")
        }
    )
    .environmentObject(ThemeManager.shared)
}
