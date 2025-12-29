import { v } from "convex/values";
import { mutation, query, internalMutation } from "./_generated/server";

/**
 * Circadian Signal Tracking Functions
 * Syncs and queries light exposure, temperature, and outdoor activity data
 * Requires iOS 17+ / watchOS 10+ for timeInDaylight
 * Requires Apple Watch Series 8+ for wrist temperature
 */

// ============================================
// Mutations
// ============================================

/**
 * Sync circadian data from iOS HealthKit
 * Upserts daily circadian metrics for a user
 */
export const syncCircadianData = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(), // YYYY-MM-DD
    timeInDaylightMins: v.optional(v.number()),
    morningLightMins: v.optional(v.number()),
    afternoonLightMins: v.optional(v.number()),
    outdoorWorkoutMins: v.optional(v.number()),
    outdoorWorkoutCount: v.optional(v.number()),
    sleepingWristTempDeviation: v.optional(v.number()),
    wristTempTrend: v.optional(v.string()),
    uvExposureIndex: v.optional(v.number()),
    circadianScore: v.optional(v.number()),
    scoreBreakdownJson: v.optional(v.string()),
    primarySource: v.optional(v.string()),
    sourceBundleId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { userId, date, ...data } = args;

    // Check for existing entry
    const existing = await ctx.db
      .query("user_circadian_data")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    const now = Date.now();

    if (existing) {
      // Update existing entry (merge with existing values)
      await ctx.db.patch(existing._id, {
        time_in_daylight_mins: data.timeInDaylightMins ?? existing.time_in_daylight_mins,
        morning_light_mins: data.morningLightMins ?? existing.morning_light_mins,
        afternoon_light_mins: data.afternoonLightMins ?? existing.afternoon_light_mins,
        outdoor_workout_mins: data.outdoorWorkoutMins ?? existing.outdoor_workout_mins,
        outdoor_workout_count: data.outdoorWorkoutCount ?? existing.outdoor_workout_count,
        sleeping_wrist_temp_deviation: data.sleepingWristTempDeviation ?? existing.sleeping_wrist_temp_deviation,
        wrist_temp_trend: data.wristTempTrend ?? existing.wrist_temp_trend,
        uv_exposure_index: data.uvExposureIndex ?? existing.uv_exposure_index,
        circadian_score: data.circadianScore ?? existing.circadian_score,
        score_breakdown_json: data.scoreBreakdownJson ?? existing.score_breakdown_json,
        primary_source: data.primarySource ?? existing.primary_source,
        source_bundle_id: data.sourceBundleId ?? existing.source_bundle_id,
        synced_at: now,
      });
      return existing._id;
    } else {
      // Create new entry
      return await ctx.db.insert("user_circadian_data", {
        user_id: userId,
        date,
        time_in_daylight_mins: data.timeInDaylightMins,
        morning_light_mins: data.morningLightMins,
        afternoon_light_mins: data.afternoonLightMins,
        outdoor_workout_mins: data.outdoorWorkoutMins,
        outdoor_workout_count: data.outdoorWorkoutCount,
        sleeping_wrist_temp_deviation: data.sleepingWristTempDeviation,
        wrist_temp_trend: data.wristTempTrend,
        uv_exposure_index: data.uvExposureIndex,
        circadian_score: data.circadianScore,
        score_breakdown_json: data.scoreBreakdownJson,
        primary_source: data.primarySource,
        source_bundle_id: data.sourceBundleId,
        synced_at: now,
      });
    }
  },
});

// ============================================
// Queries
// ============================================

/**
 * Get circadian data for a date range
 * Returns raw daily entries for charts and analysis
 */
export const getCircadianData = query({
  args: {
    userId: v.id("users"),
    startDate: v.optional(v.string()),
    endDate: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, startDate, endDate, limit = 14 } = args;

    const data = await ctx.db
      .query("user_circadian_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Filter by date range if provided
    let filtered = data;
    if (startDate && endDate) {
      filtered = data.filter((d) => d.date >= startDate && d.date <= endDate);
    }

    // Sort by date descending and limit
    return filtered
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, limit);
  },
});

/**
 * Get circadian summary for dashboard display
 * Returns aggregated stats with trend analysis
 */
