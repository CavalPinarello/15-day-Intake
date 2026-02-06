//
//  VoiceCheckInFlowViewModel.swift
//  ZoeSleep
//
//  ViewModel for voice-based check-in flow
//  Manages the 3-step Energy -> Mood -> Focus voice check-in
//

import Foundation
import SwiftUI
import Combine

/// Represents the current step in the voice check-in flow
enum VoiceCheckInStep: Int, CaseIterable {
    case energy = 0
    case mood = 1
    case focus = 2

    var title: String {
        switch self {
        case .energy: return "Energy"
        case .mood: return "Mood"
        case .focus: return "Focus"
        }
    }

    var promptText: String {
        switch self {
        case .energy:
            return "How's your energy level right now?"
        case .mood:
            return "How's your mood feeling?"
        case .focus:
            return "How focused are you?"
        }
    }

    var helpText: String {
        switch self {
        case .energy:
            return "Say things like exhausted, tired, okay, good, high, or energized"
        case .mood:
            return "Say things like terrible, sad, neutral, good, happy, or amazing"
        case .focus:
            return "Say things like foggy, distracted, okay, focused, or crystal clear"
        }
    }

    var sfSymbol: String {
        switch self {
        case .energy: return "bolt.fill"
        case .mood: return "face.smiling.fill"
        case .focus: return "eye.fill"
        }
    }

    var levelType: CheckInLevelType {
        switch self {
        case .energy: return .energy
        case .mood: return .mood
        case .focus: return .focus
        }
    }

    var next: VoiceCheckInStep? {
        VoiceCheckInStep(rawValue: rawValue + 1)
    }

    var isLast: Bool {
        self == .focus
    }
}

/// State of the voice check-in flow
enum VoiceCheckInFlowState: Equatable {
    case ready               // Ready to start recording
    case listening           // Recording audio
    case processing          // Transcribing and parsing
    case confirming          // Showing parsed result for confirmation
    case transitioning       // Moving to next step
    case submitting          // Submitting final check-in
    case completed           // All done
    case error(String)       // Error with message
}

