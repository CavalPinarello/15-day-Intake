import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

// ============================================
// Check-In System Mutations
// Morning, Midday, and Evening check-ins
// ============================================

/**
 * Submit morning check-in
 * Records sleep quality, energy level, mood, and focus upon waking
 */
export const submitMorningCheckIn = mutation({
  args: {
    userId: v.id("users"),
    sleepQuality: v.number(),       // 1-5
    energyLevel: v.number(),        // 1-6 (Watch: animal icons)
    mood: v.optional(v.number()),   // 1-6 (Watch: weather icons)
    focusLevel: v.optional(v.number()), // 1-5 (Watch: clarity icons)
    deviceType: v.optional(v.string()), // "ios", "watch"
  },
  returns: v.id("daily_checkins"),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    // Check if morning check-in already exists for today
    const existing = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date_type", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", today).eq("checkin_type", "morning")
      )
      .first();

    if (existing) {
      // Update existing check-in
      await ctx.db.patch(existing._id, {
        sleep_quality: args.sleepQuality,
        energy_level: args.energyLevel,
        mood: args.mood,
        focus_level: args.focusLevel,
        completed: true,
        completed_at: now,
        device_type: args.deviceType,
        updated_at: now,
      });
      return existing._id;
    }

    // Create new check-in
    return await ctx.db.insert("daily_checkins", {
      user_id: args.userId,
      checkin_date: today,
      checkin_type: "morning",
      completed: true,
      completed_at: now,
      sleep_quality: args.sleepQuality,
      energy_level: args.energyLevel,
      mood: args.mood,
      focus_level: args.focusLevel,
      device_type: args.deviceType,
      created_at: now,
      updated_at: now,
    });
  },
});

/**
 * Submit midday check-in
 * Records energy level, caffeine intake, and nap status
 */
export const submitMiddayCheckIn = mutation({
  args: {
    userId: v.id("users"),
    energyLevel: v.number(),              // 1-4
    caffeineCups: v.number(),             // 0-10
    caffeineLastTime: v.optional(v.string()), // HH:MM format
    napTaken: v.boolean(),
    napDurationMins: v.optional(v.number()),
    deviceType: v.optional(v.string()),
  },
  returns: v.id("daily_checkins"),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    // Check if midday check-in already exists for today
    const existing = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date_type", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", today).eq("checkin_type", "midday")
      )
      .first();

    if (existing) {
      // Update existing check-in
      await ctx.db.patch(existing._id, {
        midday_energy: args.energyLevel,
        caffeine_cups: args.caffeineCups,
        caffeine_last_time: args.caffeineLastTime,
        nap_taken: args.napTaken,
        nap_duration_mins: args.napDurationMins,
        completed: true,
        completed_at: now,
        device_type: args.deviceType,
        updated_at: now,
      });
      return existing._id;
    }

    // Create new check-in
    return await ctx.db.insert("daily_checkins", {
      user_id: args.userId,
      checkin_date: today,
      checkin_type: "midday",
      completed: true,
      completed_at: now,
      midday_energy: args.energyLevel,
      caffeine_cups: args.caffeineCups,
      caffeine_last_time: args.caffeineLastTime,
      nap_taken: args.napTaken,
      nap_duration_mins: args.napDurationMins,
      device_type: args.deviceType,
      created_at: now,
      updated_at: now,
    });
  },
});

/**
 * Submit evening check-in
 * Records day rating, reflection, and missed task reasons
 */
export const submitEveningCheckIn = mutation({
  args: {
    userId: v.id("users"),
    overallDayRating: v.number(),              // 1-5
    reflectionText: v.optional(v.string()),
    missedTasksReasons: v.optional(v.array(v.string())),
    deviceType: v.optional(v.string()),
  },
  returns: v.id("daily_checkins"),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    // Check if evening check-in already exists for today
    const existing = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date_type", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", today).eq("checkin_type", "evening")
      )
      .first();

    if (existing) {
      // Update existing check-in
      await ctx.db.patch(existing._id, {
        overall_day_rating: args.overallDayRating,
        reflection_text: args.reflectionText,
        tasks_missed_reasons: args.missedTasksReasons
          ? JSON.stringify(args.missedTasksReasons)
          : undefined,
        completed: true,
        completed_at: now,
        device_type: args.deviceType,
        updated_at: now,
      });
      return existing._id;
    }

    // Create new check-in
    return await ctx.db.insert("daily_checkins", {
      user_id: args.userId,
      checkin_date: today,
      checkin_type: "evening",
      completed: true,
      completed_at: now,
      overall_day_rating: args.overallDayRating,
      reflection_text: args.reflectionText,
      tasks_missed_reasons: args.missedTasksReasons
        ? JSON.stringify(args.missedTasksReasons)
        : undefined,
      device_type: args.deviceType,
      created_at: now,
      updated_at: now,
    });
  },
});

