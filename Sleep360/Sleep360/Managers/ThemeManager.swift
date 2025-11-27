//
//  ThemeManager.swift
//  Zoe Sleep for Longevity System
//
//  Manages app-wide theming, accessibility settings, and debug options
//

import Foundation
import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Color Theme

    enum ColorTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        case circadian = "Circadian"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .circadian: return "clock.fill"
            }
        }
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

        // Sleep Log background (soft blue)
        static let sleepLogBackground = Color(red: 0.89, green: 0.95, blue: 0.99) // #E3F2FD

        // Assessment background (soft purple)
        static let assessmentBackground = Color(red: 0.95, green: 0.90, blue: 0.96) // #F3E5F5
    }

    // MARK: - Published Properties

    // Appearance
    @AppStorage("colorTheme") var colorTheme: ColorTheme = .system
    @AppStorage("accentColor") var accentColorOption: AccentColorOption = .teal

    // Accessibility
    @AppStorage("largeIconsMode") var largeIconsMode: Bool = false
    @AppStorage("highContrast") var highContrast: Bool = false
    @AppStorage("reduceMotion") var reduceMotion: Bool = false
    @AppStorage("textSizeMultiplier") var textSizeMultiplier: Double = 1.0

    // Debug
    @AppStorage("debugMode") var debugMode: Bool = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Computed Properties

    var accentColor: Color {
        accentColorOption.color
    }

    /// Returns the current ColorTheme based on time of day
    var currentTheme: ColorTheme {
        ColorTheme.shared
    }

    var buttonScale: CGFloat {
        largeIconsMode ? 1.3 : 1.0
    }

    var minimumTapTarget: CGFloat {
        largeIconsMode ? 58 : 44  // Apple HIG minimum is 44pt
    }

    var scaledFontSize: (CGFloat) -> CGFloat {
        { baseSize in
            baseSize * self.textSizeMultiplier
        }
    }

    var currentColorScheme: ColorScheme? {
        switch colorTheme {
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

    // MARK: - Animation Settings

    var animationDuration: Double {
        reduceMotion ? 0 : 0.3
    }

    var springAnimation: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - High Contrast Adjustments

    func adjustedColor(_ color: Color) -> Color {
        if highContrast {
            // Increase saturation and contrast
            return color.opacity(1.0)
        }
        return color
    }

    var borderWidth: CGFloat {
        highContrast ? 2 : 1
    }

    var shadowRadius: CGFloat {
        highContrast ? 0 : 4
    }
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - View Extension for Theming

extension View {
    func withTheme() -> some View {
        self.environmentObject(ThemeManager.shared)
    }

    func scaledButton(scale: CGFloat = 1.0) -> some View {
        let themeManager = ThemeManager.shared
        return self.scaleEffect(scale * themeManager.buttonScale)
    }

    func accessibleTapTarget() -> some View {
        let themeManager = ThemeManager.shared
        return self.frame(minWidth: themeManager.minimumTapTarget, minHeight: themeManager.minimumTapTarget)
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
