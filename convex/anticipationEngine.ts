/**
 * Anticipation Engine - Predictive Sleep Alerts
 * "What's Coming" - not just descriptive, but predictive
 *
 * Provides:
 * - Tonight's sleep forecast based on patterns
 * - Day-of-week predictions (Sunday anxiety, etc.)
 * - Lifecycle-aware messaging (Day 1-7 vs Day 8-14 vs treatment)
 * - Early warning for challenging nights
 */

import { v } from "convex/values";
import { query, mutation, internalQuery, internalMutation } from "./_generated/server";
import { Id } from "./_generated/dataModel";

// ============================================
// Types
// ============================================

export interface SleepForecast {
  prediction_type: "favorable" | "challenging" | "neutral";
  confidence: number; // 0-100
  factors: ForecastFactor[];
  recommendations: string[];
  message: string;
}

export interface ForecastFactor {
  factor_id: string;
  factor_name: string;
  impact: "positive" | "negative" | "neutral";
  weight: number; // 0-100
  description: string;
}

// ============================================
// Tonight's Forecast
// ============================================

/**
 * Get tonight's sleep forecast for a user
 */
export const getTonightsForecast = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args): Promise<SleepForecast | null> => {
    const user = await ctx.db.get(args.userId);
    if (!user) return null;

    const now = new Date();
    const dayOfWeek = now.getDay(); // 0 = Sunday
    const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

    const factors: ForecastFactor[] = [];
    let positiveWeight = 0;
    let negativeWeight = 0;

    // 1. Day of week analysis
    const dayFactor = await analyzeDayOfWeekPattern(ctx, args.userId, dayOfWeek);
    if (dayFactor) {
      factors.push(dayFactor);
      if (dayFactor.impact === "negative") negativeWeight += dayFactor.weight;
      else if (dayFactor.impact === "positive") positiveWeight += dayFactor.weight;
    }

    // 2. Recent activity analysis
    const activityFactor = await analyzeRecentActivity(ctx, args.userId);
    if (activityFactor) {
      factors.push(activityFactor);
      if (activityFactor.impact === "negative") negativeWeight += activityFactor.weight;
      else if (activityFactor.impact === "positive") positiveWeight += activityFactor.weight;
    }

    // 3. Stress/anxiety indicators
    const stressFactor = await analyzeStressIndicators(ctx, args.userId);
    if (stressFactor) {
      factors.push(stressFactor);
      if (stressFactor.impact === "negative") negativeWeight += stressFactor.weight;
      else if (stressFactor.impact === "positive") positiveWeight += stressFactor.weight;
    }

    // 4. Sleep pattern consistency
    const consistencyFactor = await analyzeConsistency(ctx, args.userId);
    if (consistencyFactor) {
      factors.push(consistencyFactor);
      if (consistencyFactor.impact === "negative") negativeWeight += consistencyFactor.weight;
      else if (consistencyFactor.impact === "positive") positiveWeight += consistencyFactor.weight;
    }

    // 5. Weekend/weekday context
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6 || dayOfWeek === 5; // Fri-Sun
    const weekendFactor = await analyzeWeekendContext(ctx, args.userId, isWeekend);
    if (weekendFactor) {
      factors.push(weekendFactor);
      if (weekendFactor.impact === "negative") negativeWeight += weekendFactor.weight;
    }

    // Calculate prediction type
    const netScore = positiveWeight - negativeWeight;
    let prediction_type: "favorable" | "challenging" | "neutral";
    let message: string;

    if (netScore >= 20) {
      prediction_type = "favorable";
      message = "Tonight looks good for quality sleep.";
    } else if (netScore <= -20) {
      prediction_type = "challenging";
      message = "Tonight might be more challenging based on your patterns.";
    } else {
      prediction_type = "neutral";
      message = "No strong indicators for tonight—stick to your routine.";
    }

    // Generate recommendations based on negative factors
    const recommendations = generateRecommendations(factors, prediction_type);

    // Calculate confidence based on data quality
    const dataPoints = factors.filter((f) => f.weight > 0).length;
    const confidence = Math.min(90, 40 + dataPoints * 12);

    return {
      prediction_type,
      confidence,
      factors: factors.sort((a, b) => b.weight - a.weight),
      recommendations,
      message,
    };
  },
});

