# Zoe Sleep Architecture & File Structure

## Project Structure Overview

```
Zoe-Sleep-V1/
├── ZoeSleep/                    # iOS & watchOS Xcode project
├── client/                      # Next.js web application (debug only)
├── server/                      # Node.js backend server
├── convex/                      # Convex serverless backend
├── docs/                        # Documentation
└── scripts/                     # Build and utility scripts
```

## iOS Application (Xcode Project)

### Main Project
- **Xcode Project:** `/ZoeSleep/ZoeSleep.xcodeproj`
- **Bundle ID:** `com.zoesleep.app`

### iOS Target Files
```
/ZoeSleep/ZoeSleep/
├── Models/
│   ├── QuestionModels.swift      # Question data models & types
│   └── SharedQuestionBank.swift  # Shared questions (iOS/Watch)
├── Managers/
│   ├── HealthKitManager.swift    # HealthKit integration
│   ├── AuthenticationManager.swift # Clerk auth management
│   ├── QuestionnaireManager.swift # Questionnaire logic
│   ├── OnboardingManager.swift   # User onboarding flow
│   └── ThemeManager.swift        # Theme & appearance
├── Views/
│   ├── ContentView.swift         # Main dashboard
│   ├── QuestionnaireView.swift   # 15-day questionnaire
│   ├── QuestionComponents.swift  # Question UI components
│   ├── OnboardingView.swift      # User onboarding
│   ├── TreatmentView.swift       # Post-intake treatment
│   ├── CircadianWaveBackground.swift # Animated backgrounds
│   └── SplashScreenView.swift    # Animated splash screen
├── Services/
│   ├── APIService.swift          # HTTP networking
│   └── ConvexService.swift       # Convex backend integration
└── ZoeSleepApp.swift             # App entry point
```

## Apple Watch Application

### Watch Target Files
```
/ZoeSleep/ZoeSleep Watch App/
├── ZoeSleep_Watch_AppApp.swift   # Watch app entry point
├── WatchHomeView.swift            # Main watch interface
├── QuestionnaireView.swift       # Watch questionnaire (Sleep Log only)
├── SleepLogView.swift            # 60-second morning flow
├── TreatmentTasksView.swift      # Daily treatment tasks
├── SettingsView.swift            # Watch settings & debug
├── WatchQuestionComponents.swift # Adaptive UI components
├── RecommendationsView.swift     # Physician recommendations
├── WatchThemeManager.swift       # Watch theme management
├── HealthKitWatchManager.swift   # Watch health data
└── WatchConnectivityManager.swift # iPhone-Watch sync
```

### Watch Features
- **Bundle ID:** `com.zoesleep.app.watchkitapp`
- **Sleep Log Only:** 5 Stanford questions (~60 seconds)
- **Assessment:** Shows "Complete on iPhone" status
- **Adaptive UI:** 40mm SE to 49mm Ultra support

## Web Application (Debug/Development Only)

### Patient Journey
```
/client/src/app/
├── journey/                      # 15-day questionnaire
├── treatment/                    # Post-intake tasks
├── sign-in/                      # Authentication
└── layout.tsx                    # Root layout
```

### Physician Dashboard
```
/client/src/app/physician-dashboard/
├── page.tsx                      # Patient list
├── patient/[id]/
│   ├── page.tsx                  # Patient detail
│   └── prescription/page.tsx    # Treatment builder
├── questions/page.tsx            # Question manager
└── settings/page.tsx             # Dashboard settings
```

### Components
```
/client/src/components/
├── questions/                    # Question input components
├── ui/                           # Shadcn UI components
└── navigation/                   # Nav components
```

## Convex Backend

### Core Functions
```
/convex/
├── schema.ts                     # Database schema (30+ tables)
├── watch.ts                      # Watch-specific functions
├── ios.ts                        # iOS-specific functions
├── recommendations.ts            # Physician recommendations
├── treatment.ts                  # Treatment management
├── questions.ts                  # Question operations
├── users.ts                      # User management
└── _generated/                   # Auto-generated types
```

### Key Tables
- `users` - User profiles & progress
- `questionnaire_responses` - All question answers
- `questionnaire_session` - Cross-device sync state
- `interventions` - Treatment interventions
- `recommendations` - Physician recommendations
- `ios_devices`, `ios_sessions` - iOS tracking
- `apple_sign_in` - Apple Sign In data

## Server (Node.js Backend)

```
/server/
├── src/
│   ├── routes/                   # API endpoints
│   ├── services/                 # Business logic
│   └── middleware/               # Auth, logging
├── database.sqlite               # SQLite database
└── .env                          # Environment config
```

## Documentation

```
/docs/
├── sessions/                     # Development session logs
│   └── INDEX.md                  # Session history index
├── api/                          # API documentation
├── setup/                        # Setup guides
├── guides/                       # User guides
├── ARCHITECTURE.md               # This file
└── PATTERNS.md                   # Development patterns
```

## Legacy/Archived

```
/Sleep360/                        # Old project (archived)
/ios/                             # Original iOS files (reference)
/watchos/                         # Original watch files (reference)
```

## Platform Architecture

### Cross-Platform Sync
```
Apple Watch ←→ Convex ←→ iPhone
                ↑
                ↓
            Web (Debug)
```

### Authentication Flow
```
Clerk → JWT Token → All Platforms
```

### Data Flow
1. **Real-time sync:** Convex subscriptions
2. **Question progress:** Saved per question
3. **Cross-device resume:** Exact question position
4. **HealthKit:** iOS/Watch → Convex → Analysis