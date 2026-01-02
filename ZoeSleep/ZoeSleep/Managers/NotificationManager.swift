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

    // Check-in nudge types (separate from daily task reminders)
    case morningCheckInNudge = "checkin_nudge_morning"
    case middayCheckInNudge = "checkin_nudge_midday"
    case eveningCheckInNudge = "checkin_nudge_evening"
}

// MARK: - Varied Notification Messages

/// 100 varied morning notification messages to prevent desensitization
struct NotificationMessages {
    static let morningMessages: [(title: String, body: String)] = [
        // Friendly greetings (1-20)
        ("Good morning!", "Time to log how you slept last night."),
        ("Rise and shine!", "Let's capture your sleep while it's fresh."),
        ("Morning!", "Quick sleep log to start your day right."),
        ("Hello there!", "Your sleep data is waiting to be recorded."),
        ("Hey!", "Don't forget to log last night's sleep."),
        ("Good morning!", "A minute now saves insights later."),
        ("Wakey wakey!", "Time for your daily sleep check-in."),
        ("Top of the morning!", "Let's see how you slept."),
        ("Morning sunshine!", "Your sleep log awaits."),
        ("Hello!", "Start your day by logging your sleep."),
        ("Good day!", "Quick check-in about last night?"),
        ("Greetings!", "Your sleep tracker is ready for you."),
        ("Hey there!", "Log your sleep while you remember it."),
        ("Morning!", "Better sleep starts with tracking."),
        ("Hi!", "Ready to log your sleep?"),
        ("Good morning!", "Your daily sleep log is due."),
        ("Hello!", "Take a moment to track your rest."),
        ("Hey!", "How did you sleep? Let's find out."),
        ("Morning!", "Time to record your sleep patterns."),
        ("Rise and log!", "Capture last night's sleep data."),

        // Motivational (21-40)
        ("You've got this!", "A quick sleep log helps build better habits."),
        ("One step at a time", "Log your sleep to stay on track."),
        ("Small steps matter", "Your sleep log takes just a minute."),
        ("Keep the streak!", "Don't break your logging momentum."),
        ("Progress awaits", "Track your sleep to see improvements."),
        ("Stay consistent", "Daily logging leads to better insights."),
        ("You're doing great!", "Keep up with your sleep tracking."),
        ("Every day counts", "Log today for a healthier tomorrow."),
        ("Build the habit", "Just 60 seconds to log your sleep."),
        ("Stay on track", "Your sleep journey continues today."),
        ("Keep it up!", "Another day, another sleep log."),
        ("Consistency wins", "Log now while it's fresh in mind."),
        ("Make it count", "Your sleep data matters."),
        ("One more day", "Add today's sleep to your record."),
        ("Stay strong", "Sleep tracking builds awareness."),
        ("Daily wins", "Logging sleep is a form of self-care."),
        ("Keep going!", "Your future self will thank you."),
        ("Almost there", "Complete your morning check-in."),
        ("You can do it!", "Quick sleep log for the day."),
        ("Stay committed", "Track sleep, transform your nights."),

        // Curious/Question-based (41-60)
        ("How'd you sleep?", "Let's find out and track it."),
        ("Sleep well?", "Log it now while you remember."),
        ("Rest easy?", "Your sleep log is waiting."),
        ("Good rest?", "Share how last night went."),
        ("Dreams or nightmares?", "Record your sleep experience."),
        ("Feeling rested?", "Log your sleep quality today."),
        ("Slept enough?", "Track it to know for sure."),
        ("Quality rest?", "Your sleep data tells the story."),
        ("How was last night?", "Time to log your sleep."),
        ("Well rested?", "Record your sleep now."),
        ("Sleep soundly?", "Let's capture that data."),
        ("Good night's sleep?", "Log it before you forget."),
        ("Feel refreshed?", "Track your rest for insights."),
        ("Sleep through?", "Your log helps spot patterns."),
        ("Wake up rested?", "Share your sleep quality."),
        ("Peaceful night?", "Log how you slept."),
        ("Restful sleep?", "Time for your check-in."),
        ("Sleep deeply?", "Record your rest now."),
        ("How many hours?", "Log your sleep duration."),
        ("Sleep score?", "Let's see how you did."),

        // Health-focused (61-80)
        ("Sleep matters", "Track it to improve it."),
        ("Better sleep awaits", "Start by logging today."),
        ("Health check", "Your sleep affects everything."),
        ("Wellness moment", "Log your sleep for better health."),
        ("Self-care time", "Track your rest patterns."),
        ("For your health", "A minute to log your sleep."),
        ("Sleep health", "Tracking is the first step."),
        ("Feel better", "Know your sleep, improve your days."),
        ("Energy check", "How you slept affects your day."),
        ("Vitality boost", "Good sleep tracking leads to good sleep."),
        ("Rest recovery", "Log your sleep to optimize rest."),
        ("Body check-in", "Your sleep data tells a story."),
        ("Mind & body", "Track sleep for overall wellness."),
        ("Recharge status", "How did your body rest?"),
        ("Recovery time", "Log your sleep quality."),
        ("Wellness log", "Track your nightly recovery."),
        ("Health journal", "Add your sleep entry."),
        ("Body awareness", "Know your sleep patterns."),
        ("Rest report", "Submit your sleep log."),
        ("Sleep science", "Data drives improvement."),

        // Short and punchy (81-100)
        ("Log time!", "Your sleep data awaits."),
        ("Sleep check!", "Quick log for the morning."),
        ("Track it!", "Log your sleep now."),
        ("Don't forget!", "Your sleep log is due."),
        ("Quick check!", "Sleep log in under a minute."),
        ("Reminder!", "Time to track your sleep."),
        ("Daily log!", "Record last night's sleep."),
        ("Check in!", "Your sleep tracker needs you."),
        ("Log now!", "While it's fresh in your mind."),
        ("Sleep time!", "Well, logging time actually."),
        ("Rise & log!", "Morning sleep check-in."),
        ("Wake & track!", "Log your sleep data."),
        ("New day!", "Start with your sleep log."),
        ("Fresh start!", "Log yesterday's sleep."),
        ("Day one!", "Well, another one. Log it!"),
        ("Track now!", "Your sleep insights await."),
        ("Quick task!", "Log your sleep quality."),
        ("Easy win!", "Complete your sleep log."),
        ("2 minutes!", "That's all for your log."),
        ("Tap here!", "To log last night's sleep."),
    ]

