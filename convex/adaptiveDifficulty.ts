import { query, mutation, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";

// ============================================
// Adaptive Difficulty System
// Auto-adjusts task complexity based on compliance
// ============================================

// Difficulty adjustment thresholds
const LOW_COMPLIANCE_THRESHOLD = 50;   // Below 50% = struggling
const HIGH_COMPLIANCE_THRESHOLD = 90;  // Above 90% = excelling
const CONSECUTIVE_LOW_DAYS_TO_REDUCE = 3;
const CONSECUTIVE_HIGH_DAYS_TO_INCREASE = 7;
const MIN_DIFFICULTY = 1;
const MAX_DIFFICULTY = 5;

/**
 * Get difficulty status for all user interventions
 */
export const getDifficultyStatus = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.array(
    v.object({
      userInterventionId: v.string(),
      interventionId: v.string(),
      name: v.string(),
      currentDifficulty: v.number(),
      originalDifficulty: v.number(),
      rolling7DayCompliance: v.number(),
      consecutiveLowDays: v.number(),
      consecutiveHighDays: v.number(),
      isLocked: v.boolean(),
      lockedReason: v.optional(v.string()),
      lastAdjustment: v.optional(
        v.object({
          date: v.string(),
          direction: v.string(),
          reason: v.string(),
        })
      ),
      canBeReduced: v.boolean(),
      canBeIncreased: v.boolean(),
    })
  ),
  handler: async (ctx, args) => {
    // Get user's active interventions
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .collect();

    // Get difficulty settings
    const difficultySettings = await ctx.db
      .query("intervention_difficulty_settings")
      .collect();

    const difficultyMap = new Map(
      difficultySettings.map((d) => [d.user_intervention_id, d])
    );

    // Get intervention details
    const results = await Promise.all(
      userInterventions.map(async (ui) => {
        const intervention = await ctx.db.get(ui.intervention_id);
        const difficulty = difficultyMap.get(ui._id);

        // Default values if no difficulty settings exist
        const currentDifficulty = difficulty?.current_difficulty ?? 3;
        const originalDifficulty = difficulty?.original_difficulty ?? 3;
        const rolling7DayCompliance = difficulty?.rolling_7_day_compliance ?? 100;
        const consecutiveLowDays = difficulty?.consecutive_low_days ?? 0;
        const consecutiveHighDays = difficulty?.consecutive_high_days ?? 0;
        const isLocked = difficulty?.difficulty_locked ?? false;

        return {
          userInterventionId: ui._id,
          interventionId: intervention?.intervention_id || "",
          name: intervention?.name || "Unknown",
          currentDifficulty,
          originalDifficulty,
          rolling7DayCompliance,
          consecutiveLowDays,
          consecutiveHighDays,
          isLocked,
          lockedReason: difficulty?.lock_reason,
          lastAdjustment: difficulty?.last_adjustment_date
            ? {
                date: difficulty.last_adjustment_date,
                direction: difficulty.adjustment_direction || "none",
                reason: difficulty.adjustment_reason || "",
              }
            : undefined,
          canBeReduced: !isLocked && currentDifficulty > MIN_DIFFICULTY,
          canBeIncreased: !isLocked && currentDifficulty < MAX_DIFFICULTY,
        };
      })
    );

    return results;
  },
});

/**
 * Compute adaptive difficulty for a single user
 * Should be called daily or when compliance data changes
 */
