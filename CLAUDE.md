# CLAUDE.md

This file provides essential guidance to Claude Code when working with the **Zoe Sleep** repository.

## Brand & Product

**Product Name:** Zoe Sleep
**Tagline:** "Sleep Better, Live Longer"
**Design Theme:** Elegant circadian waves (NO moon/stars clichés) - abstract waveforms, gradient flows

**CRITICAL Color Principle (Sleep-Optimized):**
- **Morning/Afternoon**: Blues, teals, greens OK (promotes alertness)
- **Evening/Night**: ONLY warm colors (amber, orange, brown) - NO blue spectrum
- This is non-negotiable for a sleep app - blue light disrupts melatonin production

## Platform Architecture

**Patient-Facing Applications (Cross-Platform):**
- **Apple Watch App** (PRIMARY for morning logs): 60-second Stanford Sleep Log completion
- **iOS Application**: Full 15-day intake journey with comprehensive questionnaire
- **Web Application**: Patient access via browser (also used for debugging)
- **Cross-device Sync**: Real-time Convex sync - start on Watch, continue on iPhone, finish on Web

**Physician/Admin Dashboard:**
- **Web Dashboard** (`/physician`): Patient review, questionnaire scores, treatment prescriptions
- **Question Manager**: Drag-and-drop question assignment, add new questions with 9 answer types

**Supported Apple Watch Models (ALL sizes):**
| Model | Case Size | Adaptive UI |
|-------|-----------|-------------|
| SE (2nd gen) | 40mm/44mm | Compact layout |
| Series 7/8/9/10 | 41mm/45mm | Standard layout |
| **Ultra/Ultra 2** | **49mm** | **Spacious layout, 5-column grids** |

**Development & Backend:**
- **Convex Backend**: Serverless with real-time data synchronization across all platforms
- **Clerk Authentication**: JWT-based auth shared across iOS, Watch, and Web

## Quick Start Commands

```bash
# Install and run everything
npm run install:all && npm run dev

# Database setup (Adaptive Questionnaire System - RECOMMENDED)
cd server && npm run seed-adaptive

# Database setup (Legacy SQLite mode)
cd server && npm run seed

# Database setup (Convex mode) 
npx convex dev && ./setup-convex.sh
```

## ⚡ NEW: Smart Adaptive Questionnaire System

**Revolutionary Intelligence for Sleep Assessment:**
- **Smart Gateway Logic**: Questions adapt based on user responses - no overwhelming 300+ question dumps
- **15-Day Distribution**: Core foundation (Days 1-5) + conditional expansion (Days 6-15)
- **Stanford Sleep Log**: Daily parallel tracking for subjective vs objective data analysis
- **Clinical Methodology**: Based on validated sleep assessment instruments (PSQI, ISI, DBAS-16, etc.)
- **Load Balancing**: Light days (7-9 questions) vs Heavy expansion days (13-29 questions) only when needed

**Gateway Triggers:**
- **Insomnia Gateway** → ISI, DBAS-16, Sleep Hygiene, PSAS questionnaires
- **Daytime Sleepiness** → ESS, FSS, FOSQ-10 assessments  
- **Mental Health** → PHQ-9, GAD-7, DASS-21, PROMIS-Cognitive screening
- **Sleep Apnea** → STOP-BANG, Berlin questionnaires
- **Pain/Diet/Chronotype** → Targeted assessments only if relevant

## Critical Settings

**Database Mode:** Set `USE_CONVEX=true` in `/server/.env` for cloud mode (default: SQLite)

**Test Credentials:** user1-user10, password: "1"

## Key File Locations

**iOS Application (Xcode Project):**
- **Xcode Project:** `/ZoeSleep/ZoeSleep.xcodeproj` (Main iOS project)
- **iOS Target:** `/ZoeSleep/ZoeSleep/` (Swift/SwiftUI iOS app implementation)
- **Models:** `/ZoeSleep/ZoeSleep/Models/` (QuestionModels for questionnaire system)
- **Managers:** `/ZoeSleep/ZoeSleep/Managers/` (HealthKitManager, AuthenticationManager, QuestionnaireManager)
- **Views:** `/ZoeSleep/ZoeSleep/Views/` (QuestionnaireView, QuestionComponents, ContentView)
- **Services:** `/ZoeSleep/ZoeSleep/Services/` (APIService, ConvexService for backend integration)

**Apple Watch Application (Xcode Project):**
- **Watch Target:** `/ZoeSleep/ZoeSleep Watch App/` (watchOS app in Xcode project)
- **Main App:** `/ZoeSleep/ZoeSleep Watch App/ZoeSleep_Watch_AppApp.swift` (Watch app entry point)
- **Questionnaire:** `/ZoeSleep/ZoeSleep Watch App/QuestionnaireView.swift` (Watch-optimized UI)
- **Sleep Log:** `/ZoeSleep/ZoeSleep Watch App/SleepLogView.swift` (60-second morning flow)
- **Settings:** `/ZoeSleep/ZoeSleep Watch App/SettingsView.swift` (Large text, debug mode)
- **Question Components:** `/ZoeSleep/ZoeSleep Watch App/WatchQuestionComponents.swift` (Adaptive UI for all watch sizes)
- **Recommendations:** `/ZoeSleep/ZoeSleep Watch App/RecommendationsView.swift` (Physician recommendations)
- **Watch HealthKit:** `/ZoeSleep/ZoeSleep Watch App/HealthKitWatchManager.swift` (Watch health data)
- **Watch Connectivity:** `/ZoeSleep/ZoeSleep Watch App/WatchConnectivityManager.swift` (iPhone-Watch sync)

**Legacy Files (Archived):**
- **iOS Reference:** `/ios/` (Original Swift files - archived)
- **watchOS Reference:** `/watchos/` (Original watch files - archived)
- **Sleep360 (Old):** `/Sleep360/` (Archived, replaced by ZoeSleep)

**Web Application (Patient + Physician):**
- **Patient Journey:** `/client/src/app/journey/` (Next.js - 15-day questionnaire)
- **Patient Treatment:** `/client/src/app/treatment/` (Post-intake daily tasks)
- **Physician Dashboard:** `/client/src/app/physician-dashboard/` (Patient list, scores, prescriptions)
- **Physician Patient View:** `/client/src/app/physician-dashboard/patient/[id]/` (Day-by-day responses, AI analysis)
- **Physician Prescription:** `/client/src/app/physician-dashboard/patient/[id]/prescription/` (Treatment plans builder)
- **Question Manager:** `/client/src/app/physician-dashboard/questions/` (Day/Module/Question views)
- **Physician Settings:** `/client/src/app/physician-dashboard/settings/` (Profile, notifications)

**Convex Backend:**
- **Schema:** `/convex/schema.ts` (30+ tables with real-time sync)
- **Functions:** `/convex/` (queries, mutations, actions for all platforms)
- **Watch Functions:** `/convex/watch.ts` (watch connectivity and sync)
- **Recommendations:** `/convex/recommendations.ts` (physician recommendations for watch)
- **Auth:** Clerk authentication integration
- **Documentation:** `/docs/` (organized by category)

## Development Patterns

**Watch-First Design Philosophy:**
- Design for 41mm Apple Watch FIRST, then scale up to larger screens
- Stanford Sleep Log completable in **under 60 seconds** on any watch
- Digital Crown for time pickers and sliders (with haptic feedback)
- Adaptive layouts: UI automatically adjusts to watch size (40mm → 49mm Ultra)
- Large tap targets: 44pt minimum, 60pt on Ultra

**Cross-Platform Sync:**
- Real-time Convex sync across Watch, iPhone, and Web
- Start questionnaire on Watch → Continue on iPhone → Finish on Web
- Progress saved instantly to cloud

**Accessibility Features:**
- **Large Icons Mode**: 30% bigger buttons/text for poor eyesight
- **High Contrast**: Bolder colors, clearer borders
- **Reduce Motion**: Minimize animations
- **Text Size Slider**: Scalable from 0.8x to 1.4x

**iOS & watchOS Development:**
- Swift/SwiftUI with Xcode project at `/ZoeSleep/ZoeSleep.xcodeproj`
- HealthKit integration for comprehensive sleep and health data
- WatchConnectivity for iPhone-Watch sync

**Web Application (Patient + Physician):**
- Next.js 14 with App Router
- Patients can complete questionnaire on web (interchangeable with iOS/Watch)
- Physicians access dashboard at `/physician`
- Day advancement button in Settings > Debug Mode for testing

**Common Patterns:**
- Convex provides real-time data synchronization across platforms
- Use test users (user1-user10, password: "1") for rapid development/testing
- Clerk authentication for iOS app
- TypeScript backend with Swift/SwiftUI frontend

## Important Notes

