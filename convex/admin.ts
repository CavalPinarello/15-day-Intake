/**
 * Admin Management Functions
 * Comprehensive admin toolkit for the physician dashboard
 *
 * Functions:
 * - deleteUser: Complete user deletion with all related data
 * - deleteMultipleUsers: Batch deletion
 * - resetUserPassword: Reset a user's password
 * - resetUserProgress: Reset progress without deleting user
 * - purgeTestUsers: Delete all test users (user1-user10)
 * - getAllUsersAdmin: Get all users with full details
 * - exportUserData: Export all user data (GDPR compliance)
 * - updateUserField: Update any user field
 */

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

// ============================================
// Queries
// ============================================

/**
 * Get all users with full details for admin management
 */
export const getAllUsersAdmin = query({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();

    // Enrich with additional data
    const enrichedUsers = await Promise.all(
      users.map(async (user) => {
        // Get progress stats
        const progressRecords = await ctx.db
          .query("user_progress")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .collect();

        const completedDays = progressRecords.filter((p) => p.completed).length;

        // Get response count
        const responses = await ctx.db
          .query("user_assessment_responses")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .collect();

        // Get journey status
        const journeyStatus = await ctx.db
          .query("patient_journey_status")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .first();

        // Get intervention count
        const interventions = await ctx.db
          .query("user_interventions")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .collect();

        return {
          ...user,
          completedDays,
          responseCount: responses.length,
          phase: journeyStatus?.phase || "intake",
          interventionCount: interventions.length,
          isTestUser: /^user\d+$/.test(user.username) || /^test_/.test(user.username),
        };
      })
    );

    return enrichedUsers.sort((a, b) => b.created_at - a.created_at);
  },
});

/**
 * Get user data summary for export preview
 */
export const getUserDataSummary = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    if (!user) return null;

    // Count records in each table
    const tables = [
      { name: "responses", query: ctx.db.query("responses").withIndex("by_user", (q) => q.eq("user_id", userId)) },
      { name: "user_progress", query: ctx.db.query("user_progress").withIndex("by_user", (q) => q.eq("user_id", userId)) },
      { name: "user_assessment_responses", query: ctx.db.query("user_assessment_responses").withIndex("by_user", (q) => q.eq("user_id", userId)) },
      { name: "daily_checkins", query: ctx.db.query("daily_checkins").withIndex("by_user", (q) => q.eq("user_id", userId)) },
      { name: "user_sleep_data", query: ctx.db.query("user_sleep_data").withIndex("by_user", (q) => q.eq("user_id", userId)) },
      { name: "user_interventions", query: ctx.db.query("user_interventions").withIndex("by_user", (q) => q.eq("user_id", userId)) },
      { name: "physician_notes", query: ctx.db.query("physician_notes").withIndex("by_user", (q) => q.eq("user_id", userId)) },
      { name: "questionnaire_scores", query: ctx.db.query("questionnaire_scores").withIndex("by_user", (q) => q.eq("user_id", userId)) },
      { name: "user_gateway_states", query: ctx.db.query("user_gateway_states").withIndex("by_user", (q) => q.eq("user_id", userId)) },
      { name: "sleep_insights", query: ctx.db.query("sleep_insights").withIndex("by_user", (q) => q.eq("user_id", userId)) },
    ];

    const counts: Record<string, number> = {};
    let totalRecords = 0;

    for (const table of tables) {
      const records = await table.query.collect();
      counts[table.name] = records.length;
      totalRecords += records.length;
    }

    return {
      user,
      tableCounts: counts,
      totalRecords,
    };
  },
});

/**
 * Get system stats for admin dashboard
 */
export const getSystemStats = query({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    const testUsers = users.filter((u) => /^user\d+$/.test(u.username));
    const realUsers = users.filter((u) => !/^user\d+$/.test(u.username));

    // Get active patients (with responses in last 7 days)
    const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const recentResponses = await ctx.db
      .query("user_assessment_responses")
      .filter((q) => q.gt(q.field("created_at"), sevenDaysAgo))
      .collect();
    const activeUserIds = new Set(recentResponses.map((r) => r.user_id.toString()));

    // Count by role
    const roleCount = {
      patient: users.filter((u) => u.role === "patient" || !u.role).length,
      physician: users.filter((u) => u.role === "physician").length,
      admin: users.filter((u) => u.role === "admin").length,
    };

    // Get total responses
    const totalResponses = await ctx.db.query("user_assessment_responses").collect();

    // Get journey phase distribution
    const journeyStatuses = await ctx.db.query("patient_journey_status").collect();
    const phaseDistribution = {
      intake: journeyStatuses.filter((j) => j.phase === "intake").length,
      analysis: journeyStatuses.filter((j) => j.phase === "analysis").length,
      treatment_pending: journeyStatuses.filter((j) => j.phase === "treatment_pending").length,
      treatment_active: journeyStatuses.filter((j) => j.phase === "treatment_active").length,
    };

    return {
      totalUsers: users.length,
      testUsers: testUsers.length,
      realUsers: realUsers.length,
      activeUsersLast7Days: activeUserIds.size,
      roleDistribution: roleCount,
      totalResponses: totalResponses.length,
      phaseDistribution,
    };
  },
});

