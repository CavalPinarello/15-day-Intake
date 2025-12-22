"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState, useEffect } from "react";
import {
  CheckCircle2,
  Search,
  FileText,
  Star,
  ChevronDown,
  ChevronUp,
  Loader2,
  ArrowRight,
  Sparkles,
  AlertCircle,
  Brain,
  ListChecks,
  FileCheck,
  Stethoscope,
  ClipboardCheck,
  Save,
  ArrowUpRight,
} from "lucide-react";
import Link from "next/link";

interface PatientAnalysisWorkflowProps {
  userId: Id<"users">;
  patientId: string;
  onAiAnalysisRun?: () => void;
}

const stageConfig = [
  {
    stage: 1,
    title: "Data Collected",
    icon: CheckCircle2,
    description: "14 days of sleep data ready for analysis",
    color: "green",
  },
  {
    stage: 2,
    title: "Patterns Identified",
    icon: Search,
    description: "Review data, identify patterns, document findings",
    color: "amber",
  },
  {
    stage: 3,
    title: "Recommendations Preparing",
    icon: FileText,
    description: "Assign interventions and create treatment plan",
    color: "purple",
  },
  {
    stage: 4,
    title: "Treatment Plan Ready",
    icon: Star,
    description: "Finalize and deliver to patient",
    color: "emerald",
  },
];

