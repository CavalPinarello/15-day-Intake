//
//  CoachMarkView.swift
//  Zoe Sleep for Longevity System
//
//  Floating tooltip bubbles that point to features and explain them
//  Brief, friendly, contextual guidance for first-time users
//  CIRCADIAN-AWARE: Uses warm colors at night
//

import SwiftUI

// MARK: - Arrow Direction

enum CoachMarkArrowDirection {
    case up
    case down
    case left
    case right

    var rotation: Angle {
        switch self {
        case .up: return .degrees(0)
        case .down: return .degrees(180)
        case .left: return .degrees(-90)
        case .right: return .degrees(90)
        }
    }
}

// MARK: - Coach Mark Content

struct CoachMarkContent {
    let id: String
    let icon: String
    let title: String
    let message: String
    let buttonText: String

    init(id: String, icon: String, title: String, message: String, buttonText: String = "Got it") {
        self.id = id
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonText = buttonText
    }
}

// MARK: - Coach Mark Library

enum CoachMarkLibrary {

    // MARK: - Dashboard

    static let sleepLogTask = CoachMarkContent(
        id: "coach_sleep_log_task",
        icon: "moon.zzz.fill",
        title: "Morning Sleep Log",
        message: "Tap here each morning to log last night's sleep. Takes about 2 minutes!"
    )

    static let assessmentTask = CoachMarkContent(
        id: "coach_assessment_task",
        icon: "list.clipboard.fill",
        title: "Daily Assessment",
        message: "Quick questions about your day. Helps us understand what affects your sleep."
    )

    static let progressGarden = CoachMarkContent(
        id: "coach_progress_garden",
        icon: "leaf.fill",
        title: "Your Sleep Garden",
        message: "Watch it grow as you complete daily tasks. Each day adds new life!"
    )

    static let streakCounter = CoachMarkContent(
        id: "coach_streak_counter",
        icon: "flame.fill",
        title: "Daily Streak",
        message: "Complete both tasks daily to build your streak. Consistency is key!"
    )

    static let dayProgress = CoachMarkContent(
        id: "coach_day_progress",
        icon: "calendar.circle.fill",
        title: "Journey Progress",
        message: "10 days of data builds your personalized sleep profile. You're on your way!"
    )

    // MARK: - Settings

    static let sleepScienceCards = CoachMarkContent(
        id: "coach_science_cards",
        icon: "sparkles",
        title: "Sleep Science Cards",
        message: "Fun facts appear between questions. Turn off here if you prefer a faster flow."
    )

    static let circadianMode = CoachMarkContent(
        id: "coach_circadian_mode",
        icon: "sun.and.horizon.fill",
        title: "Circadian Colors",
        message: "Colors shift warmer at night to protect your sleep. No blue light after sunset!"
    )

    static let notifications = CoachMarkContent(
        id: "coach_notifications",
        icon: "bell.badge.fill",
        title: "Smart Reminders",
        message: "Gentle nudges to keep you on track. Customize timing to fit your schedule."
    )

    // MARK: - HealthKit

    static let healthKitConnect = CoachMarkContent(
        id: "coach_healthkit_connect",
        icon: "heart.fill",
        title: "Apple Health",
        message: "Connect to import sleep data from your watch. Makes logging even easier!"
    )

    static let healthKitData = CoachMarkContent(
        id: "coach_healthkit_data",
        icon: "waveform.path.ecg",
        title: "Your Health Data",
        message: "We combine your Apple Health data with your answers for deeper insights."
    )

    // MARK: - Questionnaire

    static let questionProgress = CoachMarkContent(
        id: "coach_question_progress",
        icon: "chart.bar.fill",
        title: "Progress Bar",
        message: "See how far along you are. Most questions take just a few seconds!"
    )

    static let backButton = CoachMarkContent(
        id: "coach_back_button",
        icon: "arrow.left.circle.fill",
        title: "Go Back Anytime",
        message: "Changed your mind? Tap back to review or change your previous answer."
    )
}

// MARK: - Coach Mark View

struct CoachMarkView: View {
    let content: CoachMarkContent
    let arrowDirection: CoachMarkArrowDirection
    let onDismiss: () -> Void

    @State private var isAppearing: Bool = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Circadian Colors (Theme-based)

    private var theme: ColorTheme { themeManager.currentTheme }
    private var palette: CircadianPalette { themeManager.circadianPalette }

    private var bubbleBackground: Color {
        theme.cardBackground
    }

    private var bubbleBorder: Color {
        palette.isDark
            ? theme.accent.opacity(0.4)
            : theme.secondaryText.opacity(0.2)
    }

    private var titleColor: Color {
        theme.primaryText
    }

    private var messageColor: Color {
        theme.secondaryText.opacity(0.9)
    }

