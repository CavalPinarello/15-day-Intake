//
//  QuestionModels.swift
//  Zoe Sleep for Longevity System
//
//  Data models for the 15-day adaptive questionnaire system
//  CIRCADIAN DESIGN: Colors transition smoothly throughout the day
//

import Foundation
import SwiftUI

// MARK: - Circadian Phase System (8 phases with smooth interpolation)

/// The 8 phases of the circadian day, designed for continuous color transitions
/// CRITICAL: No blue light after dusk (disrupts melatonin production)
enum CircadianPhase: Int, CaseIterable, Equatable {
    case preDown = 0    // 4:00-5:30 AM: Deep warm transitioning from night
    case dawn = 1       // 5:30-7:30 AM: Golden sunrise, awakening
    case morning = 2    // 7:30-11:00 AM: Bright energetic (blue OK)
    case midday = 3     // 11:00-14:00: Peak brightness
    case afternoon = 4  // 14:00-17:00: Warming golden
    case dusk = 5       // 17:00-19:00: Orange sunset (NO blue starts here!)
    case evening = 6    // 19:00-22:00: Deep amber warmth
    case night = 7      // 22:00-4:00 AM: Full night mode, darkest warm

    /// Whether this phase allows blue light (safe for melatonin)
    var allowsBlueLight: Bool {
        switch self {
        case .preDown, .dawn, .morning, .midday, .afternoon:
            return true
        case .dusk, .evening, .night:
            return false  // NO BLUE LIGHT after dusk!
        }
    }

