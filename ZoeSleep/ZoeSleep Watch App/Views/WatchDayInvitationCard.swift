//
//  WatchDayInvitationCard.swift
//  ZoeSleep Watch App
//
//  Ultra-compact 2-line invitation card for Watch
//  Shows day title + short mission + time estimate
//

import SwiftUI

// MARK: - Watch Day Invitation Card

/// Glanceable 2-line card showing today's discovery mission
struct WatchDayInvitationCard: View {
    let invitation: WatchDayInvitation

    private let palette = WatchCircadianPalette.current

    private var cardBackground: Color {
        Color.white.opacity(0.1)
    }

    private var accentColor: Color {
        invitation.isExpansionDay ? Color.orange : Color.purple
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Line 1: Emoji + Day + Title
            HStack(spacing: 6) {
                Text(invitation.emoji)
                    .font(.system(size: 14))

                Text("Day \(invitation.dayNumber)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("•")
                    .foregroundColor(.gray)
                    .font(.system(size: 10))

                Text(invitation.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }

            // Line 2: Short mission + time
            HStack(spacing: 4) {
                Text(invitation.shortMission)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(invitation.estimatedMinutes) min")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(accentColor)
            }

            // Expansion badge (if applicable)
            if invitation.isExpansionDay {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill.checkmark")
                        .font(.system(size: 9))
                    Text("Personalized for you")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                }
                .foregroundColor(.orange.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Watch Day Invitation Data

/// Ultra-compact invitation data for Watch display
struct WatchDayInvitation {
    let dayNumber: Int
    let emoji: String
    let title: String
    let shortMission: String
    let estimatedMinutes: Int
    let isExpansionDay: Bool
    let isAvailable: Bool

    /// Line 1: emoji + day + title
    var line1: String {
        "\(emoji) Day \(dayNumber): \(title)"
    }

    /// Line 2: mission + time
    var line2: String {
        "\(shortMission) • \(estimatedMinutes) min"
    }
}

// MARK: - Watch Day Invitation Library

/// Library of ultra-compact invitations for Watch
struct WatchDayInvitationLibrary {

    /// Get invitation for a specific day
    static func invitation(for dayNumber: Int, isAvailable: Bool = true) -> WatchDayInvitation {
        let data = allDays[dayNumber - 1]
        return WatchDayInvitation(
            dayNumber: dayNumber,
            emoji: data.emoji,
            title: data.title,
            shortMission: data.shortMission,
            estimatedMinutes: data.estimatedMinutes,
            isExpansionDay: dayNumber > 7,
            isAvailable: isAvailable
        )
    }

    private static let allDays: [(emoji: String, title: String, shortMission: String, estimatedMinutes: Int)] = [
        // Core Days (1-7)
        ("🌙", "Your Sleep World", "Map your sleep environment", 8),
        ("💤", "Sleep Quality", "Measure true rest quality", 10),
        ("🔍", "Disruption Hunt", "Find what wakes you", 10),
        ("💪", "Body & Sleep", "Physical-sleep connection", 13),
        ("⏰", "Timing & Mind", "Your rhythm + triggers", 9),
        ("🫁", "Physical Check", "Snoring, pain, environment", 6),
        ("☕", "Fuel & Rest", "Diet-sleep connection", 6),
        // Expansion Days (8-14)
        ("😴", "Insomnia Check", "Severity assessment", 8),
        ("✓", "Habits Audit", "Sleep habits review", 8),
        ("🧠", "Mind & Body", "Pre-sleep patterns", 10),
        ("⚡", "Energy Check", "Fatigue impact", 8),
        ("💚", "Mood-Sleep", "Depression & anxiety", 8),
        ("✨", "Mental Picture", "Complete mental profile", 12),
        ("🏆", "Final Portrait", "Complete your 360°", 25)
    ]

    /// All core day invitations (always available)
    static var coreDays: [WatchDayInvitation] {
        (1...7).map { invitation(for: $0) }
    }

    /// All expansion day invitations (conditional availability)
    static var expansionDays: [WatchDayInvitation] {
        (8...14).map { invitation(for: $0, isAvailable: false) }
    }
}

// MARK: - Today's Focus Card for Watch Home

/// Compact card showing today's mission on Watch home screen
struct WatchTodaysFocusCard: View {
    let dayNumber: Int
    let sleepLogDone: Bool
    let assessmentDone: Bool

    private let palette = WatchCircadianPalette.current

    private var invitation: WatchDayInvitation {
        WatchDayInvitationLibrary.invitation(for: dayNumber)
    }

    private var cardBackground: Color {
        Color.white.opacity(0.08)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(invitation.emoji)
                    .font(.system(size: 18))
                Text("Today's Focus")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }

            // Mission
            Text(invitation.shortMission)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)

            // Progress
            HStack(spacing: 12) {
                // Sleep Log status
                HStack(spacing: 4) {
                    Image(systemName: sleepLogDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10))
                        .foregroundColor(sleepLogDone ? .green : .gray)
                    Text("Log")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Assessment status
                HStack(spacing: 4) {
                    Image(systemName: assessmentDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10))
                        .foregroundColor(assessmentDone ? .green : .gray)
                    Text("Assessment")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Time estimate
                Text("\(invitation.estimatedMinutes) min")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple)
            }
        }
        .padding(12)
        .background(cardBackground)
        .cornerRadius(14)
    }
}

// MARK: - Preview

#Preview("Day Invitation Card") {
    VStack(spacing: 12) {
        WatchDayInvitationCard(
            invitation: WatchDayInvitationLibrary.invitation(for: 1)
        )
        WatchDayInvitationCard(
            invitation: WatchDayInvitationLibrary.invitation(for: 8)
        )
    }
    .padding()
    .background(Color.black)
}

#Preview("Today's Focus") {
    WatchTodaysFocusCard(
        dayNumber: 3,
        sleepLogDone: true,
        assessmentDone: false
    )
    .padding()
    .background(Color.black)
}
