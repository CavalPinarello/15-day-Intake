//
//  AnalysisPendingView.swift
//  Zoe Sleep for Longevity System
//
//  Shows analysis progress stages while physician reviews data
//  Displays 4-stage timeline: Data collected → Patterns identified → Preparing → Ready
//

import SwiftUI

struct AnalysisPendingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var journeyManager = JourneyPhaseManager.shared

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection

                // Progress Animation
                progressAnimation

                // Stage Timeline
                stageTimeline

                // Current Stage Detail
                currentStageCard

                // Encouragement Message
                encouragementCard

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(theme.backgroundGradient)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(theme.accent)

            Text("Analyzing Your Sleep")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.primaryText)

            Text("Our team is reviewing your 15 days of data")
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Progress Animation

    private var progressAnimation: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(theme.secondaryText.opacity(0.2), lineWidth: 8)
                .frame(width: 120, height: 120)

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(journeyManager.analysisStage) / 4.0)
                .stroke(
                    AngularGradient(
                        colors: [theme.accent, theme.accent.opacity(0.6)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: journeyManager.analysisStage)

            // Center content
            VStack(spacing: 4) {
                Text("\(journeyManager.analysisStage)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(theme.primaryText)
                Text("of 4")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
        }
    }

    // MARK: - Stage Timeline

    private var stageTimeline: some View {
        VStack(spacing: 0) {
            ForEach(journeyManager.analysisStages) { stage in
                HStack(alignment: .top, spacing: 16) {
                    // Icon with connector
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(stageBackgroundColor(for: stage))
                                .frame(width: 40, height: 40)

                            Image(systemName: stageIcon(for: stage))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(stageIconColor(for: stage))
                        }

                        // Connector line (except for last)
                        if stage.id < 4 {
                            Rectangle()
                                .fill(stage.isComplete ? theme.accent : theme.secondaryText.opacity(0.2))
                                .frame(width: 2, height: 40)
                        }
                    }

                    // Stage content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stage.title)
                                .font(.headline)
                                .foregroundColor(stage.isCurrent ? theme.primaryText : (stage.isComplete ? theme.secondaryText : theme.secondaryText.opacity(0.5)))

                            if stage.isCurrent {
                                Text("Current")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(theme.accent)
                                    .cornerRadius(10)
                            }
                        }

                        Text(stage.description)
                            .font(.caption)
                            .foregroundColor(theme.secondaryText.opacity(stage.isCurrent || stage.isComplete ? 1 : 0.5))
                            .lineLimit(2)
                    }
                    .padding(.bottom, stage.id < 4 ? 24 : 0)

                    Spacer()
                }
            }
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Current Stage Card

    private var currentStageCard: some View {
        VStack(spacing: 16) {
            if let currentStage = journeyManager.analysisStages.first(where: { $0.isCurrent }) {
                HStack {
                    Image(systemName: currentStage.icon)
                        .font(.title2)
                        .foregroundColor(theme.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Status")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                        Text(currentStage.title)
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                    }

                    Spacer()

                    // Animated indicator
                    if journeyManager.analysisStage < 4 {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }

                Text(currentStage.description)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Action button for stage 4
                if journeyManager.analysisStage == 4 {
                    Button(action: {
                        // Navigate to treatment view
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("View Your Treatment Plan")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.accent)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Encouragement Card

    private var encouragementCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundColor(.pink)

            VStack(alignment: .leading, spacing: 4) {
                Text("Thank you for completing your journey!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.primaryText)

                Text("Your detailed sleep data helps us create a truly personalized plan for you.")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground.opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func stageBackgroundColor(for stage: AnalysisStage) -> Color {
        if stage.isComplete {
            return theme.accent
        } else if stage.isCurrent {
            return theme.accent.opacity(0.2)
        } else {
            return theme.secondaryText.opacity(0.1)
        }
    }

    private func stageIconColor(for stage: AnalysisStage) -> Color {
        if stage.isComplete {
            return .white
        } else if stage.isCurrent {
            return theme.accent
        } else {
            return theme.secondaryText.opacity(0.5)
        }
    }

    private func stageIcon(for stage: AnalysisStage) -> String {
        if stage.isComplete {
            return "checkmark"
        }
        return stage.icon
    }
}

// MARK: - Preview

#Preview {
    AnalysisPendingView()
        .environmentObject(ThemeManager.shared)
}