// ============================================
// Check-In Queries
// ============================================

/**
 * Get today's check-in status for all three types
 */
export const getTodayCheckInStatus = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.object({
    morning: v.object({
      completed: v.boolean(),
      completedAt: v.optional(v.number()),
      sleepQuality: v.optional(v.number()),
      energyLevel: v.optional(v.number()),
      mood: v.optional(v.number()),
      focusLevel: v.optional(v.number()),
    }),
    midday: v.object({
      completed: v.boolean(),
      completedAt: v.optional(v.number()),
      energyLevel: v.optional(v.number()),
      caffeineCups: v.optional(v.number()),
      caffeineLastTime: v.optional(v.string()),
      napTaken: v.optional(v.boolean()),
      napDurationMins: v.optional(v.number()),
    }),
    evening: v.object({
      completed: v.boolean(),
      completedAt: v.optional(v.number()),
      overallDayRating: v.optional(v.number()),
      reflectionText: v.optional(v.string()),
    }),
  }),
  handler: async (ctx, args) => {
    const today = new Date().toISOString().split("T")[0];

    // Get all check-ins for today
    const checkins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", today)
      )
      .collect();

    const morning = checkins.find((c) => c.checkin_type === "morning");
    const midday = checkins.find((c) => c.checkin_type === "midday");
    const evening = checkins.find((c) => c.checkin_type === "evening");

    return {
      morning: {
        completed: morning?.completed ?? false,
        completedAt: morning?.completed_at,
        sleepQuality: morning?.sleep_quality,
        energyLevel: morning?.energy_level,
        mood: morning?.mood,
        focusLevel: morning?.focus_level,
      },
      midday: {
        completed: midday?.completed ?? false,
        completedAt: midday?.completed_at,
        energyLevel: midday?.midday_energy,
        caffeineCups: midday?.caffeine_cups,
        caffeineLastTime: midday?.caffeine_last_time,
        napTaken: midday?.nap_taken,
        napDurationMins: midday?.nap_duration_mins,
      },
      evening: {
        completed: evening?.completed ?? false,
        completedAt: evening?.completed_at,
        overallDayRating: evening?.overall_day_rating,
        reflectionText: evening?.reflection_text,
      },
    };
  },
});

/**
 * Get check-in history for the last N days
 * Used by physician dashboard and iOS trends
 */
