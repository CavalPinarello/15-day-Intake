//
//  CircadianWaveBackground.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Animated flowing wave background inspired by EEG and circadian rhythms
//  Features glassy, shaded waves that flow continuously
//

import SwiftUI

// MARK: - Glassy Wave Shape (Filled with gradient)

struct GlassyWaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat
    var fillDown: Bool = true // Whether to fill downward or upward

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2

        // Start at bottom-left or top-left depending on fill direction
        if fillDown {
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: 0, y: midY + sin(phase) * amplitude))
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: midY + sin(phase) * amplitude))
        }

        // Draw the wave curve
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let normalizedX = relativeX * frequency * .pi * 2 + phase
            let y = midY + sin(normalizedX) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Close the path
        if fillDown {
            path.addLine(to: CGPoint(x: width, y: height))
            path.addLine(to: CGPoint(x: 0, y: height))
        } else {
            path.addLine(to: CGPoint(x: width, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - Glassy Wave Layer with Gradient Fill

struct GlassyWaveLayer: View {
    let index: Int
    let colorScheme: ColorScheme
    @State private var phase: CGFloat = 0

    // Wave configurations for each layer
    private var config: (amplitude: CGFloat, frequency: CGFloat, speed: Double, yOffset: CGFloat, opacity: Double, blur: CGFloat) {
        switch index {
        case 0: // Back layer - largest, slowest, most diffuse
            return (amplitude: 50, frequency: 0.6, speed: 35, yOffset: 0.55, opacity: 0.15, blur: 8)
        case 1: // Mid-back layer
            return (amplitude: 40, frequency: 0.8, speed: 28, yOffset: 0.50, opacity: 0.18, blur: 5)
        case 2: // Middle layer - main visual
            return (amplitude: 35, frequency: 1.0, speed: 22, yOffset: 0.45, opacity: 0.22, blur: 3)
        case 3: // Mid-front layer
            return (amplitude: 28, frequency: 1.2, speed: 18, yOffset: 0.40, opacity: 0.20, blur: 2)
        default: // Front layer - sharpest, fastest
            return (amplitude: 22, frequency: 1.5, speed: 15, yOffset: 0.35, opacity: 0.16, blur: 1)
        }
    }

    private var waveGradient: LinearGradient {
        let baseColor = colorScheme == .dark
            ? Color(red: 0.30, green: 0.85, blue: 0.80) // Bright teal for dark mode
            : Color(red: 0.15, green: 0.60, blue: 0.70) // Deeper teal for light mode

        let highlightColor = colorScheme == .dark
            ? Color(red: 0.40, green: 0.95, blue: 0.90) // Lighter teal highlight
            : Color(red: 0.25, green: 0.75, blue: 0.85)

        return LinearGradient(
            colors: [
                highlightColor.opacity(config.opacity * 1.5),
                baseColor.opacity(config.opacity),
                baseColor.opacity(config.opacity * 0.3)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        GeometryReader { geometry in
            GlassyWaveShape(
                phase: phase + CGFloat(index) * .pi / 4,
                amplitude: config.amplitude,
                frequency: config.frequency,
                fillDown: true
            )
            .fill(waveGradient)
            .blur(radius: config.blur)
            .offset(y: geometry.size.height * config.yOffset)
        }
        .onAppear {
            withAnimation(
                .linear(duration: config.speed)
                .repeatForever(autoreverses: false)
            ) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Glowing Line Wave (for accent lines)

struct GlowingLineWave: View {
    let index: Int
    let colorScheme: ColorScheme
    @State private var phase: CGFloat = 0

    private var config: (amplitude: CGFloat, frequency: CGFloat, speed: Double, yOffset: CGFloat, lineWidth: CGFloat, opacity: Double) {
        switch index {
        case 0:
            return (35, 0.9, 25, 0.42, 3.0, 0.35)
        case 1:
            return (28, 1.1, 20, 0.48, 2.5, 0.30)
        case 2:
            return (22, 1.3, 16, 0.54, 2.0, 0.25)
        default:
            return (18, 1.6, 12, 0.60, 1.5, 0.20)
        }
    }

    private var lineColor: Color {
        colorScheme == .dark
            ? Color(red: 0.45, green: 0.95, blue: 0.90) // Bright cyan-teal
            : Color(red: 0.20, green: 0.70, blue: 0.80)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Glow layer (blurred underneath)
                SineWaveShape(
                    phase: phase + CGFloat(index) * .pi / 3,
                    amplitude: config.amplitude,
                    frequency: config.frequency
                )
                .stroke(
                    lineColor.opacity(config.opacity * 0.5),
                    style: StrokeStyle(lineWidth: config.lineWidth * 3, lineCap: .round)
                )
                .blur(radius: 8)
                .offset(y: geometry.size.height * config.yOffset)

                // Main line
                SineWaveShape(
                    phase: phase + CGFloat(index) * .pi / 3,
                    amplitude: config.amplitude,
                    frequency: config.frequency
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            lineColor.opacity(config.opacity * 0.6),
                            lineColor.opacity(config.opacity),
                            lineColor.opacity(config.opacity * 0.6)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round)
                )
                .offset(y: geometry.size.height * config.yOffset)
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: config.speed)
                .repeatForever(autoreverses: false)
            ) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Simple Sine Wave Shape (for lines)

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

        path.move(to: CGPoint(x: 0, y: midY + sin(phase) * amplitude))

        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let normalizedX = relativeX * frequency * .pi * 2 + phase
            let y = midY + sin(normalizedX) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
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
                    // Glassy filled waves (back to front)
                    ForEach(0..<5, id: \.self) { index in
                        GlassyWaveLayer(index: index, colorScheme: colorScheme)
                            .opacity(intensity)
                    }

                    // Glowing accent lines on top
                    ForEach(0..<4, id: \.self) { index in
                        GlowingLineWave(index: index, colorScheme: colorScheme)
                            .opacity(intensity)
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
            // Dark mode: Deep navy gradient with subtle color variation
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.12), // Very deep navy top
                    Color(red: 0.06, green: 0.09, blue: 0.16), // #0F172A
                    Color(red: 0.05, green: 0.10, blue: 0.18)  // Hint of teal-navy bottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Light mode: Soft gradient
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color(red: 0.92, green: 0.95, blue: 0.98),
                    Color(red: 0.88, green: 0.94, blue: 0.98)
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
    private let highlightColor = Color(red: 0.45, green: 0.95, blue: 0.90) // Bright cyan
    private let backgroundColor = Color(red: 0.04, green: 0.06, blue: 0.12) // Deep navy

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep navy gradient background
                LinearGradient(
                    colors: [
                        backgroundColor,
                        Color(red: 0.06, green: 0.09, blue: 0.16),
                        Color(red: 0.05, green: 0.12, blue: 0.20)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Glassy wave fills
                ForEach(0..<4, id: \.self) { index in
                    SplashGlassyWave(
                        index: index,
                        size: geometry.size,
                        phase: animationPhase
                    )
                }

                // Glowing accent lines
                ForEach(0..<3, id: \.self) { index in
                    SplashGlowLine(
                        index: index,
                        size: geometry.size,
                        phase: animationPhase
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

struct SplashGlassyWave: View {
    let index: Int
    let size: CGSize
    let phase: CGFloat

    private var config: (amplitude: CGFloat, frequency: CGFloat, phaseOffset: CGFloat, yOffset: CGFloat, opacity: Double, blur: CGFloat) {
        switch index {
        case 0:
            return (55, 0.7, 0, 0.60, 0.20, 10)
        case 1:
            return (45, 0.9, .pi / 4, 0.52, 0.25, 6)
        case 2:
            return (35, 1.1, .pi / 2, 0.45, 0.22, 4)
        default:
            return (28, 1.4, .pi * 3/4, 0.38, 0.18, 2)
        }
    }

    private var gradient: LinearGradient {
        let baseColor = Color(red: 0.30, green: 0.85, blue: 0.80)
        let highlightColor = Color(red: 0.45, green: 0.95, blue: 0.90)

        return LinearGradient(
            colors: [
                highlightColor.opacity(config.opacity * 1.3),
                baseColor.opacity(config.opacity),
                baseColor.opacity(config.opacity * 0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        GlassyWaveShape(
            phase: phase + config.phaseOffset,
            amplitude: config.amplitude,
            frequency: config.frequency,
            fillDown: true
        )
        .fill(gradient)
        .blur(radius: config.blur)
        .offset(y: size.height * config.yOffset)
    }
}

struct SplashGlowLine: View {
    let index: Int
    let size: CGSize
    let phase: CGFloat

    private var config: (amplitude: CGFloat, frequency: CGFloat, phaseOffset: CGFloat, yOffset: CGFloat, lineWidth: CGFloat, opacity: Double) {
        switch index {
        case 0:
            return (40, 0.85, .pi / 6, 0.48, 3.5, 0.45)
        case 1:
            return (32, 1.05, .pi / 3, 0.52, 2.5, 0.35)
        default:
            return (25, 1.25, .pi / 2, 0.56, 2.0, 0.28)
        }
    }

    private let lineColor = Color(red: 0.50, green: 1.0, blue: 0.95) // Bright cyan

    var body: some View {
        ZStack {
            // Outer glow
            SineWaveShape(
                phase: phase + config.phaseOffset,
                amplitude: config.amplitude,
                frequency: config.frequency
            )
            .stroke(lineColor.opacity(config.opacity * 0.3), style: StrokeStyle(lineWidth: config.lineWidth * 4, lineCap: .round))
            .blur(radius: 12)
            .offset(y: size.height * config.yOffset)

            // Inner glow
            SineWaveShape(
                phase: phase + config.phaseOffset,
                amplitude: config.amplitude,
                frequency: config.frequency
            )
            .stroke(lineColor.opacity(config.opacity * 0.5), style: StrokeStyle(lineWidth: config.lineWidth * 2, lineCap: .round))
            .blur(radius: 4)
            .offset(y: size.height * config.yOffset)

            // Core line
            SineWaveShape(
                phase: phase + config.phaseOffset,
                amplitude: config.amplitude,
                frequency: config.frequency
            )
            .stroke(
                LinearGradient(
                    colors: [
                        lineColor.opacity(config.opacity * 0.5),
                        lineColor.opacity(config.opacity),
                        lineColor.opacity(config.opacity * 0.5)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round)
            )
            .offset(y: size.height * config.yOffset)
        }
    }
}

// MARK: - Questionnaire Wave Background (Simple gradient for performance)

/// A simple gradient background for questionnaire views - no animations to prevent scrolling issues
struct QuestionnaireWaveBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        // Simple gradient with subtle teal tint - no animations
        backgroundGradient
            .ignoresSafeArea()
    }

    private var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.12),
                    Color(red: 0.05, green: 0.09, blue: 0.16),
                    Color(red: 0.06, green: 0.12, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 0.99),
                    Color(red: 0.90, green: 0.95, blue: 0.98),
                    Color(red: 0.85, green: 0.93, blue: 0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Dashboard Wave Background (Subtle animated waves)

/// Animated wave background for dashboard - subtle and performant
struct DashboardWaveBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                backgroundGradient

                // Subtle animated waves (only 2 layers for performance)
                DashboardWaveLayer(index: 0, phase: phase, colorScheme: colorScheme)
                DashboardWaveLayer(index: 1, phase: phase, colorScheme: colorScheme)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }

    private var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.12),
                    Color(red: 0.05, green: 0.09, blue: 0.16),
                    Color(red: 0.06, green: 0.12, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 0.99),
                    Color(red: 0.90, green: 0.95, blue: 0.98),
                    Color(red: 0.85, green: 0.93, blue: 0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct DashboardWaveLayer: View {
    let index: Int
    let phase: CGFloat
    let colorScheme: ColorScheme

    private var config: (amplitude: CGFloat, frequency: CGFloat, offset: CGFloat, yPos: CGFloat, opacity: Double) {
        switch index {
        case 0:
            return (40, 0.6, 0, 0.7, 0.12)
        default:
            return (30, 0.8, .pi / 2, 0.55, 0.08)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let waveColor = colorScheme == .dark
                ? Color(red: 0.30, green: 0.85, blue: 0.80)
                : Color(red: 0.20, green: 0.65, blue: 0.75)

            SimpleDashboardWave(
                phase: phase + config.offset,
                amplitude: config.amplitude,
                frequency: config.frequency
            )
            .fill(
                LinearGradient(
                    colors: [
                        waveColor.opacity(config.opacity),
                        waveColor.opacity(config.opacity * 0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(y: geometry.size.height * config.yPos)
        }
    }
}

/// Simple wave shape for dashboard - no blur for performance
struct SimpleDashboardWave: Shape {
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

        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: midY + sin(phase) * amplitude))

        // Use larger step for performance
        for x in stride(from: 0, through: width, by: 6) {
            let relativeX = x / width
            let normalizedX = relativeX * frequency * .pi * 2 + phase
            let y = midY + sin(normalizedX) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Glassy Card Background

/// A translucent background for cards that lets the wave background show through
struct GlassyCardBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var opacity: Double = 0.45  // More translucent by default
    var tint: Color? = nil
    var blur: CGFloat = 0  // Kept for API compatibility

    var body: some View {
        ZStack {
            // Base translucent layer
            if colorScheme == .dark {
                // Dark mode: very translucent dark with subtle gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.12, blue: 0.18).opacity(opacity),
                        Color(red: 0.08, green: 0.10, blue: 0.15).opacity(opacity * 0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Light mode: very translucent white
                LinearGradient(
                    colors: [
                        Color.white.opacity(opacity * 0.85),
                        Color.white.opacity(opacity * 0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Optional color tint
            if let tint = tint {
                tint.opacity(0.05)
            }

            // Subtle top highlight for glassy effect
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.3),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
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
    /// Adds an animated circadian wave background with glassy effect
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
