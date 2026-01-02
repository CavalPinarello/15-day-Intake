import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";
import { validatePhysicianRole, validateIOSSession } from "./auth";
import { shouldShowExpansion } from "./fixedSchedule";

// ============================================
// Question Definitions - Single Source of Truth
// ============================================

// Stanford Sleep Log questions (SL_ prefix - used by Watch quick log)
// Note: Watch app is PAUSED - these remain for backward compatibility with existing data
const SLEEP_LOG_QUESTIONS: Record<string, { text: string; type: string }> = {
  // Watch/iPhone quick sleep log (SL_ prefix)
  "SL_BEDTIME": { text: "What time did you go to bed last night?", type: "time" },
  // Note: SL_ASLEEP_TIME deprecated in favor of deriving from lights_out + latency
  // Kept for backward compatibility with Watch app data
  "SL_ASLEEP_TIME": { text: "What time did you fall asleep?", type: "time" },
  "SL_AWAKENINGS": { text: "How many times did you wake up during the night?", type: "number" },
  "SL_WAKE_TIME": { text: "What time did you wake up this morning?", type: "time" },
  "SL_QUALITY": { text: "How would you rate your sleep quality?", type: "scale" },
  "SL_OUT_OF_BED": { text: "What time did you get out of bed?", type: "time" },
  "SL_REFRESHED": { text: "How refreshed do you feel this morning?", type: "scale" },
  "SL_NAPS": { text: "Did you take any naps yesterday?", type: "yes_no" },
  "SL_NAP_DURATION": { text: "How long were your naps in total?", type: "duration" },
  "SL_CAFFEINE": { text: "Did you have caffeine after 2pm?", type: "yes_no" },
  "SL_ALCOHOL": { text: "Did you have alcohol last night?", type: "yes_no" },
  "SL_EXERCISE": { text: "Did you exercise yesterday?", type: "yes_no" },
  "SL_NOTES": { text: "Any notes about your sleep?", type: "text" },
};

// Stanford Sleep Diary questions (SD_ prefix - full diary from SharedQuestionBank)
// NOTE: SD_DATE was removed - the system knows the date from the day being logged
const SLEEP_DIARY_QUESTIONS: Record<string, { text: string; type: string }> = {
  "SD_DAY_TYPE": { text: "What type of day is today?", type: "single_select" },
  "SD_MEDICATION_TAKEN": { text: "Did you take any sleep medication last night?", type: "yes_no" },
  "SD_MEDICATION_TIME": { text: "If yes, what time did you take it?", type: "time" },
  "SD_MEDS_LIST": { text: "What type of sleep medication did you take?", type: "medication_select" },
  "SD_MEDS_OTHER": { text: "Other medication (specify)", type: "text" },
  "SD_GOT_INTO_BED": { text: "What time did you get into bed last night?", type: "time" },
  "SD_LIGHTS_OUT": { text: "What time did you turn off the lights to sleep?", type: "time" },
  // Note: SD_SLEEP_ONSET removed - sleep onset time derived from SD_LIGHTS_OUT + SD_SLEEP_LATENCY
  "SD_SLEEP_LATENCY": { text: "How long did it take you to fall asleep? (minutes)", type: "minutes" },
  "SD_AWAKENINGS_COUNT": { text: "How many times did you wake up during the night?", type: "number" },
  "SD_AWAKENINGS_DURATION": { text: "Total time awake during the night (minutes)", type: "minutes" },
  "SD_FINAL_WAKE": { text: "What time did you wake up for the final time?", type: "time" },
  "SD_OUT_OF_BED": { text: "What time did you get out of bed this morning?", type: "time" },
  "SD_SLEEP_QUALITY": { text: "How would you rate your sleep quality?", type: "scale" },
  "SD_NAPS_TAKEN": { text: "Did you take any naps yesterday?", type: "yes_no" },
  "SD_NAPS_COUNT": { text: "How many naps did you take?", type: "number" },
  "SD_NAP_DETAILS": { text: "For each nap, record the start time and duration.", type: "nap_details" },
};

// Consensus Sleep Diary questions (CSD_ prefix - iOS app's primary sleep log)
const CONSENSUS_SLEEP_DIARY_QUESTIONS: Record<string, { text: string; type: string }> = {
  "CSD_DAY_TYPE": { text: "What type of day was yesterday?", type: "single_select" },
  "CSD_INTO_BED": { text: "What time did you get into bed?", type: "time" },
  "CSD_TRY_SLEEP": { text: "What time did you try to go to sleep?", type: "time" },
  "CSD_LATENCY": { text: "How long did it take you to fall asleep? (minutes)", type: "minutes" },
  "CSD_AWAKENINGS": { text: "How many times did you wake up during the night?", type: "number" },
  "CSD_WASO": { text: "Total time awake during the night (minutes)", type: "minutes" },
  "CSD_FINAL_WAKE": { text: "What time was your final awakening?", type: "time" },
  "CSD_OUT_BED": { text: "What time did you get out of bed?", type: "time" },
  "CSD_QUALITY": { text: "How would you rate your sleep quality?", type: "scale" },
  "CSD_REFRESHED": { text: "How refreshed did you feel upon waking?", type: "scale" },
  "CSD_NAPS": { text: "Did you take any naps yesterday?", type: "yes_no" },
  "CSD_NAP_COUNT": { text: "How many naps did you take?", type: "number" },
  "CSD_NAP_DURATION": { text: "Total nap duration (minutes)", type: "minutes" },  // Legacy
  "CSD_NAP_DETAILS": { text: "Nap details (start time and duration)", type: "nap_details" },
  "CSD_CAFFEINE": { text: "How many caffeinated drinks did you have?", type: "number" },
  "CSD_CAFFEINE_LAST": { text: "When was your last caffeine?", type: "time" },
  "CSD_ALCOHOL": { text: "Did you consume alcohol yesterday?", type: "yes_no" },
  "CSD_ALCOHOL_DRINKS": { text: "How many alcoholic drinks?", type: "number" },
  "CSD_ALCOHOL_LAST": { text: "When was your last alcoholic drink?", type: "time" },
  "CSD_MEDS": { text: "Did you take any sleep aids or medications?", type: "yes_no" },
  "CSD_MEDS_NAME": { text: "What sleep aids/medications did you take?", type: "text" },  // Legacy
  "CSD_MEDS_LIST": { text: "Sleep medications taken", type: "medication_select" },
  "CSD_MEDS_OTHER": { text: "Other medication (specify)", type: "text" },
  "CSD_COMMENTS": { text: "Any additional comments about your sleep?", type: "text" },
};

// Combined lookup function
function getQuestionDefinition(questionId: string): { text: string; type: string; pillar: string } | null {
  if (questionId.startsWith("SL_")) {
    const q = SLEEP_LOG_QUESTIONS[questionId];
    return q ? { ...q, pillar: "Sleep Log" } : null;
  }
  if (questionId.startsWith("SD_")) {
    const q = SLEEP_DIARY_QUESTIONS[questionId];
    return q ? { ...q, pillar: "Sleep Diary" } : null;
  }
  if (questionId.startsWith("CSD_")) {
    const q = CONSENSUS_SLEEP_DIARY_QUESTIONS[questionId];
    return q ? { ...q, pillar: "Consensus Sleep Diary" } : null;
  }
  return null;
}

// ============================================
// Questionnaire Scoring Functions
// ============================================

interface QuestionnaireScore {
  name: string;
  abbreviation: string;
  score: number | null;
  maxScore: number;
  interpretation: string;
  severity: "normal" | "mild" | "moderate" | "severe" | "unknown";
  questionsAnswered: number;
  questionsRequired: number;
}

