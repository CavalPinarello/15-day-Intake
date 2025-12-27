"use client";
/* eslint-disable @typescript-eslint/no-unused-vars, @typescript-eslint/no-explicit-any */

import { useState, useMemo } from "react";
import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { Id } from "@/convex/_generated/dataModel";
import {
  Search,
  Filter,
  ChevronRight,
  ChevronDown,
  Plus,
  Minus,
  Check,
  Clock,
  Sun,
  Moon,
  Coffee,
  Pill,
  Activity,
  Brain,
  Heart,
  Home,
  Thermometer,
  Stethoscope,
  Utensils,
  Sparkles,
  Info,
  AlertTriangle,
  Package,
  Zap,
  Target,
  X,
} from "lucide-react";

interface InterventionLibraryProps {
  userId: Id<"users">;
  onInterventionSelect?: (interventionId: Id<"interventions">) => void;
  selectedInterventions?: Id<"interventions">[];
  showSuggestions?: boolean;
  compact?: boolean;
}

// Category icon mapping
const categoryIcons: Record<string, React.ReactNode> = {
  sleep_timing: <Clock className="w-4 h-4" />,
  light_dark: <Sun className="w-4 h-4" />,
  chrononutrition: <Utensils className="w-4 h-4" />,
  supplements: <Pill className="w-4 h-4" />,
  caffeine: <Coffee className="w-4 h-4" />,
  temperature: <Thermometer className="w-4 h-4" />,
  exercise: <Activity className="w-4 h-4" />,
  cbti: <Brain className="w-4 h-4" />,
  autonomic: <Heart className="w-4 h-4" />,
  environment: <Home className="w-4 h-4" />,
  medical: <Stethoscope className="w-4 h-4" />,
  chronotherapy: <Moon className="w-4 h-4" />,
};

// Category color mapping
const categoryColors: Record<string, { bg: string; text: string; border: string }> = {
  sleep_timing: { bg: "bg-indigo-50", text: "text-indigo-700", border: "border-indigo-200" },
  light_dark: { bg: "bg-amber-50", text: "text-amber-700", border: "border-amber-200" },
  chrononutrition: { bg: "bg-emerald-50", text: "text-emerald-700", border: "border-emerald-200" },
  supplements: { bg: "bg-violet-50", text: "text-violet-700", border: "border-violet-200" },
  caffeine: { bg: "bg-orange-50", text: "text-orange-800", border: "border-orange-200" },
  temperature: { bg: "bg-blue-50", text: "text-blue-700", border: "border-blue-200" },
  exercise: { bg: "bg-red-50", text: "text-red-700", border: "border-red-200" },
  cbti: { bg: "bg-pink-50", text: "text-pink-700", border: "border-pink-200" },
  autonomic: { bg: "bg-orange-50", text: "text-orange-700", border: "border-orange-200" },
  environment: { bg: "bg-teal-50", text: "text-teal-700", border: "border-teal-200" },
  medical: { bg: "bg-red-50", text: "text-red-800", border: "border-red-200" },
  chronotherapy: { bg: "bg-purple-50", text: "text-purple-700", border: "border-purple-200" },
};

