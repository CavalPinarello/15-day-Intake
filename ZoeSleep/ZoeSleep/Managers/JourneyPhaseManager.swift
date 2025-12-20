//
//  JourneyPhaseManager.swift
//  Zoe Sleep for Longevity System
//
//  Manages patient journey phases: Intake → Analysis → Treatment
//  Handles progressive insights, analysis stages, and treatment tasks
//

import Foundation
import SwiftUI
import Combine

// MARK: - Journey Phase Enum

enum JourneyPhase: String, Codable, CaseIterable {
    case intake = "intake"
    case analysis = "analysis"
    case treatmentPending = "treatment_pending"
    case treatmentActive = "treatment_active"

    var displayName: String {
        switch self {
        case .intake: return "Data Collection"
        case .analysis: return "Analysis in Progress"
        case .treatmentPending: return "Treatment Prepared"
        case .treatmentActive: return "Treatment Active"
        }
    }

    var icon: String {
        switch self {
        case .intake: return "calendar"
        case .analysis: return "magnifyingglass"
        case .treatmentPending: return "doc.text.fill"
        case .treatmentActive: return "heart.fill"
        }
    }
}

// MARK: - Analysis Stage

struct AnalysisStage: Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
    let icon: String
    var isComplete: Bool
    var isCurrent: Bool

    static let stages: [AnalysisStage] = [
        AnalysisStage(id: 1, title: "Data collected", description: "Your 15 days of sleep data are ready for analysis", icon: "checkmark.circle.fill", isComplete: false, isCurrent: false),
        AnalysisStage(id: 2, title: "Patterns identified", description: "Our sleep specialists are reviewing your patterns", icon: "magnifyingglass", isComplete: false, isCurrent: false),
        AnalysisStage(id: 3, title: "Recommendations preparing", description: "Your personalized treatment plan is being created", icon: "doc.text.fill", isComplete: false, isCurrent: false),
        AnalysisStage(id: 4, title: "Treatment plan ready!", description: "Tap to view your personalized sleep improvement plan", icon: "star.fill", isComplete: false, isCurrent: false),
    ]
}

// MARK: - Insight Teaser

struct InsightTeaser: Identifiable, Equatable {
    let id: String
    let title: String
    let category: String
    let icon: String
    let color: String?
    let teaserType: String // "countdown" or "discovery"
    let isUnlocked: Bool
    let daysUntilUnlock: Int?
    let lockedDescription: String
    let unlockedDescription: String?
    let discoveryHint: String?
    let discoveryHintLevel: Int
    let dataPointsCollected: Int
}

// MARK: - Time Window

struct TimeWindow: Identifiable, Equatable {
    let id: String // "morning", "afternoon", "evening", "night"
    let name: String
    let description: String
    let icon: String
    let color: Color
    let startHour: Int
    let endHour: Int

    var isActive: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= startHour && hour < endHour
    }

    var timeRange: String {
        let startSuffix = startHour >= 12 ? "PM" : "AM"
        let endSuffix = endHour >= 12 ? "PM" : "AM"
        let start = startHour > 12 ? startHour - 12 : startHour
        let end = endHour > 12 ? endHour - 12 : (endHour == 24 ? 12 : endHour)
        return "\(start) \(startSuffix) - \(end) \(endSuffix)"
    }

    static let morning = TimeWindow(id: "morning", name: "Morning", description: "5 AM - 12 PM", icon: "sun.max.fill", color: .orange, startHour: 5, endHour: 12)
    static let afternoon = TimeWindow(id: "afternoon", name: "Afternoon", description: "12 PM - 5 PM", icon: "sun.haze.fill", color: .yellow, startHour: 12, endHour: 17)
    static let evening = TimeWindow(id: "evening", name: "Evening", description: "5 PM - 9 PM", icon: "sunset.fill", color: .pink, startHour: 17, endHour: 21)
    static let night = TimeWindow(id: "night", name: "Night", description: "9 PM - 12 AM", icon: "moon.fill", color: .indigo, startHour: 21, endHour: 24)

    static let all: [TimeWindow] = [.morning, .afternoon, .evening, .night]

    static func current() -> TimeWindow {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 21 || hour < 5 { return .night }
        if hour >= 17 { return .evening }
        if hour >= 12 { return .afternoon }
        return .morning
    }
}

// MARK: - Windowed Task

struct WindowedTask: Identifiable, Equatable {
    let id: String
    let taskName: String
    let taskInstructions: String
    let timeWindow: String
    let status: String
    let scheduledTime: String?
    let priority: Int?
    let interventionId: String
    let isLocked: Bool
    let unlocksAt: String?

    var isCompleted: Bool {
        status == "completed"
    }

