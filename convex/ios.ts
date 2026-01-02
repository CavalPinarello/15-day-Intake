/**
 * iOS-Specific Convex Functions
 *
 * This file contains all Convex functions optimized for direct iOS app usage.
 * The iOS app should call these functions directly using the Convex Swift SDK.
 *
 * SECURITY: All mutations that modify user data require session token validation
 * to prevent unauthorized access.
 */

import { query, mutation, action, QueryCtx, MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { validateIOSSession, validateUserOwnership } from "./auth";
import { FIXED_SCHEDULE, PACK_TO_MODULE_IDS, shouldShowExpansion, type DayConfig } from "./fixedSchedule";

// ============================================
// Module to Question Prefix Mapping
// ============================================
// Maps expansion module IDs to their actual question ID prefixes.
// This is needed because module names don't always match question prefixes
// (e.g., "expansion_promis_cognitive" has questions like "PROMIS_COG_1", not "PROMIS_COGNITIVE_1")
const MODULE_TO_QUESTION_PREFIX: Record<string, string> = {
  // Day 6: Insomnia + Shift Work
  expansion_isi: "ISI_",
  expansion_swdsq: "SWDSQ_",
  // Day 7: Depression + Cognitive
  expansion_phq9: "PHQ9_",
  expansion_promis_cognitive: "PROMIS_COG_", // Not PROMIS_COGNITIVE_!
  // Day 8: Anxiety + Sleep Hygiene
  expansion_gad7: "GAD7_",
  expansion_sleep_hygiene_part1: "SH_",
  expansion_sleep_hygiene_part2: "SH_",
  // Day 9: OSA
  expansion_stop_bang: "SB_", // Not STOP_BANG_!
  // Day 10: Excessive Sleepiness
  expansion_ess: "ESS_",
  expansion_fss: "FSS_",
  // Day 11: Beliefs + Pain
  expansion_dbas6: "DBAS_", // Not DBAS6_!
  expansion_bpi_part1: "BPI_",
  // Day 12: Pain Impact
  expansion_bpi_part2: "BPI_",
  // Day 13: Arousal + Function
  expansion_psas_cognitive: "PSAS_",
  expansion_psas_somatic: "PSAS_",
  expansion_fosq_part1: "FOSQ_",
  expansion_fosq_part2: "FOSQ_",
  // Day 14: Diet + Chronotype
  expansion_medas: "MEDAS_",
  expansion_meq_part1: "MEQ_",
  expansion_meq_part2: "MEQ_",
};

// ============================================
// Inline Helper Functions (avoids internal.xxx bootstrap issues)
// ============================================

interface QuestionResult {
  question_id: string;
  question_text: string;
  help_text?: string;
  pillar: string;
  tier: string;
  answer_format: string;
  format_config: string;
  validation_rules?: string;
  conditional_logic?: string;
  order_index?: number;
  estimated_time_seconds: number;
  module_id: string;
  module_name: string;
}

/**
 * Inline helper to get questions by day (avoids internal.xxx bootstrap issues)
 */
async function getQuestionsByDayHelper(ctx: QueryCtx, dayNumber: number): Promise<QuestionResult[]> {
  const dayModules = await ctx.db
    .query("day_modules")
    .withIndex("by_day", (q) => q.eq("day_number", dayNumber))
    .collect();

  const result: QuestionResult[] = [];

  for (const dayModule of dayModules) {
    const module = await ctx.db
      .query("assessment_modules")
      .withIndex("by_module_id", (q) => q.eq("module_id", dayModule.module_id))
      .first();

    if (!module) continue;

    const moduleQuestions = await ctx.db
      .query("module_questions")
      .withIndex("by_module", (q) => q.eq("module_id", dayModule.module_id))
      .collect();

    moduleQuestions.sort((a, b) => a.order_index - b.order_index);

    for (const mq of moduleQuestions) {
      const question = await ctx.db
        .query("assessment_questions")
        .withIndex("by_question_id", (q) => q.eq("question_id", mq.question_id))
        .first();

      if (question) {
        result.push({
          question_id: question.question_id,
          question_text: question.question_text,
          help_text: question.help_text,
          pillar: question.pillar,
          tier: question.tier,
          answer_format: question.answer_format,
          format_config: question.format_config,
          validation_rules: question.validation_rules ?? undefined,
          conditional_logic: question.conditional_logic ?? undefined,
          order_index: mq.order_index,
          estimated_time_seconds: question.estimated_time_seconds,
          module_id: dayModule.module_id,
          module_name: module.name
        });
      }
    }
  }

  return result;
}

interface SaveResponseArgs {
  userId: Id<"users">;
  questionId: string;
  answerFormat: string;
  value: string | number | null;
  arrayValue?: string[];
  objectValue?: string;
  responseUnit?: string;
  dayNumber?: number;
  answeredInSeconds?: number;
}

/**
 * Inline helper to save response (avoids internal.xxx bootstrap issues)
 */
async function saveResponseHelper(
  ctx: MutationCtx,
  args: SaveResponseArgs
): Promise<Id<"user_assessment_responses">> {
  const startTime = Date.now();

  let existing;
  if (args.dayNumber !== undefined) {
    existing = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question_day", (q) =>
        q.eq("user_id", args.userId).eq("question_id", args.questionId).eq("day_number", args.dayNumber)
      )
      .first();
  } else {
    existing = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", args.questionId)
      )
      .first();
  }

  let responseData: {
    response_value?: string;
    response_number?: number;
    response_array?: string;
    response_object?: string;
    response_unit?: string;
  } = {};

  // Include unit if provided
  if (args.responseUnit) {
    responseData.response_unit = args.responseUnit;
  }

  switch (args.answerFormat) {
    case "time_picker":
    case "single_select_chips":
    case "date_picker":
      responseData.response_value =
        typeof args.value === "string" ? args.value : undefined;
      break;
    case "minutes_scroll":
    case "number_scroll":
    case "slider_scale":
    case "number_input":
      responseData.response_number =
        typeof args.value === "number"
          ? args.value
          : typeof args.value === "string"
          ? parseFloat(args.value)
          : undefined;
      break;
    case "multi_select_chips":
      responseData.response_array = args.arrayValue
        ? JSON.stringify(args.arrayValue)
        : undefined;
      break;
    case "repeating_group":
      responseData.response_object = args.objectValue;
      break;
    default:
      throw new Error(`Unknown answer format: ${args.answerFormat}`);
  }

  if (existing) {
    await ctx.db.patch(existing._id, {
      ...responseData,
      day_number: args.dayNumber,
      answered_in_seconds:
        args.answeredInSeconds ||
        Math.floor((Date.now() - startTime) / 1000),
      updated_at: Date.now()
    });
    return existing._id;
  } else {
    return await ctx.db.insert("user_assessment_responses", {
      user_id: args.userId,
      question_id: args.questionId,
      ...responseData,
      day_number: args.dayNumber,
      answered_in_seconds:
        args.answeredInSeconds ||
        Math.floor((Date.now() - startTime) / 1000),
      created_at: Date.now(),
      updated_at: Date.now()
    });
  }
}

/**
 * Inline helper to mark day complete (avoids internal.xxx bootstrap issues)
 */
async function markDayCompleteHelper(
  ctx: MutationCtx,
  args: { userId: Id<"users">; dayNumber: number }
): Promise<Id<"user_progress">> {
  const day = await ctx.db
    .query("days")
    .withIndex("by_day_number", (q) => q.eq("day_number", args.dayNumber))
    .first();

  if (!day) {
    throw new Error(`Day ${args.dayNumber} not found`);
  }

  const existing = await ctx.db
    .query("user_progress")
    .withIndex("by_user_day", (q) =>
      q.eq("user_id", args.userId).eq("day_id", day._id)
    )
    .first();

  if (existing) {
    await ctx.db.patch(existing._id, {
      completed: true,
      completed_at: Date.now()
    });
    return existing._id;
  } else {
    return await ctx.db.insert("user_progress", {
      user_id: args.userId,
      day_id: day._id,
      completed: true,
      completed_at: Date.now(),
      created_at: Date.now()
    });
  }
}

// ============================================
// iOS Authentication Functions
// ============================================

/**
 * Sign in with email/username and password
 * Returns user data and session token
 */
export const signIn = mutation({
  args: {
    identifier: v.string(), // email or username
    passwordHash: v.string(), // Pre-hashed on client for security
    deviceId: v.string(),
    deviceInfo: v.optional(v.object({
      deviceName: v.optional(v.string()),
      deviceModel: v.optional(v.string()),
      osVersion: v.optional(v.string()),
      appVersion: v.optional(v.string()),
    })),
  },
  handler: async (ctx, args) => {
    // Find user by username or email
    let user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.identifier))
      .first();

    if (!user) {
      user = await ctx.db
        .query("users")
        .withIndex("by_email", (q) => q.eq("email", args.identifier))
        .first();
    }

    if (!user) {
      throw new Error("User not found");
    }

    // Verify password (compare hashes)
    if (user.password_hash !== args.passwordHash) {
      throw new Error("Invalid password");
    }

    // Generate session token
    const sessionToken = generateSessionToken();
    const now = Date.now();
    const expiresAt = now + (30 * 24 * 60 * 60 * 1000); // 30 days

    // Create iOS session
    await ctx.db.insert("ios_sessions", {
      user_id: user._id,
      session_token: sessionToken,
      device_id: args.deviceId,
      expires_at: expiresAt,
      created_at: now,
      last_refreshed_at: now,
      is_active: true,
    });

    // Update or create device record
    const existingDevice = await ctx.db
      .query("ios_devices")
      .withIndex("by_device_id", (q) => q.eq("device_id", args.deviceId))
      .first();

    if (existingDevice) {
      await ctx.db.patch(existingDevice._id, {
        user_id: user._id,
        last_active_at: now,
        ...(args.deviceInfo && {
          device_name: args.deviceInfo.deviceName,
          device_model: args.deviceInfo.deviceModel,
          os_version: args.deviceInfo.osVersion,
          app_version: args.deviceInfo.appVersion,
        }),
      });
    }

    // Update user last accessed
    await ctx.db.patch(user._id, {
      last_accessed: now,
    });

    return {
      userId: user._id,
      sessionToken,
      expiresAt,
      user: {
        username: user.username,
        email: user.email,
        currentDay: user.current_day,
        role: user.role,
        onboardingCompleted: user.onboarding_completed,
        appleHealthConnected: user.apple_health_connected,
        // Profile data - essential for user isolation
        fullName: user.full_name,
        measurementSystem: user.measurement_system,
        heightCm: user.height_cm,
        weightKg: user.weight_kg,
        gender: user.gender,
        birthYear: user.birth_year,
      },
    };
  },
});

