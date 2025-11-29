//
//  QuestionnaireSections.swift
//  Zoe Sleep for Longevity System
//
//  Distinct visual sections for Stanford Sleep Log vs Day Assessments
//

import SwiftUI

// MARK: - Section Type

enum QuestionnaireSection: String, CaseIterable {
    case sleepLog = "sleep_log"
    case assessment = "assessment"

    var title: String {
        switch self {
        case .sleepLog: return "Daily Sleep Log"
        case .assessment: return "Day Assessment"
        }
    }

    var subtitle: String {
        switch self {
        case .sleepLog: return "Stanford Sleep Diary"
        case .assessment: return "About your typical patterns"
        }
    }

    var description: String {
        switch self {
        case .sleepLog: return "About last night's sleep..."
        case .assessment: return "Understanding your sleep patterns..."
        }
    }

    var icon: String {
        switch self {
        case .sleepLog: return "moon.zzz.fill"
        case .assessment: return "clipboard.fill"
        }
    }

    /// Background color - Sleep Log: blue tint, Assessment: purple tint
    var backgroundColor: Color {
        switch self {
        case .sleepLog: return Color(red: 0.13, green: 0.59, blue: 0.95).opacity(0.1)  // Blue
        case .assessment: return Color(red: 0.61, green: 0.35, blue: 0.71).opacity(0.15)  // Purple
        }
    }

    /// Accent color - Sleep Log: blue, Assessment: purple
    var accentColor: Color {
        switch self {
        case .sleepLog: return Color(red: 0.13, green: 0.59, blue: 0.95)  // #2196F3
        case .assessment: return Color(red: 0.61, green: 0.35, blue: 0.71)  // #9C27B0
        }
    }

    /// Header gradient
    var headerGradient: LinearGradient {
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
        }
    }
}

// MARK: - Section Header View

struct SectionHeaderView: View {
    let section: QuestionnaireSection
    let currentQuestion: Int
    let totalQuestions: Int

    var body: some View {
        VStack(spacing: 0) {
            // Colored header bar
            HStack {
                Image(systemName: section.icon)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1)

                    Text(section.subtitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(currentQuestion)/\(totalQuestions)")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("questions")
                        .font(.caption2)
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(section.headerGradient)

            // Subtitle bar
            HStack {
                Text(section.description)
                    .font(.subheadline)
                    .foregroundColor(section.accentColor)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(section.backgroundColor)
        }
    }
}

// MARK: - Section Progress View

struct SectionProgressView: View {
    let section: QuestionnaireSection
    let currentIndex: Int
    let totalQuestions: Int

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(section.backgroundColor)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(section.accentColor)
                        .frame(width: geometry.size.width * CGFloat(currentIndex + 1) / CGFloat(totalQuestions), height: 8)
                }
            }
            .frame(height: 8)

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalQuestions, id: \.self) { index in
                    Circle()
                        .fill(index <= currentIndex ? section.accentColor : section.backgroundColor)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(section.accentColor.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Section Transition View

struct SectionTransitionView: View {
    let fromSection: QuestionnaireSection
    let toSection: QuestionnaireSection
    let onContinue: () -> Void

    @State private var isAnimating = false

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

                Text("Great job capturing last night's sleep")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.horizontal, 40)

            // Next section preview
            VStack(spacing: 12) {
                Text("Up Next")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
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
        .background(Color(.systemBackground))
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
                        .foregroundColor(.secondary)
                }
            }

            // Question text
            Text(question.text)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Help text
            if let helpText = question.helpText {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(section.accentColor)
                        .font(.caption)
                    Text(helpText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(section.backgroundColor)
                .cornerRadius(8)
            }

            // Answer content
            content()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: section.accentColor.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(section.backgroundColor, lineWidth: 2)
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

    @State private var isAnimating = false

    var body: some View {
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
                    Text("Day \(dayNumber) Complete!")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Great progress on your sleep journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Summary cards
                VStack(spacing: 12) {
                    // Sleep Log summary
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundColor(QuestionnaireSection.sleepLog.accentColor)

                        VStack(alignment: .leading) {
                            Text("Sleep Log")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(sleepLogQuestionsCount) questions completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(QuestionnaireSection.sleepLog.backgroundColor)
                    .cornerRadius(12)

                    // Assessment summary
                    HStack {
                        Image(systemName: "clipboard.fill")
                            .foregroundColor(QuestionnaireSection.assessment.accentColor)

                        VStack(alignment: .leading) {
                            Text("Day Assessment")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(assessmentQuestionsCount) questions completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(QuestionnaireSection.assessment.backgroundColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // Gateway triggers (if any)
                if !triggeredGateways.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Personalized Assessments Added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)

                        Text("Based on your responses, we've added these assessments to your journey:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

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
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)

                // Done button
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
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
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

#Preview("Day Completion") {
    DayCompletionView(
        dayNumber: 3,
        sleepLogQuestionsCount: 5,
        assessmentQuestionsCount: 8,
        triggeredGateways: [.insomnia, .anxiety],
        onDone: {}
    )
}
