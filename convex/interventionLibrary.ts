import { query, mutation, action, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";
import { internal } from "./_generated/api";

// ============================================
// Intervention Library Queries
// ============================================

/**
 * Get all intervention categories
 */
export const getCategories = query({
  args: {},
  returns: v.array(
    v.object({
      _id: v.id("intervention_categories"),
      category_id: v.string(),
      name: v.string(),
      description: v.optional(v.string()),
      icon: v.optional(v.string()),
      color: v.optional(v.string()),
      order_index: v.number(),
    })
  ),
  handler: async (ctx) => {
    const categories = await ctx.db
      .query("intervention_categories")
      .collect();

    // Explicitly map fields to exclude _creationTime (Convex system field)
    return categories
      .sort((a, b) => a.order_index - b.order_index)
      .map((c) => ({
        _id: c._id,
        category_id: c.category_id,
        name: c.name,
        description: c.description,
        icon: c.icon,
        color: c.color,
        order_index: c.order_index,
      }));
  },
});

/**
 * Get all interventions from the library with optional filtering
 */
export const getAllInterventions = query({
  args: {
    category: v.optional(v.string()),
    searchTerm: v.optional(v.string()),
    status: v.optional(v.string()),
  },
  returns: v.array(
    v.object({
      _id: v.id("interventions"),
      intervention_id: v.string(),
      name: v.string(),
      short_name: v.optional(v.string()),
      category: v.string(),
      type: v.optional(v.string()),
      why_it_works: v.string(),
      how_to_apply: v.string(),
      instructions_text: v.string(),
      target_phenotypes: v.array(v.string()),
      target_gateways: v.array(v.string()),
      evidence_score: v.optional(v.number()),
      safety_rating: v.optional(v.number()),
      contraindications: v.array(v.string()),
      default_frequency: v.optional(v.string()),
      default_timing: v.optional(v.string()),
      default_dosage: v.optional(v.string()),
      is_core_intervention: v.optional(v.boolean()),
      is_optional_addon: v.optional(v.boolean()),
      primary_benefit: v.optional(v.string()),
      status: v.string(),
    })
  ),
  handler: async (ctx, args) => {
    let interventions = await ctx.db
      .query("interventions")
      .withIndex("by_status", (q) => q.eq("status", args.status || "active"))
      .collect();

    // Filter by category
    if (args.category) {
      interventions = interventions.filter((i) => i.category === args.category);
    }

    // Filter by search term
    if (args.searchTerm && args.searchTerm.trim()) {
      const term = args.searchTerm.toLowerCase();
      interventions = interventions.filter(
        (i) =>
          i.name.toLowerCase().includes(term) ||
          i.intervention_id.toLowerCase().includes(term) ||
          i.instructions_text.toLowerCase().includes(term) ||
          i.why_it_works.toLowerCase().includes(term)
      );
    }

    return interventions.map((i) => ({
      _id: i._id,
      intervention_id: i.intervention_id,
      name: i.name,
      short_name: i.short_name,
      category: i.category,
      type: i.type,
      why_it_works: i.why_it_works,
      how_to_apply: i.how_to_apply,
      instructions_text: i.instructions_text,
      target_phenotypes: i.target_phenotypes_json
        ? JSON.parse(i.target_phenotypes_json)
        : [],
      target_gateways: i.target_gateways_json
        ? JSON.parse(i.target_gateways_json)
        : [],
      evidence_score: i.evidence_score,
      safety_rating: i.safety_rating,
      contraindications: i.contraindications_json
        ? JSON.parse(i.contraindications_json)
        : [],
      default_frequency: i.default_frequency,
      default_timing: i.default_timing,
      default_dosage: i.default_dosage,
      is_core_intervention: i.is_core_intervention,
      is_optional_addon: i.is_optional_addon,
      primary_benefit: i.primary_benefit,
      status: i.status,
    }));
  },
});

/**
 * Get a single intervention by ID
 */
export const getInterventionById = query({
  args: {
    interventionId: v.union(v.id("interventions"), v.string()),
  },
  returns: v.union(
    v.object({
      _id: v.id("interventions"),
      intervention_id: v.string(),
      name: v.string(),
      short_name: v.optional(v.string()),
      category: v.string(),
      type: v.optional(v.string()),
      why_it_works: v.string(),
      how_to_apply: v.string(),
      instructions_text: v.string(),
      target_phenotypes: v.array(v.string()),
      target_gateways: v.array(v.string()),
      evidence_score: v.optional(v.number()),
      safety_rating: v.optional(v.number()),
      contraindications: v.array(v.string()),
      available_frequencies: v.array(v.string()),
      available_timings: v.array(v.string()),
      default_frequency: v.optional(v.string()),
      default_timing: v.optional(v.string()),
      default_dosage: v.optional(v.string()),
      dosage_notes: v.optional(v.string()),
      recommended_duration_weeks: v.optional(v.number()),
      is_core_intervention: v.optional(v.boolean()),
      is_optional_addon: v.optional(v.boolean()),
      primary_benefit: v.optional(v.string()),
      status: v.string(),
    }),
    v.null()
  ),
  handler: async (ctx, args) => {
    let intervention;

    // Try to find by Convex ID first
    if (typeof args.interventionId === "string" && args.interventionId.length > 20) {
      try {
        intervention = await ctx.db.get(args.interventionId as Id<"interventions">);
      } catch {
        // Not a valid Convex ID, try string ID
      }
    }

    // If not found, try by intervention_id string
    if (!intervention) {
      intervention = await ctx.db
        .query("interventions")
        .withIndex("by_intervention_id", (q) =>
          q.eq("intervention_id", args.interventionId as string)
        )
        .first();
    }

    if (!intervention) return null;

    return {
      _id: intervention._id,
      intervention_id: intervention.intervention_id,
      name: intervention.name,
      short_name: intervention.short_name,
      category: intervention.category,
      type: intervention.type,
      why_it_works: intervention.why_it_works,
      how_to_apply: intervention.how_to_apply,
      instructions_text: intervention.instructions_text,
      target_phenotypes: intervention.target_phenotypes_json
        ? JSON.parse(intervention.target_phenotypes_json)
        : [],
      target_gateways: intervention.target_gateways_json
        ? JSON.parse(intervention.target_gateways_json)
        : [],
      evidence_score: intervention.evidence_score,
      safety_rating: intervention.safety_rating,
      contraindications: intervention.contraindications_json
        ? JSON.parse(intervention.contraindications_json)
        : [],
      available_frequencies: intervention.available_frequencies_json
        ? JSON.parse(intervention.available_frequencies_json)
        : ["daily"],
      available_timings: intervention.available_timings_json
        ? JSON.parse(intervention.available_timings_json)
        : [],
      default_frequency: intervention.default_frequency,
      default_timing: intervention.default_timing,
      default_dosage: intervention.default_dosage,
      dosage_notes: intervention.dosage_notes,
      recommended_duration_weeks: intervention.recommended_duration_weeks,
      is_core_intervention: intervention.is_core_intervention,
      is_optional_addon: intervention.is_optional_addon,
      primary_benefit: intervention.primary_benefit,
      status: intervention.status,
    };
  },
});

/**
 * Get all intervention bundles
 */
export const getBundles = query({
  args: {},
  returns: v.array(
    v.object({
      _id: v.id("intervention_bundles"),
      bundle_id: v.string(),
      name: v.string(),
      description: v.string(),
      goal: v.string(),
      target_phenotypes: v.array(v.string()),
      target_gateways: v.array(v.string()),
      core_intervention_ids: v.array(v.string()),
      optional_intervention_ids: v.array(v.string()),
      recommended_count: v.number(),
      status: v.string(),
    })
  ),
  handler: async (ctx) => {
    const bundles = await ctx.db
      .query("intervention_bundles")
      .withIndex("by_status", (q) => q.eq("status", "active"))
      .collect();

    return bundles.map((b) => ({
      _id: b._id,
      bundle_id: b.bundle_id,
      name: b.name,
      description: b.description,
      goal: b.goal,
      target_phenotypes: JSON.parse(b.target_phenotypes_json),
      target_gateways: b.target_gateways_json
        ? JSON.parse(b.target_gateways_json)
        : [],
      core_intervention_ids: JSON.parse(b.core_intervention_ids_json),
      optional_intervention_ids: b.optional_intervention_ids_json
        ? JSON.parse(b.optional_intervention_ids_json)
        : [],
      recommended_count: b.recommended_count,
      status: b.status,
    }));
  },
});

// ============================================
// AI-Powered Intervention Suggestions
// ============================================

/**
 * Get suggested interventions based on patient's scores and gateways
 */
export const getSuggestedInterventions = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.object({
    suggestedBundle: v.optional(
      v.object({
        bundle_id: v.string(),
        name: v.string(),
        description: v.string(),
        goal: v.string(),
        matchScore: v.number(),
        matchReasons: v.array(v.string()),
      })
    ),
    suggestedInterventions: v.array(
      v.object({
        _id: v.id("interventions"),
        intervention_id: v.string(),
        name: v.string(),
        category: v.string(),
        matchScore: v.number(),
        matchReasons: v.array(v.string()),
        priority: v.string(),
      })
    ),
    patientProfile: v.object({
      triggeredGateways: v.array(v.string()),
      phenotype: v.optional(v.string()),
      riskFactors: v.array(v.string()),
    }),
  }),
  handler: async (ctx, args) => {
    // Get patient's gateway states
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const triggeredGateways = gatewayStates
      .filter((g) => g.triggered)
      .map((g) => g.gateway_id);

    // Get patient's questionnaire scores
    const scores = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Determine phenotype based on responses
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Analyze sleep timing to determine chronotype
    let phenotype: string | undefined;
    const bedtimeResponses = responses.filter(
      (r) => r.question_id === "SD_GOT_INTO_BED" || r.question_id === "SL_BEDTIME"
    );
    if (bedtimeResponses.length > 0) {
      const avgBedtime = bedtimeResponses
        .map((r) => {
          const time = r.response_value;
          if (!time) return 0;
          const [hours, mins] = time.split(":").map(Number);
          return hours * 60 + (mins || 0);
        })
        .filter((t) => t > 0)
        .reduce((sum, t, _, arr) => sum + t / arr.length, 0);

      // Late bedtime (after midnight) suggests DSPD/late chronotype
      if (avgBedtime > 0 && (avgBedtime < 300 || avgBedtime > 1380)) {
        phenotype = "late_chronotype";
      } else if (avgBedtime > 0 && avgBedtime < 1260) {
        phenotype = "early_chronotype";
      }
    }

    // Check for irregularity
    const sleepTimeVariability = calculateSleepTimeVariability(responses);
    if (sleepTimeVariability > 90) {
      phenotype = "irregular_rhythm";
    }

    // Identify risk factors
    const riskFactors: string[] = [];
    for (const score of scores) {
      if (score.questionnaire_name === "ISI" && score.score >= 15) {
        riskFactors.push("moderate_to_severe_insomnia");
      }
      if (score.questionnaire_name === "PHQ-9" && score.score >= 10) {
        riskFactors.push("depression_concern");
      }
      if (score.questionnaire_name === "STOP-BANG" && score.score >= 3) {
        riskFactors.push("sleep_apnea_risk");
      }
      if (score.questionnaire_name === "ESS" && score.score >= 11) {
        riskFactors.push("excessive_daytime_sleepiness");
      }
    }

    // Get all active interventions
    const allInterventions = await ctx.db
      .query("interventions")
      .withIndex("by_status", (q) => q.eq("status", "active"))
      .collect();

    // Get all bundles
    const allBundles = await ctx.db
      .query("intervention_bundles")
      .withIndex("by_status", (q) => q.eq("status", "active"))
      .collect();

    // Score bundles based on match
    let bestBundle: {
      bundle_id: string;
      name: string;
      description: string;
      goal: string;
      matchScore: number;
      matchReasons: string[];
    } | undefined;

    for (const bundle of allBundles) {
      const targetPhenotypes = JSON.parse(bundle.target_phenotypes_json) as string[];
      const targetGateways = bundle.target_gateways_json
        ? (JSON.parse(bundle.target_gateways_json) as string[])
        : [];

      let matchScore = 0;
      const matchReasons: string[] = [];

      // Check phenotype match
      if (phenotype && targetPhenotypes.includes(phenotype)) {
        matchScore += 30;
        matchReasons.push(`Matches your sleep pattern: ${phenotype.replace("_", " ")}`);
      }

      // Check gateway matches
      for (const gateway of triggeredGateways) {
        if (targetGateways.includes(gateway)) {
          matchScore += 20;
          matchReasons.push(`Addresses ${gateway.replace("_", " ")} concerns`);
        }
      }

      if (matchScore > 0 && (!bestBundle || matchScore > bestBundle.matchScore)) {
        bestBundle = {
          bundle_id: bundle.bundle_id,
          name: bundle.name,
          description: bundle.description,
          goal: bundle.goal,
          matchScore,
          matchReasons,
        };
      }
    }

    // Score individual interventions
    const scoredInterventions: {
      _id: Id<"interventions">;
      intervention_id: string;
      name: string;
      category: string;
      matchScore: number;
      matchReasons: string[];
      priority: string;
    }[] = [];

    for (const intervention of allInterventions) {
      const targetPhenotypes = intervention.target_phenotypes_json
        ? (JSON.parse(intervention.target_phenotypes_json) as string[])
        : [];
      const targetGateways = intervention.target_gateways_json
        ? (JSON.parse(intervention.target_gateways_json) as string[])
        : [];

      let matchScore = 0;
      const matchReasons: string[] = [];

      // Core interventions get base score
      if (intervention.is_core_intervention) {
        matchScore += 10;
        matchReasons.push("Core intervention");
      }

      // Check phenotype match
      if (phenotype && targetPhenotypes.includes(phenotype)) {
        matchScore += 25;
        matchReasons.push(`Matches ${phenotype.replace("_", " ")}`);
      }

      // Check gateway matches
      for (const gateway of triggeredGateways) {
        if (targetGateways.includes(gateway)) {
          matchScore += 15;
          matchReasons.push(`Targets ${gateway.replace("_", " ")}`);
        }
      }

      // Boost if part of best bundle
      if (bestBundle) {
        const bundleData = allBundles.find((b) => b.bundle_id === bestBundle!.bundle_id);
        if (bundleData) {
          const coreIds = JSON.parse(bundleData.core_intervention_ids_json) as string[];
          if (coreIds.includes(intervention.intervention_id)) {
            matchScore += 20;
            matchReasons.push(`Part of recommended bundle`);
          }
        }
      }

      if (matchScore > 0) {
        scoredInterventions.push({
          _id: intervention._id,
          intervention_id: intervention.intervention_id,
          name: intervention.name,
          category: intervention.category,
          matchScore,
          matchReasons,
          priority: matchScore >= 40 ? "high" : matchScore >= 20 ? "medium" : "low",
        });
      }
    }

    // Sort by match score
    scoredInterventions.sort((a, b) => b.matchScore - a.matchScore);

    return {
      suggestedBundle: bestBundle,
      suggestedInterventions: scoredInterventions.slice(0, 12), // Top 12
      patientProfile: {
        triggeredGateways,
        phenotype,
        riskFactors,
      },
    };
  },
});

