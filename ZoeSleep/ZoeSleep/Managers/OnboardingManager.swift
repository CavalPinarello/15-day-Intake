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
/// FLOW: HealthKit FIRST to get all available data, then only ask what we couldn't get
enum OnboardingStep: Int, CaseIterable {
    case healthConnect = 0      // FIRST - get height, weight, age, sex from HealthKit
    case name = 1               // Ask for name (can't get from HealthKit)
    case heightWeight = 2       // Skipped if HealthKit provided data
    case genderAge = 3          // Skipped if HealthKit provided data
    case wearables = 4
    case ready = 5

    var title: String {
        switch self {
        case .healthConnect: return "Health Data"
        case .name: return "Your Name"
        case .heightWeight: return "Body Metrics"
        case .genderAge: return "About You"
        case .wearables: return "Devices"
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

    @Published var currentStep: OnboardingStep = .healthConnect
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

    // MARK: - Initialization

    private init() {
        loadLocalProfile()
        detectSystemMeasurementSystem()
        hasSeenJourneyIntro = UserDefaults.standard.bool(forKey: journeyIntroSeenKey)
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
        print("[Onboarding] Checking state for user: \(userId)")

        let lastUserId = UserDefaults.standard.string(forKey: lastUserIdKey)
        print("[Onboarding] Last user ID from storage: \(lastUserId ?? "nil")")
        print("[Onboarding] Current profile name before check: '\(profile.name)'")

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
        profile = OnboardingProfile()
        currentStep = .healthConnect  // Start at HealthKit step
        isOnboardingComplete = false
        hasSeenJourneyIntro = false  // Reset for new user - they need to see intro
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.set(false, forKey: onboardingCompleteKey)
        UserDefaults.standard.set(false, forKey: journeyIntroSeenKey)
        detectSystemMeasurementSystem()
    }

    /// Clear onboarding state when user signs out
    func clearForSignOut() {
        profile = OnboardingProfile()
        currentStep = .healthConnect  // Start at HealthKit step
        isOnboardingComplete = false
        hasSeenJourneyIntro = false  // Reset for new user
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.set(false, forKey: onboardingCompleteKey)
        UserDefaults.standard.set(false, forKey: journeyIntroSeenKey)
        print("[Onboarding] Cleared for sign out")
    }

    // MARK: - System Detection

    /// Detect the user's locale measurement system
    func detectSystemMeasurementSystem() {
        let locale = Locale.current
        // US, Liberia, and Myanmar use imperial
        let imperialRegions = ["US", "LR", "MM"]

        if let regionCode = locale.region?.identifier,
           imperialRegions.contains(regionCode) {
            profile.measurementSystem = MeasurementSystem.imperial.rawValue
        } else {
            profile.measurementSystem = MeasurementSystem.metric.rawValue
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
    }

    /// Check if a step should be skipped (has pre-filled data from HealthKit)
    func shouldSkipStep(_ step: OnboardingStep) -> Bool {
        switch step {
        case .healthConnect:
            // Never skip - always show HealthKit permission request first
            return false
        case .name:
            // Never skip name - we can't get it from HealthKit
            return false
        case .heightWeight:
            // Skip if HealthKit provided valid height and weight data
            guard let height = profile.heightCm, let weight = profile.weightKg else {
                return false  // Don't skip if no data available
            }
            return profile.hasConnectedHealthKit &&
                   height > 100 && height < 250 &&
                   weight > 30 && weight < 300
        case .genderAge:
            // Skip if HealthKit provided both gender and age
            let hasValidGender = profile.gender != Gender.preferNotToSay.rawValue
            let hasValidAge = profile.birthYear > 1920 && profile.birthYear < Calendar.current.component(.year, from: Date()) - 10
            return profile.hasConnectedHealthKit && hasValidGender && hasValidAge
        case .wearables:
            return false
        case .ready:
            return false
        }
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
    }

    func goToStep(_ step: OnboardingStep) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            currentStep = step
        }
    }

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case .healthConnect:
            return true // Can proceed even without connecting
        case .name:
            return !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .heightWeight:
            guard let height = profile.heightCm, let weight = profile.weightKg else {
                return false
            }
            return height > 0 && weight > 0
        case .genderAge:
            return profile.birthYear > 1900 && profile.birthYear <= Calendar.current.component(.year, from: Date())
        case .wearables:
            return true // Optional step
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
    }

    private func loadLocalProfile() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(OnboardingProfile.self, from: data) {
            self.profile = decoded
            self.isOnboardingComplete = decoded.onboardingCompleted
            updateImperialFromMetric()
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
