//
//  JourneyIntroScreens.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Journey introduction screens - big text, concise messaging
//  Explains the 14-day assessment → expert review → maintenance transition
//

import SwiftUI

// MARK: - Screen 1: 360° Sleep Understanding

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

            // Title - BIG
            Text("14 Days to\n360° Sleep Understanding")
                .font(.system(size: isCompact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(textOpacity)

            // Description - SHORT
            Text("A complete picture of your sleep.\n10 minutes daily. Worth every second.")
                .font(.system(size: isCompact ? 18 : 20, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 32)
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

// MARK: - Screen 2: Validated Clinical Tools

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

            // Title - BIG
            Text("Best-in-Class\nClinical Questionnaires")
                .font(.system(size: isCompact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(textOpacity)

            // Description - SHORT
            VStack(spacing: isCompact ? 8 : 12) {
                Text("Industry-standardized, validated tools.")
                    .font(.system(size: isCompact ? 18 : 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Text("Stanford Sleep Diary, ISI, PHQ-9,\nSTOP-BANG, and more — personalized to you.")
                    .font(.system(size: isCompact ? 17 : 19, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
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

            // Title - BIG
            Text("Expert Medical Review\nHuman-in-the-Loop")
                .font(.system(size: isCompact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(textOpacity)

            // Description - SHORT
            Text("After 14 days, a sleep specialist reviews\nyour data and prescribes personalized\nsleep interventions.")
                .font(.system(size: isCompact ? 18 : 20, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
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

// MARK: - Screen 4: Your Future (Final Screen with CTA)

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

            // Title - BIG
            Text("Optimal Sleep for Life")
                .font(.system(size: isCompact ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)

            // Description - SHORT & POWERFUL
            VStack(spacing: isCompact ? 8 : 12) {
                Text("Maximum focus. Peak energy.")
                    .font(.system(size: isCompact ? 18 : 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Text("Your app becomes a lifelong companion\nfor healthy sleep and extended healthspan.")
                    .font(.system(size: isCompact ? 17 : 19, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .padding(.horizontal, 28)
            .opacity(textOpacity)

            Spacer()

            // CTA Button
            Button(action: onComplete) {
                Text("Begin My Journey")
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
        // Redirect to screen 3
        JourneyIntroScreen3(screenHeight: screenHeight)
    }
}

struct JourneyIntroScreen6: View {
    let screenHeight: CGFloat
    let onComplete: () -> Void

    var body: some View {
        // Redirect to screen 4
        JourneyIntroScreen4(screenHeight: screenHeight, onComplete: onComplete)
    }
}

// MARK: - Sunrise Icon (new for screen 4)

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

// MARK: - Reusable Paragraph Component (kept for any legacy usage)

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

#Preview("Screen 1") {
    ZStack {
        AuroraBorealisView()
        JourneyIntroScreen1(screenHeight: 844)
    }
}

#Preview("Screen 2") {
    ZStack {
        AuroraBorealisView()
        JourneyIntroScreen2(screenHeight: 844)
    }
}

#Preview("Screen 3") {
    ZStack {
        AuroraBorealisView()
        JourneyIntroScreen3(screenHeight: 844)
    }
}

#Preview("Screen 4") {
    ZStack {
        AuroraBorealisView()
        JourneyIntroScreen4(screenHeight: 844, onComplete: {})
    }
}
