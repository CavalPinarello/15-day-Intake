"use client";

import { useState, useMemo } from "react";
import {
  Intervention,
  INTERVENTION_CATEGORIES,
  InterventionCategory,
} from "./InterventionLibrary";
import {
  X,
  Clock,
  Calendar,
  GripVertical,
  AlertTriangle,
  ChevronDown,
  ChevronUp,
  Info,
  Sun,
  Moon,
  Coffee,
  Utensils,
} from "lucide-react";

export interface PrescribedIntervention {
  intervention: Intervention;
  startDate: string;
  endDate: string;
  frequency: string;
  timing: string;
  customInstructions: string;
  aiSuggested?: boolean;
  requiresApproval?: boolean;
}

// Chronotype-based timing recommendations
const CHRONOTYPE_TIMING = {
  morning_lark: {
    wake: "5:30-6:30 AM",
    peakEnergy: "8-11 AM",
    lightExposure: "Immediately on waking",
    exercise: "6-10 AM",
    caffeineCutoff: "12 PM",
    windDown: "7:30 PM",
    bedtime: "9-10 PM",
    melatonin: "7 PM",
  },
  neutral: {
    wake: "6:30-7:30 AM",
    peakEnergy: "10 AM - 1 PM",
    lightExposure: "Within 30 min of waking",
    exercise: "8 AM - 4 PM",
    caffeineCutoff: "2 PM",
    windDown: "9 PM",
    bedtime: "10-11 PM",
    melatonin: "8 PM",
  },
  night_owl: {
    wake: "8-9 AM",
    peakEnergy: "12-5 PM",
    lightExposure: "Within 1 hour of waking",
    exercise: "4-7 PM",
    caffeineCutoff: "4 PM",
    windDown: "10:30 PM",
    bedtime: "11 PM - 12 AM",
    melatonin: "9 PM",
  },
} as const;

// Timing options based on intervention type
const TIMING_OPTIONS = [
  { value: "morning", label: "Morning", icon: <Sun className="w-4 h-4" /> },
  { value: "afternoon", label: "Afternoon", icon: <Coffee className="w-4 h-4" /> },
  { value: "evening", label: "Evening", icon: <Moon className="w-4 h-4" /> },
  { value: "before_bed", label: "Before bed", icon: <Moon className="w-4 h-4" /> },
  { value: "with_meals", label: "With meals", icon: <Utensils className="w-4 h-4" /> },
  { value: "on_waking", label: "On waking", icon: <Sun className="w-4 h-4" /> },
];

const FREQUENCY_OPTIONS = [
  "Daily",
  "Twice daily",
  "3x daily",
  "Every other day",
  "Weekly",
  "As needed",
];

interface PrescriptionBuilderProps {
  prescribedInterventions: PrescribedIntervention[];
  onUpdateIntervention: (index: number, updates: Partial<PrescribedIntervention>) => void;
  onRemoveIntervention: (index: number) => void;
  onReorderInterventions: (fromIndex: number, toIndex: number) => void;
  chronotype?: "morning_lark" | "neutral" | "night_owl";
}

