# Question Answer Format Specification
## Sleep 360° Platform - Unified Question Types & Answer Formats

**Last Updated:** 2025-01-14  
**Purpose:** Standardize all question presentation and answer collection across the platform to minimize user friction and maximize speed.

---

## Executive Summary

After analyzing 230+ questions across multiple questionnaires (Sleep Diary, Sleep 360°, Assessment Modules), we've identified **8 core answer format types** that cover all use cases. This specification ensures:

1. **Consistency** - Similar questions use identical UI components
2. **Speed** - Optimized input methods (scroll wheels, sliders) over text input
3. **Mobile-First** - Touch-optimized interactions
4. **Accessibility** - Clear labels, appropriate input constraints
5. **Validation** - Built-in data quality checks

---

## Core Answer Format Types

### 1. **TIME_PICKER** 
**Use Case:** Any time-of-day question  
**UI Component:** Native time picker (12h or 24h based on locale)  
**Data Type:** `string` (HH:MM format, 24-hour)  
**Examples:**
- "What time did you get into bed?"
- "What time did you wake up?"
- "When do you typically eat your last meal?"

**Implementation:**
```typescript
{
  type: "time_picker",
  format: "HH:MM",
  defaultValue?: string,
  minTime?: string,  // e.g., "00:00"
  maxTime?: string,  // e.g., "23:59"
  allowCrossMidnight: boolean  // Handle sleep times that cross midnight
}
```

**Database Storage:** `v.string()` - stored as "HH:MM"

---

### 2. **MINUTES_SCROLL**
**Use Case:** Duration in minutes (0-480 range typical)  
**UI Component:** Scroll wheel/number picker optimized for minutes  
**Data Type:** `number` (integer)  
**Increment:** Configurable (1, 5, 10, 15 minute steps)  
**Examples:**
- "How long did it take you to fall asleep? (minutes)"
- "How much total time were you awake during the night?"
- "Duration of nap"

**Implementation:**
```typescript
{
  type: "minutes_scroll",
  min: number,              // e.g., 0
  max: number,              // e.g., 200 for sleep latency
  defaultValue: number,     // e.g., 15
  step: number,             // e.g., 5 (increment by 5 mins)
  specialValue?: {          // Optional escape value
    value: number,          // e.g., 201
    label: string          // e.g., "I couldn't fall asleep"
  }
}
```

**Database Storage:** `v.number()` - integer minutes

**Common Ranges:**
- Sleep latency: 0-200 minutes (special: "couldn't sleep")
- Awake during night: 0-480 minutes
- Nap duration: 1-240 minutes

---

### 3. **NUMBER_SCROLL**
**Use Case:** Small discrete numbers (counts, quantities)  
**UI Component:** Scroll wheel/number picker  
**Data Type:** `number` (integer)  
**Examples:**
- "How many times did you wake up during the night?" (0-20)
- "How many naps did you take?" (0-5)
- "How many cups of coffee per day?" (0-10)

**Implementation:**
```typescript
{
  type: "number_scroll",
  min: number,           // e.g., 0
  max: number,           // e.g., 20
  defaultValue: number,  // e.g., 0
  unit?: string,         // e.g., "times", "cups"
  step: number          // usually 1
}
```

**Database Storage:** `v.number()` - integer

**Common Ranges:**
- Wake-up count: 0-20
- Nap count: 0-5
- Caffeine servings: 0-10
- Alcohol drinks: 0-20

---

### 4. **SLIDER_SCALE**
**Use Case:** Rating scales, severity, intensity questions  
**UI Component:** Visual slider with labeled endpoints  
**Data Type:** `number` (integer)  
**Display:** Show current value, labeled min/max  
**Examples:**
- "Rate sleep quality (1-10)"
- "Pain severity (0-10)"
- "How often? (Never 0 → Always 5)"

**Implementation:**
```typescript
{
  type: "slider_scale",
  min: number,                    // e.g., 0 or 1
  max: number,                    // e.g., 10
  minLabel: string,               // e.g., "Very Poor" or "Never"
  maxLabel: string,               // e.g., "Excellent" or "Always"
  defaultValue?: number,
  showNumberLabel: boolean,       // Show numeric value above slider
  step: number,                   // Usually 1
  midpointLabel?: string         // Optional middle label
}
```

**Database Storage:** `v.number()` - integer scale value

**Standard Scale Mappings:**

