import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

/**
 * Patient Journey Phase Management
 *
 * Tracks the patient's progression through:
 * 1. Intake (Days 1-14)
 * 2. Analysis (4 stages while physician reviews)
 * 3. Treatment Active (interventions assigned and active)
 */

// Analysis stage definitions
const ANALYSIS_STAGES = [
  {
    stage: 1,
    title: "Data collected",
    description: "Your 14 days of sleep data are ready for analysis",
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
 * Called automatically when Day 14 is completed
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
 * Returns true if current day > 14 and all assessments complete
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

    // Check if all 14 days are complete
    // This checks user_progress for completed days
    const completedDays = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("completed"), true))
      .collect();

    const intakeComplete = completedDays.length >= 14;

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

// ============================================
// Analysis Workflow Management
// For physician dashboard - tracks detailed findings and prerequisites
// ============================================

/**
 * Get the analysis workflow state for a patient
 */
export const getAnalysisWorkflow = query({
  args: { userId: v.id("users") },
  returns: v.object({
    exists: v.boolean(),
    physicianId: v.optional(v.string()),
    // Stage 2: Patterns
    patternsIdentified: v.array(v.string()),
    primarySleepIssues: v.array(v.string()),
    triggeredGateways: v.array(v.string()),
    riskFactors: v.array(v.string()),
    reviewedSleepData: v.boolean(),
    reviewedQuestionnaireScores: v.boolean(),
    reviewedGatewayTriggers: v.boolean(),
    ranAiAnalysis: v.boolean(),
    patternsNotes: v.optional(v.string()),
    patternsCompletedAt: v.optional(v.number()),
    // Stage 3: Recommendations
    recommendedInterventions: v.array(v.string()),
    treatmentApproach: v.optional(v.string()),
    estimatedDurationWeeks: v.optional(v.number()),
    recommendationsNotes: v.optional(v.string()),
    recommendationsCompletedAt: v.optional(v.number()),
    // Stage 4: Ready
    planSummary: v.optional(v.string()),
    specialConsiderations: v.optional(v.string()),
    readyForPatient: v.boolean(),
    finalReviewNotes: v.optional(v.string()),
    treatmentReadyAt: v.optional(v.number()),
    // Meta
    updatedAt: v.optional(v.number()),
  }),
  handler: async (ctx, args) => {
    const workflow = await ctx.db
      .query("patient_analysis_workflow")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!workflow) {
      return {
        exists: false,
        physicianId: undefined,
        patternsIdentified: [],
        primarySleepIssues: [],
        triggeredGateways: [],
        riskFactors: [],
        reviewedSleepData: false,
        reviewedQuestionnaireScores: false,
        reviewedGatewayTriggers: false,
        ranAiAnalysis: false,
        patternsNotes: undefined,
        patternsCompletedAt: undefined,
        recommendedInterventions: [],
        treatmentApproach: undefined,
        estimatedDurationWeeks: undefined,
        recommendationsNotes: undefined,
        recommendationsCompletedAt: undefined,
        planSummary: undefined,
        specialConsiderations: undefined,
        readyForPatient: false,
        finalReviewNotes: undefined,
        treatmentReadyAt: undefined,
        updatedAt: undefined,
      };
    }

    // Parse JSON fields
    const parseJson = (json: string | undefined): string[] => {
      if (!json) return [];
      try {
        return JSON.parse(json);
      } catch {
        return [];
      }
    };

    return {
      exists: true,
      physicianId: workflow.physician_id,
      patternsIdentified: parseJson(workflow.patterns_identified_json),
      primarySleepIssues: parseJson(workflow.primary_sleep_issues_json),
      triggeredGateways: parseJson(workflow.triggered_gateways_json),
      riskFactors: parseJson(workflow.risk_factors_json),
      reviewedSleepData: workflow.reviewed_sleep_data ?? false,
      reviewedQuestionnaireScores: workflow.reviewed_questionnaire_scores ?? false,
      reviewedGatewayTriggers: workflow.reviewed_gateway_triggers ?? false,
      ranAiAnalysis: workflow.ran_ai_analysis ?? false,
      patternsNotes: workflow.patterns_notes,
      patternsCompletedAt: workflow.patterns_completed_at,
      recommendedInterventions: parseJson(workflow.recommended_interventions_json),
      treatmentApproach: workflow.treatment_approach,
      estimatedDurationWeeks: workflow.estimated_duration_weeks,
      recommendationsNotes: workflow.recommendations_notes,
      recommendationsCompletedAt: workflow.recommendations_completed_at,
      planSummary: workflow.plan_summary,
      specialConsiderations: workflow.special_considerations,
      readyForPatient: workflow.ready_for_patient ?? false,
      finalReviewNotes: workflow.final_review_notes,
      treatmentReadyAt: workflow.treatment_ready_at,
      updatedAt: workflow.updated_at,
    };
  },
});

