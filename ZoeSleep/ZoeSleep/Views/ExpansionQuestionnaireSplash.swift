//
//  ExpansionQuestionnaireSplash.swift
//  Zoe Sleep for Longevity System
//
//  Splash screen that explains the rationale for each validated questionnaire
//  Shows peer-review citations and what the assessment measures
//
//  CIRCADIAN-AWARE: Uses warm amber colors at night, no blue light
//

import SwiftUI

// MARK: - Questionnaire Validation Info

/// Validated information about each standardized questionnaire
/// All citation counts and validation data are from peer-reviewed sources
struct QuestionnaireValidationInfo {
    let id: String                      // Module ID (e.g., "expansion_isi")
    let fullName: String                // Full questionnaire name
    let abbreviation: String            // Short form (e.g., "ISI")
    let originalAuthors: String         // Primary author(s)
    let originalYear: Int               // Year first published
    let originalJournal: String         // Publication venue
    let validationStudiesCount: String  // Approximate citation/validation count
    let sensitivity: String?            // Sensitivity percentage if known
    let specificity: String?            // Specificity percentage if known
    let cronbachAlpha: String?          // Internal consistency if known
    let purpose: String                 // What it measures (patient-friendly)
    let whyWeAsk: String                // Why this matters for their care
    let estimatedMinutes: Int           // Time to complete
    let questionCount: Int              // Number of questions
    let icon: String                    // SF Symbol name
    let category: QuestionnaireCategory // Category for grouping

    enum QuestionnaireCategory: String {
        case insomnia = "Sleep Quality"
        case sleepiness = "Daytime Function"
        case mentalHealth = "Mental Health"
        case breathing = "Breathing & OSA"
        case physical = "Physical Health"
        case lifestyle = "Lifestyle"
        case chronotype = "Sleep Timing"
    }
}

// MARK: - Questionnaire Library

/// Static library of all validated questionnaire information
/// Data sourced from PubMed, systematic reviews, and original publications
struct QuestionnaireLibrary {

