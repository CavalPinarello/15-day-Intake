//
//  ConvexServiceTests.swift
//  ZoeSleepTests
//
//  Unit tests for ConvexService
//

import XCTest
@testable import ZoeSleep

final class ConvexServiceTests: XCTestCase {

    var sut: ConvexService!

    override func setUp() {
        super.setUp()
        sut = ConvexService.shared
        // Clear session before each test
        sut.clearSession()
    }

    override func tearDown() {
        sut.clearSession()
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSingletonExists() {
        XCTAssertNotNil(ConvexService.shared)
    }

    func testSingletonIsSameInstance() {
        let instance1 = ConvexService.shared
        let instance2 = ConvexService.shared

        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Session Management Tests

    func testClearSessionResetsState() {
        // Set a session
        sut.setSession(token: "test_token", userId: "test_user", username: "testuser")

        // Clear it
        sut.clearSession()

        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.userId)
    }

    func testSetSessionUpdatesState() {
        sut.setSession(token: "test_token_123", userId: "user_123", username: "testuser")

        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(sut.userId, "user_123")
    }

    func testLoadSavedSessionWhenEmpty() {
        sut.clearSession()

        let session = sut.loadSavedSession()

        XCTAssertNil(session)
    }

    func testLoadSavedSessionAfterSet() {
        sut.setSession(token: "saved_token", userId: "saved_user", username: "saveduser")

        // Clear in-memory and reload from storage
        let session = sut.loadSavedSession()

        XCTAssertNotNil(session)
        XCTAssertEqual(session?.token, "saved_token")
        XCTAssertEqual(session?.userId, "saved_user")
    }

    func testIsAuthenticatedWhenNoSession() {
        sut.clearSession()

        XCTAssertFalse(sut.isAuthenticated)
    }

    func testIsAuthenticatedWithSession() {
        sut.setSession(token: "token", userId: "user", username: "user")

        XCTAssertTrue(sut.isAuthenticated)
    }

    // MARK: - Response Type Tests

    func testConvexUserDecoding() {
        let json = """
        {
            "username": "testuser",
            "email": "test@test.com",
            "currentDay": 5.0,
            "role": "patient",
            "onboardingCompleted": true,
            "appleHealthConnected": false,
            "fullName": "Test User",
            "measurementSystem": "Metric",
            "heightCm": 175.0,
            "weightKg": 70.0,
            "gender": "male",
            "birthYear": 1990.0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let user = try? decoder.decode(ConvexUser.self, from: json)

        XCTAssertNotNil(user)
        XCTAssertEqual(user?.username, "testuser")
        XCTAssertEqual(user?.currentDayInt, 5)
        XCTAssertEqual(user?.birthYearInt, 1990)
    }

    func testJourneyProgressDecoding() {
        let json = """
        {
            "currentDay": 3,
            "completedDays": [1, 2],
            "totalDays": 15,
            "journeyComplete": false,
            "sleepLogCompleted": true,
            "assessmentCompleted": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let progress = try? decoder.decode(JourneyProgress.self, from: json)

        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.currentDay, 3)
        XCTAssertEqual(progress?.completedDays, [1, 2])
        XCTAssertEqual(progress?.totalDays, 15)
        XCTAssertEqual(progress?.sleepLogCompleted, true)
        XCTAssertEqual(progress?.assessmentCompleted, false)
    }

    func testSleepDataRecordDecoding() {
        let json = """
        {
            "date": "2025-12-20",
            "inBedTime": 1640000000,
            "asleepTime": 1640001000,
            "wakeTime": 1640030000,
            "totalSleepMins": 420,
            "sleepEfficiency": 0.88,
            "deepSleepMins": 90,
            "lightSleepMins": 210,
            "remSleepMins": 100,
            "awakeMins": 20,
            "interruptionsCount": 3,
            "sleepLatencyMins": 15
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let record = try? decoder.decode(SleepDataRecord.self, from: json)

        XCTAssertNotNil(record)
        XCTAssertEqual(record?.date, "2025-12-20")
        XCTAssertEqual(record?.totalSleepMins, 420)
        XCTAssertEqual(record?.sleepEfficiency, 0.88)
    }

    // MARK: - Error Type Tests

    func testConvexErrorDescriptions() {
        XCTAssertEqual(ConvexError.invalidURL.errorDescription, "Invalid Convex URL")
        XCTAssertEqual(ConvexError.invalidResponse.errorDescription, "Invalid response from server")
        XCTAssertEqual(ConvexError.httpError(404).errorDescription, "HTTP error: 404")
        XCTAssertEqual(ConvexError.serverError("Test error").errorDescription, "Test error")
        XCTAssertEqual(ConvexError.notAuthenticated.errorDescription, "User not authenticated")
        XCTAssertEqual(ConvexError.decodingError.errorDescription, "Failed to decode response")
    }

    // MARK: - Query/Mutation Tests (require authentication)

    func testValidateSessionWhenNotAuthenticated() async {
        sut.clearSession()

        do {
            let response = try await sut.validateSession()
            XCTAssertFalse(response.valid)
        } catch {
            // Error is acceptable when no session
        }
    }

    func testGetJourneyProgressWhenNotAuthenticated() async {
        sut.clearSession()

        do {
            _ = try await sut.getJourneyProgress()
            XCTFail("Should throw when not authenticated")
        } catch {
            // Expected to throw
            XCTAssertTrue(error is ConvexError)
        }
    }

    func testGetQuestionsForUserDayWhenNotAuthenticated() async {
        sut.clearSession()

        do {
            _ = try await sut.getQuestionsForUserDay(dayNumber: 1)
            XCTFail("Should throw when not authenticated")
        } catch {
            XCTAssertTrue(error is ConvexError)
        }
    }

    // MARK: - AnyCodable Tests

    func testAnyCodableDecodesInt() {
        let json = "42".data(using: .utf8)!
        let decoder = JSONDecoder()
        let value = try? decoder.decode(AnyCodable.self, from: json)

        XCTAssertNotNil(value)
        XCTAssertEqual(value?.value as? Int, 42)
    }

    func testAnyCodableDecodesString() {
        let json = "\"test\"".data(using: .utf8)!
        let decoder = JSONDecoder()
        let value = try? decoder.decode(AnyCodable.self, from: json)

        XCTAssertNotNil(value)
        XCTAssertEqual(value?.value as? String, "test")
    }

    func testAnyCodableDecodesBool() {
        let json = "true".data(using: .utf8)!
        let decoder = JSONDecoder()
        let value = try? decoder.decode(AnyCodable.self, from: json)

        XCTAssertNotNil(value)
        XCTAssertEqual(value?.value as? Bool, true)
    }

    func testAnyCodableDecodesDouble() {
        let json = "3.14".data(using: .utf8)!
        let decoder = JSONDecoder()
        let value = try? decoder.decode(AnyCodable.self, from: json)

        XCTAssertNotNil(value)
        XCTAssertEqual(value?.value as? Double, 3.14)
    }
}

// MARK: - Response Type Encoding/Decoding Tests

extension ConvexServiceTests {

    func testCompleteSectionResponseDecoding() {
        let json = """
        {
            "success": true,
            "section": "sleepLog",
            "sleepLogCompleted": true,
            "assessmentCompleted": false,
            "dayFullyCompleted": false,
            "currentDay": 3,
            "journeyComplete": false,
            "source": "ios"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try? decoder.decode(CompleteSectionResponse.self, from: json)

        XCTAssertNotNil(response)
        XCTAssertTrue(response?.success ?? false)
        XCTAssertEqual(response?.section, "sleepLog")
        XCTAssertTrue(response?.sleepLogCompleted ?? false)
        XCTAssertFalse(response?.assessmentCompleted ?? true)
    }

    func testAdvanceDayResponseDecoding() {
        let json = """
        {
            "success": true,
            "newDay": 4,
            "previousDay": 3,
            "sleepLogCompleted": true,
            "assessmentCompleted": true,
            "timeUnlocked": true,
            "currentDay": 4
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try? decoder.decode(ConvexService.AdvanceDayResponse.self, from: json)

        XCTAssertNotNil(response)
        XCTAssertTrue(response?.success ?? false)
        XCTAssertEqual(response?.newDay, 4)
        XCTAssertEqual(response?.previousDay, 3)
    }

    func testExpansionScheduleSummaryDecoding() {
        let json = """
        {
            "hasSchedule": true,
            "triggeredGateways": ["insomnia", "anxiety"],
            "totalDays": 5,
            "totalQuestions": 50,
            "totalMinutes": 25,
            "completedDays": 2,
            "remainingDays": 3
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try? decoder.decode(ExpansionScheduleSummary.self, from: json)

        XCTAssertNotNil(response)
        XCTAssertTrue(response?.hasSchedule ?? false)
        XCTAssertEqual(response?.triggeredGateways, ["insomnia", "anxiety"])
        XCTAssertEqual(response?.totalDays, 5)
    }
}

// MARK: - Sleep Insights Types Tests

extension ConvexServiceTests {

    func testSleepDashboardSummaryDecoding() {
        let json = """
        {
            "daysOfData": 7,
            "hasEnoughForInsights": true,
            "hasEnoughForPatterns": false,
            "daysUntilInsights": 0,
            "daysUntilPatterns": 7,
            "weeklyAverage": {
                "sleepMins": 420,
                "efficiency": 85,
                "deepMins": 90,
                "remMins": 100
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try? decoder.decode(SleepDashboardSummary.self, from: json)

        XCTAssertNotNil(response)
        XCTAssertEqual(response?.daysOfData, 7)
        XCTAssertTrue(response?.hasEnoughForInsights ?? false)
        XCTAssertEqual(response?.weeklyAverage.sleepMins, 420)
    }
}

// MARK: - Device Info Tests

extension ConvexServiceTests {

    func testDeviceInfoCurrent() {
        let deviceInfo = DeviceInfo.current

        XCTAssertNotNil(deviceInfo.deviceName)
        XCTAssertNotNil(deviceInfo.deviceModel)
        XCTAssertNotNil(deviceInfo.osVersion)
    }
}

// MARK: - Keychain Helper Tests

extension ConvexServiceTests {

    func testKeychainSaveAndLoad() {
        let testKey = "test_keychain_key"
        let testValue = "test_keychain_value"

        // Save
        KeychainHelper.save(testValue, forKey: testKey)

        // Load
        let loaded = KeychainHelper.load(forKey: testKey)

        XCTAssertEqual(loaded, testValue)

        // Cleanup
        KeychainHelper.delete(forKey: testKey)
    }

    func testKeychainDelete() {
        let testKey = "test_delete_key"
        let testValue = "test_value"

        // Save
        KeychainHelper.save(testValue, forKey: testKey)

        // Delete
        KeychainHelper.delete(forKey: testKey)

        // Load should return nil
        let loaded = KeychainHelper.load(forKey: testKey)

        XCTAssertNil(loaded)
    }

    func testKeychainLoadNonexistent() {
        let loaded = KeychainHelper.load(forKey: "nonexistent_key_12345")

        XCTAssertNil(loaded)
    }

    func testKeychainOverwrite() {
        let testKey = "test_overwrite_key"

        // Save first value
        KeychainHelper.save("first_value", forKey: testKey)

        // Overwrite with second value
        KeychainHelper.save("second_value", forKey: testKey)

        // Load should return second value
        let loaded = KeychainHelper.load(forKey: testKey)

        XCTAssertEqual(loaded, "second_value")

        // Cleanup
        KeychainHelper.delete(forKey: testKey)
    }
}
