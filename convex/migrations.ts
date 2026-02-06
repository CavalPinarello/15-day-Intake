import { internalMutation } from "./_generated/server";

/**
 * Migration script to backfill wearable_type and device_model fields
 * for existing sleep data records
 *
 * Run this after deploying the schema changes to populate the new fields
 * for historical data.
 */

/**
 * Detects the consolidated wearable type from bundle ID and source name
 * Duplicate of the function in healthkit.ts for use in migration
 */
function detectWearableType(bundleId: string, sourceName: string): string {
  const combined = (bundleId + " " + sourceName).toLowerCase();

  if (combined.includes("watch") || combined.includes("com.apple.health.")) {
    return "Apple Watch";
  } else if (combined.includes("oura") || combined.includes("ouraring")) {
    return "Oura Ring";
  } else if (combined.includes("garmin")) {
    return "Garmin";
  } else if (combined.includes("fitbit")) {
    return "Fitbit";
  } else if (combined.includes("whoop")) {
    return "WHOOP";
  }
  return "Other Device";
}

/**
 * Extracts device model from source name
 * Duplicate of the function in healthkit.ts for use in migration
 */
function extractDeviceModel(sourceName: string): string | undefined {
  const patterns = [
    /Apple Watch (.+)/i,
    /Garmin (.+)/i,
    /Fitbit (.+)/i,
    /WHOOP (.+)/i,
    /Oura Ring (.+)/i,
  ];

  for (const pattern of patterns) {
    const match = sourceName.match(pattern);
    if (match) return match[1].trim();
  }
  return undefined;
}

/**
 * Backfill wearable_type and device_model for all existing sleep data
 *
 * This migration:
 * 1. Queries all sleep data records
 * 2. Skips records that already have wearable_type set
 * 3. Detects wearable type from primary_source and source_bundle_id
 * 4. Extracts device model from primary_source name
 * 5. Updates records with new fields
 *
 * @returns Statistics about the migration
 */
export const backfillWearableTypes = internalMutation({
  handler: async (ctx) => {
    console.log("Starting wearable type backfill migration...");

    const sleepData = await ctx.db.query("user_sleep_data").collect();
    console.log(`Found ${sleepData.length} total sleep records`);

    let updated = 0;
    let skipped = 0;
    let failed = 0;

    const wearableTypeCounts: Record<string, number> = {};

    for (const record of sleepData) {
      try {
        // Skip if already has wearable_type
        if (record.wearable_type) {
          skipped++;
          continue;
        }

        // Detect wearable type
        const wearableType = detectWearableType(
          record.source_bundle_id || "",
          record.primary_source || ""
        );

        // Extract device model
        const deviceModel = extractDeviceModel(record.primary_source || "");

        // Update record
        await ctx.db.patch(record._id, {
          wearable_type: wearableType,
          device_model: deviceModel,
        });

        updated++;

        // Track wearable type distribution
        wearableTypeCounts[wearableType] = (wearableTypeCounts[wearableType] || 0) + 1;

      } catch (error) {
        console.error(`Failed to update record ${record._id}:`, error);
        failed++;
      }
    }

    const result = {
      total: sleepData.length,
      updated,
      skipped,
      failed,
      wearableTypeCounts,
      completionPercentage: ((updated + skipped) / sleepData.length * 100).toFixed(2) + "%"
    };

    console.log("Migration complete:", result);
    return result;
  },
});

/**
 * Verify migration results
 * Check how many records have wearable_type populated
 */
export const verifyWearableTypesMigration = internalMutation({
  handler: async (ctx) => {
    const allRecords = await ctx.db.query("user_sleep_data").collect();
    const withWearableType = allRecords.filter(r => r.wearable_type);
    const withoutWearableType = allRecords.filter(r => !r.wearable_type);

    const wearableTypeBreakdown: Record<string, number> = {};
    withWearableType.forEach(r => {
      const type = r.wearable_type || "Unknown";
      wearableTypeBreakdown[type] = (wearableTypeBreakdown[type] || 0) + 1;
    });

    return {
      total: allRecords.length,
      withWearableType: withWearableType.length,
      withoutWearableType: withoutWearableType.length,
      coverage: ((withWearableType.length / allRecords.length) * 100).toFixed(2) + "%",
      wearableTypeBreakdown,
      sampleRecordsWithout: withoutWearableType.slice(0, 5).map(r => ({
        id: r._id,
        date: r.date,
        primary_source: r.primary_source,
        source_bundle_id: r.source_bundle_id
      }))
    };
  },
});
