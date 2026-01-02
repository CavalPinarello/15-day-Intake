"use client";

import { useState } from "react";
import { ChevronDown, ChevronUp, AlertTriangle, AlertCircle, Info, Minus } from "lucide-react";

export type PriorityLevel = "critical" | "high" | "medium" | "standard" | "supporting";

interface PrioritySectionProps {
  title: string;
  priority: PriorityLevel;
  description?: string;
  children: React.ReactNode;
  defaultCollapsed?: boolean;
  badge?: string | number;
  flagCount?: number; // Number of urgent flags in this section
}

const PRIORITY_CONFIG: Record<PriorityLevel, {
  borderColor: string;
  bgTint: string;
  labelColor: string;
  labelBg: string;
  icon: React.ReactNode;
  label: string;
}> = {
  critical: {
    borderColor: "border-l-red-600",
    bgTint: "bg-red-50/50",
    labelColor: "text-red-700",
    labelBg: "bg-red-100",
    icon: <AlertTriangle className="w-4 h-4" />,
    label: "CRITICAL",
  },
  high: {
    borderColor: "border-l-orange-500",
    bgTint: "bg-orange-50/30",
    labelColor: "text-orange-700",
    labelBg: "bg-orange-100",
    icon: <AlertCircle className="w-4 h-4" />,
    label: "HIGH",
  },
  medium: {
    borderColor: "border-l-amber-400",
    bgTint: "bg-amber-50/30",
    labelColor: "text-amber-700",
    labelBg: "bg-amber-100",
    icon: <Minus className="w-4 h-4" />,
    label: "MEDIUM",
  },
  standard: {
    borderColor: "border-l-gray-300",
    bgTint: "bg-white",
    labelColor: "text-gray-600",
    labelBg: "bg-gray-100",
    icon: null,
    label: "STANDARD",
  },
  supporting: {
    borderColor: "border-l-gray-200",
    bgTint: "bg-gray-50/50",
    labelColor: "text-gray-500",
    labelBg: "bg-gray-100",
    icon: <Info className="w-4 h-4" />,
    label: "SUPPORTING",
  },
};

export function PrioritySection({
  title,
  priority,
  description,
  children,
  defaultCollapsed = false,
  badge,
  flagCount,
}: PrioritySectionProps) {
  const [isCollapsed, setIsCollapsed] = useState(defaultCollapsed);

  const config = PRIORITY_CONFIG[priority];
  const isCollapsible = priority === "supporting";

  return (
    <div
      className={`border-l-4 ${config.borderColor} rounded-r-xl ${config.bgTint} overflow-hidden transition-all`}
    >
      {/* Header */}
      <div
        className={`px-4 py-3 flex items-center justify-between ${
          isCollapsible ? "cursor-pointer hover:bg-gray-100/50" : ""
        }`}
        onClick={() => isCollapsible && setIsCollapsed(!isCollapsed)}
      >
        <div className="flex items-center gap-3">
          {/* Priority Badge */}
          <span
            className={`px-2 py-0.5 text-xs font-bold rounded ${config.labelBg} ${config.labelColor} flex items-center gap-1`}
          >
            {config.icon}
            {config.label}
          </span>

          {/* Title */}
          <h3 className="font-semibold text-gray-900">{title}</h3>

          {/* Description */}
          {description && (
            <span className="text-sm text-gray-500 hidden sm:inline">{description}</span>
          )}

          {/* Flag Count */}
          {flagCount !== undefined && flagCount > 0 && (
            <span className="px-2 py-0.5 bg-red-600 text-white text-xs font-bold rounded-full">
              {flagCount} {flagCount === 1 ? "flag" : "flags"}
            </span>
          )}

          {/* Custom Badge */}
          {badge !== undefined && (
            <span className="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-medium rounded">
              {badge}
            </span>
          )}
        </div>

        {/* Collapse Toggle */}
        {isCollapsible && (
          <button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
            {isCollapsed ? (
              <ChevronDown className="w-5 h-5" />
            ) : (
              <ChevronUp className="w-5 h-5" />
            )}
          </button>
        )}
      </div>

      {/* Content */}
      {!isCollapsed && <div className="px-4 pb-4 space-y-4">{children}</div>}
    </div>
  );
}

/**
 * A simpler inline priority indicator for individual cards
 */
export function PriorityBadge({ priority }: { priority: PriorityLevel }) {
  const config = PRIORITY_CONFIG[priority];

  return (
    <span
      className={`inline-flex items-center gap-1 px-1.5 py-0.5 text-xs font-bold rounded ${config.labelBg} ${config.labelColor}`}
    >
      {config.icon}
      {config.label}
    </span>
  );
}
