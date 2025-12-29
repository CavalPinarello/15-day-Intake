/**
 * Daily & Weekly Challenges System
 * Provides engaging micro-goals to boost retention
 *
 * Uses the user_challenges table from schema.ts
 */

import { v } from "convex/values";
import { query, mutation } from "./_generated/server";
import { Id } from "./_generated/dataModel";

// Helper to get today's date
function getTodayString(): string {
  return new Date().toISOString().split("T")[0];
}

// Helper to get week start date (Monday)
function getWeekStartString(): string {
  const today = new Date();
  const day = today.getDay();
  const diff = today.getDate() - day + (day === 0 ? -6 : 1);
  const monday = new Date(today.setDate(diff));
  return monday.toISOString().split("T")[0];
}

// Helper to get week end date (Sunday)
function getWeekEndString(): string {
  const weekStart = new Date(getWeekStartString());
  weekStart.setDate(weekStart.getDate() + 6);
  return weekStart.toISOString().split("T")[0];
}

// ============================================
// Challenge Definitions
// ============================================

interface ChallengeDefinition {
  id: string;
  name: string;
  description: string;
  type: "daily" | "weekly";
  xpReward: number;
  icon: string;
  checkCondition: string; // JSON describing how to check completion
  category: "timing" | "consistency" | "engagement" | "quality";
}

const DAILY_CHALLENGES: ChallengeDefinition[] = [
  {
    id: "morning_logger",
    name: "Morning Logger",
    description: "Complete your sleep log before 9 AM",
    type: "daily",
    xpReward: 30,
    icon: "sunrise",
    checkCondition: JSON.stringify({ action: "sleep_log", timeBefore: "09:00" }),
    category: "timing",
  },
  {
    id: "early_assessment",
    name: "Early Bird Assessment",
    description: "Complete today's assessment before noon",
    type: "daily",
    xpReward: 25,
    icon: "sun",
    checkCondition: JSON.stringify({ action: "assessment", timeBefore: "12:00" }),
    category: "timing",
  },
  {
    id: "reflective_logger",
    name: "Reflective Logger",
    description: "Add a note to your sleep log today",
    type: "daily",
    xpReward: 20,
    icon: "pencil",
    checkCondition: JSON.stringify({ action: "add_note" }),
    category: "engagement",
  },
  {
    id: "insight_explorer",
    name: "Insight Explorer",
    description: "View at least one insight today",
    type: "daily",
    xpReward: 15,
    icon: "lightbulb",
    checkCondition: JSON.stringify({ action: "view_insight" }),
    category: "engagement",
  },
  {
    id: "perfect_day",
    name: "Perfect Day",
    description: "Complete both sleep log and assessment today",
    type: "daily",
    xpReward: 50,
    icon: "star",
    checkCondition: JSON.stringify({ action: "both_complete" }),
    category: "consistency",
  },
];

const WEEKLY_CHALLENGES: ChallengeDefinition[] = [
  {
    id: "week_warrior",
    name: "Week Warrior",
    description: "Complete all 14 tasks this week (7 logs + 7 assessments)",
    type: "weekly",
    xpReward: 200,
    icon: "trophy",
    checkCondition: JSON.stringify({ completions: 14 }),
    category: "consistency",
  },
  {
    id: "consistent_sleeper",
    name: "Consistent Sleeper",
    description: "Log a bedtime within 30 min of average for 5 days",
    type: "weekly",
    xpReward: 150,
    icon: "clock",
    checkCondition: JSON.stringify({ bedtimeVariance: 30, days: 5 }),
    category: "quality",
  },
  {
    id: "morning_champion",
    name: "Morning Champion",
    description: "Complete sleep log before 9 AM for 5 days this week",
    type: "weekly",
    xpReward: 100,
    icon: "sunrise",
    checkCondition: JSON.stringify({ earlyLogs: 5 }),
    category: "timing",
  },
  {
    id: "streak_builder",
    name: "Streak Builder",
    description: "Don't break your streak this week",
    type: "weekly",
    xpReward: 100,
    icon: "flame",
    checkCondition: JSON.stringify({ maintainStreak: true }),
    category: "consistency",
  },
  {
    id: "insight_seeker",
    name: "Insight Seeker",
    description: "View all available insights this week",
    type: "weekly",
    xpReward: 75,
    icon: "brain",
    checkCondition: JSON.stringify({ viewAllInsights: true }),
    category: "engagement",
  },
];

// ============================================
// Queries
// ============================================

/**
 * Get today's available challenges for a user
 */
export const getDailyChallenges = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const today = getTodayString();

    // Get user's challenge progress for today using existing schema
    const userChallenges = await ctx.db
      .query("user_challenges")
      .withIndex("by_user_type", (q) =>
        q.eq("user_id", args.userId).eq("challenge_type", "daily")
      )
      .filter((q) => q.eq(q.field("start_date"), today))
      .collect();

    const completedIds = new Set(
      userChallenges.filter((c) => c.status === "completed").map((c) => c.challenge_id)
    );

    // Return daily challenges with completion status
    return DAILY_CHALLENGES.map((challenge) => ({
      ...challenge,
      isCompleted: completedIds.has(challenge.id),
      progress: userChallenges.find((c) => c.challenge_id === challenge.id)?.progress_current ?? 0,
    }));
  },
});

