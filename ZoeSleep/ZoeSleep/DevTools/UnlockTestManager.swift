//
//  UnlockTestManager.swift
//  ZoeSleep
//
//  Manages the Day Unlock Test feature for debugging 4 AM unlock mechanism
//  - Simulates timestamps to test server-side unlock logic
//  - Provides live countdown and status updates
//  - Auto-advances on successful unlock
//

import Foundation
import SwiftUI

@MainActor
class UnlockTestManager: ObservableObject {
    static let shared = UnlockTestManager()

    // MARK: - Published State

    @Published var isTestRunning = false
    @Published var currentTestSecond: Int = 0  // 0-10
    @Published var testResults: [UnlockTestResult] = []
    @Published var testOutcome: TestOutcome?
    @Published var error: String?
    @Published var isAdvancing = false

    // Status info from last check
    @Published var dayReadyAt: Date?
    @Published var unlockTime: Date?
    @Published var sleepLogCompleted = false
    @Published var assessmentCompleted = false
    @Published var currentDay = 1

    // MARK: - Types

    struct UnlockTestResult: Identifiable {
        let id = UUID()
        let second: Int
        let timestamp: Date
        let isUnlocked: Bool
        let formattedTime: String
    }

    enum TestOutcome {
        case success(unlockedAtSecond: Int, advancedToDay: Int)
        case failure(reason: String)
        case alreadyUnlocked
        case notReady(reason: String)
        case cancelled
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Computed Properties

    /// Whether the day is ready for unlock testing (both sections complete)
    var isReadyForTest: Bool {
        sleepLogCompleted && assessmentCompleted
    }

    /// Formatted day ready at time
    var formattedDayReadyAt: String {
        guard let dayReadyAt = dayReadyAt else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dayReadyAt)
    }

    /// Formatted unlock time
    var formattedUnlockTime: String {
        guard let unlockTime = unlockTime else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: unlockTime)
    }

    /// Time remaining until natural unlock
    var timeUntilNaturalUnlock: String? {
        guard let unlockTime = unlockTime else { return nil }
        let now = Date()
        if now >= unlockTime {
            return "Already unlocked"
        }
        let interval = unlockTime.timeIntervalSince(now)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Description of test scenario
    var testScenarioDescription: String {
        guard let unlockTime = unlockTime else { return "Complete day first" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm:ss a"

        let testStart = unlockTime.addingTimeInterval(-10)
        return "Simulates \(formatter.string(from: testStart)) → \(formatter.string(from: unlockTime))"
    }

    // MARK: - Public API

    /// Refresh status from server
    func refreshStatus() async {
        do {
            // Don't bypass time check - we want to see the actual unlock status
            let response = try await ConvexService.shared.canAdvanceDay(debugMode: true, bypassTimeCheck: false)
            sleepLogCompleted = response.sleepLogCompleted
            assessmentCompleted = response.assessmentCompleted
            currentDay = response.currentDay ?? 1

            if let dayReadyAtMs = response.dayReadyAt {
                dayReadyAt = Date(timeIntervalSince1970: dayReadyAtMs / 1000)
            } else {
                dayReadyAt = nil
            }

            if let unlockTimeMs = response.unlockTime {
                unlockTime = Date(timeIntervalSince1970: unlockTimeMs / 1000)
            } else {
                unlockTime = nil
            }

            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Start the unlock test sequence
    func startTest() async {
        guard isReadyForTest else {
            testOutcome = .notReady(reason: "Complete sleep log and assessment first")
            return
        }

        guard let unlockTime = unlockTime else {
            testOutcome = .notReady(reason: "No unlock time calculated")
            return
        }

        // Check if already unlocked
        let now = Date()
        if now >= unlockTime {
            testOutcome = .alreadyUnlocked
            return
        }

        // Reset state
        isTestRunning = true
        currentTestSecond = 0
        testResults = []
        testOutcome = nil
        error = nil

        // Calculate test timestamps (10 seconds before unlock to unlock time)
        let testStartTime = unlockTime.addingTimeInterval(-10)

        // Run the 11-second test (0-10 inclusive)
        for second in 0...10 {
            guard isTestRunning else {
                testOutcome = .cancelled
                break
            }

            currentTestSecond = second
            let testTime = testStartTime.addingTimeInterval(Double(second))
            let testTimestamp = testTime.timeIntervalSince1970 * 1000 // Convert to milliseconds

            do {
                // Test with simulated timestamp, NO bypass - tests actual 4 AM logic
                let response = try await ConvexService.shared.canAdvanceDay(debugMode: true, bypassTimeCheck: false, testTimestamp: testTimestamp)

                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm:ss a"

                let result = UnlockTestResult(
                    second: second,
                    timestamp: testTime,
                    isUnlocked: response.timeUnlocked,
                    formattedTime: formatter.string(from: testTime)
                )
                testResults.append(result)

                // If we just became unlocked, record success
                if response.timeUnlocked {
                    // Auto-advance using the unlock timestamp (NO bypass)
                    isAdvancing = true
                    do {
                        let advanceResponse = try await ConvexService.shared.advanceToNextDay(debugMode: true, bypassTimeCheck: false, testTimestamp: testTimestamp)
                        if advanceResponse.success {
                            testOutcome = .success(unlockedAtSecond: second, advancedToDay: advanceResponse.newDay ?? (currentDay + 1))
                            currentDay = advanceResponse.newDay ?? (currentDay + 1)
                            // Notify main view to refresh journey progress
                            await QuestionnaireManager.shared.loadJourneyProgress()
                            NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)
                        } else {
                            testOutcome = .failure(reason: advanceResponse.error ?? "Failed to advance")
                        }
                    } catch {
                        testOutcome = .failure(reason: error.localizedDescription)
                    }
                    isAdvancing = false
                    isTestRunning = false
                    return
                }

                // Small delay between checks (for visual effect)
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            } catch {
                testOutcome = .failure(reason: error.localizedDescription)
                isTestRunning = false
                return
            }
        }

        // If we got here without unlocking, something is wrong
        if testOutcome == nil {
            testOutcome = .failure(reason: "Unlock did not occur at expected time")
        }

        isTestRunning = false
    }

    /// Cancel the running test
    func cancelTest() {
        isTestRunning = false
        testOutcome = .cancelled
    }

    /// Reset all state
    func reset() {
        isTestRunning = false
        currentTestSecond = 0
        testResults = []
        testOutcome = nil
        error = nil
        isAdvancing = false
    }

    // MARK: - Helpers

    /// Calculate unlock time from day ready timestamp
    static func calculateUnlockTime(dayReadyAt: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: dayReadyAt)
        components.hour = 4
        components.minute = 0
        components.second = 0

        guard let fourAMSameDay = calendar.date(from: components) else {
            return dayReadyAt
        }

        if dayReadyAt < fourAMSameDay {
            // Completed before 4 AM - unlock at 4 AM same day
            return fourAMSameDay
        } else {
            // Completed after 4 AM - unlock at 4 AM next day
            return calendar.date(byAdding: .day, value: 1, to: fourAMSameDay) ?? fourAMSameDay
        }
    }
}