// Helper function to calculate sleep time variability
function calculateSleepTimeVariability(
  responses: { question_id: string; response_value?: string }[]
): number {
  const sleepTimes = responses
    .filter((r) => r.question_id === "SD_SLEEP_ONSET" || r.question_id === "SL_ASLEEP_TIME")
    .map((r) => {
      if (!r.response_value) return null;
      const [hours, mins] = r.response_value.split(":").map(Number);
      if (isNaN(hours)) return null;
      return hours * 60 + (mins || 0);
    })
    .filter((t): t is number => t !== null);

  if (sleepTimes.length < 3) return 0;

  const mean = sleepTimes.reduce((a, b) => a + b, 0) / sleepTimes.length;
  const variance =
    sleepTimes.reduce((sum, t) => sum + Math.pow(t - mean, 2), 0) / sleepTimes.length;
  return Math.sqrt(variance); // Standard deviation in minutes
}

// ============================================
// Intervention Assignment Mutations
// ============================================

/**
 * Assign an intervention to a patient
 */
export const assignIntervention = mutation({
  args: {
    userId: v.id("users"),
    interventionId: v.id("interventions"),
    startDate: v.string(),
    endDate: v.optional(v.string()),
    frequency: v.optional(v.string()),
    timing: v.optional(v.string()),
    specificTime: v.optional(v.string()),
    dosage: v.optional(v.string()),
    customInstructions: v.optional(v.string()),
    priority: v.optional(v.number()),
    physicianId: v.optional(v.string()),
  },
  returns: v.id("user_interventions"),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Get the intervention to store the string ID
    const intervention = await ctx.db.get(args.interventionId);
    if (!intervention) {
      throw new Error("Intervention not found");
    }

    const userInterventionId = await ctx.db.insert("user_interventions", {
      user_id: args.userId,
      intervention_id: args.interventionId,
      intervention_string_id: intervention.intervention_id,
      assigned_by_physician_id: args.physicianId,
      start_date: args.startDate,
      end_date: args.endDate,
      frequency: args.frequency || intervention.default_frequency || "daily",
      timing: args.timing || intervention.default_timing,
      specific_time: args.specificTime,
      dosage: args.dosage || intervention.default_dosage,
      custom_instructions: args.customInstructions,
      patient_instructions: intervention.instructions_text,
      priority: args.priority || 3,
      status: "draft",
      assigned_at: now,
    });

    return userInterventionId;
  },
});

