//
//  DaySplashLibrary.swift
//  Zoe Sleep for Longevity System
//
//  Hero-framed content for all 10 days of the sleep discovery journey
//  Each day positions the user as the hero uncovering insights about their sleep
//
//  FIXED SCHEDULE:
//  Days 1-5: Core Assessment (by pillar/theme)
//  Days 6-10: Expansion Packs (gateway-triggered)
//

import Foundation

// MARK: - Day Splash Library

/// Library of splash screen content for all 10 days
/// Hero-framing: User is the protagonist on a discovery journey
struct DaySplashLibrary {

    // MARK: - Core Days (1-5) - By Pillar/Theme

    static let day1 = DaySplashInfo(
        dayNumber: 1,
        icon: "person.2.fill",
        title: "Let's Get to Know You",
        missionStatement: "Map your demographics, sleep history, and environment. Understanding who you are helps us personalize your journey.",
        discoveries: [
            "How your living situation affects your rest",
            "Hidden social factors impacting your sleep",
            "Your work-life rhythm and sleep connection"
        ],
        questionCount: 15,
        estimatedMinutes: 8,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: nil
    )

    static let day2 = DaySplashInfo(
        dayNumber: 2,
        icon: "moon.stars.fill",
        title: "Your Sleep Quality",
        missionStatement: "Measure the true quality of your sleep—not just hours, but depth, satisfaction, and patterns.",
        discoveries: [
            "Your sleep efficiency score",
            "Where your nights are breaking down",
            "Patterns in your nighttime awakenings"
        ],
        questionCount: 15,
        estimatedMinutes: 8,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: ["PSQI"]
    )

    static let day3 = DaySplashInfo(
        dayNumber: 3,
        icon: "brain.head.profile",
        title: "Mind & Mood",
        missionStatement: "Explore the connection between your mental health, daytime function, and sleep. Your mood and rest are deeply intertwined.",
        discoveries: [
            "Anxiety and depression screening",
            "Daytime function assessment",
            "Concentration and cognitive patterns"
        ],
        questionCount: 15,
        estimatedMinutes: 8,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: ["PHQ-2", "GAD-2"]
    )

    static let day4 = DaySplashInfo(
        dayNumber: 4,
        icon: "heart.text.square.fill",
        title: "Body & Health",
        missionStatement: "Understand how your physical health shapes your sleep. Breathing, pain, and activity all play crucial roles.",
        discoveries: [
            "Sleep apnea risk screening",
            "How pain affects your rest",
            "Your activity-sleep connection"
        ],
        questionCount: 15,
        estimatedMinutes: 8,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: ["STOP-BANG Gateway"]
    )

    static let day5 = DaySplashInfo(
        dayNumber: 5,
        icon: "cup.and.saucer.fill",
        title: "Daily Habits",
        missionStatement: "Connect your daily habits to your nightly rest. Caffeine, alcohol, meals, screens, and stress all shape your sleep.",
        discoveries: [
            "Your caffeine-sleep timeline",
            "How alcohol affects your sleep architecture",
            "Screen time and stress impacts"
        ],
        questionCount: 15,
        estimatedMinutes: 8,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: nil
    )

    // MARK: - Expansion Days (6-10) - Gateway-Triggered

    static let day6 = DaySplashInfo(
        dayNumber: 6,
        icon: "moon.zzz.fill",
        title: "Insomnia Assessment",
        missionStatement: "Measure your insomnia severity, assess shift work impacts, and explore beliefs about sleep that may be affecting your rest.",
        discoveries: [
            "Your clinical insomnia severity score (ISI)",
            "Shift work disorder screening (SWDSQ)",
            "Sleep beliefs affecting your rest (DBAS)"
        ],
        questionCount: 17,
        estimatedMinutes: 5,
        triggeredByGateways: [.insomnia, .poorSleepQuality, .shiftWork],
        isExpansionDay: true,
        clinicalInstruments: ["ISI", "SWDSQ", "DBAS"]
    )

    static let day7 = DaySplashInfo(
        dayNumber: 7,
        icon: "brain.head.profile",
        title: "Mental Health & Arousal",
        missionStatement: "Deep dive into depression and anxiety screening, plus understand how pre-sleep arousal affects your nights.",
        discoveries: [
            "Comprehensive depression screening (PHQ-9)",
            "Anxiety severity assessment (GAD-7)",
            "Pre-sleep arousal patterns (PSAS)"
        ],
        questionCount: 32,
        estimatedMinutes: 9,
        triggeredByGateways: [.depression, .anxiety, .insomnia],
        isExpansionDay: true,
        clinicalInstruments: ["PHQ-9", "GAD-7", "PSAS"]
    )

    static let day8 = DaySplashInfo(
        dayNumber: 8,
        icon: "lungs.fill",
        title: "Breathing & Energy",
        missionStatement: "Screen for sleep apnea risk and measure how sleepiness and fatigue affect your daily life.",
        discoveries: [
            "Sleep apnea risk screening (STOP-BANG)",
            "Daytime sleepiness score (ESS)",
            "Fatigue severity assessment (FSS)"
        ],
        questionCount: 25,
        estimatedMinutes: 7,
        triggeredByGateways: [.osa, .excessiveSleepiness],
        isExpansionDay: true,
        clinicalInstruments: ["STOP-BANG", "ESS", "FSS"]
    )

