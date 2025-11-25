# ZOE Sleep Coaching Platform - 15-Day Intake Journey

## Project Overview

This is a sleep coaching platform implementing a 15-day intake journey with **iOS and watchOS as the primary user-facing applications**:

- **iOS Application** (PRIMARY): Main user-facing app for the 15-day intake journey
- **Apple Watch Application**: Companion app with watch-optimized questionnaire experience
- **Web Application** (DEV/DEBUG ONLY): Used for debugging questionnaires and development testing
- **Convex Backend**: Serverless backend providing real-time data synchronization

**Development Focus:** iOS and watchOS applications are the priority. The web version exists solely for questionnaire debugging and is NOT intended for end users.

## Features

### iOS & Apple Watch Applications
- ✅ **15-Day Adaptive Questionnaire**: Smart gateway logic adapts questions based on responses
- ✅ **Stanford Sleep Log**: Daily subjective sleep perception tracking
- ✅ **Gateway System**: 10 gateway types trigger personalized expansion assessments
- ✅ **Clinical Instruments**: ISI, DBAS-16, ESS, PHQ-9, GAD-7, STOP-BANG, Berlin, MEDAS, MEQ
- ✅ **HealthKit Integration**: Compare subjective perception vs Apple Health data
- ✅ **Apple Watch Alternative**: Complete questionnaire experience on watch
- ✅ **Cross-device sync**: Start on iPhone, complete on watch (or vice versa)
- ✅ Native iOS/watchOS experience optimized for each platform
- ✅ **Post-intake recommendations**: Physician recommendations delivered to watch
- ✅ **Clerk Authentication**: Secure user authentication with JWT tokens
- ✅ **Authenticated HealthKit Sync**: Protected health data synchronization

### Web Application (Development/Debug Only)
- ✅ **Questionnaire debugging**: Test and iterate on question flows without rebuilding iOS app
- ✅ Day advance feature for rapid journey testing
- ✅ Admin interface for managing and rearranging questions
- ✅ 9 different question input types (text, textarea, number, select, radio, checkbox, scale, date, time)
- ✅ Hard-coded users (user1-user10) with password "1"
- ✅ Physician dashboard reference implementation
- ⚠️ **NOT for end users** - all user interaction happens on iOS/watchOS

### Shared Backend
- ✅ RESTful API supporting both iOS and web clients
- ✅ Dual database support (SQLite/Convex)
- ✅ Cross-platform authentication and data synchronization
- ✅ **JWT Token Authentication**: Shared authentication between iOS and web
- ✅ **Clerk Integration**: Enterprise-grade authentication service

## Tech Stack

### iOS & Apple Watch Applications
- **iOS**: Swift/SwiftUI with comprehensive UI for detailed interactions
- **watchOS**: SwiftUI optimized for quick watch-based questionnaire completion
- **HealthKit**: Integrated across both iOS and watchOS for comprehensive health data
- **WatchConnectivity**: Real-time sync between iPhone and Apple Watch
- **Convex Swift SDK**: Direct Convex calls via `ConvexMobile` for real-time sync
- **ConvexService.swift**: Type-safe Swift service with Combine publishers
- **Xcode Project**: Complete project structure at `/Sleep360/Sleep360.xcodeproj`

### Web Application (Debug/Dev Only)
- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- React

### Convex Backend
- Convex serverless backend
- Real-time data synchronization
- Built-in authentication with Clerk
- Queries, mutations, and actions

## Setup Instructions

### 1. Install Dependencies

```bash
# Install root dependencies
npm install

# Install all dependencies (root, server, client)
npm run install:all
```

### 2. Setup Convex Backend

```bash
# Install Convex CLI globally
npm install -g convex

# Setup Convex project
npx convex dev
```

This will:
- Setup Convex project and database
- Initialize schema and functions
- Configure authentication with Clerk

### 3. Start the Frontend

```bash
cd client
npm run dev
```

The client will run on http://localhost:3000

### 4. Or Run Both Simultaneously

From the root directory:

```bash
npm run dev
```

This will start both Convex and the client concurrently.

### 5. iOS App Setup (Optional)

```bash
# Open Xcode project
open Sleep360/Sleep360.xcodeproj

# Or navigate to the project in Finder
# Location: /Sleep360/Sleep360.xcodeproj
```

**iOS Setup Requirements:**
- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Apple Developer account (for device testing)
- Enable HealthKit capability in project settings

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

## Convex Functions

### Queries (Read Operations)
- `api.users.get` - Get user information
- `api.days.list` - Get all days
- `api.questions.getByDay` - Get questions for a day
- `api.responses.getUserResponses` - Get user responses
- `api.physician.getAllPatientsWithProgress` - Get patients with progress

### Mutations (Write Operations)
- `api.auth.signUp` - Create new user
- `api.responses.saveResponse` - Save user response (iOS/watchOS)
- `api.users.advanceDay` - Advance user to next day
- `api.questions.create` - Create new question
- `api.physician.updatePatientReviewStatus` - Update review status
- `api.recommendations.createForPatient` - Create physician recommendations for watch

