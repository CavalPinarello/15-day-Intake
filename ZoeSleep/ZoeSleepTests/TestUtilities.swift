//
//  TestUtilities.swift
//  ZoeSleepTests
//
//  Shared test utilities, mocks, and helpers for comprehensive testing
//

import Foundation
import XCTest
@testable import ZoeSleep

// MARK: - Test Configuration

struct TestConfig {
    static let testUsername = "test_user_001"
    static let testPassword = "test123"
    static let testEmail = "test_user_001@test.zoesleep.com"
    static let testUserId = "test_user_id_001"

    // Convex test endpoint (uses same as production for integration tests)
    static var convexURL: String {
        return Config.convexDeploymentURL
    }

    // Timeout for async operations
    static let asyncTimeout: TimeInterval = 10.0
    static let uiTimeout: TimeInterval = 5.0
}

// MARK: - Mock Convex Service

class MockConvexService {
    static let shared = MockConvexService()

    var shouldSucceed = true
    var mockUser: ConvexUser?
    var mockResponses: [String: Any] = [:]
    var callHistory: [(function: String, args: [String: Any])] = []

    func reset() {
        shouldSucceed = true
        mockUser = nil
        mockResponses = [:]
        callHistory = []
    }

    func setupDefaultUser() {
        mockUser = ConvexUser(
            username: TestConfig.testUsername,
            email: TestConfig.testEmail,
            currentDay: 1.0,
            role: "patient",
            onboardingCompleted: true,
            appleHealthConnected: false,
            fullName: "Test User",
            measurementSystem: "Metric",
            heightCm: 175.0,
            weightKg: 70.0,
            gender: "male",
            birthYear: 1990.0
        )
    }

    func setupUserAtDay(_ day: Int) {
        setupDefaultUser()
        mockUser = ConvexUser(
            username: mockUser!.username,
            email: mockUser!.email,
            currentDay: Double(day),
            role: mockUser!.role,
            onboardingCompleted: mockUser!.onboardingCompleted,
            appleHealthConnected: mockUser!.appleHealthConnected,
            fullName: mockUser!.fullName,
            measurementSystem: mockUser!.measurementSystem,
            heightCm: mockUser!.heightCm,
            weightKg: mockUser!.weightKg,
            gender: mockUser!.gender,
            birthYear: mockUser!.birthYear
        )
    }
}

// MARK: - Mock Response Value (for test generation)

enum MockResponseValue {
    case string(String)
    case number(Int)
    case array([String])
}

// MARK: - Mock Response (for test generation - not to be confused with ZoeSleep.QuestionResponse)

struct MockResponse {
    let questionId: String
    let value: MockResponseValue
}

// MARK: - Mock Response Generators

struct MockResponseGenerator {

    /// Generate mock responses that simulate specific gateways being triggered
    static func mockResponsesForGateways(_ gateways: [String]) -> [String: MockResponse] {
        var responses: [String: MockResponse] = [:]

        // Base responses
        responses["1"] = MockResponse(questionId: "1", value: .number(5))
        responses["D1"] = MockResponse(questionId: "D1", value: .number(35))
        responses["D2"] = MockResponse(questionId: "D2", value: .string("Male"))

        // Gateway triggers
        if gateways.contains("insomnia") {
            responses["3"] = MockResponse(questionId: "3", value: .string("Yes"))
        } else {
            responses["3"] = MockResponse(questionId: "3", value: .string("No"))
        }

        if gateways.contains("depression") {
            responses["15"] = MockResponse(questionId: "15", value: .number(2)) // More than half
        } else {
            responses["15"] = MockResponse(questionId: "15", value: .number(0))
        }

        if gateways.contains("anxiety") {
            responses["16"] = MockResponse(questionId: "16", value: .number(2))
        } else {
            responses["16"] = MockResponse(questionId: "16", value: .number(0))
        }

        if gateways.contains("osa") {
            responses["19"] = MockResponse(questionId: "19", value: .string("Yes"))
            responses["20"] = MockResponse(questionId: "20", value: .string("Yes"))
        } else {
            responses["19"] = MockResponse(questionId: "19", value: .string("No"))
            responses["20"] = MockResponse(questionId: "20", value: .string("No"))
        }

        if gateways.contains("pain") {
            responses["22"] = MockResponse(questionId: "22", value: .string("Yes"))
            responses["23"] = MockResponse(questionId: "23", value: .number(6))
        }

        return responses
    }

