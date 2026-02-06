//
//  ConversationalAssessmentModels.swift
//  ZoeSleep
//
//  Data models for the conversational assessment system.
//  Maps questionnaire questions to natural conversation flows.
//

import Foundation

// MARK: - Session State

/// State of the voice assessment session
enum VoiceAssessmentState: Equatable {
    case notStarted
    case introducingZoe            // Playing Zoe's introduction
    case awaitingResponse          // Waiting for user to speak
    case listening                 // Recording user audio
    case processing                // Transcribing and parsing
    case confirming(String)        // Confirming parsed answer
    case transitioning             // Moving to next question
    case redirecting               // User went off-topic, redirecting
    case sectionComplete           // Finished a section
    case dayComplete               // Finished today's questions
    case paused                    // User paused the session
    case error(String)             // Error occurred
}

/// Type of guardrail redirect needed
enum GuardrailRedirectType: Equatable {
    case offTopic                  // User talking about unrelated things
    case tooVague                  // Answer too vague to parse
    case requestingMedicalAdvice   // User asking for diagnosis/advice
    case emotionalDistress         // User expressing distress (handle carefully)
    case technicalIssue            // User having trouble with the system

    var redirectPrompt: String {
        switch self {
        case .offTopic:
            return "I appreciate you sharing that. Let me bring us back to your sleep assessment. "
        case .tooVague:
            return "I want to make sure I capture this accurately. Could you tell me more specifically: "
        case .requestingMedicalAdvice:
            return "That's a great question for the sleep specialist who will review your assessment. For now, let me continue gathering information. "
        case .emotionalDistress:
            return "I hear you, and I want you to know that these feelings are valid. If you're struggling, please reach out to a mental health professional. For now, would you like to continue, or would you prefer to pause? "
        case .technicalIssue:
            return "I'm sorry you're having trouble. You can always tap your answer instead, or say 'repeat' and I'll ask again. "
        }
    }
}

// MARK: - Conversation Script

/// A conversational question that maps to one or more questionnaire items
struct ConversationalPrompt: Identifiable, Codable {
    let id: String
    let questionIds: [String]              // Maps to questionnaire question IDs
    let spokenPrompt: String               // What Zoe says
    let followUpPrompt: String?            // If user gives partial answer
    let clarificationPrompt: String?       // If answer is unclear
    let expectedAnswerType: ExpectedAnswerType
    let validationRules: ValidationRules?
    let transitionPhrase: String?          // What to say before moving on

    /// Keywords that indicate this question was answered
    var answerKeywords: [String]? = nil

    /// If true, this is a gateway question that may trigger expansion
    var isGateway: Bool = false
    var gatewayType: String? = nil
}

/// Type of answer expected for parsing
enum ExpectedAnswerType: String, Codable {
    case yesNo                  // "Do you snore?"
    case yesNoDontKnow          // "Has anyone observed you stop breathing?"
    case scale1to10             // "On a scale of 1 to 10..."
    case scale0to4              // Clinical scales (ISI items)
    case scale0to3              // PHQ-9, GAD-7 items
    case frequency              // "How often..." (never, sometimes, often, always)
    case time                   // "What time do you usually..."
    case duration               // "How long does it take..."
    case number                 // "How many times..."
    case singleChoice           // "Which of these best describes..."
    case multipleChoice         // "Which of these apply..."
    case freeText               // "Tell me about..."
    case confirmation           // "Is that correct?"
}

/// Rules for validating and accepting an answer
struct ValidationRules: Codable {
    var minValue: Double?
    var maxValue: Double?
    var requiredKeywords: [String]?
    var acceptableOptions: [String]?
    var requiresConfirmation: Bool = false
}

// MARK: - Conversation Section

/// A group of related questions in the conversation
struct ConversationSection: Identifiable, Codable {
    let id: String
    let title: String                      // e.g., "Sleep Quality", "Mental Health"
    let introduction: String               // What Zoe says to introduce this section
    let prompts: [ConversationalPrompt]
    let conclusion: String                 // What Zoe says when section is done
    let estimatedMinutes: Int

    /// Pillar this section belongs to
    var pillar: String? = nil

    /// If this section requires specific gateways to be triggered
    var requiredGateways: [String]? = nil
}

// MARK: - Day Script

/// The complete conversation script for a single day
struct DayConversationScript: Identifiable, Codable {
    let id: String                         // e.g., "day1", "day6_insomnia"
    let dayNumber: Int
    let title: String                      // e.g., "Let's Get to Know You"
    let sections: [ConversationSection]
    let openingMessage: String             // First thing Zoe says
    let closingMessage: String             // Last thing Zoe says
    let estimatedMinutes: Int

