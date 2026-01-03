//
//  QuestionnaireManagerTests.swift
//  ZoeSleepTests
//
//  Comprehensive unit tests for QuestionnaireManager
//

import XCTest
@testable import ZoeSleep

@MainActor
final class QuestionnaireManagerTests: XCTestCase {

    var sut: QuestionnaireManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = QuestionnaireManager.shared
        sut.resetForNewUser()
    }

    override func tearDown() async throws {
        sut.resetForNewUser()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertEqual(sut.currentDay, 1)
        XCTAssertNil(sut.journeyProgress)
        XCTAssertTrue(sut.responses.isEmpty)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.gatewayStates.isEmpty)
    }

    func testGatewayStatesInitialized() {
        // All gateway types should be initialized
        let gatewayTypes = GatewayType.allCases
        XCTAssertEqual(sut.gatewayStates.count, gatewayTypes.count)

        for gateway in sut.gatewayStates {
            XCTAssertFalse(gateway.triggered, "Gateway \(gateway.gatewayType) should not be triggered initially")
        }
    }

    func testResetForNewUser() {
        // Modify state
        sut.currentDay = 5
        sut.error = "Test error"

        // Reset
        sut.resetForNewUser()

        // Verify reset
        XCTAssertEqual(sut.currentDay, 1)
        XCTAssertNil(sut.error)
        XCTAssertTrue(sut.responses.isEmpty)
    }

    // MARK: - Day Configuration Tests

    func testDayConfigurationsExist() {
        let configs = QuestionnaireManager.dayConfigurations
        XCTAssertEqual(configs.count, 10, "Should have 10 day configurations")
    }

    func testDayConfiguration_Day1() {
        let configs = QuestionnaireManager.dayConfigurations
        guard let day1Config = configs.first(where: { $0.dayNumber == 1 }) else {
            XCTFail("Day 1 configuration should exist")
            return
        }

        XCTAssertEqual(day1Config.dayNumber, 1)
        XCTAssertFalse(day1Config.moduleIds.isEmpty, "Day 1 should have modules")
        XCTAssertFalse(day1Config.isExpansionDay, "Day 1 should be a core day")
    }

    func testDayConfiguration_CoreDays() {
        let configs = QuestionnaireManager.dayConfigurations
        for day in 1...5 {
            guard let config = configs.first(where: { $0.dayNumber == day }) else {
                XCTFail("Day \(day) configuration should exist")
                continue
            }
            XCTAssertFalse(config.isExpansionDay, "Day \(day) should be a core day")
            XCTAssertFalse(config.moduleIds.isEmpty, "Day \(day) should have modules")
        }
    }

    func testDayConfiguration_ExpansionDays() {
        let configs = QuestionnaireManager.dayConfigurations
        // Journey is now 10 days (updated Jan 3, 2026)
        for day in 6...10 {
            guard let config = configs.first(where: { $0.dayNumber == day }) else {
                XCTFail("Day \(day) configuration should exist")
                continue
            }
            XCTAssertTrue(config.isExpansionDay, "Day \(day) should be an expansion day")
        }
    }

    // MARK: - Sleep Diary Tests

    func testConsensusSleepDiaryQuestionsExist() {
        let questions = QuestionnaireManager.consensusSleepDiaryQuestions
        XCTAssertFalse(questions.isEmpty, "Sleep diary should have questions")
    }

    func testConsensusSleepDiaryHasExpectedQuestions() {
        let questions = QuestionnaireManager.consensusSleepDiaryQuestions

        // Verify expected CSD questions exist
        let expectedIds = ["CSD_DAY_TYPE", "CSD_INTO_BED", "CSD_TRY_SLEEP", "CSD_LATENCY", "CSD_AWAKENINGS"]
        for expectedId in expectedIds {
            let found = questions.contains { $0.id == expectedId }
            XCTAssertTrue(found, "Sleep diary should contain \(expectedId)")
        }
    }

    // MARK: - HealthKit Demographics Tests

    func testHealthKitDemographicsCache() {
        XCTAssertNil(sut.healthKitDateOfBirth)
        XCTAssertNil(sut.healthKitBiologicalSex)

        let dob = Date(timeIntervalSince1970: 0)
        sut.updateHealthKitDemographics(
            dateOfBirth: dob,
            biologicalSex: "male",
            heightCm: 180,
            weightKg: 75
        )

        XCTAssertEqual(sut.healthKitDateOfBirth, dob)
        XCTAssertEqual(sut.healthKitBiologicalSex, "male")
        XCTAssertEqual(sut.healthKitHeightCm, 180)
        XCTAssertEqual(sut.healthKitWeightKg, 75)
    }

    // MARK: - Gateway State Tests

    func testGatewayStateInitialization() {
        let gateway = GatewayState(gatewayType: .insomnia)
        XCTAssertEqual(gateway.id, "insomnia")
        XCTAssertEqual(gateway.gatewayType, .insomnia)
        XCTAssertFalse(gateway.triggered)
        XCTAssertNil(gateway.triggeredAt)
    }

    func testGatewayStateTriggered() {
        let gateway = GatewayState(gatewayType: .depression, triggered: true, triggeredAt: Date())
        XCTAssertTrue(gateway.triggered)
        XCTAssertNotNil(gateway.triggeredAt)
    }

    // MARK: - Response Storage Tests

    func testResponseStorage() {
        let questionId = "test_q1"
        let response = QuestionResponse(
            questionId: questionId,
            dayNumber: 1,
            stringValue: "Test answer"
        )

        sut.responses[questionId] = response

        XCTAssertNotNil(sut.responses[questionId])
        XCTAssertEqual(sut.responses[questionId]?.stringValue, "Test answer")
    }

    func testNumericResponseStorage() {
        let questionId = "test_q2"
        let response = QuestionResponse(
            questionId: questionId,
            dayNumber: 1,
            numberValue: 42
        )

        sut.responses[questionId] = response

        XCTAssertNotNil(sut.responses[questionId])
        XCTAssertEqual(sut.responses[questionId]?.numberValue, 42)
    }

    func testArrayResponseStorage() {
        let questionId = "test_q3"
        let response = QuestionResponse(
            questionId: questionId,
            dayNumber: 1,
            arrayValue: ["Option A", "Option B"]
        )

        sut.responses[questionId] = response

        XCTAssertNotNil(sut.responses[questionId])
        XCTAssertEqual(sut.responses[questionId]?.arrayValue?.count, 2)
    }

    // MARK: - Day Configuration Model Tests

    func testDayConfigurationFormattedTitle() {
        let config = DayConfiguration(
            id: 1,
            dayNumber: 1,
            title: "Test Day",
            description: "Test description",
            estimatedMinutes: 10,
            moduleIds: ["test_module"],
            isExpansionDay: false,
            requiredGateways: nil
        )

        XCTAssertEqual(config.formattedTitle, "Day 1: Test Day")
    }

    func testDayConfigurationWithGateways() {
        let config = DayConfiguration(
            id: 6,
            dayNumber: 6,
            title: "Expansion Day",
            description: "Test expansion",
            estimatedMinutes: 15,
            moduleIds: ["expansion_isi"],
            isExpansionDay: true,
            requiredGateways: [.insomnia, .poorSleepQuality]
        )

        XCTAssertTrue(config.isExpansionDay)
        XCTAssertEqual(config.requiredGateways?.count, 2)
        XCTAssertTrue(config.requiredGateways?.contains(.insomnia) ?? false)
    }

    // MARK: - Gateway Type Tests

    func testAllGatewayTypes() {
        let allTypes = GatewayType.allCases
        XCTAssertEqual(allTypes.count, 10)
        XCTAssertTrue(allTypes.contains(.insomnia))
        XCTAssertTrue(allTypes.contains(.depression))
        XCTAssertTrue(allTypes.contains(.anxiety))
        XCTAssertTrue(allTypes.contains(.excessiveSleepiness))
        XCTAssertTrue(allTypes.contains(.cognitive))
        XCTAssertTrue(allTypes.contains(.osa))
        XCTAssertTrue(allTypes.contains(.pain))
        XCTAssertTrue(allTypes.contains(.sleepTiming))
        XCTAssertTrue(allTypes.contains(.dietImpact))
        XCTAssertTrue(allTypes.contains(.poorSleepQuality))
    }

    func testGatewayTypeRawValues() {
        XCTAssertEqual(GatewayType.insomnia.rawValue, "insomnia")
        XCTAssertEqual(GatewayType.depression.rawValue, "depression")
        XCTAssertEqual(GatewayType.osa.rawValue, "osa")
    }

    // MARK: - Response Model Tests

    func testQuestionResponseEncoding() throws {
        let response = QuestionResponse(
            questionId: "test_q",
            dayNumber: 1,
            stringValue: "Test",
            answeredInSeconds: 30,
            isDerived: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        XCTAssertFalse(data.isEmpty)
    }

    func testQuestionResponseDecoding() throws {
        // Create a JSON representation
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "questionId": "test_q",
            "dayNumber": 1,
            "stringValue": "Test",
            "answeredAt": 1234567890,
            "answeredInSeconds": 30,
            "isDerived": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QuestionResponse.self, from: json)
        XCTAssertEqual(decoded.questionId, "test_q")
        XCTAssertEqual(decoded.stringValue, "Test")
        XCTAssertEqual(decoded.answeredInSeconds, 30)
        XCTAssertFalse(decoded.isDerived)
    }

    func testDerivedResponse() {
        let response = QuestionResponse(
            questionId: "derived_q",
            dayNumber: 1,
            stringValue: "Derived from other question",
            isDerived: true
        )

        XCTAssertTrue(response.isDerived)
    }

    // MARK: - Current Day Tests

    func testCurrentDayModification() {
        XCTAssertEqual(sut.currentDay, 1)

        sut.currentDay = 5
        XCTAssertEqual(sut.currentDay, 5)

        sut.currentDay = 15
        XCTAssertEqual(sut.currentDay, 15)
    }

    // MARK: - Scheduled Expansion Tests

    func testScheduledExpansionInitiallyNil() {
        XCTAssertNil(sut.scheduledExpansionForToday)
    }

    // MARK: - Response DisplayValue Tests

    func testResponseDisplayValueString() {
        let response = QuestionResponse(
            questionId: "q1",
            dayNumber: 1,
            stringValue: "Hello World"
        )
        XCTAssertEqual(response.displayValue, "Hello World")
    }

    func testResponseDisplayValueNumber() {
        let response = QuestionResponse(
            questionId: "q2",
            dayNumber: 1,
            numberValue: 7.5
        )
        XCTAssertEqual(response.displayValue, "7.5")
    }

    func testResponseDisplayValueArray() {
        let response = QuestionResponse(
            questionId: "q3",
            dayNumber: 1,
            arrayValue: ["Option A", "Option B", "Option C"]
        )
        XCTAssertEqual(response.displayValue, "Option A, Option B, Option C")
    }

    func testResponseDisplayValueEmpty() {
        let response = QuestionResponse(
            questionId: "q4",
            dayNumber: 1
        )
        XCTAssertEqual(response.displayValue, "")
    }
}
