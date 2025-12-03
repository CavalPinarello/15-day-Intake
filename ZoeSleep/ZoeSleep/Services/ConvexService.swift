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
    // Profile data from server
    let fullName: String?
    let measurementSystem: String?
    let heightCm: Double?
    let weightKg: Double?
    let gender: String?
    let birthYear: Double?  // Convex returns numbers as Double

    // Computed property to get currentDay as Int
    var currentDayInt: Int {
        return Int(currentDay)
    }

    // Computed property to get birthYear as Int
    var birthYearInt: Int? {
        guard let year = birthYear else { return nil }
        return Int(year)
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
    let startedAt: Int?  // Optional - watch:getJourneyState doesn't return this
    // Section completion status for current day
    let sleepLogCompleted: Bool?
    let assessmentCompleted: Bool?
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

struct CompleteSectionResponse: Codable {
    let success: Bool
    let section: String
    let sleepLogCompleted: Bool
    let assessmentCompleted: Bool
    let dayFullyCompleted: Bool
    let currentDay: Int
    let journeyComplete: Bool
    let source: String?
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
                // Handle null values
                if value is NSNull {
                    // For optional types, return empty data that decodes to nil
                    let emptyData = "null".data(using: .utf8)!
                    return try decoder.decode(T.self, from: emptyData)
                }

                // Check if value is JSON-serializable before re-encoding
                if JSONSerialization.isValidJSONObject(value) {
                    let valueData = try JSONSerialization.data(withJSONObject: value)
                    return try decoder.decode(T.self, from: valueData)
                } else if let stringValue = value as? String {
                    // Handle primitive string values
                    let quotedString = "\"\(stringValue)\""
                    let valueData = quotedString.data(using: .utf8)!
                    return try decoder.decode(T.self, from: valueData)
                } else if let numberValue = value as? NSNumber {
                    // Handle primitive number values
                    let valueData = "\(numberValue)".data(using: .utf8)!
                    return try decoder.decode(T.self, from: valueData)
                } else if let boolValue = value as? Bool {
                    // Handle primitive bool values
                    let valueData = (boolValue ? "true" : "false").data(using: .utf8)!
                    return try decoder.decode(T.self, from: valueData)
                }
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

        // Automatically load saved session on init
        if let token = KeychainHelper.load(forKey: "convex_session_token"),
           let userId = KeychainHelper.load(forKey: "convex_user_id") {
            self.sessionToken = token
            self.currentUserId = userId
            print("[ConvexService] Auto-loaded session for userId: \(userId)")
        } else {
            print("[ConvexService] No saved session found")
        }
    }

    // MARK: - Session Management

    func setSession(token: String, userId: String, username: String? = nil) {
        self.sessionToken = token
        self.currentUserId = userId
        KeychainHelper.save(token, forKey: "convex_session_token")
        KeychainHelper.save(userId, forKey: "convex_user_id")
        if let username = username {
            KeychainHelper.save(username, forKey: "convex_username")
        }
        print("[ConvexService] Session saved for userId: \(userId)")

        // Sync credentials to Watch immediately after login
        if let username = username {
            Task { @MainActor in
                iOSWatchConnectivityManager.shared.syncCredentialsToWatch(userId: userId, username: username)
            }
        }
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
        setSession(token: response.sessionToken, userId: response.userId, username: response.user.username)
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

        // Use watch:getJourneyState which includes section completion status
        return try await client.query("watch:getJourneyState", args: ["userId": userId])
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

    /// Complete a specific section (sleepLog or assessment) for a day
    func completeSection(dayNumber: Int, section: String) async throws -> CompleteSectionResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("watch:completeSection", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section,
            "source": "ios"
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
        let newDay: Int?
        let previousDay: Int?
        let error: String?
        let sleepLogCompleted: Bool?
        let assessmentCompleted: Bool?
        let timeUnlocked: Bool?
        let currentDay: Int?
    }

    struct CanAdvanceDayResponse: Codable {
        let canAdvance: Bool
        let reason: String
        let sleepLogCompleted: Bool
        let assessmentCompleted: Bool
        let timeUnlocked: Bool
        let currentDay: Int?
        let nextDay: Int?
    }

    struct ResetProgressResponse: Codable {
        let success: Bool
        let newDay: Int?
    }

    struct JourneyDebugInfo: Codable {
        let currentDay: Int
        let completedDays: [Int]
        let responsesCount: Int
        let gateways: [String]
        let journeyComplete: Bool
    }

    /// Check if user can advance to the next day
    /// Requirements: Both Sleep Log AND Assessment must be completed
    /// In debug mode: Bypasses time check but NOT completion check
    func canAdvanceDay(debugMode: Bool = false) async throws -> CanAdvanceDayResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("watch:canAdvanceDay", args: [
            "userId": userId,
            "debugMode": debugMode
        ])
    }

    /// Advance user to the next day
    /// STRICT: Both sections must be completed first
    /// - debugMode: true bypasses time check (4 AM) but NOT completion check
    func advanceToNextDay(debugMode: Bool = false) async throws -> AdvanceDayResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("watch:advanceDay", args: [
            "userId": userId,
            "debugMode": debugMode
        ])
    }

    /// Advance user to a specific day number (convenience method)
    /// Uses advanceToNextDay internally - validates completion first
    func advanceDay(to dayNumber: Int, debugMode: Bool = false) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        // Use watch:advanceDay which validates completion
        let response: AdvanceDayResponse = try await client.mutation("watch:advanceDay", args: [
            "userId": userId,
            "debugMode": debugMode
        ])

        if !response.success {
            throw ConvexError.serverError(response.error ?? "Cannot advance day")
        }
    }

    /// Reset journey progress to Day 1 (Debug Mode only)
    func resetJourneyProgress() async throws -> ResetProgressResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("watch:resetProgress", args: ["userId": userId])
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

    // MARK: - Cross-Device Question Progress Sync

    struct QuestionProgress: Codable {
        let currentQuestionIndex: Int
        let totalQuestions: Int
        let lastDevice: String
        let lastUpdatedAt: Double
        let completed: Bool
    }

    struct SavedResponses: Codable {
        // Dynamic dictionary - will be decoded manually
    }

    /// Get the current question progress for a section (to resume where user left off)
    func getQuestionProgress(dayNumber: Int, section: String) async throws -> QuestionProgress? {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        do {
            return try await client.query("watch:getQuestionProgress", args: [
                "userId": userId,
                "dayNumber": dayNumber,
                "section": section
            ])
        } catch {
            // If query fails or returns null, return nil - don't crash
            print("[iOS] getQuestionProgress error: \(error), returning nil")
            return nil
        }
    }

    /// Update question progress after answering a question
    func updateQuestionProgress(dayNumber: Int, section: String, questionIndex: Int, totalQuestions: Int) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        let _: SuccessResponse = try await client.mutation("watch:updateQuestionProgress", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section,
            "currentQuestionIndex": questionIndex,
            "totalQuestions": totalQuestions,
            "device": "ios"
        ])
    }

    /// Mark a section's question progress as complete
    func completeQuestionProgress(dayNumber: Int, section: String) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        let _: SuccessResponse = try await client.mutation("watch:completeQuestionProgress", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section,
            "device": "ios"
        ])
    }

    struct ResponseValue: Codable {
        let stringValue: String?
        let numberValue: Double?
        let arrayValue: [String]?
    }

    struct SaveResponsesResult: Codable {
        let success: Bool
        let savedCount: Int
    }

    /// Batch save responses to Convex (called before completing a section)
    /// This ensures server-side validation can verify responses exist
    func saveResponses(dayNumber: Int, responses: [[String: Any]]) async throws -> SaveResponsesResult {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("watch:saveResponses", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "responses": responses,
            "source": "ios"
        ])
    }

    /// Get all saved responses for a day (to pre-fill answers when resuming)
    func getSavedResponses(dayNumber: Int) async throws -> [String: QuestionResponseValue] {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        // Query returns a dictionary of questionId -> response values
        // Handle case where response might be empty or null
        do {
            let rawResponse: [String: ResponseValue] = try await client.query("watch:getSavedResponses", args: [
                "userId": userId,
                "dayNumber": dayNumber
            ])

            var result: [String: QuestionResponseValue] = [:]
            for (questionId, values) in rawResponse {
                result[questionId] = QuestionResponseValue(
                    stringValue: values.stringValue,
                    numberValue: values.numberValue,
                    arrayValue: values.arrayValue
                )
            }
            return result
        } catch {
            // If we fail to decode, return empty - don't crash
            print("[iOS] getSavedResponses decode error: \(error), returning empty")
            return [:]
        }
    }
}

