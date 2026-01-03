//
//  AnswerDerivationSystem.swift
//  Zoe Sleep for Longevity System
//
//  Intelligent answer derivation system that:
//  1. Pre-fills Sleep Log from previous day's answers
//  2. Derives expansion question answers from core questions
//  3. Calculates derived values (BMI, sleep efficiency, etc.)
//  4. Preserves validated questionnaire scoring integrity
//
//  IMPORTANT: This system NEVER modifies original questionnaire items.
//  It only fills in "helper" questions that don't affect clinical scores.
//

import Foundation

// MARK: - Answer Derivation System

/// System for deriving answers and reducing user burden while preserving scoring
struct AnswerDerivationSystem {

    // MARK: - Sleep Log Smart Pre-fill

    /// Pre-fill today's sleep log from yesterday's answers
    /// Only applies after Day 3 (need baseline data first)
    static func preFillSleepLog(
        todaysDayType: String,
        previousDayType: String,
        previousAnswers: [String: Any],
        historicalAverages: SleepLogAverages?
    ) -> [String: Any] {

        var preFilled: [String: Any] = [:]

        // Use previous day if same day type, otherwise use historical average
        let usePreviousDay = (todaysDayType == previousDayType)

        // Time-based questions - pre-fill if same day type
        if usePreviousDay {
            // Bedtime questions
            if let gotIntoBed = previousAnswers["SD_GOT_INTO_BED"] as? String {
                preFilled["SD_GOT_INTO_BED"] = gotIntoBed
            }
            if let lightsOut = previousAnswers["SD_LIGHTS_OUT"] as? String {
                preFilled["SD_LIGHTS_OUT"] = lightsOut
            }
            if let finalWake = previousAnswers["SD_FINAL_WAKE"] as? String {
                preFilled["SD_FINAL_WAKE"] = finalWake
            }
            if let outOfBed = previousAnswers["SD_OUT_OF_BED"] as? String {
                preFilled["SD_OUT_OF_BED"] = outOfBed
            }
        } else if let averages = historicalAverages {
            // Use averages for different day type
            if todaysDayType == "Workday" || todaysDayType == "School Day" {
                preFilled["SD_GOT_INTO_BED"] = averages.weekdayBedtime
                preFilled["SD_FINAL_WAKE"] = averages.weekdayWakeTime
            } else {
                preFilled["SD_GOT_INTO_BED"] = averages.weekendBedtime
                preFilled["SD_FINAL_WAKE"] = averages.weekendWakeTime
            }
        }

        // Medication - carry forward (usually consistent)
        if let medTaken = previousAnswers["SD_MEDICATION_TAKEN"] as? String {
            preFilled["SD_MEDICATION_TAKEN"] = medTaken
            if medTaken == "Yes", let medTime = previousAnswers["SD_MEDICATION_TIME"] as? String {
                preFilled["SD_MEDICATION_TIME"] = medTime
            }
        }

        // Naps - default to previous (but user should confirm)
        if let napsTaken = previousAnswers["SD_NAPS_TAKEN"] as? String {
            preFilled["SD_NAPS_TAKEN"] = napsTaken
        }

        // Note: Quality rating (SD_SLEEP_QUALITY) is NEVER pre-filled
        // Note: Awakenings (SD_AWAKENINGS_COUNT) are NEVER pre-filled
        // These must be answered fresh each day for accuracy

        return preFilled
    }

    // MARK: - Derived Answers from Core Questions

