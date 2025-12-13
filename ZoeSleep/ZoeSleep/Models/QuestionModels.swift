//
//  QuestionModels.swift
//  Zoe Sleep for Longevity System
//
//  Data models for the 15-day adaptive questionnaire system
//

import Foundation
import SwiftUI

// MARK: - Time Period Enum

enum TimePeriod: Equatable {
    case morning    // After dawn until noon: Bright, energetic
    case afternoon  // Noon until dusk start: Transitioning warmth
    case evening    // Dusk start until night: Full sunset warmth (NO blue light!)
    case night      // Night until dawn: Deep, calming (NO blue light!)

    /// Returns current time period using SEASONAL sunrise/sunset calculation
    /// MUST match CircadianPalette.current logic for consistency!
    static var current: TimePeriod {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 180

        // Seasonal sunrise/sunset calculation (SAME as CircadianPalette!)
        let seasonalOffset = sin(Double(dayOfYear - 80) / 365.0 * .pi * 2)
        let sunriseHour = 6.5 - seasonalOffset * 1.0   // 5:30 to 7:30 AM depending on season
        let sunsetHour = 18.5 + seasonalOffset * 2.0   // 4:30 to 8:30 PM depending on season

        let currentHour = Double(hour) + Double(minute) / 60.0

        // Time boundaries (SAME as CircadianPalette!)
        let dawnStart = sunriseHour - 0.5
        let dawnEnd = sunriseHour + 1.5
        let duskStart = sunsetHour - 1.5  // Evening starts 1.5 hours before sunset

        // Determine period
        if currentHour >= duskStart || currentHour < dawnStart {
            // After dusk or before dawn = evening/night (warm colors only!)
            if currentHour >= duskStart && currentHour < sunsetHour + 2 {
                return .evening
            } else {
                return .night
            }
        } else if currentHour >= dawnStart && currentHour < dawnEnd {
            return .morning  // Dawn transition
        } else if currentHour >= dawnEnd && currentHour < 12 {
            return .morning
        } else {
            return .afternoon  // Noon until dusk start
        }
    }
}

// MARK: - Color Theme

struct ColorTheme {

    // MARK: - Singleton with Time Awareness (for circadian mode)

    static var shared: ColorTheme {
        ColorTheme(period: TimePeriod.current)
    }

    let period: TimePeriod?
    let accentColorOption: ThemeManager.AccentColorOption?

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

    // MARK: - Primary Colors (Sleep-Optimized)
    // CRITICAL: NO blue/teal/purple at night - only warm amber/orange for sleep health

    /// Main accent color - changes with time of day (circadian) or user selection
    var primary: Color {
        if let accent = accentColorOption {
            return accent.color
        }
        guard let period = period else { return ThemeManager.AccentColorOption.teal.color }
        switch period {
        case .morning:
            return Color(hex: "#0EA5E9")!  // Sky blue - energetic morning (OK)
        case .afternoon:
            return Color(hex: "#F59E0B")!  // Amber - warm afternoon
        case .evening:
            return Color(hex: "#F28C40")!  // Bright amber/orange - NO BLUE
        case .night:
            return Color(hex: "#F28C40")!  // Warm amber - NO PURPLE/BLUE (sleep-safe)
        }
    }

    /// Secondary accent for subtle elements
    var secondary: Color {
        if let accent = accentColorOption {
            return accent.color.opacity(0.7)
        }
        guard let period = period else { return ThemeManager.AccentColorOption.teal.color.opacity(0.7) }
        switch period {
        case .morning:
            return Color(hex: "#38BDF8")!  // Light sky blue (OK for morning)
        case .afternoon:
            return Color(hex: "#FBBF24")!  // Golden amber
        case .evening:
            return Color(hex: "#D97706")!  // Deep amber - NO BLUE
        case .night:
            return Color(hex: "#D97706")!  // Deep amber - NO LAVENDER (sleep-safe)
        }
    }

    /// Tertiary color for accents and highlights
    var tertiary: Color {
        if let accent = accentColorOption {
            return accent.color.opacity(0.5)
        }
        guard let period = period else { return ThemeManager.AccentColorOption.teal.color.opacity(0.5) }
        switch period {
        case .morning:
            return Color(hex: "#06B6D4")!  // Cyan (OK for morning)
        case .afternoon:
            return Color(hex: "#D97706")!  // Deep amber
        case .evening:
            return Color(hex: "#B45309")!  // Burnt orange - NO RED with blue
        case .night:
            return Color(hex: "#B45309")!  // Burnt orange - NO VIOLET (sleep-safe)
        }
    }

    // MARK: - Background Colors (Sleep-Optimized)