    var isSkipped: Bool {
        status == "skipped"
    }
}

// MARK: - Journey Phase Manager

@MainActor
class JourneyPhaseManager: ObservableObject {
    static let shared = JourneyPhaseManager()

    // MARK: - Published State

    @Published var currentPhase: JourneyPhase = .intake
    @Published var analysisStage: Int = 1
    @Published var analysisStages: [AnalysisStage] = AnalysisStage.stages

    // Progressive Insights
    @Published var insightTeasers: [InsightTeaser] = []
    @Published var nextInsight: InsightTeaser?

    // Treatment Tasks (grouped by time window)
    @Published var morningTasks: [WindowedTask] = []
    @Published var afternoonTasks: [WindowedTask] = []
    @Published var eveningTasks: [WindowedTask] = []
    @Published var nightTasks: [WindowedTask] = []
    @Published var currentWindow: TimeWindow = .current()

    // Timestamps
    @Published var intakeCompletedAt: Date?
    @Published var treatmentActivatedAt: Date?

    // UI State
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    // MARK: - Computed Properties

    var completedTaskCount: Int {
        [morningTasks, afternoonTasks, eveningTasks, nightTasks]
            .flatMap { $0 }
            .filter { $0.isCompleted }
            .count
    }

    var totalTaskCount: Int {
        morningTasks.count + afternoonTasks.count + eveningTasks.count + nightTasks.count
    }

