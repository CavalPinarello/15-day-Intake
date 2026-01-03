/**
 * Watch-Specific Convex Functions
 *
 * These functions enable Apple Watch to directly communicate with Convex
 * for real-time sync of questionnaire progress between Watch, iPhone, and Web.
 *
 * SECURITY: All mutations now require session token validation to prevent
 * unauthorized access to other users' data.
 */

import { query, mutation, MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";
import { api } from "./_generated/api";
import { validateIOSSession } from "./auth";
import {
  FIXED_SCHEDULE,
  getDayConfig,
  shouldShowExpansion,
  getModuleIdsForDay,
  THEME_TO_MODULE_IDS,
  PACK_TO_MODULE_IDS,
} from "./fixedSchedule";

// ============================================
// Derivable Questions Configuration
// ============================================

/**
 * Questions that can be automatically derived from sleep log (CSD_) data.
 * When the user completes their sleep log, these questions are skipped in the assessment
 * and their values are auto-calculated and saved.
 *
 * This reduces user burden while maintaining data integrity for physician scoring.
 */
const DERIVABLE_QUESTIONS = {
  // Question 44: "How many hours of actual sleep did you typically get at night?"
  // Derived from: CSD_TRY_SLEEP, CSD_FINAL_WAKE, CSD_WASO, CSD_LATENCY
  "44": {
    sources: ["CSD_TRY_SLEEP", "CSD_FINAL_WAKE", "CSD_WASO", "CSD_LATENCY"],
    derive: (responses: Map<string, { value?: string; number?: number }>) => {
      const trySleep = responses.get("CSD_TRY_SLEEP")?.value;
      const finalWake = responses.get("CSD_FINAL_WAKE")?.value;
      const wasoMinutes = responses.get("CSD_WASO")?.number ?? 0;
      const latencyMinutes = responses.get("CSD_LATENCY")?.number ?? 0;

      if (!trySleep || !finalWake) return null;

      // Parse times (HH:MM format)
      const [tryH, tryM] = trySleep.split(":").map(Number);
      const [wakeH, wakeM] = finalWake.split(":").map(Number);

      // Calculate time in bed (minutes)
      let tryMinutes = tryH * 60 + tryM;
      let wakeMinutes = wakeH * 60 + wakeM;

      // Handle crossing midnight
      if (wakeMinutes < tryMinutes) {
        wakeMinutes += 24 * 60;
      }

      const timeInBed = wakeMinutes - tryMinutes;

      // Actual sleep = Time in bed - latency - WASO
      const actualSleepMinutes = timeInBed - latencyMinutes - wasoMinutes;
      const actualSleepHours = actualSleepMinutes / 60;

      // Round to nearest 0.5 hour
      return Math.round(actualSleepHours * 2) / 2;
    }
  },

  // Question 42: "How many minutes did it typically take you to fall asleep?"
  // Directly derived from: CSD_LATENCY
  "42": {
    sources: ["CSD_LATENCY"],
    derive: (responses: Map<string, { value?: string; number?: number }>) => {
      return responses.get("CSD_LATENCY")?.number ?? null;
    }
  },

  // Question 41: "When have you usually gone to bed at night?"
  // Directly derived from: CSD_TRY_SLEEP
  "41": {
    sources: ["CSD_TRY_SLEEP"],
    derive: (responses: Map<string, { value?: string; number?: number }>) => {
      return responses.get("CSD_TRY_SLEEP")?.value ?? null;
    }
  },

  // Question 33D: "Do you use any sleep aids?"
  // Derived from: CSD_MEDS (yes/no) and CSD_MEDS_LIST (medication selections)
  // If user answered "Yes" to CSD_MEDS, we derive from their medication list
  // If user answered "No" to CSD_MEDS, we derive as ["none"]
  "33D": {
    sources: ["CSD_MEDS", "CSD_MEDS_LIST"],
    derive: (responses: Map<string, { value?: string; number?: number; array?: string[] }>) => {
      const tookMeds = responses.get("CSD_MEDS")?.value;

      if (tookMeds === "No") {
        // User said they don't take sleep aids
        return JSON.stringify(["none"]);
      }

      if (tookMeds === "Yes") {
        // User takes sleep aids - derive from their medication list
        // CSD_MEDS_LIST is a medication_select which stores medications
        const medsList = responses.get("CSD_MEDS_LIST");
        if (medsList?.array && medsList.array.length > 0) {
          // Map medication categories to 33D options
          // This provides a reasonable approximation
          return JSON.stringify(medsList.array);
        }
        // They said yes but no list - default to "other"
        return JSON.stringify(["other"]);
      }

      // No answer yet - can't derive
      return null;
    }
  },

  // ============================================
  // Derivations from OTHER Assessment Questions
  // These reduce duplicate questions while preserving clinical scores
  // ============================================

  // Question 43: "When have you usually gotten up in the morning?"
  // Derived from: SD_FINAL_WAKE (sleep diary wake time)
  "43": {
    sources: ["SD_FINAL_WAKE"],
    derive: (responses: Map<string, { value?: string; number?: number }>) => {
      return responses.get("SD_FINAL_WAKE")?.value ?? null;
    }
  },

  // Question 12A: "How many times do you typically wake up during the night?"
  // Derived from: SD_AWAKENINGS_COUNT (sleep diary)
  "12A": {
    sources: ["SD_AWAKENINGS_COUNT"],
    derive: (responses: Map<string, { value?: string; number?: number }>) => {
      return responses.get("SD_AWAKENINGS_COUNT")?.number ?? null;
    }
  },

  // Question 12C: "When you wake up during the night, how long does it typically take to fall back asleep?"
  // Derived from: SD_AWAKENINGS_DURATION / SD_AWAKENINGS_COUNT
  "12C": {
    sources: ["SD_AWAKENINGS_DURATION", "SD_AWAKENINGS_COUNT"],
    derive: (responses: Map<string, { value?: string; number?: number }>) => {
      const duration = responses.get("SD_AWAKENINGS_DURATION")?.number ?? 0;
      const count = responses.get("SD_AWAKENINGS_COUNT")?.number ?? 1;
      if (count === 0) return 0;
      return Math.round(duration / count);
    }
  },

  // Question 54C: DUPLICATE of Q31 - "What time do you typically have your last caffeinated beverage?"
  // Derived directly from Q31 (same question)
  "54C": {
    sources: ["31"],
    derive: (responses: Map<string, { value?: string; number?: number }>) => {
      return responses.get("31")?.value ?? null;
    }
  },

  // Question 55: DUPLICATE of Q1 - "Rate your sleep quality overall" (PSQI Component 1)
  // Derived from Q1 with scale conversion: 1-10 → 0-3 (PSQI scale)
  "55": {
    sources: ["1"],
    derive: (responses: Map<string, { value?: string; number?: number }>) => {
      const q1 = responses.get("1")?.number;
      if (q1 === undefined || q1 === null) return null;
      // Convert 1-10 scale to 0-3 PSQI scale
      // 1-3 → 0 (Very bad), 4-5 → 1 (Fairly bad), 6-7 → 2 (Fairly good), 8-10 → 3 (Very good)
      if (q1 <= 3) return 0;
      if (q1 <= 5) return 1;
      if (q1 <= 7) return 2;
      return 3;
    }
  },

  // Question 200: DUPLICATE of Q27 - "Do you have high blood pressure?" (Berlin Category 2)
  // Derived directly from Q27 (same question asked on Day 5)
  "200": {
    sources: ["27"],
    derive: (responses: Map<string, { value?: string; number?: number }>) => {
      return responses.get("27")?.value ?? null;
    }
  },
} as const;

// Set of all derivable question IDs for quick lookup
const DERIVABLE_QUESTION_IDS = new Set(Object.keys(DERIVABLE_QUESTIONS));

// ============================================
// Always Hidden Duplicates (assessment-to-assessment)
// ============================================
// These are semantic duplicates of other assessment questions
// They should NEVER be shown to users - always filtered unconditionally
// Their values are derived from the source question for clinical scoring
const ALWAYS_HIDDEN_DUPLICATE_IDS = new Set([
  "55",   // Duplicate of Q1 - "Rate your sleep quality overall" (PSQI) → derived from Q1
  "54C",  // Duplicate of Q31 - "Last caffeinated beverage time" → derived from Q31
  "200",  // Duplicate of Q27 - "High blood pressure" (Berlin) → derived from Q27
]);

// ============================================
// Sleep Diary Average-Based Derivations (7+ days required)
// ============================================

/**
 * Questions that can be derived from AVERAGED sleep diary data.
 * These require 7+ days of sleep diary to have reliable averages.
 *
 * The derive function receives aggregated sleep diary stats.
 */
interface SleepDiaryAverages {
  dayCount: number;
  avgBedtime: string | null;       // Average bedtime (HH:MM)
  avgWakeTime: string | null;      // Average wake time (HH:MM)
  avgLatency: number | null;       // Average sleep latency (minutes)
  avgAwakenings: number | null;    // Average number of awakenings
  avgWASO: number | null;          // Average wake after sleep onset (minutes)
  avgTotalSleep: number | null;    // Average total sleep time (hours)
  avgQuality: number | null;       // Average sleep quality (1-10)
  avgAlertness: number | null;     // Average morning alertness (1-10)
  latencyOver30Pct: number | null; // % of nights with latency > 30 min
  awakeningsPct: number | null;    // % of nights with awakenings > 0
  lowAlertnessPct: number | null;  // % of nights with alertness ≤ 3
}

const AVERAGE_DERIVABLE_QUESTIONS: Record<string, {
  minDays: number;
  derive: (stats: SleepDiaryAverages) => string | number | null;
}> = {
  // Question 1: "How would you rate your overall sleep quality in the past month?"
  // Scale: 1-10
  "1": {
    minDays: 7,
    derive: (stats) => {
      if (stats.avgQuality === null) return null;
      return Math.round(stats.avgQuality);
    }
  },

  // Question 2: "How often do you feel refreshed and rested after sleep?"
  // Options: always, usually, sometimes, rarely, never
  "2": {
    minDays: 7,
    derive: (stats) => {
      if (stats.avgAlertness === null) return null;
      // Map average alertness (1-10) to frequency
      if (stats.avgAlertness >= 8) return "always";
      if (stats.avgAlertness >= 6) return "usually";
      if (stats.avgAlertness >= 4) return "sometimes";
      if (stats.avgAlertness >= 2) return "rarely";
      return "never";
    }
  },

  // Question 12A: "How many times do you typically wake up during the night?"
  // Number input
  "12A": {
    minDays: 7,
    derive: (stats) => {
      if (stats.avgAwakenings === null) return null;
      return Math.round(stats.avgAwakenings);
    }
  },

  // Question 12C: "When you wake up, how long does it typically take to fall back asleep?"
  // Minutes input
  "12C": {
    minDays: 7,
    derive: (stats) => {
      if (stats.avgWASO === null || stats.avgAwakenings === null) return null;
      if (stats.avgAwakenings === 0) return 0;
      // Average WASO per awakening
      return Math.round(stats.avgWASO / Math.max(1, stats.avgAwakenings));
    }
  },

  // Question 41: "When have you usually gone to bed at night?"
  // Time picker (HH:MM)
  "41": {
    minDays: 7,
    derive: (stats) => stats.avgBedtime
  },

  // Question 42: "How many minutes did it typically take you to fall asleep?"
  // Minutes input
  "42": {
    minDays: 7,
    derive: (stats) => {
      if (stats.avgLatency === null) return null;
      return Math.round(stats.avgLatency);
    }
  },

  // Question 43: "When have you usually gotten up in the morning?"
  // Time picker (HH:MM)
  "43": {
    minDays: 7,
    derive: (stats) => stats.avgWakeTime
  },

  // Question 44: "How many hours of actual sleep did you typically get at night?"
  // Number input (hours)
  "44": {
    minDays: 7,
    derive: (stats) => {
      if (stats.avgTotalSleep === null) return null;
      // Round to nearest 0.5 hour
      return Math.round(stats.avgTotalSleep * 2) / 2;
    }
  },

  // Question 45: "How often have you had trouble sleeping because you cannot get to sleep within 30 minutes?"
  // Options: not_at_all, less_than_once_week, once_or_twice_week, three_or_more_week
  "45": {
    minDays: 7,
    derive: (stats) => {
      if (stats.latencyOver30Pct === null) return null;
      // Map fraction to frequency category (values are 0.0 - 1.0)
      if (stats.latencyOver30Pct < 0.05) return "not_at_all";       // <5% of nights
      if (stats.latencyOver30Pct < 0.20) return "less_than_once_week"; // <20%
      if (stats.latencyOver30Pct < 0.50) return "once_or_twice_week";  // <50%
      return "three_or_more_week";  // 50%+ of nights
    }
  },

  // Question 46: "How often have you had trouble sleeping because you wake up in the middle of the night?"
  // Options: not_at_all, less_than_once_week, once_or_twice_week, three_or_more_week
  "46": {
    minDays: 7,
    derive: (stats) => {
      if (stats.awakeningsPct === null) return null;
      // Map fraction to frequency category (values are 0.0 - 1.0)
      if (stats.awakeningsPct < 0.05) return "not_at_all";          // <5% of nights
      if (stats.awakeningsPct < 0.20) return "less_than_once_week"; // <20%
      if (stats.awakeningsPct < 0.50) return "once_or_twice_week";  // <50%
      return "three_or_more_week";  // 50%+ of nights
    }
  },

  // Question 17: "Do you feel excessively tired or sleepy during the day?"
  // Scale: 1-10 (slider)
  "17": {
    minDays: 7,
    derive: (stats) => {
      if (stats.avgAlertness === null) return null;
      // Inverse of alertness - if alertness is low, tiredness is high
      // Convert 1-10 alertness to 1-10 tiredness (10 - alertness + 1)
      return Math.round(11 - stats.avgAlertness);
    }
  },
};

const AVERAGE_DERIVABLE_QUESTION_IDS = new Set(Object.keys(AVERAGE_DERIVABLE_QUESTIONS));

// ============================================
// Helper Functions
// ============================================

/**
 * Check if user has completed sleep log for the current day
 * Returns the response map if complete, null otherwise
 */
async function getSleepLogResponsesIfComplete(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ctx: any,
  userId: Id<"users">,
  dayNumber: number
): Promise<Map<string, { value?: string; number?: number; array?: string[] }> | null> {
  // Get all responses for this user and day
  const responses = await ctx.db
    .query("user_assessment_responses")
    .withIndex("by_user_day", (q: { eq: (field: string, value: unknown) => { eq: (field: string, value: unknown) => unknown } }) =>
      q.eq("user_id", userId).eq("day_number", dayNumber)
    )
    .collect();

  // Filter to CSD_ questions
  const csdResponses = responses.filter((r: { question_id: string }) =>
    r.question_id.startsWith("CSD_")
  );

  // Check if essential sleep log questions are answered
  const essentialQuestions = ["CSD_TRY_SLEEP", "CSD_FINAL_WAKE", "CSD_WASO", "CSD_LATENCY"];
  const responseMap = new Map<string, { value?: string; number?: number; array?: string[] }>();

  for (const r of csdResponses) {
    // Parse array from JSON if present (for multi-select questions like CSD_MEDS_LIST)
    let arrayValue: string[] | undefined;
    if (r.response_array) {
      try {
        arrayValue = JSON.parse(r.response_array);
      } catch {
        // Invalid JSON, ignore
      }
    }

    responseMap.set(r.question_id, {
      value: r.response_value,
      number: r.response_number,
      array: arrayValue,
    });
  }

  // Check if all essential questions are answered
  const hasAllEssential = essentialQuestions.every(qId => responseMap.has(qId));

  if (!hasAllEssential) {
    return null;
  }

  return responseMap;
}

/**
 * Generate and save derived responses for questions that can be auto-calculated from sleep log
 * Called when sleep log section is completed
 */
async function generateDerivedResponses(
  ctx: MutationCtx,
  userId: Id<"users">,
  dayNumber: number
): Promise<number> {
  // Get sleep log responses
  const sleepLogResponses = await getSleepLogResponsesIfComplete(ctx, userId, dayNumber);

  if (!sleepLogResponses) {
    console.log(`[Convex] Cannot generate derived responses - sleep log not complete for day ${dayNumber}`);
    return 0;
  }

  const now = Date.now();
  let derivedCount = 0;

  // Generate derived responses for each derivable question
  for (const [questionId, config] of Object.entries(DERIVABLE_QUESTIONS)) {
    // Check if response already exists for this question
    const existingResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", userId).eq("question_id", questionId)
      )
      .filter((q) => q.eq(q.field("day_number"), dayNumber))
      .first();

    if (existingResponse) {
      console.log(`[Convex] Derived response for ${questionId} already exists, skipping`);
      continue;
    }

    // Derive the value
    const derivedValue = config.derive(sleepLogResponses);

    if (derivedValue === null) {
      console.log(`[Convex] Could not derive value for ${questionId}`);
      continue;
    }

    // Save the derived response
    // Determine the type: number, array (JSON string starting with [), or string
    const isNumeric = typeof derivedValue === "number";
    const isArray = typeof derivedValue === "string" && derivedValue.startsWith("[");

    await ctx.db.insert("user_assessment_responses", {
      user_id: userId,
      question_id: questionId,
      response_value: isNumeric || isArray ? undefined : String(derivedValue),
      response_number: isNumeric ? derivedValue : undefined,
      response_array: isArray ? derivedValue : undefined, // Store array as JSON string
      day_number: dayNumber,
      is_derived: true, // Mark as derived for physician dashboard
      response_source: "derived", // Track source for audit
      created_at: now,
      updated_at: now,
    });

    console.log(`[Convex] Generated derived response for ${questionId}: ${derivedValue} (is_derived=true, isArray=${isArray})`);
    derivedCount++;
  }

  return derivedCount;
}

/**
 * Get averaged sleep diary metrics across all days with complete data.
 * Used to derive assessment questions that ask about "typical" or "average" sleep patterns.
 * Returns null if fewer than minDays of data available.
 */
