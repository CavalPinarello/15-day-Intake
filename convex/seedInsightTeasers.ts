import { mutation } from "./_generated/server";

/**
 * Seed script for Progressive Insight Teasers
 *
 * Run with: npx convex run seedInsightTeasers:seedAll
 */

interface InsightTeaserData {
  teaser_id: string;
  unlock_day: number;
  unlock_data_points?: number;
  teaser_type: "countdown" | "discovery";
  title: string;
  locked_description: string;
  unlocked_description?: string;
  discovery_hints_json?: string;
  category: string;
  icon: string;
  color?: string;
  order_index: number;
}

// Progressive insight teasers that build anticipation during the 15-day journey
const INSIGHT_TEASERS: InsightTeaserData[] = [
  // === COUNTDOWN TEASERS (unlock on specific days) ===
  {
    teaser_id: "sleep_timing_pattern",
    unlock_day: 3,
    teaser_type: "countdown",
    title: "Sleep Timing Pattern",
    locked_description: "3 more nights to detect your natural rhythm",
    unlocked_description:
      "We've identified your natural sleep timing preferences",
    category: "timing",
    icon: "clock.fill",
    color: "#F59E0B", // Amber
    order_index: 1,
  },
  {
    teaser_id: "sleep_efficiency_trend",
    unlock_day: 5,
    teaser_type: "countdown",
    title: "Sleep Efficiency Trend",
    locked_description: "Your sleep efficiency analysis unlocks in 2 more days",
    unlocked_description: "Here's how efficiently you're sleeping",
    category: "efficiency",
    icon: "chart.line.uptrend.xyaxis",
    color: "#10B981", // Emerald
    order_index: 2,
  },
  {
    teaser_id: "weekly_pattern",
    unlock_day: 7,
    teaser_type: "countdown",
    title: "Weekly Sleep Pattern",
    locked_description: "7 days of data reveals your weekly cycle",
    unlocked_description: "Your sleep patterns across the week",
    category: "pattern",
    icon: "calendar",
    color: "#6366F1", // Indigo
    order_index: 3,
  },
  {
    teaser_id: "sleep_quality_factors",
    unlock_day: 10,
    teaser_type: "countdown",
    title: "Quality Influencers",
    locked_description: "We're learning what affects your sleep quality",
    unlocked_description: "Factors that most impact your sleep quality",
    category: "quality",
    icon: "star.fill",
    color: "#EC4899", // Pink
    order_index: 4,
  },
  {
    teaser_id: "chronotype_analysis",
    unlock_day: 12,
    teaser_type: "countdown",
    title: "Your Chronotype",
    locked_description: "Your natural sleep-wake preference is emerging",
    unlocked_description: "Your chronotype: morning lark, night owl, or in between",
    category: "timing",
    icon: "sun.and.horizon.fill",
    color: "#F97316", // Orange
    order_index: 5,
  },
  {
    teaser_id: "full_sleep_profile",
    unlock_day: 10,
    teaser_type: "countdown",
    title: "Complete Sleep Profile",
    locked_description: "Your complete sleep profile is almost ready",
    unlocked_description: "Your comprehensive sleep analysis is complete",
    category: "pattern",
    icon: "person.crop.circle.badge.checkmark",
    color: "#8B5CF6", // Violet
    order_index: 6,
  },

  // === DISCOVERY TEASERS (progressive hints based on data patterns) ===
  {
    teaser_id: "wake_pattern_discovery",
    unlock_day: 15, // Unlocks at end or via data points
    unlock_data_points: 5,
    teaser_type: "discovery",
    title: "Wake Pattern",
    locked_description: "Analyzing your wake times...",
    unlocked_description: "Your natural wake pattern revealed",
    discovery_hints_json: JSON.stringify([
      "We're gathering data on your wake times...",
      "We're noticing something about your wake times...",
      "An interesting pattern is forming in your mornings...",
      "Your wake pattern is almost clear!",
    ]),
    category: "timing",
    icon: "sunrise.fill",
    color: "#FBBF24", // Yellow
    order_index: 7,
  },
  {
    teaser_id: "bedtime_consistency",
    unlock_day: 15,
    unlock_data_points: 7,
    teaser_type: "discovery",
    title: "Bedtime Rhythm",
    locked_description: "Tracking your bedtime consistency...",
    unlocked_description: "Your bedtime consistency analysis",
    discovery_hints_json: JSON.stringify([
      "Tracking your bedtime patterns...",
      "Your bedtime habits are becoming clearer...",
      "We're seeing a rhythm in your bedtimes...",
      "Your bedtime pattern is ready!",
    ]),
    category: "timing",
    icon: "moon.fill",
    color: "#6366F1", // Indigo
    order_index: 8,
  },
  {
    teaser_id: "sleep_debt_tracker",
    unlock_day: 15,
    unlock_data_points: 10,
    teaser_type: "discovery",
    title: "Sleep Debt",
    locked_description: "Calculating your sleep debt...",
    unlocked_description: "Your accumulated sleep debt analysis",
    discovery_hints_json: JSON.stringify([
      "Tracking your sleep duration...",
      "Calculating your sleep needs...",
      "Your sleep debt picture is forming...",
      "Sleep debt analysis ready!",
    ]),
    category: "efficiency",
    icon: "hourglass.bottomhalf.filled",
    color: "#EF4444", // Red
    order_index: 9,
  },
  {
    teaser_id: "quality_correlation",
    unlock_day: 15,
    unlock_data_points: 8,
    teaser_type: "discovery",
    title: "Quality Insights",
    locked_description: "Finding patterns in your sleep quality...",
    unlocked_description: "What affects your sleep quality most",
    discovery_hints_json: JSON.stringify([
      "Analyzing your sleep quality ratings...",
      "We're finding patterns in your sleep quality...",
      "Quality correlations are emerging...",
      "Quality insights unlocked!",
    ]),
    category: "quality",
    icon: "sparkles",
    color: "#A855F7", // Purple
    order_index: 10,
  },
];

