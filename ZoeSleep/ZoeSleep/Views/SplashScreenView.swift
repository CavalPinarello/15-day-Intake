//
//  SplashScreenView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Full-screen animated splash screen with circadian wave animation
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var wavePhase: CGFloat = 0

    // Callback when splash is complete
    var onComplete: (() -> Void)?

    // Splash duration in seconds
    var duration: Double = 2.5

    // Theme colors
    private let backgroundColor = Color(red: 0.04, green: 0.06, blue: 0.12)
    private let tealColor = Color(red: 0.35, green: 0.90, blue: 0.85)
    private let highlightColor = Color(red: 0.50, green: 1.0, blue: 0.95)
    private let accentColor = Color(red: 1.0, green: 0.85, blue: 0.40)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        backgroundColor,
                        Color(red: 0.06, green: 0.09, blue: 0.16),
                        Color(red: 0.05, green: 0.12, blue: 0.20)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Simple animated waves
                ForEach(0..<3, id: \.self) { index in
                    SimpleSplashWave(
                        index: index,
                        phase: wavePhase,
                        size: geometry.size
                    )
                }

                // Center logo composition
                VStack(spacing: 24) {
                    // Animated logo
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(highlightColor.opacity(0.3), lineWidth: 3)
                            .frame(width: 180, height: 180)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .opacity(isAnimating ? 0.4 : 0.7)

                        // Inner glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        tealColor.opacity(0.2),
                                        backgroundColor.opacity(0.3)
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)

                        // Wave icon
                        SplashWaveIcon(phase: wavePhase)
                            .frame(width: 100, height: 60)
                            .opacity(logoOpacity)

                        // Energy orb
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accentColor.opacity(0.8),
                                        accentColor.opacity(0.3),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 16
                                )
                            )
                            .frame(width: 32, height: 32)
                            .offset(x: 38, y: -32)
                            .opacity(logoOpacity * 0.9)
                    }
                    .scaleEffect(logoScale)

                    // App name
                    VStack(spacing: 8) {
                        Text("Zoe Sleep")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Sleep Better, Live Longer")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(tealColor.opacity(0.9))
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
        // Wave animation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }

        // Logo fade in and scale
        withAnimation(.easeOut(duration: 0.8)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        // Text fade in
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            textOpacity = 1.0
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            isAnimating = true
        }

        // Complete callback - ensure it runs on main thread
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onComplete?()
        }
    }
}

// MARK: - Simple Wave for Splash

struct SimpleSplashWave: View {
    let index: Int
    let phase: CGFloat
    let size: CGSize

    private var config: (amplitude: CGFloat, frequency: CGFloat, offset: CGFloat, yPos: CGFloat, opacity: Double) {
        switch index {
        case 0:
            return (50, 0.7, 0, 0.55, 0.15)
        case 1:
            return (40, 0.9, .pi / 3, 0.48, 0.12)
        default:
            return (30, 1.1, .pi * 2/3, 0.62, 0.10)
        }
    }

    private let waveColor = Color(red: 0.35, green: 0.90, blue: 0.85)

    var body: some View {
        GlassyWaveShape(
            phase: phase + config.offset,
            amplitude: config.amplitude,
            frequency: config.frequency,
            fillDown: true
        )
        .fill(
            LinearGradient(
                colors: [
                    waveColor.opacity(config.opacity * 1.2),
                    waveColor.opacity(config.opacity),
                    waveColor.opacity(config.opacity * 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .blur(radius: 6)
        .offset(y: size.height * config.yPos)
    }
}

// MARK: - Wave Icon for Splash

struct SplashWaveIcon: View {
    let phase: CGFloat
    private let color = Color(red: 0.50, green: 1.0, blue: 0.95)

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                WaveIconLine(
                    phase: phase + CGFloat(index) * .pi / 3,
                    amplitude: 1.0 - CGFloat(index) * 0.2,
                    yOffset: CGFloat(index - 1) * 12,
                    lineWidth: 3 - CGFloat(index) * 0.5,
                    opacity: 1.0 - Double(index) * 0.25
                )
                .stroke(color.opacity(1.0 - Double(index) * 0.25), style: StrokeStyle(lineWidth: 3 - CGFloat(index) * 0.5, lineCap: .round))
            }
        }
    }
}

struct WaveIconLine: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var yOffset: CGFloat
    var lineWidth: CGFloat
    var opacity: Double

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2 + yOffset
        let waveAmplitude = height * 0.25 * amplitude

        path.move(to: CGPoint(x: 0, y: midY + sin(phase) * waveAmplitude))

        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let angle = relativeX * .pi * 2 + phase
            let y = midY + sin(angle) * waveAmplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

// MARK: - Previews

#Preview("Splash Screen") {
    SplashScreenView()
}
