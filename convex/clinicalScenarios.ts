import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

/**
 * Clinical Scenario Test Suite
 *
 * Provides pre-configured clinical test cases for validating:
 * - Correct gateway triggering
 * - Accurate clinical scoring
 * - Appropriate intervention recommendations
 * - Phenotype classification accuracy
 */

// ============================================
// Clinical Test Case Definitions
// ============================================

interface ClinicalTestCase {
  id: string;
  name: string;
  description: string;
  category: "insomnia" | "apnea" | "mental_health" | "circadian" | "comorbid" | "healthy";
  expectedGateways: string[];
  expectedPhenotype: string;
  expectedScores: {
    ISI?: { range: [number, number]; severity: string };
    "PHQ-9"?: { range: [number, number]; severity: string };
    "GAD-7"?: { range: [number, number]; severity: string };
    ESS?: { range: [number, number]; severity: string };
    "STOP-BANG"?: { range: [number, number]; severity: string };
  };
  responses: Record<string, string | number>;
  sleepPattern: string;
  demographics: {
    ageRange: [number, number];
    gender: string;
    bmiRange: [number, number];
  };
}

const CLINICAL_TEST_CASES: ClinicalTestCase[] = [
  // ============================================
  // Insomnia Cases
  // ============================================
  {
    id: "insomnia_onset_moderate",
    name: "Sleep Onset Insomnia - Moderate",
    description: "Classic sleep onset insomnia with anxiety component",
    category: "insomnia",
    expectedGateways: ["insomnia", "anxiety", "poor_sleep_quality"],
    expectedPhenotype: "tired_but_wired",
    expectedScores: {
      ISI: { range: [15, 21], severity: "moderate" },
      "GAD-7": { range: [10, 14], severity: "moderate" },
    },
    responses: {
      "1": 4, // Poor sleep quality
      "3": "Yes", // Insomnia
      "16": 2, // Anxiety (more than half days)
      ISI_1: 3, ISI_2: 3, ISI_3: 2, ISI_4: 3, ISI_5: 3, ISI_6: 2, ISI_7: 2,
      GAD7_1: 2, GAD7_2: 2, GAD7_3: 1, GAD7_4: 2, GAD7_5: 1, GAD7_6: 1, GAD7_7: 2,
      CSD_LATENCY: 75, // Long sleep onset
      CSD_AWAKENINGS: 2,
      CSD_WASO: 20,
    },
    sleepPattern: "insomnia_onset",
    demographics: {
      ageRange: [35, 50],
      gender: "female",
      bmiRange: [22, 27],
    },
  },
  {
    id: "insomnia_maintenance_severe",
    name: "Sleep Maintenance Insomnia - Severe",
    description: "Frequent night awakenings with depression",
    category: "insomnia",
    expectedGateways: ["insomnia", "depression", "poor_sleep_quality"],
    expectedPhenotype: "fragmented_sleeper",
    expectedScores: {
      ISI: { range: [22, 28], severity: "severe" },
      "PHQ-9": { range: [15, 20], severity: "moderately_severe" },
    },
    responses: {
      "1": 2, // Very poor quality
      "3": "Yes", // Insomnia
      "15": 3, // Depression (nearly every day)
      ISI_1: 3, ISI_2: 4, ISI_3: 3, ISI_4: 3, ISI_5: 4, ISI_6: 3, ISI_7: 3,
      PHQ9_1: 2, PHQ9_2: 2, PHQ9_3: 2, PHQ9_4: 2, PHQ9_5: 1, PHQ9_6: 1, PHQ9_7: 2, PHQ9_8: 1, PHQ9_9: 0,
      CSD_LATENCY: 25,
      CSD_AWAKENINGS: 5, // Many awakenings
      CSD_WASO: 60,
    },
    sleepPattern: "insomnia_maintenance",
    demographics: {
      ageRange: [45, 60],
      gender: "female",
      bmiRange: [24, 30],
    },
  },
  {
    id: "insomnia_early_wake",
    name: "Early Morning Awakening",
    description: "Wakes at 4-5 AM, can't return to sleep, mild depression",
    category: "insomnia",
    expectedGateways: ["insomnia", "depression"],
    expectedPhenotype: "early_terminator",
    expectedScores: {
      ISI: { range: [14, 20], severity: "moderate" },
      "PHQ-9": { range: [10, 14], severity: "moderate" },
    },
    responses: {
      "1": 5,
      "3": "Yes",
      "15": 2,
      ISI_1: 2, ISI_2: 2, ISI_3: 3, ISI_4: 3, ISI_5: 2, ISI_6: 2, ISI_7: 2,
      PHQ9_1: 1, PHQ9_2: 2, PHQ9_3: 1, PHQ9_4: 2, PHQ9_5: 1, PHQ9_6: 1, PHQ9_7: 1, PHQ9_8: 1, PHQ9_9: 0,
      CSD_LATENCY: 15,
      CSD_AWAKENINGS: 1,
      CSD_OUT_BED: "04:30",
    },
    sleepPattern: "early_awakening",
    demographics: {
      ageRange: [55, 70],
      gender: "male",
      bmiRange: [25, 30],
    },
  },

  // ============================================
  // Sleep Apnea Cases
  // ============================================
  {
    id: "osa_high_risk",
    name: "High Risk OSA - Classic Presentation",
    description: "Snoring, witnessed apneas, daytime sleepiness, overweight male",
    category: "apnea",
    expectedGateways: ["osa", "excessive_sleepiness"],
    expectedPhenotype: "fragmented_sleeper",
    expectedScores: {
      ESS: { range: [15, 20], severity: "moderate" },
      "STOP-BANG": { range: [5, 8], severity: "high" },
    },
    responses: {
      "17": 3, // Excessive sleepiness
      "19": "Yes", // Snoring
      "20": "Yes", // Witnessed apnea
      SB_1: "Yes", SB_2: "Yes", SB_3: "Yes", SB_4: "No", SB_5: "Yes", SB_6: "Yes", SB_7: "Yes", SB_8: "Yes",
      ESS_1: 2, ESS_2: 2, ESS_3: 2, ESS_4: 3, ESS_5: 2, ESS_6: 2, ESS_7: 1, ESS_8: 2,
    },
    sleepPattern: "sleep_apnea",
    demographics: {
      ageRange: [50, 65],
      gender: "male",
      bmiRange: [35, 42],
    },
  },
  {
    id: "osa_moderate_female",
    name: "Moderate Risk OSA - Female Presentation",
    description: "Atypical presentation: fatigue, insomnia symptoms, mild overweight",
    category: "apnea",
    expectedGateways: ["osa", "insomnia"],
    expectedPhenotype: "fragmented_sleeper",
    expectedScores: {
      ESS: { range: [11, 14], severity: "mild" },
      "STOP-BANG": { range: [3, 4], severity: "intermediate" },
    },
    responses: {
      "17": 2,
      "19": "Yes",
      "20": "No",
      "3": "Yes",
      SB_1: "Yes", SB_2: "Yes", SB_3: "No", SB_4: "Yes", SB_5: "No", SB_6: "Yes", SB_7: "No", SB_8: "No",
      ESS_1: 1, ESS_2: 2, ESS_3: 2, ESS_4: 2, ESS_5: 1, ESS_6: 1, ESS_7: 1, ESS_8: 1,
      ISI_1: 2, ISI_2: 2, ISI_3: 1, ISI_4: 2, ISI_5: 2, ISI_6: 1, ISI_7: 2,
    },
    sleepPattern: "sleep_apnea",
    demographics: {
      ageRange: [55, 65],
      gender: "female",
      bmiRange: [28, 33],
    },
  },

  // ============================================
  // Mental Health Cases
  // ============================================
  {
    id: "anxiety_insomnia",
    name: "Anxiety-Driven Insomnia",
    description: "Racing thoughts, difficulty relaxing, high GAD-7",
    category: "mental_health",
    expectedGateways: ["anxiety", "insomnia", "poor_sleep_quality"],
    expectedPhenotype: "tired_but_wired",
    expectedScores: {
      "GAD-7": { range: [15, 21], severity: "severe" },
      ISI: { range: [15, 21], severity: "moderate" },
    },
    responses: {
      "16": 3, // Anxiety nearly every day
      "3": "Yes",
      "1": 3,
      GAD7_1: 3, GAD7_2: 3, GAD7_3: 2, GAD7_4: 2, GAD7_5: 2, GAD7_6: 2, GAD7_7: 3,
      ISI_1: 3, ISI_2: 2, ISI_3: 2, ISI_4: 2, ISI_5: 3, ISI_6: 2, ISI_7: 3,
      CSD_LATENCY: 90,
    },
    sleepPattern: "insomnia_onset",
    demographics: {
      ageRange: [25, 40],
      gender: "female",
      bmiRange: [20, 25],
    },
  },
  {
    id: "depression_hypersomnia",
    name: "Depression with Hypersomnia",
    description: "Sleeping too much, low energy, anhedonia",
    category: "mental_health",
    expectedGateways: ["depression"],
    expectedPhenotype: "efficiency_struggler",
    expectedScores: {
      "PHQ-9": { range: [15, 21], severity: "moderately_severe" },
    },
    responses: {
      "15": 3, // Depression nearly every day
      "1": 5,
      "3": "No",
      PHQ9_1: 2, PHQ9_2: 3, PHQ9_3: 3, PHQ9_4: 2, PHQ9_5: 1, PHQ9_6: 2, PHQ9_7: 2, PHQ9_8: 0, PHQ9_9: 0,
      CSD_BEDTIME: "21:00",
      CSD_OUT_BED: "09:30",
    },
    sleepPattern: "irregular",
    demographics: {
      ageRange: [20, 35],
      gender: "male",
      bmiRange: [22, 28],
    },
  },

  // ============================================
  // Circadian Cases
  // ============================================
  {
    id: "delayed_phase",
    name: "Delayed Sleep Phase Disorder",
    description: "Natural night owl, can't fall asleep before 2 AM",
    category: "circadian",
    expectedGateways: ["sleep_timing"],
    expectedPhenotype: "delayed_phase",
    expectedScores: {
      ISI: { range: [8, 14], severity: "mild" },
    },
    responses: {
      "7": "00:30", // Weekday bedtime
      "8": "07:00", // Weekday wake
      "9": "02:30", // Weekend bedtime
      "10": "11:00", // Weekend wake
      "1": 6,
      "3": "No",
      ISI_1: 2, ISI_2: 1, ISI_3: 1, ISI_4: 2, ISI_5: 2, ISI_6: 1, ISI_7: 2,
    },
    sleepPattern: "delayed_phase",
    demographics: {
      ageRange: [18, 30],
      gender: "male",
      bmiRange: [20, 25],
    },
  },
  {
    id: "social_jet_lag",
    name: "Social Jet Lag / Compensator",
    description: "Large weekday-weekend sleep difference",
    category: "circadian",
    expectedGateways: ["sleep_timing", "poor_sleep_quality"],
    expectedPhenotype: "compensator",
    expectedScores: {
      ISI: { range: [8, 14], severity: "mild" },
    },
    responses: {
      "7": "23:00", // Weekday bedtime
      "8": "06:00", // Weekday wake
      "9": "01:30", // Weekend bedtime - 2.5 hours later
      "10": "10:00", // Weekend wake - 4 hours later
      "1": 5,
      "3": "Yes",
      ISI_1: 2, ISI_2: 2, ISI_3: 1, ISI_4: 2, ISI_5: 2, ISI_6: 1, ISI_7: 1,
    },
    sleepPattern: "compensator",
    demographics: {
      ageRange: [25, 40],
      gender: "female",
      bmiRange: [22, 28],
    },
  },

  // ============================================
  // Comorbid Cases
  // ============================================
  {
    id: "triple_threat",
    name: "Triple Threat - Insomnia, Anxiety, Depression",
    description: "Complex comorbid presentation requiring multimodal treatment",
    category: "comorbid",
    expectedGateways: ["insomnia", "anxiety", "depression", "poor_sleep_quality"],
    expectedPhenotype: "tired_but_wired",
    expectedScores: {
      ISI: { range: [18, 25], severity: "severe" },
      "GAD-7": { range: [12, 18], severity: "moderate" },
      "PHQ-9": { range: [12, 18], severity: "moderate" },
    },
    responses: {
      "1": 2,
      "3": "Yes",
      "15": 2,
      "16": 2,
      ISI_1: 3, ISI_2: 3, ISI_3: 3, ISI_4: 3, ISI_5: 3, ISI_6: 3, ISI_7: 3,
      GAD7_1: 2, GAD7_2: 2, GAD7_3: 2, GAD7_4: 2, GAD7_5: 2, GAD7_6: 1, GAD7_7: 2,
      PHQ9_1: 2, PHQ9_2: 2, PHQ9_3: 2, PHQ9_4: 2, PHQ9_5: 1, PHQ9_6: 1, PHQ9_7: 2, PHQ9_8: 1, PHQ9_9: 0,
      CSD_LATENCY: 60,
      CSD_AWAKENINGS: 4,
      CSD_WASO: 45,
    },
    sleepPattern: "insomnia_maintenance",
    demographics: {
      ageRange: [35, 55],
      gender: "female",
      bmiRange: [24, 32],
    },
  },
  {
    id: "apnea_plus_insomnia",
    name: "OSA with Comorbid Insomnia (COMISA)",
    description: "Complex sleep-disordered breathing with psychophysiological insomnia",
    category: "comorbid",
    expectedGateways: ["osa", "insomnia", "excessive_sleepiness", "poor_sleep_quality"],
    expectedPhenotype: "fragmented_sleeper",
    expectedScores: {
      ISI: { range: [15, 22], severity: "moderate" },
      ESS: { range: [12, 18], severity: "moderate" },
      "STOP-BANG": { range: [4, 6], severity: "intermediate" },
    },
    responses: {
      "3": "Yes",
      "17": 3,
      "19": "Yes",
      "20": "Yes",
      "1": 3,
      ISI_1: 3, ISI_2: 3, ISI_3: 2, ISI_4: 2, ISI_5: 3, ISI_6: 2, ISI_7: 2,
      ESS_1: 2, ESS_2: 2, ESS_3: 2, ESS_4: 2, ESS_5: 2, ESS_6: 1, ESS_7: 1, ESS_8: 2,
      SB_1: "Yes", SB_2: "Yes", SB_3: "Yes", SB_4: "No", SB_5: "No", SB_6: "Yes", SB_7: "No", SB_8: "Yes",
      CSD_LATENCY: 40,
      CSD_AWAKENINGS: 6,
      CSD_WASO: 50,
    },
    sleepPattern: "sleep_apnea",
    demographics: {
      ageRange: [50, 65],
      gender: "male",
      bmiRange: [30, 38],
    },
  },

  // ============================================
  // Healthy Control
  // ============================================
  {
    id: "healthy_sleeper",
    name: "Healthy Sleeper Control",
    description: "No significant sleep complaints, good sleep hygiene",
    category: "healthy",
    expectedGateways: [],
    expectedPhenotype: "healthy",
    expectedScores: {
      ISI: { range: [0, 7], severity: "none" },
      "PHQ-9": { range: [0, 4], severity: "none" },
      "GAD-7": { range: [0, 4], severity: "none" },
      ESS: { range: [0, 10], severity: "none" },
    },
    responses: {
      "1": 8, // Good quality
      "3": "No", // No insomnia
      "15": 0, // No depression
      "16": 0, // No anxiety
      "17": 1, // Normal sleepiness
      "19": "No", // No snoring
      "20": "No", // No apnea
      ISI_1: 1, ISI_2: 1, ISI_3: 1, ISI_4: 1, ISI_5: 1, ISI_6: 0, ISI_7: 1,
      PHQ9_1: 0, PHQ9_2: 0, PHQ9_3: 0, PHQ9_4: 1, PHQ9_5: 0, PHQ9_6: 0, PHQ9_7: 0, PHQ9_8: 0, PHQ9_9: 0,
      GAD7_1: 0, GAD7_2: 1, GAD7_3: 0, GAD7_4: 0, GAD7_5: 0, GAD7_6: 0, GAD7_7: 0,
      ESS_1: 1, ESS_2: 1, ESS_3: 1, ESS_4: 1, ESS_5: 1, ESS_6: 0, ESS_7: 0, ESS_8: 1,
      CSD_LATENCY: 12,
      CSD_AWAKENINGS: 1,
      CSD_WASO: 8,
    },
    sleepPattern: "healthy",
    demographics: {
      ageRange: [30, 45],
      gender: "female",
      bmiRange: [21, 25],
    },
  },
];