    /// For expansion days, which gateways trigger this day
    var requiredGateways: [String]? = nil

    /// All question IDs covered in this day (for progress tracking)
    var allQuestionIds: [String] {
        sections.flatMap { $0.prompts.flatMap { $0.questionIds } }
    }
}

// MARK: - Session Progress

/// Tracks progress through a voice assessment session
struct VoiceAssessmentProgress: Codable {
    var currentDayNumber: Int
    var currentSectionIndex: Int
    var currentPromptIndex: Int
    var answeredQuestionIds: Set<String>
    var gatewaysTriggered: Set<String>
    var sessionStartTime: Date
    var lastActivityTime: Date
    var redirectCount: Int                 // How many times we've had to redirect
    var totalQuestionsAnswered: Int

    /// Percentage complete for current day
    var dayProgress: Double {
        guard totalQuestionsInDay > 0 else { return 0 }
        return Double(questionsAnsweredToday) / Double(totalQuestionsInDay)
    }

    var questionsAnsweredToday: Int = 0
    var totalQuestionsInDay: Int = 0

    static var empty: VoiceAssessmentProgress {
        VoiceAssessmentProgress(
            currentDayNumber: 1,
            currentSectionIndex: 0,
            currentPromptIndex: 0,
            answeredQuestionIds: [],
            gatewaysTriggered: [],
            sessionStartTime: Date(),
            lastActivityTime: Date(),
            redirectCount: 0,
            totalQuestionsAnswered: 0
        )
    }
}

// MARK: - Parsed Conversational Answer

/// An answer extracted from conversational speech
struct ParsedConversationalAnswer: Equatable {
    let questionIds: [String]              // Which questions this answers
    let rawTranscript: String              // What user said
    let parsedValues: [String: Any]        // questionId -> value mapping
    let confidence: Double                 // 0-1
    let needsClarification: Bool
    let clarificationReason: String?

    // For gateway detection
    var triggersGateway: Bool = false
    var gatewayType: String? = nil

    static func == (lhs: ParsedConversationalAnswer, rhs: ParsedConversationalAnswer) -> Bool {
        lhs.questionIds == rhs.questionIds &&
        lhs.rawTranscript == rhs.rawTranscript &&
        lhs.confidence == rhs.confidence
    }
}

// MARK: - Zoe's Introduction

/// The introduction Zoe gives when starting a voice assessment
struct ZoeIntroduction {

    static let firstTimeIntro = """
    Hey, I'm Zoe, your sleep optimization companion. I'm an AI, but I'm here to help collect comprehensive information about your sleep. \
    The human specialists on our team will review everything to build a personalized sleep protocol just for you. \
    I'll ask you questions and you just answer naturally, like we're having a conversation. \
    If you ever need me to repeat something, just say "repeat." Ready to get started?
    """

    static let returningUserIntro = """
    Welcome back! I'm Zoe, and I'm excited to continue learning about your sleep. \
    Today we'll explore %TOPIC%. This usually takes about %MINUTES% minutes. \
    Just speak naturally, and remember you can say "repeat" anytime. Let's begin!
    """

    static let dayIntros: [Int: String] = [
        1: "Today, I'd love to get to know you a bit and understand your overall sleep quality. We'll cover some basics about your sleep patterns.",
        2: "Today we're going to dive deeper into your sleep quality and look at how regular your sleep schedule is.",
        3: "Let's talk about your mind and mood today. Sleep and mental health are closely connected, so this helps us understand the full picture.",
        4: "Today we'll focus on your physical health and how it might relate to your sleep, including things like snoring, pain, and exercise.",
        5: "Let's wrap up the core assessment by talking about your daily habits, like caffeine, alcohol, and your sleep environment.",
        6: "Based on what you've shared, I'd like to ask some more detailed questions about insomnia.",
        7: "Let's explore your mental health a bit more deeply today.",
        8: "Today we'll focus on daytime energy and breathing during sleep.",
        9: "Let's talk about how sleep affects your daily functioning and behaviors.",
        10: "Finally, we'll look at your lifestyle patterns and natural sleep rhythm."
    ]

    static func introForDay(_ day: Int, topic: String, minutes: Int, isFirstTime: Bool) -> String {
        if isFirstTime && day == 1 {
            return firstTimeIntro
        }

        let daySpecific = dayIntros[day] ?? "Let's continue your sleep assessment."
        return returningUserIntro
            .replacingOccurrences(of: "%TOPIC%", with: topic)
            .replacingOccurrences(of: "%MINUTES%", with: String(minutes))
            + " " + daySpecific
    }
}

