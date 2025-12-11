# Development Patterns & Best Practices

## Watch-First Design Philosophy

### Core Principles
- Design for 41mm Apple Watch FIRST, then scale up to larger screens
- Stanford Sleep Log completable in **under 60 seconds** on any watch
- Digital Crown for time pickers and sliders (with haptic feedback)
- Adaptive layouts: UI automatically adjusts to watch size (40mm → 49mm Ultra)
- Large tap targets: 44pt minimum, 60pt on Ultra

### Watch Constraints
- **Sleep Log Only:** 5 quick questions on Watch
- **Assessment:** Complete on iPhone (screen too small for detailed questions)
- **Treatment Tasks:** Quick tap completion with haptic feedback
- **Time Pickers:** 12-hour format with AM/PM wheel

## Cross-Platform Sync

### Real-Time Synchronization
- Convex provides real-time data synchronization across all platforms
- Start questionnaire on Watch → Continue on iPhone → Finish on Web
- Progress saved instantly to cloud after each question
- Question-by-question resume at exact position

### Device Handoff Flow
```
1. User answers 3 questions on iPhone
2. Progress synced: { section: "sleepLog", currentQuestionIndex: 2 }
3. User opens Watch app, starts Sleep Log
4. Watch fetches progress, resumes at question 3
5. Seamless experience across devices
```

## Accessibility Features

### Visual Accessibility
- **Large Icons Mode:** 30% bigger buttons/text for poor eyesight
- **High Contrast:** Bolder colors, clearer borders
- **Reduce Motion:** Minimize animations
- **Text Size Slider:** Scalable from 0.8x to 1.4x

### Interaction Patterns
- Digital Crown support on Apple Watch
- VoiceOver compatibility
- Clear tap targets (minimum 44pt)
- Haptic feedback for important actions

## Circadian Color System

### Critical Sleep App Principle
**NO BLUE LIGHT AFTER DUSK** - Blue spectrum disrupts melatonin production

### Time-Based Colors
```swift
// Morning/Afternoon (promotes alertness)
- Blues, teals, greens OK
- Primary: Sky blue #0EA5E9
- Secondary: Light blue #38BDF8

// Evening/Night (sleep-safe)
- ONLY warm colors (amber, orange, brown)
- Primary: Warm amber #F28C40
- Secondary: Deep amber #D97706
- Text: Bright cream #FEF3C7
```

### Seasonal Calculation
```swift
let seasonalOffset = sin(Double(dayOfYear - 80) / 365.0 * .pi * 2)
let sunriseHour = 6.5 - seasonalOffset * 1.0  // 5:30-7:30 AM
let sunsetHour = 18.5 + seasonalOffset * 2.0   // 4:30-8:30 PM
```

## iOS & watchOS Development

### SwiftUI Best Practices
- Use `@EnvironmentObject` for shared state (not `@StateObject`)
- `GeometryReader` for adaptive layouts
- Combine publishers for Convex subscriptions
- Keychain for secure token storage

### HealthKit Integration
- Request permissions on first launch
- Compare subjective vs objective sleep data
- Auto-fetch previous night's metrics
- Sync to Convex for analysis

### Authentication Pattern
```swift
// Shared auth state across views
@EnvironmentObject var authManager: AuthenticationManager

// JWT token for API calls
authManager.getAuthToken()

// Clerk integration
AuthenticationManager.signInWithApple()
```

## Web Application Patterns

### Next.js 14 App Router
- Server components by default
- Client components with `"use client"`
- Middleware for auth protection
- API routes in `/app/api/`

### Convex Integration
```typescript
// HTTP client for browser
const client = new ConvexHTTPClient(CONVEX_URL)

// Query with auth
await client.query("watch:getQuestionProgress", {
  userId,
  day: currentDay,
  section: "sleepLog"
})
```

## Testing & Development

### Test Users
- **Credentials:** user1-user10, password: "1"
- **Auto-login:** Watch auto-logs as user3 in dev mode
- **Debug Mode:** Day advancement button bypasses time locks

### Debug Features
- **iOS:** Settings > Debug Mode > Reset Progress
- **Watch:** Settings > Debug > Advance Day
- **Web:** Settings > Debug Mode > Advance to Next Day

### Simulator Testing
- Use `127.0.0.1` instead of `localhost`
- Both apps must use same test user for sync
- WatchConnectivity doesn't work in simulators

## Common Patterns

### Smart Defaults
```swift
// Time pickers
Bedtime: 10:00 PM
Wake time: 7:00 AM
Fall asleep: 10:30 PM

// Numbers
Age: 35 years
Height: 170 cm
Weight: 70 kg

// Scales
Sleep quality: 6/10
Stress: 5/10
Pain: 2/10
```

### Gateway System
- 10 gateway types trigger personalized assessments
- Core questions (Days 1-5) embed gateway triggers
- Expansion questions (Days 6-15) load conditionally
- Load balancing: Light days (7-9 questions) vs Heavy days (13-29)

### Error Handling
```swift
// Retry transient network errors
for attempt in 1...3 {
    do {
        return try await performRequest()
    } catch {
        if attempt < 3 {
            await Task.sleep(500_000_000) // 500ms
        }
    }
}

// Validate JSON before serialization
guard JSONSerialization.isValidJSONObject(data) else {
    return nil
}
```

## Database Patterns

### Timestamps
- Store as Unix timestamps (numbers)
- Convert to Date objects in app

### JSON Fields
- Store as strings
- Parse in application layer

### Cross-Device Sync
- `questionnaire_session` table tracks progress
- Mark `completed: true` when section done
- Validate saved responses before resuming