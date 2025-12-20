/**
 * Micro-Cohort System - "People Like You"
 * Dynamic peer groups for personalized comparisons
 *
 * This system creates meaningful cohorts based on:
 * - Demographics (age, gender)
 * - Life stage (student, parent, retired, etc.)
 * - Work pattern (9-5, shift work, high stress, etc.)
 * - Primary sleep gateway (insomnia, apnea, anxiety, etc.)
 * - Chronotype (early bird, night owl, etc.)
 * - Activity level (low, moderate, high)
 * - Family situation (young children, teens, etc.)
 *
 * PRIVACY: All comparisons are anonymous and aggregate
 */

import { v } from "convex/values";
import { query, mutation, internalQuery, internalMutation } from "./_generated/server";
import { Id, Doc } from "./_generated/dataModel";
import { createHash } from "crypto";

// ============================================
// Types
// ============================================

export interface CohortDimensions {
  age_bracket: string;
  gender?: string;
  life_stage?: string;
  work_pattern?: string;
  primary_gateway?: string;
  chronotype?: string;
  activity_level?: string;
  family_situation?: string;
}

export interface CohortExtractionResult {
  dimensions: CohortDimensions;
  cohort_hash: string;
  confidence: number; // 0-100 how much data we have
  missing_dimensions: string[];
}

// ============================================
// Age Bracket Helpers
// ============================================

function calculateAgeBracket(birthYear?: number): string {
  if (!birthYear) return "unknown";

  const currentYear = new Date().getFullYear();
  const age = currentYear - birthYear;

  if (age < 20) return "under_20";
  if (age < 30) return "20-30";
  if (age < 40) return "30-40";
  if (age < 50) return "40-50";
  if (age < 60) return "50-60";
  return "60+";
}

// ============================================
// Cohort Hash Generation
// ============================================