    /// Derive expansion question answers from already-answered core questions
    /// These derivations preserve scoring because they only affect "helper" questions
    static func deriveExpansionAnswers(from coreAnswers: [String: Any]) -> [String: DerivedAnswer] {

        var derived: [String: DerivedAnswer] = [:]

        // Calculate BMI from height and weight
        if let heightCm = coreAnswers["D5"] as? Double,
           let weightKg = coreAnswers["D6"] as? Double,
           heightCm > 0 {
            let heightM = heightCm / 100.0
            let bmi = weightKg / (heightM * heightM)

            // Q188: BMI more than 35?
            derived["188"] = DerivedAnswer(
                value: bmi > 35 ? "Yes" : "No",
                derivedFrom: ["D5", "D6"],
                explanation: "Calculated from your height (\(Int(heightCm))cm) and weight (\(Int(weightKg))kg): BMI = \(String(format: "%.1f", bmi))"
            )

            // Q201: BMI calculation
            derived["201"] = DerivedAnswer(
                value: String(format: "%.1f", bmi),
                derivedFrom: ["D5", "D6"],
                explanation: "Your BMI is \(String(format: "%.1f", bmi))"
            )
        }

        // Derive neck circumference comparison from actual measurement
        if let neckCm = coreAnswers["21"] as? Double {
            // Q190: Neck circumference >40cm (15.75")?
            derived["190"] = DerivedAnswer(
                value: neckCm > 40 ? "Yes" : "No",
                derivedFrom: ["21"],
                explanation: "Based on your neck measurement of \(String(format: "%.1f", neckCm))cm"
            )
        }

        // Derive gender question from demographics
        if let sex = coreAnswers["D4"] as? String {
            // Q191: Gender = Male?
            derived["191"] = DerivedAnswer(
                value: sex.lowercased() == "male" ? "Yes" : "No",
                derivedFrom: ["D4"],
                explanation: "Based on your demographic information"
            )
        }

        // Derive blood pressure expansion answers from core
        if let hasBP = coreAnswers["27"] as? String {
            // Q187: Have or treated for high blood Pressure?
            derived["187"] = DerivedAnswer(
                value: hasBP,
                derivedFrom: ["27"],
                explanation: "Based on your earlier response about high blood pressure"
            )

            // Q200: Do you have high blood pressure?
            derived["200"] = DerivedAnswer(
                value: hasBP,
                derivedFrom: ["27"],
                explanation: "Based on your earlier response about high blood pressure"
            )
        }

        // Derive snoring expansion from gateway
        if let snoresLoud = coreAnswers["19"] as? String, snoresLoud.lowercased() == "yes" {
            // Q184: Snore loudly (louder than talking)?
            derived["184"] = DerivedAnswer(
                value: "Yes",
                derivedFrom: ["19"],
                explanation: "Based on your earlier response about snoring"
            )

            // Q192: Do you snore?
            derived["192"] = DerivedAnswer(
                value: "Yes",
                derivedFrom: ["19"],
                explanation: "Based on your earlier response about snoring"
            )
        }

        // Derive stop breathing expansion from gateway
        if let stopBreathing = coreAnswers["20"] as? String {
            // Q186: Anyone Observed you stop breathing during sleep?
            derived["186"] = DerivedAnswer(
                value: stopBreathing,
                derivedFrom: ["20"],
                explanation: "Based on your earlier response"
            )

            // Q196: Anyone noticed you stop breathing during sleep?
            derived["196"] = DerivedAnswer(
                value: stopBreathing,
                derivedFrom: ["20"],
                explanation: "Based on your earlier response"
            )
        }

        // Derive daytime tiredness from gateway
        if let dayTired = coreAnswers["17"] as? String {
            // Q185: Often feel Tired/fatigued/sleepy during day?
            let isOften = ["often", "always", "frequently", "3", "4", "5"].contains { dayTired.lowercased().contains($0) }
            derived["185"] = DerivedAnswer(
                value: isOften ? "Yes" : "No",
                derivedFrom: ["17"],
                explanation: "Based on your daytime tiredness response"
            )
        }

        return derived
    }

    // MARK: - Typical Sleep Pattern Derivation

