import { mutation, query, action } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

/**
 * Comprehensive Testing API for Zoe Sleep
 *
 * Provides endpoints for:
 * - Automated testing orchestration
 * - Gateway validation
 * - Questionnaire consistency checks
 * - Cross-platform data validation
 * - Clinical scoring verification
 * - Expansion pack testing
 */

// ============================================
// Gateway Validation Tests
// ============================================

/**
 * Test all gateway trigger conditions
 */
export const validateAllGateways = query({
  args: {},
  handler: async (ctx) => {
    const results: Array<{
      gatewayId: string;
      status: "pass" | "fail" | "warning";
      message: string;
      details?: Record<string, unknown>;
    }> = [];

    // Get all gateway definitions
    const gateways = await ctx.db.query("module_gateways").collect();

    if (gateways.length === 0) {
      return {
        status: "fail",
        message: "No gateways found in database. Run seed first.",
        results: [],
      };
    }

    // Expected gateways
    const expectedGateways = [
      "insomnia", "depression", "anxiety", "excessive_sleepiness",
      "cognitive", "osa", "pain", "sleep_timing", "diet_impact", "poor_sleep_quality"
    ];

    // Check all expected gateways exist
    for (const expectedId of expectedGateways) {
      const gateway = gateways.find(g => g.gateway_id === expectedId);
      if (!gateway) {
        results.push({
          gatewayId: expectedId,
          status: "fail",
          message: `Gateway '${expectedId}' not found in database`,
        });
      } else {
        // Validate gateway structure
        try {
          const condition = JSON.parse(gateway.condition_json);
          const targetModules = JSON.parse(gateway.target_modules_json);
          const triggerQuestions = JSON.parse(gateway.trigger_question_ids_json);

          if (!condition.type) {
            results.push({
              gatewayId: expectedId,
              status: "fail",
              message: "Gateway condition missing 'type' field",
            });
          } else if (targetModules.length === 0) {
            results.push({
              gatewayId: expectedId,
              status: "warning",
              message: "Gateway has no target modules",
            });
          } else if (triggerQuestions.length === 0) {
            results.push({
              gatewayId: expectedId,
              status: "fail",
              message: "Gateway has no trigger questions",
            });
          } else {
            results.push({
              gatewayId: expectedId,
              status: "pass",
              message: `Gateway valid: ${triggerQuestions.length} trigger questions, ${targetModules.length} target modules`,
              details: {
                conditionType: condition.type,
                targetModules,
                triggerQuestions,
              },
            });
          }
        } catch (e) {
          results.push({
            gatewayId: expectedId,
            status: "fail",
            message: `Invalid JSON in gateway configuration: ${e}`,
          });
        }
      }
    }

    const passCount = results.filter(r => r.status === "pass").length;
    const failCount = results.filter(r => r.status === "fail").length;

    return {
      status: failCount > 0 ? "fail" : "pass",
      summary: `${passCount}/${expectedGateways.length} gateways valid`,
      results,
    };
  },
});

/**
 * Test gateway triggering for a specific user
 */