/**
 * Sign in with Apple
 */
export const signInWithApple = mutation({
  args: {
    appleUserId: v.string(),
    identityToken: v.string(),
    email: v.optional(v.string()),
    fullName: v.optional(v.string()),
    deviceId: v.string(),
    deviceInfo: v.optional(v.object({
      deviceName: v.optional(v.string()),
      deviceModel: v.optional(v.string()),
      osVersion: v.optional(v.string()),
      appVersion: v.optional(v.string()),
    })),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if this Apple user already exists
    let appleSignIn = await ctx.db
      .query("apple_sign_in")
      .withIndex("by_apple_user_id", (q) => q.eq("apple_user_id", args.appleUserId))
      .first();

    let user;

    if (appleSignIn) {
      // Existing Apple Sign-In user
      user = await ctx.db.get(appleSignIn.user_id);
      if (!user) {
        throw new Error("User account not found");
      }

      // Update last sign in
      await ctx.db.patch(appleSignIn._id, {
        last_sign_in_at: now,
        identity_token_hash: hashToken(args.identityToken),
      });
    } else {
      // New Apple Sign-In user - create account
      const username = args.email?.split("@")[0] || `apple_${args.appleUserId.slice(0, 8)}`;

      // Create user
      const userId = await ctx.db.insert("users", {
        username,
        password_hash: "", // No password for Apple Sign-In
        email: args.email,
        oauth_provider: "apple",
        oauth_id: args.appleUserId,
        current_day: 1,
        started_at: now,
        last_accessed: now,
        created_at: now,
        email_verified: true, // Apple verifies email
        role: "patient",
      });

      user = await ctx.db.get(userId);

      // Create Apple Sign-In record
      await ctx.db.insert("apple_sign_in", {
        user_id: userId,
        apple_user_id: args.appleUserId,
        email: args.email,
        full_name: args.fullName,
        identity_token_hash: hashToken(args.identityToken),
        created_at: now,
        last_sign_in_at: now,
      });
    }

    if (!user) {
      throw new Error("Failed to create user");
    }

    // Generate session token
    const sessionToken = generateSessionToken();
    const expiresAt = now + (30 * 24 * 60 * 60 * 1000); // 30 days

    // Create iOS session
    await ctx.db.insert("ios_sessions", {
      user_id: user._id,
      session_token: sessionToken,
      device_id: args.deviceId,
      expires_at: expiresAt,
      created_at: now,
      last_refreshed_at: now,
      is_active: true,
    });

    // Update or create device record
    const existingDevice = await ctx.db
      .query("ios_devices")
      .withIndex("by_device_id", (q) => q.eq("device_id", args.deviceId))
      .first();

    if (!existingDevice) {
      await ctx.db.insert("ios_devices", {
        user_id: user._id,
        device_token: "", // Will be set when push notifications registered
        device_id: args.deviceId,
        device_name: args.deviceInfo?.deviceName,
        device_model: args.deviceInfo?.deviceModel,
        os_version: args.deviceInfo?.osVersion,
        app_version: args.deviceInfo?.appVersion,
        push_enabled: false,
        last_active_at: now,
        created_at: now,
      });
    }

    // Update user last accessed
    await ctx.db.patch(user._id, {
      last_accessed: now,
    });

    return {
      userId: user._id,
      sessionToken,
      expiresAt,
      isNewUser: !appleSignIn,
      user: {
        username: user.username,
        email: user.email,
        currentDay: user.current_day,
        role: user.role,
        onboardingCompleted: user.onboarding_completed,
        appleHealthConnected: user.apple_health_connected,
        // Profile data - essential for user isolation
        fullName: user.full_name,
        measurementSystem: user.measurement_system,
        heightCm: user.height_cm,
        weightKg: user.weight_kg,
        gender: user.gender,
        birthYear: user.birth_year,
      },
    };
  },
});

/**
 * Register new user
 */
export const register = mutation({
  args: {
    email: v.string(),
    passwordHash: v.string(),
    deviceId: v.string(),
    deviceInfo: v.optional(v.object({
      deviceName: v.optional(v.string()),
      deviceModel: v.optional(v.string()),
      osVersion: v.optional(v.string()),
      appVersion: v.optional(v.string()),
    })),
  },
  handler: async (ctx, args) => {
    // Check if email exists
    const existingEmail = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();

    if (existingEmail) {
      throw new Error("An account with this email already exists");
    }

    // Auto-generate username from email (part before @)
    const baseUsername = args.email.split("@")[0].toLowerCase().replace(/[^a-z0-9]/g, "");
    let username = baseUsername;

    // Ensure username is unique by adding random suffix if needed
    let existingUsername = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();

    if (existingUsername) {
      // Add random 4-digit suffix
      username = `${baseUsername}${Math.floor(1000 + Math.random() * 9000)}`;
    }

    const now = Date.now();

    // Create user
    const userId = await ctx.db.insert("users", {
      username: username,
      password_hash: args.passwordHash,
      email: args.email,
      current_day: 1,
      started_at: now,
      last_accessed: now,
      created_at: now,
      email_verified: false,
      role: "patient",
    });

    // Generate session token
    const sessionToken = generateSessionToken();
    const expiresAt = now + (30 * 24 * 60 * 60 * 1000); // 30 days

    // Create iOS session
    await ctx.db.insert("ios_sessions", {
      user_id: userId,
      session_token: sessionToken,
      device_id: args.deviceId,
      expires_at: expiresAt,
      created_at: now,
      last_refreshed_at: now,
      is_active: true,
    });

    // Create device record
    await ctx.db.insert("ios_devices", {
      user_id: userId,
      device_token: "",
      device_id: args.deviceId,
      device_name: args.deviceInfo?.deviceName,
      device_model: args.deviceInfo?.deviceModel,
      os_version: args.deviceInfo?.osVersion,
      app_version: args.deviceInfo?.appVersion,
      push_enabled: false,
      last_active_at: now,
      created_at: now,
    });

    return {
      userId,
      sessionToken,
      expiresAt,
      user: {
        username: username,
        email: args.email,
        currentDay: 1,
        role: "patient",
        onboardingCompleted: false,
        appleHealthConnected: false,
      },
    };
  },
});

/**
 * Validate session token
 */
export const validateSession = query({
  args: {
    sessionToken: v.string(),
  },
  handler: async (ctx, args) => {
    const session = await ctx.db
      .query("ios_sessions")
      .withIndex("by_session_token", (q) => q.eq("session_token", args.sessionToken))
      .first();

    if (!session) {
      return { valid: false, reason: "Session not found" };
    }

    if (!session.is_active) {
      return { valid: false, reason: "Session inactive" };
    }

    if (session.expires_at < Date.now()) {
      return { valid: false, reason: "Session expired" };
    }

    const user = await ctx.db.get(session.user_id);
    if (!user) {
      return { valid: false, reason: "User not found" };
    }

    return {
      valid: true,
      userId: user._id,
      user: {
        username: user.username,
        email: user.email,
        currentDay: user.current_day,
        role: user.role,
        onboardingCompleted: user.onboarding_completed,
        appleHealthConnected: user.apple_health_connected,
        // Profile data
        fullName: user.full_name,
        measurementSystem: user.measurement_system,
        heightCm: user.height_cm,
        weightKg: user.weight_kg,
        gender: user.gender,
        birthYear: user.birth_year,
      },
    };
  },
});

/**
 * Sign out - invalidate session
 */
export const signOut = mutation({
  args: {
    sessionToken: v.string(),
  },
  handler: async (ctx, args) => {
    const session = await ctx.db
      .query("ios_sessions")
      .withIndex("by_session_token", (q) => q.eq("session_token", args.sessionToken))
      .first();

    if (session) {
      await ctx.db.patch(session._id, {
        is_active: false,
      });
    }

    return { success: true };
  },
});

/**
 * Refresh session
 */
export const refreshSession = mutation({
  args: {
    sessionToken: v.string(),
  },
  handler: async (ctx, args) => {
    const session = await ctx.db
      .query("ios_sessions")
      .withIndex("by_session_token", (q) => q.eq("session_token", args.sessionToken))
      .first();

    if (!session || !session.is_active) {
      throw new Error("Invalid session");
    }

    const now = Date.now();
    const newExpiresAt = now + (30 * 24 * 60 * 60 * 1000); // 30 days

    await ctx.db.patch(session._id, {
      expires_at: newExpiresAt,
      last_refreshed_at: now,
    });

    return {
      sessionToken: args.sessionToken,
      expiresAt: newExpiresAt,
    };
  },
});

