import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { Id } from "./_generated/dataModel";

/**
 * HealthKit Data Storage and Retrieval Functions
 * Used by iOS app to sync Apple Health data and by Physician Dashboard to display it
 */

// ============================================
// Sleep Data Functions
// ============================================

/**
 * Store or update sleep data from HealthKit
 */
export const syncSleepData = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(), // YYYY-MM-DD
    inBedTime: v.optional(v.number()),
    asleepTime: v.optional(v.number()),
    wakeTime: v.optional(v.number()),
    totalSleepMins: v.optional(v.number()),
    sleepEfficiency: v.optional(v.number()),
    deepSleepMins: v.optional(v.number()),
    lightSleepMins: v.optional(v.number()),
    remSleepMins: v.optional(v.number()),
    awakeMins: v.optional(v.number()),
    interruptionsCount: v.optional(v.number()),
    sleepLatencyMins: v.optional(v.number()),
    primarySource: v.optional(v.string()),
    sourceBundleId: v.optional(v.string()),
    allSourcesJson: v.optional(v.string()),
    isMultiSource: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const { userId, date, ...sleepData } = args;

    // Check for existing entry
    const existing = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    const now = Date.now();

    if (existing) {
      // Update existing entry
      await ctx.db.patch(existing._id, {
        in_bed_time: sleepData.inBedTime ?? existing.in_bed_time,
        asleep_time: sleepData.asleepTime ?? existing.asleep_time,
        wake_time: sleepData.wakeTime ?? existing.wake_time,
        total_sleep_mins: sleepData.totalSleepMins ?? existing.total_sleep_mins,
        sleep_efficiency: sleepData.sleepEfficiency ?? existing.sleep_efficiency,
        deep_sleep_mins: sleepData.deepSleepMins ?? existing.deep_sleep_mins,
        light_sleep_mins: sleepData.lightSleepMins ?? existing.light_sleep_mins,
        rem_sleep_mins: sleepData.remSleepMins ?? existing.rem_sleep_mins,
        awake_mins: sleepData.awakeMins ?? existing.awake_mins,
        interruptions_count: sleepData.interruptionsCount ?? existing.interruptions_count,
        sleep_latency_mins: sleepData.sleepLatencyMins ?? existing.sleep_latency_mins,
        primary_source: sleepData.primarySource ?? existing.primary_source,
        source_bundle_id: sleepData.sourceBundleId ?? existing.source_bundle_id,
        all_sources_json: sleepData.allSourcesJson ?? existing.all_sources_json,
        is_multi_source: sleepData.isMultiSource ?? existing.is_multi_source,
        synced_at: now,
      });
      return existing._id;
    } else {
      // Create new entry
      return await ctx.db.insert("user_sleep_data", {
        user_id: userId,
        date,
        in_bed_time: sleepData.inBedTime,
        asleep_time: sleepData.asleepTime,
        wake_time: sleepData.wakeTime,
        total_sleep_mins: sleepData.totalSleepMins,
        sleep_efficiency: sleepData.sleepEfficiency,
        deep_sleep_mins: sleepData.deepSleepMins,
        light_sleep_mins: sleepData.lightSleepMins,
        rem_sleep_mins: sleepData.remSleepMins,
        awake_mins: sleepData.awakeMins,
        interruptions_count: sleepData.interruptionsCount,
        sleep_latency_mins: sleepData.sleepLatencyMins,
        primary_source: sleepData.primarySource,
        source_bundle_id: sleepData.sourceBundleId,
        all_sources_json: sleepData.allSourcesJson,
        is_multi_source: sleepData.isMultiSource,
        synced_at: now,
      });
    }
  },
});

/**
 * Store sleep stage data
 */
export const syncSleepStages = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),
    stages: v.array(
      v.object({
        startTime: v.number(),
        endTime: v.number(),
        stage: v.string(), // 'deep', 'light', 'rem', 'awake'
        durationMins: v.optional(v.number()),
      })
    ),
  },
  handler: async (ctx, args) => {
    const { userId, date, stages } = args;

    // Delete existing stages for this date
    const existing = await ctx.db
      .query("user_sleep_stages")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .collect();

    for (const stage of existing) {
      await ctx.db.delete(stage._id);
    }

    // Insert new stages
    for (const stage of stages) {
      await ctx.db.insert("user_sleep_stages", {
        user_id: userId,
        date,
        start_time: stage.startTime,
        end_time: stage.endTime,
        stage: stage.stage,
        duration_mins: stage.durationMins,
      });
    }

    return { inserted: stages.length };
  },
});

