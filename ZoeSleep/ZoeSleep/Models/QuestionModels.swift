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
        // CRITICAL: Even in non-circadian mode, backgrounds use circadian colors
        // So we MUST use bright text in dark phases for readability
        let currentPalette = CircadianPalette.current
        if currentPalette.isDark {
            return currentPalette.textPrimary  // Bright cream for dark backgrounds
        }
        if accentColorOption != nil {
            // Non-circadian mode during day: use system colors
            return Color.primary
        }
        return palette.textPrimary  // Smoothly interpolated!
    }

    var textSecondary: Color {
        // CRITICAL: Match dark phase check for consistency
        let currentPalette = CircadianPalette.current
        if currentPalette.isDark {
            return currentPalette.textSecondary  // Golden amber for dark backgrounds
        }
        if accentColorOption != nil {
            return Color.secondary
        }
        return palette.textSecondary  // Smoothly interpolated!
    }

    /// Muted text for hints, timestamps, etc.
    var textMuted: Color {
        // CRITICAL: Match dark phase check for consistency
        let currentPalette = CircadianPalette.current
        if currentPalette.isDark {
            return currentPalette.textSecondary.opacity(0.7)  // Warm amber muted
        }
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
    /// CRITICAL: Cards use circadian backgrounds (GlassyCardBackground), so text must match
    var textOnCard: Color {
        // CRITICAL: Card backgrounds ALWAYS use circadian colors (GlassyCardBackground)
        // So we MUST use bright text in dark phases regardless of appearance mode
        let currentPalette = CircadianPalette.current
        if currentPalette.isDark {
            return currentPalette.textPrimary  // Bright warm cream on dark cards
        }
        if accentColorOption != nil {
            return Color(red: 0.15, green: 0.10, blue: 0.08)  // Dark on light cards
        }
        return palette.textPrimary  // Same as textPrimary for cards
    }

    /// Secondary text ON cards - circadian-aware
    var textOnCardSecondary: Color {
        // CRITICAL: Match dark phase check for card text consistency
        let currentPalette = CircadianPalette.current
        if currentPalette.isDark {
            return currentPalette.textSecondary  // Golden amber on dark cards
        }
        if accentColorOption != nil {
            return Color(red: 0.35, green: 0.25, blue: 0.20)
        }
        return palette.textSecondary  // Same as textSecondary for cards
    }

    /// Muted text ON cards - circadian-aware
    var textOnCardMuted: Color {
        // CRITICAL: Match dark phase check for card text consistency
        let currentPalette = CircadianPalette.current
        if currentPalette.isDark {
            return currentPalette.textSecondary.opacity(0.7)  // Warm amber muted on dark cards
        }
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
    case hoursMinutesScroll = "HoursMinutesScroll"  // For sleep duration with 15-min increments
    case repeatingGroup = "RepeatingGroup"
    case info = "Info"
    case napDetails = "NapDetails"  // Dynamic nap blocks with start time + duration
    case medicationSelect = "MedicationSelect"  // Multi-select medication categories with doses
    case caffeineSelect = "CaffeineSelect"  // Multi-select caffeine types with quantity and mg tracking
    case prescriptionMedSelect = "PrescriptionMedSelect"  // Multi-select Rx meds with dose + timing
    case supplementSelect = "SupplementSelect"  // Multi-select supplements with dose + timing
    case surgeryDetails = "SurgeryDetails"  // Surgery/procedure entries with name + date
}

// MARK: - Nap Entry Model

/// Represents a single nap with start time and duration
struct NapEntry: Codable, Identifiable, Equatable {
    var id: Int { napNumber }
    let napNumber: Int          // 1, 2, 3...
    var startTime: String       // "14:30" (24h format)
    var durationMinutes: Int    // 15, 30, 45, 60, 90, 120

    init(napNumber: Int, startTime: String = "14:00", durationMinutes: Int = 30) {
        self.napNumber = napNumber
        self.startTime = startTime
        self.durationMinutes = durationMinutes
    }

    /// Default start time for a nap based on its number (2 PM, 4 PM, 6 PM, etc.)
    static func defaultStartTime(for napNumber: Int) -> String {
        let baseHour = 14  // 2 PM
        let hour = baseHour + ((napNumber - 1) * 2)
        return String(format: "%02d:00", min(hour, 20))  // Cap at 8 PM
    }
}

// MARK: - Medication Category Model

/// Represents a sleep medication category for multi-select
struct MedicationCategory: Identifiable {
    let id: String
    let name: String
    let subtitle: String?
    let icon: String
    let doseUnit: String  // mg, IU, drops, etc.
    let commonDoses: [String]  // Quick-select dose options
    let requiresName: Bool  // Whether to show "specify medication" field

    init(id: String, name: String, subtitle: String? = nil, icon: String, doseUnit: String = "mg", commonDoses: [String] = [], requiresName: Bool = false) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.icon = icon
        self.doseUnit = doseUnit
        self.commonDoses = commonDoses
        self.requiresName = requiresName
    }

    /// All available medication categories with dose options
    static let allCategories: [MedicationCategory] = [
        MedicationCategory(
            id: "melatonin",
            name: "Melatonin",
            icon: "moon.stars",
            doseUnit: "mg",
            commonDoses: ["0.5", "1", "2", "3", "5", "10"]
        ),
        MedicationCategory(
            id: "prescription",
            name: "Prescription",
            subtitle: "Ambien, Lunesta, Trazodone",
            icon: "pills",
            doseUnit: "mg",
            commonDoses: ["5", "10", "25", "50", "100"],
            requiresName: true
        ),
        MedicationCategory(
            id: "otc",
            name: "OTC Sleep Aid",
            subtitle: "ZzzQuil, Unisom, Benadryl",
            icon: "cross.case",
            doseUnit: "mg",
            commonDoses: ["25", "50"],
            requiresName: true
        ),
        MedicationCategory(
            id: "cbd_thc",
            name: "CBD/THC",
            icon: "leaf",
            doseUnit: "mg",
            commonDoses: ["5", "10", "15", "20", "25", "50"]
        ),
        MedicationCategory(
            id: "magnesium",
            name: "Magnesium",
            subtitle: "Glycinate, Citrate, Oxide",
            icon: "bolt.circle",
            doseUnit: "mg",
            commonDoses: ["200", "300", "400", "500"]
        ),
        MedicationCategory(
            id: "herbal",
            name: "Herbal/Natural",
            subtitle: "Valerian, L-Theanine, GABA",
            icon: "leaf.circle",
            doseUnit: "mg",
            commonDoses: ["100", "200", "300", "500"],
            requiresName: true
        ),
        MedicationCategory(
            id: "other",
            name: "Other",
            icon: "ellipsis.circle",
            doseUnit: "mg",
            commonDoses: [],
            requiresName: true
        )
    ]
}

