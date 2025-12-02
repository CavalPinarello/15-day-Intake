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

// MARK: - Questionnaire Wave Background (Circadian animated waves)

/// Animated wave background for questionnaire - uses same circadian system as dashboard
struct QuestionnaireWaveBackground: View {
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0

    var body: some View {
        let palette = CircadianPalette.current

        GeometryReader { geometry in
            ZStack {
                // Base gradient with circadian colors
                LinearGradient(
                    colors: palette.background,
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Wave layer 1 - back, slow (MORE VISIBLE)
                FlowingWave(
                    phase: phase1,
                    amplitude: 70,
                    frequency: 0.6,
                    verticalOffset: 0.65
                )
                .fill(
                    LinearGradient(
                        colors: [
                            palette.wave.opacity(0.30),
                            palette.wave.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Wave layer 2 - front, faster (MORE VISIBLE)
                FlowingWave(
                    phase: phase2,
                    amplitude: 50,
                    frequency: 0.8,
                    verticalOffset: 0.4
                )
                .fill(
                    LinearGradient(
                        colors: [
                            palette.accent.opacity(0.22),
                            palette.accent.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                phase1 = .pi * 2
            }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                phase2 = .pi * 2
            }
        }
    }
}

// MARK: - Circadian Palette (Sleep-optimized color system)

/// Centralized circadian color palette optimized for sleep health
/// EVENING/NIGHT: Only warm colors (amber, orange, red, brown) - NO blue/teal/green
/// MORNING/DAY: Can use energizing blues, teals, greens
struct CircadianPalette {
    let background: [Color]
    let wave: Color
    let accent: Color
    let isDark: Bool
    let textPrimary: Color
    let textSecondary: Color

    /// Get the current circadian palette based on time of day
    static var current: CircadianPalette {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 180

        // Seasonal sunrise/sunset calculation
        let seasonalOffset = sin(Double(dayOfYear - 80) / 365.0 * .pi * 2)
        let sunriseHour = 6.5 - seasonalOffset * 1.0
        let sunsetHour = 18.5 + seasonalOffset * 2.0

        let currentHour = Double(hour) + Double(minute) / 60.0

        // Time periods
        let dawnStart = sunriseHour - 0.5
        let dawnEnd = sunriseHour + 1.5
        let duskStart = sunsetHour - 1.5

        // ========================================
        // EVENING/NIGHT MODE (after dusk start)
        // NO BLUE, NO TEAL, NO GREEN - only warm colors
        // ========================================
        if currentHour >= duskStart || currentHour < dawnStart {
            // Deep warm amber/brown background - zero blue
            return CircadianPalette(
                background: [
                    Color(red: 0.14, green: 0.08, blue: 0.06),  // Deep warm brown
                    Color(red: 0.16, green: 0.09, blue: 0.07),
                    Color(red: 0.18, green: 0.10, blue: 0.08)
                ],
                wave: Color(red: 0.85, green: 0.45, blue: 0.20),      // Warm amber
                accent: Color(red: 0.95, green: 0.55, blue: 0.25),    // Bright amber/orange
                isDark: true,
                textPrimary: Color(red: 1.0, green: 0.92, blue: 0.85),   // Warm white
                textSecondary: Color(red: 0.85, green: 0.70, blue: 0.55) // Warm tan
            )
        }
        // ========================================
        // DAWN - Warm coral/peach transition
        // ========================================
        else if currentHour >= dawnStart && currentHour < dawnEnd {
            return CircadianPalette(
                background: [
                    Color(red: 0.99, green: 0.94, blue: 0.90),  // Warm cream
                    Color(red: 0.98, green: 0.91, blue: 0.86),
                    Color(red: 0.97, green: 0.88, blue: 0.82)
                ],
                wave: Color(red: 1.0, green: 0.60, blue: 0.40),       // Coral
                accent: Color(red: 1.0, green: 0.75, blue: 0.45),     // Golden peach
                isDark: false,
                textPrimary: Color(red: 0.25, green: 0.15, blue: 0.10),
                textSecondary: Color(red: 0.50, green: 0.35, blue: 0.25)
            )
        }
        // ========================================
        // MORNING - Bright, energizing (blues/teals OK)
        // ========================================
        else if currentHour >= dawnEnd && currentHour < 12 {
            return CircadianPalette(
                background: [
                    Color(red: 0.92, green: 0.97, blue: 0.98),
                    Color(red: 0.88, green: 0.95, blue: 0.97),
                    Color(red: 0.84, green: 0.93, blue: 0.96)
                ],
                wave: Color(red: 0.31, green: 0.80, blue: 0.77),      // Teal
                accent: Color(red: 0.27, green: 0.72, blue: 0.82),    // Cyan
                isDark: false,
                textPrimary: Color(red: 0.10, green: 0.15, blue: 0.20),
                textSecondary: Color(red: 0.35, green: 0.45, blue: 0.50)
            )
        }
        // ========================================
        // AFTERNOON - Soft blue (still OK for alertness)
        // ========================================
        else {
            return CircadianPalette(
                background: [
                    Color(red: 0.94, green: 0.96, blue: 0.99),
                    Color(red: 0.90, green: 0.94, blue: 0.98),
                    Color(red: 0.86, green: 0.92, blue: 0.97)
                ],
                wave: Color(red: 0.35, green: 0.70, blue: 0.85),
                accent: Color(red: 0.45, green: 0.75, blue: 0.90),
                isDark: false,
                textPrimary: Color(red: 0.10, green: 0.15, blue: 0.20),
                textSecondary: Color(red: 0.40, green: 0.45, blue: 0.50)
            )
        }
    }
}

// MARK: - Dashboard Wave Background (Circadian-aware animated waves)

/// Animated wave background for dashboard - like Headspace meditation app
/// Uses shared CircadianPalette that adjusts for time of day and season
struct DashboardWaveBackground: View {
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0
    @State private var phase3: CGFloat = 0

    var body: some View {
        let palette = CircadianPalette.current

        GeometryReader { geometry in
            ZStack {
                // Base gradient with circadian colors
                LinearGradient(
                    colors: palette.background,
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Wave layer 1 - back, slow, large amplitude (MORE VISIBLE)
                FlowingWave(
                    phase: phase1,
                    amplitude: 80,
                    frequency: 0.5,
                    verticalOffset: 0.7
                )
                .fill(
                    LinearGradient(
                        colors: [
                            palette.wave.opacity(0.35),
                            palette.wave.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Wave layer 2 - middle, medium speed (MORE VISIBLE)
                FlowingWave(
                    phase: phase2,
                    amplitude: 60,
                    frequency: 0.7,
                    verticalOffset: 0.5
                )
                .fill(
                    LinearGradient(
                        colors: [
                            palette.wave.opacity(0.28),
                            palette.wave.opacity(0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Wave layer 3 - front, faster, accent color (MORE VISIBLE)
                FlowingWave(
                    phase: phase3,
                    amplitude: 45,
                    frequency: 0.9,
                    verticalOffset: 0.3
                )
                .fill(
                    LinearGradient(
                        colors: [
                            palette.accent.opacity(0.25),
                            palette.accent.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Stagger the wave animations for organic feel
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            phase1 = .pi * 2
        }
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            phase2 = .pi * 2
        }
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
            phase3 = .pi * 2
        }
    }
}

/// Flowing wave shape - smooth, organic movement
struct FlowingWave: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat
    var verticalOffset: CGFloat // 0-1, where on screen the wave centers

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let baseY = height * verticalOffset

        // Start at bottom-left
        path.move(to: CGPoint(x: 0, y: height))

        // Move to wave start
        let startY = baseY + sin(phase) * amplitude
        path.addLine(to: CGPoint(x: 0, y: startY))

        // Draw smooth wave using quadratic curves for organic feel
        let segments = 8
        let segmentWidth = width / CGFloat(segments)

        for i in 0..<segments {
            let x1 = segmentWidth * CGFloat(i)
            let x2 = segmentWidth * CGFloat(i + 1)
            let midX = (x1 + x2) / 2

            let progress1 = x1 / width
            let progressMid = midX / width
            let progress2 = x2 / width

            let y1 = baseY + sin(progress1 * frequency * .pi * 2 + phase) * amplitude
            let yMid = baseY + sin(progressMid * frequency * .pi * 2 + phase) * amplitude
            let y2 = baseY + sin(progress2 * frequency * .pi * 2 + phase) * amplitude

            // Use quadratic curve for smoother wave
            path.addQuadCurve(
                to: CGPoint(x: x2, y: y2),
                control: CGPoint(x: midX, y: yMid)
            )
        }

        // Close path
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Glassy Card Background

/// A translucent background for cards - uses circadian palette for proper contrast
struct GlassyCardBackground: View {
    var opacity: Double = 0.5
    var tint: Color? = nil
    var blur: CGFloat = 0  // Kept for API compatibility

    var body: some View {
        let palette = CircadianPalette.current

        ZStack {
            // Base translucent layer - adapts to circadian mode
            if palette.isDark {
                // Night mode: warm translucent brown (no blue!)
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.12, blue: 0.10).opacity(opacity),
                        Color(red: 0.15, green: 0.10, blue: 0.08).opacity(opacity * 0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Day mode: translucent white/cream
                LinearGradient(
                    colors: [
                        Color.white.opacity(opacity * 0.9),
                        Color.white.opacity(opacity * 0.75)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Optional color tint
            if let tint = tint {
                tint.opacity(palette.isDark ? 0.08 : 0.05)
            }

            // Subtle top highlight for glassy effect
            LinearGradient(
                colors: [
                    (palette.isDark ? palette.accent : Color.white).opacity(palette.isDark ? 0.08 : 0.25),
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
