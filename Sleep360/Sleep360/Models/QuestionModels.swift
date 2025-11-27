//
//  QuestionModels.swift
//  Zoe Sleep for Longevity System
//
//  Data models for the 15-day adaptive questionnaire system
//

import Foundation
import SwiftUI

// MARK: - Time Period Enum

enum TimePeriod {
    case morning    // 5 AM - 12 PM: Bright, energetic
    case afternoon  // 12 PM - 5 PM: Transitioning warmth
    case evening    // 5 PM - 9 PM: Full sunset warmth
    case night      // 9 PM - 5 AM: Deep, calming

    static var current: TimePeriod {
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

// MARK: - Color Theme

struct ColorTheme {

    // MARK: - Singleton with Time Awareness

    static var shared: ColorTheme {
        ColorTheme(period: TimePeriod.current)
    }

    let period: TimePeriod

    init(period: TimePeriod = .current) {
        self.period = period
    }

    // MARK: - Primary Colors (Time-Based)

    /// Main accent color - changes with time of day
    var primary: Color {
        switch period {
        case .morning:
            return Color(hex: "#0EA5E9")!  // Sky blue - energetic morning
        case .afternoon:
            return Color(hex: "#F59E0B")!  // Amber - warm afternoon
        case .evening:
            return Color(hex: "#EA580C")!  // Orange - sunset glow
        case .night:
            return Color(hex: "#7C3AED")!  // Purple - calming night
        }
    }

    /// Secondary accent for subtle elements
    var secondary: Color {
        switch period {
        case .morning:
            return Color(hex: "#38BDF8")!  // Light sky blue
        case .afternoon:
            return Color(hex: "#FBBF24")!  // Golden amber
        case .evening:
            return Color(hex: "#FB923C")!  // Warm orange
        case .night:
            return Color(hex: "#A78BFA")!  // Soft lavender
        }
    }

    /// Tertiary color for accents and highlights
    var tertiary: Color {
        switch period {
        case .morning:
            return Color(hex: "#06B6D4")!  // Cyan
        case .afternoon:
            return Color(hex: "#D97706")!  // Deep amber
        case .evening:
            return Color(hex: "#DC2626")!  // Warm red
        case .night:
            return Color(hex: "#8B5CF6")!  // Violet
        }
    }

    // MARK: - Background Colors

    /// Subtle background tint
    var backgroundTint: Color {
        switch period {
        case .morning:
            return Color(hex: "#0EA5E9")!.opacity(0.08)  // Light blue tint
        case .afternoon:
            return Color(hex: "#F59E0B")!.opacity(0.08)  // Amber tint
        case .evening:
            return Color(hex: "#EA580C")!.opacity(0.08)  // Orange tint
        case .night:
            return Color(hex: "#7C3AED")!.opacity(0.08)  // Purple tint
        }
    }

    /// Card background with time-based warmth
    var cardBackground: Color {
        switch period {
        case .morning:
            return Color(hex: "#F0F9FF")!  // Very light blue
        case .afternoon:
            return Color(hex: "#FFFBEB")!  // Warm cream
        case .evening:
            return Color(hex: "#FFF7ED")!  // Warm orange tint
        case .night:
            return Color(hex: "#FAF5FF")!  // Soft purple tint
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

    // MARK: - Text Colors

    var textPrimary: Color {
        Color.primary
    }

    var textSecondary: Color {
        Color.secondary
    }

    var textOnPrimary: Color {
        .white
    }

    // MARK: - Component-Specific Colors

    /// Sleep diary icon
    var sleepDiary: Color {
        switch period {
        case .morning:
            return Color(hex: "#8B5CF6")!  // Purple
        case .afternoon:
            return Color(hex: "#EA580C")!  // Orange
        case .evening:
            return Color(hex: "#DC2626")!  // Warm red
        case .night:
            return Color(hex: "#7C3AED")!  // Deep purple
        }
    }

    /// HealthKit / Heart
    var health: Color {
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

    /// Insights / Charts
    var insights: Color {
        switch period {
        case .morning:
            return Color(hex: "#10B981")!  // Emerald
        case .afternoon:
            return Color(hex: "#059669")!  // Deep emerald
        case .evening:
            return Color(hex: "#047857")!  // Forest green
        case .night:
            return Color(hex: "#34D399")!  // Soft mint
        }
    }

    // MARK: - Phase Colors

    /// Core assessment phase (Days 1-5)
    var corePhase: Color {
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

    /// Primary gradient for headers and accents
    var primaryGradient: LinearGradient {
        switch period {
        case .morning:
            return LinearGradient(
                colors: [Color(hex: "#0EA5E9")!, Color(hex: "#38BDF8")!],
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
                colors: [Color(hex: "#EA580C")!, Color(hex: "#FB923C")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .night:
            return LinearGradient(
                colors: [Color(hex: "#7C3AED")!, Color(hex: "#A78BFA")!],
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

// MARK: - Observable Theme Manager

@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: ColorTheme

    init() {
        self.currentTheme = ColorTheme.shared
    }

    func updateTheme() {
        let newTheme = ColorTheme.shared
        if newTheme.period != currentTheme.period {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentTheme = newTheme
            }
        }
    }
}

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
}
