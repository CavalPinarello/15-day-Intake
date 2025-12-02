//
//  CircadianWaveBackground.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Animated flowing wave background inspired by EEG and circadian rhythms
//  Features subtle, gentle sine waves that flow continuously
//

import SwiftUI

// MARK: - Wave Configuration

struct WaveConfig {
    let amplitude: CGFloat      // Height of the wave
    let frequency: CGFloat      // How many waves fit horizontally
    let speed: CGFloat          // Animation speed (lower = slower)
    let opacity: Double         // Wave transparency
    let yOffset: CGFloat        // Vertical position offset (0-1 range)
    let color: Color            // Wave color

    static func defaultWaves(for colorScheme: ColorScheme) -> [WaveConfig] {
        let baseColor = colorScheme == .dark
            ? Color(red: 0.31, green: 0.80, blue: 0.77) // Teal for dark mode
            : Color(red: 0.20, green: 0.55, blue: 0.65) // Deeper teal for light mode

        return [
            // Background layer - slowest, most subtle
            WaveConfig(
                amplitude: 30,
                frequency: 0.8,
                speed: 0.02,
                opacity: 0.08,
                yOffset: 0.3,
                color: baseColor
            ),
            // Mid layer - medium speed
            WaveConfig(
                amplitude: 25,
                frequency: 1.2,
                speed: 0.025,
                opacity: 0.06,
                yOffset: 0.5,
                color: baseColor
            ),
            // Upper layer
            WaveConfig(
                amplitude: 20,
                frequency: 1.5,
                speed: 0.03,
                opacity: 0.05,
                yOffset: 0.35,
                color: baseColor
            ),
            // Lower layer
            WaveConfig(
                amplitude: 22,
                frequency: 1.0,
                speed: 0.022,
                opacity: 0.07,
                yOffset: 0.65,
                color: baseColor
            ),
            // Accent layer - faster, thinner
            WaveConfig(
                amplitude: 15,
                frequency: 1.8,
                speed: 0.035,
                opacity: 0.04,
                yOffset: 0.45,
                color: baseColor
            )
        ]
    }
}

// MARK: - Single Wave Shape

struct SineWaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2

        path.move(to: CGPoint(x: 0, y: midY))

        // Draw sine wave with smooth curves
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let normalizedX = relativeX * frequency * .pi * 2 + phase
            let y = midY + sin(normalizedX) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

// MARK: - Animated Wave Layer

struct AnimatedWaveLayer: View {
    let config: WaveConfig
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            SineWaveShape(
                phase: phase,
                amplitude: config.amplitude,
                frequency: config.frequency
            )
            .stroke(
                config.color.opacity(config.opacity),
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .offset(y: geometry.size.height * config.yOffset)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1 / config.speed)
                .repeatForever(autoreverses: false)
            ) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Main Background View

struct CircadianWaveBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Whether to use reduced motion (no animation)
    private var reduceMotion: Bool {
        themeManager.reduceMotion
    }

    /// Custom gradient for background (optional)
    var customGradient: LinearGradient? = nil

    /// Wave intensity (0-1, affects opacity)
    var intensity: Double = 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient background
                backgroundGradient

                // Animated wave layers (if motion is allowed)
                if !reduceMotion {
                    ForEach(0..<5, id: \.self) { index in
                        let waves = WaveConfig.defaultWaves(for: colorScheme)
                        if index < waves.count {
                            AnimatedWaveLayer(config: waves[index])
                                .opacity(intensity)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundGradient: some View {
        Group {
            if let custom = customGradient {
                custom
            } else {
                defaultGradient
            }
        }
    }

    private var defaultGradient: LinearGradient {
        if colorScheme == .dark {
            // Dark mode: Deep navy gradient
            LinearGradient(
                colors: [
                    Color(red: 0.059, green: 0.090, blue: 0.165), // #0F172A
                    Color(red: 0.078, green: 0.118, blue: 0.200)  // Slightly lighter navy
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Light mode: Soft off-white to light blue
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 0.99),
                    Color(red: 0.93, green: 0.96, blue: 0.99)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Splash Screen Background (More Prominent Waves)

struct SplashWaveBackground: View {
    @State private var animationPhase: CGFloat = 0

    // Colors for the splash screen
    private let waveColor = Color(red: 0.31, green: 0.80, blue: 0.77) // Teal
    private let backgroundColor = Color(red: 0.059, green: 0.090, blue: 0.165) // Deep navy

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep navy background
                backgroundColor

                // Multiple flowing wave layers with higher visibility
                ForEach(0..<4, id: \.self) { index in
                    SplashWaveLayer(
                        index: index,
                        size: geometry.size,
                        animationPhase: animationPhase
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .linear(duration: 20)
                .repeatForever(autoreverses: false)
            ) {
                animationPhase = .pi * 2
            }
        }
    }
}

struct SplashWaveLayer: View {
    let index: Int
    let size: CGSize
    let animationPhase: CGFloat

    private let waveColor = Color(red: 0.31, green: 0.80, blue: 0.77)

    private var config: (amplitude: CGFloat, frequency: CGFloat, phaseOffset: CGFloat, yOffset: CGFloat, opacity: Double) {
        switch index {
        case 0:
            return (40, 1.0, 0, 0.25, 0.15)
        case 1:
            return (35, 1.3, .pi / 3, 0.4, 0.12)
        case 2:
            return (30, 1.6, .pi / 2, 0.55, 0.10)
        default:
            return (25, 1.9, .pi * 2/3, 0.7, 0.08)
        }
    }

    var body: some View {
        SineWaveShape(
            phase: animationPhase + config.phaseOffset,
            amplitude: config.amplitude,
            frequency: config.frequency
        )
        .stroke(
            waveColor.opacity(config.opacity),
            style: StrokeStyle(
                lineWidth: 3,
                lineCap: .round,
                lineJoin: .round
            )
        )
        .offset(y: size.height * config.yOffset)
    }
}

// MARK: - View Modifier for Easy Application

struct CircadianWaveBackgroundModifier: ViewModifier {
    var intensity: Double = 1.0

    func body(content: Content) -> some View {
        ZStack {
            CircadianWaveBackground(intensity: intensity)
            content
        }
    }
}

extension View {
    /// Adds a subtle animated circadian wave background
    func circadianWaveBackground(intensity: Double = 1.0) -> some View {
        modifier(CircadianWaveBackgroundModifier(intensity: intensity))
    }
}

// MARK: - Previews

#Preview("Wave Background - Light") {
    CircadianWaveBackground()
        .environment(\.colorScheme, .light)
}

#Preview("Wave Background - Dark") {
    CircadianWaveBackground()
        .environment(\.colorScheme, .dark)
}

#Preview("Splash Background") {
    SplashWaveBackground()
}

#Preview("Content with Background") {
    VStack {
        Text("Zoe Sleep")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
        Text("Sleep Better, Live Longer")
            .foregroundColor(.white.opacity(0.7))
    }
    .circadianWaveBackground()
    .environment(\.colorScheme, .dark)
}