- Timestamps stored as Unix timestamps (numbers)
- JSON fields stored as strings (require parsing) 
- Hard-coded test users for rapid prototyping
- Assessment system: 9 question answer types
- Admin panel: drag-and-drop question reordering

## Documentation

Complete documentation available in organized `/docs/` structure:
- **Setup:** `/docs/setup/` - Environment and service configuration
- **API:** `/docs/api/` - Complete API documentation
- **Architecture:** See README.md for full overview
- **Troubleshooting:** `/docs/guides/TROUBLESHOOTING.md`

For detailed architecture, setup instructions, and API documentation, see README.md.

## Recent Changes (2025-11-21)

**Clerk Authentication Integration Session:**
- Implemented comprehensive authentication system using Clerk
- **Web App Features:**
  - Added Clerk environment variables and provider configuration
  - Created protected routes with middleware (`/journey`, `/sleep-diary`)
  - Built sign-in/sign-up pages with styled components
  - Added authentication UI with user menu and modal sign-in
- **iOS App Features:**  
  - Created complete iOS authentication system with Swift/SwiftUI
  - Built AuthenticationManager for Clerk integration
  - Added APIService for authenticated requests
  - Updated HealthKitManager to require authentication
  - Created comprehensive authentication UI views
- **Security:** JWT token-based authentication shared between platforms
- **Files Added:** 4 new iOS authentication files, 2 new web auth routes
- **Session Goal:** Enable secure user authentication across both platforms
- **Commit Hash:** `1ded787` - "Implement comprehensive Clerk authentication for iOS and web platforms"
- **Repository:** Successfully pushed to https://github.com/CavalPinarello/15-day-Intake.git
- **Session Log:** `/docs/sessions/clerk-authentication-2025-11-21.md`

**Apple Watch Integration Session (2025-11-21):**
- **Platform Expansion:** Extended architecture to include Apple Watch as alternative questionnaire interface
- **Multi-Platform Design:** iOS + Apple Watch + Web applications with shared Convex backend
- **Watch Features:** 
  - Alternative questionnaire experience optimized for watch interactions
  - Post-intake physician recommendations delivered to Apple Watch
  - Real-time sync between iPhone and Apple Watch via WatchConnectivity
  - Watch-specific HealthKit integration for comprehensive health data
- **Cross-Device Sync:** Seamless questionnaire progress sync between iPhone and Apple Watch
- **New watchOS Files:** Created complete Apple Watch application structure (5 Swift files)
- **Documentation Updates:** Updated all architecture docs to reflect multi-platform design
- **Session Goal:** Enable 15-day intake completion on Apple Watch with physician recommendations
- **Commit Hash:** `f92b918` - "Implement Apple Watch integration for 15-day intake journey"
- **Repository:** Successfully pushed to https://github.com/CavalPinarello/15-day-Intake.git
- **Session Log:** `/docs/sessions/apple-watch-integration-2025-11-21.md`

## Latest Session Context (2025-12-02)

**Complete Onboarding Redesign with User-Account-Aware State**

This session completely redesigned the onboarding flow to fix three critical issues:
1. Screens were too large and didn't fit iPhone screen sizes
2. Two splash screens appeared when the app loaded
3. Onboarding didn't follow the circadian color system
4. Onboarding state was device-based, not user-account-based

### Problems Fixed

#### 1. Screens Too Large for iPhone
The original onboarding screens had fixed large padding, icons, and text that overflowed on smaller iPhones (SE, Mini).

**Solution:** Added adaptive layouts using `GeometryReader`:
- `isCompact` flag triggers for screens < 700pt height
- Smaller icons, tighter spacing on compact screens
- All 9 onboarding steps fit any iPhone without scrolling issues

#### 2. Double Splash Screen
The app showed both a system UILaunchScreen and a SwiftUI SplashScreenView, creating a "double splash" effect.

**Solution:**
- Reduced splash duration from 2.5s to 1.2s
- Simplified splash animation (quick fade-in instead of complex animations)
- Uses circadian colors to match the rest of the app

#### 3. No Circadian Colors in Onboarding
Onboarding used hardcoded blue/orange colors, ignoring the time-of-day circadian system.

**Solution:** All onboarding screens now use `CircadianPalette.current`:
- Evening/night: Warm amber/orange colors (sleep-safe)
- Morning/afternoon: Blues/teals for alertness
- Background gradients, buttons, text all adapt to time of day

#### 4. Device-Based vs User-Account-Based Onboarding
Previously, onboarding completion was stored in local UserDefaults. This meant:
- Reinstalling app showed onboarding again for existing users
- Logging into a new account might skip onboarding

**Solution:** Onboarding state is now tied to user account via server:
- `OnboardingManager.checkUserOnboardingState()` called after login
- Server's `onboardingCompleted` field is the source of truth
- Completing onboarding saves to server via `ConvexService.updateUserProfile()`
- Different users on same device get correct onboarding state

### New App Flow

```
App Launch → Splash (1.2s) →
  ├── Not Authenticated → AuthenticationView (Login)
  ├── Authenticated + No Onboarding → OnboardingView
  └── Authenticated + Onboarding Complete → Main Dashboard
```

### Key Files Modified

- `/ZoeSleep/ZoeSleep/Views/OnboardingView.swift` - Complete rewrite with adaptive layouts + circadian colors
- `/ZoeSleep/ZoeSleep/Views/SplashScreenView.swift` - Simplified with shorter duration + circadian colors
- `/ZoeSleep/ZoeSleep/ZoeSleepApp.swift` - New `AppRootView` with auth → onboarding → content routing
- `/ZoeSleep/ZoeSleep/Managers/OnboardingManager.swift` - User-aware state, server sync, `clearForSignOut()`
- `/ZoeSleep/ZoeSleep/Managers/AuthenticationManager.swift` - Calls `checkUserOnboardingState()` after login
- `/ZoeSleep/ZoeSleep/ContentView.swift` - Simplified (routing moved to AppRootView)

### Onboarding Steps (9 Total)

1. **Welcome** - Logo, tagline, "Get Started" button
2. **Name** - Text input with auto-focus
3. **Measurement System** - Metric/Imperial selection
4. **Height & Weight** - Sliders (metric) or wheel pickers (imperial)
5. **Gender & Age** - 2x2 grid + birth year picker
6. **Wearables** - Multi-select device grid
7. **Health Connect** - Apple Health authorization
8. **Sleep Philosophy** - Our approach explanation
9. **Ready** - Summary and "Start My Journey"

---

## Previous Session Context (2025-12-02)

**Fix: Circadian Text Color Contrast for Evening/Night Mode**

This session fixed a critical visibility issue where text was invisible on the warm brown circadian background during evening/night hours.

### Problem
At 4:31 PM (or any time after seasonal dusk), the app displayed warm brown backgrounds correctly, but the text remained gray (system `.secondary` color), making it completely invisible. Users could not read any secondary text on the dashboard.

### Root Cause
Two separate time calculation systems were out of sync:
1. **`CircadianPalette.current`** (backgrounds) used **seasonal sunrise/sunset** calculation
2. **`TimePeriod.current`** (text colors) used **fixed hour boundaries** (12-17 = afternoon)

In December with early sunset (~4:30 PM), the background switched to evening mode at ~3 PM, but text colors stayed in "afternoon" mode until 5 PM.

### Solution

#### 1. Synchronized Time Period Calculation (`QuestionModels.swift`)
Updated `TimePeriod.current` to use the **same seasonal calculation** as `CircadianPalette`:
```swift
// Seasonal sunrise/sunset calculation (SAME as CircadianPalette!)
let seasonalOffset = sin(Double(dayOfYear - 80) / 365.0 * .pi * 2)
let sunriseHour = 6.5 - seasonalOffset * 1.0   // 5:30 to 7:30 AM
let sunsetHour = 18.5 + seasonalOffset * 2.0   // 4:30 to 8:30 PM
let duskStart = sunsetHour - 1.5  // Evening starts 1.5 hours before sunset
```

#### 2. Brighter Text Colors for Dark Backgrounds (`QuestionModels.swift`)
| Property | Old Value | New Value | Color |
|----------|-----------|-----------|-------|
| `textPrimary` (evening/night) | `rgb(1.0, 0.92, 0.85)` | `#FEF3C7` | Bright warm cream |
| `textSecondary` (evening/night) | `rgb(0.85, 0.70, 0.55)` | `#FCD34D` | Golden yellow |
| `textMuted` (NEW) | - | `#F59E0B` | Amber |

#### 3. Fixed Hardcoded `.secondary` Colors (`ContentView.swift`)
Replaced 11 instances of `foregroundColor(.secondary)` with `foregroundColor(theme.textSecondary)`.

#### 4. Web Client Circadian Theme (NEW FILES)
Created complete circadian theme system for the web client:
- `/client/src/lib/circadianTheme.ts` - Color palette and utilities
- `/client/src/hooks/useCircadianTheme.ts` - React hook for components
- Updated `journey/page.tsx` and all question components with circadian support

