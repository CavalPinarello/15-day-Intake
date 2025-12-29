"use client";

import { BentoCard } from "./BentoCard";

// 11 Pillars from the Zoe Sleep system
export const PILLARS = {
  social: {
    name: "Social",
    icon: "👥",
    color: "#8B5CF6", // Purple
    description: "Social support, relationships, lifestyle factors",
  },
  metabolic: {
    name: "Metabolic",
    icon: "🔥",
    color: "#F59E0B", // Amber
    description: "BMI, metabolic health indicators",
  },
  sleepQuality: {
    name: "Sleep Quality",
    icon: "⭐",
    color: "#10B981", // Emerald
    description: "PSQI, subjective sleep quality ratings",
  },
  sleepQuantity: {
    name: "Sleep Quantity",
    icon: "⏱️",
    color: "#3B82F6", // Blue
    description: "Total sleep time, sleep need",
  },
  sleepRegularity: {
    name: "Sleep Regularity",
    icon: "📅",
    color: "#6366F1", // Indigo
    description: "Bedtime/wake time consistency",
  },
  sleepTiming: {
    name: "Sleep Timing",
    icon: "🌙",
    color: "#EC4899", // Pink
    description: "Chronotype, MEQ score",
  },
  mentalHealth: {
    name: "Mental Health",
    icon: "🧠",
    color: "#EF4444", // Red
    description: "PHQ-9, GAD-7, stress levels",
  },
  cognitive: {
    name: "Cognitive",
    icon: "💭",
    color: "#14B8A6", // Teal
    description: "Cognitive function, DBAS-16",
  },
  physical: {
    name: "Physical",
    icon: "💪",
    color: "#F97316", // Orange
    description: "Pain, activity levels, health conditions",
  },
  nutritional: {
    name: "Nutritional",
    icon: "🥗",
    color: "#84CC16", // Lime
    description: "Diet patterns, caffeine, alcohol",
  },
  sleepLog: {
    name: "Sleep Log",
    icon: "📝",
    color: "#06B6D4", // Cyan
    description: "Daily Stanford Sleep Log entries",
  },
} as const;

export type PillarKey = keyof typeof PILLARS;

interface PillarStatus {
  pillar: PillarKey;
  score: number | null; // 0-100 normalized score, null if no data
  questionsAnswered: number;
  questionsTotal: number;
  trend: "improving" | "declining" | "stable" | null;
  alerts: string[];
}

interface PillarSummaryCardProps {
  pillars: PillarStatus[];
  onPillarClick?: (pillar: PillarKey) => void;
}

// Uses neutral color for completion percentage (not health-implying)
const getCompletionColor = (score: number | null) => {
  if (score === null) return "bg-gray-600";
  // Use consistent amber/orange for completion progress - not green/red which implies health status
  return "bg-amber-500";
};

const getTrendIcon = (trend: PillarStatus["trend"]) => {
  switch (trend) {
    case "improving":
      return "↑";
    case "declining":
      return "↓";
    case "stable":
      return "→";
    default:
      return "";
  }
};

const getTrendColor = (trend: PillarStatus["trend"]) => {
  switch (trend) {
    case "improving":
      return "text-green-400";
    case "declining":
      return "text-red-400";
    case "stable":
      return "text-gray-400";
    default:
      return "text-gray-600";
  }
};

