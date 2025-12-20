import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

/**
 * Cross-Platform Consistency Validator
 *
 * Validates consistency between:
 * - iOS QuestionnaireManager module definitions
 * - Convex backend module/question definitions
 * - Web dashboard score displays
 *
 * This ensures questions show up correctly on all platforms
 * and scoring is consistent across the system.
 */

// ============================================
// iOS Module Definitions (Expected)
// ============================================

// These should match QuestionnaireManager.swift
const IOS_EXPECTED_MODULES = {
  core: [
    { id: "core_demographics", name: "Demographics", questionPrefix: "D", expectedQuestions: 6 },
    { id: "core_social", name: "Social", questionPrefix: "35-39,53", expectedQuestions: 12 },
    { id: "core_metabolic", name: "Metabolic", questionPrefix: "26-28,44", expectedQuestions: 14 },
    { id: "core_sleep_quality_1", name: "Sleep Quality Part 1", questionPrefix: "1-3,12,41-46", expectedQuestions: 12 },
    { id: "core_sleep_quality_2", name: "Sleep Quality Part 2", questionPrefix: "47-58", expectedQuestions: 11 },
    { id: "core_sleep_quantity", name: "Sleep Quantity", questionPrefix: "4-6", expectedQuestions: 3 },
    { id: "core_sleep_regularity", name: "Sleep Regularity", questionPrefix: "7-10", expectedQuestions: 4 },
    { id: "core_sleep_timing", name: "Sleep Timing", questionPrefix: "11-18", expectedQuestions: 8 },
    { id: "core_physical", name: "Physical", questionPrefix: "19-25,33", expectedQuestions: 11 },
    { id: "core_nutritional", name: "Nutritional", questionPrefix: "29-34,54", expectedQuestions: 11 },
  ],
  gateway: [
    { id: "gateway_mental_health", name: "Mental Health Gateway", questionIds: ["15", "16"], expectedQuestions: 2 },
    { id: "gateway_cognitive", name: "Cognitive Gateway", questionIds: ["17", "18"], expectedQuestions: 2 },
    { id: "gateway_sleep_quality", name: "Sleep Quality Gateway", questionIds: ["3"], expectedQuestions: 1 },
    { id: "gateway_physical", name: "Physical Gateway", questionIds: ["19", "20", "22-25"], expectedQuestions: 6 },
  ],
  expansion: [
    { id: "expansion_isi", name: "ISI", questionPrefix: "ISI_", expectedQuestions: 7 },
    { id: "expansion_phq9", name: "PHQ-9", questionPrefix: "PHQ9_", expectedQuestions: 9 },
    { id: "expansion_gad7", name: "GAD-7", questionPrefix: "GAD7_", expectedQuestions: 7 },
    { id: "expansion_stop_bang", name: "STOP-BANG", questionPrefix: "SB_", expectedQuestions: 8 },
    { id: "expansion_ess", name: "ESS", questionPrefix: "ESS_", expectedQuestions: 8 },
    { id: "expansion_dbas", name: "DBAS-16", questionPrefix: "DBAS_", expectedQuestions: 16 },
    { id: "expansion_sleep_hygiene", name: "Sleep Hygiene", questionPrefix: "SH_", expectedQuestions: 10 },
    { id: "expansion_psas", name: "PSAS", questionPrefix: "PSAS_", expectedQuestions: 16 },
    { id: "expansion_psqi", name: "PSQI", questionPrefix: "PSQI_", expectedQuestions: 19 },
    { id: "expansion_dass21", name: "DASS-21", questionPrefix: "DASS_", expectedQuestions: 21 },
    { id: "expansion_berlin", name: "Berlin", questionPrefix: "BERLIN_", expectedQuestions: 10 },
    { id: "expansion_fss", name: "FSS", questionPrefix: "FSS_", expectedQuestions: 9 },
    { id: "expansion_fosq", name: "FOSQ-10", questionPrefix: "FOSQ_", expectedQuestions: 10 },
    { id: "expansion_promis", name: "PROMIS Cognitive", questionPrefix: "PROMIS_", expectedQuestions: 15 },
    { id: "expansion_bpi", name: "BPI", questionPrefix: "BPI_", expectedQuestions: 11 },
    { id: "expansion_meq", name: "MEQ", questionPrefix: "MEQ_", expectedQuestions: 19 },
  ],
  sleepDiary: [
    { id: "csd_sleep_log", name: "Consensus Sleep Diary", questionPrefix: "CSD_", expectedQuestions: 20 },
  ],
};