// MARK: - Guardrail Patterns

/// Patterns to detect when user goes off-topic or needs help
struct GuardrailPatterns {

    /// Keywords indicating user is asking for medical advice
    static let medicalAdviceKeywords = [
        "should i take", "is it bad", "am i sick", "do i have",
        "what medication", "prescribe", "diagnose", "what's wrong with me",
        "should i see a doctor", "is this serious"
    ]

    /// Keywords indicating emotional distress
    static let distressKeywords = [
        "can't take it anymore", "want to die", "kill myself", "end it all",
        "hopeless", "no point", "hate my life", "suicidal"
    ]

    /// Keywords indicating user wants to pause/stop
    static let pauseKeywords = [
        "stop", "pause", "take a break", "come back later",
        "too tired", "can't do this right now", "that's enough"
    ]

    /// Keywords indicating user needs help with the system
    static let helpKeywords = [
        "how do i", "what do i say", "i don't understand",
        "confused", "what does that mean", "can you explain"
    ]

    /// Keywords indicating user wants to repeat
    static let repeatKeywords = [
        "repeat", "say that again", "what was that", "sorry what",
        "didn't catch that", "one more time", "pardon"
    ]

    /// Check transcript for guardrail triggers
    static func checkForGuardrails(_ transcript: String) -> GuardrailRedirectType? {
        let lower = transcript.lowercased()

        // Check for distress first (highest priority)
        if distressKeywords.contains(where: { lower.contains($0) }) {
            return .emotionalDistress
        }

        // Check for medical advice requests
        if medicalAdviceKeywords.contains(where: { lower.contains($0) }) {
            return .requestingMedicalAdvice
        }

        // Check for help requests
        if helpKeywords.contains(where: { lower.contains($0) }) {
            return .technicalIssue
        }

        return nil
    }

    /// Check if user wants to repeat the question
    static func wantsRepeat(_ transcript: String) -> Bool {
        let lower = transcript.lowercased()
        return repeatKeywords.contains(where: { lower.contains($0) })
    }

    /// Check if user wants to pause
    static func wantsPause(_ transcript: String) -> Bool {
        let lower = transcript.lowercased()
        return pauseKeywords.contains(where: { lower.contains($0) })
    }
}

// MARK: - Answer Mapping Templates

/// Templates for mapping conversational answers to questionnaire values
struct AnswerMappingTemplates {

    /// Yes/No mappings
    static let yesNoMappings: [String: Bool] = [
        "yes": true, "yeah": true, "yep": true, "uh huh": true, "definitely": true,
        "absolutely": true, "correct": true, "that's right": true, "sure": true,
        "i do": true, "i have": true, "sometimes": true, "occasionally": true,

        "no": false, "nope": false, "nah": false, "not really": false, "never": false,
        "i don't": false, "i haven't": false, "not at all": false, "negative": false
    ]

    /// Frequency mappings (0-3 scale for PHQ-9, GAD-7)
    static let frequencyMappings: [String: Int] = [
        "not at all": 0, "never": 0, "rarely": 0, "almost never": 0,
        "several days": 1, "sometimes": 1, "occasionally": 1, "a few times": 1,
        "more than half": 2, "often": 2, "frequently": 2, "most days": 2,
        "nearly every day": 3, "every day": 3, "always": 3, "all the time": 3
    ]

    /// Severity mappings (0-4 scale for ISI)
    static let severityMappings: [String: Int] = [
        "none": 0, "not at all": 0, "no problem": 0,
        "mild": 1, "a little": 1, "slight": 1, "minor": 1,
        "moderate": 2, "somewhat": 2, "medium": 2, "fair amount": 2,
        "severe": 3, "quite a bit": 3, "a lot": 3, "significant": 3,
        "very severe": 4, "extremely": 4, "terrible": 4, "unbearable": 4
    ]

    /// Sleep quality descriptors to 1-10 scale
    static let qualityToScaleMappings: [String: Int] = [
        "terrible": 1, "awful": 1, "horrible": 1,
        "very bad": 2, "really bad": 2,
        "bad": 3, "poor": 3,
        "not great": 4, "below average": 4,
        "okay": 5, "so-so": 5, "average": 5, "fair": 5,
        "decent": 6, "not bad": 6,
        "good": 7, "pretty good": 7,
        "very good": 8, "great": 8,
        "excellent": 9, "really good": 9,
        "perfect": 10, "amazing": 10, "couldn't be better": 10
    ]
}
