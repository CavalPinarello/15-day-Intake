//
//  WatchNotificationManager.swift
//  ZoeSleep Watch App
//
//  Comprehensive notification system for sleep journey.
//  - Checks Convex for completion status before notifying
//  - Sleep log & assessment reminders
//  - Energy nudges at varied times
//  - 100+ message variety to prevent habituation
//

import UserNotifications
import WatchKit

// MARK: - Watch Notification Manager

@MainActor
class WatchNotificationManager: ObservableObject {
    static let shared = WatchNotificationManager()

    @Published var isAuthorized = false

    // Track completion status to avoid unnecessary notifications
    private var lastKnownSleepLogComplete = false
    private var lastKnownAssessmentComplete = false
    private var lastCheckTime: Date?

    // Reference to Convex for checking completion status
    private var convexService: WatchConvexService { WatchConvexService.shared }

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

    // MARK: - Master Schedule (Call on App Activation)

    /// Schedule all notifications - only 2 per day (midday and evening check-ins)
    func scheduleAllNotifications() async {
        guard isAuthorized else { return }

        // Fetch current completion status from Convex
        await refreshCompletionStatus()

        // Cancel all existing notifications and reschedule
        cancelAllNotifications()

        // Only schedule check-in reminders (midday and evening)
        scheduleCheckInReminders()
        scheduleDayUnlockNotification()

        print("[Notifications] Scheduled 2 daily check-in notifications")
    }

    /// Refresh completion status from Convex (ground truth)
    private func refreshCompletionStatus() async {
        guard convexService.isAuthenticated else {
            print("[Notifications] Not authenticated - can't check Convex")
            return
        }

        do {
            _ = try await convexService.fetchJourneyState()
            lastKnownSleepLogComplete = convexService.sleepLogCompleted
            lastKnownAssessmentComplete = convexService.assessmentCompleted
            lastCheckTime = Date()
            print("[Notifications] Convex status: SleepLog=\(lastKnownSleepLogComplete), Assessment=\(lastKnownAssessmentComplete)")
        } catch {
            print("[Notifications] Failed to fetch Convex status: \(error)")
        }
    }

    // MARK: - Sleep Log & Assessment Reminders REMOVED
    // Sleep log and assessment notifications are now handled by iPhone only

    // MARK: - Check-In Reminders (2x Daily - Simplified)

    /// Schedule check-in reminders - only midday and evening (2 total per day)
    /// Uses times synced from iPhone if available, otherwise defaults to 1 PM and 6 PM
    func scheduleCheckInReminders() {
        updateNotificationTimesFromSettings()
        print("[Notifications] Scheduled 2 daily check-in reminders (midday + evening)")
    }

    /// Update notification times from settings synced from iPhone
    func updateNotificationTimesFromSettings() {
        let defaults = UserDefaults.standard

        // Read synced times from iPhone (via WCSession)
        let middayHour = defaults.integer(forKey: "middayHour")
        let middayMinute = defaults.integer(forKey: "middayMinute")
        let eveningHour = defaults.integer(forKey: "eveningHour")
        let eveningMinute = defaults.integer(forKey: "eveningMinute")

        // Use defaults if not set (13:00 and 18:00)
        let finalMiddayHour = middayHour > 0 ? middayHour : 13
        let finalMiddayMinute = middayMinute >= 0 ? middayMinute : 0
        let finalEveningHour = eveningHour > 0 ? eveningHour : 18
        let finalEveningMinute = eveningMinute >= 0 ? eveningMinute : 0

        print("[Notifications] Using times - Midday: \(finalMiddayHour):\(String(format: "%02d", finalMiddayMinute)), Evening: \(finalEveningHour):\(String(format: "%02d", finalEveningMinute))")

        // Reschedule with new times
        scheduleMiddayCheckInReminder(hour: finalMiddayHour, minute: finalMiddayMinute)
        scheduleEveningCheckInReminder(hour: finalEveningHour, minute: finalEveningMinute)
    }

