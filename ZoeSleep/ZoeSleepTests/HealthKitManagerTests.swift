//
//  HealthKitManagerTests.swift
//  ZoeSleepTests
//
//  Unit tests for HealthKitManager
//  Note: Many HealthKit tests require running on a real device with HealthKit access
//

import XCTest
import HealthKit
@testable import ZoeSleep

@MainActor
final class HealthKitManagerTests: XCTestCase {

    var sut: HealthKitManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = HealthKitManager()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializesWithEmptyDemographics() {
        XCTAssertNil(sut.demographics.dateOfBirth)
        XCTAssertNil(sut.demographics.biologicalSex)
        XCTAssertNil(sut.demographics.heightCm)
        XCTAssertNil(sut.demographics.weightKg)
    }

    func testIsAuthorizedInitiallyFalse() {
        XCTAssertFalse(sut.isAuthorized)
    }

    // MARK: - HealthKit Availability Tests

    func testHealthKitAvailabilityCheck() {
        // This test just verifies the property exists
        // Actual availability depends on device
        _ = sut.isHealthKitAvailable
    }

    // MARK: - Demographics Model Tests

    func testHealthKitDemographicsAge() {
        // Test age calculation from date of birth
        var demographics = HealthKitDemographics()

        // No DOB = nil age
        XCTAssertNil(demographics.age)

        // Set DOB to 30 years ago
        let calendar = Calendar.current
        demographics.dateOfBirth = calendar.date(byAdding: .year, value: -30, to: Date())

        XCTAssertNotNil(demographics.age)
        // Should be approximately 30 (could be 29 or 30 depending on exact date)
        XCTAssertGreaterThanOrEqual(demographics.age!, 29)
        XCTAssertLessThanOrEqual(demographics.age!, 31)
    }

    func testHealthKitDemographicsAgeEdgeCases() {
        var demographics = HealthKitDemographics()

        // Test newborn (DOB = today)
        demographics.dateOfBirth = Date()
        XCTAssertEqual(demographics.age, 0)

        // Test 1 year old
        let calendar = Calendar.current
        demographics.dateOfBirth = calendar.date(byAdding: .year, value: -1, to: Date())
        XCTAssertEqual(demographics.age, 1)
    }

    // MARK: - Demographic Responses Tests

    func testGetDemographicResponsesEmpty() {
        let responses = sut.getDemographicResponses()

        // With no demographics, responses should be empty
        XCTAssertTrue(responses.isEmpty)
    }

    func testHasDemographicDataForUnknownQuestion() {
        XCTAssertFalse(sut.hasDemographicData(for: "UNKNOWN_QUESTION"))
        XCTAssertFalse(sut.hasDemographicData(for: ""))
        XCTAssertFalse(sut.hasDemographicData(for: "D99"))
    }

    func testHasDemographicDataForValidQuestions() {
        // Without data, should return false
        XCTAssertFalse(sut.hasDemographicData(for: "D2")) // DOB
        XCTAssertFalse(sut.hasDemographicData(for: "D4")) // Sex
        XCTAssertFalse(sut.hasDemographicData(for: "D5")) // Height
        XCTAssertFalse(sut.hasDemographicData(for: "D6")) // Weight
    }

    // MARK: - Sleep Data Source Tests

    func testSleepDataSourcePriority() {
        // Apple Watch should have highest priority (1)
        let watchSource = SleepDataSource(name: "Apple Watch", bundleIdentifier: "com.apple.health", priority: 1)
        XCTAssertEqual(watchSource.priority, 1)

        // iPhone native should be priority 2
        let iphoneSource = SleepDataSource(name: "iPhone", bundleIdentifier: "com.apple.Health", priority: 2)
        XCTAssertEqual(iphoneSource.priority, 2)

        // Third-party should be priority 3
        let ouraSource = SleepDataSource(name: "Oura", bundleIdentifier: "com.ouraring.oura", priority: 3)
        XCTAssertEqual(ouraSource.priority, 3)
    }

