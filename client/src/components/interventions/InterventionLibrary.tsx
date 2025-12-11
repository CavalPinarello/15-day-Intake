"use client";

import { useState, useMemo } from "react";
import {
  Search,
  Plus,
  Filter,
  Star,
  Clock,
  AlertTriangle,
  ChevronDown,
  ChevronRight,
  GripVertical,
  Info,
} from "lucide-react";

// Intervention categories with colors
export const INTERVENTION_CATEGORIES = {
  sleep_hygiene: {
    name: "Sleep Hygiene",
    color: "#3B82F6",
    icon: "🛏️",
    description: "Environment and bedtime routine optimization",
  },
  behavioral: {
    name: "Behavioral",
    color: "#8B5CF6",
    icon: "🧠",
    description: "CBT-I and behavioral techniques",
  },
  relaxation: {
    name: "Relaxation",
    color: "#10B981",
    icon: "🧘",
    description: "Stress reduction and relaxation exercises",
  },
  supplements: {
    name: "Supplements",
    color: "#F59E0B",
    icon: "💊",
    description: "Natural sleep aids and supplements",
  },
  lifestyle: {
    name: "Lifestyle",
    color: "#EC4899",
    icon: "🏃",
    description: "Exercise, diet, and daily habits",
  },
  light_therapy: {
    name: "Light Therapy",
    color: "#06B6D4",
    icon: "☀️",
    description: "Light exposure timing and intensity",
  },
  medication: {
    name: "Medication",
    color: "#EF4444",
    icon: "💉",
    description: "Prescription sleep medications",
  },
  devices: {
    name: "Devices",
    color: "#6366F1",
    icon: "📱",
    description: "Sleep tracking and therapy devices",
  },
} as const;

export type InterventionCategory = keyof typeof INTERVENTION_CATEGORIES;

export interface Intervention {
  id: string;
  name: string;
  category: InterventionCategory;
  description: string;
  instructions: string;
  evidenceScore: number; // 1-5
  defaultDuration: number; // weeks
  recommendedFrequency: string;
  defaultTiming: string;
  contraindications?: string[];
  requiresApproval?: boolean;
  chronotypeAdjustment?: {
    morning_lark: string;
    neutral: string;
    night_owl: string;
  };
}

