//
//  ZoeOrbView.swift
//  ZoeSleep
//
//  An amorphous, friendly glowing orb that represents Zoe
//  Animates based on voice activity - pulses when listening/speaking
//

import SwiftUI

/// The state of the Zoe orb animation
enum ZoeOrbState {
    case idle           // Gentle breathing animation
    case listening      // Pulsing, responsive to audio input
    case speaking       // Smooth, rhythmic animation while TTS plays
    case thinking       // Swirling, processing animation
}

/// An amorphous, glowing orb representing Zoe - the voice assistant
struct ZoeOrbView: View {
    let state: ZoeOrbState
    let audioLevel: Float  // 0.0 to 1.0

    @ObservedObject var themeManager = ThemeManager.shared

    // Animation states
    @State private var phase: CGFloat = 0
    @State private var breatheScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var blobOffsets: [CGSize] = Array(repeating: .zero, count: 5)

    private var theme: ColorTheme { themeManager.currentTheme }

    // Orb colors based on circadian phase
    private var primaryColor: Color {
        theme.accent
    }

    private var secondaryColor: Color {
        theme.accent.opacity(0.6)
    }

    private var glowColor: Color {
        theme.accent.opacity(0.3)
    }

    var body: some View {
        ZStack {
            // Outer glow layers
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                glowColor.opacity(0.4 - Double(i) * 0.1),
                                glowColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 150 + CGFloat(i) * 30
                        )
                    )
                    .frame(width: 300 + CGFloat(i) * 60, height: 300 + CGFloat(i) * 60)
                    .scaleEffect(breatheScale + CGFloat(audioLevel) * 0.15)
                    .blur(radius: 20 + CGFloat(i) * 10)
            }

            // Main amorphous blob
            ZStack {
                // Multiple overlapping blobs create amorphous shape
                ForEach(0..<5, id: \.self) { i in
                    BlobShape(
                        sides: 6 + i,
                        phase: phase + Double(i) * 0.5,
                        amplitude: 0.15 + Double(audioLevel) * 0.1
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                primaryColor.opacity(0.8 - Double(i) * 0.1),
                                secondaryColor.opacity(0.6 - Double(i) * 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140 - CGFloat(i) * 10, height: 140 - CGFloat(i) * 10)
                    .offset(blobOffsets[i])
                    .blur(radius: CGFloat(i) * 2)
                    .rotationEffect(.degrees(rotationAngle + Double(i) * 20))
                }

                // Inner core - brighter center
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                primaryColor.opacity(0.8),
                                primaryColor.opacity(0.4)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 8)
                    .scaleEffect(0.9 + CGFloat(audioLevel) * 0.2)
            }
            .scaleEffect(breatheScale + CGFloat(audioLevel) * 0.1)
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: state) { _, newState in
            updateAnimationsForState(newState)
        }
    }

    private func startAnimations() {
        // Continuous phase animation for blob morphing
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            phase = .pi * 2
        }

        // Breathing animation
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            breatheScale = 1.08
        }

        // Slow rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Blob offset animations for organic movement
        for i in 0..<5 {
            let duration = 2.0 + Double(i) * 0.5
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                blobOffsets[i] = CGSize(
                    width: CGFloat.random(in: -8...8),
                    height: CGFloat.random(in: -8...8)
                )
            }
        }
    }

    private func updateAnimationsForState(_ state: ZoeOrbState) {
        switch state {
        case .idle:
            // Gentle, slow animations
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breatheScale = 1.05
            }
        case .listening:
            // More responsive, faster breathing
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                breatheScale = 1.1
            }
        case .speaking:
            // Rhythmic, smooth animation
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                breatheScale = 1.12
            }
        case .thinking:
            // Swirling, faster rotation
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Blob Shape

/// A morphing blob shape using sine waves
struct BlobShape: Shape {
    let sides: Int
    var phase: Double
    var amplitude: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        let points = 100

        for i in 0...points {
            let angle = (Double(i) / Double(points)) * 2 * .pi

            // Create organic wobble using multiple sine waves
            let wobble = sin(angle * Double(sides) + phase) * amplitude +
                        sin(angle * Double(sides + 2) + phase * 1.5) * amplitude * 0.5 +
                        sin(angle * Double(sides - 1) + phase * 0.7) * amplitude * 0.3

            let r = radius * (1 + wobble)
            let x = center.x + CGFloat(r * cos(angle))
            let y = center.y + CGFloat(r * sin(angle))

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("Zoe Orb - Idle") {
    ZStack {
        Color.black.ignoresSafeArea()
        ZoeOrbView(state: .idle, audioLevel: 0.0)
    }
}

#Preview("Zoe Orb - Listening") {
    ZStack {
        Color.black.ignoresSafeArea()
        ZoeOrbView(state: .listening, audioLevel: 0.5)
    }
}

#Preview("Zoe Orb - Speaking") {
    ZStack {
        Color.black.ignoresSafeArea()
        ZoeOrbView(state: .speaking, audioLevel: 0.7)
    }
}
