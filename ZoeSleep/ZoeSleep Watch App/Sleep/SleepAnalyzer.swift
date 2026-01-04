//
//  SleepAnalyzer.swift
//  ZoeSleep Watch App
//
//  Comprehensive sleep analysis with chronotype-aware scoring.
//  Analyzes architecture, timing, continuity, and recovery.
//

import Foundation
import SwiftUI

// MARK: - Sleep Analyzer

@MainActor
class SleepAnalyzer: ObservableObject {
    static let shared = SleepAnalyzer()

    private let chronotypeManager = ChronotypeManager.shared

    private init() {}

    // MARK: - Full Analysis

    /// Perform comprehensive sleep analysis
    func analyzeSleepSession(
        _ session: SleepSession,
        historicalSessions: [SleepSession] = []
    ) -> SleepAnalysis {
        let chronotype = chronotypeManager.chronotype

        // Calculate individual scores
        let architectureScore = calculateArchitectureScore(session, chronotype: chronotype)
        let timingScore = calculateTimingScore(session, chronotype: chronotype)
        let continuityScore = calculateContinuityScore(session)
        let durationScore = calculateDurationScore(session, chronotype: chronotype)
        let recoveryScore = calculateRecoveryScore(session)

        // Weighted overall score
        let overallScore = Int(
            Double(architectureScore) * 0.25 +
            Double(timingScore) * 0.25 +
            Double(continuityScore) * 0.20 +
            Double(durationScore) * 0.15 +
            Double(recoveryScore) * 0.15
        )

        // Calculate alignment metrics
        let optimalWindow = chronotypeManager.getOptimalSleepWindow(for: session.bedtime)
        let bedtimeDeviation = optimalWindow.bedtimeDeviation(from: session.bedtime)

        let wakeDeviation = calculateWakeTimeDeviation(session.wakeTime, chronotype: chronotype)
        let isWithinOptimalWindow = abs(bedtimeDeviation) < 3600 && abs(wakeDeviation) < 3600  // Within 1 hour

        // Rate sleep stage quality
        let deepSleepQuality = rateDeepSleepQuality(session, chronotype: chronotype)
        let remQuality = rateREMQuality(session, chronotype: chronotype)
        let lightSleepQuality = rateLightSleepQuality(session)

        // Calculate trends if we have history
        let (deepTrend, remTrend, efficiencyTrend, scoreTrend) = calculateTrends(
            session,
            historical: historicalSessions
        )

        // Generate insights
        let insights = generateInsights(
            session: session,
            chronotype: chronotype,
            architectureScore: architectureScore,
            timingScore: timingScore,
            continuityScore: continuityScore
        )

        // Generate recommendations
        let recommendations = generateRecommendations(
            session: session,
            chronotype: chronotype,
            insights: insights,
            timingScore: timingScore
        )

        return SleepAnalysis(
            session: session,
            chronotype: chronotype,
            overallScore: overallScore,
            architectureScore: architectureScore,
            timingScore: timingScore,
            continuityScore: continuityScore,
            durationScore: durationScore,
            recoveryScore: recoveryScore,
            insights: insights,
            recommendations: recommendations,
            bedtimeDeviation: bedtimeDeviation,
            wakeTimeDeviation: wakeDeviation,
            isWithinOptimalWindow: isWithinOptimalWindow,
            deepSleepQuality: deepSleepQuality,
            remQuality: remQuality,
            lightSleepQuality: lightSleepQuality,
            deepSleepTrend: deepTrend,
            remTrend: remTrend,
            efficiencyTrend: efficiencyTrend,
            scoreTrend: scoreTrend
        )
    }

    // MARK: - Architecture Score

