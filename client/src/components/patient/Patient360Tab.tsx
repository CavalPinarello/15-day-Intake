"use client";
/* eslint-disable @typescript-eslint/no-unused-vars, react/no-unescaped-entities */

import { useQuery, useAction } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState, useMemo } from "react";
import { SubjectiveVsObjectiveCard, type SubjectiveSleepData } from "./SubjectiveVsObjectiveCard";
import { PillarSummaryCard, PillarKey, type PillarStatus } from "./PillarSummaryCard";
import { getPillarSeverities, type PillarKey as SeverityPillarKey } from "@/utils/pillarSeverity";
import { PillarDetailModal } from "./PillarDetailModal";
import { AIInsightsCard, generateSampleInsights } from "./AIInsightsCard";
import { PatientEngagementCard } from "./PatientEngagementCard";
import { PatientAnalysisWorkflow } from "./PatientAnalysisWorkflow";
import { CheckInHistoryCard } from "./CheckInHistoryCard";
import { WellnessMetricsChart } from "./WellnessMetricsChart";
import { CircadianMetricsCard } from "./CircadianMetricsCard";
import { SleepHealthFactorsCard } from "./SleepHealthFactorsCard";
import { AdaptiveDifficultyPanel } from "./AdaptiveDifficultyPanel";
import { ComplianceCorrelationChart } from "@/components/charts/ComplianceCorrelationChart";
import { ProtocolAssignment } from "@/components/physician/ProtocolAssignment";
import { SleepTrendChart } from "@/components/charts/SleepTrendChart";
import { ScoreGauge } from "@/components/charts/ScoreProgressionChart";
import { SleepBreakdown } from "@/components/charts/SleepArchitectureChart";
import {
  ComplianceChart,
  ComplianceSummary,
  ModularComplianceSummary,
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
  patientId?: string; // For navigation links in workflow component
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

export function Patient360Tab({ userId, patientId, patient }: Patient360TabProps) {
  const [isAnalyzing, setIsAnalyzing] = useState(false);

  // Fetch HealthKit data
  const healthSummary = useQuery(api.healthkit.getPatientHealthSummary, { userId });
  const sleepArchitecture = useQuery(api.healthkit.getSleepArchitecture, { userId, limit: 15 });
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
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
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const responsesByDay = useQuery(api.physician.getPatientResponsesByDay, { userId });

  // Fetch accurate compliance data for streak calculation
  const complianceDataQuery = useQuery(api.physician.getDailyComplianceData, { userId });

  // Fetch modular compliance data (sleep log, core assessment, expansion packs)
  const modularComplianceData = useQuery(api.physician.getModularComplianceData, { userId });

  // Fetch subjective sleep quality data (from sleep log)
  const subjectiveSleepData = useQuery(api.physician.getSubjectiveSleepQuality, { userId, days: 14 });

  // AI Analysis action
  const analyzePatient = useAction(api.llm.analyzePatientResponses);
  const previewPrompt = useAction(api.llm.previewAnalysisPrompt);

  // LLM Settings
  const llmSettings = useQuery(api.systemSettings.getLLMSettings);

  const [analysis, setAnalysis] = useState<{
    summary: string;
    riskFactors: string[];
    recommendations: string[];
  } | null>(null);
  const [analysisError, setAnalysisError] = useState<string | null>(null);
  const [isLoadingPreview, setIsLoadingPreview] = useState(false);
  const [promptPreview, setPromptPreview] = useState<{
    systemPrompt: string;
    userPrompt: string;
    estimatedTokens: number;
    estimatedCost: string;
    selectedModel: string;
    modelProvider: string;
  } | null>(null);

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

  const handlePreviewPrompt = async () => {
    setIsLoadingPreview(true);
    try {
      const result = await previewPrompt({ userId });
      setPromptPreview(result);
    } catch (error) {
      console.error("Preview failed:", error);
      setAnalysisError(error instanceof Error ? error.message : "Failed to load prompt preview.");
    } finally {
      setIsLoadingPreview(false);
    }
  };

  // Transform scores to expected format
  const patientScores = useMemo(() => {
    if (!scores) return {};
    const scoreMap: Record<string, number> = {};
    scores.forEach((s: NonNullable<typeof scores>[number]) => {
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
      sleepPatternInsights.forEach((insight: NonNullable<typeof sleepPatternInsights>[number]) => {
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

  // Build sleep trend data from HealthKit + subjective sleep data
  type SleepEntry = NonNullable<typeof healthSummary>["recentSleep"][number];
  type GapEntry = NonNullable<NonNullable<typeof healthSummary>["recentGaps"]>[number];
  type SubjectiveDailyData = NonNullable<NonNullable<typeof subjectiveSleepData>["dailyData"]>[number];
  const sleepTrendData = useMemo(() => {
    if (!healthSummary?.recentSleep) return [];
    return healthSummary.recentSleep.map((s: SleepEntry, i: number) => {
      // Find matching subjective data by date for perceived efficiency
      const subjectiveDay = subjectiveSleepData?.dailyData?.find(
        (d: SubjectiveDailyData) => d.date === s.date
      );
      const objectiveEff = s.efficiency ?? null;
      const perceivedEff = subjectiveDay?.perceivedEfficiency ?? null;
      // Calculate perception delta (positive = overestimates, negative = underestimates)
      const delta = (objectiveEff !== null && perceivedEff !== null)
        ? perceivedEff - objectiveEff
        : null;

      return {
        day: i + 1,
        subjectiveQuality: healthSummary.recentGaps?.find((g: GapEntry) => g.date === s.date)?.subjectiveQuality ?? null,
        objectiveEfficiency: objectiveEff,
        perceivedEfficiency: perceivedEff,
        perceptionDelta: delta,
        bedtimeConsistency: null,
        wakeTimeConsistency: null,
      };
    }).reverse();
  }, [healthSummary, subjectiveSleepData]);

  // Build compliance data - per-day completion for Sleep Log, Assessment, and Expansion
  type ComplianceEntry = NonNullable<typeof complianceDataQuery>[number];
  const complianceData = useMemo(() => {
    // Use daily compliance query with per-day completion flags
    if (complianceDataQuery && complianceDataQuery.length > 0) {
      return complianceDataQuery.map((d: ComplianceEntry) => {
        // Count tasks complete for this day
        const tasksComplete = (d.sleepLogCompleted ? 1 : 0) +
          (d.assessmentCompleted ? 1 : 0) +
          (d.expansionCompleted ? 1 : 0);

        return {
          date: d.date,
          day: d.dayNumber,
          tasksCompleted: tasksComplete,
          tasksTotal: 3, // Sleep Log + Assessment + Expansion
          sleepLogCompleted: d.sleepLogCompleted,
          assessmentCompleted: d.assessmentCompleted,
          expansionCompleted: d.expansionCompleted,
        };
      });
    }

    // Fallback - show empty progress
    const days = [];
    for (let i = 1; i <= patient.user.current_day; i++) {
      days.push({
        date: new Date(patient.user.started_at + (i - 1) * 86400000).toISOString().split("T")[0],
        day: i,
        tasksCompleted: 0,
        tasksTotal: 3,
        sleepLogCompleted: false,
        assessmentCompleted: false,
        expansionCompleted: false,
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
      type PillarStat = NonNullable<typeof pillarStats>[number];
      const stats = pillarStats?.find((s: PillarStat) => s.pillar === pillarNameMap[pillar]);
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
        // Sleep log completion based on 14-day journey (not current day)
        const TOTAL_JOURNEY_DAYS = 14;
        score = patient.completedDays > 0 ? Math.round((patient.completedDays / TOTAL_JOURNEY_DAYS) * 100) : 0;
        questionsAnswered = patient.completedDays * 5; // 5 questions per day
        questionsTotal = TOTAL_JOURNEY_DAYS * 5; // Full 14-day journey
      }
      // Only use healthSummary for sleep quantity if there's real wearable data
      if (pillar === "sleepQuantity" && healthSummary?.hasHealthKitData && healthSummary?.summary?.avgSleepHours) {
        const hrs = healthSummary.summary.avgSleepHours;
        score = hrs >= 7 ? 90 : hrs >= 6 ? 70 : hrs >= 5 ? 50 : 30;
        if (hrs < 6) alerts.push("Insufficient sleep duration");
      }

      // Calculate severity indicators for traffic lights
      const scoresForSeverity: Record<string, number | undefined> = {
        PSQI: patientScores.PSQI,
        "PHQ-9": patientScores.PHQ9,
        "GAD-7": patientScores.GAD7,
        ISI: patientScores.ISI,
        ESS: patientScores.ESS,
        MEQ: patientScores.MEQ,
        "DBAS-16": patientScores.DBAS16,
        BPI: patientScores.BPI,
        MEDAS: patientScores.MEDAS,
        BMI: patientScores.BMI,
        // Add derived metrics for sleep quantity/regularity
        avgSleepHours: healthSummary?.summary?.avgSleepHours,
        bedtimeVariance: healthSummary?.summary?.bedtimeVariance,
      };

      const severities = getPillarSeverities(
        pillar as SeverityPillarKey,
        scoresForSeverity,
        undefined // responses - could pass actual responses for Social/Metabolic derivation
      );

      return {
        pillar,
        score,
        questionsAnswered,
        questionsTotal,
        trend: null,
        alerts,
        severities,
      };
    });
  }, [patientScores, patient, healthSummary, pillarStats]);

  // Build subjective vs objective comparison
  // CRITICAL: Only include objective data if user has real wearable connection
  const sleepComparison = useMemo(() => {
    const latestGap = healthSummary?.recentGaps?.[0];
    const latestSleep = healthSummary?.recentSleep?.[0];
    const hasWearable = healthSummary?.hasHealthKitData === true;

    return {
      date: latestGap?.date || new Date().toISOString().split("T")[0],
      subjective: {
        quality: latestGap?.subjectiveQuality || 7,
        totalSleep: 420, // Default 7 hours - TODO: Get from questionnaire responses
        bedtime: "22:30",
        wakeTime: "06:30",
        awakenings: 2,
      },
      // Only include objective data if wearable is actually connected
      objective: hasWearable && latestSleep ? {
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

  // Calculate REAL compliance using actual question counts
  // Sleep Log: based on 14-day journey (days with sleep log complete / 14)
  // Assessment: based on pillar questions answered / expected questions
  const actualComplianceData = useMemo(() => {
    const TOTAL_JOURNEY_DAYS = 14;

    // Calculate assessment rate from pillarStats (actual questions answered vs expected)
    let assessmentQuestionsAnswered = 0;
    let assessmentQuestionsTotal = 0;

    if (pillarStats) {
      type PillarStat = NonNullable<typeof pillarStats>[number];
      pillarStats.forEach((stat: PillarStat) => {
        // Exclude Sleep Log from assessment calculation
        if (stat.pillar !== "Sleep Log") {
          assessmentQuestionsAnswered += stat.questionsAnswered;
          assessmentQuestionsTotal += stat.questionsTotal;
        }
      });
    }

    // Calculate assessment rate based on actual questions (not days)
    const assessmentRate = assessmentQuestionsTotal > 0
      ? Math.round((assessmentQuestionsAnswered / assessmentQuestionsTotal) * 100)
      : 0;

    if (complianceDataQuery && complianceDataQuery.length > 0) {
      // Count days where sleep log is done
      const sleepLogDays = complianceDataQuery.filter((d: ComplianceEntry) => d.sleepLogCompleted).length;

      // Sleep log rate: days with sleep log complete out of 14-day journey
      const sleepLogRate = Math.round((sleepLogDays / TOTAL_JOURNEY_DAYS) * 100);

      // Overall rate: weighted average of sleep log and assessment completion
      // Both are important, so we average them
      const overallRate = Math.round((sleepLogRate + assessmentRate) / 2);

      // Count days where BOTH tasks are complete (for streak display)
      const fullyCompleteDays = complianceDataQuery.filter(
        (d: ComplianceEntry) => d.sleepLogCompleted && d.assessmentCompleted
      ).length;
      // Count days where at least one task is complete (partial)
      const partialDays = complianceDataQuery.filter(
        (d: ComplianceEntry) => (d.sleepLogCompleted || d.assessmentCompleted) && !(d.sleepLogCompleted && d.assessmentCompleted)
      ).length;

      return {
        fullyCompleteDays,
        partialDays,
        sleepLogRate,
        assessmentRate,
        overallRate,
        assessmentQuestionsAnswered,
        assessmentQuestionsTotal,
      };
    }

    return {
      fullyCompleteDays: 0,
      partialDays: 0,
      sleepLogRate: 0,
      assessmentRate,
      overallRate: 0,
      assessmentQuestionsAnswered,
      assessmentQuestionsTotal,
    };
  }, [complianceDataQuery, pillarStats]);

  // Use modular compliance data if available, fallback to actualComplianceData
  const complianceRate = modularComplianceData?.overall.rate ?? actualComplianceData.overallRate;

  return (
    <div className="space-y-6">
      {/* Top Stats Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard
          icon={<Calendar className="w-5 h-5" />}
          label="Journey Progress"
          value={`Day ${patient.user.current_day}`}
          subValue="of 14"
          color="blue"
        />
        <StatCard
          icon={<Moon className="w-5 h-5" />}
          label={hasHealthKitData ? "Avg Sleep Quality" : "Wearable Data"}
          value={hasHealthKitData && healthSummary?.summary?.avgEfficiency ? `${healthSummary.summary.avgEfficiency}%` : "—"}
          subValue={hasHealthKitData ? "from wearable" : "not connected"}
          color="purple"
        />
        <StatCard
          icon={<Activity className="w-5 h-5" />}
          label={hasHealthKitData ? "Sleep Duration" : "Sleep Duration"}
          value={hasHealthKitData && healthSummary?.summary?.avgSleepHours ? `${healthSummary.summary.avgSleepHours.toFixed(1)}h` : "—"}
          subValue={hasHealthKitData ? "from wearable" : "no wearable"}
          color="green"
        />
        <StatCard
          icon={<TrendingUp className="w-5 h-5" />}
          label="Compliance"
          value={`${complianceRate}%`}
          subValue={modularComplianceData
            ? `${modularComplianceData.overall.totalQuestionsAnswered} Q answered`
            : actualComplianceData.fullyCompleteDays > 0
              ? `${actualComplianceData.fullyCompleteDays} complete days`
              : actualComplianceData.partialDays > 0
                ? `${actualComplianceData.partialDays} partial`
                : "no data yet"
          }
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
              <p className="text-xs text-gray-500">14-day overview</p>
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
          onPreviewPrompt={handlePreviewPrompt}
          isAnalyzing={isAnalyzing}
          isLoadingPreview={isLoadingPreview}
          lastAnalysisTime={analysis ? "Just now" : undefined}
          selectedModel={llmSettings?.primaryModel || "claude-sonnet-4-20250514"}
          modelProvider={llmSettings?.primaryModel?.startsWith("claude") ? "Anthropic" : "OpenAI"}
          error={analysisError}
        />

        {/* Subjective vs Objective */}
        <SubjectiveVsObjectiveCard
          data={sleepComparison}
          subjectiveData={subjectiveSleepData as SubjectiveSleepData | undefined}
        />

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

        {/* Analysis Workflow - Comprehensive workflow for physicians during analysis phase */}
        {patientId && (
          <div className="lg:col-span-2">
            <PatientAnalysisWorkflow
              userId={userId}
              patientId={patientId}
              onAiAnalysisRun={handleAnalyze}
            />
          </div>
        )}

        {/* Sleep Architecture - requires REAL wearable data (not questionnaire-derived) */}
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
          {sleepArchitecture && sleepArchitecture.length > 0 ? (
            <SleepBreakdown data={sleepArchitecture[sleepArchitecture.length - 1]} />
          ) : (
            <div className="flex flex-col items-center justify-center h-24 text-center">
              <Watch className="w-8 h-8 text-gray-600 mb-2" />
              <p className="text-sm text-gray-400">No Wearable Connected</p>
              <p className="text-xs text-gray-500 mt-1">Sleep stages require Apple Watch or similar device</p>
            </div>
          )}
        </div>

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

        {/* Circadian Metrics - Light Exposure & Rhythm */}
        <CircadianMetricsCard userId={userId} />

        {/* Sleep Health Factors - Naps, Medications, Caffeine */}
        <SleepHealthFactorsCard userId={userId} />
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
                {sourceDetails.map((detail: NonNullable<typeof sourceDetails>[number]) => (
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
          <ModularComplianceSummary
            data={modularComplianceData}
            showExpansionDetails={true}
          />
        </div>
        <ComplianceChart
          data={complianceData}
          height={150}
          stackedData={modularComplianceData ? {
            sleepLogRate: modularComplianceData.sleepLog.rate,
            assessmentRate: modularComplianceData.coreAssessment.rate,
            expansionRate: modularComplianceData.expansionPacks.rate,
            hasExpansion: modularComplianceData.expansionPacks.triggered,
          } : undefined}
        />
      </div>

      {/* Watch Wellness Metrics (Energy/Mood/Focus) */}
      <WellnessMetricsChart userId={userId} />

      {/* Treatment Protocol Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Check-in History */}
        <CheckInHistoryCard userId={userId} days={14} />

        {/* Compliance vs Outcomes Correlation */}
        <ComplianceCorrelationChart userId={userId} height={200} />
      </div>

      {/* Adaptive Difficulty and Protocol Assignment */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Adaptive Difficulty Panel */}
        <AdaptiveDifficultyPanel userId={userId} physicianId={patientId} />

        {/* Protocol Assignment (if physician context available) */}
        {patientId && (
          <ProtocolAssignment userId={userId} physicianId={patientId} />
        )}
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

      {/* Prompt Preview Modal */}
      {promptPreview && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50">
          <div className="bg-gray-900 rounded-xl max-w-4xl w-full max-h-[90vh] overflow-hidden border border-gray-700">
            <div className="flex items-center justify-between p-4 border-b border-gray-700">
              <div>
                <h3 className="text-lg font-semibold text-white">Analysis Prompt Preview</h3>
                <p className="text-sm text-gray-400">
                  Model: {promptPreview.selectedModel} ({promptPreview.modelProvider})
                </p>
              </div>
              <button
                onClick={() => setPromptPreview(null)}
                className="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div className="p-4 overflow-y-auto max-h-[calc(90vh-140px)]">
              <div className="mb-6">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-sm font-medium text-purple-400">System Prompt</h4>
                  <span className="text-xs text-gray-500">Sets the AI's role and behavior</span>
                </div>
                <div className="bg-gray-800 rounded-lg p-4 border border-gray-700">
                  <pre className="text-sm text-gray-300 whitespace-pre-wrap font-mono">
                    {promptPreview.systemPrompt}
                  </pre>
                </div>
              </div>
              <div className="mb-6">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-sm font-medium text-blue-400">User Prompt (Patient Data)</h4>
                  <span className="text-xs text-gray-500">Contains all patient information</span>
                </div>
                <div className="bg-gray-800 rounded-lg p-4 border border-gray-700">
                  <pre className="text-sm text-gray-300 whitespace-pre-wrap font-mono">
                    {promptPreview.userPrompt}
                  </pre>
                </div>
              </div>
              <div className="flex items-center justify-between text-sm">
                <div className="flex items-center gap-4">
                  <span className="text-gray-400">
                    Estimated Tokens: <span className="text-white">{promptPreview.estimatedTokens.toLocaleString()}</span>
                  </span>
                  <span className="text-gray-400">
                    Estimated Cost: <span className="text-white">{promptPreview.estimatedCost}</span>
                  </span>
                </div>
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(
                      `SYSTEM:\n${promptPreview.systemPrompt}\n\nUSER:\n${promptPreview.userPrompt}`
                    );
                  }}
                  className="px-3 py-1.5 bg-gray-800 text-gray-300 rounded-lg hover:bg-gray-700 transition-colors text-xs"
                >
                  Copy to Clipboard
                </button>
              </div>
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
