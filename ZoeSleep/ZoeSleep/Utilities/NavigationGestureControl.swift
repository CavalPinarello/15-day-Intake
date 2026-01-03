//
//  NavigationGestureControl.swift
//  Zoe Sleep for Longevity System
//
//  Utility to disable the iOS interactive pop gesture (swipe-back)
//  Prevents accidental navigation when using sliders
//

import SwiftUI
import UIKit

// MARK: - Interactive Pop Gesture Disabler

/// A view that finds and disables the UINavigationController's interactive pop gesture
/// This prevents the swipe-from-anywhere-to-go-back gesture from conflicting with sliders
struct InteractivePopGestureDisabler: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> DisablerViewController {
        DisablerViewController()
    }

    func updateUIViewController(_ uiViewController: DisablerViewController, context: Context) {}

    class DisablerViewController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // Disable the interactive pop gesture recognizer
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // Re-enable when leaving this view
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

// MARK: - View Modifier

/// Modifier to disable swipe-back navigation gesture
struct DisableSwipeBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(InteractivePopGestureDisabler())
    }
}

// MARK: - View Extension

extension View {
    /// Disables the iOS swipe-back navigation gesture
    /// Use this on views with horizontal drag gestures (sliders, swipeable content)
    /// to prevent accidental back navigation
    func disableSwipeBack() -> some View {
        modifier(DisableSwipeBackModifier())
    }
}