### Key Files Modified
- `/ZoeSleep/ZoeSleep/Models/QuestionModels.swift` - TimePeriod sync, brighter text colors
- `/ZoeSleep/ZoeSleep/Views/CircadianWaveBackground.swift` - Updated CircadianPalette text colors
- `/ZoeSleep/ZoeSleep/ContentView.swift` - Replaced .secondary with theme.textSecondary
- `/client/src/lib/circadianTheme.ts` - NEW: Web circadian color system
- `/client/src/hooks/useCircadianTheme.ts` - NEW: React hook for circadian theme
- `/client/src/app/journey/page.tsx` - Web circadian theme integration
- `/client/src/components/questions/*.tsx` - All question components updated

### Result
Text is now **high contrast** on dark brown backgrounds:
- Primary text: Bright cream (`#FEF3C7`)
- Secondary text: Golden yellow (`#FCD34D`)
- Both iOS and Web apps now have synchronized circadian themes

---

## Previous Session Context (2025-12-02)

**Watch UI Fix: Hide Debug Reset Button & Add Assessment Navigation**

This session fixed two issues on the Watch questionnaire completion screen:

### Problem 1: "Reset & Start Over" Always Visible
The "Reset & Start Over" button was showing on the completion screen unconditionally, even when debug mode was disabled. This debug feature should only be visible to developers.

### Problem 2: No Way to Proceed to Day Assessment
After completing the Sleep Log, the screen showed "Day Assessment still remaining" but there was no way to actually navigate to the assessment questions.

### Solution

#### 1. Debug Mode Gate for Reset Button (`QuestionnaireView.swift` lines 285-296)
```swift
// Debug: Reset button only shown in debug mode
if themeManager.debugMode {
    Divider()
        .padding(.vertical, 4)

    Button("Reset & Start Over") {
        resetAllProgress()
    }
    .buttonStyle(.bordered)
    .tint(.red)
    .font(.caption2)
}
```

#### 2. Assessment Navigation Button (`QuestionnaireView.swift` lines 246-259)
Added a `NavigationLink` to the Day Assessment after sleep log completion:
```swift
NavigationLink(destination: QuestionnaireView(mode: .assessment)) {
    HStack {
        Image(systemName: "list.clipboard.fill")
        Text("Start Assessment")
    }
    .font(.system(size: 14, weight: .semibold))
    .foregroundColor(.white)
    .padding(.vertical, 10)
    .padding(.horizontal, 16)
    .background(theme.primary)
    .cornerRadius(10)
}
```

### Other Changes in This Commit

#### Year Picker for Date of Birth (`QuestionnaireView.swift`)
- Added `WatchYearPickerView` component for year selection (1920-present)
- Shows scrollable year picker with live age indicator
- Added `.year` case to `WatchQuestionType` enum
- Converts `.date` type questions to year picker on Watch

### Key Files Modified
- `/ZoeSleep/ZoeSleep Watch App/QuestionnaireView.swift` - Debug gate, navigation button, year picker

---

## Previous Session Context (2025-12-02)

**Fix: Questionnaire Jumping to Last Question on Day 1**

This session fixed a critical bug where starting the sleep log on Day 1 would immediately jump to the last question, skipping all previous questions.

### Problem
When starting the Sleep Log questionnaire on Day 1, the Watch app would immediately show the last question (e.g., "How would you rate your sleep quality?") instead of the first question ("What time did you go to bed?"). Users had to manually go back through all questions.

### Root Cause
The `questionnaire_session` table in Convex was storing cross-device sync progress, but:
1. **`resetProgress` didn't clear sessions**: When users reset their progress (debug mode), the old `questionnaire_session` records weren't deleted
2. **Stale sessions persisted**: Old sessions with high `currentQuestionIndex` values would cause the app to resume at the wrong position
3. **No validation for orphaned progress**: The app blindly resumed progress even when no saved responses existed

### Solution
Three-part fix across backend and both client apps:

#### 1. Convex Backend (`/convex/watch.ts`)

**`resetProgress` mutation (lines 776-784)**:
- Now deletes all `questionnaire_session` entries when user resets progress
```typescript
// Delete questionnaire session progress (cross-device sync state)
const sessions = await ctx.db
  .query("questionnaire_session")
  .withIndex("by_user_day_section", (q) => q.eq("user_id", args.userId))
  .collect();

for (const session of sessions) {
  await ctx.db.delete(session._id);
}
```

**`completeSection` mutation (lines 361-376)**:
- Now marks `questionnaire_session` as `completed: true` when section is finished
- Prevents completed sessions from being incorrectly resumed

#### 2. Watch App (`QuestionnaireView.swift`)

**`loadSavedProgress()` rewritten (lines 760-821)**:
- Loads saved responses FIRST, before checking progress
- Added validation: only resumes if `loadedResponseCount > 0`
- Added logging for stale progress detection:
```swift
let isValidProgress = !progress.completed &&
                      progress.currentQuestionIndex < questions.count &&
                      progress.currentQuestionIndex > 0 &&
                      loadedResponseCount > 0
```

#### 3. iOS App (`QuestionnaireView.swift`)

**Same fix applied (lines 593-656)**:
- Responses loaded first for validation
- Progress only resumed if saved responses exist
- Stale progress is logged and ignored

### Key Files Modified
- `/convex/watch.ts` - resetProgress clears sessions, completeSection marks completed
- `/ZoeSleep/ZoeSleep Watch App/QuestionnaireView.swift` - Stale progress validation
- `/ZoeSleep/ZoeSleep/Views/QuestionnaireView.swift` - Same fix for iOS

### Testing
1. Reset progress via Settings > Debug Mode > Reset Progress
2. Start Day 1 Sleep Log - should show question 1, not last question
3. Answer 2 questions, switch to iPhone, continue from question 3
4. Complete section, start again - should not resume old progress

---

## Previous Session Context (2025-12-02)

**Smart Time Picker Defaults Based on Previous Answers**

This session fixed the time picker pre-selection issue where subsequent time questions (like "What time did you wake up?") were showing arbitrary default times instead of logically following the previously answered bedtime.

### Problem
When completing the daily sleep log:
- First question "What time did you go to bed?" correctly defaulted to 10:00 PM
- Second question "What time did you fall asleep?" showed 1:00 PM instead of ~10:15 PM
- Third question "What time did you wake up?" showed arbitrary time instead of ~6:00-7:00 AM

### Solution
Modified time picker components on both iOS and Watch to use **previously answered bedtime** as the basis for calculating smart defaults:

#### iOS Changes (`QuestionComponents.swift`)
- Added `previousBedtime: Date?` parameter to `TimeInput` component
- Updated `smartDefaultTime` to calculate:
  - **SL_ASLEEP_TIME**: bedtime + 15 minutes
  - **SL_WAKE_TIME**: bedtime + 8 hours
  - **PSQI_3**: bedtime + 8 hours (for PSQI wake time questions)

#### iOS Changes (`QuestionnaireView.swift`)
- Added `getPreviousBedtime(for:)` helper function that returns:
  - For `SL_ASLEEP_TIME` and `SL_WAKE_TIME` → `SL_BEDTIME` answer
  - For `PSQI_3` (wake time) → `PSQI_1` (bedtime) answer
  - For weekday/weekend wake times → corresponding bedtime answer

#### Watch Changes (`QuestionnaireView.swift`)
- Added `previousBedtime: Date?` parameter to `WatchTimePickerView`
- Added same smart default calculation logic
- Added `getPreviousBedtime(for:)` helper function

### Result
Now when answering "What time did you go to bed?" with 11:00 PM:
- "What time did you fall asleep?" defaults to **11:15 PM** (15 min later)
- "What time did you wake up?" defaults to **7:00 AM** (8 hours later)

### Key Files Modified
- `/ZoeSleep/ZoeSleep/Views/QuestionComponents.swift` - TimeInput with previousBedtime
- `/ZoeSleep/ZoeSleep/Views/QuestionnaireView.swift` - getPreviousBedtime helper
- `/ZoeSleep/ZoeSleep Watch App/QuestionnaireView.swift` - WatchTimePickerView with previousBedtime + helper
- `/ZoeSleep/ZoeSleep/Services/ConvexService.swift` - Fixed mutation response type bug

---

## Previous Session Context (2025-12-02)

**Sleep-Optimized Circadian Color System**

This session implemented a complete sleep-optimized circadian color system that eliminates ALL blue/teal/purple light from the app during evening and night hours, replacing them with warm amber/orange colors that are safe for melatonin production.

### Critical Design Principle
**NO BLUE LIGHT AFTER DUSK** - As a sleep app, Zoe Sleep must avoid the blue light spectrum (blue, teal, cyan, purple, green) in evening/night mode. Only warm colors (amber, orange, brown, red) are used after sunset.

