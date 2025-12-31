/**
 * Seed questions into the database
 * Run each seeder individually:
 *   npx convex run seedQuestions:seedAssessmentQuestions
 *   npx convex run seedQuestions:seedSleepDiaryQuestions
 */

import { internalMutation, mutation } from "./_generated/server";
import { v } from "convex/values";

// Import converted questions with explicit type casting to avoid deep type instantiation
import assessmentQuestionsDataRaw from "../data/converted/assessment_questions_converted.json";
import sleepDiaryQuestionsDataRaw from "../data/converted/sleep_diary_questions_converted.json";

// Type assertions to prevent TypeScript deep instantiation errors
const assessmentQuestionsData = assessmentQuestionsDataRaw as unknown as Array<{
  question_id: string;
  question_text: string;
  help_text?: string;
  help_text_imperial?: string;
  pillar: string;
  tier: string;
  answer_format: string;
  format_config: Record<string, unknown>;
  validation_rules: Record<string, unknown>;
  estimated_time_seconds: number;
  trigger?: string;
  conditional_logic?: Record<string, unknown>;
}>;

const sleepDiaryQuestionsData = sleepDiaryQuestionsDataRaw as unknown as Array<{
  id: string;
  question_text: string;
  help_text?: string;
  group_key?: string;
  pillar?: string;
  answer_format: string;
  format_config: Record<string, unknown>;
  validation_rules?: Record<string, unknown>;
  conditional_logic?: Record<string, unknown>;
  order_index?: number;
  estimated_time_seconds: number;
}>;

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
            help_text_imperial: q.help_text_imperial,
            pillar: q.pillar,
            tier: q.tier,
            answer_format: q.answer_format,
            format_config: JSON.stringify(q.format_config),
            validation_rules: JSON.stringify(q.validation_rules),
            estimated_time_seconds: q.estimated_time_seconds,
            trigger: q.trigger,
            conditional_logic: q.conditional_logic
              ? JSON.stringify(q.conditional_logic)
              : undefined,
            updated_at: Date.now()
          });
        } else {
          // Insert new
          await ctx.db.insert("assessment_questions", {
            question_id: q.question_id,
            question_text: q.question_text,
            help_text: q.help_text,
            help_text_imperial: q.help_text_imperial,
            pillar: q.pillar,
            tier: q.tier,
            answer_format: q.answer_format,
            format_config: JSON.stringify(q.format_config),
            validation_rules: JSON.stringify(q.validation_rules),
            estimated_time_seconds: q.estimated_time_seconds,
            trigger: q.trigger,
            conditional_logic: q.conditional_logic
              ? JSON.stringify(q.conditional_logic)
              : undefined,
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

// To seed all questions, run the two seeders above individually

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

/**
 * Remove the SD_DATE question from sleep diary
 * This question is redundant on digital devices - we can auto-detect the date.
 * Run with: npx convex run seedQuestions:removeDateQuestion
 */
export const removeDateQuestion = mutation({
  args: {},
  returns: v.object({
    deleted: v.boolean(),
    message: v.string()
  }),
  handler: async (ctx) => {
    // Find and delete the SD_DATE question
    const dateQuestion = await ctx.db
      .query("sleep_diary_questions")
      .withIndex("by_question_id", (query) => query.eq("id", "SD_DATE"))
      .first();

    if (dateQuestion) {
      await ctx.db.delete(dateQuestion._id);
      return { deleted: true, message: "SD_DATE question removed successfully" };
    }

    return { deleted: false, message: "SD_DATE question not found in database" };
  },
});

/**
 * Clear internal help_text from questions 44I and 44J
 * These were accidentally exposed to users with "Only shown for women of reproductive age"
 * Run with: npx convex run seedQuestions:clearInternalHelpText
 */
export const clearInternalHelpText = mutation({
  args: {},
  returns: v.object({
    updated: v.number(),
    message: v.string()
  }),
  handler: async (ctx) => {
    const questionIds = ["44I", "44J"];
    let updated = 0;

    for (const questionId of questionIds) {
      const question = await ctx.db
        .query("assessment_questions")
        .withIndex("by_question_id", (q) => q.eq("question_id", questionId))
        .first();

      if (question && question.help_text) {
        await ctx.db.patch(question._id, { help_text: undefined });
        updated++;
        console.log(`[Migration] Cleared help_text from question ${questionId}`);
      }
    }

    return {
      updated,
      message: updated > 0
        ? `Cleared internal help_text from ${updated} questions (44I, 44J)`
        : "No questions needed updating"
    };
  },
});

// Re-export internal API
import { internal } from "./_generated/api";


