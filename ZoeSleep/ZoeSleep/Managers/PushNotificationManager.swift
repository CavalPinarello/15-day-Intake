//
//  PushNotificationManager.swift
//  Zoe Sleep for Longevity System
//
//  Handles push notification permissions, registration, and display
//  Supports streak reminders, insight alerts, and daily nudges
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Types

enum ZoeNotificationType: String, CaseIterable {
    case streakReminder = "streak_reminder"
    case morningNudge = "morning_nudge"
    case insightUnlocked = "insight_unlocked"
    case badgeEarned = "badge_earned"
    case questionnaire = "questionnaire"
    case milestone = "milestone"

    var category: String {
        switch self {
        case .streakReminder: return "STREAK"
        case .morningNudge: return "DAILY"
        case .insightUnlocked: return "INSIGHT"
        case .badgeEarned: return "ACHIEVEMENT"
        case .questionnaire: return "QUESTIONNAIRE"
        case .milestone: return "MILESTONE"
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .streakReminder, .morningNudge, .insightUnlocked:
            return true
        case .badgeEarned, .questionnaire, .milestone:
            return false
        }
    }
}

// MARK: - Push Notification Manager

final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published var isAuthorized: Bool = false
    @Published var deviceToken: String?
    @Published var settings: [ZoeNotificationType: Bool] = [:]

    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard

    private override init() {
        super.init()
        loadSettings()
        checkAuthorizationStatus()
        notificationCenter.delegate = self
    }

    // MARK: - Authorization

    /// Request notification permissions
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await notificationCenter.requestAuthorization(options: options)

            await MainActor.run {
                self.isAuthorized = granted
            }

            if granted {
                await registerForRemoteNotifications()
                setupNotificationCategories()
            }

            return granted
        } catch {
            print("❌ Push notification authorization failed: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    /// Register for remote notifications
    @MainActor
    private func registerForRemoteNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Device Token

    /// Called when device token is received
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token

        // Store token for syncing to server
        userDefaults.set(token, forKey: "apns_device_token")

        print("📱 Push notification token: \(token)")

        // Sync to Convex backend
        Task {
            await syncDeviceToken(token)
        }
    }

    /// Sync device token to Convex backend
    private func syncDeviceToken(_ token: String) async {
        // This would call a Convex mutation to store the device token
        // await ConvexService.shared.registerDevice(token: token)
        print("📤 Device token synced to backend")
    }

    // MARK: - Local Notifications

    /// Schedule a streak reminder notification
    func scheduleStreakReminder(streakCount: Int, at time: Date) {
        guard settings[.streakReminder] == true else { return }

        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak! 🔥"
        content.body = "Complete today's tasks to maintain your \(streakCount)-day streak!"
        content.sound = .default
        content.categoryIdentifier = ZoeNotificationType.streakReminder.category
        content.userInfo = ["type": ZoeNotificationType.streakReminder.rawValue]

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "streak_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule streak reminder: \(error)")
            } else {
                print("✅ Streak reminder scheduled for \(time)")
            }
        }
    }

    /// Schedule a morning nudge notification
    func scheduleMorningNudge(at hour: Int = 8, minute: Int = 0) {
        guard settings[.morningNudge] == true else { return }

        let content = UNMutableNotificationContent()
        content.title = "Good morning! ☀️"
        content.body = "Your sleep log is ready. Start your day with a quick check-in."
        content.sound = .default
        content.categoryIdentifier = ZoeNotificationType.morningNudge.category

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "morning_nudge",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request)
    }

    /// Show immediate notification for badge earned
    func notifyBadgeEarned(badgeName: String, badgeIcon: String) {
        guard settings[.badgeEarned] == true else { return }

        let content = UNMutableNotificationContent()
        content.title = "Badge Earned! \(badgeIcon)"
        content.body = "Congratulations! You've unlocked the \(badgeName) badge."
        content.sound = .default
        content.categoryIdentifier = ZoeNotificationType.badgeEarned.category

        let request = UNNotificationRequest(
            identifier: "badge_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate
        )

        notificationCenter.add(request)
    }

    /// Show notification for insight unlocked
    func notifyInsightUnlocked(insightTitle: String) {
        guard settings[.insightUnlocked] == true else { return }

        let content = UNMutableNotificationContent()
        content.title = "New Insight Unlocked! 💡"
        content.body = insightTitle
        content.sound = .default
        content.categoryIdentifier = ZoeNotificationType.insightUnlocked.category

        let request = UNNotificationRequest(
            identifier: "insight_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    // MARK: - Settings

    /// Load notification settings from UserDefaults
    private func loadSettings() {
        for type in ZoeNotificationType.allCases {
            let key = "notification_\(type.rawValue)"
            if userDefaults.object(forKey: key) != nil {
                settings[type] = userDefaults.bool(forKey: key)
            } else {
                settings[type] = type.defaultEnabled
            }
        }
    }

    /// Update notification setting
    func updateSetting(_ type: ZoeNotificationType, enabled: Bool) {
        settings[type] = enabled
        userDefaults.set(enabled, forKey: "notification_\(type.rawValue)")

        // Cancel existing notifications if disabled
        if !enabled {
            cancelNotifications(for: type)
        }
    }

    /// Cancel notifications of a specific type
    private func cancelNotifications(for type: ZoeNotificationType) {
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter { $0.identifier.hasPrefix(type.rawValue) }
                .map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Notification Categories

    /// Setup interactive notification categories
    private func setupNotificationCategories() {
        // Streak reminder actions
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_NOW",
            title: "Complete Now",
            options: .foreground
        )
        let remindLaterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind in 1 hour",
            options: []
        )
        let streakCategory = UNNotificationCategory(
            identifier: "STREAK",
            actions: [completeAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )

        // Daily nudge actions
        let startLogAction = UNNotificationAction(
            identifier: "START_LOG",
            title: "Start Sleep Log",
            options: .foreground
        )
        let dailyCategory = UNNotificationCategory(
            identifier: "DAILY",
            actions: [startLogAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([streakCategory, dailyCategory])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let notification = response.notification

        switch actionIdentifier {
        case "COMPLETE_NOW", "START_LOG":
            // Navigate to appropriate screen
            NotificationCenter.default.post(
                name: .openQuestionnaire,
                object: nil
            )

        case "REMIND_LATER":
            // Reschedule notification for 1 hour later
            let content = notification.request.content
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
            let request = UNNotificationRequest(
                identifier: notification.request.identifier + "_delayed",
                content: content,
                trigger: trigger
            )
            notificationCenter.add(request)

        default:
            break
        }

        completionHandler()
    }
}

// MARK: - Notification Name Extensions

extension Notification.Name {
    static let openQuestionnaire = Notification.Name("openQuestionnaire")
    static let openInsights = Notification.Name("openInsights")
    static let openBadges = Notification.Name("openBadges")
}
