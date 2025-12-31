//
//  HapticFeedback.swift
//  Zoe Sleep for Longevity System
//
//  Centralized haptic feedback utilities
//  Provides consistent tactile feedback throughout the app
//

import UIKit
import SwiftUI

// MARK: - Haptic Manager

final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    // MARK: - Impact Feedback

    /// Light tap for subtle interactions (selecting an answer, toggling)
    func lightTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium tap for button presses
    func mediumTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy tap for important actions
    func heavyTap() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Soft tap for gentle feedback
    func softTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    /// Rigid tap for precise feedback
    func rigidTap() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    // MARK: - Notification Feedback

    /// Success feedback for completed actions
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning feedback for alerts
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error feedback for failures
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    /// Selection changed feedback
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Scaled Impact Feedback

    /// Intensity-scaled impact for slider feedback
    /// Uses .light style for gentleness even at full intensity
    /// - Parameter intensity: 0.0 to 1.0, where higher = stronger vibration
    func scaledImpact(intensity: CGFloat) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    // MARK: - Custom Patterns

    /// Question answered - light tap
    func questionAnswered() {
        lightTap()
    }

    /// Section completed - success pattern
    func sectionCompleted() {
        success()
    }

    /// Day completed - celebration pattern
    func dayCompleted() {
        // Two quick taps followed by a success
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.success)
        }
    }

    /// Badge unlocked - special celebration
    func badgeUnlocked() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.success)
        }
    }

    /// Level up - extra special celebration
    func levelUp() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)

        // Rising intensity pattern
        for (index, delay) in [0.0, 0.1, 0.2].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                generator.impactOccurred(intensity: CGFloat(index + 1) / 3.0)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.success)
        }
    }

    /// Streak milestone reached
    func streakMilestone() {
        let generator = UIImpactFeedbackGenerator(style: .medium)

        // Fire-like pattern
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            generator.impactOccurred(intensity: 0.7)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            generator.impactOccurred(intensity: 0.4)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.success)
        }
    }

    /// XP earned - quick positive feedback
    func xpEarned() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Slider/picker value changed
    func valueChanged() {
        selectionChanged()
    }

    /// Error during save or sync
    func saveError() {
        error()
    }

    /// Streak at risk warning
    func streakWarning() {
        warning()
    }

    /// Streak freeze used
    func streakFrozen() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.success)
        }
    }

    /// Navigate forward
    func navigateForward() {
        lightTap()
    }

    /// Navigate back
    func navigateBack() {
        softTap()
    }

    /// Button disabled tap
    func disabledTap() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred(intensity: 0.3)
    }
}

// MARK: - SwiftUI View Modifier

struct HapticButtonStyle: ButtonStyle {
    var hapticType: HapticType = .medium

    enum HapticType {
        case light, medium, heavy, success, selection
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    switch hapticType {
                    case .light:
                        HapticManager.shared.lightTap()
                    case .medium:
                        HapticManager.shared.mediumTap()
                    case .heavy:
                        HapticManager.shared.heavyTap()
                    case .success:
                        HapticManager.shared.success()
                    case .selection:
                        HapticManager.shared.selectionChanged()
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Adds haptic feedback when the view appears
    func hapticOnAppear(_ type: HapticType = .light) -> some View {
        self.onAppear {
            triggerHaptic(type)
        }
    }

    /// Adds haptic feedback when a value changes
    func hapticOnChange<V: Equatable>(of value: V, _ type: HapticType = .selection) -> some View {
        self.onChange(of: value) { _, _ in
            triggerHaptic(type)
        }
    }

    private func triggerHaptic(_ type: HapticType) {
        switch type {
        case .light:
            HapticManager.shared.lightTap()
        case .medium:
            HapticManager.shared.mediumTap()
        case .heavy:
            HapticManager.shared.heavyTap()
        case .success:
            HapticManager.shared.success()
        case .warning:
            HapticManager.shared.warning()
        case .error:
            HapticManager.shared.error()
        case .selection:
            HapticManager.shared.selectionChanged()
        }
    }
}

enum HapticType {
    case light, medium, heavy, success, warning, error, selection
}

// MARK: - Haptic Button Modifier

extension Button {
    /// Applies haptic feedback button style
    func haptic(_ type: HapticButtonStyle.HapticType = .medium) -> some View {
        self.buttonStyle(HapticButtonStyle(hapticType: type))
    }
}
