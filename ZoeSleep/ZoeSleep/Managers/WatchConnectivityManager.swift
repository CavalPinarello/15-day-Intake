//
//  WatchConnectivityManager.swift
//  Zoe Sleep for Longevity System - iOS
//
//  Manages communication between iPhone and Apple Watch
//  Responds to Watch requests and syncs data bidirectionally
//

@preconcurrency import WatchConnectivity
import Foundation
import Combine

@MainActor
class iOSWatchConnectivityManager: NSObject, ObservableObject {
    static let shared = iOSWatchConnectivityManager()

    // Cached theme values for thread-safe access
    private var cachedAccentColor: String = ""
    private var cachedAppearanceMode: String = ""
    private var cachedLargeIconsMode: Bool = false
    private var cachedHighContrast: Bool = false
    private var cachedReduceMotion: Bool = false

    @Published var isWatchConnected = false
    @Published var isWatchAppInstalled = false

    // Debug log for connectivity events (max 100 entries, newest first)
    @Published var connectivityLog: [iOSConnectivityLogEntry] = []

    private var session: WCSession?
    private var questionnaireManager: QuestionnaireManager { QuestionnaireManager.shared }

    private override init() {
        super.init()
        setupWatchConnectivity()
        log("iOSWatchConnectivityManager initialized")
    }

    // MARK: - Debug Logging

    func log(_ message: String, level: iOSConnectivityLogEntry.Level = .info) {
        let entry = iOSConnectivityLogEntry(message: message, level: level)
        connectivityLog.insert(entry, at: 0)
        // Keep only last 100 entries
        if connectivityLog.count > 100 {
            connectivityLog.removeLast()
        }
        print("[iOSWatchConnectivity] \(level.emoji) \(message)")
    }

    func clearLog() {
        connectivityLog.removeAll()
        log("Log cleared")
    }

    // MARK: - Setup

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send Data to Watch

    /// Update cached theme values (call this before sending to Watch)
    func updateCachedThemeValues() {
        let themeManager = ThemeManager.shared
        cachedAccentColor = themeManager.accentColorOption.rawValue
        cachedAppearanceMode = themeManager.appearanceMode.rawValue
        cachedLargeIconsMode = themeManager.largeIconsMode
        cachedHighContrast = themeManager.highContrast
        cachedReduceMotion = themeManager.reduceMotion
    }

