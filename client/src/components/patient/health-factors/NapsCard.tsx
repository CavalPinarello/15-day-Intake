"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState } from "react";
import {
  Moon,
  Clock,
  X,
  AlertCircle,
  ChevronRight,
} from "lucide-react";

interface NapsCardProps {
  userId: Id<"users">;
}

interface DailyData {
  dayNumber: number;
  date?: string;
  tookNaps: boolean;
  napCount: number;
  napDetails: Array<{ startTime?: string; durationMinutes?: number }>;
  totalNapMinutes: number;
  sleepQuality?: number;
}

// Mini bar chart for 10-day rolling data
function MiniBarChart({
  data,
  maxValue,
  color,
  label,
}: {
  data: number[];
  maxValue: number;
  color: string;
  label?: string;
}) {
  const barColors: Record<string, string> = {
    blue: "bg-blue-500",
  };

  return (
    <div className="w-full">
      {label && <p className="text-xs text-gray-400 mb-1">{label}</p>}
      <div className="flex items-end gap-0.5 h-8">
        {data.map((value, i) => {
          const height = maxValue > 0 ? Math.max((value / maxValue) * 100, value > 0 ? 10 : 0) : 0;
          return (
            <div
              key={i}
              className={`flex-1 rounded-t ${value > 0 ? barColors[color] || "bg-gray-500" : "bg-gray-700/50"}`}
              style={{ height: `${height}%` }}
              title={`Day ${i + 1}: ${value}`}
            />
          );
        })}
      </div>
      <div className="flex justify-between mt-0.5">
        <span className="text-[10px] text-gray-500">Day 1</span>
        <span className="text-[10px] text-gray-500">Day {data.length}</span>
      </div>
    </div>
  );
}

// Day-by-day breakdown row
function DayRow({
  day,
  hasData,
  children,
  sleepQuality,
}: {
  day: number;
  hasData: boolean;
  children: React.ReactNode;
  sleepQuality?: number;
}) {
  return (
    <div className={`p-2 rounded-lg ${hasData ? "bg-gray-800/50" : "bg-gray-800/20"} border border-gray-700/30`}>
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs font-medium text-gray-400">Day {day}</span>
        {sleepQuality !== undefined && (
          <span className={`text-xs px-1.5 py-0.5 rounded ${
            sleepQuality >= 4 ? "bg-green-500/20 text-green-400" :
            sleepQuality >= 3 ? "bg-amber-500/20 text-amber-400" :
            "bg-red-500/20 text-red-400"
          }`}>
            Sleep: {sleepQuality}/5
          </span>
        )}
      </div>
      {hasData ? (
        <div className="text-sm text-white">{children}</div>
      ) : (
        <p className="text-xs text-gray-500 italic">No data</p>
      )}
    </div>
  );
}

