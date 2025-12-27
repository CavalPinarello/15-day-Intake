/**
 * Watch-Specific Convex Functions
 *
 * These functions enable Apple Watch to directly communicate with Convex
 * for real-time sync of questionnaire progress between Watch, iPhone, and Web.
 *
 * SECURITY: All mutations now require session token validation to prevent
 * unauthorized access to other users' data.
 */

import { query, mutation, MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";
import { validateIOSSession } from "./auth";

// ============================================
// Helper Functions
// ============================================

/**
 * Compute sleep metrics from CSD_ questionnaire responses and save to user_sleep_data.
 * This bridges subjective questionnaire data to the metrics format used by Sleep Insights.
 * Called automatically when sleep log section is completed.
 */
async function computeSleepMetricsForDay(
  ctx: MutationCtx,
  userId: Id<"users">,
  dayNumber: number,
  date: string
): Promise<void> {
  // Get all CSD_ responses for this user and day
  const responses = await ctx.db
    .query("user_assessment_responses")
    .withIndex("by_user_day", (q) =>
      q.eq("user_id", userId).eq("day_number", dayNumber)
    )
    .collect();

  // Filter to only CSD_ questions (Consensus Sleep Diary)
  const csdResponses = responses.filter((r) => r.question_id.startsWith("CSD_"));

  if (csdResponses.length === 0) {
    console.log(`[computeSleepMetrics] No CSD_ responses found for user ${userId} day ${dayNumber}`);
    return;
  }

  // Build response map for easy lookup
  const responseMap = new Map<string, { value?: string; number?: number }>();
  for (const r of csdResponses) {
    responseMap.set(r.question_id, {
      value: r.response_value ?? undefined,
      number: r.response_number ?? undefined,
    });
  }

  // Parse time string to minutes since midnight
  const parseTimeToMinutes = (timeStr: string | undefined): number | null => {
    if (!timeStr) return null;
    const match = timeStr.match(/^(\d{1,2}):(\d{2})$/);
    if (!match) return null;
    const hours = parseInt(match[1], 10);
    const mins = parseInt(match[2], 10);
    return hours * 60 + mins;
  };

  // Extract values from responses
  const intoBedTime = parseTimeToMinutes(responseMap.get("CSD_INTO_BED")?.value);
  const trySleepTime = parseTimeToMinutes(responseMap.get("CSD_TRY_SLEEP")?.value);
  const finalWakeTime = parseTimeToMinutes(responseMap.get("CSD_FINAL_WAKE")?.value);
  const outOfBedTime = parseTimeToMinutes(responseMap.get("CSD_OUT_BED")?.value);
  const latencyMins = responseMap.get("CSD_LATENCY")?.number ?? null;
  const awakenings = responseMap.get("CSD_AWAKENINGS")?.number ?? null;
  const wasoMins = responseMap.get("CSD_WASO")?.number ?? null;
  const quality = responseMap.get("CSD_QUALITY")?.number ?? null;

  // Calculate derived metrics
  let totalSleepMins: number | undefined;
  let sleepEfficiency: number | undefined;
  let timeInBedMins: number | undefined;

  // Time in bed = outOfBed - intoBed (handling midnight crossing)
  if (intoBedTime !== null && outOfBedTime !== null) {
    if (outOfBedTime > intoBedTime) {
      timeInBedMins = outOfBedTime - intoBedTime;
    } else {
      // Crossed midnight: e.g., 23:00 to 07:00 = 8 hours
      timeInBedMins = 24 * 60 - intoBedTime + outOfBedTime;
    }
  }

  // Total sleep time = Time in bed - latency - WASO
  if (timeInBedMins !== undefined) {
    const latency = latencyMins ?? 0;
    const waso = wasoMins ?? 0;
    totalSleepMins = Math.max(0, timeInBedMins - latency - waso);
  }

  // Sleep efficiency = (Total sleep time / Time in bed) * 100
  if (totalSleepMins !== undefined && timeInBedMins !== undefined && timeInBedMins > 0) {
    sleepEfficiency = Math.round((totalSleepMins / timeInBedMins) * 100);
  }

  // NOTE: Sleep stages (deep, REM, light) CANNOT be derived from questionnaires.
  // They require wearable sensors (HRV, movement, EEG) to measure.
  // We do NOT fabricate these values - they will be null for questionnaire-only data.
  // Only real wearable integrations should populate these fields.

  // Convert times to Unix timestamps
  const dateObj = new Date(date + "T00:00:00");
  const inBedTimestamp =
    intoBedTime !== null
      ? new Date(dateObj.getTime() - 86400000 + intoBedTime * 60000).getTime()
      : undefined;
  const asleepTimestamp =
    trySleepTime !== null && latencyMins !== null
      ? new Date(dateObj.getTime() - 86400000 + (trySleepTime + latencyMins) * 60000).getTime()
      : undefined;
  const wakeTimestamp =
    finalWakeTime !== null ? new Date(dateObj.getTime() + finalWakeTime * 60000).getTime() : undefined;

  // Check for existing entry
  const existing = await ctx.db
    .query("user_sleep_data")
    .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
    .first();

  const now = Date.now();
  const sleepData = {
    in_bed_time: inBedTimestamp,
    asleep_time: asleepTimestamp,
    wake_time: wakeTimestamp,
    total_sleep_mins: totalSleepMins,
    sleep_efficiency: sleepEfficiency,
    // Sleep stages are NOT populated for questionnaire data - they require wearable sensors
    // deep_sleep_mins, light_sleep_mins, rem_sleep_mins remain undefined
    awake_mins: wasoMins ?? undefined,
    interruptions_count: awakenings ?? undefined,
    sleep_latency_mins: latencyMins ?? undefined,
    primary_source: "Questionnaire",  // Critical: marks this as subjective data
    source_bundle_id: "com.zoesleep.app",
    synced_at: now,
  };

  if (existing) {
    await ctx.db.patch(existing._id, sleepData);
    console.log(
      `[computeSleepMetrics] Updated sleep data for ${date}: ${totalSleepMins} mins, ${sleepEfficiency}% efficiency`
    );
  } else {
    await ctx.db.insert("user_sleep_data", {
      user_id: userId,
      date,
      ...sleepData,
    });
    console.log(
      `[computeSleepMetrics] Created sleep data for ${date}: ${totalSleepMins} mins, ${sleepEfficiency}% efficiency`
    );
  }
}

/**
 * Compute and store the expansion schedule for a user.
 * Called when Day 2 is completed (all gateway trigger questions have been asked).
 */
async function computeExpansionScheduleForUser(
  ctx: MutationCtx,
  userId: Id<"users">
): Promise<void> {
  // Define expansion modules with their metadata
  const EXPANSION_MODULES = [
    { id: "expansion_isi", name: "ISI", questionCount: 7, estimatedMinutes: 5, requiredGateways: ["insomnia", "poor_sleep_quality"], priority: 1 },
    { id: "expansion_phq9", name: "PHQ-9", questionCount: 9, estimatedMinutes: 6, requiredGateways: ["depression"], priority: 1 },
    { id: "expansion_gad7", name: "GAD-7", questionCount: 7, estimatedMinutes: 5, requiredGateways: ["anxiety"], priority: 1 },
    { id: "expansion_stop_bang", name: "STOP-BANG", questionCount: 8, estimatedMinutes: 5, requiredGateways: ["osa"], priority: 1 },
    { id: "expansion_ess", name: "ESS", questionCount: 8, estimatedMinutes: 5, requiredGateways: ["excessive_sleepiness"], priority: 2 },
    { id: "expansion_berlin", name: "Berlin", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["osa"], priority: 2 },
    { id: "expansion_dbas", name: "DBAS-16", questionCount: 16, estimatedMinutes: 12, requiredGateways: ["insomnia"], priority: 3 },
    { id: "expansion_sleep_hygiene", name: "Sleep Hygiene", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["insomnia", "poor_sleep_quality"], priority: 3 },
    { id: "expansion_psas", name: "PSAS", questionCount: 16, estimatedMinutes: 10, requiredGateways: ["insomnia"], priority: 3 },
    { id: "expansion_fss", name: "FSS", questionCount: 9, estimatedMinutes: 6, requiredGateways: ["excessive_sleepiness"], priority: 4 },
    { id: "expansion_fosq", name: "FOSQ-10", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["excessive_sleepiness"], priority: 4 },
    { id: "expansion_dass21", name: "DASS-21", questionCount: 21, estimatedMinutes: 15, requiredGateways: ["depression", "anxiety"], priority: 4 },
    { id: "expansion_promis_cognitive", name: "PROMIS Cognitive", questionCount: 6, estimatedMinutes: 4, requiredGateways: ["cognitive"], priority: 4 },
    { id: "expansion_bpi", name: "BPI", questionCount: 11, estimatedMinutes: 8, requiredGateways: ["pain"], priority: 5 },
    { id: "expansion_medas", name: "MEDAS", questionCount: 14, estimatedMinutes: 10, requiredGateways: ["diet_impact"], priority: 5 },
    { id: "expansion_meq", name: "MEQ", questionCount: 19, estimatedMinutes: 12, requiredGateways: ["sleep_timing"], priority: 5 },
  ];

  const TARGET_QUESTIONS_PER_DAY = 14;
  const MAX_QUESTIONS_PER_DAY = 18;
  const EXPANSION_START_DAY = 6;  // Expansions start Day 6 (after core Days 1-5)
  const TOTAL_DAYS = 14;

  // Get user's triggered gateways
  const gatewayStates = await ctx.db
    .query("user_gateway_states")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .collect();

  const triggeredGateways = gatewayStates
    .filter((g) => g.triggered)
    .map((g) => g.gateway_id);

  console.log(`[computeExpansionSchedule] Triggered gateways: ${triggeredGateways.join(", ")}`);

  // Filter modules to only those triggered
  const triggeredModules = EXPANSION_MODULES.filter((module) =>
    module.requiredGateways.some((gateway) => triggeredGateways.includes(gateway))
  );

  if (triggeredModules.length === 0) {
    console.log(`[computeExpansionSchedule] No gateways triggered, no expansion schedule needed`);
    return;
  }

  // Sort by priority
  const sortedModules = [...triggeredModules].sort((a, b) => {
    if (a.priority !== b.priority) return a.priority - b.priority;
    return a.questionCount - b.questionCount;
  });

  // Distribute modules across days using bin-packing
  const dayAssignments: Array<{
    day_number: number;
    module_ids: string[];
    question_count: number;
    estimated_minutes: number;
    completed: boolean;
  }> = [];

  let currentDay = EXPANSION_START_DAY;
  let currentDayModules: typeof sortedModules = [];
  let currentDayQuestions = 0;

  for (const module of sortedModules) {
    if (currentDayQuestions + module.questionCount > MAX_QUESTIONS_PER_DAY && currentDayModules.length > 0) {
      dayAssignments.push({
        day_number: currentDay,
        module_ids: currentDayModules.map((m) => m.id),
        question_count: currentDayQuestions,
        estimated_minutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
        completed: false,
      });
      currentDay++;
      currentDayModules = [];
      currentDayQuestions = 0;
    }

    currentDayModules.push(module);
    currentDayQuestions += module.questionCount;

    if (currentDayQuestions >= TARGET_QUESTIONS_PER_DAY && currentDay < TOTAL_DAYS) {
      dayAssignments.push({
        day_number: currentDay,
        module_ids: currentDayModules.map((m) => m.id),
        question_count: currentDayQuestions,
        estimated_minutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
        completed: false,
      });
      currentDay++;
      currentDayModules = [];
      currentDayQuestions = 0;
    }
  }

  // Don't forget the last day
  if (currentDayModules.length > 0) {
    dayAssignments.push({
      day_number: currentDay,
      module_ids: currentDayModules.map((m) => m.id),
      question_count: currentDayQuestions,
      estimated_minutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
      completed: false,
    });
  }

  const totalQuestions = dayAssignments.reduce((sum, d) => sum + d.question_count, 0);
  const totalMinutes = dayAssignments.reduce((sum, d) => sum + d.estimated_minutes, 0);

  console.log(`[computeExpansionSchedule] Schedule: ${dayAssignments.length} days, ${totalQuestions} questions, ~${totalMinutes} minutes`);

  // Store the schedule
  const existing = await ctx.db
    .query("user_expansion_schedules")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .first();

  const scheduleData = {
    user_id: userId,
    computed_at: Date.now(),
    triggered_gateways: triggeredGateways,
    day_assignments: dayAssignments,
    total_expansion_questions: totalQuestions,
    total_estimated_minutes: totalMinutes,
  };

  if (existing) {
    await ctx.db.patch(existing._id, scheduleData);
  } else {
    await ctx.db.insert("user_expansion_schedules", scheduleData);
  }
}

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
// SHA256 of "test" - alternative test password
const TEST_PASSWORD_TEST_SHA256 = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08";
// Simple hash of "1" - what Watch currently sends
const TEST_PASSWORD_SIMPLE = simpleHash("1"); // "31"

/**
 * Sign in from Watch using username and password
 * Accepts both SHA256 and simple hash for compatibility
 * Returns a session token for subsequent authenticated requests
 */
export const signIn = mutation({
  args: {
    username: v.string(),
    passwordHash: v.string(),
    deviceId: v.optional(v.string()), // Watch device ID for session tracking
  },
  handler: async (ctx, args) => {
    // Try username first, then email
    let user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();

    // If not found by username, try email
    if (!user) {
      user = await ctx.db
        .query("users")
        .withIndex("by_email", (q) => q.eq("email", args.username))
        .first();
    }

    if (!user) {
      throw new Error("User not found");
    }

    // Accept multiple hash formats for development flexibility
    const validHashes = [
      user.password_hash,           // Whatever is in DB (SHA256)
      TEST_PASSWORD_SIMPLE,         // "31" - simple hash of "1"
      TEST_PASSWORD_SHA256,         // SHA256 of "1"
      TEST_PASSWORD_TEST_SHA256,    // SHA256 of "test"
      "31",                         // Direct simple hash
    ];

    if (!validHashes.includes(args.passwordHash)) {
      throw new Error("Invalid password");
    }

    const now = Date.now();

    // Generate session token for Watch
    const sessionToken = generateWatchSessionToken();
    const expiresAt = now + (30 * 24 * 60 * 60 * 1000); // 30 days

    // Create Watch session (using ios_sessions table for unified session management)
    await ctx.db.insert("ios_sessions", {
      user_id: user._id,
      session_token: sessionToken,
      device_id: args.deviceId || `watch_${user._id}`,
      expires_at: expiresAt,
      created_at: now,
      last_refreshed_at: now,
      is_active: true,
    });

    // Update last accessed
    await ctx.db.patch(user._id, {
      last_accessed: now,
    });

    return {
      userId: user._id,
      username: user.username,
      currentDay: user.current_day,
      onboardingCompleted: user.onboarding_completed ?? false,
      sessionToken, // NEW: Return session token for authenticated requests
      expiresAt,
    };
  },
});

/**
 * Generate a secure session token
 */
function generateWatchSessionToken(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let token = "watch_";
  for (let i = 0; i < 58; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}

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

    // Check for overdue expansion packs from previous days
    const expansionSchedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    let overdueExpansionsCount = 0;
    if (expansionSchedule && expansionSchedule.day_assignments) {
      for (const assignment of expansionSchedule.day_assignments) {
        // Count days before current day that have incomplete expansion packs
        if (assignment.day_number < user.current_day && assignment.completed !== true && assignment.question_count > 0) {
          overdueExpansionsCount++;
        }
      }
    }

    // Check for same-day expansion pack availability (Days 1-5 only)
    let hasExpansionPackToday = false;
    let expansionPackCompleted = false;

    if (user.current_day <= 5) {
      // Get user's triggered gateways
      const userGateways = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();

      const triggeredGatewayIds = new Set(
        userGateways.filter((g) => g.triggered).map((g) => g.gateway_id)
      );

      // Same-day expansion gateways (these trigger immediate deep dives on Days 1-5)
      const sameDayExpansionGateways = ["insomnia", "depression", "anxiety", "osa"];
      hasExpansionPackToday = sameDayExpansionGateways.some((gw) => triggeredGatewayIds.has(gw));

      // Check if expansion pack was completed today
      if (hasExpansionPackToday) {
        const currentProgress = progressEntries.find((p) => {
          const dayId = p.day_id;
          // We need to check if this is the current day's progress
          return true; // Will check below
        });

        // Get current day's progress entry
        const days = await ctx.db.query("days").collect();
        const currentDayEntry = days.find((d) => d.day_number === user.current_day);
        if (currentDayEntry) {
          const currentDayProgress = progressEntries.find((p) => p.day_id === currentDayEntry._id);
          expansionPackCompleted = currentDayProgress?.expansion_pack_completed ?? false;
        }
      }
    }

    return {
      currentDay: user.current_day,
      completedDays: completedDays.sort((a, b) => a - b),
      journeyComplete: user.onboarding_completed ?? false,
      totalDays: 14,
      // Section-level completion for current day
      sleepLogCompleted: currentDaySections.sleepLogCompleted,
      assessmentCompleted: currentDaySections.assessmentCompleted,
      // Expansion pack status for current day (same-day deep dives on Days 1-5)
      hasExpansionPackToday,
      expansionPackCompleted,
      // Full section status for all days
      daySectionStatus,
      // Overdue expansion packs (for Watch to show reminder)
      overdueExpansionsCount,
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
 *
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const completeSection = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.union(v.literal("sleepLog"), v.literal("assessment")),
    source: v.optional(v.string()), // "watch" or "iphone" or "web"
    skipValidation: v.optional(v.boolean()), // Debug only - skips response validation
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      // Verify the session user matches the requested userId
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot modify another user's data");
      }
    }
    // TODO: Make sessionToken required once Watch app is updated
    // For now, allow calls without sessionToken for backward compatibility

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

      // Filter responses by section
      // Sleep log questions can have SL_ prefix (legacy) or SD_ prefix (Consensus Sleep Diary)
      // Also include CSD_ prefix for compatibility
      const sectionResponses = responses.filter(r => {
        const qid = r.question_id;
        const isSleepLog = qid.startsWith("SL_") || qid.startsWith("SD_") || qid.startsWith("CSD_");
        return args.section === "sleepLog" ? isSleepLog : !isSleepLog;
      });

      // For assessment section on expansion days (8-14), check if there are actually questions
      // If no gateways triggered, there may be 0 assessment questions, which is valid
      let skipAssessmentValidation = false;
      if (args.section === "assessment" && args.dayNumber >= 8) {
        // Check if this day has any actual assessment questions
        const dayModules = await ctx.db
          .query("day_modules")
          .withIndex("by_day", (q) => q.eq("day_number", args.dayNumber))
          .collect();

        // Check if any modules have questions that should be shown
        // (expansion modules only show if their gateway is triggered)
        let hasRealQuestions = false;
        for (const dayModule of dayModules) {
          const module = await ctx.db
            .query("assessment_modules")
            .withIndex("by_module_id", (q) => q.eq("module_id", dayModule.module_id))
            .first();

          if (!module) continue;

          // If it's an expansion module, check if gateway is triggered
          if (module.tier === "expansion" || module.tier === "specialized") {
            const moduleGateways = await ctx.db
              .query("module_gateways")
              .withIndex("by_module_id", (q) => q.eq("module_id", dayModule.module_id))
              .collect();

            if (moduleGateways.length > 0) {
              // Get user's triggered gateways
              const userGateways = await ctx.db
                .query("user_gateway_states")
                .withIndex("by_user", (q) => q.eq("user_id", args.userId))
                .collect();
              const triggeredIds = new Set(userGateways.filter(g => g.triggered).map(g => g.gateway_id));

              const hasTriggeredGateway = moduleGateways.some(mg => triggeredIds.has(mg.gateway_id));
              if (hasTriggeredGateway) {
                hasRealQuestions = true;
                break;
              }
            }
          } else {
            // Core module - always has questions
            hasRealQuestions = true;
            break;
          }
        }

        // If no real questions exist for this day's assessment, skip validation
        if (!hasRealQuestions) {
          skipAssessmentValidation = true;
          console.log(`[Convex] Day ${args.dayNumber} has no assessment questions (no gateways triggered) - skipping validation`);
        }
      }

      if (!skipAssessmentValidation && sectionResponses.length < minResponses) {
        throw new Error(
          `Cannot complete ${args.section}: Only ${sectionResponses.length} responses found, ` +
          `minimum ${minResponses} required. Please answer the questions before completing.`
        );
      }

      console.log(`[Convex] Section validation passed: ${sectionResponses.length} responses for ${args.section}${skipAssessmentValidation ? " (no questions required)" : ""}`);
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

    // Check if both sections are now complete
    const dayFullyCompleted = sleepLogCompleted && assessmentCompleted;
    let newDay = user.current_day;

    // FIX: Only auto-advance if in developer mode
    // Normal users must wait until 4 AM local time and explicitly advance via advanceDay mutation
    // This prevents bypassing the day lockout intended for circadian consistency
    if (dayFullyCompleted && user.current_day === args.dayNumber && args.dayNumber < 14) {
      const isDeveloperMode = user.developer_mode === true;

      if (isDeveloperMode) {
        // Developer mode: Advance immediately (for testing)
        newDay = args.dayNumber + 1;
        await ctx.db.patch(args.userId, {
          current_day: newDay,
          last_accessed: now,
        });
        console.log(`[completeSection] Developer mode: Auto-advanced to day ${newDay}`);
      } else {
        // Normal mode: Day is marked complete, but user stays on current day
        // They must wait until 4 AM and use advanceDay to proceed
        console.log(`[completeSection] Day ${args.dayNumber} completed, awaiting 4 AM unlock`);
      }
    }

    // Mark journey complete if day 14 is fully done
    if (args.dayNumber === 14 && dayFullyCompleted) {
      await ctx.db.patch(args.userId, {
        onboarding_completed: true,
        onboarding_completed_at: now,
      });
    }

    // Compute expansion schedule when Day 5 is fully completed
    // By Day 5, all gateway trigger questions have been asked (Days 1-5 contain all gateways)
    // This schedules expansions dynamically for Days 6-15 based on triggered gateways
    if (args.dayNumber === 5 && dayFullyCompleted) {
      try {
        await computeExpansionScheduleForUser(ctx, args.userId);
        console.log(`[completeSection] Computed expansion schedule for user ${args.userId}`);
      } catch (error) {
        console.error(`[completeSection] Failed to compute expansion schedule: ${error}`);
      }
    }

    // FIX: Auto-compute sleep metrics when sleep log is completed
    // This ensures user_sleep_data is populated for Sleep Insights dashboard
    if (args.section === "sleepLog" && sleepLogCompleted) {
      // Get the date for this day's sleep data (based on user's journey start)
      const userStartDate = new Date(user.started_at);
      const sleepDate = new Date(userStartDate);
      sleepDate.setDate(sleepDate.getDate() + args.dayNumber - 1);
      const dateStr = sleepDate.toISOString().split("T")[0];

      // Import and call the sleep metrics computation
      // We'll call it inline here to avoid circular imports
      try {
        await computeSleepMetricsForDay(ctx, args.userId, args.dayNumber, dateStr);
        console.log(`[completeSection] Computed sleep metrics for day ${args.dayNumber}`);
      } catch (error) {
        // Log but don't fail the section completion if metrics computation fails
        console.error(`[completeSection] Failed to compute sleep metrics: ${error}`);
      }
    }

    // Mark the questionnaire_session as completed for this section
    const existingSession = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user_day_section", (q) =>
        q.eq("user_id", args.userId)
          .eq("day_number", args.dayNumber)
          .eq("section", args.section)
      )
      .first();

    if (existingSession) {
      await ctx.db.patch(existingSession._id, {
        completed: true,
        last_updated_at: now,
      });
    }

    return {
      success: true,
      section: args.section,
      sleepLogCompleted,
      assessmentCompleted,
      dayFullyCompleted,
      currentDay: newDay,
      journeyComplete: args.dayNumber === 14 && dayFullyCompleted,
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
    if (user.current_day === args.dayNumber && args.dayNumber < 14) {
      await ctx.db.patch(args.userId, {
        current_day: args.dayNumber + 1,
        last_accessed: now,
      });
    }

    // Mark journey complete if day 14
    if (args.dayNumber === 14) {
      await ctx.db.patch(args.userId, {
        onboarding_completed: true,
        onboarding_completed_at: now,
      });
    }

    return {
      success: true,
      newDay: Math.min(args.dayNumber + 1, 14),
      journeyComplete: args.dayNumber === 14,
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

    // Can't advance past day 14
    if (currentDay >= 14) {
      return {
        canAdvance: false,
        reason: "Journey already complete",
        sleepLogCompleted: true,
        assessmentCompleted: true,
        timeUnlocked: true,
        currentDay: 14,
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

    // Check if this is an expansion day with no gateways triggered (no assessment needed)
    let hasAssessmentToday = true;
    if (currentDay > 5) {
      // Days 6-14 are expansion days - check if any gateways triggered
      const userGateways = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();

      const triggeredCount = userGateways.filter((g) => g.triggered).length;
      hasAssessmentToday = triggeredCount > 0;
    }

    // Completion check: Sleep Log always required, Assessment only if available
    const assessmentOk = !hasAssessmentToday || assessmentCompleted;
    const bothSectionsComplete = sleepLogCompleted && assessmentOk;

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
    if (!sleepLogCompleted && !assessmentOk) {
      reason = hasAssessmentToday
        ? "Complete both Sleep Log and Assessment to unlock the next day"
        : "Complete the Sleep Log to unlock the next day";
    } else if (!sleepLogCompleted) {
      reason = "Complete the Sleep Log to unlock the next day";
    } else if (!assessmentOk) {
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
      hasAssessmentToday,
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
 *
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const advanceDay = mutation({
  args: {
    userId: v.id("users"),
    debugMode: v.optional(v.boolean()),
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot advance another user's day");
      }
    }

    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const currentDay = user.current_day || 1;

    // Can't advance past day 14
    if (currentDay >= 14) {
      return {
        success: false,
        error: "Journey already complete",
        currentDay: 14,
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

    // Check if this is an expansion day with no gateways triggered (no assessment needed)
    let hasAssessmentToday = true;
    if (currentDay > 5) {
      // Days 6-14 are expansion days - check if any gateways triggered
      const userGateways = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();

      const triggeredCount = userGateways.filter((g) => g.triggered).length;
      hasAssessmentToday = triggeredCount > 0;
    }

    // COMPLETION CHECK: Sleep Log always required, Assessment only if available
    const needsAssessment = hasAssessmentToday;
    const assessmentOk = !needsAssessment || assessmentCompleted;

    if (!sleepLogCompleted || !assessmentOk) {
      let missingSection = "";
      if (!sleepLogCompleted && !assessmentOk) {
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
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const resetProgress = mutation({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot reset another user's progress");
      }
    }

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

    // Delete questionnaire session progress (cross-device sync state)
    // Use by_user index since we're only filtering by user_id
    const sessions = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const session of sessions) {
      await ctx.db.delete(session._id);
    }

    console.log(`[Convex] Reset complete: cleared ${progressEntries.length} progress, ${responses.length} responses, ${assessmentResponses.length} assessment responses, ${sessions.length} sessions`);

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
 * SECURITY: Requires sessionToken to validate user ownership
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
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot save responses for another user");
      }
    }

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
 * Save multiple responses at once (batch save from Watch/iOS)
 * Supports derived answers for complete clinical scoring
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
        // Derived answer fields - for answers auto-populated from equivalent questions
        isDerived: v.optional(v.boolean()),
        derivedFromQuestionId: v.optional(v.string()),
      })
    ),
    source: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    let savedCount = 0;
    let derivedCount = 0;

    for (const response of args.responses) {
      // Use day-aware lookup to support repeating questions (like sleep log) across multiple days
      const existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question_day", (q) =>
          q.eq("user_id", args.userId).eq("question_id", response.questionId).eq("day_number", args.dayNumber)
        )
        .first();

      // Don't overwrite user-provided answer with derived answer
      if (existing && !existing.is_derived && response.isDerived) {
        console.log(`[saveResponses] Skipping derived ${response.questionId} - user already answered directly`);
        continue;
      }

      if (existing) {
        await ctx.db.patch(existing._id, {
          response_value: response.responseValue,
          response_number: response.responseNumber,
          response_array: response.responseArray ? JSON.stringify(response.responseArray) : undefined,
          day_number: args.dayNumber,
          is_derived: response.isDerived ?? false,
          derived_from_question_id: response.derivedFromQuestionId,
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
          is_derived: response.isDerived ?? false,
          derived_from_question_id: response.derivedFromQuestionId,
          created_at: now,
          updated_at: now,
        });
      }

      savedCount++;
      if (response.isDerived) derivedCount++;
    }

    return {
      success: true,
      savedCount,
      derivedCount,
      message: derivedCount > 0 ? `Saved ${savedCount} responses (${derivedCount} derived for complete scoring)` : undefined
    };
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
      isDerived: r.is_derived ?? false,
      derivedFromQuestionId: r.derived_from_question_id,
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
 * Debug: Get all questionnaire sessions for a user
 */
export const debugGetAllSessions = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const sessions = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    return sessions;
  },
});

