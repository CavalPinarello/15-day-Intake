"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import { useState, useMemo } from "react";
import {
  Sun,
  Moon,
  Plus,
  X,
  Check,
  Clock,
  GripVertical,
  AlertCircle,
  ChevronDown,
  ChevronUp,
  Sparkles,
  Pause,
  Play,
} from "lucide-react";

interface ProtocolAssignmentProps {
  userId: Id<"users">;
  physicianId: string;
}

interface InterventionOption {
  id: string;
  name: string;
  category: string;
  difficulty: number;
  description?: string;
}

export function ProtocolAssignment({ userId, physicianId }: ProtocolAssignmentProps) {
  const [activeTab, setActiveTab] = useState<"morning" | "evening">("morning");
  const [isAddingIntervention, setIsAddingIntervention] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [expandedCategory, setExpandedCategory] = useState<string | null>(null);

  // Fetch current protocols
  const userProtocols = useQuery(api.protocols.getUserProtocols, { userId });

  // Fetch available interventions
  const allInterventions = useQuery(api.interventionLibrary.getInterventions, {});

  // Mutations
  const assignProtocol = useMutation(api.protocols.assignProtocol);
  const updateProtocolStatus = useMutation(api.protocols.updateProtocolStatus);

  // Current protocol data
  const currentProtocol = useMemo(() => {
    if (!userProtocols) return null;
    const protocol = activeTab === "morning"
      ? userProtocols.morningProtocol
      : userProtocols.eveningProtocol;
    if (!protocol) return null;
    return {
      protocolId: protocol.protocolId,
      interventionIds: [] as string[], // Will be populated from tasks
      status: "active" as const,
    };
  }, [userProtocols, activeTab]);

  // Filter interventions based on search and category
  const filteredInterventions = useMemo(() => {
    if (!allInterventions) return [];

    let filtered = allInterventions;

    interface AllIntervention {
      _id: string;
      name: string;
      category?: string;
      difficulty_level?: number;
      description?: string;
    }

    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(
        (i: AllIntervention) =>
          i.name.toLowerCase().includes(query) ||
          i.category?.toLowerCase().includes(query)
      );
    }

    // Group by category
    const grouped: Record<string, InterventionOption[]> = {};
    filtered.forEach((i: AllIntervention) => {
      const category = i.category || "Other";
      if (!grouped[category]) grouped[category] = [];
      grouped[category].push({
        id: i._id,
        name: i.name,
        category,
        difficulty: i.difficulty_level || 3,
        description: i.description,
      });
    });

    return grouped;
  }, [allInterventions, searchQuery]);

  // Get currently assigned intervention IDs for the active protocol
  const assignedInterventionIds = useMemo(() => {
    if (!userProtocols) return new Set<string>();
    const protocol = activeTab === "morning"
      ? userProtocols.morningProtocol
      : userProtocols.eveningProtocol;
    if (!protocol?.tasks) return new Set<string>();
    // Extract intervention IDs from tasks
    const ids = protocol.tasks
      .map((t: { interventionId?: string }) => t.interventionId)
      .filter((id: string | undefined): id is string => !!id);
    return new Set(ids);
  }, [userProtocols, activeTab]);

  const handleAddIntervention = async (interventionId: string) => {
    const newIds = [...Array.from(assignedInterventionIds), interventionId];
    try {
      await assignProtocol({
        userId,
        protocolId: activeTab === "morning" ? "morning_protocol" : "evening_protocol",
        interventionIds: newIds,
        physicianId,
      });
    } catch (error) {
      console.error("Failed to add intervention:", error);
    }
  };

  const handleRemoveIntervention = async (interventionId: string) => {
    const newIds = Array.from(assignedInterventionIds).filter(
      (id) => id !== interventionId
    );
    try {
      await assignProtocol({
        userId,
        protocolId: activeTab === "morning" ? "morning_protocol" : "evening_protocol",
        interventionIds: newIds,
        physicianId,
      });
    } catch (error) {
      console.error("Failed to remove intervention:", error);
    }
  };

  const handleToggleProtocolStatus = async () => {
    if (!currentProtocol) return;

    try {
      await updateProtocolStatus({
        userId,
        protocolId: currentProtocol.protocolId,
        status: currentProtocol.status === "active" ? "paused" : "active",
      });
    } catch (error) {
      console.error("Failed to toggle protocol status:", error);
    }
  };

  const getDifficultyColor = (difficulty: number) => {
    if (difficulty <= 1) return "bg-green-500/20 text-green-400";
    if (difficulty <= 2) return "bg-teal-500/20 text-teal-400";
    if (difficulty <= 3) return "bg-amber-500/20 text-amber-400";
    if (difficulty <= 4) return "bg-orange-500/20 text-orange-400";
    return "bg-red-500/20 text-red-400";
  };

  // Get intervention details for assigned interventions
  const assignedInterventions = useMemo(() => {
    if (!allInterventions) return [];
    const ids = Array.from(assignedInterventionIds) as string[];
    return ids
      .map((id) => allInterventions.find((i: { _id: string }) => i._id === id))
      .filter(Boolean);
  }, [allInterventions, assignedInterventionIds]);

  return (
    <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700/50 rounded-xl p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-indigo-500/20 flex items-center justify-center">
            <Sparkles className="w-4 h-4 text-indigo-400" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-white">Protocol Assignment</h3>
            <p className="text-xs text-gray-500">Configure treatment protocols</p>
          </div>
        </div>
      </div>

      {/* Protocol Tabs */}
      <div className="flex gap-2 mb-4">
        <button
          onClick={() => setActiveTab("morning")}
          className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg transition-colors ${
            activeTab === "morning"
              ? "bg-amber-500/20 text-amber-400 border border-amber-500/30"
              : "bg-gray-700/30 text-gray-400 hover:bg-gray-700/50"
          }`}
        >
          <Sun className="w-4 h-4" />
          <span className="text-sm">Morning Protocol</span>
        </button>
        <button
          onClick={() => setActiveTab("evening")}
          className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg transition-colors ${
            activeTab === "evening"
              ? "bg-purple-500/20 text-purple-400 border border-purple-500/30"
              : "bg-gray-700/30 text-gray-400 hover:bg-gray-700/50"
          }`}
        >
          <Moon className="w-4 h-4" />
          <span className="text-sm">Evening Protocol</span>
        </button>
      </div>

      {/* Protocol Status */}
      {currentProtocol && (
        <div className="flex items-center justify-between mb-4 p-2 bg-gray-700/30 rounded-lg">
          <div className="flex items-center gap-2">
            <div
              className={`w-2 h-2 rounded-full ${
                currentProtocol.status === "active" ? "bg-green-500" : "bg-amber-500"
              }`}
            />
            <span className="text-xs text-gray-400">
              Status: <span className="text-white capitalize">{currentProtocol.status}</span>
            </span>
          </div>
          <button
            onClick={handleToggleProtocolStatus}
            className={`flex items-center gap-1 px-2 py-1 rounded text-xs ${
              currentProtocol.status === "active"
                ? "bg-amber-500/20 text-amber-400 hover:bg-amber-500/30"
                : "bg-green-500/20 text-green-400 hover:bg-green-500/30"
            }`}
          >
            {currentProtocol.status === "active" ? (
              <>
                <Pause className="w-3 h-3" />
                Pause
              </>
            ) : (
              <>
                <Play className="w-3 h-3" />
                Resume
              </>
            )}
          </button>
        </div>
      )}

      {/* Assigned Interventions */}
      <div className="mb-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-xs text-gray-400">
            Assigned Interventions ({assignedInterventions.length})
          </span>
          <button
            onClick={() => setIsAddingIntervention(true)}
            className="flex items-center gap-1 px-2 py-1 rounded bg-indigo-500/20 text-indigo-400 text-xs hover:bg-indigo-500/30"
          >
            <Plus className="w-3 h-3" />
            Add
          </button>
        </div>

        {assignedInterventions.length === 0 ? (
          <div className="p-4 text-center bg-gray-700/30 rounded-lg border border-dashed border-gray-600">
            <AlertCircle className="w-6 h-6 text-gray-500 mx-auto mb-2" />
            <p className="text-sm text-gray-400">No interventions assigned</p>
            <p className="text-xs text-gray-500">Click Add to assign interventions</p>
          </div>
        ) : (
          <div className="space-y-2 max-h-[200px] overflow-y-auto">
            {assignedInterventions.map((intervention, index) => (
              <div
                key={intervention!._id}
                className="flex items-center gap-2 p-2 bg-gray-700/30 rounded-lg group"
              >
                <GripVertical className="w-4 h-4 text-gray-500 cursor-grab" />
                <span className="text-xs text-gray-500 w-4">{index + 1}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-white truncate">{intervention!.name}</p>
                  <p className="text-[10px] text-gray-500">{intervention!.category}</p>
                </div>
                <span
                  className={`px-1.5 py-0.5 text-[10px] rounded ${getDifficultyColor(
                    intervention!.difficulty_level || 3
                  )}`}
                >
                  L{intervention!.difficulty_level || 3}
                </span>
                <button
                  onClick={() => handleRemoveIntervention(intervention!._id)}
                  className="p-1 text-gray-500 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Time Window Info */}
      <div className="p-3 bg-gray-700/30 rounded-lg mb-4">
        <div className="flex items-center gap-2 mb-2">
          <Clock className="w-4 h-4 text-gray-400" />
          <span className="text-xs text-gray-400">Time Window</span>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-sm text-white">
            {activeTab === "morning" ? "6:00 AM - 12:00 PM" : "6:00 PM - 10:00 PM"}
          </span>
        </div>
      </div>

      {/* Add Intervention Modal/Panel */}
      {isAddingIntervention && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
          <div className="w-full max-w-lg bg-gray-800 rounded-xl border border-gray-700 shadow-xl max-h-[80vh] overflow-hidden">
            {/* Modal Header */}
            <div className="flex items-center justify-between p-4 border-b border-gray-700">
              <h3 className="text-sm font-medium text-white">Add Intervention</h3>
              <button
                onClick={() => setIsAddingIntervention(false)}
                className="p-1 text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Search */}
            <div className="p-4 border-b border-gray-700">
              <input
                type="text"
                placeholder="Search interventions..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full px-3 py-2 bg-gray-700/50 border border-gray-600 rounded-lg text-sm text-white placeholder:text-gray-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              />
            </div>

            {/* Intervention List */}
            <div className="p-4 max-h-[400px] overflow-y-auto">
              {Object.entries(filteredInterventions).map(([category, interventions]) => (
                <div key={category} className="mb-3">
                  <button
                    onClick={() =>
                      setExpandedCategory(expandedCategory === category ? null : category)
                    }
                    className="flex items-center justify-between w-full p-2 bg-gray-700/30 rounded-lg hover:bg-gray-700/50"
                  >
                    <span className="text-xs font-medium text-gray-300">{category}</span>
                    <div className="flex items-center gap-2">
                      <span className="text-[10px] text-gray-500">
                        {interventions.length} interventions
                      </span>
                      {expandedCategory === category ? (
                        <ChevronUp className="w-4 h-4 text-gray-400" />
                      ) : (
                        <ChevronDown className="w-4 h-4 text-gray-400" />
                      )}
                    </div>
                  </button>

                  {expandedCategory === category && (
                    <div className="mt-2 space-y-1 pl-2">
                      {interventions.map((intervention) => {
                        const isAssigned = assignedInterventionIds.has(intervention.id);
                        return (
                          <div
                            key={intervention.id}
                            className={`flex items-center justify-between p-2 rounded-lg ${
                              isAssigned
                                ? "bg-green-500/10 border border-green-500/30"
                                : "bg-gray-700/20 hover:bg-gray-700/40"
                            }`}
                          >
                            <div className="flex-1 min-w-0">
                              <p className="text-sm text-white truncate">
                                {intervention.name}
                              </p>
                              {intervention.description && (
                                <p className="text-[10px] text-gray-500 truncate">
                                  {intervention.description}
                                </p>
                              )}
                            </div>
                            <div className="flex items-center gap-2">
                              <span
                                className={`px-1.5 py-0.5 text-[10px] rounded ${getDifficultyColor(
                                  intervention.difficulty
                                )}`}
                              >
                                L{intervention.difficulty}
                              </span>
                              {isAssigned ? (
                                <button
                                  onClick={() => handleRemoveIntervention(intervention.id)}
                                  className="p-1 text-green-400 hover:text-red-400"
                                >
                                  <Check className="w-4 h-4" />
                                </button>
                              ) : (
                                <button
                                  onClick={() => handleAddIntervention(intervention.id)}
                                  className="p-1 text-gray-400 hover:text-green-400"
                                >
                                  <Plus className="w-4 h-4" />
                                </button>
                              )}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              ))}

              {Object.keys(filteredInterventions).length === 0 && (
                <div className="text-center py-8 text-gray-500">
                  <p className="text-sm">No interventions found</p>
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div className="p-4 border-t border-gray-700 flex justify-end">
              <button
                onClick={() => setIsAddingIntervention(false)}
                className="px-4 py-2 bg-indigo-500 text-white text-sm rounded-lg hover:bg-indigo-600"
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Footer Info */}
      <div className="text-center">
        <p className="text-[10px] text-gray-500">
          Interventions are shown to patients in the assigned order
        </p>
      </div>
    </div>
  );
}
