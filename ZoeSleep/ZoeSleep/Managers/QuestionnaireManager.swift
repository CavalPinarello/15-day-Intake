//
//  QuestionnaireManager.swift
//  Zoe Sleep for Longevity System
//
//  Manages the 15-day adaptive questionnaire system with gateway logic
//

import Foundation
import SwiftUI
import Combine

// Notification posted when questionnaire progress changes (section completion, day change, etc.)
extension Notification.Name {
    static let questionnaireProgressDidChange = Notification.Name("questionnaireProgressDidChange")
}

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

    // Cached expansion schedule from Convex (for Days 6+)
    @Published var scheduledExpansionForToday: ExpansionDayInfo?

    // Actual assessment question count for today (loaded from getQuestionsForUserDay)
    // This is the source of truth for whether there's an assessment to show
    @Published var assessmentQuestionCountForToday: Int = 0

    // HealthKit demographics cache - set by views with HealthKitManager access
    // Used to skip demographic questions if HealthKit has the data
    var healthKitDateOfBirth: Date?
    var healthKitBiologicalSex: String?
    var healthKitHeightCm: Double?
    var healthKitWeightKg: Double?

    /// Update HealthKit demographics cache from HealthKitManager
    /// Call this from views that have access to HealthKitManager
    func updateHealthKitDemographics(dateOfBirth: Date?, biologicalSex: String?, heightCm: Double?, weightKg: Double?) {
        self.healthKitDateOfBirth = dateOfBirth
        self.healthKitBiologicalSex = biologicalSex
        self.healthKitHeightCm = heightCm
        self.healthKitWeightKg = weightKg
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let convexService = ConvexService.shared

    /// Maps Convex consolidated module IDs to iOS module parts
    /// Convex uses single IDs like "expansion_dbas" while iOS has split modules like "expansion_dbas_part1", "expansion_dbas_part2"
    private static let convexToIOSModuleMapping: [String: [String]] = [
        // Consolidated modules -> iOS parts
        "expansion_isi": ["expansion_isi"],
        "expansion_phq9": ["expansion_phq9"],
        "expansion_gad7": ["expansion_gad7_part1", "expansion_gad7_part2"],
        "expansion_stop_bang": ["expansion_stop_bang"],
        "expansion_ess": ["expansion_ess"],
        "expansion_berlin": ["expansion_berlin"],
        "expansion_dbas": ["expansion_dbas_part1", "expansion_dbas_part2"],
        "expansion_sleep_hygiene": ["expansion_sleep_hygiene_part1", "expansion_sleep_hygiene_part2"],
        "expansion_psas": ["expansion_psas_part1", "expansion_psas_part2"],
        "expansion_fss": ["expansion_fss"],
        "expansion_fosq": ["expansion_fosq_part1", "expansion_fosq_part2"],
        "expansion_dass21": ["expansion_dass21_part1", "expansion_dass21_part2"],
        "expansion_promis_cognitive": ["expansion_promis_cognitive"],
        "expansion_bpi": ["expansion_bpi"],
        "expansion_medas": ["expansion_medas"],
        "expansion_meq": ["expansion_meq"]
    ]

    // MARK: - Initialization

    private init() {
        initializeGatewayStates()
    }

    func initializeGatewayStates() {
        gatewayStates = GatewayType.allCases.map { GatewayState(gatewayType: $0) }
    }

    /// Reset local questionnaire state for a new user
    /// Called when a different user logs in
    func resetForNewUser() {
        print("[QuestionnaireManager] Resetting state for new user")
        currentDay = 1
        journeyProgress = nil
        responses = [:]
        error = nil
        scheduledExpansionForToday = nil
        assessmentQuestionCountForToday = 0
        answeredSemanticConcepts.removeAll()  // Reset redundancy tracking
        initializeGatewayStates()
    }

    /// Load the expansion schedule for today from Convex (for Days 6+)
    func loadExpansionScheduleForDay(_ dayNumber: Int) async {
        // Only load for expansion days (6+)
        guard dayNumber >= 6 else {
            scheduledExpansionForToday = nil
            return
        }

        do {
            let expansion = try await convexService.getExpansionForDay(dayNumber: dayNumber)
            await MainActor.run {
                self.scheduledExpansionForToday = expansion
                if let exp = expansion {
                    print("[QuestionnaireManager] Loaded expansion for day \(dayNumber): \(exp.modules.count) modules, \(exp.totalQuestions) questions")
                } else {
                    print("[QuestionnaireManager] No expansion scheduled for day \(dayNumber)")
                }
            }
        } catch {
            print("[QuestionnaireManager] Failed to load expansion schedule: \(error)")
            await MainActor.run {
                self.scheduledExpansionForToday = nil
            }
        }
    }

    /// Load the actual assessment question count for a day from Convex
    /// This is the source of truth for whether there's an assessment to show
    func loadAssessmentQuestionCountForDay(_ dayNumber: Int) async {
        do {
            let questions = try await convexService.getQuestionsForUserDay(dayNumber: dayNumber, section: "assessment")
            // Filter out the INFO_NO_QUESTIONS placeholder
            let realQuestions = questions.assessment.filter { $0.id != "INFO_NO_QUESTIONS" }
            await MainActor.run {
                self.assessmentQuestionCountForToday = realQuestions.count
                print("[QuestionnaireManager] Loaded assessment question count for day \(dayNumber): \(realQuestions.count) questions")
            }
        } catch {
            print("[QuestionnaireManager] Failed to load assessment question count: \(error)")
            await MainActor.run {
                // Fall back to expansion schedule count if available
                self.assessmentQuestionCountForToday = self.scheduledExpansionForToday?.totalQuestions ?? 0
            }
        }
    }

    // MARK: - Day Configuration

    static let dayConfigurations: [DayConfiguration] = [
        DayConfiguration(id: 1, dayNumber: 1, title: "Demographics & Sleep Quality", description: "About you and your sleep habits", estimatedMinutes: 12, moduleIds: ["core_social", "core_metabolic", "core_sleep_quality_part1"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 2, dayNumber: 2, title: "PSQI & Sleep Patterns", description: "Sleep patterns and quality assessment", estimatedMinutes: 11, moduleIds: ["core_sleep_quality_part2", "core_sleep_quantity", "core_sleep_regularity"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 3, dayNumber: 3, title: "Sleep Timing & Mental Health", description: "Light, screens, and wellbeing", estimatedMinutes: 8, moduleIds: ["core_sleep_timing", "gateway_mental_health"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 4, dayNumber: 4, title: "Physical Health & Metabolic", description: "Physical health and activity", estimatedMinutes: 9, moduleIds: ["core_physical", "gateway_physical"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 5, dayNumber: 5, title: "Nutritional & Social", description: "Diet, substances, and social factors", estimatedMinutes: 7, moduleIds: ["core_nutritional", "core_social_part2"], isExpansionDay: false, requiredGateways: nil),
        DayConfiguration(id: 6, dayNumber: 6, title: "ISI - Insomnia Severity", description: "Insomnia severity assessment", estimatedMinutes: 8, moduleIds: ["expansion_isi"], isExpansionDay: true, requiredGateways: [.insomnia, .poorSleepQuality]),
        DayConfiguration(id: 7, dayNumber: 7, title: "DBAS-16 Part 1", description: "Sleep beliefs assessment (part 1)", estimatedMinutes: 8, moduleIds: ["expansion_dbas_part1"], isExpansionDay: true, requiredGateways: [.insomnia]),
        DayConfiguration(id: 8, dayNumber: 8, title: "DBAS-16 Part 2 & Sleep Hygiene", description: "Sleep beliefs and habits", estimatedMinutes: 14, moduleIds: ["expansion_dbas_part2", "expansion_sleep_hygiene_part1"], isExpansionDay: true, requiredGateways: [.insomnia]),
        DayConfiguration(id: 9, dayNumber: 9, title: "Sleep Hygiene & PSAS Part 1", description: "Habits and pre-sleep arousal", estimatedMinutes: 13, moduleIds: ["expansion_sleep_hygiene_part2", "expansion_psas_part1"], isExpansionDay: true, requiredGateways: [.insomnia]),
        DayConfiguration(id: 10, dayNumber: 10, title: "PSAS Part 2 & ESS", description: "Arousal and daytime sleepiness", estimatedMinutes: 16, moduleIds: ["expansion_psas_part2", "expansion_ess"], isExpansionDay: true, requiredGateways: [.insomnia, .excessiveSleepiness]),
        DayConfiguration(id: 11, dayNumber: 11, title: "FSS & FOSQ-10 Part 1", description: "Fatigue and daily functioning", estimatedMinutes: 14, moduleIds: ["expansion_fss", "expansion_fosq_part1"], isExpansionDay: true, requiredGateways: [.excessiveSleepiness]),
        DayConfiguration(id: 12, dayNumber: 12, title: "FOSQ-10 Part 2 & PHQ-9 & GAD-7", description: "Mental health screening", estimatedMinutes: 14, moduleIds: ["expansion_fosq_part2", "expansion_phq9", "expansion_gad7_part1"], isExpansionDay: true, requiredGateways: [.depression, .anxiety]),
        DayConfiguration(id: 13, dayNumber: 13, title: "GAD-7 Part 2 & DASS-21 & PROMIS", description: "Anxiety and cognitive function", estimatedMinutes: 16, moduleIds: ["expansion_gad7_part2", "expansion_dass21_part1", "expansion_promis_cognitive"], isExpansionDay: true, requiredGateways: [.anxiety, .cognitive]),
        DayConfiguration(id: 14, dayNumber: 14, title: "Final Assessments", description: "Final assessments to complete your profile", estimatedMinutes: 35, moduleIds: ["expansion_dass21_part2", "expansion_stop_bang", "expansion_berlin", "expansion_bpi", "expansion_medas", "expansion_meq"], isExpansionDay: true, requiredGateways: [.osa, .pain, .dietImpact, .sleepTiming])
    ]

    // MARK: - Consensus Sleep Diary Questions (Asked Every Day)
    // Based on the standardized Consensus Sleep Diary (Carney et al., 2012)
    // https://pmc.ncbi.nlm.nih.gov/articles/PMC3250369/

    static let consensusSleepDiaryQuestions: [Question] = [
        // Day Context (asked first to set the stage)
        Question(
            id: "CSD_DAY_TYPE",
            text: "What type of day was yesterday?",
            pillar: .sleepLog,
            questionType: .singleSelect,
            options: ["Work day", "School day", "Day off", "Vacation"],
            helpText: "This helps us understand your sleep patterns",
            group: "sleep_log"
        ),

        // Core CSD Questions - Timing
        Question(
            id: "CSD_INTO_BED",
            text: "What time did you get into bed last night?",
            pillar: .sleepLog,
            questionType: .time,
            helpText: "When you physically got into bed, not when you tried to sleep",
            group: "sleep_log"
        ),
        Question(
            id: "CSD_TRY_SLEEP",
            text: "What time did you try to go to sleep?",
            pillar: .sleepLog,
            questionType: .time,
            helpText: "When you turned off the lights and closed your eyes",
            group: "sleep_log"
        ),
        Question(
            id: "CSD_LATENCY",
            text: "How long did it take you to fall asleep?",
            pillar: .sleepLog,
            questionType: .minutesScroll,
            minValue: 0,
            maxValue: 180,
            unit: "minutes",
            defaultValue: 15,
            helpText: "Your best estimate in minutes",
            group: "sleep_log"
        ),
        Question(
            id: "CSD_AWAKENINGS",
            text: "How many times did you wake up during the night?",
            pillar: .sleepLog,
            questionType: .numberScroll,
            minValue: 0,
            maxValue: 20,
            defaultValue: 0,
            helpText: "Not counting your final awakening",
            group: "sleep_log"
        ),
        Question(
            id: "CSD_WASO",
            text: "In total, how long were you awake during the night?",
            pillar: .sleepLog,
            questionType: .minutesScroll,
            minValue: 0,
            maxValue: 300,
            unit: "minutes",
            defaultValue: 0,
            helpText: "Total time of all awakenings combined",
            group: "sleep_log"
        ),
        Question(
            id: "CSD_FINAL_WAKE",
            text: "What time was your final awakening this morning?",
            pillar: .sleepLog,
            questionType: .time,
            helpText: "The last time you woke up before getting out of bed",
            group: "sleep_log"
        ),
        Question(
            id: "CSD_OUT_BED",
            text: "What time did you get out of bed?",
            pillar: .sleepLog,
            questionType: .time,
            helpText: "When you actually got up for the day",
            group: "sleep_log"
        ),

        // Sleep Quality Rating (1-5 scale per CSD standard)
        Question(
            id: "CSD_QUALITY",
            text: "How would you rate the quality of your sleep last night?",
            pillar: .sleepLog,
            questionType: .scale,
            scaleMin: 1,
            scaleMax: 5,
            scaleMinLabel: "Very poor",
            scaleMaxLabel: "Very good",
            group: "sleep_log"
        ),

        // Refreshed feeling
        Question(
            id: "CSD_REFRESHED",
            text: "How refreshed do you feel this morning?",
            pillar: .sleepLog,
            questionType: .scale,
            scaleMin: 1,
            scaleMax: 5,
            scaleMinLabel: "Not at all",
            scaleMaxLabel: "Very refreshed",
            group: "sleep_log"
        )
    ]

    // MARK: - Optional Context Questions (shown in expandable section)
    // These provide additional context but are not required

    static let sleepContextQuestions: [Question] = [
        // Napping
        Question(
            id: "CSD_NAPS",
            text: "Did you nap or doze yesterday?",
            pillar: .sleepLog,
            questionType: .yesNo,
            group: "sleep_context"
        ),
        Question(
            id: "CSD_NAP_COUNT",
            text: "How many times did you nap?",
            pillar: .sleepLog,
            questionType: .numberScroll,
            minValue: 1,
            maxValue: 5,
            defaultValue: 1,
            conditionalLogic: ConditionalLogic(questionId: "CSD_NAPS", equals: "Yes"),
            group: "sleep_context"
        ),
        Question(
            id: "CSD_NAP_DETAILS",
            text: "For each nap, record the start time and duration.",
            pillar: .sleepLog,
            questionType: .napDetails,
            helpText: "Tap each nap to set the time and how long you slept",
            conditionalLogic: ConditionalLogic(questionId: "CSD_NAPS", equals: "Yes"),
            group: "sleep_context"
        ),

        // Caffeine
        Question(
            id: "CSD_CAFFEINE",
            text: "How many caffeinated drinks did you have yesterday?",
            pillar: .sleepLog,
            questionType: .numberScroll,
            minValue: 0,
            maxValue: 10,
            defaultValue: 0,
            helpText: "Coffee, tea, energy drinks, soda",
            group: "sleep_context"
        ),
        Question(
            id: "CSD_CAFFEINE_LAST",
            text: "What time was your last caffeinated drink?",
            pillar: .sleepLog,
            questionType: .time,
            conditionalLogic: ConditionalLogic(questionId: "CSD_CAFFEINE", greaterThan: 0),
            group: "sleep_context"
        ),

        // Alcohol
        Question(
            id: "CSD_ALCOHOL",
            text: "Did you have any alcohol yesterday?",
            pillar: .sleepLog,
            questionType: .yesNo,
            group: "sleep_context"
        ),
        Question(
            id: "CSD_ALCOHOL_DRINKS",
            text: "How many alcoholic drinks?",
            pillar: .sleepLog,
            questionType: .numberScroll,
            minValue: 1,
            maxValue: 10,
            defaultValue: 1,
            conditionalLogic: ConditionalLogic(questionId: "CSD_ALCOHOL", equals: "Yes"),
            group: "sleep_context"
        ),
        Question(
            id: "CSD_ALCOHOL_LAST",
            text: "What time was your last alcoholic drink?",
            pillar: .sleepLog,
            questionType: .time,
            conditionalLogic: ConditionalLogic(questionId: "CSD_ALCOHOL", equals: "Yes"),
            group: "sleep_context"
        ),

        // Sleep Medications
        Question(
            id: "CSD_MEDS",
            text: "Did you take any sleep medication or aid?",
            pillar: .sleepLog,
            questionType: .yesNo,
            helpText: "Prescription, OTC, or supplements like melatonin",
            group: "sleep_context"
        ),
        Question(
            id: "CSD_MEDS_LIST",
            text: "What did you take?",
            pillar: .sleepLog,
            questionType: .medicationSelect,
            helpText: "Select all that apply",
            conditionalLogic: ConditionalLogic(questionId: "CSD_MEDS", equals: "Yes"),
            group: "sleep_context"
        ),
        Question(
            id: "CSD_MEDS_OTHER",
            text: "Please specify the other medication(s):",
            pillar: .sleepLog,
            questionType: .text,
            helpText: "Enter the name and dose if known",
            conditionalLogic: ConditionalLogic(
                all: [
                    ConditionalLogic(questionId: "CSD_MEDS", equals: "Yes"),
                    ConditionalLogic(questionId: "CSD_MEDS_LIST", contains: "other")
                ]
            ),
            group: "sleep_context"
        ),

        // Comments
        Question(
            id: "CSD_COMMENTS",
            text: "Any other comments about your sleep?",
            pillar: .sleepLog,
            questionType: .text,
            helpText: "Optional - anything else you'd like to note",
            group: "sleep_context"
        )
    ]

    // MARK: - Legacy Stanford Sleep Log (kept for backward compatibility)
    // Maps to CSD questions for data migration

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
                text: "During the past month, how many minutes did it typically take you to fall asleep at night?",
                pillar: .sleepQuality,
                questionType: .minutesScroll,
                minValue: 0,
                maxValue: 180,
                unit: "minutes",
                defaultValue: 15,
                helpText: "This can be derived from your sleep log",
                isGateway: true,
                gatewayType: .insomnia,
                gatewayThreshold: 30
            ),
            Question(id: "PSQI_3", text: "During the past month, when have you usually gotten up in the morning?", pillar: .sleepQuality, questionType: .time, helpText: "Your subjective perception - don't check your wearable"),
            Question(
                id: "PSQI_4",
                text: "During the past month, how many hours of actual sleep did you typically get at night?",
                pillar: .sleepQuality,
                questionType: .numberScroll,
                minValue: 0,
                maxValue: 15,
                step: 0.5,
                unit: "hours",
                defaultValue: 7,
                helpText: "This can be derived from your sleep log"
            )
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
            Question(id: "PSQI_5d", text: "How often have you had trouble sleeping because you cannot breathe comfortably?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]),
            Question(id: "PSQI_5e", text: "How often have you had trouble sleeping because you cough or snore loudly?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]),
            Question(id: "PSQI_5f", text: "How often have you had trouble sleeping because you feel too cold?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]),
            Question(id: "PSQI_5g", text: "How often have you had trouble sleeping because you feel too hot?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]),
            Question(id: "PSQI_5h", text: "How often have you had trouble sleeping because you have bad dreams?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]),
            Question(id: "PSQI_5i", text: "How often have you had trouble sleeping because you have pain?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]),
            Question(id: "PSQI_5j", text: "How often have you had trouble sleeping because of other reason(s)?", pillar: .sleepQuality, questionType: .singleSelect, options: ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]),
            // NOTE: 12A, 12B, 12C are related to night awakenings
            // 12A and 12C are derived from sleep log (CSD_AWAKENINGS and CSD_WASO)
            // 12B is only shown if the user reported awakenings in the sleep log
            Question(
                id: "12A",
                text: "How many times do you typically wake up during the night?",
                pillar: .sleepQuality,
                questionType: .numberScroll,
                minValue: 0,
                maxValue: 15,
                defaultValue: 1,
                helpText: "Auto-derived from your Sleep Log"
            ),
            Question(
                id: "12B",
                text: "When you wake up at night, what is the MAIN reason?",
                pillar: .sleepQuality,
                questionType: .singleSelect,
                options: ["Bathroom needs", "Pain/discomfort", "Noise", "Light", "Hot/cold", "Dreams/nightmares", "Worry/stress", "Other"],
                conditionalLogic: ConditionalLogic(questionId: "CSD_AWAKENINGS", greaterThan: 0)
            ),
            Question(
                id: "12C",
                text: "When you wake up during the night, how long does it typically take you to fall back asleep?",
                pillar: .sleepQuality,
                questionType: .minutesScroll,
                minValue: 0,
                maxValue: 120,
                unit: "minutes",
                defaultValue: 15,
                helpText: "Auto-derived from your Sleep Log",
                conditionalLogic: ConditionalLogic(questionId: "CSD_AWAKENINGS", greaterThan: 0)
            ),

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
            Question(id: "11", text: "How many days per week do you get morning sunlight exposure within an hour of waking?", pillar: .sleepTiming, questionType: .singleSelect, options: ["Never (0 days)", "1-2 days", "3-4 days", "5-6 days", "Daily (7 days)"], helpText: "Morning sunlight helps regulate your circadian rhythm"),
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
            // Note: Q21 removed - redundant with Q17 (Day 3 gateway)
            // Q17 asks the same thing with a 5-point scale, Q21 was just yes/no
            // SB_2 derivation now uses Q17 instead
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
        ],

        // DBAS-16 Part 1 - Dysfunctional Beliefs and Attitudes about Sleep (Day 7)
        "expansion_dbas_part1": [
            Question(id: "DBAS_1", text: "I need 8 hours of sleep to feel refreshed and function well during the day.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_2", text: "When I don't get a proper amount of sleep, I need to catch up the next day by napping or the next night by sleeping longer.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_3", text: "I am concerned that chronic insomnia may have serious consequences on my physical health.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_4", text: "I am worried that I may lose control over my abilities to sleep.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_5", text: "After a poor night's sleep, I know that it will interfere with my daily activities the next day.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_6", text: "In order to be alert and function well during the day, I believe I would be better off taking a sleeping pill rather than having a poor night's sleep.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_7", text: "When I feel irritable, depressed, or anxious during the day, it is mostly because I did not sleep well the night before.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_8", text: "When I sleep poorly on one night, I know it will disturb my sleep schedule for the whole week.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree")
        ],

        // DBAS-16 Part 2 (Day 8)
        "expansion_dbas_part2": [
            Question(id: "DBAS_9", text: "Without an adequate night's sleep, I can hardly function the next day.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_10", text: "I can't ever predict whether I'll have a good or poor night's sleep.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_11", text: "I have little ability to manage the negative consequences of disturbed sleep.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_12", text: "When I feel tired, have no energy, or just seem not to function well during the day, it is generally because I did not sleep well the night before.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_13", text: "I believe insomnia is essentially the result of a chemical imbalance.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_14", text: "I feel insomnia is ruining my ability to enjoy life and prevents me from doing what I want.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_15", text: "Medication is probably the only solution to sleeplessness.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "DBAS_16", text: "I avoid or cancel obligations (social, family) after a poor night's sleep.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree")
        ],

        // Sleep Hygiene Part 1 (Day 8)
        "expansion_sleep_hygiene_part1": [
            Question(id: "SH_1", text: "I keep a regular sleep schedule (same bedtime and wake time daily).", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Always"),
            Question(id: "SH_2", text: "I avoid caffeine within 6 hours of bedtime.", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Always"),
            Question(id: "SH_3", text: "I avoid alcohol within 3 hours of bedtime.", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Always"),
            Question(id: "SH_4", text: "I avoid heavy meals close to bedtime.", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Always"),
            Question(id: "SH_5", text: "My bedroom is quiet, dark, and at a comfortable temperature.", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree")
        ],

        // Sleep Hygiene Part 2 (Day 9)
        "expansion_sleep_hygiene_part2": [
            Question(id: "SH_6", text: "I avoid screens (phone, TV, computer) within 1 hour of bedtime.", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Always"),
            Question(id: "SH_7", text: "I have a relaxing pre-sleep routine.", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Always"),
            Question(id: "SH_8", text: "I use my bed only for sleep and intimacy (not work or watching TV).", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Always"),
            Question(id: "SH_9", text: "I exercise regularly, but not within 3 hours of bedtime.", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Always"),
            Question(id: "SH_10", text: "I get natural sunlight exposure during the day.", pillar: .sleepQuality, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Always")
        ],

        // PSAS Part 1 - Pre-Sleep Arousal Scale (Cognitive) (Day 9)
        "expansion_psas_part1": [
            Question(id: "PSAS_C1", text: "Worry about falling asleep", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_C2", text: "Review or ponder events of the day", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_C3", text: "Depressing or anxious thoughts", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_C4", text: "Worry about problems other than sleep", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_C5", text: "Being mentally alert, active", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_C6", text: "Can't shut off your thoughts", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_C7", text: "Thoughts keep running through your head", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_C8", text: "Being distracted by sounds, etc. in the environment", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely")
        ],

        // PSAS Part 2 - Pre-Sleep Arousal Scale (Somatic) (Day 10)
        "expansion_psas_part2": [
            Question(id: "PSAS_S1", text: "Heart racing, pounding, or beating irregularly", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_S2", text: "A jittery, nervous feeling in your body", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_S3", text: "Shortness of breath or labored breathing", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_S4", text: "A tight, tense feeling in your muscles", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_S5", text: "Cold feeling in your hands, feet, or your body in general", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_S6", text: "Have stomach upset (knot or nervous feeling in stomach, etc.)", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_S7", text: "Perspiration in palms of your hands or other parts of your body", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely"),
            Question(id: "PSAS_S8", text: "Dry feeling in mouth or throat", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Not at all", scaleMaxLabel: "Extremely")
        ],

        // FSS - Fatigue Severity Scale (Day 11)
        "expansion_fss": [
            Question(id: "FSS_1", text: "My motivation is lower when I am fatigued.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 7, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "FSS_2", text: "Exercise brings on my fatigue.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 7, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "FSS_3", text: "I am easily fatigued.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 7, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "FSS_4", text: "Fatigue interferes with my physical functioning.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 7, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "FSS_5", text: "Fatigue causes frequent problems for me.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 7, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "FSS_6", text: "My fatigue prevents sustained physical functioning.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 7, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "FSS_7", text: "Fatigue interferes with carrying out certain duties and responsibilities.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 7, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "FSS_8", text: "Fatigue is among my three most disabling symptoms.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 7, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree"),
            Question(id: "FSS_9", text: "Fatigue interferes with my work, family, or social life.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 7, scaleMinLabel: "Strongly Disagree", scaleMaxLabel: "Strongly Agree")
        ],

        // FOSQ-10 Part 1 - Functional Outcomes of Sleep (Day 11)
        "expansion_fosq_part1": [
            Question(id: "FOSQ_1", text: "Difficulty concentrating on things you do because of sleepiness or fatigue?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty"),
            Question(id: "FOSQ_2", text: "Difficulty remembering things because of sleepiness or fatigue?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty"),
            Question(id: "FOSQ_3", text: "Difficulty finishing a meal because you became sleepy?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty"),
            Question(id: "FOSQ_4", text: "Difficulty working on a hobby because of sleepiness or fatigue?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty"),
            Question(id: "FOSQ_5", text: "Difficulty doing work or accomplishing tasks at home or work?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty")
        ],

        // FOSQ-10 Part 2 (Day 12)
        "expansion_fosq_part2": [
            Question(id: "FOSQ_6", text: "Difficulty operating a motor vehicle for short distances (<1 hour)?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty"),
            Question(id: "FOSQ_7", text: "Difficulty operating a motor vehicle for long distances (>1 hour)?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty"),
            Question(id: "FOSQ_8", text: "Difficulty visiting with family or friends in your home?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty"),
            Question(id: "FOSQ_9", text: "Difficulty watching a movie or video?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty"),
            Question(id: "FOSQ_10", text: "Difficulty taking care of financial affairs or doing paperwork?", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 4, scaleMinLabel: "No difficulty", scaleMaxLabel: "Extreme difficulty")
        ],

        // DASS-21 Part 1 (Day 13) - Depression & Anxiety items
        "expansion_dass21_part1": [
            Question(id: "DASS_1", text: "I found it hard to wind down.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_2", text: "I was aware of dryness of my mouth.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_3", text: "I couldn't seem to experience any positive feeling at all.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_4", text: "I experienced breathing difficulty (e.g. excessively rapid breathing).", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_5", text: "I found it difficult to work up the initiative to do things.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_6", text: "I tended to over-react to situations.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_7", text: "I experienced trembling (e.g. in the hands).", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_8", text: "I felt that I was using a lot of nervous energy.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_9", text: "I was worried about situations in which I might panic.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_10", text: "I felt that I had nothing to look forward to.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_11", text: "I found myself getting agitated.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much")
        ],

        // DASS-21 Part 2 (Day 14)
        "expansion_dass21_part2": [
            Question(id: "DASS_12", text: "I found it difficult to relax.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_13", text: "I felt down-hearted and blue.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_14", text: "I was intolerant of anything that kept me from getting on with what I was doing.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_15", text: "I felt I was close to panic.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_16", text: "I was unable to become enthusiastic about anything.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_17", text: "I felt I wasn't worth much as a person.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_18", text: "I felt that I was rather touchy.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_19", text: "I felt scared without any good reason.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_20", text: "I felt that life was meaningless.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much"),
            Question(id: "DASS_21", text: "I found it hard to calm down after something upset me.", pillar: .mentalHealth, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 3, scaleMinLabel: "Did not apply to me", scaleMaxLabel: "Applied very much")
        ],

        // PROMIS Cognitive Function (Day 13)
        "expansion_promis_cognitive": [
            Question(id: "PROMIS_COG_1", text: "In the past 7 days, my thinking has been slow.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Very Often"),
            Question(id: "PROMIS_COG_2", text: "In the past 7 days, it has seemed like my brain was not working as well as usual.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Very Often"),
            Question(id: "PROMIS_COG_3", text: "In the past 7 days, I have had trouble concentrating.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Very Often"),
            Question(id: "PROMIS_COG_4", text: "In the past 7 days, I have had trouble forming thoughts.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Very Often"),
            Question(id: "PROMIS_COG_5", text: "In the past 7 days, I have had trouble remembering things.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Very Often"),
            Question(id: "PROMIS_COG_6", text: "In the past 7 days, I have had trouble thinking clearly.", pillar: .cognitive, tier: .expansion, questionType: .scale, scaleMin: 1, scaleMax: 5, scaleMinLabel: "Never", scaleMaxLabel: "Very Often")
        ],

        // Berlin Questionnaire (Day 14)
        "expansion_berlin": [
            Question(id: "BERLIN_1", text: "Do you snore?", pillar: .physical, tier: .expansion, questionType: .singleSelect, options: ["Yes", "No", "Don't know"]),
            Question(id: "BERLIN_2", text: "Your snoring is:", pillar: .physical, tier: .expansion, questionType: .singleSelect, options: ["Slightly louder than breathing", "As loud as talking", "Louder than talking", "Very loud - can be heard in adjacent rooms"]),
            Question(id: "BERLIN_3", text: "How often do you snore?", pillar: .physical, tier: .expansion, questionType: .singleSelect, options: ["Nearly every day", "3-4 times a week", "1-2 times a week", "1-2 times a month", "Never or nearly never"]),
            Question(id: "BERLIN_4", text: "Has your snoring ever bothered other people?", pillar: .physical, tier: .expansion, questionType: .yesNo),
            Question(id: "BERLIN_5", text: "Has anyone noticed that you quit breathing during your sleep?", pillar: .physical, tier: .expansion, questionType: .singleSelect, options: ["Nearly every day", "3-4 times a week", "1-2 times a week", "1-2 times a month", "Never or nearly never"]),
            Question(id: "BERLIN_6", text: "How often do you feel tired or fatigued after your sleep?", pillar: .physical, tier: .expansion, questionType: .singleSelect, options: ["Nearly every day", "3-4 times a week", "1-2 times a week", "1-2 times a month", "Never or nearly never"]),
            Question(id: "BERLIN_7", text: "During your waking time, do you feel tired, fatigued, or not up to par?", pillar: .physical, tier: .expansion, questionType: .singleSelect, options: ["Nearly every day", "3-4 times a week", "1-2 times a week", "1-2 times a month", "Never or nearly never"]),
            Question(id: "BERLIN_8", text: "Have you ever nodded off or fallen asleep while driving a vehicle?", pillar: .physical, tier: .expansion, questionType: .yesNo),
            Question(id: "BERLIN_9", text: "How often does this occur (nodding off while driving)?", pillar: .physical, tier: .expansion, questionType: .singleSelect, options: ["Nearly every day", "3-4 times a week", "1-2 times a week", "1-2 times a month", "Never or nearly never"]),
            Question(id: "BERLIN_10", text: "Do you have high blood pressure?", pillar: .physical, tier: .expansion, questionType: .yesNo)
        ],

        // BPI - Brief Pain Inventory (Day 14 - Final)
        "expansion_bpi": [
            Question(id: "BPI_1", text: "Rate your pain at its WORST in the last 24 hours.", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "No pain", scaleMaxLabel: "Pain as bad as you can imagine"),
            Question(id: "BPI_2", text: "Rate your pain at its LEAST in the last 24 hours.", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "No pain", scaleMaxLabel: "Pain as bad as you can imagine"),
            Question(id: "BPI_3", text: "Rate your pain on AVERAGE.", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "No pain", scaleMaxLabel: "Pain as bad as you can imagine"),
            Question(id: "BPI_4", text: "Rate your pain RIGHT NOW.", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "No pain", scaleMaxLabel: "Pain as bad as you can imagine"),
            Question(id: "BPI_5", text: "Pain interference with: General activity", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Does not interfere", scaleMaxLabel: "Completely interferes"),
            Question(id: "BPI_6", text: "Pain interference with: Mood", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Does not interfere", scaleMaxLabel: "Completely interferes"),
            Question(id: "BPI_7", text: "Pain interference with: Walking ability", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Does not interfere", scaleMaxLabel: "Completely interferes"),
            Question(id: "BPI_8", text: "Pain interference with: Normal work (including housework)", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Does not interfere", scaleMaxLabel: "Completely interferes"),
            Question(id: "BPI_9", text: "Pain interference with: Relations with other people", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Does not interfere", scaleMaxLabel: "Completely interferes"),
            Question(id: "BPI_10", text: "Pain interference with: Sleep", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Does not interfere", scaleMaxLabel: "Completely interferes"),
            Question(id: "BPI_11", text: "Pain interference with: Enjoyment of life", pillar: .physical, tier: .expansion, questionType: .scale, scaleMin: 0, scaleMax: 10, scaleMinLabel: "Does not interfere", scaleMaxLabel: "Completely interferes")
        ],

        // MEDAS - Mediterranean Diet Adherence Screener (Day 14 - Final)
        "expansion_medas": [
            Question(id: "MEDAS_1", text: "Do you use olive oil as the main source of fat for cooking?", pillar: .nutritional, tier: .expansion, questionType: .yesNo),
            Question(id: "MEDAS_2", text: "How many tablespoons of olive oil do you consume per day (including frying, salads, meals, etc.)?", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 1", "1-2", "3-4", "4 or more"]),
            Question(id: "MEDAS_3", text: "How many servings of vegetables do you consume per day? (1 serving = 200g)", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 1", "1-2", "3 or more"]),
            Question(id: "MEDAS_4", text: "How many pieces of fruit (including fresh-squeezed juice) do you consume per day?", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 1", "1-2", "3 or more"]),
            Question(id: "MEDAS_5", text: "How many servings of red meat, hamburger, or sausage do you consume per day? (1 serving = 100-150g)", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 1", "1 or more"]),
            Question(id: "MEDAS_6", text: "How many servings of butter, margarine, or cream do you consume per day? (1 serving = 12g)", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 1", "1 or more"]),
            Question(id: "MEDAS_7", text: "How many sweetened/carbonated beverages do you consume per day?", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 1", "1 or more"]),
            Question(id: "MEDAS_8", text: "How many glasses of wine do you drink per week?", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 3", "3-7", "7 or more"]),
            Question(id: "MEDAS_9", text: "How many servings of legumes (beans, lentils, peas) do you consume per week? (1 serving = 150g)", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 3", "3 or more"]),
            Question(id: "MEDAS_10", text: "How many servings of fish/shellfish do you consume per week? (1 serving = 100-150g)", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 3", "3 or more"]),
            Question(id: "MEDAS_11", text: "How many times per week do you consume commercial baked goods or sweets?", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 3", "3 or more"]),
            Question(id: "MEDAS_12", text: "How many servings of nuts (including peanuts) do you consume per week? (1 serving = 30g)", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 3", "3 or more"]),
            Question(id: "MEDAS_13", text: "Do you preferentially consume chicken, turkey, or rabbit instead of beef, pork, or sausages?", pillar: .nutritional, tier: .expansion, questionType: .yesNo),
            Question(id: "MEDAS_14", text: "How many times per week do you consume cooked vegetables, pasta, rice, or other dishes with a sauce of tomato, garlic, onion, or leeks sautéed in olive oil?", pillar: .nutritional, tier: .expansion, questionType: .singleSelect, options: ["Less than 2", "2 or more"])
        ],

        // MEQ - Morningness-Eveningness Questionnaire (Day 14 - Final)
        "expansion_meq": [
            Question(id: "MEQ_1", text: "What time would you get up if you were entirely free to plan your day?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["5:00-6:30 AM", "6:30-7:45 AM", "7:45-9:45 AM", "9:45-11:00 AM", "11:00 AM-12:00 PM"]),
            Question(id: "MEQ_2", text: "What time would you go to bed if you were entirely free to plan your evening?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["8:00-9:00 PM", "9:00-10:15 PM", "10:15 PM-12:30 AM", "12:30-1:45 AM", "1:45-3:00 AM"]),
            Question(id: "MEQ_3", text: "If you usually have to get up at a specific time in the morning, how much do you depend on an alarm clock?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Not at all", "Slightly", "Somewhat", "Very much"]),
            Question(id: "MEQ_4", text: "How easy do you find it to get up in the morning (when you are not awakened unexpectedly)?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Very difficult", "Fairly difficult", "Fairly easy", "Very easy"]),
            Question(id: "MEQ_5", text: "How alert do you feel during the first half hour after waking in the morning?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Not at all alert", "Slightly alert", "Fairly alert", "Very alert"]),
            Question(id: "MEQ_6", text: "How hungry do you feel during the first half hour after waking?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Not at all hungry", "Slightly hungry", "Fairly hungry", "Very hungry"]),
            Question(id: "MEQ_7", text: "During the first half hour after waking, how do you feel?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Very tired", "Fairly tired", "Fairly refreshed", "Very refreshed"]),
            Question(id: "MEQ_8", text: "If you had no commitments the next day, what time would you go to bed compared to your usual bedtime?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Seldom or never later", "Less than 1 hour later", "1-2 hours later", "More than 2 hours later"]),
            Question(id: "MEQ_9", text: "You have decided to do physical exercise. A friend suggests 7:00-8:00 AM. How would you perform?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Would be in good form", "Would be in reasonable form", "Would find it difficult", "Would find it very difficult"]),
            Question(id: "MEQ_10", text: "At approximately what time in the evening do you feel tired and in need of sleep?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["8:00-9:00 PM", "9:00-10:15 PM", "10:15 PM-12:45 AM", "12:45-2:00 AM", "2:00-3:00 AM"]),
            Question(id: "MEQ_11", text: "You want to be at peak performance for a test that you know is going to be mentally exhausting and will last 2 hours. Which time would you choose?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["8:00-10:00 AM", "11:00 AM-1:00 PM", "3:00-5:00 PM", "7:00-9:00 PM"]),
            Question(id: "MEQ_12", text: "If you got into bed at 11:00 PM, how tired would you be?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Not at all tired", "A little tired", "Fairly tired", "Very tired"]),
            Question(id: "MEQ_13", text: "For some reason you have gone to bed several hours later than usual, but there is no need to get up at any particular time the next morning. Which is most likely?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Will wake at usual time and not fall back asleep", "Will wake at usual time and doze", "Will wake at usual time but fall asleep again", "Will not wake until later than usual"]),
            Question(id: "MEQ_14", text: "One night you have to remain awake between 4:00-6:00 AM to carry out a night watch. You have no commitments the next day. Which would you prefer?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Would not go to bed until watch was over", "Would take a nap before and sleep after", "Would take a good sleep before and nap after", "Would take all sleep before watch"]),
            Question(id: "MEQ_15", text: "You have 2 hours of hard physical work. Which time would you choose?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["8:00-10:00 AM", "11:00 AM-1:00 PM", "3:00-5:00 PM", "7:00-9:00 PM"]),
            Question(id: "MEQ_16", text: "You have decided to do physical exercise. A friend suggests 10:00-11:00 PM. How well would you perform?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Would be in good form", "Would be in reasonable form", "Would find it difficult", "Would find it very difficult"]),
            Question(id: "MEQ_17", text: "Suppose you can choose your own work hours. Assume you work a 5-hour day. Which 5 consecutive hours would you select?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["4:00-8:00 AM", "8:00 AM-1:00 PM", "9:00 AM-2:00 PM", "2:00-7:00 PM", "5:00-12:00 PM"]),
            Question(id: "MEQ_18", text: "At approximately what time of day do you usually feel your best?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["5:00-8:00 AM", "8:00-10:00 AM", "10:00 AM-5:00 PM", "5:00-9:00 PM", "9:00 PM-5:00 AM"]),
            Question(id: "MEQ_19", text: "One hears about 'morning types' and 'evening types'. Which do you consider yourself to be?", pillar: .sleepQuality, tier: .expansion, questionType: .singleSelect, options: ["Definitely a morning type", "More a morning than evening type", "More an evening than morning type", "Definitely an evening type"])
        ]
    ]

    // MARK: - Sleep Log Derivation

    /// Question IDs that can be derived from sleep log data
    /// Includes both PSQI questions and general assessment questions
    private static let derivableFromSleepLog: Set<String> = [
        "PSQI_1",  // Usual bedtime (from CSD_TRY_SLEEP)
        "PSQI_2",  // Sleep latency (from CSD_LATENCY)
        "PSQI_4",  // Hours of actual sleep (from CSD times)
        "41",      // "When have you usually gone to bed at night?" (from CSD_TRY_SLEEP) - same as PSQI_1
        "6",       // "How long does it take you to fall asleep?" (from CSD_LATENCY)
        "12A",     // "How many times do you typically wake up during the night?" (from CSD_AWAKENINGS)
        "12C"      // "How long does it typically take you to fall back asleep?" (from CSD_WASO / CSD_AWAKENINGS)
    ]

    /// Check if we have sleep log data to derive PSQI answers
    /// Returns true if the sleep log for today has been completed
    func canDerivePSQIFromSleepLog() -> Bool {
        // Check if we have the key sleep log responses needed for derivation
        let hasLatency = responses["CSD_LATENCY"] != nil
        let hasTrySleep = responses["CSD_TRY_SLEEP"] != nil
        let hasFinalWake = responses["CSD_FINAL_WAKE"] != nil
        let hasWASO = responses["CSD_WASO"] != nil
        let hasAwakenings = responses["CSD_AWAKENINGS"] != nil

        return hasLatency && hasTrySleep && hasFinalWake && hasWASO && hasAwakenings
    }

    /// Derive PSQI_1 / Question 41 (usual bedtime) from sleep log CSD_TRY_SLEEP
    /// Returns the bedtime as a time string (e.g., "22:30")
    func deriveBedtimeFromSleepLog() -> String? {
        // First try CSD_TRY_SLEEP (time tried to go to sleep)
        if let trySleepResponse = responses["CSD_TRY_SLEEP"],
           let timeStr = trySleepResponse.stringValue {
            return timeStr
        }
        // Fallback to CSD_INTO_BED (time got into bed) if available
        if let intoBedResponse = responses["CSD_INTO_BED"],
           let timeStr = intoBedResponse.stringValue {
            return timeStr
        }
        return nil
    }

    /// Derive PSQI_2 (sleep latency) from sleep log CSD_LATENCY
    func derivePSQI2FromSleepLog() -> Double? {
        guard let latencyResponse = responses["CSD_LATENCY"],
              let latencyMinutes = latencyResponse.numberValue else {
            return nil
        }
        return latencyMinutes
    }

    /// Derive PSQI_4 (hours of actual sleep) from sleep log times
    func derivePSQI4FromSleepLog() -> Double? {
        guard let trySleepResponse = responses["CSD_TRY_SLEEP"],
              let finalWakeResponse = responses["CSD_FINAL_WAKE"],
              let wasoResponse = responses["CSD_WASO"],
              let trySleepStr = trySleepResponse.stringValue,
              let finalWakeStr = finalWakeResponse.stringValue,
              let wasoMinutes = wasoResponse.numberValue else {
            return nil
        }

        // Parse times
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let trySleepTime = formatter.date(from: trySleepStr),
              let finalWakeTime = formatter.date(from: finalWakeStr) else {
            return nil
        }

        // Calculate time in bed
        var timeInBedMinutes = Calendar.current.dateComponents([.minute], from: trySleepTime, to: finalWakeTime).minute ?? 0

        // Handle crossing midnight
        if timeInBedMinutes < 0 {
            timeInBedMinutes += 24 * 60
        }

        // Subtract WASO to get actual sleep time
        let actualSleepMinutes = Double(timeInBedMinutes) - wasoMinutes
        let actualSleepHours = actualSleepMinutes / 60.0

        // Round to nearest 0.5 hour
        return (actualSleepHours * 2).rounded() / 2
    }

    /// Derive 12A (number of awakenings) from sleep log CSD_AWAKENINGS
    func derive12AFromSleepLog() -> Double? {
        guard let awakeningsResponse = responses["CSD_AWAKENINGS"],
              let awakenings = awakeningsResponse.numberValue else {
            return nil
        }
        return awakenings
    }

    /// Derive 12C (time to fall back asleep) from sleep log CSD_WASO / CSD_AWAKENINGS
    /// Returns average time per awakening in minutes
    func derive12CFromSleepLog() -> Double? {
        guard let wasoResponse = responses["CSD_WASO"],
              let awakeningsResponse = responses["CSD_AWAKENINGS"],
              let wasoMinutes = wasoResponse.numberValue,
              let awakenings = awakeningsResponse.numberValue,
              awakenings > 0 else {
            return nil
        }
        // Average time to fall back asleep = total wake time / number of awakenings
        return wasoMinutes / awakenings
    }

    /// Generate derived responses from sleep log data
    /// Call this after sleep log is completed to auto-fill derivable questions
    func generateDerivedPSQIResponses(forDay dayNumber: Int) {
        guard canDerivePSQIFromSleepLog() else { return }

        // Derive bedtime questions (PSQI_1 and question 41)
        if let bedtimeStr = deriveBedtimeFromSleepLog() {
            // PSQI_1 ("When have you usually gone to bed at night?")
            let psqi1Response = QuestionResponse(
                questionId: "PSQI_1",
                dayNumber: dayNumber,
                stringValue: bedtimeStr,
                isDerived: true
            )
            responses["PSQI_1"] = psqi1Response
            saveResponse(psqi1Response)

            // Question 41 ("When have you usually gone to bed at night?") - same question
            let q41Response = QuestionResponse(
                questionId: "41",
                dayNumber: dayNumber,
                stringValue: bedtimeStr,
                isDerived: true
            )
            responses["41"] = q41Response
            saveResponse(q41Response)
        }

        // Derive sleep latency questions (PSQI_2 and question 6)
        if let latencyMinutes = derivePSQI2FromSleepLog() {
            // PSQI_2 (sleep latency in minutes)
            let psqi2Response = QuestionResponse(
                questionId: "PSQI_2",
                dayNumber: dayNumber,
                numberValue: latencyMinutes,
                isDerived: true
            )
            responses["PSQI_2"] = psqi2Response
            saveResponse(psqi2Response)

            // Question 6 ("How long does it take you to fall asleep?") - same source
            let q6Response = QuestionResponse(
                questionId: "6",
                dayNumber: dayNumber,
                numberValue: latencyMinutes,
                isDerived: true
            )
            responses["6"] = q6Response
            saveResponse(q6Response)
        }

        // Derive PSQI_4 (hours of actual sleep)
        if let sleepHours = derivePSQI4FromSleepLog() {
            let response = QuestionResponse(
                questionId: "PSQI_4",
                dayNumber: dayNumber,
                numberValue: sleepHours,
                isDerived: true
            )
            responses["PSQI_4"] = response
            saveResponse(response)
        }

        // Derive 12A (number of awakenings) from sleep log
        if let awakenings = derive12AFromSleepLog() {
            let response = QuestionResponse(
                questionId: "12A",
                dayNumber: dayNumber,
                numberValue: awakenings,
                isDerived: true
            )
            responses["12A"] = response
            saveResponse(response)
        }

        // Derive 12C (time to fall back asleep) from sleep log
        if let avgFallBackAsleepMinutes = derive12CFromSleepLog() {
            let response = QuestionResponse(
                questionId: "12C",
                dayNumber: dayNumber,
                numberValue: avgFallBackAsleepMinutes,
                isDerived: true
            )
            responses["12C"] = response
            saveResponse(response)
        }
    }

    /// Check if a question should be skipped because it can be derived from sleep log
    func shouldSkipDerivableQuestion(_ questionId: String) -> Bool {
        guard Self.derivableFromSleepLog.contains(questionId) else { return false }
        return canDerivePSQIFromSleepLog()
    }

    // MARK: - Get Questions for a Day

    func getQuestionsForDay(_ dayNumber: Int) -> [Question] {
        var questions: [Question] = []

        // 1. Always start with Consensus Sleep Diary (enhanced from Stanford Sleep Log)
        questions.append(contentsOf: Self.consensusSleepDiaryQuestions)

        // 2. Add core questions for days 1-5
        if dayNumber <= 5, let coreQuestions = Self.coreQuestionsByDay[dayNumber] {
            // For Day 1, filter out demographic questions already answered during onboarding
            // AND filter out PSQI questions that can be derived from sleep log
            if dayNumber == 1 {
                let filteredQuestions = coreQuestions.filter { question in
                    !shouldSkipDemographicQuestion(question.id) && !shouldSkipDerivableQuestion(question.id)
                }
                questions.append(contentsOf: filteredQuestions)

                // Pre-fill responses from onboarding so data is available for analysis
                prefillFromOnboardingProfile()

                // Generate derived PSQI responses from sleep log
                generateDerivedPSQIResponses(forDay: dayNumber)
            } else {
                // For other days, also filter derivable questions
                let filteredQuestions = coreQuestions.filter { question in
                    !shouldSkipDerivableQuestion(question.id)
                }
                questions.append(contentsOf: filteredQuestions)
            }
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
            return evaluateConditionalLogic(logic)
        }
    }

    /// Recursively evaluate conditional logic (supports compound AND/OR conditions and age checks)
    private func evaluateConditionalLogic(_ logic: ConditionalLogic) -> Bool {
        // Handle compound AND conditions
        if let allConditions = logic.all {
            return allConditions.allSatisfy { evaluateConditionalLogic($0) }
        }

        // Handle compound OR conditions
        if let anyConditions = logic.any {
            return anyConditions.contains { evaluateConditionalLogic($0) }
        }

        // Handle age-based conditions (calculated from D2 birth date)
        if let ageUnder = logic.ageUnder {
            guard let age = calculateUserAge() else { return false }
            return age < ageUnder
        }
        if let ageOver = logic.ageOver {
            guard let age = calculateUserAge() else { return false }
            return age > ageOver
        }

        // Handle single question condition
        guard let questionId = logic.questionId else { return true }
        guard let response = responses[questionId] else { return false }

        // Evaluate the condition
        if let equals = logic.equals {
            return response.stringValue?.lowercased() == equals.lowercased()
        }
        if let greaterThan = logic.greaterThan, let num = response.numberValue {
            return num > greaterThan
        }
        if let lessThan = logic.lessThan, let num = response.numberValue {
            return num < lessThan
        }
        if let greaterThanOrEqual = logic.greaterThanOrEqual, let num = response.numberValue {
            return num >= greaterThanOrEqual
        }
        if let lessThanOrEqual = logic.lessThanOrEqual, let num = response.numberValue {
            return num <= lessThanOrEqual
        }

        return true
    }

    /// Calculate user's age from D2 (Date of Birth) response
    private func calculateUserAge() -> Int? {
        guard let dobResponse = responses["D2"] else { return nil }

        // D2 is stored as a date string (YYYY-MM-DD format)
        guard let dobString = dobResponse.stringValue else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        guard let birthDate = dateFormatter.date(from: dobString) else { return nil }

        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
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
            // Handles both text labels and numeric string values from Convex
            if let response = responses["15"] {
                // Try numeric value first (from Convex: "0", "1", "2", "3")
                if let numericIndex = Int(response.stringValue ?? ""), numericIndex >= 2 { return true }
                // Fall back to text label matching
                if let index = getOptionIndex(response.stringValue, for: "15"), index >= 2 { return true }
            }
            return false

        case .anxiety:
            // Triggered if question 16 >= "More than half the days" (index 2)
            // Handles both text labels and numeric string values from Convex
            if let response = responses["16"] {
                // Try numeric value first (from Convex: "0", "1", "2", "3")
                if let numericIndex = Int(response.stringValue ?? ""), numericIndex >= 2 { return true }
                // Fall back to text label matching
                if let index = getOptionIndex(response.stringValue, for: "16"), index >= 2 { return true }
            }
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

    // MARK: - Same-Day Expansion Pack System
    // When gateways are triggered during the core assessment (Days 1-5),
    // we can offer additional "expansion" questions on the same day.
    // This provides immediate, personalized deep-dives.

    /// Maximum number of expansion questions to show in a single day (to avoid overwhelming the user)
    static let maxExpansionQuestionsPerDay = 15

    /// Maps gateway types to their primary expansion module
    /// These are the "quick" expansion modules suitable for same-day delivery
    /// Note: Only includes modules that exist in expansionQuestionsByModule
    static let sameDayExpansionModules: [GatewayType: String] = [
        .insomnia: "expansion_isi",           // 7 questions - Insomnia Severity Index
        .poorSleepQuality: "expansion_isi",   // Same as insomnia
        .excessiveSleepiness: "expansion_ess", // 8 questions - Epworth Sleepiness Scale
        .depression: "expansion_phq9",        // 9 questions - PHQ-9
        .anxiety: "expansion_gad7_part1",     // 4 questions - GAD-7 Part 1
        .osa: "expansion_stop_bang"           // 8 questions - STOP-BANG
        // Note: cognitive, pain, dietImpact, sleepTiming don't have quick same-day modules yet
    ]

    /// Get expansion pack info for newly triggered gateways on the current day
    /// - Days 1-5: Returns same-day expansion for triggered gateways (existing logic)
    /// - Days 6+: Returns scheduled expansion from Convex dynamic scheduler
    func getExpansionPackForDay(_ dayNumber: Int) -> ExpansionPackInfo? {
        // For Days 6+, use the dynamic expansion schedule from Convex
        if dayNumber >= 6 {
            return getScheduledExpansionPack()
        }

        // Days 1-5: Same-day expansion logic
        // Get completed expansion gateways
        let completedExpansions = journeyProgress?.completedExpansionGateways ?? []

        // Get triggered gateways that have same-day expansion modules AND haven't been completed yet
        let triggeredWithExpansion = gatewayStates.filter { state in
            state.triggered &&
            Self.sameDayExpansionModules.keys.contains(state.gatewayType) &&
            !completedExpansions.contains(state.gatewayType)
        }

        guard !triggeredWithExpansion.isEmpty else { return nil }

        // Collect expansion questions from triggered gateways
        var expansionQuestions: [Question] = []
        var includedGateways: [GatewayType] = []

        for state in triggeredWithExpansion {
            guard let moduleId = Self.sameDayExpansionModules[state.gatewayType],
                  let moduleQuestions = Self.expansionQuestionsByModule[moduleId] else { continue }

            // Filter out questions that are redundant (already answered or derivable from profile)
            let filteredQuestions = filterRedundantExpansionQuestions(moduleQuestions)

            // Check if adding this module would exceed the limit
            if expansionQuestions.count + filteredQuestions.count <= Self.maxExpansionQuestionsPerDay {
                // Avoid duplicates (e.g., insomnia and poorSleepQuality share the same module)
                let newQuestionIds = Set(filteredQuestions.map { $0.id })
                let existingQuestionIds = Set(expansionQuestions.map { $0.id })
                if newQuestionIds.isDisjoint(with: existingQuestionIds) {
                    expansionQuestions.append(contentsOf: filteredQuestions)
                    includedGateways.append(state.gatewayType)
                }
            }
        }

        // Return nil if no questions to show
        guard !expansionQuestions.isEmpty else { return nil }

        // Calculate estimated time (roughly 1 minute per question)
        let estimatedMinutes = max(expansionQuestions.count, 3) // Minimum 3 minutes

        return ExpansionPackInfo(
            triggeredGateways: includedGateways,
            questions: expansionQuestions,
            totalEstimatedMinutes: estimatedMinutes
        )
    }

    /// Get expansion pack from the Convex-scheduled expansion (for Days 6+)
    /// Returns nil if no expansion is scheduled or it's already completed
    private func getScheduledExpansionPack() -> ExpansionPackInfo? {
        guard let scheduled = scheduledExpansionForToday,
              !scheduled.completed else {
            return nil
        }

        // Convert Convex module IDs to iOS questions
        var expansionQuestions: [Question] = []

        for module in scheduled.modules {
            // Get iOS module IDs for this Convex module
            let iOSModuleIds = Self.convexToIOSModuleMapping[module.id] ?? [module.id]

            for iOSModuleId in iOSModuleIds {
                if let moduleQuestions = Self.expansionQuestionsByModule[iOSModuleId] {
                    expansionQuestions.append(contentsOf: moduleQuestions)
                }
            }
        }

        guard !expansionQuestions.isEmpty else { return nil }

        // For scheduled expansions, we don't have gateway associations,
        // so we use an empty array (the shortExplanation will handle this gracefully)
        return ExpansionPackInfo(
            triggeredGateways: [],
            questions: expansionQuestions,
            totalEstimatedMinutes: scheduled.estimatedMinutes
        )
    }

    // MARK: - Cross-Module Redundancy Mapping & Answer Derivation

    /// Maps question IDs to semantic concepts for cross-module deduplication
    /// When the first question of a concept is answered, subsequent questions are skipped
    /// Key: question ID, Value: semantic concept name
    private static let questionSemanticConcepts: [String: String] = [
        // Snoring questions (OSA screening)
        "SB_1": "snoring_presence",
        "BERLIN_1": "snoring_presence",
        "19": "snoring_presence",  // Core gateway question
        // Keep BERLIN_2 (loudness) and BERLIN_3 (frequency) - they add detail

        // Observed apnea
        "SB_3": "observed_apnea",
        "BERLIN_5": "observed_apnea",
        "20": "observed_apnea",  // Core gateway question

        // Blood pressure
        "SB_4": "high_blood_pressure",
        "BERLIN_10": "high_blood_pressure",

        // Daytime fatigue/tiredness (general)
        "SB_2": "daytime_fatigue_general",
        "BERLIN_6": "daytime_fatigue_general",
        "BERLIN_7": "daytime_fatigue_general",
        "17": "daytime_fatigue_general",  // Core gateway question
        // Note: PHQ9_4 and FSS items are clinically distinct - PHQ9 measures depression symptom,
        // FSS measures functional impact. Keep them separate for scoring validity.

        // Concentration difficulty
        "PHQ9_7": "concentration_difficulty",
        "FOSQ_1": "concentration_difficulty",
        "PROMIS_COG_3": "concentration_difficulty",

        // Memory problems
        "FOSQ_2": "memory_problems",
        "PROMIS_COG_5": "memory_problems",

        // Depression gateway
        "15": "depression_feeling",
        "PHQ9_2": "depression_feeling",

        // Anxiety gateway
        "16": "anxiety_feeling",
        "GAD7_1": "anxiety_feeling"
    ]

    /// Defines how to derive answers for skipped questions from equivalent source questions
    /// Key: target question ID (to be derived), Value: (source question ID, conversion function name)
    private static let answerDerivationRules: [String: (sourceId: String, conversionType: AnswerConversionType)] = [
        // STOP-BANG derivations from core gateway questions
        "SB_1": ("19", .snoringToYesNo),       // Q19 "Do you snore?" -> SB_1 yes/no
        "SB_2": ("17", .tirednessToYesNo),     // Q17 tiredness scale -> SB_2 yes/no
        "SB_3": ("20", .observedApneaToYesNo), // Q20 "observed apnea" -> SB_3 yes/no

        // Berlin derivations from STOP-BANG or core questions
        "BERLIN_1": ("SB_1", .yesNoPassthrough),   // Same yes/no format
        "BERLIN_5": ("SB_3", .yesNoToFrequency),   // yes/no -> frequency scale
        "BERLIN_10": ("SB_4", .yesNoPassthrough),  // Same yes/no format
        "BERLIN_6": ("17", .tirednessToFrequency), // tiredness scale -> frequency
        "BERLIN_7": ("17", .tirednessToFrequency), // tiredness scale -> frequency

        // PHQ-9 derivations from core gateway
        "PHQ9_2": ("15", .depressionToFrequency),  // Q15 depression scale -> PHQ9 frequency

        // GAD-7 derivations from core gateway
        "GAD7_1": ("16", .anxietyToFrequency),     // Q16 anxiety scale -> GAD7 frequency

        // FOSQ derivations from PHQ-9 (when PHQ-9 answered first)
        "FOSQ_1": ("PHQ9_7", .frequencyToDifficulty), // concentration frequency -> difficulty
        "FOSQ_2": ("PROMIS_COG_5", .frequencyToDifficulty), // memory frequency -> difficulty

        // PROMIS derivations from PHQ-9 (when PHQ-9 answered first)
        "PROMIS_COG_3": ("PHQ9_7", .frequencyPassthrough), // Same frequency scale
        "PROMIS_COG_5": ("FOSQ_2", .difficultyToFrequency)  // difficulty -> frequency
    ]

    /// Types of answer conversions between equivalent questions
    enum AnswerConversionType {
        case yesNoPassthrough           // Direct yes/no copy
        case snoringToYesNo            // "Yes/Sometimes/Never" -> "Yes/No"
        case tirednessToYesNo          // 5-point tiredness scale -> yes/no
        case tirednessToFrequency      // 5-point tiredness -> frequency scale
        case observedApneaToYesNo      // "Yes/No/Not sure" -> "Yes/No"
        case yesNoToFrequency          // yes/no -> frequency scale
        case depressionToFrequency     // 5-point depression -> PHQ9 frequency
        case anxietyToFrequency        // 5-point anxiety -> GAD7 frequency
        case frequencyToDifficulty     // PHQ/GAD frequency -> FOSQ difficulty
        case difficultyToFrequency     // FOSQ difficulty -> PROMIS frequency
        case frequencyPassthrough      // Same frequency scale
    }

    /// Track which semantic concepts have been answered in this session
    /// Reset when day changes or questionnaire is completed
    @Published var answeredSemanticConcepts: Set<String> = []

    /// Clear answered concepts when starting a new questionnaire session
    func resetAnsweredConcepts() {
        answeredSemanticConcepts.removeAll()
    }

    /// Mark a question's semantic concept as answered and derive answers for equivalent questions
    func markQuestionAnswered(_ questionId: String) {
        if let concept = Self.questionSemanticConcepts[questionId] {
            answeredSemanticConcepts.insert(concept)

            // Derive answers for equivalent questions that might be skipped
            deriveAnswersForEquivalentQuestions(sourceQuestionId: questionId)
        }
    }

    /// Check if a question should be skipped due to cross-module redundancy
    func shouldSkipForRedundancy(_ questionId: String) -> Bool {
        guard let concept = Self.questionSemanticConcepts[questionId] else {
            return false // Not in the redundancy map, show the question
        }
        return answeredSemanticConcepts.contains(concept)
    }

    /// Derive and save answers for questions that are equivalent to the source question
    /// This ensures clinical scoring instruments have complete data even when questions are skipped
    private func deriveAnswersForEquivalentQuestions(sourceQuestionId: String) {
        guard let sourceResponse = responses[sourceQuestionId] else { return }

        // Find all questions that can be derived from this source
        for (targetId, rule) in Self.answerDerivationRules {
            // Check if this target derives from our source
            guard rule.sourceId == sourceQuestionId else { continue }

            // Don't overwrite if already answered
            guard responses[targetId] == nil else { continue }

            // Convert the answer
            if let derivedResponse = convertAnswer(
                from: sourceResponse,
                toQuestionId: targetId,
                conversionType: rule.conversionType
            ) {
                responses[targetId] = derivedResponse
                print("[QuestionnaireManager] Derived \(targetId) from \(sourceQuestionId) for complete scoring")
            }
        }
    }

    /// Convert an answer from one question format to another
    private func convertAnswer(from source: QuestionResponse, toQuestionId: String, conversionType: AnswerConversionType) -> QuestionResponse? {
        var derived = QuestionResponse(questionId: toQuestionId, dayNumber: source.dayNumber)
        derived.answeredAt = source.answeredAt
        derived.isDerived = true  // Mark as derived, not directly answered

        switch conversionType {
        case .yesNoPassthrough:
            derived.stringValue = source.stringValue
            return derived

        case .snoringToYesNo:
            // "Yes" / "Sometimes" / "Rarely" / "Never" -> "Yes" / "No"
            if let value = source.stringValue?.lowercased() {
                derived.stringValue = (value == "yes" || value == "sometimes" || value == "rarely") ? "Yes" : "No"
                return derived
            }

        case .tirednessToYesNo:
            // 5-point scale (1-5) -> Yes (>=3) / No (<3)
            if let value = source.numberValue {
                derived.stringValue = value >= 3 ? "Yes" : "No"
                return derived
            }

        case .tirednessToFrequency:
            // 5-point tiredness -> 4-point frequency (never/sometimes/often/always)
            if let value = source.numberValue {
                let frequencies = ["Not during the past month", "Less than once a week", "Once or twice a week", "Three or more times a week"]
                let index = min(Int((value - 1) / 1.25), 3)
                derived.stringValue = frequencies[index]
                return derived
            }

        case .observedApneaToYesNo:
            // "Yes" / "No" / "Not sure" -> "Yes" / "No"
            if let value = source.stringValue?.lowercased() {
                derived.stringValue = (value == "yes") ? "Yes" : "No"
                return derived
            }

        case .yesNoToFrequency:
            // yes/no -> frequency (never vs 3+ times/week)
            if let value = source.stringValue?.lowercased() {
                derived.stringValue = (value == "yes") ? "Three or more times a week" : "Not during the past month"
                return derived
            }

        case .depressionToFrequency:
            // 5-point depression scale -> PHQ9 4-point (0-3)
            if let value = source.numberValue {
                let phq9Options = ["Not at all", "Several days", "More than half the days", "Nearly every day"]
                let index = min(Int((value - 1) / 1.25), 3)
                derived.stringValue = phq9Options[index]
                return derived
            }

        case .anxietyToFrequency:
            // 5-point anxiety scale -> GAD7 4-point (0-3)
            if let value = source.numberValue {
                let gad7Options = ["Not at all", "Several days", "More than half the days", "Nearly every day"]
                let index = min(Int((value - 1) / 1.25), 3)
                derived.stringValue = gad7Options[index]
                return derived
            }

        case .frequencyToDifficulty:
            // PHQ/GAD frequency -> FOSQ difficulty (1-4)
            if let value = source.stringValue?.lowercased() {
                let difficultyMap: [String: Double] = [
                    "not at all": 1.0,
                    "several days": 2.0,
                    "more than half the days": 3.0,
                    "nearly every day": 4.0
                ]
                derived.numberValue = difficultyMap[value] ?? 1.0
                return derived
            }

        case .difficultyToFrequency:
            // FOSQ difficulty (1-4) -> PROMIS frequency
            if let value = source.numberValue {
                let promisOptions = ["Never", "Rarely", "Sometimes", "Often", "Very often"]
                let index = min(Int(value) - 1, 4)
                derived.stringValue = promisOptions[max(0, index)]
                return derived
            }

        case .frequencyPassthrough:
            derived.stringValue = source.stringValue
            derived.numberValue = source.numberValue
            return derived
        }

        return nil
    }

    /// Get all derived responses that should be saved to Convex for complete clinical scoring
    /// Call this when saving expansion pack responses
    func getDerivedResponsesForScoring() -> [QuestionResponse] {
        return responses.values.filter { $0.isDerived == true }
    }

    /// Filter out expansion questions that are redundant (already answered in core assessment, derivable from profile,
    /// or semantically equivalent to questions already answered in other expansion modules)
    private func filterRedundantExpansionQuestions(_ questions: [Question]) -> [Question] {
        return questions.filter { question in
            // First check cross-module redundancy (questions answered in other expansion packs)
            if shouldSkipForRedundancy(question.id) {
                print("[QuestionnaireManager] Skipping \(question.id) - semantic equivalent already answered")
                return false
            }

            switch question.id {

            // ===== STOP-BANG Redundancies (core assessment & profile) =====
            case "SB_1":
                // "Do you snore loudly?" - already asked as Question 19 (gateway trigger)
                return false
            case "SB_2":
                // "Do you feel tired during daytime?" - derived from Question 17 (gateway)
                return false
            case "SB_3":
                // "Has anyone observed you stop breathing?" - already asked as Question 20 (gateway trigger)
                return false
            case "SB_5":
                // "BMI > 35?" - we have height/weight from onboarding
                return false
            case "SB_6":
                // "Age > 50?" - we have birth year from onboarding
                return false
            case "SB_8":
                // "Gender = Male?" - we have sex from onboarding
                return false

            // ===== PHQ-9 Redundancies =====
            case "PHQ9_2":
                // "Feeling down, depressed, or hopeless?" - already asked as Question 15 (gateway trigger)
                return false

            // ===== GAD-7 Redundancies =====
            case "GAD7_1":
                // "Feeling nervous, anxious, or on edge?" - already asked as Question 16 (gateway trigger)
                return false

            // ===== Berlin Questionnaire (when STOP-BANG also triggered) =====
            // Note: If OSA gateway triggered both, prefer STOP-BANG's validated binary format
            // Skip Berlin duplicates that overlap with STOP-BANG
            case "BERLIN_1":
                // "Do you snore?" - covered by SB_1 (already filtered above as gateway question)
                return responses["19"] != nil // Skip if snoring question was answered
            case "BERLIN_5":
                // "Has anyone noticed you quit breathing?" - covered by SB_3
                return responses["20"] != nil // Skip if observed apnea question was answered
            case "BERLIN_10":
                // "Do you have high blood pressure?" - same as SB_4
                // Only skip if SB_4 would be asked (OSA gateway day)
                return responses["SB_4"] != nil

            default:
                return true
            }
        }
    }

    /// Mark expansion gateways as completed (call after expansion questionnaire is done)
    func markExpansionCompleted(gateways: [GatewayType]) {
        guard var progress = journeyProgress else { return }

        for gateway in gateways {
            if !progress.completedExpansionGateways.contains(gateway) {
                progress.completedExpansionGateways.append(gateway)
            }
        }
        progress.expansionPackCompleted = true
        journeyProgress = progress

        print("[QuestionnaireManager] Marked expansion completed for: \(gateways.map { $0.rawValue })")
    }

    /// Check if there are triggered gateways that haven't had their expansion questions shown yet
    /// This helps the dashboard decide whether to show the expansion pack section
    func hasAvailableExpansionPack(for dayNumber: Int) -> Bool {
        return getExpansionPackForDay(dayNumber) != nil
    }

    /// Get the list of gateways that were triggered today and have expansion available
    func getTriggeredGatewaysWithExpansion() -> [GatewayType] {
        return gatewayStates.filter { state in
            state.triggered && Self.sameDayExpansionModules.keys.contains(state.gatewayType)
        }.map { $0.gatewayType }
    }

    // MARK: - Response Management

    func saveResponse(_ response: QuestionResponse) {
        responses[response.questionId] = response

        // Track semantic concept for cross-module redundancy filtering
        markQuestionAnswered(response.questionId)

        evaluateGateways()
    }

    func getResponse(for questionId: String) -> QuestionResponse? {
        return responses[questionId]
    }

    /// Look up the question text for a given question ID
    /// Used by Sleep Diary to display human-readable questions
    func getQuestionText(for questionId: String) -> String? {
        // Search in all question sources

        // Core questions by day
        for (_, questions) in Self.coreQuestionsByDay {
            if let question = questions.first(where: { $0.id == questionId }) {
                return question.text
            }
        }

        // Expansion questions by module
        for (_, questions) in Self.expansionQuestionsByModule {
            if let question = questions.first(where: { $0.id == questionId }) {
                return question.text
            }
        }

        // Consensus Sleep Diary questions
        if let question = Self.consensusSleepDiaryQuestions.first(where: { $0.id == questionId }) {
            return question.text
        }

        // Sleep context questions
        if let question = Self.sleepContextQuestions.first(where: { $0.id == questionId }) {
            return question.text
        }

        return nil
    }

    /// Get the category/pillar for a question ID
    /// Used by Sleep Diary to group questions by topic
    func getQuestionCategory(for questionId: String) -> String? {
        // Derive category from question ID prefix or pillar

        // Check for known prefixes
        let prefix = String(questionId.prefix(while: { $0.isLetter || $0 == "_" }))

        switch prefix {
        case "D", "D_":
            return "Demographics"
        case "ISI", "ISI_":
            return "Insomnia"
        case "PHQ", "PHQ9", "PHQ9_":
            return "Mental Health"
        case "GAD", "GAD7", "GAD7_":
            return "Anxiety"
        case "ESS", "ESS_":
            return "Sleepiness"
        case "PSQI", "PSQI_":
            return "Sleep Quality"
        case "DBAS", "DBAS_":
            return "Sleep Beliefs"
        case "STOP", "SB", "SB_":
            return "Sleep Apnea Screening"
        case "FSS", "FSS_":
            return "Fatigue"
        case "BPI", "BPI_":
            return "Pain"
        case "FOSQ", "FOSQ_":
            return "Functional Outcomes"
        case "DASS", "DASS_":
            return "Stress & Anxiety"
        case "PROMIS", "PROMIS_":
            return "Cognitive Function"
        case "MEQ", "MEQ_":
            return "Chronotype"
        case "MEDAS", "MEDAS_":
            return "Diet"
        case "BERLIN", "BERLIN_":
            return "Sleep Apnea"
        case "Q":
            // Core assessment questions - look up pillar
            return lookupQuestionPillar(questionId)
        default:
            // Try to look up from question data
            return lookupQuestionPillar(questionId)
        }
    }

    /// Helper to look up a question's pillar from the question data
    private func lookupQuestionPillar(_ questionId: String) -> String? {
        // Search all question sources for pillar
        for (_, questions) in Self.coreQuestionsByDay {
            if let question = questions.first(where: { $0.id == questionId }) {
                return pillarDisplayName(question.pillar)
            }
        }

        for (_, questions) in Self.expansionQuestionsByModule {
            if let question = questions.first(where: { $0.id == questionId }) {
                return pillarDisplayName(question.pillar)
            }
        }

        return "Assessment"
    }

    /// Convert pillar enum to display name
    private func pillarDisplayName(_ pillar: Pillar) -> String {
        switch pillar {
        case .sleepQuality:
            return "Sleep Quality"
        case .sleepQuantity:
            return "Sleep Quantity"
        case .sleepRegularity:
            return "Sleep Regularity"
        case .sleepTiming:
            return "Circadian Rhythm"
        case .mentalHealth:
            return "Mental Health"
        case .physical:
            return "Physical Health"
        case .cognitive:
            return "Cognitive Function"
        case .metabolic:
            return "Metabolic Health"
        case .social:
            return "Social & Lifestyle"
        case .nutritional:
            return "Nutrition"
        case .sleepDiary:
            return "Sleep Diary"
        case .sleepLog:
            return "Sleep Log"
        }
    }

    /// Get the question type for a given question ID
    /// Used by QuestionnaireView to properly format date vs time values
    func getQuestionType(for questionId: String) -> QuestionType? {
        // Search in all question sources

        // Core questions by day
        for (_, questions) in Self.coreQuestionsByDay {
            if let question = questions.first(where: { $0.id == questionId }) {
                return question.questionType
            }
        }

        // Sleep log questions
        if let question = Self.stanfordSleepLogQuestions.first(where: { $0.id == questionId }) {
            return question.questionType
        }

        // Expansion questions by module
        for (_, questions) in Self.expansionQuestionsByModule {
            if let question = questions.first(where: { $0.id == questionId }) {
                return question.questionType
            }
        }

        return nil
    }

    // MARK: - Duplicate Question Prevention (Issues 7-11)

    /// Check if a demographic question should be skipped because it was already answered during onboarding or available from HealthKit
    /// This prevents asking name, DOB, gender, height, weight again in Day 1 assessment
    func shouldSkipDemographicQuestion(_ questionId: String) -> Bool {
        let profile = OnboardingManager.shared.profile

        switch questionId {
        case "D1": // Full name
            return !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "D2": // Date of birth
            // Skip if birth year provided during onboarding OR available from HealthKit
            let hasOnboardingDOB = profile.birthYear != 1990
            let hasHealthKitDOB = healthKitDateOfBirth != nil
            return hasOnboardingDOB || hasHealthKitDOB
        case "D4": // Sex assigned at birth
            // Skip if provided during onboarding OR available from HealthKit
            let hasOnboardingGender = profile.gender != Gender.preferNotToSay.rawValue
            let hasHealthKitGender = healthKitBiologicalSex != nil
            return hasOnboardingGender || hasHealthKitGender
        case "D5": // Height
            // Skip if collected during onboarding OR available from HealthKit
            let hasOnboardingHeight = profile.heightCm != nil && (profile.heightCm ?? 0) > 0
            let hasHealthKitHeight = healthKitHeightCm != nil
            return hasOnboardingHeight || hasHealthKitHeight
        case "D6": // Weight
            // Skip if collected during onboarding OR available from HealthKit
            let hasOnboardingWeight = profile.weightKg != nil && (profile.weightKg ?? 0) > 0
            let hasHealthKitWeight = healthKitWeightKg != nil
            return hasOnboardingWeight || hasHealthKitWeight
        default:
            return false
        }
    }

    /// Get demographic responses from onboarding profile AND HealthKit to pre-populate in questionnaire
    /// This ensures data collected during onboarding or from HealthKit is available for clinical analysis
    /// Priority: Onboarding data > HealthKit data (onboarding is more recent/user-confirmed)
    func getDemographicResponsesFromOnboarding() -> [String: QuestionResponse] {
        let profile = OnboardingManager.shared.profile
        var responses: [String: QuestionResponse] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // D1: Full name (onboarding only - not in HealthKit)
        if !profile.name.isEmpty {
            var response = QuestionResponse(questionId: "D1", dayNumber: 1)
            response.stringValue = profile.name
            responses["D1"] = response
        }

        // D2: Date of birth - try onboarding first, then HealthKit
        if profile.birthYear != 1990 {
            var response = QuestionResponse(questionId: "D2", dayNumber: 1)
            if let date = Calendar.current.date(from: DateComponents(year: profile.birthYear, month: 1, day: 1)) {
                response.stringValue = dateFormatter.string(from: date)
            }
            responses["D2"] = response
        } else if let healthKitDOB = healthKitDateOfBirth {
            var response = QuestionResponse(questionId: "D2", dayNumber: 1)
            response.stringValue = dateFormatter.string(from: healthKitDOB)
            responses["D2"] = response
            print("[QuestionnaireManager] Using HealthKit date of birth")
        }

        // D4: Sex assigned at birth - try onboarding first, then HealthKit
        if profile.gender != Gender.preferNotToSay.rawValue {
            var response = QuestionResponse(questionId: "D4", dayNumber: 1)
            response.stringValue = profile.gender
            responses["D4"] = response
        } else if let healthKitSex = healthKitBiologicalSex {
            var response = QuestionResponse(questionId: "D4", dayNumber: 1)
            response.stringValue = healthKitSex
            responses["D4"] = response
            print("[QuestionnaireManager] Using HealthKit biological sex")
        }

        // D5: Height (in cm) - try onboarding first, then HealthKit
        if let onboardingHeight = profile.heightCm, onboardingHeight > 0 {
            var heightResponse = QuestionResponse(questionId: "D5", dayNumber: 1)
            heightResponse.numberValue = onboardingHeight
            responses["D5"] = heightResponse
        } else if let healthKitHeight = healthKitHeightCm {
            var heightResponse = QuestionResponse(questionId: "D5", dayNumber: 1)
            heightResponse.numberValue = healthKitHeight
            responses["D5"] = heightResponse
            print("[QuestionnaireManager] Using HealthKit height")
        }

        // D6: Weight (in kg) - try onboarding first, then HealthKit
        if let onboardingWeight = profile.weightKg, onboardingWeight > 0 {
            var weightResponse = QuestionResponse(questionId: "D6", dayNumber: 1)
            weightResponse.numberValue = onboardingWeight
            responses["D6"] = weightResponse
        } else if let healthKitWeight = healthKitWeightKg {
            var weightResponse = QuestionResponse(questionId: "D6", dayNumber: 1)
            weightResponse.numberValue = healthKitWeight
            responses["D6"] = weightResponse
            print("[QuestionnaireManager] Using HealthKit weight")
        }

        return responses
    }

    /// Pre-populate responses from onboarding data
    /// Call this when loading Day 1 questionnaire
    func prefillFromOnboardingProfile() {
        let onboardingResponses = getDemographicResponsesFromOnboarding()

        for (questionId, response) in onboardingResponses {
            // Only pre-fill if not already answered
            if responses[questionId] == nil {
                responses[questionId] = response
                print("[QuestionnaireManager] Pre-filled \(questionId) from onboarding")
            }
        }
    }

    // MARK: - HealthKit Integration

    func prefillFromHealthKit(_ sleepSummary: HealthKitSleepSummary) {
        // Pre-fill sleep log questions with HealthKit data
        // Note: We intentionally don't auto-fill sleep times because users
        // should enter their subjective perception, not objective data.
        // HealthKit data could be shown as a comparison after user enters their data.
        _ = sleepSummary // Placeholder for future comparison feature
    }

    /// Pre-fills demographic questions (D2, D4, D5, D6) with data from Apple Health
    /// This should be called when Day 1 questionnaire is loaded
    func prefillDemographicsFromHealthKit(_ healthKitManager: HealthKitManager) {
        let demographicResponses = healthKitManager.getDemographicResponses()

        for (questionId, value) in demographicResponses {
            // Only pre-fill if not already answered
            guard responses[questionId] == nil else { continue }

            var response = QuestionResponse(
                questionId: questionId,
                dayNumber: 1
            )

            if let stringValue = value as? String {
                response.stringValue = stringValue
            } else if let intValue = value as? Int {
                response.numberValue = Double(intValue)
            } else if let doubleValue = value as? Double {
                response.numberValue = doubleValue
            }

            responses[questionId] = response
            print("[QuestionnaireManager] Pre-filled \(questionId) from HealthKit: \(value)")
        }
    }

    /// Check if a question can be auto-filled from HealthKit
    func canAutoFillFromHealthKit(_ questionId: String, healthKitManager: HealthKitManager) -> Bool {
        // Only auto-fill if not already answered
        guard responses[questionId] == nil else { return false }
        return healthKitManager.hasDemographicData(for: questionId)
    }

    /// Get the HealthKit pre-filled value for display (with source indicator)
    func getHealthKitPrefillValue(_ questionId: String, healthKitManager: HealthKitManager) -> (value: Any, source: String)? {
        let demographics = healthKitManager.demographics

        switch questionId {
        case "D2":
            if let dob = demographics.dateOfBirth {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                return (formatter.string(from: dob), "Apple Health")
            }
        case "D4":
            if let sex = demographics.biologicalSex {
                return (sex, "Apple Health")
            }
        case "D5":
            if let height = demographics.heightCm {
                return (Int(round(height)), "Apple Health")
            }
        case "D6":
            if let weight = demographics.weightKg {
                return (Int(round(weight)), "Apple Health")
            }
        default:
            break
        }

        return nil
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

    @MainActor
    func loadJourneyProgress() async {
        guard convexService.isAuthenticated else {
            print("[iOS] loadJourneyProgress: Not authenticated, skipping Convex fetch")
            return
        }

        isLoading = true
        print("[iOS] loadJourneyProgress: Fetching from Convex...")

        do {
            let progress = try await convexService.getJourneyProgress()

            // Reset semantic concepts if day changed (new questionnaire session)
            if currentDay != progress.currentDay {
                answeredSemanticConcepts.removeAll()
                print("[iOS] Day changed from \(currentDay) to \(progress.currentDay), resetting answered concepts")
            }

            currentDay = progress.currentDay
            // Handle optional startedAt - use current date if not provided
            let startDate: Date
            if let startedAt = progress.startedAt {
                startDate = Date(timeIntervalSince1970: TimeInterval(startedAt))
            } else {
                startDate = Date()
            }
            let newProgress = JourneyProgressData(
                currentDay: progress.currentDay,
                completedDays: progress.completedDays,
                totalDays: progress.totalDays,
                startedAt: startDate,
                gatewayStates: gatewayStates,
                sleepLogCompleted: progress.sleepLogCompleted ?? false,
                assessmentCompleted: progress.assessmentCompleted ?? false,
                expansionPackCompleted: progress.expansionPackCompleted ?? false
            )

            // Check if anything changed to notify observers
            let progressChanged = journeyProgress?.sleepLogCompleted != newProgress.sleepLogCompleted ||
                                  journeyProgress?.assessmentCompleted != newProgress.assessmentCompleted ||
                                  journeyProgress?.expansionPackCompleted != newProgress.expansionPackCompleted ||
                                  journeyProgress?.currentDay != newProgress.currentDay

            journeyProgress = newProgress
            isLoading = false
            print("[iOS] Loaded progress: Day \(progress.currentDay), sleepLog=\(progress.sleepLogCompleted ?? false), assessment=\(progress.assessmentCompleted ?? false), expansion=\(progress.expansionPackCompleted ?? false)")

            // Post notification if progress changed
            if progressChanged {
                NotificationCenter.default.post(name: .questionnaireProgressDidChange, object: nil)
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("[iOS] Error loading journey progress: \(error.localizedDescription)")
        }
    }

    /// Load gateway states from Convex database
    /// This syncs the local gateway states with what's stored in the database
    @MainActor
    func loadGatewayStatesFromServer() async {
        guard convexService.isAuthenticated else {
            print("[iOS] loadGatewayStatesFromServer: Not authenticated, skipping")
            return
        }

        print("[iOS] Loading gateway states from Convex...")

        do {
            let serverGatewayStates = try await convexService.getGatewayStates()

            // Create a map for quick lookup
            let serverStateMap = Dictionary(uniqueKeysWithValues: serverGatewayStates.map { ($0.gatewayId, $0) })

            // Update local gateway states from server
            for i in 0..<gatewayStates.count {
                let gatewayType = gatewayStates[i].gatewayType
                if let serverState = serverStateMap[gatewayType.rawValue] {
                    gatewayStates[i].triggered = serverState.isTriggered
                    if let triggeredAt = serverState.triggeredAt {
                        gatewayStates[i].triggeredAt = Date(timeIntervalSince1970: TimeInterval(triggeredAt / 1000))
                    }
                }
            }

            let triggeredCount = gatewayStates.filter { $0.triggered }.count
            print("[iOS] Loaded \(serverGatewayStates.count) gateway states from server, \(triggeredCount) triggered")
        } catch {
            print("[iOS] Error loading gateway states: \(error.localizedDescription)")
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
