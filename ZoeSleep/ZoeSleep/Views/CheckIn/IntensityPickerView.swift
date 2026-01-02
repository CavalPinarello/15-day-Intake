//
//  IntensityPickerView.swift
//  ZoeSleep
//
//  A reusable intensity picker that replaces Watch's digital crown
//  with touch-based gestures for iPhone. Supports vertical drag or
//  slider-style interaction with animated feedback.
//

import SwiftUI

// MARK: - Intensity Picker View

/// A reusable picker for selecting intensity levels via drag gesture.
/// Replaces Watch's digital crown with finger-based interaction.
struct IntensityPickerView<T: IntensitySelectable>: View {
    @Binding var selection: T
    let title: String
    let categoryIcon: String

    @EnvironmentObject private var themeManager: ThemeManager

    @State private var iconBounce: CGFloat = 1.0
    @State private var pulsePhase: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    // Intensity ratio (0.0 to 1.0)
    private var intensityRatio: CGFloat {
        CGFloat(selection.intensityIndex - 1) / CGFloat(max(1, T.allOptions.count - 1))
    }

    // Icon scales from 0.7x to 1.2x based on intensity
    private var iconScale: CGFloat {
        0.7 + (intensityRatio * 0.5)
    }

    // Circle scales from 0.85x to 1.1x
    private var circleScale: CGFloat {
        0.85 + (intensityRatio * 0.25)
    }

    // Glow opacity increases with intensity
    private var glowOpacity: CGFloat {
        0.08 + (intensityRatio * 0.25)
    }

    // Ring opacity/width increases
    private var ringOpacity: CGFloat {
        0.15 + (intensityRatio * 0.35)
    }

    // Pulse speed increases with energy (slower = calmer, faster = energized)
    private var pulseDuration: Double {
        3.0 - (Double(intensityRatio) * 1.5)
    }

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(title)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)

            // Main interaction area
            intensityDisplay
                .contentShape(Rectangle())
                .gesture(dragGesture)

            // Label showing current selection
            Text(selection.label)
                .font(.system(size: 28, weight: intensityRatio > 0.6 ? .bold : .semibold, design: .rounded))
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.2), value: selection.intensityIndex)

            // Intensity bar with tap targets
            intensityBar

            // Hint text
            Text("Drag up/down or tap to select")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .onAppear {
            startPulseAnimation()
        }
    }

    // MARK: - Intensity Display

    private var intensityDisplay: some View {
        ZStack {
            // Outer pulse ring (only visible at higher levels)
            if intensityRatio > 0.3 {
                Circle()
                    .stroke(Color.white.opacity(ringOpacity * 0.4), lineWidth: 2)
                    .frame(width: 160 * circleScale, height: 160 * circleScale)
                    .scaleEffect(1.0 + pulsePhase * 0.06)
                    .opacity(Double(1.0 - pulsePhase * 0.4))
            }

            // Glow background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(glowOpacity), Color.white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100 * circleScale
                    )
                )
                .frame(width: 180 * circleScale, height: 180 * circleScale)

            // Main circle ring
            Circle()
                .stroke(Color.white.opacity(ringOpacity), lineWidth: 3 + intensityRatio * 2)
                .frame(width: 140 * circleScale, height: 140 * circleScale)

            // Inner filled circle
            Circle()
                .fill(Color.white.opacity(0.08 + intensityRatio * 0.12))
                .frame(width: 130 * circleScale, height: 130 * circleScale)

            // Selection-specific icon (the animal/weather/clarity icon)
            Image(systemName: selection.sfSymbol)
                .font(.system(size: 56 * iconScale, weight: intensityRatio > 0.5 ? .medium : .regular))
                .foregroundColor(.white.opacity(0.8 + intensityRatio * 0.2))
                .scaleEffect(iconBounce)

            // Category icon in corner
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: categoryIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(12)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                Spacer()
            }
            .frame(width: 180, height: 180)
        }
        .frame(height: 200)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selection.intensityIndex)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: iconBounce)
        .offset(y: isDragging ? dragOffset * 0.1 : 0)
    }

    // MARK: - Intensity Bar

    private var intensityBar: some View {
        HStack(spacing: 6) {
            ForEach(T.allOptions, id: \.intensityIndex) { option in
                Button {
                    selectOption(option)
                } label: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(option.intensityIndex <= selection.intensityIndex
                              ? Color.white.opacity(0.7 + intensityRatio * 0.3)
                              : Color.white.opacity(0.15))
                        .frame(height: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(option.intensityIndex == selection.intensityIndex
                                        ? Color.white.opacity(0.8)
                                        : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .animation(.spring(response: 0.3), value: selection.intensityIndex)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation.height

                // Sensitivity: ~60 points per level
                let sensitivity: CGFloat = 60
                let levelChange = -value.translation.height / sensitivity

                // Calculate target level
                let startIndex = selection.intensityIndex
                let targetIndex = startIndex + Int(levelChange.rounded())

                // Clamp to valid range
                let clampedIndex = max(1, min(T.allOptions.count, targetIndex))

                if clampedIndex != selection.intensityIndex {
                    if let newSelection = T.fromIntensityIndex(clampedIndex) {
                        selection = newSelection
                        triggerBounce()
                        generateHaptic(intensity: CGFloat(clampedIndex) / CGFloat(T.allOptions.count))
                    }
                }
            }
            .onEnded { _ in
                isDragging = false
                withAnimation(.spring(response: 0.3)) {
                    dragOffset = 0
                }
            }
    }

    // MARK: - Helpers

    private func selectOption(_ option: T) {
        guard option.intensityIndex != selection.intensityIndex else { return }
        selection = option
        triggerBounce()
        generateHaptic(intensity: intensityRatio)
    }

    private func triggerBounce() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            iconBounce = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                iconBounce = 1.0
            }
        }
    }

    private func generateHaptic(intensity: CGFloat) {
        guard themeManager.hapticFeedbackEnabled else { return }

        // Scale haptic intensity with selection level
        let impactStyle: UIImpactFeedbackGenerator.FeedbackStyle
        if intensity < 0.33 {
            impactStyle = .light
        } else if intensity < 0.66 {
            impactStyle = .medium
        } else {
            impactStyle = .heavy
        }

        let generator = UIImpactFeedbackGenerator(style: impactStyle)
        generator.impactOccurred()
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

// MARK: - Preview

#if DEBUG
struct IntensityPickerView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var energy: EnergyLevel = .cat
        @State private var mood: MoodLevel = .cloudy
        @State private var focus: FocusLevel = .clearing

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: energy.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    IntensityPickerView(
                        selection: $energy,
                        title: "How's your energy?",
                        categoryIcon: "bolt.fill"
                    )

                    IntensityPickerView(
                        selection: $mood,
                        title: "How's your mood?",
                        categoryIcon: "heart.fill"
                    )
                }
            }
            .environmentObject(ThemeManager.shared)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