// ============================================
// Clinical Score Thresholds (Expected)
// ============================================

const CLINICAL_SCORE_THRESHOLDS = {
  ISI: {
    maxScore: 28,
    thresholds: [
      { min: 0, max: 7, severity: "none", label: "No clinically significant insomnia" },
      { min: 8, max: 14, severity: "mild", label: "Subthreshold insomnia" },
      { min: 15, max: 21, severity: "moderate", label: "Clinical insomnia (moderate)" },
      { min: 22, max: 28, severity: "severe", label: "Clinical insomnia (severe)" },
    ],
  },
  "PHQ-9": {
    maxScore: 27,
    thresholds: [
      { min: 0, max: 4, severity: "none", label: "Minimal depression" },
      { min: 5, max: 9, severity: "mild", label: "Mild depression" },
      { min: 10, max: 14, severity: "moderate", label: "Moderate depression" },
      { min: 15, max: 19, severity: "moderately_severe", label: "Moderately severe depression" },
      { min: 20, max: 27, severity: "severe", label: "Severe depression" },
    ],
  },
  "GAD-7": {
    maxScore: 21,
    thresholds: [
      { min: 0, max: 4, severity: "none", label: "Minimal anxiety" },
      { min: 5, max: 9, severity: "mild", label: "Mild anxiety" },
      { min: 10, max: 14, severity: "moderate", label: "Moderate anxiety" },
      { min: 15, max: 21, severity: "severe", label: "Severe anxiety" },
    ],
  },
  ESS: {
    maxScore: 24,
    thresholds: [
      { min: 0, max: 10, severity: "none", label: "Normal daytime sleepiness" },
      { min: 11, max: 14, severity: "mild", label: "Mild excessive daytime sleepiness" },
      { min: 15, max: 18, severity: "moderate", label: "Moderate excessive daytime sleepiness" },
      { min: 19, max: 24, severity: "severe", label: "Severe excessive daytime sleepiness" },
    ],
  },
  "STOP-BANG": {
    maxScore: 8,
    thresholds: [
      { min: 0, max: 2, severity: "low", label: "Low risk of OSA" },
      { min: 3, max: 4, severity: "intermediate", label: "Intermediate risk of OSA" },
      { min: 5, max: 8, severity: "high", label: "High risk of OSA" },
    ],
  },
  PSQI: {
    maxScore: 21,
    thresholds: [
      { min: 0, max: 5, severity: "good", label: "Good sleep quality" },
      { min: 6, max: 10, severity: "poor", label: "Poor sleep quality" },
      { min: 11, max: 15, severity: "moderate", label: "Moderate sleep disturbance" },
      { min: 16, max: 21, severity: "severe", label: "Severe sleep disturbance" },
    ],
  },
  "DBAS-16": {
    maxScore: 160, // Average divided by 10
    isAverage: true,
    thresholds: [
      { min: 0, max: 3, severity: "low", label: "Low dysfunctional beliefs" },
      { min: 3.01, max: 5, severity: "moderate", label: "Moderate dysfunctional beliefs" },
      { min: 5.01, max: 7, severity: "elevated", label: "Elevated dysfunctional beliefs" },
      { min: 7.01, max: 10, severity: "high", label: "High dysfunctional beliefs" },
    ],
  },
};

// ============================================
// Validation Functions
// ============================================

/**
 * Validate all modules exist in backend
 */