| Scale Range | Description | Common Use |
|-------------|-------------|------------|
| 0-3 | PSQI-style frequency | "Not at all" to "Three+ times/week" |
| 0-4 | ISI severity | "None" to "Very severe" |
| 1-4 | MEQ preferences | Binary choice sets |
| 0-10 | Pain/Quality | Standard clinical scale |
| 1-10 | Quality ratings | Consumer-friendly |
| 1-5 | Frequency | "Never" to "Always" |
| 1-7 | FSS fatigue | Fatigue Severity Scale |

---

### 5. **SINGLE_SELECT_CHIPS**
**Use Case:** Single choice from 2-7 options (mutually exclusive)  
**UI Component:** Horizontal chip buttons (touch-optimized)  
**Data Type:** `string` (selected option value)  
**Visual:** Large touch targets, active state  
**Examples:**
- "Did you take medication? [Yes] [No]"
- "Day type: [Workday] [School] [Day Off] [Vacation]"
- "Employment status: [Full-time] [Part-time] [Retired] [Student]"

**Implementation:**
```typescript
{
  type: "single_select_chips",
  options: Array<{
    value: string,       // Stored value
    label: string,       // Display text
    icon?: string       // Optional icon
  }>,
  defaultValue?: string,
  layout: "horizontal" | "vertical" | "grid"  // 2-3 options=horizontal, 4+=grid
}
```

**Database Storage:** `v.string()` - the selected option value

**Best Practices:**
- Use for 2-7 options
- Keep labels short (1-2 words ideal)
- Order: logical sequence (Yes/No, chronological, severity)

---

### 6. **MULTI_SELECT_CHIPS**
**Use Case:** Multiple selections allowed from list  
**UI Component:** Chip buttons with toggle state  
**Data Type:** `array<string>` (array of selected values)  
**Examples:**
- "Sleep aids used: [White noise] [Fan] [Blackout curtains] [Humidifier]"
- "Reasons for waking: [Bathroom] [Pain] [Noise] [Temperature]"

**Implementation:**
```typescript
{
  type: "multi_select_chips",
  options: Array<{
    value: string,
    label: string,
    icon?: string
  }>,
  minSelections?: number,  // e.g., 0 for optional
  maxSelections?: number,  // e.g., 3 for "pick top 3"
  defaultValues?: string[],
  layout: "grid" | "vertical"
}
```

**Database Storage:** `v.array(v.string())` - array of selected option values

---

### 7. **DATE_PICKER**
**Use Case:** Calendar date selection  
**UI Component:** Native date picker or calendar widget  
**Data Type:** `string` (ISO date format YYYY-MM-DD)  
**Examples:**
- "Date of birth"
- "Date" (for diary entries - usually auto-filled)

**Implementation:**
```typescript
{
  type: "date_picker",
  format: "YYYY-MM-DD",
  minDate?: string,         // e.g., "1920-01-01"
  maxDate?: string,         // e.g., "today"
  defaultValue?: string,    // "today" or specific date
  autoFill?: boolean       // Pre-fill with today's date
}
```

**Database Storage:** `v.string()` - ISO date "YYYY-MM-DD"

---

### 8. **NUMBER_INPUT**
**Use Case:** Numeric measurements (height, weight, temperature, etc.)  
**UI Component:** Numeric keyboard input with unit display  
**Data Type:** `number` (float or integer)  
**Examples:**
- "Height (cm or inches)"
- "Weight (kg or lbs)"
- "Bedroom temperature (°F/°C)"
- "Hours per week"

**Implementation:**
```typescript
{
  type: "number_input",
  unit: string,              // e.g., "cm", "lbs", "°F"
  unitOptions?: Array<{      // Multiple unit support
    value: string,           // e.g., "cm"
    label: string,           // e.g., "cm"
    conversionFactor?: number
  }>,
  min?: number,
  max?: number,
  step?: number,             // e.g., 0.1 for decimals
  decimalPlaces: number,     // 0 for integers, 1-2 for float
  defaultValue?: number,
  inputMode: "numeric" | "decimal"
}
```

**Database Storage:** `v.number()` - stored in standard unit (convert if needed)

**Common Measurements:**
- Height: 100-250 cm (or 40-100 inches)
- Weight: 30-300 kg (or 66-660 lbs)
- Temperature: 15-30°C (or 59-86°F)
- BMI: Calculated, don't ask directly

