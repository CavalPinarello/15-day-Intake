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

- **iPhone:** Full 14-day intake journey with all questionnaires (PRIMARY)
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

- **14-Day Journey:** Core (Days 1-5) + Conditional expansion (Days 6-14)
- **10 Gateways:** Insomnia, Sleep Apnea, Mental Health, Pain, etc.
- **Daily Sleep Log:** 5 Stanford questions every morning
- **Load Balanced:** 11-17 questions per day (core), expansions add when triggered

### Day Distribution (Dec 21, 2025 - Updated to 14 days)
| Days | Type | Questions/Day |
|------|------|---------------|
| 1-5 | Core Assessment | 7-12 |
| 6-14 | Expansion Packs | 7-35 (conditional) |

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
- **14-Day Journey Standardization:** Updated entire codebase from 15 to 14 days (Dec 21, 2025)
  - **Merged Day 14 & 15:** Final day now includes DASS-21, STOP-BANG, Berlin, BPI, MEDAS, MEQ
  - **Files updated:** Config.swift, QuestionnaireManager.swift, ContentView.swift, WatchHomeView.swift
  - **Convex updated:** ios.ts, watch.ts, web.ts, physician.ts, expansionScheduler.ts, testingAPI.ts
  - **Dashboard updated:** physician-dashboard/page.tsx, journey/page.tsx, patient/[id]/page.tsx
  - **Tests updated:** QuestionnaireManagerTests, ConvexServiceTests, IntegrationTests
  - **All progress indicators:** Now show "Day X of 14" consistently across iOS, Watch, and web
- **PSQI Core Assessment Fix:** PSQI now always generates as core (Days 1-2), not expansion (Dec 21, 2025)
  - Root cause: Mock generator only created PSQI when insomnia gateway triggered
  - PSQI Part 1 (PSQI_1-4) on Day 1, Part 2 (PSQI_5a-5j, PSQI_6-9) on Day 2
  - Added "Core" badge to PSQI in dashboard to distinguish from expansion questionnaires
- **Gateway→Questionnaire Mapping:** Added iOS gateway display showing triggered questionnaires (Dec 21, 2025)
  - New `triggeredQuestionnaires` and `questionnaireAbbreviations` properties on GatewayType
  - UnifiedDebugPanel shows which questionnaires each gateway triggers
  - Dashboard filter toggle for "Show only triggered" questionnaires
- **Enhanced Readability Mode for Elderly Users:** Instant accessibility system (Dec 21, 2025)
  - **Floating magnifying glass button:** Visible from splash screen, login, onboarding, and intro
  - **One-tap activation:** Single toggle enables 1.5x text, large icons, high contrast, reduced motion
  - **Entry points:** Splash screen (bottom-right), login, onboarding, journey intro, Settings > Accessibility
  - **Persistent:** Setting saved to UserDefaults, applied consistently across entire app
  - **Target audience:** Users in their 70s who need crystal-clear text and easier tapping
  - **Files:** `Views/Accessibility/EnhancedReadabilityOverlay.swift`, `ThemeManager.swift` (enhancedReadabilityMode)
  - **What it activates:** textSizeMultiplier=1.5, largeIconsMode=true, highContrast=true, reduceMotion=true
- **App Icon Alpha Channel Fix:** Removed transparency from all iOS app icons (Dec 21, 2025)
  - App Store validation was failing: "large app icon can't be transparent or contain an alpha channel"
  - Converted all 15 PNG icons through JPEG format to strip alpha channel
  - All icons now have `hasAlpha: no` while preserving visual appearance
  - **Files changed:** All icons in `ZoeSleep/ZoeSleep/Assets.xcassets/AppIcon.appiconset/`
- **Journey Introduction Sequence:** 6-screen Aurora-animated intro for new users (Dec 21, 2025)
  - Full-screen modal on first MainDashboard visit with swipeable pages
  - **Aurora borealis background:** Matches splash screen aesthetic with animated waves and stars
  - **Content:** Explains 14-day journey, 10 Stanford Sleep Diary questions (repeated daily), personalized gateways, wearable integration, and expert review
  - **Time framing:** "10-15 minutes daily investment" for better subjective calibration
  - Skip button available; marks as seen via `OnboardingManager.hasSeenJourneyIntro`
  - **Files:** `JourneyIntroView.swift`, `JourneyIntro/JourneyIntroScreens.swift`, `JourneyIntro/JourneyIntroIcons.swift`
- **Build Fixes:** Resolved multiple compilation errors (Dec 21, 2025)
  - `QuestionnaireManager.swift`: Fixed `SleepPillar` → `Pillar` type, `optionalContextQuestions` → `sleepContextQuestions`
  - `ConvexService.swift`: Added Codable response types for journey phase APIs
  - `JourneyPhaseManager.swift`: Updated to use struct property access instead of dictionary subscripts
  - `ColorTheme`: Added `primaryText`, `secondaryText`, `backgroundGradient` aliases
  - `ChallengesView.swift`: Fixed `AnyShapeStyle` type mismatch
- **Dashboard Progress Indicator Fix:** Fixed 3 bugs in journey progress card (Dec 21, 2025)
  - **40% progress on Day 1:** Was using `completedDays.count` from corrupted backend data; now uses `currentDay - 1`
  - **Day 7 dot highlighted:** Was passing `completedDaysCount + 1` to dots; now uses `currentDay` directly
  - **Flickering motivational message:** `randomDayMessage()` called every render; now stored in `@State`
  - **Data integrity guard:** Added `validatedCompletedDays` filter to sanitize corrupted backend data
  - **Files changed:** ContentView.swift