    static let eveningMessages: [(title: String, body: String)] = [
        // Gentle reminders (1-20)
        ("Evening check-in", "Still time to complete your tasks."),
        ("Gentle reminder", "Your daily tasks await."),
        ("Before bed", "Complete your tasks for today."),
        ("Evening nudge", "Don't forget your daily check-in."),
        ("Night reminder", "A few tasks left for today."),
        ("Wind down time", "Finish up your daily tasks."),
        ("Evening heads-up", "Your tasks are waiting."),
        ("Twilight reminder", "Complete today's check-in."),
        ("Dusk check-in", "Time to wrap up tasks."),
        ("Night owl?", "Your tasks are still pending."),
        ("Last call", "Complete your daily tasks."),
        ("Before you sleep", "Finish your check-in first."),
        ("Evening alert", "Tasks incomplete for today."),
        ("Night nudge", "Quick tasks before bed."),
        ("Sunset reminder", "Your daily tasks await."),
        ("Evening check", "Complete your pending tasks."),
        ("Night time", "Don't forget your check-in."),
        ("Moon rise", "Time to finish today's tasks."),
        ("Starlight reminder", "Tasks still pending."),
        ("Evening glow", "Complete your daily routine."),

        // Encouraging (21-40)
        ("Almost done!", "Just a few tasks left today."),
        ("You're close!", "Finish strong with your tasks."),
        ("Final stretch!", "Complete your daily check-in."),
        ("Nearly there!", "Tasks waiting for completion."),
        ("One more effort!", "Your tasks need you."),
        ("Finish strong!", "Complete today's check-in."),
        ("End on a high!", "Wrap up your daily tasks."),
        ("Victory awaits!", "Complete your tasks now."),
        ("You've got time!", "Finish your check-in today."),
        ("Still possible!", "Complete your pending tasks."),
        ("Make it count!", "Finish today's tasks."),
        ("Close the day!", "With your tasks complete."),
        ("Round it off!", "Complete your daily routine."),
        ("Seal the day!", "With a finished check-in."),
        ("Cap it off!", "Complete your pending tasks."),
        ("Day's end!", "Time to finish tasks."),
        ("Final push!", "Your tasks await completion."),
        ("Home stretch!", "Complete your check-in."),
        ("Last lap!", "Finish your daily tasks."),
        ("Sprint finish!", "Complete tasks before bed."),

        // Practical (41-60)
        ("Tasks pending", "Complete them before midnight."),
        ("Incomplete tasks", "Finish them while you remember."),
        ("Check-in needed", "Your daily tasks await."),
        ("Action required", "Complete your pending tasks."),
        ("Tasks outstanding", "Time to finish them up."),
        ("Pending items", "Your check-in isn't complete."),
        ("Unfinished business", "Complete your tasks today."),
        ("Open tasks", "Close them before bed."),
        ("Awaiting completion", "Your daily check-in."),
        ("Tasks remain", "Complete them now."),
        ("Not done yet", "Finish your daily tasks."),
        ("Still pending", "Your check-in awaits."),
        ("Needs attention", "Your daily tasks."),
        ("Incomplete", "Finish your check-in today."),
        ("Outstanding", "Tasks need completion."),
        ("Remaining tasks", "Complete before you rest."),
        ("Left to do", "Your daily check-in."),
        ("Still open", "Tasks awaiting you."),
        ("Unfinished", "Complete your daily routine."),
        ("To be done", "Your tasks for today."),

        // Sleep-focused (61-80)
        ("Before you rest", "Complete your check-in."),
        ("Pre-sleep tasks", "Finish up for better rest."),
        ("Sleep prep", "Complete tasks, then rest."),
        ("Rest awaits", "After you finish your tasks."),
        ("Better sleep", "Starts with completing tasks."),
        ("Wind down", "After your check-in is done."),
        ("Peaceful night", "Complete your tasks first."),
        ("Sleep soon?", "Finish your check-in first."),
        ("Bedtime prep", "Complete your daily tasks."),
        ("Night routine", "Don't skip your check-in."),
        ("Rest ready?", "Complete tasks first."),
        ("Pre-bed reminder", "Tasks still pending."),
        ("Sleep starts", "With a completed check-in."),
        ("Ready for bed?", "Finish your tasks first."),
        ("Night prep", "Complete your daily tasks."),
        ("Sleep setup", "Finish your check-in."),
        ("Rest mode", "Activate after completing tasks."),
        ("Night time tasks", "Complete before sleeping."),
        ("Bedtime checklist", "Tasks still incomplete."),
        ("Pre-sleep check", "Finish your daily tasks."),

        // Short and direct (81-100)
        ("Check in!", "Evening tasks await."),
        ("Don't forget!", "Tasks still pending."),
        ("Last chance!", "Complete tasks today."),
        ("Time's ticking!", "Finish your check-in."),
        ("Act now!", "Tasks need completion."),
        ("Quick reminder!", "Evening tasks due."),
        ("Heads up!", "Tasks incomplete."),
        ("Alert!", "Daily tasks pending."),
        ("Notice!", "Check-in not complete."),
        ("Ping!", "Your tasks await."),
        ("Evening!", "Tasks still open."),
        ("Reminder!", "Complete your check-in."),
        ("Task time!", "Finish before bed."),
        ("Check it!", "Your pending tasks."),
        ("Wrap up!", "Today's tasks await."),
        ("Close out!", "Your daily check-in."),
        ("Finish!", "Tasks need you."),
        ("Complete!", "Your daily tasks."),
        ("Quick!", "Finish your check-in."),
        ("Now!", "Complete pending tasks."),
    ]

