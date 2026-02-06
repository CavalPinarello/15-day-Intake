//
//  VoiceInputModels.swift
//  ZoeSleep
//
//  Data models for Easy Mode voice input system
//  Handles voice recording states, transcription results, and parsing
//

import Foundation

// MARK: - Voice Input State

/// Represents the current state of voice input
enum VoiceInputState: Equatable {
    case idle                   // Waiting for user to press mic button
    case listening              // Recording audio
    case processing             // Sending audio to Whisper for transcription
    case parsing                // LLM parsing complex responses
    case confirming(ParsedResponse)  // Showing result for user confirmation
    case error(VoiceError)      // Error state with retry option

    var isRecording: Bool {
        self == .listening
    }

    var isProcessing: Bool {
        switch self {
        case .processing, .parsing:
            return true
        default:
            return false
        }
    }

    var isConfirming: Bool {
        if case .confirming = self {
            return true
        }
        return false
    }

    var statusMessage: String {
        switch self {
        case .idle:
            return "Hold to speak"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .parsing:
            return "Understanding..."
        case .confirming:
            return "Is this correct?"
        case .error(let error):
            return error.userMessage
        }
    }
}

// MARK: - Voice Errors

/// Errors that can occur during voice input
enum VoiceError: Error, Equatable {
    case networkError
    case timeout
    case microphonePermissionDenied
    case noAudioRecorded
    case audioTooShort
    case transcriptionFailed(String)
    case parsingFailed(String)
    case lowConfidence(String, Double)  // transcript, confidence
    case noUser
    case serializationFailed
    case invalidResponse

    var userMessage: String {
        switch self {
        case .networkError:
            return "No internet connection. Please check your connection and try again."
        case .timeout:
            return "Taking too long. Let's try again."
        case .microphonePermissionDenied:
            return "Please allow microphone access in Settings to use voice input."
        case .noAudioRecorded:
            return "I didn't hear anything. Please try again."
        case .audioTooShort:
            return "Recording too short. Please speak longer."
        case .transcriptionFailed(let reason):
            return "Couldn't understand. \(reason)"
        case .parsingFailed(let reason):
            return "Had trouble understanding. \(reason)"
        case .lowConfidence(_, _):
            return "I'm not quite sure I understood. Did you say this?"
        case .noUser:
            return "Please sign in to continue."
        case .serializationFailed:
            return "Something went wrong. Please try again."
        case .invalidResponse:
            return "Unexpected response. Please try again."
        }
    }

    var canRetry: Bool {
        switch self {
        case .microphonePermissionDenied, .noUser:
            return false
        default:
            return true
        }
    }
}

// MARK: - Parsed Response

/// Result of parsing a voice transcript into structured data
struct ParsedResponse: Equatable {
    let transcript: String          // Raw text from Whisper
    let value: ParsedValue          // Structured value
    let confidence: Double          // 0.0 to 1.0
    let alternativeInterpretations: [String]?  // Other possible meanings

    var isHighConfidence: Bool {
        confidence >= 0.85
    }

    var displayValue: String {
        value.displayString
    }
}

/// Represents the parsed value from voice input
enum ParsedValue: Equatable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case time(Date)
    case duration(minutes: Int)
    case array([String])
    case medication([MedicationParsed])
    case caffeine([CaffeineParsed])
    case nap([NapParsed])
    case energyLevel(EnergyLevel)
    case moodLevel(MoodLevel)
    case focusLevel(FocusLevel)
    case unknown

    var displayString: String {
        switch self {
        case .string(let s):
            return s
        case .number(let n):
            return n.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(n))
                : String(format: "%.1f", n)
        case .boolean(let b):
            return b ? "Yes" : "No"
        case .time(let date):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        case .duration(let minutes):
            if minutes >= 60 {
                let hours = minutes / 60
                let mins = minutes % 60
                return mins > 0 ? "\(hours) hr \(mins) min" : "\(hours) hour\(hours > 1 ? "s" : "")"
            }
            return "\(minutes) minutes"
        case .array(let arr):
            return arr.joined(separator: ", ")
        case .medication(let meds):
            return meds.map { "\($0.name) \($0.dose ?? "")" }.joined(separator: ", ")
        case .caffeine(let items):
            return items.map { "\($0.quantity) \($0.type)" }.joined(separator: ", ")
        case .nap(let naps):
            return naps.map { "\($0.durationMinutes) min nap" }.joined(separator: ", ")
        case .energyLevel(let level):
            return level.label
        case .moodLevel(let level):
            return level.label
        case .focusLevel(let level):
            return level.label
        case .unknown:
            return "Unknown"
        }
    }

    /// Convert to the format expected by QuestionnaireView responses
    var responseValue: Any {
        switch self {
        case .string(let s): return s
        case .number(let n): return n
        case .boolean(let b): return b ? "Yes" : "No"
        case .time(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        case .duration(let minutes): return minutes
        case .array(let arr): return arr
        case .medication(let meds): return meds.map { $0.toDictionary() }
        case .caffeine(let items): return items.map { $0.toDictionary() }
        case .nap(let naps): return naps.map { $0.toDictionary() }
        case .energyLevel(let level): return level.rawValue
        case .moodLevel(let level): return level.rawValue
        case .focusLevel(let level): return level.rawValue
        case .unknown: return ""
        }
    }
}

