//
//  CheckInModels.swift
//  ZoeSleep Watch App
//
//  Models for the minimal check-in system.
//  Energy uses animal icons, Mood uses weather, Focus uses clarity metaphors.
//

import SwiftUI

// MARK: - Energy Level (Animal Icons)

/// Energy level using playful animal metaphors.
/// From exhausted (sleeping seal) to energized (bouncing rabbit).
enum EnergyLevel: Int, CaseIterable, Identifiable, Codable {
    case sleepingSeal = 1  // Exhausted
    case turtle = 2        // Low energy
    case cat = 3           // Moderate
    case dog = 4           // Good energy
    case ostrich = 5       // High energy
    case rabbit = 6        // Bouncing with energy!

    var id: Int { rawValue }

    /// Display label for the energy level
    var label: String {
        switch self {
        case .sleepingSeal: return "Exhausted"
        case .turtle: return "Slow"
        case .cat: return "Okay"
        case .dog: return "Good"
        case .ostrich: return "High"
        case .rabbit: return "Energized!"
        }
    }

    /// Short label for compact display
    var shortLabel: String {
        switch self {
        case .sleepingSeal: return "Zzz"
        case .turtle: return "Slow"
        case .cat: return "OK"
        case .dog: return "Good"
        case .ostrich: return "High"
        case .rabbit: return "Max!"
        }
    }

    /// SF Symbol name for basic icon (fallback)
    var sfSymbol: String {
        switch self {
        case .sleepingSeal: return "zzz"
        case .turtle: return "tortoise.fill"
        case .cat: return "cat.fill"
        case .dog: return "dog.fill"
        case .ostrich: return "bird.fill"
        case .rabbit: return "hare.fill"
        }
    }

    /// Color representing this energy level (circadian-aware)
    var color: Color {
        let palette = WatchCircadianPalette.current
        switch self {
        case .sleepingSeal: return palette.isDark ? Color(red: 0.4, green: 0.4, blue: 0.5) : .gray
        case .turtle: return palette.isDark ? Color(red: 0.5, green: 0.5, blue: 0.4) : Color(red: 0.6, green: 0.5, blue: 0.3)
        case .cat: return palette.isDark ? Color(red: 0.6, green: 0.5, blue: 0.3) : .orange
        case .dog: return palette.isDark ? Color(red: 0.8, green: 0.6, blue: 0.3) : Color(red: 0.3, green: 0.7, blue: 0.4)
        case .ostrich: return palette.isDark ? Color(red: 0.9, green: 0.7, blue: 0.3) : Color(red: 0.2, green: 0.6, blue: 0.8)
        case .rabbit: return palette.isDark ? Color(red: 1.0, green: 0.8, blue: 0.4) : Color(red: 0.3, green: 0.8, blue: 0.5)
        }
    }

    /// Animation speed multiplier (tired animals move slower)
    var animationSpeed: Double {
        switch self {
        case .sleepingSeal: return 0.3
        case .turtle: return 0.5
        case .cat: return 0.8
        case .dog: return 1.0
        case .ostrich: return 1.3
        case .rabbit: return 1.6
        }
    }

    /// Breathing animation duration (slower for tired)
    var breathDuration: Double {
        switch self {
        case .sleepingSeal, .turtle: return 3.0
        case .cat: return 2.5
        case .dog: return 2.0
        case .ostrich, .rabbit: return 1.5
        }
    }
}

// MARK: - Mood Level (Weather Icons)

/// Mood level using weather metaphors.
/// From stormy (terrible) to rainbow (amazing).
enum MoodLevel: Int, CaseIterable, Identifiable, Codable {
    case stormy = 1       // Terrible mood
    case rainy = 2        // Down/sad
    case cloudy = 3       // Meh/neutral
    case partlySunny = 4  // Okay
    case sunny = 5        // Good mood
    case rainbow = 6      // Amazing!

    var id: Int { rawValue }

    /// Display label for the mood level
    var label: String {
        switch self {
        case .stormy: return "Stormy"
        case .rainy: return "Rainy"
        case .cloudy: return "Cloudy"
        case .partlySunny: return "Clearing"
        case .sunny: return "Sunny"
        case .rainbow: return "Rainbow"
        }
    }

    /// SF Symbol name for the weather icon
    var sfSymbol: String {
        switch self {
        case .stormy: return "cloud.bolt.fill"
        case .rainy: return "cloud.rain.fill"
        case .cloudy: return "cloud.fill"
        case .partlySunny: return "cloud.sun.fill"
        case .sunny: return "sun.max.fill"
        case .rainbow: return "rainbow"
        }
    }

