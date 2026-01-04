//
//  SleepFactRewardCard.swift
//  Zoe Sleep for Longevity System
//
//  Inline celebration card showing sleep facts between questionnaire questions
//  CIRCADIAN-AWARE: Uses warm amber/orange colors at night (no blue light)
//

import SwiftUI

// MARK: - Sleep Fact Reward Card

struct SleepFactRewardCard: View {
    let fact: SleepFact
    let onDismiss: () -> Void

    @State private var isAppearing: Bool = false
    @State private var isPulsing: Bool = false
    @State private var autoDismissTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Circadian Colors (Theme-based)

    private var theme: ColorTheme { themeManager.currentTheme }
    private var palette: CircadianPalette { themeManager.circadianPalette }

    /// Celebration accent color (circadian-safe)
    private var celebrationColor: Color {
        theme.accent
    }

    /// Category badge text color - MUST have strong contrast against glassy card background
    /// Uses darker, more saturated colors while maintaining circadian design
    private var categoryBadgeColor: Color {
        if palette.isDark {
            // Night/Evening: Bright amber/gold for visibility on dark cards
            return Color(red: 0.96, green: 0.62, blue: 0.04)  // #F59E0A - bright amber
        } else {
            // Day: Dark teal for strong contrast on light glassy cards
            // WCAG AA compliant: ~7:1 contrast ratio on light backgrounds
            return Color(red: 0.06, green: 0.42, blue: 0.40)  // #0F6B66 - dark teal
        }
    }

    /// Secondary accent for subtle elements
    private var secondaryAccent: Color {
        theme.accent.opacity(0.8)
    }

    /// Title text color
    private var titleColor: Color {
        theme.primaryText
    }

    /// Body text color
    private var bodyColor: Color {
        theme.secondaryText
    }

    /// Citation/stat text color
    private var mutedColor: Color {
        theme.secondaryText.opacity(0.7)
    }

    /// Card background
    private var cardBackground: some View {
        GlassyCardBackground(opacity: 0.5, tint: celebrationColor)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Main card content
            VStack(alignment: .leading, spacing: 16) {
                // Header with icon and category
                HStack(spacing: 10) {
                    // Pulsing sparkle icon
                    ZStack {
                        Circle()
                            .fill(celebrationColor.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .scaleEffect(isPulsing ? 1.15 : 1.0)

                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(celebrationColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        // Category badge - uses high-contrast color for readability
                        Text(fact.category.displayName.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(categoryBadgeColor)

                        // Title
                        Text(fact.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(titleColor)
                    }

                    Spacer()

                    // Dismiss X button
                    Button(action: dismissCard) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(mutedColor)
                    }
                }

                // Body text
                Text(fact.body)
                    .font(.body)
                    .foregroundColor(bodyColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)

                // Statistic callout (if available)
                if let statistic = fact.statistic {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(categoryBadgeColor)

                        Text(statistic)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(categoryBadgeColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(celebrationColor.opacity(0.12))
                    .cornerRadius(8)
                }

                // Citation (if available)
                if let citation = fact.citation {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed.fill")
                            .font(.caption2)
                        Text(citation)
                            .font(.caption)
                    }
                    .foregroundColor(mutedColor)
                }

                // Tap to continue hint
                HStack {
                    Spacer()
                    Text("Tap anywhere to continue")
                        .font(.caption)
                        .foregroundColor(mutedColor)
                    Image(systemName: "hand.tap.fill")
                        .font(.caption)
                        .foregroundColor(mutedColor)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                celebrationColor.opacity(0.4),
                                celebrationColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: celebrationColor.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
            // Entrance animation
            .scaleEffect(isAppearing ? 1.0 : 0.85)
            .opacity(isAppearing ? 1.0 : 0)
            .onTapGesture {
                dismissCard()
            }

            Spacer()
        }
        .background(Color.black.opacity(isAppearing ? 0.3 : 0))
        .onAppear {
            startAppearAnimation()
            startPulseAnimation()
            startAutoDismissTimer()
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }

    // MARK: - Animations

    private func startAppearAnimation() {
        if reduceMotion {
            isAppearing = true
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isAppearing = true
            }
        }
    }

    private func startPulseAnimation() {
        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }

    private func startAutoDismissTimer() {
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(RewardMomentConfig.autoDismissSeconds * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    dismissCard()
                }
            }
        }
    }

    private func dismissCard() {
        autoDismissTask?.cancel()

        if reduceMotion {
            onDismiss()
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                isAppearing = false
            }
            // Delay actual dismiss to allow animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onDismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview("Sleep Quality Fact") {
    SleepFactRewardCard(
        fact: SleepFact(
            id: "preview_1",
            pillar: .sleepQuality,
            title: "Quality Over Quantity",
            body: "Research shows sleep efficiency matters more than total hours. Someone sleeping 6 hours deeply often feels better than 8 hours of fragmented sleep.",
            statistic: "Sleep quality accounts for 40% of how refreshed you feel",
            citation: "Walker, 2017 - Why We Sleep",
            category: .scienceSpotlight
        ),
        onDismiss: {}
    )
}

#Preview("Caffeine Fact") {
    SleepFactRewardCard(
        fact: SleepFact(
            id: "preview_2",
            pillar: .nutritional,
            title: "Caffeine Half-Life",
            body: "Caffeine has a 5-6 hour half-life. That 3 PM coffee still has half its caffeine in your system at 9 PM.",
            statistic: "Even 6 hours before bed, caffeine reduces sleep by 1 hour",
            category: .scienceSpotlight
        ),
        onDismiss: {}
    )
}

#Preview("Simple Fact - No Stat") {
    SleepFactRewardCard(
        fact: SleepFact(
            id: "preview_3",
            pillar: .mentalHealth,
            title: "REM Sleep & Emotional Processing",
            body: "During REM sleep, your brain processes emotional memories, essentially providing overnight therapy. Dreams help regulate your mood.",
            category: .scienceSpotlight
        ),
        onDismiss: {}
    )
}