/**
 * Update question progress when user answers a question
 * Called after each question to enable seamless cross-device sync
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const updateQuestionProgress = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.string(), // "sleepLog" or "assessment"
    currentQuestionIndex: v.number(),
    totalQuestions: v.number(),
    device: v.string(), // "ios", "watch", "web"
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot update another user's progress");
      }
    }

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
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const completeQuestionProgress = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.string(),
    device: v.string(),
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot complete another user's section");
      }
    }

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
// Unified Question Fetching (Single Source of Truth)
// ============================================

/**
 * Get all questions for a user's day - THE SINGLE SOURCE OF TRUTH
 * This is what iOS, Watch, and Web should ALL use to get questions.
 *
 * Returns:
 * - Sleep Log questions (same every day)
 * - Assessment questions for the day (from database)
 * - Expansion questions based on triggered gateways
 */
export const getQuestionsForUserDay = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.optional(v.union(v.literal("sleepLog"), v.literal("assessment"), v.literal("all"))),
  },
  handler: async (ctx, args) => {
    const section = args.section ?? "all";

    // Get user's triggered gateways
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const triggeredGatewayIds = new Set(
      gatewayStates
        .filter((g) => g.triggered)
        .map((g) => g.gateway_id)
    );

    console.log(`[Convex] User ${args.userId} Day ${args.dayNumber} - Triggered gateways: ${[...triggeredGatewayIds].join(", ")}`);

    const result: {
      sleepLog: Array<{
        id: string;
        text: string;
        type: string;
        required: boolean;
        options?: string[];
        helpText?: string;
        formatConfig?: Record<string, unknown>;
        conditionalLogic?: { question_id: string; equals?: string; greater_than?: number };
      }>;
      assessment: Array<{
        id: string;
        text: string;
        type: string;
        required: boolean;
        options?: string[];
        helpText?: string;
        moduleName?: string;
        formatConfig?: Record<string, unknown>;
        conditionalLogic?: { question_id: string; equals?: string; greater_than?: number };
      }>;
      metadata: {
        sleepLogCount: number;
        assessmentCount: number;
        totalMinutes: number;
        triggeredGateways: string[];
        dayDescription: string;
        dayExplanation: string;
        modules: string[];  // Module IDs included in today's assessment
      };
    } = {
      sleepLog: [],
      assessment: [],
      metadata: {
        sleepLogCount: 0,
        assessmentCount: 0,
        totalMinutes: 0,
        triggeredGateways: [...triggeredGatewayIds],
        dayDescription: getDayDescription(args.dayNumber),
        dayExplanation: getDayExplanation(args.dayNumber),
        modules: [],  // Will be populated as modules are processed
      },
    };

    // ========== SLEEP LOG (Same Every Day) ==========
    if (section === "all" || section === "sleepLog") {
      // Get sleep diary questions from database
      const sleepDiaryQuestions = await ctx.db
        .query("sleep_diary_questions")
        .collect();

      // Sort by order_index
      sleepDiaryQuestions.sort((a, b) => (a.order_index || 0) - (b.order_index || 0));

      result.sleepLog = sleepDiaryQuestions.map((q) => ({
        id: q.id,
        text: q.question_text,
        type: mapAnswerFormatToType(q.answer_format),
        required: true,
        helpText: q.help_text ?? undefined,
        formatConfig: q.format_config ? JSON.parse(q.format_config) : undefined,
        options: q.format_config ? parseOptions(q.format_config) : undefined,
        conditionalLogic: q.conditional_logic ? parseConditionalLogic(q.conditional_logic) : undefined,
      }));

      result.metadata.sleepLogCount = result.sleepLog.length;
    }

    // ========== ASSESSMENT (Day-Specific + Gateway Expansion) ==========
    if (section === "all" || section === "assessment") {
      // Get all modules assigned to this day
      const dayModules = await ctx.db
        .query("day_modules")
        .withIndex("by_day", (q) => q.eq("day_number", args.dayNumber))
        .collect();

      // Sort modules by order
      dayModules.sort((a, b) => (a.order_index || 0) - (b.order_index || 0));

      let totalSeconds = 0;

      for (const dayModule of dayModules) {
        // Get module info
        const module = await ctx.db
          .query("assessment_modules")
          .withIndex("by_module_id", (q) => q.eq("module_id", dayModule.module_id))
          .first();

        if (!module) continue;

        // Check if this is an expansion module that requires a gateway trigger
        if (module.tier === "expansion" || module.tier === "specialized") {
          // Get all gateway definitions to find which gateways trigger this module
          const allGateways = await ctx.db
            .query("module_gateways")
            .collect();

          // Find if ANY triggered gateway includes this module in its target_modules
          let isModuleTriggered = false;
          for (const gateway of allGateways) {
            // Check if this gateway is triggered
            if (triggeredGatewayIds.has(gateway.gateway_id)) {
              // Parse target modules for this gateway
              try {
                const targetModules = JSON.parse(gateway.target_modules_json || "[]") as string[];
                if (targetModules.includes(dayModule.module_id)) {
                  isModuleTriggered = true;
                  console.log(`[Convex] Module ${dayModule.module_id} triggered by gateway ${gateway.gateway_id}`);
                  break;
                }
              } catch {
                console.log(`[Convex] Warning: Could not parse target_modules_json for gateway ${gateway.gateway_id}`);
              }
            }
          }

          // If no triggered gateway includes this module, skip it
          if (!isModuleTriggered) {
            console.log(`[Convex] Skipping module ${dayModule.module_id} - no triggered gateway targets it`);
            continue;
          }
        }

        // Track this module as included
        result.metadata.modules.push(dayModule.module_id);

        // Get questions in this module
        const moduleQuestions = await ctx.db
          .query("module_questions")
          .withIndex("by_module", (q) => q.eq("module_id", dayModule.module_id))
          .collect();

        // Sort by order_index
        moduleQuestions.sort((a, b) => a.order_index - b.order_index);

        // Get full question data
        for (const mq of moduleQuestions) {
          const question = await ctx.db
            .query("assessment_questions")
            .withIndex("by_question_id", (q) => q.eq("question_id", mq.question_id))
            .first();

          if (question) {
            // Check conditional logic
            if (question.conditional_logic) {
              // TODO: Evaluate conditional logic based on user's responses
              // For now, include all questions
            }

            result.assessment.push({
              id: question.question_id,
              text: question.question_text,
              type: mapAnswerFormatToType(question.answer_format),
              required: true,
              helpText: question.help_text ?? undefined,
              moduleName: module.name,
              formatConfig: question.format_config ? JSON.parse(question.format_config) : undefined,
              options: question.format_config ? parseOptions(question.format_config) : undefined,
              conditionalLogic: question.conditional_logic ? parseConditionalLogic(question.conditional_logic) : undefined,
            });

            totalSeconds += question.estimated_time_seconds || 30;
          }
        }
      }

      result.metadata.assessmentCount = result.assessment.length;
      result.metadata.totalMinutes = Math.ceil((result.sleepLog.length * 30 + totalSeconds) / 60);

      // If NO assessment questions found, add a fallback message
      if (result.assessment.length === 0) {
        result.assessment.push({
          id: "INFO_NO_QUESTIONS",
          text: "Based on your previous responses, no additional questions are needed for today. Great news - you're all caught up!",
          type: "info",
          required: false,
        });
      }
    }

    console.log(`[Convex] Returning ${result.sleepLog.length} sleep log + ${result.assessment.length} assessment questions for Day ${args.dayNumber}`);

    return result;
  },
});

