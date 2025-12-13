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
 * Target: 10-15 base questions per day, expansion packs add when triggered
 */
const FIFTEEN_DAY_PLAN = [
  // Day 1: Social demographics (15 questions, ~8.5 min)
  {
    day: 1,
    modules: ["core_social"]
  },
  // Day 2: Sleep Quality Part 1 (12 questions, ~10 min)
  {
    day: 2,
    modules: ["core_sleep_quality_1"]
  },
  // Day 3: Sleep Quality Part 2 (11 questions, ~9.5 min)
  {
    day: 3,
    modules: ["core_sleep_quality_2"]
  },
  // Day 4: Metabolic (17 questions, ~13.5 min)
  {
    day: 4,
    modules: ["core_metabolic"]
  },
  // Day 5: Sleep patterns (15 questions, ~9 min)
  {
    day: 5,
    modules: ["core_sleep_quantity", "core_sleep_regularity", "core_sleep_timing"]
  },
  // Day 6: Physical health (11 questions, ~5.5 min)
  {
    day: 6,
    modules: ["core_physical"]
  },
  // Day 7: Nutritional (11 questions, ~5.5 min)
  {
    day: 7,
    modules: ["core_nutritional"]
  },
  // Day 8: Sleep Quality Expansion Part 1 (17 questions if triggered, ~8.5 min)
  {
    day: 8,
    modules: ["expansion_sleep_quality_1"]
  },
  // Day 9: Sleep Quality Expansion Part 2 (17 questions if triggered, ~8.5 min)
  {
    day: 9,
    modules: ["expansion_sleep_quality_2"]
  },
  // Day 10: Mental Health Expansion Part 1 (16 questions if triggered, ~8 min)
  {
    day: 10,
    modules: ["expansion_mental_health_1"]
  },
  // Day 11: Mental Health Expansion Part 2 (16 questions if triggered, ~8 min)
  {
    day: 11,
    modules: ["expansion_mental_health_2"]
  },
  // Day 12: Mental Health Expansion Part 3 (16 questions if triggered, ~8 min)
  {
    day: 12,
    modules: ["expansion_mental_health_3"]
  },
  // Day 13: Cognitive Expansion (17 + 16 = 33 questions if triggered, split across day)
  {
    day: 13,
    modules: ["expansion_cognitive_1", "expansion_cognitive_2"]
  },
  // Day 14: Physical Expansion (16 + 15 = 31 questions if triggered)
  {
    day: 14,
    modules: ["expansion_physical_1", "expansion_physical_2"]
  },
  // Day 15: Timing + Nutritional Expansion (19 + 14 = 33 questions if triggered)
  {
    day: 15,
    modules: ["expansion_sleep_timing", "expansion_nutritional"]
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


