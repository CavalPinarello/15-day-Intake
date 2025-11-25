# iOS Convex Database Integration - Session Log

**Date:** 2025-11-25
**Session Goal:** Create dedicated Convex database infrastructure for iOS app

## Summary

Created a comprehensive iOS-dedicated backend using Convex, enabling the iOS app to communicate directly with Convex using the official Swift SDK instead of going through the legacy REST API server.

## Changes Made

### 1. Schema Updates (`convex/schema.ts`)

Added 7 new iOS-specific tables:

| Table | Purpose |
|-------|---------|
| `ios_devices` | Device registration for APNs push notifications |
| `ios_sessions` | Session management with device linking |
| `apple_sign_in` | Apple Sign-In data storage |
| `ios_app_events` | App analytics and event tracking |
| `ios_healthkit_sync` | HealthKit sync status tracking |
| `ios_notifications` | Push notification history |
| `ios_watch_sync` | iPhone-Watch sync state |

### 2. New Convex Functions (`convex/ios.ts`)

Created 19 iOS-specific functions:

**Authentication:**
- `signIn` - Email/username + password authentication
- `signInWithApple` - Apple Sign-In integration
- `register` - New user registration
- `validateSession` - Token validation
- `signOut` - Session invalidation
- `refreshSession` - Token refresh

**User Management:**
- `getUserProfile` - Get user profile data
- `updateUserProfile` - Update profile fields
- `updateUserPreferences` - Update notification/sync preferences
- `registerPushToken` - Register APNs device token

**HealthKit Sync:**
- `syncSleepData` - Sync sleep data from Apple Health
- `syncHeartRateData` - Sync heart rate & HRV data
- `syncActivityData` - Sync steps, activity, exercise
- `getRecentSleepData` - Query recent sleep records

**Questionnaire/Journey:**
- `getDayQuestionnaire` - Get day's questions with existing responses
- `submitQuestionnaireResponse` - Save questionnaire answer
- `completeDay` - Mark day complete and advance
- `getJourneyProgress` - Get overall journey status

**Analytics:**
- `trackEvent` - Track app events for analytics

### 3. iOS Swift Integration (`Sleep360/Sleep360/Services/ConvexService.swift`)

Created comprehensive Swift service using official ConvexMobile SDK:

- **Global Convex Client** - Single instance for app lifecycle
- **Type-safe Models** - Codable structs for all responses
- **Session Management** - Keychain-based secure storage
- **Real-time Subscriptions** - Combine publishers for live updates
- **Error Handling** - Custom ConvexError enum

### 4. Configuration Updates (`Sleep360/Sleep360/Config.swift`)

- Added `useConvex` toggle for backend selection
- Added `convexDeploymentURL` configuration
- Added journey and session configuration constants

### 5. Xcode Package Integration

- Installed `convex-swift` v0.6.1+ via Swift Package Manager
- Repository: `https://github.com/get-convex/convex-swift`

## Deployment

- **Convex URL:** `https://enchanted-terrier-633.convex.cloud`
- All functions deployed and verified
- Schema migration completed successfully

## Usage Example

```swift
// Sign in
let response = try await ConvexService.shared.signIn(
    identifier: "user@email.com",
    passwordHash: hashedPassword,
    deviceId: UIDevice.current.identifierForVendor?.uuidString ?? ""
)

// Get questionnaire with real-time updates
for await questionnaire: DayQuestionnaire in
    convex.subscribe(to: "ios:getDayQuestionnaire", args: ["userId": userId]).values
{
    self.questions = questionnaire.questions
}

// Sync HealthKit data
let result = try await ConvexService.shared.syncSleepData(
    deviceId: deviceId,
    sleepData: sleepRecords
)
```

## Files Created/Modified

### New Files:
- `/convex/ios.ts` - iOS-specific Convex functions
- `/Sleep360/Sleep360/Services/ConvexService.swift` - Swift service

### Modified Files:
- `/convex/schema.ts` - Added iOS tables
- `/Sleep360/Sleep360/Config.swift` - Added Convex configuration
- `/Sleep360/Sleep360.xcodeproj/project.pbxproj` - Added Convex Swift package

## Next Steps

1. Integrate ConvexService into existing iOS views
2. Replace legacy APIService calls with ConvexService
3. Implement real-time subscriptions in SwiftUI views
4. Add push notification handling with APNs
