//
//  AuthenticationManager.swift
//  Zoe Sleep for Longevity System
//
//  Authentication manager using Clerk for auth + Convex for user data
//

import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import UIKit
import Clerk

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: AppUser?
    @Published var isLoading = false
    @Published var isCheckingSession = true  // True until initial session check completes
    @Published var errorMessage: String?

    private let convexService = ConvexService.shared
    private var clerkObservationTask: Task<Void, Never>?

    struct AppUser {
        let id: String
        let username: String
        let email: String?
        let currentDay: Int
        let role: String?
    }

    init() {
        // Observe Clerk auth state changes
        setupClerkObserver()
        checkAuthenticationStatus()
    }

    private func setupClerkObserver() {
        // Watch for Clerk user changes using polling (Clerk SDK uses @Observable, not Combine)
        clerkObservationTask?.cancel()
        clerkObservationTask = Task { [weak self] in
            var previousUser: User? = Clerk.shared.user
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every 1 second
                let currentUser = Clerk.shared.user
                if currentUser?.id != previousUser?.id {
                    previousUser = currentUser
                    await self?.handleClerkUserChange(currentUser)
                }
            }
        }
    }

    private func handleClerkUserChange(_ clerkUser: User?) async {
        if let clerkUser = clerkUser {
            // User signed in via Clerk - sync with Convex
            await syncClerkUserWithConvex(clerkUser)
        } else if isAuthenticated {
            // User signed out from Clerk
            await performSignOut()
        }
    }

    func checkAuthenticationStatus() {
        // Check if user has valid session stored in Convex service
        if let _ = convexService.loadSavedSession() {
            // Validate the session with Convex
            Task {
                await validateStoredSession()
                isCheckingSession = false
            }
        } else {
            // No saved session, check Clerk
            Task {
                // Wait a moment for Clerk to load
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                if Clerk.shared.user != nil {
                    await handleClerkUserChange(Clerk.shared.user)
                }
                isCheckingSession = false
            }
        }
    }

    private func validateStoredSession() async {
        do {
            let response = try await convexService.validateSession()
            if response.valid, let user = response.user, let userId = response.userId {
                self.user = AppUser(
                    id: userId,
                    username: user.username,
                    email: user.email,
                    currentDay: user.currentDayInt,
                    role: user.role
                )
                self.isAuthenticated = true
                print("✅ Session restored for user: \(user.username)")

                // Reset guides/tour if different user (ensures fresh experience per user)
                FirstTimeGuideManager.shared.handleUserSignIn(userId: userId)

                // Sync credentials to Watch for same-user authentication
                iOSWatchConnectivityManager.shared.syncCredentialsToWatch(
                    userId: userId,
                    username: user.username
                )

                // Check onboarding state for this user with full profile data
                await OnboardingManager.shared.checkUserOnboardingState(
                    userId: userId,
                    serverOnboardingCompleted: user.onboardingCompleted,
                    serverProfile: (
                        fullName: user.fullName,
                        measurementSystem: user.measurementSystem,
                        heightCm: user.heightCm,
                        weightKg: user.weightKg,
                        gender: user.gender,
                        birthYear: user.birthYearInt
                    )
                )

                // Load journey progress for this user
                await QuestionnaireManager.shared.loadJourneyProgress()
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

    // MARK: - Clerk User Sync

    /// Sync Clerk user with Convex backend - creates or links user account
    private func syncClerkUserWithConvex(_ clerkUser: User) async {
        isLoading = true
        errorMessage = nil

        do {
            let email = clerkUser.primaryEmailAddress?.emailAddress ?? ""
            let fullName = "\(clerkUser.firstName ?? "") \(clerkUser.lastName ?? "")".trimmingCharacters(in: .whitespaces)
            let deviceId = getDeviceId()

            // Call Convex to find or create user linked to Clerk
            let response = try await convexService.signInWithClerk(
                clerkUserId: clerkUser.id,
                email: email,
                fullName: fullName.isEmpty ? nil : fullName,
                deviceId: deviceId,
                deviceInfo: DeviceInfo.current
            )

            // Update user state
            self.user = AppUser(
                id: response.userId,
                username: response.user.username,
                email: response.user.email,
                currentDay: response.user.currentDayInt,
                role: response.user.role
            )

            self.isAuthenticated = true
            print("✅ Clerk user synced with Convex: \(response.user.username)")

            // Reset guides/tour if different user
            FirstTimeGuideManager.shared.handleUserSignIn(userId: response.userId)

            // Sync credentials to Watch
            iOSWatchConnectivityManager.shared.syncCredentialsToWatch(
                userId: response.userId,
                username: response.user.username
            )

            // Check onboarding state
            await OnboardingManager.shared.checkUserOnboardingState(
                userId: response.userId,
                serverOnboardingCompleted: response.isNewUser ? false : response.user.onboardingCompleted,
                serverProfile: response.isNewUser ? nil : (
                    fullName: response.user.fullName,
                    measurementSystem: response.user.measurementSystem,
                    heightCm: response.user.heightCm,
                    weightKg: response.user.weightKg,
                    gender: response.user.gender,
                    birthYear: response.user.birthYearInt
                )
            )

            // Pre-fill onboarding data for new users
            if response.isNewUser {
                OnboardingManager.shared.prefillFromAuth(
                    name: fullName.isEmpty ? nil : fullName,
                    email: email.isEmpty ? nil : email
                )
            }

            // Load journey progress
            await QuestionnaireManager.shared.loadJourneyProgress()

        } catch let error as ConvexError {
            print("Clerk sync error: \(error)")
            self.errorMessage = "Failed to sync account. Please try again."
        } catch {
            print("Clerk sync error: \(error)")
            self.errorMessage = "Could not connect to the server. Please check your connection."
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            await performSignOut()

            // Sign out from Clerk
            try? await Clerk.shared.signOut()
        }
    }

    private func performSignOut() async {
        // Notify Apple Watch to clear its cached credentials
        iOSWatchConnectivityManager.shared.notifyWatchLogout()

        // Clear server session asynchronously
        do {
            try await convexService.signOut()
            print("✅ Server session cleared")
        } catch {
            print("Sign out error (server): \(error)")
        }

        // Clear authentication state
        convexService.clearSession()
        self.isAuthenticated = false
        self.user = nil
        self.errorMessage = nil

        print("✅ Sign out complete - auth state cleared, Watch notified")
    }

    // MARK: - Legacy Email/Password Sign In (fallback)

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            print("Attempting to sign in with: \(email)")

            let passwordHash = hashPassword(password)
            let deviceId = getDeviceId()

            let response = try await convexService.signIn(
                identifier: email,
                passwordHash: passwordHash,
                deviceId: deviceId,
                deviceInfo: DeviceInfo.current
            )

            // Update user state
            self.user = AppUser(
                id: response.userId,
                username: response.user.username,
                email: response.user.email,
                currentDay: response.user.currentDayInt,
                role: response.user.role
            )

            self.isAuthenticated = true
            print("✅ Sign in successful for user: \(response.user.username)")

            FirstTimeGuideManager.shared.handleUserSignIn(userId: response.userId)

            iOSWatchConnectivityManager.shared.syncCredentialsToWatch(
                userId: response.userId,
                username: response.user.username
            )

            await OnboardingManager.shared.checkUserOnboardingState(
                userId: response.userId,
                serverOnboardingCompleted: response.user.onboardingCompleted,
                serverProfile: (
                    fullName: response.user.fullName,
                    measurementSystem: response.user.measurementSystem,
                    heightCm: response.user.heightCm,
                    weightKg: response.user.weightKg,
                    gender: response.user.gender,
                    birthYear: response.user.birthYearInt
                )
            )

            await QuestionnaireManager.shared.loadJourneyProgress()
            print("✅ Loaded journey progress for user: \(response.user.username)")

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

    // MARK: - Legacy Email/Password Sign Up (fallback)

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let passwordHash = hashPassword(password)
            let deviceId = getDeviceId()

            let response = try await convexService.register(
                email: email,
                passwordHash: passwordHash,
                deviceId: deviceId,
                deviceInfo: DeviceInfo.current
            )

            self.user = AppUser(
                id: response.userId,
                username: response.user.username,
                email: response.user.email,
                currentDay: response.user.currentDayInt,
                role: response.user.role
            )

            self.isAuthenticated = true
            print("✅ Registration successful for user: \(response.user.email ?? "unknown")")

            FirstTimeGuideManager.shared.handleUserSignIn(userId: response.userId)

            iOSWatchConnectivityManager.shared.syncCredentialsToWatch(
                userId: response.userId,
                username: response.user.username
            )

            await OnboardingManager.shared.checkUserOnboardingState(
                userId: response.userId,
                serverOnboardingCompleted: false,
                serverProfile: nil
            )

            OnboardingManager.shared.prefillFromAuth(name: nil, email: email)

            await QuestionnaireManager.shared.loadJourneyProgress()

        } catch let error as ConvexError {
            print("Sign up error: \(error)")
            switch error {
            case .serverError(let message):
                self.errorMessage = message
            default:
                self.errorMessage = "Registration failed. Please try again."
            }
        } catch let decodingError as DecodingError {
            print("Sign up decoding error: \(decodingError)")
            #if DEBUG
            switch decodingError {
            case .keyNotFound(let key, _):
                self.errorMessage = "Missing field: \(key.stringValue)"
            case .typeMismatch(let type, let context):
                self.errorMessage = "Type error: \(context.codingPath.last?.stringValue ?? "unknown") expected \(type)"
            default:
                self.errorMessage = "Decoding error: \(decodingError.localizedDescription)"
            }
            #else
            self.errorMessage = "Could not connect to the server. Please try again."
            #endif
        } catch {
            print("Sign up error: \(error)")
            #if DEBUG
            self.errorMessage = "Error: \(error.localizedDescription)"
            #else
            self.errorMessage = "Could not connect to the server. Please try again."
            #endif
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func getDeviceId() -> String {
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
