/**
 * Sleep Insights Analytics Functions
 *
 * Provides analytics for comparing objective HealthKit data with subjective Sleep Log responses.
 * Generates insights about perception gaps, patterns, and actionable recommendations.
 */

import { query, mutation, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

// ============================================
// Constants
// ============================================

/** Optimal sleep duration in minutes (7 hours - CDC recommendation) */
const OPTIMAL_SLEEP_DURATION_MINS = 420;

/** Weight for sleep efficiency in objective score (60%) */
const EFFICIENCY_WEIGHT = 0.6;

/** Weight for sleep duration in objective score (40%) */
const DURATION_WEIGHT = 0.4;

/** Perception gap threshold for "underestimate" classification */
const UNDERESTIMATE_THRESHOLD = -15;

/** Perception gap threshold for "overestimate" classification */
const OVERESTIMATE_THRESHOLD = 15;

/** Minimum days required for basic insights */
const MIN_DAYS_FOR_INSIGHTS = 5;

/** Minimum days required for pattern detection */
const MIN_DAYS_FOR_PATTERNS = 7;

/** Minimum latency improvement (minutes) to generate bedtime insight */
const MIN_LATENCY_IMPROVEMENT = 10;

/** Minimum weekend deep sleep improvement (%) to generate insight */
const MIN_WEEKEND_DEEP_IMPROVEMENT = 15;

/** Recommended deep sleep percentage range */
const RECOMMENDED_DEEP_SLEEP_PERCENT = { min: 13, max: 23 };

/** Recommended REM sleep percentage range */
const RECOMMENDED_REM_SLEEP_PERCENT = { min: 20, max: 25 };

// ============================================
// Helper Functions
// ============================================

/**
 * Calculate Pearson correlation coefficient between two arrays
 */
function calculatePearsonCorrelation(x: number[], y: number[]): number {
  if (x.length !== y.length || x.length < 2) return 0;

  const n = x.length;
  const sumX = x.reduce((a, b) => a + b, 0);
  const sumY = y.reduce((a, b) => a + b, 0);
  const sumXY = x.reduce((total, xi, i) => total + xi * y[i], 0);
  const sumX2 = x.reduce((total, xi) => total + xi * xi, 0);
  const sumY2 = y.reduce((total, yi) => total + yi * yi, 0);

  const numerator = n * sumXY - sumX * sumY;
  const denominator = Math.sqrt(
    (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY)
  );

  return denominator === 0 ? 0 : numerator / denominator;
}

/**
 * Calculate average of an array
 */
function average(arr: number[]): number {
  return arr.length > 0 ? arr.reduce((a, b) => a + b, 0) / arr.length : 0;
}

/**
 * Calculate standard deviation
 */
function standardDeviation(arr: number[]): number {
  if (arr.length < 2) return 0;
  const avg = average(arr);
  const squareDiffs = arr.map((value) => Math.pow(value - avg, 2));
  return Math.sqrt(average(squareDiffs));
}

/**
 * Normalize objective sleep data to a 0-100 score
 * Combines efficiency and duration adequacy using weighted average
 */
function normalizeObjectiveScore(
  efficiency: number,
  totalSleepMins: number
): number {
  const durationAdequacy = Math.min(100, (totalSleepMins / OPTIMAL_SLEEP_DURATION_MINS) * 100);
  return efficiency * EFFICIENCY_WEIGHT + durationAdequacy * DURATION_WEIGHT;
}

/**
 * Calculate perception gap between subjective and objective
 * Returns the gap value, direction classification, and magnitude
 */
function calculatePerceptionGap(
  subjectiveQuality: number, // 1-10
  objectiveEfficiency: number, // 0-100
  objectiveDuration: number // minutes
): { gap: number; direction: string; magnitude: number } {
  const normalizedSubjective = subjectiveQuality * 10; // Convert to 0-100
  const objectiveScore = normalizeObjectiveScore(
    objectiveEfficiency,
    objectiveDuration
  );

  const gap = normalizedSubjective - objectiveScore;

  return {
    gap,
    direction:
      gap < UNDERESTIMATE_THRESHOLD
        ? "underestimate"
        : gap > OVERESTIMATE_THRESHOLD
          ? "overestimate"
          : "accurate",
    magnitude: Math.abs(gap),
  };
}

/**
 * Convert ISO date string to day of week (0 = Sunday, 6 = Saturday)
 */
function getDayOfWeek(dateString: string): number {
  return new Date(dateString).getDay();
}

/**
 * Check if date is a weekday (Mon-Fri)
 */
function isWeekday(dateString: string): boolean {
  const day = getDayOfWeek(dateString);
  return day >= 1 && day <= 5;
}

// ============================================
// Query: Get Perception vs Reality Data
// ============================================

export const getPerceptionVsReality = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 14;
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToFetch);
    const cutoffString = cutoffDate.toISOString().split("T")[0];

    // 1. Fetch HealthKit data (objective)
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .collect();

    const recentSleepData = sleepData.filter((d) => d.date >= cutoffString);

    // 2. Fetch Sleep Log responses (subjective) - SD_SLEEP_QUALITY question
    const qualityResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("question_id"), "SD_SLEEP_QUALITY"))
      .collect();

    // 3. Match by date and compute comparisons
    // We need to map day_number to actual dates based on user's journey start
    // For now, use response created_at to approximate the date
    const comparisons: Array<{
      date: string;
      subjective: { quality: number };
      objective: {
        totalSleepMins: number;
        efficiency: number;
        deepSleepMins: number | null;
        remSleepMins: number | null;
      };
      gap: { gap: number; direction: string; magnitude: number };
    }> = [];

    for (const night of recentSleepData) {
      if (!night.total_sleep_mins || !night.sleep_efficiency) continue;

      // Find matching subjective response by date approximation
      // This is a simplified approach - in production, match by day_number + journey start
      const matchingResponse = qualityResponses.find((r) => {
        if (!r.created_at) return false;
        const responseDate = new Date(r.created_at).toISOString().split("T")[0];
        return responseDate === night.date;
      });

      if (matchingResponse?.response_number) {
        const subjectiveQuality = matchingResponse.response_number;
        const gap = calculatePerceptionGap(
          subjectiveQuality,
          night.sleep_efficiency,
          night.total_sleep_mins
        );

        comparisons.push({
          date: night.date,
          subjective: { quality: subjectiveQuality },
          objective: {
            totalSleepMins: night.total_sleep_mins,
            efficiency: night.sleep_efficiency,
            deepSleepMins: night.deep_sleep_mins ?? null,
            remSleepMins: night.rem_sleep_mins ?? null,
          },
          gap,
        });
      }
    }

    // 4. Calculate correlation if enough data
    let correlation: number | null = null;
    if (comparisons.length >= 7) {
      const subjective = comparisons.map((c) => c.subjective.quality);
      const objective = comparisons.map((c) =>
        normalizeObjectiveScore(
          c.objective.efficiency,
          c.objective.totalSleepMins
        )
      );
      correlation = Math.round(calculatePearsonCorrelation(subjective, objective) * 100) / 100;
    }

    // 5. Analyze gap trend
    let gapTrend: {
      avgGap: number;
      consistentUnderestimate: boolean;
      confidence: number;
    } | null = null;

    if (comparisons.length >= 5) {
      const gaps = comparisons.map((c) => c.gap.gap);
      const avgGap = average(gaps);
      const underestimates = gaps.filter((g) => g < -15).length;

      gapTrend = {
        avgGap: Math.round(avgGap * 10) / 10,
        consistentUnderestimate: underestimates / gaps.length > 0.6,
        confidence: Math.min(0.95, comparisons.length / 14),
      };
    }

    return {
      daysCount: recentSleepData.length,
      comparisonsCount: comparisons.length,
      comparisons: comparisons.slice(0, 7), // Last 7 for display
      lastNightSubjective: comparisons[0]?.subjective ?? null,
      lastNightObjective: comparisons[0]?.objective ?? null,
      lastNightDate: comparisons[0]?.date ?? null,
      correlation,
      gapTrend,
    };
  },
});

