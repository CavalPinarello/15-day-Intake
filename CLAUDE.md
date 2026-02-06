# CLAUDE.md - Zoe Sleep V1 Quick Reference

> **Repository:** `Zoe-Sleep-V1` | **Full changelog:** [`docs/CHANGELOG.md`](./docs/CHANGELOG.md)

## Essential Commands

```bash
npm run install:all && npm run dev    # Start everything
npx convex dev && ./setup-convex.sh   # Convex cloud mode
```

## Critical Info

- **Current Version:** 1.0.12 (Build 12+) - See [`docs/VERSION_HISTORY.md`](./docs/VERSION_HISTORY.md)
- **Version Source:** `ZoeSleep/Shared/AppVersion.swift` (auto-increments on each build)
- **Test Users:** user1-user10, password: "1"
- **Registration:** Email + password only (username auto-generated)
- **Xcode:** `/ZoeSleep/ZoeSleep.xcodeproj`
- **Bundle IDs:** iOS: `com.sleep360.app`, Watch: `com.sleep360.app.watchkitapp`

## Circadian Design System (CRITICAL)

**EVERY new component MUST follow circadian design principles.**

### 8-Phase Day (Smooth Interpolation)
| Phase | Time | Blue Light |
|-------|------|------------|
| Pre-Dawn/Dawn | 4-7:30 AM | OK |
| Morning/Midday | 7:30 AM-2 PM | OK |
| Afternoon | 2-5 PM | OK |
| Dusk/Evening/Night | 5 PM-4 AM | NO BLUE |

### Color Usage Rules
1. `theme.primaryText` for text on backgrounds
2. `theme.cardBackground` for cards
3. `theme.textOnPrimary` for text on accent buttons
4. `theme.accent` for interactive elements
5. `theme.backgroundGradient` for full-screen backgrounds

### Key Files
- **CircadianPalette/ColorTheme:** `QuestionModels.swift`
- **ThemeManager:** `ThemeManager.swift` (updates every 60s)

## Platform Architecture

```
iPhone ←→ Convex ←→ Dashboard
(Full intake)      (Clinician view)
```

- **iPhone:** 10-day intake journey (PRIMARY)
- **Dashboard:** Clinician interface (IN DEVELOPMENT)
- **Web:** Debug/testing only
- **Watch:** PAUSED - branch `feature/watch-app-complete`

### ⚠️ CRITICAL: Convex Configuration

**Two Convex instances exist - ALWAYS use the DEV instance:**

