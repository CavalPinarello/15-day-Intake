/**
 * Encouragement Engine
 * Science-backed personalized encouragement messages for Zoe Sleep
 *
 * Evidence-based messages that normalize experiences and provide hope
 * based on user demographics, gateways triggered, and clinical scores.
 */

import { v } from "convex/values";
import { query, mutation, internalMutation } from "./_generated/server";
import { Id } from "./_generated/dataModel";

// ============================================
// Types
// ============================================

export type DemographicFilter = {
  genders?: string[];
  ageMin?: number;
  ageMax?: number;
  gateways?: string[];
  scoreThresholds?: {
    isi?: { min?: number; max?: number };
    phq9?: { min?: number; max?: number };
    gad7?: { min?: number; max?: number };
    ess?: { min?: number; max?: number };
    stopBang?: { min?: number; max?: number };
  };
};

export type EncouragementMessage = {
  id: string;
  messageText: string;
  triggerContext: string;
  demographicFilter: DemographicFilter;
  category: "normalization" | "encouragement" | "education" | "cohort_comparison";
  sourceCitation: string;
  priority: number;
};

// ============================================
// Evidence-Based Message Library
// ============================================

export const ENCOURAGEMENT_MESSAGES: EncouragementMessage[] = [
  // Perimenopause / Menopause Messages (Women 45-55)
  {
    id: "perimenopause_1",
    messageText:
      "Many women experience sleep changes during perimenopause due to hormone fluctuations. You're not alone - 40-60% of women report this. The good news: targeted interventions can help significantly.",
    triggerContext: "poor_sleep_quality",
    demographicFilter: { genders: ["female", "woman"], ageMin: 45, ageMax: 55 },
    category: "normalization",
    sourceCitation: "Baker et al., Sleep Medicine Reviews, 2018",
    priority: 1,
  },
  {
    id: "perimenopause_2",
    messageText:
      "Hot flashes and night sweats affect up to 80% of women during menopause. These are temporary and there are effective strategies to manage them.",
    triggerContext: "night_waking",
    demographicFilter: { genders: ["female", "woman"], ageMin: 45, ageMax: 60 },
    category: "normalization",
    sourceCitation: "Freedman, Menopause, 2014",
    priority: 2,
  },
  {
    id: "perimenopause_3",
    messageText:
      "Women's body temperature rhythms shift during menopause, often requiring a cooler bedroom. The ideal sleep temperature is 65-68°F (18-20°C).",
    triggerContext: "temperature_related",
    demographicFilter: { genders: ["female", "woman"], ageMin: 45, ageMax: 65 },
    category: "education",
    sourceCitation: "National Sleep Foundation, 2021",
    priority: 3,
  },

  // Older Adults (60+)
  {
    id: "older_adult_1",
    messageText:
      "Research shows sleep needs change with age. 5-6 hours with good efficiency can be normal. What matters most is how refreshed you feel.",
    triggerContext: "short_sleep_duration",
    demographicFilter: { ageMin: 60 },
    category: "normalization",
    sourceCitation: "Ohayon et al., Sleep Medicine Reviews, 2017",
    priority: 1,
  },
  {
    id: "older_adult_2",
    messageText:
      "Earlier wake times are common after age 60 due to natural circadian shifts. This 'advanced sleep phase' is biological, not a disorder.",
    triggerContext: "early_waking",
    demographicFilter: { ageMin: 60 },
    category: "education",
    sourceCitation: "Duffy & Czeisler, Sleep Medicine Clinics, 2015",
    priority: 2,
  },
  {
    id: "older_adult_3",
    messageText:
      "Brief naps (20-30 minutes) before 3 PM can improve alertness without disrupting nighttime sleep for many older adults.",
    triggerContext: "daytime_fatigue",
    demographicFilter: { ageMin: 60 },
    category: "education",
    sourceCitation: "Milner & Cote, Sleep Medicine Reviews, 2009",
    priority: 3,
  },

  // Young Adults (18-30)
  {
    id: "young_adult_1",
    messageText:
      "Your sleep timing suggests a 'night owl' chronotype - this is genetic, not laziness. About 25% of people share this pattern.",
    triggerContext: "late_chronotype",
    demographicFilter: { ageMin: 18, ageMax: 30 },
    category: "normalization",
    sourceCitation: "Roenneberg et al., Current Biology, 2007",
    priority: 1,
  },
  {
    id: "young_adult_2",
    messageText:
      "Teenagers and young adults naturally have a delayed circadian rhythm. Your body wants to sleep later - this shifts back in your 20s.",
    triggerContext: "late_bedtime",
    demographicFilter: { ageMin: 16, ageMax: 25 },
    category: "education",
    sourceCitation: "Crowley et al., Sleep, 2018",
    priority: 2,
  },
  {
    id: "young_adult_3",
    messageText:
      "Morning exercise can help shift night owls earlier, but evening exercise within 3 hours of bed may delay sleep onset.",
    triggerContext: "exercise_timing",
    demographicFilter: { ageMin: 18, ageMax: 35 },
    category: "education",
    sourceCitation: "Youngstedt, Sleep Medicine Reviews, 2005",
    priority: 3,
  },

  // Insomnia Gateway
  {
    id: "insomnia_1",
    messageText:
      "Recognizing insomnia is the first step. CBT-I (Cognitive Behavioral Therapy for Insomnia) has an 80% success rate - better than sleeping pills long-term.",
    triggerContext: "insomnia_gateway",
    demographicFilter: { gateways: ["insomnia"] },
    category: "encouragement",
    sourceCitation: "Morin et al., JAMA, 2006",
    priority: 1,
  },
  {
    id: "insomnia_2",
    messageText:
      "Most people with insomnia see significant improvement within 4-6 weeks of starting treatment. Your journey to better sleep is achievable.",
    triggerContext: "insomnia_gateway",
    demographicFilter: { gateways: ["insomnia"] },
    category: "encouragement",
    sourceCitation: "Trauer et al., Annals of Internal Medicine, 2015",
    priority: 2,
  },
  {
    id: "insomnia_high_isi",
    messageText:
      "Your insomnia severity score indicates moderate to severe symptoms. The good news: people with higher scores often see the most improvement with treatment.",
    triggerContext: "high_isi_score",
    demographicFilter: { scoreThresholds: { isi: { min: 15 } } },
    category: "encouragement",
    sourceCitation: "Morin et al., Sleep, 2011",
    priority: 1,
  },

  // Anxiety Gateway
  {
    id: "anxiety_1",
    messageText:
      "Anxiety and sleep problems often go together - treating one often improves the other. You're taking an important step by addressing both.",
    triggerContext: "anxiety_gateway",
    demographicFilter: { gateways: ["anxiety"] },
    category: "normalization",
    sourceCitation: "Alvaro et al., Sleep Medicine Reviews, 2013",
    priority: 1,
  },
  {
    id: "anxiety_2",
    messageText:
      "Caffeine sensitivity increases with anxiety. Even morning coffee can affect sleep 12+ hours later in some people.",
    triggerContext: "caffeine_question",
    demographicFilter: { gateways: ["anxiety"] },
    category: "education",
    sourceCitation: "Drake et al., Journal of Clinical Sleep Medicine, 2013",
    priority: 2,
  },
  {
    id: "anxiety_3",
    messageText:
      "Racing thoughts at bedtime are very common with anxiety. Relaxation techniques and cognitive strategies can help quiet the mind.",
    triggerContext: "racing_thoughts",
    demographicFilter: { gateways: ["anxiety"] },
    category: "normalization",
    sourceCitation: "Harvey, Behaviour Research and Therapy, 2002",
    priority: 2,
  },

  // Depression Gateway
  {
    id: "depression_1",
    messageText:
      "Sleep problems and mood are deeply connected. Improving sleep often leads to significant mood improvements within weeks.",
    triggerContext: "depression_gateway",
    demographicFilter: { gateways: ["depression"] },
    category: "encouragement",
    sourceCitation: "Cunningham & Shapiro, Clinical Psychology Review, 2018",
    priority: 1,
  },
  {
    id: "depression_2",
    messageText:
      "Early morning waking is common with depression. As your mood improves with treatment, your sleep often naturally extends.",
    triggerContext: "early_waking",
    demographicFilter: { gateways: ["depression"] },
    category: "education",
    sourceCitation: "Nutt et al., Dialogues in Clinical Neuroscience, 2008",
    priority: 2,
  },

  // Sleep Apnea Gateway
  {
    id: "apnea_1",
    messageText:
      "Snoring and breathing pauses during sleep are treatable conditions. Effective treatment can dramatically improve energy and cognitive function.",
    triggerContext: "apnea_gateway",
    demographicFilter: { gateways: ["sleepApnea"] },
    category: "encouragement",
    sourceCitation: "Peppard et al., American Journal of Epidemiology, 2013",
    priority: 1,
  },
  {
    id: "apnea_2",
    messageText:
      "Sleep apnea affects about 1 in 5 adults. Many don't know they have it. Getting tested is an important step for your health.",
    triggerContext: "apnea_screening",
    demographicFilter: { gateways: ["sleepApnea"] },
    category: "normalization",
    sourceCitation: "Young et al., New England Journal of Medicine, 1993",
    priority: 2,
  },
  {
    id: "apnea_men_40",
    messageText:
      "Men over 40 have higher rates of sleep apnea, especially with neck circumference above 17 inches. Treatment can transform your energy levels.",
    triggerContext: "apnea_risk_factors",
    demographicFilter: { genders: ["male", "man"], ageMin: 40, gateways: ["sleepApnea"] },
    category: "education",
    sourceCitation: "AASM Clinical Guidelines, 2021",
    priority: 1,
  },

  // Perception Gap Messages
  {
    id: "perception_gap_1",
    messageText:
      "Interesting - your wearable shows you're sleeping better than you feel. This 'sleep state misperception' is common and treatable.",
    triggerContext: "perception_gap_detected",
    demographicFilter: {},
    category: "education",
    sourceCitation: "Edinger & Krystal, Sleep Medicine Reviews, 2003",
    priority: 1,
  },
  {
    id: "perception_gap_2",
    messageText:
      "Anxiety can make us hyper-aware of night wakings, making sleep feel worse than it is. Cognitive techniques can help recalibrate this perception.",
    triggerContext: "perception_gap_anxiety",
    demographicFilter: { gateways: ["anxiety", "insomnia"] },
    category: "education",
    sourceCitation: "Harvey & Tang, Behaviour Research and Therapy, 2012",
    priority: 2,
  },

  // Chronic Pain Gateway
  {
    id: "pain_1",
    messageText:
      "Chronic pain and poor sleep create a cycle - but breaking it is possible. Improving sleep often reduces pain sensitivity.",
    triggerContext: "pain_gateway",
    demographicFilter: { gateways: ["pain"] },
    category: "encouragement",
    sourceCitation: "Finan et al., Sleep Medicine Reviews, 2013",
    priority: 1,
  },
  {
    id: "pain_2",
    messageText:
      "Sleep position matters with chronic pain. Finding the right position and pillow support can significantly reduce nighttime discomfort.",
    triggerContext: "pain_sleep_position",
    demographicFilter: { gateways: ["pain"] },
    category: "education",
    sourceCitation: "Cary et al., BMJ Open, 2019",
    priority: 2,
  },

  // General Encouragement
  {
    id: "general_progress_1",
    messageText:
      "Every answer you provide helps us build a clearer picture of your sleep. Small insights lead to big improvements.",
    triggerContext: "questionnaire_progress",
    demographicFilter: {},
    category: "encouragement",
    sourceCitation: "Internal",
    priority: 3,
  },
  {
    id: "general_data_1",
    messageText:
      "The more we understand about your unique sleep patterns, the more personalized your recommendations will be.",
    triggerContext: "data_collection",
    demographicFilter: {},
    category: "encouragement",
    sourceCitation: "Internal",
    priority: 4,
  },
  {
    id: "general_completion_1",
    messageText:
      "Completing your sleep assessment puts you in the top 10% of people taking active steps to improve their sleep.",
    triggerContext: "assessment_completion",
    demographicFilter: {},
    category: "cohort_comparison",
    sourceCitation: "Internal analytics",
    priority: 2,
  },

  // Cohort Comparison Messages
  {
    id: "cohort_isi_moderate",
    messageText:
      "Your insomnia severity is in the moderate range - similar to about 40% of people seeking sleep help. Most see significant improvement within 6 weeks.",
    triggerContext: "isi_moderate",
    demographicFilter: { scoreThresholds: { isi: { min: 15, max: 21 } } },
    category: "cohort_comparison",
    sourceCitation: "Morin et al., Sleep, 2011",
    priority: 1,
  },
  {
    id: "cohort_engagement",
    messageText:
      "Users who complete all 15 days of assessment are 3x more likely to maintain their sleep improvements long-term.",
    triggerContext: "day_completion",
    demographicFilter: {},
    category: "cohort_comparison",
    sourceCitation: "Internal analytics",
    priority: 2,
  },
];

