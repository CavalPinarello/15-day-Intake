//
//  SharedQuestionBank.swift
//  Zoe Sleep - Shared Question Definitions
//
//  IMPORTANT: This file is the SINGLE SOURCE OF TRUTH for all questions
//  across iPhone and Apple Watch platforms. Any question changes should
//  be made here, not in platform-specific files.
//
//  Both iOS and watchOS targets should include this file in their build.
//

import Foundation

// MARK: - Shared Question Type (Platform-Agnostic)

/// Simplified question type that works across all platforms
enum SharedQuestionType: String, Codable, CaseIterable {
    case text
    case number
    case time
    case date
    case scale
    case yesNo
    case yesNoDontKnow
    case singleSelect
    case multiSelect
    case minutesScroll
    case numberScroll
    case info
}

// MARK: - Shared Pillar

enum SharedPillar: String, Codable, CaseIterable {
    case social
    case metabolic
    case sleepQuality
    case sleepQuantity
    case sleepRegularity
    case sleepTiming
    case mentalHealth
    case cognitive
    case physical
    case nutritional
    case sleepLog
}

// MARK: - Shared Conditional Logic

/// Conditional logic for showing/hiding questions based on previous answers
struct SharedConditionalLogic: Codable {
    let questionId: String
    let equals: String?
    let greaterThan: Double?

    init(questionId: String, equals: String? = nil, greaterThan: Double? = nil) {
        self.questionId = questionId
        self.equals = equals
        self.greaterThan = greaterThan
    }
}

// MARK: - Shared Question Definition

/// Platform-agnostic question definition that can be used by both iOS and watchOS
struct SharedQuestion: Identifiable, Codable {
    let id: String
    let text: String
    let pillar: SharedPillar
    let type: SharedQuestionType

    // Optional configurations
    var options: [String]?
    var scaleMin: Int?
    var scaleMax: Int?
    var scaleMinLabel: String?
    var scaleMaxLabel: String?
    var minValue: Int?
    var maxValue: Int?
    var step: Double?
    var unit: String?
    var helpText: String?
    var required: Bool

    // HealthKit auto-fill identifier (for demographics)
    var healthKitIdentifier: String?

    // Conditional logic for showing/hiding this question
    var conditionalLogic: SharedConditionalLogic?

    init(
        id: String,
        text: String,
        pillar: SharedPillar,
        type: SharedQuestionType,
        options: [String]? = nil,
        scaleMin: Int? = nil,
        scaleMax: Int? = nil,
        scaleMinLabel: String? = nil,
        scaleMaxLabel: String? = nil,
        minValue: Int? = nil,
        maxValue: Int? = nil,
        step: Double? = nil,
        unit: String? = nil,
        helpText: String? = nil,
        required: Bool = true,
        healthKitIdentifier: String? = nil,
        conditionalLogic: SharedConditionalLogic? = nil
    ) {
        self.id = id
        self.text = text
        self.pillar = pillar
        self.type = type
        self.options = options
        self.scaleMin = scaleMin
        self.scaleMax = scaleMax
        self.scaleMinLabel = scaleMinLabel
        self.scaleMaxLabel = scaleMaxLabel
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.unit = unit
        self.helpText = helpText
        self.required = required
        self.healthKitIdentifier = healthKitIdentifier
        self.conditionalLogic = conditionalLogic
    }
}

// MARK: - Shared Question Bank

/// Central repository of all questions - THE SINGLE SOURCE OF TRUTH
struct SharedQuestionBank {

    // MARK: - Stanford Sleep Log (Full Version for iPhone/Web)
    // Based on Stanford Sleep Health and Insomnia Program: Two Week Sleep Diary
    // Adapted from the American Academy of Sleep Medicine
    // This is the COMPLETE protocol - use on iPhone and Web

