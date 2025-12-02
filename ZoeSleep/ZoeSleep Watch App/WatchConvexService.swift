//
//  WatchConvexService.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Direct Convex integration for Apple Watch
//  Enables real-time sync of questionnaire progress between devices
//

import Foundation
import WatchKit
import CryptoKit

// MARK: - Response Models

struct WatchJourneyState: Codable {
    let currentDay: Int
    let completedDays: [Int]
    let journeyComplete: Bool
    let totalDays: Int
    // Section-level completion for current day
    let sleepLogCompleted: Bool?
    let assessmentCompleted: Bool?
}

struct WatchCompleteSectionResponse: Codable {
    let success: Bool
    let section: String
    let sleepLogCompleted: Bool
    let assessmentCompleted: Bool
    let dayFullyCompleted: Bool
    let currentDay: Int
    let journeyComplete: Bool
    let source: String?
}

struct WatchCompleteDayResponse: Codable {
    let success: Bool
    let newDay: Int
    let journeyComplete: Bool
    let source: String?
}

struct WatchAdvanceDayResponse: Codable {
    let success: Bool
    let previousDay: Int
    let newDay: Int
}

struct WatchResetResponse: Codable {
    let success: Bool
    let newDay: Int
}

struct WatchSaveResponseResult: Codable {
    let success: Bool
    let savedCount: Int?
}

struct WatchQuestionProgress: Codable {
    let currentQuestionIndex: Int
    let totalQuestions: Int
    let lastDevice: String
    let lastUpdatedAt: Double
    let completed: Bool
}

struct WatchResponseValue: Codable {
    let stringValue: String?
    let numberValue: Double?
    let arrayValue: [String]?
}

struct WatchUserInfo: Codable {
    let userId: String
    let username: String
    let currentDay: Int
    let onboardingCompleted: Bool
}

struct WatchUserLookup: Codable {
    let userId: String
    let username: String
    let currentDay: Int
    let onboardingCompleted: Bool
    let passwordHash: String
}

struct WatchUserState: Codable {
    let currentDay: Int
    let completedDaysCount: Int
    let onboardingCompleted: Bool
    let lastAccessed: Double?
}

// MARK: - Convex Error

enum WatchConvexError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case notAuthenticated
    case decodingError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Convex URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .notAuthenticated:
            return "User not authenticated"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Watch Convex Service

class WatchConvexService: ObservableObject {
    static let shared = WatchConvexService()

    // Convex deployment URL - same as iOS app
    private let baseURL = "https://enchanted-terrier-633.convex.cloud"

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // User state
    @Published var isAuthenticated = false
    @Published var userId: String?
    @Published var username: String?
    @Published var currentDay: Int = 1
    @Published var completedDays: [Int] = []
    @Published var journeyComplete = false
    // Section-level completion for current day
    @Published var sleepLogCompleted = false
    @Published var assessmentCompleted = false

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        // Load any saved credentials (may have been synced from iPhone)
        loadSavedCredentials()

