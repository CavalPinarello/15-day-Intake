/**
 * Dynamic Expansion Pack Scheduler
 *
 * This module computes an optimal distribution of expansion questionnaires
 * based on which gateways were triggered during the core assessment (Days 1-2).
 *
 * Key principles:
 * 1. All gateway trigger questions are asked by Day 2
 * 2. Expansion schedule is computed when Day 2 completes
 * 3. Modules are distributed across Days 3-15 with target of 12-15 questions/day
 * 4. Clinical priority modules come first (ISI, PHQ-9, GAD-7)
 * 5. Related modules are grouped when possible
 */

import { mutation, query, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

// ============================================
// Expansion Module Definitions
// ============================================

export interface ExpansionModule {
  id: string;
  name: string;
  instrument: string;
  questionCount: number;
  estimatedMinutes: number;
  requiredGateways: string[];  // ANY of these gateways triggers this module
  priority: number;  // 1 = highest (clinical urgency), 5 = lowest
  groupWith?: string[];  // Module IDs that should stay together if possible
}

export const EXPANSION_MODULES: ExpansionModule[] = [
  // Priority 1: Clinical urgency - these inform immediate treatment decisions
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
    // Note: We combine GAD-7 Part 1 (4) + Part 2 (3) = 7 total
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

  // Priority 2: Sleep-specific assessments
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

  // Priority 3: Behavioral & cognitive assessments
  {
    id: "expansion_dbas",
    name: "Sleep Beliefs Assessment",
    instrument: "DBAS-16",
    questionCount: 16,
    estimatedMinutes: 12,
    requiredGateways: ["insomnia"],
    priority: 3,
    // Combined Part 1 (8) + Part 2 (8) = 16 total
  },
  {
    id: "expansion_sleep_hygiene",
    name: "Sleep Hygiene Assessment",
    instrument: "Sleep Hygiene",
    questionCount: 10,
    estimatedMinutes: 7,
    requiredGateways: ["insomnia", "poor_sleep_quality"],
    priority: 3,
    // Combined Part 1 (5) + Part 2 (5) = 10 total
  },
  {
    id: "expansion_psas",
    name: "Pre-Sleep Arousal Scale",
    instrument: "PSAS",
    questionCount: 16,
    estimatedMinutes: 10,
    requiredGateways: ["insomnia"],
    priority: 3,
    // Combined Cognitive (8) + Somatic (8) = 16 total
  },

  // Priority 4: Functional & fatigue assessments
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
    id: "expansion_fosq",
    name: "Functional Outcomes of Sleep",
    instrument: "FOSQ-10",
    questionCount: 10,
    estimatedMinutes: 7,
    requiredGateways: ["excessive_sleepiness"],
    priority: 4,
    // Combined Part 1 (5) + Part 2 (5) = 10 total
  },
  {
    id: "expansion_dass21",
    name: "Depression Anxiety Stress Scale",
    instrument: "DASS-21",
    questionCount: 21,
    estimatedMinutes: 15,
    requiredGateways: ["depression", "anxiety"],
    priority: 4,
    // Combined Part 1 (11) + Part 2 (10) = 21 total
  },
  {
    id: "expansion_promis_cognitive",
    name: "Cognitive Function Assessment",
    instrument: "PROMIS Cognitive",
    questionCount: 6,
    estimatedMinutes: 4,
    requiredGateways: ["cognitive"],
    priority: 4,
  },

  // Priority 5: Lifestyle & secondary assessments
  {
    id: "expansion_bpi",
    name: "Brief Pain Inventory",
    instrument: "BPI",
    questionCount: 11,
    estimatedMinutes: 8,
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
    id: "expansion_meq",
    name: "Chronotype Assessment",
    instrument: "MEQ",
    questionCount: 19,
    estimatedMinutes: 12,
    requiredGateways: ["sleep_timing"],
    priority: 5,
  },
];

// ============================================
// Schedule Computation
// ============================================

interface DayAssignment {
  dayNumber: number;
  moduleIds: string[];
  questionCount: number;
  estimatedMinutes: number;
}

/**
 * Compute the optimal expansion schedule based on triggered gateways.
 *
 * Algorithm:
 * 1. Filter modules to only those triggered by user's gateways
 * 2. Sort by priority (clinical urgency first)
 * 3. Distribute across available days (3-15 = 13 days)
 * 4. Target 12-15 questions per day, never exceed 18
 * 5. Keep total daily time under 15 minutes
 */
