import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { Id } from "./_generated/dataModel";

/**
 * HealthKit Data Storage and Retrieval Functions
 * Used by iOS app to sync Apple Health data and by Physician Dashboard to display it
 */

// ============================================
// Wearable Type Detection Helpers
// ============================================

/**
 * Detects the consolidated wearable type from bundle ID and source name
 * Maps device-specific sources to unified wearable categories
 */
function detectWearableType(bundleId: string, sourceName: string): string {
  const combined = (bundleId + " " + sourceName).toLowerCase();

  if (combined.includes("watch") || combined.includes("com.apple.health.")) {
    return "Apple Watch";
  } else if (combined.includes("oura") || combined.includes("ouraring")) {
    return "Oura Ring";
  } else if (combined.includes("garmin")) {
    return "Garmin";
  } else if (combined.includes("fitbit")) {
    return "Fitbit";
  } else if (combined.includes("whoop")) {
    return "WHOOP";
  }
  return "Other Device";
}

/**
 * Extracts device model from source name
 * Examples:
 *   "Apple Watch Series 8" → "Series 8"
 *   "Garmin Fenix 7" → "Fenix 7"
 *   "Fitbit Charge 5" → "Charge 5"
 */
function extractDeviceModel(sourceName: string): string | undefined {
  const patterns = [
    /Apple Watch (.+)/i,
    /Garmin (.+)/i,
    /Fitbit (.+)/i,
    /WHOOP (.+)/i,
    /Oura Ring (.+)/i,
  ];

  for (const pattern of patterns) {
    const match = sourceName.match(pattern);
    if (match) return match[1].trim();
  }
  return undefined;
}

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
    // Wearable consolidation fields
    wearableType: v.optional(v.string()),
    deviceModel: v.optional(v.string()),
    allBundleIdsJson: v.optional(v.string()),
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
        wearable_type: sleepData.wearableType ?? existing.wearable_type,
        device_model: sleepData.deviceModel ?? existing.device_model,
        all_bundle_ids_json: sleepData.allBundleIdsJson ?? existing.all_bundle_ids_json,
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
        wearable_type: sleepData.wearableType,
        device_model: sleepData.deviceModel,
        all_bundle_ids_json: sleepData.allBundleIdsJson,
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

    // CRITICAL: Filter to REAL wearable data BEFORE calculating averages
    // Questionnaire-derived data (primary_source: "Questionnaire") should not be included
    const wearableOnlySleep = recentSleep.filter(
      (s) => s.primary_source && s.primary_source !== "Questionnaire"
    );

    // Calculate averages from WEARABLE data only
    const avgSleepMins =
      wearableOnlySleep.filter((s) => s.total_sleep_mins).length > 0
        ? Math.round(
            wearableOnlySleep.reduce((acc, s) => acc + (s.total_sleep_mins || 0), 0) /
              wearableOnlySleep.filter((s) => s.total_sleep_mins).length
          )
        : null;

    const avgEfficiency =
      wearableOnlySleep.filter((s) => s.sleep_efficiency).length > 0
        ? Math.round(
            wearableOnlySleep.reduce((acc, s) => acc + (s.sleep_efficiency || 0), 0) /
              wearableOnlySleep.filter((s) => s.sleep_efficiency).length
          )
        : null;

    const avgDeepSleep =
      wearableOnlySleep.filter((s) => s.deep_sleep_mins).length > 0
        ? Math.round(
            wearableOnlySleep.reduce((acc, s) => acc + (s.deep_sleep_mins || 0), 0) /
              wearableOnlySleep.filter((s) => s.deep_sleep_mins).length
          )
        : null;

    const avgRemSleep =
      wearableOnlySleep.filter((s) => s.rem_sleep_mins).length > 0
        ? Math.round(
            wearableOnlySleep.reduce((acc, s) => acc + (s.rem_sleep_mins || 0), 0) /
              wearableOnlySleep.filter((s) => s.rem_sleep_mins).length
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

    // CRITICAL: Only report wearable data as available if:
    // 1. User has actually connected Apple Health AND
    // 2. The data is from a real wearable (not questionnaire-derived)
    const hasRealWearableConnection = user.apple_health_connected === true;
    const hasRealWearableData = hasRealWearableConnection && wearableOnlySleep.length > 0;

    return {
      hasHealthKitData: hasRealWearableData,
      hasWearableConnected: hasRealWearableConnection,
      dataPoints: hasRealWearableData ? wearableOnlySleep.length : 0,
      lastSyncDate: hasRealWearableData ? (wearableOnlySleep[0]?.date || null) : null,
      // Only return wearable-derived metrics if user has REAL wearable data
      // Sleep stages, HR, HRV CANNOT be derived from questionnaires
      summary: hasRealWearableData ? {
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
      } : {
        // No wearable connected - return nulls for all wearable-derived metrics
        avgSleepHours: null,
        avgEfficiency: null,
        avgDeepSleepMins: null,
        avgRemSleepMins: null,
        avgRestingHr: null,
        avgHrv: null,
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
      // Only return REAL wearable sleep data (exclude questionnaire-derived)
      recentSleep: hasRealWearableData ? wearableOnlySleep.map((s) => ({
        date: s.date,
        totalSleepMins: s.total_sleep_mins,
        efficiency: s.sleep_efficiency,
        deepMins: s.deep_sleep_mins,
        remMins: s.rem_sleep_mins,
        lightMins: s.light_sleep_mins,
        awakeMins: s.awake_mins,
        awakenings: s.interruptions_count,
        primarySource: s.primary_source,
      })) : [],
      // Perception gaps only make sense with wearable data
      recentGaps: hasRealWearableConnection ? recentGaps.map((g) => ({
        date: g.date,
        subjectiveQuality: g.subjective_quality,
        objectiveEfficiency: g.objective_efficiency,
        gapScore: g.gap_score,
        gapDirection: g.gap_direction,
      })) : [],
    };
  },
});

/**
 * Get sleep architecture data for visualization.
 * CRITICAL: Sleep stages (deep, light, REM, awake) can ONLY be measured by wearable devices.
 * They CANNOT be derived from questionnaires. This query returns null if no real wearable data exists.
 */
