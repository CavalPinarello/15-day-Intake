//
//  SleepFingerprintCard.swift
//  Zoe Sleep for Longevity System
//
//  Shows the user's personalized sleep phenotype and patterns
//  "This is who you are as a sleeper"
//

import SwiftUI

// MARK: - Sleep Phenotype Model

struct SleepPhenotype: Identifiable {
    let id = UUID()
    let phenotypeId: String
    let name: String
    let title: String
    let description: String
    let confidence: Int
    let patterns: [SleepPatternInfo]
    let leveragePoints: [String]
    let weekNumber: Int
}

struct SleepPatternInfo: Identifiable {
    let id = UUID()
    let patternId: String
    let name: String
    let description: String
    let evidence: [String]
    let confidence: Int
    let confidenceLabel: String
}

// MARK: - Sleep Fingerprint Card

struct SleepFingerprintCard: View {
    let phenotype: SleepPhenotype?
    let daysUntilAvailable: Int
    let isLoading: Bool

    @State private var isExpanded = false
    @State private var showPatternDetails = false
    @State private var selectedPattern: SleepPatternInfo?

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var phenotypeColor: Color {
        guard let p = phenotype else { return .gray }
        switch p.phenotypeId {
        case "tired_but_wired": return .purple
        case "sleep_state_misperception": return .blue
        case "compensator": return .orange
        case "irregular_rhythm": return .yellow
        case "fragmented_sleeper": return .red
        case "early_terminator": return .pink
        case "delayed_phase": return .indigo
        case "efficiency_struggler": return .teal
        default: return .blue
        }
    }

    private var phenotypeIcon: String {
        guard let p = phenotype else { return "moon.zzz.fill" }
        switch p.phenotypeId {
        case "tired_but_wired": return "brain.head.profile"
        case "sleep_state_misperception": return "eye.trianglebadge.exclamationmark"
        case "compensator": return "calendar.badge.clock"
        case "irregular_rhythm": return "waveform.path.ecg"
        case "fragmented_sleeper": return "chart.bar.xaxis"
        case "early_terminator": return "sunrise.fill"
        case "delayed_phase": return "moon.stars.fill"
        case "efficiency_struggler": return "hourglass"
        default: return "moon.zzz.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingState
            } else if let phenotype = phenotype {
                fingerprintContent(phenotype)
            } else {
                lockedState
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isEvening ? Color(white: 0.08) : Color(.systemBackground))
                .shadow(color: phenotypeColor.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: phenotype != nil ? [phenotypeColor.opacity(0.5), phenotypeColor.opacity(0.2)] : [Color.gray.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .sheet(item: $selectedPattern) { pattern in
            PatternDetailSheet(pattern: pattern, phenotypeColor: phenotypeColor)
                .environmentObject(themeManager)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: phenotypeColor))

            Text("Analyzing your sleep patterns...")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Locked State

    private var lockedState: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "fingerprint")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)

                Text("Your Sleep Fingerprint")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            // Locked icon and message
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "fingerprint")
                    .font(.system(size: 36))
                    .foregroundColor(.gray.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("\(daysUntilAvailable) more nights")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Text("to unlock your Sleep Fingerprint")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)
            }

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(index < (7 - daysUntilAvailable) ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Text("We're learning your unique sleep patterns...")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Fingerprint Content

    private func fingerprintContent(_ phenotype: SleepPhenotype) -> some View {
        VStack(spacing: 0) {
            // Main card content
            VStack(spacing: 16) {
                // Header with phenotype
                phenotypeHeader(phenotype)

                // Description
                Text(phenotype.description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780).opacity(0.85) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Confidence indicator
                confidenceBar(phenotype.confidence)

                // Expand button
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                    HStack {
                        Text(isExpanded ? "Show Less" : "See Your Patterns")
                            .font(.system(size: 14, weight: .medium, design: .rounded))

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(phenotypeColor)
                }
            }
            .padding(20)

            // Expanded content
            if isExpanded {
                Divider()
                    .background(phenotypeColor.opacity(0.3))

                expandedContent(phenotype)
                    .padding(20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Phenotype Header

    private func phenotypeHeader(_ phenotype: SleepPhenotype) -> some View {
        HStack(spacing: 16) {
            // Phenotype icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [phenotypeColor.opacity(0.3), phenotypeColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: phenotypeIcon)
                    .font(.system(size: 28))
                    .foregroundColor(phenotypeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR SLEEP FINGERPRINT")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(phenotypeColor)
                    .tracking(1)

                Text(phenotype.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Text("Week \(phenotype.weekNumber) Analysis")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Confidence Bar

    private func confidenceBar(_ confidence: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Confidence")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(confidence)%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(phenotypeColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(phenotypeColor.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(phenotypeColor)
                        .frame(width: geometry.size.width * CGFloat(confidence) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(phenotypeColor.opacity(0.05))
        )
    }

    // MARK: - Expanded Content

    private func expandedContent(_ phenotype: SleepPhenotype) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Patterns section
            if !phenotype.patterns.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("DETECTED PATTERNS")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1)

                    ForEach(phenotype.patterns) { pattern in
                        PatternRow(pattern: pattern, color: phenotypeColor)
                            .onTapGesture {
                                selectedPattern = pattern
                            }
                    }
                }
            }

            // Leverage points section
            if !phenotype.leveragePoints.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)

                        Text("WHAT CAN HELP")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(1)
                    }

                    ForEach(phenotype.leveragePoints.prefix(3), id: \.self) { point in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)

                            Text(formatLeveragePoint(point))
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }

    private func formatLeveragePoint(_ point: String) -> String {
        // Convert snake_case to Title Case
        point.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}

// MARK: - Pattern Row

struct PatternRow: View {
    let pattern: SleepPatternInfo
    let color: Color

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        HStack(spacing: 12) {
            // Confidence indicator
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                Text(pattern.description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Confidence badge
            Text(pattern.confidenceLabel)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color.opacity(0.15))
                )

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isEvening ? Color(white: 0.12) : Color(.systemGray6))
        )
    }
}