    static let day9 = DaySplashInfo(
        dayNumber: 9,
        icon: "checklist",
        title: "Function & Behavior",
        missionStatement: "Audit your sleep hygiene habits, assess pain's impact on rest, and understand how sleep affects your daily functioning.",
        discoveries: [
            "Sleep hygiene assessment",
            "Pain severity and interference (BPI)",
            "Functional outcomes of sleep (FOSQ)"
        ],
        questionCount: 33,
        estimatedMinutes: 9,
        triggeredByGateways: [.insomnia, .poorSleepQuality, .pain, .excessiveSleepiness],
        isExpansionDay: true,
        clinicalInstruments: ["Sleep Hygiene", "BPI", "FOSQ"]
    )

    static let day10 = DaySplashInfo(
        dayNumber: 10,
        icon: "clock.fill",
        title: "Lifestyle & Rhythm",
        missionStatement: "Complete your Sleep 360 portrait with cognitive function assessment, diet analysis, and chronotype profiling.",
        discoveries: [
            "Cognitive function assessment (PROMIS)",
            "Mediterranean diet adherence (MEDAS)",
            "Your chronotype profile (MEQ)"
        ],
        questionCount: 39,
        estimatedMinutes: 11,
        triggeredByGateways: [.cognitive, .dietImpact, .sleepTiming],
        isExpansionDay: true,
        clinicalInstruments: ["PROMIS", "MEDAS", "MEQ"]
    )

    // MARK: - Lookup Methods

    /// Get splash info for a specific day
    static func info(for dayNumber: Int) -> DaySplashInfo? {
        switch dayNumber {
        case 1: return day1
        case 2: return day2
        case 3: return day3
        case 4: return day4
        case 5: return day5
        case 6: return day6
        case 7: return day7
        case 8: return day8
        case 9: return day9
        case 10: return day10
        default: return nil
        }
    }

    /// Get splash info with dynamic question count from Convex
    static func info(for dayNumber: Int, questionCount: Int, estimatedMinutes: Int) -> DaySplashInfo? {
        guard let baseInfo = info(for: dayNumber) else { return nil }
        return DaySplashInfo(
            dayNumber: baseInfo.dayNumber,
            icon: baseInfo.icon,
            title: baseInfo.title,
            missionStatement: baseInfo.missionStatement,
            discoveries: baseInfo.discoveries,
            questionCount: questionCount,
            estimatedMinutes: estimatedMinutes,
            triggeredByGateways: baseInfo.triggeredByGateways,
            isExpansionDay: baseInfo.isExpansionDay,
            clinicalInstruments: baseInfo.clinicalInstruments
        )
    }

    /// Check if day should show splash (expansion days depend on gateways)
    static func shouldShowSplash(for dayNumber: Int, triggeredGateways: [GatewayType]) -> Bool {
        guard let info = info(for: dayNumber) else { return false }

        // Core days (1-5) always show splash
        if !info.isExpansionDay { return true }

        // Expansion days (6-10) only show if their gateways were triggered
        guard let requiredGateways = info.triggeredByGateways else { return true }
        return requiredGateways.contains { triggeredGateways.contains($0) }
    }

    // MARK: - Watch Invitation Cards

    /// Get ultra-compact Watch invitation for a day
    static func watchInvitation(for dayNumber: Int) -> WatchDayInvitation? {
        guard let info = info(for: dayNumber) else { return nil }

        let emojis: [Int: String] = [
            1: "👤", 2: "💤", 3: "🧠", 4: "💪", 5: "☕",
            6: "😴", 7: "🧠", 8: "🫁", 9: "📋", 10: "🕐"
        ]

        let shortMissions: [Int: String] = [
            1: "Demographics & history",
            2: "Sleep quality patterns",
            3: "Mind & mood assessment",
            4: "Physical health factors",
            5: "Daily habits review",
            6: "Insomnia & shift work",
            7: "Mental health & arousal",
            8: "Breathing & energy",
            9: "Function & behavior",
            10: "Lifestyle & rhythm"
        ]

        return WatchDayInvitation(
            dayNumber: dayNumber,
            emoji: emojis[dayNumber] ?? "📋",
            title: info.title,
            shortMission: shortMissions[dayNumber] ?? "Complete assessment",
            estimatedMinutes: info.estimatedMinutes,
            isExpansionDay: info.isExpansionDay,
            isAvailable: true  // Caller should check gateway availability
        )
    }

    /// All Watch invitations for core days (always available)
    static var coreWatchInvitations: [WatchDayInvitation] {
        (1...5).compactMap { watchInvitation(for: $0) }
    }
}

// MARK: - Journey Milestone Messages

extension DaySplashLibrary {

    /// Message shown after completing Day 5 (core complete)
    static let coreCompleteMessage = """
    You've completed the Core Assessment phase!

    Over 5 days, you've mapped:
    • Your demographics and sleep environment
    • True sleep quality and patterns
    • Mental health and daytime function
    • Physical health factors
    • Daily lifestyle habits

    Based on what we've learned, we've prepared personalized deep-dives for you.
    """

    /// Message shown after completing Day 10 (journey complete)
    static let journeyCompleteMessage = """
    Congratulations! Your Sleep 360 portrait is complete.

    You've helped us understand:
    • Every dimension of your sleep
    • Physical and mental connections
    • Your unique patterns and challenges

    Your physician will now create a personalized treatment plan targeting your specific needs.

    Thank you for your commitment to better sleep—and a longer, healthier life.
    """
}
