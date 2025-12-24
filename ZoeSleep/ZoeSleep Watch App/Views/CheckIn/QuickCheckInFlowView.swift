//
//  QuickCheckInFlowView.swift
//  ZoeSleep Watch App
//
//  A 3-screen check-in flow: Energy → Mood → Focus
//  Background gradient changes with selection intensity.
//

import SwiftUI
import WatchKit

// MARK: - Quick Check-In Flow

/// The main check-in flow view - swipeable pages for Energy, Mood, Focus
struct QuickCheckInFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let checkInType: CheckInType
    let onComplete: (EnergyLevel, MoodLevel, FocusLevel) -> Void

    @State private var currentPage = 0
    @State private var energyLevel: EnergyLevel = .cat
    @State private var moodLevel: MoodLevel = .cloudy
    @State private var focusLevel: FocusLevel = .clearing
    @State private var isSubmitting = false
    @State private var showSuccess = false

    // Crown values for each page
    @State private var energyCrownValue: Double = 3.0
    @State private var moodCrownValue: Double = 3.0
    @State private var focusCrownValue: Double = 3.0

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
                CheckInSuccessView {
                    dismiss()
                }
            } else {
                // Use a simple switch instead of TabView for better Crown control
                VStack {
                    switch currentPage {
                    case 0:
                        EnergyCheckInPage(
                            energyLevel: $energyLevel,
                            crownValue: $energyCrownValue,
                            onNext: { withAnimation { currentPage = 1 } }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                    case 1:
                        MoodCheckInPage(
                            moodLevel: $moodLevel,
                            crownValue: $moodCrownValue,
                            onNext: { withAnimation { currentPage = 2 } },
                            onBack: { withAnimation { currentPage = 0 } }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                    case 2:
                        FocusCheckInPage(
                            focusLevel: $focusLevel,
                            crownValue: $focusCrownValue,
                            isSubmitting: isSubmitting,
                            onSubmit: submitCheckIn,
                            onBack: { withAnimation { currentPage = 1 } }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Page indicator at bottom
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(i == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: i == currentPage ? 8 : 6, height: i == currentPage ? 8 : 6)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private func submitCheckIn() {
        guard !isSubmitting else { return }
        isSubmitting = true

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)

        // Show success animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSuccess = true
        }

        // Call completion handler
        onComplete(energyLevel, moodLevel, focusLevel)

        // Auto-dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

// MARK: - Energy Check-In Page

struct EnergyCheckInPage: View {
    @Binding var energyLevel: EnergyLevel
    @Binding var crownValue: Double
    let onNext: () -> Void

    @State private var iconBounce: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 6) {
            IntensityDisplayView(
                selection: energyLevel,
                title: "How's your energy?",
                icon: "bolt.fill",
                iconBounce: iconBounce
            )

            Button(action: onNext) {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.25))
            .padding(.horizontal, 12)
        }
        .focusable()
        .digitalCrownRotation(
            detent: $crownValue,
            from: 1.0,
            through: Double(EnergyLevel.allCases.count),
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { oldValue, newValue in
            let index = Int(newValue.rounded())
            if let newLevel = EnergyLevel(rawValue: index), newLevel != energyLevel {
                triggerBounce()
                energyLevel = newLevel
            }
        }
        .onAppear {
            crownValue = Double(energyLevel.rawValue)
        }
    }

    private func triggerBounce() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            iconBounce = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                iconBounce = 1.0
            }
        }
    }
}

// MARK: - Mood Check-In Page

struct MoodCheckInPage: View {
    @Binding var moodLevel: MoodLevel
    @Binding var crownValue: Double
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var iconBounce: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 6) {
            IntensityDisplayView(
                selection: moodLevel,
                title: "How's your mood?",
                icon: "heart.fill",
                iconBounce: iconBounce
            )

            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .frame(width: 40, height: 36)

                Button(action: onNext) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))
            }
            .padding(.horizontal, 12)
        }
        .focusable()
        .digitalCrownRotation(
            detent: $crownValue,
            from: 1.0,
            through: Double(MoodLevel.allCases.count),
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { oldValue, newValue in
            let index = Int(newValue.rounded())
            if let newLevel = MoodLevel(rawValue: index), newLevel != moodLevel {
                triggerBounce()
                moodLevel = newLevel
            }
        }
        .onAppear {
            crownValue = Double(moodLevel.rawValue)
        }
    }

    private func triggerBounce() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            iconBounce = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                iconBounce = 1.0
            }
        }
    }
}

// MARK: - Focus Check-In Page

struct FocusCheckInPage: View {
    @Binding var focusLevel: FocusLevel
    @Binding var crownValue: Double
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onBack: () -> Void

