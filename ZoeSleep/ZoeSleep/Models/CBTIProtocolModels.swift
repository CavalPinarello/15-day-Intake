//
//  CBTIProtocolModels.swift
//  ZoeSleep
//
//  Data models for CBT-I (Cognitive Behavioral Therapy for Insomnia).
//  Implements the five components: Sleep Restriction, Stimulus Control,
//  Cognitive Restructuring, Relaxation Training, and Sleep Hygiene.
//

import Foundation
import SwiftUI

// MARK: - CBT-I Session Types

/// Types of CBT-I coaching sessions
enum CBTISessionType: String, Codable, CaseIterable {
    case introduction = "introduction"
    case sleepRestriction = "sleep_restriction"
    case stimulusControl = "stimulus_control"
    case cognitiveRestructuring = "cognitive_restructuring"
    case relaxationTraining = "relaxation_training"
    case sleepHygiene = "sleep_hygiene"
    case weeklyReview = "weekly_review"

    var displayName: String {
        switch self {
        case .introduction: return "Getting Started"
        case .sleepRestriction: return "Sleep Restriction"
        case .stimulusControl: return "Stimulus Control"
        case .cognitiveRestructuring: return "Thinking About Sleep"
        case .relaxationTraining: return "Relaxation Training"
        case .sleepHygiene: return "Sleep Hygiene"
        case .weeklyReview: return "Weekly Check-In"
        }
    }

    var description: String {
        switch self {
        case .introduction:
            return "Learn about how CBT-I works and what to expect from your treatment."
        case .sleepRestriction:
            return "Consolidate your sleep by temporarily limiting time in bed to build sleep drive."
        case .stimulusControl:
            return "Strengthen the association between your bed and sleep."
        case .cognitiveRestructuring:
            return "Challenge unhelpful thoughts about sleep that may be keeping you awake."
        case .relaxationTraining:
            return "Learn techniques to calm your mind and body before bed."
        case .sleepHygiene:
            return "Optimize your environment and habits for better sleep."
        case .weeklyReview:
            return "Review your progress and adjust your sleep plan."
        }
    }

