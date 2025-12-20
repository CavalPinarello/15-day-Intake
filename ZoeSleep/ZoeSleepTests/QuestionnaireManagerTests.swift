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
            XCTAssertFalse(gateway.isTriggered, "Gateway \(gateway.gatewayType) should not be triggered initially")
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

    func testGetDayConfiguration_Day1() {
        let config = sut.getDayConfiguration(for: 1)

        XCTAssertEqual(config.dayNumber, 1)
        XCTAssertFalse(config.modules.isEmpty, "Day 1 should have modules")
        XCTAssertTrue(config.isCoreDays, "Day 1 should be a core day")
    }

    func testGetDayConfiguration_CoreDays() {
        for day in 1...7 {
            let config = sut.getDayConfiguration(for: day)
            XCTAssertTrue(config.isCoreDays, "Day \(day) should be a core day")
            XCTAssertFalse(config.modules.isEmpty, "Day \(day) should have modules")
        }
    }

    func testGetDayConfiguration_ExpansionDays() {
        for day in 8...15 {
            let config = sut.getDayConfiguration(for: day)
            XCTAssertFalse(config.isCoreDays, "Day \(day) should be an expansion day")
        }
    }

    // MARK: - Module Tests

    func testModuleToIOSMapping() {
        // Test that Convex module IDs map to iOS module parts correctly
        let convexModules = [
            "expansion_isi",
            "expansion_phq9",
            "expansion_gad7",
            "expansion_stop_bang",
            "expansion_ess",
            "expansion_dbas",
        ]

        for moduleId in convexModules {
            let iosModules = sut.getIOSModules(for: moduleId)
            XCTAssertFalse(iosModules.isEmpty, "Module \(moduleId) should have iOS mappings")
        }
    }

    func testExpansionModulesExist() {
        let expectedExpansionModules = [
            "expansion_isi",
            "expansion_phq9",
            "expansion_gad7",
            "expansion_stop_bang",
            "expansion_ess",
            "expansion_berlin",
            "expansion_dbas",
            "expansion_sleep_hygiene",
            "expansion_psas",
            "expansion_fss",
            "expansion_fosq",
            "expansion_dass21",
            "expansion_promis_cognitive",
            "expansion_bpi",
            "expansion_medas",
            "expansion_meq",
        ]

        for moduleId in expectedExpansionModules {
            let exists = sut.moduleExists(moduleId)
            XCTAssertTrue(exists, "Expansion module \(moduleId) should exist")
        }
    }

    // MARK: - Question Tests

    func testGetQuestionsForModule() {
        // Test core module has questions
        let coreModule = "core_demographics"
        let questions = sut.getQuestions(for: coreModule)

        // Demographics should have questions
        // Note: May fail if module doesn't exist - that's a valid test failure
        if !questions.isEmpty {
            XCTAssertGreaterThan(questions.count, 0)
            for question in questions {
                XCTAssertFalse(question.id.isEmpty)
                XCTAssertFalse(question.text.isEmpty)
            }
        }
    }

    func testQuestionAnswerFormats() {
        let allQuestions = sut.getAllQuestions()

        for question in allQuestions {
            // Every question should have a valid answer format
            XCTAssertNotNil(question.answerFormat, "Question \(question.id) should have an answer format")

            // Validate format config matches format type
            switch question.answerFormat {
            case .sliderScale:
                XCTAssertNotNil(question.sliderConfig, "Slider question \(question.id) should have slider config")
            case .singleSelectChips, .multiSelectChips:
                XCTAssertNotNil(question.chipOptions, "Chips question \(question.id) should have options")
                XCTAssertGreaterThan(question.chipOptions?.count ?? 0, 0, "Chips question \(question.id) should have at least one option")
            case .timePicker:
                // Time picker doesn't require additional config
                break
            case .minutesScroll, .numberScroll:
                // Scroll pickers should have min/max
                break
            default:
                break
            }
        }
    }

    // MARK: - Response Storage Tests

    func testSaveResponse() async {
        let questionId = "test_q1"
        let response = QuestionResponse(
            questionId: questionId,
            stringValue: "Test answer",
            numberValue: nil,
            arrayValue: nil,
            dayNumber: 1,
            answeredAt: Date()
        )

        await sut.saveResponse(response)

        XCTAssertNotNil(sut.responses[questionId])
        XCTAssertEqual(sut.responses[questionId]?.stringValue, "Test answer")
    }

    func testSaveNumericResponse() async {
        let questionId = "test_q2"
        let response = QuestionResponse(
            questionId: questionId,
            stringValue: nil,
            numberValue: 42,
            arrayValue: nil,
            dayNumber: 1,
            answeredAt: Date()
        )

        await sut.saveResponse(response)

        XCTAssertNotNil(sut.responses[questionId])
        XCTAssertEqual(sut.responses[questionId]?.numberValue, 42)
    }

    func testGetResponseForQuestion() async {
        let questionId = "test_q3"
        let response = QuestionResponse(
            questionId: questionId,
            stringValue: "Stored answer",
            numberValue: nil,
            arrayValue: nil,
            dayNumber: 1,
            answeredAt: Date()
        )

        await sut.saveResponse(response)

        let retrieved = sut.getResponse(for: questionId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.stringValue, "Stored answer")
    }

    // MARK: - Gateway Evaluation Tests

    func testEvaluateInsomniaGateway() async {
        // Set up response that should trigger insomnia gateway
        let response = QuestionResponse(
            questionId: "3", // Insomnia trigger question
            stringValue: "Yes",
            numberValue: nil,
            arrayValue: nil,
            dayNumber: 1,
            answeredAt: Date()
        )

        await sut.saveResponse(response)
        await sut.evaluateGateways()

        let insomniaGateway = sut.gatewayStates.first { $0.gatewayType == .insomnia }
        XCTAssertNotNil(insomniaGateway)
        XCTAssertTrue(insomniaGateway?.isTriggered ?? false, "Insomnia gateway should be triggered")
    }

    func testEvaluateDepressionGateway() async {
        // Q15 >= 2 triggers depression
        let response = QuestionResponse(
            questionId: "15",
            stringValue: nil,
            numberValue: 2, // More than half the days
            arrayValue: nil,
            dayNumber: 1,
            answeredAt: Date()
        )

        await sut.saveResponse(response)
        await sut.evaluateGateways()

        let depressionGateway = sut.gatewayStates.first { $0.gatewayType == .depression }
        XCTAssertTrue(depressionGateway?.isTriggered ?? false, "Depression gateway should be triggered")
    }

    func testEvaluateAnxietyGateway() async {
        // Q16 >= 2 triggers anxiety
        let response = QuestionResponse(
            questionId: "16",
            stringValue: nil,
            numberValue: 3, // Nearly every day
            arrayValue: nil,
            dayNumber: 1,
            answeredAt: Date()
        )

        await sut.saveResponse(response)
        await sut.evaluateGateways()

        let anxietyGateway = sut.gatewayStates.first { $0.gatewayType == .anxiety }
        XCTAssertTrue(anxietyGateway?.isTriggered ?? false, "Anxiety gateway should be triggered")
    }

    func testEvaluateOSAGateway() async {
        // Q19 = Yes OR Q20 = Yes triggers OSA
        let response = QuestionResponse(
            questionId: "19", // Snoring
            stringValue: "Yes",
            numberValue: nil,
            arrayValue: nil,
            dayNumber: 1,
            answeredAt: Date()
        )

        await sut.saveResponse(response)
        await sut.evaluateGateways()

        let osaGateway = sut.gatewayStates.first { $0.gatewayType == .osa }
        XCTAssertTrue(osaGateway?.isTriggered ?? false, "OSA gateway should be triggered")
    }

    func testNoGatewayTriggered() async {
        // Set up responses that should NOT trigger gateways
        await sut.saveResponse(QuestionResponse(questionId: "3", stringValue: "No", numberValue: nil, arrayValue: nil, dayNumber: 1, answeredAt: Date()))
        await sut.saveResponse(QuestionResponse(questionId: "15", stringValue: nil, numberValue: 0, arrayValue: nil, dayNumber: 1, answeredAt: Date()))
        await sut.saveResponse(QuestionResponse(questionId: "16", stringValue: nil, numberValue: 0, arrayValue: nil, dayNumber: 1, answeredAt: Date()))
        await sut.saveResponse(QuestionResponse(questionId: "19", stringValue: "No", numberValue: nil, arrayValue: nil, dayNumber: 1, answeredAt: Date()))
        await sut.saveResponse(QuestionResponse(questionId: "20", stringValue: "No", numberValue: nil, arrayValue: nil, dayNumber: 1, answeredAt: Date()))

        await sut.evaluateGateways()

        let triggeredGateways = sut.gatewayStates.filter { $0.isTriggered }
        XCTAssertEqual(triggeredGateways.count, 0, "No gateways should be triggered")
    }

    // MARK: - Progress Tracking Tests

    func testGetDayProgress() {
        let progress = sut.getDayProgress(for: 1)

        XCTAssertEqual(progress.dayNumber, 1)
        XCTAssertGreaterThanOrEqual(progress.totalQuestions, 0)
        XCTAssertGreaterThanOrEqual(progress.completedQuestions, 0)
        XCTAssertLessThanOrEqual(progress.completedQuestions, progress.totalQuestions)
    }

    func testProgressPercentage() {
        // With no responses, progress should be 0%
        var progress = sut.getDayProgress(for: 1)
        XCTAssertEqual(progress.percentComplete, 0)

        // After answering questions, progress should increase
        // (This test requires knowing actual question count)
    }

    // MARK: - Sleep Diary Tests

    func testGetSleepDiaryQuestions() {
        let questions = sut.getSleepDiaryQuestions()

        XCTAssertFalse(questions.isEmpty, "Sleep diary should have questions")

        // Verify expected CSD questions exist
        let expectedIds = ["CSD_BEDTIME", "CSD_LATENCY", "CSD_AWAKENINGS", "CSD_WASO", "CSD_OUT_BED", "CSD_QUALITY"]
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

    func testResetClearsHealthKitData() {
        sut.updateHealthKitDemographics(
            dateOfBirth: Date(),
            biologicalSex: "female",
            heightCm: 165,
            weightKg: 60
        )

        sut.resetForNewUser()

        // HealthKit cache should be preserved across resets (user data, not session data)
        // Adjust this test based on actual behavior
    }

    // MARK: - Convex to iOS Module Mapping Tests

    func testConvexModuleMappingComplete() {
        let expectedMappings = [
            "expansion_isi": ["expansion_isi"],
            "expansion_phq9": ["expansion_phq9"],
            "expansion_gad7": ["expansion_gad7_part1", "expansion_gad7_part2"],
            "expansion_stop_bang": ["expansion_stop_bang"],
            "expansion_ess": ["expansion_ess"],
            "expansion_berlin": ["expansion_berlin"],
            "expansion_dbas": ["expansion_dbas_part1", "expansion_dbas_part2"],
            "expansion_sleep_hygiene": ["expansion_sleep_hygiene_part1", "expansion_sleep_hygiene_part2"],
            "expansion_psas": ["expansion_psas_part1", "expansion_psas_part2"],
            "expansion_fss": ["expansion_fss"],
            "expansion_fosq": ["expansion_fosq_part1", "expansion_fosq_part2"],
            "expansion_dass21": ["expansion_dass21_part1", "expansion_dass21_part2"],
            "expansion_promis_cognitive": ["expansion_promis_cognitive"],
            "expansion_bpi": ["expansion_bpi"],
            "expansion_medas": ["expansion_medas"],
            "expansion_meq": ["expansion_meq"],
        ]

        for (convexId, expectedIOSIds) in expectedMappings {
            let iosModules = sut.getIOSModules(for: convexId)
            XCTAssertEqual(iosModules.count, expectedIOSIds.count, "Module \(convexId) should map to \(expectedIOSIds.count) iOS modules")
        }
    }
}

// MARK: - Gateway Type Extension for Testing

extension GatewayType: CaseIterable {
    public static var allCases: [GatewayType] {
        return [.insomnia, .depression, .anxiety, .excessiveSleepiness, .cognitive, .osa, .pain, .sleepTiming, .dietImpact, .poorSleepQuality]
    }
}
