"use client";

import { useState } from 'react';

export interface TextareaConfig {
  placeholder?: string;
  maxLength?: number;
  minLength?: number;
  rows?: number;
}

export interface TextareaProps {
  config: TextareaConfig;
  value: string | null;
  onChange: (value: string | null) => void;
  error?: string;
  disabled?: boolean;
}

export function Textarea({ config, value, onChange, error, disabled = false }: TextareaProps) {
  const [isFocused, setIsFocused] = useState(false);
  
  const {
    placeholder = "Enter your response...",
    maxLength = 1000,
    minLength = 0,
    rows = 4
  } = config;

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newValue = e.target.value;
    onChange(newValue || null);
  };

  const characterCount = value?.length || 0;
  const isOverLimit = maxLength && characterCount > maxLength;
  const isUnderMinimum = minLength && characterCount < minLength;

  return (
    <div className="space-y-3">
      <div className="relative">
        <textarea
          value={value || ''}
          onChange={handleChange}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          disabled={disabled}
          placeholder={placeholder}
          rows={rows}
          maxLength={maxLength}
          className={`
            w-full px-4 py-3 rounded-xl border-2 transition-all duration-200 resize-none
            ${error || isOverLimit
              ? 'border-red-300 bg-red-50 focus:border-red-500 focus:ring-red-200'
              : isFocused
                ? 'border-blue-500 bg-white focus:ring-blue-200'
                : 'border-gray-200 bg-white hover:border-gray-300'
            }
            ${disabled ? 'opacity-50 cursor-not-allowed' : ''}
            focus:outline-none focus:ring-4 focus:ring-opacity-20
            placeholder-gray-400 text-gray-900
          `}
        />
      </div>

      {/* Character count and validation feedback */}
      <div className="flex items-center justify-between text-sm">
        <div className="space-y-1">
          {error && (
            <p className="text-red-600 flex items-center gap-1">
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01M5.5 20.5L19.5 20.5c1.38 0 2.5-1.12 2.5-2.5L22 4c0-1.38-1.12-2.5-2.5-2.5L4.5 1.5c-1.38 0-2.5 1.12-2.5 2.5v13c0 1.38 1.12 2.5 2.5 2.5z" />
              </svg>
              {error}
            </p>
          )}
          
          {isUnderMinimum && !error && (
            <p className="text-amber-600 text-sm">
              At least {minLength} characters required
            </p>
          )}
        </div>

        {maxLength && (
          <div className={`text-right ${
            isOverLimit ? 'text-red-600' : 
            characterCount > maxLength * 0.8 ? 'text-amber-600' : 
            'text-gray-500'
          }`}>
            <span className="font-medium">{characterCount}</span>
            <span className="text-gray-400">/{maxLength}</span>
          </div>
        )}
      </div>

      {/* Usage hints */}
      {isFocused && !error && (
        <div className="text-xs text-gray-500 space-y-1">
          <p>💡 Take your time to provide a thoughtful response</p>
          {minLength > 0 && (
            <p>• Minimum {minLength} characters needed</p>
          )}
        </div>
      )}
    </div>
  );
}