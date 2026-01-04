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
    // Expansion pack status for current day (scheduled Days 6-14 OR same-day triggered Days 1-5)
    let hasExpansionPackToday: Bool?
    let expansionPackCompleted: Bool?
    let expansionQuestionCount: Int?
    let expansionModules: [String]?
    // Overdue expansion packs count (for reminder on Watch)
    let overdueExpansionsCount: Int?
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
    let previousDay: Int?
    let newDay: Int?
    let error: String?
    let sleepLogCompleted: Bool?
    let assessmentCompleted: Bool?
    let currentDay: Int?
}

struct WatchCanAdvanceDayResponse: Codable {
    let canAdvance: Bool
    let reason: String
    let sleepLogCompleted: Bool
    let assessmentCompleted: Bool
    let timeUnlocked: Bool
    let currentDay: Int?
    let nextDay: Int?
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
    let currentDay: Int?  // Made optional - might be nil for new users
    let onboardingCompleted: Bool?  // Made optional
    let sessionToken: String?
    let expiresAt: Double?

    // Provide defaults for optional fields
    var safeCurrentDay: Int { currentDay ?? 1 }
    var safeOnboardingCompleted: Bool { onboardingCompleted ?? false }
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

@MainActor
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
    @Published var sessionToken: String? // NEW: Session token for secure API calls
    @Published var currentDay: Int = 1
    @Published var completedDays: [Int] = []
    @Published var journeyComplete = false
    // Section-level completion for current day
    @Published var sleepLogCompleted = false
    @Published var assessmentCompleted = false
    // Expansion pack status for current day (scheduled Days 6-14 OR same-day triggered Days 1-5)
    @Published var hasExpansionPackToday = false
    @Published var expansionPackCompleted = false
    @Published var expansionQuestionCount = 0
    @Published var expansionModules: [String] = []
    // Overdue expansion packs count (for reminder)
    @Published var overdueExpansionsCount = 0

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
            self.sessionToken = UserDefaults.standard.string(forKey: "convexSessionToken")
            self.isAuthenticated = true
            print("[WatchConvex] Loaded saved credentials - userId: \(savedUserId), hasSessionToken: \(self.sessionToken != nil)")
        }
    }

    /// Refresh journey state from Convex (called on app activation)
    /// Waits for iPhone to sync credentials - does NOT auto-login to avoid user mismatch
    func refreshFromConvex() async {
        // Do NOT auto-login as a different user - wait for iPhone to sync credentials
        // This prevents the Watch showing one user's data while iPhone shows another
        if !isAuthenticated {
            print("[WatchConvex] Not authenticated - waiting for credentials from iPhone")
            print("[WatchConvex] (In simulator, WatchConnectivity may not work - try signing in manually)")
            return
        }

        do {
            _ = try await fetchJourneyState()
            print("[WatchConvex] Refreshed state for \(username ?? "unknown"): Day \(currentDay), SleepLog=\(sleepLogCompleted), Assessment=\(assessmentCompleted)")
        } catch {
            print("[WatchConvex] Failed to refresh: \(error)")
        }
    }

    /// For simulator testing only - manually sign in as the same user as iPhone
    /// Returns nil on success, error message on failure
    func signInForTesting(username: String, password: String) async -> String? {
        do {
            let userInfo = try await signIn(username: username, password: password)
            print("[WatchConvex] Signed in as \(userInfo.username), Day \(userInfo.safeCurrentDay)")
            return nil // Success
        } catch {
            let errorMessage = "\(error)"
            print("[WatchConvex] Sign in failed: \(errorMessage)")
            return errorMessage
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

    private func saveCredentials(userId: String, username: String, sessionToken: String? = nil) {
        UserDefaults.standard.set(userId, forKey: "convexUserId")
        UserDefaults.standard.set(username, forKey: "convexUsername")
        if let token = sessionToken {
            UserDefaults.standard.set(token, forKey: "convexSessionToken")
        }
        self.userId = userId
        self.username = username
        self.sessionToken = sessionToken
        self.isAuthenticated = true
    }

    func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: "convexUserId")
        UserDefaults.standard.removeObject(forKey: "convexUsername")
        UserDefaults.standard.removeObject(forKey: "convexSessionToken")
        self.userId = nil
        self.username = nil
        self.sessionToken = nil
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

            // Parse the JSON response
            guard let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw WatchConvexError.decodingError("Could not parse JSON response")
            }

            // Check for Convex error response FIRST (status code is 200 but contains error)
            if let status = wrapper["status"] as? String, status == "error" {
                let errorMessage = wrapper["errorMessage"] as? String ?? wrapper["error"] as? String ?? "Unknown server error"
                throw WatchConvexError.serverError(errorMessage)
            }

            // Also check for simple error field (older Convex format)
            if let errorMessage = wrapper["error"] as? String {
                throw WatchConvexError.serverError(errorMessage)
            }

            // Convex wraps successful response in { "value": ... }
            guard let value = wrapper["value"] else {
                throw WatchConvexError.decodingError("Response missing 'value' field")
            }

            // Handle null values
            if value is NSNull {
                throw WatchConvexError.invalidResponse
            }

            // Ensure value is JSON-serializable before proceeding
            guard JSONSerialization.isValidJSONObject(value) || value is String || value is NSNumber || value is Bool else {
                throw WatchConvexError.decodingError("Response value is not JSON-serializable")
            }

            let valueData = try JSONSerialization.data(withJSONObject: value)
            return try decoder.decode(T.self, from: valueData)
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
            "passwordHash": passwordHash,
            "deviceId": "watch_\(WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown")"
        ])

        // Save credentials including session token for secure API calls
        saveCredentials(userId: response.userId, username: response.username, sessionToken: response.sessionToken)

        self.currentDay = response.safeCurrentDay
        self.journeyComplete = response.safeOnboardingCompleted

        print("[WatchConvex] Signed in with session token: \(response.sessionToken != nil)")

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

        self.currentDay = state.currentDay
        self.completedDays = state.completedDays
        self.journeyComplete = state.journeyComplete
        // Update section completion status for current day
        self.sleepLogCompleted = state.sleepLogCompleted ?? false
        self.assessmentCompleted = state.assessmentCompleted ?? false
        // Update expansion pack status for current day
        self.hasExpansionPackToday = state.hasExpansionPackToday ?? false
        self.expansionPackCompleted = state.expansionPackCompleted ?? false
        self.expansionQuestionCount = state.expansionQuestionCount ?? 0
        self.expansionModules = state.expansionModules ?? []
        // Update overdue expansions count
        self.overdueExpansionsCount = state.overdueExpansionsCount ?? 0

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

        if response.success {
            if !self.completedDays.contains(dayNumber) {
                self.completedDays.append(dayNumber)
                self.completedDays.sort()
            }
            self.currentDay = response.newDay
            self.journeyComplete = response.journeyComplete
        }

        return response
    }

    /// Mark a section as completed (sleepLog or assessment)
    func completeSection(dayNumber: Int, section: String) async throws -> WatchCompleteSectionResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section,
            "source": "watch"
        ]

        // Include session token for authorization
        if let token = sessionToken {
            args["sessionToken"] = token
        }

        let response: WatchCompleteSectionResponse = try await mutation("watch:completeSection", args: args)

        if response.success {
            self.sleepLogCompleted = response.sleepLogCompleted
            self.assessmentCompleted = response.assessmentCompleted

            // Notify iPhone that section was completed (triggers immediate refresh)
            WatchConnectivityManager.shared.notifyiPhoneSectionCompleted(
                section: section,
                dayNumber: dayNumber
            )

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

        return response
    }

    /// Check if user can advance to the next day
    /// Requirements: Both Sleep Log AND Assessment must be completed
    /// In debug mode: Bypasses time check but NOT completion check
    func canAdvanceDay(debugMode: Bool = false) async throws -> WatchCanAdvanceDayResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        return try await query("watch:canAdvanceDay", args: [
            "userId": userId,
            "debugMode": debugMode
        ])
    }

    /// Advance to next day
    /// STRICT: Both sections must be completed first
    /// - debugMode: true bypasses time check (4 AM) but NOT completion check
    func advanceDay(debugMode: Bool = false) async throws -> WatchAdvanceDayResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId,
            "debugMode": debugMode
        ]

        // Include session token for authorization
        if let token = sessionToken {
            args["sessionToken"] = token
        }

        let response: WatchAdvanceDayResponse = try await mutation("watch:advanceDay", args: args)

        if response.success {
            if let previousDay = response.previousDay,
               !self.completedDays.contains(previousDay) {
                self.completedDays.append(previousDay)
                self.completedDays.sort()
            }
            if let newDay = response.newDay {
                self.currentDay = newDay
                // Reset section completion for the new day
                self.sleepLogCompleted = false
                self.assessmentCompleted = false
            }
        }

        return response
    }

    /// Reset journey progress (Debug Mode)
    func resetProgress() async throws -> WatchResetResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId
        ]

        // Include session token for authorization
        if let token = sessionToken {
            args["sessionToken"] = token
        }

        let response: WatchResetResponse = try await mutation("watch:resetProgress", args: args)

        if response.success {
            self.currentDay = 1
            self.completedDays = []
            self.journeyComplete = false
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

        // Include session token for authorization
        if let token = sessionToken {
            args["sessionToken"] = token
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

        var args: [String: Any] = [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section,
            "currentQuestionIndex": questionIndex,
            "totalQuestions": totalQuestions,
            "device": "watch"
        ]

        // Include session token for authorization
        if let token = sessionToken {
            args["sessionToken"] = token
        }

        let _: SuccessResult = try await mutation("watch:updateQuestionProgress", args: args)
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

    // MARK: - Unified Question Fetching (Single Source of Truth)

    /// THE SINGLE SOURCE OF TRUTH - Get all questions for a user's day from Convex
    /// This is what Watch should use to get questions (same as iOS and Web)
    func getQuestionsForUserDay(dayNumber: Int, section: String = "all") async throws -> WatchQuestionsForDayResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        return try await query("watch:getQuestionsForUserDay", args: [
            "userId": userId,
            "dayNumber": dayNumber,
            "section": section
        ])
    }

    // MARK: - Watch Check-In (Minimal 3-Metric)

    /// Submit a quick check-in from the watch (energy, mood, focus)
    /// - Parameters:
    ///   - checkInType: morning, midday, or evening
    ///   - energyLevel: 1-6 (sleeping seal to rabbit)
    ///   - moodLevel: 1-6 (stormy to rainbow)
    ///   - focusLevel: 1-5 (foggy to crystal)
    func submitWatchCheckIn(
        checkInType: String,
        energyLevel: Int,
        moodLevel: Int,
        focusLevel: Int
    ) async throws -> WatchCheckInSubmitResponse {
        guard let userId = userId else {
            print("[WatchConvex] ❌ submitWatchCheckIn failed: not authenticated (userId is nil)")
            throw WatchConvexError.notAuthenticated
        }

        print("[WatchConvex] 📤 submitWatchCheckIn called:")
        print("[WatchConvex]   userId: \(userId)")
        print("[WatchConvex]   checkInType: \(checkInType)")
        print("[WatchConvex]   energy: \(energyLevel), mood: \(moodLevel), focus: \(focusLevel)")

        var args: [String: Any] = [
            "userId": userId,
            "checkInType": checkInType,
            "energyLevel": energyLevel,
            "moodLevel": moodLevel,
            "focusLevel": focusLevel
        ]

        // Include session token for authorization
        if let token = sessionToken {
            args["sessionToken"] = token
            print("[WatchConvex]   sessionToken: \(String(token.prefix(20)))...")
        }

        do {
            let response = try await mutation("checkIn:watchSubmitCheckIn", args: args) as WatchCheckInSubmitResponse
            print("[WatchConvex] ✅ Check-in succeeded! checkInId: \(response.checkInId ?? "nil")")
            return response
        } catch {
            print("[WatchConvex] ❌ Check-in FAILED: \(error)")
            throw error
        }
    }

    /// Get today's check-in status (which check-ins are done)
    func getWatchCheckInStatus() async throws -> WatchCheckInStatusResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        return try await query("checkIn:getWatchCheckInStatus", args: [
            "userId": userId
        ])
    }

    /// Get check-in trends for charts (today's slots + weekly averages)
    func getWatchCheckInTrends(days: Int = 7) async throws -> WatchCheckInTrendsResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        return try await query("checkIn:getWatchCheckInTrends", args: [
            "userId": userId,
            "days": days
        ])
    }

    // MARK: - Weekly Garden

    /// Get the weekly garden state for visualization
    func getWeeklyGarden() async throws -> WatchGardenResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        return try await query("watchGarden:getWeeklyGarden", args: [
            "userId": userId
        ])
    }

    /// Update garden bloom after completing a check-in or task
    func updateGardenBloom(
        date: String,
        checkInsCompleted: Int,
        tasksCompleted: Int,
        totalTasks: Int
    ) async throws -> WatchGardenUpdateResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId,
            "date": date,
            "checkInsCompleted": checkInsCompleted,
            "tasksCompleted": tasksCompleted,
            "totalTasks": totalTasks
        ]

        // Include session token for authorization
        if let token = sessionToken {
            args["sessionToken"] = token
        }

        return try await mutation("watchGarden:updateGardenBloom", args: args)
    }

    /// Sync garden state after a check-in is submitted
    func syncGardenAfterCheckIn(checkInsCompletedToday: Int) async throws -> WatchGardenUpdateResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        var args: [String: Any] = [
            "userId": userId,
            "checkInsCompletedToday": checkInsCompletedToday
        ]

        // Include session token for authorization
        if let token = sessionToken {
            args["sessionToken"] = token
        }

        return try await mutation("watchGarden:syncGardenAfterCheckIn", args: args)
    }

    /// Get streak information
    func getStreakInfo() async throws -> (currentStreak: Int, longestStreak: Int) {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        struct StreakResponse: Codable {
            let currentStreak: Int
            let longestStreak: Int
        }

        let response: StreakResponse = try await query("watchGarden:getStreakInfo", args: [
            "userId": userId
        ])

        return (response.currentStreak, response.longestStreak)
    }

    // MARK: - Circadian Signal Tracking

    /// Get today's circadian status for the light exposure card
    func getCircadianStatus() async throws -> WatchCircadianStatusResponse {
        guard let userId = userId else {
            throw WatchConvexError.notAuthenticated
        }

        let response: WatchCircadianStatusResponse = try await query("circadian:getCircadianStatus", args: [
            "userId": userId
        ])

        return response
    }
}

