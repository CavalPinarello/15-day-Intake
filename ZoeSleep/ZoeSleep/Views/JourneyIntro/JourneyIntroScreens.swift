//
//  JourneyIntroScreens.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Individual screen components for the Journey Introduction sequence
//  Each screen explains a different aspect of the 15-day sleep assessment
//

import SwiftUI

// MARK: - Screen 1: Welcome to Your Journey

struct JourneyIntroScreen1: View {
    let screenHeight: CGFloat

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    var body: some View {
        VStack(spacing: isCompact ? 20 : 28) {
            Spacer(minLength: isCompact ? 40 : 60)

            // Animated icon
            JourneyIntroMoonIcon()
                .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title
            Text("Your 15-Day Sleep Journey")
                .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)

            // Description
            VStack(spacing: isCompact ? 12 : 16) {
                JourneyIntroParagraph(
                    "Over the next two weeks, we'll build a complete picture of your sleep.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "Plan for 10-15 minutes daily — this investment helps us calibrate your subjective experience and see the complete picture.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "It's time well spent for truly personalized care.",
                    isCompact: isCompact
                )
            }
            .padding(.horizontal, isCompact ? 24 : 32)
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

// MARK: - Screen 2: Daily Sleep Log

struct JourneyIntroScreen2: View {
    let screenHeight: CGFloat

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    var body: some View {
        VStack(spacing: isCompact ? 20 : 28) {
            Spacer(minLength: isCompact ? 40 : 60)

            // Animated icon
            JourneyIntroClipboardIcon()
                .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title
            Text("Daily Sleep Log")
                .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)

            // Description
            VStack(spacing: isCompact ? 12 : 16) {
                JourneyIntroParagraph(
                    "Every morning, 10 questions from the Stanford Consensus Sleep Diary — repeated for all 15 days.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "These capture how you felt — your subjective sleep experience.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "Consistency helps us identify true patterns and calibrate your perception.",
                    isCompact: isCompact
                )
            }
            .padding(.horizontal, isCompact ? 24 : 32)
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

// MARK: - Screen 3: Core Assessment

struct JourneyIntroScreen3: View {
    let screenHeight: CGFloat

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    var body: some View {
        VStack(spacing: isCompact ? 20 : 28) {
            Spacer(minLength: isCompact ? 40 : 60)

            // Animated icon
            JourneyIntroBrainIcon()
                .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title
            Text("Understanding Your Sleep")
                .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)

            // Description
            VStack(spacing: isCompact ? 12 : 16) {
                JourneyIntroParagraph(
                    "Across all 15 days, we explore multiple facets of your sleep health.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "From environment to lifestyle to mental health — we examine the complete picture.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "Questions are balanced daily so you're never overwhelmed.",
                    isCompact: isCompact
                )
            }
            .padding(.horizontal, isCompact ? 24 : 32)
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

// MARK: - Screen 4: Gateway System

struct JourneyIntroScreen4: View {
    let screenHeight: CGFloat

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    var body: some View {
        VStack(spacing: isCompact ? 20 : 28) {
            Spacer(minLength: isCompact ? 40 : 60)

            // Animated icon
            JourneyIntroPathIcon()
                .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title
            Text("Personalized Deep Dives")
                .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)

            // Description
            VStack(spacing: isCompact ? 12 : 16) {
                JourneyIntroParagraph(
                    "Your answers may unlock 'gateway' assessments for deeper investigation.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "These include validated clinical tools: ISI, PHQ-9, STOP-BANG, and more.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "Only assessments relevant to YOU — no wasted time.",
                    isCompact: isCompact
                )
            }
            .padding(.horizontal, isCompact ? 24 : 32)
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

// MARK: - Screen 5: Wearable Integration

struct JourneyIntroScreen5: View {
    let screenHeight: CGFloat

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    var body: some View {
        VStack(spacing: isCompact ? 20 : 28) {
            Spacer(minLength: isCompact ? 40 : 60)

            // Animated icon
            JourneyIntroWatchIcon()
                .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title
            Text("Objective Data")
                .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)

            // Description
            VStack(spacing: isCompact ? 12 : 16) {
                JourneyIntroParagraph(
                    "Your wearable captures what actually happened while you slept.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "We correlate your subjective feelings with objective measurements.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "Two weeks reveals true patterns — wearable accuracy improves over time.",
                    isCompact: isCompact
                )
            }
            .padding(.horizontal, isCompact ? 24 : 32)
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

// MARK: - Screen 6: Human Review

struct JourneyIntroScreen6: View {
    let screenHeight: CGFloat
    let onComplete: () -> Void

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    private var isCompact: Bool { screenHeight < 700 }

    // Aurora accent colors
    private let auroraAccent = Color(red: 0.1, green: 0.9, blue: 0.8)
    private let auroraSecondary = Color(red: 0.0, green: 0.8, blue: 0.9)

    var body: some View {
        VStack(spacing: isCompact ? 20 : 28) {
            Spacer(minLength: isCompact ? 40 : 60)

            // Animated icon
            JourneyIntroClinicianIcon()
                .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Title
            Text("Expert Review & Your Plan")
                .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)

            // Description
            VStack(spacing: isCompact ? 12 : 16) {
                JourneyIntroParagraph(
                    "A real clinician reviews your complete profile.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "You'll receive personalized interventions from our evidence-based library.",
                    isCompact: isCompact
                )
                JourneyIntroParagraph(
                    "Human-in-the-loop ensures nothing is missed.",
                    isCompact: isCompact
                )
            }
            .padding(.horizontal, isCompact ? 24 : 32)
            .opacity(textOpacity)

            Spacer()

            // CTA Button
            Button(action: onComplete) {
                Text("Begin My Journey")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompact ? 14 : 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [auroraAccent, auroraSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: auroraAccent.opacity(0.4), radius: 12, y: 4)
            }
            .padding(.horizontal, isCompact ? 24 : 32)
            .padding(.bottom, isCompact ? 16 : 24)
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

// MARK: - Reusable Paragraph Component

struct JourneyIntroParagraph: View {
    let text: String
    let isCompact: Bool

    private var palette: CircadianPalette { CircadianPalette.current }

    init(_ text: String, isCompact: Bool) {
        self.text = text
        self.isCompact = isCompact
    }

    var body: some View {
        Text(text)
            .font(.system(size: isCompact ? 15 : 16, weight: .regular, design: .rounded))
            .foregroundColor(palette.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }
}

// MARK: - Previews

#Preview("Screen 1") {
    ZStack {
        OnboardingCircadianBackground()
        JourneyIntroScreen1(screenHeight: 844)
    }
}

#Preview("Screen 6") {
    ZStack {
        OnboardingCircadianBackground()
        JourneyIntroScreen6(screenHeight: 844, onComplete: {})
    }
}
