//
//  CircadianExposureCard.swift
//  ZoeSleep Watch App
//
//  Displays daily light exposure progress with circadian-aware styling.
//  Shows a ring gauge, target indicator, and nudge when below target.
//

import SwiftUI

// MARK: - Circadian Status Model

struct CircadianStatus {
    let hasData: Bool
    let daylightMins: Int
    let targetMins: Int
    let percentOfTarget: Int
    let circadianScore: Int?
    let needsMoreLight: Bool
    let morningLightMins: Int

    static let empty = CircadianStatus(
        hasData: false,
        daylightMins: 0,
        targetMins: 90,
        percentOfTarget: 0,
        circadianScore: nil,
        needsMoreLight: true,
        morningLightMins: 0
    )
}

// MARK: - Circadian Exposure Card

struct CircadianExposureCard: View {
    let status: CircadianStatus
    let onTap: (() -> Void)?

    private let palette = WatchCircadianPalette.current

    init(status: CircadianStatus, onTap: (() -> Void)? = nil) {
        self.status = status
        self.onTap = onTap
    }

    private var progress: Double {
        min(1.0, Double(status.percentOfTarget) / 100.0)
    }

    private var progressColor: Color {
        if progress >= 0.9 { return .green }
        if progress >= 0.6 { return .yellow }
        return .orange
    }

    private var cardBackground: some ShapeStyle {
        Color.white.opacity(0.1)
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 10) {
                // Ring gauge
                ringGauge

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Light Exposure")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()

                        if let score = status.circadianScore {
                            Text("\(score)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(scoreColor(score))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(scoreColor(score).opacity(0.2))
                                )
                        }
                    }

                    // Stats row
                    HStack(spacing: 8) {
                        statItem(
                            icon: "sun.max.fill",
                            value: "\(status.daylightMins)",
                            unit: "min",
                            color: .yellow
                        )

                        if status.morningLightMins > 0 {
                            statItem(
                                icon: "sunrise.fill",
                                value: "\(status.morningLightMins)",
                                unit: "am",
                                color: .orange
                            )
                        }
                    }

                    // Nudge message
                    if status.needsMoreLight {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 8))
                            Text("Get more sunlight!")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.orange)
                    } else if status.daylightMins >= status.targetMins {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                            Text("Target reached!")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.green)
                    }
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ring Gauge

    private var ringGauge: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
                .frame(width: 36, height: 36)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))

            // Center icon
            Image(systemName: "sun.max.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)
        }
    }

    // MARK: - Stat Item

    private func statItem(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)

            Text(unit)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Score Color

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }
}

// MARK: - Empty State Card (shown when no data)

struct CircadianExposureEmptyCard: View {
    private var cardBackground: some ShapeStyle {
        Color.white.opacity(0.1)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Ring gauge with 0%
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    .frame(width: 36, height: 36)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Light Exposure")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)

                Text("0 min today")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 8))
                    Text("Go outside!")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct CircadianExposureCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 10) {
                // With data - needs more light
                CircadianExposureCard(
                    status: CircadianStatus(
                        hasData: true,
                        daylightMins: 45,
                        targetMins: 90,
                        percentOfTarget: 50,
                        circadianScore: 62,
                        needsMoreLight: true,
                        morningLightMins: 20
                    )
                )

                // With data - target reached
                CircadianExposureCard(
                    status: CircadianStatus(
                        hasData: true,
                        daylightMins: 95,
                        targetMins: 90,
                        percentOfTarget: 100,
                        circadianScore: 88,
                        needsMoreLight: false,
                        morningLightMins: 35
                    )
                )

                // Empty state
                CircadianExposureEmptyCard()
            }
            .padding()
        }
        .background(Color.black)
    }
}
#endif