// MARK: - Question Response Models

struct WatchConvexQuestion: Codable {
    let id: String
    let text: String
    let type: String
    let required: Bool
    let options: [String]?
    let helpText: String?
    let moduleName: String?
}

struct WatchQuestionsMetadata: Codable {
    let sleepLogCount: Int
    let assessmentCount: Int
    let totalMinutes: Int
    let triggeredGateways: [String]
    let dayDescription: String
    let dayExplanation: String
}

struct WatchQuestionsForDayResponse: Codable {
    let sleepLog: [WatchConvexQuestion]
    let assessment: [WatchConvexQuestion]
    let metadata: WatchQuestionsMetadata
}

// MARK: - Check-In Response Models

struct WatchCheckInSubmitResponse: Codable {
    let success: Bool
    let checkInId: String?
    let checkInsCompletedToday: Int
    let isFirstCheckInToday: Bool
    let error: String?
}

struct WatchCheckInStatusResponse: Codable {
    let morningDone: Bool
    let middayDone: Bool
    let eveningDone: Bool
    let totalDone: Int
    let recommendedNext: String?
    let lastEnergyLevel: Int?
    let lastMoodLevel: Int?
    let lastFocusLevel: Int?
}

// MARK: - Garden Response Models

struct WatchGardenDayResponse: Codable {
    let date: String
    let dayOfWeek: String
    let bloomState: Int
    let checkInsCompleted: Int
    let tasksCompleted: Int
    let totalTasks: Int
    let isToday: Bool
}