    private var accentColor: Color {
        theme.accent
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Arrow at top (if pointing up)
            if arrowDirection == .up {
                arrowShape
                    .padding(.bottom, -6)
            }

            // Main bubble
            HStack(spacing: 0) {
                // Arrow at left
                if arrowDirection == .left {
                    arrowShape
                        .padding(.trailing, -6)
                }

                bubbleContent

                // Arrow at right
                if arrowDirection == .right {
                    arrowShape
                        .padding(.leading, -6)
                }
            }

            // Arrow at bottom (if pointing down)
            if arrowDirection == .down {
                arrowShape
                    .padding(.top, -6)
            }
        }
        .scaleEffect(isAppearing ? 1 : 0.8)
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            if reduceMotion {
                isAppearing = true
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isAppearing = true
                }
            }
        }
    }

    // MARK: - Arrow Shape

    private var arrowShape: some View {
        CoachMarkArrow()
            .fill(bubbleBackground)
            .frame(width: 20, height: 12)
            .overlay(
                CoachMarkArrow()
                    .stroke(bubbleBorder, lineWidth: 1)
            )
            .rotationEffect(arrowDirection.rotation)
    }

    // MARK: - Bubble Content

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with icon and title
            HStack(spacing: 10) {
                Image(systemName: content.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(accentColor)

                Text(content.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(titleColor)

                Spacer()
            }

            // Message
            Text(content.message)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(messageColor)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Dismiss button
            Button(action: onDismiss) {
                Text(content.buttonText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textOnPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(accentColor)
                    .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(maxWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bubbleBackground)
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(bubbleBorder, lineWidth: 1)
        )
    }
}

// MARK: - Coach Mark With Backdrop

/// A coach mark with a dimmed backdrop overlay for better visibility
struct CoachMarkWithBackdrop: View {
    let content: CoachMarkContent
    let arrowDirection: CoachMarkArrowDirection
    let targetOffset: CGSize
    let onDismiss: () -> Void

    @State private var isAppearing: Bool = false

    var body: some View {
        ZStack {
            // Dimmed backdrop - tap to dismiss
            Color.black.opacity(isAppearing ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Coach mark bubble
            CoachMarkView(
                content: content,
                arrowDirection: arrowDirection,
                onDismiss: dismiss
            )
            .offset(targetOffset)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isAppearing = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isAppearing = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Coach Mark Arrow Shape

struct CoachMarkArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Coach Mark Overlay Modifier

struct CoachMarkOverlay: ViewModifier {
    let content: CoachMarkContent
    let arrowDirection: CoachMarkArrowDirection
    let alignment: Alignment
    let offset: CGSize
    @Binding var isShowing: Bool

    func body(content view: Content) -> some View {
        view.overlay(alignment: alignment) {
            if isShowing {
                CoachMarkView(
                    content: content,
                    arrowDirection: arrowDirection
                ) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowing = false
                    }
                    // Mark as shown
                    UserDefaults.standard.set(true, forKey: self.content.id)
                }
                .offset(offset)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

extension View {
    /// Add a coach mark tooltip to a view
    func coachMark(
        _ content: CoachMarkContent,
        arrow: CoachMarkArrowDirection = .up,
        alignment: Alignment = .bottom,
        offset: CGSize = .zero,
        isShowing: Binding<Bool>
    ) -> some View {
        modifier(CoachMarkOverlay(
            content: content,
            arrowDirection: arrow,
            alignment: alignment,
            offset: offset,
            isShowing: isShowing
        ))
    }

    /// Check if coach mark should show (hasn't been shown before)
    func shouldShowCoachMark(_ content: CoachMarkContent) -> Bool {
        !UserDefaults.standard.bool(forKey: content.id)
    }
}

// MARK: - Spotlight Overlay

/// Full-screen overlay that dims everything except the highlighted area
struct SpotlightCoachMark: View {
    let content: CoachMarkContent
    let arrowDirection: CoachMarkArrowDirection
    let spotlightFrame: CGRect
    let onDismiss: () -> Void

    @State private var isAppearing: Bool = false

    var body: some View {
        ZStack {
            // Dimmed background with cutout
            SpotlightMask(spotlightFrame: spotlightFrame)
                .fill(Color.black.opacity(0.6))
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Coach mark positioned near spotlight
            CoachMarkView(
                content: content,
                arrowDirection: arrowDirection,
                onDismiss: dismiss
            )
            .position(coachMarkPosition)
        }
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isAppearing = true
            }
        }
    }

    private var coachMarkPosition: CGPoint {
        let padding: CGFloat = 20
        switch arrowDirection {
        case .up:
            return CGPoint(x: spotlightFrame.midX, y: spotlightFrame.maxY + padding + 60)
        case .down:
            return CGPoint(x: spotlightFrame.midX, y: spotlightFrame.minY - padding - 60)
        case .left:
            return CGPoint(x: spotlightFrame.maxX + padding + 100, y: spotlightFrame.midY)
        case .right:
            return CGPoint(x: spotlightFrame.minX - padding - 100, y: spotlightFrame.midY)
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isAppearing = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UserDefaults.standard.set(true, forKey: content.id)
            onDismiss()
        }
    }
}

// MARK: - Spotlight Mask Shape

struct SpotlightMask: Shape {
    let spotlightFrame: CGRect
    let cornerRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)

        // Add rounded rect cutout
        let spotlight = CGRect(
            x: spotlightFrame.minX - 8,
            y: spotlightFrame.minY - 8,
            width: spotlightFrame.width + 16,
            height: spotlightFrame.height + 16
        )
        path.addRoundedRect(in: spotlight, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        return path
    }
}

// MARK: - Previews

#Preview("Coach Mark - Arrow Up") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.3))
                .frame(width: 200, height: 60)

            CoachMarkView(
                content: CoachMarkLibrary.sleepLogTask,
                arrowDirection: .up,
                onDismiss: {}
            )
        }
    }
}

#Preview("Coach Mark - Arrow Down") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

        VStack {
            CoachMarkView(
                content: CoachMarkLibrary.progressGarden,
                arrowDirection: .down,
                onDismiss: {}
            )

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.3))
                .frame(width: 200, height: 100)
        }
    }
}

#Preview("Coach Mark - Settings") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

        CoachMarkView(
            content: CoachMarkLibrary.sleepScienceCards,
            arrowDirection: .left,
            onDismiss: {}
        )
    }
}
