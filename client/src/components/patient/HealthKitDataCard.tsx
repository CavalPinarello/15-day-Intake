"use client";

import { Heart, Moon, Sun, RefreshCw, AlertCircle } from "lucide-react";
import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";

interface HealthKitDataCardProps {
  userId: Id<"users">;
  onOpenModal: () => void;
}

export function HealthKitDataCard({
  userId,
  onOpenModal,
}: HealthKitDataCardProps) {
  // Calculate date range for last 30 days (was 7, increased for better data capture)
  const today = new Date();
  const thirtyDaysAgo = new Date(today);
  thirtyDaysAgo.setDate(today.getDate() - 30);

  const endDate = today.toISOString().split("T")[0];
  const startDate = thirtyDaysAgo.toISOString().split("T")[0];

  // Fetch summary data
  const summary = useQuery(api.physician.getHealthKitDataForPhysician, {
    userId,
    startDate,
    endDate,
  });

  // Fetch sync status for debugging
  const syncStatus = useQuery(api.physician.getHealthKitSyncStatus, {
    userId,
  });

  if (!summary) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="animate-pulse">
          <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
          <div className="h-20 bg-gray-700/50 rounded"></div>
        </div>
      </div>
    );
  }

  if (summary.sleepData.length === 0) {
    // Show more helpful info when no data
    const diagnosis = syncStatus && "diagnosis" in syncStatus ? syncStatus.diagnosis : null;
    const appleHealthConnected = syncStatus && "user" in syncStatus ? syncStatus.user.appleHealthConnected : false;

    return (
      <div
        className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4 cursor-pointer hover:bg-gray-800/70 transition-colors"
        onClick={onOpenModal}
      >
        <div className="flex items-center gap-2 mb-3">
          <div className="w-8 h-8 rounded-lg bg-blue-500/20 flex items-center justify-center">
            <Heart className="w-4 h-4 text-blue-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">HealthKit Data</h3>
            <p className="text-xs text-gray-500">Wearable metrics & trends</p>
          </div>
        </div>

        <div className="space-y-2">
          {/* Status indicator */}
          <div className="flex items-center gap-2 text-sm">
            {appleHealthConnected ? (
              <>
                <RefreshCw className="w-4 h-4 text-amber-400" />
                <span className="text-amber-400">Connected, no recent data</span>
              </>
            ) : (
              <>
                <AlertCircle className="w-4 h-4 text-gray-500" />
                <span className="text-gray-500">Not connected</span>
              </>
            )}
          </div>

          {/* Diagnosis */}
          {diagnosis?.issue && (
            <p className="text-xs text-gray-400">
              {diagnosis.issue}
            </p>
          )}

          {/* Data counts if any exist outside date range */}
          {syncStatus && "dataCounts" in syncStatus && syncStatus.dataCounts.totalSleepRecords > 0 && (
            <p className="text-xs text-blue-400">
              {syncStatus.dataCounts.totalSleepRecords} total records (outside 30-day window)
            </p>
          )}
        </div>
      </div>
    );
  }

  // Calculate averages with proper types
  type SleepDataItem = { totalSleepMins?: number | null };
  type HeartRateItem = { restingHr?: number | null };
  type CircadianItem = { daylightMins?: number | null };
  type SourceItem = { bundleIdentifier: string; displayName: string };

  const avgSleep =
    summary.sleepData.reduce((sum: number, d: SleepDataItem) => sum + (d.totalSleepMins || 0), 0) /
      (summary.sleepData.filter((d: SleepDataItem) => d.totalSleepMins).length || 1) /
      60;

  const avgHr =
    summary.heartRateData.reduce((sum: number, d: HeartRateItem) => sum + (d.restingHr || 0), 0) /
    (summary.heartRateData.filter((d: HeartRateItem) => d.restingHr).length || 1);

  const avgDaylight =
    summary.circadianData.reduce((sum: number, d: CircadianItem) => sum + (d.daylightMins || 0), 0) /
    (summary.circadianData.filter((d: CircadianItem) => d.daylightMins).length || 1);

  const hasMultipleSources = summary.availableSources.length > 1;

  return (
    <div
      className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4 cursor-pointer hover:bg-gray-800/70 transition-colors"
      onClick={onOpenModal}
    >
      {/* Header */}
      <div className="flex items-center gap-2 mb-3">
        <div className="w-8 h-8 rounded-lg bg-blue-500/20 flex items-center justify-center">
          <Heart className="w-4 h-4 text-blue-400" />
        </div>
        <div>
          <h3 className="text-sm font-medium text-white">HealthKit Data</h3>
          <p className="text-xs text-gray-500">
            {summary.sleepData.length} days of data
          </p>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-3 gap-2 mb-3">
        <div className="bg-gray-900/50 rounded-lg p-2">
          <div className="flex items-center gap-1 mb-1">
            <Moon className="w-3 h-3 text-blue-400" />
            <p className="text-xs text-gray-500">Avg Sleep</p>
          </div>
          <p className="text-sm font-semibold text-white">
            {avgSleep > 0 ? `${avgSleep.toFixed(1)}h` : "—"}
          </p>
        </div>

        <div className="bg-gray-900/50 rounded-lg p-2">
          <div className="flex items-center gap-1 mb-1">
            <Heart className="w-3 h-3 text-red-400" />
            <p className="text-xs text-gray-500">Resting HR</p>
          </div>
          <p className="text-sm font-semibold text-white">
            {avgHr > 0 ? `${Math.round(avgHr)} bpm` : "—"}
          </p>
        </div>

        <div className="bg-gray-900/50 rounded-lg p-2">
          <div className="flex items-center gap-1 mb-1">
            <Sun className="w-3 h-3 text-yellow-400" />
            <p className="text-xs text-gray-500">Daylight</p>
          </div>
          <p className="text-sm font-semibold text-white">
            {avgDaylight > 0 ? `${Math.round(avgDaylight)} min` : "—"}
          </p>
        </div>
      </div>

      {/* Device Badges */}
      {hasMultipleSources ? (
        <div className="flex gap-1 flex-wrap">
          {summary.availableSources.map((source: SourceItem) => (
            <div
              key={source.bundleIdentifier}
              className="px-2 py-0.5 bg-blue-500/20 border border-blue-500/30 rounded text-xs text-blue-300"
            >
              {source.displayName}
            </div>
          ))}
        </div>
      ) : (
        <div className="text-xs text-gray-400">
          {summary.availableSources[0]?.displayName || "Multiple sources"}
        </div>
      )}
    </div>
  );
}
