//
//  CoachMarkView.swift
//  Zoe Sleep for Longevity System
//
//  Floating tooltip bubbles that point to features and explain them
//  Brief, friendly, contextual guidance for first-time users
//  CIRCADIAN-AWARE: Uses warm colors at night
//
//  POSITIONING SYSTEM:
//  - Uses anchor preferences to track actual element frames
//  - Automatically positions bubble to stay within screen bounds
//  - Arrow points precisely to the target element
//

import SwiftUI

// MARK: - Coach Mark Target ID

/// Identifiers for elements that can have coach marks
enum CoachMarkTargetID: String, CaseIterable {
    case settingsButton = "coach_target_settings"
    case journeyProgress = "coach_target_journey"
    case todaysFocusCard = "coach_target_todays_focus"
    case checkInRow = "coach_target_check_in"
    case sleepLogRow = "coach_target_sleep_log"
    case assessmentRow = "coach_target_assessment"
    case upcomingAssessments = "coach_target_upcoming"
}

// MARK: - Preference Key for Target Frames

struct CoachMarkTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [CoachMarkTargetID: CGRect] = [:]

    static func reduce(value: inout [CoachMarkTargetID: CGRect], nextValue: () -> [CoachMarkTargetID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Named Coordinate Space for Coach Marks

/// The coordinate space name used for coach mark positioning
/// This must be applied to the root scrollable content
let coachMarkCoordinateSpace = "coachMarkSpace"

// MARK: - View Extension for Marking Targets

extension View {
    /// Mark this view as a target for coach marks
    /// NOTE: The ancestor view must have .coordinateSpace(name: coachMarkCoordinateSpace) applied
    func coachMarkTarget(_ id: CoachMarkTargetID) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: CoachMarkTargetPreferenceKey.self,
                    value: [id: geo.frame(in: .named(coachMarkCoordinateSpace))]
                )
            }
        )
    }
}

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

    // MARK: - Dashboard Tour (in sequence order)

    /// 1. Journey Duration - at the top
    static let journeyDuration = CoachMarkContent(
        id: "coach_journey_duration",
        icon: "calendar.badge.clock",
        title: "Your 10-Day Journey",
        message: "Complete daily tasks for 10 days to build your personalized sleep profile. Each day reveals more insights!"
    )

    /// 2. Today's Focus - Energy/Mood/Focus check-ins
    static let todaysFocus = CoachMarkContent(
        id: "coach_todays_focus",
        icon: "sun.max.fill",
        title: "Quick Check-Ins",
        message: "Rate your Energy, Mood, and Focus throughout the day. Takes just seconds - helps track how sleep affects your day!"
    )

    /// 3. Sleep Log task
    static let sleepLogTask = CoachMarkContent(
        id: "coach_sleep_log_task",
        icon: "moon.zzz.fill",
        title: "Morning Sleep Log",
        message: "Each morning, log how you slept. We'll ask about bed time, wake time, and sleep quality. Takes ~3 minutes."
    )

    /// 4. Assessment task
    static let assessmentTask = CoachMarkContent(
        id: "coach_assessment_task",
        icon: "list.clipboard.fill",
        title: "Daily Assessment",
        message: "Quick questions about lifestyle, stress, and habits. Helps us understand what affects YOUR sleep specifically."
    )

    /// 5. Upcoming Assessments
    static let upcomingAssessments = CoachMarkContent(
        id: "coach_upcoming_assessments",
        icon: "sparkles",
        title: "Personalized Deep Dives",
        message: "Based on your answers, we may schedule specialized questionnaires. These unlock after Day 5 if relevant to you."
    )

    /// 6. Settings menu
    static let settingsMenu = CoachMarkContent(
        id: "coach_settings_menu",
        icon: "gearshape.fill",
        title: "Your Settings",
        message: "Customize notifications, appearance, and preferences. You can also turn off Sleep Science Cards here."
    )

    // MARK: - Legacy (keep for compatibility)

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
    var hideArrow: Bool = false  // Set to true when arrow is handled externally

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
            if arrowDirection == .up && !hideArrow {
                arrowShape
                    .padding(.bottom, -6)
            }

            // Main bubble
            HStack(spacing: 0) {
                // Arrow at left
                if arrowDirection == .left && !hideArrow {
                    arrowShape
                        .padding(.trailing, -6)
                }

                bubbleContent

                // Arrow at right
                if arrowDirection == .right && !hideArrow {
                    arrowShape
                        .padding(.leading, -6)
                }
            }

            // Arrow at bottom (if pointing down)
            if arrowDirection == .down && !hideArrow {
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
/// DEPRECATED: Use AnchoredCoachMark instead for proper positioning
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

// MARK: - Anchored Coach Mark (Screen-Aware)

/// Coach mark that positions itself relative to an actual UI element
/// Automatically stays within screen bounds and points arrow at target
struct AnchoredCoachMark: View {
    let content: CoachMarkContent
    let targetFrame: CGRect
    let screenSize: CGSize
    let safeAreaInsets: EdgeInsets
    let onDismiss: () -> Void

    @State private var isAppearing: Bool = false
    @EnvironmentObject var themeManager: ThemeManager

    // Bubble constraints
    private let bubbleMaxWidth: CGFloat = 280
    private let bubbleEstimatedHeight: CGFloat = 150
    private let screenPadding: CGFloat = 16
    private let arrowHeight: CGFloat = 12
    private let arrowWidth: CGFloat = 20
    private let verticalGap: CGFloat = 8

    var body: some View {
        ZStack {
            // Spotlight backdrop - dark overlay with cutout for target
            SpotlightBackdrop(
                targetFrame: spotlightFrame,
                screenSize: screenSize,
                opacity: isAppearing ? 0.7 : 0
            )
            .ignoresSafeArea()
            .onTapGesture {
                dismiss()
            }

            // Coach mark bubble with arrow
            bubbleWithArrow
                .position(bubblePosition)
                .opacity(isAppearing ? 1 : 0)
                .scaleEffect(isAppearing ? 1 : 0.8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isAppearing = true
            }
        }
    }

    /// Frame for the spotlight cutout (slightly larger than target for padding)
    private var spotlightFrame: CGRect {
        let padding: CGFloat = 8
        return CGRect(
            x: targetFrame.minX - padding,
            y: targetFrame.minY - padding,
            width: targetFrame.width + padding * 2,
            height: targetFrame.height + padding * 2
        )
    }

    // MARK: - Positioning Logic

    /// Determine whether bubble should appear above or below target
    private var preferBelow: Bool {
        // Calculate space above and below target
        // Note: targetFrame is already in coachMarkCoordinateSpace (relative to the ZStack content area)
        let spaceAbove = targetFrame.minY
        let spaceBelow = screenSize.height - targetFrame.maxY

        // Prefer below if more space, or if target is in top third of screen
        if targetFrame.midY < screenSize.height * 0.35 {
            return true
        }

        return spaceBelow >= bubbleEstimatedHeight + arrowHeight + verticalGap
    }

    /// Calculate arrow direction based on positioning
    private var arrowDirection: CoachMarkArrowDirection {
        preferBelow ? .up : .down
    }

    /// Calculate the X position for the bubble (clamped to screen bounds)
    private var bubbleX: CGFloat {
        let targetCenterX = targetFrame.midX

        // Calculate bounds for bubble center
        let minX = screenPadding + bubbleMaxWidth / 2
        let maxX = screenSize.width - screenPadding - bubbleMaxWidth / 2

        // Clamp to screen bounds
        return min(max(targetCenterX, minX), maxX)
    }

    /// Calculate the Y position for the bubble
    private var bubbleY: CGFloat {
        if preferBelow {
            // Position below target
            return targetFrame.maxY + verticalGap + arrowHeight + bubbleEstimatedHeight / 2
        } else {
            // Position above target
            return targetFrame.minY - verticalGap - arrowHeight - bubbleEstimatedHeight / 2
        }
    }

    /// Final bubble position
    private var bubblePosition: CGPoint {
        CGPoint(x: bubbleX, y: bubbleY)
    }

    /// Calculate arrow X offset from bubble center to point at target
    private var arrowXOffset: CGFloat {
        let targetCenterX = targetFrame.midX
        let offset = targetCenterX - bubbleX

        // Clamp arrow offset to stay within bubble bounds
        let maxOffset = (bubbleMaxWidth / 2) - arrowWidth
        return min(max(offset, -maxOffset), maxOffset)
    }

    // MARK: - Views

    private var bubbleWithArrow: some View {
        VStack(spacing: 0) {
            if arrowDirection == .up {
                arrowView
                    .offset(x: arrowXOffset)
                    .padding(.bottom, -6)
            }

            CoachMarkView(
                content: content,
                arrowDirection: arrowDirection,
                onDismiss: dismiss,
                hideArrow: true  // Arrow is handled separately for precise positioning
            )

            if arrowDirection == .down {
                arrowView
                    .offset(x: arrowXOffset)
                    .padding(.top, -6)
            }
        }
    }

    private var arrowView: some View {
        let theme = themeManager.currentTheme
        let palette = themeManager.circadianPalette

        let bubbleBackground = theme.cardBackground
        let bubbleBorder = palette.isDark
            ? theme.accent.opacity(0.4)
            : theme.secondaryText.opacity(0.2)

        return CoachMarkArrow()
            .fill(bubbleBackground)
            .frame(width: arrowWidth, height: arrowHeight)
            .overlay(
                CoachMarkArrow()
                    .stroke(bubbleBorder, lineWidth: 1)
            )
            .rotationEffect(arrowDirection == .down ? .degrees(180) : .degrees(0))
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

// MARK: - Dashboard Tour Overlay

/// Full-screen overlay for dashboard tour that uses actual element positions
/// Enhanced with navigation controls: back/next arrows, step indicator, and skip option
struct DashboardTourOverlay: View {
    let currentStep: Int
    let totalSteps: Int
    let targetFrames: [CoachMarkTargetID: CGRect]
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAppearing = false
    @State private var displayedStep: Int = 0

    private var theme: ColorTheme { themeManager.currentTheme }

    /// Map tour steps to their target elements
    static let stepTargets: [Int: CoachMarkTargetID] = [
        1: .journeyProgress,      // Day X of 10
        2: .checkInRow,           // Check-In (Energy/Mood/Focus)
        3: .sleepLogRow,          // Sleep Log
        4: .assessmentRow,        // Assessment
        5: .upcomingAssessments,  // Upcoming Assessments
        6: .settingsButton        // Settings
    ]

    /// Map tour steps to their content
    static let stepContent: [Int: CoachMarkContent] = [
        1: CoachMarkLibrary.journeyDuration,
        2: CoachMarkLibrary.todaysFocus,
        3: CoachMarkLibrary.sleepLogTask,
        4: CoachMarkLibrary.assessmentTask,
        5: CoachMarkLibrary.upcomingAssessments,
        6: CoachMarkLibrary.settingsMenu
    ]

    var body: some View {
        GeometryReader { geometry in
            let targetID = Self.stepTargets[displayedStep]
            let targetFrame = targetID.flatMap { targetFrames[$0] }
            let isVisible = isFrameVisible(targetFrame, in: geometry)

            #if DEBUG
            let _ = print("[CoachMark Tour] Step \(displayedStep): targetID=\(targetID?.rawValue ?? "nil"), frame=\(targetFrame.map { "y:\(Int($0.minY))-\(Int($0.maxY))" } ?? "nil"), visible=\(isVisible), isAppearing=\(isAppearing)")
            #endif

            ZStack {
                // Always show the dark backdrop
                Color.black.opacity(isAppearing ? 0.7 : 0)
                    .ignoresSafeArea()

                if let content = Self.stepContent[displayedStep],
                   let frame = targetFrame,
                   isVisible,
                   isAppearing {
                    // Spotlight cutout for target element
                    SpotlightBackdrop(
                        targetFrame: spotlightFrame(for: frame),
                        screenSize: geometry.size,
                        opacity: 0.7
                    )
                    .ignoresSafeArea()

                    // Coach mark bubble
                    tourBubble(content: content, targetFrame: frame, geometry: geometry)
                }

                // Navigation controls at bottom (always visible when appearing)
                if isAppearing {
                    VStack {
                        Spacer()
                        tourNavigationBar
                            .padding(.horizontal, 20)
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayedStep)
        }
        .ignoresSafeArea()
        .onAppear {
            displayedStep = currentStep
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isAppearing = true
            }
        }
        .onChange(of: currentStep) { oldValue, newValue in
            // Animate transition between steps
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                displayedStep = newValue
            }
        }
    }

    // MARK: - Tour Bubble

    @ViewBuilder
    private func tourBubble(content: CoachMarkContent, targetFrame: CGRect, geometry: GeometryProxy) -> some View {
        let position = calculateBubblePosition(targetFrame: targetFrame, geometry: geometry)
        let arrowDirection: CoachMarkArrowDirection = position.preferBelow ? .up : .down
        let arrowXOffset = calculateArrowXOffset(targetFrame: targetFrame, bubbleX: position.x)

        VStack(spacing: 0) {
            if arrowDirection == .up {
                arrowView(direction: .up)
                    .offset(x: arrowXOffset)
                    .padding(.bottom, -6)
            }

            tourBubbleContent(content: content)

            if arrowDirection == .down {
                arrowView(direction: .down)
                    .offset(x: arrowXOffset)
                    .padding(.top, -6)
            }
        }
        .position(x: position.x, y: position.y)
        .opacity(isAppearing ? 1 : 0)
        .scaleEffect(isAppearing ? 1 : 0.8)
    }

    private func tourBubbleContent(content: CoachMarkContent) -> some View {
        let palette = themeManager.circadianPalette
        let bubbleBackground = theme.cardBackground
        let bubbleBorder = palette.isDark
            ? theme.accent.opacity(0.4)
            : theme.secondaryText.opacity(0.2)

        return VStack(alignment: .leading, spacing: 10) {
            // Header with icon and title
            HStack(spacing: 10) {
                Image(systemName: content.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(theme.accent)

                Text(content.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primaryText)

                Spacer()
            }

            // Message
            Text(content.message)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(theme.secondaryText.opacity(0.9))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
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

    private func arrowView(direction: CoachMarkArrowDirection) -> some View {
        let palette = themeManager.circadianPalette
        let bubbleBackground = theme.cardBackground
        let bubbleBorder = palette.isDark
            ? theme.accent.opacity(0.4)
            : theme.secondaryText.opacity(0.2)

        return CoachMarkArrow()
            .fill(bubbleBackground)
            .frame(width: 20, height: 12)
            .overlay(
                CoachMarkArrow()
                    .stroke(bubbleBorder, lineWidth: 1)
            )
            .rotationEffect(direction == .down ? .degrees(180) : .degrees(0))
    }

    // MARK: - Navigation Bar

    private var tourNavigationBar: some View {
        HStack(spacing: 16) {
            // Skip button (left side)
            Button(action: onSkip) {
                Text("Skip Tour")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(currentStep > 1 ? theme.accent : theme.secondaryText.opacity(0.4))
            }
            .disabled(currentStep <= 1)

            // Step indicator
            Text("\(currentStep) of \(totalSteps)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(theme.secondaryText)
                .frame(minWidth: 50)

            // Next/Done button
            Button(action: onNext) {
                HStack(spacing: 4) {
                    Text(currentStep >= totalSteps ? "Done" : "Next")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    if currentStep < totalSteps {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(theme.textOnPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.accent)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground.opacity(0.95))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: -4)
        )
    }

    // MARK: - Positioning Helpers

    private struct BubblePosition {
        let x: CGFloat
        let y: CGFloat
        let preferBelow: Bool
    }

    private func calculateBubblePosition(targetFrame: CGRect, geometry: GeometryProxy) -> BubblePosition {
        let bubbleMaxWidth: CGFloat = 280
        let bubbleEstimatedHeight: CGFloat = 120
        let screenPadding: CGFloat = 16
        let arrowHeight: CGFloat = 12
        let verticalGap: CGFloat = 8

        // Determine if bubble should be above or below
        let preferBelow = targetFrame.midY < geometry.size.height * 0.4

        // Calculate X position (clamped to screen)
        let minX = screenPadding + bubbleMaxWidth / 2
        let maxX = geometry.size.width - screenPadding - bubbleMaxWidth / 2
        let x = min(max(targetFrame.midX, minX), maxX)

        // Calculate Y position
        let y: CGFloat
        if preferBelow {
            y = targetFrame.maxY + verticalGap + arrowHeight + bubbleEstimatedHeight / 2
        } else {
            y = targetFrame.minY - verticalGap - arrowHeight - bubbleEstimatedHeight / 2
        }

        return BubblePosition(x: x, y: y, preferBelow: preferBelow)
    }

    private func calculateArrowXOffset(targetFrame: CGRect, bubbleX: CGFloat) -> CGFloat {
        let offset = targetFrame.midX - bubbleX
        let maxOffset: CGFloat = (280.0 / 2.0) - 20.0
        return min(max(offset, -maxOffset), maxOffset)
    }

    private func spotlightFrame(for targetFrame: CGRect) -> CGRect {
        let padding: CGFloat = 8
        return CGRect(
            x: targetFrame.minX - padding,
            y: targetFrame.minY - padding,
            width: targetFrame.width + padding * 2,
            height: targetFrame.height + padding * 2
        )
    }

    /// Check if a frame is valid and visible on screen
    private func isFrameVisible(_ frame: CGRect?, in geometry: GeometryProxy) -> Bool {
        guard let frame = frame else { return false }

        // Frame must have valid dimensions
        guard frame.width > 0, frame.height > 0 else { return false }

        // Since frames are captured relative to the coachMarkCoordinateSpace (the ZStack),
        // they're already in the content area. Check if frame is within visible bounds.
        let screenHeight = geometry.size.height

        // Check if frame is at least partially within visible area (at least 20 points visible)
        let visibleTop = max(frame.minY, 0)
        let visibleBottom = min(frame.maxY, screenHeight)
        let visibleHeight = visibleBottom - visibleTop

        return visibleHeight >= 20
    }
}

// MARK: - Spotlight Backdrop

/// Dark overlay with a rounded rectangle cutout to highlight the target element
struct SpotlightBackdrop: View {
    let targetFrame: CGRect
    let screenSize: CGSize
    let opacity: Double
    let cornerRadius: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            // Fill the entire canvas with dark color
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(opacity))
            )

            // Cut out the spotlight area (make it transparent)
            context.blendMode = .destinationOut
            let spotlightPath = Path(roundedRect: targetFrame, cornerRadius: cornerRadius)
            context.fill(spotlightPath, with: .color(.white))
        }
        .compositingGroup()
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