    /// Human-readable name
    var displayName: String {
        switch self {
        case .preDown: return "Pre-Dawn"
        case .dawn: return "Dawn"
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .afternoon: return "Afternoon"
        case .dusk: return "Dusk"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
}

// MARK: - Circadian Palette (Smooth Color Interpolation System)

/// Centralized circadian color system with minute-level precision
/// All colors smoothly interpolate between phases for gradual transitions
struct CircadianPalette {

    // MARK: - Current State

    /// Progress through the current day (0.0 = midnight, 1.0 = next midnight)
    let dayProgress: Double

    /// Current circadian phase
    let phase: CircadianPhase

    /// Progress within the current phase (0.0 = phase start, 1.0 = phase end)
    let phaseProgress: Double

    // MARK: - Initialization

    /// Create palette for the current moment
    static var current: CircadianPalette {
        CircadianPalette(date: Date())
    }

    /// Create palette for a specific date/time
    init(date: Date = Date()) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 180

        let currentTime = Double(hour) + Double(minute) / 60.0
        self.dayProgress = currentTime / 24.0

        // Seasonal adjustment for sunrise/sunset
        let seasonalOffset = sin(Double(dayOfYear - 80) / 365.0 * .pi * 2)
        let sunriseBase = 6.5 - seasonalOffset * 1.0   // 5:30-7:30 AM
        let sunsetBase = 18.5 + seasonalOffset * 2.0   // 16:30-20:30 PM

        // Phase boundaries (hours) - seasonally adjusted
        let phaseHours: [(CircadianPhase, Double, Double)] = [
            (.night, 0.0, 4.0),
            (.preDown, 4.0, sunriseBase - 1.0),
            (.dawn, sunriseBase - 1.0, sunriseBase + 1.5),
            (.morning, sunriseBase + 1.5, 11.0),
            (.midday, 11.0, 14.0),
            (.afternoon, 14.0, sunsetBase - 1.5),
            (.dusk, sunsetBase - 1.5, sunsetBase + 1.0),
            (.evening, sunsetBase + 1.0, 22.0),
            (.night, 22.0, 24.0)
        ]

        // Find current phase and calculate progress within it
        var foundPhase: CircadianPhase = .night
        var foundProgress: Double = 0.0

        for (phase, start, end) in phaseHours {
            if currentTime >= start && currentTime < end {
                foundPhase = phase
                foundProgress = (currentTime - start) / (end - start)
                break
            }
        }

        self.phase = foundPhase
        self.phaseProgress = foundProgress
    }

    // MARK: - Color Interpolation

    /// Interpolate between two colors based on progress (0.0-1.0)
    static func interpolate(_ from: Color, to: Color, progress: Double) -> Color {
        let p = min(1.0, max(0.0, progress))

        // Extract RGB components using UIColor
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        UIColor(from).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(to).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        // Use smooth ease-in-out interpolation for more natural transitions
        let smoothProgress = smoothStep(p)

        return Color(
            red: r1 + (r2 - r1) * smoothProgress,
            green: g1 + (g2 - g1) * smoothProgress,
            blue: b1 + (b2 - b1) * smoothProgress,
            opacity: a1 + (a2 - a1) * smoothProgress
        )
    }

    /// Smooth step function for natural color transitions
    private static func smoothStep(_ t: Double) -> Double {
        // Hermite interpolation: 3t² - 2t³
        return t * t * (3.0 - 2.0 * t)
    }

    // MARK: - Phase-Specific Colors

    /// Get color for a specific phase (static values before interpolation)
    static func phaseColor(for phase: CircadianPhase, type: ColorType) -> Color {
        switch type {
        case .primary:
            switch phase {
            case .preDown: return Color(hex: "#D97706")!   // Deep amber
            case .dawn: return Color(hex: "#F59E0B")!      // Golden amber
            case .morning: return Color(hex: "#0EA5E9")!   // Sky blue
            case .midday: return Color(hex: "#06B6D4")!    // Cyan
            case .afternoon: return Color(hex: "#F59E0B")! // Amber
            case .dusk: return Color(hex: "#EA580C")!      // Orange (NO blue!)
            case .evening: return Color(hex: "#F28C40")!   // Warm amber
            case .night: return Color(hex: "#F28C40")!     // Warm amber
            }

        case .secondary:
            switch phase {
            case .preDown: return Color(hex: "#B45309")!
            case .dawn: return Color(hex: "#FBBF24")!
            case .morning: return Color(hex: "#38BDF8")!
            case .midday: return Color(hex: "#22D3EE")!
            case .afternoon: return Color(hex: "#FBBF24")!
            case .dusk: return Color(hex: "#D97706")!
            case .evening: return Color(hex: "#D97706")!
            case .night: return Color(hex: "#D97706")!
            }

        case .background:
            switch phase {
            case .preDown: return Color(hex: "#1A0F0A")!    // Very dark warm
            case .dawn: return Color(hex: "#FEF3C7")!       // Warm cream
            case .morning: return Color(hex: "#F0F9FF")!    // Light sky
            case .midday: return Color(hex: "#ECFEFF")!     // Bright cyan tint
            case .afternoon: return Color(hex: "#FFFBEB")!  // Warm cream
            case .dusk: return Color(hex: "#451A03")!       // Dark orange-brown
            case .evening: return Color(hex: "#2D1810")!    // Dark warm brown
            case .night: return Color(hex: "#1A0F0A")!      // Very dark warm
            }

        case .backgroundEnd:
            switch phase {
            case .preDown: return Color(hex: "#0F0805")!
            case .dawn: return Color(hex: "#FDE68A")!
            case .morning: return Color(hex: "#E0F2FE")!
            case .midday: return Color(hex: "#CFFAFE")!
            case .afternoon: return Color(hex: "#FEF3C7")!
            case .dusk: return Color(hex: "#2D1810")!
            case .evening: return Color(hex: "#1A0F0A")!
            case .night: return Color(hex: "#0F0805")!
            }

        case .cardBackground:
            switch phase {
            case .preDown: return Color(red: 0.18, green: 0.11, blue: 0.08)
            case .dawn: return Color(red: 1.0, green: 0.99, blue: 0.95)
            case .morning: return Color.white.opacity(0.92)
            case .midday: return Color.white.opacity(0.95)
            case .afternoon: return Color(red: 1.0, green: 0.99, blue: 0.95)
            case .dusk: return Color(red: 0.25, green: 0.16, blue: 0.12)
            case .evening: return Color(red: 0.22, green: 0.14, blue: 0.10)
            case .night: return Color(red: 0.18, green: 0.11, blue: 0.08)
            }

        case .textPrimary:
            switch phase {
            case .preDown, .dusk, .evening, .night:
                // Bright warm cream for dark backgrounds - HIGH CONTRAST
                return Color(red: 0.996, green: 0.953, blue: 0.780)
            case .dawn, .morning, .midday, .afternoon:
                // Dark for light backgrounds
                return Color(red: 0.12, green: 0.08, blue: 0.06)
            }

        case .textSecondary:
            switch phase {
            case .preDown, .dusk, .evening, .night:
                // Golden amber for dark backgrounds
                return Color(red: 0.988, green: 0.827, blue: 0.302)
            case .dawn, .morning, .midday, .afternoon:
                // Medium brown for light backgrounds
                return Color(red: 0.35, green: 0.28, blue: 0.22)
            }

        case .accent:
            switch phase {
            case .preDown: return Color(hex: "#F59E0B")!
            case .dawn: return Color(hex: "#EA580C")!
            case .morning: return Color(hex: "#0EA5E9")!
            case .midday: return Color(hex: "#06B6D4")!
            case .afternoon: return Color(hex: "#F59E0B")!
            case .dusk: return Color(hex: "#F97316")!      // Orange
            case .evening: return Color(hex: "#F28C40")!   // Coral amber
            case .night: return Color(hex: "#F28C40")!     // Coral amber
            }
        }
    }

    enum ColorType {
        case primary
        case secondary
        case background
        case backgroundEnd
        case cardBackground
        case textPrimary
        case textSecondary
        case accent
    }

    // MARK: - Interpolated Colors (The Magic!)

    /// Get smoothly interpolated color for current time
    func interpolatedColor(_ type: ColorType) -> Color {
        let currentColor = CircadianPalette.phaseColor(for: phase, type: type)
        let nextPhase = CircadianPhase(rawValue: (phase.rawValue + 1) % 8) ?? .night
        let nextColor = CircadianPalette.phaseColor(for: nextPhase, type: type)

        return CircadianPalette.interpolate(currentColor, to: nextColor, progress: phaseProgress)
    }

    /// Primary accent color (interpolated)
    var primary: Color { interpolatedColor(.primary) }

    /// Secondary accent color (interpolated)
    var secondary: Color { interpolatedColor(.secondary) }

    /// Background start color (interpolated)
    var backgroundStart: Color { interpolatedColor(.background) }

    /// Background end color (interpolated)
    var backgroundEnd: Color { interpolatedColor(.backgroundEnd) }

    /// Card background color (interpolated)
    var cardBackground: Color { interpolatedColor(.cardBackground) }

    /// Primary text color (interpolated)
    var textPrimary: Color { interpolatedColor(.textPrimary) }

    /// Secondary text color (interpolated)
    var textSecondary: Color { interpolatedColor(.textSecondary) }

    /// Accent color (interpolated)
    var accent: Color { interpolatedColor(.accent) }

    /// Whether we're in a dark phase (dusk, evening, night, pre-dawn)
    /// Use this to adjust toolbar color schemes and other UI elements
    var isDark: Bool {
        !phase.allowsBlueLight
    }

    /// Background gradient using interpolated colors
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundStart, backgroundEnd],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Legacy Time Period Enum (Maps to CircadianPhase)

enum TimePeriod: Equatable {
    case morning    // Maps to: dawn, morning, midday
    case afternoon  // Maps to: afternoon
    case evening    // Maps to: dusk, evening
    case night      // Maps to: night, preDown

