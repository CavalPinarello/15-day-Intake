"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useState } from "react";
import { BentoCard, BentoGrid } from "./BentoCard";
import { SubjectiveVsObjectiveCard } from "./SubjectiveVsObjectiveCard";
import { PillarSummaryCard, PillarKey, PILLARS } from "./PillarSummaryCard";
import { AIInsightsCard, generateSampleInsights } from "./AIInsightsCard";
import {
  SleepTrendChart,
  SleepTrendMini,
} from "@/components/charts/SleepTrendChart";
import {
  ScoreProgressionChart,
  ScoreGauge,
  SCORE_CONFIG,
} from "@/components/charts/ScoreProgressionChart";
import { SleepBreakdown } from "@/components/charts/SleepArchitectureChart";
import {
  ComplianceChart,
  StreakIndicator,
  ComplianceSummary,
} from "@/components/charts/ComplianceChart";
import {
  Calendar,
  Clock,
  Moon,
  Activity,
  Heart,
  TrendingUp,
  Watch,
} from "lucide-react";

// Type definitions for patient data
interface PatientData {
  id: string;
  name: string;
  currentDay: number;
  totalDays: number;
  startDate: string;
  demographics: {
    age?: number;
    sex?: string;
    height?: string;
    weight?: string;
    bmi?: number;
    chronotype?: "morning_lark" | "neutral" | "night_owl";
  };
  scores: {
    ISI?: number;
    PHQ9?: number;
    GAD7?: number;
    ESS?: number;
    PSQI?: number;
    MEQ?: number;
  };
  sleepData: {
    day: number;
    subjectiveQuality: number | null;
    objectiveEfficiency: number | null;
    perceivedEfficiency: number | null;
    perceptionDelta: number | null;
    bedtimeConsistency: number | null;
    wakeTimeConsistency: number | null;
  }[];
  sleepComparison: {
    date: string;
    subjective: {
      quality: number;
      totalSleep: number;
      bedtime: string;
      wakeTime: string;
      awakenings: number;
    };
    objective: {
      efficiency: number;
      totalSleep: number;
      bedtime: string;
      wakeTime: string;
      awakenings: number;
      deepSleep: number;
      remSleep: number;
      lightSleep: number;
    } | null;
  };
  sleepArchitecture?: {
    date: string;
    day: number;
    deep: number;
    light: number;
    rem: number;
    awake: number;
    totalSleep: number;
  };
  pillarStatuses: {
    pillar: PillarKey;
    score: number | null;
    questionsAnswered: number;
    questionsTotal: number;
    trend: "improving" | "declining" | "stable" | null;
    alerts: string[];
  }[];
  compliance: {
    date: string;
    day: number;
    tasksCompleted: number;
    tasksTotal: number;
    sleepLogCompleted: boolean;
    assessmentCompleted: boolean;
  }[];
  healthKitConnected: boolean;
  hasWearable: boolean;
  wearableType?: string;
}

interface Patient360ViewProps {
  patient: PatientData;
  onRunAnalysis?: () => Promise<void>;
  onPillarClick?: (pillar: PillarKey) => void;
  onViewSleepTrends?: () => void;
  onViewScoreHistory?: () => void;
  isAnalyzing?: boolean;
}