// ============================================
// Factor Analysis Functions
// ============================================

async function analyzeDayOfWeekPattern(
  ctx: any,
  userId: Id<"users">,
  dayOfWeek: number
): Promise<ForecastFactor | null> {
  const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

  // Get last 4 weeks of sleep data for this day
  const sleepData = await ctx.db
    .query("user_sleep_data")
    .withIndex("by_user", (q: any) => q.eq("user_id", userId))
    .order("desc")
    .take(28);

  const thisDayData = sleepData.filter((d: { date: string }) => {
    const date = new Date(d.date);
    return date.getDay() === dayOfWeek;
  });

  if (thisDayData.length < 2) return null;

  // Calculate average efficiency for this day
  const avgEfficiency =
    thisDayData
      .filter((d: { sleep_efficiency?: number }) => d.sleep_efficiency !== undefined)
      .reduce((sum: number, d: { sleep_efficiency?: number }) => sum + (d.sleep_efficiency || 0), 0) /
    thisDayData.length;

  // Calculate overall average
  const overallAvg =
    sleepData
      .filter((d: { sleep_efficiency?: number }) => d.sleep_efficiency !== undefined)
      .reduce((sum: number, d: { sleep_efficiency?: number }) => sum + (d.sleep_efficiency || 0), 0) /
    sleepData.length;

  const difference = avgEfficiency - overallAvg;

  // Sunday/Monday often challenging
  if (dayOfWeek === 0 || dayOfWeek === 1) {
    if (difference < -5) {
      return {
        factor_id: "day_pattern",
        factor_name: `${dayNames[dayOfWeek]} Pattern`,
        impact: "negative",
        weight: 25,
        description:
          dayOfWeek === 0
            ? "Sundays are typically your hardest night (anticipatory anxiety before the week)"
            : "Mondays often carry lingering weekend schedule disruption",
      };
    }
  }

  if (Math.abs(difference) >= 5) {
    return {
      factor_id: "day_pattern",
      factor_name: `${dayNames[dayOfWeek]} Pattern`,
      impact: difference > 0 ? "positive" : "negative",
      weight: Math.min(30, Math.abs(difference) * 3),
      description:
        difference > 0
          ? `${dayNames[dayOfWeek]}s are typically one of your better nights`
          : `${dayNames[dayOfWeek]}s tend to be harder for you`,
    };
  }

  return null;
}

async function analyzeRecentActivity(
  ctx: any,
  userId: Id<"users">
): Promise<ForecastFactor | null> {
  // Get today's activity data
  const today = new Date().toISOString().split("T")[0];
  const activityData = await ctx.db
    .query("user_activity")
    .withIndex("by_user_date", (q: any) => q.eq("user_id", userId).eq("date", today))
    .first();

  if (!activityData) return null;

  const exerciseMins = activityData.exercise_mins || 0;
  const currentHour = new Date().getHours();

  // Late evening exercise (after 6pm) can disrupt sleep
  if (exerciseMins > 30 && currentHour >= 18) {
    return {
      factor_id: "late_exercise",
      factor_name: "Evening Exercise",
      impact: "negative",
      weight: 20,
      description: "Intense exercise late in the day can delay sleep onset",
    };
  }

  // Morning/afternoon exercise is beneficial
  if (exerciseMins >= 30 && currentHour < 18) {
    return {
      factor_id: "good_exercise",
      factor_name: "Daytime Activity",
      impact: "positive",
      weight: 20,
      description: "Your physical activity today should help with sleep tonight",
    };
  }

  return null;
}