    /// Send updated user data to Watch (including user credentials for Convex sync)
    func sendUserDataToWatch() {
        updateCachedThemeValues()
        guard let session = session else { return }

        // Get current check-in status from CheckInManager
        let checkInManager = CheckInManager.shared

        var message: [String: Any] = [
            "action": "userDataUpdate",
            "isAuthenticated": ConvexService.shared.isAuthenticated,
            "currentDay": questionnaireManager.currentDay,
            "accentColor": cachedAccentColor,
            "appearanceMode": cachedAppearanceMode,
            "timestamp": Date().timeIntervalSince1970,
            // Include check-in status so Watch can update immediately
            "checkInStatus": [
                "morningDone": checkInManager.morningCompleted,
                "middayDone": checkInManager.middayCompleted,
                "eveningDone": checkInManager.eveningCompleted
            ] as [String: Any]
        ]

        // Send user credentials to Watch for Convex sync (only if authenticated)
        if let userId = ConvexService.shared.userId {
            message["convexUserId"] = userId
        }

        // Also include username for Watch to use
        if let username = KeychainHelper.load(forKey: "convex_username") {
            message["convexUsername"] = username
        }

        // Try sendMessage if reachable, otherwise use transferUserInfo for background delivery
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send user data to Watch: \(error.localizedDescription)")
            }
        } else {
            // Use transferUserInfo for guaranteed delivery when Watch is not reachable
            session.transferUserInfo(message)
            print("[iOS] Queued user data for Watch via transferUserInfo")
        }
    }

    /// Call this after successful login to immediately sync credentials to Watch
    func syncCredentialsToWatch(userId: String, username: String) {
        guard let session = session else {
            log("Cannot sync credentials - no session", level: .error)
            return
        }

        let message: [String: Any] = [
            "action": "credentialsSync",
            "convexUserId": userId,
            "convexUsername": username,
            "isAuthenticated": true,
            "currentDay": questionnaireManager.currentDay,
            "timestamp": Date().timeIntervalSince1970
        ]

        log("Syncing credentials to Watch: userId=\(userId.prefix(8))..., username=\(username)")

        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] reply in
                self?.log("Watch acknowledged credentials sync", level: .success)
            }) { [weak self] error in
                self?.log("sendMessage failed, using transferUserInfo: \(error.localizedDescription)", level: .warning)
                // Fallback to transferUserInfo
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
            log("Queued credentials via transferUserInfo (Watch not reachable)")
        }
    }

    /// Send theme settings to Watch
    func sendThemeSettingsToWatch() {
        updateCachedThemeValues()
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "action": "themeSettingsUpdate",
            "accentColor": cachedAccentColor,
            "appearanceMode": cachedAppearanceMode,
            "largeIconsMode": cachedLargeIconsMode,
            "highContrast": cachedHighContrast,
            "reduceMotion": cachedReduceMotion,
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send theme settings to Watch: \(error.localizedDescription)")
        }
    }

    /// Notify Watch that day was advanced
    func notifyWatchDayAdvanced(newDay: Int) {
        guard let session = session else { return }

        let message: [String: Any] = [
            "action": "dayAdvanced",
            "newDay": newDay,
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to notify Watch of day advance: \(error.localizedDescription)")
            }
        } else {
            // Queue for later delivery
            session.transferUserInfo(message)
            print("[iOS] Queued day advance notification for Watch")
        }
    }

    /// Notify Watch that a section was completed on iPhone
    func notifyWatchSectionCompleted(section: String, dayNumber: Int, sleepLogCompleted: Bool, assessmentCompleted: Bool) {
        guard let session = session else { return }

        let message: [String: Any] = [
            "action": "iPhoneSectionCompleted",
            "section": section,
            "dayNumber": dayNumber,
            "sleepLogCompleted": sleepLogCompleted,
            "assessmentCompleted": assessmentCompleted,
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to notify Watch of section completion: \(error.localizedDescription)")
            }
        } else {
            // Queue for later delivery - Watch will refresh when it receives this
            session.transferUserInfo(message)
            print("[iOS] Queued section completion for Watch: \(section)")
        }
    }

    /// Notify Watch that user logged out on iPhone - Watch should clear its credentials
    func notifyWatchLogout() {
        guard let session = session else {
            log("Cannot notify Watch of logout - no session", level: .error)
            return
        }

        let message: [String: Any] = [
            "action": "userLogout",
            "timestamp": Date().timeIntervalSince1970
        ]

        log("Sending logout notification to Watch")

        // Use transferUserInfo for guaranteed delivery even if Watch isn't currently reachable
        // This ensures Watch clears credentials even if it was asleep during logout
        session.transferUserInfo(message)
        log("Queued logout via transferUserInfo (guaranteed delivery)")

        // Also try sendMessage for immediate effect if Watch is reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] reply in
                self?.log("Watch acknowledged logout immediately", level: .success)
            }) { [weak self] error in
                self?.log("Watch not reachable for immediate logout", level: .warning)
            }
        }
    }

    /// Notify Watch that a check-in was completed on iPhone (for Energy/Mood/Focus sync)
    func notifyWatchCheckInCompleted(timeSlot: CheckInTimeSlot, date: String) {
        guard let session = session else {
            log("Cannot notify Watch of check-in - no session", level: .error)
            return
        }

        let message: [String: Any] = [
            "action": "checkInCompleted",
            "timeSlot": timeSlot.rawValue,
            "date": date,
            "source": "ios",
            "timestamp": Date().timeIntervalSince1970
        ]

        log("Sending check-in completion to Watch: \(timeSlot.rawValue)")

        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] _ in
                self?.log("Watch acknowledged check-in sync", level: .success)
            }) { [weak self] error in
                self?.log("Check-in sendMessage failed, using transferUserInfo", level: .warning)
                session.transferUserInfo(message)
            }
        } else {
            // Queue for later delivery
            session.transferUserInfo(message)
            log("Queued check-in completion via transferUserInfo (Watch not reachable)")
        }
    }

    /// Sync notification time preferences to Watch (for midday and evening check-ins)
    func syncNotificationTimesToWatch() {
        guard let session = session, session.isWatchAppInstalled else {
            log("Cannot sync - Watch not installed", level: .warning)
            return
        }

        let defaults = UserDefaults.standard
        let message: [String: Any] = [
            "action": "notificationTimesUpdate",
            "middayHour": defaults.integer(forKey: NotificationManager.middayCheckInReminderHourKey),
            "middayMinute": defaults.integer(forKey: NotificationManager.middayCheckInReminderMinuteKey),
            "eveningHour": defaults.integer(forKey: NotificationManager.eveningCheckInReminderHourKey),
            "eveningMinute": defaults.integer(forKey: NotificationManager.eveningCheckInReminderMinuteKey),
            "timestamp": Date().timeIntervalSince1970
        ]

        session.transferUserInfo(message)
        log("Synced notification times to Watch (midday: \(defaults.integer(forKey: NotificationManager.middayCheckInReminderHourKey)):\(String(format: "%02d", defaults.integer(forKey: NotificationManager.middayCheckInReminderMinuteKey))), evening: \(defaults.integer(forKey: NotificationManager.eveningCheckInReminderHourKey)):\(String(format: "%02d", defaults.integer(forKey: NotificationManager.eveningCheckInReminderMinuteKey))))")
    }

    // MARK: - Handle Watch Requests

    private func handleWatchMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        guard let action = message["action"] as? String else {
            replyHandler?(["error": "No action specified"])
            return
        }

        switch action {
        case "requestUserData":
            handleRequestUserData(replyHandler: replyHandler)

        case "requestCurrentDayQuestions":
            handleRequestCurrentDayQuestions(replyHandler: replyHandler)

        case "saveQuestionnaireResponses":
            handleSaveResponses(message, replyHandler: replyHandler)

        case "advanceDay":
            handleAdvanceDay(replyHandler: replyHandler)

        case "requestRecommendations":
            handleRequestRecommendations(replyHandler: replyHandler)

        case "requestTreatmentTasks":
            handleRequestTreatmentTasks(replyHandler: replyHandler)

        case "completeTreatmentTask":
            handleCompleteTreatmentTask(message, replyHandler: replyHandler)

        case "resetJourneyProgress":
            handleResetJourneyProgress(replyHandler: replyHandler)

        case "sectionCompleted":
            handleSectionCompleted(message, replyHandler: replyHandler)

        case "checkInCompleted":
            handleCheckInCompleted(message, replyHandler: replyHandler)

        default:
            replyHandler?(["error": "Unknown action: \(action)"])
        }
    }

    private func handleSectionCompleted(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        let section = message["section"] as? String ?? "unknown"
        let dayNumber = message["dayNumber"] as? Int ?? 0

        print("[iOS] Watch completed section '\(section)' for day \(dayNumber)")

        // Post notification to trigger immediate refresh on dashboard
        NotificationCenter.default.post(
            name: .questionnaireProgressDidChange,
            object: nil,
            userInfo: ["section": section, "dayNumber": dayNumber, "source": "watch"]
        )

        replyHandler?(["received": true])
    }

    /// Handle check-in completion notification from Watch
    private func handleCheckInCompleted(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        guard let timeSlotStr = message["timeSlot"] as? String,
              let date = message["date"] as? String,
              let timeSlot = CheckInTimeSlot(rawValue: timeSlotStr) else {
            replyHandler?(["error": "Invalid check-in data"])
            return
        }

        print("[iOS] Watch completed \(timeSlotStr) check-in for \(date)")

        // Update CheckInManager state
        Task { @MainActor in
            CheckInManager.shared.handleWatchCheckInCompletion(timeSlot: timeSlot, date: date)
        }

        // Post notification for UI refresh
        NotificationCenter.default.post(
            name: .checkInStatusDidChange,
            object: nil,
            userInfo: ["timeSlot": timeSlotStr, "date": date, "source": "watch"]
        )

        replyHandler?(["received": true])
    }

    // MARK: - Request Handlers

    private func handleRequestUserData(replyHandler: (([String: Any]) -> Void)?) {
        let response: [String: Any] = [
            "isAuthenticated": ConvexService.shared.isAuthenticated,
            "currentDay": questionnaireManager.currentDay
        ]
        replyHandler?(response)
    }

    private func handleRequestCurrentDayQuestions(replyHandler: (([String: Any]) -> Void)?) {
        let currentDay = questionnaireManager.currentDay

        // Get questions for current day
        let questions = questionnaireManager.getQuestionsForDay(currentDay)

        // Filter to only Watch-compatible question types and Stanford Sleep Log
        let watchQuestions = questions.filter { question in
            // Include Sleep Log questions (they work great on Watch)
            if question.group == "sleep_log" {
                return true
            }
            // Include simple question types
            switch question.questionType {
            case .scale, .yesNo, .singleSelect:
                return true
            default:
                return false
            }
        }

        // Check if day is already completed
        let completedDays = questionnaireManager.journeyProgress?.completedDays ?? []
        let isDayCompleted = completedDays.contains(currentDay)

        // Convert to Watch-compatible format
        let questionsData: [[String: Any]] = isDayCompleted ? [] : watchQuestions.map { question in
            var data: [String: Any] = [
                "id": question.id,
                "text": question.text,
                "type": mapQuestionTypeForWatch(question.questionType)
            ]
            if let options = question.options {
                data["options"] = options
            }
            return data
        }

        let response: [String: Any] = [
            "day": currentDay,
            "questions": questionsData,
            "isDayCompleted": isDayCompleted
        ]
        replyHandler?(response)
    }

    private func mapQuestionTypeForWatch(_ type: QuestionType) -> String {
        switch type {
        case .scale, .numberScroll, .minutesScroll, .hoursMinutesScroll, .number:
            return "scale"
        case .yesNo, .yesNoDontKnow:
            return "radio"
        case .singleSelect:
            return "radio"
        case .multiSelect, .medicationSelect, .caffeineSelect:
            return "checkbox"
        case .text, .email:
            return "text"
        case .time:
            return "time"
        case .date:
            return "date"
        case .info, .repeatingGroup, .napDetails:
            return "text"
        case .prescriptionMedSelect, .supplementSelect, .surgeryDetails:
            // These complex types are not suitable for Watch - display as text
            return "text"
        }
    }

    private func handleSaveResponses(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        guard let day = message["day"] as? Int,
              let responses = message["responses"] as? [String: Any] else {
            replyHandler?(["success": false, "error": "Invalid data"])
            return
        }

        // Save responses to QuestionnaireManager
        for (questionId, value) in responses {
            let response = QuestionResponse(
                questionId: questionId,
                dayNumber: day,
                stringValue: value as? String,
                numberValue: value as? Double,
                arrayValue: value as? [String],
                answeredAt: Date()
            )
            questionnaireManager.saveResponse(response)
        }

        // TODO: Sync to Convex
        replyHandler?(["success": true])
    }

    private func handleAdvanceDay(replyHandler: (([String: Any]) -> Void)?) {
        let newDay = min(questionnaireManager.currentDay + 1, 15)
        questionnaireManager.currentDay = newDay

        replyHandler?(["newDay": newDay])
    }

    private func handleRequestRecommendations(replyHandler: (([String: Any]) -> Void)?) {
        // TODO: Fetch from Convex
        // For now, return empty array
        replyHandler?(["recommendations": []])
    }

    private func handleRequestTreatmentTasks(replyHandler: (([String: Any]) -> Void)?) {
        // TODO: Fetch from Convex treatment tasks
        // For now, return sample tasks if user has completed intake
        let currentDay = questionnaireManager.currentDay

        // Only show tasks after completing the intake journey
        if currentDay <= Config.totalJourneyDays {
            replyHandler?(["tasks": []])
            return
        }

        // Sample tasks (in production, fetch from Convex)
        let tasks: [[String: Any]] = [
            [
                "id": "1",
                "name": "Morning Light",
                "timing": "Morning",
                "shortInstructions": "30 min bright light exposure",
                "isCompleted": false
            ],
            [
                "id": "2",
                "name": "Caffeine Cutoff",
                "timing": "Afternoon",
                "shortInstructions": "No caffeine after 2 PM",
                "isCompleted": false
            ],
            [
                "id": "3",
                "name": "Wind Down",
                "timing": "Evening",
                "shortInstructions": "Start relaxation routine",
                "isCompleted": false
            ]
        ]

        replyHandler?(["tasks": tasks])
    }

    private func handleCompleteTreatmentTask(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        guard let taskId = message["taskId"] as? String else {
            replyHandler?(["success": false])
            return
        }

        // TODO: Update task completion in Convex
        print("Task \(taskId) completed from Watch")
        replyHandler?(["success": true])
    }

    private func handleResetJourneyProgress(replyHandler: (([String: Any]) -> Void)?) {
        // Always reset local state first (works even without Convex)
        questionnaireManager.currentDay = 1
        questionnaireManager.journeyProgress = nil
        questionnaireManager.responses = [:]
        questionnaireManager.initializeGatewayStates()

        print("Journey progress reset locally from Watch")

        // Try to also reset in Convex (but don't fail if it doesn't work)
        Task {
            do {
                _ = try await ConvexService.shared.resetJourneyProgress()
                print("Journey progress also reset in Convex")
            } catch {
                print("Convex reset failed (local reset still applied): \(error)")
            }
        }

        replyHandler?(["success": true, "newDay": 1])
    }
}

