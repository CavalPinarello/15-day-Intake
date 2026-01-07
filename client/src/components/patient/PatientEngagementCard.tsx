"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import {
  CheckCircle,
  AlertTriangle,
  TrendingUp,
  Calendar,
} from "lucide-react";

interface PatientEngagementCardProps {
  userId: Id<"users">;
}

export function PatientEngagementCard({ userId }: PatientEngagementCardProps) {
  const modularCompliance = useQuery(api.physician.getModularComplianceData, { userId });

  if (!modularCompliance) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4 animate-pulse">
        <div className="h-4 bg-gray-700 rounded w-1/3 mb-4"></div>
        <div className="space-y-3">
          <div className="h-8 bg-gray-700 rounded"></div>
          <div className="h-8 bg-gray-700 rounded"></div>
        </div>
      </div>
    );
  }

  const overallRate = modularCompliance.overall.rate;
  const sleepLogRate = modularCompliance.sleepLog.rate;
  const assessmentRate = modularCompliance.coreAssessment.rate;

  // Determine status based on overall completion
  const status = overallRate >= 75 ? "excellent" :
                 overallRate >= 50 ? "good" :
                 overallRate >= 25 ? "fair" : "needs-attention";

  const statusConfig = {
    excellent: { color: "text-green-400", bg: "bg-green-500/20", label: "Excellent" },
    good: { color: "text-blue-400", bg: "bg-blue-500/20", label: "Good" },
    fair: { color: "text-amber-400", bg: "bg-amber-500/20", label: "Fair" },
    "needs-attention": { color: "text-red-400", bg: "bg-red-500/20", label: "Needs Attention" },
  };

  const statusStyle = statusConfig[status];

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className={`w-8 h-8 rounded-lg ${statusStyle.bg} flex items-center justify-center`}>
            <TrendingUp className={`w-4 h-4 ${statusStyle.color}`} />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Patient Engagement</h3>
            <p className="text-xs text-gray-500">Completion tracking</p>
          </div>
        </div>
        {/* Overall Status */}
        <div className="flex items-center gap-1.5">
          <span className={`px-2 py-1 rounded-full text-xs font-medium ${statusStyle.bg} ${statusStyle.color}`}>
            {statusStyle.label}
          </span>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 gap-3 mb-4">
        {/* Overall Completion */}
        <div className="bg-gray-700/30 rounded-lg p-3">
          <div className="flex items-center gap-2 mb-1">
            <CheckCircle className="w-4 h-4 text-green-400" />
            <span className="text-xs text-gray-400">Overall</span>
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-xl font-bold text-white">{overallRate}%</span>
          </div>
          <div className="text-xs text-gray-500 mt-1">
            {modularCompliance.overall.totalQuestionsAnswered} Q answered
          </div>
        </div>

        {/* Sleep Log Completion */}
        <div className="bg-gray-700/30 rounded-lg p-3">
          <div className="flex items-center gap-2 mb-1">
            <Calendar className="w-4 h-4 text-blue-400" />
            <span className="text-xs text-gray-400">Sleep Log</span>
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-xl font-bold text-white">{sleepLogRate}%</span>
          </div>
          <div className="text-xs text-gray-500 mt-1">
            {modularCompliance.sleepLog.daysCompleted}/10 days
          </div>
        </div>

        {/* Assessment Completion */}
        <div className="bg-gray-700/30 rounded-lg p-3 col-span-2">
          <div className="flex items-center gap-2 mb-1">
            <CheckCircle className="w-4 h-4 text-purple-400" />
            <span className="text-xs text-gray-400">Assessment Progress</span>
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-xl font-bold text-white">{assessmentRate}%</span>
          </div>
          <div className="text-xs text-gray-500 mt-1">
            {modularCompliance.coreAssessment.questionsAnswered} of {modularCompliance.coreAssessment.questionsRequired} questions
          </div>
        </div>
      </div>

      {/* Status Insights */}
      {overallRate < 50 && (
        <div className="flex items-start gap-2 text-xs p-2 rounded-lg bg-amber-500/10 text-amber-400">
          <AlertTriangle className="w-3 h-3 mt-0.5 flex-shrink-0" />
          <span>Patient may need additional engagement or support</span>
        </div>
      )}

      {overallRate >= 75 && (
        <div className="flex items-start gap-2 text-xs p-2 rounded-lg bg-green-500/10 text-green-400">
          <CheckCircle className="w-3 h-3 mt-0.5 flex-shrink-0" />
          <span>Excellent engagement - patient is actively participating</span>
        </div>
      )}
    </div>
  );
}
