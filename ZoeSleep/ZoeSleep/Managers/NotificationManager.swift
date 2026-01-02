//
//  NotificationManager.swift
//  ZoeSleep
//
//  Manages local notifications for treatment tasks, check-ins, and reminders.
//  Uses fixed circadian-aligned notification times to respect natural sleep-wake cycles.
//
//  Notification Schedule:
//  - 7:00 AM (Morning)   - Morning check-in + task preview
//  - 2:00 PM (Afternoon) - Mid-day reminder for incomplete tasks
//  - 7:00 PM (Evening)   - Evening block tasks reminder
//  - 10:00 PM (Bedtime)  - Final tasks + evening report
//
//  Smart As-Needed Reminders:
//  - Tasks overdue by >2 hours get a gentle reminder
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Types

enum NotificationType: String {
    case morningCheckIn = "morning_checkin"
    case afternoonReminder = "afternoon_reminder"
    case eveningReminder = "evening_reminder"
    case bedtimeReminder = "bedtime_reminder"
    case overdueTask = "overdue_task"
    case taskReminder = "task_reminder"
}

// MARK: - Notification Time Slot

struct NotificationTimeSlot {
    let hour: Int
    let minute: Int
    let type: NotificationType
    let title: String
    let bodyTemplate: String

    static let circadianSlots: [NotificationTimeSlot] = [
        NotificationTimeSlot(
            hour: 7, minute: 0,
            type: .morningCheckIn,
            title: "Good morning!",
            bodyTemplate: "Start your day right. Log how you slept and preview today's tasks."
        ),
        NotificationTimeSlot(
            hour: 14, minute: 0,
            type: .afternoonReminder,
            title: "Afternoon check-in",
            bodyTemplate: "You have %d tasks remaining for today. Keep up the momentum!"
        ),
        NotificationTimeSlot(
            hour: 19, minute: 0,
            type: .eveningReminder,
            title: "Evening reminder",
            bodyTemplate: "Time to wind down. %d evening tasks are waiting for you."
        ),
        NotificationTimeSlot(
            hour: 22, minute: 0,
            type: .bedtimeReminder,
            title: "Bedtime check-in",
            bodyTemplate: "Complete your evening report and prepare for a restful night."
        ),
    ]
}

// MARK: - NotificationManager

