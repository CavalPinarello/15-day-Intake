/**
 * Watch Garden State - Convex Functions
 *
 * Manages the weekly garden visualization for Apple Watch.
 * Each day's check-in compliance causes a flower to bloom through 6 stages.
 *
 * Bloom States:
 * 0 = empty (future day)
 * 1 = seed (day started, no check-ins)
 * 2 = sprout (1 check-in done)
 * 3 = budding (2 check-ins done)
 * 4 = blooming (all check-ins done)
 * 5 = fullBloom (all check-ins + all tasks done)
 */

import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Types for garden state
interface DayFlower {
  date: string;          // YYYY-MM-DD
  dayOfWeek: string;     // "Mon", "Tue", etc.
  bloomState: number;    // 0-5
  checkInsCompleted: number;
  tasksCompleted: number;
  totalTasks: number;
  isToday: boolean;
}

interface WeeklyGarden {
  weekStartDate: string;
  days: DayFlower[];
  currentStreak: number;
  longestStreak: number;
}

/**
 * Get the Monday of the current week
 */
function getWeekMonday(date: Date = new Date()): string {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Adjust for Sunday
  d.setDate(diff);
  return d.toISOString().split("T")[0];
}

/**
 * Get today's date in YYYY-MM-DD format
 */
function getTodayDate(): string {
  return new Date().toISOString().split("T")[0];
}

/**
 * Calculate bloom state based on check-ins and tasks
 */
function calculateBloomState(
  checkInsCompleted: number,
  tasksCompleted: number,
  totalTasks: number,
  isFutureDay: boolean
): number {
  if (isFutureDay) return 0; // empty
  if (checkInsCompleted === 0) return 1; // seed
  if (checkInsCompleted === 1) return 2; // sprout
  if (checkInsCompleted === 2) return 3; // budding
  if (checkInsCompleted >= 3) {
    // All 3 check-ins done
    if (totalTasks === 0 || tasksCompleted >= totalTasks) {
      return 5; // fullBloom (all tasks done or no tasks)
    }
    return 4; // blooming (check-ins done, some tasks pending)
  }
  return 1; // default to seed
}

/**
 * Get current week's garden state for a user
 */
export const getWeeklyGarden = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args): Promise<WeeklyGarden> => {
    const weekStartDate = getWeekMonday();
    const todayDate = getTodayDate();

    // Check for existing garden state
    const existing = await ctx.db
      .query("watch_garden_state")
      .withIndex("by_user_week", (q) =>
        q.eq("user_id", args.userId).eq("week_start_date", weekStartDate)
      )
      .first();

    if (existing) {
      // Parse and return existing state, updating isToday flags
      const days: DayFlower[] = JSON.parse(existing.days_json);
      const updatedDays = days.map(day => ({
        ...day,
        isToday: day.date === todayDate
      }));

      return {
        weekStartDate,
        days: updatedDays,
        currentStreak: existing.current_streak,
        longestStreak: existing.longest_streak,
      };
    }

    // Create new week with empty flowers
    const dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const monday = new Date(weekStartDate);
    const days: DayFlower[] = [];

    for (let i = 0; i < 7; i++) {
      const date = new Date(monday);
      date.setDate(monday.getDate() + i);
      const dateStr = date.toISOString().split("T")[0];
      const isFuture = dateStr > todayDate;

      days.push({
        date: dateStr,
        dayOfWeek: dayNames[i],
        bloomState: isFuture ? 0 : 1, // empty if future, seed if past/today
        checkInsCompleted: 0,
        tasksCompleted: 0,
        totalTasks: 0,
        isToday: dateStr === todayDate,
      });
    }

    // Get streak from user_streaks table
    const userStreak = await ctx.db
      .query("user_streaks")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    return {
      weekStartDate,
      days,
      currentStreak: userStreak?.current_streak ?? 0,
      longestStreak: userStreak?.longest_streak ?? 0,
    };
  },
});

/**
 * Update garden after check-in or task completion
 */
