/**
 * Core Assessment → Expansion Module Question Mapping
 *
 * This configuration maps core assessment questions (Days 1-5) to their
 * equivalent standardized questionnaire items in expansion modules.
 *
 * Purpose: Allow clinical scores to be calculated from core questions
 * and show partial completion of expansion modules before they're directly answered.
 */

export interface CoreQuestionMapping {
  /** The question ID as stored in the database (e.g., "15", "PSQI_1") */
  coreQuestionId: string;
  /** The expansion module this maps to (e.g., "expansion_psqi") */
  expansionModuleId: string;
  /** The standardized questionnaire item this is equivalent to */
  standardizedEquivalent?: string;
  /** How much this contributes (1.0 = full item, 0.5 = partial/related) */
  contributionWeight: number;
  /** Notes about the mapping */
  notes?: string;
}

/**
 * Complete mapping of core questions to expansion modules
 */
export const CORE_TO_EXPANSION_MAPPING: CoreQuestionMapping[] = [
  // ============================================
  // PSQI (Pittsburgh Sleep Quality Index) - 19 items total
  // ~16 items from core assessment
  // ============================================

  // PSQI timing questions (Day 1-2)
  { coreQuestionId: "PSQI_1", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_1", contributionWeight: 1.0, notes: "Usual bedtime" },
  { coreQuestionId: "PSQI_2", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_2", contributionWeight: 1.0, notes: "Sleep latency (minutes)" },
  { coreQuestionId: "PSQI_3", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_3", contributionWeight: 1.0, notes: "Usual wake time" },

  // PSQI Component 5 - Sleep disturbances (Day 2)
  { coreQuestionId: "PSQI_5a", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5a", contributionWeight: 1.0, notes: "Cannot sleep within 30 min" },
  { coreQuestionId: "PSQI_5b", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5b", contributionWeight: 1.0, notes: "Wake up middle of night/early" },
  { coreQuestionId: "PSQI_5c", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5c", contributionWeight: 1.0, notes: "Use bathroom" },
  { coreQuestionId: "PSQI_5d", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5d", contributionWeight: 1.0, notes: "Cannot breathe comfortably" },
  { coreQuestionId: "PSQI_5e", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5e", contributionWeight: 1.0, notes: "Cough or snore loudly" },
  { coreQuestionId: "PSQI_5f", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5f", contributionWeight: 1.0, notes: "Feel too cold" },
  { coreQuestionId: "PSQI_5g", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5g", contributionWeight: 1.0, notes: "Feel too hot" },
  { coreQuestionId: "PSQI_5h", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5h", contributionWeight: 1.0, notes: "Bad dreams" },
  { coreQuestionId: "PSQI_5i", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5i", contributionWeight: 1.0, notes: "Pain" },
  { coreQuestionId: "PSQI_5j", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5j", contributionWeight: 1.0, notes: "Other reason" },

  // Additional PSQI-related core questions
  { coreQuestionId: "1", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_6", contributionWeight: 1.0, notes: "Overall sleep quality (maps to subjective quality)" },
  { coreQuestionId: "12A", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_5b_related", contributionWeight: 0.5, notes: "Night awakenings count" },
  { coreQuestionId: "12C", expansionModuleId: "expansion_psqi", standardizedEquivalent: "PSQI_maintenance", contributionWeight: 0.5, notes: "Time to fall back asleep" },

  // ============================================
  // PHQ-9 (Patient Health Questionnaire) - 9 items total
  // 1 gateway item from core
  // ============================================

  { coreQuestionId: "15", expansionModuleId: "expansion_phq9", standardizedEquivalent: "PHQ9_2", contributionWeight: 1.0, notes: "Depression gateway - Felt down/depressed/hopeless" },

  // ============================================
  // GAD-7 (Generalized Anxiety Disorder) - 7 items total
  // 1 gateway item from core
  // ============================================

  { coreQuestionId: "16", expansionModuleId: "expansion_gad7", standardizedEquivalent: "GAD7_1", contributionWeight: 1.0, notes: "Anxiety gateway - Felt nervous/anxious/on edge" },

  // ============================================
  // STOP-BANG (Sleep Apnea Screening) - 8 items total
  // 3 symptom items from core
  // ============================================

  { coreQuestionId: "19", expansionModuleId: "expansion_stop_bang", standardizedEquivalent: "SB_1", contributionWeight: 1.0, notes: "S - Snore loudly" },
  { coreQuestionId: "20", expansionModuleId: "expansion_stop_bang", standardizedEquivalent: "SB_3", contributionWeight: 1.0, notes: "O - Observed stop breathing" },
  { coreQuestionId: "21", expansionModuleId: "expansion_stop_bang", standardizedEquivalent: "SB_2", contributionWeight: 1.0, notes: "T - Tired/fatigued during day" },

  // ============================================
  // ESS (Epworth Sleepiness Scale) - 8 items total
  // 1-2 related items from core
  // ============================================

  { coreQuestionId: "17", expansionModuleId: "expansion_ess", standardizedEquivalent: "ESS_gateway", contributionWeight: 0.5, notes: "Excessive daytime sleepiness gateway" },
  { coreQuestionId: "21", expansionModuleId: "expansion_ess", standardizedEquivalent: "ESS_related", contributionWeight: 0.5, notes: "Tired/fatigued (also maps to STOP-BANG)" },

  // ============================================
  // BPI (Brief Pain Inventory) - 11 items total
  // 2 items from core
  // ============================================

  { coreQuestionId: "22", expansionModuleId: "expansion_bpi", standardizedEquivalent: "BPI_interference", contributionWeight: 1.0, notes: "Pain affects sleep" },
  { coreQuestionId: "23", expansionModuleId: "expansion_bpi", standardizedEquivalent: "BPI_3", contributionWeight: 1.0, notes: "Average pain level (0-10)" },

  // ============================================
  // MEQ (Morningness-Eveningness Questionnaire) - 19 items total
  // 1 related item from core
  // ============================================

  { coreQuestionId: "11", expansionModuleId: "expansion_meq", standardizedEquivalent: "MEQ_light", contributionWeight: 0.5, notes: "Morning sunlight exposure (chronotype indicator)" },

  // ============================================
  // Sleep Hygiene / SH_ - 10 items total
  // 3-4 items from core
  // ============================================

  { coreQuestionId: "13", expansionModuleId: "expansion_sleep_hygiene", standardizedEquivalent: "SH_screens", contributionWeight: 1.0, notes: "Screen use before bed" },
  { coreQuestionId: "29", expansionModuleId: "expansion_sleep_hygiene", standardizedEquivalent: "SH_caffeine", contributionWeight: 1.0, notes: "Caffeine consumption" },
  { coreQuestionId: "32", expansionModuleId: "expansion_sleep_hygiene", standardizedEquivalent: "SH_alcohol", contributionWeight: 1.0, notes: "Alcohol consumption" },
  { coreQuestionId: "33", expansionModuleId: "expansion_sleep_hygiene", standardizedEquivalent: "SH_alcohol_timing", contributionWeight: 1.0, notes: "Alcohol timing relative to bed" },

  // ============================================
  // ISI (Insomnia Severity Index) - 7 items total
  // 1 gateway item from core (Q3 triggers insomnia gateway)
  // ============================================

  { coreQuestionId: "3", expansionModuleId: "expansion_isi", standardizedEquivalent: "ISI_gateway", contributionWeight: 0.5, notes: "Trouble falling/staying asleep gateway" },
];

/**
 * Get all core question mappings for a specific expansion module
 */
export function getCoreContributionsForModule(moduleId: string): CoreQuestionMapping[] {
  return CORE_TO_EXPANSION_MAPPING.filter((m) => m.expansionModuleId === moduleId);
}

/**
 * Calculate total weighted contribution from core for a module
 */
export function getCoreContributionCount(moduleId: string): number {
  return CORE_TO_EXPANSION_MAPPING
    .filter((m) => m.expansionModuleId === moduleId)
    .reduce((sum, m) => sum + m.contributionWeight, 0);
}

/**
 * Get all unique module IDs that have core contributions
 */
export function getModulesWithCoreContributions(): string[] {
  return [...new Set(CORE_TO_EXPANSION_MAPPING.map((m) => m.expansionModuleId))];
}

/**
 * Check if a question ID is a core question that maps to an expansion module
 */
export function isCoreContributionQuestion(questionId: string): boolean {
  return CORE_TO_EXPANSION_MAPPING.some((m) => m.coreQuestionId === questionId);
}

/**
 * Get the expansion module(s) a core question contributes to
 */
export function getExpansionModulesForCoreQuestion(questionId: string): string[] {
  return CORE_TO_EXPANSION_MAPPING
    .filter((m) => m.coreQuestionId === questionId)
    .map((m) => m.expansionModuleId);
}
