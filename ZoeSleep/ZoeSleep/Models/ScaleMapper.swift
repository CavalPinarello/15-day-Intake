//
//  ScaleMapper.swift
//  Zoe Sleep
//
//  Maps unified 1-10 user input to clinical scale values
//  Users see a consistent 1-10 scale, while we store correct clinical values for scoring
//
//  IMPORTANT: Scale questions have two types:
//  - POSITIVE: Higher = better (sleep quality, energy, alertness)
//  - NEGATIVE: Higher = worse (pain, difficulty, severity, symptoms)
//
//  Created: December 2024
//

import Foundation

// MARK: - Scale Types

/// Represents the different clinical scale types used in validated questionnaires
enum ClinicalScaleType {
    case fourPoint          // 0-3 (PHQ-9, GAD-7, ESS, DASS-21, PSQI)
    case fivePoint          // 0-4 (ISI)
    case fivePointOffset    // 1-5 (PROMIS, PSAS, Sleep Hygiene, CSD)
    case fourPointOffset    // 1-4 (FOSQ-10)
    case sevenPoint         // 1-7 (FSS)
    case elevenPoint        // 0-10 (DBAS, BPI)
    case passthrough        // Already 1-10 or unknown - no mapping needed
}

/// Direction of the scale - determines label type
enum ScaleDirection {
    case positive  // Higher = better (quality, energy, alertness)
    case negative  // Higher = worse (pain, difficulty, severity)
    case neutral   // Neither good nor bad (chronotype, frequency)
}

// MARK: - Scale Mapper

/// Maps unified 1-10 user input to clinical scale values and provides semantic labels
struct ScaleMapper {

    // MARK: - Scale Type Detection

    /// Determine clinical scale type from question's min/max values
    static func getScaleType(clinicalMin: Int, clinicalMax: Int) -> ClinicalScaleType {
        let range = clinicalMax - clinicalMin

        switch (clinicalMin, range) {
        case (0, 3): return .fourPoint          // 0-3
        case (0, 4): return .fivePoint          // 0-4
        case (1, 4): return .fivePointOffset    // 1-5
        case (1, 3): return .fourPointOffset    // 1-4
        case (1, 6): return .sevenPoint         // 1-7
        case (0, 10): return .elevenPoint       // 0-10
        default: return .passthrough            // Unknown - pass through
        }
    }

    // MARK: - Scale Direction Detection