// Sample intervention library
export const INTERVENTION_LIBRARY: Intervention[] = [
  // Sleep Hygiene
  {
    id: "sh_bedroom_temp",
    name: "Cool Bedroom Temperature",
    category: "sleep_hygiene",
    description: "Maintain bedroom temperature between 65-68°F (18-20°C)",
    instructions: "Set thermostat to 65-68°F before bed. Use light bedding. Consider a cooling mattress pad if needed.",
    evidenceScore: 5,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Before bed",
    chronotypeAdjustment: {
      morning_lark: "Start cooling at 8 PM",
      neutral: "Start cooling at 9 PM",
      night_owl: "Start cooling at 10 PM",
    },
  },
  {
    id: "sh_dark_room",
    name: "Complete Darkness",
    category: "sleep_hygiene",
    description: "Eliminate all light sources from bedroom",
    instructions: "Use blackout curtains, cover LED lights, remove or turn off all electronics with lights.",
    evidenceScore: 5,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Before bed",
  },
  {
    id: "sh_no_screens",
    name: "Screen-Free Wind Down",
    category: "sleep_hygiene",
    description: "No screens 1-2 hours before bed",
    instructions: "Put away phones, tablets, computers at least 1 hour before bed. Use blue light blockers if necessary earlier.",
    evidenceScore: 4,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Evening",
    chronotypeAdjustment: {
      morning_lark: "Start at 8 PM",
      neutral: "Start at 9 PM",
      night_owl: "Start at 10 PM",
    },
  },
  // Behavioral
  {
    id: "beh_sleep_restriction",
    name: "Sleep Restriction Therapy",
    category: "behavioral",
    description: "Limit time in bed to match actual sleep time",
    instructions: "Calculate average sleep time. Set strict bed and wake times. Increase by 15-30 min when efficiency reaches 85%.",
    evidenceScore: 5,
    defaultDuration: 6,
    recommendedFrequency: "Daily",
    defaultTiming: "All day",
    requiresApproval: true,
    contraindications: ["Bipolar disorder", "Seizure disorder", "High-risk occupation"],
  },
  {
    id: "beh_stimulus_control",
    name: "Stimulus Control",
    category: "behavioral",
    description: "Only use bed for sleep and intimacy",
    instructions: "If not asleep in 20 min, leave bed. Return only when sleepy. No reading, TV, or phone in bed.",
    evidenceScore: 5,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Before bed",
  },
  {
    id: "beh_cognitive_restructuring",
    name: "Cognitive Restructuring",
    category: "behavioral",
    description: "Challenge and reframe negative sleep thoughts",
    instructions: "Identify catastrophic thoughts about sleep. Challenge with evidence. Replace with realistic alternatives.",
    evidenceScore: 4,
    defaultDuration: 6,
    recommendedFrequency: "Daily",
    defaultTiming: "Evening",
  },
  // Relaxation
  {
    id: "rel_pmr",
    name: "Progressive Muscle Relaxation",
    category: "relaxation",
    description: "Systematic tensing and releasing of muscle groups",
    instructions: "Starting from feet, tense each muscle group for 5 seconds, release for 30 seconds. Work up to head.",
    evidenceScore: 4,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Before bed",
    chronotypeAdjustment: {
      morning_lark: "Practice at 8:30 PM",
      neutral: "Practice at 9:30 PM",
      night_owl: "Practice at 10:30 PM",
    },
  },
  {
    id: "rel_breathing",
    name: "4-7-8 Breathing",
    category: "relaxation",
    description: "Calming breath technique for sleep onset",
    instructions: "Inhale for 4 counts, hold for 7 counts, exhale for 8 counts. Repeat 4 cycles.",
    evidenceScore: 3,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Before bed",
  },
  {
    id: "rel_body_scan",
    name: "Body Scan Meditation",
    category: "relaxation",
    description: "Guided attention through body regions",
    instructions: "Lie in bed, systematically bring awareness to each body part from toes to head. Use guided audio if helpful.",
    evidenceScore: 4,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Before bed",
  },
  // Supplements
  {
    id: "sup_melatonin",
    name: "Melatonin",
    category: "supplements",
    description: "Low-dose melatonin for sleep timing",
    instructions: "Take 0.5-3mg melatonin 1-2 hours before desired bedtime. Start with lowest dose.",
    evidenceScore: 4,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Evening",
    chronotypeAdjustment: {
      morning_lark: "Take at 7 PM",
      neutral: "Take at 8 PM",
      night_owl: "Take at 9 PM",
    },
  },
  {
    id: "sup_magnesium",
    name: "Magnesium Glycinate",
    category: "supplements",
    description: "Magnesium supplement for sleep quality",
    instructions: "Take 200-400mg magnesium glycinate 1 hour before bed with a small snack.",
    evidenceScore: 3,
    defaultDuration: 8,
    recommendedFrequency: "Daily",
    defaultTiming: "Before bed",
  },
  {
    id: "sup_ashwagandha",
    name: "Ashwagandha",
    category: "supplements",
    description: "Adaptogenic herb for stress and sleep",
    instructions: "Take 300-600mg standardized extract in the evening. May take 2-4 weeks for full effect.",
    evidenceScore: 3,
    defaultDuration: 8,
    recommendedFrequency: "Daily",
    defaultTiming: "Evening",
  },
  // Lifestyle
  {
    id: "life_exercise",
    name: "Regular Exercise",
    category: "lifestyle",
    description: "150 minutes moderate exercise per week",
    instructions: "30 minutes of moderate exercise 5 days per week. Avoid intense exercise within 3 hours of bedtime.",
    evidenceScore: 5,
    defaultDuration: 12,
    recommendedFrequency: "5x/week",
    defaultTiming: "Morning",
    chronotypeAdjustment: {
      morning_lark: "Best before 10 AM",
      neutral: "Best before 4 PM",
      night_owl: "Best between 4-7 PM",
    },
  },
  {
    id: "life_caffeine",
    name: "Caffeine Cutoff",
    category: "lifestyle",
    description: "No caffeine after early afternoon",
    instructions: "Stop all caffeine (coffee, tea, soda, chocolate) by 2 PM. Caffeine half-life is 5-6 hours.",
    evidenceScore: 4,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Morning",
    chronotypeAdjustment: {
      morning_lark: "Cutoff at 12 PM",
      neutral: "Cutoff at 2 PM",
      night_owl: "Cutoff at 4 PM",
    },
  },
  {
    id: "life_alcohol",
    name: "Alcohol Restriction",
    category: "lifestyle",
    description: "Limit alcohol and avoid close to bedtime",
    instructions: "Limit to 1-2 drinks. No alcohol within 3 hours of bedtime. Alcohol disrupts REM sleep.",
    evidenceScore: 4,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Evening",
  },
  // Light Therapy
  {
    id: "light_morning",
    name: "Morning Light Exposure",
    category: "light_therapy",
    description: "Bright light within 1 hour of waking",
    instructions: "Get 10-30 minutes of bright light (>10,000 lux) within 1 hour of waking. Use light box if needed.",
    evidenceScore: 5,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Morning",
    chronotypeAdjustment: {
      morning_lark: "Immediately on waking",
      neutral: "Within 30 min of waking",
      night_owl: "Within 1 hour of waking",
    },
  },
  {
    id: "light_blue_blockers",
    name: "Blue Light Blocking",
    category: "light_therapy",
    description: "Wear blue light blocking glasses in evening",
    instructions: "Wear amber/orange tinted glasses 2-3 hours before bed. Look for glasses blocking 450-495nm light.",
    evidenceScore: 3,
    defaultDuration: 4,
    recommendedFrequency: "Daily",
    defaultTiming: "Evening",
    chronotypeAdjustment: {
      morning_lark: "Start at 7 PM",
      neutral: "Start at 8 PM",
      night_owl: "Start at 9 PM",
    },
  },
];

