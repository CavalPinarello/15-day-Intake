import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

/**
 * Mock Sleep Log Simulation System
 *
 * This module generates realistic mock questionnaire-based sleep log data
 * for testing perception vs. actual sleep time comparisons.
 *
 * IMPORTANT: All mock data is clearly marked with:
 * - is_mock: true
 * - mock_batch_id: unique identifier for the batch
 * - primary_source: "Questionnaire-Mock"
 *
 * Mock data represents PERCEIVED/SUBJECTIVE sleep data only.
 * It does NOT generate fake wearable data.
 */

// Sleep pattern definitions with realistic variability
const SLEEP_PATTERNS = {
  normal: {
    name: "Normal Sleeper",
    description: "Healthy sleep patterns with regular schedule",
    bedTimeRange: { min: 22, max: 23.5 }, // 10:00 PM - 11:30 PM
    wakeTimeRange: { min: 6, max: 7.5 }, // 6:00 AM - 7:30 AM
    sleepLatencyRange: { min: 5, max: 20 }, // minutes
    wakingsRange: { min: 0, max: 2 },
    qualityRange: { min: 7, max: 9 },
    efficiencyRange: { min: 85, max: 95 },
    perceptionBias: { min: -15, max: 15 }, // minutes off from actual
  },
  insomnia: {
    name: "Insomnia Pattern",
    description: "Difficulty falling/staying asleep, poor quality",
    bedTimeRange: { min: 22, max: 1 }, // 10:00 PM - 1:00 AM (can wrap to next day)
    wakeTimeRange: { min: 5, max: 8 }, // 5:00 AM - 8:00 AM
    sleepLatencyRange: { min: 30, max: 90 }, // long time to fall asleep
    wakingsRange: { min: 2, max: 5 },
    qualityRange: { min: 3, max: 5 },
    efficiencyRange: { min: 60, max: 75 },
    perceptionBias: { min: -60, max: 0 }, // tends to underestimate sleep
  },
  delayed_phase: {
    name: "Delayed Sleep Phase",
    description: "Late bedtime, late wake time (circadian shift)",
    bedTimeRange: { min: 2, max: 4 }, // 2:00 AM - 4:00 AM
    wakeTimeRange: { min: 10, max: 12 }, // 10:00 AM - 12:00 PM
    sleepLatencyRange: { min: 10, max: 30 },
    wakingsRange: { min: 0, max: 2 },
    qualityRange: { min: 6, max: 8 },
    efficiencyRange: { min: 80, max: 90 },
    perceptionBias: { min: -20, max: 20 },
  },
  irregular: {
    name: "Irregular Sleep",
    description: "Highly variable bedtime and wake times",
    bedTimeRange: { min: 21, max: 3 }, // Wide range
    wakeTimeRange: { min: 5, max: 11 }, // Wide range
    sleepLatencyRange: { min: 5, max: 60 },
    wakingsRange: { min: 0, max: 4 },
    qualityRange: { min: 2, max: 8 },
    efficiencyRange: { min: 50, max: 95 },
    perceptionBias: { min: -45, max: 45 },
  },
  short_sleeper: {
    name: "Short Sleeper",
    description: "Consistently less than 6 hours of sleep",
    bedTimeRange: { min: 0, max: 1 }, // 12:00 AM - 1:00 AM
    wakeTimeRange: { min: 5, max: 6 }, // 5:00 AM - 6:00 AM
    sleepLatencyRange: { min: 5, max: 15 },
    wakingsRange: { min: 0, max: 1 },
    qualityRange: { min: 6, max: 8 },
    efficiencyRange: { min: 85, max: 95 },
    perceptionBias: { min: -10, max: 30 }, // may overestimate
  },
} as const;

type PatternKey = keyof typeof SLEEP_PATTERNS;

// Helper functions
function randomInRange(min: number, max: number): number {
  return Math.random() * (max - min) + min;
}

function randomIntInRange(min: number, max: number): number {
  return Math.floor(randomInRange(min, max + 1));
}

function normalizedTime(hours: number): number {
  // Normalize hours that might wrap past midnight
  if (hours < 0) return hours + 24;
  if (hours >= 24) return hours - 24;
  return hours;
}

