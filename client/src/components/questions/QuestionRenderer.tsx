"use client";

import { useMemo } from 'react';
import { Question, QuestionComponentProps, ResponseValue, TextareaConfig, SliderScaleConfig, SingleSelectChipsConfig, MultiSelectChipsConfig, TimePickerConfig, DatePickerConfig, MinutesScrollConfig, NumberScrollConfig, NumberInputConfig } from './types';
import { parseConfig, validateResponse, shouldShowQuestion } from './utils';
import { useCircadianTheme } from '@/hooks/useCircadianTheme';

// Import individual components
import { SliderScale } from './SliderScale';
import { SingleSelectChips } from './SingleSelectChips';
import { MultiSelectChips } from './MultiSelectChips';
import { TimePicker } from './TimePicker';
import { DatePicker } from './DatePicker';
import { MinutesScroll } from './MinutesScroll';
import { NumberScroll } from './NumberScroll';
import { NumberInput } from './NumberInput';
import { Textarea } from './Textarea';

// Placeholder components for the ones we haven't built yet
function PlaceholderComponent({ question, value, onChange }: QuestionComponentProps) {
  return (
    <div className="p-6 bg-yellow-50 border border-yellow-200 rounded-xl">
      <p className="text-yellow-800 font-medium">
        Component for {question.answer_format} not yet implemented
      </p>
      <p className="text-sm text-yellow-700 mt-2">
        Question: {question.question_text}
      </p>
      <div className="mt-4">
        <input
          type="text"
          value={value?.toString() || ''}
          onChange={(e) => onChange(e.target.value)}
          placeholder="Temporary text input"
          className="w-full px-3 py-2 border border-yellow-300 rounded-lg"
        />
      </div>
    </div>
  );
}

interface QuestionRendererProps {
  question: Question;
  value: ResponseValue;
  onChange: (value: ResponseValue) => void;
  previousResponses?: Map<string, ResponseValue>;
  disabled?: boolean;
}

export function QuestionRenderer({
  question,
  value,
  onChange,
  previousResponses = new Map(),
  disabled = false
}: QuestionRendererProps) {

  // Circadian theme for time-aware colors
  const { textClasses, isWarm, cardClasses } = useCircadianTheme();

  // Check if question should be shown based on conditional logic
  const isVisible = shouldShowQuestion(question, previousResponses);

  // Validate current response
  const validationErrors = useMemo(() => {
    return validateResponse(question, value);
  }, [question, value]);

  const error = validationErrors.length > 0 ? validationErrors[0] : undefined;

  // Parse configuration
  const config = parseConfig(question.format_config);
  
  // Don't render if conditionally hidden
  if (!isVisible) {
    return null;
  }

  // Common props for all components
  const commonProps: QuestionComponentProps = {
    question,
    value,
    onChange,
    error,
    disabled,
    previousResponses,
  };

  // Render the appropriate component based on answer format
  const renderComponent = () => {
    switch (question.answer_format) {
      case 'textarea':
        return (
          <Textarea 
            config={config as TextareaConfig}
            value={value as string | null}
            onChange={onChange}
            error={error}
            disabled={disabled}
          />
        );
        
      case 'slider_scale':
        return (
          <SliderScale 
            config={config as SliderScaleConfig}
            value={value as number | null}
            onChange={onChange}
            error={error}
            disabled={disabled}
          />
        );
      
      case 'single_select_chips':
        return (
          <SingleSelectChips 
            config={config as SingleSelectChipsConfig}
            value={value as string | null}
            onChange={onChange}
            error={error}
            disabled={disabled}
          />
        );
      
      case 'time_picker':
        return (
          <TimePicker
            config={config as TimePickerConfig}
            value={value as string | null}
            onChange={onChange}
            error={error}
            disabled={disabled}
            previousResponses={previousResponses}
          />
        );
      
      case 'date_picker':
        return (
          <DatePicker 
            config={config as DatePickerConfig}
            value={value as string | null}
            onChange={onChange}
            error={error}
            disabled={disabled}
          />
        );

      case 'minutes_scroll':
        return (
          <MinutesScroll 
            config={config as MinutesScrollConfig}
            value={value as number | null}
            onChange={onChange}
            error={error}
            disabled={disabled}
          />
        );

      case 'number_scroll':
        return (
          <NumberScroll 
            config={config as NumberScrollConfig}
            value={value as number | null}
            onChange={onChange}
            error={error}
            disabled={disabled}
          />
        );

      case 'number_input':
        return (
          <NumberInput 
            config={config as NumberInputConfig}
            value={value as number | null}
            onChange={onChange}
            error={error}
            disabled={disabled}
          />
        );

      case 'multi_select_chips':
        return (
          <MultiSelectChips 
            config={config as MultiSelectChipsConfig}
            value={value as string[] | null}
            onChange={onChange}
            error={error}
            disabled={disabled}
          />
        );

      // Placeholder for unimplemented components
      case 'repeating_group':
      default:
        return <PlaceholderComponent {...commonProps} />;
    }
  };

  return (
    <div className="space-y-6">
      {/* Question Header */}
      <div className="space-y-3">
        {/* Question Text */}
        <h3 className={`text-xl md:text-2xl font-semibold leading-relaxed ${textClasses.primary}`}>
          {question.question_text}
          {question.required && <span className={isWarm ? 'text-[#F87171] ml-1' : 'text-red-500 ml-1'}>*</span>}
        </h3>

        {/* Help Text */}
        {question.help_text && (
          <p className={`text-sm leading-relaxed ${textClasses.secondary}`}>
            {question.help_text}
          </p>
        )}

        {/* Estimated Time */}
        {question.estimated_time_seconds > 0 && (
          <div className={`flex items-center gap-2 text-xs ${textClasses.muted}`}>
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12,6 12,12 16,14"/>
            </svg>
            <span>~{Math.round(question.estimated_time_seconds / 60)} min</span>
          </div>
        )}
      </div>

      {/* Question Component */}
      <div className={isWarm ? cardClasses.bg : 'bg-white'}>
        {renderComponent()}
      </div>
    </div>
  );
}