// ISI (Insomnia Severity Index) - 7 questions, each 0-4
function calculateISI(responses: Map<string, number>): QuestionnaireScore {
  const isiQuestions = ["ISI_1", "ISI_2", "ISI_3", "ISI_4", "ISI_5", "ISI_6", "ISI_7"];
  let total = 0;
  let answered = 0;

  for (const qId of isiQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 5) { // Allow partial scoring
    const score = Math.round(total * (7 / answered)); // Prorate
    if (score <= 7) { interpretation = "No clinically significant insomnia"; severity = "normal"; }
    else if (score <= 14) { interpretation = "Subthreshold insomnia"; severity = "mild"; }
    else if (score <= 21) { interpretation = "Clinical insomnia (moderate)"; severity = "moderate"; }
    else { interpretation = "Clinical insomnia (severe)"; severity = "severe"; }

    return { name: "Insomnia Severity Index", abbreviation: "ISI", score, maxScore: 28, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
  }

  return { name: "Insomnia Severity Index", abbreviation: "ISI", score: null, maxScore: 28, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
}

// PHQ-9 (Depression) - 9 questions, each 0-3
function calculatePHQ9(responses: Map<string, number>): QuestionnaireScore {
  const phqQuestions = ["PHQ9_1", "PHQ9_2", "PHQ9_3", "PHQ9_4", "PHQ9_5", "PHQ9_6", "PHQ9_7", "PHQ9_8", "PHQ9_9"];
  let total = 0;
  let answered = 0;

  for (const qId of phqQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  // Also check gateway questions (15 = depression gateway from Day 3)
  const gatewayVal = responses.get("15");
  if (gatewayVal !== undefined && answered === 0) {
    // Map gateway to PHQ-2 equivalent
    if (gatewayVal >= 2) { // "More than half the days" or "Nearly every day"
      return { name: "Patient Health Questionnaire", abbreviation: "PHQ-9", score: null, maxScore: 27,
        interpretation: "Gateway triggered - full PHQ-9 recommended", severity: "mild", questionsAnswered: 1, questionsRequired: 9 };
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 7) {
    const score = Math.round(total * (9 / answered));
    if (score <= 4) { interpretation = "Minimal depression"; severity = "normal"; }
    else if (score <= 9) { interpretation = "Mild depression"; severity = "mild"; }
    else if (score <= 14) { interpretation = "Moderate depression"; severity = "moderate"; }
    else if (score <= 19) { interpretation = "Moderately severe depression"; severity = "moderate"; }
    else { interpretation = "Severe depression"; severity = "severe"; }

    return { name: "Patient Health Questionnaire", abbreviation: "PHQ-9", score, maxScore: 27, interpretation, severity, questionsAnswered: answered, questionsRequired: 9 };
  }

  return { name: "Patient Health Questionnaire", abbreviation: "PHQ-9", score: null, maxScore: 27, interpretation, severity, questionsAnswered: answered, questionsRequired: 9 };
}

// GAD-7 (Anxiety) - 7 questions, each 0-3
function calculateGAD7(responses: Map<string, number>): QuestionnaireScore {
  const gadQuestions = ["GAD7_1", "GAD7_2", "GAD7_3", "GAD7_4", "GAD7_5", "GAD7_6", "GAD7_7"];
  let total = 0;
  let answered = 0;

  for (const qId of gadQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  // Check gateway (16 = anxiety gateway from Day 3)
  const gatewayVal = responses.get("16");
  if (gatewayVal !== undefined && answered === 0) {
    if (gatewayVal >= 2) {
      return { name: "Generalized Anxiety Disorder", abbreviation: "GAD-7", score: null, maxScore: 21,
        interpretation: "Gateway triggered - full GAD-7 recommended", severity: "mild", questionsAnswered: 1, questionsRequired: 7 };
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 5) {
    const score = Math.round(total * (7 / answered));
    if (score <= 4) { interpretation = "Minimal anxiety"; severity = "normal"; }
    else if (score <= 9) { interpretation = "Mild anxiety"; severity = "mild"; }
    else if (score <= 14) { interpretation = "Moderate anxiety"; severity = "moderate"; }
    else { interpretation = "Severe anxiety"; severity = "severe"; }

    return { name: "Generalized Anxiety Disorder", abbreviation: "GAD-7", score, maxScore: 21, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
  }

  return { name: "Generalized Anxiety Disorder", abbreviation: "GAD-7", score: null, maxScore: 21, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
}

// ESS (Epworth Sleepiness Scale) - 8 questions, each 0-3
function calculateESS(responses: Map<string, number>): QuestionnaireScore {
  const essQuestions = ["ESS_1", "ESS_2", "ESS_3", "ESS_4", "ESS_5", "ESS_6", "ESS_7", "ESS_8"];
  let total = 0;
  let answered = 0;

  for (const qId of essQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  // Check daytime sleepiness gateway (17)
  const gatewayVal = responses.get("17");
  if (gatewayVal !== undefined && answered === 0) {
    if (gatewayVal >= 3) { // "Often" or "Always"
      return { name: "Epworth Sleepiness Scale", abbreviation: "ESS", score: null, maxScore: 24,
        interpretation: "Gateway triggered - full ESS recommended", severity: "mild", questionsAnswered: 1, questionsRequired: 8 };
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 6) {
    const score = Math.round(total * (8 / answered));
    if (score <= 10) { interpretation = "Normal daytime sleepiness"; severity = "normal"; }
    else if (score <= 14) { interpretation = "Mild excessive daytime sleepiness"; severity = "mild"; }
    else if (score <= 18) { interpretation = "Moderate excessive daytime sleepiness"; severity = "moderate"; }
    else { interpretation = "Severe excessive daytime sleepiness"; severity = "severe"; }

    return { name: "Epworth Sleepiness Scale", abbreviation: "ESS", score, maxScore: 24, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
  }

  return { name: "Epworth Sleepiness Scale", abbreviation: "ESS", score: null, maxScore: 24, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
}

// STOP-BANG (Sleep Apnea Risk) - 8 yes/no questions
// iOS uses SB_1 through SB_8 with yesNo type (1=Yes, 0=No)
function calculateSTOPBANG(responses: Map<string, number>, demographics: { age?: number; sex?: string; bmi?: number }): QuestionnaireScore {
  let score = 0;
  let answered = 0;

  // S - Snore loudly (SB_1)
  const snore = responses.get("SB_1");
  if (snore !== undefined) { if (snore === 1) score++; answered++; }

  // T - Tired/fatigued during daytime (SB_2)
  const tired = responses.get("SB_2");
  if (tired !== undefined) { if (tired === 1) score++; answered++; }

  // O - Observed stop breathing (SB_3)
  const observed = responses.get("SB_3");
  if (observed !== undefined) { if (observed === 1) score++; answered++; }

  // P - Blood Pressure high (SB_4)
  const pressure = responses.get("SB_4");
  if (pressure !== undefined) { if (pressure === 1) score++; answered++; }

  // B - BMI > 35 (SB_5) - asked directly as yes/no in iOS
  const bmi = responses.get("SB_5");
  if (bmi !== undefined) { if (bmi === 1) score++; answered++; }

  // A - Age > 50 (SB_6) - asked directly as yes/no in iOS
  const age = responses.get("SB_6");
  if (age !== undefined) { if (age === 1) score++; answered++; }

  // N - Neck circumference > 40cm (SB_7)
  const neck = responses.get("SB_7");
  if (neck !== undefined) { if (neck === 1) score++; answered++; }

  // G - Gender = Male (SB_8)
  const gender = responses.get("SB_8");
  if (gender !== undefined) { if (gender === 1) score++; answered++; }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 4) {
    if (score <= 2) { interpretation = "Low risk of OSA"; severity = "normal"; }
    else if (score <= 4) { interpretation = "Intermediate risk of OSA"; severity = "mild"; }
    else { interpretation = "High risk of OSA"; severity = "moderate"; }

    return { name: "STOP-BANG Sleep Apnea Screening", abbreviation: "STOP-BANG", score, maxScore: 8, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
  }

  return { name: "STOP-BANG Sleep Apnea Screening", abbreviation: "STOP-BANG", score: null, maxScore: 8, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
}

// PSQI (Pittsburgh Sleep Quality Index) - 7 component scores (0-3 each)
// Components: Sleep Quality, Sleep Latency, Sleep Duration, Sleep Efficiency, Sleep Disturbances, Sleep Medication, Daytime Dysfunction
function calculatePSQI(responses: Map<string, number>): QuestionnaireScore {
  let totalScore = 0;
  let componentsCalculated = 0;

  // Component 1: Subjective Sleep Quality (PSQI_6)
  const sleepQuality = responses.get("PSQI_6");
  if (sleepQuality !== undefined) {
    totalScore += Math.min(3, sleepQuality);
    componentsCalculated++;
  }

  // Component 2: Sleep Latency (PSQI_2 + PSQI_5a)
  const latency = responses.get("PSQI_2");
  const latencyScore5a = responses.get("PSQI_5a");
  if (latency !== undefined || latencyScore5a !== undefined) {
    let comp2 = 0;
    if (latency !== undefined) {
      if (latency <= 15) comp2 += 0;
      else if (latency <= 30) comp2 += 1;
      else if (latency <= 60) comp2 += 2;
      else comp2 += 3;
    }
    if (latencyScore5a !== undefined) comp2 += latencyScore5a;
    // Convert sum to 0-3 scale
    if (comp2 === 0) totalScore += 0;
    else if (comp2 <= 2) totalScore += 1;
    else if (comp2 <= 4) totalScore += 2;
    else totalScore += 3;
    componentsCalculated++;
  }

  // Component 3: Sleep Duration (PSQI_4)
  const duration = responses.get("PSQI_4");
  if (duration !== undefined) {
    if (duration >= 7) totalScore += 0;
    else if (duration >= 6) totalScore += 1;
    else if (duration >= 5) totalScore += 2;
    else totalScore += 3;
    componentsCalculated++;
  }

  // Component 4: Sleep Efficiency (calculated from PSQI_1, PSQI_3, PSQI_4)
  const bedtime = responses.get("PSQI_1"); // in hours (e.g., 23 for 11pm)
  const wakeTime = responses.get("PSQI_3"); // in hours (e.g., 7 for 7am)
  const hoursSlept = responses.get("PSQI_4");
  if (bedtime !== undefined && wakeTime !== undefined && hoursSlept !== undefined) {
    let timeInBed = wakeTime - bedtime;
    if (timeInBed < 0) timeInBed += 24; // Handle crossing midnight
    if (timeInBed > 0) {
      const efficiency = (hoursSlept / timeInBed) * 100;
      if (efficiency >= 85) totalScore += 0;
      else if (efficiency >= 75) totalScore += 1;
      else if (efficiency >= 65) totalScore += 2;
      else totalScore += 3;
      componentsCalculated++;
    }
  }

  // Component 5: Sleep Disturbances (PSQI_5b, PSQI_5c minimum - prorated if fewer questions answered)
  // iOS app uses shortened version: PSQI_5b (difficulty breathing) and PSQI_5c (bathroom)
  const disturbanceQuestions = ["PSQI_5b", "PSQI_5c", "PSQI_5d", "PSQI_5e", "PSQI_5f", "PSQI_5g", "PSQI_5h", "PSQI_5i", "PSQI_5j"];
  let disturbanceSum = 0;
  let disturbanceCount = 0;
  for (const q of disturbanceQuestions) {
    const val = responses.get(q);
    if (val !== undefined) {
      disturbanceSum += val;
      disturbanceCount++;
    }
  }
  if (disturbanceCount >= 2) {
    // Prorate to 9-question equivalent (max 27 points for original scale)
    const proratedSum = (disturbanceSum / disturbanceCount) * 9;
    if (proratedSum === 0) totalScore += 0;
    else if (proratedSum <= 9) totalScore += 1;
    else if (proratedSum <= 18) totalScore += 2;
    else totalScore += 3;
    componentsCalculated++;
  }

  // Component 6: Use of Sleep Medication (PSQI_7)
  const medication = responses.get("PSQI_7");
  if (medication !== undefined) {
    totalScore += Math.min(3, medication);
    componentsCalculated++;
  }

  // Component 7: Daytime Dysfunction (PSQI_8 + PSQI_9)
  const dysfunction8 = responses.get("PSQI_8");
  const dysfunction9 = responses.get("PSQI_9");
  if (dysfunction8 !== undefined || dysfunction9 !== undefined) {
    let comp7 = (dysfunction8 ?? 0) + (dysfunction9 ?? 0);
    if (comp7 === 0) totalScore += 0;
    else if (comp7 <= 2) totalScore += 1;
    else if (comp7 <= 4) totalScore += 2;
    else totalScore += 3;
    componentsCalculated++;
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (componentsCalculated >= 5) {
    // Prorate to 7 components
    const proratedScore = Math.round(totalScore * (7 / componentsCalculated));
    if (proratedScore <= 5) { interpretation = "Good sleep quality"; severity = "normal"; }
    else if (proratedScore <= 10) { interpretation = "Poor sleep quality"; severity = "mild"; }
    else if (proratedScore <= 15) { interpretation = "Moderate sleep disturbance"; severity = "moderate"; }
    else { interpretation = "Severe sleep disturbance"; severity = "severe"; }

    return { name: "Pittsburgh Sleep Quality Index", abbreviation: "PSQI", score: proratedScore, maxScore: 21, interpretation, severity, questionsAnswered: componentsCalculated, questionsRequired: 7 };
  }

  return { name: "Pittsburgh Sleep Quality Index", abbreviation: "PSQI", score: null, maxScore: 21, interpretation, severity, questionsAnswered: componentsCalculated, questionsRequired: 7 };
}

// DBAS-6 (Dysfunctional Beliefs and Attitudes about Sleep) - 6-item version (2024)
// Machine learning derived abbreviated version with R²=0.90 predicting DBAS-16 total score
// Items: 4, 5, 7, 11, 13, 15 from original DBAS-16
function calculateDBAS6(responses: Map<string, number>): QuestionnaireScore {
  const dbasQuestions = ["DBAS_4", "DBAS_5", "DBAS_7", "DBAS_11", "DBAS_13", "DBAS_15"];
  let total = 0;
  let answered = 0;

  for (const qId of dbasQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 4) {
    // Average score (total / answered, 0-10 scale)
    const avgScore = total / answered;

    // Same thresholds as DBAS-16 since it's an average on the same 0-10 scale
    if (avgScore <= 3) { interpretation = "Low dysfunctional beliefs about sleep"; severity = "normal"; }
    else if (avgScore <= 5) { interpretation = "Moderate dysfunctional beliefs"; severity = "mild"; }
    else if (avgScore <= 7) { interpretation = "Elevated dysfunctional beliefs"; severity = "moderate"; }
    else { interpretation = "High dysfunctional beliefs about sleep"; severity = "severe"; }

    return { name: "Dysfunctional Beliefs and Attitudes about Sleep", abbreviation: "DBAS-6", score: Math.round(avgScore * 10) / 10, maxScore: 10, interpretation, severity, questionsAnswered: answered, questionsRequired: 6 };
  }

  return { name: "Dysfunctional Beliefs and Attitudes about Sleep", abbreviation: "DBAS-6", score: null, maxScore: 10, interpretation, severity, questionsAnswered: answered, questionsRequired: 6 };
}

// Berlin Questionnaire (Sleep Apnea Risk) - 3 categories
function calculateBerlin(responses: Map<string, number>, demographics: { bmi?: number }): QuestionnaireScore {
  let categoriesPositive = 0;
  let answered = 0;

  // Category 1: Snoring (BERLIN_1 to BERLIN_5)
  let cat1Score = 0;
  const snoreFreq = responses.get("BERLIN_1");
  const snoreLoud = responses.get("BERLIN_2");
  const snoreBother = responses.get("BERLIN_3");
  const apneaObserved = responses.get("BERLIN_4");
  const apneaFreq = responses.get("BERLIN_5");

  if (snoreFreq !== undefined) { if (snoreFreq >= 3) cat1Score++; answered++; }
  if (snoreLoud !== undefined) { if (snoreLoud >= 2) cat1Score++; answered++; }
  if (snoreBother !== undefined) { if (snoreBother >= 2) cat1Score++; answered++; }
  if (apneaObserved !== undefined) { if (apneaObserved === 1) cat1Score++; answered++; }
  if (apneaFreq !== undefined) { if (apneaFreq >= 3) cat1Score++; answered++; }

  if (cat1Score >= 2) categoriesPositive++;

  // Category 2: Daytime Sleepiness (BERLIN_6 to BERLIN_9)
  let cat2Score = 0;
  const tiredFreq = responses.get("BERLIN_6");
  const tiredDriving = responses.get("BERLIN_7");
  const dozeDriving = responses.get("BERLIN_8");
  const dozeFreq = responses.get("BERLIN_9");

  if (tiredFreq !== undefined) { if (tiredFreq >= 3) cat2Score++; answered++; }
  if (tiredDriving !== undefined) { if (tiredDriving >= 3) cat2Score++; answered++; }
  if (dozeDriving !== undefined) { if (dozeDriving === 1) cat2Score++; answered++; }
  if (dozeFreq !== undefined) { if (dozeFreq >= 3) cat2Score++; answered++; }

  if (cat2Score >= 2) categoriesPositive++;

  // Category 3: BMI/Hypertension (BERLIN_10 + demographics)
  const hypertension = responses.get("BERLIN_10");
  if (hypertension !== undefined) { answered++; }

  if ((demographics.bmi !== undefined && demographics.bmi > 30) || hypertension === 1) {
    categoriesPositive++;
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 6) {
    if (categoriesPositive >= 2) {
      interpretation = "High risk of sleep apnea";
      severity = "moderate";
    } else {
      interpretation = "Low risk of sleep apnea";
      severity = "normal";
    }

    return { name: "Berlin Questionnaire", abbreviation: "Berlin", score: categoriesPositive, maxScore: 3, interpretation, severity, questionsAnswered: answered, questionsRequired: 10 };
  }

  return { name: "Berlin Questionnaire", abbreviation: "Berlin", score: null, maxScore: 3, interpretation, severity, questionsAnswered: answered, questionsRequired: 10 };
}

// FSS (Fatigue Severity Scale) - 9 questions, each 1-7
function calculateFSS(responses: Map<string, number>): QuestionnaireScore {
  const fssQuestions = Array.from({ length: 9 }, (_, i) => `FSS_${i + 1}`);
  let total = 0;
  let answered = 0;

  for (const qId of fssQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 7) {
    // Mean score per clinical standard (Krupp et al. 1989)
    const meanScore = total / answered;
    // Round to 1 decimal place for mean score display
    const score = Math.round(meanScore * 10) / 10;

    if (score < 4) { interpretation = "No significant fatigue"; severity = "normal"; }
    else if (score < 5) { interpretation = "Mild fatigue"; severity = "mild"; }
    else if (score < 6) { interpretation = "Moderate fatigue"; severity = "moderate"; }
    else { interpretation = "Severe fatigue"; severity = "severe"; }

    // Return mean score (1-7 range) as per clinical standard, not total
    return { name: "Fatigue Severity Scale", abbreviation: "FSS", score, maxScore: 7, interpretation, severity, questionsAnswered: answered, questionsRequired: 9 };
  }

  return { name: "Fatigue Severity Scale", abbreviation: "FSS", score: null, maxScore: 7, interpretation, severity, questionsAnswered: answered, questionsRequired: 9 };
}

// FOSQ-10 (Functional Outcomes of Sleep Questionnaire) - 10 questions, 5 subscales
function calculateFOSQ10(responses: Map<string, number>): QuestionnaireScore {
  const fosqQuestions = Array.from({ length: 10 }, (_, i) => `FOSQ_${i + 1}`);
  let total = 0;
  let answered = 0;

  for (const qId of fosqQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 8) {
    // Mean score * 10 / answered for standardized score (higher = better function)
    const score = Math.round((total / answered) * 10);

    if (score >= 35) { interpretation = "Good functional outcomes"; severity = "normal"; }
    else if (score >= 30) { interpretation = "Mild functional impairment"; severity = "mild"; }
    else if (score >= 25) { interpretation = "Moderate functional impairment"; severity = "moderate"; }
    else { interpretation = "Severe functional impairment"; severity = "severe"; }

    return { name: "Functional Outcomes of Sleep Questionnaire", abbreviation: "FOSQ-10", score, maxScore: 40, interpretation, severity, questionsAnswered: answered, questionsRequired: 10 };
  }

  return { name: "Functional Outcomes of Sleep Questionnaire", abbreviation: "FOSQ-10", score: null, maxScore: 40, interpretation, severity, questionsAnswered: answered, questionsRequired: 10 };
}

// DASS-21 (Depression Anxiety Stress Scales) - 21 questions, 3 subscales (0-3 each)
function calculateDASS21(responses: Map<string, number>): { depression: QuestionnaireScore; anxiety: QuestionnaireScore; stress: QuestionnaireScore } {
  // Depression items: 3, 5, 10, 13, 16, 17, 21
  const depressionItems = [3, 5, 10, 13, 16, 17, 21];
  // Anxiety items: 2, 4, 7, 9, 15, 19, 20
  const anxietyItems = [2, 4, 7, 9, 15, 19, 20];
  // Stress items: 1, 6, 8, 11, 12, 14, 18
  const stressItems = [1, 6, 8, 11, 12, 14, 18];

  const calculateSubscale = (items: number[], name: string, abbrev: string): QuestionnaireScore => {
    let total = 0;
    let answered = 0;

    for (const i of items) {
      const val = responses.get(`DASS_${i}`);
      if (val !== undefined) {
        total += val;
        answered++;
      }
    }

    let interpretation = "Not enough data";
    let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

    if (answered >= 5) {
      // Multiply by 2 to get equivalent of DASS-42
      const score = Math.round(total * 2 * (7 / answered));

      // Thresholds differ by subscale
      if (name === "Depression") {
        if (score <= 9) { interpretation = "Normal"; severity = "normal"; }
        else if (score <= 13) { interpretation = "Mild depression"; severity = "mild"; }
        else if (score <= 20) { interpretation = "Moderate depression"; severity = "moderate"; }
        else { interpretation = "Severe depression"; severity = "severe"; }
      } else if (name === "Anxiety") {
        if (score <= 7) { interpretation = "Normal"; severity = "normal"; }
        else if (score <= 9) { interpretation = "Mild anxiety"; severity = "mild"; }
        else if (score <= 14) { interpretation = "Moderate anxiety"; severity = "moderate"; }
        else { interpretation = "Severe anxiety"; severity = "severe"; }
      } else { // Stress
        if (score <= 14) { interpretation = "Normal"; severity = "normal"; }
        else if (score <= 18) { interpretation = "Mild stress"; severity = "mild"; }
        else if (score <= 25) { interpretation = "Moderate stress"; severity = "moderate"; }
        else { interpretation = "Severe stress"; severity = "severe"; }
      }

      return { name: `DASS-21 ${name}`, abbreviation: abbrev, score, maxScore: 42, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
    }

    return { name: `DASS-21 ${name}`, abbreviation: abbrev, score: null, maxScore: 42, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
  };

  return {
    depression: calculateSubscale(depressionItems, "Depression", "DASS-D"),
    anxiety: calculateSubscale(anxietyItems, "Anxiety", "DASS-A"),
    stress: calculateSubscale(stressItems, "Stress", "DASS-S"),
  };
}

// BPI (Brief Pain Inventory) - Pain severity and interference
function calculateBPI(responses: Map<string, number>): { severity: QuestionnaireScore; interference: QuestionnaireScore } {
  // Severity items: worst (1), least (2), average (3), now (4) - 0-10 scale each
  const severityItems = ["BPI_1", "BPI_2", "BPI_3", "BPI_4"];
  // Interference items: general activity, mood, walking, work, relations, sleep, enjoyment (5-11) - 0-10 scale each
  const interferenceItems = ["BPI_5", "BPI_6", "BPI_7", "BPI_8", "BPI_9", "BPI_10", "BPI_11"];

  const calculateSubscale = (items: string[], name: string, abbrev: string): QuestionnaireScore => {
    let total = 0;
    let answered = 0;

    for (const qId of items) {
      const val = responses.get(qId);
      if (val !== undefined) {
        total += val;
        answered++;
      }
    }

    let interpretation = "Not enough data";
    let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

    if (answered >= Math.ceil(items.length * 0.7)) {
      const avgScore = total / answered;
      const score = Math.round(avgScore * 10) / 10;

      if (score <= 3) { interpretation = `Mild ${name.toLowerCase()}`; severity = "normal"; }
      else if (score <= 5) { interpretation = `Moderate ${name.toLowerCase()}`; severity = "mild"; }
      else if (score <= 7) { interpretation = `Moderately severe ${name.toLowerCase()}`; severity = "moderate"; }
      else { interpretation = `Severe ${name.toLowerCase()}`; severity = "severe"; }

      return { name: `Brief Pain Inventory - ${name}`, abbreviation: abbrev, score: Math.round(total), maxScore: items.length * 10, interpretation, severity, questionsAnswered: answered, questionsRequired: items.length };
    }

    return { name: `Brief Pain Inventory - ${name}`, abbreviation: abbrev, score: null, maxScore: items.length * 10, interpretation, severity, questionsAnswered: answered, questionsRequired: items.length };
  };

  return {
    severity: calculateSubscale(severityItems, "Severity", "BPI-S"),
    interference: calculateSubscale(interferenceItems, "Interference", "BPI-I"),
  };
}

// MEDAS (Mediterranean Diet Adherence Screener) - 14 yes/no questions
function calculateMEDAS(responses: Map<string, number>): QuestionnaireScore {
  const medasQuestions = Array.from({ length: 14 }, (_, i) => `MEDAS_${i + 1}`);
  let total = 0;
  let answered = 0;

  for (const qId of medasQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      // Each favorable answer = 1 point
      total += val === 1 ? 1 : 0;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 10) {
    // Prorate to 14 questions
    const score = Math.round(total * (14 / answered));

    if (score >= 10) { interpretation = "Good Mediterranean diet adherence"; severity = "normal"; }
    else if (score >= 7) { interpretation = "Moderate diet adherence"; severity = "mild"; }
    else if (score >= 4) { interpretation = "Low diet adherence"; severity = "moderate"; }
    else { interpretation = "Poor diet adherence"; severity = "severe"; }

    return { name: "Mediterranean Diet Adherence Screener", abbreviation: "MEDAS", score, maxScore: 14, interpretation, severity, questionsAnswered: answered, questionsRequired: 14 };
  }

  return { name: "Mediterranean Diet Adherence Screener", abbreviation: "MEDAS", score: null, maxScore: 14, interpretation, severity, questionsAnswered: answered, questionsRequired: 14 };
}

// MEQ (Morningness-Eveningness Questionnaire) - Chronotype assessment
function calculateMEQ(responses: Map<string, number>): QuestionnaireScore {
  // MEQ has 19 questions with different scoring ranges
  // For simplified version, using 5 key questions
  const meqQuestions = Array.from({ length: 19 }, (_, i) => `MEQ_${i + 1}`);
  let total = 0;
  let answered = 0;

  for (const qId of meqQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 14) {
    // Prorate to full scale
    const score = Math.round(total * (19 / answered));

    if (score >= 70) { interpretation = "Definite morning type"; severity = "normal"; }
    else if (score >= 59) { interpretation = "Moderate morning type"; severity = "normal"; }
    else if (score >= 42) { interpretation = "Neither type (intermediate)"; severity = "normal"; }
    else if (score >= 31) { interpretation = "Moderate evening type"; severity = "mild"; }
    else { interpretation = "Definite evening type"; severity = "mild"; }

    return { name: "Morningness-Eveningness Questionnaire", abbreviation: "MEQ", score, maxScore: 86, interpretation, severity, questionsAnswered: answered, questionsRequired: 19 };
  }

  return { name: "Morningness-Eveningness Questionnaire", abbreviation: "MEQ", score: null, maxScore: 86, interpretation, severity, questionsAnswered: answered, questionsRequired: 19 };
}

// PROMIS Cognitive Function - 6 questions, 1-5 scale each (higher = worse)
function calculatePROMIS(responses: Map<string, number>): QuestionnaireScore {
  const promisQuestions = Array.from({ length: 6 }, (_, i) => `PROMIS_COG_${i + 1}`);
  let total = 0;
  let answered = 0;

  for (const qId of promisQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 4) {
    // Raw score 6-30, convert to T-score approximation
    // T-score: 50 is average, higher = more cognitive concerns
    const rawMean = total / answered;
    const tScore = Math.round(50 + (rawMean - 3) * 10);

    if (tScore <= 45) { interpretation = "No cognitive concerns"; severity = "normal"; }
    else if (tScore <= 55) { interpretation = "Mild cognitive concerns"; severity = "mild"; }
    else if (tScore <= 65) { interpretation = "Moderate cognitive concerns"; severity = "moderate"; }
    else { interpretation = "Significant cognitive concerns"; severity = "severe"; }

    return { name: "PROMIS Cognitive Function", abbreviation: "PROMIS-Cog", score: tScore, maxScore: 80, interpretation, severity, questionsAnswered: answered, questionsRequired: 6 };
  }

  return { name: "PROMIS Cognitive Function", abbreviation: "PROMIS-Cog", score: null, maxScore: 80, interpretation, severity, questionsAnswered: answered, questionsRequired: 6 };
}

// Sleep Hygiene Index - 10 questions, 1-5 scale each (higher = better hygiene)
function calculateSleepHygiene(responses: Map<string, number>): QuestionnaireScore {
  const shQuestions = Array.from({ length: 10 }, (_, i) => `SH_${i + 1}`);
  let total = 0;
  let answered = 0;

  for (const qId of shQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 7) {
    const avgScore = total / answered;
    const score = Math.round(avgScore * 10) / 10;

    if (score >= 4) { interpretation = "Excellent sleep hygiene"; severity = "normal"; }
    else if (score >= 3) { interpretation = "Good sleep hygiene"; severity = "normal"; }
    else if (score >= 2) { interpretation = "Fair sleep hygiene - room for improvement"; severity = "mild"; }
    else { interpretation = "Poor sleep hygiene - significant changes recommended"; severity = "moderate"; }

    return { name: "Sleep Hygiene Index", abbreviation: "SHI", score: Math.round(total), maxScore: 50, interpretation, severity, questionsAnswered: answered, questionsRequired: 10 };
  }

  return { name: "Sleep Hygiene Index", abbreviation: "SHI", score: null, maxScore: 50, interpretation, severity, questionsAnswered: answered, questionsRequired: 10 };
}

// PSAS (Pre-Sleep Arousal Scale) - Cognitive (8) + Somatic (8) = 16 questions, 1-5 scale
function calculatePSAS(responses: Map<string, number>): { cognitive: QuestionnaireScore; somatic: QuestionnaireScore } {
  const cognitiveItems = Array.from({ length: 8 }, (_, i) => `PSAS_C${i + 1}`);
  const somaticItems = Array.from({ length: 8 }, (_, i) => `PSAS_S${i + 1}`);

  const calculateSubscale = (items: string[], name: string, abbrev: string): QuestionnaireScore => {
    let total = 0;
    let answered = 0;

    for (const qId of items) {
      const val = responses.get(qId);
      if (val !== undefined) {
        total += val;
        answered++;
      }
    }

    let interpretation = "Not enough data";
    let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

    if (answered >= 6) {
      const avgScore = total / answered;

      if (avgScore <= 2) { interpretation = `Low ${name.toLowerCase()} arousal`; severity = "normal"; }
      else if (avgScore <= 3) { interpretation = `Moderate ${name.toLowerCase()} arousal`; severity = "mild"; }
      else if (avgScore <= 4) { interpretation = `High ${name.toLowerCase()} arousal`; severity = "moderate"; }
      else { interpretation = `Very high ${name.toLowerCase()} arousal`; severity = "severe"; }

      return { name: `Pre-Sleep Arousal - ${name}`, abbreviation: abbrev, score: Math.round(total), maxScore: 40, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
    }

    return { name: `Pre-Sleep Arousal - ${name}`, abbreviation: abbrev, score: null, maxScore: 40, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
  };

  return {
    cognitive: calculateSubscale(cognitiveItems, "Cognitive", "PSAS-C"),
    somatic: calculateSubscale(somaticItems, "Somatic", "PSAS-S"),
  };
}

// Shift Work Disorder Screening Questionnaire (SWDSQ)
// 4 Yes/No questions - screening for shift work disorder
function calculateSWDSQ(responses: Map<string, number>): QuestionnaireScore {
  const swdsqQuestions = ["SWDSQ_1", "SWDSQ_2", "SWDSQ_3", "SWDSQ_4"];
  let yesCount = 0;
  let answered = 0;

  for (const qId of swdsqQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      // Yes = 1, No = 0
      if (val === 1) yesCount++;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 3) {
    // SWDSQ Interpretation:
    // - All 4 "Yes" = High risk for Shift Work Disorder
    // - 3 "Yes" = Moderate risk
    // - 2 "Yes" = Low risk
    // - 0-1 "Yes" = Unlikely SWD
    if (yesCount === 4) {
      interpretation = "High risk for Shift Work Disorder - meets all 4 criteria";
      severity = "severe";
    } else if (yesCount === 3) {
      interpretation = "Moderate risk for Shift Work Disorder - meets 3 of 4 criteria";
      severity = "moderate";
    } else if (yesCount === 2) {
      interpretation = "Low risk - some shift work sleep symptoms";
      severity = "mild";
    } else {
      interpretation = "Unlikely Shift Work Disorder";
      severity = "normal";
    }
    return { name: "Shift Work Disorder Screen", abbreviation: "SWDSQ", score: yesCount, maxScore: 4, interpretation, severity, questionsAnswered: answered, questionsRequired: 4 };
  }

  return { name: "Shift Work Disorder Screen", abbreviation: "SWDSQ", score: null, maxScore: 4, interpretation, severity, questionsAnswered: answered, questionsRequired: 4 };
}

// ============================================
// Patient List & Overview Queries
// ============================================

/**
 * Get all patients with their progress and review status
 * SECURITY: Requires physician or admin role via sessionToken
 */
export const getAllPatientsWithProgress = query({
  args: {
    sessionToken: v.optional(v.string()), // Required for production, optional for backward compat
    statusFilter: v.optional(v.string()),
    searchTerm: v.optional(v.string()),
  },
  returns: v.array(
    v.object({
      _id: v.id("users"),
      username: v.string(),
      name: v.optional(v.string()),
      email: v.optional(v.string()),
      current_day: v.number(),
      started_at: v.number(),
      last_accessed: v.number(),
      onboarding_completed: v.optional(v.boolean()),
      onboarding_completed_at: v.optional(v.number()),
      review_status: v.optional(v.string()),
      progress_percentage: v.number(),
      developer_mode: v.optional(v.boolean()),
    })
  ),
  handler: async (ctx, args) => {
    // Validate physician role if session token provided
    if (args.sessionToken) {
      const session = await validatePhysicianRole(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized: Physician access required");
      }
    }
    // TODO: Make sessionToken required once web dashboard auth is updated

    const users = await ctx.db.query("users").collect();

    // Filter out physicians and admins - only show patients
    const patientUsers = users.filter(user =>
      user.role !== "physician" && user.role !== "admin"
    );

    const patientsWithProgress = await Promise.all(
      patientUsers.map(async (user) => {
        // Get the patient's name from D1 response
        const nameResponse = await ctx.db
          .query("user_assessment_responses")
          .withIndex("by_user_question", (q) =>
            q.eq("user_id", user._id).eq("question_id", "D1")
          )
          .first();

        // Get review status
        const reviewStatus = await ctx.db
          .query("patient_review_status")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .first();

        // Calculate progress percentage (14 days total)
        const progressPercentage = Math.min(
          Math.round((user.current_day / 14) * 100),
          100
        );

        // Priority: 1) full_name from profile, 2) D1 questionnaire response, 3) undefined
        const fullName = user.full_name || nameResponse?.response_value || undefined;

        return {
          _id: user._id,
          username: user.username,
          name: fullName, // Full name if available, null otherwise
          email: user.email,
          current_day: user.current_day,
          started_at: user.started_at,
          last_accessed: user.last_accessed,
          onboarding_completed: user.onboarding_completed,
          onboarding_completed_at: user.onboarding_completed_at,
          review_status: reviewStatus?.status,
          progress_percentage: progressPercentage,
          developer_mode: user.developer_mode,
        };
      })
    );

    // Filter by status if provided
    let filtered = patientsWithProgress;
    if (args.statusFilter && args.statusFilter !== "all") {
      filtered = filtered.filter(
        (p) => p.review_status === args.statusFilter
      );
    }

    // Filter by search term (name or username)
    if (args.searchTerm && args.searchTerm.trim() !== "") {
      const searchLower = args.searchTerm.toLowerCase();
      filtered = filtered.filter(
        (p) =>
          p.username.toLowerCase().includes(searchLower) ||
          (p.name && p.name.toLowerCase().includes(searchLower))
      );
    }

    // Sort by last accessed (most recent first)
    filtered.sort((a, b) => b.last_accessed - a.last_accessed);

    return filtered;
  },
});

/**
 * Get comprehensive patient details including all responses, scores, and notes
 * SECURITY: Requires physician or admin role via sessionToken
 */
export const getPatientDetails = query({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()), // Required for production
  },
  returns: v.object({
    user: v.object({
      _id: v.id("users"),
      username: v.string(),
      email: v.optional(v.string()),
      current_day: v.number(),
      started_at: v.number(),
      last_accessed: v.number(),
      onboarding_completed: v.optional(v.boolean()),
      onboarding_completed_at: v.optional(v.number()),
    }),
    name: v.optional(v.string()),
    demographics: v.object({
      dateOfBirth: v.optional(v.string()),
      sex: v.optional(v.string()),
      height: v.optional(v.string()),
      weight: v.optional(v.string()),
    }),
    reviewStatus: v.optional(
      v.object({
        status: v.string(),
        reviewed_by_physician_id: v.optional(v.string()),
        review_started_at: v.optional(v.number()),
        review_completed_at: v.optional(v.number()),
        updated_at: v.number(),
      })
    ),
    totalResponses: v.number(),
    completedDays: v.number(),
  }),
  handler: async (ctx, args) => {
    // Validate physician role if session token provided
    if (args.sessionToken) {
      const session = await validatePhysicianRole(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized: Physician access required");
      }
    }

    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get name (D1)
    const nameResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D1")
      )
      .first();

    // Get demographics (D2, D4, D5, D6)
    const dobResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D2")
      )
      .first();

    const sexResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D4")
      )
      .first();

    const heightResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D5")
      )
      .first();

    const weightResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D6")
      )
      .first();

    // Get review status
    const reviewStatus = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    // Get total responses
    const allResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get completed days - check both user_progress AND actual responses
    const userProgress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    let completedDays = userProgress.filter((p) => p.completed).length;

    // If no progress records, calculate from actual sleep log responses
    if (completedDays === 0 && allResponses.length > 0) {
      // Count unique days that have sleep log entries (CSD_ or SL_ prefix questions)
      const daysWithSleepLog = new Set(
        allResponses
          .filter(
            (r) =>
              r.day_number !== undefined &&
              (r.question_id.startsWith("CSD_") ||
                r.question_id.startsWith("SL_") ||
                r.question_id.startsWith("SD_"))
          )
          .map((r) => r.day_number)
      );
      completedDays = daysWithSleepLog.size;
    }

    return {
      user: {
        _id: user._id,
        username: user.username,
        email: user.email,
        current_day: user.current_day,
        started_at: user.started_at,
        last_accessed: user.last_accessed,
        onboarding_completed: user.onboarding_completed,
        onboarding_completed_at: user.onboarding_completed_at,
      },
      name: user.full_name || nameResponse?.response_value || undefined, // Priority: profile full_name, then D1 response
      demographics: {
        dateOfBirth: dobResponse?.response_value,
        sex: sexResponse?.response_value,
        height: heightResponse?.response_value,
        weight: weightResponse?.response_value,
      },
      reviewStatus: reviewStatus
        ? {
            status: reviewStatus.status,
            reviewed_by_physician_id: reviewStatus.reviewed_by_physician_id,
            review_started_at: reviewStatus.review_started_at,
            review_completed_at: reviewStatus.review_completed_at,
            updated_at: reviewStatus.updated_at,
          }
        : undefined,
      totalResponses: allResponses.length,
      completedDays,
    };
  },
});

/**
 * Get all responses and notes for a specific day
 * SECURITY: Requires physician or admin role via sessionToken
 */
export const getPatientDayData = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    sessionToken: v.optional(v.string()), // Required for production
  },
  returns: v.object({
    responses: v.array(
      v.object({
        _id: v.id("user_assessment_responses"),
        question_id: v.string(),
        response_value: v.optional(v.string()),
        response_unit: v.optional(v.string()),
        question_text: v.optional(v.string()),
        question_type: v.optional(v.string()),
        pillar: v.optional(v.string()),
        tier: v.optional(v.string()),
        created_at: v.number(),
        updated_at: v.number(),
      })
    ),
    notes: v.array(
      v.object({
        _id: v.id("physician_notes"),
        note_text: v.string(),
        created_at: v.number(),
        updated_at: v.number(),
        physician_id: v.optional(v.string()),
      })
    ),
  }),
  handler: async (ctx, args) => {
    // Validate physician role if session token provided
    if (args.sessionToken) {
      const session = await validatePhysicianRole(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized: Physician access required");
      }
    }

    // Get responses for this day
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    // Enrich with question details using global definitions + database fallback
    const enrichedResponses = await Promise.all(
      responses.map(async (response) => {
        let questionText: string | undefined;
        let questionType: string | undefined;
        let pillar: string | undefined;
        let tier: string | undefined = "core";

        // First check global hardcoded definitions (SL_ and SD_ prefixes)
        const hardcodedDef = getQuestionDefinition(response.question_id);
        if (hardcodedDef) {
          questionText = hardcodedDef.text;
          questionType = hardcodedDef.type;
          pillar = hardcodedDef.pillar;
        } else if (response.question_id.startsWith("SL_") || response.question_id.startsWith("SD_")) {
          // Fallback: try to find in sleep_diary_questions table
          const sleepQuestion = await ctx.db
            .query("sleep_diary_questions")
            .withIndex("by_question_id", (q) => q.eq("id", response.question_id))
            .first();

          if (sleepQuestion) {
            questionText = sleepQuestion.question_text;
            questionType = sleepQuestion.answer_format;
            pillar = response.question_id.startsWith("SL_") ? "Sleep Log" : "Sleep Diary";
          }
        } else {
          // Check assessment_questions table for all other questions
          let question = await ctx.db
            .query("assessment_questions")
            .withIndex("by_question_id", (q) =>
              q.eq("question_id", response.question_id)
            )
            .first();

          // If not found, try stripping common prefixes (PSQI_, ISI_, etc.)
          if (!question && response.question_id.includes("_")) {
            const baseId = response.question_id.split("_").pop();
            if (baseId) {
              question = await ctx.db
                .query("assessment_questions")
                .withIndex("by_question_id", (q) =>
                  q.eq("question_id", baseId)
                )
                .first();
            }
          }

          if (question) {
            questionText = question.question_text;
            questionType = question.question_type;
            pillar = question.pillar;
            tier = question.tier;
          }
        }

        // Combine response_value, response_number, response_array, and response_object into a displayable value
        let displayValue: string | undefined = response.response_value;

        // If no string value, check for numeric value
        if (!displayValue && response.response_number !== undefined && response.response_number !== null) {
          displayValue = String(response.response_number);
        }

        // If no string or number, check for array value
        if (!displayValue && response.response_array) {
          try {
            const arr = typeof response.response_array === 'string'
              ? JSON.parse(response.response_array)
              : response.response_array;
            if (Array.isArray(arr) && arr.length > 0) {
              displayValue = arr.join(", ");
            }
          } catch {
            displayValue = String(response.response_array);
          }
        }

        // Handle complex object types (medication_select, nap_details, supplement_select)
        if (!displayValue && response.response_object) {
          try {
            const obj = typeof response.response_object === 'string'
              ? JSON.parse(response.response_object)
              : response.response_object;

            // Format based on question type
            if (questionType === "medication_select" || questionType === "prescription_med_select" || questionType === "supplement_select") {
              // Array of MedicationWithTiming objects: { categoryId, dose?, medicationName?, timingCategories[] }
              if (Array.isArray(obj) && obj.length > 0) {
                displayValue = obj.map((med: { categoryId?: string; medicationName?: string; dose?: string; timingCategories?: string[] }) => {
                  const name = med.medicationName || med.categoryId || "Unknown";
                  const dose = med.dose ? ` (${med.dose})` : "";
                  const timing = med.timingCategories && med.timingCategories.length > 0
                    ? ` - ${med.timingCategories.join(", ")}`
                    : "";
                  return `${name}${dose}${timing}`;
                }).join("; ");
              } else {
                displayValue = "No medications selected";
              }
            } else if (questionType === "nap_details") {
              // Array of nap entries: { startTime, durationMinutes, napNumber }
              if (Array.isArray(obj) && obj.length > 0) {
                displayValue = obj.map((nap: { startTime?: string; nap_start_time?: string; durationMinutes?: number; nap_duration_minutes?: number; napNumber?: number }) => {
                  const startTime = nap.startTime || nap.nap_start_time || "Unknown";
                  const duration = nap.durationMinutes ?? nap.nap_duration_minutes ?? 0;
                  return `${startTime} (${duration} min)`;
                }).join("; ");
              } else {
                displayValue = "No nap details";
              }
            } else {
              // Generic object display
              displayValue = JSON.stringify(obj);
            }
          } catch {
            displayValue = String(response.response_object);
          }
        }

        // Append unit to display value if present (e.g., "85 cm" instead of just "85")
        const finalDisplayValue = displayValue && response.response_unit
          ? `${displayValue} ${response.response_unit}`
          : displayValue;

        return {
          _id: response._id,
          question_id: response.question_id,
          response_value: finalDisplayValue,
          response_unit: response.response_unit,
          question_text: questionText,
          question_type: questionType,
          pillar: pillar,
          tier: tier,
          created_at: response.created_at,
          updated_at: response.updated_at,
        };
      })
    );

    // Get notes for this day
    const notes = await ctx.db
      .query("physician_notes")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    return {
      responses: enrichedResponses,
      notes: notes.map((note) => ({
        _id: note._id,
        note_text: note.note_text,
        created_at: note.created_at,
        updated_at: note.updated_at,
        physician_id: note.physician_id,
      })),
    };
  },
});

/**
 * Get all physician notes for a patient
 */
export const getPhysicianNotes = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("physician_notes"),
      day_number: v.optional(v.number()),
      note_text: v.string(),
      created_at: v.number(),
      updated_at: v.number(),
      physician_id: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const notes = await ctx.db
      .query("physician_notes")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sort by most recent first
    notes.sort((a, b) => b.created_at - a.created_at);

    return notes.map((note) => ({
      _id: note._id,
      day_number: note.day_number,
      note_text: note.note_text,
      created_at: note.created_at,
      updated_at: note.updated_at,
      physician_id: note.physician_id,
    }));
  },
});

/**
 * Get all calculated questionnaire scores for a patient
 */
export const getQuestionnaireScores = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("questionnaire_scores"),
      questionnaire_name: v.string(),
      score: v.number(),
      max_score: v.optional(v.number()),
      category: v.optional(v.string()),
      interpretation: v.optional(v.string()),
      calculated_at: v.number(),
      calculation_metadata_json: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const scores = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sort by calculation date (most recent first)
    scores.sort((a, b) => b.calculated_at - a.calculated_at);

    return scores.map((score) => ({
      _id: score._id,
      questionnaire_name: score.questionnaire_name,
      score: score.score,
      max_score: score.max_score,
      category: score.category,
      interpretation: score.interpretation,
      calculated_at: score.calculated_at,
      calculation_metadata_json: score.calculation_metadata_json,
    }));
  },
});

/**
 * Get pillar completion stats based on actual responses
 * This calculates how many questions per pillar have been answered
 */
export const getPillarStats = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      pillar: v.string(),
      questionsAnswered: v.number(),
      questionsTotal: v.number(),
      completionPercent: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    // Get all responses for this user
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get unique question IDs that have been answered
    const answeredQuestionIds = new Set(responses.map(r => r.question_id));

    // Pillar question counts (approximate based on assessment_modules.json)
    const pillarConfig: Record<string, { displayName: string; expectedQuestions: number }> = {
      "Social": { displayName: "Social", expectedQuestions: 15 },
      "Metabolic": { displayName: "Metabolic", expectedQuestions: 17 },
      "Sleep Quality": { displayName: "Sleep Quality", expectedQuestions: 23 },
      "Sleep Quantity": { displayName: "Sleep Quantity", expectedQuestions: 3 },
      "Sleep Regularity": { displayName: "Sleep Regularity", expectedQuestions: 4 },
      "Sleep Timing": { displayName: "Sleep Timing", expectedQuestions: 8 },
      "Mental Health": { displayName: "Mental Health", expectedQuestions: 48 },
      "Cognitive": { displayName: "Cognitive", expectedQuestions: 33 },
      "Physical": { displayName: "Physical", expectedQuestions: 42 },
      "Nutritional": { displayName: "Nutritional", expectedQuestions: 25 },
      "Sleep Log": { displayName: "Sleep Log", expectedQuestions: 5 },
    };

    // Count answers per pillar by looking up questions
    const pillarCounts: Record<string, number> = {};

    for (const questionId of answeredQuestionIds) {
      // Try to find the question's pillar
      let question = await ctx.db
        .query("assessment_questions")
        .withIndex("by_question_id", (q) => q.eq("question_id", questionId))
        .first();

      // Try stripping prefix if not found
      if (!question && questionId.includes("_")) {
        const baseId = questionId.split("_").pop();
        if (baseId) {
          question = await ctx.db
            .query("assessment_questions")
            .withIndex("by_question_id", (q) => q.eq("question_id", baseId))
            .first();
        }
      }

      // Handle special prefixes
      let pillar = question?.pillar;
      if (!pillar) {
        if (questionId.startsWith("SL_") || questionId.startsWith("CSD_")) {
          pillar = "Sleep Log";
        } else if (questionId.startsWith("SD_")) {
          pillar = "Sleep Diary";
        }
      }

      if (pillar) {
        pillarCounts[pillar] = (pillarCounts[pillar] || 0) + 1;
      }
    }

    // Build results
    return Object.entries(pillarConfig).map(([pillar, config]) => {
      const answered = pillarCounts[pillar] || 0;
      const total = config.expectedQuestions;
      return {
        pillar: config.displayName,
        questionsAnswered: answered,
        questionsTotal: total,
        completionPercent: total > 0 ? Math.min(100, Math.round((answered / total) * 100)) : 0,
      };
    });
  },
});

