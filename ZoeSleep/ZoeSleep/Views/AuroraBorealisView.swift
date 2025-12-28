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

/// Enhanced aurora borealis with more dramatic, fluid animations
/// Designed for splash screen with vertical flowing curtains
struct EnhancedAuroraBorealisView: View {
    @State private var phase: CGFloat = 0
    @State private var verticalFlow: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: CGFloat = 0.5
    @State private var colorShift: CGFloat = 0

    // Rich aurora color palette
    private let primaryColors: [Color] = [
        Color(red: 0.0, green: 0.85, blue: 0.85),   // Bright cyan
        Color(red: 0.1, green: 0.95, blue: 0.75),   // Electric turquoise
        Color(red: 0.0, green: 0.75, blue: 0.95),   // Deep sky blue
        Color(red: 0.2, green: 0.85, blue: 0.65),   // Seafoam green
    ]

    private let secondaryColors: [Color] = [
        Color(red: 0.3, green: 0.6, blue: 0.9),    // Soft blue
        Color(red: 0.1, green: 0.7, blue: 0.8),    // Teal
        Color(red: 0.0, green: 0.55, blue: 0.75),  // Ocean
        Color(red: 0.15, green: 0.8, blue: 0.7),   // Aquamarine
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep space background with subtle gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.02, blue: 0.06),
                        Color(red: 0.02, green: 0.04, blue: 0.10),
                        Color(red: 0.01, green: 0.03, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Vertical flowing aurora curtains (multiple layers)
                ForEach(0..<4, id: \.self) { curtainIndex in
                    AuroraCurtainLayer(
                        colors: curtainIndex % 2 == 0 ? primaryColors : secondaryColors,
                        phase: phase,
                        verticalFlow: verticalFlow + CGFloat(curtainIndex) * 0.25,
                        curtainIndex: curtainIndex,
                        geometry: geometry
                    )
                    .blur(radius: 20 + CGFloat(curtainIndex) * 8)
                    .opacity(0.6 - CGFloat(curtainIndex) * 0.1)
                }

                // Horizontal wave layers (original style, but enhanced)
                ForEach(0..<5, id: \.self) { index in
                    let colorIndex = (index + Int(colorShift * 4)) % 4
                    AuroraWaveLayer(
                        color: primaryColors[colorIndex],
                        phase: phase + CGFloat(index) * 0.6,
                        amplitude: 40 + CGFloat(index) * 12,
                        frequency: 1.0 + CGFloat(index) * 0.25,
                        verticalPosition: 0.25 + CGFloat(index) * 0.12,
                        geometry: geometry
                    )
                    .blur(radius: 18 + CGFloat(index) * 6)
                    .opacity(0.5 - CGFloat(index) * 0.07)
                }

                // Central luminous glow that pulses
                RadialGradient(
                    colors: [
                        Color(red: 0.1, green: 0.9, blue: 0.85).opacity(glowIntensity * 0.35),
                        Color(red: 0.0, green: 0.7, blue: 0.8).opacity(glowIntensity * 0.2),
                        Color(red: 0.0, green: 0.5, blue: 0.6).opacity(glowIntensity * 0.1),
                        Color.clear
                    ],
                    center: .init(x: 0.5, y: 0.35),
                    startRadius: 20,
                    endRadius: geometry.size.width * 0.7
                )
                .scaleEffect(pulseScale)

                // Secondary glow - upper left
                RadialGradient(
                    colors: [
                        Color(red: 0.2, green: 0.95, blue: 0.8).opacity(glowIntensity * 0.25),
                        Color(red: 0.1, green: 0.7, blue: 0.75).opacity(glowIntensity * 0.12),
                        Color.clear
                    ],
                    center: .init(x: 0.2, y: 0.2),
                    startRadius: 30,
                    endRadius: geometry.size.width * 0.5
                )
                .scaleEffect(pulseScale * 0.95)

                // Tertiary glow - lower right
                RadialGradient(
                    colors: [
                        Color(red: 0.0, green: 0.8, blue: 0.9).opacity(glowIntensity * 0.2),
                        Color.clear
                    ],
                    center: .init(x: 0.8, y: 0.6),
                    startRadius: 20,
                    endRadius: geometry.size.width * 0.4
                )
                .scaleEffect(pulseScale * 1.05)

                // Enhanced twinkling stars
                EnhancedStarsOverlay()
                    .opacity(0.7)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startEnhancedAnimation()
        }
    }

    private func startEnhancedAnimation() {
        // Horizontal wave movement
        withAnimation(
            .linear(duration: 6)
            .repeatForever(autoreverses: false)
        ) {
            phase = .pi * 2
        }

        // Vertical flowing movement (slower, creates curtain effect)
        withAnimation(
            .linear(duration: 10)
            .repeatForever(autoreverses: false)
        ) {
            verticalFlow = 1.0
        }

        // Breathing glow pulse
        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.15
            glowIntensity = 0.85
        }

        // Subtle color cycling
        withAnimation(
            .linear(duration: 12)
            .repeatForever(autoreverses: false)
        ) {
            colorShift = 1.0
        }
    }
}

