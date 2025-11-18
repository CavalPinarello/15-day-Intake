import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

// ============================================
// Patient List & Overview Queries
// ============================================

/**
 * Get all patients with their progress and review status
 */
export const getAllPatientsWithProgress = query({
  args: {
    statusFilter: v.optional(v.string()),
    searchTerm: v.optional(v.string()),
  },
  returns: v.array(
    v.object({
      _id: v.id("users"),
      username: v.string(),
      name: v.optional(v.string()),
      email: v.optional(v.string()),
      current_day: v.number(),
      started_at: v.number(),
      last_accessed: v.number(),
      onboarding_completed: v.optional(v.boolean()),
      onboarding_completed_at: v.optional(v.number()),
      review_status: v.optional(v.string()),
      progress_percentage: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const users = await ctx.db.query("users").collect();

    // Filter out physicians and admins - only show patients
    const patientUsers = users.filter(user => 
      user.role !== "physician" && user.role !== "admin"
    );

    const patientsWithProgress = await Promise.all(
      patientUsers.map(async (user) => {
        // Get the patient's name from D1 response
        const nameResponse = await ctx.db
          .query("user_assessment_responses")
          .withIndex("by_user_question", (q) =>
            q.eq("user_id", user._id).eq("question_id", "D1")
          )
          .first();

        // Get review status
        const reviewStatus = await ctx.db
          .query("patient_review_status")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .first();

        // Calculate progress percentage (15 days total)
        const progressPercentage = Math.min(
          Math.round((user.current_day / 15) * 100),
          100
        );

        return {
          _id: user._id,
          username: user.username,
          name: nameResponse?.response_value || user.username, // Use username as fallback
          email: user.email,
          current_day: user.current_day,
          started_at: user.started_at,
          last_accessed: user.last_accessed,
          onboarding_completed: user.onboarding_completed,
          onboarding_completed_at: user.onboarding_completed_at,
          review_status: reviewStatus?.status,
          progress_percentage: progressPercentage,
        };
      })
    );

    // Filter by status if provided
    let filtered = patientsWithProgress;
    if (args.statusFilter && args.statusFilter !== "all") {
      filtered = filtered.filter(
        (p) => p.review_status === args.statusFilter
      );
    }

    // Filter by search term (name or username)
    if (args.searchTerm && args.searchTerm.trim() !== "") {
      const searchLower = args.searchTerm.toLowerCase();
      filtered = filtered.filter(
        (p) =>
          p.username.toLowerCase().includes(searchLower) ||
          (p.name && p.name.toLowerCase().includes(searchLower))
      );
    }

    // Sort by last accessed (most recent first)
    filtered.sort((a, b) => b.last_accessed - a.last_accessed);

    return filtered;
  },
});

/**
 * Get comprehensive patient details including all responses, scores, and notes
 */
export const getPatientDetails = query({
  args: { userId: v.id("users") },
  returns: v.object({
    user: v.object({
      _id: v.id("users"),
      username: v.string(),
      email: v.optional(v.string()),
      current_day: v.number(),
      started_at: v.number(),
      last_accessed: v.number(),
      onboarding_completed: v.optional(v.boolean()),
      onboarding_completed_at: v.optional(v.number()),
    }),
    name: v.optional(v.string()),
    demographics: v.object({
      dateOfBirth: v.optional(v.string()),
      sex: v.optional(v.string()),
      height: v.optional(v.string()),
      weight: v.optional(v.string()),
    }),
    reviewStatus: v.optional(
      v.object({
        status: v.string(),
        reviewed_by_physician_id: v.optional(v.string()),
        review_started_at: v.optional(v.number()),
        review_completed_at: v.optional(v.number()),
        updated_at: v.number(),
      })
    ),
    totalResponses: v.number(),
    completedDays: v.number(),
  }),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get name (D1)
    const nameResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D1")
      )
      .first();

    // Get demographics (D2, D4, D5, D6)
    const dobResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D2")
      )
      .first();

    const sexResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D4")
      )
      .first();

    const heightResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D5")
      )
      .first();

    const weightResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D6")
      )
      .first();

    // Get review status
    const reviewStatus = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    // Get total responses
    const allResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get completed days
    const userProgress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    const completedDays = userProgress.filter((p) => p.completed).length;

    return {
      user: {
        _id: user._id,
        username: user.username,
        email: user.email,
        current_day: user.current_day,
        started_at: user.started_at,
        last_accessed: user.last_accessed,
        onboarding_completed: user.onboarding_completed,
        onboarding_completed_at: user.onboarding_completed_at,
      },
      name: nameResponse?.response_value || user.username, // Use username as fallback
      demographics: {
        dateOfBirth: dobResponse?.response_value,
        sex: sexResponse?.response_value,
        height: heightResponse?.response_value,
        weight: weightResponse?.response_value,
      },
      reviewStatus: reviewStatus
        ? {
            status: reviewStatus.status,
            reviewed_by_physician_id: reviewStatus.reviewed_by_physician_id,
            review_started_at: reviewStatus.review_started_at,
            review_completed_at: reviewStatus.review_completed_at,
            updated_at: reviewStatus.updated_at,
          }
        : undefined,
      totalResponses: allResponses.length,
      completedDays,
    };
  },
});

