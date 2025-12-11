"use client";

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
  ReferenceLine,
} from "recharts";

interface ComplianceDataPoint {
  date: string;
  day: number;
  tasksCompleted: number;
  tasksTotal: number;
  sleepLogCompleted: boolean;
  assessmentCompleted: boolean;
}

interface ComplianceChartProps {
  data: ComplianceDataPoint[];
  height?: number;
  showTarget?: boolean;
  targetPercentage?: number;
}

const getComplianceColor = (percentage: number) => {
  if (percentage >= 90) return "#10B981"; // Green - Excellent
  if (percentage >= 70) return "#F59E0B"; // Amber - Good
  if (percentage >= 50) return "#F97316"; // Orange - Fair
  return "#EF4444"; // Red - Poor
};

export function ComplianceChart({
  data,
  height = 200,
  showTarget = true,
  targetPercentage = 80,
}: ComplianceChartProps) {
  const chartData = data.map((point) => {
    const percentage =
      point.tasksTotal > 0
        ? Math.round((point.tasksCompleted / point.tasksTotal) * 100)
        : 0;
    return {
      day: `Day ${point.day}`,
      date: point.date,
      percentage,
      completed: point.tasksCompleted,
      total: point.tasksTotal,
      sleepLog: point.sleepLogCompleted,
      assessment: point.assessmentCompleted,
    };
  });

  return (
    <div className="w-full" style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={chartData}
          margin={{ top: 10, right: 10, left: 0, bottom: 5 }}
        >
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
          <XAxis
            dataKey="day"
            tick={{ fill: "#9CA3AF", fontSize: 11 }}
            tickLine={{ stroke: "#4B5563" }}
            axisLine={{ stroke: "#4B5563" }}
          />
          <YAxis
            domain={[0, 100]}
            tick={{ fill: "#9CA3AF", fontSize: 11 }}
            tickLine={{ stroke: "#4B5563" }}
            axisLine={{ stroke: "#4B5563" }}
            tickFormatter={(value) => `${value}%`}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: "#1F2937",
              border: "1px solid #374151",
              borderRadius: "8px",
              color: "#F9FAFB",
            }}
            labelStyle={{ color: "#9CA3AF" }}
            formatter={(value: number, name: string, props: any) => {
              const { payload } = props;
              return [
                <div key="tooltip" className="space-y-1">
                  <div className="font-medium">{value}% Complete</div>
                  <div className="text-xs text-gray-400">
                    {payload.completed}/{payload.total} tasks
                  </div>
                  <div className="flex gap-2 text-xs mt-1">
                    <span
                      className={
                        payload.sleepLog ? "text-green-400" : "text-gray-500"
                      }
                    >
                      {payload.sleepLog ? "✓" : "○"} Sleep Log
                    </span>
                    <span
                      className={
                        payload.assessment ? "text-green-400" : "text-gray-500"
                      }
                    >
                      {payload.assessment ? "✓" : "○"} Assessment
                    </span>
                  </div>
                </div>,
                "",
              ];
            }}
          />

          {/* Target line */}
          {showTarget && (
            <ReferenceLine
              y={targetPercentage}
              stroke="#10B981"
              strokeDasharray="5 5"
              strokeOpacity={0.7}
              label={{
                value: `Target ${targetPercentage}%`,
                position: "right",
                fill: "#10B981",
                fontSize: 10,
              }}
            />
          )}

          <Bar dataKey="percentage" radius={[4, 4, 0, 0]}>
            {chartData.map((entry, index) => (
              <Cell
                key={`cell-${index}`}
                fill={getComplianceColor(entry.percentage)}
              />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

// Streak indicator component
interface StreakIndicatorProps {
  currentStreak: number;
  longestStreak: number;
  last7Days: boolean[];
}

export function StreakIndicator({
  currentStreak,
  longestStreak,
  last7Days,
}: StreakIndicatorProps) {
  return (
    <div className="flex flex-col gap-3">
      {/* Streak stats */}
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-2">
          <span className="text-2xl">🔥</span>
          <div>
            <div className="text-lg font-bold text-white">{currentStreak}</div>
            <div className="text-xs text-gray-400">Current Streak</div>
          </div>
        </div>
        <div className="text-right">
          <div className="text-lg font-medium text-gray-300">
            {longestStreak}
          </div>
          <div className="text-xs text-gray-400">Best Streak</div>
        </div>
      </div>

      {/* Last 7 days dots */}
      <div className="flex justify-between gap-1">
        {last7Days.map((completed, i) => (
          <div
            key={i}
            className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium ${
              completed
                ? "bg-green-500/20 text-green-400 border border-green-500/50"
                : "bg-gray-700/50 text-gray-500 border border-gray-600"
            }`}
          >
            {completed ? "✓" : "−"}
          </div>
        ))}
      </div>

      {/* Day labels */}
      <div className="flex justify-between gap-1">
        {["M", "T", "W", "T", "F", "S", "S"].map((day, i) => (
          <div key={i} className="w-8 text-center text-xs text-gray-500">
            {day}
          </div>
        ))}
      </div>
    </div>
  );
}

// Compact compliance summary
interface ComplianceSummaryProps {
  overallPercentage: number;
  sleepLogRate: number;
  assessmentRate: number;
  interventionRate: number;
}

export function ComplianceSummary({
  overallPercentage,
  sleepLogRate,
  assessmentRate,
  interventionRate,
}: ComplianceSummaryProps) {
  const items = [
    { label: "Sleep Log", rate: sleepLogRate, icon: "📝" },
    { label: "Assessment", rate: assessmentRate, icon: "📋" },
    { label: "Interventions", rate: interventionRate, icon: "💊" },
  ];

  return (
    <div className="space-y-3">
      {/* Overall percentage */}
      <div className="flex items-center justify-between">
        <span className="text-sm text-gray-400">Overall Compliance</span>
        <span
          className="text-xl font-bold"
          style={{ color: getComplianceColor(overallPercentage) }}
        >
          {overallPercentage}%
        </span>
      </div>

      {/* Progress bar */}
      <div className="w-full h-3 bg-gray-700 rounded-full overflow-hidden">
        <div
          className="h-full rounded-full transition-all duration-500"
          style={{
            width: `${overallPercentage}%`,
            backgroundColor: getComplianceColor(overallPercentage),
          }}
        />
      </div>

      {/* Breakdown */}
      <div className="grid grid-cols-3 gap-2 pt-2">
        {items.map((item) => (
          <div
            key={item.label}
            className="text-center p-2 bg-gray-800/50 rounded-lg"
          >
            <div className="text-lg">{item.icon}</div>
            <div
              className="text-sm font-medium"
              style={{ color: getComplianceColor(item.rate) }}
            >
              {item.rate}%
            </div>
            <div className="text-xs text-gray-500">{item.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
