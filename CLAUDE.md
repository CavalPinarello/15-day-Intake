# CLAUDE.md

This file provides essential guidance to Claude Code when working with this sleep coaching platform repository.

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

- **Schema:** `/convex/schema.ts` (30+ tables)
- **API Routes:** `/server/routes/`
- **Database:** `/server/database/` (SQLite) | `/convex/` (Convex)
- **Documentation:** `/docs/` (organized by category)

## Development Patterns

- Always run `npm run verify-db` after database changes
- Use test users for rapid development/testing
- Day advancement button available for journey testing
- Dual database support: SQLite (local) / Convex (cloud)

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

**CLAUDE.md Optimization Session:**
- Reduced file size from 213 lines (8KB) to 53 lines (4KB) - 75% reduction
- Moved detailed documentation to organized `/docs/` structure  
- Enhanced README.md with comprehensive architecture details
- Created `/docs/development/` for patterns and command reference
- Improved Claude Code performance and maintainability
- **Session Log:** `/docs/sessions/optimization-2025-11-21.md`