    /// Get a random morning message
    static func randomMorningMessage() -> (title: String, body: String) {
        return morningMessages.randomElement() ?? morningMessages[0]
    }

    /// Get a random evening message
    static func randomEveningMessage() -> (title: String, body: String) {
        return eveningMessages.randomElement() ?? eveningMessages[0]
    }
}

// MARK: - Check-In Nudge Messages (100 unique prompts)

/// 100 varied check-in nudge messages for morning/midday/evening energy-mood-focus check-ins
struct CheckInNudgeMessages {

    // MARK: - Morning Check-In Prompts (35)
    static let morningPrompts: [(title: String, body: String)] = [
        // Energy-focused (1-12)
        ("How's your battery?", "Quick energy check after last night's sleep."),
        ("Energy level?", "Rate how charged you feel this morning."),
        ("Morning energy check", "How's your tank after sleeping?"),
        ("Feeling charged?", "10-second energy level check-in."),
        ("Battery status?", "How energized are you this morning?"),
        ("Energy report", "Quick check: how's your power level?"),
        ("Rise & report", "Tell us about your morning energy."),
        ("Morning vitality", "Quick check on your energy levels."),
        ("Power check", "How's your energy right now?"),
        ("Fuel gauge", "Rate your morning energy level."),
        ("Energy snapshot", "Quick morning energy reading."),
        ("Wake-up power", "How energized do you feel?"),

        // Mood-focused (13-24)
        ("Morning mood?", "Sunny or stormy? Quick check-in."),
        ("How are you feeling?", "Morning mood check - takes 10 seconds."),
        ("Mood check", "How's your emotional weather today?"),
        ("Morning vibes", "What's your mood like right now?"),
        ("Feeling check", "Quick mood snapshot for the morning."),
        ("Emotional pulse", "How are you feeling this AM?"),
        ("Sunrise mood", "Rate your morning emotional state."),
        ("Morning outlook", "How optimistic are you feeling?"),
        ("Mood meter", "Quick check on your feelings."),
        ("AM mood check", "Tell us how you're feeling."),
        ("Morning feels", "What's your mood this morning?"),
        ("Emotional check-in", "Quick morning mood reading."),

        // Focus-focused (25-35)
        ("Mental clarity?", "How sharp is your focus this morning?"),
        ("Focus check", "Rate your mental clarity level."),
        ("Brain fog?", "Quick focus level check-in."),
        ("Morning sharpness", "How clear is your thinking?"),
        ("Clarity check", "Mental focus snapshot."),
        ("Concentration level?", "How focused do you feel?"),
        ("Mind check", "Rate your morning mental clarity."),
        ("Focus fuel", "How's your concentration today?"),
        ("Mental energy", "Quick focus level reading."),
        ("Thinking clearly?", "Morning mental clarity check."),
        ("Cognitive check", "How's your brain power?"),
    ]

