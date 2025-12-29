/**
 * Sleep Phenotype Classification System - "The Mirror"
 * Creates personalized sleep narratives that make users feel understood
 *
 * Phenotypes:
 * - tired_but_wired: High anxiety/stress + difficulty falling asleep
 * - sleep_state_misperception: Subjective quality much worse than objective
 * - compensator: Weekend sleep-ins to "catch up"
 * - irregular_rhythm: High variability in sleep timing
 * - fragmented_sleeper: Frequent nighttime awakenings
 * - early_terminator: Wakes too early, can't return to sleep
 * - delayed_phase: Natural night owl struggling with early demands
 * - short_sleeper: Consistently <6 hours but functional
 * - efficiency_struggler: Long time in bed, low efficiency
 */

import { v } from "convex/values";
import { query, mutation, internalQuery, internalMutation, QueryCtx, MutationCtx } from "./_generated/server";
import { Id, Doc } from "./_generated/dataModel";

// ============================================
// Types
// ============================================

export interface SleepPattern {
  pattern_id: string;
  pattern_name: string;
  description: string;
  evidence: string[];
  confidence: number; // 0-100
  data_points: number;
}

export interface PhenotypeClassification {
  primary_phenotype: string;
  secondary_phenotype?: string;
  confidence: number;
  patterns: SleepPattern[];
  leverage_points: LeveragePoint[];
}

export interface LeveragePoint {
  intervention_type: string;
  reason: string;
  priority: number;
  evidence_strength: string;
}

// ============================================
// Phenotype Definitions
// ============================================

const PHENOTYPE_DEFINITIONS: Record<
  string,
  {
    name: string;
    title: string;
    description: string;
    typical_profile: string;
    leverage_interventions: string[];
  }
> = {
  tired_but_wired: {
    name: "Tired but Wired",
    title: "The Tired but Wired Sleeper",
    description:
      "Your body wants to sleep, but your mind races at night. This is common in high-achievers and those with demanding responsibilities.",
    typical_profile:
      "Often seen in executives, parents of young children, and those with anxiety-related gateways.",
    leverage_interventions: [
      "cognitive_wind_down",
      "worry_time",
      "relaxation_techniques",
      "stimulus_control",
    ],
  },
  sleep_state_misperception: {
    name: "Sleep State Misperception",
    title: "The Perception Gap Sleeper",
    description:
      "You rate your sleep worse than it actually is. Your objective data shows better efficiency than you perceive. This affects 30-50% of insomnia patients and is very treatable.",
    typical_profile:
      "Common in those with anxiety gateways or perfectionist tendencies.",
    leverage_interventions: [
      "cognitive_restructuring",
      "sleep_data_review",
      "perception_reframing",
    ],
  },
  compensator: {
    name: "Compensator",
    title: "The Weekend Warrior Sleeper",
    description:
      "You try to 'catch up' on sleep during weekends, sleeping 1-2+ hours longer. This creates 'social jet lag' that disrupts your rhythm.",
    typical_profile:
      "Typical for working professionals with demanding weekday schedules.",
    leverage_interventions: [
      "fixed_wake_time",
      "weekend_consistency",
      "sleep_debt_education",
    ],
  },
  irregular_rhythm: {
    name: "Irregular Rhythm",
    title: "The Variable Schedule Sleeper",
    description:
      "Your sleep timing varies significantly from night to night. Your body's clock struggles to find a consistent pattern.",
    typical_profile:
      "Common in shift workers, parents of infants, and those with variable work schedules.",
    leverage_interventions: [
      "anchor_wake_time",
      "light_therapy",
      "circadian_stabilization",
    ],
  },
  fragmented_sleeper: {
    name: "Fragmented Sleeper",
    title: "The Light Sleeper",
    description:
      "You wake up multiple times during the night. Even if you get enough total hours, the fragmentation reduces sleep quality.",
    typical_profile:
      "More common with age, in those with pain conditions, or sleep apnea risk.",
    leverage_interventions: [
      "sleep_environment",
      "noise_management",
      "temperature_optimization",
      "apnea_screening",
    ],
  },
  early_terminator: {
    name: "Early Terminator",
    title: "The Early Riser (Not By Choice)",
    description:
      "You wake up earlier than desired and can't fall back asleep. This robs you of the final sleep cycles.",
    typical_profile:
      "Often associated with depression, advanced age, or advanced circadian phase.",
    leverage_interventions: [
      "light_management",
      "delayed_morning_light",
      "mood_assessment",
    ],
  },
  delayed_phase: {
    name: "Delayed Phase",
    title: "The Natural Night Owl",
    description:
      "Your biological clock is set later than society demands. You're fighting your nature, not lacking discipline.",
    typical_profile:
      "Genetic component; 25% of population has this chronotype. Common in younger adults.",
    leverage_interventions: [
      "morning_light_therapy",
      "chronotherapy",
      "schedule_alignment",
    ],
  },
  short_sleeper: {
    name: "Short Sleeper",
    title: "The Efficient Sleeper",
    description:
      "You consistently sleep less than 7 hours but maintain good daytime function. You may be a natural short sleeper.",
    typical_profile:
      "Rare genetic variant (~1-3% of population). Most who think they are, aren't.",
    leverage_interventions: [
      "validate_efficiency",
      "quality_focus",
      "daytime_alertness_check",
    ],
  },
  efficiency_struggler: {
    name: "Efficiency Struggler",
    title: "The Time-in-Bed Struggler",
    description:
      "You spend a long time in bed but actually sleep much less. Your sleep efficiency is below optimal.",
    typical_profile:
      "Common pattern in chronic insomnia. Often involves conditioned arousal.",
    leverage_interventions: [
      "sleep_restriction",
      "stimulus_control",
      "bed_reassociation",
    ],
  },
};

