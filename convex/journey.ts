import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

/**
 * Patient Journey Phase Management
 *
 * Tracks the patient's progression through:
 * 1. Intake (Days 1-15)
 * 2. Analysis (4 stages while physician reviews)
 * 3. Treatment Active (interventions assigned and active)
 */

// Analysis stage definitions
const ANALYSIS_STAGES = [
  {
    stage: 1,
    title: "Data collected",
    description: "Your 15 days of sleep data are ready for analysis",
    icon: "checkmark.circle.fill",
  },
  {
    stage: 2,
    title: "Patterns identified",
    description: "Our sleep specialists are reviewing your patterns",
    icon: "magnifyingglass",
  },
  {
    stage: 3,
    title: "Recommendations preparing",
    description: "Your personalized treatment plan is being created",
    icon: "doc.text.fill",
  },
  {
    stage: 4,
    title: "Treatment plan ready!",
    description: "Tap to view your personalized sleep improvement plan",
    icon: "star.fill",
  },
];

/**
 * Get the patient's current journey status
 */
export const getJourneyStatus = query({
  args: { userId: v.id("users") },
  returns: v.object({
    phase: v.string(),
    analysisStage: v.optional(v.number()),
    analysisStageLabel: v.optional(v.string()),
    analysisStageDescription: v.optional(v.string()),
    intakeCompletedAt: v.optional(v.number()),
    treatmentActivatedAt: v.optional(v.number()),
    updatedAt: v.number(),
  }),
  handler: async (ctx, args) => {
    // Try to get existing journey status
    const journeyStatus = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!journeyStatus) {
      // Default to intake phase if no status exists
      return {
        phase: "intake",
        analysisStage: undefined,
        analysisStageLabel: undefined,
        analysisStageDescription: undefined,
        intakeCompletedAt: undefined,
        treatmentActivatedAt: undefined,
        updatedAt: Date.now(),
      };
    }

    // Get stage label if in analysis phase
    let stageLabel: string | undefined;
    let stageDescription: string | undefined;
    if (journeyStatus.analysis_stage) {
      const stageInfo = ANALYSIS_STAGES.find(
        (s) => s.stage === journeyStatus.analysis_stage
      );
      stageLabel = stageInfo?.title;
      stageDescription = stageInfo?.description;
    }

    return {
      phase: journeyStatus.phase,
      analysisStage: journeyStatus.analysis_stage,
      analysisStageLabel: stageLabel,
      analysisStageDescription: stageDescription,
      intakeCompletedAt: journeyStatus.intake_completed_at,
      treatmentActivatedAt: journeyStatus.treatment_activated_at,
      updatedAt: journeyStatus.updated_at,
    };
  },
});

/**
 * Get detailed analysis progress for the patient app UI
 */
export const getAnalysisProgress = query({
  args: { userId: v.id("users") },
  returns: v.object({
    stages: v.array(
      v.object({
        stage: v.number(),
        title: v.string(),
        description: v.string(),
        icon: v.string(),
        isComplete: v.boolean(),
        isCurrent: v.boolean(),
      })
    ),
    currentStage: v.number(),
    phase: v.string(),
  }),
  handler: async (ctx, args) => {
    const journeyStatus = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const currentStage = journeyStatus?.analysis_stage ?? 1;
    const phase = journeyStatus?.phase ?? "intake";

    const stages = ANALYSIS_STAGES.map((stage) => ({
      stage: stage.stage,
      title: stage.title,
      description: stage.description,
      icon: stage.icon,
      isComplete: stage.stage < currentStage,
      isCurrent: stage.stage === currentStage,
    }));

    return {
      stages,
      currentStage,
      phase,
    };
  },
});

/**
 * Transition patient from intake to analysis phase
 * Called automatically when Day 15 is completed
 */