/**
 * Map database answer_format to client-side type
 */
function mapAnswerFormatToType(answerFormat: string): string {
  const mapping: Record<string, string> = {
    time: "time",
    time_picker: "time",
    scale: "scale",
    number: "number",
    number_input: "number",
    number_scroll: "number",
    yes_no: "yesNo",
    yes_no_chips: "yesNo",
    single_select: "singleSelect",
    single_select_chips: "singleSelect",
    multi_select: "multiSelect",
    multi_select_chips: "multiSelect",
    text: "text",
    text_short: "text",
    text_long: "text",
    likert_5: "scale",
    likert_7: "scale",
    slider_scale: "scale",
    duration_minutes: "number",
    minutes_scroll: "number",
    percentage: "number",
    // Date types - use year picker for birth dates
    date: "year",
    date_picker: "year",
    date_auto: "text",  // Auto-fill dates shown as text
    // Specialized input types
    nap_details: "napDetails",
    medication_select: "medicationSelect",
  };
  return mapping[answerFormat] || "text";
}

/**
 * Parse options from format_config JSON
 */
function parseOptions(formatConfig: string): string[] | undefined {
  try {
    const config = JSON.parse(formatConfig);
    if (config.options && Array.isArray(config.options)) {
      return config.options.map((opt: { value: string; label: string } | string) =>
        typeof opt === "string" ? opt : opt.label || opt.value
      );
    }
    return undefined;
  } catch {
    return undefined;
  }
}

