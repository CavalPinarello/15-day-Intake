//
//  ClinicalScoringTests.swift
//  ZoeSleepTests
//
//  Tests for clinical questionnaire scoring (ISI, PHQ-9, GAD-7, ESS, STOP-BANG)
//

import XCTest
@testable import ZoeSleep

final class ClinicalScoringTests: XCTestCase {

    // MARK: - ISI (Insomnia Severity Index) Tests

    func testISIScoring_None() {
        // Score 0-7: No clinically significant insomnia
        let responses = [
            "ISI_1": 1, "ISI_2": 1, "ISI_3": 1, "ISI_4": 1,
            "ISI_5": 1, "ISI_6": 0, "ISI_7": 1
        ] // Total: 6

        let score = calculateISI(responses: responses)

        XCTAssertEqual(score.total, 6)
        XCTAssertEqual(score.severity, "none")
        XCTAssertTrue(score.interpretation.contains("No clinically significant"))
    }

    func testISIScoring_Mild() {
        // Score 8-14: Subthreshold insomnia
        let responses = [
            "ISI_1": 2, "ISI_2": 2, "ISI_3": 1, "ISI_4": 2,
            "ISI_5": 2, "ISI_6": 1, "ISI_7": 2
        ] // Total: 12

        let score = calculateISI(responses: responses)

        XCTAssertEqual(score.total, 12)
        XCTAssertEqual(score.severity, "mild")
        XCTAssertTrue(score.interpretation.contains("Subthreshold"))
    }

    func testISIScoring_Moderate() {
        // Score 15-21: Clinical insomnia (moderate)
        let responses = [
            "ISI_1": 3, "ISI_2": 3, "ISI_3": 2, "ISI_4": 3,
            "ISI_5": 3, "ISI_6": 2, "ISI_7": 2
        ] // Total: 18

        let score = calculateISI(responses: responses)

        XCTAssertEqual(score.total, 18)
        XCTAssertEqual(score.severity, "moderate")
        XCTAssertTrue(score.interpretation.lowercased().contains("moderate"))
    }

    func testISIScoring_Severe() {
        // Score 22-28: Clinical insomnia (severe)
        let responses = [
            "ISI_1": 4, "ISI_2": 4, "ISI_3": 3, "ISI_4": 3,
            "ISI_5": 4, "ISI_6": 3, "ISI_7": 3
        ] // Total: 24

        let score = calculateISI(responses: responses)

        XCTAssertEqual(score.total, 24)
        XCTAssertEqual(score.severity, "severe")
        XCTAssertTrue(score.interpretation.lowercased().contains("severe"))
    }

    func testISIScoring_MaxScore() {
        let responses = [
            "ISI_1": 4, "ISI_2": 4, "ISI_3": 4, "ISI_4": 4,
            "ISI_5": 4, "ISI_6": 4, "ISI_7": 4
        ] // Total: 28

        let score = calculateISI(responses: responses)

        XCTAssertEqual(score.total, 28)
        XCTAssertEqual(score.maxScore, 28)
    }

    func testISIScoring_MinScore() {
        let responses = [
            "ISI_1": 0, "ISI_2": 0, "ISI_3": 0, "ISI_4": 0,
            "ISI_5": 0, "ISI_6": 0, "ISI_7": 0
        ]

        let score = calculateISI(responses: responses)

        XCTAssertEqual(score.total, 0)
    }

    func testISIScoring_Prorated() {
        // With only 5 questions answered, should prorate
        let responses = [
            "ISI_1": 3, "ISI_2": 2, "ISI_3": 3, "ISI_4": 2, "ISI_5": 3
        ] // Total: 13, prorated to 13 * 7/5 = 18.2 ≈ 18

        let score = calculateISI(responses: responses, prorate: true)

        XCTAssertGreaterThan(score.total, 13)
        XCTAssertTrue(score.isProrated)
    }

    // MARK: - PHQ-9 (Depression) Tests

    func testPHQ9Scoring_Minimal() {
        // Score 0-4: Minimal depression
        let responses = [
            "PHQ9_1": 0, "PHQ9_2": 1, "PHQ9_3": 0, "PHQ9_4": 1,
            "PHQ9_5": 0, "PHQ9_6": 0, "PHQ9_7": 0, "PHQ9_8": 0, "PHQ9_9": 0
        ] // Total: 2

        let score = calculatePHQ9(responses: responses)

        XCTAssertEqual(score.total, 2)
        XCTAssertEqual(score.severity, "minimal")
    }

