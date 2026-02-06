//
//  ConversationScriptLibrary.swift
//  ZoeSleep
//
//  Library of conversation scripts for each assessment day.
//  Maps questionnaire questions to natural conversational prompts.
//

import Foundation

/// Library of conversation scripts for the 10-day assessment journey
struct ConversationScriptLibrary {

    // MARK: - Script Access

    static func script(forDay day: Int) -> DayConversationScript? {
        switch day {
        case 1: return day1Script
        case 2: return day2Script
        case 3: return day3Script
        case 4: return day4Script
        case 5: return day5Script
        case 6: return day6Script
        case 7: return day7Script
        case 8: return day8Script
        case 9: return day9Script
        case 10: return day10Script
        default: return nil
        }
    }

    // MARK: - Day 1: Let's Get to Know You

    static let day1Script = DayConversationScript(
        id: "day1",
        dayNumber: 1,
        title: "Let's Get to Know You",
        sections: [
            // Section 1: Demographics
            ConversationSection(
                id: "day1_demographics",
                title: "About You",
                introduction: "First, let me learn a little about you.",
                prompts: [
                    ConversationalPrompt(
                        id: "intro_name",
                        questionIds: ["D1"],
                        spokenPrompt: "What's your name?",
                        followUpPrompt: "I didn't quite catch that. Could you say your name again?",
                        clarificationPrompt: nil,
                        expectedAnswerType: .freeText,
                        validationRules: nil,
                        transitionPhrase: "Nice to meet you!"
                    ),
                    ConversationalPrompt(
                        id: "intro_dob",
                        questionIds: ["D2"],
                        spokenPrompt: "And when were you born? Just the month and year is fine.",
                        followUpPrompt: "What year were you born?",
                        clarificationPrompt: nil,
                        expectedAnswerType: .freeText,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "intro_sex",
                        questionIds: ["D3"],
                        spokenPrompt: "For our medical records, were you assigned male or female at birth?",
                        followUpPrompt: nil,
                        clarificationPrompt: "You can say male, female, or prefer not to answer.",
                        expectedAnswerType: .singleChoice,
                        validationRules: ValidationRules(acceptableOptions: ["male", "female", "prefer not to say"]),
                        transitionPhrase: nil
                    )
                ],
                conclusion: "Great, I've got your basic information.",
                estimatedMinutes: 2,
                pillar: "demographics"
            ),

            // Section 2: Overall Sleep Quality
            ConversationSection(
                id: "day1_sleep_quality",
                title: "Sleep Quality",
                introduction: "Now let's talk about your sleep. I'd love to understand how you've been sleeping lately.",
                prompts: [
                    ConversationalPrompt(
                        id: "sleep_quality_overall",
                        questionIds: ["Q1"],
                        spokenPrompt: "On a scale of 1 to 10, where 10 is the best sleep of your life and 1 is terrible, how would you rate your overall sleep quality recently?",
                        followUpPrompt: "Just give me a number from 1 to 10.",
                        clarificationPrompt: "You can say any number between 1 and 10, or describe it like 'pretty good' or 'terrible'.",
                        expectedAnswerType: .scale1to10,
                        validationRules: ValidationRules(minValue: 1, maxValue: 10),
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "poor_sleep_quality"
                    ),
                    ConversationalPrompt(
                        id: "sleep_refreshed",
                        questionIds: ["Q2"],
                        spokenPrompt: "When you wake up in the morning, how often do you feel refreshed and well-rested?",
                        followUpPrompt: nil,
                        clarificationPrompt: "Would you say never, rarely, sometimes, often, or always?",
                        expectedAnswerType: .frequency,
                        validationRules: ValidationRules(acceptableOptions: ["never", "rarely", "sometimes", "often", "always"]),
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "has_insomnia",
                        questionIds: ["Q3"],
                        spokenPrompt: "Do you have trouble falling asleep, staying asleep, or waking up too early?",
                        followUpPrompt: nil,
                        clarificationPrompt: "A simple yes or no works here.",
                        expectedAnswerType: .yesNo,
                        validationRules: nil,
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "insomnia"
                    )
                ],
                conclusion: "I'm getting a picture of your sleep quality.",
                estimatedMinutes: 3,
                pillar: "sleep_quality"
            ),

            // Section 3: Sleep Schedule (PSQI Part 1)
            ConversationSection(
                id: "day1_schedule",
                title: "Sleep Schedule",
                introduction: "Let's talk about your typical sleep schedule on weeknights.",
                prompts: [
                    ConversationalPrompt(
                        id: "bedtime",
                        questionIds: ["PSQI_1"],
                        spokenPrompt: "What time do you usually go to bed on weeknights?",
                        followUpPrompt: "Just roughly, like 10 PM or 11 o'clock.",
                        clarificationPrompt: nil,
                        expectedAnswerType: .time,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "sleep_latency",
                        questionIds: ["PSQI_2"],
                        spokenPrompt: "Once you're in bed, about how long does it take you to fall asleep?",
                        followUpPrompt: "In minutes, roughly.",
                        clarificationPrompt: "You can say something like 'about 20 minutes' or 'less than 10 minutes'.",
                        expectedAnswerType: .duration,
                        validationRules: ValidationRules(minValue: 0, maxValue: 180),
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "wake_time",
                        questionIds: ["PSQI_3"],
                        spokenPrompt: "What time do you usually wake up in the morning?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .time,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "sleep_duration",
                        questionIds: ["PSQI_4"],
                        spokenPrompt: "And roughly how many hours of actual sleep do you get per night? Not time in bed, but actual sleep.",
                        followUpPrompt: nil,
                        clarificationPrompt: "You can say something like '6 hours' or 'about 7 and a half'.",
                        expectedAnswerType: .duration,
                        validationRules: ValidationRules(minValue: 0, maxValue: 720),
                        transitionPhrase: "Thank you, that's really helpful."
                    )
                ],
                conclusion: "I've got a good picture of your sleep schedule.",
                estimatedMinutes: 3,
                pillar: "sleep_quality"
            )
        ],
        openingMessage: "Let's start your sleep assessment!",
        closingMessage: "That's everything for today! You've completed Day 1 of your sleep assessment. Tomorrow, we'll dive deeper into your sleep quality. Have a good night!",
        estimatedMinutes: 8
    )