// MARK: - Complex Type Parsed Models

/// Parsed medication from voice input
struct MedicationParsed: Equatable, Codable {
    let name: String
    let dose: String?
    let category: String?  // melatonin, prescription, otc, etc.

    func toDictionary() -> [String: String] {
        var dict = ["name": name]
        if let dose = dose { dict["dose"] = dose }
        if let category = category { dict["category"] = category }
        return dict
    }
}

/// Parsed caffeine from voice input
struct CaffeineParsed: Equatable, Codable {
    let type: String      // coffee, tea, soda, etc.
    let quantity: Int
    let unit: String?     // cups, cans, etc.

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type, "quantity": quantity]
        if let unit = unit { dict["unit"] = unit }
        return dict
    }
}

/// Parsed nap from voice input
struct NapParsed: Equatable, Codable {
    let startTime: Date?
    let durationMinutes: Int

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["durationMinutes": durationMinutes]
        if let startTime = startTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            dict["startTime"] = formatter.string(from: startTime)
        }
        return dict
    }
}

// MARK: - Transcription Result

/// Result from Whisper API transcription
struct TranscriptionResult: Codable {
    let text: String
    let language: String?
    let duration: Double?

    /// Normalized transcript (trimmed, lowercased for matching)
    var normalizedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - TTS Request/Response

/// Request for text-to-speech synthesis
struct TTSRequest {
    let text: String
    let voiceId: String
    let speed: Double  // 0.5 to 2.0, default 1.0

    init(text: String, voiceId: String = "default", speed: Double = 0.9) {
        self.text = text
        self.voiceId = voiceId
        self.speed = speed
    }
}

/// Available TTS voice options (curated for elderly users)
struct TTSVoice: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let previewUrl: String?

    static let defaultVoices: [TTSVoice] = [
        TTSVoice(
            id: "rachel",
            name: "Rachel",
            description: "Warm, calm female voice",
            previewUrl: nil
        ),
        TTSVoice(
            id: "adam",
            name: "Adam",
            description: "Clear, friendly male voice",
            previewUrl: nil
        ),
        TTSVoice(
            id: "dorothy",
            name: "Dorothy",
            description: "Gentle, reassuring female voice",
            previewUrl: nil
        )
    ]
}

// MARK: - Retry Tracking

/// Tracks retry attempts for voice input
struct VoiceRetryState {
    var attemptCount: Int = 0
    let maxAttempts: Int = 3

    var canRetry: Bool {
        attemptCount < maxAttempts
    }

    var hint: String? {
        switch attemptCount {
        case 1:
            return "Try speaking a bit slower"
        case 2:
            return "Try saying just the key information"
        default:
            return nil
        }
    }

    mutating func recordAttempt() {
        attemptCount += 1
    }

    mutating func reset() {
        attemptCount = 0
    }
}

// MARK: - Parsing Strategy

/// Strategy for parsing voice transcript based on question type
enum ParsingStrategy {
    case keywordMatch       // For yes/no, simple options
    case numberExtraction   // For scale 1-10, numeric values
    case timeExtraction     // For time questions
    case durationExtraction // For minutes, hours+minutes
    case optionMatching     // For single/multi select with options
    case llmFull           // For complex types (medication, caffeine, naps)
    case directTranscript   // For free text, just use transcript
    case energyLevelParsing // For energy level check-ins
    case moodLevelParsing   // For mood level check-ins
    case focusLevelParsing  // For focus level check-ins

