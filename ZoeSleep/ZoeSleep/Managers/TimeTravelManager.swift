//
//  TimeTravelManager.swift
//  ZoeSleep
//
//  Manages Time Travel Mode for streamlined journey testing
//  - Pick a historical start date for Day 1
//  - 5-second lockouts to test day unlocking
//  - Historical timestamps on all data
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TimeTravelManager: ObservableObject {
    static let shared = TimeTravelManager()

    // MARK: - Published State

    @Published var isTimeTravelActive: Bool = false
    @Published var isTestData: Bool = false
    @Published var startedAt: Date = Date()
    @Published var currentDay: Int = 1
    @Published var simulatedDate: Date = Date()
    @Published var secondsUntilUnlock: Int = 0
    @Published var canAdvance: Bool = false
    @Published var isLocked: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Private State

    private var countdownTimer: Timer?
    private var dayUnlocksAt: Date?

    // UserDefaults keys for persistence
    private static let timeTravelActiveKey = "timeTravelActive"
    private static let startedAtKey = "timeTravelStartedAt"
    private static let dayUnlocksAtKey = "timeTravelDayUnlocksAt"
    private static let isTestDataKey = "timeTravelIsTestData"
    private static let currentDayKey = "timeTravelCurrentDay"

    // MARK: - Initialization

    private init() {
        loadPersistedState()
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        isTimeTravelActive = UserDefaults.standard.bool(forKey: Self.timeTravelActiveKey)
        isTestData = UserDefaults.standard.bool(forKey: Self.isTestDataKey)
        currentDay = UserDefaults.standard.integer(forKey: Self.currentDayKey)
        if currentDay == 0 { currentDay = 1 }

        if let startedAtTimestamp = UserDefaults.standard.object(forKey: Self.startedAtKey) as? Double {
            startedAt = Date(timeIntervalSince1970: startedAtTimestamp / 1000)
            updateSimulatedDate()
        }

        if let unlockTimestamp = UserDefaults.standard.object(forKey: Self.dayUnlocksAtKey) as? Double {
            dayUnlocksAt = Date(timeIntervalSince1970: unlockTimestamp / 1000)
            updateCountdown()

            // Start timer if we're in time travel mode with active countdown
            if isTimeTravelActive && secondsUntilUnlock > 0 {
                startCountdownTimer()
            }
        }

        print("[TimeTravel] Loaded persisted state: active=\(isTimeTravelActive), day=\(currentDay), countdown=\(secondsUntilUnlock)s")
    }

    private func persistState() {
        UserDefaults.standard.set(isTimeTravelActive, forKey: Self.timeTravelActiveKey)
        UserDefaults.standard.set(isTestData, forKey: Self.isTestDataKey)
        UserDefaults.standard.set(currentDay, forKey: Self.currentDayKey)
        UserDefaults.standard.set(startedAt.timeIntervalSince1970 * 1000, forKey: Self.startedAtKey)

        if let unlockDate = dayUnlocksAt {
            UserDefaults.standard.set(unlockDate.timeIntervalSince1970 * 1000, forKey: Self.dayUnlocksAtKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.dayUnlocksAtKey)
        }
    }

    private func updateSimulatedDate() {
        // Simulated date = started_at + (currentDay - 1) days
        simulatedDate = Calendar.current.date(byAdding: .day, value: currentDay - 1, to: startedAt) ?? startedAt
    }

    // MARK: - Countdown Timer

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCountdown()
            }
        }
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateCountdown() {
        guard let unlockDate = dayUnlocksAt else {
            secondsUntilUnlock = 0
            canAdvance = false
            isLocked = false
            return
        }

        let remaining = unlockDate.timeIntervalSinceNow
        if remaining <= 0 {
            secondsUntilUnlock = 0
            canAdvance = true
            isLocked = false
            stopCountdownTimer()
        } else {
            secondsUntilUnlock = Int(ceil(remaining))
            canAdvance = false
            isLocked = true
        }
    }

    // MARK: - Public API

    /// Sync state with server (call on app launch and resume)
    func syncWithServer() async {
        guard ConvexService.shared.isAuthenticated else { return }

        do {
            let status = try await ConvexService.shared.getTimeTravelStatus()

            isTimeTravelActive = status.isTimeTravelActive
            isTestData = status.isTestData
            currentDay = status.currentDay
            secondsUntilUnlock = status.secondsUntilUnlock
            canAdvance = status.canAdvance
            isLocked = status.isLocked
            startedAt = Date(timeIntervalSince1970: status.startedAt / 1000)
            simulatedDate = Date(timeIntervalSince1970: status.simulatedDate / 1000)

            if let unlockAt = status.dayUnlocksAt {
                dayUnlocksAt = Date(timeIntervalSince1970: unlockAt / 1000)
            } else {
                dayUnlocksAt = nil
            }

            persistState()

            // Start timer if needed
            if isTimeTravelActive && secondsUntilUnlock > 0 {
                startCountdownTimer()
            } else {
                stopCountdownTimer()
            }

            print("[TimeTravel] Synced with server: active=\(isTimeTravelActive), day=\(currentDay), countdown=\(secondsUntilUnlock)s")
        } catch {
            print("[TimeTravel] Failed to sync with server: \(error)")
        }
    }

    /// Set up Time Travel with a specific start date
    func setup(startDate: Date) async throws {
        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.timeTravelSetup(startDate: startDate)

            if response.success {
                isTimeTravelActive = true
                isTestData = true
                currentDay = response.currentDay ?? 1
                startedAt = startDate
                updateSimulatedDate()
                dayUnlocksAt = nil
                secondsUntilUnlock = 0
                canAdvance = false
                isLocked = false
                persistState()
                print("[TimeTravel] Setup complete, Day 1 = \(startDate)")
            } else {
                throw NSError(domain: "TimeTravel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to set up time travel"])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Complete current day with mock data and start 5-second countdown
    func completeDay() async throws {
        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.timeTravelCompleteDay()

            if response.success {
                if let completedDay = response.completedDay {
                    currentDay = completedDay
                }

                // Start 5-second lockout
                dayUnlocksAt = Date().addingTimeInterval(5)
                secondsUntilUnlock = response.secondsUntilUnlock ?? 5
                canAdvance = false
                isLocked = true
                startCountdownTimer()

                persistState()
                updateSimulatedDate()
                print("[TimeTravel] Completed Day \(currentDay), lockout started")
            } else {
                throw NSError(domain: "TimeTravel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to complete day"])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Advance to next day after countdown completes
    func advanceToNextDay() async throws {
        guard canAdvance else {
            throw NSError(domain: "TimeTravel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot advance yet. \(secondsUntilUnlock) seconds remaining."])
        }

        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.timeTravelAdvanceDay()

            if response.success {
                if let newDay = response.currentDay {
                    currentDay = newDay
                }
                dayUnlocksAt = nil
                secondsUntilUnlock = 0
                canAdvance = false
                isLocked = false
                persistState()
                updateSimulatedDate()
                print("[TimeTravel] Advanced to Day \(currentDay)")
            } else if let errorMsg = response.error {
                throw NSError(domain: "TimeTravel", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Reset journey - clears all data and returns to Day 1
    func resetJourney() async throws {
        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.timeTravelReset()

            if response.success {
                isTimeTravelActive = false
                isTestData = false
                currentDay = 1
                startedAt = Date()
                simulatedDate = Date()
                dayUnlocksAt = nil
                secondsUntilUnlock = 0
                canAdvance = false
                isLocked = false
                stopCountdownTimer()
                persistState()
                print("[TimeTravel] Journey reset complete")
            } else {
                throw NSError(domain: "TimeTravel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to reset journey"])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Clear test data flag (convert to real patient)
    func clearTestDataFlag() async throws {
        isLoading = true
        error = nil

        do {
            let _ = try await ConvexService.shared.clearTestDataFlag()
            isTestData = false
            isTimeTravelActive = false
            dayUnlocksAt = nil
            secondsUntilUnlock = 0
            canAdvance = false
            isLocked = false
            stopCountdownTimer()
            persistState()
            print("[TimeTravel] Test data flag cleared")
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Reset all local state (for signout)
    func reset() {
        stopCountdownTimer()
        isTimeTravelActive = false
        isTestData = false
        secondsUntilUnlock = 0
        canAdvance = false
        isLocked = false
        currentDay = 1
        dayUnlocksAt = nil
        startedAt = Date()
        simulatedDate = Date()
        error = nil

        UserDefaults.standard.removeObject(forKey: Self.timeTravelActiveKey)
        UserDefaults.standard.removeObject(forKey: Self.startedAtKey)
        UserDefaults.standard.removeObject(forKey: Self.dayUnlocksAtKey)
        UserDefaults.standard.removeObject(forKey: Self.isTestDataKey)
        UserDefaults.standard.removeObject(forKey: Self.currentDayKey)
    }

    // MARK: - Computed Properties

    var formattedSimulatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: simulatedDate)
    }

    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: startedAt)
    }
}
