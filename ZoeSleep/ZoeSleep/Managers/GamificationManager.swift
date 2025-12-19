//
//  GamificationManager.swift
//  Zoe Sleep for Longevity System
//
//  Manages gamification features: streaks, XP, badges, and challenges
//  Integrates with Convex backend for persistence
//

import Foundation
import SwiftUI
import Combine

// MARK: - Data Models

struct StreakData: Equatable {
    let currentStreak: Int
    let longestStreak: Int
    let lastActivityDate: String?
    let totalDaysCompleted: Int
    let streakAtRisk: Bool
    let hasFreezeAvailable: Bool

    static let empty = StreakData(
        currentStreak: 0,
        longestStreak: 0,
        lastActivityDate: nil,
        totalDaysCompleted: 0,
        streakAtRisk: false,
        hasFreezeAvailable: true
    )
}

struct XPData: Equatable {
    let totalXP: Int
    let currentLevel: Int
    let levelName: String
    let xpToNextLevel: Int
    let weeklyXP: Int
    let breakdown: XPBreakdown

    struct XPBreakdown: Equatable {
        let logs: Int
        let assessments: Int
        let streaks: Int
        let badges: Int
        let challenges: Int
    }

    static let empty = XPData(
        totalXP: 0,
        currentLevel: 1,
        levelName: "Sleep Novice",
        xpToNextLevel: 500,
        weeklyXP: 0,
        breakdown: XPBreakdown(logs: 0, assessments: 0, streaks: 0, badges: 0, challenges: 0)
    )

    var progressToNextLevel: Double {
        guard xpToNextLevel > 0 else { return 1.0 }
        let xpInCurrentLevel = xpForCurrentLevel
        let currentLevelXP = Double(totalXP - xpForLevelStart(currentLevel))
        return min(1.0, max(0.0, currentLevelXP / Double(xpInCurrentLevel)))
    }

    private var xpForCurrentLevel: Int {
        switch currentLevel {
        case 1: return 500
        case 2: return 1000
        case 3: return 2000
        case 4: return 3500
        default: return 1000
        }
    }

    private func xpForLevelStart(_ level: Int) -> Int {
        switch level {
        case 1: return 0
        case 2: return 500
        case 3: return 1500
        case 4: return 3500
        case 5: return 7000
        default: return 0
        }
    }
}

struct BadgeData: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: String
    let icon: String
    let earnedAt: Date?
    let isEarned: Bool
    let progressCurrent: Int?
    let progressTarget: Int?

    var progress: Double {
        guard let current = progressCurrent, let target = progressTarget, target > 0 else { return 0 }
        return min(1.0, Double(current) / Double(target))
    }
}

struct DayCompleteResult {
    let xpEarned: Int
    let newStreak: Int
    let isNewStreakRecord: Bool
    let badgesEarned: [String]
    let leveledUp: Bool
    let previousLevel: Int?
    let newLevel: Int?
}

// MARK: - XP Award Event (for animations)

struct XPAwardEvent: Identifiable {
    let id = UUID()
    let amount: Int
    let description: String
    let type: XPType

    enum XPType {
        case sleepLog
        case assessment
        case perfectDay
        case streakBonus
        case badge
        case challenge
    }
}

// MARK: - Gamification Manager

@MainActor
class GamificationManager: ObservableObject {
    static let shared = GamificationManager()

    // MARK: - Published State

    @Published var streak: StreakData = .empty
    @Published var xp: XPData = .empty
    @Published var earnedBadges: [BadgeData] = []
    @Published var inProgressBadges: [BadgeData] = []

    // UI State
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    // Animation triggers
    @Published var showXPAnimation: Bool = false
    @Published var xpAnimationAmount: Int = 0
    @Published var recentXPEvents: [XPAwardEvent] = []
    @Published var showBadgeUnlockedAnimation: Bool = false
    @Published var unlockedBadge: BadgeData?
    @Published var showLevelUpAnimation: Bool = false
    @Published var newLevelInfo: (level: Int, name: String)?
    @Published var showStreakMilestoneAnimation: Bool = false
    @Published var streakMilestone: Int?

    // MARK: - Constants

    static let XP = (
        sleepLog: 50,
        assessment: 100,
        perfectDay: 200,
        streak7Day: 500,
        streak15Day: 1000,
        streak30Day: 2000,
        expansionPack: 300,
        connectWearable: 100
    )

    // MARK: - Init

    private init() {}

    // MARK: - Data Fetching

    /// Load all gamification data for current user
    func loadData() async {
        guard ConvexService.shared.isAuthenticated else {
            print("[Gamification] Not authenticated, skipping data load")
            return
        }

        isLoading = true
        lastError = nil

        do {
            // Fetch streak, XP, and badges in parallel
            async let streakTask = fetchStreak()
            async let xpTask = fetchXP()
            async let badgesTask = fetchBadges()

            let (streakResult, xpResult, badgesResult) = await (streakTask, xpTask, badgesTask)

            if let s = streakResult { streak = s }
            if let x = xpResult { xp = x }
            if let (earned, inProgress) = badgesResult {
                earnedBadges = earned
                inProgressBadges = inProgress
            }

            print("[Gamification] Data loaded: Streak=\(streak.currentStreak), XP=\(xp.totalXP), Badges=\(earnedBadges.count)")
        } catch {
            lastError = error.localizedDescription
            print("[Gamification] Error loading data: \(error)")
        }

        isLoading = false
    }

