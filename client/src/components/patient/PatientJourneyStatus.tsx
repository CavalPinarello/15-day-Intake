"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState } from "react";
import {
  Calendar,
  Search,
  FileText,
  Star,
  ChevronRight,
  CheckCircle2,
  Clock,
  Loader2,
  ArrowRight,
  Sparkles,
} from "lucide-react";

interface PatientJourneyStatusProps {
  userId: Id<"users">;
}

const phaseConfig = {
  intake: {
    label: "Data Collection",
    color: "bg-blue-500/20 text-blue-400 border-blue-500/30",
    icon: Calendar,
  },
  analysis: {
    label: "Analysis",
    color: "bg-amber-500/20 text-amber-400 border-amber-500/30",
    icon: Search,
  },
  treatment_pending: {
    label: "Treatment Pending",
    color: "bg-purple-500/20 text-purple-400 border-purple-500/30",
    icon: FileText,
  },
  treatment_active: {
    label: "Treatment Active",
    color: "bg-green-500/20 text-green-400 border-green-500/30",
    icon: Star,
  },
};

const stageConfig = [
  { id: 1, title: "Data collected", icon: CheckCircle2, description: "14 days of sleep data ready" },
  { id: 2, title: "Patterns identified", icon: Search, description: "Reviewing sleep patterns" },
  { id: 3, title: "Recommendations preparing", icon: FileText, description: "Creating treatment plan" },
  { id: 4, title: "Treatment plan ready!", icon: Star, description: "Ready for patient" },
];

