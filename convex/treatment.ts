import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// Patient Treatment Mode Queries
// ============================================

/**
 * Get all active interventions/tasks for a patient
 * Used by iOS, Web, and Watch apps to show daily treatment tasks
 */
export const getActiveInterventions = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("user_interventions"),
      intervention_id: v.id("interventions"),
      name: v.string(),
      category: v.optional(v.string()),
      instructions: v.string(),
      start_date: v.string(),
      end_date: v.optional(v.string()),
      frequency: v.optional(v.string()),
      timing: v.optional(v.string()),
      custom_instructions: v.optional(v.string()),
      status: v.string(),
      todayCompleted: v.boolean(),
    })
  ),
  handler: async (ctx, args) => {
    // Get active user interventions
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .collect();

    const today = new Date().toISOString().split("T")[0];

    // Enrich with intervention details and check today's compliance
    const enriched = await Promise.all(
      userInterventions.map(async (ui) => {
        const intervention = await ctx.db.get(ui.intervention_id);

        // Check if completed today
        const todayCompliance = await ctx.db
          .query("intervention_compliance")
          .withIndex("by_intervention_date", (q) =>
            q.eq("user_intervention_id", ui._id).eq("scheduled_date", today)
          )
          .first();

        return {
          _id: ui._id,
          intervention_id: ui.intervention_id,
          name: intervention?.name || "Unknown Intervention",
          category: intervention?.category,
          instructions: intervention?.instructions_text || "",
          start_date: ui.start_date,
          end_date: ui.end_date,
          frequency: ui.frequency,
          timing: ui.timing,
          custom_instructions: ui.custom_instructions,
          status: ui.status,
          todayCompleted: todayCompliance?.completed || false,
        };
      })
    );

    // Sort by timing (morning first, then afternoon, evening, before bed)
    const timingOrder = ["Morning", "Afternoon", "Evening", "Before bed", "With meals"];
    enriched.sort((a, b) => {
      const aIdx = timingOrder.indexOf(a.timing || "") || 99;
      const bIdx = timingOrder.indexOf(b.timing || "") || 99;
      return aIdx - bIdx;
    });

    return enriched;
  },
});

/**
 * Get today's tasks summary for dashboard display
 */
