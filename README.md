# ZOE Sleep Coaching Platform - 14-Day Onboarding Journey

## Project Overview

This is a sleep coaching platform implementing a 14-day onboarding journey, built for rapid prototyping and testing with dual database support (SQLite/Convex) and comprehensive admin management features.

## Features

- ✅ 14-day onboarding journey with themed daily experiences
- ✅ 9 different question input types (text, textarea, number, select, radio, checkbox, scale, date, time)
- ✅ Day advance feature for rapid testing
- ✅ Admin interface for managing and rearranging questions
- ✅ Progress tracking
- ✅ Hard-coded users (user1-user10) with password "1"
- ✅ Reusable backend architecture for other components

## Tech Stack

### Backend
- Node.js + Express
- SQLite (easily migratable to PostgreSQL)
- RESTful API

### Frontend
- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- React

## Setup Instructions

### 1. Install Dependencies

```bash
# Install root dependencies
npm install

# Install all dependencies (root, server, client)
npm run install:all
```

### 2. Initialize Database and Seed Sample Questions

```bash
cd server
npm run seed
```

This will:
- Create the SQLite database
- Initialize 14 days
- Create 10 test users (user1-user10)
- Add sample questions for Day 1 and Day 2

### 3. Start the Backend Server

```bash
cd server
npm run dev
```

The server will run on http://localhost:3001

### 4. Start the Frontend

In a new terminal:

```bash
cd client
npm run dev
```

The client will run on http://localhost:3000

### 5. Or Run Both Simultaneously

From the root directory:

```bash
npm run dev
```

This will start both the server and client concurrently.

## Usage

### Login
- Username: `user1` through `user10`
- Password: `1`

### User Journey
1. Login with any user (user1-user10)
2. You'll see your current day in the onboarding journey
3. Answer questions for the day
4. Use the "⏩ Advance Day" button to quickly test multiple days
5. Progress is automatically saved

### Admin Panel
1. Click "Admin Panel" from the login page
2. Select a day from the dropdown
3. Add, edit, delete, or reorder questions
4. Drag and drop questions to rearrange them
5. Questions support 9 different input types

## Question Types

1. **Text** - Single-line text input
2. **Textarea** - Multi-line text input
3. **Number** - Numeric input
4. **Select** - Dropdown selection
5. **Radio** - Single choice from options
6. **Checkbox** - Multiple choice from options
7. **Scale** - Slider/scale input (1-10 by default)
8. **Date** - Date picker
9. **Time** - Time picker

## API Endpoints

### Auth
- `POST /api/auth/login` - Login user
- `GET /api/auth/me` - Get current user

### Days
- `GET /api/days` - Get all days
- `GET /api/days/:dayNumber` - Get specific day
- `GET /api/days/user/:userId/current` - Get user's current day

### Questions
- `GET /api/questions/day/:dayId` - Get questions for a day
- `POST /api/questions` - Create question
- `PUT /api/questions/:questionId` - Update question
- `DELETE /api/questions/:questionId` - Delete question

### Responses
- `POST /api/responses` - Save response
- `GET /api/responses/user/:userId/day/:dayId` - Get user responses for a day
- `POST /api/responses/user/:userId/day/:dayId/complete` - Mark day as completed

### Users
- `GET /api/users/:userId/progress` - Get user progress
- `POST /api/users/:userId/advance-day` - Advance to next day
- `POST /api/users/:userId/set-day` - Set user to specific day

### Admin
- `GET /api/admin/days/:dayId/questions` - Get questions for admin
- `POST /api/admin/days/:dayId/questions/reorder` - Reorder questions
- `POST /api/admin/days/:dayId/questions` - Create question
- `PUT /api/admin/questions/:questionId` - Update question
- `DELETE /api/admin/questions/:questionId` - Delete question

## Database Schema

The backend uses SQLite with the following tables:
- `users` - User accounts
- `days` - 14 days of the journey
- `questions` - Questions for each day
- `responses` - User responses to questions
- `user_progress` - User progress tracking

## Architecture Details

