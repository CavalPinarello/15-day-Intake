# Question & Answer System - Complete Summary

## Executive Overview

**Goal:** Standardize all questions across the Sleep 360° platform to minimize user friction and maximize completion speed.

**Status:** ✅ **Specification Complete - Ready for Implementation**

**Expected Impact:**
- 📊 **30% faster** question completion time
- 🎯 **Higher completion rates** due to reduced friction
- 🔧 **Easier maintenance** with standardized formats
- ♿ **Better accessibility** with consistent patterns
- 📱 **Superior mobile UX** with touch-optimized components

---

## What We've Created

### 1. **Main Specification Document** 
📄 `QUESTION_ANSWER_FORMAT_SPECIFICATION.md`

Defines **8 core answer format types** that cover all 230+ questions:

| Answer Format | Use Case | Example | Count |
|---------------|----------|---------|-------|
| `time_picker` | Time of day | "What time did you go to bed?" | 18 |
| `minutes_scroll` | Duration in minutes | "How long to fall asleep?" | 12 |
| `number_scroll` | Small counts | "Times woke up?" (0-20) | 11 |
| `slider_scale` | Ratings, severity | "Sleep quality 1-10" | 95 |
| `single_select_chips` | Single choice | "Did you take medication? [Yes/No]" | 62 |
| `multi_select_chips` | Multiple choices | "Sleep aids used (select all)" | 5 |
| `date_picker` | Calendar dates | "Date of birth" | 3 |
| `number_input` | Measurements | "Height (cm), Weight (kg)" | 22 |
| `repeating_group` | Dynamic lists | "Record each nap time + duration" | 2 |

**Total Questions Covered:** 230 (excluding open-text questions to be added later)

---

### 2. **Updated Database Schema**
📄 `convex/schema.ts` (updated)

**New Fields Added to `assessment_questions` table:**
```typescript
{
  answer_format: v.string(),              // 🆕 One of 8 core types
  format_config: v.string(),              // 🆕 JSON config
  help_text: v.optional(v.string()),      // 🆕 Helper text
  validation_rules: v.optional(v.string()),// 🆕 Validation
  conditional_logic: v.optional(v.string()),// 🆕 Show/hide logic
  order_index: v.optional(v.number()),    // 🆕 Ordering
  estimated_time_seconds: v.number(),     // 🆕 Changed from minutes
}
```

**New Fields Added to `user_assessment_responses` table:**
```typescript
{
  response_number: v.optional(v.number()),  // 🆕 For numeric answers
  response_array: v.optional(v.string()),   // 🆕 For multi-select
  response_object: v.optional(v.string()),  // 🆕 For complex data
  answered_in_seconds: v.optional(v.number()), // 🆕 Track speed
}
```

**Same updates applied to `sleep_diary_questions` table** for consistency.

---

### 3. **Migration Guide**
📄 `QUESTION_FORMAT_MIGRATION_GUIDE.md`

Complete step-by-step guide for:
- ✅ Converting old question formats to new standardized format
- ✅ Running database migrations safely
- ✅ Testing and validation procedures
- ✅ Rollback procedures if needed
- ✅ Timeline: 7-week rollout plan

---

### 4. **Sample Data File**
📄 `data/standardized_questions_sample.json`

**50+ example questions** properly formatted with the new system, including:
- All Sleep Diary questions (16 questions)
- Representative Sleep 360° questions from each pillar
- Gateway questions
- Expansion questions
- Examples of all 8 answer format types

Ready to use as:
- Database seed data
- Reference for question creation
- Testing fixtures

---

## Database Changes Summary

### Tables Modified

#### 1. `assessment_questions`
**Purpose:** Stores Sleep 360° assessment questions

