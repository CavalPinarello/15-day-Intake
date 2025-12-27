//
//  DaySplashLibrary.swift
//  Zoe Sleep for Longevity System
//
//  Hero-framed content for all 14 days of the sleep discovery journey
//  Each day positions the user as the hero uncovering insights about their sleep
//

import Foundation

// MARK: - Day Splash Library

/// Library of splash screen content for all 14 days
/// Hero-framing: User is the protagonist on a discovery journey
struct DaySplashLibrary {

    // MARK: - Core Days (1-7)

    static let day1 = DaySplashInfo(
        dayNumber: 1,
        icon: "person.2.fill",
        title: "Your Sleep World",
        missionStatement: "Map the people, places, and patterns that shape your nights. Your sleep environment tells a story—let's uncover it.",
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
        title: "Sleep Quality",
        missionStatement: "Measure the true quality of your sleep—not just hours, but depth and restoration. Quality matters more than quantity.",
        discoveries: [
            "Your sleep efficiency score",
            "Where your nights are breaking down",
            "Patterns in your nighttime awakenings"
        ],
        questionCount: 12,
        estimatedMinutes: 10,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: ["PSQI Part 1"]
    )

    static let day3 = DaySplashInfo(
        dayNumber: 3,
        icon: "magnifyingglass",
        title: "Disruption Detective",
        missionStatement: "Identify exactly what's waking you up and wearing you down. Every disruption has a cause—let's find yours.",
        discoveries: [
            "Your top sleep disruptors ranked",
            "Physical factors interrupting your rest",
            "Patterns you may not have noticed"
        ],
        questionCount: 11,
        estimatedMinutes: 10,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: ["PSQI Part 2"]
    )

    static let day4 = DaySplashInfo(
        dayNumber: 4,
        icon: "heart.text.square.fill",
        title: "Your Body's Story",
        missionStatement: "Understand how your physical health shapes your sleep. Your body and your rest are deeply connected.",
        discoveries: [
            "How your health conditions affect sleep",
            "Medication impacts on rest quality",
            "Your metabolic-sleep connection"
        ],
        questionCount: 17,
        estimatedMinutes: 13,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: nil
    )

    static let day5 = DaySplashInfo(
        dayNumber: 5,
        icon: "clock.badge.checkmark.fill",
        title: "Timing & Triggers",
        missionStatement: "Map your internal clock and uncover mental health connections. When you sleep matters as much as how long.",
        discoveries: [
            "Your natural sleep rhythm profile",
            "Weekday vs weekend patterns",
            "Mood and anxiety links to sleep"
        ],
        questionCount: 15,
        estimatedMinutes: 9,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: ["PHQ-2", "GAD-2"]
    )

    static let day6 = DaySplashInfo(
        dayNumber: 6,
        icon: "lungs.fill",
        title: "Physical Factors",
        missionStatement: "Investigate snoring, pain, and your sleep environment. These physical clues reveal hidden sleep challenges.",
        discoveries: [
            "Your sleep apnea risk factors",
            "How pain is affecting your rest",
            "Environment optimizations for better sleep"
        ],
        questionCount: 11,
        estimatedMinutes: 6,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: ["STOP-BANG Gateway"]
    )

    static let day7 = DaySplashInfo(
        dayNumber: 7,
        icon: "cup.and.saucer.fill",
        title: "Fuel & Rest",
        missionStatement: "Connect what you consume to how you sleep. Caffeine, alcohol, and meal timing all shape your nights.",
        discoveries: [
            "Your caffeine-sleep timeline",
            "How alcohol affects your sleep architecture",
            "Optimal eating patterns for better rest"
        ],
        questionCount: 11,
        estimatedMinutes: 6,
        triggeredByGateways: nil,
        isExpansionDay: false,
        clinicalInstruments: nil
    )

    // MARK: - Expansion Days (8-14) - Conditional on Gateway Triggers

    static let day8 = DaySplashInfo(
        dayNumber: 8,
        icon: "moon.zzz.fill",
        title: "Insomnia Severity",
        missionStatement: "Measure exactly how insomnia is affecting your daily life. Understanding severity is the first step to targeted solutions.",
        discoveries: [
            "Your clinical insomnia severity score",
            "How sleep problems are noticed by others",
            "The worry-sleep cycle in your life"
        ],
        questionCount: 17,
        estimatedMinutes: 8,
        triggeredByGateways: [.insomnia, .poorSleepQuality],
        isExpansionDay: true,
        clinicalInstruments: ["ISI", "DBAS-16 Part 1"]
    )

    static let day9 = DaySplashInfo(
        dayNumber: 9,
        icon: "checkmark.shield.fill",
        title: "Sleep Habits Audit",
        missionStatement: "Audit the habits that help or hurt your sleep. Small changes in routine can transform your nights.",
        discoveries: [
            "Habits keeping you awake",
            "Beliefs sabotaging your rest",
            "Quick wins for better sleep hygiene"
        ],
        questionCount: 17,
        estimatedMinutes: 8,
        triggeredByGateways: [.insomnia],
        isExpansionDay: true,
        clinicalInstruments: ["DBAS-16 Part 2", "SHI Part 1"]
    )

