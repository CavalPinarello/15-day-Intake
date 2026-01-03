/**
 * Profile Response Injection
 *
 * Auto-injects demographic responses (D2, D4, D5, D6) from user profile
 * to ensure clinical scoring works without asking redundant questions.
 * Also injects derived STOP-BANG responses (SB_5, SB_6, SB_8).
 */

import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

/**
 * Inject demographic responses from user profile into user_assessment_responses.
 * Called when:
 * 1. User starts Day 1 assessment
 * 2. User updates profile in Settings
 *
 * This ensures STOP-BANG and Berlin scoring have the demographic data they need
 * without asking the user to re-enter information from onboarding.
 */
export const injectDemographicResponses = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.optional(v.number()),
  },
  returns: v.object({
    injectedCount: v.number(),
    skippedCount: v.number(),
    details: v.array(v.object({
      questionId: v.string(),
      action: v.string(), // "inserted", "updated", "skipped"
      reason: v.optional(v.string()),
    })),
  }),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    const now = Date.now();
    const dayNumber = args.dayNumber ?? 1;
    const details: Array<{ questionId: string; action: string; reason?: string }> = [];
    let injectedCount = 0;
    let skippedCount = 0;

    // Helper function to upsert a profile-sourced response
    async function upsertProfileResponse(
      questionId: string,
      responseValue?: string,
      responseNumber?: number
    ): Promise<void> {
      // Check if user-entered response already exists (don't overwrite)
      const existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", questionId)
        )
        .first();

      if (existing) {
        // Only update if it's a profile/derived response (not user-entered)
        if (existing.response_source === "profile" || existing.response_source === "derived") {
          await ctx.db.patch(existing._id, {
            response_value: responseValue,
            response_number: responseNumber,
            updated_at: now,
          });
          details.push({ questionId, action: "updated", reason: "profile response updated" });
          injectedCount++;
        } else {
          // User-entered response exists, don't overwrite
          details.push({ questionId, action: "skipped", reason: "user-entered response exists" });
          skippedCount++;
        }
      } else {
        // Insert new response
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: questionId,
          response_value: responseValue,
          response_number: responseNumber,
          day_number: dayNumber,
          response_source: "profile",
          is_derived: false,
          created_at: now,
          updated_at: now,
        });
        details.push({ questionId, action: "inserted" });
        injectedCount++;
      }
    }

    // Helper function to upsert a derived response
    async function upsertDerivedResponse(
      questionId: string,
      responseValue: string,
      responseNumber: number,
      derivedFrom: string
    ): Promise<void> {
      const existing = await ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", questionId)
        )
        .first();

      if (existing) {
        if (existing.response_source === "profile" || existing.response_source === "derived") {
          await ctx.db.patch(existing._id, {
            response_value: responseValue,
            response_number: responseNumber,
            is_derived: true,
            derived_from_question_id: derivedFrom,
            updated_at: now,
          });
          details.push({ questionId, action: "updated", reason: "derived response updated" });
          injectedCount++;
        } else {
          details.push({ questionId, action: "skipped", reason: "user-entered response exists" });
          skippedCount++;
        }
      } else {
        await ctx.db.insert("user_assessment_responses", {
          user_id: args.userId,
          question_id: questionId,
          response_value: responseValue,
          response_number: responseNumber,
          day_number: dayNumber,
          response_source: "derived",
          is_derived: true,
          derived_from_question_id: derivedFrom,
          created_at: now,
          updated_at: now,
        });
        details.push({ questionId, action: "inserted" });
        injectedCount++;
      }
    }

    // === Inject D2: Date of Birth (from birth_year) ===
    if (user.birth_year && user.birth_year > 1900 && user.birth_year < new Date().getFullYear()) {
      // Store as YYYY-01-01 format (we only have year, so use Jan 1)
      const dobString = `${user.birth_year}-01-01`;
      await upsertProfileResponse("D2", dobString);
    } else {
      details.push({ questionId: "D2", action: "skipped", reason: "invalid birth_year" });
      skippedCount++;
    }

    // === Inject D4: Sex (from gender) ===
    if (user.gender && user.gender.trim() !== "" && user.gender.toLowerCase() !== "prefer not to say") {
      // Capitalize first letter to match expected format (Male, Female, Other)
      const genderValue = user.gender.charAt(0).toUpperCase() + user.gender.slice(1).toLowerCase();
      await upsertProfileResponse("D4", genderValue);
    } else {
      details.push({ questionId: "D4", action: "skipped", reason: "missing or declined gender" });
      skippedCount++;
    }

    // === Inject D5: Height (from height_cm) ===
    if (user.height_cm && user.height_cm >= 100 && user.height_cm <= 250) {
      await upsertProfileResponse("D5", undefined, user.height_cm);
    } else {
      details.push({ questionId: "D5", action: "skipped", reason: "invalid height_cm" });
      skippedCount++;
    }

    // === Inject D6: Weight (from weight_kg) ===
    if (user.weight_kg && user.weight_kg >= 30 && user.weight_kg <= 300) {
      await upsertProfileResponse("D6", undefined, user.weight_kg);
    } else {
      details.push({ questionId: "D6", action: "skipped", reason: "invalid weight_kg" });
      skippedCount++;
    }

    // === Inject Derived STOP-BANG Responses ===

    // SB_5: BMI > 35?
    if (user.height_cm && user.weight_kg && user.height_cm > 0) {
      const heightM = user.height_cm / 100;
      const bmi = user.weight_kg / (heightM * heightM);
      const bmiOver35 = bmi > 35;
      await upsertDerivedResponse(
        "SB_5",
        bmiOver35 ? "Yes" : "No",
        bmiOver35 ? 1 : 0,
        "D5,D6"
      );
    }

    // SB_6: Age > 50?
    if (user.birth_year && user.birth_year > 1900) {
      const currentYear = new Date().getFullYear();
      const age = currentYear - user.birth_year;
      const ageOver50 = age > 50;
      await upsertDerivedResponse(
        "SB_6",
        ageOver50 ? "Yes" : "No",
        ageOver50 ? 1 : 0,
        "D2"
      );
    }

    // SB_8: Gender = Male?
    if (user.gender) {
      const isMale = user.gender.toLowerCase() === "male";
      await upsertDerivedResponse(
        "SB_8",
        isMale ? "Yes" : "No",
        isMale ? 1 : 0,
        "D4"
      );
    }

    // === Derive STOP-BANG answers from core questionnaire responses ===
    // These questions were asked during Days 1-5 as gateway triggers or core assessment

    // Helper to get a user's response
    const getResponse = async (questionId: string) => {
      return ctx.db
        .query("user_assessment_responses")
        .withIndex("by_user_question", (q) =>
          q.eq("user_id", args.userId).eq("question_id", questionId)
        )
        .first();
    };

    // SB_1: Snore loudly? (from Q19 gateway)
    const q19 = await getResponse("19");
    if (q19?.response_value) {
      const value = q19.response_value.toLowerCase();
      const snoresLoudly = value === "yes" || value === "sometimes";
      await upsertDerivedResponse(
        "SB_1",
        snoresLoudly ? "Yes" : "No",
        snoresLoudly ? 1 : 0,
        "19"
      );
    }

    // SB_2: Tired during day? (from Q17 gateway - 1-10 scale)
    const q17 = await getResponse("17");
    if (q17?.response_number !== undefined) {
      const isTired = q17.response_number >= 5;
      await upsertDerivedResponse(
        "SB_2",
        isTired ? "Yes" : "No",
        isTired ? 1 : 0,
        "17"
      );
    }

    // SB_3: Observed stop breathing? (from Q20 gateway)
    const q20 = await getResponse("20");
    if (q20?.response_value) {
      const observedApnea = q20.response_value.toLowerCase() === "yes";
      await upsertDerivedResponse(
        "SB_3",
        observedApnea ? "Yes" : "No",
        observedApnea ? 1 : 0,
        "20"
      );
    }

    // SB_4: High blood Pressure? (from Q27 core Day 4)
    const q27 = await getResponse("27");
    if (q27?.response_value) {
      const hasHighBP = q27.response_value.toLowerCase() === "yes";
      await upsertDerivedResponse(
        "SB_4",
        hasHighBP ? "Yes" : "No",
        hasHighBP ? 1 : 0,
        "27"
      );
    }

    // SB_7: Neck > 40cm? (from Q21 core Day 4)
    const q21 = await getResponse("21");
    if (q21?.response_number !== undefined) {
      const neckOver40 = q21.response_number > 40;
      await upsertDerivedResponse(
        "SB_7",
        neckOver40 ? "Yes" : "No",
        neckOver40 ? 1 : 0,
        "21"
      );
    }

    // Log STOP-BANG derivation summary
    const stopBangDerived = details.filter(d => d.questionId.startsWith("SB_") && d.action !== "skipped");
    console.log(`[profileResponses] Injected ${injectedCount} responses, skipped ${skippedCount} for user ${args.userId}`);
    console.log(`[profileResponses] STOP-BANG derived: ${stopBangDerived.map(d => `${d.questionId}=${d.action}`).join(", ") || "none"}`);
    console.log(`[profileResponses] Full details: ${JSON.stringify(details.filter(d => d.questionId.startsWith("SB_")))}`);

    return { injectedCount, skippedCount, details };
  },
});

/**
 * Check if demographic responses need to be injected for a user.
 * Returns true if profile has data but responses don't exist yet.
 */
export const needsDemographicInjection = query({
  args: {
    userId: v.id("users"),
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return false;

    // Check if profile has demographic data
    const hasProfileData =
      (user.birth_year && user.birth_year > 1900) ||
      (user.gender && user.gender.trim() !== "") ||
      (user.height_cm && user.height_cm > 0) ||
      (user.weight_kg && user.weight_kg > 0);

    if (!hasProfileData) return false;

    // Check if D2 response exists (use as proxy for all demographics)
    const d2Response = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D2")
      )
      .first();

    return !d2Response;
  },
});
