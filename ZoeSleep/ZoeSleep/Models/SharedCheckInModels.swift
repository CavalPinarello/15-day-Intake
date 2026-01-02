//
//  SharedCheckInModels.swift
//  ZoeSleep
//
//  UI extensions for the Watch-style check-in enums.
//  The base enums (EnergyLevel, MoodLevel, FocusLevel, CheckInTimeSlot) are defined
//  in CheckInManager.swift. This file adds UI properties like colors, gradients, icons.
//

import SwiftUI

// MARK: - Intensity Selectable Protocol

/// Protocol for types that can be selected via intensity scale
protocol IntensitySelectable: CaseIterable, Equatable {
    var intensityIndex: Int { get }
    var label: String { get }
    var sfSymbol: String { get }
    var color: Color { get }
    var gradientColors: [Color] { get }

    static var allOptions: [Self] { get }
    static func fromIntensityIndex(_ index: Int) -> Self?
}

extension IntensitySelectable where Self: RawRepresentable, Self.RawValue == Int {
    var intensityIndex: Int { rawValue }

    static var allOptions: [Self] {
        Array(allCases)
    }

    static func fromIntensityIndex(_ index: Int) -> Self? {
        Self(rawValue: index)
    }
}

// MARK: - EnergyLevel UI Extensions

extension EnergyLevel: Identifiable {
    var id: Int { rawValue }

    /// Display label for the energy level
    var label: String {
        switch self {
        case .sleepingSeal: return "Exhausted"
        case .turtle: return "Slow"
        case .cat: return "Okay"
        case .dog: return "Good"
        case .ostrich: return "High"
        case .rabbit: return "Energized!"
        }
    }

    /// Short label for compact display
    var shortLabel: String {
        switch self {
        case .sleepingSeal: return "Zzz"
        case .turtle: return "Slow"
        case .cat: return "OK"
        case .dog: return "Good"
        case .ostrich: return "High"
        case .rabbit: return "Max!"
        }
    }

    /// SF Symbol name for the icon
    var sfSymbol: String {
        switch self {
        case .sleepingSeal: return "zzz"
        case .turtle: return "tortoise.fill"
        case .cat: return "cat.fill"
        case .dog: return "dog.fill"
        case .ostrich: return "bird.fill"
        case .rabbit: return "hare.fill"
        }
    }

    /// Color representing this energy level (circadian-aware)
    var color: Color {
        let isDark = CircadianPalette.current.isDark
        switch self {
        case .sleepingSeal: return isDark ? Color(red: 0.4, green: 0.4, blue: 0.5) : .gray
        case .turtle: return isDark ? Color(red: 0.5, green: 0.5, blue: 0.4) : Color(red: 0.6, green: 0.5, blue: 0.3)
        case .cat: return isDark ? Color(red: 0.6, green: 0.5, blue: 0.3) : .orange
        case .dog: return isDark ? Color(red: 0.8, green: 0.6, blue: 0.3) : Color(red: 0.3, green: 0.7, blue: 0.4)
        case .ostrich: return isDark ? Color(red: 0.9, green: 0.7, blue: 0.3) : Color(red: 0.2, green: 0.6, blue: 0.8)
        case .rabbit: return isDark ? Color(red: 1.0, green: 0.8, blue: 0.4) : Color(red: 0.3, green: 0.8, blue: 0.5)
        }
    }

    /// Animation speed multiplier (tired animals move slower)
    var animationSpeed: Double {
        switch self {
        case .sleepingSeal: return 0.3
        case .turtle: return 0.5
        case .cat: return 0.8
        case .dog: return 1.0
        case .ostrich: return 1.3
        case .rabbit: return 1.6
        }
    }
}

// MARK: - EnergyLevel IntensitySelectable

extension EnergyLevel: IntensitySelectable {
    var gradientColors: [Color] {
        switch self {
        case .sleepingSeal:
            return [Color(red: 0.08, green: 0.08, blue: 0.15), Color(red: 0.12, green: 0.1, blue: 0.2)]
        case .turtle:
            return [Color(red: 0.12, green: 0.1, blue: 0.2), Color(red: 0.18, green: 0.14, blue: 0.25)]
        case .cat:
            return [Color(red: 0.2, green: 0.16, blue: 0.22), Color(red: 0.28, green: 0.2, blue: 0.22)]
        case .dog:
            return [Color(red: 0.35, green: 0.25, blue: 0.15), Color(red: 0.45, green: 0.3, blue: 0.12)]
        case .ostrich:
            return [Color(red: 0.5, green: 0.35, blue: 0.1), Color(red: 0.65, green: 0.42, blue: 0.08)]
        case .rabbit:
            return [Color(red: 0.65, green: 0.45, blue: 0.05), Color(red: 0.8, green: 0.55, blue: 0.05)]
        }
    }
}