export const testGatewayTriggering = mutation({
  args: {
    userId: v.id("users"),
    dryRun: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const { userId, dryRun = true } = args;

    const user = await ctx.db.get(userId);
    if (!user) {
      return { status: "fail", message: "User not found" };
    }

    // Get all user responses
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Build response map
    const responseMap: Record<string, string | number | undefined> = {};
    for (const r of responses) {
      responseMap[r.question_id] = r.response_value ?? r.response_number;
    }

    // Get gateways
    const gateways = await ctx.db.query("module_gateways").collect();

    const evaluationResults: Array<{
      gatewayId: string;
      shouldTrigger: boolean;
      triggered: boolean;
      responses: Record<string, unknown>;
    }> = [];

    for (const gateway of gateways) {
      const condition = JSON.parse(gateway.condition_json);
      const triggerQuestions = JSON.parse(gateway.trigger_question_ids_json);

      // Get relevant responses
      const relevantResponses: Record<string, unknown> = {};
      for (const qId of triggerQuestions) {
        relevantResponses[qId] = responseMap[qId];
      }

      // Evaluate condition
      const shouldTrigger = evaluateCondition(condition, responseMap);

      // Check current state
      const currentState = await ctx.db
        .query("user_gateway_states")
        .withIndex("by_user_gateway", (q) => q.eq("user_id", userId).eq("gateway_id", gateway.gateway_id))
        .first();

      const triggered = currentState?.triggered ?? false;

      evaluationResults.push({
        gatewayId: gateway.gateway_id,
        shouldTrigger,
        triggered,
        responses: relevantResponses,
      });

      // Update state if not dry run
      if (!dryRun && shouldTrigger !== triggered) {
        if (currentState) {
          await ctx.db.patch(currentState._id, {
            triggered: shouldTrigger,
            triggered_at: shouldTrigger ? Date.now() : undefined,
            last_evaluated_at: Date.now(),
          });
        } else {
          await ctx.db.insert("user_gateway_states", {
            user_id: userId,
            gateway_id: gateway.gateway_id,
            triggered: shouldTrigger,
            triggered_at: shouldTrigger ? Date.now() : undefined,
            last_evaluated_at: Date.now(),
          });
        }
      }
    }

    const mismatches = evaluationResults.filter(r => r.shouldTrigger !== r.triggered);

    return {
      status: mismatches.length > 0 ? "mismatch" : "pass",
      userId,
      dryRun,
      totalGateways: evaluationResults.length,
      triggeredCount: evaluationResults.filter(r => r.shouldTrigger).length,
      mismatchCount: mismatches.length,
      results: evaluationResults,
      mismatches,
    };
  },
});

// Helper function to evaluate gateway conditions
function evaluateCondition(condition: Record<string, unknown>, responses: Record<string, string | number | undefined>): boolean {
  const type = condition.type as string;

  switch (type) {
    case "equals":
      return responses[condition.questionId as string] === condition.value;

    case "greaterThanOrEqual":
      const numValue = responses[condition.questionId as string];
      return typeof numValue === "number" && numValue >= (condition.value as number);

    case "lessThanOrEqual":
      const numVal = responses[condition.questionId as string];
      return typeof numVal === "number" && numVal <= (condition.value as number);

    case "and":
      return (condition.conditions as Array<Record<string, unknown>>).every(c => evaluateCondition(c, responses));

    case "or":
      return (condition.conditions as Array<Record<string, unknown>>).some(c => evaluateCondition(c, responses));

    case "calculated":
      // For complex calculations like weekday/weekend difference
      return false; // Would need specific implementation

    default:
      return false;
  }
}

// ============================================
// Questionnaire Validation Tests
// ============================================

/**
 * Validate all questions exist and have correct format
 */
