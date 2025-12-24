"use client";

import { useCallback } from 'react';
import { SingleSelectChipsConfig } from './types';
import { useCircadianTheme } from '@/hooks/useCircadianTheme';

interface SingleSelectChipsProps {
  config: SingleSelectChipsConfig;
  value: string | null;
  onChange: (value: string) => void;
  error?: string;
  disabled?: boolean;
}

export function SingleSelectChips({ config, value, onChange, error, disabled }: SingleSelectChipsProps) {
  const { options = [], layout = 'vertical' } = config;
  const { isWarm } = useCircadianTheme();

  // Hook must be called before any early returns
  const handleSelect = useCallback((optionValue: string) => {
    onChange(optionValue);
  }, [onChange]);

  // Guard against missing options
  if (!options || options.length === 0) {
    return (
      <div className="p-4 text-amber-600 bg-amber-50 rounded-lg">
        No options available for this question.
      </div>
    );
  }

  const layoutClasses = {
    horizontal: 'flex flex-wrap gap-3',
    vertical: 'space-y-3',
    grid: 'grid grid-cols-2 gap-3 sm:grid-cols-3',
  };

  return (
    <div className="space-y-4">
      <div className={layoutClasses[layout]}>
        {options.map((option) => (
          <button
            key={option.value}
            onClick={() => handleSelect(option.value)}
            disabled={disabled}
            className={`
              relative p-4 rounded-xl text-left transition-all duration-200
              border-2 active:scale-98 min-h-[60px]
              ${value === option.value
                ? isWarm
                  ? 'bg-[#4A3020] border-[#F28C40] text-[#FEF3C7]'
                  : 'bg-blue-50 border-blue-500 text-blue-700'
                : isWarm
                  ? 'bg-[#3D2418] border-[#5C3D2E] text-[#FCD34D] hover:border-[#7A5240] hover:bg-[#4A3020]'
                  : 'bg-white border-gray-200 text-gray-700 hover:border-gray-300 hover:bg-gray-50'
              }
              disabled:cursor-not-allowed disabled:opacity-50
              focus:outline-none focus:ring-2 ${isWarm ? 'focus:ring-[#F28C40]' : 'focus:ring-blue-500'} focus:ring-offset-2
            `}
          >
            {/* Selection Indicator */}
            {value === option.value && (
              <div className="absolute top-3 right-3">
                <div className={`w-5 h-5 ${isWarm ? 'bg-[#F28C40]' : 'bg-blue-500'} rounded-full flex items-center justify-center`}>
                  <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                </div>
              </div>
            )}

            {/* Icon */}
            {option.icon && (
              <div className="mb-2">
                <span className="text-2xl">{option.icon}</span>
              </div>
            )}

            {/* Label */}
            <div className={`font-medium ${option.icon ? 'pr-8' : 'pr-6'}`}>
              {option.label}
            </div>
          </button>
        ))}
      </div>

      {/* Error Message */}
      {error && (
        <div className={`${isWarm ? 'text-[#F87171]' : 'text-red-500'} text-sm flex items-center gap-2`}>
          <svg className="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
          </svg>
          {error}
        </div>
      )}
    </div>
  );
}