/**
 * Get all responses and notes for a specific day
 */
export const getPatientDayData = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  returns: v.object({
    responses: v.array(
      v.object({
        _id: v.id("user_assessment_responses"),
        question_id: v.string(),
        response_value: v.optional(v.string()),
        question_text: v.optional(v.string()),
        question_type: v.optional(v.string()),
        pillar: v.optional(v.string()),
        tier: v.optional(v.string()),
        created_at: v.number(),
        updated_at: v.number(),
      })
    ),
    notes: v.array(
      v.object({
        _id: v.id("physician_notes"),
        note_text: v.string(),
        created_at: v.number(),
        updated_at: v.number(),
        physician_id: v.optional(v.string()),
      })
    ),
  }),
  handler: async (ctx, args) => {
    // Get responses for this day
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    // Enrich with question details
    const enrichedResponses = await Promise.all(
      responses.map(async (response) => {
        const question = await ctx.db
          .query("assessment_questions")
          .withIndex("by_question_id", (q) =>
            q.eq("question_id", response.question_id)
          )
          .first();

        return {
          _id: response._id,
          question_id: response.question_id,
          response_value: response.response_value,
          question_text: question?.question_text,
          question_type: question?.question_type,
          pillar: question?.pillar,
          tier: question?.tier,
          created_at: response.created_at,
          updated_at: response.updated_at,
        };
      })
    );

    // Get notes for this day
    const notes = await ctx.db
      .query("physician_notes")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    return {
      responses: enrichedResponses,
      notes: notes.map((note) => ({
        _id: note._id,
        note_text: note.note_text,
        created_at: note.created_at,
        updated_at: note.updated_at,
        physician_id: note.physician_id,
      })),
    };
  },
});

/**
 * Get all physician notes for a patient
 */
export const getPhysicianNotes = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("physician_notes"),
      day_number: v.optional(v.number()),
      note_text: v.string(),
      created_at: v.number(),
      updated_at: v.number(),
      physician_id: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const notes = await ctx.db
      .query("physician_notes")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sort by most recent first
    notes.sort((a, b) => b.created_at - a.created_at);

    return notes.map((note) => ({
      _id: note._id,
      day_number: note.day_number,
      note_text: note.note_text,
      created_at: note.created_at,
      updated_at: note.updated_at,
      physician_id: note.physician_id,
    }));
  },
});

/**
 * Get all calculated questionnaire scores for a patient
 */
export const getQuestionnaireScores = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("questionnaire_scores"),
      questionnaire_name: v.string(),
      score: v.number(),
      max_score: v.optional(v.number()),
      category: v.optional(v.string()),
      interpretation: v.optional(v.string()),
      calculated_at: v.number(),
      calculation_metadata_json: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const scores = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sort by calculation date (most recent first)
    scores.sort((a, b) => b.calculated_at - a.calculated_at);

    return scores.map((score) => ({
      _id: score._id,
      questionnaire_name: score.questionnaire_name,
      score: score.score,
      max_score: score.max_score,
      category: score.category,
      interpretation: score.interpretation,
      calculated_at: score.calculated_at,
      calculation_metadata_json: score.calculation_metadata_json,
    }));
  },
});

/**
 * Get patient visible field configuration
 */
