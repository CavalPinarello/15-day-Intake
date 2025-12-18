"use client";

import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import {
  X,
  Activity,
  AlertTriangle,
  CheckCircle,
  TrendingUp,
  TrendingDown,
  Minus,
  Brain,
  Loader2,
  FileText,
  BarChart3,
  Clock,
} from "lucide-react";

interface QuestionResponse {
  questionId: string;
  questionText: string;
  responseValue: string;
  responseNumber?: number;
}

interface ScoreDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  userId: Id<"users">;
  score: {
    _id: string;
    questionnaire_name: string;
    score: number;
    max_score?: number;
    category?: string;
    interpretation?: string;
    calculated_at: number;
  };
  questionResponses?: QuestionResponse[];
}

// Severity color mapping
const severityColors: Record<string, { bg: string; text: string; border: string }> = {
  normal: { bg: "bg-green-500/20", text: "text-green-400", border: "border-green-500/30" },
  mild: { bg: "bg-yellow-500/20", text: "text-yellow-400", border: "border-yellow-500/30" },
  moderate: { bg: "bg-orange-500/20", text: "text-orange-400", border: "border-orange-500/30" },
  severe: { bg: "bg-red-500/20", text: "text-red-400", border: "border-red-500/30" },
  unknown: { bg: "bg-gray-500/20", text: "text-gray-400", border: "border-gray-500/30" },
};

// Score thresholds for each questionnaire
const scoreThresholds: Record<string, { ranges: Array<{ max: number; severity: string; label: string }> }> = {
  ISI: {
    ranges: [
      { max: 7, severity: "normal", label: "No clinically significant insomnia" },
      { max: 14, severity: "mild", label: "Subthreshold insomnia" },
      { max: 21, severity: "moderate", label: "Clinical insomnia (moderate)" },
      { max: 28, severity: "severe", label: "Clinical insomnia (severe)" },
    ],
  },
  "PHQ-9": {
    ranges: [
      { max: 4, severity: "normal", label: "Minimal depression" },
      { max: 9, severity: "mild", label: "Mild depression" },
      { max: 14, severity: "moderate", label: "Moderate depression" },
      { max: 19, severity: "moderate", label: "Moderately severe depression" },
      { max: 27, severity: "severe", label: "Severe depression" },
    ],
  },
  "GAD-7": {
    ranges: [
      { max: 4, severity: "normal", label: "Minimal anxiety" },
      { max: 9, severity: "mild", label: "Mild anxiety" },
      { max: 14, severity: "moderate", label: "Moderate anxiety" },
      { max: 21, severity: "severe", label: "Severe anxiety" },
    ],
  },
  ESS: {
    ranges: [
      { max: 7, severity: "normal", label: "Normal daytime sleepiness" },
      { max: 12, severity: "mild", label: "Mild excessive daytime sleepiness" },
      { max: 15, severity: "moderate", label: "Moderate excessive daytime sleepiness" },
      { max: 24, severity: "severe", label: "Severe excessive daytime sleepiness" },
    ],
  },
  "STOP-BANG": {
    ranges: [
      { max: 2, severity: "normal", label: "Low risk for OSA" },
      { max: 4, severity: "mild", label: "Intermediate risk for OSA" },
      { max: 8, severity: "moderate", label: "High risk for OSA" },
    ],
  },
};

function getSeverityForScore(questionnaireName: string, score: number): string {
  const thresholds = scoreThresholds[questionnaireName];
  if (!thresholds) return "unknown";

  for (const range of thresholds.ranges) {
    if (score <= range.max) return range.severity;
  }
  return "severe";
}

