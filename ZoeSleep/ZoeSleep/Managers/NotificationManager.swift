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

    // Specific task types for deep linking
    case sleepLogReminder = "sleep_log_reminder"
    case assessmentReminder = "assessment_reminder"

    // Check-in nudge types (separate from daily task reminders)
    case morningCheckInNudge = "checkin_nudge_morning"
    case middayCheckInNudge = "checkin_nudge_midday"
    case eveningCheckInNudge = "checkin_nudge_evening"
}

// MARK: - Varied Notification Messages

/// 100 varied morning notification messages for sleep log and assessment only
struct NotificationMessages {
    static let morningMessages: [(title: String, body: String)] = [
        // Friendly greetings (1-20)
        ("Good morning!", "Time to log your sleep and answer today's questions."),
        ("Rise and shine!", "Sleep log and assessment ready for you."),
        ("Morning!", "Quick sleep log and daily questions."),
        ("Hello there!", "Log your sleep and complete today's assessment."),
        ("Hey!", "Sleep log and daily questions await."),
        ("Good morning!", "Two quick tasks: sleep log and assessment."),
        ("Wakey wakey!", "Log last night and answer a few questions."),
        ("Top of the morning!", "Sleep log and assessment time."),
        ("Morning sunshine!", "Ready to log your sleep and assessment?"),
        ("Hello!", "Start with your sleep log and daily questions."),
        ("Good day!", "Sleep log and assessment for today."),
        ("Greetings!", "Log your sleep and complete the assessment."),
        ("Hey there!", "Sleep log and questions while it's fresh."),
        ("Morning!", "Two tasks: sleep log and assessment."),
        ("Hi!", "Ready to log sleep and answer questions?"),
        ("Good morning!", "Sleep log and daily assessment due."),
        ("Hello!", "Log your rest and complete the assessment."),
        ("Hey!", "Sleep log and daily questions ready."),
        ("Morning!", "Track your sleep and answer today's questions."),
        ("Rise and log!", "Sleep data and assessment await."),

        // Motivational (21-40)
        ("You've got this!", "Sleep log and assessment ready."),
        ("One step at a time", "Log your sleep and answer questions."),
        ("Small steps matter", "Two quick tasks this morning."),
        ("Keep the streak!", "Sleep log and assessment time."),
        ("Progress awaits", "Log sleep and complete the assessment."),
        ("Stay consistent", "Daily tasks lead to better insights."),
        ("You're doing great!", "Keep up with sleep log and questions."),
        ("Every day counts", "Log and assess for better health."),
        ("Build the habit", "Sleep log and assessment ready."),
        ("Stay on track", "Two morning tasks await you."),
        ("Keep it up!", "Sleep log and daily questions."),
        ("Consistency wins", "Log sleep and answer questions now."),
        ("Make it count", "Your sleep data and insights matter."),
        ("One more day", "Sleep log and assessment time."),
        ("Stay strong", "Log your sleep and complete questions."),
        ("Daily wins", "Sleep log and assessment for today."),
        ("Keep going!", "Two quick tasks for better insights."),
        ("Almost there", "Complete sleep log and assessment."),
        ("You can do it!", "Sleep log and questions ready."),
        ("Stay committed", "Track and assess for better nights."),

        // Curious/Question-based (41-60)
        ("How'd you sleep?", "Log it and answer today's questions."),
        ("Sleep well?", "Log and complete the assessment."),
        ("Rest easy?", "Sleep log and questions await."),
        ("Good rest?", "Share how you slept and answer questions."),
        ("Dreams or nightmares?", "Log sleep and complete assessment."),
        ("Feeling rested?", "Log sleep quality and answer questions."),
        ("Slept enough?", "Track it and complete the assessment."),
        ("Quality rest?", "Log your sleep and answer questions."),
        ("How was last night?", "Time to log and assess."),
        ("Well rested?", "Record sleep and answer questions."),
        ("Sleep soundly?", "Log data and complete assessment."),
        ("Good night's sleep?", "Log and answer before you forget."),
        ("Feel refreshed?", "Track sleep and complete questions."),
        ("Sleep through?", "Log helps patterns, questions help care."),
        ("Wake up rested?", "Share sleep quality and assessment."),
        ("Peaceful night?", "Log sleep and answer questions."),
        ("Restful sleep?", "Time for sleep log and assessment."),
        ("Sleep deeply?", "Record sleep and complete questions."),
        ("How many hours?", "Log duration and answer questions."),
        ("Sleep score?", "Log it and complete assessment."),

        // Health-focused (61-80)
        ("Sleep matters", "Log it and complete the assessment."),
        ("Better sleep awaits", "Start with log and questions."),
        ("Health check", "Sleep log and assessment ready."),
        ("Wellness moment", "Log sleep and answer questions."),
        ("Self-care time", "Track sleep and complete assessment."),
        ("For your health", "Two tasks: log and assess."),
        ("Sleep health", "Log and assessment are first steps."),
        ("Feel better", "Log sleep and answer questions."),
        ("Energy check", "Sleep log and assessment for you."),
        ("Vitality boost", "Log and assess for better sleep."),
        ("Rest recovery", "Log sleep and complete questions."),
        ("Body check-in", "Sleep data and assessment tell the story."),
        ("Mind & body", "Log sleep and answer questions."),
        ("Recharge status", "Log rest and complete assessment."),
        ("Recovery time", "Log sleep and answer questions."),
        ("Wellness log", "Track sleep and complete assessment."),
        ("Health journal", "Add sleep entry and assessment."),
        ("Body awareness", "Log sleep and answer questions."),
        ("Rest report", "Submit log and complete assessment."),
        ("Sleep science", "Data and questions drive improvement."),

        // Short and punchy (81-100)
        ("Log time!", "Sleep and assessment await."),
        ("Sleep check!", "Log and questions ready."),
        ("Track it!", "Log sleep and complete assessment."),
        ("Don't forget!", "Sleep log and questions due."),
        ("Quick check!", "Two morning tasks ready."),
        ("Reminder!", "Time to log and assess."),
        ("Daily log!", "Sleep and assessment time."),
        ("Check in!", "Log and questions need you."),
        ("Log now!", "Sleep and assessment fresh."),
        ("Morning tasks!", "Log sleep and answer questions."),
        ("Rise & log!", "Sleep log and assessment."),
        ("Wake & track!", "Log and assess your sleep."),
        ("New day!", "Start with log and assessment."),
        ("Fresh start!", "Log and answer questions."),
        ("Day one!", "Well, another one. Log and assess!"),
        ("Track now!", "Sleep log and assessment await."),
        ("Quick task!", "Log sleep and complete questions."),
        ("Easy win!", "Complete log and assessment."),
        ("2 minutes!", "That's all for both tasks."),
        ("Tap here!", "Log sleep and answer questions."),
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
        migrateNotificationSettings()
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Migration

    /// Migrate notification settings from v1 to v2 (granular controls)
    private func migrateNotificationSettings() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "notificationSettingsMigrated_v2") else {
            print("[Notifications] Migration already complete")
            return
        }