/**
 * Get sleep data for a user over a date range
 */
export const getSleepDataRange = query({
  args: {
    userId: v.id("users"),
    startDate: v.string(),
    endDate: v.string(),
  },
  handler: async (ctx, args) => {
    const { userId, startDate, endDate } = args;

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Filter by date range
    return sleepData
      .filter((d) => d.date >= startDate && d.date <= endDate)
      .sort((a, b) => a.date.localeCompare(b.date));
  },
});

/**
 * Get sleep data for a specific date
 */
export const getSleepDataForDate = query({
  args: {
    userId: v.id("users"),
    date: v.string(),
  },
  handler: async (ctx, args) => {
    const { userId, date } = args;

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    if (!sleepData) return null;

    // Get sleep stages for this date
    const stages = await ctx.db
      .query("user_sleep_stages")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .collect();

    return {
      ...sleepData,
      stages: stages.sort((a, b) => a.start_time - b.start_time),
    };
  },
});

/**
 * Get the most recent sleep data
 */
export const getLatestSleepData = query({
  args: {
    userId: v.id("users"),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, limit = 15 } = args;

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    return sleepData
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, limit);
  },
});

// ============================================
// Heart Rate Functions
// ============================================

/**
 * Store heart rate data
 */
export const syncHeartRateData = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),
    restingHr: v.optional(v.number()),
    avgHr: v.optional(v.number()),
    hrvMorning: v.optional(v.number()),
    hrvAvg: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, date, ...hrData } = args;

    const existing = await ctx.db
      .query("user_heart_rate")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    const now = Date.now();

    if (existing) {
      await ctx.db.patch(existing._id, {
        resting_hr: hrData.restingHr ?? existing.resting_hr,
        avg_hr: hrData.avgHr ?? existing.avg_hr,
        hrv_morning: hrData.hrvMorning ?? existing.hrv_morning,
        hrv_avg: hrData.hrvAvg ?? existing.hrv_avg,
        synced_at: now,
      });
      return existing._id;
    } else {
      return await ctx.db.insert("user_heart_rate", {
        user_id: userId,
        date,
        resting_hr: hrData.restingHr,
        avg_hr: hrData.avgHr,
        hrv_morning: hrData.hrvMorning,
        hrv_avg: hrData.hrvAvg,
        synced_at: now,
      });
    }
  },
});

/**
 * Get heart rate data range
 */
export const getHeartRateRange = query({
  args: {
    userId: v.id("users"),
    startDate: v.string(),
    endDate: v.string(),
  },
  handler: async (ctx, args) => {
    const { userId, startDate, endDate } = args;

    const hrData = await ctx.db
      .query("user_heart_rate")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    return hrData
      .filter((d) => d.date >= startDate && d.date <= endDate)
      .sort((a, b) => a.date.localeCompare(b.date));
  },
});

// ============================================
// Activity Functions
// ============================================

/**
 * Store activity data
 */
export const syncActivityData = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),
    steps: v.optional(v.number()),
    activeMins: v.optional(v.number()),
    exerciseMins: v.optional(v.number()),
    caloriesBurned: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, date, ...activityData } = args;

    const existing = await ctx.db
      .query("user_activity")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    const now = Date.now();

    if (existing) {
      await ctx.db.patch(existing._id, {
        steps: activityData.steps ?? existing.steps,
        active_mins: activityData.activeMins ?? existing.active_mins,
        exercise_mins: activityData.exerciseMins ?? existing.exercise_mins,
        calories_burned: activityData.caloriesBurned ?? existing.calories_burned,
        synced_at: now,
      });
      return existing._id;
    } else {
      return await ctx.db.insert("user_activity", {
        user_id: userId,
        date,
        steps: activityData.steps,
        active_mins: activityData.activeMins,
        exercise_mins: activityData.exerciseMins,
        calories_burned: activityData.caloriesBurned,
        synced_at: now,
      });
    }
  },
});

// ============================================
// Perception Gap Functions
// ============================================

/**
 * Store perception gap data (subjective vs objective comparison)
 */
