import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { requirePermission, auditAdminAction } from "./auth";
import { Id } from "./_generated/dataModel";

// ============================================
// Physician Collaborators Management
// ============================================

/**
 * Generate cryptographically secure random invitation token
 */
function generateInvitationToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let token = '';
  for (let i = 0; i < 64; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}

// ============================================
// Invitation Mutations
// ============================================

/**
 * Invite a physician to join the dashboard
 * Only master password users or admin physicians can invite
 */
export const invitePhysician = mutation({
  args: {
    sessionToken: v.string(),
    email: v.string(),
    permissionLevel: v.union(v.literal("viewer"), v.literal("clinician"), v.literal("admin")),
    personalMessage: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Only master or admin can invite
    const authCheck = await requirePermission(ctx, args.sessionToken, "admin");
    if (!authCheck.authorized) {
      throw new Error(authCheck.error || "Unauthorized: Admin permission required to invite physicians");
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(args.email)) {
      throw new Error("Invalid email address");
    }

    // Check for existing physician with this email
    const existingPhysician = await ctx.db
      .query("physicians")
      .withIndex("by_email", (q) => q.eq("email", args.email.toLowerCase()))
      .first();

    if (existingPhysician) {
      throw new Error("A physician with this email already exists in the system");
    }

    // Check for pending invitation to this email
    const pendingInvitation = await ctx.db
      .query("physician_invitations")
      .withIndex("by_email", (q) => q.eq("email", args.email.toLowerCase()))
      .filter((q) => q.eq(q.field("status"), "pending"))
      .first();

    if (pendingInvitation) {
      throw new Error("An invitation has already been sent to this email. Use 'resend' to send it again.");
    }

    // Create invitation
    const token = generateInvitationToken();
    const now = Date.now();
    const expiresAt = now + (7 * 24 * 60 * 60 * 1000); // 7 days

    const invitationId = await ctx.db.insert("physician_invitations", {
      email: args.email.toLowerCase(),
      invitation_token: token,
      permission_level: args.permissionLevel,
      invited_by_type: authCheck.session!.type === "master" ? "master" : "admin_physician",
      invited_by_physician_id: authCheck.session!.physician_id,
      status: "pending",
      expires_at: expiresAt,
      created_at: now,
      personal_message: args.personalMessage,
      resend_count: 0,
    });

    // Audit log
    await auditAdminAction(
      ctx,
      authCheck.session!,
      "invite_physician",
      {
        email: args.email,
        permission_level: args.permissionLevel,
        invitation_id: invitationId,
      }
    );

    // TODO: Send email via HTTP action
    // For now, return the token for manual testing
    return {
      success: true,
      invitationId,
      token,
      inviteUrl: `/physician-dashboard/accept-invite?token=${token}`,
      expiresAt,
    };
  },
});

/**
 * Accept an invitation after Clerk OAuth
 */
export const acceptInvitation = mutation({
  args: {
    invitationToken: v.string(),
    clerkUserId: v.string(),
    clerkEmail: v.string(),
    fullName: v.string(),
    avatarUrl: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Find invitation
    const invitation = await ctx.db
      .query("physician_invitations")
      .withIndex("by_token", (q) => q.eq("invitation_token", args.invitationToken))
      .first();

    if (!invitation) {
      throw new Error("Invalid invitation token. Please contact your administrator.");
    }

    if (invitation.status !== "pending") {
      throw new Error(`This invitation has already been ${invitation.status}. Please contact your administrator.`);
    }

    if (invitation.expires_at < Date.now()) {
      // Mark as expired
      await ctx.db.patch(invitation._id, { status: "expired" });
      throw new Error("This invitation has expired. Please request a new invitation.");
    }

    // Check if Clerk user already has a physician account
    const existingPhysician = await ctx.db
      .query("physicians")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_user_id", args.clerkUserId))
      .first();

    if (existingPhysician) {
      throw new Error("This account is already registered as a physician.");
    }

    // Create physician record
    const now = Date.now();
    const physicianId = await ctx.db.insert("physicians", {
      clerk_user_id: args.clerkUserId,
      email: args.clerkEmail.toLowerCase(),
      full_name: args.fullName,
      avatar_url: args.avatarUrl,
      permission_level: invitation.permission_level,
      status: "active",
      invited_by: invitation.invited_by_type,
      invited_at: invitation.created_at,
      activated_at: now,
      created_at: now,
      updated_at: now,
    });

    // Mark invitation as accepted
    await ctx.db.patch(invitation._id, {
      status: "accepted",
      accepted_at: now,
      physician_id: physicianId,
    });

    return {
      success: true,
      physicianId,
      permissionLevel: invitation.permission_level,
      email: args.clerkEmail,
    };
  },
});

