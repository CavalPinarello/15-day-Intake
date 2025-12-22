//
//  EnhancedReadabilityOverlay.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Provides instant accessibility for elderly users (70+)
//  Floating magnifying glass button available from splash screen onwards
//  Single toggle activates 1.5x text, large icons, high contrast, reduced motion
//

import SwiftUI

// MARK: - Floating Accessibility Button

/// A floating magnifying glass button that appears in the bottom-right corner
/// Provides instant access to Enhanced Readability Mode from any screen
struct EnhancedReadabilityButton: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingSheet = false
    @State private var hasAppeared = false

    /// Whether to show in a light style (for dark backgrounds like splash screen)
    var lightStyle: Bool = false

    /// Padding from the screen edges
    var edgePadding: CGFloat = 20

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                Button(action: {
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    showingSheet = true
                }) {
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(lightStyle ? Color.white.opacity(0.2) : Color(.systemBackground))
                            .frame(width: 56, height: 56)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

                        // Icon
                        Image(systemName: themeManager.enhancedReadabilityMode
                              ? "text.magnifyingglass"
                              : "magnifyingglass")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(iconColor)

                        // Active indicator
                        if themeManager.enhancedReadabilityMode {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(lightStyle ? Color.black.opacity(0.3) : Color.white, lineWidth: 2)
                                )
                                .offset(x: 18, y: -18)
                        }
                    }
                }
                .accessibilityLabel(themeManager.enhancedReadabilityMode
                                    ? "Enhanced Readability is on. Tap to adjust."
                                    : "Tap for larger text and easier reading")
                .accessibilityHint("Opens accessibility options")
                // Subtle pulse animation on first appearance (if not in reduce motion mode)
                .scaleEffect(hasAppeared ? 1.0 : 0.8)
                .opacity(hasAppeared ? 1.0 : 0)
            }
            .padding(.trailing, edgePadding)
            .padding(.bottom, edgePadding)
        }
        .sheet(isPresented: $showingSheet) {
            EnhancedReadabilitySheet()
        }
        .onAppear {
            // Animate in (respect reduce motion)
            let animation: Animation = themeManager.reduceMotion
                ? .linear(duration: 0)
                : .spring(response: 0.5, dampingFraction: 0.7).delay(0.3)
            withAnimation(animation) {
                hasAppeared = true
            }
        }
    }

    private var iconColor: Color {
        if themeManager.enhancedReadabilityMode {
            return lightStyle ? .white : themeManager.accentColor
        } else {
            return lightStyle ? .white.opacity(0.9) : .primary
        }
    }
}

// MARK: - Enhanced Readability Sheet

/// Modal sheet explaining and controlling Enhanced Readability Mode
struct EnhancedReadabilitySheet: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header illustration
                    headerSection

                    // Main toggle
                    mainToggleSection

                    // What it does
                    featuresSection

                    // Preview
                    previewSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reading Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Large icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.primary.opacity(0.2), theme.primary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(theme.primary)
            }

            VStack(spacing: 8) {
                Text("Enhanced Readability")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Make everything easier to read with larger text, bigger buttons, and clearer visuals.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Main Toggle Section

    private var mainToggleSection: some View {
        VStack(spacing: 12) {
            // Large, prominent toggle button
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    themeManager.enhancedReadabilityMode.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Status indicator
                    ZStack {
                        Circle()
                            .fill(themeManager.enhancedReadabilityMode ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)

                        if themeManager.enhancedReadabilityMode {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    Text(themeManager.enhancedReadabilityMode ? "ON" : "OFF")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.enhancedReadabilityMode ? .green : .secondary)

                    Spacer()

                    // Large visual switch
                    ZStack {
                        Capsule()
                            .fill(themeManager.enhancedReadabilityMode ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 70, height: 40)

                        Circle()
                            .fill(.white)
                            .frame(width: 32, height: 32)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: themeManager.enhancedReadabilityMode ? 14 : -14)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enhanced Readability Mode")
            .accessibilityValue(themeManager.enhancedReadabilityMode ? "On" : "Off")
            .accessibilityHint("Double-tap to toggle")
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What this enables:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 12) {
                FeatureRow(
                    icon: "textformat.size.larger",
                    title: "50% Larger Text",
                    description: "All text is easier to read",
                    isActive: themeManager.enhancedReadabilityMode
                )

                FeatureRow(
                    icon: "hand.tap",
                    title: "Bigger Tap Targets",
                    description: "Buttons are larger and easier to press",
                    isActive: themeManager.enhancedReadabilityMode
                )

                FeatureRow(
                    icon: "circle.lefthalf.filled",
                    title: "Higher Contrast",
                    description: "Clearer borders and colors",
                    isActive: themeManager.enhancedReadabilityMode
                )

                FeatureRow(
                    icon: "figure.walk",
                    title: "Less Animation",
                    description: "Calmer, steadier interface",
                    isActive: themeManager.enhancedReadabilityMode
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 20) {
                // Normal text
                VStack(spacing: 8) {
                    Text("Aa")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Normal")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.enhancedReadabilityMode ? Color.clear : theme.primary, lineWidth: 2)
                        )
                )

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)

                // Enhanced text
                VStack(spacing: 8) {
                    Text("Aa")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Enhanced")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.enhancedReadabilityMode ? theme.primary : Color.clear, lineWidth: 2)
                        )
                )
            }

            // Settings reminder
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                Text("You can change this anytime in Settings")
                    .font(.system(size: 14))
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
        }
    }
}

// MARK: - Feature Row Component

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isActive ? .green : .secondary)
                .frame(width: 24)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Checkmark when active
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - View Modifier for Adding the Button

/// Convenience modifier to add the accessibility button to any view
extension View {
    /// Adds the floating Enhanced Readability button to this view
    /// - Parameters:
    ///   - lightStyle: Use light colors for dark backgrounds (e.g., splash screen)
    ///   - edgePadding: Distance from screen edges
    func withEnhancedReadabilityButton(lightStyle: Bool = false, edgePadding: CGFloat = 20) -> some View {
        self.overlay(
            EnhancedReadabilityButton(lightStyle: lightStyle, edgePadding: edgePadding)
        )
    }
}

// MARK: - Previews

#Preview("Button - Light") {
    ZStack {
        Color.black.ignoresSafeArea()
        Text("Content")
            .foregroundColor(.white)
    }
    .withEnhancedReadabilityButton(lightStyle: true)
}

#Preview("Button - Dark") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        Text("Content")
    }
    .withEnhancedReadabilityButton(lightStyle: false)
}

#Preview("Sheet") {
    EnhancedReadabilitySheet()
}