    /// Score based on sleep stage composition
    private func calculateArchitectureScore(_ session: SleepSession, chronotype: Chronotype) -> Int {
        let percentages = session.stagePercentages

        let deepPercent = percentages[.deep] ?? 0
        let remPercent = percentages[.rem] ?? 0
        let lightPercent = percentages[.light] ?? 0
        let awakePercent = percentages[.awake] ?? 0

        var score: Double = 100

        // Deep sleep scoring (optimal: 13-23% depending on chronotype)
        let expectedDeep = chronotype.expectedDeepPercent
        if deepPercent < expectedDeep.lowerBound {
            let deficit = expectedDeep.lowerBound - deepPercent
            score -= deficit * 200  // Penalize low deep sleep heavily
        } else if deepPercent > expectedDeep.upperBound {
            // Slightly too much deep is OK
            let excess = deepPercent - expectedDeep.upperBound
            score -= excess * 50
        }

        // REM scoring (optimal: 20-25%)
        let expectedREM = chronotype.expectedREMPercent
        if remPercent < expectedREM.lowerBound {
            let deficit = expectedREM.lowerBound - remPercent
            score -= deficit * 150
        } else if remPercent > expectedREM.upperBound {
            let excess = remPercent - expectedREM.upperBound
            score -= excess * 30
        }

        // Light sleep (optimal: 50-55%)
        let optimalLight = 0.50...0.55
        if lightPercent < optimalLight.lowerBound {
            let deficit = optimalLight.lowerBound - lightPercent
            score -= deficit * 50
        } else if lightPercent > 0.65 {
            // Too much light sleep = not enough deep/REM
            score -= (lightPercent - 0.65) * 100
        }

        // Awake time penalty
        if awakePercent > 0.05 {
            score -= (awakePercent - 0.05) * 200
        }

        // Deep sleep timing bonus (should occur in first half of night)
        if let timeToDeep = session.timeToFirstDeep {
            if timeToDeep < 1800 {  // Within 30 minutes
                score += 5
            } else if timeToDeep > 5400 {  // After 90 minutes
                score -= 10
            }
        }

        // Sleep cycles bonus (4-6 is optimal)
        let cycles = session.sleepCycles
        if cycles >= 4 && cycles <= 6 {
            score += 5
        } else if cycles < 3 {
            score -= 10
        }

        return max(0, min(100, Int(score)))
    }

    // MARK: - Timing Score

    /// Score based on circadian alignment with chronotype
    private func calculateTimingScore(_ session: SleepSession, chronotype: Chronotype) -> Int {
        var score: Double = 100

        let optimalWindow = chronotypeManager.getOptimalSleepWindow(for: session.bedtime)

        // Bedtime deviation (in hours)
        let bedtimeDeviationHours = abs(optimalWindow.bedtimeDeviation(from: session.bedtime)) / 3600

        // Score bedtime alignment
        if bedtimeDeviationHours <= 0.5 {
            // Within 30 min - excellent
            score += 5
        } else if bedtimeDeviationHours <= 1.0 {
            // Within 1 hour - good
            score -= 5
        } else if bedtimeDeviationHours <= 2.0 {
            // Within 2 hours - fair
            score -= 20
        } else {
            // More than 2 hours off
            score -= 40 + (bedtimeDeviationHours - 2) * 10
        }

        // Wake time deviation
        let wakeDeviationHours = abs(calculateWakeTimeDeviation(session.wakeTime, chronotype: chronotype)) / 3600

        if wakeDeviationHours <= 0.5 {
            score += 5
        } else if wakeDeviationHours <= 1.0 {
            score -= 5
        } else if wakeDeviationHours <= 2.0 {
            score -= 15
        } else {
            score -= 30 + (wakeDeviationHours - 2) * 10
        }

        // Sleep midpoint alignment (key circadian indicator)
        let midpoint = session.bedtime.addingTimeInterval(session.totalDuration / 2)
        let calendar = Calendar.current
        let midpointHour = Double(calendar.component(.hour, from: midpoint)) +
                          Double(calendar.component(.minute, from: midpoint)) / 60.0

        // Optimal midpoint varies by chronotype
        let optimalMidpoint: Double
        switch chronotype {
        case .earlyRiser: optimalMidpoint = 1.5  // 1:30 AM
        case .balanced: optimalMidpoint = 3.0    // 3:00 AM
        case .nightOwl: optimalMidpoint = 4.0    // 4:00 AM
        }

        var midpointDeviation = abs(midpointHour - optimalMidpoint)
        if midpointDeviation > 12 { midpointDeviation = 24 - midpointDeviation }

        if midpointDeviation <= 0.5 {
            score += 10  // Bonus for perfect midpoint
        } else if midpointDeviation > 2 {
            score -= midpointDeviation * 10
        }

        return max(0, min(100, Int(score)))
    }