/**
 * Resend an invitation email
 */
export const resendInvitation = mutation({
  args: {
    sessionToken: v.string(),
    invitationId: v.id("physician_invitations"),
  },
  handler: async (ctx, args) => {
    const authCheck = await requirePermission(ctx, args.sessionToken, "admin");
    if (!authCheck.authorized) {
      throw new Error(authCheck.error || "Unauthorized");
    }

    const invitation = await ctx.db.get(args.invitationId);
    if (!invitation) {
      throw new Error("Invitation not found");
    }

    if (invitation.status !== "pending") {
      throw new Error(`Cannot resend ${invitation.status} invitation`);
    }

    // Extend expiry by 7 days from now
    const now = Date.now();
    const newExpiresAt = now + (7 * 24 * 60 * 60 * 1000);

    await ctx.db.patch(args.invitationId, {
      expires_at: newExpiresAt,
      resend_count: (invitation.resend_count || 0) + 1,
      last_resent_at: now,
    });

    // Audit log
    await auditAdminAction(
      ctx,
      authCheck.session!,
      "resend_invitation",
      { invitation_id: args.invitationId, email: invitation.email }
    );

    // TODO: Send email via HTTP action

    return {
      success: true,
      newExpiresAt,
      inviteUrl: `/physician-dashboard/accept-invite?token=${invitation.invitation_token}`,
    };
  },
});

/**
 * Revoke a pending invitation
 */
export const revokeInvitation = mutation({
  args: {
    sessionToken: v.string(),
    invitationId: v.id("physician_invitations"),
  },
  handler: async (ctx, args) => {
    const authCheck = await requirePermission(ctx, args.sessionToken, "admin");
    if (!authCheck.authorized) {
      throw new Error(authCheck.error || "Unauthorized");
    }

    const invitation = await ctx.db.get(args.invitationId);
    if (!invitation) {
      throw new Error("Invitation not found");
    }

    if (invitation.status !== "pending") {
      throw new Error(`Cannot revoke ${invitation.status} invitation`);
    }

    await ctx.db.patch(args.invitationId, {
      status: "revoked",
      revoked_at: Date.now(),
      revoked_by: authCheck.session!.type === "master" ? "master" : authCheck.session!.physician_id,
    });

    // Audit log
    await auditAdminAction(
      ctx,
      authCheck.session!,
      "revoke_invitation",
      { invitation_id: args.invitationId, email: invitation.email }
    );

    return { success: true };
  },
});

// ============================================
// Physician Management Queries
// ============================================

/**
 * Get all physicians (master or admin only)
 */
export const getAllPhysicians = query({
  args: { sessionToken: v.string() },
  handler: async (ctx, args) => {
    const authCheck = await requirePermission(ctx, args.sessionToken, "admin");
    if (!authCheck.authorized) {
      throw new Error(authCheck.error || "Unauthorized");
    }

    const physicians = await ctx.db.query("physicians").collect();

    // Get patient assignment counts for each physician
    const physiciansWithCounts = await Promise.all(
      physicians.map(async (physician) => {
        const activeAssignments = await ctx.db
          .query("physician_patient_assignments")
          .withIndex("by_physician_status", (q) =>
            q.eq("physician_id", physician._id).eq("status", "active")
          )
          .collect();

        return {
          ...physician,
          patientCount: activeAssignments.length,
        };
      })
    );

    return physiciansWithCounts;
  },
});

