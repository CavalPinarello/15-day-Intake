//
//  OnboardingView.swift
//  Zoe Sleep - Sleep Better, Live Longer
//
//  Compact, iPhone-optimized onboarding with circadian colors
//  Designed to fit all iPhone screen sizes without scrolling issues
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Circadian-aware background
                OnboardingCircadianBackground()

                VStack(spacing: 0) {
                    // Progress indicator (compact) - shown for all steps except ready
                    if onboardingManager.currentStep != .ready {
                        OnboardingProgressBar(
                            currentStep: onboardingManager.currentStep.rawValue,
                            totalSteps: OnboardingStep.allCases.count - 1  // Exclude ready step from count
                        )
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                    }

                    // FLOW: Personal connection first, HealthKit at the end for sleep history
                    TabView(selection: $onboardingManager.currentStep) {
                        // Step 0: Name - personal connection first
                        NameStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.name)

                        // Step 1: Units + Height/Weight combined
                        HeightWeightStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.heightWeight)

                        // Step 2: Gender/Age
                        GenderAgeStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.genderAge)

                        // Step 3: Wearables
                        WearablesStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.wearables)

                        // Step 4: HealthKit - sync sleep/activity history (optional)
                        HealthConnectStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .environmentObject(healthKitManager)
                            .tag(OnboardingStep.healthConnect)

                        // Step 5: Ready
                        ReadyStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.ready)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: onboardingManager.currentStep)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Circadian-Aware Background

struct OnboardingCircadianBackground: View {
    var body: some View {
        let palette = WaveCircadianPalette.current

        ZStack {
            // Base gradient
            LinearGradient(
                colors: palette.background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle accent circle (top right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.accent.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 150, y: -150)
                .blur(radius: 40)

            // Subtle wave accent (bottom left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.wave.opacity(0.10), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: -120, y: 250)
                .blur(radius: 35)
        }
    }
}

// MARK: - Progress Bar (Compact)

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        let palette = WaveCircadianPalette.current

        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(palette.isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                    .frame(height: 3)

                // Progress fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [palette.accent, palette.wave],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 3)
                    .animation(.spring(response: 0.4), value: currentStep)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Name Step (Compact)
// NOTE: Welcome step removed - splash screen serves as welcome

struct NameStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let screenHeight: CGFloat
    @FocusState private var isNameFocused: Bool

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Spacer(minLength: isCompact ? 30 : 50)

            // Icon
            Image(systemName: "person.fill")
                .font(.system(size: isCompact ? 36 : 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [palette.accent, palette.wave],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title
            VStack(spacing: 6) {
                Text("What should we call you?")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)

                Text("We'll personalize your experience")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
            }

            // Name input
            TextField("Your name", text: $onboardingManager.profile.name)
                .font(.title3)
                .foregroundColor(palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding()
                .background(palette.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(palette.accent.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 32)
                .focused($isNameFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isNameFocused = true
                    }
                }

            Spacer()

            // Navigation - no back button since this is the first step
            OnboardingNavigationButtons(
                onboardingManager: onboardingManager,
                showBack: false
            )
            .padding(.horizontal, 20)
            .padding(.bottom, isCompact ? 24 : 32)
        }
    }
}

// MARK: - Height & Weight Step (Combined with Units)

struct HeightWeightStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    private var isMetric: Bool {
        onboardingManager.profile.measurementSystem == MeasurementSystem.metric.rawValue
    }

