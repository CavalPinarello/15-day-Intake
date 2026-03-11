//
//  HumeVoiceService.swift
//  ZoeSleep
//
//  Wraps Hume AI's Swift SDK VoiceProvider to deliver empathic voice
//  conversations for the 10-day questionnaire intake.
//
//  Replaces: ElevenLabsConversationService + AudioSessionManager (for voice chat)
//

import Foundation
import Combine

// MARK: - Hume Voice Event

/// Events emitted during a Hume EVI conversation
enum HumeVoiceEvent {
    case connected(chatId: String)
    case disconnected(error: Error?)
    case userTranscript(text: String, isFinal: Bool)
    case assistantMessage(text: String)
    case assistantAudioStart
    case assistantAudioEnd
    case emotionUpdate(emotions: [String: Double], arousal: Double, valence: Double)
    case toolCall(name: String, parameters: String, toolCallId: String)
    case error(String)
}

// MARK: - Hume Voice State

enum HumeVoiceState: Equatable {
    case idle
    case connecting
    case connected
    case listening       // User is speaking
    case thinking        // Processing user input
    case speaking        // Assistant is responding
    case disconnected
}

// MARK: - Hume Voice Service

/// Service managing Hume EVI voice conversations for questionnaire intake.
/// Handles WebSocket connection, audio I/O, emotion tracking, and tool calls.
@MainActor
class HumeVoiceService: ObservableObject {

    // MARK: - Singleton

    static let shared = HumeVoiceService()

    // MARK: - Published State

    @Published var state: HumeVoiceState = .idle
    @Published var currentUserTranscript: String = ""
    @Published var currentAssistantMessage: String = ""
    @Published var isConnected: Bool = false
    @Published var audioLevel: Float = 0.0

    // Emotion state (updated in real-time from EVI)
    @Published var currentEmotions: [String: Double] = [:]
    @Published var currentArousal: Double = 0.5
    @Published var currentValence: Double = 0.0

    // MARK: - Event Publisher

    let eventPublisher = PassthroughSubject<HumeVoiceEvent, Never>()

    // MARK: - Conversation History

    struct ConversationTurn: Identifiable {
        let id = UUID()
        let role: String  // "user" or "assistant"
        let text: String
        let emotions: [String: Double]?
        let timestamp: Date
    }

    @Published var conversationHistory: [ConversationTurn] = []

    // MARK: - Private State

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var chatId: String?
    private var chatGroupId: String?
    private var isReceivingAudio: Bool = false

    // Audio engine for microphone capture
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    // Audio playback for EVI responses
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioOutputBuffer: Data = Data()
    private let audioOutputQueue = DispatchQueue(label: "com.zoesleep.hume.audioOutput")
    private let minPlaybackBytes = 4800  // Buffer ~50ms at 48kHz before playing

    // Configuration
    private var currentSystemPrompt: String?
    private var currentTools: [[String: Any]] = []

    // MARK: - Configuration

    /// Hume API key - fetched from Convex environment
    private var apiKey: String?

    /// EVI config ID - created in Hume dashboard or via API
    private var configId: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Connection

    /// Connect to Hume EVI with a system prompt and optional tools
    func connect(
        systemPrompt: String,
        tools: [[String: Any]] = [],
        configId: String? = nil
    ) async throws {
        guard state == .idle || state == .disconnected else {
            print("[HumeVoice] Already connected or connecting")
            return
        }

        state = .connecting
        currentSystemPrompt = systemPrompt
        currentTools = tools

        // Get API key from Convex if not cached
        if apiKey == nil {
            apiKey = try await fetchHumeApiKey()
        }

        guard let key = apiKey else {
            throw HumeVoiceError.noApiKey
        }

        // Build WebSocket URL
        var urlComponents = URLComponents(string: "wss://api.hume.ai/v0/evi/chat")!
        var queryItems: [URLQueryItem] = []

        // Handle token format: "apikey:xxx" for direct API key, otherwise access_token
        if key.hasPrefix("apikey:") {
            let rawKey = String(key.dropFirst("apikey:".count))
            queryItems.append(URLQueryItem(name: "api_key", value: rawKey))
        } else {
            queryItems.append(URLQueryItem(name: "access_token", value: key))
        }

        if let configId = configId ?? self.configId {
            queryItems.append(URLQueryItem(name: "config_id", value: configId))
        }
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw HumeVoiceError.invalidURL
        }

        // Create WebSocket connection
        let session = URLSession(configuration: .default)
        urlSession = session
        let ws = session.webSocketTask(with: url)
        webSocket = ws
        ws.resume()

        // Start receiving messages
        Task { await receiveMessages() }

