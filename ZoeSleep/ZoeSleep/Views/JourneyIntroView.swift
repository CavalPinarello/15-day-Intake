//
//  JourneyIntroView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Introduces users to the 14-day sleep journey
//  4 screens: 360° understanding, daily routine, expert review, lifelong maintenance
//

import SwiftUI

struct JourneyIntroView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager

    @State private var currentScreen: Int = 0

    private let totalScreens = 4
    private var palette: CircadianPalette { CircadianPalette.current }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated aurora borealis background
                AuroraBorealisView()

                // Subtle vignette for better text readability
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.4)],
                    center: .center,
                    startRadius: 100,
                    endRadius: 500
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Skip button (top right)
                    HStack {
                        Spacer()
                        Button(action: dismiss) {
                            Text("Skip")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, geometry.safeAreaInsets.top > 0 ? 8 : 16)
                    .padding(.trailing, 8)

                    // Content pages - 4 screens
                    TabView(selection: $currentScreen) {
                        JourneyIntroScreen1(screenHeight: geometry.size.height)
                            .tag(0)

                        JourneyIntroScreen2(screenHeight: geometry.size.height)
                            .tag(1)

                        JourneyIntroScreen3(screenHeight: geometry.size.height)
                            .tag(2)

                        JourneyIntroScreen4(screenHeight: geometry.size.height, onComplete: dismiss)
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentScreen)
                    .padding(.horizontal, 16)  // Add horizontal padding to prevent graphics clipping

                    // Page indicator dots
                    JourneyIntroPageIndicator(
                        currentPage: currentScreen,
                        totalPages: totalScreens
                    )
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 24 : 32)
                }

                // Floating accessibility button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        EnhancedReadabilityButton(lightStyle: true, edgePadding: 0)
                            .padding(.trailing, 24)
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 60 : 72)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func dismiss() {
        // Mark as seen
        OnboardingManager.shared.markJourneyIntroSeen()

        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - Page Indicator

struct JourneyIntroPageIndicator: View {
    let currentPage: Int
    let totalPages: Int

    // Aurora teal accent color
    private let auroraAccent = Color(red: 0.1, green: 0.9, blue: 0.8)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage
                          ? auroraAccent
                          : Color.white.opacity(0.3))
                    .frame(
                        width: index == currentPage ? 10 : 8,
                        height: index == currentPage ? 10 : 8
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    JourneyIntroView(isPresented: .constant(true))
}