    func testPHQ9Scoring_Mild() {
        // Score 5-9: Mild depression
        let responses = [
            "PHQ9_1": 1, "PHQ9_2": 1, "PHQ9_3": 1, "PHQ9_4": 1,
            "PHQ9_5": 1, "PHQ9_6": 1, "PHQ9_7": 1, "PHQ9_8": 0, "PHQ9_9": 0
        ] // Total: 7

        let score = calculatePHQ9(responses: responses)

        XCTAssertEqual(score.total, 7)
        XCTAssertEqual(score.severity, "mild")
    }

    func testPHQ9Scoring_Moderate() {
        // Score 10-14: Moderate depression
        let responses = [
            "PHQ9_1": 2, "PHQ9_2": 2, "PHQ9_3": 1, "PHQ9_4": 1,
            "PHQ9_5": 1, "PHQ9_6": 1, "PHQ9_7": 1, "PHQ9_8": 1, "PHQ9_9": 1
        ] // Total: 11

        let score = calculatePHQ9(responses: responses)

        XCTAssertEqual(score.total, 11)
        XCTAssertEqual(score.severity, "moderate")
    }

    func testPHQ9Scoring_ModeratelySevere() {
        // Score 15-19: Moderately severe depression
        let responses = [
            "PHQ9_1": 2, "PHQ9_2": 2, "PHQ9_3": 2, "PHQ9_4": 2,
            "PHQ9_5": 2, "PHQ9_6": 2, "PHQ9_7": 2, "PHQ9_8": 1, "PHQ9_9": 1
        ] // Total: 16

        let score = calculatePHQ9(responses: responses)

        XCTAssertEqual(score.total, 16)
        XCTAssertEqual(score.severity, "moderately_severe")
    }

    func testPHQ9Scoring_Severe() {
        // Score 20-27: Severe depression
        let responses = [
            "PHQ9_1": 3, "PHQ9_2": 3, "PHQ9_3": 2, "PHQ9_4": 2,
            "PHQ9_5": 2, "PHQ9_6": 2, "PHQ9_7": 2, "PHQ9_8": 2, "PHQ9_9": 2
        ] // Total: 20

        let score = calculatePHQ9(responses: responses)

        XCTAssertEqual(score.total, 20)
        XCTAssertEqual(score.severity, "severe")
    }

    func testPHQ9_Question9_SuicidalIdeation() {
        // Question 9 asks about suicidal ideation - any non-zero requires follow-up
        let responses = [
            "PHQ9_1": 0, "PHQ9_2": 0, "PHQ9_3": 0, "PHQ9_4": 0,
            "PHQ9_5": 0, "PHQ9_6": 0, "PHQ9_7": 0, "PHQ9_8": 0, "PHQ9_9": 1
        ]

        let score = calculatePHQ9(responses: responses)

        XCTAssertTrue(score.requiresSafetyAssessment, "Non-zero Q9 should flag safety assessment")
    }

    // MARK: - GAD-7 (Anxiety) Tests

    func testGAD7Scoring_Minimal() {
        // Score 0-4: Minimal anxiety
        let responses = [
            "GAD7_1": 0, "GAD7_2": 1, "GAD7_3": 0, "GAD7_4": 1,
            "GAD7_5": 0, "GAD7_6": 0, "GAD7_7": 0
        ] // Total: 2

        let score = calculateGAD7(responses: responses)

        XCTAssertEqual(score.total, 2)
        XCTAssertEqual(score.severity, "minimal")
    }

    func testGAD7Scoring_Mild() {
        // Score 5-9: Mild anxiety
        let responses = [
            "GAD7_1": 1, "GAD7_2": 1, "GAD7_3": 1, "GAD7_4": 1,
            "GAD7_5": 1, "GAD7_6": 1, "GAD7_7": 1
        ] // Total: 7

        let score = calculateGAD7(responses: responses)

        XCTAssertEqual(score.total, 7)
        XCTAssertEqual(score.severity, "mild")
    }

