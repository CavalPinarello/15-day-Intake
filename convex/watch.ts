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
 *
 * VALIDATION: Ensures responses exist before marking section complete
 * - Sleep Log requires at least 3 responses (minimum viable)
 * - Assessment requires at least 1 response per day
 * - Use skipValidation=true only for debug/testing purposes
 */
export const completeSection = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.union(v.literal("sleepLog"), v.literal("assessment")),
    source: v.optional(v.string()), // "watch" or "iphone" or "web"
    skipValidation: v.optional(v.boolean()), // Debug only - skips response validation
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // VALIDATION: Check that user has actually answered questions
    // unless skipValidation is explicitly true (debug mode only)
    if (!args.skipValidation) {
      // Get all responses for this user and day
      const responses = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_day", (q) =>
          q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
        )
        .collect();

      // Define minimum required responses per section
      // Sleep log has 5 questions - require at least 3 (time-based defaults are auto-filled)
      // Assessment varies by day - require at least 1 to prove user engaged
      const minResponses = args.section === "sleepLog" ? 3 : 1;

      // Filter responses by section (rough heuristic - SL_ prefix for sleep log)
      const sectionResponses = responses.filter(r => {
        const isSleepLog = r.question_id.startsWith("SL_");
        return args.section === "sleepLog" ? isSleepLog : !isSleepLog;
      });

      if (sectionResponses.length < minResponses) {
        throw new Error(
          `Cannot complete ${args.section}: Only ${sectionResponses.length} responses found, ` +
          `minimum ${minResponses} required. Please answer the questions before completing.`
        );
      }

      console.log(`[Convex] Section validation passed: ${sectionResponses.length} responses for ${args.section}`);
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

// ============================================
// Module Metadata with Contextual Explanations
// ============================================

/**
 * Module metadata with explanations for each questionnaire type
 * This helps users understand WHY they're being asked certain questions
 */