    /// Generate ISI responses for a target score
    static func isiResponses(targetScore: Int) -> [String: MockResponse] {
        var responses: [String: MockResponse] = [:]
        var remaining = min(28, max(0, targetScore))

        for i in 1...7 {
            let value: Int
            if i == 7 {
                value = min(4, remaining)
            } else {
                let maxForThis = min(4, remaining - (7 - i))
                let minForThis = max(0, remaining - (7 - i) * 4)
                value = Int.random(in: minForThis...max(minForThis, maxForThis))
                remaining -= value
            }
            responses["ISI_\(i)"] = MockResponse(questionId: "ISI_\(i)", value: .number(value))
        }

        return responses
    }

    /// Generate PHQ-9 responses for a target score
    static func phq9Responses(targetScore: Int) -> [String: MockResponse] {
        var responses: [String: MockResponse] = [:]
        var remaining = min(27, max(0, targetScore))

        for i in 1...9 {
            let value: Int
            if i == 9 {
                value = min(3, remaining)
            } else {
                let maxForThis = min(3, remaining - (9 - i))
                let minForThis = max(0, remaining - (9 - i) * 3)
                value = Int.random(in: minForThis...max(minForThis, maxForThis))
                remaining -= value
            }
            responses["PHQ9_\(i)"] = MockResponse(questionId: "PHQ9_\(i)", value: .number(value))
        }

        return responses
    }

    /// Generate sleep diary responses
    static func sleepDiaryResponses(
        bedtime: String = "23:00",
        latency: Int = 20,
        awakenings: Int = 2,
        waso: Int = 15,
        wakeTime: String = "07:00",
        quality: Int = 3
    ) -> [String: MockResponse] {
        return [
            "CSD_BEDTIME": MockResponse(questionId: "CSD_BEDTIME", value: .string(bedtime)),
            "CSD_LATENCY": MockResponse(questionId: "CSD_LATENCY", value: .number(latency)),
            "CSD_AWAKENINGS": MockResponse(questionId: "CSD_AWAKENINGS", value: .number(awakenings)),
            "CSD_WASO": MockResponse(questionId: "CSD_WASO", value: .number(waso)),
            "CSD_OUT_BED": MockResponse(questionId: "CSD_OUT_BED", value: .string(wakeTime)),
            "CSD_QUALITY": MockResponse(questionId: "CSD_QUALITY", value: .number(quality)),
        ]
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {

    /// Wait for async operation with timeout
    func waitForAsync(timeout: TimeInterval = TestConfig.asyncTimeout, _ operation: @escaping () async throws -> Void) {
        let expectation = self.expectation(description: "Async operation")

        Task {
            do {
                try await operation()
                expectation.fulfill()
            } catch {
                XCTFail("Async operation failed: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout)
    }

    /// Assert condition with retries (for flaky UI tests)
    func assertEventually(
        timeout: TimeInterval = TestConfig.uiTimeout,
        interval: TimeInterval = 0.1,
        _ condition: @autoclosure () -> Bool,
        message: String = "Condition not met within timeout"
    ) {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }
            Thread.sleep(forTimeInterval: interval)
        }

        XCTFail(message)
    }
}

// MARK: - Test Data Factory

class TestDataFactory {

    static func createTestUser(
        day: Int = 1,
        onboardingComplete: Bool = true,
        gateways: [String] = []
    ) -> ConvexUser {
        return ConvexUser(
            username: "test_\(UUID().uuidString.prefix(8))",
            email: "test_\(UUID().uuidString.prefix(8))@test.com",
            currentDay: Double(day),
            role: "patient",
            onboardingCompleted: onboardingComplete,
            appleHealthConnected: false,
            fullName: "Test User",
            measurementSystem: "Metric",
            heightCm: 175.0,
            weightKg: 70.0,
            gender: "male",
            birthYear: 1990.0
        )
    }

    static func createSleepData(
        totalSleep: Int = 420,
        efficiency: Int = 85,
        latency: Int = 15,
        awakenings: Int = 2
    ) -> [String: Any] {
        return [
            "total_sleep_mins": totalSleep,
            "sleep_efficiency": efficiency,
            "sleep_latency_mins": latency,
            "interruptions_count": awakenings,
            "deep_sleep_mins": Int(Double(totalSleep) * 0.2),
            "light_sleep_mins": Int(Double(totalSleep) * 0.5),
            "rem_sleep_mins": Int(Double(totalSleep) * 0.25),
        ]
    }

    /// Create a real QuestionResponse for use in tests
    static func createQuestionResponse(
        questionId: String,
        dayNumber: Int = 1,
        stringValue: String? = nil,
        numberValue: Double? = nil,
        arrayValue: [String]? = nil
    ) -> QuestionResponse {
        return QuestionResponse(
            questionId: questionId,
            dayNumber: dayNumber,
            stringValue: stringValue,
            numberValue: numberValue,
            arrayValue: arrayValue
        )
    }
}
