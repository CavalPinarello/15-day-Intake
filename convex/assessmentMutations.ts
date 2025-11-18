/**
 * Mutation functions for saving assessment responses
 */

import { mutation } from "./_generated/server";
import { v } from "convex/values";

/**
 * Save a user's response to an assessment question
 */
export const saveResponse = mutation({
  args: {
    userId: v.id("users"),
    questionId: v.string(),
    answerFormat: v.string(),
    value: v.union(v.string(), v.number(), v.null()),
    arrayValue: v.optional(v.array(v.string())),
    objectValue: v.optional(v.string()),
    dayNumber: v.optional(v.number()),
    answeredInSeconds: v.optional(v.number())
  },
  returns: v.id("user_assessment_responses"),
  handler: async (ctx, args) => {
    const startTime = Date.now();

    // Check if response already exists
    const existing = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", args.questionId)
      )
      .first();

    // Prepare response data based on answer format
    let responseData: {
      response_value?: string;
      response_number?: number;
      response_array?: string;
      response_object?: string;
    } = {};

    switch (args.answerFormat) {
      case "time_picker":
      case "single_select_chips":
      case "date_picker":
        responseData.response_value =
          typeof args.value === "string" ? args.value : undefined;
        break;

      case "minutes_scroll":
      case "number_scroll":
      case "slider_scale":
      case "number_input":
        responseData.response_number =
          typeof args.value === "number"
            ? args.value
            : typeof args.value === "string"
            ? parseFloat(args.value)
            : undefined;
        break;

      case "multi_select_chips":
        responseData.response_array = args.arrayValue
          ? JSON.stringify(args.arrayValue)
          : undefined;
        break;

      case "repeating_group":
        responseData.response_object = args.objectValue;
        break;

      default:
        throw new Error(`Unknown answer format: ${args.answerFormat}`);
    }

    if (existing) {
      // Update existing response
      await ctx.db.patch(existing._id, {
        ...responseData,
        answered_in_seconds:
          args.answeredInSeconds ||
          Math.floor((Date.now() - startTime) / 1000),
        updated_at: Date.now()
      });
      return existing._id;
    } else {
      // Insert new response
      return await ctx.db.insert("user_assessment_responses", {
        user_id: args.userId,
        question_id: args.questionId,
        ...responseData,
        day_number: args.dayNumber,
        answered_in_seconds:
          args.answeredInSeconds ||
          Math.floor((Date.now() - startTime) / 1000),
        created_at: Date.now(),
        updated_at: Date.now()
      });
    }
  },
});

/**
 * Bulk save multiple responses (for faster submission)
 */
export const saveMultipleResponses = mutation({
  args: {
    userId: v.id("users"),
    responses: v.array(
      v.object({
        questionId: v.string(),
        answerFormat: v.string(),
        value: v.union(v.string(), v.number(), v.null()),
        arrayValue: v.optional(v.array(v.string())),
        objectValue: v.optional(v.string()),
        answeredInSeconds: v.optional(v.number())
      })
    ),
    dayNumber: v.optional(v.number())
  },
  returns: v.array(v.id("user_assessment_responses")),
  handler: async (ctx, args) => {
    const responseIds: Array<any> = [];

    for (const response of args.responses) {
      const id = await ctx.runMutation(api.assessmentMutations.saveResponse, {
        userId: args.userId,
        questionId: response.questionId,
        answerFormat: response.answerFormat,
        value: response.value,
        arrayValue: response.arrayValue,
        objectValue: response.objectValue,
        dayNumber: args.dayNumber,
        answeredInSeconds: response.answeredInSeconds
      });
      responseIds.push(id);
    }

    return responseIds;
  },
});

/**
 * Mark a day as completed
 */
export const markDayComplete = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number()
  },
  returns: v.id("user_progress"),
  handler: async (ctx, args) => {
    // Get or create the day record
    const day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", args.dayNumber))
      .first();

    if (!day) {
      throw new Error(`Day ${args.dayNumber} not found`);
    }

    // Check if progress record exists
    const existing = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", day._id)
      )
      .first();

    if (existing) {
      // Update existing
      await ctx.db.patch(existing._id, {
        completed: true,
        completed_at: Date.now()
      });
      return existing._id;
    } else {
      // Create new progress record
      return await ctx.db.insert("user_progress", {
        user_id: args.userId,
        day_id: day._id,
        completed: true,
        completed_at: Date.now(),
        created_at: Date.now()
      });
    }
  },
});

/**
 * Delete a user's response (for testing/corrections)
 */
export const deleteResponse = mutation({
  args: {
    userId: v.id("users"),
    questionId: v.string()
  },
  returns: v.union(v.boolean(), v.null()),
  handler: async (ctx, args) => {
    const response = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", args.questionId)
      )
      .first();

    if (response) {
      await ctx.db.delete(response._id);
      return true;
    }

    return null;
  },
});

// Import api for mutations
import { api } from "./_generated/api";


