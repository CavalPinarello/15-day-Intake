//
//  SleepStageClassifier.swift
//  ZoeSleep Watch App
//
//  EXPERIMENTAL: Combines motion and heart rate analysis to classify sleep stages.
//  Uses rule-based classification with chronotype-aware adjustments.
//

import Foundation

// MARK: - Classification Result

struct StageClassification {
    let stage: SleepStage
    let confidence: Double
    let contributors: [StageContributor]
}

struct StageContributor {
    let source: String       // "motion", "heartRate", "timing", "pattern"
    let suggestedStage: SleepStage
    let weight: Double
}

// MARK: - Sleep Stage Classifier

/// Combines multiple signals to classify sleep stage
class SleepStageClassifier {

    // MARK: - Configuration

    struct Configuration {
        var motionWeight: Double = 0.4
        var heartRateWeight: Double = 0.35
        var patternWeight: Double = 0.15
        var timingWeight: Double = 0.1

        // Stage transition constraints
        var minEpochsForDeepSleep: Int = 4   // Need 2+ min of stillness
        var minEpochsForREM: Int = 3         // REM cycles are at least 90s
        var maxSuddenDeepSleep: Bool = false // Can't go directly to deep sleep
    }

    var config = Configuration()

    // MARK: - State

    private var stageHistory: [SleepStage] = []
    private var epochsSinceWake: Int = 0
    private var currentCycleStartTime: Date?

    // MARK: - Classification

    /// Classify sleep stage for an epoch
    func classify(
        _ epoch: SleepEpoch,
        recentEpochs: [SleepEpoch],
        chronotype: Chronotype
    ) -> StageClassification {

        var contributors: [StageContributor] = []

        // 1. Motion-based classification
        let motionStage = classifyFromMotion(epoch)
        contributors.append(StageContributor(
            source: "motion",
            suggestedStage: motionStage.stage,
            weight: config.motionWeight * motionStage.confidence
        ))

        // 2. Heart rate-based classification
        let hrStage = classifyFromHeartRate(epoch)
        contributors.append(StageContributor(
            source: "heartRate",
            suggestedStage: hrStage.stage,
            weight: config.heartRateWeight * hrStage.confidence
        ))

        // 3. Pattern-based classification (looking at recent history)
        let patternStage = classifyFromPattern(recentEpochs)
        contributors.append(StageContributor(
            source: "pattern",
            suggestedStage: patternStage.stage,
            weight: config.patternWeight * patternStage.confidence
        ))

        // 4. Timing-based classification (circadian expectation)
        let timingStage = classifyFromTiming(epoch.startTime, chronotype: chronotype)
        contributors.append(StageContributor(
            source: "timing",
            suggestedStage: timingStage.stage,
            weight: config.timingWeight * timingStage.confidence
        ))

        // Combine votes
        let finalStage = combineClassifications(contributors, epoch: epoch, history: recentEpochs)

        // Calculate overall confidence
        let matchingWeight = contributors
            .filter { $0.suggestedStage == finalStage }
            .map { $0.weight }
            .reduce(0, +)
        let totalWeight = contributors.map { $0.weight }.reduce(0, +)
        let confidence = totalWeight > 0 ? matchingWeight / totalWeight : 0.5

        // Update history
        stageHistory.append(finalStage)
        if stageHistory.count > 20 {
            stageHistory.removeFirst()
        }

        return StageClassification(
            stage: finalStage,
            confidence: confidence,
            contributors: contributors
        )
    }

    // MARK: - Motion Classification

    private func classifyFromMotion(_ epoch: SleepEpoch) -> (stage: SleepStage, confidence: Double) {
        let intensity = epoch.movementIntensity

        // Very high movement = awake
        if intensity > 0.3 || epoch.movementCount > 8 {
            return (.awake, 0.9)
        }

        // High movement = awake or very light
        if intensity > 0.15 || epoch.movementCount > 4 {
            return (.awake, 0.7)
        }

        // Micro-fidgeting (Netflix detection)
        if epoch.microMovements > 12 && intensity < 0.1 {
            return (.awake, 0.75) // Likely watching something
        }

        // Moderate movement = light sleep
        if intensity > 0.05 || epoch.movementCount > 1 {
            return (.lightN2, 0.6)
        }

        // Very still but occasional movement = could be REM (muscle atonia)
        if intensity > 0.02 && epoch.movementCount <= 1 {
            return (.rem, 0.4) // Low confidence REM guess
        }

        // Deep stillness = deep sleep
        if intensity < 0.02 && epoch.movementCount == 0 {
            return (.deepN3, 0.7)
        }

        return (.lightN2, 0.5)
    }

    // MARK: - Heart Rate Classification