// ============================================
// Query Functions
// ============================================

/**
 * Get encouragement message for a specific user based on their profile and context
 */
export const getEncouragementForUser = query({
  args: {
    userId: v.id("users"),
    triggerContext: v.string(),
  },
  handler: async (ctx, { userId, triggerContext }) => {
    // Get user profile
    const user = await ctx.db.get(userId);
    if (!user) return null;

    // Calculate user age
    const currentYear = new Date().getFullYear();
    const userAge = user.birth_year ? currentYear - user.birth_year : null;

    // Get user's triggered gateways
    const gatewayResults = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .filter((q) => q.eq(q.field("triggered"), true))
      .collect();
    const triggeredGateways = gatewayResults.map((g) => g.gateway_id);

    // Get user's clinical scores
    const allScores = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();
    // Build a scores object from individual questionnaire results
    const scores = {
      isi_score: allScores.find(s => s.questionnaire_name === "ISI")?.score ?? null,
      phq9_score: allScores.find(s => s.questionnaire_name === "PHQ-9")?.score ?? null,
      gad7_score: allScores.find(s => s.questionnaire_name === "GAD-7")?.score ?? null,
    };

    // Get messages already shown to this user
    const shownMessages = await ctx.db
      .query("user_encouragement_history")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();
    const shownMessageIds = new Set(shownMessages.map((m) => m.message_id));

    // Filter and score messages
    const matchingMessages = ENCOURAGEMENT_MESSAGES.filter((msg) => {
      // Skip if already shown
      if (shownMessageIds.has(msg.id)) return false;

      // Match trigger context (or allow general messages)
      if (msg.triggerContext !== triggerContext && msg.triggerContext !== "general") {
        return false;
      }

      const filter = msg.demographicFilter;

      // Gender filter
      if (filter.genders && filter.genders.length > 0) {
        const userGender = user.gender?.toLowerCase();
        if (!userGender || !filter.genders.some((g) => userGender.includes(g.toLowerCase()))) {
          return false;
        }
      }

      // Age filter
      if (userAge !== null) {
        if (filter.ageMin && userAge < filter.ageMin) return false;
        if (filter.ageMax && userAge > filter.ageMax) return false;
      }

      // Gateway filter
      if (filter.gateways && filter.gateways.length > 0) {
        const hasMatchingGateway = filter.gateways.some((g) =>
          triggeredGateways.includes(g)
        );
        if (!hasMatchingGateway) return false;
      }

      // Score threshold filter
      if (filter.scoreThresholds) {
        const thresholds = filter.scoreThresholds;
        if (thresholds.isi) {
          if (thresholds.isi.min && (scores.isi_score ?? 0) < thresholds.isi.min) return false;
          if (thresholds.isi.max && (scores.isi_score ?? 0) > thresholds.isi.max) return false;
        }
        if (thresholds.phq9) {
          if (thresholds.phq9.min && (scores.phq9_score ?? 0) < thresholds.phq9.min) return false;
          if (thresholds.phq9.max && (scores.phq9_score ?? 0) > thresholds.phq9.max) return false;
        }
        if (thresholds.gad7) {
          if (thresholds.gad7.min && (scores.gad7_score ?? 0) < thresholds.gad7.min) return false;
          if (thresholds.gad7.max && (scores.gad7_score ?? 0) > thresholds.gad7.max) return false;
        }
      }

      return true;
    });

    // Sort by priority and return the best match
    matchingMessages.sort((a, b) => a.priority - b.priority);
    return matchingMessages[0] || null;
  },
});