export const getPatientVisibleFields = query({
  args: { userId: v.id("users") },
  returns: v.optional(
    v.object({
      _id: v.id("patient_visible_fields"),
      field_config_json: v.string(),
      updated_at: v.number(),
      updated_by_physician_id: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const config = await ctx.db
      .query("patient_visible_fields")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!config) return undefined;

    return {
      _id: config._id,
      field_config_json: config.field_config_json,
      updated_at: config.updated_at,
      updated_by_physician_id: config.updated_by_physician_id,
    };
  },
});

/**
 * Get all responses grouped by day for a patient
 */
export const getPatientResponsesByDay = query({
  args: { userId: v.id("users") },
  returns: v.object({
    days: v.array(
      v.object({
        dayNumber: v.number(),
        responseCount: v.number(),
        lastUpdated: v.number(),
        hasNotes: v.boolean(),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Group by day
    const dayMap: Record<
      number,
      { count: number; lastUpdated: number; notes: boolean }
    > = {};

    for (const response of responses) {
      if (response.day_number !== undefined) {
        if (!dayMap[response.day_number]) {
          dayMap[response.day_number] = {
            count: 0,
            lastUpdated: 0,
            notes: false,
          };
        }
        dayMap[response.day_number].count++;
        dayMap[response.day_number].lastUpdated = Math.max(
          dayMap[response.day_number].lastUpdated,
          response.updated_at
        );
      }
    }

    // Check for notes
    const allNotes = await ctx.db
      .query("physician_notes")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const note of allNotes) {
      if (note.day_number !== undefined && dayMap[note.day_number]) {
        dayMap[note.day_number].notes = true;
      }
    }

    // Convert to array and sort
    const days = Object.entries(dayMap)
      .map(([dayNumber, data]) => ({
        dayNumber: parseInt(dayNumber, 10),
        responseCount: data.count,
        lastUpdated: data.lastUpdated,
        hasNotes: data.notes,
      }))
      .sort((a, b) => a.dayNumber - b.dayNumber);

    return { days };
  },
});

/**
 * Get active interventions for a patient
 */
export const getPatientInterventions = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("user_interventions"),
      intervention_id: v.id("interventions"),
      intervention_name: v.string(),
      start_date: v.string(),
      end_date: v.optional(v.string()),
      frequency: v.optional(v.string()),
      dosage: v.optional(v.string()),
      timing: v.optional(v.string()),
      custom_instructions: v.optional(v.string()),
      status: v.string(),
      assigned_at: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Enrich with intervention details
    const enriched = await Promise.all(
      userInterventions.map(async (ui) => {
        const intervention = await ctx.db.get(ui.intervention_id);
        return {
          _id: ui._id,
          intervention_id: ui.intervention_id,
          intervention_name: intervention?.name || "Unknown",
          start_date: ui.start_date,
          end_date: ui.end_date,
          frequency: ui.frequency,
          dosage: ui.dosage,
          timing: ui.timing,
          custom_instructions: ui.custom_instructions,
          status: ui.status,
          assigned_at: ui.assigned_at,
        };
      })
    );

    // Sort by assignment date (most recent first)
    enriched.sort((a, b) => b.assigned_at - a.assigned_at);

    return enriched;
  },
});

/**
 * Get all available interventions library
 */
export const getAllInterventions = query({
  args: {},
  returns: v.array(
    v.object({
      _id: v.id("interventions"),
      name: v.string(),
      type: v.optional(v.string()),
      category: v.optional(v.string()),
      instructions_text: v.string(),
      status: v.string(),
    })
  ),
  handler: async (ctx) => {
    const interventions = await ctx.db
      .query("interventions")
      .withIndex("by_status", (q) => q.eq("status", "active"))
      .collect();

    return interventions.map((i) => ({
      _id: i._id,
      name: i.name,
      type: i.type,
      category: i.category,
      instructions_text: i.instructions_text,
      status: i.status,
    }));
  },
});

// ============================================
// Mutations
// ============================================

/**
 * Save or update a physician note
 */
export const savePhysicianNote = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.optional(v.number()),
    noteText: v.string(),
    physicianId: v.optional(v.string()),
  },
  returns: v.id("physician_notes"),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if note exists for this user and day
    const existingQuery = ctx.db
      .query("physician_notes")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      );

    const existing = await existingQuery.first();

    if (existing) {
      // Update existing note
      await ctx.db.patch(existing._id, {
        note_text: args.noteText,
        updated_at: now,
        physician_id: args.physicianId,
      });
      return existing._id;
    } else {
      // Create new note
      const noteId = await ctx.db.insert("physician_notes", {
        user_id: args.userId,
        day_number: args.dayNumber,
        note_text: args.noteText,
        created_at: now,
        updated_at: now,
        physician_id: args.physicianId,
      });
      return noteId;
    }
  },
});

/**
 * Update patient review status
 */
export const updatePatientReviewStatus = mutation({
  args: {
    userId: v.id("users"),
    status: v.string(),
    physicianId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const existing = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (existing) {
      // Update existing status
      const updates: any = {
        status: args.status,
        updated_at: now,
      };

      if (args.physicianId) {
        updates.reviewed_by_physician_id = args.physicianId;
      }

      // Set timestamps based on status
      if (args.status === "under_review" && !existing.review_started_at) {
        updates.review_started_at = now;
      }
      if (
        args.status === "interventions_prepared" &&
        !existing.review_completed_at
      ) {
        updates.review_completed_at = now;
      }

      await ctx.db.patch(existing._id, updates);
    } else {
      // Create new status
      const data: any = {
        user_id: args.userId,
        status: args.status,
        updated_at: now,
      };

      if (args.physicianId) {
        data.reviewed_by_physician_id = args.physicianId;
      }

      if (args.status === "under_review") {
        data.review_started_at = now;
      }

      await ctx.db.insert("patient_review_status", data);
    }

    return null;
  },
});

