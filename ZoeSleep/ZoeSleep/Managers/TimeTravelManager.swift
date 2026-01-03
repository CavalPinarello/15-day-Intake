//
//  TimeTravelManager.swift
//  ZoeSleep
//
//  Manages Time Travel Mode for calendar-based journey testing
//  - Pick a past date as "simulated today"
//  - Advance day-by-day through the journey
//  - All dates stay in the past
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
    @Published var simulatedDate: Date = Date()      // "Today" in the simulation
    @Published var currentDay: Int = 1               // Journey day (1-10)
    @Published var dayCompleted: Bool = false        // Whether current day is done
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - UserDefaults keys for persistence

    private static let timeTravelActiveKey = "timeTravelActive"
    private static let simulatedDateKey = "timeTravelSimulatedDate"
    private static let currentDayKey = "timeTravelCurrentDay"
    private static let dayCompletedKey = "timeTravelDayCompleted"
    private static let isTestDataKey = "timeTravelIsTestData"

    // MARK: - Initialization

    private init() {
        loadPersistedState()
    }

    // MARK: - Computed Properties

    /// Whether we can advance to the next day
    /// - Must be in Time Travel mode
    /// - Next simulated date must not exceed today's real date
    /// - Must not be past Day 10
    var canAdvanceToNextDay: Bool {
        guard isTimeTravelActive else { return false }
        guard currentDay < 10 else { return false }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: simulatedDate) ?? simulatedDate
        return tomorrow <= Date()
    }

    /// How many days ago the simulated date is
    var daysAgo: Int {
        let components = Calendar.current.dateComponents([.day], from: simulatedDate, to: Date())
        return max(0, components.day ?? 0)
    }

    /// Why the advance button is disabled (for UI)
    var advanceDisabledReason: String? {
        guard isTimeTravelActive else { return nil }
        if currentDay >= 10 { return "Journey Complete" }
        if !canAdvanceToNextDay { return "At today's date" }
        return nil
    }

    /// Minimum selectable date (3 months ago)
    var minSelectableDate: Date {
        Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    }

    /// Maximum selectable date (yesterday - need at least 1 day to test)
    var maxSelectableDate: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    /// Formatted simulated date for display
    var formattedSimulatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: simulatedDate)
    }

    /// Whether the journey is complete (Day 10)
    var journeyComplete: Bool {
        currentDay >= 10
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        isTimeTravelActive = UserDefaults.standard.bool(forKey: Self.timeTravelActiveKey)
        isTestData = UserDefaults.standard.bool(forKey: Self.isTestDataKey)
        dayCompleted = UserDefaults.standard.bool(forKey: Self.dayCompletedKey)
        currentDay = UserDefaults.standard.integer(forKey: Self.currentDayKey)
        if currentDay == 0 { currentDay = 1 }

        if let simulatedTimestamp = UserDefaults.standard.object(forKey: Self.simulatedDateKey) as? Double {
            simulatedDate = Date(timeIntervalSince1970: simulatedTimestamp / 1000)
        }

        print("[TimeTravel] Loaded state: active=\(isTimeTravelActive), day=\(currentDay), simDate=\(formattedSimulatedDate)")
    }

    private func persistState() {
        UserDefaults.standard.set(isTimeTravelActive, forKey: Self.timeTravelActiveKey)
        UserDefaults.standard.set(isTestData, forKey: Self.isTestDataKey)
        UserDefaults.standard.set(dayCompleted, forKey: Self.dayCompletedKey)
        UserDefaults.standard.set(currentDay, forKey: Self.currentDayKey)
        UserDefaults.standard.set(simulatedDate.timeIntervalSince1970 * 1000, forKey: Self.simulatedDateKey)
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
            dayCompleted = status.dayCompleted
            simulatedDate = Date(timeIntervalSince1970: status.simulatedDate / 1000)

            persistState()

            print("[TimeTravel] Synced: active=\(isTimeTravelActive), day=\(currentDay), simDate=\(formattedSimulatedDate), daysAgo=\(daysAgo)")
        } catch {
            print("[TimeTravel] Failed to sync: \(error)")
        }
    }

    /// Set up Time Travel with a specific simulated date
    /// - Parameter simulatedDate: The past date to use as "today" in the simulation
    func setup(simulatedDate: Date) async throws {
        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.timeTravelSetup(simulatedDate: simulatedDate)

            if response.success {
                isTimeTravelActive = true
                isTestData = true
                currentDay = response.currentDay ?? 1
                self.simulatedDate = simulatedDate
                dayCompleted = false
                persistState()
                print("[TimeTravel] Setup complete, simulating \(formattedSimulatedDate) as Day 1")
            } else {
                throw NSError(domain: "TimeTravel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to set up time travel"])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Complete current day with mock data
    func completeDay() async throws {
        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.timeTravelCompleteDay()

            if response.success {
                if let completedDay = response.completedDay {
                    currentDay = completedDay
                }
                dayCompleted = true
                persistState()
                print("[TimeTravel] Day \(currentDay) completed")
            } else {
                throw NSError(domain: "TimeTravel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to complete day"])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Advance to next day - moves simulated date forward by 1 day
    func advanceToNextDay() async throws {
        guard canAdvanceToNextDay else {
            let reason = advanceDisabledReason ?? "Cannot advance"
            throw NSError(domain: "TimeTravel", code: -1, userInfo: [NSLocalizedDescriptionKey: reason])
        }

        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.timeTravelAdvanceDay()

            if response.success {
                if let newDay = response.currentDay {
                    currentDay = newDay
                }
                if let newSimDate = response.simulatedDate {
                    simulatedDate = Date(timeIntervalSince1970: newSimDate / 1000)
                } else {
                    // Fallback: advance locally
                    simulatedDate = Calendar.current.date(byAdding: .day, value: 1, to: simulatedDate) ?? simulatedDate
                }
                dayCompleted = false
                persistState()
                print("[TimeTravel] Advanced to Day \(currentDay), simulating \(formattedSimulatedDate)")
            } else if let errorMsg = response.error {
                throw NSError(domain: "TimeTravel", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Reset journey - clears all data and exits Time Travel mode
    func resetJourney() async throws {
        isLoading = true
        error = nil

        do {
            let response = try await ConvexService.shared.timeTravelReset()

            if response.success {
                isTimeTravelActive = false
                isTestData = false
                currentDay = 1
                simulatedDate = Date()
                dayCompleted = false
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
            dayCompleted = false
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
        isTimeTravelActive = false
        isTestData = false
        currentDay = 1
        simulatedDate = Date()
        dayCompleted = false
        error = nil

        UserDefaults.standard.removeObject(forKey: Self.timeTravelActiveKey)
        UserDefaults.standard.removeObject(forKey: Self.simulatedDateKey)
        UserDefaults.standard.removeObject(forKey: Self.currentDayKey)
        UserDefaults.standard.removeObject(forKey: Self.dayCompletedKey)
        UserDefaults.standard.removeObject(forKey: Self.isTestDataKey)
    }
}
