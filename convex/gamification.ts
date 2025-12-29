import { v } from "convex/values";
import { query, mutation, internalMutation } from "./_generated/server";
import { Id } from "./_generated/dataModel";
import { api } from "./_generated/api";

// ============================================
// Constants
// ============================================

export const XP_VALUES = {
  SLEEP_LOG: 50,
  ASSESSMENT: 100,
  PERFECT_DAY: 200, // Both log + assessment (includes 50 bonus)
  STREAK_7_DAY: 500,
  STREAK_15_DAY: 1000,
  STREAK_30_DAY: 2000,
  EXPANSION_PACK: 300,
  CONNECT_WEARABLE: 100,
  VIEW_INSIGHT: 10,
} as const;

export const LEVEL_THRESHOLDS = {
  1: { name: "Sleep Novice", minXP: 0, maxXP: 500 },
  2: { name: "Sleep Student", minXP: 500, maxXP: 1500 },
  3: { name: "Sleep Scholar", minXP: 1500, maxXP: 3500 },
  4: { name: "Sleep Expert", minXP: 3500, maxXP: 7000 },
  5: { name: "Sleep Master", minXP: 7000, maxXP: Infinity },
} as const;

// Helper to get current date as YYYY-MM-DD
function getTodayString(): string {
  return new Date().toISOString().split("T")[0];
}

// Helper to get week start (Monday) as YYYY-MM-DD
function getWeekStartString(): string {
  const today = new Date();
  const day = today.getDay();
  const diff = today.getDate() - day + (day === 0 ? -6 : 1);
  const monday = new Date(today.setDate(diff));
  return monday.toISOString().split("T")[0];
}

// Calculate level from XP
function calculateLevel(totalXP: number): { level: number; name: string; xpToNext: number } {
  for (let level = 5; level >= 1; level--) {
    const threshold = LEVEL_THRESHOLDS[level as keyof typeof LEVEL_THRESHOLDS];
    if (totalXP >= threshold.minXP) {
      return {
        level,
        name: threshold.name,
        xpToNext: threshold.maxXP === Infinity ? 0 : threshold.maxXP - totalXP,
      };
    }
  }
  return { level: 1, name: "Sleep Novice", xpToNext: 500 - totalXP };
}

// ============================================
// Streak Queries & Mutations
// ============================================

export const getUserStreak = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const streak = await ctx.db
      .query("user_streaks")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!streak) {
      return {
        currentStreak: 0,
        longestStreak: 0,
        lastActivityDate: null,
        totalDaysCompleted: 0,
        streakAtRisk: false,
        hasFreezeAvailable: true,
      };
    }

    const today = getTodayString();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().split("T")[0];

    // Check if streak is at risk (last activity was yesterday, not today)
    const streakAtRisk = streak.last_activity_date === yesterdayStr;
    const hasFreezeAvailable = streak.freeze_count_this_week < 1;

    return {
      currentStreak: streak.current_streak,
      longestStreak: streak.longest_streak,
      lastActivityDate: streak.last_activity_date,
      totalDaysCompleted: streak.total_days_completed,
      streakAtRisk,
      hasFreezeAvailable,
    };
  },
});