export const getCheckInHistory = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 14
  },
  returns: v.array(
    v.object({
      date: v.string(),
      morningCompleted: v.boolean(),
      middayCompleted: v.boolean(),
      eveningCompleted: v.boolean(),
      // Morning data
      sleepQuality: v.optional(v.number()),
      morningEnergy: v.optional(v.number()),
      mood: v.optional(v.number()),
      focusLevel: v.optional(v.number()),
      // Midday data
      middayEnergy: v.optional(v.number()),
      caffeineCups: v.optional(v.number()),
      napTaken: v.optional(v.boolean()),
      napDurationMins: v.optional(v.number()),
      // Evening data
      overallDayRating: v.optional(v.number()),
    })
  ),
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 14;
    const results: {
      date: string;
      morningCompleted: boolean;
      middayCompleted: boolean;
      eveningCompleted: boolean;
      sleepQuality?: number;
      morningEnergy?: number;
      mood?: number;
      focusLevel?: number;
      middayEnergy?: number;
      caffeineCups?: number;
      napTaken?: boolean;
      napDurationMins?: number;
      overallDayRating?: number;
    }[] = [];

    // Generate dates for the last N days
    const dates: string[] = [];
    for (let i = 0; i < daysToFetch; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split("T")[0]);
    }

    // Get all check-ins for this user
    const allCheckins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Filter to only relevant dates and group by date
    const checkinsByDate = new Map<string, typeof allCheckins>();
    for (const checkin of allCheckins) {
      if (dates.includes(checkin.checkin_date)) {
        const existing = checkinsByDate.get(checkin.checkin_date) ?? [];
        existing.push(checkin);
        checkinsByDate.set(checkin.checkin_date, existing);
      }
    }

    // Build results
    for (const date of dates) {
      const dayCheckins = checkinsByDate.get(date) ?? [];
      const morning = dayCheckins.find((c) => c.checkin_type === "morning");
      const midday = dayCheckins.find((c) => c.checkin_type === "midday");
      const evening = dayCheckins.find((c) => c.checkin_type === "evening");

      results.push({
        date,
        morningCompleted: morning?.completed ?? false,
        middayCompleted: midday?.completed ?? false,
        eveningCompleted: evening?.completed ?? false,
        sleepQuality: morning?.sleep_quality,
        morningEnergy: morning?.energy_level,
        mood: morning?.mood,
        focusLevel: morning?.focus_level,
        middayEnergy: midday?.midday_energy,
        caffeineCups: midday?.caffeine_cups,
        napTaken: midday?.nap_taken,
        napDurationMins: midday?.nap_duration_mins,
        overallDayRating: evening?.overall_day_rating,
      });
    }

    return results;
  },
});

/**
 * Get energy trends over time
 * Combines morning and midday energy readings
 */
export const getEnergyTrends = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 7
  },
  returns: v.array(
    v.object({
      date: v.string(),
      morningEnergy: v.optional(v.number()),
      middayEnergy: v.optional(v.number()),
      averageEnergy: v.optional(v.number()),
    })
  ),
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 7;
    const results: {
      date: string;
      morningEnergy?: number;
      middayEnergy?: number;
      averageEnergy?: number;
    }[] = [];

    // Generate dates
    const dates: string[] = [];
    for (let i = 0; i < daysToFetch; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split("T")[0]);
    }

    // Get all check-ins
    const allCheckins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const date of dates) {
      const dayCheckins = allCheckins.filter((c) => c.checkin_date === date);
      const morning = dayCheckins.find((c) => c.checkin_type === "morning");
      const midday = dayCheckins.find((c) => c.checkin_type === "midday");

      const morningEnergy = morning?.energy_level;
      const middayEnergy = midday?.midday_energy;

      let averageEnergy: number | undefined;
      if (morningEnergy !== undefined && middayEnergy !== undefined) {
        averageEnergy = (morningEnergy + middayEnergy) / 2;
      } else if (morningEnergy !== undefined) {
        averageEnergy = morningEnergy;
      } else if (middayEnergy !== undefined) {
        averageEnergy = middayEnergy;
      }

      results.push({
        date,
        morningEnergy,
        middayEnergy,
        averageEnergy,
      });
    }

    return results;
  },
});

/**
 * Get caffeine patterns over time
 * For physician dashboard analysis
 */
export const getCaffeinePatterns = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 14
  },
  returns: v.object({
    averageDailyCups: v.number(),
    maxCupsInDay: v.number(),
    latestCaffeineTime: v.optional(v.string()),
    dailyData: v.array(
      v.object({
        date: v.string(),
        cups: v.optional(v.number()),
        lastTime: v.optional(v.string()),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 14;

    // Generate dates
    const dates: string[] = [];
    for (let i = 0; i < daysToFetch; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split("T")[0]);
    }

    // Get midday check-ins
    const allCheckins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_type", (q) =>
        q.eq("user_id", args.userId).eq("checkin_type", "midday")
      )
      .collect();

    const relevantCheckins = allCheckins.filter((c) =>
      dates.includes(c.checkin_date)
    );

    // Calculate stats
    let totalCups = 0;
    let daysWithData = 0;
    let maxCups = 0;
    let latestTime: string | undefined;

    const dailyData = dates.map((date) => {
      const checkin = relevantCheckins.find((c) => c.checkin_date === date);
      const cups = checkin?.caffeine_cups;
      const lastTime = checkin?.caffeine_last_time;

      if (cups !== undefined) {
        totalCups += cups;
        daysWithData++;
        if (cups > maxCups) maxCups = cups;
        if (lastTime && (!latestTime || lastTime > latestTime)) {
          latestTime = lastTime;
        }
      }

      return { date, cups, lastTime };
    });

    return {
      averageDailyCups: daysWithData > 0 ? totalCups / daysWithData : 0,
      maxCupsInDay: maxCups,
      latestCaffeineTime: latestTime,
      dailyData,
    };
  },
});