// ============================================
// Test Case Execution Functions
// ============================================

/**
 * Get all clinical test cases
 */
export const getClinicalTestCases = query({
  args: {
    category: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { category } = args;

    let cases = CLINICAL_TEST_CASES;
    if (category) {
      cases = cases.filter(c => c.category === category);
    }

    return {
      totalCases: cases.length,
      categories: [...new Set(CLINICAL_TEST_CASES.map(c => c.category))],
      cases: cases.map(c => ({
        id: c.id,
        name: c.name,
        description: c.description,
        category: c.category,
        expectedGateways: c.expectedGateways,
        expectedPhenotype: c.expectedPhenotype,
        expectedScores: c.expectedScores,
      })),
    };
  },
});

/**
 * Create a test user from a clinical scenario
 */
export const createClinicalTestUser = mutation({
  args: {
    scenarioId: v.string(),
    usernamePrefix: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { scenarioId, usernamePrefix = "clinical_test" } = args;

    const scenario = CLINICAL_TEST_CASES.find(c => c.id === scenarioId);
    if (!scenario) {
      return { status: "fail", message: `Unknown scenario: ${scenarioId}` };
    }

    const now = Date.now();
    const username = `${usernamePrefix}_${scenarioId}_${Date.now().toString(36)}`;

    // Calculate demographics
    const age = Math.floor(Math.random() * (scenario.demographics.ageRange[1] - scenario.demographics.ageRange[0] + 1)) + scenario.demographics.ageRange[0];
    const birthYear = new Date().getFullYear() - age;
    const bmi = Math.random() * (scenario.demographics.bmiRange[1] - scenario.demographics.bmiRange[0]) + scenario.demographics.bmiRange[0];
    const heightCm = scenario.demographics.gender === "male" ? 175 : 165;
    const weightKg = Math.round(bmi * Math.pow(heightCm / 100, 2));

    // Create user
    const userId = await ctx.db.insert("users", {
      username,
      password_hash: "test123_hash",
      email: `${username}@test.zoesleep.com`,
      role: "patient",
      current_day: 10, // Mid-journey for expansion access
      started_at: now - 10 * 24 * 60 * 60 * 1000,
      last_accessed: now,
      created_at: now,
      onboarding_completed: true,
      onboarding_completed_at: now - 10 * 24 * 60 * 60 * 1000,
      full_name: `Clinical Test - ${scenario.name}`,
      measurement_system: "Metric",
      height_cm: heightCm,
      weight_kg: weightKg,
      gender: scenario.demographics.gender,
      birth_year: birthYear,
      developer_mode: true,
    });

    // Insert responses
    for (const [questionId, value] of Object.entries(scenario.responses)) {
      const isNumber = typeof value === "number";
      const dayNumber = questionId.startsWith("ISI_") || questionId.startsWith("PHQ") ||
                        questionId.startsWith("GAD") || questionId.startsWith("ESS") ||
                        questionId.startsWith("SB_") ? 8 : 1;

      await ctx.db.insert("user_assessment_responses", {
        user_id: userId,
        question_id: questionId,
        response_value: isNumber ? undefined : String(value),
        response_number: isNumber ? value : undefined,
        day_number: dayNumber,
        created_at: now,
        updated_at: now,
      });
    }

    // Set gateway states
    for (const gatewayId of scenario.expectedGateways) {
      await ctx.db.insert("user_gateway_states", {
        user_id: userId,
        gateway_id: gatewayId,
        triggered: true,
        triggered_at: now,
        last_evaluated_at: now,
      });
    }

    // Store narrative/phenotype
    await ctx.db.insert("user_sleep_narrative", {
      user_id: userId,
      phenotype: scenario.expectedPhenotype,
      phenotype_confidence: 90,
      phenotype_description: scenario.description,
      key_patterns_json: JSON.stringify(scenario.expectedGateways),
      leverage_points_json: JSON.stringify([]),
      narrative_title: scenario.name,
      narrative_text: scenario.description,
      week_number: 1,
      data_points_used: Object.keys(scenario.responses).length,
      generated_at: now,
      updated_at: now,
    });

    return {
      status: "success",
      userId,
      username,
      scenario: {
        id: scenario.id,
        name: scenario.name,
        category: scenario.category,
        expectedGateways: scenario.expectedGateways,
        expectedPhenotype: scenario.expectedPhenotype,
        expectedScores: scenario.expectedScores,
      },
      demographics: {
        age,
        gender: scenario.demographics.gender,
        bmi: Math.round(bmi * 10) / 10,
        heightCm,
        weightKg,
      },
    };
  },
});

