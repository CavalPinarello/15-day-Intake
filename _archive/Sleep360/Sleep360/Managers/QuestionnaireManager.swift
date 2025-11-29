//
//  QuestionnaireManager.swift
//  Zoe Sleep for Longevity System
//
//  Manages the 15-day adaptive questionnaire system with gateway logic
//

import Foundation
import SwiftUI
import Combine

@MainActor
class QuestionnaireManager: ObservableObject {
    static let shared = QuestionnaireManager()

    // MARK: - Published Properties

    @Published var currentDay: Int = 1
    @Published var journeyProgress: JourneyProgressData?
    @Published var gatewayStates: [GatewayState] = []
    @Published var responses: [String: QuestionResponse] = [:]
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    // MARK: - Initialization

    private init() {
        initializeGatewayStates()
    }

    func initializeGatewayStates() {
        gatewayStates = GatewayType.allCases.map { GatewayState(gatewayType: $0) }
    }

    // MARK: - Day Configuration

    static let dayConfigurations: [DayConfiguration] = [
        DayConfiguration(id: 1, dayNumber: 1, title: "Demographics & Sleep Quality", description: "Foundation: Basic demographics & sleep quality overview with gateway questions", estimatedMinutes: 12, moduleIds: ["core_social", "core_metabolic", "core_sleep_quality_part1"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 2, dayNumber: 2, title: "PSQI & Sleep Patterns", description: "PSQI completion + sleep patterns (weekday vs weekend, bedtimes, wake times)", estimatedMinutes: 11, moduleIds: ["core_sleep_quality_part2", "core_sleep_quantity", "core_sleep_regularity"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 3, dayNumber: 3, title: "Sleep Timing & Mental Health", description: "Light exposure, screens, mental health & cognitive function gateways", estimatedMinutes: 8, moduleIds: ["core_sleep_timing", "gateway_mental_health"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 4, dayNumber: 4, title: "Physical Health & Metabolic", description: "OSA screening, pain assessment, exercise habits, metabolic health basics", estimatedMinutes: 9, moduleIds: ["core_physical", "gateway_physical"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 5, dayNumber: 5, title: "Nutritional & Social", description: "Caffeine, alcohol, diet impacts, social sleep factors. CORE COMPLETE.", estimatedMinutes: 7, moduleIds: ["core_nutritional", "core_social_part2"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 6, dayNumber: 6, title: "ISI - Insomnia Severity", description: "Insomnia Severity Index assessment", estimatedMinutes: 8, moduleIds: ["expansion_isi"], isExpansionDay: true, requiredGateways: [.insomnia, .poorSleepQuality]),
        DayConfiguration(id: 7, dayNumber: 7, title: "DBAS-16 Part 1", description: "Dysfunctional Beliefs About Sleep (first half)", estimatedMinutes: 8, moduleIds: ["expansion_dbas_part1"], isExpansionDay: true, requiredGateways: [.insomnia]),
        DayConfiguration(id: 8, dayNumber: 8, title: "DBAS-16 Part 2 & Sleep Hygiene", description: "Complete beliefs + start sleep hygiene habits", estimatedMinutes: 14, moduleIds: ["expansion_dbas_part2", "expansion_sleep_hygiene_part1"], isExpansionDay: true, requiredGateways: [.insomnia]),
        DayConfiguration(id: 9, dayNumber: 9, title: "Sleep Hygiene & PSAS Part 1", description: "Complete hygiene + start pre-sleep arousal", estimatedMinutes: 13, moduleIds: ["expansion_sleep_hygiene_part2", "expansion_psas_part1"], isExpansionDay: true, requiredGateways: [.insomnia]),
        DayConfiguration(id: 10, dayNumber: 10, title: "PSAS Part 2 & ESS", description: "Complete pre-sleep arousal. ESS if daytime sleepiness triggered", estimatedMinutes: 16, moduleIds: ["expansion_psas_part2", "expansion_ess"], isExpansionDay: true, requiredGateways: [.insomnia, .excessiveSleepiness]),
        DayConfiguration(id: 11, dayNumber: 11, title: "FSS & FOSQ-10 Part 1", description: "Fatigue scale + functional outcomes", estimatedMinutes: 14, moduleIds: ["expansion_fss", "expansion_fosq_part1"], isExpansionDay: true, requiredGateways: [.excessiveSleepiness]),
        DayConfiguration(id: 12, dayNumber: 12, title: "FOSQ-10 Part 2 & PHQ-9 & GAD-7", description: "Complete functional outcomes. Start mental health assessments", estimatedMinutes: 14, moduleIds: ["expansion_fosq_part2", "expansion_phq9", "expansion_gad7_part1"], isExpansionDay: true, requiredGateways: [.depression, .anxiety]),
        DayConfiguration(id: 13, dayNumber: 13, title: "GAD-7 Part 2 & DASS-21 & PROMIS", description: "Complete anxiety screen. Comprehensive mental health + cognitive function", estimatedMinutes: 16, moduleIds: ["expansion_gad7_part2", "expansion_dass21_part1", "expansion_promis_cognitive"], isExpansionDay: true, requiredGateways: [.anxiety, .cognitive]),
        DayConfiguration(id: 14, dayNumber: 14, title: "DASS-21 Part 2 & STOP-BANG & Berlin", description: "Complete DASS-21. OSA screening if gateway triggered", estimatedMinutes: 21, moduleIds: ["expansion_dass21_part2", "expansion_stop_bang", "expansion_berlin"], isExpansionDay: true, requiredGateways: [.osa]),
        DayConfiguration(id: 15, dayNumber: 15, title: "BPI & MEDAS & MEQ", description: "Pain inventory, diet assessment, chronotype. Flexible completion day.", estimatedMinutes: 29, moduleIds: ["expansion_bpi", "expansion_medas", "expansion_meq"], isExpansionDay: true, requiredGateways: [.pain, .dietImpact, .sleepTiming])
    ]

    // MARK: - Stanford Sleep Log Questions (Asked Every Day)

    static let stanfordSleepLogQuestions: [Question] = [
        Question(
            id: "SL_BEDTIME",
            text: "What time did you go to bed last night?",
            pillar: .sleepLog,
            questionType: .time,
            helpText: "Your subjective perception - don't check your wearable device",
            group: "sleep_log"
        ),
        Question(
            id: "SL_ASLEEP_TIME",
            text: "What time did you fall asleep last night?",
            pillar: .sleepLog,
            questionType: .time,
            helpText: "Your best estimate - don't check your wearable",
            group: "sleep_log"
        ),
        Question(
            id: "SL_AWAKENINGS",
            text: "How many times did you wake up during the night?",
            pillar: .sleepLog,
            questionType: .numberScroll,
            minValue: 0,
            maxValue: 20,
            defaultValue: 0,
            group: "sleep_log"
        ),
        Question(
            id: "SL_WAKE_TIME",
            text: "What time did you wake up this morning?",
            pillar: .sleepLog,
            questionType: .time,
            helpText: "Final awakening - don't check your wearable",
            group: "sleep_log"
        ),
        Question(
            id: "SL_QUALITY",
            text: "How would you rate your sleep quality last night?",
            pillar: .sleepLog,
            questionType: .scale,
            scaleMin: 1,
            scaleMax: 10,
            scaleMinLabel: "Very Poor",
            scaleMaxLabel: "Excellent",
            group: "sleep_log"
        )
    ]

    // MARK: - Core Questions by Day

    static let coreQuestionsByDay: [Int: [Question]] = [
        // DAY 1: Demographics + Sleep Quality Core
        1: [
            // Demographics
            Question(id: "D1", text: "What is your full name?", pillar: .social, questionType: .text),
            Question(id: "D2", text: "What is your date of birth?", pillar: .social, questionType: .date),
            Question(id: "D4", text: "What is your sex assigned at birth?", pillar: .metabolic, questionType: .singleSelect, options: ["Male", "Female", "Other"]),
            Question(id: "D5", text: "What is your height?", pillar: .metabolic, questionType: .number, minValue: 100, maxValue: 250, unit: "cm"),
            Question(id: "D6", text: "What is your weight?", pillar: .metabolic, questionType: .number, minValue: 30, maxValue: 300, unit: "kg"),

            // Sleep Quality Core (Gateway Questions)
            Question(
                id: "1",
                text: "Overall sleep quality in past month",
                pillar: .sleepQuality,
                questionType: .scale,
                scaleMin: 1,
                scaleMax: 10,
                scaleMinLabel: "Very Poor",
                scaleMaxLabel: "Excellent",
                isGateway: true,
                gatewayType: .poorSleepQuality,
                gatewayThreshold: 5
            ),
            Question(id: "2", text: "How often do you feel refreshed after sleep?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Never", "Rarely", "Sometimes", "Often", "Always"]),
            Question(
                id: "3",
                text: "Do you have trouble falling asleep, staying asleep, or waking too early?",
                pillar: .sleepQuality,
                questionType: .yesNo,
                isGateway: true,
                gatewayType: .insomnia
            ),

            // PSQI Part 1
            Question(id: "PSQI_1", text: "During the past month, when have you usually gone to bed at night?", pillar: .sleepQuality, questionType: .time, helpText: "Your subjective perception - don't check your wearable device"),
            Question(
                id: "PSQI_2",
                text: "During the past month, how long (in minutes) has it usually taken you to fall asleep each night?",
                pillar: .sleepQuality,
                questionType: .minutesScroll,
                minValue: 0,
                maxValue: 180,
                unit: "minutes",
                helpText: nil,
                isGateway: true,
                gatewayType: .insomnia,
                gatewayThreshold: 30
            ),
            Question(id: "PSQI_3", text: "During the past month, when have you usually gotten up in the morning?", pillar: .sleepQuality, questionType: .time, helpText: "Your subjective perception - don't check your wearable"),
            Question(id: "PSQI_4", text: "During the past month, how many hours of actual sleep did you get at night?", pillar: .sleepQuality, questionType: .number, minValue: 0, maxValue: 15, step: 0.5, unit: "hours")
        ],

        // DAY 2: PSQI Part 2 + Sleep Quantity + Sleep Regularity
        2: [
            Question(
                id: "PSQI_5a",
                text: "How often have you had trouble sleeping because you cannot get to sleep within 30 minutes?",
                pillar: .sleepQuality,
                questionType: .singleSelect,
                options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"],
                isGateway: true,
                gatewayType: .insomnia,
                gatewayThreshold: 2
            ),
            Question(
                id: "PSQI_5b",
                text: "How often have you had trouble sleeping because you wake up in the middle of the night or early morning?",
                pillar: .sleepQuality,
                questionType: .singleSelect,
                options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"],
                isGateway: true,
                gatewayType: .insomnia,
                gatewayThreshold: 2
            ),
            Question(id: "PSQI_5c", text: "How often have you had trouble sleeping because you have to get up to use the bathroom?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]),
            Question(id: "12A", text: "How many times do you typically wake up during the night?", pillar: .sleepQuality, questionType: .number, minValue: 0, maxValue: 15),
            Question(id: "12B", text: "When you wake up at night, what is the MAIN reason?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Bathroom needs", "Pain/discomfort", "Noise", "Light", "Hot/cold", "Dreams/nightmares", "Worry/stress", "Other"]),

            // Sleep Regularity
            Question(id: "7", text: "What time do you usually go to bed on weekdays?", pillar: .sleepRegularity, questionType: .time),
            Question(id: "8", text: "What time do you usually wake up on weekdays?", pillar: .sleepRegularity, questionType: .time),
            Question(id: "9", text: "What time do you usually go to bed on weekends?", pillar: .sleepRegularity, questionType: .time),
            Question(id: "10", text: "What time do you usually wake up on weekends?", pillar: .sleepRegularity, questionType: .time),
            Question(id: "REG_1", text: "Do you use an alarm clock on weekdays?", pillar: .sleepRegularity, questionType: .singleSelect, options: ["Never", "Rarely", "Sometimes", "Usually", "Always"]),
            Question(
                id: "REG_2",
                text: "How much does your bedtime vary from night to night?",
                pillar: .sleepRegularity,
                questionType: .singleSelect,
                options: ["Less than 15 minutes", "15-30 minutes", "30-60 minutes", "1-2 hours", "More than 2 hours"],
                isGateway: true,
                gatewayType: .sleepTiming,
                gatewayThreshold: 3
            )
        ],

        // DAY 3: Sleep Timing + Mental Health Gateways
        3: [
            Question(id: "11", text: "How often do you get morning sunlight exposure within 1 hour of waking?", pillar: .sleepTiming, questionType: .singleSelect, options: ["Never", "Rarely", "Sometimes", "Often", "Daily"]),
            Question(id: "12", text: "How many hours per day do you spend looking at screens for work?", pillar: .social, questionType: .number, minValue: 0, maxValue: 18, step: nil, unit: "hours"),
            Question(id: "13", text: "How often do you use electronic devices within 1 hour of bedtime?", pillar: .sleepTiming, questionType: .singleSelect, options: ["Never", "Rarely", "Sometimes", "Often", "Always"]),
            Question(id: "14", text: "On a scale of 1-10, how would you rate your current stress level?", pillar: .mentalHealth, questionType: .scale, scaleMin: 1, scaleMax: 10, scaleMinLabel: "No stress", scaleMaxLabel: "Extremely stressed"),
            Question(
                id: "15",
                text: "Over the past 2 weeks, how often have you felt down, depressed, or hopeless?",
                pillar: .mentalHealth,
                questionType: .singleSelect,
                options: ["Not at all", "Several days", "More than half the days", "Nearly every day"],
                isGateway: true,
                gatewayType: .depression,
                gatewayThreshold: 2
            ),
            Question(
                id: "16",
                text: "Over the past 2 weeks, how often have you felt nervous, anxious, or on edge?",
                pillar: .mentalHealth,
                questionType: .singleSelect,
                options: ["Not at all", "Several days", "More than half the days", "Nearly every day"],
                isGateway: true,
                gatewayType: .anxiety,
                gatewayThreshold: 2
            ),
            Question(
                id: "17",
                text: "Do you feel excessively tired or sleepy during the day?",
                pillar: .cognitive,
                questionType: .singleSelect,
                options: ["Never", "Rarely", "Sometimes", "Often", "Always"],
                isGateway: true,
                gatewayType: .excessiveSleepiness,
                gatewayThreshold: 3
            ),
            Question(
                id: "18",
                text: "Do you experience memory problems, difficulty concentrating, or mental fog?",
                pillar: .cognitive,
                questionType: .yesNo,
                isGateway: true,
                gatewayType: .cognitive
            )
        ],

        // DAY 4: Physical Health Gateways + Metabolic Core
        4: [
            Question(
                id: "19",
                text: "Do you snore loudly (louder than talking or loud enough to be heard through closed doors)?",
                pillar: .physical,
                questionType: .yesNoDontKnow,
                isGateway: true,
                gatewayType: .osa
            ),
            Question(
                id: "20",
                text: "Has anyone observed you stop breathing during your sleep?",
                pillar: .physical,
                questionType: .yesNoDontKnow,
                isGateway: true,
                gatewayType: .osa
            ),
            Question(id: "21", text: "Do you often feel tired, fatigued, or sleepy during daytime?", pillar: .physical, questionType: .yesNo),
            Question(
                id: "22",
                text: "Do you experience pain that affects your sleep?",
                pillar: .physical,
                questionType: .yesNo,
                isGateway: true,
                gatewayType: .pain
            ),
            Question(
                id: "23",
                text: "On average, what is your pain level?",
                pillar: .physical,
                questionType: .scale,
                scaleMin: 0,
                scaleMax: 10,
                scaleMinLabel: "No pain",
                scaleMaxLabel: "Worst possible",
                isGateway: true,
                gatewayType: .pain,
                gatewayThreshold: 4,
                conditionalLogic: ConditionalLogic(questionId: "22", equals: "Yes")
            ),
            Question(id: "24", text: "How often do you exercise or engage in physical activity?", pillar: .physical, questionType: .singleSelect, options: ["Never", "Less than once a week", "1-2 times per week", "3-4 times per week", "5+ times per week"]),
            Question(id: "25", text: "What time of day do you typically exercise?", pillar: .physical, questionType: .singleSelect, options: ["Morning", "Afternoon", "Evening", "Night", "Varies", "I don't exercise"]),
            Question(id: "26", text: "Do you have diabetes or pre-diabetes?", pillar: .metabolic, questionType: .yesNoDontKnow),
            Question(id: "27", text: "Do you have or are you being treated for high blood pressure?", pillar: .metabolic, questionType: .yesNo)
        ],

        // DAY 5: Nutritional Core + Social Factors
        5: [
            Question(id: "29", text: "Do you consume caffeine (coffee, tea, energy drinks)?", pillar: .nutritional, questionType: .singleSelect, options: ["Never", "Rarely", "Sometimes", "Often", "Daily"]),
            Question(id: "30", text: "If you consume caffeine, how many cups/servings per day?", pillar: .nutritional, questionType: .number, required: false, minValue: 0, maxValue: 20, conditionalLogic: ConditionalLogic(questionId: "29", equals: "Never")),
            Question(id: "31", text: "What time is your last caffeine intake typically?", pillar: .nutritional, questionType: .time, required: false, helpText: nil),
            Question(id: "32", text: "How often do you consume alcohol?", pillar: .nutritional, questionType: .singleSelect, options: ["Never", "Less than monthly", "Monthly", "Weekly", "Daily"]),
            Question(id: "33", text: "If you drink alcohol, when is it typically in relation to bedtime?", pillar: .nutritional, questionType: .singleSelect, options: ["More than 4 hours before bed", "2-4 hours before bed", "Within 2 hours of bed", "I don't drink alcohol"]),
            Question(
                id: "34",
                text: "Do you notice your diet affects your sleep quality?",
                pillar: .nutritional,
                questionType: .singleSelect,
                options: ["Not at all", "Slightly", "Moderately", "Quite a bit", "Extremely"],
                isGateway: true,
                gatewayType: .dietImpact,
                gatewayThreshold: 2
            ),
            Question(id: "35", text: "Do you share your bedroom with a partner?", pillar: .social, questionType: .yesNo),
            Question(id: "36", text: "If yes, do they snore or disturb your sleep?", pillar: .social, questionType: .yesNo, required: false, helpText: nil, conditionalLogic: ConditionalLogic(questionId: "35", equals: "Yes")),
            Question(id: "37", text: "Do you have young children or infants at home?", pillar: .social, questionType: .yesNo),
            Question(id: "53E", text: "On a scale of 1-10, how would you rate your current work-related stress?", pillar: .social, questionType: .scale, scaleMin: 1, scaleMax: 10, scaleMinLabel: "No stress", scaleMaxLabel: "Extreme stress")
        ]
    ]

    // MARK: - Expansion Questions (Days 6-15)

    static let expansionQuestionsByModule: [String: [Question]] = [
        // ISI - Insomnia Severity Index (Day 6)
        "expansion_isi": [
            Question(id: "ISI_1", text: "Difficulty falling asleep - rate severity (0-4)", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 4, scaleMinLabel: "None", scaleMaxLabel: "Very Severe"),
            Question(id: "ISI_2", text: "Difficulty staying asleep - rate severity (0-4)", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 4, scaleMinLabel: "None", scaleMaxLabel: "Very Severe"),
            Question(id: "ISI_3", text: "Problems waking up too early - rate severity (0-4)", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 4, scaleMinLabel: "None", scaleMaxLabel: "Very Severe"),
            Question(id: "ISI_4", text: "How SATISFIED/dissatisfied are you with your current sleep pattern?", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 4, scaleMinLabel: "Very Satisfied", scaleMaxLabel: "Very Dissatisfied"),
            Question(id: "ISI_5", text: "How NOTICEABLE to others do you think your sleeping problem is in terms of impairing the quality of your life?", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 4, scaleMinLabel: "Not at all", scaleMaxLabel: "Very Much"),
            Question(id: "ISI_6", text: "How WORRIED/distressed are you about your current sleep problem?", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 4, scaleMinLabel: "Not at all", scaleMaxLabel: "Very Much"),
            Question(id: "ISI_7", text: "To what extent do you consider your sleep problem to INTERFERE with your daily functioning?", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 4, scaleMinLabel: "Not at all", scaleMaxLabel: "Very Much")
        ],

        // ESS - Epworth Sleepiness Scale (Day 10)
        "expansion_ess": [
            Question(id: "ESS_1", text: "How likely are you to doze off: Sitting and reading?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Would never doze", scaleMaxLabel: "High chance"),
            Question(id: "ESS_2", text: "How likely are you to doze off: Watching TV?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Would never doze", scaleMaxLabel: "High chance"),
            Question(id: "ESS_3", text: "How likely are you to doze off: Sitting inactive in a public place?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Would never doze", scaleMaxLabel: "High chance"),
            Question(id: "ESS_4", text: "How likely are you to doze off: As a passenger in a car for an hour?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Would never doze", scaleMaxLabel: "High chance"),
            Question(id: "ESS_5", text: "How likely are you to doze off: Lying down to rest in the afternoon?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Would never doze", scaleMaxLabel: "High chance"),
            Question(id: "ESS_6", text: "How likely are you to doze off: Sitting and talking to someone?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Would never doze", scaleMaxLabel: "High chance"),
            Question(id: "ESS_7", text: "How likely are you to doze off: Sitting quietly after a lunch without alcohol?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Would never doze", scaleMaxLabel: "High chance"),
            Question(id: "ESS_8", text: "How likely are you to doze off: In a car, while stopped for a few minutes in traffic?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Would never doze", scaleMaxLabel: "High chance")
        ],

        // PHQ-9 - Patient Health Questionnaire (Day 12)
        "expansion_phq9": [
            Question(id: "PHQ9_1", text: "Over the last 2 weeks: Little interest or pleasure in doing things?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "PHQ9_2", text: "Over the last 2 weeks: Feeling down, depressed, or hopeless?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "PHQ9_3", text: "Over the last 2 weeks: Trouble falling or staying asleep, or sleeping too much?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "PHQ9_4", text: "Over the last 2 weeks: Feeling tired or having little energy?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "PHQ9_5", text: "Over the last 2 weeks: Poor appetite or overeating?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "PHQ9_6", text: "Over the last 2 weeks: Feeling bad about yourself - or that you are a failure?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "PHQ9_7", text: "Over the last 2 weeks: Trouble concentrating on things?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "PHQ9_8", text: "Over the last 2 weeks: Moving or speaking slowly, or being fidgety/restless?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "PHQ9_9", text: "Over the last 2 weeks: Thoughts that you would be better off dead or of hurting yourself?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"])
        ],

        // GAD-7 - Generalized Anxiety Disorder (Days 12-13)
        "expansion_gad7_part1": [
            Question(id: "GAD7_1", text: "Over the last 2 weeks: Feeling nervous, anxious, or on edge?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "GAD7_2", text: "Over the last 2 weeks: Not being able to stop or control worrying?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "GAD7_3", text: "Over the last 2 weeks: Worrying too much about different things?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "GAD7_4", text: "Over the last 2 weeks: Trouble relaxing?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"])
        ],
        "expansion_gad7_part2": [
            Question(id: "GAD7_5", text: "Over the last 2 weeks: Being so restless that it is hard to sit still?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "GAD7_6", text: "Over the last 2 weeks: Becoming easily annoyed or irritable?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"]),
            Question(id: "GAD7_7", text: "Over the last 2 weeks: Feeling afraid, as if something awful might happen?", pillar: .mentalHealth, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Several days", "More than half the days", "Nearly every day"])
        ],

        // STOP-BANG (Day 14)
        "expansion_stop_bang": [
            Question(id: "SB_1", text: "Do you Snore loudly (louder than talking or loud enough to be heard through closed doors)?", pillar: .physical, tier: .expansion, questionType: .yesNo),
            Question(id: "SB_2", text: "Do you often feel Tired, fatigued, or sleepy during daytime?", pillar: .physical, tier: .expansion, questionType: .yesNo),
            Question(id: "SB_3", text: "Has anyone Observed you stop breathing during your sleep?", pillar: .physical, tier: .expansion, questionType: .yesNo),
            Question(id: "SB_4", text: "Do you have or are you being treated for high blood Pressure?", pillar: .physical, tier: .expansion, questionType: .yesNo),
            Question(id: "SB_5", text: "BMI more than 35 kg/m²?", pillar: .physical, tier: .expansion, questionType: .yesNo, helpText: "Calculated from your height and weight"),
            Question(id: "SB_6", text: "Age over 50 years old?", pillar: .physical, tier: .expansion, questionType: .yesNo),
            Question(id: "SB_7", text: "Neck circumference greater than 40cm (15.75 inches)?", pillar: .physical, tier: .expansion, questionType: .yesNo),
            Question(id: "SB_8", text: "Gender = Male?", pillar: .physical, tier: .expansion, questionType: .yesNo)
        ]
    ]

    // MARK: - Get Questions for a Day

    func getQuestionsForDay(_ dayNumber: Int) -> [Question] {
        var questions: [Question] = []

        // 1. Always start with Stanford Sleep Log
        questions.append(contentsOf: Self.stanfordSleepLogQuestions)

        // 2. Add core questions for days 1-5
        if dayNumber <= 5, let coreQuestions = Self.coreQuestionsByDay[dayNumber] {
            questions.append(contentsOf: coreQuestions)
        }

        // 3. For expansion days (6-15), check gateway triggers
        if dayNumber > 5 {
            guard let config = Self.dayConfigurations.first(where: { $0.dayNumber == dayNumber }) else {
                return questions
            }

            // Check if any required gateway is triggered
            let shouldShowExpansion = config.requiredGateways?.contains(where: { gateway in
                gatewayStates.first(where: { $0.gatewayType == gateway })?.triggered ?? false
            }) ?? false

            if shouldShowExpansion {
                // Add expansion questions for triggered modules
                for moduleId in config.moduleIds {
                    if let moduleQuestions = Self.expansionQuestionsByModule[moduleId] {
                        questions.append(contentsOf: moduleQuestions)
                    }
                }
            } else {
                // No expansion needed - show info message
                questions.append(Question(
                    id: "INFO_NO_EXPANSION",
                    text: "Based on your previous responses, no additional questions are needed for today. Great news - you're all caught up!",
                    pillar: .sleepQuality,
                    questionType: .info,
                    required: false
                ))
            }
        }

        // 4. Filter out questions based on conditional logic
        return filterQuestionsWithConditionalLogic(questions)
    }

    private func filterQuestionsWithConditionalLogic(_ questions: [Question]) -> [Question] {
        return questions.filter { question in
            guard let logic = question.conditionalLogic else { return true }

            // Check if the conditional question has been answered
            guard let response = responses[logic.questionId] else { return false }

            // Evaluate the condition
            if let equals = logic.equals {
                return response.stringValue == equals
            }
            if let greaterThan = logic.greaterThan, let num = response.numberValue {
                return num > greaterThan
            }
            if let lessThan = logic.lessThan, let num = response.numberValue {
                return num < lessThan
            }

            return true
        }
    }

    // MARK: - Gateway Evaluation

    func evaluateGateways() {
        for i in 0..<gatewayStates.count {
            let gateway = gatewayStates[i]
            let triggered = evaluateSingleGateway(gateway.gatewayType)

            if triggered != gateway.triggered {
                gatewayStates[i].triggered = triggered
                if triggered {
                    gatewayStates[i].triggeredAt = Date()
                }
            }
        }
    }

    private func evaluateSingleGateway(_ gatewayType: GatewayType) -> Bool {
        switch gatewayType {
        case .insomnia:
            // Triggered if question 3 = "Yes" OR sleep latency > 30 mins OR PSQI 5a/5b >= 2
            if let response = responses["3"], response.stringValue == "Yes" { return true }
            if let response = responses["PSQI_2"], let mins = response.numberValue, mins > 30 { return true }
            if let response = responses["PSQI_5a"], let index = getOptionIndex(response.stringValue, for: "PSQI_5a"), index >= 2 { return true }
            if let response = responses["PSQI_5b"], let index = getOptionIndex(response.stringValue, for: "PSQI_5b"), index >= 2 { return true }
            return false

        case .poorSleepQuality:
            // Triggered if question 1 <= 5
            if let response = responses["1"], let score = response.numberValue, score <= 5 { return true }
            return evaluateSingleGateway(.insomnia) // Also triggered if insomnia gateway is triggered

        case .depression:
            // Triggered if question 15 >= "More than half the days" (index 2)
            if let response = responses["15"], let index = getOptionIndex(response.stringValue, for: "15"), index >= 2 { return true }
            return false

        case .anxiety:
            // Triggered if question 16 >= "More than half the days" (index 2)
            if let response = responses["16"], let index = getOptionIndex(response.stringValue, for: "16"), index >= 2 { return true }
            return false

        case .excessiveSleepiness:
            // Triggered if question 17 >= "Often" (index 3)
            if let response = responses["17"], let index = getOptionIndex(response.stringValue, for: "17"), index >= 3 { return true }
            return false

        case .cognitive:
            // Triggered if question 18 = "Yes"
            if let response = responses["18"], response.stringValue == "Yes" { return true }
            return false

        case .osa:
            // Triggered if question 19 = "Yes" OR question 20 = "Yes"
            if let response = responses["19"], response.stringValue == "Yes" { return true }
            if let response = responses["20"], response.stringValue == "Yes" { return true }
            return false

        case .pain:
            // Triggered if question 22 = "Yes" AND question 23 >= 4
            if let q22 = responses["22"], q22.stringValue == "Yes",
               let q23 = responses["23"], let score = q23.numberValue, score >= 4 {
                return true
            }
            return false

        case .sleepTiming:
            // Triggered if bedtime variance > 1 hour OR weekday-weekend difference > 1 hour
            if let response = responses["REG_2"], let index = getOptionIndex(response.stringValue, for: "REG_2"), index >= 3 { return true }
            // Calculate weekday-weekend difference
            if let weekdayBed = responses["7"]?.stringValue,
               let weekendBed = responses["9"]?.stringValue,
               let diff = calculateTimeDifference(weekdayBed, weekendBed),
               diff > 60 {
                return true
            }
            return false

        case .dietImpact:
            // Triggered if question 34 >= "Moderately" (index 2)
            if let response = responses["34"], let index = getOptionIndex(response.stringValue, for: "34"), index >= 2 { return true }
            return false
        }
    }

    private func getOptionIndex(_ value: String?, for questionId: String) -> Int? {
        guard let value = value else { return nil }
        let allQuestions = Self.coreQuestionsByDay.values.flatMap { $0 }
        guard let question = allQuestions.first(where: { $0.id == questionId }),
              let options = question.options else { return nil }
        return options.firstIndex(of: value)
    }

    private func calculateTimeDifference(_ time1: String, _ time2: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let date1 = formatter.date(from: time1),
              let date2 = formatter.date(from: time2) else { return nil }

        let calendar = Calendar.current
        let components1 = calendar.dateComponents([.hour, .minute], from: date1)
        let components2 = calendar.dateComponents([.hour, .minute], from: date2)

        guard let hour1 = components1.hour, let min1 = components1.minute,
              let hour2 = components2.hour, let min2 = components2.minute else { return nil }

        let totalMinutes1 = hour1 * 60 + min1
        let totalMinutes2 = hour2 * 60 + min2

        return abs(totalMinutes1 - totalMinutes2)
    }

    // MARK: - Response Management

    func saveResponse(_ response: QuestionResponse) {
        responses[response.questionId] = response
        evaluateGateways()
    }

    func getResponse(for questionId: String) -> QuestionResponse? {
        return responses[questionId]
    }

    // MARK: - HealthKit Integration

    func prefillFromHealthKit(_ sleepSummary: HealthKitSleepSummary) {
        // Pre-fill sleep log questions with HealthKit data
        if let inBedTime = sleepSummary.formattedInBedTime {
            // Don't auto-fill - just show as suggestion
            // User should enter their subjective perception
        }

        // Could show a comparison view after user enters their data
    }

    // MARK: - Day Completion

    func completeDay(_ dayNumber: Int) async throws {
        guard convexService.isAuthenticated else {
            throw QuestionnaireError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await convexService.completeDay(dayNumber: dayNumber)
            currentDay = result.newDay

            // Update journey progress
            if var progress = journeyProgress {
                if !progress.completedDays.contains(dayNumber) {
                    progress.completedDays.append(dayNumber)
                }
                progress.gatewayStates = gatewayStates
                journeyProgress = progress
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Load Progress

    func loadJourneyProgress() async {
        guard convexService.isAuthenticated else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let progress = try await convexService.getJourneyProgress()
            currentDay = progress.currentDay
            journeyProgress = JourneyProgressData(
                currentDay: progress.currentDay,
                completedDays: progress.completedDays,
                totalDays: progress.totalDays,
                startedAt: Date(timeIntervalSince1970: TimeInterval(progress.startedAt)),
                gatewayStates: gatewayStates
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Errors

enum QuestionnaireError: LocalizedError {
    case notAuthenticated
    case dayNotAvailable
    case questionNotFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Please sign in to continue"
        case .dayNotAvailable: return "This day is not yet available"
        case .questionNotFound: return "Question not found"
        case .invalidResponse: return "Invalid response format"
        }
    }
}
