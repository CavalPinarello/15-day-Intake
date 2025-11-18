import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Get all days
export const getAllDays = query({
  args: {},
  handler: async (ctx) => {
    const days = await ctx.db
      .query("days")
      .withIndex("by_day_number")
      .collect();
    return days.sort((a, b) => a.day_number - b.day_number);
  },
});

// Get day by day number
export const getDayByNumber = query({
  args: { dayNumber: v.number() },
  handler: async (ctx, args) => {
    const day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", args.dayNumber))
      .first();
    return day;
  },
});

// Get day by ID
export const getDayById = query({
  args: { dayId: v.id("days") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.dayId);
  },
});

// Create day
export const createDay = mutation({
  args: {
    day_number: v.number(),
    title: v.string(),
    description: v.optional(v.string()),
    theme_color: v.optional(v.string()),
    background_image: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const dayId = await ctx.db.insert("days", {
      day_number: args.day_number,
      title: args.title,
      description: args.description,
      theme_color: args.theme_color,
      background_image: args.background_image,
      created_at: Date.now(),
    });
    return dayId;
  },
});

// Update day
export const updateDay = mutation({
  args: {
    dayId: v.id("days"),
    updates: v.object({
      title: v.optional(v.string()),
      description: v.optional(v.string()),
      theme_color: v.optional(v.string()),
      background_image: v.optional(v.string()),
    }),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.dayId, args.updates);
  },
});