/**
 * Get patient visible field configuration
 */
export const getPatientVisibleFields = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const config = await ctx.db
      .query("patient_visible_fields")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!config) return undefined;

    return {
      _id: config._id,
      field_config_json: config.field_config_json,
      updated_at: config.updated_at,
      updated_by_physician_id: config.updated_by_physician_id,
    };
  },
});

/**
 * Get all responses grouped by day for a patient
 */
export const getPatientResponsesByDay = query({
  args: { userId: v.id("users") },
  returns: v.object({
    days: v.array(
      v.object({
        dayNumber: v.number(),
        responseCount: v.number(),
        lastUpdated: v.number(),
        hasNotes: v.boolean(),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Group by day
    const dayMap: Record<
      number,
      { count: number; lastUpdated: number; notes: boolean }
    > = {};

    for (const response of responses) {
      if (response.day_number !== undefined) {
        if (!dayMap[response.day_number]) {
          dayMap[response.day_number] = {
            count: 0,
            lastUpdated: 0,
            notes: false,
          };
        }
        dayMap[response.day_number].count++;
        dayMap[response.day_number].lastUpdated = Math.max(
          dayMap[response.day_number].lastUpdated,
          response.updated_at
        );
      }
    }

    // Check for notes
    const allNotes = await ctx.db
      .query("physician_notes")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const note of allNotes) {
      if (note.day_number !== undefined && dayMap[note.day_number]) {
        dayMap[note.day_number].notes = true;
      }
    }

    // Convert to array and sort
    const days = Object.entries(dayMap)
      .map(([dayNumber, data]) => ({
        dayNumber: parseInt(dayNumber, 10),
        responseCount: data.count,
        lastUpdated: data.lastUpdated,
        hasNotes: data.notes,
      }))
      .sort((a, b) => a.dayNumber - b.dayNumber);

    return { days };
  },
});

/**
 * Get active interventions for a patient
 */
export const getPatientInterventions = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("user_interventions"),
      intervention_id: v.id("interventions"),
      intervention_name: v.string(),
      start_date: v.string(),
      end_date: v.optional(v.string()),
      frequency: v.optional(v.string()),
      dosage: v.optional(v.string()),
      timing: v.optional(v.string()),
      custom_instructions: v.optional(v.string()),
      status: v.string(),
      assigned_at: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Enrich with intervention details
    const enriched = await Promise.all(
      userInterventions.map(async (ui) => {
        const intervention = await ctx.db.get(ui.intervention_id);
        return {
          _id: ui._id,
          intervention_id: ui.intervention_id,
          intervention_name: intervention?.name || "Unknown",
          start_date: ui.start_date,
          end_date: ui.end_date,
          frequency: ui.frequency,
          dosage: ui.dosage,
          timing: ui.timing,
          custom_instructions: ui.custom_instructions,
          status: ui.status,
          assigned_at: ui.assigned_at,
        };
      })
    );

    // Sort by assignment date (most recent first)
    enriched.sort((a, b) => b.assigned_at - a.assigned_at);

    return enriched;
  },
});

/**
 * Get all available interventions library
 */
export const getAllInterventions = query({
  args: {},
  returns: v.array(
    v.object({
      _id: v.id("interventions"),
      name: v.string(),
      type: v.optional(v.string()),
      category: v.optional(v.string()),
      instructions_text: v.string(),
      status: v.string(),
    })
  ),
  handler: async (ctx) => {
    const interventions = await ctx.db
      .query("interventions")
      .withIndex("by_status", (q) => q.eq("status", "active"))
      .collect();

    return interventions.map((i) => ({
      _id: i._id,
      name: i.name,
      type: i.type,
      category: i.category,
      instructions_text: i.instructions_text,
      status: i.status,
    }));
  },
});

// ============================================
// Daily Compliance Data (for Streak Calculation)
// ============================================

/**
 * Get daily compliance data for accurate streak and completion tracking
 */
export const getDailyComplianceData = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      dayNumber: v.number(),
      date: v.string(),
      sleepLogCompleted: v.boolean(),
      assessmentCompleted: v.boolean(),
      expansionCompleted: v.boolean(),
      hasExpansionTask: v.boolean(), // Whether a Deeper Dive was assigned for this day
      hasAssessmentTask: v.boolean(), // Whether core assessment questions exist for this day (Days 1-5)
      responseCount: v.number(),
      // Additional fields for granular tracking
      sleepLogQuestionsAnswered: v.number(),
      assessmentQuestionsAnswered: v.number(),
      expansionQuestionsAnswered: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return [];

    // Get all responses for this user (for question counting)
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get user_progress entries - THIS IS THE SOURCE OF TRUTH for task completion
    const progressEntries = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get days table to map day_id to day_number
    const days = await ctx.db.query("days").collect();
    const dayIdToNumber: Record<string, number> = {};
    for (const day of days) {
      dayIdToNumber[day._id] = day.day_number;
    }

    // Build progress map by day number from user_progress table
    const progressByDay: Record<number, {
      sleepLogCompleted: boolean;
      assessmentCompleted: boolean;
      expansionPackCompleted: boolean;
    }> = {};
    for (const progress of progressEntries) {
      const dayNum = dayIdToNumber[progress.day_id];
      if (dayNum) {
        progressByDay[dayNum] = {
          sleepLogCompleted: progress.sleep_log_completed ?? false,
          assessmentCompleted: progress.assessment_completed ?? false,
          expansionPackCompleted: progress.expansion_pack_completed ?? false,
        };
      }
    }

    // Get triggered gateways to determine which days have expansion tasks
    // Using fixed schedule instead of dynamic user_expansion_schedules table
    const userGateways = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const triggeredGateways = userGateways
      .filter((g) => g.triggered)
      .map((g) => g.gateway_id);

    // Build map of days that have expansion tasks based on FIXED SCHEDULE
    // Days 6-14 have expansion if ANY of their gateways are triggered
    const daysWithExpansionTask = new Set<number>();
    for (let day = 6; day <= 14; day++) {
      if (shouldShowExpansion(day, triggeredGateways)) {
        daysWithExpansionTask.add(day);
      }
    }

    // Get completion status from progressByDay (already loaded above)
    const expansionCompletedByDay: Record<number, boolean> = {};
    for (const [dayNum, progress] of Object.entries(progressByDay)) {
      if (progress.expansionPackCompleted) {
        expansionCompletedByDay[Number(dayNum)] = true;
      }
    }

    // For Days 1-5, also check for same-day triggered gateways (insomnia, depression, anxiety, osa)
    const sameDayGateways = ["insomnia", "depression", "anxiety", "osa"];
    const hasSameDayTriggeredGateway = userGateways.some(
      (g) => g.triggered && sameDayGateways.includes(g.gateway_id)
    );

    // Sleep log question IDs (CSD = Consensus Sleep Diary, SL = Sleep Log, SD = Sleep Diary)
    const sleepLogPrefixes = ["CSD_", "SL_", "SD_"];

    // Core assessment question IDs that use standardized prefixes (PSQI_, etc.)
    // These are answered in Days 1-5 core assessment and should NOT be counted as expansion
    const coreAssessmentWithPrefixes = new Set([
      // PSQI questions in core assessment
      "PSQI_1", "PSQI_2", "PSQI_3", "PSQI_4",
      "PSQI_5a", "PSQI_5b", "PSQI_5c", "PSQI_5d", "PSQI_5e",
      "PSQI_5f", "PSQI_5g", "PSQI_5h", "PSQI_5i", "PSQI_5j",
      "PSQI_6", "PSQI_7", "PSQI_8", "PSQI_9",
    ]);

    // Expansion module prefixes (Deeper Dive questionnaires)
    // NOTE: PSQI_ questions in core assessment are handled separately above
    const expansionPrefixes = [
      "ISI_",      // Insomnia Severity Index (7 questions)
      "PHQ9_",     // Depression (9 questions)
      "GAD7_",     // Anxiety (7 questions)
      "SB_",       // STOP-BANG Sleep Apnea (8 questions)
      "ESS_",      // Epworth Sleepiness Scale (8 questions)
      "DBAS_",     // Dysfunctional Beliefs About Sleep - DBAS-6 (6 questions)
      "SH_",       // Sleep Hygiene (10 questions)
      "PSAS_",     // Pre-Sleep Arousal Scale (16 questions)
      "PSQI_",     // Pittsburgh Sleep Quality Index (19 questions) - expansion only
      "DASS_",     // Depression Anxiety Stress Scale (21 questions)
      // "BERLIN_", - Berlin removed, STOP-BANG has 93% sensitivity for OSA
      "FSS_",      // Fatigue Severity Scale (9 questions)
      "FOSQ_",     // Functional Outcomes of Sleep (10 questions)
      "PROMIS_",   // Cognitive Function (15 questions)
      "BPI_",      // Brief Pain Inventory (11 questions)
      "MEQ_",      // Morningness-Eveningness Questionnaire (19 questions)
      "SWDSQ_",    // Shift Work Disorder (4 questions)
    ];

    // Expansion module sizes for completion detection
    const expansionModuleSizes: Record<string, number> = {
      "ISI_": 7, "PHQ9_": 9, "GAD7_": 7, "SB_": 8, "ESS_": 8,
      "DBAS_": 6, "SH_": 10, "PSAS_": 16, "PSQI_": 19, "DASS_": 21, // DBAS-6 replaces DBAS-16
      // "BERLIN_": 10, - Berlin removed, STOP-BANG has 93% sensitivity for OSA
      "FSS_": 9, "FOSQ_": 10, "PROMIS_": 15,
      "BPI_": 11, "MEQ_": 19, "SWDSQ_": 4,
    };

    // Group responses by day
    const dayData: Record<
      number,
      {
        sleepLogQuestions: Set<string>;
        assessmentQuestions: Set<string>;
        expansionQuestions: Set<string>;
        expansionByModule: Record<string, Set<string>>;
        responseCount: number;
      }
    > = {};

    for (const response of responses) {
      const day = response.day_number ?? 1;
      if (!dayData[day]) {
        dayData[day] = {
          sleepLogQuestions: new Set(),
          assessmentQuestions: new Set(),
          expansionQuestions: new Set(),
          expansionByModule: {},
          responseCount: 0,
        };
      }
      dayData[day].responseCount++;

      const qId = response.question_id;

      // Check if sleep log question
      const isSleepLog = sleepLogPrefixes.some((prefix) => qId.startsWith(prefix));
      if (isSleepLog) {
        dayData[day].sleepLogQuestions.add(qId);
        continue;
      }

      // Check if core assessment question that uses a standardized prefix (e.g., PSQI_1)
      // These are answered during Days 1-5 and should count as core assessment, not expansion
      if (coreAssessmentWithPrefixes.has(qId)) {
        dayData[day].assessmentQuestions.add(qId);
        continue;
      }

      // Check if expansion question (questionnaires triggered by gateways)
      const expansionPrefix = expansionPrefixes.find((prefix) => qId.startsWith(prefix));
      if (expansionPrefix) {
        dayData[day].expansionQuestions.add(qId);
        // Track by module for completion detection
        if (!dayData[day].expansionByModule[expansionPrefix]) {
          dayData[day].expansionByModule[expansionPrefix] = new Set();
        }
        dayData[day].expansionByModule[expansionPrefix].add(qId);
        continue;
      }

      // Otherwise it's a core assessment question (numbered IDs like "1", "15", etc.)
      dayData[day].assessmentQuestions.add(qId);
    }

    // Build result for each day up to current_day
    const result: {
      dayNumber: number;
      date: string;
      sleepLogCompleted: boolean;
      assessmentCompleted: boolean;
      expansionCompleted: boolean;
      hasExpansionTask: boolean;
      hasAssessmentTask: boolean;
      responseCount: number;
      sleepLogQuestionsAnswered: number;
      assessmentQuestionsAnswered: number;
      expansionQuestionsAnswered: number;
    }[] = [];

    for (let day = 1; day <= user.current_day; day++) {
      const data = dayData[day];
      const date = new Date(user.started_at + (day - 1) * 86400000)
        .toISOString()
        .split("T")[0];

      // Check if any expansion module is complete for this day
      let expansionComplete = false;
      if (data) {
        for (const [prefix, questions] of Object.entries(data.expansionByModule)) {
          const expectedSize = expansionModuleSizes[prefix] || 5;
          if (questions.size >= expectedSize) {
            expansionComplete = true;
            break;
          }
        }
      }

      // Get completion status from user_progress (source of truth)
      const dayProgress = progressByDay[day];

      // Determine if this day has an expansion task assigned
      // Only use explicit sources of truth:
      // 1. Check explicit schedule (from user_expansion_schedules.day_assignments)
      // 2. Check if user_progress shows expansion completed (catches same-day triggers)
      // NOTE: We do NOT use "questions answered" as a signal because questions can be
      // partially answered without the task being formally assigned for that day
      const hasScheduledExpansion = daysWithExpansionTask.has(day);
      const progressShowsExpansion = dayProgress?.expansionPackCompleted ?? false;
      const hasExpansionTask = hasScheduledExpansion || progressShowsExpansion;

      // Use user_progress as source of truth for completion, with fallback to question counts
      const sleepLogCompleted = dayProgress?.sleepLogCompleted ?? (data ? data.sleepLogQuestions.size >= 5 : false);
      const assessmentCompleted = dayProgress?.assessmentCompleted ?? (data ? data.assessmentQuestions.size >= 8 : false);

      // Expansion is complete if:
      // 1. user_progress.expansion_pack_completed is true, OR
      // 2. user_expansion_schedules.day_assignments[day].completed is true, OR
      // 3. Question-based check (any module fully answered)
      const expansionFromProgress = progressShowsExpansion;
      const expansionFromSchedule = expansionCompletedByDay[day] ?? false;
      const expansionIsComplete = expansionFromProgress || expansionFromSchedule || expansionComplete;

      // Days 1-5 have core assessment questions, Days 6-14 do not
      // On Days 6-14, only Sleep Log and (optionally) Expansion Pack are assigned
      const hasAssessmentTask = day <= 5;

      result.push({
        dayNumber: day,
        date,
        sleepLogCompleted,
        assessmentCompleted,
        expansionCompleted: expansionIsComplete,
        hasExpansionTask,
        hasAssessmentTask,
        responseCount: data?.responseCount ?? 0,
        // Actual question counts for granular progress
        sleepLogQuestionsAnswered: data ? data.sleepLogQuestions.size : 0,
        assessmentQuestionsAnswered: data ? data.assessmentQuestions.size : 0,
        expansionQuestionsAnswered: data ? data.expansionQuestions.size : 0,
      });
    }

    return result;
  },
});

/**
 * Get modular compliance data with separate tracking for:
 * - Sleep Log (daily diary entries)
 * - Core Assessment (Days 1-5 questions everyone answers)
 * - Expansion Packs (triggered based on gateway responses)
 */
