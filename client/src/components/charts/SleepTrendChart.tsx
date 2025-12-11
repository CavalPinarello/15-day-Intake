"use client";

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ReferenceLine,
} from "recharts";

interface SleepDataPoint {
  day: number;
  subjectiveQuality: number | null; // 1-10 from Sleep Log
  objectiveEfficiency: number | null; // % from HealthKit
  bedtimeConsistency: number | null; // deviation in minutes
  wakeTimeConsistency: number | null; // deviation in minutes
}

interface SleepTrendChartProps {
  data: SleepDataPoint[];
  showObjective?: boolean;
  height?: number;
}

export function SleepTrendChart({
  data,
  showObjective = true,
  height = 300,
}: SleepTrendChartProps) {
  // Transform data for chart display
  const chartData = data.map((point) => ({
    day: `Day ${point.day}`,
    dayNum: point.day,
    "Sleep Quality": point.subjectiveQuality,
    "Sleep Efficiency": point.objectiveEfficiency
      ? Math.round(point.objectiveEfficiency / 10)
      : null, // Scale to 0-10
    "Bedtime Variance": point.bedtimeConsistency,
    "Wake Variance": point.wakeTimeConsistency,
  }));

  return (
    <div className="w-full" style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <LineChart
          data={chartData}
          margin={{ top: 5, right: 30, left: 0, bottom: 5 }}
        >
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
          <XAxis
            dataKey="day"
            tick={{ fill: "#9CA3AF", fontSize: 12 }}
            tickLine={{ stroke: "#4B5563" }}
            axisLine={{ stroke: "#4B5563" }}
          />
          <YAxis
            domain={[0, 10]}
            tick={{ fill: "#9CA3AF", fontSize: 12 }}
            tickLine={{ stroke: "#4B5563" }}
            axisLine={{ stroke: "#4B5563" }}
            label={{
              value: "Quality (1-10)",
              angle: -90,
              position: "insideLeft",
              fill: "#9CA3AF",
              fontSize: 12,
            }}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: "#1F2937",
              border: "1px solid #374151",
              borderRadius: "8px",
              color: "#F9FAFB",
            }}
            labelStyle={{ color: "#9CA3AF" }}
          />
          <Legend
            wrapperStyle={{ paddingTop: "10px" }}
            formatter={(value) => (
              <span style={{ color: "#D1D5DB" }}>{value}</span>
            )}
          />

          {/* Clinical threshold lines */}
          <ReferenceLine
            y={7}
            stroke="#10B981"
            strokeDasharray="5 5"
            label={{
              value: "Good",
              position: "right",
              fill: "#10B981",
              fontSize: 10,
            }}
          />
          <ReferenceLine
            y={5}
            stroke="#F59E0B"
            strokeDasharray="5 5"
            label={{
              value: "Fair",
              position: "right",
              fill: "#F59E0B",
              fontSize: 10,
            }}
          />

          {/* Subjective sleep quality line */}
          <Line
            type="monotone"
            dataKey="Sleep Quality"
            stroke="#3B82F6"
            strokeWidth={2}
            dot={{ fill: "#3B82F6", strokeWidth: 2, r: 4 }}
            activeDot={{ r: 6, fill: "#60A5FA" }}
            connectNulls
          />

          {/* Objective sleep efficiency line (scaled) */}
          {showObjective && (
            <Line
              type="monotone"
              dataKey="Sleep Efficiency"
              stroke="#10B981"
              strokeWidth={2}
              strokeDasharray="5 5"
              dot={{ fill: "#10B981", strokeWidth: 2, r: 4 }}
              activeDot={{ r: 6, fill: "#34D399" }}
              connectNulls
            />
          )}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

// Mini version for dashboard cards
export function SleepTrendMini({
  data,
  height = 120,
}: {
  data: SleepDataPoint[];
  height?: number;
}) {
  const chartData = data.slice(-7).map((point) => ({
    day: point.day,
    quality: point.subjectiveQuality,
  }));

  return (
    <div className="w-full" style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={chartData} margin={{ top: 5, right: 5, left: 5, bottom: 5 }}>
          <Line
            type="monotone"
            dataKey="quality"
            stroke="#3B82F6"
            strokeWidth={2}
            dot={false}
            connectNulls
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
