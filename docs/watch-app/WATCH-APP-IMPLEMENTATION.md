# Apple Watch App Implementation Documentation

**Status:** PAUSED (December 2025)
**Reason:** Prioritizing iPhone app and dashboard development for retreat timeline
**Recovery Branch:** `feature/watch-app-complete`

---

## Executive Summary

The Apple Watch app for Zoe Sleep was approximately 85% complete when development was paused. The app is fully functional for Sleep Log completion with cross-device sync via Convex, but requires additional testing and debugging before production release.

### What Works
- ✅ Sleep Log questionnaire (5 Stanford questions)
- ✅ Cross-device authentication sync with iPhone
- ✅ Direct Convex cloud integration
- ✅ Circadian color theming (no blue light at night)
- ✅ Treatment task viewing and completion
- ✅ HealthKit integration (sleep, heart rate, activity)
- ✅ All watch sizes supported (40mm-49mm Ultra)
- ✅ Debug mode for development/testing

### What Needs Work
- ❌ End-to-end testing on physical devices
- ❌ Edge case handling (network failures, partial syncs)
- ❌ Complication support
- ❌ Background app refresh optimization
- ❌ Push notification integration

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Apple Watch App                           │
├─────────────────────────────────────────────────────────────┤
│  ZoeSleep_Watch_AppApp.swift (Entry Point)                  │
│    └── WatchContentView (TabView)                           │
│         ├── WatchHomeView (Today tab)                       │
│         │    └── QuestionnaireView (Sleep Log)              │
│         ├── TreatmentTasksView (Tasks tab)                  │
│         ├── HealthSummaryView (Health tab)                  │
│         └── WatchSettingsView (Settings tab)                │
├─────────────────────────────────────────────────────────────┤
│  Services                                                    │
│    ├── WatchConvexService (Convex cloud API)                │
│    ├── WatchConnectivityManager (iPhone communication)       │
│    ├── HealthKitWatchManager (HealthKit data)               │
│    └── WatchThemeManager (Circadian theming)                │
└─────────────────────────────────────────────────────────────┘
           │                    │
           ▼                    ▼
    ┌──────────────┐    ┌──────────────┐
    │    Convex    │    │   iPhone     │
    │    Cloud     │    │    App       │
    └──────────────┘    └──────────────┘
```

---

## File Structure

```
ZoeSleep/ZoeSleep Watch App/
├── ZoeSleep_Watch_AppApp.swift      # Main app entry, environment setup
├── WatchHomeView.swift               # Home screen with day progress
├── QuestionnaireView.swift           # Sleep Log questionnaire UI
├── WatchQuestionComponents.swift     # Reusable question input components
├── WatchConvexService.swift          # Direct Convex API integration
├── WatchConnectivityManager.swift    # WatchConnectivity to iPhone
├── WatchThemeManager.swift           # Circadian-aware theming
├── HealthKitWatchManager.swift       # HealthKit data access
├── TreatmentTasksView.swift          # Post-intake treatment tasks
├── RecommendationsView.swift         # Physician recommendations display
├── SettingsView.swift                # Settings + debug controls
├── SleepLogView.swift                # Sleep log specific view
├── Info.plist                        # App configuration
├── ZoeSleep Watch App.entitlements   # App capabilities
└── Assets.xcassets/                  # App icons and colors
```

---

## Core Features

### 1. Sleep Log Questionnaire

The Watch app is designed for **Sleep Log completion only** (not full Assessment). The Assessment is too complex for the small watch screen and must be completed on iPhone.

**5 Stanford Sleep Diary Questions:**
1. What time did you go to bed? (time picker)
2. What time did you fall asleep? (time picker)
3. How many times did you wake up? (number stepper 0-20)
4. What time did you wake up? (time picker)
5. Rate your sleep quality (1-10 scale)

**Question Types Supported:**
- `time` - 12-hour time picker with AM/PM
- `scale` - Slider with Digital Crown support
- `number` - Stepper with +/- buttons and Crown
- `yesNo` - Large tap targets
- `singleSelect` / `radio` - Scrollable option list
- `multiSelect` / `checkbox` - Multiple selection
- `text` - Text field input
- `year` - Birth year picker (1920-current)
- `info` - Display-only informational

**Smart Defaults:**
Time pickers use intelligent defaults based on question context:
- Bedtime → 10:00 PM
- Lights out → Bedtime + 10 min
- Fall asleep → Lights out + 15 min
- Wake time → Fall asleep + 8 hours
- Out of bed → Wake time + 10 min

**File:** `QuestionnaireView.swift`, `WatchQuestionComponents.swift`

### 2. Convex Cloud Integration

Direct HTTP API calls to Convex (no SDK dependency). The Watch authenticates independently or syncs credentials from iPhone.

**Key Functions in `WatchConvexService.swift`:**

```swift
// Authentication
func signIn(username: String, password: String) -> WatchUserInfo
func updateCredentialsFromiPhone(userId: String, username: String?)

