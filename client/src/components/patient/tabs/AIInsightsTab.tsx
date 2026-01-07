"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { AIInsightsCard } from "../AIInsightsCard";
import { PerceptionGapCard } from "../PerceptionGapCard";
import { PatientAnalysisWorkflow } from "../PatientAnalysisWorkflow";

interface AIInsightsTabProps {
  userId: Id<"users">;
  patientId?: string; // For navigation links in workflow component
}

export function AIInsightsTab({ userId, patientId }: AIInsightsTabProps) {
  return (
    <div className="space-y-6">
      {/* AI Analysis Workflow */}
      {patientId && (
        <PatientAnalysisWorkflow userId={userId} patientId={patientId} />
      )}

      {/* AI Insights Card */}
      <AIInsightsCard
        insights={[]}
        onRunDeepAnalysis={() => {}}
        onPreviewPrompt={() => {}}
        isAnalyzing={false}
        isLoadingPreview={false}
      />

      {/* Perception Gap Analysis */}
      <PerceptionGapCard userId={userId} />
    </div>
  );
}
