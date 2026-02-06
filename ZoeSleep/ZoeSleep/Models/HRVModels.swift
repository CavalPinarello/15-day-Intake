//
//  HRVModels.swift
//  Zoe Sleep for Longevity System
//
//  Models for HRV (Heart Rate Variability) tracking and recovery metrics
//

import Foundation

// MARK: - HRV Sample Types

/// Type of HRV measurement based on time of day
enum HRVSampleType: String, Codable, CaseIterable {
    case evening = "evening"           // 2-3 hours before bed
    case intraNight = "intra_night"    // During sleep
    case morning = "morning"           // Within 30 mins of wake
}

/// Device capability for HRV measurements
enum DeviceHRVCapability: String, Codable, CaseIterable {
    case fullIntraNight = "full"       // Oura, WHOOP - samples every 5-15 mins
    case periodicSleep = "periodic"    // Apple Watch - less frequent during sleep
    case morningOnly = "morning_only"  // Garmin, Fitbit - single morning reading
    case none = "none"                 // No HRV support

    /// Human-readable description
    var description: String {
        switch self {
        case .fullIntraNight:
            return "Full night HRV tracking"
        case .periodicSleep:
            return "Periodic sleep HRV"
        case .morningOnly:
            return "Morning HRV only"
        case .none:
            return "No HRV data"
        }
    }

    /// Whether this capability supports recovery curve visualization
    var supportsRecoveryCurve: Bool {
        switch self {
        case .fullIntraNight, .periodicSleep:
            return true
        case .morningOnly, .none:
            return false
        }
    }
}

// MARK: - HRV Sample

/// Individual HRV measurement sample
struct HRVSample: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let value: Double              // SDNN in milliseconds
    let sampleType: HRVSampleType
    let sourceBundleId: String
    let wearableType: String       // WearableType raw value
    let isDuringSleep: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date,
        value: Double,
        sampleType: HRVSampleType,
        sourceBundleId: String,
        wearableType: String,
        isDuringSleep: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.sampleType = sampleType
        self.sourceBundleId = sourceBundleId
        self.wearableType = wearableType
        self.isDuringSleep = isDuringSleep
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: HRVSample, rhs: HRVSample) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - HRV Nightly Summary

/// Aggregated HRV data for a single night
struct HRVNightlySummary: Codable, Identifiable {
    let id: String                 // Date string YYYY-MM-DD
    let date: String               // YYYY-MM-DD (wake date)

    // Evening baseline (2-3 hours before bed)
    let eveningAvg: Double?
    let eveningMin: Double?
    let eveningMax: Double?
    let eveningSampleCount: Int

    // Intra-night metrics
    let intraNightAvg: Double?
    let intraNightPeak: Double?
    let peakTime: Date?
    let intraNightSampleCount: Int
    let sampleIntervalMins: Int?   // Avg time between samples

    // Morning metrics (within 30 mins of wake)
    let morningAvg: Double?
    let morningSampleCount: Int

    // Computed recovery metrics
    let recoveryRatio: Double?     // Peak / Evening (1.0 = no change)
    let timeToPeakMins: Int?       // Time from sleep onset to peak HRV

    // Source tracking
    let primarySource: String      // WearableType raw value
    let hrvCapability: DeviceHRVCapability

    var id_: String { date }

    init(
        date: String,
        eveningAvg: Double? = nil,
        eveningMin: Double? = nil,
        eveningMax: Double? = nil,
        eveningSampleCount: Int = 0,
        intraNightAvg: Double? = nil,
        intraNightPeak: Double? = nil,
        peakTime: Date? = nil,
        intraNightSampleCount: Int = 0,
        sampleIntervalMins: Int? = nil,
        morningAvg: Double? = nil,
        morningSampleCount: Int = 0,
        recoveryRatio: Double? = nil,
        timeToPeakMins: Int? = nil,
        primarySource: String,
        hrvCapability: DeviceHRVCapability
    ) {
        self.id = date
        self.date = date
        self.eveningAvg = eveningAvg
        self.eveningMin = eveningMin
        self.eveningMax = eveningMax
        self.eveningSampleCount = eveningSampleCount
        self.intraNightAvg = intraNightAvg
        self.intraNightPeak = intraNightPeak
        self.peakTime = peakTime
        self.intraNightSampleCount = intraNightSampleCount
        self.sampleIntervalMins = sampleIntervalMins
        self.morningAvg = morningAvg
        self.morningSampleCount = morningSampleCount
        self.recoveryRatio = recoveryRatio
        self.timeToPeakMins = timeToPeakMins
        self.primarySource = primarySource
        self.hrvCapability = hrvCapability
    }

    /// Whether there's enough data for meaningful analysis
    var hasMinimumData: Bool {
        eveningSampleCount > 0 || intraNightSampleCount >= 3 || morningSampleCount > 0
    }

    /// Whether full recovery curve can be displayed
    var canShowRecoveryCurve: Bool {
        intraNightSampleCount >= 3 && hrvCapability.supportsRecoveryCurve
    }
}

// MARK: - HRV Charge (Recovery Score)