    /// Returns current time period using CircadianPhase
    static var current: TimePeriod {
        switch CircadianPalette.current.phase {
        case .preDown, .night:
            return .night
        case .dawn, .morning, .midday:
            return .morning
        case .afternoon:
            return .afternoon
        case .dusk, .evening:
            return .evening
        }
    }

    /// Get the underlying CircadianPhase for more granular control
    var circadianPhase: CircadianPhase {
        switch self {
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .evening: return .evening
        case .night: return .night
        }
    }
}

// MARK: - Color Theme (Uses CircadianPalette for Smooth Interpolation)

struct ColorTheme {

    // MARK: - Singleton with Time Awareness (for circadian mode)

    static var shared: ColorTheme {
        ColorTheme(period: TimePeriod.current)
    }

    let period: TimePeriod?
    let accentColorOption: ThemeManager.AccentColorOption?

    /// The underlying circadian palette for smooth color interpolation
    private var palette: CircadianPalette {
        CircadianPalette.current
    }

    /// Whether circadian mode is active (no custom accent selected)
    var isCircadianMode: Bool {
        accentColorOption == nil
    }

    /// Initialize with time-based circadian colors
    init(period: TimePeriod = .current) {
        self.period = period
        self.accentColorOption = nil
    }

    /// Initialize with user-selected accent color
    init(accentColor: ThemeManager.AccentColorOption) {
        self.period = nil
        self.accentColorOption = accentColor
    }

    // MARK: - Primary Colors (Sleep-Optimized, INTERPOLATED)
    // CRITICAL: NO blue/teal/purple at night - only warm amber/orange for sleep health
    // Colors now smoothly interpolate between phases!

    /// Main accent color - smoothly interpolated throughout the day
    var primary: Color {
        if let accent = accentColorOption {
            return accent.color
        }
        return palette.primary  // Smoothly interpolated!
    }

    /// Secondary accent for subtle elements - smoothly interpolated
    var secondary: Color {
        if let accent = accentColorOption {
            return accent.color.opacity(0.7)
        }
        return palette.secondary  // Smoothly interpolated!
    }

    /// Tertiary color for accents and highlights
    var tertiary: Color {
        if let accent = accentColorOption {
            return accent.color.opacity(0.5)
        }
        // Interpolate between primary and secondary
        return CircadianPalette.interpolate(palette.primary, to: palette.secondary, progress: 0.5)
    }

    // MARK: - Background Colors (Sleep-Optimized, INTERPOLATED)

    /// Subtle background tint - smoothly interpolated
    var backgroundTint: Color {
        if let accent = accentColorOption {
            return accent.color.opacity(0.08)
        }
        return palette.primary.opacity(0.08)
    }

    /// Card background with smoothly interpolated time-based warmth
    /// CIRCADIAN: Cards smoothly transition throughout the day
    var cardBackground: Color {
        if accentColorOption != nil {
            return Color(.secondarySystemBackground)
        }
        return palette.cardBackground  // Smoothly interpolated!
    }

    // MARK: - Status Colors (Consistent across time periods)

    var success: Color {
        Color(hex: "#10B981")!  // Emerald green
    }

    var warning: Color {
        Color(hex: "#F59E0B")!  // Amber
    }

    var error: Color {
        Color(hex: "#EF4444")!  // Red
    }

    var info: Color {
        primary
    }

    /// Alias for primary color (for code that uses theme.accent)
    var accent: Color {
        primary
    }

    // MARK: - Progress Colors

    /// Completed state
    var completed: Color {
        success
    }

    /// Current/Active state
    var active: Color {
        primary
    }

    /// Pending/Inactive state
    var inactive: Color {
        Color(hex: "#9CA3AF")!.opacity(0.4)  // Gray
    }