function generateCohortHash(dimensions: CohortDimensions): string {
  // Create a consistent hash from the dimension values
  // Only include non-undefined dimensions for the hash
  const hashInput = [
    dimensions.age_bracket,
    dimensions.gender || "_",
    dimensions.life_stage || "_",
    dimensions.work_pattern || "_",
    dimensions.primary_gateway || "_",
    dimensions.chronotype || "_",
    dimensions.activity_level || "_",
    dimensions.family_situation || "_",
  ].join("|");

  // Create a short hash for database efficiency
  // Using a simple hash since we're in Convex runtime (no crypto)
  let hash = 0;
  for (let i = 0; i < hashInput.length; i++) {
    const char = hashInput.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return `cohort_${Math.abs(hash).toString(36)}`;
}

// ============================================
// Dimension Extraction from User Data
// ============================================

/**
 * Extract cohort dimensions from user data
 * Combines user profile, questionnaire responses, gateway states, and health data
 */
export const extractCohortDimensions = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, args): Promise<CohortExtractionResult | null> => {
    const user = await ctx.db.get(args.userId);
    if (!user) return null;

    const missingDimensions: string[] = [];
    let dataPointsFound = 0;
    const totalPossiblePoints = 8; // Number of dimension types

    // 1. Age Bracket (from user profile)
    const age_bracket = calculateAgeBracket(user.birth_year);
    if (age_bracket !== "unknown") dataPointsFound++;
    else missingDimensions.push("age_bracket");

    // 2. Gender (from user profile)
    const gender = user.gender?.toLowerCase();
    if (gender) dataPointsFound++;
    else missingDimensions.push("gender");

    // 3. Get user's gateway states
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("triggered"), true))
      .collect();

    // Determine primary gateway (most significant)
    const gatewayPriority = [
      "insomnia",
      "sleep_apnea",
      "mental_health",
      "perimenopause",
      "pain",
      "circadian",
      "lifestyle",
    ];

    let primary_gateway: string | undefined;
    for (const gw of gatewayPriority) {
      if (gatewayStates.some((g) => g.gateway_id === gw)) {
        primary_gateway = gw;
        break;
      }
    }
    if (primary_gateway) dataPointsFound++;
    else if (gatewayStates.length === 0) missingDimensions.push("primary_gateway");

    // 4. Get questionnaire responses for life stage, work pattern, family
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Map responses by question_id for easy lookup
    const responseMap = new Map(responses.map((r) => [r.question_id, r]));

    // Life stage inference
    let life_stage: string | undefined;
    const occupationResponse = responseMap.get("D4_OCCUPATION");
    const ageNum = user.birth_year
      ? new Date().getFullYear() - user.birth_year
      : undefined;

    if (occupationResponse?.response_value) {
      const occupation = occupationResponse.response_value.toLowerCase();
      if (occupation.includes("student")) life_stage = "student";
      else if (occupation.includes("retired")) life_stage = "retired";
      else if (ageNum && ageNum < 30) life_stage = "early_career";
    }

    // Check for young children
    const youngChildrenResponse = responseMap.get("D4_YOUNG_CHILDREN");
    if (
      youngChildrenResponse?.response_value === "Yes" ||
      youngChildrenResponse?.response_value === "true"
    ) {
      life_stage = "parent_young";
    }

    if (life_stage) dataPointsFound++;
    else missingDimensions.push("life_stage");

    // 5. Work pattern
    let work_pattern: string | undefined;
    const dayTypeResponse = responseMap.get("SD_DAY_TYPE");
    const workScheduleResponse = responseMap.get("D4_WORK_SCHEDULE");

    if (workScheduleResponse?.response_value) {
      const schedule = workScheduleResponse.response_value.toLowerCase();
      if (schedule.includes("shift") || schedule.includes("rotating")) {
        work_pattern = "shift_work";
      } else if (schedule.includes("variable") || schedule.includes("irregular")) {
        work_pattern = "variable";
      } else if (schedule.includes("remote") || schedule.includes("home")) {
        work_pattern = "remote";
      } else {
        work_pattern = "9_to_5";
      }
    }

    // Check for high stress indicators
    const stressResponse = responseMap.get("D3_STRESS_LEVEL");
    if (stressResponse?.response_number && stressResponse.response_number >= 7) {
      work_pattern = work_pattern ? `${work_pattern}_high_stress` : "high_stress";
    }

    if (work_pattern) dataPointsFound++;
    else missingDimensions.push("work_pattern");

    // 6. Chronotype - from sleep timing patterns
    let chronotype: string | undefined;

    // Get recent sleep data
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(14);

    if (sleepData.length >= 5) {
      // Calculate average sleep time
      const sleepTimes = sleepData
        .filter((d) => d.asleep_time)
        .map((d) => {
          const date = new Date(d.asleep_time! * 1000);
          let hours = date.getHours() + date.getMinutes() / 60;
          // Normalize around midnight
          if (hours < 12) hours += 24;
          return hours;
        });

      if (sleepTimes.length >= 3) {
        const avgSleepHour =
          sleepTimes.reduce((a, b) => a + b, 0) / sleepTimes.length;

        // Calculate consistency (standard deviation)
        const variance =
          sleepTimes.reduce((sum, h) => sum + Math.pow(h - avgSleepHour, 2), 0) /
          sleepTimes.length;
        const stdDev = Math.sqrt(variance);

        if (stdDev > 2) {
          chronotype = "irregular";
        } else if (avgSleepHour < 22.5) {
          // Before 10:30 PM
          chronotype = "early_bird";
        } else if (avgSleepHour > 24.5) {
          // After 12:30 AM
          chronotype = "night_owl";
        } else {
          chronotype = "normal";
        }
        dataPointsFound++;
      }
    }

    if (!chronotype) missingDimensions.push("chronotype");

    // 7. Activity level - from HealthKit data
    let activity_level: string | undefined;

    const activityData = await ctx.db
      .query("user_activity")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(14);

    if (activityData.length >= 5) {
      const avgExerciseMins =
        activityData
          .filter((d) => d.exercise_mins !== undefined)
          .reduce((sum, d) => sum + (d.exercise_mins || 0), 0) /
        activityData.length;

      if (avgExerciseMins >= 45) {
        activity_level = "high";
      } else if (avgExerciseMins >= 20) {
        activity_level = "moderate";
      } else {
        activity_level = "low";
      }
      dataPointsFound++;
    }

    if (!activity_level) missingDimensions.push("activity_level");

    // 8. Family situation
    let family_situation: string | undefined;

    if (
      youngChildrenResponse?.response_value === "Yes" ||
      youngChildrenResponse?.response_value === "true"
    ) {
      family_situation = "young_children";
    } else {
      // Check for teens based on other indicators or age
      const dependentsResponse = responseMap.get("D4_DEPENDENTS");
      if (dependentsResponse?.response_value) {
        if (dependentsResponse.response_value.toLowerCase().includes("teen")) {
          family_situation = "teens";
        } else if (
          dependentsResponse.response_value.toLowerCase() === "none" ||
          dependentsResponse.response_value === "0"
        ) {
          family_situation = "no_kids";
        }
      }
    }

    if (family_situation) dataPointsFound++;
    else missingDimensions.push("family_situation");

    // Build the dimensions object
    const dimensions: CohortDimensions = {
      age_bracket,
      gender,
      life_stage,
      work_pattern,
      primary_gateway,
      chronotype,
      activity_level,
      family_situation,
    };

    // Calculate confidence based on how many dimensions we have
    const confidence = Math.round((dataPointsFound / totalPossiblePoints) * 100);

    // Generate cohort hash
    const cohort_hash = generateCohortHash(dimensions);

    return {
      dimensions,
      cohort_hash,
      confidence,
      missing_dimensions: missingDimensions,
    };
  },
});