    /// Determine if a question is positive (higher=better) or negative (higher=worse)
    static func getScaleDirection(questionId: String, questionText: String = "") -> ScaleDirection {
        let id = questionId.uppercased()
        let text = questionText.lowercased()

        // ========== POSITIVE QUESTIONS (Higher = Better) ==========

        // Core sleep quality questions - POSITIVE
        let positiveQuestionIds = [
            "1", "55",              // Sleep quality rating
            "SL_QUALITY",           // Sleep log quality rating
            "CSD_QUALITY",          // CSD sleep quality
            "CSD_REFRESHED",        // CSD refreshed rating
            "CSD_ALERT",            // How refreshed upon waking
            "234",                  // How easy to get up
            "235",                  // How alert first 30min
            "239", "246",           // Performance ability
            "33C",                  // How dark is bedroom (darker = better for sleep)
        ]

        if positiveQuestionIds.contains(id) {
            return .positive
        }

        // ISI Item 4 is INVERTED - satisfaction (higher clinical = WORSE satisfaction)
        // But we present it as: 1=dissatisfied, 10=satisfied (positive display)
        if id == "ISI_4" || id == "ISI-4" || id == "63" {
            return .positive  // Display as satisfaction scale
        }

        // Text-based detection for positive questions
        let positiveKeywords = [
            "sleep quality", "quality of your sleep", "rate your overall sleep",
            "how refreshed", "how alert", "how energized", "how rested",
            "how easy", "how well", "how good",
            "satisfaction", "satisfied",
            "how dark"  // Darker bedroom = better
        ]

        for keyword in positiveKeywords {
            if text.contains(keyword) {
                return .positive
            }
        }

        // ========== NEGATIVE QUESTIONS (Higher = Worse) ==========

        // Clinical instruments that measure problems/symptoms - NEGATIVE
        let negativeInstrumentPrefixes = [
            "ISI",      // Insomnia severity (except ISI_4)
            "PHQ",      // Depression symptoms
            "GAD",      // Anxiety symptoms
            "ESS",      // Sleepiness (dozing = bad)
            "FSS",      // Fatigue severity
            "DASS",     // Depression/anxiety/stress
            "PSAS",     // Pre-sleep arousal
            "BPI",      // Pain
            // Note: SH_ (Sleep Hygiene) removed - these ask about GOOD habits, so higher = better
            "PROMIS",   // Cognitive impairment
            "FOSQ",     // Difficulty doing things
        ]

        // Clinical instruments that measure GOOD behaviors - POSITIVE
        // (Higher values = doing the good behavior more often = better)
        let positiveInstrumentPrefixes = [
            "SH_",      // Sleep Hygiene - good habits (Always = better)
        ]

        for prefix in positiveInstrumentPrefixes {
            if id.hasPrefix(prefix) {
                return .positive
            }
        }

        for prefix in negativeInstrumentPrefixes {
            if id.hasPrefix(prefix) {
                // Exception: ISI_4 is positive (satisfaction)
                if prefix == "ISI" && (id == "ISI_4" || id == "ISI-4") {
                    continue
                }
                return .negative
            }
        }

        // Core question IDs that are negative
        let negativeQuestionIds = [
            "53E",                          // Work stress
            "57", "58",                     // Trouble staying awake, keeping enthusiasm
            "60", "61", "62",               // Difficulty sleeping
            "64", "65", "66",               // Noticeable, worried, interference
            "67", "68", "69", "71", "72",   // DBAS-style beliefs
            "73", "74", "75", "76", "77",
            "78", "79", "80", "81", "82",
            "84", "85", "86", "87", "88",   // PSAS-style arousal
            "89", "90", "91", "93", "94",
            "95", "96", "97", "98",
            "99", "100", "102", "103",      // Sleep hygiene habits
            "104", "105", "106", "107",
            "108", "109", "110", "111",
            "112", "113", "114", "115",     // ESS-style dozing
            "116", "117", "118", "119",
            "121", "122", "123", "124",     // FSS-style fatigue
            "125", "126", "127",
            "129", "130", "131", "132",     // FOSQ-style difficulty
            "133", "134", "135", "136",
            "137", "138",
            "139", "140", "141", "142",     // PHQ-9 style symptoms
            "143", "144", "145", "146", "147",
            "148", "149", "150", "151",     // GAD-7 style symptoms
            "152", "153", "154",
            "156", "157", "158", "159",     // DASS-21 style symptoms
            "160", "161", "162", "163",
            "165", "166", "167", "168",
            "169", "170", "171", "172",
            "173", "174",
            "176", "177", "178", "179",     // PROMIS cognitive
            "180", "181", "182", "183",
            "193", "194",                   // Snoring frequency
            "197", "198",                   // Tiredness/fatigue
            "204", "205", "206", "207",     // Pain severity
            "210", "211", "212", "213",     // Pain interference
            "214", "215", "216",
            "17",                           // Gateway: excessive tiredness
            "23",                           // Pain severity
            "33B",                          // Noise level (higher noise = worse)
            "237",                          // How tired first 30min
            "242",                          // Tiredness at 11pm
        ]

        if negativeQuestionIds.contains(id) {
            return .negative
        }

        // Text-based detection for negative questions
        let negativeKeywords = [
            "difficulty", "trouble", "problem", "pain", "stress",
            "worried", "worry", "anxious", "nervous", "depressed",
            "interfere", "interference", "severity", "severe",
            "tired", "fatigue", "sleepy", "dozing",
            "can't", "cannot", "unable",
            "poor", "bad", "worse",
            "fear", "afraid", "panic",
            "irritable", "annoyed", "agitated",
            "noise", "noisy"
        ]

        for keyword in negativeKeywords {
            if text.contains(keyword) {
                return .negative
            }
        }

        // ========== NEUTRAL QUESTIONS ==========
        // Chronotype, preferences - neither good nor bad
        let neutralQuestionIds = [
            "233",   // Alarm clock dependency
            "236",   // Appetite
            "238",   // Bedtime comparison
            "249",   // Morning/evening type
        ]

        if neutralQuestionIds.contains(id) {
            return .neutral
        }

        // Default to negative (safer for clinical instruments)
        return .negative
    }

    // MARK: - Display to Clinical Mapping

