import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// Physician Master Password Authentication
// ============================================

/**
 * Check if a master password has been set
 */
export const hasMasterPassword = query({
  args: {},
  returns: v.boolean(),
  handler: async (ctx) => {
    const password = await ctx.db.query("physician_master_password").first();
    return !!password;
  },
});

/**
 * Set the master password (only if none exists)
 * This is the initial setup - first person to set it becomes the admin
 */
export const setMasterPassword = mutation({
  args: {
    passwordHash: v.string(), // SHA256 hash of the password
  },
  returns: v.object({
    success: v.boolean(),
    error: v.optional(v.string()),
  }),
  handler: async (ctx, args) => {
    // Check if a password already exists
    const existing = await ctx.db.query("physician_master_password").first();
    if (existing) {
      return { success: false, error: "Master password already set" };
    }

    const now = Date.now();
    await ctx.db.insert("physician_master_password", {
      password_hash: args.passwordHash,
      created_at: now,
      updated_at: now,
      created_by: "initial_setup",
    });

    return { success: true };
  },
});

/**
 * Verify the master password and create a session
 */
export const verifyMasterPassword = mutation({
  args: {
    passwordHash: v.string(), // SHA256 hash of the entered password
    userAgent: v.optional(v.string()),
  },
  returns: v.object({
    success: v.boolean(),
    sessionToken: v.optional(v.string()),
    error: v.optional(v.string()),
  }),
  handler: async (ctx, args) => {
    // Get the stored password
    const stored = await ctx.db.query("physician_master_password").first();
    if (!stored) {
      return { success: false, error: "No master password set" };
    }

    // Verify the password hash matches
    if (stored.password_hash !== args.passwordHash) {
      return { success: false, error: "Invalid password" };
    }

    // Create a new session
    const sessionToken = generateSessionToken();
    const now = Date.now();
    const expiresAt = now + 24 * 60 * 60 * 1000; // 24 hours

    await ctx.db.insert("physician_sessions", {
      session_token: sessionToken,
      session_type: "master_password",
      created_at: now,
      expires_at: expiresAt,
      is_active: true,
      last_activity_at: now,
      user_agent: args.userAgent,
    });

    return { success: true, sessionToken };
  },
});

/**
 * Validate a physician session token
 */
export const validatePhysicianSession = query({
  args: {
    sessionToken: v.string(),
  },
  returns: v.object({
    valid: v.boolean(),
    error: v.optional(v.string()),
  }),
  handler: async (ctx, args) => {
    if (!args.sessionToken) {
      return { valid: false, error: "No session token provided" };
    }

    const session = await ctx.db
      .query("physician_sessions")
      .withIndex("by_session_token", (q) => q.eq("session_token", args.sessionToken))
      .first();

    if (!session) {
      return { valid: false, error: "Session not found" };
    }

    if (!session.is_active) {
      return { valid: false, error: "Session inactive" };
    }

    if (session.expires_at < Date.now()) {
      return { valid: false, error: "Session expired" };
    }

    return { valid: true };
  },
});

/**
 * Get current physician's profile data from session token.
 * Returns physician details for profile management.
 */
export const getCurrentPhysician = query({
  args: {
    sessionToken: v.string(),
  },
  returns: v.union(
    v.object({
      id: v.id("physicians"),
      email: v.string(),
      fullName: v.string(),
      avatarUrl: v.optional(v.string()),
      permissionLevel: v.string(),
      title: v.optional(v.string()),
      specialization: v.optional(v.string()),
      sessionType: v.string(),
    }),
    v.null()
  ),
  handler: async (ctx, args) => {
    if (!args.sessionToken) {
      return null;
    }

    const session = await ctx.db
      .query("physician_sessions")
      .withIndex("by_session_token", (q) => q.eq("session_token", args.sessionToken))
      .first();

    if (!session || !session.is_active || session.expires_at < Date.now()) {
      return null;
    }

    // If it's a Clerk-based session, get the physician record
    if (session.session_type === "clerk_physician" && session.physician_id) {
      const physician = await ctx.db.get(session.physician_id);
      if (physician) {
        return {
          id: physician._id,
          email: physician.email,
          fullName: physician.full_name,
          avatarUrl: physician.avatar_url ?? undefined,
          permissionLevel: physician.permission_level,
          title: physician.title ?? undefined,
          specialization: physician.specialization ?? undefined,
          sessionType: "clerk",
        };
      }
    }

    // Master password session - return generic data
    return null;
  },
});

/**
 * Logout - invalidate a session
 */