// ============================================
// Cohort Membership Management
// ============================================

/**
 * Update user's cohort membership
 * Called when user data changes (new responses, health data sync, etc.)
 */
export const updateUserCohortMembership = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Extract dimensions
    const extraction = await ctx.runQuery(
      // @ts-ignore - internal query reference
      "microCohorts:extractCohortDimensions" as any,
      { userId: args.userId }
    );

    if (!extraction) return null;

    const { dimensions, cohort_hash, confidence } = extraction;

    // Check if membership already exists
    const existing = await ctx.db
      .query("user_cohort_memberships")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    // Count cohort size
    const cohortMembers = await ctx.db
      .query("user_cohort_memberships")
      .withIndex("by_cohort_hash", (q) => q.eq("cohort_hash", cohort_hash))
      .collect();

    const cohort_size = cohortMembers.length + (existing?.cohort_hash !== cohort_hash ? 1 : 0);

    const now = Date.now();

    if (existing) {
      // Update existing membership
      await ctx.db.patch(existing._id, {
        cohort_hash,
        age_bracket: dimensions.age_bracket,
        gender: dimensions.gender,
        life_stage: dimensions.life_stage,
        work_pattern: dimensions.work_pattern,
        primary_gateway: dimensions.primary_gateway,
        chronotype: dimensions.chronotype,
        activity_level: dimensions.activity_level,
        family_situation: dimensions.family_situation,
        cohort_dimensions_json: JSON.stringify(dimensions),
        cohort_size,
        updated_at: now,
      });
      return existing._id;
    } else {
      // Create new membership
      const id = await ctx.db.insert("user_cohort_memberships", {
        user_id: args.userId,
        cohort_hash,
        age_bracket: dimensions.age_bracket,
        gender: dimensions.gender,
        life_stage: dimensions.life_stage,
        work_pattern: dimensions.work_pattern,
        primary_gateway: dimensions.primary_gateway,
        chronotype: dimensions.chronotype,
        activity_level: dimensions.activity_level,
        family_situation: dimensions.family_situation,
        cohort_dimensions_json: JSON.stringify(dimensions),
        cohort_size,
        created_at: now,
        updated_at: now,
      });
      return id;
    }
  },
});

// ============================================
// Cohort Percentile Queries
// ============================================

/**
 * Get user's percentile within their cohort for a specific metric
 */