// ============================================
// iOS Device Management
// ============================================

/**
 * Register device for push notifications
 */
export const registerPushToken = mutation({
  args: {
    sessionToken: v.string(),
    deviceToken: v.string(),
    deviceId: v.string(),
  },
  handler: async (ctx, args) => {
    const session = await ctx.db
      .query("ios_sessions")
      .withIndex("by_session_token", (q) => q.eq("session_token", args.sessionToken))
      .first();

    if (!session || !session.is_active) {
      throw new Error("Invalid session");
    }

    const device = await ctx.db
      .query("ios_devices")
      .withIndex("by_device_id", (q) => q.eq("device_id", args.deviceId))
      .first();

    if (device) {
      await ctx.db.patch(device._id, {
        device_token: args.deviceToken,
        push_enabled: true,
        last_active_at: Date.now(),
      });
    } else {
      await ctx.db.insert("ios_devices", {
        user_id: session.user_id,
        device_token: args.deviceToken,
        device_id: args.deviceId,
        push_enabled: true,
        last_active_at: Date.now(),
        created_at: Date.now(),
      });
    }

    return { success: true };
  },
});

// ============================================
// iOS User Profile Functions
// ============================================

/**
 * Get user profile
 */
export const getUserProfile = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get user preferences
    const preferences = await ctx.db
      .query("user_preferences")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    return {
      userId: user._id,
      username: user.username,
      email: user.email,
      currentDay: user.current_day,
      startedAt: user.started_at,
      role: user.role,
      onboardingCompleted: user.onboarding_completed,
      appleHealthConnected: user.apple_health_connected,
      profilePicture: user.profile_picture,
      preferences: preferences ? {
        notificationEnabled: preferences.notification_enabled,
        notificationTime: preferences.notification_time,
        quietHoursStart: preferences.quiet_hours_start,
        quietHoursEnd: preferences.quiet_hours_end,
        timezone: preferences.timezone,
        appleHealthSyncEnabled: preferences.apple_health_sync_enabled,
        dailyReminderEnabled: preferences.daily_reminder_enabled,
      } : null,
    };
  },
});

/**
 * Update user profile
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const updateUserProfile = mutation({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()), // Required for authorization (optional for backward compat)
    updates: v.object({
      email: v.optional(v.string()),
      profilePicture: v.optional(v.string()),
      appleHealthConnected: v.optional(v.boolean()),
      // Profile fields from onboarding
      onboardingCompleted: v.optional(v.boolean()),
      displayName: v.optional(v.string()),
      measurementSystem: v.optional(v.string()),
      heightCm: v.optional(v.number()),
      weightKg: v.optional(v.number()),
      gender: v.optional(v.string()),
      birthYear: v.optional(v.number()),
      wearables: v.optional(v.array(v.string())),
    }),
  },
  handler: async (ctx, args) => {
    // Validate session and ownership if token provided
    if (args.sessionToken) {
      const session = await validateUserOwnership(ctx, args.sessionToken, args.userId);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized");
      }
    }

    const updateData: Record<string, unknown> = {};

    if (args.updates.email !== undefined) {
      updateData.email = args.updates.email;
    }
    if (args.updates.profilePicture !== undefined) {
      updateData.profile_picture = args.updates.profilePicture;
    }
    if (args.updates.appleHealthConnected !== undefined) {
      updateData.apple_health_connected = args.updates.appleHealthConnected;
    }
    // Profile fields from onboarding
    if (args.updates.onboardingCompleted !== undefined) {
      updateData.onboarding_completed = args.updates.onboardingCompleted;
      if (args.updates.onboardingCompleted) {
        updateData.onboarding_completed_at = Date.now();
      }
    }
    if (args.updates.displayName !== undefined) {
      updateData.full_name = args.updates.displayName;
    }
    if (args.updates.measurementSystem !== undefined) {
      updateData.measurement_system = args.updates.measurementSystem;
    }
    if (args.updates.heightCm !== undefined) {
      updateData.height_cm = args.updates.heightCm;
    }
    if (args.updates.weightKg !== undefined) {
      updateData.weight_kg = args.updates.weightKg;
    }
    if (args.updates.gender !== undefined) {
      updateData.gender = args.updates.gender;
    }
    if (args.updates.birthYear !== undefined) {
      updateData.birth_year = args.updates.birthYear;
    }

    await ctx.db.patch(args.userId, updateData);

    // Check if demographic fields changed - if so, re-inject demographic responses
    const demographicFieldsChanged =
      args.updates.heightCm !== undefined ||
      args.updates.weightKg !== undefined ||
      args.updates.gender !== undefined ||
      args.updates.birthYear !== undefined ||
      args.updates.onboardingCompleted === true;

    if (demographicFieldsChanged) {
      // Inject/update demographic responses to ensure scoring calculations have correct data
      try {
        await ctx.runMutation(api.profileResponses.injectDemographicResponses, {
          userId: args.userId,
          dayNumber: 1,
        });
        console.log(`[ios:updateUserProfile] Injected demographic responses for user ${args.userId}`);
      } catch (error) {
        // Log but don't fail the profile update
        console.error(`[ios:updateUserProfile] Failed to inject demographic responses:`, error);
      }
    }

    return { success: true };
  },
});

/**
 * Update user preferences
 */
export const updateUserPreferences = mutation({
  args: {
    userId: v.id("users"),
    preferences: v.object({
      notificationEnabled: v.optional(v.boolean()),
      notificationTime: v.optional(v.string()),
      quietHoursStart: v.optional(v.string()),
      quietHoursEnd: v.optional(v.string()),
      timezone: v.optional(v.string()),
      appleHealthSyncEnabled: v.optional(v.boolean()),
      dailyReminderEnabled: v.optional(v.boolean()),
    }),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("user_preferences")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const now = Date.now();

    if (existing) {
      await ctx.db.patch(existing._id, {
        ...(args.preferences.notificationEnabled !== undefined && {
          notification_enabled: args.preferences.notificationEnabled,
        }),
        ...(args.preferences.notificationTime !== undefined && {
          notification_time: args.preferences.notificationTime,
        }),
        ...(args.preferences.quietHoursStart !== undefined && {
          quiet_hours_start: args.preferences.quietHoursStart,
        }),
        ...(args.preferences.quietHoursEnd !== undefined && {
          quiet_hours_end: args.preferences.quietHoursEnd,
        }),
        ...(args.preferences.timezone !== undefined && {
          timezone: args.preferences.timezone,
        }),
        ...(args.preferences.appleHealthSyncEnabled !== undefined && {
          apple_health_sync_enabled: args.preferences.appleHealthSyncEnabled,
        }),
        ...(args.preferences.dailyReminderEnabled !== undefined && {
          daily_reminder_enabled: args.preferences.dailyReminderEnabled,
        }),
        updated_at: now,
      });
    } else {
      await ctx.db.insert("user_preferences", {
        user_id: args.userId,
        notification_enabled: args.preferences.notificationEnabled ?? true,
        notification_time: args.preferences.notificationTime ?? "21:00",
        quiet_hours_start: args.preferences.quietHoursStart ?? "22:00",
        quiet_hours_end: args.preferences.quietHoursEnd ?? "07:00",
        timezone: args.preferences.timezone ?? "America/New_York",
        apple_health_sync_enabled: args.preferences.appleHealthSyncEnabled ?? true,
        daily_reminder_enabled: args.preferences.dailyReminderEnabled ?? true,
        updated_at: now,
      });
    }

    return { success: true };
  },
});

// ============================================
// iOS HealthKit Sync Functions
// ============================================