// ============================================
// Query: Detect Sleep Patterns
// ============================================

export const detectPatterns = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    // Fetch last 30 days of sleep data
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30);
    const cutoffString = cutoffDate.toISOString().split("T")[0];

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .collect();

    const recentData = sleepData.filter(
      (d) => d.date >= cutoffString && d.total_sleep_mins && d.sleep_efficiency
    );

    if (recentData.length < 7) {
      return null; // Not enough data for pattern detection
    }

    // 1. Workday vs Weekend Analysis
    const weekdayData = recentData.filter((d) => isWeekday(d.date));
    const weekendData = recentData.filter((d) => !isWeekday(d.date));

    let workdayWeekend: {
      workdayAvgSleep: number;
      weekendAvgSleep: number;
      workdayAvgDeep: number;
      weekendAvgDeep: number;
      workdayAvgEfficiency: number;
      weekendAvgEfficiency: number;
      sleepDifference: number;
      deepDifference: number;
    } | null = null;

    if (weekdayData.length >= 5 && weekendData.length >= 2) {
      const workdayAvgSleep = average(
        weekdayData.map((d) => d.total_sleep_mins!)
      );
      const weekendAvgSleep = average(
        weekendData.map((d) => d.total_sleep_mins!)
      );
      const workdayAvgDeep = average(
        weekdayData.map((d) => d.deep_sleep_mins ?? 0)
      );
      const weekendAvgDeep = average(
        weekendData.map((d) => d.deep_sleep_mins ?? 0)
      );

      workdayWeekend = {
        workdayAvgSleep: Math.round(workdayAvgSleep),
        weekendAvgSleep: Math.round(weekendAvgSleep),
        workdayAvgDeep: Math.round(workdayAvgDeep),
        weekendAvgDeep: Math.round(weekendAvgDeep),
        workdayAvgEfficiency: Math.round(
          average(weekdayData.map((d) => d.sleep_efficiency!))
        ),
        weekendAvgEfficiency: Math.round(
          average(weekendData.map((d) => d.sleep_efficiency!))
        ),
        sleepDifference: Math.round(weekendAvgSleep - workdayAvgSleep),
        deepDifference: Math.round(weekendAvgDeep - workdayAvgDeep),
      };
    }

    // 2. Optimal Bedtime Analysis
    // Group by bedtime hour and find which hour has lowest sleep latency
    let optimalBedtime: {
      time: string;
      avgLatencyMinutes: number;
      latencyDiff: number;
      confidence: number;
    } | null = null;

    const dataWithBedtime = recentData.filter(
      (d) => d.in_bed_time && d.sleep_latency_mins !== undefined
    );

    if (dataWithBedtime.length >= 7) {
      // Group by bedtime hour
      const byHour: Record<number, number[]> = {};
      for (const d of dataWithBedtime) {
        const hour = new Date(d.in_bed_time! * 1000).getHours();
        if (!byHour[hour]) byHour[hour] = [];
        byHour[hour].push(d.sleep_latency_mins!);
      }

      // Find hour with lowest average latency (needs at least 2 data points)
      let bestHour = -1;
      let bestLatency = Infinity;
      let overallAvgLatency = average(
        dataWithBedtime.map((d) => d.sleep_latency_mins!)
      );

      for (const [hour, latencies] of Object.entries(byHour)) {
        if (latencies.length >= 2) {
          const avgLatency = average(latencies);
          if (avgLatency < bestLatency) {
            bestLatency = avgLatency;
            bestHour = parseInt(hour);
          }
        }
      }

      if (bestHour >= 0 && bestLatency < overallAvgLatency - 5) {
        // Format hour to time string (e.g., "10:30 PM")
        const timeStr =
          bestHour === 0
            ? "12:00 AM"
            : bestHour < 12
              ? `${bestHour}:00 AM`
              : bestHour === 12
                ? "12:00 PM"
                : `${bestHour - 12}:00 PM`;

        optimalBedtime = {
          time: timeStr,
          avgLatencyMinutes: Math.round(bestLatency),
          latencyDiff: Math.round(overallAvgLatency - bestLatency),
          confidence: Math.min(0.9, (byHour[bestHour]?.length ?? 0) / 5),
        };
      }
    }

    // 3. Sleep Stage Patterns
    const dataWithStages = recentData.filter(
      (d) =>
        d.deep_sleep_mins !== undefined &&
        d.rem_sleep_mins !== undefined &&
        d.total_sleep_mins
    );

    let sleepStages: {
      avgDeepPercent: number;
      avgRemPercent: number;
      avgLightPercent: number;
      deepBelowRecommended: boolean;
      remBelowRecommended: boolean;
    } | null = null;

    if (dataWithStages.length >= 5) {
      const deepPercents = dataWithStages.map(
        (d) => ((d.deep_sleep_mins ?? 0) / d.total_sleep_mins!) * 100
      );
      const remPercents = dataWithStages.map(
        (d) => ((d.rem_sleep_mins ?? 0) / d.total_sleep_mins!) * 100
      );
      const lightPercents = dataWithStages.map(
        (d) => ((d.light_sleep_mins ?? 0) / d.total_sleep_mins!) * 100
      );

      const avgDeep = average(deepPercents);
      const avgRem = average(remPercents);

      sleepStages = {
        avgDeepPercent: Math.round(avgDeep * 10) / 10,
        avgRemPercent: Math.round(avgRem * 10) / 10,
        avgLightPercent: Math.round(average(lightPercents) * 10) / 10,
        deepBelowRecommended: avgDeep < 13, // Recommended: 13-23%
        remBelowRecommended: avgRem < 20, // Recommended: 20-25%
      };
    }

    return {
      workdayWeekend,
      optimalBedtime,
      sleepStages,
      dataPoints: recentData.length,
    };
  },
});