export const recordDailyActivity = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const today = getTodayString();
    const weekStart = getWeekStartString();
    const now = Date.now();

    const existingStreak = await ctx.db
      .query("user_streaks")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!existingStreak) {
      // First activity ever - create new streak
      await ctx.db.insert("user_streaks", {
        user_id: args.userId,
        current_streak: 1,
        longest_streak: 1,
        last_activity_date: today,
        freeze_count_this_week: 0,
        week_start_date: weekStart,
        total_days_completed: 1,
        created_at: now,
        updated_at: now,
      });
      return { currentStreak: 1, xpEarned: 0, isNewRecord: true };
    }

    // Already logged today
    if (existingStreak.last_activity_date === today) {
      return {
        currentStreak: existingStreak.current_streak,
        xpEarned: 0,
        isNewRecord: false,
      };
    }

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().split("T")[0];

    let newStreak: number;
    let xpEarned = 0;

    if (existingStreak.last_activity_date === yesterdayStr) {
      // Continuing streak
      newStreak = existingStreak.current_streak + 1;
    } else if (
      existingStreak.streak_frozen_until &&
      existingStreak.streak_frozen_until >= today
    ) {
      // Streak was frozen - continue it
      newStreak = existingStreak.current_streak + 1;
    } else {
      // Streak broken - start over
      newStreak = 1;
    }

    // Check for streak milestones
    if (newStreak === 7) xpEarned = XP_VALUES.STREAK_7_DAY;
    else if (newStreak === 15) xpEarned = XP_VALUES.STREAK_15_DAY;
    else if (newStreak === 30) xpEarned = XP_VALUES.STREAK_30_DAY;

    const isNewRecord = newStreak > existingStreak.longest_streak;

    // Reset week tracking if new week
    const freezeCount =
      existingStreak.week_start_date === weekStart
        ? existingStreak.freeze_count_this_week
        : 0;

    await ctx.db.patch(existingStreak._id, {
      current_streak: newStreak,
      longest_streak: isNewRecord ? newStreak : existingStreak.longest_streak,
      last_activity_date: today,
      streak_frozen_until: undefined, // Clear any freeze
      freeze_count_this_week: freezeCount,
      week_start_date: weekStart,
      total_days_completed: existingStreak.total_days_completed + 1,
      updated_at: now,
    });

    return { currentStreak: newStreak, xpEarned, isNewRecord };
  },
});

export const useStreakFreeze = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const streak = await ctx.db
      .query("user_streaks")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!streak) {
      return { success: false, reason: "No streak to freeze" };
    }

    if (streak.freeze_count_this_week >= 1) {
      return { success: false, reason: "Already used freeze this week" };
    }

    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split("T")[0];

    await ctx.db.patch(streak._id, {
      streak_frozen_until: tomorrowStr,
      freeze_count_this_week: streak.freeze_count_this_week + 1,
      updated_at: Date.now(),
    });

    return { success: true, frozenUntil: tomorrowStr };
  },
});

// ============================================
// XP Queries & Mutations
// ============================================

export const getUserXP = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const userXP = await ctx.db
      .query("user_xp")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!userXP) {
      return {
        totalXP: 0,
        currentLevel: 1,
        levelName: "Sleep Novice",
        xpToNextLevel: 500,
        weeklyXP: 0,
        breakdown: {
          logs: 0,
          assessments: 0,
          streaks: 0,
          badges: 0,
          challenges: 0,
        },
      };
    }

    return {
      totalXP: userXP.total_xp,
      currentLevel: userXP.current_level,
      levelName: userXP.level_name,
      xpToNextLevel: userXP.xp_to_next_level,
      weeklyXP: userXP.weekly_xp,
      breakdown: {
        logs: userXP.xp_from_logs,
        assessments: userXP.xp_from_assessments,
        streaks: userXP.xp_from_streaks,
        badges: userXP.xp_from_badges,
        challenges: userXP.xp_from_challenges,
      },
    };
  },
});