---

## Special Case: Repeating Groups

**Use Case:** Multiple instances of same data structure (e.g., multiple naps)  
**UI Component:** Dynamic list with add/remove  
**Examples:**
- Nap tracking: For each nap, collect start time + duration

**Implementation:**
```typescript
{
  type: "repeating_group",
  fields: Array<{
    id: string,
    label: string,
    type: string,      // One of the 8 core types
    config: object     // Type-specific config
  }>,
  minInstances: number,   // e.g., 0
  maxInstances: number,   // e.g., 5 for naps
  addButtonText: string,  // e.g., "+ Add another nap"
  removeButtonText: string
}
```

**Example: Nap Tracking**
```typescript
{
  type: "repeating_group",
  fields: [
    {
      id: "nap_start_time",
      label: "Nap start time",
      type: "time_picker"
    },
    {
      id: "nap_duration_minutes",
      label: "Duration",
      type: "minutes_scroll",
      min: 5,
      max: 240,
      defaultValue: 30
    }
  ],
  minInstances: 0,
  maxInstances: 5
}
```

**Database Storage:** `v.array(v.object({ ... }))` - array of structured objects

---

## Question Type Mapping

### From Sleep 360° Questions → Unified Types

| Original Scale Type | Unified Type | Config |
|---------------------|--------------|--------|
| `"Yes/No"` | `single_select_chips` | options: ["Yes", "No"] |
| `"Yes/No/Don't know"` | `single_select_chips` | options: ["Yes", "No", "Don't know"] |
| `"Yes/No/Not applicable"` | `single_select_chips` | options: ["Yes", "No", "Not applicable"] |
| `"1-10 scale"` | `slider_scale` | min: 1, max: 10 |
| `"0-10 scale"` | `slider_scale` | min: 0, max: 10 |
| `"0-3 scale"` | `slider_scale` | min: 0, max: 3 |
| `"0-4 scale"` | `slider_scale` | min: 0, max: 4 |
| `"1-4 scale"` | `slider_scale` | min: 1, max: 4 |
| `"1-5 scale"` | `slider_scale` | min: 1, max: 5 |
| `"5-point scale"` | `slider_scale` | min: 1, max: 5 |
| `"1-7 scale"` | `slider_scale` | min: 1, max: 7 |
| `"Number"` | `number_scroll` OR `number_input` | Depends on range |
| `"Number (minutes)"` | `minutes_scroll` | As defined above |
| `"Number (hours)"` | `number_scroll` | unit: "hours" |
| `"Time"` | `time_picker` | HH:MM format |
| `"Time range"` | Two `time_picker` fields | Start + End |
| `"Date"` | `date_picker` | ISO format |
| `"Text"` | **SKIP FOR NOW** | Open-ended - add later |
| `"Text (list)"` | **SKIP FOR NOW** | Open-ended - add later |
| `"Email"` | **ONE-TIME ONLY** | Registration only |
| `"Multiple choice"` | `single_select_chips` | 2-7 options |
| `"Multiple select"` | `multi_select_chips` | Multiple allowed |
| `"4-point scale"` | `slider_scale` | min: 1, max: 4 |

---

## Database Schema Requirements

### Current Schema (from schema.ts)

The existing `assessment_questions` table needs enhancement:

```typescript
assessment_questions: defineTable({
  question_id: v.string(),
  question_text: v.string(),
  pillar: v.string(),
  tier: v.string(),
  question_type: v.string(),
  options_json: v.optional(v.string()),  // ✅ GOOD - stores config
  estimated_time: v.optional(v.number()),
  trigger: v.optional(v.string()),
  notes: v.optional(v.string()),
})
```

### Enhanced Question Schema

Add these fields to support all answer formats:

```typescript
assessment_questions: defineTable({
  question_id: v.string(),
  question_text: v.string(),
  help_text: v.optional(v.string()),     // 🆕 Helper text under question
  
  // Answer format configuration
  answer_format: v.string(),              // 🆕 One of 8 core types
  format_config: v.string(),              // 🆕 JSON config for the type
  
  // Validation
  validation_rules: v.optional(v.string()), // 🆕 JSON validation rules
  
  // Display
  pillar: v.string(),
  tier: v.string(),
  order_index: v.optional(v.number()),    // 🆕 Question ordering
  
  // Metadata
  estimated_time_seconds: v.number(),     // 🆕 Change to seconds
  created_at: v.number(),
  updated_at: v.number(),
})
```

