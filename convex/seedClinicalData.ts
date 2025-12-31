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

import { internalMutation, mutation, MutationCtx } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// Gateway Definitions
// ============================================

const GATEWAY_DEFINITIONS = [
  {
    gateway_id: "insomnia",
    name: "Insomnia",
    description: "Difficulty falling asleep, staying asleep, or waking too early",
    trigger_question_ids: ["3", "ISI_1", "ISI_2", "ISI_3"],
    expansion_module_ids: ["expansion_isi", "expansion_dbas6", "expansion_psas_cognitive", "expansion_psas_somatic"], // DBAS-6 (2024) replaces DBAS-16
  },
  {
    gateway_id: "depression",
    name: "Depression",
    description: "Feelings of sadness, hopelessness, or loss of interest",
    trigger_question_ids: ["15", "PHQ9_1", "PHQ9_2"],
    expansion_module_ids: ["expansion_phq9"],
  },
  {
    gateway_id: "anxiety",
    name: "Anxiety",
    description: "Excessive worry, nervousness, or restlessness",
    trigger_question_ids: ["16", "GAD7_1", "GAD7_2"],
    expansion_module_ids: ["expansion_gad7", "expansion_psas_cognitive", "expansion_psas_somatic"],
  },
  {
    gateway_id: "osa",
    name: "Obstructive Sleep Apnea",
    description: "Snoring, witnessed apneas, or breathing pauses during sleep",
    trigger_question_ids: ["19", "20", "48", "49", "SB_1", "SB_2"],
    expansion_module_ids: ["expansion_stop_bang", "expansion_ess"], // Berlin removed - STOP-BANG has 93% sensitivity
  },
  {
    gateway_id: "excessive_sleepiness",
    name: "Excessive Daytime Sleepiness",
    description: "Difficulty staying awake or excessive fatigue during the day",
    trigger_question_ids: ["17", "ESS_1", "ESS_2"],
    expansion_module_ids: ["expansion_ess", "expansion_fss", "expansion_fosq_part1", "expansion_fosq_part2"],
  },
  {
    gateway_id: "poor_sleep_quality",
    name: "Poor Sleep Quality",
    description: "Non-restorative sleep despite adequate duration",
    trigger_question_ids: ["1", "CSD_QUALITY"],
    expansion_module_ids: ["expansion_sleep_hygiene_part1", "expansion_sleep_hygiene_part2"],
  },
  {
    gateway_id: "sleep_timing",
    name: "Sleep Timing Issues",
    description: "Delayed or advanced sleep phase, irregular schedule",
    trigger_question_ids: ["7", "8", "9", "10"],
    expansion_module_ids: ["expansion_meq_part1", "expansion_meq_part2"],
  },
  {
    gateway_id: "cognitive",
    name: "Cognitive Concerns",
    description: "Memory, concentration, or cognitive function issues",
    trigger_question_ids: ["18"],
    expansion_module_ids: ["expansion_promis_cognitive"],
  },
  {
    gateway_id: "pain",
    name: "Chronic Pain",
    description: "Pain that interferes with sleep",
    trigger_question_ids: ["22", "23", "53"],
    expansion_module_ids: ["expansion_bpi_part1", "expansion_bpi_part2"],
  },
  {
    gateway_id: "circadian_misalignment",
    name: "Circadian Misalignment",
    description: "Mismatch between internal clock and desired schedule",
    trigger_question_ids: ["7", "8", "9", "10"],
    expansion_module_ids: ["expansion_meq_part1", "expansion_meq_part2"],
  },
  {
    gateway_id: "diet_impact",
    name: "Diet Impact on Sleep",
    description: "Dietary habits affecting sleep quality",
    trigger_question_ids: ["33", "34"],
    expansion_module_ids: ["expansion_medas"],
  },
  {
    gateway_id: "shift_work",
    name: "Shift Work Disorder",
    description: "Work schedule that conflicts with normal sleep patterns, including night shifts, rotating shifts, and irregular hours",
    trigger_question_ids: ["53B"],
    expansion_module_ids: ["expansion_swdsq"],
  },
  {
    gateway_id: "exercise",
    name: "Physical Activity",
    description: "Regular physical activity and its relationship to sleep quality",
    trigger_question_ids: ["24"],
    expansion_module_ids: ["expansion_physical_1", "expansion_physical_2"],
  },
  // Note: Prostate follow-ups (Q47_PROSTATE, Q47_STREAM) are conditional questions
  // in core_sleep_quality_2, not a gateway expansion. They show via conditional logic
  // for male users 45+ who report frequent nocturia (Q47 >= 2).
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

  // ============================================
  // PROMIS Cognitive Function (6 questions, 1-5 scale)
  // Day 7: "Mood & Thinking"
  // ============================================
  ...Array.from({ length: 6 }, (_, i) => ({
    question_id: `PROMIS_COG_${i + 1}`,
    question_text: [
      "My thinking has been slow.",
      "It has seemed like my brain was not working as well as usual.",
      "I have had to work harder than usual to keep track of what I was doing.",
      "I have had trouble shifting back and forth between different activities.",
      "I have had trouble concentrating.",
      "My thinking has been foggy.",
    ][i],
    help_text: "In the past 7 days...",
    pillar: "Cognitive",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 5,
      labels: ["Never", "Rarely", "Sometimes", "Often", "Very Often"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // ============================================
  // Sleep Hygiene Index (10 questions, 1-5 scale)
  // Day 8: "Anxiety & Sleep Habits"
  // ============================================
  ...Array.from({ length: 10 }, (_, i) => ({
    question_id: `SH_${i + 1}`,
    question_text: [
      "I go to bed at different times from day to day.",
      "I use alcohol, tobacco, or caffeine within 4 hours of going to bed.",
      "I do something that may wake me up before bedtime (e.g., exercise, video games).",
      "I stay in bed although I am awake.",
      "I use my bed for things other than sleeping or sex.",
      "I sleep in an uncomfortable bedroom (e.g., too bright, too stuffy, too hot).",
      "I do important work before bedtime.",
      "I think, plan, or worry when I am in bed.",
      "I have an irregular morning rising time.",
      "I take daytime naps lasting 2 or more hours.",
    ][i],
    pillar: "Sleep Quality",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 5,
      labels: ["Never", "Rarely", "Sometimes", "Frequently", "Always"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // ============================================
  // Berlin Questionnaire (10 questions)
  // Day 9: "Sleep Apnea Assessment"
  // ============================================
  {
    question_id: "BERLIN_1",
    question_text: "Do you snore?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }, { value: "Don't know", label: "Don't know" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "BERLIN_2",
    question_text: "Your snoring is:",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "slightly_louder", label: "Slightly louder than breathing" },
      { value: "as_loud_as_talking", label: "As loud as talking" },
      { value: "louder_than_talking", label: "Louder than talking" },
      { value: "very_loud", label: "Very loud" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "BERLIN_3",
    question_text: "How often do you snore?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "nearly_every_day", label: "Nearly every day" },
      { value: "3_4_times_week", label: "3-4 times per week" },
      { value: "1_2_times_week", label: "1-2 times per week" },
      { value: "1_2_times_month", label: "1-2 times per month" },
      { value: "never_rarely", label: "Never or nearly never" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "BERLIN_4",
    question_text: "Has your snoring ever bothered other people?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "BERLIN_5",
    question_text: "Has anyone noticed that you quit breathing during your sleep?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "nearly_every_day", label: "Nearly every day" },
      { value: "3_4_times_week", label: "3-4 times per week" },
      { value: "1_2_times_week", label: "1-2 times per week" },
      { value: "1_2_times_month", label: "1-2 times per month" },
      { value: "never_rarely", label: "Never or nearly never" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "BERLIN_6",
    question_text: "How often do you feel tired or fatigued after your sleep?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "nearly_every_day", label: "Nearly every day" },
      { value: "3_4_times_week", label: "3-4 times per week" },
      { value: "1_2_times_week", label: "1-2 times per week" },
      { value: "1_2_times_month", label: "1-2 times per month" },
      { value: "never_rarely", label: "Never or nearly never" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "BERLIN_7",
    question_text: "During your waking time, do you feel tired, fatigued, or not up to par?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "nearly_every_day", label: "Nearly every day" },
      { value: "3_4_times_week", label: "3-4 times per week" },
      { value: "1_2_times_week", label: "1-2 times per week" },
      { value: "1_2_times_month", label: "1-2 times per month" },
      { value: "never_rarely", label: "Never or nearly never" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "BERLIN_8",
    question_text: "Have you ever nodded off or fallen asleep while driving a vehicle?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "BERLIN_9",
    question_text: "How often does this (nodding off while driving) occur?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "nearly_every_day", label: "Nearly every day" },
      { value: "3_4_times_week", label: "3-4 times per week" },
      { value: "1_2_times_week", label: "1-2 times per week" },
      { value: "1_2_times_month", label: "1-2 times per month" },
      { value: "never_rarely", label: "Never or nearly never" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "BERLIN_10",
    question_text: "Do you have high blood pressure?",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }, { value: "Don't know", label: "Don't know" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },

  // ============================================
  // FSS - Fatigue Severity Scale (9 questions, 1-7 scale)
  // Day 10: "Daytime Energy"
  // ============================================
  ...Array.from({ length: 9 }, (_, i) => ({
    question_id: `FSS_${i + 1}`,
    question_text: [
      "My motivation is lower when I am fatigued.",
      "Exercise brings on my fatigue.",
      "I am easily fatigued.",
      "Fatigue interferes with my physical functioning.",
      "Fatigue causes frequent problems for me.",
      "My fatigue prevents sustained physical functioning.",
      "Fatigue interferes with carrying out certain duties and responsibilities.",
      "Fatigue is among my three most disabling symptoms.",
      "Fatigue interferes with my work, family, or social life.",
    ][i],
    help_text: "Please rate how much you agree with each statement.",
    pillar: "Sleep Quality",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 7,
      labels: ["Strongly Disagree", "Disagree", "Somewhat Disagree", "Neutral", "Somewhat Agree", "Agree", "Strongly Agree"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // ============================================
  // DBAS-16 - Dysfunctional Beliefs and Attitudes about Sleep (16 questions, 0-10 scale)
  // Days 11-12: "Beliefs & Pain"
  // ============================================
  ...Array.from({ length: 16 }, (_, i) => ({
    question_id: `DBAS_${i + 1}`,
    question_text: [
      "I need 8 hours of sleep to feel refreshed and function well during the day.",
      "When I don't get proper sleep, I need to catch up the next day by napping or sleeping longer.",
      "I am concerned that chronic insomnia may have serious consequences on my physical health.",
      "I am worried that I may lose control over my ability to sleep.",
      "After a poor night's sleep, I know it will interfere with my daily activities.",
      "To be alert during the day, I believe I would be better off taking sleeping pills.",
      "When I feel irritable or depressed during the day, it is mostly because I did not sleep well.",
      "When I sleep poorly one night, I know it will disturb my sleep schedule for the whole week.",
      "Without adequate sleep, I can hardly function the next day.",
      "I can't ever predict whether I'll have a good or poor night's sleep.",
      "I have little ability to manage the negative consequences of disturbed sleep.",
      "When I feel tired or lack energy during the day, it's generally because I didn't sleep well.",
      "I believe insomnia is essentially the result of a chemical imbalance.",
      "I feel insomnia is ruining my ability to enjoy life.",
      "Medication is probably the only solution to sleeplessness.",
      "I avoid scheduling important things in the morning after a poor night's sleep.",
    ][i],
    help_text: "Please indicate to what extent you personally agree with each statement.",
    pillar: "Mental Health",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 0,
      scaleMax: 10,
      labels: ["Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // ============================================
  // BPI - Brief Pain Inventory (11 questions, 0-10 scale)
  // Days 11-12: "Beliefs & Pain"
  // ============================================
  ...Array.from({ length: 11 }, (_, i) => ({
    question_id: `BPI_${i + 1}`,
    question_text: [
      "Rate your pain at its WORST in the last 24 hours.",
      "Rate your pain at its LEAST in the last 24 hours.",
      "Rate your pain on the AVERAGE.",
      "Rate your pain RIGHT NOW.",
      "How much has pain interfered with your GENERAL ACTIVITY?",
      "How much has pain interfered with your MOOD?",
      "How much has pain interfered with your WALKING ABILITY?",
      "How much has pain interfered with your NORMAL WORK (including housework)?",
      "How much has pain interfered with your RELATIONS WITH OTHER PEOPLE?",
      "How much has pain interfered with your SLEEP?",
      "How much has pain interfered with your ENJOYMENT OF LIFE?",
    ][i],
    help_text: i < 4 ? "0 = No pain, 10 = Pain as bad as you can imagine" : "0 = Does not interfere, 10 = Completely interferes",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 0,
      scaleMax: 10,
      labels: i < 4 ? ["No Pain", "Moderate", "Worst Pain"] : ["Does Not Interfere", "Somewhat Interferes", "Completely Interferes"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // ============================================
  // PSAS - Pre-Sleep Arousal Scale (16 questions, 1-5 scale)
  // Day 13: "Sleep Arousal & Function"
  // Cognitive subscale (8 questions)
  // ============================================
  ...Array.from({ length: 8 }, (_, i) => ({
    question_id: `PSAS_C${i + 1}`,
    question_text: [
      "Worry about falling asleep.",
      "Review or ponder events of the day.",
      "Depressing or anxious thoughts.",
      "Worry about problems other than sleep.",
      "Being mentally alert, active.",
      "Can't shut off your thoughts.",
      "Thoughts keep running through your head.",
      "Being distracted by sounds, etc. in the environment.",
    ][i],
    help_text: "As you attempt to fall asleep, how intensely do you experience...",
    pillar: "Mental Health",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 5,
      labels: ["Not at All", "Slightly", "Moderately", "A Lot", "Extremely"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // PSAS Somatic subscale (8 questions)
  ...Array.from({ length: 8 }, (_, i) => ({
    question_id: `PSAS_S${i + 1}`,
    question_text: [
      "Heart racing, pounding, or beating irregularly.",
      "A jittery, nervous feeling in your body.",
      "Shortness of breath or labored breathing.",
      "A tight, tense feeling in your muscles.",
      "Cold feeling in your hands, feet, or body.",
      "Have stomach upset (knot in stomach, heartburn, nausea).",
      "Perspiration in palms of hands or other parts of body.",
      "Dry feeling in mouth or throat.",
    ][i],
    help_text: "As you attempt to fall asleep, how intensely do you experience...",
    pillar: "Physical",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 5,
      labels: ["Not at All", "Slightly", "Moderately", "A Lot", "Extremely"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // ============================================
  // FOSQ-10 - Functional Outcomes of Sleep Questionnaire (10 questions, 1-4 scale)
  // Day 13: "Sleep Arousal & Function"
  // ============================================
  ...Array.from({ length: 10 }, (_, i) => ({
    question_id: `FOSQ_${i + 1}`,
    question_text: [
      "Do you have difficulty concentrating on the things you do?",
      "Do you have difficulty remembering things?",
      "Do you have difficulty finishing a meal?",
      "Do you have difficulty working on a hobby?",
      "Do you have difficulty doing work that requires you to use your hands?",
      "Do you have difficulty visiting with your family or friends in their home?",
      "Do you have difficulty doing household chores?",
      "Do you have difficulty operating a motor vehicle for short distances?",
      "Do you have difficulty being as active as you want to be in the evening?",
      "Do you have difficulty being as active as you want to be in the afternoon?",
    ][i],
    help_text: "Do you have difficulty with the following activities because of being tired or sleepy?",
    pillar: "Cognitive",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 4,
      labels: ["No Difficulty", "A Little Difficulty", "Moderate Difficulty", "Extreme Difficulty"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  })),

  // ============================================
  // MEDAS - Mediterranean Diet Adherence Screener (14 questions)
  // Day 14: "Diet & Chronotype"
  // ============================================
  {
    question_id: "MEDAS_1",
    question_text: "Do you use olive oil as your main culinary fat?",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_2",
    question_text: "How much olive oil do you consume in a given day (including oil used for frying, salads, etc.)?",
    help_text: "4 tablespoons = 2 servings",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "4_or_more", label: "4+ tablespoons" },
      { value: "2_to_3", label: "2-3 tablespoons" },
      { value: "less_than_2", label: "Less than 2 tablespoons" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_3",
    question_text: "How many vegetable servings do you consume per day?",
    help_text: "1 serving = 200g, count garnishes as half a serving",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "2_or_more", label: "2+ servings" },
      { value: "1", label: "1 serving" },
      { value: "less_than_1", label: "Less than 1" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_4",
    question_text: "How many fruit units (including fresh-squeezed juice) do you consume per day?",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "3_or_more", label: "3+ fruits" },
      { value: "1_to_2", label: "1-2 fruits" },
      { value: "less_than_1", label: "Less than 1" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_5",
    question_text: "How many servings of red meat, hamburger, or meat products (ham, sausage, etc.) do you consume per day?",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "less_than_1", label: "Less than 1" },
      { value: "1_or_more", label: "1 or more" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_6",
    question_text: "How many servings of butter, margarine, or cream do you consume per day?",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "less_than_1", label: "Less than 1" },
      { value: "1_or_more", label: "1 or more" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_7",
    question_text: "How many sweet or carbonated beverages do you drink per day?",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "less_than_1", label: "Less than 1" },
      { value: "1_or_more", label: "1 or more" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_8",
    question_text: "How much wine do you drink per week?",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "7_or_more", label: "7+ glasses" },
      { value: "3_to_6", label: "3-6 glasses" },
      { value: "less_than_3", label: "Less than 3 glasses" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_9",
    question_text: "How many servings of legumes do you consume per week?",
    help_text: "1 serving = 150g",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "3_or_more", label: "3+ servings" },
      { value: "1_to_2", label: "1-2 servings" },
      { value: "less_than_1", label: "Less than 1" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_10",
    question_text: "How many servings of fish or shellfish do you consume per week?",
    help_text: "1 serving = 100-150g fish, 4-5 pieces shellfish",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "3_or_more", label: "3+ servings" },
      { value: "1_to_2", label: "1-2 servings" },
      { value: "less_than_1", label: "Less than 1" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_11",
    question_text: "How many times per week do you consume commercial sweets or pastries (not homemade)?",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "less_than_3", label: "Less than 3 times" },
      { value: "3_or_more", label: "3 or more times" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_12",
    question_text: "How many servings of nuts (including peanuts) do you consume per week?",
    help_text: "1 serving = 30g",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "3_or_more", label: "3+ servings" },
      { value: "1_to_2", label: "1-2 servings" },
      { value: "less_than_1", label: "Less than 1" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_13",
    question_text: "Do you preferentially consume chicken, turkey, or rabbit meat instead of veal, pork, hamburger, or sausage?",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [{ value: "Yes", label: "Yes" }, { value: "No", label: "No" }] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },
  {
    question_id: "MEDAS_14",
    question_text: "How many times per week do you consume vegetables, pasta, rice, or other dishes with a sauce of tomato, garlic, onion, or leeks sautéed in olive oil (sofrito)?",
    pillar: "Nutritional",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "2_or_more", label: "2+ times" },
      { value: "less_than_2", label: "Less than 2 times" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 10,
  },

  // ============================================
  // MEQ - Morningness-Eveningness Questionnaire (19 questions)
  // Day 14: "Diet & Chronotype"
  // ============================================
  {
    question_id: "MEQ_1",
    question_text: "What time would you get up if you were entirely free to plan your day?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "5am_6_30am", label: "5:00-6:30 AM" },
      { value: "6_30am_7_45am", label: "6:30-7:45 AM" },
      { value: "7_45am_9_45am", label: "7:45-9:45 AM" },
      { value: "9_45am_11am", label: "9:45-11:00 AM" },
      { value: "11am_12pm", label: "11:00 AM-Noon" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_2",
    question_text: "What time would you go to bed if you were entirely free to plan your evening?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "8pm_9pm", label: "8:00-9:00 PM" },
      { value: "9pm_10_15pm", label: "9:00-10:15 PM" },
      { value: "10_15pm_12_30am", label: "10:15 PM-12:30 AM" },
      { value: "12_30am_1_45am", label: "12:30-1:45 AM" },
      { value: "1_45am_3am", label: "1:45-3:00 AM" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_3",
    question_text: "How dependent are you on being woken up by an alarm clock?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 4,
      labels: ["Not at all", "Slightly", "Somewhat", "Very"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_4",
    question_text: "How easy do you find it to get up in the morning?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 4,
      labels: ["Not at all easy", "Slightly easy", "Fairly easy", "Very easy"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_5",
    question_text: "How alert do you feel during the first half hour after waking in the morning?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 4,
      labels: ["Not at all alert", "Slightly alert", "Fairly alert", "Very alert"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_6",
    question_text: "How hungry do you feel during the first half hour after waking?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 4,
      labels: ["Not at all hungry", "Slightly hungry", "Fairly hungry", "Very hungry"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_7",
    question_text: "How tired do you feel during the first half hour after waking?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 4,
      labels: ["Very tired", "Fairly tired", "Fairly refreshed", "Very refreshed"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_8",
    question_text: "When you have no commitments the next day, what time do you go to bed compared to your usual bedtime?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "same", label: "Same time" },
      { value: "1hr_later", label: "< 1 hour later" },
      { value: "1_2hr_later", label: "1-2 hours later" },
      { value: "2hr_later", label: "> 2 hours later" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_9",
    question_text: "You have decided to do physical exercise. A friend suggests a one-hour session twice a week. The best time for your friend is 7-8 AM. How do you think you would perform?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 4,
      labels: ["Would be in good form", "Reasonable form", "Would find it difficult", "Very difficult"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_10",
    question_text: "At what time in the evening do you feel tired and in need of sleep?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "8pm_9pm", label: "8:00-9:00 PM" },
      { value: "9pm_10_15pm", label: "9:00-10:15 PM" },
      { value: "10_15pm_12_30am", label: "10:15 PM-12:30 AM" },
      { value: "12_30am_1_45am", label: "12:30-1:45 AM" },
      { value: "1_45am_3am", label: "1:45-3:00 AM" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_11",
    question_text: "You wish to be at peak performance for a test which is known to be mentally exhausting and lasts two hours. When would you schedule this test?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "8am_10am", label: "8-10 AM" },
      { value: "11am_1pm", label: "11 AM-1 PM" },
      { value: "3pm_5pm", label: "3-5 PM" },
      { value: "7pm_9pm", label: "7-9 PM" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_12",
    question_text: "If you went to bed at 11 PM, how tired would you be?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 4,
      labels: ["Not at all tired", "A little tired", "Fairly tired", "Very tired"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_13",
    question_text: "For some reason you have gone to bed several hours later than usual, but there is no need to get up at any particular time the next morning. Which of the following are you most likely to do?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "wake_usual", label: "Wake at usual time, no desire to sleep" },
      { value: "wake_doze", label: "Wake at usual time, doze" },
      { value: "wake_usual_sleep_again", label: "Wake at usual time, sleep again" },
      { value: "wake_later", label: "Wake up later than usual" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_14",
    question_text: "One night you have to stay awake between 4-6 AM. You have no commitments the next day. Which suits you best?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "not_sleep_until_6am", label: "Not go to bed until 6 AM" },
      { value: "nap_before", label: "Nap before, stay up after" },
      { value: "sleep_before_nap_after", label: "Sleep before, nap after" },
      { value: "sleep_before_only", label: "Sleep before, no nap after" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_15",
    question_text: "You have two hours of hard physical work. When would you schedule this?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "8am_10am", label: "8-10 AM" },
      { value: "11am_1pm", label: "11 AM-1 PM" },
      { value: "3pm_5pm", label: "3-5 PM" },
      { value: "7pm_9pm", label: "7-9 PM" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_16",
    question_text: "You have decided to do hard physical exercise. A friend suggests 10-11 PM. How do you think you would perform?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "slider_scale",
    format_config: {
      scaleMin: 1,
      scaleMax: 4,
      labels: ["Would be in good form", "Reasonable form", "Would find it difficult", "Very difficult"],
      step: 1,
    },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_17",
    question_text: "Suppose you can choose your own work hours. Assume that you work a FIVE-hour day. Which FIVE CONSECUTIVE hours would you select?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "4am_8am", label: "4-8 AM" },
      { value: "8am_1pm", label: "8 AM-1 PM" },
      { value: "9am_2pm", label: "9 AM-2 PM" },
      { value: "2pm_7pm", label: "2-7 PM" },
      { value: "5pm_12am", label: "5 PM-Midnight" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_18",
    question_text: "At what time of day do you think that you reach your 'feeling best' peak?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "5am_8am", label: "5-8 AM" },
      { value: "8am_10am", label: "8-10 AM" },
      { value: "10am_5pm", label: "10 AM-5 PM" },
      { value: "5pm_9pm", label: "5-9 PM" },
      { value: "9pm_5am", label: "9 PM-5 AM" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
  },
  {
    question_id: "MEQ_19",
    question_text: "One hears about 'morning' and 'evening' types of people. Which ONE of these types do you consider yourself to be?",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    answer_format: "single_select_chips",
    format_config: { options: [
      { value: "definitely_morning", label: "Definitely morning type" },
      { value: "more_morning", label: "More morning than evening" },
      { value: "more_evening", label: "More evening than morning" },
      { value: "definitely_evening", label: "Definitely evening type" },
    ] },
    validation_rules: { required: true },
    estimated_time_seconds: 15,
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
  // Day 6: SWDSQ - Shift Work Disorder Screening Questionnaire
  {
    module_id: "expansion_swdsq",
    name: "SWDSQ",
    description: "Shift Work Disorder Screening Questionnaire - 4-item screening",
    pillar: "Sleep Disorder Screening",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 2,
    question_ids: ["SWDSQ_1", "SWDSQ_2", "SWDSQ_3", "SWDSQ_4"],
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

  // ============================================
  // NEW EXPANSION MODULES - Days 7-14
  // ============================================

  // Day 7: PROMIS Cognitive Function
  {
    module_id: "expansion_promis_cognitive",
    name: "PROMIS Cognitive",
    description: "PROMIS Cognitive Function - 6-item cognitive assessment",
    pillar: "Cognitive",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 3,
    question_ids: ["PROMIS_COG_1", "PROMIS_COG_2", "PROMIS_COG_3", "PROMIS_COG_4", "PROMIS_COG_5", "PROMIS_COG_6"],
  },

  // Day 8: Sleep Hygiene Index (split into 2 parts for fixedSchedule.ts)
  {
    module_id: "expansion_sleep_hygiene_part1",
    name: "Sleep Hygiene (Part 1)",
    description: "Sleep Hygiene Index - Part 1 (questions 1-5)",
    pillar: "Sleep Quality",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 3,
    question_ids: ["SH_1", "SH_2", "SH_3", "SH_4", "SH_5"],
  },
  {
    module_id: "expansion_sleep_hygiene_part2",
    name: "Sleep Hygiene (Part 2)",
    description: "Sleep Hygiene Index - Part 2 (questions 6-10)",
    pillar: "Sleep Quality",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 3,
    question_ids: ["SH_6", "SH_7", "SH_8", "SH_9", "SH_10"],
  },

  // Day 9: Berlin Questionnaire - REMOVED
  // Berlin removed - STOP-BANG alone has 93% sensitivity for OSA detection
  // Keeping the questions in case needed for future validation studies

  // Day 10: FSS - Fatigue Severity Scale
  {
    module_id: "expansion_fss",
    name: "FSS",
    description: "Fatigue Severity Scale - 9-item fatigue assessment",
    pillar: "Sleep Quality",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 4,
    question_ids: ["FSS_1", "FSS_2", "FSS_3", "FSS_4", "FSS_5", "FSS_6", "FSS_7", "FSS_8", "FSS_9"],
  },

  // Day 11: DBAS-6 (2024) - Machine learning derived 6-item version
  // R²=0.90 predicting DBAS-16 total score
  // Items: 4, 5, 7, 11, 13, 15 from original DBAS-16
  {
    module_id: "expansion_dbas6",
    name: "DBAS-6",
    description: "Dysfunctional Beliefs and Attitudes about Sleep - 6-item version (2024)",
    pillar: "Mental Health",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 3,
    question_ids: ["DBAS_4", "DBAS_5", "DBAS_7", "DBAS_11", "DBAS_13", "DBAS_15"],
  },

  // Days 11-12: BPI - Brief Pain Inventory (split into 2 parts)
  {
    module_id: "expansion_bpi_part1",
    name: "BPI (Part 1)",
    description: "Brief Pain Inventory - Part 1 (pain severity + 2 interference)",
    pillar: "Physical",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 4,
    question_ids: ["BPI_1", "BPI_2", "BPI_3", "BPI_4", "BPI_5", "BPI_6"],
  },
  {
    module_id: "expansion_bpi_part2",
    name: "BPI (Part 2)",
    description: "Brief Pain Inventory - Part 2 (remaining interference questions)",
    pillar: "Physical",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 4,
    question_ids: ["BPI_7", "BPI_8", "BPI_9", "BPI_10", "BPI_11"],
  },

  // Day 13: PSAS - Pre-Sleep Arousal Scale (2 subscales)
  {
    module_id: "expansion_psas_cognitive",
    name: "PSAS Cognitive",
    description: "Pre-Sleep Arousal Scale - Cognitive subscale (8 items)",
    pillar: "Mental Health",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 4,
    question_ids: ["PSAS_C1", "PSAS_C2", "PSAS_C3", "PSAS_C4", "PSAS_C5", "PSAS_C6", "PSAS_C7", "PSAS_C8"],
  },
  {
    module_id: "expansion_psas_somatic",
    name: "PSAS Somatic",
    description: "Pre-Sleep Arousal Scale - Somatic subscale (8 items)",
    pillar: "Physical",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 4,
    question_ids: ["PSAS_S1", "PSAS_S2", "PSAS_S3", "PSAS_S4", "PSAS_S5", "PSAS_S6", "PSAS_S7", "PSAS_S8"],
  },

  // Day 13: FOSQ-10 (split into 2 parts)
  {
    module_id: "expansion_fosq_part1",
    name: "FOSQ-10 (Part 1)",
    description: "Functional Outcomes of Sleep Questionnaire - Part 1 (questions 1-5)",
    pillar: "Cognitive",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 3,
    question_ids: ["FOSQ_1", "FOSQ_2", "FOSQ_3", "FOSQ_4", "FOSQ_5"],
  },
  {
    module_id: "expansion_fosq_part2",
    name: "FOSQ-10 (Part 2)",
    description: "Functional Outcomes of Sleep Questionnaire - Part 2 (questions 6-10)",
    pillar: "Cognitive",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 3,
    question_ids: ["FOSQ_6", "FOSQ_7", "FOSQ_8", "FOSQ_9", "FOSQ_10"],
  },

  // Day 14: MEDAS - Mediterranean Diet Adherence
  {
    module_id: "expansion_medas",
    name: "MEDAS",
    description: "Mediterranean Diet Adherence Screener - 14-item diet assessment",
    pillar: "Nutritional",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 6,
    question_ids: ["MEDAS_1", "MEDAS_2", "MEDAS_3", "MEDAS_4", "MEDAS_5", "MEDAS_6", "MEDAS_7", "MEDAS_8", "MEDAS_9", "MEDAS_10", "MEDAS_11", "MEDAS_12", "MEDAS_13", "MEDAS_14"],
  },

  // Day 14: MEQ - Morningness-Eveningness Questionnaire (split into 2 parts)
  {
    module_id: "expansion_meq_part1",
    name: "MEQ (Part 1)",
    description: "Morningness-Eveningness Questionnaire - Part 1 (questions 1-10)",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 6,
    question_ids: ["MEQ_1", "MEQ_2", "MEQ_3", "MEQ_4", "MEQ_5", "MEQ_6", "MEQ_7", "MEQ_8", "MEQ_9", "MEQ_10"],
  },
  {
    module_id: "expansion_meq_part2",
    name: "MEQ (Part 2)",
    description: "Morningness-Eveningness Questionnaire - Part 2 (questions 11-19)",
    pillar: "Sleep Timing",
    tier: "EXPANSION",
    module_type: "EXPANSION",
    estimated_minutes: 6,
    question_ids: ["MEQ_11", "MEQ_12", "MEQ_13", "MEQ_14", "MEQ_15", "MEQ_16", "MEQ_17", "MEQ_18", "MEQ_19"],
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
          help_text: (q as { help_text?: string }).help_text,
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
 * Run with: npx convex run seedClinicalData:fixQuestion33D
 */
export const fixQuestion33D = mutation({
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

// ============================================
// Cleanup Redundant Modules
// ============================================

/**
 * REDUNDANT MODULES TO REMOVE:
 * These modules are not in fixedSchedule.ts and should be cleaned up.
 *
 * - expansion_berlin: Replaced by STOP-BANG (93% sensitivity)
 * - expansion_dbas_part1/part2: Replaced by DBAS-6 (2024)
 * - expansion_sleep_timing: Not in schedule
 * - expansion_sleep_quality_1/2: Core versions used instead
 * - expansion_cognitive_1/2: Not in schedule
 * - expansion_mental_health_1/2/3: Not in schedule
 * - core_sleep_quantity: Not in THEME_TO_MODULE_IDS
 * - core_sleep_regularity: Not in THEME_TO_MODULE_IDS
 * - core_sleep_timing: Not in THEME_TO_MODULE_IDS
 */
const REDUNDANT_MODULES = [
  // Removed questionnaires
  "expansion_berlin",           // 10 questions - replaced by STOP-BANG
  "expansion_dbas_part1",       // 8 questions - replaced by DBAS-6
  "expansion_dbas_part2",       // 8 questions - replaced by DBAS-6

  // Expansion modules not in fixedSchedule
  "expansion_sleep_timing",     // 19 questions - not in schedule
  "expansion_sleep_quality_1",  // 17 questions - core version used
  "expansion_sleep_quality_2",  // 17 questions - core version used
  "expansion_cognitive_1",      // 17 questions - not in schedule
  "expansion_cognitive_2",      // 16 questions - not in schedule
  "expansion_mental_health_1",  // 16 questions - not in schedule
  "expansion_mental_health_2",  // 16 questions - not in schedule
  "expansion_mental_health_3",  // 16 questions - not in schedule

  // Legacy core modules not in THEME_TO_MODULE_IDS
  "core_sleep_quantity",        // 3 questions - not used
  "core_sleep_regularity",      // 4 questions - not used
  "core_sleep_timing",          // 8 questions - not used

  // Legacy empty modules
  "core_sleep_quality",         // Empty - core_sleep_quality_1/2 used instead
  "expansion_sleep_quality",    // Empty
  "expansion_mental_health",    // Empty
  "expansion_cognitive",        // Empty
  "expansion_physical",         // Empty
];

/**
 * Preview what will be cleaned up (dry run)
 */
export const previewCleanup = mutation({
  args: {},
  handler: async (ctx) => {
    const modules = await ctx.db.query("assessment_modules").collect();
    const moduleQuestions = await ctx.db.query("module_questions").collect();

    const toRemove: {
      modules: { id: string; name: string; questionCount: number }[];
      questionMappings: number;
      totalQuestionsFreed: number;
    } = {
      modules: [],
      questionMappings: 0,
      totalQuestionsFreed: 0,
    };

    for (const moduleId of REDUNDANT_MODULES) {
      const module = modules.find(m => m.module_id === moduleId);
      const mappings = moduleQuestions.filter(mq => mq.module_id === moduleId);

      if (module || mappings.length > 0) {
        toRemove.modules.push({
          id: moduleId,
          name: module?.name || "(module record missing)",
          questionCount: mappings.length,
        });
        toRemove.questionMappings += mappings.length;
        toRemove.totalQuestionsFreed += mappings.length;
      }
    }

    return {
      preview: true,
      message: "DRY RUN - No changes made. Run cleanupRedundantModules to execute.",
      ...toRemove,
    };
  },
});

/**
 * Remove redundant modules and their question mappings
 * This DOES NOT delete the actual questions - just the module records and mappings
 */
export const cleanupRedundantModules = mutation({
  args: {
    confirm: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    if (!args.confirm) {
      return {
        error: "Safety check: Pass { confirm: true } to execute cleanup",
        hint: "Run previewCleanup first to see what will be removed",
      };
    }

    const results = {
      modulesDeleted: 0,
      moduleMappingsDeleted: 0,
      dayMappingsDeleted: 0,
      errors: [] as string[],
    };

    for (const moduleId of REDUNDANT_MODULES) {
      try {
        // Delete module_questions mappings
        const moduleQuestions = await ctx.db
          .query("module_questions")
          .filter(q => q.eq(q.field("module_id"), moduleId))
          .collect();

        for (const mq of moduleQuestions) {
          await ctx.db.delete(mq._id);
          results.moduleMappingsDeleted++;
        }

        // Delete day_modules mappings
        const dayModules = await ctx.db
          .query("day_modules")
          .filter(q => q.eq(q.field("module_id"), moduleId))
          .collect();

        for (const dm of dayModules) {
          await ctx.db.delete(dm._id);
          results.dayMappingsDeleted++;
        }

        // Delete the module itself
        const modules = await ctx.db
          .query("assessment_modules")
          .filter(q => q.eq(q.field("module_id"), moduleId))
          .collect();

        for (const m of modules) {
          await ctx.db.delete(m._id);
          results.modulesDeleted++;
        }
      } catch (error) {
        results.errors.push(`${moduleId}: ${error}`);
      }
    }

    return {
      success: true,
      message: `Cleaned up ${results.modulesDeleted} modules and ${results.moduleMappingsDeleted} question mappings`,
      ...results,
    };
  },
});

/**
 * Also remove Berlin questions from assessment_questions table
 * (These are truly unused now that Berlin questionnaire is removed)
 */
export const cleanupBerlinQuestions = mutation({
  args: {
    confirm: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    if (!args.confirm) {
      // Preview mode
      const berlinQuestions = await ctx.db
        .query("assessment_questions")
        .filter(q => q.gte(q.field("question_id"), "BERLIN_"))
        .filter(q => q.lt(q.field("question_id"), "BERLIN`"))
        .collect();

      return {
        preview: true,
        message: "DRY RUN - Pass { confirm: true } to delete",
        questionsToDelete: berlinQuestions.map(q => q.question_id),
        count: berlinQuestions.length,
      };
    }

    // Delete Berlin questions
    const berlinQuestions = await ctx.db
      .query("assessment_questions")
      .filter(q => q.gte(q.field("question_id"), "BERLIN_"))
      .filter(q => q.lt(q.field("question_id"), "BERLIN`"))
      .collect();

    let deleted = 0;
    for (const q of berlinQuestions) {
      await ctx.db.delete(q._id);
      deleted++;
    }

    return {
      success: true,
      deleted,
      message: `Deleted ${deleted} Berlin questionnaire questions`,
    };
  },
});

// Note: To seed all data, run each seeder individually:
// npx convex run seedClinicalData:seedGateways
// npx convex run seedClinicalData:seedClinicalQuestions
// npx convex run seedClinicalData:seedExpansionModules
// npx convex run seedClinicalData:fixSliderScaleQuestions
// npx convex run seedClinicalData:fixQuestion33D
//
// To cleanup redundant modules:
// npx convex run seedClinicalData:previewCleanup
// npx convex run seedClinicalData:cleanupRedundantModules '{"confirm": true}'
// npx convex run seedClinicalData:cleanupBerlinQuestions '{"confirm": true}'
// npx convex run seedClinicalData:deleteOrphanGateway '{"gatewayId": "prostate"}'

/**
 * Delete an orphan gateway that targets a non-existent module
 */
export const deleteOrphanGateway = mutation({
  args: {
    gatewayId: v.string(),
  },
  handler: async (ctx, args) => {
    const gateway = await ctx.db
      .query("module_gateways")
      .filter(q => q.eq(q.field("gateway_id"), args.gatewayId))
      .first();

    if (!gateway) {
      return {
        success: false,
        message: `Gateway '${args.gatewayId}' not found`,
      };
    }

    await ctx.db.delete(gateway._id);

    return {
      success: true,
      message: `Deleted gateway '${args.gatewayId}'`,
      deletedId: gateway._id,
    };
  },
});