    /// Derive typical sleep patterns from 10-day diary data
    /// Used to auto-fill core questions about typical bedtime/wake time
    static func deriveTypicalPatterns(from diaryEntries: [DerivationSleepEntry]) -> TypicalSleepPatterns? {
        guard diaryEntries.count >= 5 else { return nil } // Need at least 5 days

        let weekdayEntries = diaryEntries.filter { $0.isWeekday }
        let weekendEntries = diaryEntries.filter { !$0.isWeekday }

        guard !weekdayEntries.isEmpty, !weekendEntries.isEmpty else { return nil }

        return TypicalSleepPatterns(
            weekdayBedtime: averageTime(weekdayEntries.map { $0.gotIntoBed }),
            weekdayWakeTime: averageTime(weekdayEntries.map { $0.finalWake }),
            weekdaySleepDuration: averageMinutes(weekdayEntries.map { $0.totalSleepMinutes }),
            weekdayLatency: averageMinutes(weekdayEntries.map { $0.sleepLatencyMinutes }),
            weekendBedtime: averageTime(weekendEntries.map { $0.gotIntoBed }),
            weekendWakeTime: averageTime(weekendEntries.map { $0.finalWake }),
            weekendSleepDuration: averageMinutes(weekendEntries.map { $0.totalSleepMinutes }),
            weekendLatency: averageMinutes(weekendEntries.map { $0.sleepLatencyMinutes }),
            averageAwakenings: Int(round(Double(diaryEntries.map { $0.awakeningsCount }.reduce(0, +)) / Double(diaryEntries.count))),
            averageQuality: Double(diaryEntries.map { $0.qualityRating }.reduce(0, +)) / Double(diaryEntries.count)
        )
    }

    // MARK: - Questions to Skip Based on Previous Answers

    /// Returns question IDs that can be skipped based on gateway/core answers
    /// These questions would score 0 or are not applicable
    static func questionsToSkip(basedOn answers: [String: Any]) -> Set<String> {
        var skip: Set<String> = []

        // If no loud snoring → skip detailed snoring questions
        if let snore = answers["19"] as? String, snore.lowercased() != "yes" {
            skip.formUnion(["184", "192", "193", "194", "195"])
        }

        // If no observed stop breathing → skip those questions
        if let stop = answers["20"] as? String, stop.lowercased() != "yes" {
            skip.formUnion(["186", "196"])
        }

        // If no pain affecting sleep → skip BPI questions
        if let pain = answers["22"] as? String, pain.lowercased() != "yes" {
            skip.formUnion(["203", "204", "205", "206", "207", "208", "209", "210", "211", "212", "213", "214", "215", "216"])
        }

        // If no insomnia gateway → skip ISI and DBAS (they would score 0)
        if let insomnia = answers["3"] as? String, insomnia.lowercased() != "yes" {
            // Note: We still need these if the gateway was triggered later
            // This is handled by the gateway system, not here
        }

        // Gender-specific questions
        if let sex = answers["D4"] as? String, sex.lowercased() == "male" {
            skip.formUnion(["44I", "44J"]) // Pregnancy/breastfeeding
        }

        return skip
    }

    // MARK: - Helper Functions

    private static func averageTime(_ times: [Date]) -> String {
        guard !times.isEmpty else { return "22:00" }

        let totalMinutes = times.reduce(0) { sum, date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            var minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            // Handle times past midnight
            if minutes < 360 { minutes += 1440 } // Add 24 hours if before 6 AM
            return sum + minutes
        }

        var avgMinutes = totalMinutes / times.count
        if avgMinutes >= 1440 { avgMinutes -= 1440 }

        let hours = avgMinutes / 60
        let mins = avgMinutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }

    private static func averageMinutes(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }
}

// MARK: - Supporting Types

/// A derived answer with source and explanation
struct DerivedAnswer {
    let value: Any
    let derivedFrom: [String]  // Question IDs used to derive this
    let explanation: String    // Human-readable explanation

    /// Whether to show this derivation to the user
    var shouldShow: Bool {
        // Always show calculated values like BMI
        return true
    }
}

/// Historical averages for sleep log pre-fill
struct SleepLogAverages {
    let weekdayBedtime: String
    let weekdayWakeTime: String
    let weekendBedtime: String
    let weekendWakeTime: String
}