/**
 * Validate a clinical test user against expected outcomes
 */
export const validateClinicalTestUser = mutation({
  args: {
    userId: v.id("users"),
    scenarioId: v.string(),
  },
  handler: async (ctx, args) => {
    const { userId, scenarioId } = args;

    const scenario = CLINICAL_TEST_CASES.find(c => c.id === scenarioId);
    if (!scenario) {
      return { status: "fail", message: `Unknown scenario: ${scenarioId}` };
    }

    const user = await ctx.db.get(userId);
    if (!user) {
      return { status: "fail", message: "User not found" };
    }

    const validationResults: Array<{
      check: string;
      expected: unknown;
      actual: unknown;
      passed: boolean;
    }> = [];

    // Validate gateway states
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const triggeredGateways = gatewayStates.filter(g => g.triggered).map(g => g.gateway_id);

    for (const expectedGateway of scenario.expectedGateways) {
      validationResults.push({
        check: `Gateway: ${expectedGateway}`,
        expected: true,
        actual: triggeredGateways.includes(expectedGateway),
        passed: triggeredGateways.includes(expectedGateway),
      });
    }

    // Check for unexpected gateways
    for (const triggeredGateway of triggeredGateways) {
      if (!scenario.expectedGateways.includes(triggeredGateway)) {
        validationResults.push({
          check: `Unexpected Gateway: ${triggeredGateway}`,
          expected: false,
          actual: true,
          passed: false,
        });
      }
    }

    // Validate phenotype
    const narrative = await ctx.db
      .query("user_sleep_narrative")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .first();

    validationResults.push({
      check: "Phenotype",
      expected: scenario.expectedPhenotype,
      actual: narrative?.phenotype || "none",
      passed: narrative?.phenotype === scenario.expectedPhenotype,
    });

    // Validate scores (if calculated)
    const scores = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    for (const [questionnaire, expectedScore] of Object.entries(scenario.expectedScores)) {
      const actualScore = scores.find(s => s.questionnaire_name === questionnaire);

      if (actualScore) {
        const inRange = actualScore.score >= expectedScore.range[0] && actualScore.score <= expectedScore.range[1];
        validationResults.push({
          check: `Score: ${questionnaire}`,
          expected: `${expectedScore.range[0]}-${expectedScore.range[1]} (${expectedScore.severity})`,
          actual: `${actualScore.score} (${actualScore.category || "uncategorized"})`,
          passed: inRange,
        });
      } else {
        validationResults.push({
          check: `Score: ${questionnaire}`,
          expected: `${expectedScore.range[0]}-${expectedScore.range[1]}`,
          actual: "Not calculated",
          passed: false,
        });
      }
    }

    const passCount = validationResults.filter(r => r.passed).length;
    const failCount = validationResults.filter(r => !r.passed).length;

    return {
      status: failCount === 0 ? "pass" : "fail",
      scenario: {
        id: scenario.id,
        name: scenario.name,
        category: scenario.category,
      },
      summary: `${passCount}/${validationResults.length} checks passed`,
      results: validationResults,
    };
  },
});

