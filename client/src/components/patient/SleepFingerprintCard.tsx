"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import {
  Brain,
  Eye,
  Calendar,
  Activity,
  Sunrise,
  Moon,
  Clock,
  Lightbulb,
  ChevronDown,
  ChevronUp,
  Lock,
  Fingerprint,
  CheckCircle,
} from "lucide-react";
import { useState } from "react";

interface SleepFingerprintCardProps {
  userId: Id<"users">;
}

interface SleepPattern {
  id: string;
  name: string;
  description: string;
  evidence: string[];
  confidence: number;
  confidence_label: string;
}

export function SleepFingerprintCard({ userId }: SleepFingerprintCardProps) {
  const fingerprint = useQuery(api.sleepPhenotype.getSleepFingerprint, { userId });
  const [isExpanded, setIsExpanded] = useState(false);
  const [selectedPattern, setSelectedPattern] = useState<SleepPattern | null>(null);

  if (!fingerprint) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-6 animate-pulse">
        <div className="h-6 bg-gray-700 rounded w-1/2 mb-4"></div>
        <div className="h-20 bg-gray-700 rounded mb-4"></div>
        <div className="h-4 bg-gray-700 rounded w-3/4"></div>
      </div>
    );
  }

  const phenotypeConfig: Record<string, { color: string; gradient: string; icon: typeof Brain }> = {
    tired_but_wired: { color: "purple", gradient: "from-purple-500/20 to-violet-500/20", icon: Brain },
    sleep_state_misperception: { color: "blue", gradient: "from-blue-500/20 to-cyan-500/20", icon: Eye },
    compensator: { color: "orange", gradient: "from-orange-500/20 to-amber-500/20", icon: Calendar },
    irregular_rhythm: { color: "yellow", gradient: "from-yellow-500/20 to-amber-500/20", icon: Activity },
    fragmented_sleeper: { color: "red", gradient: "from-red-500/20 to-rose-500/20", icon: Activity },
    early_terminator: { color: "pink", gradient: "from-pink-500/20 to-rose-500/20", icon: Sunrise },
    delayed_phase: { color: "indigo", gradient: "from-indigo-500/20 to-purple-500/20", icon: Moon },
    efficiency_struggler: { color: "teal", gradient: "from-teal-500/20 to-cyan-500/20", icon: Clock },
  };

  if (!fingerprint.has_fingerprint) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-6">
        {/* Locked State */}
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 rounded-lg bg-gray-700/50 flex items-center justify-center">
            <Fingerprint className="w-5 h-5 text-gray-500" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-white">Sleep Fingerprint</h3>
            <p className="text-xs text-gray-500">Locked</p>
          </div>
          <Lock className="w-4 h-4 text-gray-500 ml-auto" />
        </div>

        <div className="flex flex-col items-center py-8">
          <div className="w-20 h-20 rounded-full bg-gray-700/30 flex items-center justify-center mb-4">
            <Fingerprint className="w-10 h-10 text-gray-600" />
          </div>
          <p className="text-2xl font-bold text-white mb-1">
            {fingerprint.days_until_available} more nights
          </p>
          <p className="text-sm text-gray-400 mb-4">to unlock Sleep Fingerprint</p>

          {/* Progress dots */}
          <div className="flex gap-1.5 mb-4">
            {Array.from({ length: 7 }).map((_, i) => (
              <div
                key={i}
                className={`w-2 h-2 rounded-full ${
                  i < 7 - (fingerprint.days_until_available ?? 0)
                    ? "bg-blue-500"
                    : "bg-gray-600"
                }`}
              />
            ))}
          </div>

          <p className="text-xs text-gray-500 text-center">{fingerprint.teaser}</p>
        </div>
      </div>
    );
  }

  const config = phenotypeConfig[fingerprint.phenotype || ""] || {
    color: "blue",
    gradient: "from-blue-500/20 to-cyan-500/20",
    icon: Brain,
  };
  const Icon = config.icon;

  const patterns = (fingerprint.patterns || []) as SleepPattern[];
  const leveragePoints = (fingerprint.leverage_points || []) as Array<{
    intervention_type: string;
    reason: string;
    priority: number;
  }>;

  const formatLeveragePoint = (point: string): string => {
    return point
      .replace(/_/g, " ")
      .split(" ")
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(" ");
  };

  return (
    <div
      className={`bg-gradient-to-br ${config.gradient} backdrop-blur-sm border border-${config.color}-500/30 rounded-xl overflow-hidden`}
    >
      {/* Header */}
      <div className="p-6 pb-4">
        <div className="flex items-start gap-4">
          <div
            className={`w-14 h-14 rounded-xl bg-gradient-to-br from-${config.color}-500/30 to-${config.color}-600/10 flex items-center justify-center`}
          >
            <Icon className={`w-7 h-7 text-${config.color}-400`} />
          </div>
          <div className="flex-1">
            <p className={`text-[10px] font-semibold uppercase tracking-wider text-${config.color}-400 mb-1`}>
              Your Sleep Fingerprint
            </p>
            <h3 className="text-xl font-bold text-white">{fingerprint.title}</h3>
            <p className="text-xs text-gray-400 mt-0.5">Week {fingerprint.week_number} Analysis</p>
          </div>
        </div>

        {/* Description */}
        <p className="text-sm text-gray-300 mt-4 leading-relaxed">{fingerprint.description}</p>

        {/* Confidence Bar */}
        <div className="mt-4 p-3 bg-black/20 rounded-lg">
          <div className="flex justify-between items-center mb-2">
            <span className="text-xs text-gray-400">Confidence</span>
            <span className={`text-xs font-semibold text-${config.color}-400`}>
              {fingerprint.confidence}%
            </span>
          </div>
          <div className="h-1.5 bg-gray-700/50 rounded-full overflow-hidden">
            <div
              className={`h-full bg-${config.color}-500 rounded-full transition-all duration-500`}
              style={{ width: `${fingerprint.confidence}%` }}
            />
          </div>
        </div>

        {/* Expand Button */}
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className={`w-full mt-4 flex items-center justify-center gap-2 text-sm font-medium text-${config.color}-400 hover:text-${config.color}-300 transition-colors`}
        >
          {isExpanded ? "Show Less" : "See Your Patterns"}
          {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
        </button>
      </div>

      {/* Expanded Content */}
      {isExpanded && (
        <div className="border-t border-gray-700/50 p-6 pt-4 space-y-6">
          {/* Patterns Section */}
          {patterns.length > 0 && (
            <div>
              <h4 className="text-[10px] font-semibold uppercase tracking-wider text-gray-400 mb-3">
                Detected Patterns
              </h4>
              <div className="space-y-2">
                {patterns.map((pattern) => (
                  <button
                    key={pattern.id}
                    onClick={() => setSelectedPattern(pattern)}
                    className="w-full flex items-center gap-3 p-3 bg-gray-800/50 hover:bg-gray-800/70 rounded-lg transition-colors text-left"
                  >
                    <div className={`w-2 h-2 rounded-full bg-${config.color}-500`} />
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-white truncate">{pattern.name}</p>
                      <p className="text-xs text-gray-400 truncate">{pattern.description}</p>
                    </div>
                    <span
                      className={`text-[10px] font-medium px-2 py-1 rounded-full bg-${config.color}-500/20 text-${config.color}-400`}
                    >
                      {pattern.confidence_label}
                    </span>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Leverage Points Section */}
          {leveragePoints.length > 0 && (
            <div className="p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Lightbulb className="w-4 h-4 text-yellow-400" />
                <h4 className="text-[10px] font-semibold uppercase tracking-wider text-gray-400">
                  What Can Help
                </h4>
              </div>
              <div className="space-y-2">
                {leveragePoints.slice(0, 3).map((point, index) => (
                  <div key={index} className="flex items-start gap-2">
                    <CheckCircle className="w-4 h-4 text-green-400 mt-0.5 flex-shrink-0" />
                    <span className="text-sm text-white">
                      {formatLeveragePoint(point.intervention_type)}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Pattern Detail Modal */}
      {selectedPattern && (
        <div
          className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4"
          onClick={() => setSelectedPattern(null)}
        >
          <div
            className={`bg-gray-900 border border-${config.color}-500/30 rounded-xl max-w-md w-full max-h-[80vh] overflow-y-auto`}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="p-6">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-xl font-bold text-white">{selectedPattern.name}</h3>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="text-sm text-gray-400">Confidence:</span>
                    <span className={`text-sm font-semibold text-${config.color}-400`}>
                      {selectedPattern.confidence}%
                    </span>
                    <span className="text-sm text-gray-500">({selectedPattern.confidence_label})</span>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedPattern(null)}
                  className="text-gray-400 hover:text-white transition-colors"
                >
                  &times;
                </button>
              </div>

              <p className="text-gray-300 mb-6">{selectedPattern.description}</p>

              <div className={`p-4 bg-${config.color}-500/10 border border-${config.color}-500/20 rounded-lg`}>
                <h4 className="text-sm font-semibold text-white mb-3 flex items-center gap-2">
                  <Activity className={`w-4 h-4 text-${config.color}-400`} />
                  Evidence
                </h4>
                <ul className="space-y-2">
                  {selectedPattern.evidence.map((evidence, index) => (
                    <li key={index} className="flex items-start gap-2 text-sm text-gray-300">
                      <CheckCircle className={`w-4 h-4 text-${config.color}-400 mt-0.5 flex-shrink-0`} />
                      {evidence}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/**
 * Cohort Percentile Card - Shows user's percentile within their cohort
 */
interface CohortPercentileCardProps {
  userId: Id<"users">;
  metricType: "isi" | "sleep_efficiency" | "sleep_duration";
}

export function CohortPercentileCard({ userId, metricType }: CohortPercentileCardProps) {
  const percentileData = useQuery(api.microCohorts.getCohortPercentile, { userId, metricType });

  if (!percentileData) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4 animate-pulse">
        <div className="h-4 bg-gray-700 rounded w-1/3 mb-3"></div>
        <div className="h-8 bg-gray-700 rounded w-1/2"></div>
      </div>
    );
  }

  const getPercentileColor = (percentile: number | null): string => {
    if (!percentile) return "gray";
    if (percentile >= 75) return "green";
    if (percentile >= 50) return "blue";
    if (percentile >= 25) return "yellow";
    return "orange";
  };

  const color = getPercentileColor(percentileData.percentile);

  const formatValue = (value: number | undefined, type: string): string => {
    if (value === undefined) return "-";
    switch (type) {
      case "isi":
        return value.toFixed(0);
      case "sleep_efficiency":
        return `${value.toFixed(0)}%`;
      case "sleep_duration":
        const hours = Math.floor(value / 60);
        const mins = Math.round(value % 60);
        return `${hours}h ${mins}m`;
      default:
        return value.toFixed(1);
    }
  };

  return (
    <div className={`bg-gradient-to-br from-${color}-500/10 to-${color}-600/5 backdrop-blur-sm border border-${color}-500/30 rounded-xl p-4`}>
      <div className="flex items-start justify-between mb-3">
        <div>
          <p className={`text-[10px] font-semibold uppercase tracking-wider text-${color}-400 mb-1`}>
            Among People Like You
          </p>
          <p className="text-sm font-medium text-white">
            {percentileData.cohort_description || "Similar users"}
          </p>
        </div>

        {percentileData.percentile !== null && (
          <div className="relative w-14 h-14">
            <svg className="w-full h-full -rotate-90">
              <circle
                cx="28"
                cy="28"
                r="24"
                fill="none"
                stroke="currentColor"
                strokeWidth="4"
                className={`text-${color}-900/50`}
              />
              <circle
                cx="28"
                cy="28"
                r="24"
                fill="none"
                stroke="currentColor"
                strokeWidth="4"
                strokeDasharray={`${(percentileData.percentile / 100) * 150.8} 150.8`}
                strokeLinecap="round"
                className={`text-${color}-500`}
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className={`text-sm font-bold text-${color}-400`}>
                {percentileData.percentile}
              </span>
              <span className={`text-[8px] text-${color}-400/80`}>%</span>
            </div>
          </div>
        )}
      </div>

      <p className="text-sm text-gray-300 mb-4">{percentileData.message}</p>

      {percentileData.user_value !== undefined && percentileData.cohort_mean !== undefined && (
        <div className="flex gap-4">
          <div className={`flex-1 p-3 bg-${color}-500/10 rounded-lg text-center`}>
            <p className={`text-lg font-bold text-${color}-400`}>
              {formatValue(percentileData.user_value, metricType)}
            </p>
            <p className="text-[10px] text-gray-400">You</p>
          </div>
          <div className="flex-1 p-3 bg-gray-700/30 rounded-lg text-center">
            <p className="text-lg font-bold text-gray-400">
              {formatValue(percentileData.cohort_mean, metricType)}
            </p>
            <p className="text-[10px] text-gray-400">Cohort Avg</p>
          </div>
        </div>
      )}

      <p className="text-[10px] text-gray-500 mt-3 flex items-center gap-1">
        <span className="inline-block w-2 h-2 bg-gray-600 rounded-full" />
        Based on {percentileData.cohort_size}+ similar users
      </p>
    </div>
  );
}