    var body: some View {
        VStack(spacing: isCompact ? 10 : 14) {
            Spacer(minLength: isCompact ? 16 : 28)

            // Icon & Title
            VStack(spacing: 4) {
                Image(systemName: "figure.stand")
                    .font(.system(size: isCompact ? 28 : 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.accent, palette.wave],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Body Metrics")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)
            }

            // Unit System Picker
            VStack(spacing: 6) {
                Text("Measurement system")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)

                Picker("Units", selection: Binding(
                    get: {
                        MeasurementSystem(rawValue: onboardingManager.profile.measurementSystem) ?? .metric
                    },
                    set: { newValue in
                        onboardingManager.profile.measurementSystem = newValue.rawValue
                    }
                )) {
                    ForEach(MeasurementSystem.allCases) { system in
                        Text(system.rawValue).tag(system)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 20)

            // Height & Weight sliders
            VStack(spacing: isCompact ? 10 : 14) {
                // Height
                MetricInputRow(
                    label: "Height",
                    value: isMetric
                        ? "\(Int(onboardingManager.tempHeightCm)) cm"
                        : "\(onboardingManager.tempHeightFeet)' \(onboardingManager.tempHeightInches)\"",
                    isCompact: isCompact
                ) {
                    if isMetric {
                        Slider(value: $onboardingManager.tempHeightCm, in: 120...220, step: 1)
                            .tint(palette.accent)
                            .onChange(of: onboardingManager.tempHeightCm) { _, _ in
                                onboardingManager.updateProfileFromMetric()
                            }
                    } else {
                        // Single slider for imperial height (total inches displayed as feet/inches)
                        Slider(
                            value: Binding(
                                get: { Double(onboardingManager.tempHeightFeet * 12 + onboardingManager.tempHeightInches) },
                                set: { newValue in
                                    let totalInches = Int(newValue)
                                    onboardingManager.tempHeightFeet = totalInches / 12
                                    onboardingManager.tempHeightInches = totalInches % 12
                                }
                            ),
                            in: 48...95,  // 4'0" to 7'11"
                            step: 1
                        )
                        .tint(palette.accent)
                        .onChange(of: onboardingManager.tempHeightFeet) { _, _ in
                            onboardingManager.updateMetricFromImperial()
                        }
                        .onChange(of: onboardingManager.tempHeightInches) { _, _ in
                            onboardingManager.updateMetricFromImperial()
                        }
                    }
                }

                // Weight
                MetricInputRow(
                    label: "Weight",
                    value: isMetric
                        ? "\(Int(onboardingManager.tempWeightKg)) kg"
                        : "\(Int(onboardingManager.tempWeightLbs)) lbs",
                    isCompact: isCompact
                ) {
                    if isMetric {
                        Slider(value: $onboardingManager.tempWeightKg, in: 30...200, step: 0.5)
                            .tint(palette.accent)
                            .onChange(of: onboardingManager.tempWeightKg) { _, _ in
                                onboardingManager.updateProfileFromMetric()
                            }
                    } else {
                        Slider(value: $onboardingManager.tempWeightLbs, in: 66...440, step: 1)
                            .tint(palette.accent)
                            .onChange(of: onboardingManager.tempWeightLbs) { _, _ in
                                onboardingManager.updateMetricFromImperial()
                            }
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            // Navigation
            OnboardingNavigationButtons(
                onboardingManager: onboardingManager,
                showBack: true
            )
            .padding(.horizontal, 20)
            .padding(.bottom, isCompact ? 24 : 32)
        }
        .onAppear {
            // Initialize profile values from temp values if not already set
            // This ensures users can proceed even if they don't touch the sliders
            if onboardingManager.profile.heightCm == nil {
                onboardingManager.profile.heightCm = onboardingManager.tempHeightCm
            }
            if onboardingManager.profile.weightKg == nil {
                onboardingManager.profile.weightKg = onboardingManager.tempWeightKg
            }
        }
    }
}

struct MetricInputRow<Content: View>: View {
    let label: String
    let value: String
    let isCompact: Bool
    @ViewBuilder let content: Content

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(palette.accent)
            }
            content
        }
        .padding(isCompact ? 10 : 12)
        .background(palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        .cornerRadius(10)
    }
}

// MARK: - Gender & Age Step (Compact)

struct GenderAgeStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        VStack(spacing: isCompact ? 12 : 16) {
            Spacer(minLength: isCompact ? 20 : 35)

            // Icon & Title
            VStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: isCompact ? 30 : 38))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.accent, palette.wave],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("About You")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)
            }

            // Gender selection (2x2 grid)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Gender.allCases) { gender in
                    GenderCard(
                        gender: gender,
                        isSelected: onboardingManager.profile.gender == gender.rawValue,
                        isCompact: isCompact,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                onboardingManager.profile.gender = gender.rawValue
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)

            // Birth year (compact)
            HStack {
                Picker("Birth Year", selection: $onboardingManager.profile.birthYear) {
                    ForEach((1920...currentYear).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: isCompact ? 90 : 100)
                .frame(maxWidth: 140)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Age")
                        .font(.caption2)
                        .foregroundColor(palette.textSecondary)
                    Text("\(onboardingManager.profile.age)")
                        .font(.title2.bold())
                        .foregroundColor(palette.accent)
                }
                .padding(.trailing, 16)
            }
            .padding(10)
            .background(palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            .cornerRadius(10)
            .padding(.horizontal, 16)

            Spacer()

            // Navigation
            OnboardingNavigationButtons(
                onboardingManager: onboardingManager,
                showBack: true
            )
            .padding(.horizontal, 20)
            .padding(.bottom, isCompact ? 24 : 32)
        }
    }
}

