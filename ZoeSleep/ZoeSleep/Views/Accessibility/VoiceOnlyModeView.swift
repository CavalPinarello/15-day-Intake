//
//  VoiceOnlyModeView.swift
//  ZoeSleep
//
//  Minimal visual UI for voice-first interaction.
//  Designed for elderly and vision-impaired users who prefer voice navigation.
//

import SwiftUI
import Combine

struct VoiceOnlyModeView: View {
    @StateObject private var accessibilityManager = AccessibilityVoiceManager.shared
    @StateObject private var easyModeManager = EasyModeManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: ColorTheme { themeManager.currentTheme }

    @State private var currentState: VoiceOnlyState = .idle
    @State private var currentPrompt: String = ""
    @State private var userTranscript: String = ""
    @State private var showingOptions: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // High contrast background
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Minimal header
                minimalHeader

                Spacer()

                // Central voice indicator
                centralVoiceArea

                Spacer()

                // Current prompt/response display
                promptDisplay

                Spacer()

                // Large action buttons
                actionButtons
            }
            .padding()
        }
        .onAppear {
            announceScreen()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityNavigateBack)) { _ in
            dismiss()
        }
    }

    // MARK: - Background

    private var backgroundColor: some View {
        Group {
            if accessibilityManager.highContrastMode {
                Color.black
            } else {
                theme.backgroundGradient
            }
        }
    }

    // MARK: - Minimal Header

    private var minimalHeader: some View {
        HStack {
            // Back button - large touch target
            Button {
                accessibilityManager.speak("Going back")
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title)
                    .foregroundColor(textColor)
                    .frame(width: accessibilityManager.minimumTouchTargetSize,
                           height: accessibilityManager.minimumTouchTargetSize)
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Go back")

            Spacer()

            // Help button
            Button {
                accessibilityManager.listAllCommands()
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title)
                    .foregroundColor(textColor)
                    .frame(width: accessibilityManager.minimumTouchTargetSize,
                           height: accessibilityManager.minimumTouchTargetSize)
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Help. List available commands")
        }
    }

    // MARK: - Central Voice Area

    private var centralVoiceArea: some View {
        VStack(spacing: 24) {
            // Large voice orb
            Button {
                toggleListening()
            } label: {
                ZStack {
                    // Outer ring for state indication
                    Circle()
                        .stroke(orbStrokeColor, lineWidth: 4)
                        .frame(width: 200, height: 200)

                    // Main orb
                    Circle()
                        .fill(orbFillColor)
                        .frame(width: 180, height: 180)

                    // Icon
                    Image(systemName: orbIcon)
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(orbIconColor)
                }
            }
            .accessibilityLabel(orbAccessibilityLabel)
            .accessibilityHint("Double tap to \(currentState == .listening ? "stop" : "start") listening")

            // State text
            Text(stateText)
                .font(.title2.bold())
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Prompt Display

    private var promptDisplay: some View {
        VStack(spacing: 16) {
            // Current prompt from Zoe
            if !currentPrompt.isEmpty {
                Text(currentPrompt)
                    .font(.title3)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(promptBackgroundColor)
                    .cornerRadius(16)
            }

            // User's transcript
            if !userTranscript.isEmpty && currentState == .listening {
                Text(userTranscript)
                    .font(.body)
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary action button
            Button {
                handlePrimaryAction()
            } label: {
                HStack {
                    Image(systemName: primaryActionIcon)
                        .font(.title2)
                    Text(primaryActionText)
                        .font(.headline)
                }
                .foregroundColor(accessibilityManager.highContrastMode ? .black : theme.textOnPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: accessibilityManager.buttonHeight)
                .background(primaryActionColor)
                .cornerRadius(16)
            }
            .accessibilityLabel(primaryActionText)

            // Secondary actions in horizontal row
            HStack(spacing: 16) {
                // Repeat button
                Button {
                    accessibilityManager.repeatLastContent()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("Repeat")
                            .font(.caption)
                    }
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: accessibilityManager.buttonHeight)
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Repeat last message")

                // Options button
                Button {
                    showingOptions = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                        Text("Options")
                            .font(.caption)
                    }
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: accessibilityManager.buttonHeight)
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
                }
                .accessibilityLabel("More options")

                // Home button
                Button {
                    accessibilityManager.speak("Going to home screen")
                    NotificationCenter.default.post(name: .accessibilityNavigateHome, object: nil)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "house")
                            .font(.title2)
                        Text("Home")
                            .font(.caption)
                    }
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: accessibilityManager.buttonHeight)
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Go to home screen")
            }
        }
        .sheet(isPresented: $showingOptions) {
            VoiceOptionsSheet()
        }
    }

    // MARK: - Computed Properties

    private var textColor: Color {
        accessibilityManager.highContrastMode ? .white : theme.primaryText
    }

    private var secondaryTextColor: Color {
        accessibilityManager.highContrastMode ? .white.opacity(0.7) : theme.secondaryText
    }

    private var buttonBackgroundColor: Color {
        accessibilityManager.highContrastMode ? .white.opacity(0.2) : theme.cardBackground
    }

    private var promptBackgroundColor: Color {
        accessibilityManager.highContrastMode ? .white.opacity(0.1) : theme.cardBackground.opacity(0.8)
    }

    private var primaryActionColor: Color {
        accessibilityManager.highContrastMode ? .white : theme.accent
    }

    private var orbFillColor: Color {
        switch currentState {
        case .idle:
            return accessibilityManager.highContrastMode ? .gray : theme.cardBackground
        case .listening:
            return accessibilityManager.highContrastMode ? .green : theme.accent
        case .processing:
            return accessibilityManager.highContrastMode ? .yellow : theme.accent.opacity(0.7)
        case .speaking:
            return accessibilityManager.highContrastMode ? .blue : theme.accent
        case .error:
            return .red
        }
    }

    private var orbStrokeColor: Color {
        switch currentState {
        case .listening:
            return accessibilityManager.highContrastMode ? .green : theme.accent
        default:
            return .clear
        }
    }

    private var orbIcon: String {
        switch currentState {
        case .idle: return "mic.fill"
        case .listening: return "waveform"
        case .processing: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var orbIconColor: Color {
        accessibilityManager.highContrastMode ? .white : theme.textOnPrimary
    }

    private var orbAccessibilityLabel: String {
        switch currentState {
        case .idle: return "Tap to speak"
        case .listening: return "Listening. Tap to stop"
        case .processing: return "Processing your request"
        case .speaking: return "Zoe is speaking"
        case .error: return "Error occurred"
        }
    }

    private var stateText: String {
        switch currentState {
        case .idle: return "Tap to speak"
        case .listening: return "Listening..."
        case .processing: return "Thinking..."
        case .speaking: return "Zoe is speaking"
        case .error: return "Something went wrong"
        }
    }

    private var primaryActionText: String {
        switch currentState {
        case .idle: return "Start Speaking"
        case .listening: return "Done Speaking"
        case .processing: return "Please Wait"
        case .speaking: return "Interrupt"
        case .error: return "Try Again"
        }
    }

    private var primaryActionIcon: String {
        switch currentState {
        case .idle: return "mic.fill"
        case .listening: return "checkmark.circle.fill"
        case .processing: return "clock.fill"
        case .speaking: return "hand.raised.fill"
        case .error: return "arrow.clockwise"
        }
    }

    // MARK: - Actions

    private func announceScreen() {
        accessibilityManager.speak(
            "Voice mode active. Tap the large circle or say 'start' to speak. Say 'help' for commands."
        )
    }

    private func toggleListening() {
        switch currentState {
        case .idle, .error:
            startListening()
        case .listening:
            stopListening()
        case .speaking:
            // Interrupt
            currentState = .idle
            accessibilityManager.speak("Interrupted")
        case .processing:
            // Can't interrupt processing
            break
        }
    }

    private func handlePrimaryAction() {
        toggleListening()
    }

    private func startListening() {
        currentState = .listening
        userTranscript = ""

        Task {
            do {
                try await easyModeManager.startRecording()
            } catch {
                currentState = .error
                accessibilityManager.speak("Could not start listening. Please try again.")
            }
        }
    }

    private func stopListening() {
        currentState = .processing

        Task {
            // Stop recording and process
            easyModeManager.stopRecording()

            // The EasyModeManager should handle transcription and response
            // We simulate the flow here
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Check for voice commands first
            if let command = accessibilityManager.processVoiceCommand(userTranscript) {
                currentState = .idle
                // Command was handled
            } else {
                // Process as regular input
                currentState = .speaking
                currentPrompt = "I heard: " + userTranscript
                accessibilityManager.speak(currentPrompt)

                try? await Task.sleep(nanoseconds: 2_000_000_000)
                currentState = .idle
            }
        }
    }
}

// MARK: - Voice Only State

enum VoiceOnlyState {
    case idle
    case listening
    case processing
    case speaking
    case error
}

// MARK: - Voice Options Sheet

struct VoiceOptionsSheet: View {
    @StateObject private var accessibilityManager = AccessibilityVoiceManager.shared
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Speech settings
                Section("Speech") {
                    HStack {
                        Text("Speech Speed")
                        Spacer()
                        Text(speedLabel)
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $accessibilityManager.ttsSpeed,
                        in: 0.5...1.0,
                        step: 0.05
                    )

                    Toggle("Auto-Read Content", isOn: $accessibilityManager.autoReadContent)

                    Toggle("Voice Feedback", isOn: $accessibilityManager.voiceFeedback)
                }

                // Timing settings
                Section("Timing") {
                    HStack {
                        Text("Silence Timeout")
                        Spacer()
                        Text("\(Int(accessibilityManager.silenceTimeout))s")
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $accessibilityManager.silenceTimeout,
                        in: 2...10,
                        step: 1
                    )
                }

                // Visual settings
                Section("Display") {
                    Toggle("Large Touch Targets", isOn: $accessibilityManager.useLargeTouchTargets)

                    Toggle("High Contrast", isOn: $accessibilityManager.highContrastMode)
                }

                // Presets
                Section("Quick Setup") {
                    Button("Elderly-Friendly Settings") {
                        accessibilityManager.applyElderlyPreset()
                        dismiss()
                    }

                    Button("Vision-Impaired Settings") {
                        accessibilityManager.applyVisionImpairedPreset()
                        dismiss()
                    }

                    Button("Reset to Defaults") {
                        accessibilityManager.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Voice Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var speedLabel: String {
        let speed = accessibilityManager.ttsSpeed
        if speed < 0.7 {
            return "Very Slow"
        } else if speed < 0.85 {
            return "Slow"
        } else if speed < 0.95 {
            return "Normal"
        } else {
            return "Fast"
        }
    }
}

// MARK: - Preview

#Preview {
    VoiceOnlyModeView()
        .environmentObject(ThemeManager.shared)
}
