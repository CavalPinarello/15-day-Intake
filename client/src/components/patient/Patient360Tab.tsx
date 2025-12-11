"use client";

import { useQuery, useAction } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState, useMemo } from "react";
import { BentoCard, BentoGrid } from "./BentoCard";
import { SubjectiveVsObjectiveCard } from "./SubjectiveVsObjectiveCard";
import { PillarSummaryCard, PillarKey, PILLARS } from "./PillarSummaryCard";
import { AIInsightsCard, generateSampleInsights } from "./AIInsightsCard";
import { SleepTrendChart } from "@/components/charts/SleepTrendChart";
import { ScoreGauge, SCORE_CONFIG } from "@/components/charts/ScoreProgressionChart";
import { SleepBreakdown } from "@/components/charts/SleepArchitectureChart";
import {
  ComplianceChart,
  StreakIndicator,
  ComplianceSummary,
} from "@/components/charts/ComplianceChart";
import {
  Calendar,
  Moon,
  Activity,
  TrendingUp,
  Heart,
  Watch,
  Brain,
  AlertTriangle,
  CheckCircle,
} from "lucide-react";

interface Patient360TabProps {
  userId: Id<"users">;
  patient: {
    name?: string;
    user: {
      current_day: number;
      started_at: number;
      apple_health_connected?: boolean;
    };
    demographics: {
      dateOfBirth?: string;
      sex?: string;
      height?: string;
      weight?: string;
    };
    totalResponses: number;
    completedDays: number;
  };
}

