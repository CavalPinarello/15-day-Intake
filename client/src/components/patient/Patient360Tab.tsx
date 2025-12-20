"use client";

import { useQuery, useAction } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState, useMemo } from "react";
import { BentoCard, BentoGrid } from "./BentoCard";
import { SubjectiveVsObjectiveCard } from "./SubjectiveVsObjectiveCard";
import { PillarSummaryCard, PillarKey, PILLARS } from "./PillarSummaryCard";
import { PillarDetailModal } from "./PillarDetailModal";
import { AIInsightsCard, generateSampleInsights } from "./AIInsightsCard";
import { PatientEngagementCard } from "./PatientEngagementCard";
import { PatientJourneyStatus } from "./PatientJourneyStatus";
import { SleepTrendChart } from "@/components/charts/SleepTrendChart";
import { ScoreGauge, SCORE_CONFIG } from "@/components/charts/ScoreProgressionChart";
import { SleepBreakdown } from "@/components/charts/SleepArchitectureChart";
import {
  ComplianceChart,
  StreakIndicator,
  ComplianceSummary,
} from "@/components/charts/ComplianceChart";
import {
  MultiSourceSleepChart,
  SourceComparisonSummary,
  SourceBadges,
} from "@/components/charts/MultiSourceSleepChart";
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

  // Fetch sleep pattern insights from Convex
  const sleepPatternInsights = useQuery(api.sleepInsights.generateInsights, { userId });

  // Fetch multi-source sleep data for wearable comparison
  const multiSourceData = useQuery(api.healthkit.getMultiSourceSleepData, { userId, days: 15 });
  const sourceDetails = useQuery(api.healthkit.getSourceDetails, { userId });

  // Fetch questionnaire scores
  const scores = useQuery(api.physician.getQuestionnaireScores, { userId });

  // Fetch pillar completion stats
  const pillarStats = useQuery(api.physician.getPillarStats, { userId });

  // Fetch responses for pillar analysis
  const responsesByDay = useQuery(api.physician.getPatientResponsesByDay, { userId });

  // Fetch accurate compliance data for streak calculation
  const complianceDataQuery = useQuery(api.physician.getDailyComplianceData, { userId });

  // AI Analysis action
  const analyzePatient = useAction(api.llm.analyzePatientResponses);

  const [analysis, setAnalysis] = useState<{
    summary: string;
    riskFactors: string[];
    recommendations: string[];
  } | null>(null);
  const [analysisError, setAnalysisError] = useState<string | null>(null);

  // State for pillar detail modal
  const [selectedPillar, setSelectedPillar] = useState<PillarKey | null>(null);

  const handleAnalyze = async () => {
    setIsAnalyzing(true);
    setAnalysisError(null);
    try {
      const result = await analyzePatient({ userId });
      setAnalysis(result);
      // Check if the LLM returned an error message
      if (result.summary === "Error analyzing patient data") {
        setAnalysisError("Analysis completed but no insights generated. Check if API keys are configured.");
      }
    } catch (error) {
      console.error("Analysis failed:", error);
      setAnalysisError(error instanceof Error ? error.message : "Analysis failed. Please try again.");
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

  // Generate insights from scores, sleep patterns, and LLM analysis
  const insights = useMemo(() => {
    const baseInsights = generateSampleInsights({
      isiScore: patientScores.ISI,
      phq9Score: patientScores.PHQ9,
      gad7Score: patientScores.GAD7,
      avgSleepHours: healthSummary?.summary?.avgSleepHours ?? undefined,
      sleepEfficiency: healthSummary?.summary?.avgEfficiency ?? undefined,
    });

    const now = new Date().toISOString();

    // Add sleep pattern insights from Convex backend
    if (sleepPatternInsights && sleepPatternInsights.length > 0) {
      sleepPatternInsights.forEach((insight) => {
        // Map insight type to severity
        const severityMap: Record<string, "critical" | "warning" | "info" | "positive"> = {
          "optimization": "info",
          "pattern": "info",
          "cognitive": "warning",
          "positive": "positive",
          "warning": "warning",
        };
        // Map insight type to category
        const categoryMap: Record<string, "sleep_quality" | "behavioral" | "mental_health"> = {
          "optimization": "behavioral",
          "pattern": "sleep_quality",
          "cognitive": "mental_health",
          "positive": "sleep_quality",
          "warning": "sleep_quality",
        };

        baseInsights.push({
          id: insight.id,
          title: insight.title,
          description: insight.text,
          severity: severityMap[insight.type] || "info",
          category: categoryMap[insight.type] || "sleep_quality",
          confidence: Math.round(insight.confidence * 100),
          timestamp: now,
          suggestedActions: insight.actionable ? ["Review and discuss with patient"] : undefined,
        });
      });
    }

    // Add LLM analysis results if available
    if (analysis) {
      // Add summary as an info insight
      if (analysis.summary && analysis.summary !== "Error analyzing patient data") {
        baseInsights.push({
          id: "llm-summary",
          title: "AI Analysis Summary",
          description: analysis.summary,
          severity: "info" as const,
          category: "sleep_quality" as const,
          confidence: 85,
          timestamp: now,
        });
      }

      // Add risk factors as warnings
      analysis.riskFactors.forEach((risk, idx) => {
        baseInsights.push({
          id: `llm-risk-${idx}`,
          title: risk.length > 50 ? risk.slice(0, 47) + "..." : risk,
          description: risk,
          severity: "warning" as const,
          category: "sleep_quality" as const,
          confidence: 80,
          timestamp: now,
        });
      });

      // Add recommendations as positive insights with actions
      if (analysis.recommendations.length > 0) {
        baseInsights.push({
          id: "llm-recommendations",
          title: "AI Recommendations",
          description: "Evidence-based interventions suggested by AI analysis",
          severity: "positive" as const,
          category: "behavioral" as const,
          confidence: 75,
          suggestedActions: analysis.recommendations,
          timestamp: now,
        });
      }
    }

    return baseInsights;
  }, [patientScores, healthSummary, analysis, sleepPatternInsights]);

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

  // Build compliance data - prefer accurate query data, fallback to patient.completedDays
  const complianceData = useMemo(() => {
    // Use accurate compliance query if available
    if (complianceDataQuery && complianceDataQuery.length > 0) {
      return complianceDataQuery.map((d) => ({
        date: d.date,
        day: d.dayNumber,
        tasksCompleted: (d.sleepLogCompleted ? 1 : 0) + (d.assessmentCompleted ? 1 : 0),
        tasksTotal: 2,
        sleepLogCompleted: d.sleepLogCompleted,
        assessmentCompleted: d.assessmentCompleted,
      }));
    }

    // Fallback to existing logic
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
  }, [patient, complianceDataQuery]);

  // Calculate streak
  const currentStreak = useMemo(() => {
    let streak = 0;
    for (let i = complianceData.length - 1; i >= 0; i--) {
      if (complianceData[i].sleepLogCompleted) streak++;
      else break;
    }
    return streak;
  }, [complianceData]);

  // Build pillar statuses using actual response data
  const pillarStatuses = useMemo(() => {
    const pillars: PillarKey[] = [
      "social", "metabolic", "sleepQuality", "sleepQuantity",
      "sleepRegularity", "sleepTiming", "mentalHealth",
      "cognitive", "physical", "nutritional", "sleepLog"
    ];

    // Map pillar keys to display names for lookup
    const pillarNameMap: Record<PillarKey, string> = {
      social: "Social",
      metabolic: "Metabolic",
      sleepQuality: "Sleep Quality",
      sleepQuantity: "Sleep Quantity",
      sleepRegularity: "Sleep Regularity",
      sleepTiming: "Sleep Timing",
      mentalHealth: "Mental Health",
      cognitive: "Cognitive",
      physical: "Physical",
      nutritional: "Nutritional",
      sleepLog: "Sleep Log",
    };

    return pillars.map((pillar) => {
      let score: number | null = null;
      const alerts: string[] = [];
      let questionsAnswered = 0;
      let questionsTotal = 10;

      // Get stats from pillarStats query if available
      const stats = pillarStats?.find(s => s.pillar === pillarNameMap[pillar]);
      if (stats) {
        questionsAnswered = stats.questionsAnswered;
        questionsTotal = stats.questionsTotal;
        // Use completion percentage as score if questions have been answered
        if (stats.questionsAnswered > 0) {
          score = stats.completionPercent;
        }
      }

      // Override with specific clinical scores if available
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
        // Sleep log completion based on days completed
        score = patient.completedDays > 0 ? Math.round((patient.completedDays / patient.user.current_day) * 100) : 0;
        questionsAnswered = patient.completedDays * 5; // 5 questions per day
        questionsTotal = patient.user.current_day * 5;
      }
      if (pillar === "sleepQuantity" && healthSummary?.summary?.avgSleepHours) {
        const hrs = healthSummary.summary.avgSleepHours;
        score = hrs >= 7 ? 90 : hrs >= 6 ? 70 : hrs >= 5 ? 50 : 30;
        if (hrs < 6) alerts.push("Insufficient sleep duration");
      }

      return {
        pillar,
        score,
        questionsAnswered,
        questionsTotal,
        trend: null,
        alerts,
      };
    });
  }, [patientScores, patient, healthSummary, pillarStats]);

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
          error={analysisError}
        />

        {/* Subjective vs Objective */}
        <SubjectiveVsObjectiveCard data={sleepComparison} />

        {/* Pillar Summary */}
        <PillarSummaryCard
          pillars={pillarStatuses}
          onPillarClick={(pillar) => setSelectedPillar(pillar)}
        />

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

        {/* Patient Engagement - Shows streak, XP, badges, and engagement insights */}
        <PatientEngagementCard userId={userId} />

        {/* Journey Status - Shows current phase and analysis progress */}
        <PatientJourneyStatus userId={userId} />

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

        {/* Wearable Status with Data Quality */}
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <div className="w-8 h-8 rounded-lg bg-gray-700/50 flex items-center justify-center text-gray-400">
              <Watch className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-medium text-white">Data Source</h3>
              <p className="text-xs text-gray-500">Sleep data origin</p>
            </div>
            {(() => {
              const source = healthSummary?.recentSleep?.[0]?.primarySource ||
                            (hasHealthKitData ? "Apple Watch" : null);
              const quality = getDataQuality(source, healthSummary);
              return (
                <span className={`ml-auto px-2 py-0.5 text-xs font-medium rounded-full border ${quality.classes}`}>
                  {quality.label}
                </span>
              );
            })()}
          </div>
          <div className="flex flex-col items-center justify-center h-24 text-center">
            {(() => {
              const source = healthSummary?.recentSleep?.[0]?.primarySource ||
                            (hasHealthKitData ? "Apple Watch" : null);
              if (source) {
                const { icon: SourceIcon, color, label } = getSourceInfo(source);
                return (
                  <>
                    <div className={`w-12 h-12 rounded-full ${color} flex items-center justify-center mb-2`}>
                      <SourceIcon className="w-6 h-6" />
                    </div>
                    <p className="text-sm text-white font-medium">{label}</p>
                    <p className="text-xs text-gray-400">
                      {healthSummary?.dataPoints || 0} days of data
                    </p>
                  </>
                );
              }
              return (
                <>
                  <div className="w-12 h-12 rounded-full bg-gray-700/50 flex items-center justify-center mb-2">
                    <Watch className="w-6 h-6 text-gray-500" />
                  </div>
                  <p className="text-sm text-gray-400">No device connected</p>
                  <p className="text-xs text-gray-500">Questionnaire data only</p>
                </>
              );
            })()}
          </div>
        </div>
      </div>

      {/* Multi-Source Sleep Comparison - Only show if patient has multiple wearables */}
      {multiSourceData?.hasMultipleSources && (
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-purple-500/20 flex items-center justify-center">
                <Activity className="w-4 h-4 text-purple-400" />
              </div>
              <div>
                <h3 className="text-sm font-medium text-white">Multi-Device Sleep Comparison</h3>
                <p className="text-xs text-gray-500">
                  Comparing data from {multiSourceData.sources.length} sources over {multiSourceData.totalDays} days
                </p>
              </div>
            </div>
            <SourceBadges sources={multiSourceData.sources} />
          </div>

          <MultiSourceSleepChart
            hasMultipleSources={multiSourceData.hasMultipleSources}
            sources={multiSourceData.sources}
            sourceStats={multiSourceData.sourceStats}
            comparisonData={multiSourceData.comparisonData}
            totalDays={multiSourceData.totalDays}
            metric="efficiency"
            height={220}
          />

          <div className="mt-4">
            <SourceComparisonSummary sourceStats={multiSourceData.sourceStats} />
          </div>

          {/* Source details table */}
          {sourceDetails && sourceDetails.length > 1 && (
            <div className="mt-4 pt-4 border-t border-gray-700/50">
              <h4 className="text-xs font-medium text-gray-400 mb-2">Device Capabilities</h4>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
                {sourceDetails.map((detail) => (
                  <div
                    key={detail.source}
                    className="p-2 rounded-lg bg-gray-700/30 border border-gray-600/30"
                  >
                    <p className="text-xs font-medium text-white truncate">{detail.source}</p>
                    <div className="flex flex-wrap gap-1 mt-1">
                      {detail.hasSleepStages && (
                        <span className="px-1.5 py-0.5 text-[9px] rounded bg-green-500/20 text-green-400">
                          Stages
                        </span>
                      )}
                      {detail.hasHeartRate && (
                        <span className="px-1.5 py-0.5 text-[9px] rounded bg-blue-500/20 text-blue-400">
                          HR
                        </span>
                      )}
                      {detail.hasHrv && (
                        <span className="px-1.5 py-0.5 text-[9px] rounded bg-purple-500/20 text-purple-400">
                          HRV
                        </span>
                      )}
                    </div>
                    <p className="text-[10px] text-gray-400 mt-1">
                      Quality: {detail.qualityScore}/5
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

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

      {/* Pillar Detail Modal */}
      {selectedPillar && (
        <PillarDetailModal
          isOpen={!!selectedPillar}
          onClose={() => setSelectedPillar(null)}
          userId={userId}
          pillar={selectedPillar}
          pillarStatus={pillarStatuses.find((p) => p.pillar === selectedPillar)!}
        />
      )}
    </div>
  );
}

// Helper function to get data source info
function getSourceInfo(source: string | null): {
  icon: typeof Watch;
  color: string;
  label: string;
} {
  if (!source) {
    return { icon: Watch, color: "bg-gray-700/50 text-gray-500", label: "No device" };
  }

  const sourceUpper = source.toUpperCase();

  if (sourceUpper.includes("APPLE") || sourceUpper.includes("WATCH")) {
    return { icon: Watch, color: "bg-green-500/20 text-green-400", label: "Apple Watch" };
  }
  if (sourceUpper.includes("OURA")) {
    return { icon: Activity, color: "bg-purple-500/20 text-purple-400", label: "Oura Ring" };
  }
  if (sourceUpper.includes("FITBIT")) {
    return { icon: Watch, color: "bg-teal-500/20 text-teal-400", label: "Fitbit" };
  }
  if (sourceUpper.includes("GARMIN")) {
    return { icon: Watch, color: "bg-blue-500/20 text-blue-400", label: "Garmin" };
  }
  if (sourceUpper.includes("WHOOP")) {
    return { icon: Activity, color: "bg-amber-500/20 text-amber-400", label: "WHOOP" };
  }
  if (sourceUpper.includes("QUESTIONNAIRE")) {
    return { icon: Calendar, color: "bg-orange-500/20 text-orange-400", label: "Sleep Log" };
  }

  return { icon: Heart, color: "bg-green-500/20 text-green-400", label: source };
}

// Helper function to assess data quality
function getDataQuality(
  source: string | null,
  healthSummary: { summary?: { avgDeepSleepMins?: number | null; avgRestingHr?: number | null; avgHrv?: number | null } } | null | undefined
): { label: string; classes: string } {
  if (!source) {
    return { label: "No data", classes: "bg-gray-500/20 text-gray-400 border-gray-500/30" };
  }

  // Calculate quality score
  let qualityScore = 0;
  const sourceUpper = source.toUpperCase();

  // Has sleep stages (deep/REM)?
  if (healthSummary?.summary?.avgDeepSleepMins && healthSummary.summary.avgDeepSleepMins > 0) {
    qualityScore += 2;
  }
  // Has heart rate?
  if (healthSummary?.summary?.avgRestingHr && healthSummary.summary.avgRestingHr > 0) {
    qualityScore += 1;
  }
  // Has HRV?
  if (healthSummary?.summary?.avgHrv && healthSummary.summary.avgHrv > 0) {
    qualityScore += 1;
  }
  // Is it a dedicated sleep tracker?
  if (sourceUpper.includes("WATCH") || sourceUpper.includes("OURA") || sourceUpper.includes("WHOOP")) {
    qualityScore += 1;
  }

  if (qualityScore >= 4) {
    return { label: "Excellent", classes: "bg-green-500/20 text-green-400 border-green-500/30" };
  } else if (qualityScore >= 2) {
    return { label: "Good", classes: "bg-amber-500/20 text-amber-400 border-amber-500/30" };
  } else if (qualityScore >= 1) {
    return { label: "Fair", classes: "bg-orange-500/20 text-orange-400 border-orange-500/30" };
  } else {
    return { label: "Limited", classes: "bg-red-500/20 text-red-400 border-red-500/30" };
  }
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