struct WatchGardenResponse: Codable {
    let weekStartDate: String
    let days: [WatchGardenDayResponse]
    let currentStreak: Int
    let longestStreak: Int
}

struct WatchGardenUpdateResponse: Codable {
    let success: Bool
    let newBloomState: Int
    let currentStreak: Int
}

// MARK: - Check-In Trends Response Models

struct WatchCheckInTrendsSlotData: Codable {
    let energy: Int
    let mood: Int
    let focus: Int
    let completedAt: Double
}

struct WatchCheckInTrendsTodayData: Codable {
    let morning: WatchCheckInTrendsSlotData?
    let midday: WatchCheckInTrendsSlotData?
    let evening: WatchCheckInTrendsSlotData?
}

struct WatchCheckInTrendsWeekDay: Codable {
    let date: String
    let dayOfWeek: String
    let hasData: Bool
    let avgEnergy: Double?
    let avgMood: Double?
    let avgFocus: Double?
    let checkInsCount: Int
}

struct WatchCheckInTrendsResponse: Codable {
    let today: WatchCheckInTrendsTodayData
    let week: [WatchCheckInTrendsWeekDay]
}

// MARK: - Circadian Status Response Model

struct WatchCircadianStatusResponse: Codable {
    let hasData: Bool
    let daylightMins: Int
    let targetMins: Int
    let percentOfTarget: Int
    let circadianScore: Int?
    let needsMoreLight: Bool
    let morningLightMins: Int
}
