"use node";

// Node.js process type declaration
declare const process: {
  env: Record<string, string | undefined>;
};

import { action, ActionCtx } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
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
  modulesUsed?: string[];
}

// ============================================
// Modular AI Analysis Architecture
// ============================================

interface PromptModule {
  id: string;
  name: string;
  description: string;
  estimatedTokens: number;
  enabledByDefault: boolean;
  build: (ctx: ActionCtx, userId: string) => Promise<string | null>;
}

// Default enabled modules
const DEFAULT_ENABLED_MODULES = [
  "demographics",
  "questionnaire_scores",
  "gateway_triggers",
  "sleep_log_full",
  "healthkit_sleep",
  "activity_data",
  "light_exposure",
  "perception_gap",
  "temporal_trends",
];

// Module A: Demographics & Context
async function buildDemographicsModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    const patientDetails = await ctx.runQuery(
      api.physician.getPatientDetails,
      { userId: userId as any }
    );

    if (!patientDetails) return null;

    const dob = patientDetails.demographics.dateOfBirth;
    let age = "Unknown";
    if (dob) {
      const birthDate = new Date(dob);
      const today = new Date();
      age = String(Math.floor((today.getTime() - birthDate.getTime()) / (365.25 * 24 * 60 * 60 * 1000)));
    }

    return `- Name: ${patientDetails.name || "Patient"}
- Age: ${age} years
- Sex: ${patientDetails.demographics.sex || "Unknown"}
- Height: ${patientDetails.demographics.height || "Unknown"}
- Weight: ${patientDetails.demographics.weight || "Unknown"}
- Days Completed: ${patientDetails.completedDays}/10
- Total Responses: ${patientDetails.totalResponses}
- Apple Health Connected: ${(patientDetails.user as any)?.apple_health_connected ? "Yes" : "No"}`;
  } catch (error) {
    console.error("Error building demographics module:", error);
    return null;
  }
}

// Module B: Standardized Questionnaire Scores
async function buildQuestionnaireScoresModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    const scores = await ctx.runQuery(api.physician.getQuestionnaireScores, {
      userId: userId as any,
    });

    if (!scores || scores.length === 0) {
      return "No questionnaire scores calculated yet.";
    }

    const scoreLines = scores.map((s: any) => {
      const interpretation = s.category || s.interpretation || "no interpretation";
      return `- **${s.questionnaire_name}**: ${s.score}/${s.max_score || "?"} (${interpretation})`;
    });

    return scoreLines.join("\n");
  } catch (error) {
    console.error("Error building questionnaire scores module:", error);
    return null;
  }
}

// Module C: Gateway Triggers & Risk Flags
async function buildGatewayTriggersModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    const gatewayStates = await ctx.runQuery(api.assessment.getUserGatewayStates, {
      userId: userId as any,
    });

    if (!gatewayStates) return "No gateway data available.";

    const triggeredGateways = Object.entries(gatewayStates)
      .filter(([_, state]: [string, any]) => state.triggered)
      .map(([gatewayId, state]: [string, any]) => {
        const triggeredAt = state.triggeredAt
          ? new Date(state.triggeredAt).toLocaleDateString()
          : "unknown date";
        return `- **${gatewayId}**: Triggered on ${triggeredAt}`;
      });

    if (triggeredGateways.length === 0) {
      return "No clinical gateways triggered.";
    }

    return triggeredGateways.join("\n");
  } catch (error) {
    console.error("Error building gateway triggers module:", error);
    return null;
  }
}

// Module D: Sleep Log Data (ALL 10 days - not truncated)
async function buildSleepLogFullModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    const subjectiveSleepData = await ctx.runQuery(api.physician.getSubjectiveSleepQuality, {
      userId: userId as any,
      days: 14,
    });

    if (!subjectiveSleepData || !subjectiveSleepData.dailyData || subjectiveSleepData.dailyData.length === 0) {
      return "No sleep log data available.";
    }

    const sleepLogLines = subjectiveSleepData.dailyData.map((day: any) => {
      const quality = day.quality !== null ? `Quality: ${day.quality}/10` : "";
      const duration = day.totalSleepMins ? `Duration: ${Math.round(day.totalSleepMins / 60 * 10) / 10}h` : "";
      const efficiency = day.perceivedEfficiency ? `Efficiency: ${day.perceivedEfficiency}%` : "";
      const latency = day.latencyMins ? `Latency: ${day.latencyMins}min` : "";
      const waso = day.wasoMins ? `WASO: ${day.wasoMins}min` : "";

      const metrics = [quality, duration, efficiency, latency, waso].filter(Boolean).join(", ");
      return `- Day ${day.dayNumber || "?"} (${day.date || "?"}): ${metrics || "No data"}`;
    });

    return sleepLogLines.join("\n");
  } catch (error) {
    console.error("Error building sleep log module:", error);
    return null;
  }
}

// Module E: HealthKit Sleep Architecture
async function buildHealthKitSleepModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    const healthSummary = await ctx.runQuery(api.healthkit.getPatientHealthSummary, {
      userId: userId as any,
    });

    const sleepArchitecture = await ctx.runQuery(api.healthkit.getSleepArchitecture, {
      userId: userId as any,
      limit: 14,
    });

    if (!healthSummary && (!sleepArchitecture || sleepArchitecture.length === 0)) {
      return "No HealthKit sleep data available. Patient may not have connected Apple Health.";
    }

    let result = "";

    if (healthSummary && healthSummary.hasHealthKitData) {
      result += `**14-Day Wearable Averages:**
- Average Sleep: ${healthSummary.summary?.avgSleepHours ? healthSummary.summary.avgSleepHours.toFixed(1) + "h" : "N/A"}
- Average Efficiency: ${healthSummary.summary?.avgEfficiency ? healthSummary.summary.avgEfficiency + "%" : "N/A"}
- Average Deep Sleep: ${healthSummary.summary?.avgDeepSleepMins ? Math.round(healthSummary.summary.avgDeepSleepMins) + " mins" : "N/A"}
- Average REM Sleep: ${healthSummary.summary?.avgRemSleepMins ? Math.round(healthSummary.summary.avgRemSleepMins) + " mins" : "N/A"}
- Data Points: ${healthSummary.dataPoints || 0}
`;
    }

    if (sleepArchitecture && sleepArchitecture.length > 0) {
      result += `\n**Recent Sleep Architecture (last ${sleepArchitecture.length} nights):**\n`;
      sleepArchitecture.slice(0, 7).forEach((night: any) => {
        const deepPct = night.deepSleepPercent ? `Deep: ${night.deepSleepPercent}%` : "";
        const remPct = night.remSleepPercent ? `REM: ${night.remSleepPercent}%` : "";
        const lightPct = night.lightSleepPercent ? `Light: ${night.lightSleepPercent}%` : "";
        const eff = night.efficiency ? `Eff: ${night.efficiency}%` : "";
        const metrics = [deepPct, remPct, lightPct, eff].filter(Boolean).join(", ");
        result += `- ${night.date}: ${metrics || "No stage data"}\n`;
      });
    }

    return result || null;
  } catch (error) {
    console.error("Error building HealthKit sleep module:", error);
    return null;
  }
}