export const getCohortPercentile = query({
  args: {
    userId: v.id("users"),
    metricType: v.string(), // "isi", "sleep_efficiency", "sleep_duration", "consistency"
  },
  handler: async (ctx, args) => {
    // Get user's cohort membership
    const membership = await ctx.db
      .query("user_cohort_memberships")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!membership) {
      return {
        percentile: null,
        cohort_size: 0,
        cohort_description: null,
        message: "Still learning about you...",
      };
    }

    // Get cohort aggregate stats
    const stats = await ctx.db
      .query("cohort_aggregate_stats")
      .withIndex("by_cohort_stat", (q) =>
        q.eq("cohort_hash", membership.cohort_hash).eq("stat_type", args.metricType)
      )
      .first();

    if (!stats || stats.sample_size < 10) {
      return {
        percentile: null,
        cohort_size: membership.cohort_size,
        cohort_description: buildCohortDescription(membership),
        message: "Collecting more data from people like you...",
      };
    }

    // Get user's actual metric value for comparison
    let userValue: number | null = null;

    if (args.metricType === "isi") {
      const score = await ctx.db
        .query("questionnaire_scores")
        .withIndex("by_user_questionnaire", (q) =>
          q.eq("user_id", args.userId).eq("questionnaire_name", "ISI")
        )
        .order("desc")
        .first();
      userValue = score?.score ?? null;
    } else if (args.metricType === "sleep_efficiency") {
      const sleepData = await ctx.db
        .query("user_sleep_data")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .order("desc")
        .take(7);
      if (sleepData.length >= 3) {
        const validEfficiency = sleepData.filter((d) => d.sleep_efficiency !== undefined);
        if (validEfficiency.length > 0) {
          userValue =
            validEfficiency.reduce((sum, d) => sum + (d.sleep_efficiency || 0), 0) /
            validEfficiency.length;
        }
      }
    } else if (args.metricType === "sleep_duration") {
      const sleepData = await ctx.db
        .query("user_sleep_data")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .order("desc")
        .take(7);
      if (sleepData.length >= 3) {
        const validDuration = sleepData.filter((d) => d.total_sleep_mins !== undefined);
        if (validDuration.length > 0) {
          userValue =
            validDuration.reduce((sum, d) => sum + (d.total_sleep_mins || 0), 0) /
            validDuration.length;
        }
      }
    }

    if (userValue === null) {
      return {
        percentile: null,
        cohort_size: membership.cohort_size,
        cohort_description: buildCohortDescription(membership),
        message: "Need more data to compare...",
      };
    }

    // Parse the distribution from stats
    const statData = JSON.parse(stats.stat_data_json) as {
      percentiles: { p10: number; p25: number; p50: number; p75: number; p90: number };
      mean: number;
      count: number;
    };

    // Calculate user's percentile
    let percentile: number;
    const { p10, p25, p50, p75, p90 } = statData.percentiles;

    // For ISI, lower is better
    if (args.metricType === "isi") {
      if (userValue <= p10) percentile = 90;
      else if (userValue <= p25) percentile = 75;
      else if (userValue <= p50) percentile = 50;
      else if (userValue <= p75) percentile = 25;
      else if (userValue <= p90) percentile = 10;
      else percentile = 5;
    } else {
      // For sleep efficiency and duration, higher is generally better
      if (userValue >= p90) percentile = 90;
      else if (userValue >= p75) percentile = 75;
      else if (userValue >= p50) percentile = 50;
      else if (userValue >= p25) percentile = 25;
      else if (userValue >= p10) percentile = 10;
      else percentile = 5;
    }

    return {
      percentile,
      cohort_size: stats.sample_size,
      cohort_description: buildCohortDescription(membership),
      user_value: userValue,
      cohort_mean: statData.mean,
      message: buildPercentileMessage(percentile, args.metricType, membership),
    };
  },
});

/**
 * Get full cohort comparison for user
 */
