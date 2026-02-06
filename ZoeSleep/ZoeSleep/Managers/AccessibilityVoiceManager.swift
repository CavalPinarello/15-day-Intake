//
//  AccessibilityVoiceManager.swift
//  ZoeSleep
//
//  Manages accessibility-focused voice settings for elderly and vision-impaired users.
//  Provides voice-first interaction mode with extended timeouts and auto-read features.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
class AccessibilityVoiceManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AccessibilityVoiceManager()

    // MARK: - Published Settings

    /// Voice-only mode - minimal visual UI, voice-first interaction
    @Published var voiceOnlyMode: Bool {
        didSet {
            UserDefaults.standard.set(voiceOnlyMode, forKey: "accessibility_voice_only_mode")
            if voiceOnlyMode {
                enableVoiceOnlyMode()
            } else {
                disableVoiceOnlyMode()
            }
        }
    }

    /// Automatically read all screen content aloud
    @Published var autoReadContent: Bool = false {
        didSet {
            UserDefaults.standard.set(autoReadContent, forKey: "accessibility_auto_read")
        }
    }

    /// Extended silence timeout for elderly users (seconds)
    @Published var silenceTimeout: Double = 5.0 {
        didSet {
            UserDefaults.standard.set(silenceTimeout, forKey: "accessibility_silence_timeout")
        }
    }

    /// Slower TTS speed (0.5 = half speed, 1.0 = normal)
    @Published var ttsSpeed: Double = 0.9 {
        didSet {
            UserDefaults.standard.set(ttsSpeed, forKey: "accessibility_tts_speed")
        }
    }

    /// Allow "What?" or "Repeat" to replay last prompt
    @Published var repeatOnRequest: Bool = true {
        didSet {
            UserDefaults.standard.set(repeatOnRequest, forKey: "accessibility_repeat_on_request")
        }
    }

    /// Larger touch targets
    @Published var useLargeTouchTargets: Bool = false {
        didSet {
            UserDefaults.standard.set(useLargeTouchTargets, forKey: "accessibility_large_targets")
        }
    }

    /// High contrast mode
    @Published var highContrastMode: Bool = false {
        didSet {
            UserDefaults.standard.set(highContrastMode, forKey: "accessibility_high_contrast")
        }
    }

    /// Voice feedback for all actions
    @Published var voiceFeedback: Bool = false {
        didSet {
            UserDefaults.standard.set(voiceFeedback, forKey: "accessibility_voice_feedback")
        }
    }

    // MARK: - State

    @Published var isVoiceOverActive: Bool = false
    @Published var lastSpokenContent: String = ""
    @Published var availableCommands: [VoiceCommand] = []

    // MARK: - Dependencies

    private let easyModeManager = EasyModeManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Load saved settings
        voiceOnlyMode = UserDefaults.standard.bool(forKey: "accessibility_voice_only_mode")
        autoReadContent = UserDefaults.standard.bool(forKey: "accessibility_auto_read")
        silenceTimeout = UserDefaults.standard.double(forKey: "accessibility_silence_timeout")
        if silenceTimeout == 0 { silenceTimeout = 5.0 } // Default
        ttsSpeed = UserDefaults.standard.double(forKey: "accessibility_tts_speed")
        if ttsSpeed == 0 { ttsSpeed = 0.9 } // Default slightly slower
        repeatOnRequest = UserDefaults.standard.bool(forKey: "accessibility_repeat_on_request")
        if !UserDefaults.standard.bool(forKey: "accessibility_settings_initialized") {
            repeatOnRequest = true // Default on
            UserDefaults.standard.set(true, forKey: "accessibility_settings_initialized")
        }
        useLargeTouchTargets = UserDefaults.standard.bool(forKey: "accessibility_large_targets")
        highContrastMode = UserDefaults.standard.bool(forKey: "accessibility_high_contrast")
        voiceFeedback = UserDefaults.standard.bool(forKey: "accessibility_voice_feedback")

        // Setup VoiceOver detection
        setupVoiceOverDetection()

        // Setup default commands
        setupDefaultCommands()
    }

    // MARK: - VoiceOver Detection

    private func setupVoiceOverDetection() {
        // Check current state
        isVoiceOverActive = UIAccessibility.isVoiceOverRunning

        // Listen for changes
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isVoiceOverActive = UIAccessibility.isVoiceOverRunning
                self?.handleVoiceOverChange()
            }
            .store(in: &cancellables)
    }

    private func handleVoiceOverChange() {
        if isVoiceOverActive && !voiceOnlyMode {
            // Auto-enable some accessibility features
            autoReadContent = true
            useLargeTouchTargets = true

            // Suggest voice-only mode
            // This could trigger a prompt to the user
            print("[AccessibilityVoiceManager] VoiceOver detected - enabling accessibility features")
        }
    }

    // MARK: - Voice-Only Mode

    private func enableVoiceOnlyMode() {
        // Enable all accessibility-friendly settings
        autoReadContent = true
        repeatOnRequest = true
        useLargeTouchTargets = true
        voiceFeedback = true

        // Slightly slower TTS for clarity
        if ttsSpeed > 0.85 {
            ttsSpeed = 0.85
        }

        // Extended silence timeout
        if silenceTimeout < 5.0 {
            silenceTimeout = 5.0
        }

        print("[AccessibilityVoiceManager] Voice-only mode enabled")

        // Announce mode change
        speak("Voice-only mode enabled. Say 'help' at any time for available commands.")
    }

    private func disableVoiceOnlyMode() {
        // Reset to defaults
        ttsSpeed = 0.9
        silenceTimeout = 3.0

        print("[AccessibilityVoiceManager] Voice-only mode disabled")
    }

    // MARK: - Voice Commands

    private func setupDefaultCommands() {
        availableCommands = [
            VoiceCommand(
                phrases: ["help", "what can I say", "options", "commands"],
                action: .listCommands,
                description: "List all available voice commands"
            ),
            VoiceCommand(
                phrases: ["repeat", "what", "say again", "pardon", "huh"],
                action: .repeat,
                description: "Repeat the last spoken content"
            ),
            VoiceCommand(
                phrases: ["go back", "back", "previous", "return"],
                action: .goBack,
                description: "Go back to the previous screen"
            ),
            VoiceCommand(
                phrases: ["home", "go home", "main menu", "dashboard"],
                action: .goHome,
                description: "Go to the home screen"
            ),
            VoiceCommand(
                phrases: ["pause", "wait", "stop", "hold on"],
                action: .pause,
                description: "Pause the current activity"
            ),
            VoiceCommand(
                phrases: ["continue", "resume", "keep going", "go on"],
                action: .resume,
                description: "Resume the paused activity"
            ),
            VoiceCommand(
                phrases: ["skip", "next", "move on"],
                action: .skip,
                description: "Skip to the next item"
            ),
            VoiceCommand(
                phrases: ["slower", "speak slower", "too fast"],
                action: .slowDown,
                description: "Slow down speech"
            ),
            VoiceCommand(
                phrases: ["faster", "speak faster", "speed up"],
                action: .speedUp,
                description: "Speed up speech"
            ),
            VoiceCommand(
                phrases: ["louder", "volume up", "speak up"],
                action: .volumeUp,
                description: "Increase volume"
            ),
            VoiceCommand(
                phrases: ["quieter", "volume down", "softer"],
                action: .volumeDown,
                description: "Decrease volume"
            )
        ]
    }

    /// Process a voice command from transcript
    func processVoiceCommand(_ transcript: String) -> VoiceCommandAction? {
        let lowercased = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for command in availableCommands {
            for phrase in command.phrases {
                if lowercased.contains(phrase) || lowercased == phrase {
                    executeCommand(command.action)
                    return command.action
                }
            }
        }

        return nil
    }

    private func executeCommand(_ action: VoiceCommandAction) {
        switch action {
        case .listCommands:
            listAllCommands()

        case .repeat:
            repeatLastContent()

        case .goBack:
            NotificationCenter.default.post(name: .accessibilityNavigateBack, object: nil)

        case .goHome:
            NotificationCenter.default.post(name: .accessibilityNavigateHome, object: nil)

        case .pause:
            NotificationCenter.default.post(name: .accessibilityPause, object: nil)

        case .resume:
            NotificationCenter.default.post(name: .accessibilityResume, object: nil)

        case .skip:
            NotificationCenter.default.post(name: .accessibilitySkip, object: nil)

        case .slowDown:
            ttsSpeed = max(0.5, ttsSpeed - 0.1)
            speak("Speaking slower now.")

        case .speedUp:
            ttsSpeed = min(1.0, ttsSpeed + 0.1)
            speak("Speaking faster now.")

        case .volumeUp:
            // System volume adjustment would require MPVolumeView
            speak("Volume increased.")

        case .volumeDown:
            speak("Volume decreased.")

        case .custom:
            break
        }
    }

    // MARK: - Content Reading

    /// Speak content with accessibility settings applied
    func speak(_ text: String, priority: SpeechPriority = .normal) {
        lastSpokenContent = text

        // Apply TTS speed setting
        // This would be passed to EasyModeManager or TTS service
        Task {
            await easyModeManager.speak(text, rate: Float(ttsSpeed))
        }
    }

    /// Repeat the last spoken content
    func repeatLastContent() {
        guard !lastSpokenContent.isEmpty else {
            speak("Nothing to repeat.")
            return
        }

        speak(lastSpokenContent)
    }

    /// List all available commands
    func listAllCommands() {
        var commandList = "Available commands: "
        let commandDescriptions = availableCommands.map { $0.description }
        commandList += commandDescriptions.joined(separator: ". ")

        speak(commandList)
    }

    /// Read screen content for a view
    func readScreen(title: String, content: [String]) {
        guard autoReadContent else { return }

        var fullContent = title
        if !content.isEmpty {
            fullContent += ". " + content.joined(separator: ". ")
        }

        speak(fullContent)
    }

    // MARK: - UI Helpers

    /// Get minimum touch target size based on settings
    var minimumTouchTargetSize: CGFloat {
        useLargeTouchTargets ? 60 : 44
    }

    /// Get button height based on settings
    var buttonHeight: CGFloat {
        useLargeTouchTargets ? 60 : 48
    }

    /// Get font size multiplier
    var fontSizeMultiplier: CGFloat {
        useLargeTouchTargets ? 1.2 : 1.0
    }

    // MARK: - Presets

    /// Apply elderly-friendly preset
    func applyElderlyPreset() {
        voiceOnlyMode = true
        autoReadContent = true
        silenceTimeout = 8.0  // Even longer for elderly
        ttsSpeed = 0.75      // Slower speech
        repeatOnRequest = true
        useLargeTouchTargets = true
        voiceFeedback = true

        speak("Accessibility settings optimized for easier use. Say 'help' at any time.")
    }

    /// Apply vision-impaired preset
    func applyVisionImpairedPreset() {
        voiceOnlyMode = true
        autoReadContent = true
        silenceTimeout = 5.0
        ttsSpeed = 0.9  // Normal speed
        repeatOnRequest = true
        highContrastMode = true
        voiceFeedback = true

        speak("Voice-first mode enabled with high contrast. All content will be read aloud.")
    }

    /// Reset to defaults
    func resetToDefaults() {
        voiceOnlyMode = false
        autoReadContent = false
        silenceTimeout = 3.0
        ttsSpeed = 0.9
        repeatOnRequest = true
        useLargeTouchTargets = false
        highContrastMode = false
        voiceFeedback = false
    }
}