    static let all: [QuestionnaireValidationInfo] = [

        // MARK: - Insomnia Assessments

        QuestionnaireValidationInfo(
            id: "expansion_isi",
            fullName: "Insomnia Severity Index",
            abbreviation: "ISI",
            originalAuthors: "Morin, Belleville, Bélanger & Ivers",
            originalYear: 2011,
            originalJournal: "SLEEP",
            validationStudiesCount: "2,500+",
            sensitivity: "89.6%",
            specificity: "86.5%",
            cronbachAlpha: "0.90",
            purpose: "Measures the severity of your insomnia symptoms and how they affect your daily life",
            whyWeAsk: "Understanding the severity of your sleep difficulties helps us tailor the right level of support. The ISI is the gold standard for tracking insomnia treatment progress.",
            estimatedMinutes: 3,
            questionCount: 7,
            icon: "moon.zzz.fill",
            category: .insomnia
        ),

        QuestionnaireValidationInfo(
            id: "expansion_dbas",
            fullName: "Dysfunctional Beliefs and Attitudes about Sleep",
            abbreviation: "DBAS-16",
            originalAuthors: "Morin, Vallières & Ivers",
            originalYear: 2007,
            originalJournal: "SLEEP",
            validationStudiesCount: "1,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.79",
            purpose: "Identifies unhelpful thoughts and beliefs about sleep that may be keeping you awake",
            whyWeAsk: "Research shows that changing how we think about sleep is often more effective than medication. Understanding your sleep beliefs helps us address the root causes of insomnia.",
            estimatedMinutes: 8,
            questionCount: 16,
            icon: "brain.head.profile",
            category: .insomnia
        ),

        QuestionnaireValidationInfo(
            id: "expansion_sleep_hygiene",
            fullName: "Sleep Hygiene Index",
            abbreviation: "SHI",
            originalAuthors: "Mastin, Bryson & Corwyn",
            originalYear: 2006,
            originalJournal: "Journal of Behavioral Medicine",
            validationStudiesCount: "500+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.66",
            purpose: "Assesses your daily habits and behaviors that may be affecting your sleep quality",
            whyWeAsk: "Small changes in daily habits can have a big impact on sleep. This helps us identify simple adjustments that could improve your rest.",
            estimatedMinutes: 5,
            questionCount: 13,
            icon: "list.bullet.clipboard",
            category: .insomnia
        ),

        QuestionnaireValidationInfo(
            id: "expansion_psas",
            fullName: "Pre-Sleep Arousal Scale",
            abbreviation: "PSAS",
            originalAuthors: "Nicassio, Mendlowitz, Fussell & Petras",
            originalYear: 1985,
            originalJournal: "Behaviour Research and Therapy",
            validationStudiesCount: "800+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.88",
            purpose: "Measures both mental and physical activation that occurs as you try to fall asleep",
            whyWeAsk: "Racing thoughts and physical tension are common barriers to sleep. Understanding your pre-sleep state helps us recommend the right relaxation strategies.",
            estimatedMinutes: 5,
            questionCount: 16,
            icon: "waveform.path.ecg",
            category: .insomnia
        ),

        // MARK: - Daytime Sleepiness & Function

        QuestionnaireValidationInfo(
            id: "expansion_ess",
            fullName: "Epworth Sleepiness Scale",
            abbreviation: "ESS",
            originalAuthors: "Murray Johns",
            originalYear: 1991,
            originalJournal: "SLEEP",
            validationStudiesCount: "10,000+",
            sensitivity: "93.5%",
            specificity: "100%",
            cronbachAlpha: "0.88",
            purpose: "Measures your level of daytime sleepiness in everyday situations",
            whyWeAsk: "Excessive daytime sleepiness can signal underlying sleep disorders and affects your safety and quality of life. The ESS is used worldwide by sleep specialists.",
            estimatedMinutes: 3,
            questionCount: 8,
            icon: "sun.max.trianglebadge.exclamationmark",
            category: .sleepiness
        ),

        QuestionnaireValidationInfo(
            id: "expansion_fss",
            fullName: "Fatigue Severity Scale",
            abbreviation: "FSS",
            originalAuthors: "Krupp, LaRocca, Muir-Nash & Steinberg",
            originalYear: 1989,
            originalJournal: "Archives of Neurology",
            validationStudiesCount: "7,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.89",
            purpose: "Distinguishes true fatigue from sleepiness and measures how it impacts your daily activities",
            whyWeAsk: "Fatigue and sleepiness are different experiences with different solutions. Understanding which you're experiencing helps us provide the right support.",
            estimatedMinutes: 3,
            questionCount: 9,
            icon: "battery.25",
            category: .sleepiness
        ),

        QuestionnaireValidationInfo(
            id: "expansion_fosq",
            fullName: "Functional Outcomes of Sleep Questionnaire",
            abbreviation: "FOSQ-10",
            originalAuthors: "Chasens, Ratcliffe & Weaver",
            originalYear: 2009,
            originalJournal: "SLEEP",
            validationStudiesCount: "500+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.87",
            purpose: "Measures how sleepiness affects your ability to perform daily activities, work, and relationships",
            whyWeAsk: "Sleep problems don't just affect nights—they impact your whole life. Understanding these effects helps us prioritize what matters most to you.",
            estimatedMinutes: 4,
            questionCount: 10,
            icon: "figure.walk",
            category: .sleepiness
        ),

        // MARK: - Mental Health

        QuestionnaireValidationInfo(
            id: "expansion_phq9",
            fullName: "Patient Health Questionnaire",
            abbreviation: "PHQ-9",
            originalAuthors: "Kroenke, Spitzer & Williams",
            originalYear: 2001,
            originalJournal: "Journal of General Internal Medicine",
            validationStudiesCount: "15,000+",
            sensitivity: "88%",
            specificity: "88%",
            cronbachAlpha: "0.89",
            purpose: "Screens for depression symptoms that commonly accompany sleep difficulties",
            whyWeAsk: "Sleep and mood are deeply connected—improving one often helps the other. This helps us understand the full picture of your wellbeing.",
            estimatedMinutes: 3,
            questionCount: 9,
            icon: "heart.text.square",
            category: .mentalHealth
        ),

        QuestionnaireValidationInfo(
            id: "expansion_gad7",
            fullName: "Generalized Anxiety Disorder Scale",
            abbreviation: "GAD-7",
            originalAuthors: "Spitzer, Kroenke, Williams & Löwe",
            originalYear: 2006,
            originalJournal: "Archives of Internal Medicine",
            validationStudiesCount: "10,000+",
            sensitivity: "89%",
            specificity: "82%",
            cronbachAlpha: "0.92",
            purpose: "Screens for anxiety symptoms that can interfere with falling and staying asleep",
            whyWeAsk: "Anxiety and sleep problems often go hand in hand. Understanding your anxiety levels helps us recommend calming strategies that work.",
            estimatedMinutes: 2,
            questionCount: 7,
            icon: "bolt.heart",
            category: .mentalHealth
        ),

        QuestionnaireValidationInfo(
            id: "expansion_dass21",
            fullName: "Depression Anxiety Stress Scales",
            abbreviation: "DASS-21",
            originalAuthors: "Lovibond & Lovibond",
            originalYear: 1995,
            originalJournal: "Psychology Foundation of Australia",
            validationStudiesCount: "20,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.93",
            purpose: "Provides a comprehensive view of depression, anxiety, and stress levels",
            whyWeAsk: "This widely-validated assessment helps us understand the emotional factors affecting your sleep from multiple angles.",
            estimatedMinutes: 7,
            questionCount: 21,
            icon: "chart.bar.doc.horizontal",
            category: .mentalHealth
        ),

        QuestionnaireValidationInfo(
            id: "expansion_promis_cognitive",
            fullName: "PROMIS Cognitive Function",
            abbreviation: "PROMIS-Cog",
            originalAuthors: "NIH PROMIS Initiative",
            originalYear: 2010,
            originalJournal: "NIH/National Institutes of Health",
            validationStudiesCount: "2,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.95",
            purpose: "Assesses your perceived cognitive abilities including memory, concentration, and mental clarity",
            whyWeAsk: "Poor sleep significantly affects thinking and memory. Tracking cognitive function helps us measure how sleep improvements affect your mental sharpness.",
            estimatedMinutes: 2,
            questionCount: 8,
            icon: "brain",
            category: .mentalHealth
        ),

        // MARK: - Sleep Apnea Screening

        QuestionnaireValidationInfo(
            id: "expansion_stop_bang",
            fullName: "STOP-BANG Sleep Apnea Screening",
            abbreviation: "STOP-BANG",
            originalAuthors: "Chung, Yegneswaran, Liao et al.",
            originalYear: 2008,
            originalJournal: "Anesthesiology",
            validationStudiesCount: "5,000+",
            sensitivity: "93%",
            specificity: "43%",
            cronbachAlpha: nil,
            purpose: "Screens for risk factors associated with obstructive sleep apnea",
            whyWeAsk: "Sleep apnea affects 1 in 5 adults and often goes undiagnosed. Early detection can prevent serious health consequences and dramatically improve sleep quality.",
            estimatedMinutes: 2,
            questionCount: 8,
            icon: "lungs",
            category: .breathing
        ),

        QuestionnaireValidationInfo(
            id: "expansion_berlin",
            fullName: "Berlin Questionnaire",
            abbreviation: "Berlin",
            originalAuthors: "Netzer, Stoohs, Netzer, Clark & Strohl",
            originalYear: 1999,
            originalJournal: "Annals of Internal Medicine",
            validationStudiesCount: "3,000+",
            sensitivity: "86%",
            specificity: "77%",
            cronbachAlpha: nil,
            purpose: "Identifies individuals at high risk for sleep apnea based on symptoms and risk factors",
            whyWeAsk: "The Berlin questionnaire was developed specifically for primary care settings and helps determine if further sleep testing may be beneficial.",
            estimatedMinutes: 3,
            questionCount: 10,
            icon: "wind",
            category: .breathing
        ),

        // MARK: - Physical Health

        QuestionnaireValidationInfo(
            id: "expansion_bpi",
            fullName: "Brief Pain Inventory",
            abbreviation: "BPI",
            originalAuthors: "Charles S. Cleeland",
            originalYear: 1994,
            originalJournal: "Annals of the Academy of Medicine, Singapore",
            validationStudiesCount: "6,300+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.87",
            purpose: "Measures pain severity and how it interferes with your daily life and sleep",
            whyWeAsk: "Pain is one of the most common causes of poor sleep. Understanding your pain patterns helps us address this barrier to restful nights.",
            estimatedMinutes: 4,
            questionCount: 11,
            icon: "hand.point.up.left",
            category: .physical
        ),

        // MARK: - Lifestyle

        QuestionnaireValidationInfo(
            id: "expansion_medas",
            fullName: "Mediterranean Diet Adherence Screener",
            abbreviation: "MEDAS",
            originalAuthors: "PREDIMED Study Group",
            originalYear: 2011,
            originalJournal: "Journal of Nutrition",
            validationStudiesCount: "1,500+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: nil,
            purpose: "Assesses your dietary patterns and their potential impact on sleep quality",
            whyWeAsk: "What you eat affects how you sleep. The Mediterranean diet has been linked to better sleep quality in numerous studies.",
            estimatedMinutes: 4,
            questionCount: 14,
            icon: "leaf",
            category: .lifestyle
        ),

        // MARK: - Chronotype

        QuestionnaireValidationInfo(
            id: "expansion_meq",
            fullName: "Morningness-Eveningness Questionnaire",
            abbreviation: "MEQ",
            originalAuthors: "Horne & Östberg",
            originalYear: 1976,
            originalJournal: "International Journal of Chronobiology",
            validationStudiesCount: "4,000+",
            sensitivity: nil,
            specificity: nil,
            cronbachAlpha: "0.82",
            purpose: "Determines your natural chronotype—whether you're naturally a morning person or night owl",
            whyWeAsk: "Working with your body's natural rhythm, rather than against it, is key to sustainable sleep improvement. This helps us personalize timing recommendations.",
            estimatedMinutes: 7,
            questionCount: 19,
            icon: "clock.arrow.2.circlepath",
            category: .chronotype
        )
    ]

