//
//  MockDataTypes.swift
//  ZoeSleep
//
//  Development-only types for mock data generation
//  Allows rapid testing of 14-day questionnaire flow
//

#if DEBUG

import Foundation

// MARK: - Configuration

/// Configuration for mock data generation
struct MockGeneratorConfig {
    /// Delay between questions (seconds) - controls playback speed
    var questionDelay: TimeInterval = 0.1

    /// Range of days to generate (1-14 for full 2-week coverage)
    var dayRange: ClosedRange<Int> = 1...14

    /// Probability that a gateway question triggers (0.0-1.0)
    /// At 0.4, roughly 4-6 of 10 gateways will trigger
    var gatewayTriggerProbability: Double = 0.4

    /// Random seed for reproducible results (nil = random each time)
    var randomSeed: UInt64? = nil
}

// MARK: - State Machine

/// States for the mock generation process
enum MockGeneratorState: Equatable {
    case idle
    case preparing
    case generatingDay(Int)
    case savingDay(Int)
    case transitioning(from: Int, to: Int)
    case computingScores  // Calculating and persisting clinical scores
    case completed
    case cancelled
    case failed(String)

    static func == (lhs: MockGeneratorState, rhs: MockGeneratorState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparing, .preparing),
             (.computingScores, .computingScores),
             (.completed, .completed),
             (.cancelled, .cancelled):
            return true
        case (.generatingDay(let l), .generatingDay(let r)):
            return l == r
        case (.savingDay(let l), .savingDay(let r)):
            return l == r
        case (.transitioning(let lFrom, let lTo), .transitioning(let rFrom, let rTo)):
            return lFrom == rFrom && lTo == rTo
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }

    var isActive: Bool {
        switch self {
        case .preparing, .generatingDay, .savingDay, .transitioning, .computingScores:
            return true
        default:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Ready to generate"
        case .preparing:
            return "Resetting progress..."
        case .generatingDay(let day):
            return "Day \(day)"
        case .savingDay(let day):
            return "Saving Day \(day)..."
        case .transitioning(let from, let to):
            return "Day \(from) → \(to)"
        case .computingScores:
            return "Computing scores..."
        case .completed:
            return "Complete!"
        case .cancelled:
            return "Cancelled"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
}

// MARK: - Progress Tracking

/// Tracks real-time progress during mock data generation
struct MockGenerationProgress {
    var currentDay: Int = 0
    var totalDays: Int = 14

    var currentSection: String = ""  // "Sleep Log" or "Assessment"
    var currentQuestionIndex: Int = 0
    var totalQuestionsForSection: Int = 0

    var currentQuestionId: String = ""
    var currentQuestionText: String = ""
    var currentAnswer: String = ""

    var triggeredGateways: [GatewayType] = []

    var totalQuestionsAnswered: Int = 0
    var startTime: Date = Date()

    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var dayProgress: Double {
        guard totalDays > 0 else { return 0 }
        return Double(currentDay) / Double(totalDays)
    }

    var sectionProgress: Double {
        guard totalQuestionsForSection > 0 else { return 0 }
        return Double(currentQuestionIndex) / Double(totalQuestionsForSection)
    }

    mutating func reset() {
        currentDay = 0
        currentSection = ""
        currentQuestionIndex = 0
        totalQuestionsForSection = 0
        currentQuestionId = ""
        currentQuestionText = ""
        currentAnswer = ""
        triggeredGateways = []
        totalQuestionsAnswered = 0
        startTime = Date()
    }
}

// MARK: - Generated Response

/// Represents a generated mock response ready to save
struct MockResponse {
    let questionId: String
    let dayNumber: Int
    let answerFormat: String
    let stringValue: String?
    let numberValue: Double?
    let arrayValue: [String]?
    let objectValue: String?

    /// Convert to dictionary for ConvexService.saveResponses()
    /// Uses Convex field names: responseValue, responseNumber, responseArray
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "questionId": questionId
        ]

        // Convex expects these field names
        if let str = stringValue {
            dict["responseValue"] = str
        }
        if let num = numberValue {
            dict["responseNumber"] = num
        }
        if let arr = arrayValue {
            dict["responseArray"] = arr
        }
        // Note: objectValue not supported by watch:saveResponses - handle separately if needed

        return dict
    }
}

// MARK: - Sleep Time Ranges

/// Realistic sleep time ranges for mock data
struct SleepTimeRanges {
    // Bedtime: 9:30 PM - 12:30 AM
    static let bedtimeHourRange = 21...24
    static let bedtimeMinuteRange = 0...59

    // Sleep attempt: usually 0-30 min after getting in bed
    static let sleepAttemptDelayMinutes = 0...30

    // Sleep latency (time to fall asleep): 5-60 minutes
    static let latencyMinutesRange = 5...60

    // Number of awakenings: 0-5
    static let awakeningsRange = 0...5

    // Wake after sleep onset (WASO): 0-90 minutes
    static let wasoMinutesRange = 0...90

    // Final wake time: 5:00 AM - 8:00 AM
    static let wakeHourRange = 5...8
    static let wakeMinuteRange = 0...59

    // Quality and refreshed ratings: 2-5 (avoiding extremes)
    static let qualityRange = 2...5
    static let refreshedRange = 2...5
}

#endif