    /// Determine parsing strategy based on question type
    /// Handles both iOS QuestionType raw values ("Yes/No") and server types ("yesNo")
    static func forQuestionType(_ type: String) -> ParsingStrategy {
        // Normalize: convert to lowercase and remove non-alphanumeric chars for comparison
        let normalized = type.lowercased().replacingOccurrences(of: "/", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "'", with: "")

        switch normalized {
        // Yes/No types
        case "yesno", "yes/no":
            return .keywordMatch
        case "yesnodontknow", "yes/no/dontknow", "yesnodont know":
            return .keywordMatch

        // Scale types
        case "scale":
            return .numberExtraction

        // Time types
        case "time":
            return .timeExtraction

        // Duration types
        case "minutesscroll", "hoursminutesscroll":
            return .durationExtraction

        // Selection types
        case "singleselect":
            return .optionMatching
        case "multiselect":
            return .optionMatching

        // Number types
        case "number", "numberscroll":
            return .numberExtraction

        // Complex types requiring LLM
        case "medicationselect", "caffeineselect", "napdetails",
             "prescriptionmedselect", "supplementselect", "surgerydetails":
            return .llmFull

        // Text types
        case "text", "email":
            return .directTranscript

        // Info type (no input needed)
        case "info":
            return .directTranscript

        default:
            print("ParsingStrategy: Unknown type '\(type)' (normalized: '\(normalized)'), using directTranscript")
            return .directTranscript
        }
    }
}

// MARK: - Check-In Level Parsing

/// Helpers for parsing natural language into check-in levels
struct CheckInLevelParser {

    // MARK: - Energy Level Parsing

    /// Parse natural language into EnergyLevel
    /// Returns (level, confidence) or nil if no match
    static func parseEnergyLevel(from transcript: String) -> (EnergyLevel, Double)? {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exhausted / Level 1 (sleepingSeal)
        let exhaustedKeywords = ["exhausted", "dead", "no energy", "can't move", "completely drained",
                                  "wiped out", "burnt out", "running on empty", "dead tired", "about to collapse",
                                  "sleeping seal", "zzz", "level 1", "one", "1"]
        if exhaustedKeywords.contains(where: { normalized.contains($0) }) {
            return (.sleepingSeal, 0.9)
        }

        // Low / Level 2 (turtle)
        let lowKeywords = ["low", "slow", "tired", "sluggish", "dragging", "barely awake",
                           "need coffee", "groggy", "turtle", "level 2", "two", "2"]
        if lowKeywords.contains(where: { normalized.contains($0) }) {
            return (.turtle, 0.9)
        }

        // Okay / Level 3 (cat)
        let okayKeywords = ["okay", "ok", "fine", "alright", "moderate", "meh", "so-so",
                            "not bad", "average", "cat", "level 3", "three", "3"]
        if okayKeywords.contains(where: { normalized.contains($0) }) {
            return (.cat, 0.9)
        }

        // Good / Level 4 (dog)
        let goodKeywords = ["good", "pretty good", "well", "decent", "nice", "positive",
                            "dog", "level 4", "four", "4"]
        if goodKeywords.contains(where: { normalized.contains($0) }) {
            return (.dog, 0.9)
        }

        // High / Level 5 (ostrich)
        let highKeywords = ["high", "very good", "great", "energetic", "awake", "alert",
                            "ostrich", "bird", "level 5", "five", "5"]
        if highKeywords.contains(where: { normalized.contains($0) }) {
            return (.ostrich, 0.9)
        }

        // Energized / Level 6 (rabbit)
        let energizedKeywords = ["energized", "amazing", "fantastic", "bouncing", "incredible",
                                  "on fire", "unstoppable", "super", "excellent", "best",
                                  "rabbit", "hare", "level 6", "six", "6", "max"]
        if energizedKeywords.contains(where: { normalized.contains($0) }) {
            return (.rabbit, 0.9)
        }

        return nil
    }

    // MARK: - Mood Level Parsing

