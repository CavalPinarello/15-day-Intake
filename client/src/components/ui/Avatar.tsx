"use client";

import { useState } from "react";

interface AvatarProps {
  imageUrl?: string | null;
  name: string;
  size?: "xs" | "sm" | "md" | "lg" | "xl";
  className?: string;
}

const sizeClasses = {
  xs: "w-6 h-6 text-xs",
  sm: "w-8 h-8 text-sm",
  md: "w-12 h-12 text-lg",
  lg: "w-16 h-16 text-2xl",
  xl: "w-20 h-20 text-3xl",
};

/**
 * Reusable Avatar component with image support and initials fallback.
 * Shows a gradient background with initials when no image is provided.
 */
export function Avatar({
  imageUrl,
  name,
  size = "md",
  className = "",
}: AvatarProps) {
  const [imageError, setImageError] = useState(false);

  // Get initials from name (up to 2 characters)
  const initials = name
    .split(" ")
    .map((part) => part.charAt(0))
    .join("")
    .toUpperCase()
    .slice(0, 2) || "?";

  const sizeClass = sizeClasses[size];

  // Show image if URL exists and hasn't errored
  if (imageUrl && !imageError) {
    return (
      <img
        src={imageUrl}
        alt={name}
        className={`rounded-full object-cover ${sizeClass} ${className}`}
        onError={() => setImageError(true)}
      />
    );
  }

  // Fallback to initials with gradient
  return (
    <div
      className={`rounded-full bg-gradient-to-br from-teal-400 to-blue-500 flex items-center justify-center text-white font-semibold ${sizeClass} ${className}`}
    >
      {initials}
    </div>
  );
}

export default Avatar;
