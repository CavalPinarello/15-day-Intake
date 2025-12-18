"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import Link from "next/link";
import { useState, useEffect, useMemo } from "react";
import { useParams, useRouter } from "next/navigation";
import { PhysicianLogoutButton } from "@/components/PhysicianAuthGuard";
import { InterventionLibrary } from "@/components/physician";
import {
  ArrowLeft,
  Pill,
  Plus,
  Trash2,
  Save,
  Send,
  Clock,
  Calendar,
  Users,
  ClipboardList,
  Settings,
  CheckCircle,
  Search,
  X,
  Edit2,
  ChevronUp,
  ChevronDown,
  Play,
  Sparkles,
  AlertTriangle,
  FileText,
  Package,
  Target,
  Info,
  GripVertical,
} from "lucide-react";
import { ZoeLogo } from "@/components/ZoeLogo";

interface DraftIntervention {
  intervention_id: Id<"interventions">;
  intervention_string_id: string;
  name: string;
  category: string;
  startDate: string;
  endDate: string;
  frequency: string;
  timing: string;
  specificTime: string;
  dosage: string;
  customInstructions: string;
  priority: number;
  why_it_works?: string;
  instructions_text?: string;
}

const frequencyOptions = [
  { value: "daily", label: "Daily" },
  { value: "twice_daily", label: "Twice Daily" },
  { value: "weekly", label: "Weekly" },
  { value: "as_needed", label: "As Needed" },
  { value: "weekdays", label: "Weekdays Only" },
];

const timingOptions = [
  { value: "morning", label: "Morning" },
  { value: "midday", label: "Midday" },
  { value: "afternoon", label: "Afternoon" },
  { value: "evening", label: "Evening" },
  { value: "pre_bed", label: "Before Bed" },
  { value: "post_meal", label: "After Meals" },
];