    static let stanfordSleepLog: [SharedQuestion] = [
        // Q1: Day Type - CRITICAL for Stanford protocol
        SharedQuestion(
            id: "SD_DAY_TYPE",
            text: "What type of day is today?",
            pillar: .sleepLog,
            type: .singleSelect,
            options: ["Workday", "School Day", "Day Off", "Vacation", "Holiday"],
            helpText: "This helps track how your schedule affects your sleep"
        ),

        // Q2: Medication Tracking
        SharedQuestion(
            id: "SD_MEDICATION_TAKEN",
            text: "Did you take any sleep medication last night?",
            pillar: .sleepLog,
            type: .yesNo,
            helpText: "Including prescription, OTC, or supplements"
        ),
        // Note: SD_MEDICATION_TIME is conditional - only shown if medication taken = Yes
        // The app should handle this conditional logic

        // Q3: Bedtime Routine
        SharedQuestion(
            id: "SD_GOT_INTO_BED",
            text: "What time did you get into bed last night?",
            pillar: .sleepLog,
            type: .time,
            helpText: "When you physically got into bed, not necessarily trying to sleep"
        ),
        SharedQuestion(
            id: "SD_LIGHTS_OUT",
            text: "What time did you turn off the lights to sleep?",
            pillar: .sleepLog,
            type: .time,
            helpText: "When you started trying to fall asleep"
        ),

        // Q4: Sleep Latency (how long it took to fall asleep)
        // Note: SD_SLEEP_ONSET was removed - redundant with sleep latency
        // Sleep onset time can be derived from SD_LIGHTS_OUT + sleep latency

        // Q5: Night Awakenings
        SharedQuestion(
            id: "SL_AWAKENINGS",
            text: "How many times did you wake up during the night?",
            pillar: .sleepLog,
            type: .numberScroll,
            minValue: 0,
            maxValue: 20
        ),
        // Note: SD_AWAKENINGS_DURATION is conditional - only shown if awakenings > 0
        // "Approximately how much total time were you awake during the night? (minutes)"

        // Q6: Morning Wake Time
        SharedQuestion(
            id: "SL_WAKE_TIME",
            text: "What time did you wake up for the final time?",
            pillar: .sleepLog,
            type: .time,
            helpText: "The last time you woke up and decided to get up"
        ),
        SharedQuestion(
            id: "SD_OUT_OF_BED",
            text: "What time did you get out of bed this morning?",
            pillar: .sleepLog,
            type: .time,
            helpText: "When you physically got out of bed"
        ),

        // Q7: Sleep Quality
        SharedQuestion(
            id: "SL_QUALITY",
            text: "How would you rate your sleep quality last night?",
            pillar: .sleepLog,
            type: .scale,
            scaleMin: 1,
            scaleMax: 10,
            scaleMinLabel: "Very Poor",
            scaleMaxLabel: "Excellent"
        ),

        // Q8: Naps (yesterday)
        SharedQuestion(
            id: "SD_NAPS_TAKEN",
            text: "Did you take any naps yesterday?",
            pillar: .sleepLog,
            type: .yesNo
        )
        // Note: SD_NAPS_COUNT and SD_NAP_DETAILS are conditional - only shown if naps = Yes
    ]

    // MARK: - Stanford Sleep Log (Watch Version - Streamlined)
    // Simplified 5-question version for Apple Watch (~60 seconds)
    // Captures the essential data points while keeping it quick

