//
//  SplashScreenView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Full-screen animated splash screen with circadian wave animation
//  Features the app logo that seamlessly blends with flowing waves
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var waveOffset: CGFloat = 0

    // Callback when splash is complete
    var onComplete: (() -> Void)?

    // Splash duration in seconds
    var duration: Double = 2.5

    // Theme colors
    private let backgroundColor = Color(red: 0.059, green: 0.090, blue: 0.165) // #0F172A
    private let tealColor = Color(red: 0.31, green: 0.80, blue: 0.77) // #4ECDC4
    private let accentColor = Color(red: 1.0, green: 0.85, blue: 0.40) // Warm amber

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep navy background
                backgroundColor

                // Animated wave layers
                WaveLayerGroup(size: geometry.size, isAnimating: isAnimating)

                // Center logo composition
                VStack(spacing: 24) {
                    // Animated logo
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(
                                tealColor.opacity(0.3),
                                lineWidth: 3
                            )
                            .frame(width: 180, height: 180)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .opacity(isAnimating ? 0 : 0.5)

                        // Main logo circle with gradient
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        tealColor.opacity(0.3),
                                        tealColor.opacity(0.1),
                                        backgroundColor
                                    ],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 160, height: 160)

                        // Circadian wave icon in center
                        CircadianWaveIcon(size: 100, color: tealColor)
                            .opacity(logoOpacity)

                        // Subtle energy orb
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accentColor.opacity(0.6),
                                        accentColor.opacity(0.2),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 15
                                )
                            )
                            .frame(width: 30, height: 30)
                            .offset(x: 35, y: -30)
                            .opacity(logoOpacity * 0.8)
                    }
                    .scaleEffect(logoScale)

                    // App name
                    VStack(spacing: 8) {
                        Text("Zoe Sleep")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Sleep Better, Live Longer")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(tealColor.opacity(0.8))
                    }
                    .opacity(textOpacity)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Logo fade in and scale
        withAnimation(.easeOut(duration: 0.8)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        // Text fade in (slightly delayed)
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            textOpacity = 1.0
        }

        // Continuous glow pulse
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            isAnimating = true
        }

        // Complete after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onComplete?()
        }
    }
}

// MARK: - Circadian Wave Icon (Vector logo)

struct CircadianWaveIcon: View {
    let size: CGFloat
    let color: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            // Three layered sine waves representing circadian rhythm
            ForEach(0..<3, id: \.self) { index in
                WaveIconPath(
                    phase: phase + CGFloat(index) * .pi / 3,
                    amplitude: (1.0 - CGFloat(index) * 0.2),
                    verticalOffset: CGFloat(index - 1) * 12
                )
                .stroke(
                    color.opacity(1.0 - Double(index) * 0.25),
                    style: StrokeStyle(
                        lineWidth: 3 - CGFloat(index) * 0.5,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size * 0.6)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

struct WaveIconPath: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var verticalOffset: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2 + verticalOffset
        let waveAmplitude = height * 0.25 * amplitude

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let angle = relativeX * .pi * 2 + phase
            let y = midY + sin(angle) * waveAmplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

// MARK: - Wave Layer Group for Splash

struct WaveLayerGroup: View {
    let size: CGSize
    let isAnimating: Bool
    @State private var phase: CGFloat = 0

    private let tealColor = Color(red: 0.31, green: 0.80, blue: 0.77)

    var body: some View {
        ZStack {
            // Multiple wave layers at different positions
            ForEach(0..<5, id: \.self) { index in
                SplashWave(
                    index: index,
                    size: size,
                    phase: phase,
                    color: tealColor
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

struct SplashWave: View {
    let index: Int
    let size: CGSize
    let phase: CGFloat
    let color: Color

    private var config: (amplitude: CGFloat, frequency: CGFloat, phaseOffset: CGFloat, yPosition: CGFloat, opacity: Double) {
        switch index {
        case 0:
            return (35, 1.2, 0, 0.15, 0.12)
        case 1:
            return (30, 1.5, .pi / 4, 0.35, 0.10)
        case 2:
            return (25, 1.8, .pi / 2, 0.55, 0.08)
        case 3:
            return (28, 1.3, .pi * 3/4, 0.72, 0.10)
        default:
            return (22, 2.0, .pi, 0.88, 0.06)
        }
    }

    var body: some View {
        SineWaveShape(
            phase: phase + config.phaseOffset,
            amplitude: config.amplitude,
            frequency: config.frequency
        )
        .stroke(
            color.opacity(config.opacity),
            style: StrokeStyle(
                lineWidth: 2.5,
                lineCap: .round
            )
        )
        .offset(y: size.height * (config.yPosition - 0.5))
    }
}

// MARK: - Animated Splash Screen with Transition

struct AnimatedSplashScreen: View {
    @State private var showSplash = true
    @State private var splashOpacity: Double = 1.0

    var body: some View {
        ZStack {
            // Main content (underneath)
            ContentView()
                .opacity(showSplash ? 0 : 1)

            // Splash screen (on top)
            if showSplash {
                SplashScreenView {
                    // Fade out splash
                    withAnimation(.easeInOut(duration: 0.5)) {
                        splashOpacity = 0
                    }

                    // Remove splash after fade
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSplash = false
                    }
                }
                .opacity(splashOpacity)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Previews

#Preview("Splash Screen") {
    SplashScreenView()
}

#Preview("Splash with Transition") {
    AnimatedSplashScreen()
        .environmentObject(AuthenticationManager())
        .environmentObject(HealthKitManager(authManager: AuthenticationManager()))
        .environmentObject(ThemeManager.shared)
}

#Preview("Wave Icon Only") {
    ZStack {
        Color(red: 0.059, green: 0.090, blue: 0.165)
        CircadianWaveIcon(
            size: 150,
            color: Color(red: 0.31, green: 0.80, blue: 0.77)
        )
    }
    .ignoresSafeArea()
}