### Features Implemented

#### 1. iOS ColorTheme Sleep-Optimization (`QuestionModels.swift`)
Complete rewrite of the `ColorTheme` struct to use sleep-safe colors:

| Color Property | Day (Morning/Afternoon) | Evening/Night |
|----------------|------------------------|---------------|
| `primary` | Sky blue `#0EA5E9` / Amber `#F59E0B` | Warm amber `#F28C40` |
| `secondary` | Light blue `#38BDF8` / Golden `#FBBF24` | Deep amber `#D97706` |
| `tertiary` | Cyan `#06B6D4` / Deep amber | Burnt orange `#B45309` |
| `backgroundTint` | Blue/amber tint | Warm amber tint |
| `cardBackground` | Light blue `#F0F9FF` / Cream | Deep warm brown `#2D1A14` |
| `textPrimary` | System default | Warm white `rgb(1.0, 0.92, 0.85)` |
| `textSecondary` | System default | Warm tan `rgb(0.85, 0.70, 0.55)` |
| `insights` | Emerald green | Amber `#F59E0B` |
| `sleepDiary` | Purple | Deep amber `#D97706` |

#### 2. iOS Wave Background (`CircadianWaveBackground.swift`)
- `DashboardWaveBackground`: Animated flowing waves with circadian-aware colors
- `QuestionnaireWaveBackground`: Subtle animated waves for questionnaire screens
- `CircadianPalette`: Centralized palette with seasonal sunrise/sunset calculation
- `GlassyCardBackground`: Translucent cards with warm brown tones at night

#### 3. Apple Watch Circadian System (`WatchThemeManager.swift`, `WatchHomeView.swift`)
- Added `WatchCircadianPalette` struct matching iOS implementation
- Updated all Watch UI components to use circadian colors:
  - `CircadianBackground`: Warm amber ribbons at night
  - `dayHeader`, `motivationCard`: Use palette accent/text colors
  - `actionButtons`: Warm amber/orange for incomplete states at night
  - `countdownCard`, `journeyProgressCard`: All circadian-aware
  - `journeyCompleteCard`: Warm gold trophy at night

#### 4. JSON Crash Fix (`ConvexService.swift`)
Fixed `NSInvalidArgumentException: Invalid top-level type in JSON write` crash:
- Added NSNull check before JSON serialization
- Added `JSONSerialization.isValidJSONObject()` validation
- Handle primitive types (String, Number, Bool) separately
- Try-catch wrappers in `getQuestionProgress()` and `getSavedResponses()`

### Time-Based Color Logic
Uses seasonal sunrise/sunset calculation:
```swift
let seasonalOffset = sin(Double(dayOfYear - 80) / 365.0 * .pi * 2)
let sunriseHour = 6.5 - seasonalOffset * 1.0  // 5:30 to 7:30 AM
let sunsetHour = 18.5 + seasonalOffset * 2.0   // 4:30 to 8:30 PM
```

### Key Files Modified
- `/ZoeSleep/ZoeSleep/Models/QuestionModels.swift` - Complete ColorTheme rewrite
- `/ZoeSleep/ZoeSleep/Views/CircadianWaveBackground.swift` - Wave animations + CircadianPalette
- `/ZoeSleep/ZoeSleep/ContentView.swift` - Use theme.textPrimary/textSecondary throughout
- `/ZoeSleep/ZoeSleep/Services/ConvexService.swift` - JSON crash fix
- `/ZoeSleep/ZoeSleep Watch App/WatchThemeManager.swift` - WatchCircadianPalette
- `/ZoeSleep/ZoeSleep Watch App/WatchHomeView.swift` - All UI using circadian colors

---

## Previous Session Context (2025-12-01)

**Enhanced Watch Day Complete UI & Number Input Improvements**

This session enhanced the Apple Watch "Day Complete" state with useful information and fixed the number stepper input.

### Features Implemented

#### 1. Enhanced Day Complete Celebration (WatchHomeView.swift)
When a day is complete, the Watch now shows much more useful information:

- **Live Countdown Timer**: Shows hours:minutes:seconds until 4 AM unlock
  - Updates every second in real-time
  - Shows "Ready now!" with green checkmark when unlocked
  - Debug mode: Shows "Advance to Day X" button that bypasses time check

- **15-Day Journey Progress**: Visual progress visualization
  - Progress bar showing X/15 completion
  - 15 dots representing each day (filled = completed)
  - "X days remaining" message

- **ZOE Treatment Tasks Card**: If pending tasks exist
  - Orange card showing number of pending tasks
  - Tapping navigates to TreatmentTasksView

- **Journey Complete State**: For Day 15 completion
  - Trophy icon with celebration message
  - "View Treatment Plan" button if tasks exist

#### 2. Number Input with Progress Bar & Digital Crown (QuestionnaireView.swift)
The "How many times did you wake up?" stepper now has:

- **Visual Progress Bar**: Fills left-to-right as number increases (0-20 range)
- **Digital Crown Support**: Rotate scroll wheel to change value with haptic feedback
- **+/- Buttons**: Still work, now show disabled state at limits
- **Smooth Animations**: Number display animates on change
- **Hint Text**: "Rotate Crown or tap ±" to guide users

#### 3. Day Advancement System (convex/watch.ts)
New backend support for day progression:

- **advanceDay mutation**: Server-side day advancement with validation
  - Checks if current day's sleep log + assessment are complete
  - Debug mode bypasses time check (NOT completion check)
  - Returns new day number or error if sections incomplete

- **Watch Integration**: "Start Day X" button in countdown card
  - Only appears when countdown reaches zero (or debug mode)
  - Calls advanceDay mutation to progress journey

### Key Files Modified
- `/ZoeSleep/ZoeSleep Watch App/WatchHomeView.swift` - Enhanced day complete UI, countdown timer, journey progress
- `/ZoeSleep/ZoeSleep Watch App/QuestionnaireView.swift` - New WatchNumberInputView with progress bar + crown
- `/ZoeSleep/ZoeSleep Watch App/WatchConvexService.swift` - advanceDay method
- `/ZoeSleep/ZoeSleep Watch App/WatchThemeManager.swift` - debugMode property
- `/ZoeSleep/ZoeSleep Watch App/SettingsView.swift` - Debug mode toggle
- `/convex/watch.ts` - advanceDay mutation with completion validation
- `/ZoeSleep/ZoeSleep/Services/ConvexService.swift` - iOS advanceDay support
- `/ZoeSleep/ZoeSleep/ContentView.swift` - Debug mode advance button

### Unlock Time Changed
- Day unlock time changed from **5 AM to 4 AM** for earlier morning access

---

## Previous Session Context (2025-12-01)

**Cross-Device Question-by-Question Sync & Day Completion UI**

This session implemented seamless question-level progress sync across iOS, Watch, and Web, plus day completion celebration UI.

### Features Implemented

#### 1. Question-by-Question Cross-Device Sync
Users can now start a questionnaire on one device and seamlessly continue on another, picking up at the exact question they left off.

**New Convex Schema (`/convex/schema.ts`):**
- Added `questionnaire_session` table tracking:
  - `user_id`, `day_number`, `section` (sleepLog/assessment)
  - `current_question_index` - exact question position
  - `total_questions`, `last_device` ("ios", "watch", "web")
  - `completed` status with timestamps

**New Convex Functions (`/convex/watch.ts`):**
- `watch:getQuestionProgress` - Get where user left off
- `watch:updateQuestionProgress` - Save progress after each question
- `watch:completeQuestionProgress` - Mark section complete
- `watch:getSavedResponses` - Get all saved answers for pre-filling

**iOS Integration (`ConvexService.swift`, `QuestionnaireView.swift`):**
- `getQuestionProgress()`, `updateQuestionProgress()`, `getSavedResponses()`
- Loads saved progress on questionnaire open
- Syncs position after each "Next" tap
- Pre-fills previously answered questions

**Watch Integration (`WatchConvexService.swift`, `QuestionnaireView.swift`):**
- Same sync functions with `device: "watch"`
- Auto-resumes from where user left off
- Robust error handling for network issues

**Web Integration (`/client/src/lib/convexService.ts`, `journey/page.tsx`):**
- New HTTP-based Convex client for browser
- Loads progress and responses on page load
- Syncs after each question advancement

#### 2. Day Completion Celebration UI

**iOS (`ContentView.swift`):**
- `DayCompleteCelebrationView` component showing:
  - Star icon with "Day X Complete!" message
  - **Debug mode**: "Advance to Day X" button for instant progression
  - **Normal mode**: Countdown timer to 5 AM unlock
  - Live countdown (hours/minutes/seconds)
  - Journey complete message for Day 15
- "Complete" badge with checkmark in Today's Tasks header