// MARK: - Medication Selection (with dose)

/// Represents a selected medication with its dose
struct MedicationSelection: Codable, Equatable {
    let categoryId: String
    var dose: String?  // e.g., "5", "10", "25"
    var medicationName: String?  // For categories that require specifying the medication

    init(categoryId: String, dose: String? = nil, medicationName: String? = nil) {
        self.categoryId = categoryId
        self.dose = dose
        self.medicationName = medicationName
    }

    /// Display string for the selection
    var displayString: String {
        let category = MedicationCategory.allCategories.first { $0.id == categoryId }
        var parts: [String] = []

        if let name = medicationName, !name.isEmpty {
            parts.append(name)
        } else if let cat = category {
            parts.append(cat.name)
        }

        if let dose = dose, !dose.isEmpty, let cat = category {
            parts.append("\(dose) \(cat.doseUnit)")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Medication Timing Categories

/// Time of day categories for medication/supplement intake
enum MedicationTimingCategory: String, Codable, CaseIterable {
    case morning = "morning"        // 5 AM - 12 PM
    case afternoon = "afternoon"    // 12 PM - 5 PM
    case evening = "evening"        // 5 PM - 9 PM
    case bedtime = "bedtime"        // 9 PM - 12 AM

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .bedtime: return "Bedtime"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .afternoon: return "sun.min.fill"
        case .evening: return "sunset.fill"
        case .bedtime: return "moon.stars.fill"
        }
    }
}

// MARK: - Medication With Timing Selection

/// Represents a selected medication/supplement with dose AND timing
struct MedicationWithTiming: Codable, Equatable {
    let categoryId: String
    var dose: String?
    var medicationName: String?
    var timingCategories: [MedicationTimingCategory]  // Can select multiple (e.g., morning + bedtime)
    var specificTime: String?  // Optional "HH:mm" format for precise tracking

    init(categoryId: String, dose: String? = nil, medicationName: String? = nil,
         timingCategories: [MedicationTimingCategory] = [], specificTime: String? = nil) {
        self.categoryId = categoryId
        self.dose = dose
        self.medicationName = medicationName
        self.timingCategories = timingCategories
        self.specificTime = specificTime
    }

