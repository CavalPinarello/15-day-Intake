"use node";

// Node.js process type declaration
declare const process: {
  env: Record<string, string | undefined>;
};

import { action } from "./_generated/server";
import { v } from "convex/values";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";

// ============================================
// Voice Service for Easy Mode
// Proxies calls to OpenAI Whisper and ElevenLabs
// ============================================

// Create OpenAI client for Whisper
function createOpenAI(): OpenAI {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY not configured");
  }
  return new OpenAI({ apiKey });
}

// Create Anthropic client for response parsing
function createAnthropic(): Anthropic {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY not configured");
  }
  return new Anthropic({ apiKey });
}

// ============================================
// Whisper Transcription
// ============================================

export const transcribe = action({
  args: {
    userId: v.string(),
    audioBase64: v.string(),
  },
  handler: async (ctx, args): Promise<{
    transcript: string | null;
    language: string | null;
    duration: number | null;
  }> => {
    const openai = createOpenAI();

    // Decode base64 audio to buffer
    const audioBuffer = Buffer.from(args.audioBase64, "base64");

    // Create a File object for the API
    const audioFile = new File([audioBuffer], "audio.m4a", {
      type: "audio/m4a",
    });

    try {
      const response = await openai.audio.transcriptions.create({
        file: audioFile,
        model: "whisper-1",
        language: "en",
        response_format: "verbose_json",
      });

      return {
        transcript: response.text,
        language: response.language || "en",
        duration: response.duration || null,
      };
    } catch (error) {
      console.error("Whisper transcription error:", error);
      throw new Error(
        `Transcription failed: ${error instanceof Error ? error.message : "Unknown error"}`
      );
    }
  },
});

// ============================================
// ElevenLabs Text-to-Speech
// ============================================

