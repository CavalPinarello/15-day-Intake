//
//  WatchThemeManager.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Manages app-wide theming for Apple Watch, synced from iPhone
//

import Foundation
import SwiftUI

@MainActor
class WatchThemeManager: ObservableObject {
    static let shared = WatchThemeManager()

    // MARK: - Appearance Mode

    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        case circadian = "Circadian"

        var id: String { rawValue }
    }

    // MARK: - Accent Color

    enum AccentColorOption: String, CaseIterable, Identifiable {
        case teal = "Teal"
        case coral = "Coral"
        case violet = "Violet"
        case gold = "Gold"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .teal: return Color(red: 0.31, green: 0.80, blue: 0.77)    // #4ECDC4
            case .coral: return Color(red: 1.0, green: 0.42, blue: 0.42)    // #FF6B6B
            case .violet: return Color(red: 0.42, green: 0.36, blue: 0.90)  // #6C5CE7
            case .gold: return Color(red: 1.0, green: 0.85, blue: 0.24)     // #FFD93D
            }
        }
    }

    // MARK: - Circadian Color Palette

    struct CircadianColors {
        // Dawn/Energy: Warm coral to soft gold
        static let dawnStart = Color(red: 1.0, green: 0.42, blue: 0.42)     // #FF6B6B
        static let dawnEnd = Color(red: 1.0, green: 0.85, blue: 0.24)       // #FFD93D

        // Day/Vitality: Bright teal to sky blue
        static let dayStart = Color(red: 0.31, green: 0.80, blue: 0.77)     // #4ECDC4
        static let dayEnd = Color(red: 0.27, green: 0.72, blue: 0.82)       // #45B7D1

        // Dusk/Transition: Purple to deep violet
        static let duskStart = Color(red: 0.61, green: 0.35, blue: 0.71)    // #9B59B6
        static let duskEnd = Color(red: 0.42, green: 0.36, blue: 0.90)      // #6C5CE7

        // Night/Rest: Deep indigo to soft navy
        static let nightStart = Color(red: 0.17, green: 0.24, blue: 0.31)   // #2C3E50
        static let nightEnd = Color(red: 0.20, green: 0.29, blue: 0.37)     // #34495E
    }

    // MARK: - Published Properties (synced from iPhone)

    @Published var appearanceMode: AppearanceMode = .system {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "watchAppearanceMode")
        }
    }

    @Published var accentColorOption: AccentColorOption = .teal {
        didSet {
            UserDefaults.standard.set(accentColorOption.rawValue, forKey: "watchAccentColor")
        }
    }

    @Published var largeIconsMode: Bool = false {
        didSet {
            UserDefaults.standard.set(largeIconsMode, forKey: "watchLargeIconsMode")
        }
    }

    @Published var highContrast: Bool = false {
        didSet {
            UserDefaults.standard.set(highContrast, forKey: "watchHighContrast")
        }
    }

    @Published var reduceMotion: Bool = false {
        didSet {
            UserDefaults.standard.set(reduceMotion, forKey: "watchReduceMotion")
        }
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    private func loadSettings() {
        if let modeString = UserDefaults.standard.string(forKey: "watchAppearanceMode"),
           let mode = AppearanceMode(rawValue: modeString) {
            appearanceMode = mode
        }

        if let colorString = UserDefaults.standard.string(forKey: "watchAccentColor"),
           let color = AccentColorOption(rawValue: colorString) {
            accentColorOption = color
        }

        largeIconsMode = UserDefaults.standard.bool(forKey: "watchLargeIconsMode")
        highContrast = UserDefaults.standard.bool(forKey: "watchHighContrast")
        reduceMotion = UserDefaults.standard.bool(forKey: "watchReduceMotion")
    }

    // MARK: - Update from iPhone

    func updateFromiPhone(accentColor: String?, appearanceMode: String?, largeIcons: Bool?, highContrast: Bool?, reduceMotion: Bool?) {
        if let colorString = accentColor, let color = AccentColorOption(rawValue: colorString) {
            self.accentColorOption = color
        }

        if let modeString = appearanceMode, let mode = AppearanceMode(rawValue: modeString) {
            self.appearanceMode = mode
        }

        if let largeIcons = largeIcons {
            self.largeIconsMode = largeIcons
        }

        if let highContrast = highContrast {
            self.highContrast = highContrast
        }

        if let reduceMotion = reduceMotion {
            self.reduceMotion = reduceMotion
        }
    }

    // MARK: - Computed Properties

    var accentColor: Color {
        accentColorOption.color
    }

    var currentColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        case .circadian:
            return circadianScheme()
        }
    }

    // MARK: - Circadian Logic

    private func circadianScheme() -> ColorScheme {
        let hour = Calendar.current.component(.hour, from: Date())
        // Light mode from 7 AM to 7 PM
        return (hour >= 7 && hour < 19) ? .light : .dark
    }

    func circadianGradient() -> LinearGradient {
        let hour = Calendar.current.component(.hour, from: Date())

        let colors: [Color]
        switch hour {
        case 5..<8:   // Dawn (5-8 AM)
            colors = [CircadianColors.dawnStart, CircadianColors.dawnEnd]
        case 8..<17:  // Day (8 AM - 5 PM)
            colors = [CircadianColors.dayStart, CircadianColors.dayEnd]
        case 17..<20: // Dusk (5-8 PM)
            colors = [CircadianColors.duskStart, CircadianColors.duskEnd]
        default:      // Night (8 PM - 5 AM)
            colors = [CircadianColors.nightStart, CircadianColors.nightEnd]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Time-Based Theme Colors

    var currentTheme: WatchColorTheme {
        WatchColorTheme.shared
    }

    // MARK: - Animation Settings

    var animationDuration: Double {
        reduceMotion ? 0 : 0.3
    }

    var springAnimation: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Accessibility Adjustments

    var buttonScale: CGFloat {
        largeIconsMode ? 1.2 : 1.0
    }

    var minimumTapTarget: CGFloat {
        largeIconsMode ? 50 : 44
    }

    func adjustedColor(_ color: Color) -> Color {
        if highContrast {
            return color.opacity(1.0)
        }
        return color
    }
}

// MARK: - Watch Color Theme

struct WatchColorTheme {
    static var shared: WatchColorTheme {
        WatchColorTheme(period: WatchTimePeriod.current)
    }

    let period: WatchTimePeriod

    init(period: WatchTimePeriod = .current) {
        self.period = period
    }

    // MARK: - Primary Colors (Time-Based)

    var primary: Color {
        switch period {
        case .morning:
            return Color(red: 0.05, green: 0.65, blue: 0.91)  // Sky blue
        case .afternoon:
            return Color(red: 0.96, green: 0.62, blue: 0.04)  // Amber
        case .evening:
            return Color(red: 0.92, green: 0.35, blue: 0.05)  // Orange
        case .night:
            return Color(red: 0.49, green: 0.23, blue: 0.93)  // Purple
        }
    }

    var secondary: Color {
        switch period {
        case .morning:
            return Color(red: 0.22, green: 0.74, blue: 0.97)  // Light sky blue
        case .afternoon:
            return Color(red: 0.98, green: 0.75, blue: 0.14)  // Golden amber
        case .evening:
            return Color(red: 0.98, green: 0.57, blue: 0.24)  // Warm orange
        case .night:
            return Color(red: 0.65, green: 0.55, blue: 0.98)  // Soft lavender
        }
    }

    // MARK: - Status Colors

    var success: Color { Color(red: 0.06, green: 0.73, blue: 0.51) }  // Emerald
    var warning: Color { Color(red: 0.96, green: 0.62, blue: 0.04) }  // Amber
    var error: Color { Color(red: 0.94, green: 0.27, blue: 0.27) }    // Red

    // MARK: - Progress Colors

    var completed: Color { success }
    var active: Color { primary }
    var inactive: Color { Color.gray.opacity(0.4) }

    // MARK: - Background Colors

    var backgroundTint: Color {
        primary.opacity(0.15)
    }

    // MARK: - Category Colors

    func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "sleep":
            return primary
        case "exercise":
            return success
        case "nutrition":
            return secondary
        case "stress":
            return Color(red: 0.55, green: 0.36, blue: 0.96)  // Purple
        case "environment":
            return Color(red: 0.08, green: 0.72, blue: 0.65)  // Teal
        case "medication":
            return error
        default:
            return primary
        }
    }
}

// MARK: - Watch Time Period

enum WatchTimePeriod {
    case morning    // 5 AM - 12 PM
    case afternoon  // 12 PM - 5 PM
    case evening    // 5 PM - 9 PM
    case night      // 9 PM - 5 AM

    static var current: WatchTimePeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }
}

// MARK: - View Extension for Watch Theming

extension View {
    func withWatchTheme() -> some View {
        self.environmentObject(WatchThemeManager.shared)
    }
}
