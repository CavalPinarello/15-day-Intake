"use node";

import { action, ActionCtx } from "./_generated/server";
import { v } from "convex/values";
import { internal, api } from "./_generated/api";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";

// ============================================
// LLM Configuration Types
// ============================================

interface LLMConfig {
  primaryModel: string;
  fallbackModel: string;
  anthropicKey: string | null;
  openaiKey: string | null;
  enableFallback: boolean;
}

// Model provider detection
function getProvider(modelId: string): "anthropic" | "openai" {
  if (modelId.startsWith("claude") || modelId.startsWith("anthropic")) {
    return "anthropic";
  }
  return "openai";
}

// ============================================
// LLM Client Management
// ============================================

// Create OpenAI client with specific API key
function createOpenAI(apiKey: string): OpenAI {
  return new OpenAI({ apiKey });
}

// Create Anthropic client with specific API key
function createAnthropic(apiKey: string): Anthropic {
  return new Anthropic({ apiKey });
}

// Get API key - prefer system settings, fall back to env
async function getApiKey(
  ctx: ActionCtx,
  provider: "anthropic" | "openai"
): Promise<string | null> {
  try {
    // Try to get from system settings first
    const config = await ctx.runQuery(api.systemSettings.getLLMConfig, {});
    if (provider === "anthropic" && config.anthropicKey) {
      return config.anthropicKey;
    }
    if (provider === "openai" && config.openaiKey) {
      return config.openaiKey;
    }
  } catch {
    // System settings not available, fall back to env
  }

  // Fall back to environment variables
  if (provider === "anthropic") {
    return process.env.ANTHROPIC_API_KEY || null;
  }
  return process.env.OPENAI_API_KEY || null;
}

// Get full LLM config
async function getLLMConfigFromSettings(ctx: ActionCtx): Promise<LLMConfig> {
  try {
    const config = await ctx.runQuery(api.systemSettings.getLLMConfig, {});
    return {
      primaryModel: config.primaryModel || "claude-sonnet-4-20250514",
      fallbackModel: config.fallbackModel || "gpt-4o",
      anthropicKey: config.anthropicKey || process.env.ANTHROPIC_API_KEY || null,
      openaiKey: config.openaiKey || process.env.OPENAI_API_KEY || null,
      enableFallback: config.enableFallback ?? true,
    };
  } catch {
    // Fall back to env-only config
    return {
      primaryModel: "claude-sonnet-4-20250514",
      fallbackModel: "gpt-4o",
      anthropicKey: process.env.ANTHROPIC_API_KEY || null,
      openaiKey: process.env.OPENAI_API_KEY || null,
      enableFallback: true,
    };
  }
}

// ============================================
// Core LLM Call Function
// ============================================

/**
 * Dual-provider LLM call with configurable primary/fallback
 * Reads config from system settings, falls back to env vars
 */