/**
 * Assign a full bundle of interventions to a patient
 */
export const assignBundle = mutation({
  args: {
    userId: v.id("users"),
    bundleId: v.string(),
    startDate: v.string(),
    endDate: v.optional(v.string()),
    selectedInterventionIds: v.array(v.string()), // intervention_id strings
    physicianId: v.optional(v.string()),
  },
  returns: v.array(v.id("user_interventions")),
  handler: async (ctx, args) => {
    const now = Date.now();
    const assignedIds: Id<"user_interventions">[] = [];

    for (let i = 0; i < args.selectedInterventionIds.length; i++) {
      const interventionStringId = args.selectedInterventionIds[i];

      // Find the intervention
      const intervention = await ctx.db
        .query("interventions")
        .withIndex("by_intervention_id", (q) =>
          q.eq("intervention_id", interventionStringId)
        )
        .first();

      if (!intervention) continue;

      const userInterventionId = await ctx.db.insert("user_interventions", {
        user_id: args.userId,
        intervention_id: intervention._id,
        intervention_string_id: interventionStringId,
        assigned_by_physician_id: args.physicianId,
        start_date: args.startDate,
        end_date: args.endDate,
        frequency: intervention.default_frequency || "daily",
        timing: intervention.default_timing,
        dosage: intervention.default_dosage,
        patient_instructions: intervention.instructions_text,
        priority: 3,
        display_order: i,
        status: "draft",
        assigned_at: now,
      });

      assignedIds.push(userInterventionId);
    }

    return assignedIds;
  },
});