    var completionPercentage: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }

    var unlockedInsightsCount: Int {
        insightTeasers.filter { $0.isUnlocked }.count
    }

    // MARK: - Initialization

    private init() {
        updateCurrentWindow()
    }

    // MARK: - Window Updates

    func updateCurrentWindow() {
        currentWindow = TimeWindow.current()
    }

    // MARK: - Load Journey Status

    func loadJourneyStatus(userId: String) async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil

        do {
            // Call Convex to get journey status
            let response = try await ConvexService.shared.getJourneyStatus(userId: userId)

            // Update phase
            if let phaseString = response["phase"] as? String,
               let phase = JourneyPhase(rawValue: phaseString) {
                self.currentPhase = phase
            }

            // Update analysis stage
            if let stage = response["analysisStage"] as? Int {
                self.analysisStage = stage
                updateAnalysisStages(currentStage: stage)
            }

            // Update timestamps
            if let intakeTimestamp = response["intakeCompletedAt"] as? Double {
                self.intakeCompletedAt = Date(timeIntervalSince1970: intakeTimestamp / 1000)
            }
            if let treatmentTimestamp = response["treatmentActivatedAt"] as? Double {
                self.treatmentActivatedAt = Date(timeIntervalSince1970: treatmentTimestamp / 1000)
            }

            isLoading = false
        } catch {
            self.lastError = error.localizedDescription
            isLoading = false
            print("[JourneyPhase] Error loading status: \(error)")
        }
    }

    private func updateAnalysisStages(currentStage: Int) {
        analysisStages = AnalysisStage.stages.map { stage in
            var updated = stage
            updated.isComplete = stage.id < currentStage
            updated.isCurrent = stage.id == currentStage
            return updated
        }
    }

    // MARK: - Load Progressive Insights

    func loadInsightTeasers(userId: String) async {
        do {
            let response = try await ConvexService.shared.getProgressiveInsights(userId: userId)

            self.insightTeasers = response.map { item in
                InsightTeaser(
                    id: item["teaserId"] as? String ?? "",
                    title: item["title"] as? String ?? "",
                    category: item["category"] as? String ?? "",
                    icon: item["icon"] as? String ?? "sparkles",
                    color: item["color"] as? String,
                    teaserType: item["teaserType"] as? String ?? "countdown",
                    isUnlocked: item["isUnlocked"] as? Bool ?? false,
                    daysUntilUnlock: item["daysUntilUnlock"] as? Int,
                    lockedDescription: item["lockedDescription"] as? String ?? "",
                    unlockedDescription: item["unlockedDescription"] as? String,
                    discoveryHint: item["discoveryHint"] as? String,
                    discoveryHintLevel: item["discoveryHintLevel"] as? Int ?? 0,
                    dataPointsCollected: item["dataPointsCollected"] as? Int ?? 0
                )
            }

            // Load next insight teaser
            if let next = try await ConvexService.shared.getNextInsightTeaser(userId: userId) {
                self.nextInsight = InsightTeaser(
                    id: next["teaserId"] as? String ?? "",
                    title: next["title"] as? String ?? "",
                    category: "",
                    icon: next["icon"] as? String ?? "sparkles",
                    color: nil,
                    teaserType: next["teaserType"] as? String ?? "countdown",
                    isUnlocked: false,
                    daysUntilUnlock: next["daysUntilUnlock"] as? Int,
                    lockedDescription: next["displayText"] as? String ?? "",
                    unlockedDescription: nil,
                    discoveryHint: nil,
                    discoveryHintLevel: 0,
                    dataPointsCollected: 0
                )
            }
        } catch {
            print("[JourneyPhase] Error loading insights: \(error)")
        }
    }

    // MARK: - Load Windowed Tasks

    func loadWindowedTasks(userId: String) async {
        do {
            let response = try await ConvexService.shared.getTasksByTimeWindow(userId: userId)

            self.morningTasks = parseTasks(response["morning"] as? [[String: Any]] ?? [])
            self.afternoonTasks = parseTasks(response["afternoon"] as? [[String: Any]] ?? [])
            self.eveningTasks = parseTasks(response["evening"] as? [[String: Any]] ?? [])
            self.nightTasks = parseTasks(response["night"] as? [[String: Any]] ?? [])

            if let windowStr = response["currentWindow"] as? String {
                switch windowStr {
                case "morning": currentWindow = .morning
                case "afternoon": currentWindow = .afternoon
                case "evening": currentWindow = .evening
                case "night": currentWindow = .night
                default: break
                }
            }
        } catch {
            print("[JourneyPhase] Error loading tasks: \(error)")
        }
    }

    private func parseTasks(_ items: [[String: Any]]) -> [WindowedTask] {
        items.compactMap { item in
            guard let id = item["_id"] as? String else { return nil }
            return WindowedTask(
                id: id,
                taskName: item["task_name"] as? String ?? "",
                taskInstructions: item["task_instructions"] as? String ?? "",
                timeWindow: item["time_window"] as? String ?? "morning",
                status: item["status"] as? String ?? "pending",
                scheduledTime: item["scheduled_time"] as? String,
                priority: item["priority"] as? Int,
                interventionId: item["intervention_id"] as? String ?? "",
                isLocked: item["isLocked"] as? Bool ?? false,
                unlocksAt: item["unlocksAt"] as? String
            )
        }
    }

    // MARK: - Task Actions

    func completeTask(taskId: String, difficultyRating: Int? = nil, notes: String? = nil) async -> (success: Bool, error: String?) {
        do {
            let result = try await ConvexService.shared.completeTask(
                taskId: taskId,
                difficultyRating: difficultyRating,
                notes: notes
            )

            if let success = result["success"] as? Bool, success {
                // Update local state
                updateTaskStatus(taskId: taskId, newStatus: "completed")
                return (true, nil)
            } else {
                let error = result["error"] as? String ?? "Unknown error"
                return (false, error)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }

    func skipTask(taskId: String, reason: String?) async -> Bool {
        do {
            _ = try await ConvexService.shared.skipTask(taskId: taskId, reason: reason)
            updateTaskStatus(taskId: taskId, newStatus: "skipped")
            return true
        } catch {
            print("[JourneyPhase] Error skipping task: \(error)")
            return false
        }
    }

    private func updateTaskStatus(taskId: String, newStatus: String) {
        func update(_ tasks: inout [WindowedTask]) {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                let task = tasks[index]
                tasks[index] = WindowedTask(
                    id: task.id,
                    taskName: task.taskName,
                    taskInstructions: task.taskInstructions,
                    timeWindow: task.timeWindow,
                    status: newStatus,
                    scheduledTime: task.scheduledTime,
                    priority: task.priority,
                    interventionId: task.interventionId,
                    isLocked: task.isLocked,
                    unlocksAt: task.unlocksAt
                )
            }
        }

        update(&morningTasks)
        update(&afternoonTasks)
        update(&eveningTasks)
        update(&nightTasks)
    }

    // MARK: - Phase Transitions

    func checkAndTransitionToAnalysis(userId: String, currentDay: Int) async {
        guard currentDay > 15 && currentPhase == .intake else { return }

        do {
            _ = try await ConvexService.shared.transitionToAnalysis(userId: userId)
            await loadJourneyStatus(userId: userId)
        } catch {
            print("[JourneyPhase] Error transitioning to analysis: \(error)")
        }
    }

    // MARK: - Tasks for Window

    func tasks(for window: TimeWindow) -> [WindowedTask] {
        switch window.id {
        case "morning": return morningTasks
        case "afternoon": return afternoonTasks
        case "evening": return eveningTasks
        case "night": return nightTasks
        default: return []
        }
    }

    func completedCount(for window: TimeWindow) -> Int {
        tasks(for: window).filter { $0.isCompleted }.count
    }

    func totalCount(for window: TimeWindow) -> Int {
        tasks(for: window).count
    }
}