### Response Storage Schema

The `user_assessment_responses` table is good but can be enhanced:

```typescript
user_assessment_responses: defineTable({
  user_id: v.id("users"),
  question_id: v.string(),
  
  // Response value (type depends on answer format)
  response_value: v.optional(v.string()),     // ✅ String for most
  response_number: v.optional(v.number()),    // 🆕 Numbers, scales
  response_array: v.optional(v.string()),     // 🆕 JSON array for multi-select
  response_object: v.optional(v.string()),    // 🆕 JSON object for complex
  
  // Metadata
  day_number: v.optional(v.number()),
  answered_in_seconds: v.optional(v.number()), // 🆕 Track speed
  created_at: v.number(),
  updated_at: v.number(),
})
```

**Storage by Type:**

| Answer Format | Storage Field | Example Value |
|---------------|---------------|---------------|
| `time_picker` | `response_value` | `"23:30"` |
| `minutes_scroll` | `response_number` | `45` |
| `number_scroll` | `response_number` | `3` |
| `slider_scale` | `response_number` | `7` |
| `single_select_chips` | `response_value` | `"Yes"` |
| `multi_select_chips` | `response_array` | `'["White noise","Fan"]'` |
| `date_picker` | `response_value` | `"2025-01-15"` |
| `number_input` | `response_number` | `175.5` |
| `repeating_group` | `response_object` | `'[{"time":"14:00","mins":30}]'` |

---

## Question Configuration Examples

### Example 1: Sleep Latency (Minutes Scroll)

```json
{
  "question_id": "SD_SLEEP_LATENCY",
  "question_text": "How long did it take you to fall asleep?",
  "help_text": "Your best estimate in minutes",
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
  "estimated_time_seconds": 10
}
```

### Example 2: Sleep Quality (Slider Scale)

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
  "estimated_time_seconds": 8
}
```

### Example 3: Wake-ups Count (Number Scroll)

```json
{
  "question_id": "SD_AWAKENINGS_COUNT",
  "question_text": "How many times did you wake up during the night?",
  "answer_format": "number_scroll",
  "format_config": {
    "min": 0,
    "max": 20,
    "defaultValue": 0,
    "unit": "times",
    "step": 1
  },
  "validation_rules": {
    "required": true,
    "min": 0,
    "max": 20
  },
  "estimated_time_seconds": 8
}
```

### Example 4: Medication Taken (Yes/No Chips)

```json
{
  "question_id": "SD_MEDICATION_TAKEN",
  "question_text": "Did you take any sleep-related medication yesterday or last night?",
  "answer_format": "single_select_chips",
  "format_config": {
    "options": [
      { "value": "Yes", "label": "Yes" },
      { "value": "No", "label": "No" }
    ],
    "layout": "horizontal"
  },
  "validation_rules": {
    "required": true
  },
  "estimated_time_seconds": 5
}
```

### Example 5: Day Type (Single Select Chips)

```json
{
  "question_id": "SD_DAY_TYPE",
  "question_text": "What type of day is today?",
  "answer_format": "single_select_chips",
  "format_config": {
    "options": [
      { "value": "workday", "label": "Workday" },
      { "value": "school", "label": "School Day" },
      { "value": "off", "label": "Day Off" },
      { "value": "vacation", "label": "Vacation" }
    ],
    "layout": "grid"
  },
  "validation_rules": {
    "required": true
  },
  "estimated_time_seconds": 6
}
```

### Example 6: Bedtime (Time Picker)

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
  "estimated_time_seconds": 12
}
```

### Example 7: Sleep Aids (Multi-Select Chips)

```json
{
  "question_id": "33D",
  "question_text": "Do you use any sleep aids?",
  "answer_format": "multi_select_chips",
  "format_config": {
    "options": [
      { "value": "white_noise", "label": "White noise" },
      { "value": "fan", "label": "Fan" },
      { "value": "humidifier", "label": "Humidifier" },
      { "value": "air_purifier", "label": "Air purifier" },
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
  "estimated_time_seconds": 10
}
```

### Example 8: Height (Number Input)

