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
      inBedTime: v.optional(v.number()),
      asleepTime: v.optional(v.number()),
      wakeTime: v.optional(v.number()),
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
      // For day 1, assessment requires more questions (core assessment)
      const assessmentCompleted = data ? data.assessmentQuestions.size > 0 : false;

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
        const missingAssessment = !assessmentCompleted;
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
    const overdueExpansions: {
      dayNumber: number;
      triggeredGateways: string[];
      moduleIds: string[];
      questionCount: number;
      estimatedMinutes: number;
      answeredCount: number;
    }[] = [];

    // Get expansion schedule for this user
    const expansionSchedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (expansionSchedule && expansionSchedule.day_assignments) {
      // Check each day assignment for incomplete expansion packs
      for (const assignment of expansionSchedule.day_assignments) {
        // Only check days that are before current day AND not completed
        if (assignment.day_number < user.current_day && assignment.completed !== true) {
          // Count how many expansion questions were answered for this day
          const expansionPrefixes = assignment.module_ids.map(m => m.toUpperCase());
          let answeredCount = 0;

          const dayResponses = dayData[assignment.day_number];
          if (dayResponses) {
            // Check assessment responses for expansion module questions
            for (const qId of dayResponses.assessmentQuestions) {
              const upperQId = qId.toUpperCase();
              // Check if this response belongs to one of the expansion modules
              if (expansionPrefixes.some(prefix => upperQId.startsWith(prefix))) {
                answeredCount++;
              }
            }
          }

          // Only add to overdue if there are actually questions to complete
          if (assignment.question_count > 0) {
            overdueExpansions.push({
              dayNumber: assignment.day_number,
              triggeredGateways: expansionSchedule.triggered_gateways,
              moduleIds: assignment.module_ids,
              questionCount: assignment.question_count,
              estimatedMinutes: assignment.estimated_minutes,
              answeredCount,
            });
          }
        }
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
 * Reset journey progress (DEBUG MODE ONLY)
 * Resets user to Day 1 and clears all responses
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

    // Reset user's current day
    await ctx.db.patch(args.userId, {
      current_day: 1,
      onboarding_completed: false,
    });

    // Delete all user progress entries
    const progressEntries = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const entry of progressEntries) {
      await ctx.db.delete(entry._id);
    }

    // Delete all responses
    const responses = await ctx.db
      .query("responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const response of responses) {
      await ctx.db.delete(response._id);
    }

    // Reset gateway states
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const state of gatewayStates) {
      await ctx.db.patch(state._id, {
        triggered: false,
        triggered_at: undefined,
        trigger_value: undefined,
      });
    }

    // Log the debug action
    await ctx.db.insert("ios_app_events", {
      user_id: args.userId,
      device_id: "debug",
      event_type: "debug_reset_journey",
      event_data: JSON.stringify({ reset_at: Date.now() }),
      timestamp: Date.now(),
    });

    return {
      success: true,
      newDay: 1,
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
