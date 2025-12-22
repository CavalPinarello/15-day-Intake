/**
 * Seed Clinical Data - Comprehensive seeder for missing questionnaires, gateways, and modules
 * Run with: npx convex run seedClinicalData:seedAll
 *
 * This fixes:
 * 1. Missing gateway definitions
 * 2. Missing clinical questionnaire questions (ISI, PHQ-9, GAD-7, ESS, STOP-BANG, CSD)
 * 3. Missing expansion modules
 * 4. Slider scale questions missing scaleMin/scaleMax
 */

import { internalMutation, mutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

// ============================================
// Gateway Definitions
// ============================================

const GATEWAY_DEFINITIONS = [
  {
    gateway_id: "insomnia",
    name: "Insomnia",
    description: "Difficulty falling asleep, staying asleep, or waking too early",
    trigger_question_ids: ["3", "ISI_1", "ISI_2", "ISI_3"],
    expansion_module_ids: ["expansion_isi", "expansion_dbas", "expansion_psas"],
  },
  {
    gateway_id: "depression",
    name: "Depression",
    description: "Feelings of sadness, hopelessness, or loss of interest",
    trigger_question_ids: ["15", "PHQ9_1", "PHQ9_2"],
    expansion_module_ids: ["expansion_phq9", "expansion_dass21"],
  },
  {
    gateway_id: "anxiety",
    name: "Anxiety",
    description: "Excessive worry, nervousness, or restlessness",
    trigger_question_ids: ["16", "GAD7_1", "GAD7_2"],
    expansion_module_ids: ["expansion_gad7", "expansion_dass21", "expansion_psas"],
  },
  {
    gateway_id: "osa",
    name: "Obstructive Sleep Apnea",
    description: "Snoring, witnessed apneas, or breathing pauses during sleep",
    trigger_question_ids: ["19", "20", "SB_1", "SB_2"],
    expansion_module_ids: ["expansion_stop_bang", "expansion_ess", "expansion_berlin"],
  },
  {
    gateway_id: "excessive_sleepiness",
    name: "Excessive Daytime Sleepiness",
    description: "Difficulty staying awake or excessive fatigue during the day",
    trigger_question_ids: ["17", "ESS_1", "ESS_2"],
    expansion_module_ids: ["expansion_ess", "expansion_fss", "expansion_fosq"],
  },
  {
    gateway_id: "poor_sleep_quality",
    name: "Poor Sleep Quality",
    description: "Non-restorative sleep despite adequate duration",
    trigger_question_ids: ["1", "CSD_QUALITY"],
    expansion_module_ids: ["expansion_psqi", "expansion_sleep_hygiene"],
  },
  {
    gateway_id: "sleep_timing",
    name: "Sleep Timing Issues",
    description: "Delayed or advanced sleep phase, irregular schedule",
    trigger_question_ids: ["7", "8", "9", "10"],
    expansion_module_ids: ["expansion_meq"],
  },
  {
    gateway_id: "cognitive",
    name: "Cognitive Concerns",
    description: "Memory, concentration, or cognitive function issues",
    trigger_question_ids: ["21"],
    expansion_module_ids: ["expansion_promis"],
  },
  {
    gateway_id: "pain",
    name: "Chronic Pain",
    description: "Pain that interferes with sleep",
    trigger_question_ids: ["22", "23"],
    expansion_module_ids: ["expansion_bpi"],
  },
  {
    gateway_id: "circadian_misalignment",
    name: "Circadian Misalignment",
    description: "Mismatch between internal clock and desired schedule",
    trigger_question_ids: ["7", "8", "9", "10"],
    expansion_module_ids: ["expansion_meq"],
  },
  {
    gateway_id: "diet_impact",
    name: "Diet Impact on Sleep",
    description: "Dietary habits affecting sleep quality",
    trigger_question_ids: ["33", "34"],
    expansion_module_ids: ["expansion_nutritional"],
  },
];

// ============================================
// Clinical Questionnaire Questions
// ============================================

const CLINICAL_QUESTIONS = [
  // ISI (Insomnia Severity Index) - 7 questions, each 0-4
  ...Array.from({ length: 7 }, (_, i) => ({
    question_id: `ISI_${i + 1}`,
    question_text: [
      "Difficulty falling asleep",
      "Difficulty staying asleep",
      "Problems waking up too early",
      "How satisfied/dissatisfied are you with your current sleep pattern?",
      "How noticeable to others do you think your sleep problem is in terms of impairing the quality of your life?",
      "How worried/distressed are you about your current sleep problem?",
      "To what extent do you consider your sleep problem to interfere with your daily functioning?",
    ][i],
    pillar: "Sleep Quality",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 0,
      scaleMax: 4,
      labels: ["None", "Mild", "Moderate", "Severe", "Very Severe"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // PHQ-9 (Patient Health Questionnaire) - 9 questions, each 0-3
  ...Array.from({ length: 9 }, (_, i) => ({
    question_id: `PHQ9_${i + 1}`,
    question_text: [
      "Little interest or pleasure in doing things",
      "Feeling down, depressed, or hopeless",
      "Trouble falling or staying asleep, or sleeping too much",
      "Feeling tired or having little energy",
      "Poor appetite or overeating",
      "Feeling bad about yourself - or that you are a failure or have let yourself or your family down",
      "Trouble concentrating on things, such as reading the newspaper or watching television",
      "Moving or speaking so slowly that other people could have noticed? Or the opposite - being so fidgety or restless?",
      "Thoughts that you would be better off dead, or of hurting yourself in some way",
    ][i],
    help_text: "Over the last 2 weeks, how often have you been bothered by this problem?",
    pillar: "Mental Health",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 0,
      scaleMax: 3,
      labels: ["Not at all", "Several days", "More than half the days", "Nearly every day"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 20,
  })),

  // GAD-7 (Generalized Anxiety Disorder) - 7 questions, each 0-3
  ...Array.from({ length: 7 }, (_, i) => ({
    question_id: `GAD7_${i + 1}`,
    question_text: [
      "Feeling nervous, anxious, or on edge",
      "Not being able to stop or control worrying",
      "Worrying too much about different things",
      "Trouble relaxing",
      "Being so restless that it's hard to sit still",
      "Becoming easily annoyed or irritable",
      "Feeling afraid, as if something awful might happen",
    ][i],
    help_text: "Over the last 2 weeks, how often have you been bothered by this problem?",
    pillar: "Mental Health",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 0,
      scaleMax: 3,
      labels: ["Not at all", "Several days", "More than half the days", "Nearly every day"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // ESS (Epworth Sleepiness Scale) - 8 questions, each 0-3
  ...Array.from({ length: 8 }, (_, i) => ({
    question_id: `ESS_${i + 1}`,
    question_text: [
      "Sitting and reading",
      "Watching TV",
      "Sitting inactive in a public place (e.g., a theater or a meeting)",
      "As a passenger in a car for an hour without a break",
      "Lying down to rest in the afternoon when circumstances permit",
      "Sitting and talking to someone",
      "Sitting quietly after lunch without alcohol",
      "In a car, while stopped for a few minutes in traffic",
    ][i],
    help_text: "How likely are you to doze off or fall asleep in this situation?",
    pillar: "Sleep Quality",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 0,
      scaleMax: 3,
      labels: ["Would never doze", "Slight chance", "Moderate chance", "High chance"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // STOP-BANG - 8 yes/no questions
  {
    question_id: "SB_1",
    question_text: "Do you SNORE loudly (loud enough to be heard through closed doors or your bed-partner elbows you for snoring at night)?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "SB_2",
    question_text: "Do you often feel TIRED, fatigued, or sleepy during the daytime?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "SB_3",
    question_text: "Has anyone OBSERVED you stop breathing or choking/gasping during your sleep?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "SB_4",
    question_text: "Do you have or are you being treated for high blood PRESSURE?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "SB_5",
    question_text: "Is your BMI more than 35 kg/m²?",
    help_text: "BMI = Body Mass Index (calculated from height and weight)",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "SB_6",
    question_text: "Are you older than 50 years of age?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "SB_7",
    question_text: "Is your neck circumference greater than 40 cm (16 inches)?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "SB_8",
    question_text: "Are you male?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },

  // CSD (Consensus Sleep Diary) - Core questions
  {
    question_id: "CSD_BEDTIME",
    question_text: "What time did you get into bed?",
    pillar: "Sleep Timing",
    tier: "CORE",
    answer_format: "time_picker",
    format_config: { format: "HH:mm", defaultHour: 22, minuteInterval: 15 },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "CSD_LATENCY",
    question_text: "How long did it take you to fall asleep?",
    help_text: "In minutes",
    pillar: "Sleep Quality",
    tier: "CORE",
    answer_format: "minutes_scroll",
    format_config: { minValue: 0, maxValue: 180, step: 5, unit: "minutes" },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "CSD_AWAKENINGS",
    question_text: "How many times did you wake up during the night?",
    pillar: "Sleep Quality",
    tier: "CORE",
    answer_format: "number_scroll",
    format_config: { minValue: 0, maxValue: 20, step: 1 },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "CSD_WASO",
    question_text: "In total, how long were you awake during the night?",
    help_text: "Total minutes awake after falling asleep",
    pillar: "Sleep Quality",
    tier: "CORE",
    answer_format: "minutes_scroll",
    format_config: { minValue: 0, maxValue: 300, step: 5, unit: "minutes" },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "CSD_OUT_BED",
    question_text: "What time did you get out of bed for the day?",
    pillar: "Sleep Timing",
    tier: "CORE",
    answer_format: "time_picker",
    format_config: { format: "HH:mm", defaultHour: 7, minuteInterval: 15 },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "CSD_QUALITY",
    question_text: "How would you rate your sleep quality?",
    pillar: "Sleep Quality",
    tier: "CORE",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 5,
      labels: ["Very poor", "Poor", "Fair", "Good", "Very good"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "CSD_ALERT",
    question_text: "How refreshed did you feel upon waking?",
    pillar: "Sleep Quality",
    tier: "CORE",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 5,
      labels: ["Not at all", "Slightly", "Somewhat", "Fairly", "Very"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "CSD_NAPS",
    question_text: "Did you take any naps yesterday?",
    pillar: "Sleep Timing",
    tier: "CORE",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
];

// ============================================
// Expansion Modules
// ============================================

const EXPANSION_MODULES = [
  {
    module_id: "expansion_isi",
    name: "ISI",
    description: "Insomnia Severity Index - 7-item insomnia assessment",
    pillar: "Sleep Quality",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 3,
    question_ids: ["ISI_1", "ISI_2", "ISI_3", "ISI_4", "ISI_5", "ISI_6", "ISI_7"],
  },
  {
    module_id: "expansion_phq9",
    name: "PHQ-9",
    description: "Patient Health Questionnaire - 9-item depression screen",
    pillar: "Mental Health",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 4,
    question_ids: ["PHQ9_1", "PHQ9_2", "PHQ9_3", "PHQ9_4", "PHQ9_5", "PHQ9_6", "PHQ9_7", "PHQ9_8", "PHQ9_9"],
  },
  {
    module_id: "expansion_gad7",
    name: "GAD-7",
    description: "Generalized Anxiety Disorder - 7-item anxiety screen",
    pillar: "Mental Health",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 3,
    question_ids: ["GAD7_1", "GAD7_2", "GAD7_3", "GAD7_4", "GAD7_5", "GAD7_6", "GAD7_7"],
  },
  {
    module_id: "expansion_ess",
    name: "ESS",
    description: "Epworth Sleepiness Scale - 8-item daytime sleepiness assessment",
    pillar: "Sleep Quality",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 3,
    question_ids: ["ESS_1", "ESS_2", "ESS_3", "ESS_4", "ESS_5", "ESS_6", "ESS_7", "ESS_8"],
  },
  {
    module_id: "expansion_stop_bang",
    name: "STOP-BANG",
    description: "Sleep apnea screening questionnaire",
    pillar: "Physical",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 2,
    question_ids: ["SB_1", "SB_2", "SB_3", "SB_4", "SB_5", "SB_6", "SB_7", "SB_8"],
  },
  {
    module_id: "csd_sleep_log",
    name: "Consensus Sleep Diary",
    description: "Daily sleep log based on consensus sleep diary",
    pillar: "Sleep Quality",
    tier: "CORE",
    module_type: "CORE",
    estimated_minutes: 2,
    question_ids: ["CSD_BEDTIME", "CSD_LATENCY", "CSD_AWAKENINGS", "CSD_WASO", "CSD_OUT_BED", "CSD_QUALITY", "CSD_ALERT", "CSD_NAPS"],
  },
];

// ============================================
// Seed Functions
// ============================================

/**
 * Seed gateway definitions
 */
export const seedGateways = internalMutation({
  args: {},
  returns: v.object({
    inserted: v.number(),
    updated: v.number(),
    errors: v.array(v.string()),
  }),
  handler: async (ctx) => {
    const errors: string[] = [];
    let inserted = 0;
    let updated = 0;
    const now = Date.now();

    for (const gateway of GATEWAY_DEFINITIONS) {
      try {
        const existing = await ctx.db
          .query("module_gateways")
          .withIndex("by_gateway_id", (q) => q.eq("gateway_id", gateway.gateway_id))
          .first();

        // Build condition JSON - simple trigger logic
        const conditionJson = JSON.stringify({
          type: "any_triggered",
          question_ids: gateway.trigger_question_ids,
        });

        const data = {
          name: gateway.name,
          description: gateway.description,
          condition_json: conditionJson,
          target_modules_json: JSON.stringify(gateway.expansion_module_ids),
          trigger_question_ids_json: JSON.stringify(gateway.trigger_question_ids),
        };

        if (existing) {
          await ctx.db.patch(existing._id, data);
          updated++;
        } else {
          await ctx.db.insert("module_gateways", {
            gateway_id: gateway.gateway_id,
            ...data,
            created_at: now,
          });
          inserted++;
        }
      } catch (error) {
        errors.push(`Gateway ${gateway.gateway_id}: ${error}`);
      }
    }

    return { inserted, updated, errors };
  },
});

/**
 * Seed clinical questionnaire questions
 */
export const seedClinicalQuestions = internalMutation({
  args: {},
  returns: v.object({
    inserted: v.number(),
    updated: v.number(),
    errors: v.array(v.string()),
  }),
  handler: async (ctx) => {
    const errors: string[] = [];
    let inserted = 0;
    let updated = 0;
    const now = Date.now();

    for (const q of CLINICAL_QUESTIONS) {
      try {
        const existing = await ctx.db
          .query("assessment_questions")
          .withIndex("by_question_id", (query) => query.eq("question_id", q.question_id))
          .first();

        const data = {
          question_text: q.question_text,
          help_text: q.help_text,
          pillar: q.pillar,
          tier: q.tier,
          answer_format: q.answer_format,
          format_config: JSON.stringify(q.format_config),
          validation_rules: JSON.stringify(q.validation_rules),
          estimated_time_seconds: q.estimated_time_seconds,
          updated_at: now,
        };

        if (existing) {
          await ctx.db.patch(existing._id, data);
          updated++;
        } else {
          await ctx.db.insert("assessment_questions", {
            question_id: q.question_id,
            ...data,
            created_at: now,
          });
          inserted++;
        }
      } catch (error) {
        errors.push(`Question ${q.question_id}: ${error}`);
      }
    }

    return { inserted, updated, errors };
  },
});

/**
 * Seed expansion modules
 */
export const seedExpansionModules = internalMutation({
  args: {},
  returns: v.object({
    modulesInserted: v.number(),
    modulesUpdated: v.number(),
    mappingsInserted: v.number(),
    errors: v.array(v.string()),
  }),
  handler: async (ctx) => {
    const errors: string[] = [];
    let modulesInserted = 0;
    let modulesUpdated = 0;
    let mappingsInserted = 0;

    for (const module of EXPANSION_MODULES) {
      try {
        // Upsert module
        const existing = await ctx.db
          .query("assessment_modules")
          .withIndex("by_module_id", (query) => query.eq("module_id", module.module_id))
          .first();

        if (existing) {
          await ctx.db.patch(existing._id, {
            name: module.name,
            description: module.description,
            pillar: module.pillar,
            tier: module.tier,
            module_type: module.module_type,
            estimated_minutes: module.estimated_minutes,
          });
          modulesUpdated++;
        } else {
          await ctx.db.insert("assessment_modules", {
            module_id: module.module_id,
            name: module.name,
            description: module.description,
            pillar: module.pillar,
            tier: module.tier,
            module_type: module.module_type,
            estimated_minutes: module.estimated_minutes,
          });
          modulesInserted++;
        }

        // Seed module-question mappings
        for (let i = 0; i < module.question_ids.length; i++) {
          const existingMapping = await ctx.db
            .query("module_questions")
            .withIndex("by_module", (q) => q.eq("module_id", module.module_id))
            .filter((q) => q.eq(q.field("question_id"), module.question_ids[i]))
            .first();

          if (!existingMapping) {
            await ctx.db.insert("module_questions", {
              module_id: module.module_id,
              question_id: module.question_ids[i],
              order_index: i,
            });
            mappingsInserted++;
          }
        }
      } catch (error) {
        errors.push(`Module ${module.module_id}: ${error}`);
      }
    }

    return { modulesInserted, modulesUpdated, mappingsInserted, errors };
  },
});

/**
 * Fix question 33D (missing options for multi_select_chips)
 */
export const fixQuestion33D = internalMutation({
  args: {},
  returns: v.object({
    fixed: v.boolean(),
    error: v.optional(v.string()),
  }),
  handler: async (ctx) => {
    try {
      const question = await ctx.db
        .query("assessment_questions")
        .withIndex("by_question_id", (q) => q.eq("question_id", "33D"))
        .first();

      if (!question) {
        return { fixed: false, error: "Question 33D not found" };
      }

      const formatConfig = {
        options: [
          { value: "none", label: "None" },
          { value: "melatonin", label: "Melatonin" },
          { value: "prescription_sleep_aid", label: "Prescription sleep medication" },
          { value: "otc_sleep_aid", label: "Over-the-counter sleep aid" },
          { value: "antihistamines", label: "Antihistamines (Benadryl, etc.)" },
          { value: "herbal_supplements", label: "Herbal supplements (valerian, chamomile, etc.)" },
          { value: "cbd_cannabis", label: "CBD or cannabis" },
          { value: "alcohol", label: "Alcohol" },
          { value: "other", label: "Other" },
        ],
        layout: "grid",
        minSelections: 0,
        maxSelections: 10,
      };

      await ctx.db.patch(question._id, {
        format_config: JSON.stringify(formatConfig),
        updated_at: Date.now(),
      });

      return { fixed: true };
    } catch (error) {
      return { fixed: false, error: String(error) };
    }
  },
});

/**
 * Fix slider_scale questions missing scaleMin/scaleMax
 */
export const fixSliderScaleQuestions = internalMutation({
  args: {},
  returns: v.object({
    fixed: v.number(),
    alreadyValid: v.number(),
    errors: v.array(v.string()),
  }),
  handler: async (ctx) => {
    const errors: string[] = [];
    let fixed = 0;
    let alreadyValid = 0;

    // Get all slider_scale questions
    const sliderQuestions = await ctx.db
      .query("assessment_questions")
      .withIndex("by_answer_format", (q) => q.eq("answer_format", "slider_scale"))
      .collect();

    // Default scale configurations based on question patterns
    const SCALE_DEFAULTS: Record<string, { min: number; max: number; labels?: string[] }> = {
      // ISI questions (0-4)
      "ISI_": { min: 0, max: 4, labels: ["None", "Mild", "Moderate", "Severe", "Very Severe"] },
      // PHQ-9 questions (0-3)
      "PHQ9_": { min: 0, max: 3, labels: ["Not at all", "Several days", "More than half", "Nearly every day"] },
      // GAD-7 questions (0-3)
      "GAD7_": { min: 0, max: 3, labels: ["Not at all", "Several days", "More than half", "Nearly every day"] },
      // ESS questions (0-3)
      "ESS_": { min: 0, max: 3, labels: ["Never", "Slight", "Moderate", "High"] },
      // DBAS questions (0-10)
      "DBAS_": { min: 0, max: 10 },
      // PSAS questions (1-5)
      "PSAS_": { min: 1, max: 5 },
      // FSS questions (1-7)
      "FSS_": { min: 1, max: 7 },
      // FOSQ questions (1-4)
      "FOSQ_": { min: 1, max: 4 },
      // PROMIS questions (1-5)
      "PROMIS_": { min: 1, max: 5 },
      // BPI questions (0-10)
      "BPI_": { min: 0, max: 10 },
      // MEQ questions (1-5)
      "MEQ_": { min: 1, max: 5 },
      // DASS questions (0-3)
      "DASS_": { min: 0, max: 3 },
      // PSQI questions (0-3)
      "PSQI_": { min: 0, max: 3 },
      // Default for general questions
      "default": { min: 1, max: 10 },
    };

    for (const q of sliderQuestions) {
      try {
        let formatConfig: any;
        try {
          formatConfig = JSON.parse(q.format_config || "{}");
        } catch {
          formatConfig = {};
        }

        // Check if already has valid scale config
        if (formatConfig.scaleMin !== undefined && formatConfig.scaleMax !== undefined) {
          alreadyValid++;
          continue;
        }

        // Find matching scale defaults
        let scaleConfig = SCALE_DEFAULTS.default;
        for (const [prefix, config] of Object.entries(SCALE_DEFAULTS)) {
          if (prefix !== "default" && q.question_id.startsWith(prefix)) {
            scaleConfig = config;
            break;
          }
        }

        // Update format_config with scale values
        formatConfig.scaleMin = scaleConfig.min;
        formatConfig.scaleMax = scaleConfig.max;
        if (scaleConfig.labels) {
          formatConfig.labels = scaleConfig.labels;
        }
        formatConfig.step = 1;

        await ctx.db.patch(q._id, {
          format_config: JSON.stringify(formatConfig),
          updated_at: Date.now(),
        });
        fixed++;
      } catch (error) {
        errors.push(`Question ${q.question_id}: ${error}`);
      }
    }

    return { fixed, alreadyValid, errors };
  },
});

/**
 * Run all seeders
 */
export const seedAll = mutation({
  args: {},
  returns: v.object({
    gateways: v.object({
      inserted: v.number(),
      updated: v.number(),
      errors: v.array(v.string()),
    }),
    questions: v.object({
      inserted: v.number(),
      updated: v.number(),
      errors: v.array(v.string()),
    }),
    modules: v.object({
      modulesInserted: v.number(),
      modulesUpdated: v.number(),
      mappingsInserted: v.number(),
      errors: v.array(v.string()),
    }),
    sliderFix: v.object({
      fixed: v.number(),
      alreadyValid: v.number(),
      errors: v.array(v.string()),
    }),
    question33D: v.object({
      fixed: v.boolean(),
      error: v.optional(v.string()),
    }),
  }),
  handler: async (ctx) => {
    // Run all seeders
    const gateways = await ctx.runMutation(internal.seedClinicalData.seedGateways, {});
    const questions = await ctx.runMutation(internal.seedClinicalData.seedClinicalQuestions, {});
    const modules = await ctx.runMutation(internal.seedClinicalData.seedExpansionModules, {});
    const sliderFix = await ctx.runMutation(internal.seedClinicalData.fixSliderScaleQuestions, {});
    const question33D = await ctx.runMutation(internal.seedClinicalData.fixQuestion33D, {});

    return { gateways, questions, modules, sliderFix, question33D };
  },
});
