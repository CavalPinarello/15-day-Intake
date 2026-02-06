"use client";

import { Watch } from "lucide-react";

interface DeviceSource {
  name: string;
  bundleIdentifier: string;
  displayName: string;
  dataPoints: number;
  deviceModels?: string[]; // Array of device models (e.g., ["Series 8", "Ultra"])
}

interface DeviceSourceSelectorProps {
  sources: DeviceSource[];
  selected: string | null;
  onChange: (bundleId: string | null) => void;
}

export function DeviceSourceSelector({
  sources,
  selected,
  onChange,
}: DeviceSourceSelectorProps) {
  if (sources.length === 0) {
    return null;
  }

  return (
    <div className="flex items-center gap-2 bg-gray-800/50 rounded-lg px-3 py-2">
      <Watch className="w-4 h-4 text-gray-400" />
      <select
        value={selected || "all"}
        onChange={(e) => onChange(e.target.value === "all" ? null : e.target.value)}
        className="bg-transparent text-white text-sm border-none outline-none cursor-pointer"
      >
        <option value="all">All Devices (Merged)</option>
        {sources.map((source) => {
          // Format device models if available
          const modelsText = source.deviceModels && source.deviceModels.length > 0
            ? ` (${source.deviceModels.join(", ")})`
            : "";

          return (
            <option key={source.bundleIdentifier} value={source.name}>
              {source.displayName}{modelsText} • {source.dataPoints} days
            </option>
          );
        })}
      </select>
    </div>
  );
}
