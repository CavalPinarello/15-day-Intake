//
//  NavigationGestureControl.swift
//  Zoe Sleep for Longevity System
//
//  Utility to disable the iOS interactive pop gesture (swipe-back)
//  Prevents accidental navigation when using sliders
//

import SwiftUI
import UIKit

// MARK: - Navigation Controller Finder

/// Finds the UINavigationController in the view hierarchy
/// Uses multiple strategies to ensure we find it regardless of SwiftUI's internal structure
struct NavigationControllerFinder {

    /// Find navigation controller from any UIView by traversing the responder chain
    static func find(from view: UIView) -> UINavigationController? {
        // Strategy 1: Walk the responder chain
        var responder: UIResponder? = view
        while let current = responder {
            if let navController = current as? UINavigationController {
                return navController
            }
            if let viewController = current as? UIViewController {
                if let navController = viewController.navigationController {
                    return navController
                }
            }
            responder = current.next
        }

        // Strategy 2: Find through the view's window
        if let window = view.window {
            return findNavigationController(in: window.rootViewController)
        }

        return nil
    }

    /// Recursively search view controller hierarchy
    private static func findNavigationController(in viewController: UIViewController?) -> UINavigationController? {
        guard let vc = viewController else { return nil }

        if let nav = vc as? UINavigationController {
            return nav
        }

        if let nav = vc.navigationController {
            return nav
        }

        // Check children
        for child in vc.children {
            if let found = findNavigationController(in: child) {
                return found
            }
        }

        // Check presented view controller
        if let presented = vc.presentedViewController {
            if let found = findNavigationController(in: presented) {
                return found
            }
        }

        return nil
    }
}

// MARK: - Interactive Pop Gesture Disabler

/// A UIView that disables the navigation controller's interactive pop gesture
final class GestureDisablerView: UIView {

    private weak var disabledNavController: UINavigationController?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }

        // Small delay to ensure view hierarchy is fully set up
        DispatchQueue.main.async { [weak self] in
            self?.disableGesture()
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        // Re-enable when being removed
        if newWindow == nil {
            enableGesture()
        }
    }

    private func disableGesture() {
        if let navController = NavigationControllerFinder.find(from: self) {
            navController.interactivePopGestureRecognizer?.isEnabled = false
            disabledNavController = navController
            #if DEBUG
            print("[GestureDisabler] ✓ Disabled swipe-back gesture")
            #endif
        } else {
            #if DEBUG
            print("[GestureDisabler] ⚠️ Could not find navigation controller")
            #endif
        }
    }

    private func enableGesture() {
        disabledNavController?.interactivePopGestureRecognizer?.isEnabled = true
        #if DEBUG
        print("[GestureDisabler] ✓ Re-enabled swipe-back gesture")
        #endif
        disabledNavController = nil
    }
}

/// SwiftUI wrapper for the gesture disabler
struct InteractivePopGestureDisabler: UIViewRepresentable {

    func makeUIView(context: Context) -> GestureDisablerView {
        let view = GestureDisablerView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        // Make the frame non-zero so it gets added to the view hierarchy properly
        view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        return view
    }

    func updateUIView(_ uiView: GestureDisablerView, context: Context) {}
}

// MARK: - View Modifier

/// Modifier to disable swipe-back navigation gesture
struct DisableSwipeBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                InteractivePopGestureDisabler()
                    .frame(width: 1, height: 1)
            )
    }
}

// MARK: - View Extension

extension View {
    /// Disables the iOS swipe-back navigation gesture
    /// Use this on views with horizontal drag gestures (sliders, swipeable content)
    /// to prevent accidental back navigation
    ///
    /// Note: Users can still navigate back using the back button
    func disableSwipeBack() -> some View {
        modifier(DisableSwipeBackModifier())
    }
}
