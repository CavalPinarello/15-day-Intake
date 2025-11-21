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

# Database setup (SQLite mode)
cd server && npm run seed

# Database setup (Convex mode) 
npx convex dev && ./setup-convex.sh
```

## Critical Settings

**Database Mode:** Set `USE_CONVEX=true` in `/server/.env` for cloud mode (default: SQLite)

**Test Credentials:** user1-user10, password: "1"

## Key File Locations

**iOS Application:**
- **iOS Files:** `/ios/` (Swift configuration and HealthKit integration)
- **API Config:** `/ios/Config.swift` (API endpoints for iOS)
- **Watch Sync:** `/ios/WatchConnectivityManager.swift` (iPhone-Watch communication)

**Apple Watch Application:**
- **Watch Files:** `/watchos/` (watchOS-optimized questionnaire and recommendations)
- **Main App:** `/watchos/WatchApp.swift` (Watch app interface)
- **Questionnaire:** `/watchos/QuestionnaireView.swift` (Watch-optimized UI)
- **Recommendations:** `/watchos/RecommendationsView.swift` (Physician recommendations)

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
- **New watchOS Files:** Created complete Apple Watch application structure
- **Documentation Updates:** Updated all architecture docs to reflect multi-platform design
- **Session Goal:** Enable 15-day intake completion on Apple Watch with physician recommendations

**Previous Sessions:**
- Clerk Authentication Integration (commit `1ded787`)
- Optimization Session (commit `79f0032`) - 75% CLAUDE.md reduction