/**
 * Activate all draft interventions for a patient (start treatment)
 */
export const activatePatientInterventions = mutation({
  args: {
    userId: v.id("users"),
  },
  returns: v.object({
    activated: v.number(),
    tasksGenerated: v.number(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = new Date().toISOString().split("T")[0];

    // Get all draft interventions for this user
    const draftInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "draft")
      )
      .collect();

    let tasksGenerated = 0;

    // Activate each intervention and generate initial tasks
    for (const intervention of draftInterventions) {
      await ctx.db.patch(intervention._id, {
        status: "active",
        activated_at: now,
      });

      // Generate tasks for the next 7 days
      const interventionData = await ctx.db.get(intervention.intervention_id);
      if (!interventionData) continue;

      for (let dayOffset = 0; dayOffset < 7; dayOffset++) {
        const taskDate = new Date();
        taskDate.setDate(taskDate.getDate() + dayOffset);
        const dateStr = taskDate.toISOString().split("T")[0];

        // Check if we should create a task based on frequency
        if (intervention.frequency === "daily" || shouldCreateTaskForDate(intervention, taskDate)) {
          await ctx.db.insert("user_daily_tasks", {
            user_id: args.userId,
            user_intervention_id: intervention._id,
            intervention_id: intervention.intervention_id,
            task_date: dateStr,
            task_name: interventionData.short_name || interventionData.name,
            task_instructions:
              intervention.patient_instructions || interventionData.instructions_text,
            timing: intervention.timing,
            scheduled_time: intervention.specific_time,
            status: "pending",
            created_at: now,
            updated_at: now,
          });
          tasksGenerated++;
        }
      }
    }

    // Update patient review status
    const existingStatus = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (existingStatus) {
      await ctx.db.patch(existingStatus._id, {
        status: "interventions_active",
        updated_at: now,
      });
    } else {
      await ctx.db.insert("patient_review_status", {
        user_id: args.userId,
        status: "interventions_active",
        updated_at: now,
      });
    }

    return {
      activated: draftInterventions.length,
      tasksGenerated,
    };
  },
});

