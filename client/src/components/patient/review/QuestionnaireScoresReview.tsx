"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useMemo } from "react";
import { ClipboardList, AlertTriangle, CheckCircle, Info } from "lucide-react";
import { ReviewSection } from "./ReviewSection";

interface QuestionnaireScoresReviewProps {
  userId: Id<"users">;
  isReviewed: boolean;
  onReviewedChange: (reviewed: boolean) => void;
}

interface QuestionnaireScore {
  questionnaire: string;
  score: number | null;
  maxScore?: number;
  interpretation?: string;
  severity?: string;
  completedAt?: number;
}

// Score thresholds for severity coloring
const SCORE_THRESHOLDS: Record<string, { mild: number; moderate: number; severe: number; max: number }> = {
  ISI: { mild: 8, moderate: 15, severe: 22, max: 28 },
  "PHQ-9": { mild: 5, moderate: 10, severe: 15, max: 27 },
  "GAD-7": { mild: 5, moderate: 10, severe: 15, max: 21 },
  ESS: { mild: 10, moderate: 13, severe: 16, max: 24 },
  "STOP-BANG": { mild: 3, moderate: 5, severe: 6, max: 8 },
  PSQI: { mild: 5, moderate: 10, severe: 15, max: 21 },
  "MEQ-SA": { mild: 42, moderate: 58, severe: 86, max: 86 },
  FSS: { mild: 36, moderate: 45, severe: 54, max: 63 },
  FOSQ: { mild: 14, moderate: 16, severe: 18, max: 20 },
  DBAS: { mild: 4, moderate: 5, severe: 6, max: 10 },
  PSAS: { mild: 26, moderate: 39, severe: 52, max: 80 },
  "BPI-SF": { mild: 4, moderate: 6, severe: 8, max: 10 },
  "AUDIT-C": { mild: 3, moderate: 5, severe: 7, max: 12 },
};