// Journey State
func fetchJourneyState() -> WatchJourneyState
func completeSection(dayNumber: Int, section: String) -> WatchCompleteSectionResponse
func advanceDay(debugMode: Bool) -> WatchAdvanceDayResponse

// Responses
func saveResponse(questionId: String, dayNumber: Int, ...)
func saveResponses(dayNumber: Int, responses: [[String: Any]]) -> Int
func getSavedResponses(dayNumber: Int) -> [String: WatchResponseValue]

// Question Progress Sync
func getQuestionProgress(dayNumber: Int, section: String) -> WatchQuestionProgress?
func updateQuestionProgress(dayNumber: Int, section: String, questionIndex: Int, totalQuestions: Int)
```

**Convex Backend Functions (`convex/watch.ts`):**
- `watch:signIn` - Authenticate with username/password
- `watch:getJourneyState` - Get current day and completion status
- `watch:completeSection` - Mark sleepLog or assessment complete
- `watch:advanceDay` - Move to next day (with time/completion checks)
- `watch:saveResponse` / `watch:saveResponses` - Store answers
- `watch:getQuestionProgress` / `watch:updateQuestionProgress` - Cross-device resume

### 3. Cross-Device Sync

The Watch communicates with iPhone via WatchConnectivity for:
- Credential sync (iPhone login triggers Watch authentication)
- Treatment task requests
- Response sync (backup to iPhone-based sync)
- Section completion notifications

**File:** `WatchConnectivityManager.swift`

**Message Types:**
- `userDataUpdate` - Receive user state from iPhone
- `credentialsSync` - Receive Convex credentials from iPhone
- `themeSettingsUpdate` - Sync theme preferences
- `sectionCompleted` - Notify iPhone of Watch completion

### 4. Circadian Color Theming

**CRITICAL:** No blue light after dusk (disrupts melatonin production)

**Time Periods:**
- **Night (dusk → dawn):** Deep browns, warm amber accents
- **Dawn:** Coral/peach transition colors
- **Morning:** Blues/teals OK (energizing)
- **Afternoon:** Soft blues (alertness)

**File:** `WatchThemeManager.swift`

```swift
struct WatchCircadianPalette {
    let background: [Color]
    let wave: Color
    let accent: Color
    let isDark: Bool
    let textPrimary: Color
    let textSecondary: Color

    static var current: WatchCircadianPalette {
        // Returns appropriate palette based on:
        // - Current hour
        // - Seasonal sunrise/sunset calculation
    }
}
```

### 5. HealthKit Integration

Read-only access to health data for context and correlation.

**Data Types Accessed:**
- Sleep analysis (duration, quality)
- Heart rate
- Steps
- Active energy burned
- Exercise minutes
- Walking/running distance

**File:** `HealthKitWatchManager.swift`

### 6. Treatment Tasks

After 15-day intake completion, users receive daily treatment tasks from their physician.

**Features:**
- View pending and completed tasks
- Tap to toggle completion
- Progress bar showing daily completion percentage
- Syncs with iPhone via WatchConnectivity

**File:** `TreatmentTasksView.swift`

### 7. Watch Size Detection

Adaptive UI for all Apple Watch sizes:
- 40mm (SE)
- 41mm (Series 7/8/9/10)
- 44mm (SE)
- 45mm (Series 7/8/9/10)
- 49mm (Ultra/Ultra 2)

**File:** `SettingsView.swift` (`WatchSizeDetector` enum)

```swift
enum WatchSizeDetector {
    var buttonHeight: CGFloat
    var fontSize: CGFloat
    var titleFontSize: CGFloat
    var gridColumns: Int
    // ... more adaptive properties
}
```

---

## User Flow

```
App Launch
    │
    ▼
