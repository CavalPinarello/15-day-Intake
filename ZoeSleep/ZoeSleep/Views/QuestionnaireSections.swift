//
//  QuestionnaireSections.swift
//  Zoe Sleep for Longevity System
//
//  Distinct visual sections for Stanford Sleep Log vs Day Assessments
//  CIRCADIAN-AWARE: Colors adapt to time of day (warm amber at night, no blue light)
//

import SwiftUI

// MARK: - Section Type

enum QuestionnaireSection: String, CaseIterable {
    case sleepLog = "sleep_log"
    case assessment = "assessment"
    case expansionPack = "expansion_pack"  // NEW: Same-day triggered assessments

    var title: String {
        switch self {
        case .sleepLog: return FriendlyCopy.sleepLogHeader
        case .assessment: return FriendlyCopy.assessmentHeader
        case .expansionPack: return "Deeper Dive"
        }
    }

    var subtitle: String {
        switch self {
        case .sleepLog: return "A quick check-in"
        case .assessment: return "Getting to know you"
        case .expansionPack: return "Personalized for you"
        }
    }

    var description: String {
        switch self {
        case .sleepLog: return "How did you sleep?"
        case .assessment: return "Help us understand you better"
        case .expansionPack: return "Based on your responses"
        }
    }

    var icon: String {
        switch self {
        case .sleepLog: return "moon.zzz.fill"
        case .assessment: return "clipboard.fill"
        case .expansionPack: return "sparkles"
        }
    }

    // MARK: - Circadian-Aware Colors
    // Evening/Night: Warm amber/orange colors (sleep-safe, no blue light)
    // Morning/Afternoon: Blues/purples OK for alertness

