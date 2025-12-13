import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// Assessment Questions
// ============================================

// Get all master questions
export const getMasterQuestions = query({
  args: {},
  handler: async (ctx) => {
    const questions = await ctx.db.query("assessment_questions").collect();
    return questions.sort((a, b) => {
      // Sort by pillar, then tier, then question_id
      if (a.pillar !== b.pillar) return a.pillar.localeCompare(b.pillar);
      if (a.tier !== b.tier) return a.tier.localeCompare(b.tier);
      return a.question_id.localeCompare(b.question_id);
    });
  },
});

// Get question by ID
export const getAssessmentQuestionById = query({
  args: { questionId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("assessment_questions")
      .withIndex("by_question_id", (q) => q.eq("question_id", args.questionId))
      .first();
  },
});

// Update assessment question
export const updateAssessmentQuestion = mutation({
  args: {
    questionId: v.string(),
    updates: v.object({
      question_text: v.optional(v.string()),
      question_type: v.optional(v.string()),
      options_json: v.optional(v.string()),
      estimated_time: v.optional(v.number()),
      trigger: v.optional(v.string()),
    }),
  },
  handler: async (ctx, args) => {
    const question = await ctx.db
      .query("assessment_questions")
      .withIndex("by_question_id", (q) => q.eq("question_id", args.questionId))
      .first();

    if (!question) {
      throw new Error(`Question ${args.questionId} not found`);
    }

    await ctx.db.patch(question._id, args.updates);
  },
});

// ============================================
// Assessment Modules
// ============================================

// Get all modules
export const getModules = query({
  args: {},
  handler: async (ctx) => {
    const modules = await ctx.db.query("assessment_modules").collect();
    return modules.sort((a, b) => {
      if (a.tier !== b.tier) return a.tier.localeCompare(b.tier);
      if (a.pillar !== b.pillar) return a.pillar.localeCompare(b.pillar);
      return a.name.localeCompare(b.name);
    });
  },
});

// Get module by ID
export const getModuleById = query({
  args: { moduleId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("assessment_modules")
      .withIndex("by_module_id", (q) => q.eq("module_id", args.moduleId))
      .first();
  },
});

// Get module with questions
export const getModuleWithQuestions = query({
  args: { moduleId: v.string() },
  handler: async (ctx, args) => {
    const module = await ctx.db
      .query("assessment_modules")
      .withIndex("by_module_id", (q) => q.eq("module_id", args.moduleId))
      .first();

    if (!module) return null;

    const moduleQuestions = await ctx.db
      .query("module_questions")
      .withIndex("by_module_order", (q) => q.eq("module_id", args.moduleId))
      .collect();

    const questions = await Promise.all(
      moduleQuestions
        .sort((a, b) => a.order_index - b.order_index)
        .map(async (mq) => {
          const question = await ctx.db
            .query("assessment_questions")
            .withIndex("by_question_id", (q) => q.eq("question_id", mq.question_id))
            .first();
          return question;
        })
    );

    return {
      ...module,
      questions: questions.filter((q) => q !== null),
    };
  },
});

// ============================================
// Module Questions
// ============================================

// Get questions for a module
export const getModuleQuestions = query({
  args: { moduleId: v.string() },
  handler: async (ctx, args) => {
    const moduleQuestions = await ctx.db
      .query("module_questions")
      .withIndex("by_module_order", (q) => q.eq("module_id", args.moduleId))
      .collect();

    return moduleQuestions.sort((a, b) => a.order_index - b.order_index);
  },
});

// Reorder questions within a module
export const reorderModuleQuestions = mutation({
  args: {
    moduleId: v.string(),
    questionIds: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    // Delete existing entries for this module
    const existing = await ctx.db
      .query("module_questions")
      .withIndex("by_module", (q) => q.eq("module_id", args.moduleId))
      .collect();

    for (const entry of existing) {
      await ctx.db.delete(entry._id);
    }

    // Insert with new order
    for (let i = 0; i < args.questionIds.length; i++) {
      await ctx.db.insert("module_questions", {
        module_id: args.moduleId,
        question_id: args.questionIds[i],
        order_index: i,
      });
    }
  },
});

// ============================================
// Day Modules
// ============================================

