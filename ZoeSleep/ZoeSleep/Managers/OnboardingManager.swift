//
//  OnboardingManager.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Manages user onboarding state and data collection
//  Onboarding state is tied to the user account, not the device
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

/// Measurement system preference
enum MeasurementSystem: String, CaseIterable, Identifiable {
    case metric = "Metric"
    case imperial = "Imperial"

    var id: String { rawValue }

    var heightUnit: String {
        switch self {
        case .metric: return "cm"
        case .imperial: return "ft/in"
        }
    }

    var weightUnit: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lbs"
        }
    }
}

/// Gender options
enum Gender: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case other = "Other"
    case preferNotToSay = "Prefer not to say"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        case .other: return "figure.2"
        case .preferNotToSay: return "person.fill.questionmark"
        }
    }
}

/// Wearable device options
enum WearableDevice: String, CaseIterable, Identifiable {
    case appleWatch = "Apple Watch"
    case ouraRing = "Oura Ring"
    case fitbit = "Fitbit"
    case garmin = "Garmin"
    case whoop = "WHOOP"
    case samsung = "Samsung Galaxy Watch"
    case other = "Other"
    case none = "None"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .appleWatch: return "applewatch"
        case .ouraRing: return "circle.circle"
        case .fitbit: return "waveform.path.ecg.rectangle"
        case .garmin: return "watchface.applewatch.case"
        case .whoop: return "waveform.badge.plus"
        case .samsung: return "watchface.applewatch.case"
        case .other: return "sensor.tag.radiowaves.forward"
        case .none: return "xmark.circle"
        }
    }
}

/// Onboarding step enum
/// FLOW: Disclaimer first, then personal connection, then HealthKit at the end for sleep history sync
/// Note: Wearables step removed - HealthKit provides actual device data
enum OnboardingStep: Int, CaseIterable {
    case disclaimer = 0         // Legal disclaimer - wellness only, data storage consent
    case name = 1               // Personal connection
    case heightWeight = 2       // Units + body metrics combined
    case genderAge = 3          // About you
    case healthConnect = 4      // Sync sleep/activity history (optional)
    case ready = 5

    var title: String {
        switch self {
        case .disclaimer: return "Important Information"
        case .name: return "Your Name"
        case .heightWeight: return "Body Metrics"
        case .genderAge: return "About You"
        case .healthConnect: return "Sleep History"
        case .ready: return "Ready"
        }
    }
}

/// User profile data collected during onboarding
struct OnboardingProfile: Codable {
    var name: String = ""
    var measurementSystem: String = MeasurementSystem.metric.rawValue
    var heightCm: Double? = nil  // Optional - only set when user provides or HealthKit fills
    var weightKg: Double? = nil  // Optional - only set when user provides or HealthKit fills
    var gender: String = Gender.preferNotToSay.rawValue
    var birthYear: Int = 1990
    var wearables: [String] = []
    var hasConnectedHealthKit: Bool = false
    var onboardingCompleted: Bool = false
    var completedAt: Date?
    var userId: String? // Track which user this profile belongs to

    /// Whether height and weight have been set (from HealthKit or user input)
    var hasBodyMetrics: Bool {
        return heightCm != nil && weightKg != nil
    }

    /// Calculate age from birth year
    var age: Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        return currentYear - birthYear
    }

    /// Height in feet and inches (for imperial display)
    var heightFeet: Int? {
        guard let height = heightCm else { return nil }
        let totalInches = height / 2.54
        return Int(totalInches / 12)
    }

    var heightInches: Int? {
        guard let height = heightCm else { return nil }
        let totalInches = height / 2.54
        return Int(totalInches) % 12
    }

    /// Weight in pounds (for imperial display)
    var weightLbs: Double? {
        guard let weight = weightKg else { return nil }
        return weight * 2.20462
    }
}