        // If not authenticated from saved credentials, wait for iPhone to sync credentials
        // This ensures Watch uses the same account as iPhone
        if !isAuthenticated {
            print("[WatchConvex] Not authenticated - waiting for iPhone to sync credentials")
        }
    }

    // MARK: - Credentials Management

    private func loadSavedCredentials() {
        if let savedUserId = UserDefaults.standard.string(forKey: "convexUserId") {
            self.userId = savedUserId
            self.username = UserDefaults.standard.string(forKey: "convexUsername")
            self.isAuthenticated = true
            print("[WatchConvex] Loaded saved credentials - userId: \(savedUserId)")
        }
    }

    /// Refresh journey state from Convex (called on app activation)
    /// Auto-logs in as user3 for development/simulator testing if not authenticated
    func refreshFromConvex() async {
        // Auto-login for development if not authenticated
        if !isAuthenticated {
            print("[WatchConvex] Not authenticated - auto-logging in as user3 for development")
            do {
                let userInfo = try await signIn(username: "user3", password: "1")
                print("[WatchConvex] Auto-logged in as \(userInfo.username), Day \(userInfo.currentDay)")
            } catch {
                print("[WatchConvex] Auto-login failed: \(error)")
                return
            }
        }

        do {
            _ = try await fetchJourneyState()
            print("[WatchConvex] Refreshed state: Day \(currentDay)")
        } catch {
            print("[WatchConvex] Failed to refresh: \(error)")
        }
    }

    /// Update credentials (called when receiving userId from iPhone via WatchConnectivity)
    func updateUserId(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: "convexUserId")
        self.userId = userId
        self.isAuthenticated = true
        print("[WatchConvex] Updated userId from iPhone: \(userId)")

        // Fetch current journey state with new credentials
        Task {
            do {
                _ = try await fetchJourneyState()
            } catch {
                print("[WatchConvex] Failed to fetch state after userId update: \(error)")
            }
        }
    }

    /// Update credentials from iPhone login (called from WatchConnectivityManager)
    func updateCredentialsFromiPhone(userId: String, username: String?) {
        // Save to UserDefaults
        UserDefaults.standard.set(userId, forKey: "convexUserId")
        if let username = username {
            UserDefaults.standard.set(username, forKey: "convexUsername")
        }

        // Update published properties on main thread
        Task { @MainActor in
            self.userId = userId
            self.username = username
            self.isAuthenticated = true
            print("[WatchConvex] ✅ Synced credentials from iPhone: userId=\(userId), username=\(username ?? "nil")")

            // Fetch current journey state
            do {
                _ = try await self.fetchJourneyState()
                print("[WatchConvex] Fetched state after iPhone sync: Day \(self.currentDay)")
            } catch {
                print("[WatchConvex] Failed to fetch state after iPhone sync: \(error)")
            }
        }
    }

    private func saveCredentials(userId: String, username: String) {
        UserDefaults.standard.set(userId, forKey: "convexUserId")
        UserDefaults.standard.set(username, forKey: "convexUsername")
        self.userId = userId
        self.username = username
        self.isAuthenticated = true
    }

    func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: "convexUserId")
        UserDefaults.standard.removeObject(forKey: "convexUsername")
        self.userId = nil
        self.username = nil
        self.isAuthenticated = false
    }

    // MARK: - HTTP Request Helper

    private func request<T: Decodable>(
        path: String,
        functionName: String,
        args: [String: Any]
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw WatchConvexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "path": functionName,
            "args": args
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        print("[WatchConvex] Request: \(functionName)")
        print("[WatchConvex] Args: \(args)")
        #endif

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WatchConvexError.invalidResponse
            }

            #if DEBUG
            print("[WatchConvex] Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[WatchConvex] Response: \(responseString.prefix(500))")
            }
            #endif

            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorResponse["error"] as? String {
                    throw WatchConvexError.serverError(errorMessage)
                }
                throw WatchConvexError.httpError(httpResponse.statusCode)
            }

            // Convex wraps response in { "value": ... }
            if let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let value = wrapper["value"] {
                    // Handle null values - check if value is NSNull
                    if value is NSNull {
                        // For optional types, this will fail gracefully
                        throw WatchConvexError.invalidResponse
                    }
                    // Ensure value is JSON-serializable before proceeding
                    guard JSONSerialization.isValidJSONObject(value) || value is String || value is NSNumber || value is Bool else {
                        throw WatchConvexError.decodingError("Response value is not JSON-serializable")
                    }
                    let valueData = try JSONSerialization.data(withJSONObject: value)
                    return try decoder.decode(T.self, from: valueData)
                }
            }

            return try decoder.decode(T.self, from: data)
        } catch let error as WatchConvexError {
            throw error
        } catch let decodingError as DecodingError {
            throw WatchConvexError.decodingError(decodingError.localizedDescription)
        } catch {
            throw WatchConvexError.networkError(error.localizedDescription)
        }
    }

    private func query<T: Decodable>(_ functionName: String, args: [String: Any] = [:]) async throws -> T {
        return try await request(path: "/api/query", functionName: functionName, args: args)
    }

    private func mutation<T: Decodable>(_ functionName: String, args: [String: Any] = [:]) async throws -> T {
        return try await request(path: "/api/mutation", functionName: functionName, args: args)
    }

    // MARK: - Authentication

    /// Sign in with username and password
    func signIn(username: String, password: String) async throws -> WatchUserInfo {
        // SHA256 hash for password (matches database - seeded with SHA256)
        let passwordHash = sha256Hash(password)

        let response: WatchUserInfo = try await mutation("watch:signIn", args: [
            "username": username,
            "passwordHash": passwordHash
        ])

        saveCredentials(userId: response.userId, username: response.username)

        await MainActor.run {
            self.currentDay = response.currentDay
            self.journeyComplete = response.onboardingCompleted
        }

        return response
    }

    /// Check if username exists and get user info
    func lookupUser(username: String) async throws -> WatchUserLookup? {
        let result: WatchUserLookup? = try await query("watch:getUserByUsername", args: [
            "username": username
        ])
        return result
    }

    private func sha256Hash(_ string: String) -> String {
        // SHA256 hash to match the database (test users seeded with SHA256)
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Journey State

    /// Get current journey state from Convex
    func fetchJourneyState() async throws -> WatchJourneyState {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        let state: WatchJourneyState = try await query("watch:getJourneyState", args: [
            "userId": userId
        ])

        await MainActor.run {
            self.currentDay = state.currentDay
            self.completedDays = state.completedDays
            self.journeyComplete = state.journeyComplete
            // Update section completion status for current day
            self.sleepLogCompleted = state.sleepLogCompleted ?? false
            self.assessmentCompleted = state.assessmentCompleted ?? false
        }

        return state
    }

    /// Check if a specific day is completed
    func isDayCompleted(dayNumber: Int) async throws -> Bool {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        struct BoolResponse: Codable {
            // Convex returns raw boolean
        }

        let result: Bool = try await query("watch:isDayCompleted", args: [
            "userId": userId,
            "dayNumber": dayNumber
        ])

        return result
    }

    /// Get user's current state (for polling)
    func getUserState() async throws -> WatchUserState {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        return try await query("watch:getUserState", args: [
            "userId": userId
        ])
    }

    // MARK: - Day Completion

    /// Mark a day as completed
    func completeDay(dayNumber: Int) async throws -> WatchCompleteDayResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        let response: WatchCompleteDayResponse = try await mutation("watch:completeDay", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "source": "watch"
        ])

        await MainActor.run {
            if response.success {
                if !self.completedDays.contains(dayNumber) {
                    self.completedDays.append(dayNumber)
                    self.completedDays.sort()
                }
                self.currentDay = response.newDay
                self.journeyComplete = response.journeyComplete
            }
        }

        return response
    }

    /// Mark a section as completed (sleepLog or assessment)
    func completeSection(dayNumber: Int, section: String) async throws -> WatchCompleteSectionResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        let response: WatchCompleteSectionResponse = try await mutation("watch:completeSection", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section,
            "source": "watch"
        ])

        await MainActor.run {
            if response.success {
                self.sleepLogCompleted = response.sleepLogCompleted
                self.assessmentCompleted = response.assessmentCompleted

                if response.dayFullyCompleted {
                    if !self.completedDays.contains(dayNumber) {
                        self.completedDays.append(dayNumber)
                        self.completedDays.sort()
                    }
                    self.currentDay = response.currentDay
                    self.journeyComplete = response.journeyComplete
                    // Reset section completion for the new day
                    if response.currentDay != dayNumber {
                        self.sleepLogCompleted = false
                        self.assessmentCompleted = false
                    }
                }
            }
        }

        return response
    }

    /// Advance to next day (Debug Mode)
    func advanceDay() async throws -> WatchAdvanceDayResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        let response: WatchAdvanceDayResponse = try await mutation("watch:advanceDay", args: [
            "userId": userId
        ])

        await MainActor.run {
            if response.success {
                if !self.completedDays.contains(response.previousDay) {
                    self.completedDays.append(response.previousDay)
                    self.completedDays.sort()
                }
                self.currentDay = response.newDay
            }
        }

        return response
    }

    /// Reset journey progress (Debug Mode)
    func resetProgress() async throws -> WatchResetResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        let response: WatchResetResponse = try await mutation("watch:resetProgress", args: [
            "userId": userId
        ])

        await MainActor.run {
            if response.success {
                self.currentDay = 1
                self.completedDays = []
                self.journeyComplete = false
            }
        }

        return response
    }

    // MARK: - Questionnaire Responses

    /// Save a single response
    func saveResponse(
        questionId: String,
        dayNumber: Int,
        stringValue: String? = nil,
        numberValue: Double? = nil,
        arrayValue: [String]? = nil
    ) async throws {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId,
            "questionId": questionId,
            "dayNumber": dayNumber,
            "source": "watch"
        ]

        if let str = stringValue {
            args["responseValue"] = str
        }
        if let num = numberValue {
            args["responseNumber"] = num
        }
        if let arr = arrayValue {
            args["responseArray"] = arr
        }

        struct SuccessResponse: Codable {
            let success: Bool
        }

        let _: SuccessResponse = try await mutation("watch:saveResponse", args: args)
    }

    /// Save multiple responses at once
    func saveResponses(dayNumber: Int, responses: [[String: Any]]) async throws -> Int {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        // Convert responses to the expected format
        var formattedResponses: [[String: Any]] = []
        for response in responses {
            var formatted: [String: Any] = [:]
            if let questionId = response["questionId"] as? String {
                formatted["questionId"] = questionId
            }
            if let stringValue = response["responseValue"] as? String {
                formatted["responseValue"] = stringValue
            }
            if let numberValue = response["responseNumber"] as? Double {
                formatted["responseNumber"] = numberValue
            }
            if let arrayValue = response["responseArray"] as? [String] {
                formatted["responseArray"] = arrayValue
            }
            formattedResponses.append(formatted)
        }

        let result: WatchSaveResponseResult = try await mutation("watch:saveResponses", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "responses": formattedResponses,
            "source": "watch"
        ])

        return result.savedCount ?? responses.count
    }

    // MARK: - Cross-Device Question Progress Sync

    /// Get the current question progress for a section (to resume where user left off)
    func getQuestionProgress(dayNumber: Int, section: String) async throws -> WatchQuestionProgress? {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        return try await query("watch:getQuestionProgress", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section
        ])
    }

    /// Update question progress after answering a question
    func updateQuestionProgress(dayNumber: Int, section: String, questionIndex: Int, totalQuestions: Int) async throws {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        struct SuccessResult: Codable {
            let success: Bool
            let questionIndex: Int
        }

        let _: SuccessResult = try await mutation("watch:updateQuestionProgress", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section,
            "currentQuestionIndex": questionIndex,
            "totalQuestions": totalQuestions,
            "device": "watch"
        ])
    }

    /// Get all saved responses for a day (to pre-fill answers when resuming)
    func getSavedResponses(dayNumber: Int) async throws -> [String: WatchResponseValue] {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        return try await query("watch:getSavedResponses", args: [
            "userId": userId,
            "dayNumber": dayNumber
        ])
    }
}