// Get day assignments
export const getDayAssignments = query({
  args: {},
  handler: async (ctx) => {
    const assignments = await ctx.db
      .query("day_modules")
      .withIndex("by_day_order")
      .collect();

    // Group by day number
    const dayAssignments: Record<number, any[]> = {};
    for (const assignment of assignments) {
      if (!dayAssignments[assignment.day_number]) {
        dayAssignments[assignment.day_number] = [];
      }
      const module = await ctx.db
        .query("assessment_modules")
        .withIndex("by_module_id", (q) => q.eq("module_id", assignment.module_id))
        .first();
      if (module) {
        dayAssignments[assignment.day_number].push({
          ...assignment,
          module,
        });
      }
    }

    // Sort each day's modules by order_index
    for (const dayNumber in dayAssignments) {
      dayAssignments[dayNumber].sort((a, b) => a.order_index - b.order_index);
    }

    return dayAssignments;
  },
});

// Enhanced day assignments with computed question counts and gateway info
export const getDayAssignmentsEnhanced = query({
  args: {},
  handler: async (ctx) => {
    const assignments = await ctx.db
      .query("day_modules")
      .withIndex("by_day_order")
      .collect();

    // Get all gateways for reference
    const allGateways = await ctx.db.query("module_gateways").collect();

    // Group by day number and enrich with computed data
    const dayAssignments: Record<
      number,
      {
        modules: any[];
        total_questions: number;
        total_minutes: number;
        gateways: any[];
      }
    > = {};

    for (const assignment of assignments) {
      if (!dayAssignments[assignment.day_number]) {
        dayAssignments[assignment.day_number] = {
          modules: [],
          total_questions: 0,
          total_minutes: 0,
          gateways: [],
        };
      }

      const module = await ctx.db
        .query("assessment_modules")
        .withIndex("by_module_id", (q) => q.eq("module_id", assignment.module_id))
        .first();

      if (!module) continue;

      // COUNT questions from module_questions table (the fix!)
      const moduleQuestions = await ctx.db
        .query("module_questions")
        .withIndex("by_module", (q) => q.eq("module_id", assignment.module_id))
        .collect();

      const questionCount = moduleQuestions.length;

      // Check if this is an expansion module
      const isExpansion = module.tier === "EXPANSION";

      // Find which gateways can trigger this expansion module
      const relatedGateways = allGateways.filter((g) => {
        try {
          const targetModules = JSON.parse(g.target_modules_json || "[]");
          return targetModules.includes(assignment.module_id);
        } catch {
          return false;
        }
      });

      dayAssignments[assignment.day_number].modules.push({
        ...assignment,
        module: {
          ...module,
          question_count: questionCount, // Computed value!
        },
        is_expansion: isExpansion,
        required_gateways: relatedGateways.map((g) => g.gateway_id),
      });

      dayAssignments[assignment.day_number].total_questions += questionCount;
      dayAssignments[assignment.day_number].total_minutes +=
        module.estimated_minutes || 0;
    }

    // Sort each day's modules by order_index
    for (const dayNumber in dayAssignments) {
      dayAssignments[dayNumber].modules.sort(
        (a, b) => a.order_index - b.order_index
      );
    }

    // Find gateways that have trigger questions in each day
    for (const dayNumber in dayAssignments) {
      const dayGatewayIds = new Set<string>();

      // Get all question IDs for this day
      const dayQuestionIds = new Set<string>();
      for (const mod of dayAssignments[dayNumber].modules) {
        const moduleQuestions = await ctx.db
          .query("module_questions")
          .withIndex("by_module", (q) => q.eq("module_id", mod.module.module_id))
          .collect();
        moduleQuestions.forEach((mq) => dayQuestionIds.add(mq.question_id));
      }

      // Check which gateways have trigger questions in this day
      for (const gateway of allGateways) {
        try {
          const triggerIds = JSON.parse(gateway.trigger_question_ids_json || "[]");
          if (triggerIds.some((id: string) => dayQuestionIds.has(id))) {
            dayGatewayIds.add(gateway.gateway_id);
          }
        } catch {
          // Ignore parse errors
        }
      }

      // Add gateway details
      dayAssignments[dayNumber].gateways = allGateways
        .filter((g) => dayGatewayIds.has(g.gateway_id))
        .map((g) => ({
          gateway_id: g.gateway_id,
          name: g.name,
          description: g.description,
          trigger_question_ids: JSON.parse(g.trigger_question_ids_json || "[]"),
          target_modules: JSON.parse(g.target_modules_json || "[]"),
        }));
    }

    return dayAssignments;
  },
});

