//
//  ConvexService.swift
//  Zoe Sleep for Longevity System
//
//  Convex backend service for direct iOS integration
//  Uses URLSession for HTTP calls to Convex backend
//

import Foundation
import Combine
import UIKit

// MARK: - Convex Configuration

struct ConvexConfig {
    static var deploymentUrl: String {
        return Config.convexDeploymentURL
    }

    static var isDebugMode: Bool {
        return Config.isDebugMode
    }
}

// MARK: - Data Models

struct ConvexUser: Codable {
    let username: String
    let email: String?
    let currentDay: Double  // Convex returns as Double
    let role: String?
    let onboardingCompleted: Bool?
    let appleHealthConnected: Bool?

    // Computed property to get currentDay as Int
    var currentDayInt: Int {
        return Int(currentDay)
    }
}

struct SignInResponse: Codable {
    let userId: String
    let sessionToken: String
    let expiresAt: Double  // Convex returns as Double
    let user: ConvexUser

    // Computed property to get expiresAt as Int
    var expiresAtInt: Int {
        return Int(expiresAt)
    }
}

struct SignInWithAppleResponse: Codable {
    let userId: String
    let sessionToken: String
    let expiresAt: Double
    let isNewUser: Bool
    let user: ConvexUser
}

struct RegisterResponse: Codable {
    let userId: String
    let sessionToken: String
    let expiresAt: Double
    let user: ConvexUser
}

struct ValidateSessionResponse: Codable {
    let valid: Bool
    let reason: String?
    let userId: String?
    let user: ConvexUser?
}

struct UserProfile: Codable {
    let userId: String
    let username: String
    let email: String?
    let currentDay: Int
    let startedAt: Int
    let role: String?
    let onboardingCompleted: Bool?
    let appleHealthConnected: Bool?
    let profilePicture: String?
    let preferences: UserPreferences?
}

struct UserPreferences: Codable {
    let notificationEnabled: Bool?
    let notificationTime: String?
    let quietHoursStart: String?
    let quietHoursEnd: String?
    let timezone: String?
    let appleHealthSyncEnabled: Bool?
    let dailyReminderEnabled: Bool?
}

struct JourneyProgress: Codable {
    let currentDay: Int
    let completedDays: [Int]
    let totalDays: Int
    let journeyComplete: Bool?
    let startedAt: Int
}

struct SleepDataRecord: Codable {
    let date: String
    let inBedTime: Int?
    let asleepTime: Int?
    let wakeTime: Int?
    let totalSleepMins: Int?
    let sleepEfficiency: Double?
    let deepSleepMins: Int?
    let lightSleepMins: Int?
    let remSleepMins: Int?
    let awakeMins: Int?
    let interruptionsCount: Int?
    let sleepLatencyMins: Int?
}

struct CompleteDayResponse: Codable {
    let success: Bool
    let newDay: Int
    let journeyComplete: Bool?
}

struct SuccessResponse: Codable {
    let success: Bool
}

struct RefreshSessionResponse: Codable {
    let sessionToken: String
    let expiresAt: Int
}

struct SyncResponse: Codable {
    let success: Bool
    let recordsSynced: Int?
}

// MARK: - Convex HTTP Client

