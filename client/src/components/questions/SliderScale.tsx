"use client";

import { useState, useCallback, useEffect, useRef } from 'react';
import { SliderScaleConfig } from './types';
import { useCircadianTheme } from '@/hooks/useCircadianTheme';

// Smart default values for scale questions
// These represent neutral/typical positions to start from
const SMART_SCALE_DEFAULTS: Record<string, number> = {
  // Sleep quality (1-10 scale) - start at neutral/slightly good
  'SL_QUALITY': 6,
  '1': 6,                      // Overall sleep quality - neutral position
  // Stress level (1-10) - start at moderate
  'stress_level': 5,
  // Pain level (0-10) - start at low/no pain (optimistic default)
  'pain_level': 2,
};

interface SliderScaleProps {
  config: SliderScaleConfig;
  value: number | null;
  onChange: (value: number) => void;
  error?: string;
  disabled?: boolean;
}

export function SliderScale({ config, value, onChange, error, disabled }: SliderScaleProps) {
  const [isActive, setIsActive] = useState(false);
  const hasSetInitialValue = useRef(false);
  const { isWarm, textClasses } = useCircadianTheme();

  const { min, max, step = 1, labels, showQuickSelect = true, questionKey, defaultValue } = config;

  // Set smart default on mount if no value exists
  useEffect(() => {
    if (hasSetInitialValue.current || value !== null) return;
    hasSetInitialValue.current = true;

    let smartDefault: number | null = null;

    // Use explicit default from config first
    if (defaultValue !== undefined) {
      smartDefault = defaultValue;
    }
    // Then check for question-key-based smart defaults
    else if (questionKey && SMART_SCALE_DEFAULTS[questionKey] !== undefined) {
      smartDefault = SMART_SCALE_DEFAULTS[questionKey];
    }
    // If no specific default, use middle of the scale
    else {
      smartDefault = Math.round((min + max) / 2);
    }

    if (smartDefault !== null) {
      // Ensure it's within bounds
      if (smartDefault < min) smartDefault = min;
      if (smartDefault > max) smartDefault = max;
      onChange(smartDefault);
    }
  }, [questionKey, defaultValue, min, max, value, onChange]);
  
  const handleSliderChange = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = parseInt(event.target.value);
    onChange(newValue);
  }, [onChange]);

  const handleQuickSelect = useCallback((quickValue: number) => {
    onChange(quickValue);
  }, [onChange]);

  const range = max - min;
  const progress = value !== null ? ((value - min) / range) * 100 : 0;

  return (
    <div className="space-y-4">
      {/* Value Display */}
      {value !== null && (
        <div className="text-center">
          <div className={`inline-flex items-center justify-center w-16 h-16 ${isWarm ? 'bg-[#F28C40]' : 'bg-blue-500'} text-white text-2xl font-bold rounded-full shadow-lg`}>
            {value}
          </div>
        </div>
      )}

      {/* Slider */}
      <div className="relative px-2">
        <div className="relative">
          {/* Progress Track */}
          <div className={`absolute top-1/2 left-0 right-0 h-2 ${isWarm ? 'bg-[#5C3D2E]' : 'bg-gray-200'} rounded-full transform -translate-y-1/2`}>
            <div
              className={`h-full ${isWarm ? 'bg-[#F28C40]' : 'bg-blue-500'} rounded-full transition-all duration-200`}
              style={{ width: `${progress}%` }}
            />
          </div>
          
          {/* Slider Input */}
          <input
            type="range"
            min={min}
            max={max}
            step={step}
            value={value ?? min}
            onChange={handleSliderChange}
            onMouseDown={() => setIsActive(true)}
            onMouseUp={() => setIsActive(false)}
            onTouchStart={() => setIsActive(true)}
            onTouchEnd={() => setIsActive(false)}
            disabled={disabled}
            className={`
              relative w-full h-2 bg-transparent appearance-none cursor-pointer
              focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
              disabled:cursor-not-allowed disabled:opacity-50
              
              /* Webkit styles */
              [&::-webkit-slider-thumb]:appearance-none
              [&::-webkit-slider-thumb]:w-6
              [&::-webkit-slider-thumb]:h-6
              [&::-webkit-slider-thumb]:bg-white
              [&::-webkit-slider-thumb]:rounded-full
              [&::-webkit-slider-thumb]:border-2
              [&::-webkit-slider-thumb]:border-blue-500
              [&::-webkit-slider-thumb]:shadow-lg
              [&::-webkit-slider-thumb]:cursor-pointer
              [&::-webkit-slider-thumb]:transition-transform
              ${isActive ? '[&::-webkit-slider-thumb]:scale-110' : ''}
              
              /* Firefox styles */
              [&::-moz-range-thumb]:w-6
              [&::-moz-range-thumb]:h-6
              [&::-moz-range-thumb]:bg-white
              [&::-moz-range-thumb]:rounded-full
              [&::-moz-range-thumb]:border-2
              [&::-moz-range-thumb]:border-blue-500
              [&::-moz-range-thumb]:cursor-pointer
              [&::-moz-range-thumb]:appearance-none
              [&::-moz-range-track]:bg-transparent
            `}
          />
        </div>

        {/* Labels */}
        {labels && (
          <div className={`flex justify-between mt-3 text-sm ${textClasses.secondary}`}>
            <span className="text-left">{labels.min}</span>
            {labels.mid && (
              <span className="text-center">{labels.mid}</span>
            )}
            <span className="text-right">{labels.max}</span>
          </div>
        )}
      </div>

      {/* Quick Select Numbers */}
      {showQuickSelect && range <= 10 && (
        <div className="flex flex-wrap justify-center gap-2 mt-6">
          {Array.from({ length: max - min + 1 }, (_, i) => min + i).map(num => (
            <button
              key={num}
              onClick={() => handleQuickSelect(num)}
              disabled={disabled}
              className={`
                w-10 h-10 rounded-full text-sm font-medium transition-all duration-200
                border-2 active:scale-95
                ${value === num
                  ? isWarm
                    ? 'bg-[#F28C40] text-white border-[#F28C40]'
                    : 'bg-blue-500 text-white border-blue-500'
                  : isWarm
                    ? 'bg-[#3D2418] text-[#FCD34D] border-[#5C3D2E] hover:border-[#F28C40]'
                    : 'bg-white text-gray-700 border-gray-300 hover:border-blue-300'
                }
                disabled:cursor-not-allowed disabled:opacity-50
                ${isWarm ? 'focus:ring-[#F28C40]' : 'focus:ring-blue-500'} focus:outline-none focus:ring-2 focus:ring-offset-1
              `}
            >
              {num}
            </button>
          ))}
        </div>
      )}

      {/* Error Message */}
      {error && (
        <div className={`${isWarm ? 'text-[#F87171]' : 'text-red-500'} text-sm mt-2 flex items-center gap-2`}>
          <svg className="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
          </svg>
          {error}
        </div>
      )}
    </div>
  );
}