    /// Map user's 1-10 display value to clinical scale value
    static func mapToClinicalScale(
        displayValue: Double,
        clinicalMin: Int,
        clinicalMax: Int
    ) -> Double {
        let scaleType = getScaleType(clinicalMin: clinicalMin, clinicalMax: clinicalMax)
        let intValue = Int(displayValue)

        switch scaleType {
        case .fourPoint:      // 0-3 (PHQ-9, GAD-7, ESS, DASS-21)
            switch intValue {
            case 1...2: return 0
            case 3...5: return 1
            case 6...7: return 2
            case 8...10: return 3
            default: return 0
            }

        case .fivePoint:      // 0-4 (ISI)
            switch intValue {
            case 1...2: return 0
            case 3...4: return 1
            case 5...6: return 2
            case 7...8: return 3
            case 9...10: return 4
            default: return 0
            }

        case .fivePointOffset: // 1-5 (PROMIS, PSAS, Sleep Hygiene, CSD)
            switch intValue {
            case 1...2: return 1
            case 3...4: return 2
            case 5...6: return 3
            case 7...8: return 4
            case 9...10: return 5
            default: return 1
            }

        case .fourPointOffset: // 1-4 (FOSQ-10)
            switch intValue {
            case 1...2: return 1
            case 3...5: return 2
            case 6...8: return 3
            case 9...10: return 4
            default: return 1
            }

        case .sevenPoint:     // 1-7 (FSS)
            switch intValue {
            case 1: return 1
            case 2...3: return 2
            case 4: return 3
            case 5...6: return 4
            case 7: return 5
            case 8...9: return 6
            case 10: return 7
            default: return 4
            }

        case .elevenPoint:    // 0-10 (DBAS, BPI)
            return ((displayValue - 1) * 10.0 / 9.0).rounded()

        case .passthrough:
            return displayValue
        }
    }

    // MARK: - Clinical to Display Mapping (Reverse)

    /// Convert stored clinical value back to display value (1-10)
    static func mapToDisplayValue(
        clinicalValue: Double,
        clinicalMin: Int,
        clinicalMax: Int
    ) -> Double {
        let scaleType = getScaleType(clinicalMin: clinicalMin, clinicalMax: clinicalMax)
        let intClinical = Int(clinicalValue)

        switch scaleType {
        case .fourPoint:      // 0-3 → 1-10
            switch intClinical {
            case 0: return 1.5
            case 1: return 4.0
            case 2: return 6.5
            case 3: return 9.0
            default: return 5.0
            }

        case .fivePoint:      // 0-4 → 1-10
            switch intClinical {
            case 0: return 1.5
            case 1: return 3.5
            case 2: return 5.5
            case 3: return 7.5
            case 4: return 9.5
            default: return 5.0
            }

        case .fivePointOffset: // 1-5 → 1-10
            switch intClinical {
            case 1: return 1.5
            case 2: return 3.5
            case 3: return 5.5
            case 4: return 7.5
            case 5: return 9.5
            default: return 5.0
            }

        case .fourPointOffset: // 1-4 → 1-10
            switch intClinical {
            case 1: return 1.5
            case 2: return 4.0
            case 3: return 7.0
            case 4: return 9.5
            default: return 5.0
            }

        case .sevenPoint:     // 1-7 → 1-10
            switch intClinical {
            case 1: return 1.0
            case 2: return 2.5
            case 3: return 4.0
            case 4: return 5.5
            case 5: return 7.0
            case 6: return 8.5
            case 7: return 10.0
            default: return 5.0
            }

        case .elevenPoint:    // 0-10 → 1-10
            return (clinicalValue * 9.0 / 10.0) + 1.0

        case .passthrough:
            return clinicalValue
        }
    }

    // MARK: - Semantic Labels