**Watch (`WatchHomeView.swift`):**
- Celebration card when both sleep log and assessment complete
- "Day X+1 unlocks at 5 AM" message
- Green checkmark styling on completed tasks

#### 3. Watch Sync Improvements

**Settings (`SettingsView.swift`):**
- New "Sync" section with:
  - "Sync from Cloud" button - manual refresh from Convex
  - "Login as user3" button - dev auto-login for simulator testing
  - Shows current logged-in username and day

**Auto-Login (`WatchConvexService.swift`):**
- Watch auto-logs in as user3 on launch if not authenticated
- Enables simulator testing without manual login

### Key Files Modified
- `/convex/schema.ts` - Added `questionnaire_session` table
- `/convex/watch.ts` - Question progress sync functions
- `/ZoeSleep/ZoeSleep/Services/ConvexService.swift` - iOS sync methods
- `/ZoeSleep/ZoeSleep/Views/QuestionnaireView.swift` - Progress load/save
- `/ZoeSleep/ZoeSleep/ContentView.swift` - Day completion UI
- `/ZoeSleep/ZoeSleep Watch App/WatchConvexService.swift` - Watch sync methods
- `/ZoeSleep/ZoeSleep Watch App/QuestionnaireView.swift` - Watch progress sync
- `/ZoeSleep/ZoeSleep Watch App/WatchHomeView.swift` - Celebration card
- `/ZoeSleep/ZoeSleep Watch App/SettingsView.swift` - Sync controls
- `/client/src/lib/convexService.ts` - NEW: Web Convex HTTP client
- `/client/src/app/journey/page.tsx` - Web progress sync

### Cross-Device Sync Flow
1. User starts questionnaire on iPhone, answers 3 questions
2. Progress synced to Convex: `{ section: "sleepLog", currentQuestionIndex: 2 }`
3. User opens Watch app, starts Sleep Log
4. Watch fetches progress, resumes at question 3
5. User answers 2 more questions on Watch
6. User opens Web app, continues from question 5

### Testing Notes
- All devices must use same user account (user3 for simulators)
- Watch auto-logs in as user3 for simulator testing
- Debug mode allows instant day advancement
- Normal mode shows 5 AM unlock countdown

---

## Previous Session Context (2025-12-01 - Earlier)

**Smart Default Times for Time Pickers & Shared Question Bank**

This session implemented intelligent default values for time pickers and number inputs across iOS and watchOS, and created a shared question bank for cross-platform consistency.

### Smart Default Times

**Problem:** Time pickers were defaulting to the current time (e.g., 5:13 PM), which is unrealistic for questions like "What time did you fall asleep last night?"

**Solution:** Implemented smart defaults based on question context:

| Question | iOS Default | Watch Default |
|----------|-------------|---------------|
| Bedtime (SL_BEDTIME) | 10:00 PM | 10:00 PM |
| Fall Asleep (SL_ASLEEP_TIME) | 10:30 PM | 10:30 PM |
| Wake Time (SL_WAKE_TIME) | 7:00 AM | 7:00 AM |
| PSQI Bedtime (PSQI_1) | 10:30 PM | - |
| PSQI Wake Time (PSQI_3) | 7:00 AM | - |

**Smart Number Defaults:**
- Age: 35 years (median adult)
- Height: 170 cm (average)
- Weight: 70 kg (average)
- Night Awakenings: 1
- Sleep Latency: 15 minutes
- Sleep Hours: 7 hours

**Scale Defaults:**
- Sleep Quality: 6/10 (neutral-positive)
- Stress Level: 5/10 (moderate)
- Pain Level: 2/10 (low/optimistic)

### Apple Watch Time Picker Redesign

**Problem:** Watch time picker showed 24-hour format (17:25) with redundant time display above.

**Solution:** Completely redesigned with:
- 12-hour format (1-12) with separate AM/PM picker wheel
- Removed redundant time display at top
- Smart defaults based on question ID
- Compact layout optimized for small watch screens

### Shared Question Bank

Created `/ZoeSleep/Shared/SharedQuestionBank.swift`:
- Single source of truth for all questions (iOS + Watch)
- Stanford Sleep Log questions with proper IDs
- Day-specific assessment questions (Days 1-15)
- Consistent question IDs across platforms

### Files Modified
- `/ZoeSleep/ZoeSleep/Views/QuestionComponents.swift` - iOS smart defaults for TimeInput, NumberInput, ScaleInput
- `/ZoeSleep/ZoeSleep Watch App/QuestionnaireView.swift` - Watch WatchTimePickerView redesign, WatchQuestionBank uses SharedQuestionBank
- `/ZoeSleep/ZoeSleep Watch App/WatchConvexService.swift` - Fixed null response handling to prevent crashes
- `/ZoeSleep/Shared/SharedQuestionBank.swift` - NEW: Shared question definitions

### Web Client Changes (also updated)
- `/client/src/components/questions/types.ts` - Added questionKey and defaultValue to configs
- `/client/src/components/questions/TimePicker.tsx` - Smart time defaults
- `/client/src/components/questions/NumberInput.tsx` - Smart number defaults
- `/client/src/components/questions/SliderScale.tsx` - Smart scale defaults
- `/client/src/app/journey/page.tsx` - Pass questionKey to config builders

- **Commit Hash:** `25ad5ae` - "Implement smart default times for time pickers and shared question bank"
- **Repository:** Successfully pushed to https://github.com/CavalPinarello/15-day-Intake.git

---

## Previous Session Context (2025-12-01)

**Animated Circadian Wave Background & Splash Screen**

This session implemented animated flowing wave backgrounds inspired by EEG/circadian rhythms, similar to Apple Watch sleep tracking visuals.

### Features Implemented

1. **CircadianWaveBackground (`/ZoeSleep/ZoeSleep/Views/CircadianWaveBackground.swift`)**
   - Multiple layers of animated sine waves flowing horizontally
   - Configurable amplitude, frequency, speed, and opacity per wave layer
   - Dark/light mode aware with appropriate color schemes
   - Respects `reduceMotion` accessibility setting
   - View modifier `.circadianWaveBackground()` for easy application

