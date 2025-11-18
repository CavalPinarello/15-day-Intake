import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Get user by username
export const getUserByUsername = query({
  args: { username: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();
    return user;
  },
});

// Get user by ID
export const getUserById = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.userId);
  },
});

// Get user by email
export const getUserByEmail = query({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    return user;
  },
});

// Create user
export const createUser = mutation({
  args: {
    username: v.string(),
    password_hash: v.string(),
    email: v.optional(v.string()),
    current_day: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const userId = await ctx.db.insert("users", {
      username: args.username,
      password_hash: args.password_hash,
      email: args.email,
      current_day: args.current_day ?? 1,
      started_at: now,
      last_accessed: now,
      created_at: now,
    });
    return userId;
  },
});

// Update user
export const updateUser = mutation({
  args: {
    userId: v.id("users"),
    updates: v.object({
      current_day: v.optional(v.number()),
      last_accessed: v.optional(v.number()),
      email: v.optional(v.string()),
      onboarding_completed: v.optional(v.boolean()),
      onboarding_completed_at: v.optional(v.number()),
    }),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, args.updates);
  },
});

// Get all users (for admin)
export const getAllUsers = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db.query("users").collect();
  },
});

// Delete all users (for testing/admin)
export const deleteAllUsers = mutation({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    let deleted = 0;
    for (const user of users) {
      await ctx.db.delete(user._id);
      deleted++;
    }
    return { deleted, message: `Successfully deleted ${deleted} users` };
  },
});

// Set user role
export const setUserRole = mutation({
  args: {
    userId: v.id("users"),
    role: v.union(v.literal("patient"), v.literal("physician"), v.literal("admin")),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, { role: args.role });
    return null;
  },
});

// Set role by username
export const setRoleByUsername = mutation({
  args: {
    username: v.string(),
    role: v.union(v.literal("patient"), v.literal("physician"), v.literal("admin")),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();
    
    if (!user) {
      throw new Error(`User ${args.username} not found`);
    }
    
    await ctx.db.patch(user._id, { role: args.role });
    return null;
  },
});

// Migrate all users without roles to "patient" role
export const migrateUserRoles = mutation({
  args: {},
  returns: v.object({
    updated: v.number(),
    message: v.string(),
  }),
  handler: async (ctx, args) => {
    const users = await ctx.db.query("users").collect();
    let updated = 0;
    
    for (const user of users) {
      if (!user.role) {
        await ctx.db.patch(user._id, { role: "patient" as const });
        updated++;
      }
    }
    
    return {
      updated,
      message: `Migrated ${updated} users to 'patient' role`,
    };
  },
});

// Get users by role
export const getUsersByRole = query({
  args: {
    role: v.union(v.literal("patient"), v.literal("physician"), v.literal("admin")),
  },
  returns: v.array(v.any()),
  handler: async (ctx, args) => {
    const users = await ctx.db
      .query("users")
      .withIndex("by_role", (q) => q.eq("role", args.role))
      .collect();
    
    // Remove password hashes from response
    return users.map(({ password_hash, ...user }) => user);
  },
});