// ============================================
// Query: Generate Actionable Insights
// ============================================

export const generateInsights = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const insights: Array<{
      id: string;
      type: string;
      title: string;
      text: string;
      confidence: number;
      actionable: boolean;
    }> = [];

    // Get patterns and perception data
    // Note: In production, these would be pre-computed and cached
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(30);

    if (sleepData.length < 5) {
      return []; // Not enough data for insights
    }

    // Filter for data with required fields
    const validData = sleepData.filter(
      (d) => d.total_sleep_mins && d.sleep_efficiency
    );

    // 1. Workday vs Weekend insight
    const weekdayData = validData.filter((d) => isWeekday(d.date));
    const weekendData = validData.filter((d) => !isWeekday(d.date));

    if (weekdayData.length >= 5 && weekendData.length >= 2) {
      const weekdayAvgDeep = average(
        weekdayData.map((d) => d.deep_sleep_mins ?? 0)
      );
      const weekendAvgDeep = average(
        weekendData.map((d) => d.deep_sleep_mins ?? 0)
      );

      if (weekdayAvgDeep > 0) {
        const deepDiffPercent = Math.round(
          ((weekendAvgDeep - weekdayAvgDeep) / weekdayAvgDeep) * 100
        );

        if (deepDiffPercent >= 15) {
          insights.push({
            id: "weekend_deep_sleep",
            type: "pattern",
            title: "Weekend Sleep Pattern",
            text: `Your deep sleep is ${deepDiffPercent}% better on weekends. Consider stress management or an earlier bedtime during the week.`,
            confidence: 0.78,
            actionable: true,
          });
        }

        if (deepDiffPercent <= -15) {
          insights.push({
            id: "weekday_deep_sleep",
            type: "pattern",
            title: "Weekday Sleep Advantage",
            text: `Your deep sleep is ${Math.abs(deepDiffPercent)}% better on weekdays. Your weekday routine seems to benefit your sleep quality.`,
            confidence: 0.78,
            actionable: false,
          });
        }
      }
    }

    // 2. Sleep latency insight
    const dataWithLatency = validData.filter(
      (d) => d.in_bed_time && d.sleep_latency_mins !== undefined
    );

    if (dataWithLatency.length >= 7) {
      // Group by bedtime hour
      const byHour: Record<number, number[]> = {};
      for (const d of dataWithLatency) {
        const hour = new Date(d.in_bed_time! * 1000).getHours();
        if (!byHour[hour]) byHour[hour] = [];
        byHour[hour].push(d.sleep_latency_mins!);
      }

      // Find optimal hour
      let bestHour = -1;
      let bestLatency = Infinity;
      const overallAvg = average(dataWithLatency.map((d) => d.sleep_latency_mins!));

      for (const [hour, latencies] of Object.entries(byHour)) {
        if (latencies.length >= 2) {
          const avgLatency = average(latencies);
          if (avgLatency < bestLatency) {
            bestLatency = avgLatency;
            bestHour = parseInt(hour);
          }
        }
      }

      const latencyDiff = Math.round(overallAvg - bestLatency);
      if (bestHour >= 0 && latencyDiff >= 10) {
        const timeStr =
          bestHour === 0
            ? "midnight"
            : bestHour < 12
              ? `${bestHour}:00 AM`
              : bestHour === 12
                ? "noon"
                : `${bestHour - 12}:00 PM`;

        insights.push({
          id: "bedtime_latency",
          type: "optimization",
          title: "Optimal Bedtime Found",
          text: `You fall asleep ${latencyDiff} minutes faster when going to bed around ${timeStr}.`,
          confidence: 0.85,
          actionable: true,
        });
      }
    }

    // 3. Sleep efficiency trend
    if (validData.length >= 10) {
      const recentEfficiency = average(
        validData.slice(0, 5).map((d) => d.sleep_efficiency!)
      );
      const olderEfficiency = average(
        validData.slice(5, 10).map((d) => d.sleep_efficiency!)
      );

      const efficiencyChange = Math.round(recentEfficiency - olderEfficiency);

      if (efficiencyChange >= 5) {
        insights.push({
          id: "efficiency_improving",
          type: "positive",
          title: "Sleep Efficiency Improving",
          text: `Your sleep efficiency has improved by ${efficiencyChange}% over the past week. Keep up the good habits!`,
          confidence: 0.8,
          actionable: false,
        });
      } else if (efficiencyChange <= -5) {
        insights.push({
          id: "efficiency_declining",
          type: "warning",
          title: "Sleep Efficiency Declining",
          text: `Your sleep efficiency has decreased by ${Math.abs(efficiencyChange)}% recently. Consider reviewing your sleep environment or pre-bed routine.`,
          confidence: 0.8,
          actionable: true,
        });
      }
    }

    // 4. Check for perception gap (requires subjective data)
    const qualityResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("question_id"), "SD_SLEEP_QUALITY"))
      .take(14);

    if (qualityResponses.length >= 5) {
      // Simple check: count how often subjective < objective
      let underestimates = 0;
      let total = 0;

      for (const response of qualityResponses) {
        if (!response.response_number || !response.created_at) continue;

        const responseDate = new Date(response.created_at)
          .toISOString()
          .split("T")[0];
        const matchingSleep = validData.find((d) => d.date === responseDate);

        if (matchingSleep) {
          const normalizedSubjective = response.response_number * 10;
          const objectiveScore = normalizeObjectiveScore(
            matchingSleep.sleep_efficiency!,
            matchingSleep.total_sleep_mins!
          );

          if (normalizedSubjective < objectiveScore - 15) {
            underestimates++;
          }
          total++;
        }
      }

      if (total >= 5 && underestimates / total > 0.6) {
        insights.push({
          id: "perception_gap",
          type: "cognitive",
          title: "Sleep Perception Gap",
          text: "You tend to rate your sleep lower than your objective metrics suggest. Your sleep may be better than you think!",
          confidence: Math.min(0.9, total / 10),
          actionable: true,
        });
      }
    }

    // Sort by confidence (highest first)
    insights.sort((a, b) => b.confidence - a.confidence);

    return insights;
  },
});