    // MARK: - Text Colors (Sleep-Optimized, INTERPOLATED for dark evening backgrounds)
    // CRITICAL: Must be HIGH CONTRAST on dark brown backgrounds in evening/night!
    // Colors now smoothly interpolate between phases!

    /// Get current period - uses stored period or falls back to current time
    private var effectivePeriod: TimePeriod {
        period ?? TimePeriod.current
    }

    /// Current circadian phase for more granular control
    var currentPhase: CircadianPhase {
        palette.phase
    }

    /// Whether we're in a dark phase (after dusk)
    var isDarkPhase: Bool {
        !palette.phase.allowsBlueLight
    }

    var textPrimary: Color {
        if accentColorOption != nil {
            // Non-circadian mode: use system colors
            return Color.primary
        }
        return palette.textPrimary  // Smoothly interpolated!
    }

    var textSecondary: Color {
        if accentColorOption != nil {
            return Color.secondary
        }
        return palette.textSecondary  // Smoothly interpolated!
    }

    /// Muted text for hints, timestamps, etc.
    var textMuted: Color {
        if accentColorOption != nil {
            return Color.secondary.opacity(0.7)
        }
        // Interpolate between secondary and a more muted version
        return palette.textSecondary.opacity(0.7)
    }

    var textOnPrimary: Color {
        // On amber/orange buttons in evening, use dark text for contrast
        if isDarkPhase && isCircadianMode {
            return Color(red: 0.15, green: 0.10, blue: 0.08)  // Dark brown on amber buttons
        }
        return .white
    }

    // MARK: - Card Text Colors (CIRCADIAN-AWARE, INTERPOLATED for high contrast)
    // Colors smoothly interpolate for gradual transitions!

    /// Primary text ON cards - circadian-aware for contrast
    var textOnCard: Color {
        if accentColorOption != nil {
            return Color(red: 0.15, green: 0.10, blue: 0.08)
        }
        return palette.textPrimary  // Same as textPrimary for cards
    }

    /// Secondary text ON cards - circadian-aware
    var textOnCardSecondary: Color {
        if accentColorOption != nil {
            return Color(red: 0.35, green: 0.25, blue: 0.20)
        }
        return palette.textSecondary  // Same as textSecondary for cards
    }

    /// Muted text ON cards - circadian-aware
    var textOnCardMuted: Color {
        if accentColorOption != nil {
            return Color(red: 0.50, green: 0.40, blue: 0.35)
        }
        return palette.textSecondary.opacity(0.7)
    }

    // MARK: - Component-Specific Colors

    /// Sleep diary icon (Sleep-Optimized)
    var sleepDiary: Color {
        if accentColorOption != nil {
            return primary
        }
        guard let period = period else { return Color(hex: "#8B5CF6")! }
        switch period {
        case .morning:
            return Color(hex: "#8B5CF6")!  // Purple (OK for morning)
        case .afternoon:
            return Color(hex: "#EA580C")!  // Orange
        case .evening:
            return Color(hex: "#D97706")!  // Deep amber - NO PURPLE
        case .night:
            return Color(hex: "#D97706")!  // Deep amber - NO PURPLE (sleep-safe)
        }
    }

    /// HealthKit / Heart
    var health: Color {
        if accentColorOption != nil {
            return Color(hex: "#EF4444")!  // Red (consistent)
        }
        guard let period = period else { return Color(hex: "#EF4444")! }
        switch period {
        case .morning:
            return Color(hex: "#EF4444")!  // Red
        case .afternoon:
            return Color(hex: "#DC2626")!  // Darker red
        case .evening:
            return Color(hex: "#B91C1C")!  // Deep red
        case .night:
            return Color(hex: "#F87171")!  // Soft red
        }
    }

    /// Insights / Charts (Sleep-Optimized)
    var insights: Color {
        if accentColorOption != nil {
            return Color(hex: "#10B981")!  // Emerald (consistent)
        }
        guard let period = period else { return Color(hex: "#10B981")! }
        switch period {
        case .morning:
            return Color(hex: "#10B981")!  // Emerald (OK for morning)
        case .afternoon:
            return Color(hex: "#059669")!  // Deep emerald
        case .evening:
            return Color(hex: "#F59E0B")!  // Amber - NO GREEN
        case .night:
            return Color(hex: "#F59E0B")!  // Amber - NO MINT/GREEN (sleep-safe)
        }
    }

    // MARK: - Chart Colors (Sleep-Optimized for Insights Dashboard)
    // CRITICAL: NO blue light after dusk - warm colors only for evening/night

    /// Objective data line color (HealthKit data) - adapts to time of day
    var chartLineObjective: Color {
        guard let period = period else { return Color(hex: "#3B82F6")! }
        switch period {
        case .morning, .afternoon:
            return Color(hex: "#3B82F6")!  // Blue (safe during day)
        case .evening, .night:
            return Color(hex: "#F28C40")!  // Amber (sleep-safe)
        }
    }

    /// Subjective data line color (User rating) - adapts to time of day
    var chartLineSubjective: Color {
        guard let period = period else { return Color(hex: "#8B5CF6")! }
        switch period {
        case .morning, .afternoon:
            return Color(hex: "#8B5CF6")!  // Purple (safe during day)
        case .evening, .night:
            return Color(hex: "#D97706")!  // Orange (sleep-safe)
        }
    }

