/**
 * File Storage Functions for Profile Pictures
 *
 * Handles file upload URL generation and profile picture storage
 * for both patients (users) and physicians.
 *
 * Uses Convex's built-in file storage system.
 */

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

// ============================================
// Upload URL Generation
// ============================================

/**
 * Generate a short-lived upload URL for file storage.
 * Client uploads directly to this URL, then calls saveProfilePicture with the storage ID.
 */
export const generateUploadUrl = mutation({
  args: {},
  handler: async (ctx) => {
    return await ctx.storage.generateUploadUrl();
  },
});

// ============================================
// Patient Profile Pictures
// ============================================

/**
 * Save a profile picture for a patient (user).
 * Called after the client uploads the file to the storage URL.
 */
export const saveUserProfilePicture = mutation({
  args: {
    userId: v.id("users"),
    storageId: v.id("_storage"),
  },
  handler: async (ctx, args) => {
    // Verify user exists
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get the public URL for the stored file
    const url = await ctx.storage.getUrl(args.storageId);
    if (!url) {
      throw new Error("Failed to get storage URL for uploaded file");
    }

    // Update user's profile picture
    await ctx.db.patch(args.userId, {
      profile_picture: url,
    });

    return {
      success: true,
      url,
      storageId: args.storageId,
    };
  },
});

/**
 * Delete a patient's profile picture.
 */
export const deleteUserProfilePicture = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Clear the profile picture field
    await ctx.db.patch(args.userId, {
      profile_picture: undefined,
    });

    return { success: true };
  },
});

// ============================================
// Physician Profile Pictures
// ============================================

/**
 * Save a profile picture (avatar) for a physician.
 * Called after the client uploads the file to the storage URL.
 */
export const savePhysicianProfilePicture = mutation({
  args: {
    physicianId: v.id("physicians"),
    storageId: v.id("_storage"),
  },
  handler: async (ctx, args) => {
    // Verify physician exists
    const physician = await ctx.db.get(args.physicianId);
    if (!physician) {
      throw new Error("Physician not found");
    }

    // Get the public URL for the stored file
    const url = await ctx.storage.getUrl(args.storageId);
    if (!url) {
      throw new Error("Failed to get storage URL for uploaded file");
    }

    // Update physician's avatar URL
    await ctx.db.patch(args.physicianId, {
      avatar_url: url,
    });

    return {
      success: true,
      url,
      storageId: args.storageId,
    };
  },
});

/**
 * Delete a physician's profile picture.
 */
export const deletePhysicianProfilePicture = mutation({
  args: {
    physicianId: v.id("physicians"),
  },
  handler: async (ctx, args) => {
    const physician = await ctx.db.get(args.physicianId);
    if (!physician) {
      throw new Error("Physician not found");
    }

    // Clear the avatar URL field
    await ctx.db.patch(args.physicianId, {
      avatar_url: undefined,
    });

    return { success: true };
  },
});

// ============================================
// Utility Queries
// ============================================

/**
 * Get the URL for a stored file by its storage ID.
 */
export const getStorageUrl = query({
  args: {
    storageId: v.optional(v.id("_storage")),
  },
  handler: async (ctx, args) => {
    if (!args.storageId) {
      return null;
    }
    return await ctx.storage.getUrl(args.storageId);
  },
});

/**
 * Get a user's profile picture URL.
 */
export const getUserProfilePicture = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      return null;
    }
    return user.profile_picture ?? null;
  },
});

/**
 * Get a physician's avatar URL.
 */
export const getPhysicianAvatar = query({
  args: {
    physicianId: v.id("physicians"),
  },
  handler: async (ctx, args) => {
    const physician = await ctx.db.get(args.physicianId);
    if (!physician) {
      return null;
    }
    return physician.avatar_url ?? null;
  },
});