export const getTodayTasksSummary = query({
  args: { userId: v.id("users") },
  returns: v.object({
    totalTasks: v.number(),
    completedTasks: v.number(),
    pendingTasks: v.number(),
    completionPercentage: v.number(),
    nextTask: v.optional(
      v.object({
        name: v.string(),
        timing: v.optional(v.string()),
        instructions: v.string(),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .collect();

    const today = new Date().toISOString().split("T")[0];
    let completedTasks = 0;
    let nextTask: { name: string; timing?: string; instructions: string } | undefined;

    const timingOrder = ["Morning", "Afternoon", "Evening", "Before bed", "With meals"];
    const sortedInterventions: Array<{
      ui: typeof userInterventions[0];
      intervention: any;
      completed: boolean;
    }> = [];

    for (const ui of userInterventions) {
      const intervention = await ctx.db.get(ui.intervention_id);
      const compliance = await ctx.db
        .query("intervention_compliance")
        .withIndex("by_intervention_date", (q) =>
          q.eq("user_intervention_id", ui._id).eq("scheduled_date", today)
        )
        .first();

      if (compliance?.completed) {
        completedTasks++;
      }

      sortedInterventions.push({
        ui,
        intervention,
        completed: compliance?.completed || false,
      });
    }

    // Sort by timing
    sortedInterventions.sort((a, b) => {
      const aIdx = timingOrder.indexOf(a.ui.timing || "") || 99;
      const bIdx = timingOrder.indexOf(b.ui.timing || "") || 99;
      return aIdx - bIdx;
    });

    // Find next incomplete task
    const nextIncomplete = sortedInterventions.find((s) => !s.completed);
    if (nextIncomplete) {
      nextTask = {
        name: nextIncomplete.intervention?.name || "Task",
        timing: nextIncomplete.ui.timing,
        instructions: nextIncomplete.intervention?.instructions_text || "",
      };
    }

    const totalTasks = userInterventions.length;
    const pendingTasks = totalTasks - completedTasks;
    const completionPercentage =
      totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;

    return {
      totalTasks,
      completedTasks,
      pendingTasks,
      completionPercentage,
      nextTask,
    };
  },
});

/**
 * Get treatment history/compliance for a patient
 */
export const getComplianceHistory = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 7 days
  },
  returns: v.array(
    v.object({
      date: v.string(),
      totalTasks: v.number(),
      completedTasks: v.number(),
      tasks: v.array(
        v.object({
          name: v.string(),
          completed: v.boolean(),
          completedAt: v.optional(v.number()),
        })
      ),
    })
  ),
  handler: async (ctx, args) => {
    const daysToFetch = args.days || 7;
    const today = new Date();
    const history: Array<{
      date: string;
      totalTasks: number;
      completedTasks: number;
      tasks: Array<{ name: string; completed: boolean; completedAt?: number }>;
    }> = [];

    // Get all user interventions (active and completed)
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (let i = 0; i < daysToFetch; i++) {
      const date = new Date(today);
      date.setDate(date.getDate() - i);
      const dateStr = date.toISOString().split("T")[0];

      const dayTasks: Array<{
        name: string;
        completed: boolean;
        completedAt?: number;
      }> = [];

      for (const ui of userInterventions) {
        // Check if intervention was active on this date
        if (ui.start_date <= dateStr && (!ui.end_date || ui.end_date >= dateStr)) {
          const intervention = await ctx.db.get(ui.intervention_id);
          const compliance = await ctx.db
            .query("intervention_compliance")
            .withIndex("by_intervention_date", (q) =>
              q.eq("user_intervention_id", ui._id).eq("scheduled_date", dateStr)
            )
            .first();

          dayTasks.push({
            name: intervention?.name || "Task",
            completed: compliance?.completed || false,
            completedAt: compliance?.completed_at,
          });
        }
      }

      history.push({
        date: dateStr,
        totalTasks: dayTasks.length,
        completedTasks: dayTasks.filter((t) => t.completed).length,
        tasks: dayTasks,
      });
    }

    return history;
  },
});

/**
 * Get patient's treatment phase info
 */
export const getTreatmentPhase = query({
  args: { userId: v.id("users") },
  returns: v.object({
    phase: v.string(), // "intake", "treatment", "completed"
    intakeDay: v.number(),
    intakeComplete: v.boolean(),
    treatmentStartDate: v.optional(v.string()),
    treatmentWeek: v.optional(v.number()),
    activeInterventionCount: v.number(),
  }),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("User not found");

    // Check review status
    const reviewStatus = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    // Count active interventions
    const activeInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .collect();

    const intakeComplete = user.current_day > 15;
    const inTreatment = reviewStatus?.status === "interventions_active";

    // Calculate treatment week if in treatment
    let treatmentWeek: number | undefined;
    let treatmentStartDate: string | undefined;

    if (inTreatment && activeInterventions.length > 0) {
      // Find earliest intervention start date
      const startDates = activeInterventions
        .map((i) => i.start_date)
        .sort();
      treatmentStartDate = startDates[0];

      if (treatmentStartDate) {
        const start = new Date(treatmentStartDate);
        const now = new Date();
        const daysDiff = Math.floor(
          (now.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)
        );
        treatmentWeek = Math.floor(daysDiff / 7) + 1;
      }
    }

    let phase: "intake" | "treatment" | "completed" = "intake";
    if (inTreatment) {
      phase = "treatment";
    } else if (intakeComplete) {
      phase = "completed"; // Intake done, waiting for physician review
    }

    return {
      phase,
      intakeDay: user.current_day,
      intakeComplete,
      treatmentStartDate,
      treatmentWeek,
      activeInterventionCount: activeInterventions.length,
    };
  },
});

// ============================================
// Patient Treatment Mode Mutations
// ============================================

/**
 * Mark a task as completed for today
 */
export const completeTask = mutation({
  args: {
    userInterventionId: v.id("user_interventions"),
    note: v.optional(v.string()),
  },
  returns: v.id("intervention_compliance"),
  handler: async (ctx, args) => {
    const today = new Date().toISOString().split("T")[0];
    const now = Date.now();

    // Check if already exists
    const existing = await ctx.db
      .query("intervention_compliance")
      .withIndex("by_intervention_date", (q) =>
        q
          .eq("user_intervention_id", args.userInterventionId)
          .eq("scheduled_date", today)
      )
      .first();

    if (existing) {
      // Update existing
      await ctx.db.patch(existing._id, {
        completed: true,
        completed_at: now,
        note_text: args.note,
      });
      return existing._id;
    } else {
      // Create new
      const complianceId = await ctx.db.insert("intervention_compliance", {
        user_intervention_id: args.userInterventionId,
        scheduled_date: today,
        completed: true,
        completed_at: now,
        note_text: args.note,
      });
      return complianceId;
    }
  },
});