export function PatientJourneyStatus({ userId }: PatientJourneyStatusProps) {
  const journeyStatus = useQuery(api.journey.getJourneyStatus, { userId });
  const analysisProgress = useQuery(api.journey.getAnalysisProgress, { userId });
  const advanceStage = useMutation(api.journey.advanceAnalysisStage);
  const transitionToTreatment = useMutation(api.journey.transitionToTreatment);

  const [isAdvancing, setIsAdvancing] = useState(false);
  const [isActivating, setIsActivating] = useState(false);

  if (!journeyStatus) {
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

  const { phase, analysisStage, intakeCompletedAt, treatmentActivatedAt } = journeyStatus;
  const currentPhase = phaseConfig[phase as keyof typeof phaseConfig] || phaseConfig.intake;
  const PhaseIcon = currentPhase.icon;

  const handleAdvanceStage = async () => {
    if (!analysisStage || analysisStage >= 4) return;
    setIsAdvancing(true);
    try {
      await advanceStage({ userId, newStage: analysisStage + 1 });
    } catch (error) {
      console.error("Failed to advance stage:", error);
    }
    setIsAdvancing(false);
  };

  const handleActivateTreatment = async () => {
    setIsActivating(true);
    try {
      await transitionToTreatment({ userId });
    } catch (error) {
      console.error("Failed to activate treatment:", error);
    }
    setIsActivating(false);
  };

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-indigo-500/20 to-purple-500/20 flex items-center justify-center">
            <PhaseIcon className="w-4 h-4 text-indigo-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Journey Status</h3>
            <p className="text-xs text-gray-500">Patient progression</p>
          </div>
        </div>
        {/* Phase Badge */}
        <div className={`px-3 py-1.5 rounded-full border text-xs font-medium ${currentPhase.color}`}>
          {currentPhase.label}
        </div>
      </div>

      {/* Analysis Timeline (only shown during analysis phase) */}
      {phase === "analysis" && analysisProgress && (
        <div className="mb-4">
          <div className="flex items-center gap-1.5 text-xs text-gray-400 mb-3">
            <Clock className="w-3 h-3" />
            <span>Analysis Progress</span>
          </div>

          <div className="space-y-0">
            {stageConfig.map((stage, index) => {
              const isComplete = analysisStage ? stage.id < analysisStage : false;
              const isCurrent = analysisStage === stage.id;
              const StageIcon = stage.icon;

              return (
                <div key={stage.id} className="flex items-start gap-3">
                  {/* Timeline connector */}
                  <div className="flex flex-col items-center">
                    <div
                      className={`w-8 h-8 rounded-full flex items-center justify-center ${
                        isComplete
                          ? "bg-green-500/20"
                          : isCurrent
                          ? "bg-amber-500/20 ring-2 ring-amber-500/50"
                          : "bg-gray-700/30"
                      }`}
                    >
                      {isComplete ? (
                        <CheckCircle2 className="w-4 h-4 text-green-400" />
                      ) : (
                        <StageIcon
                          className={`w-4 h-4 ${
                            isCurrent ? "text-amber-400" : "text-gray-500"
                          }`}
                        />
                      )}
                    </div>
                    {index < stageConfig.length - 1 && (
                      <div
                        className={`w-0.5 h-8 ${
                          isComplete ? "bg-green-500/50" : "bg-gray-700"
                        }`}
                      />
                    )}
                  </div>

                  {/* Stage content */}
                  <div className="flex-1 pb-4">
                    <div className="flex items-center gap-2">
                      <span
                        className={`text-sm font-medium ${
                          isComplete
                            ? "text-gray-400 line-through"
                            : isCurrent
                            ? "text-white"
                            : "text-gray-500"
                        }`}
                      >
                        {stage.title}
                      </span>
                      {isCurrent && (
                        <span className="px-1.5 py-0.5 bg-amber-500/20 text-amber-400 text-xs rounded">
                          Current
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-gray-500 mt-0.5">{stage.description}</p>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Advance Stage Button */}
          {analysisStage && analysisStage < 4 && (
            <button
              onClick={handleAdvanceStage}
              disabled={isAdvancing}
              className="w-full mt-2 flex items-center justify-center gap-2 px-4 py-2.5 bg-amber-500/20 hover:bg-amber-500/30 text-amber-400 rounded-lg transition-colors disabled:opacity-50"
            >
              {isAdvancing ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <>
                  <ArrowRight className="w-4 h-4" />
                  <span className="text-sm font-medium">Advance to Stage {analysisStage + 1}</span>
                </>
              )}
            </button>
          )}

          {/* Treatment Ready - Activate Button */}
          {analysisStage === 4 && phase === "analysis" && (
            <button
              onClick={handleActivateTreatment}
              disabled={isActivating}
              className="w-full mt-2 flex items-center justify-center gap-2 px-4 py-2.5 bg-green-500/20 hover:bg-green-500/30 text-green-400 rounded-lg transition-colors disabled:opacity-50"
            >
              {isActivating ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <>
                  <Sparkles className="w-4 h-4" />
                  <span className="text-sm font-medium">Activate Treatment Plan</span>
                </>
              )}
            </button>
          )}
        </div>
      )}

      {/* Intake Phase Info */}
      {phase === "intake" && (
        <div className="bg-blue-500/10 rounded-lg p-3 mb-4">
          <div className="flex items-start gap-2">
            <Calendar className="w-4 h-4 text-blue-400 mt-0.5" />
            <div>
              <p className="text-sm text-blue-400 font-medium">14-Day Data Collection</p>
              <p className="text-xs text-gray-400 mt-1">
                Patient is currently completing daily sleep logs and questionnaires.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Treatment Active Info */}
      {(phase === "treatment_active" || phase === "treatment_pending") && (
        <div className="bg-green-500/10 rounded-lg p-3 mb-4">
          <div className="flex items-start gap-2">
            <Star className="w-4 h-4 text-green-400 mt-0.5" />
            <div>
              <p className="text-sm text-green-400 font-medium">Treatment Plan Active</p>
              <p className="text-xs text-gray-400 mt-1">
                Patient is following their personalized intervention plan.
              </p>
              {treatmentActivatedAt && (
                <p className="text-xs text-gray-500 mt-2">
                  Started: {new Date(treatmentActivatedAt).toLocaleDateString()}
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Timestamps */}
      <div className="flex flex-col gap-1 text-xs text-gray-500 border-t border-gray-700/50 pt-3">
        {intakeCompletedAt && (
          <div className="flex items-center justify-between">
            <span>Intake completed</span>
            <span className="text-gray-400">
              {new Date(intakeCompletedAt).toLocaleDateString()}
            </span>
          </div>
        )}
        {treatmentActivatedAt && (
          <div className="flex items-center justify-between">
            <span>Treatment started</span>
            <span className="text-gray-400">
              {new Date(treatmentActivatedAt).toLocaleDateString()}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