    /// Color representing this mood level
    var color: Color {
        let palette = WatchCircadianPalette.current
        switch self {
        case .stormy: return palette.isDark ? Color(red: 0.4, green: 0.3, blue: 0.5) : Color(red: 0.3, green: 0.3, blue: 0.5)
        case .rainy: return palette.isDark ? Color(red: 0.4, green: 0.4, blue: 0.6) : Color(red: 0.4, green: 0.5, blue: 0.7)
        case .cloudy: return palette.isDark ? Color(red: 0.5, green: 0.5, blue: 0.5) : .gray
        case .partlySunny: return palette.isDark ? Color(red: 0.7, green: 0.6, blue: 0.4) : Color(red: 0.9, green: 0.7, blue: 0.3)
        case .sunny: return palette.isDark ? Color(red: 0.9, green: 0.7, blue: 0.3) : Color(red: 1.0, green: 0.8, blue: 0.2)
        case .rainbow: return palette.isDark ? Color(red: 0.8, green: 0.5, blue: 0.7) : Color(red: 0.6, green: 0.4, blue: 0.8)
        }
    }

    /// Animation style for weather
    var hasRainAnimation: Bool {
        self == .stormy || self == .rainy
    }

    var hasSunAnimation: Bool {
        self == .sunny || self == .partlySunny
    }
}

// MARK: - Focus Level (Clarity Icons)

/// Focus/clarity level using visual metaphors.
/// From foggy (can't concentrate) to crystal clear (sharp focus).
enum FocusLevel: Int, CaseIterable, Identifiable, Codable {
    case foggy = 1      // Can't concentrate
    case hazy = 2       // Distracted
    case clearing = 3   // Getting there
    case clear = 4      // Focused
    case crystal = 5    // Crystal clear focus

    var id: Int { rawValue }

    /// Display label for the focus level
    var label: String {
        switch self {
        case .foggy: return "Foggy"
        case .hazy: return "Hazy"
        case .clearing: return "Clearing"
        case .clear: return "Clear"
        case .crystal: return "Crystal"
        }
    }

    /// SF Symbol name for the focus icon
    var sfSymbol: String {
        switch self {
        case .foggy: return "cloud.fog.fill"
        case .hazy: return "smoke.fill"
        case .clearing: return "sun.haze.fill"
        case .clear: return "eye.fill"
        case .crystal: return "sparkles"
        }
    }

    /// Color representing this focus level
    var color: Color {
        let palette = WatchCircadianPalette.current
        switch self {
        case .foggy: return palette.isDark ? Color(red: 0.4, green: 0.4, blue: 0.4) : .gray
        case .hazy: return palette.isDark ? Color(red: 0.5, green: 0.5, blue: 0.5) : Color(red: 0.6, green: 0.6, blue: 0.6)
        case .clearing: return palette.isDark ? Color(red: 0.6, green: 0.6, blue: 0.5) : Color(red: 0.7, green: 0.7, blue: 0.5)
        case .clear: return palette.isDark ? Color(red: 0.7, green: 0.7, blue: 0.5) : Color(red: 0.3, green: 0.6, blue: 0.9)
        case .crystal: return palette.isDark ? Color(red: 0.9, green: 0.8, blue: 0.5) : Color(red: 0.4, green: 0.8, blue: 1.0)
        }
    }

    /// Blur radius for visual effect
    var blurRadius: CGFloat {
        switch self {
        case .foggy: return 10
        case .hazy: return 6
        case .clearing: return 3
        case .clear: return 1
        case .crystal: return 0
        }
    }
}

// MARK: - Check-In Type

/// Type of check-in (morning, midday, or evening)
enum CheckInType: String, CaseIterable, Identifiable, Codable {
    case morning
    case midday
    case evening

    var id: String { rawValue }

    /// Display label
    var label: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .evening: return "Evening"
        }
    }

    /// SF Symbol for the check-in type
    var sfSymbol: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }

    /// Time window description
    var timeWindow: String {
        switch self {
        case .morning: return "5 AM - 12 PM"
        case .midday: return "12 PM - 6 PM"
        case .evening: return "6 PM - 12 AM"
        }
    }

    /// Color for the check-in type
    var color: Color {
        let palette = WatchCircadianPalette.current
        switch self {
        case .morning: return palette.isDark ? Color(red: 0.9, green: 0.7, blue: 0.4) : Color(red: 1.0, green: 0.8, blue: 0.3)
        case .midday: return palette.isDark ? Color(red: 0.8, green: 0.7, blue: 0.4) : Color(red: 0.3, green: 0.7, blue: 0.9)
        case .evening: return palette.isDark ? Color(red: 0.8, green: 0.5, blue: 0.3) : Color(red: 0.9, green: 0.5, blue: 0.3)
        }
    }
}