    var sfSymbol: String {
        switch self {
        case .introduction: return "hand.wave.fill"
        case .sleepRestriction: return "clock.fill"
        case .stimulusControl: return "bed.double.fill"
        case .cognitiveRestructuring: return "brain.head.profile"
        case .relaxationTraining: return "leaf.fill"
        case .sleepHygiene: return "sparkles"
        case .weeklyReview: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: Color {
        switch self {
        case .introduction: return .blue
        case .sleepRestriction: return .orange
        case .stimulusControl: return .purple
        case .cognitiveRestructuring: return .teal
        case .relaxationTraining: return .green
        case .sleepHygiene: return .mint
        case .weeklyReview: return .indigo
        }
    }

    var estimatedMinutes: Int {
        switch self {
        case .introduction: return 15
        case .sleepRestriction: return 20
        case .stimulusControl: return 15
        case .cognitiveRestructuring: return 25
        case .relaxationTraining: return 20
        case .sleepHygiene: return 10
        case .weeklyReview: return 15
        }
    }
}

// MARK: - Sleep Window

/// A prescribed sleep window for sleep restriction therapy
struct SleepWindow: Codable, Equatable {
    let bedtime: Date
    let wakeTime: Date
    let durationMinutes: Int

    /// Minimum safe duration (5 hours)
    static let minimumDurationMinutes = 300

    /// Time allowed in bed
    var timeInBed: String {
        let hours = durationMinutes / 60
        let mins = durationMinutes % 60
        if mins == 0 {
            return "\(hours) hours"
        }
        return "\(hours)h \(mins)m"
    }

    /// Calculate initial sleep window based on sleep log data
    static func calculateInitial(
        averageTotalSleepMinutes: Int,
        desiredWakeTime: Date
    ) -> SleepWindow {
        // Start with average sleep time, but not less than 5 hours
        let initialDuration = max(averageTotalSleepMinutes, minimumDurationMinutes)

        // Calculate bedtime from wake time
        let bedtime = Calendar.current.date(
            byAdding: .minute,
            value: -initialDuration,
            to: desiredWakeTime
        ) ?? desiredWakeTime

        return SleepWindow(
            bedtime: bedtime,
            wakeTime: desiredWakeTime,
            durationMinutes: initialDuration
        )
    }

    /// Adjust sleep window based on weekly sleep efficiency
    func adjusted(forSleepEfficiency efficiency: Double) -> SleepWindow {
        var newDuration = durationMinutes

        if efficiency >= 0.90 {
            // Sleep efficiency >= 90%: Increase by 15 minutes
            newDuration += 15
        } else if efficiency >= 0.85 {
            // Sleep efficiency 85-90%: Keep the same
            // No change
        } else {
            // Sleep efficiency < 85%: Decrease by 15 minutes (to minimum)
            newDuration = max(SleepWindow.minimumDurationMinutes, newDuration - 15)
        }

        let newBedtime = Calendar.current.date(
            byAdding: .minute,
            value: -newDuration,
            to: wakeTime
        ) ?? wakeTime

        return SleepWindow(
            bedtime: newBedtime,
            wakeTime: wakeTime,
            durationMinutes: newDuration
        )
    }
}

// MARK: - Stimulus Control Rules

/// The rules for stimulus control therapy
struct StimulusControlRules: Codable {
    static let rules: [StimulusControlRule] = [
        StimulusControlRule(
            id: "only_sleep",
            title: "Bed is for Sleep",
            description: "Only use your bed for sleep and intimacy. No reading, TV, phones, or worrying in bed.",
            importance: .critical
        ),
        StimulusControlRule(
            id: "sleepy_only",
            title: "Go to Bed When Sleepy",
            description: "Only go to bed when you feel truly sleepy, not just tired.",
            importance: .critical
        ),
        StimulusControlRule(
            id: "twenty_minute_rule",
            title: "The 20-Minute Rule",
            description: "If you can't fall asleep within about 20 minutes, get out of bed. Do something relaxing until you feel sleepy again.",
            importance: .critical
        ),
        StimulusControlRule(
            id: "consistent_wake",
            title: "Consistent Wake Time",
            description: "Wake up at the same time every day, including weekends, regardless of how much you slept.",
            importance: .high
        ),
        StimulusControlRule(
            id: "no_naps",
            title: "Limit Naps",
            description: "Avoid daytime naps, or limit them to 20 minutes before 3 PM.",
            importance: .moderate
        )
    ]
}

struct StimulusControlRule: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let importance: RuleImportance

    enum RuleImportance: String, Codable {
        case critical
        case high
        case moderate
    }
}

// MARK: - Cognitive Distortions

/// Common cognitive distortions about sleep
enum CognitiveDistortion: String, Codable, CaseIterable {
    case catastrophizing = "catastrophizing"
    case allOrNothing = "all_or_nothing"
    case mindReading = "mind_reading"
    case fortuneTelling = "fortune_telling"
    case overgeneralization = "overgeneralization"
    case shouldStatements = "should_statements"
    case emotionalReasoning = "emotional_reasoning"

    var displayName: String {
        switch self {
        case .catastrophizing: return "Catastrophizing"
        case .allOrNothing: return "All-or-Nothing Thinking"
        case .mindReading: return "Mind Reading"
        case .fortuneTelling: return "Fortune Telling"
        case .overgeneralization: return "Overgeneralization"
        case .shouldStatements: return "Should Statements"
        case .emotionalReasoning: return "Emotional Reasoning"
        }
    }

    var sleepExample: String {
        switch self {
        case .catastrophizing:
            return "\"If I don't sleep tonight, I'll never be able to function tomorrow.\""
        case .allOrNothing:
            return "\"I need 8 hours or my sleep is completely worthless.\""
        case .mindReading:
            return "\"Everyone can tell I'm sleep deprived and thinks I'm incompetent.\""
        case .fortuneTelling:
            return "\"I know I won't sleep tonight. I never do on Sunday nights.\""
        case .overgeneralization:
            return "\"I always have insomnia. This will never get better.\""
        case .shouldStatements:
            return "\"I should be able to fall asleep within 5 minutes like normal people.\""
        case .emotionalReasoning:
            return "\"I feel exhausted, so I must have gotten terrible sleep.\""
        }
    }

