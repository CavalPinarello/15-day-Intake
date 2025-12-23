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
    // Profile data from server (may be missing for new users)
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

    // Custom decoder to handle missing optional keys
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        currentDay = try container.decode(Double.self, forKey: .currentDay)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
        appleHealthConnected = try container.decodeIfPresent(Bool.self, forKey: .appleHealthConnected)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        measurementSystem = try container.decodeIfPresent(String.self, forKey: .measurementSystem)
        heightCm = try container.decodeIfPresent(Double.self, forKey: .heightCm)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        birthYear = try container.decodeIfPresent(Double.self, forKey: .birthYear)
    }

    private enum CodingKeys: String, CodingKey {
        case username, email, currentDay, role, onboardingCompleted, appleHealthConnected
        case fullName, measurementSystem, heightCm, weightKg, gender, birthYear
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

/// Response type for daily completion status (catch-up feature)
struct DailyCompletionStatus: Codable {
    struct DayStatus: Codable {
        let dayNumber: Int
        let sleepLogCompleted: Bool
        let assessmentCompleted: Bool
        let sleepLogCount: Int
        let assessmentCount: Int
    }

    struct MissedDay: Codable {
        let dayNumber: Int
        let missingSleepLog: Bool
        let missingAssessment: Bool
    }

    let currentDay: Int
    let dailyStatus: [DayStatus]
    let missedDays: [MissedDay]
    let hasMissedTasks: Bool
    let totalMissedSleepLogs: Int
    let totalMissedAssessments: Int
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
        // Check for error responses first (Convex returns 200 even for errors)
        if let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Check if this is an error response
            if let status = wrapper["status"] as? String, status == "error" {
                if let errorMessage = wrapper["errorMessage"] as? String {
                    // Extract the actual error message (remove request ID and stack trace)
                    let cleanError = errorMessage
                        .components(separatedBy: "Uncaught Error: ").last?
                        .components(separatedBy: "\n").first ?? errorMessage
                    throw ConvexError.serverError(cleanError)
                }
                throw ConvexError.serverError("Unknown server error")
            }

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
                    do {
                        return try decoder.decode(T.self, from: valueData)
                    } catch let decodingError as DecodingError {
                        print("❌ Decoding error: \(decodingError)")
                        if let jsonString = String(data: valueData, encoding: .utf8) {
                            print("📦 Raw JSON: \(jsonString)")
                        }
                        // Extract specific missing key info
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            print("🔑 Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        case .typeMismatch(let type, let context):
                            print("🔄 Type mismatch: expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        case .valueNotFound(let type, let context):
                            print("❓ Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        default:
                            break
                        }
                        throw decodingError
                    } catch {
                        print("❌ Unknown decoding error: \(error)")
                        throw error
                    }
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
        passwordHash: String,
        deviceId: String,
        deviceInfo: DeviceInfo? = nil
    ) async throws -> RegisterResponse {
        var args: [String: Any] = [
            "email": email,
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

    /// Get detailed daily completion status for all days (catch-up feature)
    /// Returns which days have missed sleep logs or assessments
    func getDailyCompletionStatus() async throws -> DailyCompletionStatus {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("ios:getDailyCompletionStatus", args: ["userId": userId])
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
    let conditionalLogic: ConvexConditionalLogic?
}

struct ConvexConditionalLogic: Codable {
    let questionId: String
    let equals: String?
    let greaterThan: Double?

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case equals
        case greaterThan = "greater_than"
    }

    // Also support snake_case "show_if" format from database
    init(from decoder: Decoder) throws {
        // Try direct format first
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.questionId = try container.decode(String.self, forKey: .questionId)
            self.equals = try container.decodeIfPresent(String.self, forKey: .equals)
            self.greaterThan = try container.decodeIfPresent(Double.self, forKey: .greaterThan)
        } else {
            // Try show_if format
            let showIfContainer = try decoder.container(keyedBy: ShowIfKeys.self)
            let showIf = try showIfContainer.decode(ShowIfContent.self, forKey: .showIf)
            self.questionId = showIf.questionId
            self.equals = showIf.value
            self.greaterThan = showIf.greaterThan
        }
    }

    private enum ShowIfKeys: String, CodingKey {
        case showIf = "show_if"
    }

    private struct ShowIfContent: Codable {
        let questionId: String
        let value: String?
        let greaterThan: Double?

        enum CodingKeys: String, CodingKey {
            case questionId = "question_id"
            case value
            case greaterThan = "greater_than"
        }
    }
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

// MARK: - Sleep Insights Response Types

struct SleepDashboardSummary: Codable {
    let daysOfData: Int
    let hasEnoughForInsights: Bool
    let hasEnoughForPatterns: Bool
    let daysUntilInsights: Int
    let daysUntilPatterns: Int
    let weeklyAverage: WeeklyAverageData
    let lastNight: LastNightData?
    let lastSyncTime: Double?

    struct WeeklyAverageData: Codable {
        let sleepMins: Int
        let efficiency: Int
        let deepMins: Int
        let remMins: Int
    }

    struct LastNightData: Codable {
        let date: String
        let totalSleepMins: Int?
        let efficiency: Double?
        let deepMins: Int?
        let remMins: Int?
        let primarySource: String?
    }
}

struct PerceptionVsRealityData: Codable {
    let daysCount: Int
    let comparisonsCount: Int
    let comparisons: [DailyComparisonData]
    let lastNightSubjective: SubjectiveData?
    let lastNightObjective: ObjectiveData?
    let lastNightDate: String?
    let correlation: Double?
    let gapTrend: GapTrendData?

    struct DailyComparisonData: Codable {
        let date: String
        let subjective: SubjectiveData
        let objective: ObjectiveData
        let gap: GapData
    }

    struct SubjectiveData: Codable {
        let quality: Double
    }

    struct ObjectiveData: Codable {
        let totalSleepMins: Int
        let efficiency: Double
        let deepSleepMins: Int?
        let remSleepMins: Int?
    }

    struct GapData: Codable {
        let gap: Double
        let direction: String
        let magnitude: Double
    }

    struct GapTrendData: Codable {
        let avgGap: Double
        let consistentUnderestimate: Bool
        let confidence: Double
    }
}

struct SleepPatternsData: Codable {
    let workdayWeekend: WorkdayWeekendData?
    let optimalBedtime: OptimalBedtimeData?
    let sleepStages: SleepStagesData?
    let dataPoints: Int

    struct WorkdayWeekendData: Codable {
        let workdayAvgSleep: Int
        let weekendAvgSleep: Int
        let workdayAvgDeep: Int
        let weekendAvgDeep: Int
        let workdayAvgEfficiency: Int
        let weekendAvgEfficiency: Int
        let sleepDifference: Int
        let deepDifference: Int
    }

    struct OptimalBedtimeData: Codable {
        let time: String
        let avgLatencyMinutes: Int
        let latencyDiff: Int
        let confidence: Double
    }

    struct SleepStagesData: Codable {
        let avgDeepPercent: Double
        let avgRemPercent: Double
        let avgLightPercent: Double
        let deepBelowRecommended: Bool
        let remBelowRecommended: Bool
    }
}

struct GeneratedInsight: Codable {
    let id: String
    let type: String
    let title: String
    let text: String
    let confidence: Double
    let actionable: Bool
}

// MARK: - Sleep Insights Queries

extension ConvexService {
    /// Get dashboard summary with day counts and weekly averages
    func getSleepDashboardSummary() async throws -> SleepDashboardSummary {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("sleepInsights:getDashboardSummary", args: [
            "userId": userId
        ])
    }

    /// Get perception vs reality comparison data
    func getPerceptionVsReality(days: Int = 14) async throws -> PerceptionVsRealityData {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("sleepInsights:getPerceptionVsReality", args: [
            "userId": userId,
            "days": days
        ])
    }

    /// Detect sleep patterns (workday vs weekend, optimal bedtime, stages)
    func detectSleepPatterns() async throws -> SleepPatternsData? {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("sleepInsights:detectPatterns", args: [
            "userId": userId
        ])
    }

    /// Generate actionable insights
    func generateSleepInsights() async throws -> [GeneratedInsight] {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("sleepInsights:generateInsights", args: [
            "userId": userId
        ])
    }
}

// MARK: - Dashboard Data Computation (for Mock Generator)

extension ConvexService {
    /// Compute sleep metrics from CSD responses and save to user_sleep_data table
    /// This populates the dashboard's sleep data visualizations
    func computeSleepMetricsFromResponses(dayNumber: Int, date: String) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        let _: SuccessResponse = try await client.mutation("healthkit:computeSleepMetricsFromResponses", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "date": date
        ])
    }

    /// Retroactively compute sleep metrics for ALL existing CSD_ questionnaire responses
    /// This populates the dashboard's sleep data from historical questionnaire data
    func computeAllSleepMetricsFromResponses() async throws -> Int {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        struct ComputeResult: Decodable {
            let success: Bool
            let daysProcessed: Int
        }

        let result: ComputeResult = try await client.mutation("healthkit:computeAllSleepMetricsFromResponses", args: [
            "userId": userId
        ])

        return result.daysProcessed
    }

    /// Persist calculated questionnaire scores to questionnaire_scores table
    /// This populates the dashboard's clinical scores section
    func persistCalculatedScores() async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        let _: SuccessResponse = try await client.mutation("physician:persistCalculatedScores", args: [
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

// MARK: - Treatment Types

struct ActiveIntervention: Codable, Identifiable {
    let _id: String
    let intervention_id: String
    let name: String
    let category: String?
    let instructions: String
    let start_date: String
    let end_date: String?
    let frequency: String?
    let timing: String?
    let custom_instructions: String?
    let status: String
    let todayCompleted: Bool

    var id: String { _id }
}

struct TreatmentPhaseInfo: Codable {
    let phase: String
    let intakeDay: Int
    let intakeComplete: Bool
    let treatmentStartDate: String?
    let treatmentWeek: Int?
    let activeInterventionCount: Int
}

struct ComplianceHistoryDay: Codable {
    let date: String
    let totalTasks: Int
    let completedTasks: Int
    let tasks: [TaskCompletion]

    struct TaskCompletion: Codable {
        let name: String
        let completed: Bool
        let completedAt: Double?
    }
}

struct TasksSummary: Codable {
    let totalTasks: Int
    let completedTasks: Int
    let pendingTasks: Int
    let completionPercentage: Int
    let nextTask: NextTask?

    struct NextTask: Codable {
        let name: String
        let timing: String?
        let instructions: String
    }
}

struct CompleteTaskResponse: Codable {
    let complianceId: String
}

struct AddNoteResponse: Codable {
    let noteId: String
}

// MARK: - Treatment Queries

extension ConvexService {
    /// Get all active treatment tasks for today
    func getActiveInterventions() async throws -> [ActiveIntervention] {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("treatment:getActiveInterventions", args: [
            "userId": userId
        ])
    }

    /// Get treatment phase info (intake, treatment, completed)
    func getTreatmentPhase() async throws -> TreatmentPhaseInfo {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("treatment:getTreatmentPhase", args: [
            "userId": userId
        ])
    }

    /// Get today's tasks summary
    func getTodayTasksSummary() async throws -> TasksSummary {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("treatment:getTodayTasksSummary", args: [
            "userId": userId
        ])
    }

    /// Get compliance history for past N days
    func getComplianceHistory(days: Int = 7) async throws -> [ComplianceHistoryDay] {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("treatment:getComplianceHistory", args: [
            "userId": userId,
            "days": days
        ])
    }

    /// Complete a treatment task
    func completeTask(userInterventionId: String, note: String? = nil) async throws -> String {
        var args: [String: Any] = [
            "userInterventionId": userInterventionId
        ]
        if let note = note {
            args["note"] = note
        }

        let response: CompleteTaskResponse = try await client.mutation("treatment:completeTask", args: args)
        return response.complianceId
    }

    /// Uncomplete a treatment task (undo)
    func uncompleteTask(userInterventionId: String) async throws {
        let _: SuccessResponse = try await client.mutation("treatment:uncompleteTask", args: [
            "userInterventionId": userInterventionId
        ])
    }

    /// Add a note to a treatment task
    func addTaskNote(userInterventionId: String, noteText: String, moodRating: Int? = nil) async throws -> String {
        var args: [String: Any] = [
            "userInterventionId": userInterventionId,
            "noteText": noteText
        ]
        if let mood = moodRating {
            args["moodRating"] = mood
        }

        let response: AddNoteResponse = try await client.mutation("treatment:addTaskNote", args: args)
        return response.noteId
    }
}

// MARK: - Multi-Source Sleep Data Types

struct MultiSourceSleepData: Codable {
    let hasMultipleSources: Bool
    let sources: [String]
    let sourceStats: [SourceStat]
    let comparisonData: [ComparisonDataPoint]
    let totalDays: Int

    struct SourceStat: Codable {
        let source: String
        let dataPoints: Int
        let avgEfficiency: Double?
        let avgSleepHours: Double?
        let hasDeepSleep: Bool
        let hasHeartRate: Bool
    }

    struct ComparisonDataPoint: Codable {
        let date: String
        let sources: [String: SourceDayData?]

        struct SourceDayData: Codable {
            let totalSleepMins: Int?
            let efficiency: Double?
            let deepMins: Int?
            let remMins: Int?
            let lightMins: Int?
        }
    }
}

struct SourceDetail: Codable {
    let source: String
    let hasSleepStages: Bool
    let hasHeartRate: Bool
    let hasHrv: Bool
    let qualityScore: Int
}

// MARK: - Multi-Source Sleep Data Queries

extension ConvexService {
    /// Get multi-source sleep data for comparison chart
    func getMultiSourceSleepData(days: Int = 15) async throws -> MultiSourceSleepData {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("healthkit:getMultiSourceSleepData", args: [
            "userId": userId,
            "days": days
        ])
    }

    /// Get source details (capabilities for each wearable)
    func getSourceDetails() async throws -> [SourceDetail] {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("healthkit:getSourceDetails", args: [
            "userId": userId
        ])
    }
}

// MARK: - Expansion Schedule Types

struct ExpansionModuleInfo: Codable {
    let id: String
    let name: String
    let instrument: String
    let questionCount: Int
    let estimatedMinutes: Int
    let priority: Int
}

struct ExpansionDayInfo: Codable {
    let dayNumber: Int
    let modules: [ExpansionModuleInfo]
    let totalQuestions: Int
    let estimatedMinutes: Int
    let completed: Bool
}

struct ExpansionScheduleSummary: Codable {
    let hasSchedule: Bool
    let triggeredGateways: [String]
    let totalDays: Int
    let totalQuestions: Int
    let totalMinutes: Int?
    let completedDays: Int
    let remainingDays: Int
    let dayAssignments: [DayAssignmentSummary]?

    struct DayAssignmentSummary: Codable {
        let dayNumber: Int
        let questionCount: Int
        let estimatedMinutes: Int
        let completed: Bool
    }
}

// MARK: - Expansion Scheduler Queries

extension ConvexService {
    /// Get expansion modules scheduled for a specific day
    /// Returns nil if no expansion is scheduled for this day
    func getExpansionForDay(dayNumber: Int) async throws -> ExpansionDayInfo? {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("expansionScheduler:getExpansionForDay", args: [
            "userId": userId,
            "dayNumber": dayNumber
        ])
    }

    /// Get full expansion schedule summary
    func getExpansionScheduleSummary() async throws -> ExpansionScheduleSummary {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("expansionScheduler:getScheduleSummary", args: [
            "userId": userId
        ])
    }

    /// Mark a day's expansion modules as completed
    func markDayExpansionCompleted(dayNumber: Int) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        let _: SuccessResponse = try await client.mutation("expansionScheduler:markDayExpansionCompleted", args: [
            "userId": userId,
            "dayNumber": dayNumber
        ])
    }

    /// Preview expansion schedule for given gateways (doesn't persist)
    /// Used for testing schedule computation before running full journey
    func previewExpansionSchedule(triggeredGateways: [String]) async throws -> SchedulePreviewResponse {
        return try await client.query("expansionScheduler:previewSchedule", args: [
            "triggeredGateways": triggeredGateways
        ])
    }
}

// MARK: - Schedule Preview Response

struct SchedulePreviewResponse: Codable {
    let triggeredGateways: [String]
    let dayAssignments: [PreviewDayAssignment]
    let totalQuestions: Int
    let totalMinutes: Int
    let averageQuestionsPerDay: Int

    struct PreviewDayAssignment: Codable {
        let dayNumber: Int
        let questionCount: Int
        let estimatedMinutes: Int
        let moduleIds: [String]
        let modules: [PreviewModule]

        struct PreviewModule: Codable {
            let id: String
            let name: String
            let instrument: String?
        }
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

// MARK: - Journey Phase Response Types

struct JourneyStatusResponse: Codable {
    let phase: String
    let currentDay: Int?
    let analysisStage: Int?
    let treatmentActive: Bool?
}

struct AnalysisProgressResponse: Codable {
    let currentStage: Int
    let stages: [AnalysisStageData]?

    struct AnalysisStageData: Codable {
        let id: Int
        let title: String
        let description: String
        let icon: String
        let isComplete: Bool
        let isCurrent: Bool
    }
}

struct TransitionResponse: Codable {
    let success: Bool
    let newPhase: String?
    let message: String?
}

struct InsightResponse: Codable {
    let id: String
    let title: String
    let category: String
    let icon: String
    let color: String?
    let isUnlocked: Bool
    let daysUntilUnlock: Int?
    let lockedDescription: String?
    let unlockedDescription: String?
    let discoveryHint: String?
    let discoveryHintLevel: Int?
    let dataPointsCollected: Int?
}

struct TasksByWindowResponse: Codable {
    let morning: [TaskData]?
    let afternoon: [TaskData]?
    let evening: [TaskData]?
    let night: [TaskData]?
    let currentWindow: String?

    struct TaskData: Codable {
        let id: String
        let title: String?
        let description: String?
        let taskName: String?
        let taskInstructions: String?
        let timeWindow: String?
        let status: String?
        let scheduledTime: String?
        let priority: Int?
        let interventionId: String?
        let isLocked: Bool?
        let unlocksAt: String?
        let isCompleted: Bool?

        // Use CodingKeys to map snake_case from backend
        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case title
            case description
            case taskName = "task_name"
            case taskInstructions = "task_instructions"
            case timeWindow = "time_window"
            case status
            case scheduledTime = "scheduled_time"
            case priority
            case interventionId = "intervention_id"
            case isLocked
            case unlocksAt
            case isCompleted
        }
    }
}

struct TaskActionResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Journey Phase Management

extension ConvexService {
    /// Get the current journey phase status
    func getJourneyStatus(userId: String) async throws -> JourneyStatusResponse {
        return try await client.query("journey:getJourneyStatus", args: [
            "userId": userId
        ])
    }

    /// Get analysis progress stages
    func getAnalysisProgress(userId: String) async throws -> AnalysisProgressResponse {
        return try await client.query("journey:getAnalysisProgress", args: [
            "userId": userId
        ])
    }

    /// Transition from intake to analysis phase
    func transitionToAnalysis(userId: String) async throws -> TransitionResponse {
        return try await client.mutation("journey:transitionToAnalysis", args: [
            "userId": userId
        ])
    }

    /// Advance analysis stage (for testing/debug)
    func advanceAnalysisStage(userId: String, newStage: Int) async throws -> TransitionResponse {
        return try await client.mutation("journey:advanceAnalysisStage", args: [
            "userId": userId,
            "newStage": newStage
        ])
    }
}

// MARK: - Progressive Insights

extension ConvexService {
    /// Get all progressive insights with unlock status
    func getProgressiveInsights(userId: String) async throws -> [InsightResponse] {
        return try await client.query("insights:getProgressiveInsights", args: [
            "userId": userId
        ])
    }

    /// Get the next insight teaser to show
    func getNextInsightTeaser(userId: String) async throws -> InsightResponse? {
        return try await client.query("insights:getNextInsightTeaser", args: [
            "userId": userId
        ])
    }

    /// Get discovery hints based on patterns
    func getDiscoveryHints(userId: String, dayNumber: Int) async throws -> [InsightResponse] {
        return try await client.query("insights:getDiscoveryHints", args: [
            "userId": userId,
            "dayNumber": dayNumber
        ])
    }

    /// Initialize insight progress for user
    func initializeInsightProgress(userId: String) async throws -> SuccessResponse {
        return try await client.mutation("insights:initializeInsightProgress", args: [
            "userId": userId
        ])
    }
}

// MARK: - Treatment Tasks (Time-Windowed)

extension ConvexService {
    /// Get tasks grouped by time window
    func getTasksByTimeWindow(userId: String) async throws -> TasksByWindowResponse {
        return try await client.query("interventionLibrary:getTasksByTimeWindow", args: [
            "userId": userId
        ])
    }

    /// Complete a task (with time window enforcement)
    func completeTask(taskId: String, difficultyRating: Int?, notes: String?) async throws -> TaskActionResponse {
        var args: [String: Any] = ["taskId": taskId]
        if let rating = difficultyRating {
            args["difficultyRating"] = rating
        }
        if let noteText = notes {
            args["notes"] = noteText
        }
        return try await client.mutation("interventionLibrary:completeTask", args: args)
    }

    /// Skip a task
    func skipTask(taskId: String, reason: String?) async throws -> TaskActionResponse {
        var args: [String: Any] = ["taskId": taskId]
        if let reasonText = reason {
            args["reason"] = reasonText
        }
        return try await client.mutation("interventionLibrary:skipTask", args: args)
    }

    /// Get today's tasks (simpler format)
    func getTodaysTasks(userId: String) async throws -> [TasksByWindowResponse.TaskData] {
        return try await client.query("interventionLibrary:getTodaysTasks", args: [
            "userId": userId
        ])
    }
}

// MARK: - Check-In Types

struct CheckInStatusResponse: Codable {
    let morning: CheckInStatus
    let midday: CheckInStatus
    let evening: CheckInStatus

    struct CheckInStatus: Codable {
        let completed: Bool
        let completedAt: Double?
    }
}

struct CheckInSubmitResponse: Codable {
    let success: Bool
    let checkInId: String
}

// MARK: - Check-In APIs

extension ConvexService {
    /// Submit morning check-in data
    func submitMorningCheckIn(
        sleepQuality: Int,
        energyLevel: Int,
        mood: Int,
        deviceType: String = "ios"
    ) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        let _: CheckInSubmitResponse = try await client.mutation("checkIn:submitMorningCheckIn", args: [
            "userId": userId,
            "sleepQuality": sleepQuality,
            "energyLevel": energyLevel,
            "mood": mood,
            "deviceType": deviceType
        ])
    }

    /// Submit midday check-in data (energy, caffeine, naps)
    func submitMiddayCheckIn(
        energyLevel: Int,
        caffeineCups: Int,
        caffeineLastTime: String?,
        napTaken: Bool,
        napDurationMins: Int?,
        deviceType: String = "ios"
    ) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId,
            "energyLevel": energyLevel,
            "caffeineCups": caffeineCups,
            "napTaken": napTaken,
            "deviceType": deviceType
        ]

        if let caffeineTime = caffeineLastTime {
            args["caffeineLastTime"] = caffeineTime
        }
        if let napDuration = napDurationMins {
            args["napDurationMins"] = napDuration
        }

        let _: CheckInSubmitResponse = try await client.mutation("checkIn:submitMiddayCheckIn", args: args)
    }

    /// Submit evening check-in data
    func submitEveningCheckIn(
        overallDayRating: Int,
        reflectionText: String?,
        tasksMissedReasons: String?,
        deviceType: String = "ios"
    ) async throws {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId,
            "overallDayRating": overallDayRating,
            "deviceType": deviceType
        ]

        if let reflection = reflectionText {
            args["reflectionText"] = reflection
        }
        if let missedReasons = tasksMissedReasons {
            args["tasksMissedReasons"] = missedReasons
        }

        let _: CheckInSubmitResponse = try await client.mutation("checkIn:submitEveningCheckIn", args: args)
    }

    /// Get today's check-in completion status
    func getTodayCheckInStatus() async throws -> CheckInStatusResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("checkIn:getTodayCheckInStatus", args: [
            "userId": userId
        ])
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