        print("[Notifications] Starting migration to granular notification controls...")

        // Migrate morning reminder → sleep log + assessment (bundled)
        if let morningEnabled = defaults.object(forKey: Self.dailyReminderEnabledKey) as? Bool {
            defaults.set(morningEnabled, forKey: Self.sleepLogReminderEnabledKey)
            defaults.set(morningEnabled, forKey: Self.assessmentReminderEnabledKey)
            defaults.set(true, forKey: Self.assessmentSameAsSleepLogKey) // Bundle by default
        } else {
            // Fresh install - set defaults
            defaults.set(true, forKey: Self.sleepLogReminderEnabledKey)
            defaults.set(true, forKey: Self.assessmentReminderEnabledKey)
            defaults.set(true, forKey: Self.assessmentSameAsSleepLogKey)
        }

        if let hour = defaults.object(forKey: Self.dailyReminderHourKey) as? Int {
            defaults.set(hour, forKey: Self.sleepLogReminderHourKey)
            defaults.set(hour, forKey: Self.assessmentReminderHourKey)
        } else {
            defaults.set(9, forKey: Self.sleepLogReminderHourKey)
            defaults.set(9, forKey: Self.assessmentReminderHourKey)
        }

        if let minute = defaults.object(forKey: Self.dailyReminderMinuteKey) as? Int {
            defaults.set(minute, forKey: Self.sleepLogReminderMinuteKey)
            defaults.set(minute, forKey: Self.assessmentReminderMinuteKey)
        } else {
            defaults.set(0, forKey: Self.sleepLogReminderMinuteKey)
            defaults.set(0, forKey: Self.assessmentReminderMinuteKey)
        }

        // Migrate afternoon reminder → midday check-in
        if let afternoonEnabled = defaults.object(forKey: Self.afternoonReminderEnabledKey) as? Bool {
            defaults.set(afternoonEnabled, forKey: Self.middayCheckInReminderEnabledKey)
        } else {
            defaults.set(true, forKey: Self.middayCheckInReminderEnabledKey)
        }

        if let hour = defaults.object(forKey: Self.afternoonReminderHourKey) as? Int {
            defaults.set(hour, forKey: Self.middayCheckInReminderHourKey)
        } else {
            defaults.set(13, forKey: Self.middayCheckInReminderHourKey)
        }

