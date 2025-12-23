import { v } from "convex/values";
import { mutation, query, action } from "./_generated/server";
import { api } from "./_generated/api";

/**
 * System Settings Management
 * Handles configuration for AI analysis, API keys, and other system-wide settings
 */

// ============================================
// Setting Keys (Constants)
// ============================================

export const LLM_SETTINGS = {
  PRIMARY_MODEL: "llm_primary_model",
  FALLBACK_MODEL: "llm_fallback_model",
  ANTHROPIC_KEY: "llm_anthropic_key",
  OPENAI_KEY: "llm_openai_key",
  ENABLE_FALLBACK: "llm_enable_fallback",
  SHOW_DEBUG: "llm_show_debug",
} as const;

export const MODEL_OPTIONS = {
  ANTHROPIC: [
    { id: "claude-sonnet-4-20250514", name: "Claude Sonnet 4", provider: "anthropic" },
    { id: "claude-3-5-sonnet-20241022", name: "Claude Sonnet 3.5", provider: "anthropic" },
    { id: "claude-opus-4-20250514", name: "Claude Opus 4", provider: "anthropic" },
  ],
  OPENAI: [
    { id: "gpt-4o", name: "GPT-4o", provider: "openai" },
    { id: "gpt-4o-mini", name: "GPT-4o Mini", provider: "openai" },
  ],
} as const;

// ============================================
// Queries
// ============================================

/**
 * Get all LLM-related settings
 */
export const getLLMSettings = query({
  args: {},
  handler: async (ctx) => {
    const settings = await ctx.db
      .query("system_settings")
      .withIndex("by_category", (q) => q.eq("category", "llm"))
      .collect();

    // Build settings object, masking secrets
    const result: Record<string, string | null> = {};
    for (const setting of settings) {
      if (setting.is_secret && setting.value) {
        // Mask API keys - show only last 4 characters
        result[setting.key] = `...${setting.value.slice(-4)}`;
      } else {
        result[setting.key] = setting.value;
      }
    }

    return {
      settings: result,
      primaryModel: result[LLM_SETTINGS.PRIMARY_MODEL] || "claude-sonnet-4-20250514",
      fallbackModel: result[LLM_SETTINGS.FALLBACK_MODEL] || "gpt-4o",
      hasAnthropicKey: !!settings.find(s => s.key === LLM_SETTINGS.ANTHROPIC_KEY)?.value,
      hasOpenAIKey: !!settings.find(s => s.key === LLM_SETTINGS.OPENAI_KEY)?.value,
      enableFallback: result[LLM_SETTINGS.ENABLE_FALLBACK] === "true",
      showDebug: result[LLM_SETTINGS.SHOW_DEBUG] === "true",
    };
  },
});

/**
 * Get a single setting value (for internal use)
 */
export const getSetting = query({
  args: {
    key: v.string(),
  },
  handler: async (ctx, { key }) => {
    const setting = await ctx.db
      .query("system_settings")
      .withIndex("by_key", (q) => q.eq("key", key))
      .first();

    return setting?.value || null;
  },
});

/**
 * Get LLM configuration for analysis (used by llm.ts)
 * Returns actual API keys (not masked) for internal use only
 */
export const getLLMConfig = query({
  args: {},
  handler: async (ctx) => {
    const settings = await ctx.db
      .query("system_settings")
      .withIndex("by_category", (q) => q.eq("category", "llm"))
      .collect();

    const getValue = (key: string) => settings.find(s => s.key === key)?.value;

    return {
      primaryModel: getValue(LLM_SETTINGS.PRIMARY_MODEL) || "claude-sonnet-4-20250514",
      fallbackModel: getValue(LLM_SETTINGS.FALLBACK_MODEL) || "gpt-4o",
      anthropicKey: getValue(LLM_SETTINGS.ANTHROPIC_KEY) || null,
      openaiKey: getValue(LLM_SETTINGS.OPENAI_KEY) || null,
      enableFallback: getValue(LLM_SETTINGS.ENABLE_FALLBACK) === "true",
    };
  },
});

/**
 * Get available model options for the UI
 */
export const getModelOptions = query({
  args: {},
  handler: async () => {
    return {
      anthropic: MODEL_OPTIONS.ANTHROPIC,
      openai: MODEL_OPTIONS.OPENAI,
      all: [...MODEL_OPTIONS.ANTHROPIC, ...MODEL_OPTIONS.OPENAI],
    };
  },
});

// ============================================
// Mutations
// ============================================

/**
 * Set or update a system setting
 */
