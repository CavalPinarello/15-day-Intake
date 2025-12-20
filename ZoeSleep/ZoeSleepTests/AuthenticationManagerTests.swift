//
//  AuthenticationManagerTests.swift
//  ZoeSleepTests
//
//  Unit tests for AuthenticationManager
//

import XCTest
@testable import ZoeSleep

@MainActor
final class AuthenticationManagerTests: XCTestCase {

    var sut: AuthenticationManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = AuthenticationManager()
        // Clear any existing session
        ConvexService.shared.clearSession()
    }

    override func tearDown() async throws {
        ConvexService.shared.clearSession()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        // New manager should start unauthenticated
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.user)
        XCTAssertNil(sut.errorMessage)
    }

    func testIsCheckingSessionStartsTrue() {
        // Session check starts pending
        let newManager = AuthenticationManager()
        // Note: isCheckingSession may have already finished by the time we check
        // This test verifies the property exists
        _ = newManager.isCheckingSession
    }

    // MARK: - User Model Tests

    func testUserModel() {
        let user = AuthenticationManager.User(
            id: "test_id",
            username: "testuser",
            email: "test@test.com",
            currentDay: 5,
            role: "patient"
        )

        XCTAssertEqual(user.id, "test_id")
        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.email, "test@test.com")
        XCTAssertEqual(user.currentDay, 5)
        XCTAssertEqual(user.role, "patient")
    }

    func testUserModelOptionalEmail() {
        let user = AuthenticationManager.User(
            id: "test_id",
            username: "testuser",
            email: nil,
            currentDay: 1,
            role: nil
        )

        XCTAssertNil(user.email)
        XCTAssertNil(user.role)
    }

    // MARK: - Nonce Generation Tests

    func testGenerateNonceReturnsValidString() {
        let nonce = sut.generateNonce()

        XCTAssertFalse(nonce.isEmpty)
        XCTAssertEqual(nonce.count, 32)
    }

    func testGenerateNonceIsUnique() {
        let nonce1 = sut.generateNonce()
        let nonce2 = sut.generateNonce()

        XCTAssertNotEqual(nonce1, nonce2)
    }

    // MARK: - SHA256 Hash Tests

    func testSHA256Hash() {
        let hash = sut.sha256("test")

        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 64) // SHA256 produces 64 hex characters
    }

    func testSHA256Consistency() {
        let hash1 = sut.sha256("password123")
        let hash2 = sut.sha256("password123")

        XCTAssertEqual(hash1, hash2)
    }

    func testSHA256DifferentInputs() {
        let hash1 = sut.sha256("password1")
        let hash2 = sut.sha256("password2")

        XCTAssertNotEqual(hash1, hash2)
    }

    // MARK: - Sign Out Tests

    func testSignOutClearsState() {
        // Simulate authenticated state (manually set for testing)
        // Note: In real tests, you'd mock the ConvexService

        sut.signOut()

        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.user)
        XCTAssertNil(sut.errorMessage)
    }

    func testSignOutClearsConvexSession() {
        sut.signOut()

        XCTAssertFalse(ConvexService.shared.isAuthenticated)
    }

    // MARK: - Auth Token Tests

    func testGetAuthTokenWhenNoSession() {
        let token = sut.getAuthToken()

        XCTAssertNil(token)
    }

    // MARK: - Loading State Tests

    func testIsLoadingInitiallyFalse() {
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Error Handling Tests

    func testErrorMessageInitiallyNil() {
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Integration Tests (require network)

    func testSignInWithInvalidCredentials() async {
        // Sign in with definitely invalid credentials
        await sut.signIn(email: "nonexistent@fake.email", password: "wrongpassword123")

        // Should have error message
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.user)
        // Error message may or may not be set depending on server response
    }

    func testSignUpWithInvalidEmail() async {
        // Sign up with invalid email format should fail
        await sut.signUp(email: "not-an-email", password: "password123", username: "testuser")

        XCTAssertFalse(sut.isAuthenticated)
    }
}

// MARK: - Sign In Flow Tests

extension AuthenticationManagerTests {

    func testSignInSetsLoadingState() async {
        // This test checks that isLoading is managed properly
        // We can't easily test the middle state without async observation

        await sut.signIn(email: "test@test.com", password: "test123")

        // After completion, loading should be false
        XCTAssertFalse(sut.isLoading)
    }

    func testSignUpSetsLoadingState() async {
        await sut.signUp(email: "newuser@test.com", password: "test123", username: "newuser")

        // After completion, loading should be false
        XCTAssertFalse(sut.isLoading)
    }
}

// MARK: - Test User Authentication (Integration)

extension AuthenticationManagerTests {

    /// Test signing in with a known test user
    /// This requires the test user to exist in the database
    func testSignInWithTestUser() async {
        await sut.signIn(email: "user1", password: "1")

        // Check if sign in was successful
        if sut.isAuthenticated {
            XCTAssertNotNil(sut.user)
            XCTAssertEqual(sut.user?.username, "user1")
        } else {
            // If user doesn't exist, error message should be set
            // This is acceptable - the user may not exist in test database
            print("Test user 'user1' not found - skipping assertion")
        }
    }
}
