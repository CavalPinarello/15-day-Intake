//
//  SplashScreenView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Brief splash screen with circadian-aware colors - minimal duration
//  to avoid feeling like a double splash with system launch screen
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0

    // Callback when splash is complete
    var onComplete: (() -> Void)?

    // Shorter splash duration (system already shows launch screen)
    var duration: Double = 1.2

    // Use circadian colors
    private var palette: CircadianPalette { CircadianPalette.current }

    var body: some View {
        ZStack {
            // Circadian-aware background gradient
            LinearGradient(
                colors: palette.background,
                startPoint: .top,
                endPoint: .bottom
            )

            // Center logo composition
            VStack(spacing: 20) {
                // Logo
                ZStack {
                    // Subtle glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    palette.accent.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)

                    // Wave icon
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 50, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [palette.accent, palette.wave],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .opacity(logoOpacity)

                // App name
                VStack(spacing: 6) {
                    Text("Zoe Sleep")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(palette.textPrimary)

                    Text("Sleep Better, Live Longer")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(palette.accent.opacity(0.9))
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
        // Quick fade in
        withAnimation(.easeOut(duration: 0.4)) {
            logoOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
            textOpacity = 1.0
        }

        // Complete callback after short duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onComplete?()
        }
    }
}

// MARK: - Previews

#Preview("Splash Screen") {
    SplashScreenView()
}
