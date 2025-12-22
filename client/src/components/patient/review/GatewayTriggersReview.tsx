"use client";

import { useQuery } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useMemo } from "react";
import {
  AlertTriangle,
  Shield,
  Moon,
  Brain,
  Frown,
  Zap,
  Wind,
  Activity,
  CheckCircle,
} from "lucide-react";
import { ReviewSection } from "./ReviewSection";

interface GatewayTriggersReviewProps {
  userId: Id<"users">;
  isReviewed: boolean;
  onReviewedChange: (reviewed: boolean) => void;
}

interface GatewayInfo {
  id: string;
  name: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
  triggered: boolean;
  triggerScore?: number;
  triggerThreshold?: number;
  triggerReason?: string;
}

// Gateway definitions
const GATEWAY_DEFINITIONS: Record<
  string,
  {
    name: string;
    description: string;
    icon: React.ComponentType<{ className?: string }>;
    questionnaire: string;
    threshold: number;
    thresholdLabel: string;
  }
> = {
  insomnia: {
    name: "Insomnia",
    description: "Difficulty falling or staying asleep",
    icon: Moon,
    questionnaire: "ISI",
    threshold: 10,
    thresholdLabel: "ISI ≥ 10",
  },
  depression: {
    name: "Depression",
    description: "Depressive symptoms affecting mood",
    icon: Frown,
    questionnaire: "PHQ-9",
    threshold: 10,
    thresholdLabel: "PHQ-9 ≥ 10",
  },
  anxiety: {
    name: "Anxiety",
    description: "Anxious thoughts disrupting sleep",
    icon: Brain,
    questionnaire: "GAD-7",
    threshold: 10,
    thresholdLabel: "GAD-7 ≥ 10",
  },
  sleep_apnea: {
    name: "Sleep Apnea",
    description: "Breathing disruptions during sleep",
    icon: Wind,
    questionnaire: "STOP-BANG",
    threshold: 3,
    thresholdLabel: "STOP-BANG ≥ 3",
  },
  sleepiness: {
    name: "Daytime Sleepiness",
    description: "Excessive sleepiness during the day",
    icon: Zap,
    questionnaire: "ESS",
    threshold: 10,
    thresholdLabel: "ESS ≥ 10",
  },
  pain: {
    name: "Chronic Pain",
    description: "Pain interfering with sleep",
    icon: Activity,
    questionnaire: "BPI-SF",
    threshold: 4,
    thresholdLabel: "BPI-SF ≥ 4",
  },
};