export function InterventionLibrary({
  userId,
  onInterventionSelect,
  selectedInterventions = [],
  showSuggestions = true,
  compact = false,
}: InterventionLibraryProps) {
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [expandedIntervention, setExpandedIntervention] = useState<string | null>(null);
  const [showFilters, setShowFilters] = useState(false);

  // Queries
  const categories = useQuery(api.interventionLibrary.getCategories);
  const interventions = useQuery(api.interventionLibrary.getAllInterventions, {
    category: selectedCategory || undefined,
    searchTerm: searchTerm || undefined,
  });
  const suggestions = useQuery(
    api.interventionLibrary.getSuggestedInterventions,
    showSuggestions ? { userId } : "skip"
  );
  const bundles = useQuery(api.interventionLibrary.getBundles);

  // Group interventions by category
  type InterventionType = NonNullable<typeof interventions>[number];
  type CategoryType = NonNullable<typeof categories>[number];
  const interventionsByCategory = useMemo(() => {
    if (!interventions) return {};
    return interventions.reduce(
      (acc: Record<string, InterventionType[]>, intv: InterventionType) => {
        if (!acc[intv.category]) acc[intv.category] = [];
        acc[intv.category].push(intv);
        return acc;
      },
      {} as Record<string, InterventionType[]>
    );
  }, [interventions]);

  // Check if intervention is selected
  const isSelected = (id: Id<"interventions">) => selectedInterventions.includes(id);

  // Check if intervention is suggested
  type SuggestionItemType = NonNullable<typeof suggestions>["suggestedInterventions"][number];
  const getSuggestionInfo = (interventionId: string) => {
    if (!suggestions) return null;
    const suggested = suggestions.suggestedInterventions.find(
      (s: SuggestionItemType) => s.intervention_id === interventionId
    );
    return suggested;
  };

  const handleInterventionClick = (intervention: {
    _id: Id<"interventions">;
    intervention_id: string;
  }) => {
    if (onInterventionSelect) {
      onInterventionSelect(intervention._id);
    }
  };

  const toggleExpand = (interventionId: string) => {
    setExpandedIntervention((prev) => (prev === interventionId ? null : interventionId));
  };

  if (!categories || !interventions) {
    return (
      <div className="flex items-center justify-center py-8">
        <div className="animate-spin w-6 h-6 border-2 border-teal-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className={`bg-white rounded-xl border border-gray-200 ${compact ? "" : "p-4"}`}>
      {/* Header with Search */}
      <div className={`${compact ? "p-4 border-b border-gray-200" : "mb-4"}`}>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <Package className="w-5 h-5 text-teal-600" />
            Intervention Library
          </h3>
          <span className="text-sm text-gray-500">{interventions.length} interventions</span>
        </div>

        {/* Search Bar */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search interventions..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500 text-sm"
          />
          {searchTerm && (
            <button
              onClick={() => setSearchTerm("")}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Category Filters */}
        <div className="flex items-center gap-2 mt-3 overflow-x-auto pb-2">
          <button
            onClick={() => setSelectedCategory(null)}
            className={`px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-colors ${
              selectedCategory === null
                ? "bg-teal-600 text-white"
                : "bg-gray-100 text-gray-600 hover:bg-gray-200"
            }`}
          >
            All
          </button>
          {categories.map((cat: NonNullable<typeof categories>[number]) => (
            <button
              key={cat.category_id}
              onClick={() =>
                setSelectedCategory((prev) =>
                  prev === cat.category_id ? null : cat.category_id
                )
              }
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-colors ${
                selectedCategory === cat.category_id
                  ? "bg-teal-600 text-white"
                  : `${categoryColors[cat.category_id]?.bg || "bg-gray-100"} ${categoryColors[cat.category_id]?.text || "text-gray-600"} hover:opacity-80`
              }`}
            >
              {categoryIcons[cat.category_id]}
              {cat.name}
            </button>
          ))}
        </div>
      </div>

      {/* AI Suggestions Section */}
      {showSuggestions && suggestions && suggestions.suggestedInterventions.length > 0 && (
        <div className={`${compact ? "px-4 py-3" : "mb-4"} bg-gradient-to-r from-purple-50 to-teal-50 rounded-lg border border-purple-100`}>
          <div className="flex items-center gap-2 mb-3">
            <Sparkles className="w-4 h-4 text-purple-600" />
            <span className="text-sm font-medium text-purple-800">
              AI-Suggested Interventions
            </span>
            {suggestions.suggestedBundle && (
              <span className="ml-auto text-xs text-purple-600 bg-purple-100 px-2 py-0.5 rounded-full">
                Matches: {suggestions.suggestedBundle.name}
              </span>
            )}
          </div>

          {/* Patient Profile Summary */}
          <div className="flex flex-wrap gap-2 mb-3">
            {suggestions.patientProfile.phenotype && (
              <span className="text-xs px-2 py-1 bg-white rounded-full text-purple-700 border border-purple-200">
                <Target className="w-3 h-3 inline mr-1" />
                {suggestions.patientProfile.phenotype.replace(/_/g, " ")}
              </span>
            )}
            {suggestions.patientProfile.triggeredGateways.map((gateway: string) => (
              <span
                key={gateway}
                className="text-xs px-2 py-1 bg-white rounded-full text-amber-700 border border-amber-200"
              >
                <AlertTriangle className="w-3 h-3 inline mr-1" />
                {gateway.replace(/_/g, " ")}
              </span>
            ))}
          </div>

          {/* Top Suggestions */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
            {suggestions.suggestedInterventions.slice(0, 6).map((suggestion: SuggestionItemType) => {
              const fullIntervention = interventions.find(
                (i: InterventionType) => i.intervention_id === suggestion.intervention_id
              );
              if (!fullIntervention) return null;

              return (
                <button
                  key={suggestion.intervention_id}
                  onClick={() => handleInterventionClick(fullIntervention)}
                  className={`flex items-start gap-2 p-2 rounded-lg text-left transition-all ${
                    isSelected(fullIntervention._id)
                      ? "bg-teal-100 border-2 border-teal-500"
                      : "bg-white border border-gray-200 hover:border-teal-300 hover:bg-teal-50"
                  }`}
                >
                  <div
                    className={`p-1 rounded ${categoryColors[fullIntervention.category]?.bg || "bg-gray-100"}`}
                  >
                    {categoryIcons[fullIntervention.category]}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">
                      {fullIntervention.short_name || fullIntervention.name}
                    </p>
                    <div className="flex items-center gap-1 mt-0.5">
                      <span
                        className={`text-xs px-1.5 py-0.5 rounded ${
                          suggestion.priority === "high"
                            ? "bg-green-100 text-green-700"
                            : suggestion.priority === "medium"
                              ? "bg-amber-100 text-amber-700"
                              : "bg-gray-100 text-gray-600"
                        }`}
                      >
                        {suggestion.priority}
                      </span>
                      <span className="text-xs text-gray-500">
                        {suggestion.matchScore}% match
                      </span>
                    </div>
                  </div>
                  {isSelected(fullIntervention._id) ? (
                    <Check className="w-4 h-4 text-teal-600 flex-shrink-0" />
                  ) : (
                    <Plus className="w-4 h-4 text-gray-400 flex-shrink-0" />
                  )}
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* Interventions List */}
      <div className={`space-y-4 ${compact ? "px-4 pb-4 max-h-96 overflow-y-auto" : ""}`}>
        {selectedCategory
          ? // Single category view
            interventions.map((intervention: InterventionType) => (
              <InterventionCard
                key={intervention._id}
                intervention={intervention}
                isSelected={isSelected(intervention._id)}
                isExpanded={expandedIntervention === intervention.intervention_id}
                suggestionInfo={getSuggestionInfo(intervention.intervention_id)}
                onSelect={() => handleInterventionClick(intervention)}
                onToggleExpand={() => toggleExpand(intervention.intervention_id)}
                compact={compact}
              />
            ))
          : // Grouped by category view
            (Object.entries(interventionsByCategory) as [string, InterventionType[]][]).map(([category, categoryInterventions]) => (
              <CategorySection
                key={category}
                category={category}
                categoryName={categories.find((c: CategoryType) => c.category_id === category)?.name || category}
                interventions={categoryInterventions}
                selectedInterventions={selectedInterventions}
                expandedIntervention={expandedIntervention}
                onSelect={handleInterventionClick}
                onToggleExpand={toggleExpand}
                getSuggestionInfo={getSuggestionInfo}
                compact={compact}
              />
            ))}

        {interventions.length === 0 && (
          <div className="text-center py-8 text-gray-500">
            <Package className="w-8 h-8 mx-auto mb-2 text-gray-300" />
            <p>No interventions found</p>
            {searchTerm && (
              <button
                onClick={() => setSearchTerm("")}
                className="text-teal-600 text-sm mt-1 hover:underline"
              >
                Clear search
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// Category Section Component
function CategorySection({
  category,
  categoryName,
  interventions,
  selectedInterventions,
  expandedIntervention,
  onSelect,
  onToggleExpand,
  getSuggestionInfo,
  compact,
}: {
  category: string;
  categoryName: string;
  interventions: any[];
  selectedInterventions: Id<"interventions">[];
  expandedIntervention: string | null;
  onSelect: (intervention: any) => void;
  onToggleExpand: (id: string) => void;
  getSuggestionInfo: (id: string) => any;
  compact: boolean;
}) {
  const [isExpanded, setIsExpanded] = useState(true);
  const colors = categoryColors[category] || { bg: "bg-gray-50", text: "text-gray-700", border: "border-gray-200" };

  return (
    <div className={`border rounded-lg ${colors.border}`}>
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className={`w-full flex items-center justify-between p-3 ${colors.bg} rounded-t-lg ${!isExpanded && "rounded-b-lg"}`}
      >
        <div className="flex items-center gap-2">
          {categoryIcons[category]}
          <span className={`font-medium ${colors.text}`}>{categoryName}</span>
          <span className="text-xs text-gray-500">({interventions.length})</span>
        </div>
        {isExpanded ? (
          <ChevronDown className="w-4 h-4 text-gray-500" />
        ) : (
          <ChevronRight className="w-4 h-4 text-gray-500" />
        )}
      </button>

      {isExpanded && (
        <div className="p-2 space-y-2">
          {interventions.map((intervention) => (
            <InterventionCard
              key={intervention._id}
              intervention={intervention}
              isSelected={selectedInterventions.includes(intervention._id)}
              isExpanded={expandedIntervention === intervention.intervention_id}
              suggestionInfo={getSuggestionInfo(intervention.intervention_id)}
              onSelect={() => onSelect(intervention)}
              onToggleExpand={() => onToggleExpand(intervention.intervention_id)}
              compact={compact}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// Individual Intervention Card
function InterventionCard({
  intervention,
  isSelected,
  isExpanded,
  suggestionInfo,
  onSelect,
  onToggleExpand,
  compact,
}: {
  intervention: any;
  isSelected: boolean;
  isExpanded: boolean;
  suggestionInfo: any;
  onSelect: () => void;
  onToggleExpand: () => void;
  compact: boolean;
}) {
  const colors = categoryColors[intervention.category] || {
    bg: "bg-gray-50",
    text: "text-gray-700",
    border: "border-gray-200",
  };

  return (
    <div
      className={`border rounded-lg transition-all ${
        isSelected ? "border-teal-500 bg-teal-50/50" : "border-gray-200 hover:border-gray-300"
      }`}
    >
      {/* Card Header */}
      <div className="flex items-center gap-3 p-3">
        <button
          onClick={onSelect}
          className={`p-2 rounded-lg transition-colors ${
            isSelected
              ? "bg-teal-500 text-white"
              : "bg-gray-100 text-gray-400 hover:bg-teal-100 hover:text-teal-600"
          }`}
        >
          {isSelected ? <Check className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
        </button>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="font-medium text-gray-900 truncate">
              {intervention.short_name || intervention.name}
            </span>
            {intervention.is_core_intervention && (
              <span className="text-xs px-1.5 py-0.5 bg-teal-100 text-teal-700 rounded">
                Core
              </span>
            )}
            {suggestionInfo && (
              <span className="text-xs px-1.5 py-0.5 bg-purple-100 text-purple-700 rounded flex items-center gap-1">
                <Sparkles className="w-3 h-3" />
                Suggested
              </span>
            )}
          </div>
          <p className="text-xs text-gray-500 truncate">
            {intervention.intervention_id} • {intervention.primary_benefit || intervention.type}
          </p>
        </div>

        <div className="flex items-center gap-2">
          {intervention.default_timing && (
            <span className={`text-xs px-2 py-1 rounded ${colors.bg} ${colors.text}`}>
              {intervention.default_timing}
            </span>
          )}
          <button
            onClick={(e) => {
              e.stopPropagation();
              onToggleExpand();
            }}
            className="p-1 text-gray-400 hover:text-gray-600"
          >
            {isExpanded ? (
              <ChevronDown className="w-4 h-4" />
            ) : (
              <Info className="w-4 h-4" />
            )}
          </button>
        </div>
      </div>

      {/* Expanded Details */}
      {isExpanded && (
        <div className="px-3 pb-3 pt-0 border-t border-gray-100">
          <div className="mt-3 space-y-3">
            {/* Why It Works */}
            <div>
              <p className="text-xs font-medium text-gray-500 uppercase mb-1">
                Why It Works
              </p>
              <p className="text-sm text-gray-700">{intervention.why_it_works}</p>
            </div>

            {/* How To Apply */}
            <div>
              <p className="text-xs font-medium text-gray-500 uppercase mb-1">
                How To Apply
              </p>
              <p className="text-sm text-gray-700">{intervention.how_to_apply}</p>
            </div>

            {/* Patient Instructions */}
            <div className="bg-gray-50 rounded-lg p-3">
              <p className="text-xs font-medium text-gray-500 uppercase mb-1">
                Patient Instructions
              </p>
              <p className="text-sm text-gray-700">{intervention.instructions_text}</p>
            </div>

            {/* Metadata */}
            <div className="flex flex-wrap gap-2">
              {intervention.default_frequency && (
                <span className="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded">
                  {intervention.default_frequency}
                </span>
              )}
              {intervention.default_dosage && (
                <span className="text-xs px-2 py-1 bg-violet-100 text-violet-700 rounded">
                  {intervention.default_dosage}
                </span>
              )}
              {intervention.contraindications?.length > 0 && (
                <span className="text-xs px-2 py-1 bg-red-100 text-red-700 rounded flex items-center gap-1">
                  <AlertTriangle className="w-3 h-3" />
                  {intervention.contraindications.length} contraindication(s)
                </span>
              )}
            </div>

            {/* Contraindications Detail */}
            {intervention.contraindications?.length > 0 && (
              <div className="bg-red-50 rounded-lg p-2">
                <p className="text-xs font-medium text-red-700 mb-1">Contraindications:</p>
                <ul className="text-xs text-red-600 list-disc list-inside">
                  {intervention.contraindications.map((c: string, i: number) => (
                    <li key={i}>{c}</li>
                  ))}
                </ul>
              </div>
            )}

            {/* Match Reasons (if suggested) */}
            {suggestionInfo && (
              <div className="bg-purple-50 rounded-lg p-2">
                <p className="text-xs font-medium text-purple-700 mb-1">
                  Why Suggested ({suggestionInfo.matchScore}% match):
                </p>
                <ul className="text-xs text-purple-600 list-disc list-inside">
                  {suggestionInfo.matchReasons.map((reason: string, i: number) => (
                    <li key={i}>{reason}</li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

export default InterventionLibrary;
