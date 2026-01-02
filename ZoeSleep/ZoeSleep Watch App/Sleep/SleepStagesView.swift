//
//  SleepStagesView.swift
//  ZoeSleep Watch App
//
//  Comprehensive sleep stages visualization with chronotype insights.
//  A better sleep analysis than Apple's built-in tracking.
//

import SwiftUI
import Charts

// MARK: - Main Sleep Stages View

struct SleepStagesView: View {
    @StateObject private var analyzer = SleepAnalyzer.shared
    @StateObject private var chronotypeManager = ChronotypeManager.shared
    @State private var analysis: SleepAnalysis?
    @State private var selectedPage = 0
    @State private var showChronotypeSetup = false

    // Sample session for preview (replace with actual HealthKit data)
    @State private var currentSession: SleepSession?

    private var darkBackground: [Color] {
        [
            Color(red: 0.06, green: 0.06, blue: 0.12),
            Color(red: 0.10, green: 0.10, blue: 0.16)
        ]
    }

    var body: some View {
        NavigationStack {
            Group {
                if !chronotypeManager.isAssessed {
                    chronotypePrompt
                } else if let analysis = analysis {
                    sleepAnalysisContent(analysis)
                } else {
                    loadingOrEmptyState
                }
            }
            .background(
                LinearGradient(colors: darkBackground, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Sleep Stages")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showChronotypeSetup) {
                ChronotypeQuizView()
            }
        }
        .onAppear {
            loadSleepData()
        }
    }

    // MARK: - Chronotype Prompt

    private var chronotypePrompt: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer().frame(height: 20)

                // Chronotype icons
                HStack(spacing: 8) {
                    ForEach(Chronotype.allCases, id: \.self) { type in
                        Text(type.emoji)
                            .font(.system(size: 24))
                    }
                }

                Text("Discover Your Chronotype")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text("Take a quick quiz to unlock personalized sleep insights based on your biological clock")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button(action: { showChronotypeSetup = true }) {
                    Text("Start Quiz")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(
                                    colors: [.purple, .indigo],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Loading/Empty State

    private var loadingOrEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom)
                )

            Text("No Sleep Data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text("Wear your watch tonight to track sleep stages")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Sleep Analysis Content

    private func sleepAnalysisContent(_ analysis: SleepAnalysis) -> some View {
        TabView(selection: $selectedPage) {
            // Page 1: Overview Score
            OverviewPage(analysis: analysis)
                .tag(0)

            // Page 2: Sleep Stages Hypnogram
            HypnogramPage(analysis: analysis)
                .tag(1)

            // Page 3: Chronotype Alignment
            AlignmentPage(analysis: analysis)
                .tag(2)

            // Page 4: Insights
            InsightsPage(analysis: analysis)
                .tag(3)
        }
        .tabViewStyle(.verticalPage)
    }

    // MARK: - Data Loading

    private func loadSleepData() {
        // In production, load from HealthKit
        // For now, create sample data for preview
        currentSession = createSampleSession()

        if let session = currentSession {
            analysis = analyzer.analyzeSleepSession(session)
        }
    }

    private func createSampleSession() -> SleepSession {
        let calendar = Calendar.current
        let now = Date()
        let bedtime = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now)!)!
        let wakeTime = calendar.date(bySettingHour: 6, minute: 45, second: 0, of: now)!

        // Create realistic sleep stages
        var stages: [SleepStageSegment] = []
        var currentTime = bedtime

        // Typical sleep cycle pattern
        let cyclePattern: [(SleepStage, Int)] = [
            // Falling asleep
            (.awake, 8),
            (.lightN1, 5),
            (.lightN2, 20),
            // First deep cycle
            (.deepN3, 25),
            (.deepN4, 15),
            (.lightN2, 10),
            (.rem, 15),
            // Second cycle
            (.lightN2, 15),
            (.deepN3, 20),
            (.lightN2, 10),
            (.rem, 20),
            // Third cycle
            (.lightN2, 15),
            (.deepN3, 15),
            (.lightN2, 15),
            (.rem, 25),
            // Fourth cycle (more REM, less deep)
            (.lightN2, 20),
            (.lightN1, 10),
            (.rem, 30),
            // Fifth cycle
            (.lightN2, 20),
            (.rem, 35),
            (.lightN1, 10),
            (.awake, 5),
        ]

        for (stage, durationMinutes) in cyclePattern {
            let endTime = currentTime.addingTimeInterval(Double(durationMinutes) * 60)
            stages.append(SleepStageSegment(
                id: UUID(),
                stage: stage,
                startTime: currentTime,
                endTime: endTime
            ))
            currentTime = endTime
        }

        return SleepSession(
            id: UUID(),
            date: now,
            bedtime: bedtime,
            wakeTime: wakeTime,
            stages: stages,
            heartRateData: nil,
            respiratoryRate: 14.5,
            hrv: 45,
            skinTemperature: nil,
            bloodOxygen: 96,
            movementScore: 0.25
        )
    }
}

