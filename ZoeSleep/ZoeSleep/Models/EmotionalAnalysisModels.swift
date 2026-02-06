//
//  EmotionalAnalysisModels.swift
//  ZoeSleep
//
//  Data models for emotional state detection via Hume AI.
//  Analyzes voice patterns during assessments to detect sleep-relevant emotions.
//

import Foundation
import SwiftUI

// MARK: - Sleep-Relevant Emotions

/// Emotions particularly relevant to sleep health assessment
enum SleepRelevantEmotion: String, Codable, CaseIterable {
    case anxiety = "anxiety"
    case stress = "stress"
    case calm = "calm"
    case frustration = "frustration"
    case sadness = "sadness"
    case confusion = "confusion"
    case fatigue = "fatigue"
    case irritability = "irritability"
    case hopelessness = "hopelessness"
    case contentment = "contentment"

    var displayName: String {
        rawValue.capitalized
    }

    var sfSymbol: String {
        switch self {
        case .anxiety: return "exclamationmark.triangle"
        case .stress: return "bolt.fill"
        case .calm: return "leaf.fill"
        case .frustration: return "flame.fill"
        case .sadness: return "cloud.rain.fill"
        case .confusion: return "questionmark.circle"
        case .fatigue: return "battery.25"
        case .irritability: return "burst.fill"
        case .hopelessness: return "cloud.heavyrain.fill"
        case .contentment: return "sun.max.fill"
        }
    }

    var color: Color {
        switch self {
        case .anxiety: return .orange
        case .stress: return .red
        case .calm: return .green
        case .frustration: return .orange
        case .sadness: return .blue
        case .confusion: return .purple
        case .fatigue: return .gray
        case .irritability: return .red
        case .hopelessness: return .indigo
        case .contentment: return .mint
        }
    }

    /// Clinical relevance for sleep disorders
    var clinicalRelevance: String {
        switch self {
        case .anxiety:
            return "Anxiety is strongly linked to sleep onset insomnia and sleep maintenance issues."
        case .stress:
            return "Chronic stress elevates cortisol, disrupting sleep architecture."
        case .calm:
            return "Calmness indicates good emotional regulation, supporting healthy sleep."
        case .frustration:
            return "Frustration about sleep can perpetuate insomnia through negative conditioning."
        case .sadness:
            return "Sadness may indicate depressive symptoms, often co-morbid with sleep disorders."
        case .confusion:
            return "Confusion may indicate cognitive effects of sleep deprivation."
        case .fatigue:
            return "Fatigue is a primary symptom requiring differentiation from sleepiness."
        case .irritability:
            return "Irritability often results from sleep deprivation and poor sleep quality."
        case .hopelessness:
            return "Hopelessness warrants clinical attention and may indicate depression."
        case .contentment:
            return "Contentment suggests positive sleep-related emotional state."
        }
    }

    /// Whether this emotion warrants special attention
    var requiresAttention: Bool {
        switch self {
        case .hopelessness, .anxiety, .stress:
            return true
        default:
            return false
        }
    }
}

// MARK: - Emotion Snapshot

/// A snapshot of emotional state at a point in time
struct EmotionSnapshot: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let emotions: [String: Double]  // emotion -> confidence (0.0-1.0)
    let dominantEmotion: SleepRelevantEmotion
    let arousalLevel: Double  // 0.0 (calm) to 1.0 (activated)
    let valence: Double  // -1.0 (negative) to 1.0 (positive)
    let speechRate: Double?  // words per minute
    let voicePitch: Double?  // relative pitch

    /// Check if distress was detected
    var isDistressed: Bool {
        arousalLevel > 0.7 && valence < -0.3
    }

    /// Get the top 3 emotions by confidence
    var topEmotions: [(SleepRelevantEmotion, Double)] {
        emotions
            .compactMap { key, value -> (SleepRelevantEmotion, Double)? in
                guard let emotion = SleepRelevantEmotion(rawValue: key) else { return nil }
                return (emotion, value)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0 }
    }

    static func empty() -> EmotionSnapshot {
        EmotionSnapshot(
            id: UUID().uuidString,
            timestamp: Date(),
            emotions: [:],
            dominantEmotion: .calm,
            arousalLevel: 0.5,
            valence: 0.0,
            speechRate: nil,
            voicePitch: nil
        )
    }
}

// MARK: - Session Emotion Summary

/// Aggregated emotional analysis for an entire session
struct SessionEmotionSummary: Codable {
    let sessionId: String
    let sessionType: String  // "assessment", "check_in", "cbti"
    let startTime: Date
    let endTime: Date
    let snapshotCount: Int

    // Aggregated metrics
    let averageArousal: Double
    let averageValence: Double
    let dominantEmotions: [String]  // Top 3 across session
    let emotionVariability: Double  // How much emotions changed