/**
 * Sync sleep data from HealthKit
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const syncSleepData = mutation({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()), // Session token for authorization
    deviceId: v.string(),
    sleepData: v.array(v.object({
      date: v.string(), // YYYY-MM-DD
      inBedTime: v.optional(v.number()), // Unix timestamp (ms)
      asleepTime: v.optional(v.number()), // Unix timestamp (ms)
      wakeTime: v.optional(v.number()), // Unix timestamp (ms)
      totalSleepMins: v.optional(v.number()),
      sleepEfficiency: v.optional(v.number()),
      deepSleepMins: v.optional(v.number()),
      lightSleepMins: v.optional(v.number()),
      remSleepMins: v.optional(v.number()),
      awakeMins: v.optional(v.number()),
      interruptionsCount: v.optional(v.number()),
      sleepLatencyMins: v.optional(v.number()),
      // Source tracking fields
      primarySource: v.optional(v.string()), // "Apple Watch", "Oura", etc.
      sourceBundleId: v.optional(v.string()),
      allSourcesJson: v.optional(v.string()), // JSON array of source names
      isMultiSource: v.optional(v.boolean()),
    })),
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateUserOwnership(ctx, args.sessionToken, args.userId);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized");
      }
    }

    const now = Date.now();
    let recordsSynced = 0;

    for (const data of args.sleepData) {
      // Check if record exists for this date
      const existing = await ctx.db
        .query("user_sleep_data")
        .withIndex("by_user_date", (q) =>
          q.eq("user_id", args.userId).eq("date", data.date)
        )
        .first();

      if (existing) {
        await ctx.db.patch(existing._id, {
          in_bed_time: data.inBedTime,
          asleep_time: data.asleepTime,
          wake_time: data.wakeTime,
          total_sleep_mins: data.totalSleepMins,
          sleep_efficiency: data.sleepEfficiency,
          deep_sleep_mins: data.deepSleepMins,
          light_sleep_mins: data.lightSleepMins,
          rem_sleep_mins: data.remSleepMins,
          awake_mins: data.awakeMins,
          interruptions_count: data.interruptionsCount,
          sleep_latency_mins: data.sleepLatencyMins,
          synced_at: now,
          // Source tracking fields
          primary_source: data.primarySource,
          source_bundle_id: data.sourceBundleId,
          all_sources_json: data.allSourcesJson,
          is_multi_source: data.isMultiSource,
        });
      } else {
        await ctx.db.insert("user_sleep_data", {
          user_id: args.userId,
          date: data.date,
          in_bed_time: data.inBedTime,
          asleep_time: data.asleepTime,
          wake_time: data.wakeTime,
          total_sleep_mins: data.totalSleepMins,
          sleep_efficiency: data.sleepEfficiency,
          deep_sleep_mins: data.deepSleepMins,
          light_sleep_mins: data.lightSleepMins,
          rem_sleep_mins: data.remSleepMins,
          awake_mins: data.awakeMins,
          interruptions_count: data.interruptionsCount,
          sleep_latency_mins: data.sleepLatencyMins,
          synced_at: now,
          // Source tracking fields
          primary_source: data.primarySource,
          source_bundle_id: data.sourceBundleId,
          all_sources_json: data.allSourcesJson,
          is_multi_source: data.isMultiSource,
        });
      }
      recordsSynced++;
    }

    // Update sync status
    const syncRecord = await ctx.db
      .query("ios_healthkit_sync")
      .withIndex("by_user_device", (q) =>
        q.eq("user_id", args.userId).eq("device_id", args.deviceId)
      )
      .first();

    if (syncRecord) {
      await ctx.db.patch(syncRecord._id, {
        last_sync_at: now,
        sync_status: "success",
        data_types_synced: JSON.stringify(["sleep"]),
        records_synced: recordsSynced,
      });
    } else {
      await ctx.db.insert("ios_healthkit_sync", {
        user_id: args.userId,
        device_id: args.deviceId,
        last_sync_at: now,
        sync_status: "success",
        data_types_synced: JSON.stringify(["sleep"]),
        records_synced: recordsSynced,
      });
    }

    // Update user's apple_health_connected flag
    await ctx.db.patch(args.userId, {
      apple_health_connected: true,
    });

    return { success: true, recordsSynced };
  },
});

/**
 * Sync heart rate data from HealthKit
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const syncHeartRateData = mutation({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()), // Session token for authorization
    deviceId: v.string(),
    heartRateData: v.array(v.object({
      date: v.string(),
      restingHr: v.optional(v.number()),
      avgHr: v.optional(v.number()),
      hrvMorning: v.optional(v.number()),
      hrvAvg: v.optional(v.number()),
    })),
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateUserOwnership(ctx, args.sessionToken, args.userId);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized");
      }
    }

    const now = Date.now();
    let recordsSynced = 0;

    for (const data of args.heartRateData) {
      const existing = await ctx.db
        .query("user_heart_rate")
        .withIndex("by_user_date", (q) =>
          q.eq("user_id", args.userId).eq("date", data.date)
        )
        .first();

      if (existing) {
        await ctx.db.patch(existing._id, {
          resting_hr: data.restingHr,
          avg_hr: data.avgHr,
          hrv_morning: data.hrvMorning,
          hrv_avg: data.hrvAvg,
          synced_at: now,
        });
      } else {
        await ctx.db.insert("user_heart_rate", {
          user_id: args.userId,
          date: data.date,
          resting_hr: data.restingHr,
          avg_hr: data.avgHr,
          hrv_morning: data.hrvMorning,
          hrv_avg: data.hrvAvg,
          synced_at: now,
        });
      }
      recordsSynced++;
    }

    return { success: true, recordsSynced };
  },
});

/**
 * Sync activity data from HealthKit
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const syncActivityData = mutation({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()), // Session token for authorization
    deviceId: v.string(),
    activityData: v.array(v.object({
      date: v.string(),
      steps: v.optional(v.number()),
      activeMins: v.optional(v.number()),
      exerciseMins: v.optional(v.number()),
      caloriesBurned: v.optional(v.number()),
    })),
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateUserOwnership(ctx, args.sessionToken, args.userId);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized");
      }
    }

    const now = Date.now();
    let recordsSynced = 0;

    for (const data of args.activityData) {
      const existing = await ctx.db
        .query("user_activity")
        .withIndex("by_user_date", (q) =>
          q.eq("user_id", args.userId).eq("date", data.date)
        )
        .first();

      if (existing) {
        await ctx.db.patch(existing._id, {
          steps: data.steps,
          active_mins: data.activeMins,
          exercise_mins: data.exerciseMins,
          calories_burned: data.caloriesBurned,
          synced_at: now,
        });
      } else {
        await ctx.db.insert("user_activity", {
          user_id: args.userId,
          date: data.date,
          steps: data.steps,
          active_mins: data.activeMins,
          exercise_mins: data.exerciseMins,
          calories_burned: data.caloriesBurned,
          synced_at: now,
        });
      }
      recordsSynced++;
    }

    return { success: true, recordsSynced };
  },
});

/**
 * Get recent sleep data for user
 */
export const getRecentSleepData = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 7 days
  },
  handler: async (ctx, args) => {
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .take(args.days ?? 7);

    return sleepData.map(d => ({
      date: d.date,
      inBedTime: d.in_bed_time,
      asleepTime: d.asleep_time,
      wakeTime: d.wake_time,
      totalSleepMins: d.total_sleep_mins,
      sleepEfficiency: d.sleep_efficiency,
      deepSleepMins: d.deep_sleep_mins,
      lightSleepMins: d.light_sleep_mins,
      remSleepMins: d.rem_sleep_mins,
      awakeMins: d.awake_mins,
      interruptionsCount: d.interruptions_count,
      sleepLatencyMins: d.sleep_latency_mins,
    }));
  },
});

// ============================================
// iOS Journey/Questionnaire Functions
// ============================================

/**
 * Get current day's questionnaire
 */
export const getDayQuestionnaire = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // If no day specified, get user's current day
    let dayNum = args.dayNumber;
    if (!dayNum) {
      const user = await ctx.db.get(args.userId);
      if (!user) throw new Error("User not found");
      dayNum = user.current_day;
    }

    // Get questions for this day using inline helper (avoids internal.xxx bootstrap issues)
    const questions = await getQuestionsByDayHelper(ctx, dayNum);

    // Get user's existing responses for these questions
    const responses: Record<string, unknown> = {};
    for (const q of questions) {
      const response = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q_) =>
          q_.eq("user_id", args.userId).eq("question_id", q.question_id)
        )
        .first();

      if (response) {
        responses[q.question_id] = {
          value: response.response_value,
          number: response.response_number,
          array: response.response_array ? JSON.parse(response.response_array) : null,
          object: response.response_object ? JSON.parse(response.response_object) : null,
        };
      }
    }

    return {
      dayNumber: dayNum,
      questions: questions.map((q) => ({
        questionId: q.question_id,
        questionText: q.question_text,
        helpText: q.help_text,
        pillar: q.pillar,
        answerFormat: q.answer_format,
        formatConfig: JSON.parse(q.format_config),
        validationRules: q.validation_rules ? JSON.parse(q.validation_rules) : null,
        conditionalLogic: q.conditional_logic ? JSON.parse(q.conditional_logic) : null,
        estimatedTimeSeconds: q.estimated_time_seconds,
        moduleName: q.module_name,
        existingResponse: responses[q.question_id] ?? null,
      })),
      totalQuestions: questions.length,
    };
  },
});

/**
 * Submit questionnaire response
 */
export const submitQuestionnaireResponse = mutation({
  args: {
    userId: v.id("users"),
    questionId: v.string(),
    answerFormat: v.string(),
    value: v.optional(v.union(v.string(), v.number())),
    arrayValue: v.optional(v.array(v.string())),
    objectValue: v.optional(v.string()),
    responseUnit: v.optional(v.string()),
    dayNumber: v.number(),
    answeredInSeconds: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // Use inline helper (avoids internal.xxx bootstrap issues)
    return await saveResponseHelper(ctx, {
      userId: args.userId,
      questionId: args.questionId,
      answerFormat: args.answerFormat,
      value: args.value ?? null,
      arrayValue: args.arrayValue,
      objectValue: args.objectValue,
      responseUnit: args.responseUnit,
      dayNumber: args.dayNumber,
      answeredInSeconds: args.answeredInSeconds,
    });
  },
});

/**
 * Complete day and advance to next
 */
export const completeDay = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("User not found");

    // Mark day as complete using inline helper (avoids internal.xxx bootstrap issues)
    await markDayCompleteHelper(ctx, {
      userId: args.userId,
      dayNumber: args.dayNumber,
    });

    // Advance to next day if this was current day
    if (user.current_day === args.dayNumber && args.dayNumber < 14) {
      await ctx.db.patch(args.userId, {
        current_day: args.dayNumber + 1,
      });
    }

    // Check if all 14 days completed
    if (args.dayNumber === 14) {
      await ctx.db.patch(args.userId, {
        onboarding_completed: true,
        onboarding_completed_at: Date.now(),
      });
    }

    return {
      success: true,
      newDay: Math.min(args.dayNumber + 1, 14),
      journeyComplete: args.dayNumber === 14,
    };
  },
});

/**
 * Get user's journey progress
 */
export const getJourneyProgress = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("User not found");

    // Get all completed days
    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const completedDays = progress
      .filter(p => p.completed)
      .map(async (p) => {
        const day = await ctx.db.get(p.day_id);
        return day?.day_number;
      });

    const resolvedDays = await Promise.all(completedDays);

    return {
      currentDay: user.current_day,
      completedDays: resolvedDays.filter(Boolean) as number[],
      totalDays: 14,
      journeyComplete: user.onboarding_completed ?? false,
      startedAt: user.started_at,
    };
  },
});