    static let stanfordSleepLogWatch: [SharedQuestion] = [
        // Q1: Day Type - Essential for schedule-based analysis
        SharedQuestion(
            id: "SD_DAY_TYPE",
            text: "What type of day is today?",
            pillar: .sleepLog,
            type: .singleSelect,
            options: ["Workday", "School Day", "Day Off", "Vacation", "Holiday"],
            helpText: "This helps track how your schedule affects your sleep"
        ),

        // Q2: Bedtime (combined - when you tried to sleep)
        SharedQuestion(
            id: "SD_GOT_INTO_BED",
            text: "What time did you go to bed?",
            pillar: .sleepLog,
            type: .time,
            helpText: "When you got into bed to sleep"
        ),

        // Q3: Night Awakenings
        SharedQuestion(
            id: "SL_AWAKENINGS",
            text: "How many times did you wake up?",
            pillar: .sleepLog,
            type: .numberScroll,
            minValue: 0,
            maxValue: 20
        ),

        // Q4: Wake Time
        SharedQuestion(
            id: "SL_WAKE_TIME",
            text: "What time did you wake up?",
            pillar: .sleepLog,
            type: .time,
            helpText: "Final wake time this morning"
        ),

        // Q5: Sleep Quality
        SharedQuestion(
            id: "SL_QUALITY",
            text: "Rate your sleep quality",
            pillar: .sleepLog,
            type: .scale,
            scaleMin: 1,
            scaleMax: 10,
            scaleMinLabel: "Very Poor",
            scaleMaxLabel: "Excellent"
        )
    ]

    // MARK: - Day 1: Demographics + Sleep Quality Core

    static let day1Questions: [SharedQuestion] = [
        // Demographics - These can be auto-filled from Apple Health
        SharedQuestion(
            id: "D1",
            text: "What is your full name?",
            pillar: .social,
            type: .text,
            helpText: "This will be used to identify you in reports"
        ),
        SharedQuestion(
            id: "D2",
            text: "What is your date of birth?",
            pillar: .social,
            type: .date,
            healthKitIdentifier: "dateOfBirth"
        ),
        SharedQuestion(
            id: "D4",
            text: "What is your sex assigned at birth?",
            pillar: .metabolic,
            type: .singleSelect,
            options: ["Male", "Female", "Other"],
            healthKitIdentifier: "biologicalSex"
        ),
        SharedQuestion(
            id: "D5",
            text: "What is your height?",
            pillar: .metabolic,
            type: .number,
            minValue: 100,
            maxValue: 250,
            unit: "cm",
            healthKitIdentifier: "height"
        ),
        SharedQuestion(
            id: "D6",
            text: "What is your weight?",
            pillar: .metabolic,
            type: .number,
            minValue: 30,
            maxValue: 300,
            unit: "kg",
            healthKitIdentifier: "bodyMass"
        ),

        // Sleep Quality Core (Gateway Questions)
        SharedQuestion(
            id: "1",
            text: "Overall sleep quality in past month",
            pillar: .sleepQuality,
            type: .scale,
            scaleMin: 1,
            scaleMax: 10,
            scaleMinLabel: "Very Poor",
            scaleMaxLabel: "Excellent"
        ),
        SharedQuestion(
            id: "2",
            text: "How often do you feel refreshed after sleep?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Never", "Rarely", "Sometimes", "Often", "Always"]
        ),
        SharedQuestion(
            id: "3",
            text: "Do you have trouble falling asleep, staying asleep, or waking too early?",
            pillar: .sleepQuality,
            type: .yesNo
        ),

