//
//  ThemeManager.swift
//  Zoé Sleep for Longevity System
//
//  Manages app-wide theming, accessibility settings, and debug options
//  Design philosophy: Calm, friendly, Headspace-inspired aesthetic
//

import Foundation
import SwiftUI
import Combine

// MARK: - Design System Constants

/// Headspace-inspired spacing scale
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 20
    static let lg: CGFloat = 28
    static let xl: CGFloat = 40
    static let xxl: CGFloat = 56
    static let xxxl: CGFloat = 72
}

/// Softer corner radius scale
enum CornerRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 20
    static let large: CGFloat = 28
    static let extraLarge: CGFloat = 36
    static let pill: CGFloat = 999
}

/// Typography scale (larger, friendlier)
enum Typography {
    static let caption2: CGFloat = 12
    static let caption: CGFloat = 14
    static let footnote: CGFloat = 15
    static let subheadline: CGFloat = 16
    static let body: CGFloat = 18
    static let callout: CGFloat = 17
    static let headline: CGFloat = 20
    static let title3: CGFloat = 24
    static let title2: CGFloat = 28
    static let title: CGFloat = 34
    static let largeTitle: CGFloat = 40
}

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

    /// Override the 4 AM unlock time restriction (debug feature)
    @Published var unlockTimeOverride: Bool = false {
        didSet {
            UserDefaults.standard.set(unlockTimeOverride, forKey: "unlockTimeOverride")
        }
    }

    // Circadian time period - triggers UI refresh when time period changes
    @Published private(set) var currentTimePeriod: TimePeriod = TimePeriod.current
    private var circadianTimer: Timer?

    // MARK: - Initialization

    private init() {
        loadFromUserDefaults()
        startCircadianTimer()
    }

    /// Starts a timer that checks for time period changes every 30 seconds
    private func startCircadianTimer() {
        circadianTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkTimePeriodChange()
        }
        // Also listen for significant time changes (timezone, manual time change)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSignificantTimeChange),
            name: UIApplication.significantTimeChangeNotification,
            object: nil
        )
    }

    private func checkTimePeriodChange() {
        let newPeriod = TimePeriod.current
        if newPeriod != currentTimePeriod {
            DispatchQueue.main.async {
                self.currentTimePeriod = newPeriod
            }
        }
    }

    @objc private func handleSignificantTimeChange() {
        checkTimePeriodChange()
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

        // Load unlock time override
        self.unlockTimeOverride = UserDefaults.standard.bool(forKey: "unlockTimeOverride")
    }

    // MARK: - Computed Properties

    var accentColor: Color {
        accentColorOption.color
    }

    /// Returns the current ColorTheme based on appearance mode
    /// When in circadian mode, uses currentTimePeriod to ensure UI updates when time changes
    var currentTheme: ColorTheme {
        if appearanceMode == .circadian {
            // Use currentTimePeriod to ensure dependency tracking for SwiftUI refresh
            return ColorTheme(period: currentTimePeriod)
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

    /// Apply accessibility-aware text scaling
    func accessibleFont(_ style: Font.TextStyle, size: CGFloat? = nil) -> some View {
        let themeManager = ThemeManager.shared
        let baseSize = size ?? Font.TextStyle.defaultSize(for: style)
        return self.font(.system(size: themeManager.scaledFontSize(baseSize)))
    }

    /// Apply accessibility-aware animation
    func accessibleAnimation<V: Equatable>(_ animation: Animation = .default, value: V) -> some View {
        let themeManager = ThemeManager.shared
        if themeManager.reduceMotion {
            return AnyView(self.animation(.linear(duration: 0), value: value))
        } else {
            return AnyView(self.animation(animation, value: value))
        }
    }

    /// Apply high contrast border if enabled
    func accessibleBorder(_ color: Color, cornerRadius: CGFloat = 8) -> some View {
        let themeManager = ThemeManager.shared
        return self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: themeManager.borderWidth)
        )
    }

    /// Apply shadow with accessibility consideration
    func accessibleShadow(color: Color = .black.opacity(0.1), radius: CGFloat = 4, x: CGFloat = 0, y: CGFloat = 2) -> some View {
        let themeManager = ThemeManager.shared
        return self.shadow(color: color, radius: themeManager.shadowRadius, x: x, y: y)
    }
}

// MARK: - Font.TextStyle Extension