    func testGAD7Scoring_Moderate() {
        // Score 10-14: Moderate anxiety
        let responses = [
            "GAD7_1": 2, "GAD7_2": 2, "GAD7_3": 2, "GAD7_4": 2,
            "GAD7_5": 1, "GAD7_6": 1, "GAD7_7": 1
        ] // Total: 11

        let score = calculateGAD7(responses: responses)

        XCTAssertEqual(score.total, 11)
        XCTAssertEqual(score.severity, "moderate")
    }

    func testGAD7Scoring_Severe() {
        // Score 15-21: Severe anxiety
        let responses = [
            "GAD7_1": 3, "GAD7_2": 3, "GAD7_3": 2, "GAD7_4": 2,
            "GAD7_5": 2, "GAD7_6": 2, "GAD7_7": 2
        ] // Total: 16

        let score = calculateGAD7(responses: responses)

        XCTAssertEqual(score.total, 16)
        XCTAssertEqual(score.severity, "severe")
    }

    // MARK: - ESS (Epworth Sleepiness Scale) Tests

    func testESSScoring_Normal() {
        // Score 0-10: Normal daytime sleepiness
        let responses = [
            "ESS_1": 1, "ESS_2": 1, "ESS_3": 1, "ESS_4": 1,
            "ESS_5": 1, "ESS_6": 0, "ESS_7": 0, "ESS_8": 1
        ] // Total: 6

        let score = calculateESS(responses: responses)

        XCTAssertEqual(score.total, 6)
        XCTAssertEqual(score.severity, "normal")
    }

    func testESSScoring_MildEDS() {
        // Score 11-14: Mild excessive daytime sleepiness
        let responses = [
            "ESS_1": 2, "ESS_2": 2, "ESS_3": 1, "ESS_4": 1,
            "ESS_5": 2, "ESS_6": 1, "ESS_7": 1, "ESS_8": 2
        ] // Total: 12

        let score = calculateESS(responses: responses)

        XCTAssertEqual(score.total, 12)
        XCTAssertEqual(score.severity, "mild")
    }

    func testESSScoring_ModerateEDS() {
        // Score 15-18: Moderate EDS
        let responses = [
            "ESS_1": 2, "ESS_2": 2, "ESS_3": 2, "ESS_4": 2,
            "ESS_5": 2, "ESS_6": 2, "ESS_7": 2, "ESS_8": 2
        ] // Total: 16

        let score = calculateESS(responses: responses)

        XCTAssertEqual(score.total, 16)
        XCTAssertEqual(score.severity, "moderate")
    }

    func testESSScoring_SevereEDS() {
        // Score 19-24: Severe EDS
        let responses = [
            "ESS_1": 3, "ESS_2": 3, "ESS_3": 3, "ESS_4": 2,
            "ESS_5": 3, "ESS_6": 2, "ESS_7": 2, "ESS_8": 3
        ] // Total: 21

        let score = calculateESS(responses: responses)

        XCTAssertEqual(score.total, 21)
        XCTAssertEqual(score.severity, "severe")
    }

    // MARK: - STOP-BANG (OSA Screening) Tests

    func testSTOPBANGScoring_LowRisk() {
        // Score 0-2: Low risk of OSA
        let responses = [
            "SB_1": "No", "SB_2": "No", "SB_3": "No", "SB_4": "Yes",
            "SB_5": "No", "SB_6": "No", "SB_7": "No", "SB_8": "Yes"
        ] // Total: 2

        let score = calculateSTOPBANG(responses: responses)

        XCTAssertEqual(score.total, 2)
        XCTAssertEqual(score.riskLevel, "low")
    }

    func testSTOPBANGScoring_IntermediateRisk() {
        // Score 3-4: Intermediate risk
        let responses = [
            "SB_1": "Yes", "SB_2": "Yes", "SB_3": "No", "SB_4": "Yes",
            "SB_5": "No", "SB_6": "No", "SB_7": "No", "SB_8": "Yes"
        ] // Total: 4

        let score = calculateSTOPBANG(responses: responses)

        XCTAssertEqual(score.total, 4)
        XCTAssertEqual(score.riskLevel, "intermediate")
    }

    func testSTOPBANGScoring_HighRisk() {
        // Score 5-8: High risk
        let responses = [
            "SB_1": "Yes", "SB_2": "Yes", "SB_3": "Yes", "SB_4": "Yes",
            "SB_5": "Yes", "SB_6": "Yes", "SB_7": "No", "SB_8": "Yes"
        ] // Total: 7

        let score = calculateSTOPBANG(responses: responses)

        XCTAssertEqual(score.total, 7)
        XCTAssertEqual(score.riskLevel, "high")
    }