    private func calculateWakeTimeDeviation(_ wakeTime: Date, chronotype: Chronotype) -> TimeInterval {
        let calendar = Calendar.current
        let wakeHour = Double(calendar.component(.hour, from: wakeTime))
        let wakeMinute = Double(calendar.component(.minute, from: wakeTime))
        let actualWake = wakeHour + wakeMinute / 60.0

        var deviation = actualWake - chronotype.optimalWakeTime
        if deviation > 12 { deviation -= 24 }
        if deviation < -12 { deviation += 24 }

        return deviation * 3600
    }

    // MARK: - Continuity Score

    /// Score based on sleep fragmentation
    private func calculateContinuityScore(_ session: SleepSession) -> Int {
        var score: Double = 100

        // Awakenings penalty
        let awakenings = session.awakenings
        if awakenings == 0 {
            score += 10  // Perfect continuity bonus
        } else if awakenings <= 2 {
            score -= Double(awakenings) * 5.0
        } else if awakenings <= 5 {
            score -= 10.0 + Double(awakenings - 2) * 8.0
        } else {
            score -= 34.0 + Double(awakenings - 5) * 10.0
        }

        // Sleep efficiency
        let efficiency = session.sleepEfficiency
        if efficiency >= 0.90 {
            score += 10
        } else if efficiency >= 0.85 {
            // Good
        } else if efficiency >= 0.80 {
            score -= 10
        } else if efficiency >= 0.75 {
            score -= 20
        } else {
            score -= 30 + (0.75 - efficiency) * 100
        }

        // Sleep onset latency
        let latencyMinutes = session.sleepOnsetLatency / 60
        if latencyMinutes <= 10 {
            score += 5  // Falls asleep quickly
        } else if latencyMinutes <= 20 {
            // Normal
        } else if latencyMinutes <= 30 {
            score -= 10
        } else {
            score -= 20 + (latencyMinutes - 30) * 0.5
        }

        return max(0, min(100, Int(score)))
    }

    // MARK: - Duration Score

    /// Score based on adequate sleep duration for chronotype
    private func calculateDurationScore(_ session: SleepSession, chronotype: Chronotype) -> Int {
        let duration = session.totalDurationHours
        let ideal = chronotype.idealSleepDuration

        var score: Double = 100

        let deviation = abs(duration - ideal)

        if deviation <= 0.25 {
            score += 10  // Perfect duration
        } else if deviation <= 0.5 {
            score -= 5
        } else if deviation <= 1.0 {
            score -= 15
        } else if deviation <= 1.5 {
            score -= 30
        } else {
            score -= 45 + (deviation - 1.5) * 15
        }

        // Severe undersleep penalty
        if duration < 5 {
            score -= 30
        } else if duration < 6 {
            score -= 15
        }

        // Oversleep penalty (can indicate issues)
        if duration > 10 {
            score -= 20
        } else if duration > 9 {
            score -= 10
        }

        return max(0, min(100, Int(score)))
    }

    // MARK: - Recovery Score

