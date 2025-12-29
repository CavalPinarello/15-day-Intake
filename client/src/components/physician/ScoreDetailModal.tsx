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
  Link2,
  User,
  Heart,
} from "lucide-react";

interface QuestionResponse {
  questionId: string;
  questionText: string;
  responseValue: string;
  responseNumber?: number;
  isDerived?: boolean;
  derivedFromQuestionId?: string;
  responseSource?: string; // "user" (default), "profile", "derived", "healthkit"
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
  PSQI: {
    ranges: [
      { max: 5, severity: "normal", label: "Good sleep quality" },
      { max: 10, severity: "mild", label: "Poor sleep quality" },
      { max: 15, severity: "moderate", label: "Moderate sleep difficulty" },
      { max: 21, severity: "severe", label: "Severe sleep difficulty" },
    ],
  },
  "DBAS-16": {
    ranges: [
      { max: 40, severity: "normal", label: "Low dysfunctional beliefs" },
      { max: 80, severity: "mild", label: "Mild dysfunctional beliefs" },
      { max: 120, severity: "moderate", label: "Moderate dysfunctional beliefs" },
      { max: 160, severity: "severe", label: "Severe dysfunctional beliefs" },
    ],
  },
  FSS: {
    ranges: [
      { max: 3, severity: "normal", label: "No significant fatigue" },
      { max: 4, severity: "mild", label: "Mild fatigue" },
      { max: 5, severity: "moderate", label: "Moderate fatigue" },
      { max: 7, severity: "severe", label: "Severe fatigue" },
    ],
  },
  "FOSQ-10": {
    ranges: [
      { max: 15, severity: "severe", label: "Severe functional impairment" },
      { max: 25, severity: "moderate", label: "Moderate functional impairment" },
      { max: 35, severity: "mild", label: "Mild functional impairment" },
      { max: 40, severity: "normal", label: "Normal functioning" },
    ],
  },
  "DASS-21": {
    ranges: [
      { max: 9, severity: "normal", label: "Normal" },
      { max: 13, severity: "mild", label: "Mild" },
      { max: 20, severity: "moderate", label: "Moderate" },
      { max: 27, severity: "severe", label: "Severe" },
    ],
  },
  Berlin: {
    ranges: [
      { max: 1, severity: "normal", label: "Low risk for OSA" },
      { max: 3, severity: "moderate", label: "High risk for OSA" },
    ],
  },
  BPI: {
    ranges: [
      { max: 3, severity: "normal", label: "Mild pain" },
      { max: 5, severity: "mild", label: "Moderate pain" },
      { max: 7, severity: "moderate", label: "Moderately severe pain" },
      { max: 10, severity: "severe", label: "Severe pain" },
    ],
  },
  MEDAS: {
    ranges: [
      { max: 5, severity: "severe", label: "Poor Mediterranean diet adherence" },
      { max: 8, severity: "moderate", label: "Moderate Mediterranean diet adherence" },
      { max: 11, severity: "mild", label: "Good Mediterranean diet adherence" },
      { max: 14, severity: "normal", label: "High Mediterranean diet adherence" },
    ],
  },
  PROMIS: {
    ranges: [
      { max: 40, severity: "severe", label: "Severe cognitive impairment" },
      { max: 45, severity: "moderate", label: "Moderate cognitive impairment" },
      { max: 50, severity: "mild", label: "Mild cognitive impairment" },
      { max: 100, severity: "normal", label: "Normal cognitive function" },
    ],
  },
  "Sleep Hygiene": {
    ranges: [
      { max: 20, severity: "normal", label: "Good sleep hygiene" },
      { max: 30, severity: "mild", label: "Fair sleep hygiene" },
      { max: 40, severity: "moderate", label: "Poor sleep hygiene" },
      { max: 50, severity: "severe", label: "Very poor sleep hygiene" },
    ],
  },
  "PSAS-Cognitive": {
    ranges: [
      { max: 16, severity: "normal", label: "Low cognitive arousal" },
      { max: 24, severity: "mild", label: "Mild cognitive arousal" },
      { max: 32, severity: "moderate", label: "Moderate cognitive arousal" },
      { max: 40, severity: "severe", label: "High cognitive arousal" },
    ],
  },
  "PSAS-Somatic": {
    ranges: [
      { max: 16, severity: "normal", label: "Low somatic arousal" },
      { max: 24, severity: "mild", label: "Mild somatic arousal" },
      { max: 32, severity: "moderate", label: "Moderate somatic arousal" },
      { max: 40, severity: "severe", label: "High somatic arousal" },
    ],
  },
};

