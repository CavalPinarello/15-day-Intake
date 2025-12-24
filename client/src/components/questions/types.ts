/* eslint-disable @typescript-eslint/no-explicit-any */
// Question and response types for the standardized question system

export interface Question {
  question_id: string;
  question_text: string;
  help_text?: string;
  answer_format: AnswerFormat;
  format_config: string; // JSON string to be parsed
  validation_rules?: string; // JSON string to be parsed
  conditional_logic?: string; // JSON string to be parsed
  required: boolean;
  order_index?: number;
  estimated_time_seconds: number;
}

export type AnswerFormat = 
  | 'textarea'
  | 'time_picker'
  | 'minutes_scroll'
  | 'number_scroll'
  | 'slider_scale'
  | 'single_select_chips'
  | 'multi_select_chips'
  | 'date_picker'
  | 'number_input'
  | 'repeating_group';

export interface BaseFormatConfig {
  [key: string]: any;
}

// Textarea Configuration
export interface TextareaConfig extends BaseFormatConfig {
  placeholder?: string;
  maxLength?: number;
  minLength?: number;
  rows?: number;
}

// Time Picker Configuration
export interface TimePickerConfig extends BaseFormatConfig {
  format: 'HH:MM';
  allowCrossMidnight?: boolean;
  defaultValue?: string;  // HH:MM format default time
  questionKey?: string;   // For smart defaults based on question type (SL_BEDTIME, SL_ASLEEP_TIME, etc.)
}

// Minutes Scroll Configuration
export interface MinutesScrollConfig extends BaseFormatConfig {
  min: number;
  max: number;
  defaultValue: number;
  step: number;
  specialValue?: {
    value: number;
    label: string;
  };
}

// Number Scroll Configuration
export interface NumberScrollConfig extends BaseFormatConfig {
  min: number;
  max: number;
  defaultValue: number;
  step: number;
  unit?: string;
  showRangeSlider?: boolean;
}

// Slider Scale Configuration
export interface SliderScaleConfig extends BaseFormatConfig {
  min: number;
  max: number;
  step?: number;
  labels?: {
    min: string;
    max: string;
    mid?: string;
  };
  showQuickSelect?: boolean;
  defaultValue?: number;    // Pre-selected default value
  questionKey?: string;     // For smart defaults based on question type
}

// Single Select Chips Configuration
export interface SingleSelectChipsConfig extends BaseFormatConfig {
  options: Array<{
    value: string;
    label: string;
    icon?: string;
  }>;
  layout?: 'horizontal' | 'vertical' | 'grid';
}

// Multi Select Chips Configuration
export interface MultiSelectChipsConfig extends BaseFormatConfig {
  options: Array<{
    value: string;
    label: string;
    icon?: string;
  }>;
  minSelections?: number;
  maxSelections?: number;
  layout?: 'grid' | 'vertical';
}

// Date Picker Configuration
export interface DatePickerConfig extends BaseFormatConfig {
  format: 'YYYY-MM-DD';
  minDate?: string;
  maxDate?: string;
  showQuickButtons?: boolean;
}

// Number Input Configuration
export interface NumberInputConfig extends BaseFormatConfig {
  min?: number;
  max?: number;
  step?: number;
  decimalPlaces?: number;
  unit?: string;
  defaultValue?: number;    // Pre-selected default value
  questionKey?: string;     // For smart defaults based on question type
  alternativeUnits?: Array<{
    value: string;
    label: string;
    multiplier: number;
  }>;
}

// Repeating Group Configuration
export interface RepeatingGroupConfig extends BaseFormatConfig {
  minInstances?: number;
  maxInstances?: number;
  fields: Array<{
    name: string;
    label: string;
    answerFormat: AnswerFormat;
    config: BaseFormatConfig;
    required?: boolean;
  }>;
}

// Response Value Types
export type ResponseValue = string | number | string[] | object | null;

export interface UserResponse {
  question_id: string;
  response_value?: string;
  response_number?: number;
  response_array?: string; // JSON string
  response_object?: string; // JSON string
  answered_in_seconds?: number;
}

// Component Props
export interface QuestionComponentProps {
  question: Question;
  value: ResponseValue;
  onChange: (value: ResponseValue) => void;
  error?: string;
  disabled?: boolean;
  previousResponses?: Map<string, ResponseValue>;
}

export interface ValidationRule {
  type: 'required' | 'min' | 'max' | 'pattern' | 'custom';
  value?: any;
  message: string;
}

export interface ConditionalLogic {
  operator: 'equals' | 'not_equals' | 'greater_than' | 'less_than' | 'in_array' | 'not_in_array';
  questionId: string;
  value: any;
}