export const awardXP = mutation({
  args: {
    userId: v.id("users"),
    amount: v.number(),
    transactionType: v.string(),
    description: v.string(),
    referenceId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const weekStart = getWeekStartString();

    // Get or create user XP record
    let userXP = await ctx.db
      .query("user_xp")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const newTotalXP = (userXP?.total_xp ?? 0) + args.amount;
    const levelInfo = calculateLevel(newTotalXP);

    // Reset weekly XP if new week
    const currentWeeklyXP =
      userXP?.week_start_date === weekStart ? userXP.weekly_xp : 0;

    // Update breakdown based on transaction type
    const getBreakdownKey = (type: string) => {
      switch (type) {
        case "sleep_log":
          return "xp_from_logs";
        case "assessment":
          return "xp_from_assessments";
        case "streak_bonus":
          return "xp_from_streaks";
        case "badge_earned":
          return "xp_from_badges";
        case "challenge_complete":
          return "xp_from_challenges";
        default:
          return null;
      }
    };

    const breakdownKey = getBreakdownKey(args.transactionType);

    if (userXP) {
      const updates: Record<string, unknown> = {
        total_xp: newTotalXP,
        current_level: levelInfo.level,
        level_name: levelInfo.name,
        xp_to_next_level: levelInfo.xpToNext,
        weekly_xp: currentWeeklyXP + args.amount,
        week_start_date: weekStart,
        updated_at: now,
      };

      if (breakdownKey) {
        updates[breakdownKey] = (userXP[breakdownKey as keyof typeof userXP] as number ?? 0) + args.amount;
      }

      await ctx.db.patch(userXP._id, updates);
    } else {
      const newRecord: Record<string, unknown> = {
        user_id: args.userId,
        total_xp: args.amount,
        current_level: levelInfo.level,
        level_name: levelInfo.name,
        xp_to_next_level: levelInfo.xpToNext,
        weekly_xp: args.amount,
        week_start_date: weekStart,
        xp_from_logs: 0,
        xp_from_assessments: 0,
        xp_from_streaks: 0,
        xp_from_badges: 0,
        xp_from_challenges: 0,
        updated_at: now,
      };

      if (breakdownKey) {
        newRecord[breakdownKey] = args.amount;
      }

      await ctx.db.insert("user_xp", newRecord as {
        user_id: Id<"users">;
        total_xp: number;
        current_level: number;
        level_name: string;
        xp_to_next_level: number;
        weekly_xp: number;
        week_start_date: string;
        xp_from_logs: number;
        xp_from_assessments: number;
        xp_from_streaks: number;
        xp_from_badges: number;
        xp_from_challenges: number;
        updated_at: number;
      });
    }

    // Log the transaction
    await ctx.db.insert("xp_transactions", {
      user_id: args.userId,
      xp_amount: args.amount,
      transaction_type: args.transactionType,
      description: args.description,
      reference_id: args.referenceId,
      created_at: now,
    });

    // Check for level up
    const previousLevel = userXP?.current_level ?? 1;
    const leveledUp = levelInfo.level > previousLevel;

    return {
      newTotalXP,
      currentLevel: levelInfo.level,
      levelName: levelInfo.name,
      xpToNextLevel: levelInfo.xpToNext,
      leveledUp,
      previousLevel,
    };
  },
});

export const getRecentXPTransactions = query({
  args: { userId: v.id("users"), limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const transactions = await ctx.db
      .query("xp_transactions")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(args.limit ?? 10);

    return transactions;
  },
});

// ============================================
// Badge Queries & Mutations
// ============================================

export const getUserBadges = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const badges = await ctx.db
      .query("user_badges")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const earned = badges.filter((b) => b.is_earned);
    const inProgress = badges.filter((b) => !b.is_earned);

    return { earned, inProgress };
  },
});