    // MARK: - Day 2: Your Sleep Quality

    static let day2Script = DayConversationScript(
        id: "day2",
        dayNumber: 2,
        title: "Your Sleep Quality",
        sections: [
            // Section 1: Sleep Disturbances (PSQI 5a-5j)
            ConversationSection(
                id: "day2_disturbances",
                title: "Sleep Disturbances",
                introduction: "Today I'd like to understand what might be disrupting your sleep. I'll ask about some common issues.",
                prompts: [
                    ConversationalPrompt(
                        id: "cant_fall_asleep",
                        questionIds: ["PSQI_5a"],
                        spokenPrompt: "In the past month, how often have you had trouble falling asleep within 30 minutes?",
                        followUpPrompt: nil,
                        clarificationPrompt: "Would you say not at all, less than once a week, once or twice a week, or three or more times a week?",
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "wake_middle_night",
                        questionIds: ["PSQI_5b"],
                        spokenPrompt: "How often do you wake up in the middle of the night or early morning?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "bathroom_trips",
                        questionIds: ["PSQI_5c"],
                        spokenPrompt: "How often do you have to get up to use the bathroom during the night?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "breathing_issues",
                        questionIds: ["PSQI_5d"],
                        spokenPrompt: "Do you have trouble breathing comfortably while sleeping?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "loud_snoring",
                        questionIds: ["PSQI_5e"],
                        spokenPrompt: "Do you snore loudly?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "too_cold",
                        questionIds: ["PSQI_5f"],
                        spokenPrompt: "How often do you feel too cold during the night?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "too_hot",
                        questionIds: ["PSQI_5g"],
                        spokenPrompt: "And how often do you feel too hot?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "bad_dreams",
                        questionIds: ["PSQI_5h"],
                        spokenPrompt: "Do you have bad dreams or nightmares?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "pain",
                        questionIds: ["PSQI_5i"],
                        spokenPrompt: "Do you experience pain that disrupts your sleep?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    )
                ],
                conclusion: "Thank you for sharing that. Sleep disturbances are really common, and understanding yours helps us help you.",
                estimatedMinutes: 5,
                pillar: "sleep_quality"
            ),

            // Section 2: Sleep Regularity
            ConversationSection(
                id: "day2_regularity",
                title: "Sleep Regularity",
                introduction: "Now let's look at how consistent your sleep schedule is.",
                prompts: [
                    ConversationalPrompt(
                        id: "weekend_bedtime",
                        questionIds: ["Q7"],
                        spokenPrompt: "On weekends or days off, what time do you typically go to bed?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .time,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "weekend_waketime",
                        questionIds: ["Q9"],
                        spokenPrompt: "And what time do you usually wake up on weekends?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .time,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "alarm_use",
                        questionIds: ["REG_1"],
                        spokenPrompt: "Do you use an alarm to wake up, or do you wake naturally?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .singleChoice,
                        validationRules: ValidationRules(acceptableOptions: ["alarm", "naturally", "both"]),
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "bedtime_variance",
                        questionIds: ["REG_2"],
                        spokenPrompt: "How much does your bedtime vary from night to night? Is it pretty consistent, or does it change a lot?",
                        followUpPrompt: nil,
                        clarificationPrompt: "Would you say very consistent, somewhat varies, or changes a lot?",
                        expectedAnswerType: .singleChoice,
                        validationRules: nil,
                        transitionPhrase: "Consistency really helps with sleep quality."
                    )
                ],
                conclusion: "Your sleep schedule patterns are important for understanding your circadian rhythm.",
                estimatedMinutes: 3,
                pillar: "sleep_regularity"
            )
        ],
        openingMessage: "Welcome to Day 2 of your sleep assessment!",
        closingMessage: "You've completed Day 2! We're making great progress understanding your sleep. See you tomorrow!",
        estimatedMinutes: 8
    )

    // MARK: - Day 3-10 (Abbreviated for now)
    // TODO: Complete scripts for Days 3-10

    static let day3Script = DayConversationScript(
        id: "day3",
        dayNumber: 3,
        title: "Mind & Mood",
        sections: [
            ConversationSection(
                id: "day3_mood",
                title: "Mental Health Check",
                introduction: "Today we'll explore how your mind and mood might be connected to your sleep.",
                prompts: [
                    ConversationalPrompt(
                        id: "stress_level",
                        questionIds: ["Q14"],
                        spokenPrompt: "On a scale of 1 to 10, how would you rate your overall stress level lately?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale1to10,
                        validationRules: ValidationRules(minValue: 1, maxValue: 10),
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "feeling_down",
                        questionIds: ["Q15"],
                        spokenPrompt: "Over the past two weeks, how often have you felt down, depressed, or hopeless?",
                        followUpPrompt: nil,
                        clarificationPrompt: "You can say not at all, several days, more than half the days, or nearly every day.",
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "depression"
                    ),
                    ConversationalPrompt(
                        id: "anxiety",
                        questionIds: ["Q16"],
                        spokenPrompt: "How often have you felt nervous, anxious, or on edge?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "anxiety"
                    ),
                    ConversationalPrompt(
                        id: "daytime_sleepiness",
                        questionIds: ["Q17"],
                        spokenPrompt: "Do you experience excessive daytime sleepiness, where you struggle to stay awake during the day?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "excessive_sleepiness"
                    ),
                    ConversationalPrompt(
                        id: "cognitive_issues",
                        questionIds: ["Q18"],
                        spokenPrompt: "Do you have problems with memory, concentration, or brain fog?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .yesNo,
                        validationRules: nil,
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "cognitive"
                    )
                ],
                conclusion: "Thank you for sharing about your mental state. This really helps complete the picture.",
                estimatedMinutes: 4,
                pillar: "mental_health"
            )
        ],
        openingMessage: "Welcome to Day 3!",
        closingMessage: "You've completed Day 3! Understanding the mind-sleep connection is so important. See you tomorrow!",
        estimatedMinutes: 5
    )

    static let day4Script = DayConversationScript(
        id: "day4",
        dayNumber: 4,
        title: "Body & Health",
        sections: [
            ConversationSection(
                id: "day4_physical",
                title: "Physical Health",
                introduction: "Today let's talk about your physical health and how it might affect your sleep.",
                prompts: [
                    ConversationalPrompt(
                        id: "snoring",
                        questionIds: ["Q19"],
                        spokenPrompt: "Do you snore? If you're not sure, has anyone ever told you that you snore?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .yesNoDontKnow,
                        validationRules: nil,
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "osa"
                    ),
                    ConversationalPrompt(
                        id: "breathing_stops",
                        questionIds: ["Q20"],
                        spokenPrompt: "Has anyone ever observed you stop breathing or gasp during sleep?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .yesNoDontKnow,
                        validationRules: nil,
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "osa"
                    ),
                    ConversationalPrompt(
                        id: "pain_present",
                        questionIds: ["Q22"],
                        spokenPrompt: "Do you experience chronic pain that affects your sleep?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .yesNo,
                        validationRules: nil,
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "pain"
                    ),
                    ConversationalPrompt(
                        id: "pain_severity",
                        questionIds: ["Q23"],
                        spokenPrompt: "On a scale of 1 to 10, how severe is your pain typically?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale1to10,
                        validationRules: ValidationRules(minValue: 1, maxValue: 10),
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "exercise",
                        questionIds: ["Q24"],
                        spokenPrompt: "How many days per week do you exercise?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .number,
                        validationRules: ValidationRules(minValue: 0, maxValue: 7),
                        transitionPhrase: nil
                    )
                ],
                conclusion: "Physical health plays such an important role in sleep quality.",
                estimatedMinutes: 4,
                pillar: "physical"
            )
        ],
        openingMessage: "Welcome to Day 4!",
        closingMessage: "You've completed Day 4! Great job. One more day of core questions tomorrow!",
        estimatedMinutes: 5
    )

    static let day5Script = DayConversationScript(
        id: "day5",
        dayNumber: 5,
        title: "Daily Habits",
        sections: [
            ConversationSection(
                id: "day5_habits",
                title: "Daily Habits",
                introduction: "Let's wrap up the core assessment by talking about your daily habits.",
                prompts: [
                    ConversationalPrompt(
                        id: "caffeine_intake",
                        questionIds: ["Q28"],
                        spokenPrompt: "How much caffeine do you typically have in a day? Coffee, tea, sodas, energy drinks...",
                        followUpPrompt: nil,
                        clarificationPrompt: "Like how many cups of coffee or caffeinated drinks?",
                        expectedAnswerType: .freeText,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "caffeine_timing",
                        questionIds: ["Q29"],
                        spokenPrompt: "What time is your last caffeinated drink of the day?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .time,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "alcohol",
                        questionIds: ["Q30"],
                        spokenPrompt: "How often do you drink alcohol?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "diet_sleep_impact",
                        questionIds: ["Q34"],
                        spokenPrompt: "How much do you feel your diet affects your sleep?",
                        followUpPrompt: nil,
                        clarificationPrompt: "Not at all, a little, moderately, or a lot?",
                        expectedAnswerType: .singleChoice,
                        validationRules: nil,
                        transitionPhrase: nil,
                        isGateway: true,
                        gatewayType: "diet_impact"
                    )
                ],
                conclusion: "You've completed all the core questions!",
                estimatedMinutes: 4,
                pillar: "nutritional"
            )
        ],
        openingMessage: "Welcome to Day 5 - the final day of core questions!",
        closingMessage: "Congratulations! You've completed the core assessment. Based on your answers, I may have some additional questions in the coming days to help us understand specific areas better. Great job!",
        estimatedMinutes: 5
    )

    // MARK: - Expansion Days (6-10) - Triggered by Gateways

    static let day6Script = DayConversationScript(
        id: "day6_insomnia",
        dayNumber: 6,
        title: "Insomnia Assessment",
        sections: [
            ConversationSection(
                id: "day6_isi",
                title: "Insomnia Severity",
                introduction: "Based on what you've shared, I'd like to ask some more detailed questions about your insomnia.",
                prompts: [
                    ConversationalPrompt(
                        id: "isi_1",
                        questionIds: ["ISI_1"],
                        spokenPrompt: "How much difficulty do you have falling asleep? None, mild, moderate, severe, or very severe?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to4,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "isi_2",
                        questionIds: ["ISI_2"],
                        spokenPrompt: "How much difficulty do you have staying asleep?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to4,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "isi_3",
                        questionIds: ["ISI_3"],
                        spokenPrompt: "How much of a problem is waking up too early?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to4,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "isi_4",
                        questionIds: ["ISI_4"],
                        spokenPrompt: "How satisfied or dissatisfied are you with your current sleep pattern?",
                        followUpPrompt: nil,
                        clarificationPrompt: "Very satisfied, satisfied, neutral, dissatisfied, or very dissatisfied?",
                        expectedAnswerType: .scale0to4,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "isi_5",
                        questionIds: ["ISI_5"],
                        spokenPrompt: "How noticeable to others do you think your sleep problem is, in terms of impairing the quality of your life?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to4,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "isi_6",
                        questionIds: ["ISI_6"],
                        spokenPrompt: "How worried or distressed are you about your current sleep problem?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to4,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "isi_7",
                        questionIds: ["ISI_7"],
                        spokenPrompt: "To what extent do you consider your sleep problem to interfere with your daily functioning, like concentration, memory, or mood?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to4,
                        validationRules: nil,
                        transitionPhrase: "Thank you, that really helps us understand the severity."
                    )
                ],
                conclusion: "I've calculated your insomnia severity score. This will help the specialists tailor your treatment.",
                estimatedMinutes: 5,
                pillar: "sleep_quality",
                requiredGateways: ["insomnia", "poor_sleep_quality"]
            )
        ],
        openingMessage: "Welcome to Day 6 - we're diving deeper into insomnia today.",
        closingMessage: "You've completed the insomnia assessment. This information is really valuable for your treatment plan.",
        estimatedMinutes: 5,
        requiredGateways: ["insomnia", "poor_sleep_quality"]
    )

    static let day7Script = DayConversationScript(
        id: "day7_mental",
        dayNumber: 7,
        title: "Mental Health Assessment",
        sections: [
            ConversationSection(
                id: "day7_phq9",
                title: "Mood Assessment",
                introduction: "Let's take a closer look at your mood and emotional wellbeing.",
                prompts: [
                    ConversationalPrompt(
                        id: "phq9_1",
                        questionIds: ["PHQ9_1"],
                        spokenPrompt: "Over the past 2 weeks, how often have you had little interest or pleasure in doing things?",
                        followUpPrompt: nil,
                        clarificationPrompt: "Not at all, several days, more than half the days, or nearly every day?",
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "phq9_2",
                        questionIds: ["PHQ9_2"],
                        spokenPrompt: "How often have you been feeling down, depressed, or hopeless?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "phq9_3",
                        questionIds: ["PHQ9_3"],
                        spokenPrompt: "How often have you had trouble falling asleep, staying asleep, or sleeping too much?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "phq9_4",
                        questionIds: ["PHQ9_4"],
                        spokenPrompt: "How often have you felt tired or had little energy?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "phq9_5",
                        questionIds: ["PHQ9_5"],
                        spokenPrompt: "How often have you had poor appetite or been overeating?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    )
                    // ... (PHQ9_6 through PHQ9_9 would continue similarly)
                ],
                conclusion: "Thank you for sharing. Your emotional wellbeing is an important part of sleep health.",
                estimatedMinutes: 6,
                pillar: "mental_health",
                requiredGateways: ["depression", "anxiety"]
            )
        ],
        openingMessage: "Welcome to Day 7 - today we're focusing on mental health.",
        closingMessage: "You've completed the mental health assessment. This helps us understand the connection between your mood and sleep.",
        estimatedMinutes: 8,
        requiredGateways: ["depression", "anxiety", "insomnia"]
    )

    // MARK: - Day 8: Breathing & Energy (STOP-BANG, ESS, FSS)

    static let day8Script = DayConversationScript(
        id: "day8_breathing",
        dayNumber: 8,
        title: "Breathing & Energy",
        sections: [
            // STOP-BANG Section
            ConversationSection(
                id: "day8_stopbang",
                title: "Sleep Apnea Screening",
                introduction: "Let's check a few things related to breathing during sleep. These help us screen for sleep apnea.",
                prompts: [
                    ConversationalPrompt(
                        id: "sb_snore",
                        questionIds: ["SB_S"],
                        spokenPrompt: "Do you snore loudly, loud enough to be heard through closed doors?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .yesNo,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "sb_tired",
                        questionIds: ["SB_T"],
                        spokenPrompt: "Do you often feel tired, fatigued, or sleepy during the daytime?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .yesNo,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "sb_observed",
                        questionIds: ["SB_O"],
                        spokenPrompt: "Has anyone observed you stop breathing during sleep?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .yesNoDontKnow,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "sb_pressure",
                        questionIds: ["SB_P"],
                        spokenPrompt: "Do you have or are you being treated for high blood pressure?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .yesNo,
                        validationRules: nil,
                        transitionPhrase: nil
                    )
                ],
                conclusion: "This helps us understand your sleep apnea risk.",
                estimatedMinutes: 3,
                pillar: "sleep_quality",
                requiredGateways: ["osa"]
            ),

            // Epworth Sleepiness Scale Section
            ConversationSection(
                id: "day8_ess",
                title: "Daytime Sleepiness",
                introduction: "Now I'd like to understand your daytime sleepiness. For each situation, tell me how likely you are to doze off.",
                prompts: [
                    ConversationalPrompt(
                        id: "ess_1",
                        questionIds: ["ESS_1"],
                        spokenPrompt: "How likely are you to doze off while sitting and reading? Never, slight, moderate, or high chance?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "ess_2",
                        questionIds: ["ESS_2"],
                        spokenPrompt: "What about watching TV?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "ess_3",
                        questionIds: ["ESS_3"],
                        spokenPrompt: "Sitting inactive in a public place, like a theater or meeting?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "ess_4",
                        questionIds: ["ESS_4"],
                        spokenPrompt: "As a passenger in a car for an hour without a break?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "ess_5",
                        questionIds: ["ESS_5"],
                        spokenPrompt: "Lying down to rest in the afternoon?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "ess_6",
                        questionIds: ["ESS_6"],
                        spokenPrompt: "Sitting and talking to someone?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "ess_7",
                        questionIds: ["ESS_7"],
                        spokenPrompt: "Sitting quietly after lunch without alcohol?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "ess_8",
                        questionIds: ["ESS_8"],
                        spokenPrompt: "And finally, in a car while stopped for a few minutes in traffic?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: "Thank you, this gives us a good picture of your daytime alertness."
                    )
                ],
                conclusion: "Your sleepiness score will help us understand your daytime function.",
                estimatedMinutes: 4,
                pillar: "sleep_quality",
                requiredGateways: ["excessive_sleepiness"]
            )
        ],
        openingMessage: "Welcome to Day 8 - today we're focusing on breathing and energy.",
        closingMessage: "You've completed Day 8! We have a much better picture of your breathing and alertness now.",
        estimatedMinutes: 7,
        requiredGateways: ["osa", "excessive_sleepiness"]
    )

    // MARK: - Day 9: Function & Behavior (Sleep Hygiene, BPI, FOSQ)

    static let day9Script = DayConversationScript(
        id: "day9_function",
        dayNumber: 9,
        title: "Function & Behavior",
        sections: [
            // Sleep Hygiene Section
            ConversationSection(
                id: "day9_hygiene",
                title: "Sleep Habits",
                introduction: "Let's talk about your sleep environment and habits.",
                prompts: [
                    ConversationalPrompt(
                        id: "shi_1",
                        questionIds: ["SHI_1"],
                        spokenPrompt: "Do you go to bed at different times each night?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "shi_2",
                        questionIds: ["SHI_2"],
                        spokenPrompt: "Do you use your phone, tablet, or watch TV in bed?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "shi_3",
                        questionIds: ["SHI_3"],
                        spokenPrompt: "Do you exercise within 4 hours of bedtime?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "shi_4",
                        questionIds: ["SHI_4"],
                        spokenPrompt: "Do you stay in bed when you can't sleep?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .frequency,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "shi_5",
                        questionIds: ["SHI_5"],
                        spokenPrompt: "Is your bedroom dark, quiet, and at a comfortable temperature?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .yesNo,
                        validationRules: nil,
                        transitionPhrase: nil
                    )
                ],
                conclusion: "Sleep hygiene is one of the most actionable areas for improving sleep.",
                estimatedMinutes: 3,
                pillar: "sleep_quality",
                requiredGateways: ["insomnia", "poor_sleep_quality"]
            ),

            // Brief Pain Inventory Section
            ConversationSection(
                id: "day9_pain",
                title: "Pain Assessment",
                introduction: "You mentioned having pain. Let me understand how it affects your life.",
                prompts: [
                    ConversationalPrompt(
                        id: "bpi_1",
                        questionIds: ["BPI_1"],
                        spokenPrompt: "On a scale of 0 to 10, what's your pain at its worst in the last 24 hours?",
                        followUpPrompt: nil,
                        clarificationPrompt: "0 means no pain, 10 means pain as bad as you can imagine.",
                        expectedAnswerType: .scale1to10,
                        validationRules: ValidationRules(minValue: 0, maxValue: 10),
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "bpi_2",
                        questionIds: ["BPI_2"],
                        spokenPrompt: "What's your pain at its least in the last 24 hours?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale1to10,
                        validationRules: ValidationRules(minValue: 0, maxValue: 10),
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "bpi_3",
                        questionIds: ["BPI_3"],
                        spokenPrompt: "How much does pain interfere with your sleep?",
                        followUpPrompt: nil,
                        clarificationPrompt: "0 means doesn't interfere, 10 means completely interferes.",
                        expectedAnswerType: .scale1to10,
                        validationRules: ValidationRules(minValue: 0, maxValue: 10),
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "bpi_4",
                        questionIds: ["BPI_4"],
                        spokenPrompt: "How much does pain interfere with your mood?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale1to10,
                        validationRules: ValidationRules(minValue: 0, maxValue: 10),
                        transitionPhrase: "Thank you, understanding your pain helps us help your sleep."
                    )
                ],
                conclusion: "Pain management is often key to better sleep.",
                estimatedMinutes: 3,
                pillar: "physical",
                requiredGateways: ["pain"]
            )
        ],
        openingMessage: "Welcome to Day 9 - today we're looking at function and behavior.",
        closingMessage: "You've completed Day 9! Just one more day to go.",
        estimatedMinutes: 6,
        requiredGateways: ["insomnia", "poor_sleep_quality", "pain", "excessive_sleepiness"]
    )

    // MARK: - Day 10: Lifestyle & Rhythm (PROMIS, MEQ, MEDAS)

    static let day10Script = DayConversationScript(
        id: "day10_lifestyle",
        dayNumber: 10,
        title: "Lifestyle & Rhythm",
        sections: [
            // Morningness-Eveningness Section
            ConversationSection(
                id: "day10_meq",
                title: "Your Natural Rhythm",
                introduction: "Let's understand your natural sleep-wake preference - whether you're more of a morning person or night owl.",
                prompts: [
                    ConversationalPrompt(
                        id: "meq_1",
                        questionIds: ["MEQ_1"],
                        spokenPrompt: "If you were entirely free to plan your day, what time would you ideally wake up?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .time,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "meq_2",
                        questionIds: ["MEQ_2"],
                        spokenPrompt: "If you were entirely free to plan your evening, what time would you ideally go to bed?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .time,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "meq_3",
                        questionIds: ["MEQ_3"],
                        spokenPrompt: "How alert do you feel during the first half hour after waking up?",
                        followUpPrompt: nil,
                        clarificationPrompt: "Not at all alert, slightly alert, fairly alert, or very alert?",
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "meq_4",
                        questionIds: ["MEQ_4"],
                        spokenPrompt: "At what time of day do you feel your best and most productive?",
                        followUpPrompt: nil,
                        clarificationPrompt: "Morning, midday, afternoon, or evening?",
                        expectedAnswerType: .singleChoice,
                        validationRules: ValidationRules(acceptableOptions: ["morning", "midday", "afternoon", "evening"]),
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "meq_5",
                        questionIds: ["MEQ_5"],
                        spokenPrompt: "Would you describe yourself as a morning type, evening type, or neither?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .singleChoice,
                        validationRules: ValidationRules(acceptableOptions: ["morning type", "evening type", "neither"]),
                        transitionPhrase: nil
                    )
                ],
                conclusion: "Understanding your chronotype helps us personalize your sleep recommendations.",
                estimatedMinutes: 3,
                pillar: "chronotype",
                requiredGateways: ["sleep_timing"]
            ),

            // Cognitive Function Section
            ConversationSection(
                id: "day10_cognitive",
                title: "Cognitive Function",
                introduction: "Let's assess how sleep affects your mental function.",
                prompts: [
                    ConversationalPrompt(
                        id: "cog_1",
                        questionIds: ["FOSQ_1"],
                        spokenPrompt: "How difficult has it been for you to concentrate on things because of sleepiness?",
                        followUpPrompt: nil,
                        clarificationPrompt: "No difficulty, a little, moderate, or extreme difficulty?",
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "cog_2",
                        questionIds: ["FOSQ_2"],
                        spokenPrompt: "How difficult has it been to remember things because of sleepiness?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "cog_3",
                        questionIds: ["FOSQ_3"],
                        spokenPrompt: "How difficult has it been to finish a meal because of sleepiness?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: nil
                    ),
                    ConversationalPrompt(
                        id: "cog_4",
                        questionIds: ["FOSQ_4"],
                        spokenPrompt: "Has sleepiness affected your ability to maintain relationships with friends or family?",
                        followUpPrompt: nil,
                        clarificationPrompt: nil,
                        expectedAnswerType: .scale0to3,
                        validationRules: nil,
                        transitionPhrase: "Thank you for sharing. This completes your assessment!"
                    )
                ],
                conclusion: "We now have a complete picture of how sleep affects your life.",
                estimatedMinutes: 3,
                pillar: "cognitive",
                requiredGateways: ["cognitive", "excessive_sleepiness"]
            )
        ],
        openingMessage: "Welcome to Day 10 - the final day of your assessment!",
        closingMessage: "Congratulations! You've completed the full 10-day assessment. Our specialists will now review your comprehensive sleep profile and create a personalized protocol just for you. This includes your sleep patterns, mental health connection, physical factors, and lifestyle habits. You should hear from them soon with your personalized sleep optimization plan!",
        estimatedMinutes: 8,
        requiredGateways: ["cognitive", "diet_impact", "sleep_timing"]
    )
}
