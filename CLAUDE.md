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
- **New User Registration:** Email + password only (username auto-generated from email)
- **Database Mode:** Set `USE_CONVEX=true` in `/server/.env` for cloud mode
- **Xcode Project:** `/ZoeSleep/ZoeSleep.xcodeproj`
- **Bundle IDs:** iOS: `com.zoesleep.app`, Watch: `com.zoesleep.app.watchkitapp`

## 🌙 Circadian Design System (CRITICAL)

**EVERY new component MUST follow circadian design principles.**

### The 8-Phase Day (Smooth Color Interpolation)
Colors interpolate smoothly between phases - NO discrete jumps!

| Phase | Time | Background | Accent | Blue Light |
|-------|------|------------|--------|------------|
| Pre-Dawn | 4-5:30 AM | Very dark warm | Deep amber | ✅ OK |
| Dawn | 5:30-7:30 AM | Warm cream | Golden amber | ✅ OK |
| Morning | 7:30-11 AM | Light sky blue | Sky blue | ✅ OK |
| Midday | 11 AM-2 PM | Bright cyan tint | Cyan | ✅ OK |
| Afternoon | 2-5 PM | Warm cream | Amber | ✅ OK |
| Dusk | 5-7 PM | Dark orange-brown | Orange | ❌ NO BLUE |
| Evening | 7-10 PM | Dark warm brown | Warm amber | ❌ NO BLUE |
| Night | 10 PM-4 AM | Very dark warm | Warm amber | ❌ NO BLUE |

### Key Implementation Files
- **CircadianPalette:** `QuestionModels.swift` - 8-phase color interpolation
- **ColorTheme:** `QuestionModels.swift` - Uses palette for all colors
- **ThemeManager:** `ThemeManager.swift` - Updates every 60 seconds

### Color Usage Rules
1. **Always use `theme.primaryText`** for text on backgrounds (interpolates automatically)
2. **Always use `theme.cardBackground`** for cards (dark in evening, light in morning)
3. **Always use `theme.textOnPrimary`** for text on accent-colored buttons
4. **Use `theme.accent`** for interactive elements (adapts to time)
5. **Use `theme.backgroundGradient`** for full-screen backgrounds

### Developer Checklist for New Components
- [ ] Uses `theme.primaryText` / `theme.secondaryText` for all text
- [ ] Uses `theme.cardBackground` for card backgrounds
- [ ] Uses `theme.accent` for interactive elements
- [ ] Uses `theme.textOnPrimary` for button labels
- [ ] NO hardcoded blue/purple colors after dusk (check `isDarkPhase`)
- [ ] Tested at evening time (after 5 PM) for legibility

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
- **Comprehensive Questionnaire Scale Labels Fix:** Replaced all "Minimum/Maximum" slider labels with clinical descriptors (Dec 27, 2025)
  - **Problem:** Slider questions showed useless "Minimum/Maximum" labels instead of meaningful clinical descriptors
  - **Fixed 14+ questionnaire types** with proper labels from official publications:
    | Questionnaire | Scale | Labels |
    |--------------|-------|--------|
    | ISI | 0-4 | None → Mild → Moderate → Severe → Very Severe |
    | DBAS-16 | 0-10 | Strongly Disagree → Strongly Agree |
    | Sleep Hygiene | 1-5 | Never → Rarely → Sometimes → Frequently → Always |
    | PSAS | 1-5 | Not at all → Slightly → Moderately → A lot → Extremely |
    | PHQ-9/GAD-7 | 0-3 | Not at all → Several days → More than half → Nearly every day |
    | DASS-21 | 0-3 | Not at all → Sometimes → Often → Almost always |
    | ESS | 0-3 | No chance → Slight → Moderate → High chance |
    | FSS | 1-7 | Strongly Disagree → Strongly Agree |
    | FOSQ | 1-4 | No difficulty → Mild → Moderate → Extreme difficulty |
    | PROMIS Cognitive | 1-5 | Never → Rarely → Sometimes → Often → Very often |
    | Berlin | 1-5 | Never → Nearly every day (frequency) |
    | BPI | 0-10 | No pain → Worst pain imaginable |
    | MEQ | 1-4 | Chronotype-specific labels (e.g., Very tired → Very refreshed) |
  - **File changed:** `data/converted/assessment_questions_converted.json`
  - **IMPORTANT:** After modifying JSON, run `npx convex run seedQuestions:seedAll` to update database
