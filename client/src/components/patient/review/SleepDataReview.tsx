"use client";
/* eslint-disable @typescript-eslint/no-unused-vars, prefer-const */

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useMemo } from "react";
import {
  Moon,
  Sun,
  Clock,
  Zap,
  BedDouble,
  AlertTriangle,
  TrendingUp,
  TrendingDown,
  Minus,
  Coffee,
  Pill,
  Briefcase,
  Palmtree,
  AlertCircle,
  Info,
} from "lucide-react";
import { ReviewSection } from "./ReviewSection";

interface SleepDataReviewProps {
  userId: Id<"users">;
  isReviewed: boolean;
  onReviewedChange: (reviewed: boolean) => void;
}

interface DayData {
  day: number;
  date?: string;
  bedtime?: string;
  wakeTime?: string;
  sleepDuration?: number;
  sleepQuality?: number;
  awakenings?: number;
  timeToFallAsleep?: number;
}

export function SleepDataReview({
  userId,
  isReviewed,
  onReviewedChange,
}: SleepDataReviewProps) {
  // Fetch all day data
  const dayData = useQuery(api.physician.getPatientDayData, { userId });
  const sleepMetrics = useQuery(api.healthkit.getPatientHealthSummary, { userId });
  const napSummary = useQuery(api.physician.getPatientNapSummary, { userId });
  const medSummary = useQuery(api.physician.getPatientMedicationSummary, { userId });
  const dayTypeAnalysis = useQuery(api.physician.getPatientDayTypeAnalysis, { userId });

  // Process sleep data from questionnaire responses
  const processedData = useMemo(() => {
    if (!dayData) return null;

    const days: DayData[] = [];
    let totalDuration = 0;
    let totalQuality = 0;
    let totalAwakenings = 0;
    let totalLatency = 0;
    let daysWithData = 0;

    // Group responses by day
    const dayGroups: Record<number, Record<string, string | number>> = {};
    dayData.forEach((response: { question_id: string; value: string | number; day?: number }) => {
      const day = response.day || 1;
      if (!dayGroups[day]) dayGroups[day] = {};
      dayGroups[day][response.question_id] = response.value;
    });

    // Helper to get value with fallback (supports both CSD_ and SD_ prefixes)
    const getValue = (responses: Record<string, string | number>, csdKey: string, sdKey: string) => {
      return responses[csdKey] ?? responses[sdKey];
    };

    // Process each day
    Object.entries(dayGroups).forEach(([dayStr, responses]) => {
      const day = parseInt(dayStr);
      const dayEntry: DayData = { day };

      // Bedtime (CSD_1 or SD_GOT_INTO_BED or CSD_INTO_BED)
      const bedtime = getValue(responses, "CSD_1", "SD_GOT_INTO_BED") ?? responses["CSD_INTO_BED"];
      if (bedtime) {
        dayEntry.bedtime = String(bedtime);
      }

      // Final wake time (CSD_3 or SD_FINAL_WAKE or CSD_FINAL_WAKE)
      const wakeTime = getValue(responses, "CSD_3", "SD_FINAL_WAKE") ?? responses["CSD_FINAL_WAKE"];
      if (wakeTime) {
        dayEntry.wakeTime = String(wakeTime);
      }

      // Time to fall asleep / latency (CSD_2 or SD_SLEEP_LATENCY or CSD_LATENCY)
      const latency = getValue(responses, "CSD_2", "SD_SLEEP_LATENCY") ?? responses["CSD_LATENCY"];
      if (latency) {
        dayEntry.timeToFallAsleep = Number(latency);
        totalLatency += dayEntry.timeToFallAsleep;
      }

      // Number of awakenings (CSD_4 or SD_AWAKENINGS_COUNT or CSD_AWAKENINGS)
      const awakenings = getValue(responses, "CSD_4", "SD_AWAKENINGS_COUNT") ?? responses["CSD_AWAKENINGS"];
      if (awakenings) {
        dayEntry.awakenings = Number(awakenings);
        totalAwakenings += dayEntry.awakenings;
      }

      // Sleep quality (CSD_5 or SD_SLEEP_QUALITY or CSD_QUALITY) - note: CSD uses 1-5, SD uses 1-10
      const quality = getValue(responses, "CSD_5", "SD_SLEEP_QUALITY") ?? responses["CSD_QUALITY"];
      if (quality) {
        const qualityNum = Number(quality);
        // Normalize SD_SLEEP_QUALITY (1-10) to 1-5 scale if needed
        dayEntry.sleepQuality = qualityNum > 5 ? Math.round(qualityNum / 2) : qualityNum;
        totalQuality += dayEntry.sleepQuality;
      }

      // Calculate sleep duration from bedtime and wake time
      if (dayEntry.bedtime && dayEntry.wakeTime) {
        const [bedH, bedM] = dayEntry.bedtime.split(":").map(Number);
        const [wakeH, wakeM] = dayEntry.wakeTime.split(":").map(Number);
        let bedMinutes = bedH * 60 + bedM;
        let wakeMinutes = wakeH * 60 + wakeM;

        // Handle overnight sleep (wake time < bedtime)
        if (wakeMinutes < bedMinutes) {
          wakeMinutes += 24 * 60;
        }

        dayEntry.sleepDuration = (wakeMinutes - bedMinutes) / 60;
        totalDuration += dayEntry.sleepDuration;
        daysWithData++;
      }

      days.push(dayEntry);
    });

    // Sort by day
    days.sort((a, b) => a.day - b.day);

    // Calculate averages
    const avgDuration = daysWithData > 0 ? totalDuration / daysWithData : 0;
    const avgQuality = daysWithData > 0 ? totalQuality / daysWithData : 0;
    const avgAwakenings = daysWithData > 0 ? totalAwakenings / daysWithData : 0;
    const avgLatency = daysWithData > 0 ? totalLatency / daysWithData : 0;

    // Calculate sleep efficiency (simplified)
    const avgTimeInBed = avgDuration + avgLatency / 60;
    const sleepEfficiency = avgTimeInBed > 0 ? (avgDuration / avgTimeInBed) * 100 : 0;

    return {
      days,
      totalDays: days.length,
      daysWithData,
      avgDuration,
      avgQuality,
      avgAwakenings,
      avgLatency,
      sleepEfficiency,
    };
  }, [dayData]);

  // Build preview text
  const preview = useMemo(() => {
    if (!processedData) return "Loading sleep data...";
    if (processedData.daysWithData === 0) return "No sleep logs recorded";

    return `${processedData.daysWithData} days • Avg ${processedData.avgDuration.toFixed(1)}h • Quality ${processedData.avgQuality.toFixed(1)}/5`;
  }, [processedData]);

  const formatTime = (time: string | undefined) => {
    if (!time) return "--";
    const [h, m] = time.split(":");
    const hour = parseInt(h);
    const ampm = hour >= 12 ? "PM" : "AM";
    const displayHour = hour > 12 ? hour - 12 : hour === 0 ? 12 : hour;
    return `${displayHour}:${m} ${ampm}`;
  };

  const getQualityColor = (quality: number) => {
    if (quality >= 4) return "text-green-400";
    if (quality >= 3) return "text-amber-400";
    return "text-red-400";
  };

  const getDurationColor = (hours: number) => {
    if (hours >= 7 && hours <= 9) return "text-green-400";
    if (hours >= 6 && hours < 7) return "text-amber-400";
    return "text-red-400";
  };

  const getEfficiencyColor = (efficiency: number) => {
    if (efficiency >= 85) return "text-green-400 bg-green-500/20";
    if (efficiency >= 75) return "text-amber-400 bg-amber-500/20";
    return "text-red-400 bg-red-500/20";
  };

  return (
    <ReviewSection
      id="sleep_data"
      title="Review sleep data"
      icon={<Moon className="w-4 h-4" />}
      preview={preview}
      isReviewed={isReviewed}
      onReviewedChange={onReviewedChange}
      isLoading={!processedData}
    >
      {processedData && processedData.daysWithData > 0 ? (
        <div className="space-y-4">
          {/* Summary Stats */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <div className="p-3 bg-gray-800/50 rounded-lg">
              <div className="flex items-center gap-2 text-gray-400 mb-1">
                <Clock className="w-3 h-3" />
                <span className="text-[10px] uppercase">Avg Duration</span>
              </div>
              <p className={`text-lg font-semibold ${getDurationColor(processedData.avgDuration)}`}>
                {processedData.avgDuration.toFixed(1)}h
              </p>
            </div>

            <div className="p-3 bg-gray-800/50 rounded-lg">
              <div className="flex items-center gap-2 text-gray-400 mb-1">
                <Zap className="w-3 h-3" />
                <span className="text-[10px] uppercase">Avg Quality</span>
              </div>
              <p className={`text-lg font-semibold ${getQualityColor(processedData.avgQuality)}`}>
                {processedData.avgQuality.toFixed(1)}/5
              </p>
            </div>

            <div className="p-3 bg-gray-800/50 rounded-lg">
              <div className="flex items-center gap-2 text-gray-400 mb-1">
                <AlertTriangle className="w-3 h-3" />
                <span className="text-[10px] uppercase">Avg Awakenings</span>
              </div>
              <p className="text-lg font-semibold text-gray-300">
                {processedData.avgAwakenings.toFixed(1)}
              </p>
            </div>

            <div className="p-3 bg-gray-800/50 rounded-lg">
              <div className="flex items-center gap-2 text-gray-400 mb-1">
                <BedDouble className="w-3 h-3" />
                <span className="text-[10px] uppercase">Efficiency</span>
              </div>
              <p className={`text-lg font-semibold px-2 py-0.5 rounded ${getEfficiencyColor(processedData.sleepEfficiency)}`}>
                {processedData.sleepEfficiency.toFixed(0)}%
              </p>
            </div>
          </div>

          {/* Additional Metrics Row */}
          <div className="flex flex-wrap gap-4 text-sm">
            <div className="flex items-center gap-2">
              <Moon className="w-4 h-4 text-indigo-400" />
              <span className="text-gray-400">Avg Bedtime:</span>
              <span className="text-white font-medium">
                {processedData.days.length > 0 && processedData.days[0].bedtime
                  ? formatTime(processedData.days[processedData.days.length - 1].bedtime)
                  : "--"}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <Sun className="w-4 h-4 text-amber-400" />
              <span className="text-gray-400">Avg Wake:</span>
              <span className="text-white font-medium">
                {processedData.days.length > 0 && processedData.days[0].wakeTime
                  ? formatTime(processedData.days[processedData.days.length - 1].wakeTime)
                  : "--"}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-purple-400" />
              <span className="text-gray-400">Avg Latency:</span>
              <span className="text-white font-medium">
                {processedData.avgLatency.toFixed(0)} min
              </span>
            </div>
          </div>

          {/* Day-by-Day Breakdown */}
          <div>
            <h4 className="text-xs font-medium text-gray-400 mb-2 uppercase">
              Day-by-Day Log ({processedData.daysWithData} days)
            </h4>
            <div className="max-h-[200px] overflow-y-auto space-y-1">
              {processedData.days.map((day) => (
                <div
                  key={day.day}
                  className="flex items-center gap-3 p-2 bg-gray-800/30 rounded-lg text-sm"
                >
                  <span className="w-12 text-gray-500 text-xs">Day {day.day}</span>
                  <div className="flex-1 flex items-center gap-4">
                    <div className="flex items-center gap-1 text-gray-300">
                      <Moon className="w-3 h-3 text-indigo-400" />
                      {formatTime(day.bedtime)}
                    </div>
                    <div className="flex items-center gap-1 text-gray-300">
                      <Sun className="w-3 h-3 text-amber-400" />
                      {formatTime(day.wakeTime)}
                    </div>
                    <div className={`${getDurationColor(day.sleepDuration || 0)}`}>
                      {day.sleepDuration?.toFixed(1) || "--"}h
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`text-xs ${getQualityColor(day.sleepQuality || 0)}`}>
                      Q: {day.sleepQuality || "--"}
                    </span>
                    <span className="text-xs text-gray-500">
                      {day.awakenings || 0} wake
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Napping Patterns */}
          {napSummary && napSummary.napDays > 0 && (
            <div className="p-3 bg-gray-800/50 rounded-lg">
              <div className="flex items-center gap-2 text-gray-400 mb-3">
                <Coffee className="w-4 h-4" />
                <h4 className="text-xs font-medium uppercase">Napping Patterns</h4>
              </div>
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Days with naps:</span>
                  <span className="text-white font-medium">
                    {napSummary.napDays}/{napSummary.totalDays}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Avg naps/day:</span>
                  <span className="text-white font-medium">
                    {napSummary.avgNapCount.toFixed(1)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Avg duration:</span>
                  <span className="text-white font-medium">
                    {napSummary.avgDuration} min
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Common times:</span>
                  <span className="text-white font-medium">
                    {napSummary.commonTimes.slice(0, 2).join(", ")}
                  </span>
                </div>
              </div>
            </div>
          )}

          {/* Sleep Medications */}
          {medSummary && medSummary.medicationDays > 0 && (
            <div className="p-3 bg-gray-800/50 rounded-lg">
              <div className="flex items-center gap-2 text-gray-400 mb-3">
                <Pill className="w-4 h-4" />
                <h4 className="text-xs font-medium uppercase">Sleep Medications</h4>
              </div>
              <div className="space-y-3">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Days with medications:</span>
                  <span className="text-white font-medium">
                    {medSummary.medicationDays}/{medSummary.totalDays}
                  </span>
                </div>
                {medSummary.categories.length > 0 && (
                  <div className="flex flex-wrap gap-1.5">
                    {medSummary.categories.map((cat: NonNullable<typeof medSummary>["categories"][number]) => (
                      <span
                        key={cat.id}
                        className="px-2 py-0.5 bg-purple-500/20 text-purple-300 rounded text-xs"
                      >
                        {cat.name} ({cat.count})
                      </span>
                    ))}
                  </div>
                )}
                {medSummary.otherMedications.length > 0 && (
                  <div className="text-xs text-gray-400">
                    <span className="text-gray-500">Other: </span>
                    {medSummary.otherMedications.join(", ")}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Workday vs Weekend Analysis */}
          {dayTypeAnalysis && dayTypeAnalysis.hasData && (dayTypeAnalysis.workdayStats || dayTypeAnalysis.weekendStats) && (
            <div className="p-3 bg-gray-800/50 rounded-lg">
              <div className="flex items-center gap-2 text-gray-400 mb-3">
                <Briefcase className="w-4 h-4" />
                <h4 className="text-xs font-medium uppercase">Workday vs Weekend Patterns</h4>
              </div>

              {/* Comparison Grid */}
              <div className="grid grid-cols-3 gap-2 text-sm mb-3">
                <div className="text-gray-500 text-xs"></div>
                <div className="text-center">
                  <div className="flex items-center justify-center gap-1 text-blue-400">
                    <Briefcase className="w-3 h-3" />
                    <span className="text-xs font-medium">Workday</span>
                  </div>
                  <span className="text-[10px] text-gray-500">
                    ({dayTypeAnalysis.workdayStats?.count || 0} days)
                  </span>
                </div>
                <div className="text-center">
                  <div className="flex items-center justify-center gap-1 text-green-400">
                    <Palmtree className="w-3 h-3" />
                    <span className="text-xs font-medium">Weekend</span>
                  </div>
                  <span className="text-[10px] text-gray-500">
                    ({dayTypeAnalysis.weekendStats?.count || 0} days)
                  </span>
                </div>

                {/* Sleep Duration Row */}
                <div className="text-gray-400 text-xs flex items-center">
                  <Clock className="w-3 h-3 mr-1" /> Duration
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.workdayStats?.avgSleepMins
                    ? `${(dayTypeAnalysis.workdayStats.avgSleepMins / 60).toFixed(1)}h`
                    : "--"}
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.weekendStats?.avgSleepMins
                    ? `${(dayTypeAnalysis.weekendStats.avgSleepMins / 60).toFixed(1)}h`
                    : "--"}
                </div>

                {/* Efficiency Row */}
                <div className="text-gray-400 text-xs flex items-center">
                  <BedDouble className="w-3 h-3 mr-1" /> Efficiency
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.workdayStats?.avgEfficiency
                    ? `${dayTypeAnalysis.workdayStats.avgEfficiency}%`
                    : "--"}
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.weekendStats?.avgEfficiency
                    ? `${dayTypeAnalysis.weekendStats.avgEfficiency}%`
                    : "--"}
                </div>

                {/* Quality Row */}
                <div className="text-gray-400 text-xs flex items-center">
                  <Zap className="w-3 h-3 mr-1" /> Quality
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.workdayStats?.avgQuality
                    ? `${dayTypeAnalysis.workdayStats.avgQuality}/10`
                    : "--"}
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.weekendStats?.avgQuality
                    ? `${dayTypeAnalysis.weekendStats.avgQuality}/10`
                    : "--"}
                </div>

                {/* Latency Row */}
                <div className="text-gray-400 text-xs flex items-center">
                  <Moon className="w-3 h-3 mr-1" /> Latency
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.workdayStats?.avgLatencyMins != null
                    ? `${dayTypeAnalysis.workdayStats.avgLatencyMins}m`
                    : "--"}
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.weekendStats?.avgLatencyMins != null
                    ? `${dayTypeAnalysis.weekendStats.avgLatencyMins}m`
                    : "--"}
                </div>

                {/* Naps Row */}
                <div className="text-gray-400 text-xs flex items-center">
                  <Coffee className="w-3 h-3 mr-1" /> Naps
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.workdayStats?.daysWithNaps != null
                    ? `${dayTypeAnalysis.workdayStats.daysWithNaps} days`
                    : "--"}
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.weekendStats?.daysWithNaps != null
                    ? `${dayTypeAnalysis.weekendStats.daysWithNaps} days`
                    : "--"}
                </div>

                {/* Meds Row */}
                <div className="text-gray-400 text-xs flex items-center">
                  <Pill className="w-3 h-3 mr-1" /> Meds
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.workdayStats?.daysWithMeds != null
                    ? `${dayTypeAnalysis.workdayStats.daysWithMeds} days`
                    : "--"}
                </div>
                <div className="text-center text-white">
                  {dayTypeAnalysis.weekendStats?.daysWithMeds != null
                    ? `${dayTypeAnalysis.weekendStats.daysWithMeds} days`
                    : "--"}
                </div>
              </div>

              {/* Difference Summary */}
              {dayTypeAnalysis.differences && (
                <div className="flex flex-wrap gap-2 mt-2 pt-2 border-t border-gray-700">
                  {dayTypeAnalysis.differences.sleepDiffMins !== 0 && (
                    <div className={`text-xs px-2 py-1 rounded ${
                      Math.abs(dayTypeAnalysis.differences.sleepDiffMins) > 60
                        ? "bg-amber-500/20 text-amber-300"
                        : "bg-gray-700 text-gray-300"
                    }`}>
                      {dayTypeAnalysis.differences.sleepDiffMins > 0 ? (
                        <TrendingUp className="w-3 h-3 inline mr-1" />
                      ) : (
                        <TrendingDown className="w-3 h-3 inline mr-1" />
                      )}
                      {Math.abs(dayTypeAnalysis.differences.sleepDiffMins)} min {dayTypeAnalysis.differences.sleepDiffMins > 0 ? "more" : "less"} on weekends
                    </div>
                  )}
                </div>
              )}

              {/* Clinical Flags */}
              {dayTypeAnalysis.flags && dayTypeAnalysis.flags.length > 0 && (
                <div className="mt-3 space-y-2">
                  {dayTypeAnalysis.flags.map((flag: { type: string; severity: "info" | "warning" | "alert"; message: string }, idx: number) => (
                    <div
                      key={idx}
                      className={`flex items-start gap-2 p-2 rounded text-xs ${
                        flag.severity === "alert"
                          ? "bg-red-500/20 text-red-300 border border-red-500/30"
                          : flag.severity === "warning"
                          ? "bg-amber-500/20 text-amber-300 border border-amber-500/30"
                          : "bg-blue-500/10 text-blue-300 border border-blue-500/20"
                      }`}
                    >
                      {flag.severity === "alert" ? (
                        <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
                      ) : flag.severity === "warning" ? (
                        <AlertTriangle className="w-4 h-4 flex-shrink-0 mt-0.5" />
                      ) : (
                        <Info className="w-4 h-4 flex-shrink-0 mt-0.5" />
                      )}
                      <div>
                        <span className="font-medium capitalize">
                          {flag.type.replace(/_/g, " ")}:
                        </span>{" "}
                        {flag.message}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Patterns Detected */}
          {sleepMetrics && (
            <div className="p-3 bg-indigo-500/10 border border-indigo-500/30 rounded-lg">
              <h4 className="text-xs font-medium text-indigo-400 mb-2">
                HealthKit Integration
              </h4>
              <p className="text-xs text-gray-400">
                HealthKit data available - sleep stages and heart rate metrics can be analyzed.
              </p>
            </div>
          )}
        </div>
      ) : (
        <div className="text-center py-6 text-gray-500">
          <Moon className="w-8 h-8 mx-auto mb-2 opacity-50" />
          <p className="text-sm">No sleep log data recorded</p>
          <p className="text-xs mt-1">Patient has not completed sleep diary entries</p>
        </div>
      )}
    </ReviewSection>
  );
}