// MARK: - Overview Page

struct OverviewPage: View {
    let analysis: SleepAnalysis

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Page indicator
                pageIndicator(current: 0, total: 4)

                // Main score circle
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 100, height: 100)

                    // Score ring
                    Circle()
                        .trim(from: 0, to: CGFloat(analysis.overallScore) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [analysis.gradeColor, analysis.gradeColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(analysis.overallScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(analysis.gradeLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(analysis.gradeColor)
                    }
                }

                // Chronotype badge
                HStack(spacing: 4) {
                    Text(analysis.chronotype.emoji)
                        .font(.system(size: 12))
                    Text(analysis.chronotype.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(analysis.chronotype.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(analysis.chronotype.color.opacity(0.2))
                )

                // Quick stats
                HStack(spacing: 8) {
                    quickStat(
                        icon: "bed.double.fill",
                        value: formatDuration(analysis.session.totalDuration),
                        label: "Duration",
                        color: .cyan
                    )
                    quickStat(
                        icon: "percent",
                        value: "\(Int(analysis.session.sleepEfficiency * 100))%",
                        label: "Efficiency",
                        color: .green
                    )
                }

                // Sub-scores
                VStack(spacing: 6) {
                    subScoreRow(label: "Architecture", score: analysis.architectureScore, color: .purple)
                    subScoreRow(label: "Timing", score: analysis.timingScore, color: .orange)
                    subScoreRow(label: "Continuity", score: analysis.continuityScore, color: .cyan)
                }
                .padding(.horizontal, 4)

                Text("Swipe down for stages")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
    }

    private func quickStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func subScoreRow(label: String, score: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 4)
                }
            }
            .frame(width: 60, height: 4)

            Text("\(score)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 25, alignment: .trailing)
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Hypnogram Page

struct HypnogramPage: View {
    let analysis: SleepAnalysis

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                pageIndicator(current: 1, total: 4)

                Text("Sleep Stages")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                // Hypnogram chart
                hypnogramChart
                    .frame(height: 80)
                    .padding(.horizontal, 4)

                // Stage breakdown
                VStack(spacing: 6) {
                    ForEach(SleepStageCategory.allCases, id: \.self) { category in
                        if let percentage = analysis.session.stagePercentages[category] {
                            stageRow(category: category, percentage: percentage)
                        }
                    }
                }
                .padding(.horizontal, 4)

                // Sleep cycles
                HStack {
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("\(analysis.session.sleepCycles) Sleep Cycles")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
                .padding(.top, 4)

                Text("Swipe for alignment")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
    }

    private var hypnogramChart: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let totalDuration = analysis.session.totalDuration

            Canvas { context, size in
                let stages = analysis.session.stages

                for segment in stages {
                    let startRatio = segment.startTime.timeIntervalSince(analysis.session.bedtime) / totalDuration
                    let endRatio = segment.endTime.timeIntervalSince(analysis.session.bedtime) / totalDuration

                    let x = width * CGFloat(startRatio)
                    let segmentWidth = width * CGFloat(endRatio - startRatio)

                    // Y position based on stage depth
                    let yRatio: CGFloat
                    switch segment.stage {
                    case .awake: yRatio = 0.0
                    case .remLight, .rem: yRatio = 0.25
                    case .lightN1: yRatio = 0.45
                    case .lightN2: yRatio = 0.55
                    case .deepN3: yRatio = 0.75
                    case .deepN4: yRatio = 0.9
                    }

                    let y = height * yRatio
                    let rect = CGRect(x: x, y: y, width: max(segmentWidth, 1), height: height * 0.12)

                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(segment.stage.color)
                    )
                }

                // Draw depth labels
                let labels = ["Awake", "REM", "Light", "Deep"]
                let yPositions: [CGFloat] = [0.0, 0.25, 0.5, 0.82]

                for (index, label) in labels.enumerated() {
                    let y = height * yPositions[index]
                    context.draw(
                        Text(label)
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.4)),
                        at: CGPoint(x: -15, y: y + 6)
                    )
                }
            }
            .padding(.leading, 35)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func stageRow(category: SleepStageCategory, percentage: Double) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(category.color)
                .frame(width: 8, height: 8)

            Text(category.rawValue)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            // Bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(category.color)
                    .frame(width: geo.size.width * CGFloat(percentage))
            }
            .frame(width: 50, height: 6)

            Text("\(Int(percentage * 100))%")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Alignment Page