/**
 * Get multiple encouragement messages for display
 */
export const getEncouragementMessages = query({
  args: {
    userId: v.id("users"),
    limit: v.optional(v.number()),
    category: v.optional(v.string()),
  },
  handler: async (ctx, { userId, limit = 3, category }) => {
    const user = await ctx.db.get(userId);
    if (!user) return [];

    const currentYear = new Date().getFullYear();
    const userAge = user.birth_year ? currentYear - user.birth_year : null;

    const gatewayResults = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .filter((q) => q.eq(q.field("triggered"), true))
      .collect();
    const triggeredGateways = gatewayResults.map((g) => g.gateway_id);

    const shownMessages = await ctx.db
      .query("user_encouragement_history")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();
    const shownMessageIds = new Set(shownMessages.map((m) => m.message_id));

    // Filter messages matching user profile
    const matchingMessages = ENCOURAGEMENT_MESSAGES.filter((msg) => {
      if (shownMessageIds.has(msg.id)) return false;
      if (category && msg.category !== category) return false;

      const filter = msg.demographicFilter;

      if (filter.genders && filter.genders.length > 0) {
        const userGender = user.gender?.toLowerCase();
        if (!userGender || !filter.genders.some((g) => userGender.includes(g.toLowerCase()))) {
          return false;
        }
      }

      if (userAge !== null) {
        if (filter.ageMin && userAge < filter.ageMin) return false;
        if (filter.ageMax && userAge > filter.ageMax) return false;
      }

      if (filter.gateways && filter.gateways.length > 0) {
        const hasMatchingGateway = filter.gateways.some((g) =>
          triggeredGateways.includes(g)
        );
        if (!hasMatchingGateway) return false;
      }

      return true;
    });

    matchingMessages.sort((a, b) => a.priority - b.priority);
    return matchingMessages.slice(0, limit);
  },
});