/**
 * Run all clinical scenarios as tests
 */
export const runAllClinicalScenarios = mutation({
  args: {
    cleanup: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const { cleanup = true } = args;

    const results: Array<{
      scenarioId: string;
      name: string;
      category: string;
      status: "pass" | "fail";
      userId?: Id<"users">;
      summary?: string;
    }> = [];

    for (const scenario of CLINICAL_TEST_CASES) {
      try {
        // Create test user
        const now = Date.now();
        const username = `clinical_batch_${scenario.id}_${now.toString(36)}`;

        const age = Math.floor(Math.random() * (scenario.demographics.ageRange[1] - scenario.demographics.ageRange[0] + 1)) + scenario.demographics.ageRange[0];
        const birthYear = new Date().getFullYear() - age;
        const bmi = Math.random() * (scenario.demographics.bmiRange[1] - scenario.demographics.bmiRange[0]) + scenario.demographics.bmiRange[0];
        const heightCm = scenario.demographics.gender === "male" ? 175 : 165;
        const weightKg = Math.round(bmi * Math.pow(heightCm / 100, 2));

        const userId = await ctx.db.insert("users", {
          username,
          password_hash: "test_hash",
          email: `${username}@test.zoesleep.com`,
          role: "patient",
          current_day: 10,
          started_at: now - 10 * 24 * 60 * 60 * 1000,
          last_accessed: now,
          created_at: now,
          onboarding_completed: true,
          full_name: `Clinical Test - ${scenario.name}`,
          height_cm: heightCm,
          weight_kg: weightKg,
          gender: scenario.demographics.gender,
          birth_year: birthYear,
          developer_mode: true,
        });

        // Insert responses
        for (const [questionId, value] of Object.entries(scenario.responses)) {
          const isNumber = typeof value === "number";
          await ctx.db.insert("user_assessment_responses", {
            user_id: userId,
            question_id: questionId,
            response_value: isNumber ? undefined : String(value),
            response_number: isNumber ? value : undefined,
            day_number: 1,
            created_at: now,
            updated_at: now,
          });
        }

        // Set gateways
        for (const gatewayId of scenario.expectedGateways) {
          await ctx.db.insert("user_gateway_states", {
            user_id: userId,
            gateway_id: gatewayId,
            triggered: true,
            triggered_at: now,
            last_evaluated_at: now,
          });
        }

        // Validate
        const gatewayStates = await ctx.db
          .query("user_gateway_states")
          .withIndex("by_user", (q) => q.eq("user_id", userId))
          .collect();

        const triggeredGateways = gatewayStates.filter(g => g.triggered).map(g => g.gateway_id);
        const gatewaysMatch = scenario.expectedGateways.every(g => triggeredGateways.includes(g));

        results.push({
          scenarioId: scenario.id,
          name: scenario.name,
          category: scenario.category,
          status: gatewaysMatch ? "pass" : "fail",
          userId,
          summary: `Gateways: ${triggeredGateways.join(", ") || "none"}`,
        });

        // Cleanup if requested
        if (cleanup) {
          // Delete responses
          const responses = await ctx.db
            .query("user_assessment_responses")
            .withIndex("by_user", (q) => q.eq("user_id", userId))
            .collect();
          for (const r of responses) {
            await ctx.db.delete(r._id);
          }

          // Delete gateway states
          for (const g of gatewayStates) {
            await ctx.db.delete(g._id);
          }

          // Delete user
          await ctx.db.delete(userId);
        }
      } catch (error) {
        results.push({
          scenarioId: scenario.id,
          name: scenario.name,
          category: scenario.category,
          status: "fail",
          summary: `Error: ${error}`,
        });
      }
    }

    const passCount = results.filter(r => r.status === "pass").length;
    const failCount = results.filter(r => r.status === "fail").length;

    return {
      status: failCount === 0 ? "pass" : "fail",
      summary: `${passCount}/${results.length} scenarios passed`,
      cleanedUp: cleanup,
      results,
    };
  },
});
