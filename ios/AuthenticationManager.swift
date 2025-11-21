//
//  AuthenticationManager.swift
//  Sleep 360 Platform
//
//  Authentication manager for Clerk integration
//

import Foundation
import Combine

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    struct User {
        let id: String
        let email: String
        let firstName: String?
        let lastName: String?
        let profileImageUrl: String?
    }
    
    init() {
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        // Check if user has valid session token stored locally
        if let token = getStoredToken(), !token.isEmpty {
            validateToken(token)
        }
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await apiService.signIn(email: email, password: password)
            
            if let token = result["token"] as? String,
               let userData = result["user"] as? [String: Any] {
                
                // Store token securely
                storeToken(token)
                
                // Update user data
                self.user = User(
                    id: userData["id"] as? String ?? "",
                    email: userData["email"] as? String ?? "",
                    firstName: userData["firstName"] as? String,
                    lastName: userData["lastName"] as? String,
                    profileImageUrl: userData["profileImageUrl"] as? String
                )
                
                self.isAuthenticated = true
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, firstName: String?, lastName: String?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await apiService.signUp(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            
            if let token = result["token"] as? String,
               let userData = result["user"] as? [String: Any] {
                
                // Store token securely
                storeToken(token)
                
                // Update user data
                self.user = User(
                    id: userData["id"] as? String ?? "",
                    email: userData["email"] as? String ?? "",
                    firstName: userData["firstName"] as? String,
                    lastName: userData["lastName"] as? String,
                    profileImageUrl: userData["profileImageUrl"] as? String
                )
                
                self.isAuthenticated = true
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() {
        // Clear stored token
        clearStoredToken()
        
        // Reset state
        isAuthenticated = false
        user = nil
        errorMessage = nil
    }
    
    private func validateToken(_ token: String) {
        Task {
            do {
                let result = try await apiService.validateToken(token)
                
                if let userData = result["user"] as? [String: Any] {
                    self.user = User(
                        id: userData["id"] as? String ?? "",
                        email: userData["email"] as? String ?? "",
                        firstName: userData["firstName"] as? String,
                        lastName: userData["lastName"] as? String,
                        profileImageUrl: userData["profileImageUrl"] as? String
                    )
                    
                    self.isAuthenticated = true
                } else {
                    // Token is invalid, clear it
                    clearStoredToken()
                }
            } catch {
                // Token validation failed, clear it
                clearStoredToken()
            }
        }
    }
    
    // MARK: - Token Storage
    private func storeToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    private func getStoredToken() -> String? {
        return UserDefaults.standard.string(forKey: "auth_token")
    }
    
    private func clearStoredToken() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
    
    // MARK: - Token for API calls
    func getAuthToken() -> String? {
        return getStoredToken()
    }
}