- **Smart Question Derivation:** Reduce user burden by deriving redundant questions from Sleep Log (Dec 27, 2025)
  - **Problem:** Questions 12A (# awakenings), 12C (time to fall back asleep) asked in Assessment despite same data being in Sleep Log
  - **Derivation System:** Added 12A and 12C to `derivableFromSleepLog` set in QuestionnaireManager.swift
  - **New functions:** `derive12AFromSleepLog()` gets awakenings from `CSD_AWAKENINGS`, `derive12CFromSleepLog()` calculates avg time = `CSD_WASO / CSD_AWAKENINGS`
  - **Conditional logic:** 12B (reason for waking) now only shows if user reported awakenings > 0
  - **Scale labels fix:** `convertConvexQuestion()` now extracts `scaleMin`/`scaleMax`/`labels` from Convex format
  - **iOS→Convex format mapping:** Convex uses `scaleMin`/`scaleMax`/`labels[]`, iOS expected `min`/`max`/`minLabel`/`maxLabel`
  - **Files changed:** `QuestionnaireManager.swift` (+50 lines derivation), `QuestionnaireView.swift` (formatConfig extraction)
- **Dynamic Task Counter & Expansion Pack Integration:** Complete task tracking system for iOS and Watch (Dec 27, 2025)
  - **Problem:** Task count was static "1 of 2" even when expansion packs triggered; no-gateway days showed misleading "Assessment: Pending"
  - **Dynamic task count:** Now shows "1 of 1" (no assessment), "2 of 2" (with assessment), or "2 of 3" (with expansion pack)
  - **iOS ContentView.swift:** Updated `totalTaskCount`, `completedTaskCount`, and `isDayComplete` to include expansion packs
  - **No-gateway UX:** New `NoAssessmentTodayView` component shows "You're on track!" message when no assessment needed
  - **Debug Tools fix:** `UnifiedDebugPanel.swift` now shows "None (0 gateways)" instead of misleading "Pending"
  - **Countdown timer:** Now displays correctly when day is complete (was blocked by incorrect `isDayComplete` logic)
  - **Watch app sync:** `WatchHomeView.swift` shows same task count as iPhone; new "Deeper Dive" task row with purple sparkles
  - **Backend update:** `watch.ts:getJourneyState` now returns `hasExpansionPackToday` and `expansionPackCompleted`
  - **Schema update:** Added `expansion_pack_completed` field to `user_progress` table
  - **Files changed:** `ContentView.swift`, `UnifiedDebugPanel.swift`, `WatchHomeView.swift`, `WatchConvexService.swift`, `watch.ts`, `schema.ts`
- **New Zoe Logo & App Icons:** Updated all app icons with new spiral crescent moon logo from official brand SVG (Dec 27, 2025)
  - **Logo source:** Frame 3.svg - spiral crescent moon design
  - **Color scheme:** Warm cream (#F5E6D3) on dark warm brown gradient (#1a1512 to #0d0a08)
  - **iOS icons:** 15 icons regenerated (20x20 to 1024x1024) - RGB, no alpha channel
  - **Watch icons:** 17 icons regenerated (24x24@2x to 1024x1024) - RGB, no alpha channel
  - **ZoeLogo.swift:** Complete rewrite with exact SVG path recreation
    - `ZoeLogoSVG` - Pixel-perfect SVG path implementation
    - `ZoeLogoSimple` - Performance-optimized circle approximation
    - `OuterCrescentShape` / `InnerCrescentShape` - Shape primitives
  - **SplashScreenView.swift:** Updated to use `ZoeLogoSVG` with warm cream color
  - **AuthenticationView.swift:** Updated to use `ZoeLogoSVG` with warm cream color
  - **Icon generation script:** `scripts/generate-icons.sh` - regenerates all icons from SVG
  - **No alpha channel:** All icons are 8-bit RGB (avoids App Store rejection)
- **Expansion Pack Splash Screens:** Educational rationale screens for all 16 validated questionnaires (Dec 27, 2025)
  - **Purpose:** When users encounter expansion packs (Days 6-14), they now see a splash screen explaining why they're being asked these questions
  - **Content per questionnaire:** Full name, abbreviation, citation count, what it measures, why we're asking, scientific background (authors, year, journal, sensitivity/specificity, Cronbach's α)
  - **16 validated instruments:** ISI (2,500+ citations), DBAS-16 (1,000+), SHI (500+), PSAS (800+), ESS (10,000+), FSS (7,000+), FOSQ-10 (500+), PHQ-9 (15,000+), GAD-7 (10,000+), DASS-21 (20,000+), PROMIS-Cog (2,000+), STOP-BANG (5,000+), Berlin (3,000+), BPI (6,300+), MEDAS (1,500+), MEQ (4,000+)
  - **Single vs Multi-day:** Single questionnaire shows detailed view; multi-questionnaire days show summary list with stats
  - **Triggered gateways:** Explains which gateway triggered the assessment (e.g., "Based on your responses about insomnia...")
  - **Once per day:** Splash only shown once per day (tracked via UserDefaults)
  - **Convex integration:** Added `modules` field to metadata in `watch.ts:getQuestionsForUserDay`
  - **New file:** `ZoeSleep/ZoeSleep/Views/ExpansionQuestionnaireSplash.swift` (~700 lines)
  - **Modified:** `QuestionnaireView.swift` (splash integration), `ConvexService.swift` (modules field)
- **Physician Review Checklist UX Improvement:** Expandable review sections in analysis workflow (Dec 27, 2025)
  - **Problem:** Review Checklist only had checkboxes - physicians had to navigate away to see actual data
  - **Solution:** Click-to-expand sections that show data inline without leaving the workflow
  - **SleepDataReview:** Shows avg duration, quality, awakenings, efficiency + day-by-day breakdown
  - **QuestionnaireScoresReview:** All 18 questionnaire scores with severity indicators (Normal/Mild/Moderate/Severe)
  - **GatewayTriggersReview:** Shows 6 gateways with triggered/not triggered status and scores
  - **Auto-mark reviewed:** Items auto-check after 2 seconds of viewing expanded content
  - **Summary previews:** Shows key stats in collapsed state (e.g., "14 days • Avg 6.2h • Quality 3.2/5")
  - **New files:** `client/src/components/patient/review/ReviewSection.tsx`, `SleepDataReview.tsx`, `QuestionnaireScoresReview.tsx`, `GatewayTriggersReview.tsx`
  - **Modified:** `client/src/components/patient/PatientAnalysisWorkflow.tsx`
- **Overdue Expansion Pack Tracking:** Full tracking for incomplete expansion packs from previous days (Dec 24, 2025)
  - **Problem:** Users could trigger expansion packs on Day N but advance to Day N+1 without completing them, with no visibility
  - **Backend:** `ios.ts:getDailyCompletionStatus` now returns `overdueExpansions[]` with dayNumber, triggeredGateways, questionCount, answeredCount, estimatedMinutes
  - **Backend:** `watch.ts:getJourneyState` now returns `overdueExpansionsCount` for Watch reminder
  - **iOS Dashboard:** Purple "Overdue Deep Dives" card shows incomplete expansion packs with progress and time estimates
  - **iOS Navigation:** Tap overdue expansion to jump directly to catch-up questionnaire for that day
  - **Watch App:** Purple reminder card shows count of overdue packs with "Complete on iPhone" indicator
  - **Files changed:** `convex/ios.ts`, `convex/watch.ts`, `ContentView.swift` (+160 lines), `ConvexService.swift`, `WatchConvexService.swift`, `WatchHomeView.swift`
- **Next Button UX Fix:** Questions with default values no longer require interaction to proceed (Dec 24, 2025)
  - **Problem:** Number inputs (e.g., "How many hours looking at screens?") showed default value (6) but Next button was disabled until user changed it
  - **Fix:** `canProceed` in `QuestionnaireView.swift` now returns `true` for `.number` and `.numberScroll` types
  - **Smart default saving:** When user taps Next without interacting, the visible default value is saved automatically
  - **Watch app:** Same fix applied to `isCurrentQuestionAnswered()` for time, scale, and number questions
  - **Files changed:** `QuestionnaireView.swift` (iOS), `QuestionnaireView.swift` (Watch)
- **Sleep Log Completion Persistence:** Section completion now saves immediately when showing completion screen (Dec 24, 2025)
  - **Problem:** Completing Sleep Log showed "Complete!" but tapping back instead of "Proceed to Assessment" didn't persist completion
  - **Fix:** Added `completeSectionInBackground()` that syncs responses and marks section complete immediately when completion screen appears
  - **Impact:** Users can tap back after completing Sleep Log and dashboard correctly shows it as done
  - **Files changed:** `QuestionnaireView.swift` (+60 lines)
- **AI Analysis Configuration System:** Complete LLM settings management for physician dashboard (Dec 23, 2025)
  - **System Settings Table:** New `system_settings` table in schema for storing API keys and model preferences
  - **Model Selection:** Primary + fallback model configuration with latest models:
    - Anthropic: Claude Opus 4.5, Sonnet 4.5, Opus 4, Sonnet 4, Sonnet 3.5
    - OpenAI: GPT-5.2 (Thinking/Instant/Pro), GPT-5.1, GPT-4o, GPT-4o Mini
  - **API Key Management:** Secure storage with masked display (shows only last 4 chars)
  - **Test Connection:** Validate API keys before saving
  - **Preview Analysis Prompt:** Button to see full system/user prompt before running analysis
  - **Token/Cost Estimates:** Shows estimated tokens and cost in preview modal
  - **Backend files:** `convex/systemSettings.ts` (new), `convex/llm.ts` (updated)
  - **UI location:** `/physician-dashboard/settings` - AI Configuration section
- **HealthKit Authorization Fix:** Fixed misleading "Connected" status in onboarding (Dec 23, 2025)
  - **Root cause:** iOS `requestAuthorization()` returns `success=true` when dialog is SHOWN, not when user GRANTS permission
  - **Fix:** Added `verifyDataAccess()` that attempts actual data read to verify true access
  - **New status states:** `notConnected`, `connecting`, `connected`, `denied`, `unavailable`
  - **UI improvements:** Orange warning when denied, "Open Settings" link, option to continue without data
  - **Files changed:** `HealthKitManager.swift` (+70 lines), `OnboardingView.swift` (redesigned HealthConnectStepView), `HealthKitIntegrationView.swift`
  - **Impact:** Users now see accurate connection status instead of false "Connected" message
- **Admin Tools Dashboard:** Comprehensive admin toolkit for physician dashboard (Dec 22, 2025)
  - **New page:** `/physician-dashboard/admin` - Full user management interface
  - **User operations:** Delete users, reset passwords, reset progress, change roles, toggle dev mode
  - **Bulk actions:** Select multiple users, bulk delete, purge by pattern
  - **Three purge options:** `user1-10` only, `test_*` only, or ALL test users combined
  - **System stats:** Total users, active users (7 days), role distribution, response counts
  - **Backend functions:** `convex/admin.ts` with deleteUser, resetUserPassword, purgeTestUsers, purgeGeneratedTestUsers, purgeAllTestUsers
  - **Files changed:** `convex/admin.ts`, `client/src/app/physician-dashboard/admin/page.tsx`, all physician dashboard pages (nav link)
- **Email-Only Registration:** Simplified sign-up to email + password only (Dec 22, 2025)
  - **Removed username field:** Users no longer need to choose a username
  - **Auto-generated username:** Created from email prefix (e.g., "john" from "john@example.com")
  - **Better error handling:** Convex error responses now properly detected and displayed
  - **Custom JSON decoder:** ConvexUser now handles missing optional fields gracefully
  - **Files changed:** AuthenticationView.swift, AuthenticationManager.swift, ConvexService.swift, ios.ts
- **CRITICAL: Circadian Text Contrast Fix:** Permanent fix for dark text on dark background issue (Dec 22, 2025)
  - **Root cause:** `ColorTheme` text colors checked `accentColorOption` but backgrounds (DashboardWaveBackground, GlassyCardBackground) ALWAYS use circadian colors
  - **Problem:** In non-circadian mode (default), text was dark system color but background was dark brown → invisible text
  - **Fix:** All text color properties now check `CircadianPalette.current.isDark` FIRST, regardless of appearance mode
  - **Fixed properties:** `textPrimary`, `textSecondary`, `textMuted`, `textOnCard`, `textOnCardSecondary`, `textOnCardMuted`
  - **Key change:** When `isDark == true`, text uses bright warm cream/amber from CircadianPalette, not system colors
  - **Files changed:** `QuestionModels.swift` (ColorTheme struct)
  - **Permanent:** Fix applies regardless of ThemeManager.appearanceMode setting
- **Sleep Diary Layout Fix:** Fixed content cropping on left edge (Dec 22, 2025)
  - **Root cause:** Horizontal ScrollView for day selector conflicted with parent padding
  - **Fix:** Added negative margin on ScrollView with compensating content padding
  - **Implementation:** `.padding(.horizontal, -16)` on ScrollView, `.padding(.horizontal, 16)` on content
  - **Files changed:** `ContentView.swift` (SleepDiaryHistoryView)
- **8-Phase Circadian Color System:** Complete redesign for smooth day-to-night transitions (Dec 22, 2025)
  - **CircadianPalette:** New struct with 8 phases (pre-dawn → dawn → morning → midday → afternoon → dusk → evening → night)
  - **Smooth interpolation:** Colors blend gradually using Hermite interpolation (no discrete jumps)
  - **Seasonal awareness:** Sunrise/sunset times adjust based on day of year
  - **Auto-updates:** ThemeManager refreshes every 60 seconds for smooth transitions
  - **High contrast:** Evening/night text uses bright warm cream on dark brown backgrounds
  - **Files changed:** `QuestionModels.swift` (+300 lines), `ThemeManager.swift`, `AnalysisPendingView.swift`
  - **Usage:** All views now use `theme.primaryText`, `theme.cardBackground`, `theme.accent` which auto-interpolate
- **Unified Debug Panel:** Consolidated all developer tools into single panel (Dec 22, 2025)
  - **Replaced 3 scattered views:** DevPanelView, MockPlaybackView entry, ExpansionSchedulerTestView entry
  - **4 generation modes:** Full Journey (Random), Max Load (All Gateways), Selective (Choose Gateways), Quick Test (Days 1-5)
  - **Gateway selection:** Toggle individual gateways with icons, colors, and trigger descriptions
  - **Schedule preview:** Shows expansion schedule for Days 6-14 with question counts per day
  - **Journey controls:** Advance day, reset progress, refresh from server, repair tools
  - **New file:** `DevTools/UnifiedDebugPanel.swift` (575 lines)
  - **Simplified ProfileSettingsView:** Developer section now has just 3 items
- **Fixed 93% Completion Bug:** Day 14 completion now shows 100% (Dec 22, 2025)
  - **Root cause:** `progressPercentage` used `currentDay - 1` regardless of whether current day was complete
  - **Fix:** Now checks `isDayComplete` and includes current day in count if both sections done
  - **Impact:** When all 14 days complete, shows 100% instead of 93%
- **Fixed Sleep Log Refresh Issue:** Today's Focus now updates immediately after Sleep Log completion (Dec 22, 2025)
  - **Root cause:** 2-second throttle in `refreshFromConvex()` was blocking notification-triggered refreshes
  - **Fix:** Added `force` parameter to bypass throttle for explicit completion notifications
  - **Impact:** Completing Sleep Log manually now immediately shows as "Done" on Today's Focus
- **GatewayType Extensions:** Added UI properties to QuestionModels.swift (Dec 22, 2025)
  - `icon`: SF Symbol for each gateway (moon.zzz, cloud.rain, exclamationmark.triangle, etc.)
  - `color`: SwiftUI Color for each gateway (purple, blue, red, etc.)
  - `triggerDescription`: Human-readable trigger condition
  - `triggeredQuestionnaires`: List of questionnaires triggered by each gateway
  - `questionnaireAbbreviations`: Compact display format for questionnaire lists
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