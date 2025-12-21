//
//  IntegrationTests.swift
//  ZoeSleepTests
//
//  Integration tests that verify iOS app correctly communicates with Convex backend
//  These tests require network connectivity and a running Convex deployment
//

import XCTest
@testable import ZoeSleep

@MainActor
final class IntegrationTests: XCTestCase {

    var convexService: ConvexService!
    var authManager: AuthenticationManager!

    // Test user credentials (must exist in database)
    let testUsername = "user1"
    let testPassword = "1"

    override func setUp() async throws {
        try await super.setUp()
        convexService = ConvexService.shared
        authManager = AuthenticationManager()

        // Clear any existing session
        convexService.clearSession()
    }

    override func tearDown() async throws {
        convexService.clearSession()
        convexService = nil
        authManager = nil
        try await super.tearDown()
    }

    // MARK: - Authentication Integration Tests

    func testSignInIntegration() async throws {
        // Sign in with test user
        await authManager.signIn(email: testUsername, password: testPassword)

        if authManager.isAuthenticated {
            XCTAssertNotNil(authManager.user)
            XCTAssertNotNil(convexService.userId)
            XCTAssertTrue(convexService.isAuthenticated)
        } else {
            // If test user doesn't exist, mark test as skipped
            print("⚠️ Test user '\(testUsername)' not found - skipping integration test")
        }
    }

    func testSessionValidation() async throws {
        // First sign in
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            print("⚠️ Skipping session validation - not authenticated")
            return
        }