// ============================================
// Query: Get Dashboard Summary
// ============================================

export const getDashboardSummary = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    // Get last 7 days of sleep data
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 7);
    const cutoffString = cutoffDate.toISOString().split("T")[0];

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(30);

    const recentData = sleepData.filter((d) => d.date >= cutoffString);
    const allValidData = sleepData.filter(
      (d) => d.total_sleep_mins && d.sleep_efficiency
    );

    // Calculate averages for last 7 days
    const last7Days = recentData.filter(
      (d) => d.total_sleep_mins && d.sleep_efficiency
    );

    let weeklyAvg = {
      sleepMins: 0,
      efficiency: 0,
      deepMins: 0,
      remMins: 0,
    };

    if (last7Days.length > 0) {
      weeklyAvg = {
        sleepMins: Math.round(average(last7Days.map((d) => d.total_sleep_mins!))),
        efficiency: Math.round(average(last7Days.map((d) => d.sleep_efficiency!))),
        deepMins: Math.round(average(last7Days.map((d) => d.deep_sleep_mins ?? 0))),
        remMins: Math.round(average(last7Days.map((d) => d.rem_sleep_mins ?? 0))),
      };
    }

    // Get last night's data
    const lastNight = recentData[0];

    // Check if we have enough data for insights
    const hasEnoughForInsights = allValidData.length >= 5;
    const hasEnoughForPatterns = allValidData.length >= 7;

    return {
      daysOfData: allValidData.length,
      hasEnoughForInsights,
      hasEnoughForPatterns,
      daysUntilInsights: hasEnoughForInsights ? 0 : 5 - allValidData.length,
      daysUntilPatterns: hasEnoughForPatterns ? 0 : 7 - allValidData.length,
      weeklyAverage: weeklyAvg,
      lastNight: lastNight
        ? {
            date: lastNight.date,
            totalSleepMins: lastNight.total_sleep_mins,
            efficiency: lastNight.sleep_efficiency,
            deepMins: lastNight.deep_sleep_mins,
            remMins: lastNight.rem_sleep_mins,
            primarySource: lastNight.primary_source,
          }
        : null,
      lastSyncTime: lastNight?.synced_at ?? null,
    };
  },
});

