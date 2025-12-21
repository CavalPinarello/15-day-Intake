import { mutation, query, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

/**
 * Comprehensive Test User Generator for Zoe Sleep
 *
 * Creates 100+ diverse test users covering:
 * - All 9 sleep phenotypes
 * - All 10 gateway triggers
 * - Various demographics (age, gender, BMI)
 * - Different sleep patterns and conditions
 * - Clinical severity levels
 */

// ============================================
// Sleep Phenotype Profiles
// ============================================

const SLEEP_PHENOTYPES = {
  tired_but_wired: {
    name: "Tired but Wired",
    description: "High anxiety, difficulty falling asleep despite exhaustion",
    gatewaysLikely: ["anxiety", "insomnia"],
    isiRange: [15, 24],
    gad7Range: [10, 21],
    sleepLatencyRange: [45, 120], // minutes
    sleepEfficiencyRange: [60, 75],
  },
  sleep_state_misperception: {
    name: "Sleep State Misperception",
    description: "Perceives sleep as worse than objective measures",
    gatewaysLikely: ["insomnia", "poor_sleep_quality"],
    isiRange: [12, 20],
    subjectiveQualityRange: [2, 4], // out of 10
    objectiveEfficiencyRange: [80, 92],
    gapScore: 30, // large perception gap
  },
  compensator: {
    name: "Compensator (Weekend Warrior)",
    description: "Makes up sleep on weekends",
    gatewaysLikely: ["sleep_timing"],
    weekdayWeekendGap: 90, // minutes
    socialJetLag: true,
    sleepDebtWeekday: true,
  },
  irregular_rhythm: {
    name: "Irregular Rhythm",
    description: "Highly variable sleep schedule",
    gatewaysLikely: ["sleep_timing", "poor_sleep_quality"],
    bedtimeVariability: 120, // minutes stddev
    wakeTimeVariability: 90,
  },
  fragmented_sleeper: {
    name: "Fragmented Sleeper",
    description: "Multiple awakenings per night",
    gatewaysLikely: ["insomnia", "osa"],
    awakeningsPerNight: [4, 8],
    wasoRange: [45, 90], // wake after sleep onset
    sleepEfficiencyRange: [65, 78],
  },
  early_terminator: {
    name: "Early Terminator",
    description: "Wakes too early, can't return to sleep",
    gatewaysLikely: ["insomnia", "depression"],
    wakeTimeRange: ["04:00", "05:30"],
    earlyWakeFrequency: 5, // nights per week
    phq9Range: [5, 15],
  },
  delayed_phase: {
    name: "Delayed Phase (Night Owl)",
    description: "Natural late chronotype",
    gatewaysLikely: ["sleep_timing"],
    bedtimeRange: ["01:00", "03:00"],
    wakeTimeRange: ["09:00", "11:00"],
    chronotype: "night_owl",
  },
  short_sleeper: {
    name: "Short Sleeper",
    description: "Functions on less than 6 hours",
    gatewaysLikely: [], // may not trigger gateways
    totalSleepRange: [300, 360], // 5-6 hours in minutes
    sleepEfficiencyRange: [85, 95],
    functional: true,
  },
  efficiency_struggler: {
    name: "Efficiency Struggler",
    description: "Long time in bed, poor efficiency",
    gatewaysLikely: ["insomnia", "poor_sleep_quality"],
    timeInBedRange: [540, 600], // 9-10 hours
    totalSleepRange: [360, 420], // 6-7 hours
    sleepEfficiencyRange: [60, 72],
  },
};

// ============================================
// Demographic Profiles
// ============================================

const DEMOGRAPHICS = {
  ageGroups: [
    { bracket: "18-25", range: [18, 25], lifeStage: "student", workPattern: "variable" },
    { bracket: "26-35", range: [26, 35], lifeStage: "early_career", workPattern: "9_to_5" },
    { bracket: "36-45", range: [36, 45], lifeStage: "parent_young", workPattern: "high_stress" },
    { bracket: "46-55", range: [46, 55], lifeStage: "parent_teens", workPattern: "9_to_5" },
    { bracket: "56-65", range: [56, 65], lifeStage: "empty_nest", workPattern: "remote" },
    { bracket: "66+", range: [66, 80], lifeStage: "retired", workPattern: "retired" },
  ],
  genders: ["male", "female", "other"],
  bmiCategories: [
    { category: "underweight", range: [16, 18.4] },
    { category: "normal", range: [18.5, 24.9] },
    { category: "overweight", range: [25, 29.9] },
    { category: "obese_1", range: [30, 34.9] },
    { category: "obese_2", range: [35, 39.9] },
    { category: "obese_3", range: [40, 50] },
  ],
  activityLevels: ["low", "moderate", "high"],
  chronotypes: ["early_bird", "normal", "night_owl"],
};

// ============================================
// Clinical Severity Profiles
// ============================================

const SEVERITY_LEVELS = {
  none: { isiRange: [0, 7], phq9Range: [0, 4], gad7Range: [0, 4], essRange: [0, 10] },
  mild: { isiRange: [8, 14], phq9Range: [5, 9], gad7Range: [5, 9], essRange: [11, 14] },
  moderate: { isiRange: [15, 21], phq9Range: [10, 14], gad7Range: [10, 14], essRange: [15, 18] },
  severe: { isiRange: [22, 28], phq9Range: [15, 27], gad7Range: [15, 21], essRange: [19, 24] },
};

// ============================================
// Test User Templates (100+ configurations)
// ============================================

interface TestUserTemplate {
  prefix: string;
  phenotype: keyof typeof SLEEP_PHENOTYPES;
  severity: keyof typeof SEVERITY_LEVELS;
  ageGroup: number; // index into DEMOGRAPHICS.ageGroups
  gender: string;
  bmiCategory: number; // index
  chronotype: string;
  gateways: string[];
  description: string;
}

const generateTestUserTemplates = (): TestUserTemplate[] => {
  const templates: TestUserTemplate[] = [];
  let counter = 1;

  // Generate phenotype-focused users (45 users - 5 per phenotype)
  Object.keys(SLEEP_PHENOTYPES).forEach((phenotypeKey, phenotypeIdx) => {
    const phenotype = phenotypeKey as keyof typeof SLEEP_PHENOTYPES;
    const profile = SLEEP_PHENOTYPES[phenotype];

    // Mild, moderate, severe for each phenotype
    ["mild", "moderate", "severe"].forEach((severity, sevIdx) => {
      templates.push({
        prefix: `test_${phenotype}_${severity}`,
        phenotype,
        severity: severity as keyof typeof SEVERITY_LEVELS,
        ageGroup: (phenotypeIdx + sevIdx) % 6,
        gender: DEMOGRAPHICS.genders[sevIdx % 3],
        bmiCategory: Math.floor(Math.random() * 6),
        chronotype: phenotype === "delayed_phase" ? "night_owl" : DEMOGRAPHICS.chronotypes[sevIdx % 3],
        gateways: profile.gatewaysLikely,
        description: `${profile.name} - ${severity} severity`,
      });
      counter++;
    });
  });

  // Generate gateway-focused users (30 users - 3 per gateway)
  const gatewayConfigs = [
    { id: "insomnia", phenotypes: ["tired_but_wired", "efficiency_struggler"] },
    { id: "depression", phenotypes: ["early_terminator", "fragmented_sleeper"] },
    { id: "anxiety", phenotypes: ["tired_but_wired", "irregular_rhythm"] },
    { id: "excessive_sleepiness", phenotypes: ["fragmented_sleeper", "short_sleeper"] },
    { id: "cognitive", phenotypes: ["sleep_state_misperception", "efficiency_struggler"] },
    { id: "osa", phenotypes: ["fragmented_sleeper", "efficiency_struggler"] },
    { id: "pain", phenotypes: ["fragmented_sleeper", "early_terminator"] },
    { id: "sleep_timing", phenotypes: ["compensator", "delayed_phase", "irregular_rhythm"] },
    { id: "diet_impact", phenotypes: ["efficiency_struggler", "fragmented_sleeper"] },
    { id: "poor_sleep_quality", phenotypes: ["tired_but_wired", "efficiency_struggler"] },
  ];

  gatewayConfigs.forEach((gateway, idx) => {
    ["mild", "moderate", "severe"].forEach((severity, sevIdx) => {
      templates.push({
        prefix: `test_gw_${gateway.id}_${severity}`,
        phenotype: gateway.phenotypes[sevIdx % gateway.phenotypes.length] as keyof typeof SLEEP_PHENOTYPES,
        severity: severity as keyof typeof SEVERITY_LEVELS,
        ageGroup: (idx + sevIdx) % 6,
        gender: DEMOGRAPHICS.genders[(idx + sevIdx) % 3],
        bmiCategory: gateway.id === "osa" ? 4 : Math.floor(Math.random() * 4), // Higher BMI for OSA
        chronotype: gateway.id === "sleep_timing" ? "night_owl" : "normal",
        gateways: [gateway.id],
        description: `Gateway focus: ${gateway.id} - ${severity}`,
      });
    });
  });

  // Generate demographic diversity users (20 users)
  DEMOGRAPHICS.ageGroups.forEach((age, ageIdx) => {
    DEMOGRAPHICS.genders.slice(0, 2).forEach((gender, genderIdx) => {
      templates.push({
        prefix: `test_demo_${age.bracket.replace(/[+-]/g, "")}_${gender}`,
        phenotype: Object.keys(SLEEP_PHENOTYPES)[(ageIdx + genderIdx) % 9] as keyof typeof SLEEP_PHENOTYPES,
        severity: "moderate",
        ageGroup: ageIdx,
        gender,
        bmiCategory: (ageIdx + genderIdx) % 6,
        chronotype: DEMOGRAPHICS.chronotypes[(ageIdx + genderIdx) % 3],
        gateways: [],
        description: `Demographic: ${age.bracket}, ${gender}`,
      });
    });
  });

  // Generate multi-comorbidity users (15 users - multiple conditions)
  const comorbidityConfigs = [
    { gateways: ["insomnia", "anxiety", "depression"], name: "anxiety_depression_insomnia" },
    { gateways: ["osa", "insomnia", "excessive_sleepiness"], name: "osa_complex" },
    { gateways: ["pain", "depression", "insomnia"], name: "pain_depression" },
    { gateways: ["sleep_timing", "anxiety", "poor_sleep_quality"], name: "circadian_anxiety" },
    { gateways: ["cognitive", "excessive_sleepiness", "osa"], name: "cognitive_sleepiness" },
  ];

  comorbidityConfigs.forEach((config, idx) => {
    ["mild", "moderate", "severe"].forEach((severity, sevIdx) => {
      templates.push({
        prefix: `test_comorbid_${config.name}_${severity}`,
        phenotype: "efficiency_struggler",
        severity: severity as keyof typeof SEVERITY_LEVELS,
        ageGroup: (idx + sevIdx) % 6,
        gender: DEMOGRAPHICS.genders[(idx + sevIdx) % 3],
        bmiCategory: 3,
        chronotype: "normal",
        gateways: config.gateways,
        description: `Multi-comorbidity: ${config.name} - ${severity}`,
      });
    });
  });

  return templates;
};

// ============================================
// Helper Functions
// ============================================

const randomInRange = (min: number, max: number): number => {
  return Math.floor(Math.random() * (max - min + 1)) + min;
};

const randomFloat = (min: number, max: number, decimals: number = 1): number => {
  const value = Math.random() * (max - min) + min;
  return Number(value.toFixed(decimals));
};

const hashPassword = (password: string): string => {
  // Simple hash for testing - in production use SHA256
  let hash = 0;
  for (let i = 0; i < password.length; i++) {
    const char = password.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return Math.abs(hash).toString(16).padStart(8, '0');
};

// SHA256 hash for iOS compatibility
const sha256Hash = async (str: string): Promise<string> => {
  // For test users, we use a simple predictable hash
  // Real SHA256 would require crypto library
  return `sha256_${str}_hash`;
};

// ============================================
// Response Generation Functions
// ============================================

const generateISIResponses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const range = SEVERITY_LEVELS[severity].isiRange;
  const targetScore = randomInRange(range[0], range[1]);

  // Distribute score across 7 questions (each 0-4)
  const responses: Record<string, number> = {};
  let remaining = targetScore;

  for (let i = 1; i <= 7; i++) {
    if (i === 7) {
      responses[`ISI_${i}`] = Math.min(4, remaining);
    } else {
      const maxForThis = Math.min(4, remaining - (7 - i));
      const minForThis = Math.max(0, remaining - (7 - i) * 4);
      responses[`ISI_${i}`] = randomInRange(minForThis, maxForThis);
      remaining -= responses[`ISI_${i}`];
    }
  }

  return responses;
};

const generatePHQ9Responses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const range = SEVERITY_LEVELS[severity].phq9Range;
  const targetScore = randomInRange(range[0], range[1]);

  const responses: Record<string, number> = {};
  let remaining = targetScore;

  for (let i = 1; i <= 9; i++) {
    if (i === 9) {
      responses[`PHQ9_${i}`] = Math.min(3, remaining);
    } else {
      const maxForThis = Math.min(3, remaining - (9 - i));
      const minForThis = Math.max(0, remaining - (9 - i) * 3);
      responses[`PHQ9_${i}`] = randomInRange(minForThis, maxForThis);
      remaining -= responses[`PHQ9_${i}`];
    }
  }

  return responses;
};