export function PillarSummaryCard({
  pillars,
  onPillarClick,
}: PillarSummaryCardProps) {
  // Calculate overall health score
  const validScores = pillars.filter((p) => p.score !== null);
  const overallScore =
    validScores.length > 0
      ? Math.round(
          validScores.reduce((acc, p) => acc + (p.score || 0), 0) /
            validScores.length
        )
      : null;

  // Count alerts
  const totalAlerts = pillars.reduce((acc, p) => acc + p.alerts.length, 0);

  return (
    <BentoCard
      title="Health Pillars"
      subtitle="11-pillar assessment"
      size="large"
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
        totalAlerts > 0
          ? {
              text: `${totalAlerts} alert${totalAlerts > 1 ? "s" : ""}`,
              variant: "warning",
            }
          : overallScore !== null
          ? {
              text: `${overallScore}%`,
              variant: "warning", // Neutral color for completion - not health status
            }
          : undefined
      }
    >
      <div className="space-y-3">
        {/* Assessment completion bar */}
        {overallScore !== null && (
          <div className="mb-4">
            <div className="flex justify-between items-center mb-1">
              <span className="text-xs text-gray-400">Assessment Completion</span>
              <span className="text-sm font-medium text-amber-400">
                {overallScore}%
              </span>
            </div>
            <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
              <div
                className={`h-full rounded-full transition-all duration-500 ${getCompletionColor(
                  overallScore
                )}`}
                style={{ width: `${overallScore}%` }}
              />
            </div>
          </div>
        )}

        {/* Pillar grid */}
        <div className="grid grid-cols-4 gap-2">
          {pillars.map((pillarStatus) => {
            const pillar = PILLARS[pillarStatus.pillar];
            const hasData = pillarStatus.score !== null;

            return (
              <button
                key={pillarStatus.pillar}
                onClick={() => onPillarClick?.(pillarStatus.pillar)}
                className={`
                  relative p-2 rounded-lg border transition-all
                  ${
                    hasData
                      ? "bg-gray-700/50 border-gray-600 hover:border-gray-500"
                      : "bg-gray-800/30 border-gray-700/50"
                  }
                  ${pillarStatus.alerts.length > 0 ? "ring-1 ring-amber-500/50" : ""}
                `}
                title={pillar.description}
              >
                {/* Alert indicator */}
                {pillarStatus.alerts.length > 0 && (
                  <div className="absolute -top-1 -right-1 w-4 h-4 bg-amber-500 rounded-full flex items-center justify-center text-[10px] text-black font-bold">
                    !
                  </div>
                )}

                {/* Icon */}
                <div className="text-lg mb-1">{pillar.icon}</div>

                {/* Completion bar */}
                <div className="h-1.5 bg-gray-700 rounded-full overflow-hidden mb-1">
                  <div
                    className={`h-full rounded-full transition-all ${getCompletionColor(
                      pillarStatus.score
                    )}`}
                    style={{ width: `${pillarStatus.score || 0}%` }}
                  />
                </div>

                {/* Label and trend */}
                <div className="flex items-center justify-between">
                  <span className="text-[10px] text-gray-400 truncate">
                    {pillar.name}
                  </span>
                  {pillarStatus.trend && (
                    <span
                      className={`text-xs ${getTrendColor(pillarStatus.trend)}`}
                    >
                      {getTrendIcon(pillarStatus.trend)}
                    </span>
                  )}
                </div>

                {/* Score */}
                {hasData && (
                  <div className="text-xs font-medium text-white mt-0.5">
                    {pillarStatus.score}%
                  </div>
                )}
              </button>
            );
          })}
        </div>

        {/* Completion stats */}
        <div className="flex justify-between text-xs text-gray-500 pt-2 border-t border-gray-700">
          <span>
            {validScores.length}/{pillars.length} pillars assessed
          </span>
          <span>
            {pillars.reduce((acc, p) => acc + p.questionsAnswered, 0)} questions
            answered
          </span>
        </div>
      </div>
    </BentoCard>
  );
}

// Compact pillar bar for inline use
export function PillarBar({
  pillars,
}: {
  pillars: { pillar: PillarKey; score: number | null }[];
}) {
  return (
    <div className="flex gap-0.5 h-4">
      {pillars.map(({ pillar, score }) => (
        <div
          key={pillar}
          className={`flex-1 rounded-sm ${getCompletionColor(score)}`}
          style={{ opacity: score === null ? 0.3 : 1 }}
          title={`${PILLARS[pillar].name}: ${score ?? "N/A"}% complete`}
        />
      ))}
    </div>
  );
}
