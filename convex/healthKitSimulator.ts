import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

/**
 * HealthKit Data Simulator
 *
 * Generates realistic sleep and health data for testing:
 * - Sleep stages (deep, light, REM, awake)
 * - Heart rate data (resting, average, HRV)
 * - Activity data (steps, exercise, calories)
 * - Various sleep disorder patterns
 */

// ============================================
// Sleep Pattern Profiles
// ============================================

interface SleepPattern {
  name: string;
  description: string;
  // Sleep timing
  bedtimeRange: [string, string]; // HH:MM format
  wakeTimeRange: [string, string];
  // Sleep architecture
  deepSleepPercent: [number, number]; // Min/max percentage
  lightSleepPercent: [number, number];
  remSleepPercent: [number, number];
  wakingsPercent: [number, number]; // Time awake during night
  // Variability
  latencyRange: [number, number]; // Minutes to fall asleep
  efficiencyRange: [number, number]; // 0-100 percentage
  // Day-to-day variability (in minutes)
  bedtimeVariability: number;
  wakeTimeVariability: number;
  // Heart rate
  restingHRRange: [number, number];
  sleepHRRange: [number, number];
  hrvRange: [number, number];
}

const SLEEP_PATTERNS: Record<string, SleepPattern> = {
  healthy: {
    name: "Healthy Sleeper",
    description: "Normal sleep architecture with good efficiency",
    bedtimeRange: ["22:30", "23:30"],
    wakeTimeRange: ["06:30", "07:30"],
    deepSleepPercent: [18, 25],
    lightSleepPercent: [45, 55],
    remSleepPercent: [20, 25],
    wakingsPercent: [2, 5],
    latencyRange: [5, 15],
    efficiencyRange: [88, 95],
    bedtimeVariability: 20,
    wakeTimeVariability: 15,
    restingHRRange: [55, 65],
    sleepHRRange: [50, 58],
    hrvRange: [40, 60],
  },
  insomnia_onset: {
    name: "Sleep Onset Insomnia",
    description: "Difficulty falling asleep",
    bedtimeRange: ["22:00", "23:00"],
    wakeTimeRange: ["06:00", "07:00"],
    deepSleepPercent: [12, 18],
    lightSleepPercent: [50, 60],
    remSleepPercent: [18, 22],
    wakingsPercent: [5, 10],
    latencyRange: [45, 120],
    efficiencyRange: [65, 78],
    bedtimeVariability: 60,
    wakeTimeVariability: 30,
    restingHRRange: [65, 75],
    sleepHRRange: [58, 68],
    hrvRange: [25, 40],
  },
  insomnia_maintenance: {
    name: "Sleep Maintenance Insomnia",
    description: "Frequent nighttime awakenings",
    bedtimeRange: ["22:00", "23:00"],
    wakeTimeRange: ["06:00", "07:00"],
    deepSleepPercent: [10, 15],
    lightSleepPercent: [55, 65],
    remSleepPercent: [15, 20],
    wakingsPercent: [15, 25],
    latencyRange: [10, 25],
    efficiencyRange: [60, 75],
    bedtimeVariability: 30,
    wakeTimeVariability: 45,
    restingHRRange: [62, 72],
    sleepHRRange: [55, 65],
    hrvRange: [28, 42],
  },
  early_awakening: {
    name: "Early Morning Awakening",
    description: "Wakes too early, can't return to sleep",
    bedtimeRange: ["22:00", "23:00"],
    wakeTimeRange: ["04:00", "05:30"],
    deepSleepPercent: [15, 20],
    lightSleepPercent: [50, 58],
    remSleepPercent: [15, 18],
    wakingsPercent: [8, 12],
    latencyRange: [10, 20],
    efficiencyRange: [70, 82],
    bedtimeVariability: 25,
    wakeTimeVariability: 20,
    restingHRRange: [60, 70],
    sleepHRRange: [52, 62],
    hrvRange: [30, 45],
  },
  sleep_apnea: {
    name: "Sleep Apnea Pattern",
    description: "Fragmented sleep with oxygen desaturation",
    bedtimeRange: ["22:30", "23:30"],
    wakeTimeRange: ["06:30", "07:30"],
    deepSleepPercent: [5, 12],
    lightSleepPercent: [60, 70],
    remSleepPercent: [10, 15],
    wakingsPercent: [20, 35],
    latencyRange: [5, 15],
    efficiencyRange: [55, 70],
    bedtimeVariability: 25,
    wakeTimeVariability: 30,
    restingHRRange: [70, 85],
    sleepHRRange: [60, 75],
    hrvRange: [18, 32],
  },
  delayed_phase: {
    name: "Delayed Sleep Phase",
    description: "Natural night owl chronotype",
    bedtimeRange: ["01:30", "03:00"],
    wakeTimeRange: ["09:30", "11:00"],
    deepSleepPercent: [18, 24],
    lightSleepPercent: [48, 55],
    remSleepPercent: [20, 25],
    wakingsPercent: [3, 6],
    latencyRange: [8, 20],
    efficiencyRange: [85, 92],
    bedtimeVariability: 45,
    wakeTimeVariability: 60,
    restingHRRange: [58, 68],
    sleepHRRange: [52, 60],
    hrvRange: [38, 55],
  },
  advanced_phase: {
    name: "Advanced Sleep Phase",
    description: "Early bird, sleeps and wakes early",
    bedtimeRange: ["19:30", "21:00"],
    wakeTimeRange: ["04:00", "05:30"],
    deepSleepPercent: [18, 24],
    lightSleepPercent: [48, 55],
    remSleepPercent: [20, 25],
    wakingsPercent: [3, 6],
    latencyRange: [5, 15],
    efficiencyRange: [85, 92],
    bedtimeVariability: 20,
    wakeTimeVariability: 25,
    restingHRRange: [55, 65],
    sleepHRRange: [50, 58],
    hrvRange: [42, 58],
  },
  irregular: {
    name: "Irregular Sleep-Wake",
    description: "Highly variable schedule",
    bedtimeRange: ["22:00", "03:00"],
    wakeTimeRange: ["06:00", "11:00"],
    deepSleepPercent: [10, 18],
    lightSleepPercent: [50, 60],
    remSleepPercent: [15, 22],
    wakingsPercent: [8, 15],
    latencyRange: [15, 45],
    efficiencyRange: [70, 82],
    bedtimeVariability: 120,
    wakeTimeVariability: 90,
    restingHRRange: [62, 75],
    sleepHRRange: [55, 68],
    hrvRange: [28, 45],
  },
  short_sleeper: {
    name: "Short Sleeper",
    description: "Naturally needs less sleep",
    bedtimeRange: ["00:00", "01:00"],
    wakeTimeRange: ["05:00", "06:00"],
    deepSleepPercent: [22, 28],
    lightSleepPercent: [42, 50],
    remSleepPercent: [22, 28],
    wakingsPercent: [2, 4],
    latencyRange: [3, 10],
    efficiencyRange: [92, 97],
    bedtimeVariability: 20,
    wakeTimeVariability: 15,
    restingHRRange: [52, 62],
    sleepHRRange: [48, 55],
    hrvRange: [45, 65],
  },
  compensator: {
    name: "Social Jet Lag / Compensator",
    description: "Different weekend vs weekday patterns",
    bedtimeRange: ["23:00", "00:00"],
    wakeTimeRange: ["06:00", "07:00"],
    deepSleepPercent: [15, 22],
    lightSleepPercent: [48, 55],
    remSleepPercent: [18, 24],
    wakingsPercent: [4, 8],
    latencyRange: [10, 25],
    efficiencyRange: [78, 88],
    bedtimeVariability: 90, // High because of weekend catch-up
    wakeTimeVariability: 120,
    restingHRRange: [58, 68],
    sleepHRRange: [52, 62],
    hrvRange: [35, 50],
  },
};