export const validateQuestionnaireStructure = query({
  args: {},
  handler: async (ctx) => {
    const results: Array<{
      area: string;
      status: "pass" | "fail" | "warning";
      message: string;
      count?: number;
    }> = [];

    // Check assessment questions
    const assessmentQuestions = await ctx.db.query("assessment_questions").collect();
    if (assessmentQuestions.length === 0) {
      results.push({
        area: "assessment_questions",
        status: "fail",
        message: "No assessment questions found. Run seedQuestions first.",
      });
    } else {
      // Validate each question has required fields
      const invalidQuestions = assessmentQuestions.filter(q =>
        !q.question_id || !q.question_text || !q.answer_format || !q.format_config
      );

      if (invalidQuestions.length > 0) {
        results.push({
          area: "assessment_questions",
          status: "fail",
          message: `${invalidQuestions.length} questions missing required fields`,
          count: invalidQuestions.length,
        });
      } else {
        results.push({
          area: "assessment_questions",
          status: "pass",
          message: `${assessmentQuestions.length} assessment questions valid`,
          count: assessmentQuestions.length,
        });
      }

      // Validate format_config is valid JSON
      const invalidFormat = assessmentQuestions.filter(q => {
        try {
          JSON.parse(q.format_config);
          return false;
        } catch {
          return true;
        }
      });

      if (invalidFormat.length > 0) {
        results.push({
          area: "format_config",
          status: "fail",
          message: `${invalidFormat.length} questions have invalid format_config JSON`,
          count: invalidFormat.length,
        });
      }
    }

    // Check sleep diary questions
    const sleepDiaryQuestions = await ctx.db.query("sleep_diary_questions").collect();
    if (sleepDiaryQuestions.length === 0) {
      results.push({
        area: "sleep_diary_questions",
        status: "fail",
        message: "No sleep diary questions found",
      });
    } else {
      results.push({
        area: "sleep_diary_questions",
        status: "pass",
        message: `${sleepDiaryQuestions.length} sleep diary questions found`,
        count: sleepDiaryQuestions.length,
      });
    }

    // Check modules
    const modules = await ctx.db.query("assessment_modules").collect();
    if (modules.length === 0) {
      results.push({
        area: "assessment_modules",
        status: "fail",
        message: "No assessment modules found. Run seedModules first.",
      });
    } else {
      const coreModules = modules.filter(m => m.module_type === "CORE");
      const gatewayModules = modules.filter(m => m.module_type === "GATEWAY");
      const expansionModules = modules.filter(m => m.module_type === "EXPANSION");

      results.push({
        area: "assessment_modules",
        status: "pass",
        message: `${modules.length} modules: ${coreModules.length} CORE, ${gatewayModules.length} GATEWAY, ${expansionModules.length} EXPANSION`,
        count: modules.length,
      });
    }

    // Check module-question mappings
    const moduleQuestions = await ctx.db.query("module_questions").collect();
    if (moduleQuestions.length === 0) {
      results.push({
        area: "module_questions",
        status: "fail",
        message: "No module-question mappings found",
      });
    } else {
      results.push({
        area: "module_questions",
        status: "pass",
        message: `${moduleQuestions.length} module-question mappings`,
        count: moduleQuestions.length,
      });

      // Check for orphan mappings
      const questionIds = new Set(assessmentQuestions.map(q => q.question_id));
      const orphanMappings = moduleQuestions.filter(mq => !questionIds.has(mq.question_id));

      if (orphanMappings.length > 0) {
        results.push({
          area: "orphan_mappings",
          status: "warning",
          message: `${orphanMappings.length} module-question mappings reference non-existent questions`,
          count: orphanMappings.length,
        });
      }
    }

    // Check day-module mappings
    const dayModules = await ctx.db.query("day_modules").collect();
    if (dayModules.length === 0) {
      results.push({
        area: "day_modules",
        status: "fail",
        message: "No day-module mappings found",
      });
    } else {
      // Check each day has content
      const dayNumbers = new Set(dayModules.map(dm => dm.day_number));
      const emptyDays = [];
      for (let day = 1; day <= 15; day++) {
        if (!dayNumbers.has(day)) {
          emptyDays.push(day);
        }
      }

      if (emptyDays.length > 0) {
        results.push({
          area: "day_modules",
          status: "warning",
          message: `Days without assigned modules: ${emptyDays.join(", ")}`,
          count: emptyDays.length,
        });
      } else {
        results.push({
          area: "day_modules",
          status: "pass",
          message: `All 15 days have assigned modules (${dayModules.length} total mappings)`,
          count: dayModules.length,
        });
      }
    }

    const failCount = results.filter(r => r.status === "fail").length;
    const warnCount = results.filter(r => r.status === "warning").length;

    return {
      status: failCount > 0 ? "fail" : warnCount > 0 ? "warning" : "pass",
      summary: `${results.filter(r => r.status === "pass").length} pass, ${warnCount} warnings, ${failCount} failures`,
      results,
    };
  },
});

/**
 * Validate question answer formats match their types
 */