export const getCircadianSummary = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, days = 14 } = args;

    const data = await ctx.db
      .query("user_circadian_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Get recent data sorted by date descending
    const recentData = data
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, days);

    if (recentData.length === 0) {
      return {
        hasData: false,
        avgDaylightMins: null,
        avgMorningLightMins: null,
        avgCircadianScore: null,
        avgTempDeviation: null,
        avgOutdoorMins: null,
        trend: null,
        daysWithData: 0,
        recentData: [],
      };
    }

    // Calculate averages for entries that have data
    const daylightValues = recentData.filter((d) => d.time_in_daylight_mins != null);
    const morningLightValues = recentData.filter((d) => d.morning_light_mins != null);
    const scoreValues = recentData.filter((d) => d.circadian_score != null);
    const tempValues = recentData.filter((d) => d.sleeping_wrist_temp_deviation != null);
    const outdoorValues = recentData.filter((d) => d.outdoor_workout_mins != null);

    const avgDaylight = daylightValues.length > 0
      ? Math.round(daylightValues.reduce((sum, d) => sum + (d.time_in_daylight_mins || 0), 0) / daylightValues.length)
      : null;

    const avgMorningLight = morningLightValues.length > 0
      ? Math.round(morningLightValues.reduce((sum, d) => sum + (d.morning_light_mins || 0), 0) / morningLightValues.length)
      : null;

    const avgScore = scoreValues.length > 0
      ? Math.round(scoreValues.reduce((sum, d) => sum + (d.circadian_score || 0), 0) / scoreValues.length)
      : null;

    const avgTemp = tempValues.length > 0
      ? tempValues.reduce((sum, d) => sum + (d.sleeping_wrist_temp_deviation || 0), 0) / tempValues.length
      : null;

    const avgOutdoor = outdoorValues.length > 0
      ? Math.round(outdoorValues.reduce((sum, d) => sum + (d.outdoor_workout_mins || 0), 0) / outdoorValues.length)
      : null;

    // Calculate trend by comparing first half to second half of data
    let trend: string | null = null;
    if (scoreValues.length >= 4) {
      const midpoint = Math.floor(scoreValues.length / 2);
      const recentHalf = scoreValues.slice(0, midpoint);
      const olderHalf = scoreValues.slice(midpoint);

      const recentAvg = recentHalf.reduce((sum, d) => sum + (d.circadian_score || 0), 0) / recentHalf.length;
      const olderAvg = olderHalf.reduce((sum, d) => sum + (d.circadian_score || 0), 0) / olderHalf.length;

      const diff = recentAvg - olderAvg;
      if (diff > 5) trend = "improving";
      else if (diff < -5) trend = "declining";
      else trend = "stable";
    }

    return {
      hasData: true,
      avgDaylightMins: avgDaylight,
      avgMorningLightMins: avgMorningLight,
      avgCircadianScore: avgScore,
      avgTempDeviation: avgTemp ? Math.round(avgTemp * 100) / 100 : null,
      avgOutdoorMins: avgOutdoor,
      trend,
      daysWithData: recentData.length,
      recentData: recentData.map((d) => ({
        date: d.date,
        daylightMins: d.time_in_daylight_mins,
        morningLightMins: d.morning_light_mins,
        afternoonLightMins: d.afternoon_light_mins,
        circadianScore: d.circadian_score,
        tempDeviation: d.sleeping_wrist_temp_deviation,
        outdoorMins: d.outdoor_workout_mins,
      })),
    };
  },
});

/**
 * Get today's circadian status for Watch complication
 * Lightweight query for quick display
 */
export const getCircadianStatus = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;

    // Get today's date in YYYY-MM-DD format
    const today = new Date().toISOString().split("T")[0];

    const todayData = await ctx.db
      .query("user_circadian_data")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", today))
      .first();

    const targetMins = 90; // Recommended 80-100 mins daily

    if (!todayData) {
      return {
        hasData: false,
        daylightMins: 0,
        targetMins,
        percentOfTarget: 0,
        circadianScore: null,
        needsMoreLight: true,
        morningLightMins: 0,
      };
    }

    const daylightMins = todayData.time_in_daylight_mins || 0;
    const percentOfTarget = Math.min(100, Math.round((daylightMins / targetMins) * 100));

    return {
      hasData: true,
      daylightMins: Math.round(daylightMins),
      targetMins,
      percentOfTarget,
      circadianScore: todayData.circadian_score,
      needsMoreLight: daylightMins < 60,
      morningLightMins: todayData.morning_light_mins || 0,
    };
  },
});

