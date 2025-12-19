import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";
import { validatePhysicianRole, validateIOSSession } from "./auth";

// ============================================
// Question Definitions - Single Source of Truth
// ============================================

// Stanford Sleep Log questions (SL_ prefix - used by Watch quick log)
const SLEEP_LOG_QUESTIONS: Record<string, { text: string; type: string }> = {
  // Watch/iPhone quick sleep log (SL_ prefix)
  "SL_BEDTIME": { text: "What time did you go to bed last night?", type: "time" },
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
  "SD_GOT_INTO_BED": { text: "What time did you get into bed last night?", type: "time" },
  "SD_LIGHTS_OUT": { text: "What time did you turn off the lights to sleep?", type: "time" },
  "SD_SLEEP_ONSET": { text: "What time do you think you fell asleep?", type: "time" },
  "SD_SLEEP_LATENCY": { text: "How long did it take you to fall asleep? (minutes)", type: "minutes" },
  "SD_AWAKENINGS_COUNT": { text: "How many times did you wake up during the night?", type: "number" },
  "SD_AWAKENINGS_DURATION": { text: "Total time awake during the night (minutes)", type: "minutes" },
  "SD_FINAL_WAKE": { text: "What time did you wake up for the final time?", type: "time" },
  "SD_OUT_OF_BED": { text: "What time did you get out of bed this morning?", type: "time" },
  "SD_SLEEP_QUALITY": { text: "How would you rate your sleep quality?", type: "scale" },
  "SD_NAPS_TAKEN": { text: "Did you take any naps yesterday?", type: "yes_no" },
  "SD_NAPS_COUNT": { text: "How many naps did you take?", type: "number" },
  "SD_NAP_DETAILS": { text: "For each nap, record the start time and duration.", type: "repeating_group" },
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
  "CSD_NAP_DURATION": { text: "Total nap duration (minutes)", type: "minutes" },
  "CSD_CAFFEINE": { text: "How many caffeinated drinks did you have?", type: "number" },
  "CSD_CAFFEINE_LAST": { text: "When was your last caffeine?", type: "time" },
  "CSD_ALCOHOL": { text: "Did you consume alcohol yesterday?", type: "yes_no" },
  "CSD_ALCOHOL_DRINKS": { text: "How many alcoholic drinks?", type: "number" },
  "CSD_ALCOHOL_LAST": { text: "When was your last alcoholic drink?", type: "time" },
  "CSD_MEDS": { text: "Did you take any sleep aids or medications?", type: "yes_no" },
  "CSD_MEDS_NAME": { text: "What sleep aids/medications did you take?", type: "text" },
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
function calculateSTOPBANG(responses: Map<string, number>, demographics: { age?: number; sex?: string; bmi?: number }): QuestionnaireScore {
  let score = 0;
  let answered = 0;

  // S - Snore (question 19)
  const snore = responses.get("19");
  if (snore !== undefined) { if (snore === 1) score++; answered++; }

  // T - Tired (question 17) - 5-point scale: Never(0), Rarely(1), Sometimes(2), Often(3), Always(4)
  // Q21 was removed from iOS as redundant with Q17. Score point if Often (3) or Always (4)
  const tired = responses.get("17");
  if (tired !== undefined) { if (tired >= 3) score++; answered++; }

  // O - Observed apnea (question 20)
  const observed = responses.get("20");
  if (observed !== undefined) { if (observed === 1) score++; answered++; }

  // P - Pressure (high blood pressure, question 27)
  const pressure = responses.get("27");
  if (pressure !== undefined) { if (pressure === 1) score++; answered++; }

  // B - BMI > 35
  if (demographics.bmi !== undefined) {
    if (demographics.bmi > 35) score++;
    answered++;
  }

  // A - Age > 50
  if (demographics.age !== undefined) {
    if (demographics.age > 50) score++;
    answered++;
  }

  // N - Neck circumference > 40cm (usually not collected, skip)

  // G - Gender = Male
  if (demographics.sex !== undefined) {
    if (demographics.sex.toLowerCase() === "male") score++;
    answered++;
  }

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

  // Component 5: Sleep Disturbances (PSQI_5b through PSQI_5j sum)
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
  if (disturbanceCount >= 5) {
    if (disturbanceSum === 0) totalScore += 0;
    else if (disturbanceSum <= 9) totalScore += 1;
    else if (disturbanceSum <= 18) totalScore += 2;
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

// DBAS-16 (Dysfunctional Beliefs and Attitudes about Sleep) - 16 questions, each 0-10
function calculateDBAS16(responses: Map<string, number>): QuestionnaireScore {
  const dbasQuestions = Array.from({ length: 16 }, (_, i) => `DBAS_${i + 1}`);
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

  if (answered >= 12) {
    // Average score (total / answered, then scaled to 0-10)
    const avgScore = total / answered;
    const score = Math.round(avgScore * 10) / 10; // One decimal place

    if (score <= 3) { interpretation = "Low dysfunctional beliefs about sleep"; severity = "normal"; }
    else if (score <= 5) { interpretation = "Moderate dysfunctional beliefs"; severity = "mild"; }
    else if (score <= 7) { interpretation = "Elevated dysfunctional beliefs"; severity = "moderate"; }
    else { interpretation = "High dysfunctional beliefs about sleep"; severity = "severe"; }

    return { name: "Dysfunctional Beliefs and Attitudes about Sleep", abbreviation: "DBAS-16", score: Math.round(total), maxScore: 160, interpretation, severity, questionsAnswered: answered, questionsRequired: 16 };
  }

  return { name: "Dysfunctional Beliefs and Attitudes about Sleep", abbreviation: "DBAS-16", score: null, maxScore: 160, interpretation, severity, questionsAnswered: answered, questionsRequired: 16 };
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
    // Mean score
    const meanScore = total / answered;
    const score = Math.round(meanScore * 10) / 10;

    if (score < 4) { interpretation = "No significant fatigue"; severity = "normal"; }
    else if (score < 5) { interpretation = "Mild fatigue"; severity = "mild"; }
    else if (score < 6) { interpretation = "Moderate fatigue"; severity = "moderate"; }
    else { interpretation = "Severe fatigue"; severity = "severe"; }

    return { name: "Fatigue Severity Scale", abbreviation: "FSS", score: Math.round(total), maxScore: 63, interpretation, severity, questionsAnswered: answered, questionsRequired: 9 };
  }

  return { name: "Fatigue Severity Scale", abbreviation: "FSS", score: null, maxScore: 63, interpretation, severity, questionsAnswered: answered, questionsRequired: 9 };
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
  // Severity items: worst, least, average, now (BPI_3 to BPI_6)
  const severityItems = ["BPI_3", "BPI_4", "BPI_5", "BPI_6"];
  // Interference items: general activity, mood, walking, work, relations, sleep, enjoyment (BPI_9a to BPI_9g)
  const interferenceItems = ["BPI_9a", "BPI_9b", "BPI_9c", "BPI_9d", "BPI_9e", "BPI_9f", "BPI_9g"];

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

        // Calculate progress percentage (15 days total)
        const progressPercentage = Math.min(
          Math.round((user.current_day / 15) * 100),
          100
        );

        return {
          _id: user._id,
          username: user.username,
          name: nameResponse?.response_value || user.username, // Use username as fallback
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
      name: nameResponse?.response_value || user.username, // Use username as fallback
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

        // Combine response_value, response_number, and response_array into a displayable value
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

        return {
          _id: response._id,
          question_id: response.question_id,
          response_value: displayValue,
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
  returns: v.optional(
    v.object({
      _id: v.id("patient_visible_fields"),
      field_config_json: v.string(),
      updated_at: v.number(),
      updated_by_physician_id: v.optional(v.string()),
    })
  ),
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
      responseCount: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return [];

    // Get all responses for this user
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sleep log question IDs (CSD = Consensus Sleep Diary, SL = Sleep Log, SD = Sleep Diary)
    const sleepLogPrefixes = ["CSD_", "SL_", "SD_"];

    // Group responses by day
    const dayData: Record<
      number,
      {
        sleepLogQuestions: Set<string>;
        assessmentQuestions: Set<string>;
        responseCount: number;
      }
    > = {};

    for (const response of responses) {
      const day = response.day_number ?? 1;
      if (!dayData[day]) {
        dayData[day] = {
          sleepLogQuestions: new Set(),
          assessmentQuestions: new Set(),
          responseCount: 0,
        };
      }
      dayData[day].responseCount++;

      const isSleepLog = sleepLogPrefixes.some((prefix) =>
        response.question_id.startsWith(prefix)
      );
      if (isSleepLog) {
        dayData[day].sleepLogQuestions.add(response.question_id);
      } else {
        dayData[day].assessmentQuestions.add(response.question_id);
      }
    }

    // Build result for each day up to current_day
    const result: {
      dayNumber: number;
      date: string;
      sleepLogCompleted: boolean;
      assessmentCompleted: boolean;
      responseCount: number;
    }[] = [];

    for (let day = 1; day <= user.current_day; day++) {
      const data = dayData[day];
      const date = new Date(user.started_at + (day - 1) * 86400000)
        .toISOString()
        .split("T")[0];

      result.push({
        dayNumber: day,
        date,
        // Sleep log is complete if at least 3 sleep-related questions answered
        sleepLogCompleted: data ? data.sleepLogQuestions.size >= 3 : false,
        // Assessment is complete if at least 1 non-sleep-log question answered
        assessmentCompleted: data ? data.assessmentQuestions.size > 0 : false,
        responseCount: data?.responseCount ?? 0,
      });
    }

    return result;
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
      "Mental Health": ["PHQ-9", "GAD-7"],
      "Sleep Quality": ["ISI", "PSQI"],
      Cognitive: ["DBAS-16"],
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
    })
  ),
  handler: async (ctx, args) => {
    // Hardcoded question texts for standardized questionnaires
    // (These are defined in iOS QuestionnaireManager.swift but not synced to Convex)
    const questionTexts: Record<string, string> = {
      // PHQ-9 - Patient Health Questionnaire (Depression)
      "PHQ9_1": "Over the last 2 weeks: Little interest or pleasure in doing things?",
      "PHQ9_2": "Over the last 2 weeks: Feeling down, depressed, or hopeless?",
      "PHQ9_3": "Over the last 2 weeks: Trouble falling or staying asleep, or sleeping too much?",
      "PHQ9_4": "Over the last 2 weeks: Feeling tired or having little energy?",
      "PHQ9_5": "Over the last 2 weeks: Poor appetite or overeating?",
      "PHQ9_6": "Over the last 2 weeks: Feeling bad about yourself - or that you are a failure?",
      "PHQ9_7": "Over the last 2 weeks: Trouble concentrating on things?",
      "PHQ9_8": "Over the last 2 weeks: Moving or speaking slowly, or being fidgety/restless?",
      "PHQ9_9": "Over the last 2 weeks: Thoughts that you would be better off dead or of hurting yourself?",

      // GAD-7 - Generalized Anxiety Disorder
      "GAD7_1": "Over the last 2 weeks: Feeling nervous, anxious, or on edge?",
      "GAD7_2": "Over the last 2 weeks: Not being able to stop or control worrying?",
      "GAD7_3": "Over the last 2 weeks: Worrying too much about different things?",
      "GAD7_4": "Over the last 2 weeks: Trouble relaxing?",
      "GAD7_5": "Over the last 2 weeks: Being so restless that it is hard to sit still?",
      "GAD7_6": "Over the last 2 weeks: Becoming easily annoyed or irritable?",
      "GAD7_7": "Over the last 2 weeks: Feeling afraid, as if something awful might happen?",

      // ISI - Insomnia Severity Index
      "ISI_1": "Difficulty falling asleep?",
      "ISI_2": "Difficulty staying asleep?",
      "ISI_3": "Problems waking up too early?",
      "ISI_4": "How satisfied are you with your current sleep pattern?",
      "ISI_5": "How noticeable to others is your sleep problem affecting your daily functioning?",
      "ISI_6": "How worried are you about your current sleep problem?",
      "ISI_7": "How much is your sleep problem interfering with your daily functioning?",

      // ESS - Epworth Sleepiness Scale
      "ESS_1": "Chance of dozing: Sitting and reading?",
      "ESS_2": "Chance of dozing: Watching TV?",
      "ESS_3": "Chance of dozing: Sitting inactive in a public place (theater/meeting)?",
      "ESS_4": "Chance of dozing: As a passenger in a car for an hour?",
      "ESS_5": "Chance of dozing: Lying down to rest in the afternoon?",
      "ESS_6": "Chance of dozing: Sitting and talking to someone?",
      "ESS_7": "Chance of dozing: Sitting quietly after lunch without alcohol?",
      "ESS_8": "Chance of dozing: In a car while stopped for a few minutes in traffic?",

      // STOP-BANG - Sleep Apnea Screening (uses numeric IDs from gateway questions)
      "19": "Do you snore loudly?",
      "20": "Has anyone observed you stop breathing during sleep?",
      "17": "Do you feel excessively tired or sleepy during the day?", // Q21 removed, use Q17 (5-point scale)
      "27": "Do you have or are you being treated for high blood pressure?",
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

      // STOP-BANG - Sleep Apnea Screening (uses numeric question IDs)
      // Note: Q21 removed from iOS, use Q17 instead (5-point tiredness scale)
      "STOP-BANG": ["19", "20", "17", "27"],
      "STOP-BANG Sleep Apnea Screening": ["19", "20", "17", "27"],
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
    }> = [];

    for (const qId of questionIds) {
      const response = responses.find((r) => r.question_id === qId);
      if (response && (response.response_value || response.response_number !== undefined)) {
        result.push({
          questionId: qId,
          questionText: questionTexts[qId] || `Question ${qId}`,
          responseValue: response.response_value || String(response.response_number ?? ""),
          responseNumber: response.response_number,
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
      calculateDBAS16(responseMap),
      calculateBerlin(responseMap, { bmi: demographics.bmi }),
      calculateFSS(responseMap),
      calculateFOSQ10(responseMap),
      calculateMEDAS(responseMap),
      calculateMEQ(responseMap),
    ];

    // Add DASS-21 subscales
    const dass21 = calculateDASS21(responseMap);
    scores.push(dass21.depression, dass21.anxiety, dass21.stress);

    // Add BPI subscales
    const bpi = calculateBPI(responseMap);
    scores.push(bpi.severity, bpi.interference);

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
                  (responseMap.get("20") === 1), // observed apnea
      excessiveSleepiness: (responseMap.get("17") !== undefined && responseMap.get("17")! >= 3), // often/always tired
      pain: (responseMap.get("22") === 1), // pain affects sleep
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
      calculateDBAS16(responseMap),
      calculateBerlin(responseMap, { bmi: demographics.bmi }),
      calculateFSS(responseMap),
      calculateFOSQ10(responseMap),
      calculateMEDAS(responseMap),
      calculateMEQ(responseMap),
    ];

    // Add DASS-21 subscales
    const dass21 = calculateDASS21(responseMap);
    scores.push(dass21.depression, dass21.anxiety, dass21.stress);

    // Add BPI subscales
    const bpi = calculateBPI(responseMap);
    scores.push(bpi.severity, bpi.interference);

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
    // Validate dayNumber is 1-15
    if (args.dayNumber < 1 || args.dayNumber > 15) {
      throw new Error("Day must be between 1 and 15");
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