/**
 * Get this week's challenges for a user
 */
export const getWeeklyChallenges = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const weekStart = getWeekStartString();

    // Get user's weekly challenge progress using existing schema
    const userChallenges = await ctx.db
      .query("user_challenges")
      .withIndex("by_user_type", (q) =>
        q.eq("user_id", args.userId).eq("challenge_type", "weekly")
      )
      .filter((q) => q.eq(q.field("start_date"), weekStart))
      .collect();

    const completedIds = new Set(
      userChallenges.filter((c) => c.status === "completed").map((c) => c.challenge_id)
    );

    return WEEKLY_CHALLENGES.map((challenge) => {
      const userChallenge = userChallenges.find((c) => c.challenge_id === challenge.id);
      return {
        ...challenge,
        isCompleted: completedIds.has(challenge.id),
        progress: userChallenge?.progress_current ?? 0,
        progressTarget: getProgressTarget(challenge.id),
      };
    });
  },
});

/**
 * Get all active challenges (daily + weekly) for display
 */
export const getActiveChallenges = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const today = getTodayString();
    const weekStart = getWeekStartString();
    const todayDate = new Date();
    const dayOfWeek = todayDate.getDay();

    // Get all user challenges
    const userChallenges = await ctx.db
      .query("user_challenges")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const todayChallenges = userChallenges.filter((c) => c.start_date === today);
    const weekChallenges = userChallenges.filter(
      (c) => c.challenge_type === "weekly" && c.start_date === weekStart
    );

    const dailyCompleted = todayChallenges.filter((c) => c.status === "completed").length;
    const weeklyCompleted = weekChallenges.filter((c) => c.status === "completed").length;

    return {
      daily: {
        total: DAILY_CHALLENGES.length,
        completed: dailyCompleted,
        challenges: DAILY_CHALLENGES.map((c) => ({
          ...c,
          isCompleted: todayChallenges.some((tc) => tc.challenge_id === c.id && tc.status === "completed"),
        })),
      },
      weekly: {
        total: WEEKLY_CHALLENGES.length,
        completed: weeklyCompleted,
        daysRemaining: 7 - dayOfWeek,
        challenges: WEEKLY_CHALLENGES.map((c) => ({
          ...c,
          isCompleted: weekChallenges.some((wc) => wc.challenge_id === c.id && wc.status === "completed"),
          progress: weekChallenges.find((wc) => wc.challenge_id === c.id)?.progress_current ?? 0,
        })),
      },
    };
  },
});

// ============================================
// Mutations
// ============================================

/**
 * Record a challenge-related action and check for completions
 * Uses the existing user_challenges schema
 */
export const recordChallengeAction = mutation({
  args: {
    userId: v.id("users"),
    action: v.string(), // "sleep_log", "assessment", "add_note", "view_insight", "both_complete"
    timestamp: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const now = args.timestamp ?? Date.now();
    const today = getTodayString();
    const weekStart = getWeekStartString();
    const weekEnd = getWeekEndString();
    const hour = new Date(now).getHours();

    const completedChallenges: string[] = [];
    const xpEarned: number[] = [];

    // Check daily challenges
    for (const challenge of DAILY_CHALLENGES) {
      const condition = JSON.parse(challenge.checkCondition);
      let completed = false;

      if (condition.action === args.action) {
        if (condition.timeBefore) {
          const [beforeHour] = condition.timeBefore.split(":").map(Number);
          completed = hour < beforeHour;
        } else {
          completed = true;
        }
      }

      if (args.action === "both_complete" && challenge.id === "perfect_day") {
        completed = true;
      }

      if (completed) {
        // Check if already completed today using the existing schema index
        const existing = await ctx.db
          .query("user_challenges")
          .withIndex("by_user_status", (q) =>
            q.eq("user_id", args.userId).eq("status", "active")
          )
          .filter((q) =>
            q.and(
              q.eq(q.field("challenge_id"), challenge.id),
              q.eq(q.field("start_date"), today)
            )
          )
          .first();

        if (!existing) {
          // Create new challenge entry using existing schema
          await ctx.db.insert("user_challenges", {
            user_id: args.userId,
            challenge_id: challenge.id,
            challenge_type: "daily",
            challenge_name: challenge.name,
            challenge_description: challenge.description,
            xp_reward: challenge.xpReward,
            start_date: today,
            end_date: today,
            progress_current: 1,
            progress_target: 1,
            status: "completed",
            completed_at: now,
            created_at: now,
          });
          completedChallenges.push(challenge.name);
          xpEarned.push(challenge.xpReward);
        } else if (existing.status !== "completed") {
          await ctx.db.patch(existing._id, {
            status: "completed",
            completed_at: now,
            progress_current: 1,
          });
          completedChallenges.push(challenge.name);
          xpEarned.push(challenge.xpReward);
        }
      }
    }

    // Update weekly challenge progress
    await updateWeeklyChallengeProgress(ctx, args.userId, args.action, weekStart, weekEnd, now);

    return {
      completedChallenges,
      xpEarned: xpEarned.reduce((a, b) => a + b, 0),
    };
  },
});

