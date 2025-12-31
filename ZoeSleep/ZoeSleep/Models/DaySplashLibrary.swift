//
//  DaySplashLibrary.swift
//  Zoe Sleep for Longevity System
//
//  Hero-framed content for all 14 days of the sleep discovery journey
//  Each day positions the user as the hero uncovering insights about their sleep
//
//  FIXED SCHEDULE:
//  Days 1-5: Core Assessment (by pillar/theme)
//  Days 6-14: Expansion Packs (gateway-triggered)
//

import Foundation

// MARK: - Day Splash Library

/// Library of splash screen content for all 14 days
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

    // MARK: - Expansion Days (6-14) - Gateway-Triggered

    static let day6 = DaySplashInfo(
        dayNumber: 6,
        icon: "moon.zzz.fill",
        title: "Sleep & Work Patterns",
        missionStatement: "Measure your insomnia severity and assess shift work impacts. Understanding these patterns unlocks targeted solutions.",
        discoveries: [
            "Your clinical insomnia severity score (ISI)",
            "Shift work disorder screening",
            "The worry-sleep cycle in your life"
        ],
        questionCount: 11,
        estimatedMinutes: 8,
        triggeredByGateways: [.insomnia, .poorSleepQuality, .shiftWork],
        isExpansionDay: true,
        clinicalInstruments: ["ISI", "SWDSQ"]
    )

    static let day7 = DaySplashInfo(
        dayNumber: 7,
        icon: "heart.circle.fill",
        title: "Mood & Thinking",
        missionStatement: "Deep dive into depression screening and cognitive function. Your mental state profoundly affects your rest.",
        discoveries: [
            "Comprehensive depression screening (PHQ-9)",
            "Cognitive function assessment",
            "The bidirectional mood-sleep relationship"
        ],
        questionCount: 15,
        estimatedMinutes: 10,
        triggeredByGateways: [.depression, .cognitive],
        isExpansionDay: true,
        clinicalInstruments: ["PHQ-9", "PROMIS Cognitive"]
    )

    static let day8 = DaySplashInfo(
        dayNumber: 8,
        icon: "checkmark.shield.fill",
        title: "Anxiety & Sleep Habits",
        missionStatement: "Screen for anxiety and audit your sleep hygiene. Small habit changes can transform your nights.",
        discoveries: [
            "Your anxiety severity score (GAD-7)",
            "Sleep hygiene assessment",
            "Habits helping or hurting your rest"
        ],
        questionCount: 17,
        estimatedMinutes: 12,
        triggeredByGateways: [.anxiety, .insomnia, .poorSleepQuality],
        isExpansionDay: true,
        clinicalInstruments: ["GAD-7", "Sleep Hygiene Index"]
    )

    static let day9 = DaySplashInfo(
        dayNumber: 9,
        icon: "lungs.fill",
        title: "Sleep Apnea Screening",
        missionStatement: "STOP-BANG screening for sleep apnea risk. Breathing issues during sleep can have serious health impacts.",
        discoveries: [
            "STOP-BANG risk assessment",
            "Your sleep apnea risk profile",
            "Breathing pattern insights"
        ],
        questionCount: 8,
        estimatedMinutes: 5,
        triggeredByGateways: [.osa],
        isExpansionDay: true,
        clinicalInstruments: ["STOP-BANG"]
    )

    static let day10 = DaySplashInfo(
        dayNumber: 10,
        icon: "bolt.fill",
        title: "Daytime Energy",
        missionStatement: "Measure how sleepiness and fatigue are affecting your daily life. Energy issues impact every aspect of functioning.",
        discoveries: [
            "Your daytime sleepiness score (ESS)",
            "Fatigue severity assessment (FSS)",
            "The energy-sleep feedback loop"
        ],
        questionCount: 17,
        estimatedMinutes: 12,
        triggeredByGateways: [.excessiveSleepiness],
        isExpansionDay: true,
        clinicalInstruments: ["ESS", "FSS"]
    )

    static let day11 = DaySplashInfo(
        dayNumber: 11,
        icon: "brain",
        title: "Beliefs & Pain (Part 1)",
        missionStatement: "Examine your beliefs about sleep and assess pain's impact on rest. Both psychological and physical factors matter.",
        discoveries: [
            "Dysfunctional beliefs about sleep (DBAS-6)",
            "Pain severity assessment (BPI Part 1)",
            "How thoughts affect your sleep"
        ],
        questionCount: 12,
        estimatedMinutes: 8,
        triggeredByGateways: [.insomnia, .pain],
        isExpansionDay: true,
        clinicalInstruments: ["DBAS-6", "BPI Part 1"]
    )

    static let day12 = DaySplashInfo(
        dayNumber: 12,
        icon: "brain.head.profile",
        title: "Pain Impact",
        missionStatement: "Complete your pain assessment to understand how pain interferes with daily activities and sleep.",
        discoveries: [
            "Pain interference patterns (BPI Part 2)",
            "Daily activity impact",
            "Patterns connecting pain and rest"
        ],
        questionCount: 7,
        estimatedMinutes: 5,
        triggeredByGateways: [.pain],
        isExpansionDay: true,
        clinicalInstruments: ["BPI Part 2"]
    )

    static let day13 = DaySplashInfo(
        dayNumber: 13,
        icon: "sparkles",
        title: "Sleep Arousal & Function",
        missionStatement: "Understand pre-sleep arousal and how sleep impacts your daily functioning. The final pieces of your sleep puzzle.",
        discoveries: [
            "Pre-sleep arousal patterns (PSAS)",
            "Functional outcomes of sleep (FOSQ)",
            "How racing thoughts affect your nights"
        ],
        questionCount: 26,
        estimatedMinutes: 18,
        triggeredByGateways: [.insomnia, .anxiety, .excessiveSleepiness],
        isExpansionDay: true,
        clinicalInstruments: ["PSAS", "FOSQ-10"]
    )

    static let day14 = DaySplashInfo(
        dayNumber: 14,
        icon: "trophy.fill",
        title: "Diet & Chronotype",
        missionStatement: "Complete your Sleep 360 portrait with diet assessment and chronotype analysis. Understanding your biological rhythm and nutrition.",
        discoveries: [
            "Mediterranean diet adherence (MEDAS)",
            "Your chronotype profile (MEQ)",
            "Optimal eating and sleeping patterns"
        ],
        questionCount: 33,
        estimatedMinutes: 22,
        triggeredByGateways: [.dietImpact, .sleepTiming],
        isExpansionDay: true,
        clinicalInstruments: ["MEDAS", "MEQ"]
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
        case 11: return day11
        case 12: return day12
        case 13: return day13
        case 14: return day14
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

        // Expansion days (6-14) only show if their gateways were triggered
        guard let requiredGateways = info.triggeredByGateways else { return true }
        return requiredGateways.contains { triggeredGateways.contains($0) }
    }

    // MARK: - Watch Invitation Cards

    /// Get ultra-compact Watch invitation for a day
    static func watchInvitation(for dayNumber: Int) -> WatchDayInvitation? {
        guard let info = info(for: dayNumber) else { return nil }

        let emojis: [Int: String] = [
            1: "👤", 2: "💤", 3: "🧠", 4: "💪", 5: "☕",
            6: "😴", 7: "💚", 8: "✓", 9: "🫁", 10: "⚡",
            11: "🧠", 12: "🧠", 13: "✨", 14: "🏆"
        ]

        let shortMissions: [Int: String] = [
            1: "Demographics & history",
            2: "Sleep quality patterns",
            3: "Mind & mood assessment",
            4: "Physical health factors",
            5: "Daily habits review",
            6: "Insomnia & shift work",
            7: "Mood & thinking",
            8: "Anxiety & sleep habits",
            9: "Sleep apnea assessment",
            10: "Energy & fatigue",
            11: "Beliefs & pain (1/2)",
            12: "Beliefs & pain (2/2)",
            13: "Arousal & function",
            14: "Diet & chronotype"
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

    /// Message shown after completing Day 14 (journey complete)
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