async function callLLMWithConfig(
  ctx: ActionCtx,
  systemPrompt: string,
  userPrompt: string,
  jsonMode: boolean = true
): Promise<string> {
  const config = await getLLMConfigFromSettings(ctx);
  const primaryProvider = getProvider(config.primaryModel);

  // Try primary provider first
  const primaryKey = primaryProvider === "anthropic" ? config.anthropicKey : config.openaiKey;

  if (primaryKey) {
    try {
      if (primaryProvider === "anthropic") {
        const client = createAnthropic(primaryKey);
        const message = await client.messages.create({
          model: config.primaryModel,
          max_tokens: 4096,
          system: systemPrompt + (jsonMode ? " Respond only with valid JSON." : ""),
          messages: [{ role: "user", content: userPrompt }],
        });

        const content = message.content[0];
        if (content.type === "text") {
          return content.text;
        }
      } else {
        const client = createOpenAI(primaryKey);
        const completion = await client.chat.completions.create({
          model: config.primaryModel,
          messages: [
            { role: "system", content: systemPrompt + (jsonMode ? " Respond only with valid JSON." : "") },
            { role: "user", content: userPrompt },
          ],
          temperature: 0.7,
          ...(jsonMode && { response_format: { type: "json_object" as const } }),
        });
        return completion.choices[0].message.content || "{}";
      }
    } catch (error) {
      console.error(`${primaryProvider} API error:`, error);
      if (!config.enableFallback) {
        throw new Error(`${primaryProvider} API failed and fallback is disabled`);
      }
    }
  }

  // Fallback to secondary provider
  if (config.enableFallback) {
    const fallbackProvider = getProvider(config.fallbackModel);
    const fallbackKey = fallbackProvider === "anthropic" ? config.anthropicKey : config.openaiKey;

    if (fallbackKey) {
      try {
        if (fallbackProvider === "anthropic") {
          const client = createAnthropic(fallbackKey);
          const message = await client.messages.create({
            model: config.fallbackModel,
            max_tokens: 4096,
            system: systemPrompt + (jsonMode ? " Respond only with valid JSON." : ""),
            messages: [{ role: "user", content: userPrompt }],
          });

          const content = message.content[0];
          if (content.type === "text") {
            return content.text;
          }
        } else {
          const client = createOpenAI(fallbackKey);
          const completion = await client.chat.completions.create({
            model: config.fallbackModel,
            messages: [
              { role: "system", content: systemPrompt + (jsonMode ? " Respond only with valid JSON." : "") },
              { role: "user", content: userPrompt },
            ],
            temperature: 0.7,
            ...(jsonMode && { response_format: { type: "json_object" as const } }),
          });
          return completion.choices[0].message.content || "{}";
        }
      } catch (error) {
        console.error(`${fallbackProvider} API error:`, error);
      }
    }
  }

  throw new Error("All LLM providers failed or no API keys configured");
}