export function QuestionnaireScoresReview({
  userId,
  isReviewed,
  onReviewedChange,
}: QuestionnaireScoresReviewProps) {
  // Fetch questionnaire scores
  const scoresData = useQuery(api.physician.getQuestionnaireScores, { userId });

  // Process scores
  const processedScores = useMemo(() => {
    if (!scoresData) return null;

    const scores: QuestionnaireScore[] = [];
    let concernCount = 0;
    let completedCount = 0;

    // Convert scores data to array
    Object.entries(scoresData).forEach(([key, value]) => {
      if (typeof value === "object" && value !== null && "score" in value) {
        const scoreData = value as {
          score: number | null;
          maxScore?: number;
          interpretation?: string;
          severity?: string;
          completedAt?: number;
        };

        const questionnaire = key.toUpperCase().replace(/_/g, "-");
        const score: QuestionnaireScore = {
          questionnaire,
          score: scoreData.score,
          maxScore: scoreData.maxScore,
          interpretation: scoreData.interpretation,
          severity: scoreData.severity,
          completedAt: scoreData.completedAt,
        };

        scores.push(score);

        if (score.score !== null) {
          completedCount++;
          const threshold = SCORE_THRESHOLDS[questionnaire];
          if (threshold && score.score >= threshold.moderate) {
            concernCount++;
          }
        }
      }
    });

    // Sort by severity (most concerning first)
    scores.sort((a, b) => {
      if (a.score === null) return 1;
      if (b.score === null) return -1;

      const aThreshold = SCORE_THRESHOLDS[a.questionnaire];
      const bThreshold = SCORE_THRESHOLDS[b.questionnaire];

      const aLevel = aThreshold
        ? a.score >= aThreshold.severe
          ? 3
          : a.score >= aThreshold.moderate
          ? 2
          : a.score >= aThreshold.mild
          ? 1
          : 0
        : 0;

      const bLevel = bThreshold
        ? b.score >= bThreshold.severe
          ? 3
          : b.score >= bThreshold.moderate
          ? 2
          : b.score >= bThreshold.mild
          ? 1
          : 0
        : 0;

      return bLevel - aLevel;
    });

    return {
      scores,
      completedCount,
      concernCount,
      totalCount: scores.length,
    };
  }, [scoresData]);

  // Build preview text
  const preview = useMemo(() => {
    if (!processedScores) return "Loading questionnaire scores...";
    if (processedScores.completedCount === 0) return "No questionnaires completed";

    // Find most notable scores for preview
    const notable = processedScores.scores
      .filter((s) => s.score !== null)
      .slice(0, 3)
      .map((s) => `${s.questionnaire}: ${s.score}`)
      .join(" • ");

    return notable || `${processedScores.completedCount} questionnaires completed`;
  }, [processedScores]);

  const getSeverityColor = (questionnaire: string, score: number | null) => {
    if (score === null) return "bg-gray-700/50 text-gray-500";

    const threshold = SCORE_THRESHOLDS[questionnaire];
    if (!threshold) return "bg-gray-700/50 text-gray-300";

    if (score >= threshold.severe) return "bg-red-500/20 text-red-400 border-red-500/30";
    if (score >= threshold.moderate) return "bg-orange-500/20 text-orange-400 border-orange-500/30";
    if (score >= threshold.mild) return "bg-amber-500/20 text-amber-400 border-amber-500/30";
    return "bg-green-500/20 text-green-400 border-green-500/30";
  };

  const getSeverityLabel = (questionnaire: string, score: number | null) => {
    if (score === null) return "Not completed";

    const threshold = SCORE_THRESHOLDS[questionnaire];
    if (!threshold) return "Completed";

    if (score >= threshold.severe) return "Severe";
    if (score >= threshold.moderate) return "Moderate";
    if (score >= threshold.mild) return "Mild";
    return "Normal";
  };

  const getScoreBarWidth = (questionnaire: string, score: number | null) => {
    if (score === null) return 0;
    const threshold = SCORE_THRESHOLDS[questionnaire];
    const max = threshold?.max || 100;
    return Math.min((score / max) * 100, 100);
  };

  const getQuestionnaireDescription = (questionnaire: string): string => {
    const descriptions: Record<string, string> = {
      ISI: "Insomnia Severity Index",
      "PHQ-9": "Patient Health Questionnaire (Depression)",
      "GAD-7": "Generalized Anxiety Disorder",
      ESS: "Epworth Sleepiness Scale",
      "STOP-BANG": "Sleep Apnea Screening",
      PSQI: "Pittsburgh Sleep Quality Index",
      "MEQ-SA": "Morningness-Eveningness (Chronotype)",
      FSS: "Fatigue Severity Scale",
      FOSQ: "Functional Outcomes of Sleep",
      DBAS: "Dysfunctional Beliefs About Sleep",
      PSAS: "Pre-Sleep Arousal Scale",
      "BPI-SF": "Brief Pain Inventory",
      "AUDIT-C": "Alcohol Use Disorders",
    };
    return descriptions[questionnaire] || questionnaire;
  };

  return (
    <ReviewSection
      id="scores"
      title="Review questionnaire scores"
      icon={<ClipboardList className="w-4 h-4" />}
      preview={preview}
      isReviewed={isReviewed}
      onReviewedChange={onReviewedChange}
      isLoading={!processedScores}
    >
      {processedScores && processedScores.scores.length > 0 ? (
        <div className="space-y-4">
          {/* Summary Stats */}
          <div className="flex items-center gap-4 text-sm">
            <div className="flex items-center gap-2">
              <CheckCircle className="w-4 h-4 text-green-400" />
              <span className="text-gray-400">Completed:</span>
              <span className="text-white font-medium">{processedScores.completedCount}</span>
            </div>
            {processedScores.concernCount > 0 && (
              <div className="flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-orange-400" />
                <span className="text-gray-400">Elevated scores:</span>
                <span className="text-orange-400 font-medium">{processedScores.concernCount}</span>
              </div>
            )}
          </div>

          {/* Scores Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 max-h-[350px] overflow-y-auto">
            {processedScores.scores.map((score) => (
              <div
                key={score.questionnaire}
                className={`p-3 rounded-lg border ${getSeverityColor(
                  score.questionnaire,
                  score.score
                )}`}
              >
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <p className="text-sm font-medium text-white">{score.questionnaire}</p>
                    <p className="text-[10px] text-gray-500">
                      {getQuestionnaireDescription(score.questionnaire)}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-lg font-bold">
                      {score.score !== null ? score.score : "--"}
                      <span className="text-xs text-gray-500 font-normal">
                        /{SCORE_THRESHOLDS[score.questionnaire]?.max || "?"}
                      </span>
                    </p>
                    <p className="text-[10px]">
                      {getSeverityLabel(score.questionnaire, score.score)}
                    </p>
                  </div>
                </div>

                {/* Score Bar */}
                {score.score !== null && (
                  <div className="h-1.5 bg-gray-700 rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full transition-all ${
                        getSeverityLabel(score.questionnaire, score.score) === "Severe"
                          ? "bg-red-500"
                          : getSeverityLabel(score.questionnaire, score.score) === "Moderate"
                          ? "bg-orange-500"
                          : getSeverityLabel(score.questionnaire, score.score) === "Mild"
                          ? "bg-amber-500"
                          : "bg-green-500"
                      }`}
                      style={{
                        width: `${getScoreBarWidth(score.questionnaire, score.score)}%`,
                      }}
                    />
                  </div>
                )}

                {/* Interpretation */}
                {score.interpretation && (
                  <p className="text-[10px] text-gray-400 mt-2 line-clamp-2">
                    {score.interpretation}
                  </p>
                )}
              </div>
            ))}
          </div>

          {/* Info Note */}
          <div className="flex items-start gap-2 p-3 bg-gray-800/50 rounded-lg">
            <Info className="w-4 h-4 text-gray-400 mt-0.5" />
            <p className="text-xs text-gray-400">
              Click on individual questionnaires in the 360° View tab for detailed question-by-question responses.
            </p>
          </div>
        </div>
      ) : (
        <div className="text-center py-6 text-gray-500">
          <ClipboardList className="w-8 h-8 mx-auto mb-2 opacity-50" />
          <p className="text-sm">No questionnaire scores available</p>
          <p className="text-xs mt-1">Patient has not completed any questionnaires</p>
        </div>
      )}
    </ReviewSection>
  );
}