function hoursToTimeString(hours: number): string {
  const normalized = normalizedTime(hours);
  const h = Math.floor(normalized);
  const m = Math.round((normalized - h) * 60);
  return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}`;
}

function generateDateRange(days: number, endDate?: string): string[] {
  const dates: string[] = [];
  const end = endDate ? new Date(endDate) : new Date();

  for (let i = days - 1; i >= 0; i--) {
    const date = new Date(end);
    date.setDate(date.getDate() - i);
    dates.push(date.toISOString().split("T")[0]);
  }

  return dates;
}

function generateMockSleepNight(
  pattern: (typeof SLEEP_PATTERNS)[PatternKey],
  date: string,
  dayNumber: number
): {
  date: string;
  dayNumber: number;
  bedTime: string;
  wakeTime: string;
  sleepLatencyMins: number;
  wakingsCount: number;
  wakingsDurationMins: number;
  perceivedTotalSleepMins: number;
  qualityRating: number;
  sleepEfficiency: number;
  dayType: "workday" | "weekend" | "day_off";
  napsTaken: boolean;
  napCount: number;
  napTotalMins: number;
} {
  // Determine day type
  const dateObj = new Date(date);
  const dayOfWeek = dateObj.getDay();
  const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
  const dayType: "workday" | "weekend" | "day_off" = isWeekend ? "weekend" : "workday";

  // Generate sleep times with slight variation
  let bedTimeHours = randomInRange(pattern.bedTimeRange.min, pattern.bedTimeRange.max);
  let wakeTimeHours = randomInRange(pattern.wakeTimeRange.min, pattern.wakeTimeRange.max);

  // Add weekend shift (stay up later, wake up later)
  if (isWeekend) {
    bedTimeHours += randomInRange(0.5, 1.5);
    wakeTimeHours += randomInRange(0.5, 2);
  }

  const bedTime = hoursToTimeString(bedTimeHours);
  const wakeTime = hoursToTimeString(wakeTimeHours);

  // Calculate time in bed
  let timeInBedHours = wakeTimeHours - bedTimeHours;
  if (timeInBedHours < 0) timeInBedHours += 24; // Handle overnight

  const sleepLatencyMins = randomIntInRange(pattern.sleepLatencyRange.min, pattern.sleepLatencyRange.max);
  const wakingsCount = randomIntInRange(pattern.wakingsRange.min, pattern.wakingsRange.max);
  const wakingsDurationMins = wakingsCount * randomIntInRange(3, 15);

  // Calculate perceived total sleep time
  const timeInBedMins = timeInBedHours * 60;
  const actualSleepMins = Math.max(0, timeInBedMins - sleepLatencyMins - wakingsDurationMins);

  // Add perception bias
  const perceptionBias = randomInRange(pattern.perceptionBias.min, pattern.perceptionBias.max);
  const perceivedTotalSleepMins = Math.round(actualSleepMins + perceptionBias);

  const qualityRating = randomIntInRange(pattern.qualityRange.min, pattern.qualityRange.max);
  const sleepEfficiency = Math.round(randomInRange(pattern.efficiencyRange.min, pattern.efficiencyRange.max));

  // Generate nap data (more likely for insomnia/short sleeper patterns)
  const napProbability = pattern.name.includes("Insomnia") || pattern.name.includes("Short") ? 0.4 : 0.15;
  const napsTaken = Math.random() < napProbability;
  const napCount = napsTaken ? randomIntInRange(1, 2) : 0;
  const napTotalMins = napsTaken ? randomIntInRange(15, 60) * napCount : 0;

  return {
    date,
    dayNumber,
    bedTime,
    wakeTime,
    sleepLatencyMins,
    wakingsCount,
    wakingsDurationMins,
    perceivedTotalSleepMins,
    qualityRating,
    sleepEfficiency,
    dayType,
    napsTaken,
    napCount,
    napTotalMins,
  };
}

/**
 * Generate mock sleep log data for a user
 *
 * Creates realistic questionnaire-based sleep data that represents
 * the user's PERCEIVED/SUBJECTIVE sleep experience.
 */
export const generateMockSleepLogData = mutation({
  args: {
    userId: v.id("users"),
    days: v.optional(v.number()), // Default 14
    pattern: v.union(
      v.literal("normal"),
      v.literal("insomnia"),
      v.literal("delayed_phase"),
      v.literal("irregular"),
      v.literal("short_sleeper")
    ),
    endDate: v.optional(v.string()), // Default: today
  },
  handler: async (ctx, args) => {
    const { userId, days = 14, pattern, endDate } = args;

    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    const patternConfig = SLEEP_PATTERNS[pattern];
    const dates = generateDateRange(days, endDate);
    const batchId = `mock_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    let createdRecords = 0;
    const mockData: Array<{
      date: string;
      perceivedSleep: number;
      quality: number;
    }> = [];

    for (let i = 0; i < dates.length; i++) {
      const date = dates[i];
      const dayNumber = i + 1;

      // Generate sleep data
      const sleepNight = generateMockSleepNight(patternConfig, date, dayNumber);

      // Check if record already exists for this date
      const existing = await ctx.db
        .query("user_sleep_data")
        .withIndex("by_user_date", (q) => q.eq("user_id", userId).eq("date", date))
        .first();

      if (existing) {
        // Skip if real data exists and isn't mock
        if (!existing.is_mock) {
          continue;
        }
        // Delete existing mock data
        await ctx.db.delete(existing._id);
      }

      // Create the mock sleep data record
      await ctx.db.insert("user_sleep_data", {
        user_id: userId,
        date,
        day_number: dayNumber,

        // Time data
        in_bed_time: new Date(`${date}T${sleepNight.bedTime}:00`).getTime(),
        asleep_time: new Date(
          `${date}T${sleepNight.bedTime}:00`
        ).getTime() + sleepNight.sleepLatencyMins * 60 * 1000,
        wake_time: new Date(`${date}T${sleepNight.wakeTime}:00`).getTime(),

        // Core metrics
        total_sleep_mins: sleepNight.perceivedTotalSleepMins,
        sleep_efficiency: sleepNight.sleepEfficiency,
        sleep_latency_mins: sleepNight.sleepLatencyMins,
        interruptions_count: sleepNight.wakingsCount,
        awake_mins: sleepNight.wakingsDurationMins,

        // Subjective data
        subjective_quality: sleepNight.qualityRating,
        day_type: sleepNight.dayType,

        // Nap data
        naps_taken: sleepNight.napsTaken,
        nap_count: sleepNight.napCount,
        nap_total_mins: sleepNight.napTotalMins,

        // Source tracking - CLEARLY MARKED AS MOCK
        primary_source: "Questionnaire-Mock",
        source_bundle_id: "com.zoesleep.mock",
        is_mock: true,
        mock_batch_id: batchId,

        // Metadata
        synced_at: Date.now(),
      });

      createdRecords++;
      mockData.push({
        date,
        perceivedSleep: sleepNight.perceivedTotalSleepMins,
        quality: sleepNight.qualityRating,
      });
    }

    return {
      success: true,
      batchId,
      pattern: patternConfig.name,
      patternDescription: patternConfig.description,
      createdRecords,
      dateRange: {
        start: dates[0],
        end: dates[dates.length - 1],
      },
      mockData,
    };
  },
});