export const computeAdaptiveDifficulty = mutation({
  args: {
    userId: v.id("users"),
  },
  returns: v.object({
    adjusted: v.number(),
    unchanged: v.number(),
    locked: v.number(),
    adjustments: v.array(
      v.object({
        interventionId: v.string(),
        previousDifficulty: v.number(),
        newDifficulty: v.number(),
        reason: v.string(),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    // Get user's active interventions
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .collect();

    // Get last 7 days of dates
    const last7Days: string[] = [];
    for (let i = 0; i < 7; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      last7Days.push(date.toISOString().split("T")[0]);
    }

    // Get compliance data for last 7 days
    const allCompliance = await ctx.db
      .query("intervention_compliance")
      .collect();

    const adjustments: {
      interventionId: string;
      previousDifficulty: number;
      newDifficulty: number;
      reason: string;
    }[] = [];
    let adjusted = 0;
    let unchanged = 0;
    let locked = 0;

    for (const ui of userInterventions) {
      // Get intervention details
      const intervention = await ctx.db.get(ui.intervention_id);

      // Get existing difficulty settings
      let difficultySettings = await ctx.db
        .query("intervention_difficulty_settings")
        .withIndex("by_intervention", (q) =>
          q.eq("user_intervention_id", ui._id)
        )
        .first();

      // Calculate 7-day compliance
      const uiCompliance = allCompliance.filter(
        (c) =>
          c.user_intervention_id === ui._id &&
          last7Days.includes(c.scheduled_date)
      );

      const completedDays = uiCompliance.filter((c) => c.completed).length;
      const rolling7DayCompliance =
        last7Days.length > 0 ? (completedDays / last7Days.length) * 100 : 100;

      // Determine consecutive low/high days
      let consecutiveLowDays = 0;
      let consecutiveHighDays = 0;

      // Sort by date descending to count streaks
      const sortedDays = [...last7Days].sort().reverse();
      for (const date of sortedDays) {
        const dayCompliance = uiCompliance.find(
          (c) => c.scheduled_date === date
        );
        if (dayCompliance?.completed) {
          if (consecutiveLowDays > 0) break; // Streak broken
          consecutiveHighDays++;
        } else {
          if (consecutiveHighDays > 0) break; // Streak broken
          consecutiveLowDays++;
        }
      }

      // Get current difficulty
      const currentDifficulty = difficultySettings?.current_difficulty ?? 3;
      const originalDifficulty = difficultySettings?.original_difficulty ?? 3;
      const isLocked = difficultySettings?.difficulty_locked ?? false;

      // Update or create difficulty settings with latest compliance
      let settingsId: Id<"intervention_difficulty_settings">;
      if (!difficultySettings) {
        settingsId = await ctx.db.insert("intervention_difficulty_settings", {
          user_intervention_id: ui._id,
          current_difficulty: currentDifficulty,
          original_difficulty: originalDifficulty,
          rolling_7_day_compliance: rolling7DayCompliance,
          consecutive_low_days: consecutiveLowDays,
          consecutive_high_days: consecutiveHighDays,
          difficulty_locked: false,
          created_at: now,
          updated_at: now,
        });
      } else {
        settingsId = difficultySettings._id;
        await ctx.db.patch(settingsId, {
          rolling_7_day_compliance: rolling7DayCompliance,
          consecutive_low_days: consecutiveLowDays,
          consecutive_high_days: consecutiveHighDays,
          updated_at: now,
        });
      }

      // Skip locked interventions
      if (isLocked) {
        locked++;
        continue;
      }

      // Determine if adjustment is needed
      let newDifficulty = currentDifficulty;
      let adjustmentReason = "";
      let adjustmentDirection = "";

      // Check for difficulty reduction
      if (
        consecutiveLowDays >= CONSECUTIVE_LOW_DAYS_TO_REDUCE &&
        currentDifficulty > MIN_DIFFICULTY
      ) {
        newDifficulty = Math.max(MIN_DIFFICULTY, currentDifficulty - 1);
        adjustmentReason = `Compliance below ${LOW_COMPLIANCE_THRESHOLD}% for ${consecutiveLowDays} consecutive days`;
        adjustmentDirection = "reduced";
      }
      // Check for difficulty increase (optional - flagged for review)
      else if (
        consecutiveHighDays >= CONSECUTIVE_HIGH_DAYS_TO_INCREASE &&
        currentDifficulty < MAX_DIFFICULTY &&
        rolling7DayCompliance >= HIGH_COMPLIANCE_THRESHOLD
      ) {
        // Don't auto-increase, just flag for physician review
        // newDifficulty = Math.min(MAX_DIFFICULTY, currentDifficulty + 1);
        // adjustmentReason = `Compliance above ${HIGH_COMPLIANCE_THRESHOLD}% for ${consecutiveHighDays} consecutive days`;
        // adjustmentDirection = "increased";
        unchanged++;
        continue;
      }

      if (newDifficulty !== currentDifficulty) {
        // Apply adjustment
        await ctx.db.patch(settingsId, {
          current_difficulty: newDifficulty,
          last_adjustment_date: today,
          adjustment_reason: adjustmentReason,
          adjustment_direction: adjustmentDirection,
          updated_at: now,
        });

        // Log the adjustment
        await ctx.db.insert("difficulty_adjustment_log", {
          user_intervention_id: ui._id,
          user_id: args.userId,
          previous_difficulty: currentDifficulty,
          new_difficulty: newDifficulty,
          adjustment_type: "auto_reduce",
          reason: adjustmentReason,
          rolling_compliance_at_adjustment: rolling7DayCompliance,
          adjusted_at: now,
        });

        adjustments.push({
          interventionId: intervention?.intervention_id || "",
          previousDifficulty: currentDifficulty,
          newDifficulty,
          reason: adjustmentReason,
        });

        adjusted++;
      } else {
        unchanged++;
      }
    }

    return {
      adjusted,
      unchanged,
      locked,
      adjustments,
    };
  },
});

/**
 * Manually adjust difficulty (physician action)
 */
export const manuallyAdjustDifficulty = mutation({
  args: {
    userInterventionId: v.id("user_interventions"),
    newDifficulty: v.number(),
    reason: v.string(),
    physicianId: v.string(),
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    // Validate difficulty range
    if (args.newDifficulty < MIN_DIFFICULTY || args.newDifficulty > MAX_DIFFICULTY) {
      return false;
    }

    // Get user intervention
    const ui = await ctx.db.get(args.userInterventionId);
    if (!ui) return false;

    // Get existing settings
    let settings = await ctx.db
      .query("intervention_difficulty_settings")
      .withIndex("by_intervention", (q) =>
        q.eq("user_intervention_id", args.userInterventionId)
      )
      .first();

    const previousDifficulty = settings?.current_difficulty ?? 3;
    let rolling7DayCompliance = settings?.rolling_7_day_compliance ?? 100;

    if (settings) {
      await ctx.db.patch(settings._id, {
        current_difficulty: args.newDifficulty,
        last_adjustment_date: today,
        adjustment_reason: args.reason,
        adjustment_direction: args.newDifficulty > previousDifficulty ? "increased" : "reduced",
        updated_at: now,
      });
    } else {
      await ctx.db.insert("intervention_difficulty_settings", {
        user_intervention_id: args.userInterventionId,
        current_difficulty: args.newDifficulty,
        original_difficulty: 3,
        rolling_7_day_compliance: 100,
        consecutive_low_days: 0,
        consecutive_high_days: 0,
        difficulty_locked: false,
        last_adjustment_date: today,
        adjustment_reason: args.reason,
        adjustment_direction: args.newDifficulty > previousDifficulty ? "increased" : "reduced",
        created_at: now,
        updated_at: now,
      });
    }

    // Log the adjustment
    await ctx.db.insert("difficulty_adjustment_log", {
      user_intervention_id: args.userInterventionId,
      user_id: ui.user_id,
      previous_difficulty: previousDifficulty,
      new_difficulty: args.newDifficulty,
      adjustment_type: "physician_override",
      reason: args.reason,
      rolling_compliance_at_adjustment: rolling7DayCompliance,
      adjusted_at: now,
      adjusted_by: args.physicianId,
    });

    return true;
  },
});

/**
 * Lock/unlock difficulty (physician action)
 */
export const lockDifficulty = mutation({
  args: {
    userInterventionId: v.id("user_interventions"),
    locked: v.boolean(),
    reason: v.optional(v.string()),
    physicianId: v.string(),
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Get existing settings
    let settings = await ctx.db
      .query("intervention_difficulty_settings")
      .withIndex("by_intervention", (q) =>
        q.eq("user_intervention_id", args.userInterventionId)
      )
      .first();

    if (settings) {
      await ctx.db.patch(settings._id, {
        difficulty_locked: args.locked,
        locked_by_physician_id: args.locked ? args.physicianId : undefined,
        locked_at: args.locked ? now : undefined,
        lock_reason: args.locked ? args.reason : undefined,
        updated_at: now,
      });
    } else {
      // Create settings with lock
      await ctx.db.insert("intervention_difficulty_settings", {
        user_intervention_id: args.userInterventionId,
        current_difficulty: 3,
        original_difficulty: 3,
        rolling_7_day_compliance: 100,
        consecutive_low_days: 0,
        consecutive_high_days: 0,
        difficulty_locked: args.locked,
        locked_by_physician_id: args.locked ? args.physicianId : undefined,
        locked_at: args.locked ? now : undefined,
        lock_reason: args.locked ? args.reason : undefined,
        created_at: now,
        updated_at: now,
      });
    }

    return true;
  },
});

/**
 * Reset difficulty to original
 */
export const resetDifficulty = mutation({
  args: {
    userInterventionId: v.id("user_interventions"),
    physicianId: v.optional(v.string()),
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    // Get user intervention
    const ui = await ctx.db.get(args.userInterventionId);
    if (!ui) return false;

    // Get existing settings
    const settings = await ctx.db
      .query("intervention_difficulty_settings")
      .withIndex("by_intervention", (q) =>
        q.eq("user_intervention_id", args.userInterventionId)
      )
      .first();

    if (!settings) return false;

    const previousDifficulty = settings.current_difficulty;

    await ctx.db.patch(settings._id, {
      current_difficulty: settings.original_difficulty,
      last_adjustment_date: today,
      adjustment_reason: "Reset to original difficulty",
      adjustment_direction: "reset",
      updated_at: now,
    });

    // Log the reset
    await ctx.db.insert("difficulty_adjustment_log", {
      user_intervention_id: args.userInterventionId,
      user_id: ui.user_id,
      previous_difficulty: previousDifficulty,
      new_difficulty: settings.original_difficulty,
      adjustment_type: "reset",
      reason: "Reset to original difficulty",
      rolling_compliance_at_adjustment: settings.rolling_7_day_compliance,
      adjusted_at: now,
      adjusted_by: args.physicianId,
    });

    return true;
  },
});

/**
 * Get difficulty adjustment history for a user
 */
export const getDifficultyHistory = query({
  args: {
    userId: v.id("users"),
    limit: v.optional(v.number()),
  },
  returns: v.array(
    v.object({
      interventionId: v.string(),
      interventionName: v.string(),
      previousDifficulty: v.number(),
      newDifficulty: v.number(),
      adjustmentType: v.string(),
      reason: v.string(),
      rollingCompliance: v.number(),
      adjustedAt: v.number(),
      adjustedBy: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const limitCount = args.limit ?? 20;

    // Get adjustment logs
    const logs = await ctx.db
      .query("difficulty_adjustment_log")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(limitCount);

    // Get intervention details
    const results = await Promise.all(
      logs.map(async (log) => {
        const ui = await ctx.db.get(log.user_intervention_id);
        let interventionName = "Unknown";
        let interventionId = "";

        if (ui) {
          const intervention = await ctx.db.get(ui.intervention_id);
          interventionName = intervention?.name || "Unknown";
          interventionId = intervention?.intervention_id || "";
        }

        return {
          interventionId,
          interventionName,
          previousDifficulty: log.previous_difficulty,
          newDifficulty: log.new_difficulty,
          adjustmentType: log.adjustment_type,
          reason: log.reason,
          rollingCompliance: log.rolling_compliance_at_adjustment,
          adjustedAt: log.adjusted_at,
          adjustedBy: log.adjusted_by,
        };
      })
    );

    return results;
  },
});

/**
 * Get patients with recent difficulty adjustments
 * For physician dashboard alerts
 */
export const getPatientsWithRecentAdjustments = query({
  args: {
    days: v.optional(v.number()), // Default 7
  },
  returns: v.array(
    v.object({
      userId: v.string(),
      username: v.string(),
      adjustmentCount: v.number(),
      latestAdjustment: v.object({
        interventionName: v.string(),
        direction: v.string(),
        date: v.string(),
      }),
    })
  ),
  handler: async (ctx, args) => {
    const daysAgo = args.days ?? 7;
    const cutoffTime = Date.now() - daysAgo * 24 * 60 * 60 * 1000;

    // Get recent adjustment logs
    const logs = await ctx.db
      .query("difficulty_adjustment_log")
      .withIndex("by_adjusted_at", (q) => q.gt("adjusted_at", cutoffTime))
      .collect();

    // Group by user
    const userMap = new Map<
      string,
      {
        userId: string;
        adjustments: typeof logs;
      }
    >();

    for (const log of logs) {
      const existing = userMap.get(log.user_id);
      if (existing) {
        existing.adjustments.push(log);
      } else {
        userMap.set(log.user_id, {
          userId: log.user_id,
          adjustments: [log],
        });
      }
    }

    // Build results
    const results = await Promise.all(
      Array.from(userMap.values()).map(async (entry) => {
        const user = await ctx.db
          .query("users")
          .filter((q) => q.eq(q.field("_id"), entry.userId))
          .first();
        const latestLog = entry.adjustments.sort(
          (a, b) => b.adjusted_at - a.adjusted_at
        )[0];

        let interventionName = "Unknown";
        if (latestLog) {
          const ui = await ctx.db.get(latestLog.user_intervention_id);
          if (ui) {
            const intervention = await ctx.db.get(ui.intervention_id);
            interventionName = intervention?.name || "Unknown";
          }
        }

        return {
          userId: entry.userId,
          username: user?.username ?? "Unknown",
          adjustmentCount: entry.adjustments.length,
          latestAdjustment: {
            interventionName,
            direction: latestLog?.adjustment_type || "unknown",
            date: new Date(latestLog?.adjusted_at || 0)
              .toISOString()
              .split("T")[0],
          },
        };
      })
    );

    // Sort by adjustment count (most first)
    return results.sort((a, b) => b.adjustmentCount - a.adjustmentCount);
  },
});