export const awardBadge = mutation({
  args: {
    userId: v.id("users"),
    badgeId: v.string(),
    badgeName: v.string(),
    badgeDescription: v.string(),
    badgeCategory: v.string(),
    badgeIcon: v.string(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if already earned
    const existing = await ctx.db
      .query("user_badges")
      .withIndex("by_user_badge", (q) =>
        q.eq("user_id", args.userId).eq("badge_id", args.badgeId)
      )
      .first();

    if (existing?.is_earned) {
      return { alreadyEarned: true, badge: existing };
    }

    if (existing) {
      // Update existing in-progress badge to earned
      await ctx.db.patch(existing._id, {
        is_earned: true,
        earned_at: now,
      });
      return { alreadyEarned: false, badge: existing };
    }

    // Create new earned badge
    const badge = await ctx.db.insert("user_badges", {
      user_id: args.userId,
      badge_id: args.badgeId,
      badge_name: args.badgeName,
      badge_description: args.badgeDescription,
      badge_category: args.badgeCategory,
      badge_icon: args.badgeIcon,
      earned_at: now,
      is_earned: true,
    });

    return { alreadyEarned: false, badgeId: badge };
  },
});

export const updateBadgeProgress = mutation({
  args: {
    userId: v.id("users"),
    badgeId: v.string(),
    progressCurrent: v.number(),
    progressTarget: v.number(),
    badgeName: v.string(),
    badgeDescription: v.string(),
    badgeCategory: v.string(),
    badgeIcon: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("user_badges")
      .withIndex("by_user_badge", (q) =>
        q.eq("user_id", args.userId).eq("badge_id", args.badgeId)
      )
      .first();

    const isComplete = args.progressCurrent >= args.progressTarget;

    if (existing) {
      await ctx.db.patch(existing._id, {
        progress_current: args.progressCurrent,
        progress_target: args.progressTarget,
        is_earned: isComplete,
        earned_at: isComplete ? Date.now() : existing.earned_at,
      });
    } else {
      await ctx.db.insert("user_badges", {
        user_id: args.userId,
        badge_id: args.badgeId,
        badge_name: args.badgeName,
        badge_description: args.badgeDescription,
        badge_category: args.badgeCategory,
        badge_icon: args.badgeIcon,
        earned_at: isComplete ? Date.now() : 0,
        progress_current: args.progressCurrent,
        progress_target: args.progressTarget,
        is_earned: isComplete,
      });
    }

    return { isComplete };
  },
});

// ============================================
// Combined Activity Recording (for Day Complete)
// ============================================

export const recordDayComplete = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    completedSleepLog: v.boolean(),
    completedAssessment: v.boolean(),
    triggeredGateways: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const results: {
      xpEarned: number;
      streakUpdate: { currentStreak: number; xpEarned: number; isNewRecord: boolean } | null;
      badgesEarned: string[];
      leveledUp: boolean;
    } = {
      xpEarned: 0,
      streakUpdate: null,
      badgesEarned: [],
      leveledUp: false,
    };

    // 1. Record streak activity
    const streakResult = await ctx.runMutation(api.gamification.recordDailyActivity, {
      userId: args.userId,
    });
    results.streakUpdate = streakResult;

    // 2. Award XP for completions
    let totalXP = 0;

    if (args.completedSleepLog && args.completedAssessment) {
      // Perfect day bonus
      totalXP = XP_VALUES.PERFECT_DAY;
      await ctx.runMutation(api.gamification.awardXP, {
        userId: args.userId,
        amount: XP_VALUES.PERFECT_DAY,
        transactionType: "assessment",
        description: `Perfect Day ${args.dayNumber} - Sleep Log + Assessment`,
      });
    } else {
      if (args.completedSleepLog) {
        totalXP += XP_VALUES.SLEEP_LOG;
        await ctx.runMutation(api.gamification.awardXP, {
          userId: args.userId,
          amount: XP_VALUES.SLEEP_LOG,
          transactionType: "sleep_log",
          description: `Day ${args.dayNumber} Sleep Log`,
        });
      }
      if (args.completedAssessment) {
        totalXP += XP_VALUES.ASSESSMENT;
        await ctx.runMutation(api.gamification.awardXP, {
          userId: args.userId,
          amount: XP_VALUES.ASSESSMENT,
          transactionType: "assessment",
          description: `Day ${args.dayNumber} Assessment`,
        });
      }
    }

    // Award streak XP if applicable
    if (streakResult.xpEarned > 0) {
      await ctx.runMutation(api.gamification.awardXP, {
        userId: args.userId,
        amount: streakResult.xpEarned,
        transactionType: "streak_bonus",
        description: `${streakResult.currentStreak}-day streak bonus!`,
      });
      totalXP += streakResult.xpEarned;
    }

    results.xpEarned = totalXP;

    // 3. Check for journey badges
    const journeyBadges = [
      { day: 1, id: "first_step", name: "First Step", icon: "🌟" },
      { day: 8, id: "halfway_hero", name: "Halfway Hero", icon: "🏃" },
      { day: 15, id: "journey_master", name: "Journey Master", icon: "🏆" },
    ];

    for (const badge of journeyBadges) {
      if (args.dayNumber === badge.day) {
        const result = await ctx.runMutation(api.gamification.awardBadge, {
          userId: args.userId,
          badgeId: badge.id,
          badgeName: badge.name,
          badgeDescription: `Complete Day ${badge.day} of your sleep journey`,
          badgeCategory: "journey",
          badgeIcon: badge.icon,
        });
        if (!result.alreadyEarned) {
          results.badgesEarned.push(badge.name);
        }
      }
    }

    // 4. Check for gateway explorer badge
    if (args.triggeredGateways && args.triggeredGateways.length > 0) {
      const result = await ctx.runMutation(api.gamification.awardBadge, {
        userId: args.userId,
        badgeId: "gateway_explorer",
        badgeName: "Gateway Explorer",
        badgeDescription: "Unlock your first personalized deep dive",
        badgeCategory: "journey",
        badgeIcon: "🔍",
      });
      if (!result.alreadyEarned) {
        results.badgesEarned.push("Gateway Explorer");
      }
    }

    // 5. Check streak badges
    const streakBadges = [
      { streak: 7, id: "week_warrior", name: "Week Warrior", icon: "🔥" },
      { streak: 15, id: "journey_complete", name: "Journey Complete", icon: "✨" },
      { streak: 30, id: "sleep_champion", name: "Sleep Champion", icon: "👑" },
    ];

    for (const badge of streakBadges) {
      if (streakResult.currentStreak === badge.streak) {
        const result = await ctx.runMutation(api.gamification.awardBadge, {
          userId: args.userId,
          badgeId: badge.id,
          badgeName: badge.name,
          badgeDescription: `Maintain a ${badge.streak}-day streak`,
          badgeCategory: "streak",
          badgeIcon: badge.icon,
        });
        if (!result.alreadyEarned) {
          results.badgesEarned.push(badge.name);
        }
      }
    }

    return results;
  },
});

