# CLAUDE.md - Zoe Sleep V1 Quick Reference

> **Repository:** `Zoe-Sleep-V1` | **Full changelog:** [`docs/CHANGELOG.md`](./docs/CHANGELOG.md)

## Essential Commands

```bash
npm run install:all && npm run dev    # Start everything
npx convex dev && ./setup-convex.sh   # Convex cloud mode
```

## Critical Info

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

- **14-Day Journey:** Core (Days 1-5) + Conditional expansion (Days 6-14)
- **10 Gateways:** Insomnia, Sleep Apnea, Mental Health, Pain, etc.
- **Daily Sleep Log:** 5 Stanford questions every morning

## Documentation

- **Architecture:** [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md)
- **Patterns:** [`docs/PATTERNS.md`](./docs/PATTERNS.md)
- **Changelog:** [`docs/CHANGELOG.md`](./docs/CHANGELOG.md)
- **Sessions:** [`docs/sessions/INDEX.md`](./docs/sessions/INDEX.md)

## Current Focus (Dec 2025)

1. iPhone app completion and polish
2. Clinician dashboard development
3. Backend API stability

## Recent Updates

See [`docs/CHANGELOG.md`](./docs/CHANGELOG.md) for complete history.

**Dec 29:** Comprehensive debug reset fix (Clinical Scores + all dashboard data), time picker defaults for dependent questions fix, dashboard pillar completion UI (neutral amber), Sleep Health Factors dashboard module, iOS complex response serialization fix, unified body metrics slider UI, auto-derivable questions
**Dec 28:** Expansion pack slider UX fix, journey intro flow, fresh install detection, dashboard UX redesign
**Dec 27:** Day type analysis, nap/medication tracking, scale labels fix, dynamic task counter, new logo
**Dec 22:** 8-phase circadian system, text contrast fix, unified debug panel, admin tools

---

*For detailed documentation, see the `/docs/` directory.*
