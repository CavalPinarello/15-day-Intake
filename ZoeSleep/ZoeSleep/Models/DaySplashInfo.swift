//
//  DaySplashInfo.swift
//  Zoe Sleep for Longevity System
//
//  Data model for day splash screens - hero-framed journey content
//  Each day of the 14-day journey has a mission and discoveries
//

import Foundation

// MARK: - Day Splash Info

/// Information displayed on the daily splash screen before assessments
/// Uses hero-framing language to make the user the protagonist of their sleep discovery journey
struct DaySplashInfo {
    let dayNumber: Int
    let icon: String                    // SF Symbol name
    let title: String                   // Short title (e.g., "Sleep Quality")
    let missionStatement: String        // Hero-framed mission (3 lines max)
    let discoveries: [String]           // What user will discover (2-3 bullet points)
    let questionCount: Int
    let estimatedMinutes: Int
    let triggeredByGateways: [GatewayType]?  // nil for core days, set for expansion days
    let isExpansionDay: Bool
    let clinicalInstruments: [String]?  // Abbreviations like "ISI", "DBAS-16" for expansion days

    /// Whether this day's content is conditional on gateway triggers
    var isConditional: Bool {
        triggeredByGateways != nil && !triggeredByGateways!.isEmpty
    }

    /// Progress indicator text
    var progressText: String {
        "Day \(dayNumber) of 14"
    }

    /// Formatted time estimate
    var timeEstimate: String {
        "~\(estimatedMinutes) min"
    }

    /// Formatted question count
    var questionCountText: String {
        "\(questionCount) questions"
    }
}

// MARK: - Watch Invitation Card Info

/// Ultra-compact version for Apple Watch display
/// 2-line glanceable card with essential info only
struct WatchDayInvitation {
    let dayNumber: Int
    let emoji: String                   // Single emoji for visual identity
    let title: String                   // Short title (max 20 chars)
    let shortMission: String            // One-line mission (max 30 chars)
    let estimatedMinutes: Int
    let isExpansionDay: Bool
    let isAvailable: Bool               // false if gateways not triggered

    /// First line: emoji + title
    var line1: String {
        "\(emoji) Day \(dayNumber): \(title)"
    }

    /// Second line: mission + time
    var line2: String {
        "\(shortMission) • \(estimatedMinutes) min"
    }
}

// MARK: - Section Type for Splash Context

/// Which section the splash is for
enum SplashSection {
    case sleepLog
    case assessment
    case both  // Combined for days with both sections
}

// MARK: - Gateway Trigger Display

extension GatewayType {
    /// Human-readable trigger explanation for splash screens
    var triggerExplanation: String {
        switch self {
        case .insomnia:
            return "Based on your sleep difficulty responses"
        case .poorSleepQuality:
            return "Based on your sleep quality rating"
        case .excessiveSleepiness:
            return "Based on your daytime sleepiness responses"
        case .depression:
            return "Based on your mood responses"
        case .anxiety:
            return "Based on your anxiety responses"
        case .cognitive:
            return "Based on your concentration and memory responses"
        case .osa:
            return "Based on your snoring and breathing responses"
        case .pain:
            return "Based on your pain affecting sleep"
        case .dietImpact:
            return "Based on your diet and nutrition responses"
        case .sleepTiming:
            return "Based on your sleep schedule patterns"
        case .shiftWork:
            return "Based on your work schedule responses"
        }
    }

    /// Short version for Watch
    var shortTrigger: String {
        switch self {
        case .insomnia: return "sleep difficulties"
        case .poorSleepQuality: return "sleep quality"
        case .excessiveSleepiness: return "daytime sleepiness"
        case .depression: return "mood patterns"
        case .anxiety: return "anxiety patterns"
        case .cognitive: return "focus concerns"
        case .osa: return "breathing patterns"
        case .pain: return "pain affecting sleep"
        case .dietImpact: return "diet patterns"
        case .sleepTiming: return "schedule patterns"
        case .shiftWork: return "shift work patterns"
        }
    }
}
