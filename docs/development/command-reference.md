# Command Reference

Complete reference for all development commands in this project.

## Root Level Commands

```bash
# Install all dependencies for all components
npm run install:all

# Run both Convex and client concurrently
npm run dev

# Convex only
npx convex dev

# Client only (when client directory exists)
npm run client
```

## Convex Commands

```bash
# Start Convex development environment
npx convex dev

# Deploy Convex functions
npx convex deploy

# Setup Convex project
npx convex init

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

## App Icon Generation

```bash
# Generate/regenerate all iOS and watchOS app icons
# First time setup (creates virtual environment):
cd /path/to/project
python3 -m venv .venv
source .venv/bin/activate
pip install Pillow

# Generate icons (after setup):
source .venv/bin/activate
python3 scripts/generate_app_icons.py
```

Icon files are generated to:
- **iOS:** `/Sleep360/Sleep360/Assets.xcassets/AppIcon.appiconset/`
- **watchOS:** `/Sleep360/Sleep360 Watch App/Assets.xcassets/AppIcon.appiconset/`
- **Preview:** `/docs/zoe-sleep-icon-preview.png`

## Validation Commands

```bash
# Database integrity checking
npm run verify-db

# Question format validation for 9 different answer types
# User progress tracking and completion validation
# Gateway condition evaluation for dynamic module triggering
```