    /// Get validation info for a specific module ID
    static func info(for moduleId: String) -> QuestionnaireValidationInfo? {
        // Handle part1/part2 suffixes by matching base module ID
        let baseId = moduleId
            .replacingOccurrences(of: "_part1", with: "")
            .replacingOccurrences(of: "_part2", with: "")

        return all.first { $0.id == baseId }
    }

    /// Get validation info for multiple module IDs (for combined splash screens)
    static func infos(for moduleIds: [String]) -> [QuestionnaireValidationInfo] {
        let uniqueBaseIds = Set(moduleIds.map { moduleId in
            moduleId
                .replacingOccurrences(of: "_part1", with: "")
                .replacingOccurrences(of: "_part2", with: "")
        })

        return uniqueBaseIds.compactMap { baseId in
            all.first { $0.id == baseId }
        }
    }
}

// MARK: - Expansion Questionnaire Splash View

/// Full-screen splash that explains the rationale for an expansion questionnaire
/// Shown once when user first encounters an expansion pack on a given day
struct ExpansionQuestionnaireSplashView: View {
    let info: QuestionnaireValidationInfo
    let triggeredGateways: [GatewayType]
    let onContinue: () -> Void

    @State private var isAnimating = false
    @EnvironmentObject var themeManager: ThemeManager

