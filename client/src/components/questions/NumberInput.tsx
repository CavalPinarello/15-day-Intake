"use client";

import { useState, useEffect, useRef } from 'react';
import { NumberInputConfig } from './types';

// Smart default values for common questions
// These are realistic starting positions to make user input easier
const SMART_NUMBER_DEFAULTS: Record<string, number> = {
  // Demographics
  'D1': 35,                    // Age - median adult age
  'D5': 170,                   // Height in cm - average adult height
  'D6': 70,                    // Weight in kg - average adult weight
  // Sleep-related numbers
  'SL_AWAKENINGS': 1,          // Night awakenings - most people wake 1-2 times
  'PSQI_2': 15,                // Time to fall asleep (minutes) - typical sleep latency
  'PSQI_4': 7,                 // Hours of actual sleep - recommended amount
  // Day 2 questions
  'night_awakenings': 1,       // How many times wake up - typically 1
  // Day 3 questions
  'screen_hours': 6,           // Screen time for work - typical office worker
  // Day 5 questions
  'caffeine_servings': 2,      // Caffeine servings per day - average coffee drinker
};

interface NumberInputProps {
  config: NumberInputConfig;
  value: number | null;
  onChange: (value: number | null) => void;
  error?: string;
  disabled?: boolean;
}

export function NumberInput({
  config,
  value,
  onChange,
  error,
  disabled = false
}: NumberInputProps) {
  const [isFocused, setIsFocused] = useState(false);
  const [inputValue, setInputValue] = useState(value?.toString() || '');
  const hasSetInitialValue = useRef(false);

  // Set smart default on mount if no value exists
  useEffect(() => {
    if (hasSetInitialValue.current || value !== null) return;
    hasSetInitialValue.current = true;

    let smartDefault: number | null = null;

    // Use explicit default from config first
    if (config.defaultValue !== undefined) {
      smartDefault = config.defaultValue;
    }
    // Then check for question-key-based smart defaults
    else if (config.questionKey && SMART_NUMBER_DEFAULTS[config.questionKey] !== undefined) {
      smartDefault = SMART_NUMBER_DEFAULTS[config.questionKey];
    }

    if (smartDefault !== null) {
      // Ensure it's within bounds
      if (config.min !== undefined && smartDefault < config.min) {
        smartDefault = config.min;
      }
      if (config.max !== undefined && smartDefault > config.max) {
        smartDefault = config.max;
      }
      onChange(smartDefault);
      setInputValue(smartDefault.toString());
    }
  }, [config.questionKey, config.defaultValue, config.min, config.max, value, onChange]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = e.target.value;
    setInputValue(newValue);

    // Parse the number value
    if (newValue === '') {
      onChange(null);
      return;
    }

    const numValue = parseFloat(newValue);
    if (!isNaN(numValue)) {
      // Apply constraints
      const constrainedValue = Math.min(
        Math.max(numValue, config.min_value || -Infinity),
        config.max_value || Infinity
      );
      onChange(constrainedValue);
    }
  };

  const handleBlur = () => {
    setIsFocused(false);
    // Format the display value on blur
    if (value !== null) {
      const formatted = config.decimal_places !== undefined 
        ? value.toFixed(config.decimal_places)
        : value.toString();
      setInputValue(formatted);
    }
  };

  const handleFocus = () => {
    setIsFocused(true);
  };

  // Increment/Decrement handlers for step buttons
  const handleIncrement = () => {
    const step = config.step || 1;
    const currentValue = value || 0;
    const newValue = currentValue + step;
    
    if (!config.max_value || newValue <= config.max_value) {
      onChange(newValue);
      setInputValue(newValue.toString());
    }
  };

  const handleDecrement = () => {
    const step = config.step || 1;
    const currentValue = value || 0;
    const newValue = currentValue - step;
    
    if (!config.min_value || newValue >= config.min_value) {
      onChange(newValue);
      setInputValue(newValue.toString());
    }
  };

  const showStepButtons = config.show_step_buttons !== false;

  return (
    <div className="space-y-3">
      {/* Input Container */}
      <div className="relative flex items-center">
        {/* Main Input */}
        <input
          type="number"
          value={inputValue}
          onChange={handleInputChange}
          onFocus={handleFocus}
          onBlur={handleBlur}
          disabled={disabled}
          min={config.min_value}
          max={config.max_value}
          step={config.step || 1}
          placeholder={config.placeholder}
          className={`
            ${showStepButtons ? 'pr-16' : 'pr-12'} w-full px-4 py-3 text-lg border-2 rounded-xl transition-all duration-200
            ${error 
              ? 'border-red-300 focus:border-red-500 focus:ring-red-200' 
              : isFocused || value !== null
                ? 'border-blue-300 focus:border-blue-500 focus:ring-blue-200'
                : 'border-gray-200 focus:border-gray-400'
            }
            ${disabled 
              ? 'bg-gray-50 text-gray-400 cursor-not-allowed' 
              : 'bg-white hover:border-gray-300 focus:ring-4'
            }
            [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none
          `}
        />

        {/* Unit Label */}
        {config.unit && (
          <div className="absolute right-4 text-gray-500 pointer-events-none">
            {config.unit}
          </div>
        )}

        {/* Step Buttons */}
        {showStepButtons && !disabled && (
          <div className="absolute right-2 flex flex-col">
            <button
              type="button"
              onClick={handleIncrement}
              className="px-2 py-1 text-gray-400 hover:text-gray-600 transition-colors"
              disabled={config.max_value !== undefined && (value || 0) >= config.max_value}
            >
              <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 15l7-7 7 7" />
              </svg>
            </button>
            <button
              type="button"
              onClick={handleDecrement}
              className="px-2 py-1 text-gray-400 hover:text-gray-600 transition-colors"
              disabled={config.min_value !== undefined && (value || 0) <= config.min_value}
            >
              <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
          </div>
        )}
      </div>

      {/* Error Message */}
      {error && (
        <p className="text-sm text-red-600 flex items-center">
          <svg className="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
          </svg>
          {error}
        </p>
      )}

      {/* Help Text */}
      {config.help_text && !error && (
        <p className="text-sm text-gray-500">
          {config.help_text}
        </p>
      )}

      {/* Value Range Info */}
      {(config.min_value !== undefined || config.max_value !== undefined) && !error && (
        <p className="text-xs text-gray-400">
          Range: {config.min_value ?? '∞'} - {config.max_value ?? '∞'}
          {config.step && ` (step: ${config.step})`}
        </p>
      )}
    </div>
  );
}