@MainActor
class VoiceCheckInFlowViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentStep: VoiceCheckInStep = .energy
    @Published var flowState: VoiceCheckInFlowState = .ready

    @Published var selectedEnergy: EnergyLevel?
    @Published var selectedMood: MoodLevel?
    @Published var selectedFocus: FocusLevel?

    @Published var currentTranscript: String = ""
    @Published var showConfirmation: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let easyModeManager = EasyModeManager.shared
    private let audioManager = AudioSessionManager.shared
    private let checkInManager = CheckInManager.shared

    // MARK: - Properties

    let timeSlot: CheckInTimeSlot
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var progress: Double {
        Double(currentStep.rawValue) / Double(VoiceCheckInStep.allCases.count)
    }

    var isRecording: Bool {
        audioManager.isRecording
    }

    var audioLevel: Float {
        audioManager.audioLevel
    }

    var canSubmit: Bool {
        selectedEnergy != nil && selectedMood != nil && selectedFocus != nil
    }

    var orbState: ZoeOrbState {
        switch flowState {
        case .listening:
            return .listening
        case .processing:
            return .thinking
        case .confirming, .transitioning:
            return .speaking
        default:
            return .idle
        }
    }

    // MARK: - Initialization

    init(timeSlot: CheckInTimeSlot) {
        self.timeSlot = timeSlot
        setupObservers()
    }

    private func setupObservers() {
        // Observe voice state changes
        easyModeManager.$voiceState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleVoiceStateChange(state)
            }
            .store(in: &cancellables)

        // Observe audio manager for silence detection
        audioManager.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if self?.flowState == .listening && !isRecording {
                    // Recording stopped (silence detected)
                    self?.processRecording()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Voice State Handling

    private func handleVoiceStateChange(_ state: VoiceInputState) {
        switch state {
        case .idle:
            if flowState != .confirming && flowState != .completed {
                flowState = .ready
            }
        case .listening:
            flowState = .listening
        case .processing, .parsing:
            flowState = .processing
        case .confirming(let response):
            handleParsedResponse(response)
        case .error(let error):
            flowState = .error(error.userMessage)
            errorMessage = error.userMessage
        }
    }

    // MARK: - Recording Actions

    func startRecording() async {
        guard flowState == .ready else { return }

        errorMessage = nil
        flowState = .listening

        do {
            try await easyModeManager.startRecording()
        } catch {
            flowState = .error("Failed to start recording")
            errorMessage = "Couldn't access microphone. Please check permissions."
        }
    }

    func stopRecording() {
        guard flowState == .listening else { return }
        audioManager.stopRecording()
    }

    private func processRecording() {
        guard flowState == .listening else { return }
        flowState = .processing

        Task {
            await processCurrentStepAudio()
        }
    }

    private func processCurrentStepAudio() async {
        do {
            // Get audio data
            guard let audioData = audioManager.getRecordedAudioData() else {
                throw VoiceError.noAudioRecorded
            }

            // Transcribe
            let transcript = try await ConvexService.shared.callVoiceTranscribe(
                audioBase64: audioData.base64EncodedString()
            )
            currentTranscript = transcript

            // Parse based on current step
            if let parsed = parseTranscriptForCurrentStep(transcript) {
                applyParsedValue(parsed)
                flowState = .confirming
                showConfirmation = true

                // Auto-confirm after TTS reads confirmation
                await speakConfirmation(parsed)
            } else {
                // Try LLM parsing as fallback
                await llmParseForCurrentStep(transcript)
            }
        } catch {
            flowState = .error("Couldn't understand. Please try again.")
            errorMessage = error.localizedDescription
        }
    }

    private func parseTranscriptForCurrentStep(_ transcript: String) -> ParsedValue? {
        return CheckInLevelParser.parse(transcript: transcript, for: currentStep.levelType)
    }

    private func llmParseForCurrentStep(_ transcript: String) async {
        do {
            let context = VoiceParsingContext(
                questionId: "checkin_\(currentStep.rawValue)",
                questionText: currentStep.promptText,
                questionType: currentStep.levelType == .energy ? "energyLevel" :
                              currentStep.levelType == .mood ? "moodLevel" : "focusLevel",
                options: nil,
                minValue: 1,
                maxValue: currentStep.levelType == .focus ? 5 : 6
            )

            let response = try await ConvexService.shared.callVoiceParseResponse(
                transcript: transcript,
                context: context
            )

            applyParsedResponse(response)
            flowState = .confirming
            showConfirmation = true

            await speakConfirmation(response.value)
        } catch {
            flowState = .error("Couldn't understand. Please try again.")
            errorMessage = "Try saying something like '\(currentStep.helpText)'"
        }
    }

    private func handleParsedResponse(_ response: ParsedResponse) {
        currentTranscript = response.transcript
        applyParsedValue(response.value)
        flowState = .confirming
        showConfirmation = true
    }

    private func applyParsedValue(_ value: ParsedValue) {
        switch value {
        case .energyLevel(let level):
            selectedEnergy = level
        case .moodLevel(let level):
            selectedMood = level
        case .focusLevel(let level):
            selectedFocus = level
        case .number(let num):
            // Map number to level
            applyNumericValue(Int(num))
        default:
            break
        }
    }

    private func applyParsedResponse(_ response: ParsedResponse) {
        applyParsedValue(response.value)
    }

    private func applyNumericValue(_ value: Int) {
        switch currentStep {
        case .energy:
            selectedEnergy = EnergyLevel(rawValue: min(max(value, 1), 6))
        case .mood:
            selectedMood = MoodLevel(rawValue: min(max(value, 1), 6))
        case .focus:
            selectedFocus = FocusLevel(rawValue: min(max(value, 1), 5))
        }
    }

    // MARK: - TTS

    private func speakConfirmation(_ value: ParsedValue) async {
        let confirmText: String
        switch value {
        case .energyLevel(let level):
            confirmText = "Got it, your energy is \(level.label.lowercased())."
        case .moodLevel(let level):
            confirmText = "Got it, your mood is \(level.label.lowercased())."
        case .focusLevel(let level):
            confirmText = "Got it, your focus is \(level.label.lowercased())."
        default:
            confirmText = "Got it."
        }

        await easyModeManager.speak(confirmText)
    }

    func speakCurrentPrompt() async {
        let prompt = currentStep.promptText + " " + currentStep.helpText
        await easyModeManager.speak(prompt)
    }

    // MARK: - Navigation

    func confirmAndContinue() {
        showConfirmation = false

        if let nextStep = currentStep.next {
            flowState = .transitioning

            Task {
                // Brief pause before next step
                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    currentStep = nextStep
                    flowState = .ready
                }

                // Speak the next prompt
                await speakCurrentPrompt()
            }
        } else {
            // All steps done, submit
            submitCheckIn()
        }
    }

    func retry() {
        showConfirmation = false
        flowState = .ready
        errorMessage = nil

        // Clear the current step's selection
        switch currentStep {
        case .energy: selectedEnergy = nil
        case .mood: selectedMood = nil
        case .focus: selectedFocus = nil
        }
    }

    func goBack() {
        guard currentStep.rawValue > 0 else { return }

        if let previousStep = VoiceCheckInStep(rawValue: currentStep.rawValue - 1) {
            currentStep = previousStep
            flowState = .ready
            showConfirmation = false
        }
    }

    // MARK: - Manual Selection (Fallback)

    func selectEnergy(_ level: EnergyLevel) {
        selectedEnergy = level
        if currentStep == .energy {
            confirmAndContinue()
        }
    }

    func selectMood(_ level: MoodLevel) {
        selectedMood = level
        if currentStep == .mood {
            confirmAndContinue()
        }
    }

    func selectFocus(_ level: FocusLevel) {
        selectedFocus = level
        if currentStep == .focus {
            confirmAndContinue()
        }
    }

    // MARK: - Submission

    func submitCheckIn() {
        guard canSubmit,
              let energy = selectedEnergy,
              let mood = selectedMood,
              let focus = selectedFocus else {
            errorMessage = "Please complete all steps"
            return
        }

        flowState = .submitting

        Task {
            await checkInManager.submitWatchStyleCheckIn(
                timeSlot: timeSlot,
                energy: energy,
                mood: mood,
                focus: focus
            )

            await MainActor.run {
                flowState = .completed
            }
        }
    }

    // MARK: - Display Values

    var currentDisplayValue: String? {
        switch currentStep {
        case .energy:
            return selectedEnergy?.label
        case .mood:
            return selectedMood?.label
        case .focus:
            return selectedFocus?.label
        }
    }

    var currentDisplayIcon: String? {
        switch currentStep {
        case .energy:
            return selectedEnergy?.sfSymbol
        case .mood:
            return selectedMood?.sfSymbol
        case .focus:
            return selectedFocus?.sfSymbol
        }
    }

    var currentDisplayColor: Color? {
        switch currentStep {
        case .energy:
            return selectedEnergy?.color
        case .mood:
            return selectedMood?.color
        case .focus:
            return selectedFocus?.color
        }
    }
}