        if let minute = defaults.object(forKey: Self.afternoonReminderMinuteKey) as? Int {
            defaults.set(minute, forKey: Self.middayCheckInReminderMinuteKey)
        } else {
            defaults.set(0, forKey: Self.middayCheckInReminderMinuteKey)
        }

        // Migrate evening reminder → evening check-in
        if let eveningEnabled = defaults.object(forKey: Self.eveningReminderEnabledKey) as? Bool {
            defaults.set(eveningEnabled, forKey: Self.eveningCheckInReminderEnabledKey)
        } else {
            defaults.set(true, forKey: Self.eveningCheckInReminderEnabledKey)
        }

        if let hour = defaults.object(forKey: Self.eveningReminderHourKey) as? Int {
            defaults.set(hour, forKey: Self.eveningCheckInReminderHourKey)
        } else {
            defaults.set(18, forKey: Self.eveningCheckInReminderHourKey)
        }

        if let minute = defaults.object(forKey: Self.eveningReminderMinuteKey) as? Int {
            defaults.set(minute, forKey: Self.eveningCheckInReminderMinuteKey)
        } else {
            defaults.set(0, forKey: Self.eveningCheckInReminderMinuteKey)
        }

        // NEW FEATURE: Enable overdue reminder by default (6 PM reminder, check at 5 PM)
        defaults.set(true, forKey: Self.overdueReminderEnabledKey)
        defaults.set(18, forKey: Self.overdueReminderHourKey) // 6 PM
        defaults.set(0, forKey: Self.overdueReminderMinuteKey)
        defaults.set(17, forKey: Self.overdueCheckTimeHourKey) // Check at 5 PM
        defaults.set(0, forKey: Self.overdueCheckTimeMinuteKey)

        // NEW FEATURE: Enable morning check-in by default (7 AM)
        defaults.set(true, forKey: Self.morningCheckInReminderEnabledKey)
        defaults.set(7, forKey: Self.morningCheckInReminderHourKey)
        defaults.set(0, forKey: Self.morningCheckInReminderMinuteKey)

        // Enable auto-skip iPhone if Watch by default
        defaults.set(true, forKey: Self.autoSkipIPhoneIfWatchEnabledKey)

        // Mark migration complete
        defaults.set(true, forKey: "notificationSettingsMigrated_v2")

        print("[Notifications] Migration complete - all notification settings configured")
        print("[Notifications] Sleep Log: \(defaults.bool(forKey: Self.sleepLogReminderEnabledKey)) at \(defaults.integer(forKey: Self.sleepLogReminderHourKey)):\(String(format: "%02d", defaults.integer(forKey: Self.sleepLogReminderMinuteKey)))")
        print("[Notifications] Assessment: \(defaults.bool(forKey: Self.assessmentReminderEnabledKey)) (same as sleep log: \(defaults.bool(forKey: Self.assessmentSameAsSleepLogKey)))")
        print("[Notifications] Overdue: \(defaults.bool(forKey: Self.overdueReminderEnabledKey)) at \(defaults.integer(forKey: Self.overdueReminderHourKey)):\(String(format: "%02d", defaults.integer(forKey: Self.overdueReminderMinuteKey)))")
        print("[Notifications] Morning Check-In: \(defaults.bool(forKey: Self.morningCheckInReminderEnabledKey)) at \(defaults.integer(forKey: Self.morningCheckInReminderHourKey)):\(String(format: "%02d", defaults.integer(forKey: Self.morningCheckInReminderMinuteKey)))")
        print("[Notifications] Midday Check-In: \(defaults.bool(forKey: Self.middayCheckInReminderEnabledKey)) at \(defaults.integer(forKey: Self.middayCheckInReminderHourKey)):\(String(format: "%02d", defaults.integer(forKey: Self.middayCheckInReminderMinuteKey)))")
        print("[Notifications] Evening Check-In: \(defaults.bool(forKey: Self.eveningCheckInReminderEnabledKey)) at \(defaults.integer(forKey: Self.eveningCheckInReminderHourKey)):\(String(format: "%02d", defaults.integer(forKey: Self.eveningCheckInReminderMinuteKey)))")
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

    // New granular notification identifiers
    private static let sleepLogReminderID = "sleep_log_reminder"
    private static let assessmentReminderID = "assessment_reminder"
    private static let overdueReminderID = "overdue_task_reminder"
    private static let morningCheckInReminderID = "morning_checkin_reminder"
    private static let middayCheckInReminderID = "midday_checkin_reminder"
    private static let eveningCheckInReminderID = "evening_checkin_reminder"

