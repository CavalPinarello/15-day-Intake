//
//  AuroraBorealisView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Animated aurora borealis background effect
//  Vibrant, luminescent waves that flow across the screen
//

import SwiftUI

/// Animated aurora borealis background - vibrant and luminescent
struct AuroraBorealisView: View {
    @State private var phase: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: CGFloat = 0.6

    // Vibrant aurora colors - bright and luminescent
    private let auroraColors: [Color] = [
        Color(red: 0.0, green: 0.8, blue: 0.9),   // Bright cyan
        Color(red: 0.1, green: 0.9, blue: 0.8),   // Turquoise
        Color(red: 0.2, green: 0.7, blue: 0.9),   // Sky blue
        Color(red: 0.0, green: 0.6, blue: 0.7),   // Deep teal
        Color(red: 0.3, green: 0.9, blue: 0.7),   // Seafoam
        Color(red: 0.1, green: 0.5, blue: 0.8),   // Ocean blue
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep dark background
                Color(red: 0.02, green: 0.03, blue: 0.08)

                // Glowing aurora layers - more layers, more vibrant
                ForEach(0..<6, id: \.self) { index in
                    AuroraWaveLayer(
                        color: auroraColors[index],
                        phase: phase + CGFloat(index) * 0.8,
                        amplitude: 50 + CGFloat(index) * 15,
                        frequency: 1.2 + CGFloat(index) * 0.3,
                        verticalPosition: 0.2 + CGFloat(index) * 0.1,
                        geometry: geometry
                    )
                    .blur(radius: 15 + CGFloat(index) * 5)
                    .opacity(0.7 - CGFloat(index) * 0.08)
                }

                // Extra glow layer for luminescence
                RadialGradient(
                    colors: [
                        Color(red: 0.1, green: 0.8, blue: 0.8).opacity(glowIntensity * 0.4),
                        Color(red: 0.0, green: 0.5, blue: 0.6).opacity(glowIntensity * 0.2),
                        Color.clear
                    ],
                    center: .init(x: 0.3, y: 0.3),
                    startRadius: 50,
                    endRadius: geometry.size.width * 0.8
                )
                .scaleEffect(pulseScale)

                // Second glow spot
                RadialGradient(
                    colors: [
                        Color(red: 0.2, green: 0.9, blue: 0.7).opacity(glowIntensity * 0.3),
                        Color(red: 0.1, green: 0.6, blue: 0.7).opacity(glowIntensity * 0.15),
                        Color.clear
                    ],
                    center: .init(x: 0.7, y: 0.5),
                    startRadius: 30,
                    endRadius: geometry.size.width * 0.6
                )
                .scaleEffect(pulseScale * 0.9)

                // Bright stars
                StarsOverlay()
                    .opacity(0.6)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Fast wave movement
        withAnimation(
            .linear(duration: 4)
            .repeatForever(autoreverses: false)
        ) {
            phase = .pi * 2
        }

        // Pulsing glow effect
        withAnimation(
            .easeInOut(duration: 2)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.15
            glowIntensity = 0.9
        }
    }
}

/// Individual aurora wave layer - more dramatic waves
struct AuroraWaveLayer: View {
    let color: Color
    let phase: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat
    let verticalPosition: CGFloat
    let geometry: GeometryProxy

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let width = size.width
            let height = size.height
            let baseY = height * verticalPosition

            path.move(to: CGPoint(x: 0, y: height))

            // Create flowing wave with multiple sine components
            for x in stride(from: 0, through: width, by: 2) {
                let normalizedX = x / width
                let y = baseY
                    + sin(normalizedX * .pi * frequency * 2 + phase) * amplitude
                    + sin(normalizedX * .pi * frequency * 3 + phase * 1.3) * (amplitude * 0.6)
                    + sin(normalizedX * .pi * frequency * 5 + phase * 0.7) * (amplitude * 0.3)
                path.addLine(to: CGPoint(x: x, y: y))
            }

            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()

            // Fill with gradient for more depth
            let gradient = Gradient(colors: [
                color.opacity(0.9),
                color.opacity(0.5),
                color.opacity(0.2)
            ])
            context.fill(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: baseY - amplitude),
                    endPoint: CGPoint(x: 0, y: height)
                )
            )
        }
    }
}

/// Twinkling star field overlay
struct StarsOverlay: View {
    @State private var twinklePhase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let starCount = 80
            for i in 0..<starCount {
                let seed = Double(i * 12345)
                let x = (sin(seed) * 0.5 + 0.5) * size.width
                let y = (cos(seed * 1.3) * 0.5 + 0.5) * size.height * 0.7
                let baseSize = 1.0 + (sin(seed * 2.7) * 0.5 + 0.5) * 2.5
                let baseBrightness = 0.4 + (cos(seed * 3.1) * 0.5 + 0.5) * 0.6

                // Twinkle effect
                let twinkle = sin(twinklePhase + seed * 0.1) * 0.3 + 0.7
                let starSize = baseSize * twinkle
                let brightness = baseBrightness * twinkle

                let rect = CGRect(x: x - starSize/2, y: y - starSize/2, width: starSize, height: starSize)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(brightness))
                )
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 3)
                .repeatForever(autoreverses: false)
            ) {
                twinklePhase = .pi * 2
            }
        }
    }
}

/// Aurora with animated shimmer effect
struct AuroraShimmerView: View {
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AuroraBorealisView()

                // Shimmer overlay
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.1),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: shimmerPhase * geometry.size.width * 2 - geometry.size.width)
                .blur(radius: 30)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 3)
                .repeatForever(autoreverses: false)
            ) {
                shimmerPhase = 1
            }
        }
    }
}

#Preview("Aurora Borealis") {
    AuroraBorealisView()
}

#Preview("Aurora with Shimmer") {
    AuroraShimmerView()
}
