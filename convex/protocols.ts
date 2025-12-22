import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

// ============================================
// Treatment Protocol System
// Morning and Evening Protocols with grouped tasks
// ============================================

/**
 * Task schema for protocol responses
 */
const taskSchema = v.object({
  _id: v.string(),
  taskName: v.string(),
  instructions: v.string(),
  interventionId: v.string(),
  timing: v.optional(v.string()),
  status: v.string(),           // "pending", "completed", "skipped"
  completedAt: v.optional(v.number()),
  priority: v.optional(v.number()),
  difficultyLevel: v.optional(v.number()),
  isLocked: v.boolean(),        // Time window not active yet
});

/**
 * Get user's protocols with grouped tasks
 * Returns morning protocol, evening protocol, and standalone tasks
 */
export const getUserProtocols = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.object({
    morningProtocol: v.optional(
      v.object({
        protocolId: v.string(),
        name: v.string(),
        description: v.string(),
        icon: v.string(),
        color: v.string(),
        timeWindow: v.string(),
        windowStartHour: v.number(),
        windowEndHour: v.number(),
        tasks: v.array(taskSchema),
        completedCount: v.number(),
        totalCount: v.number(),
        isActive: v.boolean(),    // Time window currently active
      })
    ),
    eveningProtocol: v.optional(
      v.object({
        protocolId: v.string(),
        name: v.string(),
        description: v.string(),
        icon: v.string(),
        color: v.string(),
        timeWindow: v.string(),
        windowStartHour: v.number(),
        windowEndHour: v.number(),
        tasks: v.array(taskSchema),
        completedCount: v.number(),
        totalCount: v.number(),
        isActive: v.boolean(),
      })
    ),
    standaloneTasks: v.array(taskSchema),
    currentTimeWindow: v.string(),
  }),
  handler: async (ctx, args) => {
    const currentHour = new Date().getHours();
    const today = new Date().toISOString().split("T")[0];

    // Determine current time window
    let currentTimeWindow = "morning";
    if (currentHour >= 21 || currentHour < 5) currentTimeWindow = "night";
    else if (currentHour >= 17) currentTimeWindow = "evening";
    else if (currentHour >= 12) currentTimeWindow = "afternoon";

    // Get user's protocol assignments
    const protocolAssignments = await ctx.db
      .query("user_protocol_assignments")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .collect();

    // Get protocol definitions
    const protocols = await ctx.db.query("treatment_protocols").collect();

    // Get user's active interventions
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .collect();

    // Get today's compliance data
    const todayCompliance = await ctx.db
      .query("intervention_compliance")
      .withIndex("by_date", (q) => q.eq("scheduled_date", today))
      .collect();

    const userTodayCompliance = todayCompliance.filter((c) =>
      userInterventions.some((ui) => ui._id === c.user_intervention_id)
    );

    // Get intervention details
    const interventionIds = userInterventions.map((ui) => ui.intervention_id);
    const interventions = await Promise.all(
      interventionIds.map((id) => ctx.db.get(id))
    );
    const interventionMap = new Map(
      interventions.filter(Boolean).map((i) => [i!._id, i!])
    );

    // Get difficulty settings for all user interventions
    const difficultySettings = await ctx.db
      .query("intervention_difficulty_settings")
      .collect();
    const difficultyMap = new Map(
      difficultySettings.map((d) => [d.user_intervention_id, d])
    );

    // Helper to build task object
    const buildTask = (userIntervention: typeof userInterventions[0]) => {
      const intervention = interventionMap.get(userIntervention.intervention_id);
      const compliance = userTodayCompliance.find(
        (c) => c.user_intervention_id === userIntervention._id
      );
      const difficulty = difficultyMap.get(userIntervention._id);

      // Check if task is locked (time window not active)
      const taskWindow = userIntervention.time_window || "morning";
      const windowHours = getTimeWindowHours(taskWindow);
      const isLocked = windowHours
        ? currentHour < windowHours.start || currentHour >= windowHours.end
        : false;

      return {
        _id: userIntervention._id,
        taskName: intervention?.short_name || intervention?.name || "Task",
        instructions:
          userIntervention.patient_instructions ||
          intervention?.instructions_text ||
          "",
        interventionId: intervention?.intervention_id || "",
        timing: userIntervention.timing,
        status: compliance?.completed
          ? "completed"
          : isLocked
          ? "pending"
          : "pending",
        completedAt: compliance?.completed_at,
        priority: userIntervention.priority,
        difficultyLevel: difficulty?.current_difficulty,
        isLocked,
      };
    };

    // Build protocols
    let morningProtocol = undefined;
    let eveningProtocol = undefined;
    const standaloneTasks: ReturnType<typeof buildTask>[] = [];

    // Get assigned protocol intervention IDs
    const morningAssignment = protocolAssignments.find(
      (pa) => pa.protocol_id === "morning_protocol"
    );
    const eveningAssignment = protocolAssignments.find(
      (pa) => pa.protocol_id === "evening_protocol"
    );

    const morningInterventionIds = morningAssignment
      ? JSON.parse(morningAssignment.intervention_ids_json)
      : [];
    const eveningInterventionIds = eveningAssignment
      ? JSON.parse(eveningAssignment.intervention_ids_json)
      : [];

    // Separate interventions by protocol
    for (const ui of userInterventions) {
      const intervention = interventionMap.get(ui.intervention_id);
      const interventionStringId = intervention?.intervention_id;

      if (
        morningInterventionIds.includes(interventionStringId) ||
        ui.time_window === "morning"
      ) {
        // Will be added to morning protocol
        continue;
      } else if (
        eveningInterventionIds.includes(interventionStringId) ||
        ui.time_window === "evening" ||
        ui.time_window === "night"
      ) {
        // Will be added to evening protocol
        continue;
      } else {
        // Standalone task
        standaloneTasks.push(buildTask(ui));
      }
    }

    // Build morning protocol
    const morningProtocolDef = protocols.find(
      (p) => p.protocol_id === "morning_protocol"
    );
    if (morningProtocolDef) {
      const morningTasks = userInterventions
        .filter((ui) => {
          const intervention = interventionMap.get(ui.intervention_id);
          return (
            morningInterventionIds.includes(intervention?.intervention_id) ||
            ui.time_window === "morning"
          );
        })
        .map(buildTask);

      if (morningTasks.length > 0) {
        const completedCount = morningTasks.filter(
          (t) => t.status === "completed"
        ).length;

        morningProtocol = {
          protocolId: "morning_protocol",
          name: morningProtocolDef.name,
          description: morningProtocolDef.description,
          icon: morningProtocolDef.icon,
          color: morningProtocolDef.color,
          timeWindow: morningProtocolDef.time_window,
          windowStartHour: morningProtocolDef.window_start_hour,
          windowEndHour: morningProtocolDef.window_end_hour,
          tasks: morningTasks,
          completedCount,
          totalCount: morningTasks.length,
          isActive:
            currentHour >= morningProtocolDef.window_start_hour &&
            currentHour < morningProtocolDef.window_end_hour,
        };
      }
    }

    // Build evening protocol
    const eveningProtocolDef = protocols.find(
      (p) => p.protocol_id === "evening_protocol"
    );
    if (eveningProtocolDef) {
      const eveningTasks = userInterventions
        .filter((ui) => {
          const intervention = interventionMap.get(ui.intervention_id);
          return (
            eveningInterventionIds.includes(intervention?.intervention_id) ||
            ui.time_window === "evening" ||
            ui.time_window === "night"
          );
        })
        .map(buildTask);

      if (eveningTasks.length > 0) {
        const completedCount = eveningTasks.filter(
          (t) => t.status === "completed"
        ).length;

        eveningProtocol = {
          protocolId: "evening_protocol",
          name: eveningProtocolDef.name,
          description: eveningProtocolDef.description,
          icon: eveningProtocolDef.icon,
          color: eveningProtocolDef.color,
          timeWindow: eveningProtocolDef.time_window,
          windowStartHour: eveningProtocolDef.window_start_hour,
          windowEndHour: eveningProtocolDef.window_end_hour,
          tasks: eveningTasks,
          completedCount,
          totalCount: eveningTasks.length,
          isActive:
            currentHour >= eveningProtocolDef.window_start_hour ||
            currentHour < 5, // Evening protocol active until 5 AM
        };
      }
    }

    return {
      morningProtocol,
      eveningProtocol,
      standaloneTasks,
      currentTimeWindow,
    };
  },
});

