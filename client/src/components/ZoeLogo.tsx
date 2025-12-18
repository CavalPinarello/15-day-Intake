/**
 * ZoeLogo - Official Zoe Sleep logo component
 * Spiral crescent moon design representing sleep cycles and renewal
 */

import React from "react";

interface ZoeLogoProps {
  size?: number;
  className?: string;
  color?: string;
}

/**
 * The Zoe spiral crescent logo as an SVG
 */
export function ZoeLogo({
  size = 40,
  className = "",
  color = "#38A5B0",
}: ZoeLogoProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      {/* Outer crescent moon */}
      <mask id="outerCrescentMask">
        <circle cx="50" cy="50" r="45" fill="white" />
        <circle cx="62" cy="42" r="35" fill="black" />
      </mask>
      <circle cx="50" cy="50" r="45" fill={color} mask="url(#outerCrescentMask)" />

      {/* Inner spiral crescent */}
      <mask id="innerCrescentMask">
        <circle cx="60" cy="48" r="25" fill="white" />
        <circle cx="70" cy="42" r="18" fill="black" />
      </mask>
      <circle cx="60" cy="48" r="25" fill={color} mask="url(#innerCrescentMask)" />
    </svg>
  );
}

/**
 * Logo with "Zoe Sleep" text
 */
export function ZoeLogoWithText({
  logoSize = 40,
  className = "",
  showSubtitle = false,
}: {
  logoSize?: number;
  className?: string;
  showSubtitle?: boolean;
}) {
  return (
    <div className={`flex items-center gap-3 ${className}`}>
      <ZoeLogo size={logoSize} />
      <div>
        <h1 className="text-xl font-bold text-gray-900">Zoé Sleep</h1>
        {showSubtitle && (
          <p className="text-xs text-gray-500">Physician Dashboard</p>
        )}
      </div>
    </div>
  );
}

/**
 * Logo for dark backgrounds (login page, etc.)
 */
export function ZoeLogoDark({
  size = 64,
  className = "",
}: {
  size?: number;
  className?: string;
}) {
  return (
    <div className={`inline-flex flex-col items-center ${className}`}>
      <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-slate-900/50 to-slate-800/50 backdrop-blur mb-4">
        <ZoeLogo size={size * 0.6} />
      </div>
      <h1 className="text-3xl font-bold text-white">Zoé Sleep</h1>
      <p className="text-slate-400 mt-1">Physician Dashboard</p>
    </div>
  );
}

/**
 * Animated logo with subtle pulse effect
 */
export function ZoeLogoAnimated({
  size = 40,
  className = "",
}: {
  size?: number;
  className?: string;
}) {
  return (
    <div className={`relative ${className}`}>
      {/* Glow effect */}
      <div
        className="absolute inset-0 animate-pulse"
        style={{
          background: "radial-gradient(circle, rgba(56,165,176,0.3) 0%, transparent 70%)",
          transform: "scale(1.5)",
        }}
      />
      <ZoeLogo size={size} />
    </div>
  );
}

export default ZoeLogo;