**Changes:**
- ➕ Added `answer_format` (required)
- ➕ Added `format_config` (required JSON string)
- ➕ Added `help_text` (optional)
- ➕ Added `validation_rules` (optional JSON string)
- ➕ Added `conditional_logic` (optional JSON string)
- ➕ Added `order_index` (optional number)
- ➕ Added `estimated_time_seconds` (required, replaces `estimated_time`)
- ➕ Added `created_at`, `updated_at` timestamps
- ➕ Added index on `answer_format`
- ✅ Kept legacy `question_type` and `options_json` for backward compatibility

#### 2. `user_assessment_responses`
**Purpose:** Stores user answers to assessment questions

**Changes:**
- ➕ Added `response_number` for numeric answers
- ➕ Added `response_array` for multi-select (JSON array string)
- ➕ Added `response_object` for complex data (JSON object string)
- ➕ Added `answered_in_seconds` to track response time
- ✅ Kept existing `response_value` for string answers

**Storage by Answer Format:**
| Answer Format | Storage Field | Example |
|---------------|---------------|---------|
| `time_picker` | `response_value` | `"23:30"` |
| `single_select_chips` | `response_value` | `"yes"` |
| `date_picker` | `response_value` | `"2025-01-15"` |
| `minutes_scroll` | `response_number` | `45` |
| `number_scroll` | `response_number` | `3` |
| `slider_scale` | `response_number` | `7` |
| `number_input` | `response_number` | `175.5` |
| `multi_select_chips` | `response_array` | `'["white_noise","fan"]'` |
| `repeating_group` | `response_object` | `'[{"time":"14:00","mins":30}]'` |

#### 3. `sleep_diary_questions`
**Purpose:** Stores daily sleep diary questions

**Changes:**
- ➕ Same additions as `assessment_questions`
- ➕ Added `pillar` field to map to Sleep 360° pillars
- ➕ Renamed `condition_json` to `conditional_logic` for consistency
- ✅ Kept legacy fields for backward compatibility

---

## How Questions Are Structured

### Example 1: Simple Yes/No Question

**Question:** "Did you take any sleep medication?"

```json
{
  "question_id": "SD_MEDICATION_TAKEN",
  "question_text": "Did you take any sleep-related medication yesterday or last night?",
  "answer_format": "single_select_chips",
  "format_config": {
    "options": [
      { "value": "yes", "label": "Yes" },
      { "value": "no", "label": "No" }
    ],
    "layout": "horizontal"
  },
  "validation_rules": {
    "required": true
  },
  "estimated_time_seconds": 12
}
```

**User sees:** Two large chip buttons: [Yes] [No]  
**Stored in database:** `response_value = "yes"` or `"no"`

---

### Example 2: Time Picker Question

**Question:** "What time did you go to bed?"

```json
{
  "question_id": "SD_GOT_INTO_BED",
  "question_text": "What time did you get into bed last night?",
  "answer_format": "time_picker",
  "format_config": {
    "format": "HH:MM",
    "allowCrossMidnight": true
  },
  "validation_rules": {
    "required": true
  },
  "estimated_time_seconds": 18
}
```

**User sees:** Native iOS/Android time picker wheel  
**Stored in database:** `response_value = "23:30"`

---

### Example 3: Minutes Scroll Wheel

**Question:** "How long did it take to fall asleep?"

```json
{
  "question_id": "SD_SLEEP_LATENCY",
  "question_text": "How long did it take you to fall asleep? (minutes)",
  "answer_format": "minutes_scroll",
  "format_config": {
    "min": 0,
    "max": 200,
    "defaultValue": 15,
    "step": 5,
    "specialValue": {
      "value": 201,
      "label": "I couldn't fall asleep"
    }
  },
  "validation_rules": {
    "required": true,
    "min": 0,
    "max": 201
  },
  "estimated_time_seconds": 12
}
```

**User sees:** Scroll wheel: 0, 5, 10, 15, 20... 200, "I couldn't fall asleep"  
**Stored in database:** `response_number = 45` (or 201 for special case)

---

### Example 4: Slider Scale

