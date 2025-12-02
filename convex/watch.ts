/**
 * Watch-Specific Convex Functions
 *
 * These functions enable Apple Watch to directly communicate with Convex
 * for real-time sync of questionnaire progress between Watch, iPhone, and Web.
 */

import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// Watch Authentication (Simple Username/Password)
// ============================================

// Simple hash function matching Watch app's simpleHash
function simpleHash(str: string): string {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash = hash & hash;
  }
  return Math.abs(hash).toString(16);
}

// SHA256 of "1" - the test password
const TEST_PASSWORD_SHA256 = "6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b";
// Simple hash of "1" - what Watch currently sends
const TEST_PASSWORD_SIMPLE = simpleHash("1"); // "31"

/**
 * Sign in from Watch using username and password
 * Accepts both SHA256 and simple hash for compatibility
 */
export const signIn = mutation({
  args: {
    username: v.string(),
    passwordHash: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();

    if (!user) {
      throw new Error("User not found");
    }

    // Accept multiple hash formats for development flexibility
    const validHashes = [
      user.password_hash,           // Whatever is in DB (SHA256)
      TEST_PASSWORD_SIMPLE,         // "31" - simple hash of "1"
      TEST_PASSWORD_SHA256,         // SHA256 of "1"
      "31",                         // Direct simple hash
    ];

    if (!validHashes.includes(args.passwordHash)) {
      throw new Error("Invalid password");
    }

    // Update last accessed
    await ctx.db.patch(user._id, {
      last_accessed: Date.now(),
    });

    return {
      userId: user._id,
      username: user.username,
      currentDay: user.current_day,
      onboardingCompleted: user.onboarding_completed ?? false,
    };
  },
});

// ============================================
// Journey Progress Functions
// ============================================

/**
 * Get user's current journey state
 * Returns current day, completed days, and section completion status
 */
export const getJourneyState = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get all user progress entries
    const progressEntries = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get completed day numbers and section completion status
    const completedDays: number[] = [];
    const daySectionStatus: { [key: number]: { sleepLogCompleted: boolean; assessmentCompleted: boolean } } = {};

    for (const entry of progressEntries) {
      const day = await ctx.db.get(entry.day_id);
      if (day) {
        daySectionStatus[day.day_number] = {
          sleepLogCompleted: entry.sleep_log_completed ?? entry.completed ?? false,
          assessmentCompleted: entry.assessment_completed ?? entry.completed ?? false,
        };
        if (entry.completed) {
          completedDays.push(day.day_number);
        }
      }
    }

    // Get section status for current day
    const currentDaySections = daySectionStatus[user.current_day] ?? {
      sleepLogCompleted: false,
      assessmentCompleted: false,
    };

    return {
      currentDay: user.current_day,
      completedDays: completedDays.sort((a, b) => a - b),
      journeyComplete: user.onboarding_completed ?? false,
      totalDays: 15,
      // Section-level completion for current day
      sleepLogCompleted: currentDaySections.sleepLogCompleted,
      assessmentCompleted: currentDaySections.assessmentCompleted,
      // Full section status for all days
      daySectionStatus,
    };
  },
});

/**
 * Check if a specific day is completed
 */
export const isDayCompleted = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", args.dayNumber))
      .first();

    if (!day) {
      return false;
    }

    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", day._id)
      )
      .first();

    return progress?.completed ?? false;
  },
});

/**
 * Complete a specific section (Sleep Log or Assessment) for a day
 * This allows partial day completion across devices
 */
