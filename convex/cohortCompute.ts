/**
 * Cohort Statistics Computation
 * Scheduled job to compute aggregate statistics for each cohort
 *
 * Runs nightly to update:
 * - Cohort aggregate stats (percentile distributions)
 * - User percentiles within cohorts
 * - Intervention effectiveness by cohort
 * - Solidarity moment data
 */

import { v } from "convex/values";
import { internalMutation, internalQuery, action } from "./_generated/server";
import { internal } from "./_generated/api";
import { Id, Doc } from "./_generated/dataModel";

// ============================================
// Cohort Statistics Computation
// ============================================

/**
 * Compute aggregate statistics for a cohort
 */
export const computeCohortStats = internalMutation({
  args: {
    cohort_hash: v.string(),
    stat_type: v.string(), // "isi", "sleep_efficiency", "sleep_duration"
  },
  handler: async (ctx, args) => {
    // Get all users in this cohort
    const cohortMembers = await ctx.db
      .query("user_cohort_memberships")
      .withIndex("by_cohort_hash", (q) => q.eq("cohort_hash", args.cohort_hash))
      .collect();

    if (cohortMembers.length < 5) {
      // Not enough members for meaningful stats
      return null;
    }

    // Collect values for this stat type
    const values: number[] = [];

    for (const member of cohortMembers) {
      let value: number | null = null;

      if (args.stat_type === "isi") {
        const score = await ctx.db
          .query("questionnaire_scores")
          .withIndex("by_user_questionnaire", (q) =>
            q.eq("user_id", member.user_id).eq("questionnaire_name", "ISI")
          )
          .order("desc")
          .first();
        value = score?.score ?? null;
      } else if (args.stat_type === "sleep_efficiency") {
        const sleepData = await ctx.db
          .query("user_sleep_data")
          .withIndex("by_user", (q) => q.eq("user_id", member.user_id))
          .order("desc")
          .take(7);

        const validData = sleepData.filter((d) => d.sleep_efficiency !== undefined);
        if (validData.length >= 3) {
          value =
            validData.reduce((sum, d) => sum + (d.sleep_efficiency || 0), 0) /
            validData.length;
        }
      } else if (args.stat_type === "sleep_duration") {
        const sleepData = await ctx.db
          .query("user_sleep_data")
          .withIndex("by_user", (q) => q.eq("user_id", member.user_id))
          .order("desc")
          .take(7);

        const validData = sleepData.filter((d) => d.total_sleep_mins !== undefined);
        if (validData.length >= 3) {
          value =
            validData.reduce((sum, d) => sum + (d.total_sleep_mins || 0), 0) /
            validData.length;
        }
      }

      if (value !== null) {
        values.push(value);
      }
    }

    if (values.length < 5) {
      return null;
    }

    // Sort values for percentile calculation
    values.sort((a, b) => a - b);

    // Calculate statistics
    const mean = values.reduce((a, b) => a + b, 0) / values.length;
    const p10 = values[Math.floor(values.length * 0.1)];
    const p25 = values[Math.floor(values.length * 0.25)];
    const p50 = values[Math.floor(values.length * 0.5)];
    const p75 = values[Math.floor(values.length * 0.75)];
    const p90 = values[Math.floor(values.length * 0.9)];

    const statData = {
      percentiles: { p10, p25, p50, p75, p90 },
      mean,
      count: values.length,
      min: values[0],
      max: values[values.length - 1],
    };

    // Get cohort info for denormalization
    const firstMember = cohortMembers[0];

    // Check if stat already exists
    const existing = await ctx.db
      .query("cohort_aggregate_stats")
      .withIndex("by_cohort_stat", (q) =>
        q.eq("cohort_hash", args.cohort_hash).eq("stat_type", args.stat_type)
      )
      .first();

    const now = Date.now();
    const expiresAt = now + 24 * 60 * 60 * 1000; // 24 hours

    if (existing) {
      await ctx.db.patch(existing._id, {
        stat_data_json: JSON.stringify(statData),
        sample_size: values.length,
        computed_at: now,
        expires_at: expiresAt,
      });
    } else {
      await ctx.db.insert("cohort_aggregate_stats", {
        cohort_hash: args.cohort_hash,
        age_bracket: firstMember.age_bracket,
        gender: firstMember.gender,
        primary_gateway: firstMember.primary_gateway,
        stat_type: args.stat_type,
        stat_data_json: JSON.stringify(statData),
        sample_size: values.length,
        confidence_level: Math.min(100, values.length * 2), // Simple confidence
        computed_at: now,
        expires_at: expiresAt,
      });
    }

    return { cohort_hash: args.cohort_hash, stat_type: args.stat_type, sample_size: values.length };
  },
});

