//
//  QuestionnaireRouterView.swift
//  ZoeSleep
//
//  Routes to the appropriate questionnaire view based on mode:
//  - Normal Mode: Standard QuestionnaireView with manual input
//  - Easy Mode: Seamless voice-first experience with Zoe Orb
//  - Conversational Mode: Full conversational assessment with Zoe (for assessments)
//

import SwiftUI

/// Router view that selects the appropriate questionnaire experience
/// When Easy Mode is enabled, shows the seamless voice questionnaire instead
/// For assessments in Easy Mode, optionally shows the full conversational experience
struct QuestionnaireRouterView: View {
    @Binding var currentDay: Int
    let startSection: QuestionnaireSection
    let sectionOnly: Bool

    /// If true, use the full conversational assessment for assessment sections
    var useConversationalAssessment: Bool = false

    @ObservedObject var themeManager = ThemeManager.shared
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    // State for Easy Mode
    @State private var loadedQuestions: [Question] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        Group {
            if themeManager.easyModeEnabled {
                // Check if we should use the full conversational assessment
                if shouldUseConversationalAssessment {
                    // Full conversational experience with Zoe intro and guardrails
                    VoiceAssessmentView(
                        dayNumber: currentDay,
                        onComplete: {
                            dismiss()
                        },
                        onDismiss: {
                            dismiss()
                        }
                    )
                } else {
                    // Seamless voice-first experience (question by question)
                    seamlessVoiceView
                }
            } else {
                // Standard questionnaire with manual input
                QuestionnaireView(
                    currentDay: $currentDay,
                    startSection: startSection,
                    sectionOnly: sectionOnly
                )
                .environmentObject(healthKitManager)
                .environmentObject(themeManager)
            }
        }
    }

    /// Determine if we should use the full conversational assessment
    private var shouldUseConversationalAssessment: Bool {
        // Only use conversational for assessment sections (not sleep log)
        guard startSection == .assessment || startSection == .expansionPack else {
            return false
        }

        // Check if explicitly requested or if it's the user's preference
        return useConversationalAssessment || themeManager.conversationalAssessmentEnabled
    }

    // MARK: - Seamless Voice View

    @ViewBuilder
    private var seamlessVoiceView: some View {
        if isLoading {
            // Loading state
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading questions...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else if let error = loadError {
            // Error state
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                Button("Try Again") {
                    loadQuestionsForVoice()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else if loadedQuestions.isEmpty {
            // Need to load
            Color.clear
                .onAppear {
                    loadQuestionsForVoice()
                }
        } else {
            // Ready - show seamless voice UI
            SeamlessVoiceQuestionnaireView(
                questions: loadedQuestions,
                sectionTitle: startSection.title,
                onComplete: { answers in
                    handleVoiceAnswers(answers)
                },
                onDismiss: {
                    dismiss()
                }
            )
        }
    }

    // MARK: - Load Questions

    private func loadQuestionsForVoice() {
        isLoading = true
        loadError = nil

        Task {
            do {
                // Map enum to Convex API expected values (camelCase)
                let sectionArg: String
                switch startSection {
                case .sleepLog:
                    sectionArg = "sleepLog"
                case .assessment:
                    sectionArg = "assessment"
                case .expansionPack:
                    sectionArg = "assessment" // Expansion packs are part of assessment
                }

                let questionsResponse = try await ConvexService.shared.getQuestionsForUserDay(
                    dayNumber: currentDay,
                    section: sectionArg
                )

                // Convert to Question type based on section
                var questions: [Question] = []

                if startSection == .sleepLog {
                    questions = questionsResponse.sleepLog.map { convertConvexQuestion($0, isSleepLog: true) }
                    print("[VoiceRouter] Loaded \(questions.count) sleep log questions")
                } else {
                    questions = questionsResponse.assessment.map { convertConvexQuestion($0, isSleepLog: false) }
                    print("[VoiceRouter] Loaded \(questions.count) assessment questions")
                }

                await MainActor.run {
                    loadedQuestions = questions
                    isLoading = false
                }

            } catch {
                await MainActor.run {
                    loadError = "Failed to load questions: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Convert Convex Question (simplified from QuestionnaireView)

    private func convertConvexQuestion(_ cq: ConvexQuestion, isSleepLog: Bool) -> Question {
        // Map Convex question type to iOS QuestionType
        let questionType: QuestionType
        switch cq.type {
        case "time": questionType = .time
        case "scale": questionType = .scale
        case "number": questionType = .number
        case "numberScroll": questionType = .numberScroll
        case "minutesScroll": questionType = .minutesScroll
        case "hoursMinutesScroll": questionType = .hoursMinutesScroll
        case "yesNo": questionType = .yesNo
        case "singleSelect": questionType = .singleSelect
        case "multiSelect": questionType = .multiSelect
        case "text": questionType = .text
        case "date": questionType = .date
        case "info": questionType = .info
        case "napDetails": questionType = .napDetails
        case "medicationSelect": questionType = .medicationSelect
        case "caffeineSelect": questionType = .caffeineSelect
        default: questionType = .text
        }

        // Extract scale config from formatConfig if available
        var scaleMin: Int? = nil
        var scaleMax: Int? = nil
        var scaleMinLabel: String? = nil
        var scaleMaxLabel: String? = nil

        if let config = cq.formatConfig {
            if let min = config["scaleMin"]?.value as? Int { scaleMin = min }
            if let max = config["scaleMax"]?.value as? Int { scaleMax = max }
            // Fallback to legacy format
            if scaleMin == nil, let min = config["min"]?.value as? Int { scaleMin = min }
            if scaleMax == nil, let max = config["max"]?.value as? Int { scaleMax = max }
            // Labels
            if let labels = config["labels"]?.value as? [String], !labels.isEmpty {
                scaleMinLabel = labels.first
                scaleMaxLabel = labels.last
            } else {
                if let minLabel = config["minLabel"]?.value as? String { scaleMinLabel = minLabel }
                if let maxLabel = config["maxLabel"]?.value as? String { scaleMaxLabel = maxLabel }
            }
        }

        return Question(
            id: cq.id,
            text: cq.text,
            pillar: isSleepLog ? .sleepLog : .sleepQuality,
            tier: .core,
            questionType: questionType,
            estimatedMinutes: 0.5,
            required: cq.required,
            options: cq.options,
            scaleMin: scaleMin,
            scaleMax: scaleMax,
            scaleMinLabel: scaleMinLabel,
            scaleMaxLabel: scaleMaxLabel,
            minValue: scaleMin,
            maxValue: scaleMax,
            step: nil,
            unit: nil,
            defaultValue: nil,
            unitImperial: nil,
            defaultImperial: nil,
            helpText: cq.helpText,
            helpTextImperial: cq.helpTextImperial,
            isGateway: false,
            conditionalLogic: nil,
            group: isSleepLog ? "sleep_log" : nil
        )
    }

    // MARK: - Handle Answers

    private func handleVoiceAnswers(_ answers: [String: Any]) {
        // Save answers to Convex
        Task {
            do {
                // Convert to Convex response format
                var convexResponses: [[String: Any]] = []

                for (questionId, value) in answers {
                    var response: [String: Any] = ["questionId": questionId]

                    if let stringValue = value as? String {
                        // Check if it's a number string
                        if let intValue = Int(stringValue) {
                            response["responseNumber"] = Double(intValue)
                        } else {
                            response["responseValue"] = stringValue
                        }
                    } else if let intValue = value as? Int {
                        response["responseNumber"] = Double(intValue)
                    } else if let doubleValue = value as? Double {
                        response["responseNumber"] = doubleValue
                    } else {
                        response["responseValue"] = "\(value)"
                    }

                    convexResponses.append(response)
                }

                // Save responses
                if !convexResponses.isEmpty {
                    let result = try await ConvexService.shared.saveResponses(
                        dayNumber: currentDay,
                        responses: convexResponses
                    )
                    print("[VoiceRouter] Saved \(result.savedCount) voice answers")
                }

            } catch {
                print("[VoiceRouter] Failed to save answers: \(error)")
            }

            // Dismiss
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview("Questionnaire Router") {
    QuestionnaireRouterView(
        currentDay: .constant(1),
        startSection: .sleepLog,
        sectionOnly: true
    )
    .environmentObject(HealthKitManager())
}