    /// Get semantic label for user's 1-10 display value
    static func getLabel(
        displayValue: Int,
        questionId: String,
        clinicalMin: Int,
        clinicalMax: Int
    ) -> String {
        let id = questionId.uppercased()
        let direction = getScaleDirection(questionId: questionId)

        // ========== SPECIFIC INSTRUMENT LABELS ==========

        // PHQ-9 / GAD-7 (frequency of symptoms)
        if id.hasPrefix("PHQ") || id.hasPrefix("GAD") {
            return phqGadLabels[displayValue] ?? ""
        }

        // ISI - question-specific
        if id.hasPrefix("ISI") {
            return getISILabel(displayValue: displayValue, questionId: questionId)
        }

        // ESS (sleepiness)
        if id.hasPrefix("ESS") {
            return essLabels[displayValue] ?? ""
        }

        // FSS (fatigue agreement)
        if id.hasPrefix("FSS") {
            return fssLabels[displayValue] ?? ""
        }

        // PROMIS Cognitive (impairment frequency)
        if id.hasPrefix("PROMIS") {
            return promisLabels[displayValue] ?? ""
        }

        // PSAS (arousal intensity)
        if id.hasPrefix("PSAS") {
            return psasLabels[displayValue] ?? ""
        }

        // Sleep Hygiene (good habit frequency)
        // SH_5 uses agreement scale, others use frequency
        if id == "SH_5" {
            return dbasLabels[displayValue] ?? ""
        }
        if id.hasPrefix("SH_") {
            return sleepHygieneLabels[displayValue] ?? ""
        }

        // FOSQ (difficulty)
        if id.hasPrefix("FOSQ") {
            return fosqLabels[displayValue] ?? ""
        }

        // DBAS (agreement with dysfunctional beliefs)
        if id.hasPrefix("DBAS") {
            return dbasLabels[displayValue] ?? ""
        }

        // BPI (pain)
        if id.hasPrefix("BPI") {
            return bpiLabels[displayValue] ?? ""
        }

        // DASS-21 (symptom frequency)
        if id.hasPrefix("DASS") {
            return dassLabels[displayValue] ?? ""
        }

        // CSD Sleep Quality / Refreshed
        if id.hasPrefix("CSD") || id == "CSD_QUALITY" || id == "CSD_ALERT" {
            return csdLabels[displayValue] ?? ""
        }

        // ========== CORE QUESTION SPECIFIC LABELS ==========

        // Sleep quality questions (1, 55, SL_QUALITY)
        if id == "1" || id == "55" || id == "SL_QUALITY" {
            return sleepQualityLabels[displayValue] ?? ""
        }

        // Satisfaction questions (63 = ISI_4 equivalent)
        if id == "63" {
            return satisfactionLabels[displayValue] ?? ""
        }

        // Work stress (53E)
        if id == "53E" {
            return stressLabels[displayValue] ?? ""
        }

        // How easy to get up (234)
        if id == "234" {
            return easeLabels[displayValue] ?? ""
        }

        // How alert (235)
        if id == "235" {
            return alertnessLabels[displayValue] ?? ""
        }

        // Performance ability (239, 246)
        if id == "239" || id == "246" {
            return performanceLabels[displayValue] ?? ""
        }

        // How dark is bedroom (33C)
        if id == "33C" {
            return darknessLabels[displayValue] ?? ""
        }

        // Noise level (33B)
        if id == "33B" {
            return noiseLabels[displayValue] ?? ""
        }

        // Pain severity questions
        if id == "23" || id == "204" || id == "205" || id == "206" || id == "207" {
            return bpiLabels[displayValue] ?? ""
        }

        // Tiredness questions
        if id == "237" || id == "242" {
            return tirednessLabels[displayValue] ?? ""
        }

        // ========== DIRECTION-BASED DEFAULT LABELS ==========

        switch direction {
        case .positive:
            return positiveLabels[displayValue] ?? ""
        case .negative:
            return negativeLabels[displayValue] ?? ""
        case .neutral:
            return neutralLabels[displayValue] ?? ""
        }
    }

    // MARK: - Min/Max Labels for Slider Endpoints