// ============================================
// Helper Functions
// ============================================

function randomInRange(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomFloat(min: number, max: number, decimals: number = 1): number {
  const value = Math.random() * (max - min) + min;
  return Number(value.toFixed(decimals));
}

function parseTime(timeStr: string): { hours: number; minutes: number } {
  const [h, m] = timeStr.split(":").map(Number);
  return { hours: h, minutes: m };
}

function randomTimeInRange(start: string, end: string, variabilityMinutes: number = 0): string {
  const startTime = parseTime(start);
  const endTime = parseTime(end);

  let startMinutes = startTime.hours * 60 + startTime.minutes;
  let endMinutes = endTime.hours * 60 + endTime.minutes;

  // Handle overnight ranges
  if (endMinutes < startMinutes) {
    endMinutes += 24 * 60;
  }

  // Add variability
  startMinutes -= variabilityMinutes / 2;
  endMinutes += variabilityMinutes / 2;

  const randomMinutes = randomInRange(Math.floor(startMinutes), Math.floor(endMinutes));
  const normalizedMinutes = ((randomMinutes % (24 * 60)) + 24 * 60) % (24 * 60);

  const hours = Math.floor(normalizedMinutes / 60);
  const minutes = normalizedMinutes % 60;

  return `${hours.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}`;
}

function generateSleepStages(
  totalSleepMinutes: number,
  pattern: SleepPattern,
  date: string,
  sleepStartTime: number
): Array<{
  startTime: number;
  endTime: number;
  stage: string;
  durationMins: number;
}> {
  const stages: Array<{
    startTime: number;
    endTime: number;
    stage: string;
    durationMins: number;
  }> = [];

  // Calculate durations
  const deepMins = Math.round(totalSleepMinutes * randomFloat(pattern.deepSleepPercent[0], pattern.deepSleepPercent[1]) / 100);
  const lightMins = Math.round(totalSleepMinutes * randomFloat(pattern.lightSleepPercent[0], pattern.lightSleepPercent[1]) / 100);
  const remMins = Math.round(totalSleepMinutes * randomFloat(pattern.remSleepPercent[0], pattern.remSleepPercent[1]) / 100);
  const awakeMins = totalSleepMinutes - deepMins - lightMins - remMins;

  // Create ~4-5 sleep cycles
  const cycleCount = randomInRange(4, 5);
  let currentTime = sleepStartTime;

  for (let cycle = 0; cycle < cycleCount; cycle++) {
    const cycleMultiplier = cycle < 2 ? 1.2 : 0.8; // More deep sleep early, more REM late
    const remMultiplier = cycle < 2 ? 0.6 : 1.4;

    // Light sleep transition
    const lightDuration = Math.round((lightMins / cycleCount) * 1.2);
    stages.push({
      startTime: currentTime,
      endTime: currentTime + lightDuration * 60 * 1000,
      stage: "light",
      durationMins: lightDuration,
    });
    currentTime += lightDuration * 60 * 1000;

    // Deep sleep (more in early cycles)
    if (cycle < 3) {
      const deepDuration = Math.round((deepMins / 3) * cycleMultiplier);
      stages.push({
        startTime: currentTime,
        endTime: currentTime + deepDuration * 60 * 1000,
        stage: "deep",
        durationMins: deepDuration,
      });
      currentTime += deepDuration * 60 * 1000;
    }

    // Light sleep again
    const light2Duration = Math.round((lightMins / cycleCount) * 0.8);
    stages.push({
      startTime: currentTime,
      endTime: currentTime + light2Duration * 60 * 1000,
      stage: "light",
      durationMins: light2Duration,
    });
    currentTime += light2Duration * 60 * 1000;

    // REM sleep (more in later cycles)
    const remDuration = Math.round((remMins / cycleCount) * remMultiplier);
    stages.push({
      startTime: currentTime,
      endTime: currentTime + remDuration * 60 * 1000,
      stage: "rem",
      durationMins: remDuration,
    });
    currentTime += remDuration * 60 * 1000;

    // Occasional waking
    if (Math.random() < 0.3) {
      const awakeDuration = Math.round(awakeMins / 4);
      stages.push({
        startTime: currentTime,
        endTime: currentTime + awakeDuration * 60 * 1000,
        stage: "awake",
        durationMins: awakeDuration,
      });
      currentTime += awakeDuration * 60 * 1000;
    }
  }

  return stages;
}

// ============================================
// Simulation Functions
// ============================================

/**
 * Generate a single night of sleep data
 */
export const generateSingleNight = mutation({
  args: {
    userId: v.id("users"),
    date: v.string(), // YYYY-MM-DD
    patternName: v.string(),
    isWeekend: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const { userId, date, patternName, isWeekend = false } = args;

    const pattern = SLEEP_PATTERNS[patternName];
    if (!pattern) {
      return { status: "fail", message: `Unknown pattern: ${patternName}` };
    }

    // Adjust for weekend if compensator
    const weekendAdjust = isWeekend && patternName === "compensator" ? 90 : 0;

    // Generate bedtime
    const bedtimeStr = randomTimeInRange(
      pattern.bedtimeRange[0],
      pattern.bedtimeRange[1],
      pattern.bedtimeVariability
    );

    // Adjust for weekend (later bedtime, later wake)
    const bedtimeTime = parseTime(bedtimeStr);
    let bedtimeMinutes = bedtimeTime.hours * 60 + bedtimeTime.minutes + weekendAdjust;
    if (bedtimeMinutes >= 24 * 60) bedtimeMinutes -= 24 * 60;

    // Generate wake time
    const wakeTimeStr = randomTimeInRange(
      pattern.wakeTimeRange[0],
      pattern.wakeTimeRange[1],
      pattern.wakeTimeVariability
    );
    const wakeTime = parseTime(wakeTimeStr);
    let wakeMinutes = wakeTime.hours * 60 + wakeTime.minutes + weekendAdjust;

    // Calculate time in bed
    let timeInBedMinutes = wakeMinutes - bedtimeMinutes;
    if (timeInBedMinutes < 0) timeInBedMinutes += 24 * 60;

    // Generate sleep latency
    const latency = randomInRange(pattern.latencyRange[0], pattern.latencyRange[1]);

    // Generate WASO (wake after sleep onset)
    const wasoPercent = randomFloat(pattern.wakingsPercent[0], pattern.wakingsPercent[1]);
    const wasoMinutes = Math.round((timeInBedMinutes - latency) * wasoPercent / 100);

    // Calculate total sleep
    const totalSleep = timeInBedMinutes - latency - wasoMinutes;
    const efficiency = Math.round((totalSleep / timeInBedMinutes) * 100);

    // Calculate sleep stages
    const deepPercent = randomFloat(pattern.deepSleepPercent[0], pattern.deepSleepPercent[1]);
    const lightPercent = randomFloat(pattern.lightSleepPercent[0], pattern.lightSleepPercent[1]);
    const remPercent = randomFloat(pattern.remSleepPercent[0], pattern.remSleepPercent[1]);

    const deepMins = Math.round(totalSleep * deepPercent / 100);
    const lightMins = Math.round(totalSleep * lightPercent / 100);
    const remMins = Math.round(totalSleep * remPercent / 100);

    // Generate awakenings count
    const awakenings = Math.round(wasoMinutes / randomInRange(5, 15));

    // Check for existing data
    const existing = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        total_sleep_mins: totalSleep,
        sleep_efficiency: efficiency,
        deep_sleep_mins: deepMins,
        light_sleep_mins: lightMins,
        rem_sleep_mins: remMins,
        awake_mins: wasoMinutes,
        sleep_latency_mins: latency,
        interruptions_count: awakenings,
        synced_at: Date.now(),
        primary_source: "HealthKit Simulator",
      });
    } else {
      await ctx.db.insert("user_sleep_data", {
        user_id: userId,
        date,
        total_sleep_mins: totalSleep,
        sleep_efficiency: efficiency,
        deep_sleep_mins: deepMins,
        light_sleep_mins: lightMins,
        rem_sleep_mins: remMins,
        awake_mins: wasoMinutes,
        sleep_latency_mins: latency,
        interruptions_count: awakenings,
        synced_at: Date.now(),
        primary_source: "HealthKit Simulator",
      });
    }

    // Generate heart rate data
    const restingHR = randomInRange(pattern.restingHRRange[0], pattern.restingHRRange[1]);
    const avgHR = randomInRange(pattern.sleepHRRange[0], pattern.sleepHRRange[1]);
    const hrv = randomInRange(pattern.hrvRange[0], pattern.hrvRange[1]);

    const existingHR = await ctx.db
      .query("user_heart_rate")
      .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
      .first();

    if (existingHR) {
      await ctx.db.patch(existingHR._id, {
        resting_hr: restingHR,
        avg_hr: avgHR,
        hrv_morning: hrv,
        hrv_avg: hrv,
        synced_at: Date.now(),
      });
    } else {
      await ctx.db.insert("user_heart_rate", {
        user_id: userId,
        date,
        resting_hr: restingHR,
        avg_hr: avgHR,
        hrv_morning: hrv,
        hrv_avg: hrv,
        synced_at: Date.now(),
      });
    }

    return {
      status: "success",
      date,
      pattern: patternName,
      data: {
        totalSleep,
        efficiency,
        latency,
        awakenings,
        deepMins,
        lightMins,
        remMins,
        wasoMinutes,
        restingHR,
        avgHR,
        hrv,
      },
    };
  },
});