// Map full questionnaire names to their abbreviations for threshold lookup
const questionnaireNameToAbbreviation: Record<string, string> = {
  "Insomnia Severity Index": "ISI",
  "Patient Health Questionnaire": "PHQ-9",
  "Patient Health Questionnaire-9": "PHQ-9",
  "Generalized Anxiety Disorder": "GAD-7",
  "Generalized Anxiety Disorder-7": "GAD-7",
  "Epworth Sleepiness Scale": "ESS",
  "STOP-BANG Sleep Apnea Screening": "STOP-BANG",
  "Pittsburgh Sleep Quality Index": "PSQI",
  "Dysfunctional Beliefs and Attitudes about Sleep": "DBAS-16",
  "Fatigue Severity Scale": "FSS",
  "Functional Outcomes of Sleep Questionnaire": "FOSQ-10",
  "Depression Anxiety Stress Scales": "DASS-21",
  "Berlin Questionnaire": "Berlin",
  "Brief Pain Inventory": "BPI",
  "Mediterranean Diet Adherence Screener": "MEDAS",
  "Morningness-Eveningness Questionnaire": "MEQ",
  "PROMIS Cognitive Function": "PROMIS",
  "PROMIS Cognitive": "PROMIS",
  "Sleep Hygiene Index": "Sleep Hygiene",
  "Pre-Sleep Arousal Scale": "PSAS-Cognitive",
  "Pre-Sleep Arousal Scale - Cognitive": "PSAS-Cognitive",
  "Pre-Sleep Arousal Scale - Somatic": "PSAS-Somatic",
};

