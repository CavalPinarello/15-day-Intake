"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState } from "react";
import {
  Pill,
  Coffee,
  Moon,
  Clock,
  ChevronRight,
  X,
  AlertCircle,
  Leaf,
  TrendingUp,
  TrendingDown,
  Minus,
} from "lucide-react";

interface SleepHealthFactorsCardProps {
  userId: Id<"users">;
}

// Display names for supplement category IDs
const SUPPLEMENT_NAMES: Record<string, string> = {
  melatonin: "Melatonin",
  magnesium: "Magnesium",
  valerian_root: "Valerian Root",
  l_theanine: "L-Theanine",
  cbd_cbn: "CBD/CBN",
  cbd_thc: "CBD/THC",
  gaba: "GABA",
  chamomile: "Chamomile",
  ashwagandha: "Ashwagandha",
  glycine: "Glycine",
  "5_htp": "5-HTP",
  herbal: "Herbal/Natural",
  other_supplement: "Other Supplement",
  other: "Other",
};

// Types matching the API response
interface DailyData {
  dayNumber: number;
  date?: string;
  tookNaps: boolean;
  napCount: number;
  napDetails: Array<{ startTime?: string; durationMinutes?: number }>;
  totalNapMinutes: number;
  tookMeds: boolean;
  medications: Array<{ categoryId: string; medicationName?: string; dose?: string; timing?: string[] }>;
  tookSupplements: boolean;
  supplements: Array<{ categoryId: string; medicationName?: string; dose?: string; timing?: string[] }>;
  hadCaffeine: boolean;
  caffeineEntries: Array<{ typeId: string; count: number }>;
  totalCaffeineMg: number;
  lastCaffeineTime?: string;
  sleepQuality?: number;
  sleepDurationMins?: number;
  sleepEfficiency?: number;
}

interface MedCategory {
  id: string;
  name: string;
  count: number;
  medicationNames: string[];
  doses: string[];
}

interface SuppCategory {
  id: string;
  name: string;
  count: number;
  doses: string[];
}

interface CaffeineCategory {
  id: string;
  name: string;
  daysUsed: number;
  totalServings: number;
}

// Mini bar chart for 14-day rolling data
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
    purple: "bg-purple-500",
    green: "bg-green-500",
    amber: "bg-amber-500",
    red: "bg-red-500",
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