struct AlignmentPage: View {
    let analysis: SleepAnalysis
    @StateObject private var chronotypeManager = ChronotypeManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                pageIndicator(current: 2, total: 4)

                Text("Circadian Alignment")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                // Alignment visualization
                alignmentRing

                // Timing details
                VStack(spacing: 8) {
                    timingRow(
                        label: "Your Bedtime",
                        actual: formatTime(analysis.session.bedtime),
                        optimal: "Optimal: \(formatOptimalTime(analysis.chronotype.optimalBedtimeStart))",
                        deviation: analysis.bedtimeDeviation
                    )

                    timingRow(
                        label: "Your Wake Time",
                        actual: formatTime(analysis.session.wakeTime),
                        optimal: "Optimal: \(formatOptimalTime(analysis.chronotype.optimalWakeTime))",
                        deviation: analysis.wakeTimeDeviation
                    )
                }
                .padding(.horizontal, 4)

                // Chronotype tip
                chronotypeTip

                Text("Swipe for insights")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
    }

    private var alignmentRing: some View {
        ZStack {
            // 24-hour clock face
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 6)
                .frame(width: 90, height: 90)

            // Optimal sleep window arc
            Circle()
                .trim(from: optimalArcStart, to: optimalArcEnd)
                .stroke(
                    analysis.chronotype.color.opacity(0.3),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-90))

            // Actual sleep arc
            Circle()
                .trim(from: actualArcStart, to: actualArcEnd)
                .stroke(
                    analysis.isWithinOptimalWindow ? Color.green : Color.orange,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 0) {
                Text("\(analysis.timingScore)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Timing")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var optimalArcStart: CGFloat {
        CGFloat(analysis.chronotype.optimalBedtimeStart) / 24.0
    }

    private var optimalArcEnd: CGFloat {
        var end = CGFloat(analysis.chronotype.optimalWakeTime) / 24.0
        if end < optimalArcStart { end += 1.0 }
        return end
    }

    private var actualArcStart: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: analysis.session.bedtime)
        let minute = calendar.component(.minute, from: analysis.session.bedtime)
        return CGFloat(hour * 60 + minute) / (24 * 60)
    }

    private var actualArcEnd: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: analysis.session.wakeTime)
        let minute = calendar.component(.minute, from: analysis.session.wakeTime)
        var end = CGFloat(hour * 60 + minute) / (24 * 60)
        if end < actualArcStart { end += 1.0 }
        return end
    }

    private func timingRow(label: String, actual: String, optimal: String, deviation: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(actual)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            }

            HStack {
                Text(optimal)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(formatDeviation(deviation))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(abs(deviation) < 3600 ? .green : .orange)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var chronotypeTip: some View {
        HStack(spacing: 8) {
            Text(analysis.chronotype.emoji)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(analysis.chronotype.displayName) Tip")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(analysis.chronotype.color)

                Text(ChronotypeProfile(
                    chronotype: analysis.chronotype,
                    confidence: 0.8,
                    assessmentMethod: .questionnaire
                ).tips.first ?? "")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(analysis.chronotype.color.opacity(0.15))
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatOptimalTime(_ hour: Double) -> String {
        let wholeHour = Int(hour) % 24
        let minutes = Int((hour - Double(Int(hour))) * 60)
        let isPM = wholeHour >= 12
        let displayHour = wholeHour > 12 ? wholeHour - 12 : (wholeHour == 0 ? 12 : wholeHour)
        return String(format: "%d:%02d %@", displayHour, minutes, isPM ? "PM" : "AM")
    }

    private func formatDeviation(_ seconds: TimeInterval) -> String {
        let minutes = Int(abs(seconds) / 60)
        if minutes < 60 {
            let direction = seconds > 0 ? "late" : "early"
            return "\(minutes)m \(direction)"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            let direction = seconds > 0 ? "late" : "early"
            return "\(hours)h \(remainingMins)m \(direction)"
        }
    }
}

// MARK: - Insights Page

struct InsightsPage: View {
    let analysis: SleepAnalysis

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                pageIndicator(current: 3, total: 4)

                Text("Sleep Insights")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                // Top insights
                ForEach(analysis.insights.prefix(4)) { insight in
                    insightCard(insight)
                }

                // Top recommendation
                if let recommendation = analysis.recommendations.first {
                    recommendationCard(recommendation)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
    }

    private func insightCard(_ insight: SleepInsight) -> some View {
        HStack(spacing: 8) {
            Image(systemName: insight.icon)
                .font(.system(size: 14))
                .foregroundColor(insight.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)

                Text(insight.description)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(insight.color.opacity(0.1))
        )
    }

    private func recommendationCard(_ rec: SleepRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: rec.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text("Recommendation")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.orange)
            }

            Text(rec.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)

            Text(rec.description)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Chronotype Quiz View

struct ChronotypeQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chronotypeManager = ChronotypeManager.shared
    @State private var currentQuestion = 0
    @State private var responses: [Int: Int] = [:]
    @State private var showResult = false
    @State private var result: (Chronotype, Double)?

    private let questions = ChronotypeManager.assessmentQuestions

    var body: some View {
        NavigationStack {
            if showResult, let result = result {
                resultView(chronotype: result.0, confidence: result.1)
            } else {
                questionView
            }
        }
    }

    private var questionView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Progress
                HStack {
                    Text("Q\(currentQuestion + 1)/\(questions.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple)
                                .frame(width: geo.size.width * CGFloat(currentQuestion + 1) / CGFloat(questions.count))
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 8)

                let question = questions[currentQuestion]

                Text(question.question)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Options
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        selectOption(index)
                    }) {
                        Text(option.text)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(responses[question.id] == index ? Color.purple : Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .navigationTitle("Chronotype Quiz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectOption(_ index: Int) {
        let question = questions[currentQuestion]
        responses[question.id] = index

        // Small delay then advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if currentQuestion < questions.count - 1 {
                withAnimation {
                    currentQuestion += 1
                }
            } else {
                // Calculate result
                result = chronotypeManager.calculateChronotypeFromResponses(responses)
                withAnimation {
                    showResult = true
                }
            }
        }
    }

    private func resultView(chronotype: Chronotype, confidence: Double) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(chronotype.emoji)
                    .font(.system(size: 50))

                Text("You're a \(chronotype.displayName)!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(chronotype.color)

                Text(chronotype.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                // Confidence
                HStack {
                    Text("Confidence:")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(Int(confidence * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }

                Button(action: {
                    chronotypeManager.saveChronotype(chronotype, confidence: confidence)
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(chronotype.color)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Your Chronotype")
    }
}

// MARK: - Helper Views

private func pageIndicator(current: Int, total: Int) -> some View {
    HStack(spacing: 4) {
        ForEach(0..<total, id: \.self) { index in
            Circle()
                .fill(index == current ? Color.white : Color.white.opacity(0.3))
                .frame(width: 5, height: 5)
        }
    }
    .padding(.top, 4)
}

// MARK: - Preview

#if DEBUG
struct SleepStagesView_Previews: PreviewProvider {
    static var previews: some View {
        SleepStagesView()
    }
}
#endif