    @State private var iconBounce: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 6) {
            IntensityDisplayView(
                selection: focusLevel,
                title: "How focused?",
                icon: "scope",
                iconBounce: iconBounce
            )

            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .frame(width: 40, height: 36)

                Button(action: onSubmit) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                            Text("Done")
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.35))
                .disabled(isSubmitting)
            }
            .padding(.horizontal, 12)
        }
        .focusable()
        .digitalCrownRotation(
            detent: $crownValue,
            from: 1.0,
            through: Double(FocusLevel.allCases.count),
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { oldValue, newValue in
            let index = Int(newValue.rounded())
            if let newLevel = FocusLevel(rawValue: index), newLevel != focusLevel {
                triggerBounce()
                focusLevel = newLevel
            }
        }
        .onAppear {
            crownValue = Double(focusLevel.rawValue)
        }
    }

    private func triggerBounce() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            iconBounce = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                iconBounce = 1.0
            }
        }
    }
}

// MARK: - Intensity Display View

/// Display view for intensity - shows icon, label, and bar (crown handled at page level)
struct IntensityDisplayView<T: IntensitySelectable>: View {
    let selection: T
    let title: String
    let icon: String
    var iconBounce: CGFloat = 1.0

    @State private var pulsePhase: CGFloat = 0

    // Dynamic sizing based on intensity (0.0 to 1.0)
    private var intensityRatio: CGFloat {
        CGFloat(selection.intensityIndex - 1) / CGFloat(max(1, T.allOptions.count - 1))
    }

    // Icon scales from 0.7x to 1.2x based on intensity
    private var iconScale: CGFloat {
        0.7 + (intensityRatio * 0.5)
    }

    // Circle scales from 0.8x to 1.1x
    private var circleScale: CGFloat {
        0.85 + (intensityRatio * 0.25)
    }

    // Glow opacity increases with intensity
    private var glowOpacity: CGFloat {
        0.05 + (intensityRatio * 0.25)
    }

    // Ring opacity/width increases
    private var ringOpacity: CGFloat {
        0.1 + (intensityRatio * 0.3)
    }

    // Pulse speed increases with energy (slower = calmer, faster = energized)
    private var pulseDuration: Double {
        3.0 - (Double(intensityRatio) * 1.5) // 3s at low, 1.5s at high
    }

    var body: some View {
        VStack(spacing: 8) {
            // Title
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            // Dynamic icon with intensity-based size and glow
            ZStack {
                // Outer pulse ring (only visible at higher levels)
                if intensityRatio > 0.3 {
                    Circle()
                        .stroke(Color.white.opacity(ringOpacity * 0.5), lineWidth: 1)
                        .frame(width: 80 * circleScale, height: 80 * circleScale)
                        .scaleEffect(1.0 + pulsePhase * 0.08)
                        .opacity(Double(1.0 - pulsePhase * 0.5))
                }

                // Glow background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(glowOpacity), Color.white.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50 * circleScale
                        )
                    )
                    .frame(width: 90 * circleScale, height: 90 * circleScale)

                // Main circle ring
                Circle()
                    .stroke(Color.white.opacity(ringOpacity), lineWidth: 2 + intensityRatio * 1)
                    .frame(width: 68 * circleScale, height: 68 * circleScale)

                // Inner filled circle
                Circle()
                    .fill(Color.white.opacity(0.08 + intensityRatio * 0.12))
                    .frame(width: 60 * circleScale, height: 60 * circleScale)

                // Icon - grows with intensity
                Image(systemName: icon)
                    .font(.system(size: 26 * iconScale, weight: intensityRatio > 0.5 ? .regular : .light))
                    .foregroundColor(.white.opacity(0.7 + intensityRatio * 0.3))
                    .scaleEffect(iconBounce)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selection.intensityIndex)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: iconBounce)

            // Label
            Text(selection.label)
                .font(.system(size: 17, weight: intensityRatio > 0.6 ? .bold : .semibold))
                .foregroundColor(.white.opacity(0.85 + intensityRatio * 0.15))
                .animation(.easeInOut(duration: 0.2), value: selection.intensityIndex)

            // Intensity bar
            HStack(spacing: 3) {
                ForEach(T.allOptions, id: \.intensityIndex) { option in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(option.intensityIndex <= selection.intensityIndex
                              ? Color.white.opacity(0.7 + intensityRatio * 0.3)
                              : Color.white.opacity(0.15))
                        .frame(height: 5)
                        .animation(.spring(response: 0.3), value: selection.intensityIndex)
                }
            }
            .padding(.horizontal, 20)

            // Hint
            Text("Rotate Crown")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
        }
        .onAppear {
            startPulseAnimation()
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: pulseDuration)
            .repeatForever(autoreverses: true)
        ) {
            pulsePhase = 1
        }
    }
}

// MARK: - Intensity Selectable Protocol

/// Protocol for types that can be selected via intensity scale
protocol IntensitySelectable: CaseIterable, Equatable {
    var intensityIndex: Int { get }
    var label: String { get }
    var gradientColors: [Color] { get }

    static var allOptions: [Self] { get }
    static func fromIntensityIndex(_ index: Int) -> Self?
}

extension IntensitySelectable where Self: RawRepresentable, Self.RawValue == Int {
    var intensityIndex: Int { rawValue }

