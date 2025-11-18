import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Get user for login (password comparison done server-side)
export const getUserForLogin = query({
  args: { username: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();
    return user;
  },
});

// Update user last_accessed after successful login
export const updateUserLastAccessed = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, {
      last_accessed: Date.now(),
    });
  },
});

// Register new user
export const registerUser = mutation({
  args: {
    username: v.string(),
    password_hash: v.string(),
    email: v.string(),
    email_verification_token: v.optional(v.string()),
    email_verification_expires: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // Check if username already exists
    const existingUser = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();

    if (existingUser) {
      throw new Error("Username already exists");
    }

    // Check if email already exists (if provided)
    if (args.email) {
      const existingEmail = await ctx.db
        .query("users")
        .withIndex("by_email", (q) => q.eq("email", args.email))
        .first();

      if (existingEmail) {
        throw new Error("Email already exists");
      }
    }

    // Create new user
    const now = Date.now();
    const userId = await ctx.db.insert("users", {
      username: args.username,
      password_hash: args.password_hash,
      email: args.email,
      current_day: 1,
      started_at: now,
      last_accessed: now,
      created_at: now,
      email_verified: false,
      email_verification_token: args.email_verification_token,
      email_verification_expires: args.email_verification_expires,
    });

    return userId;
  },
});

// Get user by username or email (for login flexibility)
export const getUserByUsernameOrEmail = query({
  args: { identifier: v.string() },
  handler: async (ctx, args) => {
    // Try username first
    const byUsername = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.identifier))
      .first();

    if (byUsername) {
      return byUsername;
    }

    // Try email
    const byEmail = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.identifier))
      .first();

    return byEmail || null;
  },
});

// Store refresh token
export const storeRefreshToken = mutation({
  args: {
    user_id: v.id("users"),
    token: v.string(),
    expires_at: v.number(),
  },
  handler: async (ctx, args) => {
    const tokenId = await ctx.db.insert("refresh_tokens", {
      user_id: args.user_id,
      token: args.token,
      expires_at: args.expires_at,
      created_at: Date.now(),
      revoked: false,
    });
    return tokenId;
  },
});

// Get refresh token
export const getRefreshToken = query({
  args: { token: v.string() },
  handler: async (ctx, args) => {
    const tokenData = await ctx.db
      .query("refresh_tokens")
      .withIndex("by_token", (q) => q.eq("token", args.token))
      .first();

    if (!tokenData) return null;

    // Check if expired or revoked
    const now = Date.now();
    if (tokenData.revoked || tokenData.expires_at < now) {
      return null;
    }

    // Get user data
    const user = await ctx.db.get(tokenData.user_id);
    return {
      ...tokenData,
      user,
    };
  },
});

// Revoke refresh token
export const revokeRefreshToken = mutation({
  args: {
    token: v.string(),
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const tokenData = await ctx.db
      .query("refresh_tokens")
      .withIndex("by_token", (q) => q.eq("token", args.token))
      .first();

    if (tokenData && tokenData.user_id === args.userId) {
      await ctx.db.patch(tokenData._id, { revoked: true });
    }
  },
});

// Get user by verification token
export const getUserByVerificationToken = query({
  args: { token: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_verification_token", (q) => q.eq("email_verification_token", args.token))
      .first();
    return user;
  },
});

// Verify user email
export const verifyUserEmail = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, {
      email_verified: true,
      email_verification_token: undefined,
      email_verification_expires: undefined,
    });
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

// Set password reset token
export const setPasswordResetToken = mutation({
  args: {
    userId: v.id("users"),
    resetToken: v.string(),
    resetExpires: v.number(),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, {
      password_reset_token: args.resetToken,
      password_reset_expires: args.resetExpires,
    });
  },
});

// Get user by password reset token
export const getUserByPasswordResetToken = query({
  args: { token: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_reset_token", (q) => q.eq("password_reset_token", args.token))
      .first();
    return user;
  },
});

// Update user password
export const updateUserPassword = mutation({
  args: {
    userId: v.id("users"),
    password_hash: v.string(),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, {
      password_hash: args.password_hash,
      password_reset_token: undefined,
      password_reset_expires: undefined,
    });
  },
});

// Clear password reset token
export const clearPasswordResetToken = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, {
      password_reset_token: undefined,
      password_reset_expires: undefined,
    });
  },
});

