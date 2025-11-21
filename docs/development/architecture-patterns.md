# Architecture Patterns

Key architectural patterns and conventions used in this sleep coaching platform.

## Platform Architecture

**Hybrid Application Design:**
- **iOS Application**: 15-day intake journey with native Swift/SwiftUI implementation
- **Web Application**: Physician dashboard and administrative interface using Next.js
- **Convex Backend**: Serverless backend providing real-time data synchronization

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

**iOS Application:**
- `/ios/Config.swift` - API endpoints and authentication configuration
- `/ios/HealthKitManager.swift` - HealthKit integration for sleep/activity data
- `/ios/AuthenticationManager.swift` - Authentication handling for iOS

**Web Application:**
- `/client/` - Next.js physician dashboard and admin interface
- `/client/app/physician-dashboard/` - Physician dashboard components

**Convex Backend:**
- `/convex/schema.ts` - Complete database schema (30+ tables) 
- `/convex/auth.ts` - Authentication functions with Clerk
- `/convex/questions.ts` - Question management queries and mutations
- `/convex/responses.ts` - Response handling functions
- `/convex/physician.ts` - Physician dashboard functions
- `/convex/health.ts` - HealthKit data sync actions

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
- HealthKit integration for sleep and activity data
- RESTful API consumption
- Native iOS UI patterns and components

**Web Application:**
- Next.js 14 with App Router
- TypeScript support
- Tailwind CSS for styling
- Focused on physician dashboard and administrative functions