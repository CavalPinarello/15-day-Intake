# Changelog - Zoe Sleep V1

> Complete development history. For quick reference, see [CLAUDE.md](../CLAUDE.md).

## January 2026

### Jan 3, 2026

#### Fix Day Advancement Bug for Expansion Days Without Assessments

Fixed critical bug where users couldn't advance to the next day when the current expansion day had no assessments scheduled for their triggered gateways.

**Problem:**
- Day 10 only shows content for `excessive_sleepiness` gateway (ESS + FSS packs)
- If user triggered `pain` but not `excessive_sleepiness`, Day 10 has no assessments
- Old code checked if ANY gateways were triggered globally and required `assessmentCompleted = true`
- Since there was no assessment to complete, the "Advance to Day 11" button didn't work
- Users could only advance by tapping the manual day dots

**Root Cause:**
In `convex/watch.ts`, both `canAdvanceDay` query and `advanceDay` mutation used:
```typescript
const triggeredCount = userGateways.filter((g) => g.triggered).length;
hasAssessmentToday = triggeredCount > 0;
```
This checked if ANY gateways were triggered, not if the SPECIFIC day had content.

**Fix:**
Changed both functions to use `shouldShowExpansion()` from `fixedSchedule.ts`:
```typescript
const triggeredGateways = userGateways
  .filter((g) => g.triggered)
  .map((g) => g.gateway_id);
hasAssessmentToday = shouldShowExpansion(currentDay, triggeredGateways);
```

This uses the fixed schedule to check if the specific day has content for the user's triggered gateways (e.g., Day 10 requires `excessive_sleepiness` gateway).

**Files changed:** `convex/watch.ts` (lines 1999-2015, 2155-2171)

---

#### Watch-Style Check-In Widget Improvements

Enhanced the "Today's Focus" check-in widget for better visibility and instant feedback.

**UI/UX Improvements:**
- Renamed widget title to "Today's Focus" with subtitle "Energy · Mood · Focus"
- Theme-aware colors for morning/midday/evening indicators - adapts to circadian phase
- Increased contrast for inactive slots using `theme.primaryText` and `theme.secondaryText`
- Subtle background fill on inactive circles for better definition
- Reordered dashboard: Journey Progress → Today's Focus → Other cards

**State Management:**
- Optimistic state updates - UI shows completion immediately before Convex confirms
- Reverts gracefully on network errors
- `onChange` listener refreshes status when check-in sheet dismisses
- `onAppear` loads today's status from Convex

**Backend (Convex):**
- `submitMiddayCheckIn`: Added `moodLevel` and `focusLevel` optional parameters
- `submitEveningCheckIn`: Added `energyLevel`, `moodLevel`, `focusLevel` optional parameters
- `getCheckInHistory`: Returns all energy/mood/focus data per time slot for physician dashboard

**Enum Alignment (iOS ↔ Watch):**
- `FocusLevel`: Reduced from 6 to 5 levels to match Watch (foggy, hazy, clearing, clear, crystal)
- `MoodLevel`: Fixed `partlyCloudy` → `partlySunny` to match Watch naming

**Files changed:** `QuickCheckInWidget.swift`, `CheckInManager.swift`, `SharedCheckInModels.swift`, `ContentView.swift`, `convex/checkIn.ts`

---

### Jan 2, 2026

#### Parked XP/Gamification Feature

Disabled the XP points and gamification system via a feature flag for future re-enablement.

**Changes:**
- Added `gamificationEnabled` flag to ThemeManager (default: `false`)
- Guarded all gamification code in QuestionnaireView with feature flag check
- Badge unlock and level up animations only show when enabled
- `recordDayComplete()` calls wrapped in feature flag check
- Added toggle in Debug Panel > Experimental Features for easy re-enablement

**Why parked:**
- XP status wasn't visible anywhere in the app UI
- Feature didn't add much value in current state
- Code preserved for potential future iteration

**Files changed:** `ThemeManager.swift`, `QuestionnaireView.swift`, `UnifiedDebugPanel.swift`

---

#### Unified Time Format System (12-hour/24-hour)

Fixed TimeFormatManager not being found by Xcode and updated all time pickers to respect the user's 12-hour/24-hour preference.

**Problem:**
- TimeFormatManager was in Shared folder but not properly linked to iOS target
- Watch app time picker was hardcoded to 12-hour format only
- iOS DatePickers ignored app preference and used device locale regardless

**Solution:**
- Moved TimeFormatManager to `ZoeSleep/Utilities/` for iOS target
- Created separate TimeFormatManager in `ZoeSleep Watch App/` for Watch target
- Updated Watch `WatchTimePickerView` to support both 12-hour and 24-hour modes:
  - 12-hour mode: Hour (1-12) + Minute + AM/PM picker
  - 24-hour mode: Hour (00-23) + Minute (no AM/PM)
- **iOS DatePicker Fix:** Added `.environment(\.locale, pickerLocale)` to all DatePickers:
  - Uses `en_US` locale for 12-hour format (forces AM/PM)
  - Uses `en_GB` locale for 24-hour format (forces 00:00-23:59)
  - System default option uses device's actual locale
- User can override in Settings (System Default / 12-hour / 24-hour)

**Files changed:** `TimeFormatManager.swift`, `QuestionComponents.swift`, `NotificationsSettingsView.swift`, `MiddayCheckInView.swift`, Watch `QuestionnaireView.swift`, `WatchQuestionComponents.swift`

---

#### Notification Message Variety & Check-In Infrastructure

Implemented 100 rotating notification messages to prevent user desensitization and added infrastructure for Watch-style check-ins on iOS.

**100 Varied Morning Messages:**
- Friendly greetings (20 messages)
- Motivational messages (20 messages)
- Question-based prompts (20 messages)
- Health-focused messages (20 messages)
- Gentle reminders (20 messages)
- Each notification randomly selects a message to keep engagement fresh

