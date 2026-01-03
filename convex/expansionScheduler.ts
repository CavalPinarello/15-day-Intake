/**
 * Expansion Pack Scheduler
 *
 * Simplified to use the FIXED_SCHEDULE from fixedSchedule.ts.
 * No more dynamic bin-packing - each day has predetermined content.
 *
 * This file provides:
 * - Module metadata (EXPANSION_MODULES)
 * - Schedule summary queries for iOS display
 * - Legacy queries for backward compatibility
 */

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import {
  FIXED_SCHEDULE,
  getDayConfig,
  shouldShowExpansion,
  getUpcomingAssessmentDays,
  PACK_TO_MODULE_IDS,
  type ExpansionPackId,
} from "./fixedSchedule";

// ============================================
// Expansion Module Metadata
// (Kept for reference and splash screen info)
// ============================================

export interface ExpansionModule {
  id: string;
  name: string;
  instrument: string;
  questionCount: number;
  estimatedMinutes: number;
  requiredGateways: string[];
  priority: number;
}

export const EXPANSION_MODULES: ExpansionModule[] = [
  // Priority 1: Clinical urgency
  {
    id: "expansion_isi",
    name: "Insomnia Severity Index",
    instrument: "ISI",
    questionCount: 7,
    estimatedMinutes: 5,
    requiredGateways: ["insomnia", "poor_sleep_quality"],
    priority: 1,
  },
  {
    id: "expansion_phq9",
    name: "Depression Screen",
    instrument: "PHQ-9",
    questionCount: 9,
    estimatedMinutes: 6,
    requiredGateways: ["depression"],
    priority: 1,
  },
  {
    id: "expansion_gad7",
    name: "Anxiety Screen",
    instrument: "GAD-7",
    questionCount: 7,
    estimatedMinutes: 5,
    requiredGateways: ["anxiety"],
    priority: 1,
  },
  // Legacy split modules kept for backwards compatibility
  {
    id: "expansion_gad7_part1",
    name: "Anxiety Screen (Part 1)",
    instrument: "GAD-7",
    questionCount: 4,
    estimatedMinutes: 3,
    requiredGateways: ["anxiety"],
    priority: 1,
  },
  {
    id: "expansion_gad7_part2",
    name: "Anxiety Screen (Part 2)",
    instrument: "GAD-7",
    questionCount: 3,
    estimatedMinutes: 2,
    requiredGateways: ["anxiety"],
    priority: 1,
  },
  {
    id: "expansion_stop_bang",
    name: "Sleep Apnea Screen",
    instrument: "STOP-BANG",
    questionCount: 8,
    estimatedMinutes: 5,
    requiredGateways: ["osa"],
    priority: 1,
  },

  // Priority 2: Sleep-specific
  {
    id: "expansion_ess",
    name: "Epworth Sleepiness Scale",
    instrument: "ESS",
    questionCount: 8,
    estimatedMinutes: 5,
    requiredGateways: ["excessive_sleepiness"],
    priority: 2,
  },
  {
    id: "expansion_berlin",
    name: "Berlin Questionnaire",
    instrument: "Berlin",
    questionCount: 10,
    estimatedMinutes: 7,
    requiredGateways: ["osa"],
    priority: 2,
  },
  {
    id: "expansion_swdsq",
    name: "Shift Work Disorder Screening",
    instrument: "SWDSQ",
    questionCount: 4,
    estimatedMinutes: 3,
    requiredGateways: ["shift_work"],
    priority: 2,
  },

  // Priority 3: Behavioral & cognitive
  {
    id: "expansion_dbas6",
    name: "Sleep Beliefs (DBAS-6)",
    instrument: "DBAS-6",
    questionCount: 6,
    estimatedMinutes: 4,
    requiredGateways: ["insomnia"],
    priority: 3,
  },
  // Legacy DBAS-16 split modules kept for backwards compatibility
  {
    id: "expansion_dbas_part1",
    name: "Sleep Beliefs (Part 1)",
    instrument: "DBAS-16",
    questionCount: 8,
    estimatedMinutes: 6,
    requiredGateways: ["insomnia"],
    priority: 3,
  },
  {
    id: "expansion_dbas_part2",
    name: "Sleep Beliefs (Part 2)",
    instrument: "DBAS-16",
    questionCount: 8,
    estimatedMinutes: 6,
    requiredGateways: ["insomnia"],
    priority: 3,
  },
  {
    id: "expansion_sleep_hygiene_part1",
    name: "Sleep Hygiene (Part 1)",
    instrument: "Sleep Hygiene",
    questionCount: 5,
    estimatedMinutes: 4,
    requiredGateways: ["insomnia", "poor_sleep_quality"],
    priority: 3,
  },
  {
    id: "expansion_sleep_hygiene_part2",
    name: "Sleep Hygiene (Part 2)",
    instrument: "Sleep Hygiene",
    questionCount: 5,
    estimatedMinutes: 4,
    requiredGateways: ["insomnia", "poor_sleep_quality"],
    priority: 3,
  },
  {
    id: "expansion_psas_cognitive",
    name: "Pre-Sleep Arousal (Cognitive)",
    instrument: "PSAS",
    questionCount: 8,
    estimatedMinutes: 5,
    requiredGateways: ["insomnia", "anxiety"],
    priority: 3,
  },
  {
    id: "expansion_psas_somatic",
    name: "Pre-Sleep Arousal (Somatic)",
    instrument: "PSAS",
    questionCount: 8,
    estimatedMinutes: 5,
    requiredGateways: ["insomnia", "anxiety"],
    priority: 3,
  },

  // Priority 4: Functional & fatigue
  {
    id: "expansion_fss",
    name: "Fatigue Severity Scale",
    instrument: "FSS",
    questionCount: 9,
    estimatedMinutes: 6,
    requiredGateways: ["excessive_sleepiness"],
    priority: 4,
  },
  {
    id: "expansion_fosq_part1",
    name: "Functional Outcomes (Part 1)",
    instrument: "FOSQ-10",
    questionCount: 5,
    estimatedMinutes: 4,
    requiredGateways: ["excessive_sleepiness"],
    priority: 4,
  },
  {
    id: "expansion_fosq_part2",
    name: "Functional Outcomes (Part 2)",
    instrument: "FOSQ-10",
    questionCount: 5,
    estimatedMinutes: 4,
    requiredGateways: ["excessive_sleepiness"],
    priority: 4,
  },
  {
    id: "expansion_promis_cognitive",
    name: "Cognitive Function",
    instrument: "PROMIS Cognitive",
    questionCount: 6,
    estimatedMinutes: 4,
    requiredGateways: ["cognitive"],
    priority: 4,
  },

  // Priority 5: Lifestyle
  {
    id: "expansion_bpi_part1",
    name: "Brief Pain Inventory (Part 1)",
    instrument: "BPI",
    questionCount: 6,
    estimatedMinutes: 4,
    requiredGateways: ["pain"],
    priority: 5,
  },
  {
    id: "expansion_bpi_part2",
    name: "Brief Pain Inventory (Part 2)",
    instrument: "BPI",
    questionCount: 5,
    estimatedMinutes: 4,
    requiredGateways: ["pain"],
    priority: 5,
  },
  {
    id: "expansion_medas",
    name: "Mediterranean Diet Assessment",
    instrument: "MEDAS",
    questionCount: 14,
    estimatedMinutes: 10,
    requiredGateways: ["diet_impact"],
    priority: 5,
  },
  {
    id: "expansion_meq_part1",
    name: "Chronotype (Part 1)",
    instrument: "MEQ",
    questionCount: 10,
    estimatedMinutes: 6,
    requiredGateways: ["sleep_timing"],
    priority: 5,
  },
  {
    id: "expansion_meq_part2",
    name: "Chronotype (Part 2)",
    instrument: "MEQ",
    questionCount: 9,
    estimatedMinutes: 6,
    requiredGateways: ["sleep_timing"],
    priority: 5,
  },
];