export const getModularComplianceData = query({
  args: { userId: v.id("users") },
  returns: v.object({
    sleepLog: v.object({
      daysCompleted: v.number(),
      totalDays: v.number(),
      rate: v.number(),
      questionsAnswered: v.number(),
    }),
    coreAssessment: v.object({
      questionsAnswered: v.number(),
      totalQuestions: v.number(),
      rate: v.number(),
    }),
    expansionPacks: v.object({
      triggered: v.boolean(),
      triggeredGateways: v.array(v.string()),
      questionsAnswered: v.number(),
      totalQuestions: v.number(),
      rate: v.number(),
      modules: v.array(v.object({
        id: v.string(),
        name: v.string(),
        questionsAnswered: v.number(),
        questionsFromCore: v.number(),
        questionsFromExpansion: v.number(),
        totalQuestions: v.number(),
        completed: v.boolean(),
        completionPercentage: v.number(),
      })),
    }),
    overall: v.object({
      rate: v.number(),
      totalQuestionsAnswered: v.number(),
      totalQuestionsExpected: v.number(),
    }),
  }),
  handler: async (ctx, args) => {
    const TOTAL_JOURNEY_DAYS = 14;
    const SLEEP_LOG_QUESTIONS_PER_DAY = 5; // Minimum required per day

    // Core assessment expected questions (from crossPlatformValidator)
    const CORE_EXPECTED_QUESTIONS = 92; // Demographics + all core modules

    // Expansion module definitions with prefixes for identification
    const EXPANSION_MODULES = [
      { id: "expansion_isi", name: "Insomnia Severity (ISI)", prefix: "ISI_", questions: 7, gateways: ["insomnia", "poor_sleep_quality"] },
      { id: "expansion_phq9", name: "Depression (PHQ-9)", prefix: "PHQ9_", questions: 9, gateways: ["depression"] },
      { id: "expansion_gad7", name: "Anxiety (GAD-7)", prefix: "GAD7_", questions: 7, gateways: ["anxiety"] },
      { id: "expansion_stop_bang", name: "Sleep Apnea (STOP-BANG)", prefix: "SB_", questions: 8, gateways: ["osa"] },
      { id: "expansion_ess", name: "Sleepiness (ESS)", prefix: "ESS_", questions: 8, gateways: ["excessive_sleepiness"] },
      { id: "expansion_dbas", name: "Sleep Beliefs (DBAS-16)", prefix: "DBAS_", questions: 16, gateways: ["insomnia"] },
      { id: "expansion_sleep_hygiene", name: "Sleep Hygiene", prefix: "SH_", questions: 10, gateways: ["insomnia", "poor_sleep_quality"] },
      { id: "expansion_psas", name: "Pre-Sleep Arousal (PSAS)", prefix: "PSAS_", questions: 16, gateways: ["insomnia"] },
      { id: "expansion_psqi", name: "Sleep Quality (PSQI)", prefix: "PSQI_", questions: 19, gateways: ["poor_sleep_quality"] },
      { id: "expansion_dass21", name: "Stress Scale (DASS-21)", prefix: "DASS_", questions: 21, gateways: ["depression", "anxiety"] },
      { id: "expansion_berlin", name: "Berlin Questionnaire", prefix: "BERLIN_", questions: 10, gateways: ["osa"] },
      { id: "expansion_fss", name: "Fatigue (FSS)", prefix: "FSS_", questions: 9, gateways: ["excessive_sleepiness"] },
      { id: "expansion_fosq", name: "Functional Outcomes (FOSQ)", prefix: "FOSQ_", questions: 10, gateways: ["excessive_sleepiness"] },
      { id: "expansion_promis", name: "Cognitive Function (PROMIS)", prefix: "PROMIS_", questions: 15, gateways: ["cognitive"] },
      { id: "expansion_bpi", name: "Pain (BPI)", prefix: "BPI_", questions: 11, gateways: ["pain"] },
      { id: "expansion_meq", name: "Chronotype (MEQ)", prefix: "MEQ_", questions: 19, gateways: ["sleep_timing"] },
      { id: "expansion_swdsq", name: "Shift Work (SWDSQ)", prefix: "SWDSQ_", questions: 4, gateways: ["shift_work"] },
    ];

    // Core Assessment → Expansion Module Question Mapping
    // Maps core questions (Days 1-5) to their standardized questionnaire equivalents
    const CORE_TO_EXPANSION_MAPPING: Array<{ coreQuestionId: string; expansionModuleId: string; weight: number }> = [
      // PSQI (16 items from core)
      { coreQuestionId: "PSQI_1", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_2", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_3", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5a", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5b", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5c", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5d", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5e", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5f", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5g", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5h", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5i", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "PSQI_5j", expansionModuleId: "expansion_psqi", weight: 1.0 },
      { coreQuestionId: "1", expansionModuleId: "expansion_psqi", weight: 1.0 }, // Overall sleep quality
      { coreQuestionId: "12A", expansionModuleId: "expansion_psqi", weight: 0.5 }, // Night awakenings
      { coreQuestionId: "12C", expansionModuleId: "expansion_psqi", weight: 0.5 }, // Return to sleep time
      // PHQ-9 (1 gateway item)
      { coreQuestionId: "15", expansionModuleId: "expansion_phq9", weight: 1.0 }, // Depression gateway
      // GAD-7 (1 gateway item)
      { coreQuestionId: "16", expansionModuleId: "expansion_gad7", weight: 1.0 }, // Anxiety gateway
      // STOP-BANG (3 items)
      { coreQuestionId: "19", expansionModuleId: "expansion_stop_bang", weight: 1.0 }, // Snore loudly
      { coreQuestionId: "20", expansionModuleId: "expansion_stop_bang", weight: 1.0 }, // Stop breathing
      { coreQuestionId: "21", expansionModuleId: "expansion_stop_bang", weight: 1.0 }, // Tired/fatigued
      // ESS (1-2 related items)
      { coreQuestionId: "17", expansionModuleId: "expansion_ess", weight: 0.5 }, // Excessive sleepiness
      { coreQuestionId: "21", expansionModuleId: "expansion_ess", weight: 0.5 }, // Tired (also STOP-BANG)
      // BPI (2 items)
      { coreQuestionId: "22", expansionModuleId: "expansion_bpi", weight: 1.0 }, // Pain affects sleep
      { coreQuestionId: "23", expansionModuleId: "expansion_bpi", weight: 1.0 }, // Pain level
      // MEQ (1 related item)
      { coreQuestionId: "11", expansionModuleId: "expansion_meq", weight: 0.5 }, // Morning sunlight
      // Sleep Hygiene (3-4 items)
      { coreQuestionId: "13", expansionModuleId: "expansion_sleep_hygiene", weight: 1.0 }, // Screen use
      { coreQuestionId: "29", expansionModuleId: "expansion_sleep_hygiene", weight: 1.0 }, // Caffeine
      { coreQuestionId: "32", expansionModuleId: "expansion_sleep_hygiene", weight: 1.0 }, // Alcohol
      { coreQuestionId: "33", expansionModuleId: "expansion_sleep_hygiene", weight: 1.0 }, // Alcohol timing
      // ISI (1 gateway item)
      { coreQuestionId: "3", expansionModuleId: "expansion_isi", weight: 0.5 }, // Insomnia gateway
    ];

    // Sleep log prefixes
    const SLEEP_LOG_PREFIXES = ["CSD_", "SL_", "SD_"];

    // Core assessment question IDs that use standardized prefixes (PSQI_, etc.)
    // These are answered in Days 1-5 core assessment and should NOT be counted as expansion
    const CORE_ASSESSMENT_WITH_PREFIXES = new Set(
      CORE_TO_EXPANSION_MAPPING
        .filter(m => m.coreQuestionId.includes("_")) // Only IDs with prefixes like PSQI_1
        .map(m => m.coreQuestionId)
    );

    // Get all responses for this user
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get user's triggered gateways
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const triggeredGateways = gatewayStates
      .filter(g => g.triggered)
      .map(g => g.gateway_id);

    // Categorize responses
    const sleepLogQuestionsByDay: Record<number, Set<string>> = {};
    const coreQuestions = new Set<string>();
    const expansionQuestionsByModule: Record<string, Set<string>> = {};
    const coreContributionsByModule: Record<string, Set<string>> = {};
    const answeredQuestionIds = new Set<string>();

    // Initialize expansion module tracking
    EXPANSION_MODULES.forEach(m => {
      expansionQuestionsByModule[m.id] = new Set();
      coreContributionsByModule[m.id] = new Set();
    });

    // First pass: collect all answered question IDs
    for (const response of responses) {
      answeredQuestionIds.add(response.question_id);
    }

    // Second pass: categorize responses
    for (const response of responses) {
      const qId = response.question_id;
      const dayNum = response.day_number ?? 1;

      // Check if sleep log question
      const isSleepLog = SLEEP_LOG_PREFIXES.some(p => qId.startsWith(p));
      if (isSleepLog) {
        if (!sleepLogQuestionsByDay[dayNum]) {
          sleepLogQuestionsByDay[dayNum] = new Set();
        }
        sleepLogQuestionsByDay[dayNum].add(qId);
        continue;
      }

      // Check if core assessment question that uses a standardized prefix (e.g., PSQI_1)
      // These are answered during Days 1-5 and should count as core assessment, not expansion
      if (CORE_ASSESSMENT_WITH_PREFIXES.has(qId)) {
        coreQuestions.add(qId);
        // Also track that this core question contributes to an expansion module
        const mappings = CORE_TO_EXPANSION_MAPPING.filter(m => m.coreQuestionId === qId);
        for (const mapping of mappings) {
          coreContributionsByModule[mapping.expansionModuleId].add(qId);
        }
        continue;
      }

      // Check if expansion question (with explicit prefix like ISI_, PHQ9_, etc.)
      let isExpansionPrefixed = false;
      for (const module of EXPANSION_MODULES) {
        if (qId.startsWith(module.prefix)) {
          expansionQuestionsByModule[module.id].add(qId);
          isExpansionPrefixed = true;
          break;
        }
      }

      // If not expansion-prefixed, it's a core question
      // But also check if it maps to an expansion module
      if (!isExpansionPrefixed) {
        coreQuestions.add(qId);

        // Check if this core question contributes to any expansion module
        const mappings = CORE_TO_EXPANSION_MAPPING.filter(m => m.coreQuestionId === qId);
        for (const mapping of mappings) {
          coreContributionsByModule[mapping.expansionModuleId].add(qId);
        }
      }
    }

    // Calculate sleep log completion (days with >= 5 questions answered)
    // Core CSD questions: INTO_BED, TRY_SLEEP, LATENCY, AWAKENINGS, FINAL_WAKE, OUT_BED, QUALITY, REFRESHED
    // Not all are required (some conditional), so 5 is a reasonable minimum
    const sleepLogDaysCompleted = Object.values(sleepLogQuestionsByDay)
      .filter(questions => questions.size >= 5).length;
    const totalSleepLogQuestions = Object.values(sleepLogQuestionsByDay)
      .reduce((sum, qs) => sum + qs.size, 0);

    // Calculate core assessment completion
    const coreQuestionsAnswered = coreQuestions.size;
    const coreRate = CORE_EXPECTED_QUESTIONS > 0
      ? Math.min(100, Math.round((coreQuestionsAnswered / CORE_EXPECTED_QUESTIONS) * 100))
      : 0;

    // Calculate expansion packs completion
    // Only count modules that were triggered by gateways
    const triggeredModules = EXPANSION_MODULES.filter(m =>
      m.gateways.some(g => triggeredGateways.includes(g))
    );

    let expansionQuestionsAnswered = 0;
    let expansionTotalQuestions = 0;

    const moduleProgress = triggeredModules.map(m => {
      const fromExpansion = expansionQuestionsByModule[m.id].size;
      const fromCore = coreContributionsByModule[m.id].size;
      const totalAnswered = fromExpansion + fromCore;

      expansionQuestionsAnswered += totalAnswered;
      expansionTotalQuestions += m.questions;

      const completionPercentage = Math.min(100, Math.round((totalAnswered / m.questions) * 100));

      return {
        id: m.id,
        name: m.name,
        questionsAnswered: totalAnswered,
        questionsFromCore: fromCore,
        questionsFromExpansion: fromExpansion,
        totalQuestions: m.questions,
        completed: totalAnswered >= m.questions,
        completionPercentage,
      };
    });

    const expansionRate = expansionTotalQuestions > 0
      ? Math.min(100, Math.round((expansionQuestionsAnswered / expansionTotalQuestions) * 100))
      : 100; // 100% if no expansion packs triggered (nothing to do)

    // Calculate overall completion
    const sleepLogRate = Math.round((sleepLogDaysCompleted / TOTAL_JOURNEY_DAYS) * 100);

    // Overall = weighted average considering all components
    // Sleep log weight: 30%, Core: 40%, Expansion: 30% (if triggered, else split between others)
    let overallRate: number;
    if (triggeredModules.length > 0) {
      overallRate = Math.round((sleepLogRate * 0.3) + (coreRate * 0.4) + (expansionRate * 0.3));
    } else {
      // No expansion packs - just sleep log and core
      overallRate = Math.round((sleepLogRate * 0.4) + (coreRate * 0.6));
    }

    const totalQuestionsAnswered = totalSleepLogQuestions + coreQuestionsAnswered + expansionQuestionsAnswered;
    const totalQuestionsExpected = (TOTAL_JOURNEY_DAYS * SLEEP_LOG_QUESTIONS_PER_DAY) + CORE_EXPECTED_QUESTIONS + expansionTotalQuestions;

    return {
      sleepLog: {
        daysCompleted: sleepLogDaysCompleted,
        totalDays: TOTAL_JOURNEY_DAYS,
        rate: sleepLogRate,
        questionsAnswered: totalSleepLogQuestions,
      },
      coreAssessment: {
        questionsAnswered: coreQuestionsAnswered,
        totalQuestions: CORE_EXPECTED_QUESTIONS,
        rate: coreRate,
      },
      expansionPacks: {
        triggered: triggeredModules.length > 0,
        triggeredGateways,
        questionsAnswered: expansionQuestionsAnswered,
        totalQuestions: expansionTotalQuestions,
        rate: expansionRate,
        modules: moduleProgress,
      },
      overall: {
        rate: overallRate,
        totalQuestionsAnswered,
        totalQuestionsExpected,
      },
    };
  },
});

// ============================================
// Pillar Detail Queries
// ============================================

/**
 * Get all questions and responses for a specific health pillar
 */
export const getPillarResponses = query({
  args: {
    userId: v.id("users"),
    pillarName: v.string(),
  },
  returns: v.object({
    questions: v.array(
      v.object({
        questionId: v.string(),
        questionText: v.string(),
        questionType: v.optional(v.string()),
        responseValue: v.optional(v.string()),
        responseNumber: v.optional(v.number()),
        dayNumber: v.optional(v.number()),
        answeredAt: v.optional(v.number()),
      })
    ),
    clinicalSummary: v.optional(
      v.object({
        interpretation: v.optional(v.string()),
        severity: v.optional(v.string()),
        score: v.optional(v.number()),
        maxScore: v.optional(v.number()),
      })
    ),
  }),
  handler: async (ctx, args) => {
    // Get all questions for this pillar from assessment_questions
    const allQuestions = await ctx.db.query("assessment_questions").collect();

    // Filter questions by pillar
    const pillarQuestions = allQuestions.filter(
      (q) => q.pillar === args.pillarName
    );

    // Get user responses
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Map questions to responses
    const questions = pillarQuestions.map((q) => {
      const response = responses.find((r) => r.question_id === q.question_id);
      return {
        questionId: q.question_id,
        questionText: q.question_text,
        questionType: q.question_type,
        responseValue: response?.response_value,
        responseNumber: response?.response_number,
        dayNumber: response?.day_number,
        answeredAt: response?.updated_at,
      };
    });

    // Get clinical summary if available (from questionnaire scores)
    let clinicalSummary:
      | {
          interpretation?: string;
          severity?: string;
          score?: number;
          maxScore?: number;
        }
      | undefined;

    // Map pillar names to questionnaire names for clinical scores
    const pillarToQuestionnaire: Record<string, string[]> = {
      "Mental Health": ["PHQ-9", "GAD-7", "DBAS-6"], // DBAS-6 maps to Mental Health
      "Sleep Quality": ["ISI", "PSQI"],
      Cognitive: ["PROMIS"], // Cognitive uses PROMIS
    };

    const relevantQuestionnaires = pillarToQuestionnaire[args.pillarName];
    if (relevantQuestionnaires) {
      const scores = await ctx.db
        .query("questionnaire_scores")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();

      const relevantScore = scores.find((s) =>
        relevantQuestionnaires.includes(s.questionnaire_name)
      );

      if (relevantScore) {
        clinicalSummary = {
          interpretation: relevantScore.interpretation,
          severity: relevantScore.category,
          score: relevantScore.score,
          maxScore: relevantScore.max_score,
        };
      }
    }

    return {
      questions,
      clinicalSummary,
    };
  },
});

/**
 * Get all questions and responses for a specific standardized questionnaire
 * (ISI, PHQ-9, GAD-7, ESS, STOP-BANG, etc.)
 */
export const getQuestionnaireResponses = query({
  args: {
    userId: v.id("users"),
    questionnaireName: v.string(),
  },
  returns: v.array(
    v.object({
      questionId: v.string(),
      questionText: v.string(),
      responseValue: v.string(),
      responseNumber: v.optional(v.number()),
      // Derived answer indicator - true if auto-populated from equivalent question
      isDerived: v.optional(v.boolean()),
      derivedFromQuestionId: v.optional(v.string()),
      // Response source: "user" (default), "profile" (from onboarding), "derived" (calculated), "healthkit"
      responseSource: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    // Hardcoded question texts for ALL standardized questionnaires
    const questionTexts: Record<string, string> = {
      // ISI - Insomnia Severity Index (7 questions, 0-4 scale)
      "ISI_1": "Difficulty falling asleep?",
      "ISI_2": "Difficulty staying asleep?",
      "ISI_3": "Problems waking up too early?",
      "ISI_4": "How satisfied are you with your current sleep pattern?",
      "ISI_5": "How noticeable to others is your sleep problem affecting your daily functioning?",
      "ISI_6": "How worried are you about your current sleep problem?",
      "ISI_7": "How much is your sleep problem interfering with your daily functioning?",

      // PHQ-9 - Patient Health Questionnaire (9 questions, 0-3 scale)
      "PHQ9_1": "Over the last 2 weeks: Little interest or pleasure in doing things?",
      "PHQ9_2": "Over the last 2 weeks: Feeling down, depressed, or hopeless?",
      "PHQ9_3": "Over the last 2 weeks: Trouble falling or staying asleep, or sleeping too much?",
      "PHQ9_4": "Over the last 2 weeks: Feeling tired or having little energy?",
      "PHQ9_5": "Over the last 2 weeks: Poor appetite or overeating?",
      "PHQ9_6": "Over the last 2 weeks: Feeling bad about yourself - or that you are a failure?",
      "PHQ9_7": "Over the last 2 weeks: Trouble concentrating on things?",
      "PHQ9_8": "Over the last 2 weeks: Moving or speaking slowly, or being fidgety/restless?",
      "PHQ9_9": "Over the last 2 weeks: Thoughts that you would be better off dead or of hurting yourself?",

      // GAD-7 - Generalized Anxiety Disorder (7 questions, 0-3 scale)
      "GAD7_1": "Over the last 2 weeks: Feeling nervous, anxious, or on edge?",
      "GAD7_2": "Over the last 2 weeks: Not being able to stop or control worrying?",
      "GAD7_3": "Over the last 2 weeks: Worrying too much about different things?",
      "GAD7_4": "Over the last 2 weeks: Trouble relaxing?",
      "GAD7_5": "Over the last 2 weeks: Being so restless that it is hard to sit still?",
      "GAD7_6": "Over the last 2 weeks: Becoming easily annoyed or irritable?",
      "GAD7_7": "Over the last 2 weeks: Feeling afraid, as if something awful might happen?",

      // ESS - Epworth Sleepiness Scale (8 questions, 0-3 scale)
      "ESS_1": "Chance of dozing: Sitting and reading?",
      "ESS_2": "Chance of dozing: Watching TV?",
      "ESS_3": "Chance of dozing: Sitting inactive in a public place (theater/meeting)?",
      "ESS_4": "Chance of dozing: As a passenger in a car for an hour?",
      "ESS_5": "Chance of dozing: Lying down to rest in the afternoon?",
      "ESS_6": "Chance of dozing: Sitting and talking to someone?",
      "ESS_7": "Chance of dozing: Sitting quietly after lunch without alcohol?",
      "ESS_8": "Chance of dozing: In a car while stopped for a few minutes in traffic?",

      // STOP-BANG - Sleep Apnea Screening (8 yes/no questions)
      "SB_1": "Do you snore loudly (loud enough to be heard through closed doors)?",
      "SB_2": "Do you often feel tired, fatigued, or sleepy during the daytime?",
      "SB_3": "Has anyone observed you stop breathing or choking/gasping during your sleep?",
      "SB_4": "Do you have or are you being treated for high blood pressure?",
      "SB_5": "Is your BMI more than 35 kg/m²?",
      "SB_6": "Are you older than 50 years old?",
      "SB_7": "Is your neck circumference greater than 40 cm (16 inches)?",
      "SB_8": "Are you male?",

      // PSQI - Pittsburgh Sleep Quality Index (19 questions)
      "PSQI_1": "What time have you usually gone to bed?",
      "PSQI_2": "How long (in minutes) has it taken you to fall asleep each night?",
      "PSQI_3": "What time have you usually gotten up in the morning?",
      "PSQI_4": "How many hours of actual sleep did you get at night?",
      "PSQI_5a": "Cannot get to sleep within 30 minutes?",
      "PSQI_5b": "Wake up in the middle of the night or early morning?",
      "PSQI_5c": "Have to get up to use the bathroom?",
      "PSQI_5d": "Cannot breathe comfortably?",
      "PSQI_5e": "Cough or snore loudly?",
      "PSQI_5f": "Feel too cold?",
      "PSQI_5g": "Feel too hot?",
      "PSQI_5h": "Have bad dreams?",
      "PSQI_5i": "Have pain?",
      "PSQI_5j": "Other reasons (describe)?",
      "PSQI_6": "How would you rate your sleep quality overall?",
      "PSQI_7": "How often have you taken medicine to help you sleep?",
      "PSQI_8": "How often have you had trouble staying awake during activities?",
      "PSQI_9": "How much of a problem has it been to keep up enthusiasm to get things done?",

      // DBAS-16 - Dysfunctional Beliefs and Attitudes about Sleep (16 questions, 0-10 scale)
      "DBAS_1": "I need 8 hours of sleep to feel refreshed and function well during the day.",
      "DBAS_2": "When I don't get proper sleep, I need to catch up the next day by napping or sleeping longer.",
      "DBAS_3": "I am concerned that chronic insomnia may have serious consequences on my physical health.",
      "DBAS_4": "I am worried that I may lose control over my ability to sleep.",
      "DBAS_5": "After a poor night's sleep, I know it will interfere with my daily activities.",
      "DBAS_6": "To be alert during the day, I believe I would be better off taking sleeping pills.",
      "DBAS_7": "When I feel irritable or depressed during the day, it is mostly because I did not sleep well.",
      "DBAS_8": "When I sleep poorly one night, I know it will disturb my sleep schedule for the whole week.",
      "DBAS_9": "Without adequate sleep, I can hardly function the next day.",
      "DBAS_10": "I can't ever predict whether I'll have a good or poor night's sleep.",
      "DBAS_11": "I have little ability to manage the negative consequences of disturbed sleep.",
      "DBAS_12": "When I feel tired or lack energy during the day, it's generally because I didn't sleep well.",
      "DBAS_13": "I believe insomnia is essentially the result of a chemical imbalance.",
      "DBAS_14": "I feel insomnia is ruining my ability to enjoy life.",
      "DBAS_15": "Medication is probably the only solution to sleeplessness.",
      "DBAS_16": "I avoid scheduling important things in the morning after a poor night's sleep.",

      // Berlin Questionnaire (10 questions)
      "BERLIN_1": "Do you snore?",
      "BERLIN_2": "Your snoring is: Slightly louder than breathing / As loud as talking / Louder than talking / Very loud",
      "BERLIN_3": "How often do you snore?",
      "BERLIN_4": "Has your snoring ever bothered other people?",
      "BERLIN_5": "Has anyone noticed that you quit breathing during your sleep?",
      "BERLIN_6": "How often do you feel tired after sleeping?",
      "BERLIN_7": "During your waking time, do you feel tired, fatigued, or not up to par?",
      "BERLIN_8": "Have you ever nodded off or fallen asleep while driving a vehicle?",
      "BERLIN_9": "How often does this occur?",
      "BERLIN_10": "Do you have high blood pressure?",

      // FSS - Fatigue Severity Scale (9 questions, 1-7 scale)
      "FSS_1": "My motivation is lower when I am fatigued.",
      "FSS_2": "Exercise brings on my fatigue.",
      "FSS_3": "I am easily fatigued.",
      "FSS_4": "Fatigue interferes with my physical functioning.",
      "FSS_5": "Fatigue causes frequent problems for me.",
      "FSS_6": "My fatigue prevents sustained physical functioning.",
      "FSS_7": "Fatigue interferes with carrying out certain duties and responsibilities.",
      "FSS_8": "Fatigue is among my three most disabling symptoms.",
      "FSS_9": "Fatigue interferes with my work, family, or social life.",

      // FOSQ-10 - Functional Outcomes of Sleep (10 questions, 1-4 scale)
      "FOSQ_1": "Difficulty concentrating on things you do?",
      "FOSQ_2": "Difficulty remembering things?",
      "FOSQ_3": "Difficulty finishing a meal?",
      "FOSQ_4": "Difficulty working on a hobby?",
      "FOSQ_5": "Difficulty doing work requiring manual dexterity?",
      "FOSQ_6": "Difficulty visiting with family or friends in their home?",
      "FOSQ_7": "Difficulty doing household chores?",
      "FOSQ_8": "Difficulty operating a motor vehicle for short distances?",
      "FOSQ_9": "Difficulty being as active as you want in the evening?",
      "FOSQ_10": "Difficulty being as active as you want in the afternoon?",

      // DASS-21 - Depression Anxiety Stress Scales (21 questions, 0-3 scale)
      "DASS_1": "I found it hard to wind down.",
      "DASS_2": "I was aware of dryness of my mouth.",
      "DASS_3": "I couldn't seem to experience any positive feeling at all.",
      "DASS_4": "I experienced breathing difficulty.",
      "DASS_5": "I found it difficult to work up the initiative to do things.",
      "DASS_6": "I tended to over-react to situations.",
      "DASS_7": "I experienced trembling (e.g., in the hands).",
      "DASS_8": "I felt that I was using a lot of nervous energy.",
      "DASS_9": "I was worried about situations in which I might panic.",
      "DASS_10": "I felt that I had nothing to look forward to.",
      "DASS_11": "I found myself getting agitated.",
      "DASS_12": "I found it difficult to relax.",
      "DASS_13": "I felt down-hearted and blue.",
      "DASS_14": "I was intolerant of anything that kept me from getting on with what I was doing.",
      "DASS_15": "I felt I was close to panic.",
      "DASS_16": "I was unable to become enthusiastic about anything.",
      "DASS_17": "I felt I wasn't worth much as a person.",
      "DASS_18": "I felt that I was rather touchy.",
      "DASS_19": "I was aware of the action of my heart in the absence of physical exertion.",
      "DASS_20": "I felt scared without any good reason.",
      "DASS_21": "I felt that life was meaningless.",

      // BPI - Brief Pain Inventory (11 questions, 0-10 scale)
      "BPI_1": "Rate your pain at its worst in the last 24 hours.",
      "BPI_2": "Rate your pain at its least in the last 24 hours.",
      "BPI_3": "Rate your pain on average.",
      "BPI_4": "Rate your pain right now.",
      "BPI_5": "How much has pain interfered with your general activity?",
      "BPI_6": "How much has pain interfered with your mood?",
      "BPI_7": "How much has pain interfered with your walking ability?",
      "BPI_8": "How much has pain interfered with your normal work?",
      "BPI_9": "How much has pain interfered with your relations with other people?",
      "BPI_10": "How much has pain interfered with your sleep?",
      "BPI_11": "How much has pain interfered with your enjoyment of life?",

      // MEDAS - Mediterranean Diet Adherence Screener (14 yes/no questions)
      "MEDAS_1": "Do you use olive oil as the main culinary fat?",
      "MEDAS_2": "How much olive oil do you consume in a given day? (≥4 tablespoons)",
      "MEDAS_3": "How many vegetable servings do you consume per day? (≥2)",
      "MEDAS_4": "How many fruit units do you consume per day? (≥3)",
      "MEDAS_5": "How many servings of red meat do you consume per day? (<1)",
      "MEDAS_6": "How many servings of butter/margarine do you consume per day? (<1)",
      "MEDAS_7": "How many sweet/carbonated beverages do you drink per day? (<1)",
      "MEDAS_8": "How much wine do you drink per week? (≥7 glasses)",
      "MEDAS_9": "How many servings of legumes do you consume per week? (≥3)",
      "MEDAS_10": "How many servings of fish/shellfish do you consume per week? (≥3)",
      "MEDAS_11": "How many times per week do you consume pastries? (<3)",
      "MEDAS_12": "How many servings of nuts do you consume per week? (≥3)",
      "MEDAS_13": "Do you prefer chicken, turkey, or rabbit instead of beef, pork, or sausages?",
      "MEDAS_14": "How many times per week do you eat vegetables, pasta, rice with sofrito sauce? (≥2)",

      // MEQ - Morningness-Eveningness Questionnaire (19 questions, various scales)
      "MEQ_1": "What time would you get up if you were entirely free to plan your day?",
      "MEQ_2": "What time would you go to bed if you were entirely free to plan your evening?",
      "MEQ_3": "How dependent are you on an alarm clock?",
      "MEQ_4": "How easy do you find it to get up in the morning?",
      "MEQ_5": "How alert do you feel during the first half hour after waking?",
      "MEQ_6": "How hungry do you feel during the first half hour after waking?",
      "MEQ_7": "How tired do you feel during the first half hour after waking?",
      "MEQ_8": "When you have no commitments the next day, what time do you go to bed?",
      "MEQ_9": "You have decided to do physical exercise. When would you choose?",
      "MEQ_10": "At what time in the evening do you feel tired?",
      "MEQ_11": "You have to do a two-hour mentally exhausting test. When would you schedule it?",
      "MEQ_12": "If you went to bed at 11 PM, how tired would you be?",
      "MEQ_13": "You have to wake up at 6 AM. How would you feel?",
      "MEQ_14": "You have to stay awake from 4-6 AM. When would you sleep?",
      "MEQ_15": "You have to do 2 hours of hard physical work. When would you schedule it?",
      "MEQ_16": "You have decided to do physical exercise. When would you perform at best?",
      "MEQ_17": "Suppose you can choose your working hours. What 5 hours would you pick?",
      "MEQ_18": "At what time of day do you feel your best?",
      "MEQ_19": "Do you think of yourself as a morning or evening person?",

      // PROMIS Cognitive Function (6 questions, 1-5 scale)
      "PROMIS_COG_1": "My thinking has been slow.",
      "PROMIS_COG_2": "It has seemed like my brain was not working as well as usual.",
      "PROMIS_COG_3": "I have had to work harder than usual to keep track of what I was doing.",
      "PROMIS_COG_4": "I have had trouble shifting back and forth between different activities.",
      "PROMIS_COG_5": "I have had trouble concentrating.",
      "PROMIS_COG_6": "My thinking has been foggy.",

      // Sleep Hygiene Index (10 questions, 1-5 scale)
      "SH_1": "I go to bed at different times from day to day.",
      "SH_2": "I use alcohol, tobacco, or caffeine within 4 hours of going to bed.",
      "SH_3": "I do something that may wake me up before bedtime (e.g., exercise, video games).",
      "SH_4": "I stay in bed although I am awake.",
      "SH_5": "I use my bed for things other than sleeping or sex.",
      "SH_6": "I sleep in an uncomfortable bedroom (e.g., too bright, too stuffy, too hot).",
      "SH_7": "I do important work before bedtime.",
      "SH_8": "I think, plan, or worry when I am in bed.",
      "SH_9": "I have an irregular morning rising time.",
      "SH_10": "I take daytime naps lasting 2 or more hours.",

      // PSAS - Pre-Sleep Arousal Scale (16 questions, 1-5 scale)
      // Cognitive subscale
      "PSAS_C1": "Worry about falling asleep.",
      "PSAS_C2": "Review or ponder events of the day.",
      "PSAS_C3": "Depressing or anxious thoughts.",
      "PSAS_C4": "Worry about problems other than sleep.",
      "PSAS_C5": "Being mentally alert, active.",
      "PSAS_C6": "Can't shut off your thoughts.",
      "PSAS_C7": "Thoughts keep running through your head.",
      "PSAS_C8": "Being distracted by sounds, etc. in the environment.",
      // Somatic subscale
      "PSAS_S1": "Heart racing, pounding, or beating irregularly.",
      "PSAS_S2": "A jittery, nervous feeling in your body.",
      "PSAS_S3": "Shortness of breath or labored breathing.",
      "PSAS_S4": "A tight, tense feeling in your muscles.",
      "PSAS_S5": "Cold feeling in your hands, feet, or body.",
      "PSAS_S6": "Have stomach upset (knot in stomach, heartburn, nausea).",
      "PSAS_S7": "Perspiration in palms of hands or other parts of body.",
      "PSAS_S8": "Dry feeling in mouth or throat.",
    };

    // Map questionnaire names to specific question IDs
    const questionnaireToQuestionIds: Record<string, string[]> = {
      // ISI - Insomnia Severity Index
      "ISI": ["ISI_1", "ISI_2", "ISI_3", "ISI_4", "ISI_5", "ISI_6", "ISI_7"],
      "Insomnia Severity Index": ["ISI_1", "ISI_2", "ISI_3", "ISI_4", "ISI_5", "ISI_6", "ISI_7"],

      // PHQ-9 - Patient Health Questionnaire
      "PHQ-9": ["PHQ9_1", "PHQ9_2", "PHQ9_3", "PHQ9_4", "PHQ9_5", "PHQ9_6", "PHQ9_7", "PHQ9_8", "PHQ9_9"],
      "Patient Health Questionnaire": ["PHQ9_1", "PHQ9_2", "PHQ9_3", "PHQ9_4", "PHQ9_5", "PHQ9_6", "PHQ9_7", "PHQ9_8", "PHQ9_9"],

      // GAD-7 - Generalized Anxiety Disorder
      "GAD-7": ["GAD7_1", "GAD7_2", "GAD7_3", "GAD7_4", "GAD7_5", "GAD7_6", "GAD7_7"],
      "Generalized Anxiety Disorder": ["GAD7_1", "GAD7_2", "GAD7_3", "GAD7_4", "GAD7_5", "GAD7_6", "GAD7_7"],

      // ESS - Epworth Sleepiness Scale
      "ESS": ["ESS_1", "ESS_2", "ESS_3", "ESS_4", "ESS_5", "ESS_6", "ESS_7", "ESS_8"],
      "Epworth Sleepiness Scale": ["ESS_1", "ESS_2", "ESS_3", "ESS_4", "ESS_5", "ESS_6", "ESS_7", "ESS_8"],

      // STOP-BANG - Sleep Apnea Screening
      "STOP-BANG": ["SB_1", "SB_2", "SB_3", "SB_4", "SB_5", "SB_6", "SB_7", "SB_8"],
      "STOP-BANG Sleep Apnea Screening": ["SB_1", "SB_2", "SB_3", "SB_4", "SB_5", "SB_6", "SB_7", "SB_8"],

      // PSQI - Pittsburgh Sleep Quality Index
      "PSQI": ["PSQI_1", "PSQI_2", "PSQI_3", "PSQI_4", "PSQI_5a", "PSQI_5b", "PSQI_5c", "PSQI_5d", "PSQI_5e", "PSQI_5f", "PSQI_5g", "PSQI_5h", "PSQI_5i", "PSQI_5j", "PSQI_6", "PSQI_7", "PSQI_8", "PSQI_9"],
      "Pittsburgh Sleep Quality Index": ["PSQI_1", "PSQI_2", "PSQI_3", "PSQI_4", "PSQI_5a", "PSQI_5b", "PSQI_5c", "PSQI_5d", "PSQI_5e", "PSQI_5f", "PSQI_5g", "PSQI_5h", "PSQI_5i", "PSQI_5j", "PSQI_6", "PSQI_7", "PSQI_8", "PSQI_9"],

      // DBAS-16 - Dysfunctional Beliefs and Attitudes about Sleep
      "DBAS-16": ["DBAS_1", "DBAS_2", "DBAS_3", "DBAS_4", "DBAS_5", "DBAS_6", "DBAS_7", "DBAS_8", "DBAS_9", "DBAS_10", "DBAS_11", "DBAS_12", "DBAS_13", "DBAS_14", "DBAS_15", "DBAS_16"],
      "Dysfunctional Beliefs and Attitudes about Sleep": ["DBAS_1", "DBAS_2", "DBAS_3", "DBAS_4", "DBAS_5", "DBAS_6", "DBAS_7", "DBAS_8", "DBAS_9", "DBAS_10", "DBAS_11", "DBAS_12", "DBAS_13", "DBAS_14", "DBAS_15", "DBAS_16"],

      // Berlin Questionnaire
      "Berlin": ["BERLIN_1", "BERLIN_2", "BERLIN_3", "BERLIN_4", "BERLIN_5", "BERLIN_6", "BERLIN_7", "BERLIN_8", "BERLIN_9", "BERLIN_10"],
      "Berlin Questionnaire": ["BERLIN_1", "BERLIN_2", "BERLIN_3", "BERLIN_4", "BERLIN_5", "BERLIN_6", "BERLIN_7", "BERLIN_8", "BERLIN_9", "BERLIN_10"],

      // FSS - Fatigue Severity Scale
      "FSS": ["FSS_1", "FSS_2", "FSS_3", "FSS_4", "FSS_5", "FSS_6", "FSS_7", "FSS_8", "FSS_9"],
      "Fatigue Severity Scale": ["FSS_1", "FSS_2", "FSS_3", "FSS_4", "FSS_5", "FSS_6", "FSS_7", "FSS_8", "FSS_9"],

      // FOSQ-10 - Functional Outcomes of Sleep Questionnaire
      "FOSQ-10": ["FOSQ_1", "FOSQ_2", "FOSQ_3", "FOSQ_4", "FOSQ_5", "FOSQ_6", "FOSQ_7", "FOSQ_8", "FOSQ_9", "FOSQ_10"],
      "Functional Outcomes of Sleep Questionnaire": ["FOSQ_1", "FOSQ_2", "FOSQ_3", "FOSQ_4", "FOSQ_5", "FOSQ_6", "FOSQ_7", "FOSQ_8", "FOSQ_9", "FOSQ_10"],

      // DASS-21 subscales
      "DASS-D": ["DASS_3", "DASS_5", "DASS_10", "DASS_13", "DASS_16", "DASS_17", "DASS_21"],
      "DASS-21 Depression": ["DASS_3", "DASS_5", "DASS_10", "DASS_13", "DASS_16", "DASS_17", "DASS_21"],
      "DASS-A": ["DASS_2", "DASS_4", "DASS_7", "DASS_9", "DASS_15", "DASS_19", "DASS_20"],
      "DASS-21 Anxiety": ["DASS_2", "DASS_4", "DASS_7", "DASS_9", "DASS_15", "DASS_19", "DASS_20"],
      "DASS-S": ["DASS_1", "DASS_6", "DASS_8", "DASS_11", "DASS_12", "DASS_14", "DASS_18"],
      "DASS-21 Stress": ["DASS_1", "DASS_6", "DASS_8", "DASS_11", "DASS_12", "DASS_14", "DASS_18"],

      // BPI - Brief Pain Inventory subscales
      "BPI-S": ["BPI_1", "BPI_2", "BPI_3", "BPI_4"],
      "Brief Pain Inventory - Severity": ["BPI_1", "BPI_2", "BPI_3", "BPI_4"],
      "BPI-I": ["BPI_5", "BPI_6", "BPI_7", "BPI_8", "BPI_9", "BPI_10", "BPI_11"],
      "Brief Pain Inventory - Interference": ["BPI_5", "BPI_6", "BPI_7", "BPI_8", "BPI_9", "BPI_10", "BPI_11"],

      // MEDAS - Mediterranean Diet Adherence Screener
      "MEDAS": ["MEDAS_1", "MEDAS_2", "MEDAS_3", "MEDAS_4", "MEDAS_5", "MEDAS_6", "MEDAS_7", "MEDAS_8", "MEDAS_9", "MEDAS_10", "MEDAS_11", "MEDAS_12", "MEDAS_13", "MEDAS_14"],
      "Mediterranean Diet Adherence Screener": ["MEDAS_1", "MEDAS_2", "MEDAS_3", "MEDAS_4", "MEDAS_5", "MEDAS_6", "MEDAS_7", "MEDAS_8", "MEDAS_9", "MEDAS_10", "MEDAS_11", "MEDAS_12", "MEDAS_13", "MEDAS_14"],

      // MEQ - Morningness-Eveningness Questionnaire
      "MEQ": ["MEQ_1", "MEQ_2", "MEQ_3", "MEQ_4", "MEQ_5", "MEQ_6", "MEQ_7", "MEQ_8", "MEQ_9", "MEQ_10", "MEQ_11", "MEQ_12", "MEQ_13", "MEQ_14", "MEQ_15", "MEQ_16", "MEQ_17", "MEQ_18", "MEQ_19"],
      "Morningness-Eveningness Questionnaire": ["MEQ_1", "MEQ_2", "MEQ_3", "MEQ_4", "MEQ_5", "MEQ_6", "MEQ_7", "MEQ_8", "MEQ_9", "MEQ_10", "MEQ_11", "MEQ_12", "MEQ_13", "MEQ_14", "MEQ_15", "MEQ_16", "MEQ_17", "MEQ_18", "MEQ_19"],

      // PROMIS Cognitive Function
      "PROMIS-Cog": ["PROMIS_COG_1", "PROMIS_COG_2", "PROMIS_COG_3", "PROMIS_COG_4", "PROMIS_COG_5", "PROMIS_COG_6"],
      "PROMIS Cognitive Function": ["PROMIS_COG_1", "PROMIS_COG_2", "PROMIS_COG_3", "PROMIS_COG_4", "PROMIS_COG_5", "PROMIS_COG_6"],

      // Sleep Hygiene Index
      "SHI": ["SH_1", "SH_2", "SH_3", "SH_4", "SH_5", "SH_6", "SH_7", "SH_8", "SH_9", "SH_10"],
      "Sleep Hygiene Index": ["SH_1", "SH_2", "SH_3", "SH_4", "SH_5", "SH_6", "SH_7", "SH_8", "SH_9", "SH_10"],

      // PSAS - Pre-Sleep Arousal Scale subscales
      "PSAS-C": ["PSAS_C1", "PSAS_C2", "PSAS_C3", "PSAS_C4", "PSAS_C5", "PSAS_C6", "PSAS_C7", "PSAS_C8"],
      "Pre-Sleep Arousal - Cognitive": ["PSAS_C1", "PSAS_C2", "PSAS_C3", "PSAS_C4", "PSAS_C5", "PSAS_C6", "PSAS_C7", "PSAS_C8"],
      "PSAS-S": ["PSAS_S1", "PSAS_S2", "PSAS_S3", "PSAS_S4", "PSAS_S5", "PSAS_S6", "PSAS_S7", "PSAS_S8"],
      "Pre-Sleep Arousal - Somatic": ["PSAS_S1", "PSAS_S2", "PSAS_S3", "PSAS_S4", "PSAS_S5", "PSAS_S6", "PSAS_S7", "PSAS_S8"],
    };

    const questionIds = questionnaireToQuestionIds[args.questionnaireName];

    if (!questionIds || questionIds.length === 0) {
      return [];
    }

    // Get user responses
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Map specified question IDs to responses
    const result: Array<{
      questionId: string;
      questionText: string;
      responseValue: string;
      responseNumber?: number;
      isDerived?: boolean;
      derivedFromQuestionId?: string;
      responseSource?: string;
    }> = [];

    for (const qId of questionIds) {
      const response = responses.find((r) => r.question_id === qId);
      if (response && (response.response_value || response.response_number !== undefined)) {
        result.push({
          questionId: qId,
          questionText: questionTexts[qId] || `Question ${qId}`,
          responseValue: response.response_value || String(response.response_number ?? ""),
          responseNumber: response.response_number,
          isDerived: response.is_derived ?? false,
          derivedFromQuestionId: response.derived_from_question_id,
          responseSource: response.response_source,
        });
      }
    }

    return result;
  },
});

// ============================================
// Mutations
// ============================================

/**
 * Save or update a physician note
 */
export const savePhysicianNote = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.optional(v.number()),
    noteText: v.string(),
    physicianId: v.optional(v.string()),
  },
  returns: v.id("physician_notes"),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if note exists for this user and day
    const existingQuery = ctx.db
      .query("physician_notes")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      );

    const existing = await existingQuery.first();

    if (existing) {
      // Update existing note
      await ctx.db.patch(existing._id, {
        note_text: args.noteText,
        updated_at: now,
        physician_id: args.physicianId,
      });
      return existing._id;
    } else {
      // Create new note
      const noteId = await ctx.db.insert("physician_notes", {
        user_id: args.userId,
        day_number: args.dayNumber,
        note_text: args.noteText,
        created_at: now,
        updated_at: now,
        physician_id: args.physicianId,
      });
      return noteId;
    }
  },
});

