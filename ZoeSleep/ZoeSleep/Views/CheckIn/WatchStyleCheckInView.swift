//
//  WatchStyleCheckInView.swift
//  ZoeSleep
//
//  Apple Watch-style check-in flow for iPhone.
//  A 3-page swipeable experience: Energy -> Mood -> Focus
//  with dynamic gradient backgrounds and animated feedback.
//

import SwiftUI

// MARK: - Watch Style Check-In View

/// Main check-in flow view - swipeable pages for Energy, Mood, Focus
/// Mirrors the Apple Watch experience but adapted for iPhone touch interaction.
struct WatchStyleCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let timeSlot: CheckInTimeSlot
    let onComplete: (EnergyLevel, MoodLevel, FocusLevel) -> Void

    @State private var currentPage = 0
    @State private var energyLevel: EnergyLevel = .cat
    @State private var moodLevel: MoodLevel = .cloudy
    @State private var focusLevel: FocusLevel = .clearing
    @State private var isSubmitting = false
    @State private var showSuccess = false

    // Dynamic gradient based on current selection
    private var currentGradient: LinearGradient {
        let colors: [Color]
        switch currentPage {
        case 0: colors = energyLevel.gradientColors
        case 1: colors = moodLevel.gradientColors
        case 2: colors = focusLevel.gradientColors
        default: colors = [Color(white: 0.1), Color(white: 0.15)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            // Dynamic animated gradient background
            currentGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: energyLevel)
                .animation(.easeInOut(duration: 0.5), value: moodLevel)
                .animation(.easeInOut(duration: 0.5), value: focusLevel)
                .animation(.easeInOut(duration: 0.4), value: currentPage)

            if showSuccess {
                CheckInSuccessOverlay {
                    dismiss()
                }
            } else {
                VStack(spacing: 0) {
                    // Header with time slot and close button
                    headerView

                    // Page content
                    TabView(selection: $currentPage) {
                        energyPage.tag(0)
                        moodPage.tag(1)
                        focusPage.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

                    // Page indicator and navigation
                    navigationFooter
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Time slot indicator
            HStack(spacing: 8) {
                Image(systemName: timeSlot.sfSymbol)
                    .font(.system(size: 16, weight: .semibold))
                Text(timeSlot.label + " Check-In")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.8))

            Spacer()

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Energy Page

    private var energyPage: some View {
        VStack {
            Spacer()

            IntensityPickerView(
                selection: $energyLevel,
                title: "How's your energy?",
                categoryIcon: "bolt.fill"
            )

            Spacer()
        }
    }

    // MARK: - Mood Page

    private var moodPage: some View {
        VStack {
            Spacer()

            IntensityPickerView(
                selection: $moodLevel,
                title: "How's your mood?",
                categoryIcon: "heart.fill"
            )

            Spacer()
        }
    }

    // MARK: - Focus Page

    private var focusPage: some View {
        VStack {
            Spacer()

            IntensityPickerView(
                selection: $focusLevel,
                title: "How's your focus?",
                categoryIcon: "eye.fill"
            )

            Spacer()
        }
    }

    // MARK: - Navigation Footer

    private var navigationFooter: some View {
        VStack(spacing: 16) {
            // Page indicator dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? Color.white : Color.white.opacity(0.3))
                        .frame(width: i == currentPage ? 10 : 8, height: i == currentPage ? 10 : 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            // Navigation buttons
            HStack(spacing: 16) {
                // Back button (hidden on first page)
                if currentPage > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage -= 1
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                }

                Spacer()

                // Next/Submit button
                Button {
                    if currentPage < 2 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    } else {
                        submitCheckIn()
                    }
                } label: {
                    HStack {
                        Text(currentPage < 2 ? "Next" : "Submit")
                        Image(systemName: currentPage < 2 ? "chevron.right" : "checkmark")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(currentPage < 2 ? .white : .black)
                    .frame(width: currentPage < 2 ? 100 : 140, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(currentPage < 2 ? Color.white.opacity(0.3) : Color.white)
                    )
                }
                .disabled(isSubmitting)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Submit

    private func submitCheckIn() {
        guard !isSubmitting else { return }
        isSubmitting = true

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show success animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSuccess = true
        }

        // Call completion handler
        onComplete(energyLevel, moodLevel, focusLevel)

        // Auto-dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            dismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WatchStyleCheckInView_Previews: PreviewProvider {
    static var previews: some View {
        WatchStyleCheckInView(
            timeSlot: .morning,
            onComplete: { energy, mood, focus in
                print("Completed: E=\(energy.label), M=\(mood.label), F=\(focus.label)")
            }
        )
        .environmentObject(ThemeManager.shared)
    }
}
#endif