export function Patient360Tab({ userId, patient }: Patient360TabProps) {
  const [isAnalyzing, setIsAnalyzing] = useState(false);

  // Fetch HealthKit data
  const healthSummary = useQuery(api.healthkit.getPatientHealthSummary, { userId });
  const sleepArchitecture = useQuery(api.healthkit.getSleepArchitecture, { userId, limit: 15 });
  const perceptionGaps = useQuery(api.healthkit.getPerceptionGaps, { userId, limit: 15 });

  // Fetch questionnaire scores
  const scores = useQuery(api.physician.getQuestionnaireScores, { userId });

  // Fetch responses for pillar analysis
  const responsesByDay = useQuery(api.physician.getPatientResponsesByDay, { userId });

  // AI Analysis action
  const analyzePatient = useAction(api.llm.analyzePatientResponses);

  const [analysis, setAnalysis] = useState<{
    summary: string;
    riskFactors: string[];
    recommendations: string[];
  } | null>(null);

  const handleAnalyze = async () => {
    setIsAnalyzing(true);
    try {
      const result = await analyzePatient({ userId });
      setAnalysis(result);
    } catch (error) {
      console.error("Analysis failed:", error);
    } finally {
      setIsAnalyzing(false);
    }
  };

  // Transform scores to expected format
  const patientScores = useMemo(() => {
    if (!scores) return {};
    const scoreMap: Record<string, number> = {};
    scores.forEach((s) => {
      const key = s.questionnaire_name.toUpperCase().replace(/-/g, "");
      if (key === "ISI" || key === "PHQ9" || key === "GAD7" || key === "ESS" || key === "PSQI") {
        scoreMap[key] = s.score;
      }
    });
    return scoreMap;
  }, [scores]);

  // Generate insights from scores
  const insights = useMemo(() => {
    return generateSampleInsights({
      isiScore: patientScores.ISI,
      phq9Score: patientScores.PHQ9,
      gad7Score: patientScores.GAD7,
      avgSleepHours: healthSummary?.summary?.avgSleepHours ?? undefined,
      sleepEfficiency: healthSummary?.summary?.avgEfficiency ?? undefined,
    });
  }, [patientScores, healthSummary]);

  // Build sleep trend data from HealthKit
  const sleepTrendData = useMemo(() => {
    if (!healthSummary?.recentSleep) return [];
    return healthSummary.recentSleep.map((s, i) => ({
      day: i + 1,
      subjectiveQuality: healthSummary.recentGaps?.find(g => g.date === s.date)?.subjectiveQuality ?? null,
      objectiveEfficiency: s.efficiency ?? null,
      bedtimeConsistency: null,
      wakeTimeConsistency: null,
    })).reverse();
  }, [healthSummary]);

  // Build compliance data (mock for now - would come from user_progress)
  const complianceData = useMemo(() => {
    const days = [];
    for (let i = 1; i <= patient.user.current_day; i++) {
      days.push({
        date: new Date(patient.user.started_at + (i - 1) * 86400000).toISOString().split("T")[0],
        day: i,
        tasksCompleted: i <= patient.completedDays ? 2 : 0,
        tasksTotal: 2,
        sleepLogCompleted: i <= patient.completedDays,
        assessmentCompleted: i <= patient.completedDays,
      });
    }
    return days;
  }, [patient]);

  // Calculate streak
  const currentStreak = useMemo(() => {
    let streak = 0;
    for (let i = complianceData.length - 1; i >= 0; i--) {
      if (complianceData[i].sleepLogCompleted) streak++;
      else break;
    }
    return streak;
  }, [complianceData]);

  // Build pillar statuses (simplified - would need real pillar calculation)
  const pillarStatuses = useMemo(() => {
    const pillars: PillarKey[] = [
      "social", "metabolic", "sleepQuality", "sleepQuantity",
      "sleepRegularity", "sleepTiming", "mentalHealth",
      "cognitive", "physical", "nutritional", "sleepLog"
    ];

    return pillars.map((pillar) => {
      let score: number | null = null;
      const alerts: string[] = [];

      // Map scores to pillars
      if (pillar === "sleepQuality" && patientScores.PSQI) {
        score = Math.max(0, 100 - (patientScores.PSQI / 21) * 100);
        if (patientScores.PSQI > 10) alerts.push("Poor sleep quality");
      }
      if (pillar === "mentalHealth") {
        if (patientScores.PHQ9) {
          const phq9Norm = Math.max(0, 100 - (patientScores.PHQ9 / 27) * 100);
          if (patientScores.GAD7) {
            const gad7Norm = Math.max(0, 100 - (patientScores.GAD7 / 21) * 100);
            score = Math.round((phq9Norm + gad7Norm) / 2);
          } else {
            score = Math.round(phq9Norm);
          }
          if (patientScores.PHQ9 >= 15) alerts.push("Moderately severe depression");
          if (patientScores.GAD7 && patientScores.GAD7 >= 10) alerts.push("Moderate anxiety");
        }
      }
      if (pillar === "sleepLog") {
        score = patient.completedDays > 0 ? Math.round((patient.completedDays / patient.user.current_day) * 100) : 0;
      }
      if (pillar === "sleepQuantity" && healthSummary?.summary?.avgSleepHours) {
        const hrs = healthSummary.summary.avgSleepHours;
        score = hrs >= 7 ? 90 : hrs >= 6 ? 70 : hrs >= 5 ? 50 : 30;
        if (hrs < 6) alerts.push("Insufficient sleep duration");
      }

      return {
        pillar,
        score,
        questionsAnswered: score !== null ? 5 : 0,
        questionsTotal: 10,
        trend: null,
        alerts,
      };
    });
  }, [patientScores, patient, healthSummary]);

  // Build subjective vs objective comparison
  const sleepComparison = useMemo(() => {
    const latestGap = healthSummary?.recentGaps?.[0];
    const latestSleep = healthSummary?.recentSleep?.[0];

    return {
      date: latestGap?.date || new Date().toISOString().split("T")[0],
      subjective: {
        quality: latestGap?.subjectiveQuality || 7,
        totalSleep: 420, // Default 7 hours
        bedtime: "22:30",
        wakeTime: "06:30",
        awakenings: 2,
      },
      objective: latestSleep ? {
        efficiency: latestSleep.efficiency || 85,
        totalSleep: latestSleep.totalSleepMins || 420,
        bedtime: "22:45",
        wakeTime: "06:15",
        awakenings: latestSleep.awakenings || 3,
        deepSleep: latestSleep.deepMins || 60,
        remSleep: latestSleep.remMins || 90,
        lightSleep: latestSleep.lightMins || 240,
      } : null,
    };
  }, [healthSummary]);

  const hasHealthKitData = healthSummary?.hasHealthKitData || false;
  const complianceRate = patient.completedDays > 0
    ? Math.round((patient.completedDays / patient.user.current_day) * 100)
    : 0;

  return (
    <div className="space-y-6">
      {/* Top Stats Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard
          icon={<Calendar className="w-5 h-5" />}
          label="Journey Progress"
          value={`Day ${patient.user.current_day}`}
          subValue="of 15"
          color="blue"
        />
        <StatCard
          icon={<Moon className="w-5 h-5" />}
          label="Avg Sleep Quality"
          value={healthSummary?.summary?.avgEfficiency ? `${healthSummary.summary.avgEfficiency}%` : "—"}
          subValue="efficiency"
          color="purple"
        />
        <StatCard
          icon={<Activity className="w-5 h-5" />}
          label="Sleep Duration"
          value={healthSummary?.summary?.avgSleepHours ? `${healthSummary.summary.avgSleepHours.toFixed(1)}h` : "—"}
          subValue="average"
          color="green"
        />
        <StatCard
          icon={<TrendingUp className="w-5 h-5" />}
          label="Compliance"
          value={`${complianceRate}%`}
          subValue={`${patient.completedDays} days`}
          color="amber"
        />
      </div>

      {/* Main Bento Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 auto-rows-[minmax(140px,auto)]">
        {/* Sleep Trend Chart - Wide */}
        <div className="lg:col-span-2 bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <div className="w-8 h-8 rounded-lg bg-gray-700/50 flex items-center justify-center text-gray-400">
              <Moon className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-medium text-white">Sleep Quality Trend</h3>
              <p className="text-xs text-gray-500">15-day overview</p>
            </div>
          </div>
          {sleepTrendData.length > 0 ? (
            <SleepTrendChart data={sleepTrendData} showObjective={hasHealthKitData} height={180} />
          ) : (
            <div className="h-[180px] flex items-center justify-center text-gray-500">
              <p className="text-sm">No sleep data available yet</p>
            </div>
          )}
        </div>

        {/* AI Insights */}
        <AIInsightsCard
          insights={insights}
          onRunDeepAnalysis={handleAnalyze}
          isAnalyzing={isAnalyzing}
          lastAnalysisTime={analysis ? "Just now" : undefined}
        />

        {/* Subjective vs Objective */}
        <SubjectiveVsObjectiveCard data={sleepComparison} />

        {/* Pillar Summary */}
        <PillarSummaryCard pillars={pillarStatuses} />

        {/* Score Gauges */}
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <div className="w-8 h-8 rounded-lg bg-gray-700/50 flex items-center justify-center text-gray-400">
              <Activity className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-medium text-white">Clinical Scores</h3>
              <p className="text-xs text-gray-500">Key assessments</p>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2">
            {patientScores.ISI !== undefined && (
              <ScoreGauge score={patientScores.ISI} type="ISI" showTrend={null} />
            )}
            {patientScores.PHQ9 !== undefined && (
              <ScoreGauge score={patientScores.PHQ9} type="PHQ9" showTrend={null} />
            )}
            {patientScores.GAD7 !== undefined && (
              <ScoreGauge score={patientScores.GAD7} type="GAD7" showTrend={null} />
            )}
            {patientScores.ESS !== undefined && (
              <ScoreGauge score={patientScores.ESS} type="ESS" showTrend={null} />
            )}
            {Object.keys(patientScores).length === 0 && (
              <div className="col-span-2 text-center py-4 text-gray-500">
                <p className="text-sm">No scores calculated yet</p>
              </div>
            )}
          </div>
        </div>

        {/* Streak */}
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gray-700/50 flex items-center justify-center text-gray-400">
                <TrendingUp className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-sm font-medium text-white">Streak</h3>
                <p className="text-xs text-gray-500">Daily completion</p>
              </div>
            </div>
            {currentStreak >= 3 && (
              <span className="px-2 py-0.5 text-xs font-medium rounded-full bg-green-500/20 text-green-400 border border-green-500/30">
                {currentStreak} days
              </span>
            )}
          </div>
          <StreakIndicator
            currentStreak={currentStreak}
            longestStreak={currentStreak}
            last7Days={complianceData.slice(-7).map(c => c.sleepLogCompleted)}
          />
        </div>

        {/* Sleep Architecture (if available) */}
        {sleepArchitecture && sleepArchitecture.length > 0 && (
          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-8 h-8 rounded-lg bg-gray-700/50 flex items-center justify-center text-gray-400">
                <Moon className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-sm font-medium text-white">Last Night</h3>
                <p className="text-xs text-gray-500">Sleep stages</p>
              </div>
            </div>
            <SleepBreakdown data={sleepArchitecture[sleepArchitecture.length - 1]} />
          </div>
        )}

        {/* Wearable Status */}
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <div className="w-8 h-8 rounded-lg bg-gray-700/50 flex items-center justify-center text-gray-400">
              <Watch className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-medium text-white">Wearables</h3>
              <p className="text-xs text-gray-500">Connected devices</p>
            </div>
            <span className={`ml-auto px-2 py-0.5 text-xs font-medium rounded-full border ${
              hasHealthKitData
                ? "bg-green-500/20 text-green-400 border-green-500/30"
                : "bg-gray-500/20 text-gray-400 border-gray-500/30"
            }`}>
              {hasHealthKitData ? "Connected" : "Not connected"}
            </span>
          </div>
          <div className="flex flex-col items-center justify-center h-24 text-center">
            {hasHealthKitData ? (
              <>
                <div className="w-12 h-12 rounded-full bg-green-500/20 flex items-center justify-center mb-2">
                  <Heart className="w-6 h-6 text-green-400" />
                </div>
                <p className="text-sm text-white font-medium">Apple Watch</p>
                <p className="text-xs text-gray-400">Syncing sleep data</p>
              </>
            ) : (
              <>
                <div className="w-12 h-12 rounded-full bg-gray-700/50 flex items-center justify-center mb-2">
                  <Watch className="w-6 h-6 text-gray-500" />
                </div>
                <p className="text-sm text-gray-400">No device connected</p>
                <p className="text-xs text-gray-500">Subjective data only</p>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Compliance Chart - Full Width */}
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-sm font-medium text-white">Daily Compliance</h3>
            <p className="text-xs text-gray-500">Task completion over time</p>
          </div>
          <ComplianceSummary
            overallPercentage={complianceRate}
            sleepLogRate={complianceRate}
            assessmentRate={complianceRate}
            interventionRate={0}
          />
        </div>
        <ComplianceChart data={complianceData} height={150} />
      </div>

      {/* AI Analysis Results (if available) */}
      {analysis && (
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Brain className="w-5 h-5 text-purple-400" />
            <h3 className="text-lg font-semibold text-white">AI Analysis Results</h3>
          </div>
          <div className="space-y-4">
            <div>
              <h4 className="text-sm font-medium text-gray-400 mb-2">Summary</h4>
              <p className="text-gray-300">{analysis.summary}</p>
            </div>
            <div>
              <h4 className="text-sm font-medium text-gray-400 mb-2">Risk Factors</h4>
              <ul className="space-y-1">
                {analysis.riskFactors.map((factor, i) => (
                  <li key={i} className="flex items-start gap-2 text-gray-300">
                    <AlertTriangle className="w-4 h-4 text-amber-500 mt-0.5 flex-shrink-0" />
                    {factor}
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h4 className="text-sm font-medium text-gray-400 mb-2">Recommendations</h4>
              <ul className="space-y-1">
                {analysis.recommendations.map((rec, i) => (
                  <li key={i} className="flex items-start gap-2 text-gray-300">
                    <CheckCircle className="w-4 h-4 text-green-500 mt-0.5 flex-shrink-0" />
                    {rec}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      )}
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
    blue: "from-blue-500/20 to-blue-600/10 border-blue-500/30 text-blue-400",
    purple: "from-purple-500/20 to-purple-600/10 border-purple-500/30 text-purple-400",
    green: "from-green-500/20 to-green-600/10 border-green-500/30 text-green-400",
    amber: "from-amber-500/20 to-amber-600/10 border-amber-500/30 text-amber-400",
  };

  return (
    <div className={`p-4 rounded-xl border bg-gradient-to-br ${colorClasses[color]}`}>
      <div className="mb-2">{icon}</div>
      <p className="text-xs text-gray-400">{label}</p>
      <p className="text-xl font-bold text-white">
        {value}
        {subValue && <span className="text-sm font-normal text-gray-400 ml-1">{subValue}</span>}
      </p>
    </div>
  );
}
