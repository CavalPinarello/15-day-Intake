# CLAUDE.md

This file provides essential guidance to Claude Code when working with the **Zoe Sleep** repository.

## Brand & Product

**Product Name:** Zoe Sleep
**Tagline:** "Sleep Better, Live Longer"
**Design Theme:** Elegant circadian waves (NO moon/stars clichés) - abstract waveforms, gradient flows

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

## Latest Session Context (2025-11-28)

**REBRANDING: Sleep360 → Zoe Sleep**

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