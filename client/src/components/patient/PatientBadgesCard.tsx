"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { Trophy, Lock, Star, ChevronRight } from "lucide-react";
import { useState } from "react";

interface PatientBadgesCardProps {
  userId: Id<"users">;
}

export function PatientBadgesCard({ userId }: PatientBadgesCardProps) {
  const badges = useQuery(api.gamification.getUserBadges, { userId });
  const [showAll, setShowAll] = useState(false);

  if (!badges) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4 animate-pulse">
        <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
        <div className="flex gap-2">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="w-12 h-12 bg-gray-700 rounded-lg"></div>
          ))}
        </div>
      </div>
    );
  }

  const { earned, inProgress } = badges;
  const displayBadges = showAll ? earned : earned.slice(0, 8);

  // Type aliases for badges
  type BadgeType = typeof earned[number];
  type InProgressBadgeType = typeof inProgress[number];

  // Group badges by category
  const badgesByCategory = earned.reduce(
    (acc: Record<string, BadgeType[]>, badge: BadgeType) => {
      const category = badge.badge_category;
      if (!acc[category]) acc[category] = [];
      acc[category].push(badge);
      return acc;
    },
    {} as Record<string, BadgeType[]>
  );

  const categoryColors: Record<string, string> = {
    journey: "from-blue-500/20 to-cyan-500/20",
    streak: "from-orange-500/20 to-amber-500/20",
    quality: "from-green-500/20 to-emerald-500/20",
    clinical: "from-purple-500/20 to-violet-500/20",
  };

  const categoryLabels: Record<string, string> = {
    journey: "Journey",
    streak: "Streak",
    quality: "Quality",
    clinical: "Clinical",
  };

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-yellow-500/20 to-amber-500/20 flex items-center justify-center">
            <Trophy className="w-4 h-4 text-yellow-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Badges</h3>
            <p className="text-xs text-gray-500">{earned.length} earned</p>
          </div>
        </div>
        {earned.length > 8 && (
          <button
            onClick={() => setShowAll(!showAll)}
            className="text-xs text-blue-400 hover:text-blue-300 flex items-center gap-1"
          >
            {showAll ? "Show less" : "Show all"}
            <ChevronRight className={`w-3 h-3 transition-transform ${showAll ? "rotate-90" : ""}`} />
          </button>
        )}
      </div>

      {/* Badge Display */}
      {earned.length === 0 ? (
        <div className="text-center py-6">
          <Lock className="w-8 h-8 text-gray-600 mx-auto mb-2" />
          <p className="text-sm text-gray-500">No badges earned yet</p>
          <p className="text-xs text-gray-600 mt-1">
            {inProgress.length > 0
              ? `${inProgress.length} badge${inProgress.length > 1 ? "s" : ""} in progress`
              : "Badges unlock as patient completes activities"}
          </p>
        </div>
      ) : showAll ? (
        // Expanded view - grouped by category
        <div className="space-y-3">
          {(Object.entries(badgesByCategory) as [string, BadgeType[]][]).map(([category, categoryBadges]) => (
            <div key={category}>
              <div className="flex items-center gap-2 mb-2">
                <span className="text-xs text-gray-500 uppercase tracking-wide">
                  {categoryLabels[category] || category}
                </span>
                <div className="h-px flex-1 bg-gray-700"></div>
              </div>
              <div className="flex flex-wrap gap-2">
                {categoryBadges.map((badge) => (
                  <BadgeItem key={badge.badge_id} badge={badge} />
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        // Compact view - just icons
        <div className="flex flex-wrap gap-2">
          {displayBadges.map((badge: BadgeType) => (
            <BadgeItem key={badge.badge_id} badge={badge} compact />
          ))}
        </div>
      )}

      {/* In Progress Section */}
      {inProgress.length > 0 && (
        <div className="mt-4 pt-3 border-t border-gray-700/50">
          <div className="flex items-center gap-1.5 text-xs text-gray-400 mb-2">
            <Star className="w-3 h-3" />
            <span>In Progress ({inProgress.length})</span>
          </div>
          <div className="flex flex-wrap gap-2">
            {inProgress.slice(0, 4).map((badge: InProgressBadgeType) => (
              <div
                key={badge.badge_id}
                className="relative"
                title={`${badge.badge_name}: ${badge.progress_current ?? 0}/${badge.progress_target ?? 1}`}
              >
                <div className="w-10 h-10 rounded-lg bg-gray-700/50 flex items-center justify-center opacity-50">
                  <span className="text-lg">{badge.badge_icon}</span>
                </div>
                {badge.progress_current !== undefined && badge.progress_target !== undefined && (
                  <div className="absolute -bottom-1 left-0 right-0 h-1 bg-gray-600 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-blue-500"
                      style={{
                        width: `${(badge.progress_current / badge.progress_target) * 100}%`,
                      }}
                    />
                  </div>
                )}
              </div>
            ))}
            {inProgress.length > 4 && (
              <div className="w-10 h-10 rounded-lg bg-gray-700/30 flex items-center justify-center">
                <span className="text-xs text-gray-500">+{inProgress.length - 4}</span>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

interface BadgeItemProps {
  badge: {
    badge_id: string;
    badge_name: string;
    badge_description: string;
    badge_category: string;
    badge_icon: string;
    earned_at: number;
  };
  compact?: boolean;
}

function BadgeItem({ badge, compact = false }: BadgeItemProps) {
  const categoryColors: Record<string, string> = {
    journey: "border-blue-500/30",
    streak: "border-orange-500/30",
    quality: "border-green-500/30",
    clinical: "border-purple-500/30",
  };

  const categoryBg: Record<string, string> = {
    journey: "bg-blue-500/10",
    streak: "bg-orange-500/10",
    quality: "bg-green-500/10",
    clinical: "bg-purple-500/10",
  };

  if (compact) {
    return (
      <div
        className={`w-10 h-10 rounded-lg ${categoryBg[badge.badge_category] || "bg-gray-700/50"}
          border ${categoryColors[badge.badge_category] || "border-gray-600"}
          flex items-center justify-center cursor-pointer hover:scale-110 transition-transform`}
        title={`${badge.badge_name}: ${badge.badge_description}`}
      >
        <span className="text-lg">{badge.badge_icon}</span>
      </div>
    );
  }

  return (
    <div
      className={`flex items-center gap-2 px-2 py-1.5 rounded-lg
        ${categoryBg[badge.badge_category] || "bg-gray-700/50"}
        border ${categoryColors[badge.badge_category] || "border-gray-600"}`}
    >
      <span className="text-lg">{badge.badge_icon}</span>
      <div className="min-w-0">
        <p className="text-xs font-medium text-white truncate">{badge.badge_name}</p>
        <p className="text-[10px] text-gray-400 truncate">{formatDate(badge.earned_at)}</p>
      </div>
    </div>
  );
}

function formatDate(timestamp: number): string {
  const date = new Date(timestamp);
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}
