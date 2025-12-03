import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";
import { validatePhysicianRole, validateIOSSession } from "./auth";

// ============================================
// Question Definitions - Single Source of Truth
// ============================================

// Stanford Sleep Log questions (SL_ prefix - used by Watch quick log)
const SLEEP_LOG_QUESTIONS: Record<string, { text: string; type: string }> = {
  // Watch/iPhone quick sleep log (SL_ prefix)
  "SL_BEDTIME": { text: "What time did you go to bed last night?", type: "time" },
  "SL_ASLEEP_TIME": { text: "What time did you fall asleep?", type: "time" },
  "SL_AWAKENINGS": { text: "How many times did you wake up during the night?", type: "number" },
  "SL_WAKE_TIME": { text: "What time did you wake up this morning?", type: "time" },
  "SL_QUALITY": { text: "How would you rate your sleep quality?", type: "scale" },
  "SL_OUT_OF_BED": { text: "What time did you get out of bed?", type: "time" },
  "SL_REFRESHED": { text: "How refreshed do you feel this morning?", type: "scale" },
  "SL_NAPS": { text: "Did you take any naps yesterday?", type: "yes_no" },
  "SL_NAP_DURATION": { text: "How long were your naps in total?", type: "duration" },
  "SL_CAFFEINE": { text: "Did you have caffeine after 2pm?", type: "yes_no" },
  "SL_ALCOHOL": { text: "Did you have alcohol last night?", type: "yes_no" },
  "SL_EXERCISE": { text: "Did you exercise yesterday?", type: "yes_no" },
  "SL_NOTES": { text: "Any notes about your sleep?", type: "text" },
};

// Stanford Sleep Diary questions (SD_ prefix - full diary from SharedQuestionBank)
// NOTE: SD_DATE was removed - the system knows the date from the day being logged
const SLEEP_DIARY_QUESTIONS: Record<string, { text: string; type: string }> = {
  "SD_DAY_TYPE": { text: "What type of day is today?", type: "single_select" },
  "SD_MEDICATION_TAKEN": { text: "Did you take any sleep medication last night?", type: "yes_no" },
  "SD_MEDICATION_TIME": { text: "If yes, what time did you take it?", type: "time" },
  "SD_GOT_INTO_BED": { text: "What time did you get into bed last night?", type: "time" },
  "SD_LIGHTS_OUT": { text: "What time did you turn off the lights to sleep?", type: "time" },
  "SD_SLEEP_ONSET": { text: "What time do you think you fell asleep?", type: "time" },
  "SD_SLEEP_LATENCY": { text: "How long did it take you to fall asleep? (minutes)", type: "minutes" },
  "SD_AWAKENINGS_COUNT": { text: "How many times did you wake up during the night?", type: "number" },
  "SD_AWAKENINGS_DURATION": { text: "Total time awake during the night (minutes)", type: "minutes" },
  "SD_FINAL_WAKE": { text: "What time did you wake up for the final time?", type: "time" },
  "SD_OUT_OF_BED": { text: "What time did you get out of bed this morning?", type: "time" },
  "SD_SLEEP_QUALITY": { text: "How would you rate your sleep quality?", type: "scale" },
  "SD_NAPS_TAKEN": { text: "Did you take any naps yesterday?", type: "yes_no" },
  "SD_NAPS_COUNT": { text: "How many naps did you take?", type: "number" },
  "SD_NAP_DETAILS": { text: "For each nap, record the start time and duration.", type: "repeating_group" },
};

// Combined lookup function
function getQuestionDefinition(questionId: string): { text: string; type: string; pillar: string } | null {
  if (questionId.startsWith("SL_")) {
    const q = SLEEP_LOG_QUESTIONS[questionId];
    return q ? { ...q, pillar: "Sleep Log" } : null;
  }
  if (questionId.startsWith("SD_")) {
    const q = SLEEP_DIARY_QUESTIONS[questionId];
    return q ? { ...q, pillar: "Sleep Diary" } : null;
  }
  return null;
}

// ============================================
// Questionnaire Scoring Functions
// ============================================

interface QuestionnaireScore {
  name: string;
  abbreviation: string;
  score: number | null;
  maxScore: number;
  interpretation: string;
  severity: "normal" | "mild" | "moderate" | "severe" | "unknown";
  questionsAnswered: number;
  questionsRequired: number;
}

