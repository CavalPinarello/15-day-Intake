//
//  WatchNotificationManager.swift
//  ZoeSleep Watch App
//
//  Handles local notifications for check-in reminders and tasks.
//

import UserNotifications
import WatchKit

// MARK: - Watch Notification Manager

@MainActor
class WatchNotificationManager: ObservableObject {
    static let shared = WatchNotificationManager()

    @Published var isAuthorized = false

    private init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization failed: \(error)")
            return false
        }
    }

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Check-In Reminders

    /// Schedule all three daily check-in reminders
    func scheduleCheckInReminders() {
        scheduleMorningCheckIn()
        scheduleMiddayCheckIn()
        scheduleEveningCheckIn()
    }

    /// Morning check-in reminder at 8:00 AM
    func scheduleMorningCheckIn() {
        let content = UNMutableNotificationContent()
        content.title = "Good Morning!"
        content.body = "How's your energy today?"
        content.sound = .default
        content.categoryIdentifier = "CHECKIN_MORNING"

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "checkin_morning",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule morning check-in: \(error)")
            }
        }
    }

    /// Midday check-in reminder at 1:00 PM
    func scheduleMiddayCheckIn() {
        let content = UNMutableNotificationContent()
        content.title = "Midday Check"
        content.body = "Quick energy update?"
        content.sound = .default
        content.categoryIdentifier = "CHECKIN_MIDDAY"

        var dateComponents = DateComponents()
        dateComponents.hour = 13
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "checkin_midday",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule midday check-in: \(error)")
            }
        }
    }

    /// Evening check-in reminder at 8:00 PM
    func scheduleEveningCheckIn() {
        let content = UNMutableNotificationContent()
        content.title = "Evening Reflection"
        content.body = "How was your day?"
        content.sound = .default
        content.categoryIdentifier = "CHECKIN_EVENING"

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "checkin_evening",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule evening check-in: \(error)")
            }
        }
    }

    // MARK: - Task Reminders

    /// Schedule a reminder for a specific task
    func scheduleTaskReminder(taskId: String, taskName: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "ZOE Task"
        content.body = taskName
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "task_\(taskId)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule task reminder: \(error)")
            }
        }
    }

    /// Cancel a task reminder
    func cancelTaskReminder(taskId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["task_\(taskId)"]
        )
    }

    // MARK: - Day Unlock

    /// Schedule day unlock notification at 4:00 AM
    func scheduleDayUnlockNotification() {
        let content = UNMutableNotificationContent()
        content.title = "New Day Unlocked!"
        content.body = "Ready for today's journey?"
        content.sound = .default
        content.categoryIdentifier = "DAY_UNLOCK"

        var dateComponents = DateComponents()
        dateComponents.hour = 4
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "day_unlock",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule day unlock notification: \(error)")
            }
        }
    }

    // MARK: - Streak Reminders

    /// Schedule a reminder if streak is at risk (no activity by evening)
    func scheduleStreakRiskReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak!"
        content.body = "Complete a check-in before midnight"
        content.sound = .default
        content.categoryIdentifier = "STREAK_RISK"

        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "streak_risk",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule streak risk reminder: \(error)")
            }
        }
    }

    // MARK: - Management

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Cancel check-in reminders only
    func cancelCheckInReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["checkin_morning", "checkin_midday", "checkin_evening"]
        )
    }

    /// List all pending notifications (for debugging)
    func listPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    // MARK: - Notification Categories

    /// Register notification categories for interactive notifications
    func registerNotificationCategories() {
        // Check-in action
        let checkInAction = UNNotificationAction(
            identifier: "CHECKIN_ACTION",
            title: "Check In",
            options: [.foreground]
        )

        // Snooze action
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Remind in 30 min",
            options: []
        )

        // Morning check-in category
        let morningCategory = UNNotificationCategory(
            identifier: "CHECKIN_MORNING",
            actions: [checkInAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Midday check-in category
        let middayCategory = UNNotificationCategory(
            identifier: "CHECKIN_MIDDAY",
            actions: [checkInAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Evening check-in category
        let eveningCategory = UNNotificationCategory(
            identifier: "CHECKIN_EVENING",
            actions: [checkInAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Task category
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Done",
            options: []
        )

        let taskCategory = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            morningCategory,
            middayCategory,
            eveningCategory,
            taskCategory
        ])
    }
}