export const updateGardenBloom = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),           // YYYY-MM-DD
    checkInsCompleted: v.number(),
    tasksCompleted: v.number(),
    totalTasks: v.number(),
  },
  handler: async (ctx, args) => {
    const weekStartDate = getWeekMonday(new Date(args.date));
    const todayDate = getTodayDate();

    // Calculate new bloom state
    const isFuture = args.date > todayDate;
    const newBloomState = calculateBloomState(
      args.checkInsCompleted,
      args.tasksCompleted,
      args.totalTasks,
      isFuture
    );

    // Get existing garden state
    const existing = await ctx.db
      .query("watch_garden_state")
      .withIndex("by_user_week", (q) =>
        q.eq("user_id", args.userId).eq("week_start_date", weekStartDate)
      )
      .first();

    let days: DayFlower[];
    let currentStreak = 0;
    let longestStreak = 0;

    if (existing) {
      // Update existing day
      days = JSON.parse(existing.days_json);
      const dayIndex = days.findIndex(d => d.date === args.date);

      if (dayIndex >= 0) {
        days[dayIndex] = {
          ...days[dayIndex],
          bloomState: newBloomState,
          checkInsCompleted: args.checkInsCompleted,
          tasksCompleted: args.tasksCompleted,
          totalTasks: args.totalTasks,
          isToday: args.date === todayDate,
        };
      }

      currentStreak = existing.current_streak;
      longestStreak = existing.longest_streak;

      // Update the record
      await ctx.db.patch(existing._id, {
        days_json: JSON.stringify(days),
        updated_at: Date.now(),
      });
    } else {
      // Create new garden state
      const dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      const monday = new Date(weekStartDate);
      days = [];

      for (let i = 0; i < 7; i++) {
        const date = new Date(monday);
        date.setDate(monday.getDate() + i);
        const dateStr = date.toISOString().split("T")[0];
        const isFutureDay = dateStr > todayDate;

        if (dateStr === args.date) {
          days.push({
            date: dateStr,
            dayOfWeek: dayNames[i],
            bloomState: newBloomState,
            checkInsCompleted: args.checkInsCompleted,
            tasksCompleted: args.tasksCompleted,
            totalTasks: args.totalTasks,
            isToday: dateStr === todayDate,
          });
        } else {
          days.push({
            date: dateStr,
            dayOfWeek: dayNames[i],
            bloomState: isFutureDay ? 0 : 1,
            checkInsCompleted: 0,
            tasksCompleted: 0,
            totalTasks: 0,
            isToday: dateStr === todayDate,
          });
        }
      }

      // Get streak from user_streaks table
      const userStreak = await ctx.db
        .query("user_streaks")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .first();

      currentStreak = userStreak?.current_streak ?? 0;
      longestStreak = userStreak?.longest_streak ?? 0;

      // Create new record
      await ctx.db.insert("watch_garden_state", {
        user_id: args.userId,
        week_start_date: weekStartDate,
        days_json: JSON.stringify(days),
        current_streak: currentStreak,
        longest_streak: longestStreak,
        updated_at: Date.now(),
      });
    }

    // Update streak if needed (only when bloom reaches level 4+)
    if (newBloomState >= 4) {
      await updateStreak(ctx, args.userId, args.date);
    }

    return {
      bloomState: newBloomState,
      currentStreak,
      longestStreak,
    };
  },
});

/**
 * Update user streak after a successful day
 */
async function updateStreak(ctx: any, userId: any, date: string) {
  const userStreak = await ctx.db
    .query("user_streaks")
    .withIndex("by_user", (q: any) => q.eq("user_id", userId))
    .first();

  if (!userStreak) {
    // Create new streak record
    await ctx.db.insert("user_streaks", {
      user_id: userId,
      current_streak: 1,
      longest_streak: 1,
      last_activity_date: date,
      streak_frozen_until: undefined,
      freeze_count_this_week: 0,
      week_start_date: getWeekMonday(new Date(date)),
      total_days_completed: 1,
      created_at: Date.now(),
      updated_at: Date.now(),
    });
    return;
  }

  // Check if this extends the streak
  const lastDate = new Date(userStreak.last_activity_date);
  const currentDate = new Date(date);
  const dayDiff = Math.floor((currentDate.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));

  let newStreak = userStreak.current_streak;

  if (dayDiff === 1) {
    // Consecutive day - extend streak
    newStreak = userStreak.current_streak + 1;
  } else if (dayDiff > 1) {
    // Gap in days - reset streak (unless frozen)
    if (userStreak.streak_frozen_until && userStreak.streak_frozen_until >= date) {
      // Streak was frozen, maintain it
      newStreak = userStreak.current_streak;
    } else {
      // Reset streak
      newStreak = 1;
    }
  }
  // dayDiff === 0 means same day, don't change streak

  const newLongest = Math.max(userStreak.longest_streak, newStreak);

  await ctx.db.patch(userStreak._id, {
    current_streak: newStreak,
    longest_streak: newLongest,
    last_activity_date: date,
    total_days_completed: userStreak.total_days_completed + (dayDiff > 0 ? 1 : 0),
    updated_at: Date.now(),
  });
}