// ============================================
// Pattern Detection Functions
// ============================================

/**
 * Helper function to detect all patterns from user's sleep data
 * This is extracted to avoid self-referential internal API calls during bootstrap
 */
async function detectSleepPatternsHelper(ctx: QueryCtx, userId: Id<"users">): Promise<SleepPattern[]> {
  const patterns: SleepPattern[] = [];

  // Get user data
  const user = await ctx.db.get(userId);
  if (!user) return patterns;

  // Get sleep data (last 14 days)
  const sleepData = await ctx.db
    .query("user_sleep_data")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .order("desc")
    .take(14);

  // Get perception gaps
  const perceptionGaps = await ctx.db
    .query("perception_gaps")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .order("desc")
    .take(14);

  // Get gateway states
  const gateways = await ctx.db
    .query("user_gateway_states")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .filter((q) => q.eq(q.field("triggered"), true))
    .collect();

  // Get questionnaire responses
  const responses = await ctx.db
    .query("user_assessment_responses")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .collect();

  const responseMap = new Map(responses.map((r) => [r.question_id, r]));

  if (sleepData.length < 5) {
    return patterns; // Not enough data
  }

  // Pattern 1: Sleep State Misperception
  const gapPattern = detectPerceptionGapPattern(perceptionGaps);
  if (gapPattern) patterns.push(gapPattern);

  // Pattern 2: Weekend Compensation (Social Jet Lag)
  const compensationPattern = detectCompensationPattern(sleepData);
  if (compensationPattern) patterns.push(compensationPattern);

  // Pattern 3: Irregular Rhythm
  const irregularPattern = detectIrregularPattern(sleepData);
  if (irregularPattern) patterns.push(irregularPattern);

  // Pattern 4: Sleep Fragmentation
  const fragmentationPattern = detectFragmentationPattern(sleepData);
  if (fragmentationPattern) patterns.push(fragmentationPattern);

  // Pattern 5: Early Morning Awakening
  const earlyWakePattern = detectEarlyWakePattern(sleepData, responseMap);
  if (earlyWakePattern) patterns.push(earlyWakePattern);

  // Pattern 6: Delayed Phase
  const delayedPattern = detectDelayedPhasePattern(sleepData);
  if (delayedPattern) patterns.push(delayedPattern);

  // Pattern 7: Low Sleep Efficiency
  const efficiencyPattern = detectEfficiencyPattern(sleepData);
  if (efficiencyPattern) patterns.push(efficiencyPattern);

  // Pattern 8: Anxiety-Driven Insomnia
  const anxietyPattern = detectAnxietyPattern(gateways, responseMap);
  if (anxietyPattern) patterns.push(anxietyPattern);

  return patterns;
}