    /// Score based on physiological recovery indicators
    private func calculateRecoveryScore(_ session: SleepSession) -> Int {
        var score: Double = 70  // Base score without physiological data

        // HRV (Heart Rate Variability) - higher is better
        if let hrv = session.hrv {
            if hrv >= 50 {
                score += 15
            } else if hrv >= 40 {
                score += 10
            } else if hrv >= 30 {
                score += 5
            } else if hrv < 20 {
                score -= 10
            }
        }

        // Resting heart rate during sleep
        if let hrData = session.heartRateData, !hrData.isEmpty {
            let avgHR = hrData.map { $0.bpm }.reduce(0, +) / hrData.count
            let minHR = hrData.map { $0.bpm }.min() ?? avgHR

            // Lower resting HR during sleep = better recovery
            if minHR < 50 {
                score += 10
            } else if minHR < 60 {
                score += 5
            } else if minHR > 70 {
                score -= 10
            }
        }

        // Blood oxygen
        if let oxygen = session.bloodOxygen {
            if oxygen >= 95 {
                score += 5
            } else if oxygen < 90 {
                score -= 20  // Potential sleep apnea indicator
            }
        }

        // Movement during sleep
        if let movement = session.movementScore {
            if movement < 0.2 {
                score += 5  // Very still = deep rest
            } else if movement > 0.5 {
                score -= 10  // Restless
            }
        }

        // Respiratory rate
        if let respRate = session.respiratoryRate {
            if respRate >= 12 && respRate <= 16 {
                score += 5  // Normal range
            } else if respRate < 10 || respRate > 20 {
                score -= 10
            }
        }

        return max(0, min(100, Int(score)))
    }

    // MARK: - Quality Ratings

    private func rateDeepSleepQuality(_ session: SleepSession, chronotype: Chronotype) -> SleepQualityRating {
        let deepPercent = session.stagePercentages[.deep] ?? 0
        let expected = chronotype.expectedDeepPercent

        if deepPercent >= expected.upperBound {
            return .excellent
        } else if deepPercent >= expected.lowerBound {
            return .good
        } else if deepPercent >= expected.lowerBound * 0.7 {
            return .fair
        } else if deepPercent >= expected.lowerBound * 0.5 {
            return .low
        } else {
            return .veryLow
        }
    }

    private func rateREMQuality(_ session: SleepSession, chronotype: Chronotype) -> SleepQualityRating {
        let remPercent = session.stagePercentages[.rem] ?? 0
        let expected = chronotype.expectedREMPercent

        if remPercent >= expected.upperBound {
            return .excellent
        } else if remPercent >= expected.lowerBound {
            return .good
        } else if remPercent >= expected.lowerBound * 0.7 {
            return .fair
        } else if remPercent >= expected.lowerBound * 0.5 {
            return .low
        } else {
            return .veryLow
        }
    }

    private func rateLightSleepQuality(_ session: SleepSession) -> SleepQualityRating {
        let lightPercent = session.stagePercentages[.light] ?? 0

        // Light sleep should be 45-60%
        if lightPercent >= 0.45 && lightPercent <= 0.55 {
            return .excellent
        } else if lightPercent >= 0.40 && lightPercent <= 0.60 {
            return .good
        } else if lightPercent >= 0.35 && lightPercent <= 0.65 {
            return .fair
        } else {
            return .low
        }
    }

    // MARK: - Trends

    private func calculateTrends(
        _ current: SleepSession,
        historical: [SleepSession]
    ) -> (TrendDirection, TrendDirection, TrendDirection, TrendDirection) {
        guard historical.count >= 3 else {
            return (.stable, .stable, .stable, .stable)
        }

        // Get last 7 days average
        let recentSessions = historical.suffix(7)

        let avgDeep = recentSessions.compactMap { $0.stagePercentages[.deep] }.reduce(0, +) / Double(recentSessions.count)
        let avgREM = recentSessions.compactMap { $0.stagePercentages[.rem] }.reduce(0, +) / Double(recentSessions.count)
        let avgEfficiency = recentSessions.map { $0.sleepEfficiency }.reduce(0, +) / Double(recentSessions.count)

        let currentDeep = current.stagePercentages[.deep] ?? 0
        let currentREM = current.stagePercentages[.rem] ?? 0
        let currentEfficiency = current.sleepEfficiency

        func determineTrend(_ current: Double, _ average: Double, threshold: Double = 0.02) -> TrendDirection {
            let diff = current - average
            if diff > threshold { return .improving }
            if diff < -threshold { return .declining }
            return .stable
        }

        return (
            determineTrend(currentDeep, avgDeep),
            determineTrend(currentREM, avgREM),
            determineTrend(currentEfficiency, avgEfficiency, threshold: 0.03),
            .stable  // Score trend needs historical scores
        )
    }