export const completeSection = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.union(v.literal("sleepLog"), v.literal("assessment")),
    source: v.optional(v.string()), // "watch" or "iphone" or "web"
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get or create the day entry
    let day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", args.dayNumber))
      .first();

    if (!day) {
      const dayId = await ctx.db.insert("days", {
        day_number: args.dayNumber,
        title: `Day ${args.dayNumber}`,
        created_at: Date.now(),
      });
      day = await ctx.db.get(dayId);
    }

    if (!day) {
      throw new Error("Failed to create day entry");
    }

    const now = Date.now();

    // Check if progress already exists
    const existingProgress = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", day!._id)
      )
      .first();

    let sleepLogCompleted = false;
    let assessmentCompleted = false;

    if (existingProgress) {
      sleepLogCompleted = existingProgress.sleep_log_completed ?? false;
      assessmentCompleted = existingProgress.assessment_completed ?? false;

      // Update the specific section
      if (args.section === "sleepLog") {
        sleepLogCompleted = true;
      } else {
        assessmentCompleted = true;
      }

      // Update existing progress
      await ctx.db.patch(existingProgress._id, {
        sleep_log_completed: sleepLogCompleted,
        assessment_completed: assessmentCompleted,
        // Mark day as fully completed if both sections are done
        completed: sleepLogCompleted && assessmentCompleted,
        completed_at: sleepLogCompleted && assessmentCompleted ? now : existingProgress.completed_at,
      });
    } else {
      // Create new progress entry
      sleepLogCompleted = args.section === "sleepLog";
      assessmentCompleted = args.section === "assessment";

      await ctx.db.insert("user_progress", {
        user_id: args.userId,
        day_id: day._id,
        sleep_log_completed: sleepLogCompleted,
        assessment_completed: assessmentCompleted,
        completed: sleepLogCompleted && assessmentCompleted,
        completed_at: sleepLogCompleted && assessmentCompleted ? now : undefined,
        created_at: now,
      });
    }

    // If both sections are now complete, advance to next day
    const dayFullyCompleted = sleepLogCompleted && assessmentCompleted;
    let newDay = user.current_day;

    if (dayFullyCompleted && user.current_day === args.dayNumber && args.dayNumber < 15) {
      newDay = args.dayNumber + 1;
      await ctx.db.patch(args.userId, {
        current_day: newDay,
        last_accessed: now,
      });
    }

    // Mark journey complete if day 15 is fully done
    if (args.dayNumber === 15 && dayFullyCompleted) {
      await ctx.db.patch(args.userId, {
        onboarding_completed: true,
        onboarding_completed_at: now,
      });
    }

    return {
      success: true,
      section: args.section,
      sleepLogCompleted,
      assessmentCompleted,
      dayFullyCompleted,
      currentDay: newDay,
      journeyComplete: args.dayNumber === 15 && dayFullyCompleted,
      source: args.source ?? "unknown",
    };
  },
});

/**
 * Mark a day as completed
 * This is called when user finishes questionnaire on Watch or iPhone
 */
export const completeDay = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    source: v.optional(v.string()), // "watch" or "iphone" or "web"
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get or create the day entry
    let day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", args.dayNumber))
      .first();

    if (!day) {
      // Create day entry if it doesn't exist
      const dayId = await ctx.db.insert("days", {
        day_number: args.dayNumber,
        title: `Day ${args.dayNumber}`,
        created_at: Date.now(),
      });
      day = await ctx.db.get(dayId);
    }

    if (!day) {
      throw new Error("Failed to create day entry");
    }

    // Check if progress already exists
    const existingProgress = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", day!._id)
      )
      .first();

    const now = Date.now();

    if (existingProgress) {
      // Update existing progress
      await ctx.db.patch(existingProgress._id, {
        completed: true,
        completed_at: now,
      });
    } else {
      // Create new progress entry
      await ctx.db.insert("user_progress", {
        user_id: args.userId,
        day_id: day._id,
        completed: true,
        completed_at: now,
        created_at: now,
      });
    }

    // Advance user's current day if needed
    if (user.current_day === args.dayNumber && args.dayNumber < 15) {
      await ctx.db.patch(args.userId, {
        current_day: args.dayNumber + 1,
        last_accessed: now,
      });
    }

    // Mark journey complete if day 15
    if (args.dayNumber === 15) {
      await ctx.db.patch(args.userId, {
        onboarding_completed: true,
        onboarding_completed_at: now,
      });
    }

    return {
      success: true,
      newDay: Math.min(args.dayNumber + 1, 15),
      journeyComplete: args.dayNumber === 15,
      source: args.source ?? "unknown",
    };
  },
});

/**
 * Check if user can advance to the next day
 * Requirements:
 * - Both sleepLog AND assessment must be completed for current day
 * - In normal mode: Must also be past 4 AM the next day
 * - In debug mode: Can advance immediately once both sections complete
 */
