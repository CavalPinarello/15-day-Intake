//
//  JourneyIntroIcons.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Animated icon components for the Journey Introduction screens
//  Each icon has subtle animations that play when the screen appears
//

import SwiftUI

// MARK: - Screen 1: Moon with Orbiting Stars

struct JourneyIntroMoonIcon: View {
    @State private var rotation: Double = 0
    @State private var starPulse: CGFloat = 1.0

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.accent.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Orbiting stars container
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(palette.wave)
                        .scaleEffect(starPulse)
                        .offset(x: 45)
                        .rotationEffect(.degrees(Double(index) * 120 + rotation))
                }
            }

            // Main moon icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, palette.wave],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                Image(systemName: "moon.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundColor(palette.isDark ? .black.opacity(0.3) : .white.opacity(0.4))
            }
        }
        .onAppear {
            // Orbiting animation
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            // Star pulse
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                starPulse = 1.3
            }
        }
    }
}

// MARK: - Screen 2: Clipboard with Checkmark

struct JourneyIntroClipboardIcon: View {
    @State private var checkmarkProgress: CGFloat = 0
    @State private var glowOpacity: Double = 0.3

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.accent.opacity(glowOpacity), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Main circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.wave],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)

            // Clipboard icon
            Image(systemName: "list.clipboard.fill")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(palette.isDark ? .black.opacity(0.3) : .white.opacity(0.4))

            // Animated checkmark overlay
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(palette.isDark ? .black.opacity(0.5) : .white.opacity(0.6))
                .offset(x: 12, y: 12)
                .scaleEffect(checkmarkProgress)
                .opacity(Double(checkmarkProgress))
        }
        .onAppear {
            // Checkmark appears
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.5)) {
                checkmarkProgress = 1.0
            }
            // Glow pulse
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.5
            }
        }
    }
}

// MARK: - Screen 3: Brain with Gears

struct JourneyIntroBrainIcon: View {
    @State private var gearRotation1: Double = 0
    @State private var gearRotation2: Double = 0

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.accent.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Rotating gears (behind brain)
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18))
                .foregroundColor(palette.wave.opacity(0.6))
                .rotationEffect(.degrees(gearRotation1))
                .offset(x: -25, y: -25)

            Image(systemName: "gearshape.fill")
                .font(.system(size: 14))
                .foregroundColor(palette.wave.opacity(0.5))
                .rotationEffect(.degrees(gearRotation2))
                .offset(x: 28, y: 20)

            // Main circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.wave],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)

            // Brain icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 34, weight: .regular))
                .foregroundColor(palette.isDark ? .black.opacity(0.3) : .white.opacity(0.4))
        }
        .onAppear {
            // Gear rotations (opposite directions)
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                gearRotation1 = 360
            }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                gearRotation2 = -360
            }
        }
    }
}

// MARK: - Screen 4: Branching Paths

struct JourneyIntroPathIcon: View {
    @State private var pathOpacity1: Double = 0.2
    @State private var pathOpacity2: Double = 0.2
    @State private var pathOpacity3: Double = 0.2
    @State private var glowOpacity: Double = 0.3

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.accent.opacity(glowOpacity), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Branching path indicators (animated)
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(palette.wave)
                        .frame(width: 8, height: 8)
                        .opacity(pathOpacity1)

                    Circle()
                        .fill(palette.wave)
                        .frame(width: 8, height: 8)
                        .opacity(pathOpacity2)

                    Circle()
                        .fill(palette.wave)
                        .frame(width: 8, height: 8)
                        .opacity(pathOpacity3)
                }
            }
            .offset(y: -42)

            // Main circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.wave],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)

            // Arrow branching icon
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(palette.isDark ? .black.opacity(0.3) : .white.opacity(0.4))
        }
        .onAppear {
            // Sequential path illumination
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                pathOpacity1 = 1.0
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.6)) {
                pathOpacity2 = 1.0
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.9)) {
                pathOpacity3 = 1.0
            }
            // Glow pulse
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(1.5)) {
                glowOpacity = 0.5
            }
        }
    }
}

// MARK: - Screen 5: Watch with Pulse

struct JourneyIntroWatchIcon: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.5
    @State private var heartScale: CGFloat = 1.0

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        ZStack {
            // Pulse rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(palette.accent.opacity(pulseOpacity - Double(index) * 0.15), lineWidth: 2)
                    .frame(width: 70 + CGFloat(index) * 20, height: 70 + CGFloat(index) * 20)
                    .scaleEffect(pulseScale)
            }

            // Main circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.wave],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)

            // Watch icon
            Image(systemName: "applewatch")
                .font(.system(size: 34, weight: .regular))
                .foregroundColor(palette.isDark ? .black.opacity(0.3) : .white.opacity(0.4))

            // Heart overlay (pulse)
            Image(systemName: "heart.fill")
                .font(.system(size: 12))
                .foregroundColor(palette.isDark ? .black.opacity(0.4) : .white.opacity(0.5))
                .scaleEffect(heartScale)
                .offset(y: 2)
        }
        .onAppear {
            // Pulse wave animation
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseScale = 1.4
                pulseOpacity = 0
            }
            // Heart beat
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                heartScale = 1.2
            }
        }
    }
}

// MARK: - Screen 6: Clinician

struct JourneyIntroClinicianIcon: View {
    @State private var checkmarkScale: CGFloat = 0
    @State private var glowOpacity: Double = 0.3

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.accent.opacity(glowOpacity), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Main circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.wave],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)

            // Person with stethoscope icon
            Image(systemName: "stethoscope")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(palette.isDark ? .black.opacity(0.3) : .white.opacity(0.4))

            // Checkmark badge
            ZStack {
                Circle()
                    .fill(palette.wave)
                    .frame(width: 24, height: 24)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(palette.isDark ? .black : .white)
            }
            .scaleEffect(checkmarkScale)
            .offset(x: 28, y: -28)
        }
        .onAppear {
            // Checkmark appears with bounce
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.5)) {
                checkmarkScale = 1.0
            }
            // Glow pulse
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.5
            }
        }
    }
}

// MARK: - Previews

#Preview("Moon Icon") {
    ZStack {
        OnboardingCircadianBackground()
        JourneyIntroMoonIcon()
            .frame(width: 120, height: 120)
    }
}

#Preview("All Icons") {
    ZStack {
        OnboardingCircadianBackground()
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                JourneyIntroMoonIcon().frame(width: 80, height: 80)
                JourneyIntroClipboardIcon().frame(width: 80, height: 80)
                JourneyIntroBrainIcon().frame(width: 80, height: 80)
            }
            HStack(spacing: 20) {
                JourneyIntroPathIcon().frame(width: 80, height: 80)
                JourneyIntroWatchIcon().frame(width: 80, height: 80)
                JourneyIntroClinicianIcon().frame(width: 80, height: 80)
            }
        }
    }
}