export function Patient360View({
  patient,
  onRunAnalysis,
  onPillarClick,
  onViewSleepTrends,
  onViewScoreHistory,
  isAnalyzing = false,
}: Patient360ViewProps) {
  const [selectedScoreType, setSelectedScoreType] = useState<keyof typeof SCORE_CONFIG>("ISI");

  // Generate insights from patient data
  const insights = generateSampleInsights({
    isiScore: patient.scores.ISI,
    phq9Score: patient.scores.PHQ9,
    gad7Score: patient.scores.GAD7,
    avgSleepHours:
      patient.sleepData.length > 0
        ? patient.sleepComparison.subjective.totalSleep / 60
        : undefined,
    sleepEfficiency: patient.sleepComparison.objective?.efficiency,
  });

  // Calculate averages
  const avgQuality =
    patient.sleepData.filter((d) => d.subjectiveQuality !== null).length > 0
      ? Math.round(
          patient.sleepData
            .filter((d) => d.subjectiveQuality !== null)
            .reduce((acc, d) => acc + (d.subjectiveQuality || 0), 0) /
            patient.sleepData.filter((d) => d.subjectiveQuality !== null).length
        )
      : null;

  const avgEfficiency =
    patient.sleepData.filter((d) => d.objectiveEfficiency !== null).length > 0
      ? Math.round(
          patient.sleepData
            .filter((d) => d.objectiveEfficiency !== null)
            .reduce((acc, d) => acc + (d.objectiveEfficiency || 0), 0) /
            patient.sleepData.filter((d) => d.objectiveEfficiency !== null)
              .length
        )
      : null;

  // Compliance stats
  const completedDays = patient.compliance.filter(
    (c) => c.sleepLogCompleted && c.assessmentCompleted
  ).length;
  const complianceRate =
    patient.compliance.length > 0
      ? Math.round((completedDays / patient.compliance.length) * 100)
      : 0;

  const currentStreak = calculateStreak(patient.compliance);
  const longestStreak = calculateLongestStreak(patient.compliance);

  return (
    <div className="space-y-6">
      {/* Top Stats Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard
          icon={<Calendar className="w-5 h-5" />}
          label="Journey Progress"
          value={`Day ${patient.currentDay}`}
          subValue={`of ${patient.totalDays}`}
          color="blue"
        />
        <StatCard
          icon={<Moon className="w-5 h-5" />}
          label="Avg Sleep Quality"
          value={avgQuality !== null ? `${avgQuality}/10` : "—"}
          subValue="subjective"
          color="purple"
        />
        <StatCard
          icon={<Activity className="w-5 h-5" />}
          label="Sleep Efficiency"
          value={avgEfficiency !== null ? `${avgEfficiency}%` : "—"}
          subValue="from HealthKit"
          color="green"
        />
        <StatCard
          icon={<TrendingUp className="w-5 h-5" />}
          label="Compliance"
          value={`${complianceRate}%`}
          subValue={`${completedDays} days complete`}
          color="amber"
        />
      </div>

      {/* Main Bento Grid */}
      <BentoGrid columns={3}>
        {/* Sleep Trend Chart - Wide */}
        <BentoCard
          title="Sleep Quality Trend"
          subtitle="14-day overview"
          size="wide"
          icon={<Moon className="w-4 h-4" />}
          action={
            onViewSleepTrends
              ? { label: "View details", onClick: onViewSleepTrends }
              : undefined
          }
        >
          <SleepTrendChart
            data={patient.sleepData}
            showObjective={patient.healthKitConnected}
            height={180}
          />
        </BentoCard>

        {/* AI Insights - Medium */}
        <AIInsightsCard
          insights={insights}
          onRunDeepAnalysis={onRunAnalysis}
          isAnalyzing={isAnalyzing}
          lastAnalysisTime="2 hours ago"
        />

        {/* Subjective vs Objective - Wide */}
        <SubjectiveVsObjectiveCard
          data={patient.sleepComparison}
          onViewDetails={onViewSleepTrends}
        />

        {/* Pillar Summary - Large */}
        <PillarSummaryCard
          pillars={patient.pillarStatuses}
          onPillarClick={onPillarClick}
        />

        {/* Score Gauges - Medium */}
        <BentoCard
          title="Clinical Scores"
          subtitle="Key assessments"
          size="medium"
          icon={<Activity className="w-4 h-4" />}
          action={
            onViewScoreHistory
              ? { label: "View history", onClick: onViewScoreHistory }
              : undefined
          }
        >
          <div className="grid grid-cols-2 gap-2 h-full">
            {patient.scores.ISI !== undefined && (
              <ScoreGauge
                score={patient.scores.ISI}
                type="ISI"
                showTrend={null}
              />
            )}
            {patient.scores.PHQ9 !== undefined && (
              <ScoreGauge
                score={patient.scores.PHQ9}
                type="PHQ9"
                showTrend={null}
              />
            )}
            {patient.scores.GAD7 !== undefined && (
              <ScoreGauge
                score={patient.scores.GAD7}
                type="GAD7"
                showTrend={null}
              />
            )}
            {patient.scores.ESS !== undefined && (
              <ScoreGauge
                score={patient.scores.ESS}
                type="ESS"
                showTrend={null}
              />
            )}
          </div>
        </BentoCard>

        {/* Compliance - Small */}
        <BentoCard
          title="Streak"
          subtitle="Daily completion"
          size="small"
          icon={<Clock className="w-4 h-4" />}
          badge={
            currentStreak >= 3
              ? { text: `${currentStreak} days`, variant: "success" }
              : undefined
          }
        >
          <StreakIndicator
            currentStreak={currentStreak}
            longestStreak={longestStreak}
            last7Days={patient.compliance
              .slice(-7)
              .map((c) => c.sleepLogCompleted && c.assessmentCompleted)}
          />
        </BentoCard>

        {/* Sleep Architecture - Small */}
        {patient.sleepArchitecture && (
          <BentoCard
            title="Last Night"
            subtitle="Sleep stages"
            size="small"
            icon={<Moon className="w-4 h-4" />}
          >
            <SleepBreakdown data={patient.sleepArchitecture} />
          </BentoCard>
        )}

        {/* Wearable Status - Small */}
        <BentoCard
          title="Wearables"
          subtitle="Connected devices"
          size="small"
          icon={<Watch className="w-4 h-4" />}
          badge={
            patient.healthKitConnected
              ? { text: "Connected", variant: "success" }
              : { text: "Not connected", variant: "neutral" }
          }
        >
          <div className="flex flex-col items-center justify-center h-full text-center">
            {patient.healthKitConnected ? (
              <>
                <div className="w-12 h-12 rounded-full bg-green-500/20 flex items-center justify-center mb-2">
                  <Heart className="w-6 h-6 text-green-400" />
                </div>
                <p className="text-sm text-white font-medium">
                  {patient.wearableType || "Apple Watch"}
                </p>
                <p className="text-xs text-gray-400">Syncing sleep data</p>
              </>
            ) : (
              <>
                <div className="w-12 h-12 rounded-full bg-gray-700/50 flex items-center justify-center mb-2">
                  <Watch className="w-6 h-6 text-gray-500" />
                </div>
                <p className="text-sm text-gray-400">No device connected</p>
                <p className="text-xs text-gray-500">
                  Subjective data only
                </p>
              </>
            )}
          </div>
        </BentoCard>

        {/* Chronotype - Small */}
        {patient.demographics.chronotype && (
          <BentoCard
            title="Chronotype"
            subtitle="Sleep timing preference"
            size="small"
            icon={
              patient.demographics.chronotype === "morning_lark" ? (
                <span className="text-sm">🌅</span>
              ) : patient.demographics.chronotype === "night_owl" ? (
                <span className="text-sm">🦉</span>
              ) : (
                <span className="text-sm">⚖️</span>
              )
            }
          >
            <div className="flex flex-col items-center justify-center h-full text-center">
              <div className="text-4xl mb-2">
                {patient.demographics.chronotype === "morning_lark"
                  ? "🌅"
                  : patient.demographics.chronotype === "night_owl"
                  ? "🦉"
                  : "⚖️"}
              </div>
              <p className="text-sm text-white font-medium capitalize">
                {patient.demographics.chronotype.replace("_", " ")}
              </p>
              {patient.scores.MEQ && (
                <p className="text-xs text-gray-400">MEQ: {patient.scores.MEQ}</p>
              )}
            </div>
          </BentoCard>
        )}
      </BentoGrid>

      {/* Compliance Chart - Full Width */}
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-sm font-medium text-white">Daily Compliance</h3>
            <p className="text-xs text-gray-500">Task completion over time</p>
          </div>
          <ComplianceSummary
            overallPercentage={complianceRate}
            sleepLogRate={Math.round(
              (patient.compliance.filter((c) => c.sleepLogCompleted).length /
                Math.max(patient.compliance.length, 1)) *
                100
            )}
            assessmentRate={Math.round(
              (patient.compliance.filter((c) => c.assessmentCompleted).length /
                Math.max(patient.compliance.length, 1)) *
                100
            )}
            interventionRate={Math.round(
              (patient.compliance.reduce(
                (acc, c) => acc + c.tasksCompleted,
                0
              ) /
                Math.max(
                  patient.compliance.reduce((acc, c) => acc + c.tasksTotal, 0),
                  1
                )) *
                100
            )}
          />
        </div>
        <ComplianceChart data={patient.compliance} height={150} />
      </div>
    </div>
  );
}

