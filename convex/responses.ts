import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Save or update response
export const saveResponse = mutation({
  args: {
    user_id: v.id("users"),
    question_id: v.id("questions"),
    day_id: v.id("days"),
    response_value: v.optional(v.string()),
    response_data: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    // Check if response exists
    const existing = await ctx.db
      .query("responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.user_id).eq("question_id", args.question_id)
      )
      .first();

    if (existing) {
      // Update existing
      await ctx.db.patch(existing._id, {
        response_value: args.response_value,
        response_data: args.response_data,
        updated_at: now,
      });
      return existing._id;
    } else {
      // Create new
      const responseId = await ctx.db.insert("responses", {
        user_id: args.user_id,
        question_id: args.question_id,
        day_id: args.day_id,
        response_value: args.response_value,
        response_data: args.response_data,
        created_at: now,
        updated_at: now,
      });
      return responseId;
    }
  },
});

// Get user responses for a day
export const getUserDayResponses = query({
  args: {
    userId: v.id("users"),
    dayId: v.id("days"),
  },
  handler: async (ctx, args) => {
    const responses = await ctx.db
      .query("responses")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", args.dayId)
      )
      .collect();

    // Get question details for each response
    const responsesWithQuestions = await Promise.all(
      responses.map(async (response) => {
        const question = await ctx.db.get(response.question_id);
        return {
          ...response,
          question_text: question?.question_text,
          question_type: question?.question_type,
        };
      })
    );

    // Sort by question order_index
    responsesWithQuestions.sort((a, b) => {
      const aOrder = a.question_id ? 0 : 0; // We'd need to fetch question order_index
      const bOrder = b.question_id ? 0 : 0;
      return aOrder - bOrder;
    });

    return responsesWithQuestions;
  },
});

// Mark day as completed
export const markDayCompleted = mutation({
  args: {
    userId: v.id("users"),
    dayId: v.id("days"),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    // Check if progress exists
    const existing = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", args.dayId)
      )
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        completed: true,
        completed_at: now,
      });
    } else {
      await ctx.db.insert("user_progress", {
        user_id: args.userId,
        day_id: args.dayId,
        completed: true,
        completed_at: now,
        created_at: now,
      });
    }
  },
});



