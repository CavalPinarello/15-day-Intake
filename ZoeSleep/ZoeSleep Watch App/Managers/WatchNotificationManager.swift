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

    /// Schedule all notifications - checks Convex first to avoid unnecessary reminders
    func scheduleAllNotifications() async {
        guard isAuthorized else { return }

        // Fetch current completion status from Convex
        await refreshCompletionStatus()

        // Cancel all existing notifications and reschedule
        cancelAllNotifications()

        // Schedule based on what's NOT completed
        scheduleSleepLogReminders()
        scheduleAssessmentReminders()
        scheduleCheckInReminders()
        scheduleEnergyNudges()
        scheduleDayUnlockNotification()

        print("[Notifications] Scheduled all notifications (SleepLog=\(lastKnownSleepLogComplete), Assessment=\(lastKnownAssessmentComplete))")
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

    // MARK: - Sleep Log Reminders (Morning Focus)

    /// Schedule sleep log reminders - only if not completed
    private func scheduleSleepLogReminders() {
        // Don't schedule if already complete
        guard !lastKnownSleepLogComplete else {
            print("[Notifications] Sleep log already complete - skipping reminders")
            return
        }

        // Sleep log should be filled in the morning (best recall)
        // Schedule 3 reminders with increasing urgency
        let times: [(hour: Int, minute: Int)] = [
            (7, 30),   // First gentle reminder
            (9, 15),   // Second reminder
            (11, 0),   // Final reminder before noon
        ]

        for (index, time) in times.enumerated() {
            let reminderNumber = index + 1
            let message = EncouragementMessages.randomSleepLogReminder()

            let content = UNMutableNotificationContent()
            content.title = reminderNumber == 3 ? "Sleep Log Needed!" : "Sleep Log"
            content.body = message
            content.sound = reminderNumber >= 2 ? .default : nil
            content.categoryIdentifier = "SLEEP_LOG"

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "sleep_log_\(reminderNumber)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Notifications] Failed to schedule sleep log \(reminderNumber): \(error)")
                }
            }
        }
    }

    // MARK: - Assessment Reminders (Flexible Timing)

    /// Schedule assessment reminders - only if not completed
    private func scheduleAssessmentReminders() {
        // Don't schedule if already complete
        guard !lastKnownAssessmentComplete else {
            print("[Notifications] Assessment already complete - skipping reminders")
            return
        }

        // Assessment can be done anytime, but we want varied reminder times
        // These use semi-random times to feel less robotic
        let times: [(hour: Int, minute: Int)] = [
            (10, 45),  // Late morning
            (14, 20),  // Early afternoon
            (16, 35),  // Late afternoon
            (19, 10),  // Evening (before wind-down)
        ]

        for (index, time) in times.enumerated() {
            let reminderNumber = index + 1
            let message = EncouragementMessages.randomAssessmentReminder()

            let content = UNMutableNotificationContent()
            content.title = reminderNumber == 4 ? "Assessment Today!" : "Daily Questions"
            content.body = message
            content.sound = reminderNumber >= 3 ? .default : nil
            content.categoryIdentifier = "ASSESSMENT"

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "assessment_\(reminderNumber)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Notifications] Failed to schedule assessment \(reminderNumber): \(error)")
                }
            }
        }
    }

    // MARK: - Check-In Reminders (3x Daily)

    /// Schedule check-in reminders (morning, midday, evening)
    func scheduleCheckInReminders() {
        scheduleMorningCheckInReminders()
        scheduleMiddayCheckInReminders()
        scheduleEveningCheckInReminders()

        print("[Notifications] Scheduled 9 daily check-in reminders")
    }

    private func scheduleMorningCheckInReminders() {
        // Varied times to feel less robotic
        let times: [(hour: Int, minute: Int)] = [
            (7, 0),
            (8, 45),
            (10, 30),
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

    private func scheduleMiddayCheckInReminders() {
        let times: [(hour: Int, minute: Int)] = [
            (12, 30),
            (14, 15),
            (16, 45),
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

    private func scheduleEveningCheckInReminders() {
        // Sleep-friendly timing - no late night disturbances!
        let times: [(hour: Int, minute: Int)] = [
            (18, 0),
            (19, 20),
            (20, 15),  // Last reminder at 8:15 PM
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

    // MARK: - Energy Nudges (Varied Throughout Day)

    /// Schedule energy and wellness nudges at varied times
    private func scheduleEnergyNudges() {
        // Morning energy nudges (circadian light exposure)
        scheduleMorningEnergyNudges()

        // Afternoon energy nudges (movement, alertness)
        scheduleAfternoonEnergyNudges()

        // Evening wind-down nudges
        scheduleEveningWindDownNudges()

        print("[Notifications] Scheduled 6 daily energy nudges")
    }

    private func scheduleMorningEnergyNudges() {
        // Semi-random times in morning window
        let times: [(hour: Int, minute: Int)] = [
            (6, 45),   // Early - catch early risers
            (8, 20),   // Mid-morning - light exposure reminder
        ]

        for (index, time) in times.enumerated() {
            let message = EncouragementMessages.randomEnergyNudge(for: .morning)

            let content = UNMutableNotificationContent()
            content.title = "Energy Boost"
            content.body = message
            content.sound = nil  // Silent nudges
            content.categoryIdentifier = "ENERGY_NUDGE"

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "energy_morning_\(index + 1)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Notifications] Failed to schedule morning energy: \(error)")
                }
            }
        }
    }

    private func scheduleAfternoonEnergyNudges() {
        // Target the afternoon slump window
        let times: [(hour: Int, minute: Int)] = [
            (13, 45),  // Post-lunch slump
            (15, 30),  // Mid-afternoon dip
        ]

        for (index, time) in times.enumerated() {
            let message = EncouragementMessages.randomEnergyNudge(for: .afternoon)

            let content = UNMutableNotificationContent()
            content.title = "Afternoon Boost"
            content.body = message
            content.sound = nil
            content.categoryIdentifier = "ENERGY_NUDGE"

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "energy_afternoon_\(index + 1)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Notifications] Failed to schedule afternoon energy: \(error)")
                }
            }
        }
    }

    private func scheduleEveningWindDownNudges() {
        // Evening circadian wind-down reminders
        let times: [(hour: Int, minute: Int)] = [
            (19, 45),  // Pre-bedtime - dim lights
            (21, 0),   // Bedtime prep - blue light reminder
        ]

        for (index, time) in times.enumerated() {
            let message = EncouragementMessages.randomEnergyNudge(for: .evening)

            let content = UNMutableNotificationContent()
            content.title = "Wind Down"
            content.body = message
            content.sound = nil  // Silent for evening
            content.categoryIdentifier = "WIND_DOWN"

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "winddown_\(index + 1)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Notifications] Failed to schedule wind-down: \(error)")
                }
            }
        }
    }

    // MARK: - Completion Handlers

    /// Call when sleep log is completed - cancels remaining reminders
    func markSleepLogComplete() {
        lastKnownSleepLogComplete = true
        cancelSleepLogReminders()
        showCompletionNotification(type: "Sleep Log")
    }

    /// Call when assessment is completed - cancels remaining reminders
    func markAssessmentComplete() {
        lastKnownAssessmentComplete = true
        cancelAssessmentReminders()
        showCompletionNotification(type: "Assessment")
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

    /// Call when full day is completed
    func markDayComplete() {
        lastKnownSleepLogComplete = true
        lastKnownAssessmentComplete = true

        // Show celebration notification
        let content = UNMutableNotificationContent()
        content.title = "Day Complete!"
        content.body = EncouragementMessages.randomDayCompleteMessage()
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "day_complete_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)

        // Cancel all task reminders for today
        cancelSleepLogReminders()
        cancelAssessmentReminders()
    }

    private func showCompletionNotification(type: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(type) Complete!"
        content.body = EncouragementMessages.randomCompletionMessage()
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "\(type.lowercased())_complete_\(UUID().uuidString)",
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

    private func cancelSleepLogReminders() {
        let identifiers = (1...3).map { "sleep_log_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    private func cancelAssessmentReminders() {
        let identifiers = (1...4).map { "assessment_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    private func cancelCheckInReminders(for type: String) {
        let identifiers = (1...3).map { "checkin_\(type)_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    func cancelCheckInReminders() {
        let identifiers = [
            "checkin_morning_1", "checkin_morning_2", "checkin_morning_3",
            "checkin_midday_1", "checkin_midday_2", "checkin_midday_3",
            "checkin_evening_1", "checkin_evening_2", "checkin_evening_3",
        ]
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

        // Log action
        let logAction = UNNotificationAction(
            identifier: "LOG_ACTION",
            title: "Log Now",
            options: [.foreground]
        )

        // Snooze action
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Later",
            options: []
        )

        // Sleep Log category
        let sleepLogCategory = UNNotificationCategory(
            identifier: "SLEEP_LOG",
            actions: [logAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Assessment category
        let assessmentCategory = UNNotificationCategory(
            identifier: "ASSESSMENT",
            actions: [logAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Check-in categories
        let morningCategory = UNNotificationCategory(
            identifier: "CHECKIN_MORNING",
            actions: [checkInAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

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

        // Energy nudge category (no actions - passive reminder)
        let energyCategory = UNNotificationCategory(
            identifier: "ENERGY_NUDGE",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Wind-down category
        let windDownCategory = UNNotificationCategory(
            identifier: "WIND_DOWN",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            sleepLogCategory,
            assessmentCategory,
            morningCategory,
            middayCategory,
            eveningCategory,
            energyCategory,
            windDownCategory,
        ])

        print("[Notifications] Registered notification categories")
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