/**
 * Update user percentiles within their cohort
 */
export const updateUserPercentiles = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get user's cohort membership
    const membership = await ctx.db
      .query("user_cohort_memberships")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!membership) return null;

    // Get cohort stats
    const isiStats = await ctx.db
      .query("cohort_aggregate_stats")
      .withIndex("by_cohort_stat", (q) =>
        q.eq("cohort_hash", membership.cohort_hash).eq("stat_type", "isi")
      )
      .first();

    const efficiencyStats = await ctx.db
      .query("cohort_aggregate_stats")
      .withIndex("by_cohort_stat", (q) =>
        q.eq("cohort_hash", membership.cohort_hash).eq("stat_type", "sleep_efficiency")
      )
      .first();

    const durationStats = await ctx.db
      .query("cohort_aggregate_stats")
      .withIndex("by_cohort_stat", (q) =>
        q.eq("cohort_hash", membership.cohort_hash).eq("stat_type", "sleep_duration")
      )
      .first();

    // Get user's values
    const userIsi = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user_questionnaire", (q) =>
        q.eq("user_id", args.userId).eq("questionnaire_name", "ISI")
      )
      .order("desc")
      .first();

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(7);

    let percentile_isi: number | undefined;
    let percentile_sleep_efficiency: number | undefined;
    let percentile_sleep_duration: number | undefined;

    // Calculate ISI percentile (lower is better)
    if (userIsi && isiStats) {
      const { p10, p25, p50, p75, p90 } = JSON.parse(isiStats.stat_data_json).percentiles;
      const score = userIsi.score;
      if (score <= p10) percentile_isi = 90;
      else if (score <= p25) percentile_isi = 75;
      else if (score <= p50) percentile_isi = 50;
      else if (score <= p75) percentile_isi = 25;
      else if (score <= p90) percentile_isi = 10;
      else percentile_isi = 5;
    }

    // Calculate sleep efficiency percentile (higher is better)
    if (sleepData.length >= 3 && efficiencyStats) {
      const validData = sleepData.filter((d) => d.sleep_efficiency !== undefined);
      if (validData.length > 0) {
        const avgEfficiency =
          validData.reduce((sum, d) => sum + (d.sleep_efficiency || 0), 0) / validData.length;
        const { p10, p25, p50, p75, p90 } = JSON.parse(efficiencyStats.stat_data_json).percentiles;

        if (avgEfficiency >= p90) percentile_sleep_efficiency = 90;
        else if (avgEfficiency >= p75) percentile_sleep_efficiency = 75;
        else if (avgEfficiency >= p50) percentile_sleep_efficiency = 50;
        else if (avgEfficiency >= p25) percentile_sleep_efficiency = 25;
        else if (avgEfficiency >= p10) percentile_sleep_efficiency = 10;
        else percentile_sleep_efficiency = 5;
      }
    }

    // Calculate sleep duration percentile
    if (sleepData.length >= 3 && durationStats) {
      const validData = sleepData.filter((d) => d.total_sleep_mins !== undefined);
      if (validData.length > 0) {
        const avgDuration =
          validData.reduce((sum, d) => sum + (d.total_sleep_mins || 0), 0) / validData.length;
        const { p10, p25, p50, p75, p90 } = JSON.parse(durationStats.stat_data_json).percentiles;

        if (avgDuration >= p90) percentile_sleep_duration = 90;
        else if (avgDuration >= p75) percentile_sleep_duration = 75;
        else if (avgDuration >= p50) percentile_sleep_duration = 50;
        else if (avgDuration >= p25) percentile_sleep_duration = 25;
        else if (avgDuration >= p10) percentile_sleep_duration = 10;
        else percentile_sleep_duration = 5;
      }
    }

    // Update membership with percentiles
    await ctx.db.patch(membership._id, {
      percentile_isi,
      percentile_sleep_efficiency,
      percentile_sleep_duration,
      updated_at: Date.now(),
    });

    return {
      isi: percentile_isi,
      sleep_efficiency: percentile_sleep_efficiency,
      sleep_duration: percentile_sleep_duration,
    };
  },
});