// Get all questions for a specific module (for expandable preview)
export const getQuestionsForModule = query({
  args: { moduleId: v.string() },
  handler: async (ctx, args) => {
    const moduleQuestions = await ctx.db
      .query("module_questions")
      .withIndex("by_module", (q) => q.eq("module_id", args.moduleId))
      .collect();

    moduleQuestions.sort((a, b) => a.order_index - b.order_index);

    const questions = await Promise.all(
      moduleQuestions.map(async (mq) => {
        const question = await ctx.db
          .query("assessment_questions")
          .withIndex("by_question_id", (q) => q.eq("question_id", mq.question_id))
          .first();
        return question
          ? {
              question_id: question.question_id,
              question_text: question.question_text,
              pillar: question.pillar,
              tier: question.tier,
              answer_format: question.answer_format,
              estimated_time_seconds: question.estimated_time_seconds,
              order_index: mq.order_index,
            }
          : null;
      })
    );

    return questions.filter((q) => q !== null);
  },
});

// Get all gateway definitions with their expansion module info
export const getAllGateways = query({
  args: {},
  handler: async (ctx) => {
    const gateways = await ctx.db.query("module_gateways").collect();

    return Promise.all(
      gateways.map(async (gateway) => {
        let targetModuleIds: string[] = [];
        let triggerQuestionIds: string[] = [];
        let condition = {};

        try {
          targetModuleIds = JSON.parse(gateway.target_modules_json || "[]");
          triggerQuestionIds = JSON.parse(gateway.trigger_question_ids_json || "[]");
          condition = JSON.parse(gateway.condition_json || "{}");
        } catch {
          // Ignore parse errors
        }

        // Get expansion module details
        const expansionModules = await Promise.all(
          targetModuleIds.map(async (moduleId: string) => {
            const module = await ctx.db
              .query("assessment_modules")
              .withIndex("by_module_id", (q) => q.eq("module_id", moduleId))
              .first();

            if (!module) return null;

            // Count questions
            const questions = await ctx.db
              .query("module_questions")
              .withIndex("by_module", (q) => q.eq("module_id", moduleId))
              .collect();

            return {
              module_id: moduleId,
              name: module.name,
              pillar: module.pillar,
              question_count: questions.length,
              estimated_minutes: module.estimated_minutes,
            };
          })
        );

        return {
          gateway_id: gateway.gateway_id,
          name: gateway.name,
          description: gateway.description,
          condition,
          trigger_question_ids: triggerQuestionIds,
          expansion_modules: expansionModules.filter((m) => m !== null),
        };
      })
    );
  },
});

// Assign module to day
export const assignModuleToDay = mutation({
  args: {
    dayNumber: v.number(),
    moduleId: v.string(),
    orderIndex: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // Check if already assigned
    const existing = await ctx.db
      .query("day_modules")
      .withIndex("by_day", (q) => q.eq("day_number", args.dayNumber))
      .collect();

    const alreadyAssigned = existing.find((a) => a.module_id === args.moduleId);
    if (alreadyAssigned) {
      throw new Error("Module already assigned to this day");
    }

    // Get max order_index if not provided
    let order = args.orderIndex;
    if (order === undefined) {
      const maxOrder = existing.reduce((max, a) => Math.max(max, a.order_index), -1);
      order = maxOrder + 1;
    }

    await ctx.db.insert("day_modules", {
      day_number: args.dayNumber,
      module_id: args.moduleId,
      order_index: order,
    });
  },
});

// Remove module from day
export const removeModuleFromDay = mutation({
  args: {
    dayNumber: v.number(),
    moduleId: v.string(),
  },
  handler: async (ctx, args) => {
    const assignment = await ctx.db
      .query("day_modules")
      .withIndex("by_day", (q) => q.eq("day_number", args.dayNumber))
      .collect()
      .then((assignments) =>
        assignments.find((a) => a.module_id === args.moduleId)
      );

    if (assignment) {
      await ctx.db.delete(assignment._id);
    }
  },
});