    /// Display string for the selection
    func displayString(using categories: [MedicationCategory]) -> String {
        let category = categories.first { $0.id == categoryId }
        var parts: [String] = []

        if let name = medicationName, !name.isEmpty {
            parts.append(name)
        } else if let cat = category {
            parts.append(cat.name)
        }

        if let dose = dose, !dose.isEmpty, let cat = category {
            parts.append("\(dose) \(cat.doseUnit)")
        }

        if !timingCategories.isEmpty {
            let timings = timingCategories.map { $0.displayName }.joined(separator: ", ")
            parts.append("(\(timings))")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Prescription Medication Categories (44A)

/// Represents prescription medication categories for the intake assessment
struct PrescriptionMedCategory: Identifiable {
    let id: String
    let name: String
    let subtitle: String?
    let icon: String
    let doseUnit: String
    let commonDoses: [String]
    let requiresName: Bool

    init(id: String, name: String, subtitle: String? = nil, icon: String, doseUnit: String = "mg", commonDoses: [String] = [], requiresName: Bool = true) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.icon = icon
        self.doseUnit = doseUnit
        self.commonDoses = commonDoses
        self.requiresName = requiresName
    }

    /// All prescription medication categories
    static let allCategories: [PrescriptionMedCategory] = [
        PrescriptionMedCategory(
            id: "sleep_aid",
            name: "Prescription Sleep Aid",
            subtitle: "Ambien, Lunesta, Sonata",
            icon: "pills",
            doseUnit: "mg",
            commonDoses: ["5", "10", "12.5", "20"]
        ),
        PrescriptionMedCategory(
            id: "benzodiazepine",
            name: "Benzodiazepine",
            subtitle: "Xanax, Valium, Ativan, Klonopin",
            icon: "pills.fill",
            doseUnit: "mg",
            commonDoses: ["0.25", "0.5", "1", "2"]
        ),
        PrescriptionMedCategory(
            id: "antidepressant",
            name: "Antidepressant",
            subtitle: "Trazodone, Mirtazapine, Amitriptyline",
            icon: "brain",
            doseUnit: "mg",
            commonDoses: ["25", "50", "100", "150"]
        ),
        PrescriptionMedCategory(
            id: "blood_pressure",
            name: "Blood Pressure Medication",
            subtitle: "Beta-blockers, ACE inhibitors",
            icon: "heart.fill",
            doseUnit: "mg",
            commonDoses: ["10", "25", "50", "100"]
        ),
        PrescriptionMedCategory(
            id: "pain_medication",
            name: "Pain Medication",
            subtitle: "Opioids, NSAIDs, Muscle relaxants",
            icon: "bandage.fill",
            doseUnit: "mg",
            commonDoses: ["5", "10", "20", "50"]
        ),
        PrescriptionMedCategory(
            id: "thyroid",
            name: "Thyroid Medication",
            subtitle: "Levothyroxine, Synthroid",
            icon: "staroflife.fill",
            doseUnit: "mcg",
            commonDoses: ["25", "50", "75", "100", "125"],
            requiresName: false
        ),
        PrescriptionMedCategory(
            id: "diabetes",
            name: "Diabetes Medication",
            subtitle: "Metformin, Insulin, etc.",
            icon: "drop.fill",
            doseUnit: "mg",
            commonDoses: ["500", "850", "1000"]
        ),
        PrescriptionMedCategory(
            id: "other_rx",
            name: "Other Prescription",
            icon: "cross.case.fill",
            doseUnit: "mg",
            commonDoses: []
        )
    ]
}

// MARK: - Supplement Categories (44C)

/// Represents supplement categories for the intake assessment
struct SupplementCategory: Identifiable {
    let id: String
    let name: String
    let subtitle: String?
    let icon: String
    let doseUnit: String
    let commonDoses: [String]
    let requiresName: Bool

    init(id: String, name: String, subtitle: String? = nil, icon: String, doseUnit: String = "mg", commonDoses: [String] = [], requiresName: Bool = false) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.icon = icon
        self.doseUnit = doseUnit
        self.commonDoses = commonDoses
        self.requiresName = requiresName
    }

    /// All sleep-related supplement categories
    static let allCategories: [SupplementCategory] = [
        SupplementCategory(
            id: "melatonin",
            name: "Melatonin",
            subtitle: "Sleep hormone",
            icon: "moon.stars",
            doseUnit: "mg",
            commonDoses: ["0.5", "1", "2", "3", "5", "10"]
        ),
        SupplementCategory(
            id: "magnesium",
            name: "Magnesium",
            subtitle: "Glycinate, Citrate, Threonate",
            icon: "bolt.circle",
            doseUnit: "mg",
            commonDoses: ["200", "300", "400", "500"]
        ),
        SupplementCategory(
            id: "valerian_root",
            name: "Valerian Root",
            icon: "leaf.fill",
            doseUnit: "mg",
            commonDoses: ["300", "450", "600", "900"]
        ),
        SupplementCategory(
            id: "l_theanine",
            name: "L-Theanine",
            icon: "leaf.circle",
            doseUnit: "mg",
            commonDoses: ["100", "200", "300", "400"]
        ),
        SupplementCategory(
            id: "cbd_cbn",
            name: "CBD/CBN",
            icon: "leaf",
            doseUnit: "mg",
            commonDoses: ["10", "15", "20", "25", "50"]
        ),
        SupplementCategory(
            id: "gaba",
            name: "GABA",
            icon: "brain.head.profile",
            doseUnit: "mg",
            commonDoses: ["100", "250", "500", "750"]
        ),
        SupplementCategory(
            id: "chamomile",
            name: "Chamomile",
            subtitle: "Tea or extract",
            icon: "cup.and.saucer",
            doseUnit: "mg",
            commonDoses: ["250", "400", "500"]
        ),
        SupplementCategory(
            id: "ashwagandha",
            name: "Ashwagandha",
            icon: "leaf.circle.fill",
            doseUnit: "mg",
            commonDoses: ["300", "450", "600"]
        ),
        SupplementCategory(
            id: "glycine",
            name: "Glycine",
            icon: "atom",
            doseUnit: "g",
            commonDoses: ["1", "2", "3"]
        ),
        SupplementCategory(
            id: "5_htp",
            name: "5-HTP",
            icon: "pills.circle",
            doseUnit: "mg",
            commonDoses: ["50", "100", "200"]
        ),
        SupplementCategory(
            id: "other_supplement",
            name: "Other Supplement",
            icon: "ellipsis.circle",
            doseUnit: "mg",
            commonDoses: [],
            requiresName: true
        )
    ]
}

// MARK: - Surgery Entry Model (44G)

/// Represents a surgery or medical procedure entry
struct SurgeryEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var procedureName: String
    var procedureDate: String  // "yyyy-MM" format (month/year)