export function computeExpansionSchedule(triggeredGateways: string[]): DayAssignment[] {
  const TARGET_QUESTIONS_PER_DAY = 14;
  const MAX_QUESTIONS_PER_DAY = 18;
  const EXPANSION_START_DAY = 6;  // Start expansions on Day 6 (core days 1-5)
  const TOTAL_DAYS = 15;

  // 1. Get modules triggered by user's gateways
  const triggeredModules = EXPANSION_MODULES.filter(module =>
    module.requiredGateways.some(gateway => triggeredGateways.includes(gateway))
  );

  if (triggeredModules.length === 0) {
    return [];
  }

  // 2. Sort by priority (lower = higher priority)
  const sortedModules = [...triggeredModules].sort((a, b) => {
    if (a.priority !== b.priority) return a.priority - b.priority;
    // Same priority: put smaller modules first for better packing
    return a.questionCount - b.questionCount;
  });

  // 3. Calculate total questions and ideal distribution
  const totalQuestions = sortedModules.reduce((sum, m) => sum + m.questionCount, 0);
  const availableDays = TOTAL_DAYS - EXPANSION_START_DAY + 1; // Days 3-15 = 13 days
  const idealQuestionsPerDay = Math.ceil(totalQuestions / availableDays);

  // 4. Distribute modules across days using bin-packing
  const dayAssignments: DayAssignment[] = [];
  let currentDay = EXPANSION_START_DAY;
  let currentDayModules: ExpansionModule[] = [];
  let currentDayQuestions = 0;

  for (const module of sortedModules) {
    // Check if adding this module exceeds the day limit
    if (currentDayQuestions + module.questionCount > MAX_QUESTIONS_PER_DAY && currentDayModules.length > 0) {
      // Save current day and start a new one
      dayAssignments.push({
        dayNumber: currentDay,
        moduleIds: currentDayModules.map(m => m.id),
        questionCount: currentDayQuestions,
        estimatedMinutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
      });
      currentDay++;
      currentDayModules = [];
      currentDayQuestions = 0;
    }

    // Add module to current day
    currentDayModules.push(module);
    currentDayQuestions += module.questionCount;

    // If we've reached a good stopping point (near target), start new day
    if (currentDayQuestions >= TARGET_QUESTIONS_PER_DAY && currentDay < TOTAL_DAYS) {
      dayAssignments.push({
        dayNumber: currentDay,
        moduleIds: currentDayModules.map(m => m.id),
        questionCount: currentDayQuestions,
        estimatedMinutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
      });
      currentDay++;
      currentDayModules = [];
      currentDayQuestions = 0;
    }
  }

  // Don't forget the last day
  if (currentDayModules.length > 0) {
    dayAssignments.push({
      dayNumber: currentDay,
      moduleIds: currentDayModules.map(m => m.id),
      questionCount: currentDayQuestions,
      estimatedMinutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
    });
  }

  return dayAssignments;
}

// ============================================
// Convex Mutations & Queries
// ============================================

/**
 * Compute and store the expansion schedule for a user.
 * Called automatically when Day 2 is completed (all gateways known).
 */
export const computeAndStoreSchedule = mutation({
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
      .filter(g => g.triggered)
      .map(g => g.gateway_id);

    console.log(`[ExpansionScheduler] Computing schedule for user ${args.userId}`);
    console.log(`[ExpansionScheduler] Triggered gateways: ${triggeredGateways.join(", ")}`);

    // Compute optimal schedule
    const dayAssignments = computeExpansionSchedule(triggeredGateways);

    // Calculate totals
    const totalQuestions = dayAssignments.reduce((sum, d) => sum + d.questionCount, 0);
    const totalMinutes = dayAssignments.reduce((sum, d) => sum + d.estimatedMinutes, 0);

    console.log(`[ExpansionScheduler] Schedule: ${dayAssignments.length} expansion days, ${totalQuestions} questions, ~${totalMinutes} minutes`);

    // Check for existing schedule
    const existing = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const scheduleData = {
      user_id: args.userId,
      computed_at: Date.now(),
      triggered_gateways: triggeredGateways,
      day_assignments: dayAssignments.map(d => ({
        day_number: d.dayNumber,
        module_ids: d.moduleIds,
        question_count: d.questionCount,
        estimated_minutes: d.estimatedMinutes,
        completed: false,
      })),
      total_expansion_questions: totalQuestions,
      total_estimated_minutes: totalMinutes,
    };

    if (existing) {
      await ctx.db.patch(existing._id, scheduleData);
      console.log(`[ExpansionScheduler] Updated existing schedule`);
    } else {
      await ctx.db.insert("user_expansion_schedules", scheduleData);
      console.log(`[ExpansionScheduler] Created new schedule`);
    }

    return {
      triggeredGateways,
      dayAssignments,
      totalQuestions,
      totalMinutes,
    };
  },
});