/**
 * Clear all mock data for a user
 */
export const clearMockData = mutation({
  args: {
    userId: v.id("users"),
    batchId: v.optional(v.string()), // If provided, only clear this batch
  },
  handler: async (ctx, args) => {
    const { userId, batchId } = args;

    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    // Find all mock data for this user
    const mockRecords = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .filter((q) => q.eq(q.field("is_mock"), true))
      .collect();

    // Filter by batch if specified
    const recordsToDelete = batchId
      ? mockRecords.filter((r) => r.mock_batch_id === batchId)
      : mockRecords;

    let deletedCount = 0;
    for (const record of recordsToDelete) {
      await ctx.db.delete(record._id);
      deletedCount++;
    }

    return {
      success: true,
      deletedCount,
      batchId: batchId || "all",
    };
  },
});

/**
 * Get mock data status for a user
 */
export const getMockDataStatus = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;

    const user = await ctx.db.get(userId);
    if (!user) {
      return null;
    }

    // Find all mock data for this user
    const mockRecords = await ctx.db
      .query("user_sleep_data")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .filter((q) => q.eq(q.field("is_mock"), true))
      .collect();

    if (mockRecords.length === 0) {
      return {
        hasMockData: false,
        mockRecordCount: 0,
        batches: [],
      };
    }

    // Group by batch
    const batchMap = new Map<
      string,
      {
        batchId: string;
        recordCount: number;
        dateRange: { start: string; end: string };
        pattern?: string;
      }
    >();

    for (const record of mockRecords) {
      const batchId = record.mock_batch_id || "unknown";

      if (!batchMap.has(batchId)) {
        batchMap.set(batchId, {
          batchId,
          recordCount: 0,
          dateRange: { start: record.date, end: record.date },
        });
      }

      const batch = batchMap.get(batchId)!;
      batch.recordCount++;

      if (record.date < batch.dateRange.start) {
        batch.dateRange.start = record.date;
      }
      if (record.date > batch.dateRange.end) {
        batch.dateRange.end = record.date;
      }
    }

    return {
      hasMockData: true,
      mockRecordCount: mockRecords.length,
      batches: Array.from(batchMap.values()),
    };
  },
});

/**
 * Get available mock patterns
 */
export const getAvailableMockPatterns = query({
  args: {},
  handler: async () => {
    return Object.entries(SLEEP_PATTERNS).map(([key, pattern]) => ({
      id: key,
      name: pattern.name,
      description: pattern.description,
    }));
  },
});

/**
 * Toggle visibility of mock data in dashboard views
 * This doesn't delete mock data, just hides/shows it
 */
export const setMockDataVisibility = mutation({
  args: {
    userId: v.id("users"),
    visible: v.boolean(),
  },
  handler: async (ctx, args) => {
    const { userId, visible } = args;

    const user = await ctx.db.get(userId);
    if (!user) {
      return { success: false, error: "User not found" };
    }

    // Store visibility preference on user record
    await ctx.db.patch(userId, {
      // @ts-ignore - dynamic field
      show_mock_data: visible,
    });

    return {
      success: true,
      showMockData: visible,
    };
  },
});