// ============================================
// Schedule Queries (Using Fixed Schedule)
// ============================================

/**
 * Get expansion schedule summary for a user.
 * Now uses FIXED_SCHEDULE instead of dynamic computation.
 */
export const getScheduleSummary = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    // Get user's triggered gateways
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const triggeredGateways = gatewayStates
      .filter((g) => g.triggered)
      .map((g) => g.gateway_id);

    if (triggeredGateways.length === 0) {
      return {
        hasSchedule: false,
        triggeredGateways: [],
        totalDays: 0,
        totalQuestions: 0,
        totalMinutes: 0,
        completedDays: 0,
        remainingDays: 0,
        gatewaySchedule: {},
        dayAssignments: [],
      };
    }

    // Use fixed schedule to determine which days have content
    const upcomingDays = getUpcomingAssessmentDays(triggeredGateways);

    // Build gateway -> day mapping from fixed schedule
    const gatewaySchedule: Record<string, number> = {};
    for (const item of upcomingDays) {
      if (!gatewaySchedule[item.gateway]) {
        gatewaySchedule[item.gateway] = item.dayNumber;
      }
    }

    // Build day assignments from fixed schedule
    const dayAssignments: {
      dayNumber: number;
      questionCount: number;
      estimatedMinutes: number;
      completed: boolean;
      splashTitle: string;
    }[] = [];

    // Get user's day completion status from user_progress table
    // Note: user_progress uses day_id (from days table), so we need to look up days first
    const days = await ctx.db.query("days").collect();
    const dayIdToNumber = new Map(days.map((d) => [d._id.toString(), d.day_number]));

    const progressRecords = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const completedDayNumbers = new Set(
      progressRecords
        .filter((p) => p.completed)
        .map((p) => dayIdToNumber.get(p.day_id.toString()))
        .filter((n): n is number => n !== undefined)
    );

    for (let day = 6; day <= 10; day++) {
      if (shouldShowExpansion(day, triggeredGateways)) {
        const config = FIXED_SCHEDULE[day];
        if (config && config.type === "expansion") {
          dayAssignments.push({
            dayNumber: day,
            questionCount: config.totalQuestions,
            estimatedMinutes: config.estimatedMinutes,
            completed: completedDayNumbers.has(day),
            splashTitle: config.splashTitle,
          });
        }
      }
    }

    const totalQuestions = dayAssignments.reduce((sum, d) => sum + d.questionCount, 0);
    const totalMinutes = dayAssignments.reduce((sum, d) => sum + d.estimatedMinutes, 0);
    const completedDays = dayAssignments.filter((d) => d.completed).length;

    return {
      hasSchedule: dayAssignments.length > 0,
      triggeredGateways,
      totalDays: dayAssignments.length,
      totalQuestions,
      totalMinutes,
      completedDays,
      remainingDays: dayAssignments.length - completedDays,
      gatewaySchedule,
      dayAssignments,
    };
  },
});