async function analyzeStressIndicators(
  ctx: any,
  userId: Id<"users">
): Promise<ForecastFactor | null> {
  // Check for anxiety/stress gateway
  const anxietyGateway = await ctx.db
    .query("user_gateway_states")
    .withIndex("by_user_gateway", (q: any) =>
      q.eq("user_id", userId).eq("gateway_id", "mental_health")
    )
    .first();

  // Check recent perception gaps for stress indicators
  const recentGaps = await ctx.db
    .query("perception_gaps")
    .withIndex("by_user", (q: any) => q.eq("user_id", userId))
    .order("desc")
    .take(3);

  // If consistently rating sleep poorly despite decent efficiency
  const stressPattern = recentGaps.filter(
    (g: { subjective_quality?: number; objective_efficiency?: number }) =>
      g.subjective_quality !== undefined &&
      g.objective_efficiency !== undefined &&
      g.subjective_quality <= 4 &&
      g.objective_efficiency >= 75
  );

  if (stressPattern.length >= 2) {
    return {
      factor_id: "stress_perception",
      factor_name: "Stress Indicators",
      impact: "negative",
      weight: 20,
      description: "Your recent sleep perception suggests elevated stress",
    };
  }

  if (anxietyGateway?.triggered) {
    return {
      factor_id: "anxiety_gateway",
      factor_name: "Anxiety Awareness",
      impact: "neutral",
      weight: 15,
      description: "Be mindful of relaxation techniques tonight",
    };
  }

  return null;
}

async function analyzeConsistency(
  ctx: any,
  userId: Id<"users">
): Promise<ForecastFactor | null> {
  // Get recent sleep times
  const sleepData = await ctx.db
    .query("user_sleep_data")
    .withIndex("by_user", (q: any) => q.eq("user_id", userId))
    .order("desc")
    .take(7);

  if (sleepData.length < 3) return null;

  // Calculate bedtime variability
  const sleepTimes = sleepData
    .filter((d: { asleep_time?: number }) => d.asleep_time)
    .map((d: { asleep_time: number }) => {
      const date = new Date(d.asleep_time * 1000);
      let hours = date.getHours() + date.getMinutes() / 60;
      if (hours < 12) hours += 24;
      return hours;
    });

  if (sleepTimes.length < 3) return null;

  const mean = sleepTimes.reduce((a: number, b: number) => a + b, 0) / sleepTimes.length;
  const variance =
    sleepTimes.reduce((sum: number, t: number) => sum + Math.pow(t - mean, 2), 0) / sleepTimes.length;
  const stdDev = Math.sqrt(variance);

  if (stdDev > 1.5) {
    return {
      factor_id: "inconsistent_timing",
      factor_name: "Irregular Schedule",
      impact: "negative",
      weight: 25,
      description: "Your bedtime has varied significantly this week",
    };
  }

  if (stdDev < 0.5) {
    return {
      factor_id: "consistent_timing",
      factor_name: "Consistent Schedule",
      impact: "positive",
      weight: 20,
      description: "Your regular sleep schedule is working in your favor",
    };
  }

  return null;
}