export const canAdvanceDay = query({
  args: {
    userId: v.id("users"),
    debugMode: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      return {
        canAdvance: false,
        reason: "User not found",
        sleepLogCompleted: false,
        assessmentCompleted: false,
        timeUnlocked: false,
      };
    }

    const currentDay = user.current_day || 1;

    // Can't advance past day 15
    if (currentDay >= 15) {
      return {
        canAdvance: false,
        reason: "Journey already complete",
        sleepLogCompleted: true,
        assessmentCompleted: true,
        timeUnlocked: true,
        currentDay: 15,
      };
    }

    // Get the day entry
    const day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", currentDay))
      .first();

    let sleepLogCompleted = false;
    let assessmentCompleted = false;

    if (day) {
      const progress = await ctx.db
        .query("user_progress")
        .withIndex("by_user_day", (q) =>
          q.eq("user_id", args.userId).eq("day_id", day._id)
        )
        .first();

      if (progress) {
        sleepLogCompleted = progress.sleep_log_completed ?? progress.completed ?? false;
        assessmentCompleted = progress.assessment_completed ?? progress.completed ?? false;
      }
    }

    const bothSectionsComplete = sleepLogCompleted && assessmentCompleted;

    // Check time restriction (4 AM unlock)
    // In debug mode, skip time check
    let timeUnlocked = args.debugMode ?? false;

    if (!timeUnlocked) {
      // Check if it's past 4 AM
      // Note: This runs on the server, so we use UTC and let clients handle timezone
      const now = new Date();
      const hour = now.getHours();
      // For now, assume server is in user's timezone (simplified)
      // In production, you'd want to track user's timezone
      timeUnlocked = hour >= 4;
    }

    const canAdvance = bothSectionsComplete && timeUnlocked;

    let reason = "";
    if (!sleepLogCompleted && !assessmentCompleted) {
      reason = "Complete both Sleep Log and Assessment to unlock the next day";
    } else if (!sleepLogCompleted) {
      reason = "Complete the Sleep Log to unlock the next day";
    } else if (!assessmentCompleted) {
      reason = "Complete the Assessment to unlock the next day";
    } else if (!timeUnlocked) {
      reason = "Next day unlocks at 4:00 AM";
    } else {
      reason = "Ready to advance";
    }

    return {
      canAdvance,
      reason,
      sleepLogCompleted,
      assessmentCompleted,
      timeUnlocked,
      currentDay,
      nextDay: currentDay + 1,
    };
  },
});

/**
 * Advance to next day
 * STRICT VALIDATION: Both sections must be completed before advancing
 * - debugMode: Bypasses time check (4 AM) but NOT completion check
 */
export const advanceDay = mutation({
  args: {
    userId: v.id("users"),
    debugMode: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const currentDay = user.current_day || 1;

    // Can't advance past day 15
    if (currentDay >= 15) {
      return {
        success: false,
        error: "Journey already complete",
        currentDay: 15,
      };
    }

    // Get the day entry
    let day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", currentDay))
      .first();

    if (!day) {
      const dayId = await ctx.db.insert("days", {
        day_number: currentDay,
        title: `Day ${currentDay}`,
        created_at: Date.now(),
      });
      day = await ctx.db.get(dayId);
    }

    if (!day) {
      throw new Error("Failed to create day entry");
    }

    // Check section completion - REQUIRED even in debug mode
    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", day!._id)
      )
      .first();

    const sleepLogCompleted = progress?.sleep_log_completed ?? progress?.completed ?? false;
    const assessmentCompleted = progress?.assessment_completed ?? progress?.completed ?? false;

    // STRICT CHECK: Both sections must be completed
    if (!sleepLogCompleted || !assessmentCompleted) {
      let missingSection = "";
      if (!sleepLogCompleted && !assessmentCompleted) {
        missingSection = "both Sleep Log and Assessment";
      } else if (!sleepLogCompleted) {
        missingSection = "Sleep Log";
      } else {
        missingSection = "Assessment";
      }

      return {
        success: false,
        error: `Cannot advance: Complete ${missingSection} first`,
        sleepLogCompleted,
        assessmentCompleted,
        currentDay,
      };
    }

    // Time check (only in normal mode)
    if (!args.debugMode) {
      const now = new Date();
      const hour = now.getHours();
      if (hour < 4) {
        return {
          success: false,
          error: "Next day unlocks at 4:00 AM",
          sleepLogCompleted,
          assessmentCompleted,
          currentDay,
          timeUnlocked: false,
        };
      }
    }

    const newDay = currentDay + 1;

    // Mark current day as fully completed (ensure both flags set)
    const now = Date.now();
    if (progress) {
      await ctx.db.patch(progress._id, {
        completed: true,
        completed_at: now,
        sleep_log_completed: true,
        assessment_completed: true,
      });
    } else {
      await ctx.db.insert("user_progress", {
        user_id: args.userId,
        day_id: day._id,
        completed: true,
        completed_at: now,
        created_at: now,
        sleep_log_completed: true,
        assessment_completed: true,
      });
    }

    // Update user's current day
    await ctx.db.patch(args.userId, {
      current_day: newDay,
      last_accessed: now,
    });

    return {
      success: true,
      previousDay: currentDay,
      newDay: newDay,
      sleepLogCompleted: true,
      assessmentCompleted: true,
    };
  },
});