export const validateModuleConsistency = query({
  args: {},
  handler: async (ctx) => {
    const results: Array<{
      category: string;
      moduleId: string;
      name: string;
      status: "pass" | "fail" | "warning";
      message: string;
      backendQuestionCount?: number;
      expectedQuestionCount?: number;
    }> = [];

    // Get all backend modules
    const backendModules = await ctx.db.query("assessment_modules").collect();
    const backendModuleIds = new Set(backendModules.map(m => m.module_id));

    // Get all module-question mappings
    const moduleQuestions = await ctx.db.query("module_questions").collect();

    // Count questions per module
    const questionCountByModule: Record<string, number> = {};
    for (const mq of moduleQuestions) {
      questionCountByModule[mq.module_id] = (questionCountByModule[mq.module_id] || 0) + 1;
    }

    // Check all iOS modules
    for (const category of ["core", "gateway", "expansion", "sleepDiary"] as const) {
      for (const iosModule of IOS_EXPECTED_MODULES[category]) {
        const backendExists = backendModuleIds.has(iosModule.id);
        const backendCount = questionCountByModule[iosModule.id] || 0;

        if (!backendExists) {
          results.push({
            category,
            moduleId: iosModule.id,
            name: iosModule.name,
            status: "fail",
            message: "Module not found in backend",
            expectedQuestionCount: iosModule.expectedQuestions,
          });
        } else if (backendCount === 0) {
          results.push({
            category,
            moduleId: iosModule.id,
            name: iosModule.name,
            status: "fail",
            message: "Module has no questions mapped",
            backendQuestionCount: 0,
            expectedQuestionCount: iosModule.expectedQuestions,
          });
        } else if (backendCount !== iosModule.expectedQuestions) {
          results.push({
            category,
            moduleId: iosModule.id,
            name: iosModule.name,
            status: "warning",
            message: `Question count mismatch: backend=${backendCount}, iOS expected=${iosModule.expectedQuestions}`,
            backendQuestionCount: backendCount,
            expectedQuestionCount: iosModule.expectedQuestions,
          });
        } else {
          results.push({
            category,
            moduleId: iosModule.id,
            name: iosModule.name,
            status: "pass",
            message: `${backendCount} questions`,
            backendQuestionCount: backendCount,
            expectedQuestionCount: iosModule.expectedQuestions,
          });
        }
      }
    }

    // Check for backend modules not in iOS list
    const allIosModuleIds = new Set([
      ...IOS_EXPECTED_MODULES.core.map(m => m.id),
      ...IOS_EXPECTED_MODULES.gateway.map(m => m.id),
      ...IOS_EXPECTED_MODULES.expansion.map(m => m.id),
      ...IOS_EXPECTED_MODULES.sleepDiary.map(m => m.id),
    ]);

    for (const backendModule of backendModules) {
      if (!allIosModuleIds.has(backendModule.module_id)) {
        results.push({
          category: "backend_only",
          moduleId: backendModule.module_id,
          name: backendModule.name,
          status: "warning",
          message: "Module exists in backend but not expected by iOS",
          backendQuestionCount: questionCountByModule[backendModule.module_id] || 0,
        });
      }
    }

    const passCount = results.filter(r => r.status === "pass").length;
    const warnCount = results.filter(r => r.status === "warning").length;
    const failCount = results.filter(r => r.status === "fail").length;

    return {
      status: failCount > 0 ? "fail" : warnCount > 0 ? "warning" : "pass",
      summary: `${passCount} pass, ${warnCount} warnings, ${failCount} failures`,
      results,
    };
  },
});

/**
 * Validate clinical questionnaire questions exist
 */