// Module F: Heart Rate & HRV Trends
async function buildHeartRateHRVModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    // Calculate date range for last 14 days
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 14);

    const hrData = await ctx.runQuery(api.healthkit.getHeartRateRange, {
      userId: userId as any,
      startDate: startDate.toISOString().split("T")[0],
      endDate: endDate.toISOString().split("T")[0],
    });

    if (!hrData || hrData.length === 0) {
      return "No heart rate data available.";
    }

    // Calculate averages (using snake_case from schema)
    const validHR = hrData.filter((d: any) => d.resting_hr);
    const validHRV = hrData.filter((d: any) => d.hrv_avg);

    const avgRestingHR = validHR.length > 0
      ? Math.round(validHR.reduce((sum: number, d: any) => sum + d.resting_hr, 0) / validHR.length)
      : null;

    const avgHRV = validHRV.length > 0
      ? Math.round(validHRV.reduce((sum: number, d: any) => sum + (d.hrv_avg || 0), 0) / validHRV.length)
      : null;

    let result = `**14-Day Heart Rate Summary:**
- Average Resting HR: ${avgRestingHR ? avgRestingHR + " bpm" : "N/A"}
- Average HRV: ${avgHRV ? avgHRV + " ms" : "N/A"}
- Data Points: ${hrData.length}
`;

    // Add trend info (first week vs last week)
    if (hrData.length >= 7) {
      const firstWeek = hrData.slice(0, 7);
      const lastWeek = hrData.slice(-7);

      const firstWeekHR = firstWeek.filter((d: any) => d.resting_hr);
      const lastWeekHR = lastWeek.filter((d: any) => d.resting_hr);

      if (firstWeekHR.length > 0 && lastWeekHR.length > 0) {
        const avgFirst = firstWeekHR.reduce((s: number, d: any) => s + d.resting_hr, 0) / firstWeekHR.length;
        const avgLast = lastWeekHR.reduce((s: number, d: any) => s + d.resting_hr, 0) / lastWeekHR.length;
        const trend = avgLast < avgFirst ? "decreasing (positive)" : avgLast > avgFirst ? "increasing" : "stable";
        result += `- HR Trend: ${trend}\n`;
      }
    }

    return result;
  } catch (error) {
    console.error("Error building heart rate module:", error);
    return null;
  }
}

// Module G: Activity Data
async function buildActivityDataModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    // Get nap summary (includes activity context)
    const napSummary = await ctx.runQuery(api.physician.getPatientNapSummary, {
      userId: userId as any,
    });

    // Get day type analysis for activity patterns
    const dayTypeAnalysis = await ctx.runQuery(api.physician.getPatientDayTypeAnalysis, {
      userId: userId as any,
    });

    let result = "";

    if (napSummary) {
      result += `**Nap Patterns:**
- Days with Naps: ${napSummary.napDays || 0}/${napSummary.totalDays || 0} days
- Average Naps per Day: ${napSummary.avgNapCount?.toFixed(1) || "0"}
- Average Nap Duration: ${napSummary.avgDuration ? napSummary.avgDuration + " mins" : "N/A"}
- Common Nap Times: ${napSummary.commonTimes?.join(", ") || "N/A"}
`;
    }

    if (dayTypeAnalysis && dayTypeAnalysis.hasData) {
      result += `\n**Day Type Analysis:**
- Total Days: ${dayTypeAnalysis.totalDays || 0}
- Workday Stats: ${dayTypeAnalysis.workdayStats ? `${dayTypeAnalysis.workdayStats.count} days, avg sleep ${dayTypeAnalysis.workdayStats.avgSleepMins ? Math.round(dayTypeAnalysis.workdayStats.avgSleepMins / 60 * 10) / 10 + "h" : "N/A"}` : "N/A"}
- Weekend/Off Stats: ${dayTypeAnalysis.weekendStats ? `${dayTypeAnalysis.weekendStats.count} days, avg sleep ${dayTypeAnalysis.weekendStats.avgSleepMins ? Math.round(dayTypeAnalysis.weekendStats.avgSleepMins / 60 * 10) / 10 + "h" : "N/A"}` : "N/A"}`;

      // Add clinical flags
      if (dayTypeAnalysis.flags && dayTypeAnalysis.flags.length > 0) {
        result += `\n**Clinical Flags:**\n`;
        dayTypeAnalysis.flags.forEach((flag: any) => {
          result += `- [${flag.severity.toUpperCase()}] ${flag.message}\n`;
        });
      }
    }

    return result || "No activity data available.";
  } catch (error) {
    console.error("Error building activity module:", error);
    return null;
  }
}

// Module H: Light Exposure & Circadian
async function buildLightExposureModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    const circadianData = await ctx.runQuery(api.circadian.getCircadianSummary, {
      userId: userId as any,
      days: 14,
    });

    if (!circadianData || !circadianData.hasData) {
      return "No light exposure data available. Requires iOS 17+ for daylight tracking.";
    }

    return `**14-Day Light Exposure Summary:**
- Average Time in Daylight: ${circadianData.avgDaylightMins ? Math.round(circadianData.avgDaylightMins) + " mins" : "N/A"}
- Average Morning Light: ${circadianData.avgMorningLightMins ? Math.round(circadianData.avgMorningLightMins) + " mins" : "N/A"}
- Average Outdoor Workout: ${circadianData.avgOutdoorMins ? Math.round(circadianData.avgOutdoorMins) + " mins" : "N/A"}
- Average Circadian Score: ${circadianData.avgCircadianScore ? circadianData.avgCircadianScore + "/100" : "N/A"}
- Wrist Temp Deviation: ${circadianData.avgTempDeviation ? circadianData.avgTempDeviation.toFixed(2) + "°C" : "N/A"}
- Days With Data: ${circadianData.daysWithData || 0}
- Trend: ${circadianData.trend || "N/A"}`;
  } catch (error) {
    console.error("Error building light exposure module:", error);
    return null;
  }
}