export function SleepHealthFactorsCard({ userId }: SleepHealthFactorsCardProps) {
  const [showDetailModal, setShowDetailModal] = useState<"naps" | "meds" | "supplements" | "caffeine" | null>(null);

  // Use the new comprehensive rolling API
  const rollingData = useQuery(api.physician.getPatientSleepHealthRolling, { userId, days: 14 });

  const hasData = rollingData && rollingData.totalDays > 0;

  // Calculate display values
  const napRate = hasData && rollingData.totalDays > 0
    ? Math.round((rollingData.naps.daysWithNaps / rollingData.totalDays) * 100)
    : 0;

  const medRate = hasData && rollingData.totalDays > 0
    ? Math.round((rollingData.medications.daysUsing / rollingData.totalDays) * 100)
    : 0;

  const suppRate = hasData && rollingData.totalDays > 0
    ? Math.round((rollingData.supplements.daysUsing / rollingData.totalDays) * 100)
    : 0;

  const caffeineRate = hasData && rollingData.totalDays > 0
    ? Math.round((rollingData.caffeine.daysWithCaffeine / rollingData.totalDays) * 100)
    : 0;

  // Prepare chart data
  const napChartData = rollingData?.dailyData.map((d: DailyData) => d.tookNaps ? 1 : 0) ?? [];
  const napMinutesChartData = rollingData?.dailyData.map((d: DailyData) => d.totalNapMinutes) ?? [];
  const medChartData = rollingData?.dailyData.map((d: DailyData) => d.tookMeds ? 1 : 0) ?? [];
  const suppChartData = rollingData?.dailyData.map((d: DailyData) => d.tookSupplements ? 1 : 0) ?? [];
  const caffeineChartData = rollingData?.dailyData.map((d: DailyData) => d.totalCaffeineMg) ?? [];

  return (
    <>
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="flex items-center gap-2 mb-4">
          <div className="w-8 h-8 rounded-lg bg-amber-500/20 flex items-center justify-center">
            <Pill className="w-4 h-4 text-amber-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Sleep Health Factors</h3>
            <p className="text-xs text-gray-500">14-day rolling view</p>
          </div>
        </div>

        <div className="space-y-3">
          {/* Naps Row */}
          <button
            onClick={() => setShowDetailModal("naps")}
            className="w-full flex items-center justify-between p-3 rounded-lg bg-gray-700/30 hover:bg-gray-700/50 transition-colors group"
          >
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-blue-500/20 flex items-center justify-center">
                <Moon className="w-4 h-4 text-blue-400" />
              </div>
              <div className="text-left">
                <p className="text-sm font-medium text-white">Napping</p>
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

          {/* Medications Row */}
          <button
            onClick={() => setShowDetailModal("meds")}
            className="w-full flex items-center justify-between p-3 rounded-lg bg-gray-700/30 hover:bg-gray-700/50 transition-colors group"
          >
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-purple-500/20 flex items-center justify-center">
                <Pill className="w-4 h-4 text-purple-400" />
              </div>
              <div className="text-left">
                <p className="text-sm font-medium text-white">Sleep Medications</p>
                <p className="text-xs text-gray-400">
                  {hasData
                    ? `${rollingData.medications.daysUsing}/${rollingData.totalDays} days (${medRate}%)`
                    : "No data yet"
                  }
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {hasData && rollingData.medications.categories.length > 0 && (
                <span className="px-2 py-0.5 text-xs rounded-full bg-purple-500/20 text-purple-400">
                  {rollingData.medications.categories.length} type{rollingData.medications.categories.length > 1 ? "s" : ""}
                </span>
              )}
              <ChevronRight className="w-4 h-4 text-gray-500 group-hover:text-white transition-colors" />
            </div>
          </button>

          {/* Supplements Row */}
          <button
            onClick={() => setShowDetailModal("supplements")}
            className="w-full flex items-center justify-between p-3 rounded-lg bg-gray-700/30 hover:bg-gray-700/50 transition-colors group"
          >
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-green-500/20 flex items-center justify-center">
                <Leaf className="w-4 h-4 text-green-400" />
              </div>
              <div className="text-left">
                <p className="text-sm font-medium text-white">Supplements</p>
                <p className="text-xs text-gray-400">
                  {hasData
                    ? `${rollingData.supplements.daysUsing}/${rollingData.totalDays} days (${suppRate}%)`
                    : "No data yet"
                  }
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {hasData && rollingData.supplements.categories.length > 0 && (
                <span className="px-2 py-0.5 text-xs rounded-full bg-green-500/20 text-green-400">
                  {rollingData.supplements.categories.length} type{rollingData.supplements.categories.length > 1 ? "s" : ""}
                </span>
              )}
              <ChevronRight className="w-4 h-4 text-gray-500 group-hover:text-white transition-colors" />
            </div>
          </button>

          {/* Caffeine Row */}
          <button
            onClick={() => setShowDetailModal("caffeine")}
            className="w-full flex items-center justify-between p-3 rounded-lg bg-gray-700/30 hover:bg-gray-700/50 transition-colors group"
          >
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-amber-500/20 flex items-center justify-center">
                <Coffee className="w-4 h-4 text-amber-400" />
              </div>
              <div className="text-left">
                <p className="text-sm font-medium text-white">Caffeine</p>
                <p className="text-xs text-gray-400">
                  {hasData
                    ? `${rollingData.caffeine.avgDailyMg}mg/day avg`
                    : "No data yet"
                  }
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {hasData && rollingData.caffeine.avgDailyMg > 400 && (
                <span className="px-2 py-0.5 text-xs rounded-full bg-red-500/20 text-red-400 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  High
                </span>
              )}
              <ChevronRight className="w-4 h-4 text-gray-500 group-hover:text-white transition-colors" />
            </div>
          </button>
        </div>
      </div>

      {/* Detail Modal */}
      {showDetailModal && rollingData && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50">
          <div className="bg-gray-900 rounded-xl max-w-lg w-full max-h-[90vh] overflow-hidden border border-gray-700">
            <div className="flex items-center justify-between p-4 border-b border-gray-700">
              <h3 className="text-lg font-semibold text-white">
                {showDetailModal === "naps" && "Napping - 14 Day View"}
                {showDetailModal === "meds" && "Sleep Medications - 14 Day View"}
                {showDetailModal === "supplements" && "Supplements - 14 Day View"}
                {showDetailModal === "caffeine" && "Caffeine - 14 Day View"}
              </h3>
              <button
                onClick={() => setShowDetailModal(null)}
                className="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-4 overflow-y-auto max-h-[calc(90vh-80px)]">
              {/* Naps Detail */}
              {showDetailModal === "naps" && (
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

                  {/* 14-Day Chart */}
                  <div className="p-3 rounded-lg bg-gray-800/50">
                    <p className="text-sm font-medium text-gray-400 mb-2">Napping Pattern (14 days)</p>
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
              )}

              {/* Medications Detail */}
              {showDetailModal === "meds" && (
                <div className="space-y-4">
                  {/* Summary Stats */}
                  <div className="grid grid-cols-2 gap-4">
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Days Using</p>
                      <p className="text-xl font-bold text-white">{rollingData.medications.daysUsing}</p>
                      <p className="text-xs text-gray-500">of {rollingData.totalDays} tracked</p>
                    </div>
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Types Used</p>
                      <p className="text-xl font-bold text-white">{rollingData.medications.categories.length}</p>
                      <p className="text-xs text-gray-500">medication types</p>
                    </div>
                  </div>

                  {/* 14-Day Chart */}
                  <div className="p-3 rounded-lg bg-gray-800/50">
                    <p className="text-sm font-medium text-gray-400 mb-2">Medication Use (14 days)</p>
                    <MiniBarChart data={medChartData} maxValue={1} color="purple" />
                  </div>

                  {/* Medication Categories */}
                  {rollingData.medications.categories.length > 0 && (
                    <div>
                      <p className="text-sm font-medium text-gray-400 mb-2">Medications Used</p>
                      <div className="space-y-2">
                        {rollingData.medications.categories.map((cat: MedCategory) => (
                          <div key={cat.id} className="p-3 rounded-lg bg-gray-800/50 border border-gray-700/50">
                            <div className="flex items-center justify-between mb-1">
                              <p className="text-sm font-medium text-white">{cat.name}</p>
                              <span className="text-xs text-gray-400">{cat.count}x</span>
                            </div>
                            {cat.medicationNames.length > 0 && (
                              <p className="text-xs text-purple-400 mb-1">
                                {cat.medicationNames.join(", ")}
                              </p>
                            )}
                            {cat.doses.length > 0 && (
                              <p className="text-xs text-gray-400">
                                Doses: {cat.doses.join(", ")}
                              </p>
                            )}
                          </div>
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
                          hasData={day.tookMeds}
                          sleepQuality={day.sleepQuality}
                        >
                          <div className="space-y-1">
                            {day.medications.map((med: { categoryId: string; medicationName?: string; dose?: string; timing?: string[] }, i: number) => (
                              <div key={i} className="flex items-center gap-2 text-xs">
                                <Pill className="w-3 h-3 text-purple-400" />
                                <span className="text-purple-300">{med.medicationName || med.categoryId}</span>
                                {med.dose && (
                                  <>
                                    <span className="text-gray-400">•</span>
                                    <span>{med.dose}</span>
                                  </>
                                )}
                                {med.timing && med.timing.length > 0 && (
                                  <>
                                    <span className="text-gray-400">•</span>
                                    <span className="text-gray-400">{med.timing.join(", ")}</span>
                                  </>
                                )}
                              </div>
                            ))}
                          </div>
                        </DayRow>
                      ))}
                    </div>
                  </div>

                  {medRate > 70 && (
                    <div className="p-3 rounded-lg bg-purple-500/10 border border-purple-500/30">
                      <p className="text-sm text-purple-400">
                        <AlertCircle className="w-4 h-4 inline mr-1" />
                        High frequency of sleep medication use - consider reviewing with patient
                      </p>
                    </div>
                  )}
                </div>
              )}

              {/* Supplements Detail */}
              {showDetailModal === "supplements" && (
                <div className="space-y-4">
                  {/* Summary Stats */}
                  <div className="grid grid-cols-2 gap-4">
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Days Using</p>
                      <p className="text-xl font-bold text-white">{rollingData.supplements.daysUsing}</p>
                      <p className="text-xs text-gray-500">of {rollingData.totalDays} tracked</p>
                    </div>
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Types Used</p>
                      <p className="text-xl font-bold text-white">{rollingData.supplements.categories.length}</p>
                      <p className="text-xs text-gray-500">supplement types</p>
                    </div>
                  </div>

                  {/* 14-Day Chart */}
                  <div className="p-3 rounded-lg bg-gray-800/50">
                    <p className="text-sm font-medium text-gray-400 mb-2">Supplement Use (14 days)</p>
                    <MiniBarChart data={suppChartData} maxValue={1} color="green" />
                  </div>

                  {/* Supplement Categories */}
                  {rollingData.supplements.categories.length > 0 && (
                    <div>
                      <p className="text-sm font-medium text-gray-400 mb-2">Supplements Used</p>
                      <div className="space-y-2">
                        {rollingData.supplements.categories.map((cat: SuppCategory) => (
                          <div key={cat.id} className="p-3 rounded-lg bg-gray-800/50 border border-gray-700/50">
                            <div className="flex items-center justify-between mb-1">
                              <p className="text-sm font-medium text-white">{cat.name}</p>
                              <span className="text-xs text-gray-400">{cat.count}x</span>
                            </div>
                            {cat.doses.length > 0 && (
                              <p className="text-xs text-gray-400">
                                Doses: {cat.doses.join(", ")}
                              </p>
                            )}
                          </div>
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
                          hasData={day.tookSupplements}
                          sleepQuality={day.sleepQuality}
                        >
                          <div className="space-y-1">
                            {day.supplements.map((supp: { categoryId: string; medicationName?: string; dose?: string; timing?: string[] }, i: number) => (
                              <div key={i} className="flex items-center gap-2 text-xs">
                                <Leaf className="w-3 h-3 text-green-400" />
                                <span className="text-green-300">
                                  {supp.medicationName || SUPPLEMENT_NAMES[supp.categoryId] || supp.categoryId}
                                </span>
                                {supp.dose && (
                                  <>
                                    <span className="text-gray-400">•</span>
                                    <span>{supp.dose}</span>
                                  </>
                                )}
                                {supp.timing && supp.timing.length > 0 && (
                                  <>
                                    <span className="text-gray-400">•</span>
                                    <span className="text-gray-400">{supp.timing.join(", ")}</span>
                                  </>
                                )}
                              </div>
                            ))}
                          </div>
                        </DayRow>
                      ))}
                    </div>
                  </div>

                  <div className="p-3 rounded-lg bg-green-500/10 border border-green-500/30">
                    <p className="text-sm text-green-400">
                      <Leaf className="w-4 h-4 inline mr-1" />
                      {suppRate > 0
                        ? "Patient using natural sleep supplements"
                        : "No supplement use reported in this period"
                      }
                    </p>
                  </div>
                </div>
              )}

              {/* Caffeine Detail */}
              {showDetailModal === "caffeine" && (
                <div className="space-y-4">
                  {/* Summary Stats */}
                  <div className="grid grid-cols-2 gap-4">
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Avg Daily</p>
                      <p className="text-xl font-bold text-white">{rollingData.caffeine.avgDailyMg}mg</p>
                      <p className="text-xs text-gray-500">per day</p>
                    </div>
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Caffeine Days</p>
                      <p className="text-xl font-bold text-white">{rollingData.caffeine.daysWithCaffeine}</p>
                      <p className="text-xs text-gray-500">of {rollingData.totalDays} tracked</p>
                    </div>
                  </div>

                  {/* 14-Day Chart */}
                  <div className="p-3 rounded-lg bg-gray-800/50">
                    <p className="text-sm font-medium text-gray-400 mb-2">Daily Caffeine (mg)</p>
                    <MiniBarChart data={caffeineChartData} maxValue={Math.max(...caffeineChartData, 400)} color="amber" />
                    <div className="flex justify-end mt-1">
                      <span className="text-[10px] text-gray-500">400mg = recommended max</span>
                    </div>
                  </div>

                  {/* Caffeine Sources */}
                  {rollingData.caffeine.categories.length > 0 && (
                    <div>
                      <p className="text-sm font-medium text-gray-400 mb-2">Caffeine Sources</p>
                      <div className="space-y-2">
                        {rollingData.caffeine.categories.map((cat: CaffeineCategory) => (
                          <div key={cat.id} className="p-2 rounded-lg bg-gray-800/50 flex items-center justify-between">
                            <div>
                              <p className="text-sm text-white">{cat.name}</p>
                              <p className="text-xs text-gray-400">{cat.totalServings} servings total</p>
                            </div>
                            <span className="text-xs text-gray-400">{cat.daysUsed} days</span>
                          </div>
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
                          hasData={day.hadCaffeine}
                          sleepQuality={day.sleepQuality}
                        >
                          <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2 text-xs">
                              <Coffee className="w-3 h-3 text-amber-400" />
                              <span>{day.totalCaffeineMg}mg total</span>
                              {day.caffeineEntries.length > 0 && (
                                <>
                                  <span className="text-gray-400">•</span>
                                  <span className="text-gray-400">
                                    {day.caffeineEntries.reduce((sum: number, e: { typeId: string; count: number }) => sum + e.count, 0)} drinks
                                  </span>
                                </>
                              )}
                            </div>
                            {day.lastCaffeineTime && (
                              <span className="text-xs text-gray-400">
                                Last: {day.lastCaffeineTime}
                              </span>
                            )}
                          </div>
                        </DayRow>
                      ))}
                    </div>
                  </div>

                  {rollingData.caffeine.avgDailyMg > 400 && (
                    <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/30">
                      <p className="text-sm text-red-400">
                        <AlertCircle className="w-4 h-4 inline mr-1" />
                        Average intake exceeds 400mg/day - may significantly impact sleep quality
                      </p>
                    </div>
                  )}

                  {rollingData.caffeine.avgDailyMg > 0 && rollingData.caffeine.avgDailyMg <= 400 && (
                    <div className="p-3 rounded-lg bg-amber-500/10 border border-amber-500/30">
                      <p className="text-sm text-amber-400">
                        <Coffee className="w-4 h-4 inline mr-1" />
                        Moderate caffeine intake - monitor timing relative to bedtime
                      </p>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
