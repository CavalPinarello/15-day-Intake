//
//  DayAdvancementLogger.swift
//  ZoeSleep
//
//  Logging and analytics for day advancement events
//  Helps debug issues with day progression
//

import Foundation

// MARK: - Day Advancement Event

struct DayAdvancementEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let eventType: EventType
    let fromDay: Int
    let toDay: Int?
    let success: Bool
    let errorMessage: String?
    let sleepLogCompleted: Bool?
    let assessmentCompleted: Bool?
    let timeCheckPassed: Bool?
    let bypassedTimeCheck: Bool
    let debugMode: Bool

    enum EventType: String, Codable {
        case attemptAdvance = "attempt_advance"
        case advanceSuccess = "advance_success"
        case advanceFailed = "advance_failed"
        case retryAttempt = "retry_attempt"
        case progressReloadFailed = "progress_reload_failed"
        case questionsLoadFailed = "questions_load_failed"
    }

    var eventIcon: String {
        switch eventType {
        case .attemptAdvance: return "arrow.right.circle"
        case .advanceSuccess: return "checkmark.circle.fill"
        case .advanceFailed: return "xmark.circle.fill"
        case .retryAttempt: return "arrow.clockwise.circle"
        case .progressReloadFailed: return "exclamationmark.triangle.fill"
        case .questionsLoadFailed: return "exclamationmark.triangle.fill"
        }
    }

    var eventColor: String {
        switch eventType {
        case .attemptAdvance: return "blue"
        case .advanceSuccess: return "green"
        case .advanceFailed, .progressReloadFailed, .questionsLoadFailed: return "red"
        case .retryAttempt: return "orange"
        }
    }
}

// MARK: - Day Advancement Logger

@MainActor
class DayAdvancementLogger: ObservableObject {
    static let shared = DayAdvancementLogger()

    @Published private(set) var events: [DayAdvancementEvent] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastErrorTimestamp: Date?

    // Statistics
    @Published private(set) var totalAttempts: Int = 0
    @Published private(set) var successfulAdvances: Int = 0
    @Published private(set) var failedAdvances: Int = 0
    @Published private(set) var retryAttempts: Int = 0

    private let maxEvents = 100  // Keep last 100 events
    private let userDefaultsKey = "DayAdvancementEvents"

    private init() {
        loadEvents()
    }

    // MARK: - Logging Methods

    func logAttempt(fromDay: Int, bypassTimeCheck: Bool, debugMode: Bool) {
        let event = DayAdvancementEvent(
            id: UUID(),
            timestamp: Date(),
            eventType: .attemptAdvance,
            fromDay: fromDay,
            toDay: fromDay + 1,
            success: false,  // Will be updated on success
            errorMessage: nil,
            sleepLogCompleted: nil,
            assessmentCompleted: nil,
            timeCheckPassed: nil,
            bypassedTimeCheck: bypassTimeCheck,
            debugMode: debugMode
        )
        addEvent(event)
        totalAttempts += 1
        print("[DayAdvancementLogger] Attempt: Day \(fromDay) -> Day \(fromDay + 1), bypass=\(bypassTimeCheck), debug=\(debugMode)")
    }

    func logSuccess(fromDay: Int, toDay: Int, sleepLogCompleted: Bool, assessmentCompleted: Bool, bypassTimeCheck: Bool, debugMode: Bool) {
        let event = DayAdvancementEvent(
            id: UUID(),
            timestamp: Date(),
            eventType: .advanceSuccess,
            fromDay: fromDay,
            toDay: toDay,
            success: true,
            errorMessage: nil,
            sleepLogCompleted: sleepLogCompleted,
            assessmentCompleted: assessmentCompleted,
            timeCheckPassed: true,
            bypassedTimeCheck: bypassTimeCheck,
            debugMode: debugMode
        )
        addEvent(event)
        successfulAdvances += 1
        lastError = nil
        lastErrorTimestamp = nil
        print("[DayAdvancementLogger] Success: Day \(fromDay) -> Day \(toDay)")
    }