```json
{
  "question_id": "D5",
  "question_text": "Height",
  "answer_format": "number_input",
  "format_config": {
    "unitOptions": [
      { "value": "cm", "label": "cm" },
      { "value": "in", "label": "inches", "conversionFactor": 2.54 }
    ],
    "min": 100,
    "max": 250,
    "step": 1,
    "decimalPlaces": 0,
    "inputMode": "numeric"
  },
  "validation_rules": {
    "required": true,
    "min": 100,
    "max": 250
  },
  "estimated_time_seconds": 15
}
```

---

## Conditional Logic Support

Questions can have conditions based on previous answers:

```json
{
  "question_id": "SD_MEDICATION_TIME",
  "question_text": "If yes, what time did you take it?",
  "answer_format": "time_picker",
  "format_config": { ... },
  "conditional_logic": {
    "show_if": {
      "question_id": "SD_MEDICATION_TAKEN",
      "operator": "equals",
      "value": "Yes"
    }
  }
}
```

**Supported Operators:**
- `equals` - exact match
- `not_equals`
- `greater_than` - for numeric values
- `less_than`
- `in_array` - value is in list
- `not_in_array`

---

## UI/UX Guidelines

### Speed Optimization
1. **Auto-advance:** Move to next question automatically after selection (for single-select)
2. **Smart defaults:** Pre-fill based on previous day's data
3. **Batch display:** Group related questions on same screen
4. **Progress bar:** Show completion percentage

### Mobile Interactions
1. **Large touch targets:** Minimum 44x44pt
2. **Scroll wheels:** Native iOS/Android pickers for numbers
3. **Haptic feedback:** Confirm selections
4. **Swipe navigation:** Swipe to advance after answering

### Accessibility
1. **Voice over:** All elements labeled
2. **Dynamic type:** Support system font sizes
3. **Color contrast:** WCAG AA minimum
4. **Error messages:** Clear, actionable

---

## Validation Rules

### Global Validation
- All questions check for required/optional
- Range validation for numbers
- Format validation for times/dates

### Custom Validation Examples

```typescript
// Sleep efficiency check
if (timeInBedMinutes < totalSleepMinutes) {
  error("Sleep time cannot exceed time in bed");
}

// Logical time sequence
if (bedTime > wakeTime && !crossesMidnight) {
  warning("Did this cross midnight? Check times.");
}

// Extreme values
if (sleepLatency > 120) {
  warning("Sleep latency over 2 hours - is this correct?");
}
```

---

## Migration Plan

### Phase 1: Update Database Schema ✅
- Add new fields to `assessment_questions`
- Add new response fields to `user_assessment_responses`
- Migrate existing questions to new format

### Phase 2: Create Question Components
- Build 8 core UI components
- Implement validation logic
- Add conditional logic engine

### Phase 3: Map Existing Questions
- Convert all Sleep 360° questions
- Convert all Sleep Diary questions
- Test each question type

### Phase 4: Testing
- User testing with each component type
- Speed benchmarks (target: <3 sec per question)
- Accessibility audit

---

## Summary Statistics

### Question Type Distribution (Sleep 360° + Sleep Diary)

| Answer Format | Count | % of Total | Avg Time (sec) |
|---------------|-------|-----------|----------------|
| `slider_scale` | 95 | 41% | 8 |
| `single_select_chips` | 62 | 27% | 5 |
| `number_input` | 22 | 10% | 12 |
| `time_picker` | 18 | 8% | 10 |
| `minutes_scroll` | 12 | 5% | 9 |
| `number_scroll` | 11 | 5% | 8 |
| `multi_select_chips` | 5 | 2% | 10 |
| `date_picker` | 3 | 1% | 8 |
| `repeating_group` | 2 | 1% | 30 |
| **Text (skipped)** | ~15 | - | - |
| **TOTAL** | **230** | **100%** | **~8.5 avg** |

### Estimated Completion Times

- **CORE Assessment:** ~65 minutes → **Target: 45 minutes** (31% reduction)
- **Sleep Diary (daily):** ~5 minutes → **Target: 2 minutes** (60% reduction)
- **EXPANSION modules:** Varies by gateway triggers

---

## Next Steps

1. ✅ **This Document** - Complete specification
2. ⏭️ **Update Database Schema** - Add new fields
3. ⏭️ **Build UI Components** - 8 core types in React/React Native
4. ⏭️ **Migrate Question Data** - Convert all questions to new format
5. ⏭️ **Testing & Validation** - User testing, speed optimization

---

**End of Specification**