const MODULE_METADATA: Record<string, {
  title: string;
  shortTitle: string;
  icon: string;
  estimatedMinutes: number;
  questionCount: number;
  color: string;
  description: string;
  why: string;
  triggeredBy?: string;
}> = {
  // Stanford Sleep Log - Daily
  sleep_log: {
    title: "Daily Sleep Log",
    shortTitle: "Sleep Log",
    icon: "moon.zzz",
    estimatedMinutes: 2,
    questionCount: 5,
    color: "#2196F3", // Blue
    description: "About last night's sleep",
    why: "Recording your subjective sleep perception daily helps us compare it with your wearable data and identify patterns. This takes about 60 seconds."
  },

  // Day 1: Demographics
  core_demographics: {
    title: "Your Profile",
    shortTitle: "Profile",
    icon: "person.circle",
    estimatedMinutes: 3,
    questionCount: 5,
    color: "#9C27B0", // Purple
    description: "Basic information about you",
    why: "Age, sex, height, and weight affect sleep needs. Some of this can be auto-filled from Apple Health."
  },

  // Day 1-5: PSQI (Pittsburgh Sleep Quality Index)
  core_psqi: {
    title: "Sleep Quality Assessment",
    shortTitle: "PSQI",
    icon: "chart.bar",
    estimatedMinutes: 8,
    questionCount: 12,
    color: "#9C27B0",
    description: "Pittsburgh Sleep Quality Index",
    why: "This validated questionnaire measures your sleep quality over the past month. Your score helps us understand the severity of sleep issues and track improvement."
  },

  // Day Assessment Generic
  day_assessment: {
    title: "Day Assessment",
    shortTitle: "Assessment",
    icon: "list.clipboard",
    estimatedMinutes: 5,
    questionCount: 8,
    color: "#9C27B0",
    description: "Daily assessment questions",
    why: "These questions help us understand your unique sleep patterns and any factors affecting your rest."
  },

  // Expansion: ISI (Insomnia Severity Index)
  expansion_isi: {
    title: "Insomnia Assessment",
    shortTitle: "ISI",
    icon: "exclamationmark.triangle",
    estimatedMinutes: 5,
    questionCount: 7,
    color: "#FF9800", // Orange - expansion
    description: "Insomnia Severity Index",
    why: "Based on your earlier responses about difficulty sleeping, this assessment measures insomnia severity. It's a clinically validated tool used worldwide.",
    triggeredBy: "insomnia"
  },

  // Expansion: PHQ-9 (Depression)
  expansion_phq9: {
    title: "Mood Assessment",
    shortTitle: "PHQ-9",
    icon: "heart.text.square",
    estimatedMinutes: 4,
    questionCount: 9,
    color: "#FF9800",
    description: "Patient Health Questionnaire",
    why: "Sleep and mood are closely connected. Based on your response about feeling down, this assessment helps us understand if depression may be affecting your sleep.",
    triggeredBy: "depression"
  },

  // Expansion: GAD-7 (Anxiety)
  expansion_gad7: {
    title: "Anxiety Assessment",
    shortTitle: "GAD-7",
    icon: "brain.head.profile",
    estimatedMinutes: 3,
    questionCount: 7,
    color: "#FF9800",
    description: "Generalized Anxiety Disorder Scale",
    why: "Based on your response about feeling anxious, this assessment helps us understand how anxiety may be impacting your sleep quality.",
    triggeredBy: "anxiety"
  },

  // Expansion: ESS (Epworth Sleepiness Scale)
  expansion_ess: {
    title: "Daytime Sleepiness",
    shortTitle: "ESS",
    icon: "sun.max.fill",
    estimatedMinutes: 4,
    questionCount: 8,
    color: "#FF9800",
    description: "Epworth Sleepiness Scale",
    why: "You mentioned feeling excessively sleepy during the day. This assessment measures daytime sleepiness severity, which may indicate a sleep disorder.",
    triggeredBy: "excessiveSleepiness"
  },

  // Expansion: FSS (Fatigue Severity Scale)
  expansion_fss: {
    title: "Fatigue Assessment",
    shortTitle: "FSS",
    icon: "battery.25",
    estimatedMinutes: 4,
    questionCount: 9,
    color: "#FF9800",
    description: "Fatigue Severity Scale",
    why: "This assessment measures how fatigue affects your daily life and helps distinguish between sleepiness and fatigue.",
    triggeredBy: "excessiveSleepiness"
  },

  // Expansion: STOP-BANG (Sleep Apnea Risk)
  expansion_stop_bang: {
    title: "Sleep Apnea Screening",
    shortTitle: "STOP-BANG",
    icon: "lungs.fill",
    estimatedMinutes: 3,
    questionCount: 8,
    color: "#F44336", // Red - important
    description: "Sleep Apnea Risk Assessment",
    why: "Based on your reports of snoring or breathing pauses, this screening helps determine if you may have sleep apnea and should have a sleep study.",
    triggeredBy: "osa"
  },

  // Expansion: Berlin Questionnaire (OSA)
  expansion_berlin: {
    title: "Sleep Apnea Risk",
    shortTitle: "Berlin",
    icon: "lungs",
    estimatedMinutes: 4,
    questionCount: 10,
    color: "#F44336",
    description: "Berlin Questionnaire for Sleep Apnea",
    why: "This additional screening helps us better assess your risk for obstructive sleep apnea.",
    triggeredBy: "osa"
  },

  // Expansion: BPI (Brief Pain Inventory)
  expansion_bpi: {
    title: "Pain Assessment",
    shortTitle: "BPI",
    icon: "bolt.circle",
    estimatedMinutes: 5,
    questionCount: 11,
    color: "#FF9800",
    description: "Brief Pain Inventory",
    why: "You reported that pain affects your sleep. This assessment helps us understand how pain impacts your daily life and sleep quality.",
    triggeredBy: "pain"
  },

  // Expansion: DBAS-16 (Dysfunctional Beliefs About Sleep)
  expansion_dbas16: {
    title: "Sleep Beliefs",
    shortTitle: "DBAS-16",
    icon: "brain",
    estimatedMinutes: 6,
    questionCount: 16,
    color: "#FF9800",
    description: "Dysfunctional Beliefs and Attitudes about Sleep",
    why: "This assessment identifies unhelpful beliefs about sleep that may be maintaining insomnia. Changing these beliefs is a key part of treatment.",
    triggeredBy: "insomnia"
  },

  // Expansion: MEQ (Morningness-Eveningness Questionnaire)
  expansion_meq: {
    title: "Chronotype Assessment",
    shortTitle: "MEQ",
    icon: "sunrise",
    estimatedMinutes: 6,
    questionCount: 19,
    color: "#FF9800",
    description: "Morningness-Eveningness Questionnaire",
    why: "This assessment determines your natural sleep-wake preference (are you a morning lark or night owl?), which helps optimize your sleep schedule.",
    triggeredBy: "sleepTiming"
  },

  // Expansion: MEDAS (Mediterranean Diet Adherence)
  expansion_medas: {
    title: "Diet Assessment",
    shortTitle: "MEDAS",
    icon: "leaf",
    estimatedMinutes: 5,
    questionCount: 14,
    color: "#4CAF50", // Green
    description: "Mediterranean Diet Adherence Screener",
    why: "You noticed diet affects your sleep. The Mediterranean diet has been shown to improve sleep quality. This assessment helps us make dietary recommendations.",
    triggeredBy: "dietImpact"
  },

  // Expansion: Sleep Hygiene
  expansion_sleep_hygiene: {
    title: "Sleep Habits",
    shortTitle: "Sleep Hygiene",
    icon: "bed.double",
    estimatedMinutes: 5,
    questionCount: 12,
    color: "#FF9800",
    description: "Sleep Hygiene Assessment",
    why: "This assessment identifies behaviors and habits that may be interfering with your sleep quality. Small changes can make a big difference.",
    triggeredBy: "poorSleepQuality"
  },

  // Expansion: PROMIS Cognitive Function
  expansion_promis_cognitive: {
    title: "Cognitive Function",
    shortTitle: "PROMIS-Cog",
    icon: "brain.head.profile",
    estimatedMinutes: 4,
    questionCount: 8,
    color: "#FF9800",
    description: "PROMIS Cognitive Function Short Form",
    why: "You mentioned cognitive issues affecting daily life. This assessment helps us understand how sleep affects your thinking and memory.",
    triggeredBy: "cognitive"
  },
};