struct QuestionResponseValue {
    let stringValue: String?
    let numberValue: Double?
    let arrayValue: [String]?
}

// MARK: - Day Metadata with Contextual Explanations

struct ModuleMetadata: Codable {
    let title: String
    let shortTitle: String
    let icon: String
    let estimatedMinutes: Int
    let questionCount: Int
    let color: String
    let description: String
    let why: String
    let isCompleted: Bool?
}

struct DayMetadataResponse: Codable {
    let sleepLog: ModuleMetadata
    let assessment: ModuleMetadata
    let totalMinutes: Int
    let totalQuestions: Int
    let triggeredExpansions: [String]
}

extension ConvexService {
    /// Get metadata for a specific day including time estimates and explanations
    func getDayMetadata(dayNumber: Int) async throws -> DayMetadataResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("watch:getDayMetadata", args: [
            "userId": userId,
            "dayNumber": dayNumber
        ])
    }
}

// MARK: - Unified Question Fetching (Single Source of Truth)

struct ConvexQuestion: Codable {
    let id: String
    let text: String
    let type: String
    let required: Bool
    let options: [String]?
    let helpText: String?
    let moduleName: String?
    let formatConfig: [String: AnyCodable]?
}

struct QuestionsForDayResponse: Codable {
    let sleepLog: [ConvexQuestion]
    let assessment: [ConvexQuestion]
    let metadata: QuestionsMetadata
}

