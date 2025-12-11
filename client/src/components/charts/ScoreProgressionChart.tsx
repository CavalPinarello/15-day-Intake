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
  ReferenceArea,
} from "recharts";

interface ScoreDataPoint {
  day: number;
  date?: string;
  ISI?: number | null; // 0-28
  PHQ9?: number | null; // 0-27
  GAD7?: number | null; // 0-21
  ESS?: number | null; // 0-24
  PSQI?: number | null; // 0-21
}

interface ScoreProgressionChartProps {
  data: ScoreDataPoint[];
  scores?: ("ISI" | "PHQ9" | "GAD7" | "ESS" | "PSQI")[];
  height?: number;
  showThresholds?: boolean;
}

// Clinical thresholds for severity levels
const SCORE_CONFIG = {
  ISI: {
    name: "Insomnia (ISI)",
    color: "#8B5CF6",
    max: 28,
    thresholds: [
      { min: 0, max: 7, label: "No insomnia", color: "#10B981" },
      { min: 8, max: 14, label: "Subthreshold", color: "#F59E0B" },
      { min: 15, max: 21, label: "Moderate", color: "#F97316" },
      { min: 22, max: 28, label: "Severe", color: "#EF4444" },
    ],
  },
  PHQ9: {
    name: "Depression (PHQ-9)",
    color: "#EF4444",
    max: 27,
    thresholds: [
      { min: 0, max: 4, label: "Minimal", color: "#10B981" },
      { min: 5, max: 9, label: "Mild", color: "#F59E0B" },
      { min: 10, max: 14, label: "Moderate", color: "#F97316" },
      { min: 15, max: 19, label: "Mod. Severe", color: "#EF4444" },
      { min: 20, max: 27, label: "Severe", color: "#DC2626" },
    ],
  },
  GAD7: {
    name: "Anxiety (GAD-7)",
    color: "#F59E0B",
    max: 21,
    thresholds: [
      { min: 0, max: 4, label: "Minimal", color: "#10B981" },
      { min: 5, max: 9, label: "Mild", color: "#F59E0B" },
      { min: 10, max: 14, label: "Moderate", color: "#F97316" },
      { min: 15, max: 21, label: "Severe", color: "#EF4444" },
    ],
  },
  ESS: {
    name: "Sleepiness (ESS)",
    color: "#3B82F6",
    max: 24,
    thresholds: [
      { min: 0, max: 10, label: "Normal", color: "#10B981" },
      { min: 11, max: 24, label: "Excessive", color: "#EF4444" },
    ],
  },
  PSQI: {
    name: "Sleep Quality (PSQI)",
    color: "#10B981",
    max: 21,
    thresholds: [
      { min: 0, max: 5, label: "Good", color: "#10B981" },
      { min: 6, max: 21, label: "Poor", color: "#EF4444" },
    ],
  },
};

