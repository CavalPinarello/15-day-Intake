# Watch App Simplification: Sleep Log Only (No Assessment)

**Date:** 2025-12-02

## Problem
The Apple Watch screen is too small for detailed Assessment questions like height, weight, and date of birth.

## Design Decision
**Watch is for quick daily interactions only:**
- ✅ Sleep Log (5 questions, ~60 seconds)
- ✅ Treatment Tasks (view and complete)
- ✅ HealthKit readouts
- ✅ Day progress status
- ❌ Assessment questions (complete on iPhone)

## Changes Made

### 1. Removed Assessment from WatchHomeView
- Removed `showingAssessment` state variable
- Removed `QuestionnaireView(mode: .assessment)` navigation destination
- Changed Assessment button from tappable to display-only:
  - Shows iPhone icon with "Complete on iPhone" text
  - Shows green checkmark when completed (synced from Convex)
  - No navigation - just status display

### 2. Updated QuestionnaireView Completion Screen
- Removed "Start Assessment" button after Sleep Log completion
- Now shows: "Assessment - Complete on iPhone" (informational)
- When both done: "Day X Complete! See you tomorrow"

### 3. Fixed Sleep Log Questions Loading
- Sleep Log now ALWAYS uses local `SharedQuestionBank` (not Convex)
- Fixes issue where Convex returned empty/wrong questions
- The 5 Stanford Sleep Log questions are hardcoded locally:
  1. What time did you go to bed? (time picker)
  2. What time did you fall asleep? (time picker)
  3. How many times did you wake up? (number stepper)
  4. What time did you wake up? (time picker)
  5. Rate your sleep quality (1-10 scale)

### 4. Fixed Date of Birth Question Type
- Added `year` type to `WatchQuestionType` enum
- Added `WatchYearPickerView` component (wheel picker 1920-current year)
- Fixed Convex `mapAnswerFormatToType()` to handle `date_picker` → `year`
- This fixes the bug where date questions showed time pickers

## Key Files Modified
- `/ZoeSleep/ZoeSleep Watch App/WatchHomeView.swift` - Removed assessment navigation, display-only status
- `/ZoeSleep/ZoeSleep Watch App/QuestionnaireView.swift` - Sleep Log uses local questions, removed assessment button
- `/convex/watch.ts` - Added date_picker → year mapping

## Watch App Flow (After Changes)
```
WatchHomeView
├── Sleep Log Button → QuestionnaireView (5 questions) → Completion
├── Assessment Card → Display only ("Complete on iPhone")
└── Treatment Tasks → TreatmentTasksView (if tasks exist)
```