// Helper function to determine if task should be created for a date
function shouldCreateTaskForDate(
  intervention: {
    frequency?: string;
    days_of_week_json?: string;
  },
  date: Date
): boolean {
  if (intervention.frequency === "daily") return true;

  if (intervention.days_of_week_json) {
    const days = JSON.parse(intervention.days_of_week_json) as string[];
    const dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
    return days.includes(dayNames[date.getDay()]);
  }

  if (intervention.frequency === "weekly") {
    // Default to starting day of week
    return date.getDay() === 1; // Monday
  }

  return false;
}

/**
 * Update an assigned intervention
 */
export const updateAssignedIntervention = mutation({
  args: {
    userInterventionId: v.id("user_interventions"),
    updates: v.object({
      frequency: v.optional(v.string()),
      timing: v.optional(v.string()),
      specificTime: v.optional(v.string()),
      dosage: v.optional(v.string()),
      customInstructions: v.optional(v.string()),
      priority: v.optional(v.number()),
      endDate: v.optional(v.string()),
      status: v.optional(v.string()),
    }),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const updateData: any = {};

    if (args.updates.frequency !== undefined)
      updateData.frequency = args.updates.frequency;
    if (args.updates.timing !== undefined) updateData.timing = args.updates.timing;
    if (args.updates.specificTime !== undefined)
      updateData.specific_time = args.updates.specificTime;
    if (args.updates.dosage !== undefined) updateData.dosage = args.updates.dosage;
    if (args.updates.customInstructions !== undefined)
      updateData.custom_instructions = args.updates.customInstructions;
    if (args.updates.priority !== undefined)
      updateData.priority = args.updates.priority;
    if (args.updates.endDate !== undefined)
      updateData.end_date = args.updates.endDate;
    if (args.updates.status !== undefined) {
      updateData.status = args.updates.status;
      if (args.updates.status === "paused") {
        updateData.paused_at = Date.now();
      } else if (args.updates.status === "completed") {
        updateData.completed_at = Date.now();
      }
    }

    await ctx.db.patch(args.userInterventionId, updateData);
    return null;
  },
});