/**
 * Generate multiple nights of sleep data
 */
export const generateMultipleNights = mutation({
  args: {
    userId: v.id("users"),
    startDate: v.string(), // YYYY-MM-DD
    nights: v.number(),
    patternName: v.string(),
    includeWeekendEffect: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const { userId, startDate, nights, patternName, includeWeekendEffect = true } = args;

    const pattern = SLEEP_PATTERNS[patternName];
    if (!pattern) {
      return { status: "fail", message: `Unknown pattern: ${patternName}` };
    }

    const results = [];
    const startDateObj = new Date(startDate);

    for (let i = 0; i < nights; i++) {
      const currentDate = new Date(startDateObj);
      currentDate.setDate(currentDate.getDate() + i);
      const dateStr = currentDate.toISOString().split("T")[0];
      const dayOfWeek = currentDate.getDay();
      const isWeekend = includeWeekendEffect && (dayOfWeek === 0 || dayOfWeek === 6);

      // Generate sleep data inline (can't call mutations from mutations)
      const weekendAdjust = isWeekend && patternName === "compensator" ? 90 : 0;

      const bedtimeStr = randomTimeInRange(
        pattern.bedtimeRange[0],
        pattern.bedtimeRange[1],
        pattern.bedtimeVariability
      );
      const bedtimeTime = parseTime(bedtimeStr);
      let bedtimeMinutes = bedtimeTime.hours * 60 + bedtimeTime.minutes + weekendAdjust;
      if (bedtimeMinutes >= 24 * 60) bedtimeMinutes -= 24 * 60;

      const wakeTimeStr = randomTimeInRange(
        pattern.wakeTimeRange[0],
        pattern.wakeTimeRange[1],
        pattern.wakeTimeVariability
      );
      const wakeTime = parseTime(wakeTimeStr);
      let wakeMinutes = wakeTime.hours * 60 + wakeTime.minutes + weekendAdjust;

      let timeInBedMinutes = wakeMinutes - bedtimeMinutes;
      if (timeInBedMinutes < 0) timeInBedMinutes += 24 * 60;

      const latency = randomInRange(pattern.latencyRange[0], pattern.latencyRange[1]);
      const wasoPercent = randomFloat(pattern.wakingsPercent[0], pattern.wakingsPercent[1]);
      const wasoMinutes = Math.round((timeInBedMinutes - latency) * wasoPercent / 100);

      const totalSleep = timeInBedMinutes - latency - wasoMinutes;
      const efficiency = Math.round((totalSleep / timeInBedMinutes) * 100);

      const deepPercent = randomFloat(pattern.deepSleepPercent[0], pattern.deepSleepPercent[1]);
      const lightPercent = randomFloat(pattern.lightSleepPercent[0], pattern.lightSleepPercent[1]);
      const remPercent = randomFloat(pattern.remSleepPercent[0], pattern.remSleepPercent[1]);

      const deepMins = Math.round(totalSleep * deepPercent / 100);
      const lightMins = Math.round(totalSleep * lightPercent / 100);
      const remMins = Math.round(totalSleep * remPercent / 100);
      const awakenings = Math.round(wasoMinutes / randomInRange(5, 15));

      // Insert sleep data
      await ctx.db.insert("user_sleep_data", {
        user_id: userId,
        date: dateStr,
        total_sleep_mins: totalSleep,
        sleep_efficiency: efficiency,
        deep_sleep_mins: deepMins,
        light_sleep_mins: lightMins,
        rem_sleep_mins: remMins,
        awake_mins: wasoMinutes,
        sleep_latency_mins: latency,
        interruptions_count: awakenings,
        synced_at: Date.now(),
        primary_source: "HealthKit Simulator",
      });

      // Insert heart rate
      const restingHR = randomInRange(pattern.restingHRRange[0], pattern.restingHRRange[1]);
      const avgHR = randomInRange(pattern.sleepHRRange[0], pattern.sleepHRRange[1]);
      const hrv = randomInRange(pattern.hrvRange[0], pattern.hrvRange[1]);

      await ctx.db.insert("user_heart_rate", {
        user_id: userId,
        date: dateStr,
        resting_hr: restingHR,
        avg_hr: avgHR,
        hrv_morning: hrv,
        hrv_avg: hrv,
        synced_at: Date.now(),
      });

      results.push({
        date: dateStr,
        isWeekend,
        totalSleep,
        efficiency,
      });
    }

    return {
      status: "success",
      pattern: patternName,
      nightsGenerated: nights,
      results,
    };
  },
});

