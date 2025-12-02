"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import Link from "next/link";
import { useState, use } from "react";
import { UserButton } from "@clerk/nextjs";
import {
  ArrowLeft,
  Pill,
  Plus,
  Trash2,
  Save,
  Send,
  Clock,
  Calendar,
  Moon,
  Users,
  ClipboardList,
  Settings,
  CheckCircle,
  Search,
  X,
} from "lucide-react";

interface DraftIntervention {
  interventionId: Id<"interventions">;
  interventionName: string;
  startDate: string;
  endDate: string;
  frequency: string;
  timing: string;
  customInstructions: string;
}

export default function PrescriptionPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const userId = id as Id<"users">;

  const [searchTerm, setSearchTerm] = useState("");
  const [draftInterventions, setDraftInterventions] = useState<
    DraftIntervention[]
  >([]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Queries
  const patient = useQuery(api.physician.getPatientDetails, { userId });
  const allInterventions = useQuery(api.physician.getAllInterventions, {});
  const existingInterventions = useQuery(api.physician.getPatientInterventions, {
    userId,
  });

  // Mutations
  const createIntervention = useMutation(
    api.physician.createInterventionForPatient
  );
  const activateInterventions = useMutation(
    api.physician.activateInterventions
  );
  const updateStatus = useMutation(api.physician.updatePatientReviewStatus);

  // Filter interventions based on search
  const filteredInterventions = allInterventions?.filter(
    (i) =>
      i.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      i.category?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Group interventions by category
  const groupedInterventions = filteredInterventions?.reduce(
    (acc, i) => {
      const category = i.category || "Other";
      if (!acc[category]) acc[category] = [];
      acc[category].push(i);
      return acc;
    },
    {} as Record<string, typeof filteredInterventions>
  );

  const addIntervention = (intervention: (typeof allInterventions)[number]) => {
    const today = new Date().toISOString().split("T")[0];
    const fourWeeksLater = new Date(Date.now() + 28 * 24 * 60 * 60 * 1000)
      .toISOString()
      .split("T")[0];

    setDraftInterventions((prev) => [
      ...prev,
      {
        interventionId: intervention._id,
        interventionName: intervention.name,
        startDate: today,
        endDate: fourWeeksLater,
        frequency: "Daily",
        timing: "Evening",
        customInstructions: "",
      },
    ]);
  };

  const removeIntervention = (index: number) => {
    setDraftInterventions((prev) => prev.filter((_, i) => i !== index));
  };

  const updateDraft = (
    index: number,
    field: keyof DraftIntervention,
    value: string
  ) => {
    setDraftInterventions((prev) =>
      prev.map((item, i) => (i === index ? { ...item, [field]: value } : item))
    );
  };

  const handleSaveAsDraft = async () => {
    setIsSubmitting(true);
    try {
      for (const draft of draftInterventions) {
        await createIntervention({
          userId,
          interventionId: draft.interventionId,
          startDate: draft.startDate,
          endDate: draft.endDate || undefined,
          frequency: draft.frequency || undefined,
          timing: draft.timing || undefined,
          customInstructions: draft.customInstructions || undefined,
        });
      }
      await updateStatus({ userId, status: "interventions_prepared" });
      setDraftInterventions([]);
    } catch (error) {
      console.error("Error saving interventions:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleActivate = async () => {
    setIsSubmitting(true);
    try {
      // First save any new drafts
      for (const draft of draftInterventions) {
        await createIntervention({
          userId,
          interventionId: draft.interventionId,
          startDate: draft.startDate,
          endDate: draft.endDate || undefined,
          frequency: draft.frequency || undefined,
          timing: draft.timing || undefined,
          customInstructions: draft.customInstructions || undefined,
        });
      }
      // Then activate all
      await activateInterventions({ userId });
      setDraftInterventions([]);
    } catch (error) {
      console.error("Error activating interventions:", error);
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
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-teal-500 to-blue-600 flex items-center justify-center">
                <Moon className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">Zoe Sleep</h1>
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
              <UserButton
                appearance={{
                  elements: {
                    avatarBox: "w-9 h-9",
                  },
                }}
              />
            </nav>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Back Link */}
        <Link
          href={`/physician-dashboard/patient/${id}`}
          className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to {patient.name || patient.user.username}
        </Link>

        {/* Page Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h2 className="text-2xl font-bold text-gray-900">
              Prescription Builder
            </h2>
            <p className="text-gray-600 mt-1">
              Create a treatment plan for {patient.name || patient.user.username}
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={handleSaveAsDraft}
              disabled={
                isSubmitting ||
                (draftInterventions.length === 0 &&
                  !existingInterventions?.some((i) => i.status === "draft"))
              }
              className="inline-flex items-center gap-2 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50"
            >
              <Save className="w-4 h-4" />
              Save Draft
            </button>
            <button
              onClick={handleActivate}
              disabled={isSubmitting || !hasDraftInterventions}
              className="inline-flex items-center gap-2 px-4 py-2 bg-teal-600 text-white rounded-lg hover:bg-teal-700 transition-colors disabled:opacity-50"
            >
              <Send className="w-4 h-4" />
              Activate & Send to Patient
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Intervention Library */}
          <div className="lg:col-span-1">
            <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden sticky top-24">
              <div className="p-4 border-b border-gray-100">
                <h3 className="font-semibold text-gray-900 mb-3">
                  Intervention Library
                </h3>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Search interventions..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="w-full pl-9 pr-4 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
                  />
                </div>
              </div>

              <div className="max-h-[calc(100vh-300px)] overflow-y-auto">
                {groupedInterventions &&
                  Object.entries(groupedInterventions).map(
                    ([category, items]) => (
                      <div key={category} className="border-b border-gray-100">
                        <div className="px-4 py-2 bg-gray-50">
                          <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
                            {category}
                          </h4>
                        </div>
                        {items?.map((intervention) => (
                          <button
                            key={intervention._id}
                            onClick={() => addIntervention(intervention)}
                            className="w-full px-4 py-3 text-left hover:bg-gray-50 transition-colors flex items-center justify-between group"
                          >
                            <div>
                              <p className="font-medium text-gray-900 text-sm">
                                {intervention.name}
                              </p>
                              <p className="text-xs text-gray-500 line-clamp-1">
                                {intervention.instructions_text}
                              </p>
                            </div>
                            <Plus className="w-4 h-4 text-gray-400 group-hover:text-teal-600 flex-shrink-0" />
                          </button>
                        ))}
                      </div>
                    )
                  )}
              </div>
            </div>
          </div>

          {/* Prescription Form */}
          <div className="lg:col-span-2">
            {/* Existing Draft Interventions */}
            {existingInterventions?.filter((i) => i.status === "draft").length >
              0 && (
              <div className="bg-white rounded-2xl border border-gray-200 p-6 mb-6">
                <h3 className="font-semibold text-gray-900 mb-4">
                  Previously Saved Drafts
                </h3>
                <div className="space-y-4">
                  {existingInterventions
                    ?.filter((i) => i.status === "draft")
                    .map((intervention) => (
                      <div
                        key={intervention._id}
                        className="border border-amber-200 bg-amber-50 rounded-xl p-4"
                      >
                        <div className="flex items-center justify-between">
                          <div>
                            <h4 className="font-medium text-gray-900">
                              {intervention.intervention_name}
                            </h4>
                            <p className="text-sm text-gray-600">
                              {intervention.start_date} -{" "}
                              {intervention.end_date || "Ongoing"} &bull;{" "}
                              {intervention.frequency} &bull;{" "}
                              {intervention.timing}
                            </p>
                          </div>
                          <span className="px-2 py-1 bg-amber-100 text-amber-700 rounded text-xs font-medium">
                            Draft
                          </span>
                        </div>
                      </div>
                    ))}
                </div>
              </div>
            )}

            {/* New Interventions */}
            <div className="bg-white rounded-2xl border border-gray-200 p-6">
              <h3 className="font-semibold text-gray-900 mb-4">
                Treatment Plan
              </h3>

              {draftInterventions.length === 0 &&
              !existingInterventions?.some((i) => i.status === "draft") ? (
                <div className="text-center py-12 border-2 border-dashed border-gray-200 rounded-xl">
                  <Pill className="w-12 h-12 mx-auto mb-4 text-gray-300" />
                  <p className="text-gray-500">No interventions added yet</p>
                  <p className="text-sm text-gray-400 mt-1">
                    Select interventions from the library on the left
                  </p>
                </div>
              ) : (
                <div className="space-y-4">
                  {draftInterventions.map((draft, index) => (
                    <div
                      key={index}
                      className="border border-gray-200 rounded-xl p-4"
                    >
                      <div className="flex items-center justify-between mb-4">
                        <h4 className="font-semibold text-gray-900">
                          {draft.interventionName}
                        </h4>
                        <button
                          onClick={() => removeIntervention(index)}
                          className="p-1 text-gray-400 hover:text-red-600 transition-colors"
                        >
                          <X className="w-5 h-5" />
                        </button>
                      </div>

                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">
                            <Calendar className="w-4 h-4 inline mr-1" />
                            Start Date
                          </label>
                          <input
                            type="date"
                            value={draft.startDate}
                            onChange={(e) =>
                              updateDraft(index, "startDate", e.target.value)
                            }
                            className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-teal-500"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">
                            <Calendar className="w-4 h-4 inline mr-1" />
                            End Date
                          </label>
                          <input
                            type="date"
                            value={draft.endDate}
                            onChange={(e) =>
                              updateDraft(index, "endDate", e.target.value)
                            }
                            className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-teal-500"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">
                            <Clock className="w-4 h-4 inline mr-1" />
                            Frequency
                          </label>
                          <select
                            value={draft.frequency}
                            onChange={(e) =>
                              updateDraft(index, "frequency", e.target.value)
                            }
                            className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-teal-500"
                          >
                            <option value="Daily">Daily</option>
                            <option value="Twice daily">Twice daily</option>
                            <option value="Weekly">Weekly</option>
                            <option value="As needed">As needed</option>
                          </select>
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">
                            <Clock className="w-4 h-4 inline mr-1" />
                            Timing
                          </label>
                          <select
                            value={draft.timing}
                            onChange={(e) =>
                              updateDraft(index, "timing", e.target.value)
                            }
                            className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-teal-500"
                          >
                            <option value="Morning">Morning</option>
                            <option value="Afternoon">Afternoon</option>
                            <option value="Evening">Evening</option>
                            <option value="Before bed">Before bed</option>
                            <option value="With meals">With meals</option>
                          </select>
                        </div>
                      </div>

                      <div className="mt-4">
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          Custom Instructions (Optional)
                        </label>
                        <textarea
                          value={draft.customInstructions}
                          onChange={(e) =>
                            updateDraft(
                              index,
                              "customInstructions",
                              e.target.value
                            )
                          }
                          placeholder="Add personalized instructions for this patient..."
                          className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-teal-500 resize-none"
                          rows={2}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Active Interventions */}
            {existingInterventions?.filter((i) => i.status === "active").length >
              0 && (
              <div className="bg-white rounded-2xl border border-gray-200 p-6 mt-6">
                <h3 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
                  <CheckCircle className="w-5 h-5 text-green-600" />
                  Currently Active
                </h3>
                <div className="space-y-3">
                  {existingInterventions
                    ?.filter((i) => i.status === "active")
                    .map((intervention) => (
                      <div
                        key={intervention._id}
                        className="border border-green-200 bg-green-50 rounded-xl p-4"
                      >
                        <div className="flex items-center justify-between">
                          <div>
                            <h4 className="font-medium text-gray-900">
                              {intervention.intervention_name}
                            </h4>
                            <p className="text-sm text-gray-600">
                              {intervention.start_date} -{" "}
                              {intervention.end_date || "Ongoing"} &bull;{" "}
                              {intervention.frequency} &bull;{" "}
                              {intervention.timing}
                            </p>
                          </div>
                          <span className="px-2 py-1 bg-green-100 text-green-700 rounded text-xs font-medium">
                            Active
                          </span>
                        </div>
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