/**
 * Detect all patterns from user's sleep data
 */
export const detectSleepPatterns = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, args): Promise<SleepPattern[]> => {
    return detectSleepPatternsHelper(ctx, args.userId);
  },
});

/**
 * Helper function to classify sleep phenotype
 * Extracted to avoid self-referential internal API calls during bootstrap
 */
async function classifySleepPhenotypeHelper(ctx: QueryCtx, userId: Id<"users">): Promise<PhenotypeClassification | null> {
  // Get detected patterns using helper directly
  const patterns = await detectSleepPatternsHelper(ctx, userId);

  if (patterns.length === 0) {
    return null;
  }

  // Score each phenotype based on matching patterns
  const phenotypeScores: Map<string, number> = new Map();

  for (const pattern of patterns) {
    switch (pattern.pattern_id) {
      case "perception_gap":
        addScore(phenotypeScores, "sleep_state_misperception", pattern.confidence);
        break;
      case "compensation":
        addScore(phenotypeScores, "compensator", pattern.confidence);
        break;
      case "irregular_rhythm":
        addScore(phenotypeScores, "irregular_rhythm", pattern.confidence);
        break;
      case "fragmented_sleep":
        addScore(phenotypeScores, "fragmented_sleeper", pattern.confidence);
        break;
      case "early_termination":
        addScore(phenotypeScores, "early_terminator", pattern.confidence);
        break;
      case "delayed_phase":
        addScore(phenotypeScores, "delayed_phase", pattern.confidence);
        break;
      case "low_efficiency":
        addScore(phenotypeScores, "efficiency_struggler", pattern.confidence);
        break;
      case "anxiety_driven":
        addScore(phenotypeScores, "tired_but_wired", pattern.confidence * 1.2); // Boost for anxiety
        break;
    }
  }

  // Find top phenotypes
  const sortedPhenotypes = [...phenotypeScores.entries()].sort((a, b) => b[1] - a[1]);

  if (sortedPhenotypes.length === 0) {
    return null;
  }

  const [primaryId, primaryScore] = sortedPhenotypes[0];
  const secondary =
    sortedPhenotypes.length > 1 && sortedPhenotypes[1][1] > 40
      ? sortedPhenotypes[1][0]
      : undefined;

  // Build leverage points based on primary phenotype
  const leveragePoints = buildLeveragePoints(primaryId, patterns);

  return {
    primary_phenotype: primaryId,
    secondary_phenotype: secondary,
    confidence: Math.min(95, primaryScore),
    patterns,
    leverage_points: leveragePoints,
  };
}

// Pattern detection helpers
function detectPerceptionGapPattern(gaps: Doc<"perception_gaps">[]): SleepPattern | null {
  if (gaps.length < 5) return null;

  const significantGaps = gaps.filter(
    (g) =>
      g.subjective_quality !== undefined &&
      g.objective_efficiency !== undefined &&
      g.subjective_quality <= 5 && // Poor subjective
      g.objective_efficiency >= 80 // Good objective
  );

  if (significantGaps.length >= 3) {
    const avgSubjective =
      significantGaps.reduce((s, g) => s + (g.subjective_quality || 0), 0) /
      significantGaps.length;
    const avgObjective =
      significantGaps.reduce((s, g) => s + (g.objective_efficiency || 0), 0) /
      significantGaps.length;

    return {
      pattern_id: "perception_gap",
      pattern_name: "Perception Gap",
      description: `You rate your sleep ${avgSubjective.toFixed(1)}/10 but your efficiency is ${avgObjective.toFixed(0)}%`,
      evidence: [
        `${significantGaps.length} nights with perception mismatch`,
        `Average subjective: ${avgSubjective.toFixed(1)}/10`,
        `Average objective efficiency: ${avgObjective.toFixed(0)}%`,
      ],
      confidence: Math.min(90, significantGaps.length * 15),
      data_points: significantGaps.length,
    };
  }

  return null;
}

