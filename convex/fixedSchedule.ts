/**
 * Fixed Schedule Configuration
 *
 * This is the single source of truth for the 10-day assessment journey.
 * NO dynamic scheduling - each day has predetermined content.
 *
 * Structure:
 * - Days 1-5: Core Assessment (by pillar/theme)
 * - Days 6-10: Expansion Packs (gateway-triggered)
 */

// Gateway types that can trigger expansion content
export type GatewayId =
  | "insomnia"
  | "poor_sleep_quality"
  | "depression"
  | "anxiety"
  | "osa"
  | "excessive_sleepiness"
  | "cognitive"
  | "pain"
  | "sleep_timing"
  | "diet_impact"
  | "shift_work";

// Core assessment themes for Days 1-5
export type CoreTheme =
  | "demographics"
  | "sleep_quality"
  | "mental_health"
  | "physical"
  | "lifestyle";

// Expansion pack IDs
export type ExpansionPackId =
  | "isi"
  | "swdsq"
  | "phq9"
  | "promis"
  | "gad7"
  | "sleep_hygiene"
  | "stop_bang"
  // Berlin removed - STOP-BANG alone has 93% sensitivity for OSA
  | "ess"
  | "fss"
  | "dbas" // Changed from dbas_part1/part2 to single DBAS-6 (6 items)
  | "bpi_part1"
  | "bpi_part2"
  | "psas"
  | "fosq"
  | "medas"
  | "meq";

// Day configuration types
interface CoreDayConfig {
  type: "core";
  theme: CoreTheme;
  splashTitle: string;
  splashSubtitle: string;
  estimatedMinutes: number;
}

interface ExpansionDayConfig {
  type: "expansion";
  packs: ExpansionPackId[];
  gateways: GatewayId[];
  splashTitle: string;
  splashSubtitle: string;
  totalQuestions: number;
  estimatedMinutes: number;
}

export type DayConfig = CoreDayConfig | ExpansionDayConfig;

/**
 * FIXED 10-DAY SCHEDULE
 *
 * Days 1-5: Core Assessment (always shown)
 * Days 6-10: Expansion Packs (shown only if ANY gateway is triggered)
 */
export const FIXED_SCHEDULE: Record<number, DayConfig> = {
  // ============================================
  // CORE ASSESSMENT PHASE (Days 1-5)
  // ============================================

  1: {
    type: "core",
    theme: "demographics",
    splashTitle: "Let's Get to Know You",
    splashSubtitle: "Demographics, sleep history, and environment",
    estimatedMinutes: 4,  // ~15 sec/question
  },

  2: {
    type: "core",
    theme: "sleep_quality",
    splashTitle: "Your Sleep Quality",
    splashSubtitle: "Sleep patterns, quality ratings, and satisfaction",
    estimatedMinutes: 6,  // ~15 sec/question
  },

  3: {
    type: "core",
    theme: "mental_health",
    splashTitle: "Mind & Mood",
    splashSubtitle: "Mental health, daytime function, and concentration",
    estimatedMinutes: 1,  // ~15 sec/question (only 4 questions)
  },

  4: {
    type: "core",
    theme: "physical",
    splashTitle: "Body & Health",
    splashSubtitle: "Physical health, breathing, pain, and activity",
    estimatedMinutes: 3,  // ~15 sec/question
  },

  5: {
    type: "core",
    theme: "lifestyle",
    splashTitle: "Daily Habits",
    splashSubtitle: "Caffeine, alcohol, meals, screens, and stress",
    estimatedMinutes: 9,  // ~15 sec/question (33 questions)
  },

  // ============================================
  // EXPANSION PACK PHASE (Days 6-10)
  // Consolidated from 9 days to 5 days for faster intake
  // ============================================

  6: {
    type: "expansion",
    packs: ["isi", "swdsq", "dbas"],
    gateways: ["insomnia", "poor_sleep_quality", "shift_work"],
    splashTitle: "Insomnia Assessment",
    splashSubtitle: "Insomnia severity, shift work, and sleep beliefs",
    totalQuestions: 17, // ISI(7) + SWDSQ(4) + DBAS-6(6)
    estimatedMinutes: 5,
  },

  7: {
    type: "expansion",
    packs: ["phq9", "gad7", "psas"],
    gateways: ["depression", "anxiety", "insomnia"],
    splashTitle: "Mental Health & Arousal",
    splashSubtitle: "Depression, anxiety, and pre-sleep arousal",
    totalQuestions: 32, // PHQ-9(9) + GAD-7(7) + PSAS(16)
    estimatedMinutes: 9,
  },

  8: {
    type: "expansion",
    packs: ["stop_bang", "ess", "fss"],
    gateways: ["osa", "excessive_sleepiness"],
    splashTitle: "Breathing & Energy",
    splashSubtitle: "Sleep apnea screening and daytime sleepiness",
    totalQuestions: 25, // STOP-BANG(8) + ESS(8) + FSS(9)
    estimatedMinutes: 7,
  },

  9: {
    type: "expansion",
    packs: ["sleep_hygiene", "bpi_part1", "bpi_part2", "fosq"],
    gateways: ["insomnia", "poor_sleep_quality", "pain", "excessive_sleepiness"],
    splashTitle: "Function & Behavior",
    splashSubtitle: "Sleep habits, pain, and functional outcomes",
    totalQuestions: 33, // Sleep Hygiene(10) + BPI(13) + FOSQ(10)
    estimatedMinutes: 9,
  },

  10: {
    type: "expansion",
    packs: ["promis", "medas", "meq"],
    gateways: ["cognitive", "diet_impact", "sleep_timing"],
    splashTitle: "Lifestyle & Rhythm",
    splashSubtitle: "Cognitive function, diet, and chronotype",
    totalQuestions: 39, // PROMIS(6) + MEDAS(14) + MEQ(19)
    estimatedMinutes: 11,
  },
};