/**
 * Get check-in counts for a specific date
 * Used by garden to determine bloom state
 */
export const getCheckInCountsForDate = query({
  args: {
    userId: v.id("users"),
    date: v.string(),  // YYYY-MM-DD
  },
  handler: async (ctx, args) => {
    const checkIns = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", args.date)
      )
      .collect();

    const completedCheckIns = checkIns.filter(c => c.completed);

    return {
      total: completedCheckIns.length,
      morning: completedCheckIns.some(c => c.checkin_type === "morning"),
      midday: completedCheckIns.some(c => c.checkin_type === "midday"),
      evening: completedCheckIns.some(c => c.checkin_type === "evening"),
    };
  },
});

/**
 * Get task counts for a specific date
 * Used by garden to determine bloom state
 */
export const getTaskCountsForDate = query({
  args: {
    userId: v.id("users"),
    date: v.string(),  // YYYY-MM-DD
  },
  handler: async (ctx, args) => {
    const tasks = await ctx.db
      .query("user_daily_tasks")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("task_date", args.date)
      )
      .collect();

    const completedTasks = tasks.filter(t => t.status === "completed");

    return {
      total: tasks.length,
      completed: completedTasks.length,
    };
  },
});

/**
 * Sync garden state after check-in completion
 * Called by watch after submitting a check-in
 */
export const syncGardenAfterCheckIn = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(),  // YYYY-MM-DD
  },
  handler: async (ctx, args) => {
    // Get check-in counts
    const checkIns = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("checkin_date", args.date)
      )
      .collect();

    const completedCheckIns = checkIns.filter(c => c.completed).length;

    // Get task counts
    const tasks = await ctx.db
      .query("user_daily_tasks")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("task_date", args.date)
      )
      .collect();

    const completedTasks = tasks.filter(t => t.status === "completed").length;
    const totalTasks = tasks.length;

    // Update garden
    const weekStartDate = getWeekMonday(new Date(args.date));
    const todayDate = getTodayDate();
    const isFuture = args.date > todayDate;

    const bloomState = calculateBloomState(
      completedCheckIns,
      completedTasks,
      totalTasks,
      isFuture
    );

    // Get existing garden state
    const existing = await ctx.db
      .query("watch_garden_state")
      .withIndex("by_user_week", (q) =>
        q.eq("user_id", args.userId).eq("week_start_date", weekStartDate)
      )
      .first();

    if (existing) {
      const days: DayFlower[] = JSON.parse(existing.days_json);
      const dayIndex = days.findIndex(d => d.date === args.date);

      if (dayIndex >= 0) {
        days[dayIndex] = {
          ...days[dayIndex],
          bloomState,
          checkInsCompleted: completedCheckIns,
          tasksCompleted: completedTasks,
          totalTasks,
        };

        await ctx.db.patch(existing._id, {
          days_json: JSON.stringify(days),
          updated_at: Date.now(),
        });
      }
    }

    // Update streak if blooming
    if (bloomState >= 4) {
      await updateStreak(ctx, args.userId, args.date);
    }

    return {
      bloomState,
      checkInsCompleted: completedCheckIns,
      tasksCompleted: completedTasks,
      totalTasks,
    };
  },
});

/**
 * Get streak info for user
 */
export const getStreakInfo = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const userStreak = await ctx.db
      .query("user_streaks")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    return {
      currentStreak: userStreak?.current_streak ?? 0,
      longestStreak: userStreak?.longest_streak ?? 0,
      totalDaysCompleted: userStreak?.total_days_completed ?? 0,
      lastActivityDate: userStreak?.last_activity_date ?? null,
    };
  },
});
