"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import {
  Brain,
  TrendingUp,
  TrendingDown,
  Minus,
  Eye,
  Watch,
  AlertCircle,
  CheckCircle2,
  Info,
} from "lucide-react";

interface PerceptionGapCardProps {
  userId: Id<"users">;
  days?: number;
}

interface GapData {
  date: string;
  subjective_quality?: number;
  objective_efficiency?: number;
  subjective_latency_mins?: number;
  objective_latency_mins?: number;
  subjective_awakenings?: number;
  objective_awakenings?: number;
  gap_score?: number;
  gap_direction?: string;
  objective_total_sleep_mins?: number;
}

export function PerceptionGapCard({ userId, days = 14 }: PerceptionGapCardProps) {
  const gapData = useQuery(api.healthkit.getPerceptionGaps, {
    userId,
    limit: days,
  });

  // Also get subjective sleep quality data
  const subjectiveSleepData = useQuery(api.physician.getSubjectiveSleepQuality, {
    userId,
    days,
  });

  if (!gapData || !subjectiveSleepData) {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2 bg-purple-100 rounded-lg">
            <Brain className="w-5 h-5 text-purple-700" />
          </div>
          <h3 className="font-semibold text-gray-900">Perception Gap Analysis</h3>
        </div>
        <div className="animate-pulse space-y-4">
          <div className="h-32 bg-gray-100 rounded" />
          <div className="h-20 bg-gray-100 rounded" />
        </div>
      </div>
    );
  }

  // Combine subjective data with objective gap data
  const combinedData: Array<{
    date: string;
    dayOfWeek: string;
    perceivdQuality?: number;
    perceivedSleepMins?: number;
    objectiveEfficiency?: number;
    objectiveSleepMins?: number;
    gapScore?: number;
    gapDirection?: string;
    hasPerceived: boolean;
    hasObjective: boolean;
  }> = [];

  // Build date map from gap data
  const gapMap = new Map<string, GapData>();
  gapData.forEach((g: GapData) => {
    gapMap.set(g.date, g);
  });

  // Process subjective data first (it has more complete date coverage)
  if (subjectiveSleepData.dailyData) {
    subjectiveSleepData.dailyData.forEach((day: {
      date: string;
      quality?: number | null;
      totalSleepMins?: number | null;
    }) => {
      const gap = gapMap.get(day.date);
      const dateObj = new Date(day.date);
      const dayOfWeek = dateObj.toLocaleDateString("en-US", { weekday: "short" });

      combinedData.push({
        date: day.date,
        dayOfWeek,
        perceivdQuality: day.quality ?? undefined,
        perceivedSleepMins: day.totalSleepMins ?? undefined,
        objectiveEfficiency: gap?.objective_efficiency,
        objectiveSleepMins: gap?.objective_total_sleep_mins,
        gapScore: gap?.gap_score,
        gapDirection: gap?.gap_direction,
        hasPerceived: day.quality != null,
        hasObjective: gap?.objective_efficiency != null,
      });
    });
  }

  // Sort by date (oldest first)
  combinedData.sort((a, b) => a.date.localeCompare(b.date));

  // Calculate statistics
  const daysWithBothData = combinedData.filter((d) => d.hasPerceived && d.hasObjective);
  const hasEnoughData = daysWithBothData.length >= 3;

  // Calculate average perception gap
  let avgGap = 0;
  let biasDirection: "overestimate" | "underestimate" | "accurate" = "accurate";
  let accurateDays = 0;

  if (hasEnoughData) {
    const gaps = daysWithBothData
      .filter((d) => d.perceivdQuality != null && d.objectiveEfficiency != null)
      .map((d) => {
        // Normalize perceived quality (1-10) to 0-100 scale
        const perceivedNormalized = (d.perceivdQuality || 5) * 10;
        const gap = perceivedNormalized - (d.objectiveEfficiency || 0);
        return gap;
      });

    if (gaps.length > 0) {
      avgGap = Math.round(gaps.reduce((a, b) => a + b, 0) / gaps.length);

      // Count accurate days (within +/- 10 points)
      accurateDays = gaps.filter((g) => Math.abs(g) <= 10).length;

      // Determine overall bias
      if (avgGap > 5) {
        biasDirection = "overestimate";
      } else if (avgGap < -5) {
        biasDirection = "underestimate";
      } else {
        biasDirection = "accurate";
      }
    }
  }

  const accuracyRate = daysWithBothData.length > 0
    ? Math.round((accurateDays / daysWithBothData.length) * 100)
    : 0;

  // Calculate trend (comparing first half to second half)
  let trend: "improving" | "declining" | "stable" | null = null;
  if (daysWithBothData.length >= 6) {
    const mid = Math.floor(daysWithBothData.length / 2);
    const firstHalf = daysWithBothData.slice(0, mid);
    const secondHalf = daysWithBothData.slice(mid);

    const firstHalfAvgGap = firstHalf.reduce((sum, d) => {
      const percNorm = (d.perceivdQuality || 5) * 10;
      return sum + Math.abs(percNorm - (d.objectiveEfficiency || 0));
    }, 0) / firstHalf.length;

    const secondHalfAvgGap = secondHalf.reduce((sum, d) => {
      const percNorm = (d.perceivdQuality || 5) * 10;
      return sum + Math.abs(percNorm - (d.objectiveEfficiency || 0));
    }, 0) / secondHalf.length;

    // Smaller gap = better (improving)
    if (secondHalfAvgGap < firstHalfAvgGap - 5) {
      trend = "improving";
    } else if (secondHalfAvgGap > firstHalfAvgGap + 5) {
      trend = "declining";
    } else {
      trend = "stable";
    }
  }

  // Max values for bar scaling
  const maxValue = 100; // Both scales go to 100%

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-purple-100 rounded-lg">
            <Brain className="w-5 h-5 text-purple-700" />
          </div>
          <div>
            <h3 className="font-semibold text-gray-900">Perception Gap Analysis</h3>
            <p className="text-sm text-gray-500">Subjective vs. Objective Sleep Assessment</p>
          </div>
        </div>
        {trend && (
          <div className={`flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${
            trend === "improving"
              ? "bg-green-100 text-green-700"
              : trend === "declining"
              ? "bg-red-100 text-red-700"
              : "bg-gray-100 text-gray-600"
          }`}>
            {trend === "improving" ? (
              <TrendingUp className="w-3 h-3" />
            ) : trend === "declining" ? (
              <TrendingDown className="w-3 h-3" />
            ) : (
              <Minus className="w-3 h-3" />
            )}
            {trend === "improving" ? "Improving" : trend === "declining" ? "Declining" : "Stable"}
          </div>
        )}
      </div>

      {!hasEnoughData ? (
        <div className="text-center py-8 text-gray-500">
          <Brain className="w-12 h-12 mx-auto mb-3 text-gray-300" />
          <p className="font-medium">Not enough data for analysis</p>
          <p className="text-sm mt-1">
            Requires both questionnaire responses and wearable data on at least 3 days
          </p>
          <div className="flex items-center justify-center gap-4 mt-4 text-xs">
            <span className="flex items-center gap-1">
              <Eye className="w-3 h-3" />
              Subjective: {combinedData.filter((d) => d.hasPerceived).length} days
            </span>
            <span className="flex items-center gap-1">
              <Watch className="w-3 h-3" />
              Objective: {combinedData.filter((d) => d.hasObjective).length} days
            </span>
          </div>
        </div>
      ) : (
        <>
          {/* Timeline Visualization */}
          <div className="mb-6">
            <div className="flex items-center gap-4 mb-3 text-xs">
              <div className="flex items-center gap-1">
                <div className="w-3 h-3 bg-purple-400 rounded-sm" />
                <span className="text-gray-600">Perceived Quality</span>
              </div>
              <div className="flex items-center gap-1">
                <div className="w-3 h-3 bg-blue-400 rounded-sm" />
                <span className="text-gray-600">Actual Efficiency</span>
              </div>
            </div>

            <div className="space-y-2">
              {combinedData.slice(-7).map((day, i) => {
                const perceivedHeight = day.perceivdQuality
                  ? (day.perceivdQuality * 10 / maxValue) * 100
                  : 0;
                const objectiveHeight = day.objectiveEfficiency
                  ? (day.objectiveEfficiency / maxValue) * 100
                  : 0;

                // Calculate gap for color coding
                const gapSize = day.perceivdQuality && day.objectiveEfficiency
                  ? Math.abs(day.perceivdQuality * 10 - day.objectiveEfficiency)
                  : 0;

                let gapColor = "bg-green-500"; // Accurate
                if (gapSize > 15) gapColor = "bg-red-500"; // Significant gap
                else if (gapSize > 10) gapColor = "bg-yellow-500"; // Mild gap

                return (
                  <div key={i} className="flex items-center gap-2">
                    {/* Day label */}
                    <span className="w-12 text-xs text-gray-500 text-right">{day.dayOfWeek}</span>

                    {/* Bar container */}
                    <div className="flex-1 flex gap-1">
                      {/* Perceived */}
                      <div className="flex-1 h-6 bg-gray-100 rounded overflow-hidden relative">
                        {day.hasPerceived ? (
                          <div
                            className="h-full bg-purple-400 rounded transition-all"
                            style={{ width: `${perceivedHeight}%` }}
                          />
                        ) : (
                          <div className="h-full w-full flex items-center justify-center text-xs text-gray-400">
                            —
                          </div>
                        )}
                      </div>

                      {/* Actual */}
                      <div className="flex-1 h-6 bg-gray-100 rounded overflow-hidden relative">
                        {day.hasObjective ? (
                          <div
                            className="h-full bg-blue-400 rounded transition-all"
                            style={{ width: `${objectiveHeight}%` }}
                          />
                        ) : (
                          <div className="h-full w-full flex items-center justify-center text-xs text-gray-400">
                            —
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Gap indicator */}
                    <div className="w-16 flex items-center justify-end">
                      {day.hasPerceived && day.hasObjective ? (
                        <div className={`w-2 h-2 rounded-full ${gapColor}`} title={`Gap: ${gapSize.toFixed(0)}pts`} />
                      ) : (
                        <span className="text-xs text-gray-400">—</span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Summary Statistics */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            {/* Bias Direction */}
            <div className={`p-3 rounded-lg ${
              biasDirection === "accurate"
                ? "bg-green-50"
                : biasDirection === "overestimate"
                ? "bg-amber-50"
                : "bg-blue-50"
            }`}>
              <div className="flex items-center gap-1 text-xs text-gray-600 mb-1">
                {biasDirection === "accurate" ? (
                  <CheckCircle2 className="w-3 h-3 text-green-600" />
                ) : (
                  <AlertCircle className="w-3 h-3 text-amber-600" />
                )}
                <span>Bias</span>
              </div>
              <p className={`font-bold ${
                biasDirection === "accurate"
                  ? "text-green-700"
                  : biasDirection === "overestimate"
                  ? "text-amber-700"
                  : "text-blue-700"
              }`}>
                {biasDirection === "accurate"
                  ? "Accurate"
                  : biasDirection === "overestimate"
                  ? "Over +10%"
                  : "Under -10%"}
              </p>
            </div>

            {/* Average Gap */}
            <div className="p-3 bg-gray-50 rounded-lg">
              <div className="flex items-center gap-1 text-xs text-gray-600 mb-1">
                <Brain className="w-3 h-3" />
                <span>Avg Gap</span>
              </div>
              <p className="font-bold text-gray-900">
                {avgGap > 0 ? "+" : ""}{avgGap}%
              </p>
            </div>

            {/* Accuracy Rate */}
            <div className="p-3 bg-purple-50 rounded-lg">
              <div className="flex items-center gap-1 text-xs text-gray-600 mb-1">
                <Eye className="w-3 h-3" />
                <span>Accuracy</span>
              </div>
              <p className="font-bold text-purple-700">{accuracyRate}%</p>
            </div>

            {/* Days Analyzed */}
            <div className="p-3 bg-blue-50 rounded-lg">
              <div className="flex items-center gap-1 text-xs text-gray-600 mb-1">
                <Watch className="w-3 h-3" />
                <span>Data Days</span>
              </div>
              <p className="font-bold text-blue-700">{daysWithBothData.length}</p>
            </div>
          </div>

          {/* Clinical Interpretation */}
          <div className="mt-4 p-3 bg-gray-50 rounded-lg border border-gray-200">
            <div className="flex items-start gap-2">
              <Info className="w-4 h-4 text-gray-500 mt-0.5" />
              <div className="text-sm text-gray-600">
                {biasDirection === "overestimate" && (
                  <p>
                    <strong>Sleep State Misperception:</strong> Patient consistently rates their sleep quality higher than
                    objective measurements suggest. This may indicate paradoxical insomnia or difficulty recognizing
                    sleep disruptions.
                  </p>
                )}
                {biasDirection === "underestimate" && (
                  <p>
                    <strong>Negative Perception Bias:</strong> Patient perceives their sleep as worse than objective
                    measurements show. This could be related to anxiety, catastrophizing, or hypersensitivity to
                    awakenings.
                  </p>
                )}
                {biasDirection === "accurate" && (
                  <p>
                    <strong>Good Sleep Awareness:</strong> Patient's perception aligns well with objective
                    measurements. This indicates healthy interoceptive awareness of sleep quality.
                  </p>
                )}
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