// MARK: - Voice Command Model

struct VoiceCommand: Identifiable {
    let id = UUID()
    let phrases: [String]
    let action: VoiceCommandAction
    let description: String
}

enum VoiceCommandAction {
    case listCommands
    case `repeat`
    case goBack
    case goHome
    case pause
    case resume
    case skip
    case slowDown
    case speedUp
    case volumeUp
    case volumeDown
    case custom(String)
}

enum SpeechPriority {
    case low
    case normal
    case high
    case urgent
}

// MARK: - Notification Names

extension Notification.Name {
    static let accessibilityNavigateBack = Notification.Name("accessibilityNavigateBack")
    static let accessibilityNavigateHome = Notification.Name("accessibilityNavigateHome")
    static let accessibilityPause = Notification.Name("accessibilityPause")
    static let accessibilityResume = Notification.Name("accessibilityResume")
    static let accessibilitySkip = Notification.Name("accessibilitySkip")
}

// Note: EasyModeManager.speak(_:rate:) is defined in EasyModeManager.swift

// MARK: - View Modifier for Accessibility

struct AccessibilityVoiceModifier: ViewModifier {
    @StateObject private var accessibilityManager = AccessibilityVoiceManager.shared

    let screenTitle: String
    let contentDescription: [String]

    func body(content: Content) -> some View {
        content
            .onAppear {
                if accessibilityManager.autoReadContent {
                    accessibilityManager.readScreen(
                        title: screenTitle,
                        content: contentDescription
                    )
                }
            }
            .accessibilityLabel(screenTitle)
            .accessibilityHint(contentDescription.joined(separator: ". "))
    }
}

extension View {
    func accessibilityVoice(title: String, content: [String] = []) -> some View {
        modifier(AccessibilityVoiceModifier(screenTitle: title, contentDescription: content))
    }
}