/**
 * Get module metadata for display
 * Returns contextual information about a questionnaire section
 */
export const getModuleMetadata = query({
  args: {
    moduleKey: v.string(),
  },
  handler: async (ctx, args) => {
    const metadata = MODULE_METADATA[args.moduleKey];
    if (!metadata) {
      return null;
    }
    return metadata;
  },
});

/**
 * Get metadata for a specific day
 * Returns sleep log and assessment metadata with time estimates
 */
export const getDayMetadata = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    // Get user's triggered gateways to determine if expansion modules apply
    // For now, return basic metadata - gateway logic can be added later

    const sleepLogMeta = MODULE_METADATA.sleep_log;

    // Calculate assessment based on day number
    // Days 1-5: Core assessments (varying lengths)
    // Days 6-15: May include expansion modules
    const dayAssessmentCounts: Record<number, { questions: number; minutes: number }> = {
      1: { questions: 12, minutes: 6 },   // Demographics + initial
      2: { questions: 10, minutes: 5 },   // PSQI Part 1
      3: { questions: 10, minutes: 5 },   // PSQI Part 2
      4: { questions: 8, minutes: 4 },    // Sleep patterns
      5: { questions: 8, minutes: 4 },    // Health factors
      6: { questions: 10, minutes: 5 },   // May include ISI
      7: { questions: 8, minutes: 4 },
      8: { questions: 12, minutes: 6 },   // May include PHQ-9, GAD-7
      9: { questions: 10, minutes: 5 },   // May include ESS
      10: { questions: 12, minutes: 6 },  // May include STOP-BANG
      11: { questions: 8, minutes: 4 },
      12: { questions: 10, minutes: 5 },  // May include MEQ
      13: { questions: 8, minutes: 4 },   // May include MEDAS
      14: { questions: 6, minutes: 3 },
      15: { questions: 8, minutes: 4 },   // Final review
    };

    const dayData = dayAssessmentCounts[args.dayNumber] || { questions: 8, minutes: 4 };

    return {
      sleepLog: {
        ...sleepLogMeta,
        isCompleted: false, // Will be set by client based on progress
      },
      assessment: {
        title: `Day ${args.dayNumber} Assessment`,
        shortTitle: `Day ${args.dayNumber}`,
        icon: "list.clipboard",
        estimatedMinutes: dayData.minutes,
        questionCount: dayData.questions,
        color: "#9C27B0",
        description: getDayDescription(args.dayNumber),
        why: getDayExplanation(args.dayNumber),
        isCompleted: false,
      },
      totalMinutes: sleepLogMeta.estimatedMinutes + dayData.minutes,
      totalQuestions: sleepLogMeta.questionCount + dayData.questions,
      triggeredExpansions: [], // Would be populated based on gateway states
    };
  },
});

