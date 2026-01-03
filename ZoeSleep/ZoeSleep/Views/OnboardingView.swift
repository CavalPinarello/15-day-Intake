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

                    // Content - starts with name (no welcome step, splash serves as welcome)
                    // REVISED ORDER: HealthKit moved early to enable skip of body metrics
                    TabView(selection: $onboardingManager.currentStep) {
                        NameStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.name)

                        // HealthKit early - allows pre-filling of body metrics
                        HealthConnectStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .environmentObject(healthKitManager)
                            .tag(OnboardingStep.healthConnect)

                        // Measurement system - auto-skipped (uses locale detection)
                        MeasurementSystemStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.measurementSystem)

                        // Height/Weight - skipped if HealthKit provided data
                        HeightWeightStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.heightWeight)

                        // Gender/Age - skipped if HealthKit provided data
                        GenderAgeStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.genderAge)

                        WearablesStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.wearables)

                        ReadyStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.ready)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: onboardingManager.currentStep)
                }

                // Floating accessibility button (bottom-right)
                // Uses palette colors to blend with circadian background
                EnhancedReadabilityButton(
                    lightStyle: WaveCircadianPalette.current.isDark,
                    edgePadding: 24
                )
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

// MARK: - Measurement System Step (Compact)

struct MeasurementSystemStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        VStack(spacing: isCompact ? 16 : 24) {
            Spacer(minLength: isCompact ? 30 : 50)