**Question:** "Rate your sleep quality"

```json
{
  "question_id": "SD_SLEEP_QUALITY",
  "question_text": "How would you rate the quality of your sleep last night?",
  "answer_format": "slider_scale",
  "format_config": {
    "min": 1,
    "max": 10,
    "minLabel": "Worst",
    "maxLabel": "Best",
    "defaultValue": 5,
    "showNumberLabel": true,
    "step": 1
  },
  "validation_rules": {
    "required": true,
    "min": 1,
    "max": 10
  },
  "estimated_time_seconds": 12
}
```

**User sees:** Visual slider with "Worst" on left, "Best" on right, current value "7" displayed  
**Stored in database:** `response_number = 7`

---

### Example 5: Conditional Question

**Question:** "What time did you take medication?" (only if answered "yes" to taking medication)

```json
{
  "question_id": "SD_MEDICATION_TIME",
  "question_text": "If yes, what time did you take it?",
  "answer_format": "time_picker",
  "format_config": {
    "format": "HH:MM",
    "allowCrossMidnight": true
  },
  "validation_rules": {
    "required": false
  },
  "conditional_logic": {
    "show_if": {
      "question_id": "SD_MEDICATION_TAKEN",
      "operator": "equals",
      "value": "yes"
    }
  },
  "estimated_time_seconds": 18
}
```

**Logic:** Only shown if user answered "yes" to `SD_MEDICATION_TAKEN`  
**User sees:** Time picker (only if condition met)  
**Stored in database:** `response_value = "22:30"` (or nothing if not shown)

---

### Example 6: Multi-Select Chips

**Question:** "What sleep aids do you use?"

```json
{
  "question_id": "33D",
  "question_text": "Do you use any sleep aids?",
  "help_text": "Select all that apply",
  "answer_format": "multi_select_chips",
  "format_config": {
    "options": [
      { "value": "white_noise", "label": "White noise" },
      { "value": "fan", "label": "Fan" },
      { "value": "humidifier", "label": "Humidifier" },
      { "value": "blackout_curtains", "label": "Blackout curtains" },
      { "value": "none", "label": "None" }
    ],
    "layout": "grid",
    "minSelections": 0,
    "maxSelections": 10
  },
  "validation_rules": {
    "required": false
  },
  "estimated_time_seconds": 30
}
```

**User sees:** Multiple chip buttons, can tap several to select  
**Stored in database:** `response_array = '["white_noise","fan","blackout_curtains"]'`

---

### Example 7: Repeating Group (Complex)

**Question:** "Record each nap (time + duration)"

```json
{
  "question_id": "SD_NAP_DETAILS",
  "question_text": "For each nap, record the start time and duration.",
  "answer_format": "repeating_group",
  "format_config": {
    "fields": [
      {
        "id": "nap_start_time",
        "label": "Nap start time",
        "type": "time_picker",
        "config": { "format": "HH:MM" }
      },
      {
        "id": "nap_duration_minutes",
        "label": "Nap duration (minutes)",
        "type": "minutes_scroll",
        "config": { "min": 5, "max": 240, "defaultValue": 30, "step": 5 }
      }
    ],
    "minInstances": 0,
    "maxInstances": 5,
    "addButtonText": "+ Add another nap",
    "removeButtonText": "Remove"
  },
  "validation_rules": {
    "required": false
  },
  "estimated_time_seconds": 36
}
```

**User sees:** Dynamic form with "+" button to add naps, each shows time picker + duration scroll wheel  
**Stored in database:** `response_object = '[{"nap_start_time":"14:00","nap_duration_minutes":30},{"nap_start_time":"16:30","nap_duration_minutes":45}]'`

---

## Implementation Plan

### Phase 1: Database Updates (Week 1)
- [ ] Deploy updated `schema.ts` to Convex
- [ ] Verify tables created with new fields
- [ ] Create backup of existing questions
- [ ] Test schema in development environment

