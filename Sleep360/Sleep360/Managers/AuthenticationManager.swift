//
//  AuthenticationManager.swift
//  Sleep 360 Platform
//
//  Authentication manager using Convex backend directly
//

import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let convexService = ConvexService.shared
    private var currentNonce: String?

    struct User {
        let id: String
        let username: String
        let email: String?
        let currentDay: Int
        let role: String?
    }

    init() {
        checkAuthenticationStatus()
    }

    func checkAuthenticationStatus() {
        // Check if user has valid session stored in Convex service
        if let session = convexService.loadSavedSession() {
            // Validate the session with Convex
            Task {
                await validateStoredSession()
            }
        }
    }

    private func validateStoredSession() async {
        do {
            let response = try await convexService.validateSession()
            if response.valid, let user = response.user, let userId = response.userId {
                self.user = User(
                    id: userId,
                    username: user.username,
                    email: user.email,
                    currentDay: user.currentDayInt,
                    role: user.role
                )
                self.isAuthenticated = true
                print("✅ Session restored for user: \(user.username)")
            } else {
                // Session invalid, clear it
                convexService.clearSession()
                self.isAuthenticated = false
                self.user = nil
            }
        } catch {
            print("Session validation failed: \(error)")
            convexService.clearSession()
            self.isAuthenticated = false
            self.user = nil
        }
    }

    // MARK: - Email/Password Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            print("Attempting to sign in with: \(email)")

            // Hash the password (simple hash for demo - in production use proper hashing)
            let passwordHash = hashPassword(password)
            let deviceId = getDeviceId()

            let response = try await convexService.signIn(
                identifier: email,
                passwordHash: passwordHash,
                deviceId: deviceId,
                deviceInfo: DeviceInfo.current
            )

            // Update user state
            self.user = User(
                id: response.userId,
                username: response.user.username,
                email: response.user.email,
                currentDay: response.user.currentDayInt,
                role: response.user.role
            )

            self.isAuthenticated = true
            print("✅ Sign in successful for user: \(response.user.username)")

        } catch let error as ConvexError {
            print("Sign in error: \(error)")
            switch error {
            case .serverError(let message):
                self.errorMessage = message
            case .httpError(let code):
                if code == 401 {
                    self.errorMessage = "Invalid credentials. Please try again."
                } else {
                    self.errorMessage = "Server error (\(code)). Please try again."
                }
            default:
                self.errorMessage = "Could not connect to the server. Please check your connection."
            }
        } catch {
            print("Sign in error: \(error)")
            self.errorMessage = "Could not connect to the server. Please check your connection."
        }

        isLoading = false
    }

    // MARK: - Email/Password Sign Up

    func signUp(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let passwordHash = hashPassword(password)
            let deviceId = getDeviceId()

            let response = try await convexService.register(
                email: email,
                username: username,
                passwordHash: passwordHash,
                deviceId: deviceId,
                deviceInfo: DeviceInfo.current
            )

            // Update user state
            self.user = User(
                id: response.userId,
                username: response.user.username,
                email: response.user.email,
                currentDay: response.user.currentDayInt,
                role: response.user.role
            )

            self.isAuthenticated = true
            print("✅ Registration successful for user: \(response.user.username)")

        } catch let error as ConvexError {
            print("Sign up error: \(error)")
            switch error {
            case .serverError(let message):
                self.errorMessage = message
            default:
                self.errorMessage = "Registration failed. Please try again."
            }
        } catch {
            print("Sign up error: \(error)")
            self.errorMessage = "Could not connect to the server. Please try again."
        }

        isLoading = false
    }

    // MARK: - Apple Sign In

    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }

    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    self.errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                    isLoading = false
                    return
                }

                guard let appleIDToken = appleIDCredential.identityToken else {
                    self.errorMessage = "Unable to fetch identity token"
                    isLoading = false
                    return
                }

                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    self.errorMessage = "Unable to serialize token string from data"
                    isLoading = false
                    return
                }

                // Extract user information
                let firstName = appleIDCredential.fullName?.givenName
                let lastName = appleIDCredential.fullName?.familyName
                let fullName = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
                let email = appleIDCredential.email
                let userIdentifier = appleIDCredential.user

                do {
                    let deviceId = getDeviceId()

                    let response = try await convexService.signInWithApple(
                        appleUserId: userIdentifier,
                        identityToken: idTokenString,
                        email: email,
                        fullName: fullName.isEmpty ? nil : fullName,
                        deviceId: deviceId,
                        deviceInfo: DeviceInfo.current
                    )

                    // Update user state
                    self.user = User(
                        id: response.userId,
                        username: response.user.username,
                        email: response.user.email,
                        currentDay: response.user.currentDayInt,
                        role: response.user.role
                    )

                    self.isAuthenticated = true

                    if response.isNewUser {
                        print("✅ New user created via Apple Sign In: \(response.user.username)")
                    } else {
                        print("✅ Existing user signed in via Apple: \(response.user.username)")
                    }

                } catch let error as ConvexError {
                    print("Apple Sign In error: \(error)")
                    self.errorMessage = "Apple Sign In failed. Please try again."
                } catch {
                    print("Apple Sign In error: \(error)")
                    self.errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
                }
            }

        case .failure(let error):
            // Handle cancellation gracefully
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                self.errorMessage = nil // User cancelled, no error message needed
            } else {
                self.errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        // Google Sign In requires the Google Sign-In SDK to be integrated
        // This would typically:
        // 1. Use GIDSignIn to get the user's Google credentials
        // 2. Send the ID token to Convex for verification
        // 3. Create/update user in the database

        // For now, show a message - Google Sign In SDK needs to be added
        self.errorMessage = "Google Sign In requires additional SDK setup. Please use email/password or Apple Sign In."

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            do {
                try await convexService.signOut()
            } catch {
                print("Sign out error: \(error)")
            }

            // Clear local state regardless of server response
            convexService.clearSession()
            self.isAuthenticated = false
            self.user = nil
            self.errorMessage = nil
        }
    }

    // MARK: - Helper Methods

    private func hashPassword(_ password: String) -> String {
        // Simple SHA256 hash for demo purposes
        // In production, use proper password hashing (bcrypt, argon2, etc.) on the server
        let inputData = Data(password.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func getDeviceId() -> String {
        // Get or create a unique device identifier
        let key = "device_uuid"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }

        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    // MARK: - Token for API calls (compatibility)

    func getAuthToken() -> String? {
        if let session = convexService.loadSavedSession() {
            return session.token
        }
        return nil
    }
}
