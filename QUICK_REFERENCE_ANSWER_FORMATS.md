# Quick Reference: 8 Answer Format Types

**For Developers Building UI Components**

---

## 1. TIME_PICKER ⏰

**When to use:** Any time-of-day question  
**UI:** Native time picker wheel  
**Storage:** `response_value` as string `"HH:MM"`

```typescript
// Config
{
  "answer_format": "time_picker",
  "format_config": {
    "format": "HH:MM",              // 24-hour format
    "allowCrossMidnight": true      // Handle sleep times
  }
}

// Example values
"23:30"  // 11:30 PM
"06:45"  // 6:45 AM
"14:00"  // 2:00 PM
```

**Component Props:**
```typescript
interface TimePickerProps {
  value: string;              // "HH:MM"
  onChange: (value: string) => void;
  config: {
    format: "HH:MM";
    allowCrossMidnight?: boolean;
  };
}
```

---

## 2. MINUTES_SCROLL ⏱️

**When to use:** Duration in minutes (0-480 range)  
**UI:** Scroll wheel optimized for minutes  
**Storage:** `response_number` as integer

```typescript
// Config
{
  "answer_format": "minutes_scroll",
  "format_config": {
    "min": 0,
    "max": 200,
    "defaultValue": 15,
    "step": 5,                      // Increment by 5
    "specialValue": {               // Optional escape
      "value": 201,
      "label": "I couldn't fall asleep"
    }
  }
}

// Example values
15   // 15 minutes
45   // 45 minutes
201  // Special value (couldn't sleep)
```

**Component Props:**
```typescript
interface MinutesScrollProps {
  value: number;
  onChange: (value: number) => void;
  config: {
    min: number;
    max: number;
    defaultValue: number;
    step: number;
    specialValue?: {
      value: number;
      label: string;
    };
  };
}
```

**Common Ranges:**
- Sleep latency: 0-200 min
- Awake during night: 0-480 min
- Nap duration: 5-240 min

---

## 3. NUMBER_SCROLL 🔢

**When to use:** Small discrete counts (0-20 range)  
**UI:** Scroll wheel for integers  
**Storage:** `response_number` as integer

```typescript
// Config
{
  "answer_format": "number_scroll",
  "format_config": {
    "min": 0,
    "max": 20,
    "defaultValue": 0,
    "unit": "times",               // Display unit
    "step": 1
  }
}

// Example values
0   // None
3   // Three times
7   // Seven cups
```

**Component Props:**
```typescript
interface NumberScrollProps {
  value: number;
  onChange: (value: number) => void;
  config: {
    min: number;
    max: number;
    defaultValue: number;
    unit?: string;
    step: number;
  };
}
```

**Common Uses:**
- Wake-up count: 0-20
- Nap count: 0-5
- Caffeine servings: 0-10
- Hours per week: 0-40

---

## 4. SLIDER_SCALE 📊

**When to use:** Rating scales, severity, frequency  
**UI:** Visual slider with labeled ends  
**Storage:** `response_number` as integer

```typescript
// Config
{
  "answer_format": "slider_scale",
  "format_config": {
    "min": 1,
    "max": 10,
    "minLabel": "Very Poor",
    "maxLabel": "Excellent",
    "defaultValue": 5,
    "showNumberLabel": true,        // Show "7" above slider
    "step": 1,
    "midpointLabel": "Fair"         // Optional middle label
  }
}

// Example values
1   // Worst
7   // Good
10  // Excellent
```

**Component Props:**
```typescript
interface SliderScaleProps {
  value: number;
  onChange: (value: number) => void;
  config: {
    min: number;
    max: number;
    minLabel: string;
    maxLabel: string;
    defaultValue?: number;
    showNumberLabel: boolean;
    step: number;
    midpointLabel?: string;
  };
}
```

**Common Scales:**
- 0-3: PSQI frequency
- 0-4: ISI severity
- 0-10: Pain, quality
- 1-5: Never to Always
- 1-7: FSS fatigue
- 1-10: Consumer ratings

---

## 5. SINGLE_SELECT_CHIPS 🎯

**When to use:** Single choice from 2-7 options  
**UI:** Horizontal or grid chip buttons  
**Storage:** `response_value` as string (option value)

```typescript
// Config
{
  "answer_format": "single_select_chips",
  "format_config": {
    "options": [
      { "value": "yes", "label": "Yes" },
      { "value": "no", "label": "No" }
    ],
    "layout": "horizontal"          // or "vertical" or "grid"
  }
}

// Example values
"yes"
"workday"
"sometimes"
```

