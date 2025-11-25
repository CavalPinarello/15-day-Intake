/**
 * iOS-Specific Convex Functions
 *
 * This file contains all Convex functions optimized for direct iOS app usage.
 * The iOS app should call these functions directly using the Convex Swift SDK.
 */

import { query, mutation, action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";

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
    username: v.string(),
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
    // Check if username exists
    const existingUsername = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();

    if (existingUsername) {
      throw new Error("Username already exists");
    }

    // Check if email exists
    const existingEmail = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();

    if (existingEmail) {
      throw new Error("Email already exists");
    }

    const now = Date.now();

    // Create user
    const userId = await ctx.db.insert("users", {
      username: args.username,
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
        username: args.username,
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
 */
export const updateUserProfile = mutation({
  args: {
    userId: v.id("users"),
    updates: v.object({
      email: v.optional(v.string()),
      profilePicture: v.optional(v.string()),
      appleHealthConnected: v.optional(v.boolean()),
    }),
  },
  handler: async (ctx, args) => {
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

    await ctx.db.patch(args.userId, updateData);

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
 */
export const syncSleepData = mutation({
  args: {
    userId: v.id("users"),
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
    })),
  },
  handler: async (ctx, args) => {
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
 */
export const syncHeartRateData = mutation({
  args: {
    userId: v.id("users"),
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
 */
export const syncActivityData = mutation({
  args: {
    userId: v.id("users"),
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

    // Get questions for this day using existing query
    const questions = await ctx.runQuery(
      api.assessmentQueries.getQuestionsByDay,
      { dayNumber: dayNum }
    );

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
      questions: questions.map(q => ({
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
    dayNumber: v.number(),
    answeredInSeconds: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // Use existing mutation
    return await ctx.runMutation(api.assessmentMutations.saveResponse, {
      userId: args.userId,
      questionId: args.questionId,
      answerFormat: args.answerFormat,
      value: args.value ?? null,
      arrayValue: args.arrayValue,
      objectValue: args.objectValue,
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

    // Mark day as complete
    await ctx.runMutation(api.assessmentMutations.markDayComplete, {
      userId: args.userId,
      dayNumber: args.dayNumber,
    });

    // Advance to next day if this was current day
    if (user.current_day === args.dayNumber && args.dayNumber < 15) {
      await ctx.db.patch(args.userId, {
        current_day: args.dayNumber + 1,
      });
    }

    // Check if all 15 days completed
    if (args.dayNumber === 15) {
      await ctx.db.patch(args.userId, {
        onboarding_completed: true,
        onboarding_completed_at: Date.now(),
      });
    }

    return {
      success: true,
      newDay: Math.min(args.dayNumber + 1, 15),
      journeyComplete: args.dayNumber === 15,
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
      totalDays: 15,
      journeyComplete: user.onboarding_completed ?? false,
      startedAt: user.started_at,
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
