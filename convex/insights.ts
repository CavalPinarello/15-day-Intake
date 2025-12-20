import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

/**
 * Progressive Insight Teasers System
 *
 * Keeps users engaged during the 15-day journey by:
 * 1. Showing countdown teasers: "Sleep efficiency unlocks in 2 days"
 * 2. Showing discovery hints: "We're noticing something about your wake times..."
 * 3. Progressively revealing insights as data accumulates
 */

/**
 * Get all progressive insights with unlock status for a user
 */
export const getProgressiveInsights = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      teaserId: v.string(),
      title: v.string(),
      category: v.string(),
      icon: v.string(),
      color: v.optional(v.string()),
      teaserType: v.string(),
      isUnlocked: v.boolean(),
      daysUntilUnlock: v.optional(v.number()),
      lockedDescription: v.string(),
      unlockedDescription: v.optional(v.string()),
      discoveryHint: v.optional(v.string()),
      discoveryHintLevel: v.number(),
      dataPointsCollected: v.number(),
      insightValue: v.optional(v.any()),
    })
  ),
  handler: async (ctx, args) => {
    // Get user's current day
    const user = await ctx.db.get(args.userId);
    if (!user) return [];

    const currentDay = user.current_day ?? 1;

    // Get all active teasers
    const teasers = await ctx.db
      .query("insight_teasers")
      .filter((q) => q.eq(q.field("is_active"), true))
      .collect();

    // Get user's progress for each teaser
    const userProgress = await ctx.db
      .query("user_insight_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const progressMap = new Map(userProgress.map((p) => [p.teaser_id, p]));

    // Build response with unlock status
    const result = teasers
      .sort((a, b) => a.order_index - b.order_index)
      .map((teaser) => {
        const progress = progressMap.get(teaser.teaser_id);
        const isUnlocked = progress?.unlocked ?? currentDay >= teaser.unlock_day;
        const daysUntilUnlock = isUnlocked
          ? undefined
          : teaser.unlock_day - currentDay;

        // Parse discovery hints
        let discoveryHint: string | undefined;
        const hintLevel = progress?.discovery_hint_level ?? 0;
        if (teaser.discovery_hints_json && hintLevel > 0) {
          try {
            const hints = JSON.parse(teaser.discovery_hints_json) as string[];
            discoveryHint = hints[Math.min(hintLevel - 1, hints.length - 1)];
          } catch {
            // Invalid JSON, ignore
          }
        }

        // Parse insight value if unlocked
        let insightValue: unknown;
        if (isUnlocked && progress?.insight_value_json) {
          try {
            insightValue = JSON.parse(progress.insight_value_json);
          } catch {
            // Invalid JSON, ignore
          }
        }

        return {
          teaserId: teaser.teaser_id,
          title: teaser.title,
          category: teaser.category,
          icon: teaser.icon,
          color: teaser.color,
          teaserType: teaser.teaser_type,
          isUnlocked,
          daysUntilUnlock,
          lockedDescription: teaser.locked_description,
          unlockedDescription: teaser.unlocked_description,
          discoveryHint,
          discoveryHintLevel: hintLevel,
          dataPointsCollected: progress?.data_points_collected ?? 0,
          insightValue,
        };
      });

    return result;
  },
});

/**
 * Get discovery hints based on current patterns in user's data
 * These are dynamic hints that tease at patterns being detected
 */
export const getDiscoveryHints = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  returns: v.array(
    v.object({
      hintType: v.string(),
      hintText: v.string(),
      confidence: v.number(),
      relatedTeaserId: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const hints: {
      hintType: string;
      hintText: string;
      confidence: number;
      relatedTeaserId?: string;
    }[] = [];

    // Get user's sleep data to analyze patterns
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const dataPoints = sleepData.length;

    // Sleep timing pattern hint (needs 3+ days)
    if (dataPoints >= 3 && dataPoints < 7) {
      const wakeTimes = sleepData
        .filter((d) => d.wake_time)
        .map((d) => d.wake_time as number);
      if (wakeTimes.length >= 3) {
        hints.push({
          hintType: "wake_pattern",
          hintText: "We're noticing something about your wake times...",
          confidence: 0.6,
          relatedTeaserId: "wake_pattern_weekly",
        });
      }
    }

    // Sleep efficiency hint (needs 5+ days)
    if (dataPoints >= 5 && dataPoints < 7) {
      const efficiencies = sleepData
        .filter((d) => d.sleep_efficiency)
        .map((d) => d.sleep_efficiency as number);
      if (efficiencies.length >= 5) {
        const avgEfficiency =
          efficiencies.reduce((a, b) => a + b, 0) / efficiencies.length;
        if (avgEfficiency > 0) {
          hints.push({
            hintType: "efficiency_trend",
            hintText: "Your sleep efficiency trend is emerging...",
            confidence: 0.7,
            relatedTeaserId: "sleep_efficiency_trend",
          });
        }
      }
    }

    // Sleep quality correlation hint (needs 7+ days)
    if (dataPoints >= 7 && args.dayNumber < 10) {
      hints.push({
        hintType: "quality_correlation",
        hintText: "We're finding patterns in your sleep quality...",
        confidence: 0.8,
        relatedTeaserId: "quality_correlation",
      });
    }

    // Chronotype detection hint (needs 10+ days)
    if (dataPoints >= 10 && args.dayNumber < 14) {
      hints.push({
        hintType: "chronotype",
        hintText: "Your natural sleep rhythm is becoming clearer...",
        confidence: 0.85,
        relatedTeaserId: "chronotype_analysis",
      });
    }

    return hints;
  },
});

