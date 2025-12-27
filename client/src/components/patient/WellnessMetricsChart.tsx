"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState } from "react";
import {
  Battery,
  Smile,
  Target,
  TrendingUp,
  TrendingDown,
  Minus,
  Calendar,
} from "lucide-react";

interface WellnessMetricsChartProps {
  userId: Id<"users">;
}

export function WellnessMetricsChart({ userId }: WellnessMetricsChartProps) {
  const [timeRange, setTimeRange] = useState<7 | 14 | 30>(14);

  // Fetch check-in trends from the new physician query
  const trendsData = useQuery(api.physician.getPatientCheckInTrends, {
    patientId: userId,
    days: timeRange,
  });

  if (!trendsData) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="animate-pulse">
          <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
          <div className="h-32 bg-gray-700/50 rounded"></div>
        </div>
      </div>
    );
  }

  const { dailyData, summary } = trendsData;

  // Get data points with values for the chart
  type DayData = NonNullable<typeof trendsData>["dailyData"][number];
  const dataWithValues = dailyData.filter((d: DayData) => d.hasData);

  const getTrendIcon = (trend?: number) => {
    if (trend === undefined) return null;
    if (trend > 0.3) return <TrendingUp className="w-3 h-3 text-green-400" />;
    if (trend < -0.3) return <TrendingDown className="w-3 h-3 text-red-400" />;
    return <Minus className="w-3 h-3 text-gray-400" />;
  };

  const getTrendColor = (trend?: number) => {
    if (trend === undefined) return "text-gray-400";
    if (trend > 0.3) return "text-green-400";
    if (trend < -0.3) return "text-red-400";
    return "text-gray-400";
  };

  const formatTrend = (trend?: number) => {
    if (trend === undefined) return "-";
    const sign = trend > 0 ? "+" : "";
    return `${sign}${trend.toFixed(1)}`;
  };

  // Calculate bar heights (scale 1-6 to percentage)
  const getBarHeight = (value?: number) => {
    if (!value) return 0;
    return ((value - 1) / 5) * 100; // Scale 1-6 to 0-100%
  };

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-orange-500/20 to-yellow-500/20 flex items-center justify-center">
            <Battery className="w-4 h-4 text-orange-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Wellness Metrics</h3>
            <p className="text-xs text-gray-500">Energy, Mood & Focus from Watch</p>
          </div>
        </div>

        {/* Time Range Selector */}
        <div className="flex items-center gap-1 bg-gray-700/50 rounded-lg p-0.5">
          {([7, 14, 30] as const).map((days) => (
            <button
              key={days}
              onClick={() => setTimeRange(days)}
              className={`px-2 py-1 text-xs rounded-md transition-colors ${
                timeRange === days
                  ? "bg-teal-600 text-white"
                  : "text-gray-400 hover:text-white"
              }`}
            >
              {days}d
            </button>
          ))}
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-3 gap-3 mb-4">
        {/* Energy */}
        <div className="p-3 bg-gray-700/30 rounded-lg">
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-1">
              <Battery className="w-3 h-3 text-orange-400" />
              <span className="text-xs text-gray-400">Energy</span>
            </div>
            {getTrendIcon(summary.energyTrend)}
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-lg font-semibold text-white">
              {summary.avgEnergy?.toFixed(1) ?? "-"}
            </span>
            <span className="text-xs text-gray-500">/6</span>
          </div>
          <div className={`text-xs ${getTrendColor(summary.energyTrend)}`}>
            {formatTrend(summary.energyTrend)} trend
          </div>
        </div>

        {/* Mood */}
        <div className="p-3 bg-gray-700/30 rounded-lg">
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-1">
              <Smile className="w-3 h-3 text-yellow-400" />
              <span className="text-xs text-gray-400">Mood</span>
            </div>
            {getTrendIcon(summary.moodTrend)}
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-lg font-semibold text-white">
              {summary.avgMood?.toFixed(1) ?? "-"}
            </span>
            <span className="text-xs text-gray-500">/6</span>
          </div>
          <div className={`text-xs ${getTrendColor(summary.moodTrend)}`}>
            {formatTrend(summary.moodTrend)} trend
          </div>
        </div>

        {/* Focus */}
        <div className="p-3 bg-gray-700/30 rounded-lg">
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-1">
              <Target className="w-3 h-3 text-cyan-400" />
              <span className="text-xs text-gray-400">Focus</span>
            </div>
            {getTrendIcon(summary.focusTrend)}
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-lg font-semibold text-white">
              {summary.avgFocus?.toFixed(1) ?? "-"}
            </span>
            <span className="text-xs text-gray-500">/5</span>
          </div>
          <div className={`text-xs ${getTrendColor(summary.focusTrend)}`}>
            {formatTrend(summary.focusTrend)} trend
          </div>
        </div>
      </div>

      {/* Chart */}
      {dataWithValues.length > 0 ? (
        <div className="relative">
          {/* Y-axis labels */}
          <div className="absolute left-0 top-0 bottom-6 w-6 flex flex-col justify-between text-[10px] text-gray-500">
            <span>6</span>
            <span>3</span>
            <span>1</span>
          </div>

          {/* Chart area */}
          <div className="ml-8 h-32 flex items-end gap-1">
            {dailyData.map((day: DayData, i: number) => (
              <div
                key={day.date}
                className="flex-1 flex flex-col items-center gap-0.5"
              >
                {day.hasData ? (
                  <div className="w-full flex items-end justify-center gap-px h-24">
                    {/* Energy bar */}
                    <div
                      className="w-2 bg-orange-500 rounded-t-sm transition-all"
                      style={{ height: `${getBarHeight(day.avgEnergy)}%` }}
                      title={`Energy: ${day.avgEnergy}`}
                    />
                    {/* Mood bar */}
                    <div
                      className="w-2 bg-yellow-500 rounded-t-sm transition-all"
                      style={{ height: `${getBarHeight(day.avgMood)}%` }}
                      title={`Mood: ${day.avgMood}`}
                    />
                    {/* Focus bar */}
                    <div
                      className="w-2 bg-cyan-500 rounded-t-sm transition-all"
                      style={{ height: `${getBarHeight(day.avgFocus)}%` }}
                      title={`Focus: ${day.avgFocus}`}
                    />
                  </div>
                ) : (
                  <div className="w-full h-24 flex items-center justify-center">
                    <div className="text-gray-600 text-xs">×</div>
                  </div>
                )}
                {/* Day label - show every few days to avoid clutter */}
                {(i === 0 || i === dailyData.length - 1 || i % Math.ceil(dailyData.length / 5) === 0) && (
                  <span className="text-[9px] text-gray-500">{day.dayOfWeek}</span>
                )}
              </div>
            ))}
          </div>

          {/* Legend */}
          <div className="flex items-center justify-center gap-4 mt-2 text-xs">
            <div className="flex items-center gap-1">
              <div className="w-2 h-2 rounded-full bg-orange-500" />
              <span className="text-gray-400">Energy</span>
            </div>
            <div className="flex items-center gap-1">
              <div className="w-2 h-2 rounded-full bg-yellow-500" />
              <span className="text-gray-400">Mood</span>
            </div>
            <div className="flex items-center gap-1">
              <div className="w-2 h-2 rounded-full bg-cyan-500" />
              <span className="text-gray-400">Focus</span>
            </div>
          </div>
        </div>
      ) : (
        <div className="h-32 flex items-center justify-center text-gray-500 text-sm">
          <div className="text-center">
            <Calendar className="w-8 h-8 mx-auto mb-2 opacity-50" />
            <p>No wellness check-ins yet</p>
            <p className="text-xs text-gray-600">
              Data appears when patient uses the Watch app
            </p>
          </div>
        </div>
      )}

      {/* Data coverage */}
      <div className="mt-3 flex items-center justify-between text-xs text-gray-500">
        <span>
          {summary.daysWithData} of {summary.totalDays} days tracked
        </span>
        <span className="text-[10px] text-gray-600">
          Data from Apple Watch check-ins
        </span>
      </div>
    </div>
  );
}
