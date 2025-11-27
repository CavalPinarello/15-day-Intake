//
//  APIService.swift
//  Zoe Sleep for Longevity System
//
//  API service for communicating with Clerk-authenticated backend
//

import Foundation

class APIService {
    static let shared = APIService()
    private let session: URLSession

    private init() {
        // Use ephemeral configuration to avoid connection caching issues on iOS Simulator
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        // Prevent connection reuse which causes -1005 errors on simulator
        config.httpMaximumConnectionsPerHost = 1
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    // Helper to create fresh URLRequest with proper headers
    private func createRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        // Force HTTP/1.1 by not using multiplexing
        request.setValue("close", forHTTPHeaderField: "Connection")
        return request
    }
    
    // MARK: - Authentication

    func signIn(email: String, password: String) async throws -> [String: Any] {
        let url = URL(string: "\(Config.authEndpoint)/login")!
        var request = createRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // The server expects 'username' field which can be email or username
        let body = [
            "username": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Retry logic for connection reset errors (-1005)
        var lastError: Error?
        for attempt in 1...3 {
            do {
                print("Sign in attempt \(attempt) to \(url)")
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                print("Sign in response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode != 200 {
                    // Try to parse error message
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        print("Server error: \(errorMessage)")
                    }
                    throw APIError.authenticationFailed
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw APIError.invalidData
                }

                return json
            } catch let error as NSError where error.code == -1005 {
                // Connection was lost - retry after brief delay
                print("Connection lost (attempt \(attempt)), retrying...")
                lastError = error
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                continue
            } catch {
                throw error
            }
        }

        throw lastError ?? APIError.networkError(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed after 3 retries"]))
    }
    
    func signUp(email: String, password: String, firstName: String?, lastName: String?) async throws -> [String: Any] {
        let url = URL(string: "\(Config.authEndpoint)/register")!
        var request = createRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        if let firstName = firstName {
            body["firstName"] = firstName
        }
        if let lastName = lastName {
            body["lastName"] = lastName
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 201 {
            throw APIError.registrationFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidData
        }
        
        return json
    }
    
    func validateToken(_ token: String) async throws -> [String: Any] {
        let url = URL(string: "\(Config.authEndpoint)/validate")!
        var request = createRequest(url: url, method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.tokenInvalid
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidData
        }
        
        return json
    }
    
    func signInWithApple(idToken: String, nonce: String, firstName: String?, lastName: String?, email: String?, userIdentifier: String) async throws -> [String: Any] {
        let url = URL(string: "\(Config.authEndpoint)/apple")!
        var request = createRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "idToken": idToken,
            "nonce": nonce,
            "firstName": firstName ?? "",
            "lastName": lastName ?? "",
            "email": email ?? "",
            "userIdentifier": userIdentifier
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.authenticationFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidData
        }
        
        return json
    }
    
    func signInWithApple() async throws -> [String: Any] {
        // Placeholder for basic Apple authentication flow
        // In a real implementation, this would be called from a native Apple Sign In button
        throw APIError.authenticationFailed
    }

    func signInWithGoogle() async throws -> [String: Any] {
        // In a real implementation, this would handle Google authentication
        // For now, return a simulated response
        throw APIError.authenticationFailed
    }
    
    // MARK: - HealthKit Data Sync
    
    func syncHealthData(_ healthData: [String: Any], token: String) async throws -> [String: Any] {
        let url = URL(string: Config.healthKitSyncEndpoint)!
        var request = createRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: healthData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.syncFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidData
        }
        
        return json
    }
    
    // MARK: - User Profile
    
    func getUserProfile(token: String) async throws -> [String: Any] {
        let url = URL(string: Config.userProfileEndpoint)!
        var request = createRequest(url: url, method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.profileFetchFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidData
        }
        
        return json
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidResponse
    case invalidData
    case authenticationFailed
    case registrationFailed
    case tokenInvalid
    case syncFailed
    case profileFetchFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidData:
            return "Invalid data received from server"
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .registrationFailed:
            return "Registration failed. Please try again."
        case .tokenInvalid:
            return "Session expired. Please sign in again."
        case .syncFailed:
            return "Failed to sync health data. Please try again."
        case .profileFetchFailed:
            return "Failed to fetch user profile. Please try again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}