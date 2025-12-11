"use client";

import { useState } from "react";
import { BentoCard } from "./BentoCard";

export type InsightSeverity = "critical" | "warning" | "info" | "positive";
export type InsightCategory =
  | "sleep_quality"
  | "mental_health"
  | "physical_health"
  | "behavioral"
  | "medication"
  | "lifestyle";

interface AIInsight {
  id: string;
  title: string;
  description: string;
  severity: InsightSeverity;
  category: InsightCategory;
  confidence: number; // 0-100
  suggestedActions?: string[];
  relatedQuestions?: string[];
  timestamp: string;
}

interface AIInsightsCardProps {
  insights: AIInsight[];
  onRunDeepAnalysis?: () => void;
  onInsightClick?: (insight: AIInsight) => void;
  isAnalyzing?: boolean;
  lastAnalysisTime?: string;
}

const severityConfig = {
  critical: {
    bg: "bg-red-500/20",
    border: "border-red-500/50",
    text: "text-red-400",
    icon: "⚠️",
    label: "Critical",
  },
  warning: {
    bg: "bg-amber-500/20",
    border: "border-amber-500/50",
    text: "text-amber-400",
    icon: "⚡",
    label: "Warning",
  },
  info: {
    bg: "bg-blue-500/20",
    border: "border-blue-500/50",
    text: "text-blue-400",
    icon: "💡",
    label: "Info",
  },
  positive: {
    bg: "bg-green-500/20",
    border: "border-green-500/50",
    text: "text-green-400",
    icon: "✓",
    label: "Positive",
  },
};

const categoryIcons: Record<InsightCategory, string> = {
  sleep_quality: "😴",
  mental_health: "🧠",
  physical_health: "💪",
  behavioral: "📊",
  medication: "💊",
  lifestyle: "🌿",
};

export function AIInsightsCard({
  insights,
  onRunDeepAnalysis,
  onInsightClick,
  isAnalyzing = false,
  lastAnalysisTime,
}: AIInsightsCardProps) {
  const [expandedInsight, setExpandedInsight] = useState<string | null>(null);

  // Sort insights by severity
  const sortedInsights = [...insights].sort((a, b) => {
    const order = { critical: 0, warning: 1, info: 2, positive: 3 };
    return order[a.severity] - order[b.severity];
  });

  const criticalCount = insights.filter((i) => i.severity === "critical").length;
  const warningCount = insights.filter((i) => i.severity === "warning").length;

  return (
    <BentoCard
      title="AI Insights"
      subtitle={lastAnalysisTime ? `Last analyzed ${lastAnalysisTime}` : "GPT-4o analysis"}
      size="medium"
      icon={
        <svg
          className="w-4 h-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
          />
        </svg>
      }
      badge={
        criticalCount > 0
          ? { text: `${criticalCount} critical`, variant: "error" }
          : warningCount > 0
          ? { text: `${warningCount} warning`, variant: "warning" }
          : insights.length > 0
          ? { text: `${insights.length} insights`, variant: "info" }
          : undefined
      }
    >
      <div className="flex flex-col h-full">
        {/* Insights list */}
        <div className="flex-1 overflow-y-auto space-y-2 mb-3">
          {sortedInsights.length === 0 ? (
            <div className="h-full flex items-center justify-center text-center text-gray-500">
              <div>
                <div className="text-2xl mb-2">🔍</div>
                <p className="text-sm">No insights yet</p>
                <p className="text-xs">Run deep analysis to generate insights</p>
              </div>
            </div>
          ) : (
            sortedInsights.slice(0, 5).map((insight) => {
              const config = severityConfig[insight.severity];
              const isExpanded = expandedInsight === insight.id;

              return (
                <button
                  key={insight.id}
                  onClick={() => {
                    setExpandedInsight(isExpanded ? null : insight.id);
                    onInsightClick?.(insight);
                  }}
                  className={`
                    w-full text-left p-2 rounded-lg border transition-all
                    ${config.bg} ${config.border}
                    hover:brightness-110
                  `}
                >
                  <div className="flex items-start gap-2">
                    <span className="text-sm">{categoryIcons[insight.category]}</span>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className={`text-xs font-medium ${config.text}`}>
                          {config.icon} {config.label}
                        </span>
                        <span className="text-[10px] text-gray-500">
                          {insight.confidence}% confident
                        </span>
                      </div>
                      <p className="text-sm text-white font-medium truncate">
                        {insight.title}
                      </p>
                      {isExpanded && (
                        <div className="mt-2 space-y-2">
                          <p className="text-xs text-gray-300">
                            {insight.description}
                          </p>
                          {insight.suggestedActions &&
                            insight.suggestedActions.length > 0 && (
                              <div className="pt-2 border-t border-gray-700">
                                <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">
                                  Suggested Actions
                                </p>
                                <ul className="space-y-1">
                                  {insight.suggestedActions.map((action, i) => (
                                    <li
                                      key={i}
                                      className="text-xs text-gray-300 flex items-start gap-1"
                                    >
                                      <span className="text-gray-500">•</span>
                                      {action}
                                    </li>
                                  ))}
                                </ul>
                              </div>
                            )}
                        </div>
                      )}
                    </div>
                  </div>
                </button>
              );
            })
          )}
        </div>

        {/* Deep Analysis button */}
        {onRunDeepAnalysis && (
          <button
            onClick={onRunDeepAnalysis}
            disabled={isAnalyzing}
            className={`
              w-full py-2 px-3 rounded-lg font-medium text-sm
              transition-all flex items-center justify-center gap-2
              ${
                isAnalyzing
                  ? "bg-gray-700 text-gray-400 cursor-not-allowed"
                  : "bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-500 hover:to-blue-500 text-white"
              }
            `}
          >
            {isAnalyzing ? (
              <>
                <svg
                  className="animate-spin h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <circle
                    className="opacity-25"
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="currentColor"
                    strokeWidth="4"
                  />
                  <path
                    className="opacity-75"
                    fill="currentColor"
                    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                  />
                </svg>
                Analyzing...
              </>
            ) : (
              <>
                <svg
                  className="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
                Run Deep Analysis
              </>
            )}
          </button>
        )}
      </div>
    </BentoCard>
  );
}