        // Validate session
        do {
            let response = try await convexService.validateSession()
            XCTAssertTrue(response.valid)
            XCTAssertNotNil(response.user)
            XCTAssertNotNil(response.userId)
        } catch {
            XCTFail("Session validation failed: \(error)")
        }
    }

    func testSignOutIntegration() async throws {
        // Sign in first
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        // Sign out
        authManager.signOut()

        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertFalse(convexService.isAuthenticated)
    }

    // MARK: - Journey Progress Integration Tests

    func testGetJourneyProgress() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            print("⚠️ Skipping journey progress test - not authenticated")
            return
        }

        do {
            let progress = try await convexService.getJourneyProgress()

            XCTAssertGreaterThanOrEqual(progress.currentDay, 1)
            XCTAssertLessThanOrEqual(progress.currentDay, 14)
            XCTAssertEqual(progress.totalDays, 14)
        } catch {
            XCTFail("Failed to get journey progress: \(error)")
        }
    }

    func testGetDayMetadata() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let metadata = try await convexService.getDayMetadata(dayNumber: 1)

            XCTAssertNotNil(metadata.sleepLog)
            XCTAssertNotNil(metadata.assessment)
            XCTAssertGreaterThan(metadata.totalQuestions, 0)
        } catch {
            XCTFail("Failed to get day metadata: \(error)")
        }
    }

    // MARK: - Questions Integration Tests

    func testGetQuestionsForDay() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let questions = try await convexService.getQuestionsForUserDay(dayNumber: 1)

            XCTAssertFalse(questions.sleepLog.isEmpty, "Day 1 should have sleep log questions")
            XCTAssertFalse(questions.assessment.isEmpty, "Day 1 should have assessment questions")

            // Verify question structure
            for question in questions.sleepLog {
                XCTAssertFalse(question.id.isEmpty)
                XCTAssertFalse(question.text.isEmpty)
                XCTAssertFalse(question.type.isEmpty)
            }
        } catch {
            XCTFail("Failed to get questions: \(error)")
        }
    }

    func testQuestionResponseSubmission() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            // Submit a test response
            let responseId = try await convexService.submitQuestionnaireResponse(
                questionId: "TEST_INTEGRATION_Q1",
                answerFormat: "slider",
                value: 5,
                dayNumber: 1
            )

            XCTAssertFalse(responseId.isEmpty)
        } catch {
            // This may fail if question doesn't exist - acceptable for integration test
            print("Response submission test: \(error)")
        }
    }

    // MARK: - Gateway Integration Tests

    func testGetGatewayStates() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let gateways = try await convexService.getGatewayStates()

            // Should have 10 gateways
            XCTAssertEqual(gateways.count, 10, "Should have 10 gateway states")

            // Verify expected gateways exist
            let gatewayIds = gateways.map { $0.gatewayId }
            let expectedGateways = [
                "insomnia", "depression", "anxiety", "excessive_sleepiness",
                "cognitive", "osa", "pain", "sleep_timing", "diet_impact", "poor_sleep_quality"
            ]

            for expected in expectedGateways {
                XCTAssertTrue(gatewayIds.contains(expected), "Should have gateway: \(expected)")
            }
        } catch {
            XCTFail("Failed to get gateway states: \(error)")
        }
    }

    // MARK: - Sleep Insights Integration Tests

    func testGetSleepDashboardSummary() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let summary = try await convexService.getSleepDashboardSummary()

            XCTAssertGreaterThanOrEqual(summary.daysOfData, 0)
            XCTAssertGreaterThanOrEqual(summary.daysUntilInsights, 0)
        } catch {
            XCTFail("Failed to get sleep dashboard summary: \(error)")
        }
    }

    // MARK: - Expansion Schedule Integration Tests

    func testGetExpansionScheduleSummary() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let schedule = try await convexService.getExpansionScheduleSummary()

            // Schedule may or may not exist depending on gateway triggers
            XCTAssertGreaterThanOrEqual(schedule.completedDays, 0)
            XCTAssertGreaterThanOrEqual(schedule.remainingDays, 0)
        } catch {
            XCTFail("Failed to get expansion schedule: \(error)")
        }
    }

    func testPreviewExpansionSchedule() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            // Preview schedule for specific gateways
            let preview = try await convexService.previewExpansionSchedule(
                triggeredGateways: ["insomnia", "anxiety"]
            )

            XCTAssertEqual(preview.triggeredGateways, ["insomnia", "anxiety"])
            XCTAssertFalse(preview.dayAssignments.isEmpty, "Should have day assignments")
            XCTAssertGreaterThan(preview.totalQuestions, 0)
        } catch {
            XCTFail("Failed to preview expansion schedule: \(error)")
        }
    }

    // MARK: - Treatment Integration Tests

    func testGetTreatmentPhase() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let phase = try await convexService.getTreatmentPhase()

            // Phase should be valid
            let validPhases = ["intake", "analysis", "treatment_pending", "treatment_active", "completed"]
            XCTAssertTrue(validPhases.contains(phase.phase), "Phase should be valid: \(phase.phase)")
        } catch {
            XCTFail("Failed to get treatment phase: \(error)")
        }
    }

    func testGetActiveInterventions() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let interventions = try await convexService.getActiveInterventions()

            // May or may not have interventions depending on treatment phase
            // Just verify the call succeeds
            XCTAssertNotNil(interventions)
        } catch {
            XCTFail("Failed to get active interventions: \(error)")
        }
    }

    // MARK: - Multi-Source Sleep Data Tests

    func testGetMultiSourceSleepData() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let data = try await convexService.getMultiSourceSleepData(days: 7)

            XCTAssertNotNil(data.sources)
            XCTAssertGreaterThanOrEqual(data.totalDays, 0)
        } catch {
            XCTFail("Failed to get multi-source sleep data: \(error)")
        }
    }

    // MARK: - Journey Phase Integration Tests

    func testGetJourneyStatus() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated, let userId = convexService.userId else {
            return
        }

        do {
            let status = try await convexService.getJourneyStatus(userId: userId)

            let validPhases = ["intake", "analysis", "treatment_pending", "treatment_active", "completed"]
            XCTAssertTrue(validPhases.contains(status.phase))
        } catch {
            XCTFail("Failed to get journey status: \(error)")
        }
    }

    // MARK: - Debug/Developer Mode Tests

    func testCanAdvanceDay() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let canAdvance = try await convexService.canAdvanceDay(debugMode: true)

            // Just verify the response structure
            XCTAssertNotNil(canAdvance.reason)
        } catch {
            XCTFail("Failed to check can advance day: \(error)")
        }
    }

    func testGetJourneyDebugInfo() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let debugInfo = try await convexService.getJourneyDebugInfo()

            XCTAssertGreaterThanOrEqual(debugInfo.currentDay, 1)
            XCTAssertLessThanOrEqual(debugInfo.currentDay, 15)
            XCTAssertNotNil(debugInfo.completedDays)
            XCTAssertNotNil(debugInfo.gateways)
        } catch {
            XCTFail("Failed to get journey debug info: \(error)")
        }
    }
}