struct QuestionsMetadata: Codable {
    let sleepLogCount: Int
    let assessmentCount: Int
    let totalMinutes: Int
    let triggeredGateways: [String]
    let dayDescription: String
    let dayExplanation: String
}

struct ConvexGatewayState: Codable {
    let gatewayId: String
    let isTriggered: Bool
    let triggerQuestionId: String?
    let triggerValue: String?
    let triggeredAt: Double?
}

/// Helper to decode Any values from JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            try container.encodeNil()
        }
    }
}

extension ConvexService {
    /// THE SINGLE SOURCE OF TRUTH - Get all questions for a user's day from Convex
    /// This is what iOS, Watch, and Web should ALL use to get questions.
    func getQuestionsForUserDay(dayNumber: Int, section: String = "all") async throws -> QuestionsForDayResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("watch:getQuestionsForUserDay", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section
        ])
    }

    /// Update gateway state when a gateway-triggering response is detected
    func updateGatewayState(gatewayId: String, isTriggered: Bool, triggerQuestionId: String?, triggerValue: String?) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId,
            "gatewayId": gatewayId,
            "isTriggered": isTriggered
        ]
        if let questionId = triggerQuestionId {
            args["triggerQuestionId"] = questionId
        }
        if let value = triggerValue {
            args["triggerValue"] = value
        }

        let _: SuccessResponse = try await client.mutation("watch:updateGatewayState", args: args)
    }

    /// Get all gateway states for the current user
    func getGatewayStates() async throws -> [ConvexGatewayState] {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("watch:getGatewayStates", args: [
            "userId": userId
        ])
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
