# CLAUDE.md

This file provides essential guidance to Claude Code when working with this sleep coaching platform repository.

## Platform Architecture

**Multi-Platform Application Design:**
- **iOS Application**: 15-day intake journey with comprehensive Swift/SwiftUI implementation
- **Apple Watch Application**: Alternative questionnaire experience with watch-optimized UI
- **Cross-device Sync**: WatchConnectivity for seamless iPhone-Watch integration
- **Web Application**: Physician dashboard and administrative interface using Next.js  
- **Convex Backend**: Serverless backend providing real-time data synchronization across all platforms

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
- **Managers:** `/Sleep360/Sleep360/Managers/` (HealthKitManager, AuthenticationManager)
- **Views:** `/Sleep360/Sleep360/Views/` (SwiftUI views and interfaces)
- **Services:** `/Sleep360/Sleep360/Services/` (APIService for backend integration)

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

**Web Application:**
- **Physician Dashboard:** `/client/app/physician-dashboard/`
- **Admin Interface:** `/client/` (Next.js web application)

**Convex Backend:**
- **Schema:** `/convex/schema.ts` (30+ tables with real-time sync)
- **Functions:** `/convex/` (queries, mutations, actions for all platforms)
- **Watch Functions:** `/convex/watch.ts` (watch connectivity and sync)
- **Recommendations:** `/convex/recommendations.ts` (physician recommendations for watch)
- **Auth:** Clerk authentication integration
- **Documentation:** `/docs/` (organized by category)

## Development Patterns

**Multi-Platform Development:**
- iOS app provides comprehensive patient intake journey and HealthKit integration
- Apple Watch app offers alternative questionnaire interface and receives physician recommendations
- WatchConnectivity enables seamless sync between iPhone and Apple Watch
- Web app handles physician dashboard and administrative functions
- All platforms consume Convex functions with real-time synchronization

**Common Patterns:**
- Convex provides real-time data synchronization across platforms
- Use test users for rapid development/testing
- Day advancement button (web) available for journey testing
- Clerk authentication shared between iOS and web
- TypeScript-first development with automatic type generation

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

## Latest Session Context (2025-11-25)

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