- **Measurement System & Body Metrics Overhaul:** Proper height/weight handling (Dec 20, 2025)
  - **Measurement system from locale:** Auto-detects Metric/Imperial from device locale (US = Imperial)
  - **User can change units:** Picker in onboarding Body Metrics step AND in Profile settings
  - **Height/weight now optional:** `nil` by default, shows "Not set" in Profile if never provided
  - **Tap-to-edit:** Profile > Height/Weight opens BodyMetricsEditorView with sliders/pickers
  - **HealthKit integration:** If connected, height/weight auto-filled from Apple Health
  - **Files changed:** OnboardingManager.swift, ProfileSettingsView.swift, OnboardingView.swift
  - **New views:** DebugDataView.swift, NotificationsSettingsView.swift
  - **Archived:** SettingsView.swift (replaced by ProfileSettingsView)
- **"From Gamification to Indispensability" System:** Complete personalization engine (Dec 20, 2025)
  - **Micro-Cohorts ("People Like You"):** Dynamic peer groups based on 8 dimensions
    - Age, gender, life stage, work pattern, gateway, chronotype, activity, family
    - Percentile comparisons within peer groups (not generic population)
    - `convex/microCohorts.ts`, `convex/cohortCompute.ts`
  - **Sleep Fingerprint ("This is who you are"):** Phenotype classification
    - 9 phenotypes: tired_but_wired, sleep_state_misperception, compensator, etc.
    - 8 pattern detectors with evidence collection
    - `convex/sleepPhenotype.ts`
    - iOS: `SleepFingerprintCard.swift`, Web: `SleepFingerprintCard.tsx`
  - **Personalized Insights ("The Aha Factory"):** 100+ evidence-based messages
    - Categories: demographic, gateway, pattern, cohort, prediction, solidarity
    - Relevance scoring based on user profile matching
    - `convex/insightLibrary.ts`
  - **Anticipation Engine ("What's Coming"):** Predictive sleep forecasting
    - Tonight's forecast based on 5 factors (day of week, activity, stress, consistency, weekend)
    - Lifecycle-aware messaging (discovery → patterns → insights → treatment)
    - Weekly progress summaries with trend analysis
    - `convex/anticipationEngine.ts`
- **Post-Intake Experience:** Complete treatment journey implementation (Dec 20, 2025)
  - **Journey Phases:** intake → analysis → treatment_pending → treatment_active
  - **Progressive Insights:** Countdown and discovery teasers during Days 1-14
  - **Analysis Pending View:** 4-stage timeline (data collected → patterns → preparing → ready)
  - **Treatment Dashboard:** Session-based cards (Morning/Afternoon/Evening/Night)
  - **Time-Windowed Tasks:** Tasks only completable during scheduled time windows
  - **New Convex APIs:** `convex/journey.ts`, `convex/insights.ts` (phase management, teasers)
  - **iOS:** JourneyPhaseManager.swift, AnalysisPendingView.swift, TreatmentDashboardView.swift
  - **Dashboard:** PatientJourneyStatus.tsx, InterventionTimeWindows.tsx
  - Physicians can advance analysis stages and assign time windows to interventions
- **Sleep Insights Bug Fix & Repair Tool:** Fixed "0 days" bug in Sleep Insights (Dec 20, 2025)
  - Root cause: Mock data generator created questionnaire responses but not `user_sleep_data` entries
  - Added `healthkit:computeAllSleepMetricsFromResponses` - retroactively computes sleep metrics from CSD_ responses
  - Added "Repair Sleep Insights" button in iOS Profile > Developer section
  - Computes total sleep, efficiency, stages, latency from questionnaire data
- **Micro-Cohort System Schema:** "People Like You" dynamic peer groups (Dec 20, 2025)
  - `user_cohort_memberships` - User's cohort based on demographics, gateways, chronotype
  - `cohort_aggregate_stats` - Percentile comparisons, improvement rates
  - `user_sleep_narrative` - Personalized sleep phenotype and narrative
- **Cross-Platform Questionnaire Audit & Fix:** Complete scoring system verification (Dec 20, 2025)
  - Fixed STOP-BANG scoring: Now uses SB_1-8 IDs (was broken with numeric IDs)
  - Added 4 new scoring functions: PROMIS Cognitive, Sleep Hygiene, PSAS (cognitive+somatic)
  - Fixed PSQI Component 5: Prorated scoring for fewer disturbance questions
  - Added 16 missing expansion modules to iOS QuestionnaireManager
  - Updated physician dashboard ScoreDetailModal with 12 new questionnaire thresholds
  - Verified gateway detection works correctly across iOS → Convex → Dashboard
- **Developer Mode for Testers:** Physician dashboard toggle for fast-track testing (Dec 19, 2025)
  - Toggle developer mode on/off per patient from patient detail page
  - Jump to any day (1-15) instantly when developer mode is enabled
  - Purple badge in patient list indicates dev mode active
  - Skip time gates and section completion for rapid testing
  - Mutations: `toggleDeveloperMode`, `setPatientDay`, `getDeveloperModeStatus`
- **Gamification System (Schema):** "Strava for Sleep" tables added (Dec 19, 2025)
  - User streaks, badges, XP/levels, and challenges
  - Evidence-based encouragement message library
  - Cohort statistics for anonymous comparisons
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
  - Expansion days (6-14): Only show if gateways triggered
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