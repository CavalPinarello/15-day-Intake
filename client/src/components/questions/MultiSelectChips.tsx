"use client";

import { useState } from 'react';
import { MultiSelectChipsConfig } from './types';

interface MultiSelectChipsProps {
  config: MultiSelectChipsConfig;
  value: string[] | null;
  onChange: (value: string[] | null) => void;
  error?: string;
  disabled?: boolean;
}

export function MultiSelectChips({
  config,
  value = [],
  onChange,
  error,
  disabled = false
}: MultiSelectChipsProps) {
  const [focusedIndex, setFocusedIndex] = useState<number | null>(null);

  // Guard against missing options
  const options = config.options || [];
  if (options.length === 0) {
    return (
      <div className="p-4 text-amber-600 bg-amber-50 rounded-lg">
        No options available for this question.
      </div>
    );
  }

  const handleOptionToggle = (optionValue: string) => {
    if (disabled) return;

    const currentValues = value || [];
    const isSelected = currentValues.includes(optionValue);

    if (isSelected) {
      // Remove the option
      const newValues = currentValues.filter(v => v !== optionValue);
      onChange(newValues.length > 0 ? newValues : null);
    } else {
      // Add the option (check max selections)
      if (!config.max_selections || currentValues.length < config.max_selections) {
        onChange([...currentValues, optionValue]);
      }
    }
  };

  const isOptionSelected = (optionValue: string): boolean => {
    return value ? value.includes(optionValue) : false;
  };

  const canSelectMore = (): boolean => {
    if (!config.max_selections) return true;
    return (value?.length || 0) < config.max_selections;
  };

  const selectedCount = value?.length || 0;

  return (
    <div className="space-y-4">
      {/* Selection Counter */}
      {(config.min_selections || config.max_selections) && (
        <div className="text-sm text-gray-600">
          Selected: {selectedCount}
          {config.min_selections && ` (min: ${config.min_selections})`}
          {config.max_selections && ` (max: ${config.max_selections})`}
        </div>
      )}

      {/* Options Grid */}
      <div className={`
        grid gap-3
        ${config.columns === 1 ? 'grid-cols-1' : 
          config.columns === 2 ? 'grid-cols-1 sm:grid-cols-2' :
          config.columns === 3 ? 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3' :
          'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3'
        }
      `}>
        {options.map((option, index) => {
          const isSelected = isOptionSelected(option.value);
          const canSelect = canSelectMore() || isSelected;
          const isDisabled = disabled || !canSelect;

          return (
            <button
              key={option.value}
              type="button"
              onClick={() => handleOptionToggle(option.value)}
              onFocus={() => setFocusedIndex(index)}
              onBlur={() => setFocusedIndex(null)}
              disabled={isDisabled}
              className={`
                relative px-4 py-3 text-sm font-medium rounded-xl border-2 transition-all duration-200
                ${isSelected
                  ? 'border-blue-500 bg-blue-50 text-blue-700'
                  : error
                    ? 'border-red-300 bg-white text-gray-700 hover:border-red-400'
                    : 'border-gray-200 bg-white text-gray-700 hover:border-gray-300'
                }
                ${focusedIndex === index ? 'ring-4 ring-blue-200' : ''}
                ${isDisabled 
                  ? 'cursor-not-allowed opacity-50' 
                  : 'cursor-pointer hover:shadow-sm'
                }
              `}
            >
              {/* Selection Indicator */}
              <div className={`
                absolute top-2 right-2 w-4 h-4 rounded-full border-2 transition-all duration-200
                ${isSelected 
                  ? 'border-blue-500 bg-blue-500' 
                  : 'border-gray-300 bg-white'
                }
              `}>
                {isSelected && (
                  <svg 
                    className="w-3 h-3 text-white absolute top-0.5 left-0.5" 
                    fill="currentColor" 
                    viewBox="0 0 20 20"
                  >
                    <path 
                      fillRule="evenodd" 
                      d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" 
                      clipRule="evenodd" 
                    />
                  </svg>
                )}
              </div>

              {/* Option Content */}
              <div className="pr-6 text-left">
                <div className="font-medium">
                  {option.label}
                </div>
                {option.description && (
                  <div className="text-xs text-gray-500 mt-1">
                    {option.description}
                  </div>
                )}
              </div>
            </button>
          );
        })}
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

      {/* Selection Limit Warning */}
      {config.max_selections && selectedCount >= config.max_selections && (
        <p className="text-sm text-amber-600">
          Maximum of {config.max_selections} selections reached.
        </p>
      )}
    </div>
  );
}