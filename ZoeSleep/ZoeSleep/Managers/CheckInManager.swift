//
//  CheckInManager.swift
//  ZoeSleep
//
//  Manages check-in state across the app.
//  Tracks morning, midday, and evening check-in completion status.
//  Supports both traditional check-ins and Watch-style Energy/Mood/Focus check-ins.
//
//  Usage:
//  - Call loadTodayStatus() on app launch to sync with server
//  - Use completion status to show/hide check-in prompts
//  - Submit check-ins through this manager for centralized tracking
//

import Foundation
import SwiftUI

// MARK: - Check-In Level Types (iOS versions for Watch sync)
// These mirror the Watch app's types for unified Energy/Mood/Focus tracking

enum EnergyLevel: Int, CaseIterable, Codable {
    case sleepingSeal = 1  // Exhausted
    case turtle = 2        // Low energy
    case cat = 3           // Moderate
    case dog = 4           // Good energy
    case ostrich = 5       // High energy
    case rabbit = 6        // Bouncing with energy!
}

enum MoodLevel: Int, CaseIterable, Codable {
    case stormy = 1        // Terrible mood
    case rainy = 2         // Down/sad
    case cloudy = 3        // Meh/neutral
    case partlySunny = 4   // Okay (matches Watch: partlySunny)
    case sunny = 5         // Good mood
    case rainbow = 6       // Amazing!
}

enum FocusLevel: Int, CaseIterable, Codable {
    case foggy = 1         // Can't concentrate
    case hazy = 2          // Distracted
    case clearing = 3      // Getting there
    case clear = 4         // Focused
    case crystal = 5       // Crystal clear focus (matches Watch: 5 levels)
}

enum CheckInTimeSlot: String, CaseIterable, Codable {
    case morning
    case midday
    case evening
}

@MainActor
class CheckInManager: ObservableObject {
    static let shared = CheckInManager()

    // MARK: - Published State

    @Published var morningCompleted: Bool = false
    @Published var middayCompleted: Bool = false
    @Published var eveningCompleted: Bool = false

    @Published var morningCompletedAt: Date?
    @Published var middayCompletedAt: Date?
    @Published var eveningCompletedAt: Date?

    @Published var isLoading: Bool = false
    @Published var lastSyncTime: Date?
    @Published var errorMessage: String?

    // MARK: - Watch-Style Check-In State (PAUSED - Watch integration)

    /// Last sync source - "ios", "watch", or nil
    @Published var lastSyncSource: String?

    /// Last energy level recorded (for trend display) - Int value 1-6
    @Published var lastEnergyLevel: Int?

    /// Last mood level recorded - Int value 1-6
    @Published var lastMoodLevel: Int?

    /// Last focus level recorded - Int value 1-6
    @Published var lastFocusLevel: Int?

    // MARK: - Aliases for Widget Compatibility

    var morningCheckInCompleted: Bool { morningCompleted }
    var middayCheckInCompleted: Bool { middayCompleted }
    var eveningCheckInCompleted: Bool { eveningCompleted }

    // MARK: - Computed Properties

    var allCheckInsComplete: Bool {
        morningCompleted && middayCompleted && eveningCompleted
    }

    var completedCount: Int {
        [morningCompleted, middayCompleted, eveningCompleted].filter { $0 }.count
    }

