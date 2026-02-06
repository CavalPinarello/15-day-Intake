"use node";

import { mutation, query, action } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// CBT-I Session Management
// Handles session persistence, thought records, and progress tracking
// ============================================

// ============================================
// Session Mutations
// ============================================

/**
 * Save a completed CBT-I session
 */
export const saveSession = mutation({
  args: {
    userId: v.string(),
    sessionId: v.string(),
    sessionType: v.string(),
    transcriptJson: v.string(),
    sleepWindowJson: v.optional(v.string()),
    emotionSummaryJson: v.optional(v.string()),
    completedAt: v.number(),
  },
  handler: async (ctx, args) => {
    // Find user
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.userId))
      .first();

    if (!user) {
      throw new Error("User not found");
    }

    // Insert session
    const id = await ctx.db.insert("cbti_sessions", {
      user_id: user._id,
      session_id: args.sessionId,
      session_type: args.sessionType,
      transcript_json: args.transcriptJson,
      sleep_window_json: args.sleepWindowJson,
      emotion_summary_json: args.emotionSummaryJson,
      completed_at: args.completedAt,
      flagged_for_review: false,
      created_at: Date.now(),
    });

    console.log(`[cbtiSessions] Saved session ${args.sessionId} (${args.sessionType})`);

    return { id };
  },
});

/**
 * Save user's CBT-I progress
 */
export const saveProgress = mutation({
  args: {
    userId: v.string(),
    weekNumber: v.number(),
    sessionsCompletedJson: v.string(),
    thoughtRecordsCount: v.number(),
    relaxationMinutes: v.number(),
  },
  handler: async (ctx, args) => {
    // Find user
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.userId))
      .first();

    if (!user) {
      throw new Error("User not found");
    }

    // Check if protocol record exists
    const existing = await ctx.db
      .query("cbti_user_protocols")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .first();

    if (existing) {
      // Update existing
      await ctx.db.patch(existing._id, {
        protocol_type: "standard",
        status: args.weekNumber >= 6 ? "completed" : "active",
        current_sleep_window_json: undefined, // Set separately
        sessions_completed: args.thoughtRecordsCount, // Simplified
        compliance_score: undefined,
        updated_at: Date.now(),
      });
    } else {
      // Create new
      await ctx.db.insert("cbti_user_protocols", {
        user_id: user._id,
        protocol_type: "standard",
        status: "active",
        sessions_completed: 0,
        created_at: Date.now(),
      });
    }

    console.log(`[cbtiSessions] Saved progress for user, week ${args.weekNumber}`);
  },
});

/**
 * Save a thought record from cognitive restructuring
 */
export const saveThoughtRecord = mutation({
  args: {
    userId: v.string(),
    recordId: v.string(),
    recordJson: v.string(),
    sessionId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Find user
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.userId))
      .first();

    if (!user) {
      throw new Error("User not found");
    }

    // Parse the record
    const record = JSON.parse(args.recordJson);

    // Insert thought record
    const id = await ctx.db.insert("cbti_thought_records", {
      user_id: user._id,
      record_id: args.recordId,
      session_id: args.sessionId,
      situation: record.situation || "",
      automatic_thought: record.automaticThought || "",
      emotion: record.emotion || "",
      emotion_intensity: record.emotionIntensity || 0,
      cognitive_distortion: record.cognitiveDistortion || undefined,
      evidence_for: record.evidenceFor || undefined,
      evidence_against: record.evidenceAgainst || undefined,
      balanced_thought: record.balancedThought || undefined,
      new_emotion_intensity: record.newEmotionIntensity || undefined,
      created_at: Date.now(),
    });

    console.log(`[cbtiSessions] Saved thought record ${args.recordId}`);

    return { id };
  },
});

/**
 * Flag a session for clinician review
 */
export const flagForReview = mutation({
  args: {
    sessionId: v.string(),
    reason: v.string(),
    timestamp: v.number(),
  },
  handler: async (ctx, args) => {
    // Find the session
    const session = await ctx.db
      .query("cbti_sessions")
      .filter((q) => q.eq(q.field("session_id"), args.sessionId))
      .first();

    if (session) {
      await ctx.db.patch(session._id, {
        flagged_for_review: true,
        review_reason: args.reason,
        flagged_at: args.timestamp,
      });

      console.log(`[cbtiSessions] Flagged session ${args.sessionId} for review: ${args.reason}`);
    }
  },
});

// ============================================
// Session Queries
// ============================================

/**
 * Get all CBT-I sessions for a user
 */