// Module I: Perception Gap Analysis
async function buildPerceptionGapModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    const perceptionGaps = await ctx.runQuery(api.healthkit.getPerceptionGaps, {
      userId: userId as any,
      limit: 14,
    });

    if (!perceptionGaps || perceptionGaps.length === 0) {
      return "No perception gap data available. Requires both sleep log and HealthKit data.";
    }

    // Calculate summary stats
    const overestimate = perceptionGaps.filter((g: any) => g.gap_direction === "overestimate").length;
    const underestimate = perceptionGaps.filter((g: any) => g.gap_direction === "underestimate").length;
    const accurate = perceptionGaps.filter((g: any) => g.gap_direction === "accurate").length;

    const avgGapMins = perceptionGaps.reduce((sum: number, g: any) => sum + (g.gap_minutes || 0), 0) / perceptionGaps.length;

    let biasDirection = "neutral";
    if (overestimate > underestimate + 2) biasDirection = "tends to overestimate sleep";
    else if (underestimate > overestimate + 2) biasDirection = "tends to underestimate sleep";

    return `**Sleep Perception Analysis (${perceptionGaps.length} nights):**
- Overestimated Sleep: ${overestimate} nights
- Underestimated Sleep: ${underestimate} nights
- Accurate (within 30 mins): ${accurate} nights
- Average Gap: ${avgGapMins > 0 ? "+" : ""}${Math.round(avgGapMins)} mins
- Bias Direction: ${biasDirection}
- Accuracy Rate: ${Math.round((accurate / perceptionGaps.length) * 100)}%

**Clinical Note:** ${biasDirection === "tends to overestimate sleep"
  ? "Patient may have sleep state misperception or underestimate actual sleep difficulties."
  : biasDirection === "tends to underestimate sleep"
  ? "Patient may be sleeping better than perceived - consider anxiety or depression screening."
  : "Patient has good sleep perception accuracy."}`;
  } catch (error) {
    console.error("Error building perception gap module:", error);
    return null;
  }
}

// Module J: Temporal Trends (Week 1 vs Week 2)
async function buildTemporalTrendsModule(ctx: ActionCtx, userId: string): Promise<string | null> {
  try {
    const subjectiveSleepData = await ctx.runQuery(api.physician.getSubjectiveSleepQuality, {
      userId: userId as any,
      days: 14,
    });

    if (!subjectiveSleepData || !subjectiveSleepData.dailyData || subjectiveSleepData.dailyData.length < 7) {
      return "Insufficient data for trend analysis. Need at least 7 days.";
    }

    const dailyData = subjectiveSleepData.dailyData;

    // Split into weeks
    const week1 = dailyData.slice(0, 7);
    const week2 = dailyData.slice(7, 14);

    // Calculate week 1 averages
    const week1Quality = week1.filter((d: any) => d.quality !== null);
    const week1AvgQuality = week1Quality.length > 0
      ? week1Quality.reduce((s: number, d: any) => s + d.quality, 0) / week1Quality.length
      : null;

    const week1Duration = week1.filter((d: any) => d.totalSleepMins);
    const week1AvgDuration = week1Duration.length > 0
      ? week1Duration.reduce((s: number, d: any) => s + d.totalSleepMins, 0) / week1Duration.length
      : null;

    // Calculate week 2 averages (if available)
    let week2AvgQuality = null;
    let week2AvgDuration = null;

    if (week2.length > 0) {
      const week2Quality = week2.filter((d: any) => d.quality !== null);
      week2AvgQuality = week2Quality.length > 0
        ? week2Quality.reduce((s: number, d: any) => s + d.quality, 0) / week2Quality.length
        : null;

      const week2Duration = week2.filter((d: any) => d.totalSleepMins);
      week2AvgDuration = week2Duration.length > 0
        ? week2Duration.reduce((s: number, d: any) => s + d.totalSleepMins, 0) / week2Duration.length
        : null;
    }

    let result = `**Temporal Trend Analysis:**

Week 1 (Days 1-7):
- Average Quality: ${week1AvgQuality ? week1AvgQuality.toFixed(1) + "/10" : "N/A"}
- Average Duration: ${week1AvgDuration ? (week1AvgDuration / 60).toFixed(1) + "h" : "N/A"}
`;

    if (week2.length > 0) {
      result += `
Week 2 (Days 6-10):
- Average Quality: ${week2AvgQuality ? week2AvgQuality.toFixed(1) + "/10" : "N/A"}
- Average Duration: ${week2AvgDuration ? (week2AvgDuration / 60).toFixed(1) + "h" : "N/A"}
`;

      // Calculate trends
      if (week1AvgQuality !== null && week2AvgQuality !== null) {
        const qualityTrend = week2AvgQuality - week1AvgQuality;
        const trendText = qualityTrend > 0.5 ? `Improving (+${qualityTrend.toFixed(1)})` : qualityTrend < -0.5 ? `Declining (${qualityTrend.toFixed(1)})` : "Stable";
        result += `\n**Trends:**
- Quality Trend: ${trendText}`;
      }

      if (week1AvgDuration !== null && week2AvgDuration !== null) {
        const durationTrend = (week2AvgDuration - week1AvgDuration) / 60;
        const durationText = durationTrend > 0.25 ? `Increasing (+${durationTrend.toFixed(1)}h)` : durationTrend < -0.25 ? `Decreasing (${durationTrend.toFixed(1)}h)` : "Stable";
        result += `
- Duration Trend: ${durationText}`;
      }
    } else {
      result += "\nWeek 2 data not yet available.";
    }

    return result;
  } catch (error) {
    console.error("Error building temporal trends module:", error);
    return null;
  }
}