// Time window hours helper
function getTimeWindowHours(
  window: string
): { start: number; end: number } | null {
  const windows: Record<string, { start: number; end: number }> = {
    morning: { start: 5, end: 12 },
    afternoon: { start: 12, end: 17 },
    evening: { start: 17, end: 21 },
    night: { start: 21, end: 5 }, // Wraps around midnight
  };
  return windows[window] || null;
}

/**
 * Assign a protocol to a patient (physician action)
 */
export const assignProtocol = mutation({
  args: {
    userId: v.id("users"),
    protocolId: v.string(),          // "morning_protocol" or "evening_protocol"
    interventionIds: v.array(v.string()), // Array of intervention_id strings
    physicianId: v.optional(v.string()),
    startDate: v.optional(v.string()),
  },
  returns: v.id("user_protocol_assignments"),
  handler: async (ctx, args) => {
    const now = Date.now();
    const today = args.startDate || new Date().toISOString().split("T")[0];

    // Check if assignment already exists
    const existing = await ctx.db
      .query("user_protocol_assignments")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .filter((q) => q.eq(q.field("protocol_id"), args.protocolId))
      .first();

    if (existing) {
      // Update existing assignment
      await ctx.db.patch(existing._id, {
        intervention_ids_json: JSON.stringify(args.interventionIds),
        updated_at: now,
      });
      return existing._id;
    }

    // Create new assignment
    return await ctx.db.insert("user_protocol_assignments", {
      user_id: args.userId,
      protocol_id: args.protocolId,
      intervention_ids_json: JSON.stringify(args.interventionIds),
      start_date: today,
      status: "active",
      assigned_by_physician_id: args.physicianId,
      assigned_at: now,
      updated_at: now,
    });
  },
});