/**
 * Update workflow checklist items (Stage 2 prerequisites)
 */
export const updateWorkflowChecklist = mutation({
  args: {
    userId: v.id("users"),
    reviewedSleepData: v.optional(v.boolean()),
    reviewedQuestionnaireScores: v.optional(v.boolean()),
    reviewedGatewayTriggers: v.optional(v.boolean()),
    ranAiAnalysis: v.optional(v.boolean()),
  },
  returns: v.object({ success: v.boolean() }),
  handler: async (ctx, args) => {
    const now = Date.now();
    const workflow = await ctx.db
      .query("patient_analysis_workflow")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const updates: Record<string, boolean | number> = { updated_at: now };
    if (args.reviewedSleepData !== undefined) updates.reviewed_sleep_data = args.reviewedSleepData;
    if (args.reviewedQuestionnaireScores !== undefined) updates.reviewed_questionnaire_scores = args.reviewedQuestionnaireScores;
    if (args.reviewedGatewayTriggers !== undefined) updates.reviewed_gateway_triggers = args.reviewedGatewayTriggers;
    if (args.ranAiAnalysis !== undefined) updates.ran_ai_analysis = args.ranAiAnalysis;

    if (workflow) {
      await ctx.db.patch(workflow._id, updates);
    } else {
      await ctx.db.insert("patient_analysis_workflow", {
        user_id: args.userId,
        reviewed_sleep_data: args.reviewedSleepData ?? false,
        reviewed_questionnaire_scores: args.reviewedQuestionnaireScores ?? false,
        reviewed_gateway_triggers: args.reviewedGatewayTriggers ?? false,
        ran_ai_analysis: args.ranAiAnalysis ?? false,
        created_at: now,
        updated_at: now,
      });
    }

    return { success: true };
  },
});

/**
 * Save Stage 2 findings - Patterns Identified
 */
