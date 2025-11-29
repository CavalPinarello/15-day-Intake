//
//  WatchConvexService.swift
//  Zoe Sleep for Longevity System - watchOS
//
//  Direct Convex integration for Apple Watch
//  Enables real-time sync of questionnaire progress between devices
//

import Foundation
import WatchKit

// MARK: - Response Models

struct WatchJourneyState: Codable {
    let currentDay: Int
    let completedDays: [Int]
    let journeyComplete: Bool
    let totalDays: Int
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

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        // Load saved credentials
        loadSavedCredentials()
    }

    // MARK: - Credentials Management

    private func loadSavedCredentials() {
        if let savedUserId = UserDefaults.standard.string(forKey: "convexUserId"),
           let savedUsername = UserDefaults.standard.string(forKey: "convexUsername") {
            self.userId = savedUserId
            self.username = savedUsername
            self.isAuthenticated = true
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
        // Simple hash for password (matches iOS app)
        let passwordHash = simpleHash(password)

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

    private func simpleHash(_ string: String) -> String {
        // Simple hash matching the iOS app's password hashing
        // In production, use proper crypto
        var hash: Int = 0
        for char in string.unicodeScalars {
            hash = ((hash << 5) &- hash) &+ Int(char.value)
        }
        return String(format: "%x", abs(hash))
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
}
