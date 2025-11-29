//
//  WatchConnectivityManager.swift
//  Zoe Sleep for Longevity System - iOS
//
//  Manages communication between iPhone and Apple Watch
//  Responds to Watch requests and syncs data bidirectionally
//

import WatchConnectivity
import Foundation
import Combine

@preconcurrency import WatchConnectivity

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

    private var session: WCSession?
    private var questionnaireManager: QuestionnaireManager { QuestionnaireManager.shared }

    private override init() {
        super.init()
        setupWatchConnectivity()
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

    /// Send updated user data to Watch
    func sendUserDataToWatch() {
        updateCachedThemeValues()
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "action": "userDataUpdate",
            "isAuthenticated": ConvexService.shared.isAuthenticated,
            "currentDay": questionnaireManager.currentDay,
            "accentColor": cachedAccentColor,
            "appearanceMode": cachedAppearanceMode,
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send user data to Watch: \(error.localizedDescription)")
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
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "action": "dayAdvanced",
            "newDay": newDay,
            "timestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to notify Watch of day advance: \(error.localizedDescription)")
        }
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

        default:
            replyHandler?(["error": "Unknown action: \(action)"])
        }
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
        case .scale, .numberScroll, .minutesScroll, .number:
            return "scale"
        case .yesNo, .yesNoDontKnow:
            return "radio"
        case .singleSelect:
            return "radio"
        case .multiSelect:
            return "checkbox"
        case .text, .email:
            return "text"
        case .time:
            return "time"
        case .date:
            return "date"
        case .info, .repeatingGroup:
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

        // Only show tasks after completing the 15-day intake
        if currentDay <= 15 {
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
            self.isWatchConnected = activationState == .activated

            if let error = error {
                print("WatchConnectivity activation failed: \(error.localizedDescription)")
            } else {
                print("WatchConnectivity activated successfully")
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("WatchConnectivity session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("WatchConnectivity session deactivated")
        // Reactivate for switching watches
        DispatchQueue.main.async {
            self.session?.activate()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = session.isReachable
            print("Watch reachability changed: \(session.isReachable)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleWatchMessage(message, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleWatchMessage(message, replyHandler: nil)
        }
    }

    #if os(iOS)
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            print("Watch app installed: \(session.isWatchAppInstalled)")
        }
    }
    #endif
}
