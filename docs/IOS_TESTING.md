# iOS Testing Guide

Comprehensive testing documentation for the Zoe Sleep iOS app.

## Quick Start

```bash
# Run all iOS tests
./scripts/run-ios-tests.sh

# Run specific test suites
./scripts/run-ios-tests.sh unit           # Unit tests only
./scripts/run-ios-tests.sh ui             # UI tests only
./scripts/run-ios-tests.sh integration    # Integration tests
./scripts/run-ios-tests.sh clinical       # Clinical scoring tests
./scripts/run-ios-tests.sh coverage       # All tests with coverage
```

Or run directly in Xcode:
1. Open `ZoeSleep/ZoeSleep.xcodeproj`
2. Select scheme: **ZoeSleep**
3. Press `Cmd + U` to run all tests

## Test Suite Architecture

```
ZoeSleepTests/                    # Unit + Integration Tests
├── TestUtilities.swift           # Mock data, test helpers
├── QuestionnaireManagerTests.swift  # Questionnaire system tests
├── ClinicalScoringTests.swift    # ISI, PHQ-9, GAD-7, ESS, STOP-BANG
├── AuthenticationManagerTests.swift # Auth flow tests
├── ConvexServiceTests.swift      # Backend service tests
├── HealthKitManagerTests.swift   # HealthKit integration tests
├── ThemeManagerTests.swift       # Circadian theming tests
└── IntegrationTests.swift        # End-to-end backend tests

ZoeSleepUITests/                  # UI Automation Tests
└── ZoeSleepUITests.swift         # Login, onboarding, questionnaire UI
```

## Test Categories

### 1. Unit Tests

Test individual components in isolation:

| Test File | Coverage | Key Areas |
|-----------|----------|-----------|
| `QuestionnaireManagerTests` | 45+ tests | Day config, modules, gateways, responses |
| `ClinicalScoringTests` | 25+ tests | ISI, PHQ-9, GAD-7, ESS, STOP-BANG scoring |
| `AuthenticationManagerTests` | 15+ tests | Sign in, sign out, session management |
| `ConvexServiceTests` | 30+ tests | API calls, encoding, keychain |
| `HealthKitManagerTests` | 20+ tests | Demographics, sleep data, sources |
| `ThemeManagerTests` | 15+ tests | Circadian colors, time periods |

### 2. Integration Tests

Test iOS ↔ Convex backend communication:

- Session validation
- Journey progress sync
- Question fetching
- Response submission
- Gateway state sync
- Sleep insights queries
- Treatment phase tracking

**Requirements:**
- Network connectivity
- Running Convex deployment
- Test user in database (`user1` / `1`)

### 3. UI Tests (XCUITest)

Automated UI interaction tests:

| Flow | Tests |
|------|-------|
| Login | Screen elements, sign in, Apple sign in |
| Onboarding | 8-step flow, HealthKit permission, profile |
| Questionnaire | Navigation, sliders, chips, time pickers |
| Settings | Profile access, sign out, developer mode |
| Sleep Insights | Tab navigation, visualizations |
| Treatment | Task cards, completion |
| Accessibility | Labels, VoiceOver, dynamic type |
| Performance | Launch time, scroll performance |

### 4. Clinical Scoring Tests

Validated clinical questionnaire scoring:

#### ISI (Insomnia Severity Index)
- Range: 0-28
- 7 questions, 0-4 scale each
- Thresholds: 0-7 (none), 8-14 (subthreshold), 15-21 (moderate), 22-28 (severe)

#### PHQ-9 (Depression)
- Range: 0-27
- 9 questions, 0-3 scale each
- Thresholds: 0-4 (minimal), 5-9 (mild), 10-14 (moderate), 15-19 (moderately severe), 20-27 (severe)

#### GAD-7 (Anxiety)
- Range: 0-21
- 7 questions, 0-3 scale each
- Thresholds: 0-4 (minimal), 5-9 (mild), 10-14 (moderate), 15-21 (severe)

#### ESS (Epworth Sleepiness Scale)
- Range: 0-24
- 8 questions, 0-3 scale each
- Thresholds: 0-10 (normal), 11-14 (mild EDS), 15-18 (moderate EDS), 19-24 (severe EDS)

#### STOP-BANG (OSA Risk)
- Range: 0-8
- 8 yes/no questions
- Thresholds: 0-2 (low), 3-4 (intermediate), 5-8 (high risk)

## Test User Credentials

Default test users (seeded in database):

| Username | Password | Description |
|----------|----------|-------------|
| user1 | 1 | Standard test user |
| user2-10 | 1 | Additional test users |