export function PatientAnalysisWorkflow({
  userId,
  patientId,
  onAiAnalysisRun,
}: PatientAnalysisWorkflowProps) {
  // Queries
  const journeyStatus = useQuery(api.journey.getJourneyStatus, { userId });
  const workflow = useQuery(api.journey.getAnalysisWorkflow, { userId });
  const readiness = useQuery(api.journey.getWorkflowReadiness, { userId });
  const interventions = useQuery(api.physician.getPatientInterventions, { userId });

  // Mutations
  const advanceStage = useMutation(api.journey.advanceAnalysisStage);
  const updateChecklist = useMutation(api.journey.updateWorkflowChecklist);
  const savePatterns = useMutation(api.journey.savePatternFindings);
  const saveRecommendations = useMutation(api.journey.saveRecommendations);
  const finalizePlan = useMutation(api.journey.finalizeTreatmentPlan);
  const transitionToTreatment = useMutation(api.journey.transitionToTreatment);

  // UI State
  const [expandedStage, setExpandedStage] = useState<number | null>(null);
  const [isAdvancing, setIsAdvancing] = useState(false);
  const [isActivating, setIsActivating] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  // Form states for Stage 2
  const [patternsIdentified, setPatternsIdentified] = useState<string[]>([]);
  const [primaryIssues, setPrimaryIssues] = useState<string[]>([]);
  const [riskFactors, setRiskFactors] = useState<string[]>([]);
  const [patternsNotes, setPatternsNotes] = useState("");

  // Form states for Stage 3
  const [treatmentApproach, setTreatmentApproach] = useState("");
  const [estimatedWeeks, setEstimatedWeeks] = useState<number | undefined>();
  const [recommendationsNotes, setRecommendationsNotes] = useState("");

  // Form states for Stage 4
  const [planSummary, setPlanSummary] = useState("");
  const [specialConsiderations, setSpecialConsiderations] = useState("");
  const [finalNotes, setFinalNotes] = useState("");

  // Load existing workflow data into forms
  useEffect(() => {
    if (workflow) {
      setPatternsIdentified(workflow.patternsIdentified);
      setPrimaryIssues(workflow.primarySleepIssues);
      setRiskFactors(workflow.riskFactors);
      setPatternsNotes(workflow.patternsNotes || "");
      setTreatmentApproach(workflow.treatmentApproach || "");
      setEstimatedWeeks(workflow.estimatedDurationWeeks);
      setRecommendationsNotes(workflow.recommendationsNotes || "");
      setPlanSummary(workflow.planSummary || "");
      setSpecialConsiderations(workflow.specialConsiderations || "");
      setFinalNotes(workflow.finalReviewNotes || "");
    }
  }, [workflow]);

  // Auto-expand current stage
  useEffect(() => {
    if (journeyStatus?.analysisStage && expandedStage === null) {
      setExpandedStage(journeyStatus.analysisStage);
    }
  }, [journeyStatus?.analysisStage, expandedStage]);

  if (!journeyStatus || !workflow || !readiness) {
    return (
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-6 animate-pulse">
        <div className="h-6 bg-gray-700 rounded w-1/3 mb-4"></div>
        <div className="space-y-3">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="h-16 bg-gray-700 rounded"></div>
          ))}
        </div>
      </div>
    );
  }

  const { phase, analysisStage } = journeyStatus;
  const currentStage = analysisStage ?? 1;

  // Don't show if not in analysis phase
  if (phase !== "analysis") {
    return null;
  }

  const handleChecklistUpdate = async (item: string, checked: boolean) => {
    const updates: Record<string, boolean> = {};
    if (item === "sleep_data") updates.reviewedSleepData = checked;
    if (item === "scores") updates.reviewedQuestionnaireScores = checked;
    if (item === "gateways") updates.reviewedGatewayTriggers = checked;
    if (item === "ai_analysis") {
      updates.ranAiAnalysis = checked;
      if (checked && onAiAnalysisRun) onAiAnalysisRun();
    }
    await updateChecklist({ userId, ...updates });
  };

  const handleSavePatterns = async (markComplete: boolean) => {
    setIsSaving(true);
    try {
      await savePatterns({
        userId,
        patternsIdentified,
        primarySleepIssues: primaryIssues,
        triggeredGateways: workflow.triggeredGateways,
        riskFactors,
        notes: patternsNotes,
        markComplete,
      });
    } finally {
      setIsSaving(false);
    }
  };

  const handleSaveRecommendations = async (markComplete: boolean) => {
    setIsSaving(true);
    try {
      const interventionIds = interventions?.map((i) => i._id) || [];
      await saveRecommendations({
        userId,
        recommendedInterventions: interventionIds,
        treatmentApproach,
        estimatedDurationWeeks: estimatedWeeks,
        notes: recommendationsNotes,
        markComplete,
      });
    } finally {
      setIsSaving(false);
    }
  };

  const handleFinalizePlan = async () => {
    setIsSaving(true);
    try {
      await finalizePlan({
        userId,
        planSummary,
        specialConsiderations: specialConsiderations || undefined,
        finalReviewNotes: finalNotes || undefined,
      });
    } finally {
      setIsSaving(false);
    }
  };

  const handleAdvanceStage = async (targetStage: number) => {
    setIsAdvancing(true);
    try {
      await advanceStage({ userId, newStage: targetStage });
      setExpandedStage(targetStage);
    } finally {
      setIsAdvancing(false);
    }
  };

  const handleActivateTreatment = async () => {
    setIsActivating(true);
    try {
      await transitionToTreatment({ userId });
    } finally {
      setIsActivating(false);
    }
  };

  const getStageStatus = (stage: number) => {
    if (stage < currentStage) return "complete";
    if (stage === currentStage) return "current";
    return "pending";
  };

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-amber-500/20 to-orange-500/20 flex items-center justify-center">
            <Stethoscope className="w-5 h-5 text-amber-400" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-white">Analysis Workflow</h3>
            <p className="text-sm text-gray-400">Track your progress reviewing this patient</p>
          </div>
        </div>
        <div className="px-3 py-1.5 rounded-full bg-amber-500/20 border border-amber-500/30">
          <span className="text-sm font-medium text-amber-400">
            Stage {currentStage} of 4
          </span>
        </div>
      </div>

      {/* Timeline */}
      <div className="space-y-3">
        {stageConfig.map((stage) => {
          const status = getStageStatus(stage.stage);
          const StageIcon = stage.icon;
          const isExpanded = expandedStage === stage.stage;
          const requirements =
            stage.stage === 2
              ? readiness.stage2Requirements
              : stage.stage === 3
              ? readiness.stage3Requirements
              : stage.stage === 4
              ? readiness.stage4Requirements
              : [];

          return (
            <div key={stage.stage} className="relative">
              {/* Stage Header */}
              <button
                onClick={() => setExpandedStage(isExpanded ? null : stage.stage)}
                className={`w-full flex items-center gap-4 p-4 rounded-xl transition-all ${
                  status === "current"
                    ? "bg-amber-500/10 border border-amber-500/30"
                    : status === "complete"
                    ? "bg-green-500/10 border border-green-500/30"
                    : "bg-gray-700/30 border border-gray-700/50"
                }`}
              >
                {/* Stage Icon */}
                <div
                  className={`w-10 h-10 rounded-full flex items-center justify-center ${
                    status === "complete"
                      ? "bg-green-500/20"
                      : status === "current"
                      ? "bg-amber-500/20 ring-2 ring-amber-500/50"
                      : "bg-gray-700/50"
                  }`}
                >
                  {status === "complete" ? (
                    <CheckCircle2 className="w-5 h-5 text-green-400" />
                  ) : (
                    <StageIcon
                      className={`w-5 h-5 ${
                        status === "current" ? "text-amber-400" : "text-gray-500"
                      }`}
                    />
                  )}
                </div>

                {/* Stage Info */}
                <div className="flex-1 text-left">
                  <div className="flex items-center gap-2">
                    <span
                      className={`font-medium ${
                        status === "complete"
                          ? "text-gray-400"
                          : status === "current"
                          ? "text-white"
                          : "text-gray-500"
                      }`}
                    >
                      {stage.title}
                    </span>
                    {status === "current" && (
                      <span className="px-2 py-0.5 text-xs font-medium bg-amber-500/20 text-amber-400 rounded">
                        Current
                      </span>
                    )}
                    {status === "complete" && (
                      <span className="px-2 py-0.5 text-xs font-medium bg-green-500/20 text-green-400 rounded">
                        Complete
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-gray-500 mt-0.5">{stage.description}</p>
                </div>

                {/* Expand/Collapse */}
                <div className="text-gray-500">
                  {isExpanded ? (
                    <ChevronUp className="w-5 h-5" />
                  ) : (
                    <ChevronDown className="w-5 h-5" />
                  )}
                </div>
              </button>

              {/* Expanded Content */}
              {isExpanded && (
                <div className="mt-3 ml-14 p-4 bg-gray-900/50 rounded-xl border border-gray-700/50">
                  {/* Stage 1: Data Collected */}
                  {stage.stage === 1 && (
                    <div className="space-y-4">
                      <div className="flex items-center gap-2 text-green-400">
                        <CheckCircle2 className="w-5 h-5" />
                        <span className="font-medium">Data collection complete</span>
                      </div>
                      <p className="text-sm text-gray-400">
                        The patient has completed their 14-day intake journey. All sleep logs and
                        questionnaires have been submitted and are ready for your review.
                      </p>
                      {currentStage === 1 && (
                        <button
                          onClick={() => handleAdvanceStage(2)}
                          disabled={isAdvancing}
                          className="flex items-center gap-2 px-4 py-2 bg-amber-500/20 hover:bg-amber-500/30 text-amber-400 rounded-lg transition-colors"
                        >
                          {isAdvancing ? (
                            <Loader2 className="w-4 h-4 animate-spin" />
                          ) : (
                            <ArrowRight className="w-4 h-4" />
                          )}
                          <span>Begin Analysis</span>
                        </button>
                      )}
                    </div>
                  )}

                  {/* Stage 2: Pattern Identification */}
                  {stage.stage === 2 && (
                    <div className="space-y-6">
                      {/* Review Checklist */}
                      <div>
                        <h4 className="text-sm font-medium text-white flex items-center gap-2 mb-3">
                          <ListChecks className="w-4 h-4 text-amber-400" />
                          Review Checklist
                        </h4>
                        <div className="space-y-2">
                          {requirements.map((req) => (
                            <label
                              key={req.id}
                              className="flex items-center gap-3 p-2 rounded-lg hover:bg-gray-800/50 cursor-pointer"
                            >
                              <input
                                type="checkbox"
                                checked={req.complete}
                                onChange={(e) =>
                                  handleChecklistUpdate(req.id, e.target.checked)
                                }
                                className="w-4 h-4 rounded border-gray-600 bg-gray-700 text-amber-500 focus:ring-amber-500"
                              />
                              <span
                                className={`text-sm ${
                                  req.complete ? "text-gray-400 line-through" : "text-gray-300"
                                }`}
                              >
                                {req.label}
                              </span>
                              {req.required && !req.complete && (
                                <span className="text-xs text-red-400">Required</span>
                              )}
                              {req.id === "ai_analysis" && !req.complete && (
                                <button
                                  onClick={() => {
                                    handleChecklistUpdate("ai_analysis", true);
                                  }}
                                  className="ml-auto flex items-center gap-1 px-2 py-1 text-xs bg-purple-500/20 text-purple-400 rounded hover:bg-purple-500/30"
                                >
                                  <Brain className="w-3 h-3" />
                                  Run Analysis
                                </button>
                              )}
                            </label>
                          ))}
                        </div>
                      </div>

                      {/* Findings Documentation */}
                      <div>
                        <h4 className="text-sm font-medium text-white flex items-center gap-2 mb-3">
                          <FileCheck className="w-4 h-4 text-amber-400" />
                          Document Findings
                        </h4>

                        {/* Patterns Identified */}
                        <div className="mb-4">
                          <label className="block text-xs text-gray-400 mb-1">
                            Patterns Identified
                          </label>
                          <textarea
                            value={patternsIdentified.join("\n")}
                            onChange={(e) =>
                              setPatternsIdentified(
                                e.target.value.split("\n").filter((s) => s.trim())
                              )
                            }
                            placeholder="Enter one pattern per line..."
                            rows={3}
                            className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-amber-500"
                          />
                        </div>

                        {/* Primary Issues */}
                        <div className="mb-4">
                          <label className="block text-xs text-gray-400 mb-1">
                            Primary Sleep Issues
                          </label>
                          <textarea
                            value={primaryIssues.join("\n")}
                            onChange={(e) =>
                              setPrimaryIssues(
                                e.target.value.split("\n").filter((s) => s.trim())
                              )
                            }
                            placeholder="Enter one issue per line..."
                            rows={2}
                            className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-amber-500"
                          />
                        </div>

                        {/* Risk Factors */}
                        <div className="mb-4">
                          <label className="block text-xs text-gray-400 mb-1">
                            Risk Factors
                          </label>
                          <textarea
                            value={riskFactors.join("\n")}
                            onChange={(e) =>
                              setRiskFactors(
                                e.target.value.split("\n").filter((s) => s.trim())
                              )
                            }
                            placeholder="Enter one risk factor per line..."
                            rows={2}
                            className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-amber-500"
                          />
                        </div>

                        {/* Notes */}
                        <div className="mb-4">
                          <label className="block text-xs text-gray-400 mb-1">
                            Additional Notes
                          </label>
                          <textarea
                            value={patternsNotes}
                            onChange={(e) => setPatternsNotes(e.target.value)}
                            placeholder="Any additional observations..."
                            rows={2}
                            className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-amber-500"
                          />
                        </div>

                        {/* Actions */}
                        <div className="flex items-center gap-3">
                          <button
                            onClick={() => handleSavePatterns(false)}
                            disabled={isSaving}
                            className="flex items-center gap-2 px-3 py-2 bg-gray-700 hover:bg-gray-600 text-gray-300 rounded-lg text-sm transition-colors"
                          >
                            {isSaving ? (
                              <Loader2 className="w-4 h-4 animate-spin" />
                            ) : (
                              <Save className="w-4 h-4" />
                            )}
                            Save Draft
                          </button>
                          {currentStage === 2 && (
                            <button
                              onClick={async () => {
                                await handleSavePatterns(true);
                                if (readiness.stage2Ready) {
                                  handleAdvanceStage(3);
                                }
                              }}
                              disabled={isSaving || !readiness.stage2Ready}
                              className="flex items-center gap-2 px-4 py-2 bg-amber-500/20 hover:bg-amber-500/30 text-amber-400 rounded-lg text-sm transition-colors disabled:opacity-50"
                            >
                              {isAdvancing ? (
                                <Loader2 className="w-4 h-4 animate-spin" />
                              ) : (
                                <ArrowRight className="w-4 h-4" />
                              )}
                              Complete & Advance
                            </button>
                          )}
                        </div>
                        {!readiness.stage2Ready && currentStage === 2 && (
                          <p className="text-xs text-amber-400 mt-2 flex items-center gap-1">
                            <AlertCircle className="w-3 h-3" />
                            Complete all required items to advance
                          </p>
                        )}
                      </div>
                    </div>
                  )}

                  {/* Stage 3: Recommendations */}
                  {stage.stage === 3 && (
                    <div className="space-y-6">
                      {/* Requirements Checklist */}
                      <div>
                        <h4 className="text-sm font-medium text-white flex items-center gap-2 mb-3">
                          <ClipboardCheck className="w-4 h-4 text-purple-400" />
                          Preparation Checklist
                        </h4>
                        <div className="space-y-2">
                          {requirements.map((req) => (
                            <div
                              key={req.id}
                              className="flex items-center gap-3 p-2 rounded-lg"
                            >
                              {req.complete ? (
                                <CheckCircle2 className="w-4 h-4 text-green-400" />
                              ) : (
                                <div className="w-4 h-4 rounded-full border-2 border-gray-600" />
                              )}
                              <span
                                className={`text-sm ${
                                  req.complete ? "text-gray-400" : "text-gray-300"
                                }`}
                              >
                                {req.label}
                              </span>
                              {req.id === "interventions" && !req.complete && (
                                <Link
                                  href={`/physician-dashboard/patient/${patientId}/prescription`}
                                  className="ml-auto flex items-center gap-1 px-2 py-1 text-xs bg-purple-500/20 text-purple-400 rounded hover:bg-purple-500/30"
                                >
                                  <Sparkles className="w-3 h-3" />
                                  Prescribe
                                  <ArrowUpRight className="w-3 h-3" />
                                </Link>
                              )}
                            </div>
                          ))}
                        </div>
                      </div>

                      {/* Assigned Interventions */}
                      {interventions && interventions.length > 0 && (
                        <div>
                          <h4 className="text-sm font-medium text-white mb-2">
                            Assigned Interventions ({interventions.length})
                          </h4>
                          <div className="flex flex-wrap gap-2">
                            {interventions.map((intervention) => (
                              <span
                                key={intervention._id}
                                className="px-2 py-1 text-xs bg-purple-500/20 text-purple-300 rounded"
                              >
                                {intervention.intervention_name}
                              </span>
                            ))}
                          </div>
                        </div>
                      )}

                      {/* Treatment Approach */}
                      <div>
                        <label className="block text-xs text-gray-400 mb-1">
                          Treatment Approach
                        </label>
                        <select
                          value={treatmentApproach}
                          onChange={(e) => setTreatmentApproach(e.target.value)}
                          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                        >
                          <option value="">Select approach...</option>
                          <option value="cbt-i">CBT-I (Cognitive Behavioral Therapy for Insomnia)</option>
                          <option value="sleep_restriction">Sleep Restriction Therapy</option>
                          <option value="stimulus_control">Stimulus Control</option>
                          <option value="relaxation">Relaxation Training</option>
                          <option value="cpap">CPAP Therapy</option>
                          <option value="medication">Pharmacological Intervention</option>
                          <option value="combined">Combined Approach</option>
                          <option value="other">Other</option>
                        </select>
                      </div>

                      {/* Estimated Duration */}
                      <div>
                        <label className="block text-xs text-gray-400 mb-1">
                          Estimated Duration (weeks)
                        </label>
                        <input
                          type="number"
                          value={estimatedWeeks || ""}
                          onChange={(e) =>
                            setEstimatedWeeks(e.target.value ? parseInt(e.target.value) : undefined)
                          }
                          placeholder="e.g., 8"
                          min={1}
                          max={52}
                          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500"
                        />
                      </div>

                      {/* Notes */}
                      <div>
                        <label className="block text-xs text-gray-400 mb-1">
                          Recommendation Notes
                        </label>
                        <textarea
                          value={recommendationsNotes}
                          onChange={(e) => setRecommendationsNotes(e.target.value)}
                          placeholder="Notes about the treatment plan..."
                          rows={2}
                          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500"
                        />
                      </div>

                      {/* Actions */}
                      <div className="flex items-center gap-3">
                        <button
                          onClick={() => handleSaveRecommendations(false)}
                          disabled={isSaving}
                          className="flex items-center gap-2 px-3 py-2 bg-gray-700 hover:bg-gray-600 text-gray-300 rounded-lg text-sm transition-colors"
                        >
                          {isSaving ? (
                            <Loader2 className="w-4 h-4 animate-spin" />
                          ) : (
                            <Save className="w-4 h-4" />
                          )}
                          Save Draft
                        </button>
                        {currentStage === 3 && (
                          <button
                            onClick={async () => {
                              await handleSaveRecommendations(true);
                              if (readiness.stage3Ready) {
                                handleAdvanceStage(4);
                              }
                            }}
                            disabled={isSaving || !readiness.stage3Ready}
                            className="flex items-center gap-2 px-4 py-2 bg-purple-500/20 hover:bg-purple-500/30 text-purple-400 rounded-lg text-sm transition-colors disabled:opacity-50"
                          >
                            {isAdvancing ? (
                              <Loader2 className="w-4 h-4 animate-spin" />
                            ) : (
                              <ArrowRight className="w-4 h-4" />
                            )}
                            Complete & Advance
                          </button>
                        )}
                      </div>
                    </div>
                  )}

                  {/* Stage 4: Treatment Ready */}
                  {stage.stage === 4 && (
                    <div className="space-y-6">
                      {/* Patient Summary */}
                      <div>
                        <label className="block text-xs text-gray-400 mb-1">
                          Patient Summary (visible to patient)
                        </label>
                        <textarea
                          value={planSummary}
                          onChange={(e) => setPlanSummary(e.target.value)}
                          placeholder="Write a summary the patient will see..."
                          rows={3}
                          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                        />
                      </div>

                      {/* Special Considerations */}
                      <div>
                        <label className="block text-xs text-gray-400 mb-1">
                          Special Considerations (optional)
                        </label>
                        <textarea
                          value={specialConsiderations}
                          onChange={(e) => setSpecialConsiderations(e.target.value)}
                          placeholder="Any special considerations for this patient..."
                          rows={2}
                          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                        />
                      </div>

                      {/* Final Notes */}
                      <div>
                        <label className="block text-xs text-gray-400 mb-1">
                          Final Review Notes (internal)
                        </label>
                        <textarea
                          value={finalNotes}
                          onChange={(e) => setFinalNotes(e.target.value)}
                          placeholder="Internal notes for the team..."
                          rows={2}
                          className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                        />
                      </div>

                      {/* Actions */}
                      <div className="flex items-center gap-3">
                        <button
                          onClick={handleFinalizePlan}
                          disabled={isSaving || !planSummary.trim()}
                          className="flex items-center gap-2 px-3 py-2 bg-gray-700 hover:bg-gray-600 text-gray-300 rounded-lg text-sm transition-colors disabled:opacity-50"
                        >
                          {isSaving ? (
                            <Loader2 className="w-4 h-4 animate-spin" />
                          ) : (
                            <Save className="w-4 h-4" />
                          )}
                          Save
                        </button>
                        {currentStage === 4 && workflow.readyForPatient && (
                          <button
                            onClick={handleActivateTreatment}
                            disabled={isActivating}
                            className="flex items-center gap-2 px-4 py-2 bg-emerald-500/20 hover:bg-emerald-500/30 text-emerald-400 rounded-lg text-sm transition-colors"
                          >
                            {isActivating ? (
                              <Loader2 className="w-4 h-4 animate-spin" />
                            ) : (
                              <Sparkles className="w-4 h-4" />
                            )}
                            Activate Treatment Plan
                          </button>
                        )}
                      </div>
                      {currentStage === 4 && !workflow.readyForPatient && (
                        <p className="text-xs text-amber-400 flex items-center gap-1">
                          <AlertCircle className="w-3 h-3" />
                          Save the patient summary to enable activation
                        </p>
                      )}
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Completion Badge */}
      {phase === "treatment_active" && (
        <div className="mt-6 p-4 bg-emerald-500/10 rounded-xl border border-emerald-500/30">
          <div className="flex items-center gap-3">
            <Sparkles className="w-6 h-6 text-emerald-400" />
            <div>
              <p className="text-emerald-400 font-medium">Treatment Plan Active</p>
              <p className="text-sm text-gray-400">
                The patient can now see their personalized treatment plan
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
