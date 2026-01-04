//
//  StreakFreezeView.swift
//  Zoe Sleep for Longevity System
//
//  Streak freeze UI - allows users to protect their streak
//  One freeze per week available
//

import SwiftUI

// MARK: - Streak Freeze Card

struct StreakFreezeCard: View {
    let currentStreak: Int
    let hasFreezeAvailable: Bool
    let streakAtRisk: Bool
    let onUseFreeze: () -> Void

    @State private var showingConfirmation = false
    @State private var isUsingFreeze = false

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ColorTheme { themeManager.currentTheme }
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 16))
                            .foregroundColor(.cyan)

                        Text("Streak Freeze")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.primaryText)
                    }

                    Text("Protect your streak when you miss a day")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                // Availability indicator
                ZStack {
                    Circle()
                        .fill(hasFreezeAvailable ? Color.cyan.opacity(0.2) : theme.secondaryText.opacity(0.2))
                        .frame(width: 40, height: 40)

                    if hasFreezeAvailable {
                        Image(systemName: "snowflake")
                            .font(.system(size: 18))
                            .foregroundColor(.cyan)
                    } else {
                        Text("0")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }

            // Streak at risk warning
            if streakAtRisk {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your \(currentStreak)-day streak is at risk!")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.orange)

                        Text("Complete today's tasks or use a freeze")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            // Use freeze button
            if hasFreezeAvailable && streakAtRisk {
                Button(action: {
                    showingConfirmation = true
                }) {
                    HStack {
                        if isUsingFreeze {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "snowflake")
                                .font(.system(size: 16))
                        }

                        Text("Use Streak Freeze")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isUsingFreeze)
            }

            // Info text
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(hasFreezeAvailable ? "1 freeze available per week" : "Next freeze available Monday")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isEvening ? Color(white: 0.1) : Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .alert("Use Streak Freeze?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Use Freeze") {
                useFreeze()
            }
        } message: {
            Text("This will protect your \(currentStreak)-day streak for today. You can only use one freeze per week.")
        }
    }

    private func useFreeze() {
        isUsingFreeze = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        onUseFreeze()

        // Reset state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isUsingFreeze = false
        }
    }
}

// MARK: - Streak Freeze Success View

struct StreakFreezeSuccessView: View {
    let streakCount: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var snowflakeRotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 24) {
                // Animated snowflake
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.cyan.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)

                    Image(systemName: "snowflake")
                        .font(.system(size: 60))
                        .foregroundColor(.cyan)
                        .rotationEffect(.degrees(snowflakeRotation))
                }

                VStack(spacing: 8) {
                    Text("Streak Protected!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Your \(streakCount)-day streak is safe")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color.cyan, lineWidth: 2)
                        )
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                snowflakeRotation = 360
            }
        }
    }
}

// MARK: - Compact Streak Status (for Dashboard)

struct StreakStatusBadge: View {
    let currentStreak: Int
    let streakAtRisk: Bool
    let hasFreezeAvailable: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Flame
            Image(systemName: currentStreak > 0 ? "flame.fill" : "flame")
                .font(.system(size: 14))
                .foregroundColor(currentStreak > 0 ? .orange : .gray)

            Text("\(currentStreak)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(currentStreak > 0 ? .orange : .gray)

            // Warning if at risk
            if streakAtRisk {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
            }

            // Freeze indicator
            if hasFreezeAvailable {
                Image(systemName: "snowflake")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.15))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct StreakFreezeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StreakFreezeCard(
                currentStreak: 7,
                hasFreezeAvailable: true,
                streakAtRisk: true,
                onUseFreeze: {}
            )

            StreakFreezeCard(
                currentStreak: 3,
                hasFreezeAvailable: false,
                streakAtRisk: false,
                onUseFreeze: {}
            )

            StreakStatusBadge(
                currentStreak: 7,
                streakAtRisk: true,
                hasFreezeAvailable: true
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .environmentObject(ThemeManager.shared)
    }
}
#endif