export const updatePerceptionGap = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),
    subjectiveQuality: v.optional(v.number()),
    subjectiveLatencyMins: v.optional(v.number()),
    subjectiveAwakenings: v.optional(v.number()),
    objectiveTotalSleepMins: v.optional(v.number()),
    objectiveEfficiency: v.optional(v.number()),
    objectiveDeepMins: v.optional(v.number()),
    objectiveRemMins: v.optional(v.number()),
    objectiveLatencyMins: v.optional(v.number()),
    objectiveAwakenings: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, date, ...gapData } = args;

    const existing = await ctx.db
      .query("perception_gaps")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    const now = Date.now();

    // Calculate gap score and direction
    let gapScore: number | undefined;
    let gapDirection: string | undefined;

    if (gapData.subjectiveQuality && gapData.objectiveEfficiency) {
      // Normalize subjective to 0-100 (from 1-10 scale)
      const subjectiveNormalized = gapData.subjectiveQuality * 10;
      gapScore = subjectiveNormalized - gapData.objectiveEfficiency;

      if (Math.abs(gapScore) <= 10) {
        gapDirection = "accurate";
      } else if (gapScore > 0) {
        gapDirection = "overestimate";
      } else {
        gapDirection = "underestimate";
      }
    }

    if (existing) {
      await ctx.db.patch(existing._id, {
        subjective_quality: gapData.subjectiveQuality ?? existing.subjective_quality,
        subjective_latency_mins: gapData.subjectiveLatencyMins ?? existing.subjective_latency_mins,
        subjective_awakenings: gapData.subjectiveAwakenings ?? existing.subjective_awakenings,
        objective_total_sleep_mins: gapData.objectiveTotalSleepMins ?? existing.objective_total_sleep_mins,
        objective_efficiency: gapData.objectiveEfficiency ?? existing.objective_efficiency,
        objective_deep_mins: gapData.objectiveDeepMins ?? existing.objective_deep_mins,
        objective_rem_mins: gapData.objectiveRemMins ?? existing.objective_rem_mins,
        objective_latency_mins: gapData.objectiveLatencyMins ?? existing.objective_latency_mins,
        objective_awakenings: gapData.objectiveAwakenings ?? existing.objective_awakenings,
        gap_score: gapScore,
        gap_direction: gapDirection,
        computed_at: now,
      });
      return existing._id;
    } else {
      return await ctx.db.insert("perception_gaps", {
        user_id: userId,
        date,
        subjective_quality: gapData.subjectiveQuality,
        subjective_latency_mins: gapData.subjectiveLatencyMins,
        subjective_awakenings: gapData.subjectiveAwakenings,
        objective_total_sleep_mins: gapData.objectiveTotalSleepMins,
        objective_efficiency: gapData.objectiveEfficiency,
        objective_deep_mins: gapData.objectiveDeepMins,
        objective_rem_mins: gapData.objectiveRemMins,
        objective_latency_mins: gapData.objectiveLatencyMins,
        objective_awakenings: gapData.objectiveAwakenings,
        gap_score: gapScore,
        gap_direction: gapDirection,
        computed_at: now,
      });
    }
  },
});

/**
 * Get perception gaps for a user
 */
export const getPerceptionGaps = query({
  args: {
    userId: v.id("users"),
    startDate: v.optional(v.string()),
    endDate: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, startDate, endDate, limit = 15 } = args;

    const gaps = await ctx.db
      .query("perception_gaps")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    let filtered = gaps;

    if (startDate && endDate) {
      filtered = gaps.filter((g) => g.date >= startDate && g.date <= endDate);
    }

    return filtered
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, limit);
  },
});

// ============================================
// Physician Dashboard Functions
// ============================================

/**
 * Get comprehensive patient HealthKit summary for physician dashboard
 */
