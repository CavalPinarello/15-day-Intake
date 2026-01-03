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
- **Bundle IDs:** iOS: `com.zoesleep.app`, Watch: `com.zoesleep.app.watchkitapp`

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

- **iPhone:** 14-day intake journey (PRIMARY)
- **Dashboard:** Clinician interface (IN DEVELOPMENT)
- **Web:** Debug/testing only
- **Watch:** PAUSED - branch `feature/watch-app-complete`

## Key Locations

| Platform | Path |
|----------|------|
| iOS | `/ZoeSleep/ZoeSleep/` |
| Watch | `/ZoeSleep/ZoeSleep Watch App/` |
| Web | `/client/src/app/` |
| Backend | `/convex/` |
| Docs | `/docs/` |

## Smart Questionnaire System

- **14-Day Journey:** Core (Days 1-7) + Conditional expansion (Days 8-15)
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
