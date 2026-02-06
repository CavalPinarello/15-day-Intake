"use client";

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
  ReferenceLine,
} from "recharts";
import { Moon, Info } from "lucide-react";

interface SleepDataPoint {
  date: string;
  totalSleepMins: number | null;
  efficiency: number | null;
  deepSleepMins: number | null;
  remSleepMins: number | null;
  lightSleepMins: number | null;
  primarySource?: string | null;
}

interface SleepMetricsChartProps {
  data: SleepDataPoint[];
  timeRange: 7 | 14 | 30 | 90;
}

export function SleepMetricsChart({ data, timeRange }: SleepMetricsChartProps) {
  const chartData = data.map((day) => ({
    date: day.date,
    shortDate: new Date(day.date).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
    }),
    totalSleepHours: day.totalSleepMins ? day.totalSleepMins / 60 : null,
    efficiency: day.efficiency,
    deepSleepHours: day.deepSleepMins ? day.deepSleepMins / 60 : null,
    remSleepHours: day.remSleepMins ? day.remSleepMins / 60 : null,
  }));

  const hasDeepSleep = data.some((d) => d.deepSleepMins != null);

  return (
    <section className="bg-gray-800/50 rounded-xl p-4">
      <h3 className="text-white font-medium mb-4 flex items-center gap-2">
        <Moon className="w-5 h-5 text-blue-400" />
        Sleep Metrics
      </h3>

      <ResponsiveContainer width="100%" height={300}>
        <LineChart
          data={chartData}
          margin={{ top: 5, right: 30, left: 0, bottom: 5 }}
        >
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
          <XAxis
            dataKey="shortDate"
            tick={{ fontSize: 11, fill: "#9CA3AF" }}
          />
          <YAxis
            yAxisId="hours"
            tick={{ fontSize: 11, fill: "#9CA3AF" }}
            label={{
              value: "Hours",
              angle: -90,
              position: "insideLeft",
              fill: "#9CA3AF",
            }}
          />
          <YAxis
            yAxisId="percent"
            orientation="right"
            tick={{ fontSize: 11, fill: "#9CA3AF" }}
            label={{
              value: "Efficiency %",
              angle: 90,
              position: "insideRight",
              fill: "#9CA3AF",
            }}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: "#1F2937",
              border: "1px solid #374151",
              borderRadius: "8px",
            }}
            labelStyle={{ color: "#9CA3AF" }}
          />
          <Legend />
          <ReferenceLine
            y={7}
            yAxisId="hours"
            stroke="#6B7280"
            strokeDasharray="4 4"
            label="Target"
          />
          <Line
            yAxisId="hours"
            type="monotone"
            dataKey="totalSleepHours"
            stroke="#3B82F6"
            name="Total Sleep"
            strokeWidth={2}
            dot={{ r: 3 }}
          />
          <Line
            yAxisId="percent"
            type="monotone"
            dataKey="efficiency"
            stroke="#10B981"
            name="Efficiency"
            strokeWidth={2}
            dot={{ r: 3 }}
          />
          {hasDeepSleep && (
            <>
              <Line
                yAxisId="hours"
                type="monotone"
                dataKey="deepSleepHours"
                stroke="#8B5CF6"
                name="Deep Sleep"
                strokeWidth={2}
                dot={{ r: 3 }}
              />
              <Line
                yAxisId="hours"
                type="monotone"
                dataKey="remSleepHours"
                stroke="#F59E0B"
                name="REM Sleep"
                strokeWidth={2}
                dot={{ r: 3 }}
              />
            </>
          )}
        </LineChart>
      </ResponsiveContainer>

      {!hasDeepSleep && (
        <div className="text-xs text-gray-500 flex items-center gap-2 mt-2">
          <Info className="w-4 h-4" />
          Sleep stage data not available from this device. Showing total sleep and
          efficiency only.
        </div>
      )}
    </section>
  );
}