/**
 * Get cohort statistics for user comparison
 */
export const getCohortComparison = query({
  args: {
    userId: v.id("users"),
    metricType: v.string(),
  },
  handler: async (ctx, { userId, metricType }) => {
    const user = await ctx.db.get(userId);
    if (!user) return null;

    // Get cohort statistics by stat_id (metric type as stat_id)
    const cohortStats = await ctx.db
      .query("cohort_statistics")
      .withIndex("by_stat_id", (q) => q.eq("stat_id", metricType))
      .first();

    if (!cohortStats) return null;

    // Get user's specific value for this metric
    let userValue: number | null = null;

    if (metricType === "isi_score") {
      const isiScore = await ctx.db
        .query("questionnaire_scores")
        .withIndex("by_user_questionnaire", (q) =>
          q.eq("user_id", userId).eq("questionnaire_name", "ISI")
        )
        .first();
      userValue = isiScore?.score ?? null;
    } else if (metricType === "completion_rate") {
      const progress = await ctx.db
        .query("user_progress")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .filter((q) => q.eq(q.field("completed"), true))
        .collect();
      userValue = progress.length;
    }

    if (userValue === null) return null;

    // Calculate percentile using stat_value as the cohort mean
    // Parse cohort_criteria_json for more detailed statistics if available
    let cohortMean = cohortStats.stat_value;
    let stdDev = 1; // Default standard deviation
    try {
      const criteria = JSON.parse(cohortStats.cohort_criteria_json);
      if (criteria.std_deviation) stdDev = criteria.std_deviation;
      if (criteria.mean) cohortMean = criteria.mean;
    } catch {
      // Use defaults if parsing fails
    }

    const percentile = calculatePercentile(userValue, cohortMean, stdDev);

    return {
      userValue,
      percentile,
      cohortMean,
      sampleSize: cohortStats.sample_size,
      message: generateCohortMessage(metricType, percentile),
    };
  },
});

