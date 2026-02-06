//
//  QuickCheckInWidget.swift
//  ZoeSleep
//
//  Dashboard widget showing check-in status with quick access.
//  Shows morning/midday/evening completion circles and prompts
//  for the current check-in window.
//

import SwiftUI

// MARK: - Quick Check-In Widget

/// Dashboard card showing daily check-in status with tap-to-open functionality.
struct QuickCheckInWidget: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var checkInManager = CheckInManager.shared

    @State private var showingCheckIn = false
    @State private var showingVoiceCheckIn = false

    private var theme: ColorTheme { themeManager.currentTheme }

    // Current time slot for check-in
    private var currentSlot: CheckInTimeSlot? {
        CheckInTimeSlot.current
    }

    // Status for each time slot
    private var morningDone: Bool {
        checkInManager.morningCheckInCompleted
    }

    private var middayDone: Bool {
        checkInManager.middayCheckInCompleted
    }

    private var eveningDone: Bool {
        checkInManager.eveningCheckInCompleted
    }

    private var allDone: Bool {
        morningDone && middayDone && eveningDone
    }

    private var completedCount: Int {
        [morningDone, middayDone, eveningDone].filter { $0 }.count
    }

    var body: some View {
        Button {
            if let slot = currentSlot, !isSlotCompleted(slot) {
                showingCheckIn = true
            }
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingCheckIn) {
            if let slot = currentSlot {
                WatchStyleCheckInView(
                    timeSlot: slot,
                    onComplete: handleCheckInComplete
                )
                .environmentObject(themeManager)
            }
        }
        .fullScreenCover(isPresented: $showingVoiceCheckIn) {
            if let slot = currentSlot {
                RealTimeVoiceCheckInView(
                    timeSlot: slot,
                    onComplete: {
                        // ViewModel handles submission, just reload status
                        Task {
                            await checkInManager.loadTodayStatus()
                        }
                    }
                )
                .environmentObject(themeManager)
            }
        }
        .onAppear {
            // Load today's check-in status from Convex
            Task {
                await checkInManager.loadTodayStatus()
            }
        }
        .onChange(of: showingCheckIn) { _, isShowing in
            // Refresh status when sheet dismisses
            if !isShowing {
                Task {
                    // Small delay to ensure Convex has saved the data
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    await checkInManager.loadTodayStatus()
                }
            }
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Focus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                    Text("Energy · Mood · Focus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                // Completion indicator
                Text("\(completedCount)/3")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)
            }

            // Time slot circles
            HStack(spacing: 24) {
                timeSlotIndicator(slot: .morning, isDone: morningDone)
                timeSlotIndicator(slot: .midday, isDone: middayDone)
                timeSlotIndicator(slot: .evening, isDone: eveningDone)
            }
            .frame(maxWidth: .infinity)

            // Current prompt or completion message
            if allDone {
                completionMessage
            } else if let slot = currentSlot, !isSlotCompleted(slot) {
                promptMessage(for: slot)
            } else {
                waitingMessage
            }
        }
        .padding(20)
        .background(GlassyCardBackground(opacity: 0.5))
        .cornerRadius(20)
    }

    // MARK: - Time Slot Indicator

    private func timeSlotIndicator(slot: CheckInTimeSlot, isDone: Bool) -> some View {
        let isActive = currentSlot == slot && !isDone
        // Use theme-aware colors for better contrast in light circadian modes
        let inactiveRingColor = theme.primaryText.opacity(0.25)
        let inactiveIconColor = theme.primaryText.opacity(0.4)
        let inactiveLabelColor = theme.secondaryText

        return VStack(spacing: 8) {
            ZStack {
                // Background circle with subtle fill for inactive
                if !isDone && !isActive {
                    Circle()
                        .fill(theme.primaryText.opacity(0.05))
                        .frame(width: 52, height: 52)
                }

                // Ring stroke
                Circle()
                    .stroke(
                        isDone ? Color.green.opacity(0.5) : (isActive ? slot.color : inactiveRingColor),
                        lineWidth: isDone ? 3 : (isActive ? 3 : 2)
                    )
                    .frame(width: 52, height: 52)

                // Fill for completed
                if isDone {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    // Icon for pending
                    Image(systemName: slot.sfSymbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isActive ? slot.color : inactiveIconColor)
                }

                // Active indicator ring (outer glow)
                if isActive {
                    Circle()
                        .stroke(slot.color.opacity(0.5), lineWidth: 2)
                        .frame(width: 60, height: 60)
                }
            }

            Text(slot.label)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .foregroundColor(isDone ? .green : (isActive ? theme.primaryText : inactiveLabelColor))
        }
    }

    // MARK: - Messages

    private func promptMessage(for slot: CheckInTimeSlot) -> some View {
        HStack(spacing: 12) {
            // Tap prompt
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 16))
                    .foregroundColor(slot.color)

                Text("Tap to check in")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // Voice button
            Button {
                showingVoiceCheckIn = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                    Text("Voice")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(theme.textOnPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.accent)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(slot.color.opacity(0.15))
        )
    }

    private var completionMessage: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(.green)

            Text("All check-ins complete for today!")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.green.opacity(0.9))

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }

    private var waitingMessage: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))

            Text("Next check-in window opens soon")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Helpers

    private func isSlotCompleted(_ slot: CheckInTimeSlot) -> Bool {
        switch slot {
        case .morning: return morningDone
        case .midday: return middayDone
        case .evening: return eveningDone
        }
    }

    private func handleCheckInComplete(energy: EnergyLevel, mood: MoodLevel, focus: FocusLevel) {
        guard let slot = currentSlot else { return }

        Task {
            await checkInManager.submitWatchStyleCheckIn(
                timeSlot: slot,
                energy: energy,
                mood: mood,
                focus: focus
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct QuickCheckInWidget_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            CircadianWaveBackground()

            ScrollView {
                VStack(spacing: 20) {
                    QuickCheckInWidget()
                }
                .padding(20)
            }
        }
        .environmentObject(ThemeManager.shared)
    }
}
#endif