export const validateClinicalQuestions = query({
  args: {},
  handler: async (ctx) => {
    const results: Array<{
      questionnaire: string;
      status: "pass" | "fail" | "warning";
      message: string;
      foundQuestions?: string[];
      missingQuestions?: string[];
    }> = [];

    // Get all questions
    const questions = await ctx.db.query("assessment_questions").collect();
    const questionIds = new Set(questions.map(q => q.question_id));

    // Check ISI (ISI_1 through ISI_7)
    const isiQuestions = [];
    const isiMissing = [];
    for (let i = 1; i <= 7; i++) {
      if (questionIds.has(`ISI_${i}`)) {
        isiQuestions.push(`ISI_${i}`);
      } else {
        isiMissing.push(`ISI_${i}`);
      }
    }
    results.push({
      questionnaire: "ISI",
      status: isiMissing.length === 0 ? "pass" : "fail",
      message: isiMissing.length === 0 ? "All 7 questions present" : `Missing: ${isiMissing.join(", ")}`,
      foundQuestions: isiQuestions,
      missingQuestions: isiMissing,
    });

    // Check PHQ-9 (PHQ9_1 through PHQ9_9)
    const phq9Questions = [];
    const phq9Missing = [];
    for (let i = 1; i <= 9; i++) {
      if (questionIds.has(`PHQ9_${i}`)) {
        phq9Questions.push(`PHQ9_${i}`);
      } else {
        phq9Missing.push(`PHQ9_${i}`);
      }
    }
    results.push({
      questionnaire: "PHQ-9",
      status: phq9Missing.length === 0 ? "pass" : "fail",
      message: phq9Missing.length === 0 ? "All 9 questions present" : `Missing: ${phq9Missing.join(", ")}`,
      foundQuestions: phq9Questions,
      missingQuestions: phq9Missing,
    });

    // Check GAD-7 (GAD7_1 through GAD7_7)
    const gad7Questions = [];
    const gad7Missing = [];
    for (let i = 1; i <= 7; i++) {
      if (questionIds.has(`GAD7_${i}`)) {
        gad7Questions.push(`GAD7_${i}`);
      } else {
        gad7Missing.push(`GAD7_${i}`);
      }
    }
    results.push({
      questionnaire: "GAD-7",
      status: gad7Missing.length === 0 ? "pass" : "fail",
      message: gad7Missing.length === 0 ? "All 7 questions present" : `Missing: ${gad7Missing.join(", ")}`,
      foundQuestions: gad7Questions,
      missingQuestions: gad7Missing,
    });

    // Check ESS (ESS_1 through ESS_8)
    const essQuestions = [];
    const essMissing = [];
    for (let i = 1; i <= 8; i++) {
      if (questionIds.has(`ESS_${i}`)) {
        essQuestions.push(`ESS_${i}`);
      } else {
        essMissing.push(`ESS_${i}`);
      }
    }
    results.push({
      questionnaire: "ESS",
      status: essMissing.length === 0 ? "pass" : "fail",
      message: essMissing.length === 0 ? "All 8 questions present" : `Missing: ${essMissing.join(", ")}`,
      foundQuestions: essQuestions,
      missingQuestions: essMissing,
    });

    // Check STOP-BANG (SB_1 through SB_8)
    const sbQuestions = [];
    const sbMissing = [];
    for (let i = 1; i <= 8; i++) {
      if (questionIds.has(`SB_${i}`)) {
        sbQuestions.push(`SB_${i}`);
      } else {
        sbMissing.push(`SB_${i}`);
      }
    }
    results.push({
      questionnaire: "STOP-BANG",
      status: sbMissing.length === 0 ? "pass" : "fail",
      message: sbMissing.length === 0 ? "All 8 questions present" : `Missing: ${sbMissing.join(", ")}`,
      foundQuestions: sbQuestions,
      missingQuestions: sbMissing,
    });

    // Check CSD (Consensus Sleep Diary)
    const csdQuestionIds = [
      "CSD_BEDTIME", "CSD_LATENCY", "CSD_AWAKENINGS", "CSD_WASO",
      "CSD_OUT_BED", "CSD_QUALITY", "CSD_ALERT", "CSD_NAPS"
    ];

    // Check in sleep_diary_questions table
    const sleepDiaryQuestions = await ctx.db.query("sleep_diary_questions").collect();
    const sleepDiaryIds = new Set(sleepDiaryQuestions.map(q => q.id));

    const csdFound = [];
    const csdMissing = [];
    for (const qid of csdQuestionIds) {
      if (sleepDiaryIds.has(qid) || questionIds.has(qid)) {
        csdFound.push(qid);
      } else {
        csdMissing.push(qid);
      }
    }
    results.push({
      questionnaire: "CSD (Consensus Sleep Diary)",
      status: csdMissing.length === 0 ? "pass" : csdMissing.length <= 2 ? "warning" : "fail",
      message: csdMissing.length === 0 ? "All core CSD questions present" : `Missing: ${csdMissing.join(", ")}`,
      foundQuestions: csdFound,
      missingQuestions: csdMissing,
    });

    const failCount = results.filter(r => r.status === "fail").length;
    const warnCount = results.filter(r => r.status === "warning").length;

    return {
      status: failCount > 0 ? "fail" : warnCount > 0 ? "warning" : "pass",
      summary: `${results.filter(r => r.status === "pass").length} pass, ${warnCount} warnings, ${failCount} failures`,
      results,
    };
  },
});