/**
 * Manually complete a challenge (for testing or admin)
 */
export const completeChallenge = mutation({
  args: {
    userId: v.id("users"),
    challengeId: v.string(),
    challengeType: v.union(v.literal("daily"), v.literal("weekly")),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = getTodayString();
    const weekStart = getWeekStartString();
    const weekEnd = getWeekEndString();

    const challenge = args.challengeType === "daily"
      ? DAILY_CHALLENGES.find((c) => c.id === args.challengeId)
      : WEEKLY_CHALLENGES.find((c) => c.id === args.challengeId);

    if (!challenge) {
      return { success: false, error: "Challenge not found" };
    }

    const startDate = args.challengeType === "daily" ? today : weekStart;
    const endDate = args.challengeType === "daily" ? today : weekEnd;

    const existing = await ctx.db
      .query("user_challenges")
      .withIndex("by_user_type", (q) =>
        q.eq("user_id", args.userId).eq("challenge_type", args.challengeType)
      )
      .filter((q) =>
        q.and(
          q.eq(q.field("challenge_id"), args.challengeId),
          q.eq(q.field("start_date"), startDate)
        )
      )
      .first();

    if (existing?.status === "completed") {
      return { success: false, error: "Already completed" };
    }

    if (existing) {
      await ctx.db.patch(existing._id, {
        status: "completed",
        completed_at: now,
        progress_current: existing.progress_target,
      });
    } else {
      await ctx.db.insert("user_challenges", {
        user_id: args.userId,
        challenge_id: args.challengeId,
        challenge_type: args.challengeType,
        challenge_name: challenge.name,
        challenge_description: challenge.description,
        xp_reward: challenge.xpReward,
        start_date: startDate,
        end_date: endDate,
        progress_current: 1,
        progress_target: 1,
        status: "completed",
        completed_at: now,
        created_at: now,
      });
    }

    return { success: true, xpEarned: challenge.xpReward };
  },
});

// ============================================
// Helper Functions
// ============================================

function getProgressTarget(challengeId: string): number {
  switch (challengeId) {
    case "week_warrior":
      return 14;
    case "consistent_sleeper":
    case "morning_champion":
      return 5;
    case "streak_builder":
      return 7;
    default:
      return 1;
  }
}

async function updateWeeklyChallengeProgress(
  ctx: any,
  userId: Id<"users">,
  action: string,
  weekStart: string,
  weekEnd: string,
  now: number
) {
  // Update progress for relevant weekly challenges
  for (const challenge of WEEKLY_CHALLENGES) {
    const condition = JSON.parse(challenge.checkCondition);
    let shouldIncrement = false;

    if (challenge.id === "week_warrior" && (action === "sleep_log" || action === "assessment")) {
      shouldIncrement = true;
    }
    if (challenge.id === "morning_champion" && action === "sleep_log") {
      const hour = new Date(now).getHours();
      shouldIncrement = hour < 9;
    }

    if (shouldIncrement) {
      // Use existing schema structure
      const existing = await ctx.db
        .query("user_challenges")
        .withIndex("by_user_type", (q: { eq: (field: string, value: unknown) => typeof q }) =>
          q.eq("user_id", userId).eq("challenge_type", "weekly")
        )
        .filter((q: { and: (...args: unknown[]) => unknown; eq: (field: unknown, value: unknown) => unknown; field: (name: string) => unknown }) =>
          q.and(
            q.eq(q.field("challenge_id"), challenge.id),
            q.eq(q.field("start_date"), weekStart)
          )
        )
        .first();

      const target = getProgressTarget(challenge.id);

      if (existing) {
        const newProgress = (existing.progress_current ?? 0) + 1;
        const isComplete = newProgress >= target;
        await ctx.db.patch(existing._id, {
          progress_current: newProgress,
          status: isComplete ? "completed" : "active",
          completed_at: isComplete ? now : existing.completed_at,
        });
      } else {
        await ctx.db.insert("user_challenges", {
          user_id: userId,
          challenge_id: challenge.id,
          challenge_type: "weekly",
          challenge_name: challenge.name,
          challenge_description: challenge.description,
          xp_reward: challenge.xpReward,
          start_date: weekStart,
          end_date: weekEnd,
          progress_current: 1,
          progress_target: target,
          status: "active",
          created_at: now,
        });
      }
    }
  }
}
