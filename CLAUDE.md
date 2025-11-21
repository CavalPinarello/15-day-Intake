# CLAUDE.md

This file provides essential guidance to Claude Code when working with this sleep coaching platform repository.

## Platform Architecture

**Hybrid Application Design:**
- **iOS Application**: 15-day intake journey with native Swift/SwiftUI implementation
- **Web Application**: Physician dashboard and administrative interface using Next.js  
- **Shared Backend**: Express.js API server supporting both iOS and web clients

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

**Web Application:**
- **Physician Dashboard:** `/client/app/physician-dashboard/`
- **Admin Interface:** `/client/` (Next.js web application)

**Shared Backend:**
- **API Routes:** `/server/routes/` (consumed by both iOS and web)
- **Schema:** `/convex/schema.ts` (30+ tables)
- **Database:** `/server/database/` (SQLite) | `/convex/` (Convex)
- **Documentation:** `/docs/` (organized by category)

## Development Patterns

**Cross-Platform Development:**
- iOS app handles patient intake journey and HealthKit integration
- Web app handles physician dashboard and administrative functions
- Both platforms consume shared REST API from `/server/`

**Common Patterns:**
- Always run `npm run verify-db` after database changes
- Use test users for rapid development/testing
- Day advancement button (web) available for journey testing
- Dual database support: SQLite (local) / Convex (cloud)
- Cross-platform authentication uses shared JWT tokens

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

**Previous Optimization Session:**
- Reduced file size from 213 lines (8KB) to 64 lines (4KB) - 75% reduction
- Moved detailed documentation to organized `/docs/` structure  
- Enhanced README.md with comprehensive architecture details
- Created `/docs/development/` for patterns and command reference
- **Commit Hash:** `79f0032` - "Optimize CLAUDE.md for improved Claude Code performance"