    static let day10 = DaySplashInfo(
        dayNumber: 10,
        icon: "brain.head.profile",
        title: "Pre-Sleep Mind & Body",
        missionStatement: "Understand what happens in your mind and body before sleep. Racing thoughts and tension reveal fixable patterns.",
        discoveries: [
            "Your cognitive arousal profile",
            "Physical tension patterns at bedtime",
            "Your daytime sleepiness level"
        ],
        questionCount: 24,
        estimatedMinutes: 10,
        triggeredByGateways: [.insomnia, .excessiveSleepiness],
        isExpansionDay: true,
        clinicalInstruments: ["PSAS", "ESS"]
    )

    static let day11 = DaySplashInfo(
        dayNumber: 11,
        icon: "bolt.fill",
        title: "Energy & Function",
        missionStatement: "Measure how sleepiness is stealing your energy and focus. Fatigue affects every corner of your life.",
        discoveries: [
            "Your fatigue severity score",
            "Life areas most affected by tiredness",
            "The energy-sleep feedback loop"
        ],
        questionCount: 19,
        estimatedMinutes: 8,
        triggeredByGateways: [.excessiveSleepiness],
        isExpansionDay: true,
        clinicalInstruments: ["FSS", "FOSQ-10"]
    )

    static let day12 = DaySplashInfo(
        dayNumber: 12,
        icon: "heart.circle.fill",
        title: "Mind-Sleep Connection",
        missionStatement: "Explore the powerful link between your mood and your sleep. Depression and anxiety don't just affect how you feel—they transform how you rest.",
        discoveries: [
            "Depression-sleep patterns in your life",
            "Anxiety's impact on your rest",
            "The bidirectional mood-sleep relationship"
        ],
        questionCount: 16,
        estimatedMinutes: 8,
        triggeredByGateways: [.depression, .anxiety],
        isExpansionDay: true,
        clinicalInstruments: ["PHQ-9", "GAD-7"]
    )

    static let day13 = DaySplashInfo(
        dayNumber: 13,
        icon: "sparkles",
        title: "Complete Mental Picture",
        missionStatement: "Build a complete picture of stress, anxiety, and mental clarity. Your cognitive function and emotional state shape every night.",
        discoveries: [
            "Your stress-depression-anxiety profile",
            "Cognitive function score",
            "How mental load affects rest"
        ],
        questionCount: 29,
        estimatedMinutes: 12,
        triggeredByGateways: [.anxiety, .cognitive],
        isExpansionDay: true,
        clinicalInstruments: ["DASS-21", "PROMIS-Cog"]
    )

    static let day14 = DaySplashInfo(
        dayNumber: 14,
        icon: "trophy.fill",
        title: "Final Portrait",
        missionStatement: "Complete your Sleep 360° portrait with specialized assessments. The final pieces reveal your complete sleep picture.",
        discoveries: [
            "Your sleep apnea risk assessment",
            "Pain's true impact on your rest",
            "Your chronotype and diet scores"
        ],
        questionCount: 62,
        estimatedMinutes: 25,
        triggeredByGateways: [.osa, .pain, .dietImpact, .sleepTiming],
        isExpansionDay: true,
        clinicalInstruments: ["STOP-BANG", "Berlin", "BPI", "MEDAS", "MEQ"]
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

        // Core days always show splash
        if !info.isExpansionDay { return true }

        // Expansion days only show if their gateways were triggered
        guard let requiredGateways = info.triggeredByGateways else { return true }
        return requiredGateways.contains { triggeredGateways.contains($0) }
    }

    // MARK: - Watch Invitation Cards

    /// Get ultra-compact Watch invitation for a day
    static func watchInvitation(for dayNumber: Int) -> WatchDayInvitation? {
        guard let info = info(for: dayNumber) else { return nil }

        let emojis: [Int: String] = [
            1: "🌙", 2: "💤", 3: "🔍", 4: "💪", 5: "⏰",
            6: "🫁", 7: "☕", 8: "😴", 9: "✓", 10: "🧠",
            11: "⚡", 12: "💚", 13: "✨", 14: "🏆"
        ]

        let shortMissions: [Int: String] = [
            1: "Map your sleep environment",
            2: "Measure true rest quality",
            3: "Find what wakes you",
            4: "Physical-sleep connection",
            5: "Your rhythm + triggers",
            6: "Snoring, pain, environment",
            7: "Diet-sleep connection",
            8: "Insomnia severity check",
            9: "Audit sleep habits",
            10: "Pre-sleep mind & body",
            11: "Energy impact assessment",
            12: "Mood-sleep connection",
            13: "Complete mental picture",
            14: "Final Sleep 360° portrait"
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
        (1...7).compactMap { watchInvitation(for: $0) }
    }
}

// MARK: - Journey Milestone Messages

extension DaySplashLibrary {

    /// Message shown after completing Day 7 (core complete)
    static let coreCompleteMessage = """
    You've completed the foundation of your Sleep 360° assessment!

    Over 7 days, you've mapped:
    • Your sleep environment and relationships
    • True sleep quality and disruptions
    • Physical and metabolic factors
    • Timing, mood, and lifestyle connections

    Based on what we've learned, we've prepared personalized deep-dives for you.
    """

    /// Message shown after completing Day 14 (journey complete)
    static let journeyCompleteMessage = """
    Congratulations! Your Sleep 360° portrait is complete.

    You've helped us understand:
    • Every dimension of your sleep
    • Physical and mental connections
    • Your unique patterns and challenges

    Your physician will now create a personalized treatment plan targeting your specific needs.

    Thank you for your commitment to better sleep—and a longer, healthier life.
    """
}
