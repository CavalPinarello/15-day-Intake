/**
 * Circadian Theme System for Web Client
 *
 * This module provides time-based color theming that matches the iOS circadian system.
 * CRITICAL: NO blue/teal/purple at night - only warm amber/orange for sleep health
 */

export type TimePeriod = 'morning' | 'afternoon' | 'evening' | 'night';

/**
 * Get the current time period based on hour of day
 */
export function getTimePeriod(): TimePeriod {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 21) return 'evening';
  return 'night';
}

/**
 * Check if current time is evening or night (when warm colors are required)
 */
export function isWarmColorPeriod(): boolean {
  const period = getTimePeriod();
  return period === 'evening' || period === 'night';
}

/**
 * Circadian color palette matching iOS QuestionModels.swift
 */
export interface CircadianColors {
  // Primary colors
  primary: string;
  secondary: string;
  tertiary: string;

  // Background colors
  background: string;
  backgroundGradientFrom: string;
  backgroundGradientTo: string;
  cardBackground: string;

  // Text colors - CRITICAL for visibility
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  textOnPrimary: string;

  // Status colors
  success: string;
  warning: string;
  error: string;

  // Border colors
  border: string;
  borderLight: string;
}

/**
 * Get circadian colors for the current time period
 */
export function getCircadianColors(period?: TimePeriod): CircadianColors {
  const currentPeriod = period ?? getTimePeriod();

  switch (currentPeriod) {
    case 'morning':
      return {
        primary: '#0EA5E9',      // Sky blue
        secondary: '#38BDF8',    // Light sky blue
        tertiary: '#06B6D4',     // Cyan
        background: '#F0F9FF',   // Very light blue
        backgroundGradientFrom: '#F0F9FF',
        backgroundGradientTo: '#E0F2FE',
        cardBackground: '#FFFFFF',
        textPrimary: '#111827',   // gray-900
        textSecondary: '#4B5563', // gray-600
        textMuted: '#6B7280',     // gray-500
        textOnPrimary: '#FFFFFF',
        success: '#10B981',
        warning: '#F59E0B',
        error: '#EF4444',
        border: '#E5E7EB',        // gray-200
        borderLight: '#F3F4F6',   // gray-100
      };

    case 'afternoon':
      return {
        primary: '#F59E0B',      // Amber
        secondary: '#FBBF24',    // Golden amber
        tertiary: '#D97706',     // Deep amber
        background: '#FFFBEB',   // Warm cream
        backgroundGradientFrom: '#FFFBEB',
        backgroundGradientTo: '#FEF3C7',
        cardBackground: '#FFFFFF',
        textPrimary: '#111827',   // gray-900
        textSecondary: '#4B5563', // gray-600
        textMuted: '#6B7280',     // gray-500
        textOnPrimary: '#FFFFFF',
        success: '#10B981',
        warning: '#F59E0B',
        error: '#EF4444',
        border: '#E5E7EB',        // gray-200
        borderLight: '#F3F4F6',   // gray-100
      };

    case 'evening':
      return {
        primary: '#F28C40',      // Bright amber/orange
        secondary: '#D97706',    // Deep amber
        tertiary: '#B45309',     // Burnt orange
        background: '#2D1A14',   // Deep warm brown
        backgroundGradientFrom: '#3D2418',
        backgroundGradientTo: '#2D1A14',
        cardBackground: '#3D2418', // Slightly lighter brown
        // High contrast text for dark backgrounds
        textPrimary: '#FEF3C7',   // Warm white/cream - HIGH CONTRAST
        textSecondary: '#FCD34D', // Golden yellow - VISIBLE
        textMuted: '#F59E0B',     // Amber - VISIBLE
        textOnPrimary: '#1F1410', // Dark brown on amber buttons
        success: '#34D399',       // Brighter green for visibility
        warning: '#FCD34D',       // Golden yellow
        error: '#F87171',         // Soft red
        border: '#5C3D2E',        // Warm brown border
        borderLight: '#4A3020',   // Dark brown
      };

    case 'night':
      return {
        primary: '#F28C40',      // Warm amber
        secondary: '#D97706',    // Deep amber
        tertiary: '#B45309',     // Burnt orange
        background: '#1F1410',   // Very deep brown (darker than evening)
        backgroundGradientFrom: '#2D1A14',
        backgroundGradientTo: '#1F1410',
        cardBackground: '#2D1A14', // Deep warm brown
        // High contrast text for dark backgrounds
        textPrimary: '#FEF3C7',   // Warm white/cream - HIGH CONTRAST
        textSecondary: '#FCD34D', // Golden yellow - VISIBLE
        textMuted: '#F59E0B',     // Amber - VISIBLE
        textOnPrimary: '#1F1410', // Dark brown on amber buttons
        success: '#34D399',       // Brighter green for visibility
        warning: '#FCD34D',       // Golden yellow
        error: '#F87171',         // Soft red
        border: '#4A3020',        // Dark warm brown border
        borderLight: '#3D2418',   // Slightly lighter brown
      };
  }
}

/**
 * Get Tailwind CSS classes for circadian text colors
 * Returns object with class names that can be applied to elements
 */
export function getCircadianTextClasses(): {
  primary: string;
  secondary: string;
  muted: string;
} {
  const isWarm = isWarmColorPeriod();

  if (isWarm) {
    // Evening/Night: Use warm cream/amber colors for visibility on dark brown backgrounds
    return {
      primary: 'text-[#FEF3C7]',    // Warm cream
      secondary: 'text-[#FCD34D]', // Golden yellow
      muted: 'text-[#F59E0B]',     // Amber
    };
  }

  // Morning/Afternoon: Standard gray colors
  return {
    primary: 'text-gray-900',
    secondary: 'text-gray-600',
    muted: 'text-gray-500',
  };
}

/**
 * Get circadian background gradient CSS classes
 */
export function getCircadianBackgroundClasses(): string {
  const period = getTimePeriod();

  switch (period) {
    case 'morning':
      return 'bg-gradient-to-br from-[#F0F9FF] to-[#E0F2FE]';
    case 'afternoon':
      return 'bg-gradient-to-br from-[#FFFBEB] to-[#FEF3C7]';
    case 'evening':
      return 'bg-gradient-to-br from-[#3D2418] to-[#2D1A14]';
    case 'night':
      return 'bg-gradient-to-br from-[#2D1A14] to-[#1F1410]';
  }
}

/**
 * Get circadian card background CSS classes
 */
export function getCircadianCardClasses(): string {
  const isWarm = isWarmColorPeriod();

  if (isWarm) {
    return 'bg-[#3D2418] border-[#5C3D2E]';
  }

  return 'bg-white border-gray-200';
}

/**
 * Get circadian button classes for primary actions
 */
export function getCircadianButtonClasses(): string {
  const isWarm = isWarmColorPeriod();

  if (isWarm) {
    return 'bg-gradient-to-r from-[#F28C40] to-[#D97706] text-[#1F1410] hover:opacity-90';
  }

  return 'bg-blue-600 text-white hover:bg-blue-700';
}