/// HTTP client for making requests to Convex backend
private class ConvexHTTPClient {
    let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(deploymentUrl: String) {
        // Convert deployment URL to HTTP endpoint
        // Convex URLs like "https://xxx.convex.cloud" need /api/query or /api/mutation
        self.baseURL = deploymentUrl

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func query<T: Decodable>(_ functionName: String, args: [String: Any] = [:]) async throws -> T {
        return try await request(path: "/api/query", functionName: functionName, args: args)
    }

    func mutation<T: Decodable>(_ functionName: String, args: [String: Any] = [:]) async throws -> T {
        return try await request(path: "/api/mutation", functionName: functionName, args: args)
    }

    private func request<T: Decodable>(path: String, functionName: String, args: [String: Any]) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw ConvexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convex expects { "path": "functionName", "args": {...} }
        let body: [String: Any] = [
            "path": functionName,
            "args": args
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if ConvexConfig.isDebugMode {
            print("Convex Request: \(functionName)")
            print("Args: \(args)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConvexError.invalidResponse
        }

        if ConvexConfig.isDebugMode {
            print("Convex Response Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString.prefix(500))")
            }
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorResponse["error"] as? String {
                throw ConvexError.serverError(errorMessage)
            }
            throw ConvexError.httpError(httpResponse.statusCode)
        }

        // Convex wraps response in { "value": ... } or { "status": "success", "value": ... }
        if let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let value = wrapper["value"] {
                // Re-encode the value and decode to target type
                let valueData = try JSONSerialization.data(withJSONObject: value)
                return try decoder.decode(T.self, from: valueData)
            }
        }

        // Try direct decode
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Convex Service

/// ConvexService provides direct integration with the Convex backend
class ConvexService {
    static let shared = ConvexService()

    private let client: ConvexHTTPClient

    // Session management
    private var sessionToken: String?
    private var currentUserId: String?

    private init() {
        self.client = ConvexHTTPClient(deploymentUrl: Config.convexDeploymentURL)
    }

    // MARK: - Session Management

    func setSession(token: String, userId: String) {
        self.sessionToken = token
        self.currentUserId = userId
        KeychainHelper.save(token, forKey: "convex_session_token")
        KeychainHelper.save(userId, forKey: "convex_user_id")
    }

    func clearSession() {
        self.sessionToken = nil
        self.currentUserId = nil
        KeychainHelper.delete(forKey: "convex_session_token")
        KeychainHelper.delete(forKey: "convex_user_id")
    }

    func loadSavedSession() -> (token: String, userId: String)? {
        guard let token = KeychainHelper.load(forKey: "convex_session_token"),
              let userId = KeychainHelper.load(forKey: "convex_user_id") else {
            return nil
        }
        self.sessionToken = token
        self.currentUserId = userId
        return (token, userId)
    }

    var isAuthenticated: Bool {
        return sessionToken != nil && currentUserId != nil
    }

    var userId: String? {
        return currentUserId
    }

    // MARK: - Authentication

    func signIn(identifier: String, passwordHash: String, deviceId: String, deviceInfo: DeviceInfo? = nil) async throws -> SignInResponse {
        var args: [String: Any] = [
            "identifier": identifier,
            "passwordHash": passwordHash,
            "deviceId": deviceId
        ]

        if let info = deviceInfo {
            args["deviceInfo"] = [
                "deviceName": info.deviceName as Any,
                "deviceModel": info.deviceModel as Any,
                "osVersion": info.osVersion as Any,
                "appVersion": info.appVersion as Any
            ]
        }

        let response: SignInResponse = try await client.mutation("ios:signIn", args: args)
        setSession(token: response.sessionToken, userId: response.userId)
        return response
    }

    func signInWithApple(
        appleUserId: String,
        identityToken: String,
        email: String?,
        fullName: String?,
        deviceId: String,
        deviceInfo: DeviceInfo? = nil
    ) async throws -> SignInWithAppleResponse {
        var args: [String: Any] = [
            "appleUserId": appleUserId,
            "identityToken": identityToken,
            "deviceId": deviceId
        ]

        if let email = email {
            args["email"] = email
        }
        if let fullName = fullName {
            args["fullName"] = fullName
        }
        if let info = deviceInfo {
            args["deviceInfo"] = [
                "deviceName": info.deviceName as Any,
                "deviceModel": info.deviceModel as Any,
                "osVersion": info.osVersion as Any,
                "appVersion": info.appVersion as Any
            ]
        }

        let response: SignInWithAppleResponse = try await client.mutation("ios:signInWithApple", args: args)
        setSession(token: response.sessionToken, userId: response.userId)
        return response
    }

    func register(
        email: String,
        username: String,
        passwordHash: String,
        deviceId: String,
        deviceInfo: DeviceInfo? = nil
    ) async throws -> RegisterResponse {
        var args: [String: Any] = [
            "email": email,
            "username": username,
            "passwordHash": passwordHash,
            "deviceId": deviceId
        ]

        if let info = deviceInfo {
            args["deviceInfo"] = [
                "deviceName": info.deviceName as Any,
                "deviceModel": info.deviceModel as Any,
                "osVersion": info.osVersion as Any,
                "appVersion": info.appVersion as Any
            ]
        }

        let response: RegisterResponse = try await client.mutation("ios:register", args: args)
        setSession(token: response.sessionToken, userId: response.userId)
        return response
    }

    func validateSession() async throws -> ValidateSessionResponse {
        guard let token = sessionToken else {
            return ValidateSessionResponse(valid: false, reason: "No session", userId: nil, user: nil)
        }

        return try await client.query("ios:validateSession", args: ["sessionToken": token])
    }

    func signOut() async throws {
        guard let token = sessionToken else { return }

        let _: SuccessResponse = try await client.mutation("ios:signOut", args: ["sessionToken": token])
        clearSession()
    }

    func refreshSession() async throws {
        guard let token = sessionToken else {
            throw ConvexError.notAuthenticated
        }

        let response: RefreshSessionResponse = try await client.mutation("ios:refreshSession", args: ["sessionToken": token])

        if ConvexConfig.isDebugMode {
            print("Session refreshed, expires at: \(response.expiresAt)")
        }
    }

    // MARK: - Device Management

    func registerPushToken(deviceToken: String, deviceId: String) async throws {
        guard let token = sessionToken else {
            throw ConvexError.notAuthenticated
        }

        let _: SuccessResponse = try await client.mutation("ios:registerPushToken", args: [
            "sessionToken": token,
            "deviceToken": deviceToken,
            "deviceId": deviceId
        ])
    }

    // MARK: - User Profile

    func getUserProfile() async throws -> UserProfile {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("ios:getUserProfile", args: ["userId": userId])
    }

    func updateUserProfile(updates: [String: Any]) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        let _: SuccessResponse = try await client.mutation("ios:updateUserProfile", args: [
            "userId": userId,
            "updates": updates
        ])
    }

    func updateUserPreferences(preferences: [String: Any]) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        let _: SuccessResponse = try await client.mutation("ios:updateUserPreferences", args: [
            "userId": userId,
            "preferences": preferences
        ])
    }