export const setSetting = mutation({
  args: {
    key: v.string(),
    value: v.string(),
    category: v.string(),
    description: v.optional(v.string()),
    isSecret: v.optional(v.boolean()),
  },
  handler: async (ctx, { key, value, category, description, isSecret }) => {
    const existing = await ctx.db
      .query("system_settings")
      .withIndex("by_key", (q) => q.eq("key", key))
      .first();

    const now = Date.now();

    if (existing) {
      await ctx.db.patch(existing._id, {
        value,
        updated_at: now,
      });
      return existing._id;
    } else {
      return await ctx.db.insert("system_settings", {
        key,
        value,
        category,
        description,
        is_secret: isSecret ?? false,
        updated_at: now,
      });
    }
  },
});

/**
 * Set the primary LLM model
 */
export const setPrimaryModel = mutation({
  args: {
    modelId: v.string(),
  },
  handler: async (ctx, { modelId }) => {
    return await ctx.runMutation(api.systemSettings.setSetting, {
      key: LLM_SETTINGS.PRIMARY_MODEL,
      value: modelId,
      category: "llm",
      description: "Primary LLM model for AI analysis",
    });
  },
});

/**
 * Set the fallback LLM model
 */
export const setFallbackModel = mutation({
  args: {
    modelId: v.string(),
  },
  handler: async (ctx, { modelId }) => {
    return await ctx.runMutation(api.systemSettings.setSetting, {
      key: LLM_SETTINGS.FALLBACK_MODEL,
      value: modelId,
      category: "llm",
      description: "Fallback LLM model when primary fails",
    });
  },
});

/**
 * Set the Anthropic API key
 */
export const setAnthropicKey = mutation({
  args: {
    apiKey: v.string(),
  },
  handler: async (ctx, { apiKey }) => {
    return await ctx.runMutation(api.systemSettings.setSetting, {
      key: LLM_SETTINGS.ANTHROPIC_KEY,
      value: apiKey,
      category: "llm",
      description: "Anthropic API key for Claude models",
      isSecret: true,
    });
  },
});

/**
 * Set the OpenAI API key
 */
export const setOpenAIKey = mutation({
  args: {
    apiKey: v.string(),
  },
  handler: async (ctx, { apiKey }) => {
    return await ctx.runMutation(api.systemSettings.setSetting, {
      key: LLM_SETTINGS.OPENAI_KEY,
      value: apiKey,
      category: "llm",
      description: "OpenAI API key for GPT models",
      isSecret: true,
    });
  },
});

/**
 * Toggle fallback enablement
 */
export const toggleFallback = mutation({
  args: {
    enabled: v.boolean(),
  },
  handler: async (ctx, { enabled }) => {
    return await ctx.runMutation(api.systemSettings.setSetting, {
      key: LLM_SETTINGS.ENABLE_FALLBACK,
      value: enabled ? "true" : "false",
      category: "llm",
      description: "Enable fallback to secondary model on failure",
    });
  },
});

/**
 * Delete a setting
 */
export const deleteSetting = mutation({
  args: {
    key: v.string(),
  },
  handler: async (ctx, { key }) => {
    const existing = await ctx.db
      .query("system_settings")
      .withIndex("by_key", (q) => q.eq("key", key))
      .first();

    if (existing) {
      await ctx.db.delete(existing._id);
      return true;
    }
    return false;
  },
});

// ============================================
// Actions (for API key testing)
// ============================================

/**
 * Test an Anthropic API key
 */
export const testAnthropicKey = action({
  args: {
    apiKey: v.string(),
  },
  handler: async (_, { apiKey }) => {
    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-3-haiku-20240307", // Use cheapest model for test
          max_tokens: 10,
          messages: [{ role: "user", content: "Hi" }],
        }),
      });

      if (response.ok) {
        return { success: true, message: "API key is valid" };
      } else {
        const error = await response.json();
        return {
          success: false,
          message: error.error?.message || "Invalid API key",
        };
      }
    } catch (error) {
      return {
        success: false,
        message: error instanceof Error ? error.message : "Connection failed",
      };
    }
  },
});

/**
 * Test an OpenAI API key
 */
export const testOpenAIKey = action({
  args: {
    apiKey: v.string(),
  },
  handler: async (_, { apiKey }) => {
    try {
      const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini", // Use cheapest model for test
          max_tokens: 10,
          messages: [{ role: "user", content: "Hi" }],
        }),
      });

      if (response.ok) {
        return { success: true, message: "API key is valid" };
      } else {
        const error = await response.json();
        return {
          success: false,
          message: error.error?.message || "Invalid API key",
        };
      }
    } catch (error) {
      return {
        success: false,
        message: error instanceof Error ? error.message : "Connection failed",
      };
    }
  },
});