@MainActor
class NotificationManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Published State

    @Published var isAuthorized: Bool = false
    @Published var pendingNotifications: Int = 0

    // MARK: - Private Properties

    private let notificationCenter = UNUserNotificationCenter.current()
    private var hasRequestedAuthorization = false

    // MARK: - Initialization

    override init() {
        super.init()
        notificationCenter.delegate = self
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    /// Request notification permissions
    func requestAuthorization() async -> Bool {
        guard !hasRequestedAuthorization else {
            return isAuthorized
        }

        hasRequestedAuthorization = true

        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await notificationCenter.requestAuthorization(options: options)

            await MainActor.run {
                self.isAuthorized = granted
            }

            if granted {
                print("[Notifications] Authorization granted")
                await scheduleCircadianNotifications()
            } else {
                print("[Notifications] Authorization denied")
            }

            return granted
        } catch {
            print("[Notifications] Authorization error: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()

        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Circadian Notifications

    /// Schedule all circadian-timed notifications
    func scheduleCircadianNotifications() async {
        guard isAuthorized else {
            print("[Notifications] Not authorized, skipping scheduling")
            return
        }

        // Remove existing circadian notifications
        let identifiers = NotificationTimeSlot.circadianSlots.map { $0.type.rawValue }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)

        // Schedule each time slot
        for slot in NotificationTimeSlot.circadianSlots {
            await scheduleNotification(for: slot)
        }

        await updatePendingCount()
        print("[Notifications] Scheduled \(NotificationTimeSlot.circadianSlots.count) circadian notifications")
    }

    /// Schedule a notification for a specific time slot
    private func scheduleNotification(for slot: NotificationTimeSlot) async {
        let content = UNMutableNotificationContent()
        content.title = slot.title
        content.body = slot.bodyTemplate // Will be updated with dynamic data
        content.sound = .default
        content.categoryIdentifier = slot.type.rawValue

        // Create trigger for specific time daily
        var dateComponents = DateComponents()
        dateComponents.hour = slot.hour
        dateComponents.minute = slot.minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: slot.type.rawValue,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[Notifications] Error scheduling \(slot.type.rawValue): \(error)")
        }
    }

    // MARK: - Task-Specific Notifications

    /// Schedule a reminder for a specific task
    func scheduleTaskReminder(taskId: String, taskName: String, timing: String?, inMinutes: Int) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "Don't forget: \(taskName)"
        content.sound = .default
        content.categoryIdentifier = NotificationType.taskReminder.rawValue
        content.userInfo = ["taskId": taskId]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(inMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "task_\(taskId)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled reminder for task: \(taskName)")
        } catch {
            print("[Notifications] Error scheduling task reminder: \(error)")
        }

        await updatePendingCount()
    }

    /// Schedule an overdue task reminder
    func scheduleOverdueReminder(taskId: String, taskName: String, hoursOverdue: Int) async {
        guard isAuthorized, hoursOverdue >= 2 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Overdue"
        content.body = "\"\(taskName)\" is \(hoursOverdue) hours past its scheduled time."
        content.sound = .default
        content.categoryIdentifier = NotificationType.overdueTask.rawValue
        content.userInfo = ["taskId": taskId]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "overdue_\(taskId)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[Notifications] Error scheduling overdue reminder: \(error)")
        }

        await updatePendingCount()
    }

    // MARK: - Morning/Evening Check-in Notifications

    /// Update morning notification with today's task count
    func updateMorningNotification(taskCount: Int) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Good morning!"
        content.body = "You have \(taskCount) tasks scheduled for today. Start with your morning routine."
        content.sound = .default
        content.categoryIdentifier = NotificationType.morningCheckIn.rawValue

        var dateComponents = DateComponents()
        dateComponents.hour = 7
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: NotificationType.morningCheckIn.rawValue,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[Notifications] Error updating morning notification: \(error)")
        }
    }

    /// Update bedtime notification with pending task count
    func updateBedtimeNotification(pendingTasks: Int, completedTasks: Int) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Bedtime check-in"

        if pendingTasks == 0 {
            content.body = "Great job! You completed all \(completedTasks) tasks today. Time for your evening report."
        } else {
            content.body = "You have \(pendingTasks) tasks remaining. Complete what you can and log your evening report."
        }

        content.sound = .default
        content.categoryIdentifier = NotificationType.bedtimeReminder.rawValue

        var dateComponents = DateComponents()
        dateComponents.hour = 22
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: NotificationType.bedtimeReminder.rawValue,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[Notifications] Error updating bedtime notification: \(error)")
        }
    }

    // MARK: - Management

    /// Remove all pending notifications
    func removeAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        Task {
            await MainActor.run {
                self.pendingNotifications = 0
            }
        }
        print("[Notifications] Removed all notifications")
    }

    /// Remove notification for a specific task
    func removeTaskNotification(taskId: String) {
        let identifiers = ["task_\(taskId)", "overdue_\(taskId)"]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        Task {
            await updatePendingCount()
        }
    }

    /// Update pending notification count
    private func updatePendingCount() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        await MainActor.run {
            self.pendingNotifications = pending.count
        }
    }

    // MARK: - Daily Task Reminder (Intelligent)

    /// Notification identifier for daily task reminder
    private static let dailyTaskReminderID = "daily_task_reminder"

    /// UserDefaults keys for notification settings
    static let dailyReminderEnabledKey = "dailyReminderEnabled"
    static let dailyReminderHourKey = "dailyReminderHour"
    static let dailyReminderMinuteKey = "dailyReminderMinute"

    /// Schedule an intelligent daily task reminder
    /// The notification content is customized based on which tasks are still incomplete
    func scheduleDailyTaskReminder(enabled: Bool, hour: Int, minute: Int) async {
        guard isAuthorized else {
            print("[Notifications] Not authorized, skipping daily reminder")
            return
        }

        // Cancel existing daily reminder first
        cancelDailyTaskReminder()

        guard enabled else {
            print("[Notifications] Daily reminder disabled")
            return
        }

        // Save settings to UserDefaults
        UserDefaults.standard.set(enabled, forKey: Self.dailyReminderEnabledKey)
        UserDefaults.standard.set(hour, forKey: Self.dailyReminderHourKey)
        UserDefaults.standard.set(minute, forKey: Self.dailyReminderMinuteKey)

        let content = UNMutableNotificationContent()
        content.title = "Daily Tasks Reminder"
        content.body = "Time to check in! Complete your sleep log and daily tasks."
        content.sound = .default
        content.categoryIdentifier = NotificationType.morningCheckIn.rawValue
        // Add user info so we can update content dynamically when notification fires
        content.userInfo = ["type": "daily_task_reminder"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Self.dailyTaskReminderID,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled daily reminder at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("[Notifications] Error scheduling daily reminder: \(error)")
        }

        await updatePendingCount()
    }

    /// Schedule the daily reminder using saved settings from UserDefaults
    /// Call this on app launch to restore notification schedule
    func scheduleFromSavedSettings() async {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: Self.dailyReminderEnabledKey) as? Bool ?? true
        let hour = defaults.object(forKey: Self.dailyReminderHourKey) as? Int ?? 9
        let minute = defaults.object(forKey: Self.dailyReminderMinuteKey) as? Int ?? 0

        print("[Notifications] Scheduling from saved settings - enabled: \(enabled), time: \(hour):\(String(format: "%02d", minute))")
        await scheduleDailyTaskReminder(enabled: enabled, hour: hour, minute: minute)
    }

    /// Cancel daily task reminder
    func cancelDailyTaskReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.dailyTaskReminderID])
        print("[Notifications] Cancelled daily task reminder")
    }

    /// Send an immediate smart notification based on current task completion status
    /// Call this to send a notification that's aware of what tasks are incomplete
    func sendSmartDailyNotification(
        sleepLogCompleted: Bool,
        assessmentCompleted: Bool,
        hasExpansionPack: Bool,
        expansionCompleted: Bool
    ) async {
        guard isAuthorized else { return }

        // If everything is completed, don't send notification
        let expansionIncomplete = hasExpansionPack && !expansionCompleted
        let hasIncompleteTasks = !sleepLogCompleted || !assessmentCompleted || expansionIncomplete

        guard hasIncompleteTasks else {
            print("[Notifications] All tasks completed, skipping notification")
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = NotificationType.morningCheckIn.rawValue

        // Build smart message based on what's incomplete
        var incompleteTasks: [String] = []
        if !sleepLogCompleted {
            incompleteTasks.append("sleep log")
        }
        if !assessmentCompleted {
            incompleteTasks.append("assessment")
        }
        if expansionIncomplete {
            incompleteTasks.append("expansion pack")
        }

        // Customize title and body based on incomplete tasks
        if incompleteTasks.count == 1 {
            let task = incompleteTasks[0]
            content.title = "Complete your \(task)"
            content.body = "You still need to finish your \(task) for today."
        } else {
            content.title = "Daily Tasks Reminder"
            let taskList = incompleteTasks.joined(separator: ", ")
            content.body = "You have \(incompleteTasks.count) tasks remaining: \(taskList)."
        }

        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "smart_daily_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Sent smart notification for incomplete tasks: \(incompleteTasks)")
        } catch {
            print("[Notifications] Error sending smart notification: \(error)")
        }
    }

    // MARK: - Legacy Sleep Reminders (Deprecated)

    /// Notification identifiers for sleep reminders (deprecated, kept for migration)
    private static let morningSleepReminderID = "sleep_morning_reminder"
    private static let eveningSleepReminderID = "sleep_evening_reminder"

    /// Schedule custom morning and evening sleep reminders with user-defined times
    /// @deprecated Use scheduleDailyTaskReminder instead
    func scheduleSleepReminders(
        morningEnabled: Bool,
        morningHour: Int,
        morningMinute: Int,
        eveningEnabled: Bool,
        eveningHour: Int,
        eveningMinute: Int
    ) async {
        // Migrate to new single daily reminder system
        // Use morning time as the daily reminder time
        await scheduleDailyTaskReminder(enabled: morningEnabled, hour: morningHour, minute: morningMinute)
    }

    /// Cancel all custom sleep reminders
    func cancelSleepReminders() {
        let identifiers = [Self.morningSleepReminderID, Self.eveningSleepReminderID, Self.dailyTaskReminderID]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("[Notifications] Cancelled sleep reminders")
    }

    // MARK: - Badge Management

    /// Update app badge with pending task count
    func updateBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    /// Clear app badge
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound])
    }

    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let categoryIdentifier = response.notification.request.content.categoryIdentifier

        // Handle based on notification type
        switch categoryIdentifier {
        case NotificationType.morningCheckIn.rawValue:
            // Navigate to morning check-in
            NotificationCenter.default.post(name: .showMorningCheckIn, object: nil)

        case NotificationType.bedtimeReminder.rawValue:
            // Navigate to evening report
            NotificationCenter.default.post(name: .showEveningReport, object: nil)

        case NotificationType.taskReminder.rawValue, NotificationType.overdueTask.rawValue:
            // Navigate to specific task
            if let taskId = userInfo["taskId"] as? String {
                NotificationCenter.default.post(
                    name: .showTask,
                    object: nil,
                    userInfo: ["taskId": taskId]
                )
            }

        default:
            // Navigate to treatment view
            NotificationCenter.default.post(name: .showTreatment, object: nil)
        }

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showMorningCheckIn = Notification.Name("showMorningCheckIn")
    static let showEveningReport = Notification.Name("showEveningReport")
    static let showTask = Notification.Name("showTask")
    static let showTreatment = Notification.Name("showTreatment")
}
