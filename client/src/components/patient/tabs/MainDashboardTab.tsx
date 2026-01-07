"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState, useMemo } from "react";
import { PillarSummaryCard, PillarKey, type PillarStatus } from "../PillarSummaryCard";
import { getPillarSeverities, type PillarKey as SeverityPillarKey } from "@/utils/pillarSeverity";
import { PillarDetailModal } from "../PillarDetailModal";
import { PatientEngagementCard } from "../PatientEngagementCard";
import { CircadianMetricsCard } from "../CircadianMetricsCard";
import { HealthKitDataCard } from "../HealthKitDataCard";
import { HealthKitDataModal } from "../HealthKitDataModal";
import { NapsCard } from "../health-factors/NapsCard";
import { MultiSourceSleepChart, SourceBadges } from "@/components/charts/MultiSourceSleepChart";
import { Calendar, Moon, Activity, TrendingUp } from "lucide-react";

interface MainDashboardTabProps {
  userId: Id<"users">;
  patientId?: string;
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

// Stat Card Component
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
  subValue: string;
  color: "blue" | "purple" | "green" | "amber";
}) {
  const colorClasses = {
    blue: "bg-blue-500/20 text-blue-400",
    purple: "bg-purple-500/20 text-purple-400",
    green: "bg-green-500/20 text-green-400",
    amber: "bg-amber-500/20 text-amber-400",
  };

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      <div className="flex items-center gap-2 mb-2">
        <div className={`w-8 h-8 rounded-lg ${colorClasses[color]} flex items-center justify-center`}>
          {icon}
        </div>
        <span className="text-xs text-gray-400">{label}</span>
      </div>
      <div>
        <p className="text-2xl font-bold text-white">{value}</p>
        <p className="text-xs text-gray-500">{subValue}</p>
      </div>
    </div>
  );
}

export function MainDashboardTab({ userId, patientId, patient }: MainDashboardTabProps) {
  const [healthKitModalOpen, setHealthKitModalOpen] = useState(false);
  const [selectedPillar, setSelectedPillar] = useState<PillarKey | null>(null);

  // Fetch data (force rebuild timestamp: 2026-01-07T20:05)
  const healthSummary = useQuery(api.healthkit.getPatientHealthSummary, { userId });
  const multiSourceData = useQuery(api.healthkit.getMultiSourceSleepData, { userId, days: 10 });
  const subjectiveSleepData = useQuery(api.physician.getSubjectiveSleepQuality, { userId, days: 10 });
  const checkInHistory = useQuery(api.checkIn.getCheckInHistory, { userId, days: 10 });
  const pillarStats = useQuery(api.physician.getPillarStats, { userId });
  const scores = useQuery(api.physician.getQuestionnaireScores, { userId });
  const modularComplianceData = useQuery(api.physician.getModularComplianceData, { userId });

  // Check for HealthKit data
  const hasHealthKitData = healthSummary?.hasHealthKitData || false;

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

  // Build pillar statuses
  const pillarStatuses = useMemo(() => {
    const pillars: PillarKey[] = [
      "social", "metabolic", "sleepQuality", "sleepQuantity",
      "sleepRegularity", "sleepTiming", "mentalHealth",
      "cognitive", "physical", "nutritional", "sleepLog"
    ];

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

      type PillarStat = NonNullable<typeof pillarStats>[number];
      const stats = pillarStats?.find((s: PillarStat) => s.pillar === pillarNameMap[pillar]);
      if (stats) {
        questionsAnswered = stats.questionsAnswered;
        questionsTotal = stats.questionsTotal;
        if (stats.questionsAnswered > 0) {
          score = stats.completionPercent;
        }
      }

      // Override with specific clinical scores
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
        const TOTAL_JOURNEY_DAYS = 10;
        score = patient.completedDays > 0 ? Math.round((patient.completedDays / TOTAL_JOURNEY_DAYS) * 100) : 0;
        questionsAnswered = patient.completedDays * 5;
        questionsTotal = TOTAL_JOURNEY_DAYS * 5;
      }
      if (pillar === "sleepQuantity" && healthSummary?.hasHealthKitData && healthSummary?.summary?.avgSleepHours) {
        const hrs = healthSummary.summary.avgSleepHours;
        score = hrs >= 7 ? 90 : hrs >= 6 ? 70 : hrs >= 5 ? 50 : 30;
        if (hrs < 6) alerts.push("Insufficient sleep duration");
      }

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
        avgSleepHours: healthSummary?.summary?.avgSleepHours,
        bedtimeVariance: healthSummary?.summary?.bedtimeVariance,
      };

      const severities = getPillarSeverities(
        pillar as SeverityPillarKey,
        scoresForSeverity,
        undefined
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

  // Compliance rate
  const complianceRate = modularComplianceData?.overall.rate ?? 0;

  return (
    <div className="space-y-6">
      {/* Top Stats Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard
          icon={<Calendar className="w-5 h-5" />}
          label="Journey Progress"
          value={`Day ${patient.user.current_day}`}
          subValue="of 10"
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
          label="Sleep Duration"
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
            : "no data yet"
          }
          color="amber"
        />
      </div>

      {/* 1. Sleep Quality Trends (TOP PRIORITY) - Enhanced Multi-Source Chart */}
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gray-700/50 flex items-center justify-center text-gray-400">
              <Moon className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-medium text-white">Sleep Quality Trends</h3>
              <p className="text-xs text-gray-500">10-day overview with device breakdown</p>
            </div>
          </div>
          {multiSourceData?.hasMultipleSources && (
            <SourceBadges sources={multiSourceData.sources} />
          )}
        </div>
        {multiSourceData && multiSourceData.comparisonData.length > 0 ? (
          <MultiSourceSleepChart
            hasMultipleSources={multiSourceData.hasMultipleSources}
            sources={multiSourceData.sources}
            sourceStats={multiSourceData.sourceStats}
            comparisonData={multiSourceData.comparisonData}
            totalDays={multiSourceData.totalDays}
            metric="efficiency"
            height={220}
            wellnessData={checkInHistory || []}
          />
        ) : (
          <div className="h-[220px] flex items-center justify-center text-gray-500">
            <p className="text-sm">No sleep data available yet</p>
          </div>
        )}
      </div>

      {/* Main Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* 2. Health Pillars */}
        <div className="lg:col-span-2">
          <PillarSummaryCard
            pillars={pillarStatuses}
            onPillarClick={(pillar) => setSelectedPillar(pillar)}
          />
        </div>

        {/* 6. Patient Engagement (Simplified - No Gamification) */}
        <PatientEngagementCard userId={userId} />
      </div>

      {/* Secondary Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* 3. Circadian Signal Information */}
        <CircadianMetricsCard userId={userId} />

        {/* 4. Naps Tracking */}
        <NapsCard userId={userId} />

        {/* 5. HealthKit Data (Collapsible Module) */}
        <HealthKitDataCard
          userId={userId}
          onOpenModal={() => setHealthKitModalOpen(true)}
        />
      </div>

      {/* Pillar Detail Modal */}
      {selectedPillar && (
        <PillarDetailModal
          isOpen={!!selectedPillar}
          onClose={() => setSelectedPillar(null)}
          userId={userId}
          pillar={selectedPillar}
          pillarStatus={pillarStatuses.find(p => p.pillar === selectedPillar) || pillarStatuses[0]}
        />
      )}

      {/* HealthKit Data Modal */}
      {healthKitModalOpen && (
        <HealthKitDataModal
          isOpen={healthKitModalOpen}
          onClose={() => setHealthKitModalOpen(false)}
          userId={userId}
        />
      )}
    </div>
  );
}