    private func classifyFromHeartRate(_ epoch: SleepEpoch) -> (stage: SleepStage, confidence: Double) {
        guard let avgHR = epoch.avgHeartRate else {
            return (.lightN2, 0.3) // Default with low confidence
        }

        // Use HRV if available
        let hrv = epoch.heartRateVariability

        // Very low, stable HR = deep sleep
        if avgHR < 52 {
            return (.deepN3, 0.7)
        }

        // High HRV with moderate HR = REM
        if let hrv = hrv, hrv > 50, avgHR > 50 && avgHR < 65 {
            return (.rem, 0.65)
        }

        // Elevated HR = awake
        if avgHR > 75 {
            return (.awake, 0.7)
        }

        // Moderate HR
        if avgHR < 60 {
            return (.lightN2, 0.6)
        }

        return (.lightN1, 0.5)
    }

    // MARK: - Pattern Classification

    private func classifyFromPattern(_ recentEpochs: [SleepEpoch]) -> (stage: SleepStage, confidence: Double) {
        guard recentEpochs.count >= 3 else {
            return (.lightN1, 0.3)
        }

        let recentStages = recentEpochs.compactMap { $0.classifiedStage }

        // Check for sustained deep sleep
        let deepCount = recentStages.filter { $0 == .deepN3 || $0 == .deepN4 }.count
        if deepCount >= 3 {
            return (.deepN3, 0.7) // Likely still in deep sleep
        }

        // Check for REM cycle (typically 90+ min into sleep)
        let nonWakeCount = recentStages.filter { $0 != .awake }.count
        if nonWakeCount >= 4 {
            // Could be transitioning to REM
            if recentEpochs.last?.movementIntensity ?? 0 < 0.03 {
                return (.rem, 0.5)
            }
        }

        // Recent wake = likely light sleep transition
        let recentWakes = recentStages.suffix(3).filter { $0 == .awake }.count
        if recentWakes >= 1 {
            return (.lightN1, 0.6)
        }

        return (.lightN2, 0.5)
    }

    // MARK: - Timing Classification

    private func classifyFromTiming(_ time: Date, chronotype: Chronotype) -> (stage: SleepStage, confidence: Double) {
        let hour = Calendar.current.component(.hour, from: time)
        let adjustedHour = hour < 12 ? hour + 24 : hour // Handle past midnight

        // Expected sleep architecture by time of night:
        // First 1/3: More deep sleep
        // Middle 1/3: Mix
        // Last 1/3: More REM

        // Get optimal times for chronotype
        let optimalBedtime = chronotype.optimalBedtimeStart
        let optimalWake = chronotype.optimalWakeTime + (chronotype.optimalWakeTime < 12 ? 24 : 0)

        let sleepDuration = optimalWake - optimalBedtime
        let currentPosition = Double(adjustedHour) - optimalBedtime
        let sleepProgress = currentPosition / sleepDuration

        // First third - expect deep sleep
        if sleepProgress < 0.33 {
            return (.deepN3, 0.4) // Low weight suggestion
        }

        // Last third - expect REM
        if sleepProgress > 0.66 {
            return (.rem, 0.4)
        }

        // Middle - mixed
        return (.lightN2, 0.3)
    }

    // MARK: - Combine Classifications

    private func combineClassifications(
        _ contributors: [StageContributor],
        epoch: SleepEpoch,
        history: [SleepEpoch]
    ) -> SleepStage {

        // Override: if false positive detected, force awake
        if epoch.isLikelyAwake && epoch.awakeConfidence > 0.7 {
            return .awake
        }

        // Weight votes by stage
        var stageVotes: [SleepStage: Double] = [:]

        for contributor in contributors {
            stageVotes[contributor.suggestedStage, default: 0] += contributor.weight
        }

        // Find winner
        let sorted = stageVotes.sorted { $0.value > $1.value }
        var winner = sorted.first?.key ?? .awake

        // Apply transition constraints
        winner = applyTransitionRules(winner, history: history)

        return winner
    }

    private func applyTransitionRules(_ proposed: SleepStage, history: [SleepEpoch]) -> SleepStage {
        guard let lastStage = history.last?.classifiedStage else {
            // First epoch - can't be deep sleep immediately
            if proposed == .deepN3 || proposed == .deepN4 {
                return .lightN2
            }
            return proposed
        }

        // Can't jump directly to deep sleep from awake
        if lastStage == .awake && (proposed == .deepN3 || proposed == .deepN4) {
            return .lightN1
        }

        // Can't jump from deep to REM without light transition
        if (lastStage == .deepN3 || lastStage == .deepN4) && proposed == .rem {
            // Check if there's been any light sleep recently
            let recentLight = history.suffix(3).contains { $0.classifiedStage == .lightN1 || $0.classifiedStage == .lightN2 }
            if !recentLight {
                return .lightN2
            }
        }

        return proposed
    }

    // MARK: - Reset

    func reset() {
        stageHistory = []
        epochsSinceWake = 0
        currentCycleStartTime = nil
    }
}