    var challenge: String {
        switch self {
        case .catastrophizing:
            return "One night of poor sleep is uncomfortable but not catastrophic. Your body will compensate."
        case .allOrNothing:
            return "Any sleep has value. 6 hours is much better than none, and you can still function."
        case .mindReading:
            return "You can't know what others think. Most people are focused on themselves, not analyzing you."
        case .fortuneTelling:
            return "You can't predict the future. Tonight might be different. Many variables affect sleep."
        case .overgeneralization:
            return "Look for exceptions. Have there been nights you slept well? What was different?"
        case .shouldStatements:
            return "'Should' creates pressure. There's no rule about how quickly people should fall asleep."
        case .emotionalReasoning:
            return "Feelings aren't facts. Sleep tracking often shows we sleep more than we think."
        }
    }
}

// MARK: - Thought Record

/// A cognitive restructuring thought record
struct ThoughtRecord: Codable, Identifiable {
    let id: String
    let createdAt: Date

    // The situation
    var situation: String
    var automaticThought: String
    var emotion: String
    var emotionIntensity: Int  // 0-100

    // Restructuring
    var cognitiveDistortion: CognitiveDistortion?
    var evidenceFor: String?
    var evidenceAgainst: String?
    var balancedThought: String?
    var newEmotionIntensity: Int?  // 0-100

    var isComplete: Bool {
        balancedThought != nil && newEmotionIntensity != nil
    }

    var emotionReduction: Int? {
        guard let newIntensity = newEmotionIntensity else { return nil }
        return emotionIntensity - newIntensity
    }
}

// MARK: - Relaxation Exercises

/// Types of relaxation exercises for CBT-I
enum RelaxationExercise: String, Codable, CaseIterable {
    case progressiveMuscleRelaxation = "pmr"
    case diaphragmaticBreathing = "breathing"
    case bodyScanning = "body_scan"
    case visualImagery = "imagery"
    case autogenicTraining = "autogenic"

    var displayName: String {
        switch self {
        case .progressiveMuscleRelaxation: return "Progressive Muscle Relaxation"
        case .diaphragmaticBreathing: return "Deep Breathing"
        case .bodyScanning: return "Body Scan"
        case .visualImagery: return "Peaceful Imagery"
        case .autogenicTraining: return "Autogenic Training"
        }
    }

    var description: String {
        switch self {
        case .progressiveMuscleRelaxation:
            return "Systematically tense and relax muscle groups to release physical tension."
        case .diaphragmaticBreathing:
            return "Slow, deep belly breathing to activate the relaxation response."
        case .bodyScanning:
            return "Bring gentle awareness to each part of your body, noticing and releasing tension."
        case .visualImagery:
            return "Visualize a peaceful, calming scene to quiet your mind."
        case .autogenicTraining:
            return "Use verbal cues to create feelings of warmth and heaviness in your body."
        }
    }

    var durationMinutes: Int {
        switch self {
        case .progressiveMuscleRelaxation: return 15
        case .diaphragmaticBreathing: return 5
        case .bodyScanning: return 10
        case .visualImagery: return 10
        case .autogenicTraining: return 12
        }
    }

    var sfSymbol: String {
        switch self {
        case .progressiveMuscleRelaxation: return "figure.arms.open"
        case .diaphragmaticBreathing: return "lungs.fill"
        case .bodyScanning: return "figure.stand"
        case .visualImagery: return "cloud.sun.fill"
        case .autogenicTraining: return "waveform.path"
        }
    }
}

// MARK: - Sleep Hygiene Tips

/// Sleep hygiene recommendations
struct SleepHygieneTip: Codable, Identifiable {
    let id: String
    let category: HygieneCategory
    let title: String
    let description: String
    let importance: TipImportance

    enum HygieneCategory: String, Codable {
        case environment
        case timing
        case substances
        case routines
        case mindset
    }

