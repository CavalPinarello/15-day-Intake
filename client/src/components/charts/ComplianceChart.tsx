"use client";
/* eslint-disable @typescript-eslint/no-explicit-any */

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
  Legend,
} from "recharts";

interface ComplianceDataPoint {
  date: string;
  day: number;
  tasksCompleted: number;
  tasksTotal: number;
  sleepLogCompleted: boolean;
  assessmentCompleted: boolean;
  expansionCompleted?: boolean;
  hasExpansionTask?: boolean; // Whether a Deeper Dive was assigned for this day
  hasAssessmentTask?: boolean; // Whether core assessment exists for this day (Days 1-5)
  expansionQuestionsAnswered?: number;
}

interface StackedComplianceData {
  sleepLogRate: number;
  assessmentRate: number;
  expansionRate: number;
  hasExpansion: boolean;
}

interface ComplianceChartProps {
  data: ComplianceDataPoint[];
  height?: number;
  showTarget?: boolean;
  targetPercentage?: number;
  stackedData?: StackedComplianceData;
}

const getComplianceColor = (percentage: number) => {
  if (percentage >= 90) return "#10B981"; // Green - Excellent
  if (percentage >= 70) return "#F59E0B"; // Amber - Good
  if (percentage >= 50) return "#F97316"; // Orange - Fair
  return "#EF4444"; // Red - Poor
};

// Segment colors
const SEGMENT_COLORS = {
  sleepLog: "#F59E0B",    // Amber for Sleep Log
  assessment: "#3B82F6",   // Blue for Assessment
  expansion: "#8B5CF6",    // Purple for Expansion
};