function detectCompensationPattern(sleepData: Doc<"user_sleep_data">[]): SleepPattern | null {
  // Separate weekend vs weekday sleep
  const weekdaySleep: number[] = [];
  const weekendSleep: number[] = [];

  for (const d of sleepData) {
    if (!d.total_sleep_mins || !d.date) continue;

    const date = new Date(d.date);
    const dayOfWeek = date.getDay();
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;

    if (isWeekend) {
      weekendSleep.push(d.total_sleep_mins);
    } else {
      weekdaySleep.push(d.total_sleep_mins);
    }
  }

  if (weekdaySleep.length < 3 || weekendSleep.length < 2) return null;

  const avgWeekday = weekdaySleep.reduce((a, b) => a + b, 0) / weekdaySleep.length;
  const avgWeekend = weekendSleep.reduce((a, b) => a + b, 0) / weekendSleep.length;
  const difference = avgWeekend - avgWeekday;

  // Significant if weekend is 45+ minutes more
  if (difference >= 45) {
    return {
      pattern_id: "compensation",
      pattern_name: "Weekend Compensation",
      description: `You sleep ${Math.round(difference)} minutes more on weekends`,
      evidence: [
        `Weekday average: ${Math.round(avgWeekday / 60)}h ${Math.round(avgWeekday % 60)}m`,
        `Weekend average: ${Math.round(avgWeekend / 60)}h ${Math.round(avgWeekend % 60)}m`,
        "This creates 'social jet lag'",
      ],
      confidence: Math.min(85, Math.round((difference / 60) * 30)),
      data_points: weekdaySleep.length + weekendSleep.length,
    };
  }

  return null;
}

function detectIrregularPattern(sleepData: Doc<"user_sleep_data">[]): SleepPattern | null {
  // Calculate variability in sleep onset time
  const sleepOnsets: number[] = [];

  for (const d of sleepData) {
    if (!d.asleep_time) continue;

    const date = new Date(d.asleep_time * 1000);
    let hours = date.getHours() + date.getMinutes() / 60;
    if (hours < 12) hours += 24; // Normalize around midnight
    sleepOnsets.push(hours);
  }

  if (sleepOnsets.length < 5) return null;

  const mean = sleepOnsets.reduce((a, b) => a + b, 0) / sleepOnsets.length;
  const variance =
    sleepOnsets.reduce((sum, h) => sum + Math.pow(h - mean, 2), 0) / sleepOnsets.length;
  const stdDev = Math.sqrt(variance);

  // Standard deviation > 1.5 hours indicates irregular rhythm
  if (stdDev > 1.5) {
    return {
      pattern_id: "irregular_rhythm",
      pattern_name: "Irregular Sleep Timing",
      description: `Your bedtime varies by ~${Math.round(stdDev * 60)} minutes night to night`,
      evidence: [
        `Sleep onset variability: ±${Math.round(stdDev * 60)} minutes`,
        `Range: ${formatTime(Math.min(...sleepOnsets))} to ${formatTime(Math.max(...sleepOnsets))}`,
        "Consistent timing helps regulate your sleep drive",
      ],
      confidence: Math.min(90, Math.round(stdDev * 30)),
      data_points: sleepOnsets.length,
    };
  }

  return null;
}

function detectFragmentationPattern(sleepData: Doc<"user_sleep_data">[]): SleepPattern | null {
  const fragmented = sleepData.filter(
    (d) => d.interruptions_count !== undefined && d.interruptions_count >= 3
  );

  if (fragmented.length >= 4) {
    const avgInterruptions =
      fragmented.reduce((s, d) => s + (d.interruptions_count || 0), 0) / fragmented.length;

    return {
      pattern_id: "fragmented_sleep",
      pattern_name: "Fragmented Sleep",
      description: `You wake ${avgInterruptions.toFixed(1)} times per night on average`,
      evidence: [
        `${fragmented.length} nights with 3+ awakenings`,
        "Fragmentation reduces restorative deep sleep",
        "Even if total time is adequate, quality suffers",
      ],
      confidence: Math.min(85, fragmented.length * 12),
      data_points: fragmented.length,
    };
  }

  return null;
}

