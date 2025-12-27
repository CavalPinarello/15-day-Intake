"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState } from "react";
import {
  Sun,
  Thermometer,
  TrendingUp,
  TrendingDown,
  Minus,
  Activity,
  Sunrise,
} from "lucide-react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
} from "recharts";

interface CircadianMetricsCardProps {
  userId: Id<"users">;
}

export function CircadianMetricsCard({ userId }: CircadianMetricsCardProps) {
  const [timeRange, setTimeRange] = useState<7 | 14>(14);

  // Fetch circadian data from Convex
  const circadianData = useQuery(api.circadian.getCircadianSummary, {
    userId,
    days: timeRange,
  });

  if (!circadianData) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="animate-pulse">
          <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
          <div className="h-32 bg-gray-700/50 rounded"></div>
        </div>
      </div>
    );
  }

  if (!circadianData.hasData) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="flex items-center gap-2 mb-3">
          <div className="w-8 h-8 rounded-lg bg-yellow-500/20 flex items-center justify-center">
            <Sun className="w-4 h-4 text-yellow-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Circadian Signals</h3>
            <p className="text-xs text-gray-500">Light & temperature tracking</p>
          </div>
        </div>
        <div className="h-24 flex items-center justify-center text-gray-500 text-sm">
          <div className="text-center">
            <Sun className="w-8 h-8 mx-auto mb-2 opacity-50" />
            <p>No circadian data available</p>
            <p className="text-xs text-gray-600 mt-1">
              Requires iOS 17+ with outdoor activity
            </p>
          </div>
        </div>
      </div>
    );
  }

  const getTrendIcon = (trend: string | null) => {
    if (trend === "improving") return <TrendingUp className="w-3 h-3 text-green-400" />;
    if (trend === "declining") return <TrendingDown className="w-3 h-3 text-red-400" />;
    return <Minus className="w-3 h-3 text-gray-400" />;
  };

  const getScoreColor = (score: number | null) => {
    if (!score) return "text-gray-400";
    if (score >= 80) return "text-green-400";
    if (score >= 60) return "text-yellow-400";
    if (score >= 40) return "text-orange-400";
    return "text-red-400";
  };

  const getScoreBgColor = (score: number | null) => {
    if (!score) return "bg-gray-700/30";
    if (score >= 80) return "bg-green-500/10";
    if (score >= 60) return "bg-yellow-500/10";
    if (score >= 40) return "bg-orange-500/10";
    return "bg-red-500/10";
  };

  // Prepare chart data - reverse to show oldest first (left to right)
  const chartData = circadianData.recentData
    .slice()
    .reverse()
    .map((d) => ({
      date: d.date.slice(5), // MM-DD format
      daylight: d.daylightMins ?? 0,
      morning: d.morningLightMins ?? 0,
      score: d.circadianScore ?? 0,
    }));

  // Get bar color based on daylight amount
  const getBarColor = (value: number) => {
    if (value >= 80) return "#22C55E"; // green
    if (value >= 60) return "#EAB308"; // yellow
    return "#F97316"; // orange
  };

  // Generate clinical notes
  const clinicalNotes: { text: string; severity: "info" | "warning" | "success" }[] = [];

  if (circadianData.avgDaylightMins !== null) {
    if (circadianData.avgDaylightMins < 30) {
      clinicalNotes.push({
        text: "Critical: Very low light exposure may significantly impact circadian rhythm",
        severity: "warning",
      });
    } else if (circadianData.avgDaylightMins < 60) {
      clinicalNotes.push({
        text: "Low light exposure may contribute to circadian misalignment",
        severity: "warning",
      });
    } else if (circadianData.avgDaylightMins >= 80) {
      clinicalNotes.push({
        text: "Adequate light exposure supporting circadian rhythm",
        severity: "success",
      });
    }
  }

  if (circadianData.avgMorningLightMins !== null && circadianData.avgMorningLightMins < 15) {
    clinicalNotes.push({
      text: "Minimal morning light exposure - consider morning light therapy",
      severity: "info",
    });
  }

  if (circadianData.avgTempDeviation !== null && Math.abs(circadianData.avgTempDeviation) > 0.5) {
    clinicalNotes.push({
      text: "Temperature variability may indicate circadian rhythm instability",
      severity: "info",
    });
  }

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-yellow-500/20 to-orange-500/20 flex items-center justify-center">
            <Sun className="w-4 h-4 text-yellow-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Circadian Signals</h3>
            <p className="text-xs text-gray-500">Light exposure & rhythm</p>
          </div>
        </div>

        {/* Time Range Selector */}
        <div className="flex items-center gap-1 bg-gray-700/50 rounded-lg p-0.5">
          {([7, 14] as const).map((days) => (
            <button
              key={days}
              onClick={() => setTimeRange(days)}
              className={`px-2 py-1 text-xs rounded-md transition-colors ${
                timeRange === days
                  ? "bg-yellow-600 text-white"
                  : "text-gray-400 hover:text-white"
              }`}
            >
              {days}d
            </button>
          ))}
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-4 gap-2 mb-4">
        {/* Circadian Score */}
        <div className={`p-2.5 rounded-lg ${getScoreBgColor(circadianData.avgCircadianScore)}`}>
          <div className="flex items-center justify-between mb-1">
            <span className="text-[10px] text-gray-400 uppercase tracking-wide">Score</span>
            {getTrendIcon(circadianData.trend)}
          </div>
          <div className={`text-lg font-bold ${getScoreColor(circadianData.avgCircadianScore)}`}>
            {circadianData.avgCircadianScore ?? "-"}
          </div>
        </div>

        {/* Avg Daylight */}
        <div className="p-2.5 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-1 mb-1">
            <Sun className="w-3 h-3 text-yellow-400" />
            <span className="text-[10px] text-gray-400 uppercase tracking-wide">Light</span>
          </div>
          <div className="flex items-baseline gap-0.5">
            <span className="text-lg font-bold text-white">
              {circadianData.avgDaylightMins ?? "-"}
            </span>
            <span className="text-[10px] text-gray-500">min</span>
          </div>
        </div>

        {/* Morning Light */}
        <div className="p-2.5 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-1 mb-1">
            <Sunrise className="w-3 h-3 text-orange-400" />
            <span className="text-[10px] text-gray-400 uppercase tracking-wide">AM</span>
          </div>
          <div className="flex items-baseline gap-0.5">
            <span className="text-lg font-bold text-white">
              {circadianData.avgMorningLightMins ?? "-"}
            </span>
            <span className="text-[10px] text-gray-500">min</span>
          </div>
        </div>

        {/* Outdoor Activity */}
        <div className="p-2.5 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-1 mb-1">
            <Activity className="w-3 h-3 text-green-400" />
            <span className="text-[10px] text-gray-400 uppercase tracking-wide">Out</span>
          </div>
          <div className="flex items-baseline gap-0.5">
            <span className="text-lg font-bold text-white">
              {circadianData.avgOutdoorMins ?? "-"}
            </span>
            <span className="text-[10px] text-gray-500">min</span>
          </div>
        </div>
      </div>

      {/* Light Exposure Chart */}
      <div className="h-28 mb-3">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={chartData} margin={{ top: 5, right: 5, bottom: 5, left: -10 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" vertical={false} />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 9, fill: "#9CA3AF" }}
              axisLine={{ stroke: "#374151" }}
              tickLine={false}
            />
            <YAxis
              tick={{ fontSize: 9, fill: "#9CA3AF" }}
              axisLine={false}
              tickLine={false}
              domain={[0, "auto"]}
              width={25}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "#1F2937",
                border: "1px solid #374151",
                borderRadius: "8px",
                fontSize: "11px",
              }}
              labelStyle={{ color: "#9CA3AF" }}
              formatter={(value: number, name: string) => [
                `${Math.round(value)} min`,
                name === "daylight" ? "Light Exposure" : name === "morning" ? "Morning Light" : name,
              ]}
            />
            <ReferenceLine
              y={90}
              stroke="#6B7280"
              strokeDasharray="4 4"
              label={{
                value: "Target",
                fill: "#6B7280",
                fontSize: 9,
                position: "right",
              }}
            />
            <Bar
              dataKey="daylight"
              fill="#FBBF24"
              radius={[3, 3, 0, 0]}
              name="daylight"
            />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Clinical Notes */}
      {clinicalNotes.length > 0 && (
        <div className="space-y-1.5 mb-3">
          {clinicalNotes.map((note, idx) => (
            <div
              key={idx}
              className={`px-2.5 py-1.5 rounded text-[11px] ${
                note.severity === "warning"
                  ? "bg-orange-500/10 text-orange-300"
                  : note.severity === "success"
                  ? "bg-green-500/10 text-green-300"
                  : "bg-blue-500/10 text-blue-300"
              }`}
            >
              {note.text}
            </div>
          ))}
        </div>
      )}

      {/* Temperature (if available) */}
      {circadianData.avgTempDeviation !== null && (
        <div className="flex items-center gap-2 px-2.5 py-1.5 bg-gray-700/20 rounded text-[11px]">
          <Thermometer className="w-3 h-3 text-cyan-400" />
          <span className="text-gray-400">Avg temp deviation:</span>
          <span className="text-white font-medium">
            {circadianData.avgTempDeviation > 0 ? "+" : ""}
            {circadianData.avgTempDeviation}°C
          </span>
        </div>
      )}

      {/* Data Coverage */}
      <div className="mt-3 flex items-center justify-between text-[10px] text-gray-500">
        <span>{circadianData.daysWithData} of {timeRange} days tracked</span>
        <span>iOS 17+ HealthKit</span>
      </div>
    </div>
  );
}