// ============================================
// Mutations
// ============================================

/**
 * Delete a user and ALL related data
 * This is a complete purge - use with caution!
 */
export const deleteUser = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    let deletedRecords = 0;
    const deletedTables: Record<string, number> = {};

    // Helper function to delete all records from a table for this user
    async function deleteFromTable(
      tableName: string,
      query: { collect: () => Promise<Array<{ _id: Id<any> }>> }
    ) {
      const records = await query.collect();
      for (const record of records) {
        await ctx.db.delete(record._id);
      }
      if (records.length > 0) {
        deletedTables[tableName] = records.length;
        deletedRecords += records.length;
      }
    }

    // Delete from all user-related tables
    // Order matters for some tables with foreign keys

    // Assessment & Responses
    await deleteFromTable("user_assessment_responses",
      ctx.db.query("user_assessment_responses").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("responses",
      ctx.db.query("responses").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_progress",
      ctx.db.query("user_progress").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("questionnaire_session",
      ctx.db.query("questionnaire_session").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("onboarding_insights",
      ctx.db.query("onboarding_insights").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Daily check-ins (and related)
    const checkins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    for (const checkin of checkins) {
      // Delete checkin responses first
      const checkinResponses = await ctx.db
        .query("checkin_responses")
        .withIndex("by_checkin", (q) => q.eq("checkin_id", checkin._id))
        .collect();
      for (const resp of checkinResponses) {
        await ctx.db.delete(resp._id);
        deletedRecords++;
      }
      if (checkinResponses.length > 0) {
        deletedTables["checkin_responses"] = (deletedTables["checkin_responses"] || 0) + checkinResponses.length;
      }
      await ctx.db.delete(checkin._id);
    }
    if (checkins.length > 0) {
      deletedTables["daily_checkins"] = checkins.length;
      deletedRecords += checkins.length;
    }

    await deleteFromTable("user_preferences",
      ctx.db.query("user_preferences").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Sleep reports (and related)
    const reports = await ctx.db
      .query("sleep_reports")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    for (const report of reports) {
      // Delete report sections
      const sections = await ctx.db
        .query("report_sections")
        .withIndex("by_report", (q) => q.eq("report_id", report._id))
        .collect();
      for (const section of sections) {
        await ctx.db.delete(section._id);
        deletedRecords++;
      }
      if (sections.length > 0) {
        deletedTables["report_sections"] = (deletedTables["report_sections"] || 0) + sections.length;
      }

      // Delete report roadmap
      const roadmaps = await ctx.db
        .query("report_roadmap")
        .withIndex("by_report", (q) => q.eq("report_id", report._id))
        .collect();
      for (const roadmap of roadmaps) {
        await ctx.db.delete(roadmap._id);
        deletedRecords++;
      }
      if (roadmaps.length > 0) {
        deletedTables["report_roadmap"] = (deletedTables["report_roadmap"] || 0) + roadmaps.length;
      }

      await ctx.db.delete(report._id);
    }
    if (reports.length > 0) {
      deletedTables["sleep_reports"] = reports.length;
      deletedRecords += reports.length;
    }

    // Coach assignments
    await deleteFromTable("customer_coach_assignments",
      ctx.db.query("customer_coach_assignments").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Alerts and messages
    await deleteFromTable("alerts",
      ctx.db.query("alerts").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("messages",
      ctx.db.query("messages").withIndex("by_to_user", (q) => q.eq("to_user_id", userId)));

    // Auth tokens
    await deleteFromTable("refresh_tokens",
      ctx.db.query("refresh_tokens").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Health data
    await deleteFromTable("user_sleep_data",
      ctx.db.query("user_sleep_data").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_sleep_stages",
      ctx.db.query("user_sleep_stages").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_heart_rate",
      ctx.db.query("user_heart_rate").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_activity",
      ctx.db.query("user_activity").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_workouts",
      ctx.db.query("user_workouts").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_baselines",
      ctx.db.query("user_baselines").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Interventions (and related)
    const interventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    for (const intervention of interventions) {
      // Delete compliance records
      const compliance = await ctx.db
        .query("intervention_compliance")
        .withIndex("by_intervention", (q) => q.eq("user_intervention_id", intervention._id))
        .collect();
      for (const c of compliance) {
        await ctx.db.delete(c._id);
        deletedRecords++;
      }
      if (compliance.length > 0) {
        deletedTables["intervention_compliance"] = (deletedTables["intervention_compliance"] || 0) + compliance.length;
      }

      // Delete user notes
      const userNotes = await ctx.db
        .query("intervention_user_notes")
        .withIndex("by_intervention", (q) => q.eq("user_intervention_id", intervention._id))
        .collect();
      for (const n of userNotes) {
        await ctx.db.delete(n._id);
        deletedRecords++;
      }
      if (userNotes.length > 0) {
        deletedTables["intervention_user_notes"] = (deletedTables["intervention_user_notes"] || 0) + userNotes.length;
      }

      // Delete coach notes
      const coachNotes = await ctx.db
        .query("intervention_coach_notes")
        .withIndex("by_intervention", (q) => q.eq("user_intervention_id", intervention._id))
        .collect();
      for (const n of coachNotes) {
        await ctx.db.delete(n._id);
        deletedRecords++;
      }
      if (coachNotes.length > 0) {
        deletedTables["intervention_coach_notes"] = (deletedTables["intervention_coach_notes"] || 0) + coachNotes.length;
      }

      // Delete schedules
      const schedules = await ctx.db
        .query("intervention_schedule")
        .withIndex("by_intervention", (q) => q.eq("user_intervention_id", intervention._id))
        .collect();
      for (const s of schedules) {
        await ctx.db.delete(s._id);
        deletedRecords++;
      }
      if (schedules.length > 0) {
        deletedTables["intervention_schedule"] = (deletedTables["intervention_schedule"] || 0) + schedules.length;
      }

      // Delete difficulty settings
      const difficulty = await ctx.db
        .query("intervention_difficulty_settings")
        .withIndex("by_intervention", (q) => q.eq("user_intervention_id", intervention._id))
        .collect();
      for (const d of difficulty) {
        await ctx.db.delete(d._id);
        deletedRecords++;
      }
      if (difficulty.length > 0) {
        deletedTables["intervention_difficulty_settings"] = (deletedTables["intervention_difficulty_settings"] || 0) + difficulty.length;
      }

      await ctx.db.delete(intervention._id);
    }
    if (interventions.length > 0) {
      deletedTables["user_interventions"] = interventions.length;
      deletedRecords += interventions.length;
    }

    // Daily tasks
    await deleteFromTable("user_daily_tasks",
      ctx.db.query("user_daily_tasks").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Difficulty log
    await deleteFromTable("difficulty_adjustment_log",
      ctx.db.query("difficulty_adjustment_log").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Compliance correlation
    await deleteFromTable("compliance_outcome_correlation",
      ctx.db.query("compliance_outcome_correlation").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Watch offline queue
    await deleteFromTable("watch_offline_queue",
      ctx.db.query("watch_offline_queue").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Metrics
    await deleteFromTable("user_metrics_summary",
      ctx.db.query("user_metrics_summary").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Insights
    await deleteFromTable("sleep_insights",
      ctx.db.query("sleep_insights").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("perception_gaps",
      ctx.db.query("perception_gaps").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Gateway states
    await deleteFromTable("user_gateway_states",
      ctx.db.query("user_gateway_states").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Expansion schedules
    await deleteFromTable("user_expansion_schedules",
      ctx.db.query("user_expansion_schedules").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Physician dashboard data
    await deleteFromTable("physician_notes",
      ctx.db.query("physician_notes").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("patient_review_status",
      ctx.db.query("patient_review_status").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("questionnaire_scores",
      ctx.db.query("questionnaire_scores").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("patient_visible_fields",
      ctx.db.query("patient_visible_fields").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // iOS data
    await deleteFromTable("ios_devices",
      ctx.db.query("ios_devices").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("ios_sessions",
      ctx.db.query("ios_sessions").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("apple_sign_in",
      ctx.db.query("apple_sign_in").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("ios_healthkit_sync",
      ctx.db.query("ios_healthkit_sync").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("ios_notifications",
      ctx.db.query("ios_notifications").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("ios_watch_sync",
      ctx.db.query("ios_watch_sync").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Gamification
    await deleteFromTable("user_streaks",
      ctx.db.query("user_streaks").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_badges",
      ctx.db.query("user_badges").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_xp",
      ctx.db.query("user_xp").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("xp_transactions",
      ctx.db.query("xp_transactions").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_challenges",
      ctx.db.query("user_challenges").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Cohort data
    await deleteFromTable("user_cohort_memberships",
      ctx.db.query("user_cohort_memberships").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_sleep_narrative",
      ctx.db.query("user_sleep_narrative").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_insight_queue",
      ctx.db.query("user_insight_queue").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_encouragement_history",
      ctx.db.query("user_encouragement_history").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Journey status
    await deleteFromTable("patient_journey_status",
      ctx.db.query("patient_journey_status").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("patient_analysis_workflow",
      ctx.db.query("patient_analysis_workflow").withIndex("by_user", (q) => q.eq("user_id", userId)));

    await deleteFromTable("user_insight_progress",
      ctx.db.query("user_insight_progress").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Protocol assignments
    await deleteFromTable("user_protocol_assignments",
      ctx.db.query("user_protocol_assignments").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Finally, delete the user record itself
    await ctx.db.delete(userId);
    deletedRecords++;
    deletedTables["users"] = 1;

    return {
      success: true,
      deletedUser: user.username,
      deletedRecords,
      deletedTables,
    };
  },
});

/**
 * Delete multiple users at once (batch operation)
 */
export const deleteMultipleUsers = mutation({
  args: { userIds: v.array(v.id("users")) },
  handler: async (ctx, { userIds }) => {
    const results = [];
    let totalDeleted = 0;

    for (const userId of userIds) {
      const user = await ctx.db.get(userId);
      if (user) {
        // Re-use the single delete logic
        // Note: In production, you'd want to extract the deletion logic to a shared function
        // For now, we'll call the mutation logic inline (simplified version)

        // Delete key tables (simplified for batch operation)
        const tables = [
          ctx.db.query("user_assessment_responses").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("responses").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("user_progress").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("daily_checkins").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("user_sleep_data").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("user_interventions").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("physician_notes").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("patient_review_status").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("questionnaire_scores").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("user_gateway_states").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("user_expansion_schedules").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("questionnaire_session").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("sleep_insights").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("patient_journey_status").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("user_streaks").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("user_badges").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("user_xp").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("user_daily_tasks").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("ios_devices").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("ios_sessions").withIndex("by_user", (q) => q.eq("user_id", userId)),
          ctx.db.query("refresh_tokens").withIndex("by_user", (q) => q.eq("user_id", userId)),
        ];

        let deleted = 0;
        for (const query of tables) {
          const records = await query.collect();
          for (const record of records) {
            await ctx.db.delete(record._id);
            deleted++;
          }
        }

        await ctx.db.delete(userId);
        deleted++;
        totalDeleted += deleted;

        results.push({
          userId: userId,
          username: user.username,
          deleted,
          success: true,
        });
      } else {
        results.push({
          userId: userId,
          username: null,
          deleted: 0,
          success: false,
          error: "User not found",
        });
      }
    }

    return {
      success: true,
      totalDeleted,
      results,
    };
  },
});

/**
 * Purge all test users (user1-user10 and variations)
 */
export const purgeTestUsers = mutation({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    const testUsers = users.filter((u) => /^user\d+$/.test(u.username));

    const results = [];
    let totalDeleted = 0;

    for (const user of testUsers) {
      // Simplified deletion - just delete the key tables
      const tables = [
        ctx.db.query("user_assessment_responses").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("responses").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_progress").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("daily_checkins").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_sleep_data").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_interventions").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("physician_notes").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("patient_review_status").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("questionnaire_scores").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_gateway_states").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_expansion_schedules").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("questionnaire_session").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("sleep_insights").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("patient_journey_status").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_streaks").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_badges").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_xp").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_daily_tasks").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("ios_devices").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("ios_sessions").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("refresh_tokens").withIndex("by_user", (q) => q.eq("user_id", user._id)),
      ];

      let deleted = 0;
      for (const query of tables) {
        const records = await query.collect();
        for (const record of records) {
          await ctx.db.delete(record._id);
          deleted++;
        }
      }

      await ctx.db.delete(user._id);
      deleted++;
      totalDeleted += deleted;

      results.push({
        username: user.username,
        deleted,
      });
    }

    return {
      success: true,
      purgedCount: testUsers.length,
      totalRecordsDeleted: totalDeleted,
      users: results,
    };
  },
});

/**
 * Purge generated test users (test_* pattern like test_short_sleeper_mild_022)
 */
export const purgeGeneratedTestUsers = mutation({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    // Match usernames starting with "test_" (generated mock users)
    const testUsers = users.filter((u) => /^test_/.test(u.username));

    const results = [];
    let totalDeleted = 0;

    for (const user of testUsers) {
      // Simplified deletion - just delete the key tables
      const tables = [
        ctx.db.query("user_assessment_responses").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("responses").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_progress").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("daily_checkins").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_sleep_data").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_interventions").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("physician_notes").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("patient_review_status").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("questionnaire_scores").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_gateway_states").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_expansion_schedules").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("questionnaire_session").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("sleep_insights").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("patient_journey_status").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_streaks").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_badges").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_xp").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_daily_tasks").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("ios_devices").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("ios_sessions").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("refresh_tokens").withIndex("by_user", (q) => q.eq("user_id", user._id)),
      ];

      let deleted = 0;
      for (const query of tables) {
        const records = await query.collect();
        for (const record of records) {
          await ctx.db.delete(record._id);
          deleted++;
        }
      }

      await ctx.db.delete(user._id);
      deleted++;
      totalDeleted += deleted;

      results.push({
        username: user.username,
        deleted,
      });
    }

    return {
      success: true,
      purgedCount: testUsers.length,
      totalRecordsDeleted: totalDeleted,
      users: results,
    };
  },
});

/**
 * Purge ALL test users (both user1-10 and test_* patterns)
 */
export const purgeAllTestUsers = mutation({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    // Match both patterns: user1-user10 AND test_* (generated mock users)
    const testUsers = users.filter((u) =>
      /^user\d+$/.test(u.username) || /^test_/.test(u.username)
    );

    const results = [];
    let totalDeleted = 0;

    for (const user of testUsers) {
      const tables = [
        ctx.db.query("user_assessment_responses").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("responses").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_progress").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("daily_checkins").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_sleep_data").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_interventions").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("physician_notes").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("patient_review_status").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("questionnaire_scores").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_gateway_states").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_expansion_schedules").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("questionnaire_session").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("sleep_insights").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("patient_journey_status").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_streaks").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_badges").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_xp").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("user_daily_tasks").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("ios_devices").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("ios_sessions").withIndex("by_user", (q) => q.eq("user_id", user._id)),
        ctx.db.query("refresh_tokens").withIndex("by_user", (q) => q.eq("user_id", user._id)),
      ];

      let deleted = 0;
      for (const query of tables) {
        const records = await query.collect();
        for (const record of records) {
          await ctx.db.delete(record._id);
          deleted++;
        }
      }

      await ctx.db.delete(user._id);
      deleted++;
      totalDeleted += deleted;

      results.push({
        username: user.username,
        deleted,
      });
    }

    return {
      success: true,
      purgedCount: testUsers.length,
      totalRecordsDeleted: totalDeleted,
      users: results,
    };
  },
});

/**
 * Reset user password
 */
export const resetUserPassword = mutation({
  args: {
    userId: v.id("users"),
    newPasswordHash: v.string(), // SHA256 hash of new password
  },
  handler: async (ctx, { userId, newPasswordHash }) => {
    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    await ctx.db.patch(userId, {
      password_hash: newPasswordHash,
      password_reset_token: undefined,
      password_reset_expires: undefined,
    });

    // Invalidate all existing sessions for security
    const sessions = await ctx.db
      .query("ios_sessions")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    for (const session of sessions) {
      await ctx.db.patch(session._id, { is_active: false });
    }

    // Revoke refresh tokens
    const tokens = await ctx.db
      .query("refresh_tokens")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    for (const token of tokens) {
      await ctx.db.patch(token._id, { revoked: true });
    }

    return {
      success: true,
      username: user.username,
      sessionsInvalidated: sessions.length,
      tokensRevoked: tokens.length,
    };
  },
});

/**
 * Reset user progress (keep user, delete all data)
 * Now includes option to clear ALL wearable data as well
 */
export const resetUserProgress = mutation({
  args: {
    userId: v.id("users"),
    clearWearableData: v.optional(v.boolean()), // If true, also clears wearable/HealthKit data
  },
  handler: async (ctx, { userId, clearWearableData = false }) => {
    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    let deletedRecords = 0;
    const deletedTables: Record<string, number> = {};

    // Helper to delete and track
    async function deleteFromTable(tableName: string, query: { collect: () => Promise<Array<{ _id: Id<any> }>> }) {
      const records = await query.collect();
      for (const record of records) {
        await ctx.db.delete(record._id);
        deletedRecords++;
      }
      if (records.length > 0) {
        deletedTables[tableName] = records.length;
      }
    }

    // Core assessment and progress data - ALWAYS delete
    await deleteFromTable("user_assessment_responses",
      ctx.db.query("user_assessment_responses").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("responses",
      ctx.db.query("responses").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_progress",
      ctx.db.query("user_progress").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("daily_checkins",
      ctx.db.query("daily_checkins").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("questionnaire_session",
      ctx.db.query("questionnaire_session").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("questionnaire_scores",
      ctx.db.query("questionnaire_scores").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_gateway_states",
      ctx.db.query("user_gateway_states").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_expansion_schedules",
      ctx.db.query("user_expansion_schedules").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Physician dashboard data
    await deleteFromTable("physician_notes",
      ctx.db.query("physician_notes").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("patient_review_status",
      ctx.db.query("patient_review_status").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("patient_journey_status",
      ctx.db.query("patient_journey_status").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("patient_analysis_workflow",
      ctx.db.query("patient_analysis_workflow").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Interventions
    await deleteFromTable("user_interventions",
      ctx.db.query("user_interventions").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_daily_tasks",
      ctx.db.query("user_daily_tasks").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_protocol_assignments",
      ctx.db.query("user_protocol_assignments").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Gamification
    await deleteFromTable("user_streaks",
      ctx.db.query("user_streaks").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_badges",
      ctx.db.query("user_badges").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_xp",
      ctx.db.query("user_xp").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Insights and analytics
    await deleteFromTable("sleep_insights",
      ctx.db.query("sleep_insights").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_insight_queue",
      ctx.db.query("user_insight_queue").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_insight_progress",
      ctx.db.query("user_insight_progress").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_cohort_memberships",
      ctx.db.query("user_cohort_memberships").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_sleep_narrative",
      ctx.db.query("user_sleep_narrative").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Compliance and metrics
    await deleteFromTable("perception_gaps",
      ctx.db.query("perception_gaps").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("difficulty_adjustment_log",
      ctx.db.query("difficulty_adjustment_log").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("compliance_outcome_correlation",
      ctx.db.query("compliance_outcome_correlation").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_metrics_summary",
      ctx.db.query("user_metrics_summary").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // WEARABLE DATA - Only delete if clearWearableData is true
    if (clearWearableData) {
      await deleteFromTable("user_sleep_data",
        ctx.db.query("user_sleep_data").withIndex("by_user", (q) => q.eq("user_id", userId)));
      await deleteFromTable("user_sleep_stages",
        ctx.db.query("user_sleep_stages").withIndex("by_user", (q) => q.eq("user_id", userId)));
      await deleteFromTable("user_heart_rate",
        ctx.db.query("user_heart_rate").withIndex("by_user", (q) => q.eq("user_id", userId)));
      await deleteFromTable("user_activity",
        ctx.db.query("user_activity").withIndex("by_user", (q) => q.eq("user_id", userId)));
      await deleteFromTable("user_workouts",
        ctx.db.query("user_workouts").withIndex("by_user", (q) => q.eq("user_id", userId)));
      await deleteFromTable("user_circadian_data",
        ctx.db.query("user_circadian_data").withIndex("by_user", (q) => q.eq("user_id", userId)));
      await deleteFromTable("user_baselines",
        ctx.db.query("user_baselines").withIndex("by_user", (q) => q.eq("user_id", userId)));
    } else {
      // If not clearing wearable data, only clear questionnaire-derived sleep records
      const sleepData = await ctx.db
        .query("user_sleep_data")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .collect();

      let questionnaireRecordsDeleted = 0;
      for (const record of sleepData) {
        // Only delete questionnaire-sourced data, keep wearable data
        if (record.primary_source === "Questionnaire" || !record.primary_source) {
          await ctx.db.delete(record._id);
          deletedRecords++;
          questionnaireRecordsDeleted++;
        }
      }
      if (questionnaireRecordsDeleted > 0) {
        deletedTables["user_sleep_data (questionnaire only)"] = questionnaireRecordsDeleted;
      }
    }

    // Reset user to day 1
    await ctx.db.patch(userId, {
      current_day: 1,
      onboarding_completed: false,
      onboarding_completed_at: undefined,
      developer_mode: false,
      // Optionally reset apple_health_connected if clearing wearable data
      ...(clearWearableData ? { apple_health_connected: false } : {}),
    });

    return {
      success: true,
      username: user.username,
      deletedRecords,
      deletedTables,
      resetToDay: 1,
      wearableDataCleared: clearWearableData,
    };
  },
});

/**
 * Clear ALL wearable/HealthKit data for a user (but keep questionnaire responses)
 * Use when you need to specifically clear device-synced data
 */
export const clearWearableData = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    let deletedRecords = 0;
    const deletedTables: Record<string, number> = {};

    // Helper to delete and track
    async function deleteFromTable(tableName: string, query: { collect: () => Promise<Array<{ _id: Id<any> }>> }) {
      const records = await query.collect();
      for (const record of records) {
        await ctx.db.delete(record._id);
        deletedRecords++;
      }
      if (records.length > 0) {
        deletedTables[tableName] = records.length;
      }
    }

    // Clear all wearable data tables
    await deleteFromTable("user_sleep_data",
      ctx.db.query("user_sleep_data").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_sleep_stages",
      ctx.db.query("user_sleep_stages").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_heart_rate",
      ctx.db.query("user_heart_rate").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_activity",
      ctx.db.query("user_activity").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_workouts",
      ctx.db.query("user_workouts").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_circadian_data",
      ctx.db.query("user_circadian_data").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("user_baselines",
      ctx.db.query("user_baselines").withIndex("by_user", (q) => q.eq("user_id", userId)));
    await deleteFromTable("perception_gaps",
      ctx.db.query("perception_gaps").withIndex("by_user", (q) => q.eq("user_id", userId)));

    // Reset apple_health_connected flag
    await ctx.db.patch(userId, {
      apple_health_connected: false,
    });

    return {
      success: true,
      username: user.username,
      deletedRecords,
      deletedTables,
      appleHealthReset: true,
    };
  },
});

/**
 * Full reset: Clear ALL user data including wearables (complete fresh start)
 * This is the most thorough reset option
 */
export const resetUserComplete = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    let deletedRecords = 0;
    const deletedTables: Record<string, number> = {};

    // Helper to delete and track
    async function deleteFromTable(tableName: string, query: { collect: () => Promise<Array<{ _id: Id<any> }>> }) {
      const records = await query.collect();
      for (const record of records) {
        await ctx.db.delete(record._id);
        deletedRecords++;
      }
      if (records.length > 0) {
        deletedTables[tableName] = records.length;
      }
    }

    // ALL user data tables (comprehensive list)
    const allTables = [
      // Assessment & Responses
      "user_assessment_responses",
      "responses",
      "user_progress",
      "daily_checkins",
      "questionnaire_session",
      "questionnaire_scores",
      "user_gateway_states",
      "user_expansion_schedules",
      "onboarding_insights",

      // Wearable/HealthKit data
      "user_sleep_data",
      "user_sleep_stages",
      "user_heart_rate",
      "user_activity",
      "user_workouts",
      "user_circadian_data",
      "user_baselines",

      // Physician dashboard
      "physician_notes",
      "patient_review_status",
      "patient_journey_status",
      "patient_analysis_workflow",
      "patient_visible_fields",

      // Interventions
      "user_interventions",
      "user_daily_tasks",
      "user_protocol_assignments",
      "intervention_compliance",
      "intervention_user_notes",
      "intervention_schedule",
      "intervention_difficulty_settings",

      // Gamification
      "user_streaks",
      "user_badges",
      "user_xp",
      "xp_transactions",
      "user_challenges",

      // Insights and analytics
      "sleep_insights",
      "perception_gaps",
      "user_insight_queue",
      "user_insight_progress",
      "user_cohort_memberships",
      "user_sleep_narrative",
      "user_encouragement_history",

      // Compliance and metrics
      "difficulty_adjustment_log",
      "compliance_outcome_correlation",
      "user_metrics_summary",

      // Watch data
      "watch_offline_queue",
      "watch_garden_state",
    ];

    for (const tableName of allTables) {
      try {
        // @ts-expect-error - dynamic table access for bulk deletion
        const records = await ctx.db.query(tableName).withIndex("by_user", (q: any) => q.eq("user_id", userId)).collect();
        for (const record of records) {
          await ctx.db.delete(record._id);
        }
      } catch (e) {
        // Table might not have by_user index or might not exist, skip silently
        console.log(`Skipping table ${tableName}: ${e}`);
      }
    }

    // Reset user to complete fresh state
    await ctx.db.patch(userId, {
      current_day: 1,
      onboarding_completed: false,
      onboarding_completed_at: undefined,
      developer_mode: false,
      apple_health_connected: false,
    });

    return {
      success: true,
      username: user.username,
      email: user.email,
      deletedRecords,
      deletedTables,
      resetToDay: 1,
      completeReset: true,
    };
  },
});

/**
 * Update any user field (admin override)
 */
export const updateUserField = mutation({
  args: {
    userId: v.id("users"),
    field: v.string(),
    value: v.any(),
  },
  handler: async (ctx, { userId, field, value }) => {
    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    // Whitelist of editable fields
    const editableFields = [
      "username",
      "email",
      "role",
      "current_day",
      "developer_mode",
      "full_name",
      "gender",
      "birth_year",
      "height_cm",
      "weight_kg",
      "measurement_system",
      "apple_health_connected",
      "onboarding_completed",
    ];

    if (!editableFields.includes(field)) {
      return { success: false, error: `Field '${field}' is not editable` };
    }

    const update: Record<string, unknown> = {};
    update[field] = value;

    await ctx.db.patch(userId, update);

    return {
      success: true,
      username: user.username,
      field,
      oldValue: (user as Record<string, unknown>)[field],
      newValue: value,
    };
  },
});

/**
 * Set user role
 */
export const setUserRole = mutation({
  args: {
    userId: v.id("users"),
    role: v.union(v.literal("patient"), v.literal("physician"), v.literal("admin")),
  },
  handler: async (ctx, { userId, role }) => {
    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    await ctx.db.patch(userId, { role });

    return {
      success: true,
      username: user.username,
      oldRole: user.role || "patient",
      newRole: role,
    };
  },
});

/**
 * Export all user data (GDPR compliance)
 */
export const exportUserData = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    // Collect data from all tables
    const data: Record<string, unknown[]> = {};

    // User profile
    data.user = [user];

    // Assessment responses
    data.assessment_responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Progress
    data.progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Sleep data
    data.sleep_data = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Daily checkins
    data.daily_checkins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Gateway states
    data.gateway_states = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Questionnaire scores
    data.questionnaire_scores = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Interventions
    data.interventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Insights
    data.insights = await ctx.db
      .query("sleep_insights")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Journey status
    data.journey_status = await ctx.db
      .query("patient_journey_status")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Gamification
    data.streaks = await ctx.db
      .query("user_streaks")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    data.badges = await ctx.db
      .query("user_badges")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    data.xp = await ctx.db
      .query("user_xp")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Count total records
    let totalRecords = 0;
    for (const records of Object.values(data)) {
      totalRecords += records.length;
    }

    return {
      success: true,
      username: user.username,
      exportedAt: Date.now(),
      totalRecords,
      data,
    };
  },
});

/**
 * Change physician master password
 */
export const changePhysicianMasterPassword = mutation({
  args: {
    currentPasswordHash: v.string(),
    newPasswordHash: v.string(),
  },
  handler: async (ctx, { currentPasswordHash, newPasswordHash }) => {
    const masterPassword = await ctx.db.query("physician_master_password").first();

    if (!masterPassword) {
      return { success: false, error: "Master password not set up" };
    }

    if (masterPassword.password_hash !== currentPasswordHash) {
      return { success: false, error: "Current password is incorrect" };
    }

    await ctx.db.patch(masterPassword._id, {
      password_hash: newPasswordHash,
      updated_at: Date.now(),
    });

    // Invalidate all sessions
    const sessions = await ctx.db
      .query("physician_sessions")
      .withIndex("by_active", (q) => q.eq("is_active", true))
      .collect();

    for (const session of sessions) {
      await ctx.db.patch(session._id, { is_active: false });
    }

    return {
      success: true,
      sessionsInvalidated: sessions.length,
    };
  },
});

/**
 * Get audit log of admin actions (for future implementation)
 */
export const getAdminAuditLog = query({
  args: { limit: v.optional(v.number()) },
  handler: async (_ctx, { limit = 100 }) => {
    // TODO: Implement audit logging table and return recent actions
    // For now, return empty array as placeholder
    return {
      success: true,
      actions: [],
      limit,
      note: "Audit logging not yet implemented",
    };
  },
});