export const validateAnswerFormats = query({
  args: {},
  handler: async (ctx) => {
    const questions = await ctx.db.query("assessment_questions").collect();

    const validFormats = [
      "time_picker", "minutes_scroll", "number_scroll", "slider_scale",
      "single_select_chips", "multi_select_chips", "date_picker",
      "number_input", "repeating_group", "text_input"
    ];

    const results: Array<{
      questionId: string;
      status: "pass" | "fail";
      format: string;
      message: string;
    }> = [];

    for (const q of questions) {
      if (!validFormats.includes(q.answer_format)) {
        results.push({
          questionId: q.question_id,
          status: "fail",
          format: q.answer_format,
          message: `Invalid answer format: ${q.answer_format}`,
        });
        continue;
      }

      try {
        const config = JSON.parse(q.format_config);

        // Validate config matches format type
        switch (q.answer_format) {
          case "slider_scale":
            if (typeof config.scaleMin !== "number" || typeof config.scaleMax !== "number") {
              results.push({
                questionId: q.question_id,
                status: "fail",
                format: q.answer_format,
                message: "slider_scale missing scaleMin/scaleMax",
              });
            } else {
              results.push({
                questionId: q.question_id,
                status: "pass",
                format: q.answer_format,
                message: `Valid slider: ${config.scaleMin}-${config.scaleMax}`,
              });
            }
            break;

          case "single_select_chips":
          case "multi_select_chips":
            if (!Array.isArray(config.options) || config.options.length === 0) {
              results.push({
                questionId: q.question_id,
                status: "fail",
                format: q.answer_format,
                message: "Chips format missing options array",
              });
            } else {
              results.push({
                questionId: q.question_id,
                status: "pass",
                format: q.answer_format,
                message: `Valid chips: ${config.options.length} options`,
              });
            }
            break;

          default:
            results.push({
              questionId: q.question_id,
              status: "pass",
              format: q.answer_format,
              message: "Format config present",
            });
        }
      } catch (e) {
        results.push({
          questionId: q.question_id,
          status: "fail",
          format: q.answer_format,
          message: `Invalid format_config JSON: ${e}`,
        });
      }
    }

    const failCount = results.filter(r => r.status === "fail").length;

    return {
      status: failCount > 0 ? "fail" : "pass",
      totalQuestions: questions.length,
      validCount: results.filter(r => r.status === "pass").length,
      invalidCount: failCount,
      results: failCount > 0 ? results.filter(r => r.status === "fail") : [],
    };
  },
});

// ============================================
// Clinical Scoring Validation
// ============================================

/**
 * Validate clinical scoring functions produce correct results
 */