    // Circadian-aware colors
    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var primaryTextColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.996, green: 0.953, blue: 0.780)  // Bright cream
            : Color.primary
    }

    private var secondaryTextColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.988, green: 0.827, blue: 0.302)  // Golden yellow
            : Color.secondary
    }

    private var accentColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.95, green: 0.6, blue: 0.2)  // Warm amber
            : Color(red: 0.13, green: 0.59, blue: 0.95)  // Blue
    }

    private var backgroundColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.12, green: 0.08, blue: 0.05)  // Dark warm brown
            : Color(.systemBackground)
    }

    private var cardBackgroundColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.18, green: 0.12, blue: 0.08)  // Slightly lighter brown
            : Color(.secondarySystemBackground)
    }

    var body: some View {
        ZStack {
            // Background
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Animated Icon
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(
                                .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                value: isAnimating
                            )

                        Circle()
                            .fill(accentColor.opacity(0.25))
                            .frame(width: 90, height: 90)

                        Image(systemName: info.icon)
                            .font(.system(size: 40))
                            .foregroundColor(accentColor)
                    }
                    .padding(.top, 40)

                    // Title Section
                    VStack(spacing: 8) {
                        Text(info.fullName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                            .multilineTextAlignment(.center)

                        Text("(\(info.abbreviation))")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal)

                    // Validation Badge
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)

                        Text("Peer-Reviewed & Validated")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )

                    // Stats Row
                    HStack(spacing: 20) {
                        StatBadge(
                            value: "\(info.questionCount)",
                            label: "Questions",
                            icon: "list.bullet",
                            color: accentColor,
                            textColor: primaryTextColor
                        )

                        StatBadge(
                            value: "~\(info.estimatedMinutes)",
                            label: "Minutes",
                            icon: "clock",
                            color: accentColor,
                            textColor: primaryTextColor
                        )

                        StatBadge(
                            value: info.validationStudiesCount,
                            label: "Citations",
                            icon: "doc.text",
                            color: accentColor,
                            textColor: primaryTextColor
                        )
                    }
                    .padding(.horizontal)

                    // What This Measures Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(accentColor)
                            Text("What This Measures")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                        }

                        Text(info.purpose)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackgroundColor)
                    )
                    .padding(.horizontal)

                    // Why We're Asking Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Why We're Asking")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                        }

                        Text(info.whyWeAsk)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackgroundColor)
                    )
                    .padding(.horizontal)

                    // Scientific Credibility Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(accentColor)
                            Text("Scientific Background")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            credentialRow(label: "Developed by", value: info.originalAuthors)
                            credentialRow(label: "First published", value: "\(info.originalYear) in \(info.originalJournal)")

                            if let sensitivity = info.sensitivity, let specificity = info.specificity {
                                credentialRow(label: "Accuracy", value: "\(sensitivity) sensitivity, \(specificity) specificity")
                            }

                            if let alpha = info.cronbachAlpha {
                                credentialRow(label: "Reliability", value: "Cronbach's α = \(alpha)")
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackgroundColor)
                    )
                    .padding(.horizontal)

                    // Gateway Trigger Explanation (if applicable)
                    if !triggeredGateways.isEmpty {
                        gatewayExplanationCard
                    }

                    Spacer(minLength: 100)
                }
            }

            // Continue Button (fixed at bottom)
            VStack {
                Spacer()

                Button(action: onContinue) {
                    HStack {
                        Text("Begin Assessment")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .background(
                    LinearGradient(
                        colors: [backgroundColor.opacity(0), backgroundColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }

    // MARK: - Helper Views

    private func credentialRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(secondaryTextColor.opacity(0.8))
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gatewayExplanationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill.checkmark")
                    .foregroundColor(.orange)
                Text("Personalized for You")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryTextColor)
            }

            Text("Based on your earlier responses, we noticed potential concerns related to \(gatewayDescriptions). This assessment will help us understand this area better.")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
        )
        .padding(.horizontal)
    }

    private var gatewayDescriptions: String {
        let names = triggeredGateways.map { $0.displayName.lowercased() }
        if names.count == 1 {
            return names[0]
        } else if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        } else {
            let allButLast = names.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(names.last ?? "")"
        }
    }
}

