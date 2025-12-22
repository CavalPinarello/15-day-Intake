//
//  CheckInManager.swift
//  ZoeSleep
//
//  Manages check-in state across the app.
//  Tracks morning, midday, and evening check-in completion status.
//
//  Usage:
//  - Call loadTodayStatus() on app launch to sync with server
//  - Use completion status to show/hide check-in prompts
//  - Submit check-ins through this manager for centralized tracking
//

import Foundation
import SwiftUI

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