// ============================================
// Mutation: Compute and Store Perception Gap
// ============================================

export const computePerceptionGap = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),
  },
  handler: async (ctx, args) => {
    // Get objective data for this date
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("date", args.date)
      )
      .first();

    // Get subjective data for this date
    const qualityResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("question_id"), "SD_SLEEP_QUALITY"))
      .collect();

    // Find matching response by date
    const matchingResponse = qualityResponse.find((r) => {
      if (!r.created_at) return false;
      const responseDate = new Date(r.created_at).toISOString().split("T")[0];
      return responseDate === args.date;
    });

    if (!sleepData || !matchingResponse?.response_number) {
      return null; // Can't compute without both data sources
    }

    // Calculate gap
    const gap = calculatePerceptionGap(
      matchingResponse.response_number,
      sleepData.sleep_efficiency ?? 0,
      sleepData.total_sleep_mins ?? 0
    );

    // Check if record exists
    const existing = await ctx.db
      .query("perception_gaps")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("date", args.date)
      )
      .first();

    const gapData = {
      user_id: args.userId,
      date: args.date,
      subjective_quality: matchingResponse.response_number,
      objective_total_sleep_mins: sleepData.total_sleep_mins,
      objective_efficiency: sleepData.sleep_efficiency,
      objective_deep_mins: sleepData.deep_sleep_mins,
      objective_rem_mins: sleepData.rem_sleep_mins,
      objective_latency_mins: sleepData.sleep_latency_mins,
      objective_awakenings: sleepData.interruptions_count,
      gap_score: gap.gap,
      gap_direction: gap.direction,
      computed_at: Date.now(),
    };

    if (existing) {
      await ctx.db.patch(existing._id, gapData);
      return existing._id;
    } else {
      return await ctx.db.insert("perception_gaps", gapData);
    }
  },
});