// MARK: - Stat Badge Component

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let textColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(textColor)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(textColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Multi-Questionnaire Splash (for days with multiple assessments)

/// Shows a combined splash when multiple questionnaires are triggered on the same day
struct ExpansionDaySplashView: View {
    let questionnaires: [QuestionnaireValidationInfo]
    let dayNumber: Int
    let triggeredGateways: [GatewayType]
    let onContinue: () -> Void

    @State private var isAnimating = false

    private var isEvening: Bool {
        TimePeriod.current == .evening || TimePeriod.current == .night
    }

    private var primaryTextColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.996, green: 0.953, blue: 0.780)
            : Color.primary
    }

    private var secondaryTextColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.988, green: 0.827, blue: 0.302)
            : Color.secondary
    }

    private var accentColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.95, green: 0.6, blue: 0.2)
            : Color(red: 0.13, green: 0.59, blue: 0.95)
    }

    private var backgroundColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.12, green: 0.08, blue: 0.05)
            : Color(.systemBackground)
    }

    private var cardBackgroundColor: Color {
        CircadianPalette.current.isDark
            ? Color(red: 0.18, green: 0.12, blue: 0.08)
            : Color(.secondarySystemBackground)
    }

    private var totalQuestions: Int {
        questionnaires.reduce(0) { $0 + $1.questionCount }
    }

    private var totalMinutes: Int {
        questionnaires.reduce(0) { $0 + $1.estimatedMinutes }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(accentColor.opacity(0.15))
                                .frame(width: 100, height: 100)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(
                                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                    value: isAnimating
                                )

                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundColor(accentColor)
                        }

                        Text("Day \(dayNumber) Expansion Pack")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)

                        Text("Personalized assessments based on your journey")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // Summary Stats
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(questionnaires.count)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text("Assessments")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text("\(totalQuestions)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text("Questions")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack {
                            Text("~\(totalMinutes)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                            Text("Minutes")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    .padding(.vertical, 16)

                    // Questionnaire List
                    VStack(spacing: 12) {
                        ForEach(questionnaires, id: \.id) { info in
                            QuestionnaireListCard(info: info, cardBackgroundColor: cardBackgroundColor, primaryTextColor: primaryTextColor, secondaryTextColor: secondaryTextColor, accentColor: accentColor)
                        }
                    }
                    .padding(.horizontal)

                    // Why These Assessments
                    if !triggeredGateways.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.fill.checkmark")
                                    .foregroundColor(.orange)
                                Text("Why These Assessments?")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(primaryTextColor)
                            }

                            Text("Your earlier responses indicated areas where a deeper assessment would be valuable. Each of these questionnaires is a peer-reviewed clinical tool used by sleep specialists worldwide.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackgroundColor)
                        )
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
            }

            // Continue Button
            VStack {
                Spacer()

                Button(action: onContinue) {
                    HStack {
                        Text("Begin Assessments")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .background(
                    LinearGradient(
                        colors: [backgroundColor.opacity(0), backgroundColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Questionnaire List Card

struct QuestionnaireListCard: View {
    let info: QuestionnaireValidationInfo
    let cardBackgroundColor: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: info.icon)
                    .font(.system(size: 18))
                    .foregroundColor(accentColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(info.abbreviation)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryTextColor)

                Text(info.fullName)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(1)
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(info.questionCount) Q")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(primaryTextColor)

                Text("\(info.validationStudiesCount) citations")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(secondaryTextColor.opacity(0.8))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
        )
    }
}

// MARK: - Preview

#Preview("Single Questionnaire") {
    if let info = QuestionnaireLibrary.info(for: "expansion_isi") {
        ExpansionQuestionnaireSplashView(
            info: info,
            triggeredGateways: [.insomnia],
            onContinue: {}
        )
        .environmentObject(ThemeManager.shared)
    }
}

#Preview("Multi-Questionnaire Day") {
    let infos = QuestionnaireLibrary.infos(for: ["expansion_stop_bang", "expansion_berlin", "expansion_bpi"])
    ExpansionDaySplashView(
        questionnaires: infos,
        dayNumber: 14,
        triggeredGateways: [.osa, .pain],
        onContinue: {}
    )
}