// MARK: - MoodLevel UI Extensions

extension MoodLevel: Identifiable {
    var id: Int { rawValue }

    /// Display label for the mood level
    var label: String {
        switch self {
        case .stormy: return "Stormy"
        case .rainy: return "Rainy"
        case .cloudy: return "Cloudy"
        case .partlySunny: return "Clearing"
        case .sunny: return "Sunny"
        case .rainbow: return "Rainbow"
        }
    }

    /// SF Symbol name for the weather icon
    var sfSymbol: String {
        switch self {
        case .stormy: return "cloud.bolt.fill"
        case .rainy: return "cloud.rain.fill"
        case .cloudy: return "cloud.fill"
        case .partlySunny: return "cloud.sun.fill"
        case .sunny: return "sun.max.fill"
        case .rainbow: return "rainbow"
        }
    }

    /// Color representing this mood level (circadian-aware)
    var color: Color {
        let isDark = CircadianPalette.current.isDark
        switch self {
        case .stormy: return isDark ? Color(red: 0.4, green: 0.3, blue: 0.5) : Color(red: 0.3, green: 0.3, blue: 0.5)
        case .rainy: return isDark ? Color(red: 0.4, green: 0.4, blue: 0.6) : Color(red: 0.4, green: 0.5, blue: 0.7)
        case .cloudy: return isDark ? Color(red: 0.5, green: 0.5, blue: 0.5) : .gray
        case .partlySunny: return isDark ? Color(red: 0.7, green: 0.6, blue: 0.4) : Color(red: 0.9, green: 0.7, blue: 0.3)
        case .sunny: return isDark ? Color(red: 0.9, green: 0.7, blue: 0.3) : Color(red: 1.0, green: 0.8, blue: 0.2)
        case .rainbow: return isDark ? Color(red: 0.8, green: 0.5, blue: 0.7) : Color(red: 0.6, green: 0.4, blue: 0.8)
        }
    }
}

// MARK: - MoodLevel IntensitySelectable

extension MoodLevel: IntensitySelectable {
    var gradientColors: [Color] {
        switch self {
        case .stormy:
            return [Color(red: 0.1, green: 0.1, blue: 0.15), Color(red: 0.12, green: 0.12, blue: 0.2)]
        case .rainy:
            return [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.16, green: 0.18, blue: 0.28)]
        case .cloudy:
            return [Color(red: 0.18, green: 0.18, blue: 0.22), Color(red: 0.24, green: 0.22, blue: 0.26)]
        case .partlySunny:
            return [Color(red: 0.32, green: 0.28, blue: 0.18), Color(red: 0.42, green: 0.35, blue: 0.15)]
        case .sunny:
            return [Color(red: 0.55, green: 0.42, blue: 0.1), Color(red: 0.7, green: 0.52, blue: 0.08)]
        case .rainbow:
            return [Color(red: 0.55, green: 0.35, blue: 0.4), Color(red: 0.7, green: 0.42, blue: 0.45)]
        }
    }
}

// MARK: - FocusLevel UI Extensions (5 levels to match Watch)

extension FocusLevel: Identifiable {
    var id: Int { rawValue }

    /// Display label for the focus level
    var label: String {
        switch self {
        case .foggy: return "Foggy"
        case .hazy: return "Hazy"
        case .clearing: return "Clearing"
        case .clear: return "Clear"
        case .crystal: return "Crystal"
        }
    }

    /// SF Symbol name for the focus icon
    var sfSymbol: String {
        switch self {
        case .foggy: return "cloud.fog.fill"
        case .hazy: return "smoke.fill"
        case .clearing: return "sun.haze.fill"
        case .clear: return "eye.fill"
        case .crystal: return "sparkles"
        }
    }

    /// Color representing this focus level (circadian-aware)
    var color: Color {
        let isDark = CircadianPalette.current.isDark
        switch self {
        case .foggy: return isDark ? Color(red: 0.4, green: 0.4, blue: 0.4) : .gray
        case .hazy: return isDark ? Color(red: 0.5, green: 0.5, blue: 0.5) : Color(red: 0.6, green: 0.6, blue: 0.6)
        case .clearing: return isDark ? Color(red: 0.6, green: 0.6, blue: 0.5) : Color(red: 0.7, green: 0.7, blue: 0.5)
        case .clear: return isDark ? Color(red: 0.7, green: 0.7, blue: 0.5) : Color(red: 0.3, green: 0.6, blue: 0.9)
        case .crystal: return isDark ? Color(red: 0.9, green: 0.8, blue: 0.5) : Color(red: 0.4, green: 0.8, blue: 1.0)
        }
    }