/**
 * Generate activity data
 */
export const generateActivityData = mutation({
  args: {
    userId: v.id("users"),
    startDate: v.string(),
    days: v.number(),
    activityLevel: v.string(), // "low", "moderate", "high"
  },
  handler: async (ctx, args) => {
    const { userId, startDate, days, activityLevel } = args;

    const activityProfiles: Record<string, { steps: [number, number]; active: [number, number]; exercise: [number, number] }> = {
      low: { steps: [2000, 5000], active: [10, 30], exercise: [0, 15] },
      moderate: { steps: [6000, 10000], active: [30, 60], exercise: [15, 45] },
      high: { steps: [10000, 18000], active: [60, 120], exercise: [45, 90] },
    };

    const profile = activityProfiles[activityLevel] || activityProfiles.moderate;
    const startDateObj = new Date(startDate);

    for (let i = 0; i < days; i++) {
      const currentDate = new Date(startDateObj);
      currentDate.setDate(currentDate.getDate() + i);
      const dateStr = currentDate.toISOString().split("T")[0];
      const dayOfWeek = currentDate.getDay();

      // Slightly reduced activity on weekends
      const weekendMultiplier = (dayOfWeek === 0 || dayOfWeek === 6) ? 0.8 : 1;

      const steps = Math.round(randomInRange(profile.steps[0], profile.steps[1]) * weekendMultiplier);
      const activeMins = Math.round(randomInRange(profile.active[0], profile.active[1]) * weekendMultiplier);
      const exerciseMins = Math.round(randomInRange(profile.exercise[0], profile.exercise[1]) * weekendMultiplier);
      const calories = Math.round(steps * 0.04 + exerciseMins * 8);

      await ctx.db.insert("user_activity", {
        user_id: userId,
        date: dateStr,
        steps,
        active_mins: activeMins,
        exercise_mins: exerciseMins,
        calories_burned: calories,
        synced_at: Date.now(),
      });
    }

    return {
      status: "success",
      daysGenerated: days,
      activityLevel,
    };
  },
});

