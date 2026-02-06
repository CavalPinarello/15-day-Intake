"use node";

// Node.js process type declaration
declare const process: {
  env: Record<string, string | undefined>;
};

import { action, mutation, query } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// Hume AI Emotional Analysis
// Analyzes voice patterns to detect sleep-relevant emotions
// ============================================

// Hume API configuration
const HUME_API_URL = "https://api.hume.ai/v0/batch/jobs";

// Sleep-relevant emotions we track
const SLEEP_RELEVANT_EMOTIONS = [
  "anxiety",
  "stress",
  "calm",
  "frustration",
  "sadness",
  "confusion",
  "fatigue",
  "irritability",
  "hopelessness",
  "contentment"
];

// Mapping from Hume's emotion names to our sleep-relevant categories
const EMOTION_MAPPING: Record<string, string> = {
  "Anxiety": "anxiety",
  "Fear": "anxiety",
  "Nervousness": "anxiety",
  "Worry": "anxiety",
  "Stress": "stress",
  "Tension": "stress",
  "Overwhelmed": "stress",
  "Calmness": "calm",
  "Serenity": "calm",
  "Relaxation": "calm",
  "Contentment": "contentment",
  "Satisfaction": "contentment",
  "Happiness": "contentment",
  "Frustration": "frustration",
  "Annoyance": "frustration",
  "Irritation": "irritability",
  "Anger": "irritability",
  "Rage": "irritability",
  "Sadness": "sadness",
  "Disappointment": "sadness",
  "Grief": "sadness",
  "Tiredness": "fatigue",
  "Boredom": "fatigue",
  "Lethargy": "fatigue",
  "Confusion": "confusion",
  "Doubt": "confusion",
  "Uncertainty": "confusion",
  "Despair": "hopelessness",
  "Hopelessness": "hopelessness",
  "Distress": "hopelessness"
};

// ============================================
// Emotion Analysis Action
// ============================================

export const analyzeEmotion = action({
  args: {
    userId: v.string(),
    audioBase64: v.string(),
    sessionId: v.string(),
    sessionType: v.string(),
  },
  handler: async (ctx, args): Promise<{
    success: boolean;
    snapshot: {
      emotions: Record<string, number>;
      dominantEmotion: string;
      arousalLevel: number;
      valence: number;
      speechRate: number | null;
      voicePitch: number | null;
    } | null;
    error: string | null;
  }> => {
    const humeApiKey = process.env.HUME_API_KEY;

    if (!humeApiKey) {
      console.log("[humeEmotions:analyzeEmotion] HUME_API_KEY not configured - returning mock data");
      // Return mock data for development/testing
      return {
        success: true,
        snapshot: generateMockEmotionSnapshot(),
        error: null
      };
    }

    try {
      // Decode audio
      const audioBuffer = Buffer.from(args.audioBase64, "base64");

      // Create form data for Hume API
      const formData = new FormData();
      const audioBlob = new Blob([audioBuffer], { type: "audio/wav" });
      formData.append("file", audioBlob, "audio.wav");

      // Configure models - we want prosody (voice emotion) analysis
      const models = {
        prosody: {
          granularity: "utterance"
        }
      };
      formData.append("models", JSON.stringify(models));

      // Call Hume API
      const response = await fetch(HUME_API_URL, {
        method: "POST",
        headers: {
          "X-Hume-Api-Key": humeApiKey,
        },
        body: formData
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error("[humeEmotions] Hume API error:", response.status, errorText);
        throw new Error(`Hume API error: ${response.status}`);
      }

      const result = await response.json();

      // Parse Hume response
      const snapshot = parseHumeResponse(result);

      console.log(`[humeEmotions] Analyzed emotion: ${snapshot.dominantEmotion} (arousal: ${snapshot.arousalLevel.toFixed(2)}, valence: ${snapshot.valence.toFixed(2)})`);

      return {
        success: true,
        snapshot,
        error: null
      };

    } catch (error) {
      console.error("[humeEmotions] Analysis error:", error);
      return {
        success: false,
        snapshot: null,
        error: error instanceof Error ? error.message : "Unknown error"
      };
    }
  }
});

// ============================================
// Save Session Summary
// ============================================

export const saveSessionSummary = mutation({
  args: {
    userId: v.string(),
    sessionId: v.string(),
    sessionType: v.string(),
    summaryJson: v.string(),
    distressDetected: v.boolean(),
    averageArousal: v.number(),
    averageValence: v.number(),
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

    // Insert emotion summary
    const summaryId = await ctx.db.insert("emotional_analysis_results", {
      user_id: user._id,
      session_id: args.sessionId,
      session_type: args.sessionType,
      summary_json: args.summaryJson,
      distress_detected: args.distressDetected,
      average_arousal: args.averageArousal,
      average_valence: args.averageValence,
      created_at: Date.now(),
    });

    console.log(`[humeEmotions] Saved emotion summary: ${summaryId}`);

    return { summaryId };
  }
});

// ============================================
// Get Session Emotions (for physician dashboard)
// ============================================

export const getSessionEmotions = query({
  args: {
    userId: v.string(),
    sessionId: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // Find user
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.userId))
      .first();

    if (!user) {
      return [];
    }

    let query = ctx.db
      .query("emotional_analysis_results")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .order("desc");

    const results = await query.take(args.limit ?? 10);

    // Filter by session if specified
    if (args.sessionId) {
      return results.filter(r => r.session_id === args.sessionId);
    }

    return results.map(r => ({
      sessionId: r.session_id,
      sessionType: r.session_type,
      distressDetected: r.distress_detected,
      averageArousal: r.average_arousal,
      averageValence: r.average_valence,
      createdAt: r.created_at,
      summary: JSON.parse(r.summary_json || "{}")
    }));
  }
});

