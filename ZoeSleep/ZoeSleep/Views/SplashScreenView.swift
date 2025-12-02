//
//  SplashScreenView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Simple splash screen with logo and text - no complex animations
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0

    // Callback when splash is complete
    var onComplete: (() -> Void)?

    // Splash duration in seconds
    var duration: Double = 2.0

    // Theme colors
    private let backgroundColor = Color(red: 0.04, green: 0.06, blue: 0.12)
    private let tealColor = Color(red: 0.35, green: 0.90, blue: 0.85)
    private let highlightColor = Color(red: 0.50, green: 1.0, blue: 0.95)
    private let accentColor = Color(red: 1.0, green: 0.85, blue: 0.40)

    var body: some View {
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

            // Center logo composition
            VStack(spacing: 24) {
                // Logo
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(highlightColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 160, height: 160)

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
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)

                    // Static wave icon
                    StaticWaveIcon()
                        .frame(width: 80, height: 50)
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
                                endRadius: 14
                            )
                        )
                        .frame(width: 28, height: 28)
                        .offset(x: 32, y: -28)
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
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Logo fade in and scale
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        // Text fade in
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            textOpacity = 1.0
        }

        // Complete callback
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onComplete?()
        }
    }
}

// MARK: - Static Wave Icon (no animation)

struct StaticWaveIcon: View {
    private let color = Color(red: 0.50, green: 1.0, blue: 0.95)

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let amplitude: CGFloat = 12

            // Draw three wave lines
            for i in 0..<3 {
                let yOffset = CGFloat(i - 1) * 14
                let opacity = 1.0 - Double(i) * 0.3
                let lineWidth = 3.0 - CGFloat(i) * 0.5
                let phase = CGFloat(i) * .pi / 3

                var path = Path()
                path.move(to: CGPoint(x: 0, y: midY + yOffset + sin(phase) * amplitude))

                for x in stride(from: 0, through: size.width, by: 4) {
                    let angle = (x / size.width) * .pi * 2 + phase
                    let y = midY + yOffset + sin(angle) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                context.stroke(
                    path,
                    with: .color(color.opacity(opacity)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Splash Screen") {
    SplashScreenView()
}
