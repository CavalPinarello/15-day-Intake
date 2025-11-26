# CLAUDE.md

This file provides essential guidance to Claude Code when working with this sleep coaching platform repository.

## Platform Architecture

**Primary User Applications (iOS & watchOS):**
- **iOS Application** (PRIMARY): Main user-facing app for the 15-day intake journey with Swift/SwiftUI
- **Apple Watch Application**: Companion app with watch-optimized questionnaire experience
- **Cross-device Sync**: WatchConnectivity for seamless iPhone-Watch integration

**Development & Backend:**
- **Web Application** (DEV/DEBUG ONLY): Used for debugging questionnaires and development testing - NOT for end users
- **Convex Backend**: Serverless backend providing real-time data synchronization

**Development Focus:** iOS and watchOS applications are the priority. Web exists solely for questionnaire debugging.

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
- **Xcode Project:** `/Sleep360/Sleep360.xcodeproj` (Main iOS project)
- **iOS Target:** `/Sleep360/Sleep360/` (Swift/SwiftUI iOS app implementation)
- **Models:** `/Sleep360/Sleep360/Models/` (QuestionModels for questionnaire system)
- **Managers:** `/Sleep360/Sleep360/Managers/` (HealthKitManager, AuthenticationManager, QuestionnaireManager)
- **Views:** `/Sleep360/Sleep360/Views/` (QuestionnaireView, QuestionComponents, ContentView)
- **Services:** `/Sleep360/Sleep360/Services/` (APIService, ConvexService for backend integration)

**Apple Watch Application (Xcode Project):**
- **Watch Target:** `/Sleep360/Sleep360 Watch App/` (watchOS app in Xcode project)
- **Main App:** `/Sleep360/Sleep360 Watch App/Sleep360_Watch_AppApp.swift` (Watch app entry point)
- **Questionnaire:** `/Sleep360/Sleep360 Watch App/QuestionnaireView.swift` (Watch-optimized UI)
- **Recommendations:** `/Sleep360/Sleep360 Watch App/RecommendationsView.swift` (Physician recommendations)
- **Watch HealthKit:** `/Sleep360/Sleep360 Watch App/HealthKitWatchManager.swift` (Watch health data)
- **Watch Connectivity:** `/Sleep360/Sleep360 Watch App/WatchConnectivityManager.swift` (iPhone-Watch sync)

**Legacy Files (Reference):**
- **iOS Reference:** `/ios/` (Original Swift files, now integrated in Xcode project)
- **watchOS Reference:** `/watchos/` (Original watch files, now in Xcode project)

**Web Application (Development/Debug Only):**
- **Question Debug Interface:** `/client/` (Next.js - for questionnaire testing only)
- **Physician Dashboard:** `/client/app/physician-dashboard/` (development reference)

**Convex Backend:**
- **Schema:** `/convex/schema.ts` (30+ tables with real-time sync)
- **Functions:** `/convex/` (queries, mutations, actions for all platforms)
- **Watch Functions:** `/convex/watch.ts` (watch connectivity and sync)
- **Recommendations:** `/convex/recommendations.ts` (physician recommendations for watch)
- **Auth:** Clerk authentication integration
- **Documentation:** `/docs/` (organized by category)

## Development Patterns

**iOS & watchOS Development (Primary Focus):**
- iOS app is the PRIMARY user-facing application for the 15-day intake journey
- Apple Watch app provides companion questionnaire interface and receives physician recommendations
- WatchConnectivity enables seamless sync between iPhone and Apple Watch
- HealthKit integration for comprehensive sleep and health data collection
- Swift/SwiftUI development with Xcode project at `/Sleep360/Sleep360.xcodeproj`

**Web Application (Debug/Development Only):**
- Web version exists ONLY for debugging questionnaire logic and development testing
- NOT intended for end users - all user interaction happens on iOS/watchOS
- Day advancement button available for journey testing
- Useful for rapid questionnaire iteration without rebuilding iOS app

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

## Latest Session Context (2025-11-26)

**iOS Convex Direct Integration Refactor (Current):**
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
- **Commit Hash:** `4a1307d` - "Refactor iOS to use direct Convex HTTP API calls"
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