### Phase 2: Data Migration (Week 2-3)
- [ ] Create migration scripts for each question type
- [ ] Run migrations on development database
- [ ] Verify all questions have `answer_format` and `format_config`
- [ ] Test reading migrated data

### Phase 3: UI Components (Week 4-5)
- [ ] Build 8 core answer format components in React/React Native:
  - `<TimePicker>`
  - `<MinutesScrollWheel>`
  - `<NumberScrollWheel>`
  - `<SliderScale>`
  - `<SingleSelectChips>`
  - `<MultiSelectChips>`
  - `<DatePicker>`
  - `<NumberInput>`
  - `<RepeatingGroup>` (wraps other components)
- [ ] Build `<QuestionRenderer>` that picks correct component based on `answer_format`
- [ ] Add validation logic
- [ ] Add conditional logic evaluator
- [ ] Test each component type

### Phase 4: Integration (Week 6)
- [ ] Update question fetching logic
- [ ] Update response saving logic
- [ ] Update question navigation
- [ ] Update progress tracking
- [ ] Test full questionnaire flow

### Phase 5: Testing & Optimization (Week 7)
- [ ] User testing with real participants
- [ ] Measure completion times
- [ ] Fix any usability issues
- [ ] Accessibility audit
- [ ] Performance optimization

### Phase 6: Rollout (Week 8)
- [ ] Beta release to small user group
- [ ] Monitor for errors
- [ ] Gather feedback
- [ ] Full release
- [ ] Monitor metrics

---

## Key Benefits

### 1. **Reduced User Friction**
- ✅ Consistent UI patterns across all questions
- ✅ Touch-optimized for mobile (44x44pt minimum touch targets)
- ✅ Smart defaults based on previous answers
- ✅ Auto-advance after selection (where appropriate)

### 2. **Faster Completion**
- ✅ Scroll wheels faster than typing
- ✅ Sliders faster than multiple choice buttons for scales
- ✅ Large chip buttons for quick tapping
- ✅ Estimated **30% time reduction** overall

### 3. **Better Data Quality**
- ✅ Type-safe validation (numbers are actually numbers)
- ✅ Range constraints prevent impossible values
- ✅ Consistent format (all times stored as "HH:MM")
- ✅ No parsing ambiguity

### 4. **Easier Maintenance**
- ✅ One component per answer type (not per question)
- ✅ Configuration-driven (update JSON, not code)
- ✅ Easy to add new questions
- ✅ A/B testing possible by swapping configs

### 5. **Analytics**
- ✅ Track time per question type
- ✅ Identify slow/confusing questions
- ✅ Monitor drop-off points
- ✅ Optimize based on data

---

## File Structure

```
/Users/martinkawalski/Documents/1. Projects/15-Day Test/

Documentation:
├── QUESTION_ANSWER_FORMAT_SPECIFICATION.md  ← Main specification
├── QUESTION_FORMAT_MIGRATION_GUIDE.md       ← Migration steps
└── QUESTION_SYSTEM_SUMMARY.md               ← This file

Database:
└── convex/
    └── schema.ts                             ← Updated schema ✅

Sample Data:
└── data/
    ├── standardized_questions_sample.json   ← 50+ example questions ✅
    ├── sleep_diary_questions.json           ← Original sleep diary
    ├── sleep360_questions.json              ← Original Sleep 360°
    └── assessment_modules.json              ← Module definitions

To Create (Implementation):
└── client/components/
    └── questions/
        ├── QuestionRenderer.tsx             ← Main component
        ├── TimePicker.tsx                   ← Time picker
        ├── MinutesScrollWheel.tsx           ← Minutes scroll
        ├── NumberScrollWheel.tsx            ← Number scroll
        ├── SliderScale.tsx                  ← Slider
        ├── SingleSelectChips.tsx            ← Single select
        ├── MultiSelectChips.tsx             ← Multi select
        ├── DatePicker.tsx                   ← Date picker
        ├── NumberInput.tsx                  ← Number input
        └── RepeatingGroup.tsx               ← Repeating group
```

