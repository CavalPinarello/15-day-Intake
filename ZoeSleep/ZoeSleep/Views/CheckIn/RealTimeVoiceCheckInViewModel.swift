//
//  RealTimeVoiceCheckInViewModel.swift
//  ZoeSleep
//
//  ViewModel for real-time voice check-in using native iOS Speech Recognition.
//  Provides instant transcription with zero network latency.
//

import Foundation
import SwiftUI
import Speech
import AVFoundation
import Combine

@MainActor
class RealTimeVoiceCheckInViewModel: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isConnected = false
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var isComplete = false

    @Published var statusMessage = "Tap to start"
    @Published var userTranscript = ""
    @Published var agentMessage = ""

    @Published var currentStep: RealTimeCheckInStep? = .energy
    @Published var completedSteps = 0

    @Published var capturedEnergy: EnergyLevel?
    @Published var capturedMood: MoodLevel?
    @Published var capturedFocus: FocusLevel?

    @Published var showManualFallback = false
    @Published var audioLevel: Float = 0.0

    // MARK: - Speech Recognition

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Properties

    let timeSlot: CheckInTimeSlot
    private let checkInManager = CheckInManager.shared
    private var silenceTimer: Timer?
    private var lastTranscriptTime: Date?

    // MARK: - Computed Properties

    var orbState: ConversationOrbState {
        if !isConnected {
            return .idle
        } else if isListening {
            return .listening
        } else if isSpeaking {
            return .speaking
        } else {
            return .idle
        }
    }

    // MARK: - Initialization

    init(timeSlot: CheckInTimeSlot) {
        self.timeSlot = timeSlot
        super.init()
    }

    // MARK: - Session Management

    func startSession() async {
        statusMessage = "Setting up..."

        // Request speech recognition authorization
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard authStatus == .authorized else {
            statusMessage = "Speech recognition not authorized"
            showManualFallback = true
            return
        }

        // Request microphone permission
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusMessage = "Microphone access required"
            showManualFallback = true
            return
        }

        isConnected = true
        updatePromptForCurrentStep()
    }

    func endSession() {
        stopListening()
        isConnected = false
    }

    func startListening() {
        guard isConnected, !isListening else { return }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            statusMessage = "Speech recognition unavailable"
            showManualFallback = true
            return
        }

        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation

        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level for visualization
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData?[i] ?? 0)
            }
            let avgLevel = sum / Float(frameLength)
            Task { @MainActor in
                self?.audioLevel = min(1.0, avgLevel * 10)
            }
        }

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.userTranscript = transcript
                    self.lastTranscriptTime = Date()

                    // Check for final result or if user paused
                    if result.isFinal {
                        self.processTranscript(transcript)
                    }
                }

                if error != nil || result?.isFinal == true {
                    // Recognition ended
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            statusMessage = "Listening..."
            userTranscript = ""

            // Start silence detection timer
            startSilenceDetection()

        } catch {
            statusMessage = "Couldn't start listening"
            print("Audio engine start error: \(error)")
        }
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        guard isListening else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        isListening = false
        audioLevel = 0

        // Process final transcript if we have one
        if !userTranscript.isEmpty {
            processTranscript(userTranscript)
        }
    }

    // MARK: - Silence Detection

    private func startSilenceDetection() {
        lastTranscriptTime = Date()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSilence()
            }
        }
    }

    private func checkSilence() {
        guard isListening, let lastTime = lastTranscriptTime else { return }

        // If 2 seconds of silence after speech, process the transcript
        let silenceDuration = Date().timeIntervalSince(lastTime)
        if silenceDuration > 2.0 && !userTranscript.isEmpty {
            stopListening()
        }
    }

    // MARK: - Response Processing

    private func processTranscript(_ transcript: String) {
        let lowercased = transcript.lowercased()

        switch currentStep {
        case .energy:
            if let level = parseEnergyLevel(lowercased) {
                capturedEnergy = level
                completedSteps = 1
                currentStep = .mood
                userTranscript = ""
                updatePromptForCurrentStep()

                // Brief pause then listen again
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    startListening()
                }
            } else {
                statusMessage = "I didn't catch that. How's your energy? (1-6 or words like 'tired', 'good', 'great')"
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    startListening()
                }
            }

        case .mood:
            if let level = parseMoodLevel(lowercased) {
                capturedMood = level
                completedSteps = 2
                currentStep = .focus
                userTranscript = ""
                updatePromptForCurrentStep()

                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    startListening()
                }
            } else {
                statusMessage = "Try again. How's your mood? (1-6 or 'bad', 'okay', 'good', 'great')"
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    startListening()
                }
            }

        case .focus:
            if let level = parseFocusLevel(lowercased) {
                capturedFocus = level
                completedSteps = 3
                currentStep = nil
                submitCheckIn()
            } else {
                statusMessage = "One more time. How focused are you? (1-5 or 'foggy', 'okay', 'focused')"
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    startListening()
                }
            }

        case nil:
            break
        }
    }

    private func updatePromptForCurrentStep() {
        switch currentStep {
        case .energy:
            statusMessage = "How's your energy level?"
            agentMessage = "Say 1-6 or words like 'exhausted', 'tired', 'okay', 'good', 'great', 'energized'"
        case .mood:
            statusMessage = "How's your mood?"
            agentMessage = "Say 1-6 or 'terrible', 'bad', 'meh', 'okay', 'good', 'amazing'"
        case .focus:
            statusMessage = "How focused are you?"
            agentMessage = "Say 1-5 or 'foggy', 'distracted', 'okay', 'focused', 'crystal clear'"
        case nil:
            statusMessage = "All done!"
            agentMessage = ""
        }
    }

    // MARK: - Level Parsing

    private func parseEnergyLevel(_ text: String) -> EnergyLevel? {
        // EnergyLevel: sleepingSeal=1, turtle=2, cat=3, dog=4, ostrich=5, rabbit=6

        // Number-based parsing (most reliable)
        if let number = extractNumber(from: text, max: 6) {
            switch number {
            case 1: return .sleepingSeal
            case 2: return .turtle
            case 3: return .cat
            case 4: return .dog
            case 5: return .ostrich
            case 6: return .rabbit
            default: break
            }
        }

        // Word-based parsing
        if text.contains("exhausted") || text.contains("wiped") || text.contains("dead") || text.contains("none") {
            return .sleepingSeal
        } else if text.contains("very tired") || text.contains("really tired") || text.contains("low") || text.contains("terrible") {
            return .turtle
        } else if text.contains("tired") || text.contains("sluggish") || text.contains("meh") || text.contains("not great") {
            return .cat
        } else if text.contains("okay") || text.contains("alright") || text.contains("average") || text.contains("fine") || text.contains("so so") {
            return .dog
        } else if text.contains("good") || text.contains("pretty good") || text.contains("well") || text.contains("high") || text.contains("nice") {
            return .ostrich
        } else if text.contains("great") || text.contains("energized") || text.contains("excellent") || text.contains("amazing") || text.contains("fantastic") {
            return .rabbit
        }

        return nil
    }

    private func parseMoodLevel(_ text: String) -> MoodLevel? {
        // MoodLevel: stormy=1, rainy=2, cloudy=3, partlySunny=4, sunny=5, rainbow=6

        if let number = extractNumber(from: text, max: 6) {
            switch number {
            case 1: return .stormy
            case 2: return .rainy
            case 3: return .cloudy
            case 4: return .partlySunny
            case 5: return .sunny
            case 6: return .rainbow
            default: break
            }
        }

        if text.contains("terrible") || text.contains("awful") || text.contains("horrible") || text.contains("worst") {
            return .stormy
        } else if text.contains("bad") || text.contains("sad") || text.contains("down") || text.contains("low") {
            return .rainy
        } else if text.contains("meh") || text.contains("so-so") || text.contains("neutral") || text.contains("whatever") {
            return .cloudy
        } else if text.contains("okay") || text.contains("alright") || text.contains("fine") || text.contains("decent") {
            return .partlySunny
        } else if text.contains("good") || text.contains("happy") || text.contains("nice") || text.contains("pretty good") {
            return .sunny
        } else if text.contains("amazing") || text.contains("excellent") || text.contains("fantastic") || text.contains("wonderful") || text.contains("great") {
            return .rainbow
        }

        return nil
    }

    private func parseFocusLevel(_ text: String) -> FocusLevel? {
        // FocusLevel: foggy=1, hazy=2, clearing=3, clear=4, crystal=5

        if let number = extractNumber(from: text, max: 5) {
            switch number {
            case 1: return .foggy
            case 2: return .hazy
            case 3: return .clearing
            case 4: return .clear
            case 5: return .crystal
            default: break
            }
        }

        if text.contains("can't focus") || text.contains("foggy") || text.contains("scattered") || text.contains("completely") || text.contains("none") {
            return .foggy
        } else if text.contains("unfocused") || text.contains("distracted") || text.contains("hard") || text.contains("hazy") || text.contains("struggling") {
            return .hazy
        } else if text.contains("okay") || text.contains("alright") || text.contains("average") || text.contains("moderate") || text.contains("getting there") || text.contains("so so") {
            return .clearing
        } else if text.contains("focused") || text.contains("good") || text.contains("clear") || text.contains("pretty") {
            return .clear
        } else if text.contains("very focused") || text.contains("crystal") || text.contains("laser") || text.contains("excellent") || text.contains("sharp") || text.contains("great") {
            return .crystal
        }

        return nil
    }

    private func extractNumber(from text: String, max: Int) -> Int? {
        let numberWords: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
            "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6,
            "won": 1, "to": 2, "too": 2, "for": 4 // Common speech recognition mistakes
        ]

        for (word, number) in numberWords {
            if text.contains(word) && number <= max {
                return number
            }
        }

        // Also try to find standalone digits
        let pattern = "\\b([1-\(max)])\\b"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text),
           let number = Int(text[range]) {
            return number
        }

        return nil
    }

    // MARK: - Submission

    private func submitCheckIn() {
        guard let energy = capturedEnergy,
              let mood = capturedMood,
              let focus = capturedFocus else {
            return
        }

        statusMessage = "Saving..."

        Task {
            await checkInManager.submitWatchStyleCheckIn(
                timeSlot: timeSlot,
                energy: energy,
                mood: mood,
                focus: focus
            )

            await MainActor.run {
                statusMessage = "All set! ✓"

                // Brief delay to show completion
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    isComplete = true
                }
            }
        }
    }

    func switchToManualInput() {
        endSession()
    }
}
