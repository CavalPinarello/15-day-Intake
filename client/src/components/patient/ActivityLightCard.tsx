"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import {
  Activity,
  Sun,
  Footprints,
  Timer,
  Flame,
  TrendingUp,
  TrendingDown,
  Minus,
  AlertCircle,
  Sunrise,
  Moon,
  Gauge,
} from "lucide-react";

interface ActivityLightCardProps {
  userId: Id<"users">;
  days?: number;
}

export function ActivityLightCard({ userId, days = 14 }: ActivityLightCardProps) {
  const data = useQuery(api.physician.getPatientActivityAndCircadian, {
    userId,
    days,
  });

  if (!data) {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2 bg-green-100 rounded-lg">
            <Activity className="w-5 h-5 text-green-700" />
          </div>
          <h3 className="font-semibold text-gray-900">Activity & Light Exposure</h3>
        </div>
        <div className="animate-pulse space-y-4">
          <div className="h-20 bg-gray-100 rounded" />
          <div className="h-20 bg-gray-100 rounded" />
        </div>
      </div>
    );
  }

  if (!data.hasAnyData) {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="p-2 bg-green-100 rounded-lg">
            <Activity className="w-5 h-5 text-green-700" />
          </div>
          <h3 className="font-semibold text-gray-900">Activity & Light Exposure</h3>
        </div>
        <div className="text-center py-8 text-gray-500">
          <Activity className="w-12 h-12 mx-auto mb-3 text-gray-300" />
          <p>No activity or light exposure data available</p>
          <p className="text-sm mt-1">Requires Apple Watch / HealthKit sync</p>
        </div>
      </div>
    );
  }

  const { activitySummary, lightSummary, clinicalNotes, dailyData } = data;

  // Helper to render trend icon
  const TrendIcon = ({ trend }: { trend: "improving" | "declining" | "stable" | null }) => {
    if (trend === "improving") return <TrendingUp className="w-4 h-4 text-green-600" />;
    if (trend === "declining") return <TrendingDown className="w-4 h-4 text-red-600" />;
    if (trend === "stable") return <Minus className="w-4 h-4 text-gray-400" />;
    return null;
  };

  // Define day data type
  type DayData = {
    date: string;
    dayOfWeek: string;
    steps?: number;
    activeMins?: number;
    exerciseMins?: number;
    caloriesBurned?: number;
    daylightMins?: number;
    morningLightMins?: number;
    afternoonLightMins?: number;
    outdoorWorkoutMins?: number;
    circadianScore?: number;
    tempDeviation?: number;
    hasActivityData: boolean;
    hasLightData: boolean;
  };

  // Calculate max values for bar charts
  const maxSteps = Math.max(...dailyData.map((d: DayData) => d.steps || 0), 10000);
  const maxDaylight = Math.max(...dailyData.map((d: DayData) => d.daylightMins || 0), 120);

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-green-100 rounded-lg">
            <Activity className="w-5 h-5 text-green-700" />
          </div>
          <div>
            <h3 className="font-semibold text-gray-900">Activity & Light Exposure</h3>
            <p className="text-sm text-gray-500">Last {days} days</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Activity Section */}
        <div className="space-y-4">
          <div className="flex items-center gap-2 text-gray-700 font-medium">
            <Footprints className="w-4 h-4" />
            <span>Physical Activity</span>
            {activitySummary.trend && <TrendIcon trend={activitySummary.trend} />}
          </div>

          {activitySummary.hasData ? (
            <>
              {/* Activity Stats */}
              <div className="grid grid-cols-3 gap-3">
                <div className="p-3 bg-green-50 rounded-lg">
                  <div className="flex items-center gap-1 text-green-700 text-xs mb-1">
                    <Footprints className="w-3 h-3" />
                    Avg Steps
                  </div>
                  <p className="text-xl font-bold text-green-700">
                    {activitySummary.avgSteps?.toLocaleString() || "—"}
                  </p>
                </div>
                <div className="p-3 bg-blue-50 rounded-lg">
                  <div className="flex items-center gap-1 text-blue-700 text-xs mb-1">
                    <Timer className="w-3 h-3" />
                    Active Mins
                  </div>
                  <p className="text-xl font-bold text-blue-700">
                    {activitySummary.avgActiveMins ?? "—"}
                  </p>
                </div>
                <div className="p-3 bg-orange-50 rounded-lg">
                  <div className="flex items-center gap-1 text-orange-700 text-xs mb-1">
                    <Flame className="w-3 h-3" />
                    Exercise Mins
                  </div>
                  <p className="text-xl font-bold text-orange-700">
                    {activitySummary.avgExerciseMins ?? "—"}
                  </p>
                </div>
              </div>

              {/* Steps Bar Chart */}
              <div className="space-y-2">
                <p className="text-xs text-gray-500 font-medium">Daily Steps</p>
                <div className="flex items-end gap-1 h-16">
                  {dailyData.slice(-14).map((day: DayData, i: number) => {
                    const height = day.steps ? Math.max(4, (day.steps / maxSteps) * 100) : 4;
                    const isLow = day.steps && day.steps < 5000;
                    return (
                      <div
                        key={i}
                        className="flex-1 flex flex-col items-center"
                        title={`${day.date}: ${day.steps?.toLocaleString() || "No data"} steps`}
                      >
                        <div
                          className={`w-full rounded-t transition-all ${
                            !day.steps
                              ? "bg-gray-200"
                              : isLow
                              ? "bg-amber-400"
                              : "bg-green-500"
                          }`}
                          style={{ height: `${height}%` }}
                        />
                      </div>
                    );
                  })}
                </div>
                <div className="flex justify-between text-xs text-gray-400">
                  <span>{dailyData[0]?.dayOfWeek}</span>
                  <span>Today</span>
                </div>
              </div>
            </>
          ) : (
            <div className="p-4 bg-gray-50 rounded-lg text-center text-gray-500 text-sm">
              No activity data available
            </div>
          )}
        </div>

        {/* Light Exposure Section */}
        <div className="space-y-4">
          <div className="flex items-center gap-2 text-gray-700 font-medium">
            <Sun className="w-4 h-4" />
            <span>Light Exposure & Circadian</span>
            {lightSummary.trend && <TrendIcon trend={lightSummary.trend} />}
          </div>

          {lightSummary.hasData ? (
            <>
              {/* Light Stats */}
              <div className="grid grid-cols-3 gap-3">
                <div className="p-3 bg-yellow-50 rounded-lg">
                  <div className="flex items-center gap-1 text-yellow-700 text-xs mb-1">
                    <Sun className="w-3 h-3" />
                    Daylight
                  </div>
                  <p className="text-xl font-bold text-yellow-700">
                    {lightSummary.avgDaylightMins ?? "—"}
                    <span className="text-xs font-normal">m</span>
                  </p>
                </div>
                <div className="p-3 bg-orange-50 rounded-lg">
                  <div className="flex items-center gap-1 text-orange-700 text-xs mb-1">
                    <Sunrise className="w-3 h-3" />
                    Morning
                  </div>
                  <p className="text-xl font-bold text-orange-700">
                    {lightSummary.avgMorningLightMins ?? "—"}
                    <span className="text-xs font-normal">m</span>
                  </p>
                </div>
                <div className="p-3 bg-purple-50 rounded-lg">
                  <div className="flex items-center gap-1 text-purple-700 text-xs mb-1">
                    <Gauge className="w-3 h-3" />
                    Circadian
                  </div>
                  <p className="text-xl font-bold text-purple-700">
                    {lightSummary.avgCircadianScore ?? "—"}
                    <span className="text-xs font-normal">/100</span>
                  </p>
                </div>
              </div>

              {/* Light Bar Chart */}
              <div className="space-y-2">
                <p className="text-xs text-gray-500 font-medium">Daily Daylight (mins)</p>
                <div className="flex items-end gap-1 h-16">
                  {dailyData.slice(-14).map((day: DayData, i: number) => {
                    const height = day.daylightMins
                      ? Math.max(4, (day.daylightMins / maxDaylight) * 100)
                      : 4;
                    const isLow = day.daylightMins && day.daylightMins < 30;
                    return (
                      <div
                        key={i}
                        className="flex-1 flex flex-col items-center"
                        title={`${day.date}: ${day.daylightMins || "No data"} mins daylight`}
                      >
                        <div
                          className={`w-full rounded-t transition-all ${
                            !day.daylightMins
                              ? "bg-gray-200"
                              : isLow
                              ? "bg-red-400"
                              : day.daylightMins < 60
                              ? "bg-amber-400"
                              : "bg-yellow-400"
                          }`}
                          style={{ height: `${height}%` }}
                        />
                      </div>
                    );
                  })}
                </div>
                <div className="flex justify-between text-xs text-gray-400">
                  <span>{dailyData[0]?.dayOfWeek}</span>
                  <span>Today</span>
                </div>
              </div>

              {/* Circadian Score Gauge */}
              {lightSummary.avgCircadianScore !== null && (
                <div className="p-3 bg-gradient-to-r from-red-100 via-yellow-100 to-green-100 rounded-lg">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs text-gray-600">Circadian Health Score</span>
                    <span className="text-sm font-bold text-gray-700">
                      {lightSummary.avgCircadianScore}/100
                    </span>
                  </div>
                  <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full transition-all ${
                        lightSummary.avgCircadianScore >= 70
                          ? "bg-green-500"
                          : lightSummary.avgCircadianScore >= 50
                          ? "bg-yellow-500"
                          : "bg-red-500"
                      }`}
                      style={{ width: `${lightSummary.avgCircadianScore}%` }}
                    />
                  </div>
                </div>
              )}
            </>
          ) : (
            <div className="p-4 bg-gray-50 rounded-lg text-center text-gray-500 text-sm">
              No light exposure data available
            </div>
          )}
        </div>
      </div>

      {/* Clinical Notes */}
      {clinicalNotes.length > 0 && (
        <div className="mt-4 p-3 bg-amber-50 border border-amber-200 rounded-lg">
          <div className="flex items-center gap-2 text-amber-700 text-sm font-medium mb-2">
            <AlertCircle className="w-4 h-4" />
            Clinical Notes
          </div>
          <ul className="text-sm text-amber-800 space-y-1">
            {clinicalNotes.map((note: string, i: number) => (
              <li key={i} className="flex items-start gap-2">
                <span className="mt-1">•</span>
                <span>{note}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