    // MARK: - Insights Generation

    private func generateInsights(
        session: SleepSession,
        chronotype: Chronotype,
        architectureScore: Int,
        timingScore: Int,
        continuityScore: Int
    ) -> [SleepInsight] {
        var insights: [SleepInsight] = []

        let percentages = session.stagePercentages

        // Deep sleep insights
        let deepPercent = percentages[.deep] ?? 0
        if deepPercent >= chronotype.expectedDeepPercent.upperBound {
            insights.append(SleepInsight(
                type: .positive,
                title: "Excellent Deep Sleep",
                description: "Your deep sleep was above optimal at \(Int(deepPercent * 100))%. Great physical recovery!",
                severity: .low,
                relatedMetric: "Deep: \(Int(deepPercent * 100))%"
            ))
        } else if deepPercent < chronotype.expectedDeepPercent.lowerBound * 0.7 {
            insights.append(SleepInsight(
                type: .warning,
                title: "Low Deep Sleep",
                description: "Only \(Int(deepPercent * 100))% deep sleep. This affects physical recovery and immune function.",
                severity: .high,
                relatedMetric: "Deep: \(Int(deepPercent * 100))%"
            ))
        }

        // REM insights
        let remPercent = percentages[.rem] ?? 0
        if remPercent >= chronotype.expectedREMPercent.upperBound {
            insights.append(SleepInsight(
                type: .positive,
                title: "Strong REM Sleep",
                description: "\(Int(remPercent * 100))% REM supports memory consolidation and emotional processing.",
                severity: .low,
                relatedMetric: "REM: \(Int(remPercent * 100))%"
            ))
        } else if remPercent < chronotype.expectedREMPercent.lowerBound * 0.7 {
            insights.append(SleepInsight(
                type: .actionable,
                title: "REM Sleep Below Target",
                description: "Only \(Int(remPercent * 100))% REM. Try avoiding alcohol and maintaining consistent wake times.",
                severity: .medium,
                relatedMetric: "REM: \(Int(remPercent * 100))%"
            ))
        }

        // Timing insights
        if timingScore < 60 {
            let optimalWindow = chronotypeManager.getOptimalSleepWindow()
            insights.append(SleepInsight(
                type: .actionable,
                title: "Sleep Timing Misaligned",
                description: "As a \(chronotype.displayName), your optimal bedtime is \(optimalWindow.formattedBedtimeRange).",
                severity: .medium,
                relatedMetric: "Timing: \(timingScore)/100"
            ))
        } else if timingScore >= 90 {
            insights.append(SleepInsight(
                type: .positive,
                title: "Perfect Circadian Alignment",
                description: "Your sleep timing matches your \(chronotype.displayName) chronotype perfectly!",
                severity: .low,
                relatedMetric: "Timing: \(timingScore)/100"
            ))
        }

        // Continuity insights
        if session.awakenings > 3 {
            insights.append(SleepInsight(
                type: .warning,
                title: "Fragmented Sleep",
                description: "You woke up \(session.awakenings) times. Consider your sleep environment (temperature, noise, light).",
                severity: .medium,
                relatedMetric: "Awakenings: \(session.awakenings)"
            ))
        }

        // Sleep efficiency
        if session.sleepEfficiency >= 0.90 {
            insights.append(SleepInsight(
                type: .positive,
                title: "High Sleep Efficiency",
                description: "\(Int(session.sleepEfficiency * 100))% of time in bed was actual sleep. Excellent!",
                severity: .low,
                relatedMetric: "Efficiency: \(Int(session.sleepEfficiency * 100))%"
            ))
        } else if session.sleepEfficiency < 0.80 {
            insights.append(SleepInsight(
                type: .actionable,
                title: "Low Sleep Efficiency",
                description: "Only \(Int(session.sleepEfficiency * 100))% sleep efficiency. Consider going to bed only when sleepy.",
                severity: .medium,
                relatedMetric: "Efficiency: \(Int(session.sleepEfficiency * 100))%"
            ))
        }

        // Sleep onset
        if session.sleepOnsetLatency > 1800 {  // > 30 min
            insights.append(SleepInsight(
                type: .actionable,
                title: "Slow Sleep Onset",
                description: "Took \(Int(session.sleepOnsetLatency / 60)) min to fall asleep. Wind down routine may help.",
                severity: .medium,
                relatedMetric: "Onset: \(Int(session.sleepOnsetLatency / 60)) min"
            ))
        }

        // Sleep cycles
        if session.sleepCycles >= 5 {
            insights.append(SleepInsight(
                type: .positive,
                title: "Complete Sleep Cycles",
                description: "Achieved \(session.sleepCycles) full sleep cycles - optimal for restoration.",
                severity: .low,
                relatedMetric: "Cycles: \(session.sleepCycles)"
            ))
        } else if session.sleepCycles < 4 {
            insights.append(SleepInsight(
                type: .neutral,
                title: "Fewer Sleep Cycles",
                description: "Only \(session.sleepCycles) cycles detected. May need longer sleep duration.",
                severity: .low,
                relatedMetric: "Cycles: \(session.sleepCycles)"
            ))
        }

        return insights
    }