    init(procedureName: String = "", procedureDate: String = "") {
        self.procedureName = procedureName
        self.procedureDate = procedureDate
    }

    /// Display string for the entry
    var displayString: String {
        var parts: [String] = []
        if !procedureName.isEmpty {
            parts.append(procedureName)
        }
        if !procedureDate.isEmpty {
            parts.append("(\(procedureDate))")
        }
        return parts.isEmpty ? "New procedure" : parts.joined(separator: " ")
    }
}

// MARK: - Caffeine Tracking

/// Represents a type of caffeinated drink with estimated caffeine content
struct CaffeineType: Identifiable {
    let id: String
    let name: String
    let subtitle: String?
    let icon: String
    let mgPerServing: Int  // Estimated mg caffeine per standard serving
    let servingSize: String  // e.g., "8 oz cup", "1 shot", "12 oz can"

    init(id: String, name: String, subtitle: String? = nil, icon: String, mgPerServing: Int, servingSize: String) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.icon = icon
        self.mgPerServing = mgPerServing
        self.servingSize = servingSize
    }

    static let allTypes: [CaffeineType] = [
        CaffeineType(
            id: "drip_coffee",
            name: "Drip Coffee",
            subtitle: "Regular brewed",
            icon: "cup.and.saucer.fill",
            mgPerServing: 95,
            servingSize: "8 oz cup"
        ),
        CaffeineType(
            id: "espresso",
            name: "Espresso",
            subtitle: "Single or double shot",
            icon: "cup.and.saucer.fill",
            mgPerServing: 63,
            servingSize: "1 oz shot"
        ),
        CaffeineType(
            id: "latte_cappuccino",
            name: "Latte / Cappuccino",
            subtitle: "Espresso-based drinks",
            icon: "cup.and.saucer.fill",
            mgPerServing: 75,
            servingSize: "12 oz"
        ),
        CaffeineType(
            id: "cold_brew",
            name: "Cold Brew",
            subtitle: "Concentrated",
            icon: "mug.fill",
            mgPerServing: 200,
            servingSize: "12 oz"
        ),
        CaffeineType(
            id: "black_tea",
            name: "Black Tea",
            icon: "leaf.fill",
            mgPerServing: 47,
            servingSize: "8 oz cup"
        ),
        CaffeineType(
            id: "green_tea",
            name: "Green Tea",
            icon: "leaf.fill",
            mgPerServing: 28,
            servingSize: "8 oz cup"
        ),
        CaffeineType(
            id: "matcha",
            name: "Matcha",
            subtitle: "Powdered green tea",
            icon: "leaf.fill",
            mgPerServing: 70,
            servingSize: "1 tsp serving"
        ),
        CaffeineType(
            id: "energy_drink",
            name: "Energy Drink",
            subtitle: "Red Bull, Monster, etc.",
            icon: "bolt.fill",
            mgPerServing: 80,
            servingSize: "8.4 oz can"
        ),
        CaffeineType(
            id: "energy_drink_large",
            name: "Energy Drink (Large)",
            subtitle: "16oz cans",
            icon: "bolt.fill",
            mgPerServing: 160,
            servingSize: "16 oz can"
        ),
        CaffeineType(
            id: "soda",
            name: "Cola / Soda",
            subtitle: "Coca-Cola, Pepsi, etc.",
            icon: "takeoutbag.and.cup.and.straw.fill",
            mgPerServing: 34,
            servingSize: "12 oz can"
        ),
        CaffeineType(
            id: "diet_soda",
            name: "Diet Cola",
            subtitle: "Diet Coke, Coke Zero, etc.",
            icon: "takeoutbag.and.cup.and.straw.fill",
            mgPerServing: 46,
            servingSize: "12 oz can"
        ),
        CaffeineType(
            id: "preworkout",
            name: "Pre-Workout",
            subtitle: "Fitness supplements",
            icon: "dumbbell.fill",
            mgPerServing: 200,
            servingSize: "1 scoop"
        ),
        CaffeineType(
            id: "chocolate",
            name: "Dark Chocolate",
            icon: "square.fill",
            mgPerServing: 12,
            servingSize: "1 oz"
        )
    ]
}

/// Represents a caffeine entry with type and quantity
struct CaffeineEntry: Codable, Equatable {
    let typeId: String
    var count: Int  // Number of servings

