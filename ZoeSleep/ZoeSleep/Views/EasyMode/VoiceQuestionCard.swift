//
//  VoiceQuestionCard.swift
//  ZoeSleep
//
//  Large, accessible question display for Easy Mode
//  Shows question text with TTS indicator and auto-reads aloud
//

import SwiftUI

/// Large question display card for Easy Mode
/// Shows question with tappable options as fallback when voice isn't working
struct VoiceQuestionCard: View {
    let question: Question
    let questionNumber: Int
    let totalQuestions: Int
    let onOptionSelected: ((String) -> Void)?  // Callback when user taps an option

    @ObservedObject var easyModeManager = EasyModeManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    @State private var hasReadQuestion = false

    private var theme: ColorTheme { themeManager.currentTheme }

    init(question: Question, questionNumber: Int, totalQuestions: Int, onOptionSelected: ((String) -> Void)? = nil) {
        self.question = question
        self.questionNumber = questionNumber
        self.totalQuestions = totalQuestions
        self.onOptionSelected = onOptionSelected
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Progress indicator
            progressHeader

            // Question text
            questionContent

            // Help text (if available)
            if let helpText = question.helpText, !helpText.isEmpty {
                helpTextView(helpText)
            }
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(theme.cardBackground)
        )
        // NOTE: Auto-reading is now handled by EasyModeQuestionnaireView's speakAndAutoRecord()
        // This card only displays the question, it doesn't control TTS timing
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack {
            // TTS indicator
            if easyModeManager.isSpeaking {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accent)
                        .symbolEffect(.variableColor)

                    Text("Reading...")
                        .font(.system(size: Typography.subheadline, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                }
            }

            Spacer()

            // Question counter
            Text("Question \(questionNumber) of \(totalQuestions)")
                .font(.system(size: Typography.headline, weight: .semibold, design: .rounded))
                .foregroundColor(theme.secondaryText)
        }
    }

    // MARK: - Question Content

    private var questionContent: some View {
        VStack(spacing: Spacing.md) {
            Text(question.text)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(question.text)

            // Options hint for select questions
            if let options = question.options, !options.isEmpty {
                optionsHint(options)
            }

            // Scale hint for scale questions
            if question.questionType == .scale {
                scaleHint
            }
        }
    }

    // MARK: - Tappable Options

    @ViewBuilder
    private func optionsHint(_ options: [String]) -> some View {
        VStack(spacing: Spacing.sm) {
            Text("Tap an option or speak your answer:")
                .font(.system(size: Typography.subheadline, weight: .medium))
                .foregroundColor(theme.secondaryText)

            // Show options as tappable buttons
            FlowLayout(spacing: Spacing.sm) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()

                        onOptionSelected?(option)
                    }) {
                        Text(option)
                            .font(.system(size: Typography.body, weight: .medium))
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(theme.accent.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Scale Hint

    private var scaleHint: some View {
        HStack {
            if let minLabel = question.scaleMinLabel {
                Text("1 = \(minLabel)")
                    .font(.system(size: Typography.subheadline))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            if let maxLabel = question.scaleMaxLabel {
                Text("10 = \(maxLabel)")
                    .font(.system(size: Typography.subheadline))
                    .foregroundColor(theme.secondaryText)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
    }

    // MARK: - Help Text

    @ViewBuilder
    private func helpTextView(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 18))
                .foregroundColor(theme.accent)

            Text(text)
                .font(.system(size: Typography.subheadline))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.leading)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(theme.accent.opacity(0.08))
        )
    }

    // MARK: - TTS

    private func readQuestionAloud() {
        guard !hasReadQuestion else { return }
        hasReadQuestion = true

        // Build the text to read
        var textToRead = question.text

        // Add options for select questions
        if let options = question.options, !options.isEmpty {
            let optionsText = options.joined(separator: ", or ")
            textToRead += ". Your options are: \(optionsText)"
        }

        // Add scale description
        if question.questionType == .scale {
            if let minLabel = question.scaleMinLabel, let maxLabel = question.scaleMaxLabel {
                textToRead += ". On a scale of 1 to 10, where 1 means \(minLabel) and 10 means \(maxLabel)."
            }
        }

        Task {
            await easyModeManager.speakQuestion(textToRead)
        }
    }
}