/// Vertical aurora curtain layer - creates the classic "curtain" effect
struct AuroraCurtainLayer: View {
    let colors: [Color]
    let phase: CGFloat
    let verticalFlow: CGFloat
    let curtainIndex: Int
    let geometry: GeometryProxy

    var body: some View {
        Canvas { context, size in
            let width: CGFloat = size.width
            let height: CGFloat = size.height
            let stripeCount: Int = 8
            let pi: CGFloat = .pi

            for stripe in 0..<stripeCount {
                let stripeFloat: CGFloat = CGFloat(stripe)
                let normalizedX: CGFloat = stripeFloat / CGFloat(stripeCount)
                let xAngle: CGFloat = normalizedX * pi * 2 + phase
                let xOffset: CGFloat = sin(xAngle) * 30
                let baseX: CGFloat = normalizedX * width + xOffset

                // Vertical stripe with wave modulation
                var path = Path()
                path.move(to: CGPoint(x: baseX, y: 0))

                // Create flowing vertical shape
                for y in stride(from: CGFloat(0), through: height, by: 4) {
                    let normalizedY: CGFloat = y / height
                    let flowAngle: CGFloat = normalizedY * pi * 3 + verticalFlow * pi * 2 + stripeFloat * 0.5
                    let flowOffset: CGFloat = sin(flowAngle) * 25
                    let waveAngle: CGFloat = phase + normalizedY * 2
                    let waveX: CGFloat = baseX + flowOffset + sin(waveAngle) * 15
                    path.addLine(to: CGPoint(x: waveX, y: y))
                }

                // Gradient fill
                let colorIndex: Int = stripe % colors.count
                let color: Color = colors[colorIndex]
                let gradientColors: [Color] = [
                    color.opacity(0.0),
                    color.opacity(0.4),
                    color.opacity(0.6),
                    color.opacity(0.4),
                    color.opacity(0.0)
                ]
                let gradient = Gradient(colors: gradientColors)
                let lineWidth: CGFloat = 50 + CGFloat(stripe % 3) * 20

                context.stroke(
                    path,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: baseX, y: 0),
                        endPoint: CGPoint(x: baseX, y: height)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
    }
}

/// Enhanced stars with variable sizes and brighter twinkle
struct EnhancedStarsOverlay: View {
    @State private var twinklePhase: CGFloat = 0
    @State private var sparklePhase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            // Regular stars
            let starCount = 100
            for i in 0..<starCount {
                let seed = Double(i * 12345)
                let x = (sin(seed) * 0.5 + 0.5) * size.width
                let y = (cos(seed * 1.3) * 0.5 + 0.5) * size.height * 0.8
                let baseSize = 1.0 + (sin(seed * 2.7) * 0.5 + 0.5) * 2.0
                let baseBrightness = 0.3 + (cos(seed * 3.1) * 0.5 + 0.5) * 0.7

                // Twinkle with different frequencies per star
                let twinkleFreq = 1.0 + (sin(seed * 0.7) * 0.5 + 0.5) * 2.0
                let twinkle = sin(twinklePhase * twinkleFreq + seed * 0.1) * 0.4 + 0.6
                let starSize = baseSize * twinkle
                let brightness = baseBrightness * twinkle

                let rect = CGRect(x: x - starSize/2, y: y - starSize/2, width: starSize, height: starSize)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(brightness))
                )
            }

            // Bright accent stars with cross sparkle
            let brightStarCount = 8
            for i in 0..<brightStarCount {
                let seed = Double(i * 54321 + 1000)
                let x = (sin(seed) * 0.5 + 0.5) * size.width
                let y = (cos(seed * 1.3) * 0.5 + 0.5) * size.height * 0.6

                let sparkle = sin(sparklePhase * 2 + seed) * 0.5 + 0.5
                let starSize: CGFloat = 3 + sparkle * 2

                // Draw cross sparkle
                let crossLength = starSize * (2 + sparkle * 2)
                var hPath = Path()
                hPath.move(to: CGPoint(x: x - crossLength, y: y))
                hPath.addLine(to: CGPoint(x: x + crossLength, y: y))

                var vPath = Path()
                vPath.move(to: CGPoint(x: x, y: y - crossLength))
                vPath.addLine(to: CGPoint(x: x, y: y + crossLength))

                context.stroke(hPath, with: .color(.white.opacity(0.3 + sparkle * 0.3)), lineWidth: 1)
                context.stroke(vPath, with: .color(.white.opacity(0.3 + sparkle * 0.3)), lineWidth: 1)

                // Center dot
                let rect = CGRect(x: x - starSize/2, y: y - starSize/2, width: starSize, height: starSize)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(0.7 + sparkle * 0.3))
                )
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 4)
                .repeatForever(autoreverses: false)
            ) {
                twinklePhase = .pi * 2
            }
            withAnimation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
            ) {
                sparklePhase = .pi
            }
        }
    }
}

#Preview("Aurora Borealis") {
    AuroraBorealisView()
}

#Preview("Enhanced Aurora") {
    EnhancedAuroraBorealisView()
}

#Preview("Aurora with Shimmer") {
    AuroraShimmerView()
}