    init(typeId: String, count: Int = 1) {
        self.typeId = typeId
        self.count = count
    }

    /// Estimated total caffeine in mg
    var estimatedMg: Int {
        guard let caffeineType = CaffeineType.allTypes.first(where: { $0.id == typeId }) else {
            return 0
        }
        return caffeineType.mgPerServing * count
    }

    /// Display string for the entry
    var displayString: String {
        guard let caffeineType = CaffeineType.allTypes.first(where: { $0.id == typeId }) else {
            return "\(count)x Unknown"
        }
        return "\(count)x \(caffeineType.name) (~\(estimatedMg)mg)"
    }
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
    case shiftWork = "shift_work"
    case exercise = "exercise"

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
        case .shiftWork: return "Shift Work Disorder"
        case .exercise: return "Physical Activity"
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
        case .shiftWork: return "Shift Work"
        case .exercise: return "Exercise"
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
        case .shiftWork: return 3.0  // SWDSQ (4 questions)
        case .exercise: return 8.0  // Physical activity expansion
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
        case .osa, .pain, .exercise:
            return ["expansion_physical"]
        case .sleepTiming:
            return ["expansion_sleep_timing"]
        case .dietImpact:
            return ["expansion_nutritional"]
        case .shiftWork:
            return ["expansion_swdsq"]
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
        case .shiftWork: return "clock.badge.exclamationmark"
        case .exercise: return "figure.run"
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
        case .shiftWork: return .teal
        case .exercise: return .brown
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
        case .shiftWork: return "Works shifts or irregular hours"
        case .exercise: return "Exercises regularly"
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
        case .shiftWork:
            return ["SWDSQ", "KSS (Sleep Log)"]
        case .exercise:
            return ["IPAQ (Physical Activity)", "Exercise Timing"]
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
        case .shiftWork:
            return "SWDSQ, KSS"
        case .exercise:
            return "IPAQ"
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

    // Number configuration (metric by default)
    var minValue: Int?
    var maxValue: Int?
    var step: Double?
    var unit: String?
    var defaultValue: Int?

    // Imperial unit configuration (for questions with unit switching)
    var unitImperial: String?
    var minImperial: Int?
    var maxImperial: Int?
    var defaultImperial: Int?

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
        unitImperial: String? = nil,
        minImperial: Int? = nil,
        maxImperial: Int? = nil,
        defaultImperial: Int? = nil,
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
        self.unitImperial = unitImperial
        self.minImperial = minImperial
        self.maxImperial = maxImperial
        self.defaultImperial = defaultImperial
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
    // Single condition fields
    var questionId: String?
    var equals: String?
    var greaterThan: Double?
    var lessThan: Double?
    var greaterThanOrEqual: Double?
    var lessThanOrEqual: Double?

    // Array condition: Check if array response contains a value
    var contains: String?

    // Age-based condition (calculated from D2 birth date)
    var ageUnder: Int?
    var ageOver: Int?

    // Compound conditions (AND logic - all must be true)
    var all: [ConditionalLogic]?

    // Compound conditions (OR logic - at least one must be true)
    var any: [ConditionalLogic]?

    // Simple initializer for single condition
    init(questionId: String, equals: String? = nil, greaterThan: Double? = nil, lessThan: Double? = nil, greaterThanOrEqual: Double? = nil, lessThanOrEqual: Double? = nil, contains: String? = nil) {
        self.questionId = questionId
        self.equals = equals
        self.greaterThan = greaterThan
        self.lessThan = lessThan
        self.greaterThanOrEqual = greaterThanOrEqual
        self.lessThanOrEqual = lessThanOrEqual
        self.contains = contains
    }

    // Initializer for compound conditions
    init(all: [ConditionalLogic]) {
        self.all = all
    }

    init(any: [ConditionalLogic]) {
        self.any = any
    }

    // Initializer for age-based condition
    init(ageUnder: Int) {
        self.ageUnder = ageUnder
    }

    init(ageOver: Int) {
        self.ageOver = ageOver
    }

    // Default empty initializer for building logic progressively
    init() {
        // All fields default to nil
    }
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

struct GatewayState: Identifiable, Codable, Equatable {
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