/**
 * Remove an intervention from a protocol
 */
export const removeFromProtocol = mutation({
  args: {
    userId: v.id("users"),
    protocolId: v.string(),
    interventionId: v.string(),
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const assignment = await ctx.db
      .query("user_protocol_assignments")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .filter((q) => q.eq(q.field("protocol_id"), args.protocolId))
      .first();

    if (!assignment) return false;

    const currentIds = JSON.parse(assignment.intervention_ids_json) as string[];
    const newIds = currentIds.filter((id) => id !== args.interventionId);

    await ctx.db.patch(assignment._id, {
      intervention_ids_json: JSON.stringify(newIds),
      updated_at: now,
    });

    return true;
  },
});

/**
 * Pause a protocol
 */
export const pauseProtocol = mutation({
  args: {
    userId: v.id("users"),
    protocolId: v.string(),
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const assignment = await ctx.db
      .query("user_protocol_assignments")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "active")
      )
      .filter((q) => q.eq(q.field("protocol_id"), args.protocolId))
      .first();

    if (!assignment) return false;

    await ctx.db.patch(assignment._id, {
      status: "paused",
      updated_at: now,
    });

    return true;
  },
});

/**
 * Resume a paused protocol
 */
export const resumeProtocol = mutation({
  args: {
    userId: v.id("users"),
    protocolId: v.string(),
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const assignment = await ctx.db
      .query("user_protocol_assignments")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) =>
        q.and(
          q.eq(q.field("protocol_id"), args.protocolId),
          q.eq(q.field("status"), "paused")
        )
      )
      .first();

    if (!assignment) return false;

    await ctx.db.patch(assignment._id, {
      status: "active",
      updated_at: now,
    });

    return true;
  },
});

/**
 * Update protocol status (pause/resume)
 */
export const updateProtocolStatus = mutation({
  args: {
    userId: v.id("users"),
    protocolId: v.string(),
    status: v.union(v.literal("active"), v.literal("paused")),
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const assignment = await ctx.db
      .query("user_protocol_assignments")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("protocol_id"), args.protocolId))
      .first();

    if (!assignment) return false;

    await ctx.db.patch(assignment._id, {
      status: args.status,
      updated_at: now,
    });

    return true;
  },
});

/**
 * Get protocol compliance summary
 */