    /// Parse natural language into MoodLevel
    static func parseMoodLevel(from transcript: String) -> (MoodLevel, Double)? {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Stormy / Level 1
        let stormyKeywords = ["terrible", "awful", "horrible", "stormy", "worst", "angry",
                               "furious", "enraged", "really bad", "level 1", "one", "1"]
        if stormyKeywords.contains(where: { normalized.contains($0) }) {
            return (.stormy, 0.9)
        }

        // Rainy / Level 2
        let rainyKeywords = ["sad", "down", "low", "depressed", "rainy", "gloomy", "blue",
                              "not great", "bad", "level 2", "two", "2"]
        if rainyKeywords.contains(where: { normalized.contains($0) }) {
            return (.rainy, 0.9)
        }

        // Cloudy / Level 3
        let cloudyKeywords = ["meh", "neutral", "whatever", "cloudy", "indifferent", "so-so",
                               "okay", "ok", "fine", "alright", "level 3", "three", "3"]
        if cloudyKeywords.contains(where: { normalized.contains($0) }) {
            return (.cloudy, 0.9)
        }

        // Partly Sunny / Level 4
        let partlySunnyKeywords = ["clearing", "better", "improving", "not bad", "pretty good",
                                    "partly sunny", "decent", "level 4", "four", "4"]
        if partlySunnyKeywords.contains(where: { normalized.contains($0) }) {
            return (.partlySunny, 0.9)
        }

        // Sunny / Level 5
        let sunnyKeywords = ["good", "happy", "sunny", "positive", "nice", "pleasant",
                              "content", "level 5", "five", "5"]
        if sunnyKeywords.contains(where: { normalized.contains($0) }) {
            return (.sunny, 0.9)
        }

        // Rainbow / Level 6
        let rainbowKeywords = ["amazing", "fantastic", "incredible", "rainbow", "wonderful",
                                "ecstatic", "overjoyed", "best", "excellent", "great",
                                "level 6", "six", "6"]
        if rainbowKeywords.contains(where: { normalized.contains($0) }) {
            return (.rainbow, 0.9)
        }

        return nil
    }

    // MARK: - Focus Level Parsing

    /// Parse natural language into FocusLevel (5 levels)
    static func parseFocusLevel(from transcript: String) -> (FocusLevel, Double)? {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Foggy / Level 1
        let foggyKeywords = ["foggy", "can't focus", "scattered", "all over", "completely distracted",
                              "brain fog", "confused", "lost", "level 1", "one", "1"]
        if foggyKeywords.contains(where: { normalized.contains($0) }) {
            return (.foggy, 0.9)
        }

        // Hazy / Level 2
        let hazyKeywords = ["hazy", "distracted", "hard to focus", "struggling", "unfocused",
                             "level 2", "two", "2"]
        if hazyKeywords.contains(where: { normalized.contains($0) }) {
            return (.hazy, 0.9)
        }

        // Clearing / Level 3
        let clearingKeywords = ["clearing", "getting there", "improving", "okay", "ok", "moderate",
                                 "so-so", "level 3", "three", "3"]
        if clearingKeywords.contains(where: { normalized.contains($0) }) {
            return (.clearing, 0.9)
        }

        // Clear / Level 4
        let clearKeywords = ["clear", "focused", "good", "sharp", "attentive", "concentrated",
                              "level 4", "four", "4"]
        if clearKeywords.contains(where: { normalized.contains($0) }) {
            return (.clear, 0.9)
        }

        // Crystal / Level 5
        let crystalKeywords = ["crystal", "crystal clear", "laser", "perfect", "amazing", "incredible",
                                "super focused", "in the zone", "best", "excellent",
                                "level 5", "five", "5"]
        if crystalKeywords.contains(where: { normalized.contains($0) }) {
            return (.crystal, 0.9)
        }

        return nil
    }

    // MARK: - Parse with Type Hint

    /// Parse transcript for a specific check-in level type
    static func parse(transcript: String, for levelType: CheckInLevelType) -> ParsedValue? {
        switch levelType {
        case .energy:
            if let (level, _) = parseEnergyLevel(from: transcript) {
                return .energyLevel(level)
            }
        case .mood:
            if let (level, _) = parseMoodLevel(from: transcript) {
                return .moodLevel(level)
            }
        case .focus:
            if let (level, _) = parseFocusLevel(from: transcript) {
                return .focusLevel(level)
            }
        }
        return nil
    }
}

/// Type of check-in level being parsed
enum CheckInLevelType {
    case energy
    case mood
    case focus

    var promptText: String {
        switch self {
        case .energy:
            return "How's your energy level right now? You can say things like exhausted, low, okay, good, high, or energized."
        case .mood:
            return "How's your mood? You can say things like terrible, sad, neutral, okay, good, or amazing."
        case .focus:
            return "How's your focus? You can say things like foggy, distracted, okay, focused, or crystal clear."
        }
    }

    var confirmationPrompt: String {
        switch self {
        case .energy: return "Got it, your energy is"
        case .mood: return "Got it, your mood is"
        case .focus: return "Got it, your focus is"
        }
    }
}