/**
 * Update patient review status
 */
export const updatePatientReviewStatus = mutation({
  args: {
    userId: v.id("users"),
    status: v.string(),
    physicianId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const existing = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (existing) {
      // Update existing status
      const updates: any = {
        status: args.status,
        updated_at: now,
      };

      if (args.physicianId) {
        updates.reviewed_by_physician_id = args.physicianId;
      }

      // Set timestamps based on status
      if (args.status === "under_review" && !existing.review_started_at) {
        updates.review_started_at = now;
      }
      if (
        args.status === "interventions_prepared" &&
        !existing.review_completed_at
      ) {
        updates.review_completed_at = now;
      }

      await ctx.db.patch(existing._id, updates);
    } else {
      // Create new status
      const data: any = {
        user_id: args.userId,
        status: args.status,
        updated_at: now,
      };

      if (args.physicianId) {
        data.reviewed_by_physician_id = args.physicianId;
      }

      if (args.status === "under_review") {
        data.review_started_at = now;
      }

      await ctx.db.insert("patient_review_status", data);
    }

    return null;
  },
});

/**
 * Save a calculated questionnaire score
 */
export const saveQuestionnaireScore = mutation({
  args: {
    userId: v.id("users"),
    questionnaireName: v.string(),
    score: v.number(),
    maxScore: v.optional(v.number()),
    category: v.optional(v.string()),
    interpretation: v.optional(v.string()),
    calculationMetadata: v.optional(v.string()),
  },
  returns: v.id("questionnaire_scores"),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if score already exists for this questionnaire
    const existing = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user_questionnaire", (q) =>
        q.eq("user_id", args.userId).eq("questionnaire_name", args.questionnaireName)
      )
      .first();

    if (existing) {
      // Update existing score
      await ctx.db.patch(existing._id, {
        score: args.score,
        max_score: args.maxScore,
        category: args.category,
        interpretation: args.interpretation,
        calculated_at: now,
        calculation_metadata_json: args.calculationMetadata,
      });
      return existing._id;
    } else {
      // Create new score
      const scoreId = await ctx.db.insert("questionnaire_scores", {
        user_id: args.userId,
        questionnaire_name: args.questionnaireName,
        score: args.score,
        max_score: args.maxScore,
        category: args.category,
        interpretation: args.interpretation,
        calculated_at: now,
        calculation_metadata_json: args.calculationMetadata,
      });
      return scoreId;
    }
  },
});

/**
 * Update patient visible fields configuration
 */
export const updatePatientVisibleFields = mutation({
  args: {
    userId: v.id("users"),
    fieldConfig: v.string(), // JSON string
    physicianId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const existing = await ctx.db
      .query("patient_visible_fields")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        field_config_json: args.fieldConfig,
        updated_at: now,
        updated_by_physician_id: args.physicianId,
      });
    } else {
      await ctx.db.insert("patient_visible_fields", {
        user_id: args.userId,
        field_config_json: args.fieldConfig,
        updated_at: now,
        updated_by_physician_id: args.physicianId,
      });
    }

    return null;
  },
});

/**
 * Create a new intervention for a patient
 */