// ============================================
// Engagement Summary for Clinician Dashboard
// ============================================

export const getPatientEngagement = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get streak info
    const streak = await ctx.db
      .query("user_streaks")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    // Get XP info
    const xp = await ctx.db
      .query("user_xp")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    // Get badges
    const badges = await ctx.db
      .query("user_badges")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("is_earned"), true))
      .collect();

    // Calculate completion rate from user_progress
    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const completedDays = progress.filter((p) => p.completed).length;
    const completionRate = progress.length > 0 ? (completedDays / 15) * 100 : 0;

    // Get last activity from various sources
    const user = await ctx.db.get(args.userId);
    const lastActive = user?.last_accessed ?? 0;

    // Calculate engagement score (0-100)
    const streakScore = Math.min((streak?.current_streak ?? 0) * 5, 25);
    const completionScore = completionRate * 0.25;
    const badgeScore = Math.min(badges.length * 5, 25);
    const xpScore = Math.min((xp?.current_level ?? 1) * 5, 25);
    const engagementScore = Math.round(
      streakScore + completionScore + badgeScore + xpScore
    );

    // Generate engagement insights for clinician
    const insights: string[] = [];
    if ((streak?.current_streak ?? 0) >= 7) {
      insights.push("High engagement - good candidate for intensive intervention");
    }
    if ((streak?.current_streak ?? 0) === 0 && (streak?.total_days_completed ?? 0) > 3) {
      insights.push("Streak broken recently - may benefit from simplified routine");
    }
    if (badges.some((b) => b.badge_category === "journey" && b.badge_id === "journey_master")) {
      insights.push("Completed full journey - thorough self-reporter");
    }
    if (completionRate < 50) {
      insights.push("Low completion rate - consider check-in call");
    }

    return {
      currentStreak: streak?.current_streak ?? 0,
      longestStreak: streak?.longest_streak ?? 0,
      totalDaysCompleted: streak?.total_days_completed ?? 0,
      level: xp?.current_level ?? 1,
      levelName: xp?.level_name ?? "Sleep Novice",
      totalXP: xp?.total_xp ?? 0,
      badgesEarned: badges.length,
      badges: badges.map((b) => ({
        id: b.badge_id,
        name: b.badge_name,
        icon: b.badge_icon,
        earnedAt: b.earned_at,
      })),
      completionRate: Math.round(completionRate),
      engagementScore,
      lastActive,
      insights,
    };
  },
});
