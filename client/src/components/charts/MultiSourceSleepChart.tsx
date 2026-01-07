"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useMemo, useState } from "react";
import React from "react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";
import { Watch, Activity, Smartphone } from "lucide-react";

// Source color mapping
const SOURCE_COLORS: Record<string, string> = {
  "Apple Watch": "#10B981",    // Green
  "Oura": "#8B5CF6",           // Purple
  "Oura Ring": "#8B5CF6",
  "Fitbit": "#14B8A6",         // Teal
  "Garmin": "#3B82F6",         // Blue
  "WHOOP": "#F59E0B",          // Amber
  "Questionnaire": "#F97316",   // Orange
  "Sleep Log": "#F97316",
  "Unknown": "#6B7280",        // Gray
};

// Get icon for source
function getSourceIcon(source: string) {
  const upper = source.toUpperCase();
  if (upper.includes("WATCH") || upper.includes("FITBIT") || upper.includes("GARMIN")) {
    return Watch;
  }
  if (upper.includes("OURA") || upper.includes("WHOOP")) {
    return Activity;
  }
  return Smartphone;
}

interface SourceStat {
  source: string;
  dataPoints: number;
  avgEfficiency: number | null;
  avgSleepHours: number | null;
  hasDeepSleep: boolean;
  hasHeartRate: boolean;
  deviceModels?: string[];  // Array of device models for upgrade tracking
  dateRange?: {
    first: string;
    last: string;
  } | null;
}

interface ComparisonDataPoint {
  date: string;
  sources: Record<string, {
    totalSleepMins: number | null;
    efficiency: number | null;
    deepMins: number | null;
    remMins: number | null;
    lightMins: number | null;
  } | null>;
}

interface WellnessDataPoint {
  date: string;
  morningEnergy?: number;
  morningMood?: number;
  morningFocus?: number;
  middayEnergy?: number;
  middayMood?: number;
  middayFocus?: number;
  eveningEnergy?: number;
  eveningMood?: number;
  eveningFocus?: number;
}

interface MultiSourceSleepChartProps {
  hasMultipleSources: boolean;
  sources: string[];
  sourceStats: SourceStat[];
  comparisonData: ComparisonDataPoint[];
  totalDays: number;
  metric?: "efficiency" | "totalSleep" | "deepSleep";
  height?: number;
  wellnessData?: WellnessDataPoint[];
}

type MetricKey = "efficiency" | "totalSleep" | "quality" | "energy" | "mood" | "focus";

