import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

/**
 * Web Authentication Functions
 * Maps Clerk users to Convex users for the web questionnaire
 */

// Generate a random password hash placeholder for Clerk users
// (Clerk handles actual authentication, this is just to satisfy schema requirements)
function generatePlaceholderHash(): string {
  return `clerk_auth_${Date.now()}_${Math.random().toString(36).substring(7)}`;
}

/**
 * Get or create a Convex user from Clerk authentication
 * This is called when a Clerk user first accesses the questionnaire
 */
export const getOrCreateUserByClerk = mutation({
  args: {
    clerkUserId: v.string(),
    email: v.optional(v.string()),
    username: v.optional(v.string()),
    fullName: v.optional(v.string()),
    profilePicture: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // First, try to find existing user by clerk_id
    const existingByClerk = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.clerkUserId))
      .first();

    if (existingByClerk) {
      // Update last_accessed and return existing user
      await ctx.db.patch(existingByClerk._id, {
        last_accessed: Date.now(),
        // Update profile info if provided
        ...(args.fullName && { full_name: args.fullName }),
        ...(args.profilePicture && { profile_picture: args.profilePicture }),
      });
      return { userId: existingByClerk._id, isNew: false };
    }

    // Try to find by email (might have registered via iOS first)
    if (args.email) {
      const existingByEmail = await ctx.db
        .query("users")
        .withIndex("by_email", (q) => q.eq("email", args.email))
        .first();

      if (existingByEmail) {
        // Link Clerk ID to existing user
        await ctx.db.patch(existingByEmail._id, {
          clerk_id: args.clerkUserId,
          oauth_provider: "clerk",
          last_accessed: Date.now(),
          ...(args.fullName && { full_name: args.fullName }),
          ...(args.profilePicture && { profile_picture: args.profilePicture }),
        });
        return { userId: existingByEmail._id, isNew: false };
      }
    }

    // Create new user
    const now = Date.now();
    const username = args.username || args.email?.split("@")[0] || `user_${args.clerkUserId.substring(0, 8)}`;

    // Check if username is taken and make unique if needed
    let finalUsername = username;
    let counter = 1;
    while (true) {
      const existing = await ctx.db
        .query("users")
        .withIndex("by_username", (q) => q.eq("username", finalUsername))
        .first();
      if (!existing) break;
      finalUsername = `${username}${counter}`;
      counter++;
    }

    const userId = await ctx.db.insert("users", {
      username: finalUsername,
      password_hash: generatePlaceholderHash(),
      email: args.email,
      role: "patient",
      current_day: 1,
      started_at: now,
      last_accessed: now,
      created_at: now,
      clerk_id: args.clerkUserId,
      oauth_provider: "clerk",
      full_name: args.fullName,
      profile_picture: args.profilePicture,
      email_verified: true, // Clerk handles email verification
      onboarding_completed: false,
    });

    return { userId, isNew: true };
  },
});

/**
 * Get user by Clerk ID (query version for reading user state)
 */
export const getUserByClerkId = query({
  args: { clerkUserId: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.clerkUserId))
      .first();

    if (!user) return null;

    return {
      _id: user._id,
      username: user.username,
      email: user.email,
      fullName: user.full_name,
      currentDay: user.current_day,
      role: user.role,
      onboardingCompleted: user.onboarding_completed,
      profilePicture: user.profile_picture,
    };
  },
});

/**
 * Get journey state for a user (wrapper around watch.ts getJourneyState)
 * Returns current day, completion status, etc.
 */
export const getWebJourneyState = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return null;

    // Get today's progress
    const dayNumber = user.current_day;

    // Find the day record
    const day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", dayNumber))
      .first();

    // Get progress for current day
    const progress = day
      ? await ctx.db
          .query("user_progress")
          .withIndex("by_user_day", (q) =>
            q.eq("user_id", args.userId).eq("day_id", day._id)
          )
          .first()
      : null;

    // Get all completed days
    const allProgress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("completed"), true))
      .collect();

    const completedDays = allProgress.map((p) => {
      // We need to look up the day number from the day_id
      return p.day_id;
    });

    return {
      currentDay: user.current_day,
      totalDays: 10,
      sleepLogCompleted: progress?.sleep_log_completed ?? false,
      assessmentCompleted: progress?.assessment_completed ?? false,
      onboardingCompleted: user.onboarding_completed ?? false,
      startedAt: user.started_at,
      lastAccessed: user.last_accessed,
    };
  },
});

/**
 * Mark web user onboarding as complete
 */
export const completeWebOnboarding = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, {
      onboarding_completed: true,
      onboarding_completed_at: Date.now(),
    });
    return { success: true };
  },
});

/**
 * Update web user profile from onboarding
 */
export const updateWebUserProfile = mutation({
  args: {
    userId: v.id("users"),
    fullName: v.optional(v.string()),
    birthYear: v.optional(v.number()),
    gender: v.optional(v.string()),
    heightCm: v.optional(v.number()),
    weightKg: v.optional(v.number()),
    measurementSystem: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const updates: Record<string, unknown> = {
      last_accessed: Date.now(),
    };

    if (args.fullName !== undefined) updates.full_name = args.fullName;
    if (args.birthYear !== undefined) updates.birth_year = args.birthYear;
    if (args.gender !== undefined) updates.gender = args.gender;
    if (args.heightCm !== undefined) updates.height_cm = args.heightCm;
    if (args.weightKg !== undefined) updates.weight_kg = args.weightKg;
    if (args.measurementSystem !== undefined) updates.measurement_system = args.measurementSystem;

    await ctx.db.patch(args.userId, updates);
    return { success: true };
  },
});