    /// Get endpoint labels for the 1-10 slider
    static func getMinMaxLabels(questionId: String, clinicalMin: Int, clinicalMax: Int) -> (min: String, max: String) {
        let id = questionId.uppercased()
        let direction = getScaleDirection(questionId: questionId)

        // Specific instruments
        if id.hasPrefix("PHQ") || id.hasPrefix("GAD") {
            return ("Not at all", "Nearly every day")
        }
        if id.hasPrefix("ISI") && id != "ISI_4" && id != "ISI-4" {
            return ("None", "Very severe")
        }
        if id == "ISI_4" || id == "ISI-4" || id == "63" {
            return ("Very dissatisfied", "Very satisfied")
        }
        if id.hasPrefix("ESS") {
            return ("Would never doze", "High chance")
        }
        if id.hasPrefix("FSS") || id.hasPrefix("DBAS") {
            return ("Strongly disagree", "Strongly agree")
        }
        if id.hasPrefix("PROMIS") {
            return ("Never", "Very often")
        }
        // Sleep Hygiene: SH_5 is agreement, others are frequency
        if id == "SH_5" {
            return ("Strongly disagree", "Strongly agree")
        }
        if id.hasPrefix("SH_") {
            return ("Never", "Always")
        }
        if id.hasPrefix("PSAS") {
            return ("Not at all", "Extremely")
        }
        if id.hasPrefix("FOSQ") {
            return ("No difficulty", "Extreme difficulty")
        }
        if id.hasPrefix("BPI") || id == "23" || id == "204" || id == "205" || id == "206" || id == "207" {
            return ("No pain at all", "Worst imaginable")
        }
        if id.hasPrefix("DASS") {
            return ("Did not apply", "Very much")
        }
        if id.hasPrefix("CSD") || id == "1" || id == "55" || id == "SL_QUALITY" {
            return ("Very poor", "Excellent")
        }

        // Work stress
        if id == "53E" {
            return ("No stress", "Extreme stress")
        }

        // Alertness, ease, performance
        if id == "234" {
            return ("Very difficult", "Very easy")
        }
        if id == "235" {
            return ("Not at all alert", "Very alert")
        }
        if id == "239" || id == "246" {
            return ("Would struggle", "Would do well")
        }

        // Bedroom environment
        if id == "33C" {
            return ("Very bright", "Completely dark")
        }
        if id == "33B" {
            return ("Very quiet", "Very noisy")
        }

        // Tiredness
        if id == "237" || id == "242" {
            return ("Not at all tired", "Very tired")
        }

        // Direction-based defaults
        switch direction {
        case .positive:
            return ("Very poor", "Excellent")
        case .negative:
            return ("Not at all", "Extremely")
        case .neutral:
            return ("Low", "High")
        }
    }

    // MARK: - Label Dictionaries

    // ========== POSITIVE SCALE LABELS (Higher = Better) ==========

    /// Sleep quality: Very poor → Excellent
    static let sleepQualityLabels: [Int: String] = [
        1: "Very poor",
        2: "Poor",
        3: "Poor",
        4: "Fair",
        5: "Fair",
        6: "Good",
        7: "Good",
        8: "Very good",
        9: "Excellent",
        10: "Excellent"
    ]

    /// CSD Sleep Quality: Very poor → Very good
    static let csdLabels: [Int: String] = [
        1: "Very poor",
        2: "Poor",
        3: "Poor",
        4: "Fair",
        5: "Fair",
        6: "Good",
        7: "Good",
        8: "Very good",
        9: "Very good",
        10: "Excellent"
    ]

    /// Satisfaction: Very dissatisfied → Very satisfied
    static let satisfactionLabels: [Int: String] = [
        1: "Very dissatisfied",
        2: "Dissatisfied",
        3: "Dissatisfied",
        4: "Somewhat dissatisfied",
        5: "Neutral",
        6: "Neutral",
        7: "Somewhat satisfied",
        8: "Satisfied",
        9: "Satisfied",
        10: "Very satisfied"
    ]

    /// Alertness: Not at all alert → Very alert
    static let alertnessLabels: [Int: String] = [
        1: "Not at all alert",
        2: "Barely alert",
        3: "Slightly alert",
        4: "Somewhat alert",
        5: "Moderately alert",
        6: "Fairly alert",
        7: "Alert",
        8: "Very alert",
        9: "Extremely alert",
        10: "Fully alert"
    ]

    /// Ease: Very difficult → Very easy
    static let easeLabels: [Int: String] = [
        1: "Very difficult",
        2: "Difficult",
        3: "Difficult",
        4: "Somewhat difficult",
        5: "Neutral",
        6: "Somewhat easy",
        7: "Fairly easy",
        8: "Easy",
        9: "Very easy",
        10: "Effortless"
    ]

    /// Performance: Would struggle → Would do well
    static let performanceLabels: [Int: String] = [
        1: "Would struggle greatly",
        2: "Would struggle",
        3: "Would have difficulty",
        4: "Somewhat difficult",
        5: "Neutral",
        6: "Would manage",
        7: "Would do okay",
        8: "Would do well",
        9: "Would perform well",
        10: "Would excel"
    ]