export const getSleepArchitecture = query({
  args: {
    userId: v.id("users"),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, limit = 15 } = args;

    // Check if user has a real wearable connected
    const user = await ctx.db.get(userId);
    if (!user) return null;

    const hasRealWearable = user.apple_health_connected === true;

    // Get sleep data
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // CRITICAL: Filter to ONLY wearable-sourced data
    // Questionnaire data does NOT have real sleep stages - any values there were fabricated
    const wearableData = sleepData.filter(
      (s) => s.primary_source && s.primary_source !== "Questionnaire"
    );

    // If no real wearable connection or no wearable data, return null
    if (!hasRealWearable || wearableData.length === 0) {
      return null;
    }

    // Only return data that actually has sleep stage measurements from wearables
    const dataWithStages = wearableData.filter(
      (s) =>
        s.deep_sleep_mins !== undefined ||
        s.light_sleep_mins !== undefined ||
        s.rem_sleep_mins !== undefined
    );

    if (dataWithStages.length === 0) {
      return null;
    }

    return dataWithStages
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

// ============================================
// Multi-Source Sleep Data Query
// ============================================

/**
 * Sanitize source names to be valid Convex field names.
 * Convex requires field names to contain only non-control ASCII characters,
 * so we replace apostrophes and other problematic characters.
 */
function sanitizeSourceName(source: string): string {
  return source
    .replace(/'/g, "") // Remove apostrophes (e.g., "Martin's" -> "Martins")
    .replace(/[^\x20-\x7E]/g, "") // Remove non-printable ASCII
    .trim();
}

/**
 * Get sleep data organized by source device for multi-wearable comparison.
 * Returns data grouped by source (Apple Watch, Oura, Fitbit, etc.) with
 * overlapping dates aligned for easy comparison charting.
 *
 * @param consolidateByWearable - If true, groups all Apple Watch models as "Apple Watch" (default: true)
 */
export const getMultiSourceSleepData = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()),
    consolidateByWearable: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const { userId, days = 15, consolidateByWearable = true } = args;

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Get unique dates and sources
    const allDates = new Set<string>();
    const sourceData: Record<string, Array<{
      date: string;
      totalSleepMins: number | null;
      efficiency: number | null;
      deepMins: number | null;
      remMins: number | null;
      lightMins: number | null;
    }>> = {};

    // Track device models per wearable type
    const deviceModelsBySource: Record<string, Set<string>> = {};

    // Collect all sources mentioned in all_sources_json
    const allSourcesSet = new Set<string>();

    for (const record of sleepData) {
      allDates.add(record.date);

      // Determine source key: use wearable_type if consolidating, otherwise primary_source
      let sourceKey: string;
      if (consolidateByWearable && record.wearable_type) {
        sourceKey = sanitizeSourceName(record.wearable_type);
      } else {
        sourceKey = sanitizeSourceName(record.primary_source || "Unknown");
      }

      // Initialize source data array if needed
      if (!sourceData[sourceKey]) {
        sourceData[sourceKey] = [];
        deviceModelsBySource[sourceKey] = new Set();
      }

      // Track device model
      if (record.device_model) {
        deviceModelsBySource[sourceKey].add(record.device_model);
      }

      sourceData[sourceKey].push({
        date: record.date,
        totalSleepMins: record.total_sleep_mins ?? null,
        efficiency: record.sleep_efficiency ?? null,
        deepMins: record.deep_sleep_mins ?? null,
        remMins: record.rem_sleep_mins ?? null,
        lightMins: record.light_sleep_mins ?? null,
      });
      allSourcesSet.add(sourceKey);

      // Parse all_sources_json to find all contributing sources
      if (record.all_sources_json) {
        try {
          const allSources = JSON.parse(record.all_sources_json) as string[];
          allSources.forEach(s => {
            const sanitized = sanitizeSourceName(s);
            // If consolidating, map to wearable type
            if (consolidateByWearable) {
              const wearableType = detectWearableType("", s);
              allSourcesSet.add(sanitizeSourceName(wearableType));
            } else {
              allSourcesSet.add(sanitized);
            }
          });
        } catch {
          // Ignore parse errors
        }
      }
    }

    // Sort dates and limit
    const sortedDates = Array.from(allDates)
      .sort((a, b) => b.localeCompare(a))
      .slice(0, days);

    // Build comparison data structure
    const comparisonData = sortedDates.map(date => {
      const dataForDate: Record<string, {
        totalSleepMins: number | null;
        efficiency: number | null;
        deepMins: number | null;
        remMins: number | null;
        lightMins: number | null;
      } | null> = {};

      for (const source of Object.keys(sourceData)) {
        const sourceRecord = sourceData[source].find(d => d.date === date);
        dataForDate[source] = sourceRecord || null;
      }

      return {
        date,
        sources: dataForDate,
      };
    }).reverse();

    // Calculate source statistics
    const sourceStats = Object.keys(sourceData).map(source => {
      const records = sourceData[source].filter(r => r.efficiency !== null);
      const avgEfficiency = records.length > 0
        ? Math.round(records.reduce((sum, r) => sum + (r.efficiency || 0), 0) / records.length)
        : null;
      const avgSleepMins = records.length > 0
        ? Math.round(records.reduce((sum, r) => sum + (r.totalSleepMins || 0), 0) / records.length)
        : null;

      // Get device models for this source (if consolidating)
      const deviceModels = Array.from(deviceModelsBySource[source] || []);

      // Find date range
      const dates = sourceData[source].map(r => r.date).sort();
      const dateRange = dates.length > 0 ? {
        first: dates[0],
        last: dates[dates.length - 1]
      } : null;

      return {
        source,
        deviceModels,  // e.g., ["Series 7", "Ultra"] for Apple Watch
        dataPoints: sourceData[source].length,
        avgEfficiency,
        avgSleepHours: avgSleepMins ? avgSleepMins / 60 : null,
        hasDeepSleep: sourceData[source].some(r => r.deepMins !== null && r.deepMins > 0),
        hasHeartRate: false, // Would need to check heart rate table
        dateRange,
      };
    });

    return {
      hasMultipleSources: Object.keys(sourceData).length > 1,
      sources: Object.keys(sourceData),
      sourceStats,
      comparisonData,
      totalDays: sortedDates.length,
    };
  },
});

/**
 * Get detailed source information including device quality assessment
 */
export const getSourceDetails = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;

    // Get recent sleep data
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .order("desc")
      .take(30);

    // Get heart rate data to assess source capabilities
    const hrData = await ctx.db
      .query("user_heart_rate")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .take(30);

    // Collect sources and their capabilities
    const sourceCapabilities: Record<string, {
      hasSleepStages: boolean;
      hasHeartRate: boolean;
      hasHrv: boolean;
      daysOfData: number;
      firstSeen: string;
      lastSeen: string;
      qualityScore: number; // 0-5
    }> = {};

    for (const record of sleepData) {
      const source = sanitizeSourceName(record.primary_source || "Unknown");

      if (!sourceCapabilities[source]) {
        sourceCapabilities[source] = {
          hasSleepStages: false,
          hasHeartRate: false,
          hasHrv: false,
          daysOfData: 0,
          firstSeen: record.date,
          lastSeen: record.date,
          qualityScore: 0,
        };
      }

      const cap = sourceCapabilities[source];
      cap.daysOfData++;
      if (record.date < cap.firstSeen) cap.firstSeen = record.date;
      if (record.date > cap.lastSeen) cap.lastSeen = record.date;

      if (record.deep_sleep_mins !== undefined && record.deep_sleep_mins > 0) {
        cap.hasSleepStages = true;
      }
    }

    // Check heart rate data
    if (hrData.length > 0) {
      // Assume heart rate comes from primary wearable
      const primarySource = sanitizeSourceName(sleepData[0]?.primary_source || "Unknown");
      if (sourceCapabilities[primarySource]) {
        sourceCapabilities[primarySource].hasHeartRate = hrData.some(h => h.resting_hr !== undefined);
        sourceCapabilities[primarySource].hasHrv = hrData.some(h => h.hrv_avg !== undefined);
      }
    }

    // Calculate quality scores
    for (const source of Object.keys(sourceCapabilities)) {
      const cap = sourceCapabilities[source];
      let score = 1; // Base score for having any data
      if (cap.hasSleepStages) score += 2;
      if (cap.hasHeartRate) score += 1;
      if (cap.hasHrv) score += 1;
      cap.qualityScore = score;
    }

    return {
      sources: Object.entries(sourceCapabilities).map(([name, cap]) => ({
        name,
        ...cap,
        qualityLabel: cap.qualityScore >= 4 ? "Excellent"
          : cap.qualityScore >= 3 ? "Good"
          : cap.qualityScore >= 2 ? "Fair"
          : "Limited",
      })),
      primarySource: sleepData[0]?.primary_source ? sanitizeSourceName(sleepData[0].primary_source) : null,
      totalSources: Object.keys(sourceCapabilities).length,
    };
  },
});