/**
 * Remove an assigned intervention
 */
export const removeAssignedIntervention = mutation({
  args: {
    userInterventionId: v.id("user_interventions"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    // Delete associated tasks
    const tasks = await ctx.db
      .query("user_daily_tasks")
      .withIndex("by_intervention", (q) =>
        q.eq("user_intervention_id", args.userInterventionId)
      )
      .collect();

    for (const task of tasks) {
      await ctx.db.delete(task._id);
    }

    // Delete the intervention assignment
    await ctx.db.delete(args.userInterventionId);
    return null;
  },
});

// ============================================
// Patient Task Queries (for iOS app)
// ============================================

/**
 * Get today's tasks for a patient
 */
export const getTodaysTasks = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.array(
    v.object({
      _id: v.id("user_daily_tasks"),
      task_name: v.string(),
      task_instructions: v.string(),
      timing: v.optional(v.string()),
      scheduled_time: v.optional(v.string()),
      status: v.string(),
      completed_at: v.optional(v.number()),
      intervention_id: v.string(),
      priority: v.optional(v.number()),
    })
  ),
  handler: async (ctx, args) => {
    const today = new Date().toISOString().split("T")[0];

    const tasks = await ctx.db
      .query("user_daily_tasks")
      .withIndex("by_user_date", (q) =>
        q.eq("user_id", args.userId).eq("task_date", today)
      )
      .collect();

    // Get intervention details for priority
    const enrichedTasks = await Promise.all(
      tasks.map(async (task) => {
        const userIntervention = await ctx.db.get(task.user_intervention_id);
        const intervention = await ctx.db.get(task.intervention_id);

        return {
          _id: task._id,
          task_name: task.task_name,
          task_instructions: task.task_instructions,
          timing: task.timing,
          scheduled_time: task.scheduled_time,
          status: task.status,
          completed_at: task.completed_at,
          intervention_id: intervention?.intervention_id || "",
          priority: userIntervention?.priority,
        };
      })
    );

    // Sort by timing (morning first) and then priority
    const timingOrder: Record<string, number> = {
      morning: 1,
      midday: 2,
      afternoon: 3,
      evening: 4,
      pre_bed: 5,
    };

    enrichedTasks.sort((a, b) => {
      const timeA = timingOrder[a.timing || "evening"] || 4;
      const timeB = timingOrder[b.timing || "evening"] || 4;
      if (timeA !== timeB) return timeA - timeB;
      return (b.priority || 3) - (a.priority || 3);
    });

    return enrichedTasks;
  },
});