export const getProtocolCompliance = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 7
  },
  returns: v.object({
    morningProtocol: v.object({
      complianceRate: v.number(),
      completedDays: v.number(),
      totalDays: v.number(),
    }),
    eveningProtocol: v.object({
      complianceRate: v.number(),
      completedDays: v.number(),
      totalDays: v.number(),
    }),
    overall: v.object({
      complianceRate: v.number(),
      tasksCompleted: v.number(),
      totalTasks: v.number(),
    }),
  }),
  handler: async (ctx, args) => {
    const daysToCheck = args.days ?? 7;

    // Generate dates
    const dates: string[] = [];
    for (let i = 0; i < daysToCheck; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split("T")[0]);
    }

    // Get protocol assignments
    const assignments = await ctx.db
      .query("user_protocol_assignments")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get user interventions
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get compliance records
    const compliance = await ctx.db
      .query("intervention_compliance")
      .collect();

    const userComplianceByDate = compliance.filter((c) => {
      const ui = userInterventions.find(
        (ui) => ui._id === c.user_intervention_id
      );
      return ui && dates.includes(c.scheduled_date);
    });

    // Calculate per-protocol compliance
    const morningAssignment = assignments.find(
      (a) => a.protocol_id === "morning_protocol"
    );
    const eveningAssignment = assignments.find(
      (a) => a.protocol_id === "evening_protocol"
    );

    const morningInterventionIds = morningAssignment
      ? JSON.parse(morningAssignment.intervention_ids_json)
      : [];
    const eveningInterventionIds = eveningAssignment
      ? JSON.parse(eveningAssignment.intervention_ids_json)
      : [];

    // Get interventions
    const interventions = await ctx.db.query("interventions").collect();
    const interventionIdMap = new Map(
      interventions.map((i) => [i.intervention_id, i._id])
    );

    // Map string IDs to Convex IDs
    const morningConvexIds = morningInterventionIds
      .map((id: string) => interventionIdMap.get(id))
      .filter(Boolean);
    const eveningConvexIds = eveningInterventionIds
      .map((id: string) => interventionIdMap.get(id))
      .filter(Boolean);

    // Calculate morning protocol compliance
    let morningCompleted = 0;
    let morningTotal = 0;
    let morningCompleteDays = 0;

    for (const date of dates) {
      const dayRecords = userComplianceByDate.filter(
        (c) => c.scheduled_date === date
      );
      const morningUis = userInterventions.filter((ui) =>
        morningConvexIds.includes(ui.intervention_id)
      );

      if (morningUis.length > 0) {
        morningTotal += morningUis.length;
        const completed = dayRecords.filter((c) => {
          const ui = morningUis.find(
            (ui) => ui._id === c.user_intervention_id
          );
          return ui && c.completed;
        }).length;
        morningCompleted += completed;
        if (completed === morningUis.length) morningCompleteDays++;
      }
    }

    // Calculate evening protocol compliance
    let eveningCompleted = 0;
    let eveningTotal = 0;
    let eveningCompleteDays = 0;

    for (const date of dates) {
      const dayRecords = userComplianceByDate.filter(
        (c) => c.scheduled_date === date
      );
      const eveningUis = userInterventions.filter((ui) =>
        eveningConvexIds.includes(ui.intervention_id)
      );

      if (eveningUis.length > 0) {
        eveningTotal += eveningUis.length;
        const completed = dayRecords.filter((c) => {
          const ui = eveningUis.find(
            (ui) => ui._id === c.user_intervention_id
          );
          return ui && c.completed;
        }).length;
        eveningCompleted += completed;
        if (completed === eveningUis.length) eveningCompleteDays++;
      }
    }

    // Overall compliance
    const totalCompleted = morningCompleted + eveningCompleted;
    const totalTasks = morningTotal + eveningTotal;

    return {
      morningProtocol: {
        complianceRate: morningTotal > 0 ? (morningCompleted / morningTotal) * 100 : 0,
        completedDays: morningCompleteDays,
        totalDays: daysToCheck,
      },
      eveningProtocol: {
        complianceRate: eveningTotal > 0 ? (eveningCompleted / eveningTotal) * 100 : 0,
        completedDays: eveningCompleteDays,
        totalDays: daysToCheck,
      },
      overall: {
        complianceRate: totalTasks > 0 ? (totalCompleted / totalTasks) * 100 : 0,
        tasksCompleted: totalCompleted,
        totalTasks,
      },
    };
  },
});

/**
 * Seed default protocol definitions
 */
export const seedProtocols = mutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const now = Date.now();

    // Check if protocols already exist
    const existing = await ctx.db.query("treatment_protocols").collect();
    if (existing.length > 0) return null;

    // Morning Protocol
    await ctx.db.insert("treatment_protocols", {
      protocol_id: "morning_protocol",
      name: "Morning Protocol",
      description: "Start your day with energy-boosting and circadian-aligned activities",
      time_window: "morning",
      window_start_hour: 5,
      window_end_hour: 12,
      icon: "sun.max.fill",
      color: "#FF9500",
      order_index: 1,
      is_active: true,
      created_at: now,
    });

    // Evening Protocol
    await ctx.db.insert("treatment_protocols", {
      protocol_id: "evening_protocol",
      name: "Evening Protocol",
      description: "Wind down and prepare your body for restorative sleep",
      time_window: "evening",
      window_start_hour: 17,
      window_end_hour: 24,
      icon: "moon.stars.fill",
      color: "#5856D6",
      order_index: 2,
      is_active: true,
      created_at: now,
    });

    return null;
  },
});