// ============================================
// Data Source Verification Tools
// ============================================

/**
 * Comprehensive data source verification for wearable data.
 * Returns detailed audit of all sleep data sources, authenticity checks,
 * and potential data quality issues.
 */
export const verifyDataSources = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;

    // Get user info
    const user = await ctx.db.get(userId);
    if (!user) return null;

    // Get all sleep data
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Get heart rate data
    const hrData = await ctx.db
      .query("user_heart_rate")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Get activity data
    const activityData = await ctx.db
      .query("user_activity")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Get circadian data
    const circadianData = await ctx.db
      .query("user_circadian_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Analyze sleep data sources
    const sourceBreakdown: Record<string, {
      count: number;
      dateRange: { first: string; last: string } | null;
      hasDeepSleep: boolean;
      hasRemSleep: boolean;
      hasLightSleep: boolean;
      avgEfficiency: number | null;
      avgTotalSleep: number | null;
      sampleDates: string[];
    }> = {};

    for (const record of sleepData) {
      const source = record.primary_source || "Unknown";

      if (!sourceBreakdown[source]) {
        sourceBreakdown[source] = {
          count: 0,
          dateRange: null,
          hasDeepSleep: false,
          hasRemSleep: false,
          hasLightSleep: false,
          avgEfficiency: null,
          avgTotalSleep: null,
          sampleDates: [],
        };
      }

      const breakdown = sourceBreakdown[source];
      breakdown.count++;

      // Track date range
      if (!breakdown.dateRange) {
        breakdown.dateRange = { first: record.date, last: record.date };
      } else {
        if (record.date < breakdown.dateRange.first) breakdown.dateRange.first = record.date;
        if (record.date > breakdown.dateRange.last) breakdown.dateRange.last = record.date;
      }

      // Track capabilities
      if (record.deep_sleep_mins !== undefined && record.deep_sleep_mins > 0) {
        breakdown.hasDeepSleep = true;
      }
      if (record.rem_sleep_mins !== undefined && record.rem_sleep_mins > 0) {
        breakdown.hasRemSleep = true;
      }
      if (record.light_sleep_mins !== undefined && record.light_sleep_mins > 0) {
        breakdown.hasLightSleep = true;
      }

      // Collect sample dates (most recent 5)
      if (breakdown.sampleDates.length < 5) {
        breakdown.sampleDates.push(record.date);
      }
    }

    // Calculate averages per source
    for (const source of Object.keys(sourceBreakdown)) {
      const sourceRecords = sleepData.filter(r => (r.primary_source || "Unknown") === source);
      const efficiencyRecords = sourceRecords.filter(r => r.sleep_efficiency !== undefined);
      const sleepRecords = sourceRecords.filter(r => r.total_sleep_mins !== undefined);

      if (efficiencyRecords.length > 0) {
        sourceBreakdown[source].avgEfficiency = Math.round(
          efficiencyRecords.reduce((sum, r) => sum + (r.sleep_efficiency || 0), 0) / efficiencyRecords.length
        );
      }
      if (sleepRecords.length > 0) {
        sourceBreakdown[source].avgTotalSleep = Math.round(
          sleepRecords.reduce((sum, r) => sum + (r.total_sleep_mins || 0), 0) / sleepRecords.length
        );
      }
    }

    // Identify potential data quality issues
    const issues: Array<{
      type: string;
      severity: "warning" | "error" | "info";
      message: string;
      dates?: string[];
    }> = [];

    // Check for questionnaire data masquerading as wearable
    const questionnaireData = sleepData.filter(r => r.primary_source === "Questionnaire");
    const wearableData = sleepData.filter(r => r.primary_source && r.primary_source !== "Questionnaire");

    if (questionnaireData.length > 0) {
      // Check if questionnaire data has sleep stages (which shouldn't be possible)
      const questionnaireWithStages = questionnaireData.filter(r =>
        (r.deep_sleep_mins !== undefined && r.deep_sleep_mins > 0) ||
        (r.rem_sleep_mins !== undefined && r.rem_sleep_mins > 0) ||
        (r.light_sleep_mins !== undefined && r.light_sleep_mins > 0)
      );

      if (questionnaireWithStages.length > 0) {
        issues.push({
          type: "fabricated_stages",
          severity: "error",
          message: `${questionnaireWithStages.length} questionnaire records have sleep stage data, which is impossible without a wearable device. These values are fabricated.`,
          dates: questionnaireWithStages.slice(0, 5).map(r => r.date),
        });
      }
    }

    // Check if user claims Apple Health connected but has no wearable data
    if (user.apple_health_connected && wearableData.length === 0) {
      issues.push({
        type: "missing_wearable_data",
        severity: "warning",
        message: "User has Apple Health marked as connected but no wearable-sourced sleep data exists.",
      });
    }

    // Check for data overlap between sources (potential conflicts)
    const dateSourceMap = new Map<string, string[]>();
    for (const record of sleepData) {
      const source = record.primary_source || "Unknown";
      if (!dateSourceMap.has(record.date)) {
        dateSourceMap.set(record.date, []);
      }
      dateSourceMap.get(record.date)!.push(source);
    }

    const overlappingDates = Array.from(dateSourceMap.entries())
      .filter(([_, sources]) => sources.length > 1)
      .map(([date, sources]) => ({ date, sources }));

    if (overlappingDates.length > 0) {
      issues.push({
        type: "source_overlap",
        severity: "warning",
        message: `${overlappingDates.length} dates have data from multiple sources. This may cause inconsistencies.`,
        dates: overlappingDates.slice(0, 5).map(d => `${d.date} (${d.sources.join(", ")})`),
      });
    }

    // Check for unrealistic values
    const unrealisticRecords = sleepData.filter(r =>
      (r.sleep_efficiency !== undefined && (r.sleep_efficiency < 0 || r.sleep_efficiency > 100)) ||
      (r.total_sleep_mins !== undefined && (r.total_sleep_mins < 0 || r.total_sleep_mins > 1440)) ||
      (r.deep_sleep_mins !== undefined && r.total_sleep_mins !== undefined &&
        r.deep_sleep_mins > r.total_sleep_mins)
    );

    if (unrealisticRecords.length > 0) {
      issues.push({
        type: "unrealistic_values",
        severity: "error",
        message: `${unrealisticRecords.length} records have unrealistic values (efficiency outside 0-100%, sleep > 24h, or deep sleep > total sleep).`,
        dates: unrealisticRecords.slice(0, 5).map(r => r.date),
      });
    }

    // Determine overall data authenticity status
    let authenticityStatus: "verified" | "mixed" | "questionnaire_only" | "no_data";

    if (sleepData.length === 0) {
      authenticityStatus = "no_data";
    } else if (wearableData.length === 0) {
      authenticityStatus = "questionnaire_only";
    } else if (questionnaireData.length > 0 && wearableData.length > 0) {
      authenticityStatus = "mixed";
    } else {
      authenticityStatus = "verified";
    }

    return {
      // User connection status
      userProfile: {
        email: user.email,
        appleHealthConnected: user.apple_health_connected === true,
        createdAt: user.created_at,
      },

      // Overall status
      authenticityStatus,
      authenticityMessage: {
        verified: "All sleep data comes from verified wearable devices",
        mixed: "Data contains both wearable and questionnaire sources - use caution when interpreting",
        questionnaire_only: "All sleep data is from questionnaires (self-reported), not wearables",
        no_data: "No sleep data available for this user",
      }[authenticityStatus],

      // Data counts
      summary: {
        totalSleepRecords: sleepData.length,
        wearableRecords: wearableData.length,
        questionnaireRecords: questionnaireData.length,
        heartRateRecords: hrData.length,
        activityRecords: activityData.length,
        circadianRecords: circadianData.length,
        uniqueSources: Object.keys(sourceBreakdown).length,
      },

      // Source breakdown
      sourceBreakdown,

      // Data quality issues
      issues,
      hasIssues: issues.length > 0,
      criticalIssues: issues.filter(i => i.severity === "error").length,

      // Recommendations
      recommendations: [
        ...(authenticityStatus === "questionnaire_only" ? [
          "This user has no wearable data - sleep stage metrics (deep, REM, light) cannot be measured from questionnaires alone"
        ] : []),
        ...(authenticityStatus === "mixed" ? [
          "Consider filtering dashboard views to show only wearable-sourced data for accurate physiological metrics",
          "Questionnaire data is useful for subjective perception but should not be used for sleep architecture analysis"
        ] : []),
        ...(issues.some(i => i.type === "fabricated_stages") ? [
          "CRITICAL: Remove fabricated sleep stage data from questionnaire records"
        ] : []),
      ],
    };
  },
});