/**
 * Get circadian data for physician dashboard
 * Includes clinical interpretation helpers
 */
export const getCircadianDataForPhysician = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, days = 14 } = args;

    const summary = await ctx.db
      .query("user_circadian_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const recentData = summary
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, days);

    if (recentData.length === 0) {
      return {
        hasData: false,
        clinicalNotes: [],
        data: [],
      };
    }

    // Generate clinical interpretation notes
    const clinicalNotes: string[] = [];
    const daylightValues = recentData.filter((d) => d.time_in_daylight_mins != null);
    const tempValues = recentData.filter((d) => d.sleeping_wrist_temp_deviation != null);

    if (daylightValues.length > 0) {
      const avgDaylight = daylightValues.reduce((sum, d) => sum + (d.time_in_daylight_mins || 0), 0) / daylightValues.length;

      if (avgDaylight < 30) {
        clinicalNotes.push("Critical: Very low light exposure may significantly impact circadian rhythm");
      } else if (avgDaylight < 60) {
        clinicalNotes.push("Low light exposure may contribute to circadian misalignment");
      } else if (avgDaylight >= 80) {
        clinicalNotes.push("Adequate light exposure supporting circadian rhythm");
      }

      // Check morning light specifically
      const morningLightValues = recentData.filter((d) => d.morning_light_mins != null);
      if (morningLightValues.length > 0) {
        const avgMorningLight = morningLightValues.reduce((sum, d) => sum + (d.morning_light_mins || 0), 0) / morningLightValues.length;
        if (avgMorningLight < 15) {
          clinicalNotes.push("Minimal morning light exposure - consider morning light therapy");
        }
      }
    }

    if (tempValues.length > 0) {
      const avgTempDev = tempValues.reduce((sum, d) => sum + Math.abs(d.sleeping_wrist_temp_deviation || 0), 0) / tempValues.length;
      if (avgTempDev > 0.5) {
        clinicalNotes.push("Temperature variability may indicate circadian rhythm instability");
      }
    }

    return {
      hasData: true,
      clinicalNotes,
      data: recentData.map((d) => ({
        date: d.date,
        daylightMins: d.time_in_daylight_mins,
        morningLightMins: d.morning_light_mins,
        afternoonLightMins: d.afternoon_light_mins,
        circadianScore: d.circadian_score,
        tempDeviation: d.sleeping_wrist_temp_deviation,
        outdoorMins: d.outdoor_workout_mins,
        outdoorWorkoutCount: d.outdoor_workout_count,
      })),
    };
  },
});

// ============================================
// Mock Data Generation (Testing Only)
// ============================================

/**
 * Generate mock circadian data for testing
 * Run with: npx convex run circadian:generateMockCircadianData '{"userId": "...", "pattern": "healthy"}'
 *
 * Patterns:
 * - "healthy": Good light exposure, regular rhythm
 * - "poor_light": Low daylight exposure
 * - "shift_work": Irregular patterns with variable light
 * - "night_owl": Late light exposure, minimal morning light
 */