/**
 * Reset journey progress (Debug Mode)
 */
export const resetProgress = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Reset user's day to 1
    await ctx.db.patch(args.userId, {
      current_day: 1,
      onboarding_completed: false,
      onboarding_completed_at: undefined,
      last_accessed: Date.now(),
    });

    // Delete all progress entries for this user
    const progressEntries = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const entry of progressEntries) {
      await ctx.db.delete(entry._id);
    }

    // Delete all questionnaire responses
    const responses = await ctx.db
      .query("responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const response of responses) {
      await ctx.db.delete(response._id);
    }

    // Delete assessment responses
    const assessmentResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const response of assessmentResponses) {
      await ctx.db.delete(response._id);
    }

    return {
      success: true,
      newDay: 1,
    };
  },
});

// ============================================
// Questionnaire Response Functions
// ============================================

/**
 * Save a questionnaire response from Watch
 */
export const saveResponse = mutation({
  args: {
    userId: v.id("users"),
    questionId: v.string(),
    dayNumber: v.number(),
    responseValue: v.optional(v.string()),
    responseNumber: v.optional(v.number()),
    responseArray: v.optional(v.array(v.string())),
    source: v.optional(v.string()), // "watch" or "iphone"
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if response already exists
    const existing = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", args.questionId)
      )
      .first();

    if (existing) {
      // Update existing response
      await ctx.db.patch(existing._id, {
        response_value: args.responseValue,
        response_number: args.responseNumber,
        response_array: args.responseArray ? JSON.stringify(args.responseArray) : undefined,
        day_number: args.dayNumber,
        updated_at: now,
      });
    } else {
      // Create new response
      await ctx.db.insert("user_assessment_responses", {
        user_id: args.userId,
        question_id: args.questionId,
        response_value: args.responseValue,
        response_number: args.responseNumber,
        response_array: args.responseArray ? JSON.stringify(args.responseArray) : undefined,
        day_number: args.dayNumber,
        created_at: now,
        updated_at: now,
      });
    }

    return { success: true };
  },
});

/**
 * Save multiple responses at once (batch save from Watch)
 */
export const saveResponses = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    responses: v.array(
      v.object({
        questionId: v.string(),
        responseValue: v.optional(v.string()),
        responseNumber: v.optional(v.number()),
        responseArray: v.optional(v.array(v.string())),
      })
    ),
    source: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    for (const response of args.responses) {
      const existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", response.questionId)
        )
        .first();

      if (existing) {
        await ctx.db.patch(existing._id, {
          response_value: response.responseValue,
          response_number: response.responseNumber,
          response_array: response.responseArray ? JSON.stringify(response.responseArray) : undefined,
          day_number: args.dayNumber,
          updated_at: now,
        });
      } else {
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: response.questionId,
          response_value: response.responseValue,
          response_number: response.responseNumber,
          response_array: response.responseArray ? JSON.stringify(response.responseArray) : undefined,
          day_number: args.dayNumber,
          created_at: now,
          updated_at: now,
        });
      }
    }

    return { success: true, savedCount: args.responses.length };
  },
});

