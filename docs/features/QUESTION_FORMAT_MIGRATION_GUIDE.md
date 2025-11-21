# Question Format Migration Guide

## Overview

This guide explains how to migrate existing questions from the old format to the new standardized answer format system.

---

## Migration Steps

### Step 1: Database Schema Update

The database schema has been updated with new fields. Deploy the updated schema:

```bash
npx convex deploy
```

**New fields added to `assessment_questions` and `sleep_diary_questions`:**
- `answer_format` (required) - The standardized answer type
- `format_config` (required) - JSON configuration for the answer type
- `help_text` (optional) - Helper text shown below question
- `validation_rules` (optional) - JSON validation rules
- `conditional_logic` (optional) - JSON show/hide logic
- `order_index` (optional) - Question ordering
- `estimated_time_seconds` (required) - Time in seconds (replaces estimated_time)

**New fields added to `user_assessment_responses`:**
- `response_number` - For numeric responses
- `response_array` - For multi-select responses (JSON array string)
- `response_object` - For complex responses (JSON object string)
- `answered_in_seconds` - Track response time

---

## Mapping Old Types to New Answer Formats

### Sleep Diary Questions Mapping

| Old `question_type` | New `answer_format` | Notes |
|---------------------|---------------------|-------|
| `"date_auto"` | `"date_picker"` | Auto-fill with today |
| `"single_select_chips"` | `"single_select_chips"` | ✅ Already correct |
| `"yes_no_chips"` | `"single_select_chips"` | Options: ["Yes", "No"] |
| `"yes_no"` | `"single_select_chips"` | Options: ["Yes", "No"] |
| `"time"` | `"time_picker"` | ✅ Already correct |
| `"minutes_scroll"` | `"minutes_scroll"` | ✅ Already correct |
| `"number_scroll"` | `"number_scroll"` | ✅ Already correct |
| `"scale"` | `"slider_scale"` | Extract min/max from question |
| `"repeating_group"` | `"repeating_group"` | ✅ Already correct |

### Sleep 360° Questions Mapping

| Old `scaleType` | New `answer_format` | Config |
|-----------------|---------------------|--------|
| `"Yes/No"` | `"single_select_chips"` | `options: ["Yes", "No"]` |
| `"Yes/No/Don't know"` | `"single_select_chips"` | `options: ["Yes", "No", "Don't know"]` |
| `"Yes/No/Not applicable"` | `"single_select_chips"` | `options: ["Yes", "No", "Not applicable"]` |
| `"1-10 scale"` | `"slider_scale"` | `min: 1, max: 10` |
| `"0-10 scale"` | `"slider_scale"` | `min: 0, max: 10` |
| `"0-3 scale"` | `"slider_scale"` | `min: 0, max: 3` |
| `"0-4 scale"` | `"slider_scale"` | `min: 0, 4` |
| `"1-4 scale"` | `"slider_scale"` | `min: 1, max: 4` |
| `"1-5 scale"` | `"slider_scale"` | `min: 1, max: 5` |
| `"5-point scale"` | `"slider_scale"` | `min: 1, max: 5` |
| `"4-point scale"` | `"slider_scale"` | `min: 1, max: 4` |
| `"1-7 scale"` | `"slider_scale"` | `min: 1, max: 7` |
| `"Number"` | `"number_scroll"` if 0-100 range<br>`"number_input"` if larger | Context-dependent |
| `"Number (minutes)"` | `"minutes_scroll"` | Standard minutes config |
| `"Number (hours)"` | `"number_scroll"` | `unit: "hours"` |
| `"Time"` | `"time_picker"` | Standard HH:MM |
| `"Time range"` | **Two `"time_picker"` questions** | Split into start/end |
| `"Date"` | `"date_picker"` | ISO format |
| `"Multiple choice"` | `"single_select_chips"` | Extract options from text |
| `"Multiple select"` | `"multi_select_chips"` | Extract options |
| `"Text"` | **SKIP FOR NOW** | To be added later |
| `"Text (list)"` | **SKIP FOR NOW** | To be added later |
| `"Email"` | `"number_input"` | Only for registration |
| `"Calculated"` | **NOT A QUESTION** | Backend calculation |
| `"Body diagram"` | **SKIP FOR NOW** | Complex UI |