// ============================================
// Mutation Functions
// ============================================

/**
 * Record that a user has seen an encouragement message
 */
export const recordEncouragementSeen = mutation({
  args: {
    userId: v.id("users"),
    messageId: v.string(),
    context: v.optional(v.string()),
  },
  handler: async (ctx, { userId, messageId, context }) => {
    await ctx.db.insert("user_encouragement_history", {
      user_id: userId,
      message_id: messageId,
      shown_at: Date.now(),
      context: context || "unknown",
      dismissed: false,
    });
  },
});

/**
 * Record user feedback on encouragement message
 */
export const rateEncouragementMessage = mutation({
  args: {
    userId: v.id("users"),
    messageId: v.string(),
    wasHelpful: v.boolean(),
  },
  handler: async (ctx, { userId, messageId, wasHelpful }) => {
    const record = await ctx.db
      .query("user_encouragement_history")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .filter((q) => q.eq(q.field("message_id"), messageId))
      .first();

    if (record) {
      await ctx.db.patch(record._id, { was_helpful: wasHelpful });
    }
  },
});

// ============================================
// Helper Functions
// ============================================

function calculatePercentile(value: number, mean: number, stdDev: number): number {
  if (stdDev === 0) return 50;
  const zScore = (value - mean) / stdDev;
  // Approximate percentile from z-score
  const percentile = 50 * (1 + erf(zScore / Math.sqrt(2)));
  return Math.round(Math.max(1, Math.min(99, percentile)));
}