**Component Props:**
```typescript
interface SingleSelectChipsProps {
  value: string;
  onChange: (value: string) => void;
  config: {
    options: Array<{
      value: string;
      label: string;
      icon?: string;
    }>;
    layout: "horizontal" | "vertical" | "grid";
    defaultValue?: string;
  };
}
```

**Layout Guidelines:**
- 2-3 options: `horizontal`
- 4-6 options: `grid`
- 7+ options: `vertical` (or use dropdown)

---

## 6. MULTI_SELECT_CHIPS ✅

**When to use:** Multiple selections allowed  
**UI:** Chip buttons with toggle state  
**Storage:** `response_array` as JSON array string

```typescript
// Config
{
  "answer_format": "multi_select_chips",
  "format_config": {
    "options": [
      { "value": "white_noise", "label": "White noise" },
      { "value": "fan", "label": "Fan" },
      { "value": "humidifier", "label": "Humidifier" }
    ],
    "layout": "grid",
    "minSelections": 0,
    "maxSelections": 10
  }
}

// Example values (stored as JSON string)
'["white_noise","fan"]'
'["bathroom","pain","noise"]'
```

**Component Props:**
```typescript
interface MultiSelectChipsProps {
  value: string[];  // Array in memory
  onChange: (value: string[]) => void;
  config: {
    options: Array<{
      value: string;
      label: string;
      icon?: string;
    }>;
    layout: "grid" | "vertical";
    minSelections?: number;
    maxSelections?: number;
    defaultValues?: string[];
  };
}
```

**Storage/Retrieval:**
```typescript
// Saving
response_array: JSON.stringify(["white_noise", "fan"])

// Loading
const selected: string[] = JSON.parse(response.response_array);
```

---

## 7. DATE_PICKER 📅

**When to use:** Calendar date selection  
**UI:** Native date picker or calendar  
**Storage:** `response_value` as ISO date string `"YYYY-MM-DD"`

```typescript
// Config
{
  "answer_format": "date_picker",
  "format_config": {
    "format": "YYYY-MM-DD",
    "minDate": "1920-01-01",        // Optional
    "maxDate": "today",             // Optional, can be date string
    "defaultValue": "today",        // Auto-fill with today
    "autoFill": true
  }
}

// Example values
"2025-01-15"
"1985-06-20"
"2024-12-31"
```

**Component Props:**
```typescript
interface DatePickerProps {
  value: string;              // "YYYY-MM-DD"
  onChange: (value: string) => void;
  config: {
    format: "YYYY-MM-DD";
    minDate?: string;
    maxDate?: string | "today";
    defaultValue?: string | "today";
    autoFill?: boolean;
  };
}
```

---

## 8. NUMBER_INPUT 🔢

**When to use:** Numeric measurements (height, weight, temp)  
**UI:** Numeric keyboard with unit selector  
**Storage:** `response_number` as float/integer

```typescript
// Config
{
  "answer_format": "number_input",
  "format_config": {
    "unitOptions": [
      { "value": "cm", "label": "cm" },
      { "value": "in", "label": "inches", "conversionFactor": 2.54 }
    ],
    "min": 100,
    "max": 250,
    "step": 1,
    "decimalPlaces": 0,             // 0 for int, 1-2 for float
    "inputMode": "numeric"          // or "decimal"
  }
}

// Example values
175     // 175 cm
68.5    // 68.5 kg
21.5    // 21.5°C
```

**Component Props:**
```typescript
interface NumberInputProps {
  value: number;
  onChange: (value: number) => void;
  config: {
    unit?: string;
    unitOptions?: Array<{
      value: string;
      label: string;
      conversionFactor?: number;
    }>;
    min?: number;
    max?: number;
    step?: number;
    decimalPlaces: number;
    inputMode: "numeric" | "decimal";
    defaultValue?: number;
  };
}
```

**Common Uses:**
- Height: 100-250 cm (or 40-100 in)
- Weight: 30-300 kg (or 66-660 lbs)
- Temperature: 15-30°C (or 59-86°F)
- Age: 0-120 years

---

## 9. REPEATING_GROUP 🔁

**When to use:** Multiple instances of same data (e.g., naps)  
**UI:** Dynamic list with add/remove buttons  
**Storage:** `response_object` as JSON object string

```typescript
// Config
{
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
        "label": "Duration",
        "type": "minutes_scroll",
        "config": { "min": 5, "max": 240, "defaultValue": 30, "step": 5 }
      }
    ],
    "minInstances": 0,
    "maxInstances": 5,
    "addButtonText": "+ Add another nap",
    "removeButtonText": "Remove"
  }
}

// Example value (stored as JSON string)
'[
  {"nap_start_time":"14:00","nap_duration_minutes":30},
  {"nap_start_time":"16:30","nap_duration_minutes":45}
]'
```

