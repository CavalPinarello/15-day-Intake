//
//  ConfettiView.swift
//  Zoe Sleep for Longevity System
//
//  Celebratory confetti animation for day completion
//  CIRCADIAN-AWARE: Uses warm colors at night, vibrant during day
//

import SwiftUI

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var rotation: Double
    var rotationSpeed: Double
    var scale: CGFloat
    var color: Color
    var shape: ConfettiShape
    var opacity: Double = 1.0

    enum ConfettiShape: CaseIterable {
        case circle
        case rectangle
        case triangle
        case star
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    let particleCount: Int
    let duration: Double
    let onComplete: (() -> Void)?

    // Circadian-aware colors
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var confettiColors: [Color] {
        if isEvening {
            // Warm amber/gold/orange palette for night
            return [
                Color(red: 0.95, green: 0.6, blue: 0.2),    // Warm amber
                Color(red: 0.85, green: 0.5, blue: 0.15),   // Deep amber
                Color(red: 0.9, green: 0.45, blue: 0.1),    // Orange
                Color(red: 0.988, green: 0.827, blue: 0.302), // Gold
                Color(red: 0.996, green: 0.953, blue: 0.780), // Cream
                Color(red: 0.72, green: 0.45, blue: 0.2),   // Copper
            ]
        } else {
            // Vibrant daytime palette
            return [
                .green,
                .blue,
                .purple,
                .orange,
                .pink,
                .yellow,
                .cyan,
                .mint,
            ]
        }
    }

    init(particleCount: Int = 100, duration: Double = 3.0, onComplete: (() -> Void)? = nil) {
        self.particleCount = particleCount
        self.duration = duration
        self.onComplete = onComplete
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ParticleView(particle: particle)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                startAnimation()
            }
        }
        .allowsHitTesting(false)
    }

    private func createParticles(in size: CGSize) {
        let centerX = size.width / 2
        let startY = size.height * 0.3  // Start from upper third

        particles = (0..<particleCount).map { _ in
            // Random spread angle (burst effect)
            let angle = Double.random(in: -Double.pi...0)
            let speed = CGFloat.random(in: 300...600)

            return ConfettiParticle(
                position: CGPoint(x: centerX + CGFloat.random(in: -20...20), y: startY),
                velocity: CGPoint(
                    x: cos(angle) * speed * CGFloat.random(in: 0.5...1.5),
                    y: sin(angle) * speed
                ),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -360...360),
                scale: CGFloat.random(in: 0.5...1.2),
                color: confettiColors.randomElement() ?? .yellow,
                shape: ConfettiParticle.ConfettiShape.allCases.randomElement() ?? .circle
            )
        }
    }

    private func startAnimation() {
        isAnimating = true

        // Animation timer
        let startTime = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 1/60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)

            if elapsed >= duration {
                timer.invalidate()
                withAnimation(.easeOut(duration: 0.3)) {
                    particles = []
                }
                onComplete?()
                return
            }

            // Update particles
            let gravity: CGFloat = 400
            let dt: CGFloat = 1/60.0

            for i in particles.indices {
                // Apply gravity
                particles[i].velocity.y += gravity * dt

                // Apply air resistance
                particles[i].velocity.x *= 0.99
                particles[i].velocity.y *= 0.99

                // Update position
                particles[i].position.x += particles[i].velocity.x * dt
                particles[i].position.y += particles[i].velocity.y * dt

                // Update rotation
                particles[i].rotation += particles[i].rotationSpeed * dt

                // Fade out in last second
                if elapsed > duration - 1.0 {
                    particles[i].opacity = max(0, 1 - (elapsed - (duration - 1.0)))
                }
            }
        }

        RunLoop.main.add(timer, forMode: .common)
    }
}

// MARK: - Particle Shape View

struct ParticleView: View {
    let particle: ConfettiParticle

    var body: some View {
        particleShape
            .frame(width: 12 * particle.scale, height: 12 * particle.scale)
            .rotationEffect(.degrees(particle.rotation))
            .position(particle.position)
            .opacity(particle.opacity)
    }

    @ViewBuilder
    private var particleShape: some View {
        switch particle.shape {
        case .circle:
            Circle()
                .fill(particle.color)
        case .rectangle:
            RoundedRectangle(cornerRadius: 2)
                .fill(particle.color)
        case .triangle:
            Triangle()
                .fill(particle.color)
        case .star:
            Star(corners: 5, smoothness: 0.45)
                .fill(particle.color)
        }
    }
}

// MARK: - Custom Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Star: Shape {
    let corners: Int
    let smoothness: CGFloat

    func path(in rect: CGRect) -> Path {
        guard corners >= 2 else { return Path() }

        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        var currentAngle = -CGFloat.pi / 2
        let angleAdjustment = .pi * 2 / CGFloat(corners * 2)
        let innerRadius = rect.width / 2 * smoothness
        let outerRadius = rect.width / 2

        var path = Path()

        for corner in 0..<corners * 2 {
            let radius = corner.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + cos(currentAngle) * radius
            let y = center.y + sin(currentAngle) * radius

            if corner == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }

            currentAngle += angleAdjustment
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Confetti Overlay Modifier

struct ConfettiModifier: ViewModifier {
    @Binding var isActive: Bool
    let particleCount: Int
    let duration: Double

    func body(content: Content) -> some View {
        ZStack {
            content

            if isActive {
                ConfettiView(
                    particleCount: particleCount,
                    duration: duration,
                    onComplete: {
                        isActive = false
                    }
                )
                .ignoresSafeArea()
            }
        }
    }
}

extension View {
    func confetti(isActive: Binding<Bool>, particleCount: Int = 100, duration: Double = 3.0) -> some View {
        modifier(ConfettiModifier(isActive: isActive, particleCount: particleCount, duration: duration))
    }
}

// MARK: - Celebration Trigger Animation

struct CelebrationTrigger: View {
    @Binding var showConfetti: Bool
    @Binding var showXPGain: Bool
    let xpAmount: Int

    var body: some View {
        ZStack {
            if showConfetti {
                ConfettiView(
                    particleCount: 80,
                    duration: 2.5,
                    onComplete: {
                        showConfetti = false
                    }
                )
            }

            if showXPGain {
                XPGainPopup(amount: xpAmount)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            showXPGain = false
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - XP Gain Popup

struct XPGainPopup: View {
    let amount: Int

    @State private var offset: CGFloat = 50
    @State private var opacity: Double = 0

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)

                Text("+\(amount) XP")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.green)
                    .shadow(color: .green.opacity(0.5), radius: 10, x: 0, y: 5)
            )
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    offset = 0
                    opacity = 1
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        offset = -30
                        opacity = 0
                    }
                }
            }

            Spacer()
                .frame(height: 150)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ConfettiView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Text("Day 5 Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            ConfettiView(particleCount: 100, duration: 3.0)
        }
    }
}

struct XPGainPopup_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            XPGainPopup(amount: 150)
        }
    }
}
#endif
