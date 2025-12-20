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
            currentDay: 1,
            role: "patient",
            onboardingCompleted: true,
            appleHealthConnected: false,
            fullName: "Test User",
            measurementSystem: "Metric",
            heightCm: 175,
            weightKg: 70,
            gender: "male",
            birthYear: 1990
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

// MARK: - Mock Question Data

struct MockQuestionData {

    // Core assessment questions
    static let coreQuestions: [Question] = [
        Question(
            id: "D1",
            text: "What is your age?",
            helpText: "Your age helps us personalize recommendations",
            answerFormat: .numberInput,
            formatConfig: NumberInputConfig(min: 18, max: 100, defaultValue: 30),
            pillar: "Demographics",
            tier: "Core"
        ),
        Question(
            id: "D2",
            text: "What is your biological sex?",
            helpText: nil,
            answerFormat: .singleSelectChips,
            formatConfig: ChipsConfig(options: ["Male", "Female", "Other"]),
            pillar: "Demographics",
            tier: "Core"
        ),
        Question(
            id: "1",
            text: "How would you rate your overall sleep quality?",
            helpText: "Consider the past month",
            answerFormat: .sliderScale,
            formatConfig: SliderConfig(min: 1, max: 10, defaultValue: 5, labels: ["Poor", "Excellent"]),
            pillar: "Sleep Quality",
            tier: "Core"
        ),
        Question(
            id: "3",
            text: "Do you have trouble falling asleep, staying asleep, or waking too early?",
            helpText: nil,
            answerFormat: .singleSelectChips,
            formatConfig: ChipsConfig(options: ["Yes", "No"]),
            pillar: "Sleep Quality",
            tier: "Gateway"
        ),
        Question(
            id: "15",
            text: "In the past 2 weeks, have you felt down, depressed, or hopeless?",
            helpText: nil,
            answerFormat: .singleSelectChips,
            formatConfig: ChipsConfig(options: ["Not at all", "Several days", "More than half", "Nearly every day"]),
            pillar: "Mental Health",
            tier: "Gateway"
        ),
        Question(
            id: "16",
            text: "In the past 2 weeks, have you felt nervous, anxious, or on edge?",
            helpText: nil,
            answerFormat: .singleSelectChips,
            formatConfig: ChipsConfig(options: ["Not at all", "Several days", "More than half", "Nearly every day"]),
            pillar: "Mental Health",
            tier: "Gateway"
        ),
    ]

    // Sleep diary questions (CSD)
    static let sleepDiaryQuestions: [Question] = [
        Question(
            id: "CSD_BEDTIME",
            text: "What time did you get into bed last night?",
            helpText: nil,
            answerFormat: .timePicker,
            formatConfig: TimePickerConfig(defaultHour: 22, defaultMinute: 30),
            pillar: "Sleep Diary",
            tier: "Daily"
        ),
        Question(
            id: "CSD_LATENCY",
            text: "How long did it take you to fall asleep?",
            helpText: "In minutes",
            answerFormat: .minutesScroll,
            formatConfig: MinutesScrollConfig(min: 0, max: 180, defaultValue: 15, step: 5),
            pillar: "Sleep Diary",
            tier: "Daily"
        ),
        Question(
            id: "CSD_AWAKENINGS",
            text: "How many times did you wake up during the night?",
            helpText: nil,
            answerFormat: .numberScroll,
            formatConfig: NumberScrollConfig(min: 0, max: 20, defaultValue: 1),
            pillar: "Sleep Diary",
            tier: "Daily"
        ),
        Question(
            id: "CSD_WASO",
            text: "How long were you awake during the night in total?",
            helpText: "Total minutes awake after falling asleep",
            answerFormat: .minutesScroll,
            formatConfig: MinutesScrollConfig(min: 0, max: 300, defaultValue: 15, step: 5),
            pillar: "Sleep Diary",
            tier: "Daily"
        ),
        Question(
            id: "CSD_OUT_BED",
            text: "What time did you get out of bed this morning?",
            helpText: nil,
            answerFormat: .timePicker,
            formatConfig: TimePickerConfig(defaultHour: 7, defaultMinute: 0),
            pillar: "Sleep Diary",
            tier: "Daily"
        ),
        Question(
            id: "CSD_QUALITY",
            text: "How would you rate your sleep quality last night?",
            helpText: nil,
            answerFormat: .sliderScale,
            formatConfig: SliderConfig(min: 1, max: 5, defaultValue: 3, labels: ["Very Poor", "Very Good"]),
            pillar: "Sleep Diary",
            tier: "Daily"
        ),
    ]

    // ISI questions
    static let isiQuestions: [Question] = (1...7).map { i in
        Question(
            id: "ISI_\(i)",
            text: "ISI Question \(i)",
            helpText: nil,
            answerFormat: .sliderScale,
            formatConfig: SliderConfig(min: 0, max: 4, defaultValue: 0, labels: ["None", "Very Severe"]),
            pillar: "Insomnia",
            tier: "Expansion"
        )
    }

    // PHQ-9 questions
    static let phq9Questions: [Question] = (1...9).map { i in
        Question(
            id: "PHQ9_\(i)",
            text: "PHQ-9 Question \(i)",
            helpText: nil,
            answerFormat: .singleSelectChips,
            formatConfig: ChipsConfig(options: ["Not at all", "Several days", "More than half", "Nearly every day"]),
            pillar: "Mental Health",
            tier: "Expansion"
        )
    }