/**
 * Get detailed daily completion status for catch-up feature
 * Returns completion status for each day including sleep log and assessment
 */
export const getDailyCompletionStatus = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("User not found");

    // Get all responses for this user
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sleep log question ID prefixes
    const sleepLogPrefixes = ["CSD_", "SL_", "SD_"];

    // Group responses by day
    const dayData: Record<
      number,
      {
        sleepLogQuestions: Set<string>;
        assessmentQuestions: Set<string>;
      }
    > = {};

    for (const response of responses) {
      const day = response.day_number ?? 1;
      if (!dayData[day]) {
        dayData[day] = {
          sleepLogQuestions: new Set(),
          assessmentQuestions: new Set(),
        };
      }

      const isSleepLog = sleepLogPrefixes.some((prefix) =>
        response.question_id.startsWith(prefix)
      );
      if (isSleepLog) {
        dayData[day].sleepLogQuestions.add(response.question_id);
      } else {
        dayData[day].assessmentQuestions.add(response.question_id);
      }
    }

    // Get user's triggered gateways FIRST (needed for determining if expansion days have content)
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    const triggeredGatewayIds = gatewayStates
      .filter(g => g.triggered)
      .map(g => g.gateway_id);

    // Build result for each day up to current_day
    const dailyStatus: {
      dayNumber: number;
      sleepLogCompleted: boolean;
      assessmentCompleted: boolean;
      sleepLogCount: number;
      assessmentCount: number;
    }[] = [];

    // Track missed days (days before current day with incomplete tasks)
    const missedDays: {
      dayNumber: number;
      missingSleepLog: boolean;
      missingAssessment: boolean;
    }[] = [];

    for (let day = 1; day <= user.current_day; day++) {
      const data = dayData[day];
      // Sleep log is complete if at least 3 sleep-related questions answered
      const sleepLogCompleted = data ? data.sleepLogQuestions.size >= 3 : false;
      // Assessment is complete if at least 1 non-sleep-log question answered
      const assessmentCompleted = data ? data.assessmentQuestions.size > 0 : false;

      // Determine if this day actually HAS assessment questions
      // Core days (1-5) always have assessments
      // Expansion days (6-14) only have assessments if their required gateways were triggered
      let dayHasAssessment = true;
      if (day >= 6 && day <= 14) {
        // For expansion days, check if the required gateways were triggered
        dayHasAssessment = shouldShowExpansion(day, triggeredGatewayIds);
      }

      dailyStatus.push({
        dayNumber: day,
        sleepLogCompleted,
        assessmentCompleted,
        sleepLogCount: data?.sleepLogQuestions.size ?? 0,
        assessmentCount: data?.assessmentQuestions.size ?? 0,
      });

      // Track missed days (exclude current day - user can still complete it)
      if (day < user.current_day) {
        const missingSleepLog = !sleepLogCompleted;
        // Only mark assessment as missing if the day actually HAD assessment questions
        const missingAssessment = dayHasAssessment && !assessmentCompleted;
        if (missingSleepLog || missingAssessment) {
          missedDays.push({
            dayNumber: day,
            missingSleepLog,
            missingAssessment,
          });
        }
      }
    }

    // Track incomplete expansion packs from previous days (Days 6-14)
    // FIXED: Now uses FIXED_SCHEDULE instead of old user_expansion_schedules table
    const overdueExpansions: {
      dayNumber: number;
      triggeredGateways: string[];
      moduleIds: string[];
      questionCount: number;
      estimatedMinutes: number;
      answeredCount: number;
      splashTitle: string;
    }[] = [];

    // Note: triggeredGatewayIds already loaded earlier in this function

    // Check each expansion day (6-14) that's before the current day
    for (let day = 6; day < user.current_day && day <= 14; day++) {
      const config = FIXED_SCHEDULE[day];
      if (!config || config.type !== "expansion") continue;

      // Check if this expansion should show based on triggered gateways
      if (!shouldShowExpansion(day, triggeredGatewayIds)) continue;

      // Get module IDs for this day's packs
      const moduleIds: string[] = [];
      for (const packId of config.packs) {
        const packModules = PACK_TO_MODULE_IDS[packId];
        if (packModules) {
          moduleIds.push(...packModules);
        }
      }

      // Count how many questions were answered for this day's expansion modules
      let answeredCount = 0;
      const dayResponses = dayData[day];
      if (dayResponses) {
        // Build a set of valid prefixes for this day's modules using the mapping
        const validPrefixes: string[] = [];
        for (const moduleId of moduleIds) {
          const prefix = MODULE_TO_QUESTION_PREFIX[moduleId];
          if (prefix && !validPrefixes.includes(prefix)) {
            validPrefixes.push(prefix.toUpperCase());
          }
        }

        // Check for expansion question IDs matching this day's module prefixes
        for (const qId of dayResponses.assessmentQuestions) {
          const upperQId = qId.toUpperCase();
          // Check if this question starts with any of the valid prefixes
          if (validPrefixes.some(prefix => upperQId.startsWith(prefix))) {
            answeredCount++;
          }
        }
      }

      // Only add to overdue if user hasn't completed most questions
      // (threshold: less than 80% of questions answered)
      const completionThreshold = Math.floor(config.totalQuestions * 0.8);
      if (answeredCount < completionThreshold) {
        overdueExpansions.push({
          dayNumber: day,
          triggeredGateways: config.gateways,
          moduleIds,
          questionCount: config.totalQuestions,
          estimatedMinutes: config.estimatedMinutes,
          answeredCount,
          splashTitle: config.splashTitle,
        });
      }
    }

    return {
      currentDay: user.current_day,
      dailyStatus,
      missedDays,
      hasMissedTasks: missedDays.length > 0,
      totalMissedSleepLogs: missedDays.filter(d => d.missingSleepLog).length,
      totalMissedAssessments: missedDays.filter(d => d.missingAssessment).length,
      // New: Overdue expansion packs
      overdueExpansions,
      hasOverdueExpansions: overdueExpansions.length > 0,
      totalOverdueExpansions: overdueExpansions.length,
    };
  },
});

// ============================================
// iOS App Events/Analytics
// ============================================

/**
 * Track app event
 */
export const trackEvent = mutation({
  args: {
    userId: v.optional(v.id("users")),
    deviceId: v.string(),
    eventType: v.string(),
    eventData: v.optional(v.string()),
    screenName: v.optional(v.string()),
    sessionId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("ios_app_events", {
      user_id: args.userId,
      device_id: args.deviceId,
      event_type: args.eventType,
      event_data: args.eventData,
      screen_name: args.screenName,
      session_id: args.sessionId,
      timestamp: Date.now(),
    });

    return { success: true };
  },
});

// ============================================
// Debug/Testing Functions
// ============================================

/**
 * Advance to next day (DEBUG MODE ONLY)
 * Used for testing the 15-day journey without waiting
 */
export const advanceToNextDay = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const currentDay = user.current_day || 1;
    const nextDay = Math.min(currentDay + 1, 15);

    // Update user's current day
    await ctx.db.patch(args.userId, {
      current_day: nextDay,
    });

    // Mark current day as completed in user_progress
    // First get the day entry
    const dayEntry = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", currentDay))
      .first();

    if (dayEntry) {
      const existingProgress = await ctx.db
        .query("user_progress")
        .withIndex("by_user_day", (q) =>
          q.eq("user_id", args.userId).eq("day_id", dayEntry._id)
        )
        .first();

      if (existingProgress) {
        await ctx.db.patch(existingProgress._id, {
          completed: true,
          completed_at: Date.now(),
        });
      } else {
        // Create progress entry for the day being completed
        await ctx.db.insert("user_progress", {
          user_id: args.userId,
          day_id: dayEntry._id,
          completed: true,
          created_at: Date.now(),
          completed_at: Date.now(),
        });
      }
    }

    // Log the debug action
    await ctx.db.insert("ios_app_events", {
      user_id: args.userId,
      device_id: "debug",
      event_type: "debug_advance_day",
      event_data: JSON.stringify({ from: currentDay, to: nextDay }),
      timestamp: Date.now(),
    });

    return {
      success: true,
      previousDay: currentDay,
      newDay: nextDay,
    };
  },
});

/**
 * Mark expansion pack as completed for the current day
 * This syncs the same-day expansion completion to Convex for cross-device visibility
 */
export const markExpansionPackCompleted = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get the day entry
    const days = await ctx.db.query("days").collect();
    const dayEntry = days.find((d) => d.day_number === args.dayNumber);
    if (!dayEntry) {
      throw new Error(`Day ${args.dayNumber} not found`);
    }

    // Get or create progress entry for this day
    let progressEntry = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", dayEntry._id)
      )
      .first();

    if (progressEntry) {
      // Update existing entry
      await ctx.db.patch(progressEntry._id, {
        expansion_pack_completed: true,
      });
    } else {
      // Create new entry with expansion completed
      await ctx.db.insert("user_progress", {
        user_id: args.userId,
        day_id: dayEntry._id,
        completed: false,
        created_at: Date.now(),
        expansion_pack_completed: true,
      });
    }

    return { success: true, dayNumber: args.dayNumber };
  },
});

/**
 * Mark specific gateway expansions as completed
 * Updates the expansion_completed flag on user_gateway_states entries
 * This persists which specific gateway expansions have been answered
 */
