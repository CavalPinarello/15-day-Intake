//
//  SleepFactModels.swift
//  Zoe Sleep for Longevity System
//
//  Pre-curated sleep facts for reward moments during questionnaire
//  Facts are organized by pillar and shown between questions to educate and engage
//

import Foundation

// MARK: - Sleep Fact Model

struct SleepFact: Identifiable {
    let id: String
    let pillar: Pillar
    let title: String           // Short celebratory header
    let body: String            // Main educational content
    let statistic: String?      // Optional stat like "73% of users..."
    let citation: String?       // Source reference
    let category: FactCategory  // Type of fact

    init(id: String, pillar: Pillar, title: String, body: String, statistic: String? = nil, citation: String? = nil, category: FactCategory = .scienceSpotlight) {
        self.id = id
        self.pillar = pillar
        self.title = title
        self.body = body
        self.statistic = statistic
        self.citation = citation
        self.category = category
    }
}

// MARK: - Fact Category

enum FactCategory: String, Codable, CaseIterable {
    case whyWeAsked = "why_we_asked"
    case scienceSpotlight = "science_spotlight"
    case cohortComparison = "cohort_comparison"
    case sleepTip = "sleep_tip"
    case calibrationEncouragement = "calibration_encouragement"

    var displayName: String {
        switch self {
        case .whyWeAsked: return "Why We Asked"
        case .scienceSpotlight: return "Science Spotlight"
        case .cohortComparison: return "How You Compare"
        case .sleepTip: return "Sleep Tip"
        case .calibrationEncouragement: return "Building Your Baseline"
        }
    }

