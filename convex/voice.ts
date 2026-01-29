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

    try {
      const response = await fetch(
        `https://api.elevenlabs.io/v1/text-to-speech/${actualVoiceId}`,
        {
          method: "POST",
          headers: {
            "xi-api-key": elevenLabsKey,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            text: args.text,
            model_id: "eleven_monolingual_v1",
            voice_settings: {
              stability: 0.75,
              similarity_boost: 0.75,
              style: 0.0,
              use_speaker_boost: true,
            },
          }),
        }
      );

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`ElevenLabs API error: ${response.status} - ${errorText}`);
      }

      // Get audio as ArrayBuffer and convert to base64
      const audioBuffer = await response.arrayBuffer();
      const audioBase64 = Buffer.from(audioBuffer).toString("base64");

      return { audioBase64 };
    } catch (error) {
      console.error("ElevenLabs TTS error:", error);
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