export const transitionToAnalysis = mutation({
  args: { userId: v.id("users") },
  returns: v.object({
    success: v.boolean(),
    phase: v.string(),
    analysisStage: v.number(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if journey status already exists
    const existingStatus = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (existingStatus) {
      // Update existing status
      await ctx.db.patch(existingStatus._id, {
        phase: "analysis",
        intake_completed_at: now,
        analysis_stage: 1,
        analysis_stage_updated_at: now,
        updated_at: now,
      });
    } else {
      // Create new status
      await ctx.db.insert("patient_journey_status", {
        user_id: args.userId,
        phase: "analysis",
        intake_completed_at: now,
        analysis_stage: 1,
        analysis_stage_updated_at: now,
        created_at: now,
        updated_at: now,
      });
    }

    // Also update patient_review_status to pending_review
    const reviewStatus = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (reviewStatus) {
      await ctx.db.patch(reviewStatus._id, {
        status: "pending_review",
        updated_at: now,
      });
    } else {
      await ctx.db.insert("patient_review_status", {
        user_id: args.userId,
        status: "pending_review",
        updated_at: now,
      });
    }

    return {
      success: true,
      phase: "analysis",
      analysisStage: 1,
    };
  },
});

/**
 * Advance the analysis stage (physician action)
 * Stage 1 → 2: Physician starts reviewing
 * Stage 2 → 3: Physician prepares interventions
 * Stage 3 → 4: Treatment plan ready
 */
export const advanceAnalysisStage = mutation({
  args: {
    userId: v.id("users"),
    newStage: v.number(),
  },
  returns: v.object({
    success: v.boolean(),
    stage: v.number(),
    message: v.string(),
  }),
  handler: async (ctx, args) => {
    if (args.newStage < 1 || args.newStage > 4) {
      return {
        success: false,
        stage: 0,
        message: "Invalid stage. Must be 1-4.",
      };
    }

    const now = Date.now();

    const journeyStatus = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!journeyStatus) {
      return {
        success: false,
        stage: 0,
        message: "Patient journey status not found.",
      };
    }

    // Update the stage
    await ctx.db.patch(journeyStatus._id, {
      analysis_stage: args.newStage,
      analysis_stage_updated_at: now,
      updated_at: now,
    });

    // Update patient_review_status based on stage
    const reviewStatus = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    let newReviewStatus = "pending_review";
    if (args.newStage === 2) newReviewStatus = "under_review";
    if (args.newStage === 3) newReviewStatus = "interventions_prepared";
    if (args.newStage === 4) newReviewStatus = "interventions_active";

    if (reviewStatus) {
      await ctx.db.patch(reviewStatus._id, {
        status: newReviewStatus,
        updated_at: now,
      });
    }

    const stageInfo = ANALYSIS_STAGES.find((s) => s.stage === args.newStage);

    return {
      success: true,
      stage: args.newStage,
      message: stageInfo?.title ?? "Stage updated",
    };
  },
});

/**
 * Transition to treatment active phase
 * Called when interventions are activated
 */
export const transitionToTreatment = mutation({
  args: { userId: v.id("users") },
  returns: v.object({
    success: v.boolean(),
    phase: v.string(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();

    const journeyStatus = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (journeyStatus) {
      await ctx.db.patch(journeyStatus._id, {
        phase: "treatment_active",
        analysis_stage: 4,
        treatment_activated_at: now,
        updated_at: now,
      });
    } else {
      await ctx.db.insert("patient_journey_status", {
        user_id: args.userId,
        phase: "treatment_active",
        analysis_stage: 4,
        treatment_activated_at: now,
        created_at: now,
        updated_at: now,
      });
    }

    return {
      success: true,
      phase: "treatment_active",
    };
  },
});

/**
 * Initialize or get journey status for a user
 * Creates default intake status if none exists
 */
export const initializeJourneyStatus = mutation({
  args: { userId: v.id("users") },
  returns: v.object({
    phase: v.string(),
    isNew: v.boolean(),
  }),
  handler: async (ctx, args) => {
    const existingStatus = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (existingStatus) {
      return {
        phase: existingStatus.phase,
        isNew: false,
      };
    }

    const now = Date.now();
    await ctx.db.insert("patient_journey_status", {
      user_id: args.userId,
      phase: "intake",
      created_at: now,
      updated_at: now,
    });

    return {
      phase: "intake",
      isNew: true,
    };
  },
});

/**
 * Check if patient should transition to analysis
 * Returns true if current day > 15 and all assessments complete
 */
export const shouldTransitionToAnalysis = query({
  args: { userId: v.id("users") },
  returns: v.object({
    shouldTransition: v.boolean(),
    currentDay: v.number(),
    intakeComplete: v.boolean(),
  }),
  handler: async (ctx, args) => {
    // Get user's current day
    const user = await ctx.db.get(args.userId);
    if (!user) {
      return {
        shouldTransition: false,
        currentDay: 1,
        intakeComplete: false,
      };
    }

    const currentDay = user.current_day ?? 1;

    // Check if all 15 days are complete
    // This checks user_progress for completed days
    const completedDays = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("completed"), true))
      .collect();

    const intakeComplete = completedDays.length >= 15;

    // Check current journey phase
    const journeyStatus = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const currentPhase = journeyStatus?.phase ?? "intake";

    // Should transition if intake complete and still in intake phase
    const shouldTransition = intakeComplete && currentPhase === "intake";

    return {
      shouldTransition,
      currentDay,
      intakeComplete,
    };
  },
});
