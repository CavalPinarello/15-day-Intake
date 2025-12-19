/**
 * Badge Seeding Script
 * Seeds the badge_definitions table with all gamification badges
 *
 * Run with: npx convex run seedBadges:seedAll
 */

import { internalMutation, mutation } from "./_generated/server";
import { v } from "convex/values";

// ============================================
// Badge Definitions
// ============================================

const BADGE_DEFINITIONS = [
  // ============================================
  // Journey Badges (Progress-based)
  // ============================================
  {
    badge_id: "first_step",
    name: "First Step",
    description: "Complete your first day of the sleep journey",
    category: "journey",
    icon: "🌱",
    unlock_type: "day_complete",
    unlock_threshold: 1,
    xp_reward: 50,
    rarity: "common",
    order_index: 1,
  },
  {
    badge_id: "week_one",
    name: "Week One",
    description: "Complete the first 7 days of your journey",
    category: "journey",
    icon: "📅",
    unlock_type: "day_complete",
    unlock_threshold: 7,
    xp_reward: 200,
    rarity: "uncommon",
    order_index: 2,
  },
  {
    badge_id: "halfway_hero",
    name: "Halfway Hero",
    description: "Complete Day 8 - you're halfway there!",
    category: "journey",
    icon: "🏃",
    unlock_type: "day_complete",
    unlock_threshold: 8,
    xp_reward: 150,
    rarity: "uncommon",
    order_index: 3,
  },
  {
    badge_id: "gateway_explorer",
    name: "Gateway Explorer",
    description: "Trigger your first expansion pack assessment",
    category: "journey",
    icon: "🔮",
    unlock_type: "gateway_triggered",
    unlock_threshold: 1,
    xp_reward: 100,
    rarity: "uncommon",
    order_index: 4,
  },
  {
    badge_id: "deep_diver",
    name: "Deep Diver",
    description: "Complete an expansion pack questionnaire",
    category: "journey",
    icon: "🤿",
    unlock_type: "expansion_complete",
    unlock_threshold: 1,
    xp_reward: 150,
    rarity: "uncommon",
    order_index: 5,
  },
  {
    badge_id: "journey_master",
    name: "Journey Master",
    description: "Complete all 15 days of the sleep journey",
    category: "journey",
    icon: "🏆",
    unlock_type: "day_complete",
    unlock_threshold: 15,
    xp_reward: 500,
    rarity: "legendary",
    order_index: 6,
  },

  // ============================================
  // Streak Badges
  // ============================================
  {
    badge_id: "streak_3",
    name: "Getting Started",
    description: "Maintain a 3-day streak",
    category: "streak",
    icon: "🔥",
    unlock_type: "streak_count",
    unlock_threshold: 3,
    xp_reward: 50,
    rarity: "common",
    order_index: 10,
  },
  {
    badge_id: "streak_7",
    name: "Week Warrior",
    description: "Maintain a 7-day streak",
    category: "streak",
    icon: "💪",
    unlock_type: "streak_count",
    unlock_threshold: 7,
    xp_reward: 150,
    rarity: "uncommon",
    order_index: 11,
  },
  {
    badge_id: "streak_15",
    name: "Dedicated Sleeper",
    description: "Maintain a 15-day streak",
    category: "streak",
    icon: "⭐",
    unlock_type: "streak_count",
    unlock_threshold: 15,
    xp_reward: 300,
    rarity: "rare",
    order_index: 12,
  },
  {
    badge_id: "streak_30",
    name: "Sleep Champion",
    description: "Maintain a 30-day streak",
    category: "streak",
    icon: "👑",
    unlock_type: "streak_count",
    unlock_threshold: 30,
    xp_reward: 500,
    rarity: "epic",
    order_index: 13,
  },
  {
    badge_id: "streak_60",
    name: "Habit Master",
    description: "Maintain a 60-day streak",
    category: "streak",
    icon: "🌟",
    unlock_type: "streak_count",
    unlock_threshold: 60,
    xp_reward: 1000,
    rarity: "legendary",
    order_index: 14,
  },

  // ============================================
  // Quality/Behavior Badges
  // ============================================
  {
    badge_id: "early_bird",
    name: "Early Bird",
    description: "Complete sleep log before 9 AM for 5 days",
    category: "quality",
    icon: "🐦",
    unlock_type: "behavior",
    unlock_threshold: 5,
    unlock_condition_json: JSON.stringify({
      action: "sleep_log_complete",
      time_before: "09:00",
    }),
    xp_reward: 100,
    rarity: "uncommon",
    order_index: 20,
  },
  {
    badge_id: "night_owl",
    name: "Night Owl",
    description: "Complete assessment after 8 PM for 5 days",
    category: "quality",
    icon: "🦉",
    unlock_type: "behavior",
    unlock_threshold: 5,
    unlock_condition_json: JSON.stringify({
      action: "assessment_complete",
      time_after: "20:00",
    }),
    xp_reward: 100,
    rarity: "uncommon",
    order_index: 21,
  },
  {
    badge_id: "consistency_king",
    name: "Consistency King",
    description: "Same bedtime (±30 min) for 7 consecutive days",
    category: "quality",
    icon: "📊",
    unlock_type: "behavior",
    unlock_threshold: 7,
    unlock_condition_json: JSON.stringify({
      metric: "bedtime_variance",
      max_variance_minutes: 30,
    }),
    xp_reward: 200,
    rarity: "rare",
    order_index: 22,
  },
  {
    badge_id: "mindful_logger",
    name: "Mindful Logger",
    description: "Add notes to 10 sleep logs",
    category: "quality",
    icon: "📝",
    unlock_type: "behavior",
    unlock_threshold: 10,
    unlock_condition_json: JSON.stringify({
      action: "note_added",
    }),
    xp_reward: 100,
    rarity: "uncommon",
    order_index: 23,
  },
  {
    badge_id: "data_champion",
    name: "Data Champion",
    description: "Connect Apple Health and complete all logs",
    category: "quality",
    icon: "📱",
    unlock_type: "behavior",
    unlock_threshold: 1,
    unlock_condition_json: JSON.stringify({
      requirements: ["apple_health_connected", "all_logs_complete"],
    }),
    xp_reward: 200,
    rarity: "rare",
    order_index: 24,
  },
  {
    badge_id: "perfect_week",
    name: "Perfect Week",
    description: "Complete all 14 tasks in a week (7 logs + 7 assessments)",
    category: "quality",
    icon: "💯",
    unlock_type: "behavior",
    unlock_threshold: 14,
    unlock_condition_json: JSON.stringify({
      action: "weekly_tasks_complete",
    }),
    xp_reward: 300,
    rarity: "rare",
    order_index: 25,
  },

  // ============================================
  // Clinical Milestone Badges
  // ============================================
  {
    badge_id: "insomnia_informed",
    name: "Insomnia Informed",
    description: "Complete the ISI (Insomnia Severity Index) assessment",
    category: "clinical",
    icon: "🧠",
    unlock_type: "assessment_complete",
    unlock_threshold: 1,
    unlock_condition_json: JSON.stringify({
      assessment: "ISI",
    }),
    xp_reward: 100,
    rarity: "uncommon",
    order_index: 30,
  },
  {
    badge_id: "mood_monitor",
    name: "Mood Monitor",
    description: "Complete both PHQ-9 and GAD-7 assessments",
    category: "clinical",
    icon: "💭",
    unlock_type: "assessment_complete",
    unlock_threshold: 2,
    unlock_condition_json: JSON.stringify({
      assessments: ["PHQ-9", "GAD-7"],
    }),
    xp_reward: 150,
    rarity: "uncommon",
    order_index: 31,
  },
  {
    badge_id: "apnea_aware",
    name: "Apnea Aware",
    description: "Complete the STOP-BANG screening",
    category: "clinical",
    icon: "😤",
    unlock_type: "assessment_complete",
    unlock_threshold: 1,
    unlock_condition_json: JSON.stringify({
      assessment: "STOP-BANG",
    }),
    xp_reward: 100,
    rarity: "uncommon",
    order_index: 32,
  },
  {
    badge_id: "sleepy_scout",
    name: "Sleepy Scout",
    description: "Complete the ESS (Epworth Sleepiness Scale)",
    category: "clinical",
    icon: "😴",
    unlock_type: "assessment_complete",
    unlock_threshold: 1,
    unlock_condition_json: JSON.stringify({
      assessment: "ESS",
    }),
    xp_reward: 100,
    rarity: "uncommon",
    order_index: 33,
  },
  {
    badge_id: "full_picture",
    name: "Full Picture",
    description: "Complete all 5 clinical assessments",
    category: "clinical",
    icon: "🔬",
    unlock_type: "assessment_complete",
    unlock_threshold: 5,
    unlock_condition_json: JSON.stringify({
      assessments: ["ISI", "PHQ-9", "GAD-7", "STOP-BANG", "ESS"],
    }),
    xp_reward: 300,
    rarity: "epic",
    order_index: 34,
  },
];