/**
 * Get the expansion schedule for a user.
 */
export const getSchedule = query({
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
    const enrichedDays = schedule.day_assignments.map(day => {
      const modules = day.module_ids.map(id => {
        const module = EXPANSION_MODULES.find(m => m.id === id);
        return module ? {
          id: module.id,
          name: module.name,
          instrument: module.instrument,
          questionCount: module.questionCount,
          estimatedMinutes: module.estimatedMinutes,
        } : null;
      }).filter(Boolean);

      return {
        ...day,
        modules,
      };
    });

    return {
      ...schedule,
      day_assignments: enrichedDays,
    };
  },
});

/**
 * Get expansion modules for a specific day.
 * Returns the module IDs and question counts for Today's Focus.
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
      return null;
    }

    const dayAssignment = schedule.day_assignments.find(
      (d) => d.day_number === args.dayNumber
    );

    if (!dayAssignment) {
      return null;
    }

    // Get module details
    const modules = dayAssignment.module_ids.map((id) => {
      const module = EXPANSION_MODULES.find(m => m.id === id);
      return module ? {
        id: module.id,
        name: module.name,
        instrument: module.instrument,
        questionCount: module.questionCount,
        estimatedMinutes: module.estimatedMinutes,
        priority: module.priority,
      } : null;
    }).filter(Boolean);

    return {
      dayNumber: args.dayNumber,
      modules,
      totalQuestions: dayAssignment.question_count,
      estimatedMinutes: dayAssignment.estimated_minutes,
      completed: dayAssignment.completed || false,
    };
  },
});

/**
 * Mark expansion modules as completed for a day.
 */
export const markDayExpansionCompleted = mutation({
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
      throw new Error("No expansion schedule found for user");
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
 * Get a summary of the expansion schedule for dashboard display.
 */
export const getScheduleSummary = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const schedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!schedule) {
      return {
        hasSchedule: false,
        triggeredGateways: [],
        totalDays: 0,
        totalQuestions: 0,
        totalMinutes: 0,
        completedDays: 0,
        remainingDays: 0,
      };
    }

    const completedDays = schedule.day_assignments.filter((d) => d.completed).length;

    return {
      hasSchedule: true,
      triggeredGateways: schedule.triggered_gateways,
      totalDays: schedule.day_assignments.length,
      totalQuestions: schedule.total_expansion_questions,
      totalMinutes: schedule.total_estimated_minutes,
      completedDays,
      remainingDays: schedule.day_assignments.length - completedDays,
      dayAssignments: schedule.day_assignments.map((d) => ({
        dayNumber: d.day_number,
        questionCount: d.question_count,
        estimatedMinutes: d.estimated_minutes,
        completed: d.completed || false,
      })),
    };
  },
});

/**
 * Debug: Get the computed schedule without storing (for testing)
 */
export const previewSchedule = query({
  args: {
    triggeredGateways: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    const dayAssignments = computeExpansionSchedule(args.triggeredGateways);

    // Enrich with module names
    const enrichedDays = dayAssignments.map(day => ({
      ...day,
      modules: day.moduleIds.map(id => {
        const module = EXPANSION_MODULES.find(m => m.id === id);
        return module ? { id, name: module.name, instrument: module.instrument } : { id, name: "Unknown" };
      }),
    }));

    const totalQuestions = dayAssignments.reduce((sum, d) => sum + d.questionCount, 0);
    const totalMinutes = dayAssignments.reduce((sum, d) => sum + d.estimatedMinutes, 0);

    return {
      triggeredGateways: args.triggeredGateways,
      dayAssignments: enrichedDays,
      totalQuestions,
      totalMinutes,
      averageQuestionsPerDay: dayAssignments.length > 0
        ? Math.round(totalQuestions / dayAssignments.length)
        : 0,
    };
  },
});