export const synthesize = action({
  args: {
    userId: v.string(),
    text: v.string(),
    voiceId: v.string(),
    speed: v.number(),
  },
  handler: async (ctx, args): Promise<{ audioBase64: string }> => {
    const elevenLabsKey = process.env.ELEVENLABS_API_KEY;
    if (!elevenLabsKey) {
      console.error("[voice:synthesize] ELEVENLABS_API_KEY not configured");
      throw new Error("ELEVENLABS_API_KEY not configured");
    }

    // Map friendly voice names to ElevenLabs voice IDs
    const voiceIdMap: Record<string, string> = {
      rachel: "21m00Tcm4TlvDq8ikWAM", // Rachel - warm, calm
      adam: "pNInz6obpgDQGcFmaJgB", // Adam - clear, friendly
      dorothy: "ThT5KcBeYPX3keUQqHPh", // Dorothy - gentle, reassuring
      default: "21m00Tcm4TlvDq8ikWAM", // Default to Rachel
    };

    const actualVoiceId = voiceIdMap[args.voiceId] || voiceIdMap.default;
    console.log(`[voice:synthesize] Using voice: ${args.voiceId} -> ${actualVoiceId}`);

    try {
      // Use eleven_multilingual_v2 model which is stable and well-supported
      // Note: Speed parameter is not supported in the basic TTS endpoint
      // For speed control, we would need to use the streaming endpoint

      const requestBody = {
        text: args.text,
        model_id: "eleven_multilingual_v2", // Stable, well-supported model
        voice_settings: {
          stability: 0.75,
          similarity_boost: 0.75,
          style: 0.0,
          use_speaker_boost: true,
        },
      };

      console.log(`[voice:synthesize] Calling ElevenLabs API for ${args.text.length} chars`);

      // Request mp3_44100_128 format explicitly via query param
      const response = await fetch(
        `https://api.elevenlabs.io/v1/text-to-speech/${actualVoiceId}?output_format=mp3_44100_128`,
        {
          method: "POST",
          headers: {
            "xi-api-key": elevenLabsKey,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
          },
          body: JSON.stringify(requestBody),
        }
      );

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[voice:synthesize] ElevenLabs API error: ${response.status} - ${errorText}`);
        throw new Error(`ElevenLabs API error: ${response.status} - ${errorText}`);
      }

      // Get audio as ArrayBuffer and convert to base64
      const audioBuffer = await response.arrayBuffer();
      const audioBase64 = Buffer.from(audioBuffer).toString("base64");

      // Log first few bytes to verify it's valid MP3 (should start with FF FB or ID3)
      const firstBytes = Buffer.from(audioBuffer).slice(0, 4);
      console.log(`[voice:synthesize] First 4 bytes: ${firstBytes.toString('hex')} (${audioBuffer.byteLength} total bytes)`);

      console.log(`[voice:synthesize] Success: ${audioBase64.length} base64 chars`);
      return { audioBase64 };
    } catch (error) {
      console.error("[voice:synthesize] TTS error:", error);
      throw new Error(
        `TTS failed: ${error instanceof Error ? error.message : "Unknown error"}`
      );
    }
  },
});

// ============================================
// LLM Response Parsing
// ============================================

export const parseResponse = action({
  args: {
    userId: v.string(),
    transcript: v.string(),
    context: v.object({
      questionId: v.string(),
      questionText: v.string(),
      questionType: v.string(),
      options: v.optional(v.array(v.string())),
      minValue: v.optional(v.number()),
      maxValue: v.optional(v.number()),
    }),
  },
  handler: async (
    ctx,
    args
  ): Promise<{
    valueType: string;
    stringValue: string | null;
    numberValue: number | null;
    booleanValue: boolean | null;
    arrayValue: string[] | null;
    confidence: number;
    alternatives: string[] | null;
  }> => {
    const anthropic = createAnthropic();

    // Build the parsing prompt based on question type
    const systemPrompt = `You are a voice response parser for a sleep health questionnaire.
Parse the user's spoken response into structured data.

Question type: ${args.context.questionType}
Question: ${args.context.questionText}
${args.context.options ? `Options: ${args.context.options.join(", ")}` : ""}
${args.context.minValue !== undefined ? `Min value: ${args.context.minValue}` : ""}
${args.context.maxValue !== undefined ? `Max value: ${args.context.maxValue}` : ""}

Return a JSON object with:
- valueType: "string" | "number" | "boolean" | "time" | "duration" | "array"
- stringValue: string value if applicable (for time, use "HH:mm" format)
- numberValue: numeric value if applicable
- booleanValue: boolean value if applicable
- arrayValue: array of strings if applicable (for multi-select)
- confidence: 0.0 to 1.0 indicating parsing confidence
- alternatives: array of alternative interpretations if confidence < 0.8

Be forgiving of casual speech patterns and variations. For example:
- "yeah", "yep", "uh huh" → boolean true
- "nope", "nah" → boolean false
- "around ten" → number 10
- "about half past ten" → time "22:30"
- "five milligrams of melatonin" → extract medication info`;

    try {
      const response = await anthropic.messages.create({
        model: "claude-3-5-haiku-20241022",
        max_tokens: 500,
        messages: [
          {
            role: "user",
            content: `Parse this spoken response: "${args.transcript}"`,
          },
        ],
        system: systemPrompt,
      });

      // Extract text content from response
      const textContent = response.content.find((c) => c.type === "text");
      if (!textContent || textContent.type !== "text") {
        throw new Error("No text response from LLM");
      }

      // Parse the JSON response
      const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        // If no JSON found, return as string with low confidence
        return {
          valueType: "string",
          stringValue: args.transcript,
          numberValue: null,
          booleanValue: null,
          arrayValue: null,
          confidence: 0.3,
          alternatives: null,
        };
      }

      const parsed = JSON.parse(jsonMatch[0]);

      return {
        valueType: parsed.valueType || "string",
        stringValue: parsed.stringValue || null,
        numberValue: parsed.numberValue || null,
        booleanValue: parsed.booleanValue ?? null,
        arrayValue: parsed.arrayValue || null,
        confidence: parsed.confidence || 0.5,
        alternatives: parsed.alternatives || null,
      };
    } catch (error) {
      console.error("LLM parsing error:", error);

      // Return transcript as-is with low confidence on error
      return {
        valueType: "string",
        stringValue: args.transcript,
        numberValue: null,
        booleanValue: null,
        arrayValue: null,
        confidence: 0.2,
        alternatives: null,
      };
    }
  },
});

// ============================================
// Complex Response Parsing (Medications, etc.)
// ============================================

export const parseMedication = action({
  args: {
    userId: v.string(),
    transcript: v.string(),
    medicationType: v.string(), // "sleep", "prescription", "supplement"
  },
  handler: async (
    ctx,
    args
  ): Promise<{
    medications: Array<{
      name: string;
      dose: string | null;
      category: string | null;
    }>;
    confidence: number;
  }> => {
    const anthropic = createAnthropic();

    const systemPrompt = `You are parsing a voice response about medications taken for sleep.
Medication type context: ${args.medicationType}

Extract medication information from the spoken response.
Return JSON:
{
  "medications": [
    { "name": "medication name", "dose": "dose with units or null", "category": "melatonin|prescription|otc|herbal|cbd" }
  ],
  "confidence": 0.0-1.0
}

Common sleep medications:
- Melatonin (doses: 1mg, 3mg, 5mg, 10mg)
- Ambien/zolpidem
- Lunesta/eszopiclone
- Trazodone
- Benadryl/diphenhydramine
- Valerian root
- Magnesium
- CBD/THC products

Be forgiving of pronunciation variations and casual descriptions.`;

    try {
      const response = await anthropic.messages.create({
        model: "claude-3-5-haiku-20241022",
        max_tokens: 500,
        messages: [
          {
            role: "user",
            content: `Parse these medications: "${args.transcript}"`,
          },
        ],
        system: systemPrompt,
      });

      const textContent = response.content.find((c) => c.type === "text");
      if (!textContent || textContent.type !== "text") {
        throw new Error("No text response from LLM");
      }

      const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return { medications: [], confidence: 0.2 };
      }

      const parsed = JSON.parse(jsonMatch[0]);
      return {
        medications: parsed.medications || [],
        confidence: parsed.confidence || 0.5,
      };
    } catch (error) {
      console.error("Medication parsing error:", error);
      return { medications: [], confidence: 0.1 };
    }
  },
});

export const parseCaffeine = action({
  args: {
    userId: v.string(),
    transcript: v.string(),
  },
  handler: async (
    ctx,
    args
  ): Promise<{
    caffeineItems: Array<{
      type: string;
      quantity: number;
      unit: string | null;
    }>;
    confidence: number;
  }> => {
    const anthropic = createAnthropic();

    const systemPrompt = `You are parsing a voice response about caffeine consumption.

Extract caffeine items from the spoken response.
Return JSON:
{
  "caffeineItems": [
    { "type": "coffee|tea|soda|energy_drink|chocolate", "quantity": number, "unit": "cups|cans|pieces|null" }
  ],
  "confidence": 0.0-1.0
}

Be forgiving of casual speech like "a couple cups of coffee" = 2 cups coffee.`;

    try {
      const response = await anthropic.messages.create({
        model: "claude-3-5-haiku-20241022",
        max_tokens: 500,
        messages: [
          {
            role: "user",
            content: `Parse this caffeine intake: "${args.transcript}"`,
          },
        ],
        system: systemPrompt,
      });

      const textContent = response.content.find((c) => c.type === "text");
      if (!textContent || textContent.type !== "text") {
        throw new Error("No text response from LLM");
      }

      const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return { caffeineItems: [], confidence: 0.2 };
      }

      const parsed = JSON.parse(jsonMatch[0]);
      return {
        caffeineItems: parsed.caffeineItems || [],
        confidence: parsed.confidence || 0.5,
      };
    } catch (error) {
      console.error("Caffeine parsing error:", error);
      return { caffeineItems: [], confidence: 0.1 };
    }
  },
});

export const parseNaps = action({
  args: {
    userId: v.string(),
    transcript: v.string(),
  },
  handler: async (
    ctx,
    args
  ): Promise<{
    naps: Array<{
      startTime: string | null;
      durationMinutes: number;
    }>;
    confidence: number;
  }> => {
    const anthropic = createAnthropic();

    const systemPrompt = `You are parsing a voice response about naps taken during the day.

Extract nap information from the spoken response.
Return JSON:
{
  "naps": [
    { "startTime": "HH:mm or null", "durationMinutes": number }
  ],
  "confidence": 0.0-1.0
}

Be forgiving of casual time descriptions:
- "around 2 in the afternoon" = "14:00"
- "after lunch" = "13:00" (estimate)
- "half an hour" = 30 minutes
- "about an hour" = 60 minutes`;

    try {
      const response = await anthropic.messages.create({
        model: "claude-3-5-haiku-20241022",
        max_tokens: 500,
        messages: [
          {
            role: "user",
            content: `Parse these naps: "${args.transcript}"`,
          },
        ],
        system: systemPrompt,
      });

      const textContent = response.content.find((c) => c.type === "text");
      if (!textContent || textContent.type !== "text") {
        throw new Error("No text response from LLM");
      }

      const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return { naps: [], confidence: 0.2 };
      }

      const parsed = JSON.parse(jsonMatch[0]);
      return {
        naps: parsed.naps || [],
        confidence: parsed.confidence || 0.5,
      };
    } catch (error) {
      console.error("Nap parsing error:", error);
      return { naps: [], confidence: 0.1 };
    }
  },
});

// ============================================
// Check-In Level Parsing (Energy/Mood/Focus)
// ============================================

export const parseCheckInLevel = action({
  args: {
    userId: v.string(),
    transcript: v.string(),
    levelType: v.string(), // "energy" | "mood" | "focus"
  },
  handler: async (
    ctx,
    args
  ): Promise<{
    level: number | null;
    levelLabel: string | null;
    confidence: number;
    alternatives: string[] | null;
  }> => {
    const anthropic = createAnthropic();

    // Define the level schemas based on type
    const levelSchemas: Record<
      string,
      { levels: Array<{ value: number; labels: string[] }>; maxLevel: number }
    > = {
      energy: {
        maxLevel: 6,
        levels: [
          { value: 1, labels: ["exhausted", "dead", "no energy", "completely drained", "burnt out", "sleepingSeal"] },
          { value: 2, labels: ["low", "slow", "tired", "sluggish", "dragging", "barely awake", "turtle"] },
          { value: 3, labels: ["okay", "ok", "fine", "alright", "moderate", "meh", "so-so", "cat"] },
          { value: 4, labels: ["good", "pretty good", "well", "decent", "nice", "positive", "dog"] },
          { value: 5, labels: ["high", "very good", "great", "energetic", "awake", "alert", "ostrich"] },
          { value: 6, labels: ["energized", "amazing", "fantastic", "bouncing", "incredible", "super", "excellent", "rabbit"] },
        ],
      },
      mood: {
        maxLevel: 6,
        levels: [
          { value: 1, labels: ["terrible", "awful", "horrible", "stormy", "worst", "angry", "furious"] },
          { value: 2, labels: ["sad", "down", "low", "depressed", "rainy", "gloomy", "blue", "bad"] },
          { value: 3, labels: ["meh", "neutral", "whatever", "cloudy", "indifferent", "so-so", "okay", "ok", "fine"] },
          { value: 4, labels: ["clearing", "better", "improving", "not bad", "pretty good", "partly sunny", "decent"] },
          { value: 5, labels: ["good", "happy", "sunny", "positive", "nice", "pleasant", "content"] },
          { value: 6, labels: ["amazing", "fantastic", "incredible", "rainbow", "wonderful", "ecstatic", "overjoyed", "great", "excellent"] },
        ],
      },
      focus: {
        maxLevel: 5,
        levels: [
          { value: 1, labels: ["foggy", "can't focus", "scattered", "completely distracted", "brain fog", "confused", "lost"] },
          { value: 2, labels: ["hazy", "distracted", "hard to focus", "struggling", "unfocused"] },
          { value: 3, labels: ["clearing", "getting there", "improving", "okay", "ok", "moderate", "so-so"] },
          { value: 4, labels: ["clear", "focused", "good", "sharp", "attentive", "concentrated"] },
          { value: 5, labels: ["crystal", "crystal clear", "laser", "perfect", "amazing", "incredible", "super focused", "in the zone", "excellent"] },
        ],
      },
    };

    const schema = levelSchemas[args.levelType];
    if (!schema) {
      return {
        level: null,
        levelLabel: null,
        confidence: 0.0,
        alternatives: null,
      };
    }

    // First try simple keyword matching
    const normalizedTranscript = args.transcript.toLowerCase().trim();

    // Check for numeric input (e.g., "3", "level 4", "four")
    const numberWords: Record<string, number> = {
      one: 1, two: 2, three: 3, four: 4, five: 5, six: 6,
      "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6,
    };

    for (const [word, num] of Object.entries(numberWords)) {
      if (normalizedTranscript.includes(word) && num <= schema.maxLevel) {
        const matchedLevel = schema.levels.find((l) => l.value === num);
        return {
          level: num,
          levelLabel: matchedLevel?.labels[0] || null,
          confidence: 0.9,
          alternatives: null,
        };
      }
    }

    // Check for keyword matches
    for (const levelDef of schema.levels) {
      for (const label of levelDef.labels) {
        if (normalizedTranscript.includes(label)) {
          return {
            level: levelDef.value,
            levelLabel: label,
            confidence: 0.9,
            alternatives: null,
          };
        }
      }
    }

    // If no direct match, use LLM for fuzzy matching
    const systemPrompt = `You are parsing a voice response about ${args.levelType} level.

The user is describing their ${args.levelType} on a scale of 1-${schema.maxLevel}.

Level definitions:
${schema.levels.map((l) => `Level ${l.value}: ${l.labels.slice(0, 3).join(", ")}`).join("\n")}

Return JSON:
{
  "level": number (1-${schema.maxLevel}),
  "levelLabel": "the best matching label",
  "confidence": 0.0-1.0,
  "alternatives": ["other possible interpretations"] or null
}

Be forgiving of casual speech. If they say something positive/high, lean toward higher levels.
If they say something negative/low, lean toward lower levels.`;

    try {
      const response = await anthropic.messages.create({
        model: "claude-3-5-haiku-20241022",
        max_tokens: 200,
        messages: [
          {
            role: "user",
            content: `Parse this ${args.levelType} level: "${args.transcript}"`,
          },
        ],
        system: systemPrompt,
      });

      const textContent = response.content.find((c) => c.type === "text");
      if (!textContent || textContent.type !== "text") {
        return {
          level: null,
          levelLabel: null,
          confidence: 0.2,
          alternatives: null,
        };
      }

      const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return {
          level: null,
          levelLabel: null,
          confidence: 0.2,
          alternatives: null,
        };
      }

      const parsed = JSON.parse(jsonMatch[0]);

      // Validate level is in range
      const parsedLevel = parsed.level;
      if (typeof parsedLevel !== "number" || parsedLevel < 1 || parsedLevel > schema.maxLevel) {
        return {
          level: null,
          levelLabel: null,
          confidence: 0.2,
          alternatives: parsed.alternatives || null,
        };
      }

      return {
        level: parsedLevel,
        levelLabel: parsed.levelLabel || null,
        confidence: parsed.confidence || 0.7,
        alternatives: parsed.alternatives || null,
      };
    } catch (error) {
      console.error("Check-in level parsing error:", error);
      return {
        level: null,
        levelLabel: null,
        confidence: 0.1,
        alternatives: null,
      };
    }
  },
});

// ============================================
// Conversational Assessment Parsing
// ============================================

/**
 * Parse a conversational response for the 10-day assessment journey.
 * This is more sophisticated than parseResponse - it handles:
 * - Multiple questions mapped to a single conversational prompt
 * - Gateway trigger detection
 * - Contextual understanding of the conversation flow
 */
export const parseConversationalResponse = action({
  args: {
    userId: v.string(),
    transcript: v.string(),
    questionIds: v.array(v.string()),
    expectedType: v.string(), // Expected answer type from ConversationalPrompt
    context: v.object({
      spokenPrompt: v.string(),
      dayNumber: v.number(),
      sectionTitle: v.optional(v.string()),
      previousAnswers: v.optional(v.array(v.object({
        questionId: v.string(),
        value: v.any(),
      }))),
      validationRules: v.optional(v.object({
        minValue: v.optional(v.number()),
        maxValue: v.optional(v.number()),
        requiredKeywords: v.optional(v.array(v.string())),
        acceptableOptions: v.optional(v.array(v.string())),
      })),
      isGateway: v.optional(v.boolean()),
      gatewayType: v.optional(v.string()),
    }),
  },
  handler: async (
    ctx,
    args
  ): Promise<{
    values: Record<string, unknown>;
    confidence: number;
    clarificationNeeded: string | null;
    triggersGateway: boolean;
    gatewayType: string | null;
    displayValue: string | null;
  }> => {
    const anthropic = createAnthropic();

    // Build comprehensive parsing prompt
    const systemPrompt = buildConversationalParsingPrompt(args.expectedType, args.context);

    try {
      const response = await anthropic.messages.create({
        model: "claude-3-5-haiku-20241022",
        max_tokens: 800,
        messages: [
          {
            role: "user",
            content: `The user was asked: "${args.context.spokenPrompt}"

Their spoken response: "${args.transcript}"

Question IDs to map: ${args.questionIds.join(", ")}
Expected answer type: ${args.expectedType}
${args.context.isGateway ? `This is a GATEWAY question for: ${args.context.gatewayType}` : ""}`,
          },
        ],
        system: systemPrompt,
      });

      const textContent = response.content.find((c) => c.type === "text");
      if (!textContent || textContent.type !== "text") {
        throw new Error("No text response from LLM");
      }

      // Parse the JSON response
      const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return {
          values: {},
          confidence: 0.3,
          clarificationNeeded: "I couldn't quite understand that. Could you rephrase?",
          triggersGateway: false,
          gatewayType: null,
          displayValue: args.transcript,
        };
      }

      const parsed = JSON.parse(jsonMatch[0]);

      // Map values to question IDs
      const values: Record<string, unknown> = {};
      const parsedValue = parsed.value ?? parsed.values;

      // If single value, apply to all question IDs
      if (typeof parsedValue !== "object" || parsedValue === null) {
        for (const qId of args.questionIds) {
          values[qId] = parsedValue;
        }
      } else if (Array.isArray(parsedValue)) {
        // Array value - apply to first question ID (for multi-select)
        if (args.questionIds.length > 0) {
          values[args.questionIds[0]] = parsedValue;
        }
      } else {
        // Object with multiple values - map directly
        for (const qId of args.questionIds) {
          if (parsedValue[qId] !== undefined) {
            values[qId] = parsedValue[qId];
          } else {
            // Try to use the first value if single mapped
            const firstValue = Object.values(parsedValue)[0];
            values[qId] = firstValue;
          }
        }
      }

      // Detect gateway triggers
      const triggersGateway = detectGatewayTrigger(
        args.expectedType,
        parsedValue,
        args.context.isGateway,
        args.context.gatewayType
      );

      return {
        values,
        confidence: parsed.confidence ?? 0.7,
        clarificationNeeded: parsed.clarificationNeeded || null,
        triggersGateway,
        gatewayType: triggersGateway ? args.context.gatewayType || null : null,
        displayValue: parsed.displayValue || formatDisplayValue(parsedValue, args.expectedType),
      };
    } catch (error) {
      console.error("Conversational parsing error:", error);
      return {
        values: {},
        confidence: 0.2,
        clarificationNeeded: "I had trouble understanding. Could you say that again?",
        triggersGateway: false,
        gatewayType: null,
        displayValue: null,
      };
    }
  },
});

/**
 * Build parsing prompt based on expected answer type
 */
function buildConversationalParsingPrompt(
  expectedType: string,
  context: {
    spokenPrompt: string;
    dayNumber: number;
    sectionTitle?: string;
    validationRules?: {
      minValue?: number;
      maxValue?: number;
      requiredKeywords?: string[];
      acceptableOptions?: string[];
    };
  }
): string {
  const basePrompt = `You are a voice response parser for Zoe, an AI sleep assessment assistant.
You're parsing responses from a conversational sleep health assessment.

Context:
- Day ${context.dayNumber} of a 10-day assessment
${context.sectionTitle ? `- Section: ${context.sectionTitle}` : ""}

Your task: Parse the user's spoken response into structured data that maps to questionnaire fields.

IMPORTANT GUIDELINES:
1. Be VERY forgiving of casual speech, filler words, and natural conversation patterns
2. Extract the core meaning even from rambling responses
3. If the answer is ambiguous, set confidence lower and suggest clarification
4. For yes/no questions, map affirmative language to true, negative to false
5. For scales, map descriptive words to numbers (e.g., "terrible" = 1, "great" = 8-10)
6. For time questions, convert to 24-hour format (HH:mm)
7. For duration questions, convert to minutes`;

  const typeSpecificPrompts: Record<string, string> = {
    yesNo: `
Return JSON:
{
  "value": boolean,
  "confidence": 0.0-1.0,
  "displayValue": "Yes" or "No",
  "clarificationNeeded": null or "specific clarification question"
}

Map these to TRUE: yes, yeah, yep, uh huh, definitely, sometimes, occasionally, I do, I have
Map these to FALSE: no, nope, nah, never, not really, I don't, I haven't`,

    yesNoDontKnow: `
Return JSON:
{
  "value": boolean or "dontknow",
  "confidence": 0.0-1.0,
  "displayValue": "Yes", "No", or "Don't know",
  "clarificationNeeded": null or "specific clarification question"
}

Map "not sure", "I don't know", "maybe", "hard to say" to "dontknow"`,

    scale1to10: `
Return JSON:
{
  "value": number (1-10),
  "confidence": 0.0-1.0,
  "displayValue": "X out of 10",
  "clarificationNeeded": null or "specific clarification question"
}

Word mappings:
- terrible, awful, horrible = 1-2
- bad, poor = 3-4
- okay, so-so, fair = 5
- decent, not bad = 6
- good, pretty good = 7
- very good, great = 8
- excellent, amazing = 9
- perfect = 10`,

    scale0to4: `
Return JSON:
{
  "value": number (0-4),
  "confidence": 0.0-1.0,
  "displayValue": severity label,
  "clarificationNeeded": null or "specific clarification question"
}

Severity scale (ISI):
0 = None, not at all, no problem
1 = Mild, a little, slight
2 = Moderate, somewhat, fair amount
3 = Severe, quite a bit, a lot
4 = Very severe, extremely, terrible`,

    scale0to3: `
Return JSON:
{
  "value": number (0-3),
  "confidence": 0.0-1.0,
  "displayValue": frequency label,
  "clarificationNeeded": null or "specific clarification question"
}

Frequency scale (PHQ-9/GAD-7):
0 = Not at all, never, rarely
1 = Several days, sometimes, occasionally
2 = More than half the days, often, frequently
3 = Nearly every day, always, all the time`,

    frequency: `
Return JSON:
{
  "value": "never" | "sometimes" | "often" | "always",
  "confidence": 0.0-1.0,
  "displayValue": the matched frequency,
  "clarificationNeeded": null
}`,

    time: `
Return JSON:
{
  "value": "HH:mm" (24-hour format),
  "confidence": 0.0-1.0,
  "displayValue": "XX:XX AM/PM",
  "clarificationNeeded": null or "specific clarification question"
}

Examples:
- "around ten thirty" → "22:30" (assume PM for bedtime)
- "about 7 in the morning" → "07:00"
- "midnight" → "00:00"
- "half past eleven" → "23:30" (assume PM)`,

    duration: `
Return JSON:
{
  "value": number (total minutes),
  "confidence": 0.0-1.0,
  "displayValue": "X hours Y minutes" or "X minutes",
  "clarificationNeeded": null or "specific clarification question"
}

Examples:
- "about an hour" → 60
- "half an hour" → 30
- "maybe 20 minutes" → 20
- "an hour and a half" → 90
- "like 45 minutes to an hour" → 52 (average)`,

    number: `
Return JSON:
{
  "value": number,
  "confidence": 0.0-1.0,
  "displayValue": "X",
  "clarificationNeeded": null
}

Extract the numeric value. Handle word numbers (one, two, three, etc.)`,

    singleChoice: `
Return JSON:
{
  "value": "matched option",
  "confidence": 0.0-1.0,
  "displayValue": "matched option",
  "clarificationNeeded": null
}

${context.validationRules?.acceptableOptions ? `Options: ${context.validationRules.acceptableOptions.join(", ")}` : ""}
Match the user's response to the closest option.`,

    multipleChoice: `
Return JSON:
{
  "value": ["option1", "option2", ...],
  "confidence": 0.0-1.0,
  "displayValue": "Option1, Option2",
  "clarificationNeeded": null
}

${context.validationRules?.acceptableOptions ? `Options: ${context.validationRules.acceptableOptions.join(", ")}` : ""}
Extract all mentioned options.`,

    freeText: `
Return JSON:
{
  "value": "cleaned up transcript",
  "confidence": 0.9,
  "displayValue": "summary of response",
  "clarificationNeeded": null
}

Clean up filler words but preserve meaning.`,

    confirmation: `
Return JSON:
{
  "value": boolean,
  "confidence": 0.0-1.0,
  "displayValue": "Confirmed" or "Changed",
  "clarificationNeeded": null
}

TRUE for: yes, correct, that's right, exactly, confirmed
FALSE for: no, wrong, not quite, change that`,
  };

  const typePrompt = typeSpecificPrompts[expectedType] || typeSpecificPrompts.freeText;

  return `${basePrompt}

Expected answer type: ${expectedType}
${typePrompt}

${context.validationRules?.minValue !== undefined ? `Minimum value: ${context.validationRules.minValue}` : ""}
${context.validationRules?.maxValue !== undefined ? `Maximum value: ${context.validationRules.maxValue}` : ""}`;
}

/**
 * Detect if a response triggers a gateway condition
 */
function detectGatewayTrigger(
  expectedType: string,
  value: unknown,
  isGateway?: boolean,
  gatewayType?: string
): boolean {
  if (!isGateway || !gatewayType) {
    return false;
  }

  // Gateway triggers based on type
  switch (gatewayType) {
    case "insomnia":
      // Trigger if they report sleep problems (yes to difficulty sleeping)
      if (expectedType === "yesNo" || expectedType === "yesNoDontKnow") {
        return value === true;
      }
      // Or if they rate sleep quality poorly
      if (expectedType === "scale1to10" && typeof value === "number") {
        return value <= 5;
      }
      break;

    case "sleep_apnea":
    case "osa":
      // Trigger if they report snoring, witnessed apneas, etc.
      if (expectedType === "yesNo") {
        return value === true;
      }
      break;

    case "mental_health":
      // Trigger on positive responses to mood/anxiety questions
      if (expectedType === "yesNo") {
        return value === true;
      }
      if (expectedType === "scale0to3" && typeof value === "number") {
        return value >= 1; // Any frequency > "not at all"
      }
      break;

    case "pain":
      // Trigger if they report chronic pain
      if (expectedType === "yesNo") {
        return value === true;
      }
      break;

    case "prostate":
      // Trigger for nocturia frequency
      if (expectedType === "number" && typeof value === "number") {
        return value >= 2; // 2+ bathroom visits
      }
      break;

    case "excessive_sleepiness":
      // Trigger for daytime sleepiness
      if (expectedType === "yesNo") {
        return value === true;
      }
      if (expectedType === "scale1to10" && typeof value === "number") {
        return value >= 7; // High sleepiness
      }
      break;
  }

  return false;
}

/**
 * Format a display value for confirmation
 */
function formatDisplayValue(value: unknown, expectedType: string): string | null {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === "boolean") {
    return value ? "Yes" : "No";
  }

  if (typeof value === "number") {
    if (expectedType === "duration") {
      const hours = Math.floor(value / 60);
      const mins = value % 60;
      if (hours > 0) {
        return mins > 0 ? `${hours}h ${mins}m` : `${hours} hours`;
      }
      return `${mins} minutes`;
    }
    if (expectedType.startsWith("scale")) {
      return `${value}`;
    }
    return `${value}`;
  }

  if (typeof value === "string") {
    return value;
  }

  if (Array.isArray(value)) {
    return value.join(", ");
  }

  return JSON.stringify(value);
}

// ============================================
// ElevenLabs Conversational AI
// ============================================

export const getConversationSignedUrl = action({
  args: {
    userId: v.string(),
    agentId: v.string(),
  },
  handler: async (ctx, args): Promise<{ signedUrl: string }> => {
    const elevenLabsKey = process.env.ELEVENLABS_API_KEY;
    if (!elevenLabsKey) {
      throw new Error("ELEVENLABS_API_KEY not configured");
    }

    try {
      // Get signed URL from ElevenLabs for WebSocket connection
      const response = await fetch(
        `https://api.elevenlabs.io/v1/convai/conversation/get_signed_url?agent_id=${args.agentId}`,
        {
          method: "GET",
          headers: {
            "xi-api-key": elevenLabsKey,
          },
        }
      );

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[voice:getConversationSignedUrl] ElevenLabs API error: ${response.status} - ${errorText}`);
        throw new Error(`ElevenLabs API error: ${response.status}`);
      }

      const data = await response.json();

      if (!data.signed_url) {
        throw new Error("No signed URL in response");
      }

      console.log(`[voice:getConversationSignedUrl] Got signed URL for agent ${args.agentId}`);
      return { signedUrl: data.signed_url };
    } catch (error) {
      console.error("[voice:getConversationSignedUrl] Error:", error);
      throw new Error(
        `Failed to get conversation URL: ${error instanceof Error ? error.message : "Unknown error"}`
      );
    }
  },
});
