//
//  SleepScoreModels.swift
//  Zoe Sleep for Longevity System
//
//  Models for unified sleep scoring across multiple devices
//

import Foundation

// MARK: - Zoe Sleep Score Components

/// Component scores that make up the Zoe Sleep Score
struct ZoeScoreComponents: Codable, Equatable {
    let duration: Double           // 0-100 (30% weight)
    let efficiency: Double         // 0-100 (25% weight)
    let deepSleep: Double          // 0-100 (20% weight)
    let remSleep: Double           // 0-100 (15% weight)
    let consistency: Double        // 0-100 (10% weight)

    /// Calculate weighted total score
    var weightedTotal: Double {
        return (duration * 0.30) +
               (efficiency * 0.25) +
               (deepSleep * 0.20) +
               (remSleep * 0.15) +
               (consistency * 0.10)
    }

    /// Get the lowest scoring component for improvement suggestions
    var lowestComponent: (name: String, score: Double) {
        let components: [(String, Double)] = [
            ("Duration", duration),
            ("Efficiency", efficiency),
            ("Deep Sleep", deepSleep),
            ("REM Sleep", remSleep),
            ("Consistency", consistency)
        ]
        return components.min(by: { $0.1 < $1.1 }) ?? ("Unknown", 0)
    }
}

// MARK: - Native Device Scores

/// Sleep score from a specific device/wearable
struct DeviceSleepScore: Codable, Identifiable, Equatable {
    let id: String                 // Bundle ID
    let deviceName: String         // Human-readable name
    let wearableType: String       // WearableType raw value
    let nativeScore: Int?          // Device's own score (if available)
    let zoeScore: Int              // Our standardized score for this device
    let discrepancy: Int?          // Difference between native and Zoe score
    let hasNativeScore: Bool

    init(
        deviceName: String,
        wearableType: String,
        bundleId: String,
        nativeScore: Int?,
        zoeScore: Int
    ) {
        self.id = bundleId
        self.deviceName = deviceName
        self.wearableType = wearableType
        self.nativeScore = nativeScore
        self.zoeScore = zoeScore
        self.hasNativeScore = nativeScore != nil
        if let native = nativeScore {
            self.discrepancy = zoeScore - native
        } else {
            self.discrepancy = nil
        }
    }
}

// MARK: - Zoe Sleep Score Result

/// Complete sleep score result for a night
struct ZoeSleepScoreResult: Codable, Identifiable, Equatable {
    let id: String                 // Date YYYY-MM-DD
    let date: String               // YYYY-MM-DD
    let zoeScore: Int              // 0-100 unified score
    let components: ZoeScoreComponents
    let deviceScores: [DeviceSleepScore]
    let hrvCharge: Int?            // HRV Charge score if available
    let hrvChargeTrajectory: String?
    let primarySource: String      // WearableType raw value
    let allSources: [String]       // All contributing sources
    let confidence: Double         // 0.0-1.0 based on data completeness
    let computedAt: Date

    var id_: String { date }

    init(
        date: String,
        zoeScore: Int,
        components: ZoeScoreComponents,
        deviceScores: [DeviceSleepScore] = [],
        hrvCharge: Int? = nil,
        hrvChargeTrajectory: String? = nil,
        primarySource: String,
        allSources: [String] = [],
        confidence: Double = 1.0,
        computedAt: Date = Date()
    ) {
        self.id = date
        self.date = date
        self.zoeScore = zoeScore
        self.components = components
        self.deviceScores = deviceScores
        self.hrvCharge = hrvCharge
        self.hrvChargeTrajectory = hrvChargeTrajectory
        self.primarySource = primarySource
        self.allSources = allSources
        self.confidence = confidence
        self.computedAt = computedAt
    }

    static func == (lhs: ZoeSleepScoreResult, rhs: ZoeSleepScoreResult) -> Bool {
        lhs.id == rhs.id && lhs.zoeScore == rhs.zoeScore
    }

    /// Score category for display
    var scoreCategory: ScoreCategory {
        ScoreCategory.from(score: zoeScore)
    }
}

// MARK: - Score Categories

/// Category for sleep score display
enum ScoreCategory: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }

    var colorName: String {
        switch self {
        case .excellent: return "success"
        case .good: return "primary"
        case .fair: return "warning"
        case .poor: return "error"
        }
    }

    var minScore: Int {
        switch self {
        case .excellent: return 85
        case .good: return 70
        case .fair: return 50
        case .poor: return 0
        }
    }

    static func from(score: Int) -> ScoreCategory {
        switch score {
        case 85...100: return .excellent
        case 70..<85: return .good
        case 50..<70: return .fair
        default: return .poor
        }
    }
}

// MARK: - Sleep Data for Scoring

/// Input data structure for sleep score calculation
struct SleepDataForScoring {
    let date: String
    let totalSleepMins: Int
    let timeInBedMins: Int
    let deepSleepMins: Int?
    let remSleepMins: Int?
    let lightSleepMins: Int?
    let inBedTime: Date?
    let wakeTime: Date?
    let awakenings: Int?
    let source: String
    let sourceBundleId: String
    let nativeScore: Int?          // Device's native score if available

    /// Sleep efficiency as percentage
    var efficiency: Double {
        guard timeInBedMins > 0 else { return 0 }
        return Double(totalSleepMins) / Double(timeInBedMins) * 100
    }

    /// Total sleep in hours
    var sleepHours: Double {
        Double(totalSleepMins) / 60.0
    }

    /// Deep sleep as percentage of total
    var deepPercent: Double? {
        guard totalSleepMins > 0, let deep = deepSleepMins else { return nil }
        return Double(deep) / Double(totalSleepMins) * 100
    }

