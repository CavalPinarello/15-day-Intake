//
//  ExpansionQuestionnaireSplash.swift
//  Zoe Sleep for Longevity System
//
//  Splash screen that explains the rationale for each validated questionnaire
//  Shows peer-review citations and what the assessment measures
//
//  CIRCADIAN-AWARE: Uses warm amber colors at night, no blue light
//
//  NOTE: QuestionnaireValidationInfo and QuestionnaireLibrary are defined in QuestionModels.swift
//

import SwiftUI

// MARK: - Expansion Questionnaire Splash View

/// Full-screen splash that explains the rationale for an expansion questionnaire
/// Shown once when user first encounters an expansion pack on a given day
struct ExpansionQuestionnaireSplashView: View {
    let info: QuestionnaireValidationInfo
    let triggeredGateways: [GatewayType]
    let onContinue: () -> Void

    @State private var isAnimating = false
    @EnvironmentObject var themeManager: ThemeManager

    // Circadian-aware colors
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var primaryTextColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.996, green: 0.953, blue: 0.780)  // Bright cream
            : Color.primary
    }

    private var secondaryTextColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.988, green: 0.827, blue: 0.302)  // Golden yellow
            : Color.secondary
    }

    private var accentColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.95, green: 0.6, blue: 0.2)  // Warm amber
            : Color(red: 0.13, green: 0.59, blue: 0.95)  // Blue
    }

    private var backgroundColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.12, green: 0.08, blue: 0.05)  // Dark warm brown
            : Color(.systemBackground)
    }

    private var cardBackgroundColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.18, green: 0.12, blue: 0.08)  // Slightly lighter brown
            : Color(.secondarySystemBackground)
    }

    var body: some View {
        ZStack {
            // Background
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Animated Icon
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(
                                .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                value: isAnimating
                            )

                        Circle()
                            .fill(accentColor.opacity(0.25))
                            .frame(width: 90, height: 90)

                        Image(systemName: info.icon)
                            .font(.system(size: 40))
                            .foregroundColor(accentColor)
                    }
                    .padding(.top, 40)

                    // Title Section
                    VStack(spacing: 8) {
                        Text(info.fullName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                            .multilineTextAlignment(.center)

                        Text("(\(info.abbreviation))")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal)

                    // Validation Badge
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)

                        Text("Peer-Reviewed & Validated")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )

                    // Stats Row
                    HStack(spacing: 20) {
                        StatBadge(
                            value: "\(info.questionCount)",
                            label: "Questions",
                            icon: "list.bullet",
                            color: accentColor,
                            textColor: primaryTextColor
                        )

                        StatBadge(
                            value: "~\(info.estimatedMinutes)",
                            label: "Minutes",
                            icon: "clock",
                            color: accentColor,
                            textColor: primaryTextColor
                        )

                        StatBadge(
                            value: info.validationStudiesCount,
                            label: "Citations",
                            icon: "doc.text",
                            color: accentColor,
                            textColor: primaryTextColor
                        )
                    }
                    .padding(.horizontal)

                    // What This Measures Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(accentColor)
                            Text("What This Measures")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                        }

                        Text(info.purpose)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackgroundColor)
                    )
                    .padding(.horizontal)

                    // Why We're Asking Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Why We're Asking")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                        }

                        Text(info.whyWeAsk)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackgroundColor)
                    )
                    .padding(.horizontal)

                    // Scientific Credibility Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(accentColor)
                            Text("Scientific Background")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            credentialRow(label: "Developed by", value: info.originalAuthors)
                            credentialRow(label: "First published", value: "\(info.originalYear) in \(info.originalJournal)")

                            if let sensitivity = info.sensitivity, let specificity = info.specificity {
                                credentialRow(label: "Accuracy", value: "\(sensitivity) sensitivity, \(specificity) specificity")
                            }

                            if let alpha = info.cronbachAlpha {
                                credentialRow(label: "Reliability", value: "Cronbach's α = \(alpha)")
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackgroundColor)
                    )
                    .padding(.horizontal)

                    // Gateway Trigger Explanation (if applicable)
                    if !triggeredGateways.isEmpty {
                        gatewayExplanationCard
                    }

                    Spacer(minLength: 100)
                }
            }

            // Continue Button (fixed at bottom)
            VStack {
                Spacer()

                Button(action: onContinue) {
                    HStack {
                        Text("Begin Assessment")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .background(
                    LinearGradient(
                        colors: [backgroundColor.opacity(0), backgroundColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }

    // MARK: - Helper Views

    private func credentialRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(secondaryTextColor.opacity(0.8))
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gatewayExplanationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill.checkmark")
                    .foregroundColor(.orange)
                Text("Personalized for You")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryTextColor)
            }

            Text("Based on your earlier responses, we noticed potential concerns related to \(gatewayDescriptions). This assessment will help us understand this area better.")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
        )
        .padding(.horizontal)
    }

    private var gatewayDescriptions: String {
        let names = triggeredGateways.map { $0.displayName.lowercased() }
        if names.count == 1 {
            return names[0]
        } else if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        } else {
            let allButLast = names.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(names.last ?? "")"
        }
    }
}

