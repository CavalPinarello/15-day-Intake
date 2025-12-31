//
//  DebugAutoCompleteButton.swift
//  ZoeSleep
//
//  Floating action button for auto-completing questionnaire sections in debug mode.
//  Fills all answers with gateway-triggering values and immediately submits.
//
//  NOTE: Only visible when Debug Mode is enabled in Settings.
//

import SwiftUI

/// Floating action button for debug auto-complete functionality
struct DebugAutoCompleteButton: View {

    let onTap: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: ColorTheme { themeManager.currentTheme }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle with circadian-aware color
                Circle()
                    .fill(theme.accent.opacity(0.9))
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // Icon
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(theme.textOnPrimary)
            }
        }
        .accessibilityLabel("Auto-complete section")
        .accessibilityHint("Fills all questions with test data and submits")
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                DebugAutoCompleteButton(onTap: {
                    print("Auto-complete tapped")
                })
                .padding(.trailing, 20)
                .padding(.bottom, 100)
            }
        }
    }
}