export const markGatewayExpansionsCompleted = mutation({
  args: {
    userId: v.id("users"),
    gatewayIds: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const now = Date.now();
    const updated: string[] = [];

    for (const gatewayId of args.gatewayIds) {
      // Find the gateway state entry
      const gatewayState = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user_gateway", (q) =>
          q.eq("user_id", args.userId).eq("gateway_id", gatewayId)
        )
        .first();

      if (gatewayState) {
        // Update existing entry
        await ctx.db.patch(gatewayState._id, {
          expansion_completed: true,
          expansion_completed_at: now,
        });
        updated.push(gatewayId);
      }
    }

    console.log(`[markGatewayExpansionsCompleted] Marked ${updated.length} gateways as expansion-completed for user ${args.userId}: ${updated.join(", ")}`);
    return { success: true, updatedGateways: updated };
  },
});

/**
 * Get list of gateway IDs that have completed their expansion
 * Returns gateway IDs where expansion_completed is true
 */
export const getCompletedExpansionGateways = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    return gatewayStates
      .filter((g) => g.expansion_completed === true)
      .map((g) => g.gateway_id);
  },
});

/**
 * Reset journey progress (DEBUG MODE ONLY)
 * Resets user to Day 1 and clears ALL assessment data, scores, and progress
 * Mirrors the comprehensive reset in admin.ts:resetUserProgress
 */
