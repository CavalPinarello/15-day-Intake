//
//  FirstTimeGuideView.swift
//  Zoe Sleep for Longevity System
//
//  Full-screen modal that explains a feature on first use
//  CIRCADIAN-AWARE: Uses warm colors at night
//

import SwiftUI

// MARK: - First Time Guide View

struct FirstTimeGuideView: View {
    let guide: GuideContent
    let onDismiss: () -> Void

    @State private var isAppearing: Bool = false
    @State private var bulletIndex: Int = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Circadian Colors

    private var palette: CircadianPalette { CircadianPalette.current }

    private var primaryTextColor: Color {
        palette.isDark
            ? Color(red: 0.996, green: 0.953, blue: 0.780)  // Bright warm cream
            : Color.primary
    }

    private var secondaryTextColor: Color {
        palette.isDark
            ? Color(red: 0.988, green: 0.827, blue: 0.302).opacity(0.85)  // Golden yellow
            : Color.secondary
    }

    private var accentColor: Color {
        palette.isDark
            ? Color(red: 0.95, green: 0.6, blue: 0.2)  // Warm amber
            : Color.accentColor
    }

    private var backgroundColor: Color {
        palette.isDark
            ? Color(red: 0.06, green: 0.04, blue: 0.02)  // Very dark warm
            : Color(.systemBackground)
    }

    private var cardBackgroundColor: Color {
        palette.isDark
            ? Color(red: 0.12, green: 0.08, blue: 0.04)  // Dark card
            : Color(.secondarySystemBackground)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            backgroundColor.ignoresSafeArea()

            // Gradient overlay
            LinearGradient(
                colors: [
                    accentColor.opacity(0.15),
                    backgroundColor.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header icon
                        iconSection
                            .padding(.top, 40)

                        // Title
                        Text(guide.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                            .multilineTextAlignment(.center)

                        // Headline
                        Text(guide.headline)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)

                        // Bullet points
                        VStack(spacing: 16) {
                            ForEach(Array(guide.bulletPoints.enumerated()), id: \.offset) { index, bullet in
                                bulletRow(bullet: bullet, index: index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .background(cardBackgroundColor)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)

                        // Footer
                        if let footer = guide.footer {
                            Text(footer)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(accentColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 8)
                        }

                        Spacer(minLength: 100)
                    }
                }

                // Bottom button
                dismissButton
            }
        }
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            startAppearAnimation()
            startBulletAnimation()
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 120, height: 120)

            // Inner glow
            Circle()
                .fill(accentColor.opacity(0.25))
                .frame(width: 90, height: 90)

            // Icon
            Image(systemName: guide.icon)
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(accentColor)
        }
    }

    // MARK: - Bullet Row

    private func bulletRow(bullet: GuideContent.GuideBullet, index: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(accentColor.opacity(bulletIndex > index ? 0.25 : 0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: bullet.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(bulletIndex > index ? accentColor : secondaryTextColor.opacity(0.6))
            }

            // Text
            Text(bullet.text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(bulletIndex > index ? primaryTextColor : secondaryTextColor.opacity(0.7))
                .lineSpacing(2)

            Spacer()
        }
        .opacity(bulletIndex > index ? 1 : 0.5)
        .animation(.easeOut(duration: 0.3), value: bulletIndex)
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [backgroundColor.opacity(0), backgroundColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .allowsHitTesting(false)

            // Button area
            VStack(spacing: 12) {
                Button(action: onDismiss) {
                    HStack(spacing: 8) {
                        Text("Got it")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                    }
                    .foregroundColor(palette.isDark ? Color.black : Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)

                // Skip hint
                Text("You won't see this again")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor.opacity(0.6))
            }
            .padding(.bottom, 32)
            .background(backgroundColor)
        }
    }

    // MARK: - Animations

    private func startAppearAnimation() {
        if reduceMotion {
            isAppearing = true
            bulletIndex = guide.bulletPoints.count
        } else {
            withAnimation(.easeOut(duration: 0.4)) {
                isAppearing = true
            }
        }
    }

    private func startBulletAnimation() {
        guard !reduceMotion else { return }

        // Stagger bullet point reveals
        for i in 0...guide.bulletPoints.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.15) {
                bulletIndex = i + 1
            }
        }
    }
}

// MARK: - View Modifier for Guides

/// Modifier to show first-time guides as a full-screen cover
struct FirstTimeGuideModifier: ViewModifier {
    @ObservedObject var guideManager = FirstTimeGuideManager.shared

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $guideManager.isShowingGuide) {
                if let guide = guideManager.currentGuide {
                    FirstTimeGuideView(guide: guide) {
                        guideManager.dismissGuide()
                    }
                }
            }
    }
}

extension View {
    /// Attach first-time guide support to a view
    func withFirstTimeGuides() -> some View {
        modifier(FirstTimeGuideModifier())
    }
}

// MARK: - Preview

#Preview("Sleep Log Guide") {
    FirstTimeGuideView(
        guide: GuideLibrary.sleepLog,
        onDismiss: {}
    )
}

#Preview("Assessment Guide") {
    FirstTimeGuideView(
        guide: GuideLibrary.assessment,
        onDismiss: {}
    )
}

#Preview("HealthKit Guide") {
    FirstTimeGuideView(
        guide: GuideLibrary.healthKitSync,
        onDismiss: {}
    )
}

#Preview("Expansion Pack Guide") {
    FirstTimeGuideView(
        guide: GuideLibrary.expansionPack,
        onDismiss: {}
    )
}