---

## Next Steps

### Immediate (This Week)
1. ✅ **Review** this summary document
2. ⏭️ **Deploy** updated Convex schema
3. ⏭️ **Test** schema in development

### Short Term (Next 2 Weeks)
4. ⏭️ **Create** migration scripts
5. ⏭️ **Migrate** existing questions to new format
6. ⏭️ **Verify** migration success

### Medium Term (Weeks 3-6)
7. ⏭️ **Build** UI components
8. ⏭️ **Integrate** with existing app
9. ⏭️ **Test** thoroughly

### Long Term (Weeks 7-8)
10. ⏭️ **Beta test** with users
11. ⏭️ **Roll out** to production
12. ⏭️ **Monitor** and optimize

---

## Questions & Decisions

### Open Questions
1. **Text input questions:** Should we add support now or later?
   - **Recommendation:** Add later. Skip for MVP to minimize friction.
   
2. **Validation messages:** Where should error messages be defined?
   - **Recommendation:** In `validation_rules` JSON as `errorMessages` object.
   
3. **Accessibility:** What screen reader support is needed?
   - **Recommendation:** Follow WCAG AA guidelines, test with VoiceOver/TalkBack.
   
4. **Analytics:** What metrics should we track?
   - **Recommendation:** Time per question, drop-off rate, validation errors, completion rate.

### Design Decisions Made
- ✅ Use JSON strings for configs (not separate tables) - simpler, more flexible
- ✅ Keep legacy fields for backward compatibility during migration
- ✅ Store different answer types in different response fields (cleaner than JSON blob)
- ✅ Skip open-text questions for now - focus on fast, structured input first
- ✅ Use native pickers where possible (iOS time picker, Android number picker) - better UX

---

## Metrics to Track

### During Migration
- % questions migrated successfully
- Migration errors/warnings
- Data quality checks passed

### Post-Implementation
- Average time per question (by answer_format)
- Completion rate (% users finishing questionnaires)
- Drop-off points (which questions cause abandonment)
- Validation errors (which questions confuse users)
- User satisfaction (feedback ratings)

### Target Metrics
- 📊 **30% reduction** in average completion time
- 🎯 **90%+** completion rate for sleep diary
- ⚡ **< 10 sec** average time per question
- ✅ **< 2%** validation error rate
- 😊 **4.5/5** user satisfaction score

---

## Success Criteria

This implementation is successful when:

1. ✅ All 230+ questions converted to standardized format
2. ✅ Zero data loss during migration
3. ✅ All UI components pass accessibility audit
4. ✅ Average completion time reduced by 30%
5. ✅ User satisfaction score > 4/5
6. ✅ < 1% error rate in production
7. ✅ System supports all existing question types
8. ✅ Easy to add new questions (< 5 minutes per question)

---

## Resources

### Documentation
- [Convex Schema Docs](https://docs.convex.dev/database/schemas)
- [React Native Pickers](https://reactnative.dev/docs/picker)
- [WCAG Accessibility Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)

### Tools
- Convex Dashboard: Monitor database changes
- PostHog/Mixpanel: Track user interactions
- Sentry: Error monitoring
- TestFlight/Firebase: Beta testing

---

## Support & Contact

For questions about this system:
- 📄 **Specification**: See `QUESTION_ANSWER_FORMAT_SPECIFICATION.md`
- 🔧 **Migration**: See `QUESTION_FORMAT_MIGRATION_GUIDE.md`
- 💡 **Examples**: See `data/standardized_questions_sample.json`

---

**Status:** ✅ **Ready for Implementation**  
**Last Updated:** 2025-01-14  
**Next Review:** After Phase 1 (Database Updates)

---

*End of Summary*