┌─────────────────────────────────────┐
│         WatchHomeView               │
│  ┌─────────────────────────────┐    │
│  │  DAY 3 of 15                │    │
│  │  ● ● ● ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○│    │
│  ├─────────────────────────────┤    │
│  │  "Building Habits"          │    │
│  │  Every answer helps...      │    │
│  ├─────────────────────────────┤    │
│  │  🌙 Sleep Log    [→]        │    │
│  │     Record last night       │    │
│  ├─────────────────────────────┤    │
│  │  📱 Assessment              │    │
│  │     Complete on iPhone      │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
    │
    │ Tap Sleep Log
    ▼
┌─────────────────────────────────────┐
│       QuestionnaireView             │
│  ┌─────────────────────────────┐    │
│  │  ████████░░  1/5            │    │
│  ├─────────────────────────────┤    │
│  │  What time did you          │    │
│  │  go to bed?                 │    │
│  │                             │    │
│  │     ┌─────────────┐         │    │
│  │     │  10:00 PM   │         │    │
│  │     └─────────────┘         │    │
│  │      Rotate Crown           │    │
│  │                             │    │
│  │  [←]                  [→]   │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
    │
    │ Complete all 5 questions
    ▼
┌─────────────────────────────────────┐
│       Completion Screen             │
│  ┌─────────────────────────────┐    │
│  │          ✓                  │    │
│  │  Sleep Log Complete!        │    │
│  │  Great job logging          │    │
│  │                             │    │
│  │  📱 Assessment              │    │
│  │  Complete on iPhone         │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

---

## Debug Mode

Enable in Settings → Developer → Debug Mode

**Debug Features:**
- Bypass 4 AM time restriction for day advancement
- Reset journey progress to Day 1
- View current Convex sync status
- Manual sync trigger

**Note:** Debug mode does NOT bypass completion checks. Both Sleep Log AND Assessment must be completed to advance days.

---

## Known Issues / TODO

### High Priority
1. **Network Error Handling** - Need graceful degradation when Convex is unreachable
2. **Session Token Expiry** - Handle token refresh for long sessions
3. **Physical Device Testing** - Only tested in Simulator

### Medium Priority
4. **Complications** - Add watch face complications for quick access
5. **Background Refresh** - Optimize battery usage for background updates
6. **Offline Mode** - Queue responses when offline, sync when connected

### Low Priority
7. **Haptic Feedback Polish** - Fine-tune haptic patterns
8. **Accessibility** - VoiceOver improvements
9. **Localization** - Multi-language support

---

## Bundle Configuration

**Bundle Identifiers:**
- Watch App: `com.zoesleep.app.watchkitapp`
- Parent iOS App: `com.zoesleep.app`

**Capabilities Required:**
- HealthKit
- Background Modes (remote notifications, background fetch)
- WatchConnectivity

**Info.plist Key Settings:**
- `WKWatchKitApp` = YES
- `WKCompanionAppBundleIdentifier` = com.zoesleep.app

---

## Recovery Instructions

To resume Watch app development:

1. **Checkout the branch:**
   ```bash
   git checkout feature/watch-app-complete
   ```

2. **Open Xcode project:**
   ```bash
   open ZoeSleep/ZoeSleep.xcodeproj
   ```

3. **Select Watch scheme:**
   - Product → Scheme → "ZoeSleep Watch App"

4. **Run on Simulator or Device:**
   - Select Apple Watch target from device menu
   - Build and Run (⌘R)

5. **Test Login:**
   - Use test account: `user3` / password: `1`
   - Or let iPhone sync credentials automatically

---

## Related Files Outside Watch App

- `convex/watch.ts` - Convex backend functions
- `ZoeSleep/ZoeSleep/Shared/SharedQuestionBank.swift` - Question definitions
- `ZoeSleep/ZoeSleep/Shared/SharedQuestion.swift` - Question model
- iOS WatchConnectivity handler (handles messages from Watch)

---

## Contact / Questions

This documentation was created during the December 2025 development pause. For questions about the Watch app implementation, refer to:

1. The session documentation: `/docs/sessions/watch-app-simplification-2025-12-02.md`
2. The main CLAUDE.md for project context
3. Git history on the `feature/watch-app-complete` branch
