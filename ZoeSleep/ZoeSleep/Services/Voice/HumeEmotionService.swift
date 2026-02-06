//
//  HumeEmotionService.swift
//  ZoeSleep
//
//  Service for analyzing voice emotions using Hume AI.
//  Streams audio during assessments to detect emotional states.
//

import Foundation
import Combine

/// Service for emotional analysis using Hume AI
@MainActor
class HumeEmotionService: ObservableObject {

    // MARK: - Singleton

    static let shared = HumeEmotionService()

    // MARK: - Published State

    @Published var isAnalyzing = false
    @Published var currentSnapshot: EmotionSnapshot?
    @Published var sessionSnapshots: [EmotionSnapshot] = []
    @Published var error: String?

    // MARK: - Session State

    private var currentSessionId: String?
    private var currentSessionType: String?
    private var emotionsByQuestion: [String: EmotionSnapshot] = [:]

    // MARK: - Configuration

    private let analysisIntervalSeconds: Double = 5.0  // Analyze every 5 seconds
    private var analysisTimer: Timer?
    private var audioBuffer: Data = Data()

    // MARK: - Dependencies

    private let audioManager = AudioSessionManager.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Session Management

    /// Start emotional analysis for a session
    func startSession(sessionId: String, sessionType: String) {
        currentSessionId = sessionId
        currentSessionType = sessionType
        sessionSnapshots = []
        emotionsByQuestion = [:]
        error = nil

        print("[HumeEmotionService] Started session: \(sessionId) (\(sessionType))")
    }

    /// End the current session and generate summary
    func endSession() async -> SessionEmotionSummary? {
        guard let sessionId = currentSessionId,
              let sessionType = currentSessionType else {
            return nil
        }

        stopAnalysis()

        // Generate summary
        let summary = generateSessionSummary(
            sessionId: sessionId,
            sessionType: sessionType
        )

        // Save to Convex
        await saveSessionSummary(summary)

        // Reset state
        currentSessionId = nil
        currentSessionType = nil

        print("[HumeEmotionService] Ended session with \(sessionSnapshots.count) snapshots")

        return summary
    }

    // MARK: - Real-time Analysis

    /// Start continuous emotional analysis
    func startAnalysis() {
        guard !isAnalyzing else { return }

        isAnalyzing = true
        audioBuffer = Data()

        // Set up periodic analysis
        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.analyzeBufferedAudio()
            }
        }

        print("[HumeEmotionService] Started continuous analysis")
    }

    /// Stop continuous analysis
    func stopAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = nil
        isAnalyzing = false
        audioBuffer = Data()

        print("[HumeEmotionService] Stopped analysis")
    }

    /// Add audio data to the buffer for analysis
    func bufferAudio(_ data: Data) {
        audioBuffer.append(data)
    }

    /// Analyze a single audio segment (for question-specific analysis)
    func analyzeAudio(
        _ audioData: Data,
        forQuestion questionId: String? = nil
    ) async -> EmotionSnapshot? {
        do {
            let result = try await callHumeAPI(audioData: audioData)

            if let snapshot = result {
                // Store by question if provided
                if let qId = questionId {
                    emotionsByQuestion[qId] = snapshot
                }

                // Add to session snapshots
                sessionSnapshots.append(snapshot)
                currentSnapshot = snapshot

                // Check for distress
                if snapshot.isDistressed {
                    handleDistressDetected(snapshot)
                }

                return snapshot
            }
        } catch {
            self.error = error.localizedDescription
            print("[HumeEmotionService] Analysis error: \(error)")
        }

        return nil
    }

    // MARK: - Private Methods

    private func analyzeBufferedAudio() async {
        guard audioBuffer.count > 1000 else { return }  // Need minimum data

        let dataToAnalyze = audioBuffer
        audioBuffer = Data()  // Clear buffer

        await analyzeAudio(dataToAnalyze)
    }

    private func callHumeAPI(audioData: Data) async throws -> EmotionSnapshot? {
        // Call Convex action which proxies to Hume
        let result = try await ConvexService.shared.analyzeEmotion(
            audioBase64: audioData.base64EncodedString(),
            sessionId: currentSessionId ?? UUID().uuidString,
            sessionType: currentSessionType ?? "unknown"
        )

        return result
    }

    private func handleDistressDetected(_ snapshot: EmotionSnapshot) {
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .emotionalDistressDetected,
            object: nil,
            userInfo: ["snapshot": snapshot]
        )

        print("[HumeEmotionService] DISTRESS DETECTED - arousal: \(snapshot.arousalLevel), valence: \(snapshot.valence)")
    }

    private func generateSessionSummary(sessionId: String, sessionType: String) -> SessionEmotionSummary {
        guard !sessionSnapshots.isEmpty else {
            return SessionEmotionSummary(
                sessionId: sessionId,
                sessionType: sessionType,
                startTime: Date(),
                endTime: Date(),
                snapshotCount: 0,
                averageArousal: 0.5,
                averageValence: 0.0,
                dominantEmotions: [],
                emotionVariability: 0.0,
                distressDetected: false,
                anxietyEpisodes: 0,
                calmPeriods: 0,
                emotionsByQuestion: nil
            )
        }

        // Calculate averages
        let avgArousal = sessionSnapshots.map { $0.arousalLevel }.reduce(0, +) / Double(sessionSnapshots.count)
        let avgValence = sessionSnapshots.map { $0.valence }.reduce(0, +) / Double(sessionSnapshots.count)

        // Count emotion occurrences
        var emotionCounts: [SleepRelevantEmotion: Int] = [:]
        for snapshot in sessionSnapshots {
            emotionCounts[snapshot.dominantEmotion, default: 0] += 1
        }
        let dominantEmotions = emotionCounts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key.rawValue }

        // Calculate variability (standard deviation of arousal)
        let meanArousal = avgArousal
        let variance = sessionSnapshots.map { pow($0.arousalLevel - meanArousal, 2) }.reduce(0, +) / Double(sessionSnapshots.count)
        let variability = sqrt(variance)

        // Count episodes
        let anxietyEpisodes = sessionSnapshots.filter { $0.dominantEmotion == .anxiety }.count
        let calmPeriods = sessionSnapshots.filter { $0.dominantEmotion == .calm || $0.dominantEmotion == .contentment }.count
        let distressDetected = sessionSnapshots.contains { $0.isDistressed }

        return SessionEmotionSummary(
            sessionId: sessionId,
            sessionType: sessionType,
            startTime: sessionSnapshots.first?.timestamp ?? Date(),
            endTime: sessionSnapshots.last?.timestamp ?? Date(),
            snapshotCount: sessionSnapshots.count,
            averageArousal: avgArousal,
            averageValence: avgValence,
            dominantEmotions: dominantEmotions,
            emotionVariability: variability,
            distressDetected: distressDetected,
            anxietyEpisodes: anxietyEpisodes,
            calmPeriods: calmPeriods,
            emotionsByQuestion: emotionsByQuestion.isEmpty ? nil : emotionsByQuestion
        )
    }

    private func saveSessionSummary(_ summary: SessionEmotionSummary) async {
        do {
            try await ConvexService.shared.saveEmotionSummary(summary)
            print("[HumeEmotionService] Saved session summary to Convex")
        } catch {
            print("[HumeEmotionService] Failed to save summary: \(error)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let emotionalDistressDetected = Notification.Name("emotionalDistressDetected")
}

// Note: ConvexService extension methods for Hume AI are defined in ConvexService.swift
