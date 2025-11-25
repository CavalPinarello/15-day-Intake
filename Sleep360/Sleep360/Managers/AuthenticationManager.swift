//
//  AuthenticationManager.swift
//  Sleep 360 Platform
//
//  Authentication manager for server-based authentication
//

import Foundation
import Combine
import AuthenticationServices
import CryptoKit

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private var currentNonce: String?

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

    // MARK: - Email/Password Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            print("Attempting to sign in with email/username: \(email)")
            let result = try await apiService.signIn(email: email, password: password)
            print("Sign in response: \(result)")

            // Handle the actual server response format
            // Server returns success as Int (1) or Bool (true)
            let isSuccess = (result["success"] as? Bool == true) || (result["success"] as? Int == 1)
            if isSuccess,
               let token = result["accessToken"] as? String,
               let userData = result["user"] as? [String: Any] {

                // Store token securely
                storeToken(token)

                // Update user data - handle both id formats (Int or String)
                let userId: String
                if let intId = userData["id"] as? Int {
                    userId = String(intId)
                } else {
                    userId = userData["id"] as? String ?? ""
                }

                self.user = User(
                    id: userId,
                    email: userData["email"] as? String ?? email,
                    firstName: userData["firstName"] as? String,
                    lastName: userData["lastName"] as? String,
                    profileImageUrl: userData["profileImageUrl"] as? String
                )

                self.isAuthenticated = true
                print("✅ Sign in successful for user: \(userId)")
            } else {
                print("Sign in failed - unexpected response format or success=false")
                self.errorMessage = "Invalid credentials. Please try again."
            }
        } catch {
            print("Sign in error: \(error)")
            self.errorMessage = "Could not connect to the server. Please check your connection."
        }

        isLoading = false
    }

    // MARK: - Email/Password Sign Up

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

            if let token = result["accessToken"] as? String ?? result["token"] as? String,
               let userData = result["user"] as? [String: Any] {

                // Store token securely
                storeToken(token)

                // Update user data
                let userId: String
                if let intId = userData["id"] as? Int {
                    userId = String(intId)
                } else {
                    userId = userData["id"] as? String ?? ""
                }

                self.user = User(
                    id: userId,
                    email: userData["email"] as? String ?? "",
                    firstName: userData["firstName"] as? String,
                    lastName: userData["lastName"] as? String,
                    profileImageUrl: userData["profileImageUrl"] as? String
                )

                self.isAuthenticated = true
            } else {
                self.errorMessage = result["message"] as? String ?? "Registration failed. Please try again."
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Apple Sign In

    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        // Note: Apple Sign In requires ASAuthorizationController which needs to be triggered from UI
        // This is a placeholder - the actual flow uses handleSignInWithApple
        self.errorMessage = "Please use the Apple Sign In button to authenticate."
        isLoading = false
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
                let email = appleIDCredential.email
                let userIdentifier = appleIDCredential.user

                do {
                    // Send the Apple ID token to your backend
                    let result = try await apiService.signInWithApple(
                        idToken: idTokenString,
                        nonce: nonce,
                        firstName: firstName,
                        lastName: lastName,
                        email: email,
                        userIdentifier: userIdentifier
                    )

                    let isSuccess = (result["success"] as? Bool == true) || (result["success"] as? Int == 1)
                    if isSuccess,
                       let token = result["accessToken"] as? String,
                       let userData = result["user"] as? [String: Any] {

                        // Store token securely
                        storeToken(token)

                        // Update user data
                        let userId: String
                        if let intId = userData["id"] as? Int {
                            userId = String(intId)
                        } else {
                            userId = userData["id"] as? String ?? ""
                        }

                        self.user = User(
                            id: userId,
                            email: userData["email"] as? String ?? email ?? "",
                            firstName: userData["firstName"] as? String ?? firstName,
                            lastName: userData["lastName"] as? String ?? lastName,
                            profileImageUrl: userData["profileImageUrl"] as? String
                        )

                        self.isAuthenticated = true
                    } else {
                        self.errorMessage = "Failed to authenticate with Apple Sign In"
                    }

                } catch {
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

        // Google Sign In requires the Google Sign-In SDK
        // For now, show a message that it's not configured
        self.errorMessage = "Google Sign In is not fully configured. Please use email/password or Apple Sign In."

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        // Clear stored token
        clearStoredToken()

        // Reset state
        isAuthenticated = false
        user = nil
        errorMessage = nil
    }

    // MARK: - Token Validation

    private func validateToken(_ token: String) {
        Task {
            do {
                let result = try await apiService.validateToken(token)

                if let userData = result["user"] as? [String: Any] {
                    // Handle both id formats (Int or String)
                    let userId: String
                    if let intId = userData["id"] as? Int {
                        userId = String(intId)
                    } else {
                        userId = userData["id"] as? String ?? ""
                    }

                    self.user = User(
                        id: userId,
                        email: userData["email"] as? String ?? userData["username"] as? String ?? "",
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
