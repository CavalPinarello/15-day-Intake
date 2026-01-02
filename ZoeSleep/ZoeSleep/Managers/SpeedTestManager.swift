//
//  SpeedTestManager.swift
//  ZoeSleep
//
//  Manages Speed Test Mode for accelerated 14-day journey testing
//  - 15-second day lockouts instead of 24 hours
//  - Countdown timer with app restart survival
//  - Red badge indicator for test mode
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SpeedTestManager: ObservableObject {
    static let shared = SpeedTestManager()

    // MARK: - Published State

    @Published var isSpeedTestMode: Bool = false
    @Published var isTestData: Bool = false
    @Published var secondsUntilUnlock: Int = 0
    @Published var canAdvance: Bool = false
    @Published var currentDay: Int = 1
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Private State

    private var countdownTimer: Timer?
    private var dayUnlocksAt: Date?

    // UserDefaults keys for persistence
    private static let speedTestModeKey = "speedTestMode"
    private static let dayUnlocksAtKey = "speedTestDayUnlocksAt"
    private static let isTestDataKey = "speedTestIsTestData"

    // MARK: - Initialization

    private init() {
        loadPersistedState()
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        isSpeedTestMode = UserDefaults.standard.bool(forKey: Self.speedTestModeKey)
        isTestData = UserDefaults.standard.bool(forKey: Self.isTestDataKey)

        if let unlockTimestamp = UserDefaults.standard.object(forKey: Self.dayUnlocksAtKey) as? Double {
            dayUnlocksAt = Date(timeIntervalSince1970: unlockTimestamp / 1000)
            updateCountdown()

            // Start timer if we're in speed test mode with active countdown
            if isSpeedTestMode && secondsUntilUnlock > 0 {
                startCountdownTimer()
            }
        }

        print("[SpeedTest] Loaded persisted state: mode=\(isSpeedTestMode), testData=\(isTestData), secondsUntilUnlock=\(secondsUntilUnlock)")
    }

    private func persistState() {
        UserDefaults.standard.set(isSpeedTestMode, forKey: Self.speedTestModeKey)
        UserDefaults.standard.set(isTestData, forKey: Self.isTestDataKey)

        if let unlockDate = dayUnlocksAt {
            UserDefaults.standard.set(unlockDate.timeIntervalSince1970 * 1000, forKey: Self.dayUnlocksAtKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.dayUnlocksAtKey)
        }
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
            canAdvance = true
            return
        }

        let remaining = unlockDate.timeIntervalSinceNow
        if remaining <= 0 {
            secondsUntilUnlock = 0
            canAdvance = true
            stopCountdownTimer()
        } else {
            secondsUntilUnlock = Int(ceil(remaining))
            canAdvance = false
        }
    }

    // MARK: - Public API

    /// Sync state with server (call on app launch and resume)
    func syncWithServer() async {
        guard ConvexService.shared.isAuthenticated else { return }

        do {
            let status = try await ConvexService.shared.getSpeedTestStatus()

            isSpeedTestMode = status.speedTestMode
            isTestData = status.isTestData
            currentDay = status.currentDay
            secondsUntilUnlock = status.secondsUntilUnlock
            canAdvance = status.canAdvance

            if let unlockAt = status.dayUnlocksAt {
                dayUnlocksAt = Date(timeIntervalSince1970: Double(unlockAt) / 1000)
            } else {
                dayUnlocksAt = nil
            }

            persistState()

            // Start timer if needed
            if isSpeedTestMode && secondsUntilUnlock > 0 {
                startCountdownTimer()
            } else {
                stopCountdownTimer()
            }

            print("[SpeedTest] Synced with server: mode=\(isSpeedTestMode), day=\(currentDay), countdown=\(secondsUntilUnlock)s")
        } catch {
            print("[SpeedTest] Failed to sync with server: \(error)")
        }
    }

    /// Enable speed test mode
    func enableSpeedTestMode() async throws {
        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.enableSpeedTestMode()

            if response.success {
                isSpeedTestMode = true
                isTestData = true
                persistState()
                print("[SpeedTest] Enabled speed test mode")
            } else {
                throw NSError(domain: "SpeedTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to enable speed test mode"])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Disable speed test mode
    func disableSpeedTestMode() async throws {
        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.disableSpeedTestMode()

            if response.success {
                isSpeedTestMode = false
                dayUnlocksAt = nil
                secondsUntilUnlock = 0
                canAdvance = false
                stopCountdownTimer()
                persistState()
                print("[SpeedTest] Disabled speed test mode")
            } else {
                throw NSError(domain: "SpeedTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to disable speed test mode"])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Complete current day with mock data and start 15-second countdown
    func completeDay(phenotype: String = "normal") async throws {
        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.speedTestCompleteDay(phenotype: phenotype)

            if response.success {
                if let completedDay = response.completedDay {
                    currentDay = completedDay
                }

                if let unlockAt = response.dayUnlocksAt {
                    dayUnlocksAt = Date(timeIntervalSince1970: Double(unlockAt) / 1000)
                    secondsUntilUnlock = response.secondsUntilUnlock ?? 15
                    canAdvance = false
                    startCountdownTimer()
                }

                persistState()
                print("[SpeedTest] Completed Day \(currentDay), countdown started")
            } else {
                throw NSError(domain: "SpeedTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to complete day"])
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
            throw NSError(domain: "SpeedTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot advance yet. \(secondsUntilUnlock) seconds remaining."])
        }

        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.speedTestAdvanceDay()

            if response.success {
                if let newDay = response.currentDay {
                    currentDay = newDay
                }
                dayUnlocksAt = nil
                secondsUntilUnlock = 0
                canAdvance = false
                persistState()
                print("[SpeedTest] Advanced to Day \(currentDay)")
            } else if let errorMsg = response.error {
                throw NSError(domain: "SpeedTest", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Clear test data flag
    func clearTestDataFlag() async throws {
        isLoading = true
        error = nil

        do {
            let _ = try await ConvexService.shared.clearTestDataFlag()
            isTestData = false
            isSpeedTestMode = false
            dayUnlocksAt = nil
            secondsUntilUnlock = 0
            canAdvance = false
            stopCountdownTimer()
            persistState()
            print("[SpeedTest] Cleared test data flag")
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Reset all local state (for signout)
    func reset() {
        stopCountdownTimer()
        isSpeedTestMode = false
        isTestData = false
        secondsUntilUnlock = 0
        canAdvance = false
        currentDay = 1
        dayUnlocksAt = nil
        error = nil

        UserDefaults.standard.removeObject(forKey: Self.speedTestModeKey)
        UserDefaults.standard.removeObject(forKey: Self.dayUnlocksAtKey)
        UserDefaults.standard.removeObject(forKey: Self.isTestDataKey)
    }
}