// MARK: - Pattern Detail Sheet

struct PatternDetailSheet: View {
    let pattern: SleepPatternInfo
    let phenotypeColor: Color

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Pattern header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pattern.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)

                        HStack {
                            Text("Confidence:")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.secondary)

                            Text("\(pattern.confidence)%")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(phenotypeColor)

                            Text("(\(pattern.confidenceLabel))")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Description
                    Text(pattern.description)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780).opacity(0.9) : .primary)

                    // Evidence section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(phenotypeColor)

                            Text("Evidence")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)
                        }

                        ForEach(pattern.evidence, id: \.self) { evidence in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(phenotypeColor)
                                    .padding(.top, 2)

                                Text(evidence)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780).opacity(0.8) : .secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(phenotypeColor.opacity(0.1))
                    )

                    Spacer()
                }
                .padding(24)
            }
            .background(
                isEvening
                    ? Color(red: 0.05, green: 0.05, blue: 0.08)
                    : Color(.systemGroupedBackground)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(phenotypeColor)
                }
            }
        }
    }
}

// MARK: - Cohort Percentile Card

struct CohortPercentileCard: View {
    let metricName: String
    let percentile: Int?
    let cohortDescription: String
    let cohortSize: Int
    let userValue: Double?
    let cohortMean: Double?
    let message: String

    @EnvironmentObject var themeManager: ThemeManager

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var percentileColor: Color {
        guard let p = percentile else { return .gray }
        if p >= 75 { return .green }
        if p >= 50 { return .blue }
        if p >= 25 { return .yellow }
        return .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AMONG PEOPLE LIKE YOU")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(percentileColor)
                        .tracking(1)

                    Text(cohortDescription)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780) : .primary)
                }

                Spacer()

                if let percentile = percentile {
                    PercentileRing(percentile: percentile, color: percentileColor)
                }
            }

            // Message
            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(isEvening ? Color(red: 0.996, green: 0.953, blue: 0.780).opacity(0.8) : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Comparison values
            if let userValue = userValue, let cohortMean = cohortMean {
                HStack {
                    ComparisonValueCell(
                        label: "You",
                        value: formatValue(userValue, for: metricName),
                        color: percentileColor
                    )

                    Spacer()

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    ComparisonValueCell(
                        label: "Cohort Avg",
                        value: formatValue(cohortMean, for: metricName),
                        color: .gray
                    )
                }
                .padding(.top, 4)
            }

            // Sample size
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("Based on \(cohortSize)+ similar users")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(percentileColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatValue(_ value: Double, for metric: String) -> String {
        switch metric.lowercased() {
        case "isi":
            return String(format: "%.0f", value)
        case "sleep_efficiency":
            return String(format: "%.0f%%", value)
        case "sleep_duration":
            let hours = Int(value) / 60
            let mins = Int(value) % 60
            return "\(hours)h \(mins)m"
        default:
            return String(format: "%.1f", value)
        }
    }
}

struct ComparisonValueCell: View {
    let label: String
    let value: String
    let color: Color

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct SleepFingerprintCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Unlocked fingerprint
                SleepFingerprintCard(
                    phenotype: SleepPhenotype(
                        phenotypeId: "tired_but_wired",
                        name: "Tired but Wired",
                        title: "The Tired but Wired Sleeper",
                        description: "Your body wants to sleep, but your mind races at night. This is common in high-achievers and those with demanding responsibilities.",
                        confidence: 85,
                        patterns: [
                            SleepPatternInfo(
                                patternId: "perception_gap",
                                name: "Perception Gap",
                                description: "You rate your sleep 4.2/10 but your efficiency is 82%",
                                evidence: ["5 nights with perception mismatch", "Average subjective: 4.2/10", "Average objective efficiency: 82%"],
                                confidence: 78,
                                confidenceLabel: "High"
                            ),
                            SleepPatternInfo(
                                patternId: "anxiety_driven",
                                name: "Anxiety-Driven Difficulty",
                                description: "Racing thoughts affect your ability to fall asleep",
                                evidence: ["Mental health gateway triggered", "Mind-body relaxation techniques are especially effective"],
                                confidence: 75,
                                confidenceLabel: "High"
                            )
                        ],
                        leveragePoints: ["cognitive_wind_down", "worry_time", "relaxation_techniques"],
                        weekNumber: 2
                    ),
                    daysUntilAvailable: 0,
                    isLoading: false
                )

                // Locked fingerprint
                SleepFingerprintCard(
                    phenotype: nil,
                    daysUntilAvailable: 3,
                    isLoading: false
                )

                // Cohort percentile
                CohortPercentileCard(
                    metricName: "ISI",
                    percentile: 78,
                    cohortDescription: "men in their 50s with families",
                    cohortSize: 312,
                    userValue: 15,
                    cohortMean: 18.5,
                    message: "Among 312 men in their 50s with families, you're managing better than 78%."
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .environmentObject(ThemeManager.shared)
    }
}
#endif