// ISI (Insomnia Severity Index) - 7 questions, each 0-4
function calculateISI(responses: Map<string, number>): QuestionnaireScore {
  const isiQuestions = ["ISI_1", "ISI_2", "ISI_3", "ISI_4", "ISI_5", "ISI_6", "ISI_7"];
  let total = 0;
  let answered = 0;

  for (const qId of isiQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 5) { // Allow partial scoring
    const score = Math.round(total * (7 / answered)); // Prorate
    if (score <= 7) { interpretation = "No clinically significant insomnia"; severity = "normal"; }
    else if (score <= 14) { interpretation = "Subthreshold insomnia"; severity = "mild"; }
    else if (score <= 21) { interpretation = "Clinical insomnia (moderate)"; severity = "moderate"; }
    else { interpretation = "Clinical insomnia (severe)"; severity = "severe"; }

    return { name: "Insomnia Severity Index", abbreviation: "ISI", score, maxScore: 28, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
  }

  return { name: "Insomnia Severity Index", abbreviation: "ISI", score: null, maxScore: 28, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
}

// PHQ-9 (Depression) - 9 questions, each 0-3
function calculatePHQ9(responses: Map<string, number>): QuestionnaireScore {
  const phqQuestions = ["PHQ9_1", "PHQ9_2", "PHQ9_3", "PHQ9_4", "PHQ9_5", "PHQ9_6", "PHQ9_7", "PHQ9_8", "PHQ9_9"];
  let total = 0;
  let answered = 0;

  for (const qId of phqQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  // Also check gateway questions (15 = depression gateway from Day 3)
  const gatewayVal = responses.get("15");
  if (gatewayVal !== undefined && answered === 0) {
    // Map gateway to PHQ-2 equivalent
    if (gatewayVal >= 2) { // "More than half the days" or "Nearly every day"
      return { name: "Patient Health Questionnaire", abbreviation: "PHQ-9", score: null, maxScore: 27,
        interpretation: "Gateway triggered - full PHQ-9 recommended", severity: "mild", questionsAnswered: 1, questionsRequired: 9 };
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 7) {
    const score = Math.round(total * (9 / answered));
    if (score <= 4) { interpretation = "Minimal depression"; severity = "normal"; }
    else if (score <= 9) { interpretation = "Mild depression"; severity = "mild"; }
    else if (score <= 14) { interpretation = "Moderate depression"; severity = "moderate"; }
    else if (score <= 19) { interpretation = "Moderately severe depression"; severity = "moderate"; }
    else { interpretation = "Severe depression"; severity = "severe"; }

    return { name: "Patient Health Questionnaire", abbreviation: "PHQ-9", score, maxScore: 27, interpretation, severity, questionsAnswered: answered, questionsRequired: 9 };
  }

  return { name: "Patient Health Questionnaire", abbreviation: "PHQ-9", score: null, maxScore: 27, interpretation, severity, questionsAnswered: answered, questionsRequired: 9 };
}

// GAD-7 (Anxiety) - 7 questions, each 0-3
function calculateGAD7(responses: Map<string, number>): QuestionnaireScore {
  const gadQuestions = ["GAD7_1", "GAD7_2", "GAD7_3", "GAD7_4", "GAD7_5", "GAD7_6", "GAD7_7"];
  let total = 0;
  let answered = 0;

  for (const qId of gadQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  // Check gateway (16 = anxiety gateway from Day 3)
  const gatewayVal = responses.get("16");
  if (gatewayVal !== undefined && answered === 0) {
    if (gatewayVal >= 2) {
      return { name: "Generalized Anxiety Disorder", abbreviation: "GAD-7", score: null, maxScore: 21,
        interpretation: "Gateway triggered - full GAD-7 recommended", severity: "mild", questionsAnswered: 1, questionsRequired: 7 };
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 5) {
    const score = Math.round(total * (7 / answered));
    if (score <= 4) { interpretation = "Minimal anxiety"; severity = "normal"; }
    else if (score <= 9) { interpretation = "Mild anxiety"; severity = "mild"; }
    else if (score <= 14) { interpretation = "Moderate anxiety"; severity = "moderate"; }
    else { interpretation = "Severe anxiety"; severity = "severe"; }

    return { name: "Generalized Anxiety Disorder", abbreviation: "GAD-7", score, maxScore: 21, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
  }

  return { name: "Generalized Anxiety Disorder", abbreviation: "GAD-7", score: null, maxScore: 21, interpretation, severity, questionsAnswered: answered, questionsRequired: 7 };
}

// ESS (Epworth Sleepiness Scale) - 8 questions, each 0-3
function calculateESS(responses: Map<string, number>): QuestionnaireScore {
  const essQuestions = ["ESS_1", "ESS_2", "ESS_3", "ESS_4", "ESS_5", "ESS_6", "ESS_7", "ESS_8"];
  let total = 0;
  let answered = 0;

  for (const qId of essQuestions) {
    const val = responses.get(qId);
    if (val !== undefined) {
      total += val;
      answered++;
    }
  }

  // Check daytime sleepiness gateway (17)
  const gatewayVal = responses.get("17");
  if (gatewayVal !== undefined && answered === 0) {
    if (gatewayVal >= 3) { // "Often" or "Always"
      return { name: "Epworth Sleepiness Scale", abbreviation: "ESS", score: null, maxScore: 24,
        interpretation: "Gateway triggered - full ESS recommended", severity: "mild", questionsAnswered: 1, questionsRequired: 8 };
    }
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 6) {
    const score = Math.round(total * (8 / answered));
    if (score <= 10) { interpretation = "Normal daytime sleepiness"; severity = "normal"; }
    else if (score <= 14) { interpretation = "Mild excessive daytime sleepiness"; severity = "mild"; }
    else if (score <= 18) { interpretation = "Moderate excessive daytime sleepiness"; severity = "moderate"; }
    else { interpretation = "Severe excessive daytime sleepiness"; severity = "severe"; }

    return { name: "Epworth Sleepiness Scale", abbreviation: "ESS", score, maxScore: 24, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
  }

  return { name: "Epworth Sleepiness Scale", abbreviation: "ESS", score: null, maxScore: 24, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
}

// STOP-BANG (Sleep Apnea Risk) - 8 yes/no questions
function calculateSTOPBANG(responses: Map<string, number>, demographics: { age?: number; sex?: string; bmi?: number }): QuestionnaireScore {
  let score = 0;
  let answered = 0;

  // S - Snore (question 19)
  const snore = responses.get("19");
  if (snore !== undefined) { if (snore === 1) score++; answered++; }

  // T - Tired (question 21)
  const tired = responses.get("21");
  if (tired !== undefined) { if (tired === 1) score++; answered++; }

  // O - Observed apnea (question 20)
  const observed = responses.get("20");
  if (observed !== undefined) { if (observed === 1) score++; answered++; }

  // P - Pressure (high blood pressure, question 27)
  const pressure = responses.get("27");
  if (pressure !== undefined) { if (pressure === 1) score++; answered++; }

  // B - BMI > 35
  if (demographics.bmi !== undefined) {
    if (demographics.bmi > 35) score++;
    answered++;
  }

  // A - Age > 50
  if (demographics.age !== undefined) {
    if (demographics.age > 50) score++;
    answered++;
  }

  // N - Neck circumference > 40cm (usually not collected, skip)

  // G - Gender = Male
  if (demographics.sex !== undefined) {
    if (demographics.sex.toLowerCase() === "male") score++;
    answered++;
  }

  let interpretation = "Not enough data";
  let severity: "normal" | "mild" | "moderate" | "severe" | "unknown" = "unknown";

  if (answered >= 4) {
    if (score <= 2) { interpretation = "Low risk of OSA"; severity = "normal"; }
    else if (score <= 4) { interpretation = "Intermediate risk of OSA"; severity = "mild"; }
    else { interpretation = "High risk of OSA"; severity = "moderate"; }

    return { name: "STOP-BANG Sleep Apnea Screening", abbreviation: "STOP-BANG", score, maxScore: 8, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
  }

  return { name: "STOP-BANG Sleep Apnea Screening", abbreviation: "STOP-BANG", score: null, maxScore: 8, interpretation, severity, questionsAnswered: answered, questionsRequired: 8 };
}

// ============================================
// Patient List & Overview Queries
// ============================================

/**
 * Get all patients with their progress and review status
 * SECURITY: Requires physician or admin role via sessionToken
 */
export const getAllPatientsWithProgress = query({
  args: {
    sessionToken: v.optional(v.string()), // Required for production, optional for backward compat
    statusFilter: v.optional(v.string()),
    searchTerm: v.optional(v.string()),
  },
  returns: v.array(
    v.object({
      _id: v.id("users"),
      username: v.string(),
      name: v.optional(v.string()),
      email: v.optional(v.string()),
      current_day: v.number(),
      started_at: v.number(),
      last_accessed: v.number(),
      onboarding_completed: v.optional(v.boolean()),
      onboarding_completed_at: v.optional(v.number()),
      review_status: v.optional(v.string()),
      progress_percentage: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    // Validate physician role if session token provided
    if (args.sessionToken) {
      const session = await validatePhysicianRole(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized: Physician access required");
      }
    }
    // TODO: Make sessionToken required once web dashboard auth is updated

    const users = await ctx.db.query("users").collect();

    // Filter out physicians and admins - only show patients
    const patientUsers = users.filter(user =>
      user.role !== "physician" && user.role !== "admin"
    );

    const patientsWithProgress = await Promise.all(
      patientUsers.map(async (user) => {
        // Get the patient's name from D1 response
        const nameResponse = await ctx.db
          .query("user_assessment_responses")
          .withIndex("by_user_question", (q) =>
            q.eq("user_id", user._id).eq("question_id", "D1")
          )
          .first();

        // Get review status
        const reviewStatus = await ctx.db
          .query("patient_review_status")
          .withIndex("by_user", (q) => q.eq("user_id", user._id))
          .first();

        // Calculate progress percentage (15 days total)
        const progressPercentage = Math.min(
          Math.round((user.current_day / 15) * 100),
          100
        );

        return {
          _id: user._id,
          username: user.username,
          name: nameResponse?.response_value || user.username, // Use username as fallback
          email: user.email,
          current_day: user.current_day,
          started_at: user.started_at,
          last_accessed: user.last_accessed,
          onboarding_completed: user.onboarding_completed,
          onboarding_completed_at: user.onboarding_completed_at,
          review_status: reviewStatus?.status,
          progress_percentage: progressPercentage,
        };
      })
    );

    // Filter by status if provided
    let filtered = patientsWithProgress;
    if (args.statusFilter && args.statusFilter !== "all") {
      filtered = filtered.filter(
        (p) => p.review_status === args.statusFilter
      );
    }

    // Filter by search term (name or username)
    if (args.searchTerm && args.searchTerm.trim() !== "") {
      const searchLower = args.searchTerm.toLowerCase();
      filtered = filtered.filter(
        (p) =>
          p.username.toLowerCase().includes(searchLower) ||
          (p.name && p.name.toLowerCase().includes(searchLower))
      );
    }

    // Sort by last accessed (most recent first)
    filtered.sort((a, b) => b.last_accessed - a.last_accessed);

    return filtered;
  },
});

/**
 * Get comprehensive patient details including all responses, scores, and notes
 * SECURITY: Requires physician or admin role via sessionToken
 */
export const getPatientDetails = query({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()), // Required for production
  },
  returns: v.object({
    user: v.object({
      _id: v.id("users"),
      username: v.string(),
      email: v.optional(v.string()),
      current_day: v.number(),
      started_at: v.number(),
      last_accessed: v.number(),
      onboarding_completed: v.optional(v.boolean()),
      onboarding_completed_at: v.optional(v.number()),
    }),
    name: v.optional(v.string()),
    demographics: v.object({
      dateOfBirth: v.optional(v.string()),
      sex: v.optional(v.string()),
      height: v.optional(v.string()),
      weight: v.optional(v.string()),
    }),
    reviewStatus: v.optional(
      v.object({
        status: v.string(),
        reviewed_by_physician_id: v.optional(v.string()),
        review_started_at: v.optional(v.number()),
        review_completed_at: v.optional(v.number()),
        updated_at: v.number(),
      })
    ),
    totalResponses: v.number(),
    completedDays: v.number(),
  }),
  handler: async (ctx, args) => {
    // Validate physician role if session token provided
    if (args.sessionToken) {
      const session = await validatePhysicianRole(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized: Physician access required");
      }
    }

    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Get name (D1)
    const nameResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D1")
      )
      .first();

    // Get demographics (D2, D4, D5, D6)
    const dobResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D2")
      )
      .first();

    const sexResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D4")
      )
      .first();

    const heightResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D5")
      )
      .first();

    const weightResponse = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_question", (q) =>
        q.eq("user_id", args.userId).eq("question_id", "D6")
      )
      .first();

    // Get review status
    const reviewStatus = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    // Get total responses
    const allResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Get completed days
    const userProgress = await ctx.db
      .query("user_progress")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();
    const completedDays = userProgress.filter((p) => p.completed).length;

    return {
      user: {
        _id: user._id,
        username: user.username,
        email: user.email,
        current_day: user.current_day,
        started_at: user.started_at,
        last_accessed: user.last_accessed,
        onboarding_completed: user.onboarding_completed,
        onboarding_completed_at: user.onboarding_completed_at,
      },
      name: nameResponse?.response_value || user.username, // Use username as fallback
      demographics: {
        dateOfBirth: dobResponse?.response_value,
        sex: sexResponse?.response_value,
        height: heightResponse?.response_value,
        weight: weightResponse?.response_value,
      },
      reviewStatus: reviewStatus
        ? {
            status: reviewStatus.status,
            reviewed_by_physician_id: reviewStatus.reviewed_by_physician_id,
            review_started_at: reviewStatus.review_started_at,
            review_completed_at: reviewStatus.review_completed_at,
            updated_at: reviewStatus.updated_at,
          }
        : undefined,
      totalResponses: allResponses.length,
      completedDays,
    };
  },
});

/**
 * Get all responses and notes for a specific day
 * SECURITY: Requires physician or admin role via sessionToken
 */
export const getPatientDayData = query({
  args: {
    userId: v.id("users"),
    dayNumber: v.number(),
    sessionToken: v.optional(v.string()), // Required for production
  },
  returns: v.object({
    responses: v.array(
      v.object({
        _id: v.id("user_assessment_responses"),
        question_id: v.string(),
        response_value: v.optional(v.string()),
        question_text: v.optional(v.string()),
        question_type: v.optional(v.string()),
        pillar: v.optional(v.string()),
        tier: v.optional(v.string()),
        created_at: v.number(),
        updated_at: v.number(),
      })
    ),
    notes: v.array(
      v.object({
        _id: v.id("physician_notes"),
        note_text: v.string(),
        created_at: v.number(),
        updated_at: v.number(),
        physician_id: v.optional(v.string()),
      })
    ),
  }),
  handler: async (ctx, args) => {
    // Validate physician role if session token provided
    if (args.sessionToken) {
      const session = await validatePhysicianRole(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized: Physician access required");
      }
    }

    // Get responses for this day
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    // Enrich with question details using global definitions + database fallback
    const enrichedResponses = await Promise.all(
      responses.map(async (response) => {
        let questionText: string | undefined;
        let questionType: string | undefined;
        let pillar: string | undefined;
        let tier: string | undefined = "core";

        // First check global hardcoded definitions (SL_ and SD_ prefixes)
        const hardcodedDef = getQuestionDefinition(response.question_id);
        if (hardcodedDef) {
          questionText = hardcodedDef.text;
          questionType = hardcodedDef.type;
          pillar = hardcodedDef.pillar;
        } else if (response.question_id.startsWith("SL_") || response.question_id.startsWith("SD_")) {
          // Fallback: try to find in sleep_diary_questions table
          const sleepQuestion = await ctx.db
            .query("sleep_diary_questions")
            .withIndex("by_question_id", (q) => q.eq("id", response.question_id))
            .first();

          if (sleepQuestion) {
            questionText = sleepQuestion.question_text;
            questionType = sleepQuestion.answer_format;
            pillar = response.question_id.startsWith("SL_") ? "Sleep Log" : "Sleep Diary";
          }
        } else {
          // Check assessment_questions table for all other questions
          const question = await ctx.db
            .query("assessment_questions")
            .withIndex("by_question_id", (q) =>
              q.eq("question_id", response.question_id)
            )
            .first();

          if (question) {
            questionText = question.question_text;
            questionType = question.question_type;
            pillar = question.pillar;
            tier = question.tier;
          }
        }

        // Combine response_value, response_number, and response_array into a displayable value
        let displayValue: string | undefined = response.response_value;

        // If no string value, check for numeric value
        if (!displayValue && response.response_number !== undefined && response.response_number !== null) {
          displayValue = String(response.response_number);
        }

        // If no string or number, check for array value
        if (!displayValue && response.response_array) {
          try {
            const arr = typeof response.response_array === 'string'
              ? JSON.parse(response.response_array)
              : response.response_array;
            if (Array.isArray(arr) && arr.length > 0) {
              displayValue = arr.join(", ");
            }
          } catch {
            displayValue = String(response.response_array);
          }
        }

        return {
          _id: response._id,
          question_id: response.question_id,
          response_value: displayValue,
          question_text: questionText,
          question_type: questionType,
          pillar: pillar,
          tier: tier,
          created_at: response.created_at,
          updated_at: response.updated_at,
        };
      })
    );

    // Get notes for this day
    const notes = await ctx.db
      .query("physician_notes")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      )
      .collect();

    return {
      responses: enrichedResponses,
      notes: notes.map((note) => ({
        _id: note._id,
        note_text: note.note_text,
        created_at: note.created_at,
        updated_at: note.updated_at,
        physician_id: note.physician_id,
      })),
    };
  },
});

/**
 * Get all physician notes for a patient
 */
export const getPhysicianNotes = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("physician_notes"),
      day_number: v.optional(v.number()),
      note_text: v.string(),
      created_at: v.number(),
      updated_at: v.number(),
      physician_id: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const notes = await ctx.db
      .query("physician_notes")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sort by most recent first
    notes.sort((a, b) => b.created_at - a.created_at);

    return notes.map((note) => ({
      _id: note._id,
      day_number: note.day_number,
      note_text: note.note_text,
      created_at: note.created_at,
      updated_at: note.updated_at,
      physician_id: note.physician_id,
    }));
  },
});

/**
 * Get all calculated questionnaire scores for a patient
 */
export const getQuestionnaireScores = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("questionnaire_scores"),
      questionnaire_name: v.string(),
      score: v.number(),
      max_score: v.optional(v.number()),
      category: v.optional(v.string()),
      interpretation: v.optional(v.string()),
      calculated_at: v.number(),
      calculation_metadata_json: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const scores = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Sort by calculation date (most recent first)
    scores.sort((a, b) => b.calculated_at - a.calculated_at);

    return scores.map((score) => ({
      _id: score._id,
      questionnaire_name: score.questionnaire_name,
      score: score.score,
      max_score: score.max_score,
      category: score.category,
      interpretation: score.interpretation,
      calculated_at: score.calculated_at,
      calculation_metadata_json: score.calculation_metadata_json,
    }));
  },
});

