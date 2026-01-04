//
//  FirstTimeGuideManager.swift
//  Zoe Sleep for Longevity System
//
//  Manages first-time feature guides that explain "why" behind each feature
//  Shows once per feature, dismissible with "Got it"
//

import Foundation
import SwiftUI

// MARK: - Guide Feature

/// Features that have first-time explanatory guides
enum GuideFeature: String, CaseIterable {
    case sleepLog = "sleep_log"
    case assessment = "assessment"
    case healthKitSync = "healthkit_sync"
    case expansionPack = "expansion_pack"
    case dashboard = "dashboard"
    case notifications = "notifications"
    case sleepScienceCards = "sleep_science_cards"

    /// UserDefaults key for tracking if guide was shown
    var shownKey: String {
        "firstTimeGuide_shown_\(rawValue)"
    }
}

// MARK: - Guide Content

/// Content for a first-time guide
struct GuideContent {
    let feature: GuideFeature
    let icon: String
    let title: String
    let headline: String
    let bulletPoints: [GuideBullet]
    let footer: String?

    struct GuideBullet {
        let icon: String
        let text: String
    }
}

// MARK: - Guide Library

/// Pre-defined guide content for each feature
enum GuideLibrary {

    // MARK: - Sleep Log Guide

    static let sleepLog = GuideContent(
        feature: .sleepLog,
        icon: "moon.zzz.fill",
        title: "Your Daily Sleep Log",
        headline: "Each morning, we'll ask about last night's sleep. This builds your personal sleep profile.",
        bulletPoints: [
            .init(icon: "clock.fill", text: "Track your actual sleep times vs. time in bed"),
            .init(icon: "chart.line.uptrend.xyaxis", text: "Measure sleep efficiency - a key health metric"),
            .init(icon: "brain.head.profile", text: "Capture how refreshed you feel each day"),
            .init(icon: "stethoscope", text: "These are the same questions used in sleep clinics worldwide")
        ],
        footer: "After 10 days, you'll have a clinical-grade baseline of your sleep patterns."
    )

    // MARK: - Assessment Guide

    static let assessment = GuideContent(
        feature: .assessment,
        icon: "list.clipboard.fill",
        title: "Your Sleep Assessment",
        headline: "Beyond sleep times, we explore factors that affect your sleep quality and overall health.",
        bulletPoints: [
            .init(icon: "heart.fill", text: "Understand how lifestyle affects your sleep"),
            .init(icon: "brain", text: "Identify mental factors like stress and anxiety"),
            .init(icon: "leaf.fill", text: "Discover habits that help or hurt your rest"),
            .init(icon: "person.fill.checkmark", text: "Questions adapt based on YOUR responses")
        ],
        footer: "This comprehensive view helps create truly personalized recommendations."
    )

    // MARK: - HealthKit Guide

    static let healthKitSync = GuideContent(
        feature: .healthKitSync,
        icon: "heart.text.square.fill",
        title: "Apple Health Integration",
        headline: "We can import your existing health data to enhance your sleep analysis.",
        bulletPoints: [
            .init(icon: "bed.double.fill", text: "Import sleep data from Apple Watch and other apps"),
            .init(icon: "waveform.path.ecg", text: "Correlate heart rate patterns with sleep quality"),
            .init(icon: "figure.walk", text: "See how activity levels affect your rest"),
            .init(icon: "lock.shield.fill", text: "Your data stays private and secure on your device")
        ],
        footer: "This is optional - you control what data is shared."
    )

    // MARK: - Expansion Pack Guide

    static let expansionPack = GuideContent(
        feature: .expansionPack,
        icon: "sparkles",
        title: "Personalized Deep Dive",
        headline: "Based on your responses, we've identified areas that need a closer look.",
        bulletPoints: [
            .init(icon: "checkmark.seal.fill", text: "These are peer-reviewed clinical questionnaires"),
            .init(icon: "stethoscope", text: "Used by sleep specialists worldwide"),
            .init(icon: "target", text: "Tailored specifically to your situation"),
            .init(icon: "lightbulb.fill", text: "Results inform your personalized recommendations")
        ],
        footer: "Taking a few extra minutes now leads to much better insights."
    )

    // MARK: - Dashboard Guide

    static let dashboard = GuideContent(
        feature: .dashboard,
        icon: "chart.bar.doc.horizontal.fill",
        title: "Your Sleep Dashboard",
        headline: "This is your command center for understanding and improving your sleep.",
        bulletPoints: [
            .init(icon: "calendar", text: "Track your daily progress through the 10-day journey"),
            .init(icon: "chart.pie.fill", text: "See your sleep health across multiple pillars"),
            .init(icon: "leaf.fill", text: "Watch your sleep garden grow with each completion"),
            .init(icon: "bell.badge.fill", text: "Get reminders to stay on track")
        ],
        footer: nil
    )

    // MARK: - Notifications Guide

    static let notifications = GuideContent(
        feature: .notifications,
        icon: "bell.badge.fill",
        title: "Smart Reminders",
        headline: "We'll send gentle reminders to help you build consistent sleep tracking habits.",
        bulletPoints: [
            .init(icon: "sunrise.fill", text: "Morning reminder for your daily sleep log"),
            .init(icon: "moon.stars.fill", text: "Evening nudge if you haven't completed today's assessment"),
            .init(icon: "slider.horizontal.3", text: "Fully customizable timing and frequency"),
            .init(icon: "bell.slash.fill", text: "Easy to turn off anytime in Settings")
        ],
        footer: "Notifications help most users stay consistent during the 10-day calibration."
    )

