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

    // MARK: - Sleep-Optimized Circadian Color Palette
    // CRITICAL: NO blue/teal/green after dusk - only warm colors for sleep health

    struct CircadianColors {
        // ========================================
        // EVENING/NIGHT: WARM COLORS ONLY (no blue light!)
        // ========================================
        static let nightBackground1 = Color(red: 0.14, green: 0.08, blue: 0.06)  // Deep warm brown
        static let nightBackground2 = Color(red: 0.16, green: 0.09, blue: 0.07)
        static let nightBackground3 = Color(red: 0.18, green: 0.10, blue: 0.08)
        static let nightWave = Color(red: 0.85, green: 0.45, blue: 0.20)         // Warm amber
        static let nightAccent = Color(red: 0.95, green: 0.55, blue: 0.25)       // Bright amber/orange
        static let nightTextPrimary = Color(red: 1.0, green: 0.92, blue: 0.85)   // Warm white
        static let nightTextSecondary = Color(red: 0.85, green: 0.70, blue: 0.55) // Warm tan

        // ========================================
        // DAWN: Warm coral/peach transition
        // ========================================
        static let dawnBackground1 = Color(red: 0.99, green: 0.94, blue: 0.90)
        static let dawnBackground2 = Color(red: 0.98, green: 0.91, blue: 0.86)
        static let dawnWave = Color(red: 1.0, green: 0.60, blue: 0.40)           // Coral
        static let dawnAccent = Color(red: 1.0, green: 0.75, blue: 0.45)         // Golden peach

        // ========================================
        // MORNING: Energizing (blues/teals OK)
        // ========================================
        static let morningBackground1 = Color(red: 0.92, green: 0.97, blue: 0.98)
        static let morningBackground2 = Color(red: 0.88, green: 0.95, blue: 0.97)
        static let morningWave = Color(red: 0.31, green: 0.80, blue: 0.77)       // Teal
        static let morningAccent = Color(red: 0.27, green: 0.72, blue: 0.82)     // Cyan

        // ========================================
        // AFTERNOON: Soft blue (OK for alertness)
        // ========================================
        static let afternoonBackground1 = Color(red: 0.94, green: 0.96, blue: 0.99)
        static let afternoonBackground2 = Color(red: 0.90, green: 0.94, blue: 0.98)
        static let afternoonWave = Color(red: 0.35, green: 0.70, blue: 0.85)
        static let afternoonAccent = Color(red: 0.45, green: 0.75, blue: 0.90)
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

    @Published var debugMode: Bool = false {
        didSet {
            UserDefaults.standard.set(debugMode, forKey: "watchDebugMode")
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
        debugMode = UserDefaults.standard.bool(forKey: "watchDebugMode")
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

    /// Get circadian-aware background gradient - NO blue after dusk for sleep health
    func circadianGradient() -> LinearGradient {
        let palette = WatchCircadianPalette.current

        return LinearGradient(
            colors: palette.background,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Get the current circadian palette for dynamic theming
    var circadianPalette: WatchCircadianPalette {
        WatchCircadianPalette.current
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

// MARK: - Watch Circadian Palette (Sleep-optimized)

/// Centralized circadian color palette for Apple Watch - matches iOS
/// EVENING/NIGHT: Only warm colors (amber, orange, red, brown) - NO blue/teal/green
/// MORNING/DAY: Can use energizing blues, teals, greens
struct WatchCircadianPalette {
    let background: [Color]
    let wave: Color
    let accent: Color
    let isDark: Bool
    let textPrimary: Color
    let textSecondary: Color

    /// Get the current circadian palette based on time of day and season
    static var current: WatchCircadianPalette {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 180

        // Seasonal sunrise/sunset calculation (same as iOS)
        let seasonalOffset = sin(Double(dayOfYear - 80) / 365.0 * .pi * 2)
        let sunriseHour = 6.5 - seasonalOffset * 1.0
        let sunsetHour = 18.5 + seasonalOffset * 2.0

        let currentHour = Double(hour) + Double(minute) / 60.0

        // Time periods
        let dawnStart = sunriseHour - 0.5
        let dawnEnd = sunriseHour + 1.5
        let duskStart = sunsetHour - 1.5

        // ========================================
        // EVENING/NIGHT MODE (after dusk start)
        // NO BLUE, NO TEAL, NO GREEN - only warm colors
        // ========================================
        if currentHour >= duskStart || currentHour < dawnStart {
            return WatchCircadianPalette(
                background: [
                    WatchThemeManager.CircadianColors.nightBackground1,
                    WatchThemeManager.CircadianColors.nightBackground2,
                    WatchThemeManager.CircadianColors.nightBackground3
                ],
                wave: WatchThemeManager.CircadianColors.nightWave,
                accent: WatchThemeManager.CircadianColors.nightAccent,
                isDark: true,
                textPrimary: WatchThemeManager.CircadianColors.nightTextPrimary,
                textSecondary: WatchThemeManager.CircadianColors.nightTextSecondary
            )
        }
        // ========================================
        // DAWN - Warm coral/peach transition
        // ========================================
        else if currentHour >= dawnStart && currentHour < dawnEnd {
            return WatchCircadianPalette(
                background: [
                    WatchThemeManager.CircadianColors.dawnBackground1,
                    WatchThemeManager.CircadianColors.dawnBackground2
                ],
                wave: WatchThemeManager.CircadianColors.dawnWave,
                accent: WatchThemeManager.CircadianColors.dawnAccent,
                isDark: false,
                textPrimary: Color(red: 0.25, green: 0.15, blue: 0.10),
                textSecondary: Color(red: 0.50, green: 0.35, blue: 0.25)
            )
        }
        // ========================================
        // MORNING - Energizing (blues/teals OK)
        // ========================================
        else if currentHour >= dawnEnd && currentHour < 12 {
            return WatchCircadianPalette(
                background: [
                    WatchThemeManager.CircadianColors.morningBackground1,
                    WatchThemeManager.CircadianColors.morningBackground2
                ],
                wave: WatchThemeManager.CircadianColors.morningWave,
                accent: WatchThemeManager.CircadianColors.morningAccent,
                isDark: false,
                textPrimary: Color(red: 0.10, green: 0.15, blue: 0.20),
                textSecondary: Color(red: 0.35, green: 0.45, blue: 0.50)
            )
        }
        // ========================================
        // AFTERNOON - Soft blue (OK for alertness)
        // ========================================
        else {
            return WatchCircadianPalette(
                background: [
                    WatchThemeManager.CircadianColors.afternoonBackground1,
                    WatchThemeManager.CircadianColors.afternoonBackground2
                ],
                wave: WatchThemeManager.CircadianColors.afternoonWave,
                accent: WatchThemeManager.CircadianColors.afternoonAccent,
                isDark: false,
                textPrimary: Color(red: 0.10, green: 0.15, blue: 0.20),
                textSecondary: Color(red: 0.40, green: 0.45, blue: 0.50)
            )
        }
    }
}

// MARK: - View Extension for Watch Theming

extension View {
    func withWatchTheme() -> some View {
        self.environmentObject(WatchThemeManager.shared)
    }
}