    static var allOptions: [Self] {
        Array(allCases)
    }

    static func fromIntensityIndex(_ index: Int) -> Self? {
        Self(rawValue: index)
    }
}

// MARK: - EnergyLevel IntensitySelectable

extension EnergyLevel: IntensitySelectable {
    var gradientColors: [Color] {
        // Cool muted (low) → Vibrant warm gold (high)
        switch self {
        case .sleepingSeal:
            return [Color(red: 0.08, green: 0.08, blue: 0.15), Color(red: 0.12, green: 0.1, blue: 0.2)]
        case .turtle:
            return [Color(red: 0.12, green: 0.1, blue: 0.2), Color(red: 0.18, green: 0.14, blue: 0.25)]
        case .cat:
            return [Color(red: 0.2, green: 0.16, blue: 0.22), Color(red: 0.28, green: 0.2, blue: 0.22)]
        case .dog:
            return [Color(red: 0.35, green: 0.25, blue: 0.15), Color(red: 0.45, green: 0.3, blue: 0.12)]
        case .ostrich:
            return [Color(red: 0.5, green: 0.35, blue: 0.1), Color(red: 0.65, green: 0.42, blue: 0.08)]
        case .rabbit:
            // Bright vibrant gold/amber
            return [Color(red: 0.65, green: 0.45, blue: 0.05), Color(red: 0.8, green: 0.55, blue: 0.05)]
        }
    }
}

// MARK: - MoodLevel IntensitySelectable

extension MoodLevel: IntensitySelectable {
    var gradientColors: [Color] {
        // Dark stormy → Bright warm sunshine
        switch self {
        case .stormy:
            return [Color(red: 0.1, green: 0.1, blue: 0.15), Color(red: 0.12, green: 0.12, blue: 0.2)]
        case .rainy:
            return [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.16, green: 0.18, blue: 0.28)]
        case .cloudy:
            return [Color(red: 0.18, green: 0.18, blue: 0.22), Color(red: 0.24, green: 0.22, blue: 0.26)]
        case .partlySunny:
            return [Color(red: 0.32, green: 0.28, blue: 0.18), Color(red: 0.42, green: 0.35, blue: 0.15)]
        case .sunny:
            // Bright warm yellow-gold
            return [Color(red: 0.55, green: 0.42, blue: 0.1), Color(red: 0.7, green: 0.52, blue: 0.08)]
        case .rainbow:
            // Vibrant warm pink/coral
            return [Color(red: 0.55, green: 0.35, blue: 0.4), Color(red: 0.7, green: 0.42, blue: 0.45)]
        }
    }
}

// MARK: - FocusLevel IntensitySelectable

extension FocusLevel: IntensitySelectable {
    var gradientColors: [Color] {
        // Foggy gray → Bright crystal teal/cyan
        switch self {
        case .foggy:
            return [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.15, green: 0.15, blue: 0.18)]
        case .hazy:
            return [Color(red: 0.14, green: 0.16, blue: 0.2), Color(red: 0.18, green: 0.2, blue: 0.25)]
        case .clearing:
            return [Color(red: 0.12, green: 0.2, blue: 0.28), Color(red: 0.15, green: 0.28, blue: 0.35)]
        case .clear:
            return [Color(red: 0.08, green: 0.28, blue: 0.38), Color(red: 0.1, green: 0.38, blue: 0.48)]
        case .crystal:
            // Bright vibrant teal/cyan
            return [Color(red: 0.05, green: 0.38, blue: 0.5), Color(red: 0.08, green: 0.5, blue: 0.6)]
        }
    }
}

// MARK: - Check-In Success View

struct CheckInSuccessView: View {
    let onDismiss: () -> Void

    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0
    @State private var confettiOpacity: Double = 0
    @State private var confettiOffset: CGFloat = 0

    private let confettiColors: [Color] = [.pink, .orange, .yellow, .green, .blue, .purple]

    var body: some View {
        ZStack {
            // Confetti particles
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(confettiColors[i % confettiColors.count])
                    .frame(width: 6, height: 6)
                    .offset(
                        x: cos(Double(i) * .pi / 6) * (30 + confettiOffset),
                        y: sin(Double(i) * .pi / 6) * (30 + confettiOffset) - 10
                    )
                    .opacity(confettiOpacity)
            }

            // Success content
            VStack(spacing: 12) {
                // Checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }

                Text("Check-In Complete!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(checkmarkOpacity)

                Text("Your garden is blooming")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(checkmarkOpacity)
            }
        }
        .onAppear {
            // Checkmark animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }

            // Confetti burst
            withAnimation(.easeOut(duration: 0.4)) {
                confettiOpacity = 1.0
                confettiOffset = 20
            }

            // Confetti fade
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    confettiOpacity = 0
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct QuickCheckInFlowView_Previews: PreviewProvider {
    static var previews: some View {
        QuickCheckInFlowView(checkInType: .morning) { energy, mood, focus in
            print("Check-in: \(energy.label), \(mood.label), \(focus.label)")
        }
    }
}
#endif