export function NapsCard({ userId }: NapsCardProps) {
  const [showDetailModal, setShowDetailModal] = useState(false);

  // Use the comprehensive rolling API
  const rollingData = useQuery(api.physician.getPatientSleepHealthRolling, { userId, days: 14 });

  const hasData = rollingData && rollingData.totalDays > 0;

  // Calculate display values
  const napRate = hasData && rollingData.totalDays > 0
    ? Math.round((rollingData.naps.daysWithNaps / rollingData.totalDays) * 100)
    : 0;

  // Prepare chart data
  const napChartData = rollingData?.dailyData.map((d: DailyData) => d.tookNaps ? 1 : 0) ?? [];
  const napMinutesChartData = rollingData?.dailyData.map((d: DailyData) => d.totalNapMinutes) ?? [];

  return (
    <>
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="flex items-center gap-2 mb-4">
          <div className="w-8 h-8 rounded-lg bg-blue-500/20 flex items-center justify-center">
            <Moon className="w-4 h-4 text-blue-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Napping</h3>
            <p className="text-xs text-gray-500">10-day rolling view</p>
          </div>
        </div>

        {/* Summary Row */}
        <button
          onClick={() => setShowDetailModal(true)}
          className="w-full flex items-center justify-between p-3 rounded-lg bg-gray-700/30 hover:bg-gray-700/50 transition-colors group"
        >
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-blue-500/20 flex items-center justify-center">
              <Moon className="w-4 h-4 text-blue-400" />
            </div>
            <div className="text-left">
              <p className="text-sm font-medium text-white">Napping Frequency</p>
              <p className="text-xs text-gray-400">
                {hasData
                  ? `${rollingData.naps.daysWithNaps}/${rollingData.totalDays} days (${napRate}%)`
                  : "No data yet"
                }
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {hasData && napRate > 50 && (
              <span className="px-2 py-0.5 text-xs rounded-full bg-amber-500/20 text-amber-400">
                Frequent
              </span>
            )}
            <ChevronRight className="w-4 h-4 text-gray-500 group-hover:text-white transition-colors" />
          </div>
        </button>

        {/* Quick Stats */}
        {hasData && rollingData.naps.daysWithNaps > 0 && (
          <div className="mt-3 p-3 rounded-lg bg-gray-700/30">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-gray-400">Avg Duration</p>
                <p className="text-lg font-semibold text-white">{rollingData.naps.avgNapMinutes} min</p>
              </div>
              {rollingData.naps.commonTimes.length > 0 && (
                <div className="text-right">
                  <p className="text-xs text-gray-400">Common Time</p>
                  <p className="text-sm text-blue-400">{rollingData.naps.commonTimes[0]}</p>
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Detail Modal */}
      {showDetailModal && rollingData && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50">
          <div className="bg-gray-900 rounded-xl max-w-lg w-full max-h-[90vh] overflow-hidden border border-gray-700">
            <div className="flex items-center justify-between p-4 border-b border-gray-700">
              <h3 className="text-lg font-semibold text-white">
                Napping - 10 Day View
              </h3>
              <button
                onClick={() => setShowDetailModal(false)}
                className="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-4 overflow-y-auto max-h-[calc(90vh-80px)]">
              <div className="space-y-4">
                {/* Summary Stats */}
                <div className="grid grid-cols-2 gap-4">
                  <div className="p-3 rounded-lg bg-gray-800/50">
                    <p className="text-xs text-gray-400">Nap Days</p>
                    <p className="text-xl font-bold text-white">{rollingData.naps.daysWithNaps}</p>
                    <p className="text-xs text-gray-500">of {rollingData.totalDays} tracked</p>
                  </div>
                  <div className="p-3 rounded-lg bg-gray-800/50">
                    <p className="text-xs text-gray-400">Avg Duration</p>
                    <p className="text-xl font-bold text-white">{rollingData.naps.avgNapMinutes}m</p>
                    <p className="text-xs text-gray-500">per nap day</p>
                  </div>
                </div>

                {/* 10-Day Chart */}
                <div className="p-3 rounded-lg bg-gray-800/50">
                  <p className="text-sm font-medium text-gray-400 mb-2">Napping Pattern (10 days)</p>
                  <MiniBarChart data={napChartData} maxValue={1} color="blue" />
                </div>

                {rollingData.naps.avgNapMinutes > 0 && (
                  <div className="p-3 rounded-lg bg-gray-800/50">
                    <p className="text-sm font-medium text-gray-400 mb-2">Nap Duration (minutes)</p>
                    <MiniBarChart data={napMinutesChartData} maxValue={Math.max(...napMinutesChartData, 60)} color="blue" />
                  </div>
                )}

                {rollingData.naps.commonTimes.length > 0 && (
                  <div>
                    <p className="text-sm font-medium text-gray-400 mb-2">Common Nap Times</p>
                    <div className="flex flex-wrap gap-2">
                      {rollingData.naps.commonTimes.map((time: string) => (
                        <span key={time} className="px-3 py-1.5 rounded-full bg-blue-500/20 text-blue-400 text-sm">
                          <Clock className="w-3 h-3 inline mr-1" />
                          {time}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {/* Day-by-Day Breakdown */}
                <div>
                  <p className="text-sm font-medium text-gray-400 mb-2">Day-by-Day Breakdown</p>
                  <div className="space-y-2 max-h-60 overflow-y-auto">
                    {rollingData.dailyData.map((day: DailyData) => (
                      <DayRow
                        key={day.dayNumber}
                        day={day.dayNumber}
                        hasData={day.tookNaps}
                        sleepQuality={day.sleepQuality}
                      >
                        {day.napDetails.length > 0 ? (
                          <div className="space-y-1">
                            {day.napDetails.map((nap: { startTime?: string; durationMinutes?: number }, i: number) => (
                              <div key={i} className="flex items-center gap-2 text-xs">
                                <Clock className="w-3 h-3 text-blue-400" />
                                <span>{nap.startTime || "Unknown time"}</span>
                                <span className="text-gray-400">•</span>
                                <span>{nap.durationMinutes}min</span>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <span className="text-xs text-gray-400">Napped (no details)</span>
                        )}
                      </DayRow>
                    ))}
                  </div>
                </div>

                <div className="p-3 rounded-lg bg-amber-500/10 border border-amber-500/30">
                  <p className="text-sm text-amber-400">
                    <AlertCircle className="w-4 h-4 inline mr-1" />
                    {napRate > 50
                      ? "Frequent napping may indicate insufficient nighttime sleep"
                      : napRate > 0
                        ? "Occasional napping patterns detected"
                        : "No napping reported in this period"
                    }
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