    /// UserDefaults keys for notification settings (legacy - kept for migration)
    static let dailyReminderEnabledKey = "dailyReminderEnabled"
    static let dailyReminderHourKey = "dailyReminderHour"
    static let dailyReminderMinuteKey = "dailyReminderMinute"
    static let eveningReminderEnabledKey = "eveningReminderEnabled"
    static let eveningReminderHourKey = "eveningReminderHour"
    static let eveningReminderMinuteKey = "eveningReminderMinute"

    // Sleep Log notification settings
    static let sleepLogReminderEnabledKey = "sleepLogReminderEnabled"
    static let sleepLogReminderHourKey = "sleepLogReminderHour"
    static let sleepLogReminderMinuteKey = "sleepLogReminderMinute"

    // Assessment notification settings (bundled with sleep log by default)
    static let assessmentReminderEnabledKey = "assessmentReminderEnabled"
    static let assessmentSameAsSleepLogKey = "assessmentSameAsSleepLog"
    static let assessmentReminderHourKey = "assessmentReminderHour"
    static let assessmentReminderMinuteKey = "assessmentReminderMinute"

    // Overdue catch-up reminder settings (user-configurable check and reminder times)
    static let overdueReminderEnabledKey = "overdueReminderEnabled"
    static let overdueReminderHourKey = "overdueReminderHour"
    static let overdueReminderMinuteKey = "overdueReminderMinute"
    static let overdueCheckTimeHourKey = "overdueCheckTimeHour"
    static let overdueCheckTimeMinuteKey = "overdueCheckTimeMinute"

    // Check-In notification settings (iPhone)
    static let morningCheckInReminderEnabledKey = "morningCheckInReminderEnabled"
    static let morningCheckInReminderHourKey = "morningCheckInReminderHour"
    static let morningCheckInReminderMinuteKey = "morningCheckInReminderMinute"

    static let middayCheckInReminderEnabledKey = "middayCheckInReminderEnabled"
    static let middayCheckInReminderHourKey = "middayCheckInReminderHour"
    static let middayCheckInReminderMinuteKey = "middayCheckInReminderMinute"

    static let eveningCheckInReminderEnabledKey = "eveningCheckInReminderEnabled"
    static let eveningCheckInReminderHourKey = "eveningCheckInReminderHour"
    static let eveningCheckInReminderMinuteKey = "eveningCheckInReminderMinute"

    // Watch coordination settings
    static let autoSkipIPhoneIfWatchEnabledKey = "autoSkipIPhoneIfWatchEnabled"

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
        // Include destination for deep linking - morning = sleep log
        content.userInfo = ["type": "morning_task_reminder", "destination": "sleeplog"]

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
        // Include destination for deep linking - evening = assessment (if not completed)
        content.userInfo = ["type": "evening_task_reminder", "destination": "assessment"]

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

    // MARK: - Granular Notification Scheduling Methods