/**
 * Get detailed audit trail for a specific date's sleep data.
 * Shows exactly what data exists and from what sources.
 */
export const auditSleepDataForDate = query({
  args: {
    userId: v.id("users"),
    date: v.string(),
  },
  handler: async (ctx, args) => {
    const { userId, date } = args;

    // Get sleep data for this date
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    // Get sleep stages for this date
    const stages = await ctx.db
      .query("user_sleep_stages")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .collect();

    // Get heart rate for this date
    const heartRate = await ctx.db
      .query("user_heart_rate")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    if (!sleepData) {
      return {
        found: false,
        date,
        message: `No sleep data found for ${date}`,
      };
    }

    // Parse all sources if available
    let allSources: string[] = [];
    if (sleepData.all_sources_json) {
      try {
        allSources = JSON.parse(sleepData.all_sources_json);
      } catch {
        // Ignore parse errors
      }
    }

    // Determine data authenticity
    const isFromWearable = sleepData.primary_source && sleepData.primary_source !== "Questionnaire";
    const hasStageData = stages.length > 0 ||
      (sleepData.deep_sleep_mins !== undefined && sleepData.deep_sleep_mins > 0);

    // Check for data integrity issues
    const integrityIssues: string[] = [];

    if (!isFromWearable && hasStageData) {
      integrityIssues.push("Sleep stage data exists but source is not a wearable - this data is fabricated");
    }

    // Calculate percentages
    const totalSleepMins = sleepData.total_sleep_mins || 0;
    const deepPct = totalSleepMins > 0 && sleepData.deep_sleep_mins
      ? Math.round((sleepData.deep_sleep_mins / totalSleepMins) * 100)
      : null;
    const remPct = totalSleepMins > 0 && sleepData.rem_sleep_mins
      ? Math.round((sleepData.rem_sleep_mins / totalSleepMins) * 100)
      : null;
    const lightPct = totalSleepMins > 0 && sleepData.light_sleep_mins
      ? Math.round((sleepData.light_sleep_mins / totalSleepMins) * 100)
      : null;

    return {
      found: true,
      date,

      // Source verification
      source: {
        primarySource: sleepData.primary_source || "Unknown",
        sourceBundleId: sleepData.source_bundle_id || null,
        allSources: allSources.length > 0 ? allSources : [sleepData.primary_source || "Unknown"],
        isMultiSource: sleepData.is_multi_source === true,
        isFromWearable,
        isFromQuestionnaire: sleepData.primary_source === "Questionnaire",
      },

      // Core metrics
      metrics: {
        totalSleepMins: sleepData.total_sleep_mins,
        totalSleepHours: sleepData.total_sleep_mins ? (sleepData.total_sleep_mins / 60).toFixed(1) : null,
        sleepEfficiency: sleepData.sleep_efficiency,
        sleepLatencyMins: sleepData.sleep_latency_mins,
        interruptionsCount: sleepData.interruptions_count,
        awakeMins: sleepData.awake_mins,
      },

      // Sleep architecture (ONLY valid from wearables)
      sleepArchitecture: {
        available: isFromWearable && hasStageData,
        trustworthy: isFromWearable,
        deepSleepMins: sleepData.deep_sleep_mins,
        deepSleepPct: deepPct,
        remSleepMins: sleepData.rem_sleep_mins,
        remSleepPct: remPct,
        lightSleepMins: sleepData.light_sleep_mins,
        lightSleepPct: lightPct,
        stageTransitions: stages.length,
      },

      // Heart rate data (if available)
      heartRate: heartRate ? {
        available: true,
        restingHr: heartRate.resting_hr,
        avgHr: heartRate.avg_hr,
        hrvMorning: heartRate.hrv_morning,
        hrvAvg: heartRate.hrv_avg,
      } : {
        available: false,
      },

      // Timing information
      timing: {
        inBedTime: sleepData.in_bed_time ? new Date(sleepData.in_bed_time).toISOString() : null,
        asleepTime: sleepData.asleep_time ? new Date(sleepData.asleep_time).toISOString() : null,
        wakeTime: sleepData.wake_time ? new Date(sleepData.wake_time).toISOString() : null,
      },

      // Subjective data (from questionnaire)
      subjective: {
        quality: sleepData.subjective_quality,
        dayType: sleepData.day_type,
        napsTaken: sleepData.naps_taken,
        napCount: sleepData.nap_count,
        napTotalMins: sleepData.nap_total_mins,
        medicationsTaken: sleepData.medications_taken,
      },

      // Sync metadata
      metadata: {
        syncedAt: sleepData.synced_at ? new Date(sleepData.synced_at).toISOString() : null,
        dayNumber: sleepData.day_number,
      },

      // Data integrity
      integrityStatus: integrityIssues.length === 0 ? "valid" : "issues_found",
      integrityIssues,
    };
  },
});

/**
 * Get wearable data table counts for a user.
 * Useful for debugging what data exists before/after reset.
 */