**Component Props:**
```typescript
interface RepeatingGroupProps {
  value: Array<Record<string, any>>;  // Array of objects in memory
  onChange: (value: Array<Record<string, any>>) => void;
  config: {
    fields: Array<{
      id: string;
      label: string;
      type: string;  // One of the 8 answer formats
      config: any;   // Type-specific config
    }>;
    minInstances: number;
    maxInstances: number;
    addButtonText: string;
    removeButtonText: string;
  };
}
```

**Storage/Retrieval:**
```typescript
// Saving
response_object: JSON.stringify([
  { nap_start_time: "14:00", nap_duration_minutes: 30 },
  { nap_start_time: "16:30", nap_duration_minutes: 45 }
])

// Loading
const instances = JSON.parse(response.response_object);
```

---

## Conditional Logic

Questions can be shown/hidden based on previous answers:

```typescript
{
  "conditional_logic": {
    "show_if": {
      "question_id": "SD_MEDICATION_TAKEN",
      "operator": "equals",              // or "not_equals", "greater_than", etc.
      "value": "yes"
    }
  }
}
```

**Supported Operators:**
- `equals` - Exact match
- `not_equals` - Not equal
- `greater_than` - Numeric >
- `less_than` - Numeric <
- `greater_than_or_equal` - Numeric >=
- `less_than_or_equal` - Numeric <=
- `in_array` - Value in list
- `not_in_array` - Value not in list

**Implementation:**
```typescript
function shouldShowQuestion(
  question: Question,
  previousResponses: Map<string, any>
): boolean {
  if (!question.conditional_logic) return true;
  
  const logic = JSON.parse(question.conditional_logic);
  const dependentValue = previousResponses.get(logic.question_id);
  
  switch (logic.operator) {
    case 'equals':
      return dependentValue === logic.value;
    case 'greater_than':
      return Number(dependentValue) > Number(logic.value);
    // ... etc
  }
}
```

---

## Validation

All questions can have validation rules:

```typescript
{
  "validation_rules": {
    "required": true,           // Must answer
    "min": 0,                   // Min value (numbers)
    "max": 10,                  // Max value (numbers)
    "minLength": 3,             // Min string length
    "maxLength": 100,           // Max string length
    "pattern": "^[0-9]+$",      // Regex pattern
    "errorMessages": {          // Custom error messages
      "required": "This field is required",
      "min": "Must be at least 0",
      "max": "Must be at most 10"
    }
  }
}
```

**Implementation:**
```typescript
function validateAnswer(
  question: Question,
  value: any
): { valid: boolean; error?: string } {
  const rules = JSON.parse(question.validation_rules);
  
  if (rules.required && (value === null || value === undefined || value === '')) {
    return {
      valid: false,
      error: rules.errorMessages?.required || 'This field is required'
    };
  }
  
  if (rules.min !== undefined && Number(value) < rules.min) {
    return {
      valid: false,
      error: rules.errorMessages?.min || `Must be at least ${rules.min}`
    };
  }
  
  // ... more validation
  
  return { valid: true };
}
```

---

## Response Storage Mapping

| Answer Format | Storage Field | TypeScript Type | Example |
|---------------|---------------|-----------------|---------|
| `time_picker` | `response_value` | `string` | `"23:30"` |
| `single_select_chips` | `response_value` | `string` | `"yes"` |
| `date_picker` | `response_value` | `string` | `"2025-01-15"` |
| `minutes_scroll` | `response_number` | `number` | `45` |
| `number_scroll` | `response_number` | `number` | `3` |
| `slider_scale` | `response_number` | `number` | `7` |
| `number_input` | `response_number` | `number` | `175.5` |
| `multi_select_chips` | `response_array` | `string` (JSON) | `'["a","b"]'` |
| `repeating_group` | `response_object` | `string` (JSON) | `'[{...}]'` |

---

## Main Renderer Component

