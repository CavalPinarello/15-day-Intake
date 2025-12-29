"use client";

import { BentoCard } from "./BentoCard";

interface SleepComparison {
  date: string;
  subjective: {
    quality: number; // 1-10 scale
    totalSleep: number; // minutes (estimated by user)
    bedtime: string; // HH:MM
    wakeTime: string; // HH:MM
    awakenings: number;
  };
  objective: {
    efficiency: number; // percentage
    totalSleep: number; // minutes (from HealthKit)
    bedtime: string; // HH:MM
    wakeTime: string; // HH:MM
    awakenings: number;
    deepSleep: number; // minutes
    remSleep: number; // minutes
    lightSleep: number; // minutes
  } | null; // null if no HealthKit data
}

// Extended interface for daily subjective data (from sleep log)
export interface SubjectiveDailyData {
  date: string;
  dayNumber: number;
  quality: number | null; // 1-10 scale
  perceivedEfficiency: number | null; // percentage
  totalSleepMins: number | null;
  timeInBedMins: number | null;
}

export interface SubjectiveSleepData {
  dailyData: SubjectiveDailyData[];
  summary: {
    avgQuality: number | null;
    avgPerceivedEfficiency: number | null;
    daysWithData: number;
    trend: "improving" | "declining" | "stable" | null;
  };
  hasSubjectiveData: boolean;
}

interface SubjectiveVsObjectiveCardProps {
  data: SleepComparison;
  subjectiveData?: SubjectiveSleepData;
  onViewDetails?: () => void;
}

// Mini chart component for sleep quality trend
function QualityTrendChart({ data }: { data: SubjectiveDailyData[] }) {
  // Get last 14 days for chart
  const chartData = data.slice(-14);

  if (chartData.length === 0) {
    return (
      <div className="h-20 flex items-center justify-center text-gray-500 text-xs">
        No sleep log data yet
      </div>
    );
  }

  const maxQuality = 10;
  const minQuality = 1;
  const range = maxQuality - minQuality;

  // Calculate chart dimensions
  const chartWidth = 100; // percentage
  const chartHeight = 80; // pixels

  // Filter out null values for chart
  const validData = chartData.filter(d => d.quality !== null);

  if (validData.length === 0) {
    return (
      <div className="h-20 flex items-center justify-center text-gray-500 text-xs">
        No quality ratings recorded
      </div>
    );
  }

  // Create SVG path for line chart
  const points = chartData.map((d, i) => {
    const x = (i / Math.max(chartData.length - 1, 1)) * 100;
    const y = d.quality !== null
      ? 100 - ((d.quality - minQuality) / range) * 100
      : null;
    return { x, y, quality: d.quality, dayNumber: d.dayNumber };
  });

  // Build path string (skip null points)
  let pathD = "";
  let isFirstPoint = true;
  points.forEach(p => {
    if (p.y !== null) {
      if (isFirstPoint) {
        pathD += `M ${p.x} ${p.y}`;
        isFirstPoint = false;
      } else {
        pathD += ` L ${p.x} ${p.y}`;
      }
    }
  });

  return (
    <div className="relative h-20">
      {/* Y-axis labels */}
      <div className="absolute left-0 top-0 bottom-0 w-6 flex flex-col justify-between text-[9px] text-gray-500 pr-1">
        <span>10</span>
        <span>5</span>
        <span>1</span>
      </div>

      {/* Chart area */}
      <div className="ml-7 h-full relative">
        <svg
          viewBox="0 0 100 100"
          preserveAspectRatio="none"
          className="w-full h-full"
        >
          {/* Grid lines */}
          <line x1="0" y1="50" x2="100" y2="50" stroke="#374151" strokeWidth="0.5" strokeDasharray="2,2" />
          <line x1="0" y1="0" x2="100" y2="0" stroke="#374151" strokeWidth="0.5" />
          <line x1="0" y1="100" x2="100" y2="100" stroke="#374151" strokeWidth="0.5" />

          {/* Line chart */}
          {pathD && (
            <path
              d={pathD}
              fill="none"
              stroke="#3B82F6"
              strokeWidth="2"
              vectorEffect="non-scaling-stroke"
            />
          )}

          {/* Data points */}
          {points.map((p, i) =>
            p.y !== null && (
              <circle
                key={i}
                cx={p.x}
                cy={p.y}
                r="3"
                fill="#3B82F6"
                vectorEffect="non-scaling-stroke"
              />
            )
          )}
        </svg>

        {/* X-axis label */}
        <div className="absolute bottom-[-16px] left-0 right-0 flex justify-between text-[9px] text-gray-500">
          <span>Day {chartData[0]?.dayNumber || 1}</span>
          <span>Day {chartData[chartData.length - 1]?.dayNumber || 14}</span>
        </div>
      </div>
    </div>
  );
}