function getSeverityForScore(questionnaireName: string, score: number): string {
  // Try direct lookup first
  let thresholds = scoreThresholds[questionnaireName];

  // If not found, try normalized abbreviation
  if (!thresholds) {
    const abbreviation = questionnaireNameToAbbreviation[questionnaireName];
    if (abbreviation) {
      thresholds = scoreThresholds[abbreviation];
    }
  }

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
  type ScoreType = NonNullable<typeof allScores>[number];
  const historicalScores = allScores?.filter(
    (s: ScoreType) => s.questionnaire_name === score.questionnaire_name
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

  // Get correct max score for each questionnaire type
  const questionnaireMaxScores: Record<string, number> = {
    "ISI": 28,
    "Insomnia Severity Index": 28,
    "PHQ-9": 27,
    "Patient Health Questionnaire": 27,
    "GAD-7": 21,
    "Generalized Anxiety Disorder": 21,
    "ESS": 24,
    "Epworth Sleepiness Scale": 24,
    "STOP-BANG": 8,
    "STOP-BANG Sleep Apnea Screening": 8,
    "PSQI": 21,
    "Pittsburgh Sleep Quality Index": 21,
    "DBAS-16": 160,
    "Dysfunctional Beliefs and Attitudes about Sleep": 160,
    "FSS": 63,
    "Fatigue Severity Scale": 63,
    "FOSQ-10": 40,
    "Functional Outcomes of Sleep Questionnaire": 40,
    "DASS-21": 63,
    "Depression Anxiety Stress Scales": 63,
    "Berlin": 3,
    "Berlin Questionnaire": 3,
    "BPI": 10,
    "Brief Pain Inventory": 10,
    "MEDAS": 14,
    "Mediterranean Diet Adherence Screener": 14,
    "MEQ": 86,
    "Morningness-Eveningness Questionnaire": 86,
    "PROMIS": 100,
    "PROMIS Cognitive": 100,
    "Sleep Hygiene": 50,
    "Sleep Hygiene Index": 50,
    "PSAS-Cognitive": 40,
    "PSAS-Somatic": 40,
    "Pre-Sleep Arousal Scale": 80,
  };
  const maxScore = score.max_score || questionnaireMaxScores[score.questionnaire_name] || 28;
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
        questionResponses: displayResponses.map((q: QuestionResponse) => ({
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
                {historicalScores.slice(0, 5).map((s: ScoreType) => (
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
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <FileText className="w-4 h-4 text-gray-400" />
                <h3 className="text-sm font-medium text-gray-400">
                  Individual Responses {displayResponses.length > 0 && `(${displayResponses.length} questions)`}
                </h3>
              </div>
              <div className="flex flex-wrap gap-2">
                {displayResponses.some((q: QuestionResponse) => q.responseSource === "profile") && (
                  <span className="inline-flex items-center gap-1.5 px-2 py-1 bg-blue-500/10 text-blue-400 text-xs rounded-full border border-blue-500/20">
                    <User className="w-3 h-3" />
                    {displayResponses.filter((q: QuestionResponse) => q.responseSource === "profile").length} from onboarding
                  </span>
                )}
                {displayResponses.some((q: QuestionResponse) => q.isDerived || q.responseSource === "derived") && (
                  <span className="inline-flex items-center gap-1.5 px-2 py-1 bg-amber-500/10 text-amber-400 text-xs rounded-full border border-amber-500/20">
                    <Link2 className="w-3 h-3" />
                    {displayResponses.filter((q: QuestionResponse) => q.isDerived || q.responseSource === "derived").length} derived
                  </span>
                )}
              </div>
            </div>
            {questionResponses.length === 0 && fetchedResponses === undefined ? (
              <div className="flex items-center justify-center py-6">
                <Loader2 className="w-5 h-5 text-gray-500 animate-spin" />
                <span className="ml-2 text-sm text-gray-500">Loading responses...</span>
              </div>
            ) : displayResponses.length > 0 ? (
              <div className="space-y-3 max-h-60 overflow-y-auto">
                {displayResponses.map((q: QuestionResponse, i: number) => (
                  <div key={i} className={`flex items-start justify-between gap-4 p-3 rounded-lg ${
                    q.isDerived ? "bg-amber-900/20 border border-amber-500/20" : "bg-gray-900/50"
                  }`}>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-gray-500 font-mono">{q.questionId}</span>
                        {q.responseSource === "profile" && (
                          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-blue-500/20 text-blue-400 text-xs rounded border border-blue-500/30" title="Auto-filled from onboarding profile">
                            <User className="w-3 h-3" />
                            From Onboarding
                          </span>
                        )}
                        {q.responseSource === "healthkit" && (
                          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-green-500/20 text-green-400 text-xs rounded border border-green-500/30" title="Auto-filled from Apple Health">
                            <Heart className="w-3 h-3" />
                            From HealthKit
                          </span>
                        )}
                        {(q.isDerived || q.responseSource === "derived") && (
                          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 bg-amber-500/20 text-amber-400 text-xs rounded border border-amber-500/30" title={`Derived from ${q.derivedFromQuestionId || "profile data"}`}>
                            <Link2 className="w-3 h-3" />
                            Derived
                          </span>
                        )}
                      </div>
                      <p className="text-sm text-gray-300 truncate">{q.questionText}</p>
                      {q.isDerived && q.derivedFromQuestionId && (
                        <p className="text-xs text-amber-400/70 mt-0.5">
                          Inferred from response to {q.derivedFromQuestionId}
                        </p>
                      )}
                      {q.responseSource === "profile" && (
                        <p className="text-xs text-blue-400/70 mt-0.5">
                          Auto-filled from user profile during onboarding
                        </p>
                      )}
                    </div>
                    <div className="text-right">
                      <span className={`text-sm font-medium ${q.isDerived ? "text-amber-300" : "text-white"}`}>
                        {q.responseValue}
                      </span>
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