function detectEarlyWakePattern(
  sleepData: Doc<"user_sleep_data">[],
  responseMap: Map<string, Doc<"user_assessment_responses">>
): SleepPattern | null {
  // Check for early morning awakening response
  const earlyWakeResponse = responseMap.get("ISI_EARLY_WAKE");

  // Also check wake times relative to desired
  const earlyWakes = sleepData.filter((d) => {
    if (!d.wake_time) return false;
    const wakeDate = new Date(d.wake_time * 1000);
    const wakeHour = wakeDate.getHours();
    // Waking before 5:30 AM could indicate early termination
    return wakeHour < 5 || (wakeHour === 5 && wakeDate.getMinutes() < 30);
  });

  if (
    earlyWakes.length >= 3 ||
    (earlyWakeResponse?.response_number && earlyWakeResponse.response_number >= 3)
  ) {
    return {
      pattern_id: "early_termination",
      pattern_name: "Early Morning Awakening",
      description: "You tend to wake earlier than desired and can't return to sleep",
      evidence: [
        `${earlyWakes.length} nights with early awakening`,
        "This can indicate phase advancement or mood factors",
        "The last sleep cycles are often the most restorative",
      ],
      confidence: Math.min(80, earlyWakes.length * 15),
      data_points: earlyWakes.length,
    };
  }

  return null;
}

function detectDelayedPhasePattern(sleepData: Doc<"user_sleep_data">[]): SleepPattern | null {
  const sleepOnsets: number[] = [];

  for (const d of sleepData) {
    if (!d.asleep_time) continue;

    const date = new Date(d.asleep_time * 1000);
    let hours = date.getHours() + date.getMinutes() / 60;
    if (hours < 12) hours += 24;
    sleepOnsets.push(hours);
  }

  if (sleepOnsets.length < 5) return null;

  const avgOnset = sleepOnsets.reduce((a, b) => a + b, 0) / sleepOnsets.length;

  // Consistently falling asleep after midnight
  if (avgOnset > 24.5) {
    return {
      pattern_id: "delayed_phase",
      pattern_name: "Delayed Sleep Phase",
      description: `You naturally fall asleep around ${formatTime(avgOnset)}`,
      evidence: [
        `Average sleep onset: ${formatTime(avgOnset)}`,
        "This may be your biological chronotype",
        "25% of people have a naturally later rhythm",
      ],
      confidence: Math.min(85, Math.round((avgOnset - 24) * 40)),
      data_points: sleepOnsets.length,
    };
  }

  return null;
}

function detectEfficiencyPattern(sleepData: Doc<"user_sleep_data">[]): SleepPattern | null {
  const lowEfficiency = sleepData.filter(
    (d) => d.sleep_efficiency !== undefined && d.sleep_efficiency < 80
  );

  if (lowEfficiency.length >= 4) {
    const avgEfficiency =
      lowEfficiency.reduce((s, d) => s + (d.sleep_efficiency || 0), 0) / lowEfficiency.length;

    return {
      pattern_id: "low_efficiency",
      pattern_name: "Low Sleep Efficiency",
      description: `Your sleep efficiency averages ${avgEfficiency.toFixed(0)}%`,
      evidence: [
        `${lowEfficiency.length} nights below 80% efficiency`,
        "Optimal efficiency is 85-90%",
        "Time awake in bed conditions your brain to not sleep",
      ],
      confidence: Math.min(90, lowEfficiency.length * 12),
      data_points: lowEfficiency.length,
    };
  }

  return null;
}