    // MARK: - Midday Check-In Prompts (35)
    static let middayPrompts: [(title: String, body: String)] = [
        // Energy-focused (1-12)
        ("Midday energy?", "How's your afternoon power level?"),
        ("Afternoon slump?", "Quick energy check-in."),
        ("Energy update", "How's your fuel holding up?"),
        ("Post-lunch power", "Rate your current energy."),
        ("Afternoon vitality", "Quick energy snapshot."),
        ("Still going strong?", "Midday energy check."),
        ("Energy status", "How charged do you feel now?"),
        ("PM power check", "Rate your afternoon energy."),
        ("Midday recharge?", "How's your energy level?"),
        ("Afternoon battery", "Quick power level check."),
        ("Sustained energy?", "Midday energy reading."),
        ("Afternoon fuel", "How energized are you?"),

        // Mood-focused (13-24)
        ("Afternoon mood?", "Quick midday emotional check."),
        ("How's the day going?", "Mood check for the afternoon."),
        ("Midday feelings", "Rate your current mood."),
        ("Afternoon vibes", "How are you feeling now?"),
        ("PM mood check", "Quick emotional snapshot."),
        ("Day so far?", "Tell us about your mood."),
        ("Afternoon pulse", "How's your emotional state?"),
        ("Midday outlook", "Still feeling positive?"),
        ("Feelings update", "Quick afternoon mood check."),
        ("Current mood?", "Midday emotional reading."),
        ("Afternoon feels", "How are you feeling?"),
        ("Mood snapshot", "Quick check on your feelings."),

        // Focus-focused (25-35)
        ("Afternoon focus?", "How's your concentration?"),
        ("Still sharp?", "Midday mental clarity check."),
        ("Focus holding?", "Rate your concentration level."),
        ("Mental stamina", "How's your focus this afternoon?"),
        ("Clarity update", "Quick focus snapshot."),
        ("Concentration check", "How sharp are you feeling?"),
        ("PM focus level", "Rate your mental clarity."),
        ("Brain power?", "Afternoon focus reading."),
        ("Thinking clearly?", "Midday concentration check."),
        ("Mental energy?", "How's your focus holding up?"),
        ("Cognitive status", "Quick clarity check-in."),
    ]

