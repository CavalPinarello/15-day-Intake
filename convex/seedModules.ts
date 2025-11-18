/**
 * Seed assessment modules and day mappings
 * Run with: npx convex run seedModules:seedAll
 */

import { internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

// Import module data
import modulesData from "../data/assessment_modules.json";

/**
 * Seed assessment modules
 */
export const seedAssessmentModules = internalMutation({
  args: {},
  returns: v.object({
    inserted: v.number(),
    errors: v.array(v.string())
  }),
  handler: async (ctx) => {
    const errors: string[] = [];
    let inserted = 0;

    for (const module of modulesData) {
      try {
        // Check if module already exists
        const existing = await ctx.db
          .query("assessment_modules")
          .withIndex("by_module_id", (query) =>
            query.eq("module_id", module.moduleId)
          )
          .first();

        if (existing) {
          // Update existing
          await ctx.db.patch(existing._id, {
            name: module.name,
            description: module.description,
            pillar: module.pillar,
            tier: module.tier,
            module_type: module.moduleType,
            estimated_minutes: module.estimatedMinutes
          });
        } else {
          // Insert new
          await ctx.db.insert("assessment_modules", {
            module_id: module.moduleId,
            name: module.name,
            description: module.description,
            pillar: module.pillar,
            tier: module.tier,
            module_type: module.moduleType,
            estimated_minutes: module.estimatedMinutes
          });
          inserted++;
        }
      } catch (error) {
        errors.push(`Error processing module ${module.moduleId}: ${error}`);
      }
    }

    return { inserted, errors };
  },
});

/**
 * Seed module-question mappings
 */
export const seedModuleQuestions = internalMutation({
  args: {},
  returns: v.object({
    inserted: v.number(),
    errors: v.array(v.string())
  }),
  handler: async (ctx) => {
    const errors: string[] = [];
    let inserted = 0;

    // Clear existing mappings first
    const existingMappings = await ctx.db.query("module_questions").collect();
    for (const mapping of existingMappings) {
      await ctx.db.delete(mapping._id);
    }

    for (const module of modulesData) {
      if (module.questionIds && Array.isArray(module.questionIds)) {
        for (let i = 0; i < module.questionIds.length; i++) {
          try {
            await ctx.db.insert("module_questions", {
              module_id: module.moduleId,
              question_id: module.questionIds[i],
              order_index: i
            });
            inserted++;
          } catch (error) {
            errors.push(
              `Error linking question ${module.questionIds[i]} to module ${module.moduleId}: ${error}`
            );
          }
        }
      }
    }

    return { inserted, errors };
  },
});

/**
 * Define 15-day intake plan
 * Each day has specific modules assigned
 */
const FIFTEEN_DAY_PLAN = [
  // Day 1: Demographics & Core Sleep
  {
    day: 1,
    modules: ["core_social", "core_metabolic", "core_sleep_quality"]
  },
  // Day 2: Sleep patterns & timing
  {
    day: 2,
    modules: [
      "core_sleep_quantity",
      "core_sleep_regularity",
      "core_sleep_timing"
    ]
  },
  // Day 3: Gateway questions
  {
    day: 3,
    modules: [
      "gateway_sleep_quality",
      "gateway_mental_health",
      "gateway_cognitive",
      "gateway_physical"
    ]
  },
  // Day 4: Physical & nutritional core
  {
    day: 4,
    modules: ["core_physical", "core_nutritional"]
  },
  // Day 5: First expansion based on gateways
  {
    day: 5,
    modules: ["expansion_sleep_quality"] // If insomnia gateway triggered
  },
  // Day 6: Sleep diary start
  {
    day: 6,
    modules: [] // Sleep diary questions (separate table)
  },
  // Day 7: Continue diary + mental health expansion
  {
    day: 7,
    modules: ["expansion_mental_health"] // If mental health gateway triggered
  },
  // Day 8: Continue diary
  {
    day: 8,
    modules: []
  },
  // Day 9: Continue diary + cognitive expansion
  {
    day: 9,
    modules: ["expansion_cognitive"] // If cognitive gateway triggered
  },
  // Day 10: Continue diary + physical expansion
  {
    day: 10,
    modules: ["expansion_physical"] // If physical gateway triggered
  },
  // Day 11: Continue diary
  {
    day: 11,
    modules: []
  },
  // Day 12: Continue diary + timing expansion
  {
    day: 12,
    modules: ["expansion_sleep_timing"] // If timing differences detected
  },
  // Day 13: Continue diary + nutritional expansion
  {
    day: 13,
    modules: ["expansion_nutritional"] // If diet impacts detected
  },
  // Day 14: Final diary + wrap-up
  {
    day: 14,
    modules: []
  },
  // Day 15: Review & generate report
  {
    day: 15,
    modules: [] // Report generation day
  }
];

/**
 * Seed day-to-module mappings
 */
export const seedDayModules = internalMutation({
  args: {},
  returns: v.object({
    inserted: v.number(),
    errors: v.array(v.string())
  }),
  handler: async (ctx) => {
    const errors: string[] = [];
    let inserted = 0;

    // Clear existing mappings first
    const existingMappings = await ctx.db.query("day_modules").collect();
    for (const mapping of existingMappings) {
      await ctx.db.delete(mapping._id);
    }

    for (const dayPlan of FIFTEEN_DAY_PLAN) {
      for (let i = 0; i < dayPlan.modules.length; i++) {
        try {
          await ctx.db.insert("day_modules", {
            day_number: dayPlan.day,
            module_id: dayPlan.modules[i],
            order_index: i
          });
          inserted++;
        } catch (error) {
          errors.push(
            `Error linking module ${dayPlan.modules[i]} to day ${dayPlan.day}: ${error}`
          );
        }
      }
    }

    return { inserted, errors };
  },
});

/**
 * Seed all module data
 */
export const seedAll = internalMutation({
  args: {},
  returns: v.object({
    modules: v.object({
      inserted: v.number(),
      errors: v.array(v.string())
    }),
    moduleQuestions: v.object({
      inserted: v.number(),
      errors: v.array(v.string())
    }),
    dayModules: v.object({
      inserted: v.number(),
      errors: v.array(v.string())
    })
  }),
  handler: async (ctx) => {
    // Seed modules first
    const modules = await ctx.runMutation(
      internal.seedModules.seedAssessmentModules
    );

    // Then seed module-question mappings
    const moduleQuestions = await ctx.runMutation(
      internal.seedModules.seedModuleQuestions
    );

    // Finally seed day-module mappings
    const dayModules = await ctx.runMutation(
      internal.seedModules.seedDayModules
    );

    return {
      modules,
      moduleQuestions,
      dayModules
    };
  },
});


