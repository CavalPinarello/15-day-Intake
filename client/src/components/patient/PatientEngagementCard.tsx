"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import {
  Flame,
  Trophy,
  Star,
  Zap,
  Calendar,
  TrendingUp,
  AlertTriangle,
  CheckCircle,
  Sparkles,
} from "lucide-react";

interface PatientEngagementCardProps {
  userId: Id<"users">;
}

export function PatientEngagementCard({ userId }: PatientEngagementCardProps) {
  const engagement = useQuery(api.gamification.getPatientEngagement, { userId });

  if (!engagement) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4 animate-pulse">
        <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
        <div className="space-y-3">
          <div className="h-8 bg-gray-700 rounded"></div>
          <div className="h-8 bg-gray-700 rounded"></div>
        </div>
      </div>
    );
  }

  const {
    currentStreak,
    longestStreak,
    totalDaysCompleted,
    level,
    levelName,
    totalXP,
    badgesEarned,
    badges,
    completionRate,
    engagementScore,
    lastActive,
    insights,
  } = engagement;

  type BadgeType = NonNullable<typeof engagement>["badges"][number];

  const lastActiveDate = lastActive ? new Date(lastActive) : null;
  const lastActiveText = lastActiveDate
    ? formatLastActive(lastActiveDate)
    : "Unknown";

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-orange-500/20 to-amber-500/20 flex items-center justify-center">
            <Zap className="w-4 h-4 text-orange-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Patient Engagement</h3>
            <p className="text-xs text-gray-500">Activity & motivation</p>
          </div>
        </div>
        {/* Engagement Score */}
        <div className="flex items-center gap-1.5">
          <div
            className={`text-lg font-bold ${
              engagementScore >= 75
                ? "text-green-400"
                : engagementScore >= 50
                ? "text-amber-400"
                : "text-red-400"
            }`}
          >
            {engagementScore}
          </div>
          <div className="text-xs text-gray-500">/100</div>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 gap-3 mb-4">
        {/* Streak */}
        <div className="bg-gray-700/30 rounded-lg p-3">
          <div className="flex items-center gap-2 mb-1">
            <Flame
              className={`w-4 h-4 ${
                currentStreak > 0 ? "text-orange-400" : "text-gray-500"
              }`}
            />
            <span className="text-xs text-gray-400">Current Streak</span>
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-xl font-bold text-white">{currentStreak}</span>
            <span className="text-xs text-gray-500">
              {currentStreak === 1 ? "day" : "days"}
            </span>
          </div>
          <div className="text-xs text-gray-500 mt-1">
            Best: {longestStreak} days
          </div>
        </div>

        {/* Level */}
        <div className="bg-gray-700/30 rounded-lg p-3">
          <div className="flex items-center gap-2 mb-1">
            <Star className={`w-4 h-4 ${getLevelColor(level)}`} />
            <span className="text-xs text-gray-400">Level</span>
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-xl font-bold text-white">{level}</span>
            <span className="text-xs text-gray-500">{levelName}</span>
          </div>
          <div className="text-xs text-gray-500 mt-1">{totalXP} XP</div>
        </div>

        {/* Completion Rate */}
        <div className="bg-gray-700/30 rounded-lg p-3">
          <div className="flex items-center gap-2 mb-1">
            <CheckCircle className="w-4 h-4 text-green-400" />
            <span className="text-xs text-gray-400">Completion</span>
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-xl font-bold text-white">{completionRate}%</span>
          </div>
          <div className="text-xs text-gray-500 mt-1">
            {totalDaysCompleted} days done
          </div>
        </div>

        {/* Badges */}
        <div className="bg-gray-700/30 rounded-lg p-3">
          <div className="flex items-center gap-2 mb-1">
            <Trophy className="w-4 h-4 text-yellow-400" />
            <span className="text-xs text-gray-400">Badges</span>
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-xl font-bold text-white">{badgesEarned}</span>
            <span className="text-xs text-gray-500">earned</span>
          </div>
          {badges.length > 0 && (
            <div className="flex gap-1 mt-1 flex-wrap">
              {badges.slice(0, 4).map((badge: BadgeType) => (
                <span key={badge.id} title={badge.name} className="text-sm">
                  {badge.icon}
                </span>
              ))}
              {badges.length > 4 && (
                <span className="text-xs text-gray-500">+{badges.length - 4}</span>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Last Active */}
      <div className="flex items-center justify-between text-xs mb-3 px-1">
        <span className="text-gray-500">Last active</span>
        <span className="text-gray-400">{lastActiveText}</span>
      </div>

      {/* Clinician Insights */}
      {insights.length > 0 && (
        <div className="space-y-2">
          <div className="flex items-center gap-1.5 text-xs text-gray-400">
            <Sparkles className="w-3 h-3" />
            <span>Engagement Insights</span>
          </div>
          {insights.map((insight: NonNullable<typeof engagement>["insights"][number], idx: number) => (
            <div
              key={idx}
              className={`flex items-start gap-2 text-xs p-2 rounded-lg ${
                insight.includes("high engagement") || insight.includes("thorough")
                  ? "bg-green-500/10 text-green-400"
                  : insight.includes("broken") || insight.includes("Low")
                  ? "bg-amber-500/10 text-amber-400"
                  : "bg-gray-700/30 text-gray-400"
              }`}
            >
              {insight.includes("high engagement") || insight.includes("thorough") ? (
                <CheckCircle className="w-3 h-3 mt-0.5 flex-shrink-0" />
              ) : insight.includes("broken") || insight.includes("Low") ? (
                <AlertTriangle className="w-3 h-3 mt-0.5 flex-shrink-0" />
              ) : (
                <TrendingUp className="w-3 h-3 mt-0.5 flex-shrink-0" />
              )}
              <span>{insight}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// Helper functions
function getLevelColor(level: number): string {
  switch (level) {
    case 1:
      return "text-gray-400";
    case 2:
      return "text-green-400";
    case 3:
      return "text-blue-400";
    case 4:
      return "text-purple-400";
    case 5:
      return "text-yellow-400";
    default:
      return "text-gray-400";
  }
}

function formatLastActive(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffMins < 5) return "Just now";
  if (diffMins < 60) return `${diffMins} min ago`;
  if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? "s" : ""} ago`;
  if (diffDays === 1) return "Yesterday";
  if (diffDays < 7) return `${diffDays} days ago`;
  return date.toLocaleDateString();
}
