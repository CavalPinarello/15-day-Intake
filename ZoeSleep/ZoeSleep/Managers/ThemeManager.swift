//
//  ThemeManager.swift
//  Zoe Sleep for Longevity System
//
//  Manages app-wide theming, accessibility settings, and debug options
//

import Foundation
import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Appearance Mode

    enum AppearanceMode: String, CaseIterable, Identifiable {
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

    @Published var appearanceMode: AppearanceMode = .system {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "colorTheme")
        }
    }

    @Published var accentColorOption: AccentColorOption = .teal {
        didSet {
            UserDefaults.standard.set(accentColorOption.rawValue, forKey: "accentColor")
        }
    }

    @Published var largeIconsMode: Bool = false {
        didSet {
            UserDefaults.standard.set(largeIconsMode, forKey: "largeIconsMode")
        }
    }

    @Published var highContrast: Bool = false {
        didSet {
            UserDefaults.standard.set(highContrast, forKey: "highContrast")
        }
    }

    @Published var reduceMotion: Bool = false {
        didSet {
            UserDefaults.standard.set(reduceMotion, forKey: "reduceMotion")
        }
    }

    @Published var textSizeMultiplier: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(textSizeMultiplier, forKey: "textSizeMultiplier")
        }
    }

    @Published var debugMode: Bool = false {
        didSet {
            UserDefaults.standard.set(debugMode, forKey: "debugMode")
        }
    }

    // MARK: - Initialization

    private init() {
        loadFromUserDefaults()
    }

    private func loadFromUserDefaults() {
        // Load appearance mode
        if let modeString = UserDefaults.standard.string(forKey: "colorTheme"),
           let mode = AppearanceMode(rawValue: modeString) {
            self.appearanceMode = mode
        }

        // Load accent color
        if let colorString = UserDefaults.standard.string(forKey: "accentColor"),
           let color = AccentColorOption(rawValue: colorString) {
            self.accentColorOption = color
        }

        // Load accessibility settings
        self.largeIconsMode = UserDefaults.standard.bool(forKey: "largeIconsMode")
        self.highContrast = UserDefaults.standard.bool(forKey: "highContrast")
        self.reduceMotion = UserDefaults.standard.bool(forKey: "reduceMotion")

        let savedTextSize = UserDefaults.standard.double(forKey: "textSizeMultiplier")
        self.textSizeMultiplier = savedTextSize > 0 ? savedTextSize : 1.0

        // Load debug mode
        self.debugMode = UserDefaults.standard.bool(forKey: "debugMode")
    }

    // MARK: - Computed Properties

    var accentColor: Color {
        accentColorOption.color
    }

    /// Returns the current ColorTheme based on appearance mode
    var currentTheme: ColorTheme {
        if appearanceMode == .circadian {
            return ColorTheme.shared
        } else {
            return ColorTheme(accentColor: accentColorOption)
        }
    }

    var buttonScale: CGFloat {
        largeIconsMode ? 1.3 : 1.0
    }

    var minimumTapTarget: CGFloat {
        largeIconsMode ? 58 : 44
    }

    var scaledFontSize: (CGFloat) -> CGFloat {
        { baseSize in
            baseSize * self.textSizeMultiplier
        }
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
        return (hour >= 7 && hour < 19) ? .light : .dark
    }

    func circadianGradient() -> LinearGradient {
        let hour = Calendar.current.component(.hour, from: Date())

        let colors: [Color]
        switch hour {
        case 5..<8:
            colors = [CircadianColors.dawnStart, CircadianColors.dawnEnd]
        case 8..<17:
            colors = [CircadianColors.dayStart, CircadianColors.dayEnd]
        case 17..<20:
            colors = [CircadianColors.duskStart, CircadianColors.duskEnd]
        default:
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