/**
 * Compute intervention effectiveness for a cohort
 */
export const computeInterventionEffectiveness = internalMutation({
  args: {
    cohort_hash: v.string(),
    intervention_id: v.string(),
  },
  handler: async (ctx, args) => {
    // Get all users in this cohort
    const cohortMembers = await ctx.db
      .query("user_cohort_memberships")
      .withIndex("by_cohort_hash", (q) => q.eq("cohort_hash", args.cohort_hash))
      .collect();

    const userIds = cohortMembers.map((m) => m.user_id);

    // Get all user_interventions for this intervention in this cohort
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_intervention", (q) => q.eq("intervention_string_id", args.intervention_id))
      .collect();

    // Filter to only cohort members who completed the intervention
    const completedInterventions = userInterventions.filter(
      (ui) =>
        userIds.includes(ui.user_id) &&
        (ui.status === "completed" || ui.status === "active")
    );

    if (completedInterventions.length < 5) {
      return null; // Not enough data
    }

    // Calculate success metrics
    let successCount = 0;
    let totalDaysToImprovement = 0;
    let improvementCount = 0;

    for (const intervention of completedInterventions) {
      // Check if user showed improvement after intervention
      // Compare ISI scores before and after
      const startDate = new Date(intervention.start_date);
      const startTs = startDate.getTime();

      const scoresBefore = await ctx.db
        .query("questionnaire_scores")
        .withIndex("by_user_questionnaire", (q) =>
          q.eq("user_id", intervention.user_id).eq("questionnaire_name", "ISI")
        )
        .filter((q) => q.lt(q.field("calculated_at"), startTs))
        .order("desc")
        .first();

      const scoresAfter = await ctx.db
        .query("questionnaire_scores")
        .withIndex("by_user_questionnaire", (q) =>
          q.eq("user_id", intervention.user_id).eq("questionnaire_name", "ISI")
        )
        .filter((q) => q.gt(q.field("calculated_at"), startTs))
        .order("desc")
        .first();

      if (scoresBefore && scoresAfter) {
        const improvement = scoresBefore.score - scoresAfter.score;
        if (improvement >= 3) {
          // Clinically meaningful improvement
          successCount++;

          const daysToImprove = Math.floor(
            (scoresAfter.calculated_at - startTs) / (1000 * 60 * 60 * 24)
          );
          totalDaysToImprovement += daysToImprove;
          improvementCount++;
        }
      }
    }

    const successRate = Math.round((successCount / completedInterventions.length) * 100);
    const avgDaysToImprovement =
      improvementCount > 0 ? Math.round(totalDaysToImprovement / improvementCount) : undefined;

    // Get first member for cohort context
    const firstMember = cohortMembers[0];

    // Check if effectiveness record exists
    const existing = await ctx.db
      .query("cohort_intervention_effectiveness")
      .withIndex("by_cohort_intervention", (q) =>
        q.eq("cohort_hash", args.cohort_hash).eq("intervention_id", args.intervention_id)
      )
      .first();

    const now = Date.now();

    if (existing) {
      await ctx.db.patch(existing._id, {
        success_rate: successRate,
        sample_size: completedInterventions.length,
        avg_days_to_improvement: avgDaysToImprovement,
        computed_at: now,
      });
    } else {
      await ctx.db.insert("cohort_intervention_effectiveness", {
        cohort_hash: args.cohort_hash,
        intervention_id: args.intervention_id,
        success_rate: successRate,
        sample_size: completedInterventions.length,
        avg_days_to_improvement: avgDaysToImprovement,
        cohort_age_bracket: firstMember.age_bracket,
        cohort_gender: firstMember.gender,
        cohort_gateway: firstMember.primary_gateway,
        computed_at: now,
      });
    }

    return { cohort_hash: args.cohort_hash, intervention_id: args.intervention_id, success_rate: successRate };
  },
});