/**
 * Maps expansion pack IDs to their module IDs in the database
 */
export const PACK_TO_MODULE_IDS: Record<ExpansionPackId, string[]> = {
  isi: ["expansion_isi"],
  swdsq: ["expansion_swdsq"],
  phq9: ["expansion_phq9"],
  promis: ["expansion_promis_cognitive"],
  gad7: ["expansion_gad7"],
  sleep_hygiene: ["expansion_sleep_hygiene_part1", "expansion_sleep_hygiene_part2"],
  stop_bang: ["expansion_stop_bang"],
  // Berlin removed - STOP-BANG alone has 93% sensitivity for OSA
  ess: ["expansion_ess"],
  fss: ["expansion_fss"],
  dbas: ["expansion_dbas6"], // DBAS-6 (2024) - 6 items, R²=0.90 vs DBAS-16
  bpi_part1: ["expansion_bpi_part1"],
  bpi_part2: ["expansion_bpi_part2"],
  psas: ["expansion_psas_cognitive", "expansion_psas_somatic"],
  fosq: ["expansion_fosq_part1", "expansion_fosq_part2"],
  medas: ["expansion_medas"],
  meq: ["expansion_meq_part1", "expansion_meq_part2"],
};

/**
 * Maps core themes to their module IDs in the database
 */
export const THEME_TO_MODULE_IDS: Record<CoreTheme, string[]> = {
  demographics: ["core_social"],
  sleep_quality: ["core_sleep_quality_1", "core_sleep_quality_2"],
  mental_health: ["gateway_mental_health", "gateway_cognitive"],
  physical: ["core_physical"],
  lifestyle: ["core_nutritional", "core_metabolic"],
};

/**
 * Helper: Get day configuration
 */
export function getDayConfig(dayNumber: number): DayConfig | null {
  return FIXED_SCHEDULE[dayNumber] || null;
}

/**
 * Helper: Check if expansion should show for a day based on triggered gateways
 */
export function shouldShowExpansion(
  dayNumber: number,
  triggeredGateways: string[]
): boolean {
  const config = FIXED_SCHEDULE[dayNumber];
  if (!config || config.type !== "expansion") {
    return false;
  }

  // Show if ANY of the day's gateways are triggered
  return config.gateways.some((gateway) => triggeredGateways.includes(gateway));
}

/**
 * Helper: Get module IDs for a day
 */
export function getModuleIdsForDay(
  dayNumber: number,
  triggeredGateways: string[]
): string[] {
  const config = FIXED_SCHEDULE[dayNumber];
  if (!config) return [];

  if (config.type === "core") {
    return THEME_TO_MODULE_IDS[config.theme] || [];
  }

  // For expansion days, only return modules if gateways are triggered
  if (!shouldShowExpansion(dayNumber, triggeredGateways)) {
    return [];
  }

  const moduleIds: string[] = [];
  for (const packId of config.packs) {
    const packModules = PACK_TO_MODULE_IDS[packId];
    if (packModules) {
      moduleIds.push(...packModules);
    }
  }
  return moduleIds;
}

/**
 * Helper: Get fixed schedule summary for iOS "Upcoming Assessments" display
 * Returns which days have content for which gateways
 */
export function getUpcomingAssessmentDays(triggeredGateways: string[]): {
  gateway: string;
  dayNumber: number;
  splashTitle: string;
}[] {
  const results: { gateway: string; dayNumber: number; splashTitle: string }[] = [];

  for (let day = 6; day <= 10; day++) {
    const config = FIXED_SCHEDULE[day];
    if (config?.type === "expansion") {
      for (const gateway of config.gateways) {
        if (triggeredGateways.includes(gateway)) {
          // Only add if not already added for this gateway
          if (!results.some((r) => r.gateway === gateway)) {
            results.push({
              gateway,
              dayNumber: day,
              splashTitle: config.splashTitle,
            });
          }
        }
      }
    }
  }

  return results;
}
