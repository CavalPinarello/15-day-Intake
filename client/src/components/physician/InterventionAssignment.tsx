"use client";
/* eslint-disable @typescript-eslint/no-unused-vars */

import { useState } from "react";
import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import {
  X,
  Edit2,
  Trash2,
  Play,
  ChevronUp,
  ChevronDown,
  Pill,
  FileText,
  Sparkles,
  Sun,
  SunMedium,
  Sunset,
  Moon,
} from "lucide-react";
import { InterventionLibrary } from "./InterventionLibrary";
import { InterventionTimeWindows, TimeWindowId } from "@/components/patient/InterventionTimeWindows";

interface InterventionAssignmentProps {
  userId: Id<"users">;
  patientName?: string;
  onClose?: () => void;
}

interface DraftIntervention {
  intervention_id: Id<"interventions">;
  intervention_string_id: string;
  name: string;
  category: string;
  startDate: string;
  duration: string; // Duration key instead of endDate
  frequency: string;
  timing?: string;
  timeWindow?: TimeWindowId;
  specificTime?: string;
  dosage?: string;
  customInstructions?: string;
  priority: number;
}

// Duration options with calculated weeks
const durationOptions = [
  { value: "1_week", label: "1 Week", days: 7 },
  { value: "2_weeks", label: "2 Weeks", days: 14 },
  { value: "4_weeks", label: "4 Weeks", days: 28 },
  { value: "6_weeks", label: "6 Weeks", days: 42 },
  { value: "8_weeks", label: "8 Weeks", days: 56 },
  { value: "12_weeks", label: "12 Weeks", days: 84 },
  { value: "ongoing", label: "Ongoing", days: null },
];

