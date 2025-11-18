/**
 * Seed questions into the database
 * Run with: npx convex run seedQuestions:seedAll
 */

import { internalMutation } from "./_generated/server";
import { v } from "convex/values";

// Import converted questions
import assessmentQuestionsData from "../data/converted/assessment_questions_converted.json";
import sleepDiaryQuestionsData from "../data/converted/sleep_diary_questions_converted.json";

/**
 * Seed all assessment questions (Sleep 360°)
 */
export const seedAssessmentQuestions = internalMutation({
  args: {},
  returns: v.object({
    inserted: v.number(),
    errors: v.array(v.string())
  }),
  handler: async (ctx) => {
    const errors: string[] = [];
    let inserted = 0;

    for (const q of assessmentQuestionsData) {
      try {
        // Check if question already exists
        const existing = await ctx.db
          .query("assessment_questions")
          .withIndex("by_question_id", (query) =>
            query.eq("question_id", q.question_id)
          )
          .first();

        if (existing) {
          // Update existing
          await ctx.db.patch(existing._id, {
            question_text: q.question_text,
            help_text: q.help_text,
            pillar: q.pillar,
            tier: q.tier,
            answer_format: q.answer_format,
            format_config: JSON.stringify(q.format_config),
            validation_rules: JSON.stringify(q.validation_rules),
            estimated_time_seconds: q.estimated_time_seconds,
            trigger: q.trigger,
            updated_at: Date.now()
          });
        } else {
          // Insert new
          await ctx.db.insert("assessment_questions", {
            question_id: q.question_id,
            question_text: q.question_text,
            help_text: q.help_text,
            pillar: q.pillar,
            tier: q.tier,
            answer_format: q.answer_format,
            format_config: JSON.stringify(q.format_config),
            validation_rules: JSON.stringify(q.validation_rules),
            estimated_time_seconds: q.estimated_time_seconds,
            trigger: q.trigger,
            created_at: Date.now(),
            updated_at: Date.now()
          });
          inserted++;
        }
      } catch (error) {
        errors.push(`Error processing question ${q.question_id}: ${error}`);
      }
    }

    return { inserted, errors };
  },
});

/**
 * Seed all sleep diary questions
 */
export const seedSleepDiaryQuestions = internalMutation({
  args: {},
  returns: v.object({
    inserted: v.number(),
    errors: v.array(v.string())
  }),
  handler: async (ctx) => {
    const errors: string[] = [];
    let inserted = 0;

    for (const q of sleepDiaryQuestionsData) {
      try {
        // Check if question already exists
        const existing = await ctx.db
          .query("sleep_diary_questions")
          .withIndex("by_question_id", (query) => query.eq("id", q.id))
          .first();

        if (existing) {
          // Update existing
          await ctx.db.patch(existing._id, {
            question_text: q.question_text,
            help_text: q.help_text,
            group_key: q.group_key,
            pillar: q.pillar,
            answer_format: q.answer_format,
            format_config: JSON.stringify(q.format_config),
            validation_rules: JSON.stringify(q.validation_rules),
            conditional_logic: q.conditional_logic
              ? JSON.stringify(q.conditional_logic)
              : undefined,
            order_index: q.order_index,
            estimated_time_seconds: q.estimated_time_seconds,
            updated_at: Date.now()
          });
        } else {
          // Insert new
          await ctx.db.insert("sleep_diary_questions", {
            id: q.id,
            question_text: q.question_text,
            help_text: q.help_text,
            group_key: q.group_key,
            pillar: q.pillar,
            answer_format: q.answer_format,
            format_config: JSON.stringify(q.format_config),
            validation_rules: JSON.stringify(q.validation_rules),
            conditional_logic: q.conditional_logic
              ? JSON.stringify(q.conditional_logic)
              : undefined,
            order_index: q.order_index,
            estimated_time_seconds: q.estimated_time_seconds,
            created_at: Date.now(),
            updated_at: Date.now()
          });
          inserted++;
        }
      } catch (error) {
        errors.push(`Error processing question ${q.id}: ${error}`);
      }
    }

    return { inserted, errors };
  },
});

/**
 * Seed all questions (assessment + sleep diary)
 */
export const seedAll = internalMutation({
  args: {},
  returns: v.object({
    assessmentQuestions: v.object({
      inserted: v.number(),
      errors: v.array(v.string())
    }),
    sleepDiaryQuestions: v.object({
      inserted: v.number(),
      errors: v.array(v.string())
    })
  }),
  handler: async (ctx) => {
    const assessmentQuestions = await ctx.runMutation(
      internal.seedQuestions.seedAssessmentQuestions
    );
    const sleepDiaryQuestions = await ctx.runMutation(
      internal.seedQuestions.seedSleepDiaryQuestions
    );

    return {
      assessmentQuestions,
      sleepDiaryQuestions
    };
  },
});

/**
 * Clear all questions (for testing)
 */
export const clearAll = internalMutation({
  args: {},
  returns: v.object({
    deletedAssessment: v.number(),
    deletedSleepDiary: v.number()
  }),
  handler: async (ctx) => {
    // Delete all assessment questions
    const assessmentQuestions = await ctx.db
      .query("assessment_questions")
      .collect();
    for (const q of assessmentQuestions) {
      await ctx.db.delete(q._id);
    }

    // Delete all sleep diary questions
    const sleepDiaryQuestions = await ctx.db
      .query("sleep_diary_questions")
      .collect();
    for (const q of sleepDiaryQuestions) {
      await ctx.db.delete(q._id);
    }

    return {
      deletedAssessment: assessmentQuestions.length,
      deletedSleepDiary: sleepDiaryQuestions.length
    };
  },
});

// Re-export internal API
import { internal } from "./_generated/api";