export function ScoreProgressionChart({
  data,
  scores = ["ISI", "PHQ9", "GAD7"],
  height = 350,
  showThresholds = true,
}: ScoreProgressionChartProps) {
  // Find the max value across all displayed scores for Y axis
  const maxY = Math.max(...scores.map((s) => SCORE_CONFIG[s].max));

  const chartData = data.map((point) => ({
    day: `Day ${point.day}`,
    dayNum: point.day,
    ISI: point.ISI,
    PHQ9: point.PHQ9,
    GAD7: point.GAD7,
    ESS: point.ESS,
    PSQI: point.PSQI,
  }));

  return (
    <div className="w-full" style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <LineChart
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
            domain={[0, maxY]}
            tick={{ fill: "#9CA3AF", fontSize: 12 }}
            tickLine={{ stroke: "#4B5563" }}
            axisLine={{ stroke: "#4B5563" }}
            label={{
              value: "Score",
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
            formatter={(value: number, name: string) => {
              const config = SCORE_CONFIG[name as keyof typeof SCORE_CONFIG];
              if (!config) return [value, name];
              const threshold = config.thresholds.find(
                (t) => value >= t.min && value <= t.max
              );
              return [
                <span key={name}>
                  {value} <span style={{ color: threshold?.color }}>({threshold?.label})</span>
                </span>,
                config.name,
              ];
            }}
          />
          <Legend
            wrapperStyle={{ paddingTop: "10px" }}
            formatter={(value) => {
              const config = SCORE_CONFIG[value as keyof typeof SCORE_CONFIG];
              return (
                <span style={{ color: config?.color || "#D1D5DB" }}>
                  {config?.name || value}
                </span>
              );
            }}
          />

          {/* Clinical threshold reference lines */}
          {showThresholds && scores.includes("ISI") && (
            <ReferenceLine
              y={15}
              stroke="#F97316"
              strokeDasharray="3 3"
              strokeOpacity={0.5}
            />
          )}
          {showThresholds && scores.includes("PHQ9") && (
            <ReferenceLine
              y={10}
              stroke="#EF4444"
              strokeDasharray="3 3"
              strokeOpacity={0.5}
            />
          )}
          {showThresholds && scores.includes("GAD7") && (
            <ReferenceLine
              y={10}
              stroke="#F59E0B"
              strokeDasharray="3 3"
              strokeOpacity={0.5}
            />
          )}

          {/* Score lines */}
          {scores.includes("ISI") && (
            <Line
              type="monotone"
              dataKey="ISI"
              stroke={SCORE_CONFIG.ISI.color}
              strokeWidth={2}
              dot={{ fill: SCORE_CONFIG.ISI.color, strokeWidth: 2, r: 4 }}
              activeDot={{ r: 6 }}
              connectNulls
            />
          )}
          {scores.includes("PHQ9") && (
            <Line
              type="monotone"
              dataKey="PHQ9"
              stroke={SCORE_CONFIG.PHQ9.color}
              strokeWidth={2}
              dot={{ fill: SCORE_CONFIG.PHQ9.color, strokeWidth: 2, r: 4 }}
              activeDot={{ r: 6 }}
              connectNulls
            />
          )}
          {scores.includes("GAD7") && (
            <Line
              type="monotone"
              dataKey="GAD7"
              stroke={SCORE_CONFIG.GAD7.color}
              strokeWidth={2}
              dot={{ fill: SCORE_CONFIG.GAD7.color, strokeWidth: 2, r: 4 }}
              activeDot={{ r: 6 }}
              connectNulls
            />
          )}
          {scores.includes("ESS") && (
            <Line
              type="monotone"
              dataKey="ESS"
              stroke={SCORE_CONFIG.ESS.color}
              strokeWidth={2}
              dot={{ fill: SCORE_CONFIG.ESS.color, strokeWidth: 2, r: 4 }}
              activeDot={{ r: 6 }}
              connectNulls
            />
          )}
          {scores.includes("PSQI") && (
            <Line
              type="monotone"
              dataKey="PSQI"
              stroke={SCORE_CONFIG.PSQI.color}
              strokeWidth={2}
              dot={{ fill: SCORE_CONFIG.PSQI.color, strokeWidth: 2, r: 4 }}
              activeDot={{ r: 6 }}
              connectNulls
            />
          )}
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

// Score gauge component for individual scores
interface ScoreGaugeProps {
  score: number;
  type: keyof typeof SCORE_CONFIG;
  showTrend?: "up" | "down" | "stable" | null;
}

export function ScoreGauge({ score, type, showTrend }: ScoreGaugeProps) {
  const config = SCORE_CONFIG[type];
  const threshold = config.thresholds.find(
    (t) => score >= t.min && score <= t.max
  );
  const percentage = (score / config.max) * 100;

  const trendIcon = showTrend === "up" ? "↑" : showTrend === "down" ? "↓" : "→";
  const trendColor =
    type === "PSQI" || type === "ESS"
      ? showTrend === "down"
        ? "#10B981"
        : showTrend === "up"
        ? "#EF4444"
        : "#9CA3AF"
      : showTrend === "down"
      ? "#10B981"
      : showTrend === "up"
      ? "#EF4444"
      : "#9CA3AF";

  return (
    <div className="flex flex-col items-center p-3 bg-gray-800/50 rounded-lg">
      <div className="text-xs text-gray-400 mb-1">{config.name}</div>
      <div className="flex items-center gap-2">
        <span className="text-2xl font-bold" style={{ color: config.color }}>
          {score}
        </span>
        <span className="text-xs text-gray-500">/ {config.max}</span>
        {showTrend && (
          <span className="text-lg" style={{ color: trendColor }}>
            {trendIcon}
          </span>
        )}
      </div>
      <div className="w-full h-2 bg-gray-700 rounded-full mt-2 overflow-hidden">
        <div
          className="h-full rounded-full transition-all duration-500"
          style={{
            width: `${percentage}%`,
            backgroundColor: threshold?.color || config.color,
          }}
        />
      </div>
      <div
        className="text-xs mt-1 font-medium"
        style={{ color: threshold?.color }}
      >
        {threshold?.label}
      </div>
    </div>
  );
}

export { SCORE_CONFIG };
