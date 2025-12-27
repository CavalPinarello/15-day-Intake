"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useState, useCallback, useEffect, useMemo } from "react";
import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { ResponseValue, Question, AnswerFormat } from "@/components/questions/types";

type Section = "sleepLog" | "assessment";

interface UseConvexQuestionnaireOptions {
  userId: Id<"users"> | null;
  dayNumber: number;
  section: Section;
}

// Type for Convex question response
interface ConvexQuestion {
  id: string;
  text: string;
  type: string;
  required: boolean;
  options?: string[];
  helpText?: string;
  moduleName?: string;
  formatConfig?: Record<string, unknown>;
  conditionalLogic?: Record<string, unknown>;
}

interface QuestionsForDayResponse {
  sleepLog: ConvexQuestion[];
  assessment: ConvexQuestion[];
  metadata: {
    sleepLogCount: number;
    assessmentCount: number;
    totalMinutes: number;
    triggeredGateways: string[];
    dayDescription?: string;
    dayExplanation?: string;
  };
}

// Type for saved response value
interface SavedResponseValue {
  stringValue?: string;
  numberValue?: number;
  arrayValue?: string[];
}

/**
 * Main hook for questionnaire functionality
 * Encapsulates all Convex interactions for the questionnaire
 */
export function useConvexQuestionnaire({
  userId,
  dayNumber,
  section,
}: UseConvexQuestionnaireOptions) {
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [localResponses, setLocalResponses] = useState<Map<string, ResponseValue>>(new Map());
  const [saveError, setSaveError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  // === CONVEX QUERIES (reactive) ===
  const questionsData = useQuery(
    api.watch.getQuestionsForUserDay,
    userId ? { userId, dayNumber, section } : "skip"
  ) as QuestionsForDayResponse | undefined;

  const savedResponses = useQuery(
    api.watch.getSavedResponses,
    userId ? { userId, dayNumber } : "skip"
  );

  const questionProgress = useQuery(
    api.watch.getQuestionProgress,
    userId ? { userId, dayNumber, section } : "skip"
  );

  const journeyState = useQuery(
    api.watch.getJourneyState,
    userId ? { userId } : "skip"
  );

  // === CONVEX MUTATIONS ===
  const saveResponsesMutation = useMutation(api.watch.saveResponses);
  const updateProgressMutation = useMutation(api.watch.updateQuestionProgress);
  const completeSectionMutation = useMutation(api.watch.completeSection);

  // === TRANSFORM QUESTIONS ===
  const questions = useMemo(() => {
    if (!questionsData) return [];
    const rawQuestions = section === "sleepLog"
      ? questionsData.sleepLog
      : questionsData.assessment;
    return (rawQuestions || []).map(transformToQuestion);
  }, [questionsData, section]);

  const currentQuestion = questions[currentQuestionIndex];

  // === INITIALIZE FROM SAVED PROGRESS ===
  useEffect(() => {
    if (questionProgress && !questionProgress.completed && questionProgress.currentQuestionIndex < questions.length) {
      setCurrentQuestionIndex(questionProgress.currentQuestionIndex);
    }
  }, [questionProgress, questions.length]);

  // === MERGE SAVED RESPONSES ===
  useEffect(() => {
    if (savedResponses) {
      setLocalResponses((prev) => {
        const merged = new Map(prev);
        (Object.entries(savedResponses) as [string, SavedResponseValue][]).forEach(([qId, val]) => {
          if (!merged.has(qId)) {
            const responseValue = val.stringValue ?? val.numberValue ?? val.arrayValue ?? null;
            if (responseValue !== null) {
              merged.set(qId, responseValue);
            }
          }
        });
        return merged;
      });
    }
  }, [savedResponses]);

  // === ACTIONS ===
  const saveResponse = useCallback(
    async (questionId: string, value: ResponseValue) => {
      // Update local state immediately (optimistic)
      setLocalResponses((prev) => new Map(prev).set(questionId, value));

      if (!userId) return;

      setIsSaving(true);
      try {
        await saveResponsesMutation({
          userId,
          dayNumber,
          responses: [
            {
              questionId,
              responseValue: typeof value === "string" ? value : undefined,
              responseNumber: typeof value === "number" ? value : undefined,
              responseArray: Array.isArray(value) ? value : undefined,
            },
          ],
          source: "web",
        });
        setSaveError(null);
      } catch (err) {
        setSaveError("Failed to save response. Please try again.");
        console.error("[Web Convex] Save error:", err);
      } finally {
        setIsSaving(false);
      }
    },
    [userId, dayNumber, saveResponsesMutation]
  );

  const goToNextQuestion = useCallback(async () => {
    if (!userId) return { sectionComplete: false };

    const newIndex = currentQuestionIndex + 1;

    if (newIndex >= questions.length) {
      // Section complete
      return { sectionComplete: true };
    }

    setCurrentQuestionIndex(newIndex);

    // Sync progress to Convex (fire and forget)
    updateProgressMutation({
      userId,
      dayNumber,
      section,
      currentQuestionIndex: newIndex,
      totalQuestions: questions.length,
      device: "web",
    }).catch((err) => {
      console.error("[Web Convex] Failed to sync progress:", err);
    });

    return { sectionComplete: false };
  }, [userId, dayNumber, section, currentQuestionIndex, questions.length, updateProgressMutation]);

  const goToPreviousQuestion = useCallback(() => {
    if (currentQuestionIndex > 0) {
      setCurrentQuestionIndex((prev) => prev - 1);
    }
  }, [currentQuestionIndex]);

  const completeSection = useCallback(async () => {
    if (!userId) return { success: false };

    try {
      const result = await completeSectionMutation({
        userId,
        dayNumber,
        section,
        source: "web",
      });
      return { success: true, ...result };
    } catch (err) {
      setSaveError("Failed to complete section. Please try again.");
      console.error("[Web Convex] Complete section error:", err);
      throw err;
    }
  }, [userId, dayNumber, section, completeSectionMutation]);

  const resetToStart = useCallback(() => {
    setCurrentQuestionIndex(0);
  }, []);

  // === DERIVED STATE ===
  const progress = useMemo(() => {
    return questions.length > 0
      ? ((currentQuestionIndex + 1) / questions.length) * 100
      : 0;
  }, [currentQuestionIndex, questions.length]);

  const currentResponse = useMemo(() => {
    return currentQuestion ? localResponses.get(currentQuestion.question_id) ?? null : null;
  }, [currentQuestion, localResponses]);

  const isResponseValid = useMemo(() => {
    if (!currentQuestion) return true;
    if (!currentQuestion.required) return true;
    return currentResponse !== null && currentResponse !== undefined && currentResponse !== "";
  }, [currentQuestion, currentResponse]);

  return {
    // State
    currentQuestion,
    currentQuestionIndex,
    totalQuestions: questions.length,
    questions,
    progress,
    isLoading: questionsData === undefined,
    isSaving,
    saveError,

    // Responses
    currentResponse,
    responses: localResponses,
    isResponseValid,

    // Journey state
    journeyState,
    metadata: questionsData?.metadata,

    // Actions
    saveResponse,
    goToNextQuestion,
    goToPreviousQuestion,
    completeSection,
    resetToStart,
    clearError: () => setSaveError(null),
  };
}

// === HELPER: Transform Convex question to QuestionRenderer format ===
function transformToQuestion(convexQ: ConvexQuestion): Question {
  // Build format_config with defaults for special types
  const formatConfig = buildFormatConfig(convexQ);

  return {
    question_id: convexQ.id,
    question_text: convexQ.text,
    help_text: convexQ.helpText,
    answer_format: mapConvexTypeToFormat(convexQ.type),
    format_config: JSON.stringify(formatConfig),
    required: convexQ.required,
    estimated_time_seconds: 30,
  };
}

// Build format_config with sensible defaults for different question types
function buildFormatConfig(convexQ: ConvexQuestion): Record<string, unknown> {
  const baseConfig = convexQ.formatConfig || {};

  // For yesNo type, add default Yes/No options if not present
  if (convexQ.type === "yesNo" && !baseConfig.options) {
    return {
      ...baseConfig,
      options: [
        { value: "yes", label: "Yes" },
        { value: "no", label: "No" },
      ],
      layout: "horizontal",
    };
  }

  // For singleSelect/multiSelect, ensure options exist (even if empty array to prevent crash)
  if ((convexQ.type === "singleSelect" || convexQ.type === "multiSelect") && !baseConfig.options) {
    // Try to build options from the legacy options field if available
    if (convexQ.options && Array.isArray(convexQ.options)) {
      return {
        ...baseConfig,
        options: convexQ.options.map((opt: string) => ({
          value: opt.toLowerCase().replace(/\s+/g, "_"),
          label: opt,
        })),
      };
    }
    // Fallback: empty array to prevent crash
    return {
      ...baseConfig,
      options: [],
    };
  }

  // For scale type, add default range if not present
  if (convexQ.type === "scale" && !baseConfig.min && !baseConfig.max) {
    return {
      min: 1,
      max: 10,
      step: 1,
      ...baseConfig,
    };
  }

  return baseConfig;
}

function mapConvexTypeToFormat(type: string): AnswerFormat {
  const mapping: Record<string, AnswerFormat> = {
    time: "time_picker",
    scale: "slider_scale",
    number: "number_input",
    singleSelect: "single_select_chips",
    multiSelect: "multi_select_chips",
    yesNo: "single_select_chips",
    text: "textarea",
    year: "date_picker",
    minutesScroll: "minutes_scroll",
    numberScroll: "number_scroll",
    // Legacy mappings from database question_type
    select: "single_select_chips",
    checkbox: "multi_select_chips",
    textarea: "textarea",
  };
  return mapping[type] || "textarea";
}

/**
 * Hook for managing section transitions
 */
export function useSectionManager(userId: Id<"users"> | null, dayNumber: number) {
  const [currentSection, setCurrentSection] = useState<Section>("sleepLog");
  const [showSectionTransition, setShowSectionTransition] = useState(false);
  const [showDayCompletion, setShowDayCompletion] = useState(false);

  const journeyState = useQuery(
    api.watch.getJourneyState,
    userId ? { userId } : "skip"
  );

  // Check if we should start at assessment (sleep log already done)
  useEffect(() => {
    if (journeyState?.sleepLogCompleted && !journeyState?.assessmentCompleted) {
      setCurrentSection("assessment");
    }
  }, [journeyState?.sleepLogCompleted, journeyState?.assessmentCompleted]);

  const handleSectionComplete = useCallback((section: Section) => {
    if (section === "sleepLog") {
      setShowSectionTransition(true);
    } else {
      setShowDayCompletion(true);
    }
  }, []);

  const continueToAssessment = useCallback(() => {
    setShowSectionTransition(false);
    setCurrentSection("assessment");
  }, []);

  return {
    currentSection,
    setCurrentSection,
    showSectionTransition,
    showDayCompletion,
    handleSectionComplete,
    continueToAssessment,
    setShowDayCompletion,
    journeyState,
  };
}
