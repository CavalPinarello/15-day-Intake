//
//  SplashScreenView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Elegant splash screen with animated aurora borealis and Zoé logo
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var loadingDots: Int = 0
    @State private var auroraOpacity: Double = 0

    var onComplete: (() -> Void)?
    var duration: Double = 1.2  // Slightly longer to appreciate the aurora
    var isLoading: Bool = false
    var loadingMessage: String = "Signing in"

    private var palette: CircadianPalette { CircadianPalette.current }

    // Timer for loading dots animation
    private let loadingTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    // Brand teal color
    private let brandTeal = Color(red: 0.22, green: 0.65, blue: 0.69)

    var body: some View {
        ZStack {
            // Animated aurora borealis background
            AuroraBorealisView()
                .opacity(auroraOpacity)

            // Subtle vignette overlay
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.3)],
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Logo with glow effect
                ZStack {
                    // Glow behind logo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [brandTeal.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)
                        .opacity(glowOpacity)
                        .scaleEffect(logoScale * 1.2)
                        .blur(radius: 20)

                    // The Zoé spiral logo
                    ZoeLogoAccurate(size: 100, tealColor: brandTeal)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }

                // App name and tagline
                VStack(spacing: 6) {
                    Text("Zoé Sleep")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Sleep Better, Live Longer")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(brandTeal)
                }
                .opacity(textOpacity)

                Spacer()

                // Loading indicator (shown when checking session)
                if isLoading {
                    HStack(spacing: 4) {
                        Text(loadingMessage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        // Animated dots
                        Text(String(repeating: ".", count: loadingDots))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 24, alignment: .leading)
                    }
                    .opacity(textOpacity)
                    .padding(.bottom, 60)
                } else {
                    Spacer()
                        .frame(height: 80)
                }
            }

            // Floating accessibility button (bottom-right)
            // Light style for dark aurora background
            EnhancedReadabilityButton(lightStyle: true, edgePadding: 24)
        }
        .onAppear {
            startAnimation()
        }
        .onReceive(loadingTimer) { _ in
            if isLoading {
                loadingDots = (loadingDots % 3) + 1
            }
        }
    }

    private func startAnimation() {
        // Fade in aurora first
        withAnimation(.easeOut(duration: 0.4)) {
            auroraOpacity = 1.0
        }

        // Then animate logo
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            logoOpacity = 1.0
            logoScale = 1.0
            glowOpacity = 1.0
        }

        // Then text
        withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
            textOpacity = 1.0
        }

        // Complete after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onComplete?()
        }
    }
}

/// Simplified splash for quick loads (no aurora animation)
struct SimpleSplashView: View {
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.05)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZoeLogoAccurate(size: 80, tealColor: Color(red: 0.22, green: 0.65, blue: 0.69))

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
    SplashScreenView(isLoading: true)
}

#Preview("Simple Splash") {
    SimpleSplashView()
}