    /// Subtle background tint
    var backgroundTint: Color {
        if let accent = accentColorOption {
            return accent.color.opacity(0.08)
        }
        guard let period = period else { return ThemeManager.AccentColorOption.teal.color.opacity(0.08) }
        switch period {
        case .morning:
            return Color(hex: "#0EA5E9")!.opacity(0.08)  // Light blue tint (OK for morning)
        case .afternoon:
            return Color(hex: "#F59E0B")!.opacity(0.08)  // Amber tint
        case .evening:
            return Color(hex: "#F28C40")!.opacity(0.12)  // Warm amber tint - NO BLUE
        case .night:
            return Color(hex: "#F28C40")!.opacity(0.12)  // Warm amber tint - NO PURPLE (sleep-safe)
        }
    }

    /// Card background with time-based warmth
    /// CIRCADIAN: Cards should blend with background, not be stark white
    var cardBackground: Color {
        if accentColorOption != nil {
            return Color(.secondarySystemBackground)
        }
        guard let period = period else { return Color(.secondarySystemBackground) }
        switch period {
        case .morning:
            // Soft translucent white-blue that blends with morning sky background
            return Color.white.opacity(0.75)
        case .afternoon:
            // Warm translucent cream
            return Color(red: 1.0, green: 0.99, blue: 0.95).opacity(0.80)
        case .evening:
            // Warm dark card - blends with brown background
            return Color(red: 0.22, green: 0.14, blue: 0.10).opacity(0.85)
        case .night:
            // Deep warm card - very dark but warm
            return Color(red: 0.18, green: 0.11, blue: 0.08).opacity(0.90)
        }
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

    // MARK: - Text Colors (Sleep-Optimized for dark evening backgrounds)
    // CRITICAL: Must be HIGH CONTRAST on dark brown backgrounds in evening/night!
    // ALWAYS use current time period for text colors - even with custom accent colors!

    /// Get current period - uses stored period or falls back to current time
    private var effectivePeriod: TimePeriod {
        period ?? TimePeriod.current
    }

    var textPrimary: Color {
        switch effectivePeriod {
        case .morning, .afternoon:
            return Color.primary  // System default
        case .evening, .night:
            // Bright warm cream - HIGH CONTRAST on dark brown (#FEF3C7)
            return Color(red: 0.996, green: 0.953, blue: 0.780)
        }
    }

    var textSecondary: Color {
        switch effectivePeriod {
        case .morning, .afternoon:
            return Color.secondary  // System default
        case .evening, .night:
            // Golden yellow - VISIBLE on dark brown (#FCD34D)
            return Color(red: 0.988, green: 0.827, blue: 0.302)
        }
    }

    /// Muted text for hints, timestamps, etc.
    var textMuted: Color {
        switch effectivePeriod {
        case .morning, .afternoon:
            return Color.secondary.opacity(0.7)
        case .evening, .night:
            // Amber - still visible on dark brown (#F59E0B)
            return Color(red: 0.961, green: 0.620, blue: 0.043)
        }
    }

    var textOnPrimary: Color {
        switch effectivePeriod {
        case .morning, .afternoon:
            return .white
        case .evening, .night:
            return Color(red: 0.15, green: 0.10, blue: 0.08)  // Dark brown on amber buttons
        }
    }

    // MARK: - Card Text Colors (CIRCADIAN-AWARE for high contrast)
    // Morning/Afternoon: Dark text on light cards
    // Evening/Night: Warm cream/amber text on dark cards
    // ALWAYS uses effectivePeriod to ensure time-aware colors even with custom accents!

    /// Primary text ON cards - circadian-aware for contrast
    var textOnCard: Color {
        switch effectivePeriod {
        case .morning, .afternoon:
            return Color(red: 0.15, green: 0.10, blue: 0.08)  // Dark brown on light cards
        case .evening, .night:
            // Bright warm cream - high contrast on dark cards
            return Color(red: 0.996, green: 0.953, blue: 0.780)  // #FEF3C7
        }
    }

    /// Secondary text ON cards - circadian-aware
    var textOnCardSecondary: Color {
        switch effectivePeriod {
        case .morning, .afternoon:
            return Color(red: 0.35, green: 0.25, blue: 0.20)  // Medium brown on light cards
        case .evening, .night:
            // Golden amber - visible on dark cards
            return Color(red: 0.988, green: 0.827, blue: 0.302)  // #FCD34D
        }
    }

    /// Muted text ON cards - circadian-aware
    var textOnCardMuted: Color {
        switch effectivePeriod {
        case .morning, .afternoon:
            return Color(red: 0.50, green: 0.40, blue: 0.35)  // Light brown on light cards
        case .evening, .night:
            // Warm amber - still visible on dark cards
            return Color(red: 0.961, green: 0.620, blue: 0.043)  // #F59E0B
        }
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
    let answeredAt: Date
    var answeredInSeconds: Int?

    init(
        id: UUID = UUID(),
        questionId: String,
        dayNumber: Int,
        stringValue: String? = nil,
        numberValue: Double? = nil,
        arrayValue: [String]? = nil,
        objectValue: [String: String]? = nil,
        answeredAt: Date = Date(),
        answeredInSeconds: Int? = nil
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
