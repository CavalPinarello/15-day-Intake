import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// Check-In System Mutations
// Morning, Midday, and Evening check-ins
// ============================================

/**
 * Submit morning check-in
 * Records sleep quality, energy level, and mood upon waking
 */
export const submitMorningCheckIn = mutation({
  args: {
    userId: v.id("users"),
    sleepQuality: v.number(),       // 1-5
    energyLevel: v.number(),        // 1-4
    mood: v.optional(v.number()),   // 1-5
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