// Module definitions registry
const PROMPT_MODULES: Record<string, PromptModule> = {
  demographics: {
    id: "demographics",
    name: "Demographics & Context",
    description: "Patient demographics, age, sex, completion status",
    estimatedTokens: 200,
    enabledByDefault: true,
    build: buildDemographicsModule,
  },
  questionnaire_scores: {
    id: "questionnaire_scores",
    name: "Standardized Questionnaire Scores",
    description: "ISI, PHQ-9, GAD-7, ESS, PSQI, STOP-BANG scores with interpretations",
    estimatedTokens: 400,
    enabledByDefault: true,
    build: buildQuestionnaireScoresModule,
  },
  gateway_triggers: {
    id: "gateway_triggers",
    name: "Gateway Triggers & Risk Flags",
    description: "Triggered clinical gateways (insomnia, OSA, mental health, etc.)",
    estimatedTokens: 150,
    enabledByDefault: true,
    build: buildGatewayTriggersModule,
  },
  sleep_log_full: {
    id: "sleep_log_full",
    name: "Sleep Log Data (Full 14 Days)",
    description: "Complete subjective sleep log with quality, duration, latency",
    estimatedTokens: 800,
    enabledByDefault: true,
    build: buildSleepLogFullModule,
  },
  healthkit_sleep: {
    id: "healthkit_sleep",
    name: "HealthKit Sleep Architecture",
    description: "Wearable sleep stages (deep/REM/light), efficiency, duration",
    estimatedTokens: 400,
    enabledByDefault: true,
    build: buildHealthKitSleepModule,
  },
  heart_rate_hrv: {
    id: "heart_rate_hrv",
    name: "Heart Rate & HRV Trends",
    description: "Resting HR, HRV averages and trends",
    estimatedTokens: 200,
    enabledByDefault: false,
    build: buildHeartRateHRVModule,
  },
  activity_data: {
    id: "activity_data",
    name: "Activity Data",
    description: "Nap patterns, day type analysis, exercise data",
    estimatedTokens: 250,
    enabledByDefault: true,
    build: buildActivityDataModule,
  },
  light_exposure: {
    id: "light_exposure",
    name: "Light Exposure & Circadian",
    description: "Time in daylight, morning/afternoon light, circadian score",
    estimatedTokens: 200,
    enabledByDefault: true,
    build: buildLightExposureModule,
  },
  perception_gap: {
    id: "perception_gap",
    name: "Perception Gap Analysis",
    description: "Comparison of subjective sleep perception vs objective wearable data",
    estimatedTokens: 200,
    enabledByDefault: true,
    build: buildPerceptionGapModule,
  },
  temporal_trends: {
    id: "temporal_trends",
    name: "Temporal Trends",
    description: "Week 1 vs Week 2 comparison, improving/declining metrics",
    estimatedTokens: 200,
    enabledByDefault: true,
    build: buildTemporalTrendsModule,
  },
};

// Get list of all available modules
function getAvailableModules(): Array<{
  id: string;
  name: string;
  description: string;
  estimatedTokens: number;
  enabledByDefault: boolean;
}> {
  return Object.values(PROMPT_MODULES).map(m => ({
    id: m.id,
    name: m.name,
    description: m.description,
    estimatedTokens: m.estimatedTokens,
    enabledByDefault: m.enabledByDefault,
  }));
}

// Build modular analysis prompt
async function buildModularAnalysisPrompt(
  ctx: ActionCtx,
  userId: string,
  enabledModules?: string[]
): Promise<PatientAnalysisPrompt> {
  // Use default modules if none specified
  const modules = enabledModules || DEFAULT_ENABLED_MODULES;

  const sections: string[] = [];
  const modulesUsed: string[] = [];
  let totalEstimatedTokens = 0;

  // Build each enabled module
  for (const moduleId of modules) {
    const module = PROMPT_MODULES[moduleId];
    if (!module) continue;

    try {
      const content = await module.build(ctx, userId);
      if (content) {
        sections.push(`## ${module.name}\n${content}`);
        modulesUsed.push(moduleId);
        totalEstimatedTokens += module.estimatedTokens;
      }
    } catch (error) {
      console.error(`Error building module ${moduleId}:`, error);
    }
  }

  const systemPrompt = `You are a board-certified sleep medicine specialist analyzing a patient's comprehensive 10-day sleep assessment.

Your analysis should be:
- Evidence-based and clinically actionable
- Specific to the patient's profile and data
- Prioritized by clinical significance
- Consider both subjective reports AND objective wearable data when available
- Note any discrepancies between perceived and actual sleep

IMPORTANT: This analysis includes data from ${modulesUsed.length} modules: ${modulesUsed.join(", ")}.

Provide your analysis in JSON format with these exact keys:
{
  "summary": "2-3 sentence clinical summary highlighting the most significant findings",
  "riskFactors": ["array of 3-5 key risk factors identified from the data"],
  "recommendations": ["array of 3-5 evidence-based, prioritized interventions"],
  "dataQuality": "assessment of data completeness (excellent/good/fair/limited)",
  "urgentFlags": ["any findings requiring immediate attention, or empty array if none"]
}`;

  const userPrompt = sections.length > 0
    ? sections.join("\n\n") + "\n\nPlease analyze this patient's comprehensive data and provide your clinical assessment."
    : "Insufficient patient data available for analysis.";

  // Add system prompt tokens to estimate
  const estimatedTokens = Math.ceil((systemPrompt.length + userPrompt.length) / 4);

  return {
    systemPrompt,
    userPrompt,
    estimatedTokens,
    modulesUsed,
  };
}