/**
 * Get nap patterns over time
 * For physician dashboard analysis
 */
export const getNapPatterns = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 14
  },
  returns: v.object({
    napFrequency: v.number(), // Percentage of days with naps
    averageNapDuration: v.number(), // Average duration in minutes
    totalNaps: v.number(),
    dailyData: v.array(
      v.object({
        date: v.string(),
        napTaken: v.optional(v.boolean()),
        duration: v.optional(v.number()),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 14;

    // Generate dates
    const dates: string[] = [];
    for (let i = 0; i < daysToFetch; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split("T")[0]);
    }

    // Get midday check-ins
    const allCheckins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_type", (q) =>
        q.eq("user_id", args.userId).eq("checkin_type", "midday")
      )
      .collect();

    const relevantCheckins = allCheckins.filter((c) =>
      dates.includes(c.checkin_date)
    );

    // Calculate stats
    let totalNaps = 0;
    let totalNapDuration = 0;
    let daysWithNapData = 0;

    const dailyData = dates.map((date) => {
      const checkin = relevantCheckins.find((c) => c.checkin_date === date);
      const napTaken = checkin?.nap_taken;
      const duration = checkin?.nap_duration_mins;

      if (napTaken !== undefined) {
        daysWithNapData++;
        if (napTaken) {
          totalNaps++;
          if (duration) totalNapDuration += duration;
        }
      }

      return { date, napTaken, duration };
    });

    return {
      napFrequency:
        daysWithNapData > 0 ? (totalNaps / daysWithNapData) * 100 : 0,
      averageNapDuration: totalNaps > 0 ? totalNapDuration / totalNaps : 0,
      totalNaps,
      dailyData,
    };
  },
});

/**
 * Get check-in completion rate
 * For compliance tracking
 */
export const getCheckInComplianceRate = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 7
  },
  returns: v.object({
    overallRate: v.number(),         // 0-100
    morningRate: v.number(),
    middayRate: v.number(),
    eveningRate: v.number(),
    streakDays: v.number(),          // Consecutive days with all check-ins
  }),
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 7;

    // Generate dates
    const dates: string[] = [];
    for (let i = 0; i < daysToFetch; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split("T")[0]);
    }

    // Get all check-ins
    const allCheckins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    let morningCount = 0;
    let middayCount = 0;
    let eveningCount = 0;
    let streakDays = 0;
    let streakBroken = false;

    for (const date of dates) {
      const dayCheckins = allCheckins.filter((c) => c.checkin_date === date);
      const hasMorning = dayCheckins.some(
        (c) => c.checkin_type === "morning" && c.completed
      );
      const hasMidday = dayCheckins.some(
        (c) => c.checkin_type === "midday" && c.completed
      );
      const hasEvening = dayCheckins.some(
        (c) => c.checkin_type === "evening" && c.completed
      );

      if (hasMorning) morningCount++;
      if (hasMidday) middayCount++;
      if (hasEvening) eveningCount++;

      // Count streak (must have all three)
      if (!streakBroken && hasMorning && hasMidday && hasEvening) {
        streakDays++;
      } else {
        streakBroken = true;
      }
    }

    const totalPossible = daysToFetch * 3;
    const totalCompleted = morningCount + middayCount + eveningCount;

    return {
      overallRate: (totalCompleted / totalPossible) * 100,
      morningRate: (morningCount / daysToFetch) * 100,
      middayRate: (middayCount / daysToFetch) * 100,
      eveningRate: (eveningCount / daysToFetch) * 100,
      streakDays,
    };
  },
});