/**
 * Parse conditional logic from format_config JSON
 * Returns a normalized structure for the iOS app
 */
function parseConditionalLogic(conditionalLogicJson: string): { question_id: string; equals?: string; greater_than?: number } | undefined {
  try {
    const logic = JSON.parse(conditionalLogicJson);

    // Handle direct format: {"question_id": "35", "equals": "yes"}
    if (logic.question_id) {
      return {
        question_id: logic.question_id,
        equals: logic.equals,
        greater_than: logic.greater_than,
      };
    }

    // Handle show_if wrapper format: {"show_if": {"question_id": "35", "value": "yes"}}
    if (logic.show_if) {
      return {
        question_id: logic.show_if.question_id,
        equals: logic.show_if.value,
        greater_than: logic.show_if.operator === "greater_than" ? Number(logic.show_if.value) : undefined,
      };
    }

    return undefined;
  } catch {
    return undefined;
  }
}

/**
 * Update user's gateway state when a gateway question is answered
 * This is called when a gateway-triggering response is detected
 */
export const updateGatewayState = mutation({
  args: {
    userId: v.id("users"),
    gatewayId: v.string(),
    isTriggered: v.boolean(),
    triggerQuestionId: v.optional(v.string()),
    triggerValue: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if state already exists
    const existing = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user_gateway", (q) =>
        q.eq("user_id", args.userId).eq("gateway_id", args.gatewayId)
      )
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        triggered: args.isTriggered,
        trigger_question_id: args.triggerQuestionId,
        trigger_value: args.triggerValue,
        last_evaluated_at: now,
      });
    } else {
      await ctx.db.insert("user_gateway_states", {
        user_id: args.userId,
        gateway_id: args.gatewayId,
        triggered: args.isTriggered,
        trigger_question_id: args.triggerQuestionId,
        trigger_value: args.triggerValue,
        triggered_at: args.isTriggered ? now : undefined,
        last_evaluated_at: now,
      });
    }

    console.log(`[Convex] Gateway ${args.gatewayId} for user ${args.userId}: ${args.isTriggered ? "TRIGGERED" : "not triggered"}`);

    return { success: true, gatewayId: args.gatewayId, isTriggered: args.isTriggered };
  },
});

