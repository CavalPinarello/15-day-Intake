import { 
  Question, 
  ResponseValue, 
  ValidationRule, 
  ConditionalLogic,
  BaseFormatConfig
} from './types';

// Parse JSON configuration safely
export function parseConfig<T extends BaseFormatConfig>(configJson: string): T {
  try {
    return JSON.parse(configJson) as T;
  } catch (error) {
    console.error('Failed to parse config JSON:', configJson, error);
    return {} as T;
  }
}

// Parse validation rules
export function parseValidationRules(rulesJson?: string): ValidationRule[] {
  if (!rulesJson) return [];
  try {
    return JSON.parse(rulesJson);
  } catch (error) {
    console.error('Failed to parse validation rules:', rulesJson, error);
    return [];
  }
}

// Parse conditional logic
export function parseConditionalLogic(logicJson?: string): ConditionalLogic[] {
  if (!logicJson) return [];
  try {
    return JSON.parse(logicJson);
  } catch (error) {
    console.error('Failed to parse conditional logic:', logicJson, error);
    return [];
  }
}

// Validate a response value
export function validateResponse(question: Question, value: ResponseValue): string[] {
  const errors: string[] = [];
  const rules = parseValidationRules(question.validation_rules);

  // Check if required
  if (question.required && (value === null || value === undefined || value === '')) {
    errors.push('This field is required');
    return errors; // Don't validate further if empty but required
  }

  // Skip validation if empty and not required
  if (value === null || value === undefined || value === '') {
    return errors;
  }

  // Apply validation rules
  for (const rule of rules) {
    switch (rule.type) {
      case 'min':
        if (typeof value === 'number' && value < rule.value) {
          errors.push(rule.message || `Value must be at least ${rule.value}`);
        }
        break;
      case 'max':
        if (typeof value === 'number' && value > rule.value) {
          errors.push(rule.message || `Value must be at most ${rule.value}`);
        }
        break;
      case 'pattern':
        if (typeof value === 'string' && rule.value) {
          const regex = new RegExp(rule.value);
          if (!regex.test(value)) {
            errors.push(rule.message || 'Invalid format');
          }
        }
        break;
    }
  }

  return errors;
}

// Check if question should be shown based on conditional logic
export function shouldShowQuestion(
  question: Question,
  previousResponses: Map<string, ResponseValue>
): boolean {
  const conditions = parseConditionalLogic(question.conditional_logic);
  if (conditions.length === 0) return true;

  // All conditions must be met (AND logic)
  return conditions.every(condition => {
    const responseValue = previousResponses.get(condition.questionId);
    
    switch (condition.operator) {
      case 'equals':
        return responseValue === condition.value;
      case 'not_equals':
        return responseValue !== condition.value;
      case 'greater_than':
        return typeof responseValue === 'number' && responseValue > condition.value;
      case 'less_than':
        return typeof responseValue === 'number' && responseValue < condition.value;
      case 'in_array':
        if (Array.isArray(responseValue)) {
          return responseValue.includes(condition.value);
        }
        return responseValue === condition.value;
      case 'not_in_array':
        if (Array.isArray(responseValue)) {
          return !responseValue.includes(condition.value);
        }
        return responseValue !== condition.value;
      default:
        return true;
    }
  });
}

// Convert response value to appropriate storage format
export function formatResponseForStorage(answerFormat: string, value: ResponseValue): {
  response_value?: string;
  response_number?: number;
  response_array?: string;
  response_object?: string;
} {
  switch (answerFormat) {
    case 'time_picker':
    case 'date_picker':
    case 'single_select_chips':
      return { response_value: value as string };
    
    case 'slider_scale':
    case 'number_scroll':
    case 'minutes_scroll':
    case 'number_input':
      return { response_number: value as number };
    
    case 'multi_select_chips':
      return { response_array: JSON.stringify(value) };
    
    case 'repeating_group':
      return { response_object: JSON.stringify(value) };
    
    default:
      return { response_value: String(value) };
  }
}

// Convert stored response back to component value
export function parseStoredResponse(answerFormat: string, storedResponse: {
  response_value?: string;
  response_number?: number;
  response_array?: string;
  response_object?: string;
}): ResponseValue {
  switch (answerFormat) {
    case 'time_picker':
    case 'date_picker':
    case 'single_select_chips':
      return storedResponse.response_value || null;
    
    case 'slider_scale':
    case 'number_scroll':
    case 'minutes_scroll':
    case 'number_input':
      return storedResponse.response_number ?? null;
    
    case 'multi_select_chips':
      try {
        return storedResponse.response_array ? JSON.parse(storedResponse.response_array) : [];
      } catch {
        return [];
      }
    
    case 'repeating_group':
      try {
        return storedResponse.response_object ? JSON.parse(storedResponse.response_object) : {};
      } catch {
        return {};
      }
    
    default:
      return storedResponse.response_value || null;
  }
}

// Format time for display
export function formatTime(time: string): string {
  if (!time) return '';
  const [hours, minutes] = time.split(':');
  const hour12 = parseInt(hours) % 12 || 12;
  const ampm = parseInt(hours) >= 12 ? 'PM' : 'AM';
  return `${hour12}:${minutes} ${ampm}`;
}

// Calculate estimated completion time
export function calculateEstimatedTime(questions: Question[]): number {
  return questions.reduce((total, question) => total + question.estimated_time_seconds, 0);
}

// Get progress percentage
export function calculateProgress(totalQuestions: number, answeredQuestions: number): number {
  if (totalQuestions === 0) return 0;
  return Math.round((answeredQuestions / totalQuestions) * 100);
}