export function GatewayTriggersReview({
  userId,
  isReviewed,
  onReviewedChange,
}: GatewayTriggersReviewProps) {
  // Fetch gateway trigger data
  const scoresData = useQuery(api.physician.calculatePatientScores, { userId });
  const questionnaireScores = useQuery(api.physician.getQuestionnaireScores, { userId });

  // Process gateway triggers
  const processedGateways = useMemo(() => {
    if (!scoresData) return null;

    const gateways: GatewayInfo[] = [];
    let triggeredCount = 0;

    // Check each gateway
    Object.entries(GATEWAY_DEFINITIONS).forEach(([id, def]) => {
      const gateway: GatewayInfo = {
        id,
        name: def.name,
        description: def.description,
        icon: def.icon,
        triggered: false,
        triggerThreshold: def.threshold,
      };

      // Check if gateway is triggered in scores data
      const gatewayKey = `${id}Gateway`;
      if (scoresData[gatewayKey as keyof typeof scoresData]) {
        gateway.triggered = true;
        triggeredCount++;
      }

      // Get the actual score if available
      if (questionnaireScores) {
        const qKey = def.questionnaire.toLowerCase().replace(/-/g, "_");
        const scoreData = questionnaireScores[qKey as keyof typeof questionnaireScores];
        if (typeof scoreData === "object" && scoreData !== null && "score" in scoreData) {
          gateway.triggerScore = (scoreData as { score: number }).score;
          gateway.triggerReason = `${def.questionnaire} score: ${gateway.triggerScore} (threshold: ${def.threshold})`;

          // Double-check trigger status based on actual score
          if (gateway.triggerScore >= def.threshold) {
            gateway.triggered = true;
          }
        }
      }

      gateways.push(gateway);
    });

    // Sort: triggered first, then by score
    gateways.sort((a, b) => {
      if (a.triggered && !b.triggered) return -1;
      if (!a.triggered && b.triggered) return 1;
      return (b.triggerScore || 0) - (a.triggerScore || 0);
    });

    // Count triggered gateways
    triggeredCount = gateways.filter((g) => g.triggered).length;

    return {
      gateways,
      triggeredCount,
      totalCount: gateways.length,
    };
  }, [scoresData, questionnaireScores]);

  // Build preview text
  const preview = useMemo(() => {
    if (!processedGateways) return "Loading gateway analysis...";

    if (processedGateways.triggeredCount === 0) {
      return "No gateways triggered";
    }

    const triggeredNames = processedGateways.gateways
      .filter((g) => g.triggered)
      .map((g) => g.name)
      .slice(0, 3)
      .join(", ");

    if (processedGateways.triggeredCount > 3) {
      return `${processedGateways.triggeredCount} triggered: ${triggeredNames}...`;
    }

    return `${processedGateways.triggeredCount} triggered: ${triggeredNames}`;
  }, [processedGateways]);

  return (
    <ReviewSection
      id="gateways"
      title="Review gateway triggers"
      icon={<Shield className="w-4 h-4" />}
      preview={preview}
      isReviewed={isReviewed}
      onReviewedChange={onReviewedChange}
      isLoading={!processedGateways}
    >
      {processedGateways ? (
        <div className="space-y-4">
          {/* Summary */}
          <div className="flex items-center gap-4 text-sm">
            {processedGateways.triggeredCount > 0 ? (
              <div className="flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-red-400" />
                <span className="text-red-400 font-medium">
                  {processedGateways.triggeredCount} gateway{processedGateways.triggeredCount > 1 ? "s" : ""} triggered
                </span>
              </div>
            ) : (
              <div className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-400" />
                <span className="text-green-400 font-medium">No gateways triggered</span>
              </div>
            )}
            <span className="text-gray-500">
              ({processedGateways.totalCount} checked)
            </span>
          </div>

          {/* Gateways Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            {processedGateways.gateways.map((gateway) => {
              const GatewayIcon = gateway.icon;
              return (
                <div
                  key={gateway.id}
                  className={`p-3 rounded-lg border ${
                    gateway.triggered
                      ? "bg-red-500/10 border-red-500/30"
                      : "bg-gray-800/30 border-gray-700/50"
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <div
                      className={`w-8 h-8 rounded-lg flex items-center justify-center ${
                        gateway.triggered
                          ? "bg-red-500/20 text-red-400"
                          : "bg-gray-700/50 text-gray-500"
                      }`}
                    >
                      <GatewayIcon className="w-4 h-4" />
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center justify-between">
                        <p
                          className={`text-sm font-medium ${
                            gateway.triggered ? "text-white" : "text-gray-400"
                          }`}
                        >
                          {gateway.name}
                        </p>
                        {gateway.triggered ? (
                          <span className="px-2 py-0.5 text-[10px] bg-red-500/20 text-red-400 rounded">
                            TRIGGERED
                          </span>
                        ) : (
                          <span className="px-2 py-0.5 text-[10px] bg-gray-700/50 text-gray-500 rounded">
                            NOT TRIGGERED
                          </span>
                        )}
                      </div>
                      <p className="text-[10px] text-gray-500 mt-0.5">
                        {gateway.description}
                      </p>

                      {/* Score Details */}
                      {gateway.triggerScore !== undefined && (
                        <div className="mt-2 pt-2 border-t border-gray-700/50">
                          <div className="flex items-center justify-between text-xs">
                            <span className="text-gray-500">Score:</span>
                            <span
                              className={
                                gateway.triggered ? "text-red-400 font-medium" : "text-gray-400"
                              }
                            >
                              {gateway.triggerScore}
                              <span className="text-gray-500 text-[10px] ml-1">
                                (threshold: {gateway.triggerThreshold})
                              </span>
                            </span>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Explanation */}
          {processedGateways.triggeredCount > 0 && (
            <div className="p-3 bg-amber-500/10 border border-amber-500/30 rounded-lg">
              <p className="text-xs text-amber-400">
                Triggered gateways indicate areas requiring clinical attention. Consider adding
                appropriate expansion modules and interventions based on these findings.
              </p>
            </div>
          )}
        </div>
      ) : (
        <div className="text-center py-6 text-gray-500">
          <Shield className="w-8 h-8 mx-auto mb-2 opacity-50" />
          <p className="text-sm">Unable to load gateway analysis</p>
        </div>
      )}
    </ReviewSection>
  );
}
