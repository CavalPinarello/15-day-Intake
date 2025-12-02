"use client";

import { useState, useRef, useEffect } from 'react';
import { NumberScrollConfig } from './types';

interface NumberScrollProps {
  config: NumberScrollConfig;
  value: number | null;
  onChange: (value: number | null) => void;
  error?: string;
  disabled?: boolean;
}

export function NumberScroll({ 
  config, 
  value, 
  onChange, 
  error, 
  disabled = false 
}: NumberScrollProps) {
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Generate numbers array based on config
  const numbers = Array.from(
    { length: Math.floor((config.max_value - config.min_value) / config.step) + 1 }, 
    (_, i) => config.min_value + (i * config.step)
  );

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleValueSelect = (selectedValue: number) => {
    onChange(selectedValue);
    setIsOpen(false);
  };

  const formatNumber = (num: number): string => {
    if (config.unit) {
      return `${num} ${config.unit}`;
    }
    if (config.decimal_places !== undefined) {
      return num.toFixed(config.decimal_places);
    }
    return num.toString();
  };

  const displayValue = value !== null ? formatNumber(value) : config.placeholder || 'Select value';

  return (
    <div className="space-y-3">
      {/* Dropdown Container */}
      <div className="relative" ref={dropdownRef}>
        <button
          type="button"
          onClick={() => !disabled && setIsOpen(!isOpen)}
          disabled={disabled}
          className={`
            w-full px-4 py-3 text-lg text-left border-2 rounded-xl transition-all duration-200 flex items-center justify-between
            ${error 
              ? 'border-red-300 focus:border-red-500 focus:ring-red-200' 
              : isOpen || value !== null
                ? 'border-blue-300 focus:border-blue-500 focus:ring-blue-200'
                : 'border-gray-200 focus:border-gray-400'
            }
            ${disabled 
              ? 'bg-gray-50 text-gray-400 cursor-not-allowed' 
              : 'bg-white hover:border-gray-300 focus:ring-4 cursor-pointer'
            }
          `}
        >
          <span className={value !== null ? 'text-gray-900' : 'text-gray-500'}>
            {displayValue}
          </span>
          
          {/* Dropdown Arrow */}
          <svg 
            className={`w-5 h-5 transition-transform duration-200 ${isOpen ? 'rotate-180' : ''} ${disabled ? 'text-gray-300' : 'text-gray-400'}`} 
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {/* Dropdown Menu */}
        {isOpen && !disabled && (
          <div className="absolute z-50 w-full mt-2 bg-white border border-gray-200 rounded-xl shadow-lg max-h-60 overflow-y-auto">
            {numbers.map((number) => (
              <button
                key={number}
                type="button"
                onClick={() => handleValueSelect(number)}
                className={`
                  w-full px-4 py-3 text-left hover:bg-gray-50 transition-colors duration-150 first:rounded-t-xl last:rounded-b-xl
                  ${value === number ? 'bg-blue-50 text-blue-700 font-medium' : 'text-gray-700'}
                `}
              >
                {formatNumber(number)}
              </button>
            ))}
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
    </div>
  );
}