/**
 * Get responses for a specific day
 */
export const getDayResponses = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    return responses.map((r) => ({
      questionId: r.question_id,
      responseValue: r.response_value,
      responseNumber: r.response_number,
      responseArray: r.response_array ? JSON.parse(r.response_array) : null,
    }));
  },
});

// ============================================
// User Lookup
// ============================================

/**
 * Get user by username (for Watch login)
 */
export const getUserByUsername = query({
  args: {
    username: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();

    if (!user) {
      return null;
    }

    return {
      userId: user._id,
      username: user.username,
      currentDay: user.current_day,
      onboardingCompleted: user.onboarding_completed ?? false,
      passwordHash: user.password_hash, // For validation on Watch
    };
  },
});

/**
 * Get user's current state (for polling/refresh)
 */
export const getUserState = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get completed days count
    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const completedCount = progress.filter((p) => p.completed).length;

    return {
      currentDay: user.current_day,
      completedDaysCount: completedCount,
      onboardingCompleted: user.onboarding_completed ?? false,
      lastAccessed: user.last_accessed,
    };
  },
});

// ============================================
// Cross-Device Question Progress Sync
// ============================================

/**
 * Get current question progress for a section
 * Returns where the user left off so they can continue on any device
 */
export const getQuestionProgress = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.string(), // "sleepLog" or "assessment"
  },
  handler: async (ctx, args) => {
    const session = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user_day_section", (q) =>
        q.eq("user_id", args.userId)
          .eq("day_number", args.dayNumber)
          .eq("section", args.section)
      )
      .first();

    if (!session) {
      return null;
    }

    return {
      currentQuestionIndex: session.current_question_index,
      totalQuestions: session.total_questions,
      lastDevice: session.last_device,
      lastUpdatedAt: session.last_updated_at,
      completed: session.completed,
    };
  },
});

/**
 * Update question progress when user answers a question
 * Called after each question to enable seamless cross-device sync
 */
export const updateQuestionProgress = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.string(), // "sleepLog" or "assessment"
    currentQuestionIndex: v.number(),
    totalQuestions: v.number(),
    device: v.string(), // "ios", "watch", "web"
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if session exists
    const existingSession = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user_day_section", (q) =>
        q.eq("user_id", args.userId)
          .eq("day_number", args.dayNumber)
          .eq("section", args.section)
      )
      .first();

    if (existingSession) {
      // Update existing session
      await ctx.db.patch(existingSession._id, {
        current_question_index: args.currentQuestionIndex,
        total_questions: args.totalQuestions,
        last_updated_at: now,
        last_device: args.device,
      });
    } else {
      // Create new session
      await ctx.db.insert("questionnaire_session", {
        user_id: args.userId,
        day_number: args.dayNumber,
        section: args.section,
        current_question_index: args.currentQuestionIndex,
        total_questions: args.totalQuestions,
        started_at: now,
        last_updated_at: now,
        last_device: args.device,
        completed: false,
      });
    }

    return { success: true, questionIndex: args.currentQuestionIndex };
  },
});

/**
 * Mark a section as completed in the question progress tracker
 */
export const completeQuestionProgress = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.string(),
    device: v.string(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    const session = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user_day_section", (q) =>
        q.eq("user_id", args.userId)
          .eq("day_number", args.dayNumber)
          .eq("section", args.section)
      )
      .first();

    if (session) {
      await ctx.db.patch(session._id, {
        completed: true,
        completed_at: now,
        last_updated_at: now,
        last_device: args.device,
      });
    }

    return { success: true };
  },
});

/**
 * Get all responses for a user's current day
 * Useful for loading saved responses when continuing on a different device
 */
export const getSavedResponses = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    // Convert to a map of questionId -> response for easy lookup
    const responseMap: Record<string, {
      stringValue?: string;
      numberValue?: number;
      arrayValue?: string[];
    }> = {};

    for (const r of responses) {
      responseMap[r.question_id] = {
        stringValue: r.response_value ?? undefined,
        numberValue: r.response_number ?? undefined,
        arrayValue: r.response_array ? JSON.parse(r.response_array) : undefined,
      };
    }

    return responseMap;
  },
});