extension Font.TextStyle {
    /// Returns default point size for a text style (Headspace-inspired larger sizes)
    static func defaultSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return Typography.largeTitle
        case .title: return Typography.title
        case .title2: return Typography.title2
        case .title3: return Typography.title3
        case .headline: return Typography.headline
        case .body: return Typography.body
        case .callout: return Typography.callout
        case .subheadline: return Typography.subheadline
        case .footnote: return Typography.footnote
        case .caption: return Typography.caption
        case .caption2: return Typography.caption2
        @unknown default: return Typography.body
        }
    }
}

// MARK: - Friendly Copy Helpers

/// Warm, encouraging copy variants for common UI elements
enum FriendlyCopy {
    // Button labels
    static let continueButton = "Let's go"
    static let nextButton = "Next"
    static let doneButton = "Done!"
    static let saveButton = "Save"
    static let skipButton = "Skip for now"
    static let backButton = "Go back"

    // Section headers
    static let sleepLogHeader = "Your sleep last night"
    static let assessmentHeader = "A few questions"
    static let demographicsHeader = "A bit about you"

    // Encouragement
    static let greatJob = "Nice work!"
    static let almostThere = "Almost there..."
    static let keepGoing = "You're doing great"
    static let allDone = "All done for today!"

    // Greetings by time of day
    static func greeting(for hour: Int, name: String? = nil) -> String {
        let nameStr = name.map { ", \($0)" } ?? ""
        switch hour {
        case 5..<12:
            return "Good morning\(nameStr)"
        case 12..<17:
            return "Good afternoon\(nameStr)"
        case 17..<21:
            return "Good evening\(nameStr)"
        default:
            return "Hello\(nameStr)"
        }
    }

    // Motivational messages
    static let dayMessages = [
        "Every day is a step toward better sleep",
        "Small changes lead to big improvements",
        "You're building healthier sleep habits",
        "Great progress on your journey",
        "Consistency is key to better rest"
    ]

    static func randomDayMessage() -> String {
        dayMessages.randomElement() ?? dayMessages[0]
    }
}

// MARK: - Calm UI Components

/// A softer, more rounded button style
struct CalmButtonStyle: ButtonStyle {
    let isPrimary: Bool
    let theme: ColorTheme

    init(isPrimary: Bool = true, theme: ColorTheme = .shared) {
        self.isPrimary = isPrimary
        self.theme = theme
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Typography.headline, weight: .semibold, design: .rounded))
            .foregroundColor(isPrimary ? .white : theme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isPrimary ? theme.primary : theme.primary.opacity(0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A calm card container with soft shadows
struct CalmCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.lg

    init(padding: CGFloat = Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
    }
}

/// Progress dots for multi-step flows - CIRCADIAN-AWARE
struct ProgressDots: View {
    let current: Int
    let total: Int

    // Observe ThemeManager for reactive circadian updates
    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

    private var isEveningOrNight: Bool {
        let period = themeManager.currentTimePeriod
        return period == .evening || period == .night
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: index == current - 1 ? 10 : 8, height: index == current - 1 ? 10 : 8)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index < current {
            return theme.primary  // Completed - full circadian-aware color
        } else {
            // Inactive - more visible in dark mode
            return theme.primary.opacity(isEveningOrNight ? 0.4 : 0.25)
        }
    }
}

/// Interactive progress dots - tap completed days to navigate to Sleep Diary
struct InteractiveProgressDots: View {
    let current: Int
    let total: Int
    let completedDays: [Int]
    let onDayTapped: (Int) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: ColorTheme { themeManager.currentTheme }

    private var isEveningOrNight: Bool {
        let period = themeManager.currentTimePeriod
        return period == .evening || period == .night
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<total, id: \.self) { index in
                let day = index + 1
                let isCompleted = completedDays.contains(day)
                let isCurrent = day == current

                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: isCurrent ? 10 : 8, height: isCurrent ? 10 : 8)
                    .overlay(
                        // Subtle indicator for tappable dots
                        Circle()
                            .stroke(isCompleted ? theme.primary.opacity(0.5) : Color.clear, lineWidth: 1)
                            .frame(width: isCurrent ? 14 : 12, height: isCurrent ? 14 : 12)
                    )
                    .animation(.spring(response: 0.3), value: current)
                    .onTapGesture {
                        if isCompleted {
                            onDayTapped(day)
                        }
                    }
                    .contentShape(Rectangle().size(width: 20, height: 20))  // Larger tap target
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index < current {
            return theme.primary  // Completed - full circadian-aware color
        } else {
            // Inactive - more visible in dark mode
            return theme.primary.opacity(isEveningOrNight ? 0.4 : 0.25)
        }
    }
}