export const createInterventionForPatient = mutation({
  args: {
    userId: v.id("users"),
    interventionId: v.id("interventions"),
    startDate: v.string(),
    endDate: v.optional(v.string()),
    frequency: v.optional(v.string()),
    dosage: v.optional(v.string()),
    timing: v.optional(v.string()),
    customInstructions: v.optional(v.string()),
    physicianId: v.optional(v.string()),
  },
  returns: v.id("user_interventions"),
  handler: async (ctx, args) => {
    const now = Date.now();

    const userInterventionId = await ctx.db.insert("user_interventions", {
      user_id: args.userId,
      intervention_id: args.interventionId,
      assigned_by_coach_id: args.physicianId
        ? (args.physicianId as any)
        : undefined,
      start_date: args.startDate,
      end_date: args.endDate,
      frequency: args.frequency,
      dosage: args.dosage,
      timing: args.timing,
      custom_instructions: args.customInstructions,
      status: "draft", // Start as draft until activated
      assigned_at: now,
    });

    return userInterventionId;
  },
});

/**
 * Activate interventions for a patient
 */
export const activateInterventions = mutation({
  args: {
    userId: v.id("users"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    // Get all draft interventions for this user
    const draftInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "draft")
      )
      .collect();

    // Activate each one
    for (const intervention of draftInterventions) {
      await ctx.db.patch(intervention._id, {
        status: "active",
      });
    }

    // Update patient review status to interventions_active
    await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first()
      .then(async (status) => {
        if (status) {
          await ctx.db.patch(status._id, {
            status: "interventions_active",
            updated_at: Date.now(),
          });
        }
      });

    return null;
  },
});

/**
 * Delete a physician note
 */
export const deletePhysicianNote = mutation({
  args: {
    noteId: v.id("physician_notes"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.delete(args.noteId);
    return null;
  },
});

/**
 * Update an existing user intervention
 */
export const updateUserIntervention = mutation({
  args: {
    interventionId: v.id("user_interventions"),
    updates: v.object({
      start_date: v.optional(v.string()),
      end_date: v.optional(v.string()),
      frequency: v.optional(v.string()),
      dosage: v.optional(v.string()),
      timing: v.optional(v.string()),
      custom_instructions: v.optional(v.string()),
      status: v.optional(v.string()),
    }),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.patch(args.interventionId, args.updates);
    return null;
  },
});

/**
 * Delete a user intervention
 */
export const deleteUserIntervention = mutation({
  args: {
    interventionId: v.id("user_interventions"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.delete(args.interventionId);
    return null;
  },
});

// ============================================
// Dynamic Questionnaire Scoring
// ============================================

/**
 * Calculate all questionnaire scores dynamically from patient responses
 * This includes ISI, PHQ-9, GAD-7, ESS, STOP-BANG, and gateway analysis
 */
export const calculatePatientScores = query({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()),
  },
  returns: v.object({
    scores: v.array(
      v.object({
        name: v.string(),
        abbreviation: v.string(),
        score: v.union(v.number(), v.null()),
        maxScore: v.number(),
        interpretation: v.string(),
        severity: v.string(),
        questionsAnswered: v.number(),
        questionsRequired: v.number(),
      })
    ),
    sleepMetrics: v.object({
      avgBedtime: v.optional(v.string()),
      avgWakeTime: v.optional(v.string()),
      avgSleepQuality: v.optional(v.number()),
      avgAwakenings: v.optional(v.number()),
      daysLogged: v.number(),
    }),
    gateways: v.object({
      insomnia: v.boolean(),
      depression: v.boolean(),
      anxiety: v.boolean(),
      sleepApnea: v.boolean(),
      excessiveSleepiness: v.boolean(),
      pain: v.boolean(),
      prostate: v.boolean(),
    }),
  }),
  handler: async (ctx, args) => {
    // Validate physician role if session token provided
    if (args.sessionToken) {
      const session = await validatePhysicianRole(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized: Physician access required");
      }
    }

    // Get all responses for this user
    const allResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Build a map of question_id -> numeric value for scoring
    const responseMap = new Map<string, number>();
    const stringResponseMap = new Map<string, string>();

    for (const r of allResponses) {
      // Get numeric value
      if (r.response_number !== undefined && r.response_number !== null) {
        responseMap.set(r.question_id, r.response_number);
      } else if (r.response_value !== undefined) {
        // Try to parse as number
        const num = parseFloat(r.response_value);
        if (!isNaN(num)) {
          responseMap.set(r.question_id, num);
        }
        // Also map string values for yes/no questions
        const val = r.response_value.toLowerCase();
        if (val === "yes" || val === "true" || val === "1") {
          responseMap.set(r.question_id, 1);
        } else if (val === "no" || val === "false" || val === "0") {
          responseMap.set(r.question_id, 0);
        }
        // Map select index (0-based)
        if (val === "not at all") responseMap.set(r.question_id, 0);
        else if (val === "several days") responseMap.set(r.question_id, 1);
        else if (val === "more than half the days") responseMap.set(r.question_id, 2);
        else if (val === "nearly every day") responseMap.set(r.question_id, 3);
        // ESS/other scale options
        else if (val === "never") responseMap.set(r.question_id, 0);
        else if (val === "rarely") responseMap.set(r.question_id, 1);
        else if (val === "sometimes") responseMap.set(r.question_id, 2);
        else if (val === "often") responseMap.set(r.question_id, 3);
        else if (val === "always") responseMap.set(r.question_id, 4);
      }
      // Store string value
      if (r.response_value) {
        stringResponseMap.set(r.question_id, r.response_value);
      }
    }

    // Get demographics for STOP-BANG
    const user = await ctx.db.get(args.userId);
    const dobResponse = stringResponseMap.get("D2");
    const sexResponse = stringResponseMap.get("D4");
    const heightResponse = stringResponseMap.get("D5");
    const weightResponse = stringResponseMap.get("D6");

    let age: number | undefined;
    if (dobResponse) {
      const birthYear = parseInt(dobResponse.split("-")[0] || dobResponse);
      if (!isNaN(birthYear)) {
        age = new Date().getFullYear() - birthYear;
      }
    }

    let bmi: number | undefined;
    if (heightResponse && weightResponse) {
      const heightCm = parseFloat(heightResponse);
      const weightKg = parseFloat(weightResponse);
      if (!isNaN(heightCm) && !isNaN(weightKg) && heightCm > 0) {
        bmi = weightKg / ((heightCm / 100) ** 2);
      }
    }

    const demographics = { age, sex: sexResponse, bmi };

    // Calculate all scores
    const scores: QuestionnaireScore[] = [
      calculateISI(responseMap),
      calculatePHQ9(responseMap),
      calculateGAD7(responseMap),
      calculateESS(responseMap),
      calculateSTOPBANG(responseMap, demographics),
      calculatePSQI(responseMap),
      calculateDBAS6(responseMap), // DBAS-6 (2024) replaces DBAS-16
      // Berlin removed - STOP-BANG has 93% sensitivity for OSA
      calculateFSS(responseMap),
      calculateFOSQ10(responseMap),
      calculateMEDAS(responseMap),
      calculateMEQ(responseMap),
      calculateSWDSQ(responseMap),
    ];

    // Add DASS-21 subscales
    const dass21 = calculateDASS21(responseMap);
    scores.push(dass21.depression, dass21.anxiety, dass21.stress);

    // Add BPI subscales
    const bpi = calculateBPI(responseMap);
    scores.push(bpi.severity, bpi.interference);

    // Add PROMIS Cognitive
    scores.push(calculatePROMIS(responseMap));

    // Add Sleep Hygiene
    scores.push(calculateSleepHygiene(responseMap));

    // Add PSAS subscales
    const psas = calculatePSAS(responseMap);
    scores.push(psas.cognitive, psas.somatic);

    // Calculate sleep log metrics (SL_, SD_, and CSD_ prefixes)
    const sleepLogResponses = allResponses.filter(r =>
      r.question_id.startsWith("SL_") || r.question_id.startsWith("SD_") || r.question_id.startsWith("CSD_")
    );

    let totalQuality = 0;
    let qualityCount = 0;
    let totalAwakenings = 0;
    let awakeningsCount = 0;
    const bedtimes: string[] = [];
    const wakeTimes: string[] = [];

    for (const r of sleepLogResponses) {
      // Sleep quality questions
      if (r.question_id === "SL_QUALITY" || r.question_id === "SD_SLEEP_QUALITY" || r.question_id === "CSD_QUALITY") {
        const val = r.response_number ?? parseFloat(r.response_value || "");
        if (!isNaN(val)) {
          totalQuality += val;
          qualityCount++;
        }
      }
      // Awakenings questions
      if (r.question_id === "SL_AWAKENINGS" || r.question_id === "SD_AWAKENINGS_COUNT" || r.question_id === "CSD_AWAKENINGS") {
        const val = r.response_number ?? parseFloat(r.response_value || "");
        if (!isNaN(val)) {
          totalAwakenings += val;
          awakeningsCount++;
        }
      }
      // Bedtime questions
      if (r.question_id === "SL_BEDTIME" || r.question_id === "SD_GOT_INTO_BED" || r.question_id === "CSD_INTO_BED") {
        if (r.response_value) bedtimes.push(r.response_value);
      }
      // Wake time questions
      if (r.question_id === "SL_WAKE_TIME" || r.question_id === "SD_FINAL_WAKE" || r.question_id === "CSD_FINAL_WAKE") {
        if (r.response_value) wakeTimes.push(r.response_value);
      }
    }

    // Get unique days logged
    const daysLogged = new Set(sleepLogResponses.map(r => r.day_number)).size;

    const sleepMetrics = {
      avgBedtime: bedtimes.length > 0 ? bedtimes[Math.floor(bedtimes.length / 2)] : undefined, // median
      avgWakeTime: wakeTimes.length > 0 ? wakeTimes[Math.floor(wakeTimes.length / 2)] : undefined,
      avgSleepQuality: qualityCount > 0 ? Math.round((totalQuality / qualityCount) * 10) / 10 : undefined,
      avgAwakenings: awakeningsCount > 0 ? Math.round((totalAwakenings / awakeningsCount) * 10) / 10 : undefined,
      daysLogged,
    };

    // Determine gateway triggers
    const gateways = {
      insomnia: (responseMap.get("3") === 1) || // trouble falling/staying asleep
                (responseMap.get("1") !== undefined && responseMap.get("1")! <= 5), // poor sleep quality
      depression: (responseMap.get("15") !== undefined && responseMap.get("15")! >= 2), // felt down/hopeless
      anxiety: (responseMap.get("16") !== undefined && responseMap.get("16")! >= 2), // felt nervous/anxious
      sleepApnea: (responseMap.get("19") === 1) || // loud snoring
                  (responseMap.get("20") === 1) || // observed apnea
                  (responseMap.get("48") !== undefined && responseMap.get("48")! >= 2) || // breathing issues (PSQI)
                  (responseMap.get("49") !== undefined && responseMap.get("49")! >= 2), // snoring/coughing (PSQI)
      excessiveSleepiness: (responseMap.get("17") !== undefined && responseMap.get("17")! >= 3), // often/always tired
      pain: (responseMap.get("22") === 1) || // pain affects sleep
            (responseMap.get("53") !== undefined && responseMap.get("53")! >= 2), // pain trouble sleeping (PSQI)
      prostate: (responseMap.get("47") !== undefined && responseMap.get("47")! >= 2), // nocturia (requires male 45+ check in app)
    };

    return {
      scores: scores.map(s => ({
        name: s.name,
        abbreviation: s.abbreviation,
        score: s.score,
        maxScore: s.maxScore,
        interpretation: s.interpretation,
        severity: s.severity,
        questionsAnswered: s.questionsAnswered,
        questionsRequired: s.questionsRequired,
      })),
      sleepMetrics,
      gateways,
    };
  },
});

/**
 * Calculate and persist questionnaire scores to the database
 * This runs the scoring algorithms and saves results to questionnaire_scores table
 * so they can be queried by getQuestionnaireScores
 *
 * Used by:
 * - Mock data generator (to populate dashboard during testing)
 * - Could be triggered after real users complete enough questions
 */
export const persistCalculatedScores = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;
    const now = Date.now();

    // Get all user responses
    const allResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Build response map (question_id -> numeric value)
    const responseMap = new Map<string, number>();
    for (const r of allResponses) {
      const numVal = r.response_number ?? (r.response_value ? parseFloat(r.response_value) : NaN);
      if (!isNaN(numVal)) {
        responseMap.set(r.question_id, numVal);
      }
    }

    // Get demographics for STOP-BANG
    const demographics: { age?: number; bmi?: number; isMale?: boolean } = {};

    // Age from D2 (DOB)
    const dobResponse = allResponses.find(r => r.question_id === "D2");
    if (dobResponse?.response_value) {
      const dob = new Date(dobResponse.response_value);
      const today = new Date();
      const age = Math.floor((today.getTime() - dob.getTime()) / (365.25 * 24 * 60 * 60 * 1000));
      if (age > 0 && age < 150) demographics.age = age;
    }

    // Sex from D4
    const sexResponse = allResponses.find(r => r.question_id === "D4");
    if (sexResponse?.response_value) {
      demographics.isMale = sexResponse.response_value.toLowerCase().includes("male") &&
        !sexResponse.response_value.toLowerCase().includes("female");
    }

    // BMI from D5 (height) and D6 (weight)
    const heightResponse = allResponses.find(r => r.question_id === "D5");
    const weightResponse = allResponses.find(r => r.question_id === "D6");
    if (heightResponse?.response_number && weightResponse?.response_number) {
      const heightM = heightResponse.response_number / 100; // cm to m
      const weightKg = weightResponse.response_number;
      if (heightM > 0) {
        demographics.bmi = Math.round((weightKg / (heightM * heightM)) * 10) / 10;
      }
    }

    // Calculate all scores using existing functions
    const scores: QuestionnaireScore[] = [
      calculateISI(responseMap),
      calculatePHQ9(responseMap),
      calculateGAD7(responseMap),
      calculateESS(responseMap),
      calculateSTOPBANG(responseMap, demographics),
      calculatePSQI(responseMap),
      calculateDBAS6(responseMap), // DBAS-6 (2024) replaces DBAS-16
      // Berlin removed - STOP-BANG has 93% sensitivity for OSA
      calculateFSS(responseMap),
      calculateFOSQ10(responseMap),
      calculateMEDAS(responseMap),
      calculateMEQ(responseMap),
      calculateSWDSQ(responseMap),
    ];

    // Add DASS-21 subscales
    const dass21 = calculateDASS21(responseMap);
    scores.push(dass21.depression, dass21.anxiety, dass21.stress);

    // Add BPI subscales
    const bpi = calculateBPI(responseMap);
    scores.push(bpi.severity, bpi.interference);

    // Add PROMIS Cognitive
    scores.push(calculatePROMIS(responseMap));

    // Add Sleep Hygiene
    scores.push(calculateSleepHygiene(responseMap));

    // Add PSAS subscales
    const psas = calculatePSAS(responseMap);
    scores.push(psas.cognitive, psas.somatic);

    // Persist each score that has a valid value
    const savedScores: string[] = [];
    for (const score of scores) {
      if (score.score !== null) {
        const existing = await ctx.db
          .query("questionnaire_scores")
          .withIndex("by_user_questionnaire", (q) =>
            q.eq("user_id", userId).eq("questionnaire_name", score.abbreviation)
          )
          .first();

        const scoreData = {
          user_id: userId,
          questionnaire_name: score.abbreviation,
          score: score.score,
          max_score: score.maxScore,
          category: score.severity,
          interpretation: score.interpretation,
          calculated_at: now,
          calculation_metadata_json: JSON.stringify({
            questionsAnswered: score.questionsAnswered,
            questionsRequired: score.questionsRequired,
            fullName: score.name,
          }),
        };

        if (existing) {
          await ctx.db.patch(existing._id, scoreData);
        } else {
          await ctx.db.insert("questionnaire_scores", scoreData);
        }
        savedScores.push(`${score.abbreviation}: ${score.score}/${score.maxScore}`);
      }
    }

    console.log(`[persistCalculatedScores] Saved ${savedScores.length} scores for user ${userId}: ${savedScores.join(", ")}`);

    return {
      success: true,
      savedCount: savedScores.length,
      scores: savedScores,
    };
  },
});

// ============================================
// Developer Mode (Fast-Track Testing)
// ============================================

/**
 * Toggle developer mode for a patient
 * When enabled, the patient can skip time gates and advance days instantly
 */
export const toggleDeveloperMode = mutation({
  args: {
    userId: v.id("users"),
    enabled: v.boolean(),
  },
  returns: v.object({
    success: v.boolean(),
    developerMode: v.boolean(),
  }),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    await ctx.db.patch(args.userId, {
      developer_mode: args.enabled,
    });

    console.log(`[toggleDeveloperMode] User ${user.username}: developer_mode = ${args.enabled}`);

    return {
      success: true,
      developerMode: args.enabled,
    };
  },
});

/**
 * Set a patient's current day (for developer mode testing)
 * This allows physicians to instantly advance a tester to any day
 */
export const setPatientDay = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  returns: v.object({
    success: v.boolean(),
    currentDay: v.number(),
  }),
  handler: async (ctx, args) => {
    // Validate dayNumber is 1-14
    if (args.dayNumber < 1 || args.dayNumber > 14) {
      throw new Error("Day must be between 1 and 14");
    }

    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Check if developer mode is enabled
    if (!user.developer_mode) {
      throw new Error("Developer mode must be enabled to change day");
    }

    await ctx.db.patch(args.userId, {
      current_day: args.dayNumber,
    });

    console.log(`[setPatientDay] User ${user.username}: current_day = ${args.dayNumber}`);

    return {
      success: true,
      currentDay: args.dayNumber,
    };
  },
});

/**
 * Get developer mode status for a user
 */
export const getDeveloperModeStatus = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.object({
    developerMode: v.boolean(),
    currentDay: v.number(),
  }),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    return {
      developerMode: user.developer_mode ?? false,
      currentDay: user.current_day,
    };
  },
});

// ============================================
// Nap and Medication Summary Queries
// ============================================

interface NapEntry {
  napNumber: number;
  startTime: string;
  durationMinutes: number;
}

/**
 * Get aggregated nap summary for a patient
 * Returns: days with naps, average nap count, average duration, common nap times
 */
export const getPatientNapSummary = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    // Get all nap-related responses (both CSD_ and SD_ prefixes)
    const napResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) =>
        q.or(
          // CSD (Consensus Sleep Diary) prefix
          q.eq(q.field("question_id"), "CSD_NAPS"),
          q.eq(q.field("question_id"), "CSD_NAP_COUNT"),
          q.eq(q.field("question_id"), "CSD_NAP_DETAILS"),
          q.eq(q.field("question_id"), "CSD_NAP_DURATION"),
          // SD (Stanford Sleep Diary) prefix
          q.eq(q.field("question_id"), "SD_NAPS_TAKEN"),
          q.eq(q.field("question_id"), "SD_NAPS_COUNT"),
          q.eq(q.field("question_id"), "SD_NAP_DETAILS")
        )
      )
      .collect();

    // Group by day
    const dayData: Record<number, { tookNaps: boolean; napCount: number; napDetails?: NapEntry[]; totalDuration?: number }> = {};

    for (const response of napResponses) {
      const day = response.day_number ?? 1;
      if (!dayData[day]) {
        dayData[day] = { tookNaps: false, napCount: 0 };
      }

      switch (response.question_id) {
        case "CSD_NAPS":
        case "SD_NAPS_TAKEN":
          dayData[day].tookNaps = response.response_value?.toLowerCase() === "yes";
          break;
        case "CSD_NAP_COUNT":
        case "SD_NAPS_COUNT":
          dayData[day].napCount = response.response_number ?? 0;
          break;
        case "CSD_NAP_DETAILS":
        case "SD_NAP_DETAILS":
          if (response.response_object) {
            try {
              dayData[day].napDetails = JSON.parse(response.response_object);
            } catch {
              // Invalid JSON, ignore
            }
          }
          break;
        case "CSD_NAP_DURATION":
          dayData[day].totalDuration = response.response_number ?? 0;
          break;
      }
    }

    // Calculate summaries
    const daysWithNaps = Object.values(dayData).filter((d) => d.tookNaps).length;
    const totalDays = Object.keys(dayData).length;

    let totalNapCount = 0;
    let totalDuration = 0;
    let napDaysWithData = 0;
    const timeSlots: Record<string, number> = {};

    for (const data of Object.values(dayData)) {
      if (data.tookNaps) {
        totalNapCount += data.napCount || 1;
        napDaysWithData++;

        // Process detailed nap data
        if (data.napDetails) {
          for (const nap of data.napDetails) {
            totalDuration += nap.durationMinutes;
            // Round to nearest hour for common times
            const hour = parseInt(nap.startTime.split(":")[0]);
            const timeSlot = hour < 12 ? `${hour}AM` : hour === 12 ? "12PM" : `${hour - 12}PM`;
            timeSlots[timeSlot] = (timeSlots[timeSlot] || 0) + 1;
          }
        } else if (data.totalDuration) {
          // Legacy data - use total duration
          totalDuration += data.totalDuration;
        }
      }
    }

    // Find most common nap times
    const commonTimes = Object.entries(timeSlots)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([time]) => time);

    return {
      napDays: daysWithNaps,
      totalDays,
      avgNapCount: napDaysWithData > 0 ? totalNapCount / napDaysWithData : 0,
      avgDuration: napDaysWithData > 0 ? Math.round(totalDuration / napDaysWithData) : 0,
      commonTimes: commonTimes.length > 0 ? commonTimes : ["2PM", "3PM"],
    };
  },
});

// MedicationSelection type (matches iOS struct)
interface MedicationSelection {
  categoryId: string;
  dose?: string | null;
  medicationName?: string | null;
}

// MedicationWithTiming type (new iOS format with timing)
interface MedicationWithTiming {
  categoryId: string;
  dose?: string | null;
  medicationName?: string | null;
  timingCategories?: string[]; // ["morning", "afternoon", "evening", "bedtime"]
  specificTime?: string | null;
}

/**
 * Get aggregated medication summary for a patient
 * Returns: days with meds, category counts with doses, other medications
 */
