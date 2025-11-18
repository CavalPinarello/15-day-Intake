import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Get questions by day ID
export const getQuestionsByDay = query({
  args: { dayId: v.id("days") },
  handler: async (ctx, args) => {
    const questions = await ctx.db
      .query("questions")
      .withIndex("by_day_order", (q) => q.eq("day_id", args.dayId))
      .collect();
    return questions.sort((a, b) => a.order_index - b.order_index);
  },
});

// Get question by ID
export const getQuestionById = query({
  args: { questionId: v.id("questions") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.questionId);
  },
});

// Create question
export const createQuestion = mutation({
  args: {
    day_id: v.id("days"),
    question_text: v.string(),
    question_type: v.string(),
    options: v.optional(v.string()),
    order_index: v.number(),
    required: v.optional(v.boolean()),
    conditional_logic: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const questionId = await ctx.db.insert("questions", {
      day_id: args.day_id,
      question_text: args.question_text,
      question_type: args.question_type,
      options: args.options,
      order_index: args.order_index,
      required: args.required ?? true,
      conditional_logic: args.conditional_logic,
      created_at: Date.now(),
    });
    return questionId;
  },
});

// Update question
export const updateQuestion = mutation({
  args: {
    questionId: v.id("questions"),
    updates: v.object({
      question_text: v.optional(v.string()),
      question_type: v.optional(v.string()),
      options: v.optional(v.string()),
      order_index: v.optional(v.number()),
      required: v.optional(v.boolean()),
      conditional_logic: v.optional(v.string()),
    }),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.questionId, args.updates);
  },
});

// Delete question
export const deleteQuestion = mutation({
  args: { questionId: v.id("questions") },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.questionId);
  },
});

// Reorder questions
export const reorderQuestions = mutation({
  args: {
    dayId: v.id("days"),
    questionIds: v.array(v.id("questions")),
  },
  handler: async (ctx, args) => {
    // Update order_index for each question
    for (let i = 0; i < args.questionIds.length; i++) {
      await ctx.db.patch(args.questionIds[i], { order_index: i });
    }
  },
});