### Actions (External Operations)
- `api.health.syncHealthKitData` - Sync HealthKit data from iOS and watchOS
- `api.watch.syncQuestionnaireProgress` - Sync questionnaire state between devices
- `api.recommendations.pushToWatch` - Push recommendations to Apple Watch
- `api.llm.generateInsights` - Generate AI insights from responses

## Database Schema

The Convex backend includes the following tables:
- `users` - User accounts and authentication
- `days` - 15-day intake journey structure
- `assessment_questions` - Questions for each day (optimized for iOS/watchOS)
- `user_assessment_responses` - User responses from iOS and Apple Watch
- `user_sleep_data` - HealthKit sleep data from iOS and watchOS
- `questionnaire_sync_state` - Cross-device progress synchronization
- `physician_recommendations` - Post-intake recommendations for watch delivery
- `patient_review_status` - Physician review tracking
- `physician_notes` - Physician annotations

## Architecture Details

### Convex Backend Architecture
The platform uses Convex as the primary backend:

**Convex Features:**
- Real-time data synchronization between iOS and web
- Serverless scaling with automatic load balancing  
- Built-in authentication integration with Clerk
- TypeScript-first development with type safety
- Automatic schema management and migrations

### Key Architectural Patterns

**Convex Functions:**
- Queries for read operations (real-time subscriptions)
- Mutations for write operations (transactional updates)
- Actions for external integrations (HealthKit, AI services)
- All functions are strongly typed with TypeScript

**Question System:**
- Flexible question types: text, textarea, number, select, radio, checkbox, scale, date, time
- Conditional logic support via JSON configuration
- Gateway system for dynamic module triggering
- Assessment questions with 9 different answer formats

**Security Features:**
- Clerk authentication with JWT tokens
- Row-level security with Convex functions
- Real-time authorization checks
- Secure HealthKit data handling

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
├── client/            # Next.js web application (physician dashboard)
├── ios/               # iOS application files (15-day intake journey)
│   ├── Config.swift           # API endpoints and configuration
│   ├── HealthKitManager.swift # HealthKit integration for iOS
│   ├── AuthenticationManager.swift # Authentication handling
│   └── WatchConnectivityManager.swift # iPhone-Watch synchronization
├── watchos/           # Apple Watch application files
│   ├── WatchApp.swift         # Main watch app interface
│   ├── QuestionnaireView.swift # Watch-optimized questionnaire UI
│   ├── RecommendationsView.swift # Physician recommendations display
│   ├── HealthKitWatchManager.swift # HealthKit for watchOS
│   └── WatchConnectivityManager.swift # Watch-iPhone synchronization
├── convex/            # Convex backend (queries, mutations, actions)
│   ├── schema.ts      # Database schema definition
│   ├── auth.ts        # Authentication functions  
│   ├── questions.ts   # Question management functions
│   ├── responses.ts   # Response handling functions
│   ├── physician.ts   # Physician dashboard functions
│   ├── health.ts      # HealthKit data sync functions
│   ├── watch.ts       # Watch connectivity and sync functions
│   └── recommendations.ts # Physician recommendations management
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
├── scripts/           # Utility scripts for data conversion and testing
├── CLAUDE.md          # Essential Claude Code guidance (optimized)
└── README.md          # This file
```

## Development Notes

**Platform-Specific Implementation:**
- **iOS App** (PRIMARY): Main user-facing app - comprehensive 15-day intake journey with full UI and HealthKit integration
- **Apple Watch App**: Companion questionnaire interface with quick interactions and physician recommendations
- **Cross-device Sync**: WatchConnectivity ensures seamless experience between iPhone and Watch
- **Web App** (DEV ONLY): For debugging questionnaires and development testing - NOT for end users
- **Convex Backend**: All platforms consume Convex functions for real-time data sync

**Important Implementation Details:**
- Test users (user1-user10) are hard-coded with password "1" for rapid prototyping
- Day advancement button (web) allows rapid testing of multi-day journey
- Admin interface (web) supports drag-and-drop question reordering
- Physician dashboard (web) for patient review workflow
- iOS and Apple Watch apps integrate with HealthKit for comprehensive health data
- Apple Watch optimized for quick questionnaire completion and recommendation viewing
- WatchConnectivity enables real-time sync between iPhone and Apple Watch
- Assessment system supports complex conditional logic and gateway triggers
- Convex provides real-time data synchronization across all platforms (iOS, watchOS, web)
- All timestamps are stored as Unix timestamps (numbers)
- Strongly typed schema with automatic TypeScript generation
- Cross-platform authentication uses Clerk with JWT tokens
- Physician recommendations automatically pushed to Apple Watch post-intake

## Validation & Testing

The system includes comprehensive validation:
- Real-time schema validation with Convex
- Question format validation for 9 different answer types
- User progress tracking and completion validation
- Gateway condition evaluation for dynamic module triggering
- Type-safe function calls with automatic validation

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