export const resetJourneyProgress = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    let deletedRecords = 0;

    // Helper to delete all records from a table for this user
    async function deleteFromTable(
      tableName: string,
      query: { collect: () => Promise<Array<{ _id: Id<any> }>> }
    ) {
      const records = await query.collect();
      for (const record of records) {
        await ctx.db.delete(record._id);
        deletedRecords++;
      }
      if (records.length > 0) {
        console.log(`[resetJourneyProgress] Deleted ${records.length} from ${tableName}`);
      }
    }

    // Reset user's current day and onboarding status
    await ctx.db.patch(args.userId, {
      current_day: 1,
      onboarding_completed: false,
      onboarding_completed_at: undefined,
      developer_mode: false,
    });

    // Delete from all progress-related tables (matching admin.ts:resetUserProgress)

    // Core assessment data
    await deleteFromTable("user_assessment_responses",
      ctx.db.query("user_assessment_responses").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("responses",
      ctx.db.query("responses").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_progress",
      ctx.db.query("user_progress").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("daily_checkins",
      ctx.db.query("daily_checkins").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Questionnaire scores - CRITICAL: This clears Clinical Scores (ISI, PHQ-9, GAD-7, ESS)
    await deleteFromTable("questionnaire_scores",
      ctx.db.query("questionnaire_scores").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("questionnaire_session",
      ctx.db.query("questionnaire_session").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Gateway and expansion data
    await deleteFromTable("user_gateway_states",
      ctx.db.query("user_gateway_states").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_expansion_schedules",
      ctx.db.query("user_expansion_schedules").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Insights and analysis
    await deleteFromTable("sleep_insights",
      ctx.db.query("sleep_insights").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_insight_queue",
      ctx.db.query("user_insight_queue").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_insight_progress",
      ctx.db.query("user_insight_progress").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("onboarding_insights",
      ctx.db.query("onboarding_insights").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Journey and workflow status
    await deleteFromTable("patient_journey_status",
      ctx.db.query("patient_journey_status").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("patient_analysis_workflow",
      ctx.db.query("patient_analysis_workflow").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Gamification data
    await deleteFromTable("user_streaks",
      ctx.db.query("user_streaks").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_badges",
      ctx.db.query("user_badges").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_xp",
      ctx.db.query("user_xp").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("xp_transactions",
      ctx.db.query("xp_transactions").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_daily_tasks",
      ctx.db.query("user_daily_tasks").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Cohort and narrative data
    await deleteFromTable("user_cohort_memberships",
      ctx.db.query("user_cohort_memberships").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_sleep_narrative",
      ctx.db.query("user_sleep_narrative").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_encouragement_history",
      ctx.db.query("user_encouragement_history").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Physician dashboard data (optional - clears physician notes/review status)
    await deleteFromTable("physician_notes",
      ctx.db.query("physician_notes").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("patient_review_status",
      ctx.db.query("patient_review_status").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Interventions and compliance data
    await deleteFromTable("user_interventions",
      ctx.db.query("user_interventions").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_protocol_assignments",
      ctx.db.query("user_protocol_assignments").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Additional metrics and analysis tables
    await deleteFromTable("perception_gaps",
      ctx.db.query("perception_gaps").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("difficulty_adjustment_log",
      ctx.db.query("difficulty_adjustment_log").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("compliance_outcome_correlation",
      ctx.db.query("compliance_outcome_correlation").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_metrics_summary",
      ctx.db.query("user_metrics_summary").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Note: user_sleep_data is intentionally NOT cleared to preserve HealthKit sync data

    // Log the debug action
    await ctx.db.insert("ios_app_events", {
      user_id: args.userId,
      device_id: "debug",
      event_type: "debug_reset_journey",
      event_data: JSON.stringify({
        reset_at: Date.now(),
        deleted_records: deletedRecords
      }),
      timestamp: Date.now(),
    });

    console.log(`[resetJourneyProgress] Complete reset for user ${args.userId}: ${deletedRecords} records deleted`);

    return {
      success: true,
      newDay: 1,
      deletedRecords,
    };
  },
});

/**
 * Jump to any day (DEBUG MODE ONLY)
 * Allows testers to instantly move to any day 1-14 for testing specific questionnaires
 * Does NOT require completing previous days - purely for testing purposes
 */
export const jumpToDay = mutation({
  args: {
    userId: v.id("users"),
    targetDay: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Validate target day is 1-14
    if (args.targetDay < 1 || args.targetDay > 14) {
      throw new Error("Target day must be between 1 and 14");
    }

    const previousDay = user.current_day || 1;

    // Update user's current day directly
    await ctx.db.patch(args.userId, {
      current_day: args.targetDay,
      last_accessed: Date.now(),
    });

    // Log the debug action
    await ctx.db.insert("ios_app_events", {
      user_id: args.userId,
      device_id: "debug",
      event_type: "debug_jump_to_day",
      event_data: JSON.stringify({
        from: previousDay,
        to: args.targetDay,
        timestamp: Date.now()
      }),
      timestamp: Date.now(),
    });

    console.log(`[jumpToDay] User ${user.username}: jumped from day ${previousDay} to day ${args.targetDay}`);

    return {
      success: true,
      previousDay,
      newDay: args.targetDay,
    };
  },
});

/**
 * Backdate user's journey start (DEBUG MODE ONLY)
 * Changes started_at to simulate being further along in the 14-day journey.
 * Useful for testing expansion packs, time-based features, and late-journey flows.
 *
 * Example: backdating 7 days makes the app think you started a week ago,
 * so you'd be on Day 8 of the journey with correct time calculations.
 */
export const backdateUserStart = mutation({
  args: {
    userId: v.id("users"),
    daysAgo: v.number(), // How many days ago to set started_at (1-14)
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Validate daysAgo is reasonable (1-14 for the journey)
    if (args.daysAgo < 0 || args.daysAgo > 14) {
      throw new Error("daysAgo must be between 0 and 14");
    }

    const now = Date.now();
    const previousStartedAt = user.started_at;
    const previousDay = user.current_day || 1;

    // Calculate new started_at (X days ago from now)
    const newStartedAt = now - (args.daysAgo * 24 * 60 * 60 * 1000);

    // Calculate what day the user should be on based on elapsed time
    // Day 1 = first day, so daysAgo of 0 = Day 1, daysAgo of 6 = Day 7
    const calculatedDay = Math.min(args.daysAgo + 1, 14);

    // Update user record
    await ctx.db.patch(args.userId, {
      started_at: newStartedAt,
      current_day: calculatedDay,
      last_accessed: now,
    });

    // Log the debug action
    await ctx.db.insert("ios_app_events", {
      user_id: args.userId,
      device_id: "debug",
      event_type: "debug_backdate_start",
      event_data: JSON.stringify({
        previousStartedAt,
        newStartedAt,
        previousDay,
        newDay: calculatedDay,
        daysAgo: args.daysAgo,
        timestamp: now,
      }),
      timestamp: now,
    });

    console.log(`[backdateUserStart] User ${user.username}: backdated ${args.daysAgo} days (Day ${previousDay} → Day ${calculatedDay})`);

    return {
      success: true,
      previousStartedAt,
      newStartedAt,
      previousDay,
      newDay: calculatedDay,
      daysAgo: args.daysAgo,
    };
  },
});

/**
 * Speed complete current day (DEBUG MODE ONLY)
 * Generates minimal mock responses and marks both sleep log and assessment as complete.
 * Useful for rapid testing of the 14-day journey.
 *
 * @param phenotype - Sleep phenotype for realistic mock data generation
 * @param advanceToNext - If true, advances to next day after completion
 */
export const speedCompleteDay = mutation({
  args: {
    userId: v.id("users"),
    phenotype: v.optional(v.string()), // "insomnia", "osa", "normal", etc.
    advanceToNext: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const currentDay = user.current_day || 1;
    const now = Date.now();
    const phenotype = args.phenotype || "insomnia";

    // Generate mock sleep log responses (5 Stanford Consensus Sleep Diary questions)
    const sleepLogResponses = generateMockSleepLogResponses(currentDay, phenotype);
    for (const response of sleepLogResponses) {
      // Check if response already exists
      const existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", response.questionId)
        )
        .filter((q) => q.eq(q.field("day_number"), currentDay))
        .first();

      if (!existing) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: response.questionId,
          response_value: response.value,
          day_number: currentDay,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // Generate mock assessment responses (varies by day)
    const assessmentResponses = generateMockAssessmentResponses(currentDay, phenotype);
    for (const response of assessmentResponses) {
      const existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", response.questionId)
        )
        .filter((q) => q.eq(q.field("day_number"), currentDay))
        .first();

      if (!existing) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: response.questionId,
          response_value: response.value,
          day_number: currentDay,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // Get or create user_progress entry for this day
    const days = await ctx.db.query("days").collect();
    const dayEntry = days.find((d) => d.day_number === currentDay);

    if (dayEntry) {
      const existingProgress = await ctx.db
        .query("user_progress")
        .withIndex("by_user_day", (q) =>
          q.eq("user_id", args.userId).eq("day_id", dayEntry._id)
        )
        .first();

      if (existingProgress) {
        await ctx.db.patch(existingProgress._id, {
          sleep_log_completed: true,
          assessment_completed: true,
          completed: true,
          completed_at: now,
        });
      } else {
        await ctx.db.insert("user_progress", {
          user_id: args.userId,
          day_id: dayEntry._id,
          sleep_log_completed: true,
          assessment_completed: true,
          completed: true,
          completed_at: now,
          created_at: now,
        });
      }
    }

    // Optionally advance to next day
    let newDay = currentDay;
    if (args.advanceToNext && currentDay < 14) {
      newDay = currentDay + 1;
      await ctx.db.patch(args.userId, {
        current_day: newDay,
        last_accessed: now,
      });
    }

    // Log the debug action
    await ctx.db.insert("ios_app_events", {
      user_id: args.userId,
      device_id: "debug",
      event_type: "debug_speed_complete",
      event_data: JSON.stringify({
        day: currentDay,
        phenotype,
        advancedTo: args.advanceToNext ? newDay : null,
        sleepLogResponses: sleepLogResponses.length,
        assessmentResponses: assessmentResponses.length,
      }),
      timestamp: now,
    });

    console.log(`[speedCompleteDay] User ${user.username}: speed completed Day ${currentDay} (${phenotype}), now on Day ${newDay}`);

    return {
      success: true,
      completedDay: currentDay,
      currentDay: newDay,
      phenotype,
      sleepLogResponses: sleepLogResponses.length,
      assessmentResponses: assessmentResponses.length,
    };
  },
});

// Helper: Generate mock sleep log responses based on phenotype
function generateMockSleepLogResponses(day: number, phenotype: string): Array<{questionId: string; value: string}> {
  // Consensus Sleep Diary questions (CSD_*)
  const baseTime = new Date();
  baseTime.setHours(22, 30, 0, 0); // 10:30 PM bedtime

  // Phenotype-specific variations
  const variations: Record<string, {
    sleepOnsetMin: number;
    wakeCount: number;
    wakeMinutes: number;
    sleepQuality: number;
    totalSleepHours: number;
  }> = {
    insomnia: { sleepOnsetMin: 45, wakeCount: 3, wakeMinutes: 40, sleepQuality: 2, totalSleepHours: 5.5 },
    osa: { sleepOnsetMin: 10, wakeCount: 5, wakeMinutes: 20, sleepQuality: 3, totalSleepHours: 7 },
    anxiety: { sleepOnsetMin: 60, wakeCount: 4, wakeMinutes: 30, sleepQuality: 2, totalSleepHours: 5 },
    depression: { sleepOnsetMin: 20, wakeCount: 2, wakeMinutes: 60, sleepQuality: 2, totalSleepHours: 9 },
    normal: { sleepOnsetMin: 15, wakeCount: 1, wakeMinutes: 5, sleepQuality: 4, totalSleepHours: 7.5 },
  };

  const v = variations[phenotype] || variations.normal;

  // Add some day-to-day variation
  const dayVariation = (day % 3) - 1; // -1, 0, or 1

  return [
    { questionId: "CSD_1", value: "22:30" }, // Bedtime
    { questionId: "CSD_2", value: `${v.sleepOnsetMin + dayVariation * 10}` }, // Sleep onset (minutes)
    { questionId: "CSD_3", value: `${v.wakeCount + dayVariation}` }, // Wake count
    { questionId: "CSD_4", value: `${v.wakeMinutes + dayVariation * 10}` }, // Wake minutes
    { questionId: "CSD_5", value: "07:00" }, // Wake time
    { questionId: "CSD_6", value: `${v.sleepQuality}` }, // Sleep quality (1-5)
  ];
}

// Helper: Generate mock assessment responses based on day and phenotype
function generateMockAssessmentResponses(day: number, phenotype: string): Array<{questionId: string; value: string}> {
  const responses: Array<{questionId: string; value: string}> = [];

  // Day 1: Core intake questions
  if (day === 1) {
    // Basic demographics and sleep concerns
    responses.push(
      { questionId: "Q1", value: "difficulty_falling_asleep" },
      { questionId: "Q2", value: "3" }, // Severity
      { questionId: "Q3", value: "6_months_to_1_year" },
    );

    // Phenotype-specific responses
    if (phenotype === "insomnia") {
      responses.push({ questionId: "Q_INSOMNIA_TRIGGER", value: "yes" });
    } else if (phenotype === "osa") {
      responses.push({ questionId: "Q_SNORING", value: "yes" });
      responses.push({ questionId: "Q_BREATHING_STOPS", value: "sometimes" });
    }
  }

  // Days 2-5: Additional intake
  if (day >= 2 && day <= 5) {
    responses.push(
      { questionId: `Q_DAY${day}_1`, value: "moderate" },
      { questionId: `Q_DAY${day}_2`, value: "3" },
    );
  }

  // Days 6-14: Expansion questions (if gateways triggered)
  if (day >= 6) {
    responses.push(
      { questionId: `Q_EXP_${day}_1`, value: "2" },
      { questionId: `Q_EXP_${day}_2`, value: "sometimes" },
    );
  }

  return responses;
}

/**
 * Speed run entire journey (DEBUG MODE ONLY)
 * Completes all 14 days with mock data in one call.
 * Perfect for rapid end-to-end testing.
 */
export const speedRunFullJourney = mutation({
  args: {
    userId: v.id("users"),
    phenotype: v.optional(v.string()),
    targetDay: v.optional(v.number()), // Stop at this day (default 14)
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const phenotype = args.phenotype || "insomnia";
    const targetDay = args.targetDay || 14;
    const now = Date.now();

    // Backdate started_at to make time calculations work
    const daysAgo = targetDay - 1;
    const newStartedAt = now - (daysAgo * 24 * 60 * 60 * 1000);

    await ctx.db.patch(args.userId, {
      started_at: newStartedAt,
      current_day: 1, // Start from day 1
      last_accessed: now,
    });

    // Complete each day
    const completedDays: number[] = [];
    for (let day = 1; day <= targetDay; day++) {
      // Generate sleep log responses
      const sleepLogResponses = generateMockSleepLogResponses(day, phenotype);
      for (const response of sleepLogResponses) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: response.questionId,
          response_value: response.value,
          day_number: day,
          created_at: now - ((targetDay - day) * 24 * 60 * 60 * 1000),
          updated_at: now - ((targetDay - day) * 24 * 60 * 60 * 1000),
        });
      }

      // Generate assessment responses
      const assessmentResponses = generateMockAssessmentResponses(day, phenotype);
      for (const response of assessmentResponses) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: response.questionId,
          response_value: response.value,
          day_number: day,
          created_at: now - ((targetDay - day) * 24 * 60 * 60 * 1000),
          updated_at: now - ((targetDay - day) * 24 * 60 * 60 * 1000),
        });
      }

      // Mark day as complete
      const days = await ctx.db.query("days").collect();
      const dayEntry = days.find((d) => d.day_number === day);

      if (dayEntry) {
        await ctx.db.insert("user_progress", {
          user_id: args.userId,
          day_id: dayEntry._id,
          sleep_log_completed: true,
          assessment_completed: true,
          completed: true,
          completed_at: now - ((targetDay - day) * 24 * 60 * 60 * 1000),
          created_at: now - ((targetDay - day) * 24 * 60 * 60 * 1000),
        });
      }

      completedDays.push(day);
    }

    // Set final day
    await ctx.db.patch(args.userId, {
      current_day: targetDay,
    });

    // Log the debug action
    await ctx.db.insert("ios_app_events", {
      user_id: args.userId,
      device_id: "debug",
      event_type: "debug_speed_run_journey",
      event_data: JSON.stringify({
        phenotype,
        targetDay,
        completedDays: completedDays.length,
      }),
      timestamp: now,
    });

    console.log(`[speedRunFullJourney] User ${user.username}: completed ${completedDays.length} days with ${phenotype} phenotype`);

    return {
      success: true,
      completedDays: completedDays.length,
      currentDay: targetDay,
      phenotype,
      startedAt: newStartedAt,
    };
  },
});

// ============================================
// Time Travel Mode - Calendar-Based Testing
// Pick a past date to simulate, advance day by day
// All dates stay in the past, never go into the future
// ============================================

/**
 * Set up Time Travel Mode - pick a past date as "simulated today"
 * User picks Dec 3 (30 days ago) → that becomes Day 1's simulated date
 * Advance button moves to Dec 4 (29 days ago), etc.
 */
export const timeTravelSetup = mutation({
  args: {
    userId: v.id("users"),
    simulatedDate: v.number(), // Unix timestamp for "today" in the simulation
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const now = Date.now();

    // Validate date is within last 3 months
    const threeMonthsAgo = now - (90 * 24 * 60 * 60 * 1000);
    if (args.simulatedDate < threeMonthsAgo) {
      throw new Error("Date must be within the last 3 months");
    }

    // Cannot simulate future dates
    if (args.simulatedDate > now) {
      throw new Error("Simulated date cannot be in the future");
    }

    await ctx.db.patch(args.userId, {
      // New Time Travel fields
      time_travel_active: true,
      time_travel_simulated_date: args.simulatedDate,
      time_travel_current_day: 1,
      time_travel_day_completed: false,
      is_test_data: true,
      // Also set legacy fields for compatibility
      started_at: args.simulatedDate,
      current_day: 1,
      // Clear old speed test fields
      speed_test_mode: undefined,
      speed_test_day_unlocks_at: undefined,
    });

    console.log(`[TimeTravel] Setup for user ${user.username}, simulating ${new Date(args.simulatedDate).toDateString()} as Day 1`);

    return {
      success: true,
      simulatedDate: args.simulatedDate,
      currentDay: 1,
    };
  },
});

/**
 * Get Time Travel status - simulated date, journey day, completion status
 * No more timer/lockout logic - advance button is always available
 */
export const timeTravelStatus = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const now = Date.now();
    const DAY_MS = 24 * 60 * 60 * 1000;

    // Use new Time Travel fields (fall back to legacy for backwards compat)
    const isTimeTravelActive = user.time_travel_active || user.speed_test_mode || false;
    const isTestData = user.is_test_data || false;

    // Simulated date is stored directly (not calculated from start + day)
    const simulatedDate = user.time_travel_simulated_date || user.started_at || now;
    const currentDay = user.time_travel_current_day || user.current_day || 1;
    const dayCompleted = user.time_travel_day_completed || false;

    // Calculate if we can advance:
    // 1. Simulated date + 1 day must not exceed today's date
    // 2. Must not be past Day 14
    const nextSimulatedDate = simulatedDate + DAY_MS;
    const canAdvance = isTimeTravelActive && nextSimulatedDate <= now && currentDay < 14;

    // Calculate days ago for display
    const daysAgo = Math.floor((now - simulatedDate) / DAY_MS);

    return {
      isTimeTravelActive,
      isTestData,
      simulatedDate,
      currentDay,
      dayCompleted,
      canAdvance,
      daysAgo,
      journeyComplete: currentDay >= 14,
    };
  },
});

/**
 * Complete current day with mock data (optional helper)
 * Uses the simulated date as the historical timestamp
 * No more lockout timer - advance is always available after this
 */
export const timeTravelCompleteDay = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Use new Time Travel fields with fallback
    const currentDay = user.time_travel_current_day || user.current_day || 1;
    const simulatedDate = user.time_travel_simulated_date || user.started_at || Date.now();

    // Use the simulated date directly as the historical timestamp
    const historicalTimestamp = simulatedDate;

    // Generate mock responses with historical timestamps
    const sleepLogResponses = generateMockSleepLogResponses(currentDay, "normal");
    for (const response of sleepLogResponses) {
      const existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", response.questionId)
        )
        .filter((q) => q.eq(q.field("day_number"), currentDay))
        .first();

      if (!existing) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: response.questionId,
          response_value: response.value.toString(),
          response_number: typeof response.value === "number" ? response.value : undefined,
          day_number: currentDay,
          created_at: historicalTimestamp,
          updated_at: historicalTimestamp,
        });
      }
    }

    const assessmentResponses = generateMockAssessmentResponses(currentDay, "normal");
    for (const response of assessmentResponses) {
      const existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", response.questionId)
        )
        .filter((q) => q.eq(q.field("day_number"), currentDay))
        .first();

      if (!existing) {
        const numericValue = !isNaN(parseFloat(response.value)) ? parseFloat(response.value) : undefined;
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: response.questionId,
          response_value: response.value,
          response_number: numericValue,
          day_number: currentDay,
          created_at: historicalTimestamp,
          updated_at: historicalTimestamp,
        });
      }
    }

    // Mark day as complete with historical timestamp
    const dayRecord = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", currentDay))
      .first();

    if (dayRecord) {
      const existingProgress = await ctx.db
        .query("user_progress")
        .withIndex("by_user_day", (q) =>
          q.eq("user_id", args.userId).eq("day_id", dayRecord._id)
        )
        .first();

      if (existingProgress) {
        await ctx.db.patch(existingProgress._id, {
          completed: true,
          completed_at: historicalTimestamp,
          sleep_log_completed: true,
          assessment_completed: true,
        });
      } else {
        await ctx.db.insert("user_progress", {
          user_id: args.userId,
          day_id: dayRecord._id,
          completed: true,
          completed_at: historicalTimestamp,
          created_at: historicalTimestamp,
          sleep_log_completed: true,
          assessment_completed: true,
        });
      }
    }

    // Mark day as completed in Time Travel state (no lockout timer)
    await ctx.db.patch(args.userId, {
      time_travel_day_completed: true,
    });

    console.log(`[TimeTravel] Day ${currentDay} completed (dated ${new Date(historicalTimestamp).toDateString()})`);

    return {
      success: true,
      completedDay: currentDay,
      historicalDate: historicalTimestamp,
    };
  },
});