## Running Tests

### Command Line (xcodebuild)

```bash
# All tests
xcodebuild test \
  -project ZoeSleep/ZoeSleep.xcodeproj \
  -scheme ZoeSleep \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro"

# Specific test class
xcodebuild test \
  -project ZoeSleep/ZoeSleep.xcodeproj \
  -scheme ZoeSleep \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  -only-testing:ZoeSleepTests/ClinicalScoringTests

# With code coverage
xcodebuild test \
  -project ZoeSleep/ZoeSleep.xcodeproj \
  -scheme ZoeSleep \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  -enableCodeCoverage YES
```

### Xcode

1. Open project
2. Select test target in scheme
3. `Cmd + U` to run all tests
4. `Cmd + 6` to view Test Navigator
5. Click diamond next to test to run individually

### Continuous Integration

Add to GitHub Actions:

```yaml
name: iOS Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Select Xcode
        run: sudo xcode-select -switch /Applications/Xcode_15.0.app
      - name: Run Tests
        run: ./scripts/run-ios-tests.sh
```

## Test Utilities

### MockConvexService

```swift
let mock = MockConvexService.shared
mock.setupDefaultUser()
mock.setupUserAtDay(5)
mock.shouldSucceed = false  // Simulate failures
```

### MockResponseGenerator

```swift
// Generate gateway-triggering responses
let responses = MockResponseGenerator.responsesForGateways(["insomnia", "anxiety"])

// Generate specific score responses
let isiResponses = MockResponseGenerator.isiResponses(targetScore: 18)
let phq9Responses = MockResponseGenerator.phq9Responses(targetScore: 15)

// Generate sleep diary responses
let sleepDiary = MockResponseGenerator.sleepDiaryResponses(
    bedtime: "23:00",
    latency: 20,
    awakenings: 2,
    quality: 4
)
```

### TestDataFactory

```swift
let user = TestDataFactory.createTestUser(
    day: 5,
    onboardingComplete: true,
    gateways: ["insomnia", "depression"]
)

let sleepData = TestDataFactory.createSleepData(
    totalSleep: 420,
    efficiency: 85
)
```

## Debugging Tests

### View Test Logs

```bash
# View xcresult bundle
xcrun xcresulttool get --path .build/TestResults/AllTests.xcresult

# Export test report
xcrun xcresulttool export --path .build/TestResults/AllTests.xcresult \
  --output-path test-report.html --type html
```

### Common Issues

1. **Tests fail with "No session"**: Run integration tests after signing in

2. **UI tests can't find elements**: Check accessibility identifiers in SwiftUI views

3. **HealthKit tests fail**: Run on real device with HealthKit permissions

4. **Clinical scoring discrepancy**: Verify question ID mappings match backend

## Writing New Tests

### Unit Test Template

```swift
@MainActor
final class MyManagerTests: XCTestCase {
    var sut: MyManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = MyManager.shared
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    func testSomeBehavior() {
        // Given
        let input = "test"

        // When
        let result = sut.process(input)

        // Then
        XCTAssertEqual(result, "expected")
    }
}
```

### UI Test Template

```swift
func testSomeFlow() throws {
    app.launch()

    // Wait for element
    let button = app.buttons["MyButton"]
    XCTAssertTrue(button.waitForExistence(timeout: 5))

    // Interact
    button.tap()

    // Verify result
    let result = app.staticTexts["ResultLabel"]
    XCTAssertTrue(result.exists)
}
```

### Integration Test Template

```swift
func testBackendCall() async throws {
    // Authenticate
    await authManager.signIn(email: "user1", password: "1")
    guard authManager.isAuthenticated else { return }

    // Make API call
    do {
        let result = try await convexService.someQuery()
        XCTAssertNotNil(result)
    } catch {
        XCTFail("API call failed: \(error)")
    }
}
```

## Coverage Requirements

Target coverage by component:

| Component | Target | Priority |
|-----------|--------|----------|
| Clinical Scoring | 95%+ | Critical |
| Authentication | 80%+ | High |
| Questionnaire Flow | 75%+ | High |
| Data Models | 70%+ | Medium |
| UI Components | 60%+ | Medium |
| Utilities | 50%+ | Low |

## Files Reference

| File | Purpose |
|------|---------|
| `scripts/run-ios-tests.sh` | Automated test runner |
| `ZoeSleepTests/TestUtilities.swift` | Mocks and helpers |
| `ZoeSleepTests/*.swift` | Unit + integration tests |
| `ZoeSleepUITests/*.swift` | UI automation tests |
