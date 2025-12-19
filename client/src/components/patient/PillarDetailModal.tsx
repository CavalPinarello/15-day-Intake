"use client";

import { useEffect, useState } from "react";
import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { X, TrendingUp, TrendingDown, Minus, AlertTriangle, CheckCircle, Clock, Loader2 } from "lucide-react";
import { PILLARS, PillarKey } from "./PillarSummaryCard";

interface PillarStatus {
  pillar: PillarKey;
  score: number | null;
  questionsAnswered: number;
  questionsTotal: number;
  trend: "improving" | "declining" | "stable" | null;
  alerts: string[];
}

interface PillarDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  userId: Id<"users">;
  pillar: PillarKey;
  pillarStatus: PillarStatus;
}

const getSeverityColor = (severity?: string) => {
  switch (severity?.toLowerCase()) {
    case "minimal":
    case "none":
    case "normal":
      return "bg-green-100 text-green-800 border-green-200";
    case "mild":
      return "bg-yellow-100 text-yellow-800 border-yellow-200";
    case "moderate":
      return "bg-orange-100 text-orange-800 border-orange-200";
    case "moderately severe":
    case "severe":
      return "bg-red-100 text-red-800 border-red-200";
    default:
      return "bg-gray-100 text-gray-800 border-gray-200";
  }
};

const getScoreColor = (score: number | null) => {
  if (score === null) return "text-gray-400";
  if (score >= 80) return "text-green-500";
  if (score >= 60) return "text-amber-500";
  if (score >= 40) return "text-orange-500";
  return "text-red-500";
};

const getTrendIcon = (trend: PillarStatus["trend"]) => {
  switch (trend) {
    case "improving":
      return <TrendingUp className="w-5 h-5 text-green-500" />;
    case "declining":
      return <TrendingDown className="w-5 h-5 text-red-500" />;
    case "stable":
      return <Minus className="w-5 h-5 text-gray-400" />;
    default:
      return null;
  }
};

