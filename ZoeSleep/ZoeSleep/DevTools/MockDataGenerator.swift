//
//  MockDataGenerator.swift
//  ZoeSleep
//
//  Generates plausible mock answers for questionnaire testing
//  Creates realistic sleep data patterns for 14-day journey
//

#if DEBUG

import Foundation

/// Generates realistic mock answers for questionnaire questions
class MockDataGenerator {

    // MARK: - Properties

    private let config: MockGeneratorConfig
    private var randomGenerator: RandomNumberGenerator

    /// Track which gateways we've decided to trigger
    private(set) var gatewaysToTrigger: Set<GatewayType> = []

    // MARK: - Initialization

    init(config: MockGeneratorConfig = MockGeneratorConfig()) {
        self.config = config

        if let seed = config.randomSeed {
            self.randomGenerator = SeededRandomNumberGenerator(seed: seed)
        } else {
            self.randomGenerator = SystemRandomNumberGenerator()
        }

        // Pre-determine which gateways will trigger (for consistency)
        for gateway in GatewayType.allCases {
            if Double.random(in: 0...1, using: &randomGenerator) < config.gatewayTriggerProbability {
                gatewaysToTrigger.insert(gateway)
            }
        }
    }

    // MARK: - Main Generation Method

    /// Generate a mock answer for a given question
    func generateAnswer(for question: Question, dayNumber: Int) -> MockResponse {
        let (stringValue, numberValue, arrayValue, objectValue) = generateValue(for: question, dayNumber: dayNumber)

        return MockResponse(
            questionId: question.id,
            dayNumber: dayNumber,
            answerFormat: answerFormat(for: question.questionType),
            stringValue: stringValue,
            numberValue: numberValue,
            arrayValue: arrayValue,
            objectValue: objectValue
        )
    }

    /// Get display string for an answer (for UI feedback)
    func displayValue(for response: MockResponse) -> String {
        if let str = response.stringValue {
            return str
        }
        if let num = response.numberValue {
            if num == floor(num) {
                return String(Int(num))
            }
            return String(format: "%.1f", num)
        }
        if let arr = response.arrayValue, !arr.isEmpty {
            return arr.joined(separator: ", ")
        }
        return "—"
    }

    // MARK: - Value Generation by Type

    private func generateValue(for question: Question, dayNumber: Int) -> (String?, Double?, [String]?, String?) {
        // Check for special sleep log questions first
        if let sleepLogValue = generateSleepLogValue(for: question.id, dayNumber: dayNumber) {
            return sleepLogValue
        }

        // Generate based on question type
        switch question.questionType {
        case .time:
            return generateTimeValue(for: question)

        case .date:
            return generateDateValue(for: question)

        case .minutesScroll:
            return generateMinutesValue(for: question)

        case .numberScroll, .number:
            return generateNumberValue(for: question)

        case .scale:
            return generateScaleValue(for: question)

        case .yesNo:
            return generateYesNoValue(for: question)

        case .yesNoDontKnow:
            return generateYesNoDontKnowValue(for: question)

        case .singleSelect:
            return generateSingleSelectValue(for: question)

        case .multiSelect:
            return generateMultiSelectValue(for: question)

        case .text:
            return generateTextValue(for: question)

        case .email:
            return ("test@example.com", nil, nil, nil)

        case .info:
            return ("acknowledged", nil, nil, nil)

        case .repeatingGroup:
            return generateRepeatingGroupValue(for: question)
        }
    }

    // MARK: - Sleep Log Specific Values