/**
 * Get expansion info for a specific day using fixed schedule.
 */
export const getExpansionForDay = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const config = getDayConfig(args.dayNumber);
    if (!config || config.type !== "expansion") {
      return null;
    }

    // Get user's triggered gateways
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const triggeredGateways = gatewayStates
      .filter((g) => g.triggered)
      .map((g) => g.gateway_id);

    // Check if this day should show for user
    if (!shouldShowExpansion(args.dayNumber, triggeredGateways)) {
      return null;
    }

    // Get module details for the packs
    const modules: {
      id: string;
      name: string;
      instrument: string;
      questionCount: number;
      estimatedMinutes: number;
    }[] = [];

    for (const packId of config.packs) {
      const moduleIds = PACK_TO_MODULE_IDS[packId as ExpansionPackId] || [];
      for (const moduleId of moduleIds) {
        const module = EXPANSION_MODULES.find((m) => m.id === moduleId);
        if (module) {
          modules.push({
            id: module.id,
            name: module.name,
            instrument: module.instrument,
            questionCount: module.questionCount,
            estimatedMinutes: module.estimatedMinutes,
          });
        }
      }
    }

    // Check completion status using user_progress table
    const days = await ctx.db.query("days").collect();
    const dayRecord = days.find((d) => d.day_number === args.dayNumber);

    let completed = false;
    if (dayRecord) {
      const progress = await ctx.db
        .query("user_progress")
        .withIndex("by_user_day", (q) =>
          q.eq("user_id", args.userId).eq("day_id", dayRecord._id)
        )
        .first();
      completed = progress?.completed ?? false;
    }

    return {
      dayNumber: args.dayNumber,
      splashTitle: config.splashTitle,
      splashSubtitle: config.splashSubtitle,
      modules,
      totalQuestions: config.totalQuestions,
      estimatedMinutes: config.estimatedMinutes,
      completed,
      gateways: config.gateways,
    };
  },
});

