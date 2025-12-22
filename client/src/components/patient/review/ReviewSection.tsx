"use client";

import { useState, useEffect, ReactNode } from "react";
import { ChevronDown, ChevronUp, Check, Loader2 } from "lucide-react";

interface ReviewSectionProps {
  id: string;
  title: string;
  icon: ReactNode;
  preview: string;
  isReviewed: boolean;
  isRequired?: boolean;
  onReviewedChange: (reviewed: boolean) => void;
  isLoading?: boolean;
  children: ReactNode;
  autoMarkReviewed?: boolean;
  autoMarkDelay?: number;
}

export function ReviewSection({
  id,
  title,
  icon,
  preview,
  isReviewed,
  isRequired = true,
  onReviewedChange,
  isLoading = false,
  children,
  autoMarkReviewed = true,
  autoMarkDelay = 2000,
}: ReviewSectionProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const [hasBeenViewed, setHasBeenViewed] = useState(false);

  // Auto-mark as reviewed after viewing for specified time
  useEffect(() => {
    let timer: NodeJS.Timeout;

    if (isExpanded && autoMarkReviewed && !isReviewed && !hasBeenViewed) {
      timer = setTimeout(() => {
        setHasBeenViewed(true);
        onReviewedChange(true);
      }, autoMarkDelay);
    }

    return () => {
      if (timer) clearTimeout(timer);
    };
  }, [isExpanded, autoMarkReviewed, isReviewed, hasBeenViewed, onReviewedChange, autoMarkDelay]);

  const handleToggle = () => {
    setIsExpanded(!isExpanded);
  };

  const handleCheckboxChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    e.stopPropagation();
    onReviewedChange(e.target.checked);
  };

  return (
    <div
      className={`rounded-xl border transition-all ${
        isReviewed
          ? "bg-green-500/5 border-green-500/30"
          : isExpanded
          ? "bg-amber-500/5 border-amber-500/30"
          : "bg-gray-800/30 border-gray-700/50 hover:border-gray-600/50"
      }`}
    >
      {/* Header - clickable to expand */}
      <button
        onClick={handleToggle}
        className="w-full flex items-center gap-3 p-3 text-left"
      >
        {/* Checkbox */}
        <div onClick={(e) => e.stopPropagation()}>
          <input
            type="checkbox"
            checked={isReviewed}
            onChange={handleCheckboxChange}
            className="w-4 h-4 rounded border-gray-600 bg-gray-700 text-green-500 focus:ring-green-500 cursor-pointer"
          />
        </div>

        {/* Icon */}
        <div
          className={`w-8 h-8 rounded-lg flex items-center justify-center ${
            isReviewed
              ? "bg-green-500/20 text-green-400"
              : "bg-gray-700/50 text-gray-400"
          }`}
        >
          {icon}
        </div>

        {/* Title and Preview */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span
              className={`text-sm font-medium ${
                isReviewed ? "text-gray-400 line-through" : "text-white"
              }`}
            >
              {title}
            </span>
            {isRequired && !isReviewed && (
              <span className="text-[10px] px-1.5 py-0.5 bg-red-500/20 text-red-400 rounded">
                Required
              </span>
            )}
            {isReviewed && (
              <Check className="w-4 h-4 text-green-400" />
            )}
          </div>
          <p className="text-xs text-gray-500 truncate mt-0.5">{preview}</p>
        </div>

        {/* Loading or Expand Icon */}
        <div className="text-gray-400">
          {isLoading ? (
            <Loader2 className="w-4 h-4 animate-spin" />
          ) : isExpanded ? (
            <ChevronUp className="w-4 h-4" />
          ) : (
            <ChevronDown className="w-4 h-4" />
          )}
        </div>
      </button>

      {/* Expanded Content */}
      {isExpanded && (
        <div className="px-3 pb-3">
          <div className="pt-3 border-t border-gray-700/50">
            {isLoading ? (
              <div className="flex items-center justify-center py-8">
                <Loader2 className="w-6 h-6 text-gray-400 animate-spin" />
              </div>
            ) : (
              children
            )}
          </div>
        </div>
      )}
    </div>
  );
}