/**
 * Update a user's progress toward an insight
 * Called when user completes sleep logs or other data-collecting actions
 */
export const updateInsightProgress = mutation({
  args: {
    userId: v.id("users"),
    teaserId: v.string(),
    incrementDataPoints: v.optional(v.number()),
    newHintLevel: v.optional(v.number()),
  },
  returns: v.object({
    success: v.boolean(),
    newlyUnlocked: v.boolean(),
    dataPointsCollected: v.number(),
    hintLevel: v.number(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Get the teaser definition
    const teaser = await ctx.db
      .query("insight_teasers")
      .withIndex("by_teaser_id", (q) => q.eq("teaser_id", args.teaserId))
      .first();

    if (!teaser) {
      return {
        success: false,
        newlyUnlocked: false,
        dataPointsCollected: 0,
        hintLevel: 0,
      };
    }

    // Get existing progress
    const existingProgress = await ctx.db
      .query("user_insight_progress")
      .withIndex("by_user_teaser", (q) =>
        q.eq("user_id", args.userId).eq("teaser_id", args.teaserId)
      )
      .first();

    const increment = args.incrementDataPoints ?? 1;
    const currentDataPoints = existingProgress?.data_points_collected ?? 0;
    const newDataPoints = currentDataPoints + increment;

    const currentHintLevel = existingProgress?.discovery_hint_level ?? 0;
    const newHintLevel = args.newHintLevel ?? currentHintLevel;

    // Check if should unlock based on data points
    const requiredPoints = teaser.unlock_data_points ?? 0;
    const wasUnlocked = existingProgress?.unlocked ?? false;
    const shouldUnlock =
      !wasUnlocked && requiredPoints > 0 && newDataPoints >= requiredPoints;

    if (existingProgress) {
      await ctx.db.patch(existingProgress._id, {
        data_points_collected: newDataPoints,
        discovery_hint_level: newHintLevel,
        unlocked: wasUnlocked || shouldUnlock,
        unlocked_at: shouldUnlock ? now : existingProgress.unlocked_at,
        last_hint_shown_at:
          args.newHintLevel !== undefined
            ? now
            : existingProgress.last_hint_shown_at,
        updated_at: now,
      });
    } else {
      await ctx.db.insert("user_insight_progress", {
        user_id: args.userId,
        teaser_id: args.teaserId,
        unlocked: shouldUnlock,
        unlocked_at: shouldUnlock ? now : undefined,
        data_points_collected: newDataPoints,
        discovery_hint_level: newHintLevel,
        last_hint_shown_at: args.newHintLevel !== undefined ? now : undefined,
        created_at: now,
        updated_at: now,
      });
    }

    return {
      success: true,
      newlyUnlocked: shouldUnlock,
      dataPointsCollected: newDataPoints,
      hintLevel: newHintLevel,
    };
  },
});

/**
 * Unlock an insight and store its computed value
 * Called when an insight becomes available (day reached or data threshold met)
 */
export const unlockInsight = mutation({
  args: {
    userId: v.id("users"),
    teaserId: v.string(),
    insightValueJson: v.optional(v.string()),
  },
  returns: v.object({
    success: v.boolean(),
    wasAlreadyUnlocked: v.boolean(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check existing progress
    const existingProgress = await ctx.db
      .query("user_insight_progress")
      .withIndex("by_user_teaser", (q) =>
        q.eq("user_id", args.userId).eq("teaser_id", args.teaserId)
      )
      .first();

    if (existingProgress?.unlocked) {
      return {
        success: true,
        wasAlreadyUnlocked: true,
      };
    }

    if (existingProgress) {
      await ctx.db.patch(existingProgress._id, {
        unlocked: true,
        unlocked_at: now,
        insight_value_json: args.insightValueJson,
        updated_at: now,
      });
    } else {
      await ctx.db.insert("user_insight_progress", {
        user_id: args.userId,
        teaser_id: args.teaserId,
        unlocked: true,
        unlocked_at: now,
        data_points_collected: 0,
        discovery_hint_level: 0,
        insight_value_json: args.insightValueJson,
        created_at: now,
        updated_at: now,
      });
    }

    return {
      success: true,
      wasAlreadyUnlocked: false,
    };
  },
});

/**
 * Get the next insight teaser to show (for featured display)
 * Prioritizes countdown teasers close to unlock, then discovery hints
 */
export const getNextInsightTeaser = query({
  args: { userId: v.id("users") },
  returns: v.union(
    v.object({
      teaserId: v.string(),
      title: v.string(),
      teaserType: v.string(),
      displayText: v.string(),
      icon: v.string(),
      daysUntilUnlock: v.union(v.number(), v.null()),
      isDiscovery: v.boolean(),
    }),
    v.null()
  ),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return null;

    const currentDay = user.current_day ?? 1;

    // Get all active teasers
    const teasers = await ctx.db
      .query("insight_teasers")
      .filter((q) => q.eq(q.field("is_active"), true))
      .collect();

    // Get user's progress
    const userProgress = await ctx.db
      .query("user_insight_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const progressMap = new Map(userProgress.map((p) => [p.teaser_id, p]));

    // Find the best teaser to show
    // Priority 1: Countdown teasers within 3 days of unlock
    const countdownTeasers = teasers
      .filter((t) => {
        const progress = progressMap.get(t.teaser_id);
        const isUnlocked = progress?.unlocked ?? false;
        const daysUntil = t.unlock_day - currentDay;
        return (
          !isUnlocked &&
          t.teaser_type === "countdown" &&
          daysUntil > 0 &&
          daysUntil <= 3
        );
      })
      .sort((a, b) => a.unlock_day - b.unlock_day);

    if (countdownTeasers.length > 0) {
      const teaser = countdownTeasers[0];
      const daysUntil = teaser.unlock_day - currentDay;
      return {
        teaserId: teaser.teaser_id,
        title: teaser.title,
        teaserType: "countdown",
        displayText:
          daysUntil === 1
            ? `${teaser.title} unlocks tomorrow!`
            : `${teaser.title} unlocks in ${daysUntil} days`,
        icon: teaser.icon,
        daysUntilUnlock: daysUntil,
        isDiscovery: false,
      };
    }

    // Priority 2: Discovery teasers with hints available
    const discoveryTeasers = teasers
      .filter((t) => {
        const progress = progressMap.get(t.teaser_id);
        const isUnlocked = progress?.unlocked ?? false;
        const hintLevel = progress?.discovery_hint_level ?? 0;
        return (
          !isUnlocked && t.teaser_type === "discovery" && hintLevel > 0
        );
      })
      .sort((a, b) => {
        const aHint = progressMap.get(a.teaser_id)?.discovery_hint_level ?? 0;
        const bHint = progressMap.get(b.teaser_id)?.discovery_hint_level ?? 0;
        return bHint - aHint; // Higher hint level first
      });

    if (discoveryTeasers.length > 0) {
      const teaser = discoveryTeasers[0];
      const progress = progressMap.get(teaser.teaser_id);
      const hintLevel = progress?.discovery_hint_level ?? 0;

      let displayText = teaser.locked_description;
      if (teaser.discovery_hints_json) {
        try {
          const hints = JSON.parse(teaser.discovery_hints_json) as string[];
          displayText = hints[Math.min(hintLevel - 1, hints.length - 1)];
        } catch {
          // Use default
        }
      }

      return {
        teaserId: teaser.teaser_id,
        title: teaser.title,
        teaserType: "discovery",
        displayText,
        icon: teaser.icon,
        daysUntilUnlock: null,
        isDiscovery: true,
      };
    }

    // Priority 3: Any locked countdown teaser (soonest first)
    const anyCountdown = teasers
      .filter((t) => {
        const progress = progressMap.get(t.teaser_id);
        const isUnlocked = progress?.unlocked ?? false;
        return !isUnlocked && t.teaser_type === "countdown";
      })
      .sort((a, b) => a.unlock_day - b.unlock_day);

    if (anyCountdown.length > 0) {
      const teaser = anyCountdown[0];
      const daysUntil = teaser.unlock_day - currentDay;
      return {
        teaserId: teaser.teaser_id,
        title: teaser.title,
        teaserType: "countdown",
        displayText: teaser.locked_description,
        icon: teaser.icon,
        daysUntilUnlock: Math.max(0, daysUntil),
        isDiscovery: false,
      };
    }

    return null;
  },
});

/**
 * Initialize insight progress for all teasers when user starts
 */
export const initializeInsightProgress = mutation({
  args: { userId: v.id("users") },
  returns: v.object({
    initialized: v.number(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Get all active teasers
    const teasers = await ctx.db
      .query("insight_teasers")
      .filter((q) => q.eq(q.field("is_active"), true))
      .collect();

    // Get existing progress
    const existingProgress = await ctx.db
      .query("user_insight_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const existingTeaserIds = new Set(existingProgress.map((p) => p.teaser_id));

    // Initialize progress for teasers that don't have it yet
    let initialized = 0;
    for (const teaser of teasers) {
      if (!existingTeaserIds.has(teaser.teaser_id)) {
        await ctx.db.insert("user_insight_progress", {
          user_id: args.userId,
          teaser_id: teaser.teaser_id,
          unlocked: false,
          data_points_collected: 0,
          discovery_hint_level: 0,
          created_at: now,
          updated_at: now,
        });
        initialized++;
      }
    }

    return { initialized };
  },
});
