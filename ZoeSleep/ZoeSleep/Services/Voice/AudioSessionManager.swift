//
//  AudioSessionManager.swift
//  ZoeSleep
//
//  Manages AVAudioSession for recording voice input and playing TTS audio
//  Handles switching between recording and playback modes
//

import Foundation
import AVFoundation
import Combine

/// Manages audio session configuration for Easy Mode voice features
class AudioSessionManager: NSObject, ObservableObject {
    static let shared = AudioSessionManager()

    // MARK: - Published State

    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var audioLevel: Float = 0.0  // 0.0 to 1.0 for waveform display
    @Published private(set) var hasMicrophonePermission: Bool?

    /// Callback when silence is detected (for auto-stop)
    var onSilenceDetected: (() -> Void)?

    // Silence detection settings
    private let silenceThreshold: Float = 0.05  // Audio level below this = silence
    private let silenceDuration: TimeInterval = 1.2  // Seconds of silence before auto-stop (was 1.5)
    private let minimumSpeechDuration: TimeInterval = 0.5  // Minimum speech before silence detection activates
    private var silenceStartTime: Date?
    private var speechStartTime: Date?  // Track when speech started
    private var hasDetectedSpeech = false

    // MARK: - Audio Components

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var levelTimer: Timer?

    // Recording settings
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    // Temporary file URL for recording (ephemeral - deleted after use)
    private var recordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("voice_input.m4a")
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        checkMicrophonePermission()
    }

    // MARK: - Permission Handling

    /// Check and request microphone permission
    func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            hasMicrophonePermission = true
        case .denied:
            hasMicrophonePermission = false
        case .undetermined:
            hasMicrophonePermission = nil
        @unknown default:
            hasMicrophonePermission = nil
        }
    }

    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.hasMicrophonePermission = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Audio Session Configuration

    /// Configure audio session for recording
    private func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    /// Configure audio session for playback (TTS)
    private func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()

        // Deactivate first to avoid conflicts when switching categories
        try? session.setActive(false, options: .notifyOthersOnDeactivation)

        // Use playAndRecord with defaultToSpeaker so we can play through speaker
        // This avoids issues when switching between recording and playback modes
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    /// Deactivate audio session
    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSessionManager: Failed to deactivate session: \(error)")
        }
    }

    // MARK: - Recording

    /// Start recording audio
    func startRecording() async throws {
        guard hasMicrophonePermission == true else {
            throw VoiceError.microphonePermissionDenied
        }

        // Clean up any existing recording
        stopRecording()
        deleteRecordingFile()

        try configureForRecording()

        audioRecorder = try AVAudioRecorder(url: recordingURL, settings: recordingSettings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.delegate = self

        guard audioRecorder?.record() == true else {
            throw VoiceError.noAudioRecorded
        }

        await MainActor.run {
            isRecording = true
        }

        startLevelMonitoring()
    }

    /// Stop recording and return the audio data
    func stopRecording() -> Data? {
        stopLevelMonitoring()

        guard let recorder = audioRecorder, recorder.isRecording else {
            return nil
        }

        recorder.stop()

        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }

        // Read the recorded data
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            return nil
        }

        let data = try? Data(contentsOf: recordingURL)

        // Clean up the temp file
        deleteRecordingFile()

        audioRecorder = nil

        return data
    }

    /// Get recorded audio data without cleaning up (for cases where stopRecording already called)
    func getRecordedAudioData() -> Data? {
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            return nil
        }
        return try? Data(contentsOf: recordingURL)
    }

    /// Cancel recording without returning data
    func cancelRecording() {
        stopLevelMonitoring()

        if let recorder = audioRecorder, recorder.isRecording {
            recorder.stop()
        }

        deleteRecordingFile()
        audioRecorder = nil

        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }

    private func deleteRecordingFile() {
        try? FileManager.default.removeItem(at: recordingURL)
    }

    // MARK: - Level Monitoring (for waveform visualization)

    private func startLevelMonitoring() {
        // Reset silence detection state
        silenceStartTime = nil
        speechStartTime = nil
        hasDetectedSpeech = false

        // IMPORTANT: Schedule timer on main RunLoop to ensure it fires in async contexts
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else {
                    return
                }

                recorder.updateMeters()

                // Convert dB to linear scale (0.0 to 1.0)
                let averagePower = recorder.averagePower(forChannel: 0)
                // dB range is typically -160 to 0
                // Map -50dB to 0dB → 0.0 to 1.0
                let minDb: Float = -50.0
                let normalizedLevel = max(0, min(1, (averagePower - minDb) / abs(minDb)))

                self.audioLevel = normalizedLevel

                // Silence detection for auto-stop
                self.detectSilence(level: normalizedLevel)
            }

            self.levelTimer = timer
            // Add to main RunLoop in common mode to ensure it fires during scrolling etc.
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Detect silence and auto-stop recording after user finishes speaking
    private func detectSilence(level: Float) {
        if level > silenceThreshold {
            // User is speaking
            if !hasDetectedSpeech {
                // First speech detected - start tracking
                speechStartTime = Date()
                print("AudioSessionManager: Speech started")
            }
            hasDetectedSpeech = true
            silenceStartTime = nil
        } else if hasDetectedSpeech {
            // Check minimum speech duration before allowing silence detection
            guard let speechStart = speechStartTime,
                  Date().timeIntervalSince(speechStart) >= minimumSpeechDuration else {
                return  // Not enough speech yet, keep waiting
            }

            // Silence after sufficient speech was detected
            if silenceStartTime == nil {
                silenceStartTime = Date()
                print("AudioSessionManager: Silence started after speech")
            } else if let startTime = silenceStartTime,
                      Date().timeIntervalSince(startTime) >= silenceDuration {
                // Silence duration exceeded - trigger callback
                print("AudioSessionManager: Silence threshold reached, triggering callback")
                DispatchQueue.main.async {
                    self.onSilenceDetected?()
                }
                silenceStartTime = nil
                speechStartTime = nil
                hasDetectedSpeech = false
            }
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    // MARK: - TTS Playback

    // Temporary file URL for TTS playback
    private var ttsPlaybackURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("tts_playback.mp3")
    }

    /// Play audio data (from ElevenLabs TTS)
    /// ElevenLabs returns MP3 format - we save to temp file for reliable playback
    func playAudio(data: Data) async throws {
        // Stop any current playback
        stopPlayback()

        // Debug: Check first few bytes
        if data.count >= 4 {
            let prefix = data.prefix(4)
            let hexString = prefix.map { String(format: "%02X", $0) }.joined()
            print("AudioSessionManager: Audio data \(data.count) bytes, prefix: \(hexString)")
        }

        // Save audio data to temp file (AVAudioPlayer works better with files for MP3)
        try data.write(to: ttsPlaybackURL)
        print("AudioSessionManager: Saved audio to \(ttsPlaybackURL.path)")

        try configureForPlayback()

        // Try to create player with file type hint
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: ttsPlaybackURL, fileTypeHint: AVFileType.mp3.rawValue)
        } catch {
            print("AudioSessionManager: Failed with mp3 hint, trying without: \(error)")
            // Fallback without hint
            audioPlayer = try AVAudioPlayer(contentsOf: ttsPlaybackURL)
        }

        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()

        print("AudioSessionManager: Player ready, duration: \(audioPlayer?.duration ?? 0)s")

        await MainActor.run {
            isPlaying = true
        }

        let success = audioPlayer?.play() ?? false
        print("AudioSessionManager: Play started: \(success)")
    }

    /// Play audio from URL (for cached TTS)
    func playAudio(url: URL) async throws {
        stopPlayback()

        try configureForPlayback()

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self

        await MainActor.run {
            isPlaying = true
        }

        audioPlayer?.play()
    }

    /// Stop audio playback
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil

        // Clean up temp TTS file
        try? FileManager.default.removeItem(at: ttsPlaybackURL)

        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }

    /// Wait for current playback to complete (with timeout)
    /// - Parameter timeout: Maximum wait time in seconds (default 30)
    func waitForPlaybackCompletion(timeout: TimeInterval = 30) async {
        print("AudioSessionManager: waitForPlaybackCompletion started, isPlaying=\(isPlaying)")
        guard isPlaying else {
            print("AudioSessionManager: Not playing, returning immediately")
            return
        }

        let startTime = Date()

        // Poll for completion using async sleep instead of Timer
        while isPlaying {
            // Check for timeout
            if Date().timeIntervalSince(startTime) >= timeout {
                print("AudioSessionManager: Playback wait timed out after \(timeout)s")
                stopPlayback()
                break
            }

            // Small delay before checking again
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        print("AudioSessionManager: waitForPlaybackCompletion finished, isPlaying=\(isPlaying)")
    }

    // MARK: - Cleanup

    func cleanup() {
        cancelRecording()
        stopPlayback()
        deactivateSession()
    }

    deinit {
        cleanup()
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioSessionManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
        }

        if !flag {
            print("AudioSessionManager: Recording did not finish successfully")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("AudioSessionManager: Encoding error: \(error?.localizedDescription ?? "unknown")")
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioSessionManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }

        // Deactivate session after playback
        deactivateSession()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("AudioSessionManager: Playback decode error: \(error?.localizedDescription ?? "unknown")")
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}