    static func == (lhs: GatewayState, rhs: GatewayState) -> Bool {
        lhs.id == rhs.id && lhs.triggered == rhs.triggered
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

// MARK: - Questionnaire Validation Info

/// Validated information about each standardized questionnaire
/// All citation counts and validation data are from peer-reviewed sources
struct QuestionnaireValidationInfo {
    let id: String                      // Module ID (e.g., "expansion_isi")
    let fullName: String                // Full questionnaire name
    let abbreviation: String            // Short form (e.g., "ISI")
    let originalAuthors: String         // Primary author(s)
    let originalYear: Int               // Year first published
    let originalJournal: String         // Publication venue
    let validationStudiesCount: String  // Approximate citation/validation count
    let sensitivity: String?            // Sensitivity percentage if known
    let specificity: String?            // Specificity percentage if known
    let cronbachAlpha: String?          // Internal consistency if known
    let purpose: String                 // What it measures (patient-friendly)
    let whyWeAsk: String                // Why this matters for their care
    let estimatedMinutes: Int           // Time to complete
    let questionCount: Int              // Number of questions
    let icon: String                    // SF Symbol name
    let category: QuestionnaireCategory // Category for grouping

    enum QuestionnaireCategory: String {
        case insomnia = "Sleep Quality"
        case sleepiness = "Daytime Function"
        case mentalHealth = "Mental Health"
        case breathing = "Breathing & OSA"
        case physical = "Physical Health"
        case lifestyle = "Lifestyle"
        case chronotype = "Sleep Timing"
        case occupational = "Occupational Sleep"
    }
}

// MARK: - Questionnaire Library

/// Static library of all validated questionnaire information
/// Data sourced from PubMed, systematic reviews, and original publications
struct QuestionnaireLibrary {

    static let all: [QuestionnaireValidationInfo] = [

        // MARK: - Insomnia Assessments

        QuestionnaireValidationInfo(
            id: "expansion_isi",
            fullName: "Insomnia Severity Index",
            abbreviation: "ISI",
            originalAuthors: "Morin, Belleville, Bélanger & Ivers",
            originalYear: 2011,
            originalJournal: "SLEEP",
            validationStudiesCount: "2,500+",
            sensitivity: "89.6%",
            specificity: "86.5%",
            cronbachAlpha: "0.90",
            purpose: "Measures the severity of your insomnia symptoms and how they affect your daily life",
            whyWeAsk: "Understanding the severity of your sleep difficulties helps us tailor the right level of support. The ISI is the gold standard for tracking insomnia treatment progress.",
            estimatedMinutes: 3,
            questionCount: 7,
            icon: "moon.zzz.fill",
            category: .insomnia
        ),

        QuestionnaireValidationInfo(
            id: "expansion_dbas",
            fullName: "Dysfunctional Beliefs and Attitudes about Sleep",
            abbreviation: "DBAS-16",
            originalAuthors: "Morin, Vallières & Ivers",
            originalYear: 2007,
            originalJournal: "SLEEP",
            validationStudiesCount: "1,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.79",
            purpose: "Identifies unhelpful thoughts and beliefs about sleep that may be keeping you awake",
            whyWeAsk: "Research shows that changing how we think about sleep is often more effective than medication. Understanding your sleep beliefs helps us address the root causes of insomnia.",
            estimatedMinutes: 8,
            questionCount: 16,
            icon: "brain.head.profile",
            category: .insomnia
        ),

        QuestionnaireValidationInfo(
            id: "expansion_sleep_hygiene",
            fullName: "Sleep Hygiene Index",
            abbreviation: "SHI",
            originalAuthors: "Mastin, Bryson & Corwyn",
            originalYear: 2006,
            originalJournal: "Journal of Behavioral Medicine",
            validationStudiesCount: "500+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.66",
            purpose: "Assesses your daily habits and behaviors that may be affecting your sleep quality",
            whyWeAsk: "Small changes in daily habits can have a big impact on sleep. This helps us identify simple adjustments that could improve your rest.",
            estimatedMinutes: 5,
            questionCount: 13,
            icon: "list.bullet.clipboard",
            category: .insomnia
        ),

        QuestionnaireValidationInfo(
            id: "expansion_psas",
            fullName: "Pre-Sleep Arousal Scale",
            abbreviation: "PSAS",
            originalAuthors: "Nicassio, Mendlowitz, Fussell & Petras",
            originalYear: 1985,
            originalJournal: "Behaviour Research and Therapy",
            validationStudiesCount: "800+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.88",
            purpose: "Measures both mental and physical activation that occurs as you try to fall asleep",
            whyWeAsk: "Racing thoughts and physical tension are common barriers to sleep. Understanding your pre-sleep state helps us recommend the right relaxation strategies.",
            estimatedMinutes: 5,
            questionCount: 16,
            icon: "waveform.path.ecg",
            category: .insomnia
        ),

        // MARK: - Daytime Sleepiness & Function

        QuestionnaireValidationInfo(
            id: "expansion_ess",
            fullName: "Epworth Sleepiness Scale",
            abbreviation: "ESS",
            originalAuthors: "Murray Johns",
            originalYear: 1991,
            originalJournal: "SLEEP",
            validationStudiesCount: "10,000+",
            sensitivity: "93.5%",
            specificity: "100%",
            cronbachAlpha: "0.88",
            purpose: "Measures your level of daytime sleepiness in everyday situations",
            whyWeAsk: "Excessive daytime sleepiness can signal underlying sleep disorders and affects your safety and quality of life. The ESS is used worldwide by sleep specialists.",
            estimatedMinutes: 3,
            questionCount: 8,
            icon: "sun.max.trianglebadge.exclamationmark",
            category: .sleepiness
        ),

        QuestionnaireValidationInfo(
            id: "expansion_fss",
            fullName: "Fatigue Severity Scale",
            abbreviation: "FSS",
            originalAuthors: "Krupp, LaRocca, Muir-Nash & Steinberg",
            originalYear: 1989,
            originalJournal: "Archives of Neurology",
            validationStudiesCount: "7,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.89",
            purpose: "Distinguishes true fatigue from sleepiness and measures how it impacts your daily activities",
            whyWeAsk: "Fatigue and sleepiness are different experiences with different solutions. Understanding which you're experiencing helps us provide the right support.",
            estimatedMinutes: 3,
            questionCount: 9,
            icon: "battery.25",
            category: .sleepiness
        ),

        QuestionnaireValidationInfo(
            id: "expansion_fosq",
            fullName: "Functional Outcomes of Sleep Questionnaire",
            abbreviation: "FOSQ-10",
            originalAuthors: "Chasens, Ratcliffe & Weaver",
            originalYear: 2009,
            originalJournal: "SLEEP",
            validationStudiesCount: "500+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.87",
            purpose: "Measures how sleepiness affects your ability to perform daily activities, work, and relationships",
            whyWeAsk: "Sleep problems don't just affect nights—they impact your whole life. Understanding these effects helps us prioritize what matters most to you.",
            estimatedMinutes: 4,
            questionCount: 10,
            icon: "figure.walk",
            category: .sleepiness
        ),

        // MARK: - Mental Health

        QuestionnaireValidationInfo(
            id: "expansion_phq9",
            fullName: "Patient Health Questionnaire",
            abbreviation: "PHQ-9",
            originalAuthors: "Kroenke, Spitzer & Williams",
            originalYear: 2001,
            originalJournal: "Journal of General Internal Medicine",
            validationStudiesCount: "15,000+",
            sensitivity: "88%",
            specificity: "88%",
            cronbachAlpha: "0.89",
            purpose: "Screens for depression symptoms that commonly accompany sleep difficulties",
            whyWeAsk: "Sleep and mood are deeply connected—improving one often helps the other. This helps us understand the full picture of your wellbeing.",
            estimatedMinutes: 3,
            questionCount: 9,
            icon: "heart.text.square",
            category: .mentalHealth
        ),

        QuestionnaireValidationInfo(
            id: "expansion_gad7",
            fullName: "Generalized Anxiety Disorder Scale",
            abbreviation: "GAD-7",
            originalAuthors: "Spitzer, Kroenke, Williams & Löwe",
            originalYear: 2006,
            originalJournal: "Archives of Internal Medicine",
            validationStudiesCount: "10,000+",
            sensitivity: "89%",
            specificity: "82%",
            cronbachAlpha: "0.92",
            purpose: "Screens for anxiety symptoms that can interfere with falling and staying asleep",
            whyWeAsk: "Anxiety and sleep problems often go hand in hand. Understanding your anxiety levels helps us recommend calming strategies that work.",
            estimatedMinutes: 2,
            questionCount: 7,
            icon: "bolt.heart",
            category: .mentalHealth
        ),

        QuestionnaireValidationInfo(
            id: "expansion_dass21",
            fullName: "Depression Anxiety Stress Scales",
            abbreviation: "DASS-21",
            originalAuthors: "Lovibond & Lovibond",
            originalYear: 1995,
            originalJournal: "Psychology Foundation of Australia",
            validationStudiesCount: "20,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.93",
            purpose: "Provides a comprehensive view of depression, anxiety, and stress levels",
            whyWeAsk: "This widely-validated assessment helps us understand the emotional factors affecting your sleep from multiple angles.",
            estimatedMinutes: 7,
            questionCount: 21,
            icon: "chart.bar.doc.horizontal",
            category: .mentalHealth
        ),

        QuestionnaireValidationInfo(
            id: "expansion_promis_cognitive",
            fullName: "PROMIS Cognitive Function",
            abbreviation: "PROMIS-Cog",
            originalAuthors: "NIH PROMIS Initiative",
            originalYear: 2010,
            originalJournal: "NIH/National Institutes of Health",
            validationStudiesCount: "2,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.95",
            purpose: "Assesses your perceived cognitive abilities including memory, concentration, and mental clarity",
            whyWeAsk: "Poor sleep significantly affects thinking and memory. Tracking cognitive function helps us measure how sleep improvements affect your mental sharpness.",
            estimatedMinutes: 2,
            questionCount: 8,
            icon: "brain",
            category: .mentalHealth
        ),

        // MARK: - Sleep Apnea Screening

        QuestionnaireValidationInfo(
            id: "expansion_stop_bang",
            fullName: "STOP-BANG Sleep Apnea Screening",
            abbreviation: "STOP-BANG",
            originalAuthors: "Chung, Yegneswaran, Liao et al.",
            originalYear: 2008,
            originalJournal: "Anesthesiology",
            validationStudiesCount: "5,000+",
            sensitivity: "93%",
            specificity: "43%",
            cronbachAlpha: nil,
            purpose: "Screens for risk factors associated with obstructive sleep apnea",
            whyWeAsk: "Sleep apnea affects 1 in 5 adults and often goes undiagnosed. Early detection can prevent serious health consequences and dramatically improve sleep quality.",
            estimatedMinutes: 2,
            questionCount: 8,
            icon: "lungs",
            category: .breathing
        ),

        QuestionnaireValidationInfo(
            id: "expansion_berlin",
            fullName: "Berlin Questionnaire",
            abbreviation: "Berlin",
            originalAuthors: "Netzer, Stoohs, Netzer, Clark & Strohl",
            originalYear: 1999,
            originalJournal: "Annals of Internal Medicine",
            validationStudiesCount: "3,000+",
            sensitivity: "86%",
            specificity: "77%",
            cronbachAlpha: nil,
            purpose: "Identifies individuals at high risk for sleep apnea based on symptoms and risk factors",
            whyWeAsk: "The Berlin questionnaire was developed specifically for primary care settings and helps determine if further sleep testing may be beneficial.",
            estimatedMinutes: 3,
            questionCount: 10,
            icon: "wind",
            category: .breathing
        ),

        // MARK: - Physical Health

        QuestionnaireValidationInfo(
            id: "expansion_bpi",
            fullName: "Brief Pain Inventory",
            abbreviation: "BPI",
            originalAuthors: "Charles S. Cleeland",
            originalYear: 1994,
            originalJournal: "Annals of the Academy of Medicine, Singapore",
            validationStudiesCount: "6,300+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.87",
            purpose: "Measures pain severity and how it interferes with your daily life and sleep",
            whyWeAsk: "Pain is one of the most common causes of poor sleep. Understanding your pain patterns helps us address this barrier to restful nights.",
            estimatedMinutes: 4,
            questionCount: 11,
            icon: "hand.point.up.left",
            category: .physical
        ),

        // MARK: - Lifestyle

        QuestionnaireValidationInfo(
            id: "expansion_medas",
            fullName: "Mediterranean Diet Adherence Screener",
            abbreviation: "MEDAS",
            originalAuthors: "PREDIMED Study Group",
            originalYear: 2011,
            originalJournal: "Journal of Nutrition",
            validationStudiesCount: "1,500+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: nil,
            purpose: "Assesses your dietary patterns and their potential impact on sleep quality",
            whyWeAsk: "What you eat affects how you sleep. The Mediterranean diet has been linked to better sleep quality in numerous studies.",
            estimatedMinutes: 4,
            questionCount: 14,
            icon: "leaf",
            category: .lifestyle
        ),

        // MARK: - Chronotype

        QuestionnaireValidationInfo(
            id: "expansion_meq",
            fullName: "Morningness-Eveningness Questionnaire",
            abbreviation: "MEQ",
            originalAuthors: "Horne & Östberg",
            originalYear: 1976,
            originalJournal: "International Journal of Chronobiology",
            validationStudiesCount: "4,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.82",
            purpose: "Determines your natural chronotype—whether you're naturally a morning person or night owl",
            whyWeAsk: "Working with your body's natural rhythm, rather than against it, is key to sustainable sleep improvement. This helps us personalize timing recommendations.",
            estimatedMinutes: 7,
            questionCount: 19,
            icon: "clock.arrow.2.circlepath",
            category: .chronotype
        ),

        // MARK: - Shift Work Disorder

        QuestionnaireValidationInfo(
            id: "expansion_swdsq",
            fullName: "Shift Work Disorder Screening Questionnaire",
            abbreviation: "SWDSQ",
            originalAuthors: "Barger et al.",
            originalYear: 2012,
            originalJournal: "Sleep Medicine",
            validationStudiesCount: "500+",
            sensitivity: "89%",
            specificity: "76%",
            cronbachAlpha: "0.78",
            purpose: "Screens for Shift Work Disorder—a circadian rhythm sleep disorder caused by work schedules that conflict with your natural sleep-wake cycle",
            whyWeAsk: "Working shifts or irregular hours creates unique sleep challenges. This helps us understand if your work schedule is contributing to your sleep difficulties and customize your treatment plan accordingly.",
            estimatedMinutes: 3,
            questionCount: 4,
            icon: "clock.badge.exclamationmark",
            category: .occupational
        )
    ]

    /// Get validation info for a specific module ID
    static func info(for moduleId: String) -> QuestionnaireValidationInfo? {
        // Handle part1/part2 suffixes by matching base module ID
        let baseId = moduleId
            .replacingOccurrences(of: "_part1", with: "")
            .replacingOccurrences(of: "_part2", with: "")

        return all.first { $0.id == baseId }
    }

    /// Get validation info for multiple module IDs (for combined splash screens)
    static func infos(for moduleIds: [String]) -> [QuestionnaireValidationInfo] {
        let uniqueBaseIds = Set(moduleIds.map { moduleId in
            moduleId
                .replacingOccurrences(of: "_part1", with: "")
                .replacingOccurrences(of: "_part2", with: "")
        })

        return uniqueBaseIds.compactMap { baseId in
            all.first { $0.id == baseId }
        }
    }
}
