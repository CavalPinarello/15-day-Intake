//
//  CheckInModels.swift
//  ZoeSleep Watch App
//
//  Models for the minimal check-in system.
//  Energy uses animal icons, Mood uses weather, Focus uses clarity metaphors.
//

import SwiftUI

// MARK: - Energy Level (Animal Icons)

/// Energy level using playful animal metaphors.
/// From exhausted (sleeping seal) to energized (bouncing rabbit).
enum EnergyLevel: Int, CaseIterable, Identifiable, Codable {
    case sleepingSeal = 1  // Exhausted
    case turtle = 2        // Low energy
    case cat = 3           // Moderate
    case dog = 4           // Good energy
    case ostrich = 5       // High energy
    case rabbit = 6        // Bouncing with energy!

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

    /// SF Symbol name for basic icon (fallback)
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
        let palette = WatchCircadianPalette.current
        switch self {
        case .sleepingSeal: return palette.isDark ? Color(red: 0.4, green: 0.4, blue: 0.5) : .gray
        case .turtle: return palette.isDark ? Color(red: 0.5, green: 0.5, blue: 0.4) : Color(red: 0.6, green: 0.5, blue: 0.3)
        case .cat: return palette.isDark ? Color(red: 0.6, green: 0.5, blue: 0.3) : .orange
        case .dog: return palette.isDark ? Color(red: 0.8, green: 0.6, blue: 0.3) : Color(red: 0.3, green: 0.7, blue: 0.4)
        case .ostrich: return palette.isDark ? Color(red: 0.9, green: 0.7, blue: 0.3) : Color(red: 0.2, green: 0.6, blue: 0.8)
        case .rabbit: return palette.isDark ? Color(red: 1.0, green: 0.8, blue: 0.4) : Color(red: 0.3, green: 0.8, blue: 0.5)
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

    /// Breathing animation duration (slower for tired)
    var breathDuration: Double {
        switch self {
        case .sleepingSeal, .turtle: return 3.0
        case .cat: return 2.5
        case .dog: return 2.0
        case .ostrich, .rabbit: return 1.5
        }
    }
}

// MARK: - Mood Level (Weather Icons)

/// Mood level using weather metaphors.
/// From stormy (terrible) to rainbow (amazing).
enum MoodLevel: Int, CaseIterable, Identifiable, Codable {
    case stormy = 1       // Terrible mood
    case rainy = 2        // Down/sad
    case cloudy = 3       // Meh/neutral
    case partlySunny = 4  // Okay
    case sunny = 5        // Good mood
    case rainbow = 6      // Amazing!

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

    /// Color representing this mood level
    var color: Color {
        let palette = WatchCircadianPalette.current
        switch self {
        case .stormy: return palette.isDark ? Color(red: 0.4, green: 0.3, blue: 0.5) : Color(red: 0.3, green: 0.3, blue: 0.5)
        case .rainy: return palette.isDark ? Color(red: 0.4, green: 0.4, blue: 0.6) : Color(red: 0.4, green: 0.5, blue: 0.7)
        case .cloudy: return palette.isDark ? Color(red: 0.5, green: 0.5, blue: 0.5) : .gray
        case .partlySunny: return palette.isDark ? Color(red: 0.7, green: 0.6, blue: 0.4) : Color(red: 0.9, green: 0.7, blue: 0.3)
        case .sunny: return palette.isDark ? Color(red: 0.9, green: 0.7, blue: 0.3) : Color(red: 1.0, green: 0.8, blue: 0.2)
        case .rainbow: return palette.isDark ? Color(red: 0.8, green: 0.5, blue: 0.7) : Color(red: 0.6, green: 0.4, blue: 0.8)
        }
    }

    /// Animation style for weather
    var hasRainAnimation: Bool {
        self == .stormy || self == .rainy
    }

    var hasSunAnimation: Bool {
        self == .sunny || self == .partlySunny
    }
}

// MARK: - Focus Level (Clarity Icons)

/// Focus/clarity level using visual metaphors.
/// From foggy (can't concentrate) to crystal clear (sharp focus).
enum FocusLevel: Int, CaseIterable, Identifiable, Codable {
    case foggy = 1      // Can't concentrate
    case hazy = 2       // Distracted
    case clearing = 3   // Getting there
    case clear = 4      // Focused
    case crystal = 5    // Crystal clear focus

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

    /// Color representing this focus level
    var color: Color {
        let palette = WatchCircadianPalette.current
        switch self {
        case .foggy: return palette.isDark ? Color(red: 0.4, green: 0.4, blue: 0.4) : .gray
        case .hazy: return palette.isDark ? Color(red: 0.5, green: 0.5, blue: 0.5) : Color(red: 0.6, green: 0.6, blue: 0.6)
        case .clearing: return palette.isDark ? Color(red: 0.6, green: 0.6, blue: 0.5) : Color(red: 0.7, green: 0.7, blue: 0.5)
        case .clear: return palette.isDark ? Color(red: 0.7, green: 0.7, blue: 0.5) : Color(red: 0.3, green: 0.6, blue: 0.9)
        case .crystal: return palette.isDark ? Color(red: 0.9, green: 0.8, blue: 0.5) : Color(red: 0.4, green: 0.8, blue: 1.0)
        }
    }

    /// Blur radius for visual effect
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

// MARK: - Check-In Type

/// Type of check-in (morning, midday, or evening)
enum CheckInType: String, CaseIterable, Identifiable, Codable {
    case morning
    case midday
    case evening

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

    /// Color for the check-in type
    var color: Color {
        let palette = WatchCircadianPalette.current
        switch self {
        case .morning: return palette.isDark ? Color(red: 0.9, green: 0.7, blue: 0.4) : Color(red: 1.0, green: 0.8, blue: 0.3)
        case .midday: return palette.isDark ? Color(red: 0.8, green: 0.7, blue: 0.4) : Color(red: 0.3, green: 0.7, blue: 0.9)
        case .evening: return palette.isDark ? Color(red: 0.8, green: 0.5, blue: 0.3) : Color(red: 0.9, green: 0.5, blue: 0.3)
        }
    }
}

// MARK: - Check-In Data

/// Complete check-in data structure
struct WatchCheckIn: Codable {
    let date: String           // YYYY-MM-DD
    let type: CheckInType
    let energyLevel: Int       // 1-6
    let moodLevel: Int         // 1-6
    let focusLevel: Int        // 1-5
    let completedAt: Date

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

/// Check-in status for today
struct WatchCheckInStatus: Codable {
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

    var recommendedCheckInType: CheckInType? {
        guard let next = recommendedNext else { return nil }
        return CheckInType(rawValue: next)
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