export function ScoreDetailModal({
  isOpen,
  onClose,
  userId,
  score,
  questionResponses = [],
}: ScoreDetailModalProps) {
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [interpretation, setInterpretation] = useState<{
    clinicalNarrative: string;
    keyFindings: string[];
    riskFactors: string[];
    recommendations: string[];
    normativeComparison: string;
    clinicalSignificance: string;
  } | null>(null);

  // Get historical scores for trend analysis
  const allScores = useQuery(api.physician.getQuestionnaireScores, { userId });
  const historicalScores = allScores?.filter(
    (s) => s.questionnaire_name === score.questionnaire_name
  ) || [];

  // Fetch question responses if not provided
  const fetchedResponses = useQuery(
    api.physician.getQuestionnaireResponses,
    questionResponses.length === 0
      ? { userId, questionnaireName: score.questionnaire_name }
      : "skip"
  );

  // Use provided responses or fetched ones
  const displayResponses = questionResponses.length > 0
    ? questionResponses
    : (fetchedResponses || []);

  // LLM interpretation action
  const interpretScore = useAction(api.llm.interpretQuestionnaireScore);

  const severity = getSeverityForScore(score.questionnaire_name, score.score);
  const colors = severityColors[severity];
  const maxScore = score.max_score || 28;
  const percentage = Math.round((score.score / maxScore) * 100);

  // Calculate trend from historical scores
  const trend = historicalScores.length >= 2
    ? historicalScores[0].score - historicalScores[1].score
    : null;

  const handleGenerateInterpretation = async () => {
    setIsAnalyzing(true);
    try {
      const result = await interpretScore({
        userId,
        questionnaireName: score.questionnaire_name,
        score: score.score,
        maxScore,
        severity,
        questionResponses: displayResponses.map((q) => ({
          questionId: q.questionId,
          questionText: q.questionText,
          responseValue: q.responseValue,
          responseNumber: q.responseNumber,
        })),
      });
      setInterpretation(result);
    } catch (error) {
      console.error("Error generating interpretation:", error);
    } finally {
      setIsAnalyzing(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative w-full max-w-3xl max-h-[90vh] overflow-y-auto bg-gray-900 border border-gray-700 rounded-2xl shadow-2xl m-4">
        {/* Header */}
        <div className="sticky top-0 z-10 bg-gray-900/95 backdrop-blur-sm border-b border-gray-700 p-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className={`w-12 h-12 rounded-xl ${colors.bg} border ${colors.border} flex items-center justify-center`}>
                <Activity className={`w-6 h-6 ${colors.text}`} />
              </div>
              <div>
                <h2 className="text-xl font-bold text-white">{score.questionnaire_name}</h2>
                <p className="text-sm text-gray-400">
                  Completed {new Date(score.calculated_at).toLocaleDateString()}
                </p>
              </div>
            </div>
            <button
              onClick={onClose}
              className="p-2 rounded-lg hover:bg-gray-800 transition-colors"
            >
              <X className="w-5 h-5 text-gray-400" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 space-y-6">
          {/* Score Display */}
          <div className={`p-6 rounded-xl ${colors.bg} border ${colors.border}`}>
            <div className="flex items-center justify-between mb-4">
              <div>
                <p className="text-sm text-gray-400 mb-1">Total Score</p>
                <div className="flex items-baseline gap-2">
                  <span className={`text-4xl font-bold ${colors.text}`}>{score.score}</span>
                  <span className="text-lg text-gray-500">/ {maxScore}</span>
                </div>
              </div>
              <div className="text-right">
                <p className="text-sm text-gray-400 mb-1">Severity</p>
                <span className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-full ${colors.bg} ${colors.text} text-sm font-medium border ${colors.border}`}>
                  {severity === "normal" && <CheckCircle className="w-4 h-4" />}
                  {severity === "mild" && <Minus className="w-4 h-4" />}
                  {severity === "moderate" && <AlertTriangle className="w-4 h-4" />}
                  {severity === "severe" && <AlertTriangle className="w-4 h-4" />}
                  {severity.charAt(0).toUpperCase() + severity.slice(1)}
                </span>
              </div>
            </div>

            {/* Progress Bar */}
            <div className="h-3 bg-gray-800 rounded-full overflow-hidden">
              <div
                className={`h-full transition-all duration-500 ${
                  severity === "normal" ? "bg-green-500" :
                  severity === "mild" ? "bg-yellow-500" :
                  severity === "moderate" ? "bg-orange-500" : "bg-red-500"
                }`}
                style={{ width: `${percentage}%` }}
              />
            </div>

            {/* Trend Indicator */}
            {trend !== null && (
              <div className="mt-4 flex items-center gap-2">
                {trend < 0 ? (
                  <>
                    <TrendingDown className="w-4 h-4 text-green-400" />
                    <span className="text-sm text-green-400">
                      Improved by {Math.abs(trend)} points from last assessment
                    </span>
                  </>
                ) : trend > 0 ? (
                  <>
                    <TrendingUp className="w-4 h-4 text-red-400" />
                    <span className="text-sm text-red-400">
                      Increased by {trend} points from last assessment
                    </span>
                  </>
                ) : (
                  <>
                    <Minus className="w-4 h-4 text-gray-400" />
                    <span className="text-sm text-gray-400">No change from last assessment</span>
                  </>
                )}
              </div>
            )}
          </div>

          {/* Category & Interpretation */}
          {score.category && (
            <div className="p-4 bg-gray-800/50 rounded-xl border border-gray-700">
              <h3 className="text-sm font-medium text-gray-400 mb-2">Classification</h3>
              <p className="text-white font-medium">{score.category}</p>
              {score.interpretation && (
                <p className="text-gray-400 text-sm mt-2">{score.interpretation}</p>
              )}
            </div>
          )}

          {/* Historical Scores */}
          {historicalScores.length > 1 && (
            <div className="p-4 bg-gray-800/50 rounded-xl border border-gray-700">
              <div className="flex items-center gap-2 mb-3">
                <BarChart3 className="w-4 h-4 text-gray-400" />
                <h3 className="text-sm font-medium text-gray-400">Score History</h3>
              </div>
              <div className="space-y-2">
                {historicalScores.slice(0, 5).map((s, i) => (
                  <div key={s._id} className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">
                      {new Date(s.calculated_at).toLocaleDateString()}
                    </span>
                    <span className={`font-medium ${
                      getSeverityForScore(s.questionnaire_name, s.score) === "normal" ? "text-green-400" :
                      getSeverityForScore(s.questionnaire_name, s.score) === "mild" ? "text-yellow-400" :
                      getSeverityForScore(s.questionnaire_name, s.score) === "moderate" ? "text-orange-400" : "text-red-400"
                    }`}>
                      {s.score}/{s.max_score}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Question Responses */}
          <div className="p-4 bg-gray-800/50 rounded-xl border border-gray-700">
            <div className="flex items-center gap-2 mb-3">
              <FileText className="w-4 h-4 text-gray-400" />
              <h3 className="text-sm font-medium text-gray-400">
                Individual Responses {displayResponses.length > 0 && `(${displayResponses.length} questions)`}
              </h3>
            </div>
            {questionResponses.length === 0 && fetchedResponses === undefined ? (
              <div className="flex items-center justify-center py-6">
                <Loader2 className="w-5 h-5 text-gray-500 animate-spin" />
                <span className="ml-2 text-sm text-gray-500">Loading responses...</span>
              </div>
            ) : displayResponses.length > 0 ? (
              <div className="space-y-3 max-h-60 overflow-y-auto">
                {displayResponses.map((q, i) => (
                  <div key={i} className="flex items-start justify-between gap-4 p-3 bg-gray-900/50 rounded-lg">
                    <div className="flex-1 min-w-0">
                      <span className="text-xs text-gray-500 font-mono">{q.questionId}</span>
                      <p className="text-sm text-gray-300 truncate">{q.questionText}</p>
                    </div>
                    <div className="text-right">
                      <span className="text-sm font-medium text-white">{q.responseValue}</span>
                      {q.responseNumber !== undefined && (
                        <span className="text-xs text-gray-500 block">({q.responseNumber})</span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-6 text-gray-500">
                <FileText className="w-8 h-8 mx-auto mb-2 opacity-50" />
                <p className="text-sm">No question responses found for this questionnaire</p>
              </div>
            )}
          </div>

          {/* AI Interpretation */}
          <div className="p-4 bg-gray-800/50 rounded-xl border border-gray-700">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <Brain className="w-4 h-4 text-purple-400" />
                <h3 className="text-sm font-medium text-gray-400">AI Clinical Interpretation</h3>
              </div>
              {!interpretation && (
                <button
                  onClick={handleGenerateInterpretation}
                  disabled={isAnalyzing}
                  className="flex items-center gap-2 px-3 py-1.5 bg-purple-600 hover:bg-purple-700 disabled:bg-purple-600/50 text-white text-sm rounded-lg transition-colors"
                >
                  {isAnalyzing ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Analyzing...
                    </>
                  ) : (
                    <>
                      <Brain className="w-4 h-4" />
                      Generate Interpretation
                    </>
                  )}
                </button>
              )}
            </div>

            {interpretation ? (
              <div className="space-y-4">
                {/* Clinical Narrative */}
                <div>
                  <h4 className="text-xs font-medium text-purple-400 uppercase tracking-wider mb-1">
                    Clinical Summary
                  </h4>
                  <p className="text-gray-300 text-sm">{interpretation.clinicalNarrative}</p>
                </div>

                {/* Key Findings */}
                {interpretation.keyFindings.length > 0 && (
                  <div>
                    <h4 className="text-xs font-medium text-purple-400 uppercase tracking-wider mb-2">
                      Key Findings
                    </h4>
                    <ul className="space-y-1">
                      {interpretation.keyFindings.map((finding, i) => (
                        <li key={i} className="flex items-start gap-2 text-sm text-gray-300">
                          <CheckCircle className="w-4 h-4 text-teal-400 mt-0.5 flex-shrink-0" />
                          {finding}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                {/* Risk Factors */}
                {interpretation.riskFactors.length > 0 && (
                  <div>
                    <h4 className="text-xs font-medium text-purple-400 uppercase tracking-wider mb-2">
                      Risk Factors
                    </h4>
                    <ul className="space-y-1">
                      {interpretation.riskFactors.map((risk, i) => (
                        <li key={i} className="flex items-start gap-2 text-sm text-gray-300">
                          <AlertTriangle className="w-4 h-4 text-amber-400 mt-0.5 flex-shrink-0" />
                          {risk}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                {/* Recommendations */}
                {interpretation.recommendations.length > 0 && (
                  <div>
                    <h4 className="text-xs font-medium text-purple-400 uppercase tracking-wider mb-2">
                      Recommendations
                    </h4>
                    <ul className="space-y-1">
                      {interpretation.recommendations.map((rec, i) => (
                        <li key={i} className="flex items-start gap-2 text-sm text-gray-300">
                          <span className="w-5 h-5 rounded-full bg-teal-500/20 text-teal-400 flex items-center justify-center text-xs flex-shrink-0">
                            {i + 1}
                          </span>
                          {rec}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                {/* Normative Comparison */}
                <div className="pt-3 border-t border-gray-700">
                  <div className="flex items-start gap-2">
                    <BarChart3 className="w-4 h-4 text-gray-400 mt-0.5" />
                    <div>
                      <h4 className="text-xs font-medium text-gray-400 uppercase tracking-wider mb-1">
                        Normative Comparison
                      </h4>
                      <p className="text-sm text-gray-300">{interpretation.normativeComparison}</p>
                    </div>
                  </div>
                </div>

                {/* Clinical Significance */}
                <div className="p-3 bg-purple-500/10 border border-purple-500/30 rounded-lg">
                  <div className="flex items-center gap-2 text-purple-400 text-sm font-medium">
                    <Activity className="w-4 h-4" />
                    Clinical Significance
                  </div>
                  <p className="text-sm text-gray-300 mt-1">{interpretation.clinicalSignificance}</p>
                </div>
              </div>
            ) : (
              <div className="text-center py-6 text-gray-500">
                <Brain className="w-8 h-8 mx-auto mb-2 opacity-50" />
                <p className="text-sm">
                  Click &quot;Generate Interpretation&quot; to get AI-powered clinical insights
                </p>
              </div>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="sticky bottom-0 bg-gray-900/95 backdrop-blur-sm border-t border-gray-700 p-4 flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-gray-800 hover:bg-gray-700 text-white rounded-lg transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
