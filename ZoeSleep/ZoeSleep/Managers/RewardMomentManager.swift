//
//  RewardMomentManager.swift
//  Zoe Sleep for Longevity System
//
//  Manages when to show reward moments (sleep facts) during questionnaire
//  Selects facts based on recently answered question pillars
//

import Foundation
import SwiftUI

// MARK: - Reward Moment Manager

class RewardMomentManager: ObservableObject {
    /// Whether a reward should be shown now
    @Published var shouldShowReward: Bool = false

    /// The currently selected fact to display
    @Published var currentFact: SleepFact?

    /// Number of questions answered since last reward
    private var questionsSinceLastReward: Int = 0

    /// IDs of facts already shown in this session (avoid repeats)
    private var shownFactIds: Set<String> = []

    /// Recent pillars from answered questions (for relevance)
    private var recentPillars: [Pillar] = []

    /// Maximum recent pillars to track
    private let maxRecentPillars: Int = 5

    /// Current section being worked on
    private var currentSection: QuestionnaireSection = .assessment

    // MARK: - Public Methods

    /// Call this when a question is answered
    /// - Parameters:
    ///   - question: The question that was just answered
    ///   - isFirstInSection: Whether this is the first question in the section
    ///   - isLastInSection: Whether this is the last question in the section
    ///   - section: The current questionnaire section
    func onQuestionAnswered(
        question: Question,
        isFirstInSection: Bool,
        isLastInSection: Bool,
        section: QuestionnaireSection
    ) {
        // Store current section for fact selection
        currentSection = section

        // Skip Sleep Log section if configured
        if RewardMomentConfig.skipSleepLog && section == .sleepLog {
            return
        }

        // Skip first question of section (let user get into flow)
        if isFirstInSection {
            return
        }

        // Skip last question (has its own completion screen)
        if isLastInSection {
            return
        }

        // Track the pillar of this question for relevance
        trackPillar(question.pillar)

        // Increment question counter
        questionsSinceLastReward += 1

        // Check if we should trigger a reward (section-aware)
        if shouldTriggerReward(for: section) {
            selectAndShowFact(for: section)
        }
    }

    /// Dismiss the current reward and prepare for next
    func dismissReward() {
        shouldShowReward = false
        currentFact = nil
    }

    /// Reset the manager (e.g., when starting a new day)
    func reset() {
        shouldShowReward = false
        currentFact = nil
        questionsSinceLastReward = 0
        shownFactIds.removeAll()
        recentPillars.removeAll()
    }

    /// Reset shown facts only (for new session, keep other state)
    func resetShownFacts() {
        shownFactIds.removeAll()
    }

    // MARK: - Private Methods

    /// Track a pillar for relevance weighting
    private func trackPillar(_ pillar: Pillar) {
        recentPillars.append(pillar)
        if recentPillars.count > maxRecentPillars {
            recentPillars.removeFirst()
        }
    }

    /// Determine if a reward should trigger (section-aware)
    private func shouldTriggerReward(for section: QuestionnaireSection) -> Bool {
        let (min, max) = section == .sleepLog
            ? (RewardMomentConfig.sleepLogMinQuestionsBetween, RewardMomentConfig.sleepLogMaxQuestionsBetween)
            : (RewardMomentConfig.minQuestionsBetween, RewardMomentConfig.maxQuestionsBetween)

        // Not enough questions yet
        if questionsSinceLastReward < min {
            return false
        }

        // Always trigger at max
        if questionsSinceLastReward >= max {
            return true
        }

        // Between min and max: 50% chance
        return Bool.random()
    }

    /// Select a relevant fact and trigger the reward display (section-aware)
    private func selectAndShowFact(for section: QuestionnaireSection) {
        // For Sleep Log section, prefer calibration encouragement facts
        if section == .sleepLog {
            let calibrationFacts = SleepFactBank.sleepLogEncouragementFacts
                .filter { !shownFactIds.contains($0.id) }

            if let fact = calibrationFacts.randomElement() {
                displayFact(fact)
                return
            }
            // If all calibration facts shown, reset and pick again
            let shownCalibrationIds = Set(SleepFactBank.sleepLogEncouragementFacts.map { $0.id })
            shownFactIds.subtract(shownCalibrationIds)
            if let fact = SleepFactBank.sleepLogEncouragementFacts.randomElement() {
                displayFact(fact)
                return
            }
        }

        // For Assessment section (or fallback), use the regular fact selection
        selectAndShowFactFromAllPillars()
    }

    /// Select from all pillar facts (used for Assessment section)
    private func selectAndShowFactFromAllPillars() {
        // Get facts we haven't shown yet
        let availableFacts = SleepFactBank.all.filter { !shownFactIds.contains($0.id) }

        // If we've shown all facts, reset
        guard !availableFacts.isEmpty else {
            shownFactIds.removeAll()
            selectAndShowFactFromAllPillars()
            return
        }

        // Try to find a fact matching recent pillars (weighted by recency)
        var selectedFact: SleepFact?

        // Check recent pillars in reverse order (most recent first)
        for pillar in recentPillars.reversed() {
            if let matchingFact = availableFacts.first(where: { $0.pillar == pillar }) {
                selectedFact = matchingFact
                break
            }
        }

        // If no matching fact, pick a random one
        if selectedFact == nil {
            selectedFact = availableFacts.randomElement()
        }

        // Display the fact
        if let fact = selectedFact {
            displayFact(fact)
        }
    }

    /// Display a fact and update tracking state
    private func displayFact(_ fact: SleepFact) {
        shownFactIds.insert(fact.id)
        questionsSinceLastReward = 0
        currentFact = fact
        shouldShowReward = true
    }

    // MARK: - Debug/Testing

    /// Force show a specific fact (for testing)
    func showFact(_ fact: SleepFact) {
        currentFact = fact
        shouldShowReward = true
    }

    /// Get count of available facts
    var availableFactsCount: Int {
        SleepFactBank.all.filter { !shownFactIds.contains($0.id) }.count
    }

    /// Get total facts count
    var totalFactsCount: Int {
        SleepFactBank.all.count
    }
}