    var nextPendingCheckIn: CheckInType? {
        let hour = Calendar.current.component(.hour, from: Date())

        // Morning: 5 AM - 11 AM
        if !morningCompleted && hour >= 5 && hour < 11 {
            return .morning
        }
        // Midday: 12 PM - 5 PM
        if !middayCompleted && hour >= 12 && hour < 17 {
            return .midday
        }
        // Evening: 7 PM - 11 PM
        if !eveningCompleted && hour >= 19 && hour < 23 {
            return .evening
        }

        // Return first incomplete if outside time windows
        if !morningCompleted { return .morning }
        if !middayCompleted { return .midday }
        if !eveningCompleted { return .evening }

        return nil
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Load Status

    func loadTodayStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            let status = try await ConvexService.shared.getTodayCheckInStatus()

            morningCompleted = status.morning.completed
            middayCompleted = status.midday.completed
            eveningCompleted = status.evening.completed

            if let morningAt = status.morning.completedAt {
                morningCompletedAt = Date(timeIntervalSince1970: morningAt / 1000)
            }
            if let middayAt = status.midday.completedAt {
                middayCompletedAt = Date(timeIntervalSince1970: middayAt / 1000)
            }
            if let eveningAt = status.evening.completedAt {
                eveningCompletedAt = Date(timeIntervalSince1970: eveningAt / 1000)
            }

            lastSyncTime = Date()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load check-in status"
            print("[CheckInManager] Error loading status: \(error)")
        }
    }

    // MARK: - Submit Check-Ins

    func submitMorningCheckIn(
        sleepQuality: Int,
        energyLevel: Int,
        mood: Int
    ) async throws {
        try await ConvexService.shared.submitMorningCheckIn(
            sleepQuality: sleepQuality,
            energyLevel: energyLevel,
            mood: mood
        )

        morningCompleted = true
        morningCompletedAt = Date()
    }

    func submitMiddayCheckIn(
        energyLevel: Int,
        caffeineCups: Int,
        caffeineLastTime: String?,
        napTaken: Bool,
        napDurationMins: Int?
    ) async throws {
        try await ConvexService.shared.submitMiddayCheckIn(
            energyLevel: energyLevel,
            caffeineCups: caffeineCups,
            caffeineLastTime: caffeineLastTime,
            napTaken: napTaken,
            napDurationMins: napDurationMins
        )

        middayCompleted = true
        middayCompletedAt = Date()
    }

    func submitEveningCheckIn(
        overallDayRating: Int,
        reflectionText: String?,
        tasksMissedReasons: String?
    ) async throws {
        try await ConvexService.shared.submitEveningCheckIn(
            overallDayRating: overallDayRating,
            reflectionText: reflectionText,
            tasksMissedReasons: tasksMissedReasons
        )

        eveningCompleted = true
        eveningCompletedAt = Date()
    }

    // MARK: - Watch-Style Check-In Submission

    /// Submit a Watch-style check-in with Energy, Mood, and Focus levels.
    /// This uses the unified Energy/Mood/Focus model that syncs with Apple Watch.
    func submitWatchStyleCheckIn(
        timeSlot: CheckInTimeSlot,
        energy: EnergyLevel,
        mood: MoodLevel,
        focus: FocusLevel
    ) async {
        // Optimistically update local state immediately for responsive UI
        let completedAt = Date()
        switch timeSlot {
        case .morning:
            morningCompleted = true
            morningCompletedAt = completedAt
        case .midday:
            middayCompleted = true
            middayCompletedAt = completedAt
        case .evening:
            eveningCompleted = true
            eveningCompletedAt = completedAt
        }

        // Update last values immediately
        lastEnergyLevel = energy.rawValue
        lastMoodLevel = mood.rawValue
        lastFocusLevel = focus.rawValue
        lastSyncSource = "ios"
        lastSyncTime = completedAt

        do {
            // Map time slot to appropriate Convex mutation
            switch timeSlot {
            case .morning:
                try await ConvexService.shared.submitMorningCheckIn(
                    sleepQuality: 0, // Not tracked in Watch-style
                    energyLevel: energy.rawValue,
                    mood: mood.rawValue,
                    focusLevel: focus.rawValue
                )

            case .midday:
                try await ConvexService.shared.submitMiddayCheckIn(
                    energyLevel: energy.rawValue,
                    caffeineCups: 0, // Not tracked in Watch-style
                    caffeineLastTime: nil,
                    napTaken: false,
                    napDurationMins: nil,
                    moodLevel: mood.rawValue,
                    focusLevel: focus.rawValue
                )

            case .evening:
                try await ConvexService.shared.submitEveningCheckIn(
                    overallDayRating: 0, // Not tracked in Watch-style
                    reflectionText: nil,
                    tasksMissedReasons: nil,
                    energyLevel: energy.rawValue,
                    moodLevel: mood.rawValue,
                    focusLevel: focus.rawValue
                )
            }

            // Notify Watch that iPhone completed a check-in (if Watch is connected)
            iOSWatchConnectivityManager.shared.notifyWatchCheckInCompleted(
                timeSlot: timeSlot,
                date: formattedDate(Date())
            )

        } catch {
            // Revert optimistic update on error
            switch timeSlot {
            case .morning:
                morningCompleted = false
                morningCompletedAt = nil
            case .midday:
                middayCompleted = false
                middayCompletedAt = nil
            case .evening:
                eveningCompleted = false
                eveningCompletedAt = nil
            }
            errorMessage = "Failed to submit check-in"
            print("[CheckInManager] Error submitting Watch-style check-in: \(error)")
        }
    }

    /// Handle notification from Watch that a check-in was completed
    func handleWatchCheckInCompletion(timeSlot: CheckInTimeSlot, date: String) {
        // Only update if it's for today
        guard date == formattedDate(Date()) else { return }

        switch timeSlot {
        case .morning:
            morningCompleted = true
            morningCompletedAt = Date()
        case .midday:
            middayCompleted = true
            middayCompletedAt = Date()
        case .evening:
            eveningCompleted = true
            eveningCompletedAt = Date()
        }

        lastSyncSource = "watch"
        lastSyncTime = Date()
    }

    /// Format date as YYYY-MM-DD for sync
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Reset for New Day

    func resetForNewDay() {
        morningCompleted = false
        middayCompleted = false
        eveningCompleted = false
        morningCompletedAt = nil
        middayCompletedAt = nil
        eveningCompletedAt = nil
    }

    // MARK: - Check if Prompt Should Show

    func shouldShowCheckInPrompt(for type: CheckInType) -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())

        switch type {
        case .morning:
            // Morning prompt: 5 AM - 11 AM, not yet completed
            return !morningCompleted && hour >= 5 && hour < 11

        case .midday:
            // Midday prompt: 12 PM - 5 PM, not yet completed
            return !middayCompleted && hour >= 12 && hour < 17

        case .evening:
            // Evening prompt: 7 PM - 11 PM, not yet completed
            return !eveningCompleted && hour >= 19 && hour < 23
        }
    }

    // MARK: - Check-In Prompt Data

    func promptData(for type: CheckInType) -> CheckInPromptData {
        switch type {
        case .morning:
            return CheckInPromptData(
                title: "Morning Check-in",
                subtitle: "How did you sleep?",
                icon: "sun.max.fill",
                color: .orange,
                actionLabel: "Start Check-in"
            )
        case .midday:
            return CheckInPromptData(
                title: "Midday Check-in",
                subtitle: "Track your energy & habits",
                icon: "clock.fill",
                color: .blue,
                actionLabel: "Quick Check-in"
            )
        case .evening:
            return CheckInPromptData(
                title: "Evening Report",
                subtitle: "Review your day",
                icon: "moon.stars.fill",
                color: .indigo,
                actionLabel: "Complete Report"
            )
        }
    }
}

// MARK: - Check-In Types

enum CheckInType: String, CaseIterable {
    case morning
    case midday
    case evening

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .evening: return "Evening"
        }
    }
}

struct CheckInPromptData {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let actionLabel: String
}