    // MARK: - Evening Check-In Prompts (30)
    static let eveningPrompts: [(title: String, body: String)] = [
        // Energy-focused (1-10)
        ("Evening energy?", "How's your battery after today?"),
        ("End of day power", "Rate your remaining energy."),
        ("Winding down?", "Quick evening energy check."),
        ("Today's toll?", "How much energy is left?"),
        ("Evening fuel", "Rate your current power level."),
        ("Day's end energy", "How depleted are you feeling?"),
        ("Battery after today", "Quick energy reading."),
        ("PM power level", "How energized do you feel?"),
        ("Evening vitality", "Rate your remaining fuel."),
        ("Tired yet?", "Quick evening energy check."),

        // Mood-focused (11-20)
        ("Evening mood?", "How are you feeling tonight?"),
        ("Day's end feelings", "Quick mood check-in."),
        ("How was today?", "Rate your evening mood."),
        ("End-of-day vibes", "Tell us how you're feeling."),
        ("Evening outlook", "Mood snapshot for tonight."),
        ("Night feelings", "Quick emotional check-in."),
        ("PM mood check", "How's your evening mood?"),
        ("Sunset mood", "Rate your current feelings."),
        ("Today's wrap-up", "How are you feeling now?"),
        ("Evening pulse", "Quick mood reading."),

        // Focus-focused (21-30)
        ("Evening clarity?", "How's your mental state?"),
        ("Still focused?", "End-of-day concentration check."),
        ("Mental state?", "Rate your evening clarity."),
        ("Brain tired?", "Quick focus level check."),
        ("PM clarity", "How's your thinking tonight?"),
        ("Evening focus", "Rate your mental energy."),
        ("Cognitive wind-down", "Focus snapshot for tonight."),
        ("Mind check", "How clear is your thinking?"),
        ("Evening sharpness", "Quick concentration reading."),
        ("Mental wrap-up", "How's your focus this evening?"),
    ]

    /// Get a random morning check-in prompt
    static func randomMorningPrompt() -> (title: String, body: String) {
        return morningPrompts.randomElement() ?? morningPrompts[0]
    }

    /// Get a random midday check-in prompt
    static func randomMiddayPrompt() -> (title: String, body: String) {
        return middayPrompts.randomElement() ?? middayPrompts[0]
    }

    /// Get a random evening check-in prompt
    static func randomEveningPrompt() -> (title: String, body: String) {
        return eveningPrompts.randomElement() ?? eveningPrompts[0]
    }
}

// MARK: - Sleep Task Messages (50 unique prompts)

/// 50 varied prompts for sleep log and assessment reminders
struct SleepTaskMessages {

    // MARK: - Sleep Log Prompts (25)
    static let sleepLogPrompts: [(title: String, body: String)] = [
        // Friendly (1-10)
        ("Sleep log time!", "Record how you slept last night."),
        ("Log your rest", "Quick sleep diary entry."),
        ("Sleep diary", "How was last night's sleep?"),
        ("Rest report", "Tell us about your sleep."),
        ("Night recap", "Log your sleep quality."),
        ("Sleep check", "Record your rest data."),
        ("Morning log", "How did you sleep?"),
        ("Sleep entry", "Add today's sleep data."),
        ("Rest tracker", "Log your sleep now."),
        ("Sleep snapshot", "Quick sleep log entry."),

        // Question-based (11-18)
        ("How'd you sleep?", "Log it while it's fresh."),
        ("Sleep well?", "Record your rest quality."),
        ("Good rest?", "Tell us about your night."),
        ("Restful night?", "Log your sleep experience."),
        ("Sleep through?", "Record any wake-ups."),
        ("Dreams or disruptions?", "Log your sleep."),
        ("Quality rest?", "Add your sleep data."),
        ("Enough sleep?", "Log your hours and quality."),

        // Motivational (19-25)
        ("Track to improve", "Log your sleep patterns."),
        ("Data drives better sleep", "Record last night."),
        ("Consistency matters", "Log your sleep now."),
        ("Better sleep starts here", "Add your log."),
        ("One step to better rest", "Log your sleep."),
        ("Building your sleep profile", "Add today's data."),
        ("Progress through tracking", "Sleep log time."),
    ]

