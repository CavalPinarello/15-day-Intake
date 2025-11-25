//
//  ConvexService.swift
//  Sleep 360 Platform
//
//  Convex backend service for direct iOS integration
//  Uses the official Convex Swift SDK for real-time sync
//

import Foundation
import Combine
import ConvexMobile

// MARK: - Convex Configuration

struct ConvexConfig {
    // Uses the deployment URL from Config.swift
    static var deploymentUrl: String {
        return Config.convexDeploymentURL
    }

    static var isDebugMode: Bool {
        return Config.isDebugMode
    }
}

// MARK: - Global Convex Client
// Single instance for the app lifecycle - used for real-time subscriptions
let convex = ConvexClient(deploymentUrl: Config.convexDeploymentURL)

// MARK: - Data Models

struct ConvexUser: Codable {
    let userId: String
    let username: String
    let email: String?
    let currentDay: Int
    let role: String?
    let onboardingCompleted: Bool?
    let appleHealthConnected: Bool?
}

struct SignInResponse: Codable {
    let userId: String
    let sessionToken: String
    let expiresAt: Int
    let user: ConvexUser
}

struct SignInWithAppleResponse: Codable {
    let userId: String
    let sessionToken: String
    let expiresAt: Int
    let isNewUser: Bool
    let user: ConvexUser
}

struct RegisterResponse: Codable {
    let userId: String
    let sessionToken: String
    let expiresAt: Int
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
    let notificationEnabled: Bool
    let notificationTime: String
    let quietHoursStart: String
    let quietHoursEnd: String
    let timezone: String
    let appleHealthSyncEnabled: Bool
    let dailyReminderEnabled: Bool
}

struct QuestionnaireQuestion: Codable {
    let questionId: String
    let questionText: String
    let helpText: String?
    let pillar: String
    let answerFormat: String
    let formatConfig: [String: AnyCodable]
    let validationRules: [String: AnyCodable]?
    let conditionalLogic: [String: AnyCodable]?
    let estimatedTimeSeconds: Int
    let moduleName: String
    let existingResponse: QuestionResponse?
}

struct QuestionResponse: Codable {
    let value: String?
    let number: Double?
    let array: [String]?
    let object: [String: AnyCodable]?
}

struct DayQuestionnaire: Codable {
    let dayNumber: Int
    let questions: [QuestionnaireQuestion]
    let totalQuestions: Int
}

struct JourneyProgress: Codable {
    let currentDay: Int
    let completedDays: [Int]
    let totalDays: Int
    let journeyComplete: Bool
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
    let journeyComplete: Bool
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
    let recordsSynced: Int
}

// Helper for handling arbitrary JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            self.value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Convex Service

/// ConvexService provides direct integration with the Convex backend
/// Uses the official ConvexMobile SDK for queries, mutations, and real-time subscriptions
class ConvexService {
    static let shared = ConvexService()

    private let client: ConvexClient
    private let decoder = JSONDecoder()

    // Session management
    private var sessionToken: String?
    private var currentUserId: String?

    private init() {
        self.client = convex
    }

    // MARK: - ConvexMobile SDK Methods

    /// Execute a mutation using ConvexMobile SDK
    func mutation<T: Decodable>(_ name: String, args: [String: Any] = [:]) async throws -> T {
        return try await client.mutation(name, args: args)
    }

    /// Execute a query using ConvexMobile SDK
    func query<T: Decodable>(_ name: String, args: [String: Any] = [:]) async throws -> T {
        return try await client.query(name, args: args)
    }

    /// Subscribe to a query for real-time updates
    func subscribe<T: Decodable>(to name: String, args: [String: Any] = [:]) -> AnyPublisher<T, Error> {
        return client.subscribe(to: name, args: args)
            .eraseToAnyPublisher()
    }

    // MARK: - Session Management

    func setSession(token: String, userId: String) {
        self.sessionToken = token
        self.currentUserId = userId
        // Store in Keychain for persistence
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

    func getDayQuestionnaire(dayNumber: Int? = nil) async throws -> DayQuestionnaire {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        var args: [String: Any] = ["userId": userId]
        if let day = dayNumber {
            args["dayNumber"] = day
        }

        return try await client.query("ios:getDayQuestionnaire", args: args)
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

    func completeDay(dayNumber: Int) async throws -> CompleteDayResponse {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.mutation("ios:completeDay", args: [
            "userId": userId,
            "dayNumber": dayNumber
        ])
    }

    func getJourneyProgress() async throws -> JourneyProgress {
        guard let userId = currentUserId else {
            throw ConvexError.notAuthenticated
        }

        return try await client.query("ios:getJourneyProgress", args: ["userId": userId])
    }

    // MARK: - Real-time Subscriptions

    /// Subscribe to journey progress updates in real-time
    func subscribeToJourneyProgress() -> AnyPublisher<JourneyProgress, Error> {
        guard let userId = currentUserId else {
            return Fail(error: ConvexError.notAuthenticated).eraseToAnyPublisher()
        }

        return client.subscribe(to: "ios:getJourneyProgress", args: ["userId": userId])
            .eraseToAnyPublisher()
    }

    /// Subscribe to sleep data updates in real-time
    func subscribeToSleepData(days: Int = 7) -> AnyPublisher<[SleepDataRecord], Error> {
        guard let userId = currentUserId else {
            return Fail(error: ConvexError.notAuthenticated).eraseToAnyPublisher()
        }

        return client.subscribe(to: "ios:getRecentSleepData", args: [
            "userId": userId,
            "days": days
        ]).eraseToAnyPublisher()
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
