/**
 * Query functions for assessment questions
 */

import { query } from "./_generated/server";
import { v } from "convex/values";

/**
 * Get all questions for a specific day
 * Returns questions from all modules assigned to that day
 */
export const getQuestionsByDay = query({
  args: {
    dayNumber: v.number()
  },
  returns: v.array(
    v.object({
      question_id: v.string(),
      question_text: v.string(),
      help_text: v.optional(v.string()),
      pillar: v.string(),
      tier: v.string(),
      answer_format: v.string(),
      format_config: v.string(),
      validation_rules: v.optional(v.string()),
      conditional_logic: v.optional(v.string()),
      order_index: v.optional(v.number()),
      estimated_time_seconds: v.number(),
      module_id: v.string(),
      module_name: v.string()
    })
  ),
  handler: async (ctx, args) => {
    // Get all modules for this day
    const dayModules = await ctx.db
      .query("day_modules")
      .withIndex("by_day", (q) => q.eq("day_number", args.dayNumber))
      .collect();

    const result = [];

    // For each module, get its questions
    for (const dayModule of dayModules) {
      // Get module info
      const module = await ctx.db
        .query("assessment_modules")
        .withIndex("by_module_id", (q) => q.eq("module_id", dayModule.module_id))
        .first();

      if (!module) continue;

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
          result.push({
            question_id: question.question_id,
            question_text: question.question_text,
            help_text: question.help_text,
            pillar: question.pillar,
            tier: question.tier,
            answer_format: question.answer_format,
            format_config: question.format_config,
            validation_rules: question.validation_rules,
            conditional_logic: question.conditional_logic,
            order_index: mq.order_index,
            estimated_time_seconds: question.estimated_time_seconds,
            module_id: dayModule.module_id,
            module_name: module.name
          });
        }
      }
    }

    return result;
  },
});

/**
 * Get all sleep diary questions
 */
export const getSleepDiaryQuestions = query({
  args: {},
  returns: v.array(
    v.object({
      id: v.string(),
      question_text: v.string(),
      help_text: v.optional(v.string()),
      group_key: v.optional(v.string()),
      pillar: v.optional(v.string()),
      answer_format: v.string(),
      format_config: v.string(),
      validation_rules: v.optional(v.string()),
      conditional_logic: v.optional(v.string()),
      order_index: v.optional(v.number()),
      estimated_time_seconds: v.number()
    })
  ),
  handler: async (ctx) => {
    const questions = await ctx.db.query("sleep_diary_questions").collect();

    // Sort by order_index
    questions.sort((a, b) => (a.order_index || 0) - (b.order_index || 0));

    return questions.map((q) => ({
      id: q.id,
      question_text: q.question_text,
      help_text: q.help_text,
      group_key: q.group_key,
      pillar: q.pillar,
      answer_format: q.answer_format,
      format_config: q.format_config,
      validation_rules: q.validation_rules,
      conditional_logic: q.conditional_logic,
      order_index: q.order_index,
      estimated_time_seconds: q.estimated_time_seconds
    }));
  },
});

/**
 * Get a specific question by ID
 */
export const getQuestionById = query({
  args: {
    questionId: v.string()
  },
  returns: v.union(
    v.object({
      question_id: v.string(),
      question_text: v.string(),
      help_text: v.optional(v.string()),
      pillar: v.string(),
      tier: v.string(),
      answer_format: v.string(),
      format_config: v.string(),
      validation_rules: v.optional(v.string()),
      conditional_logic: v.optional(v.string()),
      estimated_time_seconds: v.number()
    }),
    v.null()
  ),
  handler: async (ctx, args) => {
    const question = await ctx.db
      .query("assessment_questions")
      .withIndex("by_question_id", (q) => q.eq("question_id", args.questionId))
      .first();

    if (!question) return null;

    return {
      question_id: question.question_id,
      question_text: question.question_text,
      help_text: question.help_text,
      pillar: question.pillar,
      tier: question.tier,
      answer_format: question.answer_format,
      format_config: question.format_config,
      validation_rules: question.validation_rules,
      conditional_logic: question.conditional_logic,
      estimated_time_seconds: question.estimated_time_seconds
    };
  },
});