async function analyzeWeekendContext(
  ctx: any,
  userId: Id<"users">,
  isWeekend: boolean
): Promise<ForecastFactor | null> {
  if (!isWeekend) return null;

  // Check if user tends to sleep later on weekends
  const sleepData = await ctx.db
    .query("user_sleep_data")
    .withIndex("by_user", (q: any) => q.eq("user_id", userId))
    .order("desc")
    .take(14);

  const weekendSleep = sleepData.filter((d: { date: string }) => {
    const date = new Date(d.date);
    const dow = date.getDay();
    return dow === 0 || dow === 6;
  });

  const weekdaySleep = sleepData.filter((d: { date: string }) => {
    const date = new Date(d.date);
    const dow = date.getDay();
    return dow >= 1 && dow <= 5;
  });

  if (weekendSleep.length < 2 || weekdaySleep.length < 3) return null;

  // Compare wake times
  const avgWeekendWake =
    weekendSleep
      .filter((d: { wake_time?: number }) => d.wake_time)
      .reduce((sum: number, d: { wake_time: number }) => sum + d.wake_time, 0) / weekendSleep.length;

  const avgWeekdayWake =
    weekdaySleep
      .filter((d: { wake_time?: number }) => d.wake_time)
      .reduce((sum: number, d: { wake_time: number }) => sum + d.wake_time, 0) / weekdaySleep.length;

  const differenceMins = (avgWeekendWake - avgWeekdayWake) / 60;

  if (differenceMins > 60) {
    return {
      factor_id: "weekend_drift",
      factor_name: "Weekend Schedule Drift",
      impact: "negative",
      weight: 20,
      description: "Try to keep your wake time within 30 minutes of weekdays",
    };
  }

  return null;
}

function generateRecommendations(
  factors: ForecastFactor[],
  predictionType: string
): string[] {
  const recommendations: string[] = [];

  // Find negative factors and suggest mitigations
  const negativeFactors = factors.filter((f) => f.impact === "negative");

  for (const factor of negativeFactors) {
    switch (factor.factor_id) {
      case "day_pattern":
        if (factor.description.includes("Sunday")) {
          recommendations.push("Start your wind-down routine 30 minutes earlier tonight");
          recommendations.push("Write down tomorrow's tasks to clear your mind");
        }
        break;
      case "late_exercise":
        recommendations.push("Do some gentle stretching to help your body cool down");
        recommendations.push("Take a warm shower to accelerate body temperature drop");
        break;
      case "stress_perception":
        recommendations.push("Try 4-7-8 breathing before bed (inhale 4s, hold 7s, exhale 8s)");
        recommendations.push("Skip screens for the last hour before bed");
        break;
      case "inconsistent_timing":
        recommendations.push("Aim for a consistent bedtime tonight");
        break;
      case "weekend_drift":
        recommendations.push("Set an alarm for your usual weekday wake time tomorrow");
        break;
    }
  }

  // If no specific recommendations, add general ones
  if (recommendations.length === 0) {
    if (predictionType === "favorable") {
      recommendations.push("Maintain your usual routine—it's working well");
    } else {
      recommendations.push("Keep your bedroom cool (65-68°F)");
      recommendations.push("Avoid caffeine after noon");
    }
  }

  return recommendations.slice(0, 3); // Max 3 recommendations
}

// ============================================
// Lifecycle-Aware Messaging
// ============================================

/**
 * Get context-appropriate message based on user's journey phase
 */
export const getLifecycleMessage = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return null;

    const currentDay = user.current_day || 1;
    const daysSinceStart = Math.floor((Date.now() - user.started_at) / (1000 * 60 * 60 * 24));

    // Get journey status
    const journeyStatus = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const phase = journeyStatus?.phase || "intake";

    // Day 1-3: Data collection phase
    if (currentDay <= 3) {
      return {
        phase: "discovery",
        title: "Learning About You",
        message: "We're gathering data to understand your unique sleep patterns. Each night teaches us something new.",
        motivation: `${3 - currentDay + 1} more nights until we can identify your first patterns`,
        progress_text: "Building your sleep profile...",
      };
    }

    // Day 4-7: Patterns emerging
    if (currentDay <= 7) {
      return {
        phase: "patterns",
        title: "Patterns Emerging",
        message: "We're seeing your rhythm take shape. A few more nights will confirm what we're observing.",
        motivation: `${7 - currentDay + 1} more nights to complete your core assessment`,
        progress_text: "Analyzing your sleep signature...",
      };
    }

    // Day 8-14: Insights unlocking
    if (currentDay <= 14) {
      return {
        phase: "insights",
        title: "Your Sleep Fingerprint",
        message: "Your personalized sleep profile is taking shape. We can now see what makes your sleep unique.",
        motivation: phase === "intake" ? "Completing your full assessment" : undefined,
        progress_text: "Refining your personalized insights...",
      };
    }

    // Day 14+: Treatment phase
    if (phase === "treatment_active") {
      return {
        phase: "treatment",
        title: "Your Treatment Journey",
        message: "You're actively working on improving your sleep with personalized interventions.",
        motivation: undefined,
        progress_text: "Track your progress and stay consistent",
      };
    }

    // Post-assessment waiting for treatment
    return {
      phase: "analysis",
      title: "Analysis Complete",
      message: "Your comprehensive sleep profile is ready. Personalized recommendations are being prepared.",
      motivation: undefined,
      progress_text: "Preparing your treatment plan...",
    };
  },
});

