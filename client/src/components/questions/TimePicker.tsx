"use client";

import { useCallback, useEffect, useRef } from 'react';
import { TimePickerConfig } from './types';
import { formatTime } from './utils';

// Smart default times for sleep log and assessment questions
// These are realistic starting positions for each question type
const SMART_DEFAULTS: Record<string, string> = {
  // Daily Sleep Log
  'SL_BEDTIME': '22:00',      // 10:00 PM - typical bedtime
  'SL_ASLEEP_TIME': '22:30',  // 10:30 PM - slightly after bedtime (accounts for sleep latency)
  'SL_WAKE_TIME': '07:00',    // 7:00 AM - typical wake time
  // PSQI Assessment questions
  'PSQI_1': '22:30',          // Usual bedtime - 10:30 PM
  'PSQI_3': '07:00',          // Usual wake time - 7:00 AM
};

interface TimePickerProps {
  config: TimePickerConfig;
  value: string | null;
  onChange: (value: string) => void;
  error?: string;
  disabled?: boolean;
  previousResponses?: Map<string, any>;
}

export function TimePicker({ config, value, onChange, error, disabled, previousResponses }: TimePickerProps) {
  const { allowCrossMidnight = true, questionKey, defaultValue } = config;
  const hasSetInitialValue = useRef(false);

  // Set smart default on mount if no value exists
  useEffect(() => {
    if (hasSetInitialValue.current || value) return;
    hasSetInitialValue.current = true;

    let smartDefault: string | null = null;

    // For SL_ASLEEP_TIME, use bedtime + 30 minutes if available
    if (questionKey === 'SL_ASLEEP_TIME' && previousResponses) {
      const bedtime = previousResponses.get('SL_BEDTIME');
      if (bedtime && typeof bedtime === 'string') {
        smartDefault = addMinutesToTime(bedtime, 30);
      }
    }

    // Use explicit default, or smart default based on question key, or fallback
    if (!smartDefault) {
      if (defaultValue) {
        smartDefault = defaultValue;
      } else if (questionKey && SMART_DEFAULTS[questionKey]) {
        smartDefault = SMART_DEFAULTS[questionKey];
      }
    }

    if (smartDefault) {
      onChange(smartDefault);
    }
  }, [questionKey, defaultValue, value, onChange, previousResponses]);

  // Helper to add minutes to a time string
  function addMinutesToTime(time: string, minutes: number): string {
    const [hours, mins] = time.split(':').map(Number);
    let totalMinutes = hours * 60 + mins + minutes;

    // Handle day overflow
    if (totalMinutes >= 24 * 60) {
      totalMinutes -= 24 * 60;
    }

    const newHours = Math.floor(totalMinutes / 60);
    const newMins = totalMinutes % 60;
    return `${newHours.toString().padStart(2, '0')}:${newMins.toString().padStart(2, '0')}`;
  }

  const handleTimeChange = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = event.target.value;
    onChange(newValue);
  }, [onChange]);

  return (
    <div className="space-y-4">
      {/* Current Time Display */}
      {value && (
        <div className="text-center">
          <div className="inline-flex items-center gap-3 px-6 py-3 bg-blue-50 border border-blue-200 rounded-xl">
            <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12,6 12,12 16,14"/>
            </svg>
            <span className="text-xl font-semibold text-blue-800">
              {formatTime(value)}
            </span>
          </div>
        </div>
      )}

      {/* Time Input */}
      <div className="flex justify-center">
        <div className="relative">
          <input
            type="time"
            value={value || ''}
            onChange={handleTimeChange}
            disabled={disabled}
            className={`
              px-4 py-3 text-lg font-medium rounded-xl border-2 transition-all duration-200
              focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
              disabled:cursor-not-allowed disabled:opacity-50
              ${error 
                ? 'border-red-300 bg-red-50 text-red-900'
                : 'border-gray-300 bg-white text-gray-900 focus:border-blue-500'
              }
              
              /* Custom time picker styling */
              [&::-webkit-datetime-edit]:px-2
              [&::-webkit-datetime-edit-fields-wrapper]:py-1
              [&::-webkit-datetime-edit-text]:px-1
              [&::-webkit-datetime-edit-hour-field]:px-1
              [&::-webkit-datetime-edit-minute-field]:px-1
              [&::-webkit-datetime-edit-ampm-field]:px-1
              
              /* Hide spinner arrows */
              [&::-webkit-outer-spin-button]:appearance-none
              [&::-webkit-inner-spin-button]:appearance-none
              [&::-webkit-calendar-picker-indicator]:cursor-pointer
              [&::-webkit-calendar-picker-indicator]:hover:bg-gray-100
              [&::-webkit-calendar-picker-indicator]:rounded
              [&::-webkit-calendar-picker-indicator]:p-1
            `}
          />
        </div>
      </div>

      {/* Cross-midnight help text */}
      {allowCrossMidnight && (
        <p className="text-sm text-gray-500 text-center">
          💡 If this is a bedtime that occurs after midnight, just select the normal time
        </p>
      )}

      {/* Error Message */}
      {error && (
        <div className="text-red-500 text-sm flex items-center justify-center gap-2">
          <svg className="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
          </svg>
          {error}
        </div>
      )}
    </div>
  );
}