---

## Migration Script Structure

### Example Migration Function

```typescript
// convex/migrations/migrateQuestions.ts
import { internalMutation } from "./_generated/server";
import { v } from "convex/values";

export const migrateSleepDiaryQuestions = internalMutation({
  args: {},
  handler: async (ctx) => {
    // Get all old-format questions
    const oldQuestions = await ctx.db
      .query("sleep_diary_questions")
      .collect();

    for (const oldQ of oldQuestions) {
      // Convert to new format
      const newFormat = convertToNewFormat(oldQ);
      
      // Update question
      await ctx.db.patch(oldQ._id, {
        answer_format: newFormat.answer_format,
        format_config: JSON.stringify(newFormat.format_config),
        validation_rules: JSON.stringify(newFormat.validation_rules),
        estimated_time_seconds: (oldQ.estimatedMinutes || 0) * 60,
      });
    }
  },
});

function convertToNewFormat(oldQ: any) {
  const questionType = oldQ.question_type || oldQ.type;
  
  switch (questionType) {
    case "time":
      return {
        answer_format: "time_picker",
        format_config: {
          format: "HH:MM",
          allowCrossMidnight: true
        },
        validation_rules: { required: true }
      };
      
    case "minutes_scroll":
      const config = JSON.parse(oldQ.options_json || "{}");
      return {
        answer_format: "minutes_scroll",
        format_config: {
          min: config.min || oldQ.min || 0,
          max: config.max || oldQ.max || 200,
          defaultValue: config.defaultValue || oldQ.defaultValue || 0,
          step: config.step || 5,
          specialValue: config.specialValue || oldQ.specialValue
        },
        validation_rules: {
          required: oldQ.required !== false,
          min: config.min || oldQ.min || 0,
          max: config.max || oldQ.max || 200
        }
      };
      
    case "scale":
      return {
        answer_format: "slider_scale",
        format_config: {
          min: oldQ.scaleMin || 1,
          max: oldQ.scaleMax || 10,
          minLabel: oldQ.scaleMinLabel || "",
          maxLabel: oldQ.scaleMaxLabel || "",
          showNumberLabel: true,
          step: 1
        },
        validation_rules: {
          required: true,
          min: oldQ.scaleMin || 1,
          max: oldQ.scaleMax || 10
        }
      };
      
    case "yes_no_chips":
    case "yes_no":
      return {
        answer_format: "single_select_chips",
        format_config: {
          options: [
            { value: "Yes", label: "Yes" },
            { value: "No", label: "No" }
          ],
          layout: "horizontal"
        },
        validation_rules: { required: true }
      };
      
    // Add more cases...
    default:
      throw new Error(`Unknown question type: ${questionType}`);
  }
}
```

---

## Step-by-Step Migration Process

### 1. Backup Current Data

```bash
# Export current questions
npx convex export --table assessment_questions --output backup_assessment_questions.json
npx convex export --table sleep_diary_questions --output backup_sleep_diary_questions.json
npx convex export --table user_assessment_responses --output backup_responses.json
```

### 2. Deploy New Schema

```bash
npx convex deploy
```

### 3. Run Migration Script

Create and run migration for each question type:

```bash
# Sleep Diary Questions
npx convex run migrations:migrateSleepDiaryQuestions

# Sleep 360° Questions
npx convex run migrations:migrateSleep360Questions

# Assessment Module Questions
npx convex run migrations:migrateAssessmentQuestions
```

### 4. Verify Migration