/**
 * Get the fixed schedule for a specific day.
 * Useful for splash screens and UI display.
 */
export const getDayScheduleInfo = query({
  args: {
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const config = getDayConfig(args.dayNumber);
    if (!config) {
      return null;
    }

    return {
      dayNumber: args.dayNumber,
      type: config.type,
      splashTitle: config.splashTitle,
      splashSubtitle: config.splashSubtitle,
      estimatedMinutes: config.estimatedMinutes,
      ...(config.type === "expansion" && {
        packs: config.packs,
        gateways: config.gateways,
        totalQuestions: config.totalQuestions,
      }),
      ...(config.type === "core" && {
        theme: config.theme,
      }),
    };
  },
});

/**
 * Preview the full fixed schedule (for debugging).
 */
export const previewFixedSchedule = query({
  args: {
    triggeredGateways: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    const schedule: {
      dayNumber: number;
      type: string;
      splashTitle: string;
      hasContent: boolean;
      packs?: string[];
      theme?: string;
    }[] = [];

    for (let day = 1; day <= 10; day++) {
      const config = getDayConfig(day);
      if (!config) continue;

      if (config.type === "core") {
        schedule.push({
          dayNumber: day,
          type: "core",
          splashTitle: config.splashTitle,
          hasContent: true,
          theme: config.theme,
        });
      } else {
        const hasContent = shouldShowExpansion(day, args.triggeredGateways);
        schedule.push({
          dayNumber: day,
          type: "expansion",
          splashTitle: config.splashTitle,
          hasContent,
          packs: config.packs,
        });
      }
    }

    return {
      triggeredGateways: args.triggeredGateways,
      schedule,
      activeDays: schedule.filter((s) => s.hasContent).length,
    };
  },
});

// ============================================
// Legacy Mutations (Deprecated)
// ============================================

/**
 * @deprecated - No longer needed with fixed schedule
 * Kept for backward compatibility but does nothing
 */
export const computeAndStoreSchedule = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    console.log(
      `[ExpansionScheduler] computeAndStoreSchedule called for user ${args.userId} - now using fixed schedule, no computation needed`
    );
    return {
      message: "Using fixed schedule - no dynamic computation needed",
      triggeredGateways: [],
      dayAssignments: [],
      totalQuestions: 0,
      totalMinutes: 0,
    };
  },
});

/**
 * @deprecated - Legacy query, kept for backward compatibility
 */
export const getSchedule = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    // Redirect to new getScheduleSummary
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const triggeredGateways = gatewayStates
      .filter((g) => g.triggered)
      .map((g) => g.gateway_id);

    if (triggeredGateways.length === 0) {
      return null;
    }

    const dayAssignments: {
      day_number: number;
      module_ids: string[];
      question_count: number;
      estimated_minutes: number;
      completed: boolean;
    }[] = [];

    for (let day = 6; day <= 10; day++) {
      if (shouldShowExpansion(day, triggeredGateways)) {
        const config = FIXED_SCHEDULE[day];
        if (config && config.type === "expansion") {
          const moduleIds: string[] = [];
          for (const packId of config.packs) {
            const packModules = PACK_TO_MODULE_IDS[packId as ExpansionPackId] || [];
            moduleIds.push(...packModules);
          }
          dayAssignments.push({
            day_number: day,
            module_ids: moduleIds,
            question_count: config.totalQuestions,
            estimated_minutes: config.estimatedMinutes,
            completed: false,
          });
        }
      }
    }

    return {
      triggered_gateways: triggeredGateways,
      day_assignments: dayAssignments,
      total_expansion_questions: dayAssignments.reduce((s, d) => s + d.question_count, 0),
      total_estimated_minutes: dayAssignments.reduce((s, d) => s + d.estimated_minutes, 0),
    };
  },
});

/**
 * @deprecated - Legacy mutation, kept for backward compatibility
 */
export const markDayExpansionCompleted = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    console.log(
      `[ExpansionScheduler] markDayExpansionCompleted called for user ${args.userId} day ${args.dayNumber}`
    );
    // Day completion is now tracked in user_day_completions table
    return { success: true };
  },
});