    // MARK: - Recommendations

    private func generateRecommendations(
        session: SleepSession,
        chronotype: Chronotype,
        insights: [SleepInsight],
        timingScore: Int
    ) -> [SleepRecommendation] {
        var recommendations: [SleepRecommendation] = []

        // Timing recommendation
        if timingScore < 70 {
            let optimalWindow = chronotypeManager.getOptimalSleepWindow()
            recommendations.append(SleepRecommendation(
                category: .timing,
                title: "Adjust Your Bedtime",
                description: "Shift bedtime closer to \(optimalWindow.formattedBedtimeRange) to align with your \(chronotype.displayName) biology.",
                priority: 1,
                actionType: .schedule
            ))
        }

        // Deep sleep recommendations
        if (session.stagePercentages[.deep] ?? 0) < chronotype.expectedDeepPercent.lowerBound {
            recommendations.append(SleepRecommendation(
                category: .habits,
                title: "Boost Deep Sleep",
                description: "Exercise earlier in the day (before 6 PM), keep room cool (65-68°F), and avoid alcohol.",
                priority: 2,
                actionType: .behavior
            ))
        }

        // Continuity recommendations
        if session.awakenings > 3 {
            recommendations.append(SleepRecommendation(
                category: .environment,
                title: "Reduce Night Awakenings",
                description: "Use blackout curtains, white noise, and avoid fluids 2 hours before bed.",
                priority: 2,
                actionType: .environment
            ))
        }

        // Chronotype-specific recommendations
        switch chronotype {
        case .earlyRiser:
            if timingScore < 80 {
                recommendations.append(SleepRecommendation(
                    category: .chronotype,
                    title: "Protect Your Early Schedule",
                    description: "Early Risers thrive on early nights. Decline late evening events when possible.",
                    priority: 3,
                    actionType: .behavior
                ))
            }
        case .nightOwl:
            recommendations.append(SleepRecommendation(
                category: .chronotype,
                title: "Morning Light Therapy",
                description: "Get bright light exposure within 30 min of waking to help shift your rhythm earlier.",
                priority: 3,
                actionType: .behavior
            ))
        case .balanced:
            // Balanced types are most adaptable
            break
        }

        // Sort by priority
        recommendations.sort { $0.priority < $1.priority }

        return recommendations
    }

