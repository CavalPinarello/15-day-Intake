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

    // MARK: - Custom Sleep Reminders

    /// Notification identifiers for sleep reminders
    private static let morningSleepReminderID = "sleep_morning_reminder"
    private static let eveningSleepReminderID = "sleep_evening_reminder"

    /// Schedule custom morning and evening sleep reminders with user-defined times
    func scheduleSleepReminders(
        morningEnabled: Bool,
        morningHour: Int,
        morningMinute: Int,
        eveningEnabled: Bool,
        eveningHour: Int,
        eveningMinute: Int
    ) async {
        guard isAuthorized else {
            print("[Notifications] Not authorized, skipping sleep reminders")
            return
        }

        // Cancel existing sleep reminders first
        cancelSleepReminders()

        // Schedule morning reminder if enabled
        if morningEnabled {
            let morningContent = UNMutableNotificationContent()
            morningContent.title = "Good morning!"
            morningContent.body = "Time to log how you slept last night."
            morningContent.sound = .default
            morningContent.categoryIdentifier = NotificationType.morningCheckIn.rawValue

            var morningComponents = DateComponents()
            morningComponents.hour = morningHour
            morningComponents.minute = morningMinute

            let morningTrigger = UNCalendarNotificationTrigger(
                dateMatching: morningComponents,
                repeats: true
            )

            let morningRequest = UNNotificationRequest(
                identifier: Self.morningSleepReminderID,
                content: morningContent,
                trigger: morningTrigger
            )

            do {
                try await notificationCenter.add(morningRequest)
                print("[Notifications] Scheduled morning reminder at \(morningHour):\(String(format: "%02d", morningMinute))")
            } catch {
                print("[Notifications] Error scheduling morning reminder: \(error)")
            }
        }

        // Schedule evening reminder if enabled
        if eveningEnabled {
            let eveningContent = UNMutableNotificationContent()
            eveningContent.title = "Evening check-in"
            eveningContent.body = "Don't forget to complete your daily assessment."
            eveningContent.sound = .default
            eveningContent.categoryIdentifier = NotificationType.eveningReminder.rawValue

            var eveningComponents = DateComponents()
            eveningComponents.hour = eveningHour
            eveningComponents.minute = eveningMinute

            let eveningTrigger = UNCalendarNotificationTrigger(
                dateMatching: eveningComponents,
                repeats: true
            )

            let eveningRequest = UNNotificationRequest(
                identifier: Self.eveningSleepReminderID,
                content: eveningContent,
                trigger: eveningTrigger
            )

            do {
                try await notificationCenter.add(eveningRequest)
                print("[Notifications] Scheduled evening reminder at \(eveningHour):\(String(format: "%02d", eveningMinute))")
            } catch {
                print("[Notifications] Error scheduling evening reminder: \(error)")
            }
        }

        await updatePendingCount()
    }

    /// Cancel all custom sleep reminders
    func cancelSleepReminders() {
        let identifiers = [Self.morningSleepReminderID, Self.eveningSleepReminderID]
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
