"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useMemo, useState } from "react";
import {
  Sun,
  Clock,
  Moon,
  Coffee,
  Zap,
  Check,
  X,
  ChevronLeft,
  ChevronRight,
  TrendingUp,
  TrendingDown,
} from "lucide-react";

interface CheckInHistoryCardProps {
  userId: Id<"users">;
  days?: number;
}

interface DayCheckIn {
  date: string;
  dayNumber: number;
  morning: {
    completed: boolean;
    sleepQuality?: number;
    energyLevel?: number;
    mood?: number;
  };
  midday: {
    completed: boolean;
    energy?: number;
    caffeineCups?: number;
    napTaken?: boolean;
    napDurationMins?: number;
  };
  evening: {
    completed: boolean;
    dayRating?: number;
    reflection?: string;
  };
}

export function CheckInHistoryCard({ userId, days = 14 }: CheckInHistoryCardProps) {
  const [selectedDay, setSelectedDay] = useState<DayCheckIn | null>(null);
  const [currentWeekOffset, setCurrentWeekOffset] = useState(0);

  // Fetch check-in history from Convex
  const checkInHistory = useQuery(api.checkIn.getCheckInHistory, {
    userId,
    days,
  });

  // Transform data into our format
  const checkInData = useMemo(() => {
    if (!checkInHistory) return [];

    const dataByDate: Record<string, DayCheckIn> = {};

    checkInHistory.forEach((checkIn: {
      checkin_date: string;
      checkin_type: string;
      completed: boolean;
      sleep_quality?: number;
      energy_level?: number;
      mood?: number;
      midday_energy?: number;
      caffeine_cups?: number;
      nap_taken?: boolean;
      nap_duration_mins?: number;
      overall_day_rating?: number;
      reflection_text?: string;
    }) => {
      const date = checkIn.checkin_date;
      if (!dataByDate[date]) {
        dataByDate[date] = {
          date,
          dayNumber: 0, // Will be calculated
          morning: { completed: false },
          midday: { completed: false },
          evening: { completed: false },
        };
      }

      if (checkIn.checkin_type === "morning") {
        dataByDate[date].morning = {
          completed: checkIn.completed,
          sleepQuality: checkIn.sleep_quality,
          energyLevel: checkIn.energy_level,
          mood: checkIn.mood,
        };
      } else if (checkIn.checkin_type === "midday") {
        dataByDate[date].midday = {
          completed: checkIn.completed,
          energy: checkIn.midday_energy,
          caffeineCups: checkIn.caffeine_cups,
          napTaken: checkIn.nap_taken,
          napDurationMins: checkIn.nap_duration_mins,
        };
      } else if (checkIn.checkin_type === "evening") {
        dataByDate[date].evening = {
          completed: checkIn.completed,
          dayRating: checkIn.overall_day_rating,
          reflection: checkIn.reflection_text,
        };
      }
    });

    // Sort by date and assign day numbers
    const sorted = Object.values(dataByDate).sort(
      (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()
    );
    sorted.forEach((day, idx) => {
      day.dayNumber = idx + 1;
    });

    return sorted;
  }, [checkInHistory]);

  // Get weeks for calendar view
  const weeks = useMemo(() => {
    const result: DayCheckIn[][] = [];
    for (let i = 0; i < checkInData.length; i += 7) {
      result.push(checkInData.slice(i, i + 7));
    }
    return result;
  }, [checkInData]);

  const currentWeek = weeks[weeks.length - 1 - currentWeekOffset] || [];

  // Calculate energy trend
  const energyTrend = useMemo(() => {
    const energyValues = checkInData
      .filter((d) => d.morning.energyLevel || d.midday.energy)
      .slice(-7)
      .map((d) => d.morning.energyLevel || d.midday.energy || 0);

    if (energyValues.length < 2) return null;

    const firstHalf = energyValues.slice(0, Math.floor(energyValues.length / 2));
    const secondHalf = energyValues.slice(Math.floor(energyValues.length / 2));
    const firstAvg = firstHalf.reduce((a, b) => a + b, 0) / firstHalf.length;
    const secondAvg = secondHalf.reduce((a, b) => a + b, 0) / secondHalf.length;

    return {
      direction: secondAvg > firstAvg ? "up" : secondAvg < firstAvg ? "down" : "stable",
      change: Math.abs(secondAvg - firstAvg).toFixed(1),
    };
  }, [checkInData]);

  // Calculate caffeine stats
  const caffeineStats = useMemo(() => {
    const caffeineData = checkInData
      .filter((d) => d.midday.caffeineCups !== undefined)
      .map((d) => d.midday.caffeineCups || 0);

    if (caffeineData.length === 0) return null;

    return {
      average: (caffeineData.reduce((a, b) => a + b, 0) / caffeineData.length).toFixed(1),
      max: Math.max(...caffeineData),
      daysTracked: caffeineData.length,
    };
  }, [checkInData]);

  // Calculate nap frequency
  const napStats = useMemo(() => {
    const middayData = checkInData.filter((d) => d.midday.completed);
    if (middayData.length === 0) return null;

    const napDays = middayData.filter((d) => d.midday.napTaken).length;
    const totalNapMins = middayData
      .filter((d) => d.midday.napDurationMins)
      .reduce((sum, d) => sum + (d.midday.napDurationMins || 0), 0);

    return {
      frequency: Math.round((napDays / middayData.length) * 100),
      avgDuration: napDays > 0 ? Math.round(totalNapMins / napDays) : 0,
      totalDays: napDays,
    };
  }, [checkInData]);

  const getCompletionStatus = (day: DayCheckIn) => {
    const completed =
      (day.morning.completed ? 1 : 0) +
      (day.midday.completed ? 1 : 0) +
      (day.evening.completed ? 1 : 0);
    return { completed, total: 3 };
  };

  const getCompletionColor = (completed: number, total: number) => {
    const ratio = completed / total;
    if (ratio === 1) return "bg-green-500";
    if (ratio >= 0.66) return "bg-amber-500";
    if (ratio >= 0.33) return "bg-orange-500";
    return "bg-gray-600";
  };

  if (!checkInHistory) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="animate-pulse">
          <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
          <div className="h-24 bg-gray-700/50 rounded"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-purple-500/20 flex items-center justify-center">
            <Clock className="w-4 h-4 text-purple-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Check-in History</h3>
            <p className="text-xs text-gray-500">Daily wellness tracking</p>
          </div>
        </div>
        {energyTrend && (
          <div className="flex items-center gap-1 text-xs">
            {energyTrend.direction === "up" ? (
              <TrendingUp className="w-3 h-3 text-green-400" />
            ) : energyTrend.direction === "down" ? (
              <TrendingDown className="w-3 h-3 text-red-400" />
            ) : null}
            <span className="text-gray-400">Energy {energyTrend.direction}</span>
          </div>
        )}
      </div>

      {/* Calendar View */}
      <div className="mb-4">
        <div className="flex items-center justify-between mb-2">
          <button
            onClick={() => setCurrentWeekOffset((prev) => Math.min(prev + 1, weeks.length - 1))}
            disabled={currentWeekOffset >= weeks.length - 1}
            className="p-1 rounded hover:bg-gray-700/50 disabled:opacity-30"
          >
            <ChevronLeft className="w-4 h-4 text-gray-400" />
          </button>
          <span className="text-xs text-gray-400">
            {currentWeek[0]?.date
              ? new Date(currentWeek[0].date).toLocaleDateString("en-US", {
                  month: "short",
                  day: "numeric",
                })
              : ""}{" "}
            -{" "}
            {currentWeek[currentWeek.length - 1]?.date
              ? new Date(currentWeek[currentWeek.length - 1].date).toLocaleDateString("en-US", {
                  month: "short",
                  day: "numeric",
                })
              : ""}
          </span>
          <button
            onClick={() => setCurrentWeekOffset((prev) => Math.max(prev - 1, 0))}
            disabled={currentWeekOffset <= 0}
            className="p-1 rounded hover:bg-gray-700/50 disabled:opacity-30"
          >
            <ChevronRight className="w-4 h-4 text-gray-400" />
          </button>
        </div>

        <div className="grid grid-cols-7 gap-1">
          {["S", "M", "T", "W", "T", "F", "S"].map((day, i) => (
            <div key={i} className="text-center text-[10px] text-gray-500 py-1">
              {day}
            </div>
          ))}
          {currentWeek.map((day, i) => {
            const status = getCompletionStatus(day);
            return (
              <button
                key={i}
                onClick={() => setSelectedDay(day)}
                className={`aspect-square rounded-lg flex flex-col items-center justify-center gap-0.5 transition-colors hover:ring-1 hover:ring-purple-500/50 ${
                  selectedDay?.date === day.date ? "ring-1 ring-purple-500" : ""
                }`}
              >
                <span className="text-[10px] text-gray-400">
                  {new Date(day.date).getDate()}
                </span>
                <div
                  className={`w-2 h-2 rounded-full ${getCompletionColor(
                    status.completed,
                    status.total
                  )}`}
                />
              </button>
            );
          })}
        </div>
      </div>

      {/* Selected Day Detail */}
      {selectedDay && (
        <div className="p-3 bg-gray-700/30 rounded-lg mb-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-medium text-white">
              Day {selectedDay.dayNumber} -{" "}
              {new Date(selectedDay.date).toLocaleDateString("en-US", {
                weekday: "short",
                month: "short",
                day: "numeric",
              })}
            </span>
            <button
              onClick={() => setSelectedDay(null)}
              className="text-gray-500 hover:text-gray-300"
            >
              <X className="w-3 h-3" />
            </button>
          </div>

          <div className="grid grid-cols-3 gap-2">
            {/* Morning */}
            <div
              className={`p-2 rounded ${
                selectedDay.morning.completed ? "bg-amber-500/20" : "bg-gray-600/30"
              }`}
            >
              <div className="flex items-center gap-1 mb-1">
                <Sun className="w-3 h-3 text-amber-400" />
                <span className="text-[10px] text-gray-300">Morning</span>
              </div>
              {selectedDay.morning.completed ? (
                <div className="space-y-0.5">
                  {selectedDay.morning.energyLevel && (
                    <div className="flex items-center gap-1">
                      <Zap className="w-2 h-2 text-yellow-400" />
                      <span className="text-[10px] text-gray-400">
                        {selectedDay.morning.energyLevel}/4
                      </span>
                    </div>
                  )}
                  {selectedDay.morning.mood && (
                    <div className="text-[10px] text-gray-400">
                      Mood: {selectedDay.morning.mood}/5
                    </div>
                  )}
                </div>
              ) : (
                <span className="text-[10px] text-gray-500">Not completed</span>
              )}
            </div>

            {/* Midday */}
            <div
              className={`p-2 rounded ${
                selectedDay.midday.completed ? "bg-blue-500/20" : "bg-gray-600/30"
              }`}
            >
              <div className="flex items-center gap-1 mb-1">
                <Clock className="w-3 h-3 text-blue-400" />
                <span className="text-[10px] text-gray-300">Midday</span>
              </div>
              {selectedDay.midday.completed ? (
                <div className="space-y-0.5">
                  {selectedDay.midday.caffeineCups !== undefined && (
                    <div className="flex items-center gap-1">
                      <Coffee className="w-2 h-2 text-amber-400" />
                      <span className="text-[10px] text-gray-400">
                        {selectedDay.midday.caffeineCups} cups
                      </span>
                    </div>
                  )}
                  {selectedDay.midday.napTaken && (
                    <div className="text-[10px] text-gray-400">
                      Nap: {selectedDay.midday.napDurationMins}min
                    </div>
                  )}
                </div>
              ) : (
                <span className="text-[10px] text-gray-500">Not completed</span>
              )}
            </div>

            {/* Evening */}
            <div
              className={`p-2 rounded ${
                selectedDay.evening.completed ? "bg-purple-500/20" : "bg-gray-600/30"
              }`}
            >
              <div className="flex items-center gap-1 mb-1">
                <Moon className="w-3 h-3 text-purple-400" />
                <span className="text-[10px] text-gray-300">Evening</span>
              </div>
              {selectedDay.evening.completed ? (
                <div className="space-y-0.5">
                  {selectedDay.evening.dayRating && (
                    <div className="text-[10px] text-gray-400">
                      Day: {selectedDay.evening.dayRating}/5
                    </div>
                  )}
                </div>
              ) : (
                <span className="text-[10px] text-gray-500">Not completed</span>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Stats Row */}
      <div className="grid grid-cols-3 gap-2">
        {/* Caffeine */}
        <div className="p-2 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-1 mb-1">
            <Coffee className="w-3 h-3 text-amber-400" />
            <span className="text-[10px] text-gray-400">Caffeine</span>
          </div>
          {caffeineStats ? (
            <div>
              <span className="text-sm font-medium text-white">{caffeineStats.average}</span>
              <span className="text-[10px] text-gray-400 ml-1">avg cups/day</span>
            </div>
          ) : (
            <span className="text-[10px] text-gray-500">No data</span>
          )}
        </div>

        {/* Naps */}
        <div className="p-2 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-1 mb-1">
            <Moon className="w-3 h-3 text-blue-400" />
            <span className="text-[10px] text-gray-400">Naps</span>
          </div>
          {napStats ? (
            <div>
              <span className="text-sm font-medium text-white">{napStats.frequency}%</span>
              <span className="text-[10px] text-gray-400 ml-1">of days</span>
            </div>
          ) : (
            <span className="text-[10px] text-gray-500">No data</span>
          )}
        </div>

        {/* Completion Rate */}
        <div className="p-2 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-1 mb-1">
            <Check className="w-3 h-3 text-green-400" />
            <span className="text-[10px] text-gray-400">Completed</span>
          </div>
          <div>
            <span className="text-sm font-medium text-white">
              {checkInData.filter((d) => d.morning.completed && d.midday.completed && d.evening.completed).length}
            </span>
            <span className="text-[10px] text-gray-400 ml-1">/ {checkInData.length} days</span>
          </div>
        </div>
      </div>
    </div>
  );
}