    /// REM sleep as percentage of total
    var remPercent: Double? {
        guard totalSleepMins > 0, let rem = remSleepMins else { return nil }
        return Double(rem) / Double(totalSleepMins) * 100
    }
}

// MARK: - Source Preferences

/// User preferences for which sleep data sources to display
struct SleepSourcePreferences: Codable, Equatable {
    let connectedSources: [ConnectedSleepSource]
    let visibleSourceIds: [String]     // Bundle IDs of visible sources
    let priorityOverride: [String]?    // Optional custom priority order
    let lastDiscovery: Date

    /// Get visible sources in priority order
    var visibleSources: [ConnectedSleepSource] {
        connectedSources
            .filter { visibleSourceIds.contains($0.bundleId) }
            .sorted { $0.priority < $1.priority }
    }

    /// Check if a source is visible
    func isVisible(_ bundleId: String) -> Bool {
        visibleSourceIds.contains(bundleId)
    }
}

/// Information about a connected sleep data source
struct ConnectedSleepSource: Codable, Identifiable, Equatable, Hashable {
    let id: String                 // Bundle ID
    let bundleId: String
    let name: String               // Human-readable name
    let wearableType: String       // WearableType raw value
    let deviceModel: String?       // Specific model if known
    let lastSyncDate: Date?
    let priority: Int              // Display priority (lower = higher priority)
    let hrvCapability: String      // DeviceHRVCapability raw value
    let hasSleepStages: Bool
    let hasNativeScore: Bool

    var id_: String { bundleId }

    /// SF Symbol icon name
    var iconName: String {
        switch wearableType {
        case "Apple Watch": return "applewatch"
        case "Oura Ring": return "circle.hexagongrid.circle"
        case "Garmin": return "figure.outdoor.cycle"
        case "Fitbit": return "figure.run"
        case "WHOOP": return "waveform.circle"
        default: return "app.connected.to.app.below.fill"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
    }
}

// MARK: - Convex Sync Payloads

/// Payload for syncing sleep score to Convex
struct SleepScoreSyncPayload: Codable {
    let date: String
    let zoeScore: Int
    let componentsJson: String     // JSON-encoded ZoeScoreComponents
    let nativeScoresJson: String?  // JSON-encoded dictionary
    let hrvCharge: Int?
    let hrvChargeTrajectory: String?
    let primarySource: String
    let allSourcesJson: String?
    let confidence: Double
    let computedAt: Int64

    init(from result: ZoeSleepScoreResult) throws {
        self.date = result.date
        self.zoeScore = result.zoeScore

        let encoder = JSONEncoder()
        self.componentsJson = String(data: try encoder.encode(result.components), encoding: .utf8) ?? "{}"

        // Encode device scores as dictionary
        var nativeDict: [String: Int] = [:]
        for deviceScore in result.deviceScores {
            if let native = deviceScore.nativeScore {
                nativeDict[deviceScore.deviceName] = native
            }
        }
        if !nativeDict.isEmpty {
            self.nativeScoresJson = String(data: try encoder.encode(nativeDict), encoding: .utf8)
        } else {
            self.nativeScoresJson = nil
        }

        self.hrvCharge = result.hrvCharge
        self.hrvChargeTrajectory = result.hrvChargeTrajectory
        self.primarySource = result.primarySource

        if !result.allSources.isEmpty {
            self.allSourcesJson = String(data: try encoder.encode(result.allSources), encoding: .utf8)
        } else {
            self.allSourcesJson = nil
        }

        self.confidence = result.confidence
        self.computedAt = Int64(result.computedAt.timeIntervalSince1970 * 1000)
    }
}

/// Payload for syncing source preferences to Convex
struct SourcePreferencesSyncPayload: Codable {
    let connectedSourcesJson: String
    let visibleSourcesJson: String
    let priorityOverrideJson: String?
    let lastSourceDiscovery: Int64

    init(from prefs: SleepSourcePreferences) throws {
        let encoder = JSONEncoder()
        self.connectedSourcesJson = String(data: try encoder.encode(prefs.connectedSources), encoding: .utf8) ?? "[]"
        self.visibleSourcesJson = String(data: try encoder.encode(prefs.visibleSourceIds), encoding: .utf8) ?? "[]"
        if let override = prefs.priorityOverride {
            self.priorityOverrideJson = String(data: try encoder.encode(override), encoding: .utf8)
        } else {
            self.priorityOverrideJson = nil
        }
        self.lastSourceDiscovery = Int64(prefs.lastDiscovery.timeIntervalSince1970 * 1000)
    }
}

// MARK: - Score History

/// Historical sleep score for trend display
struct SleepScoreHistoryDay: Identifiable, Codable, Equatable {
    let id: String                 // Date YYYY-MM-DD
    let date: String
    let zoeScore: Int?
    let hrvCharge: Int?
    let primarySource: String?
    let dayOfWeek: Int             // 1 = Sunday, 7 = Saturday

    var id_: String { date }

    /// Whether this day has any score data
    var hasData: Bool {
        zoeScore != nil || hrvCharge != nil
    }
}

/// Weekly score summary for dashboard
struct WeeklySleepScoreSummary: Codable, Equatable {
    let weekStartDate: String      // YYYY-MM-DD (Sunday)
    let avgZoeScore: Int?
    let avgHrvCharge: Int?
    let daysWithData: Int
    let bestDay: String?           // Date of highest score
    let worstDay: String?          // Date of lowest score
    let trend: ScoreTrend
}

/// Score trend direction
enum ScoreTrend: String, Codable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
    case insufficient = "insufficient_data"

    var label: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        case .insufficient: return "More data needed"
        }
    }

    var iconName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        case .insufficient: return "questionmark"
        }
    }
}