/**
 * Get patient visible field configuration
 */
export const getPatientVisibleFields = query({
  args: { userId: v.id("users") },
  returns: v.optional(
    v.object({
      _id: v.id("patient_visible_fields"),
      field_config_json: v.string(),
      updated_at: v.number(),
      updated_by_physician_id: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const config = await ctx.db
      .query("patient_visible_fields")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (!config) return undefined;

    return {
      _id: config._id,
      field_config_json: config.field_config_json,
      updated_at: config.updated_at,
      updated_by_physician_id: config.updated_by_physician_id,
    };
  },
});

/**
 * Get all responses grouped by day for a patient
 */
export const getPatientResponsesByDay = query({
  args: { userId: v.id("users") },
  returns: v.object({
    days: v.array(
      v.object({
        dayNumber: v.number(),
        responseCount: v.number(),
        lastUpdated: v.number(),
        hasNotes: v.boolean(),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const responses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Group by day
    const dayMap: Record<
      number,
      { count: number; lastUpdated: number; notes: boolean }
    > = {};

    for (const response of responses) {
      if (response.day_number !== undefined) {
        if (!dayMap[response.day_number]) {
          dayMap[response.day_number] = {
            count: 0,
            lastUpdated: 0,
            notes: false,
          };
        }
        dayMap[response.day_number].count++;
        dayMap[response.day_number].lastUpdated = Math.max(
          dayMap[response.day_number].lastUpdated,
          response.updated_at
        );
      }
    }

    // Check for notes
    const allNotes = await ctx.db
      .query("physician_notes")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    for (const note of allNotes) {
      if (note.day_number !== undefined && dayMap[note.day_number]) {
        dayMap[note.day_number].notes = true;
      }
    }

    // Convert to array and sort
    const days = Object.entries(dayMap)
      .map(([dayNumber, data]) => ({
        dayNumber: parseInt(dayNumber, 10),
        responseCount: data.count,
        lastUpdated: data.lastUpdated,
        hasNotes: data.notes,
      }))
      .sort((a, b) => a.dayNumber - b.dayNumber);

    return { days };
  },
});

/**
 * Get active interventions for a patient
 */
export const getPatientInterventions = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("user_interventions"),
      intervention_id: v.id("interventions"),
      intervention_name: v.string(),
      start_date: v.string(),
      end_date: v.optional(v.string()),
      frequency: v.optional(v.string()),
      dosage: v.optional(v.string()),
      timing: v.optional(v.string()),
      custom_instructions: v.optional(v.string()),
      status: v.string(),
      assigned_at: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const userInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Enrich with intervention details
    const enriched = await Promise.all(
      userInterventions.map(async (ui) => {
        const intervention = await ctx.db.get(ui.intervention_id);
        return {
          _id: ui._id,
          intervention_id: ui.intervention_id,
          intervention_name: intervention?.name || "Unknown",
          start_date: ui.start_date,
          end_date: ui.end_date,
          frequency: ui.frequency,
          dosage: ui.dosage,
          timing: ui.timing,
          custom_instructions: ui.custom_instructions,
          status: ui.status,
          assigned_at: ui.assigned_at,
        };
      })
    );

    // Sort by assignment date (most recent first)
    enriched.sort((a, b) => b.assigned_at - a.assigned_at);

    return enriched;
  },
});

/**
 * Get all available interventions library
 */
export const getAllInterventions = query({
  args: {},
  returns: v.array(
    v.object({
      _id: v.id("interventions"),
      name: v.string(),
      type: v.optional(v.string()),
      category: v.optional(v.string()),
      instructions_text: v.string(),
      status: v.string(),
    })
  ),
  handler: async (ctx) => {
    const interventions = await ctx.db
      .query("interventions")
      .withIndex("by_status", (q) => q.eq("status", "active"))
      .collect();

    return interventions.map((i) => ({
      _id: i._id,
      name: i.name,
      type: i.type,
      category: i.category,
      instructions_text: i.instructions_text,
      status: i.status,
    }));
  },
});

// ============================================
// Mutations
// ============================================

/**
 * Save or update a physician note
 */
export const savePhysicianNote = mutation({
  args: {
    userId: v.id("users"),
    dayNumber: v.optional(v.number()),
    noteText: v.string(),
    physicianId: v.optional(v.string()),
  },
  returns: v.id("physician_notes"),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if note exists for this user and day
    const existingQuery = ctx.db
      .query("physician_notes")
      .withIndex("by_user_day", (q) =>
        q.eq("user_id", args.userId).eq("day_number", args.dayNumber)
      );

    const existing = await existingQuery.first();

    if (existing) {
      // Update existing note
      await ctx.db.patch(existing._id, {
        note_text: args.noteText,
        updated_at: now,
        physician_id: args.physicianId,
      });
      return existing._id;
    } else {
      // Create new note
      const noteId = await ctx.db.insert("physician_notes", {
        user_id: args.userId,
        day_number: args.dayNumber,
        note_text: args.noteText,
        created_at: now,
        updated_at: now,
        physician_id: args.physicianId,
      });
      return noteId;
    }
  },
});

/**
 * Update patient review status
 */
export const updatePatientReviewStatus = mutation({
  args: {
    userId: v.id("users"),
    status: v.string(),
    physicianId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const existing = await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (existing) {
      // Update existing status
      const updates: any = {
        status: args.status,
        updated_at: now,
      };

      if (args.physicianId) {
        updates.reviewed_by_physician_id = args.physicianId;
      }

      // Set timestamps based on status
      if (args.status === "under_review" && !existing.review_started_at) {
        updates.review_started_at = now;
      }
      if (
        args.status === "interventions_prepared" &&
        !existing.review_completed_at
      ) {
        updates.review_completed_at = now;
      }

      await ctx.db.patch(existing._id, updates);
    } else {
      // Create new status
      const data: any = {
        user_id: args.userId,
        status: args.status,
        updated_at: now,
      };

      if (args.physicianId) {
        data.reviewed_by_physician_id = args.physicianId;
      }

      if (args.status === "under_review") {
        data.review_started_at = now;
      }

      await ctx.db.insert("patient_review_status", data);
    }

    return null;
  },
});

/**
 * Save a calculated questionnaire score
 */
export const saveQuestionnaireScore = mutation({
  args: {
    userId: v.id("users"),
    questionnaireName: v.string(),
    score: v.number(),
    maxScore: v.optional(v.number()),
    category: v.optional(v.string()),
    interpretation: v.optional(v.string()),
    calculationMetadata: v.optional(v.string()),
  },
  returns: v.id("questionnaire_scores"),
  handler: async (ctx, args) => {
    const now = Date.now();

    // Check if score already exists for this questionnaire
    const existing = await ctx.db
      .query("questionnaire_scores")
      .withIndex("by_user_questionnaire", (q) =>
        q.eq("user_id", args.userId).eq("questionnaire_name", args.questionnaireName)
      )
      .first();

    if (existing) {
      // Update existing score
      await ctx.db.patch(existing._id, {
        score: args.score,
        max_score: args.maxScore,
        category: args.category,
        interpretation: args.interpretation,
        calculated_at: now,
        calculation_metadata_json: args.calculationMetadata,
      });
      return existing._id;
    } else {
      // Create new score
      const scoreId = await ctx.db.insert("questionnaire_scores", {
        user_id: args.userId,
        questionnaire_name: args.questionnaireName,
        score: args.score,
        max_score: args.maxScore,
        category: args.category,
        interpretation: args.interpretation,
        calculated_at: now,
        calculation_metadata_json: args.calculationMetadata,
      });
      return scoreId;
    }
  },
});

/**
 * Update patient visible fields configuration
 */
export const updatePatientVisibleFields = mutation({
  args: {
    userId: v.id("users"),
    fieldConfig: v.string(), // JSON string
    physicianId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const now = Date.now();

    const existing = await ctx.db
      .query("patient_visible_fields")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        field_config_json: args.fieldConfig,
        updated_at: now,
        updated_by_physician_id: args.physicianId,
      });
    } else {
      await ctx.db.insert("patient_visible_fields", {
        user_id: args.userId,
        field_config_json: args.fieldConfig,
        updated_at: now,
        updated_by_physician_id: args.physicianId,
      });
    }

    return null;
  },
});

