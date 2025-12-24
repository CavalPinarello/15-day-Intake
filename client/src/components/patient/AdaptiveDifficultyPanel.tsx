"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState } from "react";
import {
  Lock,
  Unlock,
  TrendingDown,
  TrendingUp,
  Minus,
  Settings,
  AlertTriangle,
  CheckCircle,
  Clock,
  ChevronDown,
  ChevronUp,
} from "lucide-react";

interface AdaptiveDifficultyPanelProps {
  userId: Id<"users">;
  physicianId?: string;
}

interface DifficultyEntry {
  interventionId: string;
  interventionName: string;
  currentDifficulty: number;
  originalDifficulty: number;
  rolling7DayCompliance: number;
  consecutiveLowDays: number;
  consecutiveHighDays: number;
  difficultyLocked: boolean;
  lockedByPhysicianId?: string;
  lastAdjustmentDate?: string;
  adjustmentReason?: string;
}

export function AdaptiveDifficultyPanel({
  userId,
  physicianId,
}: AdaptiveDifficultyPanelProps) {
  const [expandedIntervention, setExpandedIntervention] = useState<string | null>(null);

  // Fetch difficulty status
  const difficultyStatus = useQuery(api.adaptiveDifficulty.getDifficultyStatus, {
    userId,
  });

  // Mutations
  const lockDifficulty = useMutation(api.adaptiveDifficulty.lockDifficulty);
  const adjustDifficulty = useMutation(api.adaptiveDifficulty.adjustDifficulty);

  const handleToggleLock = async (entry: DifficultyEntry) => {
    if (!physicianId) return;

    try {
      await lockDifficulty({
        userId,
        interventionId: entry.interventionId,
        locked: !entry.difficultyLocked,
        physicianId,
      });
    } catch (error) {
      console.error("Failed to toggle lock:", error);
    }
  };

  const handleManualAdjust = async (entry: DifficultyEntry, newDifficulty: number) => {
    try {
      await adjustDifficulty({
        userId,
        interventionId: entry.interventionId,
        newDifficulty,
        reason: "Manual adjustment by physician",
      });
    } catch (error) {
      console.error("Failed to adjust difficulty:", error);
    }
  };

  const getDifficultyColor = (difficulty: number) => {
    if (difficulty <= 1) return "text-green-400 bg-green-500/20";
    if (difficulty <= 2) return "text-teal-400 bg-teal-500/20";
    if (difficulty <= 3) return "text-amber-400 bg-amber-500/20";
    if (difficulty <= 4) return "text-orange-400 bg-orange-500/20";
    return "text-red-400 bg-red-500/20";
  };

  const getDifficultyLabel = (difficulty: number) => {
    const labels = ["Very Easy", "Easy", "Moderate", "Challenging", "Difficult"];
    return labels[difficulty - 1] || "Unknown";
  };

  const getComplianceColor = (compliance: number) => {
    if (compliance >= 80) return "text-green-400";
    if (compliance >= 50) return "text-amber-400";
    return "text-red-400";
  };

  const getDifficultyChangeIcon = (current: number, original: number) => {
    if (current < original) return <TrendingDown className="w-3 h-3 text-green-400" />;
    if (current > original) return <TrendingUp className="w-3 h-3 text-red-400" />;
    return <Minus className="w-3 h-3 text-gray-400" />;
  };

  if (!difficultyStatus) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="animate-pulse">
          <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-16 bg-gray-700/50 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  // Summary stats
  const totalInterventions = difficultyStatus.length;
  const reducedCount = difficultyStatus.filter(
    (e: DifficultyEntry) => e.currentDifficulty < e.originalDifficulty
  ).length;
  const lockedCount = difficultyStatus.filter((e: DifficultyEntry) => e.difficultyLocked).length;
  const lowComplianceCount = difficultyStatus.filter(
    (e: DifficultyEntry) => e.rolling7DayCompliance < 50
  ).length;

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-purple-500/20 flex items-center justify-center">
            <Settings className="w-4 h-4 text-purple-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Adaptive Difficulty</h3>
            <p className="text-xs text-gray-500">Auto-adjusted based on compliance</p>
          </div>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-4 gap-2 mb-4">
        <div className="p-2 bg-gray-700/30 rounded-lg text-center">
          <div className="text-lg font-bold text-white">{totalInterventions}</div>
          <div className="text-[10px] text-gray-400">Active</div>
        </div>
        <div className="p-2 bg-gray-700/30 rounded-lg text-center">
          <div className="text-lg font-bold text-green-400">{reducedCount}</div>
          <div className="text-[10px] text-gray-400">Simplified</div>
        </div>
        <div className="p-2 bg-gray-700/30 rounded-lg text-center">
          <div className="text-lg font-bold text-amber-400">{lockedCount}</div>
          <div className="text-[10px] text-gray-400">Locked</div>
        </div>
        <div className="p-2 bg-gray-700/30 rounded-lg text-center">
          <div className="text-lg font-bold text-red-400">{lowComplianceCount}</div>
          <div className="text-[10px] text-gray-400">Low Compl.</div>
        </div>
      </div>

      {/* Interventions List */}
      <div className="space-y-2 max-h-[400px] overflow-y-auto">
        {difficultyStatus.length === 0 ? (
          <div className="text-center py-8 text-gray-500">
            <Settings className="w-8 h-8 mx-auto mb-2 opacity-50" />
            <p className="text-sm">No interventions assigned</p>
          </div>
        ) : (
          difficultyStatus.map((entry: DifficultyEntry) => (
            <div
              key={entry.interventionId}
              className="p-3 bg-gray-700/30 rounded-lg border border-gray-600/30"
            >
              {/* Main Row */}
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 flex-1 min-w-0">
                  {/* Lock Status */}
                  <button
                    onClick={() => handleToggleLock(entry)}
                    disabled={!physicianId}
                    className={`p-1 rounded ${
                      entry.difficultyLocked
                        ? "text-amber-400 hover:bg-amber-500/20"
                        : "text-gray-500 hover:bg-gray-600/50"
                    } disabled:opacity-50 disabled:cursor-not-allowed`}
                    title={entry.difficultyLocked ? "Unlock difficulty" : "Lock difficulty"}
                  >
                    {entry.difficultyLocked ? (
                      <Lock className="w-4 h-4" />
                    ) : (
                      <Unlock className="w-4 h-4" />
                    )}
                  </button>

                  {/* Intervention Name */}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-white truncate">{entry.interventionName}</p>
                    <div className="flex items-center gap-2">
                      {/* Difficulty Change Indicator */}
                      {getDifficultyChangeIcon(
                        entry.currentDifficulty,
                        entry.originalDifficulty
                      )}
                      <span className="text-[10px] text-gray-400">
                        {entry.currentDifficulty !== entry.originalDifficulty
                          ? `Was level ${entry.originalDifficulty}`
                          : "Unchanged"}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Current Difficulty Badge */}
                <div className="flex items-center gap-2">
                  <span
                    className={`px-2 py-0.5 text-xs font-medium rounded ${getDifficultyColor(
                      entry.currentDifficulty
                    )}`}
                  >
                    L{entry.currentDifficulty}
                  </span>
                  <span className={`text-xs ${getComplianceColor(entry.rolling7DayCompliance)}`}>
                    {entry.rolling7DayCompliance}%
                  </span>
                  <button
                    onClick={() =>
                      setExpandedIntervention(
                        expandedIntervention === entry.interventionId
                          ? null
                          : entry.interventionId
                      )
                    }
                    className="p-1 text-gray-400 hover:text-white"
                  >
                    {expandedIntervention === entry.interventionId ? (
                      <ChevronUp className="w-4 h-4" />
                    ) : (
                      <ChevronDown className="w-4 h-4" />
                    )}
                  </button>
                </div>
              </div>

              {/* Expanded Details */}
              {expandedIntervention === entry.interventionId && (
                <div className="mt-3 pt-3 border-t border-gray-600/30 space-y-3">
                  {/* Compliance Details */}
                  <div className="grid grid-cols-2 gap-2">
                    <div className="p-2 bg-gray-800/50 rounded">
                      <div className="flex items-center gap-1 mb-1">
                        <Clock className="w-3 h-3 text-gray-400" />
                        <span className="text-[10px] text-gray-400">7-Day Compliance</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="flex-1 h-2 bg-gray-700 rounded-full overflow-hidden">
                          <div
                            className={`h-full ${
                              entry.rolling7DayCompliance >= 80
                                ? "bg-green-500"
                                : entry.rolling7DayCompliance >= 50
                                ? "bg-amber-500"
                                : "bg-red-500"
                            }`}
                            style={{ width: `${entry.rolling7DayCompliance}%` }}
                          />
                        </div>
                        <span className="text-xs text-gray-300">
                          {entry.rolling7DayCompliance}%
                        </span>
                      </div>
                    </div>

                    <div className="p-2 bg-gray-800/50 rounded">
                      <div className="text-[10px] text-gray-400 mb-1">Streak</div>
                      <div className="flex items-center gap-2">
                        {entry.consecutiveLowDays > 0 ? (
                          <>
                            <AlertTriangle className="w-3 h-3 text-red-400" />
                            <span className="text-xs text-red-400">
                              {entry.consecutiveLowDays} low days
                            </span>
                          </>
                        ) : entry.consecutiveHighDays > 0 ? (
                          <>
                            <CheckCircle className="w-3 h-3 text-green-400" />
                            <span className="text-xs text-green-400">
                              {entry.consecutiveHighDays} high days
                            </span>
                          </>
                        ) : (
                          <span className="text-xs text-gray-400">No streak</span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Adjustment History */}
                  {entry.lastAdjustmentDate && (
                    <div className="p-2 bg-gray-800/50 rounded">
                      <div className="text-[10px] text-gray-400 mb-1">Last Adjustment</div>
                      <div className="flex items-center justify-between">
                        <span className="text-xs text-gray-300">
                          {new Date(entry.lastAdjustmentDate).toLocaleDateString()}
                        </span>
                        {entry.adjustmentReason && (
                          <span className="text-[10px] text-gray-400 italic">
                            {entry.adjustmentReason}
                          </span>
                        )}
                      </div>
                    </div>
                  )}

                  {/* Manual Difficulty Adjustment */}
                  {physicianId && !entry.difficultyLocked && (
                    <div className="p-2 bg-gray-800/50 rounded">
                      <div className="text-[10px] text-gray-400 mb-2">
                        Manual Adjustment
                      </div>
                      <div className="flex gap-1">
                        {[1, 2, 3, 4, 5].map((level) => (
                          <button
                            key={level}
                            onClick={() => handleManualAdjust(entry, level)}
                            className={`flex-1 py-1 text-xs rounded transition-colors ${
                              level === entry.currentDifficulty
                                ? getDifficultyColor(level)
                                : "bg-gray-700/50 text-gray-400 hover:bg-gray-600/50"
                            }`}
                          >
                            L{level}
                          </button>
                        ))}
                      </div>
                      <div className="flex justify-between mt-1 text-[9px] text-gray-500">
                        <span>Easier</span>
                        <span>Harder</span>
                      </div>
                    </div>
                  )}

                  {/* Lock Message */}
                  {entry.difficultyLocked && (
                    <div className="flex items-center gap-2 p-2 bg-amber-500/10 border border-amber-500/30 rounded text-amber-400">
                      <Lock className="w-3 h-3" />
                      <span className="text-[10px]">
                        Difficulty locked - auto-adjustment disabled
                      </span>
                    </div>
                  )}
                </div>
              )}
            </div>
          ))
        )}
      </div>

      {/* Footer Info */}
      <div className="mt-4 pt-3 border-t border-gray-700/50">
        <p className="text-[10px] text-gray-500 text-center">
          Difficulty auto-adjusts when compliance &lt;50% for 3+ consecutive days
        </p>
      </div>
    </div>
  );
}