/**
 * Save a calculated questionnaire score
 */
export const saveQuestionnaireScore = mutation({
  args: {
    userId: v.id("users"),
    questionnaireName: v.string(),
    score: v.number(),
    maxScore: v.optional(v.number()),
    category: v.optional(v.string()),
    interpretation: v.optional(v.string()),
    calculationMetadata: v.optional(v.string()),
  },
  returns: v.id("questionnaire_scores"),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if score already exists for this questionnaire
    const existing = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user_questionnaire", (q) =>
        q.eq("user_id", args.userId).eq("questionnaire_name", args.questionnaireName)
      )
      .first();

    if (existing) {
      // Update existing score
      await ctx.db.patch(existing._id, {
        score: args.score,
        max_score: args.maxScore,
        category: args.category,
        interpretation: args.interpretation,
        calculated_at: now,
        calculation_metadata_json: args.calculationMetadata,
      });
      return existing._id;
    } else {
      // Create new score
      const scoreId = await ctx.db.insert("questionnaire_scores", {
        user_id: args.userId,
        questionnaire_name: args.questionnaireName,
        score: args.score,
        max_score: args.maxScore,
        category: args.category,
        interpretation: args.interpretation,
        calculated_at: now,
        calculation_metadata_json: args.calculationMetadata,
      });
      return scoreId;
    }
  },
});

/**
 * Update patient visible fields configuration
 */
export const updatePatientVisibleFields = mutation({
  args: {
    userId: v.id("users"),
    fieldConfig: v.string(), // JSON string
    physicianId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const existing = await ctx.db
      .query("patient_visible_fields")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        field_config_json: args.fieldConfig,
        updated_at: now,
        updated_by_physician_id: args.physicianId,
      });
    } else {
      await ctx.db.insert("patient_visible_fields", {
        user_id: args.userId,
        field_config_json: args.fieldConfig,
        updated_at: now,
        updated_by_physician_id: args.physicianId,
      });
    }

    return null;
  },
});

/**
 * Create a new intervention for a patient
 */
export const createInterventionForPatient = mutation({
  args: {
    userId: v.id("users"),
    interventionId: v.id("interventions"),
    startDate: v.string(),
    endDate: v.optional(v.string()),
    frequency: v.optional(v.string()),
    dosage: v.optional(v.string()),
    timing: v.optional(v.string()),
    customInstructions: v.optional(v.string()),
    physicianId: v.optional(v.string()),
  },
  returns: v.id("user_interventions"),
  handler: async (ctx, args) => {
    const now = Date.now();

    const userInterventionId = await ctx.db.insert("user_interventions", {
      user_id: args.userId,
      intervention_id: args.interventionId,
      assigned_by_coach_id: args.physicianId
        ? (args.physicianId as any)
        : undefined,
      start_date: args.startDate,
      end_date: args.endDate,
      frequency: args.frequency,
      dosage: args.dosage,
      timing: args.timing,
      custom_instructions: args.customInstructions,
      status: "draft", // Start as draft until activated
      assigned_at: now,
    });

    return userInterventionId;
  },
});

/**
 * Activate interventions for a patient
 */
export const activateInterventions = mutation({
  args: {
    userId: v.id("users"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    // Get all draft interventions for this user
    const draftInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "draft")
      )
      .collect();

    // Activate each one
    for (const intervention of draftInterventions) {
      await ctx.db.patch(intervention._id, {
        status: "active",
      });
    }

    // Update patient review status to interventions_active
    await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first()
      .then(async (status) => {
        if (status) {
          await ctx.db.patch(status._id, {
            status: "interventions_active",
            updated_at: Date.now(),
          });
        }
      });

    return null;
  },
});

/**
 * Delete a physician note
 */
export const deletePhysicianNote = mutation({
  args: {
    noteId: v.id("physician_notes"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.delete(args.noteId);
    return null;
  },
});

/**
 * Update an existing user intervention
 */
export const updateUserIntervention = mutation({
  args: {
    interventionId: v.id("user_interventions"),
    updates: v.object({
      start_date: v.optional(v.string()),
      end_date: v.optional(v.string()),
      frequency: v.optional(v.string()),
      dosage: v.optional(v.string()),
      timing: v.optional(v.string()),
      custom_instructions: v.optional(v.string()),
      status: v.optional(v.string()),
    }),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.patch(args.interventionId, args.updates);
    return null;
  },
});

/**
 * Delete a user intervention
 */
export const deleteUserIntervention = mutation({
  args: {
    interventionId: v.id("user_interventions"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.delete(args.interventionId);
    return null;
  },
});