    // GAD-7 questions
    static let gad7Questions: [Question] = (1...7).map { i in
        Question(
            id: "GAD7_\(i)",
            text: "GAD-7 Question \(i)",
            helpText: nil,
            answerFormat: .singleSelectChips,
            formatConfig: ChipsConfig(options: ["Not at all", "Several days", "More than half", "Nearly every day"]),
            pillar: "Mental Health",
            tier: "Expansion"
        )
    }

    // STOP-BANG questions
    static let stopBangQuestions: [Question] = (1...8).map { i in
        Question(
            id: "SB_\(i)",
            text: "STOP-BANG Question \(i)",
            helpText: nil,
            answerFormat: .singleSelectChips,
            formatConfig: ChipsConfig(options: ["Yes", "No"]),
            pillar: "Sleep Apnea",
            tier: "Expansion"
        )
    }

    static var allQuestions: [Question] {
        return coreQuestions + sleepDiaryQuestions + isiQuestions + phq9Questions + gad7Questions + stopBangQuestions
    }
}

// MARK: - Mock Response Generators

struct MockResponseGenerator {

    /// Generate responses that trigger specific gateways
    static func responsesForGateways(_ gateways: [String]) -> [String: QuestionResponse] {
        var responses: [String: QuestionResponse] = [:]

        // Base responses
        responses["1"] = QuestionResponse(questionId: "1", value: .number(5))
        responses["D1"] = QuestionResponse(questionId: "D1", value: .number(35))
        responses["D2"] = QuestionResponse(questionId: "D2", value: .string("Male"))

        // Gateway triggers
        if gateways.contains("insomnia") {
            responses["3"] = QuestionResponse(questionId: "3", value: .string("Yes"))
        } else {
            responses["3"] = QuestionResponse(questionId: "3", value: .string("No"))
        }

        if gateways.contains("depression") {
            responses["15"] = QuestionResponse(questionId: "15", value: .number(2)) // More than half
        } else {
            responses["15"] = QuestionResponse(questionId: "15", value: .number(0))
        }

        if gateways.contains("anxiety") {
            responses["16"] = QuestionResponse(questionId: "16", value: .number(2))
        } else {
            responses["16"] = QuestionResponse(questionId: "16", value: .number(0))
        }

        if gateways.contains("osa") {
            responses["19"] = QuestionResponse(questionId: "19", value: .string("Yes"))
            responses["20"] = QuestionResponse(questionId: "20", value: .string("Yes"))
        } else {
            responses["19"] = QuestionResponse(questionId: "19", value: .string("No"))
            responses["20"] = QuestionResponse(questionId: "20", value: .string("No"))
        }

        if gateways.contains("pain") {
            responses["22"] = QuestionResponse(questionId: "22", value: .string("Yes"))
            responses["23"] = QuestionResponse(questionId: "23", value: .number(6))
        }

        return responses
    }

    /// Generate ISI responses for a target score
    static func isiResponses(targetScore: Int) -> [String: QuestionResponse] {
        var responses: [String: QuestionResponse] = [:]
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
            responses["ISI_\(i)"] = QuestionResponse(questionId: "ISI_\(i)", value: .number(value))
        }

        return responses
    }

    /// Generate PHQ-9 responses for a target score
    static func phq9Responses(targetScore: Int) -> [String: QuestionResponse] {
        var responses: [String: QuestionResponse] = [:]
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
            responses["PHQ9_\(i)"] = QuestionResponse(questionId: "PHQ9_\(i)", value: .number(value))
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
    ) -> [String: QuestionResponse] {
        return [
            "CSD_BEDTIME": QuestionResponse(questionId: "CSD_BEDTIME", value: .string(bedtime)),
            "CSD_LATENCY": QuestionResponse(questionId: "CSD_LATENCY", value: .number(latency)),
            "CSD_AWAKENINGS": QuestionResponse(questionId: "CSD_AWAKENINGS", value: .number(awakenings)),
            "CSD_WASO": QuestionResponse(questionId: "CSD_WASO", value: .number(waso)),
            "CSD_OUT_BED": QuestionResponse(questionId: "CSD_OUT_BED", value: .string(wakeTime)),
            "CSD_QUALITY": QuestionResponse(questionId: "CSD_QUALITY", value: .number(quality)),
        ]
    }
}

// MARK: - Placeholder Types (to be replaced by actual imports)

// These are placeholder types - in real tests, import from ZoeSleep module

struct Question {
    let id: String
    let text: String
    let helpText: String?
    let answerFormat: AnswerFormat
    let formatConfig: Any
    let pillar: String
    let tier: String
}

enum AnswerFormat {
    case timePicker
    case minutesScroll
    case numberScroll
    case numberInput
    case sliderScale
    case singleSelectChips
    case multiSelectChips
    case datePicker
}

struct TimePickerConfig {
    let defaultHour: Int
    let defaultMinute: Int
}

struct MinutesScrollConfig {
    let min: Int
    let max: Int
    let defaultValue: Int
    let step: Int
}

struct NumberScrollConfig {
    let min: Int
    let max: Int
    let defaultValue: Int
}

struct NumberInputConfig {
    let min: Int
    let max: Int
    let defaultValue: Int
}

struct SliderConfig {
    let min: Int
    let max: Int
    let defaultValue: Int
    let labels: [String]
}

struct ChipsConfig {
    let options: [String]
}

struct QuestionResponse {
    let questionId: String
    let value: ResponseValue
}

enum ResponseValue {
    case string(String)
    case number(Int)
    case array([String])
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
            heightCm: 175,
            weightKg: 70,
            gender: "male",
            birthYear: 1990
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
}