export const savePatternFindings = mutation({
  args: {
    userId: v.id("users"),
    patternsIdentified: v.array(v.string()),
    primarySleepIssues: v.array(v.string()),
    triggeredGateways: v.array(v.string()),
    riskFactors: v.array(v.string()),
    notes: v.optional(v.string()),
    markComplete: v.boolean(),
  },
  returns: v.object({
    success: v.boolean(),
    canAdvance: v.boolean(),
    message: v.string(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();
    const workflow = await ctx.db
      .query("patient_analysis_workflow")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const updateData = {
      patterns_identified_json: JSON.stringify(args.patternsIdentified),
      primary_sleep_issues_json: JSON.stringify(args.primarySleepIssues),
      triggered_gateways_json: JSON.stringify(args.triggeredGateways),
      risk_factors_json: JSON.stringify(args.riskFactors),
      patterns_notes: args.notes,
      patterns_completed_at: args.markComplete ? now : undefined,
      updated_at: now,
    };

    if (workflow) {
      await ctx.db.patch(workflow._id, updateData);
    } else {
      await ctx.db.insert("patient_analysis_workflow", {
        user_id: args.userId,
        ...updateData,
        created_at: now,
      });
    }

    // Check if prerequisites are met to advance to stage 2
    const updatedWorkflow = await ctx.db
      .query("patient_analysis_workflow")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const canAdvance = args.markComplete &&
      (args.patternsIdentified.length > 0 || args.primarySleepIssues.length > 0);

    return {
      success: true,
      canAdvance,
      message: canAdvance ? "Pattern analysis complete. Ready to advance to Stage 2." : "Findings saved.",
    };
  },
});

/**
 * Save Stage 3 findings - Recommendations Preparing
 */
export const saveRecommendations = mutation({
  args: {
    userId: v.id("users"),
    recommendedInterventions: v.array(v.string()),
    treatmentApproach: v.string(),
    estimatedDurationWeeks: v.optional(v.number()),
    notes: v.optional(v.string()),
    markComplete: v.boolean(),
  },
  returns: v.object({
    success: v.boolean(),
    canAdvance: v.boolean(),
    message: v.string(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();
    const workflow = await ctx.db
      .query("patient_analysis_workflow")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const updateData = {
      recommended_interventions_json: JSON.stringify(args.recommendedInterventions),
      treatment_approach: args.treatmentApproach,
      estimated_duration_weeks: args.estimatedDurationWeeks,
      recommendations_notes: args.notes,
      recommendations_completed_at: args.markComplete ? now : undefined,
      updated_at: now,
    };

    if (workflow) {
      await ctx.db.patch(workflow._id, updateData);
    } else {
      await ctx.db.insert("patient_analysis_workflow", {
        user_id: args.userId,
        ...updateData,
        created_at: now,
      });
    }

    const canAdvance = args.markComplete && args.recommendedInterventions.length > 0;

    return {
      success: true,
      canAdvance,
      message: canAdvance ? "Recommendations complete. Ready to advance to Stage 3." : "Recommendations saved.",
    };
  },
});

/**
 * Finalize Stage 4 - Treatment Plan Ready
 */
export const finalizeTreatmentPlan = mutation({
  args: {
    userId: v.id("users"),
    planSummary: v.string(),
    specialConsiderations: v.optional(v.string()),
    finalReviewNotes: v.optional(v.string()),
  },
  returns: v.object({
    success: v.boolean(),
    message: v.string(),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();
    const workflow = await ctx.db
      .query("patient_analysis_workflow")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    const updateData = {
      plan_summary: args.planSummary,
      special_considerations: args.specialConsiderations,
      final_review_notes: args.finalReviewNotes,
      ready_for_patient: true,
      treatment_ready_at: now,
      updated_at: now,
    };

    if (workflow) {
      await ctx.db.patch(workflow._id, updateData);
    } else {
      await ctx.db.insert("patient_analysis_workflow", {
        user_id: args.userId,
        ...updateData,
        created_at: now,
      });
    }

    return {
      success: true,
      message: "Treatment plan finalized and ready for patient.",
    };
  },
});

/**
 * Get workflow readiness for each stage
 * Used by the dashboard to show what's required to advance
 */
export const getWorkflowReadiness = query({
  args: { userId: v.id("users") },
  returns: v.object({
    stage2Ready: v.boolean(),
    stage2Requirements: v.array(v.object({
      id: v.string(),
      label: v.string(),
      complete: v.boolean(),
      required: v.boolean(),
    })),
    stage3Ready: v.boolean(),
    stage3Requirements: v.array(v.object({
      id: v.string(),
      label: v.string(),
      complete: v.boolean(),
      required: v.boolean(),
    })),
    stage4Ready: v.boolean(),
    stage4Requirements: v.array(v.object({
      id: v.string(),
      label: v.string(),
      complete: v.boolean(),
      required: v.boolean(),
    })),
  }),
  handler: async (ctx, args) => {
    const workflow = await ctx.db
      .query("patient_analysis_workflow")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    // Check interventions assigned
    const interventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const hasInterventions = interventions.length > 0;

    // Stage 2 requirements
    const stage2Requirements = [
      { id: "sleep_data", label: "Review sleep data", complete: workflow?.reviewed_sleep_data ?? false, required: true },
      { id: "scores", label: "Review questionnaire scores", complete: workflow?.reviewed_questionnaire_scores ?? false, required: true },
      { id: "gateways", label: "Review gateway triggers", complete: workflow?.reviewed_gateway_triggers ?? false, required: true },
      { id: "ai_analysis", label: "Run AI analysis", complete: workflow?.ran_ai_analysis ?? false, required: false },
      { id: "patterns", label: "Document findings", complete: workflow?.patterns_completed_at !== undefined, required: true },
    ];
    const stage2Ready = stage2Requirements.filter(r => r.required).every(r => r.complete);

    // Stage 3 requirements
    const stage3Requirements = [
      { id: "interventions", label: "Assign interventions", complete: hasInterventions, required: true },
      { id: "approach", label: "Define treatment approach", complete: workflow?.treatment_approach !== undefined, required: true },
      { id: "duration", label: "Set estimated duration", complete: workflow?.estimated_duration_weeks !== undefined, required: false },
      { id: "recommendations", label: "Document recommendations", complete: workflow?.recommendations_completed_at !== undefined, required: true },
    ];
    const stage3Ready = stage3Requirements.filter(r => r.required).every(r => r.complete);

    // Stage 4 requirements
    const stage4Requirements = [
      { id: "summary", label: "Write patient summary", complete: workflow?.plan_summary !== undefined, required: true },
      { id: "considerations", label: "Add special considerations", complete: workflow?.special_considerations !== undefined, required: false },
      { id: "ready", label: "Mark ready for patient", complete: workflow?.ready_for_patient ?? false, required: true },
    ];
    const stage4Ready = stage4Requirements.filter(r => r.required).every(r => r.complete);

    return {
      stage2Ready,
      stage2Requirements,
      stage3Ready,
      stage3Requirements,
      stage4Ready,
      stage4Requirements,
    };
  },
});