// ============================================
// Seed Function
// ============================================

export const seedAll = mutation({
  args: {},
  handler: async (ctx) => {
    // Check if badges already seeded
    const existingBadges = await ctx.db.query("badge_definitions").collect();

    if (existingBadges.length > 0) {
      console.log(`Found ${existingBadges.length} existing badges. Clearing and re-seeding...`);
      // Delete existing badges
      for (const badge of existingBadges) {
        await ctx.db.delete(badge._id);
      }
    }

    // Insert all badge definitions
    let insertedCount = 0;
    for (const badge of BADGE_DEFINITIONS) {
      await ctx.db.insert("badge_definitions", {
        badge_id: badge.badge_id,
        name: badge.name,
        description: badge.description,
        category: badge.category,
        icon: badge.icon,
        unlock_type: badge.unlock_type,
        unlock_threshold: badge.unlock_threshold,
        unlock_condition_json: badge.unlock_condition_json,
        xp_reward: badge.xp_reward,
        rarity: badge.rarity,
        order_index: badge.order_index,
        is_active: true,
      });
      insertedCount++;
    }

    console.log(`Successfully seeded ${insertedCount} badge definitions`);
    return { success: true, count: insertedCount };
  },
});

/**
 * Get all badge definitions (for client display)
 */
export const getAllBadges = mutation({
  args: {},
  handler: async (ctx) => {
    const badges = await ctx.db
      .query("badge_definitions")
      .filter((q) => q.eq(q.field("is_active"), true))
      .collect();

    return badges.sort((a, b) => a.order_index - b.order_index);
  },
});