/**
 * Complete a task
 */
export const completeTask = mutation({
  args: {
    taskId: v.id("user_daily_tasks"),
    difficultyRating: v.optional(v.number()),
    notes: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const now = Date.now();

    await ctx.db.patch(args.taskId, {
      status: "completed",
      completed_at: now,
      difficulty_rating: args.difficultyRating,
      notes: args.notes,
      updated_at: now,
    });

    // Update compliance tracking
    const task = await ctx.db.get(args.taskId);
    if (task) {
      await ctx.db.insert("intervention_compliance", {
        user_intervention_id: task.user_intervention_id,
        scheduled_date: task.task_date,
        completed: true,
        completed_at: now,
        note_text: args.notes,
      });
    }

    return null;
  },
});

/**
 * Skip a task
 */
export const skipTask = mutation({
  args: {
    taskId: v.id("user_daily_tasks"),
    reason: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const now = Date.now();

    await ctx.db.patch(args.taskId, {
      status: "skipped",
      skipped_at: now,
      skipped_reason: args.reason,
      updated_at: now,
    });

    // Update compliance tracking
    const task = await ctx.db.get(args.taskId);
    if (task) {
      await ctx.db.insert("intervention_compliance", {
        user_intervention_id: task.user_intervention_id,
        scheduled_date: task.task_date,
        completed: false,
        note_text: args.reason,
      });
    }

    return null;
  },
});

// ============================================
// Admin: Seed Intervention Library
// ============================================

/**
 * Create or update an intervention in the library
 */