export function MultiSourceSleepChart({
  hasMultipleSources,
  sources,
  sourceStats,
  comparisonData,
  totalDays,
  metric: _deprecatedMetric,
  height = 300,
  wellnessData = [],
}: MultiSourceSleepChartProps) {
  // Internal state for togglable metrics
  const [activeMetrics, setActiveMetrics] = useState<Record<MetricKey, boolean>>({
    efficiency: true,
    totalSleep: false,
    quality: false,
    energy: false,
    mood: false,
    focus: false,
  });

  const toggleMetric = (key: MetricKey) => {
    setActiveMetrics(prev => ({ ...prev, [key]: !prev[key] }));
  };
  // Transform data for Recharts - supports multiple metrics
  const chartData = useMemo(() => {
    return comparisonData.map((day) => {
      const point: Record<string, string | number | null> = {
        date: day.date,
        shortDate: new Date(day.date).toLocaleDateString("en-US", {
          month: "short",
          day: "numeric"
        }),
      };

      for (const source of sources) {
        const sourceData = day.sources[source];
        if (sourceData) {
          // Add all metric values with suffixes
          if (activeMetrics.efficiency) {
            point[`${source}_efficiency`] = sourceData.efficiency;
          }
          if (activeMetrics.totalSleep) {
            point[`${source}_hours`] = sourceData.totalSleepMins
              ? Math.round(sourceData.totalSleepMins / 60 * 10) / 10
              : null;
          }
          if (activeMetrics.quality) {
            // Quality score: derive from efficiency + deep sleep percentage
            const quality = sourceData.efficiency && sourceData.deepMins && sourceData.totalSleepMins
              ? Math.round(
                  (sourceData.efficiency * 0.6) +
                  ((sourceData.deepMins / sourceData.totalSleepMins) * 100 * 0.4)
                )
              : sourceData.efficiency; // Fallback to efficiency if no deep sleep
            point[`${source}_quality`] = quality;
          }
        }
      }

      // Add wellness metrics if available
      const wellness = wellnessData.find(w => w.date === day.date);
      if (wellness) {
        if (activeMetrics.energy) {
          // Average energy across the day (morning, midday, evening)
          const energyValues = [
            wellness.morningEnergy,
            wellness.middayEnergy,
            wellness.eveningEnergy
          ].filter((v): v is number => v !== undefined);
          point.avgEnergy = energyValues.length > 0
            ? Math.round((energyValues.reduce((a, b) => a + b, 0) / energyValues.length) * 10) / 10
            : null;
        }
        if (activeMetrics.mood) {
          // Average mood across the day
          const moodValues = [
            wellness.morningMood,
            wellness.middayMood,
            wellness.eveningMood
          ].filter((v): v is number => v !== undefined);
          point.avgMood = moodValues.length > 0
            ? Math.round((moodValues.reduce((a, b) => a + b, 0) / moodValues.length) * 10) / 10
            : null;
        }
        if (activeMetrics.focus) {
          // Average focus across the day
          const focusValues = [
            wellness.morningFocus,
            wellness.middayFocus,
            wellness.eveningFocus
          ].filter((v): v is number => v !== undefined);
          point.avgFocus = focusValues.length > 0
            ? Math.round((focusValues.reduce((a, b) => a + b, 0) / focusValues.length) * 10) / 10
            : null;
        }
      }

      return point;
    });
  }, [comparisonData, sources, activeMetrics, wellnessData]);

  const metricConfig = {
    efficiency: {
      label: "Sleep Efficiency",
      unit: "%",
      domain: [60, 100] as [number, number],
      yAxisId: "left"
    },
    totalSleep: {
      label: "Total Sleep",
      unit: "hrs",
      domain: [4, 10] as [number, number],
      yAxisId: "right"
    },
    quality: {
      label: "Quality Score",
      unit: "",
      domain: [60, 100] as [number, number],
      yAxisId: "left"
    },
    energy: {
      label: "Energy Level",
      unit: "/6",
      domain: [1, 6] as [number, number],
      yAxisId: "wellness"
    },
    mood: {
      label: "Mood Level",
      unit: "/6",
      domain: [1, 6] as [number, number],
      yAxisId: "wellness"
    },
    focus: {
      label: "Focus Level",
      unit: "/5",
      domain: [1, 5] as [number, number],
      yAxisId: "wellness"
    },
  };

  // Determine which Y-axes to show
  const showLeftAxis = activeMetrics.efficiency || activeMetrics.quality;
  const showRightAxis = activeMetrics.totalSleep;
  const showWellnessAxis = activeMetrics.energy || activeMetrics.mood || activeMetrics.focus;
  const activeMetricCount = Object.values(activeMetrics).filter(Boolean).length;

  if (!hasMultipleSources) {
    return (
      <div className="flex items-center justify-center h-full text-gray-500 text-sm">
        <p>Single data source - no comparison available</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Metric Toggle Buttons */}
      <div className="flex flex-col gap-3">
        {/* Sleep Metrics */}
        <div className="flex items-center gap-2 justify-center flex-wrap">
          <span className="text-xs text-gray-500 mr-2">Sleep:</span>
          <button
            onClick={() => toggleMetric("efficiency")}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
              activeMetrics.efficiency
                ? "bg-blue-500 text-white shadow-lg shadow-blue-500/30"
                : "bg-gray-800 text-gray-400 hover:bg-gray-700"
            }`}
          >
            Efficiency %
          </button>
          <button
            onClick={() => toggleMetric("totalSleep")}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
              activeMetrics.totalSleep
                ? "bg-purple-500 text-white shadow-lg shadow-purple-500/30"
                : "bg-gray-800 text-gray-400 hover:bg-gray-700"
            }`}
          >
            Duration (hrs)
          </button>
          <button
            onClick={() => toggleMetric("quality")}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
              activeMetrics.quality
                ? "bg-green-500 text-white shadow-lg shadow-green-500/30"
                : "bg-gray-800 text-gray-400 hover:bg-gray-700"
            }`}
          >
            Quality Score
          </button>
        </div>

        {/* Wellness Metrics */}
        {wellnessData.length > 0 && (
          <div className="flex items-center gap-2 justify-center flex-wrap">
            <span className="text-xs text-gray-500 mr-2">Wellness:</span>
            <button
              onClick={() => toggleMetric("energy")}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                activeMetrics.energy
                  ? "bg-amber-500 text-white shadow-lg shadow-amber-500/30"
                  : "bg-gray-800 text-gray-400 hover:bg-gray-700"
              }`}
            >
              Energy
            </button>
            <button
              onClick={() => toggleMetric("mood")}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                activeMetrics.mood
                  ? "bg-pink-500 text-white shadow-lg shadow-pink-500/30"
                  : "bg-gray-800 text-gray-400 hover:bg-gray-700"
              }`}
            >
              Mood
            </button>
            <button
              onClick={() => toggleMetric("focus")}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                activeMetrics.focus
                  ? "bg-cyan-500 text-white shadow-lg shadow-cyan-500/30"
                  : "bg-gray-800 text-gray-400 hover:bg-gray-700"
              }`}
            >
              Focus
            </button>
          </div>
        )}
      </div>

      {activeMetricCount === 0 && (
        <div className="text-center text-sm text-gray-400 py-4">
          Select at least one metric to compare
        </div>
      )}

      {activeMetricCount > 0 && (
        <>
          {/* Source Legend with Stats */}
          <div className="flex flex-wrap gap-3">
        {sourceStats.map((stat) => {
          const Icon = getSourceIcon(stat.source);
          const color = SOURCE_COLORS[stat.source] || SOURCE_COLORS["Unknown"];

          return (
            <div
              key={stat.source}
              className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-gray-800/50 border border-gray-700/50"
            >
              <div
                className="w-6 h-6 rounded-full flex items-center justify-center"
                style={{ backgroundColor: `${color}20` }}
              >
                <Icon className="w-3 h-3" style={{ color }} />
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-medium text-white">{stat.source}</span>
                <span className="text-[10px] text-gray-400">
                  {stat.dataPoints} days
                  {stat.avgEfficiency && ` · ${stat.avgEfficiency}% avg`}
                </span>
              </div>
              {stat.hasDeepSleep && (
                <span className="px-1.5 py-0.5 text-[9px] rounded bg-green-500/20 text-green-400 border border-green-500/30">
                  Stages
                </span>
              )}
            </div>
          );
        })}
      </div>

          {/* Chart */}
          <ResponsiveContainer width="100%" height={height}>
            <LineChart data={chartData} margin={{ top: 5, right: showWellnessAxis ? 40 : (showRightAxis ? 30 : 5), left: -20, bottom: 5 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
              <XAxis
                dataKey="shortDate"
                tick={{ fill: "#9CA3AF", fontSize: 10 }}
                tickLine={{ stroke: "#4B5563" }}
                axisLine={{ stroke: "#4B5563" }}
              />
              {showLeftAxis && (
                <YAxis
                  yAxisId="left"
                  domain={[60, 100]}
                  tick={{ fill: "#9CA3AF", fontSize: 10 }}
                  tickLine={{ stroke: "#4B5563" }}
                  axisLine={{ stroke: "#4B5563" }}
                  label={{ value: "% / Score", angle: -90, position: "insideLeft", style: { fill: "#9CA3AF", fontSize: 10 } }}
                />
              )}
              {showRightAxis && !showWellnessAxis && (
                <YAxis
                  yAxisId="right"
                  orientation="right"
                  domain={[4, 10]}
                  tick={{ fill: "#9CA3AF", fontSize: 10 }}
                  tickLine={{ stroke: "#4B5563" }}
                  axisLine={{ stroke: "#4B5563" }}
                  label={{ value: "Hours", angle: 90, position: "insideRight", style: { fill: "#9CA3AF", fontSize: 10 } }}
                />
              )}
              {showWellnessAxis && (
                <YAxis
                  yAxisId="wellness"
                  orientation="right"
                  domain={[1, 6]}
                  tick={{ fill: "#9CA3AF", fontSize: 10 }}
                  tickLine={{ stroke: "#4B5563" }}
                  axisLine={{ stroke: "#4B5563" }}
                  label={{ value: "Wellness (1-6)", angle: 90, position: "insideRight", style: { fill: "#9CA3AF", fontSize: 10 } }}
                />
              )}
              <Tooltip
                contentStyle={{
                  backgroundColor: "#1F2937",
                  border: "1px solid #374151",
                  borderRadius: "8px",
                  boxShadow: "0 4px 6px -1px rgba(0, 0, 0, 0.3)",
                }}
                labelStyle={{ color: "#F9FAFB", fontWeight: 500 }}
                itemStyle={{ color: "#D1D5DB" }}
                formatter={(value: number, name: string) => {
                  const cleanName = name.replace(/_efficiency|_hours|_quality/, "");
                  let unit = "";
                  let label = cleanName;
                  if (name.includes("_efficiency")) unit = "%";
                  if (name.includes("_hours")) unit = "h";
                  if (name.includes("_quality")) unit = " pts";
                  if (name === "avgEnergy") { label = "Energy"; unit = "/6"; }
                  if (name === "avgMood") { label = "Mood"; unit = "/6"; }
                  if (name === "avgFocus") { label = "Focus"; unit = "/5"; }
                  return [`${value}${unit}`, label];
                }}
              />
              <Legend
                verticalAlign="bottom"
                height={36}
                wrapperStyle={{ paddingTop: "10px" }}
                formatter={(value) => value.replace(/_efficiency|_hours|_quality/, "")}
              />
              {sources.map((source) => {
                const color = SOURCE_COLORS[source] || SOURCE_COLORS["Unknown"];
                return (
                  <React.Fragment key={source}>
                    {activeMetrics.efficiency && (
                      <Line
                        type="monotone"
                        dataKey={`${source}_efficiency`}
                        yAxisId="left"
                        stroke={color}
                        strokeWidth={2}
                        dot={{ r: 3, fill: color }}
                        activeDot={{ r: 5 }}
                        connectNulls={false}
                        name={`${source} (Efficiency)`}
                      />
                    )}
                    {activeMetrics.totalSleep && (
                      <Line
                        type="monotone"
                        dataKey={`${source}_hours`}
                        yAxisId="right"
                        stroke={color}
                        strokeWidth={2}
                        strokeDasharray="5 5"
                        dot={{ r: 3, fill: color }}
                        activeDot={{ r: 5 }}
                        connectNulls={false}
                        name={`${source} (Hours)`}
                      />
                    )}
                    {activeMetrics.quality && (
                      <Line
                        type="monotone"
                        dataKey={`${source}_quality`}
                        yAxisId="left"
                        stroke={color}
                        strokeWidth={2}
                        strokeDasharray="3 3"
                        dot={{ r: 3, fill: color }}
                        activeDot={{ r: 5 }}
                        connectNulls={false}
                        name={`${source} (Quality)`}
                      />
                    )}
                  </React.Fragment>
                );
              })}

              {/* Wellness Metrics Lines */}
              {activeMetrics.energy && (
                <Line
                  type="monotone"
                  dataKey="avgEnergy"
                  yAxisId="wellness"
                  stroke="#F59E0B"
                  strokeWidth={2}
                  strokeDasharray="8 4"
                  dot={{ r: 4, fill: "#F59E0B" }}
                  activeDot={{ r: 6 }}
                  connectNulls={true}
                  name="Energy"
                />
              )}
              {activeMetrics.mood && (
                <Line
                  type="monotone"
                  dataKey="avgMood"
                  yAxisId="wellness"
                  stroke="#EC4899"
                  strokeWidth={2}
                  strokeDasharray="8 4"
                  dot={{ r: 4, fill: "#EC4899" }}
                  activeDot={{ r: 6 }}
                  connectNulls={true}
                  name="Mood"
                />
              )}
              {activeMetrics.focus && (
                <Line
                  type="monotone"
                  dataKey="avgFocus"
                  yAxisId="wellness"
                  stroke="#06B6D4"
                  strokeWidth={2}
                  strokeDasharray="8 4"
                  dot={{ r: 4, fill: "#06B6D4" }}
                  activeDot={{ r: 6 }}
                  connectNulls={true}
                  name="Focus"
                />
              )}
            </LineChart>
          </ResponsiveContainer>

          {/* Normalization Note */}
          {activeMetrics.quality && (
            <div className="flex items-center justify-center gap-2 text-xs text-gray-400">
              <span className="text-amber-400">*</span>
              <span>Quality score normalized across devices (60-40 efficiency-deep sleep split)</span>
            </div>
          )}
        </>
      )}
    </div>
  );
}