export const logout = mutation({
  args: {
    sessionToken: v.string(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const session = await ctx.db
      .query("physician_sessions")
      .withIndex("by_session_token", (q) => q.eq("session_token", args.sessionToken))
      .first();

    if (session) {
      await ctx.db.patch(session._id, { is_active: false });
    }

    return null;
  },
});

/**
 * Change the master password (requires current password)
 */
export const changeMasterPassword = mutation({
  args: {
    currentPasswordHash: v.string(),
    newPasswordHash: v.string(),
  },
  returns: v.object({
    success: v.boolean(),
    error: v.optional(v.string()),
  }),
  handler: async (ctx, args) => {
    const stored = await ctx.db.query("physician_master_password").first();
    if (!stored) {
      return { success: false, error: "No master password set" };
    }

    // Verify current password
    if (stored.password_hash !== args.currentPasswordHash) {
      return { success: false, error: "Current password is incorrect" };
    }

    // Update to new password
    await ctx.db.patch(stored._id, {
      password_hash: args.newPasswordHash,
      updated_at: Date.now(),
    });

    // Invalidate all existing sessions
    const activeSessions = await ctx.db
      .query("physician_sessions")
      .withIndex("by_active", (q) => q.eq("is_active", true))
      .collect();

    for (const session of activeSessions) {
      await ctx.db.patch(session._id, { is_active: false });
    }

    return { success: true };
  },
});

/**
 * Clean up expired sessions (can be called periodically)
 */
export const cleanupExpiredSessions = mutation({
  args: {},
  returns: v.number(),
  handler: async (ctx) => {
    const now = Date.now();
    const activeSessions = await ctx.db
      .query("physician_sessions")
      .withIndex("by_active", (q) => q.eq("is_active", true))
      .collect();

    let cleaned = 0;
    for (const session of activeSessions) {
      if (session.expires_at < now) {
        await ctx.db.patch(session._id, { is_active: false });
        cleaned++;
      }
    }

    return cleaned;
  },
});

/**
 * Reset master password (DANGER - for development only)
 * This deletes the existing password so a new one can be set
 */
export const resetMasterPassword = mutation({
  args: {},
  returns: v.object({
    success: v.boolean(),
    message: v.string(),
  }),
  handler: async (ctx) => {
    // Delete existing master password
    const existing = await ctx.db.query("physician_master_password").first();
    if (existing) {
      await ctx.db.delete(existing._id);
    }

    // Invalidate all sessions
    const sessions = await ctx.db.query("physician_sessions").collect();
    for (const session of sessions) {
      await ctx.db.delete(session._id);
    }

    return {
      success: true,
      message: "Master password reset. Visit /physician-login to set a new one."
    };
  },
});

// ============================================
// Clerk Physician Session Management
// ============================================

/**
 * Create a Clerk-based physician session
 * Called after a physician accepts an invitation and completes Clerk OAuth
 */
export const createClerkPhysicianSession = mutation({
  args: {
    clerkUserId: v.string(),
    clerkSessionId: v.string(),
    ipAddress: v.optional(v.string()),
    userAgent: v.optional(v.string()),
  },
  returns: v.object({
    sessionToken: v.string(),
    physician: v.any(), // Full physician object
    permissionLevel: v.string(),
  }),
  handler: async (ctx, args) => {
    // Find physician by Clerk ID
    const physician = await ctx.db
      .query("physicians")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_user_id", args.clerkUserId))
      .first();

    if (!physician) {
      throw new Error("Physician account not found. Please accept your invitation first.");
    }

    if (physician.status !== "active") {
      throw new Error(`Physician account is ${physician.status}. Please contact an administrator.`);
    }

    // Create session
    const sessionToken = generateSessionToken();
    const now = Date.now();
    const expiresAt = now + (24 * 60 * 60 * 1000); // 24 hours

    await ctx.db.insert("physician_sessions", {
      session_token: sessionToken,
      session_type: "clerk_physician",
      physician_id: physician._id,
      clerk_session_id: args.clerkSessionId,
      created_at: now,
      expires_at: expiresAt,
      is_active: true,
      last_activity_at: now,
      ip_address: args.ipAddress,
      user_agent: args.userAgent,
    });

    // Update last login
    await ctx.db.patch(physician._id, {
      last_login_at: now,
      updated_at: now,
    });

    return {
      sessionToken,
      physician,
      permissionLevel: physician.permission_level,
    };
  },
});

// Helper function to generate a random session token
function generateSessionToken(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let result = "";
  for (let i = 0; i < 64; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
