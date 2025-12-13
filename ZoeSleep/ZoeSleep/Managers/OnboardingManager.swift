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
/// NOTE: No welcome step - splash screen serves as welcome, onboarding starts with name
/// REVISED: HealthKit moved earlier to enable auto-fill of demographics
enum OnboardingStep: Int, CaseIterable {
    case name = 0
    case healthConnect = 1      // Moved earlier - before body metrics
    case measurementSystem = 2  // Auto-detected from locale, may be skipped
    case heightWeight = 3       // Skipped entirely if HealthKit provides data
    case genderAge = 4          // Skipped if HealthKit provides data
    case wearables = 5
    case sleepPhilosophy = 6
    case ready = 7

    var title: String {
        switch self {
        case .name: return "Your Name"
        case .healthConnect: return "Health Data"
        case .measurementSystem: return "Units"
        case .heightWeight: return "Body Metrics"
        case .genderAge: return "About You"
        case .wearables: return "Devices"
        case .sleepPhilosophy: return "Our Approach"
        case .ready: return "Ready"
        }
    }
}

/// User profile data collected during onboarding
struct OnboardingProfile: Codable {
    var name: String = ""
    var measurementSystem: String = MeasurementSystem.metric.rawValue
    var heightCm: Double = 170
    var weightKg: Double = 70
    var gender: String = Gender.preferNotToSay.rawValue
    var birthYear: Int = 1990
    var wearables: [String] = []
    var hasConnectedHealthKit: Bool = false
    var onboardingCompleted: Bool = false
    var completedAt: Date?
    var userId: String? // Track which user this profile belongs to

    /// Calculate age from birth year
    var age: Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        return currentYear - birthYear
    }

    /// Height in feet and inches (for imperial display)
    var heightFeet: Int {
        let totalInches = heightCm / 2.54
        return Int(totalInches / 12)
    }

    var heightInches: Int {
        let totalInches = heightCm / 2.54
        return Int(totalInches) % 12
    }

    /// Weight in pounds (for imperial display)
    var weightLbs: Double {
        return weightKg * 2.20462
    }
}

@MainActor
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    // MARK: - Published Properties

    @Published var currentStep: OnboardingStep = .name
    @Published var profile: OnboardingProfile = OnboardingProfile()
    @Published var isOnboardingComplete: Bool = false
    @Published var isCheckingServerState: Bool = false

    // Temporary editing state
    @Published var tempHeightFeet: Int = 5
    @Published var tempHeightInches: Int = 7
    @Published var tempWeightLbs: Double = 154

    // MARK: - Private Properties

    private let userDefaultsKey = "onboardingProfile"
    private let onboardingCompleteKey = "onboardingComplete"
    private let lastUserIdKey = "lastOnboardingUserId"

    // MARK: - Initialization

    private init() {
        loadLocalProfile()
        detectSystemMeasurementSystem()
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
    }

    /// Save onboarding completion and profile to server
    private func saveOnboardingToServer() async {
        do {
            // Save onboarding completion flag
            try await ConvexService.shared.updateUserProfile(updates: [
                "onboardingCompleted": true,
                "displayName": profile.name,
                "heightCm": profile.heightCm,
                "weightKg": profile.weightKg,
                "gender": profile.gender,
                "birthYear": profile.birthYear,
                "wearables": profile.wearables,
                "appleHealthConnected": profile.hasConnectedHealthKit,
                "measurementSystem": profile.measurementSystem
            ])
            print("[Onboarding] ✅ Saved to server")
        } catch {
            print("[Onboarding] ⚠️ Failed to save to server: \(error)")
            // Profile is saved locally, will retry on next app launch
        }
    }

    /// Reset local state for a new user
    private func resetLocalState() {
        profile = OnboardingProfile()
        currentStep = .name  // Start at name step (no welcome step)
        isOnboardingComplete = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.set(false, forKey: onboardingCompleteKey)
        detectSystemMeasurementSystem()
    }

    /// Clear onboarding state when user signs out
    /// This resets local state without touching server data
    func clearForSignOut() {
        profile = OnboardingProfile()
        currentStep = .name  // Start at name step (no welcome step)
        isOnboardingComplete = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.set(false, forKey: onboardingCompleteKey)
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
        let totalInches = profile.heightCm / 2.54
        tempHeightFeet = Int(totalInches / 12)
        tempHeightInches = Int(totalInches) % 12
        tempWeightLbs = profile.weightKg * 2.20462
    }

    /// Update metric profile values from imperial temp values
    func updateMetricFromImperial() {
        let totalInches = Double(tempHeightFeet * 12 + tempHeightInches)
        profile.heightCm = totalInches * 2.54
        profile.weightKg = tempWeightLbs / 2.20462
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

    /// Check if a step should be skipped (has pre-filled data)
    func shouldSkipStep(_ step: OnboardingStep) -> Bool {
        switch step {
        case .name:
            // Skip if name is already filled
            return !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .healthConnect:
            // Never skip - always show HealthKit permission request
            return false
        case .measurementSystem:
            // Skip measurement system - auto-detected from locale
            // User can change in settings if needed
            return true
        case .heightWeight:
            // Skip entirely if HealthKit provided height and weight data
            // This is the key change from Issue 2
            return profile.hasConnectedHealthKit &&
                   profile.heightCm > 100 && profile.heightCm < 250 &&
                   profile.weightKg > 30 && profile.weightKg < 300
        case .genderAge:
            // Skip if we got complete data from HealthKit
            return profile.hasConnectedHealthKit &&
                   profile.gender != Gender.preferNotToSay.rawValue &&
                   profile.birthYear > 1920 && profile.birthYear < Calendar.current.component(.year, from: Date()) - 10
        default:
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
        case .name:
            return !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .measurementSystem:
            return true
        case .heightWeight:
            return profile.heightCm > 0 && profile.weightKg > 0
        case .genderAge:
            return profile.birthYear > 1900 && profile.birthYear <= Calendar.current.component(.year, from: Date())
        case .wearables:
            return true // Optional step
        case .healthConnect:
            return true // Optional step
        case .sleepPhilosophy:
            return true
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
}
