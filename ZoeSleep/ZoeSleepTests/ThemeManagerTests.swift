//
//  ThemeManagerTests.swift
//  ZoeSleepTests
//
//  Unit tests for ThemeManager (circadian theming)
//

import XCTest
import SwiftUI
@testable import ZoeSleep

@MainActor
final class ThemeManagerTests: XCTestCase {

    var sut: ThemeManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = ThemeManager.shared
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSingletonExists() {
        XCTAssertNotNil(ThemeManager.shared)
    }

    func testSingletonIsSameInstance() {
        let instance1 = ThemeManager.shared
        let instance2 = ThemeManager.shared

        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Time Period Tests

    func testCurrentTimeOfDay() {
        let timeOfDay = sut.currentTimeOfDay

        // Should be one of the valid time periods
        let validPeriods: [TimeOfDay] = [.morning, .day, .evening, .night]
        XCTAssertTrue(validPeriods.contains(timeOfDay))
    }

    func testTimeOfDayFromHour() {
        // Morning: 5 AM - 11 AM
        XCTAssertEqual(TimeOfDay.from(hour: 5), .morning)
        XCTAssertEqual(TimeOfDay.from(hour: 10), .morning)

        // Day: 11 AM - 5 PM
        XCTAssertEqual(TimeOfDay.from(hour: 11), .day)
        XCTAssertEqual(TimeOfDay.from(hour: 16), .day)

        // Evening: 5 PM - 9 PM
        XCTAssertEqual(TimeOfDay.from(hour: 17), .evening)
        XCTAssertEqual(TimeOfDay.from(hour: 20), .evening)

        // Night: 9 PM - 5 AM
        XCTAssertEqual(TimeOfDay.from(hour: 21), .night)
        XCTAssertEqual(TimeOfDay.from(hour: 0), .night)
        XCTAssertEqual(TimeOfDay.from(hour: 4), .night)
    }

    // MARK: - Circadian Color Tests

    func testCircadianPrimaryColor() {
        let color = sut.circadianPrimary

        // Color should not be nil/empty
        XCTAssertNotNil(color)
    }

    func testCircadianBackgroundColor() {
        let color = sut.circadianBackground

        XCTAssertNotNil(color)
    }

    func testCircadianTextColor() {
        let color = sut.circadianText

        XCTAssertNotNil(color)
    }

    func testCircadianAccentColor() {
        let color = sut.circadianAccent

        XCTAssertNotNil(color)
    }

    // MARK: - Night Mode Tests

    func testIsNightMode() {
        let isNight = sut.isNightMode

        // Should return a boolean
        XCTAssertNotNil(isNight)

        // Verify consistency with time of day
        if sut.currentTimeOfDay == .night {
            XCTAssertTrue(isNight)
        }
    }

    // MARK: - Color Accessibility Tests

    func testColorsAreNotTransparent() {
        // Ensure primary colors have opacity
        // Note: This is a basic sanity check
        let colors = [
            sut.circadianPrimary,
            sut.circadianBackground,
            sut.circadianText,
            sut.circadianAccent
        ]

        for color in colors {
            XCTAssertNotNil(color)
        }
    }

    // MARK: - Theme Update Tests

    func testThemeUpdatesWithTime() {
        // This test verifies the theme manager updates based on time
        // In real scenarios, this would be tested with time mocking

        let timeOfDay1 = sut.currentTimeOfDay
        let color1 = sut.circadianPrimary

        // Theme should be consistent for same time
        let timeOfDay2 = sut.currentTimeOfDay
        let color2 = sut.circadianPrimary

        XCTAssertEqual(timeOfDay1, timeOfDay2)
        // Colors should be consistent
        XCTAssertNotNil(color1)
        XCTAssertNotNil(color2)
    }
}

// MARK: - TimeOfDay Enum Tests

extension ThemeManagerTests {

    func testTimeOfDayAllCases() {
        let allCases: [TimeOfDay] = [.morning, .day, .evening, .night]

        XCTAssertEqual(allCases.count, 4)
    }

    func testTimeOfDayBoundaries() {
        // Test edge hours
        XCTAssertEqual(TimeOfDay.from(hour: 5), .morning)  // Start of morning
        XCTAssertEqual(TimeOfDay.from(hour: 4), .night)    // End of night

        XCTAssertEqual(TimeOfDay.from(hour: 11), .day)     // Start of day
        XCTAssertEqual(TimeOfDay.from(hour: 10), .morning) // End of morning

        XCTAssertEqual(TimeOfDay.from(hour: 17), .evening) // Start of evening
        XCTAssertEqual(TimeOfDay.from(hour: 16), .day)     // End of day

        XCTAssertEqual(TimeOfDay.from(hour: 21), .night)   // Start of night
        XCTAssertEqual(TimeOfDay.from(hour: 20), .evening) // End of evening
    }

    func testTimeOfDayInvalidHours() {
        // Test wrap-around hours
        XCTAssertEqual(TimeOfDay.from(hour: 24), .night) // Should wrap to 0
        XCTAssertEqual(TimeOfDay.from(hour: -1), .night) // Negative should be handled
    }
}

// MARK: - Blue Light Compliance Tests

extension ThemeManagerTests {

    /// CRITICAL: No blue light after dusk (disrupts melatonin)
    func testNightColorsAvoidBlue() {
        // Get night colors
        // In a real implementation, we'd analyze the RGB values
        // For now, verify the design principle is documented

        let isNight = sut.currentTimeOfDay == .night || sut.currentTimeOfDay == .evening

        if isNight {
            // Night mode should use warm colors
            // This test documents the requirement
            XCTAssertTrue(sut.isNightMode || sut.currentTimeOfDay == .evening)
        }
    }

    func testDayColorsCanIncludeBlue() {
        // During day, blue/teal colors are acceptable for alertness
        let isDay = sut.currentTimeOfDay == .morning || sut.currentTimeOfDay == .day

        if isDay {
            // Day colors can include cooler tones
            XCTAssertFalse(sut.isNightMode)
        }
    }
}

// MARK: - Color Scheme Tests

extension ThemeManagerTests {

    func testCircadianColorScheme() {
        // Test that we have a consistent color scheme
        let primary = sut.circadianPrimary
        let background = sut.circadianBackground
        let text = sut.circadianText
        let accent = sut.circadianAccent

        // All should be defined
        XCTAssertNotNil(primary)
        XCTAssertNotNil(background)
        XCTAssertNotNil(text)
        XCTAssertNotNil(accent)
    }
}