    private func fetchStreak() async -> StreakData? {
        guard let userId = ConvexService.shared.userId else { return nil }

        do {
            let response: StreakResponse = try await ConvexService.shared.query(
                "gamification:getUserStreak",
                args: ["userId": userId]
            )
            return StreakData(
                currentStreak: response.currentStreak,
                longestStreak: response.longestStreak,
                lastActivityDate: response.lastActivityDate,
                totalDaysCompleted: response.totalDaysCompleted,
                streakAtRisk: response.streakAtRisk,
                hasFreezeAvailable: response.hasFreezeAvailable
            )
        } catch {
            print("[Gamification] Error fetching streak: \(error)")
            return nil
        }
    }

    private func fetchXP() async -> XPData? {
        guard let userId = ConvexService.shared.userId else { return nil }

        do {
            let response: XPResponse = try await ConvexService.shared.query(
                "gamification:getUserXP",
                args: ["userId": userId]
            )
            return XPData(
                totalXP: response.totalXP,
                currentLevel: response.currentLevel,
                levelName: response.levelName,
                xpToNextLevel: response.xpToNextLevel,
                weeklyXP: response.weeklyXP,
                breakdown: XPData.XPBreakdown(
                    logs: response.breakdown.logs,
                    assessments: response.breakdown.assessments,
                    streaks: response.breakdown.streaks,
                    badges: response.breakdown.badges,
                    challenges: response.breakdown.challenges
                )
            )
        } catch {
            print("[Gamification] Error fetching XP: \(error)")
            return nil
        }
    }

    private func fetchBadges() async -> ([BadgeData], [BadgeData])? {
        guard let userId = ConvexService.shared.userId else { return nil }

        do {
            let response: BadgesResponse = try await ConvexService.shared.query(
                "gamification:getUserBadges",
                args: ["userId": userId]
            )

            let earned = response.earned.map { badge in
                BadgeData(
                    id: badge.badge_id,
                    name: badge.badge_name,
                    description: badge.badge_description,
                    category: badge.badge_category,
                    icon: badge.badge_icon,
                    earnedAt: Date(timeIntervalSince1970: TimeInterval(badge.earned_at) / 1000),
                    isEarned: true,
                    progressCurrent: nil,
                    progressTarget: nil
                )
            }

            let inProgress = response.inProgress.map { badge in
                BadgeData(
                    id: badge.badge_id,
                    name: badge.badge_name,
                    description: badge.badge_description,
                    category: badge.badge_category,
                    icon: badge.badge_icon,
                    earnedAt: nil,
                    isEarned: false,
                    progressCurrent: badge.progress_current,
                    progressTarget: badge.progress_target
                )
            }

            return (earned, inProgress)
        } catch {
            print("[Gamification] Error fetching badges: \(error)")
            return nil
        }
    }

    // MARK: - Day Complete (Main Entry Point)

    /// Call this when a user completes their day (both sleep log and assessment)
    /// Returns the results for UI celebration
    func recordDayComplete(
        dayNumber: Int,
        completedSleepLog: Bool,
        completedAssessment: Bool,
        triggeredGateways: [String]? = nil
    ) async -> DayCompleteResult? {
        guard let userId = ConvexService.shared.userId else { return nil }

        do {
            var args: [String: Any] = [
                "userId": userId,
                "dayNumber": dayNumber,
                "completedSleepLog": completedSleepLog,
                "completedAssessment": completedAssessment
            ]
            if let gateways = triggeredGateways {
                args["triggeredGateways"] = gateways
            }

            let response: DayCompleteResponse = try await ConvexService.shared.mutation(
                "gamification:recordDayComplete",
                args: args
            )

            // Update local state
            await loadData()

            // Trigger animations
            if response.xpEarned > 0 {
                triggerXPAnimation(amount: response.xpEarned)
            }

            if response.leveledUp {
                triggerLevelUpAnimation(level: xp.currentLevel, name: xp.levelName)
            }

            if !response.badgesEarned.isEmpty {
                for badgeName in response.badgesEarned {
                    if let badge = earnedBadges.first(where: { $0.name == badgeName }) {
                        triggerBadgeAnimation(badge: badge)
                    }
                }
            }

            // Check for streak milestones
            if let streakUpdate = response.streakUpdate {
                if [7, 15, 30, 60].contains(streakUpdate.currentStreak) {
                    triggerStreakMilestoneAnimation(streak: streakUpdate.currentStreak)
                }
            }

            return DayCompleteResult(
                xpEarned: response.xpEarned,
                newStreak: response.streakUpdate?.currentStreak ?? 0,
                isNewStreakRecord: response.streakUpdate?.isNewRecord ?? false,
                badgesEarned: response.badgesEarned,
                leveledUp: response.leveledUp,
                previousLevel: nil,
                newLevel: response.leveledUp ? xp.currentLevel : nil
            )
        } catch {
            print("[Gamification] Error recording day complete: \(error)")
            return nil
        }
    }

