"use client";
/* eslint-disable react-hooks/exhaustive-deps, @typescript-eslint/no-unused-vars */

import { useState, useEffect, useMemo } from 'react';
import {
  getTimePeriod,
  getCircadianColors,
  isWarmColorPeriod,
  type TimePeriod,
  type CircadianColors,
} from '@/lib/circadianTheme';

/**
 * React hook for circadian theme colors
 * Automatically updates when the time period changes
 */
export function useCircadianTheme() {
  const [period, setPeriod] = useState<TimePeriod>(() => getTimePeriod());

  // Update period every minute to catch time changes
  useEffect(() => {
    const checkPeriod = () => {
      const newPeriod = getTimePeriod();
      if (newPeriod !== period) {
        setPeriod(newPeriod);
      }
    };

    // Check immediately and then every minute
    const interval = setInterval(checkPeriod, 60000);
    return () => clearInterval(interval);
  }, [period]);

  const colors = useMemo(() => getCircadianColors(period), [period]);
  const isWarm = useMemo(() => isWarmColorPeriod(), [period]);

  // CSS class utilities
  const textClasses = useMemo(() => ({
    primary: isWarm ? 'text-[#FEF3C7]' : 'text-gray-900',
    secondary: isWarm ? 'text-[#FCD34D]' : 'text-gray-600',
    muted: isWarm ? 'text-[#F59E0B]' : 'text-gray-500',
  }), [isWarm]);

  const bgClasses = useMemo(() => {
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
  }, [period]);

  const cardClasses = useMemo(() => ({
    bg: isWarm ? 'bg-[#3D2418]' : 'bg-white',
    border: isWarm ? 'border-[#5C3D2E]' : 'border-gray-200',
    combined: isWarm ? 'bg-[#3D2418] border-[#5C3D2E]' : 'bg-white border-gray-200',
  }), [isWarm]);

  const buttonClasses = useMemo(() => ({
    primary: isWarm
      ? 'bg-gradient-to-r from-[#F28C40] to-[#D97706] text-[#1F1410] hover:opacity-90'
      : 'bg-blue-600 text-white hover:bg-blue-700',
    secondary: isWarm
      ? 'bg-[#5C3D2E] text-[#FCD34D] hover:bg-[#6B4A37]'
      : 'bg-gray-100 text-gray-700 hover:bg-gray-200',
    ghost: isWarm
      ? 'text-[#FCD34D] hover:bg-[#3D2418]'
      : 'text-gray-600 hover:bg-gray-100',
  }), [isWarm]);

  return {
    period,
    colors,
    isWarm,
    textClasses,
    bgClasses,
    cardClasses,
    buttonClasses,
  };
}