export function PillarDetailModal({
  isOpen,
  onClose,
  userId,
  pillar,
  pillarStatus,
}: PillarDetailModalProps) {
  const pillarInfo = PILLARS[pillar];

  // Track which pillar we're currently querying to detect stale data
  const [queryPillar, setQueryPillar] = useState<PillarKey | null>(null);

  // Reset query pillar when modal opens with a new pillar
  useEffect(() => {
    if (isOpen) {
      setQueryPillar(pillar);
    } else {
      // Clear when modal closes to ensure fresh data on next open
      setQueryPillar(null);
    }
  }, [isOpen, pillar]);

  // Query pillar questions and responses
  const pillarResponses = useQuery(
    api.physician.getPillarResponses,
    isOpen ? { userId, pillarName: pillarInfo.name } : "skip"
  );

  // Check if query result matches current pillar (prevents showing stale data)
  const isDataStale = queryPillar !== pillar;
  const isLoading = !pillarResponses || isDataStale;

  if (!isOpen) return null;

  const answeredQuestions = pillarResponses?.questions.filter(
    (q) => q.responseValue || q.responseNumber !== undefined
  ) || [];
  const unansweredQuestions = pillarResponses?.questions.filter(
    (q) => !q.responseValue && q.responseNumber === undefined
  ) || [];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative bg-gray-900 rounded-2xl shadow-2xl max-w-2xl w-full mx-4 max-h-[85vh] overflow-hidden border border-gray-700">
        {/* Header */}
        <div
          className="px-6 py-4 border-b border-gray-700 flex items-center justify-between"
          style={{ backgroundColor: `${pillarInfo.color}15` }}
        >
          <div className="flex items-center gap-3">
            <span className="text-3xl">{pillarInfo.icon}</span>
            <div>
              <h2 className="text-xl font-semibold text-white">
                {pillarInfo.name}
              </h2>
              <p className="text-sm text-gray-400">{pillarInfo.description}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-gray-700 transition-colors"
          >
            <X className="w-5 h-5 text-gray-400" />
          </button>
        </div>

        {/* Score Summary */}
        <div className="px-6 py-4 border-b border-gray-700 bg-gray-800/50">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wider">
                  Pillar Score
                </p>
                <p className={`text-3xl font-bold ${getScoreColor(pillarStatus.score)}`}>
                  {pillarStatus.score !== null ? `${pillarStatus.score}%` : "N/A"}
                </p>
              </div>
              <div className="h-12 w-px bg-gray-700" />
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wider">
                  Completion
                </p>
                <p className="text-lg text-gray-300">
                  {pillarStatus.questionsAnswered}/{pillarStatus.questionsTotal} questions
                </p>
              </div>
              {pillarStatus.trend && (
                <>
                  <div className="h-12 w-px bg-gray-700" />
                  <div className="flex items-center gap-2">
                    {getTrendIcon(pillarStatus.trend)}
                    <span className="text-sm text-gray-400 capitalize">
                      {pillarStatus.trend}
                    </span>
                  </div>
                </>
              )}
            </div>

            {/* Progress Bar */}
            <div className="w-32">
              <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
                <div
                  className="h-full rounded-full transition-all"
                  style={{
                    width: `${pillarStatus.questionsTotal > 0
                      ? (pillarStatus.questionsAnswered / pillarStatus.questionsTotal) * 100
                      : 0}%`,
                    backgroundColor: pillarInfo.color,
                  }}
                />
              </div>
            </div>
          </div>

          {/* Alerts */}
          {pillarStatus.alerts.length > 0 && (
            <div className="mt-3 flex flex-wrap gap-2">
              {pillarStatus.alerts.map((alert, idx) => (
                <span
                  key={idx}
                  className="inline-flex items-center gap-1 px-2 py-1 bg-amber-900/30 text-amber-400 text-xs rounded-full border border-amber-700/50"
                >
                  <AlertTriangle className="w-3 h-3" />
                  {alert}
                </span>
              ))}
            </div>
          )}
        </div>

        {/* Content */}
        <div className="overflow-y-auto max-h-[50vh] px-6 py-4 space-y-6">
          {/* Clinical Summary (if available) */}
          {!isLoading && pillarResponses?.clinicalSummary && (
            <div className="rounded-xl border border-gray-700 bg-gray-800/50 p-4">
              <h3 className="text-sm font-medium text-gray-400 mb-3 flex items-center gap-2">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                Clinical Summary
              </h3>
              <div className="flex items-center justify-between">
                <div>
                  {pillarResponses.clinicalSummary.interpretation && (
                    <p className="text-gray-300 mb-2">
                      {pillarResponses.clinicalSummary.interpretation}
                    </p>
                  )}
                  {pillarResponses.clinicalSummary.severity && (
                    <span
                      className={`inline-block px-2 py-1 text-xs rounded-full border ${getSeverityColor(
                        pillarResponses.clinicalSummary.severity
                      )}`}
                    >
                      {pillarResponses.clinicalSummary.severity}
                    </span>
                  )}
                </div>
                {pillarResponses.clinicalSummary.score !== undefined && (
                  <div className="text-right">
                    <p className="text-2xl font-bold text-white">
                      {pillarResponses.clinicalSummary.score}
                      <span className="text-sm text-gray-500">
                        /{pillarResponses.clinicalSummary.maxScore}
                      </span>
                    </p>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Loading State */}
          {isLoading && (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="w-8 h-8 text-teal-500 animate-spin" />
              <span className="ml-2 text-gray-400">Loading {pillarInfo.name} data...</span>
            </div>
          )}

          {/* Answered Questions */}
          {!isLoading && answeredQuestions.length > 0 && (
            <div>
              <h3 className="text-sm font-medium text-gray-400 mb-3 flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                Answered Questions ({answeredQuestions.length})
              </h3>
              <div className="space-y-2">
                {answeredQuestions.map((q) => (
                  <div
                    key={q.questionId}
                    className="rounded-lg border border-gray-700 bg-gray-800/30 p-3"
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1">
                        <p className="text-xs text-gray-500 font-mono mb-1">
                          {q.questionId}
                        </p>
                        <p className="text-sm text-gray-300">{q.questionText}</p>
                      </div>
                      <div className="text-right">
                        <p className="font-medium text-white bg-gray-700 px-2 py-1 rounded text-sm">
                          {q.responseValue || q.responseNumber}
                        </p>
                        {q.dayNumber && (
                          <p className="text-xs text-gray-500 mt-1">Day {q.dayNumber}</p>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Unanswered Questions */}
          {!isLoading && unansweredQuestions.length > 0 && (
            <div>
              <h3 className="text-sm font-medium text-gray-400 mb-3 flex items-center gap-2">
                <Clock className="w-4 h-4 text-gray-500" />
                Pending Questions ({unansweredQuestions.length})
              </h3>
              <div className="space-y-2">
                {unansweredQuestions.slice(0, 5).map((q) => (
                  <div
                    key={q.questionId}
                    className="rounded-lg border border-gray-700/50 bg-gray-800/20 p-3 opacity-60"
                  >
                    <p className="text-xs text-gray-500 font-mono mb-1">
                      {q.questionId}
                    </p>
                    <p className="text-sm text-gray-400">{q.questionText}</p>
                  </div>
                ))}
                {unansweredQuestions.length > 5 && (
                  <p className="text-xs text-gray-500 text-center">
                    +{unansweredQuestions.length - 5} more questions pending
                  </p>
                )}
              </div>
            </div>
          )}

          {/* Empty State */}
          {!isLoading && pillarResponses && pillarResponses.questions.length === 0 && (
            <div className="text-center py-8">
              <p className="text-gray-500">No questions found for this pillar</p>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-gray-700 bg-gray-800/50">
          <button
            onClick={onClose}
            className="w-full px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