// Time window definitions for treatment tasks
const TIME_WINDOWS = [
  {
    window_id: "morning",
    name: "Morning",
    description: "5 AM - 12 PM",
    icon: "sun.max.fill",
    color: "#F59E0B", // Amber
    start_hour: 5,
    end_hour: 12,
    order_index: 1,
  },
  {
    window_id: "afternoon",
    name: "Afternoon",
    description: "12 PM - 5 PM",
    icon: "sun.haze.fill",
    color: "#F97316", // Orange
    start_hour: 12,
    end_hour: 17,
    order_index: 2,
  },
  {
    window_id: "evening",
    name: "Evening",
    description: "5 PM - 9 PM",
    icon: "sunset.fill",
    color: "#F472B6", // Coral/Pink
    start_hour: 17,
    end_hour: 21,
    order_index: 3,
  },
  {
    window_id: "night",
    name: "Night",
    description: "9 PM - 12 AM",
    icon: "moon.fill",
    color: "#6366F1", // Indigo
    start_hour: 21,
    end_hour: 24, // Midnight represented as 24
    order_index: 4,
  },
];

/**
 * Seed all insight teasers
 */
export const seedAll = mutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();

    // Clear existing teasers
    const existingTeasers = await ctx.db.query("insight_teasers").collect();
    for (const teaser of existingTeasers) {
      await ctx.db.delete(teaser._id);
    }

    // Clear existing time windows
    const existingWindows = await ctx.db.query("task_time_windows").collect();
    for (const window of existingWindows) {
      await ctx.db.delete(window._id);
    }

    // Insert insight teasers
    let teasersInserted = 0;
    for (const teaser of INSIGHT_TEASERS) {
      await ctx.db.insert("insight_teasers", {
        teaser_id: teaser.teaser_id,
        unlock_day: teaser.unlock_day,
        unlock_data_points: teaser.unlock_data_points,
        teaser_type: teaser.teaser_type,
        title: teaser.title,
        locked_description: teaser.locked_description,
        unlocked_description: teaser.unlocked_description,
        discovery_hints_json: teaser.discovery_hints_json,
        category: teaser.category,
        icon: teaser.icon,
        color: teaser.color,
        order_index: teaser.order_index,
        is_active: true,
        created_at: now,
      });
      teasersInserted++;
    }

    // Insert time windows
    let windowsInserted = 0;
    for (const window of TIME_WINDOWS) {
      await ctx.db.insert("task_time_windows", {
        window_id: window.window_id,
        name: window.name,
        description: window.description,
        icon: window.icon,
        color: window.color,
        start_hour: window.start_hour,
        end_hour: window.end_hour,
        order_index: window.order_index,
      });
      windowsInserted++;
    }

    console.log(
      `Seeded ${teasersInserted} insight teasers and ${windowsInserted} time windows`
    );

    return {
      teasersInserted,
      windowsInserted,
    };
  },
});

/**
 * Seed only insight teasers (without clearing)
 */
export const seedTeasersOnly = mutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();

    let inserted = 0;
    for (const teaser of INSIGHT_TEASERS) {
      // Check if already exists
      const existing = await ctx.db
        .query("insight_teasers")
        .withIndex("by_teaser_id", (q) => q.eq("teaser_id", teaser.teaser_id))
        .first();

      if (!existing) {
        await ctx.db.insert("insight_teasers", {
          teaser_id: teaser.teaser_id,
          unlock_day: teaser.unlock_day,
          unlock_data_points: teaser.unlock_data_points,
          teaser_type: teaser.teaser_type,
          title: teaser.title,
          locked_description: teaser.locked_description,
          unlocked_description: teaser.unlocked_description,
          discovery_hints_json: teaser.discovery_hints_json,
          category: teaser.category,
          icon: teaser.icon,
          color: teaser.color,
          order_index: teaser.order_index,
          is_active: true,
          created_at: now,
        });
        inserted++;
      }
    }

    return { inserted };
  },
});

/**
 * Seed only time windows (without clearing)
 */
export const seedTimeWindowsOnly = mutation({
  args: {},
  handler: async (ctx) => {
    let inserted = 0;
    for (const window of TIME_WINDOWS) {
      // Check if already exists
      const existing = await ctx.db
        .query("task_time_windows")
        .withIndex("by_window_id", (q) => q.eq("window_id", window.window_id))
        .first();

      if (!existing) {
        await ctx.db.insert("task_time_windows", {
          window_id: window.window_id,
          name: window.name,
          description: window.description,
          icon: window.icon,
          color: window.color,
          start_hour: window.start_hour,
          end_hour: window.end_hour,
          order_index: window.order_index,
        });
        inserted++;
      }
    }

    return { inserted };
  },
});