    func logFailure(fromDay: Int, error: String, sleepLogCompleted: Bool?, assessmentCompleted: Bool?, timeCheckPassed: Bool?, bypassTimeCheck: Bool, debugMode: Bool) {
        let event = DayAdvancementEvent(
            id: UUID(),
            timestamp: Date(),
            eventType: .advanceFailed,
            fromDay: fromDay,
            toDay: nil,
            success: false,
            errorMessage: error,
            sleepLogCompleted: sleepLogCompleted,
            assessmentCompleted: assessmentCompleted,
            timeCheckPassed: timeCheckPassed,
            bypassedTimeCheck: bypassTimeCheck,
            debugMode: debugMode
        )
        addEvent(event)
        failedAdvances += 1
        lastError = error
        lastErrorTimestamp = Date()
        print("[DayAdvancementLogger] Failed: Day \(fromDay), error: \(error)")
    }

    func logRetry(fromDay: Int, attemptNumber: Int) {
        let event = DayAdvancementEvent(
            id: UUID(),
            timestamp: Date(),
            eventType: .retryAttempt,
            fromDay: fromDay,
            toDay: fromDay + 1,
            success: false,
            errorMessage: "Retry attempt #\(attemptNumber)",
            sleepLogCompleted: nil,
            assessmentCompleted: nil,
            timeCheckPassed: nil,
            bypassedTimeCheck: false,
            debugMode: false
        )
        addEvent(event)
        retryAttempts += 1
        print("[DayAdvancementLogger] Retry #\(attemptNumber) for Day \(fromDay)")
    }

    func logProgressReloadFailed(currentDay: Int, error: String) {
        let event = DayAdvancementEvent(
            id: UUID(),
            timestamp: Date(),
            eventType: .progressReloadFailed,
            fromDay: currentDay,
            toDay: nil,
            success: false,
            errorMessage: error,
            sleepLogCompleted: nil,
            assessmentCompleted: nil,
            timeCheckPassed: nil,
            bypassedTimeCheck: false,
            debugMode: false
        )
        addEvent(event)
        lastError = "Progress reload failed: \(error)"
        lastErrorTimestamp = Date()
        print("[DayAdvancementLogger] Progress reload failed: \(error)")
    }

    func logQuestionsLoadFailed(day: Int, error: String) {
        let event = DayAdvancementEvent(
            id: UUID(),
            timestamp: Date(),
            eventType: .questionsLoadFailed,
            fromDay: day,
            toDay: nil,
            success: false,
            errorMessage: error,
            sleepLogCompleted: nil,
            assessmentCompleted: nil,
            timeCheckPassed: nil,
            bypassedTimeCheck: false,
            debugMode: false
        )
        addEvent(event)
        print("[DayAdvancementLogger] Questions load failed for Day \(day): \(error)")
    }

    // MARK: - Event Management

    private func addEvent(_ event: DayAdvancementEvent) {
        events.insert(event, at: 0)
        if events.count > maxEvents {
            events.removeLast()
        }
        saveEvents()
    }

    func clearEvents() {
        events.removeAll()
        totalAttempts = 0
        successfulAdvances = 0
        failedAdvances = 0
        retryAttempts = 0
        lastError = nil
        lastErrorTimestamp = nil
        saveEvents()
        print("[DayAdvancementLogger] Events cleared")
    }

    // MARK: - Persistence

    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadEvents() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([DayAdvancementEvent].self, from: data) {
            events = decoded

            // Recalculate statistics
            for event in events {
                switch event.eventType {
                case .attemptAdvance: totalAttempts += 1
                case .advanceSuccess: successfulAdvances += 1
                case .advanceFailed: failedAdvances += 1
                case .retryAttempt: retryAttempts += 1
                case .progressReloadFailed, .questionsLoadFailed: break
                }
            }
        }
    }

    // MARK: - Analytics Summary

    var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(successfulAdvances) / Double(totalAttempts) * 100
    }

    var recentFailures: [DayAdvancementEvent] {
        events.filter { !$0.success && $0.eventType == .advanceFailed }.prefix(5).map { $0 }
    }

    var hasRecentError: Bool {
        guard let timestamp = lastErrorTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < 300  // Within last 5 minutes
    }
}