    // Clinical flags
    let distressDetected: Bool
    let anxietyEpisodes: Int
    let calmPeriods: Int

    // Question-specific emotions (for correlating with responses)
    let emotionsByQuestion: [String: EmotionSnapshot]?  // questionId -> snapshot

    /// Generate clinical insights from the summary
    var clinicalInsights: [String] {
        var insights: [String] = []

        if distressDetected {
            insights.append("Emotional distress detected during session - recommend clinician review")
        }

        if anxietyEpisodes > 2 {
            insights.append("Multiple anxiety episodes (\(anxietyEpisodes)) - sleep anxiety may be a factor")
        }

        if averageArousal > 0.7 {
            insights.append("High arousal throughout session - hyperarousal may contribute to insomnia")
        }

        if averageValence < -0.3 {
            insights.append("Predominantly negative emotional tone - mood assessment recommended")
        }

        if emotionVariability > 0.5 {
            insights.append("High emotional variability - emotional regulation may be a factor")
        }

        if calmPeriods > snapshotCount / 2 {
            insights.append("Predominantly calm - good emotional baseline for treatment")
        }

        return insights
    }
}

// MARK: - Hume API Models

/// Response from Hume AI prosody analysis
struct HumeProsodyResult: Codable {
    let emotions: [HumeEmotion]
    let time: HumeTimeRange?

    struct HumeEmotion: Codable {
        let name: String
        let score: Double
    }

    struct HumeTimeRange: Codable {
        let begin: Double
        let end: Double
    }

    /// Convert Hume emotions to our sleep-relevant emotions
    func toEmotionSnapshot(id: String = UUID().uuidString) -> EmotionSnapshot {
        // Map Hume's 48 emotions to our sleep-relevant subset
        let emotionMapping: [String: SleepRelevantEmotion] = [
            "Anxiety": .anxiety,
            "Fear": .anxiety,
            "Nervousness": .anxiety,
            "Stress": .stress,
            "Tension": .stress,
            "Calmness": .calm,
            "Serenity": .calm,
            "Contentment": .contentment,
            "Frustration": .frustration,
            "Annoyance": .frustration,
            "Anger": .irritability,
            "Irritation": .irritability,
            "Sadness": .sadness,
            "Disappointment": .sadness,
            "Tiredness": .fatigue,
            "Boredom": .fatigue,
            "Confusion": .confusion,
            "Doubt": .confusion,
            "Distress": .hopelessness,
            "Despair": .hopelessness
        ]

        var sleepEmotions: [String: Double] = [:]
        var maxEmotion: (SleepRelevantEmotion, Double) = (.calm, 0.0)

        for emotion in emotions {
            if let mapped = emotionMapping[emotion.name] {
                let current = sleepEmotions[mapped.rawValue] ?? 0.0
                sleepEmotions[mapped.rawValue] = max(current, emotion.score)

                if emotion.score > maxEmotion.1 {
                    maxEmotion = (mapped, emotion.score)
                }
            }
        }

        // Calculate arousal (average of high-activation emotions)
        let arousalEmotions = ["Anxiety", "Fear", "Anger", "Excitement", "Surprise"]
        let arousalScores = emotions.filter { arousalEmotions.contains($0.name) }.map { $0.score }
        let arousal = arousalScores.isEmpty ? 0.5 : arousalScores.reduce(0, +) / Double(arousalScores.count)

        // Calculate valence (positive - negative emotions)
        let positiveEmotions = ["Joy", "Contentment", "Calmness", "Satisfaction", "Relief"]
        let negativeEmotions = ["Sadness", "Anger", "Fear", "Disgust", "Anxiety"]
        let positiveScore = emotions.filter { positiveEmotions.contains($0.name) }.map { $0.score }.reduce(0, +)
        let negativeScore = emotions.filter { negativeEmotions.contains($0.name) }.map { $0.score }.reduce(0, +)
        let valence = (positiveScore - negativeScore).clamped(to: -1.0...1.0)

        return EmotionSnapshot(
            id: id,
            timestamp: Date(),
            emotions: sleepEmotions,
            dominantEmotion: maxEmotion.0,
            arousalLevel: arousal.clamped(to: 0.0...1.0),
            valence: valence,
            speechRate: nil,
            voicePitch: nil
        )
    }
}

// MARK: - Emotional Analysis Request

/// Request to analyze audio for emotions
struct EmotionalAnalysisRequest {
    let audioData: Data
    let sessionId: String
    let sessionType: String
    let questionId: String?
    let userId: String
}

// MARK: - Emotional Analysis Result

/// Result from emotional analysis
struct EmotionalAnalysisResult {
    let snapshot: EmotionSnapshot
    let rawResponse: HumeProsodyResult?
    let processingTimeMs: Int
    let error: String?

    var isSuccess: Bool {
        error == nil
    }
}

// MARK: - Extensions

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
