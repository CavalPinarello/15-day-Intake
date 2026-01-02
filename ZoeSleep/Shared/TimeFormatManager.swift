//
//  TimeFormatManager.swift
//  ZoeSleep
//
//  Centralized time format management for 12-hour vs 24-hour display.
//  Reads system settings by default, with optional user override.
//
//  Usage:
//    TimeFormatManager.shared.formatTime(date)        // Format Date
//    TimeFormatManager.shared.formatTimeString("22:00") // Format HH:mm string
//    TimeFormatManager.shared.uses12HourFormat        // Check current mode
//

import Foundation
import SwiftUI

// MARK: - Time Format Preference

enum TimeFormatPreference: String, CaseIterable, Identifiable {
    case system = "system"
    case hour12 = "12hour"
    case hour24 = "24hour"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .hour12: return "12-hour (AM/PM)"
        case .hour24: return "24-hour"
        }
    }
}

// MARK: - Time Format Manager

class TimeFormatManager: ObservableObject {
    static let shared = TimeFormatManager()

    private let preferenceKey = "timeFormatPreference"

    @Published var preference: TimeFormatPreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: preferenceKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: preferenceKey) ?? "system"
        self.preference = TimeFormatPreference(rawValue: saved) ?? .system
    }

    // MARK: - Format Detection

    /// Whether to use 12-hour format (considers user preference + system settings)
    var uses12HourFormat: Bool {
        switch preference {
        case .system:
            return detectSystem12Hour()
        case .hour12:
            return true
        case .hour24:
            return false
        }
    }

    /// Detect system 12/24-hour setting from device locale
    private func detectSystem12Hour() -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        let sample = formatter.string(from: Date())
        // If the formatted time contains AM/PM symbols, it's 12-hour format
        return sample.contains(formatter.amSymbol) || sample.contains(formatter.pmSymbol)
    }

    // MARK: - Formatting Methods

    /// Format a Date for display (respects user preference)
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = uses12HourFormat ? "h:mm a" : "HH:mm"
        return formatter.string(from: date)
    }

    /// Format "HH:mm" storage string for display (respects user preference)
    /// Input: "22:30" (24-hour format from storage)
    /// Output: "10:30 PM" or "22:30" based on preference
    func formatTimeString(_ timeString: String) -> String {
        guard let date = parseStorageTime(timeString) else { return timeString }
        return formatTime(date)
    }

    /// Parse "HH:mm" storage string to Date (today's date with that time)
    func parseStorageTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString)
    }

    /// Convert Date to storage format ("HH:mm")
    /// Always outputs 24-hour format for consistent backend storage
    func toStorageFormat(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Display Helpers

    /// Get the appropriate format string for DateFormatter
    var dateFormatString: String {
        uses12HourFormat ? "h:mm a" : "HH:mm"
    }

    /// Get current format description for display
    var formatDescription: String {
        switch preference {
        case .system:
            let mode = uses12HourFormat ? "12-hour" : "24-hour"
            return "System (\(mode))"
        case .hour12:
            return "12-hour (AM/PM)"
        case .hour24:
            return "24-hour"
        }
    }
}

// MARK: - Convenience Extensions

extension Date {
    /// Format this date using the global time format preference
    var formattedTime: String {
        TimeFormatManager.shared.formatTime(self)
    }
}

extension String {
    /// Format this HH:mm string using the global time format preference
    var formattedTimeDisplay: String {
        TimeFormatManager.shared.formatTimeString(self)
    }
}