**Watch-Style Check-In Support:**
- Added `EnergyLevel`, `MoodLevel`, `FocusLevel` enums to iOS (mirrors Watch types)
- `CheckInManager` now tracks last energy/mood/focus levels for trend display
- New `CheckInTimeSlot` enum for morning/midday/evening check-ins
- Infrastructure ready for Watch sync and unified check-in experience

**Notification Settings UI:**
- Settings now shows actual scheduled notification times
- Displays formatted times (e.g., "7:30 AM", "2:00 PM", "9:00 PM")
- Better user understanding of when notifications will arrive

**Files changed:** `NotificationManager.swift`, `CheckInManager.swift`, `NotificationsSettingsView.swift`, `WatchConnectivityManager.swift`, `ConvexService.swift`

---

#### Unit-Aware Help Text for Temperature Question

Added support for imperial-specific help text on questions with unit switching (temperature Q33A).

**Problem:**
- Temperature question (Q33A) showed both °C and °F in help text regardless of user's preference
- Example: "Ideal sleep temperature is 16-19°C (60-67°F)" when user had Imperial selected

**Solution:**
- Added `helpTextImperial` field to Question model and Convex schema
- QuestionCard now checks user's `measurementSystem` preference and shows appropriate help text
- Q33A help text now shows only the relevant unit based on preference

**Changes:**
- **iOS:** Added `helpTextImperial` to `Question` struct, `ConvexQuestion`, and `QuestionCard`
- **Convex:** Added `help_text_imperial` field to `assessment_questions` and `sleep_diary_questions` tables
- **Data:** Updated Q33A with separate metric ("16-19°C") and imperial ("60-67°F") help texts

**Files changed:** `QuestionModels.swift`, `QuestionComponents.swift`, `ConvexService.swift`, `QuestionnaireView.swift`, `schema.ts`, `watch.ts`, `seedQuestions.ts`, `assessment_questions_converted.json`

---

#### Glassy Card UI & Dashboard Polish

Implemented frosted glass effect for all cards with circadian-aware styling, plus fixed dashboard margins.

**Glassy Card Background:**
- Uses `.ultraThinMaterial` for subtle blur effect
- Warm brown tint overlay (18% opacity) in night mode for circadian compliance
- Semi-transparent so animated wave background shows through
- Applied to dashboard cards, questionnaire cards, and completion views

**Semi-transparent Option Buttons:**
- Updated `CircadianColors.secondaryBackground` to 50% opacity
- Option selectors (Workday, School Day, etc.) now show waves through them
- Text field backgrounds also semi-transparent (60% opacity)

**Dashboard Margins:**
- Fixed 20pt horizontal padding on all dashboard content
- Profile circle ("T" avatar) no longer touches screen edge
- Consistent spacing across all cards

**Time Travel Mode (replaces Speed Test):**
- Renamed Speed Test to Time Travel for clarity
- Allows jumping forward/backward in journey for testing
- Maintains all existing functionality

**Files changed:** `CircadianWaveBackground.swift`, `QuestionComponents.swift`, `QuestionnaireSections.swift`, `ContentView.swift`, `UnifiedDebugPanel.swift`, `ConvexService.swift`, `QuestionnaireManager.swift`

---

#### Empty Assessment Handling Fix
Fixed multiple issues where users could navigate to empty assessments or have expansion days incorrectly marked as "missed".

**Problems Fixed:**
1. Focus screen showed "1 of 0" questions when navigating to empty assessment
2. "Catch Up" card incorrectly showed expansion days as "missed" even when no gateways were triggered
3. Time estimates showed ~16 min for 17 questions instead of ~8 min (was using 1 min/question instead of 30 sec)
4. DayCompletionView showed "Proceed to Assessment" button when no questions existed

**Solutions:**

1. **EmptyAssessmentView** (`QuestionnaireSections.swift`):
   - New view shows "You're All Caught Up!" when user navigates to empty assessment
   - Circadian-aware colors (warm amber at night)
   - "Continue" button dismisses and returns to Focus screen

2. **Backend Fix** (`convex/ios.ts`):
   - `getDailyCompletionStatus` now checks `shouldShowExpansion(day, triggeredGatewayIds)` before marking expansion days as "missed"
   - Only marks `missingAssessment = true` if day actually had assessment questions scheduled

3. **Focus Screen Fix** (`ContentView.swift`):
   - `getAssessmentMinutes()` now checks `scheduled.totalQuestions > 0` before returning minutes
   - Returns 0 if no questions → shows `NoAssessmentTodayView()` instead of NavigationLink

4. **Time Estimation Fix**:
   - Unified formula: `(questionCount + 1) / 2` minutes (~30 seconds per question)
   - Applied to all code paths: Focus screen, Splash screens, backend metadata

5. **Removed INFO_NO_QUESTIONS Placeholder** (`convex/watch.ts`, `QuestionnaireManager.swift`, `MockPlaybackController.swift`):
   - Was adding fake "info" question when assessment was empty, causing count to be 1 instead of 0
   - iOS now properly handles empty assessments without placeholder

**Files changed:** `QuestionnaireView.swift`, `QuestionnaireSections.swift`, `ContentView.swift`, `QuestionnaireManager.swift`, `MockPlaybackController.swift`, `convex/ios.ts`, `convex/watch.ts`

---

### Jan 1, 2026

#### Unified 1-10 Scale for All Slider Questions
Simplified user experience by presenting a consistent 1-10 scale for ALL slider questions, while internally mapping to correct clinical scale values for scoring.

**Problem:**
- Different questionnaires used different scales (ISI: 0-4, PHQ-9: 0-3, FSS: 1-7, BPI: 0-10)
- Users confused by inconsistent scales
- Sleep quality at value 9 was showing "Very severe" instead of "Excellent"