/**
 * Update solidarity moments
 */
export const updateSolidarityMoments = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const fiveMinutes = 5 * 60 * 1000;
    const oneHour = 60 * 60 * 1000;

    // Count users who were active in the last hour (proxy for "awake now")
    const recentActivity = await ctx.db
      .query("user_streaks")
      .filter((q) => q.gt(q.field("updated_at"), now - oneHour))
      .collect();

    // Scale up for display (we want to show community feeling)
    const awakeCount = Math.max(recentActivity.length * 10, 100); // Minimum 100 for solidarity

    // Update or insert awake_now moment
    const existingAwake = await ctx.db
      .query("solidarity_moments")
      .withIndex("by_moment_type", (q) => q.eq("moment_type", "awake_now"))
      .first();

    if (existingAwake) {
      await ctx.db.patch(existingAwake._id, {
        awake_count: awakeCount,
        awake_count_updated_at: now,
        expires_at: now + fiveMinutes,
      });
    } else {
      await ctx.db.insert("solidarity_moments", {
        moment_type: "awake_now",
        awake_count: awakeCount,
        awake_count_updated_at: now,
        valid_for_minutes: 5,
        computed_at: now,
        expires_at: now + fiveMinutes,
      });
    }

    // Get journey completion stats for the month
    const monthStart = new Date();
    monthStart.setDate(1);
    monthStart.setHours(0, 0, 0, 0);
    const monthStartMs = monthStart.getTime();

    const allStreaks = await ctx.db.query("user_streaks").collect();
    const journeysCompleted = allStreaks.filter((s) => s.total_days_completed >= 14).length;

    // Estimate improving count (those with 5+ day streaks)
    const improvingCount = allStreaks.filter((s) => s.current_streak >= 5).length;

    const existingJourney = await ctx.db
      .query("solidarity_moments")
      .withIndex("by_moment_type", (q) => q.eq("moment_type", "journey_complete"))
      .first();

    if (existingJourney) {
      await ctx.db.patch(existingJourney._id, {
        journeys_completed_this_month: journeysCompleted,
        improving_count: improvingCount,
        expires_at: now + oneHour,
        computed_at: now,
      });
    } else {
      await ctx.db.insert("solidarity_moments", {
        moment_type: "journey_complete",
        journeys_completed_this_month: journeysCompleted,
        improving_count: improvingCount,
        valid_for_minutes: 60,
        computed_at: now,
        expires_at: now + oneHour,
      });
    }

    return { awakeCount, journeysCompleted, improvingCount };
  },
});

// ============================================
// Batch Processing for Nightly Job
// ============================================

/**
 * Get all unique cohort hashes for batch processing
 */
export const getAllCohortHashes = internalQuery({
  args: {},
  handler: async (ctx) => {
    const memberships = await ctx.db.query("user_cohort_memberships").collect();

    // Get unique cohort hashes
    const uniqueHashes = [...new Set(memberships.map((m) => m.cohort_hash))];

    return uniqueHashes;
  },
});

/**
 * Get all active interventions for effectiveness computation
 */
export const getAllActiveInterventions = internalQuery({
  args: {},
  handler: async (ctx) => {
    const interventions = await ctx.db
      .query("interventions")
      .filter((q) => q.eq(q.field("status"), "active"))
      .collect();

    return interventions.map((i) => i.intervention_id);
  },
});