| Instance | URL | Status |
|----------|-----|--------|
| **Dev (USE THIS)** | `https://enchanted-terrier-633.convex.cloud` | ✅ Contains all patient data |
| **Prod (DON'T USE)** | `https://necessary-gnat-882.convex.cloud` | ⚠️ Empty database |

**Quick Checks:**
- Vercel: `npx vercel env ls production | grep CONVEX` → Must show `enchanted-terrier-633`
- Local: `.env.local` → Must have `CONVEX_DEPLOYMENT=dev:enchanted-terrier-633`
- iOS: `ConvexManager.swift` → Must use `enchanted-terrier-633`

**See [`DEPLOY.md`](./DEPLOY.md) for complete deployment and troubleshooting guide.**

## Key Locations

| Platform | Path |
|----------|------|
| iOS | `/ZoeSleep/ZoeSleep/` |
| Watch | `/ZoeSleep/ZoeSleep Watch App/` |
| Web | `/client/src/app/` |
| Backend | `/convex/` |
| Docs | `/docs/` |

## Smart Questionnaire System

- **10-Day Journey:** Core (Days 1-5) + Conditional expansion (Days 6-10)
- **11 Gateways:** Insomnia, Sleep Apnea (OSA), Mental Health, Pain, Prostate, etc.
- **Daily Sleep Log:** 5 Stanford questions every morning
- **Auto-derivation:** Many questions pre-populated from sleep log data

## Documentation

- **Architecture:** [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md)
- **Patterns:** [`docs/PATTERNS.md`](./docs/PATTERNS.md)
- **Changelog:** [`docs/CHANGELOG.md`](./docs/CHANGELOG.md)
- **Version History:** [`docs/VERSION_HISTORY.md`](./docs/VERSION_HISTORY.md)
- **Sessions:** [`docs/sessions/INDEX.md`](./docs/sessions/INDEX.md)

## Current Focus (Jan 2026)

1. iPhone app completion and polish
2. Clinician dashboard development
3. Backend API stability

## Recent Updates

See [`docs/CHANGELOG.md`](./docs/CHANGELOG.md) for complete history.

**Jan 5:** Guided tour improvements - Fixed tutorial scrolling and spotlight positioning. Tour now automatically scrolls to each feature being explained with proper element highlighting. Added ScrollViewReader to dashboard, unique scroll IDs for all tour targets, and custom scroll anchors (.top for most elements to avoid cutting off content). Fixed spotlight frame padding: minimal 4pt top padding (avoids capturing previous elements), generous 50pt bottom padding (shows circles/buttons fully). "Next" button text no longer wraps to two lines. Tour steps fade out during transitions and reappear after scroll completes (0.5s delay for frame updates). Step 5 "Deep Dives" scrolls to assessment area since upcoming assessments may not be visible on Day 1.
**Jan 5:** Watch check-in tile redesign - Replaced "1/3", "2/3" badge with three individual time slot indicators (sunrise/sun/sunset icons for AM/Mid/PM) each with green checkmark overlay when completed. Makes it clear at a glance which check-ins are done. Icons are dimmed when not yet completed.
**Jan 5:** Check-in sync iPhone→Watch fix - "Sync Now" button now includes check-in completion status (morning/midday/evening) in the payload. Watch `handleUserDataResponse` processes this and posts `watchCheckInStatusDidChange` notification to update UI immediately. Previously check-in sync relied only on real-time notifications which could be missed if Watch app was in background.
**Jan 5:** Watch connectivity UI improvements - replaced alarming "Not Reachable" status (which is normal when Watch app isn't in foreground) with friendlier "Ready/Active" terminology. Removed redundant "Force Reconnect" button from Profile settings (kept single "Sync Now" button). Debug panel now shows "Real-time Link: Standby" with neutral gray instead of scary red. Added explanation that sync works via queue even when Watch isn't actively reachable. Apple's `isReachable` is only true when both apps are in foreground - this is by design for battery saving.
**Jan 5:** Watch sleep log/assessment sync fix - When iPhone completes sleep log or assessment, the Watch now properly shows it as "Done" with strikethrough instead of "Complete on iPhone". Added `watchSectionCompletionDidChange` notification posted after iPhone syncs section completion. MinimalTasksView now reads directly from WatchConvexService (reactive) instead of stale snapshot.
**Jan 4:** Combined Units and HeightWeight onboarding steps into single screen - removed confusing separate "Measurement Preferences" screen that showed static example values (175 cm, 70 kg). Now one "Body Metrics" screen with unit picker at top followed by height/weight sliders. Reduced onboarding from 7 to 6 steps (name → heightWeight → genderAge → wearables → healthConnect → ready). Added onboarding step persistence so users don't lose progress if app restarts mid-onboarding. Enhanced HealthKit connection logging for debugging.
**Jan 4:** Sleep data source selector for iOS debug panel - Added ability to compare sleep data from different HealthKit sources (Apple Watch vs Oura Ring) in Debug Panel → HealthKit Data. New `getAvailableSleepSources()` method uses HKSourceQuery to discover all sleep data sources. Enhanced SleepDataSource struct with displayName, iconName, isAppleWatch, isOura helpers. UI shows horizontal chip selector with "All (Merged)" option and per-source filtering. Useful for diagnosing overlapping data from multiple wearables causing impossible percentages (e.g., 186% total). Watch app now always filters to Apple Watch data only.
**Jan 4:** Simplified notification system to only 3 reminders per day - Morning (9 AM) for sleep log + assessment + energy check-in, Afternoon (1 PM) for midday energy check-in (skipped if Watch installed), Evening (8 PM) for evening energy + incomplete tasks. Removed 9 redundant "nudge" notifications that were bombarding users. Updated NotificationsSettingsView with three clear sections. Watch integration: if Apple Watch is installed, iPhone skips afternoon reminder since Watch handles midday check-ins. State sync for sleep log, assessment, and energy check-ins between iPhone and Watch via WatchConnectivity.
**Jan 4:** Chronotype assessment during HealthKit onboarding - New ChronotypeManager analyzes 90 days of sleep data during HealthKit authorization. Shows inline progress ("Analyzing sleep patterns...", "Calculating chronotype..."). Classifies user as Early Riser (🌅), Balanced (⚖️), Night Owl (🦉), or Adaptive (🔄) based on sleep midpoint using Gaussian scoring. Results displayed in new "Sleep Profile" section in Profile settings. If <90 nights, shows "we'll estimate in coming weeks" message. HealthKit sync improved with DispatchGroup for async handling and `refreshDemographics()` method. Convex schema updated with chronotype fields.
**Jan 4:** Test Day Unlock debug feature - Added "Test Day Unlock (4 AM)" section to Debug Panel that simulates 10 seconds before 4 AM unlock using `testTimestamp` parameter. Separated `bypassTimeCheck` from `debugMode` so debug mode no longer auto-bypasses time checks. New toggle "Bypass 4 AM Time Check" in Journey Controls (off by default). Day advancement logging tracks all attempts with success/failure stats. New files: `UnlockTestManager.swift`, `DayAdvancementLogger.swift`.
**Jan 4:** Onboarding flow reordered and simplified - Personal connection first (Name → Units → Height/Weight → Gender/Age → Wearables), then HealthKit at end for sleep history sync. New Units step shows locale-detected measurement preference. HealthKit step requests permissions, fetches demographics, syncs sleep data, and performs chronotype analysis with inline progress. Fixed `markHealthKitConnected()` timing bug - now called AFTER demographics are fetched. Added missing data banner when HealthKit can't provide some info (e.g., "We'll ask about height, weight next").
**Jan 4:** Coach mark system overhaul - Fixed guide pop-up bubbles that were clipped and pointing to wrong elements. Implemented anchor-based positioning using named coordinate space (`coachMarkCoordinateSpace`) to track actual UI element frames dynamically. Added spotlight effect that highlights target element by cutting it out from the dark overlay, making it crystal clear what each tip refers to. Coach marks now auto-skip steps where target elements don't exist or aren't visible. Debug mode shows red rectangles around targets for verification.
**Jan 4:** Fixed "Other" dose option bug in Sleep Log medication question - clicking "Other" and typing a custom dose (like "15") now works correctly. Previously, typing "1" to start "15" would match the preset "1" button and hide the text field. Fix uses @State `customDoseCategories` set to explicitly track custom entry mode instead of inferring from dose value. Also fixed validation to block proceeding when dose is still "custom" placeholder, and fixed "custom mg" showing in badge before value entered.
**Jan 4:** Removed "GATEWAY:" prefix from question display text - Gateway questions (insomnia, mental health, OSA, etc.) no longer show internal "GATEWAY:" label to users. The `tier: "GATEWAY"` field is preserved for logic; only the visible question text was cleaned. Updated 5 data files: `assessment_questions_converted.json`, `sleep360_questions.json`, `standardized_questions_sample.json`, `sleep_log_questions.json`, and `Sleep_360_Complete_Database.md`. Re-seeded Convex database.
**Jan 3:** Removed "Last Night's Sleep (Apple Health)" card from sleep log - sleep log is about SUBJECTIVE sleep experience, not objective HealthKit data which can be unreliable/incomplete for new users. Removed HealthKitSleepCard component and related fetch logic.
**Jan 3:** STOP-BANG scoring fallback - physician.ts now falls back to source questions (Q17, Q19, Q20, Q21, Q27) if SB_* prefix questions not answered, plus uses demographics (age, sex, BMI) for scoring when available.
**Jan 3:** Onboarding simplification - streamlined HealthKit connection screen (larger icon, removed benefits list, added Skip option), removed chronotype analysis phase entirely, simplified overall flow.
**Jan 3:** Unified Today's Focus section - merged separate Energy/Mood/Focus check-in widget and task list into ONE "Today's focus" card with 3 items: Check-In (with mini Morning/Midday/Evening circles), Sleep Log, and Assessment. Removed duplicate "Today's Focus" labeling, cleaner dashboard UX. Created CheckInTaskRow component with inline time slot circles.
**Jan 3:** Shortened journey from 14 days to 10 days - Core assessment (Days 1-5) unchanged, expansion packs consolidated into Days 6-10 by grouping related clinical instruments (Day 6: ISI+SWDSQ+DBAS, Day 7: PHQ9+GAD7+PSAS, Day 8: STOP-BANG+ESS+FSS, Day 9: Sleep Hygiene+BPI+FOSQ, Day 10: PROMIS+MEDAS+MEQ)
**Jan 3:** Onboarding UX improvements - removed floating magnifying glass (Enhanced Readability button) from onboarding screens, replaced small text Continue/Back buttons with visible styled buttons on HealthKit connection screen, removed Sleep Philosophy step
**Jan 3:** Analysis pending screen polish - hidden "My Data" button (feature not ready), changed profile icon from person silhouette to user's initial in circle for consistency with main dashboard
**Jan 3:** Fixed day advancement bug for expansion days without assessments - `advanceDay` mutation now uses `shouldShowExpansion()` to check if the SPECIFIC day has content for user's triggered gateways, not just if ANY gateways are triggered globally. Fixes inability to advance past Day 10 when only Pain gateway triggered (Day 10 requires excessive_sleepiness gateway for ESS/FSS packs).
**Jan 3:** Watch-style check-in widget improvements - optimistic state updates for instant UI feedback, theme-aware colors for better contrast in all circadian phases, fixed state persistence after completion, widget title changed to "Today's Focus" with "Energy · Mood · Focus" subtitle
**Jan 3:** Convex backend enhancements - added mood/focus parameters to midday and evening check-in mutations, expanded getCheckInHistory query to return all energy/mood/focus data per time slot for physician dashboard
**Jan 2:** Parked XP/Gamification feature - disabled via `gamificationEnabled` flag in ThemeManager (default false), toggle available in Debug Panel > Experimental Features, code preserved for future re-enablement
**Jan 2:** Unified time format system - TimeFormatManager + locale override on all DatePickers to force 12/24-hour format, Watch time picker supports both modes, system auto-detects device preference with user override in Settings
**Jan 2:** Notification message variety (100 rotating messages to prevent desensitization), Watch-style Energy/Mood/Focus check-in infrastructure on iOS, improved notification settings UI with scheduled time display
**Jan 2:** App versioning system overhaul (v1.0.12) - single source of truth in `ZoeSleep/Shared/AppVersion.swift`, version history tracking in `docs/VERSION_HISTORY.md`, fixed date-based build display bug
**Jan 2:** Unit-aware help text for temperature question (Q33A) - shows °C or °F based on user's measurement preference, added helpTextImperial field to Question model and Convex schema
**Jan 2:** Glassy card UI with frosted glass effect (GlassyCardBackground using ultraThinMaterial with warm tint overlay), semi-transparent option buttons in questionnaires, replaced Speed Test with Time Travel testing mode, fixed dashboard margins (20pt horizontal padding)
**Jan 2:** Fixed empty assessment handling - days without triggered gateways no longer show assessment task or count as "missed", added EmptyAssessmentView for edge cases, fixed time estimation consistency across Focus/Splash screens, removed misleading INFO_NO_QUESTIONS placeholder
**Jan 1:** Unified 1-10 scale for ALL slider questions (ScaleMapper with positive/negative label detection), intensity-scaled haptic feedback for sliders (toggleable in Settings > Accessibility)
**Dec 31:** Profile settings cleanup (removed unused High Contrast, Reduce Motion, Large Icons toggles), experimental features system (Sleep Diary History and Sleep Insights hidden behind debug toggles)
**Dec 30:** Fix expansion pack scheduling bug (no longer shows on Days 2-5, only Days 6+), question inventory optimization - 20+ new follow-up questions, 3 new gateway triggers (OSA Q48/49, Pain Q53, Prostate Q47), fixed measurement ranges/defaults
**Dec 29:** Comprehensive debug reset fix (Clinical Scores + all dashboard data), time picker defaults for dependent questions fix, dashboard pillar completion UI (neutral amber), Sleep Health Factors dashboard module, iOS complex response serialization fix, unified body metrics slider UI, auto-derivable questions
**Dec 28:** Expansion pack slider UX fix, journey intro flow, fresh install detection, dashboard UX redesign
**Dec 27:** Day type analysis, nap/medication tracking, scale labels fix, dynamic task counter, new logo
**Dec 22:** 8-phase circadian system, text contrast fix, unified debug panel, admin tools

---

*For detailed documentation, see the `/docs/` directory.*