export const generateMockCircadianData = mutation({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()),
    pattern: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { userId, days = 14, pattern = "healthy" } = args;
    const now = Date.now();
    const insertedIds: string[] = [];

    // Generate data for each day
    for (let i = 0; i < days; i++) {
      const date = new Date(now - i * 24 * 60 * 60 * 1000);
      const dateStr = date.toISOString().split("T")[0];

      // Generate values based on pattern
      let data: {
        timeInDaylightMins: number;
        morningLightMins: number;
        afternoonLightMins: number;
        outdoorWorkoutMins: number;
        outdoorWorkoutCount: number;
        circadianScore: number;
        sleepingWristTempDeviation: number;
        wristTempTrend: string;
      };

      switch (pattern) {
        case "poor_light":
          data = {
            timeInDaylightMins: randomRange(15, 45),
            morningLightMins: randomRange(0, 10),
            afternoonLightMins: randomRange(10, 30),
            outdoorWorkoutMins: randomRange(0, 15),
            outdoorWorkoutCount: Math.random() > 0.7 ? 1 : 0,
            circadianScore: randomRange(35, 55),
            sleepingWristTempDeviation: randomRange(-0.4, 0.6) / 10,
            wristTempTrend: Math.random() > 0.5 ? "elevated" : "normal",
          };
          break;

        case "shift_work":
          // Variable patterns with occasional night shifts
          const isNightShift = Math.random() > 0.6;
          data = {
            timeInDaylightMins: isNightShift ? randomRange(10, 30) : randomRange(40, 80),
            morningLightMins: isNightShift ? randomRange(0, 5) : randomRange(10, 40),
            afternoonLightMins: isNightShift ? randomRange(5, 20) : randomRange(20, 50),
            outdoorWorkoutMins: randomRange(0, 30),
            outdoorWorkoutCount: Math.random() > 0.5 ? 1 : 0,
            circadianScore: isNightShift ? randomRange(30, 50) : randomRange(50, 70),
            sleepingWristTempDeviation: randomRange(-0.6, 0.8) / 10,
            wristTempTrend: isNightShift ? "irregular" : "normal",
          };
          break;

        case "night_owl":
          data = {
            timeInDaylightMins: randomRange(30, 60),
            morningLightMins: randomRange(0, 15), // Minimal morning light
            afternoonLightMins: randomRange(25, 50), // More afternoon
            outdoorWorkoutMins: randomRange(10, 40),
            outdoorWorkoutCount: Math.random() > 0.5 ? 1 : 0,
            circadianScore: randomRange(45, 65),
            sleepingWristTempDeviation: randomRange(-0.3, 0.5) / 10,
            wristTempTrend: "delayed",
          };
          break;

        case "healthy":
        default:
          data = {
            timeInDaylightMins: randomRange(70, 120),
            morningLightMins: randomRange(25, 60),
            afternoonLightMins: randomRange(30, 60),
            outdoorWorkoutMins: randomRange(20, 60),
            outdoorWorkoutCount: Math.random() > 0.3 ? Math.floor(Math.random() * 2) + 1 : 0,
            circadianScore: randomRange(70, 95),
            sleepingWristTempDeviation: randomRange(-0.2, 0.2) / 10,
            wristTempTrend: "normal",
          };
          break;
      }

      // Check for existing entry
      const existing = await ctx.db
        .query("user_circadian_data")
        .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", dateStr))
        .first();

      if (existing) {
        // Update existing
        await ctx.db.patch(existing._id, {
          time_in_daylight_mins: data.timeInDaylightMins,
          morning_light_mins: data.morningLightMins,
          afternoon_light_mins: data.afternoonLightMins,
          outdoor_workout_mins: data.outdoorWorkoutMins,
          outdoor_workout_count: data.outdoorWorkoutCount,
          circadian_score: data.circadianScore,
          sleeping_wrist_temp_deviation: data.sleepingWristTempDeviation,
          wrist_temp_trend: data.wristTempTrend,
          primary_source: "mock_generator",
          synced_at: now,
        });
        insertedIds.push(existing._id);
      } else {
        // Insert new
        const id = await ctx.db.insert("user_circadian_data", {
          user_id: userId,
          date: dateStr,
          time_in_daylight_mins: data.timeInDaylightMins,
          morning_light_mins: data.morningLightMins,
          afternoon_light_mins: data.afternoonLightMins,
          outdoor_workout_mins: data.outdoorWorkoutMins,
          outdoor_workout_count: data.outdoorWorkoutCount,
          circadian_score: data.circadianScore,
          sleeping_wrist_temp_deviation: data.sleepingWristTempDeviation,
          wrist_temp_trend: data.wristTempTrend,
          primary_source: "mock_generator",
          synced_at: now,
        });
        insertedIds.push(id);
      }
    }

    return {
      pattern,
      daysGenerated: days,
      recordIds: insertedIds,
    };
  },
});

/**
 * Helper: Generate random number in range
 */
function randomRange(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

/**
 * Clear all circadian data for a user (testing only)
 */
export const clearCircadianData = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const data = await ctx.db
      .query("user_circadian_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const d of data) {
      await ctx.db.delete(d._id);
    }

    return { deleted: data.length };
  },
});