    var icon: String {
        switch self {
        case .whyWeAsked: return "questionmark.circle.fill"
        case .scienceSpotlight: return "sparkles"
        case .cohortComparison: return "person.3.fill"
        case .sleepTip: return "lightbulb.fill"
        case .calibrationEncouragement: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Reward Moment Configuration

struct RewardMomentConfig {
    // MARK: - Assessment Settings

    /// Minimum questions between rewards (Assessment)
    static let minQuestionsBetween = 3

    /// Maximum questions between rewards (Assessment)
    static let maxQuestionsBetween = 4

    // MARK: - Sleep Log Settings

    /// Minimum questions between rewards (Sleep Log - more frequent for encouragement)
    static let sleepLogMinQuestionsBetween = 2

    /// Maximum questions between rewards (Sleep Log)
    static let sleepLogMaxQuestionsBetween = 3

    // MARK: - General Settings

    /// Auto-dismiss timeout in seconds
    static let autoDismissSeconds: Double = 4.0

    /// Enable rewards in Sleep Log section (calibration encouragement)
    static let skipSleepLog = false
}

// MARK: - Sleep Fact Bank

/// Pre-curated facts organized by pillar
/// Each pillar has 3+ facts for variety
enum SleepFactBank {

    // MARK: - All Facts

    static let all: [SleepFact] = sleepQualityFacts + sleepTimingFacts + mentalHealthFacts + metabolicFacts + physicalFacts + cognitiveFacts + socialFacts + nutritionalFacts

    // MARK: - Sleep Quality Facts

    static let sleepQualityFacts: [SleepFact] = [
        SleepFact(
            id: "sq_1",
            pillar: .sleepQuality,
            title: "Quality Over Quantity",
            body: "Research shows sleep efficiency matters more than total hours. Someone sleeping 6 hours deeply often feels better than 8 hours of fragmented sleep.",
            citation: "Walker, 2017 - Why We Sleep",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "sq_2",
            pillar: .sleepQuality,
            title: "Your Body's Repair Mode",
            body: "During deep sleep, your body releases growth hormone and repairs tissues. Poor sleep quality disrupts this vital recovery process.",
            statistic: "70% of growth hormone is released during deep sleep",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "sq_3",
            pillar: .sleepQuality,
            title: "Building Your Sleep Profile",
            body: "These questions help us understand your unique sleep architecture. Sleep quality varies by age, lifestyle, and biology - there's no one-size-fits-all.",
            statistic: "Sleep quality accounts for 40% of how refreshed you feel",
            category: .whyWeAsked
        ),
        SleepFact(
            id: "sq_4",
            pillar: .sleepQuality,
            title: "The 90-Minute Cycle",
            body: "Sleep occurs in 90-minute cycles. Waking mid-cycle often leaves you groggy, while timing your wake-up to cycle completion helps you feel refreshed.",
            category: .sleepTip
        )
    ]

    // MARK: - Sleep Timing Facts

    static let sleepTimingFacts: [SleepFact] = [
        SleepFact(
            id: "st_1",
            pillar: .sleepTiming,
            title: "Chronotype Matters",
            body: "Whether you're an early bird or night owl is largely genetic. Working with your natural rhythm improves both sleep and daytime performance.",
            statistic: "Only 25% of people are true morning types",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "st_2",
            pillar: .sleepTiming,
            title: "The Circadian Connection",
            body: "Your body's internal clock affects everything from hormone release to body temperature. Consistent sleep timing strengthens these rhythms.",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "st_3",
            pillar: .sleepTiming,
            title: "Social Jet Lag",
            body: "When your sleep schedule varies by 2+ hours on weekends vs weekdays, it's like traveling across time zones. This 'social jet lag' can affect your health.",
            statistic: "Social jet lag affects 70% of adults",
            category: .cohortComparison
        ),
        SleepFact(
            id: "st_4",
            pillar: .sleepTiming,
            title: "Light Is Your Clock",
            body: "Morning light exposure is the most powerful signal for your circadian rhythm. Even 15 minutes of natural light after waking helps set your internal clock.",
            category: .sleepTip
        )
    ]

    // MARK: - Mental Health Facts

    static let mentalHealthFacts: [SleepFact] = [
        SleepFact(
            id: "mh_1",
            pillar: .mentalHealth,
            title: "Sleep & Mood: A Two-Way Street",
            body: "Poor sleep doesn't just result from anxiety - it can cause it. Improving sleep is often the first step in treating mood disorders.",
            citation: "Harvard Medical School, 2022",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "mh_2",
            pillar: .mentalHealth,
            title: "REM Sleep & Emotional Processing",
            body: "During REM sleep, your brain processes emotional memories, essentially providing overnight therapy. Dreams help regulate your mood.",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "mh_3",
            pillar: .mentalHealth,
            title: "Building Resilience",
            body: "Well-rested brains show better emotional regulation in brain scans. Sleep is your brain's daily reset button for stress.",
            statistic: "Sleep deprivation increases emotional reactivity by 60%",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "mh_4",
            pillar: .mentalHealth,
            title: "Understanding the Connection",
            body: "We ask about mood because sleep and mental health are deeply intertwined. This helps us personalize recommendations that address the whole picture.",
            category: .whyWeAsked
        )
    ]

    // MARK: - Metabolic Facts

    static let metabolicFacts: [SleepFact] = [
        SleepFact(
            id: "met_1",
            pillar: .metabolic,
            title: "Sleep & Your Metabolism",
            body: "Even one night of poor sleep can affect insulin sensitivity and hunger hormones. Your metabolism literally depends on good sleep.",
            statistic: "Sleep-deprived people consume 385 more calories per day on average",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "met_2",
            pillar: .metabolic,
            title: "The Hunger Hormones",
            body: "Sleep loss increases ghrelin (hunger hormone) and decreases leptin (fullness hormone). It's not willpower - it's biology.",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "met_3",
            pillar: .metabolic,
            title: "Blood Sugar Balance",
            body: "Poor sleep affects how your body processes glucose. Understanding your health conditions helps us connect the dots with your sleep patterns.",
            category: .whyWeAsked
        ),
        SleepFact(
            id: "met_4",
            pillar: .metabolic,
            title: "The Weight Connection",
            body: "People who sleep less than 6 hours are more likely to have higher BMI. Sleep affects weight through hormones, cravings, and energy for exercise.",
            statistic: "Short sleepers have a 55% higher risk of obesity",
            category: .cohortComparison
        )
    ]

    // MARK: - Physical Facts

    static let physicalFacts: [SleepFact] = [
        SleepFact(
            id: "ph_1",
            pillar: .physical,
            title: "Pain & Sleep Cycle",
            body: "Poor sleep lowers pain thresholds, and pain disrupts sleep - a challenging cycle. Improving one often improves the other.",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "ph_2",
            pillar: .physical,
            title: "Immune Function",
            body: "Your immune system does critical work during sleep. Consistently sleeping less than 7 hours significantly increases your risk of getting sick.",
            statistic: "Short sleep triples your risk of catching a cold",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "ph_3",
            pillar: .physical,
            title: "Athletic Recovery",
            body: "Professional athletes prioritize sleep as much as training. Growth hormone released during deep sleep repairs muscles and tissues.",
            statistic: "Athletes who sleep 10+ hours show 9% faster sprint times",
            citation: "Stanford Sleep Research",
            category: .cohortComparison
        ),
        SleepFact(
            id: "ph_4",
            pillar: .physical,
            title: "Your Sleep Environment",
            body: "Questions about snoring and breathing help us screen for conditions like sleep apnea. Early detection can significantly improve health outcomes.",
            category: .whyWeAsked
        )
    ]

    // MARK: - Cognitive Facts

    static let cognitiveFacts: [SleepFact] = [
        SleepFact(
            id: "cog_1",
            pillar: .cognitive,
            title: "Memory Consolidation",
            body: "What you learn during the day gets transferred to long-term memory during sleep. All-nighters actually hurt exam performance.",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "cog_2",
            pillar: .cognitive,
            title: "The Glymphatic System",
            body: "During sleep, your brain's waste-clearance system activates, flushing out toxins including proteins linked to Alzheimer's disease.",
            citation: "Nedergaard Lab, University of Rochester",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "cog_3",
            pillar: .cognitive,
            title: "Decision-Making Power",
            body: "Sleep-deprived brains show less activity in decision-making centers. Important choices are best made when well-rested.",
            statistic: "24 hours without sleep impairs judgment like 0.1% BAC",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "cog_4",
            pillar: .cognitive,
            title: "Focus & Creativity",
            body: "REM sleep is when your brain makes creative connections between ideas. People often solve problems after 'sleeping on it' for a reason.",
            category: .sleepTip
        )
    ]

    // MARK: - Social Facts

    static let socialFacts: [SleepFact] = [
        SleepFact(
            id: "soc_1",
            pillar: .social,
            title: "Sleep & Social Connection",
            body: "Poor sleep affects our ability to read social cues and emotions. Well-rested people are perceived as more approachable.",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "soc_2",
            pillar: .social,
            title: "The Bedroom Environment",
            body: "Partners often have different sleep needs. Understanding your individual patterns helps create solutions that work for both.",
            category: .whyWeAsked
        ),
        SleepFact(
            id: "soc_3",
            pillar: .social,
            title: "Work-Life Balance",
            body: "Long work hours are the #1 reason adults cite for not getting enough sleep. Setting boundaries matters for your health.",
            statistic: "40% of adults sleep less than 7 hours",
            category: .cohortComparison
        ),
        SleepFact(
            id: "soc_4",
            pillar: .social,
            title: "Life Circumstances Matter",
            body: "We ask about your living situation because factors like caregiving, roommates, and work schedules directly impact when and how well you can sleep.",
            category: .whyWeAsked
        )
    ]

    // MARK: - Nutritional Facts

    static let nutritionalFacts: [SleepFact] = [
        SleepFact(
            id: "nut_1",
            pillar: .nutritional,
            title: "Caffeine Half-Life",
            body: "Caffeine has a 5-6 hour half-life. That 3 PM coffee still has half its caffeine in your system at 9 PM.",
            statistic: "Even 6 hours before bed, caffeine reduces sleep by 1 hour",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "nut_2",
            pillar: .nutritional,
            title: "Alcohol & Sleep Architecture",
            body: "While alcohol helps you fall asleep faster, it fragments sleep and suppresses REM. The sleep you get is less restorative.",
            category: .scienceSpotlight
        ),
        SleepFact(
            id: "nut_3",
            pillar: .nutritional,
            title: "Sleep-Friendly Foods",
            body: "Tryptophan-rich foods, magnesium, and complex carbs can support sleep. What you eat affects how you sleep.",
            category: .sleepTip
        ),
        SleepFact(
            id: "nut_4",
            pillar: .nutritional,
            title: "Timing Your Last Meal",
            body: "Eating within 2-3 hours of bedtime can disrupt sleep quality. Your digestive system needs time to wind down too.",
            category: .sleepTip
        )
    ]

    // MARK: - Sleep Log Encouragement Facts (Calibration Period)

    /// Facts specifically for the Sleep Log section during the 2-week calibration period
    /// These encourage users and explain why the detailed logging matters
    static let sleepLogEncouragementFacts: [SleepFact] = [
        SleepFact(
            id: "cal_1",
            pillar: .sleepQuality,
            title: "Building Your Sleep Profile",
            body: "This 2-week calibration captures your natural patterns. After this initial period, logging gets faster as we learn your unique rhythms.",
            statistic: "Your baseline will be complete in just 14 days",
            category: .calibrationEncouragement
        ),
        SleepFact(
            id: "cal_2",
            pillar: .sleepQuality,
            title: "Your Hard Work Pays Off",
            body: "The detailed data you're providing creates the most comprehensive sleep baseline possible. This precision enables truly personalized recommendations.",
            category: .calibrationEncouragement
        ),
        SleepFact(
            id: "cal_3",
            pillar: .sleepTiming,
            title: "Stanford Sleep Science",
            body: "These questions come from the Stanford Sleep Diary - the gold standard in sleep research. Clinicians worldwide use this exact method.",
            citation: "Stanford Sleep Health and Insomnia Program",
            category: .calibrationEncouragement
        ),
        SleepFact(
            id: "cal_4",
            pillar: .sleepQuality,
            title: "Almost There!",
            body: "Every morning log builds a clearer picture of your sleep. After calibration, we'll reveal patterns you never knew existed.",
            category: .calibrationEncouragement
        ),
        SleepFact(
            id: "cal_5",
            pillar: .sleepTiming,
            title: "Clinical-Grade Data",
            body: "Sleep clinics ask these exact questions. You're building the same quality data that helps doctors diagnose sleep disorders.",
            statistic: "Used by 500+ sleep clinics worldwide",
            category: .calibrationEncouragement
        ),
        SleepFact(
            id: "cal_6",
            pillar: .sleepQuality,
            title: "Patterns Are Emerging",
            body: "With each day's data, our system gets smarter about YOUR sleep. The first two weeks teach us the most about your unique patterns.",
            category: .calibrationEncouragement
        ),
        SleepFact(
            id: "cal_7",
            pillar: .sleepTiming,
            title: "Why Every Detail Matters",
            body: "Bedtime, wake time, quality ratings - each piece helps distinguish your unique sleep fingerprint from everyone else's.",
            category: .calibrationEncouragement
        ),
        SleepFact(
            id: "cal_8",
            pillar: .sleepQuality,
            title: "The Calibration Advantage",
            body: "Users who complete the full 2-week calibration see significantly more accurate recommendations than those who skip days.",
            statistic: "40% more accurate recommendations with complete data",
            category: .calibrationEncouragement
        )
    ]

    // MARK: - Helpers

    /// Get facts for a specific pillar
    static func facts(for pillar: Pillar) -> [SleepFact] {
        all.filter { $0.pillar == pillar }
    }

    /// Get facts matching any of the given pillars
    static func facts(for pillars: [Pillar]) -> [SleepFact] {
        all.filter { pillars.contains($0.pillar) }
    }

    /// Get random fact from a pillar
    static func randomFact(for pillar: Pillar) -> SleepFact? {
        facts(for: pillar).randomElement()
    }
}
