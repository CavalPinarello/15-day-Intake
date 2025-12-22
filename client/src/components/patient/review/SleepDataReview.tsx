"use client";

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

    // Process each day
    Object.entries(dayGroups).forEach(([dayStr, responses]) => {
      const day = parseInt(dayStr);
      const dayEntry: DayData = { day };

      // CSD_1: Bedtime (e.g., "23:30")
      if (responses["CSD_1"]) {
        dayEntry.bedtime = String(responses["CSD_1"]);
      }

      // CSD_3: Final wake time (e.g., "07:00")
      if (responses["CSD_3"]) {
        dayEntry.wakeTime = String(responses["CSD_3"]);
      }

      // CSD_2: Time to fall asleep (minutes)
      if (responses["CSD_2"]) {
        dayEntry.timeToFallAsleep = Number(responses["CSD_2"]);
        totalLatency += dayEntry.timeToFallAsleep;
      }

      // CSD_4: Number of awakenings
      if (responses["CSD_4"]) {
        dayEntry.awakenings = Number(responses["CSD_4"]);
        totalAwakenings += dayEntry.awakenings;
      }

      // CSD_5: Sleep quality (1-5)
      if (responses["CSD_5"]) {
        dayEntry.sleepQuality = Number(responses["CSD_5"]);
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