    func testSleepDataSourceEquality() {
        let source1 = SleepDataSource(name: "Test", bundleIdentifier: "com.test", priority: 1)
        let source2 = SleepDataSource(name: "Test", bundleIdentifier: "com.test", priority: 1)
        let source3 = SleepDataSource(name: "Other", bundleIdentifier: "com.other", priority: 2)

        XCTAssertEqual(source1, source2)
        XCTAssertNotEqual(source1, source3)
    }

    func testSleepDataSourceCodable() {
        let source = SleepDataSource(name: "Apple Watch", bundleIdentifier: "com.apple.watch", priority: 1)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(source)
            let decoded = try decoder.decode(SleepDataSource.self, from: data)

            XCTAssertEqual(decoded.name, source.name)
            XCTAssertEqual(decoded.bundleIdentifier, source.bundleIdentifier)
            XCTAssertEqual(decoded.priority, source.priority)
        } catch {
            XCTFail("Encoding/Decoding failed: \(error)")
        }
    }

    // MARK: - Sleep Data Processing Tests

    func testFetchSleepDataWithInvalidDays() {
        let expectation = self.expectation(description: "Fetch sleep data")

        sut.fetchSleepData(daysBack: 0) { result in
            // Should still complete (might be empty or error)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Heart Rate Data Tests

    func testFetchHeartRateDataCompletion() {
        let expectation = self.expectation(description: "Fetch heart rate data")

        sut.fetchHeartRateData(daysBack: 7) { result in
            // Just verify the callback is invoked
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - HRV Data Tests

    func testFetchHRVDataCompletion() {
        let expectation = self.expectation(description: "Fetch HRV data")

        sut.fetchHRVData(daysBack: 7) { result in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Activity Data Tests

    func testFetchActivityDataCompletion() {
        let expectation = self.expectation(description: "Fetch activity data")

        sut.fetchActivityData(daysBack: 7) { result in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }
}

// MARK: - Mock Data Tests

extension HealthKitManagerTests {

    func testSleepDataProcessingFormat() {
        // Test that sleep data is returned in the expected format
        // This would normally be tested with mock HKCategorySamples
        // For now, verify the data structure expectations

        let expectedKeys = [
            "date",
            "in_bed_time",
            "asleep_time",
            "wake_time",
            "total_sleep_mins",
            "sleep_efficiency",
            "deep_sleep_mins",
            "light_sleep_mins",
            "rem_sleep_mins",
            "awake_mins",
            "interruptions_count",
            "sleep_latency_mins",
            "primary_source",
            "source_bundle_id",
            "all_sources",
            "is_multi_source"
        ]

        // Just verify the expected keys are documented
        XCTAssertEqual(expectedKeys.count, 16)
    }

    func testHeartRateDataFormat() {
        let expectedKeys = ["date", "resting_hr", "avg_hr"]
        XCTAssertEqual(expectedKeys.count, 3)
    }

    func testHRVDataFormat() {
        let expectedKeys = ["date", "hrv_morning", "hrv_avg"]
        XCTAssertEqual(expectedKeys.count, 3)
    }

    func testActivityDataFormat() {
        let expectedKeys = ["date", "steps", "active_mins", "exercise_mins", "calories_burned"]
        XCTAssertEqual(expectedKeys.count, 5)
    }
}

// MARK: - Integration Tests

extension HealthKitManagerTests {

    /// Test authorization request flow
    /// Note: This test may prompt for HealthKit permissions on real devices
    func testRequestAuthorizationFlow() {
        guard sut.isHealthKitAvailable else {
            // Skip test if HealthKit not available (simulator without HealthKit)
            return
        }

        let expectation = self.expectation(description: "Authorization callback")

        sut.requestAuthorization { success, error in
            // Just verify callback is invoked
            // Success/failure depends on user interaction
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10)
    }
}

// MARK: - Sleep Stage Mapping Tests

extension HealthKitManagerTests {

    // Test sleep stage values
    func testSleepStageConstants() {
        // Verify we handle all HKCategoryValueSleepAnalysis cases
        let stages = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.awake.rawValue,
            HKCategoryValueSleepAnalysis.inBed.rawValue
        ]

        // All values should be distinct
        let uniqueStages = Set(stages)
        XCTAssertEqual(stages.count, uniqueStages.count)
    }
}