/**
 * Get description for a specific day's assessment
 */
function getDayDescription(dayNumber: number): string {
  const descriptions: Record<number, string> = {
    1: "Demographics & Sleep Quality",
    2: "Sleep Patterns & History",
    3: "Mental Health Screening",
    4: "Physical Health Factors",
    5: "Lifestyle & Environment",
    6: "Insomnia Deep Dive",
    7: "Sleep Timing",
    8: "Mood & Anxiety",
    9: "Daytime Function",
    10: "Sleep Apnea Screening",
    11: "Pain & Discomfort",
    12: "Circadian Rhythm",
    13: "Diet & Sleep",
    14: "Sleep Beliefs",
    15: "Final Review",
  };
  return descriptions[dayNumber] || "Daily Assessment";
}

/**
 * Get explanation for why this day's questions matter
 */
function getDayExplanation(dayNumber: number): string {
  const explanations: Record<number, string> = {
    1: "We're getting to know you and establishing your baseline sleep quality. This helps us personalize your journey.",
    2: "Understanding your sleep history and patterns helps us identify what might be causing your sleep issues.",
    3: "Sleep and mental health are closely connected. These questions help us see the full picture.",
    4: "Physical health factors can significantly impact sleep. We're checking for anything that might be relevant.",
    5: "Your environment and daily habits play a big role in sleep quality. Let's see what might need adjustment.",
    6: "Based on your responses, we're taking a deeper look at insomnia symptoms and their impact.",
    7: "Your natural sleep-wake cycle affects when you sleep best. We're assessing your chronotype.",
    8: "We're checking in on mood and anxiety, which can significantly affect sleep quality.",
    9: "Daytime sleepiness and energy levels tell us important things about your sleep quality.",
    10: "We're screening for sleep apnea, a common but often undiagnosed condition that affects sleep.",
    11: "Pain and physical discomfort can disrupt sleep. We're assessing if this applies to you.",
    12: "Your body clock affects when you feel sleepy and alert. Understanding this helps optimize your schedule.",
    13: "What you eat can affect how you sleep. We're looking at dietary factors.",
    14: "Sometimes our beliefs about sleep can make problems worse. We're identifying any unhelpful patterns.",
    15: "We're wrapping up your assessment and preparing your personalized recommendations.",
  };
  return explanations[dayNumber] || "These questions help us understand your unique sleep needs.";
}
