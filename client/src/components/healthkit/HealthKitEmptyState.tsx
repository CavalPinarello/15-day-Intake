"use client";

import { Watch } from "lucide-react";

export function HealthKitEmptyState() {
  return (
    <div className="text-center py-12">
      <Watch className="w-16 h-16 mx-auto mb-3 text-gray-600" />
      <p className="text-gray-400 font-medium">No Wearable Connected</p>
      <p className="text-sm text-gray-500 mt-2">
        This patient hasn&apos;t synced any HealthKit data from Apple Watch or other
        wearables.
      </p>
    </div>
  );
}