    // MARK: - Assessment Prompts (25)
    static let assessmentPrompts: [(title: String, body: String)] = [
        // Friendly (1-10)
        ("Daily assessment", "Complete your questions."),
        ("Quick questionnaire", "A few questions for today."),
        ("Assessment time", "Help us learn more."),
        ("Daily check-in", "Complete your assessment."),
        ("Questions ready", "Your daily assessment awaits."),
        ("Health check", "Complete today's questions."),
        ("Wellness assessment", "Quick questionnaire."),
        ("Progress check", "Daily questions ready."),
        ("Insight builder", "Complete your assessment."),
        ("Profile update", "Answer today's questions."),

        // Purpose-focused (11-18)
        ("Personalize your care", "Complete assessment."),
        ("Help us help you", "Daily questions ready."),
        ("Unlock insights", "Complete your assessment."),
        ("Tailored guidance", "Answer today's questions."),
        ("Better recommendations", "Assessment time."),
        ("Understanding you", "Complete your questions."),
        ("Customized care", "Daily assessment ready."),
        ("Your sleep profile", "Add more insights."),

        // Short (19-25)
        ("Assessment!", "Quick questions for today."),
        ("Questions ready!", "Complete your daily check."),
        ("Check-in time!", "Daily assessment due."),
        ("Your turn!", "Complete the assessment."),
        ("Quick check!", "Daily questions waiting."),
        ("Almost done!", "Just the assessment left."),
        ("Last task!", "Complete your assessment."),
    ]

    /// Get a random sleep log prompt
    static func randomSleepLogPrompt() -> (title: String, body: String) {
        return sleepLogPrompts.randomElement() ?? sleepLogPrompts[0]
    }

    /// Get a random assessment prompt
    static func randomAssessmentPrompt() -> (title: String, body: String) {
        return assessmentPrompts.randomElement() ?? assessmentPrompts[0]
    }

    /// Get a combined task prompt (sleep log + assessment)
    static func randomCombinedPrompt() -> (title: String, body: String) {
        let combinedPrompts: [(title: String, body: String)] = [
            ("Daily tasks ready", "Sleep log and assessment await."),
            ("Morning to-do", "Log your sleep and complete assessment."),
            ("Two quick tasks", "Sleep diary and daily questions."),
            ("Complete your day", "Sleep log + assessment ready."),
            ("Health check time", "Log sleep and answer questions."),
        ]
        return combinedPrompts.randomElement() ?? combinedPrompts[0]
    }
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

    // MARK: - Daily Task Reminders (Intelligent)

    /// Notification identifiers for daily task reminders
    private static let morningReminderID = "morning_task_reminder"
    private static let eveningReminderID = "evening_task_reminder"

    /// UserDefaults keys for notification settings
    static let dailyReminderEnabledKey = "dailyReminderEnabled"
    static let dailyReminderHourKey = "dailyReminderHour"
    static let dailyReminderMinuteKey = "dailyReminderMinute"
    static let eveningReminderEnabledKey = "eveningReminderEnabled"
    static let eveningReminderHourKey = "eveningReminderHour"
    static let eveningReminderMinuteKey = "eveningReminderMinute"