/// A single sleep diary entry for derivation calculations
/// Note: Named to avoid conflict with SleepDiaryEntry in ContentView
struct DerivationSleepEntry {
    let date: Date
    let dayType: String
    let gotIntoBed: Date
    let lightsOut: Date
    let sleepOnset: Date
    let finalWake: Date
    let outOfBed: Date
    let awakeningsCount: Int
    let awakeningsDuration: Int
    let qualityRating: Int

    var isWeekday: Bool {
        ["Workday", "School Day"].contains(dayType)
    }

    var totalSleepMinutes: Int {
        let totalInBed = Int(outOfBed.timeIntervalSince(gotIntoBed) / 60)
        return totalInBed - sleepLatencyMinutes - awakeningsDuration
    }

    var sleepLatencyMinutes: Int {
        Int(sleepOnset.timeIntervalSince(lightsOut) / 60)
    }

    var sleepEfficiency: Double {
        let timeInBed = outOfBed.timeIntervalSince(gotIntoBed) / 60
        guard timeInBed > 0 else { return 0 }
        return (Double(totalSleepMinutes) / timeInBed) * 100
    }
}

/// Typical sleep patterns derived from diary data
struct TypicalSleepPatterns {
    let weekdayBedtime: String
    let weekdayWakeTime: String
    let weekdaySleepDuration: Int  // minutes
    let weekdayLatency: Int        // minutes

    let weekendBedtime: String
    let weekendWakeTime: String
    let weekendSleepDuration: Int  // minutes
    let weekendLatency: Int        // minutes

    let averageAwakenings: Int
    let averageQuality: Double

    /// Social jet lag = weekend-weekday midpoint difference
    var socialJetLag: Int {
        // Simplified: difference in wake times
        // In reality, should use sleep midpoint
        return abs(weekendSleepDuration - weekdaySleepDuration)
    }
}

// MARK: - Duplicate Question Mapping

/// Maps duplicate questions to their primary/source question
struct DuplicateQuestionMapping {

    /// Questions that are exact duplicates - always derive from source
    static let exactDuplicates: [String: String] = [
        "59": "35",      // Bed partner (59 → 35)
        "31": "54C",     // Last caffeine time (31 → 54C)
        "187": "27",     // High BP expansion (187 → 27)
        "200": "27",     // High BP Berlin (200 → 27)
        "186": "20",     // Stop breathing observed (186 → 20)
        "196": "20",     // Stop breathing Berlin (196 → 20)
        "191": "D4",     // Gender male (191 → D4)
    ]

    /// Questions that can be derived from calculations
    static let calculatedQuestions: [String: [String]] = [
        "188": ["D5", "D6"],   // BMI > 35 from height/weight
        "190": ["21"],          // Neck > 40cm from neck measurement
        "201": ["D5", "D6"],   // BMI calculation
    ]

    /// Questions that overlap in concept - use gateway to decide
    static let conceptualOverlaps: [String: (gateway: String, skipIfNo: [String])] = [
        "snoring": (
            gateway: "19",
            skipIfNo: ["184", "192", "193", "194", "195"]
        ),
        "stopBreathing": (
            gateway: "20",
            skipIfNo: ["186", "196"]
        ),
        "pain": (
            gateway: "22",
            skipIfNo: ["203", "204", "205", "206", "207", "208", "209", "210", "211", "212", "213", "214", "215", "216"]
        ),
    ]
}

// MARK: - Standardized Answer Labels

/// Standardized labels for validated questionnaire scales
struct StandardizedAnswerLabels {

    /// ISI (Insomnia Severity Index) - 0-4 scale
    /// Original publication: Morin et al., 2011 - Sleep 34(5):601-8
    /// Note: ISI has question-specific labels per the validated instrument

    /// ISI Items 1-3 (Severity of sleep onset, maintenance, and early awakening problems)
    static let isiSeverity: [Int: String] = [
        0: "None",
        1: "Mild",
        2: "Moderate",
        3: "Severe",
        4: "Very Severe"
    ]