    func testSTOPBANGScoring_YesNoConversion() {
        // Verify Yes = 1, No = 0
        let responses = [
            "SB_1": "Yes", "SB_2": "No", "SB_3": "Yes", "SB_4": "No",
            "SB_5": "Yes", "SB_6": "No", "SB_7": "Yes", "SB_8": "No"
        ]

        let score = calculateSTOPBANG(responses: responses)

        XCTAssertEqual(score.total, 4)
    }

    // MARK: - Scoring Helper Functions

    private struct ISIScore {
        let total: Int
        let maxScore: Int
        let severity: String
        let interpretation: String
        let isProrated: Bool
    }

    private func calculateISI(responses: [String: Int], prorate: Bool = false) -> ISIScore {
        var total = 0
        var answered = 0

        for i in 1...7 {
            if let value = responses["ISI_\(i)"] {
                total += value
                answered += 1
            }
        }

        // Prorate if needed
        var finalTotal = total
        var isProrated = false
        if prorate && answered >= 5 && answered < 7 {
            finalTotal = Int(round(Double(total) * 7.0 / Double(answered)))
            isProrated = true
        }

        let severity: String
        let interpretation: String

        switch finalTotal {
        case 0...7:
            severity = "none"
            interpretation = "No clinically significant insomnia"
        case 8...14:
            severity = "mild"
            interpretation = "Subthreshold insomnia"
        case 15...21:
            severity = "moderate"
            interpretation = "Clinical insomnia (moderate)"
        default:
            severity = "severe"
            interpretation = "Clinical insomnia (severe)"
        }

        return ISIScore(total: finalTotal, maxScore: 28, severity: severity, interpretation: interpretation, isProrated: isProrated)
    }

    private struct PHQ9Score {
        let total: Int
        let severity: String
        let requiresSafetyAssessment: Bool
    }

    private func calculatePHQ9(responses: [String: Int]) -> PHQ9Score {
        var total = 0
        var q9Value = 0

        for i in 1...9 {
            if let value = responses["PHQ9_\(i)"] {
                total += value
                if i == 9 {
                    q9Value = value
                }
            }
        }

        let severity: String
        switch total {
        case 0...4:
            severity = "minimal"
        case 5...9:
            severity = "mild"
        case 10...14:
            severity = "moderate"
        case 15...19:
            severity = "moderately_severe"
        default:
            severity = "severe"
        }

        return PHQ9Score(total: total, severity: severity, requiresSafetyAssessment: q9Value > 0)
    }

    private struct GAD7Score {
        let total: Int
        let severity: String
    }

    private func calculateGAD7(responses: [String: Int]) -> GAD7Score {
        var total = 0

        for i in 1...7 {
            if let value = responses["GAD7_\(i)"] {
                total += value
            }
        }

        let severity: String
        switch total {
        case 0...4:
            severity = "minimal"
        case 5...9:
            severity = "mild"
        case 10...14:
            severity = "moderate"
        default:
            severity = "severe"
        }

        return GAD7Score(total: total, severity: severity)
    }

    private struct ESSScore {
        let total: Int
        let severity: String
    }

    private func calculateESS(responses: [String: Int]) -> ESSScore {
        var total = 0

        for i in 1...8 {
            if let value = responses["ESS_\(i)"] {
                total += value
            }
        }

        let severity: String
        switch total {
        case 0...10:
            severity = "normal"
        case 11...14:
            severity = "mild"
        case 15...18:
            severity = "moderate"
        default:
            severity = "severe"
        }

        return ESSScore(total: total, severity: severity)
    }

    private struct STOPBANGScore {
        let total: Int
        let riskLevel: String
    }

    private func calculateSTOPBANG(responses: [String: String]) -> STOPBANGScore {
        var total = 0

        for i in 1...8 {
            if let value = responses["SB_\(i)"], value.lowercased() == "yes" {
                total += 1
            }
        }

        let riskLevel: String
        switch total {
        case 0...2:
            riskLevel = "low"
        case 3...4:
            riskLevel = "intermediate"
        default:
            riskLevel = "high"
        }

        return STOPBANGScore(total: total, riskLevel: riskLevel)
    }
}
