"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useMemo } from "react";
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

interface MultiSourceSleepChartProps {
  hasMultipleSources: boolean;
  sources: string[];
  sourceStats: SourceStat[];
  comparisonData: ComparisonDataPoint[];
  totalDays: number;
  metric?: "efficiency" | "totalSleep" | "deepSleep";
  height?: number;
}

export function MultiSourceSleepChart({
  hasMultipleSources,
  sources,
  sourceStats,
  comparisonData,
  totalDays,
  metric = "efficiency",
  height = 200,
}: MultiSourceSleepChartProps) {
  // Transform data for Recharts
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
          switch (metric) {
            case "efficiency":
              point[source] = sourceData.efficiency;
              break;
            case "totalSleep":
              point[source] = sourceData.totalSleepMins
                ? Math.round(sourceData.totalSleepMins / 60 * 10) / 10
                : null;
              break;
            case "deepSleep":
              point[source] = sourceData.deepMins;
              break;
          }
        } else {
          point[source] = null;
        }
      }

      return point;
    });
  }, [comparisonData, sources, metric]);

  const metricConfig = {
    efficiency: {
      label: "Sleep Efficiency",
      unit: "%",
      domain: [60, 100] as [number, number]
    },
    totalSleep: {
      label: "Total Sleep",
      unit: "hrs",
      domain: [4, 10] as [number, number]
    },
    deepSleep: {
      label: "Deep Sleep",
      unit: "min",
      domain: [0, 120] as [number, number]
    },
  };

  const config = metricConfig[metric];

  if (!hasMultipleSources) {
    return (
      <div className="flex items-center justify-center h-full text-gray-500 text-sm">
        <p>Single data source - no comparison available</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
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
        <LineChart data={chartData} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
          <XAxis
            dataKey="shortDate"
            tick={{ fill: "#9CA3AF", fontSize: 10 }}
            tickLine={{ stroke: "#4B5563" }}
            axisLine={{ stroke: "#4B5563" }}
          />
          <YAxis
            domain={config.domain}
            tick={{ fill: "#9CA3AF", fontSize: 10 }}
            tickLine={{ stroke: "#4B5563" }}
            axisLine={{ stroke: "#4B5563" }}
            tickFormatter={(v) => `${v}${config.unit === "%" ? "" : ""}`}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: "#1F2937",
              border: "1px solid #374151",
              borderRadius: "8px",
              boxShadow: "0 4px 6px -1px rgba(0, 0, 0, 0.3)",
            }}
            labelStyle={{ color: "#F9FAFB", fontWeight: 500 }}
            itemStyle={{ color: "#D1D5DB" }}
            formatter={(value: number, name: string) => [
              `${value}${config.unit}`,
              name,
            ]}
          />
          <Legend
            verticalAlign="bottom"
            height={36}
            wrapperStyle={{ paddingTop: "10px" }}
          />
          {sources.map((source) => (
            <Line
              key={source}
              type="monotone"
              dataKey={source}
              stroke={SOURCE_COLORS[source] || SOURCE_COLORS["Unknown"]}
              strokeWidth={2}
              dot={{ r: 3, fill: SOURCE_COLORS[source] || SOURCE_COLORS["Unknown"] }}
              activeDot={{ r: 5 }}
              connectNulls={false}
            />
          ))}
        </LineChart>
      </ResponsiveContainer>

      {/* Metric Selector */}
      <div className="flex justify-center gap-2">
        <span className="text-xs text-gray-400">
          Comparing: <span className="text-white font-medium">{config.label}</span>
        </span>
      </div>
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