    /// Darkness: Very bright → Completely dark
    static let darknessLabels: [Int: String] = [
        1: "Very bright",
        2: "Bright",
        3: "Somewhat bright",
        4: "Slight light",
        5: "Dim",
        6: "Fairly dark",
        7: "Dark",
        8: "Very dark",
        9: "Almost pitch black",
        10: "Completely dark"
    ]

    /// Generic positive labels
    static let positiveLabels: [Int: String] = [
        1: "Very poor",
        2: "Poor",
        3: "Fair",
        4: "Below average",
        5: "Average",
        6: "Above average",
        7: "Good",
        8: "Very good",
        9: "Excellent",
        10: "Outstanding"
    ]

    // ========== NEGATIVE SCALE LABELS (Higher = Worse) ==========

    /// PHQ-9 / GAD-7: Symptom frequency
    static let phqGadLabels: [Int: String] = [
        1: "Not at all",
        2: "Not at all",
        3: "Several days",
        4: "Several days",
        5: "Several days",
        6: "More than half the days",
        7: "More than half the days",
        8: "Nearly every day",
        9: "Nearly every day",
        10: "Nearly every day"
    ]

    /// ESS: Chance of dozing
    static let essLabels: [Int: String] = [
        1: "Would never doze",
        2: "Would never doze",
        3: "Slight chance",
        4: "Slight chance",
        5: "Slight chance",
        6: "Moderate chance",
        7: "Moderate chance",
        8: "High chance",
        9: "High chance",
        10: "Would definitely doze"
    ]

    /// FSS: Agreement with fatigue statements
    static let fssLabels: [Int: String] = [
        1: "Strongly disagree",
        2: "Disagree",
        3: "Disagree",
        4: "Somewhat disagree",
        5: "Neither agree nor disagree",
        6: "Neither agree nor disagree",
        7: "Somewhat agree",
        8: "Agree",
        9: "Agree",
        10: "Strongly agree"
    ]

    /// PROMIS Cognitive: Impairment frequency
    static let promisLabels: [Int: String] = [
        1: "Never",
        2: "Never",
        3: "Rarely",
        4: "Rarely",
        5: "Sometimes",
        6: "Sometimes",
        7: "Often",
        8: "Often",
        9: "Very often",
        10: "Almost always"
    ]

    /// PSAS: Arousal intensity
    static let psasLabels: [Int: String] = [
        1: "Not at all",
        2: "Not at all",
        3: "Slightly",
        4: "Slightly",
        5: "Moderately",
        6: "Moderately",
        7: "A lot",
        8: "A lot",
        9: "Extremely",
        10: "Extremely"
    ]

    /// Sleep Hygiene: Good habit frequency (higher = better)
    static let sleepHygieneLabels: [Int: String] = [
        1: "Never",
        2: "Rarely",
        3: "Rarely",
        4: "Sometimes",
        5: "Sometimes",
        6: "Often",
        7: "Often",
        8: "Very often",
        9: "Always",
        10: "Always"
    ]

    /// FOSQ: Difficulty level
    static let fosqLabels: [Int: String] = [
        1: "No difficulty",
        2: "No difficulty",
        3: "A little difficulty",
        4: "A little difficulty",
        5: "Some difficulty",
        6: "Moderate difficulty",
        7: "Moderate difficulty",
        8: "Much difficulty",
        9: "Extreme difficulty",
        10: "Unable to do"
    ]

    /// DBAS: Agreement with beliefs
    static let dbasLabels: [Int: String] = [
        1: "Strongly disagree",
        2: "Disagree",
        3: "Somewhat disagree",
        4: "Slightly disagree",
        5: "Neutral",
        6: "Neutral",
        7: "Slightly agree",
        8: "Somewhat agree",
        9: "Agree",
        10: "Strongly agree"
    ]

    /// BPI: Pain intensity
    static let bpiLabels: [Int: String] = [
        1: "No pain at all",
        2: "Minimal pain",
        3: "Mild pain",
        4: "Mild pain",
        5: "Moderate pain",
        6: "Moderate pain",
        7: "Moderately severe",
        8: "Severe pain",
        9: "Very severe pain",
        10: "Worst imaginable"
    ]