    enum TipImportance: String, Codable {
        case essential
        case recommended
        case optional
    }
}

/// Standard sleep hygiene tips
struct SleepHygieneTips {
    static let all: [SleepHygieneTip] = [
        // Environment
        SleepHygieneTip(
            id: "temp",
            category: .environment,
            title: "Keep It Cool",
            description: "Maintain bedroom temperature between 65-68°F (18-20°C).",
            importance: .essential
        ),
        SleepHygieneTip(
            id: "dark",
            category: .environment,
            title: "Make It Dark",
            description: "Use blackout curtains or an eye mask to block light.",
            importance: .essential
        ),
        SleepHygieneTip(
            id: "quiet",
            category: .environment,
            title: "Reduce Noise",
            description: "Use earplugs or white noise if needed.",
            importance: .recommended
        ),

        // Timing
        SleepHygieneTip(
            id: "consistent",
            category: .timing,
            title: "Consistent Schedule",
            description: "Go to bed and wake up at the same time every day.",
            importance: .essential
        ),
        SleepHygieneTip(
            id: "wind_down",
            category: .timing,
            title: "Wind-Down Routine",
            description: "Start relaxing 30-60 minutes before bed.",
            importance: .recommended
        ),

        // Substances
        SleepHygieneTip(
            id: "caffeine",
            category: .substances,
            title: "Limit Caffeine",
            description: "Avoid caffeine after 2 PM (or earlier if sensitive).",
            importance: .essential
        ),
        SleepHygieneTip(
            id: "alcohol",
            category: .substances,
            title: "Limit Alcohol",
            description: "Avoid alcohol within 3 hours of bedtime.",
            importance: .recommended
        ),
        SleepHygieneTip(
            id: "meals",
            category: .substances,
            title: "Light Evening Meals",
            description: "Avoid heavy meals close to bedtime.",
            importance: .recommended
        ),

        // Routines
        SleepHygieneTip(
            id: "exercise",
            category: .routines,
            title: "Regular Exercise",
            description: "Exercise regularly, but not within 3 hours of bed.",
            importance: .recommended
        ),
        SleepHygieneTip(
            id: "screens",
            category: .routines,
            title: "Limit Screen Time",
            description: "Avoid screens for 30-60 minutes before bed.",
            importance: .essential
        ),

        // Mindset
        SleepHygieneTip(
            id: "worry_time",
            category: .mindset,
            title: "Scheduled Worry Time",
            description: "Set aside 15-20 minutes earlier in the day for worries.",
            importance: .recommended
        )
    ]
}

// MARK: - CBT-I Session State

/// State of a CBT-I coaching session
enum CBTISessionState: Equatable {
    case notStarted
    case introduction
    case mainContent
    case exercise(RelaxationExercise)
    case review
    case homework
    case completed
    case paused
    case error(String)
}

// MARK: - CBT-I Progress

/// Overall CBT-I treatment progress
struct CBTIProgress: Codable {
    var weekNumber: Int
    var sessionsCompleted: [CBTISessionType]
    var currentSleepWindow: SleepWindow?
    var sleepEfficiencyHistory: [Double]  // Weekly averages
    var thoughtRecordsCount: Int
    var relaxationPracticeMinutes: Int

    var overallProgress: Double {
        let totalSessions = CBTISessionType.allCases.count * 2  // Assume 2 of each type
        return Double(sessionsCompleted.count) / Double(totalSessions)
    }

    static var empty: CBTIProgress {
        CBTIProgress(
            weekNumber: 1,
            sessionsCompleted: [],
            currentSleepWindow: nil,
            sleepEfficiencyHistory: [],
            thoughtRecordsCount: 0,
            relaxationPracticeMinutes: 0
        )
    }
}

// MARK: - CBT-I Agent System Prompts

/// System prompts for ElevenLabs Conversational AI CBT-I agent
struct CBTIAgentPrompts {

    static func buildSystemPrompt(
        sessionType: CBTISessionType,
        userContext: CBTIUserContext
    ) -> String {
        let basePrompt = """
        You are Zoe, a warm and supportive CBT-I (Cognitive Behavioral Therapy for Insomnia) coach. \
        You're helping the user improve their sleep through evidence-based techniques.

        PERSONALITY:
        - Warm, empathetic, and encouraging
        - Patient and non-judgmental
        - Knowledgeable but not preachy
        - Use simple, clear language
        - Celebrate small wins

        USER CONTEXT:
        - Week \(userContext.weekNumber) of treatment
        - Average sleep efficiency: \(Int(userContext.sleepEfficiency * 100))%
        - ISI score: \(userContext.isiScore) (severity: \(userContext.isiSeverity))
        - Current sleep window: \(userContext.sleepWindowDescription)
        - Main concerns: \(userContext.mainConcerns.joined(separator: ", "))

        IMPORTANT GUIDELINES:
        1. Keep responses concise (2-3 sentences max)
        2. Ask one question at a time
        3. Validate feelings before giving advice
        4. Use Socratic questioning for cognitive work
        5. End sessions with clear homework/action items
        6. If user expresses severe distress, suggest professional help

        """

        let sessionPrompt = getSessionPrompt(sessionType)

        return basePrompt + "\n\nSESSION TYPE: \(sessionType.displayName)\n" + sessionPrompt
    }