const generateGAD7Responses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const range = SEVERITY_LEVELS[severity].gad7Range;
  const targetScore = randomInRange(range[0], range[1]);

  const responses: Record<string, number> = {};
  let remaining = targetScore;

  for (let i = 1; i <= 7; i++) {
    if (i === 7) {
      responses[`GAD7_${i}`] = Math.min(3, remaining);
    } else {
      const maxForThis = Math.min(3, remaining - (7 - i));
      const minForThis = Math.max(0, remaining - (7 - i) * 3);
      responses[`GAD7_${i}`] = randomInRange(minForThis, maxForThis);
      remaining -= responses[`GAD7_${i}`];
    }
  }

  return responses;
};

const generateESSResponses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const range = SEVERITY_LEVELS[severity].essRange;
  const targetScore = randomInRange(range[0], range[1]);

  const responses: Record<string, number> = {};
  let remaining = targetScore;

  for (let i = 1; i <= 8; i++) {
    if (i === 8) {
      responses[`ESS_${i}`] = Math.min(3, remaining);
    } else {
      const maxForThis = Math.min(3, remaining - (8 - i));
      const minForThis = Math.max(0, remaining - (8 - i) * 3);
      responses[`ESS_${i}`] = randomInRange(minForThis, maxForThis);
      remaining -= responses[`ESS_${i}`];
    }
  }

  return responses;
};

const generateSTOPBANGResponses = (
  triggerOSA: boolean,
  ageGroup: { bracket: string; range: number[] },
  gender: string,
  bmiCategory: { category: string; range: number[] }
): Record<string, string> => {
  const responses: Record<string, string> = {};

  // SB_1: Snore loudly
  responses["SB_1"] = triggerOSA ? "Yes" : (Math.random() > 0.7 ? "Yes" : "No");
  // SB_2: Tired/fatigued
  responses["SB_2"] = triggerOSA ? "Yes" : (Math.random() > 0.5 ? "Yes" : "No");
  // SB_3: Observed stop breathing
  responses["SB_3"] = triggerOSA ? "Yes" : "No";
  // SB_4: High blood pressure
  responses["SB_4"] = ageGroup.range[0] > 50 && Math.random() > 0.5 ? "Yes" : "No";
  // SB_5: BMI > 35
  responses["SB_5"] = bmiCategory.range[0] > 35 ? "Yes" : "No";
  // SB_6: Age > 50
  responses["SB_6"] = ageGroup.range[0] > 50 ? "Yes" : "No";
  // SB_7: Neck > 40cm
  responses["SB_7"] = gender === "male" && triggerOSA ? "Yes" : "No";
  // SB_8: Gender Male
  responses["SB_8"] = gender === "male" ? "Yes" : "No";

  return responses;
};

// ============================================
// Additional Questionnaire Response Generators
// ============================================

/**
 * PSQI - Pittsburgh Sleep Quality Index
 * 19 questions for 7 component scores
 */
const generatePSQIResponses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, string | number> => {
  const responses: Record<string, string | number> = {};
  const isSevere = severity === "severe";
  const isMild = severity === "mild";

  // PSQI_1: Usual bedtime
  responses["PSQI_1"] = isSevere ? "01:30" : isMild ? "22:30" : "23:45";
  // PSQI_2: Minutes to fall asleep
  responses["PSQI_2"] = isSevere ? randomInRange(45, 90) : isMild ? randomInRange(5, 15) : randomInRange(20, 40);
  // PSQI_3: Usual wake time
  responses["PSQI_3"] = isSevere ? "05:00" : isMild ? "06:30" : "06:00";
  // PSQI_4: Hours of actual sleep
  responses["PSQI_4"] = isSevere ? randomInRange(4, 5) : isMild ? randomInRange(7, 8) : randomInRange(5, 6);
  // PSQI_5a-PSQI_5j: Sleep disturbances (0-3 scale)
  const disturbanceQuestions = ["5a", "5b", "5c", "5d", "5e", "5f", "5g", "5h", "5i", "5j"];
  for (const q of disturbanceQuestions) {
    responses[`PSQI_${q}`] = isSevere ? randomInRange(2, 3) : isMild ? randomInRange(0, 1) : randomInRange(1, 2);
  }
  // PSQI_6: Sleep medication frequency (0-3)
  responses["PSQI_6"] = isSevere ? randomInRange(2, 3) : isMild ? 0 : randomInRange(0, 1);
  // PSQI_7: Trouble staying awake (0-3)
  responses["PSQI_7"] = isSevere ? randomInRange(2, 3) : isMild ? 0 : randomInRange(1, 2);
  // PSQI_8: Enthusiasm problem (0-3)
  responses["PSQI_8"] = isSevere ? randomInRange(2, 3) : isMild ? 0 : randomInRange(1, 2);
  // PSQI_9: Overall sleep quality (0-3)
  responses["PSQI_9"] = isSevere ? 3 : isMild ? 0 : randomInRange(1, 2);

  return responses;
};

/**
 * DBAS-16 - Dysfunctional Beliefs and Attitudes about Sleep
 * 16 questions, 0-10 scale
 */
const generateDBAS16Responses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const responses: Record<string, number> = {};
  const baseScore = severity === "severe" ? 7 : severity === "mild" ? 3 : 5;

  for (let i = 1; i <= 16; i++) {
    responses[`DBAS_${i}`] = Math.min(10, Math.max(0, baseScore + randomInRange(-2, 2)));
  }

  return responses;
};

/**
 * Berlin Questionnaire - OSA screening
 * 10 questions across 3 categories
 */
const generateBerlinResponses = (
  triggerOSA: boolean,
  bmiHigh: boolean
): Record<string, string | number> => {
  const responses: Record<string, string | number> = {};

  // Category 1: Snoring
  responses["BERLIN_1"] = triggerOSA ? "Yes" : (Math.random() > 0.6 ? "Yes" : "No");
  responses["BERLIN_2"] = triggerOSA ? randomInRange(3, 4) : randomInRange(1, 2); // 1-4 frequency
  responses["BERLIN_3"] = triggerOSA ? "Yes" : "No"; // Snoring bothers others
  responses["BERLIN_4"] = triggerOSA ? randomInRange(3, 4) : randomInRange(1, 2); // Breathing stops frequency

  // Category 2: Wake time fatigue
  responses["BERLIN_5"] = triggerOSA ? "Yes" : (Math.random() > 0.5 ? "Yes" : "No"); // Tired after sleep
  responses["BERLIN_6"] = triggerOSA ? randomInRange(3, 4) : randomInRange(1, 2); // Fatigue frequency
  responses["BERLIN_7"] = triggerOSA ? "Yes" : "No"; // Fell asleep driving

  // Category 3: Obesity/Hypertension
  responses["BERLIN_8"] = bmiHigh ? "Yes" : "No"; // BMI > 30
  responses["BERLIN_9"] = triggerOSA && Math.random() > 0.5 ? "Yes" : "No"; // High blood pressure
  responses["BERLIN_10"] = triggerOSA ? randomInRange(40, 45) : randomInRange(35, 39); // Neck circumference

  return responses;
};

/**
 * FSS - Fatigue Severity Scale
 * 9 questions, 1-7 scale
 */
const generateFSSResponses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const responses: Record<string, number> = {};
  const baseScore = severity === "severe" ? 6 : severity === "mild" ? 2 : 4;

  for (let i = 1; i <= 9; i++) {
    responses[`FSS_${i}`] = Math.min(7, Math.max(1, baseScore + randomInRange(-1, 1)));
  }

  return responses;
};

/**
 * FOSQ-10 - Functional Outcomes of Sleep Questionnaire
 * 10 questions, 1-4 scale (4 = no difficulty)
 */
const generateFOSQ10Responses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const responses: Record<string, number> = {};
  // Higher scores = better function, so reverse for severity
  const baseScore = severity === "severe" ? 1 : severity === "mild" ? 4 : 2;

  for (let i = 1; i <= 10; i++) {
    responses[`FOSQ_${i}`] = Math.min(4, Math.max(1, baseScore + randomInRange(0, 1)));
  }

  return responses;
};

/**
 * DASS-21 - Depression Anxiety Stress Scale
 * 21 questions, 0-3 scale, 3 subscales (D, A, S)
 */
const generateDASS21Responses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const responses: Record<string, number> = {};
  const baseScore = severity === "severe" ? 2 : severity === "mild" ? 0 : 1;

  for (let i = 1; i <= 21; i++) {
    responses[`DASS_${i}`] = Math.min(3, Math.max(0, baseScore + randomInRange(0, 1)));
  }

  return responses;
};

/**
 * BPI - Brief Pain Inventory
 * 11 questions, 0-10 scale
 */
const generateBPIResponses = (
  hasPain: boolean,
  severity: keyof typeof SEVERITY_LEVELS
): Record<string, number> => {
  const responses: Record<string, number> = {};

  if (!hasPain) {
    // No pain - all zeros
    for (let i = 1; i <= 11; i++) {
      responses[`BPI_${i}`] = 0;
    }
    return responses;
  }

  const baseScore = severity === "severe" ? 7 : severity === "mild" ? 3 : 5;

  // BPI_1-4: Pain severity (worst, least, average, now)
  for (let i = 1; i <= 4; i++) {
    responses[`BPI_${i}`] = Math.min(10, Math.max(0, baseScore + randomInRange(-2, 2)));
  }

  // BPI_5-11: Pain interference
  for (let i = 5; i <= 11; i++) {
    responses[`BPI_${i}`] = Math.min(10, Math.max(0, baseScore + randomInRange(-2, 1)));
  }

  return responses;
};