    /// Generate contextually appropriate sleep log values
    private func generateSleepLogValue(for questionId: String, dayNumber: Int) -> (String?, Double?, [String]?, String?)? {
        // Day-to-day variation can be applied to values if needed
        _ = dayNumber // Used for contextual variation

        switch questionId {
        case "CSD_DAY_TYPE":
            let options = ["Work day", "Work day", "Work day", "Work day", "Day off", "Vacation"]
            let index = Int.random(in: 0..<options.count, using: &randomGenerator)
            return (options[index], nil, nil, nil)

        case "CSD_INTO_BED":
            // Bedtime: 9:30 PM - 12:00 AM with variation
            let hour = Int.random(in: 21...23, using: &randomGenerator)
            let minute = [0, 15, 30, 45].randomElement(using: &randomGenerator) ?? 30
            return (formatTime(hour: hour, minute: minute), nil, nil, nil)

        case "CSD_TRY_SLEEP":
            // Usually 5-30 min after getting in bed
            let hour = Int.random(in: 22...24, using: &randomGenerator)
            let minute = [0, 15, 30, 45].randomElement(using: &randomGenerator) ?? 0
            let adjustedHour = hour >= 24 ? hour - 24 : hour
            return (formatTime(hour: adjustedHour, minute: minute), nil, nil, nil)

        case "CSD_LATENCY":
            // Sleep latency: 5-45 minutes (higher if insomnia triggered)
            let baseLatency = Int.random(in: 5...30, using: &randomGenerator)
            let insomniaBonus = gatewaysToTrigger.contains(.insomnia) ? Int.random(in: 15...45, using: &randomGenerator) : 0
            let latency = min(baseLatency + insomniaBonus, 120)
            return (nil, Double(latency), nil, nil)

        case "CSD_AWAKENINGS":
            // Awakenings: 0-4 times
            let base = Int.random(in: 0...3, using: &randomGenerator)
            let extra = gatewaysToTrigger.contains(.insomnia) ? Int.random(in: 0...2, using: &randomGenerator) : 0
            return (nil, Double(base + extra), nil, nil)

        case "CSD_WASO":
            // Wake after sleep onset: 0-60 minutes
            let base = Int.random(in: 0...30, using: &randomGenerator)
            let extra = gatewaysToTrigger.contains(.insomnia) ? Int.random(in: 10...40, using: &randomGenerator) : 0
            return (nil, Double(base + extra), nil, nil)

        case "CSD_FINAL_WAKE":
            // Final wake: 5:30 AM - 7:30 AM
            let hour = Int.random(in: 5...7, using: &randomGenerator)
            let minute = [0, 15, 30, 45].randomElement(using: &randomGenerator) ?? 30
            return (formatTime(hour: hour, minute: minute), nil, nil, nil)

        case "CSD_OUT_BED":
            // Out of bed: 6:00 AM - 8:00 AM
            let hour = Int.random(in: 6...8, using: &randomGenerator)
            let minute = [0, 15, 30, 45].randomElement(using: &randomGenerator) ?? 0
            return (formatTime(hour: hour, minute: minute), nil, nil, nil)

        case "CSD_QUALITY":
            // Quality: 1-5 scale, biased based on gateways
            let base = gatewaysToTrigger.contains(.poorSleepQuality) ? 2 : 3
            let value = max(1, min(5, base + Int.random(in: -1...1, using: &randomGenerator)))
            return (nil, Double(value), nil, nil)

        case "CSD_REFRESHED":
            // Refreshed: 1-5 scale
            let base = gatewaysToTrigger.contains(.excessiveSleepiness) ? 2 : 3
            let value = max(1, min(5, base + Int.random(in: -1...1, using: &randomGenerator)))
            return (nil, Double(value), nil, nil)

        case "CSD_NAPS":
            // Naps more likely if sleepy
            let napped = gatewaysToTrigger.contains(.excessiveSleepiness) ?
                Double.random(in: 0...1, using: &randomGenerator) < 0.6 :
                Double.random(in: 0...1, using: &randomGenerator) < 0.3
            return (napped ? "Yes" : "No", nil, nil, nil)

        default:
            return nil
        }
    }

    // MARK: - Generic Type Generators