    // MARK: - Weekly Summary

    func generateWeeklySummary(_ sessions: [SleepSession]) -> WeeklySleepSummary {
        guard !sessions.isEmpty else {
            return createEmptySummary()
        }

        let chronotype = chronotypeManager.chronotype

        // Calculate averages
        let avgDuration = sessions.map { $0.totalDurationHours }.reduce(0, +) / Double(sessions.count)
        let avgEfficiency = sessions.map { $0.sleepEfficiency }.reduce(0, +) / Double(sessions.count)
        let avgDeep = sessions.compactMap { $0.stagePercentages[.deep] }.reduce(0, +) / Double(sessions.count)
        let avgREM = sessions.compactMap { $0.stagePercentages[.rem] }.reduce(0, +) / Double(sessions.count)

        // Calculate scores for each session
        let scores = sessions.map { session in
            analyzeSleepSession(session).overallScore
        }
        let avgScore = scores.reduce(0, +) / scores.count

        // Find best and worst nights
        let sessionsWithScores = zip(sessions, scores).sorted { $0.1 > $1.1 }
        let bestNight = sessionsWithScores.first?.0
        let worstNight = sessionsWithScores.last?.0

        // Calculate sleep debt
        let sleepDebt = calculateSleepDebt(sessions, chronotype: chronotype)

        // Calculate social jetlag
        let socialJetlag = calculateSocialJetlag(sessions)

        // Consistency score
        let consistencyScore = calculateConsistencyScore(sessions)

        // Overall trend
        let trend: TrendDirection
        if sessions.count >= 3 {
            let recentScores = Array(scores.suffix(3))
            let earlyScores = Array(scores.prefix(3))
            let recentAvg = Double(recentScores.reduce(0, +)) / Double(recentScores.count)
            let earlyAvg = Double(earlyScores.reduce(0, +)) / Double(earlyScores.count)

            if recentAvg - earlyAvg > 5 {
                trend = .improving
            } else if earlyAvg - recentAvg > 5 {
                trend = .declining
            } else {
                trend = .stable
            }
        } else {
            trend = .stable
        }

        return WeeklySleepSummary(
            sessions: sessions,
            chronotype: chronotype,
            averageScore: avgScore,
            averageDuration: avgDuration,
            averageEfficiency: avgEfficiency,
            averageDeepPercent: avgDeep,
            averageREMPercent: avgREM,
            bestNight: bestNight,
            worstNight: worstNight,
            sleepDebt: sleepDebt,
            socialJetlag: socialJetlag,
            consistencyScore: consistencyScore,
            overallTrend: trend
        )
    }

    private func calculateSleepDebt(_ sessions: [SleepSession], chronotype: Chronotype) -> SleepDebt {
        let ideal = chronotype.idealSleepDuration
        let idealWeekly = ideal * 7

        let totalSleep = sessions.map { $0.totalDurationHours }.reduce(0, +)
        let expectedTotal = ideal * Double(sessions.count)
        let debt = max(0, expectedTotal - totalSleep)

        let weeklyAverage = sessions.isEmpty ? 0 : totalSleep / Double(sessions.count)
        let daysToRecover = Int(ceil(debt / 0.5))  // 30 min extra per night

        return SleepDebt(
            currentDebtHours: debt,
            weeklyAverage: weeklyAverage,
            idealWeeklyTotal: idealWeekly,
            daysToRecover: daysToRecover,
            recoveryProgress: 0
        )
    }