struct GenderCard: View {
    let gender: Gender
    let isSelected: Bool
    let isCompact: Bool
    let onTap: () -> Void

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: gender.icon)
                    .font(isCompact ? .body : .title3)
                    .foregroundColor(isSelected ? palette.accent : palette.textSecondary)

                Text(gender.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? palette.textPrimary : palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? 10 : 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? palette.accent.opacity(0.15) : (palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? palette.accent : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Wearables Step (Compact Grid)

struct WearablesStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        VStack(spacing: isCompact ? 12 : 16) {
            Spacer(minLength: isCompact ? 20 : 35)

            // Icon & Title
            VStack(spacing: 4) {
                Image(systemName: "applewatch")
                    .font(.system(size: isCompact ? 30 : 38))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.accent, palette.wave],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Your Devices")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)

                Text("Select all that apply")
                    .font(.caption2)
                    .foregroundColor(palette.textSecondary)
            }

            // Wearables grid (compact - 2 columns)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(WearableDevice.allCases) { device in
                    WearableCard(
                        device: device,
                        isSelected: onboardingManager.isWearableSelected(device),
                        isCompact: isCompact,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                onboardingManager.toggleWearable(device)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            // Navigation
            OnboardingNavigationButtons(
                onboardingManager: onboardingManager,
                showBack: true,
                nextLabel: "Continue"
            )
            .padding(.horizontal, 20)
            .padding(.bottom, isCompact ? 24 : 32)
        }
    }
}