export const getWearableDataCounts = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;

    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const sleepStages = await ctx.db
      .query("user_sleep_stages")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const heartRate = await ctx.db
      .query("user_heart_rate")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const activity = await ctx.db
      .query("user_activity")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const workouts = await ctx.db
      .query("user_workouts")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const circadian = await ctx.db
      .query("user_circadian_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const baselines = await ctx.db
      .query("user_baselines")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const perceptionGaps = await ctx.db
      .query("perception_gaps")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Categorize sleep data by source
    const sleepBySource: Record<string, number> = {};
    for (const record of sleepData) {
      const source = record.primary_source || "Unknown";
      sleepBySource[source] = (sleepBySource[source] || 0) + 1;
    }

    const totalRecords = sleepData.length + sleepStages.length + heartRate.length +
      activity.length + workouts.length + circadian.length + baselines.length + perceptionGaps.length;

    return {
      tables: {
        user_sleep_data: sleepData.length,
        user_sleep_stages: sleepStages.length,
        user_heart_rate: heartRate.length,
        user_activity: activity.length,
        user_workouts: workouts.length,
        user_circadian_data: circadian.length,
        user_baselines: baselines.length,
        perception_gaps: perceptionGaps.length,
      },
      sleepDataBySource: sleepBySource,
      totalRecords,
      hasWearableData: totalRecords > 0,
    };
  },
});

// ============================================
// Sleep Metrics Computation from Questionnaire Responses
// ============================================

/**
 * Compute sleep metrics from CSD_ (Consensus Sleep Diary) questionnaire responses
 * and save to user_sleep_data table. This bridges subjective questionnaire data
 * to the objective sleep metrics format used by the dashboard.
 *
 * Used by:
 * - Mock data generator (to populate dashboard during testing)
 * - Could be called after real users complete daily sleep log (to compute derived metrics)
 */
export const computeSleepMetricsFromResponses = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    date: v.string(), // YYYY-MM-DD format
  },
  handler: async (ctx, args) => {
    const { userId, dayNumber, date } = args;

    // Get all sleep log responses for this user and day (CSD_ or SD_ prefix)
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", userId).eq("day_number", dayNumber)
      )
      .collect();

    // Filter to sleep diary questions (both CSD_ and SD_ prefixes)
    const sleepResponses = responses.filter(r =>
      r.question_id.startsWith("CSD_") || r.question_id.startsWith("SD_")
    );

    if (sleepResponses.length === 0) {
      console.log(`[computeSleepMetrics] No sleep log responses found for user ${userId} day ${dayNumber}`);
      return { success: true }; // No data to compute, but not an error
    }

    // Build response map for easy lookup (supports both CSD_ and SD_ prefixes)
    const responseMap = new Map<string, { value?: string; number?: number; object?: string; array?: string }>();
    for (const r of sleepResponses) {
      responseMap.set(r.question_id, {
        value: r.response_value ?? undefined,
        number: r.response_number ?? undefined,
        object: r.response_object ?? undefined,
        array: r.response_array ?? undefined,
      });
    }

    // Helper to get response by either CSD_ or SD_ prefix
    const getResponse = (csdKey: string, sdKey: string) => {
      return responseMap.get(csdKey) ?? responseMap.get(sdKey);
    };

    // Parse time string to minutes since midnight
    const parseTimeToMinutes = (timeStr: string | undefined): number | null => {
      if (!timeStr) return null;
      const match = timeStr.match(/^(\d{1,2}):(\d{2})$/);
      if (!match) return null;
      const hours = parseInt(match[1], 10);
      const mins = parseInt(match[2], 10);
      return hours * 60 + mins;
    };

    // Extract values from responses (supporting both CSD_ and SD_ prefixes)
    const intoBedTime = parseTimeToMinutes(getResponse("CSD_INTO_BED", "SD_GOT_INTO_BED")?.value);
    const trySleepTime = parseTimeToMinutes(getResponse("CSD_TRY_SLEEP", "SD_LIGHTS_OUT")?.value);
    const finalWakeTime = parseTimeToMinutes(getResponse("CSD_FINAL_WAKE", "SD_FINAL_WAKE")?.value);
    const outOfBedTime = parseTimeToMinutes(getResponse("CSD_OUT_BED", "SD_OUT_OF_BED")?.value);
    const latencyMins = getResponse("CSD_LATENCY", "SD_SLEEP_LATENCY")?.number ?? null;
    const awakenings = getResponse("CSD_AWAKENINGS", "SD_AWAKENINGS_COUNT")?.number ?? null;
    const wasoMins = getResponse("CSD_WASO", "SD_AWAKENINGS_DURATION")?.number ?? null;
    const quality = getResponse("CSD_QUALITY", "SD_SLEEP_QUALITY")?.number ?? null;

    // Extract day context fields (new fields for clinical analysis)
    const dayType = getResponse("CSD_DAY_TYPE", "SD_DAY_TYPE")?.value ?? undefined;

    // Nap tracking
    const napsTaken = getResponse("CSD_NAPS", "SD_NAPS_TAKEN")?.value;
    const napsTakenBool = napsTaken === "Yes" || napsTaken === "true";
    const napCount = napsTakenBool ? (getResponse("CSD_NAP_COUNT", "SD_NAPS_COUNT")?.number ?? undefined) : undefined;
    const napDetailsRaw = napsTakenBool ? (getResponse("CSD_NAP_DETAILS", "SD_NAP_DETAILS")?.object ?? undefined) : undefined;

    // Calculate total nap duration from details if available
    let napTotalMins: number | undefined;
    if (napDetailsRaw) {
      try {
        const napDetails = JSON.parse(napDetailsRaw);
        if (Array.isArray(napDetails)) {
          napTotalMins = napDetails.reduce((sum: number, nap: { nap_duration_minutes?: number }) =>
            sum + (nap.nap_duration_minutes ?? 0), 0);
        }
      } catch (e) {
        console.log(`[computeSleepMetrics] Failed to parse nap details: ${e}`);
      }
    }

    // Medication tracking
    const medsTaken = getResponse("CSD_MEDS", "SD_MEDICATION_TAKEN")?.value;
    const medsTakenBool = medsTaken === "Yes" || medsTaken === "true";
    const medsTime = medsTakenBool ? (getResponse("CSD_MEDS_TIME", "SD_MEDICATION_TIME")?.value ?? undefined) : undefined;
    const medsCategoriesRaw = getResponse("CSD_MEDS_CATEGORIES", "SD_MEDICATION_CATEGORIES")?.array ?? undefined;

    // Calculate derived metrics
    let totalSleepMins: number | undefined;
    let sleepEfficiency: number | undefined;
    let timeInBedMins: number | undefined;

    // Time in bed = outOfBed - intoBed (handling midnight crossing)
    if (intoBedTime !== null && outOfBedTime !== null) {
      if (outOfBedTime > intoBedTime) {
        timeInBedMins = outOfBedTime - intoBedTime;
      } else {
        // Crossed midnight: e.g., 23:00 to 07:00 = 8 hours
        timeInBedMins = (24 * 60 - intoBedTime) + outOfBedTime;
      }
    }

    // Total sleep time = Time in bed - latency - WASO
    if (timeInBedMins !== undefined) {
      const latency = latencyMins ?? 0;
      const waso = wasoMins ?? 0;
      totalSleepMins = Math.max(0, timeInBedMins - latency - waso);
    }

    // Sleep efficiency = (Total sleep time / Time in bed) * 100
    if (totalSleepMins !== undefined && timeInBedMins !== undefined && timeInBedMins > 0) {
      sleepEfficiency = Math.round((totalSleepMins / timeInBedMins) * 100);
    }

    // Generate realistic sleep stage distribution (estimated from total sleep)
    // Typical adult: 20-25% deep, 50-55% light, 20-25% REM
    let deepSleepMins: number | undefined;
    let lightSleepMins: number | undefined;
    let remSleepMins: number | undefined;

    if (totalSleepMins !== undefined && totalSleepMins > 0) {
      // Add some variance based on quality rating
      const qualityFactor = quality ? (quality / 5) : 0.7; // 1-5 scale normalized

      deepSleepMins = Math.round(totalSleepMins * (0.15 + qualityFactor * 0.10)); // 15-25%
      remSleepMins = Math.round(totalSleepMins * (0.18 + qualityFactor * 0.07)); // 18-25%
      lightSleepMins = totalSleepMins - deepSleepMins - remSleepMins; // Remainder
    }

    // Convert times to Unix timestamps for storage
    const dateObj = new Date(date + "T00:00:00");
    const inBedTimestamp = intoBedTime !== null
      ? new Date(dateObj.getTime() - 86400000 + intoBedTime * 60000).getTime() // Previous day
      : undefined;
    const asleepTimestamp = trySleepTime !== null && latencyMins !== null
      ? new Date(dateObj.getTime() - 86400000 + (trySleepTime + latencyMins) * 60000).getTime()
      : undefined;
    const wakeTimestamp = finalWakeTime !== null
      ? new Date(dateObj.getTime() + finalWakeTime * 60000).getTime()
      : undefined;

    // Check for existing entry
    const existing = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    const now = Date.now();
    const sleepData = {
      // Journey context
      day_number: dayNumber,
      // Time fields
      in_bed_time: inBedTimestamp,
      asleep_time: asleepTimestamp,
      wake_time: wakeTimestamp,
      total_sleep_mins: totalSleepMins,
      sleep_efficiency: sleepEfficiency,
      deep_sleep_mins: deepSleepMins,
      light_sleep_mins: lightSleepMins,
      rem_sleep_mins: remSleepMins,
      awake_mins: wasoMins ?? undefined,
      interruptions_count: awakenings ?? undefined,
      sleep_latency_mins: latencyMins ?? undefined,
      // Day context (for clinical analysis of workday vs weekend patterns)
      day_type: dayType,
      // Nap tracking (daytime sleep patterns)
      naps_taken: napsTakenBool || undefined,
      nap_count: napCount,
      nap_total_mins: napTotalMins,
      nap_details_json: napDetailsRaw,
      // Medication tracking (critical for clinical correlation)
      medications_taken: medsTakenBool || undefined,
      medication_time: medsTime,
      medication_categories_json: medsCategoriesRaw,
      // Subjective quality (for perception vs reality analysis)
      subjective_quality: quality ?? undefined,
      // Source tracking
      primary_source: "Questionnaire",
      source_bundle_id: "com.zoesleep.app",
      synced_at: now,
    };

    if (existing) {
      await ctx.db.patch(existing._id, sleepData);
      console.log(`[computeSleepMetrics] Updated sleep data for ${date}: ${totalSleepMins} mins, ${sleepEfficiency}% eff, dayType=${dayType}, naps=${napsTakenBool}, meds=${medsTakenBool}`);
    } else {
      await ctx.db.insert("user_sleep_data", {
        user_id: userId,
        date,
        ...sleepData,
      });
      console.log(`[computeSleepMetrics] Created sleep data for ${date}: ${totalSleepMins} mins, ${sleepEfficiency}% eff, dayType=${dayType}, naps=${napsTakenBool}, meds=${medsTakenBool}`);
    }

    return { success: true };
  },
});

