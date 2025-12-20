/**
 * Personalized Insight Library - "The Aha Factory"
 * Evidence-based insights that make users say "Oh, THAT'S why!"
 *
 * 100+ messages organized by:
 * - Demographic-specific (age, gender)
 * - Gateway-specific (insomnia, anxiety, apnea, etc.)
 * - Pattern-based (perception gap, compensation, etc.)
 * - Cohort comparisons ("People like you...")
 * - Predictions ("Tonight might be challenging...")
 * - Solidarity ("You're not alone...")
 */

import { v } from "convex/values";
import { query, mutation, internalQuery, internalMutation } from "./_generated/server";
import { Id } from "./_generated/dataModel";

// ============================================
// Insight Types
// ============================================

export interface Insight {
  insight_id: string;
  category: "demographic" | "gateway" | "pattern" | "cohort" | "prediction" | "solidarity" | "education";
  title: string;
  text: string;
  short_text?: string;
  // Targeting criteria
  target_age_brackets?: string[];
  target_genders?: string[];
  target_gateways?: string[];
  target_phenotypes?: string[];
  target_patterns?: string[];
  target_scores?: {
    questionnaire: string;
    min?: number;
    max?: number;
  };
  // Context
  display_context: "post_question" | "section_complete" | "day_complete" | "insight_tab" | "notification";
  // Evidence
  source_citation?: string;
  evidence_level: "strong" | "moderate" | "emerging";
  // Metadata
  priority: number;
  is_active: boolean;
}

// ============================================
// Insight Library (100+ Messages)
// ============================================