// Inline insight badges for use in other cards
export function InsightBadges({
  insights,
  maxShow = 3,
}: {
  insights: AIInsight[];
  maxShow?: number;
}) {
  const criticalInsights = insights.filter((i) => i.severity === "critical");
  const warningInsights = insights.filter((i) => i.severity === "warning");
  const displayInsights = [...criticalInsights, ...warningInsights].slice(
    0,
    maxShow
  );

  if (displayInsights.length === 0) return null;

  return (
    <div className="flex flex-wrap gap-1">
      {displayInsights.map((insight) => {
        const config = severityConfig[insight.severity];
        return (
          <span
            key={insight.id}
            className={`
              inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-medium
              ${config.bg} ${config.text} border ${config.border}
            `}
            title={insight.description}
          >
            {config.icon} {insight.title}
          </span>
        );
      })}
      {insights.length > maxShow && (
        <span className="text-[10px] text-gray-500">
          +{insights.length - maxShow} more
        </span>
      )}
    </div>
  );
}

// Generate sample insights from patient data (for demo purposes)
export function generateSampleInsights(patientData: {
  isiScore?: number;
  phq9Score?: number;
  gad7Score?: number;
  avgSleepHours?: number;
  sleepEfficiency?: number;
}): AIInsight[] {
  const insights: AIInsight[] = [];
  const now = new Date().toISOString();

  if (patientData.isiScore && patientData.isiScore >= 22) {
    insights.push({
      id: "isi-severe",
      title: "Severe Insomnia Detected",
      description: `ISI score of ${patientData.isiScore} indicates clinical insomnia. Consider CBT-I referral and sleep restriction therapy.`,
      severity: "critical",
      category: "sleep_quality",
      confidence: 95,
      suggestedActions: [
        "Refer for CBT-I evaluation",
        "Review current sleep medications",
        "Consider sleep study if not recently done",
      ],
      timestamp: now,
    });
  }

  if (patientData.phq9Score && patientData.phq9Score >= 15) {
    insights.push({
      id: "phq9-modsevere",
      title: "Moderately Severe Depression",
      description: `PHQ-9 score of ${patientData.phq9Score} indicates moderately severe depression, which may be contributing to sleep difficulties.`,
      severity: "critical",
      category: "mental_health",
      confidence: 92,
      suggestedActions: [
        "Screen for suicidal ideation",
        "Consider antidepressant medication adjustment",
        "Recommend therapy/counseling",
      ],
      timestamp: now,
    });
  }

  if (patientData.avgSleepHours && patientData.avgSleepHours < 5) {
    insights.push({
      id: "short-sleep",
      title: "Chronically Short Sleep",
      description: `Average sleep of ${patientData.avgSleepHours.toFixed(1)} hours is significantly below recommended 7-9 hours.`,
      severity: "warning",
      category: "sleep_quality",
      confidence: 88,
      suggestedActions: [
        "Review sleep schedule and bedtime routine",
        "Identify barriers to adequate sleep time",
        "Consider time-in-bed restriction paradoxically",
      ],
      timestamp: now,
    });
  }

  if (patientData.sleepEfficiency && patientData.sleepEfficiency < 75) {
    insights.push({
      id: "low-efficiency",
      title: "Low Sleep Efficiency",
      description: `Sleep efficiency of ${patientData.sleepEfficiency}% suggests significant time awake in bed.`,
      severity: "warning",
      category: "behavioral",
      confidence: 85,
      suggestedActions: [
        "Implement stimulus control therapy",
        "Reduce time in bed to match actual sleep",
        "Review sleep hygiene practices",
      ],
      timestamp: now,
    });
  }

  return insights;
}