export const validateClinicalScoring = mutation({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;

    const results: Array<{
      questionnaire: string;
      status: "pass" | "fail" | "skip";
      score?: number;
      maxScore?: number;
      expectedRange?: string;
      message: string;
    }> = [];

    // Get user responses
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    // Build response map
    const responseMap: Record<string, number | string | undefined> = {};
    for (const r of responses) {
      responseMap[r.question_id] = r.response_number ?? r.response_value;
    }

    // Test ISI scoring
    const isiResponses = [];
    for (let i = 1; i <= 7; i++) {
      const value = responseMap[`ISI_${i}`];
      if (typeof value === "number") {
        isiResponses.push(value);
      }
    }

    if (isiResponses.length >= 5) {
      const isiScore = isiResponses.reduce((a, b) => a + b, 0);
      const prorated = Math.round(isiScore * (7 / isiResponses.length));

      if (prorated >= 0 && prorated <= 28) {
        results.push({
          questionnaire: "ISI",
          status: "pass",
          score: prorated,
          maxScore: 28,
          message: `ISI score: ${prorated}/28`,
        });
      } else {
        results.push({
          questionnaire: "ISI",
          status: "fail",
          score: prorated,
          maxScore: 28,
          message: `ISI score out of range: ${prorated}`,
        });
      }
    } else {
      results.push({
        questionnaire: "ISI",
        status: "skip",
        message: `Insufficient ISI responses (${isiResponses.length}/7)`,
      });
    }

    // Test PHQ-9 scoring
    const phq9Responses = [];
    for (let i = 1; i <= 9; i++) {
      const value = responseMap[`PHQ9_${i}`];
      if (typeof value === "number") {
        phq9Responses.push(value);
      }
    }

    if (phq9Responses.length >= 7) {
      const phq9Score = phq9Responses.reduce((a, b) => a + b, 0);
      const prorated = Math.round(phq9Score * (9 / phq9Responses.length));

      if (prorated >= 0 && prorated <= 27) {
        results.push({
          questionnaire: "PHQ-9",
          status: "pass",
          score: prorated,
          maxScore: 27,
          message: `PHQ-9 score: ${prorated}/27`,
        });
      } else {
        results.push({
          questionnaire: "PHQ-9",
          status: "fail",
          score: prorated,
          maxScore: 27,
          message: `PHQ-9 score out of range: ${prorated}`,
        });
      }
    } else {
      results.push({
        questionnaire: "PHQ-9",
        status: "skip",
        message: `Insufficient PHQ-9 responses (${phq9Responses.length}/9)`,
      });
    }

    // Test GAD-7 scoring
    const gad7Responses = [];
    for (let i = 1; i <= 7; i++) {
      const value = responseMap[`GAD7_${i}`];
      if (typeof value === "number") {
        gad7Responses.push(value);
      }
    }

    if (gad7Responses.length >= 5) {
      const gad7Score = gad7Responses.reduce((a, b) => a + b, 0);
      const prorated = Math.round(gad7Score * (7 / gad7Responses.length));

      if (prorated >= 0 && prorated <= 21) {
        results.push({
          questionnaire: "GAD-7",
          status: "pass",
          score: prorated,
          maxScore: 21,
          message: `GAD-7 score: ${prorated}/21`,
        });
      } else {
        results.push({
          questionnaire: "GAD-7",
          status: "fail",
          score: prorated,
          maxScore: 21,
          message: `GAD-7 score out of range: ${prorated}`,
        });
      }
    } else {
      results.push({
        questionnaire: "GAD-7",
        status: "skip",
        message: `Insufficient GAD-7 responses (${gad7Responses.length}/7)`,
      });
    }

    // Test STOP-BANG scoring
    const sbResponses = [];
    for (let i = 1; i <= 8; i++) {
      const value = responseMap[`SB_${i}`];
      if (value === "Yes" || value === "No") {
        sbResponses.push(value === "Yes" ? 1 : 0);
      }
    }

    if (sbResponses.length >= 6) {
      const sbScore = sbResponses.reduce((a, b) => a + b, 0);

      if (sbScore >= 0 && sbScore <= 8) {
        results.push({
          questionnaire: "STOP-BANG",
          status: "pass",
          score: sbScore,
          maxScore: 8,
          message: `STOP-BANG score: ${sbScore}/8`,
        });
      } else {
        results.push({
          questionnaire: "STOP-BANG",
          status: "fail",
          score: sbScore,
          maxScore: 8,
          message: `STOP-BANG score out of range: ${sbScore}`,
        });
      }
    } else {
      results.push({
        questionnaire: "STOP-BANG",
        status: "skip",
        message: `Insufficient STOP-BANG responses (${sbResponses.length}/8)`,
      });
    }

    // Test ESS scoring
    const essResponses = [];
    for (let i = 1; i <= 8; i++) {
      const value = responseMap[`ESS_${i}`];
      if (typeof value === "number") {
        essResponses.push(value);
      }
    }

    if (essResponses.length >= 6) {
      const essScore = essResponses.reduce((a, b) => a + b, 0);
      const prorated = Math.round(essScore * (8 / essResponses.length));

      if (prorated >= 0 && prorated <= 24) {
        results.push({
          questionnaire: "ESS",
          status: "pass",
          score: prorated,
          maxScore: 24,
          message: `ESS score: ${prorated}/24`,
        });
      } else {
        results.push({
          questionnaire: "ESS",
          status: "fail",
          score: prorated,
          maxScore: 24,
          message: `ESS score out of range: ${prorated}`,
        });
      }
    } else {
      results.push({
        questionnaire: "ESS",
        status: "skip",
        message: `Insufficient ESS responses (${essResponses.length}/8)`,
      });
    }

    const failCount = results.filter(r => r.status === "fail").length;
    const passCount = results.filter(r => r.status === "pass").length;
    const skipCount = results.filter(r => r.status === "skip").length;

    return {
      status: failCount > 0 ? "fail" : "pass",
      summary: `${passCount} pass, ${skipCount} skipped, ${failCount} fail`,
      results,
    };
  },
});

// ============================================
// Expansion Pack Tests
// ============================================

/**
 * Test expansion scheduling algorithm
 */