    // MARK: - HealthKit Sync

    func syncSleepData(deviceId: String, sleepData: [[String: Any]]) async throws -> SyncResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("ios:syncSleepData", args: [
            "userId": userId,
            "deviceId": deviceId,
            "sleepData": sleepData
        ])
    }

    func syncHeartRateData(deviceId: String, heartRateData: [[String: Any]]) async throws -> SyncResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("ios:syncHeartRateData", args: [
            "userId": userId,
            "deviceId": deviceId,
            "heartRateData": heartRateData
        ])
    }

    func syncActivityData(deviceId: String, activityData: [[String: Any]]) async throws -> SyncResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("ios:syncActivityData", args: [
            "userId": userId,
            "deviceId": deviceId,
            "activityData": activityData
        ])
    }

    func getRecentSleepData(days: Int = 7) async throws -> [SleepDataRecord] {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("ios:getRecentSleepData", args: [
            "userId": userId,
            "days": days
        ])
    }

    // MARK: - Questionnaire/Journey

    func getJourneyProgress() async throws -> JourneyProgress {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("ios:getJourneyProgress", args: ["userId": userId])
    }

    func completeDay(dayNumber: Int) async throws -> CompleteDayResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("ios:completeDay", args: [
            "userId": userId,
            "dayNumber": dayNumber
        ])
    }

    func submitQuestionnaireResponse(
        questionId: String,
        answerFormat: String,
        value: Any?,
        arrayValue: [String]? = nil,
        objectValue: String? = nil,
        dayNumber: Int,
        answeredInSeconds: Int? = nil
    ) async throws -> String {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId,
            "questionId": questionId,
            "answerFormat": answerFormat,
            "dayNumber": dayNumber
        ]

        if let v = value {
            args["value"] = v
        }
        if let arr = arrayValue {
            args["arrayValue"] = arr
        }
        if let obj = objectValue {
            args["objectValue"] = obj
        }
        if let secs = answeredInSeconds {
            args["answeredInSeconds"] = secs
        }

        return try await client.mutation("ios:submitQuestionnaireResponse", args: args)
    }

    // MARK: - Debug / Day Advancement

    struct AdvanceDayResponse: Codable {
        let success: Bool
        let newDay: Int
        let previousDay: Int
        let message: String
    }

    struct ResetProgressResponse: Codable {
        let success: Bool
        let message: String
    }

    struct JourneyDebugInfo: Codable {
        let currentDay: Int
        let completedDays: [Int]
        let responsesCount: Int
        let gateways: [String]
        let journeyComplete: Bool
    }

    /// Advance user to the next day (Debug Mode only)
    func advanceToNextDay() async throws -> AdvanceDayResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("ios:advanceToNextDay", args: ["userId": userId])
    }

    /// Reset journey progress to Day 1 (Debug Mode only)
    func resetJourneyProgress() async throws -> ResetProgressResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("ios:resetJourneyProgress", args: ["userId": userId])
    }

    /// Get debug information about the user's journey
    func getJourneyDebugInfo() async throws -> JourneyDebugInfo {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("ios:getJourneyDebugInfo", args: ["userId": userId])
    }

    // MARK: - Analytics

    func trackEvent(
        eventType: String,
        deviceId: String,
        eventData: [String: Any]? = nil,
        screenName: String? = nil,
        sessionId: String? = nil
    ) async throws {
        var args: [String: Any] = [
            "eventType": eventType,
            "deviceId": deviceId
        ]

        if let userId = currentUserId {
            args["userId"] = userId
        }
        if let data = eventData {
            args["eventData"] = try String(data: JSONSerialization.data(withJSONObject: data), encoding: .utf8)
        }
        if let screen = screenName {
            args["screenName"] = screen
        }
        if let session = sessionId {
            args["sessionId"] = session
        }

        let _: SuccessResponse = try await client.mutation("ios:trackEvent", args: args)
    }
}

// MARK: - Device Info

struct DeviceInfo {
    let deviceName: String?
    let deviceModel: String?
    let osVersion: String?
    let appVersion: String?

    static var current: DeviceInfo {
        return DeviceInfo(
            deviceName: UIDevice.current.name,
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
    }
}

// MARK: - Errors

enum ConvexError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case notAuthenticated
    case decodingError

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
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - Keychain Helper

class KeychainHelper {
    static func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