    private func scheduleMiddayCheckInReminder(hour: Int, minute: Int) {
        // Single midday check-in at specified time
        let notificationContent = EncouragementMessages.notificationContent(
            for: .midday,
            reminderNumber: 1
        )

        let content = UNMutableNotificationContent()
        content.title = notificationContent.title
        content.body = notificationContent.body
        content.sound = .default
        content.categoryIdentifier = "CHECKIN_MIDDAY"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

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
                print("[Notifications] Failed to schedule midday check-in: \(error)")
            } else {
                print("[Notifications] Scheduled midday at \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    private func scheduleEveningCheckInReminder(hour: Int, minute: Int) {
        // Single evening check-in at specified time
        let notificationContent = EncouragementMessages.notificationContent(
            for: .evening,
            reminderNumber: 1
        )

        let content = UNMutableNotificationContent()
        content.title = notificationContent.title
        content.body = notificationContent.body
        content.sound = .default
        content.categoryIdentifier = "CHECKIN_EVENING"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

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
                print("[Notifications] Failed to schedule evening check-in: \(error)")
            } else {
                print("[Notifications] Scheduled evening at \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    // MARK: - Energy Nudges REMOVED
    // Energy nudges removed to reduce notification overload

    // MARK: - Completion Handlers

    /// Call when sleep log is completed (no reminders to cancel since handled by iPhone)
    func markSleepLogComplete() {
        lastKnownSleepLogComplete = true
        // No Watch reminders to cancel - handled by iPhone
    }

    /// Call when assessment is completed (no reminders to cancel since handled by iPhone)
    func markAssessmentComplete() {
        lastKnownAssessmentComplete = true
        // No Watch reminders to cancel - handled by iPhone
    }

    /// Call when check-in is completed
    func markCheckInComplete(type: String, energy: Int, mood: Int, focus: Int, streak: Int) {
        cancelCheckInReminders(for: type)

        // Show personalized completion notification
        let content = UNMutableNotificationContent()
        content.title = streak > 1 ? EncouragementMessages.streakMessage(days: streak) : "Check-In Complete!"
        content.body = EncouragementMessages.personalizedMessage(energy: energy, mood: mood, focus: focus)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "checkin_success_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Call when full day is completed (all check-ins done)
    func markDayComplete() {
        lastKnownSleepLogComplete = true
        lastKnownAssessmentComplete = true

        // Show celebration notification
        let content = UNMutableNotificationContent()
        content.title = "All Check-Ins Complete!"
        content.body = EncouragementMessages.randomDayCompleteMessage()
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "day_complete_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Day Unlock

    /// Schedule day unlock notification at 4:00 AM
    func scheduleDayUnlockNotification() {
        let content = UNMutableNotificationContent()
        content.title = "New Day Unlocked!"
        content.body = "Ready for today's journey?"
        content.sound = nil  // Silent - just badge update

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

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Reset for New Day

    /// Reset completion tracking at midnight
    func resetForNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastResetKey = "lastNotificationReset"

        if let lastReset = UserDefaults.standard.object(forKey: lastResetKey) as? Date {
            let lastResetDay = Calendar.current.startOfDay(for: lastReset)
            if lastResetDay < today {
                // New day - reset tracking and reschedule
                lastKnownSleepLogComplete = false
                lastKnownAssessmentComplete = false
                UserDefaults.standard.set(today, forKey: lastResetKey)

                Task {
                    await scheduleAllNotifications()
                }
            }
        } else {
            UserDefaults.standard.set(today, forKey: lastResetKey)
        }
    }

    // MARK: - Cancellation

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("[Notifications] Cancelled all notifications")
    }

    private func cancelCheckInReminders(for type: String) {
        // Only 2 check-ins now: midday and evening
        let identifier = "checkin_\(type)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }

    func cancelCheckInReminders() {
        // Cancel both check-in notifications
        let identifiers = ["checkin_midday", "checkin_evening"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    // MARK: - Notification Categories

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
            title: "Later",
            options: []
        )

        // Check-in categories (only midday and evening now)
        let middayCategory = UNNotificationCategory(
            identifier: "CHECKIN_MIDDAY",
            actions: [checkInAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        let eveningCategory = UNNotificationCategory(
            identifier: "CHECKIN_EVENING",
            actions: [checkInAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            middayCategory,
            eveningCategory,
        ])

        print("[Notifications] Registered 2 notification categories (midday + evening)")
    }

    // MARK: - Debug

    func debugPrintScheduledNotifications() {
        Task {
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            print("[Notifications] === Scheduled Notifications (\(pending.count)) ===")
            for notification in pending.sorted(by: { $0.identifier < $1.identifier }) {
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
}