/**
 * Get available sleep patterns
 */
export const getSleepPatterns = query({
  args: {},
  handler: async () => {
    return Object.entries(SLEEP_PATTERNS).map(([id, pattern]) => ({
      id,
      name: pattern.name,
      description: pattern.description,
      typicalEfficiency: pattern.efficiencyRange,
      typicalLatency: pattern.latencyRange,
    }));
  },
});

/**
 * Clear simulated data for a user
 */
export const clearSimulatedData = mutation({
  args: {
    userId: v.id("users"),
    dataTypes: v.optional(v.array(v.string())), // ["sleep", "heart_rate", "activity"]
  },
  handler: async (ctx, args) => {
    const { userId, dataTypes = ["sleep", "heart_rate", "activity"] } = args;

    let deletedCounts: Record<string, number> = {};

    if (dataTypes.includes("sleep")) {
      const sleepData = await ctx.db
        .query("user_sleep_data")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .filter((q) => q.eq(q.field("primary_source"), "HealthKit Simulator"))
        .collect();

      for (const d of sleepData) {
        await ctx.db.delete(d._id);
      }
      deletedCounts.sleep = sleepData.length;
    }

    if (dataTypes.includes("heart_rate")) {
      const hrData = await ctx.db
        .query("user_heart_rate")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .collect();

      for (const d of hrData) {
        await ctx.db.delete(d._id);
      }
      deletedCounts.heart_rate = hrData.length;
    }

    if (dataTypes.includes("activity")) {
      const activityData = await ctx.db
        .query("user_activity")
        .withIndex("by_user", (q) => q.eq("user_id", userId))
        .collect();

      for (const d of activityData) {
        await ctx.db.delete(d._id);
      }
      deletedCounts.activity = activityData.length;
    }

    return {
      status: "success",
      deleted: deletedCounts,
    };
  },
});