/**
 * MEDAS - Mediterranean Diet Adherence Screener
 * 14 yes/no questions
 */
const generateMEDASResponses = (healthyDiet: boolean): Record<string, string> => {
  const responses: Record<string, string> = {};
  const yesProb = healthyDiet ? 0.7 : 0.3;

  for (let i = 1; i <= 14; i++) {
    responses[`MEDAS_${i}`] = Math.random() < yesProb ? "Yes" : "No";
  }

  return responses;
};

/**
 * MEQ - Morningness-Eveningness Questionnaire
 * 19 questions with varying scales
 */
const generateMEQResponses = (chronotype: string): Record<string, number> => {
  const responses: Record<string, number> = {};

  // MEQ scores: higher = morning type, lower = evening type
  const baseModifier = chronotype === "early_bird" ? 1 : chronotype === "night_owl" ? -1 : 0;

  // Questions have varying scales (mostly 1-4 or 1-5)
  for (let i = 1; i <= 19; i++) {
    // Approximate with 4-point scale, adjust for chronotype
    const base = 2 + baseModifier;
    responses[`MEQ_${i}`] = Math.min(4, Math.max(1, base + randomInRange(-1, 1)));
  }

  return responses;
};

/**
 * PROMIS Cognitive Function - Short Form
 * 6 questions, 1-5 scale (5 = no problems)
 */
const generatePROMISCogResponses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const responses: Record<string, number> = {};
  // Higher = better, so reverse for severity
  const baseScore = severity === "severe" ? 2 : severity === "mild" ? 5 : 3;

  for (let i = 1; i <= 6; i++) {
    responses[`PROMIS_COG_${i}`] = Math.min(5, Math.max(1, baseScore + randomInRange(-1, 1)));
  }

  return responses;
};

/**
 * Sleep Hygiene Index
 * 10 questions, 1-5 scale (1 = never, 5 = always - bad behaviors)
 */
const generateSleepHygieneResponses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const responses: Record<string, number> = {};
  // Higher = worse sleep hygiene
  const baseScore = severity === "severe" ? 4 : severity === "mild" ? 1 : 2;

  for (let i = 1; i <= 10; i++) {
    responses[`SH_${i}`] = Math.min(5, Math.max(1, baseScore + randomInRange(-1, 1)));
  }

  return responses;
};

/**
 * PSAS - Pre-Sleep Arousal Scale
 * 16 questions, 1-5 scale
 * 8 cognitive (PSAS_C1-8) + 8 somatic (PSAS_S1-8)
 */
const generatePSASResponses = (severity: keyof typeof SEVERITY_LEVELS): Record<string, number> => {
  const responses: Record<string, number> = {};
  const baseScore = severity === "severe" ? 4 : severity === "mild" ? 1 : 2;

  // Cognitive subscale
  for (let i = 1; i <= 8; i++) {
    responses[`PSAS_C${i}`] = Math.min(5, Math.max(1, baseScore + randomInRange(-1, 1)));
  }

  // Somatic subscale
  for (let i = 1; i <= 8; i++) {
    responses[`PSAS_S${i}`] = Math.min(5, Math.max(1, baseScore + randomInRange(-1, 1)));
  }

  return responses;
};

const generateGatewayTriggerResponses = (
  gateways: string[],
  severity: keyof typeof SEVERITY_LEVELS
): Record<string, string | number> => {
  const responses: Record<string, string | number> = {};

  // Q1: Overall sleep quality (1-10)
  if (gateways.includes("poor_sleep_quality")) {
    responses["1"] = randomInRange(1, 5);
  } else {
    responses["1"] = randomInRange(6, 10);
  }

  // Q3: Insomnia question
  if (gateways.includes("insomnia")) {
    responses["3"] = "Yes";
  } else {
    responses["3"] = "No";
  }

  // Q15: Depression (0-3 scale)
  if (gateways.includes("depression")) {
    responses["15"] = randomInRange(2, 3); // >= 2 triggers
  } else {
    responses["15"] = randomInRange(0, 1);
  }

  // Q16: Anxiety (0-3 scale)
  if (gateways.includes("anxiety")) {
    responses["16"] = randomInRange(2, 3); // >= 2 triggers
  } else {
    responses["16"] = randomInRange(0, 1);
  }

  // Q17: Excessive sleepiness (0-4 scale)
  if (gateways.includes("excessive_sleepiness")) {
    responses["17"] = randomInRange(3, 4); // >= 3 triggers
  } else {
    responses["17"] = randomInRange(0, 2);
  }

  // Q18: Cognitive issues
  if (gateways.includes("cognitive")) {
    responses["18"] = "Yes";
  } else {
    responses["18"] = "No";
  }

  // Q19: Snoring
  if (gateways.includes("osa")) {
    responses["19"] = "Yes";
  } else {
    responses["19"] = "No";
  }

  // Q20: Observed apnea
  if (gateways.includes("osa")) {
    responses["20"] = Math.random() > 0.5 ? "Yes" : "No";
  } else {
    responses["20"] = "No";
  }

  // Q22: Pain affects sleep
  if (gateways.includes("pain")) {
    responses["22"] = "Yes";
  } else {
    responses["22"] = "No";
  }

  // Q23: Pain severity (1-10)
  if (gateways.includes("pain")) {
    responses["23"] = randomInRange(4, 10); // >= 4 with Q22=Yes triggers
  } else {
    responses["23"] = randomInRange(1, 3);
  }

  // Q34: Diet impact
  if (gateways.includes("diet_impact")) {
    responses["34"] = "Yes";
  } else {
    responses["34"] = Math.random() > 0.7 ? "Yes" : "No";
  }

  return responses;
};