    // MARK: - Sleep Science Cards Guide

    static let sleepScienceCards = GuideContent(
        feature: .sleepScienceCards,
        icon: "sparkles",
        title: "Sleep Science Cards",
        headline: "As you answer questions, we'll share fascinating facts about sleep science.",
        bulletPoints: [
            .init(icon: "brain.head.profile", text: "Learn why each question matters for your health"),
            .init(icon: "book.closed.fill", text: "Discover research-backed sleep insights"),
            .init(icon: "person.3.fill", text: "See how you compare to others"),
            .init(icon: "gearshape.fill", text: "You can turn these off in Settings > Appearance")
        ],
        footer: "Knowledge is power - understanding sleep science helps you make better choices."
    )

    // MARK: - Get Guide

    /// Get guide content for a feature
    static func guide(for feature: GuideFeature) -> GuideContent {
        switch feature {
        case .sleepLog: return sleepLog
        case .assessment: return assessment
        case .healthKitSync: return healthKitSync
        case .expansionPack: return expansionPack
        case .dashboard: return dashboard
        case .notifications: return notifications
        case .sleepScienceCards: return sleepScienceCards
        }
    }
}

// MARK: - First Time Guide Manager

class FirstTimeGuideManager: ObservableObject {
    static let shared = FirstTimeGuideManager()

    /// Currently showing guide (nil if none)
    @Published var currentGuide: GuideContent?

    /// Whether a guide is being shown
    @Published var isShowingGuide: Bool = false

    private init() {}

    // MARK: - Public Methods

    /// Check if a guide should be shown for a feature (returns true if never shown before)
    func shouldShowGuide(for feature: GuideFeature) -> Bool {
        !UserDefaults.standard.bool(forKey: feature.shownKey)
    }

    /// Show a guide if it hasn't been shown before
    /// - Returns: true if guide will be shown, false if already shown
    @discardableResult
    func showGuideIfNeeded(for feature: GuideFeature) -> Bool {
        guard shouldShowGuide(for: feature) else {
            return false
        }

        currentGuide = GuideLibrary.guide(for: feature)
        isShowingGuide = true
        return true
    }

    /// Force show a guide (for testing or re-viewing)
    func showGuide(for feature: GuideFeature) {
        currentGuide = GuideLibrary.guide(for: feature)
        isShowingGuide = true
    }

    /// Dismiss the current guide and mark as shown
    func dismissGuide() {
        if let guide = currentGuide {
            UserDefaults.standard.set(true, forKey: guide.feature.shownKey)
        }
        isShowingGuide = false
        currentGuide = nil
    }

    /// Reset a specific guide (will show again)
    func resetGuide(for feature: GuideFeature) {
        UserDefaults.standard.removeObject(forKey: feature.shownKey)
    }

    /// Reset all guides (for testing/debug)
    func resetAllGuides() {
        for feature in GuideFeature.allCases {
            UserDefaults.standard.removeObject(forKey: feature.shownKey)
        }
    }

    /// Check how many guides have been shown
    var shownGuidesCount: Int {
        GuideFeature.allCases.filter { !shouldShowGuide(for: $0) }.count
    }

    /// Check how many guides remain
    var remainingGuidesCount: Int {
        GuideFeature.allCases.count - shownGuidesCount
    }

    // MARK: - Coach Mark Management

    /// Check if a coach mark should be shown (hasn't been shown before)
    func shouldShowCoachMark(_ content: CoachMarkContent) -> Bool {
        !UserDefaults.standard.bool(forKey: content.id)
    }

    /// Mark a coach mark as shown
    func markCoachMarkShown(_ content: CoachMarkContent) {
        UserDefaults.standard.set(true, forKey: content.id)
    }

    /// Reset a specific coach mark (will show again)
    func resetCoachMark(_ content: CoachMarkContent) {
        UserDefaults.standard.removeObject(forKey: content.id)
    }

    /// Reset all coach marks
    func resetAllCoachMarks() {
        // Reset all coach marks from the library
        let allCoachMarks: [CoachMarkContent] = [
            // Dashboard tour
            CoachMarkLibrary.journeyDuration,
            CoachMarkLibrary.todaysFocus,
            CoachMarkLibrary.sleepLogTask,
            CoachMarkLibrary.assessmentTask,
            CoachMarkLibrary.upcomingAssessments,
            CoachMarkLibrary.settingsMenu,
            // Legacy
            CoachMarkLibrary.progressGarden,
            CoachMarkLibrary.streakCounter,
            CoachMarkLibrary.dayProgress,
            CoachMarkLibrary.sleepScienceCards,
            CoachMarkLibrary.circadianMode,
            CoachMarkLibrary.notifications,
            CoachMarkLibrary.healthKitConnect,
            CoachMarkLibrary.healthKitData,
            CoachMarkLibrary.questionProgress,
            CoachMarkLibrary.backButton
        ]

        for mark in allCoachMarks {
            UserDefaults.standard.removeObject(forKey: mark.id)
        }
    }

    /// Dashboard tour sequence (in order)
    static let dashboardTourSequence: [CoachMarkContent] = [
        CoachMarkLibrary.journeyDuration,
        CoachMarkLibrary.todaysFocus,
        CoachMarkLibrary.sleepLogTask,
        CoachMarkLibrary.assessmentTask,
        CoachMarkLibrary.upcomingAssessments,
        CoachMarkLibrary.settingsMenu
    ]
}
