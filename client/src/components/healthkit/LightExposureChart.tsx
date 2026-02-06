"use client";

import {
  AreaChart,
  Area,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
  ReferenceLine,
  ComposedChart,
} from "recharts";
import { Sun, AlertTriangle, AlertCircle } from "lucide-react";

interface CircadianDataPoint {
  date: string;
  daylightMins: number | null;
  morningLightMins: number | null;
  afternoonLightMins: number | null;
}

interface LightExposureChartProps {
  data: CircadianDataPoint[];
}

export function LightExposureChart({ data }: LightExposureChartProps) {
  const chartData = data.map((day) => ({
    date: day.date,
    shortDate: new Date(day.date).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
    }),
    morningLightMins: day.morningLightMins || 0,
    afternoonLightMins: day.afternoonLightMins || 0,
    totalDaylightMins: day.daylightMins || 0,
  }));

  const hasLightExposure = data.some((d) => d.daylightMins != null);
  const avgDaylight =
    chartData.reduce((sum, d) => sum + d.totalDaylightMins, 0) /
    (chartData.length || 1);

  if (!hasLightExposure) {
    return (
      <section className="bg-gray-800/50 rounded-xl p-4">
        <h3 className="text-white font-medium mb-4 flex items-center gap-2">
          <Sun className="w-5 h-5 text-yellow-400" />
          Light Exposure & Circadian Rhythm
        </h3>
        <div className="p-4 bg-amber-500/10 border border-amber-500/30 rounded-xl">
          <div className="flex items-center gap-3">
            <AlertCircle className="w-5 h-5 text-amber-400" />
            <div>
              <p className="text-sm font-medium text-amber-300">
                Limited Circadian Data
              </p>
              <p className="text-xs text-amber-400 mt-1">
                Daylight exposure tracking requires iOS 17+ / watchOS 10+
              </p>
            </div>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section className="bg-gray-800/50 rounded-xl p-4">
      <h3 className="text-white font-medium mb-4 flex items-center gap-2">
        <Sun className="w-5 h-5 text-yellow-400" />
        Light Exposure & Circadian Rhythm
      </h3>

      <ResponsiveContainer width="100%" height={250}>
        <ComposedChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
          <XAxis
            dataKey="shortDate"
            tick={{ fontSize: 11, fill: "#9CA3AF" }}
          />
          <YAxis
            tick={{ fontSize: 11, fill: "#9CA3AF" }}
            label={{
              value: "Minutes",
              angle: -90,
              position: "insideLeft",
            }}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: "#1F2937",
              border: "1px solid #374151",
            }}
          />
          <Legend />
          <ReferenceLine
            y={90}
            stroke="#6B7280"
            strokeDasharray="4 4"
            label="Target: 90 min"
          />
          <Area
            type="monotone"
            dataKey="morningLightMins"
            stackId="1"
            stroke="#F97316"
            fill="#F97316"
            fillOpacity={0.6}
            name="Morning"
          />
          <Area
            type="monotone"
            dataKey="afternoonLightMins"
            stackId="1"
            stroke="#FBBF24"
            fill="#FBBF24"
            fillOpacity={0.6}
            name="Afternoon"
          />
          <Line
            type="monotone"
            dataKey="totalDaylightMins"
            stroke="#EAB308"
            strokeWidth={3}
            name="Total Daylight"
          />
        </ComposedChart>
      </ResponsiveContainer>

      {avgDaylight < 30 && (
        <div className="mt-3 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
          <p className="text-sm text-red-300 flex items-center gap-2">
            <AlertTriangle className="w-4 h-4" />
            Critical: Very low light exposure may significantly impact circadian
            rhythm
          </p>
        </div>
      )}
    </section>
  );
}