// ============================================
// Watch-specific mutations (simplified)
// ============================================

/**
 * Quick morning check-in from Watch
 * Simplified version with just energy level
 */
export const watchQuickMorningCheckIn = mutation({
  args: {
    userId: v.id("users"),
    energyLevel: v.number(), // 1-4
  },
  returns: v.id("daily_checkins"),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    const existing = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date_type", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", today).eq("checkin_type", "morning")
      )
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        energy_level: args.energyLevel,
        completed: true,
        completed_at: now,
        device_type: "watch",
        updated_at: now,
      });
      return existing._id;
    }

    return await ctx.db.insert("daily_checkins", {
      user_id: args.userId,
      checkin_date: today,
      checkin_type: "morning",
      completed: true,
      completed_at: now,
      energy_level: args.energyLevel,
      device_type: "watch",
      created_at: now,
      updated_at: now,
    });
  },
});

/**
 * Quick midday check-in from Watch
 * Just energy and caffeine count
 */
export const watchQuickMiddayCheckIn = mutation({
  args: {
    userId: v.id("users"),
    energyLevel: v.number(),    // 1-4
    caffeineCups: v.number(),   // 0-10
  },
  returns: v.id("daily_checkins"),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    const existing = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date_type", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", today).eq("checkin_type", "midday")
      )
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        midday_energy: args.energyLevel,
        caffeine_cups: args.caffeineCups,
        completed: true,
        completed_at: now,
        device_type: "watch",
        updated_at: now,
      });
      return existing._id;
    }

    return await ctx.db.insert("daily_checkins", {
      user_id: args.userId,
      checkin_date: today,
      checkin_type: "midday",
      completed: true,
      completed_at: now,
      midday_energy: args.energyLevel,
      caffeine_cups: args.caffeineCups,
      device_type: "watch",
      created_at: now,
      updated_at: now,
    });
  },
});

/**
 * Unified Watch Check-In (NEW - for minimal watch app)
 *
 * Submits a check-in with Energy (animal icons), Mood (weather), and Focus (clarity).
 * This is the primary check-in method for the redesigned minimal Watch app.
 *
 * Energy levels (1-6): sleepingSeal, turtle, cat, dog, ostrich, rabbit
 * Mood levels (1-6): stormy, rainy, cloudy, partlySunny, sunny, rainbow
 * Focus levels (1-5): foggy, hazy, clearing, clear, crystal
 */
export const watchSubmitCheckIn = mutation({
  args: {
    userId: v.id("users"),
    checkInType: v.union(v.literal("morning"), v.literal("midday"), v.literal("evening")),
    energyLevel: v.number(),      // 1-6 (animal icons)
    moodLevel: v.number(),        // 1-6 (weather icons)
    focusLevel: v.number(),       // 1-5 (clarity icons)
  },
  returns: v.object({
    success: v.boolean(),
    checkInId: v.id("daily_checkins"),
    checkInsCompletedToday: v.number(),
    isFirstCheckInToday: v.boolean(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    // Check if this type of check-in already exists for today
    const existing = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date_type", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", today).eq("checkin_type", args.checkInType)
      )
      .first();

    let checkInId: Id<"daily_checkins">;
    const isFirstCheckInToday = !existing;

    if (existing) {
      // Update existing check-in
      const updateData: Record<string, unknown> = {
        energy_level: args.energyLevel,
        mood: args.moodLevel,
        focus_level: args.focusLevel,
        completed: true,
        completed_at: now,
        device_type: "watch",
        updated_at: now,
      };

      // For midday, also set midday_energy
      if (args.checkInType === "midday") {
        updateData.midday_energy = args.energyLevel;
      }

      // For evening, also set overall_day_rating (derive from mood)
      if (args.checkInType === "evening") {
        // Map 6-point mood scale to 5-point day rating
        updateData.overall_day_rating = Math.min(5, Math.ceil(args.moodLevel * 5 / 6));
      }

      await ctx.db.patch(existing._id, updateData);
      checkInId = existing._id;
    } else {
      // Create new check-in
      const insertData: Record<string, unknown> = {
        user_id: args.userId,
        checkin_date: today,
        checkin_type: args.checkInType,
        completed: true,
        completed_at: now,
        energy_level: args.energyLevel,
        mood: args.moodLevel,
        focus_level: args.focusLevel,
        device_type: "watch",
        created_at: now,
        updated_at: now,
      };

      // For midday, also set midday_energy
      if (args.checkInType === "midday") {
        insertData.midday_energy = args.energyLevel;
      }

      // For evening, also set overall_day_rating
      if (args.checkInType === "evening") {
        insertData.overall_day_rating = Math.min(5, Math.ceil(args.moodLevel * 5 / 6));
      }

      checkInId = await ctx.db.insert("daily_checkins", insertData as any);
    }

    // Count completed check-ins for today
    const todayCheckIns = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", today)
      )
      .collect();

    const checkInsCompletedToday = todayCheckIns.filter(c => c.completed).length;

    return {
      success: true,
      checkInId,
      checkInsCompletedToday,
      isFirstCheckInToday,
    };
  },
});