export const getUserSessions = query({
  args: {
    userId: v.string(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.userId))
      .first();

    if (!user) {
      return [];
    }

    const sessions = await ctx.db
      .query("cbti_sessions")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .order("desc")
      .take(args.limit ?? 20);

    return sessions.map((s) => ({
      sessionId: s.session_id,
      sessionType: s.session_type,
      completedAt: s.completed_at,
      flaggedForReview: s.flagged_for_review,
      reviewReason: s.review_reason,
      emotionSummary: s.emotion_summary_json ? JSON.parse(s.emotion_summary_json) : null,
    }));
  },
});

/**
 * Get user's CBT-I progress
 */
export const getUserProgress = query({
  args: {
    userId: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.userId))
      .first();

    if (!user) {
      return null;
    }

    // Get protocol status
    const protocol = await ctx.db
      .query("cbti_user_protocols")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .first();

    // Get session count by type
    const sessions = await ctx.db
      .query("cbti_sessions")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .collect();

    const sessionsByType: Record<string, number> = {};
    for (const session of sessions) {
      sessionsByType[session.session_type] = (sessionsByType[session.session_type] || 0) + 1;
    }

    // Get thought records count
    const thoughtRecords = await ctx.db
      .query("cbti_thought_records")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .collect();

    // Calculate week number based on first session
    const firstSession = sessions[sessions.length - 1];
    let weekNumber = 1;
    if (firstSession) {
      const daysSinceStart = Math.floor(
        (Date.now() - (firstSession.created_at || Date.now())) / (1000 * 60 * 60 * 24)
      );
      weekNumber = Math.max(1, Math.ceil(daysSinceStart / 7));
    }

    return {
      weekNumber,
      totalSessions: sessions.length,
      sessionsByType,
      thoughtRecordsCount: thoughtRecords.length,
      status: protocol?.status || "not_started",
      currentSleepWindow: protocol?.current_sleep_window_json
        ? JSON.parse(protocol.current_sleep_window_json)
        : null,
      complianceScore: protocol?.compliance_score || null,
    };
  },
});

/**
 * Get thought records for a user
 */
export const getThoughtRecords = query({
  args: {
    userId: v.string(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.userId))
      .first();

    if (!user) {
      return [];
    }

    const records = await ctx.db
      .query("cbti_thought_records")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .order("desc")
      .take(args.limit ?? 20);

    return records.map((r) => ({
      id: r.record_id,
      sessionId: r.session_id,
      situation: r.situation,
      automaticThought: r.automatic_thought,
      emotion: r.emotion,
      emotionIntensity: r.emotion_intensity,
      cognitiveDistortion: r.cognitive_distortion,
      evidenceFor: r.evidence_for,
      evidenceAgainst: r.evidence_against,
      balancedThought: r.balanced_thought,
      newEmotionIntensity: r.new_emotion_intensity,
      createdAt: r.created_at,
    }));
  },
});

// ============================================
// Physician Dashboard Queries
// ============================================

/**
 * Get CBT-I overview for a patient (physician view)
 */
export const getPatientCBTIOverview = query({
  args: {
    patientUserId: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.patientUserId))
      .first();

    if (!user) {
      return null;
    }

    // Get all sessions
    const sessions = await ctx.db
      .query("cbti_sessions")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .order("desc")
      .collect();

    // Get flagged sessions
    const flaggedSessions = sessions.filter((s) => s.flagged_for_review);

    // Get thought records
    const thoughtRecords = await ctx.db
      .query("cbti_thought_records")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .collect();

    // Calculate average emotion reduction from thought records
    let totalReduction = 0;
    let recordsWithReduction = 0;
    for (const record of thoughtRecords) {
      if (record.new_emotion_intensity !== undefined && record.emotion_intensity > 0) {
        totalReduction += record.emotion_intensity - record.new_emotion_intensity;
        recordsWithReduction++;
      }
    }

    // Get protocol status
    const protocol = await ctx.db
      .query("cbti_user_protocols")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .first();

    // Calculate week number
    const firstSession = sessions[sessions.length - 1];
    let weekNumber = 1;
    if (firstSession) {
      const daysSinceStart = Math.floor(
        (Date.now() - (firstSession.created_at || Date.now())) / (1000 * 60 * 60 * 24)
      );
      weekNumber = Math.max(1, Math.ceil(daysSinceStart / 7));
    }

    // Get session types completed
    const sessionTypes = new Set(sessions.map((s) => s.session_type));

    // Get emotion trends from sessions
    const emotionTrends = sessions
      .filter((s) => s.emotion_summary_json)
      .map((s) => {
        const summary = JSON.parse(s.emotion_summary_json || "{}");
        return {
          date: s.completed_at,
          averageArousal: summary.averageArousal || 0.5,
          averageValence: summary.averageValence || 0,
          distressDetected: summary.distressDetected || false,
        };
      });

    return {
      weekNumber,
      status: protocol?.status || "not_started",
      totalSessions: sessions.length,
      sessionTypesCompleted: Array.from(sessionTypes),
      flaggedSessionsCount: flaggedSessions.length,
      flaggedSessions: flaggedSessions.map((s) => ({
        sessionId: s.session_id,
        sessionType: s.session_type,
        reason: s.review_reason,
        flaggedAt: s.flagged_at,
      })),
      thoughtRecordsCount: thoughtRecords.length,
      averageEmotionReduction:
        recordsWithReduction > 0 ? totalReduction / recordsWithReduction : null,
      currentSleepWindow: protocol?.current_sleep_window_json
        ? JSON.parse(protocol.current_sleep_window_json)
        : null,
      emotionTrends,
      recentSessions: sessions.slice(0, 5).map((s) => ({
        sessionType: s.session_type,
        completedAt: s.completed_at,
        flagged: s.flagged_for_review,
      })),
    };
  },
});