2. **SplashScreenView (`/ZoeSleep/ZoeSleep/Views/SplashScreenView.swift`)**
   - Full-screen animated splash screen on app launch
   - Deep navy (#0F172A) background with flowing teal waves
   - Animated vector logo with three layered circadian waves
   - Subtle amber energy orb accent
   - "Zoe Sleep" branding with tagline fade-in
   - Smooth 2.5-second animation then fade transition to main app

3. **Background Integration**
   - `MainDashboardView` - Subtle wave background (intensity: 0.7)
   - `QuestionnaireView` - Subtle wave background (intensity: 0.5)
   - Both views now feature gentle animated waves behind content

4. **Launch Screen Update**
   - Removed static `LaunchIcon` image from Info.plist
   - iOS system launch shows only deep navy background
   - SwiftUI animated splash takes over immediately

### New Files Created
- `/ZoeSleep/ZoeSleep/Views/CircadianWaveBackground.swift` - Wave animation components
- `/ZoeSleep/ZoeSleep/Views/SplashScreenView.swift` - Animated splash screen

### Files Modified
- `/ZoeSleep/ZoeSleep/ZoeSleepApp.swift` - Added `SplashScreenWrapper`
- `/ZoeSleep/ZoeSleep/ContentView.swift` - Added wave background to dashboard
- `/ZoeSleep/ZoeSleep/Views/QuestionnaireView.swift` - Added wave background
- `/ZoeSleep/ZoeSleep/Info.plist` - Removed static launch icon
- `/ZoeSleep/ZoeSleep.xcodeproj/project.pbxproj` - Added new Swift files

### Design Philosophy
- Subtle, non-distracting animated waves evoke EEG/circadian rhythms
- Waves flow continuously but gently (not hyperactive)
- Colors match the teal (#4ECDC4) circadian theme
- Accessibility-first: animations disable with reduceMotion

---

## Previous Session Context (2025-11-28)

**Cross-Device Sync: Watch ↔ iPhone ↔ Web via Convex**

This session implemented real-time questionnaire sync between Apple Watch, iPhone, and Web applications.

### Problem
- Watch and iPhone apps weren't syncing questionnaire progress
- Watch was using a different password hash format than the database
- Completing questions on one device wasn't reflected on others

### Solution Implemented

1. **Watch Authentication Fixed (`/convex/watch.ts`)**
   - Updated `signIn` mutation to accept multiple hash formats
   - Accepts both SHA256 and simple hash ("31") for development flexibility
   - Watch can now authenticate with test users (user1-user10, password: "1")

2. **Watch Auto-Login (`/ZoeSleep/ZoeSleep Watch App/WatchConvexService.swift`)**
   - Added development mode with configurable test user
   - Set `devTestUsername = "user3"` and `devTestPassword = "1"`
   - Watch auto-logs in as same user as iPhone for testing
   - Added CryptoKit import for SHA256 hashing

3. **iPhone Sync Button (`/ZoeSleep/ZoeSleep/ContentView.swift`)**
   - Added manual sync button (circular arrows icon) in header
   - Triggers `loadJourneyProgress()` to fetch latest state from Convex
   - Logs sync status: `[iOS] Synced from Convex: Day X`

4. **Real-time State Refresh**
   - Watch refreshes from Convex on app activation via `scenePhase`
   - iPhone refreshes via pull-to-refresh and sync button
   - Both apps read from same Convex `user.current_day` field

### Key Files Modified
- `/convex/watch.ts` - Multi-format password hash support
- `/ZoeSleep/ZoeSleep Watch App/WatchConvexService.swift` - Dev auto-login, SHA256 hashing
- `/ZoeSleep/ZoeSleep Watch App/ZoeSleep_Watch_AppApp.swift` - Simplified refresh logic
- `/ZoeSleep/ZoeSleep/ContentView.swift` - Added sync button
- `/ZoeSleep/ZoeSleep/ZoeSleep.entitlements` - App Group capability (for future use)
- `/ZoeSleep/ZoeSleep Watch App/ZoeSleep Watch App.entitlements` - App Group capability

### Testing Cross-Device Sync
1. Log into iPhone as `user3` (password: `1`)
2. Watch auto-logs in as `user3`
3. Complete questions on either device
4. Tap sync button on iPhone or switch tabs on Watch to refresh
5. Both devices should show same day number

### Known Limitations
- Simulators can't use WatchConnectivity (no real-time push between devices)
- App Groups require Apple Developer Program for production
- For development, both apps use hardcoded test user for reliable sync

---

**REBRANDING: Sleep360 → Zoe Sleep** (Commit: `5741d9f`)

The project has been rebranded from "Sleep360" to "Zoe Sleep" with the tagline "Sleep Better, Live Longer".

### Changes Made:
- **New Xcode Project:** `/ZoeSleep/ZoeSleep.xcodeproj` (replaces Sleep360)
- **iOS App:** `ZoeSleepApp.swift` with bundle ID `com.zoesleep.app`
- **Watch App:** `ZoeSleep_Watch_AppApp.swift` with bundle ID `com.zoesleep.app.watchkitapp`
- **Display Name:** "Zoe Sleep" (shown on home screen)
- **Build Verified:** Both iOS and watchOS targets build successfully

### Archived (Do Not Use):
- `/Sleep360/` - Old project folder (archived for reference)
- `/Sleep360/Sleep360.xcodeproj` - Old Xcode project
- `/Sleep360/Zoé Sleep.xcodeproj` - Partial migration attempt

---

**Theme System Fix: Global Theme & Accent Color Propagation**

This session fixed critical issues with the theme system where theme and accent color changes weren't propagating globally throughout the iOS app and to the Apple Watch.

### Problem
- Theme selections (System, Light, Dark, Circadian) in Settings weren't applying app-wide
- Accent color changes (Teal, Coral, Violet, Gold) only worked on Settings page
- Theme changes weren't syncing to Apple Watch

### Root Cause Analysis
1. **`@AppStorage` in `ObservableObject` doesn't trigger `objectWillChange`** - This is a known SwiftUI limitation where `@AppStorage` properties inside an `ObservableObject` class don't automatically notify observers of changes
2. **Missing iOS `WatchConnectivityManager.swift`** - File existed on disk but wasn't added to Xcode project
3. **Missing `WatchThemeManager.swift` in Watch project** - Created but not included in build

### Technical Solution
1. **ThemeManager.swift Rewrite:**
   - Changed from `@AppStorage` to `@Published` properties with manual UserDefaults sync in `didSet`
   - This ensures `objectWillChange` is triggered on every property change
   ```swift
   @Published var appearanceMode: AppearanceMode = .system {
       didSet {
           UserDefaults.standard.set(appearanceMode.rawValue, forKey: "colorTheme")
       }
   }
   ```

2. **Sleep360App.swift - ThemedRootView Wrapper:**
   - Added `ThemedRootView` wrapper that observes ThemeManager with `@ObservedObject`
   - Applies `.preferredColorScheme()` and `.tint()` modifiers at root level
   - Uses `.onChange()` to trigger theme sync to Watch

3. **SettingsView.swift - Standard Picker Controls:**
   - Changed from custom Button implementations to standard SwiftUI `Picker` controls
   - Direct binding with `$themeManager.appearanceMode` and `$themeManager.accentColorOption`

4. **Xcode Project Fixes:**
   - Added `WatchConnectivityManager.swift` to iOS Managers group and Sources build phase
   - Added `WatchThemeManager.swift` to Watch App Sources build phase
   - New unique IDs: `4A5E3BE22C8E123456789D03`, `4A5E3BE32C8E123456789D04`

### Key Files Modified
- **iOS:**
  - `/Sleep360/Sleep360/Managers/ThemeManager.swift` - Major rewrite (134 lines changed)
  - `/Sleep360/Sleep360/Sleep360App.swift` - Added ThemedRootView wrapper
  - `/Sleep360/Sleep360/Views/SettingsView.swift` - Standard Picker controls
  - `/Sleep360/Sleep360/Managers/WatchConnectivityManager.swift` - Added to project (NEW)
  - `/Sleep360/Sleep360/Models/QuestionModels.swift` - ColorTheme supports accent colors
- **watchOS:**
  - `/Sleep360/Sleep360 Watch App/WatchThemeManager.swift` - Theme manager for Watch (NEW)
  - `/Sleep360/Sleep360 Watch App/SettingsView.swift` - Theme display and settings
  - `/Sleep360/Sleep360 Watch App/WatchConnectivityManager.swift` - Theme sync handling
  - `/Sleep360/Sleep360 Watch App/TreatmentTasksView.swift` - Theme integration
- **Project:**
  - `/Sleep360/Sleep360.xcodeproj/project.pbxproj` - Added missing file references

### Build Verification
- ✅ iOS app builds successfully
- ✅ watchOS app builds successfully
- Theme changes now propagate globally

- **Commit Hash:** `1d3ee79` - "Fix theme system: global propagation and Watch sync"
- **Repository:** https://github.com/CavalPinarello/15-day-Intake.git
- **Session Log:** `/docs/sessions/theme-system-fix-2025-11-28.md`

---

**Previous Session (2025-11-26):**

**MAJOR UPDATE: Complete Physician Dashboard & Treatment Mode Implementation**

This session completed Phases 3-6 of the Zoe Sleep system, implementing:

### Phase 3: Consumer App Clarity (Sleep Log vs Assessment)
- **Section Differentiation:** Clear visual separation between Stanford Sleep Log (blue #2196F3) and Day Assessment (purple #9C27B0)
- **iOS Files:**
  - `/Sleep360/Sleep360/Views/QuestionnaireSections.swift` - QuestionnaireSection enum, SectionHeaderView, SectionProgressView
  - Updated QuestionnaireView.swift with section-based flow
- **watchOS Files:**
  - `/Sleep360/Sleep360 Watch App/SleepLogView.swift` - WatchSectionColors enum, SleepLogCard, DayAssessmentCard

### Phase 4: Full Rebranding (Circadian Wave Icons - NO moon/stars)
- **New Icon Design:** Elegant circadian wave theme replacing previous moon/stars
  - Deep navy (#0F172A) to teal (#145360) gradient background
  - Flowing sine waves representing circadian rhythms
  - Teal (#14B8A6) with glowing wave effects
  - Subtle amber energy orb for vitality
- **Icons Generated:** 15 iOS sizes + 17 watchOS sizes + 3 launch screen sizes
- **Launch Screen:** UILaunchScreen with LaunchBackground.colorset and LaunchIcon.imageset
- **Files:**
  - `/scripts/generate_app_icons.py` - Rewritten with circadian wave design
  - `/Sleep360/Sleep360/Assets.xcassets/LaunchBackground.colorset/`
  - `/Sleep360/Sleep360/Assets.xcassets/LaunchIcon.imageset/`

### Phase 5: Physician Dashboard (Complete Web Implementation)
- **Main Dashboard** (`/client/src/app/physician-dashboard/page.tsx`):
  - Patient list with status badges (In Progress, Pending Review, Under Review, Interventions Ready, Active Treatment)
  - Status filter chips with counts, search functionality
  - Progress bars and last activity timestamps
- **Patient Detail** (`/client/src/app/physician-dashboard/patient/[id]/page.tsx`):
  - Overview tab with AI analysis (GPT-4o integration), demographics
  - Responses tab with day-by-day viewer
  - Scores tab for questionnaire scores (ISI, PSQI, ESS)
  - Interventions tab for active treatments
  - Notes tab for physician annotations
- **Prescription Builder** (`/client/src/app/physician-dashboard/patient/[id]/prescription/page.tsx`):
  - Intervention library with search and categories
  - Configure start/end dates, frequency, timing
  - Custom instructions per intervention
  - Save as draft or activate immediately
- **Question Manager** (`/client/src/app/physician-dashboard/questions/page.tsx`):
  - Three views: By Day, By Module, All Questions
  - Search and filter, expandable sections, inline editing
- **Settings** (`/client/src/app/physician-dashboard/settings/page.tsx`):
  - Profile, notifications, appearance, security

### Phase 6: Treatment Mode (Post-Intake Tasks)
- **Convex Backend** (`/convex/treatment.ts`):
  - `getActiveInterventions`, `getTodayTasksSummary`, `getComplianceHistory`
  - `getTreatmentPhase`, `getWatchTasks`, `getTaskNotes`
  - `completeTask`, `uncompleteTask`, `addTaskNote`, `watchCompleteTask`
- **Web Treatment** (`/client/src/app/treatment/page.tsx`):
  - Progress card with percentage and celebration animation
  - Tasks grouped by time of day with checkboxes
  - 7-day streak chart visualization
  - Note modal for reflections
- **iOS Treatment** (`/Sleep360/Sleep360/Views/TreatmentView.swift`):
  - Native SwiftUI with progress bar animation
  - Tasks organized by timing with color-coded icons
  - Weekly streak visualization, note sheet
- **watchOS Treatment** (`/Sleep360/Sleep360 Watch App/TreatmentTasksView.swift`):
  - Optimized for all watch sizes (40mm-49mm Ultra)
  - Compact progress header, simplified task rows
  - Quick tap completion with haptic feedback
  - Treatment tab in main navigation

### Key Files Summary:
- **Convex:** `/convex/treatment.ts` (NEW)
- **Web:** 6 new pages in `/client/src/app/physician-dashboard/` and `/client/src/app/treatment/`
- **iOS:** `/Sleep360/Sleep360/Views/TreatmentView.swift`, `QuestionnaireSections.swift`, `SettingsView.swift`, `ThemeManager.swift`
- **watchOS:** `/Sleep360/Sleep360 Watch App/TreatmentTasksView.swift`, `SleepLogView.swift`, `WatchQuestionComponents.swift`, `SettingsView.swift`
- **Icons:** Updated all app icons with circadian wave design

- **Commit Hash:** `23a759f` - "Implement Phases 3-6: Section clarity, rebranding, physician dashboard, and treatment mode"
- **Repository:** https://github.com/CavalPinarello/15-day-Intake.git

---

**Previous Session (2025-11-26):**

**Zoé Sleep App Icon Design:**
- **App Branding:** Designed and implemented professional app icons for "Zoé Sleep" brand
- **Icon Design Elements:**
  - Deep indigo (#2D1B5C) to rich purple (#58378F) vertical gradient background
  - White crescent moon symbol (universal sleep iconography)
  - Soft blue (#93C5FD) cascading "Zzz" accent (representing "Zoé" and sleep)
  - Subtle twinkling stars for night-sky ambiance
- **iOS App Icons Generated:** 15 sizes covering all requirements
  - iPhone: 20x20@2x/3x, 29x29@2x/3x, 40x40@2x/3x, 60x60@2x/3x
  - iPad: 20x20@1x/2x, 29x29@1x/2x, 40x40@1x/2x, 76x76@1x/2x, 83.5x83.5@2x
  - App Store: 1024x1024
- **watchOS App Icons Generated:** 17 sizes for all Apple Watch models
  - Notification Center: 24x24@2x (38mm), 27.5x27.5@2x (42mm), 33x33@2x (45mm)
  - Companion Settings: 29x29@2x/3x
  - App Launcher: 40-54mm sizes for all watch models (38mm to 49mm Ultra)
  - Quick Look: 86-129mm sizes for all watch models
  - Watch Marketing: 1024x1024
- **Reusable Icon Generator:** Created Python script for future icon updates
  - Location: `/scripts/generate_app_icons.py`
  - Uses Pillow library for image generation
  - Run with: `source .venv/bin/activate && python3 scripts/generate_app_icons.py`
- **Key Files Created/Modified:**
  - `/scripts/generate_app_icons.py` - Icon generation script
  - `/docs/zoe-sleep-icon-preview.png` - 512x512 preview image
  - `/Sleep360/Sleep360/Assets.xcassets/AppIcon.appiconset/` - All iOS icons
  - `/Sleep360/Sleep360 Watch App/Assets.xcassets/AppIcon.appiconset/` - All watchOS icons
- **Session Goal:** Create professional app icons for Zoé Sleep iOS and watchOS apps
- **Commit Hash:** `a08082f` - "Add Zoé Sleep app icons for iOS and watchOS"
- **Repository:** https://github.com/CavalPinarello/15-day-Intake.git

**Previous Session (2025-11-26):**

**iOS Convex Direct Integration Refactor:**
- **Major Architecture Change:** Refactored iOS app to use direct Convex HTTP API calls
- **ConvexService.swift Overhaul:**
  - Replaced ConvexMobile SDK with custom `ConvexHTTPClient` using URLSession
  - HTTP-based communication with Convex backend via `/api/query` and `/api/mutation` endpoints
  - Simplified session management with Keychain storage
  - Removed external SDK dependency for more control over API calls
- **AuthenticationManager Refactor:**
  - Converted from REST API to direct Convex mutations (`ios:signIn`, `ios:signInWithApple`, `ios:register`)
  - Simplified Apple Sign-In flow with Convex backend validation
  - Removed legacy REST API fallback code
  - Cleaner error handling with `ConvexError` types
- **AuthenticationView Simplification:**
  - Streamlined UI with focus on email/password and Apple Sign-In
  - Removed Google Sign-In (requires separate SDK integration)
  - Cleaner form handling and error display
- **QuestionModels.swift Updates:**
  - Minor refinements to data model structures
  - Improved type safety for questionnaire system
- **HealthKitManager Updates:**
  - Minor adjustments to work with new authentication flow
- **Build Cleanup:**
  - Removed Xcode build cache files (XCBuildData attachments)
  - Cleaned up Swift Package Manager resolved file
  - Project structure optimized
- **Key Technical Changes:**
  - Convex HTTP endpoint format: `POST {deploymentUrl}/api/mutation` or `/api/query`
  - Request body: `{ "path": "ios:functionName", "args": {...} }`
  - Response parsing handles Convex's `{ "value": ... }` wrapper
  - Ephemeral URLSession configuration for clean connection handling
- **Key Files Modified:**
  - `/Sleep360/Sleep360/Services/ConvexService.swift` - Complete rewrite
  - `/Sleep360/Sleep360/Managers/AuthenticationManager.swift` - Convex integration
  - `/Sleep360/Sleep360/Views/AuthenticationView.swift` - Simplified UI
  - `/Sleep360/Sleep360/Config.swift` - Added Clerk configuration
- **Session Goal:** Simplify iOS-Convex integration by using direct HTTP calls
- **Commit Hash:** `ad74265` - "Refactor iOS to use direct Convex HTTP API calls"
- **Repository:** https://github.com/CavalPinarello/15-day-Intake.git

**Previous Session (2025-11-25):**

**iOS 15-Day Adaptive Questionnaire Implementation:**
- **Complete Questionnaire System:** Implemented full 15-day adaptive questionnaire in iOS app
- **New iOS Files Created:**
  - `/Sleep360/Sleep360/Models/QuestionModels.swift` - Data models for questions, responses, gateways
  - `/Sleep360/Sleep360/Managers/QuestionnaireManager.swift` - Questionnaire logic with gateway evaluation
  - `/Sleep360/Sleep360/Views/QuestionComponents.swift` - Reusable UI components for 12 question types
  - `/Sleep360/Sleep360/Views/QuestionnaireView.swift` - Complete questionnaire interface
- **Gateway System Implementation:**
  - 10 gateway types: insomnia, depression, anxiety, excessive sleepiness, cognitive, OSA, pain, sleep timing, diet impact, poor sleep quality
  - Dynamic expansion: Days 6-15 questions load based on gateway triggers from Days 1-5
  - Validated instruments: ISI, DBAS-16, ESS, PHQ-9, GAD-7, STOP-BANG, Berlin, BPI, MEDAS, MEQ
- **Stanford Sleep Log:** 5 daily questions capturing subjective sleep perception (asked every day)
- **HealthKit Integration:**
  - Shows Apple Health sleep data for comparison with user's subjective perception
  - Auto-fetches previous night's sleep metrics (total sleep, efficiency, awakenings)
- **Core Foundation (Days 1-5):**
  - Demographics, PSQI, sleep patterns, mental health screening, physical health, nutrition
  - Gateway questions embedded to trigger personalized expansion
- **UI Components:**
  - ScaleInput, YesNoInput, SingleSelectInput, MultiSelectInput, NumberInput, TimeInput
  - QuestionCard with pillar color coding and help text
  - Progress header with day/question tracking
  - Gateway alert banners showing triggered assessments
- **Updated Dashboard:**
  - Journey progress visualization with 15-day circular indicator
  - Today's tasks card showing Stanford Sleep Log + Day assessment
  - Gateway status card displaying triggered personalized assessments
  - Journey overview sheet with all 15 days and estimated times
- **Convex Integration:** Uses existing iOS Convex functions for response syncing
- **Key Files Modified:**
  - `/Sleep360/Sleep360/ContentView.swift` - Complete dashboard redesign
- **Session Goal:** Port web questionnaire system to iOS with full gateway logic
- **Commit Hash:** `7f6ee45` - "Implement iOS 15-day adaptive questionnaire system with gateway logic"
- **Repository:** Successfully pushed to https://github.com/CavalPinarello/15-day-Intake.git
- **Session Log:** `/docs/sessions/ios-questionnaire-implementation-2025-11-25.md`

**Previous Session (2025-11-25):**
**iOS Authentication & Networking Fixes Session:**
- **Fixed iOS Simulator Connection Issues:** Resolved NSURLError -1005 "network connection was lost" errors
  - Changed URLSession configuration from `.default` to `.ephemeral` to avoid connection caching
  - Added retry logic (3 attempts with 500ms delay) for transient connection errors
  - Set `httpMaximumConnectionsPerHost = 1` to prevent connection reuse issues
  - Added `Connection: close` header to force fresh connections
- **Fixed Authentication State Sharing:**
  - Changed `HealthKitIntegrationView` from `@StateObject` to `@EnvironmentObject` for `authManager`
  - This ensures the view shares the same auth state as the rest of the app
  - Fixed "Not authenticated" error when syncing health data
- **Fixed Server Response Parsing:**
  - Server returns `"success": 1` (integer) but code expected `Bool`
  - Updated `AuthenticationManager.signIn()` to handle both `Int` and `Bool` success values
- **Fixed HealthKitManager Auth Token Access:**
  - Updated `Sleep360App.swift` to pass `authManager` to `HealthKitManager` during initialization
  - `HealthKitManager` can now retrieve auth tokens for API sync calls
- **iOS Simulator Networking Notes:**
  - Use `127.0.0.1` instead of `localhost` for simulator
  - ATS exceptions configured for local development in Info.plist
  - Server must be running on port 3001 for authentication
- **Test Credentials:** user1-user10, password: "1" (verified working)
- **Key Files Modified:**
  - `/Sleep360/Sleep360/Services/APIService.swift` - Ephemeral session, retry logic
  - `/Sleep360/Sleep360/Managers/AuthenticationManager.swift` - Success field parsing
  - `/Sleep360/Sleep360/Views/HealthKitIntegrationView.swift` - EnvironmentObject usage
  - `/Sleep360/Sleep360/Sleep360App.swift` - AuthManager injection
  - `/Sleep360/Sleep360/ContentView.swift` - Preview updates
- **Commit Hash:** `800b71a` - "Document iOS authentication and networking fixes in CLAUDE.md"
- **Repository:** https://github.com/CavalPinarello/15-day-Intake.git

**Previous Session (2025-11-25):**
**iOS-Dedicated Convex Database Integration:**
- **New iOS Backend:** Created dedicated Convex database infrastructure for iOS app
- **Schema Updates:** Added 7 new iOS-specific tables to `convex/schema.ts`:
  - `ios_devices` - Device registration for APNs push notifications
  - `ios_sessions` - Session management with device linking
  - `apple_sign_in` - Apple Sign-In data storage
  - `ios_app_events` - App analytics and event tracking
  - `ios_healthkit_sync` - HealthKit sync status tracking
  - `ios_notifications` - Push notification history
  - `ios_watch_sync` - iPhone-Watch sync state
- **New Convex Functions:** Created `convex/ios.ts` with 19 iOS-specific functions:
  - Authentication: `signIn`, `signInWithApple`, `register`, `validateSession`, `signOut`, `refreshSession`
  - User Profile: `getUserProfile`, `updateUserProfile`, `updateUserPreferences`
  - HealthKit: `syncSleepData`, `syncHeartRateData`, `syncActivityData`, `getRecentSleepData`
  - Journey: `getDayQuestionnaire`, `submitQuestionnaireResponse`, `completeDay`, `getJourneyProgress`
  - Device/Analytics: `registerPushToken`, `trackEvent`
- **iOS Swift Integration:** Created `ConvexService.swift` using official ConvexMobile SDK
  - Real-time subscriptions via Combine publishers
  - Keychain-based secure session storage
  - Type-safe Codable data models
- **Convex Swift Package:** Installed `convex-swift` v0.6.1+ in Xcode project
- **Configuration:** Updated `Config.swift` with Convex deployment URL
- **Deployment URL:** `https://enchanted-terrier-633.convex.cloud`
- **Key Files:**
  - `/convex/schema.ts` - Updated with iOS tables
  - `/convex/ios.ts` - New iOS-specific Convex functions
  - `/Sleep360/Sleep360/Services/ConvexService.swift` - New Swift service
  - `/Sleep360/Sleep360/Config.swift` - Updated with Convex config
- **Commit Hash:** `6ea312b` - "Implement iOS-dedicated Convex database with Swift SDK integration"
- **Repository:** Successfully pushed to https://github.com/CavalPinarello/15-day-Intake.git
- **Session Log:** `/docs/sessions/ios-convex-integration-2025-11-25.md`

**Previous Session (2025-11-25 - Earlier):**
**Platform Focus Clarification Session:**
- **Clarified Development Priorities:** iOS and watchOS are the PRIMARY user-facing applications
- **Web App Role Defined:** Web version exists ONLY for debugging questionnaires and development testing
- **Commit Hash:** `776d896` - "Clarify platform focus: iOS/watchOS primary, web for debug only"

**Previous Session (2025-11-25 - Even Earlier):**
**Xcode watchOS Target Configuration:**
- **Added watchOS Target:** Successfully configured Apple Watch target in existing Xcode project
  - Created `Sleep360 Watch App` target with proper bundle ID `com.sleep360.app.watchkitapp`
  - Integrated all watchOS Swift files from `/Sleep360 Watch App/` directory into Xcode project structure
  - Fixed Xcode project.pbxproj configuration for dual iOS/watchOS targets
  - Resolved build conflicts and duplicate file reference errors
  - **Both Targets Available:** iOS (Sleep360) and watchOS (Sleep360 Watch App)
- **Build Configuration Fixes:**
  - Fixed "Multiple commands produce" build errors
  - Resolved CopyAndPreserveArchs configuration issues  
  - Cleaned up scheme configuration for both targets
  - Optimized architecture settings (arm64 for watchOS)
- **Project Status:** 
  - ✅ iOS target builds successfully
  - ⚠️ watchOS target configured but may need Xcode IDE for final build resolution
  - Both targets visible in Xcode with proper scheme selection
- **Files Integrated:** All 5 watchOS Swift files properly linked to watchOS target
- **Next Steps:** Open in Xcode IDE to resolve any remaining watchOS build system conflicts
- **Commit Hash:** `e5719ab` - "Integrate watchOS target into Xcode project with build fixes"
- **Repository:** Successfully pushed to https://github.com/CavalPinarello/15-day-Intake.git
- **Session Log:** `/docs/sessions/watchos-xcode-integration-2025-11-25.md`

**Previous Session (2025-11-21 - Afternoon):**
**Xcode Project Creation:**
- **Created iOS App Structure:** Complete Xcode project at `/Sleep360/Sleep360.xcodeproj`
  - Project.pbxproj with proper build settings and targets
  - Info.plist with HealthKit permissions and app configuration
  - Entitlements file for HealthKit capabilities
  - Organized folder structure (Managers, Views, Services)
  - Asset catalogs for app icon and colors
- **Fixed Clerk Middleware:** Updated authentication middleware for Next.js compatibility
  - Changed from `auth().protect()` to `await auth.protect()` syntax
- **Project Files Created:**
  - `Sleep360App.swift` - Main app entry point with SwiftUI
  - `ContentView.swift` - Main UI with dashboard and navigation
  - Complete project configuration files
- **Project Location:** `/Users/martinkawalski/Documents/GitHub/15-day-Intake/Sleep360/`
- **Commit Hash:** `867219f` - "Create Xcode project and fix Clerk middleware"
- **Repository:** Successfully pushed to https://github.com/CavalPinarello/15-day-Intake.git
- **Session Log:** `/docs/sessions/xcode-project-creation-2025-11-21.md`

**Previous Sessions:**
- Apple Watch Integration (commit `f92b918`)
- Clerk Authentication Integration (commit `1ded787`)
- Optimization Session (commit `79f0032`) - 75% CLAUDE.md reduction