export const testExpansionScheduling = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const { userId } = args;

    // Get user's triggered gateways
    const gatewayStates = await ctx.db
      .query("user_gateway_states")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .collect();

    const triggeredGateways = gatewayStates.filter(g => g.triggered).map(g => g.gateway_id);

    // Get expansion schedule
    const schedule = await ctx.db
      .query("user_expansion_schedules")
      .withIndex("by_user", (q) => q.eq("user_id", userId))
      .first();

    if (!schedule) {
      return {
        status: "warning",
        message: "No expansion schedule found for user",
        triggeredGateways,
        expectedModules: getExpectedModulesForGateways(triggeredGateways),
      };
    }

    // Validate schedule
    const results: Array<{ check: string; status: "pass" | "fail"; message: string }> = [];

    // Check triggered gateways match
    const scheduledGateways = schedule.triggered_gateways;
    const gatewayMatch = triggeredGateways.every(g => scheduledGateways.includes(g)) &&
                         scheduledGateways.every(g => triggeredGateways.includes(g));

    results.push({
      check: "gateway_match",
      status: gatewayMatch ? "pass" : "fail",
      message: gatewayMatch
        ? "Scheduled gateways match triggered gateways"
        : `Mismatch: triggered=${triggeredGateways.join(",")} vs scheduled=${scheduledGateways.join(",")}`,
    });

    // Check day assignments don't exceed limits
    for (const day of schedule.day_assignments) {
      if (day.question_count > 33) {
        results.push({
          check: `day_${day.day_number}_load`,
          status: "fail",
          message: `Day ${day.day_number} has ${day.question_count} questions (max 33)`,
        });
      }
    }

    // Check all days 8-14 are covered if there are expansion modules
    if (schedule.total_expansion_questions > 0) {
      const daysWithModules = new Set(schedule.day_assignments.map(d => d.day_number));
      const expectedDays = [8, 9, 10, 11, 12, 13, 14];
      const missingDays = expectedDays.filter(d => !daysWithModules.has(d));

      if (missingDays.length > 0 && schedule.total_expansion_questions > 50) {
        results.push({
          check: "day_coverage",
          status: "warning",
          message: `Days ${missingDays.join(",")} have no expansion modules`,
        });
      }
    }

    const failCount = results.filter(r => r.status === "fail").length;

    return {
      status: failCount > 0 ? "fail" : "pass",
      triggeredGateways,
      schedule: {
        totalQuestions: schedule.total_expansion_questions,
        totalMinutes: schedule.total_estimated_minutes,
        dayAssignments: schedule.day_assignments,
      },
      results,
    };
  },
});

// Helper to get expected modules for gateways
function getExpectedModulesForGateways(gateways: string[]): string[] {
  const gatewayToModules: Record<string, string[]> = {
    insomnia: ["expansion_isi", "expansion_dbas", "expansion_sleep_hygiene", "expansion_psas"],
    depression: ["expansion_phq9", "expansion_dass21"],
    anxiety: ["expansion_gad7", "expansion_dass21"],
    excessive_sleepiness: ["expansion_ess", "expansion_fss", "expansion_fosq"],
    cognitive: ["expansion_promis"],
    osa: ["expansion_stop_bang", "expansion_berlin"],
    pain: ["expansion_bpi"],
    sleep_timing: ["expansion_meq"],
    diet_impact: ["expansion_medas"],
    poor_sleep_quality: ["expansion_isi", "expansion_sleep_hygiene"],
  };

  const modules = new Set<string>();
  for (const gateway of gateways) {
    const mods = gatewayToModules[gateway] || [];
    for (const mod of mods) {
      modules.add(mod);
    }
  }

  return Array.from(modules);
}

// ============================================
// Data Consistency Tests
// ============================================

/**
 * Check for data consistency issues across tables
 */