// Reorder modules for a day
export const reorderDayModules = mutation({
  args: {
    dayNumber: v.number(),
    moduleIds: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    // Delete existing entries for this day
    const existing = await ctx.db
      .query("day_modules")
      .withIndex("by_day", (q) => q.eq("day_number", args.dayNumber))
      .collect();

    for (const entry of existing) {
      await ctx.db.delete(entry._id);
    }

    // Insert with new order
    for (let i = 0; i < args.moduleIds.length; i++) {
      await ctx.db.insert("day_modules", {
        day_number: args.dayNumber,
        module_id: args.moduleIds[i],
        order_index: i,
      });
    }
  },
});

// ============================================
// User Assessment Responses
// ============================================

// Save assessment response
export const saveAssessmentResponse = mutation({
  args: {
    userId: v.id("users"),
    questionId: v.string(),
    responseValue: v.optional(v.string()),
    dayNumber: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if response exists
    // Use day-aware lookup if dayNumber is provided (for repeating questions like sleep log)
    let existing;
    if (args.dayNumber !== undefined) {
      existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question_day", (q) =>
          q.eq("user_id", args.userId).eq("question_id", args.questionId).eq("day_number", args.dayNumber)
        )
        .first();
    } else {
      existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", args.questionId)
        )
        .first();
    }

    if (existing) {
      await ctx.db.patch(existing._id, {
        response_value: args.responseValue,
        day_number: args.dayNumber,
        updated_at: now,
      });
      return existing._id;
    } else {
      const responseId = await ctx.db.insert("user_assessment_responses", {
        user_id: args.userId,
        question_id: args.questionId,
        response_value: args.responseValue,
        day_number: args.dayNumber,
        created_at: now,
        updated_at: now,
      });
      return responseId;
    }
  },
});

// Get user responses
export const getUserResponses = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Convert to map (latest response per question)
    const responseMap: Record<string, string> = {};
    for (const response of responses) {
      // Keep the latest response for each question
      if (!responseMap[response.question_id] || response.updated_at > (responseMap[response.question_id] as any)) {
        responseMap[response.question_id] = response.response_value || "";
      }
    }

    return responseMap;
  },
});

// Get user name from D1 response
export const getUserName = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const response = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D1")
      )
      .order("desc")
      .first();

    return response?.response_value || null;
  },
});

// Get all user names
export const getAllUserNames = query({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db
      .query("users")
      .withIndex("by_username")
      .collect()
      .then((users) => users.filter((u) => u.username.startsWith("user")));

    const names: Record<number, string | null> = {};

    for (const user of users) {
      const response = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", user._id).eq("question_id", "D1")
        )
        .order("desc")
        .first();

      // Extract numeric ID from username (user1 -> 1, user10 -> 10)
      const match = user.username.match(/^user(\d+)$/);
      if (match) {
        const userId = parseInt(match[1], 10);
        names[userId] = response?.response_value || null;
      }
    }

    return names;
  },
});

// ============================================
// Gateway States
// ============================================

// Get user gateway states
export const getUserGatewayStates = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const states = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const stateMap: Record<string, any> = {};
    for (const state of states) {
      stateMap[state.gateway_id] = {
        triggered: state.triggered,
        triggeredAt: state.triggered_at,
        evaluationData: state.evaluation_data_json
          ? JSON.parse(state.evaluation_data_json)
          : null,
      };
    }

    return stateMap;
  },
});

// Save gateway state
export const saveGatewayState = mutation({
  args: {
    userId: v.id("users"),
    gatewayId: v.string(),
    triggered: v.boolean(),
    triggeredAt: v.optional(v.number()),
    evaluationDataJson: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    const existing = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user_gateway", (q) =>
        q.eq("user_id", args.userId).eq("gateway_id", args.gatewayId)
      )
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        triggered: args.triggered,
        triggered_at: args.triggered ? (args.triggeredAt || now) : existing.triggered_at,
        last_evaluated_at: now,
        evaluation_data_json: args.evaluationDataJson,
      });
    } else {
      await ctx.db.insert("user_gateway_states", {
        user_id: args.userId,
        gateway_id: args.gatewayId,
        triggered: args.triggered,
        triggered_at: args.triggered ? (args.triggeredAt || now) : undefined,
        last_evaluated_at: now,
        evaluation_data_json: args.evaluationDataJson,
      });
    }
  },
});

// ============================================
// Sleep Diary Questions
// ============================================

// Get sleep diary questions
export const getSleepDiaryQuestions = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("sleep_diary_questions")
      .withIndex("by_question_id")
      .collect();
  },
});