export function ComplianceChart({
  data,
  height = 200,
  showTarget = true,
  targetPercentage = 80,
  stackedData: _stackedData,
}: ComplianceChartProps) {
  // Build stacked chart data - each day shows segments for Sleep Log, Assessment, Expansion
  // Each segment shows per-day completion (complete = full segment, not complete = empty)

  const chartData = data.map((point) => {
    // Use backend flags as source of truth for which tasks exist on each day
    const hasAssessment = point.hasAssessmentTask ?? (point.day <= 5); // Days 1-5 have core assessment
    const hasExpansion = point.hasExpansionTask ?? false;

    // Expansion is complete only if the user actually completed the expansion questions
    const expansionCompleteThisDay = point.expansionCompleted === true;

    // Weights for stacked bar segments that total 100% when all complete
    // The weight depends on how many task types exist for this day:
    // - Sleep Log only: 100%
    // - Sleep Log + Assessment: 50% + 50% = 100%
    // - Sleep Log + Expansion: 50% + 50% = 100%
    // - Sleep Log + Assessment + Expansion: 33% + 34% + 33% = 100%
    let sleepLogWeight: number;
    let assessmentWeight: number;
    let expansionWeight: number;

    if (hasAssessment && hasExpansion) {
      // All three tasks
      sleepLogWeight = 33;
      assessmentWeight = 34;
      expansionWeight = 33;
    } else if (hasAssessment && !hasExpansion) {
      // Sleep Log + Assessment only (Days 1-5 without expansion trigger)
      sleepLogWeight = 50;
      assessmentWeight = 50;
      expansionWeight = 0;
    } else if (!hasAssessment && hasExpansion) {
      // Sleep Log + Expansion only (Days 6-14 with expansion)
      sleepLogWeight = 50;
      assessmentWeight = 0;
      expansionWeight = 50;
    } else {
      // Sleep Log only (Days 6-14 without expansion)
      sleepLogWeight = 100;
      assessmentWeight = 0;
      expansionWeight = 0;
    }

    // Per-day completion - segment fills if task is complete for that day
    const sleepLogValue = point.sleepLogCompleted ? sleepLogWeight : 0;
    const assessmentValue = (hasAssessment && point.assessmentCompleted) ? assessmentWeight : 0;
    // Expansion segment fills only when completed
    const expansionValue = (hasExpansion && expansionCompleteThisDay) ? expansionWeight : 0;

    return {
      day: `Day ${point.day}`,
      date: point.date,
      sleepLog: sleepLogValue,
      assessment: assessmentValue,
      expansion: expansionValue,
      sleepLogComplete: point.sleepLogCompleted,
      assessmentComplete: point.assessmentCompleted,
      expansionComplete: expansionCompleteThisDay,
      hasAssessment,
      hasExpansion,
    };
  });

  // Check if any day has expansion/assessment for legend display
  const anyDayHasExpansion = chartData.some(d => d.hasExpansion);
  const anyDayHasAssessment = chartData.some(d => d.hasAssessment);

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      const data = payload[0].payload;
      const total = data.sleepLog + data.assessment + data.expansion;
      return (
        <div className="bg-gray-800 border border-gray-700 rounded-lg p-3 text-sm">
          <div className="font-medium text-white mb-2">{label}</div>
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded" style={{ backgroundColor: SEGMENT_COLORS.sleepLog }} />
              <span className={data.sleepLogComplete ? "text-green-400" : "text-gray-400"}>
                Sleep Log: {data.sleepLog}%
                {data.sleepLogComplete && " ✓"}
              </span>
            </div>
            {data.hasAssessment && (
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded" style={{ backgroundColor: SEGMENT_COLORS.assessment }} />
                <span className={data.assessmentComplete ? "text-green-400" : "text-gray-400"}>
                  Assessment: {data.assessment}%
                  {data.assessmentComplete && " ✓"}
                </span>
              </div>
            )}
            {data.hasExpansion && (
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded" style={{ backgroundColor: SEGMENT_COLORS.expansion }} />
                <span className={data.expansionComplete ? "text-green-400" : "text-gray-400"}>
                  Deeper Dive: {data.expansion}%
                  {data.expansionComplete && " ✓"}
                </span>
              </div>
            )}
            <div className="border-t border-gray-600 pt-1 mt-1">
              <span className="text-white font-medium">Total: {total}%</span>
            </div>
          </div>
        </div>
      );
    }
    return null;
  };

  return (
    <div className="w-full" style={{ height }}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={chartData}
          margin={{ top: 10, right: 10, left: 0, bottom: 5 }}
        >
          <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
          <XAxis
            dataKey="day"
            tick={{ fill: "#E5E7EB", fontSize: 11 }}
            tickLine={{ stroke: "#6B7280" }}
            axisLine={{ stroke: "#6B7280" }}
          />
          <YAxis
            domain={[0, 100]}
            tick={{ fill: "#E5E7EB", fontSize: 11 }}
            tickLine={{ stroke: "#6B7280" }}
            axisLine={{ stroke: "#6B7280" }}
            tickFormatter={(value) => `${value}%`}
          />
          <Tooltip content={<CustomTooltip />} />

          {/* Target line */}
          {showTarget && (
            <ReferenceLine
              y={targetPercentage}
              stroke="#10B981"
              strokeDasharray="5 5"
              strokeOpacity={0.7}
              label={{
                value: `Target ${targetPercentage}%`,
                position: "right",
                fill: "#10B981",
                fontSize: 10,
              }}
            />
          )}

          {/* Legend */}
          <Legend
            verticalAlign="top"
            height={24}
            iconType="rect"
            iconSize={10}
            formatter={(value) => <span className="text-gray-200 text-xs">{value}</span>}
          />

          {/* Stacked bars for each segment */}
          <Bar
            dataKey="sleepLog"
            stackId="compliance"
            fill={SEGMENT_COLORS.sleepLog}
            name="Sleep Log"
            radius={!anyDayHasAssessment && !anyDayHasExpansion ? [4, 4, 0, 0] : undefined}
          />
          {/* Show assessment bar if any day has assessment (Days 1-5) */}
          {anyDayHasAssessment && (
            <Bar
              dataKey="assessment"
              stackId="compliance"
              fill={SEGMENT_COLORS.assessment}
              name="Assessment"
              radius={anyDayHasExpansion ? undefined : [4, 4, 0, 0]}
            />
          )}
          {/* Show expansion bar if any day has expansion task */}
          {anyDayHasExpansion && (
            <Bar
              dataKey="expansion"
              stackId="compliance"
              fill={SEGMENT_COLORS.expansion}
              name="Deeper Dive"
              radius={[4, 4, 0, 0]}
            />
          )}
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

// Streak indicator component
interface StreakIndicatorProps {
  currentStreak: number;
  longestStreak: number;
  last7Days: boolean[];
}

export function StreakIndicator({
  currentStreak,
  longestStreak,
  last7Days,
}: StreakIndicatorProps) {
  return (
    <div className="flex flex-col gap-3">
      {/* Streak stats */}
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-2">
          <span className="text-2xl">🔥</span>
          <div>
            <div className="text-lg font-bold text-white">{currentStreak}</div>
            <div className="text-xs text-gray-400">Current Streak</div>
          </div>
        </div>
        <div className="text-right">
          <div className="text-lg font-medium text-gray-300">
            {longestStreak}
          </div>
          <div className="text-xs text-gray-400">Best Streak</div>
        </div>
      </div>

      {/* Last 7 days dots */}
      <div className="flex justify-between gap-1">
        {last7Days.map((completed, i) => (
          <div
            key={i}
            className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium ${
              completed
                ? "bg-green-500/20 text-green-400 border border-green-500/50"
                : "bg-gray-700/50 text-gray-500 border border-gray-600"
            }`}
          >
            {completed ? "✓" : "−"}
          </div>
        ))}
      </div>

      {/* Day labels */}
      <div className="flex justify-between gap-1">
        {["M", "T", "W", "T", "F", "S", "S"].map((day, i) => (
          <div key={i} className="w-8 text-center text-xs text-gray-500">
            {day}
          </div>
        ))}
      </div>
    </div>
  );
}

// Compact compliance summary (legacy - for backwards compatibility)
interface ComplianceSummaryProps {
  overallPercentage: number;
  sleepLogRate: number;
  assessmentRate: number;
  interventionRate: number;
}

export function ComplianceSummary({
  overallPercentage,
  sleepLogRate,
  assessmentRate,
  interventionRate,
}: ComplianceSummaryProps) {
  const items = [
    { label: "Sleep Log", rate: sleepLogRate, icon: "📝" },
    { label: "Assessment", rate: assessmentRate, icon: "📋" },
    { label: "Interventions", rate: interventionRate, icon: "💊" },
  ];

  return (
    <div className="space-y-3">
      {/* Overall percentage */}
      <div className="flex items-center justify-between">
        <span className="text-sm text-gray-200">Overall Compliance</span>
        <span
          className="text-xl font-bold"
          style={{ color: getComplianceColor(overallPercentage) }}
        >
          {overallPercentage}%
        </span>
      </div>

      {/* Progress bar */}
      <div className="w-full h-3 bg-gray-700 rounded-full overflow-hidden">
        <div
          className="h-full rounded-full transition-all duration-500"
          style={{
            width: `${overallPercentage}%`,
            backgroundColor: getComplianceColor(overallPercentage),
          }}
        />
      </div>

      {/* Breakdown */}
      <div className="grid grid-cols-3 gap-2 pt-2">
        {items.map((item) => (
          <div
            key={item.label}
            className="text-center p-2 bg-gray-800/50 rounded-lg"
          >
            <div className="text-lg">{item.icon}</div>
            <div
              className="text-sm font-medium"
              style={{ color: getComplianceColor(item.rate) }}
            >
              {item.rate}%
            </div>
            <div className="text-xs text-gray-200">{item.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// Modular compliance summary with expansion pack support
interface ModularComplianceData {
  sleepLog: {
    daysCompleted: number;
    totalDays: number;
    rate: number;
    questionsAnswered: number;
  };
  coreAssessment: {
    questionsAnswered: number;
    totalQuestions: number;
    rate: number;
  };
  expansionPacks: {
    triggered: boolean;
    triggeredGateways: string[];
    questionsAnswered: number;
    totalQuestions: number;
    rate: number;
    modules: Array<{
      id: string;
      name: string;
      questionsAnswered: number;
      questionsFromCore: number;
      questionsFromExpansion: number;
      totalQuestions: number;
      completed: boolean;
      completionPercentage: number;
    }>;
  };
  overall: {
    rate: number;
    totalQuestionsAnswered: number;
    totalQuestionsExpected: number;
  };
}

interface ModularComplianceSummaryProps {
  data: ModularComplianceData | null | undefined;
  showExpansionDetails?: boolean;
}

export function ModularComplianceSummary({
  data,
  showExpansionDetails = false,
}: ModularComplianceSummaryProps) {
  if (!data) {
    return (
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-sm text-gray-400">Overall Compliance</span>
          <span className="text-xl font-bold text-gray-500">--%</span>
        </div>
        <div className="w-full h-3 bg-gray-700 rounded-full" />
      </div>
    );
  }

  const { sleepLog, coreAssessment, expansionPacks, overall } = data;

  return (
    <div className="space-y-3">
      {/* Overall percentage */}
      <div className="flex items-center justify-between">
        <span className="text-sm text-gray-200">Overall Compliance</span>
        <span
          className="text-xl font-bold"
          style={{ color: getComplianceColor(overall.rate) }}
        >
          {overall.rate}%
        </span>
      </div>

      {/* Segmented progress bar */}
      <div className="w-full h-3 bg-gray-700 rounded-full overflow-hidden flex">
        {/* Sleep Log segment */}
        <div
          className="h-full transition-all duration-500"
          style={{
            width: `${expansionPacks.triggered ? 30 : 40}%`,
            backgroundColor: getComplianceColor(sleepLog.rate),
            opacity: sleepLog.rate > 0 ? 1 : 0.3,
          }}
          title={`Sleep Log: ${sleepLog.rate}%`}
        />
        {/* Core Assessment segment */}
        <div
          className="h-full transition-all duration-500 border-l border-gray-600"
          style={{
            width: `${expansionPacks.triggered ? 40 : 60}%`,
            backgroundColor: getComplianceColor(coreAssessment.rate),
            opacity: coreAssessment.rate > 0 ? 1 : 0.3,
          }}
          title={`Core Assessment: ${coreAssessment.rate}%`}
        />
        {/* Expansion Packs segment (only if triggered) */}
        {expansionPacks.triggered && (
          <div
            className="h-full transition-all duration-500 border-l border-gray-600"
            style={{
              width: "30%",
              backgroundColor: getComplianceColor(expansionPacks.rate),
              opacity: expansionPacks.rate > 0 ? 1 : 0.3,
            }}
            title={`Expansion Packs: ${expansionPacks.rate}%`}
          />
        )}
      </div>

      {/* Modular breakdown */}
      <div className={`grid gap-2 pt-2 ${expansionPacks.triggered ? "grid-cols-3" : "grid-cols-2"}`}>
        {/* Sleep Log */}
        <div className="text-center p-2 bg-gray-800/50 rounded-lg">
          <div className="text-lg">📝</div>
          <div
            className="text-sm font-medium"
            style={{ color: getComplianceColor(sleepLog.rate) }}
          >
            {sleepLog.rate}%
          </div>
          <div className="text-xs text-gray-200">Sleep Log</div>
          <div className="text-[10px] text-gray-400 mt-0.5">
            {sleepLog.daysCompleted}/{sleepLog.totalDays} days
          </div>
        </div>

        {/* Core Assessment */}
        <div className="text-center p-2 bg-gray-800/50 rounded-lg">
          <div className="text-lg">📋</div>
          <div
            className="text-sm font-medium"
            style={{ color: getComplianceColor(coreAssessment.rate) }}
          >
            {coreAssessment.rate}%
          </div>
          <div className="text-xs text-gray-200">Core Assessment</div>
          <div className="text-[10px] text-gray-400 mt-0.5">
            {coreAssessment.questionsAnswered}/{coreAssessment.totalQuestions} Q
          </div>
        </div>

        {/* Expansion Packs (only if triggered) */}
        {expansionPacks.triggered && (
          <div className="text-center p-2 bg-gray-800/50 rounded-lg">
            <div className="text-lg">🔬</div>
            <div
              className="text-sm font-medium"
              style={{ color: getComplianceColor(expansionPacks.rate) }}
            >
              {expansionPacks.rate}%
            </div>
            <div className="text-xs text-gray-200">Expansion</div>
            <div className="text-[10px] text-gray-400 mt-0.5">
              {expansionPacks.modules.length} modules
            </div>
          </div>
        )}
      </div>

      {/* Expansion module details (optional) */}
      {showExpansionDetails && expansionPacks.triggered && expansionPacks.modules.length > 0 && (
        <div className="mt-3 pt-3 border-t border-gray-700/50">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs text-gray-400">Expansion Modules</span>
            <span className="text-[10px] text-gray-500">
              {expansionPacks.modules.filter(m => m.completed).length}/{expansionPacks.modules.length} complete
            </span>
          </div>
          <div className="space-y-1.5 max-h-40 overflow-y-auto pr-1">
            {expansionPacks.modules.map((module) => {
              const corePercent = Math.round((module.questionsFromCore / module.totalQuestions) * 100);
              const expansionPercent = Math.round((module.questionsFromExpansion / module.totalQuestions) * 100);

              return (
                <div
                  key={module.id}
                  className="flex items-center justify-between text-xs group relative"
                >
                  <span className="text-gray-400 truncate flex-1 mr-2">
                    {module.completed && <span className="text-green-400 mr-1">✓</span>}
                    {module.name}
                  </span>
                  <div className="flex items-center gap-2">
                    {/* Stacked progress bar: core (lighter) + expansion (darker) */}
                    <div className="w-20 h-2 bg-gray-700 rounded-full overflow-hidden flex">
                      {/* Core contribution segment (lighter shade) */}
                      {module.questionsFromCore > 0 && (
                        <div
                          className="h-full transition-all duration-300"
                          style={{
                            width: `${corePercent}%`,
                            backgroundColor: module.completed ? "#6EE7B7" : "#FCD34D", // Lighter green/amber
                          }}
                        />
                      )}
                      {/* Expansion contribution segment (darker shade) */}
                      {module.questionsFromExpansion > 0 && (
                        <div
                          className="h-full transition-all duration-300"
                          style={{
                            width: `${expansionPercent}%`,
                            backgroundColor: module.completed ? "#10B981" : "#F59E0B", // Darker green/amber
                          }}
                        />
                      )}
                    </div>
                    <span className="text-gray-500 w-12 text-right">
                      {module.questionsAnswered}/{module.totalQuestions}
                    </span>
                  </div>
                  {/* Tooltip showing core/expansion breakdown */}
                  <div className="absolute left-0 right-0 -top-8 hidden group-hover:block z-10">
                    <div className="bg-gray-900 border border-gray-700 rounded px-2 py-1 text-[10px] text-center mx-auto w-fit whitespace-nowrap">
                      {module.questionsFromCore > 0 && module.questionsFromExpansion > 0 ? (
                        <span>{module.questionsFromCore} from core + {module.questionsFromExpansion} from expansion</span>
                      ) : module.questionsFromCore > 0 ? (
                        <span>{module.questionsFromCore} from core assessment</span>
                      ) : (
                        <span>{module.questionsFromExpansion} from expansion pack</span>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
          {/* Legend for color coding */}
          <div className="flex items-center justify-center gap-4 mt-2 pt-2 border-t border-gray-700/30">
            <div className="flex items-center gap-1.5">
              <div className="w-3 h-2 rounded-sm" style={{ backgroundColor: "#FCD34D" }} />
              <span className="text-[10px] text-gray-500">From Core</span>
            </div>
            <div className="flex items-center gap-1.5">
              <div className="w-3 h-2 rounded-sm" style={{ backgroundColor: "#F59E0B" }} />
              <span className="text-[10px] text-gray-500">From Expansion</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