    /// Blur radius for visual effect (higher = more blurred)
    var blurRadius: CGFloat {
        switch self {
        case .foggy: return 10
        case .hazy: return 6
        case .clearing: return 3
        case .clear: return 1
        case .crystal: return 0
        }
    }
}

// MARK: - FocusLevel IntensitySelectable

extension FocusLevel: IntensitySelectable {
    var gradientColors: [Color] {
        switch self {
        case .foggy:
            return [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.15, green: 0.15, blue: 0.18)]
        case .hazy:
            return [Color(red: 0.14, green: 0.16, blue: 0.2), Color(red: 0.18, green: 0.2, blue: 0.25)]
        case .clearing:
            return [Color(red: 0.12, green: 0.2, blue: 0.28), Color(red: 0.15, green: 0.28, blue: 0.35)]
        case .clear:
            return [Color(red: 0.08, green: 0.28, blue: 0.38), Color(red: 0.1, green: 0.38, blue: 0.48)]
        case .crystal:
            return [Color(red: 0.05, green: 0.38, blue: 0.5), Color(red: 0.08, green: 0.5, blue: 0.6)]
        }
    }
}

// MARK: - CheckInTimeSlot UI Extensions

extension CheckInTimeSlot: Identifiable {
    var id: String { rawValue }

    /// Display label
    var label: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .evening: return "Evening"
        }
    }

    /// SF Symbol for the check-in type
    var sfSymbol: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }

    /// Time window description
    var timeWindow: String {
        switch self {
        case .morning: return "5 AM - 12 PM"
        case .midday: return "12 PM - 6 PM"
        case .evening: return "6 PM - 12 AM"
        }
    }

    /// Color for the check-in type (circadian-aware)
    var color: Color {
        let isDark = CircadianPalette.current.isDark
        switch self {
        case .morning: return isDark ? Color(red: 0.9, green: 0.7, blue: 0.4) : Color(red: 1.0, green: 0.8, blue: 0.3)
        case .midday: return isDark ? Color(red: 0.8, green: 0.7, blue: 0.4) : Color(red: 0.3, green: 0.7, blue: 0.9)
        case .evening: return isDark ? Color(red: 0.8, green: 0.5, blue: 0.3) : Color(red: 0.9, green: 0.5, blue: 0.3)
        }
    }

    /// Determine current time slot based on hour
    static var current: CheckInTimeSlot? {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<18: return .midday
        case 18..<24: return .evening
        default: return nil // 0-5 AM is not a check-in window
        }
    }

    /// Check if this time slot is currently active
    var isActive: Bool {
        Self.current == self
    }
}

// MARK: - Check-In Data Structures

/// Complete check-in data structure
struct WatchStyleCheckIn: Codable {
    let date: String           // YYYY-MM-DD
    let timeSlot: CheckInTimeSlot
    let energyLevel: Int       // 1-6
    let moodLevel: Int         // 1-6
    let focusLevel: Int        // 1-5 (matches Watch)
    let completedAt: Date
    let source: String         // "ios" or "watch"

    var energy: EnergyLevel? {
        EnergyLevel(rawValue: energyLevel)
    }

    var mood: MoodLevel? {
        MoodLevel(rawValue: moodLevel)
    }

    var focus: FocusLevel? {
        FocusLevel(rawValue: focusLevel)
    }
}

/// Check-in status for today (synced between iPhone and Watch)
struct WatchStyleCheckInStatus: Codable {
    let morningDone: Bool
    let middayDone: Bool
    let eveningDone: Bool
    let totalDone: Int
    let recommendedNext: String?
    let lastEnergyLevel: Int?
    let lastMoodLevel: Int?
    let lastFocusLevel: Int?

    var completedCount: Int {
        totalDone
    }

    var allDone: Bool {
        morningDone && middayDone && eveningDone
    }

    var recommendedCheckInType: CheckInTimeSlot? {
        guard let next = recommendedNext else { return nil }
        return CheckInTimeSlot(rawValue: next)
    }

    /// Empty status for initialization
    static var empty: WatchStyleCheckInStatus {
        WatchStyleCheckInStatus(
            morningDone: false,
            middayDone: false,
            eveningDone: false,
            totalDone: 0,
            recommendedNext: CheckInTimeSlot.current?.rawValue,
            lastEnergyLevel: nil,
            lastMoodLevel: nil,
            lastFocusLevel: nil
        )
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension EnergyLevel {
    static var preview: EnergyLevel { .dog }
}

extension MoodLevel {
    static var preview: MoodLevel { .sunny }
}

extension FocusLevel {
    static var preview: FocusLevel { .clear }
}
#endif