/**
 * Retroactively compute sleep metrics for ALL existing CSD_ questionnaire responses.
 * This is useful when mock data was generated before the computeSleepMetricsFromResponses
 * function was in place, or to fix data integrity issues.
 */
export const computeAllSleepMetricsFromResponses = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;

    // Get all CSD_ responses for this user, grouped by day
    const allResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const csdResponses = allResponses.filter(r => r.question_id.startsWith("CSD_"));

    if (csdResponses.length === 0) {
      console.log(`[computeAllSleepMetrics] No CSD_ responses found for user ${userId}`);
      return { success: true, daysProcessed: 0 };
    }

    // Group responses by day_number
    const responsesByDay = new Map<number, typeof csdResponses>();
    for (const r of csdResponses) {
      const day = r.day_number ?? 1; // Default to day 1 if not specified
      if (!responsesByDay.has(day)) {
        responsesByDay.set(day, []);
      }
      responsesByDay.get(day)!.push(r);
    }

    console.log(`[computeAllSleepMetrics] Found ${responsesByDay.size} days of CSD_ responses`);

    // Helper functions
    const parseTimeToMinutes = (timeStr: string | undefined): number | null => {
      if (!timeStr) return null;
      const match = timeStr.match(/^(\d{1,2}):(\d{2})$/);
      if (!match) return null;
      const hours = parseInt(match[1], 10);
      const mins = parseInt(match[2], 10);
      return hours * 60 + mins;
    };

    // Get user to find journey start date (use started_at or created_at as fallback)
    const user = await ctx.db.get(userId);
    const journeyStartDate = user?.started_at
      ? new Date(user.started_at)
      : new Date(user?.created_at ?? Date.now());

    let daysProcessed = 0;

    // Process each day
    for (const [dayNumber, dayResponses] of responsesByDay.entries()) {
      // Calculate the date for this day based on journey start
      const dateObj = new Date(journeyStartDate);
      dateObj.setDate(dateObj.getDate() + dayNumber - 1);
      const date = dateObj.toISOString().split('T')[0];

      // Build response map
      const responseMap = new Map<string, { value?: string; number?: number }>();
      for (const r of dayResponses) {
        responseMap.set(r.question_id, {
          value: r.response_value ?? undefined,
          number: r.response_number ?? undefined,
        });
      }

      // Extract values
      const intoBedTime = parseTimeToMinutes(responseMap.get("CSD_INTO_BED")?.value);
      const trySleepTime = parseTimeToMinutes(responseMap.get("CSD_TRY_SLEEP")?.value);
      const finalWakeTime = parseTimeToMinutes(responseMap.get("CSD_FINAL_WAKE")?.value);
      const outOfBedTime = parseTimeToMinutes(responseMap.get("CSD_OUT_BED")?.value);
      const latencyMins = responseMap.get("CSD_LATENCY")?.number ?? null;
      const awakenings = responseMap.get("CSD_AWAKENINGS")?.number ?? null;
      const wasoMins = responseMap.get("CSD_WASO")?.number ?? null;
      const quality = responseMap.get("CSD_QUALITY")?.number ?? null;

      // Skip if missing critical data
      if (intoBedTime === null || outOfBedTime === null) {
        console.log(`[computeAllSleepMetrics] Skipping day ${dayNumber}: missing bed times`);
        continue;
      }

      // Calculate metrics
      let timeInBedMins: number;
      if (outOfBedTime > intoBedTime) {
        timeInBedMins = outOfBedTime - intoBedTime;
      } else {
        timeInBedMins = (24 * 60 - intoBedTime) + outOfBedTime;
      }

      const latency = latencyMins ?? 0;
      const waso = wasoMins ?? 0;
      const totalSleepMins = Math.max(0, timeInBedMins - latency - waso);
      const sleepEfficiency = timeInBedMins > 0
        ? Math.round((totalSleepMins / timeInBedMins) * 100)
        : 0;

      // NOTE: Sleep stages (deep, REM, light) CANNOT be derived from questionnaires.
      // They require wearable sensors to measure. We do NOT fabricate these values.

      // Calculate timestamps
      const dayDateObj = new Date(date + "T00:00:00");
      const inBedTimestamp = new Date(dayDateObj.getTime() - 86400000 + intoBedTime * 60000).getTime();
      const asleepTimestamp = trySleepTime !== null && latencyMins !== null
        ? new Date(dayDateObj.getTime() - 86400000 + (trySleepTime + latencyMins) * 60000).getTime()
        : undefined;
      const wakeTimestamp = finalWakeTime !== null
        ? new Date(dayDateObj.getTime() + finalWakeTime * 60000).getTime()
        : undefined;

      // Check for existing entry
      const existing = await ctx.db
        .query("user_sleep_data")
        .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
        .first();

      const now = Date.now();
      const sleepData = {
        in_bed_time: inBedTimestamp,
        asleep_time: asleepTimestamp,
        wake_time: wakeTimestamp,
        total_sleep_mins: totalSleepMins,
        sleep_efficiency: sleepEfficiency,
        // Sleep stages NOT populated - they require wearable sensors
        awake_mins: wasoMins ?? undefined,
        interruptions_count: awakenings ?? undefined,
        sleep_latency_mins: latencyMins ?? undefined,
        primary_source: "Questionnaire",  // Critical: marks this as subjective data
        source_bundle_id: "com.zoesleep.app",
        synced_at: now,
      };

      if (existing) {
        await ctx.db.patch(existing._id, sleepData);
      } else {
        await ctx.db.insert("user_sleep_data", {
          user_id: userId,
          date,
          ...sleepData,
        });
      }

      daysProcessed++;
      console.log(`[computeAllSleepMetrics] Day ${dayNumber} (${date}): ${totalSleepMins} mins, ${sleepEfficiency}% efficiency`);
    }

    return { success: true, daysProcessed };
  },
});