    /// Background color - Circadian aware
    var backgroundColor: Color {
        let isEvening = TimePeriod.current == .evening || TimePeriod.current == .night

        if isEvening {
            // Warm brown tint for all sections at night
            switch self {
            case .sleepLog: return Color(red: 0.4, green: 0.25, blue: 0.15).opacity(0.3)    // Warm brown
            case .assessment: return Color(red: 0.35, green: 0.2, blue: 0.1).opacity(0.3)  // Darker brown
            case .expansionPack: return Color(red: 0.45, green: 0.28, blue: 0.12).opacity(0.35)  // Copper/bronze tint
            }
        } else {
            // Daytime colors
            switch self {
            case .sleepLog: return Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.1)  // Blue
            case .assessment: return Color(red: 0.61, green: 0.35, blue: 0.71).opacity(0.15)  // Purple
            case .expansionPack: return Color(red: 0.72, green: 0.45, blue: 0.2).opacity(0.15)  // Copper/bronze
            }
        }
    }

    /// Accent color - Circadian aware
    var accentColor: Color {
        let isEvening = TimePeriod.current == .evening || TimePeriod.current == .night

        if isEvening {
            // Warm amber/orange at night
            switch self {
            case .sleepLog: return Color(red: 0.95, green: 0.6, blue: 0.2)    // Warm amber #F29933
            case .assessment: return Color(red: 0.85, green: 0.5, blue: 0.15) // Deep amber #D98026
            case .expansionPack: return Color(red: 0.85, green: 0.55, blue: 0.25) // Copper #D98C40
            }
        } else {
            // Daytime colors
            switch self {
            case .sleepLog: return Color(red: 0.13, green: 0.59, blue: 0.95)  // #2196F3
            case .assessment: return Color(red: 0.61, green: 0.35, blue: 0.71)  // #9C27B0
            case .expansionPack: return Color(red: 0.72, green: 0.45, blue: 0.2)  // Copper/bronze #B87333
            }
        }
    }

    /// Header gradient - Circadian aware
    var headerGradient: LinearGradient {
        let isEvening = TimePeriod.current == .evening || TimePeriod.current == .night

        if isEvening {
            // Warm amber gradients at night
            switch self {
            case .sleepLog:
                return LinearGradient(
                    colors: [Color(red: 0.95, green: 0.6, blue: 0.2), Color(red: 0.85, green: 0.45, blue: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .assessment:
                return LinearGradient(
                    colors: [Color(red: 0.85, green: 0.5, blue: 0.15), Color(red: 0.7, green: 0.35, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .expansionPack:
                return LinearGradient(
                    colors: [Color(red: 0.85, green: 0.55, blue: 0.25), Color(red: 0.7, green: 0.4, blue: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            // Daytime gradients
            switch self {
            case .sleepLog:
                return LinearGradient(
                    colors: [Color(red: 0.13, green: 0.59, blue: 0.95), Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .assessment:
                return LinearGradient(
                    colors: [Color(red: 0.61, green: 0.35, blue: 0.71), Color(red: 0.45, green: 0.25, blue: 0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .expansionPack:
                return LinearGradient(
                    colors: [Color(red: 0.72, green: 0.45, blue: 0.2), Color(red: 0.55, green: 0.32, blue: 0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    /// Text color for descriptions - high contrast on circadian backgrounds
    var descriptionTextColor: Color {
        let isEvening = TimePeriod.current == .evening || TimePeriod.current == .night
        if isEvening {
            // Bright golden yellow for visibility on dark brown
            return Color(red: 0.988, green: 0.827, blue: 0.302)  // #FCD34D
        } else {
            return accentColor
        }
    }
}

// MARK: - Expansion Pack Info (tracks why questions were triggered)

struct ExpansionPackInfo {
    let triggeredGateways: [GatewayType]
    let questions: [Question]
    let totalEstimatedMinutes: Int

    /// Human-readable explanation of why these questions are being asked
    var triggerExplanation: String {
        guard !triggeredGateways.isEmpty else {
            return "Based on your responses, we'd like to learn more."
        }

        let gatewayNames = triggeredGateways.map { $0.displayName }
        if gatewayNames.count == 1 {
            return "Based on your response about \(gatewayNames[0].lowercased()), we'd like to understand this area better."
        } else if gatewayNames.count == 2 {
            return "Based on your responses about \(gatewayNames[0].lowercased()) and \(gatewayNames[1].lowercased()), we'd like to learn more."
        } else {
            let allButLast = gatewayNames.dropLast().joined(separator: ", ")
            return "Based on your responses about \(allButLast.lowercased()), and \(gatewayNames.last!.lowercased()), we'd like to understand these areas better."
        }
    }

    /// Short subtitle for the card
    var shortExplanation: String {
        if triggeredGateways.count == 1 {
            return "Understanding your \(triggeredGateways[0].displayName.lowercased())"
        } else {
            return "Personalized questions based on your answers"
        }
    }
}

// MARK: - Section Header View (Calm, minimal design)

struct SectionHeaderView: View {
    let section: QuestionnaireSection
    let currentQuestion: Int
    let totalQuestions: Int

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Simple, friendly header
            HStack {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: section.icon)
                        .font(.system(size: Typography.headline))
                        .foregroundColor(section.accentColor)

                    Text(section.title)
                        .font(.system(size: Typography.headline, weight: .semibold, design: .rounded))
                        .foregroundColor(section.descriptionTextColor)
                }

                Spacer()

                // Simple question counter
                Text("\(currentQuestion) of \(totalQuestions)")
                    .font(.system(size: Typography.subheadline, weight: .medium, design: .rounded))
                    .foregroundColor(section.descriptionTextColor.opacity(0.7))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(section.backgroundColor)
        }
    }
}

// MARK: - Section Progress View (Minimal, unobtrusive)

struct SectionProgressView: View {
    let section: QuestionnaireSection
    let currentIndex: Int
    let totalQuestions: Int

    var body: some View {
        // Simple thin progress bar
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(section.accentColor.opacity(0.15))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(section.accentColor)
                    .frame(width: geometry.size.width * CGFloat(currentIndex + 1) / CGFloat(max(totalQuestions, 1)), height: 4)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Section Transition View

struct SectionTransitionView: View {
    let fromSection: QuestionnaireSection
    let toSection: QuestionnaireSection
    let onContinue: () -> Void

    @State private var isAnimating = false
    @EnvironmentObject var themeManager: ThemeManager

    // Theme colors (uses centralized ColorTheme)
    private var theme: ColorTheme { themeManager.currentTheme }
    private var primaryTextColor: Color { theme.primaryText }
    private var secondaryTextColor: Color { theme.secondaryText }
    private var backgroundColor: Color { theme.cardBackground }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Completed section checkmark
            ZStack {
                Circle()
                    .fill(fromSection.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(fromSection.accentColor)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0)
            }

            VStack(spacing: 8) {
                Text("\(fromSection.title) Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(primaryTextColor)

                Text("Great job capturing last night's sleep")
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)
            }

            Divider()
                .background(secondaryTextColor.opacity(0.3))
                .padding(.horizontal, 40)

            // Next section preview
            VStack(spacing: 12) {
                Text("Up Next")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                    .textCase(.uppercase)
                    .tracking(1)

                HStack(spacing: 12) {
                    Image(systemName: toSection.icon)
                        .font(.title)
                        .foregroundColor(toSection.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(toSection.title)
                            .font(.headline)
                            .foregroundColor(toSection.accentColor)

                        Text(toSection.description)
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }
                }
                .padding()
                .background(toSection.backgroundColor)
                .cornerRadius(12)
            }

            Spacer()

            // Continue button
            Button(action: onContinue) {
                HStack {
                    Text("Continue to Assessment")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(toSection.accentColor)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(backgroundColor)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Section Question Card

struct SectionQuestionCard<Content: View>: View {
    let section: QuestionnaireSection
    let question: Question
    let content: () -> Content
    @EnvironmentObject var themeManager: ThemeManager

    // Theme colors (uses centralized ColorTheme)
    private var theme: ColorTheme { themeManager.currentTheme }
    private var questionTextColor: Color { theme.primaryText }
    private var secondaryTextColor: Color { theme.secondaryText }
    private var helpTextColor: Color { theme.secondaryText.opacity(0.9) }

    init(section: QuestionnaireSection, question: Question, @ViewBuilder content: @escaping () -> Content) {
        self.section = section
        self.question = question
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: section.icon)
                        .font(.caption)
                    Text(section == .sleepLog ? "SLEEP LOG" : question.pillar.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(section.accentColor)
                .cornerRadius(4)

                Spacer()

                if question.required {
                    Text("Required")
                        .font(.caption2)
                        .foregroundColor(secondaryTextColor)
                }
            }

            // Question text
            Text(question.text)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(questionTextColor)
                .fixedSize(horizontal: false, vertical: true)

            // Help text
            if let helpText = question.helpText {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(section.accentColor)
                        .font(.caption)
                    Text(helpText)
                        .font(.caption)
                        .foregroundColor(helpTextColor)
                }
                .padding(10)
                .background(section.backgroundColor)
                .cornerRadius(8)
            }

            // Answer content
            content()
        }
        .padding(16)
        .background(GlassyCardBackground(opacity: 0.4, tint: section.accentColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            section.accentColor.opacity(0.3),
                            section.accentColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Day Completion View

struct DayCompletionView: View {
    let dayNumber: Int
    let sleepLogQuestionsCount: Int
    let assessmentQuestionsCount: Int
    let triggeredGateways: [GatewayType]
    let onDone: () -> Void
    // New: Which section was just completed (nil means full day)
    var completedSection: QuestionnaireSection? = nil
    // New: Callback for proceeding to next section
    var onProceedToNextSection: (() -> Void)? = nil
    // Track actual completion status of each section (for accurate display)
    var completedSleepLog: Bool = false
    var completedAssessment: Bool = false

    @State private var isAnimating = false
    @State private var showConfetti = false
    @EnvironmentObject var themeManager: ThemeManager

    // Theme colors (uses centralized ColorTheme)
    private var theme: ColorTheme { themeManager.currentTheme }
    private var palette: CircadianPalette { themeManager.circadianPalette }
    private var primaryTextColor: Color { theme.primaryText }
    private var secondaryTextColor: Color { theme.secondaryText }
    private var viewBackgroundColor: Color { palette.backgroundStart }
    private var cardBackgroundColor: Color { theme.cardBackground }

    // Computed: Is this the final day of the 10-day journey?
    private var isJourneyComplete: Bool {
        dayNumber >= 10 && (isFullDayComplete || completedSection == .assessment)
    }

    // Computed: Is this a full day completion or section-only?
    private var isFullDayComplete: Bool {
        completedSection == nil
    }

    // Computed: Title text
    private var titleText: String {
        if isJourneyComplete {
            return "Journey Complete!"
        } else if isFullDayComplete {
            return "Day \(dayNumber) Complete!"
        } else if completedSection == .sleepLog {
            return "Sleep Log Complete!"
        } else {
            return "Assessment Complete!"
        }
    }

    // Computed: Subtitle text
    private var subtitleText: String {
        if isJourneyComplete {
            return "Thank you for completing your comprehensive sleep assessment"
        } else if isFullDayComplete {
            return "Great progress on your sleep journey"
        } else if completedSection == .sleepLog {
            // Only suggest assessment if there ARE assessment questions
            return assessmentQuestionsCount > 0 ? "Now let's complete the Day Assessment" : "Great progress on your sleep journey"
        } else {
            return "Great work!"
        }
    }

    var body: some View {
        if isJourneyComplete {
            journeyCompleteView
        } else {
            regularCompletionView
        }
    }

    // MARK: - Journey Complete View (Day 14 Final)

    private var journeyCompleteView: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 30)

                    // Trophy animation
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .scaleEffect(isAnimating ? 1.1 : 0.9)
                            .opacity(isAnimating ? 0.8 : 1)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.yellow, Color.orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                    }

                VStack(spacing: 12) {
                    Text("Congratulations!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(primaryTextColor)

                    Text("You've completed your 10-day comprehensive sleep assessment")
                        .font(.headline)
                        .foregroundColor(secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // What happens next card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "stethoscope")
                            .font(.title2)
                            .foregroundColor(QuestionnaireSection.assessment.accentColor)

                        Text("What Happens Next")
                            .font(.headline)
                            .foregroundColor(primaryTextColor)
                    }

                    Text("Your sleep medicine physician team will now analyze your responses and health data to create a personalized sleep intervention plan tailored specifically to you.")
                        .font(.body)
                        .foregroundColor(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()
                        .background(secondaryTextColor.opacity(0.3))

                    HStack(spacing: 16) {
                        VStack {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.title2)
                                .foregroundColor(QuestionnaireSection.assessment.accentColor)
                            Text("2-3 Days")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(primaryTextColor)
                            Text("Review Time")
                                .font(.caption2)
                                .foregroundColor(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)

                        VStack {
                            Image(systemName: "bell.badge")
                                .font(.title2)
                                .foregroundColor(QuestionnaireSection.assessment.accentColor)
                            Text("Notification")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(primaryTextColor)
                            Text("When Ready")
                                .font(.caption2)
                                .foregroundColor(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)

                        VStack {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.title2)
                                .foregroundColor(QuestionnaireSection.assessment.accentColor)
                            Text("Your Plan")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(primaryTextColor)
                            Text("Personalized")
                                .font(.caption2)
                                .foregroundColor(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
                .background(
                    GlassyCardBackground(opacity: 0.5)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                )
                .cornerRadius(16)
                .padding(.horizontal)

                // Summary stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Journey Summary")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryTextColor)

                    HStack(spacing: 20) {
                        VStack {
                            Text("15")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(QuestionnaireSection.assessment.accentColor)
                            Text("Days")
                                .font(.caption)
                                .foregroundColor(secondaryTextColor)
                        }

                        VStack {
                            Text("15")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(QuestionnaireSection.sleepLog.accentColor)
                            Text("Sleep Logs")
                                .font(.caption)
                                .foregroundColor(secondaryTextColor)
                        }

                        if !triggeredGateways.isEmpty {
                            VStack {
                                Text("\(triggeredGateways.count)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                Text("Deep Dives")
                                    .font(.caption)
                                    .foregroundColor(secondaryTextColor)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    GlassyCardBackground(opacity: 0.4)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                )
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer(minLength: 20)

                // Done button
                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                }
            }
            .background(viewBackgroundColor)

            // Confetti overlay for journey completion
            if showConfetti {
                ConfettiView(
                    particleCount: 150,
                    duration: 4.0,
                    onComplete: { showConfetti = false }
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            // Trigger confetti after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }

    // MARK: - Regular Day Completion View

    private var regularCompletionView: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Success animation
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isAnimating ? 1.2 : 0.8)
                            .opacity(isAnimating ? 0.5 : 1)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                            .scaleEffect(isAnimating ? 1.0 : 0.5)
                    }

                    VStack(spacing: 8) {
                        Text(titleText)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(primaryTextColor)

                        Text(subtitleText)
                            .font(.subheadline)
                            .foregroundColor(secondaryTextColor)
                    }

                    // Summary cards
                    VStack(spacing: 12) {
                        // Sleep Log summary - show completed or pending based on actual status
                        let sleepLogDone = isFullDayComplete || completedSection == .sleepLog || completedSleepLog
                        HStack {
                            Image(systemName: "moon.zzz.fill")
                                .foregroundColor(QuestionnaireSection.sleepLog.accentColor)

                            VStack(alignment: .leading) {
                                Text("Sleep Log")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(primaryTextColor)
                                if sleepLogDone {
                                    Text("\(sleepLogQuestionsCount) questions completed")
                                        .font(.caption)
                                        .foregroundColor(secondaryTextColor)
                                } else {
                                    Text("\(sleepLogQuestionsCount) questions remaining")
                                        .font(.caption)
                                        .foregroundColor(QuestionnaireSection.sleepLog.accentColor)
                                }
                            }

                            Spacer()

                            if sleepLogDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(QuestionnaireSection.sleepLog.accentColor)
                            }
                        }
                        .padding()
                        .background(QuestionnaireSection.sleepLog.backgroundColor)
                        .cornerRadius(12)

                        // Assessment summary - only show if there are assessment questions OR assessment was completed
                        // This prevents showing "0 questions remaining" on days with no assessment
                        if assessmentQuestionsCount > 0 || completedAssessment {
                            let assessmentDone = isFullDayComplete || completedSection == .assessment || completedAssessment
                            let canProceed = completedSection == .sleepLog && !assessmentDone && onProceedToNextSection != nil

                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "clipboard.fill")
                                        .font(.title2)
                                        .foregroundColor(QuestionnaireSection.assessment.accentColor)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Day Assessment")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(primaryTextColor)
                                        if assessmentDone {
                                            Text("\(assessmentQuestionsCount) questions completed")
                                                .font(.subheadline)
                                                .foregroundColor(secondaryTextColor)
                                        } else {
                                            Text("\(assessmentQuestionsCount) questions remaining")
                                                .font(.subheadline)
                                                .foregroundColor(QuestionnaireSection.assessment.accentColor)
                                        }
                                    }

                                    Spacer()

                                    if assessmentDone {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()

                                // Embedded Proceed button when assessment is available
                                if canProceed {
                                    Divider()
                                        .background(QuestionnaireSection.assessment.accentColor.opacity(0.3))

                                    Button(action: {
                                        onProceedToNextSection?()
                                    }) {
                                        HStack {
                                            Text("Proceed")
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                            Image(systemName: "arrow.right")
                                                .font(.headline)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(QuestionnaireSection.assessment.accentColor)
                                    }
                                }
                            }
                            .background(QuestionnaireSection.assessment.backgroundColor)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(canProceed ? QuestionnaireSection.assessment.accentColor : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Gateway triggers (if any)
                    if !triggeredGateways.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Personalized Assessments Added")
                                .font(.caption)
                                .foregroundColor(secondaryTextColor)
                                .textCase(.uppercase)
                                .tracking(1)

                            Text("Based on your responses, we've added these assessments to your journey:")
                                .font(.subheadline)
                                .foregroundColor(secondaryTextColor)

                            FlowLayout(spacing: 8) {
                                ForEach(triggeredGateways, id: \.self) { gateway in
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.caption)
                                        Text(gateway.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(QuestionnaireSection.assessment.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(QuestionnaireSection.assessment.backgroundColor)
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding()
                        .background(
                            GlassyCardBackground(opacity: 0.4)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        )
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)

                    // Continue button - only show when day is complete or no assessment to proceed to
                    // (Proceed action is now embedded in the Assessment card above)
                    if completedSection != .sleepLog || assessmentQuestionsCount == 0 {
                        Button(action: onDone) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(viewBackgroundColor)

            // Confetti overlay for day/section completion
            if showConfetti {
                ConfettiView(
                    particleCount: isFullDayComplete ? 100 : 60,
                    duration: 3.0,
                    onComplete: { showConfetti = false }
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            // Trigger confetti for full day or assessment completion (not just sleep log)
            if isFullDayComplete || completedSection == .assessment {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                }
            }
        }
    }
}

// MARK: - Flow Layout for Gateway Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            height = currentY + lineHeight
        }
    }
}

// MARK: - Preview

#Preview("Section Header - Sleep Log") {
    SectionHeaderView(section: .sleepLog, currentQuestion: 2, totalQuestions: 5)
}

#Preview("Section Header - Assessment") {
    SectionHeaderView(section: .assessment, currentQuestion: 5, totalQuestions: 12)
}

#Preview("Section Transition") {
    SectionTransitionView(
        fromSection: .sleepLog,
        toSection: .assessment,
        onContinue: {}
    )
}

#Preview("Day Completion - Full Day") {
    DayCompletionView(
        dayNumber: 3,
        sleepLogQuestionsCount: 5,
        assessmentQuestionsCount: 8,
        triggeredGateways: [.insomnia, .anxiety],
        onDone: {}
    )
}

#Preview("Day Completion - Sleep Log Only") {
    DayCompletionView(
        dayNumber: 2,
        sleepLogQuestionsCount: 5,
        assessmentQuestionsCount: 11,
        triggeredGateways: [],
        onDone: {},
        completedSection: .sleepLog,
        onProceedToNextSection: {},
        completedSleepLog: true,
        completedAssessment: false
    )
}

#Preview("Day Completion - Assessment Only (Sleep Log Skipped)") {
    DayCompletionView(
        dayNumber: 3,
        sleepLogQuestionsCount: 16,
        assessmentQuestionsCount: 10,
        triggeredGateways: [],
        onDone: {},
        completedSection: .assessment,
        completedSleepLog: false,
        completedAssessment: true
    )
}

// MARK: - Empty Assessment View
// Shows when user navigates to assessment but there are no questions
// This can happen on expansion days (6-14) when required gateways weren't triggered

struct EmptyAssessmentView: View {
    let dayNumber: Int
    let onDismiss: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    // Theme colors (uses centralized ColorTheme)
    private var theme: ColorTheme { themeManager.currentTheme }
    private var palette: CircadianPalette { themeManager.circadianPalette }
    private var backgroundColor: Color { palette.backgroundStart }
    private var primaryTextColor: Color { theme.primaryText }
    private var secondaryTextColor: Color { theme.secondaryText }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(theme.success.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(theme.success)
            }

            VStack(spacing: 12) {
                Text("You're All Caught Up!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(primaryTextColor)

                Text("Based on your responses, no additional questions are needed for Day \(dayNumber).")
                    .font(.body)
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(theme.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.success)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(backgroundColor)
    }
}

// MARK: - Expansion Pack Intro View
// Shows before expansion questions to explain why they were triggered

struct ExpansionPackIntroView: View {
    let expansionInfo: ExpansionPackInfo
    let onContinue: () -> Void
    let onSkip: (() -> Void)?  // Optional - allow skipping if not mandatory

    @State private var isAnimating = false
    @EnvironmentObject var themeManager: ThemeManager

    // Theme colors (uses centralized ColorTheme)
    private var theme: ColorTheme { themeManager.currentTheme }
    private var palette: CircadianPalette { themeManager.circadianPalette }
    private var primaryTextColor: Color { theme.primaryText }
    private var secondaryTextColor: Color { theme.secondaryText }
    private var backgroundColor: Color { palette.backgroundStart }
    private var cardBackgroundColor: Color { theme.cardBackground }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Sparkle icon animation
            ZStack {
                Circle()
                    .fill(QuestionnaireSection.expansionPack.accentColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)

                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundColor(QuestionnaireSection.expansionPack.accentColor)
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
            }

            // Title
            VStack(spacing: 8) {
                Text("Deeper Dive")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(primaryTextColor)

                Text("Personalized for you")
                    .font(.subheadline)
                    .foregroundColor(QuestionnaireSection.expansionPack.accentColor)
            }

            // Explanation card
            VStack(alignment: .leading, spacing: 16) {
                // Why these questions
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundColor(QuestionnaireSection.expansionPack.accentColor)

                    Text(expansionInfo.triggerExplanation)
                        .font(.body)
                        .foregroundColor(primaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                    .background(secondaryTextColor.opacity(0.3))

                // What to expect
                HStack(spacing: 20) {
                    // Question count
                    VStack(spacing: 4) {
                        Text("\(expansionInfo.questions.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(QuestionnaireSection.expansionPack.accentColor)
                        Text("questions")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }

                    // Divider
                    Rectangle()
                        .fill(secondaryTextColor.opacity(0.3))
                        .frame(width: 1, height: 40)

                    // Time estimate
                    VStack(spacing: 4) {
                        Text("~\(expansionInfo.totalEstimatedMinutes)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(QuestionnaireSection.expansionPack.accentColor)
                        Text("minutes")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }

                    Spacer()
                }

                // Triggered gateways tags
                if !expansionInfo.triggeredGateways.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Areas we'll explore:")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        FlowLayout(spacing: 8) {
                            ForEach(expansionInfo.triggeredGateways, id: \.self) { gateway in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                    Text(gateway.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(QuestionnaireSection.expansionPack.accentColor)
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(
                GlassyCardBackground(opacity: 0.5, tint: QuestionnaireSection.expansionPack.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(QuestionnaireSection.expansionPack.accentColor.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)

            // Reassurance
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                Text("Your answers help us create a personalized sleep plan")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    HStack {
                        Text("Let's dive in")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(QuestionnaireSection.expansionPack.accentColor)
                    .cornerRadius(12)
                }

                if let skip = onSkip {
                    Button(action: skip) {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(backgroundColor)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview("Expansion Pack Intro") {
    ExpansionPackIntroView(
        expansionInfo: ExpansionPackInfo(
            triggeredGateways: [.insomnia, .poorSleepQuality],
            questions: [],
            totalEstimatedMinutes: 8
        ),
        onContinue: {},
        onSkip: {}
    )
}
