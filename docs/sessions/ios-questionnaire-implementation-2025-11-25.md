# iOS 15-Day Adaptive Questionnaire Implementation

**Date:** 2025-11-25
**Session Type:** Feature Implementation
**Status:** Complete

## Overview

Implemented the complete 15-day adaptive questionnaire system in the iOS app, porting the web app's intelligent gateway logic to native Swift/SwiftUI.

## Files Created

### 1. `/Sleep360/Sleep360/Models/QuestionModels.swift`
- **Purpose:** Data models for the questionnaire system
- **Contents:**
  - `QuestionType` enum - 12 question types (text, number, scale, yesNo, singleSelect, etc.)
  - `Pillar` enum - 11 health pillars with color coding
  - `QuestionTier` enum - CORE, GATEWAY, EXPANSION tiers
  - `GatewayType` enum - 10 gateway types for conditional expansion
  - `Question` struct - Complete question model with conditional logic
  - `QuestionResponse` struct - Response storage with multiple value types
  - `DayConfiguration` struct - Daily questionnaire configuration
  - `GatewayState` struct - Gateway trigger tracking
  - `HealthKitSleepSummary` struct - For HealthKit auto-fill

### 2. `/Sleep360/Sleep360/Managers/QuestionnaireManager.swift`
- **Purpose:** Core questionnaire logic and gateway evaluation
- **Features:**
  - 15 day configurations with titles, descriptions, estimated times
  - Stanford Sleep Log (5 daily questions)
  - Core questions for Days 1-5 with embedded gateway triggers
  - Expansion questions for Days 6-15 (ISI, ESS, PHQ-9, GAD-7, STOP-BANG)
  - Gateway evaluation engine that dynamically triggers assessments
  - Conditional logic filtering for question display
  - Convex backend integration for response syncing

### 3. `/Sleep360/Sleep360/Views/QuestionComponents.swift`
- **Purpose:** Reusable UI components for different question types
- **Components:**
  - `QuestionCard` - Container with pillar badge and help text
  - `ScaleInput` - Slider for scale questions
  - `YesNoInput` - Button group for yes/no questions
  - `SingleSelectInput` - Radio-style selection
  - `MultiSelectInput` - Checkbox-style multiple selection
  - `NumberInput` - Increment/decrement number input
  - `TimeInput` - Time picker
  - `DateInputView` - Date picker
  - `TextInputView` - Text/email input
  - `MinutesScrollPicker` - Scroll picker for duration
  - `InfoCard` - Information display card
  - `SleepLogSummaryCard` - Compare user vs HealthKit data
  - `QuestionnaireProgressHeader` - Progress indicator
  - `GatewayAlertBanner` - Shows triggered gateways
  - `Color.init(hex:)` - Color extension for pillar colors

### 4. `/Sleep360/Sleep360/Views/QuestionnaireView.swift`
- **Purpose:** Complete questionnaire interface
- **Features:**
  - Progress header with day number and question count
  - HealthKit sleep summary at start of each day
  - Dynamic question rendering based on type
  - Response saving with timing data
  - Gateway evaluation after each response
  - Day completion workflow with alerts
  - Navigation buttons (Back/Next/Submit)

## Files Modified

### `/Sleep360/Sleep360/ContentView.swift`
- **Changes:** Complete dashboard redesign
- **New Features:**
  - Journey progress visualization with 15-day circular indicator
  - Day dots showing completed/current/future days
  - Core vs Expansion phase indicator
  - HealthKit status card
  - Today's tasks card (Stanford Sleep Log + Day assessment)
  - Gateway status card showing triggered assessments
  - Quick actions for Sleep Diary History and Insights
  - Journey Overview sheet with all 15 days
  - Greeting based on time of day
  - Menu for Journey Overview, HealthKit Settings, Sign Out

## Gateway System

### Gateway Types (10)
1. **Insomnia** - Triggers ISI, DBAS-16, Sleep Hygiene, PSAS
2. **Poor Sleep Quality** - Triggers sleep quality expansion
3. **Depression** - Triggers PHQ-9
4. **Anxiety** - Triggers GAD-7
5. **Excessive Sleepiness** - Triggers ESS, FSS, FOSQ-10
6. **Cognitive** - Triggers PROMIS-Cognitive
7. **OSA (Sleep Apnea)** - Triggers STOP-BANG, Berlin
8. **Pain** - Triggers BPI
9. **Sleep Timing** - Triggers MEQ
10. **Diet Impact** - Triggers MEDAS

### Evaluation Logic
- Gateway questions are embedded in Days 1-5
- Responses are evaluated after each answer
- Triggered gateways unlock expansion modules for Days 6-15
- If no gateways triggered, Days 6-15 show minimal questions

## Stanford Sleep Log (Daily)
1. What time did you go to bed last night?
2. What time did you fall asleep?
3. How many times did you wake up during the night?
4. What time did you wake up this morning?
5. How would you rate your sleep quality? (1-10)

## Day Configuration

| Day | Title | Description | Est. Min |
|-----|-------|-------------|----------|
| 1 | Demographics & Sleep Quality | Foundation: Basic demographics & sleep quality overview | 12 |
| 2 | PSQI & Sleep Patterns | PSQI completion + sleep patterns | 11 |
| 3 | Sleep Timing & Mental Health | Light exposure, screens, mental health gateways | 8 |
| 4 | Physical Health & Metabolic | OSA screening, pain, exercise, metabolic basics | 9 |
| 5 | Nutritional & Social | Caffeine, alcohol, diet, social factors | 7 |
| 6-15 | Expansion Days | Personalized based on gateway triggers | Variable |

## HealthKit Integration

- Fetches previous night's sleep data on questionnaire start
- Shows summary card with:
  - Total sleep duration
  - Sleep efficiency percentage
  - Awakenings count
  - In-bed and wake times
- Emphasizes subjective perception vs objective data

## Convex Integration

Uses existing iOS Convex functions:
- `ios:getDayQuestionnaire` - Fetch day's questions
- `ios:submitQuestionnaireResponse` - Save responses
- `ios:completeDay` - Mark day complete
- `ios:getJourneyProgress` - Load progress

## Testing Notes

1. Use test users user1-user10 with password "1"
2. Gateway triggers can be tested by answering:
   - "Yes" to insomnia question (3)
   - Sleep quality <= 5 (question 1)
   - "More than half the days" on depression/anxiety questions
   - "Yes" to snoring or observed apnea
3. Days 6-15 will show expansion questions only if gateways triggered

## Next Steps

1. Add Xcode project file references for new Swift files
2. Test questionnaire flow in iOS Simulator
3. Verify Convex sync with backend
4. Implement watchOS questionnaire with same logic
