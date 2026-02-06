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
} from "recharts";
import { Heart } from "lucide-react";

interface HeartRateDataPoint {
  date: string;
  restingHr: number | null;
  avgHr: number | null;
  hrvMorning: number | null;
  hrvAvg: number | null;
}

interface HeartRateHRVChartProps {
  data: HeartRateDataPoint[];
}

export function HeartRateHRVChart({ data }: HeartRateHRVChartProps) {
  const chartData = data.map((day) => ({
    date: day.date,
    shortDate: new Date(day.date).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
    }),
    restingHr: day.restingHr,
    hrvMorning: day.hrvMorning,
  }));

  const hasHRV = data.some((d) => d.hrvMorning != null);
  const hasHeartRate = data.some((d) => d.restingHr != null);

  if (!hasHeartRate) {
    return (
      <section className="bg-gray-800/50 rounded-xl p-4">
        <h3 className="text-white font-medium mb-4 flex items-center gap-2">
          <Heart className="w-5 h-5 text-red-400" />
          Heart Rate & HRV
        </h3>
        <div className="h-[250px] flex flex-col items-center justify-center text-gray-500">
          <Heart className="w-12 h-12 mb-2 text-gray-600" />
          <p className="text-sm">No heart rate data available</p>
          <p className="text-xs text-gray-600 mt-1">
            Requires Apple Watch or compatible device
          </p>
        </div>
      </section>
    );
  }

  return (
    <section className="bg-gray-800/50 rounded-xl p-4">
      <h3 className="text-white font-medium mb-4 flex items-center gap-2">
        <Heart className="w-5 h-5 text-red-400" />
        Heart Rate & HRV
      </h3>

      <ResponsiveContainer width="100%" height={250}>
        <LineChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
          <XAxis
            dataKey="shortDate"
            tick={{ fontSize: 11, fill: "#9CA3AF" }}
          />
          <YAxis
            yAxisId="hr"
            domain={[50, 80]}
            tick={{ fontSize: 11, fill: "#9CA3AF" }}
            label={{
              value: "HR (bpm)",
              angle: -90,
              position: "insideLeft",
              fill: "#9CA3AF",
            }}
          />
          {hasHRV && (
            <YAxis
              yAxisId="hrv"
              orientation="right"
              domain={[0, 100]}
              tick={{ fontSize: 11, fill: "#9CA3AF" }}
              label={{
                value: "HRV (ms)",
                angle: 90,
                position: "insideRight",
                fill: "#9CA3AF",
              }}
            />
          )}
          <Tooltip
            contentStyle={{
              backgroundColor: "#1F2937",
              border: "1px solid #374151",
            }}
          />
          <Legend />
          <Line
            yAxisId="hr"
            type="monotone"
            dataKey="restingHr"
            stroke="#EF4444"
            name="Resting HR"
            strokeWidth={2}
          />
          {hasHRV && (
            <Line
              yAxisId="hrv"
              type="monotone"
              dataKey="hrvMorning"
              stroke="#8B5CF6"
              name="Morning HRV"
              strokeWidth={2}
            />
          )}
        </LineChart>
      </ResponsiveContainer>
    </section>
  );
}