export const getFullCohortComparison = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const membership = await ctx.db
      .query("user_cohort_memberships")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!membership) {
      return {
        has_cohort: false,
        message: "Complete more of your journey to unlock cohort comparisons",
      };
    }

    // Get all relevant stats for this cohort
    const allStats = await ctx.db
      .query("cohort_aggregate_stats")
      .withIndex("by_cohort_hash", (q) => q.eq("cohort_hash", membership.cohort_hash))
      .collect();

    // Get intervention effectiveness for this cohort
    const interventionStats = await ctx.db
      .query("cohort_intervention_effectiveness")
      .withIndex("by_cohort", (q) => q.eq("cohort_hash", membership.cohort_hash))
      .collect();

    // Sort by success rate and take top 5
    const topInterventions = interventionStats
      .sort((a, b) => b.success_rate - a.success_rate)
      .slice(0, 5);

    return {
      has_cohort: true,
      cohort_description: buildCohortDescription(membership),
      cohort_size: membership.cohort_size,
      dimensions: JSON.parse(membership.cohort_dimensions_json),
      stats: allStats.map((s) => ({
        type: s.stat_type,
        data: JSON.parse(s.stat_data_json),
        sample_size: s.sample_size,
      })),
      top_interventions: topInterventions.map((i) => ({
        intervention_id: i.intervention_id,
        success_rate: i.success_rate,
        sample_size: i.sample_size,
      })),
      percentiles: {
        isi: membership.percentile_isi,
        sleep_efficiency: membership.percentile_sleep_efficiency,
        sleep_duration: membership.percentile_sleep_duration,
        consistency: membership.percentile_consistency,
      },
    };
  },
});

// ============================================
// Helper Functions
// ============================================

function buildCohortDescription(
  membership: Doc<"user_cohort_memberships">
): string {
  const parts: string[] = [];

  // Age and gender
  if (membership.age_bracket && membership.age_bracket !== "unknown") {
    if (membership.gender === "male") {
      parts.push(`men in their ${membership.age_bracket.replace("-", "s to ")}`);
    } else if (membership.gender === "female") {
      parts.push(`women in their ${membership.age_bracket.replace("-", "s to ")}`);
    } else {
      parts.push(`people aged ${membership.age_bracket}`);
    }
  }

  // Life stage or family situation
  if (membership.life_stage === "parent_young" || membership.family_situation === "young_children") {
    parts.push("with young children");
  } else if (membership.family_situation === "teens") {
    parts.push("with teenagers");
  } else if (membership.life_stage === "student") {
    parts.push("who are students");
  } else if (membership.life_stage === "retired") {
    parts.push("who are retired");
  }

  // Primary gateway
  if (membership.primary_gateway === "insomnia") {
    parts.push("managing insomnia");
  } else if (membership.primary_gateway === "sleep_apnea") {
    parts.push("at risk for sleep apnea");
  } else if (membership.primary_gateway === "mental_health") {
    parts.push("with sleep-mood connections");
  }

  // Activity level
  if (membership.activity_level === "high") {
    parts.push("who exercise regularly");
  }

  if (parts.length === 0) {
    return "users with similar profiles";
  }

  // Combine parts naturally
  if (parts.length === 1) {
    return parts[0];
  }

  return parts.slice(0, 2).join(" ");
}

function buildPercentileMessage(
  percentile: number,
  metricType: string,
  membership: Doc<"user_cohort_memberships">
): string {
  const cohortDesc = buildCohortDescription(membership);
  const count = membership.cohort_size;

  if (metricType === "isi") {
    if (percentile >= 75) {
      return `Among ${count} ${cohortDesc}, you're managing better than ${percentile}%.`;
    } else if (percentile >= 50) {
      return `You're in the middle of ${count} ${cohortDesc}. Room to improve!`;
    } else {
      return `Among ${cohortDesc}, your insomnia is more severe than average. We're here to help.`;
    }
  }

  if (metricType === "sleep_efficiency") {
    if (percentile >= 75) {
      return `Your sleep efficiency is in the top ${100 - percentile}% of ${cohortDesc}.`;
    } else if (percentile >= 50) {
      return `Your sleep efficiency is average for ${cohortDesc}.`;
    } else {
      return `There's room to improve your sleep efficiency compared to ${cohortDesc}.`;
    }
  }

  if (metricType === "sleep_duration") {
    if (percentile >= 75) {
      return `You're getting more sleep than ${percentile}% of ${cohortDesc}.`;
    } else if (percentile >= 50) {
      return `Your sleep duration is typical for ${cohortDesc}.`;
    } else {
      return `You're getting less sleep than most ${cohortDesc}.`;
    }
  }

  return `You're at the ${percentile}th percentile among ${cohortDesc}.`;
}

