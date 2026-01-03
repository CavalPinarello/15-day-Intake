//
//  JourneyIntroScreens.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Journey introduction screens - warm, human-friendly messaging
//  Explains what we do and why in a conversational tone
//

import SwiftUI

// MARK: - Screen 1: Welcome & Promise

struct JourneyIntroScreen1: View {
    let screenHeight: CGFloat

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    var body: some View {
        VStack(spacing: isCompact ? 24 : 32) {
            Spacer()

            // Icon
            JourneyIntroMoonIcon()
                .frame(width: isCompact ? 110 : 130, height: isCompact ? 110 : 130)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title - warm and inviting
            Text("Finally Understand\nYour Sleep")
                .font(.system(size: isCompact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(textOpacity)

            // Description - conversational
            Text("Over the next 10 days, we'll get to know\nhow you sleep — what works, what doesn't,\nand what makes you uniquely you.")
                .font(.system(size: isCompact ? 17 : 19, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 28)
                .opacity(textOpacity)

            Spacer()
            Spacer()
        }
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            textOpacity = 1.0
        }
    }
}

// MARK: - Screen 2: How We Do It

struct JourneyIntroScreen2: View {
    let screenHeight: CGFloat

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    var body: some View {
        VStack(spacing: isCompact ? 24 : 32) {
            Spacer()

            // Icon
            JourneyIntroClipboardIcon()
                .frame(width: isCompact ? 110 : 130, height: isCompact ? 110 : 130)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title
            Text("The Best Tools,\nTailored to You")
                .font(.system(size: isCompact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(textOpacity)

            // Description - friendly explanation
            VStack(spacing: isCompact ? 12 : 16) {
                Text("We use the same trusted questionnaires\nthat sleep clinics rely on worldwide.")
                    .font(.system(size: isCompact ? 17 : 19, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Plus your wearable data — reinterpreted\nwith your unique sleep profile in mind.")
                    .font(.system(size: isCompact ? 16 : 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 28)
            .opacity(textOpacity)

            Spacer()
            Spacer()
        }
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            textOpacity = 1.0
        }
    }
}

// MARK: - Screen 3: Expert Review

struct JourneyIntroScreen3: View {
    let screenHeight: CGFloat

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    var body: some View {
        VStack(spacing: isCompact ? 24 : 32) {
            Spacer()

            // Icon
            JourneyIntroClinicianIcon()
                .frame(width: isCompact ? 110 : 130, height: isCompact ? 110 : 130)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title
            Text("A Real Expert\nReviews Everything")
                .font(.system(size: isCompact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(textOpacity)

            // Description - reassuring
            VStack(spacing: isCompact ? 12 : 16) {
                Text("After 10 days, a sleep specialist\nlooks at your complete picture.")
                    .font(.system(size: isCompact ? 17 : 19, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("No algorithms making decisions alone.\nA real human creates your personalized\nplan — your sleep fingerprint.")
                    .font(.system(size: isCompact ? 16 : 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)
            .opacity(textOpacity)

            Spacer()
            Spacer()
        }
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            textOpacity = 1.0
        }
    }
}

// MARK: - Screen 4: The Outcome (Final Screen with CTA)

struct JourneyIntroScreen4: View {
    let screenHeight: CGFloat
    let onComplete: () -> Void

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    // Aurora accent colors
    private let auroraAccent = Color(red: 0.1, green: 0.9, blue: 0.8)
    private let auroraSecondary = Color(red: 0.0, green: 0.8, blue: 0.9)

    var body: some View {
        VStack(spacing: isCompact ? 24 : 32) {
            Spacer()

            // Icon - sunrise/energy
            JourneyIntroSunriseIcon()
                .frame(width: isCompact ? 110 : 130, height: isCompact ? 110 : 130)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title
            Text("Wake Up to\nYour Best Life")
                .font(.system(size: isCompact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(textOpacity)

            // Description - inspiring
            VStack(spacing: isCompact ? 12 : 16) {
                Text("More energy. Sharper focus.\nBetter mood. Longer healthspan.")
                    .font(.system(size: isCompact ? 18 : 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Great sleep changes everything.\nLet's find yours together.")
                    .font(.system(size: isCompact ? 16 : 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 28)
            .opacity(textOpacity)

            Spacer()

            // CTA Button
            Button(action: onComplete) {
                Text("Let's Get Started")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompact ? 16 : 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [auroraAccent, auroraSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: auroraAccent.opacity(0.5), radius: 15, y: 5)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, isCompact ? 20 : 30)
            .opacity(buttonOpacity)
        }
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            textOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            buttonOpacity = 1.0
        }
    }
}

// MARK: - Legacy Screen Aliases (for backward compatibility)

struct JourneyIntroScreen5: View {
    let screenHeight: CGFloat

    var body: some View {
        JourneyIntroScreen3(screenHeight: screenHeight)
    }
}

struct JourneyIntroScreen6: View {
    let screenHeight: CGFloat
    let onComplete: () -> Void

    var body: some View {
        JourneyIntroScreen4(screenHeight: screenHeight, onComplete: onComplete)
    }
}

// MARK: - Sunrise Icon (for screen 4)

struct JourneyIntroSunriseIcon: View {
    @State private var rayRotation: Double = 0
    @State private var glowScale: CGFloat = 1.0

    private let sunColor = Color(red: 1.0, green: 0.85, blue: 0.4)
    private let warmOrange = Color(red: 1.0, green: 0.6, blue: 0.3)

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = size / 2

            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                sunColor.opacity(0.4),
                                warmOrange.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.15,
                            endRadius: size * 0.5
                        )
                    )
                    .scaleEffect(glowScale)
                    .blur(radius: 8)

                // Rays
                ForEach(0..<8) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(sunColor.opacity(0.6))
                        .frame(width: 3, height: size * 0.18)
                        .offset(y: -size * 0.32)
                        .rotationEffect(.degrees(Double(i) * 45 + rayRotation))
                }

                // Sun circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [sunColor, warmOrange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.4, height: size * 0.4)
                    .shadow(color: sunColor.opacity(0.5), radius: 15)

                // Horizon line
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: size * 0.7, height: 4)
                    .offset(y: size * 0.2)
            }
            .frame(width: size, height: size)
            .position(x: center, y: center)
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rayRotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowScale = 1.15
            }
        }
    }
}

// MARK: - Reusable Paragraph Component

struct JourneyIntroParagraph: View {
    let text: String
    let isCompact: Bool

    init(_ text: String, isCompact: Bool) {
        self.text = text
        self.isCompact = isCompact
    }

    var body: some View {
        Text(text)
            .font(.system(size: isCompact ? 16 : 18, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
    }
}

// MARK: - Previews

#Preview("Screen 1 - Welcome") {
    ZStack {
        AuroraBorealisView()
        JourneyIntroScreen1(screenHeight: 844)
    }
}

#Preview("Screen 2 - How We Do It") {
    ZStack {
        AuroraBorealisView()
        JourneyIntroScreen2(screenHeight: 844)
    }
}

#Preview("Screen 3 - Expert Review") {
    ZStack {
        AuroraBorealisView()
        JourneyIntroScreen3(screenHeight: 844)
    }
}

#Preview("Screen 4 - Outcome") {
    ZStack {
        AuroraBorealisView()
        JourneyIntroScreen4(screenHeight: 844, onComplete: {})
    }
}