**Solution - ScaleMapper.swift:**
- Created comprehensive scale mapping utility
- Detects positive scales (higher=better: sleep quality, energy) vs negative scales (higher=worse: pain, severity)
- 22+ positive question IDs identified (1, 55, 234, 235, CSD_QUALITY, etc.)
- 80+ negative question IDs identified (ISI, PHQ, GAD, ESS, FSS, PSAS, BPI prefixes)
- Question-specific label dictionaries (sleepQualityLabels, satisfactionLabels, alertnessLabels, etc.)
- Direction-based fallback labels for uncategorized questions

**Files changed:** `ScaleMapper.swift` (new - 988 lines), `QuestionComponents.swift`, `QuestionnaireView.swift`

#### Intensity-Scaled Haptic Feedback for Sliders
Added subtle tactile feedback for slider questions with intensity that scales with the slider value.

**Features:**
- Vibration intensity scales from 0.1 (value 1, barely perceptible) to 1.0 (value 10, full strength)
- Uses `.light` style for gentleness even at full intensity
- Toggleable in Settings > Accessibility > Haptic Feedback
- Default: ON

**Implementation:**
- Added `hapticFeedbackEnabled` property to ThemeManager (persisted in UserDefaults)
- Added `scaledImpact(intensity:)` method to HapticManager
- Integrated in ScaleInput's `.onChange(of: displayValue)` handler
- Formula: `intensity = (value - 1) / 9.0 * 0.9 + 0.1`

**Files changed:** `ThemeManager.swift`, `ProfileSettingsView.swift`, `HapticFeedback.swift`, `QuestionComponents.swift`

---

## December 2025

### Dec 31, 2025

#### Profile Settings UI Cleanup
Simplified accessibility settings in Profile by removing unused options.

**Changes:**
- Removed "High Contrast" toggle (was not implemented)
- Removed "Reduce Motion" toggle (was not implemented)
- Removed "Large Icons Mode" toggle (covered by Enhanced Readability)
- Kept only "Enhanced Readability" and "Haptic Feedback" toggles
- Text Size slider remains available

**Files changed:** `ProfileSettingsView.swift`

#### Experimental Features System
Added system to hide incomplete features behind debug toggles.

**Features hidden:**
- Sleep Diary History - view past sleep log entries
- Sleep Insights - patterns and recommendations

**Implementation:**
- Added `showSleepDiaryHistory` and `showSleepInsights` toggles to ThemeManager (persisted in UserDefaults)
- Wrapped features in ContentView with conditional visibility
- Added "Experimental Features" section to UnifiedDebugPanel

**How to enable:**
1. Profile → Enable Debug Mode
2. Developer → Debug Tools
3. Scroll to "Experimental Features" section
4. Toggle on desired features

**Files changed:** `ThemeManager.swift`, `ContentView.swift`, `UnifiedDebugPanel.swift`

### Dec 30, 2025

#### Fix Expansion Pack Scheduling Bug
Fixed bug where expansion packs (ISI, PHQ-9, etc.) were showing immediately on Days 2-5 when gateways triggered, and then repeating on subsequent days.

**Problem:**
- User answers Q3 gateway "Yes" on Day 2 → ISI expansion shows on Day 2, Day 3, Day 4...
- Same expansion pack would repeat every day until core days complete

**Root Cause:**
- `sameDayExpansionModules` logic was designed to show expansions immediately on Days 1-5
- This caused duplicated expansion pack delivery across multiple days

**Fix:**
- Removed "same-day expansion" logic from Days 1-5
- Expansion packs are now ONLY served on Days 6-14 as intended
- Added `TriggeredGatewaysBanner` UI component showing "Personalized Assessments Unlocked - Starting Day 6"
- Updated `getExpansionPackForDay()` to return nil for Days 1-5
- Updated `hadExpansionPackToday` and `availableExpansionPack` computed properties

**New UX:**
- Days 1-5: Only core questions shown
- When gateway triggered: Banner shows which assessments are scheduled for Day 6+
- Days 6-14: Expansion packs served based on dynamic schedule

**Files changed:** `ContentView.swift`, `QuestionnaireManager.swift`

#### Question Inventory Optimization
Comprehensive audit and optimization of assessment questions based on physician review.

**New Follow-up Questions Added (20+):**
- **Diabetes (Q26):** Type (Q26_TYPE), HbA1C level (Q26_A1C), controlled status (Q26_CONTROLLED)
- **Blood Pressure (Q27):** Controlled status (Q27_CONTROLLED), typical readings (Q27_LEVEL), medication (Q27_MEDICATION)
- **Body Metrics:** Split Q28 into hip (Q28A) and waist (Q28B) for WHR calculation
- **Occupation:** Q53A_OCC for employed users
- **Time Zones:** Q53G_DETAILS and Q53G_ZONES for frequent travelers
- **Prostate:** Q47_PROSTATE and Q47_STREAM for males 45+ with nocturia
- **Pregnancy/Breastfeeding:** Q44I_TRIMESTER, Q44J_DURATION
- **Cannabis:** Q44K_METHOD, Q44K_PURPOSE
- **Caffeine:** Q29A for caffeine sources

**New Gateway Triggers:**
- **OSA/Sleep Apnea:** Added Q48 (breathing issues) and Q49 (snoring/coughing) - creates redundancy with Q19/Q20 for better capture
- **Pain:** Added Q53 (trouble sleeping due to pain) - creates redundancy with Q22 for better capture
- **Prostate:** New gateway triggered by Q47 ≥ 2 (nocturia) for males 45+