// ============================================
// Intervention Effectiveness by Cohort
// ============================================

/**
 * Get what works for people like the user
 */
export const getWhatWorksForCohort = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const membership = await ctx.db
      .query("user_cohort_memberships")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!membership) {
      return {
        recommendations: [],
        message: "Complete more of your journey to see what works for people like you",
      };
    }

    // Get intervention effectiveness for this cohort
    const effectiveness = await ctx.db
      .query("cohort_intervention_effectiveness")
      .withIndex("by_cohort", (q) => q.eq("cohort_hash", membership.cohort_hash))
      .collect();

    // Filter to only show those with meaningful sample sizes
    const validInterventions = effectiveness.filter((e) => e.sample_size >= 10);

    // Sort by success rate
    const sorted = validInterventions.sort((a, b) => b.success_rate - a.success_rate);

    // Get intervention details
    const recommendations = await Promise.all(
      sorted.slice(0, 5).map(async (eff) => {
        const intervention = await ctx.db
          .query("interventions")
          .withIndex("by_intervention_id", (q) =>
            q.eq("intervention_id", eff.intervention_id)
          )
          .first();

        return {
          intervention_id: eff.intervention_id,
          name: intervention?.name || eff.intervention_id,
          short_name: intervention?.short_name,
          success_rate: eff.success_rate,
          sample_size: eff.sample_size,
          avg_days_to_improvement: eff.avg_days_to_improvement,
        };
      })
    );

    const cohortDesc = buildCohortDescription(membership);

    return {
      recommendations,
      cohort_description: cohortDesc,
      cohort_size: membership.cohort_size,
      message: `Based on ${sorted.length > 0 ? sorted[0].sample_size : 0}+ ${cohortDesc}`,
    };
  },
});

// ============================================
// Solidarity Moments
// ============================================

/**
 * Get anonymous solidarity moment
 * "Right now, 2,847 people are lying awake just like you"
 */
export const getSolidarityMoment = query({
  args: {
    momentType: v.optional(v.string()), // "awake_now", "streak_milestone", "journey_complete"
    userId: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    const momentType = args.momentType || "awake_now";
    const now = Date.now();

    // Get cached moment if fresh
    const cached = await ctx.db
      .query("solidarity_moments")
      .withIndex("by_moment_type", (q) => q.eq("moment_type", momentType))
      .first();

    if (cached && cached.expires_at > now) {
      if (momentType === "awake_now") {
        return {
          type: "awake_now",
          count: cached.awake_count,
          message: `Right now, ${(cached.awake_count || 0).toLocaleString()} people are awake just like you.`,
        };
      }

      if (momentType === "streak_milestone") {
        return {
          type: "streak_milestone",
          description: cached.milestone_cohort_description,
          achievement: cached.milestone_achievement,
          message: `${cached.milestone_cohort_description} just ${cached.milestone_achievement}`,
        };
      }

      if (momentType === "journey_complete") {
        return {
          type: "journey_complete",
          completed_count: cached.journeys_completed_this_month,
          improving_count: cached.improving_count,
          message: `${(cached.journeys_completed_this_month || 0).toLocaleString()} people completed their journey this month. ${(cached.improving_count || 0).toLocaleString()} are already seeing improvement.`,
        };
      }
    }

    // Return default message if no cached data
    return {
      type: momentType,
      message: "You're not alone on this journey.",
    };
  },
});