    private static func getSessionPrompt(_ type: CBTISessionType) -> String {
        switch type {
        case .introduction:
            return """
            TODAY'S GOAL: Welcome the user and explain how CBT-I works.

            TOPICS TO COVER:
            1. What CBT-I is and why it works
            2. The five components (briefly)
            3. Set expectations (4-8 weeks, homework matters)
            4. Assess their readiness to start

            Start by asking what they hope to achieve with treatment.
            """

        case .sleepRestriction:
            return """
            TODAY'S GOAL: Calculate and explain their sleep restriction window.

            APPROACH:
            1. Review their sleep log data
            2. Explain the rationale (consolidating sleep)
            3. Calculate initial sleep window
            4. Address concerns about reduced time in bed
            5. Set their prescribed bed and wake times

            IMPORTANT: Never go below 5 hours. Emphasize this is temporary.
            """

        case .stimulusControl:
            return """
            TODAY'S GOAL: Teach stimulus control rules.

            KEY RULES TO COVER:
            1. Bed is only for sleep and intimacy
            2. Go to bed only when sleepy
            3. The 20-minute rule (leave bed if awake)
            4. Consistent wake time every day
            5. No napping (or limited)

            Help them anticipate challenges with each rule.
            """

        case .cognitiveRestructuring:
            return """
            TODAY'S GOAL: Challenge unhelpful thoughts about sleep.

            APPROACH:
            1. Identify a recent sleep-related worry
            2. Help them see the cognitive distortion
            3. Use Socratic questioning:
               - "What's the evidence for this thought?"
               - "What's the evidence against?"
               - "What would you tell a friend?"
            4. Help create a balanced thought

            Be gentle - don't invalidate their feelings.
            """

        case .relaxationTraining:
            return """
            TODAY'S GOAL: Teach a relaxation technique.

            OPTIONS:
            1. Progressive Muscle Relaxation (PMR)
            2. Diaphragmatic breathing
            3. Body scan meditation
            4. Peaceful imagery

            Guide them through the exercise step by step.
            Encourage daily practice, not just at bedtime.
            """

        case .sleepHygiene:
            return """
            TODAY'S GOAL: Review sleep hygiene practices.

            ASSESS AND ADVISE ON:
            1. Bedroom environment (dark, cool, quiet)
            2. Caffeine and alcohol timing
            3. Exercise timing
            4. Screen use before bed
            5. Pre-sleep routine

            Focus on 1-2 changes they can make this week.
            """

        case .weeklyReview:
            return """
            TODAY'S GOAL: Review progress and adjust treatment.

            STEPS:
            1. Review their sleep log from the week
            2. Calculate sleep efficiency
            3. Celebrate improvements, no matter how small
            4. Identify challenges and problem-solve
            5. Adjust sleep window if needed:
               - SE >= 90%: Add 15 minutes
               - SE 85-90%: Keep the same
               - SE < 85%: Reduce by 15 minutes (min 5 hours)
            6. Set goals for next week

            Be encouraging even if progress is slow.
            """
        }
    }
}

/// User context for CBT-I sessions
struct CBTIUserContext {
    let weekNumber: Int
    let sleepEfficiency: Double
    let isiScore: Int
    let currentSleepWindow: SleepWindow?
    let mainConcerns: [String]

    var isiSeverity: String {
        switch isiScore {
        case 0...7: return "no clinically significant insomnia"
        case 8...14: return "subthreshold insomnia"
        case 15...21: return "moderate insomnia"
        case 22...28: return "severe insomnia"
        default: return "unknown"
        }
    }

    var sleepWindowDescription: String {
        guard let window = currentSleepWindow else {
            return "not yet calculated"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: window.bedtime)) - \(formatter.string(from: window.wakeTime))"
    }
}