    /// ISI Item 4 (Satisfaction with sleep pattern)
    static let isiSatisfaction: [Int: String] = [
        0: "Very Satisfied",
        1: "Satisfied",
        2: "Moderately Satisfied",
        3: "Dissatisfied",
        4: "Very Dissatisfied"
    ]

    /// ISI Item 5 (Interference with daily functioning)
    static let isiInterference: [Int: String] = [
        0: "Not at all interfering",
        1: "A little",
        2: "Somewhat",
        3: "Much",
        4: "Very much interfering"
    ]

    /// ISI Item 6 (How noticeable to others)
    static let isiNoticeable: [Int: String] = [
        0: "Not at all noticeable",
        1: "A little",
        2: "Somewhat",
        3: "Much",
        4: "Very much noticeable"
    ]

    /// ISI Item 7 (Worry/distress about sleep problem)
    static let isiWorried: [Int: String] = [
        0: "Not at all worried",
        1: "A little",
        2: "Somewhat",
        3: "Much",
        4: "Very much worried"
    ]

    /// Default ISI labels (for backward compatibility - uses severity scale)
    static let isi: [Int: String] = isiSeverity

    /// DBAS-16 (Dysfunctional Beliefs) - 0-10 scale
    static let dbas16: [Int: String] = [
        0: "Strongly Disagree",
        5: "Neutral",
        10: "Strongly Agree"
    ]

    /// ESS (Epworth Sleepiness Scale) - 0-3 scale
    static let ess: [Int: String] = [
        0: "Would never doze",
        1: "Slight chance of dozing",
        2: "Moderate chance of dozing",
        3: "High chance of dozing"
    ]

    /// FSS (Fatigue Severity Scale) - 1-7 scale
    static let fss: [Int: String] = [
        1: "Strongly Disagree",
        4: "Neither",
        7: "Strongly Agree"
    ]

    /// PHQ-9 / GAD-7 - 0-3 scale
    static let phqGad: [Int: String] = [
        0: "Not at all",
        1: "Several days",
        2: "More than half the days",
        3: "Nearly every day"
    ]

    /// DASS-21 - 0-3 scale
    static let dass21: [Int: String] = [
        0: "Did not apply to me",
        1: "Applied some degree",
        2: "Considerable degree",
        3: "Applied very much"
    ]

    /// PSAS (Pre-Sleep Arousal) - 1-5 scale
    static let psas: [Int: String] = [
        1: "Not at all",
        2: "Slightly",
        3: "Moderately",
        4: "A lot",
        5: "Extremely"
    ]

    /// SHI (Sleep Hygiene Index) - 0-4 scale
    static let shi: [Int: String] = [
        0: "Never",
        1: "Rarely",
        2: "Sometimes",
        3: "Frequently",
        4: "Always"
    ]

    /// FOSQ-10 (Functional Outcomes) - 1-4 scale
    static let fosq10: [Int: String] = [
        1: "Extreme difficulty",
        2: "Moderate difficulty",
        3: "A little difficulty",
        4: "No difficulty"
    ]

    /// BPI (Brief Pain Inventory) - 0-10 scale
    static let bpiPain: [Int: String] = [
        0: "No pain",
        5: "Moderate pain",
        10: "Worst pain imaginable"
    ]

    static let bpiInterference: [Int: String] = [
        0: "Does not interfere",
        5: "Moderately interferes",
        10: "Completely interferes"
    ]

    /// PSQI - 0-3 scale
    static let psqi: [Int: String] = [
        0: "Not during the past month",
        1: "Less than once a week",
        2: "Once or twice a week",
        3: "Three or more times a week"
    ]

    /// Sleep Quality Rating - 0-3 scale (PSQI)
    static let psqiQuality: [Int: String] = [
        0: "Very good",
        1: "Fairly good",
        2: "Fairly bad",
        3: "Very bad"
    ]

