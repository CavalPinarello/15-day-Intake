"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import {
  ComplianceChart,
  ModularComplianceSummary,
} from "@/components/charts/ComplianceChart";
import { CheckInHistoryCard } from "../CheckInHistoryCard";
import { ComplianceCorrelationChart } from "@/components/charts/ComplianceCorrelationChart";

interface ComplianceTabProps {
  userId: Id<"users">;
}

export function ComplianceTab({ userId }: ComplianceTabProps) {
  // Fetch compliance data
  const dailyCompliance = useQuery(api.physician.getDailyComplianceData, { userId });
  const modularCompliance = useQuery(api.physician.getModularComplianceData, { userId });

  return (
    <div className="space-y-6">
      {/* Modular Compliance Summary */}
      {modularCompliance && (
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">Compliance Overview</h3>
          <ModularComplianceSummary data={modularCompliance} />
        </div>
      )}

      {/* Daily Compliance Chart */}
      {dailyCompliance && dailyCompliance.length > 0 && (
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">Daily Task Completion</h3>
          <ComplianceChart data={dailyCompliance} />
        </div>
      )}

      {/* Check-in History (Energy/Mood/Focus) */}
      <CheckInHistoryCard userId={userId} days={14} />

      {/* Compliance Correlation Chart */}
      <ComplianceCorrelationChart userId={userId} />

      {/* Empty State */}
      {(!dailyCompliance || dailyCompliance.length === 0) && (
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-12 text-center">
          <p className="text-gray-400">No compliance data available yet.</p>
          <p className="text-sm text-gray-500 mt-2">
            Data will appear as the patient completes their daily tasks.
          </p>
        </div>
      )}
    </div>
  );
}