            // Icon
            Image(systemName: "ruler")
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
                Text("Measurement Units")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)

                Text("Based on your region")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
            }

            // Options
            VStack(spacing: 12) {
                ForEach(MeasurementSystem.allCases) { system in
                    MeasurementSystemCard(
                        system: system,
                        isSelected: onboardingManager.profile.measurementSystem == system.rawValue,
                        isCompact: isCompact,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                onboardingManager.profile.measurementSystem = system.rawValue
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)

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

struct MeasurementSystemCard: View {
    let system: MeasurementSystem
    let isSelected: Bool
    let isCompact: Bool
    let onTap: () -> Void

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(system.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(palette.textPrimary)

                    Text("\(system.heightUnit) / \(system.weightUnit)")
                        .font(.caption2)
                        .foregroundColor(palette.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(palette.accent)
                        .font(.title3)
                }
            }
            .padding(isCompact ? 12 : 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? palette.accent.opacity(0.15) : (palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? palette.accent : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Height & Weight Step (Compact - Single Screen)

struct HeightWeightStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    private var isMetric: Bool {
        onboardingManager.profile.measurementSystem == MeasurementSystem.metric.rawValue
    }

    var body: some View {
        VStack(spacing: isCompact ? 12 : 16) {
            Spacer(minLength: isCompact ? 20 : 40)

            // Icon & Title (compact)
            VStack(spacing: 6) {
                Image(systemName: "figure.stand")
                    .font(.system(size: isCompact ? 32 : 40))
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
            Picker("Units", selection: Binding(
                get: {
                    MeasurementSystem(rawValue: onboardingManager.profile.measurementSystem) ?? .metric
                },
                set: { newValue in
                    onboardingManager.profile.measurementSystem = newValue.rawValue
                    // Sync temp values when switching systems
                    if newValue == .metric {
                        // Imperial → Metric: Update temp metric values from imperial
                        let totalInches = Double(onboardingManager.tempHeightFeet * 12 + onboardingManager.tempHeightInches)
                        onboardingManager.tempHeightCm = totalInches * 2.54
                        onboardingManager.tempWeightKg = onboardingManager.tempWeightLbs / 2.20462
                    } else {
                        // Metric → Imperial: Update temp imperial values from metric
                        let totalInches = onboardingManager.tempHeightCm / 2.54
                        onboardingManager.tempHeightFeet = Int(totalInches / 12)
                        onboardingManager.tempHeightInches = Int(totalInches) % 12
                        onboardingManager.tempWeightLbs = onboardingManager.tempWeightKg * 2.20462
                    }
                }
            )) {
                ForEach(MeasurementSystem.allCases) { system in
                    Text(system.rawValue).tag(system)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)

            // Height & Weight in single compact view
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

/// Sleep analysis phase during onboarding
enum SleepAnalysisPhase {
    case notStarted
    case fetchingSleepData
    case analyzingPatterns
    case complete
    case insufficientData
}

struct HealthConnectStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var chronotypeManager = ChronotypeManager.shared
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var connectionStatus: HealthKitConnectionStatus = .notConnected
    @State private var analysisPhase: SleepAnalysisPhase = .notStarted
    @State private var showingError = false
    @State private var errorMessage = ""
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        VStack(spacing: isCompact ? 12 : 16) {
            Spacer(minLength: isCompact ? 20 : 35)

            // Show different content based on analysis phase
            if analysisPhase == .notStarted {
                // Standard HealthKit connection UI
                healthKitConnectionContent
            } else {
                // Sleep analysis / chronotype UI
                sleepAnalysisContent
            }
        }
        .onAppear {
            // Check initial status
            if !healthKitManager.isHealthKitAvailable {
                connectionStatus = .unavailable
            } else if onboardingManager.profile.hasConnectedHealthKit && healthKitManager.isAuthorized {
                connectionStatus = .connected
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

    // MARK: - HealthKit Connection Content

    private var healthKitConnectionContent: some View {
        Group {
            // Icon - changes based on status
            ZStack {
                Circle()
                    .fill(iconBackgroundColor.opacity(0.15))
                    .frame(width: isCompact ? 60 : 70, height: isCompact ? 60 : 70)

                Image(systemName: iconName)
                    .font(.system(size: isCompact ? 28 : 34))
                    .foregroundColor(iconColor)
            }

            // Title
            VStack(spacing: 4) {
                Text("Connect Apple Health")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Benefits (compact list)
            VStack(alignment: .leading, spacing: 8) {
                HealthBenefitRow(icon: "bed.double.fill", text: "Sleep tracking data", isCompact: isCompact)
                HealthBenefitRow(icon: "heart.text.square.fill", text: "Heart rate patterns", isCompact: isCompact)
                HealthBenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Personalized insights", isCompact: isCompact)
            }
            .padding(12)
            .background(palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            .cornerRadius(10)
            .padding(.horizontal, 20)

            Spacer()

            // Status-specific UI
            switch connectionStatus {
            case .notConnected:
                connectButton

            case .connecting:
                connectingIndicator

            case .connected:
                connectedStatus

            case .denied:
                deniedStatus

            case .unavailable:
                unavailableStatus
            }

            // Skip/Continue button
            Button(action: { onboardingManager.nextStep() }) {
                Text(continueButtonText)
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
            }

            // Back
            Button(action: { onboardingManager.previousStep() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.caption)
                .foregroundColor(palette.textSecondary.opacity(0.7))
            }
            .padding(.bottom, isCompact ? 24 : 32)
        }
    }

    // MARK: - Sleep Analysis Content

    private var sleepAnalysisContent: some View {
        Group {
            switch analysisPhase {
            case .fetchingSleepData, .analyzingPatterns:
                // Progress indicator
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(palette.accent.opacity(0.15))
                            .frame(width: isCompact ? 70 : 80, height: isCompact ? 70 : 80)

                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(palette.accent)
                    }

                    VStack(spacing: 4) {
                        Text(analysisPhase == .fetchingSleepData ? "Fetching Sleep History" : "Analyzing Patterns")
                            .font(isCompact ? .title3.bold() : .title2.bold())
                            .foregroundColor(palette.textPrimary)

                        Text(analysisPhase == .fetchingSleepData
                             ? "Retrieving your sleep data from Apple Health..."
                             : "Calculating your sleep midpoint and chronotype...")
                            .font(.caption)
                            .foregroundColor(palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }

                Spacer()

            case .complete:
                // Show chronotype result
                if let result = chronotypeManager.result {
                    chronotypeResultView(result: result)
                }

            case .insufficientData:
                // Not enough data message
                insufficientDataView

            case .notStarted:
                EmptyView()
            }

            Spacer()

            // Continue button (only show when analysis is complete)
            if analysisPhase == .complete || analysisPhase == .insufficientData {
                Button(action: { onboardingManager.nextStep() }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(palette.isDark ? Color(red: 0.15, green: 0.10, blue: 0.08) : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [palette.accent, palette.wave],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, isCompact ? 24 : 32)
            }
        }
    }

    // MARK: - Chronotype Result View

    private func chronotypeResultView(result: ChronotypeResult) -> some View {
        VStack(spacing: 16) {
            // Chronotype icon and emoji
            ZStack {
                Circle()
                    .fill(result.chronotypeEnum.color.opacity(0.2))
                    .frame(width: isCompact ? 80 : 100, height: isCompact ? 80 : 100)

                Text(result.emoji)
                    .font(.system(size: isCompact ? 40 : 50))
            }

            // Title
            VStack(spacing: 4) {
                Text("You're a \(result.displayName)!")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)

                Text(result.chronotypeEnum.description)
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Sleep stats card
            VStack(spacing: 10) {
                HStack {
                    Label("Sleep Midpoint", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(palette.textSecondary)
                    Spacer()
                    Text(chronotypeManager.formatMidpointTime(result.avgSleepMidpoint))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(result.chronotypeEnum.color)
                }

                Divider()
                    .background(palette.textSecondary.opacity(0.3))

                HStack {
                    Label("Usual Bedtime", systemImage: "bed.double")
                        .font(.subheadline)
                        .foregroundColor(palette.textSecondary)
                    Spacer()
                    Text(chronotypeManager.formatMidpointTime(result.avgBedtime))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(palette.textPrimary)
                }

                HStack {
                    Label("Usual Wake Time", systemImage: "sun.max")
                        .font(.subheadline)
                        .foregroundColor(palette.textSecondary)
                    Spacer()
                    Text(chronotypeManager.formatMidpointTime(result.avgWakeTime))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(palette.textPrimary)
                }

                Divider()
                    .background(palette.textSecondary.opacity(0.3))

                HStack {
                    Text("Based on \(result.daysAnalyzed) nights")
                        .font(.caption)
                        .foregroundColor(palette.textSecondary)
                    Spacer()
                }
            }
            .padding(14)
            .background(palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Insufficient Data View

    private var insufficientDataView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(0.15))
                    .frame(width: isCompact ? 70 : 80, height: isCompact ? 70 : 80)

                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: isCompact ? 32 : 38))
                    .foregroundColor(palette.accent)
            }

            VStack(spacing: 4) {
                Text("Learning Your Patterns")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)

                Text(chronotypeManager.dataStatusMessage)
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Info card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(palette.accent)
                    Text("What is chronotype?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(palette.textPrimary)
                }

                Text("Your chronotype determines whether you're naturally a morning person, night owl, or somewhere in between. It's based on your typical sleep midpoint - the halfway point between when you fall asleep and wake up.")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            .cornerRadius(10)
            .padding(.horizontal, 20)
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

    private var subtitleText: String {
        switch connectionStatus {
        case .notConnected:
            return "Import sleep data for personalized insights"
        case .connecting:
            return "Requesting access..."
        case .connected:
            return "Your health data will be imported"
        case .denied:
            return "Enable access in Settings to import your sleep data"
        case .unavailable:
            return "Apple Health is not available on this device"
        }
    }

    private var continueButtonText: String {
        switch connectionStatus {
        case .connected: return "Continue"
        case .denied: return "Continue without Health data"
        default: return "Skip for now"
        }
    }

    // MARK: - Subviews

    private var connectButton: some View {
        Button(action: connectHealthKit) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                Text("Connect Apple Health")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red)
            .cornerRadius(12)
        }
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
                .foregroundColor(.gray)
            Text("Not Available")
                .foregroundColor(.gray)
                .font(.subheadline.weight(.medium))
        }
    }

    // MARK: - Actions

    private func connectHealthKit() {
        connectionStatus = .connecting

        healthKitManager.requestAuthorization { success, error in
            if success {
                connectionStatus = .connected
                onboardingManager.markHealthKitConnected()

                // Wait for demographics to be fully fetched (height/weight are async)
                healthKitManager.refreshDemographics { demographics in
                    onboardingManager.populateFromHealthKit(demographics: demographics)
                    print("[Onboarding] HealthKit demographics populated - Height: \(demographics.heightCm ?? 0), Weight: \(demographics.weightKg ?? 0), Age: \(demographics.age ?? 0)")

                    // Now start chronotype analysis
                    startChronotypeAnalysis()
                }
            } else {
                // Authorization was denied or failed
                connectionStatus = .denied
                if let error = error {
                    print("[HealthKit] Authorization denied: \(error.localizedDescription)")
                } else {
                    print("[HealthKit] Authorization denied by user")
                }
                // Show helpful message
                errorMessage = "To import your sleep data, please enable Apple Health access in Settings > Privacy & Security > Health > Zoe Sleep."
                showingError = true
            }
        }
    }

    private func startChronotypeAnalysis() {
        withAnimation(.easeInOut(duration: 0.3)) {
            analysisPhase = .fetchingSleepData
        }

        // Fetch sleep data from HealthKit
        healthKitManager.fetchSleepDataForChronotype { sleepData in
            DispatchQueue.main.async {
                chronotypeManager.nightsFound = sleepData.count

                if sleepData.isEmpty {
                    // No sleep data at all
                    withAnimation(.easeInOut(duration: 0.3)) {
                        analysisPhase = .insufficientData
                    }
                    return
                }

                withAnimation(.easeInOut(duration: 0.3)) {
                    analysisPhase = .analyzingPatterns
                }

                // Add brief delay for visual effect
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Analyze the data
                    if let result = chronotypeManager.analyzeFromSleepData(sleepData) {
                        // Sufficient data - show result
                        withAnimation(.easeInOut(duration: 0.3)) {
                            analysisPhase = .complete
                        }
                        print("[Onboarding] Chronotype determined: \(result.chronotype), midpoint: \(chronotypeManager.formatMidpointTime(result.avgSleepMidpoint))")
                    } else {
                        // Insufficient data
                        withAnimation(.easeInOut(duration: 0.3)) {
                            analysisPhase = .insufficientData
                        }
                        print("[Onboarding] Insufficient sleep data for chronotype: \(sleepData.count) nights")
                    }
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

struct HealthBenefitRow: View {
    let icon: String
    let text: String
    var isCompact: Bool = false

    private var palette: WaveCircadianPalette { WaveCircadianPalette.current }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(isCompact ? .caption : .subheadline)
                .foregroundColor(palette.accent)
                .frame(width: 20)

            Text(text)
                .font(isCompact ? .caption : .subheadline)
                .foregroundColor(palette.textPrimary)
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
                            colors: [Color(hex: "#4ECDC4")!, Color(hex: "#44BD32")!],
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

                Text("Your 14-day sleep journey begins now")
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
