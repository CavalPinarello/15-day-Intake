//
//  ThemeManagerTests.swift
//  ZoeSleepTests
//
//  Tests for ThemeManager and circadian theming system
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

    func testSharedInstance() {
        let instance1 = ThemeManager.shared
        let instance2 = ThemeManager.shared
        XCTAssertTrue(instance1 === instance2, "ThemeManager should be a singleton")
    }

    // MARK: - Appearance Mode Tests

    func testAppearanceMode_System() {
        sut.appearanceMode = .system
        XCTAssertEqual(sut.appearanceMode, .system)
    }

    func testAppearanceMode_Light() {
        sut.appearanceMode = .light
        XCTAssertEqual(sut.appearanceMode, .light)
    }

    func testAppearanceMode_Dark() {
        sut.appearanceMode = .dark
        XCTAssertEqual(sut.appearanceMode, .dark)
    }

    func testAppearanceMode_Circadian() {
        sut.appearanceMode = .circadian
        XCTAssertEqual(sut.appearanceMode, .circadian)
    }

    func testAppearanceModeAllCases() {
        let allModes = ThemeManager.AppearanceMode.allCases
        XCTAssertTrue(allModes.contains(.system))
        XCTAssertTrue(allModes.contains(.light))
        XCTAssertTrue(allModes.contains(.dark))
        XCTAssertTrue(allModes.contains(.circadian))
    }

    // MARK: - Accent Color Option Tests

    func testAccentColorOptions() {
        let allOptions = ThemeManager.AccentColorOption.allCases
        XCTAssertTrue(allOptions.contains(.teal))
        XCTAssertTrue(allOptions.contains(.coral))
        XCTAssertTrue(allOptions.contains(.violet))
        XCTAssertTrue(allOptions.contains(.gold))
        XCTAssertEqual(allOptions.count, 4)
    }

    func testAccentColorOptionSetting() {
        sut.accentColorOption = .coral
        XCTAssertEqual(sut.accentColorOption, .coral)

        sut.accentColorOption = .teal
        XCTAssertEqual(sut.accentColorOption, .teal)
    }

    func testAccentColorHasValidColor() {
        for option in ThemeManager.AccentColorOption.allCases {
            let color = option.color
            // Color should exist (no crash = pass)
            XCTAssertNotNil(color)
        }
    }

    func testAccentColorComputedProperty() {
        sut.accentColorOption = .gold
        let color = sut.accentColor
        XCTAssertNotNil(color)
        XCTAssertEqual(color, ThemeManager.AccentColorOption.gold.color)
    }

    // MARK: - Current Time Period Tests

    func testCurrentTimePeriodExists() {
        let period = sut.currentTimePeriod
        XCTAssertNotNil(period)
    }

    // MARK: - TimePeriod Tests

    func testTimePeriodCases() {
        // Verify all time periods exist
        XCTAssertNotNil(TimePeriod.morning)
        XCTAssertNotNil(TimePeriod.afternoon)
        XCTAssertNotNil(TimePeriod.evening)
        XCTAssertNotNil(TimePeriod.night)
    }

    func testTimePeriodCurrent() {
        // Current should return a valid period
        let current = TimePeriod.current
        let validPeriods: [TimePeriod] = [.morning, .afternoon, .evening, .night]
        XCTAssertTrue(validPeriods.contains(current))
    }

    // MARK: - ColorTheme Tests

    func testColorThemeShared() {
        let theme = ColorTheme.shared
        XCTAssertNotNil(theme)
        XCTAssertNotNil(theme.primary)
        XCTAssertNotNil(theme.secondary)
        XCTAssertNotNil(theme.tertiary)
    }

    func testColorThemeSuccess() {
        let theme = ColorTheme.shared
        XCTAssertNotNil(theme.success)
    }

    func testColorThemeWarning() {
        let theme = ColorTheme.shared
        XCTAssertNotNil(theme.warning)
    }

    func testColorThemeError() {
        let theme = ColorTheme.shared
        XCTAssertNotNil(theme.error)
    }

    func testColorThemeInfo() {
        let theme = ColorTheme.shared
        XCTAssertNotNil(theme.info)
    }

    func testColorThemeBackgroundTint() {
        let theme = ColorTheme.shared
        XCTAssertNotNil(theme.backgroundTint)
    }

    func testColorThemeCardBackground() {
        let theme = ColorTheme.shared
        XCTAssertNotNil(theme.cardBackground)
    }

    func testColorThemeInitWithPeriod() {
        let morningTheme = ColorTheme(period: .morning)
        XCTAssertNotNil(morningTheme.primary)

        let nightTheme = ColorTheme(period: .night)
        XCTAssertNotNil(nightTheme.primary)
    }

    func testColorThemeInitWithAccentColor() {
        let theme = ColorTheme(accentColor: .violet)
        XCTAssertNotNil(theme.primary)
    }

    // MARK: - WaveCircadianPalette Tests (Wave background specific)

    func testWaveCircadianPaletteForPeriods() {
        let periods: [TimePeriod] = [.morning, .afternoon, .evening, .night]

        for period in periods {
            let palette = WaveCircadianPalette.forPeriod(period)
            XCTAssertNotNil(palette.accent)
            XCTAssertNotNil(palette.wave)
            XCTAssertNotNil(palette.textPrimary)
            XCTAssertNotNil(palette.textSecondary)
            XCTAssertNotNil(palette.background)
        }
    }

    func testWaveCircadianPaletteIsDark() {
        // Night and evening should be dark
        let nightPalette = WaveCircadianPalette.forPeriod(.night)
        XCTAssertTrue(nightPalette.isDark)

        let eveningPalette = WaveCircadianPalette.forPeriod(.evening)
        XCTAssertTrue(eveningPalette.isDark)

        // Morning and afternoon should not be dark
        let morningPalette = WaveCircadianPalette.forPeriod(.morning)
        XCTAssertFalse(morningPalette.isDark)

        let afternoonPalette = WaveCircadianPalette.forPeriod(.afternoon)
        XCTAssertFalse(afternoonPalette.isDark)
    }

    // MARK: - CircadianPalette Tests (8-phase interpolated)

    func testCircadianPaletteCurrent() {
        let palette = CircadianPalette.current
        XCTAssertNotNil(palette.primary)
        XCTAssertNotNil(palette.secondary)
        XCTAssertNotNil(palette.textPrimary)
        XCTAssertNotNil(palette.textSecondary)
        XCTAssertNotNil(palette.cardBackground)
    }

    func testCircadianPalettePhases() {
        // Test that all 8 phases are valid
        for phase in CircadianPhase.allCases {
            XCTAssertNotNil(phase.displayName)
        }
    }

    // MARK: - Typography Tests

    func testTypographyConstants() {
        XCTAssertEqual(Typography.caption2, 12)
        XCTAssertEqual(Typography.caption, 14)
        XCTAssertEqual(Typography.body, 18)
        XCTAssertEqual(Typography.headline, 20)
        XCTAssertEqual(Typography.title, 34)
        XCTAssertEqual(Typography.largeTitle, 40)
    }

    // MARK: - Spacing Tests

    func testSpacingConstants() {
        XCTAssertEqual(Spacing.xxs, 4)
        XCTAssertEqual(Spacing.xs, 8)
        XCTAssertEqual(Spacing.sm, 12)
        XCTAssertEqual(Spacing.md, 20)
        XCTAssertEqual(Spacing.lg, 28)
        XCTAssertEqual(Spacing.xl, 40)
    }

    // MARK: - Corner Radius Tests

    func testCornerRadiusConstants() {
        XCTAssertEqual(CornerRadius.small, 12)
        XCTAssertEqual(CornerRadius.medium, 20)
        XCTAssertEqual(CornerRadius.large, 28)
    }

    // MARK: - Accessibility Settings Tests

    func testLargeIconsMode() {
        sut.largeIconsMode = true
        XCTAssertTrue(sut.largeIconsMode)
        XCTAssertEqual(sut.buttonScale, 1.3)
        XCTAssertEqual(sut.minimumTapTarget, 58)

        sut.largeIconsMode = false
        XCTAssertFalse(sut.largeIconsMode)
        XCTAssertEqual(sut.buttonScale, 1.0)
        XCTAssertEqual(sut.minimumTapTarget, 44)
    }

    func testHighContrast() {
        sut.highContrast = true
        XCTAssertTrue(sut.highContrast)
        XCTAssertEqual(sut.borderWidth, 2)
        XCTAssertEqual(sut.shadowRadius, 0)

        sut.highContrast = false
        XCTAssertFalse(sut.highContrast)
        XCTAssertEqual(sut.borderWidth, 1)
        XCTAssertEqual(sut.shadowRadius, 4)
    }

    func testReduceMotion() {
        sut.reduceMotion = true
        XCTAssertTrue(sut.reduceMotion)
        XCTAssertEqual(sut.animationDuration, 0)

        sut.reduceMotion = false
        XCTAssertFalse(sut.reduceMotion)
        XCTAssertEqual(sut.animationDuration, 0.3)
    }

    func testTextSizeMultiplier() {
        sut.textSizeMultiplier = 1.5
        XCTAssertEqual(sut.textSizeMultiplier, 1.5)

        let scaledSize = sut.scaledFontSize(16)
        XCTAssertEqual(scaledSize, 24)

        sut.textSizeMultiplier = 1.0
    }

    // MARK: - Debug Mode Tests

    func testDebugMode() {
        sut.debugMode = true
        XCTAssertTrue(sut.debugMode)

        sut.debugMode = false
        XCTAssertFalse(sut.debugMode)
    }

    func testUnlockTimeOverride() {
        sut.unlockTimeOverride = true
        XCTAssertTrue(sut.unlockTimeOverride)

        sut.unlockTimeOverride = false
        XCTAssertFalse(sut.unlockTimeOverride)
    }

    // MARK: - Current Theme Tests

    func testCurrentThemeInCircadianMode() {
        sut.appearanceMode = .circadian
        let theme = sut.currentTheme
        XCTAssertNotNil(theme)
        XCTAssertNotNil(theme.primary)
    }

    func testCurrentThemeWithAccentColor() {
        sut.appearanceMode = .system
        sut.accentColorOption = .coral
        let theme = sut.currentTheme
        XCTAssertNotNil(theme)
    }

    // MARK: - FriendlyCopy Tests

    func testFriendlyCopyGreeting() {
        let morningGreeting = FriendlyCopy.greeting(for: 8, name: "John")
        XCTAssertTrue(morningGreeting.contains("Good morning"))
        XCTAssertTrue(morningGreeting.contains("John"))

        let afternoonGreeting = FriendlyCopy.greeting(for: 14, name: nil)
        XCTAssertTrue(afternoonGreeting.contains("Good afternoon"))

        let eveningGreeting = FriendlyCopy.greeting(for: 19, name: nil)
        XCTAssertTrue(eveningGreeting.contains("Good evening"))

        let nightGreeting = FriendlyCopy.greeting(for: 23, name: nil)
        XCTAssertTrue(nightGreeting.contains("Hello"))
    }

    func testFriendlyCopyConstants() {
        XCTAssertEqual(FriendlyCopy.continueButton, "Let's go")
        XCTAssertEqual(FriendlyCopy.nextButton, "Next")
        XCTAssertEqual(FriendlyCopy.doneButton, "Done!")
    }
}