async function buildAnalysisPrompt(
  ctx: ActionCtx,
  userId: string
): Promise<PatientAnalysisPrompt> {
  // Get patient details
  const patientDetails = await ctx.runQuery(
    api.physician.getPatientDetails,
    { userId: userId as any }
  );

  // Get actual response values
  const allResponses: Array<{ questionId: string; value: string }> = [];
  for (let day = 1; day <= 10; day++) {
    const dayData = await ctx.runQuery(api.physician.getPatientDayData, {
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
  const scores = await ctx.runQuery(api.physician.getQuestionnaireScores, {
    userId: userId as any,
  });

  // Get gateway states from assessment module (returns an object keyed by gateway_id)
  const gatewayStates = await ctx.runQuery(api.assessment.getUserGatewayStates, {
    userId: userId as any,
  });

  // gatewayStates is a Record<gateway_id, {triggered, triggeredAt, evaluationData}>
  const triggeredGateways = Object.entries(gatewayStates || {})
    .filter(([_, state]: [string, any]) => state.triggered)
    .map(([gatewayId]: [string, any]) => gatewayId);

  const systemPrompt = `You are a board-certified sleep medicine specialist analyzing a patient's comprehensive 10-day sleep assessment.

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
- Days Completed: ${patientDetails.completedDays}/10

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
 * Get available analysis modules for the UI
 * Returns list of all modules with their configuration
 */
export const getAvailableAnalysisModules = action({
  args: {},
  returns: v.array(
    v.object({
      id: v.string(),
      name: v.string(),
      description: v.string(),
      estimatedTokens: v.number(),
      enabledByDefault: v.boolean(),
    })
  ),
  handler: async () => {
    return getAvailableModules();
  },
});

/**
 * Preview the analysis prompt without running the LLM
 * Shows exactly what data will be sent for analysis
 * Now supports modular architecture with configurable modules
 */
export const previewAnalysisPrompt = action({
  args: {
    userId: v.id("users"),
    enabledModules: v.optional(v.array(v.string())),
  },
  returns: v.object({
    systemPrompt: v.string(),
    userPrompt: v.string(),
    estimatedTokens: v.number(),
    estimatedCost: v.string(),
    selectedModel: v.string(),
    modelProvider: v.string(),
    modulesUsed: v.array(v.string()),
  }),
  handler: async (ctx, args) => {
    // Use modular prompt builder
    const prompt = await buildModularAnalysisPrompt(ctx, args.userId, args.enabledModules);
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
      modulesUsed: prompt.modulesUsed || [],
    };
  },
});

/**
 * Analyze patient responses using LLM
 * Now uses modular architecture with configurable modules
 */
export const analyzePatientResponses = action({
  args: {
    userId: v.id("users"),
    enabledModules: v.optional(v.array(v.string())),
  },
  returns: v.object({
    summary: v.string(),
    riskFactors: v.array(v.string()),
    recommendations: v.array(v.string()),
    dataQuality: v.optional(v.string()),
    urgentFlags: v.optional(v.array(v.string())),
    modulesUsed: v.array(v.string()),
  }),
  handler: async (ctx, args) => {
    // Use modular prompt builder
    const prompt = await buildModularAnalysisPrompt(ctx, args.userId, args.enabledModules);

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
        dataQuality: result.dataQuality || "unknown",
        urgentFlags: result.urgentFlags || [],
        modulesUsed: prompt.modulesUsed || [],
      };
    } catch (error) {
      console.error("Error analyzing patient responses:", error);
      return {
        summary: "Error analyzing patient data. Please check API key configuration in Settings.",
        riskFactors: [],
        recommendations: [],
        dataQuality: "error",
        urgentFlags: [],
        modulesUsed: prompt.modulesUsed || [],
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
      const dayData = await ctx.runQuery(api.physician.getPatientDayData, {
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
    await ctx.runMutation(api.physician.saveQuestionnaireScore, {
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
      api.physician.getPatientDetails,
      { userId: args.userId }
    );

    // Get questionnaire scores if available
    const scores = await ctx.runQuery(api.physician.getQuestionnaireScores, {
      userId: args.userId,
    });

    const systemPrompt = "You are a sleep medicine expert. Respond only with valid JSON.";

    const userPrompt = `Based on a patient's sleep assessment data, recommend specific interventions.

Patient Information:
- Name: ${patientDetails.name || "Unknown"}
- Total Responses: ${patientDetails.totalResponses}
- Completed Days: ${patientDetails.completedDays}/10

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
// Clinical Reference Data from Peer-Reviewed Literature
// ============================================

/**
 * Returns validated clinical interpretation guidelines for a specific questionnaire
 * All thresholds and interpretations are based on peer-reviewed literature
 */
function getClinicalReferenceForQuestionnaire(questionnaireName: string): string {
  const normalizedName = questionnaireName.toLowerCase();

  // ISI - Insomnia Severity Index
  // Reference: Bastien CH, Vallières A, Morin CM. Validation of the Insomnia Severity Index. Sleep Med. 2001;2(4):297-307
  // Reference: Morin CM, Belleville G, Bélanger L, Ivers H. The Insomnia Severity Index: psychometric indicators to detect insomnia cases and evaluate treatment response. Sleep. 2011;34(5):601-8
  if (normalizedName.includes("isi") || normalizedName.includes("insomnia severity")) {
    return `**INSOMNIA SEVERITY INDEX (ISI) - Clinical Reference**
Source: Bastien et al. (2001), Morin et al. (2011) - Sleep Medicine

**Validated Severity Thresholds:**
- 0-7: No clinically significant insomnia
- 8-14: Subthreshold insomnia (subclinical symptoms)
- 15-21: Clinical insomnia of MODERATE severity
- 22-28: Clinical insomnia of SEVERE severity

**Clinical Significance:**
- The ISI has demonstrated sensitivity to change and is recommended for detecting insomnia cases in clinical and research settings
- A score of 15+ indicates clinical insomnia warranting intervention per DSM-5/ICSD-3 criteria
- A change of ≥6 points is considered clinically meaningful improvement
- The ISI correlates strongly (r=0.65) with polysomnographic sleep efficiency

**Domain Assessment (Questions):**
1-3: Nighttime symptoms (difficulty falling asleep, staying asleep, early awakening)
4: Sleep satisfaction
5: Daytime impairment noticeability
6: Distress/worry about sleep
7: Interference with daily functioning`;
  }

  // PHQ-9 - Patient Health Questionnaire
  // Reference: Kroenke K, Spitzer RL, Williams JB. The PHQ-9: validity of a brief depression severity measure. J Gen Intern Med. 2001;16(9):606-13
  if (normalizedName.includes("phq") || normalizedName.includes("patient health")) {
    return `**PHQ-9 (Patient Health Questionnaire-9) - Clinical Reference**
Source: Kroenke et al. (2001) - Journal of General Internal Medicine

**Validated Severity Thresholds:**
- 0-4: Minimal depression (no treatment indicated)
- 5-9: Mild depression (watchful waiting, consider follow-up)
- 10-14: Moderate depression (treatment plan indicated - therapy and/or medication)
- 15-19: Moderately severe depression (active treatment with pharmacotherapy and/or psychotherapy)
- 20-27: Severe depression (immediate initiation of pharmacotherapy, consider specialty mental health referral)

**Clinical Significance:**
- A score ≥10 has 88% sensitivity and 88% specificity for major depression
- Question 9 (suicidal ideation) requires immediate assessment regardless of total score
- Treatment response is typically defined as ≥50% reduction in PHQ-9 score
- Remission is defined as PHQ-9 score <5

**Risk Assessment:**
- Any positive response to Q9 warrants safety assessment
- Anhedonia (Q1) and depressed mood (Q2) are core symptoms for MDD diagnosis`;
  }

  // GAD-7 - Generalized Anxiety Disorder
  // Reference: Spitzer RL, Kroenke K, Williams JB, Löwe B. A brief measure for assessing generalized anxiety disorder. Arch Intern Med. 2006;166(10):1092-7
  if (normalizedName.includes("gad") || normalizedName.includes("anxiety")) {
    return `**GAD-7 (Generalized Anxiety Disorder-7) - Clinical Reference**
Source: Spitzer et al. (2006) - Archives of Internal Medicine

**Validated Severity Thresholds:**
- 0-4: Minimal anxiety
- 5-9: Mild anxiety
- 10-14: Moderate anxiety (consider treatment)
- 15-21: Severe anxiety (active treatment recommended)

**Clinical Significance:**
- A score ≥10 has 89% sensitivity and 82% specificity for GAD diagnosis
- The GAD-7 is also a good screener for panic disorder, social anxiety, and PTSD
- Consider psychiatric referral for scores ≥15
- Treatment response is typically defined as ≥50% reduction

**Sleep Relevance:**
- Anxiety is bidirectionally related to insomnia
- High arousal from anxiety impairs sleep onset and maintenance
- CBT-I effectiveness may be reduced if GAD is untreated`;
  }

  // ESS - Epworth Sleepiness Scale
  // Reference: Johns MW. A new method for measuring daytime sleepiness: the Epworth sleepiness scale. Sleep. 1991;14(6):540-5
  if (normalizedName.includes("ess") || normalizedName.includes("epworth") || normalizedName.includes("sleepiness")) {
    return `**EPWORTH SLEEPINESS SCALE (ESS) - Clinical Reference**
Source: Johns MW (1991) - Sleep

**Validated Severity Thresholds:**
- 0-7: Normal daytime sleepiness
- 8-9: Average sleepiness (borderline)
- 10-15: Excessive daytime sleepiness (EDS) - mild to moderate
- 16-24: Severe excessive daytime sleepiness

**Clinical Significance:**
- ESS ≥10 indicates clinically significant EDS warranting evaluation
- High ESS in combination with loud snoring suggests OSA evaluation
- ESS >15 may indicate narcolepsy, severe OSA, or other hypersomnia
- Driving safety should be assessed for ESS ≥12

**Differential Diagnosis:**
- Obstructive sleep apnea
- Insufficient sleep syndrome
- Narcolepsy or idiopathic hypersomnia
- Medication side effects
- Shift work disorder`;
  }

  // STOP-BANG - Sleep Apnea Screening
  // Reference: Chung F et al. STOP questionnaire: a tool to screen patients for obstructive sleep apnea. Anesthesiology. 2008;108(5):812-21
  // Reference: Chung F et al. High STOP-Bang score indicates a high probability of obstructive sleep apnoea. Br J Anaesth. 2012;108(5):768-75
  if (normalizedName.includes("stop") || normalizedName.includes("bang") || normalizedName.includes("apnea")) {
    return `**STOP-BANG Questionnaire - Clinical Reference**
Source: Chung et al. (2008, 2012) - Anesthesiology, British Journal of Anaesthesia

**Validated Risk Stratification:**
- 0-2: Low risk for OSA
- 3-4: Intermediate risk for OSA (consider home sleep test)
- 5-8: High risk for OSA (polysomnography recommended)

**Clinical Significance:**
- Score ≥3 has 93% sensitivity for detecting moderate-severe OSA (AHI≥15)
- Score ≥5 has high specificity for severe OSA (AHI≥30)
- Male sex + BMI>35 + score≥2 = very high risk regardless of total
- Used as preoperative screening in anesthesiology guidelines

**Components (STOP-BANG):**
S - Snoring loudly
T - Tiredness/fatigue/sleepiness
O - Observed apneas
P - Pressure (hypertension)
B - BMI >35
A - Age >50
N - Neck circumference >40cm
G - Gender male`;
  }

  // PSQI - Pittsburgh Sleep Quality Index
  // Reference: Buysse DJ, Reynolds CF, Monk TH, Berman SR, Kupfer DJ. The Pittsburgh Sleep Quality Index: a new instrument for psychiatric practice and research. Psychiatry Res. 1989;28(2):193-213
  if (normalizedName.includes("psqi") || normalizedName.includes("pittsburgh")) {
    return `**PITTSBURGH SLEEP QUALITY INDEX (PSQI) - Clinical Reference**
Source: Buysse et al. (1989) - Psychiatry Research

**Validated Severity Thresholds:**
- 0-5: Good sleep quality
- 6-10: Poor sleep quality
- 11-15: Moderate sleep difficulty
- 16-21: Severe sleep difficulty

**Clinical Significance:**
- Global score >5 distinguishes good from poor sleepers with 89.6% sensitivity and 86.5% specificity
- Seven component scores assess: subjective quality, latency, duration, efficiency, disturbances, medication use, daytime dysfunction
- Widely used in sleep research as primary outcome measure

**Component Scores (0-3 each):**
1. Subjective sleep quality
2. Sleep latency
3. Sleep duration
4. Habitual sleep efficiency
5. Sleep disturbances
6. Use of sleep medication
7. Daytime dysfunction`;
  }

  // DBAS-16 - Dysfunctional Beliefs and Attitudes about Sleep
  // Reference: Morin CM, Vallières A, Ivers H. Dysfunctional beliefs and attitudes about sleep (DBAS): validation of a brief version. Sleep. 2007;30(11):1547-54
  if (normalizedName.includes("dbas") || normalizedName.includes("dysfunctional")) {
    return `**DBAS-16 (Dysfunctional Beliefs and Attitudes about Sleep) - Clinical Reference**
Source: Morin et al. (2007) - Sleep

**Validated Interpretation:**
- Higher scores indicate more dysfunctional sleep-related cognitions
- Mean score >4 (on 0-10 scale per item) or total >64/160 suggests significant cognitive distortions
- No strict clinical cutoffs; used to identify CBT-I targets

**Clinical Significance:**
- Identifies maladaptive beliefs that perpetuate insomnia
- Key target for cognitive restructuring in CBT-I
- Changes in DBAS predict treatment response in CBT-I
- Assesses misconceptions about sleep requirements, consequences, and control

**Cognitive Domains:**
- Perceived consequences of insomnia
- Worry about sleep
- Sleep expectations
- Beliefs about medication`;
  }

  // FSS - Fatigue Severity Scale
  // Reference: Krupp LB, LaRocca NG, Muir-Nash J, Steinberg AD. The fatigue severity scale: application to patients with multiple sclerosis and systemic lupus erythematosus. Arch Neurol. 1989;46(10):1121-3
  if (normalizedName.includes("fss") || normalizedName.includes("fatigue severity")) {
    return `**FATIGUE SEVERITY SCALE (FSS) - Clinical Reference**
Source: Krupp et al. (1989) - Archives of Neurology

**Validated Interpretation:**
- Mean score <4: No significant fatigue
- Mean score 4-5: Mild fatigue
- Mean score 5-6: Moderate fatigue
- Mean score ≥6: Severe fatigue

**Clinical Significance:**
- Originally validated in MS and SLE, widely used in sleep medicine
- Mean score ≥4 indicates clinically significant fatigue
- Distinguishes fatigue from sleepiness (different from ESS)
- Assesses functional impact of fatigue on daily activities

**Differential Considerations:**
- Sleep disorders causing fatigue
- Medical conditions (thyroid, anemia, autoimmune)
- Depression and mood disorders
- Chronic fatigue syndrome`;
  }

  // FOSQ-10 - Functional Outcomes of Sleep Questionnaire
  // Reference: Chasens ER, Ratcliffe SJ, Weaver TE. Development of the FOSQ-10: a short version of the Functional Outcomes of Sleep Questionnaire. Sleep. 2009;32(7):915-9
  if (normalizedName.includes("fosq") || normalizedName.includes("functional outcomes")) {
    return `**FOSQ-10 (Functional Outcomes of Sleep Questionnaire) - Clinical Reference**
Source: Chasens et al. (2009) - Sleep

**Validated Interpretation:**
- Score 5-17.5: Normal functional status
- Score 17.5-35: Moderate impairment
- Score 35-50 (lower end): Significant functional impairment
Note: Scoring is REVERSED - lower scores indicate greater impairment

**Clinical Significance:**
- Assesses impact of sleepiness on daily functioning
- Five domains: activity level, vigilance, intimacy, general productivity, social outcomes
- Sensitive to treatment effects in OSA patients on CPAP
- Correlates with quality of life measures

**Domain Assessment:**
- General productivity
- Social outcomes
- Activity level
- Vigilance
- Intimate relationships`;
  }

  // DASS-21 - Depression Anxiety Stress Scales
  // Reference: Lovibond SH, Lovibond PF. Manual for the Depression Anxiety Stress Scales. 2nd ed. Sydney: Psychology Foundation; 1995
  if (normalizedName.includes("dass")) {
    return `**DASS-21 (Depression Anxiety Stress Scales) - Clinical Reference**
Source: Lovibond & Lovibond (1995)

**Validated Severity Thresholds (multiply raw scores by 2 for DASS-21):**

Depression subscale (x2):
- 0-9: Normal
- 10-13: Mild
- 14-20: Moderate
- 21-27: Severe
- 28+: Extremely severe

Anxiety subscale (x2):
- 0-7: Normal
- 8-9: Mild
- 10-14: Moderate
- 15-19: Severe
- 20+: Extremely severe

Stress subscale (x2):
- 0-14: Normal
- 15-18: Mild
- 19-25: Moderate
- 26-33: Severe
- 34+: Extremely severe

**Clinical Significance:**
- Differentiates between depression, physical arousal (anxiety), and psychological tension (stress)
- Does NOT diagnose clinical disorders but indicates symptom severity
- Useful for tracking treatment progress`;
  }

  // Berlin Questionnaire - OSA Risk
  // Reference: Netzer NC, Stoohs RA, Netzer CM, Clark K, Strohl KP. Using the Berlin Questionnaire to identify patients at risk for the sleep apnea syndrome. Ann Intern Med. 1999;131(7):485-91
  if (normalizedName.includes("berlin")) {
    return `**BERLIN QUESTIONNAIRE - Clinical Reference**
Source: Netzer et al. (1999) - Annals of Internal Medicine

**Risk Stratification:**
- 0-1 categories positive: Low risk for OSA
- 2-3 categories positive: High risk for OSA

**Categories:**
Category 1: Snoring behavior (Q1-5)
Category 2: Daytime sleepiness (Q6-9)
Category 3: BMI >30 and/or hypertension

**Clinical Significance:**
- High risk (≥2 categories) has 86% sensitivity for OSA (AHI>5)
- Positive predictive value 89% for respiratory disturbance index >5
- Recommended for primary care OSA screening
- High-risk patients should be referred for sleep study`;
  }

  // BPI - Brief Pain Inventory
  // Reference: Cleeland CS, Ryan KM. Pain assessment: global use of the Brief Pain Inventory. Ann Acad Med Singap. 1994;23(2):129-38
  if (normalizedName.includes("bpi") || normalizedName.includes("brief pain")) {
    return `**BRIEF PAIN INVENTORY (BPI) - Clinical Reference**
Source: Cleeland & Ryan (1994) - Annals of the Academy of Medicine Singapore

**Severity Interpretation (0-10 scales):**
- 0: No pain
- 1-3: Mild pain
- 4-6: Moderate pain
- 7-10: Severe pain

**Subscales:**
- Pain Severity: Average of worst, least, average, and current pain
- Pain Interference: Average of 7 interference items

**Clinical Significance:**
- Pain severity ≥4 typically warrants pain management intervention
- High interference scores indicate significant functional impact
- Chronic pain is strongly associated with insomnia (50-90% comorbidity)
- Pain management often required for successful insomnia treatment

**Sleep Relevance:**
- Pain disrupts sleep architecture
- Sleep deprivation lowers pain threshold
- Bidirectional relationship requires concurrent treatment`;
  }

  // MEDAS - Mediterranean Diet Adherence
  // Reference: Schröder H, Fitó M, Estruch R, et al. A short screener is valid for assessing Mediterranean diet adherence among older Spanish men and women. J Nutr. 2011;141(6):1140-5
  if (normalizedName.includes("medas") || normalizedName.includes("mediterranean")) {
    return `**MEDAS (Mediterranean Diet Adherence Screener) - Clinical Reference**
Source: Schröder et al. (2011) - Journal of Nutrition

**Adherence Interpretation:**
- 0-5: Poor adherence to Mediterranean diet
- 6-8: Moderate adherence
- 9-11: Good adherence
- 12-14: High adherence

**Clinical Significance:**
- Higher Mediterranean diet adherence associated with better sleep quality
- Each point increase associated with reduced insomnia risk
- Anti-inflammatory diet may improve sleep through reduced inflammation
- High adherence linked to reduced risk of obesity, cardiovascular disease

**Key Components:**
- Olive oil as primary fat
- High vegetable/fruit intake
- Fish consumption
- Limited red meat and processed foods
- Moderate wine consumption`;
  }

  // PSAS - Pre-Sleep Arousal Scale
  // Reference: Nicassio PM, Mendlowitz DR, Fussell JJ, Petras L. The phenomenology of the pre-sleep state: the development of the pre-sleep arousal scale. Behav Res Ther. 1985;23(3):263-71
  if (normalizedName.includes("psas") || normalizedName.includes("pre-sleep arousal")) {
    return `**PRE-SLEEP AROUSAL SCALE (PSAS) - Clinical Reference**
Source: Nicassio et al. (1985) - Behaviour Research and Therapy

**Subscales:**
- Cognitive Arousal (8 items, 8-40): Racing thoughts, worry, intrusive cognitions
- Somatic Arousal (8 items, 8-40): Physical tension, heart racing, breathing issues

**Validated Interpretation:**
Cognitive Subscale:
- 8-16: Low cognitive arousal
- 17-24: Mild cognitive arousal
- 25-32: Moderate cognitive arousal
- 33-40: High cognitive arousal

Somatic Subscale:
- 8-16: Low somatic arousal
- 17-24: Mild somatic arousal
- 25-32: Moderate somatic arousal
- 33-40: High somatic arousal

**Clinical Significance:**
- High cognitive arousal strongly associated with sleep onset insomnia
- High somatic arousal may indicate anxiety or medical conditions
- Distinguishes between cognitive and physiological contributors to insomnia
- Used to target relaxation vs cognitive interventions in CBT-I`;
  }

  // MEQ - Morningness-Eveningness Questionnaire
  // Reference: Horne JA, Östberg O. A self-assessment questionnaire to determine morningness-eveningness in human circadian rhythms. Int J Chronobiol. 1976;4(2):97-110
  if (normalizedName.includes("meq") || normalizedName.includes("morningness") || normalizedName.includes("chronotype")) {
    return `**MORNINGNESS-EVENINGNESS QUESTIONNAIRE (MEQ) - Clinical Reference**
Source: Horne & Östberg (1976) - International Journal of Chronobiology

**Validated Chronotype Classification:**
- 16-30: Definite evening type
- 31-41: Moderate evening type
- 42-58: Neither type (intermediate)
- 59-69: Moderate morning type
- 70-86: Definite morning type

**Clinical Significance:**
- Chronotype affects optimal sleep-wake timing
- Evening types at higher risk for social jet lag and sleep problems
- Sleep timing should align with chronotype when possible
- Shift work particularly problematic for morning types

**Treatment Implications:**
- Evening types may benefit from light therapy in morning
- Morning types should avoid late-night activities
- Consider chronotype in scheduling CBT-I sessions`;
  }

  // PROMIS Cognitive Function
  // Reference: Cella D, et al. The Patient-Reported Outcomes Measurement Information System (PROMIS): progress of an NIH Roadmap cooperative group. Value Health. 2007;10 Suppl 2:S9-S21
  if (normalizedName.includes("promis") || normalizedName.includes("cognitive function")) {
    return `**PROMIS COGNITIVE FUNCTION - Clinical Reference**
Source: PROMIS (Patient-Reported Outcomes Measurement Information System) - NIH

**T-Score Interpretation:**
- T-score 50 = population mean
- Each 10 points = 1 standard deviation

Cognitive Function (higher = better):
- T ≥50: Normal cognitive function
- T 40-49: Mild cognitive impairment
- T 30-39: Moderate cognitive impairment
- T <30: Severe cognitive impairment

**Clinical Significance:**
- Assesses mental acuity, concentration, memory
- Sleep disorders commonly impair cognitive function
- CPAP treatment improves PROMIS scores in OSA
- Baseline for tracking cognitive effects of sleep treatment

**Domains Assessed:**
- Mental alertness
- Concentration
- Memory
- Verbal fluency
- Information processing speed`;
  }

  // Sleep Hygiene Index
  // Reference: Mastin DF, Bryson J, Corwyn R. Assessment of sleep hygiene using the Sleep Hygiene Index. J Behav Med. 2006;29(3):223-7
  if (normalizedName.includes("sleep hygiene") || normalizedName.includes("hygiene index")) {
    return `**SLEEP HYGIENE INDEX (SHI) - Clinical Reference**
Source: Mastin et al. (2006) - Journal of Behavioral Medicine

**Validated Interpretation (13 items, 0-52):**
- 0-20: Good sleep hygiene practices
- 21-30: Fair sleep hygiene (room for improvement)
- 31-40: Poor sleep hygiene (significant concerns)
- 41-52: Very poor sleep hygiene (major behavioral changes needed)

**Clinical Significance:**
- Higher scores indicate worse sleep hygiene
- Identifies modifiable behavioral factors affecting sleep
- Foundation for sleep education component of CBT-I
- Correlates with PSQI scores

**Key Sleep Hygiene Domains:**
- Regular sleep schedule
- Bedroom environment (temperature, light, noise)
- Pre-bed activities (screens, caffeine, exercise timing)
- Daytime behaviors affecting sleep
- Bed partner issues`;
  }

  // SWDSQ - Shift Work Disorder Screening Questionnaire
  if (normalizedName.includes("swdsq") || normalizedName.includes("shift work")) {
    return `**SHIFT WORK DISORDER SCREENING - Clinical Reference**
Source: AASM Diagnostic Criteria (ICSD-3)

**Screening Interpretation:**
- Positive screen: Work schedule that overlaps normal sleep time + excessive sleepiness/insomnia + symptoms persist ≥3 months
- High risk indicators: Night shift work, rotating schedules, early morning starts

**Clinical Significance:**
- Shift work disorder affects 10-40% of shift workers
- Associated with increased accident risk, cardiovascular disease, metabolic dysfunction
- Circadian rhythm disorder requiring specialized management
- May require occupational health involvement

**Management Considerations:**
- Strategic light exposure
- Melatonin timing
- Scheduled napping
- Caffeine management
- Schedule optimization when possible`;
  }

  // Default reference for unknown questionnaires
  return `**Clinical Reference for ${questionnaireName}**
Please interpret this score using standard clinical guidelines for this assessment tool.
Severity classification provided: Use the severity level passed to guide interpretation.
Focus on evidence-based recommendations appropriate for the indicated severity level.`;
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
      api.physician.getPatientDetails,
      { userId: args.userId }
    );

    // Build detailed question response summary
    const responsesSummary = args.questionResponses
      .map((r) => `- ${r.questionText}: ${r.responseValue}${r.responseNumber !== undefined ? ` (${r.responseNumber})` : ""}`)
      .join("\n");

    // Get historical scores if available
    const scores = await ctx.runQuery(api.physician.getQuestionnaireScores, {
      userId: args.userId,
    });
    const historicalScores = scores
      .filter((s) => s.questionnaire_name === args.questionnaireName)
      .map((s) => `Score: ${s.score}/${s.max_score} on ${new Date(s.calculated_at).toLocaleDateString()}`);

    // Build questionnaire-specific clinical reference based on peer-reviewed literature
    const clinicalReferences = getClinicalReferenceForQuestionnaire(args.questionnaireName);

    const systemPrompt = `You are an expert sleep medicine clinician reviewing standardized questionnaire results.
Provide detailed, clinically-relevant interpretations that would help a physician understand the patient's condition.
Be specific about what the scores mean clinically and what actions should be considered.

CRITICAL: Use ONLY the validated clinical interpretation guidelines provided below. Do NOT hallucinate severity levels or clinical thresholds.

${clinicalReferences}`;

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

