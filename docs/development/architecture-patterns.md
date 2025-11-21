# Architecture Patterns

Key architectural patterns and conventions used in this sleep coaching platform.

## Database Abstraction Pattern

**Dual Database Support:**
- Environment variable `USE_CONVEX=true` switches between SQLite and Convex
- Convex functions in `/convex/` directory provide queries, mutations, and actions
- Server routes in `/server/routes/` provide REST API endpoints

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

**Schema & Database:**
- `/convex/schema.ts` - Complete database schema (30+ tables)
- `/server/database/` - SQLite database adapters and initialization
- `/convex/*.ts` - Convex database functions (queries, mutations)

**API Routes:**
- `/server/routes/` - All REST API endpoints
- `/server/server.js` - Main Express server configuration

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

**Backend:**
- Node.js + Express.js REST API
- Dual database support: SQLite (local) / Convex (cloud)
- JWT authentication with hard-coded test users (user1-user10, password: "1")
- Security middleware: Helmet, CORS, rate limiting

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
- Next.js 14 with App Router (when client exists)
- TypeScript support
- Tailwind CSS for styling