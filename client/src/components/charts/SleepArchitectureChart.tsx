"use client";

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  Cell,
} from "recharts";

interface SleepStageData {
  date: string;
  day: number;
  deep: number; // minutes
  light: number; // minutes
  rem: number; // minutes
  awake: number; // minutes
  totalSleep: number; // minutes
}

interface SleepArchitectureChartProps {
  data: SleepStageData[];
  height?: number;
  showPercentage?: boolean;
}

const STAGE_COLORS = {
  deep: "#1E40AF", // Dark blue
  light: "#60A5FA", // Light blue
  rem: "#8B5CF6", // Purple
  awake: "#F87171", // Red
};

const STAGE_NAMES = {
  deep: "Deep Sleep",
  light: "Light Sleep",
  rem: "REM Sleep",
  awake: "Awake",
};

export function SleepArchitectureChart({
  data,
  height = 300,
  showPercentage = true,
}: SleepArchitectureChartProps) {
  // Transform data for stacked bar chart
  const chartData = data.map((point) => {
    const total = point.deep + point.light + point.rem + point.awake;
    if (showPercentage) {
      return {
        day: `Day ${point.day}`,
        date: point.date,
        Deep: total > 0 ? Math.round((point.deep / total) * 100) : 0,
        Light: total > 0 ? Math.round((point.light / total) * 100) : 0,
        REM: total > 0 ? Math.round((point.rem / total) * 100) : 0,
        Awake: total > 0 ? Math.round((point.awake / total) * 100) : 0,
        totalMinutes: total,
      };
    }
    return {
      day: `Day ${point.day}`,
      date: point.date,
      Deep: Math.round(point.deep / 60 * 10) / 10, // Convert to hours
      Light: Math.round(point.light / 60 * 10) / 10,
      REM: Math.round(point.rem / 60 * 10) / 10,
      Awake: Math.round(point.awake / 60 * 10) / 10,
      totalMinutes: point.deep + point.light + point.rem + point.awake,
    };
  });

  const formatTooltip = (value: number, name: string) => {
    if (showPercentage) {
      return [`${value}%`, name];
    }
    return [`${value}h`, name];
  };

  return (
    <div className="w-full" style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={chartData}
          margin={{ top: 20, right: 30, left: 0, bottom: 5 }}
        >
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
          <XAxis
            dataKey="day"
            tick={{ fill: "#9CA3AF", fontSize: 12 }}
            tickLine={{ stroke: "#4B5563" }}
            axisLine={{ stroke: "#4B5563" }}
          />
          <YAxis
            tick={{ fill: "#9CA3AF", fontSize: 12 }}
            tickLine={{ stroke: "#4B5563" }}
            axisLine={{ stroke: "#4B5563" }}
            label={{
              value: showPercentage ? "Percentage" : "Hours",
              angle: -90,
              position: "insideLeft",
              fill: "#9CA3AF",
              fontSize: 12,
            }}
            domain={showPercentage ? [0, 100] : [0, "auto"]}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: "#1F2937",
              border: "1px solid #374151",
              borderRadius: "8px",
              color: "#F9FAFB",
            }}
            labelStyle={{ color: "#9CA3AF" }}
            formatter={formatTooltip}
          />
          <Legend
            wrapperStyle={{ paddingTop: "10px" }}
            formatter={(value) => (
              <span style={{ color: "#D1D5DB" }}>{value}</span>
            )}
          />
          <Bar dataKey="Deep" stackId="a" fill={STAGE_COLORS.deep} />
          <Bar dataKey="Light" stackId="a" fill={STAGE_COLORS.light} />
          <Bar dataKey="REM" stackId="a" fill={STAGE_COLORS.rem} />
          <Bar dataKey="Awake" stackId="a" fill={STAGE_COLORS.awake} radius={[4, 4, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

// Single night breakdown component
interface SleepBreakdownProps {
  data: SleepStageData;
}

export function SleepBreakdown({ data }: SleepBreakdownProps) {
  const total = data.deep + data.light + data.rem + data.awake;
  const stages = [
    { key: "deep", value: data.deep, color: STAGE_COLORS.deep, name: "Deep" },
    { key: "light", value: data.light, color: STAGE_COLORS.light, name: "Light" },
    { key: "rem", value: data.rem, color: STAGE_COLORS.rem, name: "REM" },
    { key: "awake", value: data.awake, color: STAGE_COLORS.awake, name: "Awake" },
  ];

  const formatTime = (minutes: number) => {
    const hours = Math.floor(minutes / 60);
    const mins = Math.round(minutes % 60);
    return `${hours}h ${mins}m`;
  };

  return (
    <div className="space-y-3">
      {/* Total sleep time */}
      <div className="text-center pb-2 border-b border-gray-700">
        <div className="text-sm text-gray-400">Total Time</div>
        <div className="text-2xl font-bold text-white">{formatTime(total)}</div>
      </div>

      {/* Stage breakdown bar */}
      <div className="flex h-4 rounded-full overflow-hidden">
        {stages.map((stage) => (
          <div
            key={stage.key}
            style={{
              width: `${total > 0 ? (stage.value / total) * 100 : 0}%`,
              backgroundColor: stage.color,
            }}
            className="transition-all duration-300"
          />
        ))}
      </div>

      {/* Stage details */}
      <div className="grid grid-cols-2 gap-2">
        {stages.map((stage) => {
          const percentage = total > 0 ? Math.round((stage.value / total) * 100) : 0;
          return (
            <div key={stage.key} className="flex items-center gap-2">
              <div
                className="w-3 h-3 rounded-full"
                style={{ backgroundColor: stage.color }}
              />
              <div className="flex-1">
                <div className="text-xs text-gray-400">{stage.name}</div>
                <div className="text-sm font-medium text-white">
                  {formatTime(stage.value)}{" "}
                  <span className="text-gray-500">({percentage}%)</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Ideal ranges note */}
      <div className="text-xs text-gray-500 pt-2 border-t border-gray-700">
        Ideal: Deep 15-20%, REM 20-25%, Light 50-55%
      </div>
    </div>
  );
}

export { STAGE_COLORS, STAGE_NAMES };