### Database Architecture
The platform supports dual database backends for flexible deployment:

**SQLite (Local Development):**
- Fast local development
- No external dependencies
- File-based storage in `/server/`

**Convex (Cloud Deployment):**
- Real-time synchronization
- Serverless scaling
- Built-in authentication integration
- Set `USE_CONVEX=true` in `/server/.env` to enable

### Key Architectural Patterns

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

## Documentation

All project documentation has been organized in the `/docs` directory:

```
docs/
├── api/               # API documentation and specifications
├── database/          # Database schemas and data specifications
├── deployment/        # Deployment guides and infrastructure
├── development/       # Development patterns and command reference
├── features/          # Feature implementations and integrations
├── guides/            # User guides and troubleshooting
├── sessions/          # Development session logs
├── setup/             # Setup and configuration instructions
└── status/            # Project status and completion tracking
```

### Key Documentation Files:
- [`/docs/api/API_DOCUMENTATION.md`](docs/api/API_DOCUMENTATION.md) - Complete API reference
- [`/docs/guides/QUICKSTART.md`](docs/guides/QUICKSTART.md) - Quick start guide
- [`/docs/guides/TROUBLESHOOTING.md`](docs/guides/TROUBLESHOOTING.md) - Common issues and solutions
- [`/docs/setup/SETUP_ENVIRONMENT.md`](docs/setup/SETUP_ENVIRONMENT.md) - Environment setup
- [`/docs/database/DATABASE_SCHEMA.md`](docs/database/DATABASE_SCHEMA.md) - Complete database schema
- [`/docs/deployment/DEPLOYMENT_GUIDE.md`](docs/deployment/DEPLOYMENT_GUIDE.md) - Deployment instructions
- [`/docs/development/command-reference.md`](docs/development/command-reference.md) - Complete command reference
- [`/docs/development/architecture-patterns.md`](docs/development/architecture-patterns.md) - Detailed architecture patterns

## Project Structure

```
├── client/            # Next.js frontend application
├── convex/            # Convex database functions and schema
├── data/              # Sample data and question definitions
├── docs/              # All project documentation (organized by category)
│   ├── api/           # API documentation and specifications
│   ├── database/      # Database schemas and data specifications
│   ├── deployment/    # Deployment guides and infrastructure
│   ├── development/   # Development patterns and command reference
│   ├── features/      # Feature implementations and integrations
│   ├── guides/        # User guides and troubleshooting
│   ├── sessions/      # Development session logs
│   ├── setup/         # Setup and configuration instructions
│   └── status/        # Project status and completion tracking
├── ios/               # iOS-specific components and setup
├── scripts/           # Utility scripts for data conversion and testing
├── server/            # Express.js backend API
│   ├── database/      # SQLite database adapters and initialization
│   ├── routes/        # REST API endpoints
│   ├── scripts/       # Database seeding and management
│   └── server.js      # Main Express server configuration
├── CLAUDE.md          # Essential Claude Code guidance (optimized)
└── README.md          # This file
```

## Development Notes

**Important Implementation Details:**
- Test users (user1-user10) are hard-coded with password "1" for rapid prototyping
- Day advancement button allows rapid testing of multi-day journey
- Admin interface supports drag-and-drop question reordering
- Physician dashboard integration for patient review workflow
- Assessment system supports complex conditional logic and gateway triggers
- The codebase expects both SQLite and Convex to have identical schemas
- All timestamps are stored as Unix timestamps (numbers)
- JSON fields are stored as strings and require parsing

## Validation & Testing

The system includes comprehensive validation:
- Database integrity checking via `npm run verify-db`
- Question format validation for 9 different answer types
- User progress tracking and completion validation
- Gateway condition evaluation for dynamic module triggering

## Next Steps

This is a rapid prototyping version. For production, consider:
- Authentication system (currently hard-coded)
- PostgreSQL database migration
- Insight generation logic (42 insights)
- Conditional logic engine
- Celebration animations
- Notification scheduling
- Apple Health integration
- Swipeable card interface enhancements

## License

MIT