    /// Schedule sleep log reminder
    func scheduleSleepLogReminder(enabled: Bool, hour: Int, minute: Int) async {
        guard isAuthorized else { return }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.sleepLogReminderID])

        guard enabled else {
            print("[Notifications] Sleep log reminder disabled")
            return
        }

        let message = SleepTaskMessages.randomSleepLogPrompt()

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = NotificationType.sleepLogReminder.rawValue
        content.userInfo = ["destination": "sleeplog"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.sleepLogReminderID, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled sleep log at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("[Notifications] Error scheduling sleep log: \(error)")
        }
    }

    /// Schedule assessment reminder
    func scheduleAssessmentReminder(enabled: Bool, hour: Int, minute: Int) async {
        guard isAuthorized else { return }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.assessmentReminderID])

        guard enabled else {
            print("[Notifications] Assessment reminder disabled")
            return
        }

        let message = SleepTaskMessages.randomAssessmentPrompt()

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = NotificationType.assessmentReminder.rawValue
        content.userInfo = ["destination": "assessment"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.assessmentReminderID, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled assessment at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("[Notifications] Error scheduling assessment: \(error)")
        }
    }

    /// Schedule overdue catch-up reminder
    func scheduleOverdueReminder(enabled: Bool, hour: Int, minute: Int, checkTimeHour: Int, checkTimeMinute: Int) async {
        guard isAuthorized else { return }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.overdueReminderID])

        guard enabled else {
            print("[Notifications] Overdue reminder disabled")
            return
        }

        // Schedule notification at the reminder time, but we'll check completion status before sending
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Use placeholder content - actual content will be set when we check overdue status
        let content = UNMutableNotificationContent()
        content.title = "Catch-Up Reminder"
        content.body = "Time to check if you've completed today's tasks"
        content.sound = .default
        content.categoryIdentifier = NotificationType.overdueTask.rawValue
        content.userInfo = ["destination": "sleeplog", "isOverdue": true, "checkTimeHour": checkTimeHour, "checkTimeMinute": checkTimeMinute]

        let request = UNNotificationRequest(identifier: Self.overdueReminderID, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled overdue check at \(hour):\(String(format: "%02d", minute)) (check time: \(checkTimeHour):\(String(format: "%02d", checkTimeMinute)))")
        } catch {
            print("[Notifications] Error scheduling overdue reminder: \(error)")
        }
    }

    /// Schedule morning check-in reminder (energy/mood/focus)
    func scheduleMorningCheckInReminder(enabled: Bool, hour: Int, minute: Int) async {
        guard isAuthorized else { return }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.morningCheckInReminderID])

        guard enabled else {
            print("[Notifications] Morning check-in reminder disabled")
            return
        }

        let message = CheckInNudgeMessages.randomMorningPrompt()

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = NotificationType.morningCheckInNudge.rawValue
        content.userInfo = ["destination": "checkin_morning"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.morningCheckInReminderID, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled morning check-in at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("[Notifications] Error scheduling morning check-in: \(error)")
        }
    }

    /// Schedule midday check-in reminder (energy/mood/focus)
    func scheduleMiddayCheckInReminder(enabled: Bool, hour: Int, minute: Int) async {
        guard isAuthorized else { return }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.middayCheckInReminderID])

        guard enabled else {
            print("[Notifications] Midday check-in reminder disabled")
            return
        }

        let message = CheckInNudgeMessages.randomMiddayPrompt()

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = NotificationType.middayCheckInNudge.rawValue
        content.userInfo = ["destination": "checkin_midday"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.middayCheckInReminderID, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled midday check-in at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("[Notifications] Error scheduling midday check-in: \(error)")
        }
    }

    /// Schedule evening check-in reminder (energy/mood/focus)
    func scheduleEveningCheckInReminder(enabled: Bool, hour: Int, minute: Int) async {
        guard isAuthorized else { return }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.eveningCheckInReminderID])

        guard enabled else {
            print("[Notifications] Evening check-in reminder disabled")
            return
        }

        let message = CheckInNudgeMessages.randomEveningPrompt()

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = NotificationType.eveningCheckInNudge.rawValue
        content.userInfo = ["destination": "checkin_evening"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.eveningCheckInReminderID, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled evening check-in at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("[Notifications] Error scheduling evening check-in: \(error)")
        }
    }

    /// Check and send overdue reminder if tasks are incomplete
    /// This should be called when the app comes to foreground or at the scheduled check time
    func checkAndSendOverdueReminder() async {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: Self.overdueReminderEnabledKey)
        guard enabled else { return }

        // Check current time against configured check time
        let checkHour = defaults.integer(forKey: Self.overdueCheckTimeHourKey)
        let checkMinute = defaults.integer(forKey: Self.overdueCheckTimeMinuteKey)
        let currentHour = Calendar.current.component(.hour, from: Date())
        let currentMinute = Calendar.current.component(.minute, from: Date())

        // Convert to minutes for comparison
        let currentTimeMinutes = currentHour * 60 + currentMinute
        let checkTimeMinutes = checkHour * 60 + checkMinute
        guard currentTimeMinutes >= checkTimeMinutes else {
            print("[Notifications] Not yet time to check overdue (current: \(currentHour):\(String(format: "%02d", currentMinute)), check: \(checkHour):\(String(format: "%02d", checkMinute)))")
            return
        }

        // Fetch completion status from Convex
        do {
            let journeyProgress = try await ConvexService.shared.getJourneyProgress()
            let sleepLogDone = journeyProgress.sleepLogCompleted ?? false
            let assessmentDone = journeyProgress.assessmentCompleted ?? false

            guard !sleepLogDone || !assessmentDone else {
                print("[Notifications] All tasks completed - no overdue reminder needed")
                return
            }

            // Build task list
            var tasks: [String] = []
            if !sleepLogDone { tasks.append("sleep log") }
            if !assessmentDone { tasks.append("assessment") }

            // Send notification immediately
            let message = NotificationMessages.randomEveningMessage()
            let content = UNMutableNotificationContent()
            content.title = "Catch-Up Reminder"
            content.body = "You still need to complete: \(tasks.joined(separator: ", "))"
            content.sound = .default
            content.categoryIdentifier = NotificationType.overdueTask.rawValue
            content.userInfo = ["destination": "sleeplog", "isOverdue": true]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "overdue_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )

            try await notificationCenter.add(request)
            print("[Notifications] Sent overdue reminder for: \(tasks)")
        } catch {
            print("[Notifications] Failed to check overdue: \(error)")
        }
    }

    /// Schedule all reminders using saved settings from UserDefaults
    /// Call this on app launch to restore notification schedule
    /// Only 3 reminders per day: Morning (9 AM), Afternoon (1 PM), Evening (8 PM)
    func scheduleFromSavedSettings() async {
        let defaults = UserDefaults.standard

        // Morning reminder (sleep log, assessment, morning energy check-in)
        let morningEnabled = defaults.object(forKey: Self.dailyReminderEnabledKey) as? Bool ?? true
        let morningHour = defaults.object(forKey: Self.dailyReminderHourKey) as? Int ?? 9
        let morningMinute = defaults.object(forKey: Self.dailyReminderMinuteKey) as? Int ?? 0

        print("[Notifications] Scheduling from saved settings - morning: \(morningEnabled) at \(morningHour):\(String(format: "%02d", morningMinute))")
        await scheduleDailyTaskReminder(enabled: morningEnabled, hour: morningHour, minute: morningMinute)

        // Afternoon reminder (midday energy check-in - skipped if Watch app installed)
        let afternoonEnabled = defaults.object(forKey: Self.afternoonReminderEnabledKey) as? Bool ?? true
        let afternoonHour = defaults.object(forKey: Self.afternoonReminderHourKey) as? Int ?? 13
        let afternoonMinute = defaults.object(forKey: Self.afternoonReminderMinuteKey) as? Int ?? 0

        print("[Notifications] Scheduling from saved settings - afternoon: \(afternoonEnabled) at \(afternoonHour):\(String(format: "%02d", afternoonMinute))")
        await scheduleAfternoonReminder(enabled: afternoonEnabled, hour: afternoonHour, minute: afternoonMinute)

        // Evening reminder (evening energy check-in + incomplete tasks)
        let eveningEnabled = defaults.object(forKey: Self.eveningReminderEnabledKey) as? Bool ?? true
        let eveningHour = defaults.object(forKey: Self.eveningReminderHourKey) as? Int ?? 20
        let eveningMinute = defaults.object(forKey: Self.eveningReminderMinuteKey) as? Int ?? 0

        print("[Notifications] Scheduling from saved settings - evening: \(eveningEnabled) at \(eveningHour):\(String(format: "%02d", eveningMinute))")
        await scheduleEveningReminder(enabled: eveningEnabled, hour: eveningHour, minute: eveningMinute)
    }

    /// Master scheduling method - schedules all notifications using granular controls
    /// This is the new comprehensive method that replaces scheduleFromSavedSettings for new installations
    func scheduleAllNotificationsFromSettings() async {
        guard isAuthorized else {
            print("[Notifications] Not authorized - skipping all scheduling")
            return
        }

        let defaults = UserDefaults.standard

        // 1. Sleep Log
        let sleepLogEnabled = defaults.bool(forKey: Self.sleepLogReminderEnabledKey)
        let sleepLogHour = defaults.integer(forKey: Self.sleepLogReminderHourKey)
        let sleepLogMinute = defaults.integer(forKey: Self.sleepLogReminderMinuteKey)
        await scheduleSleepLogReminder(enabled: sleepLogEnabled, hour: sleepLogHour, minute: sleepLogMinute)

        // 2. Assessment (same time as sleep log by default)
        let assessmentEnabled = defaults.bool(forKey: Self.assessmentReminderEnabledKey)
        let assessmentSameAsSleepLog = defaults.bool(forKey: Self.assessmentSameAsSleepLogKey)
        if assessmentSameAsSleepLog {
            await scheduleAssessmentReminder(enabled: assessmentEnabled, hour: sleepLogHour, minute: sleepLogMinute)
        } else {
            let assessmentHour = defaults.integer(forKey: Self.assessmentReminderHourKey)
            let assessmentMinute = defaults.integer(forKey: Self.assessmentReminderMinuteKey)
            await scheduleAssessmentReminder(enabled: assessmentEnabled, hour: assessmentHour, minute: assessmentMinute)
        }

        // 3. Overdue catch-up
        let overdueEnabled = defaults.bool(forKey: Self.overdueReminderEnabledKey)
        let overdueHour = defaults.integer(forKey: Self.overdueReminderHourKey)
        let overdueMinute = defaults.integer(forKey: Self.overdueReminderMinuteKey)
        let overdueCheckHour = defaults.integer(forKey: Self.overdueCheckTimeHourKey)
        let overdueCheckMinute = defaults.integer(forKey: Self.overdueCheckTimeMinuteKey)
        await scheduleOverdueReminder(enabled: overdueEnabled, hour: overdueHour, minute: overdueMinute, checkTimeHour: overdueCheckHour, checkTimeMinute: overdueCheckMinute)

        // 4. Check-Ins (auto-skip iPhone if Watch handles them)
        let autoSkipIfWatch = defaults.bool(forKey: Self.autoSkipIPhoneIfWatchEnabledKey)
        let hasWatch = iOSWatchConnectivityManager.shared.isWatchAppInstalled

        // Morning Check-In (iPhone)
        let morningCheckInEnabled = defaults.bool(forKey: Self.morningCheckInReminderEnabledKey)
        let morningCheckInHour = defaults.integer(forKey: Self.morningCheckInReminderHourKey)
        let morningCheckInMinute = defaults.integer(forKey: Self.morningCheckInReminderMinuteKey)
        await scheduleMorningCheckInReminder(enabled: morningCheckInEnabled, hour: morningCheckInHour, minute: morningCheckInMinute)

        // Midday Check-In (skip iPhone if Watch handles it)
        if !autoSkipIfWatch || !hasWatch {
            let middayEnabled = defaults.bool(forKey: Self.middayCheckInReminderEnabledKey)
            let middayHour = defaults.integer(forKey: Self.middayCheckInReminderHourKey)
            let middayMinute = defaults.integer(forKey: Self.middayCheckInReminderMinuteKey)
            await scheduleMiddayCheckInReminder(enabled: middayEnabled, hour: middayHour, minute: middayMinute)
        } else {
            print("[Notifications] Skipping iPhone midday check-in - Watch handles it")
        }

        // Evening Check-In (skip iPhone if Watch handles it)
        if !autoSkipIfWatch || !hasWatch {
            let eveningEnabled = defaults.bool(forKey: Self.eveningCheckInReminderEnabledKey)
            let eveningHour = defaults.integer(forKey: Self.eveningCheckInReminderHourKey)
            let eveningMinute = defaults.integer(forKey: Self.eveningCheckInReminderMinuteKey)
            await scheduleEveningCheckInReminder(enabled: eveningEnabled, hour: eveningHour, minute: eveningMinute)
        } else {
            print("[Notifications] Skipping iPhone evening check-in - Watch handles it")
        }

        print("[Notifications] Scheduled all notifications from granular settings")
    }

    /// Cancel all daily task reminders (morning, afternoon, and evening)
    func cancelDailyTaskReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.morningReminderID, Self.afternoonReminderID, Self.eveningReminderID])
        print("[Notifications] Cancelled all daily task reminders")
    }

    // MARK: - Afternoon Energy Check-In Reminder

    /// Notification identifier for afternoon reminder
    private static let afternoonReminderID = "afternoon_energy_reminder"

    /// UserDefaults keys for afternoon reminder
    static let afternoonReminderEnabledKey = "afternoonReminderEnabled"
    static let afternoonReminderHourKey = "afternoonReminderHour"
    static let afternoonReminderMinuteKey = "afternoonReminderMinute"

    /// Schedule afternoon energy check-in reminder (default 1:00 PM)
    /// This reminder is for the midday energy/mood/focus check-in
    /// If the user has an Apple Watch, this can be handled by the Watch instead
    func scheduleAfternoonReminder(enabled: Bool, hour: Int, minute: Int, skipIfWatchInstalled: Bool = true) async {
        guard isAuthorized else {
            print("[Notifications] Not authorized, skipping afternoon reminder")
            return
        }

        // Cancel existing afternoon reminder
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.afternoonReminderID])

        // Save settings
        UserDefaults.standard.set(enabled, forKey: Self.afternoonReminderEnabledKey)
        UserDefaults.standard.set(hour, forKey: Self.afternoonReminderHourKey)
        UserDefaults.standard.set(minute, forKey: Self.afternoonReminderMinuteKey)

        guard enabled else {
            print("[Notifications] Afternoon reminder disabled")
            return
        }

        // Skip iPhone notification if Watch is installed (Watch handles midday check-ins)
        if skipIfWatchInstalled && iOSWatchConnectivityManager.shared.isWatchAppInstalled {
            print("[Notifications] Skipping afternoon reminder - Watch app handles midday check-ins")
            return
        }

        let prompt = CheckInNudgeMessages.randomMiddayPrompt()

        let content = UNMutableNotificationContent()
        content.title = prompt.title
        content.body = prompt.body
        content.sound = .default
        content.categoryIdentifier = NotificationType.middayCheckInNudge.rawValue
        content.userInfo = ["type": "afternoon_energy_reminder", "destination": "checkin_midday"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Self.afternoonReminderID,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("[Notifications] Scheduled afternoon reminder at \(hour):\(String(format: "%02d", minute))")
        } catch {
            print("[Notifications] Error scheduling afternoon reminder: \(error)")
        }

        await updatePendingCount()
    }

    /// Cancel check-in nudges for a specific time period (morning, midday, or evening)
    /// This method now just cancels the single reminder for that period
    func cancelCheckInNudges(for period: String) {
        switch period.lowercased() {
        case "morning":
            // Morning check-in is bundled with morning task reminder - don't cancel it
            // The morning reminder also includes sleep log/assessment
            print("[Notifications] Morning check-in completed (reminder stays for other tasks)")
        case "midday":
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.afternoonReminderID])
            print("[Notifications] Cancelled afternoon energy reminder")
        case "evening":
            // Evening check-in is bundled with evening reminder - don't cancel it
            // The evening reminder also includes sleep log/assessment if incomplete
            print("[Notifications] Evening check-in completed (reminder stays for other tasks)")
        default:
            print("[Notifications] Unknown check-in period: \(period)")
        }
    }

    /// Cancel all check-in nudges
    func cancelAllCheckInNudges() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.afternoonReminderID])
        print("[Notifications] Cancelled afternoon energy reminder")
    }

    /// Cancel ALL pending notifications (used when user disables notifications entirely)
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("[Notifications] Cancelled ALL pending notifications")
    }

    /// Reset check-in reminders for a new day with fresh random messages
    func resetCheckInNudgesForNewDay() async {
        // Re-schedule afternoon reminder if enabled (with fresh random message)
        let enabled = UserDefaults.standard.object(forKey: Self.afternoonReminderEnabledKey) as? Bool ?? true
        let hour = UserDefaults.standard.object(forKey: Self.afternoonReminderHourKey) as? Int ?? 13
        let minute = UserDefaults.standard.object(forKey: Self.afternoonReminderMinuteKey) as? Int ?? 0

        if enabled {
            await scheduleAfternoonReminder(enabled: true, hour: hour, minute: minute)
            print("[Notifications] Reset afternoon reminder for new day")
        }
    }

    /// Schedule check-in reminders from saved settings
    func scheduleCheckInNudgesFromSavedSettings() async {
        let enabled = UserDefaults.standard.object(forKey: Self.afternoonReminderEnabledKey) as? Bool ?? true
        let hour = UserDefaults.standard.object(forKey: Self.afternoonReminderHourKey) as? Int ?? 13
        let minute = UserDefaults.standard.object(forKey: Self.afternoonReminderMinuteKey) as? Int ?? 0
        await scheduleAfternoonReminder(enabled: enabled, hour: hour, minute: minute)
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

        // Check for explicit destination in userInfo (takes precedence)
        if let destination = userInfo["destination"] as? String {
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": destination]
            )
            completionHandler()
            return
        }

        // Handle based on notification type/category
        switch categoryIdentifier {
        case NotificationType.sleepLogReminder.rawValue:
            // Navigate directly to sleep log questionnaire
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": "sleeplog"]
            )

        case NotificationType.assessmentReminder.rawValue:
            // Navigate directly to assessment questionnaire
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": "assessment"]
            )

        case NotificationType.morningCheckIn.rawValue:
            // Morning task reminder - check userInfo for specific destination
            // Default to sleep log since that's the primary morning task
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": "sleeplog"]
            )

        case NotificationType.afternoonReminder.rawValue, NotificationType.eveningReminder.rawValue:
            // Afternoon/evening reminders - navigate to assessment
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": "assessment"]
            )

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

        case NotificationType.morningCheckInNudge.rawValue:
            // Navigate to morning check-in (energy/mood/focus)
            // Skip if Watch app is installed (user completes on Watch)
            handleCheckInNotification(checkInType: "morning")

        case NotificationType.middayCheckInNudge.rawValue:
            // Navigate to midday check-in (energy/mood/focus)
            // Skip if Watch app is installed (user completes on Watch)
            handleCheckInNotification(checkInType: "midday")

        case NotificationType.eveningCheckInNudge.rawValue:
            // Navigate to evening check-in (energy/mood/focus)
            // Skip if Watch app is installed (user completes on Watch)
            handleCheckInNotification(checkInType: "evening")

        default:
            // Navigate to home/dashboard
            NotificationCenter.default.post(
                name: .deepLinkNavigationRequest,
                object: nil,
                userInfo: ["destination": "home"]
            )
        }

        completionHandler()
    }

    /// Handle check-in notification tap - only show iOS check-in if Watch app not installed
    private nonisolated func handleCheckInNotification(checkInType: String) {
        // Check if Watch app is installed on main thread
        DispatchQueue.main.async {
            let hasWatchApp = iOSWatchConnectivityManager.shared.isWatchAppInstalled

            if hasWatchApp {
                // User has Watch - just open the app (they complete check-ins on Watch)
                print("[Notifications] Watch app installed - skipping iOS check-in UI")
                NotificationCenter.default.post(
                    name: .deepLinkNavigationRequest,
                    object: nil,
                    userInfo: ["destination": "home"]
                )
            } else {
                // No Watch - show iOS check-in UI
                NotificationCenter.default.post(
                    name: .showWatchStyleCheckIn,
                    object: nil,
                    userInfo: ["checkInType": checkInType]
                )
            }
        }
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