/**
 * Debug: Get all check-ins for a user (last 7 days)
 */
export const debugGetRecentCheckIns = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const allCheckins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(20);

    const utcToday = new Date().toISOString().split("T")[0];
    const utcNow = new Date().toISOString();

    return {
      utcToday,
      utcNow,
      checkinsCount: allCheckins.length,
      checkins: allCheckins.map(c => ({
        date: c.checkin_date,
        type: c.checkin_type,
        completed: c.completed,
        energy: c.energy_level,
        mood: c.mood,
        focus: c.focus_level,
        createdAt: c.created_at ? new Date(c.created_at).toISOString() : null,
      })),
    };
  },
});

/**
 * Get watch check-in status for today
 * Returns which check-ins are done and what the recommended next check-in is
 */
export const getWatchCheckInStatus = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.object({
    morningDone: v.boolean(),
    middayDone: v.boolean(),
    eveningDone: v.boolean(),
    totalDone: v.number(),
    recommendedNext: v.union(v.literal("morning"), v.literal("midday"), v.literal("evening"), v.null()),
    // Last check-in data for display
    lastEnergyLevel: v.optional(v.number()),
    lastMoodLevel: v.optional(v.number()),
    lastFocusLevel: v.optional(v.number()),
  }),
  handler: async (ctx, args) => {
    const today = new Date().toISOString().split("T")[0];
    const currentHour = new Date().getHours();

    // Get all check-ins for today
    const todayCheckIns = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", today)
      )
      .collect();

    const morning = todayCheckIns.find(c => c.checkin_type === "morning" && c.completed);
    const midday = todayCheckIns.find(c => c.checkin_type === "midday" && c.completed);
    const evening = todayCheckIns.find(c => c.checkin_type === "evening" && c.completed);

    const morningDone = !!morning;
    const middayDone = !!midday;
    const eveningDone = !!evening;
    const totalDone = (morningDone ? 1 : 0) + (middayDone ? 1 : 0) + (eveningDone ? 1 : 0);

    // Determine recommended next check-in based on time
    let recommendedNext: "morning" | "midday" | "evening" | null = null;
    if (currentHour >= 5 && currentHour < 12 && !morningDone) {
      recommendedNext = "morning";
    } else if (currentHour >= 12 && currentHour < 18 && !middayDone) {
      recommendedNext = "midday";
    } else if (currentHour >= 18 && currentHour < 24 && !eveningDone) {
      recommendedNext = "evening";
    } else if (!morningDone) {
      recommendedNext = "morning";
    } else if (!middayDone) {
      recommendedNext = "midday";
    } else if (!eveningDone) {
      recommendedNext = "evening";
    }

    // Get the most recent check-in data for display
    const allCompleted = [...todayCheckIns.filter(c => c.completed)];
    allCompleted.sort((a, b) => (b.completed_at ?? 0) - (a.completed_at ?? 0));
    const lastCheckIn = allCompleted[0];

    return {
      morningDone,
      middayDone,
      eveningDone,
      totalDone,
      recommendedNext,
      lastEnergyLevel: lastCheckIn?.energy_level,
      lastMoodLevel: lastCheckIn?.mood,
      lastFocusLevel: lastCheckIn?.focus_level,
    };
  },
});

