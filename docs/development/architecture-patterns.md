# Architecture Patterns

Key architectural patterns and conventions used in this sleep coaching platform.

## Platform Architecture

**Primary User Applications (iOS & watchOS):**
- **iOS Application** (PRIMARY): Main user-facing app for the 15-day intake journey with Swift/SwiftUI
- **Apple Watch Application**: Companion app with watch-optimized questionnaire experience
- **Cross-device Synchronization**: WatchConnectivity for seamless iPhone-Watch integration

**Development & Backend:**
- **Web Application** (DEV/DEBUG ONLY): Used for debugging questionnaires and development testing - NOT for end users
- **Convex Backend**: Serverless backend providing real-time data synchronization

**Development Focus:** iOS and watchOS applications are the priority. Web exists solely for questionnaire debugging.

## Convex Backend Pattern

**Serverless Architecture:**
- Convex functions provide queries, mutations, and actions
- Real-time data synchronization between iOS and web platforms
- Built-in authentication integration with Clerk
- TypeScript-first development with automatic type generation

## Question System Architecture

**Flexible Question Types:**
- 9 supported types: text, textarea, number, select, radio, checkbox, scale, date, time
- Conditional logic support via JSON configuration
- Gateway system for dynamic module triggering
- Assessment questions with 9 different answer formats

## Security Architecture

**Security Features:**
- Rate limiting on all endpoints (stricter for auth)
- Helmet for security headers
- CORS configuration
- JWT token authentication

## File Organization Patterns

**Critical File Locations:**

**Xcode Project Structure:**
- `/Sleep360/Sleep360.xcodeproj` - Main Xcode project with dual iOS/watchOS targets

**iOS Application (Xcode Target):**
- `/Sleep360/Sleep360/` - Main iOS app target
- `/Sleep360/Sleep360/Managers/HealthKitManager.swift` - HealthKit integration
- `/Sleep360/Sleep360/Managers/AuthenticationManager.swift` - Authentication handling
- `/Sleep360/Sleep360/Services/APIService.swift` - Backend API integration
- `/Sleep360/Sleep360/Views/` - SwiftUI views and interfaces

**Apple Watch Application (Xcode Target):**
- `/Sleep360/Sleep360 Watch App/` - Main watchOS app target  
- `/Sleep360/Sleep360 Watch App/Sleep360_Watch_AppApp.swift` - Watch app entry point
- `/Sleep360/Sleep360 Watch App/QuestionnaireView.swift` - Watch-optimized UI
- `/Sleep360/Sleep360 Watch App/HealthKitWatchManager.swift` - Watch health data
- `/Sleep360/Sleep360 Watch App/WatchConnectivityManager.swift` - iPhone-Watch sync

**Legacy Reference Files:**
- `/ios/` - Original iOS Swift files (reference, now integrated in Xcode)
- `/watchos/` - Original watch files (reference, now integrated in Xcode)
- `/watchos/RecommendationsView.swift` - Physician recommendations display
- `/watchos/HealthKitWatchManager.swift` - HealthKit for watchOS
- `/watchos/WatchConnectivityManager.swift` - Watch-iPhone synchronization

**Web Application (Development/Debug Only):**
- `/client/` - Next.js for questionnaire debugging and development testing
- `/client/app/physician-dashboard/` - Physician dashboard reference implementation

**Convex Backend:**
- `/convex/schema.ts` - Complete database schema (30+ tables) 
- `/convex/auth.ts` - Authentication functions with Clerk
- `/convex/questions.ts` - Question management queries and mutations
- `/convex/responses.ts` - Response handling functions
- `/convex/physician.ts` - Physician dashboard functions
- `/convex/health.ts` - HealthKit data sync actions (iOS + watchOS)
- `/convex/watch.ts` - Watch connectivity and sync functions
- `/convex/recommendations.ts` - Physician recommendations management

**Scripts & Utilities:**
- `/server/scripts/` - Database seeding and management scripts
- `/scripts/` - Data conversion and testing utilities
- `/data/` - Sample data and question definitions

**Configuration:**
- `/vercel.json` - Vercel deployment configuration
- `/setup-convex.sh` - Convex environment setup script

## Development Conventions

**Important Implementation Notes:**
- Test users (user1-user10) are hard-coded with password "1"
- Day advancement button allows rapid testing of multi-day journey
- Admin interface supports drag-and-drop question reordering
- Physician dashboard integration for patient review workflow
- Assessment system supports complex conditional logic and gateway triggers
- The codebase expects both SQLite and Convex to have identical schemas
- All timestamps are stored as Unix timestamps (numbers)
- JSON fields are stored as strings and require parsing

## Technology Stack Architecture

**Convex Backend:**
- Serverless Convex backend with real-time sync
- Built-in authentication integration with Clerk
- Automatic TypeScript type generation
- Row-level security and real-time subscriptions

**Database Schema:**
- Comprehensive schema supporting 5 major components:
  - Component 1: 14-Day Onboarding Journey
  - Component 2: Daily App Use  
  - Component 3: Full Sleep Report
  - Component 4: Coach Dashboard
  - Component 5: Supporting Systems
- 30+ tables with proper indexing and relationships
- Assessment system with flexible question formats (9 answer types)
- Physician dashboard integration

**Frontend Architecture:**

**iOS Application:**
- Native Swift/SwiftUI implementation
- HealthKit integration for comprehensive health data
- Convex function integration for real-time sync
- WatchConnectivity for iPhone-Watch communication

**Apple Watch Application:**
- watchOS-optimized SwiftUI interface  
- Quick questionnaire completion interface
- Physician recommendations display
- HealthKit integration for watch-based health data
- WatchConnectivity for real-time sync with iPhone

**Web Application (Debug/Dev Only):**
- Next.js 14 with App Router
- TypeScript support
- Tailwind CSS for styling
- Used for questionnaire debugging and development testing - NOT for end users