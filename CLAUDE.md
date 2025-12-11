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

- **15-Day Journey:** Core (Days 1-5) + Conditional expansion (Days 6-15)
- **10 Gateways:** Insomnia, Sleep Apnea, Mental Health, Pain, etc.
- **Daily Sleep Log:** 5 Stanford questions every morning
- **Load Balanced:** 7-29 questions per day based on triggers

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
- Repository renamed: `15-day-Intake` → `Zoe-Sleep-V1` (Dec 11, 2025)
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