    /// Schedule an intelligent morning task reminder
    /// The notification content is customized based on which tasks are still incomplete
    func scheduleDailyTaskReminder(enabled: Bool, hour: Int, minute: Int) async {
        guard isAuthorized else {
            print("[Notifications] Not authorized, skipping morning reminder")
            return
        }

        // Cancel existing morning reminder first
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.morningReminderID])

        guard enabled else {
            print("[Notifications] Morning reminder disabled")
            return
        }

        // Save settings to UserDefaults
        UserDefaults.standard.set(enabled, forKey: Self.dailyReminderEnabledKey)
        UserDefaults.standard.set(hour, forKey: Self.dailyReminderHourKey)
        UserDefaults.standard.set(minute, forKey: Self.dailyReminderMinuteKey)

        // Use random message for variety
        let randomMessage = NotificationMessages.randomMorningMessage()

        let content = UNMutableNotificationContent()
        content.title = randomMessage.title
        content.body = randomMessage.body
        content.sound = .default
        content.categoryIdentifier = NotificationType.morningCheckIn.rawValue
        content.userInfo = ["type": "morning_task_reminder"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Self.morningReminderID,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled morning reminder at \(hour):\(String(format: "%02d", minute)) - '\(randomMessage.title)'")
        } catch {
            print("[Notifications] Error scheduling morning reminder: \(error)")
        }

        await updatePendingCount()
    }

    /// Schedule an intelligent evening task reminder (follow-up if tasks incomplete)
    func scheduleEveningReminder(enabled: Bool, hour: Int, minute: Int) async {
        guard isAuthorized else {
            print("[Notifications] Not authorized, skipping evening reminder")
            return
        }

        // Cancel existing evening reminder first
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.eveningReminderID])

        guard enabled else {
            print("[Notifications] Evening reminder disabled")
            return
        }

        // Save settings to UserDefaults
        UserDefaults.standard.set(enabled, forKey: Self.eveningReminderEnabledKey)
        UserDefaults.standard.set(hour, forKey: Self.eveningReminderHourKey)
        UserDefaults.standard.set(minute, forKey: Self.eveningReminderMinuteKey)

        // Use random message for variety
        let randomMessage = NotificationMessages.randomEveningMessage()

        let content = UNMutableNotificationContent()
        content.title = randomMessage.title
        content.body = randomMessage.body
        content.sound = .default
        content.categoryIdentifier = NotificationType.eveningReminder.rawValue
        content.userInfo = ["type": "evening_task_reminder"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Self.eveningReminderID,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled evening reminder at \(hour):\(String(format: "%02d", minute)) - '\(randomMessage.title)'")
        } catch {
            print("[Notifications] Error scheduling evening reminder: \(error)")
        }

        await updatePendingCount()
    }

    /// Schedule both reminders using saved settings from UserDefaults
    /// Call this on app launch to restore notification schedule
    func scheduleFromSavedSettings() async {
        let defaults = UserDefaults.standard

        // Morning reminder
        let morningEnabled = defaults.object(forKey: Self.dailyReminderEnabledKey) as? Bool ?? true
        let morningHour = defaults.object(forKey: Self.dailyReminderHourKey) as? Int ?? 9
        let morningMinute = defaults.object(forKey: Self.dailyReminderMinuteKey) as? Int ?? 0

        print("[Notifications] Scheduling from saved settings - morning: \(morningEnabled) at \(morningHour):\(String(format: "%02d", morningMinute))")
        await scheduleDailyTaskReminder(enabled: morningEnabled, hour: morningHour, minute: morningMinute)

        // Evening reminder
        let eveningEnabled = defaults.object(forKey: Self.eveningReminderEnabledKey) as? Bool ?? true
        let eveningHour = defaults.object(forKey: Self.eveningReminderHourKey) as? Int ?? 20
        let eveningMinute = defaults.object(forKey: Self.eveningReminderMinuteKey) as? Int ?? 0

        print("[Notifications] Scheduling from saved settings - evening: \(eveningEnabled) at \(eveningHour):\(String(format: "%02d", eveningMinute))")
        await scheduleEveningReminder(enabled: eveningEnabled, hour: eveningHour, minute: eveningMinute)
    }

    /// Cancel all daily task reminders (morning and evening)
    func cancelDailyTaskReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.morningReminderID, Self.eveningReminderID])
        print("[Notifications] Cancelled all daily task reminders")
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
    private static let dailyTaskReminderID = "daily_task_reminder"

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
    static let checkInStatusDidChange = Notification.Name("checkInStatusDidChange")
    static let showWatchStyleCheckIn = Notification.Name("showWatchStyleCheckIn")
}
