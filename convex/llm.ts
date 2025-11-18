"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import OpenAI from "openai";

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

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
      const completion = await openai.chat.completions.create({
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
        result = await calculateISI(allResponses, openai);
        break;
      case "PSQI": // Pittsburgh Sleep Quality Index
        result = await calculatePSQI(allResponses, openai);
        break;
      case "ESS": // Epworth Sleepiness Scale
        result = await calculateESS(allResponses, openai);
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
      const completion = await openai.chat.completions.create({
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
  responses: Record<string, string>,
  openai: OpenAI
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
  responses: Record<string, string>,
  openai: OpenAI
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
  responses: Record<string, string>,
  openai: OpenAI
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