```typescript
// convex/migrations/verifyMigration.ts
export const verifyMigration = internalQuery({
  args: {},
  handler: async (ctx) => {
    const questions = await ctx.db
      .query("assessment_questions")
      .collect();
    
    const stats = {
      total: questions.length,
      migrated: 0,
      missing_answer_format: 0,
      missing_format_config: 0,
      by_type: {} as Record<string, number>
    };
    
    for (const q of questions) {
      if (q.answer_format && q.format_config) {
        stats.migrated++;
        stats.by_type[q.answer_format] = (stats.by_type[q.answer_format] || 0) + 1;
      }
      if (!q.answer_format) stats.missing_answer_format++;
      if (!q.format_config) stats.missing_format_config++;
    }
    
    return stats;
  },
});
```

Run verification:

```bash
npx convex run migrations:verifyMigration
```

### 5. Update Frontend Components

Update React/React Native components to use new answer format types:

```typescript
// Example: QuestionRenderer.tsx
import { QuestionConfig } from './types';

function QuestionRenderer({ question, value, onChange }: Props) {
  const config = JSON.parse(question.format_config);
  
  switch (question.answer_format) {
    case 'time_picker':
      return <TimePicker config={config} value={value} onChange={onChange} />;
      
    case 'minutes_scroll':
      return <MinutesScrollWheel config={config} value={value} onChange={onChange} />;
      
    case 'slider_scale':
      return <SliderScale config={config} value={value} onChange={onChange} />;
      
    case 'single_select_chips':
      return <SingleSelectChips config={config} value={value} onChange={onChange} />;
      
    // ... other cases
    
    default:
      console.error('Unknown answer format:', question.answer_format);
      return <div>Unsupported question type</div>;
  }
}
```

---

## Testing Checklist

### Database Migration Testing

- [ ] All questions have `answer_format` populated
- [ ] All questions have valid `format_config` JSON
- [ ] `estimated_time_seconds` converted from minutes
- [ ] No questions with `null` or `undefined` required fields
- [ ] Backward compatibility: old `question_type` field preserved

### Response Storage Testing

- [ ] Time picker responses stored in `response_value` as "HH:MM"
- [ ] Number responses stored in `response_number`
- [ ] Multi-select responses stored in `response_array` as JSON
- [ ] Repeating group responses stored in `response_object` as JSON
- [ ] Old responses still readable

### UI Component Testing

- [ ] Time picker displays correctly on iOS/Android/Web
- [ ] Scroll wheels work smoothly
- [ ] Sliders show current value
- [ ] Chips have proper touch targets (44x44pt minimum)
- [ ] All components handle validation errors
- [ ] Conditional logic works (questions show/hide correctly)

### Performance Testing

- [ ] Question rendering < 100ms
- [ ] Answer submission < 200ms
- [ ] Large questionnaires (50+ questions) scroll smoothly
- [ ] No memory leaks with repeating groups

---

## Rollback Plan

If migration fails:

### 1. Restore Old Schema

```bash
# Revert to previous Convex schema commit
git checkout HEAD~1 convex/schema.ts
npx convex deploy
```

### 2. Restore Data

```bash
# Import backed up data
npx convex import --table assessment_questions backup_assessment_questions.json --replace
npx convex import --table sleep_diary_questions backup_sleep_diary_questions.json --replace
npx convex import --table user_assessment_responses backup_responses.json --replace
```

### 3. Revert Frontend

```bash
git checkout HEAD~1 client/components/
```

---

## Post-Migration Tasks

### 1. Remove Deprecated Fields (After 30 days)

Once migration is stable and all clients updated:

```typescript
// Remove old fields from schema
export default defineSchema({
  assessment_questions: defineTable({
    // Remove these deprecated fields:
    // question_type: v.optional(v.string()),  ❌ DELETE
    // options_json: v.optional(v.string()),    ❌ DELETE
    
    // Keep only new fields
    answer_format: v.string(),
    format_config: v.string(),
    // ...
  })
});
```

### 2. Performance Optimization

- [ ] Add database indexes for frequently queried answer_format types
- [ ] Cache frequently accessed question configurations
- [ ] Lazy load UI components by answer format type