/**
 * Get day summary (modules and estimated time)
 */
export const getDaySummary = query({
  args: {
    dayNumber: v.number()
  },
  returns: v.object({
    day_number: v.number(),
    total_questions: v.number(),
    estimated_minutes: v.number(),
    modules: v.array(
      v.object({
        module_id: v.string(),
        module_name: v.string(),
        tier: v.string(),
        question_count: v.number()
      })
    )
  }),
  handler: async (ctx, args) => {
    const dayModules = await ctx.db
      .query("day_modules")
      .withIndex("by_day", (q) => q.eq("day_number", args.dayNumber))
      .collect();

    let totalQuestions = 0;
    let estimatedMinutes = 0;
    const modules = [];

    for (const dayModule of dayModules) {
      const module = await ctx.db
        .query("assessment_modules")
        .withIndex("by_module_id", (q) => q.eq("module_id", dayModule.module_id))
        .first();

      if (!module) continue;

      const moduleQuestions = await ctx.db
        .query("module_questions")
        .withIndex("by_module", (q) => q.eq("module_id", dayModule.module_id))
        .collect();

      totalQuestions += moduleQuestions.length;
      estimatedMinutes += module.estimated_minutes || 0;

      modules.push({
        module_id: dayModule.module_id,
        module_name: module.name,
        tier: module.tier,
        question_count: moduleQuestions.length
      });
    }

    return {
      day_number: args.dayNumber,
      total_questions: totalQuestions,
      estimated_minutes: Math.ceil(estimatedMinutes),
      modules
    };
  },
});

/**
 * Get user's response for a question
 */
export const getUserResponse = query({
  args: {
    userId: v.id("users"),
    questionId: v.string()
  },
  returns: v.union(
    v.object({
      response_value: v.optional(v.string()),
      response_number: v.optional(v.number()),
      response_array: v.optional(v.string()),
      response_object: v.optional(v.string()),
      answered_in_seconds: v.optional(v.number()),
      created_at: v.number(),
      updated_at: v.number()
    }),
    v.null()
  ),
  handler: async (ctx, args) => {
    const response = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", args.questionId)
      )
      .first();

    if (!response) return null;

    return {
      response_value: response.response_value,
      response_number: response.response_number,
      response_array: response.response_array,
      response_object: response.response_object,
      answered_in_seconds: response.answered_in_seconds,
      created_at: response.created_at,
      updated_at: response.updated_at
    };
  },
});

/**
 * Get user's progress for a day (which questions answered)
 */
export const getUserDayProgress = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number()
  },
  returns: v.object({
    total_questions: v.number(),
    answered_questions: v.number(),
    completion_percentage: v.number(),
    time_spent_seconds: v.number()
  }),
  handler: async (ctx, args) => {
    // Get all questions for the day
    const questions = await ctx.runQuery(
      api.assessmentQueries.getQuestionsByDay,
      { dayNumber: args.dayNumber }
    );

    let answeredCount = 0;
    let totalTimeSpent = 0;

    // Check which questions have been answered
    for (const question of questions) {
      const response = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", question.question_id)
        )
        .first();

      if (response) {
        answeredCount++;
        totalTimeSpent += response.answered_in_seconds || 0;
      }
    }

    const totalQuestions = questions.length;
    const completionPercentage =
      totalQuestions > 0 ? Math.round((answeredCount / totalQuestions) * 100) : 0;

    return {
      total_questions: totalQuestions,
      answered_questions: answeredCount,
      completion_percentage: completionPercentage,
      time_spent_seconds: totalTimeSpent
    };
  },
});

// Import api for internal queries
import { api } from "./_generated/api";