```typescript
// QuestionRenderer.tsx
import React from 'react';
import { Question, QuestionResponse } from './types';

interface Props {
  question: Question;
  value: any;
  onChange: (value: any) => void;
  onNext?: () => void;
}

export function QuestionRenderer({ question, value, onChange, onNext }: Props) {
  const config = JSON.parse(question.format_config);
  
  // Show/hide based on conditional logic
  if (!shouldShowQuestion(question, previousResponses)) {
    return null;
  }
  
  // Validate answer
  const validation = validateAnswer(question, value);
  
  return (
    <div className="question-container">
      <h2>{question.question_text}</h2>
      {question.help_text && <p className="help-text">{question.help_text}</p>}
      
      {/* Render appropriate component based on answer_format */}
      {question.answer_format === 'time_picker' && (
        <TimePicker value={value} onChange={onChange} config={config} />
      )}
      {question.answer_format === 'minutes_scroll' && (
        <MinutesScrollWheel value={value} onChange={onChange} config={config} />
      )}
      {question.answer_format === 'number_scroll' && (
        <NumberScrollWheel value={value} onChange={onChange} config={config} />
      )}
      {question.answer_format === 'slider_scale' && (
        <SliderScale value={value} onChange={onChange} config={config} />
      )}
      {question.answer_format === 'single_select_chips' && (
        <SingleSelectChips value={value} onChange={onChange} config={config} />
      )}
      {question.answer_format === 'multi_select_chips' && (
        <MultiSelectChips value={value} onChange={onChange} config={config} />
      )}
      {question.answer_format === 'date_picker' && (
        <DatePicker value={value} onChange={onChange} config={config} />
      )}
      {question.answer_format === 'number_input' && (
        <NumberInput value={value} onChange={onChange} config={config} />
      )}
      {question.answer_format === 'repeating_group' && (
        <RepeatingGroup value={value} onChange={onChange} config={config} />
      )}
      
      {/* Validation error */}
      {!validation.valid && (
        <p className="error-message">{validation.error}</p>
      )}
      
      {/* Next button */}
      <button onClick={onNext} disabled={!validation.valid}>
        Next
      </button>
    </div>
  );
}
```

---

## Saving Responses

```typescript
async function saveResponse(
  userId: string,
  questionId: string,
  answerFormat: string,
  value: any
) {
  const startTime = Date.now();
  
  // Determine which field to use
  let responseData: Partial<UserAssessmentResponse> = {
    user_id: userId,
    question_id: questionId,
    created_at: Date.now(),
    updated_at: Date.now(),
  };
  
  switch (answerFormat) {
    case 'time_picker':
    case 'single_select_chips':
    case 'date_picker':
      responseData.response_value = value;
      break;
      
    case 'minutes_scroll':
    case 'number_scroll':
    case 'slider_scale':
    case 'number_input':
      responseData.response_number = typeof value === 'number' ? value : Number(value);
      break;
      
    case 'multi_select_chips':
      responseData.response_array = JSON.stringify(value);
      break;
      
    case 'repeating_group':
      responseData.response_object = JSON.stringify(value);
      break;
      
    default:
      throw new Error(`Unknown answer format: ${answerFormat}`);
  }
  
  // Track time taken
  responseData.answered_in_seconds = Math.floor((Date.now() - startTime) / 1000);
  
  // Save to database
  await saveToDatabase(responseData);
}
```

---

## Loading Responses

```typescript
async function loadResponse(
  userId: string,
  questionId: string,
  answerFormat: string
): Promise<any> {
  const response = await db.query('user_assessment_responses')
    .where('user_id', userId)
    .where('question_id', questionId)
    .first();
  
  if (!response) return null;
  
  switch (answerFormat) {
    case 'time_picker':
    case 'single_select_chips':
    case 'date_picker':
      return response.response_value;
      
    case 'minutes_scroll':
    case 'number_scroll':
    case 'slider_scale':
    case 'number_input':
      return response.response_number;
      
    case 'multi_select_chips':
      return JSON.parse(response.response_array);
      
    case 'repeating_group':
      return JSON.parse(response.response_object);
      
    default:
      throw new Error(`Unknown answer format: ${answerFormat}`);
  }
}
```

---

## Accessibility Requirements

### All Components Must Have:
1. ✅ **Proper labels** - Screen reader accessible
2. ✅ **Keyboard navigation** - Tab through, Enter to select
3. ✅ **Focus indicators** - Visual focus state
4. ✅ **Error announcements** - Screen reader reads errors
5. ✅ **ARIA attributes** - role, aria-label, aria-describedby
6. ✅ **Touch targets** - Minimum 44x44pt
7. ✅ **Color contrast** - WCAG AA (4.5:1 for text)

### Example:
```tsx
<button
  role="button"
  aria-label={`Select ${option.label}`}
  aria-pressed={isSelected}
  onPress={handleSelect}
  style={{
    minWidth: 44,
    minHeight: 44,
    // ... contrast-compliant colors
  }}
>
  {option.label}
</button>
```

---

## Testing Checklist

For each component:
- [ ] Renders correctly with all config options
- [ ] Handles value changes
- [ ] Validates input
- [ ] Shows errors
- [ ] Works with keyboard
- [ ] Works with screen reader
- [ ] Touch targets are large enough
- [ ] Performance is acceptable (< 100ms render)
- [ ] Works on iOS, Android, Web
- [ ] Handles edge cases (null, undefined, invalid values)

---

**Quick Reference Complete** ✅

*See full specification in `QUESTION_ANSWER_FORMAT_SPECIFICATION.md`*


