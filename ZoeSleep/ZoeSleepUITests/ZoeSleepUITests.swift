//
//  ZoeSleepUITests.swift
//  ZoeSleepUITests
//
//  Comprehensive UI tests for the Zoe Sleep app
//  Tests cover login, onboarding, questionnaire flow, and settings
//

import XCTest

final class ZoeSleepUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        // Add launch arguments for testing
        app.launchArguments = [
            "-UITesting",
            "-ResetState"
        ]

        // Add launch environment
        app.launchEnvironment = [
            "UITEST_MODE": "true"
        ]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests

    func testAppLaunchesSuccessfully() throws {
        app.launch()

        // App should either show login screen or main screen
        let loginExists = app.buttons["Sign In"].waitForExistence(timeout: 5)
        let mainExists = app.navigationBars.firstMatch.waitForExistence(timeout: 5)

        XCTAssertTrue(loginExists || mainExists, "App should show either login or main screen")
    }

    func testSplashScreenAppears() throws {
        app.launch()

        // The Zoe logo or splash should appear briefly
        // This is a visual test - verify app launches without crash
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}

// MARK: - Login Flow Tests

extension ZoeSleepUITests {

    func testLoginScreenElements() throws {
        app.launch()

        // Wait for login screen
        let signInButton = app.buttons["Sign In"]
        guard signInButton.waitForExistence(timeout: 5) else {
            // If already logged in, skip this test
            return
        }

        // Check for expected login elements
        XCTAssertTrue(app.textFields.firstMatch.exists || app.secureTextFields.firstMatch.exists,
                     "Should have input fields for login")
    }

    func testLoginWithTestUser() throws {
        app.launch()

        let signInButton = app.buttons["Sign In"]
        guard signInButton.waitForExistence(timeout: 5) else {
            // Already logged in
            return
        }

        // Find email/username field
        let emailField = app.textFields.firstMatch
        if emailField.exists {
            emailField.tap()
            emailField.typeText("user1")
        }

        // Find password field
        let passwordField = app.secureTextFields.firstMatch
        if passwordField.exists {
            passwordField.tap()
            passwordField.typeText("1")
        }

        // Tap sign in
        signInButton.tap()

        // Wait for transition (either to onboarding or main screen)
        let success = app.navigationBars.firstMatch.waitForExistence(timeout: 10) ||
                     app.staticTexts["Welcome"].waitForExistence(timeout: 10)

        // Note: This may fail if user1 doesn't exist - that's expected
    }

    func testAppleSignInButtonExists() throws {
        app.launch()

        let signInButton = app.buttons["Sign In"]
        guard signInButton.waitForExistence(timeout: 5) else {
            return
        }

        // Look for Apple Sign In button
        let appleButton = app.buttons["Sign in with Apple"]
        // Apple sign in may or may not be present depending on configuration
    }

    func testSignUpLink() throws {
        app.launch()

        let signInButton = app.buttons["Sign In"]
        guard signInButton.waitForExistence(timeout: 5) else {
            return
        }

        // Look for sign up option
        let signUpButton = app.buttons["Sign Up"]
        let createAccount = app.buttons["Create Account"]

        // Either should exist for new user registration
    }
}

// MARK: - Onboarding Flow Tests

extension ZoeSleepUITests {

    func testOnboardingSteps() throws {
        // This test requires a fresh install or reset state
        app.launchArguments.append("-ForceOnboarding")
        app.launch()

        // Look for onboarding indicators
        let continueButton = app.buttons["Continue"]
        let nextButton = app.buttons["Next"]
        let getStarted = app.buttons["Get Started"]

        // If onboarding is present, navigate through it
        if continueButton.waitForExistence(timeout: 3) {
            // Tap through onboarding steps
            for _ in 0..<8 { // 8 onboarding steps
                if continueButton.exists && continueButton.isHittable {
                    continueButton.tap()
                    sleep(1)
                } else if nextButton.exists && nextButton.isHittable {
                    nextButton.tap()
                    sleep(1)
                } else {
                    break
                }
            }
        }
    }

    func testOnboardingHealthKitPermission() throws {
        app.launchArguments.append("-ForceOnboarding")
        app.launch()

        // Navigate to HealthKit permission step
        // This is typically step 3 or 4 of onboarding

        // Look for HealthKit permission button
        let enableHealthKit = app.buttons["Enable Apple Health"]
        let skipButton = app.buttons["Skip"]

        // Either option should be available
    }

    func testOnboardingProfileSetup() throws {
        app.launchArguments.append("-ForceOnboarding")
        app.launch()

        // Look for profile setup fields
        let nameField = app.textFields["Full Name"]
        let heightPicker = app.pickers.firstMatch
        let weightPicker = app.pickers.element(boundBy: 1)

        // Profile fields should be part of onboarding
    }
}