/**
 * Get watch check-in trends for charts
 * Returns energy/mood/focus per day for the last N days
 * Used by Watch app trends view
 */
export const getWatchCheckInTrends = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 7
  },
  returns: v.object({
    // Today's check-ins by time slot
    today: v.object({
      morning: v.union(v.object({
        energy: v.number(),
        mood: v.number(),
        focus: v.number(),
        completedAt: v.number(),
      }), v.null()),
      midday: v.union(v.object({
        energy: v.number(),
        mood: v.number(),
        focus: v.number(),
        completedAt: v.number(),
      }), v.null()),
      evening: v.union(v.object({
        energy: v.number(),
        mood: v.number(),
        focus: v.number(),
        completedAt: v.number(),
      }), v.null()),
    }),
    // Weekly data (array of days, oldest first)
    week: v.array(v.object({
      date: v.string(),
      dayOfWeek: v.string(), // "Mon", "Tue", etc.
      hasData: v.boolean(),
      avgEnergy: v.optional(v.number()),
      avgMood: v.optional(v.number()),
      avgFocus: v.optional(v.number()),
      checkInsCount: v.number(),
    })),
  }),
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 7;
    const today = new Date().toISOString().split("T")[0];
    const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

    // Get all check-ins for this user in the date range
    const allCheckins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Filter completed check-ins with energy/mood/focus data
    const relevantCheckins = allCheckins.filter(c =>
      c.completed &&
      c.energy_level !== undefined &&
      c.mood !== undefined
    );

    // Build today's data
    const todayCheckins = relevantCheckins.filter(c => c.checkin_date === today);
    const todayMorning = todayCheckins.find(c => c.checkin_type === "morning");
    const todayMidday = todayCheckins.find(c => c.checkin_type === "midday");
    const todayEvening = todayCheckins.find(c => c.checkin_type === "evening");

    const todayData = {
      morning: todayMorning ? {
        energy: todayMorning.energy_level!,
        mood: todayMorning.mood!,
        focus: todayMorning.focus_level ?? 3,
        completedAt: todayMorning.completed_at ?? todayMorning.created_at,
      } : null,
      midday: todayMidday ? {
        energy: todayMidday.energy_level!,
        mood: todayMidday.mood!,
        focus: todayMidday.focus_level ?? 3,
        completedAt: todayMidday.completed_at ?? todayMidday.created_at,
      } : null,
      evening: todayEvening ? {
        energy: todayEvening.energy_level!,
        mood: todayEvening.mood!,
        focus: todayEvening.focus_level ?? 3,
        completedAt: todayEvening.completed_at ?? todayEvening.created_at,
      } : null,
    };

    // Build weekly data
    const weekData: {
      date: string;
      dayOfWeek: string;
      hasData: boolean;
      avgEnergy?: number;
      avgMood?: number;
      avgFocus?: number;
      checkInsCount: number;
    }[] = [];

    for (let i = daysToFetch - 1; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      const dateStr = date.toISOString().split("T")[0];
      const dayOfWeek = dayNames[date.getDay()];

      const dayCheckins = relevantCheckins.filter(c => c.checkin_date === dateStr);

      if (dayCheckins.length > 0) {
        const energySum = dayCheckins.reduce((sum, c) => sum + (c.energy_level ?? 0), 0);
        const moodSum = dayCheckins.reduce((sum, c) => sum + (c.mood ?? 0), 0);
        const focusSum = dayCheckins.reduce((sum, c) => sum + (c.focus_level ?? 3), 0);

        weekData.push({
          date: dateStr,
          dayOfWeek,
          hasData: true,
          avgEnergy: Math.round((energySum / dayCheckins.length) * 10) / 10,
          avgMood: Math.round((moodSum / dayCheckins.length) * 10) / 10,
          avgFocus: Math.round((focusSum / dayCheckins.length) * 10) / 10,
          checkInsCount: dayCheckins.length,
        });
      } else {
        weekData.push({
          date: dateStr,
          dayOfWeek,
          hasData: false,
          checkInsCount: 0,
        });
      }
    }

    return {
      today: todayData,
      week: weekData,
    };
  },
});