/**
 * Get weekly progress summary
 */
export const getWeeklyProgress = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get last 7 days of sleep data
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const startDate = sevenDaysAgo.toISOString().split("T")[0];

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.gte(q.field("date"), startDate))
      .collect();

    if (sleepData.length < 3) {
      return {
        has_enough_data: false,
        message: "Keep logging to see your weekly trends",
      };
    }

    // Calculate week's metrics
    const avgEfficiency =
      sleepData
        .filter((d) => d.sleep_efficiency !== undefined)
        .reduce((sum, d) => sum + (d.sleep_efficiency || 0), 0) / sleepData.length;

    const avgDuration =
      sleepData
        .filter((d) => d.total_sleep_mins !== undefined)
        .reduce((sum, d) => sum + (d.total_sleep_mins || 0), 0) / sleepData.length;

    // Get previous week for comparison
    const twoWeeksAgo = new Date();
    twoWeeksAgo.setDate(twoWeeksAgo.getDate() - 14);
    const prevStartDate = twoWeeksAgo.toISOString().split("T")[0];

    const prevWeekData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.and(q.gte(q.field("date"), prevStartDate), q.lt(q.field("date"), startDate)))
      .collect();

    let efficiencyChange: number | undefined;
    let durationChange: number | undefined;

    if (prevWeekData.length >= 3) {
      const prevAvgEfficiency =
        prevWeekData
          .filter((d) => d.sleep_efficiency !== undefined)
          .reduce((sum, d) => sum + (d.sleep_efficiency || 0), 0) / prevWeekData.length;

      const prevAvgDuration =
        prevWeekData
          .filter((d) => d.total_sleep_mins !== undefined)
          .reduce((sum, d) => sum + (d.total_sleep_mins || 0), 0) / prevWeekData.length;

      efficiencyChange = avgEfficiency - prevAvgEfficiency;
      durationChange = avgDuration - prevAvgDuration;
    }

    // Generate summary message
    let message: string;
    if (efficiencyChange !== undefined && efficiencyChange > 3) {
      message = `Great progress! Your sleep efficiency improved by ${Math.round(efficiencyChange)}% this week.`;
    } else if (efficiencyChange !== undefined && efficiencyChange < -3) {
      message = `This week was a bit harder. That's normal—sleep isn't linear. Let's identify what changed.`;
    } else {
      message = "You're maintaining steady progress. Consistency is key.";
    }

    return {
      has_enough_data: true,
      days_logged: sleepData.length,
      avg_efficiency: Math.round(avgEfficiency),
      avg_duration_hours: Math.round(avgDuration / 60 * 10) / 10,
      efficiency_change: efficiencyChange !== undefined ? Math.round(efficiencyChange) : undefined,
      duration_change_mins: durationChange !== undefined ? Math.round(durationChange) : undefined,
      message,
      trend: efficiencyChange !== undefined ? (efficiencyChange > 2 ? "improving" : efficiencyChange < -2 ? "declining" : "stable") : undefined,
    };
  },
});
