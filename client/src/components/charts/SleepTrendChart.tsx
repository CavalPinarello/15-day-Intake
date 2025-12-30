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
  perceivedEfficiency: number | null; // % from Sleep Log (subjective)
  perceptionDelta: number | null; // perceived - objective (+ = overestimates, - = underestimates)
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
    "Perceived Efficiency": point.perceivedEfficiency
      ? Math.round(point.perceivedEfficiency / 10)
      : null, // Scale 0-100% to 0-10
    "Bedtime Variance": point.bedtimeConsistency,
    "Wake Variance": point.wakeTimeConsistency,
    // Store raw values for tooltip
    rawObjectiveEfficiency: point.objectiveEfficiency,
    rawPerceivedEfficiency: point.perceivedEfficiency,
    perceptionDelta: point.perceptionDelta,
  }));

  // Calculate average perception gap for summary
  const deltaValues = data
    .map((p) => p.perceptionDelta)
    .filter((d): d is number => d !== null);
  const avgPerceptionGap =
    deltaValues.length > 0
      ? Math.round(deltaValues.reduce((a, b) => a + b, 0) / deltaValues.length)
      : null;

  return (
    <div className="w-full">
      {/* Perception gap summary stat */}
      {avgPerceptionGap !== null && (
        <div className="mb-2 flex items-center justify-end gap-2 text-sm">
          <span className="text-gray-400">Avg Perception Gap:</span>
          <span className={`font-medium ${avgPerceptionGap > 0 ? 'text-yellow-400' : avgPerceptionGap < 0 ? 'text-orange-400' : 'text-gray-400'}`}>
            {avgPerceptionGap > 0 ? `+${avgPerceptionGap}%` : `${avgPerceptionGap}%`}
            <span className="ml-1 text-xs text-gray-500">
              {avgPerceptionGap > 5 ? '(tends to overestimate)' : avgPerceptionGap < -5 ? '(tends to underestimate)' : '(accurate)'}
            </span>
          </span>
        </div>
      )}
      <div style={{ height }}>
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
            formatter={(value, name, props) => {
              // Show actual percentages for efficiency metrics
              if (name === "Sleep Efficiency" && props.payload.rawObjectiveEfficiency) {
                return [`${props.payload.rawObjectiveEfficiency}%`, "Objective Efficiency"];
              }
              if (name === "Perceived Efficiency" && props.payload.rawPerceivedEfficiency) {
                return [`${props.payload.rawPerceivedEfficiency}%`, "Perceived Efficiency"];
              }
              return [value, name];
            }}
            content={({ active, payload, label }) => {
              if (!active || !payload || payload.length === 0) return null;
              const data = payload[0].payload;
              const delta = data.perceptionDelta;
              const deltaLabel = delta !== null
                ? delta > 0
                  ? `+${delta}% (overestimates)`
                  : delta < 0
                    ? `${delta}% (underestimates)`
                    : "0% (accurate)"
                : null;

              return (
                <div className="bg-gray-800 border border-gray-700 rounded-lg p-3 text-sm">
                  <p className="text-gray-400 mb-2">{label}</p>
                  {data["Sleep Quality"] !== null && (
                    <p className="text-blue-400">Sleep Quality: {data["Sleep Quality"]}/10</p>
                  )}
                  {data.rawObjectiveEfficiency !== null && (
                    <p className="text-emerald-400">Objective Efficiency: {data.rawObjectiveEfficiency}%</p>
                  )}
                  {data.rawPerceivedEfficiency !== null && (
                    <p className="text-purple-400">Perceived Efficiency: {data.rawPerceivedEfficiency}%</p>
                  )}
                  {deltaLabel && (
                    <p className={`mt-1 pt-1 border-t border-gray-700 ${delta && delta > 0 ? 'text-yellow-400' : delta && delta < 0 ? 'text-orange-400' : 'text-gray-400'}`}>
                      Perception Gap: {deltaLabel}
                    </p>
                  )}
                </div>
              );
            }}
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

          {/* Objective sleep efficiency line (scaled) - from HealthKit/wearable */}
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

          {/* Perceived sleep efficiency line (scaled) - from Sleep Log */}
          <Line
            type="monotone"
            dataKey="Perceived Efficiency"
            stroke="#9333EA"
            strokeWidth={2}
            strokeDasharray="5 5"
            dot={{ fill: "#9333EA", strokeWidth: 2, r: 3 }}
            activeDot={{ r: 5, stroke: "#9333EA" }}
            connectNulls
          />
        </LineChart>
      </ResponsiveContainer>
      </div>
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