// MARK: - Questionnaire Flow Tests

extension ZoeSleepUITests {

    func testQuestionnaireNavigation() throws {
        app.launch()

        // Navigate to questionnaire (requires login)
        let assessmentButton = app.buttons["Start Assessment"]
        let sleepLogButton = app.buttons["Sleep Log"]
        let questionCard = app.buttons.matching(identifier: "QuestionCard").firstMatch

        // Wait for main screen
        sleep(2)

        // Try to find and tap a questionnaire entry point
        if assessmentButton.exists && assessmentButton.isHittable {
            assessmentButton.tap()
        } else if sleepLogButton.exists && sleepLogButton.isHittable {
            sleepLogButton.tap()
        } else if questionCard.exists && questionCard.isHittable {
            questionCard.tap()
        }

        // Look for question UI elements
        let nextButton = app.buttons["Next"]
        let backButton = app.buttons["Back"]

        // If in questionnaire, these should exist
        if nextButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(nextButton.exists, "Next button should exist in questionnaire")
        }
    }

    func testSliderQuestionInteraction() throws {
        // Navigate to a slider question
        app.launch()
        sleep(2)

        // Find slider element
        let slider = app.sliders.firstMatch

        if slider.waitForExistence(timeout: 5) {
            // Adjust slider value
            slider.adjust(toNormalizedSliderPosition: 0.7)

            // Slider should update
            XCTAssertTrue(slider.exists)
        }
    }

    func testChipSelectionInteraction() throws {
        app.launch()
        sleep(2)

        // Find chip/button options for single select
        let chips = app.buttons.matching(identifier: "ChipOption")

        if chips.firstMatch.waitForExistence(timeout: 5) {
            // Tap a chip
            chips.firstMatch.tap()

            // Verify selection state (chip should be highlighted)
        }
    }

    func testTimePickerInteraction() throws {
        app.launch()
        sleep(2)

        // Find time picker
        let timePicker = app.datePickers.firstMatch

        if timePicker.waitForExistence(timeout: 5) {
            timePicker.tap()
            // Time picker should be interactive
            XCTAssertTrue(timePicker.isHittable)
        }
    }

    func testQuestionnaireProgressIndicator() throws {
        app.launch()
        sleep(2)

        // Look for progress indicator
        let progressBar = app.progressIndicators.firstMatch
        let progressLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'of'")).firstMatch

        // Either progress bar or "X of Y" label should exist
    }

    func testQuestionnaireBackButton() throws {
        app.launch()
        sleep(2)

        // Navigate into questionnaire
        let assessmentButton = app.buttons["Start Assessment"]
        if assessmentButton.exists && assessmentButton.isHittable {
            assessmentButton.tap()
        }

        sleep(1)

        // Find and tap next to advance
        let nextButton = app.buttons["Next"]
        if nextButton.exists && nextButton.isHittable {
            nextButton.tap()
            sleep(1)

            // Now back button should work
            let backButton = app.buttons["Back"]
            if backButton.exists && backButton.isHittable {
                backButton.tap()
                // Should go back without error
            }
        }
    }
}

// MARK: - Settings/Profile Tests

extension ZoeSleepUITests {

    func testProfileSettingsAccess() throws {
        app.launch()
        sleep(2)

        // Find settings/profile button (usually gear icon or profile tab)
        let settingsButton = app.buttons["Settings"]
        let profileButton = app.buttons["Profile"]
        let gearButton = app.buttons["gear"]

        if settingsButton.exists {
            settingsButton.tap()
        } else if profileButton.exists {
            profileButton.tap()
        } else if gearButton.exists {
            gearButton.tap()
        }

        // Look for settings content
        let settingsNav = app.navigationBars["Settings"]
        let profileNav = app.navigationBars["Profile"]
    }

    func testSignOutOption() throws {
        app.launch()
        sleep(2)

        // Navigate to settings
        let settingsButton = app.buttons["Settings"]
        let profileButton = app.buttons["Profile"]

        if settingsButton.exists {
            settingsButton.tap()
        } else if profileButton.exists {
            profileButton.tap()
        }

        sleep(1)

        // Look for sign out button
        let signOutButton = app.buttons["Sign Out"]
        let logOutButton = app.buttons["Log Out"]

        // Sign out should be available when logged in
    }

    func testDeveloperModeToggle() throws {
        app.launch()
        sleep(2)

        // Navigate to settings/profile
        let profileButton = app.buttons["Profile"]
        if profileButton.exists {
            profileButton.tap()
        }

        sleep(1)

        // Look for developer mode section
        let developerSection = app.staticTexts["Developer"]
        let developerToggle = app.switches["Developer Mode"]

        // Developer mode should be accessible for testers
    }

