# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Root Level Commands
```bash
# Install all dependencies for all components
npm run install:all

# Run both server and client concurrently
npm run dev

# Server only
npm run server

# Client only (when client directory exists)
npm run client
```

### Server Commands (run from `/server` directory)
```bash
# Development server with hot reload
npm run dev

# Production server
npm start

# Database commands
npm run seed                    # Initialize database and seed with sample data
npm run reset-users            # Reset test users (user1-user10)
npm run setup-db              # Setup complete database schema
npm run verify-db              # Verify database integrity
```

### Convex Database Commands
```bash
# Initialize and deploy Convex schema
npx convex dev

# Deploy to Convex (from root directory)
npx convex deploy

# Setup local environment for Convex
./setup-convex.sh
```

## Architecture Overview

This is a sleep coaching platform built for rapid prototyping and testing, implementing a 14-day onboarding journey. The architecture supports dual database backends (SQLite for local development, Convex for cloud deployment).

### Technology Stack

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

### Key Architecture Patterns

**Database Abstraction:**
- Environment variable `USE_CONVEX=true` switches between SQLite and Convex
- Convex functions in `/convex/` directory provide queries, mutations, and actions
- Server routes in `/server/routes/` provide REST API endpoints

**Question System:**
- Flexible question types: text, textarea, number, select, radio, checkbox, scale, date, time
- Conditional logic support via JSON configuration
- Gateway system for dynamic module triggering
- Assessment questions with 9 different answer formats

**Security Features:**
- Rate limiting on all endpoints (stricter for auth)
- Helmet for security headers
- CORS configuration
- JWT token authentication

### Critical File Locations

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

## Development Workflow

1. **Database Setup:**
   - For SQLite: `cd server && npm run seed`
   - For Convex: `npx convex dev` then `./setup-convex.sh`

2. **Environment Configuration:**
   - SQLite mode: No `.env` file or `USE_CONVEX=false`
   - Convex mode: Set `USE_CONVEX=true` and `CONVEX_URL` in `/server/.env`

3. **Testing:**
   - Use test users: user1-user10 (password: "1")
   - Admin panel accessible from login page
   - Day advancement feature for rapid testing

4. **Deployment:**
   - Configured for Vercel deployment
   - API routes: `/api/*` → server
   - Static routes: `/*` → client

## Important Notes

- Test users (user1-user10) are hard-coded with password "1"
- Day advancement button allows rapid testing of multi-day journey
- Admin interface supports drag-and-drop question reordering
- Physician dashboard integration for patient review workflow
- Assessment system supports complex conditional logic and gateway triggers
- The codebase expects both SQLite and Convex to have identical schemas
- All timestamps are stored as Unix timestamps (numbers)
- JSON fields are stored as strings and require parsing

## Testing & Validation

The system includes comprehensive validation:
- Database integrity checking via `npm run verify-db`
- Question format validation for 9 different answer types
- User progress tracking and completion validation
- Gateway condition evaluation for dynamic module triggering

## Documentation Organization

The project documentation has been organized into structured categories:

### Documentation Structure (`/docs/`)
```
docs/
├── api/               # API documentation and specifications
│   ├── API_DOCUMENTATION.md
│   ├── CONVEX_API_DOCUMENTATION.md
│   └── QUESTION_ANSWER_FORMAT_SPECIFICATION.md
├── database/          # Database schemas and data specifications
│   ├── DATABASE_SCHEMA.md
│   ├── Sleep_360_Complete_Database.md
│   ├── Stanford_Sleep_Diary_Specification.md
│   └── linear_data.md
├── deployment/        # Deployment guides and infrastructure
│   ├── DEPLOYMENT_GUIDE.md
│   ├── GITHUB_DEPLOYMENT.md
│   └── README_DEPLOYMENT.md
├── features/          # Feature implementations and integrations
│   ├── PHYSICIAN_DASHBOARD_COMPLETE.md
│   ├── CONVEX_INTEGRATION.md
│   ├── QUESTION_SYSTEM_SUMMARY.md
│   └── RESEND_INTEGRATION.md
├── guides/            # User guides and troubleshooting
│   ├── QUICKSTART.md
│   ├── TROUBLESHOOTING.md
│   └── QUICK_REFERENCE.md
├── setup/             # Setup and configuration instructions
│   ├── COLLABORATOR_SETUP.md
│   ├── CONVEX_SETUP.md
│   ├── SETUP_ENVIRONMENT.md
│   └── HEALTHKIT_SETUP.md
└── status/            # Project status and completion tracking
    ├── IMPLEMENTATION_COMPLETE.md
    ├── PROJECT_SUMMARY.md
    └── TESTING_RESULTS.md
```

### Documentation Guidelines
- **API documentation**: Located in `/docs/api/` for all API-related specifications
- **Setup guides**: Located in `/docs/setup/` for environment and service configuration
- **Feature documentation**: Located in `/docs/features/` for implementation details
- **Troubleshooting**: Located in `/docs/guides/` for user support and debugging
- **Status tracking**: Located in `/docs/status/` for project progress and completion records

This organization ensures documentation is easily discoverable and maintainable as the project grows.

## Recent Changes (2025-11-21)

**Documentation Organization Session:**
- Reorganized 47+ scattered Markdown files into structured `/docs/` directory
- Created logical categorization by document type and purpose
- Maintained important files in appropriate locations (README.md in root, convex/README.md in convex/)
- Improved project maintainability and navigation
- All documentation now follows consistent organization patterns