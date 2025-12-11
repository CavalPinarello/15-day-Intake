"use client";

import { ReactNode } from "react";

interface BentoCardProps {
  title: string;
  subtitle?: string;
  icon?: ReactNode;
  badge?: {
    text: string;
    variant: "success" | "warning" | "error" | "info" | "neutral";
  };
  action?: {
    label: string;
    onClick: () => void;
  };
  children: ReactNode;
  className?: string;
  size?: "small" | "medium" | "large" | "wide" | "tall";
}

const sizeClasses = {
  small: "col-span-1 row-span-1",
  medium: "col-span-1 row-span-2",
  large: "col-span-2 row-span-2",
  wide: "col-span-2 row-span-1",
  tall: "col-span-1 row-span-3",
};

const badgeVariants = {
  success: "bg-green-500/20 text-green-400 border-green-500/30",
  warning: "bg-amber-500/20 text-amber-400 border-amber-500/30",
  error: "bg-red-500/20 text-red-400 border-red-500/30",
  info: "bg-blue-500/20 text-blue-400 border-blue-500/30",
  neutral: "bg-gray-500/20 text-gray-400 border-gray-500/30",
};

export function BentoCard({
  title,
  subtitle,
  icon,
  badge,
  action,
  children,
  className = "",
  size = "small",
}: BentoCardProps) {
  return (
    <div
      className={`
        ${sizeClasses[size]}
        bg-gray-800/50 backdrop-blur-sm
        border border-gray-700/50
        rounded-xl p-4
        hover:border-gray-600/50 transition-colors
        flex flex-col
        ${className}
      `}
    >
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-2">
          {icon && (
            <div className="w-8 h-8 rounded-lg bg-gray-700/50 flex items-center justify-center text-gray-400">
              {icon}
            </div>
          )}
          <div>
            <h3 className="text-sm font-medium text-white">{title}</h3>
            {subtitle && (
              <p className="text-xs text-gray-500">{subtitle}</p>
            )}
          </div>
        </div>
        {badge && (
          <span
            className={`
              px-2 py-0.5 text-xs font-medium rounded-full border
              ${badgeVariants[badge.variant]}
            `}
          >
            {badge.text}
          </span>
        )}
      </div>

      {/* Content */}
      <div className="flex-1 min-h-0">{children}</div>

      {/* Action */}
      {action && (
        <button
          onClick={action.onClick}
          className="mt-3 text-xs text-blue-400 hover:text-blue-300 font-medium transition-colors text-left"
        >
          {action.label} →
        </button>
      )}
    </div>
  );
}

// Grid container for bento layout
interface BentoGridProps {
  children: ReactNode;
  columns?: 2 | 3 | 4;
  className?: string;
}

export function BentoGrid({
  children,
  columns = 3,
  className = "",
}: BentoGridProps) {
  const columnClasses = {
    2: "grid-cols-2",
    3: "grid-cols-3",
    4: "grid-cols-4",
  };

  return (
    <div
      className={`
        grid ${columnClasses[columns]}
        gap-4 auto-rows-[minmax(140px,auto)]
        ${className}
      `}
    >
      {children}
    </div>
  );
}