// Helper component for stat cards
function StatCard({
  icon,
  label,
  value,
  subValue,
  color,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  subValue?: string;
  color: "blue" | "purple" | "green" | "amber";
}) {
  const colorClasses = {
    blue: "from-blue-500/20 to-blue-600/10 border-blue-500/30",
    purple: "from-purple-500/20 to-purple-600/10 border-purple-500/30",
    green: "from-green-500/20 to-green-600/10 border-green-500/30",
    amber: "from-amber-500/20 to-amber-600/10 border-amber-500/30",
  };

  const iconColorClasses = {
    blue: "text-blue-400",
    purple: "text-purple-400",
    green: "text-green-400",
    amber: "text-amber-400",
  };

  return (
    <div
      className={`
        p-4 rounded-xl border
        bg-gradient-to-br ${colorClasses[color]}
      `}
    >
      <div className={`mb-2 ${iconColorClasses[color]}`}>{icon}</div>
      <p className="text-xs text-gray-400">{label}</p>
      <p className="text-xl font-bold text-white">
        {value}
        {subValue && (
          <span className="text-sm font-normal text-gray-400 ml-1">
            {subValue}
          </span>
        )}
      </p>
    </div>
  );
}

// Helper functions
function calculateStreak(
  compliance: PatientData["compliance"]
): number {
  let streak = 0;
  for (let i = compliance.length - 1; i >= 0; i--) {
    if (compliance[i].sleepLogCompleted && compliance[i].assessmentCompleted) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

function calculateLongestStreak(
  compliance: PatientData["compliance"]
): number {
  let longest = 0;
  let current = 0;
  for (const day of compliance) {
    if (day.sleepLogCompleted && day.assessmentCompleted) {
      current++;
      longest = Math.max(longest, current);
    } else {
      current = 0;
    }
  }
  return longest;
}