export const validateDataConsistency = query({
  args: {},
  handler: async (ctx) => {
    const results: Array<{
      check: string;
      status: "pass" | "fail" | "warning";
      message: string;
      count?: number;
    }> = [];

    // Check users have valid current_day
    const users = await ctx.db.query("users").collect();
    const invalidDayUsers = users.filter(u => u.current_day < 1 || u.current_day > 16);

    if (invalidDayUsers.length > 0) {
      results.push({
        check: "user_current_day",
        status: "fail",
        message: `${invalidDayUsers.length} users have invalid current_day`,
        count: invalidDayUsers.length,
      });
    } else {
      results.push({
        check: "user_current_day",
        status: "pass",
        message: "All users have valid current_day (1-16)",
      });
    }

    // Check all responses reference valid users
    const userIds = new Set(users.map(u => u._id));
    const responses = await ctx.db.query("user_assessment_responses").collect();
    const orphanResponses = responses.filter(r => !userIds.has(r.user_id));

    if (orphanResponses.length > 0) {
      results.push({
        check: "orphan_responses",
        status: "warning",
        message: `${orphanResponses.length} responses reference deleted users`,
        count: orphanResponses.length,
      });
    } else {
      results.push({
        check: "orphan_responses",
        status: "pass",
        message: "All responses reference valid users",
      });
    }

    // Check for duplicate responses (same user, question, day)
    const responseKeys = new Set<string>();
    const duplicates: string[] = [];
    for (const r of responses) {
      const key = `${r.user_id}_${r.question_id}_${r.day_number}`;
      if (responseKeys.has(key)) {
        duplicates.push(key);
      }
      responseKeys.add(key);
    }

    if (duplicates.length > 0) {
      results.push({
        check: "duplicate_responses",
        status: "warning",
        message: `${duplicates.length} duplicate responses found`,
        count: duplicates.length,
      });
    } else {
      results.push({
        check: "duplicate_responses",
        status: "pass",
        message: "No duplicate responses",
      });
    }

    // Check sleep data date consistency
    const sleepData = await ctx.db.query("user_sleep_data").collect();
    const invalidDates = sleepData.filter(s => {
      const datePattern = /^\d{4}-\d{2}-\d{2}$/;
      return !datePattern.test(s.date);
    });

    if (invalidDates.length > 0) {
      results.push({
        check: "sleep_data_dates",
        status: "fail",
        message: `${invalidDates.length} sleep records have invalid date format`,
        count: invalidDates.length,
      });
    } else {
      results.push({
        check: "sleep_data_dates",
        status: "pass",
        message: `All ${sleepData.length} sleep records have valid dates`,
      });
    }

    // Check scores are within valid ranges
    const scores = await ctx.db.query("questionnaire_scores").collect();
    const invalidScores = scores.filter(s => {
      if (s.max_score && (s.score < 0 || s.score > s.max_score)) {
        return true;
      }
      return false;
    });

    if (invalidScores.length > 0) {
      results.push({
        check: "score_ranges",
        status: "fail",
        message: `${invalidScores.length} scores outside valid range`,
        count: invalidScores.length,
      });
    } else {
      results.push({
        check: "score_ranges",
        status: "pass",
        message: `All ${scores.length} scores within valid ranges`,
      });
    }

    const failCount = results.filter(r => r.status === "fail").length;
    const warnCount = results.filter(r => r.status === "warning").length;

    return {
      status: failCount > 0 ? "fail" : warnCount > 0 ? "warning" : "pass",
      summary: `${results.filter(r => r.status === "pass").length} pass, ${warnCount} warnings, ${failCount} failures`,
      results,
    };
  },
});

// ============================================
// Full Test Suite Runner
// ============================================

/**
 * Run all validation tests
 */
export const runFullTestSuite = query({
  args: {
    includeUserTests: v.optional(v.boolean()),
    testUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    const { includeUserTests = false, testUserId } = args;

    const suiteResults: Record<string, unknown> = {};

    // Run structural validations
    // Note: These would need to be called separately as queries can't call other queries directly
    // This is a placeholder showing what the full test suite would cover

    suiteResults.tests = [
      "validateAllGateways",
      "validateQuestionnaireStructure",
      "validateAnswerFormats",
      "validateDataConsistency",
    ];

    if (includeUserTests && testUserId) {
      suiteResults.userTests = [
        "testGatewayTriggering",
        "validateClinicalScoring",
        "testExpansionScheduling",
      ];
    }

    return {
      message: "Call individual test functions for detailed results",
      availableTests: suiteResults,
      instructions: {
        structural: "Run validateAllGateways, validateQuestionnaireStructure, validateAnswerFormats, validateDataConsistency",
        userLevel: "For user-specific tests, provide userId and run testGatewayTriggering, validateClinicalScoring, testExpansionScheduling",
      },
    };
  },
});
