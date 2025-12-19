//
//  XPDisplayView.swift
//  Zoe Sleep for Longevity System
//
//  Displays user's XP level and progress
//

import SwiftUI

struct XPDisplayView: View {
    let totalXP: Int
    let currentLevel: Int
    let levelName: String
    let xpToNextLevel: Int
    let progressToNextLevel: Double

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 8) {
            // Level badge
            ZStack {
                Circle()
                    .fill(levelColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text("\(currentLevel)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(levelColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                // Level name
                Text(levelName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                // XP progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background
                        Capsule()
                            .fill(theme.textSecondary.opacity(0.2))
                            .frame(height: 4)

                        // Progress
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [levelColor.opacity(0.8), levelColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progressToNextLevel, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(width: 80)

            // XP count
            Text("\(totalXP) XP")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(theme.textSecondary.opacity(0.08))
        )
    }

    private var levelColor: Color {
        switch currentLevel {
        case 1: return .gray
        case 2: return .green
        case 3: return .blue
        case 4: return .purple
        case 5: return .yellow
        default: return .gray
        }
    }
}

// MARK: - Compact XP Badge (for header)

struct XPBadgeView: View {
    let totalXP: Int
    let currentLevel: Int

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 4) {
            // Level indicator
            ZStack {
                Circle()
                    .fill(levelColor.opacity(0.3))
                    .frame(width: 20, height: 20)

                Text("\(currentLevel)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(levelColor)
            }

            // XP count
            Text("\(formattedXP)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            Text("XP")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(theme.textSecondary.opacity(0.08))
        )
    }

    private var formattedXP: String {
        if totalXP >= 1000 {
            return String(format: "%.1fk", Double(totalXP) / 1000.0)
        }
        return "\(totalXP)"
    }

    private var levelColor: Color {
        switch currentLevel {
        case 1: return .gray
        case 2: return .green
        case 3: return .blue
        case 4: return .purple
        case 5: return .yellow
        default: return .gray
        }
    }
}

// MARK: - XP Animation Overlay

struct XPAnimationOverlay: View {
    let amount: Int
    let isVisible: Bool
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        if isVisible {
            VStack {
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)

                    Text("+\(amount) XP")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.9))
                        .shadow(color: .green.opacity(0.5), radius: 10, x: 0, y: 5)
                )
                .offset(y: offset)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        offset = -20
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            opacity = 0
                            offset = -50
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                }

                Spacer()
                    .frame(height: 100)
            }
        }
    }
}

// MARK: - Level Up Celebration

struct LevelUpCelebration: View {
    let newLevel: Int
    let levelName: String
    let isVisible: Bool
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        if isVisible {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }

                VStack(spacing: 24) {
                    // Star burst animation placeholder
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 20)

                    Text("LEVEL UP!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    VStack(spacing: 8) {
                        Text("Level \(newLevel)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(levelColor)

                        Text(levelName)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Button(action: dismiss) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(levelColor)
                            )
                    }
                    .padding(.top, 16)
                }
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0.8
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    private var levelColor: Color {
        switch newLevel {
        case 1: return .gray
        case 2: return .green
        case 3: return .blue
        case 4: return .purple
        case 5: return .yellow
        default: return .green
        }
    }
}

// MARK: - Preview

#if DEBUG
struct XPDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            XPDisplayView(
                totalXP: 750,
                currentLevel: 2,
                levelName: "Sleep Student",
                xpToNextLevel: 750,
                progressToNextLevel: 0.25
            )

            XPBadgeView(totalXP: 1250, currentLevel: 2)

            XPBadgeView(totalXP: 5500, currentLevel: 4)
        }
        .padding()
        .background(Color.black)
        .environmentObject(ThemeManager.shared)
    }
}
#endif
