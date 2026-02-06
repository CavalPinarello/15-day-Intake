"use client";

import { useState } from "react";
import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { X, Activity, AlertCircle, Info } from "lucide-react";
import { TimeRangeSelector } from "@/components/healthkit/TimeRangeSelector";
import { DeviceSourceSelector } from "@/components/healthkit/DeviceSourceSelector";
import { SleepMetricsChart } from "@/components/healthkit/SleepMetricsChart";
import { HeartRateHRVChart } from "@/components/healthkit/HeartRateHRVChart";
import { LightExposureChart } from "@/components/healthkit/LightExposureChart";
import { HealthKitEmptyState } from "@/components/healthkit/HealthKitEmptyState";

interface HealthKitDataModalProps {
  isOpen: boolean;
  onClose: () => void;
  userId: Id<"users">;
}

export function HealthKitDataModal({
  isOpen,
  onClose,
  userId,
}: HealthKitDataModalProps) {
  const [timeRange, setTimeRange] = useState<7 | 14 | 30 | 90>(14);
  const [selectedSource, setSelectedSource] = useState<string | null>(null);

  // Calculate date range
  const endDate = new Date().toISOString().split("T")[0];
  const startDate = new Date(
    Date.now() - timeRange * 24 * 60 * 60 * 1000
  ).toISOString().split("T")[0];

  // Fetch data
  const healthKitData = useQuery(api.physician.getHealthKitDataForPhysician, {
    userId,
    startDate,
    endDate,
    sourceFilter: selectedSource,
  });

  if (!isOpen) return null;

  if (!healthKitData) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center">
        <div
          className="absolute inset-0 bg-black/60 backdrop-blur-sm"
          onClick={onClose}
        />
        <div className="relative bg-gray-900 border border-gray-700 rounded-2xl p-6">
          <div className="animate-pulse flex flex-col items-center gap-3">
            <div className="w-12 h-12 bg-gray-800 rounded-xl"></div>
            <div className="h-4 w-48 bg-gray-800 rounded"></div>
          </div>
        </div>
      </div>
    );
  }

  const hasMultipleSources =
    healthKitData.availableSources.length > 1 && !selectedSource;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative w-full max-w-6xl max-h-[90vh] overflow-hidden bg-gray-900 border border-gray-700 rounded-2xl shadow-2xl m-4">
        {/* Sticky Header */}
        <div className="sticky top-0 z-10 bg-gray-900/95 backdrop-blur-sm border-b border-gray-700 p-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-xl bg-blue-500/20 border border-blue-500/30 flex items-center justify-center">
                <Activity className="w-6 h-6 text-blue-400" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-white">
                  HealthKit Data Viewer
                </h2>
                <p className="text-sm text-gray-400">
                  Objective health metrics from wearables
                </p>
              </div>
            </div>

            {/* Controls */}
            <div className="flex items-center gap-3">
              <TimeRangeSelector
                value={timeRange}
                onChange={setTimeRange}
              />
              <DeviceSourceSelector
                sources={healthKitData.availableSources}
                selected={selectedSource}
                onChange={setSelectedSource}
              />
              <button
                onClick={onClose}
                className="p-2 rounded-lg hover:bg-gray-800 transition-colors"
              >
                <X className="w-5 h-5 text-gray-400" />
              </button>
            </div>
          </div>
        </div>

        {/* Scrollable Body */}
        <div className="p-6 overflow-y-auto max-h-[calc(90vh-140px)] space-y-6">
          {/* Empty State */}
          {healthKitData.sleepData.length === 0 &&
            healthKitData.heartRateData.length === 0 && (
              <HealthKitEmptyState />
            )}

          {/* Data Quality Banner - Multiple Sources */}
          {hasMultipleSources && (
            <div className="p-3 bg-blue-500/10 border border-blue-500/30 rounded-lg">
              <p className="text-sm text-blue-300 flex items-center gap-2">
                <Info className="w-4 h-4" />
                Multiple data sources detected. Showing merged data with
                priority:{" "}
                {healthKitData.availableSources
                  .map((s) => s.displayName)
                  .join(" > ")}
                . Use the filter above to view individual sources.
              </p>
            </div>
          )}

          {/* Data Quality Banner - iOS < 17 */}
          {!healthKitData.dataQuality.hasLightExposure &&
            healthKitData.sleepData.length > 0 && (
              <div className="p-4 bg-amber-500/10 border border-amber-500/30 rounded-xl">
                <div className="flex items-center gap-3">
                  <AlertCircle className="w-5 h-5 text-amber-400" />
                  <div>
                    <p className="text-sm font-medium text-amber-300">
                      Limited Circadian Data
                    </p>
                    <p className="text-xs text-amber-400 mt-1">
                      Daylight exposure tracking requires iOS 17+ / watchOS 10+
                    </p>
                  </div>
                </div>
              </div>
            )}

          {/* Charts */}
          {healthKitData.sleepData.length > 0 && (
            <SleepMetricsChart
              data={healthKitData.sleepData}
              timeRange={timeRange}
            />
          )}

          {healthKitData.heartRateData.length > 0 && (
            <HeartRateHRVChart data={healthKitData.heartRateData} />
          )}

          {healthKitData.circadianData.length > 0 && (
            <LightExposureChart data={healthKitData.circadianData} />
          )}
        </div>
      </div>
    </div>
  );
}