// MARK: - WCSessionDelegate

extension iOSWatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            // isWatchConnected should reflect actual reachability, not just activation state
            // session.isReachable indicates the Watch is paired, app installed, and currently reachable
            self.isWatchConnected = activationState == .activated && session.isReachable

            #if os(iOS)
            // Update app installed state from session
            self.isWatchAppInstalled = session.isWatchAppInstalled
            #endif

            if let error = error {
                self.log("Activation failed: \(error.localizedDescription)", level: .error)
            } else {
                let stateStr = activationState == .activated ? "activated" : (activationState == .inactive ? "inactive" : "notActivated")
                self.log("Session \(stateStr), reachable: \(session.isReachable), appInstalled: \(session.isWatchAppInstalled)", level: .success)
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.log("Session became inactive", level: .warning)
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.log("Session deactivated - reactivating...", level: .warning)
        }
        // Reactivate for switching watches
        DispatchQueue.main.async {
            self.session?.activate()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            let wasConnected = self.isWatchConnected
            self.isWatchConnected = session.isReachable
            self.log("Reachability changed: \(wasConnected) → \(session.isReachable)", level: session.isReachable ? .success : .warning)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            let action = message["action"] as? String ?? "unknown"
            self.log("Received from Watch: \(action)")
            self.handleWatchMessage(message, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            let action = message["action"] as? String ?? "unknown"
            self.log("Received from Watch: \(action) (no reply)")
            self.handleWatchMessage(message, replyHandler: nil)
        }
    }

    #if os(iOS)
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.log("Watch app installed: \(session.isWatchAppInstalled)", level: session.isWatchAppInstalled ? .success : .warning)
        }
    }
    #endif
}

// MARK: - iOS Connectivity Log Entry

struct iOSConnectivityLogEntry: Identifiable {
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