/**
 * Uncomplete a task (undo completion)
 */
export const uncompleteTask = mutation({
  args: {
    userInterventionId: v.id("user_interventions"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const today = new Date().toISOString().split("T")[0];

    const existing = await ctx.db
      .query("intervention_compliance")
      .withIndex("by_intervention_date", (q) =>
        q
          .eq("user_intervention_id", args.userInterventionId)
          .eq("scheduled_date", today)
      )
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        completed: false,
        completed_at: undefined,
      });
    }

    return null;
  },
});

/**
 * Add a note to a treatment task
 */
export const addTaskNote = mutation({
  args: {
    userInterventionId: v.id("user_interventions"),
    noteText: v.string(),
    moodRating: v.optional(v.number()),
  },
  returns: v.id("intervention_user_notes"),
  handler: async (ctx, args) => {
    const noteId = await ctx.db.insert("intervention_user_notes", {
      user_intervention_id: args.userInterventionId,
      note_text: args.noteText,
      mood_rating: args.moodRating,
      created_at: Date.now(),
    });
    return noteId;
  },
});

/**
 * Get notes for a specific intervention
 */
export const getTaskNotes = query({
  args: { userInterventionId: v.id("user_interventions") },
  returns: v.array(
    v.object({
      _id: v.id("intervention_user_notes"),
      note_text: v.string(),
      mood_rating: v.optional(v.number()),
      created_at: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const notes = await ctx.db
      .query("intervention_user_notes")
      .withIndex("by_intervention", (q) =>
        q.eq("user_intervention_id", args.userInterventionId)
      )
      .collect();

    return notes
      .sort((a, b) => b.created_at - a.created_at)
      .map((n) => ({
        _id: n._id,
        note_text: n.note_text,
        mood_rating: n.mood_rating,
        created_at: n.created_at,
      }));
  },
});

// ============================================
// Watch-Specific Queries (Simplified for small screen)
// ============================================

/**
 * Get simplified task list for Apple Watch
 */
export const getWatchTasks = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("user_interventions"),
      name: v.string(),
      timing: v.optional(v.string()),
      completed: v.boolean(),
      shortInstructions: v.string(), // Truncated for watch display
    })
  ),
  handler: async (ctx, args) => {
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .collect();

    const today = new Date().toISOString().split("T")[0];
    const timingOrder = ["Morning", "Afternoon", "Evening", "Before bed", "With meals"];

    const tasks = await Promise.all(
      userInterventions.map(async (ui) => {
        const intervention = await ctx.db.get(ui.intervention_id);
        const compliance = await ctx.db
          .query("intervention_compliance")
          .withIndex("by_intervention_date", (q) =>
            q.eq("user_intervention_id", ui._id).eq("scheduled_date", today)
          )
          .first();

        // Truncate instructions for watch (max 50 chars)
        const fullInstructions = ui.custom_instructions || intervention?.instructions_text || "";
        const shortInstructions =
          fullInstructions.length > 50
            ? fullInstructions.substring(0, 47) + "..."
            : fullInstructions;

        return {
          _id: ui._id,
          name: intervention?.name || "Task",
          timing: ui.timing,
          completed: compliance?.completed || false,
          shortInstructions,
        };
      })
    );

    // Sort by timing
    tasks.sort((a, b) => {
      const aIdx = timingOrder.indexOf(a.timing || "") || 99;
      const bIdx = timingOrder.indexOf(b.timing || "") || 99;
      return aIdx - bIdx;
    });

    return tasks;
  },
});

/**
 * Quick complete for watch (simplified mutation)
 */
export const watchCompleteTask = mutation({
  args: {
    userInterventionId: v.id("user_interventions"),
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const today = new Date().toISOString().split("T")[0];
    const now = Date.now();

    const existing = await ctx.db
      .query("intervention_compliance")
      .withIndex("by_intervention_date", (q) =>
        q
          .eq("user_intervention_id", args.userInterventionId)
          .eq("scheduled_date", today)
      )
      .first();

    if (existing) {
      // Toggle completion
      await ctx.db.patch(existing._id, {
        completed: !existing.completed,
        completed_at: !existing.completed ? now : undefined,
      });
      return !existing.completed;
    } else {
      // Create as completed
      await ctx.db.insert("intervention_compliance", {
        user_intervention_id: args.userInterventionId,
        scheduled_date: today,
        completed: true,
        completed_at: now,
      });
      return true;
    }
  },
});
