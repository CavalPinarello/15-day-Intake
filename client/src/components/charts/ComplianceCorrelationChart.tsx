"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useMemo } from "react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
  Area,
  ComposedChart,
  Bar,
} from "recharts";
import { TrendingUp, TrendingDown, Minus, Activity, AlertCircle } from "lucide-react";

interface ComplianceCorrelationChartProps {
  userId: Id<"users">;
  height?: number;
}

interface CorrelationDataPoint {
  date: string;
  week: number;
  compliancePct: number;
  isiScore: number | null;
  sleepEfficiency: number | null;
}

export function ComplianceCorrelationChart({
  userId,
  height = 200,
}: ComplianceCorrelationChartProps) {
  // Fetch correlation data from Convex
  const correlationData = useQuery(api.outcomeCorrelation.getCorrelationData, {
    userId,
  });

  // Transform data for chart
  const chartData = useMemo(() => {
    if (!correlationData) return [];

    return correlationData.map((point: {
      computation_date: string;
      overall_compliance_pct: number;
      isi_score_end?: number | null;
      avg_sleep_efficiency_end?: number | null;
    }, idx: number) => ({
      week: idx + 1,
      date: point.computation_date,
      compliance: point.overall_compliance_pct,
      isi: point.isi_score_end,
      efficiency: point.avg_sleep_efficiency_end,
    }));
  }, [correlationData]);

  // Calculate correlation strength
  const correlationStrength = useMemo(() => {
    if (!correlationData || correlationData.length < 2) return null;

    const last = correlationData[correlationData.length - 1];
    if (last.compliance_improvement_correlation !== undefined) {
      const corr = last.compliance_improvement_correlation;
      if (corr >= 0.7) return { strength: "Strong", color: "text-green-400" };
      if (corr >= 0.4) return { strength: "Moderate", color: "text-amber-400" };
      if (corr >= 0.2) return { strength: "Weak", color: "text-orange-400" };
      return { strength: "None", color: "text-gray-400" };
    }
    return null;
  }, [correlationData]);

  // Calculate ISI change
  const isiChange = useMemo(() => {
    if (!correlationData || correlationData.length === 0) return null;

    const first = correlationData[0];
    const last = correlationData[correlationData.length - 1];

    if (first.isi_score_start && last.isi_score_end) {
      const change = last.isi_score_end - first.isi_score_start;
      return {
        value: Math.abs(change),
        improved: change < 0,
        percentage: Math.round((Math.abs(change) / first.isi_score_start) * 100),
      };
    }
    return null;
  }, [correlationData]);

  // Calculate compliance trend
  const complianceTrend = useMemo(() => {
    if (!chartData || chartData.length < 2) return null;

    const firstHalf = chartData.slice(0, Math.floor(chartData.length / 2));
    const secondHalf = chartData.slice(Math.floor(chartData.length / 2));

    const firstAvg =
      firstHalf.reduce((sum: number, d: { compliance: number }) => sum + d.compliance, 0) / firstHalf.length;
    const secondAvg =
      secondHalf.reduce((sum: number, d: { compliance: number }) => sum + d.compliance, 0) / secondHalf.length;

    const change = secondAvg - firstAvg;
    return {
      direction: change > 5 ? "up" : change < -5 ? "down" : "stable",
      value: Math.abs(change).toFixed(0),
    };
  }, [chartData]);

  if (!correlationData) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="animate-pulse">
          <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
          <div className="h-[200px] bg-gray-700/50 rounded"></div>
        </div>
      </div>
    );
  }

  if (chartData.length === 0) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="flex items-center gap-2 mb-4">
          <div className="w-8 h-8 rounded-lg bg-blue-500/20 flex items-center justify-center">
            <Activity className="w-4 h-4 text-blue-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Compliance vs Outcomes</h3>
            <p className="text-xs text-gray-500">Treatment effectiveness correlation</p>
          </div>
        </div>
        <div className="h-[200px] flex items-center justify-center">
          <div className="text-center">
            <AlertCircle className="w-8 h-8 text-gray-500 mx-auto mb-2" />
            <p className="text-sm text-gray-400">Not enough data yet</p>
            <p className="text-xs text-gray-500">Correlation requires at least 2 weeks of data</p>
          </div>
        </div>
      </div>
    );
  }

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-gray-800 border border-gray-700 rounded-lg p-3 shadow-lg">
          <p className="text-xs text-gray-400 mb-1">Week {label}</p>
          {payload.map((entry: any, index: number) => (
            <div key={index} className="flex items-center gap-2">
              <div
                className="w-2 h-2 rounded-full"
                style={{ backgroundColor: entry.color }}
              />
              <span className="text-xs text-gray-300">
                {entry.name}: {entry.value?.toFixed(1)}
                {entry.name === "Compliance" || entry.name === "Efficiency" ? "%" : ""}
              </span>
            </div>
          ))}
        </div>
      );
    }
    return null;
  };

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-blue-500/20 flex items-center justify-center">
            <Activity className="w-4 h-4 text-blue-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Compliance vs Outcomes</h3>
            <p className="text-xs text-gray-500">Treatment effectiveness correlation</p>
          </div>
        </div>
        {correlationStrength && (
          <span className={`text-xs ${correlationStrength.color}`}>
            {correlationStrength.strength} correlation
          </span>
        )}
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-3 gap-2 mb-4">
        {/* Compliance Trend */}
        <div className="p-2 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-1 mb-1">
            {complianceTrend?.direction === "up" ? (
              <TrendingUp className="w-3 h-3 text-green-400" />
            ) : complianceTrend?.direction === "down" ? (
              <TrendingDown className="w-3 h-3 text-red-400" />
            ) : (
              <Minus className="w-3 h-3 text-gray-400" />
            )}
            <span className="text-[10px] text-gray-400">Compliance</span>
          </div>
          <span className="text-sm font-medium text-white">
            {complianceTrend ? `${complianceTrend.direction === "down" ? "-" : "+"}${complianceTrend.value}%` : "—"}
          </span>
        </div>

        {/* ISI Change */}
        <div className="p-2 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-1 mb-1">
            {isiChange?.improved ? (
              <TrendingDown className="w-3 h-3 text-green-400" />
            ) : isiChange ? (
              <TrendingUp className="w-3 h-3 text-red-400" />
            ) : (
              <Minus className="w-3 h-3 text-gray-400" />
            )}
            <span className="text-[10px] text-gray-400">ISI Score</span>
          </div>
          <span className="text-sm font-medium text-white">
            {isiChange ? `${isiChange.improved ? "-" : "+"}${isiChange.value}` : "—"}
          </span>
        </div>

        {/* Correlation */}
        <div className="p-2 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-1 mb-1">
            <Activity className="w-3 h-3 text-purple-400" />
            <span className="text-[10px] text-gray-400">Correlation</span>
          </div>
          <span className={`text-sm font-medium ${correlationStrength?.color || "text-gray-400"}`}>
            {correlationStrength?.strength || "—"}
          </span>
        </div>
      </div>

      {/* Chart */}
      <ResponsiveContainer width="100%" height={height}>
        <ComposedChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
          <XAxis
            dataKey="week"
            tick={{ fill: "#9CA3AF", fontSize: 10 }}
            axisLine={{ stroke: "#4B5563" }}
            tickLine={{ stroke: "#4B5563" }}
            tickFormatter={(value) => `W${value}`}
          />
          <YAxis
            yAxisId="left"
            tick={{ fill: "#9CA3AF", fontSize: 10 }}
            axisLine={{ stroke: "#4B5563" }}
            tickLine={{ stroke: "#4B5563" }}
            domain={[0, 100]}
            tickFormatter={(value) => `${value}%`}
          />
          <YAxis
            yAxisId="right"
            orientation="right"
            tick={{ fill: "#9CA3AF", fontSize: 10 }}
            axisLine={{ stroke: "#4B5563" }}
            tickLine={{ stroke: "#4B5563" }}
            domain={[0, 28]}
          />
          <Tooltip content={<CustomTooltip />} />

          {/* ISI Threshold Lines */}
          <ReferenceLine
            yAxisId="right"
            y={7}
            stroke="#22C55E"
            strokeDasharray="3 3"
            label={{ value: "Normal", position: "right", fill: "#22C55E", fontSize: 9 }}
          />
          <ReferenceLine
            yAxisId="right"
            y={14}
            stroke="#F59E0B"
            strokeDasharray="3 3"
            label={{ value: "Moderate", position: "right", fill: "#F59E0B", fontSize: 9 }}
          />

          {/* Compliance Area */}
          <Area
            yAxisId="left"
            type="monotone"
            dataKey="compliance"
            fill="#3B82F6"
            fillOpacity={0.2}
            stroke="#3B82F6"
            strokeWidth={2}
            name="Compliance"
          />

          {/* ISI Line */}
          <Line
            yAxisId="right"
            type="monotone"
            dataKey="isi"
            stroke="#EF4444"
            strokeWidth={2}
            dot={{ fill: "#EF4444", r: 3 }}
            name="ISI Score"
          />

          {/* Sleep Efficiency (if available) */}
          <Line
            yAxisId="left"
            type="monotone"
            dataKey="efficiency"
            stroke="#10B981"
            strokeWidth={2}
            strokeDasharray="5 5"
            dot={{ fill: "#10B981", r: 3 }}
            name="Efficiency"
          />
        </ComposedChart>
      </ResponsiveContainer>

      {/* Legend */}
      <div className="flex items-center justify-center gap-4 mt-3">
        <div className="flex items-center gap-1">
          <div className="w-3 h-0.5 bg-blue-500"></div>
          <span className="text-[10px] text-gray-400">Compliance %</span>
        </div>
        <div className="flex items-center gap-1">
          <div className="w-3 h-0.5 bg-red-500"></div>
          <span className="text-[10px] text-gray-400">ISI Score</span>
        </div>
        <div className="flex items-center gap-1">
          <div className="w-3 h-0.5 bg-green-500 border-dashed"></div>
          <span className="text-[10px] text-gray-400">Sleep Efficiency</span>
        </div>
      </div>
    </div>
  );
}

