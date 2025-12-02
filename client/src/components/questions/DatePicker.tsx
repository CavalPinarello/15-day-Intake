"use client";

import { useState } from 'react';
import { DatePickerConfig } from './types';

interface DatePickerProps {
  config: DatePickerConfig;
  value: string | null;
  onChange: (value: string | null) => void;
  error?: string;
  disabled?: boolean;
}

export function DatePicker({ 
  config, 
  value, 
  onChange, 
  error, 
  disabled = false 
}: DatePickerProps) {
  const [isFocused, setIsFocused] = useState(false);

  const handleDateChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = e.target.value || null;
    onChange(newValue);
  };

  // Format date for display
  const formatDate = (dateString: string | null): string => {
    if (!dateString) return '';
    try {
      const date = new Date(dateString);
      return date.toISOString().split('T')[0]; // YYYY-MM-DD format
    } catch {
      return dateString;
    }
  };

  return (
    <div className="space-y-3">
      {/* Date Input */}
      <div className="relative">
        <input
          type="date"
          value={formatDate(value)}
          onChange={handleDateChange}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          disabled={disabled}
          min={config.min_date}
          max={config.max_date}
          className={`
            w-full px-4 py-3 text-lg border-2 rounded-xl transition-all duration-200
            ${error 
              ? 'border-red-300 focus:border-red-500 focus:ring-red-200' 
              : isFocused || value
                ? 'border-blue-300 focus:border-blue-500 focus:ring-blue-200'
                : 'border-gray-200 focus:border-gray-400'
            }
            ${disabled 
              ? 'bg-gray-50 text-gray-400 cursor-not-allowed' 
              : 'bg-white hover:border-gray-300 focus:ring-4'
            }
          `}
        />

        {/* Calendar Icon */}
        <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 pointer-events-none">
          <svg 
            width="20" 
            height="20" 
            viewBox="0 0 24 24" 
            fill="none" 
            stroke="currentColor" 
            strokeWidth="2"
          >
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
            <line x1="16" y1="2" x2="16" y2="6"></line>
            <line x1="8" y1="2" x2="8" y2="6"></line>
            <line x1="3" y1="10" x2="21" y2="10"></line>
          </svg>
        </div>
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
      {config.placeholder && !error && (
        <p className="text-sm text-gray-500">
          {config.placeholder}
        </p>
      )}
    </div>
  );
}