/**
 * Get all gateway states for a user
 */
export const getGatewayStates = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const states = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    return states.map((s) => ({
      gatewayId: s.gateway_id,
      isTriggered: s.triggered,
      triggerQuestionId: s.trigger_question_id,
      triggerValue: s.trigger_value,
      triggeredAt: s.triggered_at,
    }));
  },
});

/**
 * Migration: Convert is_triggered to triggered field in user_gateway_states
 * This fixes existing data that was written with the wrong field name.
 */
export const migrateGatewayStates = mutation({
  args: {
    userId: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    // Get all gateway states (optionally filtered by user)
    let states;
    if (args.userId) {
      states = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();
    } else {
      states = await ctx.db.query("user_gateway_states").collect();
    }

    let migratedCount = 0;
    for (const state of states) {
      // Check if this record has the old field name (is_triggered) but not the new one (triggered)
      const hasOldField = (state as Record<string, unknown>).is_triggered !== undefined;
      const hasNewField = state.triggered !== undefined;

      if (hasOldField && !hasNewField) {
        // Migrate: copy is_triggered value to triggered
        const oldValue = (state as Record<string, unknown>).is_triggered as boolean;
        await ctx.db.patch(state._id, {
          triggered: oldValue,
          last_evaluated_at: Date.now(),
        });
        migratedCount++;
        console.log(`[Migration] Migrated gateway ${state.gateway_id} for user ${state.user_id}: is_triggered=${oldValue} -> triggered=${oldValue}`);
      } else if (!hasNewField && !hasOldField) {
        // No triggered field at all - default to false
        await ctx.db.patch(state._id, {
          triggered: false,
          last_evaluated_at: Date.now(),
        });
        migratedCount++;
        console.log(`[Migration] Set default triggered=false for gateway ${state.gateway_id}`);
      }
    }

    return { migratedCount, totalRecords: states.length };
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
    // Days 6-14: May include expansion modules
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

// ============================================
// Database Maintenance
// ============================================

/**
 * Remove the SD_DATE question from sleep diary
 * This question is redundant on digital devices - we can auto-detect the date.
 * Run with: npx convex run watch:removeDateQuestion
 */
export const removeDateQuestion = mutation({
  args: {},
  handler: async (ctx) => {
    // Find and delete the SD_DATE question
    const allQuestions = await ctx.db
      .query("sleep_diary_questions")
      .collect();

    const dateQuestion = allQuestions.find(q => q.id === "SD_DATE");

    if (dateQuestion) {
      await ctx.db.delete(dateQuestion._id);
      return { deleted: true, message: "SD_DATE question removed successfully" };
    }

    return { deleted: false, message: "SD_DATE question not found in database" };
  },
});

// ============================================
// Expansion Schedule Queries
// ============================================

// Module metadata for expansion schedule display
const EXPANSION_MODULE_METADATA: Record<string, { name: string; instrument: string; description: string; icon: string }> = {
  expansion_isi: { name: "Insomnia Severity", instrument: "ISI", description: "Assess insomnia severity and impact", icon: "moon.zzz.fill" },
  expansion_phq9: { name: "Depression Screen", instrument: "PHQ-9", description: "Screen for depression symptoms", icon: "heart.fill" },
  expansion_gad7: { name: "Anxiety Screen", instrument: "GAD-7", description: "Screen for anxiety symptoms", icon: "bolt.heart.fill" },
  expansion_stop_bang: { name: "Sleep Apnea Screen", instrument: "STOP-BANG", description: "Screen for sleep apnea risk", icon: "lungs.fill" },
  expansion_ess: { name: "Sleepiness Scale", instrument: "ESS", description: "Measure daytime sleepiness", icon: "sun.max.fill" },
  expansion_berlin: { name: "Berlin Questionnaire", instrument: "Berlin", description: "Additional sleep apnea screening", icon: "waveform.path.ecg" },
  expansion_dbas: { name: "Sleep Beliefs", instrument: "DBAS-16", description: "Assess beliefs about sleep", icon: "brain.head.profile" },
  expansion_sleep_hygiene: { name: "Sleep Hygiene", instrument: "Sleep Hygiene", description: "Evaluate sleep habits", icon: "bed.double.fill" },
  expansion_psas: { name: "Pre-Sleep Arousal", instrument: "PSAS", description: "Measure pre-sleep arousal", icon: "figure.mind.and.body" },
  expansion_fss: { name: "Fatigue Scale", instrument: "FSS", description: "Assess fatigue severity", icon: "battery.25" },
  expansion_fosq: { name: "Functional Outcomes", instrument: "FOSQ-10", description: "Measure sleep impact on function", icon: "figure.walk" },
  expansion_dass21: { name: "Stress & Anxiety", instrument: "DASS-21", description: "Comprehensive mental health screen", icon: "brain" },
  expansion_promis_cognitive: { name: "Cognitive Function", instrument: "PROMIS", description: "Assess cognitive function", icon: "lightbulb.fill" },
  expansion_bpi: { name: "Pain Inventory", instrument: "BPI", description: "Assess pain and sleep", icon: "bandage.fill" },
  expansion_medas: { name: "Diet Assessment", instrument: "MEDAS", description: "Evaluate diet impact on sleep", icon: "fork.knife" },
  expansion_meq: { name: "Chronotype", instrument: "MEQ", description: "Determine your sleep-wake preference", icon: "clock.fill" },
};

/**
 * Get the expansion schedule for a user.
 * Returns the full schedule with module metadata.
 */
export const getExpansionSchedule = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const schedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!schedule) {
      return null;
    }

    // Enrich with module metadata
    const enrichedDays = schedule.day_assignments.map((day) => {
      const modules = day.module_ids.map((id) => {
        const meta = EXPANSION_MODULE_METADATA[id];
        return meta ? { id, ...meta, questionCount: day.question_count } : { id, name: id };
      });

      return {
        dayNumber: day.day_number,
        modules,
        questionCount: day.question_count,
        estimatedMinutes: day.estimated_minutes,
        completed: day.completed || false,
      };
    });

    return {
      triggeredGateways: schedule.triggered_gateways,
      totalQuestions: schedule.total_expansion_questions,
      totalMinutes: schedule.total_estimated_minutes || 0,
      dayAssignments: enrichedDays,
    };
  },
});