    // MARK: - Streak Actions

    /// Use a streak freeze to protect the streak
    func useStreakFreeze() async -> Bool {
        guard let userId = ConvexService.shared.userId else { return false }

        do {
            let response: StreakFreezeResponse = try await ConvexService.shared.mutation(
                "gamification:useStreakFreeze",
                args: ["userId": userId]
            )

            if response.success {
                await loadData()
            }

            return response.success
        } catch {
            print("[Gamification] Error using streak freeze: \(error)")
            return false
        }
    }

    // MARK: - Animation Triggers

    private func triggerXPAnimation(amount: Int) {
        xpAnimationAmount = amount
        showXPAnimation = true

        // Add to recent events
        recentXPEvents.append(XPAwardEvent(
            amount: amount,
            description: "Day Complete",
            type: .perfectDay
        ))

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showXPAnimation = false
        }
    }

    private func triggerBadgeAnimation(badge: BadgeData) {
        unlockedBadge = badge
        showBadgeUnlockedAnimation = true

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.showBadgeUnlockedAnimation = false
            self?.unlockedBadge = nil
        }
    }

    private func triggerLevelUpAnimation(level: Int, name: String) {
        newLevelInfo = (level, name)
        showLevelUpAnimation = true

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.showLevelUpAnimation = false
            self?.newLevelInfo = nil
        }
    }

    private func triggerStreakMilestoneAnimation(streak: Int) {
        streakMilestone = streak
        showStreakMilestoneAnimation = true

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.showStreakMilestoneAnimation = false
            self?.streakMilestone = nil
        }
    }
}

// MARK: - Convex Response Types

private struct StreakResponse: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let lastActivityDate: String?
    let totalDaysCompleted: Int
    let streakAtRisk: Bool
    let hasFreezeAvailable: Bool
}

private struct XPResponse: Codable {
    let totalXP: Int
    let currentLevel: Int
    let levelName: String
    let xpToNextLevel: Int
    let weeklyXP: Int
    let breakdown: XPBreakdownResponse

    struct XPBreakdownResponse: Codable {
        let logs: Int
        let assessments: Int
        let streaks: Int
        let badges: Int
        let challenges: Int
    }
}

private struct BadgesResponse: Codable {
    let earned: [BadgeResponse]
    let inProgress: [BadgeResponse]

    struct BadgeResponse: Codable {
        let badge_id: String
        let badge_name: String
        let badge_description: String
        let badge_category: String
        let badge_icon: String
        let earned_at: Int
        let is_earned: Bool
        let progress_current: Int?
        let progress_target: Int?
    }
}

private struct DayCompleteResponse: Codable {
    let xpEarned: Int
    let streakUpdate: StreakUpdateResponse?
    let badgesEarned: [String]
    let leveledUp: Bool

    struct StreakUpdateResponse: Codable {
        let currentStreak: Int
        let xpEarned: Int
        let isNewRecord: Bool
    }
}

private struct StreakFreezeResponse: Codable {
    let success: Bool
    let frozenUntil: String?
    let reason: String?
}

// MARK: - ConvexService Extensions

extension ConvexService {
    func query<T: Decodable>(_ functionName: String, args: [String: Any] = [:]) async throws -> T {
        // This would use the internal client - for now we need to use the existing pattern
        // In practice, you'd add this to ConvexService or create a protocol
        throw ConvexError.serverError("Use existing query pattern")
    }

    func mutation<T: Decodable>(_ functionName: String, args: [String: Any] = [:]) async throws -> T {
        throw ConvexError.serverError("Use existing mutation pattern")
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension GamificationManager {
    static var preview: GamificationManager {
        let manager = GamificationManager()
        manager.streak = StreakData(
            currentStreak: 7,
            longestStreak: 12,
            lastActivityDate: "2024-12-18",
            totalDaysCompleted: 15,
            streakAtRisk: false,
            hasFreezeAvailable: true
        )
        manager.xp = XPData(
            totalXP: 1250,
            currentLevel: 2,
            levelName: "Sleep Student",
            xpToNextLevel: 250,
            weeklyXP: 450,
            breakdown: XPData.XPBreakdown(
                logs: 350,
                assessments: 500,
                streaks: 300,
                badges: 100,
                challenges: 0
            )
        )
        manager.earnedBadges = [
            BadgeData(id: "first_step", name: "First Step", description: "Complete Day 1", category: "journey", icon: "star.fill", earnedAt: Date(), isEarned: true, progressCurrent: nil, progressTarget: nil),
            BadgeData(id: "week_warrior", name: "Week Warrior", description: "7-day streak", category: "streak", icon: "flame.fill", earnedAt: Date(), isEarned: true, progressCurrent: nil, progressTarget: nil)
        ]
        return manager
    }
}
#endif
