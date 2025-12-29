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
} from "lucide-react";

interface SleepHealthFactorsCardProps {
  userId: Id<"users">;
}

export function SleepHealthFactorsCard({ userId }: SleepHealthFactorsCardProps) {
  const [showDetailModal, setShowDetailModal] = useState<"naps" | "meds" | "caffeine" | null>(null);

  // Fetch summary data
  const napSummary = useQuery(api.physician.getPatientNapSummary, { userId });
  const medSummary = useQuery(api.physician.getPatientMedicationSummary, { userId });
  const caffeineSummary = useQuery(api.physician.getPatientCaffeineSummary, { userId });

  const hasNapData = napSummary && napSummary.totalDays > 0;
  const hasMedData = medSummary && medSummary.totalDays > 0;
  const hasCaffeineData = caffeineSummary && caffeineSummary.totalDays > 0;

  // Calculate nap rate
  const napRate = hasNapData && napSummary.totalDays > 0
    ? Math.round((napSummary.napDays / napSummary.totalDays) * 100)
    : 0;

  // Calculate medication rate
  const medRate = hasMedData && medSummary.totalDays > 0
    ? Math.round((medSummary.medicationDays / medSummary.totalDays) * 100)
    : 0;

  // Get caffeine average
  const avgCaffeine = hasCaffeineData && caffeineSummary.avgServingsPerDay
    ? caffeineSummary.avgServingsPerDay
    : "—";

  return (
    <>
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="flex items-center gap-2 mb-4">
          <div className="w-8 h-8 rounded-lg bg-amber-500/20 flex items-center justify-center">
            <Pill className="w-4 h-4 text-amber-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Sleep Health Factors</h3>
            <p className="text-xs text-gray-500">Naps, medications, caffeine</p>
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
                  {hasNapData
                    ? `${napSummary.napDays}/${napSummary.totalDays} days (${napRate}%)`
                    : "No data yet"
                  }
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {hasNapData && napRate > 50 && (
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
                <p className="text-sm font-medium text-white">Sleep Aids</p>
                <p className="text-xs text-gray-400">
                  {hasMedData
                    ? `${medSummary.medicationDays}/${medSummary.totalDays} days (${medRate}%)`
                    : "No data yet"
                  }
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {hasMedData && medSummary.categories.length > 0 && (
                <span className="px-2 py-0.5 text-xs rounded-full bg-purple-500/20 text-purple-400">
                  {medSummary.categories.length} types
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
                  {hasCaffeineData
                    ? `${avgCaffeine} drinks/day avg`
                    : "No data yet"
                  }
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {hasCaffeineData && caffeineSummary.avgMgPerDay > 400 && (
                <span className="px-2 py-0.5 text-xs rounded-full bg-red-500/20 text-red-400 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  High intake
                </span>
              )}
              <ChevronRight className="w-4 h-4 text-gray-500 group-hover:text-white transition-colors" />
            </div>
          </button>
        </div>
      </div>

      {/* Detail Modal */}
      {showDetailModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50">
          <div className="bg-gray-900 rounded-xl max-w-md w-full max-h-[90vh] overflow-hidden border border-gray-700">
            <div className="flex items-center justify-between p-4 border-b border-gray-700">
              <h3 className="text-lg font-semibold text-white">
                {showDetailModal === "naps" && "Napping Details"}
                {showDetailModal === "meds" && "Sleep Aid Details"}
                {showDetailModal === "caffeine" && "Caffeine Details"}
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
              {showDetailModal === "naps" && napSummary && (
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Nap Days</p>
                      <p className="text-xl font-bold text-white">{napSummary.napDays}</p>
                      <p className="text-xs text-gray-500">of {napSummary.totalDays} tracked</p>
                    </div>
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Avg Duration</p>
                      <p className="text-xl font-bold text-white">{napSummary.avgDuration}m</p>
                      <p className="text-xs text-gray-500">per nap session</p>
                    </div>
                  </div>

                  {napSummary.commonTimes.length > 0 && (
                    <div>
                      <p className="text-sm font-medium text-gray-400 mb-2">Common Nap Times</p>
                      <div className="flex flex-wrap gap-2">
                        {napSummary.commonTimes.map((time: string) => (
                          <span key={time} className="px-3 py-1.5 rounded-full bg-blue-500/20 text-blue-400 text-sm">
                            <Clock className="w-3 h-3 inline mr-1" />
                            {time}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}

                  <div className="p-3 rounded-lg bg-amber-500/10 border border-amber-500/30">
                    <p className="text-sm text-amber-400">
                      <AlertCircle className="w-4 h-4 inline mr-1" />
                      {napRate > 50
                        ? "Frequent napping may indicate insufficient nighttime sleep"
                        : "Occasional napping patterns detected"
                      }
                    </p>
                  </div>
                </div>
              )}

              {/* Medications Detail */}
              {showDetailModal === "meds" && medSummary && (
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Days Using</p>
                      <p className="text-xl font-bold text-white">{medSummary.medicationDays}</p>
                      <p className="text-xs text-gray-500">of {medSummary.totalDays} tracked</p>
                    </div>
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Types Used</p>
                      <p className="text-xl font-bold text-white">{medSummary.categories.length}</p>
                      <p className="text-xs text-gray-500">medication categories</p>
                    </div>
                  </div>

                  {medSummary.categories.length > 0 && (
                    <div>
                      <p className="text-sm font-medium text-gray-400 mb-2">Medications Used</p>
                      <div className="space-y-2">
                        {medSummary.categories.map((cat: { id: string; name: string; count: number; commonDoses: string[]; timingBreakdown?: Record<string, number> }) => (
                          <div key={cat.id} className="p-3 rounded-lg bg-gray-800/50 border border-gray-700/50">
                            <div className="flex items-center justify-between mb-1">
                              <p className="text-sm font-medium text-white">{cat.name}</p>
                              <span className="text-xs text-gray-400">{cat.count}x</span>
                            </div>
                            {cat.commonDoses.length > 0 && (
                              <p className="text-xs text-gray-400">
                                Doses: {cat.commonDoses.join(", ")}
                              </p>
                            )}
                            {cat.timingBreakdown && Object.keys(cat.timingBreakdown).length > 0 && (
                              <div className="mt-2 flex flex-wrap gap-1">
                                {Object.entries(cat.timingBreakdown).map(([timing, count]) => (
                                  <span
                                    key={timing}
                                    className="px-2 py-0.5 text-xs rounded bg-purple-500/20 text-purple-400"
                                  >
                                    {timing}: {count}x
                                  </span>
                                ))}
                              </div>
                            )}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {medSummary.otherMedications.length > 0 && (
                    <div>
                      <p className="text-sm font-medium text-gray-400 mb-2">Other Reported</p>
                      <div className="flex flex-wrap gap-2">
                        {medSummary.otherMedications.map((med: string, i: number) => (
                          <span key={i} className="px-3 py-1.5 rounded-full bg-gray-700 text-gray-300 text-sm">
                            {med}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}

                  {medSummary.mostCommonTiming && (
                    <div className="p-3 rounded-lg bg-purple-500/10 border border-purple-500/30">
                      <p className="text-sm text-purple-400">
                        <Clock className="w-4 h-4 inline mr-1" />
                        Most common timing: <strong>{medSummary.mostCommonTiming}</strong>
                      </p>
                    </div>
                  )}
                </div>
              )}

              {/* Caffeine Detail */}
              {showDetailModal === "caffeine" && caffeineSummary && (
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Avg Daily</p>
                      <p className="text-xl font-bold text-white">{caffeineSummary.avgServingsPerDay || "—"}</p>
                      <p className="text-xs text-gray-500">drinks per day</p>
                    </div>
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Avg Caffeine</p>
                      <p className="text-xl font-bold text-white">{caffeineSummary.avgMgPerDay || 0}mg</p>
                      <p className="text-xs text-gray-500">per day</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Caffeine Days</p>
                      <p className="text-xl font-bold text-white">{caffeineSummary.caffeineDays}</p>
                      <p className="text-xs text-gray-500">of {caffeineSummary.totalDays} tracked</p>
                    </div>
                    <div className="p-3 rounded-lg bg-gray-800/50">
                      <p className="text-xs text-gray-400">Total Intake</p>
                      <p className="text-xl font-bold text-white">{caffeineSummary.totalMgAllDays}mg</p>
                      <p className="text-xs text-gray-500">all time</p>
                    </div>
                  </div>

                  {caffeineSummary.avgMgPerDay > 400 && (
                    <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/30">
                      <p className="text-sm text-red-400">
                        <AlertCircle className="w-4 h-4 inline mr-1" />
                        Average intake exceeds 400mg/day - may impact sleep quality
                      </p>
                    </div>
                  )}

                  {caffeineSummary.typeBreakdown && caffeineSummary.typeBreakdown.length > 0 && (
                    <div>
                      <p className="text-sm font-medium text-gray-400 mb-2">Caffeine Sources</p>
                      <div className="space-y-2">
                        {caffeineSummary.typeBreakdown.map((type: { id: string; name: string; totalServings: number; totalMg: number }) => (
                          <div key={type.id} className="p-2 rounded-lg bg-gray-800/50 flex items-center justify-between">
                            <div>
                              <p className="text-sm text-white">{type.name}</p>
                              <p className="text-xs text-gray-400">{type.totalServings} servings total</p>
                            </div>
                            <span className="text-sm font-medium text-amber-400">{type.totalMg}mg</span>
                          </div>
                        ))}
                      </div>
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