// Before/After Comparison Component
export function ComplianceBeforeAfterChart({ userId }: { userId: Id<"users"> }) {
  const correlationData = useQuery(api.outcomeCorrelation.getCorrelationData, {
    userId,
  });

  const comparisonData = useMemo(() => {
    if (!correlationData || correlationData.length === 0) return null;

    const first = correlationData[0];
    const last = correlationData[correlationData.length - 1];

    return {
      isi: {
        before: first.isi_score_start,
        after: last.isi_score_end,
        change: last.isi_change,
      },
      efficiency: {
        before: first.avg_sleep_efficiency_start,
        after: last.avg_sleep_efficiency_end,
        change:
          last.avg_sleep_efficiency_end && first.avg_sleep_efficiency_start
            ? last.avg_sleep_efficiency_end - first.avg_sleep_efficiency_start
            : null,
      },
      compliance: {
        value: last.overall_compliance_pct,
      },
    };
  }, [correlationData]);

  if (!comparisonData) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="animate-pulse h-32 bg-gray-700/50 rounded"></div>
      </div>
    );
  }

  const barData = [
    {
      name: "ISI Score",
      before: comparisonData.isi.before || 0,
      after: comparisonData.isi.after || 0,
      improved: (comparisonData.isi.change || 0) < 0,
    },
    {
      name: "Sleep Efficiency",
      before: comparisonData.efficiency.before || 0,
      after: comparisonData.efficiency.after || 0,
      improved: (comparisonData.efficiency.change || 0) > 0,
    },
  ];

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      <div className="flex items-center gap-2 mb-4">
        <div className="w-8 h-8 rounded-lg bg-green-500/20 flex items-center justify-center">
          <TrendingUp className="w-4 h-4 text-green-400" />
        </div>
        <div>
          <h3 className="text-sm font-medium text-white">Before vs After</h3>
          <p className="text-xs text-gray-500">Treatment impact comparison</p>
        </div>
      </div>

      <div className="space-y-4">
        {barData.map((metric) => (
          <div key={metric.name}>
            <div className="flex items-center justify-between mb-1">
              <span className="text-xs text-gray-400">{metric.name}</span>
              <span
                className={`text-xs ${
                  metric.improved ? "text-green-400" : "text-gray-400"
                }`}
              >
                {metric.improved ? "Improved" : "No change"}
              </span>
            </div>
            <div className="flex gap-2">
              <div className="flex-1">
                <div className="text-[10px] text-gray-500 mb-0.5">Before</div>
                <div className="h-4 bg-gray-700/50 rounded overflow-hidden">
                  <div
                    className="h-full bg-gray-500"
                    style={{
                      width: `${
                        metric.name === "ISI Score"
                          ? (metric.before / 28) * 100
                          : metric.before
                      }%`,
                    }}
                  />
                </div>
                <div className="text-xs text-gray-300 mt-0.5">
                  {metric.before.toFixed(0)}
                  {metric.name === "Sleep Efficiency" ? "%" : ""}
                </div>
              </div>
              <div className="flex-1">
                <div className="text-[10px] text-gray-500 mb-0.5">After</div>
                <div className="h-4 bg-gray-700/50 rounded overflow-hidden">
                  <div
                    className={`h-full ${
                      metric.improved ? "bg-green-500" : "bg-amber-500"
                    }`}
                    style={{
                      width: `${
                        metric.name === "ISI Score"
                          ? (metric.after / 28) * 100
                          : metric.after
                      }%`,
                    }}
                  />
                </div>
                <div className="text-xs text-gray-300 mt-0.5">
                  {metric.after.toFixed(0)}
                  {metric.name === "Sleep Efficiency" ? "%" : ""}
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Overall Compliance Badge */}
      <div className="mt-4 pt-4 border-t border-gray-700/50 text-center">
        <p className="text-xs text-gray-400 mb-1">Overall Compliance</p>
        <span className="inline-block px-3 py-1 rounded-full bg-blue-500/20 text-blue-400 text-sm font-medium">
          {comparisonData.compliance.value.toFixed(0)}%
        </span>
      </div>
    </div>
  );
}