// ============================================
// HRV Data Functions (Intra-Night Recovery)
// ============================================

/**
 * Sync individual HRV samples to Convex
 * Used for detailed HRV charting
 */
export const syncHRVSamples = mutation({
  args: {
    userId: v.id("users"),
    samples: v.array(v.object({
      date: v.string(),
      sampleTime: v.number(),
      hrvValue: v.number(),
      sampleType: v.string(),
      source: v.string(),
      sourceBundleId: v.optional(v.string()),
      isDuringSleep: v.boolean(),
    })),
  },
  handler: async (ctx, args) => {
    const { userId, samples } = args;
    const now = Date.now();
    let insertedCount = 0;

    for (const sample of samples) {
      // Check for existing sample at same timestamp
      const existing = await ctx.db
        .query("user_hrv_samples")
        .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", sample.date))
        .filter((q) => q.eq(q.field("sample_time"), sample.sampleTime))
        .first();

      if (!existing) {
        await ctx.db.insert("user_hrv_samples", {
          user_id: userId,
          date: sample.date,
          sample_time: sample.sampleTime,
          hrv_value: sample.hrvValue,
          sample_type: sample.sampleType,
          source: sample.source,
          source_bundle_id: sample.sourceBundleId,
          is_during_sleep: sample.isDuringSleep,
          synced_at: now,
        });
        insertedCount++;
      }
    }

    return { success: true, samplesInserted: insertedCount };
  },
});

/**
 * Sync HRV nightly summary to Convex
 * Aggregated evening/night/morning HRV data for a single night
 */
export const syncHRVNightlySummary = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),
    eveningHrvAvg: v.optional(v.number()),
    eveningHrvMin: v.optional(v.number()),
    eveningHrvMax: v.optional(v.number()),
    eveningSampleCount: v.optional(v.number()),
    intraNightHrvAvg: v.optional(v.number()),
    intraNightHrvPeak: v.optional(v.number()),
    peakTime: v.optional(v.number()),
    sampleCount: v.optional(v.number()),
    sampleIntervalMins: v.optional(v.number()),
    morningHrvAvg: v.optional(v.number()),
    morningSampleCount: v.optional(v.number()),
    recoveryRatio: v.optional(v.number()),
    timeToPeakMins: v.optional(v.number()),
    primarySource: v.optional(v.string()),
    hrvCapability: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { userId, date, ...summaryData } = args;
    const now = Date.now();

    // Check for existing summary
    const existing = await ctx.db
      .query("user_hrv_nightly_summary")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    const data = {
      evening_hrv_avg: summaryData.eveningHrvAvg,
      evening_hrv_min: summaryData.eveningHrvMin,
      evening_hrv_max: summaryData.eveningHrvMax,
      evening_sample_count: summaryData.eveningSampleCount,
      intra_night_hrv_avg: summaryData.intraNightHrvAvg,
      intra_night_hrv_peak: summaryData.intraNightHrvPeak,
      peak_time: summaryData.peakTime,
      sample_count: summaryData.sampleCount,
      sample_interval_mins: summaryData.sampleIntervalMins,
      morning_hrv_avg: summaryData.morningHrvAvg,
      morning_sample_count: summaryData.morningSampleCount,
      recovery_ratio: summaryData.recoveryRatio,
      time_to_peak_mins: summaryData.timeToPeakMins,
      primary_source: summaryData.primarySource,
      hrv_capability: summaryData.hrvCapability,
      synced_at: now,
    };

    if (existing) {
      await ctx.db.patch(existing._id, data);
      return { success: true, action: "updated" };
    } else {
      await ctx.db.insert("user_hrv_nightly_summary", {
        user_id: userId,
        date,
        ...data,
      });
      return { success: true, action: "inserted" };
    }
  },
});

/**
 * Sync HRV Charge (recovery score) to Convex
 */
export const syncHRVCharge = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),
    chargeScore: v.number(),
    recoveryTrajectory: v.string(),
    confidence: v.number(),
    eveningComponent: v.optional(v.number()),
    recoveryComponent: v.optional(v.number()),
    trendModifier: v.optional(v.number()),
    eveningHrvUsed: v.optional(v.number()),
    peakHrvUsed: v.optional(v.number()),
    morningHrvUsed: v.optional(v.number()),
    baselineUsed: v.string(),
    deviationFromBaseline: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, date, ...chargeData } = args;
    const now = Date.now();

    // Check for existing charge
    const existing = await ctx.db
      .query("user_hrv_charge")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    const data = {
      charge_score: chargeData.chargeScore,
      recovery_trajectory: chargeData.recoveryTrajectory,
      confidence: chargeData.confidence,
      evening_component: chargeData.eveningComponent,
      recovery_component: chargeData.recoveryComponent,
      trend_modifier: chargeData.trendModifier,
      evening_hrv_used: chargeData.eveningHrvUsed,
      peak_hrv_used: chargeData.peakHrvUsed,
      morning_hrv_used: chargeData.morningHrvUsed,
      baseline_used: chargeData.baselineUsed,
      deviation_from_baseline: chargeData.deviationFromBaseline,
      computed_at: now,
    };

    if (existing) {
      await ctx.db.patch(existing._id, data);
      return { success: true, action: "updated" };
    } else {
      await ctx.db.insert("user_hrv_charge", {
        user_id: userId,
        date,
        ...data,
      });
      return { success: true, action: "inserted" };
    }
  },
});