// MARK: - Check-In Data

/// Complete check-in data structure
struct WatchCheckIn: Codable {
    let date: String           // YYYY-MM-DD
    let type: CheckInType
    let energyLevel: Int       // 1-6
    let moodLevel: Int         // 1-6
    let focusLevel: Int        // 1-5
    let completedAt: Date

    var energy: EnergyLevel? {
        EnergyLevel(rawValue: energyLevel)
    }

    var mood: MoodLevel? {
        MoodLevel(rawValue: moodLevel)
    }

    var focus: FocusLevel? {
        FocusLevel(rawValue: focusLevel)
    }
}

/// Check-in status for today
struct WatchCheckInStatus: Codable {
    let morningDone: Bool
    let middayDone: Bool
    let eveningDone: Bool
    let totalDone: Int
    let recommendedNext: String?
    let lastEnergyLevel: Int?
    let lastMoodLevel: Int?
    let lastFocusLevel: Int?

    var completedCount: Int {
        totalDone
    }

    var allDone: Bool {
        morningDone && middayDone && eveningDone
    }

    var recommendedCheckInType: CheckInType? {
        guard let next = recommendedNext else { return nil }
        return CheckInType(rawValue: next)
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension EnergyLevel {
    static var preview: EnergyLevel { .dog }
}

extension MoodLevel {
    static var preview: MoodLevel { .sunny }
}

extension FocusLevel {
    static var preview: FocusLevel { .clear }
}
#endif

// MARK: - Encouragement Message Library (100+ Messages)

/// A comprehensive library of 100+ encouragement messages to keep notifications fresh.
/// Messages are randomly selected to prevent user desensitization.
/// Categories: Check-in, Sleep Log, Assessment, Energy Nudges, and more.
struct EncouragementMessages {

    // MARK: - Check-In Completion Messages (55 messages)

    static let checkInComplete: [String] = [
        // Celebratory (10)
        "Nailed it! Your future self thanks you.",
        "Boom! Another data point for better sleep.",
        "You're building a sleep superpower!",
        "Logged! You're crushing this.",
        "That's the stuff! Keep it rolling.",
        "Fantastic! You're on a roll!",
        "Yes! Every check-in counts.",
        "Brilliant! You're making progress.",
        "Awesome! Your data is growing.",
        "Perfect! Keep the momentum going.",

        // Mindful (10)
        "Awareness is the first step to change.",
        "Noticing patterns is how healing begins.",
        "You just invested 10 seconds in yourself.",
        "Small acts, big impact.",
        "Every check-in is a gift to future you.",
        "Mindfulness in action.",
        "Self-awareness unlocked.",
        "You're paying attention to yourself.",
        "This moment of reflection matters.",
        "Tuning into your body's signals.",

        // Progress-focused (10)
        "One more step toward understanding yourself.",
        "Your sleep data is getting smarter.",
        "Pattern detected: You're consistent!",
        "This data will reveal your secrets.",
        "Building your sleep fingerprint...",
        "Your profile is getting clearer.",
        "Insights are forming...",
        "Your sleep story is unfolding.",
        "Data point logged. Progress made.",
        "Another piece of the puzzle.",

        // Playful (10)
        "Even koalas would be impressed!",
        "Your circadian rhythm says thanks.",
        "If sleep tracking were a sport, you'd medal.",
        "Achievement unlocked: Self-awareness!",
        "Your pillow sends its regards.",
        "Sleep gods approve!",
        "Your mattress is proud.",
        "Dream team material right here!",
        "Zzzoe approves this message.",
        "Sleep champion in the making!",

        // Scientific (5)
        "Data point captured. Science in action!",
        "Your biometrics are taking shape.",
        "One more variable for the algorithm.",
        "Correlations loading...",
        "Sleep science appreciates you.",

        // Encouraging (5)
        "You showed up. That's what matters.",
        "Consistency beats perfection.",
        "Slow progress is still progress.",
        "You're doing the work. Respect.",
        "This is self-care in action.",

        // Warm (5)
        "Thanks for sharing how you're feeling.",
        "We see you. Keep going.",
        "Your wellbeing matters.",
        "Taking care of yourself today.",
        "One mindful moment at a time.",
    ]

    // MARK: - Morning Reminder Messages (20)

    static let morningReminders: [String] = [
        "Good morning! Quick check-in?",
        "Rise and shine! How are you feeling?",
        "Morning vibes check!",
        "Start your day with a check-in",
        "How did you wake up today?",
        "10 seconds to log your morning",
        "Capture how you're feeling now",
        "Morning energy check!",
        "Your future self wants to know",
        "Quick morning pulse check",
        "How's the morning treating you?",
        "Log your morning mood!",
        "Start tracking your day",
        "Morning check-in time!",
        "Begin your day mindfully",
        "New day, fresh data!",
        "Morning routine: check in!",
        "How's your energy this AM?",
        "Catch your morning state!",
        "Day's starting - how are you?",
    ]

    // MARK: - Midday Reminder Messages (20)

    static let middayReminders: [String] = [
        "Midday check! How's your energy?",
        "Afternoon pulse check",
        "How's your day going?",
        "Quick midday moment",
        "Time for a focus check",
        "Halfway through! How do you feel?",
        "Afternoon vibes check",
        "Energy still holding up?",
        "Quick check-in break",
        "Moment of self-awareness",
        "How's your focus right now?",
        "Midday mood check!",
        "Pause and reflect",
        "Afternoon check-in time!",
        "Track your afternoon state",
        "Mid-day mental snapshot",
        "How's the afternoon energy?",
        "Take a moment to log",
        "Afternoon awareness break",
        "Quick status update?",
    ]

    // MARK: - Evening Reminder Messages (20)

    static let eveningReminders: [String] = [
        "Evening wind-down check",
        "How was your day?",
        "Time to reflect on today",
        "Evening energy check",
        "Wrapping up the day",
        "End-of-day reflection",
        "How are you feeling now?",
        "Evening mood check!",
        "Wind down with a check-in",
        "Log your evening state",
        "Ready for rest? Quick check!",
        "Capture your evening mood",
        "Day's almost done - check in!",
        "Evening self-care moment",
        "Reflect before you rest",
        "End your day mindfully",
        "Evening wellness check",
        "How's your evening energy?",
        "Sunset check-in time",
        "Close your day with awareness",
    ]

    // MARK: - Sleep Log Reminder Messages (25)

    static let sleepLogReminders: [String] = [
        // Gentle first reminders
        "How did you sleep? Log it now!",
        "Morning! Time for your sleep log.",
        "Record last night's sleep",
        "Your sleep data awaits",
        "Quick sleep log - 2 minutes!",
        "Log your sleep while it's fresh",
        "How was last night?",
        "Sleep diary time!",
        "Capture your sleep story",
        "Don't forget your sleep log!",

        // Encouraging
        "Your sleep log builds insights",
        "Each log improves your analysis",
        "Sleep patterns emerge from logs",
        "Track to transform your sleep",
        "Your future sleep depends on this",

        // Playful
        "Tell us about dreamland!",
        "Rate your night's performance",
        "Sleep scorecard time!",
        "How'd the pillow perform?",
        "Night shift report due!",

        // Scientific
        "Stanford questions: 5 quick ones",
        "Sleep metrics capture time",
        "Log for longitudinal insights",
        "Data point for sleep science",
        "Track your circadian rhythm",
    ]

    // MARK: - Assessment Reminder Messages (25)

    static let assessmentReminders: [String] = [
        // Gentle first reminders
        "Time for today's questions",
        "A few questions about you today",
        "Daily assessment ready",
        "Your assessment awaits",
        "Quick questionnaire time",
        "Help us understand you better",
        "Today's insights questions",
        "Answer a few questions?",
        "Daily check-in questions",
        "Personalization questions ready",

        // Encouraging
        "Your answers shape your plan",
        "Each answer improves accuracy",
        "We're learning about you",
        "Building your sleep profile",
        "Unlocking personalized insights",

        // Progress-focused
        "Continue your journey",
        "Next step in understanding",
        "Keep your progress going",
        "Don't lose momentum!",
        "Your intake continues...",

        // Playful
        "Quiz time! (The fun kind)",
        "Tell us more about you!",
        "Questionnaire unlocked!",
        "Daily discovery questions",
        "Learn yourself challenge!",
    ]

    // MARK: - Energy Nudge Messages (30)

    static let energyNudges: [String] = [
        // Morning energy (10)
        "Morning light boosts energy all day!",
        "Hydrate first thing for better energy",
        "Stretch for 2 min - wake up your body",
        "Step outside for a quick energy boost",
        "Morning movement = afternoon energy",
        "Bright light now helps sleep tonight",
        "Natural light is your circadian ally",
        "Your body clock needs morning light",
        "A short walk now powers your day",
        "Early sunshine = better evening sleep",

        // Midday energy (10)
        "Feeling sleepy? Try a 5-min walk",
        "Afternoon slump? Get some light!",
        "Stand up and stretch for energy",
        "Post-lunch walk prevents crash",
        "Sunlight resets your alertness",
        "Brief movement beats caffeine",
        "Your energy dip is normal - move!",
        "Light exposure now helps tonight",
        "Avoid the couch trap - stay moving",
        "A quick stretch goes a long way",

        // Evening wind-down (10)
        "Dim lights to signal sleep time",
        "Blue light blockers on!",
        "Time to start winding down",
        "Lower lights for melatonin",
        "Evening mode: calm and dim",
        "Your body needs darkness signals",
        "Prepare your brain for sleep",
        "Circadian wind-down time",
        "Less light = better sleep soon",
        "Evening darkness is medicine",
    ]

    // MARK: - Streak Messages (15)

    static let streakMessages: [String] = [
        "Day %d! You're on fire!",
        "%d days strong!",
        "Streak: %d days! Keep it alive!",
        "%d day streak! Impressive!",
        "You've checked in %d days in a row!",
        "%d days of consistency!",
        "Wow! %d days and counting!",
        "%d day streak - don't break it!",
        "Your %d day streak is legendary!",
        "Consistency king: %d days!",
        "%d days in a row! Unstoppable!",
        "That's %d days of dedication!",
        "%d day champion!",
        "Streak hero: %d days!",
        "%d days - you're committed!",
    ]

    // MARK: - Missed Check-In Messages (15)

    static let missedCheckIn: [String] = [
        "We missed you! Check in when ready.",
        "No worries, you can catch up now.",
        "Yesterday's check-in awaits.",
        "It's okay to miss one. Ready now?",
        "Let's get back on track!",
        "New day, fresh start!",
        "Your streak misses you!",
        "One tap to get back in the game.",
        "Ready when you are!",
        "Let's keep the momentum going.",
        "Welcome back! Time to check in.",
        "Missed you - let's catch up!",
        "Your data missed a beat.",
        "Back at it? Log now!",
        "Restart your streak today!",
    ]

    // MARK: - Day Completion Celebration (15)

    static let dayComplete: [String] = [
        "Day complete! Amazing work!",
        "All done for today! Rest well.",
        "You crushed it today!",
        "Day logged. You're a star!",
        "Another day in the books!",
        "Today's journey: Complete!",
        "Mission accomplished!",
        "Full day tracked! Impressive!",
        "You showed up today. Proud!",
        "All tasks done. Well done!",
        "Perfect day of tracking!",
        "Today: 100% complete!",
        "You're building great habits!",
        "Consistency is your superpower!",
        "Tomorrow will thank you!",
    ]

    // MARK: - Gentle Encouragement When Struggling (15)

    static let gentleEncouragement: [String] = [
        "Tough days are part of the journey.",
        "Rest is productive too.",
        "Be gentle with yourself today.",
        "Every day can't be perfect.",
        "Your effort matters, always.",
        "Progress isn't always linear.",
        "You're doing better than you think.",
        "Small steps still move forward.",
        "It's okay to have off days.",
        "Tomorrow is a fresh start.",
        "You're showing up - that counts.",
        "Healing takes time. Be patient.",
        "Your best today is enough.",
        "Recovery isn't always visible.",
        "Keep going, one moment at a time.",
    ]

    // MARK: - Personalized Messages Based on Levels

    static func energyMessage(level: Int) -> String {
        switch level {
        case 1: return "Rest is valid. Take it easy today."
        case 2: return "Low energy noted. Be gentle with yourself."
        case 3: return "Moderate energy - pace yourself."
        case 4: return "Good energy! Use it wisely."
        case 5: return "High energy day! Make it count."
        case 6: return "You're bouncing! Channel that power!"
        default: return "Thanks for checking in!"
        }
    }

    static func moodMessage(level: Int) -> String {
        switch level {
        case 1: return "Tough day. This too shall pass."
        case 2: return "Feeling low is okay. You're not alone."
        case 3: return "Hanging in there. That's enough."
        case 4: return "Good vibes detected!"
        case 5: return "Sunny disposition! Love to see it."
        case 6: return "You're radiant today!"
        default: return "Thanks for sharing how you feel."
        }
    }

    static func focusMessage(level: Int) -> String {
        switch level {
        case 1: return "Foggy days happen. Rest your mind."
        case 2: return "A bit hazy? That's okay."
        case 3: return "Finding your focus. Keep going."
        case 4: return "Clear-headed! Nice."
        case 5: return "Crystal clear focus! Impressive."
        default: return "Thanks for logging your clarity."
        }
    }

    // MARK: - Random Selection Helpers

    static func randomCompletionMessage() -> String {
        checkInComplete.randomElement() ?? "Check-in complete!"
    }

    static func randomReminderMessage(for type: ReminderType) -> String {
        switch type {
        case .morning:
            return morningReminders.randomElement() ?? "Morning check-in time!"
        case .midday:
            return middayReminders.randomElement() ?? "Midday check-in time!"
        case .evening:
            return eveningReminders.randomElement() ?? "Evening check-in time!"
        }
    }

    static func randomSleepLogReminder() -> String {
        sleepLogReminders.randomElement() ?? "Time for your sleep log!"
    }

    static func randomAssessmentReminder() -> String {
        assessmentReminders.randomElement() ?? "Time for today's assessment!"
    }

    static func randomEnergyNudge(for timeOfDay: TimeOfDay) -> String {
        let nudges: [String]
        switch timeOfDay {
        case .morning:
            nudges = Array(energyNudges.prefix(10))
        case .afternoon:
            nudges = Array(energyNudges.dropFirst(10).prefix(10))
        case .evening:
            nudges = Array(energyNudges.suffix(10))
        }
        return nudges.randomElement() ?? energyNudges.randomElement()!
    }

    static func randomDayCompleteMessage() -> String {
        dayComplete.randomElement() ?? "Day complete!"
    }

    static func randomGentleEncouragement() -> String {
        gentleEncouragement.randomElement() ?? "Keep going!"
    }

    static func streakMessage(days: Int) -> String {
        let template = streakMessages.randomElement() ?? "Day %d!"
        return String(format: template, days)
    }

    static func personalizedMessage(energy: Int, mood: Int, focus: Int) -> String {
        let lowestMetric = min(energy, mood, focus)

        if lowestMetric <= 2 {
            if energy == lowestMetric {
                return energyMessage(level: energy)
            } else if mood == lowestMetric {
                return moodMessage(level: mood)
            } else {
                return focusMessage(level: focus)
            }
        } else if lowestMetric >= 5 {
            let celebrations = [
                "All systems go! You're having a great day!",
                "Energy, mood, and focus all high! Amazing!",
                "Triple threat! You're firing on all cylinders!",
                "Peak performance mode activated!",
                "You're crushing it across the board!",
            ]
            return celebrations.randomElement() ?? "Great job!"
        } else {
            return randomCompletionMessage()
        }
    }

    enum ReminderType {
        case morning, midday, evening
    }

    enum TimeOfDay {
        case morning, afternoon, evening
    }

    struct NotificationContent {
        let title: String
        let body: String
        let sound: Bool
    }

    static func notificationContent(for type: ReminderType, reminderNumber: Int) -> NotificationContent {
        let body = randomReminderMessage(for: type)

        switch reminderNumber {
        case 1:
            return NotificationContent(title: type.title, body: body, sound: false)
        case 2:
            return NotificationContent(title: type.title, body: body, sound: true)
        case 3:
            let urgentBodies = [
                "Last chance for \(type.rawValue.lowercased()) check-in!",
                "Don't miss your \(type.rawValue.lowercased()) check-in!",
                "Window closing soon!",
            ]
            return NotificationContent(title: "Check-In Reminder", body: urgentBodies.randomElement() ?? body, sound: true)
        default:
            return NotificationContent(title: type.title, body: body, sound: true)
        }
    }
}

extension EncouragementMessages.ReminderType {
    var title: String {
        switch self {
        case .morning: return "Morning Check-In"
        case .midday: return "Midday Check-In"
        case .evening: return "Evening Check-In"
        }
    }

    var rawValue: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .evening: return "Evening"
        }
    }
}
