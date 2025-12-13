"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";

// Lazy-initialize LLM clients to avoid deploy-time errors
let openai: OpenAI | null = null;
let anthropic: Anthropic | null = null;

function getOpenAI(): OpenAI {
  if (!openai) {
    openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }
  return openai;
}

function getAnthropic(): Anthropic {
  if (!anthropic) {
    anthropic = new Anthropic({
      apiKey: process.env.ANTHROPIC_API_KEY,
    });
  }
  return anthropic;
}

// Dual-provider LLM call with Claude primary, OpenAI fallback
async function callLLM(
  systemPrompt: string,
  userPrompt: string,
  jsonMode: boolean = true
): Promise<string> {
  // Try Claude first (primary)
  if (process.env.ANTHROPIC_API_KEY) {
    try {
      const message = await getAnthropic().messages.create({
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
  try {
    const completion = await getOpenAI().chat.completions.create({
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
    throw new Error("Both Claude and OpenAI APIs failed");
  }
}

/**
 * Analyze patient responses using LLM
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
    // Get all patient responses
    const responses = await ctx.runQuery(
      internal.physician.getPatientResponsesByDay,
      { userId: args.userId }
    );

    // Get patient details
    const patientDetails = await ctx.runQuery(
      internal.physician.getPatientDetails,
      { userId: args.userId }
    );

    // Get actual response values
    const allResponses: Array<{ questionId: string; value: string }> = [];
    for (let day = 1; day <= 15; day++) {
      const dayData = await ctx.runQuery(internal.physician.getPatientDayData, {
        userId: args.userId,
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

    // Prepare prompt for LLM
    const prompt = `You are a sleep medicine expert analyzing a patient's 15-day sleep assessment data.

Patient Information:
- Name: ${patientDetails.name || "Unknown"}
- Age: ${patientDetails.demographics.dateOfBirth || "Unknown"}
- Sex: ${patientDetails.demographics.sex || "Unknown"}

Total Responses: ${allResponses.length}

Please analyze this patient's sleep data and provide:
1. A brief summary of their sleep patterns and issues (2-3 sentences)
2. Key risk factors identified (list 3-5 most important)
3. Recommended interventions (list 3-5 specific, evidence-based interventions)

Format your response as JSON with keys: summary, riskFactors (array), recommendations (array).`;

    try {
      const completion = await getOpenAI().chat.completions.create({
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content:
              "You are a sleep medicine expert. Respond only with valid JSON.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        temperature: 0.7,
        response_format: { type: "json_object" },
      });

      const result = JSON.parse(
        completion.choices[0].message.content || "{}"
      );

      return {
        summary: result.summary || "No summary available",
        riskFactors: result.riskFactors || [],
        recommendations: result.recommendations || [],
      };
    } catch (error) {
      console.error("Error analyzing patient responses:", error);
      return {
        summary: "Error analyzing patient data",
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

    // Prepare prompt
    const prompt = `You are a sleep medicine expert. Based on a patient's sleep assessment data, recommend specific interventions.

Patient Information:
- Name: ${patientDetails.name || "Unknown"}
- Total Responses: ${patientDetails.totalResponses}
- Completed Days: ${patientDetails.completedDays}/15

Questionnaire Scores:
${scores.map((s) => `- ${s.questionnaire_name}: ${s.score}/${s.max_score} (${s.category})`).join("\n")}

Recommend 3-5 evidence-based sleep interventions with:
1. Intervention name (specific, actionable)
2. Rationale (why this intervention is recommended for this patient)
3. Priority (high, medium, or low)

Format as JSON array with objects containing: interventionName, rationale, priority.`;

    try {
      const completion = await getOpenAI().chat.completions.create({
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content:
              "You are a sleep medicine expert. Respond only with valid JSON.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        temperature: 0.7,
        response_format: { type: "json_object" },
      });

      const result = JSON.parse(
        completion.choices[0].message.content || '{"recommendations": []}'
      );

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

