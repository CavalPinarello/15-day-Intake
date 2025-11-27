//
//  WatchConnectivityManager.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Manages communication between Apple Watch and iPhone
//  for questionnaire sync and data exchange
//

import WatchConnectivity
import Foundation
import Combine

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isUserAuthenticated = false
    @Published var currentUserDay = 1
    
    private var session: WCSession?
    private var pendingCallbacks: [String: (Any?) -> Void] = [:]
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    func activate() {
        session?.activate()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
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
    
    func requestCurrentDayQuestions(completion: @escaping (Int, [Question]) -> Void) {
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
    }
    
    private func parseQuestion(from data: [String: Any]) -> Question? {
        guard let id = data["id"] as? String,
              let text = data["text"] as? String,
              let typeString = data["type"] as? String,
              let type = Question.QuestionType(rawValue: typeString) else {
            return nil
        }
        
        let options = data["options"] as? [String]
        
        return Question(id: id, text: text, type: type, options: options)
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
                print("Watch connectivity activation failed: \(error.localizedDescription)")
            } else {
                print("Watch connectivity activated successfully")
                self.requestDataFromiPhone()
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleIncomingMessage(message, replyHandler: replyHandler)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleIncomingMessage(message, replyHandler: nil)
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
            replyHandler?(["received": true])
            
        case "recommendationUpdate":
            // Handle real-time recommendation updates
            replyHandler?(["received": true])
            
        case "dayAdvanced":
            if let newDay = message["newDay"] as? Int {
                currentUserDay = newDay
            }
            replyHandler?(["received": true])
            
        default:
            replyHandler?(["error": "Unknown action: \(action)"])
        }
    }
}