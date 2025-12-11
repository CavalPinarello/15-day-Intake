# Complete Onboarding Redesign with User-Account-Aware State

**Date:** 2025-12-02

## Problems Fixed

### 1. Screens Too Large for iPhone
The original onboarding screens had fixed large padding, icons, and text that overflowed on smaller iPhones (SE, Mini).

**Solution:** Added adaptive layouts using `GeometryReader`:
- `isCompact` flag triggers for screens < 700pt height
- Smaller icons, tighter spacing on compact screens
- All 8 onboarding steps fit any iPhone without scrolling issues

### 2. Double Splash Screen
The app showed both a system UILaunchScreen and a SwiftUI SplashScreenView, creating a "double splash" effect.

**Solution:**
- Reduced splash duration from 2.5s to 1.2s
- Simplified splash animation (quick fade-in instead of complex animations)
- Uses circadian colors to match the rest of the app
- Removed `welcome` case from `OnboardingStep` enum - onboarding now starts at `.name`

### 3. No Circadian Colors in Onboarding
Onboarding used hardcoded blue/orange colors, ignoring the time-of-day circadian system.

**Solution:** All onboarding screens now use `CircadianPalette.current`:
- Evening/night: Warm amber/orange colors (sleep-safe)
- Morning/afternoon: Blues/teals for alertness
- Background gradients, buttons, text all adapt to time of day

### 4. Device-Based vs User-Account-Based Onboarding
Previously, onboarding completion was stored in local UserDefaults.

**Solution:** Onboarding state is now tied to user account via server:
- `OnboardingManager.checkUserOnboardingState()` called after login
- Server's `onboardingCompleted` field is the source of truth
- Completing onboarding saves to server via `ConvexService.updateUserProfile()`
- Different users on same device get correct onboarding state

## New App Flow
```
App Launch → Splash (1.2s) →
  ├── Not Authenticated → AuthenticationView (Login)
  ├── Authenticated + No Onboarding → OnboardingView
  └── Authenticated + Onboarding Complete → Main Dashboard
```

## Updated Onboarding Steps (8 Total)
1. **Name** - Text input with auto-focus
2. **Measurement System** - Metric/Imperial selection
3. **Height & Weight** - Sliders (metric) or wheel pickers (imperial)
4. **Gender & Age** - 2x2 grid + birth year picker
5. **Wearables** - Multi-select device grid
6. **Health Connect** - Apple Health authorization
7. **Sleep Philosophy** - Our approach explanation
8. **Ready** - Summary and "Start My Journey"

## Key Files Modified
- `/ZoeSleep/ZoeSleep/Views/OnboardingView.swift` - Complete rewrite with adaptive layouts + circadian colors
- `/ZoeSleep/ZoeSleep/Views/SplashScreenView.swift` - Simplified with shorter duration + circadian colors
- `/ZoeSleep/ZoeSleep/ZoeSleepApp.swift` - New `AppRootView` with auth → onboarding → content routing
- `/ZoeSleep/ZoeSleep/Managers/OnboardingManager.swift` - User-aware state, server sync, `clearForSignOut()`
- `/ZoeSleep/ZoeSleep/Managers/AuthenticationManager.swift` - Calls `checkUserOnboardingState()` after login
- `/ZoeSleep/ZoeSleep/ContentView.swift` - Simplified (routing moved to AppRootView)