/**
 * Advance to next day - moves simulated date forward by 1 day
 * Guards: Cannot advance past today's real date, cannot advance past Day 14
 */
export const timeTravelAdvanceDay = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const now = Date.now();
    const DAY_MS = 24 * 60 * 60 * 1000;

    // Use new Time Travel fields with fallback
    const currentDay = user.time_travel_current_day || user.current_day || 1;
    const simulatedDate = user.time_travel_simulated_date || user.started_at || now;

    // Guard: Cannot advance past Day 14
    if (currentDay >= 14) {
      return {
        success: false,
        error: "Journey complete (Day 14 reached)",
      };
    }

    // Calculate next simulated date
    const nextSimulatedDate = simulatedDate + DAY_MS;

    // Guard: Cannot advance past today's real date
    if (nextSimulatedDate > now) {
      return {
        success: false,
        error: "Cannot advance past today's date",
      };
    }

    const newDay = currentDay + 1;

    await ctx.db.patch(args.userId, {
      // Update new fields
      time_travel_simulated_date: nextSimulatedDate,
      time_travel_current_day: newDay,
      time_travel_day_completed: false, // New day = not completed
      // Also update legacy fields for compatibility
      current_day: newDay,
      started_at: user.started_at, // Keep original start date
    });

    console.log(`[TimeTravel] Advanced to Day ${newDay}, simulating ${new Date(nextSimulatedDate).toDateString()}`);

    return {
      success: true,
      previousDay: currentDay,
      currentDay: newDay,
      simulatedDate: nextSimulatedDate,
      journeyComplete: newDay >= 14,
    };
  },
});

/**
 * Reset Time Travel - clears all data and exits Time Travel mode
 */
export const timeTravelReset = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Delete all user responses
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    for (const r of responses) {
      await ctx.db.delete(r._id);
    }

    // Delete all user progress
    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    for (const p of progress) {
      await ctx.db.delete(p._id);
    }

    // Delete gateway states
    const gateways = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    for (const g of gateways) {
      await ctx.db.delete(g._id);
    }

    // Delete patient journey status (resets from analysis/treatment back to intake)
    const journeyStatus = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    for (const j of journeyStatus) {
      await ctx.db.delete(j._id);
    }

    // Delete patient review status
    const reviewStatus = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    for (const r of reviewStatus) {
      await ctx.db.delete(r._id);
    }

    // Reset user to Day 1 and exit Time Travel mode
    const now = Date.now();
    await ctx.db.patch(args.userId, {
      // Reset new Time Travel fields
      time_travel_active: false,
      time_travel_simulated_date: undefined,
      time_travel_current_day: undefined,
      time_travel_day_completed: undefined,
      // Reset legacy fields
      current_day: 1,
      started_at: now,
      speed_test_mode: false,
      speed_test_day_unlocks_at: undefined,
      is_test_data: false,
    });

    console.log(`[TimeTravel] Reset complete for user ${user.username}`);

    return {
      success: true,
      currentDay: 1,
      startedAt: now,
    };
  },
});

/**
 * Clear test data flag (convert to real patient)
 * Also exits Time Travel mode
 */
export const clearTestDataFlag = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    await ctx.db.patch(args.userId, {
      is_test_data: false,
      // Clear new Time Travel fields
      time_travel_active: false,
      time_travel_simulated_date: undefined,
      time_travel_current_day: undefined,
      time_travel_day_completed: undefined,
      // Clear legacy fields
      speed_test_mode: false,
      speed_test_day_unlocks_at: undefined,
    });

    console.log(`[TimeTravel] Test data flag cleared for ${user.username}`);

    return { success: true };
  },
});

/**
 * Get current journey state (for debugging)
 */
export const getJourneyDebugInfo = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const responses = await ctx.db
      .query("responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get day info for each progress entry
    const progressWithDays = await Promise.all(
      progress.map(async (p) => {
        const day = await ctx.db.get(p.day_id);
        return {
          day: day?.day_number ?? 0,
          completed: p.completed,
        };
      })
    );

    return {
      currentDay: user.current_day || 1,
      onboardingCompleted: user.onboarding_completed || false,
      progressCount: progress.length,
      responsesCount: responses.length,
      triggeredGateways: gatewayStates.filter(g => g.triggered).map(g => g.gateway_id),
      progressByDay: progressWithDays,
    };
  },
});

// ============================================
// Helper Functions
// ============================================

function generateSessionToken(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let token = "";
  for (let i = 0; i < 64; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}

function hashToken(token: string): string {
  // Simple hash for storing - in production use proper crypto
  let hash = 0;
  for (let i = 0; i < token.length; i++) {
    const char = token.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return hash.toString(16);
}
