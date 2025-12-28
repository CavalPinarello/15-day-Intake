//
//  SplashScreenView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Elegant splash with animated aurora borealis
//  Logo and text animate in gracefully, then fade to main app
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowPulse: CGFloat = 1.0
    @State private var auroraVisible: Bool = false
    @State private var logoOffset: CGFloat = 0
    @State private var taglineOpacity: Double = 1.0

    var onComplete: (() -> Void)?
    var duration: Double = 3.5  // Longer to appreciate the logo
    var isLoading: Bool = false
    var loadingMessage: String = "Signing in"

    // Binding to trigger transition animation (logo moves up)
    @Binding var isTransitioning: Bool

    // Brand colors
    private let logoColor = Color(red: 0.96, green: 0.90, blue: 0.83) // Warm cream
    private let glowColor = Color(red: 0.1, green: 0.85, blue: 0.8)   // Aurora teal

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated aurora borealis background
                AuroraBorealisView()
                    .opacity(auroraVisible ? 1 : 0)

                // Subtle vignette for depth
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.3)],
                    center: .center,
                    startRadius: 100,
                    endRadius: 450
                )
                .ignoresSafeArea()

                // Centered content
                VStack(spacing: 28) {
                    Spacer()

                    // Logo with glowing effect - animates up during transition
                    ZStack {
                        // Pulsing glow behind logo
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        glowColor.opacity(0.3),
                                        glowColor.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 220, height: 220)
                            .scaleEffect(glowPulse)
                            .blur(radius: 20)

                        // Warm glow directly behind logo
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        logoColor.opacity(0.4),
                                        logoColor.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 15)

                        // Glassy circle container
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.04),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 90
                                )
                            )
                            .frame(width: 150, height: 150)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.35),
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )

                        // The Zoé logo
                        ZoeLogoSVG(size: 95, color: logoColor)
                            .shadow(color: logoColor.opacity(0.5), radius: 20, x: 0, y: 0)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .offset(y: logoOffset)

                    // App name and tagline
                    VStack(spacing: 8) {
                        Text("Zoé Sleep")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: glowColor.opacity(0.3), radius: 15, x: 0, y: 0)

                        Text("Sleep Better, Live Longer")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(logoColor.opacity(0.9))
                            .opacity(taglineOpacity)
                    }
                    .opacity(textOpacity)
                    .offset(y: logoOffset)

                    Spacer()

                    // Loading indicator
                    if isLoading {
                        LoadingDotsView(message: loadingMessage)
                            .opacity(textOpacity)
                            .padding(.bottom, 60)
                    } else {
                        Spacer()
                            .frame(height: 60)
                    }
                }

                // Floating accessibility button
                EnhancedReadabilityButton(lightStyle: true, edgePadding: 24)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimation()
        }
        .onChange(of: isTransitioning) { _, transitioning in
            if transitioning {
                // Animate logo moving up to make room for intro content
                withAnimation(.easeInOut(duration: 0.6)) {
                    logoOffset = -80
                    taglineOpacity = 0
                }
            }
        }
    }

    // Default initializer for previews and non-transitioning use
    init(
        onComplete: (() -> Void)? = nil,
        duration: Double = 3.5,
        isLoading: Bool = false,
        loadingMessage: String = "Signing in",
        isTransitioning: Binding<Bool> = .constant(false)
    ) {
        self.onComplete = onComplete
        self.duration = duration
        self.isLoading = isLoading
        self.loadingMessage = loadingMessage
        self._isTransitioning = isTransitioning
    }

    private func startAnimation() {
        // Aurora fades in first
        withAnimation(.easeOut(duration: 0.5)) {
            auroraVisible = true
        }

        // Logo appears with spring
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.2)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        // Text fades in
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            textOpacity = 1.0
        }

        // Gentle pulsing glow
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.3)) {
            glowPulse = 1.1
        }

        // Complete after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onComplete?()
        }
    }
}

// Simple loading dots
struct LoadingDotsView: View {
    let message: String
    @State private var dotCount: Int = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Text(String(repeating: ".", count: dotCount + 1))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20, alignment: .leading)
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }
}

/// Simplified splash for instant loads
struct SimpleSplashView: View {
    private let logoColor = Color(red: 0.96, green: 0.90, blue: 0.83)

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.06)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZoeLogoSVG(size: 80, color: logoColor)

                Text("Zoé Sleep")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview("Splash Screen") {
    SplashScreenView()
}

#Preview("Splash Loading") {
    SplashScreenView(isLoading: true, loadingMessage: "Signing in")
}

#Preview("Simple Splash") {
    SimpleSplashView()
}