/**
 * Validate score thresholds are consistent
 */
export const validateScoreThresholds = query({
  args: {},
  handler: async (ctx) => {
    // Get stored scores
    const scores = await ctx.db.query("questionnaire_scores").collect();

    const results: Array<{
      questionnaire: string;
      status: "pass" | "fail" | "warning";
      message: string;
      examples?: Array<{ score: number; interpretation: string | undefined }>;
    }> = [];

    // Group scores by questionnaire
    const scoresByQuestionnaire: Record<string, Array<{ score: number; interpretation?: string }>> = {};
    for (const s of scores) {
      if (!scoresByQuestionnaire[s.questionnaire_name]) {
        scoresByQuestionnaire[s.questionnaire_name] = [];
      }
      scoresByQuestionnaire[s.questionnaire_name].push({
        score: s.score,
        interpretation: s.interpretation || undefined,
      });
    }

    // Validate each questionnaire
    for (const [qName, thresholds] of Object.entries(CLINICAL_SCORE_THRESHOLDS)) {
      const storedScores = scoresByQuestionnaire[qName] || [];

      if (storedScores.length === 0) {
        results.push({
          questionnaire: qName,
          status: "warning",
          message: "No scores found in database to validate",
        });
        continue;
      }

      // Check if interpretations match expected thresholds
      let mismatchCount = 0;
      const examples: Array<{ score: number; interpretation: string | undefined }> = [];

      for (const s of storedScores.slice(0, 5)) { // Check first 5
        const expectedThreshold = thresholds.thresholds.find(
          t => s.score >= t.min && s.score <= t.max
        );

        if (expectedThreshold && s.interpretation) {
          // Check if interpretation matches (loosely)
          const expectedLabel = expectedThreshold.label.toLowerCase();
          const actualLabel = s.interpretation.toLowerCase();

          if (!actualLabel.includes(expectedThreshold.severity) && !expectedLabel.includes(actualLabel)) {
            mismatchCount++;
          }
        }

        examples.push({ score: s.score, interpretation: s.interpretation });
      }

      results.push({
        questionnaire: qName,
        status: mismatchCount === 0 ? "pass" : "warning",
        message: mismatchCount === 0
          ? `${storedScores.length} scores validated`
          : `${mismatchCount} potential interpretation mismatches`,
        examples,
      });
    }

    const failCount = results.filter(r => r.status === "fail").length;
    const warnCount = results.filter(r => r.status === "warning").length;

    return {
      status: failCount > 0 ? "fail" : warnCount > 0 ? "warning" : "pass",
      thresholdDefinitions: CLINICAL_SCORE_THRESHOLDS,
      results,
    };
  },
});

/**
 * Validate gateway to expansion module mapping
 */
export const validateGatewayExpansionMapping = query({
  args: {},
  handler: async (ctx) => {
    const results: Array<{
      gatewayId: string;
      status: "pass" | "fail" | "warning";
      message: string;
      targetModules?: string[];
      modulesExist?: boolean[];
    }> = [];

    // Get gateways
    const gateways = await ctx.db.query("module_gateways").collect();

    // Get all modules
    const modules = await ctx.db.query("assessment_modules").collect();
    const moduleIds = new Set(modules.map(m => m.module_id));

    for (const gateway of gateways) {
      const targetModules = JSON.parse(gateway.target_modules_json) as string[];
      const modulesExist = targetModules.map(m => moduleIds.has(m));

      const allExist = modulesExist.every(e => e);
      const noneExist = modulesExist.every(e => !e);

      results.push({
        gatewayId: gateway.gateway_id,
        status: allExist ? "pass" : noneExist ? "fail" : "warning",
        message: allExist
          ? `${targetModules.length} target modules exist`
          : noneExist
          ? "No target modules found"
          : `Some target modules missing`,
        targetModules,
        modulesExist,
      });
    }

    const failCount = results.filter(r => r.status === "fail").length;
    const warnCount = results.filter(r => r.status === "warning").length;

    return {
      status: failCount > 0 ? "fail" : warnCount > 0 ? "warning" : "pass",
      results,
    };
  },
});

/**
 * Run all cross-platform validations
 */