/**
 * Get pending invitations (master or admin only)
 */
export const getPendingInvitations = query({
  args: { sessionToken: v.string() },
  handler: async (ctx, args) => {
    const authCheck = await requirePermission(ctx, args.sessionToken, "admin");
    if (!authCheck.authorized) {
      throw new Error(authCheck.error || "Unauthorized");
    }

    const invitations = await ctx.db
      .query("physician_invitations")
      .withIndex("by_status", (q) => q.eq("status", "pending"))
      .collect();

    // Filter out expired invitations (don't patch in query - let mutations handle that)
    const now = Date.now();
    return invitations.filter((inv) => inv.expires_at >= now);
  },
});

/**
 * Get physician by ID (for current physician or admin)
 */
export const getPhysicianById = query({
  args: {
    sessionToken: v.string(),
    physicianId: v.id("physicians"),
  },
  handler: async (ctx, args) => {
    const authCheck = await requirePermission(ctx, args.sessionToken, "view");
    if (!authCheck.authorized) {
      throw new Error(authCheck.error || "Unauthorized");
    }

    const physician = await ctx.db.get(args.physicianId);
    if (!physician) {
      throw new Error("Physician not found");
    }

    // Get patient count
    const activeAssignments = await ctx.db
      .query("physician_patient_assignments")
      .withIndex("by_physician_status", (q) =>
        q.eq("physician_id", physician._id).eq("status", "active")
      )
      .collect();

    return {
      ...physician,
      patientCount: activeAssignments.length,
    };
  },
});

// ============================================
// Physician Management Mutations
// ============================================

/**
 * Update physician permissions (master only)
 */
export const updatePhysicianPermissions = mutation({
  args: {
    sessionToken: v.string(),
    physicianId: v.id("physicians"),
    permissionLevel: v.union(v.literal("viewer"), v.literal("clinician"), v.literal("admin")),
  },
  handler: async (ctx, args) => {
    // Only master password can change permissions
    const authCheck = await requirePermission(ctx, args.sessionToken, "admin");
    if (!authCheck.authorized || authCheck.session!.type !== "master") {
      throw new Error("Only master password user can change physician permissions");
    }

    const physician = await ctx.db.get(args.physicianId);
    if (!physician) {
      throw new Error("Physician not found");
    }

    await ctx.db.patch(args.physicianId, {
      permission_level: args.permissionLevel,
      updated_at: Date.now(),
    });

    // Audit log
    await auditAdminAction(
      ctx,
      authCheck.session!,
      "update_physician_permissions",
      {
        physician_id: args.physicianId,
        old_permission: physician.permission_level,
        new_permission: args.permissionLevel,
      }
    );

    return { success: true };
  },
});

/**
 * Deactivate physician (master only)
 */
export const deactivatePhysician = mutation({
  args: {
    sessionToken: v.string(),
    physicianId: v.id("physicians"),
  },
  handler: async (ctx, args) => {
    const authCheck = await requirePermission(ctx, args.sessionToken, "admin");
    if (!authCheck.authorized || authCheck.session!.type !== "master") {
      throw new Error("Only master password user can deactivate physicians");
    }

    const physician = await ctx.db.get(args.physicianId);
    if (!physician) {
      throw new Error("Physician not found");
    }

    await ctx.db.patch(args.physicianId, {
      status: "deactivated",
      updated_at: Date.now(),
    });

    // Invalidate all active sessions for this physician
    const sessions = await ctx.db
      .query("physician_sessions")
      .withIndex("by_physician", (q) => q.eq("physician_id", args.physicianId))
      .collect();

    for (const session of sessions) {
      if (session.is_active) {
        await ctx.db.patch(session._id, { is_active: false });
      }
    }

    // Audit log
    await auditAdminAction(
      ctx,
      authCheck.session!,
      "deactivate_physician",
      {
        physician_id: args.physicianId,
        physician_email: physician.email,
      }
    );

    return { success: true };
  },
});

