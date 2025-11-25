//
//  APIService.swift
//  Sleep 360 Platform
//
//  API service for communicating with Clerk-authenticated backend
//

import Foundation

class APIService {
    static let shared = APIService()
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Authentication
    
    func signIn(email: String, password: String) async throws -> [String: Any] {
        let url = URL(string: "\(Config.authEndpoint)/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // The server expects 'username' field which can be email or username
        let body = [
            "username": email,
            "password": password
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
    
    func signUp(email: String, password: String, firstName: String?, lastName: String?) async throws -> [String: Any] {
        let url = URL(string: "\(Config.authEndpoint)/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
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
    
    // MARK: - HealthKit Data Sync
    
    func syncHealthData(_ healthData: [String: Any], token: String) async throws -> [String: Any] {
        let url = URL(string: Config.healthKitSyncEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
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