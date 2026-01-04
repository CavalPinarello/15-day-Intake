//
//  LightRxView.swift
//  ZoeSleep Watch App
//
//  Shows real daylight exposure data from HealthKit.
//  Emphasizes morning light (before 10 AM) for circadian optimization.
//

import SwiftUI
import WatchKit

struct LightRxView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthKitManager = HealthKitWatchManager.shared
    @State private var isLoading = true
    @State private var daylightData: DaylightExposureData?
    @State private var errorMessage: String?

    private let morningTarget = 30  // 30 min morning light target
    private let dailyTarget = 90    // 90 min total daily target

    private var darkBackground: [Color] {
        [
            Color(red: 0.08, green: 0.06, blue: 0.02),
            Color(red: 0.12, green: 0.10, blue: 0.04)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        loadingState
                    } else if let data = daylightData {
                        lightDataContent(data)
                    } else {
                        noDataState
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(colors: darkBackground, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Light Rx")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
            }
        }
        .onAppear {
            loadDaylightData()
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                .scaleEffect(1.5)

            Text("Loading Light Data...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text("Fetching from Apple Health")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - No Data State

    private var noDataState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.trianglebadge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.yellow.opacity(0.7))

            Text("No Light Data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            } else {
                Text("Time in Daylight requires watchOS 10+ and outdoor exposure")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            Button(action: { loadDaylightData() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.yellow.opacity(0.3))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: - Light Data Content

    private func lightDataContent(_ data: DaylightExposureData) -> some View {
        VStack(spacing: 14) {
            // Morning Light - THE KEY METRIC
            morningLightCard(data)

            // Total Daily Light
            totalLightCard(data)

            // Why Morning Light Matters
            tipCard
        }
    }

    // MARK: - Morning Light Card (Critical)

    private func morningLightCard(_ data: DaylightExposureData) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)

                Text("Morning Light")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("Before 10 AM")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                    .frame(width: 80, height: 80)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(1.0, CGFloat(data.morningMinutes) / CGFloat(morningTarget)))
                    .stroke(
                        LinearGradient(
                            colors: morningLightGradient(data.morningMinutes),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(data.morningMinutes)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("min")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Status message
            Text(morningStatusMessage(data.morningMinutes))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(morningStatusColor(data.morningMinutes))
                .multilineTextAlignment(.center)

            // Target indicator
            HStack {
                Text("Target: \(morningTarget) min")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))

                if data.morningMinutes >= morningTarget {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Total Light Card

    private func totalLightCard(_ data: DaylightExposureData) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)

                Text("Total Today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(data.totalMinutes) min")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.yellow)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(1.0, CGFloat(data.totalMinutes) / CGFloat(dailyTarget)), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(data.percentOfTarget)% of \(dailyTarget) min goal")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                if data.totalMinutes >= dailyTarget {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("Goal Met!")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - Tip Card

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                Text("Why Morning Light?")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.cyan)
            }

            Text("Bright light before 10 AM sets your circadian clock, improves sleep quality, and boosts daytime energy.")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cyan.opacity(0.1))
        )
    }

    // MARK: - Helper Functions

    private func morningLightGradient(_ minutes: Int) -> [Color] {
        if minutes >= morningTarget {
            return [.green, .mint]
        } else if minutes >= morningTarget / 2 {
            return [.yellow, .orange]
        } else {
            return [.orange, .red]
        }
    }

    private func morningStatusMessage(_ minutes: Int) -> String {
        if minutes >= morningTarget {
            return "Excellent! Circadian boost achieved"
        } else if minutes >= morningTarget / 2 {
            return "Good progress, get more sun!"
        } else if minutes > 0 {
            return "Need more morning light"
        } else {
            return "Get outside before 10 AM"
        }
    }

    private func morningStatusColor(_ minutes: Int) -> Color {
        if minutes >= morningTarget {
            return .green
        } else if minutes >= morningTarget / 2 {
            return .yellow
        } else {
            return .orange
        }
    }

    // MARK: - Data Loading

    private func loadDaylightData() {
        isLoading = true
        errorMessage = nil

        Task {
            // Ensure HealthKit permissions
            healthKitManager.requestPermissions()

            // Wait a moment for permissions and data sync
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Trigger a sync to load daylight data
            healthKitManager.syncHealthData()

            // Wait for data to load
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                if let data = healthKitManager.daylightExposure {
                    daylightData = data
                    print("[LightRxView] Loaded daylight data: \(data.totalMinutes) min total, \(data.morningMinutes) min morning")
                } else {
                    daylightData = nil
                    if #available(watchOS 10.0, *) {
                        errorMessage = "No daylight data recorded today. Go outside to start tracking!"
                    } else {
                        errorMessage = "Time in Daylight requires watchOS 10 or later."
                    }
                    print("[LightRxView] No daylight data available")
                }
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LightRxView_Previews: PreviewProvider {
    static var previews: some View {
        LightRxView()
    }
}
#endif