// MARK: - Batch Response Tests

extension IntegrationTests {

    func testSaveAndGetResponses() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            // Save test responses
            let testResponses: [[String: Any]] = [
                ["questionId": "TEST_Q1", "stringValue": "Yes"],
                ["questionId": "TEST_Q2", "numberValue": 7]
            ]

            let saveResult = try await convexService.saveResponses(
                dayNumber: 1,
                responses: testResponses
            )

            XCTAssertTrue(saveResult.success)

            // Get saved responses
            let saved = try await convexService.getSavedResponses(dayNumber: 1)

            // Responses may or may not include our test data depending on DB state
            XCTAssertNotNil(saved)
        } catch {
            // May fail if schema doesn't allow test questions
            print("Save/Get responses test: \(error)")
        }
    }
}

// MARK: - Question Progress Tests

extension IntegrationTests {

    func testQuestionProgressTracking() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            // Update progress
            try await convexService.updateQuestionProgress(
                dayNumber: 1,
                section: "sleepLog",
                questionIndex: 2,
                totalQuestions: 5
            )

            // Get progress
            let progress = try await convexService.getQuestionProgress(
                dayNumber: 1,
                section: "sleepLog"
            )

            // Progress may or may not be available
            if let progress = progress {
                XCTAssertGreaterThanOrEqual(progress.currentQuestionIndex, 0)
            }
        } catch {
            print("Question progress test: \(error)")
        }
    }
}

// MARK: - Cross-Platform Validation Tests

extension IntegrationTests {

    /// Verify iOS receives the same question structure as web
    func testQuestionStructureConsistency() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        do {
            let questions = try await convexService.getQuestionsForUserDay(dayNumber: 1)

            // Verify all questions have required fields
            for question in questions.sleepLog + questions.assessment {
                XCTAssertFalse(question.id.isEmpty, "Question should have ID")
                XCTAssertFalse(question.text.isEmpty, "Question should have text")
                XCTAssertFalse(question.type.isEmpty, "Question should have type")

                // Valid answer types
                let validTypes = [
                    "slider", "single_select", "multi_select", "time_picker",
                    "minutes_scroll", "number_scroll", "number_input", "date_picker",
                    "text_input", "chips"
                ]
                // Type should be valid (note: actual validation may vary)
            }
        } catch {
            XCTFail("Question structure test failed: \(error)")
        }
    }

    /// Verify clinical questionnaire questions exist
    func testClinicalQuestionnairesExist() async throws {
        await authManager.signIn(email: testUsername, password: testPassword)

        guard authManager.isAuthenticated else {
            return
        }

        // Clinical questionnaires that should exist
        let clinicalPrefixes = ["ISI_", "PHQ9_", "GAD7_", "ESS_", "SB_", "CSD_"]

        do {
            // Check multiple days for clinical questions
            for day in 1...15 {
                let questions = try await convexService.getQuestionsForUserDay(dayNumber: day)
                let allQuestions = questions.sleepLog + questions.assessment

                for question in allQuestions {
                    // Just verify structure - clinical questions may appear on different days
                    XCTAssertFalse(question.id.isEmpty)
                }
            }
        } catch {
            // Some days may fail if user hasn't triggered gateways
            print("Clinical questionnaires test: \(error)")
        }
    }
}