// ============================================
// Get Patient Emotion Trends (for physician)
// ============================================

export const getPatientEmotionTrends = query({
  args: {
    patientUserId: v.string(),
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerk_id", args.patientUserId))
      .first();

    if (!user) {
      return null;
    }

    const cutoff = Date.now() - (args.days ?? 30) * 24 * 60 * 60 * 1000;

    const results = await ctx.db
      .query("emotional_analysis_results")
      .withIndex("by_user_id", (q) => q.eq("user_id", user._id))
      .filter((q) => q.gte(q.field("created_at"), cutoff))
      .order("asc")
      .collect();

    // Calculate trends
    const arousalTrend = results.map(r => ({
      date: r.created_at,
      value: r.average_arousal
    }));

    const valenceTrend = results.map(r => ({
      date: r.created_at,
      value: r.average_valence
    }));

    const distressCount = results.filter(r => r.distress_detected).length;

    // Extract dominant emotions across sessions
    const emotionCounts: Record<string, number> = {};
    for (const r of results) {
      try {
        const summary = JSON.parse(r.summary_json || "{}");
        if (summary.dominantEmotions) {
          for (const emotion of summary.dominantEmotions) {
            emotionCounts[emotion] = (emotionCounts[emotion] || 0) + 1;
          }
        }
      } catch {
        // Ignore parse errors
      }
    }

    const topEmotions = Object.entries(emotionCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([emotion, count]) => ({ emotion, count }));

    return {
      sessionCount: results.length,
      distressCount,
      arousalTrend,
      valenceTrend,
      topEmotions,
      averageArousal: results.length > 0
        ? results.reduce((sum, r) => sum + r.average_arousal, 0) / results.length
        : 0.5,
      averageValence: results.length > 0
        ? results.reduce((sum, r) => sum + r.average_valence, 0) / results.length
        : 0.0
    };
  }
});

// ============================================
// Helper Functions
// ============================================

function parseHumeResponse(result: any): {
  emotions: Record<string, number>;
  dominantEmotion: string;
  arousalLevel: number;
  valence: number;
  speechRate: number | null;
  voicePitch: number | null;
} {
  const sleepEmotions: Record<string, number> = {};
  let maxEmotion = { name: "calm", score: 0 };

  // Extract emotions from Hume response
  const predictions = result?.results?.[0]?.predictions?.[0]?.models?.prosody?.grouped_predictions?.[0]?.predictions || [];

  for (const pred of predictions) {
    const emotions = pred.emotions || [];

    for (const emotion of emotions) {
      const mappedName = EMOTION_MAPPING[emotion.name];
      if (mappedName) {
        const currentScore = sleepEmotions[mappedName] || 0;
        sleepEmotions[mappedName] = Math.max(currentScore, emotion.score);

        if (emotion.score > maxEmotion.score) {
          maxEmotion = { name: mappedName, score: emotion.score };
        }
      }
    }
  }

  // Calculate arousal (high-activation emotions)
  const arousalEmotions = ["anxiety", "stress", "irritability", "frustration"];
  const arousalScores = arousalEmotions
    .map(e => sleepEmotions[e] || 0)
    .filter(s => s > 0);
  const arousal = arousalScores.length > 0
    ? arousalScores.reduce((a, b) => a + b, 0) / arousalScores.length
    : 0.5;

  // Calculate valence (positive - negative)
  const positiveEmotions = ["calm", "contentment"];
  const negativeEmotions = ["anxiety", "sadness", "frustration", "hopelessness"];

  const positiveScore = positiveEmotions
    .map(e => sleepEmotions[e] || 0)
    .reduce((a, b) => a + b, 0);
  const negativeScore = negativeEmotions
    .map(e => sleepEmotions[e] || 0)
    .reduce((a, b) => a + b, 0);

  const valence = Math.max(-1, Math.min(1, positiveScore - negativeScore));

  return {
    emotions: sleepEmotions,
    dominantEmotion: maxEmotion.name,
    arousalLevel: Math.max(0, Math.min(1, arousal)),
    valence,
    speechRate: null,
    voicePitch: null
  };
}

function generateMockEmotionSnapshot(): {
  emotions: Record<string, number>;
  dominantEmotion: string;
  arousalLevel: number;
  valence: number;
  speechRate: number | null;
  voicePitch: number | null;
} {
  // Generate realistic mock data for testing
  const emotions = [
    { name: "calm", weight: 0.4 },
    { name: "stress", weight: 0.2 },
    { name: "anxiety", weight: 0.15 },
    { name: "fatigue", weight: 0.15 },
    { name: "contentment", weight: 0.1 }
  ];

  const result: Record<string, number> = {};
  let dominant = { name: "calm", score: 0 };

  for (const emotion of emotions) {
    const score = emotion.weight + (Math.random() - 0.5) * 0.3;
    result[emotion.name] = Math.max(0, Math.min(1, score));

    if (result[emotion.name] > dominant.score) {
      dominant = { name: emotion.name, score: result[emotion.name] };
    }
  }

  return {
    emotions: result,
    dominantEmotion: dominant.name,
    arousalLevel: 0.3 + Math.random() * 0.4,
    valence: -0.2 + Math.random() * 0.6,
    speechRate: 120 + Math.random() * 40,
    voicePitch: null
  };
}