**Question Fixes:**
- Q21 (neck circumference): Fixed max from 60cm to 55cm, added collar size helper text
- Q44 (sleep duration): Changed step from 0.5 to 0.25 for 15-minute increments
- Q38 (kids waking): Changed from number_input to single_select_chips with sensible options
- Q30, Q31 (caffeine): Added conditional logic on Q29

**Module Cleanup:**
- Removed orphan question IDs (44B, 44D, 44F, 44H) from modules
- Removed redundant Q210 (location of pain - covered by body diagram Q203)
- Removed redundant Q219 (hours before bed eat - same as Q54B)
- Added new follow-up questions to appropriate modules

**Files changed:** `convex/physician.ts`, `convex/seedClinicalData.ts`, `data/assessment_modules.json`, `data/converted/assessment_questions_converted.json`

### Dec 29, 2025

#### Comprehensive Debug Reset Fix
Fixed iOS "Reset to Day 1" debug function to properly clear ALL dashboard data including Clinical Scores.

- **Problem:** After clicking "Reset to Day 1" in iOS debug panel, dashboard still showed Clinical Scores (ISI, PHQ-9, GAD-7, ESS), Health Pillars progress, and other data
- **Root cause:** iOS app called `watch:resetProgress` which only cleared 4 tables, missing `questionnaire_scores` and 20+ other tables
- **Fix:** Updated both `watch:resetProgress` and `ios:resetJourneyProgress` to comprehensively clear all user data:
  - Core assessment data (`user_assessment_responses`, `responses`, `user_progress`, `daily_checkins`)
  - Clinical scores (`questionnaire_scores`) - **This was the key missing table**
  - Gateway/expansion data (`user_gateway_states`, `user_expansion_schedules`)
  - Insights (`sleep_insights`, `user_insight_queue`, `user_insight_progress`, `onboarding_insights`)
  - Journey status (`patient_journey_status`, `patient_analysis_workflow`)
  - Gamification (`user_streaks`, `user_badges`, `user_xp`, `xp_transactions`, `user_daily_tasks`)
  - Cohort/narrative (`user_cohort_memberships`, `user_sleep_narrative`, `user_encouragement_history`)
  - Physician data (`physician_notes`, `patient_review_status`)
  - Metrics (`perception_gaps`, `difficulty_adjustment_log`, `compliance_outcome_correlation`, `user_metrics_summary`)
- **Note:** `user_sleep_data` (HealthKit sync) is intentionally preserved
- **Files changed:** `convex/watch.ts`, `convex/ios.ts`

#### Time Picker Default Fix for Dependent Questions
Fixed issue where "out of bed" time showed incorrect default (e.g., 7:15 AM) when user changed wake time (e.g., to 8:00 AM).

- **Root cause:** SwiftUI wheel DatePicker binding setter may not fire immediately when user taps Next quickly
- **Fix 1:** Added `onInitialValue` callback to TimeInput that saves smart default on view appear
- **Fix 2:** Added `.onChange(of: value)` handler to ensure binding setter fires for wheel picker changes
- **Result:** Out-of-bed time now correctly defaults to 15 minutes after user's selected wake time
- **Files changed:** `QuestionComponents.swift`, `QuestionnaireView.swift`

#### Dashboard Pillar Completion UI Update
Changed pillar score colors from health-implying (green/red) to neutral amber for completion progress.

- **Rationale:** Completion percentage shouldn't imply health status (80% completion ≠ good health)
- **Changes:** Renamed "Pillar Score" to "Assessment Progress/Completion"
- **Color:** All completion bars now use consistent amber color
- **Sleep log fix:** Progress now based on 14-day journey total (not current_day)
- **Files changed:** `Patient360Tab.tsx`, `PillarDetailModal.tsx`, `PillarSummaryCard.tsx`

#### Sleep Health Factors Dashboard Module
Comprehensive 14-day rolling view of naps, medications, supplements, and caffeine in physician dashboard.

- **New API:** `getPatientSleepHealthRolling` returns day-by-day breakdown for 14 days
- **Supplements vs Medications:** Only prescription/OTC are medications; all others (melatonin, chamomile, valerian, etc.) are supplements
- **4 health factor rows:** Napping, Sleep Medications, Supplements, Caffeine
- **14-day rolling charts:** Mini bar charts showing usage patterns over time
- **Day-by-day breakdown:** Detail modals show individual entries with:
  - Medication/supplement names, doses, and timing
  - Nap details with start times and durations
  - Caffeine intake with mg totals and drink counts
  - Sleep quality rating for correlation analysis
- **Clinical insights:** Alerts for frequent napping, high caffeine, etc.
- **Files changed:** `convex/physician.ts`, `client/src/components/patient/SleepHealthFactorsCard.tsx`

#### iOS Complex Response Serialization Fix
Fixed serialization of complex types (medications, naps, caffeine) from iOS to Convex.

- **Problem:** `[MedicationSelection]`, `[NapEntry]`, `[CaffeineEntry]` were not being serialized to backend
- **Solution:** Added `convertValueToConvexFormat` helper function
- **Changes:** All 3 sync locations (`syncResponsesToConvex`, `saveInProgressResponsesOnDismiss`, `completeSectionInBackground`) now use helper
- **Backend:** Added `responseObject` field to `saveResponses` mutation in `convex/watch.ts`
- **Files changed:** `ZoeSleep/ZoeSleep/Views/QuestionnaireView.swift`, `convex/watch.ts`

#### Unified Body Metrics Slider UI
Imperial height in onboarding now uses a single slider instead of wheel pickers.