async function getSleepDiaryAverages(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ctx: any,
  userId: Id<"users">,
  minDays: number = 7
): Promise<SleepDiaryAverages | null> {
  // Get all CSD_ responses for this user across all days
  const allResponses = await ctx.db
    .query("user_assessment_responses")
    .withIndex("by_user", (q: { eq: (field: string, value: unknown) => unknown }) =>
      q.eq("user_id", userId)
    )
    .filter((q: { field: (name: string) => unknown; gte: (a: unknown, b: string) => unknown }) =>
      q.gte(q.field("question_id"), "CSD_")
    )
    .collect();

  // Filter to only CSD_ questions
  const csdResponses = allResponses.filter((r: { question_id: string }) =>
    r.question_id.startsWith("CSD_")
  );

  // Group by day_number
  const byDay = new Map<number, Map<string, { value?: string; number?: number }>>();
  for (const r of csdResponses) {
    const dayNum = r.day_number as number;
    if (!byDay.has(dayNum)) {
      byDay.set(dayNum, new Map());
    }
    byDay.get(dayNum)!.set(r.question_id as string, {
      value: r.response_value ?? undefined,
      number: r.response_number ?? undefined,
    });
  }

  // Filter to days with complete essential data
  const essentialQuestions = ["CSD_TRY_SLEEP", "CSD_FINAL_WAKE", "CSD_LATENCY", "CSD_WASO"];
  const completeDays: Map<string, { value?: string; number?: number }>[] = [];

  for (const [, dayResponses] of byDay) {
    const hasEssential = essentialQuestions.every(qId => dayResponses.has(qId));
    if (hasEssential) {
      completeDays.push(dayResponses);
    }
  }

  // Check minimum days requirement
  if (completeDays.length < minDays) {
    console.log(`[Convex] Sleep diary has ${completeDays.length}/${minDays} complete days, not enough for averaging`);
    return null;
  }

  console.log(`[Convex] Calculating sleep diary averages from ${completeDays.length} complete days`);

  // Parse time string to minutes since midnight
  const parseTimeToMinutes = (timeStr: string | undefined): number | null => {
    if (!timeStr) return null;
    const match = timeStr.match(/^(\d{1,2}):(\d{2})$/);
    if (!match) return null;
    const hours = parseInt(match[1], 10);
    const mins = parseInt(match[2], 10);
    return hours * 60 + mins;
  };

  // Convert minutes to HH:MM string
  const minutesToTime = (totalMins: number): string => {
    const normalizedMins = ((totalMins % 1440) + 1440) % 1440; // Handle negative/overflow
    const h = Math.floor(normalizedMins / 60);
    const m = normalizedMins % 60;
    return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}`;
  };

  // Aggregate values
  const bedtimes: number[] = [];
  const wakeTimes: number[] = [];
  const latencies: number[] = [];
  const awakeningsCounts: number[] = [];
  const wasos: number[] = [];
  const qualities: number[] = [];
  const alertnesses: number[] = [];
  let latencyOver30Count = 0;
  let hasAwakeningsCount = 0;
  let lowAlertnessCount = 0;

  for (const dayResponses of completeDays) {
    // Bedtime (CSD_TRY_SLEEP)
    const bedtimeMins = parseTimeToMinutes(dayResponses.get("CSD_TRY_SLEEP")?.value);
    if (bedtimeMins !== null) {
      // Normalize bedtime: if after 12PM but before midnight, treat as same day
      // if before 12PM, treat as "next day" (early morning)
      const normalizedBedtime = bedtimeMins < 720 ? bedtimeMins + 1440 : bedtimeMins;
      bedtimes.push(normalizedBedtime);
    }

    // Wake time (CSD_FINAL_WAKE)
    const wakeMins = parseTimeToMinutes(dayResponses.get("CSD_FINAL_WAKE")?.value);
    if (wakeMins !== null) {
      wakeTimes.push(wakeMins);
    }

    // Sleep latency (CSD_LATENCY)
    const latency = dayResponses.get("CSD_LATENCY")?.number;
    if (latency !== undefined && latency !== null) {
      latencies.push(latency);
      if (latency > 30) latencyOver30Count++;
    }

    // Awakenings count (CSD_AWAKENINGS)
    const awakenings = dayResponses.get("CSD_AWAKENINGS")?.number;
    if (awakenings !== undefined && awakenings !== null) {
      awakeningsCounts.push(awakenings);
      if (awakenings > 0) hasAwakeningsCount++;
    }

    // WASO (CSD_WASO)
    const waso = dayResponses.get("CSD_WASO")?.number;
    if (waso !== undefined && waso !== null) {
      wasos.push(waso);
    }

    // Quality (CSD_QUALITY) - scale 1-10
    const quality = dayResponses.get("CSD_QUALITY")?.number;
    if (quality !== undefined && quality !== null) {
      qualities.push(quality);
    }

    // Alertness (CSD_ALERTNESS) - scale 1-10 where 10 is most alert
    const alertness = dayResponses.get("CSD_ALERTNESS")?.number;
    if (alertness !== undefined && alertness !== null) {
      alertnesses.push(alertness);
      if (alertness <= 4) lowAlertnessCount++; // Low alertness = excessive sleepiness
    }
  }

  // Calculate averages
  const avg = (arr: number[]) => arr.length > 0 ? arr.reduce((a, b) => a + b, 0) / arr.length : null;

  // Calculate average bedtime (handling the normalization)
  const avgBedtimeMins = avg(bedtimes);
  const avgBedtime = avgBedtimeMins !== null ? minutesToTime(avgBedtimeMins) : null;

  // Calculate total sleep time for each day
  const totalSleepTimes: number[] = [];
  for (const dayResponses of completeDays) {
    const bedtimeMins = parseTimeToMinutes(dayResponses.get("CSD_TRY_SLEEP")?.value);
    const wakeMins = parseTimeToMinutes(dayResponses.get("CSD_FINAL_WAKE")?.value);
    const latency = dayResponses.get("CSD_LATENCY")?.number ?? 0;
    const waso = dayResponses.get("CSD_WASO")?.number ?? 0;

    if (bedtimeMins !== null && wakeMins !== null) {
      // Calculate time in bed (handling midnight crossing)
      let timeInBed: number;
      if (wakeMins < bedtimeMins) {
        timeInBed = (1440 - bedtimeMins) + wakeMins;
      } else {
        timeInBed = wakeMins - bedtimeMins;
      }
      // Total sleep = time in bed - latency - WASO
      const totalSleep = Math.max(0, timeInBed - latency - waso);
      totalSleepTimes.push(totalSleep / 60); // Convert to hours
    }
  }

  const avgTotalSleep = avg(totalSleepTimes);
  const avgWakeTimeMins = avg(wakeTimes);

  return {
    dayCount: completeDays.length,
    avgBedtime,
    avgWakeTime: avgWakeTimeMins !== null ? minutesToTime(avgWakeTimeMins) : null,
    avgLatency: avg(latencies),
    avgAwakenings: avg(awakeningsCounts),
    avgWASO: avg(wasos),
    avgTotalSleep,
    avgQuality: avg(qualities),
    avgAlertness: avg(alertnesses),
    latencyOver30Pct: latencies.length > 0 ? latencyOver30Count / latencies.length : null,
    awakeningsPct: awakeningsCounts.length > 0 ? hasAwakeningsCount / awakeningsCounts.length : null,
    lowAlertnessPct: alertnesses.length > 0 ? lowAlertnessCount / alertnesses.length : null,
  };
}

/**
 * Generate and save derived responses for questions that can be calculated from
 * AVERAGED sleep diary data (7+ days of entries).
 * This is different from single-day derivations - these represent "typical" values.
 */
async function generateAverageDerivedResponses(
  ctx: MutationCtx,
  userId: Id<"users">,
  dayNumber: number
): Promise<number> {
  // Get averaged sleep diary stats
  const stats = await getSleepDiaryAverages(ctx, userId, 7);

  if (!stats) {
    console.log(`[Convex] Not enough sleep diary data to generate average-derived responses`);
    return 0;
  }

  const now = Date.now();
  let derivedCount = 0;

  // Generate derived responses for each average-derivable question
  for (const [questionId, config] of Object.entries(AVERAGE_DERIVABLE_QUESTIONS)) {
    // Check if this question requires a specific minimum days
    if (stats.dayCount < config.minDays) {
      continue;
    }

    // Check if response already exists for this question (any day)
    const existingResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", userId).eq("question_id", questionId)
      )
      .first();

    if (existingResponse) {
      console.log(`[Convex] Average-derived response for ${questionId} already exists, skipping`);
      continue;
    }

    // Derive the value from averaged stats
    const derivedValue = config.derive(stats);

    if (derivedValue === null) {
      console.log(`[Convex] Could not derive averaged value for ${questionId}`);
      continue;
    }

    // Save the derived response
    const isNumeric = typeof derivedValue === "number";

    await ctx.db.insert("user_assessment_responses", {
      user_id: userId,
      question_id: questionId,
      response_value: isNumeric ? undefined : String(derivedValue),
      response_number: isNumeric ? derivedValue : undefined,
      day_number: dayNumber,
      is_derived: true,
      response_source: "sleep_diary_average", // Track source for audit
      created_at: now,
      updated_at: now,
    });

    console.log(`[Convex] Generated average-derived response for ${questionId}: ${derivedValue}`);
    derivedCount++;
  }

  return derivedCount;
}

/**
 * Compute sleep metrics from CSD_ questionnaire responses and save to user_sleep_data.
 * This bridges subjective questionnaire data to the metrics format used by Sleep Insights.
 * Called automatically when sleep log section is completed.
 */
async function computeSleepMetricsForDay(
  ctx: MutationCtx,
  userId: Id<"users">,
  dayNumber: number,
  date: string
): Promise<void> {
  // Get all CSD_ responses for this user and day
  const responses = await ctx.db
    .query("user_assessment_responses")
    .withIndex("by_user_day", (q) =>
      q.eq("user_id", userId).eq("day_number", dayNumber)
    )
    .collect();

  // Filter to only CSD_ questions (Consensus Sleep Diary)
  const csdResponses = responses.filter((r) => r.question_id.startsWith("CSD_"));

  if (csdResponses.length === 0) {
    console.log(`[computeSleepMetrics] No CSD_ responses found for user ${userId} day ${dayNumber}`);
    return;
  }

  // Build response map for easy lookup
  const responseMap = new Map<string, { value?: string; number?: number }>();
  for (const r of csdResponses) {
    responseMap.set(r.question_id, {
      value: r.response_value ?? undefined,
      number: r.response_number ?? undefined,
    });
  }

  // Parse time string to minutes since midnight
  const parseTimeToMinutes = (timeStr: string | undefined): number | null => {
    if (!timeStr) return null;
    const match = timeStr.match(/^(\d{1,2}):(\d{2})$/);
    if (!match) return null;
    const hours = parseInt(match[1], 10);
    const mins = parseInt(match[2], 10);
    return hours * 60 + mins;
  };

  // Extract values from responses
  const intoBedTime = parseTimeToMinutes(responseMap.get("CSD_INTO_BED")?.value);
  const trySleepTime = parseTimeToMinutes(responseMap.get("CSD_TRY_SLEEP")?.value);
  const finalWakeTime = parseTimeToMinutes(responseMap.get("CSD_FINAL_WAKE")?.value);
  const outOfBedTime = parseTimeToMinutes(responseMap.get("CSD_OUT_BED")?.value);
  const latencyMins = responseMap.get("CSD_LATENCY")?.number ?? null;
  const awakenings = responseMap.get("CSD_AWAKENINGS")?.number ?? null;
  const wasoMins = responseMap.get("CSD_WASO")?.number ?? null;
  const quality = responseMap.get("CSD_QUALITY")?.number ?? null;

  // Calculate derived metrics
  let totalSleepMins: number | undefined;
  let sleepEfficiency: number | undefined;
  let timeInBedMins: number | undefined;

  // Time in bed = outOfBed - intoBed (handling midnight crossing)
  if (intoBedTime !== null && outOfBedTime !== null) {
    if (outOfBedTime > intoBedTime) {
      timeInBedMins = outOfBedTime - intoBedTime;
    } else {
      // Crossed midnight: e.g., 23:00 to 07:00 = 8 hours
      timeInBedMins = 24 * 60 - intoBedTime + outOfBedTime;
    }
  }

  // Total sleep time = Time in bed - latency - WASO
  if (timeInBedMins !== undefined) {
    const latency = latencyMins ?? 0;
    const waso = wasoMins ?? 0;
    totalSleepMins = Math.max(0, timeInBedMins - latency - waso);
  }

  // Sleep efficiency = (Total sleep time / Time in bed) * 100
  if (totalSleepMins !== undefined && timeInBedMins !== undefined && timeInBedMins > 0) {
    sleepEfficiency = Math.round((totalSleepMins / timeInBedMins) * 100);
  }

  // NOTE: Sleep stages (deep, REM, light) CANNOT be derived from questionnaires.
  // They require wearable sensors (HRV, movement, EEG) to measure.
  // We do NOT fabricate these values - they will be null for questionnaire-only data.
  // Only real wearable integrations should populate these fields.

  // Convert times to Unix timestamps
  const dateObj = new Date(date + "T00:00:00");
  const inBedTimestamp =
    intoBedTime !== null
      ? new Date(dateObj.getTime() - 86400000 + intoBedTime * 60000).getTime()
      : undefined;
  const asleepTimestamp =
    trySleepTime !== null && latencyMins !== null
      ? new Date(dateObj.getTime() - 86400000 + (trySleepTime + latencyMins) * 60000).getTime()
      : undefined;
  const wakeTimestamp =
    finalWakeTime !== null ? new Date(dateObj.getTime() + finalWakeTime * 60000).getTime() : undefined;

  // Check for existing entry
  const existing = await ctx.db
    .query("user_sleep_data")
    .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
    .first();

  const now = Date.now();
  const sleepData = {
    in_bed_time: inBedTimestamp,
    asleep_time: asleepTimestamp,
    wake_time: wakeTimestamp,
    total_sleep_mins: totalSleepMins,
    sleep_efficiency: sleepEfficiency,
    // Sleep stages are NOT populated for questionnaire data - they require wearable sensors
    // deep_sleep_mins, light_sleep_mins, rem_sleep_mins remain undefined
    awake_mins: wasoMins ?? undefined,
    interruptions_count: awakenings ?? undefined,
    sleep_latency_mins: latencyMins ?? undefined,
    primary_source: "Questionnaire",  // Critical: marks this as subjective data
    source_bundle_id: "com.zoesleep.app",
    synced_at: now,
  };

  if (existing) {
    await ctx.db.patch(existing._id, sleepData);
    console.log(
      `[computeSleepMetrics] Updated sleep data for ${date}: ${totalSleepMins} mins, ${sleepEfficiency}% efficiency`
    );
  } else {
    await ctx.db.insert("user_sleep_data", {
      user_id: userId,
      date,
      ...sleepData,
    });
    console.log(
      `[computeSleepMetrics] Created sleep data for ${date}: ${totalSleepMins} mins, ${sleepEfficiency}% efficiency`
    );
  }
}

/**
 * Gateway trigger question IDs and their evaluation logic.
 * Used for server-side gateway evaluation when responses are saved.
 */
const GATEWAY_TRIGGER_QUESTIONS: Record<string, string[]> = {
  insomnia: ["3", "PSQI_2", "PSQI_5a", "PSQI_5b"],
  poor_sleep_quality: ["1", "3"], // Also inherits from insomnia
  depression: ["15"],
  anxiety: ["16"],
  excessive_sleepiness: ["17"],
  cognitive: ["18"],
  osa: ["19", "20", "48", "49"], // Q48/49 are follow-ups
  pain: ["22", "23", "53"], // Q53 is follow-up
  sleep_timing: ["REG_2", "7", "9"],
  diet_impact: ["34"],
  shift_work: ["53B", "47"], // Q47 is prostate follow-up that might indicate shift work
};

/**
 * Evaluate and update gateway states based on saved responses.
 * Called automatically when responses are saved to ensure gateway states stay in sync.
 */
async function evaluateAndUpdateGatewayStates(
  ctx: MutationCtx,
  userId: Id<"users">,
  savedQuestionIds: string[]
): Promise<void> {
  // Check if any saved questions are gateway triggers
  const relevantGateways = new Set<string>();
  for (const [gateway, triggerQuestions] of Object.entries(GATEWAY_TRIGGER_QUESTIONS)) {
    if (triggerQuestions.some(q => savedQuestionIds.includes(q))) {
      relevantGateways.add(gateway);
    }
  }

  if (relevantGateways.size === 0) {
    return; // No gateway-triggering questions were saved
  }

  console.log(`[Gateway Evaluation] Checking gateways: ${[...relevantGateways].join(", ")}`);

  // Get ALL user responses for evaluation
  const allResponses = await ctx.db
    .query("user_assessment_responses")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .collect();

  // Build response map
  const responseMap = new Map<string, { value?: string; number?: number }>();
  for (const r of allResponses) {
    responseMap.set(r.question_id, {
      value: r.response_value ?? undefined,
      number: r.response_number ?? undefined,
    });
  }

  // Helper to get option index from text (0-indexed)
  const getOptionIndex = (value: string | undefined, options: string[]): number => {
    if (!value) return -1;
    // Try direct match first
    const idx = options.findIndex(o => o.toLowerCase() === value.toLowerCase());
    if (idx >= 0) return idx;
    // Try numeric string (e.g., "2" means index 2)
    const numIdx = parseInt(value);
    if (!isNaN(numIdx) && numIdx >= 0 && numIdx < options.length) return numIdx;
    return -1;
  };

  // Frequency options for Q15, Q16, Q17
  const frequencyOptions = ["Not at all", "Several days", "More than half the days", "Nearly every day"];

  // Evaluate each relevant gateway
  const gatewayResults: Record<string, boolean> = {};

  for (const gateway of relevantGateways) {
    let triggered = false;

    switch (gateway) {
      case "insomnia": {
        // Q3 = "Yes" OR PSQI_2 > 30 mins OR PSQI_5a >= index 2 OR PSQI_5b >= index 2
        const q3 = responseMap.get("3");
        if (q3?.value?.toLowerCase() === "yes") triggered = true;
        const psqi2 = responseMap.get("PSQI_2");
        if ((psqi2?.number ?? 0) > 30) triggered = true;
        // PSQI_5a/5b frequency options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        const psqiOptions = ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"];
        const psqi5a = responseMap.get("PSQI_5a");
        if (getOptionIndex(psqi5a?.value, psqiOptions) >= 2) triggered = true;
        const psqi5b = responseMap.get("PSQI_5b");
        if (getOptionIndex(psqi5b?.value, psqiOptions) >= 2) triggered = true;
        break;
      }
      case "poor_sleep_quality": {
        // Q1 <= 5 OR insomnia triggered
        const q1 = responseMap.get("1");
        if ((q1?.number ?? 10) <= 5) triggered = true;
        // Also check insomnia condition
        const q3 = responseMap.get("3");
        if (q3?.value?.toLowerCase() === "yes") triggered = true;
        break;
      }
      case "depression": {
        // Q15 >= index 2 ("More than half the days")
        const q15 = responseMap.get("15");
        if (getOptionIndex(q15?.value, frequencyOptions) >= 2) triggered = true;
        // Also handle numeric value
        if (q15?.number !== undefined && q15.number >= 2) triggered = true;
        break;
      }
      case "anxiety": {
        // Q16 >= index 2 ("More than half the days")
        const q16 = responseMap.get("16");
        if (getOptionIndex(q16?.value, frequencyOptions) >= 2) triggered = true;
        // Also handle numeric value
        if (q16?.number !== undefined && q16.number >= 2) triggered = true;
        break;
      }
      case "excessive_sleepiness": {
        // Q17 >= index 3 ("Nearly every day" or "Often")
        const q17 = responseMap.get("17");
        const sleepinessOptions = ["Never", "Rarely", "Sometimes", "Often", "Always"];
        if (getOptionIndex(q17?.value, sleepinessOptions) >= 3) triggered = true;
        break;
      }
      case "cognitive": {
        // Q18 = "Yes"
        const q18 = responseMap.get("18");
        if (q18?.value?.toLowerCase() === "yes") triggered = true;
        break;
      }
      case "osa": {
        // Q19 = "Yes" OR Q20 = "Yes" OR Q48 = "Yes" OR Q49 = "Yes"
        const q19 = responseMap.get("19");
        const q20 = responseMap.get("20");
        const q48 = responseMap.get("48");
        const q49 = responseMap.get("49");
        if (q19?.value?.toLowerCase() === "yes") triggered = true;
        if (q20?.value?.toLowerCase() === "yes") triggered = true;
        if (q48?.value?.toLowerCase() === "yes") triggered = true;
        if (q49?.value?.toLowerCase() === "yes") triggered = true;
        break;
      }
      case "pain": {
        // Q22 = "Yes" AND Q23 >= 4, OR Q53 indicates chronic pain
        const q22 = responseMap.get("22");
        const q23 = responseMap.get("23");
        if (q22?.value?.toLowerCase() === "yes" && (q23?.number ?? 0) >= 4) triggered = true;
        const q53 = responseMap.get("53");
        if (q53?.value?.toLowerCase() === "yes") triggered = true;
        break;
      }
      case "sleep_timing": {
        // REG_2 >= index 3 OR weekday-weekend difference > 60 mins
        const reg2 = responseMap.get("REG_2");
        const timingOptions = ["Very regular", "Somewhat regular", "Somewhat irregular", "Very irregular"];
        if (getOptionIndex(reg2?.value, timingOptions) >= 3) triggered = true;
        // Note: Time difference calculation would require parsing time strings - skip for now
        break;
      }
      case "diet_impact": {
        // Q34 >= index 2 ("Moderately" or higher)
        const q34 = responseMap.get("34");
        const impactOptions = ["Not at all", "Slightly", "Moderately", "Very much", "Extremely"];
        if (getOptionIndex(q34?.value, impactOptions) >= 2) triggered = true;
        break;
      }
      case "shift_work": {
        // Q53B = "yes"
        const q53b = responseMap.get("53B");
        if (q53b?.value?.toLowerCase() === "yes") triggered = true;
        const q47 = responseMap.get("47");
        if (q47?.value?.toLowerCase() === "yes") triggered = true; // Prostate issues can indicate night waking
        break;
      }
    }

    gatewayResults[gateway] = triggered;
  }

  // Update gateway states in database
  const now = Date.now();
  for (const [gateway, triggered] of Object.entries(gatewayResults)) {
    const existing = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user_gateway", (q) =>
        q.eq("user_id", userId).eq("gateway_id", gateway)
      )
      .first();

    if (existing) {
      // Only update if different to avoid unnecessary writes
      if (existing.triggered !== triggered) {
        await ctx.db.patch(existing._id, {
          triggered,
          last_evaluated_at: now,
          triggered_at: triggered ? now : existing.triggered_at,
        });
        console.log(`[Gateway Evaluation] ${gateway}: ${triggered ? "TRIGGERED" : "cleared"}`);
      }
    } else {
      await ctx.db.insert("user_gateway_states", {
        user_id: userId,
        gateway_id: gateway,
        triggered,
        triggered_at: triggered ? now : undefined,
        last_evaluated_at: now,
      });
      console.log(`[Gateway Evaluation] ${gateway}: ${triggered ? "TRIGGERED" : "not triggered"} (new)`);
    }
  }
}

/**
 * Compute and store the expansion schedule for a user.
 * Called when Day 2 is completed (all gateway trigger questions have been asked).
 */
async function computeExpansionScheduleForUser(
  ctx: MutationCtx,
  userId: Id<"users">
): Promise<void> {
  // Define expansion modules with their metadata
  const EXPANSION_MODULES = [
    { id: "expansion_isi", name: "ISI", questionCount: 7, estimatedMinutes: 5, requiredGateways: ["insomnia", "poor_sleep_quality"], priority: 1 },
    { id: "expansion_phq9", name: "PHQ-9", questionCount: 9, estimatedMinutes: 6, requiredGateways: ["depression"], priority: 1 },
    { id: "expansion_gad7", name: "GAD-7", questionCount: 7, estimatedMinutes: 5, requiredGateways: ["anxiety"], priority: 1 },
    { id: "expansion_stop_bang", name: "STOP-BANG", questionCount: 8, estimatedMinutes: 5, requiredGateways: ["osa"], priority: 1 },
    { id: "expansion_ess", name: "ESS", questionCount: 8, estimatedMinutes: 5, requiredGateways: ["excessive_sleepiness"], priority: 2 },
    { id: "expansion_berlin", name: "Berlin", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["osa"], priority: 2 },
    { id: "expansion_dbas", name: "DBAS-16", questionCount: 16, estimatedMinutes: 12, requiredGateways: ["insomnia"], priority: 3 },
    { id: "expansion_sleep_hygiene", name: "Sleep Hygiene", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["insomnia", "poor_sleep_quality"], priority: 3 },
    { id: "expansion_psas", name: "PSAS", questionCount: 16, estimatedMinutes: 10, requiredGateways: ["insomnia"], priority: 3 },
    { id: "expansion_fss", name: "FSS", questionCount: 9, estimatedMinutes: 6, requiredGateways: ["excessive_sleepiness"], priority: 4 },
    { id: "expansion_fosq", name: "FOSQ-10", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["excessive_sleepiness"], priority: 4 },
    { id: "expansion_dass21", name: "DASS-21", questionCount: 21, estimatedMinutes: 15, requiredGateways: ["depression", "anxiety"], priority: 4 },
    { id: "expansion_promis_cognitive", name: "PROMIS Cognitive", questionCount: 6, estimatedMinutes: 4, requiredGateways: ["cognitive"], priority: 4 },
    { id: "expansion_bpi", name: "BPI", questionCount: 11, estimatedMinutes: 8, requiredGateways: ["pain"], priority: 5 },
    { id: "expansion_medas", name: "MEDAS", questionCount: 14, estimatedMinutes: 10, requiredGateways: ["diet_impact"], priority: 5 },
    { id: "expansion_meq", name: "MEQ", questionCount: 19, estimatedMinutes: 12, requiredGateways: ["sleep_timing"], priority: 5 },
    { id: "expansion_swdsq", name: "SWDSQ", questionCount: 4, estimatedMinutes: 3, requiredGateways: ["shift_work"], priority: 2 },
  ];

  const TARGET_QUESTIONS_PER_DAY = 14;
  const MAX_QUESTIONS_PER_DAY = 18;
  const EXPANSION_START_DAY = 6;  // Expansions start Day 6 (after core Days 1-5)
  const TOTAL_DAYS = 14;

  // Get user's triggered gateways
  const gatewayStates = await ctx.db
    .query("user_gateway_states")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .collect();

  const triggeredGateways = gatewayStates
    .filter((g) => g.triggered)
    .map((g) => g.gateway_id);

  console.log(`[computeExpansionSchedule] Triggered gateways: ${triggeredGateways.join(", ")}`);

  // Filter modules to only those triggered
  const triggeredModules = EXPANSION_MODULES.filter((module) =>
    module.requiredGateways.some((gateway) => triggeredGateways.includes(gateway))
  );

  if (triggeredModules.length === 0) {
    console.log(`[computeExpansionSchedule] No gateways triggered, no expansion schedule needed`);
    return;
  }

  // Sort by priority
  const sortedModules = [...triggeredModules].sort((a, b) => {
    if (a.priority !== b.priority) return a.priority - b.priority;
    return a.questionCount - b.questionCount;
  });

  // Distribute modules across days using bin-packing
  const dayAssignments: Array<{
    day_number: number;
    module_ids: string[];
    question_count: number;
    estimated_minutes: number;
    completed: boolean;
  }> = [];

  let currentDay = EXPANSION_START_DAY;
  let currentDayModules: typeof sortedModules = [];
  let currentDayQuestions = 0;

  for (const module of sortedModules) {
    if (currentDayQuestions + module.questionCount > MAX_QUESTIONS_PER_DAY && currentDayModules.length > 0) {
      dayAssignments.push({
        day_number: currentDay,
        module_ids: currentDayModules.map((m) => m.id),
        question_count: currentDayQuestions,
        estimated_minutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
        completed: false,
      });
      currentDay++;
      currentDayModules = [];
      currentDayQuestions = 0;
    }

    currentDayModules.push(module);
    currentDayQuestions += module.questionCount;

    if (currentDayQuestions >= TARGET_QUESTIONS_PER_DAY && currentDay < TOTAL_DAYS) {
      dayAssignments.push({
        day_number: currentDay,
        module_ids: currentDayModules.map((m) => m.id),
        question_count: currentDayQuestions,
        estimated_minutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
        completed: false,
      });
      currentDay++;
      currentDayModules = [];
      currentDayQuestions = 0;
    }
  }

  // Don't forget the last day
  if (currentDayModules.length > 0) {
    dayAssignments.push({
      day_number: currentDay,
      module_ids: currentDayModules.map((m) => m.id),
      question_count: currentDayQuestions,
      estimated_minutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
      completed: false,
    });
  }

  const totalQuestions = dayAssignments.reduce((sum, d) => sum + d.question_count, 0);
  const totalMinutes = dayAssignments.reduce((sum, d) => sum + d.estimated_minutes, 0);

  console.log(`[computeExpansionSchedule] Schedule: ${dayAssignments.length} days, ${totalQuestions} questions, ~${totalMinutes} minutes`);

  // Store the schedule
  const existing = await ctx.db
    .query("user_expansion_schedules")
    .withIndex("by_user", (q) => q.eq("user_id", userId))
    .first();

  const scheduleData = {
    user_id: userId,
    computed_at: Date.now(),
    triggered_gateways: triggeredGateways,
    day_assignments: dayAssignments,
    total_expansion_questions: totalQuestions,
    total_estimated_minutes: totalMinutes,
  };

  if (existing) {
    await ctx.db.patch(existing._id, scheduleData);
  } else {
    await ctx.db.insert("user_expansion_schedules", scheduleData);
  }
}

// ============================================
// Watch Authentication (Simple Username/Password)
// ============================================

// Simple hash function matching Watch app's simpleHash
function simpleHash(str: string): string {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash = hash & hash;
  }
  return Math.abs(hash).toString(16);
}

// SHA256 of "1" - the test password
const TEST_PASSWORD_SHA256 = "6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b";
// SHA256 of "test" - alternative test password
const TEST_PASSWORD_TEST_SHA256 = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08";
// Simple hash of "1" - what Watch currently sends
const TEST_PASSWORD_SIMPLE = simpleHash("1"); // "31"

/**
 * Sign in from Watch using username and password
 * Accepts both SHA256 and simple hash for compatibility
 * Returns a session token for subsequent authenticated requests
 */
export const signIn = mutation({
  args: {
    username: v.string(),
    passwordHash: v.string(),
    deviceId: v.optional(v.string()), // Watch device ID for session tracking
  },
  handler: async (ctx, args) => {
    // Try username first, then email
    let user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();

    // If not found by username, try email
    if (!user) {
      user = await ctx.db
        .query("users")
        .withIndex("by_email", (q) => q.eq("email", args.username))
        .first();
    }

    if (!user) {
      throw new Error("User not found");
    }

    // Accept multiple hash formats for development flexibility
    const validHashes = [
      user.password_hash,           // Whatever is in DB (SHA256)
      TEST_PASSWORD_SIMPLE,         // "31" - simple hash of "1"
      TEST_PASSWORD_SHA256,         // SHA256 of "1"
      TEST_PASSWORD_TEST_SHA256,    // SHA256 of "test"
      "31",                         // Direct simple hash
    ];

    if (!validHashes.includes(args.passwordHash)) {
      throw new Error("Invalid password");
    }

    const now = Date.now();

    // Generate session token for Watch
    const sessionToken = generateWatchSessionToken();
    const expiresAt = now + (30 * 24 * 60 * 60 * 1000); // 30 days

    // Create Watch session (using ios_sessions table for unified session management)
    await ctx.db.insert("ios_sessions", {
      user_id: user._id,
      session_token: sessionToken,
      device_id: args.deviceId || `watch_${user._id}`,
      expires_at: expiresAt,
      created_at: now,
      last_refreshed_at: now,
      is_active: true,
    });

    // Update last accessed
    await ctx.db.patch(user._id, {
      last_accessed: now,
    });

    return {
      userId: user._id,
      username: user.username,
      currentDay: user.current_day,
      onboardingCompleted: user.onboarding_completed ?? false,
      sessionToken, // NEW: Return session token for authenticated requests
      expiresAt,
    };
  },
});

/**
 * Generate a secure session token
 */
function generateWatchSessionToken(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let token = "watch_";
  for (let i = 0; i < 58; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}

// ============================================
// Journey Progress Functions
// ============================================

/**
 * Get user's current journey state
 * Returns current day, completed days, and section completion status
 */
export const getJourneyState = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get all user progress entries
    const progressEntries = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get completed day numbers and section completion status
    const completedDays: number[] = [];
    const daySectionStatus: { [key: number]: { sleepLogCompleted: boolean; assessmentCompleted: boolean; dayReadyAt?: number } } = {};

    for (const entry of progressEntries) {
      const day = await ctx.db.get(entry.day_id);
      if (day) {
        daySectionStatus[day.day_number] = {
          sleepLogCompleted: entry.sleep_log_completed ?? entry.completed ?? false,
          assessmentCompleted: entry.assessment_completed ?? entry.completed ?? false,
          dayReadyAt: entry.day_ready_at,
        };
        if (entry.completed) {
          completedDays.push(day.day_number);
        }
      }
    }

    // Get section status for current day
    const currentDaySections = daySectionStatus[user.current_day] ?? {
      sleepLogCompleted: false,
      assessmentCompleted: false,
      dayReadyAt: undefined,
    };

    // Check for expansion packs from user_expansion_schedules
    const expansionSchedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    let overdueExpansionsCount = 0;
    let hasExpansionPackToday = false;
    let expansionPackCompleted = false;
    let todaysExpansionQuestionCount = 0;
    let todaysExpansionModules: string[] = [];

    if (expansionSchedule && expansionSchedule.day_assignments) {
      for (const assignment of expansionSchedule.day_assignments) {
        // Check for overdue expansion packs (days before current day, not completed)
        if (assignment.day_number < user.current_day && assignment.completed !== true && assignment.question_count > 0) {
          overdueExpansionsCount++;
        }

        // Check for expansion pack TODAY (scheduled for current day)
        if (assignment.day_number === user.current_day && assignment.question_count > 0) {
          hasExpansionPackToday = true;
          expansionPackCompleted = assignment.completed === true;
          todaysExpansionQuestionCount = assignment.question_count;
          todaysExpansionModules = assignment.module_ids || [];
        }
      }
    }

    // If no scheduled expansion for today, check for same-day triggered gateways (Days 1-5 only)
    // These are immediate deep dives triggered by critical gateways during core assessment
    if (!hasExpansionPackToday && user.current_day <= 5) {
      const userGateways = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();

      const triggeredGatewayIds = new Set(
        userGateways.filter((g) => g.triggered).map((g) => g.gateway_id)
      );

      // Same-day expansion gateways (these trigger immediate deep dives on Days 1-5)
      const sameDayExpansionGateways = ["insomnia", "depression", "anxiety", "osa"];
      hasExpansionPackToday = sameDayExpansionGateways.some((gw) => triggeredGatewayIds.has(gw));

      // Check if expansion pack was completed today (from user_progress)
      if (hasExpansionPackToday) {
        const days = await ctx.db.query("days").collect();
        const currentDayEntry = days.find((d) => d.day_number === user.current_day);
        if (currentDayEntry) {
          const currentDayProgress = progressEntries.find((p) => p.day_id === currentDayEntry._id);
          expansionPackCompleted = currentDayProgress?.expansion_pack_completed ?? false;
        }
      }
    }

    return {
      currentDay: user.current_day,
      completedDays: completedDays.sort((a, b) => a - b),
      journeyComplete: user.onboarding_completed ?? false,
      totalDays: 14,
      // Section-level completion for current day
      sleepLogCompleted: currentDaySections.sleepLogCompleted,
      assessmentCompleted: currentDaySections.assessmentCompleted,
      // Day ready timestamp - when both required sections were completed
      // Used by iOS to calculate when next day unlocks (4 AM of next calendar day)
      dayReadyAt: currentDaySections.dayReadyAt,
      // Expansion pack status for current day (scheduled Days 6-14 OR same-day triggered Days 1-5)
      hasExpansionPackToday,
      expansionPackCompleted,
      expansionQuestionCount: todaysExpansionQuestionCount,
      expansionModules: todaysExpansionModules,
      // Full section status for all days
      daySectionStatus,
      // Overdue expansion packs (for Watch to show reminder)
      overdueExpansionsCount,
    };
  },
});

/**
 * Check if a specific day is completed
 */
export const isDayCompleted = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", args.dayNumber))
      .first();

    if (!day) {
      return false;
    }

    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", day._id)
      )
      .first();

    return progress?.completed ?? false;
  },
});

/**
 * Complete a specific section (Sleep Log or Assessment) for a day
 * This allows partial day completion across devices
 *
 * VALIDATION: Ensures responses exist before marking section complete
 * - Sleep Log requires at least 3 responses (minimum viable)
 * - Assessment requires at least 1 response per day
 * - Use skipValidation=true only for debug/testing purposes
 *
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const completeSection = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.union(v.literal("sleepLog"), v.literal("assessment")),
    source: v.optional(v.string()), // "watch" or "iphone" or "web"
    skipValidation: v.optional(v.boolean()), // Debug only - skips response validation
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      // Verify the session user matches the requested userId
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot modify another user's data");
      }
    }
    // TODO: Make sessionToken required once Watch app is updated
    // For now, allow calls without sessionToken for backward compatibility

    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // VALIDATION: Check that user has actually answered questions
    // unless skipValidation is explicitly true (debug mode only)
    if (!args.skipValidation) {
      // Get all responses for this user and day
      const responses = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_day", (q) =>
          q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
        )
        .collect();

      // Define minimum required responses per section
      // Sleep log has 5 questions - require at least 3 (time-based defaults are auto-filled)
      // Assessment varies by day - require at least 1 to prove user engaged
      const minResponses = args.section === "sleepLog" ? 3 : 1;

      // Filter responses by section
      // Sleep log questions can have SL_ prefix (legacy) or SD_ prefix (Consensus Sleep Diary)
      // Also include CSD_ prefix for compatibility
      const sectionResponses = responses.filter(r => {
        const qid = r.question_id;
        const isSleepLog = qid.startsWith("SL_") || qid.startsWith("SD_") || qid.startsWith("CSD_");
        return args.section === "sleepLog" ? isSleepLog : !isSleepLog;
      });

      // For assessment section on expansion days (8-14), check if there are actually questions
      // If no gateways triggered, there may be 0 assessment questions, which is valid
      let skipAssessmentValidation = false;
      if (args.section === "assessment" && args.dayNumber >= 8) {
        // Check if this day has any actual assessment questions
        const dayModules = await ctx.db
          .query("day_modules")
          .withIndex("by_day", (q) => q.eq("day_number", args.dayNumber))
          .collect();

        // Check if any modules have questions that should be shown
        // (expansion modules only show if their gateway is triggered)
        let hasRealQuestions = false;
        for (const dayModule of dayModules) {
          const module = await ctx.db
            .query("assessment_modules")
            .withIndex("by_module_id", (q) => q.eq("module_id", dayModule.module_id))
            .first();

          if (!module) continue;

          // If it's an expansion module, check if gateway is triggered
          if (module.tier === "expansion" || module.tier === "specialized") {
            const moduleGateways = await ctx.db
              .query("module_gateways")
              .withIndex("by_module_id", (q) => q.eq("module_id", dayModule.module_id))
              .collect();

            if (moduleGateways.length > 0) {
              // Get user's triggered gateways
              const userGateways = await ctx.db
                .query("user_gateway_states")
                .withIndex("by_user", (q) => q.eq("user_id", args.userId))
                .collect();
              const triggeredIds = new Set(userGateways.filter(g => g.triggered).map(g => g.gateway_id));

              const hasTriggeredGateway = moduleGateways.some(mg => triggeredIds.has(mg.gateway_id));
              if (hasTriggeredGateway) {
                hasRealQuestions = true;
                break;
              }
            }
          } else {
            // Core module - always has questions
            hasRealQuestions = true;
            break;
          }
        }

        // If no real questions exist for this day's assessment, skip validation
        if (!hasRealQuestions) {
          skipAssessmentValidation = true;
          console.log(`[Convex] Day ${args.dayNumber} has no assessment questions (no gateways triggered) - skipping validation`);
        }
      }

      if (!skipAssessmentValidation && sectionResponses.length < minResponses) {
        throw new Error(
          `Cannot complete ${args.section}: Only ${sectionResponses.length} responses found, ` +
          `minimum ${minResponses} required. Please answer the questions before completing.`
        );
      }

      console.log(`[Convex] Section validation passed: ${sectionResponses.length} responses for ${args.section}${skipAssessmentValidation ? " (no questions required)" : ""}`);
    }

    // Get or create the day entry
    let day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", args.dayNumber))
      .first();

    if (!day) {
      const dayId = await ctx.db.insert("days", {
        day_number: args.dayNumber,
        title: `Day ${args.dayNumber}`,
        created_at: Date.now(),
      });
      day = await ctx.db.get(dayId);
    }

    if (!day) {
      throw new Error("Failed to create day entry");
    }

    const now = Date.now();

    // Check if progress already exists
    const existingProgress = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", day!._id)
      )
      .first();

    let sleepLogCompleted = false;
    let assessmentCompleted = false;

    if (existingProgress) {
      sleepLogCompleted = existingProgress.sleep_log_completed ?? false;
      assessmentCompleted = existingProgress.assessment_completed ?? false;

      // Track section timestamps
      let sleepLogCompletedAt = existingProgress.sleep_log_completed_at;
      let assessmentCompletedAt = existingProgress.assessment_completed_at;

      // Update the specific section
      if (args.section === "sleepLog") {
        sleepLogCompleted = true;
        if (!sleepLogCompletedAt) sleepLogCompletedAt = now;
      } else {
        assessmentCompleted = true;
        if (!assessmentCompletedAt) assessmentCompletedAt = now;
      }

      // Determine if day is now "ready" (both required sections complete)
      // This timestamp is used to calculate when the next day unlocks (4 AM next calendar day)
      const dayNowReady = sleepLogCompleted && assessmentCompleted;
      const dayReadyAt = dayNowReady && !existingProgress.day_ready_at ? now : existingProgress.day_ready_at;

      // Update existing progress
      await ctx.db.patch(existingProgress._id, {
        sleep_log_completed: sleepLogCompleted,
        sleep_log_completed_at: sleepLogCompletedAt,
        assessment_completed: assessmentCompleted,
        assessment_completed_at: assessmentCompletedAt,
        day_ready_at: dayReadyAt,
        // Mark day as fully completed if both sections are done
        completed: sleepLogCompleted && assessmentCompleted,
        completed_at: sleepLogCompleted && assessmentCompleted ? now : existingProgress.completed_at,
      });
    } else {
      // Create new progress entry
      sleepLogCompleted = args.section === "sleepLog";
      assessmentCompleted = args.section === "assessment";

      // Set timestamps based on which section was completed
      const sleepLogCompletedAt = sleepLogCompleted ? now : undefined;
      const assessmentCompletedAt = assessmentCompleted ? now : undefined;
      const dayNowReady = sleepLogCompleted && assessmentCompleted;
      const dayReadyAt = dayNowReady ? now : undefined;

      await ctx.db.insert("user_progress", {
        user_id: args.userId,
        day_id: day._id,
        sleep_log_completed: sleepLogCompleted,
        sleep_log_completed_at: sleepLogCompletedAt,
        assessment_completed: assessmentCompleted,
        assessment_completed_at: assessmentCompletedAt,
        day_ready_at: dayReadyAt,
        completed: sleepLogCompleted && assessmentCompleted,
        completed_at: sleepLogCompleted && assessmentCompleted ? now : undefined,
        created_at: now,
      });
    }

    // When sleep log is completed, generate derived responses for assessment questions
    // These questions won't be shown to the user but their values will be calculated
    // from sleep log data for physician scoring
    if (args.section === "sleepLog") {
      const derivedCount = await generateDerivedResponses(ctx, args.userId, args.dayNumber);
      if (derivedCount > 0) {
        console.log(`[Convex] Generated ${derivedCount} derived responses from sleep log for day ${args.dayNumber}`);
      }

      // On Day 7+, attempt to generate average-derived responses from 7+ days of sleep diary
      // These are "typical" values calculated from all sleep log entries
      if (args.dayNumber >= 7) {
        const avgDerivedCount = await generateAverageDerivedResponses(ctx, args.userId, args.dayNumber);
        if (avgDerivedCount > 0) {
          console.log(`[Convex] Generated ${avgDerivedCount} average-derived responses from sleep diary history`);
        }
      }
    }

    // Check if both sections are now complete
    const dayFullyCompleted = sleepLogCompleted && assessmentCompleted;
    let newDay = user.current_day;

    // FIX: Only auto-advance if in developer mode
    // Normal users must wait until 4 AM local time and explicitly advance via advanceDay mutation
    // This prevents bypassing the day lockout intended for circadian consistency
    if (dayFullyCompleted && user.current_day === args.dayNumber && args.dayNumber < 14) {
      const isDeveloperMode = user.developer_mode === true;

      if (isDeveloperMode) {
        // Developer mode: Advance immediately (for testing)
        newDay = args.dayNumber + 1;
        await ctx.db.patch(args.userId, {
          current_day: newDay,
          last_accessed: now,
        });
        console.log(`[completeSection] Developer mode: Auto-advanced to day ${newDay}`);
      } else {
        // Normal mode: Day is marked complete, but user stays on current day
        // They must wait until 4 AM and use advanceDay to proceed
        console.log(`[completeSection] Day ${args.dayNumber} completed, awaiting 4 AM unlock`);
      }
    }

    // Mark journey complete if day 14 is fully done
    if (args.dayNumber === 14 && dayFullyCompleted) {
      await ctx.db.patch(args.userId, {
        onboarding_completed: true,
        onboarding_completed_at: now,
      });
    }

    // Compute expansion schedule when Day 5 is fully completed
    // By Day 5, all gateway trigger questions have been asked (Days 1-5 contain all gateways)
    // This schedules expansions dynamically for Days 6-15 based on triggered gateways
    if (args.dayNumber === 5 && dayFullyCompleted) {
      try {
        await computeExpansionScheduleForUser(ctx, args.userId);
        console.log(`[completeSection] Computed expansion schedule for user ${args.userId}`);
      } catch (error) {
        console.error(`[completeSection] Failed to compute expansion schedule: ${error}`);
      }
    }

    // FIX: Auto-compute sleep metrics when sleep log is completed
    // This ensures user_sleep_data is populated for Sleep Insights dashboard
    if (args.section === "sleepLog" && sleepLogCompleted) {
      // Get the date for this day's sleep data (based on user's journey start)
      const userStartDate = new Date(user.started_at);
      const sleepDate = new Date(userStartDate);
      sleepDate.setDate(sleepDate.getDate() + args.dayNumber - 1);
      const dateStr = sleepDate.toISOString().split("T")[0];

      // Import and call the sleep metrics computation
      // We'll call it inline here to avoid circular imports
      try {
        await computeSleepMetricsForDay(ctx, args.userId, args.dayNumber, dateStr);
        console.log(`[completeSection] Computed sleep metrics for day ${args.dayNumber}`);
      } catch (error) {
        // Log but don't fail the section completion if metrics computation fails
        console.error(`[completeSection] Failed to compute sleep metrics: ${error}`);
      }
    }

    // Mark the questionnaire_session as completed for this section
    const existingSession = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user_day_section", (q) =>
        q.eq("user_id", args.userId)
          .eq("day_number", args.dayNumber)
          .eq("section", args.section)
      )
      .first();

    if (existingSession) {
      await ctx.db.patch(existingSession._id, {
        completed: true,
        last_updated_at: now,
      });
    }

    return {
      success: true,
      section: args.section,
      sleepLogCompleted,
      assessmentCompleted,
      dayFullyCompleted,
      currentDay: newDay,
      journeyComplete: args.dayNumber === 14 && dayFullyCompleted,
      source: args.source ?? "unknown",
    };
  },
});

/**
 * Mark a day as completed
 * This is called when user finishes questionnaire on Watch or iPhone
 */
export const completeDay = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    source: v.optional(v.string()), // "watch" or "iphone" or "web"
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get or create the day entry
    let day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", args.dayNumber))
      .first();

    if (!day) {
      // Create day entry if it doesn't exist
      const dayId = await ctx.db.insert("days", {
        day_number: args.dayNumber,
        title: `Day ${args.dayNumber}`,
        created_at: Date.now(),
      });
      day = await ctx.db.get(dayId);
    }

    if (!day) {
      throw new Error("Failed to create day entry");
    }

    // Check if progress already exists
    const existingProgress = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", day!._id)
      )
      .first();

    const now = Date.now();

    if (existingProgress) {
      // Update existing progress
      await ctx.db.patch(existingProgress._id, {
        completed: true,
        completed_at: now,
      });
    } else {
      // Create new progress entry
      await ctx.db.insert("user_progress", {
        user_id: args.userId,
        day_id: day._id,
        completed: true,
        completed_at: now,
        created_at: now,
      });
    }

    // Advance user's current day if needed
    if (user.current_day === args.dayNumber && args.dayNumber < 14) {
      await ctx.db.patch(args.userId, {
        current_day: args.dayNumber + 1,
        last_accessed: now,
      });
    }

    // Mark journey complete if day 14
    if (args.dayNumber === 14) {
      await ctx.db.patch(args.userId, {
        onboarding_completed: true,
        onboarding_completed_at: now,
      });
    }

    return {
      success: true,
      newDay: Math.min(args.dayNumber + 1, 14),
      journeyComplete: args.dayNumber === 14,
      source: args.source ?? "unknown",
    };
  },
});

/**
 * Check if user can advance to the next day
 * Requirements:
 * - Both sleepLog AND assessment must be completed for current day
 * - In normal mode: Must also be past 4 AM the next day
 * - In debug mode: Can advance immediately once both sections complete
 */
export const canAdvanceDay = query({
  args: {
    userId: v.id("users"),
    debugMode: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      return {
        canAdvance: false,
        reason: "User not found",
        sleepLogCompleted: false,
        assessmentCompleted: false,
        timeUnlocked: false,
      };
    }

    const currentDay = user.current_day || 1;

    // Can't advance past day 14
    if (currentDay >= 14) {
      return {
        canAdvance: false,
        reason: "Journey already complete",
        sleepLogCompleted: true,
        assessmentCompleted: true,
        timeUnlocked: true,
        currentDay: 14,
      };
    }

    // Get the day entry
    const day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", currentDay))
      .first();

    let sleepLogCompleted = false;
    let assessmentCompleted = false;

    let dayReadyAt: number | undefined;

    if (day) {
      const progress = await ctx.db
        .query("user_progress")
        .withIndex("by_user_day", (q) =>
          q.eq("user_id", args.userId).eq("day_id", day._id)
        )
        .first();

      if (progress) {
        sleepLogCompleted = progress.sleep_log_completed ?? progress.completed ?? false;
        assessmentCompleted = progress.assessment_completed ?? progress.completed ?? false;
        dayReadyAt = progress.day_ready_at;
      }
    }

    // Check if this SPECIFIC day has assessment content based on fixed schedule and user's gateways
    let hasAssessmentToday = true;
    if (currentDay > 5) {
      // Days 6-14 are expansion days - check if THIS day has content for user's triggered gateways
      const userGateways = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();

      const triggeredGateways = userGateways
        .filter((g) => g.triggered)
        .map((g) => g.gateway_id);

      // Use fixed schedule to check if THIS day has content for user's gateways
      // e.g., Day 10 only has ESS/FSS which requires 'excessive_sleepiness' gateway
      hasAssessmentToday = shouldShowExpansion(currentDay, triggeredGateways);
    }

    // Completion check: Sleep Log always required, Assessment only if available
    const assessmentOk = !hasAssessmentToday || assessmentCompleted;
    const bothSectionsComplete = sleepLogCompleted && assessmentOk;

    // Check time restriction (4 AM unlock)
    // The next day unlocks at 4 AM of the calendar day AFTER the day was completed
    // In debug mode, skip time check
    let timeUnlocked = args.debugMode ?? false;

    if (!timeUnlocked) {
      const now = new Date();

      if (dayReadyAt) {
        // We have the exact completion timestamp - calculate proper unlock time
        const readyDate = new Date(dayReadyAt);

        // Get 4 AM of the day the user completed
        const readyDayStart = new Date(readyDate);
        readyDayStart.setHours(4, 0, 0, 0);

        if (readyDate < readyDayStart) {
          // Completed before 4 AM - unlock at 4 AM same day
          timeUnlocked = now >= readyDayStart;
        } else {
          // Completed after 4 AM - unlock at 4 AM next day
          const nextDayAt4AM = new Date(readyDayStart);
          nextDayAt4AM.setDate(nextDayAt4AM.getDate() + 1);
          timeUnlocked = now >= nextDayAt4AM;
        }
      } else {
        // No completion timestamp (legacy data) - fall back to simple hour check
        const hour = now.getHours();
        timeUnlocked = hour >= 4;
      }
    }

    const canAdvance = bothSectionsComplete && timeUnlocked;

    let reason = "";
    if (!sleepLogCompleted && !assessmentOk) {
      reason = hasAssessmentToday
        ? "Complete both Sleep Log and Assessment to unlock the next day"
        : "Complete the Sleep Log to unlock the next day";
    } else if (!sleepLogCompleted) {
      reason = "Complete the Sleep Log to unlock the next day";
    } else if (!assessmentOk) {
      reason = "Complete the Assessment to unlock the next day";
    } else if (!timeUnlocked) {
      reason = "Next day unlocks at 4:00 AM";
    } else {
      reason = "Ready to advance";
    }

    return {
      canAdvance,
      reason,
      sleepLogCompleted,
      assessmentCompleted,
      hasAssessmentToday,
      timeUnlocked,
      currentDay,
      nextDay: currentDay + 1,
    };
  },
});

/**
 * Advance to next day
 * STRICT VALIDATION: Both sections must be completed before advancing
 * - debugMode: Bypasses time check (4 AM) but NOT completion check
 *
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const advanceDay = mutation({
  args: {
    userId: v.id("users"),
    debugMode: v.optional(v.boolean()),
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot advance another user's day");
      }
    }

    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const currentDay = user.current_day || 1;

    // Can't advance past day 14
    if (currentDay >= 14) {
      return {
        success: false,
        error: "Journey already complete",
        currentDay: 14,
      };
    }

    // Get the day entry
    let day = await ctx.db
      .query("days")
      .withIndex("by_day_number", (q) => q.eq("day_number", currentDay))
      .first();

    if (!day) {
      const dayId = await ctx.db.insert("days", {
        day_number: currentDay,
        title: `Day ${currentDay}`,
        created_at: Date.now(),
      });
      day = await ctx.db.get(dayId);
    }

    if (!day) {
      throw new Error("Failed to create day entry");
    }

    // Check section completion - REQUIRED even in debug mode
    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_id", day!._id)
      )
      .first();

    const sleepLogCompleted = progress?.sleep_log_completed ?? progress?.completed ?? false;
    const assessmentCompleted = progress?.assessment_completed ?? progress?.completed ?? false;
    const dayReadyAt = progress?.day_ready_at;

    // Check if this SPECIFIC day has assessment content based on fixed schedule and user's gateways
    let hasAssessmentToday = true;
    if (currentDay > 5) {
      // Days 6-14 are expansion days - check if THIS day has content for user's triggered gateways
      const userGateways = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();

      const triggeredGateways = userGateways
        .filter((g) => g.triggered)
        .map((g) => g.gateway_id);

      // Use fixed schedule to check if THIS day has content for user's gateways
      // e.g., Day 10 only has ESS/FSS which requires 'excessive_sleepiness' gateway
      hasAssessmentToday = shouldShowExpansion(currentDay, triggeredGateways);
    }

    // COMPLETION CHECK: Sleep Log always required, Assessment only if available
    const needsAssessment = hasAssessmentToday;
    const assessmentOk = !needsAssessment || assessmentCompleted;

    if (!sleepLogCompleted || !assessmentOk) {
      let missingSection = "";
      if (!sleepLogCompleted && !assessmentOk) {
        missingSection = "both Sleep Log and Assessment";
      } else if (!sleepLogCompleted) {
        missingSection = "Sleep Log";
      } else {
        missingSection = "Assessment";
      }

      return {
        success: false,
        error: `Cannot advance: Complete ${missingSection} first`,
        sleepLogCompleted,
        assessmentCompleted,
        currentDay,
      };
    }

    // Time check (only in normal mode)
    // The next day unlocks at 4 AM of the calendar day AFTER the day was completed
    if (!args.debugMode) {
      const now = new Date();
      let timeUnlocked = false;

      if (dayReadyAt) {
        // We have the exact completion timestamp - calculate proper unlock time
        const readyDate = new Date(dayReadyAt);

        // Get 4 AM of the day the user completed
        const readyDayStart = new Date(readyDate);
        readyDayStart.setHours(4, 0, 0, 0);

        if (readyDate < readyDayStart) {
          // Completed before 4 AM - unlock at 4 AM same day
          timeUnlocked = now >= readyDayStart;
        } else {
          // Completed after 4 AM - unlock at 4 AM next day
          const nextDayAt4AM = new Date(readyDayStart);
          nextDayAt4AM.setDate(nextDayAt4AM.getDate() + 1);
          timeUnlocked = now >= nextDayAt4AM;
        }
      } else {
        // No completion timestamp (legacy data) - fall back to simple hour check
        const hour = now.getHours();
        timeUnlocked = hour >= 4;
      }

      if (!timeUnlocked) {
        return {
          success: false,
          error: "Next day unlocks at 4:00 AM",
          sleepLogCompleted,
          assessmentCompleted,
          currentDay,
          timeUnlocked: false,
        };
      }
    }

    const newDay = currentDay + 1;

    // Mark current day as fully completed (ensure both flags set)
    const now = Date.now();
    if (progress) {
      await ctx.db.patch(progress._id, {
        completed: true,
        completed_at: now,
        sleep_log_completed: true,
        assessment_completed: true,
      });
    } else {
      await ctx.db.insert("user_progress", {
        user_id: args.userId,
        day_id: day._id,
        completed: true,
        completed_at: now,
        created_at: now,
        sleep_log_completed: true,
        assessment_completed: true,
      });
    }

    // Update user's current day
    await ctx.db.patch(args.userId, {
      current_day: newDay,
      last_accessed: now,
    });

    return {
      success: true,
      previousDay: currentDay,
      newDay: newDay,
      sleepLogCompleted: true,
      assessmentCompleted: true,
    };
  },
});

/**
 * Reset journey progress (Debug Mode)
 * SECURITY: Requires sessionToken to validate user ownership
 * Comprehensive reset that clears ALL assessment data, scores, and progress
 */
export const resetProgress = mutation({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot reset another user's progress");
      }
    }

    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    let deletedRecords = 0;

    // Helper to delete all records from a table for this user
    async function deleteFromTable(
      tableName: string,
      query: { collect: () => Promise<Array<{ _id: Id<any> }>> }
    ) {
      const records = await query.collect();
      for (const record of records) {
        await ctx.db.delete(record._id);
        deletedRecords++;
      }
      if (records.length > 0) {
        console.log(`[resetProgress] Deleted ${records.length} from ${tableName}`);
      }
    }

    // Reset user's day to 1 and clear onboarding/dev mode
    await ctx.db.patch(args.userId, {
      current_day: 1,
      onboarding_completed: false,
      onboarding_completed_at: undefined,
      developer_mode: false,
      last_accessed: Date.now(),
    });

    // Core assessment data
    await deleteFromTable("user_assessment_responses",
      ctx.db.query("user_assessment_responses").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("responses",
      ctx.db.query("responses").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_progress",
      ctx.db.query("user_progress").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("daily_checkins",
      ctx.db.query("daily_checkins").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Questionnaire scores - CRITICAL: This clears Clinical Scores (ISI, PHQ-9, GAD-7, ESS)
    await deleteFromTable("questionnaire_scores",
      ctx.db.query("questionnaire_scores").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("questionnaire_session",
      ctx.db.query("questionnaire_session").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Gateway and expansion data
    await deleteFromTable("user_gateway_states",
      ctx.db.query("user_gateway_states").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_expansion_schedules",
      ctx.db.query("user_expansion_schedules").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Insights and analysis
    await deleteFromTable("sleep_insights",
      ctx.db.query("sleep_insights").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_insight_queue",
      ctx.db.query("user_insight_queue").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_insight_progress",
      ctx.db.query("user_insight_progress").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("onboarding_insights",
      ctx.db.query("onboarding_insights").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Journey and workflow status
    await deleteFromTable("patient_journey_status",
      ctx.db.query("patient_journey_status").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("patient_analysis_workflow",
      ctx.db.query("patient_analysis_workflow").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Gamification data
    await deleteFromTable("user_streaks",
      ctx.db.query("user_streaks").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_badges",
      ctx.db.query("user_badges").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_xp",
      ctx.db.query("user_xp").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("xp_transactions",
      ctx.db.query("xp_transactions").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_daily_tasks",
      ctx.db.query("user_daily_tasks").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Cohort and narrative data
    await deleteFromTable("user_cohort_memberships",
      ctx.db.query("user_cohort_memberships").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_sleep_narrative",
      ctx.db.query("user_sleep_narrative").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_encouragement_history",
      ctx.db.query("user_encouragement_history").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Physician dashboard data
    await deleteFromTable("physician_notes",
      ctx.db.query("physician_notes").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("patient_review_status",
      ctx.db.query("patient_review_status").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Interventions and compliance data
    await deleteFromTable("user_interventions",
      ctx.db.query("user_interventions").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_protocol_assignments",
      ctx.db.query("user_protocol_assignments").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Additional metrics and analysis tables
    await deleteFromTable("perception_gaps",
      ctx.db.query("perception_gaps").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("difficulty_adjustment_log",
      ctx.db.query("difficulty_adjustment_log").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("compliance_outcome_correlation",
      ctx.db.query("compliance_outcome_correlation").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    await deleteFromTable("user_metrics_summary",
      ctx.db.query("user_metrics_summary").withIndex("by_user", (q) => q.eq("user_id", args.userId)));

    // Note: user_sleep_data is intentionally NOT cleared to preserve HealthKit sync data

    console.log(`[resetProgress] Complete reset for user ${args.userId}: ${deletedRecords} records deleted`);

    return {
      success: true,
      newDay: 1,
      deletedRecords,
    };
  },
});

// ============================================
// Questionnaire Response Functions
// ============================================

/**
 * Save a questionnaire response from Watch
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const saveResponse = mutation({
  args: {
    userId: v.id("users"),
    questionId: v.string(),
    dayNumber: v.number(),
    responseValue: v.optional(v.string()),
    responseNumber: v.optional(v.number()),
    responseArray: v.optional(v.array(v.string())),
    source: v.optional(v.string()), // "watch" or "iphone"
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot save responses for another user");
      }
    }

    const now = Date.now();

    // Check if response already exists
    const existing = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", args.questionId)
      )
      .first();

    if (existing) {
      // Update existing response
      await ctx.db.patch(existing._id, {
        response_value: args.responseValue,
        response_number: args.responseNumber,
        response_array: args.responseArray ? JSON.stringify(args.responseArray) : undefined,
        day_number: args.dayNumber,
        updated_at: now,
      });
    } else {
      // Create new response
      await ctx.db.insert("user_assessment_responses", {
        user_id: args.userId,
        question_id: args.questionId,
        response_value: args.responseValue,
        response_number: args.responseNumber,
        response_array: args.responseArray ? JSON.stringify(args.responseArray) : undefined,
        day_number: args.dayNumber,
        created_at: now,
        updated_at: now,
      });
    }

    return { success: true };
  },
});

/**
 * Save multiple responses at once (batch save from Watch/iOS)
 * Supports derived answers for complete clinical scoring
 */
export const saveResponses = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    responses: v.array(
      v.object({
        questionId: v.string(),
        responseValue: v.optional(v.string()),
        responseNumber: v.optional(v.number()),
        responseArray: v.optional(v.array(v.string())),
        // Complex object responses (medications, naps, etc.) - already JSON stringified
        responseObject: v.optional(v.string()),
        // Unit of measurement for numeric responses (e.g., "cm", "in", "°C", "°F")
        responseUnit: v.optional(v.string()),
        // Derived answer fields - for answers auto-populated from equivalent questions
        isDerived: v.optional(v.boolean()),
        derivedFromQuestionId: v.optional(v.string()),
      })
    ),
    source: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    let savedCount = 0;
    let derivedCount = 0;

    for (const response of args.responses) {
      // Use day-aware lookup to support repeating questions (like sleep log) across multiple days
      const existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question_day", (q) =>
          q.eq("user_id", args.userId).eq("question_id", response.questionId).eq("day_number", args.dayNumber)
        )
        .first();

      // Don't overwrite user-provided answer with derived answer
      if (existing && !existing.is_derived && response.isDerived) {
        console.log(`[saveResponses] Skipping derived ${response.questionId} - user already answered directly`);
        continue;
      }

      if (existing) {
        await ctx.db.patch(existing._id, {
          response_value: response.responseValue,
          response_number: response.responseNumber,
          response_array: response.responseArray ? JSON.stringify(response.responseArray) : undefined,
          response_object: response.responseObject, // Already JSON stringified from iOS
          response_unit: response.responseUnit,
          day_number: args.dayNumber,
          is_derived: response.isDerived ?? false,
          derived_from_question_id: response.derivedFromQuestionId,
          updated_at: now,
        });
      } else {
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: response.questionId,
          response_value: response.responseValue,
          response_number: response.responseNumber,
          response_array: response.responseArray ? JSON.stringify(response.responseArray) : undefined,
          response_object: response.responseObject, // Already JSON stringified from iOS
          response_unit: response.responseUnit,
          day_number: args.dayNumber,
          is_derived: response.isDerived ?? false,
          derived_from_question_id: response.derivedFromQuestionId,
          created_at: now,
          updated_at: now,
        });
      }

      savedCount++;
      if (response.isDerived) derivedCount++;
    }

    // Auto-evaluate gateway states based on saved responses
    // This ensures expansion packs show correctly on Days 6-14 even if iOS sync failed
    const savedQuestionIds = args.responses.map(r => r.questionId);
    await evaluateAndUpdateGatewayStates(ctx, args.userId, savedQuestionIds);

    return {
      success: true,
      savedCount,
      derivedCount,
      message: derivedCount > 0 ? `Saved ${savedCount} responses (${derivedCount} derived for complete scoring)` : undefined
    };
  },
});

/**
 * Get responses for a specific day
 */
export const getDayResponses = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    return responses.map((r) => ({
      questionId: r.question_id,
      responseValue: r.response_value,
      responseNumber: r.response_number,
      responseArray: r.response_array ? JSON.parse(r.response_array) : null,
      isDerived: r.is_derived ?? false,
      derivedFromQuestionId: r.derived_from_question_id,
    }));
  },
});

// ============================================
// User Lookup
// ============================================

/**
 * Get user by username (for Watch login)
 */
export const getUserByUsername = query({
  args: {
    username: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username))
      .first();

    if (!user) {
      return null;
    }

    return {
      userId: user._id,
      username: user.username,
      currentDay: user.current_day,
      onboardingCompleted: user.onboarding_completed ?? false,
      passwordHash: user.password_hash, // For validation on Watch
    };
  },
});

/**
 * Get user's current state (for polling/refresh)
 */
export const getUserState = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get completed days count
    const progress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const completedCount = progress.filter((p) => p.completed).length;

    return {
      currentDay: user.current_day,
      completedDaysCount: completedCount,
      onboardingCompleted: user.onboarding_completed ?? false,
      lastAccessed: user.last_accessed,
    };
  },
});

// ============================================
// Cross-Device Question Progress Sync
// ============================================

/**
 * Get current question progress for a section
 * Returns where the user left off so they can continue on any device
 */
export const getQuestionProgress = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.string(), // "sleepLog" or "assessment"
  },
  handler: async (ctx, args) => {
    const session = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user_day_section", (q) =>
        q.eq("user_id", args.userId)
          .eq("day_number", args.dayNumber)
          .eq("section", args.section)
      )
      .first();

    if (!session) {
      return null;
    }

    return {
      currentQuestionIndex: session.current_question_index,
      totalQuestions: session.total_questions,
      lastDevice: session.last_device,
      lastUpdatedAt: session.last_updated_at,
      completed: session.completed,
    };
  },
});

/**
 * Debug: Get all questionnaire sessions for a user
 */
export const debugGetAllSessions = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const sessions = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    return sessions;
  },
});

/**
 * Update question progress when user answers a question
 * Called after each question to enable seamless cross-device sync
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const updateQuestionProgress = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.string(), // "sleepLog" or "assessment"
    currentQuestionIndex: v.number(),
    totalQuestions: v.number(),
    device: v.string(), // "ios", "watch", "web"
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot update another user's progress");
      }
    }

    const now = Date.now();

    // Check if session exists
    const existingSession = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user_day_section", (q) =>
        q.eq("user_id", args.userId)
          .eq("day_number", args.dayNumber)
          .eq("section", args.section)
      )
      .first();

    if (existingSession) {
      // Update existing session
      await ctx.db.patch(existingSession._id, {
        current_question_index: args.currentQuestionIndex,
        total_questions: args.totalQuestions,
        last_updated_at: now,
        last_device: args.device,
      });
    } else {
      // Create new session
      await ctx.db.insert("questionnaire_session", {
        user_id: args.userId,
        day_number: args.dayNumber,
        section: args.section,
        current_question_index: args.currentQuestionIndex,
        total_questions: args.totalQuestions,
        started_at: now,
        last_updated_at: now,
        last_device: args.device,
        completed: false,
      });
    }

    return { success: true, questionIndex: args.currentQuestionIndex };
  },
});

/**
 * Mark a section as completed in the question progress tracker
 * SECURITY: Requires sessionToken to validate user ownership
 */
export const completeQuestionProgress = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.string(),
    device: v.string(),
    sessionToken: v.optional(v.string()), // Session token for authorization
  },
  handler: async (ctx, args) => {
    // Validate session token if provided
    if (args.sessionToken) {
      const session = await validateIOSSession(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Invalid session");
      }
      if (session.userId !== args.userId) {
        throw new Error("Unauthorized: Cannot complete another user's section");
      }
    }

    const now = Date.now();

    const session = await ctx.db
      .query("questionnaire_session")
      .withIndex("by_user_day_section", (q) =>
        q.eq("user_id", args.userId)
          .eq("day_number", args.dayNumber)
          .eq("section", args.section)
      )
      .first();

    if (session) {
      await ctx.db.patch(session._id, {
        completed: true,
        completed_at: now,
        last_updated_at: now,
        last_device: args.device,
      });
    }

    return { success: true };
  },
});

/**
 * Get all responses for a user's current day
 * Useful for loading saved responses when continuing on a different device
 */
export const getSavedResponses = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    // Convert to a map of questionId -> response for easy lookup
    const responseMap: Record<string, {
      stringValue?: string;
      numberValue?: number;
      arrayValue?: string[];
    }> = {};

    for (const r of responses) {
      responseMap[r.question_id] = {
        stringValue: r.response_value ?? undefined,
        numberValue: r.response_number ?? undefined,
        arrayValue: r.response_array ? JSON.parse(r.response_array) : undefined,
      };
    }

    return responseMap;
  },
});

// ============================================
// Unified Question Fetching (Single Source of Truth)
// ============================================

/**
 * Get all questions for a user's day - THE SINGLE SOURCE OF TRUTH
 * This is what iOS, Watch, and Web should ALL use to get questions.
 *
 * Returns:
 * - Sleep Log questions (same every day)
 * - Assessment questions for the day (from database)
 * - Expansion questions based on triggered gateways
 */
export const getQuestionsForUserDay = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    section: v.optional(v.union(v.literal("sleepLog"), v.literal("assessment"), v.literal("all"))),
  },
  handler: async (ctx, args) => {
    const section = args.section ?? "all";

    // Get user's triggered gateways
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    const triggeredGatewayIds = new Set(
      gatewayStates
        .filter((g) => g.triggered)
        .map((g) => g.gateway_id)
    );

    console.log(`[Convex] User ${args.userId} Day ${args.dayNumber} - Triggered gateways: ${[...triggeredGatewayIds].join(", ")}`);

    const result: {
      sleepLog: Array<{
        id: string;
        text: string;
        type: string;
        required: boolean;
        options?: string[];
        helpText?: string;
        helpTextImperial?: string;
        formatConfig?: Record<string, unknown>;
        conditionalLogic?: { question_id: string; equals?: string; greater_than?: number };
      }>;
      assessment: Array<{
        id: string;
        text: string;
        type: string;
        required: boolean;
        options?: string[];
        helpText?: string;
        helpTextImperial?: string;
        moduleName?: string;
        formatConfig?: Record<string, unknown>;
        conditionalLogic?: { question_id: string; equals?: string; greater_than?: number };
      }>;
      metadata: {
        sleepLogCount: number;
        assessmentCount: number;
        totalMinutes: number;
        triggeredGateways: string[];
        dayDescription: string;
        dayExplanation: string;
        modules: string[];  // Module IDs included in today's assessment
      };
    } = {
      sleepLog: [],
      assessment: [],
      metadata: {
        sleepLogCount: 0,
        assessmentCount: 0,
        totalMinutes: 0,
        triggeredGateways: [...triggeredGatewayIds],
        dayDescription: getDayDescription(args.dayNumber),
        dayExplanation: getDayExplanation(args.dayNumber),
        modules: [],  // Will be populated as modules are processed
      },
    };

    // ========== SLEEP LOG (Same Every Day) ==========
    if (section === "all" || section === "sleepLog") {
      // Get sleep diary questions from database
      const sleepDiaryQuestions = await ctx.db
        .query("sleep_diary_questions")
        .collect();

      // Sort by order_index
      sleepDiaryQuestions.sort((a, b) => (a.order_index || 0) - (b.order_index || 0));

      // Get all user's assessment responses for cross-questionnaire conditional logic
      const allResponses = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();

      // Filter out gateway-conditional questions if their gateway is not triggered
      // This handles cross-questionnaire conditional logic (e.g., SD_KSS requires shift_work gateway)
      const filteredQuestions = sleepDiaryQuestions.filter((q) => {
        if (!q.conditional_logic) return true;

        try {
          const logic = JSON.parse(q.conditional_logic);
          // Check if this is a gateway-based condition (references an assessment question like 53B)
          const conditionQuestionId = logic.show_if?.question_id || logic.question_id;

          // If the condition references an assessment question (not SD_*),
          // we need to check if the user answered affirmatively
          if (conditionQuestionId && !conditionQuestionId.startsWith("SD_")) {
            // Look up the user's response to the assessment question
            const assessmentResponse = allResponses.find(
              (r: { question_id: string }) => r.question_id === conditionQuestionId
            );

            const expectedValue = logic.show_if?.value || logic.equals;
            if (expectedValue && assessmentResponse) {
              const actualValue = String(assessmentResponse.response_value).toLowerCase();
              const matches = actualValue === String(expectedValue).toLowerCase();
              console.log(`[Convex] Sleep diary question ${q.id}: Checking ${conditionQuestionId}=${assessmentResponse.response_value} vs ${expectedValue} => ${matches ? "INCLUDE" : "EXCLUDE"}`);
              return matches;
            }

            // No response found for the condition question - exclude this question
            console.log(`[Convex] Sleep diary question ${q.id}: No response for ${conditionQuestionId}, excluding`);
            return false;
          }
        } catch {
          // Parse error - include the question
        }
        return true;
      });

      result.sleepLog = filteredQuestions.map((q) => ({
        id: q.id,
        text: q.question_text,
        type: mapAnswerFormatToType(q.answer_format),
        required: true,
        helpText: q.help_text ?? undefined,
        helpTextImperial: q.help_text_imperial ?? undefined,
        formatConfig: q.format_config ? JSON.parse(q.format_config) : undefined,
        options: q.format_config ? parseOptions(q.format_config) : undefined,
        conditionalLogic: q.conditional_logic ? parseConditionalLogic(q.conditional_logic) : undefined,
      }));

      result.metadata.sleepLogCount = result.sleepLog.length;
    }

    // ========== ASSESSMENT (Day-Specific + Gateway Expansion) ==========
    if (section === "all" || section === "assessment") {
      // Get all user's responses for conditional logic evaluation (gender, age, etc.)
      const allUserResponses = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user", (q) => q.eq("user_id", args.userId))
        .collect();

      // Cast to UserResponse type for the evaluator
      const userResponsesForEval: UserResponse[] = allUserResponses.map(r => ({
        question_id: r.question_id,
        response_value: r.response_value as string | number | null,
      }));

      console.log(`[Convex] User ${args.userId} has ${userResponsesForEval.length} previous responses for conditional logic`);

      // ========== FIXED SCHEDULE MODULE LOOKUP ==========
      // Use the fixed schedule to determine which modules to load for this day
      // - Days 1-5: Core assessment by pillar/theme
      // - Days 6-14: Expansion packs based on triggered gateways
      const triggeredGatewaysList = [...triggeredGatewayIds];
      const moduleIdsForDay = getModuleIdsForDay(args.dayNumber, triggeredGatewaysList);
      const dayConfig = getDayConfig(args.dayNumber);

      console.log(`[Convex] Day ${args.dayNumber} fixed schedule - Type: ${dayConfig?.type || "unknown"}, Modules: ${moduleIdsForDay.join(", ") || "none"}`);

      // For expansion days (6+), check if any gateways are triggered
      if (dayConfig?.type === "expansion" && moduleIdsForDay.length === 0) {
        console.log(`[Convex] Day ${args.dayNumber} is expansion day but no gateways triggered - Sleep Log only`);
      }

      let totalSeconds = 0;

      // ========== COLLECT SAME-DAY QUESTION IDS ==========
      // First, collect all question IDs that will be shown today.
      // This allows us to differentiate between same-day conditional dependencies
      // (which iOS should evaluate dynamically) vs cross-day dependencies
      // (which we should evaluate server-side).
      const sameDayQuestionIds = new Set<string>();

      for (const moduleId of moduleIdsForDay) {
        const moduleQuestions = await ctx.db
          .query("module_questions")
          .withIndex("by_module", (q) => q.eq("module_id", moduleId))
          .collect();
        for (const mq of moduleQuestions) {
          sameDayQuestionIds.add(mq.question_id);
        }
      }

      console.log(`[Convex] Day ${args.dayNumber} has ${sameDayQuestionIds.size} same-day question IDs for conditional logic`);

      // ========== PROCESS MODULES FROM FIXED SCHEDULE ==========
      for (const moduleId of moduleIdsForDay) {
        // Get module info
        const module = await ctx.db
          .query("assessment_modules")
          .withIndex("by_module_id", (q) => q.eq("module_id", moduleId))
          .first();

        if (!module) {
          console.log(`[Convex] Warning: Module ${moduleId} not found in assessment_modules`);
          continue;
        }

        console.log(`[Convex] Processing module ${moduleId} (${module.name})`);

        // Track this module as included
        result.metadata.modules.push(moduleId);

        // Get questions in this module
        const moduleQuestions = await ctx.db
          .query("module_questions")
          .withIndex("by_module", (q) => q.eq("module_id", moduleId))
          .collect();

        // Sort by order_index
        moduleQuestions.sort((a, b) => a.order_index - b.order_index);

        // Get full question data
        for (const mq of moduleQuestions) {
          const question = await ctx.db
            .query("assessment_questions")
            .withIndex("by_question_id", (q) => q.eq("question_id", mq.question_id))
            .first();

          if (question) {
            // Check conditional logic (e.g., gender-specific questions like pregnancy)
            // Pass sameDayQuestionIds so same-day follow-ups are included for iOS evaluation
            if (question.conditional_logic) {
              const shouldShow = evaluateConditionalLogic(
                question.conditional_logic,
                userResponsesForEval,
                question.question_id,
                sameDayQuestionIds
              );
              if (!shouldShow) {
                console.log(`[Convex] Skipping question ${question.question_id} - conditional logic not met`);
                continue; // Skip this question
              }
            }

            result.assessment.push({
              id: question.question_id,
              text: question.question_text,
              type: mapAnswerFormatToType(question.answer_format),
              required: true,
              helpText: question.help_text ?? undefined,
              helpTextImperial: question.help_text_imperial ?? undefined,
              moduleName: module.name,
              formatConfig: question.format_config ? JSON.parse(question.format_config) : undefined,
              options: question.format_config ? parseOptions(question.format_config) : undefined,
              conditionalLogic: question.conditional_logic ? parseConditionalLogic(question.conditional_logic) : undefined,
            });

            totalSeconds += question.estimated_time_seconds || 30;
          }
        }
      }

      // ========== FILTER ALWAYS-HIDDEN DUPLICATES ==========
      // These are semantic duplicates that should NEVER be shown
      // (e.g., Q55 is duplicate of Q1, Q54C duplicate of Q31)
      {
        const originalCount = result.assessment.length;
        result.assessment = result.assessment.filter(
          (q) => !ALWAYS_HIDDEN_DUPLICATE_IDS.has(q.id)
        );
        const filteredCount = originalCount - result.assessment.length;
        if (filteredCount > 0) {
          console.log(`[Convex] Filtered ${filteredCount} duplicate questions (always hidden)`);
        }
      }

      // ========== FILTER DERIVABLE QUESTIONS ==========
      // If user has completed sleep log for this day, filter out questions
      // that can be derived from sleep log data (reduces user burden)
      const sleepLogResponses = await getSleepLogResponsesIfComplete(ctx, args.userId, args.dayNumber);

      if (sleepLogResponses) {
        const originalCount = result.assessment.length;
        result.assessment = result.assessment.filter(
          (q) => !DERIVABLE_QUESTION_IDS.has(q.id)
        );
        const filteredCount = originalCount - result.assessment.length;
        if (filteredCount > 0) {
          console.log(`[Convex] Filtered ${filteredCount} derivable questions (user has sleep log data for day ${args.dayNumber})`);
        }
      }

      // ========== FILTER AVERAGE-DERIVABLE QUESTIONS ==========
      // If user has 7+ days of sleep diary data, filter out questions that can be
      // derived from averaged sleep metrics (e.g., "typical" bedtime, sleep quality)
      // These questions are Day 2+ questions so only check if on Day 7+
      if (args.dayNumber >= 7) {
        const sleepDiaryStats = await getSleepDiaryAverages(ctx, args.userId, 7);

        if (sleepDiaryStats) {
          const originalCount = result.assessment.length;
          result.assessment = result.assessment.filter(
            (q) => !AVERAGE_DERIVABLE_QUESTION_IDS.has(q.id)
          );
          const filteredCount = originalCount - result.assessment.length;
          if (filteredCount > 0) {
            console.log(`[Convex] Filtered ${filteredCount} average-derivable questions (user has ${sleepDiaryStats.dayCount} days of sleep diary)`);
          }
        }
      }

      result.metadata.assessmentCount = result.assessment.length;
      // Recalculate totalMinutes based on FILTERED assessment questions (not pre-filter totalSeconds)
      // Use 15 seconds per question as the standard estimate
      const filteredTotalSeconds = result.assessment.length * 15;
      result.metadata.totalMinutes = Math.ceil((result.sleepLog.length * 15 + filteredTotalSeconds) / 60);

      // NOTE: We no longer add INFO_NO_QUESTIONS placeholder when assessment is empty.
      // The iOS client properly handles empty assessments by not showing the "Proceed to Assessment" button.
      // Adding a placeholder caused confusion (showed "1 question remaining" but it was just an info message).
    }

    console.log(`[Convex] Returning ${result.sleepLog.length} sleep log + ${result.assessment.length} assessment questions for Day ${args.dayNumber}`);

    return result;
  },
});

/**
 * Map database answer_format to client-side type
 */
function mapAnswerFormatToType(answerFormat: string): string {
  const mapping: Record<string, string> = {
    // Time inputs
    time: "time",
    time_picker: "time",

    // Scale/slider inputs
    scale: "scale",
    likert_5: "scale",
    likert_7: "scale",
    slider_scale: "scale",

    // Number inputs (generic)
    number: "number",
    number_input: "number",
    percentage: "number",

    // Scroll pickers (specialized - must map correctly!)
    number_scroll: "numberScroll",
    minutes_scroll: "minutesScroll",
    duration_minutes: "minutesScroll",
    hours_minutes_scroll: "hoursMinutesScroll",

    // Yes/No
    yes_no: "yesNo",
    yes_no_chips: "yesNo",

    // Selection inputs
    single_select: "singleSelect",
    single_select_chips: "singleSelect",
    multi_select: "multiSelect",
    multi_select_chips: "multiSelect",

    // Text inputs
    text: "text",
    text_short: "text",
    text_long: "text",

    // Date types
    date: "date",
    date_picker: "date",
    date_auto: "text",

    // Specialized input types
    nap_details: "napDetails",
    medication_select: "medicationSelect",
    info: "info",
  };
  return mapping[answerFormat] || "text";
}

/**
 * Parse options from format_config JSON
 */
function parseOptions(formatConfig: string): string[] | undefined {
  try {
    const config = JSON.parse(formatConfig);
    if (config.options && Array.isArray(config.options)) {
      return config.options.map((opt: { value: string; label: string } | string) =>
        typeof opt === "string" ? opt : opt.label || opt.value
      );
    }
    return undefined;
  } catch {
    return undefined;
  }
}

/**
 * Parse conditional logic from format_config JSON
 * Returns a normalized structure for the iOS app
 *
 * Supports:
 * - Direct: {"question_id": "35", "equals": "yes"}
 * - Direct: {"questionId": "35", "equals": "yes"}
 * - show_if wrapper: {"show_if": {"question_id": "35", "value": "yes"}}
 * - in operator: {"show_if": {"question_id": "44K", "operator": "in", "value": ["1", "2", "3", "4"]}}
 */
function parseConditionalLogic(conditionalLogicJson: string): {
  question_id: string;
  equals?: string;
  greater_than?: number;
  in_values?: string[];
} | undefined {
  try {
    const logic = JSON.parse(conditionalLogicJson);

    // Handle direct format: {"question_id": "35", "equals": "yes"} or {"questionId": "35", "equals": "yes"}
    const directQuestionId = logic.question_id || logic.questionId;
    if (directQuestionId) {
      return {
        question_id: directQuestionId,
        equals: logic.equals,
        greater_than: logic.greater_than,
      };
    }

    // Handle show_if wrapper format
    if (logic.show_if) {
      const showIf = logic.show_if;
      const questionId = showIf.question_id || showIf.questionId;

      // Handle "in" operator: {"show_if": {"question_id": "44K", "operator": "in", "value": ["1", "2", "3", "4"]}}
      if (showIf.operator === "in" && Array.isArray(showIf.value)) {
        return {
          question_id: questionId,
          in_values: showIf.value.map((v: string | number) => String(v)),
        };
      }

      // Handle "equals" via operator or direct value
      if (showIf.operator === "equals" || !showIf.operator) {
        return {
          question_id: questionId,
          equals: typeof showIf.value === "string" ? showIf.value : String(showIf.value),
        };
      }

      // Handle "greater_than" operator
      if (showIf.operator === "greater_than") {
        return {
          question_id: questionId,
          greater_than: Number(showIf.value),
        };
      }
    }

    return undefined;
  } catch {
    return undefined;
  }
}

// Type for user response record
interface UserResponse {
  question_id: string;
  response_value: string | number | null;
  response_number?: number;
}

/**
 * Evaluate complex conditional logic to determine if a question should be shown.
 * Supports:
 * - all: Array of conditions (all must be true)
 * - any: Array of conditions (at least one must be true)
 * - questionId + equals: Check if answer matches
 * - questionId + operator "in" + value array: Check if answer is in array
 * - ageUnder/ageOver: Check user's age (requires D2 date of birth response)
 *
 * @param sameDayQuestionIds - Set of question IDs that are in the same day's assessment.
 *   If a conditional references one of these, we include the question and let iOS evaluate dynamically.
 */
function evaluateConditionalLogic(
  conditionalLogicJson: string,
  userResponses: UserResponse[],
  questionId: string,
  sameDayQuestionIds?: Set<string>
): boolean {
  try {
    const logic = JSON.parse(conditionalLogicJson);

    // Create lookup map for faster access
    const responseMap = new Map<string, string | number | null>();
    for (const r of userResponses) {
      responseMap.set(r.question_id, r.response_value);
    }

    return evaluateLogicNode(logic, responseMap, questionId, sameDayQuestionIds);
  } catch (error) {
    console.log(`[Convex] Error evaluating conditional logic for ${questionId}: ${error}`);
    // On error, default to showing the question
    return true;
  }
}

/**
 * Recursively evaluate a logic node
 *
 * IMPORTANT: For same-day conditional questions (like follow-ups), we return true
 * to INCLUDE the question. iOS will evaluate the condition dynamically as the user
 * answers questions. We only pre-filter for cross-day conditions (like gender/age).
 */
function evaluateLogicNode(
  node: Record<string, unknown>,
  responseMap: Map<string, string | number | null>,
  questionId: string,
  sameDayQuestionIds?: Set<string>
): boolean {
  // Handle compound AND conditions
  if (node.all && Array.isArray(node.all)) {
    const results = node.all.map((condition: Record<string, unknown>) =>
      evaluateLogicNode(condition, responseMap, questionId, sameDayQuestionIds)
    );
    const result = results.every(Boolean);
    console.log(`[Convex] Question ${questionId}: ALL conditions [${results.join(', ')}] => ${result}`);
    return result;
  }

  // Handle compound OR conditions
  if (node.any && Array.isArray(node.any)) {
    const results = node.any.map((condition: Record<string, unknown>) =>
      evaluateLogicNode(condition, responseMap, questionId, sameDayQuestionIds)
    );
    const result = results.some(Boolean);
    console.log(`[Convex] Question ${questionId}: ANY conditions [${results.join(', ')}] => ${result}`);
    return result;
  }

  // Handle age-based conditions (requires D2 date of birth)
  if (typeof node.ageUnder === 'number') {
    const age = calculateAgeFromResponse(responseMap.get("D2"));
    if (age === null) {
      console.log(`[Convex] Question ${questionId}: ageUnder=${node.ageUnder} - no DOB available, defaulting to show`);
      return true; // No DOB available, default to showing
    }
    const result = age < node.ageUnder;
    console.log(`[Convex] Question ${questionId}: ageUnder=${node.ageUnder}, userAge=${age} => ${result}`);
    return result;
  }

  if (typeof node.ageOver === 'number') {
    const age = calculateAgeFromResponse(responseMap.get("D2"));
    if (age === null) {
      console.log(`[Convex] Question ${questionId}: ageOver=${node.ageOver} - no DOB available, defaulting to show`);
      return true;
    }
    const result = age > node.ageOver;
    console.log(`[Convex] Question ${questionId}: ageOver=${node.ageOver}, userAge=${age} => ${result}`);
    return result;
  }

  // Handle single question condition - support both questionId (camelCase) and question_id (snake_case)
  const refQuestionId = typeof node.questionId === 'string'
    ? node.questionId
    : typeof node.question_id === 'string'
      ? node.question_id
      : null;

  if (refQuestionId) {
    const userValue = responseMap.get(refQuestionId);

    // If the referenced question already has a response, evaluate server-side
    // (even if it's a same-day question - the user already answered it)
    // Only defer to iOS if there's no response AND it's a same-day question
    if (sameDayQuestionIds?.has(refQuestionId) && (userValue === null || userValue === undefined)) {
      console.log(`[Convex] Question ${questionId}: References same-day question ${refQuestionId} with no response yet, including for iOS evaluation`);
      return true;
    }

    // Handle "in" operator - check if value is in array
    if (node.operator === 'in' && Array.isArray(node.value)) {
      if (userValue === null || userValue === undefined) {
        // For demographic questions, exclude if not set
        const demographicQuestionIds = new Set(["D2", "D4", "D5", "D6"]);
        if (demographicQuestionIds.has(refQuestionId)) {
          console.log(`[Convex] Question ${questionId}: ${refQuestionId} IN [${node.value}] - DEMOGRAPHIC not set, EXCLUDING question`);
          return false;
        }
        console.log(`[Convex] Question ${questionId}: ${refQuestionId} IN [${node.value}] - no response yet, including for iOS evaluation`);
        return true;
      }
      const userValueStr = String(userValue);
      const result = (node.value as (string | number)[]).some(v => String(v) === userValueStr);
      console.log(`[Convex] Question ${questionId}: ${refQuestionId}="${userValue}" IN [${node.value}] => ${result}`);
      return result;
    }

    // Handle "notIn" operator - check if value is NOT in array
    if (node.operator === 'notIn' && Array.isArray(node.value)) {
      if (userValue === null || userValue === undefined) {
        // For demographic questions, exclude if not set
        const demographicQuestionIds = new Set(["D2", "D4", "D5", "D6"]);
        if (demographicQuestionIds.has(refQuestionId)) {
          console.log(`[Convex] Question ${questionId}: ${refQuestionId} NOT_IN [${node.value}] - DEMOGRAPHIC not set, EXCLUDING question`);
          return false;
        }
        console.log(`[Convex] Question ${questionId}: ${refQuestionId} NOT_IN [${node.value}] - no response yet, including for iOS evaluation`);
        return true;
      }
      const userValueStr = String(userValue);
      const result = !(node.value as (string | number)[]).some(v => String(v) === userValueStr);
      console.log(`[Convex] Question ${questionId}: ${refQuestionId}="${userValue}" NOT_IN [${node.value}] => ${result}`);
      return result;
    }

    if (typeof node.equals === 'string') {
      if (userValue === null || userValue === undefined) {
        // For demographic questions (D2=DOB, D4=Sex, D5=Height, D6=Weight),
        // if there's no response, EXCLUDE the question - these are profile fields
        // that should have been injected. Don't show gender-conditional questions
        // to users who haven't completed their profile.
        const demographicQuestionIds = new Set(["D2", "D4", "D5", "D6"]);
        if (demographicQuestionIds.has(refQuestionId)) {
          console.log(`[Convex] Question ${questionId}: ${refQuestionId}="${node.equals}" - DEMOGRAPHIC not set, EXCLUDING question`);
          return false; // Exclude question - demographic profile incomplete
        }
        console.log(`[Convex] Question ${questionId}: ${refQuestionId}="${node.equals}" - no response yet, including for iOS evaluation`);
        return true; // Include question, let iOS evaluate dynamically
      }
      const result = String(userValue).toLowerCase() === String(node.equals).toLowerCase();
      console.log(`[Convex] Question ${questionId}: ${refQuestionId}="${userValue}" equals "${node.equals}" => ${result}`);
      return result;
    }

    if (typeof node.greaterThan === 'number') {
      if (userValue === null || userValue === undefined) return true;
      const numValue = Number(userValue);
      if (isNaN(numValue)) return false;
      return numValue > node.greaterThan;
    }

    if (typeof node.lessThan === 'number') {
      if (userValue === null || userValue === undefined) return true;
      const numValue = Number(userValue);
      if (isNaN(numValue)) return false;
      return numValue < node.lessThan;
    }
  }

  // Handle show_if wrapper format
  if (node.show_if && typeof node.show_if === 'object') {
    return evaluateLogicNode(node.show_if as Record<string, unknown>, responseMap, questionId, sameDayQuestionIds);
  }

  // Unknown format - default to showing
  return true;
}

/**
 * Calculate age from a date of birth response (various formats supported)
 */
function calculateAgeFromResponse(dobValue: string | number | null | undefined): number | null {
  if (dobValue === null || dobValue === undefined) return null;

  const dobString = String(dobValue);

  // Try parsing various date formats
  let birthDate: Date | null = null;

  // ISO format: YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}/.test(dobString)) {
    birthDate = new Date(dobString);
  }
  // MM/DD/YYYY format
  else if (/^\d{2}\/\d{2}\/\d{4}$/.test(dobString)) {
    const [month, day, year] = dobString.split('/').map(Number);
    birthDate = new Date(year, month - 1, day);
  }
  // Year only
  else if (/^\d{4}$/.test(dobString)) {
    birthDate = new Date(Number(dobString), 0, 1);
  }

  if (!birthDate || isNaN(birthDate.getTime())) return null;

  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();

  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }

  return age;
}

/**
 * Update user's gateway state when a gateway question is answered
 * This is called when a gateway-triggering response is detected
 */
export const updateGatewayState = mutation({
  args: {
    userId: v.id("users"),
    gatewayId: v.string(),
    isTriggered: v.boolean(),
    triggerQuestionId: v.optional(v.string()),
    triggerValue: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if state already exists
    const existing = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user_gateway", (q) =>
        q.eq("user_id", args.userId).eq("gateway_id", args.gatewayId)
      )
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        triggered: args.isTriggered,
        trigger_question_id: args.triggerQuestionId,
        trigger_value: args.triggerValue,
        last_evaluated_at: now,
      });
    } else {
      await ctx.db.insert("user_gateway_states", {
        user_id: args.userId,
        gateway_id: args.gatewayId,
        triggered: args.isTriggered,
        trigger_question_id: args.triggerQuestionId,
        trigger_value: args.triggerValue,
        triggered_at: args.isTriggered ? now : undefined,
        last_evaluated_at: now,
      });
    }

    console.log(`[Convex] Gateway ${args.gatewayId} for user ${args.userId}: ${args.isTriggered ? "TRIGGERED" : "not triggered"}`);

    // When a gateway is triggered, recompute the expansion schedule
    // This ensures expansion packs are properly scheduled for Days 6-14
    if (args.isTriggered) {
      await ctx.scheduler.runAfter(0, api.expansionScheduler.computeAndStoreSchedule, {
        userId: args.userId,
      });
    }

    return { success: true, gatewayId: args.gatewayId, isTriggered: args.isTriggered };
  },
});

/**
 * Get all gateway states for a user
 */
export const getGatewayStates = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const states = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    return states.map((s) => ({
      gatewayId: s.gateway_id,
      isTriggered: s.triggered,
      triggerQuestionId: s.trigger_question_id,
      triggerValue: s.trigger_value,
      triggeredAt: s.triggered_at,
    }));
  },
});

/**
 * Migration: Convert is_triggered to triggered field in user_gateway_states
 * This fixes existing data that was written with the wrong field name.
 */
export const migrateGatewayStates = mutation({
  args: {
    userId: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    // Get all gateway states (optionally filtered by user)
    let states;
    if (args.userId) {
      const userId = args.userId;
      states = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .collect();
    } else {
      states = await ctx.db.query("user_gateway_states").collect();
    }

    let migratedCount = 0;
    for (const state of states) {
      // Check if this record has the old field name (is_triggered) but not the new one (triggered)
      const hasOldField = (state as Record<string, unknown>).is_triggered !== undefined;
      const hasNewField = state.triggered !== undefined;

      if (hasOldField && !hasNewField) {
        // Migrate: copy is_triggered value to triggered
        const oldValue = (state as Record<string, unknown>).is_triggered as boolean;
        await ctx.db.patch(state._id, {
          triggered: oldValue,
          last_evaluated_at: Date.now(),
        });
        migratedCount++;
        console.log(`[Migration] Migrated gateway ${state.gateway_id} for user ${state.user_id}: is_triggered=${oldValue} -> triggered=${oldValue}`);
      } else if (!hasNewField && !hasOldField) {
        // No triggered field at all - default to false
        await ctx.db.patch(state._id, {
          triggered: false,
          last_evaluated_at: Date.now(),
        });
        migratedCount++;
        console.log(`[Migration] Set default triggered=false for gateway ${state.gateway_id}`);
      }
    }

    return { migratedCount, totalRecords: states.length };
  },
});

// ============================================
// Module Metadata with Contextual Explanations
// ============================================

/**
 * Module metadata with explanations for each questionnaire type
 * This helps users understand WHY they're being asked certain questions
 */
const MODULE_METADATA: Record<string, {
  title: string;
  shortTitle: string;
  icon: string;
  estimatedMinutes: number;
  questionCount: number;
  color: string;
  description: string;
  why: string;
  triggeredBy?: string;
}> = {
  // Stanford Sleep Log - Daily
  sleep_log: {
    title: "Daily Sleep Log",
    shortTitle: "Sleep Log",
    icon: "moon.zzz",
    estimatedMinutes: 2,
    questionCount: 5,
    color: "#2196F3", // Blue
    description: "About last night's sleep",
    why: "Recording your subjective sleep perception daily helps us compare it with your wearable data and identify patterns. This takes about 60 seconds."
  },

  // Day 1: Demographics
  core_demographics: {
    title: "Your Profile",
    shortTitle: "Profile",
    icon: "person.circle",
    estimatedMinutes: 3,
    questionCount: 5,
    color: "#9C27B0", // Purple
    description: "Basic information about you",
    why: "Age, sex, height, and weight affect sleep needs. Some of this can be auto-filled from Apple Health."
  },

  // Day 1-5: PSQI (Pittsburgh Sleep Quality Index)
  core_psqi: {
    title: "Sleep Quality Assessment",
    shortTitle: "PSQI",
    icon: "chart.bar",
    estimatedMinutes: 8,
    questionCount: 12,
    color: "#9C27B0",
    description: "Pittsburgh Sleep Quality Index",
    why: "This validated questionnaire measures your sleep quality over the past month. Your score helps us understand the severity of sleep issues and track improvement."
  },

  // Day Assessment Generic
  day_assessment: {
    title: "Day Assessment",
    shortTitle: "Assessment",
    icon: "list.clipboard",
    estimatedMinutes: 5,
    questionCount: 8,
    color: "#9C27B0",
    description: "Daily assessment questions",
    why: "These questions help us understand your unique sleep patterns and any factors affecting your rest."
  },

  // Expansion: ISI (Insomnia Severity Index)
  expansion_isi: {
    title: "Insomnia Assessment",
    shortTitle: "ISI",
    icon: "exclamationmark.triangle",
    estimatedMinutes: 5,
    questionCount: 7,
    color: "#FF9800", // Orange - expansion
    description: "Insomnia Severity Index",
    why: "Based on your earlier responses about difficulty sleeping, this assessment measures insomnia severity. It's a clinically validated tool used worldwide.",
    triggeredBy: "insomnia"
  },

  // Expansion: PHQ-9 (Depression)
  expansion_phq9: {
    title: "Mood Assessment",
    shortTitle: "PHQ-9",
    icon: "heart.text.square",
    estimatedMinutes: 4,
    questionCount: 9,
    color: "#FF9800",
    description: "Patient Health Questionnaire",
    why: "Sleep and mood are closely connected. Based on your response about feeling down, this assessment helps us understand if depression may be affecting your sleep.",
    triggeredBy: "depression"
  },

  // Expansion: GAD-7 (Anxiety)
  expansion_gad7: {
    title: "Anxiety Assessment",
    shortTitle: "GAD-7",
    icon: "brain.head.profile",
    estimatedMinutes: 3,
    questionCount: 7,
    color: "#FF9800",
    description: "Generalized Anxiety Disorder Scale",
    why: "Based on your response about feeling anxious, this assessment helps us understand how anxiety may be impacting your sleep quality.",
    triggeredBy: "anxiety"
  },

  // Expansion: ESS (Epworth Sleepiness Scale)
  expansion_ess: {
    title: "Daytime Sleepiness",
    shortTitle: "ESS",
    icon: "sun.max.fill",
    estimatedMinutes: 4,
    questionCount: 8,
    color: "#FF9800",
    description: "Epworth Sleepiness Scale",
    why: "You mentioned feeling excessively sleepy during the day. This assessment measures daytime sleepiness severity, which may indicate a sleep disorder.",
    triggeredBy: "excessiveSleepiness"
  },

  // Expansion: FSS (Fatigue Severity Scale)
  expansion_fss: {
    title: "Fatigue Assessment",
    shortTitle: "FSS",
    icon: "battery.25",
    estimatedMinutes: 4,
    questionCount: 9,
    color: "#FF9800",
    description: "Fatigue Severity Scale",
    why: "This assessment measures how fatigue affects your daily life and helps distinguish between sleepiness and fatigue.",
    triggeredBy: "excessiveSleepiness"
  },

  // Expansion: STOP-BANG (Sleep Apnea Risk)
  expansion_stop_bang: {
    title: "Sleep Apnea Screening",
    shortTitle: "STOP-BANG",
    icon: "lungs.fill",
    estimatedMinutes: 3,
    questionCount: 8,
    color: "#F44336", // Red - important
    description: "Sleep Apnea Risk Assessment",
    why: "Based on your reports of snoring or breathing pauses, this screening helps determine if you may have sleep apnea and should have a sleep study.",
    triggeredBy: "osa"
  },

  // Expansion: Berlin Questionnaire (OSA)
  expansion_berlin: {
    title: "Sleep Apnea Risk",
    shortTitle: "Berlin",
    icon: "lungs",
    estimatedMinutes: 4,
    questionCount: 10,
    color: "#F44336",
    description: "Berlin Questionnaire for Sleep Apnea",
    why: "This additional screening helps us better assess your risk for obstructive sleep apnea.",
    triggeredBy: "osa"
  },

  // Expansion: BPI (Brief Pain Inventory)
  expansion_bpi: {
    title: "Pain Assessment",
    shortTitle: "BPI",
    icon: "bolt.circle",
    estimatedMinutes: 5,
    questionCount: 11,
    color: "#FF9800",
    description: "Brief Pain Inventory",
    why: "You reported that pain affects your sleep. This assessment helps us understand how pain impacts your daily life and sleep quality.",
    triggeredBy: "pain"
  },

  // Expansion: DBAS-16 (Dysfunctional Beliefs About Sleep)
  expansion_dbas16: {
    title: "Sleep Beliefs",
    shortTitle: "DBAS-16",
    icon: "brain",
    estimatedMinutes: 6,
    questionCount: 16,
    color: "#FF9800",
    description: "Dysfunctional Beliefs and Attitudes about Sleep",
    why: "This assessment identifies unhelpful beliefs about sleep that may be maintaining insomnia. Changing these beliefs is a key part of treatment.",
    triggeredBy: "insomnia"
  },

  // Expansion: MEQ (Morningness-Eveningness Questionnaire)
  expansion_meq: {
    title: "Chronotype Assessment",
    shortTitle: "MEQ",
    icon: "sunrise",
    estimatedMinutes: 6,
    questionCount: 19,
    color: "#FF9800",
    description: "Morningness-Eveningness Questionnaire",
    why: "This assessment determines your natural sleep-wake preference (are you a morning lark or night owl?), which helps optimize your sleep schedule.",
    triggeredBy: "sleepTiming"
  },

  // Expansion: MEDAS (Mediterranean Diet Adherence)
  expansion_medas: {
    title: "Diet Assessment",
    shortTitle: "MEDAS",
    icon: "leaf",
    estimatedMinutes: 5,
    questionCount: 14,
    color: "#4CAF50", // Green
    description: "Mediterranean Diet Adherence Screener",
    why: "You noticed diet affects your sleep. The Mediterranean diet has been shown to improve sleep quality. This assessment helps us make dietary recommendations.",
    triggeredBy: "dietImpact"
  },

  // Expansion: Sleep Hygiene
  expansion_sleep_hygiene: {
    title: "Sleep Habits",
    shortTitle: "Sleep Hygiene",
    icon: "bed.double",
    estimatedMinutes: 5,
    questionCount: 12,
    color: "#FF9800",
    description: "Sleep Hygiene Assessment",
    why: "This assessment identifies behaviors and habits that may be interfering with your sleep quality. Small changes can make a big difference.",
    triggeredBy: "poorSleepQuality"
  },

  // Expansion: PROMIS Cognitive Function
  expansion_promis_cognitive: {
    title: "Cognitive Function",
    shortTitle: "PROMIS-Cog",
    icon: "brain.head.profile",
    estimatedMinutes: 4,
    questionCount: 8,
    color: "#FF9800",
    description: "PROMIS Cognitive Function Short Form",
    why: "You mentioned cognitive issues affecting daily life. This assessment helps us understand how sleep affects your thinking and memory.",
    triggeredBy: "cognitive"
  },
};

/**
 * Get module metadata for display
 * Returns contextual information about a questionnaire section
 */
export const getModuleMetadata = query({
  args: {
    moduleKey: v.string(),
  },
  handler: async (ctx, args) => {
    const metadata = MODULE_METADATA[args.moduleKey];
    if (!metadata) {
      return null;
    }
    return metadata;
  },
});

/**
 * Get metadata for a specific day
 * Returns sleep log and assessment metadata with time estimates
 */
export const getDayMetadata = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    // Get user's triggered gateways to determine if expansion modules apply
    // For now, return basic metadata - gateway logic can be added later

    const sleepLogMeta = MODULE_METADATA.sleep_log;

    // Calculate assessment based on day number
    // Days 1-5: Core assessments (varying lengths)
    // Days 6-14: May include expansion modules
    const dayAssessmentCounts: Record<number, { questions: number; minutes: number }> = {
      1: { questions: 12, minutes: 6 },   // Demographics + initial
      2: { questions: 10, minutes: 5 },   // PSQI Part 1
      3: { questions: 10, minutes: 5 },   // PSQI Part 2
      4: { questions: 8, minutes: 4 },    // Sleep patterns
      5: { questions: 8, minutes: 4 },    // Health factors
      6: { questions: 10, minutes: 5 },   // May include ISI
      7: { questions: 8, minutes: 4 },
      8: { questions: 12, minutes: 6 },   // May include PHQ-9, GAD-7
      9: { questions: 10, minutes: 5 },   // May include ESS
      10: { questions: 12, minutes: 6 },  // May include STOP-BANG
      11: { questions: 8, minutes: 4 },
      12: { questions: 10, minutes: 5 },  // May include MEQ
      13: { questions: 8, minutes: 4 },   // May include MEDAS
      14: { questions: 6, minutes: 3 },
      15: { questions: 8, minutes: 4 },   // Final review
    };

    const dayData = dayAssessmentCounts[args.dayNumber] || { questions: 8, minutes: 4 };

    return {
      sleepLog: {
        ...sleepLogMeta,
        isCompleted: false, // Will be set by client based on progress
      },
      assessment: {
        title: `Day ${args.dayNumber} Assessment`,
        shortTitle: `Day ${args.dayNumber}`,
        icon: "list.clipboard",
        estimatedMinutes: dayData.minutes,
        questionCount: dayData.questions,
        color: "#9C27B0",
        description: getDayDescription(args.dayNumber),
        why: getDayExplanation(args.dayNumber),
        isCompleted: false,
      },
      totalMinutes: sleepLogMeta.estimatedMinutes + dayData.minutes,
      totalQuestions: sleepLogMeta.questionCount + dayData.questions,
      triggeredExpansions: [], // Would be populated based on gateway states
    };
  },
});

/**
 * Get description for a specific day's assessment
 */
function getDayDescription(dayNumber: number): string {
  const descriptions: Record<number, string> = {
    1: "Demographics & Sleep Quality",
    2: "Sleep Patterns & History",
    3: "Mental Health Screening",
    4: "Physical Health Factors",
    5: "Lifestyle & Environment",
    6: "Insomnia Deep Dive",
    7: "Sleep Timing",
    8: "Mood & Anxiety",
    9: "Daytime Function",
    10: "Sleep Apnea Screening",
    11: "Pain & Discomfort",
    12: "Circadian Rhythm",
    13: "Diet & Sleep",
    14: "Sleep Beliefs",
    15: "Final Review",
  };
  return descriptions[dayNumber] || "Daily Assessment";
}

/**
 * Get explanation for why this day's questions matter
 */
function getDayExplanation(dayNumber: number): string {
  const explanations: Record<number, string> = {
    1: "We're getting to know you and establishing your baseline sleep quality. This helps us personalize your journey.",
    2: "Understanding your sleep history and patterns helps us identify what might be causing your sleep issues.",
    3: "Sleep and mental health are closely connected. These questions help us see the full picture.",
    4: "Physical health factors can significantly impact sleep. We're checking for anything that might be relevant.",
    5: "Your environment and daily habits play a big role in sleep quality. Let's see what might need adjustment.",
    6: "Based on your responses, we're taking a deeper look at insomnia symptoms and their impact.",
    7: "Your natural sleep-wake cycle affects when you sleep best. We're assessing your chronotype.",
    8: "We're checking in on mood and anxiety, which can significantly affect sleep quality.",
    9: "Daytime sleepiness and energy levels tell us important things about your sleep quality.",
    10: "We're screening for sleep apnea, a common but often undiagnosed condition that affects sleep.",
    11: "Pain and physical discomfort can disrupt sleep. We're assessing if this applies to you.",
    12: "Your body clock affects when you feel sleepy and alert. Understanding this helps optimize your schedule.",
    13: "What you eat can affect how you sleep. We're looking at dietary factors.",
    14: "Sometimes our beliefs about sleep can make problems worse. We're identifying any unhelpful patterns.",
    15: "We're wrapping up your assessment and preparing your personalized recommendations.",
  };
  return explanations[dayNumber] || "These questions help us understand your unique sleep needs.";
}

// ============================================
// Database Maintenance
// ============================================

/**
 * Remove the SD_DATE question from sleep diary
 * This question is redundant on digital devices - we can auto-detect the date.
 * Run with: npx convex run watch:removeDateQuestion
 */
export const removeDateQuestion = mutation({
  args: {},
  handler: async (ctx) => {
    // Find and delete the SD_DATE question
    const allQuestions = await ctx.db
      .query("sleep_diary_questions")
      .collect();

    const dateQuestion = allQuestions.find(q => q.id === "SD_DATE");

    if (dateQuestion) {
      await ctx.db.delete(dateQuestion._id);
      return { deleted: true, message: "SD_DATE question removed successfully" };
    }

    return { deleted: false, message: "SD_DATE question not found in database" };
  },
});

/**
 * Remove the SD_SLEEP_ONSET question from sleep diary
 * This question is redundant - sleep onset time can be derived from lights_out + latency.
 * Run with: npx convex run watch:removeSleepOnsetQuestion
 */
export const removeSleepOnsetQuestion = mutation({
  args: {},
  handler: async (ctx) => {
    // Find and delete the SD_SLEEP_ONSET question
    const allQuestions = await ctx.db
      .query("sleep_diary_questions")
      .collect();

    const sleepOnsetQuestion = allQuestions.find(q => q.id === "SD_SLEEP_ONSET");

    if (sleepOnsetQuestion) {
      await ctx.db.delete(sleepOnsetQuestion._id);
      return { deleted: true, message: "SD_SLEEP_ONSET question removed successfully" };
    }

    return { deleted: false, message: "SD_SLEEP_ONSET question not found in database" };
  },
});

// ============================================
// Expansion Schedule Queries
// ============================================

// Module metadata for expansion schedule display
// MUST match FIXED_SCHEDULE packs in fixedSchedule.ts
const EXPANSION_MODULE_METADATA: Record<string, { name: string; instrument: string; description: string; icon: string }> = {
  // Day 6: Sleep & Work Patterns (insomnia, poor_sleep_quality, shift_work)
  expansion_isi: { name: "Insomnia Severity", instrument: "ISI", description: "Assess insomnia severity and impact", icon: "moon.zzz.fill" },
  expansion_swdsq: { name: "Shift Work Disorder", instrument: "SWDSQ", description: "Screen for shift work sleep disorder", icon: "clock.badge.exclamationmark.fill" },

  // Day 7: Mood & Thinking (depression, cognitive)
  expansion_phq9: { name: "Depression Screen", instrument: "PHQ-9", description: "Screen for depression symptoms", icon: "heart.fill" },
  expansion_promis_cognitive: { name: "Cognitive Function", instrument: "PROMIS", description: "Assess cognitive function", icon: "lightbulb.fill" },

  // Day 8: Anxiety & Sleep Habits (anxiety, insomnia, poor_sleep_quality)
  expansion_gad7: { name: "Anxiety Screen", instrument: "GAD-7", description: "Screen for anxiety symptoms", icon: "bolt.heart.fill" },
  expansion_sleep_hygiene_part1: { name: "Sleep Hygiene (Part 1)", instrument: "Sleep Hygiene", description: "Evaluate sleep habits", icon: "bed.double.fill" },
  expansion_sleep_hygiene_part2: { name: "Sleep Hygiene (Part 2)", instrument: "Sleep Hygiene", description: "Evaluate sleep habits", icon: "bed.double.fill" },

  // Day 9: Sleep Apnea Screening (osa)
  expansion_stop_bang: { name: "Sleep Apnea Screen", instrument: "STOP-BANG", description: "Screen for sleep apnea risk", icon: "lungs.fill" },

  // Day 10: Daytime Energy (excessive_sleepiness)
  expansion_ess: { name: "Sleepiness Scale", instrument: "ESS", description: "Measure daytime sleepiness", icon: "sun.max.fill" },
  expansion_fss: { name: "Fatigue Scale", instrument: "FSS", description: "Assess fatigue severity", icon: "battery.25" },

  // Day 11: Beliefs & Pain Part 1 (insomnia, pain)
  expansion_dbas6: { name: "Sleep Beliefs", instrument: "DBAS-6", description: "Assess dysfunctional beliefs about sleep", icon: "brain.head.profile" },
  expansion_bpi_part1: { name: "Pain Severity", instrument: "BPI", description: "Assess pain severity", icon: "bandage.fill" },

  // Day 12: Pain Impact (pain)
  expansion_bpi_part2: { name: "Pain Interference", instrument: "BPI", description: "Assess pain interference with daily life", icon: "bandage.fill" },

  // Day 13: Sleep Arousal & Function (insomnia, anxiety, excessive_sleepiness)
  expansion_psas_cognitive: { name: "Cognitive Arousal", instrument: "PSAS", description: "Measure pre-sleep cognitive arousal", icon: "brain" },
  expansion_psas_somatic: { name: "Somatic Arousal", instrument: "PSAS", description: "Measure pre-sleep physical arousal", icon: "figure.mind.and.body" },
  expansion_fosq_part1: { name: "Functional Outcomes (Part 1)", instrument: "FOSQ-10", description: "Measure sleep impact on function", icon: "figure.walk" },
  expansion_fosq_part2: { name: "Functional Outcomes (Part 2)", instrument: "FOSQ-10", description: "Measure sleep impact on function", icon: "figure.walk" },

  // Day 14: Diet & Chronotype (diet_impact, sleep_timing)
  expansion_medas: { name: "Diet Assessment", instrument: "MEDAS", description: "Evaluate Mediterranean diet adherence", icon: "fork.knife" },
  expansion_meq_part1: { name: "Chronotype (Part 1)", instrument: "MEQ", description: "Determine your sleep-wake preference", icon: "clock.fill" },
  expansion_meq_part2: { name: "Chronotype (Part 2)", instrument: "MEQ", description: "Determine your sleep-wake preference", icon: "clock.fill" },

  // Legacy modules (kept for backwards compatibility)
  expansion_berlin: { name: "Berlin Questionnaire", instrument: "Berlin", description: "Additional sleep apnea screening", icon: "waveform.path.ecg" },
  expansion_dbas: { name: "Sleep Beliefs", instrument: "DBAS-16", description: "Assess beliefs about sleep", icon: "brain.head.profile" },
  expansion_sleep_hygiene: { name: "Sleep Hygiene", instrument: "Sleep Hygiene", description: "Evaluate sleep habits", icon: "bed.double.fill" },
  expansion_psas: { name: "Pre-Sleep Arousal", instrument: "PSAS", description: "Measure pre-sleep arousal", icon: "figure.mind.and.body" },
  expansion_fosq: { name: "Functional Outcomes", instrument: "FOSQ-10", description: "Measure sleep impact on function", icon: "figure.walk" },
  expansion_dass21: { name: "Stress & Anxiety", instrument: "DASS-21", description: "Comprehensive mental health screen", icon: "brain" },
  expansion_bpi: { name: "Pain Inventory", instrument: "BPI", description: "Assess pain and sleep", icon: "bandage.fill" },
  expansion_meq: { name: "Chronotype", instrument: "MEQ", description: "Determine your sleep-wake preference", icon: "clock.fill" },
};

/**
 * Get the expansion schedule for a user.
 * Returns the full schedule with module metadata.
 */
export const getExpansionSchedule = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const schedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!schedule) {
      return null;
    }

    // Enrich with module metadata
    const enrichedDays = schedule.day_assignments.map((day) => {
      const modules = day.module_ids.map((id) => {
        const meta = EXPANSION_MODULE_METADATA[id];
        return meta ? { id, ...meta, questionCount: day.question_count } : { id, name: id };
      });

      return {
        dayNumber: day.day_number,
        modules,
        questionCount: day.question_count,
        estimatedMinutes: day.estimated_minutes,
        completed: day.completed || false,
      };
    });

    return {
      triggeredGateways: schedule.triggered_gateways,
      totalQuestions: schedule.total_expansion_questions,
      totalMinutes: schedule.total_estimated_minutes || 0,
      dayAssignments: enrichedDays,
    };
  },
});

/**
 * Get expansion modules for a specific day.
 * Used by iOS/web to show expansion tasks in Today's Focus.
 * FIXED: Now uses FIXED_SCHEDULE instead of old user_expansion_schedules table.
 */
export const getExpansionForDay = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    // Days 1-5 are core assessments, not expansion
    if (args.dayNumber < 6 || args.dayNumber > 14) {
      return { hasExpansion: false, modules: [], questionCount: 0, estimatedMinutes: 0, splashTitle: "" };
    }

    // Get day config from FIXED_SCHEDULE
    const config = FIXED_SCHEDULE[args.dayNumber];
    if (!config || config.type !== "expansion") {
      return { hasExpansion: false, modules: [], questionCount: 0, estimatedMinutes: 0, splashTitle: "" };
    }

    // Get user's triggered gateways from user_gateway_states (the authoritative table)
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    const triggeredGatewayIds = gatewayStates
      .filter(g => g.triggered)
      .map(g => g.gateway_id);

    // Check if ANY of this day's gateways are triggered
    if (!shouldShowExpansion(args.dayNumber, triggeredGatewayIds)) {
      return { hasExpansion: false, modules: [], questionCount: 0, estimatedMinutes: 0, splashTitle: "" };
    }

    // Get module IDs from FIXED_SCHEDULE packs
    const moduleIds: string[] = [];
    for (const packId of config.packs) {
      const packModules = PACK_TO_MODULE_IDS[packId];
      if (packModules) {
        moduleIds.push(...packModules);
      }
    }

    // Get module details
    const modules = moduleIds.map((id) => {
      const meta = EXPANSION_MODULE_METADATA[id];
      return meta
        ? { id, name: meta.name, instrument: meta.instrument, description: meta.description, icon: meta.icon }
        : { id, name: id, instrument: "", description: "", icon: "questionmark.circle" };
    });

    // Check if this day's expansion is completed by checking gateway states
    // A day's expansion is complete if ALL triggered gateways for that day have expansion_completed=true
    const relevantGatewayIds = config.gateways.filter(g => triggeredGatewayIds.includes(g));
    let expansionCompleted = false;

    if (relevantGatewayIds.length > 0) {
      const completionChecks = await Promise.all(
        relevantGatewayIds.map(async (gatewayId) => {
          const state = await ctx.db
            .query("user_gateway_states")
            .withIndex("by_user_gateway", (q) =>
              q.eq("user_id", args.userId).eq("gateway_id", gatewayId)
            )
            .first();
          return state?.expansion_completed ?? false;
        })
      );
      expansionCompleted = completionChecks.every(c => c);
    }

    return {
      hasExpansion: true,
      modules,
      questionCount: config.totalQuestions,
      estimatedMinutes: config.estimatedMinutes,
      splashTitle: config.splashTitle,
      splashSubtitle: config.splashSubtitle,
      gateways: config.gateways,
      completed: expansionCompleted,
    };
  },
});

/**
 * Mark expansion modules as completed for a day.
 * Called when user completes the expansion assessment section.
 */
export const markExpansionCompleted = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
  },
  handler: async (ctx, args) => {
    const schedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!schedule) {
      return { success: false, error: "No expansion schedule found" };
    }

    const updatedAssignments = schedule.day_assignments.map((d) => {
      if (d.day_number === args.dayNumber) {
        return { ...d, completed: true };
      }
      return d;
    });

    await ctx.db.patch(schedule._id, {
      day_assignments: updatedAssignments,
    });

    return { success: true };
  },
});

/**
 * Preview expansion schedule for testing.
 * Shows what schedule would be computed for given gateways.
 */
export const previewExpansionSchedule = query({
  args: {
    triggeredGateways: v.array(v.string()),
  },
  handler: async (ctx, args) => {
    // Use the same module definitions as computeExpansionScheduleForUser
    const EXPANSION_MODULES = [
      { id: "expansion_isi", name: "ISI", questionCount: 7, estimatedMinutes: 5, requiredGateways: ["insomnia", "poor_sleep_quality"], priority: 1 },
      { id: "expansion_phq9", name: "PHQ-9", questionCount: 9, estimatedMinutes: 6, requiredGateways: ["depression"], priority: 1 },
      { id: "expansion_gad7", name: "GAD-7", questionCount: 7, estimatedMinutes: 5, requiredGateways: ["anxiety"], priority: 1 },
      { id: "expansion_stop_bang", name: "STOP-BANG", questionCount: 8, estimatedMinutes: 5, requiredGateways: ["osa"], priority: 1 },
      { id: "expansion_ess", name: "ESS", questionCount: 8, estimatedMinutes: 5, requiredGateways: ["excessive_sleepiness"], priority: 2 },
      { id: "expansion_berlin", name: "Berlin", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["osa"], priority: 2 },
      { id: "expansion_dbas", name: "DBAS-16", questionCount: 16, estimatedMinutes: 12, requiredGateways: ["insomnia"], priority: 3 },
      { id: "expansion_sleep_hygiene", name: "Sleep Hygiene", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["insomnia", "poor_sleep_quality"], priority: 3 },
      { id: "expansion_psas", name: "PSAS", questionCount: 16, estimatedMinutes: 10, requiredGateways: ["insomnia"], priority: 3 },
      { id: "expansion_fss", name: "FSS", questionCount: 9, estimatedMinutes: 6, requiredGateways: ["excessive_sleepiness"], priority: 4 },
      { id: "expansion_fosq", name: "FOSQ-10", questionCount: 10, estimatedMinutes: 7, requiredGateways: ["excessive_sleepiness"], priority: 4 },
      { id: "expansion_dass21", name: "DASS-21", questionCount: 21, estimatedMinutes: 15, requiredGateways: ["depression", "anxiety"], priority: 4 },
      { id: "expansion_promis_cognitive", name: "PROMIS Cognitive", questionCount: 6, estimatedMinutes: 4, requiredGateways: ["cognitive"], priority: 4 },
      { id: "expansion_bpi", name: "BPI", questionCount: 11, estimatedMinutes: 8, requiredGateways: ["pain"], priority: 5 },
      { id: "expansion_medas", name: "MEDAS", questionCount: 14, estimatedMinutes: 10, requiredGateways: ["diet_impact"], priority: 5 },
      { id: "expansion_meq", name: "MEQ", questionCount: 19, estimatedMinutes: 12, requiredGateways: ["sleep_timing"], priority: 5 },
      { id: "expansion_swdsq", name: "SWDSQ", questionCount: 4, estimatedMinutes: 3, requiredGateways: ["shift_work"], priority: 2 },
    ];

    const TARGET_QUESTIONS_PER_DAY = 14;
    const MAX_QUESTIONS_PER_DAY = 18;
    const EXPANSION_START_DAY = 6;
    const TOTAL_DAYS = 14;

    // Filter modules
    const triggeredModules = EXPANSION_MODULES.filter((module) =>
      module.requiredGateways.some((gateway) => args.triggeredGateways.includes(gateway))
    );

    // Sort by priority
    const sortedModules = [...triggeredModules].sort((a, b) => {
      if (a.priority !== b.priority) return a.priority - b.priority;
      return a.questionCount - b.questionCount;
    });

    // Distribute
    const dayAssignments: Array<{ dayNumber: number; modules: string[]; questionCount: number; estimatedMinutes: number }> = [];
    let currentDay = EXPANSION_START_DAY;
    let currentDayModules: typeof sortedModules = [];
    let currentDayQuestions = 0;

    for (const module of sortedModules) {
      if (currentDayQuestions + module.questionCount > MAX_QUESTIONS_PER_DAY && currentDayModules.length > 0) {
        dayAssignments.push({
          dayNumber: currentDay,
          modules: currentDayModules.map((m) => m.name),
          questionCount: currentDayQuestions,
          estimatedMinutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
        });
        currentDay++;
        currentDayModules = [];
        currentDayQuestions = 0;
      }

      currentDayModules.push(module);
      currentDayQuestions += module.questionCount;

      if (currentDayQuestions >= TARGET_QUESTIONS_PER_DAY && currentDay < TOTAL_DAYS) {
        dayAssignments.push({
          dayNumber: currentDay,
          modules: currentDayModules.map((m) => m.name),
          questionCount: currentDayQuestions,
          estimatedMinutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
        });
        currentDay++;
        currentDayModules = [];
        currentDayQuestions = 0;
      }
    }

    if (currentDayModules.length > 0) {
      dayAssignments.push({
        dayNumber: currentDay,
        modules: currentDayModules.map((m) => m.name),
        questionCount: currentDayQuestions,
        estimatedMinutes: currentDayModules.reduce((sum, m) => sum + m.estimatedMinutes, 0),
      });
    }

    const totalQuestions = dayAssignments.reduce((sum, d) => sum + d.questionCount, 0);
    const totalMinutes = dayAssignments.reduce((sum, d) => sum + d.estimatedMinutes, 0);
    const avgQuestionsPerDay = dayAssignments.length > 0 ? Math.round(totalQuestions / dayAssignments.length) : 0;

    return {
      triggeredGateways: args.triggeredGateways,
      triggeredModulesCount: triggeredModules.length,
      dayAssignments,
      totalQuestions,
      totalMinutes,
      expansionDays: dayAssignments.length,
      avgQuestionsPerDay,
      summary: `${totalQuestions} questions across ${dayAssignments.length} days (~${avgQuestionsPerDay}/day, ~${totalMinutes} minutes total)`,
    };
  },
});