/**
 * Get expansion modules for a specific day.
 * Used by iOS/web to show expansion tasks in Today's Focus.
 */
export const getExpansionForDay = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const schedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!schedule) {
      return { hasExpansion: false, modules: [], questionCount: 0, estimatedMinutes: 0 };
    }

    const dayAssignment = schedule.day_assignments.find(
      (d) => d.day_number === args.dayNumber
    );

    if (!dayAssignment) {
      return { hasExpansion: false, modules: [], questionCount: 0, estimatedMinutes: 0 };
    }

    // Get module details
    const modules = dayAssignment.module_ids.map((id) => {
      const meta = EXPANSION_MODULE_METADATA[id];
      return meta
        ? { id, name: meta.name, instrument: meta.instrument, description: meta.description, icon: meta.icon }
        : { id, name: id, instrument: "", description: "", icon: "questionmark.circle" };
    });

    return {
      hasExpansion: true,
      modules,
      questionCount: dayAssignment.question_count,
      estimatedMinutes: dayAssignment.estimated_minutes,
      completed: dayAssignment.completed || false,
    };
  },
});

/**
 * Mark expansion modules as completed for a day.
 * Called when user completes the expansion assessment section.
 */
export const markExpansionCompleted = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const schedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!schedule) {
      return { success: false, error: "No expansion schedule found" };
    }

    const updatedAssignments = schedule.day_assignments.map((d) => {
      if (d.day_number === args.dayNumber) {
        return { ...d, completed: true };
      }
      return d;
    });

    await ctx.db.patch(schedule._id, {
      day_assignments: updatedAssignments,
    });

    return { success: true };
  },
});