    /// Positive insight color (warm-tinted at night)
    var insightPositive: Color {
        guard let period = period else { return Color(hex: "#10B981")! }
        switch period {
        case .morning, .afternoon:
            return Color(hex: "#10B981")!  // Emerald green
        case .evening, .night:
            return Color(hex: "#A3BE8C")!  // Muted sage (warm-tinted)
        }
    }

    // MARK: - Phase Colors

    /// Core assessment phase (Days 1-5)
    var corePhase: Color {
        if accentColorOption != nil {
            return Color(hex: "#F59E0B")!  // Amber (consistent)
        }
        guard let period = period else { return Color(hex: "#F59E0B")! }
        switch period {
        case .morning:
            return Color(hex: "#EAB308")!  // Yellow
        case .afternoon:
            return Color(hex: "#F59E0B")!  // Amber
        case .evening:
            return Color(hex: "#D97706")!  // Deep amber
        case .night:
            return Color(hex: "#FCD34D")!  // Soft yellow
        }
    }

    /// Expansion phase (Days 6-15)
    var expansionPhase: Color {
        success
    }

    // MARK: - Gradient Definitions

    /// Primary gradient for headers and accents (Sleep-Optimized)
    var primaryGradient: LinearGradient {
        if let accent = accentColorOption {
            return LinearGradient(
                colors: [accent.color, accent.color.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        guard let period = period else {
            return LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        switch period {
        case .morning:
            return LinearGradient(
                colors: [Color(hex: "#0EA5E9")!, Color(hex: "#38BDF8")!],  // Blue OK for morning
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .afternoon:
            return LinearGradient(
                colors: [Color(hex: "#F59E0B")!, Color(hex: "#FBBF24")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .evening:
            return LinearGradient(
                colors: [Color(hex: "#F28C40")!, Color(hex: "#D97706")!],  // Warm amber/orange
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .night:
            return LinearGradient(
                colors: [Color(hex: "#F28C40")!, Color(hex: "#D97706")!],  // Warm amber - NO PURPLE (sleep-safe)
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Sunset gradient for decorative elements
    var sunsetGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#FCD34D")!,  // Yellow
                Color(hex: "#F59E0B")!,  // Amber
                Color(hex: "#EA580C")!,  // Orange
                Color(hex: "#DC2626")!,  // Red
                Color(hex: "#7C3AED")!   // Purple
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Morning sky gradient
    var morningGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#38BDF8")!,  // Light blue
                Color(hex: "#0EA5E9")!,  // Sky blue
                Color(hex: "#0284C7")!   // Deeper blue
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Aliases for Compatibility

    /// Alias for textPrimary (used in some views)
    var primaryText: Color {
        textPrimary
    }

    /// Alias for textSecondary (used in some views)
    var secondaryText: Color {
        textSecondary
    }

    /// Background gradient for full-screen views - SMOOTHLY INTERPOLATED
    /// Colors transition gradually throughout the day for natural feel
    var backgroundGradient: LinearGradient {
        if accentColorOption != nil {
            // Non-circadian mode: use subtle system background
            return LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        // Use palette's interpolated gradient
        return palette.backgroundGradient
    }

    /// Direct access to current circadian palette for advanced use cases
    var circadianPalette: CircadianPalette {
        palette
    }
}

// Note: ThemeManager is defined in Managers/ThemeManager.swift

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

// MARK: - Question Types

enum QuestionType: String, Codable, CaseIterable {
    case text = "Text"
    case number = "Number"
    case time = "Time"
    case date = "Date"
    case email = "Email"
    case scale = "Scale"
    case yesNo = "Yes/No"
    case yesNoDontKnow = "Yes/No/Don't know"
    case singleSelect = "SingleSelect"
    case multiSelect = "MultiSelect"
    case minutesScroll = "MinutesScroll"
    case numberScroll = "NumberScroll"
    case repeatingGroup = "RepeatingGroup"
    case info = "Info"
}

enum Pillar: String, Codable, CaseIterable {
    case social = "Social"
    case metabolic = "Metabolic"
    case sleepQuality = "Sleep Quality"
    case sleepQuantity = "Sleep Quantity"
    case sleepRegularity = "Sleep Regularity"
    case sleepTiming = "Sleep Timing"
    case mentalHealth = "Mental Health"
    case cognitive = "Cognitive"
    case physical = "Physical"
    case nutritional = "Nutritional"
    case sleepDiary = "Sleep Diary"
    case sleepLog = "Sleep Log"

    var color: String {
        switch self {
        case .social: return "#6366F1"
        case .metabolic: return "#F59E0B"
        case .sleepQuality: return "#3B82F6"
        case .sleepQuantity: return "#8B5CF6"
        case .sleepRegularity: return "#10B981"
        case .sleepTiming: return "#EC4899"
        case .mentalHealth: return "#EF4444"
        case .cognitive: return "#F97316"
        case .physical: return "#14B8A6"
        case .nutritional: return "#84CC16"
        case .sleepDiary: return "#06B6D4"
        case .sleepLog: return "#6366F1"
        }
    }

    /// Time-aware pillar color
    var themeColor: Color {
        let theme = ColorTheme.shared
        switch self {
        case .social:
            return Color(hex: "#6366F1")!  // Indigo (consistent)
        case .metabolic:
            return theme.secondary  // Amber/Orange based on time
        case .sleepQuality:
            return theme.primary  // Primary theme color
        case .sleepQuantity:
            return Color(hex: "#8B5CF6")!  // Violet
        case .sleepRegularity:
            return theme.success  // Green
        case .sleepTiming:
            return Color(hex: "#EC4899")!  // Pink
        case .mentalHealth:
            return theme.health  // Red tones
        case .cognitive:
            return theme.tertiary  // Orange/Cyan based on time
        case .physical:
            return Color(hex: "#14B8A6")!  // Teal
        case .nutritional:
            return Color(hex: "#84CC16")!  // Lime
        case .sleepDiary:
            return theme.sleepDiary  // Purple/Orange based on time
        case .sleepLog:
            return theme.primary  // Primary theme color
        }
    }
}

enum QuestionTier: String, Codable {
    case core = "CORE"
    case gateway = "GATEWAY"
    case expansion = "EXPANSION"
}

// MARK: - Gateway Types

enum GatewayType: String, Codable, CaseIterable {
    case insomnia = "insomnia"
    case depression = "depression"
    case anxiety = "anxiety"
    case excessiveSleepiness = "excessive_sleepiness"
    case cognitive = "cognitive"
    case osa = "osa"
    case pain = "pain"
    case sleepTiming = "sleep_timing"
    case dietImpact = "diet_impact"
    case poorSleepQuality = "poor_sleep_quality"

    var displayName: String {
        switch self {
        case .insomnia: return "Insomnia"
        case .depression: return "Depression"
        case .anxiety: return "Anxiety"
        case .excessiveSleepiness: return "Excessive Daytime Sleepiness"
        case .cognitive: return "Cognitive Function"
        case .osa: return "Sleep Apnea Risk"
        case .pain: return "Pain Impact"
        case .sleepTiming: return "Sleep Timing"
        case .dietImpact: return "Diet Impact"
        case .poorSleepQuality: return "Poor Sleep Quality"
        }
    }

    /// Short name for compact UI display
    var shortName: String {
        switch self {
        case .insomnia: return "Insomnia"
        case .depression: return "Mood"
        case .anxiety: return "Anxiety"
        case .excessiveSleepiness: return "Sleepiness"
        case .cognitive: return "Cognitive"
        case .osa: return "Sleep Apnea"
        case .pain: return "Pain"
        case .sleepTiming: return "Chronotype"
        case .dietImpact: return "Nutrition"
        case .poorSleepQuality: return "Sleep Quality"
        }
    }

    /// Estimated minutes for this gateway's expansion module (based on assessment_modules.json)
    var estimatedMinutes: Double {
        switch self {
        case .insomnia: return 8.5  // ISI, DBAS, Sleep Hygiene, PSAS modules
        case .poorSleepQuality: return 8.5  // Sleep Quality expansion
        case .depression: return 8.0  // PHQ-9, part of mental health
        case .anxiety: return 8.0  // GAD-7, DASS-21
        case .excessiveSleepiness: return 7.0  // ESS, FSS, FOSQ
        case .cognitive: return 8.0  // PROMIS cognitive
        case .osa: return 8.0  // STOP-BANG, Berlin
        case .pain: return 8.0  // BPI
        case .sleepTiming: return 9.5  // MEQ chronotype
        case .dietImpact: return 7.0  // MEDAS
        }
    }

    var targetModules: [String] {
        switch self {
        case .insomnia, .poorSleepQuality:
            return ["expansion_sleep_quality"]
        case .depression, .anxiety:
            return ["expansion_mental_health"]
        case .excessiveSleepiness, .cognitive:
            return ["expansion_cognitive"]
        case .osa, .pain:
            return ["expansion_physical"]
        case .sleepTiming:
            return ["expansion_sleep_timing"]
        case .dietImpact:
            return ["expansion_nutritional"]
        }
    }

    /// SF Symbol icon for this gateway
    var icon: String {
        switch self {
        case .insomnia: return "moon.zzz"
        case .poorSleepQuality: return "bed.double"
        case .excessiveSleepiness: return "zzz"
        case .depression: return "cloud.rain"
        case .anxiety: return "exclamationmark.triangle"
        case .cognitive: return "brain.head.profile"
        case .osa: return "lungs"
        case .pain: return "bolt.heart"
        case .sleepTiming: return "clock"
        case .dietImpact: return "fork.knife"
        }
    }

    /// Color for debug UI
    var color: Color {
        switch self {
        case .insomnia: return .purple
        case .poorSleepQuality: return .indigo
        case .excessiveSleepiness: return .orange
        case .depression: return .blue
        case .anxiety: return .red
        case .cognitive: return .pink
        case .osa: return .cyan
        case .pain: return .yellow
        case .sleepTiming: return .green
        case .dietImpact: return .mint
        }
    }

    /// Trigger description for debug UI
    var triggerDescription: String {
        switch self {
        case .insomnia: return "Sleep difficulties >=3 nights/week"
        case .poorSleepQuality: return "PSQI global score >=5"
        case .excessiveSleepiness: return "ESS score >=10 or fatigue"
        case .depression: return "Low mood, loss of interest"
        case .anxiety: return "Worry, nervousness"
        case .cognitive: return "Memory/concentration issues"
        case .osa: return "Snoring, breathing pauses"
        case .pain: return "Pain affecting sleep"
        case .sleepTiming: return "Delayed/advanced sleep phase"
        case .dietImpact: return "Caffeine/alcohol affecting sleep"
        }
    }

    /// Questionnaires triggered by this gateway
    var triggeredQuestionnaires: [String] {
        switch self {
        case .insomnia:
            return ["ISI", "DBAS-16", "Sleep Hygiene", "PSAS (Cognitive)", "PSAS (Somatic)"]
        case .poorSleepQuality:
            return ["ISI", "Sleep Hygiene"]
        case .depression:
            return ["PHQ-9", "DASS-21 (Depression)", "DASS-21 (Anxiety)", "DASS-21 (Stress)"]
        case .anxiety:
            return ["GAD-7", "DASS-21 (Depression)", "DASS-21 (Anxiety)", "DASS-21 (Stress)"]
        case .excessiveSleepiness:
            return ["ESS", "FSS", "FOSQ-10"]
        case .cognitive:
            return ["PROMIS Cognitive"]
        case .osa:
            return ["STOP-BANG", "Berlin"]
        case .pain:
            return ["BPI (Severity)", "BPI (Interference)"]
        case .sleepTiming:
            return ["MEQ (Chronotype)"]
        case .dietImpact:
            return ["MEDAS"]
        }
    }

    /// Short list of questionnaire abbreviations for compact display
    var questionnaireAbbreviations: String {
        switch self {
        case .insomnia:
            return "ISI, DBAS, SHI, PSAS"
        case .poorSleepQuality:
            return "ISI, SHI"
        case .depression:
            return "PHQ-9, DASS-21"
        case .anxiety:
            return "GAD-7, DASS-21"
        case .excessiveSleepiness:
            return "ESS, FSS, FOSQ"
        case .cognitive:
            return "PROMIS-Cog"
        case .osa:
            return "STOP-BANG, Berlin"
        case .pain:
            return "BPI"
        case .sleepTiming:
            return "MEQ"
        case .dietImpact:
            return "MEDAS"
        }
    }
}

// MARK: - Question Model

struct Question: Identifiable, Codable {
    let id: String
    let text: String
    let pillar: Pillar
    let tier: QuestionTier
    let questionType: QuestionType
    let estimatedMinutes: Double
    let required: Bool

    // Options for select questions
    var options: [String]?

    // Scale configuration
    var scaleMin: Int?
    var scaleMax: Int?
    var scaleMinLabel: String?
    var scaleMaxLabel: String?

    // Number configuration
    var minValue: Int?
    var maxValue: Int?
    var step: Double?
    var unit: String?
    var defaultValue: Int?

    // Help text
    var helpText: String?

    // Gateway configuration
    var isGateway: Bool
    var gatewayType: GatewayType?
    var gatewayThreshold: Double?

    // Conditional display
    var conditionalLogic: ConditionalLogic?

    // Special value for scroll inputs
    var specialValue: Int?
    var specialLabel: String?

    // Group for organization
    var group: String?

    // Repeating group fields
    var repeatingFields: [RepeatingField]?

    init(
        id: String,
        text: String,
        pillar: Pillar,
        tier: QuestionTier = .core,
        questionType: QuestionType,
        estimatedMinutes: Double = 0.5,
        required: Bool = true,
        options: [String]? = nil,
        scaleMin: Int? = nil,
        scaleMax: Int? = nil,
        scaleMinLabel: String? = nil,
        scaleMaxLabel: String? = nil,
        minValue: Int? = nil,
        maxValue: Int? = nil,
        step: Double? = nil,
        unit: String? = nil,
        defaultValue: Int? = nil,
        helpText: String? = nil,
        isGateway: Bool = false,
        gatewayType: GatewayType? = nil,
        gatewayThreshold: Double? = nil,
        conditionalLogic: ConditionalLogic? = nil,
        specialValue: Int? = nil,
        specialLabel: String? = nil,
        group: String? = nil,
        repeatingFields: [RepeatingField]? = nil
    ) {
        self.id = id
        self.text = text
        self.pillar = pillar
        self.tier = tier
        self.questionType = questionType
        self.estimatedMinutes = estimatedMinutes
        self.required = required
        self.options = options
        self.scaleMin = scaleMin
        self.scaleMax = scaleMax
        self.scaleMinLabel = scaleMinLabel
        self.scaleMaxLabel = scaleMaxLabel
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.unit = unit
        self.defaultValue = defaultValue
        self.helpText = helpText
        self.isGateway = isGateway
        self.gatewayType = gatewayType
        self.gatewayThreshold = gatewayThreshold
        self.conditionalLogic = conditionalLogic
        self.specialValue = specialValue
        self.specialLabel = specialLabel
        self.group = group
        self.repeatingFields = repeatingFields
    }
}

struct RepeatingField: Codable {
    let id: String
    let label: String
    let type: QuestionType
    var minValue: Int?
    var maxValue: Int?
}

struct ConditionalLogic: Codable {
    let questionId: String
    var equals: String?
    var greaterThan: Double?
    var lessThan: Double?
    var greaterThanOrEqual: Double?
    var lessThanOrEqual: Double?
}

// MARK: - Response Model

struct QuestionResponse: Identifiable, Codable {
    let id: UUID
    let questionId: String
    let dayNumber: Int
    var stringValue: String?
    var numberValue: Double?
    var arrayValue: [String]?
    var objectValue: [String: String]?
    var answeredAt: Date
    var answeredInSeconds: Int?
    /// True if this answer was derived from an equivalent question (not directly answered)
    /// Used to distinguish user-provided answers from system-derived ones for clinical scoring
    var isDerived: Bool

    init(
        id: UUID = UUID(),
        questionId: String,
        dayNumber: Int,
        stringValue: String? = nil,
        numberValue: Double? = nil,
        arrayValue: [String]? = nil,
        objectValue: [String: String]? = nil,
        answeredAt: Date = Date(),
        answeredInSeconds: Int? = nil,
        isDerived: Bool = false
    ) {
        self.id = id
        self.questionId = questionId
        self.dayNumber = dayNumber
        self.stringValue = stringValue
        self.numberValue = numberValue
        self.arrayValue = arrayValue
        self.objectValue = objectValue
        self.answeredAt = answeredAt
        self.answeredInSeconds = answeredInSeconds
        self.isDerived = isDerived
    }

    var displayValue: String {
        if let str = stringValue { return str }
        if let num = numberValue { return String(format: "%.1f", num) }
        if let arr = arrayValue { return arr.joined(separator: ", ") }
        if let obj = objectValue { return obj.map { "\($0.key): \($0.value)" }.joined(separator: "; ") }
        return ""
    }
}

// MARK: - Day Configuration

struct DayConfiguration: Identifiable, Codable {
    let id: Int
    let dayNumber: Int
    let title: String
    let description: String
    let estimatedMinutes: Int
    let moduleIds: [String]
    let isExpansionDay: Bool
    let requiredGateways: [GatewayType]?

    var formattedTitle: String {
        return "Day \(dayNumber): \(title)"
    }
}

// MARK: - Gateway State

struct GatewayState: Identifiable, Codable {
    let id: String
    let gatewayType: GatewayType
    var triggered: Bool
    var triggeredAt: Date?
    var evaluationData: [String: String]?

    init(gatewayType: GatewayType, triggered: Bool = false, triggeredAt: Date? = nil, evaluationData: [String: String]? = nil) {
        self.id = gatewayType.rawValue
        self.gatewayType = gatewayType
        self.triggered = triggered
        self.triggeredAt = triggeredAt
        self.evaluationData = evaluationData
    }
}

// MARK: - Module Definition

struct AssessmentModule: Identifiable, Codable {
    let id: String
    let moduleId: String
    let name: String
    let description: String
    let pillar: Pillar
    let tier: QuestionTier
    let moduleType: String
    let questionIds: [String]
    let estimatedMinutes: Double
}

// MARK: - HealthKit Sleep Summary (for auto-fill)

struct HealthKitSleepSummary: Codable {
    let date: Date
    let inBedTime: Date?
    let asleepTime: Date?
    let wakeTime: Date?
    let totalSleepMinutes: Int?
    let awakeningsCount: Int?
    let awakeDurationMinutes: Int?
    let sleepEfficiency: Double?
    let deepSleepMinutes: Int?
    let remSleepMinutes: Int?
    let lightSleepMinutes: Int?

    var formattedInBedTime: String? {
        guard let time = inBedTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }

    var formattedWakeTime: String? {
        guard let time = wakeTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }
}

// MARK: - Journey Progress

struct JourneyProgressData: Codable {
    var currentDay: Int
    var completedDays: [Int]
    let totalDays: Int
    let startedAt: Date
    var gatewayStates: [GatewayState]
    // Section completion status for current day
    var sleepLogCompleted: Bool = false
    var assessmentCompleted: Bool = false
    // Expansion pack completion for current day (tracked locally)
    var expansionPackCompleted: Bool = false
    // Gateways whose expansion questions have been answered (persists across days)
    var completedExpansionGateways: [GatewayType] = []

    var progressPercentage: Double {
        return Double(completedDays.count) / Double(totalDays) * 100.0
    }

    var isComplete: Bool {
        return completedDays.count >= totalDays
    }

    var daysRemaining: Int {
        return totalDays - completedDays.count
    }

    func isGatewayTriggered(_ gateway: GatewayType) -> Bool {
        return gatewayStates.first(where: { $0.gatewayType == gateway })?.triggered ?? false
    }

    /// Check if a gateway's expansion questions have already been completed
    func hasCompletedExpansion(for gateway: GatewayType) -> Bool {
        return completedExpansionGateways.contains(gateway)
    }
}
