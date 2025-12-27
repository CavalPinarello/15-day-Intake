//
//  MockPlaybackView.swift
//  ZoeSleep
//
//  Visual UI for mock data generation
//  Shows real-time progress as data is generated
//

#if DEBUG

import SwiftUI

struct MockPlaybackView: View {
    @StateObject private var controller = MockPlaybackController()
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var isRepairingSleepData = false
    @State private var repairResult: String?

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                theme.backgroundTint
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        switch controller.state {
                        case .idle:
                            idleView
                        case .preparing:
                            preparingView
                        case .generatingDay, .savingDay, .transitioning, .computingScores:
                            generatingView
                        case .completed:
                            completedView
                        case .cancelled:
                            cancelledView
                        case .failed(let error):
                            failedView(error: error)
                        }
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("Mock Data Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            Image(systemName: "wand.and.stars")
                .font(.system(size: 60))
                .foregroundColor(.purple)
                .padding(.top, Spacing.xl)

            // Title
            Text("Generate Mock Patient Data")
                .font(.system(size: Typography.title3, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            // Description
            Text("This will generate 15 days of realistic questionnaire responses for testing the physician dashboard.")
                .font(.system(size: Typography.body))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Warning card
            warningCard

            // Stats preview
            statsPreview

            // Start button
            Button {
                controller.startGeneration()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Generation")
                }
                .font(.system(size: Typography.headline, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.purple)
                .cornerRadius(CornerRadius.medium)
            }
            .padding(.top, Spacing.md)

            // Repair sleep insights button
            repairSleepDataSection
        }
    }

    private var repairSleepDataSection: some View {
        VStack(spacing: Spacing.sm) {
            Divider()
                .padding(.vertical, Spacing.sm)

            Text("Already have data?")
                .font(.system(size: Typography.caption, weight: .medium))
                .foregroundColor(theme.textSecondary)

            Button {
                repairSleepData()
            } label: {
                HStack {
                    if isRepairingSleepData {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.blue)
                    } else {
                        Image(systemName: "wrench.and.screwdriver.fill")
                    }
                    Text(isRepairingSleepData ? "Processing..." : "Repair Sleep Insights Data")
                }
                .font(.system(size: Typography.subheadline, weight: .medium))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(CornerRadius.medium)
            }
            .disabled(isRepairingSleepData)

            Text("Computes sleep metrics from existing questionnaire responses to populate Sleep Insights dashboard")
                .font(.system(size: Typography.caption2))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            if let result = repairResult {
                HStack {
                    Image(systemName: result.contains("Error") ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(result.contains("Error") ? .red : .green)
                    Text(result)
                        .font(.system(size: Typography.caption))
                        .foregroundColor(result.contains("Error") ? .red : .green)
                }
                .padding(.vertical, Spacing.xs)
            }
        }
    }

    private func repairSleepData() {
        isRepairingSleepData = true
        repairResult = nil

        Task {
            do {
                let daysProcessed = try await ConvexService.shared.computeAllSleepMetricsFromResponses()
                await MainActor.run {
                    repairResult = "Success! Processed \(daysProcessed) days of sleep data"
                    isRepairingSleepData = false
                }
            } catch {
                await MainActor.run {
                    repairResult = "Error: \(error.localizedDescription)"
                    isRepairingSleepData = false
                }
            }
        }
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title2)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Warning")
                    .font(.system(size: Typography.subheadline, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text("This will reset and overwrite all existing questionnaire data for the current user.")
                    .font(.system(size: Typography.caption))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(CornerRadius.medium)
    }

    private var statsPreview: some View {
        VStack(spacing: Spacing.sm) {
            Text("What will be generated:")
                .font(.system(size: Typography.caption, weight: .medium))
                .foregroundColor(theme.textSecondary)

            HStack(spacing: Spacing.lg) {
                MockStatBadge(icon: "calendar", value: "15", label: "Days")
                MockStatBadge(icon: "list.bullet", value: "~200", label: "Questions")
                MockStatBadge(icon: "clock", value: "~2", label: "Minutes")
            }
        }
        .padding(Spacing.md)
        .background(theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    // MARK: - Preparing State

    private var preparingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .padding(.top, Spacing.xl)

            Text("Resetting Progress...")
                .font(.system(size: Typography.headline, weight: .medium))
                .foregroundColor(theme.textPrimary)

            Text("Clearing existing data and preparing for mock generation")
                .font(.system(size: Typography.body))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Generating State

    private var generatingView: some View {
        VStack(spacing: Spacing.lg) {
            // Day progress
            dayProgressSection

            // Current section
            currentSectionCard

            // Current question
            currentQuestionCard

            // Triggered gateways
            if !controller.progress.triggeredGateways.isEmpty {
                gatewaysSection
            }

            // Stats
            generationStatsSection

            // Debug log (collapsible)
            debugLogSection

            // Cancel button
            Button {
                controller.cancel()
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Cancel")
                }
                .font(.system(size: Typography.subheadline, weight: .medium))
                .foregroundColor(.red)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.lg)
                .background(Color.red.opacity(0.1))
                .cornerRadius(CornerRadius.pill)
            }
        }
    }

    private var debugLogSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Log")
                .font(.system(size: Typography.caption, weight: .medium))
                .foregroundColor(theme.textSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(controller.debugLog.suffix(10), id: \.self) { log in
                        Text(log)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(log.contains("warning") || log.contains("FAILED") ? .orange : theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
        }
        .padding(Spacing.sm)
        .background(Color.black.opacity(0.05))
        .cornerRadius(CornerRadius.small)
    }

    private var dayProgressSection: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("Day \(controller.progress.currentDay)")
                    .font(.system(size: Typography.title3, weight: .bold))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Text("\(controller.progress.currentDay) of \(controller.progress.totalDays)")
                    .font(.system(size: Typography.subheadline))
                    .foregroundColor(theme.textSecondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geometry.size.width * controller.progress.dayProgress, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: controller.progress.dayProgress)
                }
            }
            .frame(height: 8)
        }
        .padding(Spacing.md)
        .background(theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    private var currentSectionCard: some View {
        HStack {
            Image(systemName: controller.progress.currentSection == "Sleep Log" ? "moon.zzz.fill" : "clipboard.fill")
                .foregroundColor(.purple)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(controller.progress.currentSection)
                    .font(.system(size: Typography.subheadline, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text("Question \(controller.progress.currentQuestionIndex) of \(controller.progress.totalQuestionsForSection)")
                    .font(.system(size: Typography.caption))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            // Section progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: controller.progress.sectionProgress)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: controller.progress.sectionProgress)

                Text("\(Int(controller.progress.sectionProgress * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(Spacing.md)
        .background(theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    private var currentQuestionCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Question ID
            Text(controller.progress.currentQuestionId)
                .font(.system(size: Typography.caption, weight: .medium, design: .monospaced))
                .foregroundColor(.purple)

            // Question text
            Text(controller.progress.currentQuestionText)
                .font(.system(size: Typography.body))
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)

            // Answer
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)

                Text(controller.progress.currentAnswer)
                    .font(.system(size: Typography.subheadline, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.top, Spacing.xxs)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    private var gatewaysSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Triggered Gateways")
                .font(.system(size: Typography.caption, weight: .medium))
                .foregroundColor(theme.textSecondary)

            FlowLayout(spacing: Spacing.xs) {
                ForEach(controller.progress.triggeredGateways, id: \.self) { gateway in
                    Text(gateway.displayName)
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.orange)
                        .cornerRadius(CornerRadius.pill)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    private var generationStatsSection: some View {
        HStack(spacing: Spacing.lg) {
            MockStatBadge(
                icon: "checkmark.circle",
                value: "\(controller.progress.totalQuestionsAnswered)",
                label: "Answered"
            )

            MockStatBadge(
                icon: "clock",
                value: formatTime(controller.progress.elapsedTime),
                label: "Elapsed"
            )
        }
        .padding(Spacing.md)
        .background(theme.cardBackground)
        .cornerRadius(CornerRadius.medium)
    }

    // MARK: - Completed State

    private var completedView: some View {
        VStack(spacing: Spacing.lg) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.top, Spacing.xl)

            Text("Generation Complete!")
                .font(.system(size: Typography.title3, weight: .bold))
                .foregroundColor(theme.textPrimary)

            Text("15 days of mock questionnaire data has been generated successfully.")
                .font(.system(size: Typography.body))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            // Final stats
            VStack(spacing: Spacing.sm) {
                HStack {
                    Text("Total Questions")
                    Spacer()
                    Text("\(controller.progress.totalQuestionsAnswered)")
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Time Elapsed")
                    Spacer()
                    Text(formatTime(controller.progress.elapsedTime))
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Gateways Triggered")
                    Spacer()
                    Text("\(controller.progress.triggeredGateways.count)")
                        .fontWeight(.semibold)
                }
            }
            .font(.system(size: Typography.body))
            .foregroundColor(theme.textPrimary)
            .padding(Spacing.md)
            .background(theme.cardBackground)
            .cornerRadius(CornerRadius.medium)

            // Triggered gateways list
            if !controller.progress.triggeredGateways.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Expansion Modules Unlocked")
                        .font(.system(size: Typography.caption, weight: .medium))
                        .foregroundColor(theme.textSecondary)

                    ForEach(controller.progress.triggeredGateways, id: \.self) { gateway in
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                            Text(gateway.displayName)
                                .foregroundColor(theme.textPrimary)
                        }
                        .font(.system(size: Typography.subheadline))
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.cardBackground)
                .cornerRadius(CornerRadius.medium)
            }

            // Done button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: Typography.headline, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color.green)
                    .cornerRadius(CornerRadius.medium)
            }
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Cancelled State

    private var cancelledView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.top, Spacing.xl)

            Text("Generation Cancelled")
                .font(.system(size: Typography.title3, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text("Partial data may have been saved. You can start over or close this view.")
                .font(.system(size: Typography.body))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: Spacing.md) {
                Button {
                    controller.reset()
                } label: {
                    Text("Start Over")
                        .font(.system(size: Typography.subheadline, weight: .medium))
                        .foregroundColor(.purple)
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.lg)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(CornerRadius.pill)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: Typography.subheadline, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.lg)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(CornerRadius.pill)
                }
            }
        }
    }

    // MARK: - Failed State

    private func failedView(error: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
                .padding(.top, Spacing.xl)

            Text("Generation Failed")
                .font(.system(size: Typography.title3, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text(error)
                .font(.system(size: Typography.body))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: Spacing.md) {
                Button {
                    controller.reset()
                    controller.startGeneration()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.system(size: Typography.subheadline, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.lg)
                    .background(Color.purple)
                    .cornerRadius(CornerRadius.pill)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: Typography.subheadline, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.lg)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(CornerRadius.pill)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Supporting Views

struct MockStatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)

            Text(value)
                .font(.system(size: Typography.headline, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: Typography.caption))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 70)
    }
}

// MARK: - Preview
// Note: FlowLayout is defined in QuestionnaireSections.swift

struct MockPlaybackView_Previews: PreviewProvider {
    static var previews: some View {
        MockPlaybackView()
            .environmentObject(ThemeManager.shared)
    }
}

#endif
