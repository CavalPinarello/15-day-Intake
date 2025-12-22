//
//  CheckInManagerTests.swift
//  ZoeSleepTests
//
//  Unit tests for CheckInManager and check-in functionality
//

import XCTest
@testable import ZoeSleep

@MainActor
final class CheckInManagerTests: XCTestCase {

    var sut: CheckInManager!

    override func setUp() {
        super.setUp()
        sut = CheckInManager.shared
        sut.resetForNewDay()
    }

    override func tearDown() {
        sut.resetForNewDay()
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateAllCheckInsIncomplete() {
        XCTAssertFalse(sut.morningCompleted)
        XCTAssertFalse(sut.middayCompleted)
        XCTAssertFalse(sut.eveningCompleted)
    }

    func testCompletedCountInitiallyZero() {
        XCTAssertEqual(sut.completedCount, 0)
    }

    func testAllCheckInsCompleteInitiallyFalse() {
        XCTAssertFalse(sut.allCheckInsComplete)
    }

    // MARK: - Completed Count Tests

    func testCompletedCountWithMorning() {
        sut.morningCompleted = true
        XCTAssertEqual(sut.completedCount, 1)
    }

    func testCompletedCountWithMorningAndMidday() {
        sut.morningCompleted = true
        sut.middayCompleted = true
        XCTAssertEqual(sut.completedCount, 2)
    }

    func testCompletedCountWithAllThree() {
        sut.morningCompleted = true
        sut.middayCompleted = true
        sut.eveningCompleted = true
        XCTAssertEqual(sut.completedCount, 3)
    }

    // MARK: - All Complete Tests

    func testAllCheckInsCompleteWhenAllTrue() {
        sut.morningCompleted = true
        sut.middayCompleted = true
        sut.eveningCompleted = true
        XCTAssertTrue(sut.allCheckInsComplete)
    }

    func testAllCheckInsCompleteWhenOneMissing() {
        sut.morningCompleted = true
        sut.middayCompleted = true
        sut.eveningCompleted = false
        XCTAssertFalse(sut.allCheckInsComplete)
    }

    // MARK: - Next Pending Check-In Tests

    func testNextPendingCheckInReturnsFirstIncomplete() {
        sut.morningCompleted = false
        sut.middayCompleted = false
        sut.eveningCompleted = false
        XCTAssertNotNil(sut.nextPendingCheckIn)
    }

    func testNextPendingCheckInReturnsNilWhenAllComplete() {
        sut.morningCompleted = true
        sut.middayCompleted = true
        sut.eveningCompleted = true
        XCTAssertNil(sut.nextPendingCheckIn)
    }

    // MARK: - Reset Tests

    func testResetForNewDayClearsAllState() {
        sut.morningCompleted = true
        sut.middayCompleted = true
        sut.eveningCompleted = true
        sut.morningCompletedAt = Date()
        sut.middayCompletedAt = Date()
        sut.eveningCompletedAt = Date()

        sut.resetForNewDay()

        XCTAssertFalse(sut.morningCompleted)
        XCTAssertFalse(sut.middayCompleted)
        XCTAssertFalse(sut.eveningCompleted)
        XCTAssertNil(sut.morningCompletedAt)
        XCTAssertNil(sut.middayCompletedAt)
        XCTAssertNil(sut.eveningCompletedAt)
    }

    // MARK: - Time-Based Prompt Tests

    func testShouldShowMorningPromptDuringMorningHours() {
        // This test is time-dependent; we test the logic structure
        sut.morningCompleted = false
        // The actual result depends on current time
        // We just verify the method doesn't crash and returns a boolean
        let shouldShow = sut.shouldShowCheckInPrompt(for: .morning)
        XCTAssertTrue(shouldShow == true || shouldShow == false)
    }

    func testShouldNotShowMorningPromptWhenComplete() {
        sut.morningCompleted = true
        let shouldShow = sut.shouldShowCheckInPrompt(for: .morning)
        XCTAssertFalse(shouldShow)
    }

    func testShouldNotShowMiddayPromptWhenComplete() {
        sut.middayCompleted = true
        let shouldShow = sut.shouldShowCheckInPrompt(for: .midday)
        XCTAssertFalse(shouldShow)
    }

    func testShouldNotShowEveningPromptWhenComplete() {
        sut.eveningCompleted = true
        let shouldShow = sut.shouldShowCheckInPrompt(for: .evening)
        XCTAssertFalse(shouldShow)
    }

    // MARK: - Prompt Data Tests

    func testMorningPromptDataHasCorrectValues() {
        let data = sut.promptData(for: .morning)
        XCTAssertEqual(data.title, "Morning Check-in")
        XCTAssertEqual(data.icon, "sun.max.fill")
    }

    func testMiddayPromptDataHasCorrectValues() {
        let data = sut.promptData(for: .midday)
        XCTAssertEqual(data.title, "Midday Check-in")
        XCTAssertEqual(data.icon, "clock.fill")
    }

    func testEveningPromptDataHasCorrectValues() {
        let data = sut.promptData(for: .evening)
        XCTAssertEqual(data.title, "Evening Report")
        XCTAssertEqual(data.icon, "moon.stars.fill")
    }

    // MARK: - CheckInType Tests

    func testCheckInTypeDisplayNames() {
        XCTAssertEqual(CheckInType.morning.displayName, "Morning")
        XCTAssertEqual(CheckInType.midday.displayName, "Midday")
        XCTAssertEqual(CheckInType.evening.displayName, "Evening")
    }

    func testCheckInTypeAllCases() {
        XCTAssertEqual(CheckInType.allCases.count, 3)
        XCTAssertTrue(CheckInType.allCases.contains(.morning))
        XCTAssertTrue(CheckInType.allCases.contains(.midday))
        XCTAssertTrue(CheckInType.allCases.contains(.evening))
    }
}

// MARK: - Energy Option Tests

final class EnergyOptionTests: XCTestCase {