// Helper to calculate end date from start date and duration
function calculateEndDate(startDate: string, duration: string): string | undefined {
  const durationOption = durationOptions.find((d) => d.value === duration);
  if (!durationOption || durationOption.days === null) {
    return undefined; // Ongoing has no end date
  }
  const start = new Date(startDate);
  start.setDate(start.getDate() + durationOption.days);
  return start.toISOString().split("T")[0];
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

export function InterventionAssignment({
  userId,
  patientName,
  onClose,
}: InterventionAssignmentProps) {
  const [draftInterventions, setDraftInterventions] = useState<DraftIntervention[]>([]);
  const [editingIndex, setEditingIndex] = useState<number | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Queries
  const existingInterventions = useQuery(api.physician.getPatientInterventions, { userId });
  const suggestions = useQuery(api.interventionLibrary.getSuggestedInterventions, { userId });

  // Mutations
  const assignIntervention = useMutation(api.interventionLibrary.assignIntervention);
  const activateInterventions = useMutation(api.interventionLibrary.activatePatientInterventions);

  // Default start date (today)
  const today = new Date().toISOString().split("T")[0];

  // Handle intervention selection from library
  const handleInterventionSelect = (interventionId: Id<"interventions">) => {
    // Check if already in draft
    const existingIndex = draftInterventions.findIndex(
      (d) => d.intervention_id === interventionId
    );

    if (existingIndex >= 0) {
      // Remove from draft
      setDraftInterventions((prev) => prev.filter((_, i) => i !== existingIndex));
    } else {
      // Add to draft - need to fetch intervention details
      fetchAndAddIntervention(interventionId);
    }
  };

  const fetchAndAddIntervention = async (interventionId: Id<"interventions">) => {
    // We need to get intervention details - use the existing query data
    // For now, we'll use a placeholder and let the server fill in details
    const newDraft: DraftIntervention = {
      intervention_id: interventionId,
      intervention_string_id: "", // Will be filled by server
      name: "Loading...",
      category: "",
      startDate: today,
      duration: "4_weeks", // Default to 4 weeks
      frequency: "daily",
      priority: 3,
    };
    setDraftInterventions((prev) => [...prev, newDraft]);
    setEditingIndex(draftInterventions.length);
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

  // Submit all drafts and auto-activate
  const handleSubmit = async () => {
    if (draftInterventions.length === 0) return;
    setIsSubmitting(true);

    try {
      // Create all interventions with calculated end dates
      for (const draft of draftInterventions) {
        const endDate = calculateEndDate(draft.startDate, draft.duration);
        await assignIntervention({
          userId,
          interventionId: draft.intervention_id,
          startDate: draft.startDate,
          endDate,
          frequency: draft.frequency,
          timing: draft.timing,
          timeWindow: draft.timeWindow,
          specificTime: draft.specificTime,
          dosage: draft.dosage,
          customInstructions: draft.customInstructions,
          priority: draft.priority,
        });
      }

      // Auto-activate interventions immediately
      const result = await activateInterventions({ userId });

      alert(
        `Treatment started! ${result.activated} intervention(s) activated, ${result.tasksGenerated} daily tasks generated. Patient will see their treatment plan in the app.`
      );
      onClose?.();
    } catch (error) {
      console.error("Failed to assign and activate interventions:", error);
      alert("Failed to start treatment. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  // Get selected intervention IDs for library highlight
  const selectedIds = draftInterventions.map((d) => d.intervention_id);

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-xl font-bold text-gray-900">
                Prescribe Interventions
              </h1>
              {patientName && (
                <p className="text-sm text-gray-500">For {patientName}</p>
              )}
            </div>
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-500">
                {draftInterventions.length} intervention(s) selected
              </span>
              {onClose && (
                <button
                  onClick={onClose}
                  className="p-2 text-gray-400 hover:text-gray-600"
                >
                  <X className="w-5 h-5" />
                </button>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 py-6">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Left Column: Library */}
          <div className="lg:sticky lg:top-24 lg:h-[calc(100vh-120px)] lg:overflow-auto">
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
                  <div>
                    <p className="font-medium">Recommended Bundle</p>
                    <p className="text-sm text-white/80 mt-1">
                      Based on this patient&apos;s profile, we recommend the{" "}
                      <strong>{suggestions.suggestedBundle.name}</strong> bundle.
                    </p>
                    <p className="text-sm text-white/70 mt-1">
                      {suggestions.suggestedBundle.goal}
                    </p>
                    <button
                      onClick={() => {
                        // Add all suggested interventions
                        suggestions.suggestedInterventions
                          .slice(0, 8)
                          .forEach((s) => {
                            // We'd need to look up the full intervention here
                          });
                      }}
                      className="mt-3 px-4 py-2 bg-white/20 hover:bg-white/30 rounded-lg text-sm font-medium transition-colors"
                    >
                      Apply Recommended Bundle
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
                  Draft Prescription
                </h3>
                {draftInterventions.length > 0 && (
                  <button
                    onClick={() => setDraftInterventions([])}
                    className="text-sm text-gray-500 hover:text-red-500"
                  >
                    Clear All
                  </button>
                )}
              </div>

              {draftInterventions.length === 0 ? (
                <div className="text-center py-8 text-gray-500">
                  <Pill className="w-8 h-8 mx-auto mb-2 text-gray-300" />
                  <p>No interventions selected</p>
                  <p className="text-sm mt-1">
                    Select interventions from the library to add them here
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

              {/* Submit Button - Auto-activates interventions */}
              {draftInterventions.length > 0 && (
                <div className="mt-4 pt-4 border-t border-gray-200">
                  <button
                    onClick={handleSubmit}
                    disabled={isSubmitting}
                    className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-purple-600 to-teal-600 text-white rounded-lg font-medium hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed transition-opacity"
                  >
                    {isSubmitting ? (
                      <>
                        <div className="animate-spin w-4 h-4 border-2 border-white border-t-transparent rounded-full" />
                        Starting Treatment...
                      </>
                    ) : (
                      <>
                        <Play className="w-4 h-4" />
                        Start Treatment
                      </>
                    )}
                  </button>
                  <p className="text-xs text-gray-500 text-center mt-2">
                    Interventions will be immediately active and visible to the patient
                  </p>
                </div>
              )}
            </div>

            {/* Existing Interventions */}
            {existingInterventions && existingInterventions.length > 0 && (
              <div className="bg-white rounded-xl border border-gray-200 p-4">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">
                  Current Interventions
                </h3>
                <div className="space-y-2">
                  {existingInterventions.map((intervention) => (
                    <div
                      key={intervention._id}
                      className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
                    >
                      <div>
                        <p className="font-medium text-gray-900">
                          {intervention.intervention_name}
                        </p>
                        <div className="flex items-center gap-2 mt-1 text-xs text-gray-500">
                          <span>{intervention.frequency || "Daily"}</span>
                          <span>•</span>
                          <span>Started {intervention.start_date}</span>
                        </div>
                      </div>
                      <span
                        className={`px-2 py-1 rounded text-xs font-medium ${
                          intervention.status === "active"
                            ? "bg-green-100 text-green-700"
                            : intervention.status === "draft"
                              ? "bg-amber-100 text-amber-700"
                              : "bg-gray-100 text-gray-600"
                        }`}
                      >
                        {intervention.status}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
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
          <p className="font-medium text-gray-900 truncate">{draft.name}</p>
          <div className="flex items-center gap-2 mt-0.5 text-xs text-gray-500">
            <span>{draft.frequency}</span>
            {draft.timeWindow && (
              <>
                <span>•</span>
                <span className="capitalize">{draft.timeWindow}</span>
              </>
            )}
            {draft.timing && (
              <>
                <span>•</span>
                <span>{draft.timing}</span>
              </>
            )}
            <span>•</span>
            <span>{durationOptions.find(d => d.value === draft.duration)?.label || draft.duration}</span>
            <span>•</span>
            <span>From {draft.startDate}</span>
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

            {/* Duration */}
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Duration
              </label>
              <select
                value={draft.duration}
                onChange={(e) => onUpdate({ duration: e.target.value })}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                {durationOptions.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
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
                value={draft.timing || ""}
                onChange={(e) => onUpdate({ timing: e.target.value || undefined })}
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
          </div>

          {/* Time Window Selection */}
          <div className="mt-3 p-3 bg-gray-50 rounded-lg">
            <label className="block text-xs font-medium text-gray-700 mb-2">
              Session Time Window
            </label>
            <div className="flex gap-2">
              {[
                { id: "morning" as TimeWindowId, label: "Morning", range: "5AM-12PM", icon: Sun },
                { id: "afternoon" as TimeWindowId, label: "Afternoon", range: "12PM-5PM", icon: SunMedium },
                { id: "evening" as TimeWindowId, label: "Evening", range: "5PM-9PM", icon: Sunset },
                { id: "night" as TimeWindowId, label: "Night", range: "9PM-12AM", icon: Moon },
              ].map((window) => {
                const Icon = window.icon;
                const isSelected = draft.timeWindow === window.id;
                return (
                  <button
                    key={window.id}
                    type="button"
                    onClick={() => onUpdate({ timeWindow: isSelected ? undefined : window.id })}
                    className={`flex-1 flex flex-col items-center gap-1 p-2 rounded-lg border-2 transition-all ${
                      isSelected
                        ? "border-teal-500 bg-teal-50 text-teal-700"
                        : "border-gray-200 hover:border-gray-300 text-gray-600"
                    }`}
                  >
                    <Icon className={`w-4 h-4 ${isSelected ? "text-teal-500" : "text-gray-400"}`} />
                    <span className="text-xs font-medium">{window.label}</span>
                    <span className="text-[10px] text-gray-400">{window.range}</span>
                  </button>
                );
              })}
            </div>
            <p className="text-xs text-gray-500 mt-2">
              Tasks will only be available to complete during the selected time window.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-3 mt-3">
            {/* Specific Time */}
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Specific Time (optional)
              </label>
              <input
                type="time"
                value={draft.specificTime || ""}
                onChange={(e) =>
                  onUpdate({ specificTime: e.target.value || undefined })
                }
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              />
            </div>

            {/* Priority */}
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Priority (1-5)
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
                value={draft.dosage || ""}
                onChange={(e) => onUpdate({ dosage: e.target.value || undefined })}
                placeholder="e.g., 200mg"
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              />
            </div>
          )}

          {/* Custom Instructions */}
          <div className="mt-3">
            <label className="block text-xs font-medium text-gray-700 mb-1">
              Custom Instructions (optional)
            </label>
            <textarea
              value={draft.customInstructions || ""}
              onChange={(e) =>
                onUpdate({ customInstructions: e.target.value || undefined })
              }
              placeholder="Add personalized instructions for this patient..."
              rows={2}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 resize-none"
            />
          </div>
        </div>
      )}
    </div>
  );
}

export default InterventionAssignment;