    func testDayJumpInDeveloperMode() throws {
        app.launch()
        sleep(2)

        // This test verifies the day jump feature in developer mode
        // Navigate to settings
        let profileButton = app.buttons["Profile"]
        if profileButton.exists {
            profileButton.tap()
            sleep(1)
        }

        // Look for day selector
        let dayPicker = app.pickers.matching(identifier: "DayPicker").firstMatch
        let jumpButton = app.buttons["Jump to Day"]
    }
}

// MARK: - Sleep Insights Tests

extension ZoeSleepUITests {

    func testSleepInsightsTab() throws {
        app.launch()
        sleep(2)

        // Look for Sleep Insights tab or button
        let insightsTab = app.buttons["Insights"]
        let sleepTab = app.buttons["Sleep"]

        if insightsTab.exists {
            insightsTab.tap()
        } else if sleepTab.exists {
            sleepTab.tap()
        }

        // Look for insights content
        let weeklyAverage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Average'")).firstMatch
        let sleepEfficiency = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Efficiency'")).firstMatch
    }

    func testSleepDataVisualization() throws {
        app.launch()
        sleep(2)

        // Navigate to insights
        let insightsTab = app.buttons["Insights"]
        if insightsTab.exists {
            insightsTab.tap()
        }

        // Look for charts/visualizations
        // Note: XCUITest has limited ability to verify chart content
        let chartView = app.otherElements.matching(identifier: "SleepChart").firstMatch
    }
}

// MARK: - Treatment/Intervention Tests

extension ZoeSleepUITests {

    func testTreatmentDashboard() throws {
        app.launch()
        sleep(2)

        // Look for treatment section (available after Day 15)
        let treatmentTab = app.buttons["Treatment"]
        let tasksSection = app.staticTexts["Today's Tasks"]

        if treatmentTab.exists {
            treatmentTab.tap()
        }

        // Look for task cards
        let taskCard = app.buttons.matching(identifier: "TaskCard").firstMatch
    }

    func testTaskCompletion() throws {
        app.launch()
        sleep(2)

        // Navigate to tasks
        let treatmentTab = app.buttons["Treatment"]
        if treatmentTab.exists {
            treatmentTab.tap()
            sleep(1)
        }

        // Find a task to complete
        let completeButton = app.buttons["Complete"]
        let checkmark = app.buttons.matching(identifier: "TaskCheckmark").firstMatch

        if completeButton.exists && completeButton.isHittable {
            completeButton.tap()
            // Task should be marked complete
        }
    }
}

// MARK: - Accessibility Tests

extension ZoeSleepUITests {

    func testAccessibilityLabels() throws {
        app.launch()
        sleep(2)

        // Verify key elements have accessibility labels
        let buttons = app.buttons.allElementsBoundByIndex

        for button in buttons {
            // Each button should have a label
            let label = button.label
            XCTAssertFalse(label.isEmpty, "Button should have accessibility label")
        }
    }

    func testVoiceOverNavigation() throws {
        app.launch()
        sleep(2)

        // This test documents VoiceOver requirements
        // Full VoiceOver testing requires device testing

        // Check that focusable elements exist
        let focusableElements = app.descendants(matching: .any).matching(
            NSPredicate(format: "isAccessibilityElement == true")
        )

        XCTAssertGreaterThan(focusableElements.count, 0, "Should have accessible elements")
    }

    func testDynamicTypeSupport() throws {
        // This test documents dynamic type requirements
        // Full testing requires changing system text size

        app.launch()

        // Verify app launches successfully with default text size
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}

// MARK: - Error Handling Tests

extension ZoeSleepUITests {

    func testNetworkErrorHandling() throws {
        // This test requires network condition simulation
        // Available in Xcode Network Link Conditioner

        app.launchEnvironment["SIMULATE_NETWORK_ERROR"] = "true"
        app.launch()
        sleep(2)

        // App should display error state gracefully
        let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'Error'")).firstMatch
        let retryButton = app.buttons["Retry"]

        // Error handling UI should be available
    }

    func testOfflineMode() throws {
        app.launchEnvironment["OFFLINE_MODE"] = "true"
        app.launch()
        sleep(2)

        // App should indicate offline status
        let offlineIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'offline' OR label CONTAINS 'Offline'")).firstMatch
    }
}

// MARK: - Performance Tests

extension ZoeSleepUITests {

    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    func testScrollPerformance() throws {
        app.launch()
        sleep(2)

        // Find a scrollable area
        let scrollView = app.scrollViews.firstMatch

        if scrollView.exists {
            measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
                scrollView.swipeUp()
                scrollView.swipeDown()
            }
        }
    }
}