// Error function approximation for normal distribution
function erf(x: number): number {
  const a1 = 0.254829592;
  const a2 = -0.284496736;
  const a3 = 1.421413741;
  const a4 = -1.453152027;
  const a5 = 1.061405429;
  const p = 0.3275911;

  const sign = x < 0 ? -1 : 1;
  x = Math.abs(x);

  const t = 1.0 / (1.0 + p * x);
  const y = 1.0 - ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * Math.exp(-x * x);

  return sign * y;
}

function generateCohortMessage(metricType: string, percentile: number): string {
  if (metricType === "isi_score") {
    if (percentile < 30) {
      return `Your insomnia severity is lower than ${100 - percentile}% of users - you're on the right track!`;
    } else if (percentile < 70) {
      return `Your insomnia severity is similar to most users seeking help. With treatment, most see significant improvement.`;
    } else {
      return `Your insomnia severity is higher than average, but people with severe symptoms often see the most dramatic improvements.`;
    }
  }

  if (metricType === "completion_rate") {
    if (percentile > 70) {
      return `You're more engaged than ${percentile}% of users - this dedication leads to better outcomes!`;
    } else if (percentile > 30) {
      return `You're making good progress on your sleep journey. Keep going!`;
    } else {
      return `Every step counts. Users who complete the full assessment see the best results.`;
    }
  }

  return `You're part of a community of thousands working to improve their sleep.`;
}
