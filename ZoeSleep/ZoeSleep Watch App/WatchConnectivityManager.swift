//
//  WatchConnectivityManager.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Manages communication between Apple Watch and iPhone
//  for questionnaire sync and data exchange
//

import WatchConnectivity
import WatchKit
import Foundation
import Combine

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isConnected = false
    @Published var isUserAuthenticated = false
    @Published var currentUserDay = 1

    // Debug log for connectivity events (max 100 entries, newest first)
    @Published var connectivityLog: [WatchConnectivityLogEntry] = []

    private var session: WCSession?
    private var pendingCallbacks: [String: (Any?) -> Void] = [:]

    override init() {
        super.init()
        setupWatchConnectivity()
        log("WatchConnectivityManager initialized")
    }

    // MARK: - Debug Logging

    func log(_ message: String, level: WatchConnectivityLogEntry.Level = .info) {
        let entry = WatchConnectivityLogEntry(message: message, level: level)
        connectivityLog.insert(entry, at: 0)
        // Keep only last 100 entries
        if connectivityLog.count > 100 {
            connectivityLog.removeLast()
        }
        print("[WatchConnectivity] \(level.emoji) \(message)")
    }

    func clearLog() {
        connectivityLog.removeAll()
        log("Log cleared")
    }
    
    func activate() {
        log("Activating WCSession...")
        session?.activate()
    }

    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            log("WCSession configured, delegate set")
        } else {
            log("WCSession not supported on this device", level: .warning)
        }
    }

    // MARK: - Data Requests

    func requestDataFromiPhone() {
        guard let session = session, session.isReachable else { return }
        
        let message = [
            "action": "requestUserData",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleUserDataResponse(reply)
            }
        }) { error in
            print("Failed to request user data: \(error.localizedDescription)")
        }
    }
    
    func requestCurrentDayQuestions(completion: @escaping (Int, [WatchQuestion]) -> Void) {
        guard let session = session, session.isReachable else {
            completion(1, [])
            return
        }
        
        let requestId = UUID().uuidString
        pendingCallbacks[requestId] = { response in
            if let data = response as? [String: Any],
               let day = data["day"] as? Int,
               let questionsData = data["questions"] as? [[String: Any]] {
                let questions = questionsData.compactMap { self.parseQuestion(from: $0) }
                completion(day, questions)
            } else {
                completion(1, [])
            }
        }
        
        let message = [
            "action": "requestCurrentDayQuestions",
            "requestId": requestId,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                if let callback = self?.pendingCallbacks.removeValue(forKey: requestId) {
                    callback(reply)
                }
            }
        }) { [weak self] error in
            print("Failed to request questions: \(error.localizedDescription)")
            DispatchQueue.main.async {
                if let callback = self?.pendingCallbacks.removeValue(forKey: requestId) {
                    callback(nil)
                }
            }
        }
    }
    
    func requestRecommendations(completion: @escaping ([PhysicianRecommendation]) -> Void) {
        guard let session = session, session.isReachable else {
            completion([])
            return
        }
        
        let requestId = UUID().uuidString
        pendingCallbacks[requestId] = { response in
            if let data = response as? [String: Any],
               let recommendationsData = data["recommendations"] as? [[String: Any]] {
                let recommendations = recommendationsData.compactMap { self.parseRecommendation(from: $0) }
                completion(recommendations)
            } else {
                completion([])
            }
        }
        
        let message = [
            "action": "requestRecommendations",
            "requestId": requestId,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                if let callback = self?.pendingCallbacks.removeValue(forKey: requestId) {
                    callback(reply)
                }
            }
        }) { [weak self] error in
            print("Failed to request recommendations: \(error.localizedDescription)")
            DispatchQueue.main.async {
                if let callback = self?.pendingCallbacks.removeValue(forKey: requestId) {
                    callback(nil)
                }
            }
        }
    }
    
    // MARK: - Data Sending
    
    func sendResponses(_ responses: [String: Any], forDay day: Int, completion: @escaping (Bool) -> Void) {
        guard let session = session, session.isReachable else {
            completion(false)
            return
        }
        
        let message = [
            "action": "saveQuestionnaireResponses",
            "day": day,
            "responses": responses,
            "source": "watch",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        session.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                let success = reply["success"] as? Bool ?? false
                completion(success)
            }
        }) { error in
            print("Failed to send responses: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
    
    func sendHealthKitData(_ healthData: [String: Any]) {
        guard let session = session, session.isReachable else { return }
        
        let message = [
            "action": "syncHealthKitData",
            "healthData": healthData,
            "source": "watch",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send HealthKit data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Treatment Tasks

    func requestTreatmentTasks(completion: @escaping ([WatchTreatmentTask]) -> Void) {
        guard let session = session, session.isReachable else {
            // Return empty array if not connected - the view will show "No tasks yet"
            completion([])
            return
        }

        let requestId = UUID().uuidString
        pendingCallbacks[requestId] = { response in
            if let data = response as? [String: Any],
               let tasksData = data["tasks"] as? [[String: Any]] {
                let tasks = tasksData.compactMap { self.parseTreatmentTask(from: $0) }
                completion(tasks)
            } else {
                completion([])
            }
        }

        let message = [
            "action": "requestTreatmentTasks",
            "requestId": requestId,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]

        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                if let callback = self?.pendingCallbacks.removeValue(forKey: requestId) {
                    callback(reply)
                }
            }
        }) { [weak self] error in
            print("Failed to request treatment tasks: \(error.localizedDescription)")
            DispatchQueue.main.async {
                if let callback = self?.pendingCallbacks.removeValue(forKey: requestId) {
                    callback(nil)
                }
            }
        }
    }

    func completeTreatmentTask(taskId: String, completion: @escaping (Bool) -> Void) {
        guard let session = session, session.isReachable else {
            completion(false)
            return
        }

        let message = [
            "action": "completeTreatmentTask",
            "taskId": taskId,
            "source": "watch",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]

        session.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                let success = reply["success"] as? Bool ?? false
                completion(success)
            }
        }) { error in
            print("Failed to complete treatment task: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }

    private func parseTreatmentTask(from data: [String: Any]) -> WatchTreatmentTask? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let shortInstructions = data["shortInstructions"] as? String else {
            return nil
        }

        let timing = data["timing"] as? String
        let isCompleted = data["isCompleted"] as? Bool ?? false

        return WatchTreatmentTask(
            id: id,
            name: name,
            timing: timing,
            shortInstructions: shortInstructions,
            isCompleted: isCompleted
        )
    }

    func resetJourneyProgress(completion: @escaping (Bool, Int) -> Void) {
        guard let session = session, session.isReachable else {
            completion(false, currentUserDay)
            return
        }

        let message = [
            "action": "resetJourneyProgress",
            "source": "watch",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]

        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                let success = reply["success"] as? Bool ?? false
                let newDay = reply["newDay"] as? Int ?? 1
                if success {
                    self?.currentUserDay = newDay
                }
                completion(success, newDay)
            }
        }) { error in
            print("Failed to reset journey progress: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(false, self.currentUserDay)
            }
        }
    }

    /// Notify iPhone that a section was completed (triggers immediate refresh)
    func notifyiPhoneSectionCompleted(section: String, dayNumber: Int) {
        guard let session = session, session.isReachable else {
            print("[Watch] Cannot notify iPhone - not reachable")
            return
        }

        let message: [String: Any] = [
            "action": "sectionCompleted",
            "section": section,
            "dayNumber": dayNumber,
            "source": "watch",
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: { reply in
            print("[Watch] iPhone acknowledged section completion")
        }) { error in
            print("[Watch] Failed to notify iPhone of section completion: \(error.localizedDescription)")
        }
    }

    func advanceDay(completion: @escaping (Int) -> Void) {
        guard let session = session, session.isReachable else {
            completion(currentUserDay)
            return
        }
        
        let requestId = UUID().uuidString
        pendingCallbacks[requestId] = { response in
            if let data = response as? [String: Any],
               let newDay = data["newDay"] as? Int {
                completion(newDay)
            } else {
                completion(self.currentUserDay)
            }
        }
        
        let message = [
            "action": "advanceDay",
            "requestId": requestId,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                if let callback = self?.pendingCallbacks.removeValue(forKey: requestId) {
                    callback(reply)
                }
            }
        }) { [weak self] error in
            print("Failed to advance day: \(error.localizedDescription)")
            DispatchQueue.main.async {
                if let callback = self?.pendingCallbacks.removeValue(forKey: requestId) {
                    callback(nil)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleUserDataResponse(_ data: [String: Any]) {
        if let authenticated = data["isAuthenticated"] as? Bool {
            isUserAuthenticated = authenticated
        }

        if let day = data["currentDay"] as? Int {
            currentUserDay = day
        }

        // If iPhone sent a Convex userId, use it to authenticate on Watch
        // This ensures Watch and iPhone use the same user for Convex sync
        if let convexUserId = data["convexUserId"] as? String {
            let convexService = WatchConvexService.shared
            if convexService.userId != convexUserId {
                // Update credentials and fetch latest state
                convexService.updateUserId(convexUserId)
                print("[Watch] Synced Convex userId from iPhone: \(convexUserId)")
            }
        }

        // Handle check-in status if included (from "Sync Now" button)
        if let checkInStatus = data["checkInStatus"] as? [String: Any] {
            let morningDone = checkInStatus["morningDone"] as? Bool ?? false
            let middayDone = checkInStatus["middayDone"] as? Bool ?? false
            let eveningDone = checkInStatus["eveningDone"] as? Bool ?? false
            print("[Watch] Received check-in status: morning=\(morningDone), midday=\(middayDone), evening=\(eveningDone)")

            // Post notification to update UI with check-in status
            NotificationCenter.default.post(
                name: .watchCheckInStatusDidChange,
                object: nil,
                userInfo: [
                    "morningDone": morningDone,
                    "middayDone": middayDone,
                    "eveningDone": eveningDone,
                    "source": "iphone_sync"
                ]
            )

            // Also refresh from Convex to ensure we have latest data
            Task {
                await WatchConvexService.shared.refreshFromConvex()
            }
        }
    }

    private func parseQuestion(from data: [String: Any]) -> WatchQuestion? {
        guard let id = data["id"] as? String,
              let text = data["text"] as? String,
              let typeString = data["type"] as? String,
              let type = WatchQuestionType(rawValue: typeString) else {
            return nil
        }

        let options = data["options"] as? [String]

        return WatchQuestion(id: id, text: text, type: type, options: options)
    }
    
    private func parseRecommendation(from data: [String: Any]) -> PhysicianRecommendation? {
        guard let id = data["id"] as? String,
              let title = data["title"] as? String,
              let summary = data["summary"] as? String,
              let categoryString = data["category"] as? String,
              let category = RecommendationCategory(rawValue: categoryString),
              let isCompleted = data["isCompleted"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? TimeInterval,
              let priorityString = data["priority"] as? String,
              let priority = PhysicianRecommendation.Priority(rawValue: priorityString) else {
            return nil
        }
        
        let details = data["details"] as? String
        let instructions = data["instructions"] as? String
        let schedule = data["schedule"] as? String
        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        
        return PhysicianRecommendation(
            id: id,
            title: title,
            summary: summary,
            details: details,
            instructions: instructions,
            category: category,
            schedule: schedule,
            isCompleted: isCompleted,
            createdAt: createdAt,
            priority: priority
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated

            if let error = error {
                self.log("Activation failed: \(error.localizedDescription)", level: .error)
            } else {
                let stateStr = activationState == .activated ? "activated" : (activationState == .inactive ? "inactive" : "notActivated")
                self.log("Session \(stateStr), isReachable: \(session.isReachable)", level: .success)
                self.requestDataFromiPhone()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            let wasConnected = self.isConnected
            self.isConnected = session.isReachable
            self.log("Reachability changed: \(wasConnected) → \(session.isReachable)", level: session.isReachable ? .success : .warning)

            // If we just became reachable, request fresh data
            if session.isReachable && !wasConnected {
                self.log("iPhone became reachable - requesting data")
                self.requestDataFromiPhone()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            let action = message["action"] as? String ?? "unknown"
            self.log("Received message: \(action) (with reply)")
            self.handleIncomingMessage(message, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            let action = message["action"] as? String ?? "unknown"
            self.log("Received message: \(action) (no reply)")
            self.handleIncomingMessage(message, replyHandler: nil)
        }
    }

    /// Handle userInfo transfers (used when Watch is not reachable during iPhone login)
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async {
            let action = userInfo["action"] as? String ?? "unknown"
            self.log("Received userInfo transfer: \(action)", level: .success)
            // Handle as a message - it may contain credentials or user data
            self.handleIncomingMessage(userInfo, replyHandler: nil)
        }
    }
    
    private func handleIncomingMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        guard let action = message["action"] as? String else {
            replyHandler?(["error": "No action specified"])
            return
        }

        switch action {
        case "userDataUpdate":
            handleUserDataResponse(message)
            // Also update theme if included
            handleThemeSettingsIfPresent(message)
            replyHandler?(["received": true])

        case "credentialsSync":
            // iPhone is syncing login credentials - update Watch's Convex authentication
            handleCredentialsSync(message)
            replyHandler?(["received": true, "synced": true])

        case "themeSettingsUpdate":
            handleThemeSettingsUpdate(message)
            replyHandler?(["received": true])

        case "recommendationUpdate":
            // Handle real-time recommendation updates
            replyHandler?(["received": true])

        case "dayAdvanced":
            if let newDay = message["newDay"] as? Int {
                currentUserDay = newDay
                print("[Watch] Received day advance from iPhone: Day \(newDay)")
                // Also update Convex service
                Task {
                    await WatchConvexService.shared.refreshFromConvex()
                }
            }
            replyHandler?(["received": true])

        case "iPhoneSectionCompleted":
            // iPhone completed a section - refresh our state
            let section = message["section"] as? String ?? "unknown"
            let dayNumber = message["dayNumber"] as? Int ?? 0
            let sleepLogCompleted = message["sleepLogCompleted"] as? Bool ?? false
            let assessmentCompleted = message["assessmentCompleted"] as? Bool ?? false
            print("[Watch] iPhone completed section '\(section)' for day \(dayNumber) - refreshing state (sleepLog=\(sleepLogCompleted), assessment=\(assessmentCompleted))")
            Task {
                await WatchConvexService.shared.refreshFromConvex()
                // Post notification to update any listening views (MinimalHomeView, MinimalTasksView)
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .watchSectionCompletionDidChange,
                        object: nil,
                        userInfo: [
                            "section": section,
                            "dayNumber": dayNumber,
                            "sleepLogCompleted": sleepLogCompleted,
                            "assessmentCompleted": assessmentCompleted,
                            "source": "iphone"
                        ]
                    )
                }
            }
            replyHandler?(["received": true])

        case "userLogout":
            // iPhone user logged out - clear Watch credentials and state
            handleUserLogout()
            replyHandler?(["received": true, "cleared": true])

        case "checkInCompleted":
            // iPhone completed a check-in - update Watch state
            handleCheckInCompleted(message)
            replyHandler?(["received": true])

        default:
            log("Unknown action received: \(action)", level: .warning)
            replyHandler?(["error": "Unknown action: \(action)"])
        }
    }

    // MARK: - Credentials Sync Handler

    private func handleCredentialsSync(_ message: [String: Any]) {
        // Extract credentials from iPhone
        guard let userId = message["convexUserId"] as? String else {
            print("[Watch] Credentials sync missing userId")
            return
        }

        let username = message["convexUsername"] as? String
        let currentDay = message["currentDay"] as? Int

        print("[Watch] Received credentials from iPhone: userId=\(userId), username=\(username ?? "nil")")

        // Update local state
        isUserAuthenticated = true
        if let day = currentDay {
            currentUserDay = day
        }

        // Update WatchConvexService with the iPhone's credentials
        let convexService = WatchConvexService.shared
        convexService.updateCredentialsFromiPhone(userId: userId, username: username)
    }

    // MARK: - Logout Handler

    private func handleUserLogout() {
        log("Received logout notification from iPhone - clearing credentials", level: .warning)

        // Clear local state
        isUserAuthenticated = false
        currentUserDay = 1

        // Clear WatchConvexService credentials (removes from UserDefaults too)
        let convexService = WatchConvexService.shared
        convexService.clearCredentials()

        log("Credentials cleared - Watch will sync with next iPhone login", level: .success)
    }

    // MARK: - Check-In Sync Handler

    private func handleCheckInCompleted(_ message: [String: Any]) {
        guard let timeSlotStr = message["timeSlot"] as? String,
              let date = message["date"] as? String else {
            log("Check-in sync missing timeSlot or date", level: .error)
            return
        }

        let source = message["source"] as? String ?? "unknown"
        log("Received check-in completion: \(timeSlotStr) for \(date) from \(source)", level: .success)

        // Post notification to update any listening views
        NotificationCenter.default.post(
            name: .watchCheckInStatusDidChange,
            object: nil,
            userInfo: ["timeSlot": timeSlotStr, "date": date, "source": source]
        )

        // Refresh state from Convex to get latest check-in status
        Task {
            await WatchConvexService.shared.refreshFromConvex()
            log("Refreshed state after check-in sync")
        }
    }

    // MARK: - Theme Settings Handler

    private func handleThemeSettingsUpdate(_ message: [String: Any]) {
        let themeManager = WatchThemeManager.shared
        themeManager.updateFromiPhone(
            accentColor: message["accentColor"] as? String,
            appearanceMode: message["appearanceMode"] as? String,
            largeIcons: message["largeIconsMode"] as? Bool,
            highContrast: message["highContrast"] as? Bool,
            reduceMotion: message["reduceMotion"] as? Bool
        )
    }

    private func handleThemeSettingsIfPresent(_ message: [String: Any]) {
        // Check if theme settings are included in the message
        if message["accentColor"] != nil || message["appearanceMode"] != nil {
            handleThemeSettingsUpdate(message)
        }
    }
}

// MARK: - Watch Data Models (for connectivity)

/// Question types for watch questionnaires
enum WatchQuestionType: String {
    case scale
    case multipleChoice
    case text
    case time
    case boolean
}

/// A question for the watch app
struct WatchQuestion: Identifiable {
    let id: String
    let text: String
    let type: WatchQuestionType
    let options: [String]?
}

/// Recommendation category
enum RecommendationCategory: String {
    case sleepHygiene = "sleep_hygiene"
    case behavioral = "behavioral"
    case environmental = "environmental"
    case lifestyle = "lifestyle"
    case medical = "medical"
    case other = "other"
}

/// A physician recommendation
struct PhysicianRecommendation: Identifiable {
    enum Priority: String {
        case high
        case medium
        case low
    }

    let id: String
    let title: String
    let summary: String
    let details: String?
    let instructions: String?
    let category: RecommendationCategory
    let schedule: String?
    var isCompleted: Bool
    let createdAt: Date
    let priority: Priority
}

/// A treatment task for the watch
struct WatchTreatmentTask: Identifiable {
    let id: String
    let name: String
    let timing: String?
    let shortInstructions: String
    var isCompleted: Bool
}

// MARK: - Connectivity Log Entry

struct WatchConnectivityLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: Level

    enum Level: String {
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARNING"
        case error = "ERROR"

        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .success: return "✅"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }

        var color: String {
            switch self {
            case .info: return "blue"
            case .success: return "green"
            case .warning: return "orange"
            case .error: return "red"
            }
        }
    }

    init(message: String, level: Level = .info) {
        self.timestamp = Date()
        self.message = message
        self.level = level
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchCheckInStatusDidChange = Notification.Name("watchCheckInStatusDidChange")
    static let watchSectionCompletionDidChange = Notification.Name("watchSectionCompletionDidChange")
}