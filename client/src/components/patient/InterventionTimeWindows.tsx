"use client";

import { useState } from "react";
import {
  Sun,
  SunMedium,
  Sunset,
  Moon,
  Clock,
  Check,
} from "lucide-react";

export type TimeWindowId = "morning" | "afternoon" | "evening" | "night";

interface TimeWindow {
  id: TimeWindowId;
  name: string;
  timeRange: string;
  description: string;
  icon: React.ElementType;
  colorClass: string;
  bgColorClass: string;
  borderColorClass: string;
  startHour: number;
  endHour: number;
}

const timeWindows: TimeWindow[] = [
  {
    id: "morning",
    name: "Morning",
    timeRange: "5 AM - 12 PM",
    description: "Start your day right",
    icon: Sun,
    colorClass: "text-amber-400",
    bgColorClass: "bg-amber-500/20",
    borderColorClass: "border-amber-500/50",
    startHour: 5,
    endHour: 12,
  },
  {
    id: "afternoon",
    name: "Afternoon",
    timeRange: "12 PM - 5 PM",
    description: "Midday activities",
    icon: SunMedium,
    colorClass: "text-orange-400",
    bgColorClass: "bg-orange-500/20",
    borderColorClass: "border-orange-500/50",
    startHour: 12,
    endHour: 17,
  },
  {
    id: "evening",
    name: "Evening",
    timeRange: "5 PM - 9 PM",
    description: "Wind down routine",
    icon: Sunset,
    colorClass: "text-pink-400",
    bgColorClass: "bg-pink-500/20",
    borderColorClass: "border-pink-500/50",
    startHour: 17,
    endHour: 21,
  },
  {
    id: "night",
    name: "Night",
    timeRange: "9 PM - 12 AM",
    description: "Pre-sleep preparation",
    icon: Moon,
    colorClass: "text-indigo-400",
    bgColorClass: "bg-indigo-500/20",
    borderColorClass: "border-indigo-500/50",
    startHour: 21,
    endHour: 24,
  },
];

interface InterventionTimeWindowsProps {
  value?: TimeWindowId;
  onChange: (windowId: TimeWindowId) => void;
  variant?: "compact" | "full";
  showDescription?: boolean;
}

export function InterventionTimeWindows({
  value,
  onChange,
  variant = "full",
  showDescription = true,
}: InterventionTimeWindowsProps) {
  if (variant === "compact") {
    return (
      <div className="flex gap-2">
        {timeWindows.map((window) => {
          const Icon = window.icon;
          const isSelected = value === window.id;

          return (
            <button
              key={window.id}
              onClick={() => onChange(window.id)}
              className={`flex items-center gap-2 px-3 py-2 rounded-lg border transition-all ${
                isSelected
                  ? `${window.bgColorClass} ${window.borderColorClass} ring-2 ring-offset-1 ring-offset-gray-900 ${window.borderColorClass}`
                  : "bg-gray-700/30 border-gray-600/30 hover:bg-gray-700/50"
              }`}
              title={`${window.name} (${window.timeRange})`}
            >
              <Icon className={`w-4 h-4 ${isSelected ? window.colorClass : "text-gray-400"}`} />
              <span className={`text-sm font-medium ${isSelected ? window.colorClass : "text-gray-300"}`}>
                {window.name}
              </span>
              {isSelected && <Check className="w-3 h-3 text-current" />}
            </button>
          );
        })}
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2 text-sm text-gray-400">
        <Clock className="w-4 h-4" />
        <span>Select Time Window</span>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {timeWindows.map((window) => {
          const Icon = window.icon;
          const isSelected = value === window.id;

          return (
            <button
              key={window.id}
              onClick={() => onChange(window.id)}
              className={`relative p-4 rounded-xl border-2 transition-all text-left ${
                isSelected
                  ? `${window.bgColorClass} ${window.borderColorClass}`
                  : "bg-gray-700/20 border-gray-600/30 hover:bg-gray-700/40 hover:border-gray-500/50"
              }`}
            >
              {/* Selected indicator */}
              {isSelected && (
                <div className={`absolute top-2 right-2 w-5 h-5 rounded-full ${window.bgColorClass} flex items-center justify-center`}>
                  <Check className={`w-3 h-3 ${window.colorClass}`} />
                </div>
              )}

              {/* Icon */}
              <div className={`w-10 h-10 rounded-lg ${window.bgColorClass} flex items-center justify-center mb-3`}>
                <Icon className={`w-5 h-5 ${window.colorClass}`} />
              </div>

              {/* Content */}
              <div>
                <h4 className={`font-semibold ${isSelected ? window.colorClass : "text-white"}`}>
                  {window.name}
                </h4>
                <p className="text-xs text-gray-400 mt-0.5">{window.timeRange}</p>
                {showDescription && (
                  <p className="text-xs text-gray-500 mt-1.5">{window.description}</p>
                )}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// Helper function to determine current time window
export function getCurrentTimeWindow(): TimeWindowId {
  const hour = new Date().getHours();

  if (hour >= 21 || hour < 5) return "night";
  if (hour >= 17) return "evening";
  if (hour >= 12) return "afternoon";
  return "morning";
}

// Helper function to check if a time window is currently active
export function isTimeWindowActive(windowId: TimeWindowId): boolean {
  return getCurrentTimeWindow() === windowId;
}

// Helper function to get time window details
export function getTimeWindowDetails(windowId: TimeWindowId): TimeWindow | undefined {
  return timeWindows.find((w) => w.id === windowId);
}

// Export timeWindows for use in other components
export { timeWindows };