### 3. Analytics

Track question completion times:

```typescript
// Log answer times for optimization
export const logAnswerTime = internalMutation({
  args: {
    questionId: v.string(),
    timeSeconds: v.number(),
    answerFormat: v.string(),
  },
  handler: async (ctx, args) => {
    // Store in analytics table
    await ctx.db.insert("question_analytics", {
      question_id: args.questionId,
      answer_format: args.answerFormat,
      completion_time_seconds: args.timeSeconds,
      timestamp: Date.now(),
    });
  },
});
```

---

## Common Issues & Solutions

### Issue: JSON Parse Error

**Symptom:** `JSON.parse()` fails on `format_config`

**Solution:** Validate JSON before storing:

```typescript
function validateJSON(jsonString: string): boolean {
  try {
    JSON.parse(jsonString);
    return true;
  } catch {
    return false;
  }
}

// Before inserting/updating
if (!validateJSON(formatConfig)) {
  throw new Error("Invalid format_config JSON");
}
```

### Issue: Mismatched Response Storage

**Symptom:** Number stored in `response_value` instead of `response_number`

**Solution:** Use helper function for storage:

```typescript
function storeResponse(answerFormat: string, value: any) {
  switch (answerFormat) {
    case 'time_picker':
    case 'single_select_chips':
    case 'date_picker':
      return { response_value: value };
      
    case 'minutes_scroll':
    case 'number_scroll':
    case 'slider_scale':
    case 'number_input':
      return { response_number: typeof value === 'number' ? value : Number(value) };
      
    case 'multi_select_chips':
      return { response_array: JSON.stringify(value) };
      
    case 'repeating_group':
      return { response_object: JSON.stringify(value) };
      
    default:
      throw new Error(`Unknown answer format: ${answerFormat}`);
  }
}
```

### Issue: Conditional Logic Not Working

**Symptom:** Questions don't show/hide based on previous answers

**Solution:** Implement conditional logic evaluator:

```typescript
function shouldShowQuestion(
  question: Question,
  previousResponses: Map<string, any>
): boolean {
  if (!question.conditional_logic) return true;
  
  const logic = JSON.parse(question.conditional_logic);
  const dependentAnswer = previousResponses.get(logic.question_id);
  
  switch (logic.operator) {
    case 'equals':
      return dependentAnswer === logic.value;
    case 'not_equals':
      return dependentAnswer !== logic.value;
    case 'greater_than':
      return Number(dependentAnswer) > Number(logic.value);
    case 'less_than':
      return Number(dependentAnswer) < Number(logic.value);
    case 'in_array':
      return logic.value.includes(dependentAnswer);
    default:
      return true;
  }
}
```

---

## Monitoring & Metrics

Track these metrics post-migration:

1. **Question Completion Rate**
   - % of users who complete each question
   - Drop-off points
   
2. **Average Time per Question Type**
   - Compare to estimated times
   - Identify slow question types
   
3. **Error Rate**
   - Validation errors per question
   - JSON parse errors
   
4. **User Satisfaction**
   - Feedback on new UI components
   - A/B test old vs new format

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| **Week 1** | 5 days | Database schema update, deploy, test in dev |
| **Week 2** | 5 days | Migrate Sleep Diary questions, test |
| **Week 3** | 5 days | Migrate Sleep 360° questions, test |
| **Week 4** | 5 days | UI component updates, integration testing |
| **Week 5** | 5 days | Beta testing with select users |
| **Week 6** | 2 days | Full rollout, monitoring |
| **Week 7+** | Ongoing | Monitor, optimize, fix issues |

---

## Success Criteria

Migration is successful when:

- ✅ 100% of questions migrated to new format
- ✅ No data loss
- ✅ Average question completion time reduced by 30%
- ✅ Error rate < 1%
- ✅ User satisfaction score > 4/5
- ✅ All UI components pass accessibility audit

---

**End of Migration Guide**