/**
 * Get full session transcript for review
 */
export const getSessionTranscript = query({
  args: {
    sessionId: v.string(),
  },
  handler: async (ctx, args) => {
    const session = await ctx.db
      .query("cbti_sessions")
      .filter((q) => q.eq(q.field("session_id"), args.sessionId))
      .first();

    if (!session) {
      return null;
    }

    return {
      sessionId: session.session_id,
      sessionType: session.session_type,
      transcript: session.transcript_json ? JSON.parse(session.transcript_json) : [],
      emotionSummary: session.emotion_summary_json
        ? JSON.parse(session.emotion_summary_json)
        : null,
      sleepWindow: session.sleep_window_json ? JSON.parse(session.sleep_window_json) : null,
      completedAt: session.completed_at,
      flaggedForReview: session.flagged_for_review,
      reviewReason: session.review_reason,
    };
  },
});

// ============================================
// Sleep Window Management
// ============================================

/**
 * Update user's sleep window
 */
export const updateSleepWindow = mutation({
  args: {
    userId: v.string(),
    sleepWindowJson: v.string(),
    sleepEfficiency: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.userId))
      .first();

    if (!user) {
      throw new Error("User not found");
    }

    // Get or create protocol record
    let protocol = await ctx.db
      .query("cbti_user_protocols")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .first();

    if (protocol) {
      await ctx.db.patch(protocol._id, {
        current_sleep_window_json: args.sleepWindowJson,
        updated_at: Date.now(),
      });
    } else {
      await ctx.db.insert("cbti_user_protocols", {
        user_id: user._id,
        protocol_type: "standard",
        status: "active",
        current_sleep_window_json: args.sleepWindowJson,
        created_at: Date.now(),
      });
    }

    console.log(`[cbtiSessions] Updated sleep window for user`);
  },
});

// ============================================
// Analytics
// ============================================

/**
 * Get CBT-I analytics for physician dashboard
 */
export const getCBTIAnalytics = query({
  args: {
    physicianUserId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Get all active CBT-I protocols
    const protocols = await ctx.db.query("cbti_user_protocols").collect();

    const activeCount = protocols.filter((p) => p.status === "active").length;
    const completedCount = protocols.filter((p) => p.status === "completed").length;

    // Get all sessions
    const sessions = await ctx.db.query("cbti_sessions").collect();

    // Count sessions by type
    const sessionsByType: Record<string, number> = {};
    for (const session of sessions) {
      sessionsByType[session.session_type] = (sessionsByType[session.session_type] || 0) + 1;
    }

    // Count flagged sessions
    const flaggedCount = sessions.filter((s) => s.flagged_for_review).length;

    // Get all thought records for average emotion reduction
    const thoughtRecords = await ctx.db.query("cbti_thought_records").collect();
    let totalReduction = 0;
    let recordsWithReduction = 0;
    for (const record of thoughtRecords) {
      if (record.new_emotion_intensity !== undefined && record.emotion_intensity > 0) {
        totalReduction += record.emotion_intensity - record.new_emotion_intensity;
        recordsWithReduction++;
      }
    }

    return {
      totalPatients: protocols.length,
      activePatients: activeCount,
      completedPatients: completedCount,
      totalSessions: sessions.length,
      sessionsByType,
      flaggedSessionsCount: flaggedCount,
      totalThoughtRecords: thoughtRecords.length,
      averageEmotionReduction:
        recordsWithReduction > 0 ? totalReduction / recordsWithReduction : null,
    };
  },
});