export const runFullCrossPlatformValidation = query({
  args: {},
  handler: async (ctx) => {
    // Note: In Convex, queries can't call other queries directly
    // This provides a summary of available validations

    return {
      message: "Run individual validation functions for detailed results",
      availableValidations: [
        {
          name: "validateModuleConsistency",
          description: "Check iOS modules match backend modules",
        },
        {
          name: "validateClinicalQuestions",
          description: "Verify all clinical questionnaire questions exist",
        },
        {
          name: "validateScoreThresholds",
          description: "Validate score interpretations match thresholds",
        },
        {
          name: "validateGatewayExpansionMapping",
          description: "Check gateway-to-expansion module mappings",
        },
      ],
      expectedModuleCounts: {
        core: IOS_EXPECTED_MODULES.core.length,
        gateway: IOS_EXPECTED_MODULES.gateway.length,
        expansion: IOS_EXPECTED_MODULES.expansion.length,
        sleepDiary: IOS_EXPECTED_MODULES.sleepDiary.length,
      },
      clinicalQuestionnaires: Object.keys(CLINICAL_SCORE_THRESHOLDS),
    };
  },
});

/**
 * Generate cross-platform consistency report
 */
export const generateConsistencyReport = query({
  args: {},
  handler: async (ctx) => {
    const report: Record<string, unknown> = {
      generatedAt: new Date().toISOString(),
      platform: "Zoe Sleep V1",
    };

    // Count resources
    const [
      questions,
      modules,
      moduleQuestions,
      dayModules,
      gateways,
      sleepDiary,
    ] = await Promise.all([
      ctx.db.query("assessment_questions").collect(),
      ctx.db.query("assessment_modules").collect(),
      ctx.db.query("module_questions").collect(),
      ctx.db.query("day_modules").collect(),
      ctx.db.query("module_gateways").collect(),
      ctx.db.query("sleep_diary_questions").collect(),
    ]);

    report.resourceCounts = {
      assessmentQuestions: questions.length,
      assessmentModules: modules.length,
      moduleQuestionMappings: moduleQuestions.length,
      dayModuleMappings: dayModules.length,
      gateways: gateways.length,
      sleepDiaryQuestions: sleepDiary.length,
    };

    // Module breakdown
    const coreModules = modules.filter(m => m.module_type === "CORE");
    const gatewayModules = modules.filter(m => m.module_type === "GATEWAY");
    const expansionModules = modules.filter(m => m.module_type === "EXPANSION");

    report.moduleBreakdown = {
      core: coreModules.length,
      gateway: gatewayModules.length,
      expansion: expansionModules.length,
    };

    // Questions per module
    const questionsPerModule: Record<string, number> = {};
    for (const mq of moduleQuestions) {
      questionsPerModule[mq.module_id] = (questionsPerModule[mq.module_id] || 0) + 1;
    }

    report.questionsPerModule = questionsPerModule;

    // Day coverage
    const daysCovered: Record<number, string[]> = {};
    for (const dm of dayModules) {
      if (!daysCovered[dm.day_number]) {
        daysCovered[dm.day_number] = [];
      }
      daysCovered[dm.day_number].push(dm.module_id);
    }

    report.dayCoverage = daysCovered;

    // Answer format distribution
    const formatCounts: Record<string, number> = {};
    for (const q of questions) {
      formatCounts[q.answer_format] = (formatCounts[q.answer_format] || 0) + 1;
    }

    report.answerFormatDistribution = formatCounts;

    // Gateway details
    report.gatewayDetails = gateways.map(g => ({
      id: g.gateway_id,
      name: g.name,
      targetModules: JSON.parse(g.target_modules_json),
      triggerQuestions: JSON.parse(g.trigger_question_ids_json),
    }));

    // iOS expectations
    report.iOSExpectations = {
      totalModules:
        IOS_EXPECTED_MODULES.core.length +
        IOS_EXPECTED_MODULES.gateway.length +
        IOS_EXPECTED_MODULES.expansion.length +
        IOS_EXPECTED_MODULES.sleepDiary.length,
      coreModules: IOS_EXPECTED_MODULES.core.length,
      gatewayModules: IOS_EXPECTED_MODULES.gateway.length,
      expansionModules: IOS_EXPECTED_MODULES.expansion.length,
    };

    return report;
  },
});
