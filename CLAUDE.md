# CLAUDE.md - Zoe Sleep V1 Quick Reference

> **Repository:** `Zoe-Sleep-V1` (renamed from `15-day-Intake` on Dec 11, 2025)

## 🚀 Essential Commands

```bash
# Start everything
npm run install:all && npm run dev

# Database setup (choose one)
cd server && npm run seed-adaptive  # Recommended: Smart adaptive system
cd server && npm run seed           # Legacy SQLite mode
npx convex dev && ./setup-convex.sh # Convex cloud mode
```

## 🔑 Critical Info

- **Test Users:** user1-user10, password: "1"
- **Database Mode:** Set `USE_CONVEX=true` in `/server/.env` for cloud mode
- **Xcode Project:** `/ZoeSleep/ZoeSleep.xcodeproj`
- **Bundle IDs:** iOS: `com.zoesleep.app`, Watch: `com.zoesleep.app.watchkitapp`

## 🌙 Sleep App Design Principle

**CRITICAL:** NO blue light after dusk (disrupts melatonin)
- **Day:** Blues/teals OK (alertness)
- **Night:** ONLY warm colors (amber/orange/brown)

## 🏗️ Platform Architecture

```
iPhone ←→ Convex ←→ Dashboard
(Full intake)      (Clinician view)
     ↓
 Web (Debug only)
```

- **iPhone:** Full 15-day intake journey with all questionnaires (PRIMARY)
- **Dashboard:** Clinician interface for patient data (IN DEVELOPMENT)
- **Web:** Debug/testing only, NOT for end users
- **Watch:** ⏸️ PAUSED - See recovery branch below

## 📁 Key Locations

- **iOS:** `/ZoeSleep/ZoeSleep/` (Swift/SwiftUI)
- **Watch:** `/ZoeSleep/ZoeSleep Watch App/` (watchOS)
- **Web:** `/client/src/app/` (Next.js - debug only)
- **Backend:** `/convex/` (serverless functions)
- **Docs:** `/docs/` (detailed documentation)

## 🧠 Smart Questionnaire System

- **15-Day Journey:** Core (Days 1-7) + Conditional expansion (Days 8-15)
- **10 Gateways:** Insomnia, Sleep Apnea, Mental Health, Pain, etc.
- **Daily Sleep Log:** 5 Stanford questions every morning
- **Load Balanced:** 11-17 questions per day (core), expansions add when triggered

### Day Distribution (Dec 13, 2025 Rebalance)
| Days | Type | Questions/Day |
|------|------|---------------|
| 1-7 | Core Assessment | 11-17 |
| 8-15 | Expansion Packs | 16-33 (conditional) |

## 📚 Documentation

- **Architecture:** [`/docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) - Detailed file structure
- **Patterns:** [`/docs/PATTERNS.md`](./docs/PATTERNS.md) - Development patterns & conventions
- **Sessions:** [`/docs/sessions/INDEX.md`](./docs/sessions/INDEX.md) - Development history
- **Setup:** [`/docs/setup/`](./docs/setup/) - Environment configuration
- **API:** [`/docs/api/`](./docs/api/) - API documentation

## ⚡ Current Focus

**Product:** Zoe Sleep - "Sleep Better, Live Longer"

**Priority (Dec 2025):**
1. iPhone app completion and polish
2. Clinician dashboard development
3. Backend API stability

**Latest Updates:**
- **Dashboard 360° View data pipeline:** Complete data flow from iOS mock generator to dashboard (Dec 18, 2025)
  - `healthkit:computeSleepMetricsFromResponses` - Computes sleep metrics from CSD_ responses
  - `physician:persistCalculatedScores` - Calculates and persists ISI/PHQ-9/GAD-7/ESS/STOP-BANG scores
  - `physician:getQuestionnaireResponses` - Retrieves individual questionnaire responses for detail views
  - Mock generator now populates `user_sleep_data` and `questionnaire_scores` tables
  - ScoreDetailModal shows individual question responses for clinical questionnaires
- **New branding and logo:** Spiral crescent moon logo implementation (Dec 18, 2025)
  - iOS: ZoeLogo.swift (SwiftUI vector component)
  - Web: ZoeLogo.tsx (React SVG component)
  - App icons: All iPhone/iPad/Watch sizes regenerated
  - Animated aurora borealis splash screen and login background
  - 2.5 second splash with luminescent wave animation
- **Question Manager enhancements:** Full question preview in physician dashboard (Dec 13, 2025)
  - Fixed "0 questions" bug - now shows computed counts
  - Expandable modules with full question lists
  - Gateway/expansion preview with trigger conditions
- **iOS smart task visibility:** Assessment task only shows if content exists (Dec 13, 2025)
  - Core days (1-7): Always show assessment
  - Expansion days (8-15): Only show if gateways triggered
  - Dynamic title (Core Assessment vs Expansion Pack)
- **Day-aware response storage:** Repeating questions (sleep log) now stored per day
- **Consensus Sleep Diary (CSD):** Full iOS sleep log integration with dashboard
- **Questionnaire day rebalance:** Split large modules, spread across all 15 days (Dec 13, 2025)
  - Day 1 reduced from 55 to 15 questions
  - No more empty days (was 0 questions on days 6, 8, 11, 14, 15)
  - Core assessment: Days 1-7 (11-17 questions each)
  - Expansion packs: Days 8-15 (conditional, 16-33 questions each)
- **Intervention library system:** Physician dashboard can assign interventions to patients (Dec 18, 2025)
  - 39 evidence-based interventions across 12 categories
  - 7 treatment bundles (Delayed Phase+Insomnia, Cardiometabolic, Fragile Sleeper, etc.)
  - AI-powered suggestions based on patient gateways and phenotypes
  - Seed: `npx convex run seedInterventionLibrary:seedAll`
- Repository renamed: `15-day-Intake` → `Zoe-Sleep-V1` (Dec 11, 2025)
- Fixed questionnaire navigation: Back button now properly respects section boundaries (Dec 12, 2025)
- Added save error handling: Retry dialogs for failed Convex syncs (Dec 12, 2025)
- Circadian picker styling: Time/date pickers now use warm amber colors at night (Dec 12, 2025)
- **Fixed pre-fill/fast-forward bug:** Questionnaire no longer auto-fills answers on fresh start (Dec 12, 2025)
- **User interaction tracking:** Only saves responses user explicitly touched; accepts smart defaults on Next tap
- **Smart defaults are scale-relative:** Default values now adapt to actual question scale range (1-5 vs 1-10)
- Onboarding: 8 steps, account-aware, circadian colors
- Cross-device sync: Question-by-question resume
- Day unlock: 4 AM (was 5 AM)

## ⏸️ Apple Watch (PAUSED)

**Status:** Development paused to prioritize iPhone/Dashboard
**Recovery Branch:** `feature/watch-app-complete`
**Documentation:** [`/docs/watch-app/WATCH-APP-IMPLEMENTATION.md`](./docs/watch-app/WATCH-APP-IMPLEMENTATION.md)

**What's Implemented (~85% complete):**
- Sleep Log questionnaire (5 Stanford questions)
- Direct Convex integration
- Cross-device auth sync
- Circadian theming
- Treatment tasks

**To Resume:**
```bash
git checkout feature/watch-app-complete
open ZoeSleep/ZoeSleep.xcodeproj
# Select "ZoeSleep Watch App" scheme
```

---

*For detailed information, see the documentation files linked above.*