struct WearableCard: View {
    let device: WearableDevice
    let isSelected: Bool
    let isCompact: Bool
    let onTap: () -> Void

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: device.icon)
                    .font(isCompact ? .caption : .body)
                    .foregroundColor(isSelected ? palette.accent : palette.textSecondary)

                Text(device.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? palette.textPrimary : palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? 8 : 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? palette.accent.opacity(0.15) : (palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? palette.accent : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Health Connect Step (Compact)

/// Connection status for HealthKit
enum HealthKitConnectionStatus {
    case notConnected
    case connecting
    case connected
    case denied  // User denied permission
    case unavailable  // HealthKit not available on device
}

struct HealthConnectStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var connectionStatus: HealthKitConnectionStatus = .notConnected
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showMissingDataMessage = false
    @State private var missingDataItems: [String] = []
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Spacer(minLength: isCompact ? 40 : 60)

            // Icon - changes based on status
            ZStack {
                Circle()
                    .fill(iconBackgroundColor.opacity(0.15))
                    .frame(width: isCompact ? 80 : 100, height: isCompact ? 80 : 100)

                Image(systemName: iconName)
                    .font(.system(size: isCompact ? 36 : 44))
                    .foregroundColor(iconColor)
            }

            // Title & subtitle
            VStack(spacing: 8) {
                Text("Sync Your Sleep History")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)

                Text("Import your sleep and activity data to compare how you feel with what your body shows")
                    .font(.subheadline)
                    .foregroundColor(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Show missing data message if some demographics weren't retrieved
            if showMissingDataMessage && connectionStatus == .connected {
                missingDataBanner
            }

            Spacer()

            // Status-specific UI
            switch connectionStatus {
            case .notConnected:
                connectButton

            case .connecting:
                connectingIndicator

            case .connected:
                VStack(spacing: 16) {
                    connectedStatus

                    OnboardingNavigationButtons(
                        onboardingManager: onboardingManager,
                        showBack: true,
                        nextLabel: "Continue"
                    )
                    .padding(.horizontal, 20)
                }

            case .denied:
                deniedStatus

            case .unavailable:
                unavailableStatus
            }

            // Skip and back options for non-connected states
            if connectionStatus == .notConnected || connectionStatus == .denied || connectionStatus == .unavailable {
                VStack(spacing: 8) {
                    Button(action: { onboardingManager.nextStep() }) {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundColor(palette.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: { onboardingManager.previousStep() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.caption)
                        .foregroundColor(palette.textSecondary.opacity(0.7))
                    }
                }
                .padding(.bottom, isCompact ? 24 : 32)
            } else if connectionStatus == .connected {
                Spacer().frame(height: isCompact ? 24 : 32)
            }
        }
        .onAppear {
            // Log current state for debugging
            print("[Onboarding] HealthConnect step appeared - HK available: \(healthKitManager.isHealthKitAvailable), HK authorized: \(healthKitManager.isAuthorized), profile connected: \(onboardingManager.profile.hasConnectedHealthKit)")

            // Check initial status
            if !healthKitManager.isHealthKitAvailable {
                connectionStatus = .unavailable
                print("[Onboarding] HealthKit unavailable on this device")
            } else if onboardingManager.profile.hasConnectedHealthKit && healthKitManager.isAuthorized {
                connectionStatus = .connected
                print("[Onboarding] HealthKit already connected")
            } else {
                print("[Onboarding] HealthKit ready to connect")
            }
        }
        .alert("Connection Issue", isPresented: $showingError) {
            Button("Open Settings", role: .none) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Skip for now", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Missing Data Banner

    private var missingDataBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Some info wasn't found in Health")
                    .font(.caption.weight(.medium))
                    .foregroundColor(palette.textPrimary)

                Text("We'll ask about \(formatMissingItems()) next")
                    .font(.caption2)
                    .foregroundColor(palette.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func formatMissingItems() -> String {
        guard !missingDataItems.isEmpty else { return "" }

        if missingDataItems.count == 1 {
            return missingDataItems[0]
        } else if missingDataItems.count == 2 {
            return "\(missingDataItems[0]) and \(missingDataItems[1])"
        } else {
            let allButLast = missingDataItems.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(missingDataItems.last!)"
        }
    }

    // MARK: - Dynamic UI Properties

    private var iconName: String {
        switch connectionStatus {
        case .notConnected, .connecting: return "heart.fill"
        case .connected: return "checkmark.circle.fill"
        case .denied: return "exclamationmark.triangle.fill"
        case .unavailable: return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch connectionStatus {
        case .notConnected, .connecting: return .red
        case .connected: return .green
        case .denied: return .orange
        case .unavailable: return .gray
        }
    }

    private var iconBackgroundColor: Color {
        switch connectionStatus {
        case .notConnected, .connecting: return .red
        case .connected: return .green
        case .denied: return .orange
        case .unavailable: return .gray
        }
    }

    // MARK: - Subviews

    private var connectButton: some View {
        Button(action: connectHealthKit) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                Text("Sync Sleep History")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red)
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var connectingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .tint(palette.accent)
                .scaleEffect(0.9)
            Text("Connecting...")
                .foregroundColor(palette.textSecondary)
                .font(.subheadline.weight(.medium))
        }
    }

    private var connectedStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Connected")
                .foregroundColor(.green)
                .font(.subheadline.weight(.medium))
        }
    }

    private var deniedStatus: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Access Not Granted")
                    .foregroundColor(.orange)
                    .font(.subheadline.weight(.medium))
            }

            Button(action: openHealthSettings) {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.caption.weight(.medium))
                .foregroundColor(palette.accent)
            }
        }
    }

    private var unavailableStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(palette.textSecondary)
            Text("Not Available")
                .foregroundColor(palette.textSecondary)
                .font(.subheadline.weight(.medium))
        }
    }

    // MARK: - Actions

    private func connectHealthKit() {
        print("[Onboarding] Starting HealthKit connection flow...")
        connectionStatus = .connecting

        healthKitManager.requestAuthorization { success, error in
            // Ensure UI updates happen on main thread
            DispatchQueue.main.async {
                print("[Onboarding] HealthKit authorization callback - success: \(success), error: \(error?.localizedDescription ?? "none")")

                if success {
                    connectionStatus = .connected
                    print("[Onboarding] HealthKit authorized, fetching demographics...")

                    // Wait for demographics to be fully fetched (height/weight are async)
                    healthKitManager.refreshDemographics { demographics in
                        DispatchQueue.main.async {
                            print("[Onboarding] Demographics callback received")
                            onboardingManager.populateFromHealthKit(demographics: demographics)
                            print("[Onboarding] HealthKit demographics populated - Height: \(demographics.heightCm ?? 0), Weight: \(demographics.weightKg ?? 0), Age: \(demographics.age ?? 0)")

                            // Only mark as connected AFTER we have the data
                            onboardingManager.markHealthKitConnected()
                            print("[Onboarding] HealthKit marked as connected in profile")

                            // Check what data we actually got vs what we need
                            let hasHeight = onboardingManager.profile.heightCm != nil
                            let hasWeight = onboardingManager.profile.weightKg != nil
                            let hasGender = onboardingManager.profile.gender != Gender.preferNotToSay.rawValue
                            let currentYear = Calendar.current.component(.year, from: Date())
                            let hasAge = onboardingManager.profile.birthYear >= 1920 && onboardingManager.profile.birthYear < currentYear - 10

                            var missing: [String] = []
                            if !hasHeight { missing.append("height") }
                            if !hasWeight { missing.append("weight") }
                            if !hasGender { missing.append("gender") }
                            if !hasAge { missing.append("age") }

                            if !missing.isEmpty {
                                print("[Onboarding] ⚠️ Missing data from HealthKit: \(missing.joined(separator: ", "))")
                                missingDataItems = missing
                                showMissingDataMessage = true
                            } else {
                                print("[Onboarding] ✅ All required data retrieved from HealthKit")
                            }

                            // Sync sleep data to Convex in background (no analysis)
                            syncSleepDataToConvex()
                            print("[Onboarding] HealthKit connection flow completed successfully")
                        }
                    }
                } else {
                    // Authorization was denied or failed
                    connectionStatus = .denied
                    if let error = error {
                        print("[Onboarding] ❌ HealthKit authorization error: \(error.localizedDescription)")
                    } else {
                        print("[Onboarding] ❌ HealthKit authorization denied by user (no error)")
                    }
                    // Show helpful message
                    errorMessage = "To import your sleep data, please enable Apple Health access in Settings > Privacy & Security > Health > Zoe Sleep."
                    showingError = true
                }
            }
        }
    }

    /// Sync all health data to Convex in background (doesn't block UI)
    private func syncSleepDataToConvex() {
        print("[Onboarding] Starting background sync of health data to Convex...")
        print("[Onboarding] ConvexService authenticated: \(ConvexService.shared.isAuthenticated)")

        guard ConvexService.shared.isAuthenticated else {
            print("[Onboarding] ⚠️ Cannot sync - not authenticated with Convex yet")
            return
        }

        healthKitManager.syncAllHealthData { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let summary):
                    print("[Onboarding] ✅ Health data synced to Convex:")
                    for (key, value) in summary {
                        print("  - \(key): \(value)")
                    }
                case .failure(let error):
                    print("[Onboarding] ❌ Health data sync failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func openHealthSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Ready Step (Compact Celebration)

struct ReadyStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Spacer(minLength: isCompact ? 30 : 50)

            // Celebration icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette.accent.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: isCompact ? 50 : 70
                        )
                    )
                    .frame(width: isCompact ? 100 : 130, height: isCompact ? 100 : 130)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: isCompact ? 50 : 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#4ECDC4") ?? .teal, Color(hex: "#44BD32") ?? .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Title
            VStack(spacing: 6) {
                Text("You're All Set!")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)

                if !onboardingManager.profile.name.isEmpty {
                    Text("Welcome, \(onboardingManager.profile.name)!")
                        .font(.subheadline)
                        .foregroundColor(palette.accent)
                }

                Text("Your 10-day sleep journey begins now")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Philosophy message (compact)
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.body)
                    .foregroundColor(palette.accent)

                Text("We bridge how you feel and what your data shows")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(palette.accent.opacity(0.08))
            .cornerRadius(8)
            .padding(.horizontal, 20)

            // Summary (compact)
            VStack(spacing: 8) {
                SummaryRow(label: "Units", value: onboardingManager.profile.measurementSystem, isCompact: isCompact)
                SummaryRow(label: "Age", value: "\(onboardingManager.profile.age) years", isCompact: isCompact)

                if let device = onboardingManager.profile.wearables.first {
                    let count = onboardingManager.profile.wearables.count
                    SummaryRow(label: "Device", value: count > 1 ? "\(device) +\(count - 1)" : device, isCompact: isCompact)
                }

                SummaryRow(
                    label: "Apple Health",
                    value: onboardingManager.profile.hasConnectedHealthKit ? "Connected" : "Not connected",
                    valueColor: onboardingManager.profile.hasConnectedHealthKit ? .green : .orange,
                    isCompact: isCompact
                )

                SummaryRow(
                    label: "Reminders",
                    value: "9 AM & 8 PM",
                    icon: "bell.fill",
                    isCompact: isCompact
                )
            }
            .padding(12)
            .background(palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            .cornerRadius(10)
            .padding(.horizontal, 20)

            // Notification note
            Text("We'll ask for notification permission to send you daily reminders")
                .font(.caption2)
                .foregroundColor(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            // Start button
            Button(action: { onboardingManager.completeOnboarding() }) {
                HStack(spacing: 8) {
                    Text("Start My Journey")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(palette.isDark ? Color(red: 0.15, green: 0.10, blue: 0.08) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [palette.accent, palette.wave],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, isCompact ? 24 : 32)
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil
    var icon: String? = nil
    var isCompact: Bool = false

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        HStack {
            Text(label)
                .font(isCompact ? .caption2 : .caption)
                .foregroundColor(palette.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(isCompact ? .caption2 : .caption)
                        .foregroundColor(palette.accent)
                }
                Text(value)
                    .font(isCompact ? .caption.weight(.medium) : .subheadline.weight(.medium))
                    .foregroundColor(valueColor ?? palette.textPrimary)
            }
        }
    }
}

// MARK: - Navigation Buttons (Compact)

struct OnboardingNavigationButtons: View {
    @ObservedObject var onboardingManager: OnboardingManager
    var showBack: Bool = false
    var nextLabel: String = FriendlyCopy.continueButton  // "Let's go" by default

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Next button - calm, rounded style
            Button(action: { onboardingManager.nextStep() }) {
                HStack(spacing: Spacing.xs) {
                    Text(nextLabel)
                        .font(.system(size: Typography.headline, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: Typography.subheadline, weight: .semibold))
                }
                .foregroundColor(onboardingManager.canProceed
                    ? (palette.isDark ? Color(red: 0.15, green: 0.10, blue: 0.08) : .white)
                    : palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(
                            onboardingManager.canProceed
                                ? LinearGradient(
                                    colors: [palette.accent, palette.wave],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                )
            }
            .disabled(!onboardingManager.canProceed)
            .scaleEffect(onboardingManager.canProceed ? 1.0 : 0.98)
            .animation(.spring(response: 0.3), value: onboardingManager.canProceed)

            // Back button
            if showBack {
                Button(action: { onboardingManager.previousStep() }) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "chevron.left")
                        Text(FriendlyCopy.backButton)
                    }
                    .font(.system(size: Typography.subheadline, design: .rounded))
                    .foregroundColor(palette.textSecondary.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onboardingManager: OnboardingManager.shared)
        .environmentObject(HealthKitManager(authManager: nil))
        .environmentObject(ThemeManager.shared)
}