export const getPatientHealthSummary = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;

    // Get user info
    const user = await ctx.db.get(userId);
    if (!user) return null;

    // Get last 15 days of sleep data
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const recentSleep = sleepData
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, 15);

    // Get perception gaps
    const gaps = await ctx.db
      .query("perception_gaps")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const recentGaps = gaps
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, 15);

    // Get heart rate data
    const hrData = await ctx.db
      .query("user_heart_rate")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const recentHr = hrData
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, 15);

    // Calculate averages
    const avgSleepMins =
      recentSleep.filter((s) => s.total_sleep_mins).length > 0
        ? Math.round(
            recentSleep.reduce((acc, s) => acc + (s.total_sleep_mins || 0), 0) /
              recentSleep.filter((s) => s.total_sleep_mins).length
          )
        : null;

    const avgEfficiency =
      recentSleep.filter((s) => s.sleep_efficiency).length > 0
        ? Math.round(
            recentSleep.reduce((acc, s) => acc + (s.sleep_efficiency || 0), 0) /
              recentSleep.filter((s) => s.sleep_efficiency).length
          )
        : null;

    const avgDeepSleep =
      recentSleep.filter((s) => s.deep_sleep_mins).length > 0
        ? Math.round(
            recentSleep.reduce((acc, s) => acc + (s.deep_sleep_mins || 0), 0) /
              recentSleep.filter((s) => s.deep_sleep_mins).length
          )
        : null;

    const avgRemSleep =
      recentSleep.filter((s) => s.rem_sleep_mins).length > 0
        ? Math.round(
            recentSleep.reduce((acc, s) => acc + (s.rem_sleep_mins || 0), 0) /
              recentSleep.filter((s) => s.rem_sleep_mins).length
          )
        : null;

    // Perception gap analysis
    const overestimateCount = recentGaps.filter(
      (g) => g.gap_direction === "overestimate"
    ).length;
    const underestimateCount = recentGaps.filter(
      (g) => g.gap_direction === "underestimate"
    ).length;
    const accurateCount = recentGaps.filter(
      (g) => g.gap_direction === "accurate"
    ).length;

    return {
      hasHealthKitData: recentSleep.length > 0,
      dataPoints: recentSleep.length,
      lastSyncDate: recentSleep[0]?.date || null,
      summary: {
        avgSleepHours: avgSleepMins ? avgSleepMins / 60 : null,
        avgEfficiency,
        avgDeepSleepMins: avgDeepSleep,
        avgRemSleepMins: avgRemSleep,
        avgRestingHr:
          recentHr.filter((h) => h.resting_hr).length > 0
            ? Math.round(
                recentHr.reduce((acc, h) => acc + (h.resting_hr || 0), 0) /
                  recentHr.filter((h) => h.resting_hr).length
              )
            : null,
        avgHrv:
          recentHr.filter((h) => h.hrv_avg).length > 0
            ? Math.round(
                recentHr.reduce((acc, h) => acc + (h.hrv_avg || 0), 0) /
                  recentHr.filter((h) => h.hrv_avg).length
              )
            : null,
      },
      perceptionAnalysis: {
        overestimateCount,
        underestimateCount,
        accurateCount,
        dominantPattern:
          overestimateCount > underestimateCount && overestimateCount > accurateCount
            ? "overestimate"
            : underestimateCount > overestimateCount &&
              underestimateCount > accurateCount
            ? "underestimate"
            : "accurate",
      },
      recentSleep: recentSleep.map((s) => ({
        date: s.date,
        totalSleepMins: s.total_sleep_mins,
        efficiency: s.sleep_efficiency,
        deepMins: s.deep_sleep_mins,
        remMins: s.rem_sleep_mins,
        lightMins: s.light_sleep_mins,
        awakeMins: s.awake_mins,
        awakenings: s.interruptions_count,
      })),
      recentGaps: recentGaps.map((g) => ({
        date: g.date,
        subjectiveQuality: g.subjective_quality,
        objectiveEfficiency: g.objective_efficiency,
        gapScore: g.gap_score,
        gapDirection: g.gap_direction,
      })),
    };
  },
});

/**
 * Get sleep architecture data for visualization
 */
export const getSleepArchitecture = query({
  args: {
    userId: v.id("users"),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, limit = 15 } = args;

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    return sleepData
      .filter(
        (s) =>
          s.deep_sleep_mins !== undefined ||
          s.light_sleep_mins !== undefined ||
          s.rem_sleep_mins !== undefined
      )
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, limit)
      .map((s, index) => ({
        date: s.date,
        day: limit - index,
        deep: s.deep_sleep_mins || 0,
        light: s.light_sleep_mins || 0,
        rem: s.rem_sleep_mins || 0,
        awake: s.awake_mins || 0,
        totalSleep: s.total_sleep_mins || 0,
      }))
      .reverse();
  },
});