// Legacy wrapper for existing code (uses env vars directly if no ctx available)
async function callLLM(
  systemPrompt: string,
  userPrompt: string,
  jsonMode: boolean = true
): Promise<string> {
  // Try Claude first (primary) using env vars
  if (process.env.ANTHROPIC_API_KEY) {
    try {
      const client = createAnthropic(process.env.ANTHROPIC_API_KEY);
      const message = await client.messages.create({
        model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        system: systemPrompt + (jsonMode ? " Respond only with valid JSON." : ""),
        messages: [{ role: "user", content: userPrompt }],
      });

      const content = message.content[0];
      if (content.type === "text") {
        return content.text;
      }
    } catch (error) {
      console.error("Claude API error, falling back to OpenAI:", error);
    }
  }

  // Fallback to OpenAI
  if (process.env.OPENAI_API_KEY) {
    try {
      const client = createOpenAI(process.env.OPENAI_API_KEY);
      const completion = await client.chat.completions.create({
        model: "gpt-4o",
        messages: [
          { role: "system", content: systemPrompt + (jsonMode ? " Respond only with valid JSON." : "") },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.7,
        ...(jsonMode && { response_format: { type: "json_object" as const } }),
      });
      return completion.choices[0].message.content || "{}";
    } catch (error) {
      console.error("OpenAI API error:", error);
    }
  }

  throw new Error("Both Claude and OpenAI APIs failed or no API keys configured");
}

// ============================================
// Prompt Builder Helper
// ============================================

interface PatientAnalysisPrompt {
  systemPrompt: string;
  userPrompt: string;
  estimatedTokens: number;
}

async function buildAnalysisPrompt(
  ctx: ActionCtx,
  userId: string
): Promise<PatientAnalysisPrompt> {
  // Get patient details
  const patientDetails = await ctx.runQuery(
    internal.physician.getPatientDetails,
    { userId: userId as any }
  );

  // Get actual response values
  const allResponses: Array<{ questionId: string; value: string }> = [];
  for (let day = 1; day <= 14; day++) {
    const dayData = await ctx.runQuery(internal.physician.getPatientDayData, {
      userId: userId as any,
      dayNumber: day,
    });

    for (const response of dayData.responses) {
      if (response.response_value) {
        allResponses.push({
          questionId: response.question_id,
          value: response.response_value,
        });
      }
    }
  }

  // Get questionnaire scores
  const scores = await ctx.runQuery(internal.physician.getQuestionnaireScores, {
    userId: userId as any,
  });

  // Get gateway states
  const gatewayStates = await ctx.runQuery(internal.physician.getUserGatewayStates, {
    userId: userId as any,
  });

  const triggeredGateways = gatewayStates
    .filter((g: any) => g.triggered)
    .map((g: any) => g.gateway_id);

  const systemPrompt = `You are a board-certified sleep medicine specialist analyzing a patient's comprehensive 14-day sleep assessment.

Your analysis should be:
- Evidence-based and clinically actionable
- Specific to the patient's profile and responses
- Prioritized by clinical significance

Provide your analysis in JSON format with these exact keys:
{
  "summary": "2-3 sentence clinical summary",
  "riskFactors": ["array of 3-5 key risk factors"],
  "recommendations": ["array of 3-5 evidence-based interventions"]
}`;

  const userPrompt = `## Patient Profile
- Name: ${patientDetails.name || "Patient"}
- Age: ${patientDetails.demographics.dateOfBirth ? `Born ${patientDetails.demographics.dateOfBirth}` : "Unknown"}
- Sex: ${patientDetails.demographics.sex || "Unknown"}
- Total Responses: ${allResponses.length}
- Days Completed: ${patientDetails.completedDays}/14

## Triggered Gateways
${triggeredGateways.length > 0 ? triggeredGateways.map((g: string) => `- ${g}`).join("\n") : "None triggered"}

## Standardized Questionnaire Scores
${scores.length > 0 ? scores.map((s: any) => `- ${s.questionnaire_name}: ${s.score}/${s.max_score || "?"} (${s.category || s.interpretation || "no interpretation"})`).join("\n") : "No scores calculated yet"}

## Key Response Highlights
${allResponses.slice(0, 50).map(r => `- ${r.questionId}: ${r.value}`).join("\n")}
${allResponses.length > 50 ? `\n... and ${allResponses.length - 50} more responses` : ""}

Please analyze this patient's data and provide your clinical assessment.`;

  // Rough token estimation (4 chars per token average)
  const estimatedTokens = Math.ceil((systemPrompt.length + userPrompt.length) / 4);

  return {
    systemPrompt,
    userPrompt,
    estimatedTokens,
  };
}

/**
 * Preview the analysis prompt without running the LLM
 * Shows exactly what data will be sent for analysis
 */
export const previewAnalysisPrompt = action({
  args: {
    userId: v.id("users"),
  },
  returns: v.object({
    systemPrompt: v.string(),
    userPrompt: v.string(),
    estimatedTokens: v.number(),
    estimatedCost: v.string(),
    selectedModel: v.string(),
    modelProvider: v.string(),
  }),
  handler: async (ctx, args) => {
    const prompt = await buildAnalysisPrompt(ctx, args.userId);
    const config = await getLLMConfigFromSettings(ctx);

    // Estimate cost based on model
    const provider = getProvider(config.primaryModel);
    let costPerMToken = 0;
    if (provider === "anthropic") {
      // Claude Sonnet 4 pricing: $3/MTok input, $15/MTok output
      costPerMToken = 3; // Input cost
    } else {
      // GPT-4o pricing: $5/MTok input, $15/MTok output
      costPerMToken = 5;
    }

    const estimatedCost = (prompt.estimatedTokens / 1000000) * costPerMToken;

    return {
      systemPrompt: prompt.systemPrompt,
      userPrompt: prompt.userPrompt,
      estimatedTokens: prompt.estimatedTokens,
      estimatedCost: `~$${estimatedCost.toFixed(4)} (input only)`,
      selectedModel: config.primaryModel,
      modelProvider: provider,
    };
  },
});

/**
 * Analyze patient responses using LLM
 * Now uses configurable model from system settings
 */
export const analyzePatientResponses = action({
  args: {
    userId: v.id("users"),
  },
  returns: v.object({
    summary: v.string(),
    riskFactors: v.array(v.string()),
    recommendations: v.array(v.string()),
  }),
  handler: async (ctx, args) => {
    const prompt = await buildAnalysisPrompt(ctx, args.userId);

    try {
      // Use configurable LLM instead of hardcoded OpenAI
      const response = await callLLMWithConfig(
        ctx,
        prompt.systemPrompt,
        prompt.userPrompt,
        true // JSON mode
      );

      const result = JSON.parse(response);

      return {
        summary: result.summary || "No summary available",
        riskFactors: result.riskFactors || [],
        recommendations: result.recommendations || [],
      };
    } catch (error) {
      console.error("Error analyzing patient responses:", error);
      return {
        summary: "Error analyzing patient data. Please check API key configuration in Settings.",
        riskFactors: [],
        recommendations: [],
      };
    }
  },
});

/**
 * Calculate standardized questionnaire score
 */
export const calculateStandardizedScore = action({
  args: {
    userId: v.id("users"),
    questionnaireName: v.string(),
  },
  returns: v.object({
    score: v.number(),
    maxScore: v.number(),
    category: v.string(),
    interpretation: v.string(),
  }),
  handler: async (ctx, args) => {
    // Get all patient responses
    const allResponses: Record<string, string> = {};
    for (let day = 1; day <= 15; day++) {
      const dayData = await ctx.runQuery(internal.physician.getPatientDayData, {
        userId: args.userId,
        dayNumber: day,
      });

      for (const response of dayData.responses) {
        if (response.response_value) {
          allResponses[response.question_id] = response.response_value;
        }
      }
    }

    // Calculate score based on questionnaire type
    let result: {
      score: number;
      maxScore: number;
      category: string;
      interpretation: string;
    };

    switch (args.questionnaireName.toUpperCase()) {
      case "ISI": // Insomnia Severity Index
        result = await calculateISI(allResponses);
        break;
      case "PSQI": // Pittsburgh Sleep Quality Index
        result = await calculatePSQI(allResponses);
        break;
      case "ESS": // Epworth Sleepiness Scale
        result = await calculateESS(allResponses);
        break;
      default:
        result = {
          score: 0,
          maxScore: 0,
          category: "Unknown",
          interpretation: "Questionnaire type not supported",
        };
    }

    // Save the score
    await ctx.runMutation(internal.physician.saveQuestionnaireScore, {
      userId: args.userId,
      questionnaireName: args.questionnaireName,
      score: result.score,
      maxScore: result.maxScore,
      category: result.category,
      interpretation: result.interpretation,
      calculationMetadata: JSON.stringify({ calculatedAt: Date.now() }),
    });

    return result;
  },
});

/**
 * Generate intervention recommendations based on patient data
 * Now uses configurable model from system settings
 */
export const generateInterventionRecommendations = action({
  args: {
    userId: v.id("users"),
  },
  returns: v.array(
    v.object({
      interventionName: v.string(),
      rationale: v.string(),
      priority: v.string(),
    })
  ),
  handler: async (ctx, args) => {
    // Get patient details and responses
    const patientDetails = await ctx.runQuery(
      internal.physician.getPatientDetails,
      { userId: args.userId }
    );

    // Get questionnaire scores if available
    const scores = await ctx.runQuery(internal.physician.getQuestionnaireScores, {
      userId: args.userId,
    });

    const systemPrompt = "You are a sleep medicine expert. Respond only with valid JSON.";

    const userPrompt = `Based on a patient's sleep assessment data, recommend specific interventions.

Patient Information:
- Name: ${patientDetails.name || "Unknown"}
- Total Responses: ${patientDetails.totalResponses}
- Completed Days: ${patientDetails.completedDays}/14

Questionnaire Scores:
${scores.map((s: any) => `- ${s.questionnaire_name}: ${s.score}/${s.max_score} (${s.category})`).join("\n")}

Recommend 3-5 evidence-based sleep interventions with:
1. Intervention name (specific, actionable)
2. Rationale (why this intervention is recommended for this patient)
3. Priority (high, medium, or low)

Format as JSON object with key "recommendations" containing array of objects with: interventionName, rationale, priority.`;

    try {
      // Use configurable LLM instead of hardcoded OpenAI
      const response = await callLLMWithConfig(
        ctx,
        systemPrompt,
        userPrompt,
        true // JSON mode
      );

      const result = JSON.parse(response);

      return result.recommendations || [];
    } catch (error) {
      console.error("Error generating intervention recommendations:", error);
      return [];
    }
  },
});

// ============================================
// Helper Functions for Score Calculation
// ============================================

async function calculateISI(
  responses: Record<string, string>
): Promise<{
  score: number;
  maxScore: number;
  category: string;
  interpretation: string;
}> {
  // ISI has 7 questions, each scored 0-4
  // Questions typically: ISI1, ISI2, ISI3, ISI4, ISI5, ISI6, ISI7
  let score = 0;
  const maxScore = 28;

  // Try to find ISI questions in responses
  const isiQuestions = Object.keys(responses).filter((q) =>
    q.toUpperCase().startsWith("ISI")
  );

  for (const questionId of isiQuestions) {
    const value = responses[questionId];
    const numValue = parseInt(value, 10);
    if (!isNaN(numValue)) {
      score += numValue;
    }
  }

  // Interpret score
  let category = "";
  let interpretation = "";

  if (score <= 7) {
    category = "No clinically significant insomnia";
    interpretation =
      "Your responses indicate no significant insomnia symptoms.";
  } else if (score <= 14) {
    category = "Subthreshold insomnia";
    interpretation =
      "You have mild insomnia symptoms that may benefit from sleep hygiene improvements.";
  } else if (score <= 21) {
    category = "Moderate clinical insomnia";
    interpretation =
      "You have moderate insomnia that would benefit from behavioral interventions.";
  } else {
    category = "Severe clinical insomnia";
    interpretation =
      "You have severe insomnia. Professional evaluation and treatment are recommended.";
  }

  return { score, maxScore, category, interpretation };
}

async function calculatePSQI(
  responses: Record<string, string>
): Promise<{
  score: number;
  maxScore: number;
  category: string;
  interpretation: string;
}> {
  // PSQI has 7 component scores, each 0-3, total 0-21
  // For simplicity, we'll use a basic calculation
  let score = 0;
  const maxScore = 21;

  // Try to find PSQI questions
  const psqiQuestions = Object.keys(responses).filter((q) =>
    q.toUpperCase().includes("PSQI")
  );

  // Basic scoring (would need actual PSQI component calculation logic)
  for (const questionId of psqiQuestions) {
    const value = responses[questionId];
    const numValue = parseInt(value, 10);
    if (!isNaN(numValue)) {
      score += Math.min(numValue, 3); // PSQI components are 0-3
    }
  }

  score = Math.min(score, 21);

  let category = "";
  let interpretation = "";

  if (score <= 5) {
    category = "Good sleep quality";
    interpretation =
      "Your overall sleep quality is good with minimal difficulties.";
  } else if (score <= 10) {
    category = "Moderate sleep quality issues";
    interpretation =
      "You have some sleep quality issues that could be improved with interventions.";
  } else {
    category = "Poor sleep quality";
    interpretation =
      "You have significant sleep quality problems requiring attention.";
  }

  return { score, maxScore, category, interpretation };
}

async function calculateESS(
  responses: Record<string, string>
): Promise<{
  score: number;
  maxScore: number;
  category: string;
  interpretation: string;
}> {
  // ESS has 8 situations, each scored 0-3
  let score = 0;
  const maxScore = 24;

  // Try to find ESS questions
  const essQuestions = Object.keys(responses).filter((q) =>
    q.toUpperCase().startsWith("ESS")
  );

  for (const questionId of essQuestions) {
    const value = responses[questionId];
    const numValue = parseInt(value, 10);
    if (!isNaN(numValue)) {
      score += Math.min(numValue, 3);
    }
  }

  let category = "";
  let interpretation = "";

  if (score <= 7) {
    category = "Normal daytime sleepiness";
    interpretation = "You have normal levels of daytime sleepiness.";
  } else if (score <= 12) {
    category = "Mild excessive daytime sleepiness";
    interpretation =
      "You have mild excessive daytime sleepiness. Consider improving sleep hygiene.";
  } else if (score <= 15) {
    category = "Moderate excessive daytime sleepiness";
    interpretation =
      "You have moderate excessive daytime sleepiness that may require evaluation.";
  } else {
    category = "Severe excessive daytime sleepiness";
    interpretation =
      "You have severe excessive daytime sleepiness. Medical evaluation is strongly recommended.";
  }

  return { score, maxScore, category, interpretation };
}

// ============================================
// Comprehensive Score Interpretation with Claude
// ============================================

/**
 * Generate comprehensive clinical interpretation for a questionnaire score
 * Uses Claude as primary, OpenAI as fallback
 */
export const interpretQuestionnaireScore = action({
  args: {
    userId: v.id("users"),
    questionnaireName: v.string(),
    score: v.number(),
    maxScore: v.number(),
    severity: v.string(),
    questionResponses: v.array(
      v.object({
        questionId: v.string(),
        questionText: v.string(),
        responseValue: v.string(),
        responseNumber: v.optional(v.number()),
      })
    ),
  },
  returns: v.object({
    clinicalNarrative: v.string(),
    keyFindings: v.array(v.string()),
    riskFactors: v.array(v.string()),
    recommendations: v.array(v.string()),
    normativeComparison: v.string(),
    clinicalSignificance: v.string(),
  }),
  handler: async (ctx, args) => {
    // Get patient details for context
    const patientDetails = await ctx.runQuery(
      internal.physician.getPatientDetails,
      { userId: args.userId }
    );

    // Build detailed question response summary
    const responsesSummary = args.questionResponses
      .map((r) => `- ${r.questionText}: ${r.responseValue}${r.responseNumber !== undefined ? ` (${r.responseNumber})` : ""}`)
      .join("\n");

    // Get historical scores if available
    const scores = await ctx.runQuery(internal.physician.getQuestionnaireScores, {
      userId: args.userId,
    });
    const historicalScores = scores
      .filter((s) => s.questionnaire_name === args.questionnaireName)
      .map((s) => `Score: ${s.score}/${s.max_score} on ${new Date(s.calculated_at).toLocaleDateString()}`);

    const systemPrompt = `You are an expert sleep medicine clinician reviewing standardized questionnaire results.
Provide detailed, clinically-relevant interpretations that would help a physician understand the patient's condition.
Be specific about what the scores mean clinically and what actions should be considered.`;

    const userPrompt = `Analyze this ${args.questionnaireName} questionnaire result:

**Patient Information:**
- Name: ${patientDetails.name || "Patient"}
- Age: ${patientDetails.demographics.dateOfBirth || "Not provided"}
- Sex: ${patientDetails.demographics.sex || "Not provided"}

**Score Summary:**
- Total Score: ${args.score}/${args.maxScore}
- Severity Classification: ${args.severity}
- Completion Date: ${new Date().toLocaleDateString()}

**Individual Question Responses:**
${responsesSummary}

${historicalScores.length > 0 ? `**Historical Scores:**\n${historicalScores.join("\n")}` : "**Historical Scores:** No previous assessments"}

Please provide a comprehensive clinical interpretation in JSON format with these fields:
{
  "clinicalNarrative": "A 3-4 sentence clinical summary describing the patient's condition and what this score indicates",
  "keyFindings": ["Array of 3-5 key clinical findings from the responses"],
  "riskFactors": ["Array of 2-4 identified risk factors or concerns"],
  "recommendations": ["Array of 3-5 specific, evidence-based recommendations"],
  "normativeComparison": "How this patient compares to normative data (e.g., 'This score falls in the 85th percentile for adults with insomnia complaints')",
  "clinicalSignificance": "Brief statement about whether this score is clinically significant and warrants intervention"
}`;

    try {
      const response = await callLLM(systemPrompt, userPrompt, true);
      const result = JSON.parse(response);

      return {
        clinicalNarrative: result.clinicalNarrative || "Unable to generate clinical narrative.",
        keyFindings: result.keyFindings || [],
        riskFactors: result.riskFactors || [],
        recommendations: result.recommendations || [],
        normativeComparison: result.normativeComparison || "Normative comparison not available.",
        clinicalSignificance: result.clinicalSignificance || "Clinical significance undetermined.",
      };
    } catch (error) {
      console.error("Error interpreting questionnaire score:", error);
      return {
        clinicalNarrative: `The patient scored ${args.score}/${args.maxScore} on the ${args.questionnaireName}, indicating ${args.severity.toLowerCase()} severity.`,
        keyFindings: ["Score calculation completed successfully"],
        riskFactors: args.severity === "severe" ? ["Elevated score requires clinical attention"] : [],
        recommendations: ["Review individual question responses for detailed assessment"],
        normativeComparison: "Manual review recommended for normative comparison.",
        clinicalSignificance: args.severity === "normal" ? "Score within normal limits." : "Score may warrant clinical follow-up.",
      };
    }
  },
});