export function SubjectiveVsObjectiveCard({
  data,
  subjectiveData,
  onViewDetails,
}: SubjectiveVsObjectiveCardProps) {
  const hasObjective = data.objective !== null;
  const hasSubjective = subjectiveData?.hasSubjectiveData || false;

  // Calculate discrepancies
  const sleepDifference = hasObjective
    ? data.subjective.totalSleep - data.objective!.totalSleep
    : 0;
  const awakeningsDiff = hasObjective
    ? data.subjective.awakenings - data.objective!.awakenings
    : 0;

  // Perception accuracy (how close subjective is to objective)
  const perceptionAccuracy = hasObjective
    ? Math.max(
        0,
        100 -
          Math.abs(
            ((data.subjective.totalSleep - data.objective!.totalSleep) /
              data.objective!.totalSleep) *
              100
          )
      )
    : null;

  const formatTime = (minutes: number) => {
    const hours = Math.floor(minutes / 60);
    const mins = Math.round(minutes % 60);
    return `${hours}h ${mins}m`;
  };

  const getDiscrepancyColor = (diff: number, threshold: number) => {
    const absDiff = Math.abs(diff);
    if (absDiff <= threshold) return "text-green-400";
    if (absDiff <= threshold * 2) return "text-amber-400";
    return "text-red-400";
  };

  const getTrendIcon = (trend: string | null) => {
    switch (trend) {
      case "improving": return "↑";
      case "declining": return "↓";
      case "stable": return "→";
      default: return "";
    }
  };

  const getTrendColor = (trend: string | null) => {
    switch (trend) {
      case "improving": return "text-green-400";
      case "declining": return "text-red-400";
      case "stable": return "text-gray-400";
      default: return "text-gray-500";
    }
  };

  // Badge logic
  const badge = perceptionAccuracy !== null
    ? {
        text: `${Math.round(perceptionAccuracy)}% accurate`,
        variant: perceptionAccuracy >= 85 ? "success" as const : perceptionAccuracy >= 70 ? "warning" as const : "error" as const,
      }
    : hasSubjective && subjectiveData?.summary?.avgQuality !== null && subjectiveData?.summary?.avgQuality !== undefined
    ? {
        text: `${subjectiveData.summary.avgQuality.toFixed(1)}/10 avg`,
        variant: "info" as const,
      }
    : undefined;

  return (
    <BentoCard
      title="Sleep Perception"
      subtitle={hasObjective ? "Subjective vs Objective" : "Subjective Sleep Quality"}
      size="wide"
      icon={
        <svg
          className="w-4 h-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
          />
        </svg>
      }
      badge={badge}
      action={onViewDetails ? { label: "View trends", onClick: onViewDetails } : undefined}
    >
      {/* Subjective-Only View (No Wearable) */}
      {!hasObjective && (
        <div className="space-y-4">
          {hasSubjective ? (
            <>
              {/* Quality Trend Chart */}
              <div>
                <div className="text-xs text-gray-400 mb-2">Sleep Quality Trend (1-10)</div>
                <QualityTrendChart data={subjectiveData!.dailyData} />
              </div>

              {/* Stats Row */}
              <div className="grid grid-cols-3 gap-3 pt-4 border-t border-gray-700">
                <div>
                  <div className="text-xs text-gray-500">Avg Quality</div>
                  <div className="text-lg font-semibold text-white">
                    {subjectiveData!.summary.avgQuality !== null
                      ? `${subjectiveData!.summary.avgQuality.toFixed(1)}/10`
                      : "—"
                    }
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500">Perceived Efficiency</div>
                  <div className="text-lg font-semibold text-white">
                    {subjectiveData!.summary.avgPerceivedEfficiency !== null
                      ? `${Math.round(subjectiveData!.summary.avgPerceivedEfficiency)}%`
                      : "—"
                    }
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500">Trend</div>
                  <div className={`text-lg font-semibold ${getTrendColor(subjectiveData!.summary.trend)}`}>
                    {getTrendIcon(subjectiveData!.summary.trend)} {subjectiveData!.summary.trend || "—"}
                  </div>
                </div>
              </div>

              {/* Hint about wearable */}
              <div className="text-xs text-gray-500 text-center pt-2 border-t border-gray-700/50">
                <span className="opacity-70">Connect Apple Watch for objective sleep data comparison</span>
              </div>
            </>
          ) : (
            // No subjective data yet
            <div className="h-full flex items-center justify-center py-4">
              <div className="text-center text-gray-500">
                <svg
                  className="w-10 h-10 mx-auto mb-3 opacity-50"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={1.5}
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
                <p className="text-sm font-medium text-gray-400">Awaiting Sleep Log Data</p>
                <p className="text-xs mt-1 text-gray-500">
                  Quality ratings appear after patient completes morning sleep log
                </p>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Full Comparison View (With Wearable) */}
      {hasObjective && (
        <div className="grid grid-cols-3 gap-4 h-full">
          {/* Subjective column */}
          <div className="space-y-2">
            <div className="text-xs font-medium text-blue-400 uppercase tracking-wider">
              Reported
            </div>
            <div className="space-y-1.5">
              <div>
                <div className="text-xs text-gray-500">Quality</div>
                <div className="text-lg font-semibold text-white">
                  {data.subjective.quality}/10
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-500">Sleep Time</div>
                <div className="text-sm font-medium text-gray-300">
                  {formatTime(data.subjective.totalSleep)}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-500">Awakenings</div>
                <div className="text-sm font-medium text-gray-300">
                  {data.subjective.awakenings}×
                </div>
              </div>
            </div>
          </div>

          {/* Difference column */}
          <div className="space-y-2 border-x border-gray-700 px-4">
            <div className="text-xs font-medium text-gray-400 uppercase tracking-wider">
              Difference
            </div>
            <div className="space-y-1.5">
              <div>
                <div className="text-xs text-gray-500">Efficiency</div>
                <div className="text-lg font-semibold text-green-400">
                  {Math.round(data.objective!.efficiency)}%
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-500">Time Δ</div>
                <div
                  className={`text-sm font-medium ${getDiscrepancyColor(
                    sleepDifference,
                    30
                  )}`}
                >
                  {sleepDifference > 0 ? "+" : ""}
                  {formatTime(sleepDifference)}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-500">Awakenings Δ</div>
                <div
                  className={`text-sm font-medium ${getDiscrepancyColor(
                    awakeningsDiff,
                    2
                  )}`}
                >
                  {awakeningsDiff > 0 ? "+" : ""}
                  {awakeningsDiff}
                </div>
              </div>
            </div>
          </div>

          {/* Objective column */}
          <div className="space-y-2">
            <div className="text-xs font-medium text-green-400 uppercase tracking-wider">
              Measured
            </div>
            <div className="space-y-1.5">
              <div>
                <div className="text-xs text-gray-500">Deep Sleep</div>
                <div className="text-sm font-medium text-gray-300">
                  {formatTime(data.objective!.deepSleep)}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-500">Sleep Time</div>
                <div className="text-sm font-medium text-gray-300">
                  {formatTime(data.objective!.totalSleep)}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-500">Awakenings</div>
                <div className="text-sm font-medium text-gray-300">
                  {data.objective!.awakenings}×
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </BentoCard>
  );
}

// Insight about perception patterns
interface PerceptionInsight {
  type: "overestimate" | "underestimate" | "accurate";
  magnitude: "slight" | "moderate" | "significant";
  metric: "duration" | "quality" | "awakenings";
  message: string;
}

export function getPerceptionInsights(
  comparisons: SleepComparison[]
): PerceptionInsight[] {
  const insights: PerceptionInsight[] = [];
  const validComparisons = comparisons.filter((c) => c.objective !== null);

  if (validComparisons.length < 3) return insights;

  // Calculate average discrepancies
  let avgSleepDiff = 0;
  let avgAwakeningsDiff = 0;

  validComparisons.forEach((c) => {
    avgSleepDiff += c.subjective.totalSleep - c.objective!.totalSleep;
    avgAwakeningsDiff += c.subjective.awakenings - c.objective!.awakenings;
  });

  avgSleepDiff /= validComparisons.length;
  avgAwakeningsDiff /= validComparisons.length;

  // Sleep duration insight
  if (Math.abs(avgSleepDiff) > 15) {
    const type = avgSleepDiff > 0 ? "overestimate" : "underestimate";
    const magnitude =
      Math.abs(avgSleepDiff) > 60
        ? "significant"
        : Math.abs(avgSleepDiff) > 30
        ? "moderate"
        : "slight";

    insights.push({
      type,
      magnitude,
      metric: "duration",
      message:
        type === "overestimate"
          ? `Patient tends to ${magnitude}ly overestimate sleep duration by ~${Math.round(
              Math.abs(avgSleepDiff)
            )} minutes`
          : `Patient tends to ${magnitude}ly underestimate sleep duration by ~${Math.round(
              Math.abs(avgSleepDiff)
            )} minutes`,
    });
  }

  // Awakenings insight
  if (Math.abs(avgAwakeningsDiff) > 1) {
    const type = avgAwakeningsDiff < 0 ? "underestimate" : "overestimate";
    insights.push({
      type,
      magnitude: Math.abs(avgAwakeningsDiff) > 3 ? "significant" : "moderate",
      metric: "awakenings",
      message:
        type === "underestimate"
          ? `Patient underreports night awakenings by ~${Math.round(
              Math.abs(avgAwakeningsDiff)
            )} per night`
          : `Patient overestimates awakenings by ~${Math.round(
              Math.abs(avgAwakeningsDiff)
            )} per night`,
    });
  }

  return insights;
}