    private func calculateSocialJetlag(_ sessions: [SleepSession]) -> SocialJetlag {
        let calendar = Calendar.current

        var weekdayMidpoints: [Date] = []
        var weekendMidpoints: [Date] = []

        for session in sessions {
            let midpoint = session.bedtime.addingTimeInterval(session.totalDuration / 2)
            let weekday = calendar.component(.weekday, from: session.bedtime)

            if weekday == 1 || weekday == 7 {
                weekendMidpoints.append(midpoint)
            } else {
                weekdayMidpoints.append(midpoint)
            }
        }

        // Calculate average midpoints
        let avgWeekdayMidpoint = averageTime(weekdayMidpoints) ?? Date()
        let avgWeekendMidpoint = averageTime(weekendMidpoints) ?? Date()

        // Calculate difference in hours
        var jetlagHours = avgWeekendMidpoint.timeIntervalSince(avgWeekdayMidpoint) / 3600
        if jetlagHours > 12 { jetlagHours -= 24 }
        if jetlagHours < -12 { jetlagHours += 24 }

        return SocialJetlag(
            weekdayMidpoint: avgWeekdayMidpoint,
            weekendMidpoint: avgWeekendMidpoint,
            jetlagHours: jetlagHours
        )
    }

    private func averageTime(_ dates: [Date]) -> Date? {
        guard !dates.isEmpty else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var totalMinutes: Int = 0
        for date in dates {
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            var minutes = hour * 60 + minute
            if minutes < 12 * 60 { minutes += 24 * 60 }  // Handle past midnight
            totalMinutes += minutes
        }

        let avgMinutes = totalMinutes / dates.count
        let normalizedMinutes = avgMinutes % (24 * 60)

        return calendar.date(
            bySettingHour: normalizedMinutes / 60,
            minute: normalizedMinutes % 60,
            second: 0,
            of: today
        )
    }

    private func calculateConsistencyScore(_ sessions: [SleepSession]) -> Int {
        guard sessions.count >= 3 else { return 50 }

        let calendar = Calendar.current

        // Extract bedtimes and wake times
        var bedtimeMinutes: [Int] = []
        var wakeMinutes: [Int] = []

        for session in sessions {
            let bedHour = calendar.component(.hour, from: session.bedtime)
            let bedMin = calendar.component(.minute, from: session.bedtime)
            var bedTotal = bedHour * 60 + bedMin
            if bedTotal < 12 * 60 { bedTotal += 24 * 60 }
            bedtimeMinutes.append(bedTotal)

            let wakeHour = calendar.component(.hour, from: session.wakeTime)
            let wakeMin = calendar.component(.minute, from: session.wakeTime)
            wakeMinutes.append(wakeHour * 60 + wakeMin)
        }

        // Calculate standard deviation
        let bedtimeStdDev = standardDeviation(bedtimeMinutes.map { Double($0) })
        let wakeStdDev = standardDeviation(wakeMinutes.map { Double($0) })

        // Score: 100 = perfect consistency (0 std dev), decreases with variability
        var score = 100.0
        score -= bedtimeStdDev / 2  // Penalize bedtime variability
        score -= wakeStdDev / 2     // Penalize wake time variability

        return max(0, min(100, Int(score)))
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }

    private func createEmptySummary() -> WeeklySleepSummary {
        WeeklySleepSummary(
            sessions: [],
            chronotype: chronotypeManager.chronotype,
            averageScore: 0,
            averageDuration: 0,
            averageEfficiency: 0,
            averageDeepPercent: 0,
            averageREMPercent: 0,
            bestNight: nil,
            worstNight: nil,
            sleepDebt: SleepDebt(
                currentDebtHours: 0,
                weeklyAverage: 0,
                idealWeeklyTotal: 56,
                daysToRecover: 0,
                recoveryProgress: 0
            ),
            socialJetlag: SocialJetlag(
                weekdayMidpoint: Date(),
                weekendMidpoint: Date(),
                jetlagHours: 0
            ),
            consistencyScore: 0,
            overallTrend: .stable
        )
    }
}
