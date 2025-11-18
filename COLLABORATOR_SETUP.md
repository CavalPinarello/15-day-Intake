# Setup Guide for Collaborators

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd "15-Day Test"
   ```

2. **Install dependencies**
   ```bash
   # Client dependencies
   cd client
   npm install
   
   # Convex setup (if not already configured)
   cd ../convex
   npm install
   ```

3. **Set up environment variables**
   - Ensure `NEXT_PUBLIC_CONVEX_URL` is set in your environment
   - Check `.env.local` or `.env` files

4. **Run the development server**
   ```bash
   cd client
   npm run dev
   ```

5. **View the demo**
   - Navigate to `http://localhost:3000/question-demo`
   - This showcases all 8 standardized answer formats

## Project Structure

### Key Directories

- **`client/components/questions/`** - All question UI components
- **`convex/`** - Backend database schema and functions
- **`data/`** - Sample question data in standardized format
- **`client/app/question-demo/`** - Demo page for testing

### Important Files

- **`UNIFIED_QUESTIONS_INTEGRATION.md`** - Complete integration guide
- **`QUESTION_ANSWER_FORMAT_SPECIFICATION.md`** - Format specification
- **`QUICK_REFERENCE_ANSWER_FORMATS.md`** - Quick reference guide
- **`GIT_COMMIT_READY.md`** - Git commit information

## Understanding the System

### Answer Formats

The system uses 8 standardized answer formats:

1. **TIME_PICKER** - iOS-style scroll wheel (hour, minute, AM/PM)
2. **MINUTES_SCROLL** - Scroll wheel for minutes
3. **NUMBER_SCROLL** - Scroll wheel for numbers
4. **SLIDER_SCALE** - Slider for ranges
5. **SINGLE_SELECT_CHIPS** - Single-choice chips (Yes/No, etc.)
6. **MULTI_SELECT_CHIPS** - Multiple-choice chips
7. **DATE_PICKER** - Date selection
8. **NUMBER_INPUT** - Free-form number input

### Using QuestionRenderer

```tsx
import { QuestionRenderer, Question } from "@/components/questions";

<QuestionRenderer
  question={question}  // Question from database
  value={currentValue}
  onChange={(value) => handleChange(value)}
  previousResponses={responsesMap}  // For conditional logic
/>
```

### Database Schema

Questions are stored in Convex with:
- `answer_format: string` - The format type
- `format_config: string` - JSON configuration
- `validation_rules: string` - JSON validation rules
- `conditional_logic: string` - JSON conditional logic

### Conditional Logic

Questions can be shown/hidden based on previous responses:

```json
{
  "conditional_logic": {
    "show_if": {
      "question_id": "SD_MEDICATION_TAKEN",
      "operator": "equals",
      "value": "yes"
    }
  }
}
```

## Development Workflow

1. **Adding a new question format**:
   - Create component in `client/components/questions/`
   - Add case to `QuestionRenderer.tsx`
   - Update `types.ts` with new format type
   - Add to demo page for testing

2. **Modifying existing components**:
   - All components are in `client/components/questions/`
   - Use TypeScript for type safety
   - Follow existing patterns for consistency

3. **Testing**:
   - Use `/question-demo` page for visual testing
   - Check browser console for errors
   - Verify conditional logic works

## Common Tasks

### Adding a New Question

1. Create question object with required fields:
   ```typescript
   const question: Question = {
     question_id: "UNIQUE_ID",
     question_text: "Your question text",
     answer_format: "single_select_chips",
     format_config: JSON.stringify({
       options: [
         { value: "yes", label: "Yes" },
         { value: "no", label: "No" }
       ]
     }),
     estimated_time_seconds: 15
   };
   ```

2. Add to database via Convex mutation or seed script

### Modifying Conditional Logic

Update the `conditional_logic` field in the question:

```json
{
  "show_if": {
    "question_id": "PARENT_QUESTION_ID",
    "operator": "equals",  // or "not_equals", "greater_than", etc.
    "value": "expected_value"
  }
}
```

## Troubleshooting

### Questions not showing
- Check `conditional_logic` - parent question may need to be answered first
- Verify `shouldShowQuestion` utility function
- Check browser console for errors

### Format not rendering
- Verify `answer_format` matches one of the 8 supported types
- Check `format_config` is valid JSON
- Ensure component is imported in `QuestionRenderer.tsx`

### Styling issues
- All components use Tailwind CSS
- Check responsive classes for mobile/desktop
- Verify theme colors are applied correctly

## Resources

- **Component Documentation**: `client/components/questions/README.md`
- **Format Specification**: `QUESTION_ANSWER_FORMAT_SPECIFICATION.md`
- **Migration Guide**: `QUESTION_FORMAT_MIGRATION_GUIDE.md`
- **Quick Reference**: `QUICK_REFERENCE_ANSWER_FORMATS.md`
- **Integration Guide**: `UNIFIED_QUESTIONS_INTEGRATION.md`

## Getting Help

1. Check the documentation files listed above
2. Review the demo page at `/question-demo`
3. Examine existing question components for patterns
4. Check Convex queries/mutations for data flow

## Next Steps

- Review `UNIFIED_QUESTIONS_INTEGRATION.md` for complete system overview
- Explore the demo page to see all formats in action
- Check `GIT_COMMIT_READY.md` for commit information