/**
 * Reactivate physician (master only)
 */
export const reactivatePhysician = mutation({
  args: {
    sessionToken: v.string(),
    physicianId: v.id("physicians"),
  },
  handler: async (ctx, args) => {
    const authCheck = await requirePermission(ctx, args.sessionToken, "admin");
    if (!authCheck.authorized || authCheck.session!.type !== "master") {
      throw new Error("Only master password user can reactivate physicians");
    }

    const physician = await ctx.db.get(args.physicianId);
    if (!physician) {
      throw new Error("Physician not found");
    }

    await ctx.db.patch(args.physicianId, {
      status: "active",
      updated_at: Date.now(),
    });

    // Audit log
    await auditAdminAction(
      ctx,
      authCheck.session!,
      "reactivate_physician",
      {
        physician_id: args.physicianId,
        physician_email: physician.email,
      }
    );

    return { success: true };
  },
});

// ============================================
// Patient Assignment
// ============================================

/**
 * Assign a patient to a physician
 */
export const assignPatientToPhysician = mutation({
  args: {
    sessionToken: v.string(),
    patientId: v.id("users"),
    physicianId: v.id("physicians"),
  },
  handler: async (ctx, args) => {
    const authCheck = await requirePermission(ctx, args.sessionToken, "admin");
    if (!authCheck.authorized) {
      throw new Error(authCheck.error || "Unauthorized");
    }

    // Verify physician exists and is active
    const physician = await ctx.db.get(args.physicianId);
    if (!physician || physician.status !== "active") {
      throw new Error("Physician not found or inactive");
    }

    // Verify patient exists
    const patient = await ctx.db.get(args.patientId);
    if (!patient) {
      throw new Error("Patient not found");
    }

    // Check if there's an existing active assignment
    const existingAssignment = await ctx.db
      .query("physician_patient_assignments")
      .withIndex("by_patient_status", (q) =>
        q.eq("patient_id", args.patientId).eq("status", "active")
      )
      .first();

    if (existingAssignment) {
      if (existingAssignment.physician_id === args.physicianId) {
        return { success: true, message: "Patient already assigned to this physician" };
      }

      // Transfer assignment to new physician
      await ctx.db.patch(existingAssignment._id, {
        status: "transferred",
        ended_at: Date.now(),
      });
    }

    // Create new assignment
    await ctx.db.insert("physician_patient_assignments", {
      patient_id: args.patientId,
      physician_id: args.physicianId,
      assigned_at: Date.now(),
      assigned_by_type: authCheck.session!.type === "master" ? "master" : "admin_physician",
      assigned_by_physician_id: authCheck.session!.physician_id,
      status: "active",
    });

    // Audit log
    await auditAdminAction(
      ctx,
      authCheck.session!,
      "assign_patient",
      {
        patient_id: args.patientId,
        physician_id: args.physicianId,
        transferred_from: existingAssignment?.physician_id,
      }
    );

    return { success: true, message: "Patient assigned successfully" };
  },
});

/**
 * Get patients assigned to a specific physician
 */
export const getPhysicianPatients = query({
  args: {
    sessionToken: v.string(),
    physicianId: v.id("physicians"),
  },
  handler: async (ctx, args) => {
    const authCheck = await requirePermission(ctx, args.sessionToken, "view");
    if (!authCheck.authorized) {
      throw new Error(authCheck.error || "Unauthorized");
    }

    const assignments = await ctx.db
      .query("physician_patient_assignments")
      .withIndex("by_physician_status", (q) =>
        q.eq("physician_id", args.physicianId).eq("status", "active")
      )
      .collect();

    // Fetch patient details
    const patients = await Promise.all(
      assignments.map(async (assignment) => {
        const patient = await ctx.db.get(assignment.patient_id);
        return {
          ...patient,
          assigned_at: assignment.assigned_at,
        };
      })
    );

    return patients.filter((p) => p !== null);
  },
});