function detectAnxietyPattern(
  gateways: Doc<"user_gateway_states">[],
  responseMap: Map<string, Doc<"user_assessment_responses">>
): SleepPattern | null {
  const hasAnxietyGateway = gateways.some(
    (g) => g.gateway_id === "mental_health" || g.gateway_id === "anxiety"
  );

  // Check GAD-7 or anxiety-related responses
  const gadScore = responseMap.get("GAD7_TOTAL");
  const worryResponse = responseMap.get("D3_RACING_THOUGHTS");

  if (
    hasAnxietyGateway ||
    (gadScore?.response_number && gadScore.response_number >= 10) ||
    (worryResponse?.response_number && worryResponse.response_number >= 3)
  ) {
    return {
      pattern_id: "anxiety_driven",
      pattern_name: "Anxiety-Driven Sleep Difficulty",
      description: "Racing thoughts and worry affect your ability to fall or stay asleep",
      evidence: [
        hasAnxietyGateway ? "Mental health gateway triggered" : "",
        gadScore?.response_number ? `GAD-7 score: ${gadScore.response_number}` : "",
        "Mind-body relaxation techniques are especially effective",
      ].filter(Boolean),
      confidence: 75,
      data_points: 1,
    };
  }

  return null;
}

function formatTime(hours: number): string {
  // Convert 24.5 to "12:30 AM"
  const normalizedHours = hours > 24 ? hours - 24 : hours;
  const h = Math.floor(normalizedHours);
  const m = Math.round((normalizedHours - h) * 60);
  const period = h >= 12 ? "PM" : "AM";
  const displayHour = h > 12 ? h - 12 : h === 0 ? 12 : h;
  return `${displayHour}:${m.toString().padStart(2, "0")} ${period}`;
}

// ============================================
// Phenotype Classification
// ============================================

/**
 * Classify user's sleep phenotype based on detected patterns
 */
export const classifySleepPhenotype = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, args): Promise<PhenotypeClassification | null> => {
    // Use helper function to avoid self-referential internal API calls
    return classifySleepPhenotypeHelper(ctx, args.userId);
  },
});

function addScore(scores: Map<string, number>, phenotype: string, amount: number) {
  const current = scores.get(phenotype) || 0;
  scores.set(phenotype, current + amount);
}

function buildLeveragePoints(phenotype: string, patterns: SleepPattern[]): LeveragePoint[] {
  const definition = PHENOTYPE_DEFINITIONS[phenotype];
  if (!definition) return [];

  return definition.leverage_interventions.map((intervention, index) => ({
    intervention_type: intervention,
    reason: `Key strategy for ${definition.name} sleepers`,
    priority: index + 1,
    evidence_strength: index === 0 ? "strong" : "moderate",
  }));
}

// ============================================
// Narrative Generation
// ============================================

/**
 * Generate personalized sleep narrative
 */
export const generateSleepNarrative = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get user info
    const user = await ctx.db.get(args.userId);
    if (!user) return null;

    // Get phenotype classification using helper to avoid self-referential internal API calls
    const classification = await classifySleepPhenotypeHelper(ctx, args.userId);
    if (!classification) return null;

    const phenotypeDef = PHENOTYPE_DEFINITIONS[classification.primary_phenotype];
    if (!phenotypeDef) return null;

    // Get cohort membership for context
    const cohort = await ctx.db
      .query("user_cohort_memberships")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    // Build narrative text
    let narrativeText = phenotypeDef.description + "\n\n";

    // Add cohort context
    if (cohort) {
      const cohortContext = buildCohortContext(cohort, classification.primary_phenotype);
      if (cohortContext) {
        narrativeText += cohortContext + "\n\n";
      }
    }

    // Add pattern evidence
    if (classification.patterns.length > 0) {
      narrativeText += "Key patterns we've noticed:\n";
      for (const pattern of classification.patterns.slice(0, 3)) {
        narrativeText += `• ${pattern.description}\n`;
      }
    }

    // Calculate week number
    const daysSinceStart = Math.floor((Date.now() - user.started_at) / (1000 * 60 * 60 * 24));
    const weekNumber = Math.floor(daysSinceStart / 7) + 1;

    // Check for existing narrative
    const existing = await ctx.db
      .query("user_sleep_narrative")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .first();

    const now = Date.now();

    const narrativeData = {
      user_id: args.userId,
      phenotype: classification.primary_phenotype,
      phenotype_confidence: classification.confidence,
      phenotype_description: phenotypeDef.description,
      key_patterns_json: JSON.stringify(classification.patterns),
      leverage_points_json: JSON.stringify(classification.leverage_points),
      narrative_title: phenotypeDef.title,
      narrative_text: narrativeText,
      narrative_highlights_json: JSON.stringify(
        classification.patterns.slice(0, 3).map((p) => p.description)
      ),
      week_number: weekNumber,
      previous_narrative_id: existing?._id,
      data_points_used: classification.patterns.reduce((s, p) => s + p.data_points, 0),
      generated_at: now,
      updated_at: now,
    };

    // Insert new narrative
    const narrativeId = await ctx.db.insert("user_sleep_narrative", narrativeData);

    return {
      id: narrativeId,
      title: phenotypeDef.title,
      phenotype: classification.primary_phenotype,
      confidence: classification.confidence,
      week_number: weekNumber,
    };
  },
});

