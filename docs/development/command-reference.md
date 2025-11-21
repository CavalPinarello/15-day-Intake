# Command Reference

Complete reference for all development commands in this project.

## Root Level Commands

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

## Server Commands (run from `/server` directory)

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

## Convex Database Commands

```bash
# Initialize and deploy Convex schema
npx convex dev

# Deploy to Convex (from root directory)
npx convex deploy

# Setup local environment for Convex
./setup-convex.sh
```

## Development Workflow Commands

### Database Setup
- **SQLite mode:** `cd server && npm run seed`
- **Convex mode:** `npx convex dev` then `./setup-convex.sh`

### Environment Configuration
- **SQLite mode:** No `.env` file or `USE_CONVEX=false`
- **Convex mode:** Set `USE_CONVEX=true` and `CONVEX_URL` in `/server/.env`

### Testing Commands
- Use test users: user1-user10 (password: "1")
- Admin panel accessible from login page
- Day advancement feature for rapid testing

### Deployment
- Configured for Vercel deployment
- API routes: `/api/*` → server
- Static routes: `/*` → client

## Validation Commands

```bash
# Database integrity checking
npm run verify-db

# Question format validation for 9 different answer types
# User progress tracking and completion validation
# Gateway condition evaluation for dynamic module triggering
```