    /// DASS-21: Symptom frequency
    static let dassLabels: [Int: String] = [
        1: "Did not apply",
        2: "Did not apply",
        3: "Applied somewhat",
        4: "Applied somewhat",
        5: "Applied somewhat",
        6: "Applied considerably",
        7: "Applied considerably",
        8: "Applied very much",
        9: "Applied very much",
        10: "Applied extremely"
    ]

    /// Stress levels
    static let stressLabels: [Int: String] = [
        1: "No stress",
        2: "Minimal stress",
        3: "Mild stress",
        4: "Mild stress",
        5: "Moderate stress",
        6: "Moderate stress",
        7: "High stress",
        8: "Very high stress",
        9: "Severe stress",
        10: "Extreme stress"
    ]

    /// Noise levels
    static let noiseLabels: [Int: String] = [
        1: "Very quiet",
        2: "Quiet",
        3: "Mostly quiet",
        4: "Some noise",
        5: "Moderate noise",
        6: "Fairly noisy",
        7: "Noisy",
        8: "Very noisy",
        9: "Extremely noisy",
        10: "Unbearably noisy"
    ]

    /// Tiredness levels
    static let tirednessLabels: [Int: String] = [
        1: "Not tired at all",
        2: "Barely tired",
        3: "Slightly tired",
        4: "Somewhat tired",
        5: "Moderately tired",
        6: "Fairly tired",
        7: "Tired",
        8: "Very tired",
        9: "Extremely tired",
        10: "Exhausted"
    ]

    /// Generic negative labels
    static let negativeLabels: [Int: String] = [
        1: "Not at all",
        2: "Minimal",
        3: "Mild",
        4: "Mild",
        5: "Moderate",
        6: "Moderate",
        7: "Considerable",
        8: "Severe",
        9: "Very severe",
        10: "Extreme"
    ]

    // ========== NEUTRAL SCALE LABELS ==========

    static let neutralLabels: [Int: String] = [
        1: "Very low",
        2: "Low",
        3: "Below average",
        4: "Slightly below average",
        5: "Average",
        6: "Average",
        7: "Slightly above average",
        8: "Above average",
        9: "High",
        10: "Very high"
    ]

    // MARK: - ISI Question-Specific Labels

    private static func getISILabel(displayValue: Int, questionId: String) -> String {
        let id = questionId.uppercased()
        let numberPart = id.replacingOccurrences(of: "ISI_", with: "")
                          .replacingOccurrences(of: "ISI-", with: "")

        guard let questionNumber = Int(numberPart) else {
            return isiSeverityLabels[displayValue] ?? ""
        }

        switch questionNumber {
        case 1, 2, 3:
            return isiSeverityLabels[displayValue] ?? ""
        case 4:
            return satisfactionLabels[displayValue] ?? ""
        case 5:
            return isiInterferenceLabels[displayValue] ?? ""
        case 6:
            return isiNoticeableLabels[displayValue] ?? ""
        case 7:
            return isiWorriedLabels[displayValue] ?? ""
        default:
            return isiSeverityLabels[displayValue] ?? ""
        }
    }

    /// ISI Items 1-3: Severity
    static let isiSeverityLabels: [Int: String] = [
        1: "None",
        2: "None",
        3: "Mild",
        4: "Mild",
        5: "Moderate",
        6: "Moderate",
        7: "Severe",
        8: "Severe",
        9: "Very severe",
        10: "Very severe"
    ]

    /// ISI Item 5: Interference
    static let isiInterferenceLabels: [Int: String] = [
        1: "Not at all",
        2: "Not at all",
        3: "A little",
        4: "A little",
        5: "Somewhat",
        6: "Somewhat",
        7: "Much",
        8: "Much",
        9: "Very much",
        10: "Very much"
    ]

    /// ISI Item 6: Noticeable
    static let isiNoticeableLabels: [Int: String] = [
        1: "Not at all",
        2: "Barely",
        3: "A little",
        4: "A little",
        5: "Somewhat",
        6: "Somewhat",
        7: "Much",
        8: "Much",
        9: "Very much",
        10: "Extremely"
    ]

    /// ISI Item 7: Worried
    static let isiWorriedLabels: [Int: String] = [
        1: "Not at all",
        2: "Not at all",
        3: "A little",
        4: "A little",
        5: "Somewhat",
        6: "Somewhat",
        7: "Much",
        8: "Much",
        9: "Very much",
        10: "Extremely"
    ]
}