function buildCohortContext(
  cohort: Doc<"user_cohort_memberships">,
  phenotype: string
): string | null {
  const parts: string[] = [];

  if (cohort.age_bracket && cohort.age_bracket !== "unknown") {
    if (phenotype === "tired_but_wired") {
      if (cohort.gender === "male" && cohort.age_bracket === "50-60") {
        return "This is especially common in high-achieving men in their 50s managing multiple responsibilities.";
      }
      if (cohort.family_situation === "young_children") {
        return "This is very common among parents of young children who need to stay alert despite exhaustion.";
      }
    }

    if (phenotype === "compensator") {
      if (cohort.work_pattern?.includes("high_stress")) {
        return "Weekend catch-up sleep is a natural response to demanding work weeks, but it can backfire.";
      }
    }

    if (phenotype === "delayed_phase") {
      if (cohort.age_bracket === "20-30" || cohort.age_bracket === "30-40") {
        return "Delayed sleep phase is more common in younger adults - you're working with your biology, not against it.";
      }
    }
  }

  return null;
}

// ============================================
// Public Queries
// ============================================

/**
 * Get user's sleep fingerprint (public query for UI)
 */
export const getSleepFingerprint = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    // Get most recent narrative
    const narrative = await ctx.db
      .query("user_sleep_narrative")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .first();

    if (!narrative) {
      // Check if we have enough data to generate one
      const sleepData = await ctx.db
        .query("user_sleep_data")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .take(5);

      if (sleepData.length < 5) {
        const daysNeeded = 5 - sleepData.length;
        return {
          has_fingerprint: false,
          days_until_available: daysNeeded,
          message: `${daysNeeded} more nights to unlock your Sleep Fingerprint`,
          teaser: "We're learning your unique sleep patterns...",
        };
      }

      return {
        has_fingerprint: false,
        days_until_available: 0,
        message: "Your Sleep Fingerprint is being generated...",
        teaser: "Check back soon!",
      };
    }

    const phenotypeDef = PHENOTYPE_DEFINITIONS[narrative.phenotype];

    return {
      has_fingerprint: true,
      title: narrative.narrative_title,
      phenotype: narrative.phenotype,
      phenotype_name: phenotypeDef?.name || narrative.phenotype,
      description: narrative.phenotype_description,
      narrative: narrative.narrative_text,
      confidence: narrative.phenotype_confidence,
      patterns: JSON.parse(narrative.key_patterns_json),
      leverage_points: JSON.parse(narrative.leverage_points_json),
      highlights: narrative.narrative_highlights_json
        ? JSON.parse(narrative.narrative_highlights_json)
        : [],
      week_number: narrative.week_number,
      generated_at: narrative.generated_at,
    };
  },
});

/**
 * Get pattern details for UI display
 */
export const getPatternDetails = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const narrative = await ctx.db
      .query("user_sleep_narrative")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .order("desc")
      .first();

    if (!narrative) {
      return { patterns: [], has_data: false };
    }

    const patterns = JSON.parse(narrative.key_patterns_json) as SleepPattern[];

    return {
      patterns: patterns.map((p) => ({
        id: p.pattern_id,
        name: p.pattern_name,
        description: p.description,
        evidence: p.evidence,
        confidence: p.confidence,
        confidence_label:
          p.confidence >= 80 ? "High" : p.confidence >= 60 ? "Moderate" : "Emerging",
      })),
      has_data: true,
      phenotype: narrative.phenotype,
    };
  },
});