export const getPatientMedicationSummary = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    // Get all medication-related responses (both CSD_ and SD_ prefixes)
    const medResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) =>
        q.or(
          // CSD (Consensus Sleep Diary) prefix
          q.eq(q.field("question_id"), "CSD_MEDS"),
          q.eq(q.field("question_id"), "CSD_MEDS_LIST"),
          q.eq(q.field("question_id"), "CSD_MEDS_NAME"),
          q.eq(q.field("question_id"), "CSD_MEDS_OTHER"),
          // SD (Stanford Sleep Diary) prefix
          q.eq(q.field("question_id"), "SD_MEDICATION_TAKEN"),
          q.eq(q.field("question_id"), "SD_MEDS_LIST"),
          q.eq(q.field("question_id"), "SD_MEDS_OTHER")
        )
      )
      .collect();

    // Group by day
    const dayData: Record<number, {
      tookMeds: boolean;
      medications: MedicationWithTiming[];
      legacyCategories: string[];
      otherText?: string;
      legacyName?: string;
    }> = {};

    for (const response of medResponses) {
      const day = response.day_number ?? 1;
      if (!dayData[day]) {
        dayData[day] = { tookMeds: false, medications: [], legacyCategories: [] };
      }

      switch (response.question_id) {
        case "CSD_MEDS":
        case "SD_MEDICATION_TAKEN":
          dayData[day].tookMeds = response.response_value?.toLowerCase() === "yes";
          break;
        case "CSD_MEDS_LIST":
        case "SD_MEDS_LIST":
          // Check response_object first (new MedicationWithTiming format)
          if (response.response_object) {
            try {
              const parsed = JSON.parse(response.response_object);
              if (Array.isArray(parsed) && parsed.length > 0) {
                dayData[day].medications = parsed as MedicationWithTiming[];
              }
            } catch {
              // Invalid JSON, ignore
            }
          }
          // Fall back to response_array (legacy formats)
          else if (response.response_array) {
            try {
              const parsed = JSON.parse(response.response_array);
              // Check if it's the new MedicationSelection format or legacy string array
              if (parsed.length > 0) {
                if (typeof parsed[0] === "object" && parsed[0].categoryId) {
                  // New format: array of MedicationSelection/MedicationWithTiming objects
                  dayData[day].medications = parsed as MedicationWithTiming[];
                } else if (typeof parsed[0] === "string") {
                  // Legacy format: array of category strings
                  dayData[day].legacyCategories = parsed as string[];
                }
              }
            } catch {
              // Invalid JSON, ignore
            }
          }
          break;
        case "CSD_MEDS_OTHER":
        case "SD_MEDS_OTHER":
          dayData[day].otherText = response.response_value;
          break;
        case "CSD_MEDS_NAME":
          // Legacy field
          dayData[day].legacyName = response.response_value;
          break;
      }
    }

    // Calculate summaries
    const daysWithMeds = Object.values(dayData).filter((d) => d.tookMeds).length;
    const totalDays = Object.keys(dayData).length;

    // Aggregate category counts with dose and timing info
    const categoryCounts: Record<string, { count: number; doses: string[]; medicationNames: string[]; timingCounts: Record<string, number> }> = {};
    const otherMedications: string[] = [];
    const timingCounts: Record<string, number> = { morning: 0, afternoon: 0, evening: 0, bedtime: 0 };

    for (const data of Object.values(dayData)) {
      if (data.tookMeds) {
        // New format: MedicationWithTiming objects with doses and timing
        for (const med of data.medications) {
          const catId = med.categoryId;
          if (!categoryCounts[catId]) {
            categoryCounts[catId] = { count: 0, doses: [], medicationNames: [], timingCounts: {} };
          }
          categoryCounts[catId].count++;
          if (med.dose && !categoryCounts[catId].doses.includes(med.dose)) {
            categoryCounts[catId].doses.push(med.dose);
          }
          if (med.medicationName && !categoryCounts[catId].medicationNames.includes(med.medicationName)) {
            categoryCounts[catId].medicationNames.push(med.medicationName);
          }
          // Track timing categories
          if (med.timingCategories) {
            for (const timing of med.timingCategories) {
              timingCounts[timing] = (timingCounts[timing] || 0) + 1;
              categoryCounts[catId].timingCounts[timing] = (categoryCounts[catId].timingCounts[timing] || 0) + 1;
            }
          }
        }

        // Legacy format: string categories (no dose info)
        for (const cat of data.legacyCategories) {
          if (!categoryCounts[cat]) {
            categoryCounts[cat] = { count: 0, doses: [], medicationNames: [], timingCounts: {} };
          }
          categoryCounts[cat].count++;
        }

        // Other text (new format)
        if (data.otherText && !otherMedications.includes(data.otherText)) {
          otherMedications.push(data.otherText);
        }

        // Legacy format: free text name
        if (data.legacyName && !otherMedications.includes(data.legacyName)) {
          otherMedications.push(data.legacyName);
        }
      }
    }

    // Category display names and dose units
    const categoryInfo: Record<string, { name: string; unit: string }> = {
      melatonin: { name: "Melatonin", unit: "mg" },
      prescription: { name: "Prescription", unit: "mg" },
      otc: { name: "OTC Sleep Aid", unit: "mg" },
      cbd_thc: { name: "CBD/THC", unit: "mg" },
      magnesium: { name: "Magnesium", unit: "mg" },
      herbal: { name: "Herbal/Natural", unit: "mg" },
      other: { name: "Other", unit: "mg" },
    };

    const categories = Object.entries(categoryCounts)
      .map(([id, data]) => ({
        id,
        name: categoryInfo[id]?.name || id,
        count: data.count,
        unit: categoryInfo[id]?.unit || "mg",
        commonDoses: data.doses.sort((a, b) => parseFloat(a) - parseFloat(b)),
        medications: data.medicationNames,
        timingBreakdown: data.timingCounts,
      }))
      .sort((a, b) => b.count - a.count);

    // Determine most common timing
    const mostCommonTiming = Object.entries(timingCounts)
      .sort((a, b) => b[1] - a[1])
      .filter(([, count]) => count > 0)
      .map(([timing]) => timing)[0] || "bedtime";

    return {
      medicationDays: daysWithMeds,
      totalDays,
      categories,
      otherMedications,
      timingBreakdown: timingCounts,
      mostCommonTiming,
    };
  },
});

// CaffeineEntry type (matches iOS struct)
interface CaffeineEntry {
  typeId: string;
  count: number;
}

// Caffeine type info for display
const CAFFEINE_TYPE_INFO: Record<string, { name: string; mgPerServing: number }> = {
  drip_coffee: { name: "Drip Coffee", mgPerServing: 95 },
  espresso: { name: "Espresso", mgPerServing: 63 },
  latte_cappuccino: { name: "Latte/Cappuccino", mgPerServing: 75 },
  cold_brew: { name: "Cold Brew", mgPerServing: 200 },
  black_tea: { name: "Black Tea", mgPerServing: 47 },
  green_tea: { name: "Green Tea", mgPerServing: 28 },
  matcha: { name: "Matcha", mgPerServing: 70 },
  energy_drink: { name: "Energy Drink", mgPerServing: 80 },
  energy_drink_large: { name: "Energy Drink (Large)", mgPerServing: 160 },
  soda: { name: "Cola/Soda", mgPerServing: 34 },
  diet_soda: { name: "Diet Cola", mgPerServing: 46 },
  preworkout: { name: "Pre-Workout", mgPerServing: 200 },
  chocolate: { name: "Dark Chocolate", mgPerServing: 12 },
};

/**
 * Get aggregated caffeine summary for a patient
 * Returns: days with caffeine, total mg stats, type breakdown
 */
export const getPatientCaffeineSummary = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    // Get all caffeine-related responses
    const caffeineResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) =>
        q.or(
          q.eq(q.field("question_id"), "CSD_CAFFEINE"),
          q.eq(q.field("question_id"), "CSD_CAFFEINE_TYPES"),
          q.eq(q.field("question_id"), "CSD_CAFFEINE_LAST")
        )
      )
      .collect();

    // Group by day
    const dayData: Record<number, {
      hadCaffeine: boolean;
      entries: CaffeineEntry[];
      lastCaffeineTime?: string;
      legacyCount?: number;
    }> = {};

    for (const response of caffeineResponses) {
      const day = response.day_number ?? 1;
      if (!dayData[day]) {
        dayData[day] = { hadCaffeine: false, entries: [] };
      }

      switch (response.question_id) {
        case "CSD_CAFFEINE":
          // Can be Yes/No (new) or number (legacy)
          if (response.response_value?.toLowerCase() === "yes") {
            dayData[day].hadCaffeine = true;
          } else if (response.response_value?.toLowerCase() === "no") {
            dayData[day].hadCaffeine = false;
          } else {
            // Legacy: it's a number
            const count = parseInt(response.response_value || "0");
            dayData[day].hadCaffeine = count > 0;
            dayData[day].legacyCount = count;
          }
          break;
        case "CSD_CAFFEINE_TYPES":
          if (response.response_array) {
            try {
              dayData[day].entries = JSON.parse(response.response_array) as CaffeineEntry[];
            } catch {
              // Invalid JSON, ignore
            }
          }
          break;
        case "CSD_CAFFEINE_LAST":
          dayData[day].lastCaffeineTime = response.response_value || undefined;
          break;
      }
    }

    // Calculate summaries
    const daysWithCaffeine = Object.values(dayData).filter((d) => d.hadCaffeine).length;
    const totalDays = Object.keys(dayData).length;

    // Aggregate type counts and total mg
    const typeCounts: Record<string, { count: number; totalServings: number; totalMg: number }> = {};
    let totalMgAllDays = 0;
    let totalServingsAllDays = 0;
    let daysWithDetailedData = 0;

    for (const data of Object.values(dayData)) {
      if (data.hadCaffeine) {
        if (data.entries.length > 0) {
          daysWithDetailedData++;
          for (const entry of data.entries) {
            const typeInfo = CAFFEINE_TYPE_INFO[entry.typeId];
            if (!typeCounts[entry.typeId]) {
              typeCounts[entry.typeId] = { count: 0, totalServings: 0, totalMg: 0 };
            }
            typeCounts[entry.typeId].count++;
            typeCounts[entry.typeId].totalServings += entry.count;
            const mg = (typeInfo?.mgPerServing || 0) * entry.count;
            typeCounts[entry.typeId].totalMg += mg;
            totalMgAllDays += mg;
            totalServingsAllDays += entry.count;
          }
        } else if (data.legacyCount) {
          // Legacy data - assume drip coffee at 95mg per serving
          totalMgAllDays += data.legacyCount * 95;
          totalServingsAllDays += data.legacyCount;
        }
      }
    }

    // Build type summary
    const typeBreakdown = Object.entries(typeCounts)
      .map(([id, data]) => ({
        id,
        name: CAFFEINE_TYPE_INFO[id]?.name || id,
        mgPerServing: CAFFEINE_TYPE_INFO[id]?.mgPerServing || 0,
        daysUsed: data.count,
        totalServings: data.totalServings,
        totalMg: data.totalMg,
      }))
      .sort((a, b) => b.totalMg - a.totalMg);

    // Calculate averages
    const avgMgPerDay = daysWithCaffeine > 0 ? Math.round(totalMgAllDays / daysWithCaffeine) : 0;
    const avgServingsPerDay = daysWithCaffeine > 0 ? (totalServingsAllDays / daysWithCaffeine).toFixed(1) : "0";

    return {
      caffeineDays: daysWithCaffeine,
      totalDays,
      avgMgPerDay,
      avgServingsPerDay,
      totalMgAllDays,
      typeBreakdown,
      hasDetailedData: daysWithDetailedData > 0,
    };
  },
});

// ============================================
// Day Type Analysis (Workday vs Weekend Patterns)
// ============================================

/**
 * Get sleep pattern analysis by day type for a patient
 * Returns: workday vs weekend sleep differences, flagging significant variations
 * Critical for: Identifying social jet lag, irregular schedules, and compensatory sleep patterns
 */
export const getPatientDayTypeAnalysis = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    // Get all sleep data for this user
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    if (sleepData.length === 0) {
      return {
        hasData: false,
        totalDays: 0,
        workdayStats: null,
        weekendStats: null,
        differences: null,
        flags: [],
      };
    }

    // Group by day type (workday = Workday/School Day, weekend = Day Off/Vacation/Holiday)
    const workdayTypes = ["Workday", "School Day"];
    const weekendTypes = ["Day Off", "Vacation", "Holiday", "Weekend"];

    const workdays = sleepData.filter(d => workdayTypes.includes(d.day_type ?? ""));
    const weekends = sleepData.filter(d => weekendTypes.includes(d.day_type ?? ""));

    // Helper to calculate stats
    const calcStats = (days: typeof sleepData) => {
      if (days.length === 0) return null;

      const validSleep = days.filter(d => d.total_sleep_mins != null);
      const validEfficiency = days.filter(d => d.sleep_efficiency != null);
      const validLatency = days.filter(d => d.sleep_latency_mins != null);
      const validQuality = days.filter(d => d.subjective_quality != null);

      return {
        count: days.length,
        avgSleepMins: validSleep.length > 0
          ? Math.round(validSleep.reduce((sum, d) => sum + (d.total_sleep_mins ?? 0), 0) / validSleep.length)
          : null,
        avgEfficiency: validEfficiency.length > 0
          ? Math.round(validEfficiency.reduce((sum, d) => sum + (d.sleep_efficiency ?? 0), 0) / validEfficiency.length)
          : null,
        avgLatencyMins: validLatency.length > 0
          ? Math.round(validLatency.reduce((sum, d) => sum + (d.sleep_latency_mins ?? 0), 0) / validLatency.length)
          : null,
        avgQuality: validQuality.length > 0
          ? Math.round((validQuality.reduce((sum, d) => sum + (d.subjective_quality ?? 0), 0) / validQuality.length) * 10) / 10
          : null,
        daysWithNaps: days.filter(d => d.naps_taken === true).length,
        daysWithMeds: days.filter(d => d.medications_taken === true).length,
      };
    };

    const workdayStats = calcStats(workdays);
    const weekendStats = calcStats(weekends);

    // Calculate differences (weekend - workday)
    let differences = null;
    if (workdayStats && weekendStats && workdayStats.avgSleepMins && weekendStats.avgSleepMins) {
      differences = {
        sleepDiffMins: weekendStats.avgSleepMins - workdayStats.avgSleepMins,
        efficiencyDiff: (weekendStats.avgEfficiency ?? 0) - (workdayStats.avgEfficiency ?? 0),
        latencyDiff: (weekendStats.avgLatencyMins ?? 0) - (workdayStats.avgLatencyMins ?? 0),
        qualityDiff: (weekendStats.avgQuality ?? 0) - (workdayStats.avgQuality ?? 0),
      };
    }

    // Generate clinical flags
    const flags: { type: string; severity: "info" | "warning" | "alert"; message: string }[] = [];

    // Social jet lag: >60 min difference in sleep duration between workday/weekend
    if (differences && Math.abs(differences.sleepDiffMins) > 60) {
      const moreOn = differences.sleepDiffMins > 0 ? "weekends" : "workdays";
      flags.push({
        type: "social_jet_lag",
        severity: Math.abs(differences.sleepDiffMins) > 90 ? "alert" : "warning",
        message: `Sleeps ${Math.abs(differences.sleepDiffMins)} min more on ${moreOn} (social jet lag indicator)`,
      });
    }

    // Compensatory sleep: significant weekend catch-up suggests weekday sleep debt
    if (differences && differences.sleepDiffMins > 90) {
      flags.push({
        type: "compensatory_sleep",
        severity: "warning",
        message: "Weekend catch-up sleep suggests weekday sleep debt",
      });
    }

    // Higher nap rate on weekends
    if (workdayStats && weekendStats && weekendStats.count > 0 && workdayStats.count > 0) {
      const workdayNapRate = workdayStats.daysWithNaps / workdayStats.count;
      const weekendNapRate = weekendStats.daysWithNaps / weekendStats.count;
      if (weekendNapRate > workdayNapRate + 0.3) {
        flags.push({
          type: "weekend_napping",
          severity: "info",
          message: "Higher nap rate on weekends may indicate weekday sleep deficit",
        });
      }
    }

    // Medication use pattern
    if (workdayStats && weekendStats && workdayStats.daysWithMeds !== weekendStats.daysWithMeds) {
      const diff = Math.abs(workdayStats.daysWithMeds - weekendStats.daysWithMeds);
      if (diff > 1) {
        const moreOn = workdayStats.daysWithMeds > weekendStats.daysWithMeds ? "workdays" : "weekends";
        flags.push({
          type: "medication_pattern",
          severity: "info",
          message: `More sleep medication use on ${moreOn}`,
        });
      }
    }

    return {
      hasData: true,
      totalDays: sleepData.length,
      workdayStats,
      weekendStats,
      differences,
      flags,
    };
  },
});

// ============================================
// Patient Check-In Trends (Energy/Mood/Focus)
// ============================================

/**
 * Get a patient's daily check-in trends for the physician dashboard
 * Returns energy, mood, and focus levels over time from watch check-ins
 */
export const getPatientCheckInTrends = query({
  args: {
    patientId: v.id("users"),
    days: v.optional(v.number()), // Default 30
  },
  returns: v.object({
    // Daily data points (array of days, oldest first)
    dailyData: v.array(v.object({
      date: v.string(),
      dayOfWeek: v.string(),
      hasData: v.boolean(),
      // Averages for the day (across all check-ins)
      avgEnergy: v.optional(v.number()),
      avgMood: v.optional(v.number()),
      avgFocus: v.optional(v.number()),
      // Individual check-ins for detail view
      checkIns: v.array(v.object({
        type: v.string(), // "morning", "midday", "evening"
        energy: v.number(),
        mood: v.number(),
        focus: v.number(),
        completedAt: v.number(),
      })),
    })),
    // Summary statistics
    summary: v.object({
      totalDays: v.number(),
      daysWithData: v.number(),
      avgEnergy: v.optional(v.number()),
      avgMood: v.optional(v.number()),
      avgFocus: v.optional(v.number()),
      // Trends (positive = improving)
      energyTrend: v.optional(v.number()),
      moodTrend: v.optional(v.number()),
      focusTrend: v.optional(v.number()),
    }),
  }),
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 30;
    const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

    // Get all check-ins for this patient
    const allCheckins = await ctx.db
      .query("daily_checkins")
      .withIndex("by_user", (q) => q.eq("user_id", args.patientId))
      .collect();

    // Filter completed check-ins with energy/mood/focus data
    const relevantCheckins = allCheckins.filter(c =>
      c.completed &&
      c.energy_level !== undefined &&
      c.mood !== undefined
    );

    // Build daily data for the requested period
    const dailyData: {
      date: string;
      dayOfWeek: string;
      hasData: boolean;
      avgEnergy?: number;
      avgMood?: number;
      avgFocus?: number;
      checkIns: {
        type: string;
        energy: number;
        mood: number;
        focus: number;
        completedAt: number;
      }[];
    }[] = [];

    let totalEnergy = 0;
    let totalMood = 0;
    let totalFocus = 0;
    let totalCheckIns = 0;

    // First half averages (for trend calculation)
    let firstHalfEnergy = 0;
    let firstHalfMood = 0;
    let firstHalfFocus = 0;
    let firstHalfCount = 0;

    // Second half averages
    let secondHalfEnergy = 0;
    let secondHalfMood = 0;
    let secondHalfFocus = 0;
    let secondHalfCount = 0;

    const halfwayPoint = Math.floor(daysToFetch / 2);

    for (let i = daysToFetch - 1; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      const dateStr = date.toISOString().split("T")[0];
      const dayOfWeek = dayNames[date.getDay()];

      const dayCheckins = relevantCheckins.filter(c => c.checkin_date === dateStr);

      if (dayCheckins.length > 0) {
        const checkIns = dayCheckins.map(c => ({
          type: c.checkin_type || "unknown",
          energy: c.energy_level!,
          mood: c.mood!,
          focus: c.focus_level ?? 3,
          completedAt: c.completed_at ?? c.created_at,
        }));

        const energySum = checkIns.reduce((sum, c) => sum + c.energy, 0);
        const moodSum = checkIns.reduce((sum, c) => sum + c.mood, 0);
        const focusSum = checkIns.reduce((sum, c) => sum + c.focus, 0);

        const avgEnergy = Math.round((energySum / checkIns.length) * 10) / 10;
        const avgMood = Math.round((moodSum / checkIns.length) * 10) / 10;
        const avgFocus = Math.round((focusSum / checkIns.length) * 10) / 10;

        dailyData.push({
          date: dateStr,
          dayOfWeek,
          hasData: true,
          avgEnergy,
          avgMood,
          avgFocus,
          checkIns,
        });

        // Accumulate totals
        totalEnergy += energySum;
        totalMood += moodSum;
        totalFocus += focusSum;
        totalCheckIns += checkIns.length;

        // Track first/second half for trends
        const dayIndex = daysToFetch - 1 - i;
        if (dayIndex < halfwayPoint) {
          firstHalfEnergy += energySum;
          firstHalfMood += moodSum;
          firstHalfFocus += focusSum;
          firstHalfCount += checkIns.length;
        } else {
          secondHalfEnergy += energySum;
          secondHalfMood += moodSum;
          secondHalfFocus += focusSum;
          secondHalfCount += checkIns.length;
        }
      } else {
        dailyData.push({
          date: dateStr,
          dayOfWeek,
          hasData: false,
          checkIns: [],
        });
      }
    }

    // Calculate summary
    const daysWithData = dailyData.filter(d => d.hasData).length;

    let summary: {
      totalDays: number;
      daysWithData: number;
      avgEnergy?: number;
      avgMood?: number;
      avgFocus?: number;
      energyTrend?: number;
      moodTrend?: number;
      focusTrend?: number;
    } = {
      totalDays: daysToFetch,
      daysWithData,
    };

    if (totalCheckIns > 0) {
      summary.avgEnergy = Math.round((totalEnergy / totalCheckIns) * 10) / 10;
      summary.avgMood = Math.round((totalMood / totalCheckIns) * 10) / 10;
      summary.avgFocus = Math.round((totalFocus / totalCheckIns) * 10) / 10;

      // Calculate trends (positive = improving)
      if (firstHalfCount > 0 && secondHalfCount > 0) {
        const firstHalfAvgEnergy = firstHalfEnergy / firstHalfCount;
        const secondHalfAvgEnergy = secondHalfEnergy / secondHalfCount;
        summary.energyTrend = Math.round((secondHalfAvgEnergy - firstHalfAvgEnergy) * 10) / 10;

        const firstHalfAvgMood = firstHalfMood / firstHalfCount;
        const secondHalfAvgMood = secondHalfMood / secondHalfCount;
        summary.moodTrend = Math.round((secondHalfAvgMood - firstHalfAvgMood) * 10) / 10;

        const firstHalfAvgFocus = firstHalfFocus / firstHalfCount;
        const secondHalfAvgFocus = secondHalfFocus / secondHalfCount;
        summary.focusTrend = Math.round((secondHalfAvgFocus - firstHalfAvgFocus) * 10) / 10;
      }
    }

    return {
      dailyData,
      summary,
    };
  },
});

// ============================================
// Sleep Health Factors - Rolling 14-Day Data
// ============================================

// Medication categories (prescription drugs only - everything else is a supplement)
// Using inverse approach: only these are "medications", everything else is "supplement"
const MEDICATION_CATEGORIES = ["prescription", "otc"];

// All known supplement IDs from iOS SupplementCategory.allCategories
// This list is for display name lookup - anything not in MEDICATION_CATEGORIES is treated as supplement
const SUPPLEMENT_DISPLAY_NAMES: Record<string, string> = {
  melatonin: "Melatonin",
  magnesium: "Magnesium",
  valerian_root: "Valerian Root",
  l_theanine: "L-Theanine",
  cbd_cbn: "CBD/CBN",
  cbd_thc: "CBD/THC",
  gaba: "GABA",
  chamomile: "Chamomile",
  ashwagandha: "Ashwagandha",
  glycine: "Glycine",
  "5_htp": "5-HTP",
  herbal: "Herbal/Natural",
  other_supplement: "Other Supplement",
  other: "Other",
};

/**
 * Get comprehensive rolling sleep health data for the past 14 days
 * Returns day-by-day breakdown for: naps, medications, supplements, caffeine
 * Plus correlation with sleep quality for clinical insights
 */