/**
 * Create a new intervention for a patient
 */
export const createInterventionForPatient = mutation({
  args: {
    userId: v.id("users"),
    interventionId: v.id("interventions"),
    startDate: v.string(),
    endDate: v.optional(v.string()),
    frequency: v.optional(v.string()),
    dosage: v.optional(v.string()),
    timing: v.optional(v.string()),
    customInstructions: v.optional(v.string()),
    physicianId: v.optional(v.string()),
  },
  returns: v.id("user_interventions"),
  handler: async (ctx, args) => {
    const now = Date.now();

    const userInterventionId = await ctx.db.insert("user_interventions", {
      user_id: args.userId,
      intervention_id: args.interventionId,
      assigned_by_coach_id: args.physicianId
        ? (args.physicianId as any)
        : undefined,
      start_date: args.startDate,
      end_date: args.endDate,
      frequency: args.frequency,
      dosage: args.dosage,
      timing: args.timing,
      custom_instructions: args.customInstructions,
      status: "draft", // Start as draft until activated
      assigned_at: now,
    });

    return userInterventionId;
  },
});

/**
 * Activate interventions for a patient
 */
export const activateInterventions = mutation({
  args: {
    userId: v.id("users"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    // Get all draft interventions for this user
    const draftInterventions = await ctx.db
      .query("user_interventions")
      .withIndex("by_user_status", (q) =>
        q.eq("user_id", args.userId).eq("status", "draft")
      )
      .collect();

    // Activate each one
    for (const intervention of draftInterventions) {
      await ctx.db.patch(intervention._id, {
        status: "active",
      });
    }

    // Update patient review status to interventions_active
    await ctx.db
      .query("patient_review_status")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .first()
      .then(async (status) => {
        if (status) {
          await ctx.db.patch(status._id, {
            status: "interventions_active",
            updated_at: Date.now(),
          });
        }
      });

    return null;
  },
});

/**
 * Delete a physician note
 */
export const deletePhysicianNote = mutation({
  args: {
    noteId: v.id("physician_notes"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.delete(args.noteId);
    return null;
  },
});

/**
 * Update an existing user intervention
 */
export const updateUserIntervention = mutation({
  args: {
    interventionId: v.id("user_interventions"),
    updates: v.object({
      start_date: v.optional(v.string()),
      end_date: v.optional(v.string()),
      frequency: v.optional(v.string()),
      dosage: v.optional(v.string()),
      timing: v.optional(v.string()),
      custom_instructions: v.optional(v.string()),
      status: v.optional(v.string()),
    }),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.patch(args.interventionId, args.updates);
    return null;
  },
});

/**
 * Delete a user intervention
 */
export const deleteUserIntervention = mutation({
  args: {
    interventionId: v.id("user_interventions"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.delete(args.interventionId);
    return null;
  },
});

// ============================================
// Dynamic Questionnaire Scoring
// ============================================

/**
 * Calculate all questionnaire scores dynamically from patient responses
 * This includes ISI, PHQ-9, GAD-7, ESS, STOP-BANG, and gateway analysis
 */
export const calculatePatientScores = query({
  args: {
    userId: v.id("users"),
    sessionToken: v.optional(v.string()),
  },
  returns: v.object({
    scores: v.array(
      v.object({
        name: v.string(),
        abbreviation: v.string(),
        score: v.union(v.number(), v.null()),
        maxScore: v.number(),
        interpretation: v.string(),
        severity: v.string(),
        questionsAnswered: v.number(),
        questionsRequired: v.number(),
      })
    ),
    sleepMetrics: v.object({
      avgBedtime: v.optional(v.string()),
      avgWakeTime: v.optional(v.string()),
      avgSleepQuality: v.optional(v.number()),
      avgAwakenings: v.optional(v.number()),
      daysLogged: v.number(),
    }),
    gateways: v.object({
      insomnia: v.boolean(),
      depression: v.boolean(),
      anxiety: v.boolean(),
      sleepApnea: v.boolean(),
      excessiveSleepiness: v.boolean(),
      pain: v.boolean(),
    }),
  }),
  handler: async (ctx, args) => {
    // Validate physician role if session token provided
    if (args.sessionToken) {
      const session = await validatePhysicianRole(ctx, args.sessionToken);
      if (!session.valid) {
        throw new Error(session.error || "Unauthorized: Physician access required");
      }
    }

    // Get all responses for this user
    const allResponses = await ctx.db
      .query("user_assessment_responses")
      .withIndex("by_user", (q) => q.eq("user_id", args.userId))
      .collect();

    // Build a map of question_id -> numeric value for scoring
    const responseMap = new Map<string, number>();
    const stringResponseMap = new Map<string, string>();

    for (const r of allResponses) {
      // Get numeric value
      if (r.response_number !== undefined && r.response_number !== null) {
        responseMap.set(r.question_id, r.response_number);
      } else if (r.response_value !== undefined) {
        // Try to parse as number
        const num = parseFloat(r.response_value);
        if (!isNaN(num)) {
          responseMap.set(r.question_id, num);
        }
        // Also map string values for yes/no questions
        const val = r.response_value.toLowerCase();
        if (val === "yes" || val === "true" || val === "1") {
          responseMap.set(r.question_id, 1);
        } else if (val === "no" || val === "false" || val === "0") {
          responseMap.set(r.question_id, 0);
        }
        // Map select index (0-based)
        if (val === "not at all") responseMap.set(r.question_id, 0);
        else if (val === "several days") responseMap.set(r.question_id, 1);
        else if (val === "more than half the days") responseMap.set(r.question_id, 2);
        else if (val === "nearly every day") responseMap.set(r.question_id, 3);
        // ESS/other scale options
        else if (val === "never") responseMap.set(r.question_id, 0);
        else if (val === "rarely") responseMap.set(r.question_id, 1);
        else if (val === "sometimes") responseMap.set(r.question_id, 2);
        else if (val === "often") responseMap.set(r.question_id, 3);
        else if (val === "always") responseMap.set(r.question_id, 4);
      }
      // Store string value
      if (r.response_value) {
        stringResponseMap.set(r.question_id, r.response_value);
      }
    }

    // Get demographics for STOP-BANG
    const user = await ctx.db.get(args.userId);
    const dobResponse = stringResponseMap.get("D2");
    const sexResponse = stringResponseMap.get("D4");
    const heightResponse = stringResponseMap.get("D5");
    const weightResponse = stringResponseMap.get("D6");

    let age: number | undefined;
    if (dobResponse) {
      const birthYear = parseInt(dobResponse.split("-")[0] || dobResponse);
      if (!isNaN(birthYear)) {
        age = new Date().getFullYear() - birthYear;
      }
    }

    let bmi: number | undefined;
    if (heightResponse && weightResponse) {
      const heightCm = parseFloat(heightResponse);
      const weightKg = parseFloat(weightResponse);
      if (!isNaN(heightCm) && !isNaN(weightKg) && heightCm > 0) {
        bmi = weightKg / ((heightCm / 100) ** 2);
      }
    }

    const demographics = { age, sex: sexResponse, bmi };

    // Calculate all scores
    const scores = [
      calculateISI(responseMap),
      calculatePHQ9(responseMap),
      calculateGAD7(responseMap),
      calculateESS(responseMap),
      calculateSTOPBANG(responseMap, demographics),
    ];

    // Calculate sleep log metrics
    const sleepLogResponses = allResponses.filter(r =>
      r.question_id.startsWith("SL_") || r.question_id.startsWith("SD_")
    );

    let totalQuality = 0;
    let qualityCount = 0;
    let totalAwakenings = 0;
    let awakeningsCount = 0;
    const bedtimes: string[] = [];
    const wakeTimes: string[] = [];

    for (const r of sleepLogResponses) {
      if (r.question_id === "SL_QUALITY" || r.question_id === "SD_SLEEP_QUALITY") {
        const val = r.response_number ?? parseFloat(r.response_value || "");
        if (!isNaN(val)) {
          totalQuality += val;
          qualityCount++;
        }
      }
      if (r.question_id === "SL_AWAKENINGS" || r.question_id === "SD_AWAKENINGS_COUNT") {
        const val = r.response_number ?? parseFloat(r.response_value || "");
        if (!isNaN(val)) {
          totalAwakenings += val;
          awakeningsCount++;
        }
      }
      if (r.question_id === "SL_BEDTIME" || r.question_id === "SD_GOT_INTO_BED") {
        if (r.response_value) bedtimes.push(r.response_value);
      }
      if (r.question_id === "SL_WAKE_TIME" || r.question_id === "SD_FINAL_WAKE") {
        if (r.response_value) wakeTimes.push(r.response_value);
      }
    }

    // Get unique days logged
    const daysLogged = new Set(sleepLogResponses.map(r => r.day_number)).size;

    const sleepMetrics = {
      avgBedtime: bedtimes.length > 0 ? bedtimes[Math.floor(bedtimes.length / 2)] : undefined, // median
      avgWakeTime: wakeTimes.length > 0 ? wakeTimes[Math.floor(wakeTimes.length / 2)] : undefined,
      avgSleepQuality: qualityCount > 0 ? Math.round((totalQuality / qualityCount) * 10) / 10 : undefined,
      avgAwakenings: awakeningsCount > 0 ? Math.round((totalAwakenings / awakeningsCount) * 10) / 10 : undefined,
      daysLogged,
    };

    // Determine gateway triggers
    const gateways = {
      insomnia: (responseMap.get("3") === 1) || // trouble falling/staying asleep
                (responseMap.get("1") !== undefined && responseMap.get("1")! <= 5), // poor sleep quality
      depression: (responseMap.get("15") !== undefined && responseMap.get("15")! >= 2), // felt down/hopeless
      anxiety: (responseMap.get("16") !== undefined && responseMap.get("16")! >= 2), // felt nervous/anxious
      sleepApnea: (responseMap.get("19") === 1) || // loud snoring
                  (responseMap.get("20") === 1), // observed apnea
      excessiveSleepiness: (responseMap.get("17") !== undefined && responseMap.get("17")! >= 3), // often/always tired
      pain: (responseMap.get("22") === 1), // pain affects sleep
    };

    return {
      scores: scores.map(s => ({
        name: s.name,
        abbreviation: s.abbreviation,
        score: s.score,
        maxScore: s.maxScore,
        interpretation: s.interpretation,
        severity: s.severity,
        questionsAnswered: s.questionsAnswered,
        questionsRequired: s.questionsRequired,
      })),
      sleepMetrics,
      gateways,
    };
  },
});