        // PSQI Part 1
        SharedQuestion(
            id: "PSQI_1",
            text: "During the past month, when have you usually gone to bed at night?",
            pillar: .sleepQuality,
            type: .time,
            helpText: "Your subjective perception - don't check your wearable device"
        ),
        SharedQuestion(
            id: "PSQI_2",
            text: "During the past month, how many minutes did it typically take you to fall asleep at night?",
            pillar: .sleepQuality,
            type: .minutesScroll,
            minValue: 0,
            maxValue: 180,
            unit: "minutes"
        ),
        SharedQuestion(
            id: "PSQI_3",
            text: "During the past month, when have you usually gotten up in the morning?",
            pillar: .sleepQuality,
            type: .time,
            helpText: "Your subjective perception - don't check your wearable"
        )
        // PSQI_4 removed - always derived from sleep log
    ]

    // MARK: - Day 2: PSQI Part 2 + Sleep Quantity + Sleep Regularity

    static let day2Questions: [SharedQuestion] = [
        SharedQuestion(
            id: "PSQI_5a",
            text: "How often have you had trouble sleeping because you cannot get to sleep within 30 minutes?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "PSQI_5b",
            text: "How often have you had trouble sleeping because you wake up in the middle of the night or early morning?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "PSQI_5c",
            text: "How often have you had trouble sleeping because you have to get up to use the bathroom?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "PSQI_5d",
            text: "How often have you had trouble sleeping because you cannot breathe comfortably?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "PSQI_5e",
            text: "How often have you had trouble sleeping because you cough or snore loudly?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "PSQI_5f",
            text: "How often have you had trouble sleeping because you feel too cold?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "PSQI_5g",
            text: "How often have you had trouble sleeping because you feel too hot?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "PSQI_5h",
            text: "How often have you had trouble sleeping because you have bad dreams?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "PSQI_5i",
            text: "How often have you had trouble sleeping because you have pain?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "PSQI_5j",
            text: "How often have you had trouble sleeping because of other reason(s)?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
        ),
        SharedQuestion(
            id: "12A",
            text: "How many times do you typically wake up during the night?",
            pillar: .sleepQuality,
            type: .numberScroll,
            minValue: 0,
            maxValue: 15
        ),
        SharedQuestion(
            id: "12B",
            text: "When you wake up at night, what is the MAIN reason?",
            pillar: .sleepQuality,
            type: .singleSelect,
            options: ["Bathroom needs", "Pain/discomfort", "Noise", "Light", "Hot/cold", "Dreams/nightmares", "Worry/stress", "Other"]
        ),
        SharedQuestion(
            id: "12C",
            text: "When you wake up during the night, how long does it typically take you to fall back asleep?",
            pillar: .sleepQuality,
            type: .minutesScroll,
            minValue: 0,
            maxValue: 120,
            unit: "minutes",
            helpText: "Your best estimate in minutes"
        ),

        // Sleep Regularity
        SharedQuestion(
            id: "7",
            text: "What time do you usually go to bed on weekdays?",
            pillar: .sleepRegularity,
            type: .time
        ),
        SharedQuestion(
            id: "8",
            text: "What time do you usually wake up on weekdays?",
            pillar: .sleepRegularity,
            type: .time
        ),
        SharedQuestion(
            id: "9",
            text: "What time do you usually go to bed on weekends?",
            pillar: .sleepRegularity,
            type: .time
        ),
        SharedQuestion(
            id: "10",
            text: "What time do you usually wake up on weekends?",
            pillar: .sleepRegularity,
            type: .time
        ),
        SharedQuestion(
            id: "REG_1",
            text: "Do you use an alarm clock on weekdays?",
            pillar: .sleepRegularity,
            type: .singleSelect,
            options: ["Never", "Rarely", "Sometimes", "Usually", "Always"]
        ),
        SharedQuestion(
            id: "REG_2",
            text: "How much does your bedtime vary from night to night?",
            pillar: .sleepRegularity,
            type: .singleSelect,
            options: ["Less than 15 minutes", "15-30 minutes", "30-60 minutes", "1-2 hours", "More than 2 hours"]
        )
    ]

    // MARK: - Day 3: Sleep Timing + Mental Health Gateways

    static let day3Questions: [SharedQuestion] = [
        SharedQuestion(
            id: "11",
            text: "How often do you get morning sunlight exposure within 1 hour of waking?",
            pillar: .sleepTiming,
            type: .singleSelect,
            options: ["Never", "Rarely", "Sometimes", "Often", "Daily"]
        ),
        SharedQuestion(
            id: "12",
            text: "How many hours per day do you spend looking at screens (work or entertainment)?",
            pillar: .social,
            type: .number,
            minValue: 0,
            maxValue: 18,
            unit: "hours"
        ),
        SharedQuestion(
            id: "13",
            text: "How often do you use electronic devices within 1 hour of bedtime?",
            pillar: .sleepTiming,
            type: .singleSelect,
            options: ["Never", "Rarely", "Sometimes", "Often", "Always"]
        ),
        SharedQuestion(
            id: "14",
            text: "On a scale of 1-10, how would you rate your current stress level?",
            pillar: .mentalHealth,
            type: .scale,
            scaleMin: 1,
            scaleMax: 10,
            scaleMinLabel: "No stress",
            scaleMaxLabel: "Extremely stressed"
        ),
        SharedQuestion(
            id: "15",
            text: "Over the past 2 weeks, how often have you felt down, depressed, or hopeless?",
            pillar: .mentalHealth,
            type: .singleSelect,
            options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]
        ),
        SharedQuestion(
            id: "16",
            text: "Over the past 2 weeks, how often have you felt nervous, anxious, or on edge?",
            pillar: .mentalHealth,
            type: .singleSelect,
            options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]
        ),
        SharedQuestion(
            id: "17",
            text: "Do you feel excessively tired or sleepy during the day?",
            pillar: .cognitive,
            type: .singleSelect,
            options: ["Never", "Rarely", "Sometimes", "Often", "Always"]
        ),
        SharedQuestion(
            id: "18",
            text: "Do you experience memory problems, difficulty concentrating, or mental fog?",
            pillar: .cognitive,
            type: .yesNo
        )
    ]

    // MARK: - Day 4: Physical Health + Metabolic Core

    static let day4Questions: [SharedQuestion] = [
        SharedQuestion(
            id: "19",
            text: "Do you snore loudly (louder than talking or loud enough to be heard through closed doors)?",
            pillar: .physical,
            type: .yesNoDontKnow
        ),
        SharedQuestion(
            id: "20",
            text: "Has anyone observed you stop breathing during your sleep?",
            pillar: .physical,
            type: .yesNoDontKnow
        ),
        SharedQuestion(
            id: "21",
            text: "Do you often feel tired, fatigued, or sleepy during daytime?",
            pillar: .physical,
            type: .yesNo
        ),
        SharedQuestion(
            id: "22",
            text: "Do you experience pain that affects your sleep?",
            pillar: .physical,
            type: .yesNo
        ),
        SharedQuestion(
            id: "23",
            text: "On average, what is your pain level?",
            pillar: .physical,
            type: .scale,
            scaleMin: 0,
            scaleMax: 10,
            scaleMinLabel: "No pain",
            scaleMaxLabel: "Worst possible"
        ),
        SharedQuestion(
            id: "24",
            text: "How often do you exercise or engage in physical activity?",
            pillar: .physical,
            type: .singleSelect,
            options: ["Never", "Less than once a week", "1-2 times per week", "3-4 times per week", "5+ times per week"]
        ),
        SharedQuestion(
            id: "25",
            text: "What time of day do you typically exercise?",
            pillar: .physical,
            type: .singleSelect,
            options: ["Morning", "Afternoon", "Evening", "Night", "Varies", "I don't exercise"]
        ),
        SharedQuestion(
            id: "26",
            text: "Do you have diabetes or pre-diabetes?",
            pillar: .metabolic,
            type: .yesNoDontKnow
        ),
        SharedQuestion(
            id: "27",
            text: "Do you have or are you being treated for high blood pressure?",
            pillar: .metabolic,
            type: .yesNo
        )
    ]

    // MARK: - Day 5: Nutritional Core + Social Factors

    static let day5Questions: [SharedQuestion] = [
        SharedQuestion(
            id: "29",
            text: "Do you consume caffeine (coffee, tea, energy drinks)?",
            pillar: .nutritional,
            type: .singleSelect,
            options: ["Never", "Rarely", "Sometimes", "Often", "Daily"]
        ),
        SharedQuestion(
            id: "30",
            text: "If you consume caffeine, how many cups/servings per day?",
            pillar: .nutritional,
            type: .number,
            minValue: 0,
            maxValue: 20,
            required: false
        ),
        SharedQuestion(
            id: "31",
            text: "What time is your last caffeine intake typically?",
            pillar: .nutritional,
            type: .time,
            required: false
        ),
        SharedQuestion(
            id: "32",
            text: "How often do you consume alcohol?",
            pillar: .nutritional,
            type: .singleSelect,
            options: ["Never", "Less than monthly", "Monthly", "Weekly", "Daily"]
        ),
        SharedQuestion(
            id: "33",
            text: "If you drink alcohol, when is it typically in relation to bedtime?",
            pillar: .nutritional,
            type: .singleSelect,
            options: ["More than 4 hours before bed", "2-4 hours before bed", "Within 2 hours of bed", "I don't drink alcohol"]
        ),
        SharedQuestion(
            id: "34",
            text: "Do you notice your diet affects your sleep quality?",
            pillar: .nutritional,
            type: .singleSelect,
            options: ["Not at all", "Slightly", "Moderately", "Quite a bit", "Extremely"]
        ),
        SharedQuestion(
            id: "35",
            text: "Do you share your bedroom with a partner?",
            pillar: .social,
            type: .yesNo
        ),
        SharedQuestion(
            id: "36",
            text: "If yes, do they snore or disturb your sleep?",
            pillar: .social,
            type: .yesNo,
            required: false,
            conditionalLogic: SharedConditionalLogic(questionId: "35", equals: "Yes")
        ),
        SharedQuestion(
            id: "37",
            text: "Do you have young children or infants at home?",
            pillar: .social,
            type: .yesNo
        ),
        SharedQuestion(
            id: "53E",
            text: "On a scale of 1-10, how would you rate your current work-related stress?",
            pillar: .social,
            type: .scale,
            scaleMin: 1,
            scaleMax: 10,
            scaleMinLabel: "No stress",
            scaleMaxLabel: "Extreme stress"
        )
    ]

    // MARK: - Days 6-15: Generic Daily Check-in (when no expansion needed)

    static let genericDailyQuestions: [SharedQuestion] = [
        SharedQuestion(
            id: "DAILY_MOOD",
            text: "How is your mood today?",
            pillar: .mentalHealth,
            type: .scale,
            scaleMin: 1,
            scaleMax: 10,
            scaleMinLabel: "Very Low",
            scaleMaxLabel: "Excellent"
        ),
        SharedQuestion(
            id: "DAILY_ENERGY",
            text: "How is your energy level today?",
            pillar: .physical,
            type: .scale,
            scaleMin: 1,
            scaleMax: 10,
            scaleMinLabel: "Very Low",
            scaleMaxLabel: "Very High"
        )
    ]

    // MARK: - Question Retrieval Methods

    /// Get all questions for a specific day (Sleep Log + Day Assessment)
    static func getQuestionsForDay(_ day: Int) -> [SharedQuestion] {
        var questions = stanfordSleepLog
        questions.append(contentsOf: getAssessmentQuestionsForDay(day))
        return questions
    }

    /// Get just the assessment questions for a day (without Sleep Log)
    static func getAssessmentQuestionsForDay(_ day: Int) -> [SharedQuestion] {
        switch day {
        case 1: return day1Questions
        case 2: return day2Questions
        case 3: return day3Questions
        case 4: return day4Questions
        case 5: return day5Questions
        default: return genericDailyQuestions
        }
    }

    /// Get the full Stanford Sleep Log questions (iPhone/Web - complete protocol)
    static func getSleepLogQuestions() -> [SharedQuestion] {
        return stanfordSleepLog
    }

    /// Get the streamlined Watch version of Sleep Log (5 questions, ~60 seconds)
    static func getSleepLogQuestionsForWatch() -> [SharedQuestion] {
        return stanfordSleepLogWatch
    }

    /// Get questions that can be auto-filled from Apple Health
    static func getHealthKitAutoFillableQuestions() -> [SharedQuestion] {
        return day1Questions.filter { $0.healthKitIdentifier != nil }
    }
}