/// Recovery trajectory classification
enum RecoveryTrajectory: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case moderate = "moderate"
    case poor = "poor"
    case veryLow = "very_low"
    case insufficientData = "insufficient_data"

    /// Display label
    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .moderate: return "Moderate"
        case .poor: return "Poor"
        case .veryLow: return "Very Low"
        case .insufficientData: return "Insufficient Data"
        }
    }

    /// Color name for UI (matches circadian palette)
    var colorName: String {
        switch self {
        case .excellent: return "success"
        case .good: return "primary"
        case .moderate: return "secondary"
        case .poor: return "warning"
        case .veryLow: return "error"
        case .insufficientData: return "textSecondary"
        }
    }

    /// Create from charge score
    static func from(score: Int) -> RecoveryTrajectory {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .moderate
        case 20..<40: return .poor
        case 0..<20: return .veryLow
        default: return .insufficientData
        }
    }
}

/// Baseline type used for HRV Charge calculation
enum HRVBaselineType: String, Codable {
    case personal = "personal"       // 7+ days of user data
    case population = "population"   // Age/sex-adjusted population norms
}

/// Component scores for HRV Charge calculation
struct HRVChargeComponents: Codable, Equatable {
    let eveningComponent: Double?      // 0-100 score from evening HRV vs baseline
    let recoveryComponent: Double?     // 0-100 score from recovery ratio
    let trendModifier: Double?         // Multiplier based on personal trend
    let eveningHRVUsed: Double?        // Actual evening HRV value used
    let peakHRVUsed: Double?           // Actual peak HRV value used
    let morningHRVUsed: Double?        // Actual morning HRV value used
}

/// HRV Charge result - the main recovery metric
struct HRVChargeResult: Codable, Identifiable, Equatable {
    let id: String                     // Date string YYYY-MM-DD
    let date: String                   // YYYY-MM-DD
    let chargeScore: Int               // 0-100
    let recoveryTrajectory: RecoveryTrajectory
    let confidence: Double             // 0.0-1.0 based on data quality
    let components: HRVChargeComponents
    let baselineType: HRVBaselineType
    let deviationFromBaseline: Double? // How far from personal baseline
    let computedAt: Date

    var id_: String { date }

    init(
        date: String,
        chargeScore: Int,
        recoveryTrajectory: RecoveryTrajectory,
        confidence: Double,
        components: HRVChargeComponents,
        baselineType: HRVBaselineType,
        deviationFromBaseline: Double? = nil,
        computedAt: Date = Date()
    ) {
        self.id = date
        self.date = date
        self.chargeScore = chargeScore
        self.recoveryTrajectory = recoveryTrajectory
        self.confidence = confidence
        self.components = components
        self.baselineType = baselineType
        self.deviationFromBaseline = deviationFromBaseline
        self.computedAt = computedAt
    }

    static func == (lhs: HRVChargeResult, rhs: HRVChargeResult) -> Bool {
        lhs.id == rhs.id && lhs.chargeScore == rhs.chargeScore
    }
}

// MARK: - Personal HRV Baseline

/// Rolling 7-day personal HRV baseline for personalized scoring
struct PersonalHRVBaseline: Codable, Equatable {
    let avgEveningHRV: Double
    let avgMorningHRV: Double
    let avgPeakHRV: Double
    let avgRecoveryRatio: Double

    let stdEveningHRV: Double          // Standard deviation for trend detection
    let stdMorningHRV: Double

    let daysInBaseline: Int            // 1-7+ days
    let oldestDate: String             // YYYY-MM-DD
    let newestDate: String             // YYYY-MM-DD
    let lastUpdated: Date

    /// Whether baseline is mature enough for personalized scoring
    var isPersonalized: Bool {
        daysInBaseline >= 7
    }

    /// Confidence multiplier based on baseline maturity
    var confidenceMultiplier: Double {
        switch daysInBaseline {
        case 0..<3: return 0.5
        case 3..<5: return 0.7
        case 5..<7: return 0.85
        default: return 1.0
        }
    }
}

// MARK: - Population Norms

/// Age and sex-adjusted HRV norms for cold start
struct PopulationHRVNorms {
    /// Average SDNN by age and sex (based on Shaffer et al. 2014 meta-analysis)
    static func baselineSDNN(age: Int, sex: String?) -> Double {
        // Base HRV values (SDNN in ms)
        let baseHRV: Double = (sex?.lowercased() == "male") ? 52.0 : 47.0

        // HRV decreases ~3-4ms per decade after age 30
        let ageFactor = max(0.6, 1.0 - (Double(max(0, age - 30)) / 100.0))

        return baseHRV * ageFactor
    }

    /// Expected healthy recovery ratio range by age
    static func healthyRecoveryRatioRange(age: Int) -> ClosedRange<Double> {
        // Younger adults show higher recovery ratios
        if age < 30 { return 1.20...1.50 }
        if age < 50 { return 1.15...1.40 }
        return 1.10...1.30
    }

