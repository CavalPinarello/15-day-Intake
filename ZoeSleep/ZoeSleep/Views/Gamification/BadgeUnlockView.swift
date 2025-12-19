//
//  BadgeUnlockView.swift
//  Zoe Sleep for Longevity System
//
//  Celebration overlay when user unlocks a badge
//

import SwiftUI

struct BadgeUnlockView: View {
    let badge: BadgeData
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var iconScale: CGFloat = 0.3
    @State private var showingDetails: Bool = false

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    // Circadian-aware colors
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var primaryTextColor: Color {
        if isEvening {
            return Color(red: 0.996, green: 0.953, blue: 0.780)  // Bright cream
        } else {
            return Color.primary
        }
    }

    private var accentColor: Color {
        switch badge.category {
        case "journey":
            return .blue
        case "streak":
            return .orange
        case "quality":
            return .green
        case "clinical":
            return .purple
        default:
            return .yellow
        }
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 24) {
                // Badge icon with glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)

                    // Inner circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)

                    // Badge icon
                    Text(badge.icon)
                        .font(.system(size: 60))
                        .scaleEffect(iconScale)
                }

                // Title
                VStack(spacing: 8) {
                    Text("BADGE UNLOCKED!")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                        .tracking(2)

                    Text(badge.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(primaryTextColor)
                        .multilineTextAlignment(.center)
                }

                // Description
                if showingDetails {
                    VStack(spacing: 16) {
                        Text(badge.description)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(primaryTextColor.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        // Category tag
                        HStack {
                            Text(badge.category.capitalized)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(accentColor.opacity(0.8))
                                .clipShape(Capsule())

                            Text("• \(rarityText)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(primaryTextColor.opacity(0.6))
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Continue button
                Button(action: dismiss) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(accentColor)
                        )
                }
                .padding(.top, 8)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            animateIn()
        }
    }

    private var rarityText: String {
        // Infer rarity from badge category or name
        if badge.name.contains("Master") || badge.name.contains("Champion") {
            return "Legendary"
        } else if badge.name.contains("Full") || badge.name.contains("Perfect") {
            return "Epic"
        } else if badge.name.contains("Week") || badge.category == "streak" {
            return "Rare"
        } else {
            return "Common"
        }
    }

    private func animateIn() {
        // First: scale up the container
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }

        // Second: bounce the icon
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
            iconScale = 1.0
        }

        // Third: show details
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            showingDetails = true
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0.9
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Multi-Badge Unlock View (for when multiple badges are earned)

struct MultiBadgeUnlockView: View {
    let badges: [BadgeData]
    let onDismiss: () -> Void

    @State private var currentBadgeIndex: Int = 0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            if currentBadgeIndex < badges.count {
                BadgeUnlockView(
                    badge: badges[currentBadgeIndex],
                    onDismiss: {
                        if currentBadgeIndex < badges.count - 1 {
                            withAnimation {
                                currentBadgeIndex += 1
                            }
                        } else {
                            onDismiss()
                        }
                    }
                )
                .id(currentBadgeIndex)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - Compact Badge Display (for dashboard/profile)

struct CompactBadgeView: View {
    let badge: BadgeData

    var body: some View {
        VStack(spacing: 4) {
            Text(badge.icon)
                .font(.system(size: 32))

            Text(badge.name)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(width: 70, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
        .opacity(badge.isEarned ? 1.0 : 0.4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(badge.isEarned ? categoryColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }

    private var categoryColor: Color {
        switch badge.category {
        case "journey": return .blue
        case "streak": return .orange
        case "quality": return .green
        case "clinical": return .purple
        default: return .yellow
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BadgeUnlockView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            BadgeUnlockView(
                badge: BadgeData(
                    id: "week_warrior",
                    name: "Week Warrior",
                    description: "Maintain a 7-day streak",
                    category: "streak",
                    icon: "💪",
                    earnedAt: Date(),
                    isEarned: true,
                    progressCurrent: nil,
                    progressTarget: nil
                ),
                onDismiss: {}
            )
        }
        .environmentObject(ThemeManager.shared)
    }
}
#endif