@MainActor
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    // MARK: - Published Properties

    @Published var currentStep: OnboardingStep = .name {
        didSet {
            if oldValue != currentStep {
                print("[Onboarding] ⚠️ currentStep CHANGED from \(oldValue.title) to \(currentStep.title)")
                // Print stack trace to see what's causing the change
                Thread.callStackSymbols.prefix(10).forEach { print("  \($0)") }

                // Auto-save whenever step changes to ensure we never lose progress
                UserDefaults.standard.set(currentStep.rawValue, forKey: currentStepKey)
                UserDefaults.standard.synchronize() // Force immediate write
                print("[Onboarding] ✅ Auto-saved step: \(currentStep.title) (raw: \(currentStep.rawValue))")
            }
        }
    }
    @Published var profile: OnboardingProfile = OnboardingProfile()
    @Published var isOnboardingComplete: Bool = false
    @Published var isCheckingServerState: Bool = false
    @Published var hasSeenJourneyIntro: Bool = false

    // Temporary editing state for height/weight input (default values for UI pickers)
    @Published var tempHeightFeet: Int = 5
    @Published var tempHeightInches: Int = 7
    @Published var tempWeightLbs: Double = 150
    @Published var tempHeightCm: Double = 170
    @Published var tempWeightKg: Double = 70

    // MARK: - Private Properties

    private let userDefaultsKey = "onboardingProfile"
    private let onboardingCompleteKey = "onboardingComplete"
    private let lastUserIdKey = "lastOnboardingUserId"
    private let journeyIntroSeenKey = "hasSeenJourneyIntro"
    private let currentStepKey = "onboardingCurrentStep"

    // MARK: - Initialization

    private init() {
        print("[Onboarding] 🟡 OnboardingManager.init() - SINGLETON INITIALIZATION")
        loadLocalProfile()
        detectSystemMeasurementSystem()
        hasSeenJourneyIntro = UserDefaults.standard.bool(forKey: journeyIntroSeenKey)
        print("[Onboarding] 🟡 Init complete - currentStep: \(currentStep.title), name: '\(profile.name)'")
    }

    // MARK: - User-Aware Onboarding State

    /// Check if a user needs onboarding (called after login)
    /// This checks the SERVER-SIDE state, not local storage
    func checkUserOnboardingState(userId: String, serverOnboardingCompleted: Bool?) async {
        await checkUserOnboardingState(
            userId: userId,
            serverOnboardingCompleted: serverOnboardingCompleted,
            serverProfile: nil
        )
    }

    /// Check if a user needs onboarding with full profile data from server
    func checkUserOnboardingState(
        userId: String,
        serverOnboardingCompleted: Bool?,
        serverProfile: (fullName: String?, measurementSystem: String?, heightCm: Double?, weightKg: Double?, gender: String?, birthYear: Int?)?
    ) async {
        print("[Onboarding] 🔵 checkUserOnboardingState CALLED")
        print("[Onboarding] - userId: \(userId)")
        print("[Onboarding] - serverOnboardingCompleted: \(String(describing: serverOnboardingCompleted))")
        print("[Onboarding] - currentStep BEFORE check: \(currentStep.title)")

        let lastUserId = UserDefaults.standard.string(forKey: lastUserIdKey)
        print("[Onboarding] - lastUserId from storage: \(lastUserId ?? "nil")")
        print("[Onboarding] - Current profile name: '\(profile.name)'")

        // If this is a different user than before, reset local state
        if lastUserId != userId {
            print("[Onboarding] ⚠️ Different user detected! Last: \(lastUserId ?? "nil"), New: \(userId)")
            print("[Onboarding] 🔄 Resetting local state...")
            resetLocalState()
            // Also reset questionnaire state for the new user
            QuestionnaireManager.shared.resetForNewUser()
            UserDefaults.standard.set(userId, forKey: lastUserIdKey)
            print("[Onboarding] ✅ Local state reset. Profile name is now: '\(profile.name)'")
        } else {
            print("[Onboarding] Same user, keeping local state")
        }

        // Check server-side onboarding state
        print("[Onboarding] Server onboarding completed: \(String(describing: serverOnboardingCompleted))")
        print("[Onboarding] Server profile data: name=\(serverProfile?.fullName ?? "nil")")

        if let completed = serverOnboardingCompleted, completed {
            print("[Onboarding] User has completed onboarding (server)")
            isOnboardingComplete = true
            profile.onboardingCompleted = true
            profile.userId = userId

            // Load profile data from server if available
            if let serverData = serverProfile {
                if let name = serverData.fullName {
                    profile.name = name
                }
                if let measurementSystem = serverData.measurementSystem {
                    profile.measurementSystem = measurementSystem
                    print("[Onboarding] Loaded measurement system from server: \(measurementSystem)")
                }
                if let heightCm = serverData.heightCm {
                    profile.heightCm = heightCm
                }
                if let weightKg = serverData.weightKg {
                    profile.weightKg = weightKg
                }
                if let gender = serverData.gender {
                    profile.gender = gender
                }
                if let birthYear = serverData.birthYear {
                    profile.birthYear = birthYear
                }
                // Update imperial conversion values
                updateImperialFromMetric()
            }

            saveLocalProfile()
        } else {
            print("[Onboarding] User needs onboarding")
            isOnboardingComplete = false
            profile.onboardingCompleted = false
            profile.userId = userId
            // For new users, always detect locale for measurement system
            detectSystemMeasurementSystem()
            print("[Onboarding] Applied locale detection: \(profile.measurementSystem)")
        }
    }

    /// Complete onboarding and save to server
    func completeOnboarding() {
        profile.onboardingCompleted = true
        profile.completedAt = Date()
        saveLocalProfile()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isOnboardingComplete = true
        }

        // Save to server
        Task {
            await saveOnboardingToServer()
        }

        // Request notification permission and schedule reminders
        setupNotifications()
    }

    /// Request notification permission and schedule daily reminders
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("[Onboarding] Notification permission error: \(error)")
                return
            }

            if granted {
                print("[Onboarding] Notification permission granted - scheduling reminders")
                // Schedule reminders with default times (9 AM morning, 8 PM evening)
                Task {
                    await NotificationManager.shared.scheduleFromSavedSettings()
                }
            } else {
                print("[Onboarding] Notification permission denied")
            }
        }
    }

    /// Save onboarding completion and profile to server
    private func saveOnboardingToServer() async {
        do {
            // Build updates dictionary, only including values that exist
            var updates: [String: Any] = [
                "onboardingCompleted": true,
                "displayName": profile.name,
                "gender": profile.gender,
                "birthYear": profile.birthYear,
                "wearables": profile.wearables,
                "appleHealthConnected": profile.hasConnectedHealthKit,
                "measurementSystem": profile.measurementSystem
            ]

            // Only include height/weight if they've been set
            if let height = profile.heightCm {
                updates["heightCm"] = height
            }
            if let weight = profile.weightKg {
                updates["weightKg"] = weight
            }

            try await ConvexService.shared.updateUserProfile(updates: updates)
            print("[Onboarding] ✅ Saved to server")
        } catch {
            print("[Onboarding] ⚠️ Failed to save to server: \(error)")
            // Profile is saved locally, will retry on next app launch
        }
    }

    /// Reset local state for a new user - intro screens show for each new user
    private func resetLocalState() {
        print("[Onboarding] 🔴 resetLocalState() CALLED - resetting to name step")
        print("[Onboarding] Stack trace:")
        Thread.callStackSymbols.prefix(15).forEach { print("  \($0)") }

        profile = OnboardingProfile()
        currentStep = .name  // Start at name step for personal connection
        isOnboardingComplete = false
        hasSeenJourneyIntro = false  // Reset for new user - they need to see intro
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.set(false, forKey: onboardingCompleteKey)
        UserDefaults.standard.set(false, forKey: journeyIntroSeenKey)
        UserDefaults.standard.set(0, forKey: currentStepKey)  // Reset step to name
        detectSystemMeasurementSystem()
    }

    /// Clear onboarding state when user signs out
    func clearForSignOut() {
        profile = OnboardingProfile()
        currentStep = .name  // Start at name step for personal connection
        isOnboardingComplete = false
        hasSeenJourneyIntro = false  // Reset for new user
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.set(false, forKey: onboardingCompleteKey)
        UserDefaults.standard.set(false, forKey: journeyIntroSeenKey)
        UserDefaults.standard.set(0, forKey: currentStepKey)  // Reset step to name
        print("[Onboarding] Cleared for sign out")
    }

    // MARK: - System Detection

    /// Detect the user's actual measurement system preference from iOS settings
    /// Uses Locale.current.usesMetricSystem which correctly reads Settings > General > Language & Region > Measurement System
    func detectSystemMeasurementSystem() {
        if Locale.current.usesMetricSystem {
            profile.measurementSystem = MeasurementSystem.metric.rawValue
        } else {
            profile.measurementSystem = MeasurementSystem.imperial.rawValue
        }

        // Initialize imperial temp values from metric
        updateImperialFromMetric()
    }

    /// Update imperial temp values from metric profile values
    func updateImperialFromMetric() {
        if let height = profile.heightCm {
            let totalInches = height / 2.54
            tempHeightFeet = Int(totalInches / 12)
            tempHeightInches = Int(totalInches) % 12
            tempHeightCm = height
        }
        if let weight = profile.weightKg {
            tempWeightLbs = weight * 2.20462
            tempWeightKg = weight
        }
    }

    /// Update metric profile values from imperial temp values
    func updateMetricFromImperial() {
        let totalInches = Double(tempHeightFeet * 12 + tempHeightInches)
        profile.heightCm = totalInches * 2.54
        profile.weightKg = tempWeightLbs / 2.20462
    }

    /// Update profile from metric temp values
    func updateProfileFromMetric() {
        profile.heightCm = tempHeightCm
        profile.weightKg = tempWeightKg
    }

    // MARK: - Pre-fill from Sign Up / Login

    /// Pre-fill profile with data from authentication
    /// Call this after user signs up or logs in with Apple
    func prefillFromAuth(name: String?, email: String?) {
        // Extract first name from full name or email
        if let fullName = name, !fullName.isEmpty {
            // Use first word as display name (e.g., "John Doe" -> "John")
            let firstName = fullName.components(separatedBy: " ").first ?? fullName
            profile.name = firstName
            print("[Onboarding] Pre-filled name from auth: \(firstName)")
        } else if let email = email {
            // Extract name from email (e.g., "john.doe@email.com" -> "John")
            let localPart = email.components(separatedBy: "@").first ?? ""
            let namePart = localPart.components(separatedBy: CharacterSet(charactersIn: "._-")).first ?? localPart
            if !namePart.isEmpty {
                profile.name = namePart.capitalized
                print("[Onboarding] Pre-filled name from email: \(profile.name)")
            }
        }
    }

    /// Pre-fill from HealthKit data on app start
    func prefillFromSystemData() {
        // Measurement system from locale (already done in init)
        // Height/weight will come from HealthKit when connected
        print("[Onboarding] System data pre-filled (measurement system: \(profile.measurementSystem))")
    }

    // MARK: - Navigation

    /// Move to next step, skipping steps with pre-filled data
    func nextStep() {
        var nextIndex = currentStep.rawValue + 1

        // Find the next step that needs user input
        while let step = OnboardingStep(rawValue: nextIndex) {
            if shouldSkipStep(step) {
                nextIndex += 1
                continue
            }
            break
        }

        guard let nextStep = OnboardingStep(rawValue: nextIndex) else {
            completeOnboarding()
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentStep = nextStep
        }
        // Save progress after each step advance
        saveLocalProfile()
    }

    /// Check if a step should be skipped
    /// New flow: No steps are auto-skipped - user goes through all steps to establish personal connection
    func shouldSkipStep(_ step: OnboardingStep) -> Bool {
        // All steps are shown in the new flow
        // HealthKit is now at the end for syncing sleep history, not for pre-filling data
        return false
    }

    func previousStep() {
        var prevIndex = currentStep.rawValue - 1

        // Find the previous step that wasn't skipped
        while prevIndex >= 0 {
            if let step = OnboardingStep(rawValue: prevIndex), !shouldSkipStep(step) {
                break
            }
            prevIndex -= 1
        }

        guard let prevStep = OnboardingStep(rawValue: max(0, prevIndex)) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentStep = prevStep
        }
        // Save progress after going back
        saveLocalProfile()
    }

    func goToStep(_ step: OnboardingStep) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentStep = step
        }
        // Save progress after step change
        saveLocalProfile()
    }

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case .disclaimer:
            return true // User must explicitly tap "I Understand" button
        case .name:
            return !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .heightWeight:
            guard let height = profile.heightCm, let weight = profile.weightKg else {
                return false
            }
            return height > 0 && weight > 0
        case .genderAge:
            return profile.birthYear > 1900 && profile.birthYear <= Calendar.current.component(.year, from: Date())
        case .healthConnect:
            return true // Can proceed even without connecting
        case .ready:
            return true
        }
    }

    // MARK: - Wearables Management

    func toggleWearable(_ device: WearableDevice) {
        if device == .none {
            // If "None" is selected, clear all others
            profile.wearables = [device.rawValue]
        } else {
            // Remove "None" if selecting a device
            profile.wearables.removeAll { $0 == WearableDevice.none.rawValue }

            if profile.wearables.contains(device.rawValue) {
                profile.wearables.removeAll { $0 == device.rawValue }
            } else {
                profile.wearables.append(device.rawValue)
            }
        }
    }

    func isWearableSelected(_ device: WearableDevice) -> Bool {
        profile.wearables.contains(device.rawValue)
    }

    // MARK: - Local Persistence (backup for offline use)

    private func saveLocalProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
        UserDefaults.standard.set(isOnboardingComplete, forKey: onboardingCompleteKey)
        // Persist current step so user doesn't lose progress if app restarts
        UserDefaults.standard.set(currentStep.rawValue, forKey: currentStepKey)
        print("[Onboarding] Saved profile and step: \(currentStep.title)")
    }

    private func loadLocalProfile() {
        print("[Onboarding] 🟢 loadLocalProfile() called")

        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(OnboardingProfile.self, from: data) {
            self.profile = decoded
            self.isOnboardingComplete = decoded.onboardingCompleted
            updateImperialFromMetric()
            print("[Onboarding] - Loaded profile: name='\(decoded.name)', onboardingCompleted=\(decoded.onboardingCompleted)")
        } else {
            print("[Onboarding] - No saved profile found")
        }

        // Restore current step from persistence
        let savedStepRaw = UserDefaults.standard.integer(forKey: currentStepKey)
        print("[Onboarding] - Saved step raw value: \(savedStepRaw)")

        if let step = OnboardingStep(rawValue: savedStepRaw) {
            print("[Onboarding] - Parsed step: \(step.title)")
            // Only restore step if not completed - otherwise start fresh
            if !isOnboardingComplete {
                self.currentStep = step
                print("[Onboarding] ✅ Restored step to: \(step.title)")
            } else {
                print("[Onboarding] - Onboarding complete, not restoring step")
            }
        } else {
            print("[Onboarding] - Invalid step raw value, keeping default")
        }

        // Check legacy key as well
        if UserDefaults.standard.bool(forKey: onboardingCompleteKey) {
            self.isOnboardingComplete = true
        }
    }

    /// Reset onboarding for testing purposes
    func resetOnboarding() {
        resetLocalState()

        // Also clear on server
        Task {
            do {
                try await ConvexService.shared.updateUserProfile(updates: [
                    "onboardingCompleted": false
                ])
                print("[Onboarding] Reset on server")
            } catch {
                print("[Onboarding] Failed to reset on server: \(error)")
            }
        }
    }

    // MARK: - HealthKit Integration

    func markHealthKitConnected() {
        profile.hasConnectedHealthKit = true
        saveLocalProfile()
    }

    /// Populate profile from HealthKit demographics if available
    func populateFromHealthKit(demographics: HealthKitDemographics) {
        if let heightCm = demographics.heightCm {
            profile.heightCm = heightCm
        }
        if let weightKg = demographics.weightKg {
            profile.weightKg = weightKg
        }
        if let age = demographics.age {
            let currentYear = Calendar.current.component(.year, from: Date())
            profile.birthYear = currentYear - age
        }
        if let sex = demographics.biologicalSex {
            switch sex.lowercased() {
            case "male": profile.gender = Gender.male.rawValue
            case "female": profile.gender = Gender.female.rawValue
            default: profile.gender = Gender.other.rawValue
            }
        }

        updateImperialFromMetric()
        saveLocalProfile()
    }

    // MARK: - Check If Should Show Onboarding

    /// Whether onboarding has been completed (for app root view)
    var hasCompletedOnboarding: Bool {
        return isOnboardingComplete || profile.onboardingCompleted
    }

    // MARK: - Journey Introduction

    /// Mark the journey introduction as seen (called when user completes or skips intro)
    func markJourneyIntroSeen() {
        hasSeenJourneyIntro = true
        UserDefaults.standard.set(true, forKey: journeyIntroSeenKey)
        print("[Onboarding] Journey intro marked as seen")
    }

    /// Reset journey intro for testing purposes
    func resetJourneyIntro() {
        hasSeenJourneyIntro = false
        UserDefaults.standard.set(false, forKey: journeyIntroSeenKey)
        print("[Onboarding] Journey intro reset")
    }
}