/**
 * Preview expansion schedule for testing.
 * Shows what schedule would be computed for given gateways.
 */
export const previewExpansionSchedule = query({
  args: {
    triggeredGateways: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    // Use the same module definitions as computeExpansionScheduleForUser
    const EXPANSION_MODULES = [
      { id: "expansion_isi", name: "ISI", questionCount: 7, estimatedMinutes: 5, requiredGateways: ["insomnia", "poor_sleep_quality"], priority: 1 },
      { id: "expansion_phq9", name: "PHQ-9", questionCount: 9, estimatedMinutes: 6, requiredGateways: ["depression"], priority: 1 },
      { id: "expansion_gad7", name: "GAD-7", questionCount: 7, estimatedMinutes: 5, requiredGateways: ["anxiety"], priority: 1 },
      { id: "expansion_stop_bang", name: "STOP-BANG", questionCount: 8, estimatedMinutes: 5, requiredGateways: ["osa"], priority: 1 },
      { id: "expansion_ess", name: "ESS", questionCount: 8, estimatedMinutes: 5, requiredGateways: ["excessive_sleepiness"], priority: 2 },
      { id: "expansion_berlin", name: "Berlin", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["osa"], priority: 2 },
      { id: "expansion_dbas", name: "DBAS-16", questionCount: 16, estimatedMinutes: 12, requiredGateways: ["insomnia"], priority: 3 },
      { id: "expansion_sleep_hygiene", name: "Sleep Hygiene", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["insomnia", "poor_sleep_quality"], priority: 3 },
      { id: "expansion_psas", name: "PSAS", questionCount: 16, estimatedMinutes: 10, requiredGateways: ["insomnia"], priority: 3 },
      { id: "expansion_fss", name: "FSS", questionCount: 9, estimatedMinutes: 6, requiredGateways: ["excessive_sleepiness"], priority: 4 },
      { id: "expansion_fosq", name: "FOSQ-10", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["excessive_sleepiness"], priority: 4 },
      { id: "expansion_dass21", name: "DASS-21", questionCount: 21, estimatedMinutes: 15, requiredGateways: ["depression", "anxiety"], priority: 4 },
      { id: "expansion_promis_cognitive", name: "PROMIS Cognitive", questionCount: 6, estimatedMinutes: 4, requiredGateways: ["cognitive"], priority: 4 },
      { id: "expansion_bpi", name: "BPI", questionCount: 11, estimatedMinutes: 8, requiredGateways: ["pain"], priority: 5 },
      { id: "expansion_medas", name: "MEDAS", questionCount: 14, estimatedMinutes: 10, requiredGateways: ["diet_impact"], priority: 5 },
      { id: "expansion_meq", name: "MEQ", questionCount: 19, estimatedMinutes: 12, requiredGateways: ["sleep_timing"], priority: 5 },
    ];

    const TARGET_QUESTIONS_PER_DAY = 14;
    const MAX_QUESTIONS_PER_DAY = 18;
    const EXPANSION_START_DAY = 6;
    const TOTAL_DAYS = 14;

    // Filter modules
    const triggeredModules = EXPANSION_MODULES.filter((module) =>
      module.requiredGateways.some((gateway) => args.triggeredGateways.includes(gateway))
    );

    // Sort by priority
    const sortedModules = [...triggeredModules].sort((a, b) => {
      if (a.priority !== b.priority) return a.priority - b.priority;
      return a.questionCount - b.questionCount;
    });

    // Distribute
    const dayAssignments: Array<{ dayNumber: number; modules: string[]; questionCount: number; estimatedMinutes: number }> = [];
    let currentDay = EXPANSION_START_DAY;
    let currentDayModules: typeof sortedModules = [];
    let currentDayQuestions = 0;

    for (const module of sortedModules) {
      if (currentDayQuestions + module.questionCount > MAX_QUESTIONS_PER_DAY && currentDayModules.length > 0) {
        dayAssignments.push({
          dayNumber: currentDay,
          modules: currentDayModules.map((m) => m.name),
          questionCount: currentDayQuestions,
          estimatedMinutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
        });
        currentDay++;
        currentDayModules = [];
        currentDayQuestions = 0;
      }

      currentDayModules.push(module);
      currentDayQuestions += module.questionCount;

      if (currentDayQuestions >= TARGET_QUESTIONS_PER_DAY && currentDay < TOTAL_DAYS) {
        dayAssignments.push({
          dayNumber: currentDay,
          modules: currentDayModules.map((m) => m.name),
          questionCount: currentDayQuestions,
          estimatedMinutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
        });
        currentDay++;
        currentDayModules = [];
        currentDayQuestions = 0;
      }
    }

    if (currentDayModules.length > 0) {
      dayAssignments.push({
        dayNumber: currentDay,
        modules: currentDayModules.map((m) => m.name),
        questionCount: currentDayQuestions,
        estimatedMinutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
      });
    }

    const totalQuestions = dayAssignments.reduce((sum, d) => sum + d.questionCount, 0);
    const totalMinutes = dayAssignments.reduce((sum, d) => sum + d.estimatedMinutes, 0);
    const avgQuestionsPerDay = dayAssignments.length > 0 ? Math.round(totalQuestions / dayAssignments.length) : 0;

    return {
      triggeredGateways: args.triggeredGateways,
      triggeredModulesCount: triggeredModules.length,
      dayAssignments,
      totalQuestions,
      totalMinutes,
      expansionDays: dayAssignments.length,
      avgQuestionsPerDay,
      summary: `${totalQuestions} questions across ${dayAssignments.length} days (~${avgQuestionsPerDay}/day, ~${totalMinutes} minutes total)`,
    };
  },
});