export const getPatientSleepHealthRolling = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 14
  },
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 14;

    // Get all relevant responses for this user
    const allResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) =>
        q.or(
          // Naps
          q.eq(q.field("question_id"), "CSD_NAPS"),
          q.eq(q.field("question_id"), "CSD_NAP_COUNT"),
          q.eq(q.field("question_id"), "CSD_NAP_DETAILS"),
          q.eq(q.field("question_id"), "SD_NAPS_TAKEN"),
          q.eq(q.field("question_id"), "SD_NAPS_COUNT"),
          q.eq(q.field("question_id"), "SD_NAP_DETAILS"),
          // Medications
          q.eq(q.field("question_id"), "CSD_MEDS"),
          q.eq(q.field("question_id"), "CSD_MEDS_LIST"),
          q.eq(q.field("question_id"), "CSD_MEDS_OTHER"),
          q.eq(q.field("question_id"), "SD_MEDICATION_TAKEN"),
          q.eq(q.field("question_id"), "SD_MEDS_LIST"),
          q.eq(q.field("question_id"), "SD_MEDS_OTHER"),
          // Caffeine
          q.eq(q.field("question_id"), "CSD_CAFFEINE"),
          q.eq(q.field("question_id"), "CSD_CAFFEINE_TYPES"),
          q.eq(q.field("question_id"), "CSD_CAFFEINE_LAST")
        )
      )
      .collect();

    // Get sleep quality data for correlation
    const sleepData = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Build day-by-day data structure
    type DayData = {
      dayNumber: number;
      date?: string;
      // Naps
      tookNaps: boolean;
      napCount: number;
      napDetails: Array<{ startTime?: string; durationMinutes?: number }>;
      totalNapMinutes: number;
      // Medications (prescription/OTC)
      tookMeds: boolean;
      medications: Array<{ categoryId: string; medicationName?: string; dose?: string; timing?: string[] }>;
      // Supplements
      tookSupplements: boolean;
      supplements: Array<{ categoryId: string; name?: string; dose?: string; timing?: string[] }>;
      // Caffeine
      hadCaffeine: boolean;
      caffeineEntries: Array<{ typeId: string; count: number }>;
      totalCaffeineMg: number;
      lastCaffeineTime?: string;
      // Sleep quality (for correlation)
      sleepQuality?: number;
      sleepDurationMins?: number;
      sleepEfficiency?: number;
    };

    const dayMap: Record<number, DayData> = {};

    // Initialize days
    for (let i = 1; i <= daysToFetch; i++) {
      dayMap[i] = {
        dayNumber: i,
        tookNaps: false,
        napCount: 0,
        napDetails: [],
        totalNapMinutes: 0,
        tookMeds: false,
        medications: [],
        tookSupplements: false,
        supplements: [],
        hadCaffeine: false,
        caffeineEntries: [],
        totalCaffeineMg: 0,
      };
    }

    // Process responses
    for (const response of allResponses) {
      const day = response.day_number ?? 1;
      if (day > daysToFetch || !dayMap[day]) continue;

      const qid = response.question_id;

      // Naps
      if (qid === "CSD_NAPS" || qid === "SD_NAPS_TAKEN") {
        dayMap[day].tookNaps = response.response_value?.toLowerCase() === "yes";
      } else if (qid === "CSD_NAP_COUNT" || qid === "SD_NAPS_COUNT") {
        dayMap[day].napCount = response.response_number ?? 0;
      } else if (qid === "CSD_NAP_DETAILS" || qid === "SD_NAP_DETAILS") {
        if (response.response_object) {
          try {
            const parsed = JSON.parse(response.response_object);
            if (Array.isArray(parsed)) {
              dayMap[day].napDetails = parsed.map((n: { startTime?: string; nap_start_time?: string; durationMinutes?: number; nap_duration_minutes?: number }) => ({
                startTime: n.startTime || n.nap_start_time,
                durationMinutes: n.durationMinutes ?? n.nap_duration_minutes ?? 0,
              }));
              dayMap[day].totalNapMinutes = dayMap[day].napDetails.reduce((sum, n) => sum + (n.durationMinutes ?? 0), 0);
            }
          } catch { /* ignore */ }
        }
      }

      // Medications & Supplements
      else if (qid === "CSD_MEDS" || qid === "SD_MEDICATION_TAKEN") {
        const took = response.response_value?.toLowerCase() === "yes";
        dayMap[day].tookMeds = took;
        dayMap[day].tookSupplements = took; // Will filter below
      } else if (qid === "CSD_MEDS_LIST" || qid === "SD_MEDS_LIST") {
        let meds: Array<{ categoryId: string; medicationName?: string; dose?: string; timingCategories?: string[] }> = [];

        if (response.response_object) {
          try {
            meds = JSON.parse(response.response_object);
          } catch { /* ignore */ }
        } else if (response.response_array) {
          try {
            const parsed = JSON.parse(response.response_array);
            if (Array.isArray(parsed) && parsed.length > 0) {
              if (typeof parsed[0] === "object") {
                meds = parsed;
              } else if (typeof parsed[0] === "string") {
                meds = parsed.map((cat: string) => ({ categoryId: cat }));
              }
            }
          } catch { /* ignore */ }
        }

        // Split into medications vs supplements
        for (const med of meds) {
          const entry = {
            categoryId: med.categoryId,
            medicationName: med.medicationName,
            dose: med.dose,
            timing: med.timingCategories,
          };
          // Only prescription and OTC are medications - everything else is a supplement
          if (MEDICATION_CATEGORIES.includes(med.categoryId)) {
            dayMap[day].medications.push(entry);
          } else {
            dayMap[day].supplements.push(entry);
          }
        }

        // Update flags based on what we found
        dayMap[day].tookMeds = dayMap[day].medications.length > 0;
        dayMap[day].tookSupplements = dayMap[day].supplements.length > 0;
      } else if (qid === "CSD_MEDS_OTHER" || qid === "SD_MEDS_OTHER") {
        if (response.response_value) {
          dayMap[day].medications.push({
            categoryId: "other",
            medicationName: response.response_value,
          });
          dayMap[day].tookMeds = true;
        }
      }

      // Caffeine
      else if (qid === "CSD_CAFFEINE") {
        if (response.response_value?.toLowerCase() === "yes") {
          dayMap[day].hadCaffeine = true;
        } else if (response.response_value?.toLowerCase() === "no") {
          dayMap[day].hadCaffeine = false;
        } else if (response.response_number !== undefined) {
          // Legacy: numeric count
          dayMap[day].hadCaffeine = response.response_number > 0;
        }
      } else if (qid === "CSD_CAFFEINE_TYPES") {
        if (response.response_array) {
          try {
            const entries = JSON.parse(response.response_array) as Array<{ typeId: string; count: number }>;
            dayMap[day].caffeineEntries = entries;
            dayMap[day].hadCaffeine = entries.length > 0;
            // Calculate total mg
            dayMap[day].totalCaffeineMg = entries.reduce((sum, e) => {
              const mgPerServing = CAFFEINE_TYPE_INFO[e.typeId]?.mgPerServing || 95;
              return sum + (mgPerServing * e.count);
            }, 0);
          } catch { /* ignore */ }
        }
      } else if (qid === "CSD_CAFFEINE_LAST") {
        dayMap[day].lastCaffeineTime = response.response_value || undefined;
      }
    }

    // Add sleep quality data
    for (const sleep of sleepData) {
      const day = sleep.day_number ?? 1;
      if (day <= daysToFetch && dayMap[day]) {
        dayMap[day].sleepQuality = sleep.subjective_quality;
        dayMap[day].sleepDurationMins = sleep.total_sleep_mins;
        dayMap[day].sleepEfficiency = sleep.sleep_efficiency;
        if (sleep.date) {
          dayMap[day].date = sleep.date;
        }
      }
    }

    // Convert to array sorted by day
    const dailyData = Object.values(dayMap).sort((a, b) => a.dayNumber - b.dayNumber);

    // Calculate aggregates
    const napDays = dailyData.filter(d => d.tookNaps).length;
    const medDays = dailyData.filter(d => d.tookMeds).length;
    const supplementDays = dailyData.filter(d => d.tookSupplements).length;
    const caffeineDays = dailyData.filter(d => d.hadCaffeine).length;
    const totalDays = dailyData.filter(d =>
      d.tookNaps !== undefined || d.tookMeds !== undefined || d.hadCaffeine !== undefined
    ).length;

    // Aggregate medication categories
    const medCategoryCounts: Record<string, { count: number; names: string[]; doses: string[] }> = {};
    const supplementCategoryCounts: Record<string, { count: number; names: string[]; doses: string[] }> = {};
    const caffeineCategoryCounts: Record<string, { count: number; totalServings: number }> = {};

    for (const day of dailyData) {
      for (const med of day.medications) {
        if (!medCategoryCounts[med.categoryId]) {
          medCategoryCounts[med.categoryId] = { count: 0, names: [], doses: [] };
        }
        medCategoryCounts[med.categoryId].count++;
        if (med.medicationName && !medCategoryCounts[med.categoryId].names.includes(med.medicationName)) {
          medCategoryCounts[med.categoryId].names.push(med.medicationName);
        }
        if (med.dose && !medCategoryCounts[med.categoryId].doses.includes(med.dose)) {
          medCategoryCounts[med.categoryId].doses.push(med.dose);
        }
      }

      for (const supp of day.supplements) {
        if (!supplementCategoryCounts[supp.categoryId]) {
          supplementCategoryCounts[supp.categoryId] = { count: 0, names: [], doses: [] };
        }
        supplementCategoryCounts[supp.categoryId].count++;
        if (supp.name && !supplementCategoryCounts[supp.categoryId].names.includes(supp.name)) {
          supplementCategoryCounts[supp.categoryId].names.push(supp.name);
        }
        if (supp.dose && !supplementCategoryCounts[supp.categoryId].doses.includes(supp.dose)) {
          supplementCategoryCounts[supp.categoryId].doses.push(supp.dose);
        }
      }

      for (const caff of day.caffeineEntries) {
        if (!caffeineCategoryCounts[caff.typeId]) {
          caffeineCategoryCounts[caff.typeId] = { count: 0, totalServings: 0 };
        }
        caffeineCategoryCounts[caff.typeId].count++;
        caffeineCategoryCounts[caff.typeId].totalServings += caff.count;
      }
    }

    // Category info for display
    const medCategoryInfo: Record<string, string> = {
      prescription: "Prescription",
      otc: "OTC Sleep Aid",
      other: "Other",
    };

    // Use SUPPLEMENT_DISPLAY_NAMES defined at top of section for lookups

    return {
      // Rolling daily data
      dailyData,
      totalDays,

      // Nap summary
      naps: {
        daysWithNaps: napDays,
        avgNapMinutes: napDays > 0
          ? Math.round(dailyData.filter(d => d.tookNaps).reduce((sum, d) => sum + d.totalNapMinutes, 0) / napDays)
          : 0,
        commonTimes: [...new Set(dailyData.flatMap(d => d.napDetails.map(n => n.startTime)).filter(Boolean))].slice(0, 5),
      },

      // Medication summary (prescription/OTC only)
      medications: {
        daysUsing: medDays,
        categories: Object.entries(medCategoryCounts).map(([id, data]) => ({
          id,
          name: medCategoryInfo[id] || id,
          count: data.count,
          medicationNames: data.names,
          doses: data.doses,
        })).sort((a, b) => b.count - a.count),
      },

      // Supplement summary (melatonin, magnesium, herbal, cbd)
      supplements: {
        daysUsing: supplementDays,
        categories: Object.entries(supplementCategoryCounts).map(([id, data]) => ({
          id,
          name: SUPPLEMENT_DISPLAY_NAMES[id] || id,
          count: data.count,
          doses: data.doses,
        })).sort((a, b) => b.count - a.count),
      },

      // Caffeine summary
      caffeine: {
        daysWithCaffeine: caffeineDays,
        avgDailyMg: caffeineDays > 0
          ? Math.round(dailyData.filter(d => d.hadCaffeine).reduce((sum, d) => sum + d.totalCaffeineMg, 0) / caffeineDays)
          : 0,
        categories: Object.entries(caffeineCategoryCounts).map(([id, data]) => ({
          id,
          name: CAFFEINE_TYPE_INFO[id]?.name || id,
          daysUsed: data.count,
          totalServings: data.totalServings,
        })).sort((a, b) => b.totalServings - a.totalServings),
      },
    };
  },
});

/**
 * Get subjective sleep quality data from sleep log responses
 * Returns daily quality ratings and calculated perceived sleep efficiency
 * Works even without wearable - uses questionnaire responses only
 */
export const getSubjectiveSleepQuality = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const daysToFetch = args.days ?? 14;

    // Get sleep quality and sleep diary responses
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .filter((q) =>
        q.or(
          // Sleep quality questions
          q.eq(q.field("question_id"), "CSD_QUALITY"),
          q.eq(q.field("question_id"), "SD_SLEEP_QUALITY"),
          q.eq(q.field("question_id"), "SL_QUALITY"),
          // Time metrics for efficiency calculation
          q.eq(q.field("question_id"), "CSD_INTO_BED"),
          q.eq(q.field("question_id"), "CSD_OUT_BED"),
          q.eq(q.field("question_id"), "CSD_LATENCY"),
          q.eq(q.field("question_id"), "CSD_WASO"),
          q.eq(q.field("question_id"), "CSD_TRY_SLEEP"),
          q.eq(q.field("question_id"), "CSD_FINAL_WAKE"),
          // Stanford versions
          q.eq(q.field("question_id"), "SD_GOT_INTO_BED"),
          q.eq(q.field("question_id"), "SD_OUT_OF_BED"),
          q.eq(q.field("question_id"), "SD_SLEEP_LATENCY"),
          q.eq(q.field("question_id"), "SD_AWAKENINGS_DURATION"),
          q.eq(q.field("question_id"), "SL_BEDTIME"),
          q.eq(q.field("question_id"), "SL_OUT_OF_BED"),
          q.eq(q.field("question_id"), "SL_AWAKENINGS")
        )
      )
      .collect();

    // Build day-by-day data
    type DaySleepData = {
      dayNumber: number;
      date?: string;
      quality: number | null; // 1-10 scale
      intoBedTime: number | null; // minutes from midnight
      outOfBedTime: number | null;
      latencyMins: number | null;
      wasoMins: number | null;
      timeInBedMins: number | null;
      totalSleepMins: number | null;
      perceivedEfficiency: number | null; // 0-100%
    };

    const dayMap: Record<number, DaySleepData> = {};

    // Initialize days
    for (let i = 1; i <= daysToFetch; i++) {
      dayMap[i] = {
        dayNumber: i,
        quality: null,
        intoBedTime: null,
        outOfBedTime: null,
        latencyMins: null,
        wasoMins: null,
        timeInBedMins: null,
        totalSleepMins: null,
        perceivedEfficiency: null,
      };
    }

    // Helper to parse time string to minutes from midnight
    const parseTimeToMins = (timeStr: string | null | undefined): number | null => {
      if (!timeStr) return null;
      const match = timeStr.match(/(\d{1,2}):(\d{2})/);
      if (!match) return null;
      const hours = parseInt(match[1], 10);
      const minutes = parseInt(match[2], 10);
      return hours * 60 + minutes;
    };

    // Process responses
    for (const r of responses) {
      const day = r.day_number ?? 1;
      if (day > daysToFetch || !dayMap[day]) continue;

      const qid = r.question_id;
      dayMap[day].date = r.created_at ? new Date(r.created_at).toISOString().split("T")[0] : undefined;

      // Sleep quality (1-10)
      if (qid === "CSD_QUALITY" || qid === "SD_SLEEP_QUALITY" || qid === "SL_QUALITY") {
        const val = r.response_number ?? parseFloat(r.response_value || "");
        if (!isNaN(val)) {
          dayMap[day].quality = val;
        }
      }
      // Into bed time
      else if (qid === "CSD_INTO_BED" || qid === "SD_GOT_INTO_BED" || qid === "SL_BEDTIME") {
        dayMap[day].intoBedTime = parseTimeToMins(r.response_value);
      }
      // Out of bed time
      else if (qid === "CSD_OUT_BED" || qid === "SD_OUT_OF_BED" || qid === "SL_OUT_OF_BED") {
        dayMap[day].outOfBedTime = parseTimeToMins(r.response_value);
      }
      // Sleep latency (minutes to fall asleep)
      else if (qid === "CSD_LATENCY" || qid === "SD_SLEEP_LATENCY") {
        const val = r.response_number ?? parseFloat(r.response_value || "");
        if (!isNaN(val)) {
          dayMap[day].latencyMins = val;
        }
      }
      // WASO (wake after sleep onset)
      else if (qid === "CSD_WASO" || qid === "SD_AWAKENINGS_DURATION" || qid === "SL_AWAKENINGS") {
        const val = r.response_number ?? parseFloat(r.response_value || "");
        if (!isNaN(val)) {
          dayMap[day].wasoMins = val;
        }
      }
    }

    // Calculate derived metrics for each day
    for (const day of Object.values(dayMap)) {
      // Calculate Time in Bed
      if (day.intoBedTime !== null && day.outOfBedTime !== null) {
        if (day.outOfBedTime > day.intoBedTime) {
          // Same day (e.g., 23:00 to 07:00 next day doesn't apply here)
          day.timeInBedMins = day.outOfBedTime - day.intoBedTime;
        } else {
          // Crossed midnight: e.g., 23:00 to 07:00 = 8 hours
          day.timeInBedMins = (24 * 60 - day.intoBedTime) + day.outOfBedTime;
        }
      }

      // Calculate Total Sleep Time = Time in Bed - Latency - WASO
      if (day.timeInBedMins !== null) {
        const latency = day.latencyMins ?? 0;
        const waso = day.wasoMins ?? 0;
        day.totalSleepMins = Math.max(0, day.timeInBedMins - latency - waso);
      }

      // Calculate Perceived Sleep Efficiency = (Total Sleep / Time in Bed) × 100
      if (day.totalSleepMins !== null && day.timeInBedMins !== null && day.timeInBedMins > 0) {
        day.perceivedEfficiency = Math.round((day.totalSleepMins / day.timeInBedMins) * 100);
      }
    }

    // Convert to array and filter to days with data
    const dailyData = Object.values(dayMap)
      .filter(d => d.quality !== null || d.perceivedEfficiency !== null)
      .sort((a, b) => a.dayNumber - b.dayNumber);

    // Calculate averages
    const qualityValues = dailyData.filter(d => d.quality !== null).map(d => d.quality!);
    const efficiencyValues = dailyData.filter(d => d.perceivedEfficiency !== null).map(d => d.perceivedEfficiency!);
    const sleepDurations = dailyData.filter(d => d.totalSleepMins !== null).map(d => d.totalSleepMins!);

    return {
      dailyData,
      summary: {
        daysWithData: dailyData.length,
        avgQuality: qualityValues.length > 0
          ? Math.round(qualityValues.reduce((a, b) => a + b, 0) / qualityValues.length * 10) / 10
          : null,
        avgPerceivedEfficiency: efficiencyValues.length > 0
          ? Math.round(efficiencyValues.reduce((a, b) => a + b, 0) / efficiencyValues.length)
          : null,
        avgSleepDurationMins: sleepDurations.length > 0
          ? Math.round(sleepDurations.reduce((a, b) => a + b, 0) / sleepDurations.length)
          : null,
      },
      hasSubjectiveData: dailyData.length > 0,
    };
  },
});

// ============================================
// Activity & Light Exposure Module
// ============================================

/**
 * Get comprehensive activity and light exposure data for physician dashboard
 * Combines activity metrics with circadian/light exposure data
 */
export const getPatientActivityAndCircadian = query({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, days = 14 } = args;

    // Get activity data
    const activityData = await ctx.db
      .query("user_activity")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Get circadian data
    const circadianData = await ctx.db
      .query("user_circadian_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Get workout data for outdoor activity context
    const workoutData = await ctx.db
      .query("user_workouts")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Create date range for last N days
    const now = new Date();
    const dateRange: string[] = [];
    for (let i = 0; i < days; i++) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      dateRange.push(d.toISOString().split("T")[0]);
    }

    // Build daily data map
    const dailyData: Array<{
      date: string;
      dayOfWeek: string;
      // Activity metrics
      steps?: number;
      activeMins?: number;
      exerciseMins?: number;
      caloriesBurned?: number;
      // Light exposure metrics
      daylightMins?: number;
      morningLightMins?: number;
      afternoonLightMins?: number;
      outdoorWorkoutMins?: number;
      // Circadian health
      circadianScore?: number;
      tempDeviation?: number;
      // Calculated
      hasActivityData: boolean;
      hasLightData: boolean;
    }> = [];

    for (const dateStr of dateRange) {
      const dayOfWeek = new Date(dateStr).toLocaleDateString("en-US", { weekday: "short" });

      // Find activity for this date
      const activity = activityData.find((a) => a.date === dateStr);

      // Find circadian for this date
      const circadian = circadianData.find((c) => c.date === dateStr);

      // Find outdoor workouts for this date
      const outdoorWorkouts = workoutData.filter(
        (w) => w.date === dateStr && w.was_outdoor === true
      );
      const outdoorWorkoutMins = outdoorWorkouts.reduce((sum, w) => sum + (w.duration_mins || 0), 0);

      dailyData.push({
        date: dateStr,
        dayOfWeek,
        // Activity
        steps: activity?.steps,
        activeMins: activity?.active_mins,
        exerciseMins: activity?.exercise_mins,
        caloriesBurned: activity?.calories_burned,
        // Light
        daylightMins: circadian?.time_in_daylight_mins,
        morningLightMins: circadian?.morning_light_mins,
        afternoonLightMins: circadian?.afternoon_light_mins,
        outdoorWorkoutMins: outdoorWorkoutMins > 0 ? outdoorWorkoutMins : circadian?.outdoor_workout_mins,
        // Circadian
        circadianScore: circadian?.circadian_score,
        tempDeviation: circadian?.sleeping_wrist_temp_deviation,
        // Flags
        hasActivityData: !!activity,
        hasLightData: !!circadian,
      });
    }

    // Calculate averages and summaries
    const daysWithActivity = dailyData.filter((d) => d.hasActivityData).length;
    const daysWithLight = dailyData.filter((d) => d.hasLightData).length;

    // Activity averages
    const stepsValues = dailyData.filter((d) => d.steps != null).map((d) => d.steps!);
    const activeValues = dailyData.filter((d) => d.activeMins != null).map((d) => d.activeMins!);
    const exerciseValues = dailyData.filter((d) => d.exerciseMins != null).map((d) => d.exerciseMins!);

    const avgSteps = stepsValues.length > 0
      ? Math.round(stepsValues.reduce((a, b) => a + b, 0) / stepsValues.length)
      : null;
    const avgActiveMins = activeValues.length > 0
      ? Math.round(activeValues.reduce((a, b) => a + b, 0) / activeValues.length)
      : null;
    const avgExerciseMins = exerciseValues.length > 0
      ? Math.round(exerciseValues.reduce((a, b) => a + b, 0) / exerciseValues.length)
      : null;

    // Light exposure averages
    const daylightValues = dailyData.filter((d) => d.daylightMins != null).map((d) => d.daylightMins!);
    const morningValues = dailyData.filter((d) => d.morningLightMins != null).map((d) => d.morningLightMins!);
    const circadianValues = dailyData.filter((d) => d.circadianScore != null).map((d) => d.circadianScore!);

    const avgDaylightMins = daylightValues.length > 0
      ? Math.round(daylightValues.reduce((a, b) => a + b, 0) / daylightValues.length)
      : null;
    const avgMorningLightMins = morningValues.length > 0
      ? Math.round(morningValues.reduce((a, b) => a + b, 0) / morningValues.length)
      : null;
    const avgCircadianScore = circadianValues.length > 0
      ? Math.round(circadianValues.reduce((a, b) => a + b, 0) / circadianValues.length)
      : null;

    // Calculate trends (comparing first half to second half)
    let stepsTrend: "improving" | "declining" | "stable" | null = null;
    let lightTrend: "improving" | "declining" | "stable" | null = null;

    if (stepsValues.length >= 4) {
      const mid = Math.floor(stepsValues.length / 2);
      // Note: dailyData is in descending order (most recent first)
      const recentAvg = stepsValues.slice(0, mid).reduce((a, b) => a + b, 0) / mid;
      const olderAvg = stepsValues.slice(mid).reduce((a, b) => a + b, 0) / (stepsValues.length - mid);
      const diff = recentAvg - olderAvg;
      if (diff > avgSteps! * 0.1) stepsTrend = "improving";
      else if (diff < -avgSteps! * 0.1) stepsTrend = "declining";
      else stepsTrend = "stable";
    }

    if (daylightValues.length >= 4) {
      const mid = Math.floor(daylightValues.length / 2);
      const recentAvg = daylightValues.slice(0, mid).reduce((a, b) => a + b, 0) / mid;
      const olderAvg = daylightValues.slice(mid).reduce((a, b) => a + b, 0) / (daylightValues.length - mid);
      const diff = recentAvg - olderAvg;
      if (diff > 10) lightTrend = "improving";
      else if (diff < -10) lightTrend = "declining";
      else lightTrend = "stable";
    }

    // Generate clinical notes
    const clinicalNotes: string[] = [];

    // Activity-related notes
    if (avgSteps !== null) {
      if (avgSteps < 5000) {
        clinicalNotes.push("Low activity level (<5000 steps/day) - sedentary behavior may impact sleep");
      } else if (avgSteps >= 10000) {
        clinicalNotes.push("Good activity level (10000+ steps/day) - supports healthy sleep");
      }
    }

    if (avgExerciseMins !== null && avgExerciseMins < 20) {
      clinicalNotes.push("Limited structured exercise - recommend 150 min/week moderate activity");
    }

    // Light exposure notes
    if (avgDaylightMins !== null) {
      if (avgDaylightMins < 30) {
        clinicalNotes.push("Critical: Very low daylight exposure (<30 min) - significant circadian impact");
      } else if (avgDaylightMins < 60) {
        clinicalNotes.push("Low daylight exposure - may contribute to circadian rhythm issues");
      } else if (avgDaylightMins >= 90) {
        clinicalNotes.push("Excellent daylight exposure supporting circadian rhythm");
      }
    }

    if (avgMorningLightMins !== null && avgMorningLightMins < 15) {
      clinicalNotes.push("Minimal morning light - consider morning light therapy for circadian entrainment");
    }

    if (avgCircadianScore !== null && avgCircadianScore < 50) {
      clinicalNotes.push("Low circadian health score - review light exposure timing and consistency");
    }

    return {
      // Daily data for charts
      dailyData: dailyData.reverse(), // Oldest to newest for charts

      // Activity summary
      activitySummary: {
        daysWithData: daysWithActivity,
        avgSteps,
        avgActiveMins,
        avgExerciseMins,
        trend: stepsTrend,
        hasData: daysWithActivity > 0,
      },

      // Light exposure summary
      lightSummary: {
        daysWithData: daysWithLight,
        avgDaylightMins,
        avgMorningLightMins,
        avgCircadianScore,
        trend: lightTrend,
        hasData: daysWithLight > 0,
      },

      // Clinical interpretation
      clinicalNotes,

      // Overall status
      hasAnyData: daysWithActivity > 0 || daysWithLight > 0,
    };
  },
});