export default function PrescriptionPage() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;
  const userId = id as Id<"users">;

  const [draftInterventions, setDraftInterventions] = useState<DraftIntervention[]>([]);
  const [editingIndex, setEditingIndex] = useState<number | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showConfirmation, setShowConfirmation] = useState(false);

  // Queries
  const patient = useQuery(api.physician.getPatientDetails, { userId });
  const interventions = useQuery(api.interventionLibrary.getAllInterventions, {});
  const existingInterventions = useQuery(api.physician.getPatientInterventions, { userId });
  const suggestions = useQuery(api.interventionLibrary.getSuggestedInterventions, { userId });

  // Mutations
  const assignIntervention = useMutation(api.interventionLibrary.assignIntervention);
  const activateInterventions = useMutation(api.interventionLibrary.activatePatientInterventions);
  const updateStatus = useMutation(api.physician.updatePatientReviewStatus);

  // Default dates
  const today = new Date().toISOString().split("T")[0];
  const fourWeeksLater = new Date(Date.now() + 28 * 24 * 60 * 60 * 1000)
    .toISOString()
    .split("T")[0];

  // Get selected intervention IDs for library
  const selectedIds = useMemo(
    () => draftInterventions.map((d) => d.intervention_id),
    [draftInterventions]
  );

  // Handle intervention selection from library
  const handleInterventionSelect = (interventionId: Id<"interventions">) => {
    // Check if already in draft
    const existingIndex = draftInterventions.findIndex(
      (d) => d.intervention_id === interventionId
    );

    if (existingIndex >= 0) {
      // Remove from draft
      setDraftInterventions((prev) => prev.filter((_, i) => i !== existingIndex));
      if (editingIndex === existingIndex) setEditingIndex(null);
    } else {
      // Find the intervention details
      const intervention = interventions?.find((i) => i._id === interventionId);
      if (!intervention) return;

      const newDraft: DraftIntervention = {
        intervention_id: interventionId,
        intervention_string_id: intervention.intervention_id,
        name: intervention.short_name || intervention.name,
        category: intervention.category,
        startDate: today,
        endDate: fourWeeksLater,
        frequency: intervention.default_frequency || "daily",
        timing: intervention.default_timing || "",
        specificTime: "",
        dosage: intervention.default_dosage || "",
        customInstructions: "",
        priority: 3,
        why_it_works: intervention.why_it_works,
        instructions_text: intervention.instructions_text,
      };

      setDraftInterventions((prev) => [...prev, newDraft]);
      setEditingIndex(draftInterventions.length); // Open editor for new item
    }
  };

  // Apply recommended bundle
  const applyBundle = () => {
    if (!suggestions || !interventions) return;

    const topSuggestions = suggestions.suggestedInterventions.slice(0, 8);
    const newDrafts: DraftIntervention[] = [];

    for (const suggestion of topSuggestions) {
      const intervention = interventions.find(
        (i) => i.intervention_id === suggestion.intervention_id
      );
      if (!intervention) continue;

      // Skip if already in drafts
      if (draftInterventions.some((d) => d.intervention_id === intervention._id)) {
        continue;
      }

      newDrafts.push({
        intervention_id: intervention._id,
        intervention_string_id: intervention.intervention_id,
        name: intervention.short_name || intervention.name,
        category: intervention.category,
        startDate: today,
        endDate: fourWeeksLater,
        frequency: intervention.default_frequency || "daily",
        timing: intervention.default_timing || "",
        specificTime: "",
        dosage: intervention.default_dosage || "",
        customInstructions: "",
        priority: suggestion.priority === "high" ? 5 : suggestion.priority === "medium" ? 3 : 2,
        why_it_works: intervention.why_it_works,
        instructions_text: intervention.instructions_text,
      });
    }

    setDraftInterventions((prev) => [...prev, ...newDrafts]);
  };

  // Update draft intervention
  const updateDraft = (index: number, updates: Partial<DraftIntervention>) => {
    setDraftInterventions((prev) =>
      prev.map((d, i) => (i === index ? { ...d, ...updates } : d))
    );
  };

  // Remove draft intervention
  const removeDraft = (index: number) => {
    setDraftInterventions((prev) => prev.filter((_, i) => i !== index));
    if (editingIndex === index) setEditingIndex(null);
  };

  // Move draft up/down
  const moveDraft = (index: number, direction: "up" | "down") => {
    const newIndex = direction === "up" ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= draftInterventions.length) return;

    setDraftInterventions((prev) => {
      const newArr = [...prev];
      [newArr[index], newArr[newIndex]] = [newArr[newIndex], newArr[index]];
      return newArr;
    });
  };

  // Submit all drafts
  const handleSubmit = async () => {
    if (draftInterventions.length === 0) return;
    setIsSubmitting(true);

    try {
      for (const draft of draftInterventions) {
        await assignIntervention({
          userId,
          interventionId: draft.intervention_id,
          startDate: draft.startDate,
          endDate: draft.endDate || undefined,
          frequency: draft.frequency || undefined,
          timing: draft.timing || undefined,
          specificTime: draft.specificTime || undefined,
          dosage: draft.dosage || undefined,
          customInstructions: draft.customInstructions || undefined,
          priority: draft.priority,
        });
      }

      await updateStatus({ userId, status: "interventions_prepared" });
      setShowConfirmation(true);
    } catch (error) {
      console.error("Failed to assign interventions:", error);
      alert("Failed to assign interventions. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  // Activate interventions and start treatment
  const handleActivate = async () => {
    setIsSubmitting(true);
    try {
      const result = await activateInterventions({ userId });
      alert(
        `Treatment activated! ${result.activated} interventions activated, ${result.tasksGenerated} daily tasks generated.`
      );
      router.push(`/physician-dashboard/patient/${id}`);
    } catch (error) {
      console.error("Failed to activate interventions:", error);
      alert("Failed to activate interventions. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!patient) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-2 border-teal-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  const hasDraftInterventions =
    existingInterventions?.some((i) => i.status === "draft") ||
    draftInterventions.length > 0;

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center gap-3">
              <ZoeLogo size={40} />
              <div>
                <h1 className="text-xl font-bold text-gray-900">Zoé Sleep</h1>
                <p className="text-xs text-gray-500">Physician Dashboard</p>
              </div>
            </div>

            <nav className="flex items-center gap-6">
              <Link
                href="/physician-dashboard"
                className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
              >
                <Users className="w-5 h-5" />
                Patients
              </Link>
              <Link
                href="/physician-dashboard/questions"
                className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
              >
                <ClipboardList className="w-5 h-5" />
                Questions
              </Link>
              <Link
                href="/physician-dashboard/settings"
                className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
              >
                <Settings className="w-5 h-5" />
                Settings
              </Link>
              <PhysicianLogoutButton />
            </nav>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        {/* Back Link */}
        <Link
          href={`/physician-dashboard/patient/${id}`}
          className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-4"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to {patient.name || patient.user.username}
        </Link>

        {/* Page Header */}
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-2xl font-bold text-gray-900">
              Prescribe Interventions
            </h2>
            <p className="text-gray-600 mt-1">
              Create a personalized treatment plan for{" "}
              {patient.name || patient.user.username}
            </p>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-sm text-gray-500 mr-2">
              {draftInterventions.length} selected
            </span>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Left Column: Library */}
          <div className="lg:sticky lg:top-24 lg:h-[calc(100vh-140px)] lg:overflow-auto">
            <InterventionLibrary
              userId={userId}
              onInterventionSelect={handleInterventionSelect}
              selectedInterventions={selectedIds}
              showSuggestions={true}
            />
          </div>

          {/* Right Column: Draft & Configuration */}
          <div className="space-y-4">
            {/* AI Recommendation Banner */}
            {suggestions?.suggestedBundle && draftInterventions.length === 0 && (
              <div className="bg-gradient-to-r from-purple-600 to-teal-600 rounded-xl p-4 text-white">
                <div className="flex items-start gap-3">
                  <Sparkles className="w-5 h-5 flex-shrink-0 mt-0.5" />
                  <div className="flex-1">
                    <p className="font-medium">Recommended Bundle</p>
                    <p className="text-sm text-white/80 mt-1">
                      Based on this patient&apos;s profile, we recommend the{" "}
                      <strong>{suggestions.suggestedBundle.name}</strong> bundle.
                    </p>
                    <p className="text-sm text-white/70 mt-1">
                      Goal: {suggestions.suggestedBundle.goal}
                    </p>

                    {/* Patient Profile Tags */}
                    <div className="flex flex-wrap gap-2 mt-3">
                      {suggestions.patientProfile.phenotype && (
                        <span className="text-xs px-2 py-1 bg-white/20 rounded-full">
                          <Target className="w-3 h-3 inline mr-1" />
                          {suggestions.patientProfile.phenotype.replace(/_/g, " ")}
                        </span>
                      )}
                      {suggestions.patientProfile.triggeredGateways
                        .slice(0, 3)
                        .map((gateway) => (
                          <span
                            key={gateway}
                            className="text-xs px-2 py-1 bg-white/20 rounded-full"
                          >
                            <AlertTriangle className="w-3 h-3 inline mr-1" />
                            {gateway.replace(/_/g, " ")}
                          </span>
                        ))}
                    </div>

                    <button
                      onClick={applyBundle}
                      className="mt-4 px-4 py-2 bg-white/20 hover:bg-white/30 rounded-lg text-sm font-medium transition-colors"
                    >
                      Apply {suggestions.suggestedInterventions.length} Recommended
                      Interventions
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* Draft Interventions */}
            <div className="bg-white rounded-xl border border-gray-200 p-4">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
                  <FileText className="w-5 h-5 text-teal-600" />
                  Treatment Plan Draft
                </h3>
                {draftInterventions.length > 0 && (
                  <button
                    onClick={() => {
                      setDraftInterventions([]);
                      setEditingIndex(null);
                    }}
                    className="text-sm text-gray-500 hover:text-red-500"
                  >
                    Clear All
                  </button>
                )}
              </div>

              {draftInterventions.length === 0 ? (
                <div className="text-center py-8 border-2 border-dashed border-gray-200 rounded-xl">
                  <Pill className="w-8 h-8 mx-auto mb-2 text-gray-300" />
                  <p className="text-gray-500">No interventions selected</p>
                  <p className="text-sm text-gray-400 mt-1">
                    Select interventions from the library or apply the recommended
                    bundle
                  </p>
                </div>
              ) : (
                <div className="space-y-3">
                  {draftInterventions.map((draft, index) => (
                    <DraftInterventionCard
                      key={`${draft.intervention_id}-${index}`}
                      draft={draft}
                      index={index}
                      isEditing={editingIndex === index}
                      onEdit={() =>
                        setEditingIndex(editingIndex === index ? null : index)
                      }
                      onUpdate={(updates) => updateDraft(index, updates)}
                      onRemove={() => removeDraft(index)}
                      onMoveUp={() => moveDraft(index, "up")}
                      onMoveDown={() => moveDraft(index, "down")}
                      canMoveUp={index > 0}
                      canMoveDown={index < draftInterventions.length - 1}
                    />
                  ))}
                </div>
              )}

              {/* Submit Button */}
              {draftInterventions.length > 0 && !showConfirmation && (
                <div className="mt-4 pt-4 border-t border-gray-200">
                  <button
                    onClick={handleSubmit}
                    disabled={isSubmitting}
                    className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-teal-600 text-white rounded-lg font-medium hover:bg-teal-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                  >
                    {isSubmitting ? (
                      <>
                        <div className="animate-spin w-4 h-4 border-2 border-white border-t-transparent rounded-full" />
                        Saving...
                      </>
                    ) : (
                      <>
                        <Save className="w-4 h-4" />
                        Save Treatment Plan ({draftInterventions.length} interventions)
                      </>
                    )}
                  </button>
                </div>
              )}

              {/* Confirmation & Activate */}
              {showConfirmation && (
                <div className="mt-4 pt-4 border-t border-gray-200">
                  <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
                    <div className="flex items-center gap-2 text-green-700">
                      <CheckCircle className="w-5 h-5" />
                      <span className="font-medium">Treatment plan saved</span>
                    </div>
                    <p className="text-sm text-green-600 mt-1">
                      Click &quot;Start Treatment&quot; to activate these interventions
                      and generate daily tasks that will appear in the patient&apos;s
                      app.
                    </p>
                  </div>

                  <button
                    onClick={handleActivate}
                    disabled={isSubmitting}
                    className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-purple-600 to-teal-600 text-white rounded-lg font-medium hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed transition-opacity"
                  >
                    {isSubmitting ? (
                      <>
                        <div className="animate-spin w-4 h-4 border-2 border-white border-t-transparent rounded-full" />
                        Activating...
                      </>
                    ) : (
                      <>
                        <Play className="w-4 h-4" />
                        Start Treatment
                      </>
                    )}
                  </button>
                </div>
              )}
            </div>

            {/* Existing Draft Interventions */}
            {existingInterventions?.filter((i) => i.status === "draft").length > 0 && (
              <div className="bg-white rounded-xl border border-amber-200 p-4">
                <h3 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                  <Clock className="w-5 h-5 text-amber-600" />
                  Previously Saved Drafts
                </h3>
                <div className="space-y-2">
                  {existingInterventions
                    ?.filter((i) => i.status === "draft")
                    .map((intervention) => (
                      <div
                        key={intervention._id}
                        className="flex items-center justify-between p-3 bg-amber-50 rounded-lg"
                      >
                        <div>
                          <p className="font-medium text-gray-900">
                            {intervention.intervention_name}
                          </p>
                          <div className="flex items-center gap-2 mt-0.5 text-xs text-gray-500">
                            <span>{intervention.frequency || "Daily"}</span>
                            <span>•</span>
                            <span>{intervention.timing || "Not set"}</span>
                            <span>•</span>
                            <span>Starts {intervention.start_date}</span>
                          </div>
                        </div>
                        <span className="px-2 py-1 bg-amber-100 text-amber-700 rounded text-xs font-medium">
                          Draft
                        </span>
                      </div>
                    ))}
                </div>

                {!showConfirmation && (
                  <button
                    onClick={handleActivate}
                    disabled={isSubmitting}
                    className="mt-3 w-full flex items-center justify-center gap-2 px-4 py-2 bg-amber-600 text-white rounded-lg font-medium hover:bg-amber-700 disabled:opacity-50"
                  >
                    <Play className="w-4 h-4" />
                    Activate Saved Drafts
                  </button>
                )}
              </div>
            )}

            {/* Active Interventions */}
            {existingInterventions?.filter((i) => i.status === "active").length > 0 && (
              <div className="bg-white rounded-xl border border-green-200 p-4">
                <h3 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                  <CheckCircle className="w-5 h-5 text-green-600" />
                  Currently Active
                </h3>
                <div className="space-y-2">
                  {existingInterventions
                    ?.filter((i) => i.status === "active")
                    .map((intervention) => (
                      <div
                        key={intervention._id}
                        className="flex items-center justify-between p-3 bg-green-50 rounded-lg"
                      >
                        <div>
                          <p className="font-medium text-gray-900">
                            {intervention.intervention_name}
                          </p>
                          <div className="flex items-center gap-2 mt-0.5 text-xs text-gray-500">
                            <span>{intervention.frequency || "Daily"}</span>
                            <span>•</span>
                            <span>{intervention.timing || "Not set"}</span>
                          </div>
                        </div>
                        <span className="px-2 py-1 bg-green-100 text-green-700 rounded text-xs font-medium">
                          Active
                        </span>
                      </div>
                    ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}

// Draft Intervention Card Component
function DraftInterventionCard({
  draft,
  index,
  isEditing,
  onEdit,
  onUpdate,
  onRemove,
  onMoveUp,
  onMoveDown,
  canMoveUp,
  canMoveDown,
}: {
  draft: DraftIntervention;
  index: number;
  isEditing: boolean;
  onEdit: () => void;
  onUpdate: (updates: Partial<DraftIntervention>) => void;
  onRemove: () => void;
  onMoveUp: () => void;
  onMoveDown: () => void;
  canMoveUp: boolean;
  canMoveDown: boolean;
}) {
  return (
    <div
      className={`border rounded-lg transition-all ${
        isEditing ? "border-teal-500 bg-teal-50/30" : "border-gray-200"
      }`}
    >
      {/* Card Header */}
      <div className="flex items-center gap-2 p-3">
        <div className="flex flex-col gap-0.5">
          <button
            onClick={onMoveUp}
            disabled={!canMoveUp}
            className="p-0.5 text-gray-400 hover:text-gray-600 disabled:opacity-30 disabled:cursor-not-allowed"
          >
            <ChevronUp className="w-3 h-3" />
          </button>
          <button
            onClick={onMoveDown}
            disabled={!canMoveDown}
            className="p-0.5 text-gray-400 hover:text-gray-600 disabled:opacity-30 disabled:cursor-not-allowed"
          >
            <ChevronDown className="w-3 h-3" />
          </button>
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="font-medium text-gray-900 truncate">{draft.name}</span>
            <span className="text-xs px-1.5 py-0.5 bg-gray-100 text-gray-500 rounded">
              {draft.intervention_string_id}
            </span>
          </div>
          <div className="flex items-center gap-2 mt-0.5 text-xs text-gray-500">
            <span>{draft.frequency}</span>
            {draft.timing && (
              <>
                <span>•</span>
                <span>{draft.timing}</span>
              </>
            )}
            <span>•</span>
            <span>Starts {draft.startDate}</span>
          </div>
        </div>

        <div className="flex items-center gap-1">
          <button
            onClick={onEdit}
            className={`p-2 rounded-lg transition-colors ${
              isEditing
                ? "bg-teal-500 text-white"
                : "text-gray-400 hover:text-gray-600 hover:bg-gray-100"
            }`}
          >
            <Edit2 className="w-4 h-4" />
          </button>
          <button
            onClick={onRemove}
            className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Expanded Edit Form */}
      {isEditing && (
        <div className="px-3 pb-3 pt-0 border-t border-gray-100">
          {/* Why It Works */}
          {draft.why_it_works && (
            <div className="mt-3 p-3 bg-blue-50 rounded-lg">
              <p className="text-xs font-medium text-blue-700 mb-1">Why It Works</p>
              <p className="text-xs text-blue-600">{draft.why_it_works}</p>
            </div>
          )}

          <div className="grid grid-cols-2 gap-3 mt-3">
            {/* Start Date */}
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Start Date
              </label>
              <input
                type="date"
                value={draft.startDate}
                onChange={(e) => onUpdate({ startDate: e.target.value })}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              />
            </div>

            {/* End Date */}
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                End Date
              </label>
              <input
                type="date"
                value={draft.endDate}
                onChange={(e) => onUpdate({ endDate: e.target.value })}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              />
            </div>

            {/* Frequency */}
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Frequency
              </label>
              <select
                value={draft.frequency}
                onChange={(e) => onUpdate({ frequency: e.target.value })}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                {frequencyOptions.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Timing */}
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Timing
              </label>
              <select
                value={draft.timing}
                onChange={(e) => onUpdate({ timing: e.target.value })}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="">Not specified</option>
                {timingOptions.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Specific Time */}
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Specific Time
              </label>
              <input
                type="time"
                value={draft.specificTime}
                onChange={(e) => onUpdate({ specificTime: e.target.value })}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              />
            </div>

            {/* Priority */}
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Priority
              </label>
              <select
                value={draft.priority}
                onChange={(e) => onUpdate({ priority: parseInt(e.target.value) })}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="1">1 - Low</option>
                <option value="2">2</option>
                <option value="3">3 - Medium</option>
                <option value="4">4</option>
                <option value="5">5 - High</option>
              </select>
            </div>
          </div>

          {/* Dosage (if applicable) */}
          {draft.category === "supplements" && (
            <div className="mt-3">
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Dosage
              </label>
              <input
                type="text"
                value={draft.dosage}
                onChange={(e) => onUpdate({ dosage: e.target.value })}
                placeholder="e.g., 200mg"
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              />
            </div>
          )}

          {/* Custom Instructions */}
          <div className="mt-3">
            <label className="block text-xs font-medium text-gray-700 mb-1">
              Custom Instructions
            </label>
            <textarea
              value={draft.customInstructions}
              onChange={(e) => onUpdate({ customInstructions: e.target.value })}
              placeholder="Add personalized instructions for this patient..."
              rows={2}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 resize-none"
            />
          </div>

          {/* Default Instructions Preview */}
          {draft.instructions_text && (
            <div className="mt-3 p-3 bg-gray-50 rounded-lg">
              <p className="text-xs font-medium text-gray-500 mb-1">
                Default Patient Instructions
              </p>
              <p className="text-xs text-gray-600">{draft.instructions_text}</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