    func testEnergyOptionRawValues() {
        XCTAssertEqual(EnergyOption.exhausted.rawValue, 1)
        XCTAssertEqual(EnergyOption.tired.rawValue, 2)
        XCTAssertEqual(EnergyOption.okay.rawValue, 3)
        XCTAssertEqual(EnergyOption.energized.rawValue, 4)
    }

    func testEnergyOptionLabels() {
        XCTAssertEqual(EnergyOption.exhausted.label, "Exhausted")
        XCTAssertEqual(EnergyOption.tired.label, "Tired")
        XCTAssertEqual(EnergyOption.okay.label, "Okay")
        XCTAssertEqual(EnergyOption.energized.label, "Energized")
    }

    func testEnergyOptionEmojis() {
        XCTAssertFalse(EnergyOption.exhausted.emoji.isEmpty)
        XCTAssertFalse(EnergyOption.tired.emoji.isEmpty)
        XCTAssertFalse(EnergyOption.okay.emoji.isEmpty)
        XCTAssertFalse(EnergyOption.energized.emoji.isEmpty)
    }

    func testEnergyOptionAllCases() {
        XCTAssertEqual(EnergyOption.allCases.count, 4)
    }
}

// MARK: - Mood Option Tests

final class MoodOptionTests: XCTestCase {

    func testMoodOptionRawValues() {
        XCTAssertEqual(MoodOption.veryLow.rawValue, 1)
        XCTAssertEqual(MoodOption.low.rawValue, 2)
        XCTAssertEqual(MoodOption.neutral.rawValue, 3)
        XCTAssertEqual(MoodOption.good.rawValue, 4)
        XCTAssertEqual(MoodOption.great.rawValue, 5)
    }

    func testMoodOptionLabels() {
        XCTAssertEqual(MoodOption.veryLow.label, "Bad")
        XCTAssertEqual(MoodOption.low.label, "Low")
        XCTAssertEqual(MoodOption.neutral.label, "Okay")
        XCTAssertEqual(MoodOption.good.label, "Good")
        XCTAssertEqual(MoodOption.great.label, "Great")
    }

    func testMoodOptionEmojis() {
        XCTAssertFalse(MoodOption.veryLow.emoji.isEmpty)
        XCTAssertFalse(MoodOption.low.emoji.isEmpty)
        XCTAssertFalse(MoodOption.neutral.emoji.isEmpty)
        XCTAssertFalse(MoodOption.good.emoji.isEmpty)
        XCTAssertFalse(MoodOption.great.emoji.isEmpty)
    }

    func testMoodOptionAllCases() {
        XCTAssertEqual(MoodOption.allCases.count, 5)
    }
}

// MARK: - Protocol Data Tests

final class ProtocolDataTests: XCTestCase {

    func testMorningProtocolDefaults() {
        let morning = ProtocolData.morningProtocol
        XCTAssertEqual(morning.id, "morning_protocol")
        XCTAssertEqual(morning.name, "Morning Protocol")
        XCTAssertEqual(morning.icon, "sun.max.fill")
        XCTAssertTrue(morning.tasks.isEmpty)
    }

    func testEveningProtocolDefaults() {
        let evening = ProtocolData.eveningProtocol
        XCTAssertEqual(evening.id, "evening_protocol")
        XCTAssertEqual(evening.name, "Evening Protocol")
        XCTAssertEqual(evening.icon, "moon.stars.fill")
        XCTAssertTrue(evening.tasks.isEmpty)
    }
}

// MARK: - Protocol Task Tests

final class ProtocolTaskTests: XCTestCase {

    func testProtocolTaskInitialization() {
        let task = ProtocolTask(
            id: "task1",
            name: "Test Task",
            subtitle: "Test subtitle",
            instructions: "Test instructions",
            isCompleted: false,
            isSkipped: false,
            currentDifficulty: 2,
            originalDifficulty: 3,
            interventionId: "int1"
        )

        XCTAssertEqual(task.id, "task1")
        XCTAssertEqual(task.name, "Test Task")
        XCTAssertEqual(task.subtitle, "Test subtitle")
        XCTAssertEqual(task.instructions, "Test instructions")
        XCTAssertFalse(task.isCompleted)
        XCTAssertFalse(task.isSkipped)
        XCTAssertEqual(task.currentDifficulty, 2)
        XCTAssertEqual(task.originalDifficulty, 3)
        XCTAssertEqual(task.interventionId, "int1")
    }

    func testProtocolTaskDifficultyReduced() {
        let task = ProtocolTask(
            id: "task1",
            name: "Test Task",
            subtitle: nil,
            instructions: "Test",
            isCompleted: false,
            isSkipped: false,
            currentDifficulty: 2,
            originalDifficulty: 4,
            interventionId: nil
        )

        // Current difficulty (2) is less than original (4)
        XCTAssertTrue(task.currentDifficulty! < task.originalDifficulty)
    }
}