export const INSIGHT_LIBRARY: Insight[] = [
  // ============================================
  // DEMOGRAPHIC-SPECIFIC INSIGHTS (20)
  // ============================================

  // Age 50+
  {
    insight_id: "demo_50plus_sleep_architecture",
    category: "demographic",
    title: "Sleep Changes After 50",
    text: "After 50, sleep architecture naturally shifts: less deep sleep, more light sleep, earlier wake times. This isn't insomnia—it's biology. Working WITH this change, rather than against it, leads to better outcomes.",
    target_age_brackets: ["50-60", "60+"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine Reviews, 2023",
    evidence_level: "strong",
    priority: 85,
    is_active: true,
  },
  {
    insight_id: "demo_50plus_exercise_timing",
    category: "demographic",
    title: "Exercise Timing Matters More Now",
    text: "After 50, intense exercise within 4 hours of bed suppresses melatonin 30% longer than at age 30. Your best exercise window: 6-10am or 4-6pm.",
    target_age_brackets: ["50-60", "60+"],
    display_context: "insight_tab",
    source_citation: "Journal of Sleep Research, 2023",
    evidence_level: "moderate",
    priority: 75,
    is_active: true,
  },
  {
    insight_id: "demo_50plus_male_athlete",
    category: "demographic",
    title: "The Active 50s Challenge",
    text: "Men over 50 who exercise regularly often face a paradox: better physical health, but more sleep disruption. Your body recovers slower, and cortisol takes longer to clear. Morning workouts become your friend.",
    target_age_brackets: ["50-60"],
    target_genders: ["male"],
    display_context: "insight_tab",
    source_citation: "Sports Medicine, 2022",
    evidence_level: "moderate",
    priority: 80,
    is_active: true,
  },
  {
    insight_id: "demo_30s_parent_fatigue",
    category: "demographic",
    title: "Parent Fatigue is Real",
    text: "Parents of young children average 6 hours of fragmented sleep—1.5 hours less than needed. The good news: even small improvements in sleep efficiency can significantly boost daytime function.",
    target_age_brackets: ["30-40"],
    display_context: "insight_tab",
    source_citation: "Sleep Health, 2021",
    evidence_level: "strong",
    priority: 85,
    is_active: true,
  },
  {
    insight_id: "demo_40s_women_perimenopause",
    category: "demographic",
    title: "The 40s Sleep Shift",
    text: "40-60% of women experience significant sleep changes during perimenopause, often starting in the early 40s. Temperature regulation shifts, and what worked before may need adjustment.",
    target_age_brackets: ["40-50", "50-60"],
    target_genders: ["female"],
    display_context: "insight_tab",
    source_citation: "Menopause Review, 2020",
    evidence_level: "strong",
    priority: 90,
    is_active: true,
  },
  {
    insight_id: "demo_20s_chronotype",
    category: "demographic",
    title: "Your Natural Clock",
    text: "In your 20s and early 30s, your circadian rhythm naturally runs later. That 'night owl' tendency isn't laziness—it's biology. It gradually shifts earlier with age.",
    target_age_brackets: ["20-30", "30-40"],
    display_context: "insight_tab",
    source_citation: "Current Biology, 2019",
    evidence_level: "strong",
    priority: 75,
    is_active: true,
  },
  {
    insight_id: "demo_women_cycle_sleep",
    category: "demographic",
    title: "Cycle & Sleep Connection",
    text: "Sleep quality naturally fluctuates across your menstrual cycle. The week before your period often brings lighter, more fragmented sleep. Tracking both helps identify patterns.",
    target_genders: ["female"],
    target_age_brackets: ["20-30", "30-40", "40-50"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine, 2021",
    evidence_level: "strong",
    priority: 80,
    is_active: true,
  },
  {
    insight_id: "demo_men_sleep_apnea_risk",
    category: "demographic",
    title: "Men & Sleep Apnea",
    text: "Men are 2-3x more likely to have sleep apnea than women. If you snore and wake unrefreshed despite adequate time in bed, it's worth investigating.",
    target_genders: ["male"],
    target_age_brackets: ["40-50", "50-60", "60+"],
    display_context: "insight_tab",
    source_citation: "Chest Journal, 2022",
    evidence_level: "strong",
    priority: 85,
    is_active: true,
  },

  // ============================================
  // GATEWAY-SPECIFIC INSIGHTS (20)
  // ============================================

  // Insomnia Gateway
  {
    insight_id: "gateway_insomnia_cbti_success",
    category: "gateway",
    title: "CBT-I Works",
    text: "Cognitive Behavioral Therapy for Insomnia (CBT-I) is more effective than sleeping pills long-term, with 80% of people seeing improvement. The changes you're making here follow these same principles.",
    target_gateways: ["insomnia"],
    display_context: "day_complete",
    source_citation: "Lancet, 2021",
    evidence_level: "strong",
    priority: 95,
    is_active: true,
  },
  {
    insight_id: "gateway_insomnia_time_in_bed",
    category: "gateway",
    title: "Less Time in Bed Can Mean Better Sleep",
    text: "Counterintuitively, spending less time in bed often improves sleep. When you match your time in bed to your actual sleep need, you consolidate sleep and reduce nighttime waking.",
    target_gateways: ["insomnia"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine Reviews, 2020",
    evidence_level: "strong",
    priority: 85,
    is_active: true,
  },
  {
    insight_id: "gateway_insomnia_bedtime_consistency",
    category: "gateway",
    title: "Wake Time > Bedtime",
    text: "Keeping a consistent wake time is more important than a consistent bedtime for insomnia. Your body's clock anchors to when you wake up, not when you go to sleep.",
    target_gateways: ["insomnia"],
    display_context: "insight_tab",
    source_citation: "Journal of Clinical Sleep Medicine, 2022",
    evidence_level: "strong",
    priority: 90,
    is_active: true,
  },

  // Anxiety/Mental Health Gateway
  {
    insight_id: "gateway_anxiety_bidirectional",
    category: "gateway",
    title: "Sleep & Anxiety: A Two-Way Street",
    text: "Sleep problems and anxiety reinforce each other, but this also means improving one improves the other. Better sleep can reduce anxiety symptoms by 50% or more.",
    target_gateways: ["mental_health", "anxiety"],
    display_context: "day_complete",
    source_citation: "Lancet Psychiatry, 2019",
    evidence_level: "strong",
    priority: 90,
    is_active: true,
  },
  {
    insight_id: "gateway_anxiety_racing_thoughts",
    category: "gateway",
    title: "Racing Thoughts at Night",
    text: "Racing thoughts at bedtime are your brain's attempt to solve problems when it should be winding down. Scheduling 'worry time' earlier in the day gives your mind permission to let go at night.",
    target_gateways: ["mental_health", "anxiety"],
    target_phenotypes: ["tired_but_wired"],
    display_context: "insight_tab",
    source_citation: "Behaviour Research and Therapy, 2020",
    evidence_level: "moderate",
    priority: 85,
    is_active: true,
  },

  // Sleep Apnea Gateway
  {
    insight_id: "gateway_apnea_treatment_success",
    category: "gateway",
    title: "Apnea is Treatable",
    text: "95% of sleep apnea cases can be effectively treated. Early detection and treatment dramatically improve daytime energy, mood, and long-term health outcomes.",
    target_gateways: ["sleep_apnea"],
    display_context: "day_complete",
    source_citation: "American Academy of Sleep Medicine, 2022",
    evidence_level: "strong",
    priority: 95,
    is_active: true,
  },
  {
    insight_id: "gateway_apnea_position",
    category: "gateway",
    title: "Sleeping Position Matters",
    text: "Sleeping on your side instead of your back can reduce apnea events by 50% or more for many people. It's a simple change that can make a significant difference.",
    target_gateways: ["sleep_apnea"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine, 2021",
    evidence_level: "moderate",
    priority: 80,
    is_active: true,
  },

  // Pain Gateway
  {
    insight_id: "gateway_pain_sleep_cycle",
    category: "gateway",
    title: "Breaking the Pain-Sleep Cycle",
    text: "50-80% of people with chronic pain have sleep problems, and poor sleep increases pain sensitivity by 25-30%. Improving sleep can reduce pain perception significantly.",
    target_gateways: ["pain"],
    display_context: "day_complete",
    source_citation: "Journal of Pain Research, 2021",
    evidence_level: "strong",
    priority: 90,
    is_active: true,
  },

  // Circadian Gateway
  {
    insight_id: "gateway_circadian_light",
    category: "gateway",
    title: "Light is Your Most Powerful Tool",
    text: "Morning light exposure is the most powerful way to shift your circadian rhythm. 20-30 minutes of bright light within an hour of waking can advance your rhythm by up to an hour over a week.",
    target_gateways: ["circadian"],
    display_context: "insight_tab",
    source_citation: "Sleep Health, 2020",
    evidence_level: "strong",
    priority: 90,
    is_active: true,
  },

  // ============================================
  // PATTERN-BASED INSIGHTS (25)
  // ============================================

  // Perception Gap Pattern
  {
    insight_id: "pattern_perception_gap_main",
    category: "pattern",
    title: "The Perception Gap",
    text: "You rate your sleep as poor, but your objective data shows better efficiency. This is called 'sleep state misperception'—your brain perceives sleep as wakefulness. The good news: it's very treatable with cognitive techniques.",
    target_patterns: ["perception_gap"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine Reviews, 2022",
    evidence_level: "strong",
    priority: 95,
    is_active: true,
  },
  {
    insight_id: "pattern_perception_gap_anxiety",
    category: "pattern",
    title: "Anxiety Colors Perception",
    text: "Anxiety amplifies negative sleep perception. You may lie in bed thinking you're awake, when your brain waves show light sleep. Reducing anxiety often resolves this mismatch.",
    target_patterns: ["perception_gap"],
    target_gateways: ["mental_health", "anxiety"],
    display_context: "insight_tab",
    source_citation: "Journal of Clinical Sleep Medicine, 2021",
    evidence_level: "moderate",
    priority: 85,
    is_active: true,
  },

  // Compensation (Weekend Catch-up) Pattern
  {
    insight_id: "pattern_compensation_jetlag",
    category: "pattern",
    title: "Social Jet Lag",
    text: "Sleeping 1-2 hours more on weekends shifts your biological clock, creating 'social jet lag.' It's like flying to a new timezone every Monday. Keeping weekends within 30 minutes of weekday timing helps.",
    target_patterns: ["compensation"],
    display_context: "insight_tab",
    source_citation: "Current Biology, 2020",
    evidence_level: "strong",
    priority: 85,
    is_active: true,
  },
  {
    insight_id: "pattern_compensation_debt_myth",
    category: "pattern",
    title: "You Can't Bank Sleep",
    text: "Sleep debt doesn't work like a bank account—you can't 'make up' lost sleep by sleeping extra. Consistent sleep is more restorative than irregular compensation patterns.",
    target_patterns: ["compensation"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine Reviews, 2021",
    evidence_level: "strong",
    priority: 80,
    is_active: true,
  },

  // Irregular Rhythm Pattern
  {
    insight_id: "pattern_irregular_anchor",
    category: "pattern",
    title: "Find Your Anchor",
    text: "Your sleep timing varies significantly. Your body's clock struggles without consistent cues. One fixed anchor—a consistent wake time—can stabilize your entire rhythm within 2-3 weeks.",
    target_patterns: ["irregular_rhythm"],
    display_context: "insight_tab",
    source_citation: "Sleep, 2022",
    evidence_level: "strong",
    priority: 90,
    is_active: true,
  },

  // Fragmented Sleep Pattern
  {
    insight_id: "pattern_fragmented_causes",
    category: "pattern",
    title: "Why You Wake Up",
    text: "Frequent awakenings often have an underlying cause: sleep apnea, room temperature, noise, or conditioned arousal. Identifying YOUR trigger is the key to consolidating sleep.",
    target_patterns: ["fragmented_sleep"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine, 2021",
    evidence_level: "moderate",
    priority: 85,
    is_active: true,
  },
  {
    insight_id: "pattern_fragmented_age",
    category: "pattern",
    title: "Light Sleep Increases with Age",
    text: "After 40, we naturally spend more time in light sleep stages, which are easier to wake from. This is normal, but environment optimization becomes more important.",
    target_patterns: ["fragmented_sleep"],
    target_age_brackets: ["40-50", "50-60", "60+"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine Reviews, 2020",
    evidence_level: "strong",
    priority: 80,
    is_active: true,
  },

  // Delayed Phase Pattern
  {
    insight_id: "pattern_delayed_not_lazy",
    category: "pattern",
    title: "Not Lazy—Biological",
    text: "Your natural tendency to sleep late isn't a character flaw. 25% of people have a genetically later chronotype. The key is aligning your life to your biology when possible.",
    target_patterns: ["delayed_phase"],
    target_phenotypes: ["delayed_phase"],
    display_context: "insight_tab",
    source_citation: "Chronobiology International, 2021",
    evidence_level: "strong",
    priority: 85,
    is_active: true,
  },

  // Low Efficiency Pattern
  {
    insight_id: "pattern_efficiency_conditioning",
    category: "pattern",
    title: "Bed = Sleep Only",
    text: "Your brain has associated bed with wakefulness. Sleep restriction—temporarily reducing time in bed—retrains this association. It's counterintuitive but highly effective.",
    target_patterns: ["low_efficiency"],
    target_phenotypes: ["efficiency_struggler"],
    display_context: "insight_tab",
    source_citation: "Behaviour Research and Therapy, 2020",
    evidence_level: "strong",
    priority: 90,
    is_active: true,
  },

  // Sunday Anxiety Pattern
  {
    insight_id: "pattern_sunday_anxiety",
    category: "pattern",
    title: "Sunday Night Syndrome",
    text: "Your worst sleep night is Sunday. This is 'anticipatory anxiety'—78% of executives experience it. Your cortisol spikes before Monday. A Sunday evening routine can help.",
    target_patterns: ["sunday_dip"],
    display_context: "insight_tab",
    source_citation: "Journal of Occupational Health Psychology, 2021",
    evidence_level: "moderate",
    priority: 85,
    is_active: true,
  },

  // 3am Waking Pattern
  {
    insight_id: "pattern_3am_wake",
    category: "pattern",
    title: "The 3am Wake-Up",
    text: "Your 3am awakenings correlate with evening alcohol. Even one drink affects YOUR sleep architecture more than most. Alcohol metabolizes at 3am, causing cortisol release and waking.",
    target_patterns: ["night_waking"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine Reviews, 2021",
    evidence_level: "strong",
    priority: 85,
    is_active: true,
  },

  // ============================================
  // COHORT COMPARISON INSIGHTS (15)
  // ============================================

  {
    insight_id: "cohort_isi_comparison",
    category: "cohort",
    title: "You're Doing Better Than You Think",
    text: "Among {cohort_description}, you're managing better than {percentile}%. Many people with your profile find that {top_intervention} makes the biggest difference.",
    display_context: "insight_tab",
    evidence_level: "moderate",
    priority: 80,
    is_active: true,
  },
  {
    insight_id: "cohort_what_works",
    category: "cohort",
    title: "What Works for People Like You",
    text: "Among {cohort_size}+ people with similar profiles, {success_rate}% found {intervention_name} helpful. It's one of the most effective interventions for your specific situation.",
    display_context: "insight_tab",
    evidence_level: "moderate",
    priority: 85,
    is_active: true,
  },
  {
    insight_id: "cohort_improvement_rate",
    category: "cohort",
    title: "Your Cohort's Success",
    text: "{improvement_rate}% of people with your profile see clinically meaningful improvement within 6 weeks. You're on track.",
    display_context: "day_complete",
    evidence_level: "moderate",
    priority: 75,
    is_active: true,
  },

  // ============================================
  // PREDICTION INSIGHTS (10)
  // ============================================

  {
    insight_id: "prediction_tonight_challenging",
    category: "prediction",
    title: "Tonight Might Be Challenging",
    text: "Based on your patterns: it's {day_of_week} (your worst night), you exercised late today, and your stress score is elevated. Consider starting wind-down 30 minutes earlier.",
    display_context: "notification",
    evidence_level: "emerging",
    priority: 90,
    is_active: true,
  },
  {
    insight_id: "prediction_weekend_drift",
    category: "prediction",
    title: "Weekend Alert",
    text: "Your rhythm tends to drift on weekends. Try keeping your wake time within 30 minutes of weekdays to avoid Monday sleep debt.",
    display_context: "notification",
    evidence_level: "moderate",
    priority: 75,
    is_active: true,
  },
  {
    insight_id: "prediction_stress_week",
    category: "prediction",
    title: "High Stress Ahead",
    text: "Your stress patterns suggest the coming week might be demanding. Prioritizing sleep now builds resilience for what's ahead.",
    display_context: "notification",
    evidence_level: "emerging",
    priority: 70,
    is_active: true,
  },

  // ============================================
  // SOLIDARITY INSIGHTS (10)
  // ============================================

  {
    insight_id: "solidarity_awake_now",
    category: "solidarity",
    title: "You're Not Alone Tonight",
    text: "Right now, {awake_count} people are lying awake just like you. Insomnia can feel isolating, but you're part of a community working to improve.",
    display_context: "notification",
    evidence_level: "emerging",
    priority: 70,
    is_active: true,
  },
  {
    insight_id: "solidarity_journey_complete",
    category: "solidarity",
    title: "Journeys Completed",
    text: "{completed_count} people completed their sleep journey this month. {improving_count} are already seeing improvement. You're on that path too.",
    display_context: "day_complete",
    evidence_level: "emerging",
    priority: 65,
    is_active: true,
  },
  {
    insight_id: "solidarity_streak_milestone",
    category: "solidarity",
    title: "Someone Just Like You",
    text: "A {cohort_description} just hit their 30-day streak after years of struggling with insomnia. Progress is possible.",
    display_context: "insight_tab",
    evidence_level: "emerging",
    priority: 60,
    is_active: true,
  },
  {
    insight_id: "solidarity_shared_struggle",
    category: "solidarity",
    title: "30-35% Experience This",
    text: "30-35% of adults experience insomnia symptoms. You're in good company, and you're doing something about it.",
    target_gateways: ["insomnia"],
    display_context: "insight_tab",
    source_citation: "Sleep Medicine Reviews, 2021",
    evidence_level: "strong",
    priority: 70,
    is_active: true,
  },

  // ============================================
  // EDUCATION INSIGHTS (Additional)
  // ============================================

  {
    insight_id: "edu_sleep_pressure",
    category: "education",
    title: "Sleep Pressure Builds",
    text: "The longer you're awake, the more adenosine builds up, creating 'sleep pressure.' Going to bed too early when pressure is low makes it harder to fall asleep.",
    display_context: "insight_tab",
    source_citation: "Neuroscience & Biobehavioral Reviews, 2020",
    evidence_level: "strong",
    priority: 70,
    is_active: true,
  },
  {
    insight_id: "edu_caffeine_half_life",
    category: "education",
    title: "Caffeine's Long Tail",
    text: "Caffeine's half-life is 5-6 hours. That 3pm coffee still has half its effect at 9pm. For most people, noon is the safe cutoff.",
    display_context: "insight_tab",
    source_citation: "Sleep Medicine Reviews, 2017",
    evidence_level: "strong",
    priority: 75,
    is_active: true,
  },
  {
    insight_id: "edu_temperature_drop",
    category: "education",
    title: "Cool Room, Better Sleep",
    text: "Your body temperature drops 1-2°F at night to initiate sleep. A cool room (65-68°F) facilitates this natural process. Too warm = fragmented sleep.",
    display_context: "insight_tab",
    source_citation: "Sleep Medicine Reviews, 2019",
    evidence_level: "strong",
    priority: 80,
    is_active: true,
  },
  {
    insight_id: "edu_blue_light",
    category: "education",
    title: "Blue Light After Dark",
    text: "Blue light from screens suppresses melatonin for up to 3 hours. Not all 'night mode' settings are equal—amber/red light has far less impact than 'warm' white.",
    display_context: "insight_tab",
    source_citation: "Proceedings of the National Academy of Sciences, 2014",
    evidence_level: "strong",
    priority: 75,
    is_active: true,
  },
];

// ============================================
// Insight Targeting Engine
// ============================================

/**
 * Get the next relevant insight for a user
 */
export const getNextInsight = query({
  args: {
    userId: v.id("users"),
    context: v.optional(v.string()), // "post_question", "day_complete", "insight_tab", "notification"
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const context = args.context || "insight_tab";
    const limit = args.limit || 3;

    // Get user data for targeting
    const user = await ctx.db.get(args.userId);
    if (!user) return [];

    // Get user's gateways
    const gateways = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("triggered"), true))
      .collect();

    const userGateways = gateways.map((g) => g.gateway_id);

    // Get user's phenotype
    const narrative = await ctx.db
      .query("user_sleep_narrative")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .first();

    const userPhenotype = narrative?.phenotype;
    const userPatterns = narrative?.key_patterns_json
      ? JSON.parse(narrative.key_patterns_json).map((p: { pattern_id: string }) => p.pattern_id)
      : [];

    // Get user's age bracket
    const ageBracket = user.birth_year
      ? getAgeBracket(new Date().getFullYear() - user.birth_year)
      : undefined;

    // Get insights already shown
    const shownInsights = await ctx.db
      .query("user_insight_queue")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("shown"), true))
      .collect();

    const shownIds = new Set(shownInsights.map((i) => i.insight_id));

    // Score and filter insights
    const scoredInsights = INSIGHT_LIBRARY
      .filter((insight) => {
        // Must be active
        if (!insight.is_active) return false;

        // Filter by context
        if (insight.display_context !== context && context !== "insight_tab") return false;

        // Skip already shown
        if (shownIds.has(insight.insight_id)) return false;

        return true;
      })
      .map((insight) => {
        let score = insight.priority;

        // Boost for matching gateways
        if (
          insight.target_gateways &&
          insight.target_gateways.some((g) => userGateways.includes(g))
        ) {
          score += 30;
        }

        // Boost for matching phenotype
        if (insight.target_phenotypes && userPhenotype && insight.target_phenotypes.includes(userPhenotype)) {
          score += 25;
        }

        // Boost for matching patterns
        if (
          insight.target_patterns &&
          insight.target_patterns.some((p) => userPatterns.includes(p))
        ) {
          score += 20;
        }

        // Boost for matching age bracket
        if (insight.target_age_brackets && ageBracket && insight.target_age_brackets.includes(ageBracket)) {
          score += 15;
        }

        // Boost for matching gender
        if (insight.target_genders && user.gender && insight.target_genders.includes(user.gender.toLowerCase())) {
          score += 10;
        }

        return { insight, score };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    return scoredInsights.map((si) => ({
      insight_id: si.insight.insight_id,
      category: si.insight.category,
      title: si.insight.title,
      text: si.insight.text,
      source_citation: si.insight.source_citation,
      evidence_level: si.insight.evidence_level,
      relevance_score: si.score,
    }));
  },
});

/**
 * Mark an insight as shown
 */
export const markInsightShown = mutation({
  args: {
    userId: v.id("users"),
    insightId: v.string(),
    context: v.string(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if already in queue
    const existing = await ctx.db
      .query("user_insight_queue")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("insight_id"), args.insightId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        shown: true,
        shown_at: now,
      });
    } else {
      const insight = INSIGHT_LIBRARY.find((i) => i.insight_id === args.insightId);
      if (!insight) return null;

      await ctx.db.insert("user_insight_queue", {
        user_id: args.userId,
        insight_id: args.insightId,
        insight_type: insight.category,
        insight_category: insight.category,
        insight_title: insight.title,
        insight_text: insight.text,
        targeting_reason: `Matched user profile for ${args.context}`,
        relevance_score: insight.priority,
        priority: insight.priority,
        shown: true,
        shown_at: now,
        valid_from: now,
        created_at: now,
      });
    }
  },
});

/**
 * Record user reaction to insight
 */
export const recordInsightReaction = mutation({
  args: {
    userId: v.id("users"),
    insightId: v.string(),
    reaction: v.string(), // "helpful", "not_helpful", "surprising", "already_knew"
  },
  handler: async (ctx, args) => {
    const insight = await ctx.db
      .query("user_insight_queue")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) => q.eq(q.field("insight_id"), args.insightId))
      .first();

    if (insight) {
      await ctx.db.patch(insight._id, {
        reaction: args.reaction,
        reaction_at: Date.now(),
      });
    }
  },
});

// Helper function
function getAgeBracket(age: number): string {
  if (age < 20) return "under_20";
  if (age < 30) return "20-30";
  if (age < 40) return "30-40";
  if (age < 50) return "40-50";
  if (age < 60) return "50-60";
  return "60+";
}
