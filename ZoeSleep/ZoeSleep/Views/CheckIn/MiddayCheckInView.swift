//
//  MiddayCheckInView.swift
//  ZoeSleep
//
//  Midday check-in view for quick energy, caffeine, and nap tracking.
//  Shown at 2:00 PM notification or when user opens app in the afternoon.
//
//  Contents:
//  - Energy level assessment (1-4)
//  - Caffeine intake tracker (cups + last time)
//  - Nap tracker (yes/no + duration)
//

import SwiftUI

struct MiddayCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var timeFormatManager = TimeFormatManager.shared

    // Check-in state
    @State private var energyLevel: Int = 0
    @State private var caffeineCups: Int = 0
    @State private var caffeineLastTime: Date = Date()
    @State private var hadCaffeine: Bool = false
    @State private var napTaken: Bool = false
    @State private var napDuration: Int = 0  // minutes

    // UI state
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?

    private var theme: ColorTheme { themeManager.currentTheme }

    // Force DatePicker to use 12-hour or 24-hour format based on user preference
    private var pickerLocale: Locale {
        switch timeFormatManager.preference {
        case .system:
            return Locale.current
        case .hour12:
            return Locale(identifier: "en_US")
        case .hour24:
            return Locale(identifier: "en_GB")
        }
    }

    // Quick completion target: 30 seconds
    private let napDurations = [0, 10, 15, 20, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Energy Level
                    energyLevelSection

                    // Caffeine Tracker
                    caffeineSection

                    // Nap Tracker
                    napSection

                    // Submit Button
                    submitSection
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Midday Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .overlay {
            if showingSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Afternoon Check-in")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.textOnCard)

            Text("Quick energy and habits update")
                .font(.subheadline)
                .foregroundColor(theme.textOnCardSecondary)

            // Time indicator
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption)
                Text("Takes ~30 seconds")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    // MARK: - Energy Level Section

    private var energyLevelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How's your energy right now?")
                .font(.headline)
                .foregroundColor(theme.textOnCard)

            HStack(spacing: 12) {
                ForEach(EnergyOption.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            energyLevel = option.rawValue
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            Text(option.emoji)
                                .font(.title)

                            Text(option.label)
                                .font(.caption)
                                .foregroundColor(energyLevel == option.rawValue ? theme.textOnCard : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(energyLevel == option.rawValue ? option.color.opacity(0.2) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    energyLevel == option.rawValue ? option.color : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    // MARK: - Caffeine Section

    private var caffeineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(.brown)
                Text("Caffeine Today")
                    .font(.headline)
                    .foregroundColor(theme.textOnCard)
            }

            // Caffeine toggle
            Toggle(isOn: $hadCaffeine.animation()) {
                Text("Had caffeine?")
                    .foregroundColor(theme.textOnCard)
            }
            .tint(.brown)

            if hadCaffeine {
                VStack(spacing: 16) {
                    // Cups counter
                    HStack {
                        Text("Cups/servings")
                            .foregroundColor(theme.textOnCardSecondary)

                        Spacer()

                        HStack(spacing: 16) {
                            Button {
                                if caffeineCups > 0 {
                                    caffeineCups -= 1
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(caffeineCups > 0 ? .brown : .gray.opacity(0.3))
                            }
                            .disabled(caffeineCups == 0)

                            Text("\(caffeineCups)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textOnCard)
                                .frame(minWidth: 40)

                            Button {
                                if caffeineCups < 10 {
                                    caffeineCups += 1
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(caffeineCups < 10 ? .brown : .gray.opacity(0.3))
                            }
                            .disabled(caffeineCups >= 10)
                        }
                    }

                    // Last caffeine time
                    HStack {
                        Text("Last cup at")
                            .foregroundColor(theme.textOnCardSecondary)

                        Spacer()

                        DatePicker("", selection: $caffeineLastTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .environment(\.locale, pickerLocale)
                            .tint(.brown)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    // MARK: - Nap Section

    private var napSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundColor(.indigo)
                Text("Nap Today")
                    .font(.headline)
                    .foregroundColor(theme.textOnCard)
            }

            // Nap toggle
            Toggle(isOn: $napTaken.animation()) {
                Text("Took a nap?")
                    .foregroundColor(theme.textOnCard)
            }
            .tint(.indigo)

            if napTaken {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How long?")
                        .font(.subheadline)
                        .foregroundColor(theme.textOnCardSecondary)

                    // Duration chips
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(napDurations, id: \.self) { mins in
                            Button {
                                napDuration = mins
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(napDurationLabel(mins))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(napDuration == mins ? .white : theme.textOnCard)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(napDuration == mins ? Color.indigo : Color.gray.opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(16)
    }

    // MARK: - Submit Section

    private var submitSection: some View {
        VStack(spacing: 12) {
            Button {
                submitCheckIn()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Check-in")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(energyLevel == 0 || isSubmitting)
            .opacity(energyLevel == 0 ? 0.5 : 1)

            // Validation message
            if energyLevel == 0 {
                Text("Select your energy level to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("Check-in Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("See you this evening")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground).opacity(0.95))
            )
        }
        .transition(.opacity)
    }

    // MARK: - Helpers

    private func napDurationLabel(_ mins: Int) -> String {
        if mins == 0 { return "None" }
        if mins < 60 { return "\(mins)m" }
        if mins == 60 { return "1hr" }
        return "\(mins/60)hr\(mins%60 > 0 ? " \(mins%60)m" : "")"
    }

    private func submitCheckIn() {
        isSubmitting = true

        Task {
            do {
                // Format caffeine time as HH:MM
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                let caffeineTimeStr = hadCaffeine ? formatter.string(from: caffeineLastTime) : nil

                try await ConvexService.shared.submitMiddayCheckIn(
                    energyLevel: energyLevel,
                    caffeineCups: hadCaffeine ? caffeineCups : 0,
                    caffeineLastTime: caffeineTimeStr,
                    napTaken: napTaken,
                    napDurationMins: napTaken ? napDuration : nil
                )

                await MainActor.run {
                    isSubmitting = false

                    // Haptic success
                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    // Show success overlay
                    withAnimation {
                        showingSuccess = true
                    }

                    // Dismiss after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to save check-in. Please try again."
                    print("[MiddayCheckIn] Error: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MiddayCheckInView_Previews: PreviewProvider {
    static var previews: some View {
        MiddayCheckInView()
            .environmentObject(ThemeManager.shared)
    }
}
#endif
