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

                        SleepPhilosophyStepView(onboardingManager: onboardingManager, screenHeight: geometry.size.height)
                            .tag(OnboardingStep.sleepPhilosophy)

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
        let palette = CircadianPalette.current

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
        let palette = CircadianPalette.current

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
    private var palette: CircadianPalette { CircadianPalette.current }

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
    private var palette: CircadianPalette { CircadianPalette.current }

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

    private var palette: CircadianPalette { CircadianPalette.current }

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
    private var palette: CircadianPalette { CircadianPalette.current }

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

            // Height & Weight in single compact view
            VStack(spacing: isCompact ? 10 : 14) {
                // Height
                MetricInputRow(
                    label: "Height",
                    value: isMetric
                        ? "\(Int(onboardingManager.profile.heightCm)) cm"
                        : "\(onboardingManager.tempHeightFeet)' \(onboardingManager.tempHeightInches)\"",
                    isCompact: isCompact
                ) {
                    if isMetric {
                        Slider(value: $onboardingManager.profile.heightCm, in: 120...220, step: 1)
                            .tint(palette.accent)
                    } else {
                        HStack(spacing: 8) {
                            Picker("Feet", selection: $onboardingManager.tempHeightFeet) {
                                ForEach(4...7, id: \.self) { ft in
                                    Text("\(ft)'").tag(ft)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 70, height: 80)
                            .clipped()

                            Picker("Inches", selection: $onboardingManager.tempHeightInches) {
                                ForEach(0...11, id: \.self) { inch in
                                    Text("\(inch)\"").tag(inch)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 70, height: 80)
                            .clipped()
                        }
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
                        ? "\(Int(onboardingManager.profile.weightKg)) kg"
                        : "\(Int(onboardingManager.tempWeightLbs)) lbs",
                    isCompact: isCompact
                ) {
                    if isMetric {
                        Slider(value: $onboardingManager.profile.weightKg, in: 30...200, step: 0.5)
                            .tint(palette.accent)
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
    }
}

struct MetricInputRow<Content: View>: View {
    let label: String
    let value: String
    let isCompact: Bool
    @ViewBuilder let content: Content

    private var palette: CircadianPalette { CircadianPalette.current }

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
    private var palette: CircadianPalette { CircadianPalette.current }

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

    private var palette: CircadianPalette { CircadianPalette.current }

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
    private var palette: CircadianPalette { CircadianPalette.current }

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

    private var palette: CircadianPalette { CircadianPalette.current }

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

struct HealthConnectStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: CircadianPalette { CircadianPalette.current }

    var body: some View {
        VStack(spacing: isCompact ? 12 : 16) {
            Spacer(minLength: isCompact ? 20 : 35)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: isCompact ? 60 : 70, height: isCompact ? 60 : 70)

                Image(systemName: "heart.fill")
                    .font(.system(size: isCompact ? 28 : 34))
                    .foregroundColor(.red)
            }

            // Title
            VStack(spacing: 4) {
                Text("Connect Apple Health")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)

                Text("Import sleep data for personalized insights")
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

            // Connect button or status
            if onboardingManager.profile.hasConnectedHealthKit {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connected")
                        .foregroundColor(.green)
                        .font(.subheadline.weight(.medium))
                }
            } else {
                Button(action: connectHealthKit) {
                    HStack(spacing: 6) {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "heart.fill")
                            Text("Connect Apple Health")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(isConnecting)
                .padding(.horizontal, 20)
            }

            // Skip/Continue
            Button(action: { onboardingManager.nextStep() }) {
                Text(onboardingManager.profile.hasConnectedHealthKit ? "Continue" : "Skip for now")
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
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func connectHealthKit() {
        isConnecting = true
        healthKitManager.requestAuthorization { success, error in
            isConnecting = false
            if success {
                onboardingManager.markHealthKitConnected()
                onboardingManager.populateFromHealthKit(demographics: healthKitManager.demographics)
                onboardingManager.nextStep()
            } else if let error = error {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct HealthBenefitRow: View {
    let icon: String
    let text: String
    var isCompact: Bool = false

    private var palette: CircadianPalette { CircadianPalette.current }

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

// MARK: - Sleep Philosophy Step (Compact Cards)

struct SleepPhilosophyStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: CircadianPalette { CircadianPalette.current }

    var body: some View {
        VStack(spacing: isCompact ? 10 : 14) {
            Spacer(minLength: isCompact ? 16 : 30)

            // Icon & Title
            VStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: isCompact ? 28 : 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.accent, palette.wave],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Our Philosophy")
                    .font(isCompact ? .title3.bold() : .title2.bold())
                    .foregroundColor(palette.textPrimary)
            }

            // Philosophy cards (compact)
            VStack(spacing: 8) {
                PhilosophyCard(
                    icon: "moon.stars.fill",
                    title: "How You Feel",
                    description: "Your subjective sleep experience matters",
                    color: palette.isDark ? palette.accent : Color(hex: "#6C5CE7")!,
                    isCompact: isCompact
                )

                PhilosophyCard(
                    icon: "waveform.path.ecg",
                    title: "What Happened",
                    description: "Wearable data shows objective truth",
                    color: palette.wave,
                    isCompact: isCompact
                )

                PhilosophyCard(
                    icon: "sparkles",
                    title: "The Gap Between",
                    description: "We bridge perception and reality",
                    color: palette.accent,
                    isCompact: isCompact
                )
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
    }
}

struct PhilosophyCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var isCompact: Bool = false

    private var palette: CircadianPalette { CircadianPalette.current }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(isCompact ? .subheadline : .body)
                .foregroundColor(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(palette.textPrimary)

                Text(description)
                    .font(.caption2)
                    .foregroundColor(palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(isCompact ? 10 : 12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Ready Step (Compact Celebration)

struct ReadyStepView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let screenHeight: CGFloat

    private var isCompact: Bool { screenHeight < 700 }
    private var palette: CircadianPalette { CircadianPalette.current }

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

                Text("Your 15-day sleep journey begins now")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

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
            }
            .padding(12)
            .background(palette.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            .cornerRadius(10)
            .padding(.horizontal, 20)

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
    var isCompact: Bool = false

    private var palette: CircadianPalette { CircadianPalette.current }

    var body: some View {
        HStack {
            Text(label)
                .font(isCompact ? .caption2 : .caption)
                .foregroundColor(palette.textSecondary)
            Spacer()
            Text(value)
                .font(isCompact ? .caption.weight(.medium) : .subheadline.weight(.medium))
                .foregroundColor(valueColor ?? palette.textPrimary)
        }
    }
}

// MARK: - Navigation Buttons (Compact)

struct OnboardingNavigationButtons: View {
    @ObservedObject var onboardingManager: OnboardingManager
    var showBack: Bool = false
    var nextLabel: String = FriendlyCopy.continueButton  // "Let's go" by default

    private var palette: CircadianPalette { CircadianPalette.current }

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