// MARK: - Transcription Confirmation View

/// Shows the transcribed answer for user confirmation
struct TranscriptionConfirmView: View {
    let parsedResponse: ParsedResponse
    let onConfirm: () -> Void
    let onRetry: () -> Void
    let onEdit: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var easyModeManager = EasyModeManager.shared

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            Text("I heard:")
                .font(.system(size: Typography.headline, weight: .medium))
                .foregroundColor(theme.secondaryText)

            // Transcript
            Text("\"\(parsedResponse.transcript)\"")
                .font(.system(size: Typography.title3, weight: .regular, design: .rounded))
                .foregroundColor(theme.primaryText.opacity(0.7))
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            // Parsed value
            VStack(spacing: Spacing.sm) {
                Text("Understood as:")
                    .font(.system(size: Typography.subheadline, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                Text(parsedResponse.displayValue)
                    .font(.system(size: Typography.title2, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primaryText)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(theme.accent.opacity(0.1))
            )

            // Confidence indicator
            if !parsedResponse.isHighConfidence {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(theme.warning)
                    Text("I'm not 100% sure. Please confirm or try again.")
                        .font(.system(size: Typography.subheadline))
                        .foregroundColor(theme.warning)
                }
                .padding(Spacing.sm)
            }

            // Alternative interpretations
            if let alternatives = parsedResponse.alternativeInterpretations, !alternatives.isEmpty {
                alternativesView(alternatives)
            }

            // Action buttons
            actionButtons
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(theme.cardBackground)
        )
    }

    @ViewBuilder
    private func alternativesView(_ alternatives: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Did you mean:")
                .font(.system(size: Typography.subheadline, weight: .medium))
                .foregroundColor(theme.secondaryText)

            ForEach(alternatives, id: \.self) { alternative in
                Button(action: {
                    // Could add selection of alternative here
                }) {
                    Text(alternative)
                        .font(.system(size: Typography.body))
                        .foregroundColor(theme.primaryText)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
                                .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: Spacing.md) {
            // Retry button
            Button(action: onRetry) {
                Label("Try Again", systemImage: "mic.fill")
                    .font(.system(size: Typography.headline, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(theme.accent, lineWidth: 2)
                    )
            }
            .frame(height: 60)

            // Confirm button
            Button(action: onConfirm) {
                Label("Correct", systemImage: "checkmark")
                    .font(.system(size: Typography.headline, weight: .semibold))
                    .foregroundColor(theme.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(theme.success)
                    )
            }
            .frame(height: 60)
        }
    }
}

// MARK: - Preview

#Preview("Voice Question Card") {
    let question = Question(
        id: "test",
        text: "How would you rate the quality of your sleep last night?",
        pillar: .sleepQuality,
        tier: .core,
        questionType: .scale,
        estimatedMinutes: 0.5,
        required: true,
        options: nil,
        scaleMin: 0,
        scaleMax: 10,
        scaleMinLabel: "Very poor",
        scaleMaxLabel: "Excellent",
        minValue: nil,
        maxValue: nil,
        step: nil,
        unit: nil,
        defaultValue: nil,
        unitImperial: nil,
        defaultImperial: nil,
        helpText: "Think about how rested you felt when you woke up this morning.",
        helpTextImperial: nil,
        isGateway: false,
        gatewayType: nil,
        gatewayThreshold: nil,
        conditionalLogic: nil,
        group: nil,
        repeatingFields: nil
    )

    VStack(spacing: 30) {
        VoiceQuestionCard(
            question: question,
            questionNumber: 3,
            totalQuestions: 8
        )

        TranscriptionConfirmView(
            parsedResponse: ParsedResponse(
                transcript: "about a seven",
                value: .number(7),
                confidence: 0.85,
                alternativeInterpretations: nil
            ),
            onConfirm: {},
            onRetry: {},
            onEdit: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