    /// Create a pseudo-baseline from population norms
    static func pseudoBaseline(age: Int, sex: String?) -> PersonalHRVBaseline {
        let baseHRV = baselineSDNN(age: age, sex: sex)
        let recoveryRange = healthyRecoveryRatioRange(age: age)
        let avgRecoveryRatio = (recoveryRange.lowerBound + recoveryRange.upperBound) / 2

        return PersonalHRVBaseline(
            avgEveningHRV: baseHRV * 0.9,       // Evening typically ~10% lower
            avgMorningHRV: baseHRV,
            avgPeakHRV: baseHRV * avgRecoveryRatio,
            avgRecoveryRatio: avgRecoveryRatio,
            stdEveningHRV: baseHRV * 0.15,     // ~15% standard deviation
            stdMorningHRV: baseHRV * 0.15,
            daysInBaseline: 0,
            oldestDate: "",
            newestDate: "",
            lastUpdated: Date()
        )
    }
}

// MARK: - Chart Data Models

/// Data point for HRV recovery curve chart
struct HRVCurveDataPoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let label: String?             // Optional label (e.g., "Peak")

    static func == (lhs: HRVCurveDataPoint, rhs: HRVCurveDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

/// HRV trend data for 7-day view
struct HRVTrendDay: Identifiable, Codable, Equatable {
    let id: String                 // Date YYYY-MM-DD
    let date: String
    let chargeScore: Int?
    let eveningHRV: Double?
    let morningHRV: Double?
    let recoveryRatio: Double?

    var id_: String { date }
}

// MARK: - Convex Sync Models

/// Data structure for syncing HRV samples to Convex
struct HRVSampleSyncPayload: Codable {
    let date: String               // YYYY-MM-DD
    let sampleTime: Int64          // Unix timestamp in ms
    let hrvValue: Double
    let sampleType: String         // HRVSampleType raw value
    let source: String             // WearableType raw value
    let sourceBundleId: String
    let isDuringSleep: Bool

    init(from sample: HRVSample, date: String) {
        self.date = date
        self.sampleTime = Int64(sample.timestamp.timeIntervalSince1970 * 1000)
        self.hrvValue = sample.value
        self.sampleType = sample.sampleType.rawValue
        self.source = sample.wearableType
        self.sourceBundleId = sample.sourceBundleId
        self.isDuringSleep = sample.isDuringSleep
    }
}

/// Data structure for syncing HRV nightly summary to Convex
struct HRVNightlySummarySyncPayload: Codable {
    let date: String
    let eveningHrvAvg: Double?
    let eveningHrvMin: Double?
    let eveningHrvMax: Double?
    let eveningSampleCount: Int
    let intraNightHrvAvg: Double?
    let intraNightHrvPeak: Double?
    let peakTime: Int64?           // Unix timestamp in ms
    let sampleCount: Int
    let sampleIntervalMins: Int?
    let morningHrvAvg: Double?
    let morningSampleCount: Int
    let recoveryRatio: Double?
    let timeToPeakMins: Int?
    let primarySource: String
    let hrvCapability: String

    init(from summary: HRVNightlySummary) {
        self.date = summary.date
        self.eveningHrvAvg = summary.eveningAvg
        self.eveningHrvMin = summary.eveningMin
        self.eveningHrvMax = summary.eveningMax
        self.eveningSampleCount = summary.eveningSampleCount
        self.intraNightHrvAvg = summary.intraNightAvg
        self.intraNightHrvPeak = summary.intraNightPeak
        self.peakTime = summary.peakTime.map { Int64($0.timeIntervalSince1970 * 1000) }
        self.sampleCount = summary.intraNightSampleCount
        self.sampleIntervalMins = summary.sampleIntervalMins
        self.morningHrvAvg = summary.morningAvg
        self.morningSampleCount = summary.morningSampleCount
        self.recoveryRatio = summary.recoveryRatio
        self.timeToPeakMins = summary.timeToPeakMins
        self.primarySource = summary.primarySource
        self.hrvCapability = summary.hrvCapability.rawValue
    }
}

/// Data structure for syncing HRV Charge to Convex
struct HRVChargeSyncPayload: Codable {
    let date: String
    let chargeScore: Int
    let recoveryTrajectory: String
    let confidence: Double
    let eveningComponent: Double?
    let recoveryComponent: Double?
    let trendModifier: Double?
    let eveningHrvUsed: Double?
    let peakHrvUsed: Double?
    let morningHrvUsed: Double?
    let baselineUsed: String
    let deviationFromBaseline: Double?
    let computedAt: Int64

    init(from result: HRVChargeResult) {
        self.date = result.date
        self.chargeScore = result.chargeScore
        self.recoveryTrajectory = result.recoveryTrajectory.rawValue
        self.confidence = result.confidence
        self.eveningComponent = result.components.eveningComponent
        self.recoveryComponent = result.components.recoveryComponent
        self.trendModifier = result.components.trendModifier
        self.eveningHrvUsed = result.components.eveningHRVUsed
        self.peakHrvUsed = result.components.peakHRVUsed
        self.morningHrvUsed = result.components.morningHRVUsed
        self.baselineUsed = result.baselineType.rawValue
        self.deviationFromBaseline = result.deviationFromBaseline
        self.computedAt = Int64(result.computedAt.timeIntervalSince1970 * 1000)
    }
}