    private func generateTimeValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        // Default time range: 10 PM - 7 AM for sleep-related
        let hour = Int.random(in: 6...23, using: &randomGenerator)
        let minute = [0, 15, 30, 45].randomElement(using: &randomGenerator) ?? 0
        return (formatTime(hour: hour, minute: minute), nil, nil, nil)
    }

    private func generateDateValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        // Birth date: 25-65 years ago
        let yearsAgo = Int.random(in: 25...65, using: &randomGenerator)
        let month = Int.random(in: 1...12, using: &randomGenerator)
        let day = Int.random(in: 1...28, using: &randomGenerator)
        let year = Calendar.current.component(.year, from: Date()) - yearsAgo

        let dateString = String(format: "%04d-%02d-%02d", year, month, day)
        return (dateString, nil, nil, nil)
    }

    private func generateMinutesValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        let min = question.minValue ?? 0
        let max = question.maxValue ?? 120
        let value = Int.random(in: min...max, using: &randomGenerator)
        return (nil, Double(value), nil, nil)
    }

    private func generateNumberValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        let min = question.minValue ?? 0
        let max = question.maxValue ?? 10
        let value = Int.random(in: min...max, using: &randomGenerator)
        return (nil, Double(value), nil, nil)
    }

    private func generateScaleValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        let scaleMin = question.scaleMin ?? 1
        let scaleMax = question.scaleMax ?? 5

        // Check if this is a gateway question
        if question.isGateway, let gatewayType = question.gatewayType {
            let shouldTrigger = gatewaysToTrigger.contains(gatewayType)
            let threshold = question.gatewayThreshold ?? Double(scaleMax - 1)

            if shouldTrigger {
                // Value above threshold to trigger
                let triggerMin = Int(threshold)
                let value = Int.random(in: triggerMin...scaleMax, using: &randomGenerator)
                return (nil, Double(value), nil, nil)
            } else {
                // Value below threshold
                let safeMax = max(scaleMin, Int(threshold) - 1)
                let value = Int.random(in: scaleMin...safeMax, using: &randomGenerator)
                return (nil, Double(value), nil, nil)
            }
        }

        // Non-gateway: bias toward middle values
        let range = scaleMax - scaleMin
        let midPoint = scaleMin + range / 2
        let value = midPoint + Int.random(in: -range/3...range/3, using: &randomGenerator)
        let clampedValue = max(scaleMin, min(scaleMax, value))
        return (nil, Double(clampedValue), nil, nil)
    }

    private func generateYesNoValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        // Check if this is a gateway question
        if question.isGateway, let gatewayType = question.gatewayType {
            let shouldTrigger = gatewaysToTrigger.contains(gatewayType)
            return (shouldTrigger ? "Yes" : "No", nil, nil, nil)
        }

        // 50/50 split for non-gateway
        let isYes = Bool.random(using: &randomGenerator)
        return (isYes ? "Yes" : "No", nil, nil, nil)
    }

    private func generateYesNoDontKnowValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        // 15% Don't know, rest split
        let roll = Double.random(in: 0...1, using: &randomGenerator)
        if roll < 0.15 {
            return ("Don't know", nil, nil, nil)
        }
        return generateYesNoValue(for: question)
    }

    private func generateSingleSelectValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        guard let options = question.options, !options.isEmpty else {
            return ("Option 1", nil, nil, nil)
        }

        // Check if this is a gateway question
        if question.isGateway, let gatewayType = question.gatewayType {
            let shouldTrigger = gatewaysToTrigger.contains(gatewayType)
            let threshold = Int(question.gatewayThreshold ?? Double(options.count - 1))

            if shouldTrigger && threshold < options.count {
                // Select option at or above threshold
                let triggerIndex = Int.random(in: threshold..<options.count, using: &randomGenerator)
                return (options[triggerIndex], nil, nil, nil)
            } else {
                // Select option below threshold
                let safeMax = max(0, threshold - 1)
                let safeIndex = Int.random(in: 0...safeMax, using: &randomGenerator)
                return (options[min(safeIndex, options.count - 1)], nil, nil, nil)
            }
        }

        // Random selection for non-gateway
        let index = Int.random(in: 0..<options.count, using: &randomGenerator)
        return (options[index], nil, nil, nil)
    }

    private func generateMultiSelectValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        guard let options = question.options, !options.isEmpty else {
            return (nil, nil, ["Option 1"], nil)
        }

        // Select 1-3 random options
        let count = min(options.count, Int.random(in: 1...3, using: &randomGenerator))
        let shuffled = options.shuffled(using: &randomGenerator)
        let selected = Array(shuffled.prefix(count))
        return (nil, nil, selected, nil)
    }

    private func generateTextValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        // Context-aware text generation based on question ID
        let questionId = question.id.lowercased()

        // D1 is the patient name question in demographics
        if questionId == "d1" || questionId.contains("name") {
            return ("Test Patient", nil, nil, nil)
        }
        if questionId.contains("medication") || questionId.contains("medicine") {
            return ("Melatonin 3mg", nil, nil, nil)
        }
        if questionId.contains("comment") || questionId.contains("note") {
            return ("No additional comments", nil, nil, nil)
        }
        if questionId.contains("occupation") || questionId.contains("job") {
            return ("Software Engineer", nil, nil, nil)
        }

        return ("N/A", nil, nil, nil)
    }

    private func generateRepeatingGroupValue(for question: Question) -> (String?, Double?, [String]?, String?) {
        // Generate 1-2 items for repeating groups
        guard let fields = question.repeatingFields else {
            return (nil, nil, nil, "[]")
        }

        var items: [[String: Any]] = []
        let itemCount = Int.random(in: 1...2, using: &randomGenerator)

        for _ in 0..<itemCount {
            var item: [String: Any] = [:]
            for field in fields {
                switch field.type {
                case .text:
                    item[field.id] = "Item"
                case .number, .numberScroll:
                    let min = field.minValue ?? 0
                    let max = field.maxValue ?? 10
                    item[field.id] = Int.random(in: min...max, using: &randomGenerator)
                case .time:
                    item[field.id] = "12:00"
                default:
                    item[field.id] = ""
                }
            }
            items.append(item)
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: items),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return (nil, nil, nil, jsonString)
        }

        return (nil, nil, nil, "[]")
    }

    // MARK: - Helpers

    private func formatTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private func answerFormat(for type: QuestionType) -> String {
        switch type {
        case .time: return "time_picker"
        case .date: return "date_picker"
        case .minutesScroll: return "minutes_scroll"
        case .numberScroll, .number: return "number_scroll"
        case .scale: return "slider_scale"
        case .yesNo, .yesNoDontKnow: return "single_select_chips"
        case .singleSelect: return "single_select_chips"
        case .multiSelect: return "multi_select_chips"
        case .text, .email: return "text_input"
        case .info: return "info"
        case .repeatingGroup: return "repeating_group"
        }
    }
}

// MARK: - Seeded Random Number Generator

/// Allows reproducible random sequences for testing
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // Simple xorshift64 algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

#endif