interface InterventionLibraryProps {
  onSelectIntervention: (intervention: Intervention) => void;
  selectedIds?: string[];
  chronotype?: "morning_lark" | "neutral" | "night_owl";
}

export function InterventionLibrary({
  onSelectIntervention,
  selectedIds = [],
  chronotype = "neutral",
}: InterventionLibraryProps) {
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<InterventionCategory | "all">("all");
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(
    new Set(Object.keys(INTERVENTION_CATEGORIES))
  );
  const [showFilters, setShowFilters] = useState(false);
  const [evidenceFilter, setEvidenceFilter] = useState<number>(0);

  // Filter interventions
  const filteredInterventions = useMemo(() => {
    return INTERVENTION_LIBRARY.filter((intervention) => {
      const matchesSearch =
        intervention.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        intervention.description.toLowerCase().includes(searchTerm.toLowerCase());
      const matchesCategory =
        selectedCategory === "all" || intervention.category === selectedCategory;
      const matchesEvidence = intervention.evidenceScore >= evidenceFilter;
      return matchesSearch && matchesCategory && matchesEvidence;
    });
  }, [searchTerm, selectedCategory, evidenceFilter]);

  // Group by category
  const groupedInterventions = useMemo(() => {
    return filteredInterventions.reduce((acc, intervention) => {
      if (!acc[intervention.category]) acc[intervention.category] = [];
      acc[intervention.category].push(intervention);
      return acc;
    }, {} as Record<InterventionCategory, Intervention[]>);
  }, [filteredInterventions]);

  const toggleCategory = (category: string) => {
    setExpandedCategories((prev) => {
      const next = new Set(prev);
      if (next.has(category)) {
        next.delete(category);
      } else {
        next.add(category);
      }
      return next;
    });
  };

  const getChronotypeAdjustedTiming = (intervention: Intervention): string => {
    if (intervention.chronotypeAdjustment && chronotype) {
      return intervention.chronotypeAdjustment[chronotype];
    }
    return intervention.defaultTiming;
  };

  return (
    <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
      {/* Header */}
      <div className="p-4 border-b border-gray-100 space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="font-semibold text-gray-900">Intervention Library</h3>
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`p-2 rounded-lg transition-colors ${
              showFilters ? "bg-teal-100 text-teal-700" : "hover:bg-gray-100 text-gray-500"
            }`}
          >
            <Filter className="w-4 h-4" />
          </button>
        </div>

        {/* Search */}
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

        {/* Filters */}
        {showFilters && (
          <div className="space-y-3 pt-2">
            {/* Category filter */}
            <div>
              <label className="text-xs font-medium text-gray-500 mb-1 block">
                Category
              </label>
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value as InterventionCategory | "all")}
                className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="all">All Categories</option>
                {Object.entries(INTERVENTION_CATEGORIES).map(([key, cat]) => (
                  <option key={key} value={key}>
                    {cat.icon} {cat.name}
                  </option>
                ))}
              </select>
            </div>

            {/* Evidence filter */}
            <div>
              <label className="text-xs font-medium text-gray-500 mb-1 block">
                Minimum Evidence Score
              </label>
              <div className="flex gap-1">
                {[0, 1, 2, 3, 4, 5].map((score) => (
                  <button
                    key={score}
                    onClick={() => setEvidenceFilter(score)}
                    className={`flex-1 py-1.5 rounded text-xs font-medium transition-colors ${
                      evidenceFilter === score
                        ? "bg-teal-600 text-white"
                        : "bg-gray-100 text-gray-600 hover:bg-gray-200"
                    }`}
                  >
                    {score === 0 ? "Any" : `${score}+`}
                  </button>
                ))}
              </div>
            </div>

            {/* Chronotype indicator */}
            {chronotype && (
              <div className="flex items-center gap-2 p-2 bg-blue-50 rounded-lg text-sm">
                <Info className="w-4 h-4 text-blue-500" />
                <span className="text-blue-700">
                  Timing adjusted for{" "}
                  <span className="font-medium capitalize">
                    {chronotype.replace("_", " ")}
                  </span>
                </span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Intervention list */}
      <div className="max-h-[calc(100vh-350px)] overflow-y-auto">
        {Object.entries(groupedInterventions).map(([category, interventions]) => {
          const categoryConfig = INTERVENTION_CATEGORIES[category as InterventionCategory];
          const isExpanded = expandedCategories.has(category);

          return (
            <div key={category} className="border-b border-gray-100 last:border-b-0">
              {/* Category header */}
              <button
                onClick={() => toggleCategory(category)}
                className="w-full px-4 py-3 flex items-center justify-between hover:bg-gray-50 transition-colors"
              >
                <div className="flex items-center gap-2">
                  <span className="text-lg">{categoryConfig.icon}</span>
                  <span className="font-medium text-gray-900">{categoryConfig.name}</span>
                  <span className="text-xs text-gray-400 bg-gray-100 px-1.5 py-0.5 rounded">
                    {interventions.length}
                  </span>
                </div>
                {isExpanded ? (
                  <ChevronDown className="w-4 h-4 text-gray-400" />
                ) : (
                  <ChevronRight className="w-4 h-4 text-gray-400" />
                )}
              </button>

              {/* Interventions in category */}
              {isExpanded && (
                <div className="pb-2">
                  {interventions.map((intervention) => {
                    const isSelected = selectedIds.includes(intervention.id);
                    const adjustedTiming = getChronotypeAdjustedTiming(intervention);

                    return (
                      <button
                        key={intervention.id}
                        onClick={() => onSelectIntervention(intervention)}
                        disabled={isSelected}
                        className={`w-full px-4 py-3 text-left transition-colors flex items-start gap-3 group ${
                          isSelected
                            ? "bg-teal-50 cursor-not-allowed"
                            : "hover:bg-gray-50"
                        }`}
                      >
                        <div className="flex-shrink-0 mt-0.5">
                          <GripVertical className="w-4 h-4 text-gray-300 group-hover:text-gray-400" />
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2">
                            <p className={`font-medium text-sm ${isSelected ? "text-teal-700" : "text-gray-900"}`}>
                              {intervention.name}
                            </p>
                            {intervention.requiresApproval && (
                              <span title="Requires approval">
                                <AlertTriangle className="w-3 h-3 text-amber-500" />
                              </span>
                            )}
                          </div>
                          <p className="text-xs text-gray-500 line-clamp-1 mt-0.5">
                            {intervention.description}
                          </p>
                          <div className="flex items-center gap-3 mt-1.5">
                            {/* Evidence score */}
                            <div className="flex items-center gap-1">
                              {Array.from({ length: 5 }).map((_, i) => (
                                <Star
                                  key={i}
                                  className={`w-3 h-3 ${
                                    i < intervention.evidenceScore
                                      ? "text-amber-400 fill-amber-400"
                                      : "text-gray-200"
                                  }`}
                                />
                              ))}
                            </div>
                            {/* Timing */}
                            <div className="flex items-center gap-1 text-xs text-gray-400">
                              <Clock className="w-3 h-3" />
                              {adjustedTiming}
                            </div>
                          </div>
                        </div>
                        {isSelected ? (
                          <span className="text-xs text-teal-600 font-medium">Added</span>
                        ) : (
                          <Plus className="w-4 h-4 text-gray-400 group-hover:text-teal-600 flex-shrink-0 mt-0.5" />
                        )}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}

        {filteredInterventions.length === 0 && (
          <div className="p-8 text-center text-gray-500">
            <Search className="w-8 h-8 mx-auto mb-2 text-gray-300" />
            <p className="text-sm">No interventions found</p>
            <p className="text-xs text-gray-400">Try adjusting your filters</p>
          </div>
        )}
      </div>
    </div>
  );
}