// Summary card showing source differences
export function SourceComparisonSummary({
  sourceStats,
}: {
  sourceStats: SourceStat[];
}) {
  if (sourceStats.length < 2) return null;

  // Find the source with highest efficiency
  const sortedByEfficiency = [...sourceStats]
    .filter(s => s.avgEfficiency !== null)
    .sort((a, b) => (b.avgEfficiency || 0) - (a.avgEfficiency || 0));

  if (sortedByEfficiency.length < 2) return null;

  const best = sortedByEfficiency[0];
  const worst = sortedByEfficiency[sortedByEfficiency.length - 1];
  const diff = (best.avgEfficiency || 0) - (worst.avgEfficiency || 0);

  if (diff < 5) {
    return (
      <div className="p-3 rounded-lg bg-green-500/10 border border-green-500/30">
        <p className="text-xs text-green-400">
          Your wearables are showing consistent data with only {diff.toFixed(1)}% variance in sleep efficiency.
        </p>
      </div>
    );
  }

  return (
    <div className="p-3 rounded-lg bg-amber-500/10 border border-amber-500/30">
      <p className="text-xs text-amber-400">
        <span className="font-medium">{best.source}</span> reports {diff.toFixed(1)}% higher
        efficiency than <span className="font-medium">{worst.source}</span>.
        {diff > 15 && " Consider reviewing device placement or settings."}
      </p>
    </div>
  );
}

// Mini source badges for inline display
export function SourceBadges({ sources }: { sources: string[] }) {
  return (
    <div className="flex items-center gap-1">
      {sources.slice(0, 3).map((source) => {
        const Icon = getSourceIcon(source);
        const color = SOURCE_COLORS[source] || SOURCE_COLORS["Unknown"];

        return (
          <div
            key={source}
            className="w-5 h-5 rounded-full flex items-center justify-center"
            style={{ backgroundColor: `${color}20` }}
            title={source}
          >
            <Icon className="w-2.5 h-2.5" style={{ color }} />
          </div>
        );
      })}
      {sources.length > 3 && (
        <span className="text-[10px] text-gray-500">+{sources.length - 3}</span>
      )}
    </div>
  );
}