const generateSleepTimingResponses = (
  triggerSleepTiming: boolean,
  chronotype: string
): Record<string, string> => {
  const responses: Record<string, string> = {};

  let weekdayBedtime: string;
  let weekdayWake: string;
  let weekendBedtime: string;
  let weekendWake: string;

  if (chronotype === "night_owl") {
    weekdayBedtime = `${randomInRange(0, 2).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
    weekdayWake = `${randomInRange(8, 10).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  } else if (chronotype === "early_bird") {
    weekdayBedtime = `${randomInRange(21, 22).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
    weekdayWake = `${randomInRange(5, 6).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  } else {
    weekdayBedtime = `${randomInRange(22, 23).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
    weekdayWake = `${randomInRange(6, 7).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  }

  if (triggerSleepTiming) {
    // Add 1.5+ hour weekend difference
    const bedtimeHour = parseInt(weekdayBedtime.split(':')[0]) + 2;
    weekendBedtime = `${(bedtimeHour % 24).toString().padStart(2, '0')}:${weekdayBedtime.split(':')[1]}`;
    const wakeHour = parseInt(weekdayWake.split(':')[0]) + 2;
    weekendWake = `${wakeHour.toString().padStart(2, '0')}:${weekdayWake.split(':')[1]}`;
  } else {
    weekendBedtime = weekdayBedtime;
    weekendWake = weekdayWake;
  }

  responses["7"] = weekdayBedtime;
  responses["8"] = weekdayWake;
  responses["9"] = weekendBedtime;
  responses["10"] = weekendWake;

  return responses;
};

const generateConsensusSleepDiaryResponses = (
  phenotype: keyof typeof SLEEP_PHENOTYPES,
  severity: keyof typeof SEVERITY_LEVELS
): Record<string, string | number> => {
  const profile = SLEEP_PHENOTYPES[phenotype];
  const responses: Record<string, string | number> = {};

  // CSD_BEDTIME
  if (phenotype === "delayed_phase") {
    responses["CSD_BEDTIME"] = `${randomInRange(1, 3).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  } else {
    responses["CSD_BEDTIME"] = `${randomInRange(22, 23).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  }

  // CSD_LATENCY (minutes to fall asleep)
  if (phenotype === "tired_but_wired" && "sleepLatencyRange" in profile) {
    responses["CSD_LATENCY"] = randomInRange(profile.sleepLatencyRange[0], profile.sleepLatencyRange[1]);
  } else if (severity === "severe") {
    responses["CSD_LATENCY"] = randomInRange(30, 60);
  } else {
    responses["CSD_LATENCY"] = randomInRange(10, 25);
  }

  // CSD_AWAKENINGS
  if (phenotype === "fragmented_sleeper" && "awakeningsPerNight" in profile) {
    responses["CSD_AWAKENINGS"] = randomInRange(profile.awakeningsPerNight[0], profile.awakeningsPerNight[1]);
  } else if (severity === "severe") {
    responses["CSD_AWAKENINGS"] = randomInRange(3, 5);
  } else {
    responses["CSD_AWAKENINGS"] = randomInRange(0, 2);
  }

  // CSD_WASO (wake after sleep onset - minutes)
  if (phenotype === "fragmented_sleeper" && "wasoRange" in profile) {
    responses["CSD_WASO"] = randomInRange(profile.wasoRange[0], profile.wasoRange[1]);
  } else if (severity === "severe") {
    responses["CSD_WASO"] = randomInRange(30, 60);
  } else {
    responses["CSD_WASO"] = randomInRange(5, 20);
  }

  // CSD_OUT_BED (final wake time)
  if (phenotype === "early_terminator") {
    responses["CSD_OUT_BED"] = `${randomInRange(4, 5).toString().padStart(2, '0')}:${randomInRange(0, 30).toString().padStart(2, '0')}`;
  } else if (phenotype === "delayed_phase") {
    responses["CSD_OUT_BED"] = `${randomInRange(9, 11).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  } else {
    responses["CSD_OUT_BED"] = `${randomInRange(6, 8).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  }

  // CSD_QUALITY (1-5 rating)
  if (severity === "severe") {
    responses["CSD_QUALITY"] = randomInRange(1, 2);
  } else if (severity === "moderate") {
    responses["CSD_QUALITY"] = randomInRange(2, 3);
  } else {
    responses["CSD_QUALITY"] = randomInRange(3, 5);
  }

  return responses;
};

/**
 * Helper function to generate CSD responses based on gateways and severity
 * Used by generateAllTestUsers
 */
const generateCSDResponses = (
  gateways: string[],
  severity: { isiRange: number[]; phq9Range: number[]; gad7Range: number[]; essRange: number[] }
): Record<string, string | number> => {
  const responses: Record<string, string | number> = {};

  // Determine severity level
  const isSevere = severity.isiRange[0] >= 22;
  const isModerate = severity.isiRange[0] >= 15;
  const hasInsomnia = gateways.includes("insomnia") || gateways.includes("poor_sleep_quality");

  // CSD_BEDTIME - based on chronotype indicators
  if (gateways.includes("sleep_timing")) {
    responses["CSD_BEDTIME"] = `${randomInRange(1, 3).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  } else {
    responses["CSD_BEDTIME"] = `${randomInRange(22, 23).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  }

  // CSD_LATENCY - time to fall asleep
  if (hasInsomnia && isSevere) {
    responses["CSD_LATENCY"] = randomInRange(45, 90);
  } else if (hasInsomnia && isModerate) {
    responses["CSD_LATENCY"] = randomInRange(30, 60);
  } else if (hasInsomnia) {
    responses["CSD_LATENCY"] = randomInRange(20, 40);
  } else {
    responses["CSD_LATENCY"] = randomInRange(10, 25);
  }

  // CSD_AWAKENINGS - number of awakenings
  if (gateways.includes("osa") || isSevere) {
    responses["CSD_AWAKENINGS"] = randomInRange(4, 7);
  } else if (isModerate) {
    responses["CSD_AWAKENINGS"] = randomInRange(2, 4);
  } else {
    responses["CSD_AWAKENINGS"] = randomInRange(0, 2);
  }

  // CSD_WASO - wake after sleep onset
  if (isSevere) {
    responses["CSD_WASO"] = randomInRange(45, 90);
  } else if (isModerate) {
    responses["CSD_WASO"] = randomInRange(20, 45);
  } else {
    responses["CSD_WASO"] = randomInRange(5, 20);
  }

  // CSD_OUT_BED - wake time
  if (gateways.includes("sleep_timing")) {
    responses["CSD_OUT_BED"] = `${randomInRange(9, 11).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  } else if (gateways.includes("depression")) {
    responses["CSD_OUT_BED"] = `${randomInRange(4, 6).toString().padStart(2, '0')}:${randomInRange(0, 30).toString().padStart(2, '0')}`;
  } else {
    responses["CSD_OUT_BED"] = `${randomInRange(6, 8).toString().padStart(2, '0')}:${randomInRange(0, 59).toString().padStart(2, '0')}`;
  }

  // CSD_QUALITY - sleep quality rating (1-5)
  if (isSevere) {
    responses["CSD_QUALITY"] = randomInRange(1, 2);
  } else if (isModerate) {
    responses["CSD_QUALITY"] = randomInRange(2, 3);
  } else {
    responses["CSD_QUALITY"] = randomInRange(3, 5);
  }

  return responses;
};

// ============================================
// Main Generator Functions
// ============================================

/**
 * Generate a single test user with all their data
 */
export const generateSingleTestUser = mutation({
  args: {
    template: v.object({
      prefix: v.string(),
      phenotype: v.string(),
      severity: v.string(),
      ageGroup: v.number(),
      gender: v.string(),
      bmiCategory: v.number(),
      chronotype: v.string(),
      gateways: v.array(v.string()),
      description: v.string(),
    }),
    index: v.number(),
    password: v.optional(v.string()),
    generateResponses: v.optional(v.boolean()),
    generateHealthData: v.optional(v.boolean()),
    daysToSimulate: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { template, index, password = "test123", generateResponses = true, generateHealthData = true, daysToSimulate = 7 } = args;

    const now = Date.now();
    const username = `${template.prefix}_${index.toString().padStart(3, '0')}`;
    const email = `${username}@test.zoesleep.com`;

    // Get demographic details
    const ageGroup = DEMOGRAPHICS.ageGroups[template.ageGroup];
    const bmiCategory = DEMOGRAPHICS.bmiCategories[template.bmiCategory];

    // Calculate age and birth year
    const age = randomInRange(ageGroup.range[0], ageGroup.range[1]);
    const birthYear = new Date().getFullYear() - age;

    // Calculate height and weight from BMI
    const heightCm = template.gender === "male" ? randomInRange(170, 190) : randomInRange(155, 175);
    const bmi = randomFloat(bmiCategory.range[0], bmiCategory.range[1], 1);
    const weightKg = Math.round(bmi * Math.pow(heightCm / 100, 2));

    // Check if user already exists
    const existingUser = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();

    if (existingUser) {
      return { userId: existingUser._id, username, created: false, message: "User already exists" };
    }

    // Create the user
    const userId = await ctx.db.insert("users", {
      username,
      password_hash: hashPassword(password),
      email,
      role: "patient",
      current_day: 1,
      started_at: now - (daysToSimulate * 24 * 60 * 60 * 1000), // Started N days ago
      last_accessed: now,
      created_at: now,
      onboarding_completed: true,
      onboarding_completed_at: now - (daysToSimulate * 24 * 60 * 60 * 1000),
      full_name: `Test User ${index}`,
      measurement_system: "Metric",
      height_cm: heightCm,
      weight_kg: weightKg,
      gender: template.gender,
      birth_year: birthYear,
      developer_mode: true, // Enable dev mode for testing
    });

    // Store phenotype and metadata in user_sleep_narrative
    await ctx.db.insert("user_sleep_narrative", {
      user_id: userId,
      phenotype: template.phenotype,
      phenotype_confidence: 85,
      phenotype_description: SLEEP_PHENOTYPES[template.phenotype as keyof typeof SLEEP_PHENOTYPES].description,
      key_patterns_json: JSON.stringify(template.gateways),
      leverage_points_json: JSON.stringify([]),
      narrative_title: `The ${SLEEP_PHENOTYPES[template.phenotype as keyof typeof SLEEP_PHENOTYPES].name}`,
      narrative_text: template.description,
      week_number: 1,
      data_points_used: 0,
      generated_at: now,
      updated_at: now,
    });

    // Store cohort membership
    await ctx.db.insert("user_cohort_memberships", {
      user_id: userId,
      cohort_hash: `${ageGroup.bracket}_${template.gender}_${template.chronotype}`,
      age_bracket: ageGroup.bracket,
      gender: template.gender,
      life_stage: ageGroup.lifeStage,
      work_pattern: ageGroup.workPattern,
      primary_gateway: template.gateways[0] || "none",
      chronotype: template.chronotype,
      activity_level: "moderate",
      cohort_dimensions_json: JSON.stringify({
        age_bracket: ageGroup.bracket,
        gender: template.gender,
        chronotype: template.chronotype,
        bmi_category: bmiCategory.category,
        phenotype: template.phenotype,
        severity: template.severity,
      }),
      cohort_size: 100, // Placeholder
      created_at: now,
      updated_at: now,
    });

    // Generate questionnaire responses
    if (generateResponses) {
      const severity = template.severity as keyof typeof SEVERITY_LEVELS;
      const phenotype = template.phenotype as keyof typeof SLEEP_PHENOTYPES;

      // DEMOGRAPHIC RESPONSES (D1-D6) - Required for physician dashboard
      // D1 = Name
      await ctx.db.insert("user_assessment_responses", {
        user_id: userId,
        question_id: "D1",
        response_value: `Test User ${index}`,
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      // D2 = Date of Birth (ISO format)
      const dob = new Date(birthYear, Math.floor(Math.random() * 12), Math.floor(Math.random() * 28) + 1);
      await ctx.db.insert("user_assessment_responses", {
        user_id: userId,
        question_id: "D2",
        response_value: dob.toISOString().split('T')[0], // YYYY-MM-DD
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      // D4 = Sex
      await ctx.db.insert("user_assessment_responses", {
        user_id: userId,
        question_id: "D4",
        response_value: template.gender === "male" ? "Male" : "Female",
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      // D5 = Height
      await ctx.db.insert("user_assessment_responses", {
        user_id: userId,
        question_id: "D5",
        response_value: `${heightCm} cm`,
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      // D6 = Weight
      await ctx.db.insert("user_assessment_responses", {
        user_id: userId,
        question_id: "D6",
        response_value: `${weightKg} kg`,
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      // Gateway trigger responses
      const gatewayResponses = generateGatewayTriggerResponses(template.gateways, severity);
      for (const [questionId, value] of Object.entries(gatewayResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_value: typeof value === "string" ? value : undefined,
          response_number: typeof value === "number" ? value : undefined,
          day_number: 1,
          created_at: now,
          updated_at: now,
        });
      }

      // Sleep timing responses
      const timingResponses = generateSleepTimingResponses(template.gateways.includes("sleep_timing"), template.chronotype);
      for (const [questionId, value] of Object.entries(timingResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_value: value,
          day_number: 1,
          created_at: now,
          updated_at: now,
        });
      }

      // ISI responses
      if (template.gateways.includes("insomnia") || template.gateways.includes("poor_sleep_quality")) {
        const isiResponses = generateISIResponses(severity);
        for (const [questionId, value] of Object.entries(isiResponses)) {
          await ctx.db.insert("user_assessment_responses", {
            user_id: userId,
            question_id: questionId,
            response_number: value,
            day_number: 8, // ISI is typically on expansion day
            created_at: now,
            updated_at: now,
          });
        }
      }

      // PHQ-9 responses
      if (template.gateways.includes("depression")) {
        const phq9Responses = generatePHQ9Responses(severity);
        for (const [questionId, value] of Object.entries(phq9Responses)) {
          await ctx.db.insert("user_assessment_responses", {
            user_id: userId,
            question_id: questionId,
            response_number: value,
            day_number: 9,
            created_at: now,
            updated_at: now,
          });
        }
      }

      // GAD-7 responses
      if (template.gateways.includes("anxiety")) {
        const gad7Responses = generateGAD7Responses(severity);
        for (const [questionId, value] of Object.entries(gad7Responses)) {
          await ctx.db.insert("user_assessment_responses", {
            user_id: userId,
            question_id: questionId,
            response_number: value,
            day_number: 9,
            created_at: now,
            updated_at: now,
          });
        }
      }

      // ESS responses
      if (template.gateways.includes("excessive_sleepiness")) {
        const essResponses = generateESSResponses(severity);
        for (const [questionId, value] of Object.entries(essResponses)) {
          await ctx.db.insert("user_assessment_responses", {
            user_id: userId,
            question_id: questionId,
            response_number: value,
            day_number: 10,
            created_at: now,
            updated_at: now,
          });
        }
      }

      // STOP-BANG responses
      if (template.gateways.includes("osa")) {
        const stopBangResponses = generateSTOPBANGResponses(true, ageGroup, template.gender, bmiCategory);
        for (const [questionId, value] of Object.entries(stopBangResponses)) {
          await ctx.db.insert("user_assessment_responses", {
            user_id: userId,
            question_id: questionId,
            response_value: value,
            day_number: 10,
            is_derived: false,
            created_at: now,
            updated_at: now,
          });
        }
      }

      // Store gateway states
      for (const gatewayId of template.gateways) {
        await ctx.db.insert("user_gateway_states", {
          user_id: userId,
          gateway_id: gatewayId,
          triggered: true,
          triggered_at: now,
          last_evaluated_at: now,
        });
      }
    }

    // Generate health/sleep data
    if (generateHealthData) {
      for (let day = 0; day < daysToSimulate; day++) {
        const date = new Date(now - (daysToSimulate - day - 1) * 24 * 60 * 60 * 1000);
        const dateStr = date.toISOString().split('T')[0];

        const phenotype = template.phenotype as keyof typeof SLEEP_PHENOTYPES;
        const severity = template.severity as keyof typeof SEVERITY_LEVELS;

        // Generate CSD responses for this day
        const csdResponses = generateConsensusSleepDiaryResponses(phenotype, severity);

        // Store CSD responses
        for (const [questionId, value] of Object.entries(csdResponses)) {
          await ctx.db.insert("user_assessment_responses", {
            user_id: userId,
            question_id: questionId,
            response_value: typeof value === "string" ? value : undefined,
            response_number: typeof value === "number" ? value : undefined,
            day_number: day + 1,
            created_at: date.getTime(),
            updated_at: date.getTime(),
          });
        }

        // Calculate sleep metrics from CSD
        const bedtimeStr = csdResponses["CSD_BEDTIME"] as string;
        const outBedStr = csdResponses["CSD_OUT_BED"] as string;
        const latency = csdResponses["CSD_LATENCY"] as number;
        const waso = csdResponses["CSD_WASO"] as number;

        // Parse times
        const [bedHour, bedMin] = bedtimeStr.split(':').map(Number);
        const [wakeHour, wakeMin] = outBedStr.split(':').map(Number);

        // Calculate time in bed (handle overnight)
        let timeInBed = (wakeHour * 60 + wakeMin) - (bedHour * 60 + bedMin);
        if (timeInBed < 0) timeInBed += 24 * 60;

        const totalSleep = timeInBed - latency - waso;
        const efficiency = Math.round((totalSleep / timeInBed) * 100);

        // Store sleep data
        await ctx.db.insert("user_sleep_data", {
          user_id: userId,
          date: dateStr,
          total_sleep_mins: totalSleep,
          sleep_efficiency: efficiency,
          sleep_latency_mins: latency,
          awake_mins: waso,
          interruptions_count: csdResponses["CSD_AWAKENINGS"] as number,
          deep_sleep_mins: Math.round(totalSleep * 0.2),
          light_sleep_mins: Math.round(totalSleep * 0.5),
          rem_sleep_mins: Math.round(totalSleep * 0.25),
          synced_at: date.getTime(),
          primary_source: "Test Generator",
        });
      }
    }

    return {
      userId,
      username,
      email,
      created: true,
      phenotype: template.phenotype,
      severity: template.severity,
      gateways: template.gateways,
      demographics: {
        age,
        birthYear,
        gender: template.gender,
        heightCm,
        weightKg,
        bmi,
        bmiCategory: bmiCategory.category,
        chronotype: template.chronotype,
      },
    };
  },
});

/**
 * Generate all 100+ test users
 */
export const generateAllTestUsers = mutation({
  args: {
    password: v.optional(v.string()),
    startIndex: v.optional(v.number()),
    count: v.optional(v.number()),
    daysToSimulate: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { password = "test123", startIndex = 0, count, daysToSimulate = 7 } = args;

    const templates = generateTestUserTemplates();
    const templatesToProcess = count ? templates.slice(startIndex, startIndex + count) : templates.slice(startIndex);

    const results = [];

    for (let i = 0; i < templatesToProcess.length; i++) {
      const template = templatesToProcess[i];
      const index = startIndex + i + 1;

      try {
        // Generate user (we need to call mutation directly here)
        const now = Date.now();
        const username = `${template.prefix}_${index.toString().padStart(3, '0')}`;
        const email = `${username}@test.zoesleep.com`;

        const existingUser = await ctx.db
          .query("users")
          .withIndex("by_username", (q) => q.eq("username", username))
          .first();

        if (existingUser) {
          results.push({ username, created: false, message: "Already exists" });
          continue;
        }

        const ageGroup = DEMOGRAPHICS.ageGroups[template.ageGroup];
        const bmiCategory = DEMOGRAPHICS.bmiCategories[template.bmiCategory];
        const age = randomInRange(ageGroup.range[0], ageGroup.range[1]);
        const birthYear = new Date().getFullYear() - age;
        const heightCm = template.gender === "male" ? randomInRange(170, 190) : randomInRange(155, 175);
        const bmi = randomFloat(bmiCategory.range[0], bmiCategory.range[1], 1);
        const weightKg = Math.round(bmi * Math.pow(heightCm / 100, 2));

        const userId = await ctx.db.insert("users", {
          username,
          password_hash: hashPassword(password),
          email,
          role: "patient",
          current_day: daysToSimulate,
          started_at: now - (daysToSimulate * 24 * 60 * 60 * 1000),
          last_accessed: now,
          created_at: now,
          onboarding_completed: true,
          onboarding_completed_at: now - (daysToSimulate * 24 * 60 * 60 * 1000),
          full_name: `Test User ${index}`,
          measurement_system: "Metric",
          height_cm: heightCm,
          weight_kg: weightKg,
          gender: template.gender,
          birth_year: birthYear,
          developer_mode: true,
        });

        // Insert gateway states
        for (const gatewayId of template.gateways) {
          await ctx.db.insert("user_gateway_states", {
            user_id: userId,
            gateway_id: gatewayId,
            triggered: true,
            triggered_at: now - (daysToSimulate * 24 * 60 * 60 * 1000),
            last_evaluated_at: now,
          });
        }

        // Insert phenotype data into user_sleep_narrative
        const phenotypeData = SLEEP_PHENOTYPES[template.phenotype as keyof typeof SLEEP_PHENOTYPES];
        if (phenotypeData) {
          await ctx.db.insert("user_sleep_narrative", {
            user_id: userId,
            phenotype: template.phenotype,
            phenotype_confidence: 85 + Math.floor(Math.random() * 10),
            phenotype_description: phenotypeData.description || `${phenotypeData.name} - ${template.severity} severity`,
            key_patterns_json: JSON.stringify(template.gateways),
            leverage_points_json: JSON.stringify([]),
            narrative_title: phenotypeData.name,
            narrative_text: template.description,
            week_number: Math.ceil(daysToSimulate / 7),
            data_points_used: daysToSimulate * 8,
            generated_at: now,
            updated_at: now,
          });
        }

        // Insert DEMOGRAPHIC responses (D1-D6) - Required for physician dashboard
        // D1 = Name
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: "D1",
          response_value: `Test User ${index}`,
          day_number: 1,
          created_at: now,
          updated_at: now,
        });
        // D2 = Date of Birth
        const dob = new Date(birthYear, Math.floor(Math.random() * 12), Math.floor(Math.random() * 28) + 1);
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: "D2",
          response_value: dob.toISOString().split('T')[0],
          day_number: 1,
          created_at: now,
          updated_at: now,
        });
        // D4 = Sex
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: "D4",
          response_value: template.gender === "male" ? "Male" : "Female",
          day_number: 1,
          created_at: now,
          updated_at: now,
        });
        // D5 = Height
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: "D5",
          response_value: `${heightCm} cm`,
          day_number: 1,
          created_at: now,
          updated_at: now,
        });
        // D6 = Weight
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: "D6",
          response_value: `${weightKg} kg`,
          day_number: 1,
          created_at: now,
          updated_at: now,
        });

        // Generate some basic questionnaire responses for each day
        const severityLevel = SEVERITY_LEVELS[template.severity as keyof typeof SEVERITY_LEVELS];
        for (let day = 1; day <= daysToSimulate; day++) {
          const responses = generateGatewayTriggerResponses(template.gateways, template.severity as keyof typeof SEVERITY_LEVELS);
          const csdResponses = generateCSDResponses(template.gateways, severityLevel);

          // Store assessment responses
          for (const [questionId, value] of Object.entries(responses)) {
            await ctx.db.insert("user_assessment_responses", {
              user_id: userId,
              question_id: questionId,
              response_value: typeof value === "string" ? value : undefined,
              response_number: typeof value === "number" ? value : undefined,
              day_number: day,
              created_at: now - ((daysToSimulate - day) * 24 * 60 * 60 * 1000),
              updated_at: now - ((daysToSimulate - day) * 24 * 60 * 60 * 1000),
            });
          }

          // Store CSD responses
          for (const [questionId, value] of Object.entries(csdResponses)) {
            await ctx.db.insert("user_assessment_responses", {
              user_id: userId,
              question_id: questionId,
              response_value: typeof value === "string" ? value : undefined,
              response_number: typeof value === "number" ? value : undefined,
              day_number: day,
              created_at: now - ((daysToSimulate - day) * 24 * 60 * 60 * 1000),
              updated_at: now - ((daysToSimulate - day) * 24 * 60 * 60 * 1000),
            });
          }

          // Compute and store sleep data from CSD responses
          const bedtimeStr = csdResponses["CSD_BEDTIME"] as string;
          const outBedStr = csdResponses["CSD_OUT_BED"] as string;
          const latency = csdResponses["CSD_LATENCY"] as number;
          const waso = csdResponses["CSD_WASO"] as number;

          const [bedHour, bedMin] = bedtimeStr.split(':').map(Number);
          const [wakeHour, wakeMin] = outBedStr.split(':').map(Number);

          let timeInBed = (wakeHour * 60 + wakeMin) - (bedHour * 60 + bedMin);
          if (timeInBed < 0) timeInBed += 24 * 60;

          const totalSleep = Math.max(0, timeInBed - latency - waso);
          const efficiency = timeInBed > 0 ? Math.round((totalSleep / timeInBed) * 100) : 0;

          const dateStr = new Date(now - ((daysToSimulate - day) * 24 * 60 * 60 * 1000)).toISOString().split('T')[0];

          await ctx.db.insert("user_sleep_data", {
            user_id: userId,
            date: dateStr,
            total_sleep_mins: totalSleep,
            sleep_efficiency: efficiency,
            sleep_latency_mins: latency,
            awake_mins: waso,
            interruptions_count: csdResponses["CSD_AWAKENINGS"] as number,
            deep_sleep_mins: Math.round(totalSleep * 0.2),
            light_sleep_mins: Math.round(totalSleep * 0.5),
            rem_sleep_mins: Math.round(totalSleep * 0.25),
            synced_at: now - ((daysToSimulate - day) * 24 * 60 * 60 * 1000),
            primary_source: "Test Generator",
          });
        }

        results.push({
          username,
          userId,
          created: true,
          phenotype: template.phenotype,
          gateways: template.gateways,
        });
      } catch (error) {
        results.push({
          username: `${template.prefix}_${index.toString().padStart(3, '0')}`,
          created: false,
          error: String(error),
        });
      }
    }

    return {
      totalTemplates: templates.length,
      processed: templatesToProcess.length,
      results,
      summary: {
        created: results.filter(r => r.created).length,
        skipped: results.filter(r => !r.created).length,
      },
    };
  },
});

/**
 * Get test user templates (for inspection)
 */
export const getTestUserTemplates = query({
  args: {},
  handler: async () => {
    return {
      templates: generateTestUserTemplates(),
      phenotypes: Object.keys(SLEEP_PHENOTYPES).map(key => ({
        id: key,
        ...SLEEP_PHENOTYPES[key as keyof typeof SLEEP_PHENOTYPES],
      })),
      demographics: DEMOGRAPHICS,
      severityLevels: SEVERITY_LEVELS,
      totalTemplates: generateTestUserTemplates().length,
    };
  },
});

/**
 * Delete all test users (cleanup)
 */
export const deleteAllTestUsers = mutation({
  args: {
    confirmDelete: v.boolean(),
  },
  handler: async (ctx, args) => {
    if (!args.confirmDelete) {
      return { deleted: 0, message: "Set confirmDelete to true to delete test users" };
    }

    // Find all test users (username starts with "test_")
    const testUsers = await ctx.db
      .query("users")
      .filter((q) => q.eq(q.field("developer_mode"), true))
      .collect();

    let deleted = 0;

    for (const user of testUsers) {
      if (user.username.startsWith("test_")) {
        // Delete related data
        const responses = await ctx.db
          .query("user_assessment_responses")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .collect();
        for (const r of responses) {
          await ctx.db.delete(r._id);
        }

        const sleepData = await ctx.db
          .query("user_sleep_data")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .collect();
        for (const s of sleepData) {
          await ctx.db.delete(s._id);
        }

        const gatewayStates = await ctx.db
          .query("user_gateway_states")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .collect();
        for (const g of gatewayStates) {
          await ctx.db.delete(g._id);
        }

        const narratives = await ctx.db
          .query("user_sleep_narrative")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .collect();
        for (const n of narratives) {
          await ctx.db.delete(n._id);
        }

        const cohorts = await ctx.db
          .query("user_cohort_memberships")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .collect();
        for (const c of cohorts) {
          await ctx.db.delete(c._id);
        }

        // Delete user
        await ctx.db.delete(user._id);
        deleted++;
      }
    }

    return { deleted, message: `Deleted ${deleted} test users and their related data` };
  },
});

/**
 * Get statistics about test users
 */
export const getTestUserStats = query({
  args: {},
  handler: async (ctx) => {
    const testUsers = await ctx.db
      .query("users")
      .filter((q) => q.eq(q.field("developer_mode"), true))
      .collect();

    const testUsersList = testUsers.filter(u => u.username.startsWith("test_"));

    const phenotypeCounts: Record<string, number> = {};
    const gatewayCounts: Record<string, number> = {};
    const ageBracketCounts: Record<string, number> = {};
    const genderCounts: Record<string, number> = {};

    for (const user of testUsersList) {
      // Get narrative for phenotype
      const narrative = await ctx.db
        .query("user_sleep_narrative")
        .withIndex("by_user", (q) => q.eq("user_id", user._id))
        .first();

      if (narrative) {
        phenotypeCounts[narrative.phenotype] = (phenotypeCounts[narrative.phenotype] || 0) + 1;
        const patterns = JSON.parse(narrative.key_patterns_json);
        for (const gateway of patterns) {
          gatewayCounts[gateway] = (gatewayCounts[gateway] || 0) + 1;
        }
      }

      // Get cohort for demographics
      const cohort = await ctx.db
        .query("user_cohort_memberships")
        .withIndex("by_user", (q) => q.eq("user_id", user._id))
        .first();

      if (cohort) {
        if (cohort.age_bracket) {
          ageBracketCounts[cohort.age_bracket] = (ageBracketCounts[cohort.age_bracket] || 0) + 1;
        }
        if (cohort.gender) {
          genderCounts[cohort.gender] = (genderCounts[cohort.gender] || 0) + 1;
        }
      }
    }

    return {
      totalTestUsers: testUsersList.length,
      byPhenotype: phenotypeCounts,
      byGateway: gatewayCounts,
      byAge: ageBracketCounts,
      byGender: genderCounts,
    };
  },
});

/**
 * Repair existing test users - add missing demographic responses (D1-D6)
 * Run this to fix existing test users that were created without demographic responses
 */
export const repairTestUserDemographics = mutation({
  args: {},
  handler: async (ctx) => {
    const testUsers = await ctx.db
      .query("users")
      .filter((q) => q.eq(q.field("developer_mode"), true))
      .collect();

    const testUsersList = testUsers.filter(u => u.username.startsWith("test_"));

    let repaired = 0;
    let alreadyHadData = 0;
    const now = Date.now();

    for (const user of testUsersList) {
      // Check if D1 already exists
      const existingD1 = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) => q.eq("user_id", user._id).eq("question_id", "D1"))
        .first();

      if (existingD1) {
        alreadyHadData++;
        continue;
      }

      // Get user's profile data to populate demographics
      const fullName = user.full_name || user.username;
      const birthYear = user.birth_year || 1990;
      const gender = user.gender || "male";
      const heightCm = user.height_cm || 170;
      const weightKg = user.weight_kg || 70;

      // D1 = Name
      await ctx.db.insert("user_assessment_responses", {
        user_id: user._id,
        question_id: "D1",
        response_value: fullName,
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      // D2 = Date of Birth
      const dob = new Date(birthYear, Math.floor(Math.random() * 12), Math.floor(Math.random() * 28) + 1);
      await ctx.db.insert("user_assessment_responses", {
        user_id: user._id,
        question_id: "D2",
        response_value: dob.toISOString().split('T')[0],
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      // D4 = Sex
      await ctx.db.insert("user_assessment_responses", {
        user_id: user._id,
        question_id: "D4",
        response_value: gender === "male" ? "Male" : "Female",
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      // D5 = Height
      await ctx.db.insert("user_assessment_responses", {
        user_id: user._id,
        question_id: "D5",
        response_value: `${heightCm} cm`,
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      // D6 = Weight
      await ctx.db.insert("user_assessment_responses", {
        user_id: user._id,
        question_id: "D6",
        response_value: `${weightKg} kg`,
        day_number: 1,
        created_at: now,
        updated_at: now,
      });

      repaired++;
    }

    return {
      repaired,
      alreadyHadData,
      total: testUsersList.length,
      message: `Repaired ${repaired} test users, ${alreadyHadData} already had demographic data`,
    };
  },
});

// ============================================
// Comprehensive Dashboard Tester
// ============================================

/**
 * Generate a complete test user with ALL data populated for dashboard testing.
 * This creates a user with:
 * - Full 14-day journey data
 * - All health pillar responses
 * - Clinical scores (ISI, PHQ-9, GAD-7, ESS, STOP-BANG)
 * - Expansion pack data based on triggered gateways
 * - Sleep metrics computed
 */
export const generateCompleteDashboardTestUser = mutation({
  args: {
    name: v.string(),
    gateways: v.array(v.string()), // Which gateways to trigger
    severity: v.optional(v.string()), // mild, moderate, severe
    daysCompleted: v.optional(v.number()), // How many days (1-14)
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const severity = args.severity || "moderate";
    const daysCompleted = Math.min(args.daysCompleted || 14, 14);
    const username = `dash_test_${Date.now()}`;
    const email = `${username}@test.zoesleep.com`;

    // Demographics
    const age = 35 + Math.floor(Math.random() * 30);
    const birthYear = new Date().getFullYear() - age;
    const gender = Math.random() > 0.5 ? "male" : "female";
    const heightCm = gender === "male" ? 175 : 165;
    const weightKg = gender === "male" ? 80 : 65;

    // Create user
    const userId = await ctx.db.insert("users", {
      username,
      password_hash: "test",
      email,
      role: "patient",
      current_day: daysCompleted,
      started_at: now - (daysCompleted * 24 * 60 * 60 * 1000),
      last_accessed: now,
      created_at: now,
      onboarding_completed: daysCompleted >= 14,
      onboarding_completed_at: daysCompleted >= 14 ? now : undefined,
      full_name: args.name,
      measurement_system: "Metric",
      height_cm: heightCm,
      weight_kg: weightKg,
      gender: gender,
      birth_year: birthYear,
      developer_mode: true,
    });

    // Insert demographic responses (D1-D6)
    const dob = new Date(birthYear, 5, 15);
    const demographicResponses = [
      { question_id: "D1", response_value: args.name },
      { question_id: "D2", response_value: dob.toISOString().split('T')[0] },
      { question_id: "D4", response_value: gender === "male" ? "Male" : "Female" },
      { question_id: "D5", response_value: `${heightCm} cm` },
      { question_id: "D6", response_value: `${weightKg} kg` },
    ];

    for (const resp of demographicResponses) {
      await ctx.db.insert("user_assessment_responses", {
        user_id: userId,
        question_id: resp.question_id,
        response_value: resp.response_value,
        day_number: 1,
        created_at: now,
        updated_at: now,
      });
    }

    // Insert gateway states
    for (const gatewayId of args.gateways) {
      await ctx.db.insert("user_gateway_states", {
        user_id: userId,
        gateway_id: gatewayId,
        triggered: true,
        triggered_at: now - (daysCompleted * 24 * 60 * 60 * 1000),
        last_evaluated_at: now,
      });
    }

    // Generate Health Pillar responses
    const severityMultiplier = severity === "mild" ? 0.3 : severity === "severe" ? 0.9 : 0.6;

    // Social Pillar questions (sample)
    const socialQuestions = ["1", "2", "3", "4", "5"];
    for (const qId of socialQuestions) {
      await ctx.db.insert("user_assessment_responses", {
        user_id: userId,
        question_id: qId,
        response_number: Math.floor(3 + Math.random() * 7),
        day_number: 1,
        created_at: now,
        updated_at: now,
      });
    }

    // Metabolic Pillar questions (sample)
    const metabolicQuestions = ["6", "7", "8", "9", "10", "11"];
    for (const qId of metabolicQuestions) {
      await ctx.db.insert("user_assessment_responses", {
        user_id: userId,
        question_id: qId,
        response_number: Math.floor(2 + Math.random() * 8),
        day_number: 1,
        created_at: now,
        updated_at: now,
      });
    }

    // PSQI - Pittsburgh Sleep Quality Index (CORE assessment, Days 1-2)
    // Unlike ISI/PHQ-9/GAD-7, PSQI is part of core intake, not expansion
    const psqiResponses = generatePSQIResponses(severity as keyof typeof SEVERITY_LEVELS);

    // Day 1: PSQI Part 1 (core_sleep_quality_part1)
    const psqiDay1Questions = ["PSQI_1", "PSQI_2", "PSQI_3", "PSQI_4"];
    for (const questionId of psqiDay1Questions) {
      const value = psqiResponses[questionId];
      if (value !== undefined) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_value: typeof value === "string" ? value : undefined,
          response_number: typeof value === "number" ? value : undefined,
          day_number: 1,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // Day 2: PSQI Part 2 (core_sleep_quality_part2)
    const psqiDay2Questions = ["PSQI_5a", "PSQI_5b", "PSQI_5c", "PSQI_5d", "PSQI_5e",
                               "PSQI_5f", "PSQI_5g", "PSQI_5h", "PSQI_5i", "PSQI_5j",
                               "PSQI_6", "PSQI_7", "PSQI_8", "PSQI_9"];
    for (const questionId of psqiDay2Questions) {
      const value = psqiResponses[questionId];
      if (value !== undefined) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_value: typeof value === "string" ? value : undefined,
          response_number: typeof value === "number" ? value : undefined,
          day_number: 2,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // Clinical Questionnaires based on gateways
    // ISI (Insomnia Severity Index)
    if (args.gateways.includes("insomnia") || args.gateways.includes("poor_sleep_quality")) {
      const isiScores = severity === "mild" ? [1, 1, 1, 1, 1, 1, 1] :
                        severity === "severe" ? [3, 3, 3, 3, 3, 3, 3] :
                        [2, 2, 2, 2, 2, 2, 2];
      for (let i = 0; i < 7; i++) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: `ISI_${i + 1}`,
          response_number: isiScores[i],
          day_number: 8,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // PHQ-9 (Depression)
    if (args.gateways.includes("depression")) {
      const phqScores = severity === "mild" ? [1, 0, 1, 0, 1, 0, 0, 0, 0] :
                        severity === "severe" ? [3, 2, 3, 2, 2, 2, 2, 1, 1] :
                        [2, 1, 2, 1, 1, 1, 1, 0, 0];
      for (let i = 0; i < 9; i++) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: `PHQ9_${i + 1}`,
          response_number: phqScores[i],
          day_number: 9,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // GAD-7 (Anxiety)
    if (args.gateways.includes("anxiety")) {
      const gadScores = severity === "mild" ? [1, 1, 0, 1, 0, 0, 0] :
                        severity === "severe" ? [3, 3, 2, 2, 2, 2, 2] :
                        [2, 2, 1, 1, 1, 1, 1];
      for (let i = 0; i < 7; i++) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: `GAD7_${i + 1}`,
          response_number: gadScores[i],
          day_number: 9,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // ESS (Excessive Sleepiness)
    if (args.gateways.includes("excessive_sleepiness")) {
      const essScores = severity === "mild" ? [1, 1, 0, 1, 2, 1, 0, 1] :
                        severity === "severe" ? [3, 3, 2, 3, 3, 3, 2, 3] :
                        [2, 2, 1, 2, 2, 2, 1, 2];
      for (let i = 0; i < 8; i++) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: `ESS_${i + 1}`,
          response_number: essScores[i],
          day_number: 10,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // STOP-BANG (OSA)
    if (args.gateways.includes("osa")) {
      const sbResponses = severity === "severe" ?
        ["Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"] :
        ["Yes", "No", "Yes", "No", "Yes", "No", "No", "Yes"];
      for (let i = 0; i < 8; i++) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: `SB_${i + 1}`,
          response_value: sbResponses[i],
          day_number: 10,
          created_at: now,
          updated_at: now,
        });
      }

      // Berlin Questionnaire (also for OSA)
      const berlinResponses = generateBerlinResponses(true, weightKg / Math.pow(heightCm / 100, 2) > 30);
      for (const [questionId, value] of Object.entries(berlinResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_value: typeof value === "string" ? value : undefined,
          response_number: typeof value === "number" ? value : undefined,
          day_number: 10,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // Expansion questionnaires for insomnia/poor sleep quality
    // Note: PSQI is now generated as CORE (Days 1-2), not here
    if (args.gateways.includes("insomnia") || args.gateways.includes("poor_sleep_quality")) {
      // DBAS-16 (Dysfunctional Beliefs about Sleep)
      const dbasResponses = generateDBAS16Responses(severity as keyof typeof SEVERITY_LEVELS);
      for (const [questionId, value] of Object.entries(dbasResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_number: value,
          day_number: 8,
          created_at: now,
          updated_at: now,
        });
      }

      // Sleep Hygiene Index
      const shResponses = generateSleepHygieneResponses(severity as keyof typeof SEVERITY_LEVELS);
      for (const [questionId, value] of Object.entries(shResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_number: value,
          day_number: 9,
          created_at: now,
          updated_at: now,
        });
      }

      // PSAS (Pre-Sleep Arousal Scale)
      const psasResponses = generatePSASResponses(severity as keyof typeof SEVERITY_LEVELS);
      for (const [questionId, value] of Object.entries(psasResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_number: value,
          day_number: 9,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // FSS & FOSQ-10 (for excessive sleepiness)
    if (args.gateways.includes("excessive_sleepiness")) {
      const fssResponses = generateFSSResponses(severity as keyof typeof SEVERITY_LEVELS);
      for (const [questionId, value] of Object.entries(fssResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_number: value,
          day_number: 10,
          created_at: now,
          updated_at: now,
        });
      }

      const fosqResponses = generateFOSQ10Responses(severity as keyof typeof SEVERITY_LEVELS);
      for (const [questionId, value] of Object.entries(fosqResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_number: value,
          day_number: 10,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // DASS-21 (for anxiety/depression)
    if (args.gateways.includes("anxiety") || args.gateways.includes("depression")) {
      const dassResponses = generateDASS21Responses(severity as keyof typeof SEVERITY_LEVELS);
      for (const [questionId, value] of Object.entries(dassResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_number: value,
          day_number: 9,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // BPI (for pain gateway)
    if (args.gateways.includes("pain")) {
      const bpiResponses = generateBPIResponses(true, severity as keyof typeof SEVERITY_LEVELS);
      for (const [questionId, value] of Object.entries(bpiResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_number: value,
          day_number: 11,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // MEDAS (for diet impact gateway)
    if (args.gateways.includes("diet_impact")) {
      const medasResponses = generateMEDASResponses(severity === "mild");
      for (const [questionId, value] of Object.entries(medasResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_value: value,
          day_number: 11,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // MEQ (for sleep timing gateway)
    if (args.gateways.includes("sleep_timing")) {
      const chronotype = Math.random() > 0.5 ? "night_owl" : "early_bird";
      const meqResponses = generateMEQResponses(chronotype);
      for (const [questionId, value] of Object.entries(meqResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_number: value,
          day_number: 12,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // PROMIS Cognitive (for cognitive gateway)
    if (args.gateways.includes("cognitive")) {
      const promisCogResponses = generatePROMISCogResponses(severity as keyof typeof SEVERITY_LEVELS);
      for (const [questionId, value] of Object.entries(promisCogResponses)) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: questionId,
          response_number: value,
          day_number: 12,
          created_at: now,
          updated_at: now,
        });
      }
    }

    // Generate sleep log data for each completed day
    for (let day = 1; day <= daysCompleted; day++) {
      const dayOffset = (daysCompleted - day) * 24 * 60 * 60 * 1000;
      const dayTimestamp = now - dayOffset;

      // CSD sleep log responses
      const baseLatency = severity === "mild" ? 15 : severity === "severe" ? 60 : 35;
      const baseWaso = severity === "mild" ? 10 : severity === "severe" ? 45 : 25;

      const csdResponses = [
        { question_id: "CSD_BEDTIME", response_value: "23:00" },
        { question_id: "CSD_LATENCY", response_number: baseLatency + Math.floor(Math.random() * 20) },
        { question_id: "CSD_AWAKENINGS", response_number: severity === "severe" ? 3 : 1 },
        { question_id: "CSD_WASO", response_number: baseWaso + Math.floor(Math.random() * 15) },
        { question_id: "CSD_OUT_BED", response_value: "07:00" },
        { question_id: "CSD_QUALITY", response_number: severity === "mild" ? 4 : severity === "severe" ? 1 : 2 },
        { question_id: "CSD_ALERT", response_number: severity === "mild" ? 4 : severity === "severe" ? 1 : 2 },
        { question_id: "CSD_NAPS", response_number: 0 },
      ];

      for (const resp of csdResponses) {
        await ctx.db.insert("user_assessment_responses", {
          user_id: userId,
          question_id: resp.question_id,
          response_value: resp.response_value,
          response_number: resp.response_number,
          day_number: day,
          created_at: dayTimestamp,
          updated_at: dayTimestamp,
        });
      }

      // Compute sleep metrics
      const latency = baseLatency + Math.floor(Math.random() * 20);
      const waso = baseWaso + Math.floor(Math.random() * 15);
      const timeInBed = 8 * 60; // 8 hours
      const totalSleep = Math.max(0, timeInBed - latency - waso);
      const efficiency = Math.round((totalSleep / timeInBed) * 100);

      const dateStr = new Date(dayTimestamp).toISOString().split('T')[0];
      await ctx.db.insert("user_sleep_data", {
        user_id: userId,
        date: dateStr,
        total_sleep_mins: totalSleep,
        sleep_latency_mins: latency,
        awake_mins: waso,
        sleep_efficiency: efficiency,
        interruptions_count: severity === "severe" ? 3 : 1,
        deep_sleep_mins: Math.round(totalSleep * 0.2),
        light_sleep_mins: Math.round(totalSleep * 0.5),
        rem_sleep_mins: Math.round(totalSleep * 0.25),
        primary_source: "Dashboard Test Generator",
        synced_at: dayTimestamp,
      });
    }

    // Calculate and store clinical scores
    const scoresResult = await calculateAndStoreScores(ctx, userId, now);

    return {
      userId,
      username,
      name: args.name,
      daysCompleted,
      gateways: args.gateways,
      severity,
      message: `Created dashboard test user "${args.name}" with ${daysCompleted} days of data`,
      scoresComputed: scoresResult,
    };
  },
});

// Helper function to calculate and store clinical scores
async function calculateAndStoreScores(ctx: any, userId: Id<"users">, now: number) {
  const responses = await ctx.db
    .query("user_assessment_responses")
    .withIndex("by_user", (q: any) => q.eq("user_id", userId))
    .collect();

  const responseMap = new Map<string, number>();
  for (const r of responses) {
    if (r.response_number !== undefined) {
      responseMap.set(r.question_id, r.response_number);
    }
  }

  const scores: Array<{questionnaire: string, score: number, interpretation: string}> = [];

  // ISI Score
  let isiTotal = 0;
  let isiCount = 0;
  for (let i = 1; i <= 7; i++) {
    const val = responseMap.get(`ISI_${i}`);
    if (val !== undefined) { isiTotal += val; isiCount++; }
  }
  if (isiCount === 7) {
    const interpretation = isiTotal <= 7 ? "none" : isiTotal <= 14 ? "mild" : isiTotal <= 21 ? "moderate" : "severe";
    scores.push({ questionnaire: "ISI", score: isiTotal, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "ISI",
      score: isiTotal,
      max_score: 28,
      interpretation,
      calculated_at: now,
    });
  }

  // PHQ-9 Score
  let phqTotal = 0;
  let phqCount = 0;
  for (let i = 1; i <= 9; i++) {
    const val = responseMap.get(`PHQ9_${i}`);
    if (val !== undefined) { phqTotal += val; phqCount++; }
  }
  if (phqCount === 9) {
    const interpretation = phqTotal <= 4 ? "minimal" : phqTotal <= 9 ? "mild" : phqTotal <= 14 ? "moderate" : phqTotal <= 19 ? "moderately_severe" : "severe";
    scores.push({ questionnaire: "PHQ-9", score: phqTotal, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "PHQ-9",
      score: phqTotal,
      max_score: 27,
      interpretation,
      calculated_at: now,
    });
  }

  // GAD-7 Score
  let gadTotal = 0;
  let gadCount = 0;
  for (let i = 1; i <= 7; i++) {
    const val = responseMap.get(`GAD7_${i}`);
    if (val !== undefined) { gadTotal += val; gadCount++; }
  }
  if (gadCount === 7) {
    const interpretation = gadTotal <= 4 ? "minimal" : gadTotal <= 9 ? "mild" : gadTotal <= 14 ? "moderate" : "severe";
    scores.push({ questionnaire: "GAD-7", score: gadTotal, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "GAD-7",
      score: gadTotal,
      max_score: 21,
      interpretation,
      calculated_at: now,
    });
  }

  // ESS Score
  let essTotal = 0;
  let essCount = 0;
  for (let i = 1; i <= 8; i++) {
    const val = responseMap.get(`ESS_${i}`);
    if (val !== undefined) { essTotal += val; essCount++; }
  }
  if (essCount === 8) {
    const interpretation = essTotal <= 10 ? "normal" : essTotal <= 14 ? "mild" : essTotal <= 18 ? "moderate" : "severe";
    scores.push({ questionnaire: "ESS", score: essTotal, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "ESS",
      score: essTotal,
      max_score: 24,
      interpretation,
      calculated_at: now,
    });
  }

  // STOP-BANG Score (from string responses)
  const stringResponses = await ctx.db
    .query("user_assessment_responses")
    .withIndex("by_user", (q: any) => q.eq("user_id", userId))
    .collect();
  const stringResponseMap = new Map<string, string>();
  for (const r of stringResponses) {
    if (r.response_value !== undefined) {
      stringResponseMap.set(r.question_id, r.response_value);
    }
  }

  let sbTotal = 0;
  let sbCount = 0;
  for (let i = 1; i <= 8; i++) {
    const val = stringResponseMap.get(`SB_${i}`);
    if (val !== undefined) {
      sbCount++;
      if (val.toLowerCase() === "yes") sbTotal++;
    }
  }
  if (sbCount === 8) {
    const interpretation = sbTotal <= 2 ? "low_risk" : sbTotal <= 4 ? "intermediate_risk" : "high_risk";
    scores.push({ questionnaire: "STOP-BANG", score: sbTotal, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "STOP-BANG",
      score: sbTotal,
      max_score: 8,
      interpretation,
      calculated_at: now,
    });
  }

  // DBAS-16 Score (average)
  let dbasTotal = 0;
  let dbasCount = 0;
  for (let i = 1; i <= 16; i++) {
    const val = responseMap.get(`DBAS_${i}`);
    if (val !== undefined) { dbasTotal += val; dbasCount++; }
  }
  if (dbasCount === 16) {
    const avgScore = Math.round((dbasTotal / 16) * 10) / 10;
    const interpretation = avgScore <= 3 ? "low" : avgScore <= 6 ? "moderate" : "high";
    scores.push({ questionnaire: "DBAS-16", score: avgScore, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "DBAS-16",
      score: avgScore,
      max_score: 10,
      interpretation,
      calculated_at: now,
    });
  }

  // FSS Score (average)
  let fssTotal = 0;
  let fssCount = 0;
  for (let i = 1; i <= 9; i++) {
    const val = responseMap.get(`FSS_${i}`);
    if (val !== undefined) { fssTotal += val; fssCount++; }
  }
  if (fssCount === 9) {
    const avgScore = Math.round((fssTotal / 9) * 10) / 10;
    const interpretation = avgScore < 4 ? "normal" : "significant_fatigue";
    scores.push({ questionnaire: "FSS", score: avgScore, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "FSS",
      score: avgScore,
      max_score: 7,
      interpretation,
      calculated_at: now,
    });
  }

  // FOSQ-10 Score (average, higher = better)
  let fosqTotal = 0;
  let fosqCount = 0;
  for (let i = 1; i <= 10; i++) {
    const val = responseMap.get(`FOSQ_${i}`);
    if (val !== undefined) { fosqTotal += val; fosqCount++; }
  }
  if (fosqCount === 10) {
    const avgScore = Math.round((fosqTotal / 10) * 10) / 10;
    const interpretation = avgScore >= 3 ? "normal" : avgScore >= 2 ? "mild_impairment" : "significant_impairment";
    scores.push({ questionnaire: "FOSQ-10", score: avgScore, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "FOSQ-10",
      score: avgScore,
      max_score: 4,
      interpretation,
      calculated_at: now,
    });
  }

  // DASS-21 Scores (3 subscales, multiply by 2 for severity)
  let dassD = 0, dassA = 0, dassS = 0;
  let dassCount = 0;
  const dassDepItems = [3, 5, 10, 13, 16, 17, 21];
  const dassAnxItems = [2, 4, 7, 9, 15, 19, 20];
  const dassStrItems = [1, 6, 8, 11, 12, 14, 18];
  for (let i = 1; i <= 21; i++) {
    const val = responseMap.get(`DASS_${i}`);
    if (val !== undefined) {
      dassCount++;
      if (dassDepItems.includes(i)) dassD += val;
      if (dassAnxItems.includes(i)) dassA += val;
      if (dassStrItems.includes(i)) dassS += val;
    }
  }
  if (dassCount === 21) {
    // Multiply by 2 for final scores
    dassD *= 2; dassA *= 2; dassS *= 2;
    const depInterpretation = dassD <= 9 ? "normal" : dassD <= 13 ? "mild" : dassD <= 20 ? "moderate" : dassD <= 27 ? "severe" : "extremely_severe";
    scores.push({ questionnaire: "DASS-21 Depression", score: dassD, interpretation: depInterpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "DASS-21 Depression",
      score: dassD,
      max_score: 42,
      interpretation: depInterpretation,
      calculated_at: now,
    });

    const anxInterpretation = dassA <= 7 ? "normal" : dassA <= 9 ? "mild" : dassA <= 14 ? "moderate" : dassA <= 19 ? "severe" : "extremely_severe";
    scores.push({ questionnaire: "DASS-21 Anxiety", score: dassA, interpretation: anxInterpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "DASS-21 Anxiety",
      score: dassA,
      max_score: 42,
      interpretation: anxInterpretation,
      calculated_at: now,
    });

    const strInterpretation = dassS <= 14 ? "normal" : dassS <= 18 ? "mild" : dassS <= 25 ? "moderate" : dassS <= 33 ? "severe" : "extremely_severe";
    scores.push({ questionnaire: "DASS-21 Stress", score: dassS, interpretation: strInterpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "DASS-21 Stress",
      score: dassS,
      max_score: 42,
      interpretation: strInterpretation,
      calculated_at: now,
    });
  }

  // BPI Scores (Pain Severity and Interference)
  let bpiSeverity = 0, bpiInterference = 0;
  let bpiSevCount = 0, bpiIntCount = 0;
  for (let i = 1; i <= 4; i++) {
    const val = responseMap.get(`BPI_${i}`);
    if (val !== undefined) { bpiSeverity += val; bpiSevCount++; }
  }
  for (let i = 5; i <= 11; i++) {
    const val = responseMap.get(`BPI_${i}`);
    if (val !== undefined) { bpiInterference += val; bpiIntCount++; }
  }
  if (bpiSevCount === 4) {
    const avgSeverity = Math.round((bpiSeverity / 4) * 10) / 10;
    const interpretation = avgSeverity <= 3 ? "mild" : avgSeverity <= 6 ? "moderate" : "severe";
    scores.push({ questionnaire: "BPI Pain Severity", score: avgSeverity, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "BPI Pain Severity",
      score: avgSeverity,
      max_score: 10,
      interpretation,
      calculated_at: now,
    });
  }
  if (bpiIntCount === 7) {
    const avgInterference = Math.round((bpiInterference / 7) * 10) / 10;
    const interpretation = avgInterference <= 3 ? "mild" : avgInterference <= 6 ? "moderate" : "severe";
    scores.push({ questionnaire: "BPI Pain Interference", score: avgInterference, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "BPI Pain Interference",
      score: avgInterference,
      max_score: 10,
      interpretation,
      calculated_at: now,
    });
  }

  // MEDAS Score (count of Yes responses)
  let medasTotal = 0;
  let medasCount = 0;
  for (let i = 1; i <= 14; i++) {
    const val = stringResponseMap.get(`MEDAS_${i}`);
    if (val !== undefined) {
      medasCount++;
      if (val.toLowerCase() === "yes") medasTotal++;
    }
  }
  if (medasCount === 14) {
    const interpretation = medasTotal >= 10 ? "high_adherence" : medasTotal >= 6 ? "moderate_adherence" : "low_adherence";
    scores.push({ questionnaire: "MEDAS", score: medasTotal, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "MEDAS",
      score: medasTotal,
      max_score: 14,
      interpretation,
      calculated_at: now,
    });
  }

  // MEQ Score
  let meqTotal = 0;
  let meqCount = 0;
  for (let i = 1; i <= 19; i++) {
    const val = responseMap.get(`MEQ_${i}`);
    if (val !== undefined) { meqTotal += val; meqCount++; }
  }
  if (meqCount === 19) {
    const interpretation = meqTotal >= 59 ? "definitely_morning" : meqTotal >= 42 ? "moderately_morning" : meqTotal >= 31 ? "neither" : meqTotal >= 16 ? "moderately_evening" : "definitely_evening";
    scores.push({ questionnaire: "MEQ", score: meqTotal, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "MEQ",
      score: meqTotal,
      max_score: 86,
      interpretation,
      calculated_at: now,
    });
  }

  // PROMIS Cognitive Score
  let promisTotal = 0;
  let promisCount = 0;
  for (let i = 1; i <= 6; i++) {
    const val = responseMap.get(`PROMIS_COG_${i}`);
    if (val !== undefined) { promisTotal += val; promisCount++; }
  }
  if (promisCount === 6) {
    const interpretation = promisTotal >= 24 ? "normal" : promisTotal >= 18 ? "mild_impairment" : "significant_impairment";
    scores.push({ questionnaire: "PROMIS Cognitive", score: promisTotal, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "PROMIS Cognitive",
      score: promisTotal,
      max_score: 30,
      interpretation,
      calculated_at: now,
    });
  }

  // Sleep Hygiene Index Score
  let shTotal = 0;
  let shCount = 0;
  for (let i = 1; i <= 10; i++) {
    const val = responseMap.get(`SH_${i}`);
    if (val !== undefined) { shTotal += val; shCount++; }
  }
  if (shCount === 10) {
    const interpretation = shTotal <= 15 ? "good" : shTotal <= 25 ? "fair" : "poor";
    scores.push({ questionnaire: "Sleep Hygiene", score: shTotal, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "Sleep Hygiene",
      score: shTotal,
      max_score: 50,
      interpretation,
      calculated_at: now,
    });
  }

  // PSAS Scores (Cognitive and Somatic subscales)
  let psasCog = 0, psasSom = 0;
  let psasCogCount = 0, psasSomCount = 0;
  for (let i = 1; i <= 8; i++) {
    const cogVal = responseMap.get(`PSAS_C${i}`);
    if (cogVal !== undefined) { psasCog += cogVal; psasCogCount++; }
    const somVal = responseMap.get(`PSAS_S${i}`);
    if (somVal !== undefined) { psasSom += somVal; psasSomCount++; }
  }
  if (psasCogCount === 8) {
    const interpretation = psasCog <= 16 ? "low" : psasCog <= 24 ? "moderate" : "high";
    scores.push({ questionnaire: "PSAS Cognitive", score: psasCog, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "PSAS Cognitive",
      score: psasCog,
      max_score: 40,
      interpretation,
      calculated_at: now,
    });
  }
  if (psasSomCount === 8) {
    const interpretation = psasSom <= 16 ? "low" : psasSom <= 24 ? "moderate" : "high";
    scores.push({ questionnaire: "PSAS Somatic", score: psasSom, interpretation });
    await ctx.db.insert("questionnaire_scores", {
      user_id: userId,
      questionnaire_name: "PSAS Somatic",
      score: psasSom,
      max_score: 40,
      interpretation,
      calculated_at: now,
    });
  }

  return scores;
}

/**
 * Delete all dashboard test users (those starting with "dash_test_")
 */
export const cleanupDashboardTestUsers = mutation({
  args: {},
  handler: async (ctx) => {
    const testUsers = await ctx.db
      .query("users")
      .filter((q) => q.eq(q.field("developer_mode"), true))
      .collect();

    const dashTestUsers = testUsers.filter(u => u.username.startsWith("dash_test_"));
    let deleted = 0;

    for (const user of dashTestUsers) {
      // Delete related data
      const responses = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user", (q) => q.eq("user_id", user._id))
        .collect();
      for (const r of responses) await ctx.db.delete(r._id);

      const sleepData = await ctx.db
        .query("user_sleep_data")
        .withIndex("by_user", (q) => q.eq("user_id", user._id))
        .collect();
      for (const s of sleepData) await ctx.db.delete(s._id);

      const scores = await ctx.db
        .query("questionnaire_scores")
        .withIndex("by_user", (q) => q.eq("user_id", user._id))
        .collect();
      for (const s of scores) await ctx.db.delete(s._id);

      const gateways = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user", (q) => q.eq("user_id", user._id))
        .collect();
      for (const g of gateways) await ctx.db.delete(g._id);

      await ctx.db.delete(user._id);
      deleted++;
    }

    return { deleted, message: `Deleted ${deleted} dashboard test users` };
  },
});