    /// MEQ (Morningness-Eveningness) - various scales
    static let meqType: [Int: String] = [
        1: "Definitely evening type",
        2: "More evening than morning",
        3: "Neither type",
        4: "More morning than evening",
        5: "Definitely morning type"
    ]

    /// Get labels for a specific questionnaire
    static func labels(for questionnaireId: String) -> [Int: String]? {
        switch questionnaireId.uppercased() {
        case "ISI": return isi
        case "DBAS", "DBAS-16": return dbas16
        case "ESS": return ess
        case "FSS": return fss
        case "PHQ-9", "PHQ9", "GAD-7", "GAD7": return phqGad
        case "DASS-21", "DASS21": return dass21
        case "PSAS": return psas
        case "SHI": return shi
        case "FOSQ-10", "FOSQ10": return fosq10
        case "BPI": return bpiPain
        case "PSQI": return psqi
        case "MEQ": return meqType
        default: return nil
        }
    }

    /// Get labels for a specific question ID (supports question-specific labels like ISI)
    /// Returns question-specific labels if available, otherwise falls back to questionnaire-level labels
    static func labels(forQuestion questionId: String) -> [Int: String]? {
        let id = questionId.uppercased()

        // ISI has question-specific labels per the original validated instrument
        if id.hasPrefix("ISI_") || id.hasPrefix("ISI-") {
            // Extract question number (ISI_1, ISI_2, etc.)
            let numberPart = id.replacingOccurrences(of: "ISI_", with: "")
                              .replacingOccurrences(of: "ISI-", with: "")
            if let questionNumber = Int(numberPart) {
                switch questionNumber {
                case 1, 2, 3:
                    return isiSeverity  // Difficulty falling asleep, staying asleep, waking too early
                case 4:
                    return isiSatisfaction  // How satisfied with sleep pattern
                case 5:
                    return isiInterference  // How much interferes with daily functioning
                case 6:
                    return isiNoticeable  // How noticeable to others
                case 7:
                    return isiWorried  // How worried/distressed
                default:
                    return isiSeverity  // Fallback to severity scale
                }
            }
        }

        // For other questionnaires, use questionnaire-level labels
        if id.hasPrefix("ISI") { return isi }
        if id.hasPrefix("DBAS") { return dbas16 }
        if id.hasPrefix("ESS") { return ess }
        if id.hasPrefix("FSS") { return fss }
        if id.hasPrefix("PHQ") { return phqGad }
        if id.hasPrefix("GAD") { return phqGad }
        if id.hasPrefix("DASS") { return dass21 }
        if id.hasPrefix("PSAS") { return psas }
        if id.hasPrefix("SHI") { return shi }
        if id.hasPrefix("FOSQ") { return fosq10 }
        if id.hasPrefix("BPI") { return bpiPain }
        if id.hasPrefix("PSQI") { return psqi }
        if id.hasPrefix("MEQ") { return meqType }

        return nil
    }

    /// Get min/max labels for display
    static func minMaxLabels(for questionnaireId: String) -> (min: String, max: String)? {
        switch questionnaireId.uppercased() {
        case "ISI": return ("None", "Very Severe")
        case "DBAS", "DBAS-16": return ("Strongly Disagree", "Strongly Agree")
        case "ESS": return ("Would never doze", "High chance")
        case "FSS": return ("Strongly Disagree", "Strongly Agree")
        case "PHQ-9", "PHQ9", "GAD-7", "GAD7": return ("Not at all", "Nearly every day")
        case "DASS-21", "DASS21": return ("Did not apply", "Very much")
        case "PSAS": return ("Not at all", "Extremely")
        case "SHI": return ("Never", "Always")
        case "FOSQ-10", "FOSQ10": return ("Extreme difficulty", "No difficulty")
        case "BPI": return ("No pain", "Worst imaginable")
        case "PSQI": return ("Not during month", "3+ times/week")
        default: return nil
        }
    }
}