        // Send session settings with system prompt and tools
        try await sendSessionSettings(systemPrompt: systemPrompt, tools: tools)

        // Start audio capture
        try startAudioCapture()

        state = .connected
        isConnected = true

        print("[HumeVoice] Connected to EVI")
    }

    /// Disconnect from Hume EVI
    func disconnect() {
        stopAudioCapture()

        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession = nil

        state = .disconnected
        isConnected = false
        chatId = nil
        chatGroupId = nil
        currentUserTranscript = ""
        currentAssistantMessage = ""

        eventPublisher.send(.disconnected(error: nil))
        print("[HumeVoice] Disconnected")
    }

    // MARK: - Send Messages

    /// Send text as if the user spoke it (for typed fallback)
    func sendUserInput(_ text: String) async throws {
        let message: [String: Any] = [
            "type": "user_input",
            "text": text
        ]
        try await sendJSON(message)
    }

    /// Pause assistant responses (keeps transcription active)
    func pauseAssistant() async throws {
        try await sendJSON(["type": "pause_assistant_message"])
    }

    /// Resume assistant responses
    func resumeAssistant() async throws {
        try await sendJSON(["type": "resume_assistant_message"])
    }

    /// Send tool response back to EVI
    func sendToolResponse(toolCallId: String, content: String) async throws {
        let message: [String: Any] = [
            "type": "tool_response",
            "tool_call_id": toolCallId,
            "content": content
        ]
        try await sendJSON(message)
    }

    /// Send tool error back to EVI
    func sendToolError(toolCallId: String, error: String) async throws {
        let message: [String: Any] = [
            "type": "tool_error",
            "tool_call_id": toolCallId,
            "error": error,
            "content": "Tool execution failed: \(error)"
        ]
        try await sendJSON(message)
    }

    // MARK: - Session Settings

    /// Update system prompt and tools mid-conversation
    func updateSessionSettings(
        systemPrompt: String? = nil,
        tools: [[String: Any]]? = nil,
        variables: [String: String]? = nil
    ) async throws {
        var settings: [String: Any] = ["type": "session_settings"]

        if let prompt = systemPrompt {
            settings["system_prompt"] = prompt
        }
        if let tools = tools {
            settings["tools"] = tools
        }
        if let vars = variables {
            settings["variables"] = vars
        }

        try await sendJSON(settings)
    }

    // MARK: - Private: WebSocket Communication

    private func sendSessionSettings(
        systemPrompt: String,
        tools: [[String: Any]]
    ) async throws {
        var settings: [String: Any] = [
            "type": "session_settings",
            "system_prompt": systemPrompt
        ]

        if !tools.isEmpty {
            settings["tools"] = tools
        }

        // Configure audio input format: Linear16 PCM, 16kHz, mono
        settings["audio"] = [
            "input": [
                "encoding": "linear16",
                "sample_rate": 16000,
                "channels": 1
            ]
        ]

        try await sendJSON(settings)
    }

    private func sendJSON(_ dict: [String: Any]) async throws {
        guard let ws = webSocket else {
            throw HumeVoiceError.notConnected
        }

        let data = try JSONSerialization.data(withJSONObject: dict)
        let string = String(data: data, encoding: .utf8) ?? ""
        try await ws.send(.string(string))
    }

    private func sendAudioData(_ base64Audio: String) async {
        let message: [String: Any] = [
            "type": "audio_input",
            "data": base64Audio
        ]

        do {
            try await sendJSON(message)
        } catch {
            print("[HumeVoice] Error sending audio: \(error)")
        }
    }

    // MARK: - Private: Receive Messages

    private func receiveMessages() async {
        guard let ws = webSocket else { return }

        do {
            let message = try await ws.receive()

            switch message {
            case .string(let text):
                await handleTextMessage(text)
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) {
                    await handleTextMessage(text)
                }
            @unknown default:
                break
            }

            // Continue receiving
            if isConnected {
                await receiveMessages()
            }
        } catch {
            if isConnected {
                print("[HumeVoice] WebSocket receive error: \(error)")
                await MainActor.run {
                    self.state = .disconnected
                    self.isConnected = false
                    self.eventPublisher.send(.error(error.localizedDescription))
                }
            }
        }
    }

    private func handleTextMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "chat_metadata":
            chatId = json["chat_id"] as? String
            chatGroupId = json["chat_group_id"] as? String
            if let chatId = chatId {
                eventPublisher.send(.connected(chatId: chatId))
            }

        case "user_message":
            if let message = json["message"] as? [String: Any],
               let content = message["content"] as? String {

                currentUserTranscript = content
                state = .listening

                // Extract emotions from user message
                if let models = json["models"] as? [String: Any],
                   let prosody = models["prosody"] as? [String: Any],
                   let scores = prosody["scores"] as? [String: Double] {
                    processEmotions(scores)
                }

                eventPublisher.send(.userTranscript(text: content, isFinal: true))

                // Add to history
                conversationHistory.append(ConversationTurn(
                    role: "user",
                    text: content,
                    emotions: currentEmotions,
                    timestamp: Date()
                ))
            }

        case "assistant_message":
            if let message = json["message"] as? [String: Any],
               let content = message["content"] as? String {

                currentAssistantMessage = content
                eventPublisher.send(.assistantMessage(text: content))

                conversationHistory.append(ConversationTurn(
                    role: "assistant",
                    text: content,
                    emotions: nil,
                    timestamp: Date()
                ))
            }

        case "audio_output":
            if !isReceivingAudio {
                isReceivingAudio = true
                state = .speaking
                eventPublisher.send(.assistantAudioStart)
            }
            // Decode and play audio chunk
            if let audioData = json["data"] as? String,
               let decoded = Data(base64Encoded: audioData) {
                playAudioChunk(decoded)
            }

        case "assistant_end":
            isReceivingAudio = false
            // Flush remaining audio buffer
            flushAudioBuffer()
            state = .connected
            eventPublisher.send(.assistantAudioEnd)

        case "user_interruption":
            isReceivingAudio = false
            stopPlayback()
            state = .listening

        case "tool_call":
            if let name = json["name"] as? String,
               let parameters = json["parameters"] as? String,
               let toolCallId = json["tool_call_id"] as? String {
                state = .thinking
                eventPublisher.send(.toolCall(
                    name: name,
                    parameters: parameters,
                    toolCallId: toolCallId
                ))
            }

        case "error":
            let errorMsg = json["message"] as? String ?? "Unknown EVI error"
            eventPublisher.send(.error(errorMsg))
            print("[HumeVoice] EVI error: \(errorMsg)")

        default:
            break
        }
    }

    // MARK: - Private: Emotion Processing

    private func processEmotions(_ scores: [String: Double]) {
        // Map Hume's 48 emotions to our sleep-relevant subset
        let mapping: [String: String] = [
            "Anxiety": "anxiety", "Fear": "anxiety", "Nervousness": "anxiety",
            "Calmness": "calm", "Serenity": "calm",
            "Contentment": "contentment", "Satisfaction": "contentment",
            "Frustration": "frustration", "Annoyance": "frustration",
            "Sadness": "sadness", "Disappointment": "sadness",
            "Anger": "irritability", "Irritation": "irritability",
            "Tiredness": "fatigue", "Boredom": "fatigue",
            "Confusion": "confusion", "Doubt": "confusion",
            "Distress": "hopelessness", "Despair": "hopelessness",
            "Stress": "stress", "Tension": "stress"
        ]

        var sleepEmotions: [String: Double] = [:]
        for (humeName, score) in scores {
            if let mapped = mapping[humeName] {
                sleepEmotions[mapped] = max(sleepEmotions[mapped] ?? 0, score)
            }
        }

        currentEmotions = sleepEmotions

        // Calculate arousal and valence
        let arousalNames = ["anxiety", "stress", "irritability", "frustration"]
        let arousalScores = arousalNames.compactMap { sleepEmotions[$0] }.filter { $0 > 0 }
        currentArousal = arousalScores.isEmpty ? 0.5 : arousalScores.reduce(0, +) / Double(arousalScores.count)

        let positiveNames = ["calm", "contentment"]
        let negativeNames = ["anxiety", "sadness", "frustration", "hopelessness"]
        let posScore = positiveNames.compactMap { sleepEmotions[$0] }.reduce(0, +)
        let negScore = negativeNames.compactMap { sleepEmotions[$0] }.reduce(0, +)
        currentValence = max(-1, min(1, posScore - negScore))

        eventPublisher.send(.emotionUpdate(
            emotions: sleepEmotions,
            arousal: currentArousal,
            valence: currentValence
        ))
    }

    // MARK: - Private: Audio Capture

    private func startAudioCapture() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setPreferredIOBufferDuration(0.02) // 20ms buffers
        try audioSession.setActive(true)

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        inputNode = engine.inputNode

        // Enable voice processing for echo cancellation
        if #available(iOS 17.0, *) {
            try inputNode?.setVoiceProcessingEnabled(true)
        }

        let inputFormat = inputNode!.outputFormat(forBus: 0)

        // Target format: 16kHz, mono, 16-bit PCM
        let targetSampleRate: Double = 16000
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        )!

        // Install tap on input node
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(inputFormat.sampleRate * 0.02) // 20ms

        inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Convert to 16kHz mono Int16
            let convertedData = self.convertAudioBuffer(buffer, from: inputFormat, to: targetFormat)
            if let data = convertedData {
                let base64 = data.base64EncodedString()

                // Calculate audio level for UI
                let level = self.calculateAudioLevel(buffer)

                Task { @MainActor in
                    self.audioLevel = level
                    await self.sendAudioData(base64)
                }
            }
        }

        try engine.start()

        // Set up audio player for EVI responses
        setupAudioPlayer()

        print("[HumeVoice] Audio capture and playback started")
    }

    private func stopAudioCapture() {
        inputNode?.removeTap(onBus: 0)
        audioPlayerNode?.stop()
        audioPlayerNode = nil
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("[HumeVoice] Audio capture stopped")
    }

    // MARK: - Private: Audio Playback

    private func setupAudioPlayer() {
        guard let engine = audioEngine else { return }

        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        // EVI outputs 48kHz mono 16-bit PCM (WAV)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 48000,
            channels: 1,
            interleaved: true
        )!

        engine.connect(playerNode, to: engine.mainMixerNode, format: outputFormat)
        playerNode.play()
        audioPlayerNode = playerNode
    }

    private func playAudioChunk(_ wavData: Data) {
        audioOutputQueue.async { [weak self] in
            guard let self = self else { return }

            // Strip WAV header if present (44 bytes)
            let pcmData: Data
            if wavData.count > 44 && self.isWAVHeader(wavData) {
                pcmData = wavData.subdata(in: 44..<wavData.count)
            } else {
                pcmData = wavData
            }

            self.audioOutputBuffer.append(pcmData)

            // Play when we have enough buffered
            if self.audioOutputBuffer.count >= self.minPlaybackBytes {
                let chunk = self.audioOutputBuffer
                self.audioOutputBuffer = Data()
                self.scheduleAudioBuffer(chunk)
            }
        }
    }

    private func flushAudioBuffer() {
        audioOutputQueue.async { [weak self] in
            guard let self = self, !self.audioOutputBuffer.isEmpty else { return }
            let remaining = self.audioOutputBuffer
            self.audioOutputBuffer = Data()
            self.scheduleAudioBuffer(remaining)
        }
    }

    private func stopPlayback() {
        audioOutputQueue.async { [weak self] in
            self?.audioOutputBuffer = Data()
            Task { @MainActor in
                self?.audioPlayerNode?.stop()
                self?.audioPlayerNode?.play() // Reset for next turn
            }
        }
    }

    private func scheduleAudioBuffer(_ pcmData: Data) {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 48000,
            channels: 1,
            interleaved: true
        )!

        let frameCount = AVAudioFrameCount(pcmData.count / MemoryLayout<Int16>.size)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount

        // Copy PCM data into the buffer
        pcmData.withUnsafeBytes { rawBytes in
            guard let src = rawBytes.baseAddress else { return }
            if let dst = buffer.int16ChannelData?[0] {
                memcpy(dst, src, pcmData.count)
            }
        }

        Task { @MainActor in
            self.audioPlayerNode?.scheduleBuffer(buffer)
        }
    }

    private func isWAVHeader(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        // Check for "RIFF" magic bytes
        return data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46
    }

    private func convertAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        from sourceFormat: AVAudioFormat,
        to targetFormat: AVAudioFormat
    ) -> Data? {
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return nil
        }

        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * targetFormat.sampleRate / sourceFormat.sampleRate
        )

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
            return nil
        }

        var error: NSError?
        var inputConsumed = false

        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error = error {
            print("[HumeVoice] Audio conversion error: \(error)")
            return nil
        }

        // Extract raw PCM bytes
        guard let int16Data = convertedBuffer.int16ChannelData else { return nil }
        let byteCount = Int(convertedBuffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: int16Data[0], count: byteCount)
    }

    private func calculateAudioLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let average = sum / Float(frameLength)
        // Amplify for visualization
        return min(1.0, average * 5.0)
    }

    // MARK: - Private: API Key

    private func fetchHumeApiKey() async throws -> String {
        do {
            let token = try await ConvexService.shared.getEVIAccessToken()
            return token
        } catch {
            print("[HumeVoice] Token error: \(error)")
            throw HumeVoiceError.noApiKey
        }
    }
}

// MARK: - Errors

enum HumeVoiceError: LocalizedError {
    case noApiKey
    case invalidURL
    case notConnected
    case audioSetupFailed

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "Hume API key not configured"
        case .invalidURL: return "Invalid EVI WebSocket URL"
        case .notConnected: return "Not connected to EVI"
        case .audioSetupFailed: return "Failed to set up audio capture"
        }
    }
}

// MARK: - AVFoundation Import

import AVFoundation
