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

interface SubjectiveVsObjectiveCardProps {
  data: SleepComparison;
  onViewDetails?: () => void;
}

export function SubjectiveVsObjectiveCard({
  data,
  onViewDetails,
}: SubjectiveVsObjectiveCardProps) {
  const hasObjective = data.objective !== null;

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

  return (
    <BentoCard
      title="Sleep Perception"
      subtitle="Subjective vs Objective"
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
      badge={
        perceptionAccuracy !== null
          ? {
              text: `${Math.round(perceptionAccuracy)}% accurate`,
              variant:
                perceptionAccuracy >= 85
                  ? "success"
                  : perceptionAccuracy >= 70
                  ? "warning"
                  : "error",
            }
          : undefined
      }
      action={onViewDetails ? { label: "View trends", onClick: onViewDetails } : undefined}
    >
      {!hasObjective ? (
        <div className="h-full flex items-center justify-center">
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
                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <p className="text-sm font-medium text-gray-400">No Wearable Connected</p>
            <p className="text-xs mt-1 text-gray-500">
              Patient has not connected Apple Watch or other wearable device.
            </p>
            <p className="text-xs mt-2 text-gray-600">
              Subjective data only (from questionnaires)
            </p>
          </div>
        </div>
      ) : (
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