export function PrescriptionBuilder({
  prescribedInterventions,
  onUpdateIntervention,
  onRemoveIntervention,
  onReorderInterventions,
  chronotype = "neutral",
}: PrescriptionBuilderProps) {
  const [expandedIndex, setExpandedIndex] = useState<number | null>(null);
  const [draggedIndex, setDraggedIndex] = useState<number | null>(null);

  const chronotypeInfo = CHRONOTYPE_TIMING[chronotype];

  const handleDragStart = (index: number) => {
    setDraggedIndex(index);
  };

  const handleDragOver = (e: React.DragEvent, index: number) => {
    e.preventDefault();
    if (draggedIndex !== null && draggedIndex !== index) {
      onReorderInterventions(draggedIndex, index);
      setDraggedIndex(index);
    }
  };

  const handleDragEnd = () => {
    setDraggedIndex(null);
  };

  // Get smart timing suggestion based on intervention and chronotype
  const getSmartTiming = (intervention: Intervention): string => {
    if (intervention.chronotypeAdjustment) {
      return intervention.chronotypeAdjustment[chronotype];
    }

    // Default timing based on category and chronotype
    switch (intervention.category) {
      case "light_therapy":
        return chronotypeInfo.lightExposure;
      case "lifestyle":
        if (intervention.id.includes("exercise")) {
          return chronotypeInfo.exercise;
        }
        if (intervention.id.includes("caffeine")) {
          return `Before ${chronotypeInfo.caffeineCutoff}`;
        }
        return intervention.defaultTiming;
      case "supplements":
        if (intervention.id.includes("melatonin")) {
          return chronotypeInfo.melatonin;
        }
        return intervention.defaultTiming;
      case "relaxation":
      case "sleep_hygiene":
        return chronotypeInfo.windDown;
      default:
        return intervention.defaultTiming;
    }
  };

  if (prescribedInterventions.length === 0) {
    return (
      <div className="bg-white rounded-2xl border border-gray-200 p-8">
        <div className="text-center">
          <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Clock className="w-8 h-8 text-gray-400" />
          </div>
          <h3 className="text-lg font-medium text-gray-900 mb-1">
            No interventions added yet
          </h3>
          <p className="text-sm text-gray-500">
            Select interventions from the library to build your treatment plan
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Chronotype indicator */}
      <div className="bg-gradient-to-r from-blue-50 to-purple-50 border border-blue-200 rounded-xl p-4">
        <div className="flex items-start gap-3">
          <div className="w-10 h-10 rounded-lg bg-white flex items-center justify-center shadow-sm">
            {chronotype === "morning_lark" ? "🌅" : chronotype === "night_owl" ? "🦉" : "⚖️"}
          </div>
          <div className="flex-1">
            <h4 className="font-medium text-gray-900 capitalize">
              {chronotype.replace("_", " ")} Chronotype
            </h4>
            <p className="text-sm text-gray-600 mt-0.5">
              Timings are optimized based on this patient&apos;s sleep pattern
            </p>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-2 mt-3 text-xs">
              <div className="bg-white rounded px-2 py-1">
                <span className="text-gray-500">Wake:</span>{" "}
                <span className="font-medium">{chronotypeInfo.wake}</span>
              </div>
              <div className="bg-white rounded px-2 py-1">
                <span className="text-gray-500">Bedtime:</span>{" "}
                <span className="font-medium">{chronotypeInfo.bedtime}</span>
              </div>
              <div className="bg-white rounded px-2 py-1">
                <span className="text-gray-500">Peak:</span>{" "}
                <span className="font-medium">{chronotypeInfo.peakEnergy}</span>
              </div>
              <div className="bg-white rounded px-2 py-1">
                <span className="text-gray-500">Wind down:</span>{" "}
                <span className="font-medium">{chronotypeInfo.windDown}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Intervention cards */}
      <div className="bg-white rounded-2xl border border-gray-200 divide-y divide-gray-100">
        {prescribedInterventions.map((prescribed, index) => {
          const { intervention } = prescribed;
          const categoryConfig = INTERVENTION_CATEGORIES[intervention.category];
          const isExpanded = expandedIndex === index;
          const smartTiming = getSmartTiming(intervention);

          return (
            <div
              key={intervention.id}
              draggable
              onDragStart={() => handleDragStart(index)}
              onDragOver={(e) => handleDragOver(e, index)}
              onDragEnd={handleDragEnd}
              className={`transition-all ${
                draggedIndex === index ? "opacity-50 bg-gray-50" : ""
              }`}
            >
              {/* Header */}
              <div className="p-4">
                <div className="flex items-start gap-3">
                  <div className="cursor-grab active:cursor-grabbing mt-1">
                    <GripVertical className="w-4 h-4 text-gray-400" />
                  </div>

                  <div
                    className="w-10 h-10 rounded-lg flex items-center justify-center text-lg"
                    style={{ backgroundColor: `${categoryConfig.color}20` }}
                  >
                    {categoryConfig.icon}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <h4 className="font-medium text-gray-900">{intervention.name}</h4>
                      {prescribed.aiSuggested && (
                        <span className="px-1.5 py-0.5 text-[10px] font-medium bg-purple-100 text-purple-700 rounded">
                          AI Suggested
                        </span>
                      )}
                      {intervention.requiresApproval && (
                        <span title="Requires clinical approval">
                          <AlertTriangle className="w-4 h-4 text-amber-500" />
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-gray-500 mt-0.5">
                      {prescribed.timing || smartTiming} • {prescribed.frequency}
                    </p>
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => setExpandedIndex(isExpanded ? null : index)}
                      className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
                    >
                      {isExpanded ? (
                        <ChevronUp className="w-4 h-4 text-gray-400" />
                      ) : (
                        <ChevronDown className="w-4 h-4 text-gray-400" />
                      )}
                    </button>
                    <button
                      onClick={() => onRemoveIntervention(index)}
                      className="p-2 hover:bg-red-50 rounded-lg transition-colors group"
                    >
                      <X className="w-4 h-4 text-gray-400 group-hover:text-red-500" />
                    </button>
                  </div>
                </div>

                {/* Smart timing suggestion */}
                {prescribed.timing !== smartTiming && (
                  <div className="mt-3 ml-14 flex items-center gap-2 text-xs text-blue-600 bg-blue-50 px-2 py-1.5 rounded-lg">
                    <Info className="w-3 h-3" />
                    <span>
                      Recommended timing for {chronotype.replace("_", " ")}:{" "}
                      <button
                        onClick={() => onUpdateIntervention(index, { timing: smartTiming })}
                        className="font-medium underline hover:no-underline"
                      >
                        {smartTiming}
                      </button>
                    </span>
                  </div>
                )}
              </div>

              {/* Expanded details */}
              {isExpanded && (
                <div className="px-4 pb-4 ml-14 space-y-4">
                  {/* Date range */}
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        <Calendar className="w-3 h-3 inline mr-1" />
                        Start Date
                      </label>
                      <input
                        type="date"
                        value={prescribed.startDate}
                        onChange={(e) =>
                          onUpdateIntervention(index, { startDate: e.target.value })
                        }
                        className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        <Calendar className="w-3 h-3 inline mr-1" />
                        End Date
                      </label>
                      <input
                        type="date"
                        value={prescribed.endDate}
                        onChange={(e) =>
                          onUpdateIntervention(index, { endDate: e.target.value })
                        }
                        className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
                      />
                    </div>
                  </div>

                  {/* Frequency and timing */}
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        <Clock className="w-3 h-3 inline mr-1" />
                        Frequency
                      </label>
                      <select
                        value={prescribed.frequency}
                        onChange={(e) =>
                          onUpdateIntervention(index, { frequency: e.target.value })
                        }
                        className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
                      >
                        {FREQUENCY_OPTIONS.map((freq) => (
                          <option key={freq} value={freq}>
                            {freq}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        <Clock className="w-3 h-3 inline mr-1" />
                        Timing
                      </label>
                      <select
                        value={prescribed.timing}
                        onChange={(e) =>
                          onUpdateIntervention(index, { timing: e.target.value })
                        }
                        className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
                      >
                        {TIMING_OPTIONS.map((opt) => (
                          <option key={opt.value} value={opt.label}>
                            {opt.label}
                          </option>
                        ))}
                        {intervention.chronotypeAdjustment && (
                          <option value={smartTiming}>
                            {smartTiming} (Chronotype adjusted)
                          </option>
                        )}
                      </select>
                    </div>
                  </div>

                  {/* Custom instructions */}
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Custom Instructions
                    </label>
                    <textarea
                      value={prescribed.customInstructions}
                      onChange={(e) =>
                        onUpdateIntervention(index, {
                          customInstructions: e.target.value,
                        })
                      }
                      placeholder={intervention.instructions}
                      className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 resize-none"
                      rows={3}
                    />
                  </div>

                  {/* Contraindications */}
                  {intervention.contraindications && (
                    <div className="flex items-start gap-2 p-3 bg-amber-50 border border-amber-200 rounded-lg">
                      <AlertTriangle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                      <div>
                        <p className="text-xs font-medium text-amber-800">
                          Contraindications
                        </p>
                        <p className="text-xs text-amber-700 mt-0.5">
                          {intervention.contraindications.join(", ")}
                        </p>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