// MARK: - Stat Badge Component

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let textColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(textColor)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(textColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Multi-Questionnaire Splash (for days with multiple assessments)

/// Shows a combined splash when multiple questionnaires are triggered on the same day
struct ExpansionDaySplashView: View {
    let questionnaires: [QuestionnaireValidationInfo]
    let dayNumber: Int
    let triggeredGateways: [GatewayType]
    let onContinue: () -> Void

    @State private var isAnimating = false

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var primaryTextColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.996, green: 0.953, blue: 0.780)
            : Color.primary
    }

    private var secondaryTextColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.988, green: 0.827, blue: 0.302)
            : Color.secondary
    }

    private var accentColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.95, green: 0.6, blue: 0.2)
            : Color(red: 0.13, green: 0.59, blue: 0.95)
    }

    private var backgroundColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.12, green: 0.08, blue: 0.05)
            : Color(.systemBackground)
    }

    private var cardBackgroundColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.18, green: 0.12, blue: 0.08)
            : Color(.secondarySystemBackground)
    }

    private var totalQuestions: Int {
        questionnaires.reduce(0) { $0 + $1.questionCount }
    }

    private var totalMinutes: Int {
        questionnaires.reduce(0) { $0 + $1.estimatedMinutes }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(accentColor.opacity(0.15))
                                .frame(width: 100, height: 100)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(
                                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                    value: isAnimating
                                )

                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundColor(accentColor)
                        }

                        Text("Day \(dayNumber) Expansion Pack")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)

                        Text("Personalized assessments based on your journey")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Summary Stats
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(questionnaires.count)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text("Assessments")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text("\(totalQuestions)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text("Questions")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text("~\(totalMinutes)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text("Minutes")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    .padding(.vertical, 16)

                    // Questionnaire List
                    VStack(spacing: 12) {
                        ForEach(questionnaires, id: \.id) { info in
                            QuestionnaireListCard(info: info, cardBackgroundColor: cardBackgroundColor, primaryTextColor: primaryTextColor, secondaryTextColor: secondaryTextColor, accentColor: accentColor)
                        }
                    }
                    .padding(.horizontal)

                    // Why These Assessments
                    if !triggeredGateways.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.fill.checkmark")
                                    .foregroundColor(.orange)
                                Text("Why These Assessments?")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(primaryTextColor)
                            }

                            Text("Your earlier responses indicated areas where a deeper assessment would be valuable. Each of these questionnaires is a peer-reviewed clinical tool used by sleep specialists worldwide.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackgroundColor)
                        )
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
            }

            // Continue Button
            VStack {
                Spacer()

                Button(action: onContinue) {
                    HStack {
                        Text("Begin Assessments")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .background(
                    LinearGradient(
                        colors: [backgroundColor.opacity(0), backgroundColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Questionnaire List Card

struct QuestionnaireListCard: View {
    let info: QuestionnaireValidationInfo
    let cardBackgroundColor: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: info.icon)
                    .font(.system(size: 18))
                    .foregroundColor(accentColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(info.abbreviation)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryTextColor)

                Text(info.fullName)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(1)
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(info.questionCount) Q")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(primaryTextColor)

                Text("\(info.validationStudiesCount) citations")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(secondaryTextColor.opacity(0.8))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
        )
    }
}

// MARK: - Preview

#Preview("Single Questionnaire") {
    if let info = QuestionnaireLibrary.info(for: "expansion_isi") {
        ExpansionQuestionnaireSplashView(
            info: info,
            triggeredGateways: [.insomnia],
            onContinue: {}
        )
        .environmentObject(ThemeManager.shared)
    }
}

#Preview("Multi-Questionnaire Day") {
    let infos = QuestionnaireLibrary.infos(for: ["expansion_stop_bang", "expansion_berlin", "expansion_bpi"])
    ExpansionDaySplashView(
        questionnaires: infos,
        dayNumber: 14,
        triggeredGateways: [.osa, .pain],
        onContinue: {}
    )
}