export const upsertIntervention = mutation({
  args: {
    intervention_id: v.string(),
    name: v.string(),
    short_name: v.optional(v.string()),
    category: v.string(),
    type: v.optional(v.string()),
    why_it_works: v.string(),
    how_to_apply: v.string(),
    instructions_text: v.string(),
    target_phenotypes: v.optional(v.array(v.string())),
    target_gateways: v.optional(v.array(v.string())),
    evidence_score: v.optional(v.number()),
    safety_rating: v.optional(v.number()),
    contraindications: v.optional(v.array(v.string())),
    default_frequency: v.optional(v.string()),
    default_timing: v.optional(v.string()),
    default_dosage: v.optional(v.string()),
    dosage_notes: v.optional(v.string()),
    recommended_duration_weeks: v.optional(v.number()),
    is_core_intervention: v.optional(v.boolean()),
    is_optional_addon: v.optional(v.boolean()),
    primary_benefit: v.optional(v.string()),
    bundle_ids: v.optional(v.array(v.string())),
  },
  returns: v.id("interventions"),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if intervention exists
    const existing = await ctx.db
      .query("interventions")
      .withIndex("by_intervention_id", (q) =>
        q.eq("intervention_id", args.intervention_id)
      )
      .first();

    const data = {
      intervention_id: args.intervention_id,
      name: args.name,
      short_name: args.short_name,
      category: args.category,
      type: args.type,
      why_it_works: args.why_it_works,
      how_to_apply: args.how_to_apply,
      instructions_text: args.instructions_text,
      target_phenotypes_json: args.target_phenotypes
        ? JSON.stringify(args.target_phenotypes)
        : undefined,
      target_gateways_json: args.target_gateways
        ? JSON.stringify(args.target_gateways)
        : undefined,
      evidence_score: args.evidence_score,
      safety_rating: args.safety_rating,
      contraindications_json: args.contraindications
        ? JSON.stringify(args.contraindications)
        : undefined,
      default_frequency: args.default_frequency,
      default_timing: args.default_timing,
      default_dosage: args.default_dosage,
      dosage_notes: args.dosage_notes,
      recommended_duration_weeks: args.recommended_duration_weeks,
      is_core_intervention: args.is_core_intervention,
      is_optional_addon: args.is_optional_addon,
      primary_benefit: args.primary_benefit,
      bundle_ids_json: args.bundle_ids ? JSON.stringify(args.bundle_ids) : undefined,
      status: "active" as const,
      updated_at: now,
    };

    if (existing) {
      await ctx.db.patch(existing._id, {
        ...data,
        version: existing.version + 1,
      });
      return existing._id;
    } else {
      return await ctx.db.insert("interventions", {
        ...data,
        version: 1,
        created_at: now,
      });
    }
  },
});

/**
 * Create or update an intervention category
 */
export const upsertCategory = mutation({
  args: {
    category_id: v.string(),
    name: v.string(),
    description: v.optional(v.string()),
    icon: v.optional(v.string()),
    color: v.optional(v.string()),
    order_index: v.number(),
  },
  returns: v.id("intervention_categories"),
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("intervention_categories")
      .withIndex("by_category_id", (q) => q.eq("category_id", args.category_id))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        name: args.name,
        description: args.description,
        icon: args.icon,
        color: args.color,
        order_index: args.order_index,
      });
      return existing._id;
    } else {
      return await ctx.db.insert("intervention_categories", {
        category_id: args.category_id,
        name: args.name,
        description: args.description,
        icon: args.icon,
        color: args.color,
        order_index: args.order_index,
      });
    }
  },
});

/**
 * Create or update an intervention bundle
 */
export const upsertBundle = mutation({
  args: {
    bundle_id: v.string(),
    name: v.string(),
    description: v.string(),
    goal: v.string(),
    target_phenotypes: v.array(v.string()),
    target_gateways: v.optional(v.array(v.string())),
    core_intervention_ids: v.array(v.string()),
    optional_intervention_ids: v.optional(v.array(v.string())),
    recommended_count: v.number(),
    tracking_metrics: v.optional(v.array(v.string())),
  },
  returns: v.id("intervention_bundles"),
  handler: async (ctx, args) => {
    const now = Date.now();

    const existing = await ctx.db
      .query("intervention_bundles")
      .withIndex("by_bundle_id", (q) => q.eq("bundle_id", args.bundle_id))
      .first();

    const data = {
      bundle_id: args.bundle_id,
      name: args.name,
      description: args.description,
      goal: args.goal,
      target_phenotypes_json: JSON.stringify(args.target_phenotypes),
      target_gateways_json: args.target_gateways
        ? JSON.stringify(args.target_gateways)
        : undefined,
      core_intervention_ids_json: JSON.stringify(args.core_intervention_ids),
      optional_intervention_ids_json: args.optional_intervention_ids
        ? JSON.stringify(args.optional_intervention_ids)
        : undefined,
      recommended_count: args.recommended_count,
      tracking_metrics_json: args.tracking_metrics
        ? JSON.stringify(args.tracking_metrics)
        : undefined,
      status: "active" as const,
      updated_at: now,
    };

    if (existing) {
      await ctx.db.patch(existing._id, data);
      return existing._id;
    } else {
      return await ctx.db.insert("intervention_bundles", {
        ...data,
        created_at: now,
      });
    }
  },
});
