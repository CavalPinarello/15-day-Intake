//
//  SplashScreenView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Fast, elegant splash screen with circadian-aware colors
//

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowOpacity: Double = 0

    var onComplete: (() -> Void)?
    var duration: Double = 0.6  // Fast splash

    private var palette: CircadianPalette { CircadianPalette.current }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: palette.background,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // Logo with glow effect
                ZStack {
                    // Glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [palette.accent.opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .opacity(glowOpacity)
                        .scaleEffect(logoScale * 1.2)

                    // ECG wave icon
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [palette.accent, palette.wave],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }

                // App name
                VStack(spacing: 4) {
                    Text("Zoe Sleep")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(palette.textPrimary)

                    Text("Sleep Better, Live Longer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(palette.accent)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Quick, elegant animation
        withAnimation(.easeOut(duration: 0.25)) {
            logoOpacity = 1.0
            logoScale = 1.0
            glowOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
            textOpacity = 1.0
        }

        // Complete after short duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onComplete?()
        }
    }
}

#Preview {
    SplashScreenView()
}