/**
 * Update or create personal HRV baseline
 */
export const updateHRVBaseline = mutation({
  args: {
    userId: v.id("users"),
    avgEveningHrv: v.number(),
    avgMorningHrv: v.number(),
    avgPeakHrv: v.number(),
    avgRecoveryRatio: v.number(),
    stdEveningHrv: v.number(),
    stdMorningHrv: v.number(),
    daysInBaseline: v.number(),
    oldestDate: v.string(),
    newestDate: v.string(),
  },
  handler: async (ctx, args) => {
    const { userId, ...baselineData } = args;
    const now = Date.now();

    // Check for existing baseline
    const existing = await ctx.db
      .query("user_hrv_baseline")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .first();

    const data = {
      avg_evening_hrv: baselineData.avgEveningHrv,
      avg_morning_hrv: baselineData.avgMorningHrv,
      avg_peak_hrv: baselineData.avgPeakHrv,
      avg_recovery_ratio: baselineData.avgRecoveryRatio,
      std_evening_hrv: baselineData.stdEveningHrv,
      std_morning_hrv: baselineData.stdMorningHrv,
      days_in_baseline: baselineData.daysInBaseline,
      oldest_date: baselineData.oldestDate,
      newest_date: baselineData.newestDate,
      last_updated: now,
    };

    if (existing) {
      await ctx.db.patch(existing._id, data);
      return { success: true, action: "updated" };
    } else {
      await ctx.db.insert("user_hrv_baseline", {
        user_id: userId,
        ...data,
      });
      return { success: true, action: "inserted" };
    }
  },
});

/**
 * Get HRV baseline for a user
 */
export const getHRVBaseline = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("user_hrv_baseline")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();
  },
});

/**
 * Get HRV nightly summaries for a user (last N days)
 */
export const getHRVSummaries = query({
  args: {
    userId: v.id("users"),
    daysBack: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const summaries = await ctx.db
      .query("user_hrv_nightly_summary")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sort by date descending and limit
    const sorted = summaries.sort((a, b) => b.date.localeCompare(a.date));
    const limit = args.daysBack ?? 30;
    return sorted.slice(0, limit);
  },
});

/**
 * Get HRV Charge history for a user (last N days)
 */
export const getHRVChargeHistory = query({
  args: {
    userId: v.id("users"),
    daysBack: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const charges = await ctx.db
      .query("user_hrv_charge")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sort by date descending and limit
    const sorted = charges.sort((a, b) => b.date.localeCompare(a.date));
    const limit = args.daysBack ?? 30;
    return sorted.slice(0, limit);
  },
});

/**
 * Get HRV samples for a specific date (for charting)
 */
export const getHRVSamplesForDate = query({
  args: {
    userId: v.id("users"),
    date: v.string(),
  },
  handler: async (ctx, args) => {
    const samples = await ctx.db
      .query("user_hrv_samples")
      .withIndex("by_user_date", (q) => q.eq("user_id", args.userId).eq("date", args.date))
      .collect();

    // Sort by sample time
    return samples.sort((a, b) => a.sample_time - b.sample_time);
  },
});

// ============================================
// Sleep Score Functions (Unified Scoring)
// ============================================

/**
 * Sync sleep score to Convex
 */
export const syncSleepScore = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),
    zoeScore: v.number(),
    componentsJson: v.string(),
    nativeScoresJson: v.optional(v.string()),
    hrvCharge: v.optional(v.number()),
    hrvChargeTrajectory: v.optional(v.string()),
    primarySource: v.string(),
    allSourcesJson: v.optional(v.string()),
    confidence: v.number(),
  },
  handler: async (ctx, args) => {
    const { userId, date, ...scoreData } = args;
    const now = Date.now();

    // Check for existing score
    const existing = await ctx.db
      .query("user_sleep_scores")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    const data = {
      zoe_sleep_score: scoreData.zoeScore,
      zoe_score_components_json: scoreData.componentsJson,
      native_scores_json: scoreData.nativeScoresJson,
      hrv_charge: scoreData.hrvCharge,
      hrv_charge_trajectory: scoreData.hrvChargeTrajectory,
      primary_source: scoreData.primarySource,
      all_sources_json: scoreData.allSourcesJson,
      confidence: scoreData.confidence,
      computed_at: now,
    };

    if (existing) {
      await ctx.db.patch(existing._id, data);
      return { success: true, action: "updated" };
    } else {
      await ctx.db.insert("user_sleep_scores", {
        user_id: userId,
        date,
        ...data,
      });
      return { success: true, action: "inserted" };
    }
  },
});

/**
 * Get sleep score history for a user
 */
export const getSleepScoreHistory = query({
  args: {
    userId: v.id("users"),
    daysBack: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const scores = await ctx.db
      .query("user_sleep_scores")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sort by date descending and limit
    const sorted = scores.sort((a, b) => b.date.localeCompare(a.date));
    const limit = args.daysBack ?? 30;
    return sorted.slice(0, limit);
  },
});

/**
 * Get combined sleep + HRV data for dashboard
 */
export const getSleepDashboardData = query({
  args: {
    userId: v.id("users"),
    daysBack: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.daysBack ?? 7;

    // Get sleep scores
    const scores = await ctx.db
      .query("user_sleep_scores")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    const sortedScores = scores.sort((a, b) => b.date.localeCompare(a.date)).slice(0, limit);

    // Get HRV charges
    const charges = await ctx.db
      .query("user_hrv_charge")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    const sortedCharges = charges.sort((a, b) => b.date.localeCompare(a.date)).slice(0, limit);

    // Get HRV baseline
    const baseline = await ctx.db
      .query("user_hrv_baseline")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    return {
      sleepScores: sortedScores,
      hrvCharges: sortedCharges,
      hrvBaseline: baseline,
    };
  },
});

// ============================================
// Source Preferences Functions
// ============================================

/**
 * Save or update sleep source preferences
 */
export const saveSourcePreferences = mutation({
  args: {
    userId: v.id("users"),
    connectedSourcesJson: v.string(),
    visibleSourcesJson: v.string(),
    priorityOverrideJson: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { userId, ...prefsData } = args;
    const now = Date.now();

    // Check for existing preferences
    const existing = await ctx.db
      .query("user_sleep_source_preferences")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .first();

    const data = {
      connected_sources_json: prefsData.connectedSourcesJson,
      visible_sources_json: prefsData.visibleSourcesJson,
      priority_override_json: prefsData.priorityOverrideJson,
      last_source_discovery: now,
      updated_at: now,
    };

    if (existing) {
      await ctx.db.patch(existing._id, data);
      return { success: true, action: "updated" };
    } else {
      await ctx.db.insert("user_sleep_source_preferences", {
        user_id: userId,
        ...data,
      });
      return { success: true, action: "inserted" };
    }
  },
});

/**
 * Get sleep source preferences for a user
 */
export const getSourcePreferences = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("user_sleep_source_preferences")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();
  },
});
