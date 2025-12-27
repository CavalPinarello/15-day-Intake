//
//  WatchNotificationManager.swift
//  ZoeSleep Watch App
//
//  Handles local notifications for check-in reminders and tasks.
//  Schedules 3 reminders per check-in slot with varied messages.
//

import UserNotifications
import WatchKit

// MARK: - Watch Notification Manager

@MainActor
class WatchNotificationManager: ObservableObject {
    static let shared = WatchNotificationManager()

    @Published var isAuthorized = false

    // Track which check-ins are done today to avoid unnecessary reminders
    private var completedCheckIns: Set<String> = []

    private init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            self.isAuthorized = granted
            return granted
        } catch {
            print("[Notifications] Authorization failed: \(error)")
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

    // MARK: - Check-In Reminders (3 per slot)

    /// Schedule all check-in reminders (3 per slot = 9 total daily)
    func scheduleCheckInReminders() {
        // Cancel existing to reschedule with fresh messages
        cancelCheckInReminders()

        scheduleMorningReminders()
        scheduleMiddayReminders()
        scheduleEveningReminders()

        print("[Notifications] Scheduled 9 daily check-in reminders")
    }

    /// Morning check-in reminders: 7:00 AM, 9:00 AM, 11:00 AM
    private func scheduleMorningReminders() {
        let times: [(hour: Int, minute: Int)] = [
            (7, 0),   // First reminder - gentle
            (9, 0),   // Second reminder
            (11, 0),  // Third reminder - last chance before window closes
        ]

        for (index, time) in times.enumerated() {
            let reminderNumber = index + 1
            let notificationContent = EncouragementMessages.notificationContent(
                for: .morning,
                reminderNumber: reminderNumber
            )

            let content = UNMutableNotificationContent()
            content.title = notificationContent.title
            content.body = notificationContent.body
            content.sound = notificationContent.sound ? .default : nil
            content.categoryIdentifier = "CHECKIN_MORNING"

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "checkin_morning_\(reminderNumber)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Notifications] Failed to schedule morning \(reminderNumber): \(error)")
                }
            }
        }
    }

    /// Midday check-in reminders: 12:30 PM, 2:30 PM, 5:00 PM
    private func scheduleMiddayReminders() {
        let times: [(hour: Int, minute: Int)] = [
            (12, 30),  // First reminder - gentle
            (14, 30),  // Second reminder
            (17, 0),   // Third reminder - last chance before evening
        ]

        for (index, time) in times.enumerated() {
            let reminderNumber = index + 1
            let notificationContent = EncouragementMessages.notificationContent(
                for: .midday,
                reminderNumber: reminderNumber
            )

            let content = UNMutableNotificationContent()
            content.title = notificationContent.title
            content.body = notificationContent.body
            content.sound = notificationContent.sound ? .default : nil
            content.categoryIdentifier = "CHECKIN_MIDDAY"

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "checkin_midday_\(reminderNumber)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Notifications] Failed to schedule midday \(reminderNumber): \(error)")
                }
            }
        }
    }

    /// Evening check-in reminders: 6:00 PM, 7:15 PM, 8:30 PM (sleep-friendly - no late pings!)
    private func scheduleEveningReminders() {
        let times: [(hour: Int, minute: Int)] = [
            (18, 0),   // First reminder - gentle
            (19, 15),  // Second reminder
            (20, 30),  // Third reminder - last chance (NOT late night!)
        ]

        for (index, time) in times.enumerated() {
            let reminderNumber = index + 1
            let notificationContent = EncouragementMessages.notificationContent(
                for: .evening,
                reminderNumber: reminderNumber
            )

            let content = UNMutableNotificationContent()
            content.title = notificationContent.title
            content.body = notificationContent.body
            content.sound = notificationContent.sound ? .default : nil
            content.categoryIdentifier = "CHECKIN_EVENING"

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "checkin_evening_\(reminderNumber)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Notifications] Failed to schedule evening \(reminderNumber): \(error)")
                }
            }
        }
    }

    // MARK: - Mark Check-In Complete (Cancel Remaining Reminders)

    /// Call this when a check-in is completed to cancel remaining reminders for that slot
    func markCheckInComplete(type: String) {
        completedCheckIns.insert(type)

        // Cancel remaining reminders for this slot
        let identifiersToCancel: [String]
        switch type {
        case "morning":
            identifiersToCancel = ["checkin_morning_1", "checkin_morning_2", "checkin_morning_3"]
        case "midday":
            identifiersToCancel = ["checkin_midday_1", "checkin_midday_2", "checkin_midday_3"]
        case "evening":
            identifiersToCancel = ["checkin_evening_1", "checkin_evening_2", "checkin_evening_3"]
        default:
            return
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiersToCancel
        )

        print("[Notifications] Cancelled \(type) reminders after completion")
    }

    /// Reset completed check-ins at midnight (call from app activation)
    func resetCompletedCheckInsIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastResetKey = "lastNotificationReset"

        if let lastReset = UserDefaults.standard.object(forKey: lastResetKey) as? Date {
            let lastResetDay = Calendar.current.startOfDay(for: lastReset)
            if lastResetDay < today {
                completedCheckIns.removeAll()
                UserDefaults.standard.set(today, forKey: lastResetKey)

                // Reschedule reminders with fresh messages
                scheduleCheckInReminders()
            }
        } else {
            UserDefaults.standard.set(today, forKey: lastResetKey)
        }
    }

    // MARK: - Immediate Encouragement Notification

    /// Show an immediate notification with encouragement after check-in
    func showCheckInSuccessNotification(energy: Int, mood: Int, focus: Int, streak: Int) {
        let content = UNMutableNotificationContent()

        // Use personalized message based on levels
        content.title = streak > 1 ? EncouragementMessages.streakMessage(days: streak) : "Check-In Complete!"
        content.body = EncouragementMessages.personalizedMessage(energy: energy, mood: mood, focus: focus)
        content.sound = .default

        // Trigger immediately (1 second delay for UX)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "checkin_success_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] Failed to show success notification: \(error)")
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
                print("[Notifications] Failed to schedule task reminder: \(error)")
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
                print("[Notifications] Failed to schedule day unlock: \(error)")
            }
        }
    }

    // MARK: - Streak Reminders

    /// Schedule a reminder if streak is at risk (no activity by evening)
    /// Set to 7:45 PM - early enough to not disturb sleep prep
    func scheduleStreakRiskReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak!"
        content.body = EncouragementMessages.missedCheckIn.randomElement() ?? "Complete a check-in before bed"
        content.sound = .default
        content.categoryIdentifier = "STREAK_RISK"

        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 45

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
                print("[Notifications] Failed to schedule streak risk reminder: \(error)")
            }
        }
    }

    // MARK: - Management

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("[Notifications] Cancelled all notifications")
    }

    /// Cancel check-in reminders only
    func cancelCheckInReminders() {
        let identifiers = [
            "checkin_morning_1", "checkin_morning_2", "checkin_morning_3",
            "checkin_midday_1", "checkin_midday_2", "checkin_midday_3",
            "checkin_evening_1", "checkin_evening_2", "checkin_evening_3",
            // Also remove legacy single reminders if they exist
            "checkin_morning", "checkin_midday", "checkin_evening"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    /// List all pending notifications (for debugging)
    func listPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    /// Debug: Print all scheduled notifications
    func debugPrintScheduledNotifications() {
        Task {
            let pending = await listPendingNotifications()
            print("[Notifications] === Scheduled Notifications (\(pending.count)) ===")
            for notification in pending {
                if let trigger = notification.trigger as? UNCalendarNotificationTrigger {
                    let hour = trigger.dateComponents.hour ?? 0
                    let minute = trigger.dateComponents.minute ?? 0
                    print("  - \(notification.identifier): \(String(format: "%02d:%02d", hour, minute)) - \(notification.content.title)")
                } else {
                    print("  - \(notification.identifier): \(notification.content.title)")
                }
            }
            print("[Notifications] =====================================")
        }
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

        // Streak risk category
        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_RISK",
            actions: [checkInAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            morningCategory,
            middayCategory,
            eveningCategory,
            taskCategory,
            streakCategory
        ])

        print("[Notifications] Registered notification categories")
    }
}