- **Before:** Metric used sliders, Imperial used two wheel pickers (feet/inches) - inconsistent UX
- **After:** Both metric and imperial use unified slider interface
- **Imperial slider:** Range 48-95 inches (4'0" to 7'11"), displays as feet/inches format
- **Implementation:** Custom Binding converts total inches ↔ feet/inches for existing temp values
- **Files changed:** `ZoeSleep/ZoeSleep/Views/OnboardingView.swift`

#### Auto-Derivable Questions System
Questions that can be calculated from sleep log data are now automatically derived, reducing user burden.

- **Derivable questions:** Q44 (hours of actual sleep), Q42 (sleep latency), Q41 (bedtime), Q33D (sleep aids)
- **Auto-calculation:** When user completes sleep log, these values are calculated from CSD_ responses:
  - Q44 = (finalWake - trySleep) - latency - WASO (rounded to nearest 0.5 hour)
  - Q42 = CSD_LATENCY (direct mapping)
  - Q41 = CSD_TRY_SLEEP (direct mapping)
  - Q33D = Derived from CSD_MEDS (yes/no) and CSD_MEDS_LIST (medication selections)
- **Question filtering:** `getQuestionsForUserDay` filters out derivable questions when sleep log is complete
- **Response generation:** `markSectionComplete` auto-generates derived responses with `is_derived: true` flag
- **Array support:** Added support for array-type derived responses (stored as JSON in `response_array`)
- **Physician dashboard:** Derived responses are included in scoring with source tracking
- **Files changed:** `convex/watch.ts`

#### Q33D Redundancy Fix
Q33D "Do you use any sleep aids?" was redundant with CSD_MEDS from the sleep log.

- **Problem:** Users were asked about sleep medications twice - once in daily sleep log (CSD_MEDS) and again in Day 6 assessment (Q33D)
- **Solution:** Q33D is now derived from CSD_MEDS responses:
  - If CSD_MEDS = "No" → Q33D = ["none"]
  - If CSD_MEDS = "Yes" → Q33D = values from CSD_MEDS_LIST (or ["other"] if no list)
- **Result:** Question is automatically skipped when sleep log is complete, reducing redundant questions
- **Files changed:** `convex/watch.ts`

#### Remove Redundant Bed Partner Question (Q59)
Q59 "Do you have a bed partner or room mate?" was redundant with Q35 "Do you share your bedroom with a partner?"

- **Problem:** Users were asked about bed partners twice - Q35 on Day 1, then Q59 later in same assessment
- **Solution:** Removed Q59 from `core_social` module. If any scoring needs Q59, it can be derived from Q35
- **Derivation exists:** `AnswerDerivationSystem.swift` already has mapping `"59": "35"` for automatic derivation
- **Files changed:** `data/assessment_modules.json`, `server/core_questions.json`, `data/sleep360_questions.json`

#### Questionnaire Name Mapping Fix
Fixed severity lookup for full questionnaire names in physician dashboard.

- **Bug:** ScoreDetailModal couldn't find thresholds for full names like "Insomnia Severity Index"
- **Fix:** Added `questionnaireNameToAbbreviation` mapping (22 questionnaires)
- **Result:** Severity badges now display correctly for all questionnaire types
- **Files changed:** `client/src/components/physician/ScoreDetailModal.tsx`

#### LLM Clinical References Enhancement
Improved AI interpretations with validated clinical guidelines.

- **New system prompt:** Added `getClinicalReferenceForQuestionnaire` for peer-reviewed interpretation guidelines
- **Hallucination prevention:** Explicit instruction to use ONLY validated thresholds
- **Files changed:** `convex/llm.ts`

### Dec 28, 2025

#### Expansion Pack Slider UX Fix
Fixed issue where users couldn't tap Next on slider questions without moving the slider.

- **Bug:** In "Deeper Dive" (expansion pack questionnaire), scale questions required user interaction before Next button became enabled, even when default value was acceptable
- **Root cause:** `ContentView.swift` had different validation logic than `QuestionnaireView.swift` - expansion pack required `userInteracted.contains()` for scale questions
- **Fix 1:** Updated `canProceed` to return `true` for `.scale`, `.number`, `.numberScroll`, `.time`, `.date`, `.minutesScroll`, `.hoursMinutesScroll` types
- **Fix 2:** Added logic in `nextQuestion()` to save default value when user accepts without interacting
- **Files changed:** `ContentView.swift` (ExpansionPackQuestionnaireView)

#### Journey Intro Flow & Fresh Install Detection
Seamless splash-to-intro transition for new users.

- **New app flow:** Splash → JourneyIntro → Auth → Onboarding → Content (journey intro now shows BEFORE auth)
- **Fresh install detection:** New `app_install_marker_v1` in UserDefaults ensures journey intro shows on every fresh install
  - Keychain persists across app deletions, but this marker resets the journey intro flag
- **Splash screen improvements:**
  - Duration increased to 3.5s so logo lingers longer
  - Logo animates up (`logoOffset`) when transitioning to intro
  - Tagline fades out during transition for seamless effect
  - Added `isTransitioning` binding to coordinate animation
- **ZoeLogo centering fix:** Logo SVG paths now mathematically centered using actual content bounds
- **Journey intro screens rewritten:** 4 screens with warm, human-friendly messaging:
  - Screen 1: "Finally Understand Your Sleep" - conversational welcome
  - Screen 2: "The Best Tools, Tailored to You" - trusted questionnaires + wearable data reinterpreted with unique profile
  - Screen 3: "A Real Expert Reviews Everything" - human-in-the-loop, sleep fingerprint
  - Screen 4: "Wake Up to Your Best Life" - energy, focus, mood, healthspan + "Let's Get Started" CTA
- **Debug panel update:** New "Reset Journey Intro" button in Repair & Diagnostics section
- **Files changed:** `ZoeSleepApp.swift`, `SplashScreenView.swift`, `JourneyIntroScreens.swift`, `JourneyIntroView.swift`, `ZoeLogo.swift`, `ContentView.swift`, `UnifiedDebugPanel.swift`

#### Dashboard UX Redesign & Expansion Pack Sync Fix
Improved task layout and cross-device sync.

- **TaskRowView redesign:** Fixed truncated subtitle text by moving duration badge below subtitle
  - Title row now has chevron on right side
  - Subtitle gets full width with 3-line limit
  - Duration shown as capsule badge below subtitle
- **Day descriptions shortened:** More concise descriptions (e.g., "About you and your sleep habits" instead of long technical text)
- **Assessment Phase badge:** New badge in progress card explains this is the assessment phase
- **Expert review messaging:** Added "Personalized treatment follows expert review" text
- **Progress messages updated:** Context-aware messages (e.g., "Let's understand your sleep", "Almost ready for expert review")
- **Expansion pack sync fix:** Same-day expansions (Days 1-5) now sync to Convex via `ios:markExpansionPackCompleted`
  - Previously only stored locally - Watch couldn't see completion
  - New mutation updates `user_progress.expansion_pack_completed` in database
- **Watch app visibility:** "Deeper Dive" task now properly shows on Watch when triggered
- **Debug reset fix:** `resetProgress()` now clears UserDefaults splash keys so splashes show again after reset
- **Jump to Day feature:** New debug feature to instantly jump to any day 1-14 for testing
- **Files changed:** `ContentView.swift`, `QuestionnaireManager.swift`, `ConvexService.swift`, `UnifiedDebugPanel.swift`, `ios.ts`, `watch.ts`

#### Enhanced Splash Screen Aurora & ISI Labels
Visual polish and validated questionnaire labels.

- **EnhancedAuroraBorealisView:** New dramatic aurora with vertical flowing curtains, multiple layers, pulsing central glow
- **SplashScreenView refactor:** Smoother animations, better timing, more elegant logo reveal
- **ISI question-specific labels:** Per the validated Morin et al. 2011 instrument:
  - Items 1-3 (Severity): None → Mild → Moderate → Severe → Very Severe
  - Item 4 (Satisfaction): Very Satisfied → Very Dissatisfied
  - Item 5 (Interference): Not at all interfering → Very much interfering
  - Item 6 (Noticeable): Not at all noticeable → Very much noticeable
  - Item 7 (Worried): Not at all worried → Very much worried
- **Files changed:** `AuroraBorealisView.swift`, `SplashScreenView.swift`, `AnswerDerivationSystem.swift`, `JourneyIntroScreens.swift`

### Dec 27, 2025

#### Workday vs Weekend Day Type Analysis
Complete day type tracking and clinical pattern detection.

- **Schema enrichment:** Added to `user_sleep_data` table: `day_number`, `day_type`, `naps_taken`, `nap_count`, `nap_total_mins`, `nap_details_json`, `medications_taken`, `medication_time`, `medication_categories_json`, `subjective_quality`
- **Day types tracked:** Workday, School Day, Day Off, Vacation, Holiday, Weekend
- **Backend extraction:** `healthkit.ts:computeSleepMetricsFromResponses` now extracts day_type, naps, medications from both CSD_ and SD_ question prefixes
- **Day type analysis query:** New `physician.ts:getPatientDayTypeAnalysis` compares workday vs weekend stats
- **Clinical flags generated:**
  - `social_jet_lag` - >60 min sleep duration difference between workday/weekend
  - `compensatory_sleep` - Weekend catch-up sleep suggests weekday sleep debt
  - `weekend_napping` - Higher nap rate on weekends indicates weekday sleep deficit
  - `medication_pattern` - Different medication use between workday/weekend
- **Dashboard integration:** `SleepDataReview.tsx` now shows comparison grid with severity-styled clinical flags
- **Files changed:** `convex/schema.ts`, `convex/healthkit.ts`, `convex/physician.ts`, `SleepDataReview.tsx`

#### Dynamic Nap Blocks & Conditional Medication Questions
Structured nap/medication data collection.

- **New Nap Details UI:** Dynamic nap blocks based on nap count with time picker + duration quick-select buttons
- **New Medication Select UI:** Multi-select chips for 6 medication categories with conditional "Other" text field
- **New question types:** `napDetails` and `medicationSelect` in QuestionType enum
- **New models:** `NapEntry` struct, `MedicationCategory` struct with 6 predefined categories
- **Conditional logic enhancement:** Added `contains` operator and compound conditions (`all`, `any`)
- **Convex queries:** `getPatientNapSummary`, `getPatientMedicationSummary`
- **Files changed:** `QuestionModels.swift`, `QuestionComponents.swift`, `QuestionnaireView.swift`, `QuestionnaireManager.swift`, `convex/physician.ts`, `SleepDataReview.tsx`

#### Comprehensive Questionnaire Scale Labels Fix
Replaced all "Minimum/Maximum" slider labels with clinical descriptors.

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
| MEQ | 1-4 | Chronotype-specific labels |

- **File changed:** `data/converted/assessment_questions_converted.json`
- **IMPORTANT:** After modifying JSON, run `npx convex run seedQuestions:seedAll` to update database

#### Smart Question Derivation
Reduce user burden by deriving redundant questions from Sleep Log.

- **Derivation System:** Added 12A and 12C to `derivableFromSleepLog` set
- **New functions:** `derive12AFromSleepLog()`, `derive12CFromSleepLog()`
- **Conditional logic:** 12B (reason for waking) now only shows if user reported awakenings > 0
- **Scale labels fix:** `convertConvexQuestion()` now extracts `scaleMin`/`scaleMax`/`labels` from Convex format
- **Files changed:** `QuestionnaireManager.swift`, `QuestionnaireView.swift`

#### Dynamic Task Counter & Expansion Pack Integration
Complete task tracking system for iOS and Watch.

- **Dynamic task count:** Now shows "1 of 1", "2 of 2", or "2 of 3" based on actual tasks
- **No-gateway UX:** New `NoAssessmentTodayView` component shows "You're on track!" message
- **Watch app sync:** `WatchHomeView.swift` shows same task count as iPhone
- **Backend update:** `watch.ts:getJourneyState` now returns expansion pack status
- **Schema update:** Added `expansion_pack_completed` field to `user_progress` table
- **Files changed:** `ContentView.swift`, `UnifiedDebugPanel.swift`, `WatchHomeView.swift`, `WatchConvexService.swift`, `watch.ts`, `schema.ts`

#### New Zoe Logo & App Icons
Updated all app icons with new spiral crescent moon logo.

- **Logo source:** Frame 3.svg - spiral crescent moon design
- **Color scheme:** Warm cream (#F5E6D3) on dark warm brown gradient (#1a1512 to #0d0a08)
- **iOS icons:** 15 icons regenerated (20x20 to 1024x1024) - RGB, no alpha channel
- **Watch icons:** 17 icons regenerated (24x24@2x to 1024x1024) - RGB, no alpha channel
- **ZoeLogo.swift:** Complete rewrite with exact SVG path recreation
- **Icon generation script:** `scripts/generate-icons.sh`

#### Expansion Pack Splash Screens
Educational rationale screens for all 16 validated questionnaires.

- **16 validated instruments:** ISI (2,500+ citations), DBAS-16 (1,000+), SHI (500+), PSAS (800+), ESS (10,000+), FSS (7,000+), FOSQ-10 (500+), PHQ-9 (15,000+), GAD-7 (10,000+), DASS-21 (20,000+), PROMIS-Cog (2,000+), STOP-BANG (5,000+), Berlin (3,000+), BPI (6,300+), MEDAS (1,500+), MEQ (4,000+)
- **Content per questionnaire:** Full name, abbreviation, citation count, what it measures, scientific background
- **New file:** `ZoeSleep/ZoeSleep/Views/ExpansionQuestionnaireSplash.swift` (~700 lines)

#### Physician Review Checklist UX Improvement
Expandable review sections in analysis workflow.

- **SleepDataReview:** Shows avg duration, quality, awakenings, efficiency + day-by-day breakdown
- **QuestionnaireScoresReview:** All 18 questionnaire scores with severity indicators
- **GatewayTriggersReview:** Shows 6 gateways with triggered/not triggered status
- **Auto-mark reviewed:** Items auto-check after 2 seconds of viewing expanded content
- **New files:** `ReviewSection.tsx`, `SleepDataReview.tsx`, `QuestionnaireScoresReview.tsx`, `GatewayTriggersReview.tsx`

### Dec 24, 2025

#### Overdue Expansion Pack Tracking
Full tracking for incomplete expansion packs from previous days.

- **Backend:** `ios.ts:getDailyCompletionStatus` now returns `overdueExpansions[]`
- **iOS Dashboard:** Purple "Overdue Deep Dives" card shows incomplete expansion packs
- **Watch App:** Purple reminder card shows count of overdue packs
- **Files changed:** `convex/ios.ts`, `convex/watch.ts`, `ContentView.swift`

#### Next Button UX Fix
Questions with default values no longer require interaction to proceed.

- **Fix:** `canProceed` now returns `true` for `.number` and `.numberScroll` types
- **Smart default saving:** When user taps Next without interacting, visible default is saved automatically
- **Files changed:** `QuestionnaireView.swift` (iOS), `QuestionnaireView.swift` (Watch)

#### Sleep Log Completion Persistence
Section completion now saves immediately when showing completion screen.

- **Fix:** Added `completeSectionInBackground()` that syncs responses immediately
- **Files changed:** `QuestionnaireView.swift`

### Dec 23, 2025

#### AI Analysis Configuration System
Complete LLM settings management for physician dashboard.

- **Model Selection:** Primary + fallback model configuration (Claude Opus 4.5, Sonnet 4.5, GPT-5.2, etc.)
- **API Key Management:** Secure storage with masked display
- **Preview Analysis Prompt:** Button to see full system/user prompt before running analysis
- **Backend files:** `convex/systemSettings.ts`, `convex/llm.ts`
- **UI location:** `/physician-dashboard/settings` - AI Configuration section

#### HealthKit Authorization Fix
Fixed misleading "Connected" status in onboarding.

- **Root cause:** iOS `requestAuthorization()` returns `success=true` when dialog is SHOWN, not when user GRANTS
- **Fix:** Added `verifyDataAccess()` that attempts actual data read to verify true access
- **New status states:** `notConnected`, `connecting`, `connected`, `denied`, `unavailable`
- **Files changed:** `HealthKitManager.swift`, `OnboardingView.swift`, `HealthKitIntegrationView.swift`

### Dec 22, 2025

#### Admin Tools Dashboard
Comprehensive admin toolkit for physician dashboard.

- **New page:** `/physician-dashboard/admin` - Full user management interface
- **User operations:** Delete users, reset passwords, reset progress, change roles, toggle dev mode
- **Bulk actions:** Select multiple users, bulk delete, purge by pattern
- **Backend functions:** `convex/admin.ts`

#### Email-Only Registration
Simplified sign-up to email + password only.

- **Auto-generated username:** Created from email prefix
- **Files changed:** AuthenticationView.swift, AuthenticationManager.swift, ConvexService.swift, ios.ts

#### CRITICAL: Circadian Text Contrast Fix
Permanent fix for dark text on dark background issue.

- **Root cause:** `ColorTheme` text colors checked `accentColorOption` but backgrounds ALWAYS use circadian colors
- **Fix:** All text color properties now check `CircadianPalette.current.isDark` FIRST
- **Files changed:** `QuestionModels.swift` (ColorTheme struct)

#### 8-Phase Circadian Color System
Complete redesign for smooth day-to-night transitions.

- **CircadianPalette:** New struct with 8 phases (pre-dawn → dawn → morning → midday → afternoon → dusk → evening → night)
- **Smooth interpolation:** Colors blend gradually using Hermite interpolation
- **Seasonal awareness:** Sunrise/sunset times adjust based on day of year
- **Files changed:** `QuestionModels.swift`, `ThemeManager.swift`, `AnalysisPendingView.swift`

#### Unified Debug Panel
Consolidated all developer tools into single panel.

- **4 generation modes:** Full Journey, Max Load, Selective, Quick Test
- **Gateway selection:** Toggle individual gateways with icons and descriptions
- **New file:** `DevTools/UnifiedDebugPanel.swift`

#### Bug Fixes
- **Fixed 93% Completion Bug:** Day 14 completion now shows 100%
- **Fixed Sleep Log Refresh Issue:** Today's Focus now updates immediately after completion
- **Sleep Diary Layout Fix:** Fixed content cropping on left edge
- **GatewayType Extensions:** Added UI properties (icon, color, triggerDescription)

### Dec 21, 2025

#### 14-Day Journey Standardization
Updated entire codebase from 15 to 14 days.

- **Merged Day 14 & 15:** Final day now includes DASS-21, STOP-BANG, Berlin, BPI, MEDAS, MEQ
- **All progress indicators:** Now show "Day X of 14" consistently

#### Enhanced Readability Mode for Elderly Users
Instant accessibility system.

- **Floating magnifying glass button:** Visible from splash screen, login, onboarding, and intro
- **One-tap activation:** Single toggle enables 1.5x text, large icons, high contrast, reduced motion
- **Files:** `EnhancedReadabilityOverlay.swift`, `ThemeManager.swift`

#### Journey Introduction Sequence
6-screen Aurora-animated intro for new users.

- Full-screen modal on first MainDashboard visit with swipeable pages
- Aurora borealis background matching splash screen aesthetic
- **Files:** `JourneyIntroView.swift`, `JourneyIntroScreens.swift`, `JourneyIntroIcons.swift`

#### Other Fixes
- **App Icon Alpha Channel Fix:** Removed transparency from all iOS app icons
- **PSQI Core Assessment Fix:** PSQI now always generates as core (Days 1-2)
- **Dashboard Progress Indicator Fix:** Fixed 3 bugs in journey progress card
- **Build Fixes:** Resolved multiple compilation errors

### Dec 20, 2025

#### "From Gamification to Indispensability" System
Complete personalization engine.

- **Micro-Cohorts:** Dynamic peer groups based on 8 dimensions
- **Sleep Fingerprint:** 9 phenotypes with 8 pattern detectors
- **Personalized Insights:** 100+ evidence-based messages
- **Anticipation Engine:** Predictive sleep forecasting
- **Files:** `convex/microCohorts.ts`, `convex/sleepPhenotype.ts`, `convex/insightLibrary.ts`, `convex/anticipationEngine.ts`

#### Post-Intake Experience
Complete treatment journey implementation.

- **Journey Phases:** intake → analysis → treatment_pending → treatment_active
- **Analysis Pending View:** 4-stage timeline
- **Treatment Dashboard:** Session-based cards (Morning/Afternoon/Evening/Night)
- **Files:** `convex/journey.ts`, `convex/insights.ts`, `JourneyPhaseManager.swift`, `AnalysisPendingView.swift`, `TreatmentDashboardView.swift`

#### Measurement System & Body Metrics Overhaul
- **Measurement system from locale:** Auto-detects Metric/Imperial
- **Height/weight now optional:** Shows "Not set" in Profile if never provided
- **HealthKit integration:** Auto-fill from Apple Health

### Dec 19, 2025

#### Developer Mode for Testers
Physician dashboard toggle for fast-track testing.

- Toggle developer mode on/off per patient
- Jump to any day (1-14) instantly
- **Mutations:** `toggleDeveloperMode`, `setPatientDay`, `getDeveloperModeStatus`

#### Gamification System (Schema)
"Strava for Sleep" tables added.

- User streaks, badges, XP/levels, and challenges
- Evidence-based encouragement message library

### Dec 18, 2025

#### Dashboard 360° View Data Pipeline
Complete data flow from iOS mock generator to dashboard.

- `healthkit:computeSleepMetricsFromResponses`
- `physician:persistCalculatedScores`
- `physician:getQuestionnaireResponses`

#### New Branding and Logo
Spiral crescent moon logo implementation.

- iOS: `ZoeLogo.swift`, Web: `ZoeLogo.tsx`
- Animated aurora borealis splash screen

#### Intervention Library System
Physician dashboard can assign interventions to patients.

- 39 evidence-based interventions across 12 categories
- 7 treatment bundles
- **Seed:** `npx convex run seedInterventionLibrary:seedAll`

### Dec 13, 2025

- **Question Manager enhancements:** Full question preview in physician dashboard
- **iOS smart task visibility:** Assessment task only shows if content exists
- **Day-aware response storage:** Repeating questions now stored per day
- **Consensus Sleep Diary (CSD):** Full iOS sleep log integration
- **Questionnaire day rebalance:** Split large modules across all days

### Dec 12, 2025

- Fixed questionnaire navigation: Back button now properly respects section boundaries
- Added save error handling: Retry dialogs for failed Convex syncs
- Circadian picker styling: Time/date pickers now use warm amber colors at night
- **Fixed pre-fill/fast-forward bug:** Questionnaire no longer auto-fills answers on fresh start
- **Smart defaults are scale-relative:** Default values now adapt to actual question scale range

### Dec 11, 2025

- Repository renamed: `15-day-Intake` → `Zoe-Sleep-V1`
- Onboarding: 8 steps, account-aware, circadian colors
- Cross-device sync: Question-by-question resume
- Day unlock: 4 AM (was 5 AM)

---

*For quick reference, see [CLAUDE.md](../CLAUDE.md)*
