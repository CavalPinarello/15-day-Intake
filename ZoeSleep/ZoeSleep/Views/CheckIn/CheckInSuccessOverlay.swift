//
//  CheckInSuccessOverlay.swift
//  ZoeSleep
//
//  Success animation overlay for completed check-ins.
//  Shows animated checkmark with confetti particles.
//

import SwiftUI

// MARK: - Check-In Success Overlay

/// Full-screen success overlay with animated checkmark and confetti
struct CheckInSuccessOverlay: View {
    let onDismiss: () -> Void

    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0
    @State private var confettiOpacity: Double = 0
    @State private var confettiOffset: CGFloat = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0

    private let confettiColors: [Color] = [
        Color(red: 1.0, green: 0.6, blue: 0.7),  // Pink
        Color(red: 1.0, green: 0.7, blue: 0.4),  // Orange
        Color(red: 1.0, green: 0.9, blue: 0.4),  // Yellow
        Color(red: 0.6, green: 0.9, blue: 0.6),  // Green
        Color(red: 0.6, green: 0.8, blue: 1.0),  // Blue (soft, circadian-safe)
        Color(red: 0.8, green: 0.6, blue: 0.9),  // Purple
    ]

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 24) {
                // Animated checkmark with confetti
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(ringScale)
                        .opacity(checkmarkOpacity)

                    // Confetti particles
                    ForEach(0..<16, id: \.self) { i in
                        confettiParticle(index: i)
                    }

                    // Success circle
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)

                    // Checkmark icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80, weight: .medium))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [Color(red: 0.3, green: 0.9, blue: 0.5), Color(red: 0.2, green: 0.8, blue: 0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }

                // Success text
                VStack(spacing: 8) {
                    Text("Check-In Complete!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Thanks for tracking how you feel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            animateSuccess()
        }
    }

    // MARK: - Confetti Particle

    private func confettiParticle(index: Int) -> some View {
        let angle = Double(index) * .pi / 8
        let distance: CGFloat = 60 + confettiOffset

        return Circle()
            .fill(confettiColors[index % confettiColors.count])
            .frame(width: 10, height: 10)
            .offset(
                x: cos(angle) * distance,
                y: sin(angle) * distance
            )
            .opacity(confettiOpacity)
            .rotationEffect(.degrees(Double(index) * 22.5))
    }

    // MARK: - Animation

    private func animateSuccess() {
        // Checkmark scale and opacity
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            checkmarkScale = 1.0
            checkmarkOpacity = 1.0
            ringScale = 1.2
        }

        // Confetti burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.8)) {
                confettiOpacity = 1.0
                confettiOffset = 80
            }
        }

        // Fade out confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.5)) {
                confettiOpacity = 0
            }
        }

        // Text fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CheckInSuccessOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.25, blue: 0.15), Color(red: 0.45, green: 0.3, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            CheckInSuccessOverlay {
                print("Dismissed")
            }
        }
    }
}
#endif
