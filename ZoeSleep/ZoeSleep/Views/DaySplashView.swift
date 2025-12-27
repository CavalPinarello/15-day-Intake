//
//  DaySplashView.swift
//  Zoe Sleep for Longevity System
//
//  Single-screen compact splash for all 14 days of the journey
//  Hero-framed to make the user the protagonist of their sleep discovery
//
//  DESIGN: Fits on one iPhone screen without scrolling (~400pt content)
//  CIRCADIAN-AWARE: Uses warm amber colors at night, no blue light
//

import SwiftUI

// MARK: - Day Splash View

/// Compact single-screen splash shown at the start of each day's assessment
/// No scrolling required - all content visible at once
struct DaySplashView: View {
    let dayInfo: DaySplashInfo
    let triggeredGateways: [GatewayType]
    let onContinue: () -> Void

    @State private var isAnimating = false
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Circadian Colors

    private var palette: CircadianPalette { CircadianPalette.current }

    private var primaryTextColor: Color {
        palette.isDark
            ? Color(red: 0.996, green: 0.953, blue: 0.780)  // Bright warm cream
            : Color.primary
    }

    private var secondaryTextColor: Color {
        palette.isDark
            ? Color(red: 0.988, green: 0.827, blue: 0.302).opacity(0.8)  // Golden yellow
            : Color.secondary
    }

    private var accentColor: Color {
        palette.isDark
            ? Color(red: 0.95, green: 0.6, blue: 0.2)  // Warm amber
            : Color.accentColor
    }

    private var backgroundColor: Color {
        palette.isDark
            ? Color(red: 0.08, green: 0.05, blue: 0.02)  // Very dark warm brown
            : Color(.systemBackground)
    }

    private var cardBackgroundColor: Color {
        palette.isDark
            ? Color(red: 0.15, green: 0.10, blue: 0.05)  // Dark card
            : Color(.secondarySystemBackground)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 16) {
                // Animated Icon
                iconSection

                // Title & Progress
                titleSection

                // Mission Card
                missionCard

                // Stats Row
                statsRow

                // Discoveries Card
                discoveriesCard

                // Gateway Trigger (for expansion days)
                if dayInfo.isExpansionDay && !triggeredGateways.isEmpty {
                    gatewayIndicator
                }

                Spacer(minLength: 8)

                // CTA Button
                continueButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        ZStack {
            // Outer pulse
            Circle()
                .fill(accentColor.opacity(0.12))
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1.15 : 1.0)

            // Inner glow
            Circle()
                .fill(accentColor.opacity(0.25))
                .frame(width: 60, height: 60)

            // Icon
            Image(systemName: dayInfo.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(accentColor)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(dayInfo.progressText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(secondaryTextColor)

            Text(dayInfo.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(primaryTextColor)

            if dayInfo.isExpansionDay {
                Text("Personalized Deep Dive")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Mission Card

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("YOUR MISSION", systemImage: "target")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)

            Text(dayInfo.missionStatement)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(primaryTextColor)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(12)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 16) {
            StatBadgeCompact(
                icon: "list.bullet",
                value: dayInfo.questionCountText,
                color: accentColor
            )

            StatBadgeCompact(
                icon: "clock",
                value: dayInfo.timeEstimate,
                color: accentColor
            )

            if let instruments = dayInfo.clinicalInstruments, !instruments.isEmpty {
                StatBadgeCompact(
                    icon: "checkmark.seal.fill",
                    value: instruments.count == 1 ? instruments[0] : "\(instruments.count) validated",
                    color: .green
                )
            }
        }
    }

    // MARK: - Discoveries Card

    private var discoveriesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("WHAT YOU'LL DISCOVER", systemImage: "lightbulb.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color.yellow.opacity(palette.isDark ? 1.0 : 0.8))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(dayInfo.discoveries.prefix(3), id: \.self) { discovery in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(accentColor)
                        Text(discovery)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(primaryTextColor)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(12)
    }

    // MARK: - Gateway Indicator

    private var gatewayIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.fill.checkmark")
                .font(.system(size: 11))
            Text("Personalized for you based on your \(triggeredGateways.first?.shortTrigger ?? "responses")")
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundColor(secondaryTextColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(cardBackgroundColor.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Text("Begin Today's Discovery")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(palette.isDark ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(accentColor)
            .cornerRadius(14)
        }
    }
}

// MARK: - Compact Stat Badge

/// Ultra-compact stat badge for the stats row
struct StatBadgeCompact: View {
    let icon: String
    let value: String
    let color: Color

    private var palette: CircadianPalette { CircadianPalette.current }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(palette.isDark ? Color.white.opacity(0.9) : Color.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            palette.isDark
                ? Color.white.opacity(0.08)
                : Color(.tertiarySystemBackground)
        )
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("Day 1 - Core") {
    DaySplashView(
        dayInfo: DaySplashLibrary.day1,
        triggeredGateways: [],
        onContinue: {}
    )
    .environmentObject(ThemeManager.shared)
}

#Preview("Day 8 - Expansion") {
    DaySplashView(
        dayInfo: DaySplashLibrary.day8,
        triggeredGateways: [.insomnia],
        onContinue: {}
    )
    .environmentObject(ThemeManager.shared)
}

#Preview("Day 14 - Final") {
    DaySplashView(
        dayInfo: DaySplashLibrary.day14,
        triggeredGateways: [.osa, .pain],
        onContinue: {}
    )
    .environmentObject(ThemeManager.shared)
}
