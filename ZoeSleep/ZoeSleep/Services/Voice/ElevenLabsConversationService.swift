//
//  ElevenLabsConversationService.swift
//  ZoeSleep
//
//  Manages real-time duplex conversation with ElevenLabs Conversational AI
//  Handles WebSocket connection, audio streaming, and transcript events
//

import Foundation
import AVFoundation
import Combine

// MARK: - Conversation Events

/// Events emitted during the conversation
enum ConversationEvent {
    case connected
    case disconnected(Error?)
    case userTranscript(text: String, isFinal: Bool)     // Real-time user speech
    case agentMessage(text: String)                       // What the agent says
    case agentAudioStart                                  // Agent starts speaking
    case agentAudioEnd                                    // Agent stops speaking
    case turnTaken(by: TurnTaker)                        // Who has the floor
    case error(String)
}

enum TurnTaker {
    case user
    case agent
}

// MARK: - Conversation Service

/// Service for managing ElevenLabs Conversational AI sessions
@MainActor
class ElevenLabsConversationService: NSObject, ObservableObject {
    static let shared = ElevenLabsConversationService()

    // MARK: - Published State

    @Published var isConnected = false
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var currentUserTranscript = ""
    @Published var currentAgentMessage = ""
    @Published var conversationHistory: [(role: String, text: String)] = []
    @Published var audioLevel: Float = 0.0

    // MARK: - Event Stream

    let eventSubject = PassthroughSubject<ConversationEvent, Never>()

    // MARK: - Private Properties

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?

    // Agent configuration
    private var agentId: String?
    private var systemPrompt: String?

    // Audio buffer for streaming
    private var audioBuffer = Data()
    private let audioBufferQueue = DispatchQueue(label: "com.zoesleep.audioBuffer")

    // MARK: - Initialization

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: .main)
    }

    // MARK: - Public API

    /// Start a conversation session with the ElevenLabs agent
    /// - Parameters:
    ///   - agentId: The ElevenLabs agent ID
    ///   - systemPrompt: Optional system prompt override for the conversation
    func startConversation(agentId: String, systemPrompt: String? = nil) async throws {
        self.agentId = agentId
        self.systemPrompt = systemPrompt

        // Get signed URL from our backend
        let signedUrl = try await getSignedUrl(agentId: agentId)

        // Connect WebSocket
        try await connectWebSocket(url: signedUrl)

        // Setup audio
        try setupAudioEngine()

        isConnected = true
        eventSubject.send(.connected)

        // Start receiving messages
        startReceiving()
    }

    /// End the current conversation
    func endConversation() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil

        stopAudioEngine()

        isConnected = false
        isListening = false
        isSpeaking = false

        eventSubject.send(.disconnected(nil))
    }

    /// Start listening (unmute microphone)
    func startListening() {
        guard isConnected else { return }

        isListening = true
        eventSubject.send(.turnTaken(by: .user))

        // Start streaming audio to WebSocket
        startAudioCapture()
    }

    /// Stop listening (mute microphone)
    func stopListening() {
        isListening = false
        stopAudioCapture()
    }

    /// Interrupt the agent (barge-in)
    func interruptAgent() {
        guard isConnected, isSpeaking else { return }

        // Send interrupt message
        let interrupt: [String: Any] = ["type": "interrupt"]
        sendJSON(interrupt)

        isSpeaking = false
    }

    // MARK: - Backend Integration

    /// Get a signed URL from our Convex backend
    private func getSignedUrl(agentId: String) async throws -> URL {
        // Call Convex to get signed URL
        // The backend will call ElevenLabs API with our API key
        let response = try await ConvexService.shared.getConversationSignedUrl(agentId: agentId)

        guard let url = URL(string: response.signedUrl) else {
            throw ConversationError.invalidSignedUrl
        }

        return url
    }

    // MARK: - WebSocket Management

    private func connectWebSocket(url: URL) async throws {
        webSocket = urlSession.webSocketTask(with: url)
        webSocket?.resume()

        // Send initial configuration if we have a system prompt override
        if let systemPrompt = systemPrompt {
            let config: [String: Any] = [
                "type": "conversation_initiation_client_data",
                "conversation_config_override": [
                    "agent": [
                        "prompt": [
                            "prompt": systemPrompt
                        ]
                    ]
                ]
            ]
            sendJSON(config)
        }
    }

    private func startReceiving() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    // Continue receiving
                    self?.startReceiving()

                case .failure(let error):
                    print("ElevenLabsConversation: WebSocket error: \(error)")
                    self?.eventSubject.send(.error(error.localizedDescription))
                    self?.endConversation()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleTextMessage(text)

        case .data(let data):
            // Audio data from agent
            handleAudioData(data)

        @unknown default:
            break
        }
    }

    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "user_transcript":
            // Real-time user speech transcript
            if let transcript = json["user_transcript"] as? String {
                let isFinal = (json["is_final"] as? Bool) ?? false
                currentUserTranscript = transcript
                eventSubject.send(.userTranscript(text: transcript, isFinal: isFinal))

                if isFinal {
                    conversationHistory.append((role: "user", text: transcript))
                }
            }

        case "agent_response":
            // Agent's text response
            if let response = json["agent_response"] as? String {
                currentAgentMessage = response
                eventSubject.send(.agentMessage(text: response))
                conversationHistory.append((role: "agent", text: response))
            }

        case "audio":
            // Agent audio metadata (actual audio comes as binary)
            isSpeaking = true
            eventSubject.send(.agentAudioStart)
            eventSubject.send(.turnTaken(by: .agent))

        case "audio_end":
            isSpeaking = false
            eventSubject.send(.agentAudioEnd)

        case "interruption":
            // User interrupted the agent
            isSpeaking = false

        case "ping":
            // Respond to keep-alive
            sendJSON(["type": "pong"])

        case "error":
            if let errorMsg = json["message"] as? String {
                eventSubject.send(.error(errorMsg))
            }

        default:
            print("ElevenLabsConversation: Unknown message type: \(type)")
        }
    }

    private func handleAudioData(_ data: Data) {
        // Queue audio for playback
        audioBufferQueue.async { [weak self] in
            self?.audioBuffer.append(data)
            self?.playBufferedAudio()
        }
    }

    private func sendJSON(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return
        }

        webSocket?.send(.string(string)) { error in
            if let error = error {
                print("ElevenLabsConversation: Send error: \(error)")
            }
        }
    }

    // MARK: - Audio Engine

    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        audioPlayer = AVAudioPlayerNode()

        guard let engine = audioEngine, let player = audioPlayer else {
            throw ConversationError.audioSetupFailed
        }

        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        // Setup for playback (agent audio)
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: audioFormat)

        // Setup for capture (user audio)
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install tap for capturing microphone audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        try engine.start()
    }

    private func stopAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioPlayer?.stop()
        audioEngine?.stop()
        audioEngine = nil
        audioPlayer = nil
    }

    private func startAudioCapture() {
        // Audio capture is always running via the tap
        // We just control whether we send it to the WebSocket
    }

    private func stopAudioCapture() {
        // Stop sending audio to WebSocket
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isListening, isConnected else { return }

        // Convert to the format expected by ElevenLabs (16kHz, 16-bit PCM)
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Calculate audio level for visualization
        var sum: Float = 0
        for i in 0..<frameCount {
            sum += abs(channelData[i])
        }
        let avgLevel = sum / Float(frameCount)

        Task { @MainActor in
            self.audioLevel = min(1.0, avgLevel * 5) // Amplify for visualization
        }

        // Convert float samples to 16-bit PCM
        var pcmData = Data(capacity: frameCount * 2)
        for i in 0..<frameCount {
            let sample = Int16(max(-32768, min(32767, channelData[i] * 32767)))
            withUnsafeBytes(of: sample.littleEndian) { pcmData.append(contentsOf: $0) }
        }

        // Send audio chunk to WebSocket
        let audioMessage: [String: Any] = [
            "type": "audio",
            "audio": pcmData.base64EncodedString()
        ]
        sendJSON(audioMessage)
    }

    private func playBufferedAudio() {
        guard audioBuffer.count >= 320 else { return } // Need at least some samples

        // Extract chunk from buffer
        let chunkSize = min(audioBuffer.count, 4096)
        let chunk = audioBuffer.prefix(chunkSize)
        audioBuffer.removeFirst(chunkSize)

        // Schedule playback on main queue
        DispatchQueue.main.async { [weak self] in
            self?.playAudioChunk(Data(chunk))
        }
    }

    private func playAudioChunk(_ data: Data) {
        guard let player = audioPlayer,
              let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1) else {
            return
        }

        // ElevenLabs sends 16-bit PCM at 16kHz
        let sampleCount = data.count / 2

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)

        // Convert 16-bit PCM to float
        data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else { return }
            let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)
            guard let floatChannelData = buffer.floatChannelData?[0] else { return }

            for i in 0..<sampleCount {
                floatChannelData[i] = Float(int16Pointer[i]) / 32768.0
            }
        }

        // Schedule and play
        player.scheduleBuffer(buffer, completionHandler: nil)

        if !player.isPlaying {
            player.play()
        }
    }
}

// MARK: - Errors

enum ConversationError: Error, LocalizedError {
    case invalidSignedUrl
    case audioSetupFailed
    case notConnected
    case noAgentConfigured

    var errorDescription: String? {
        switch self {
        case .invalidSignedUrl:
            return "Failed to get conversation URL"
        case .audioSetupFailed:
            return "Failed to setup audio"
        case .notConnected:
            return "Not connected to conversation"
        case .noAgentConfigured:
            return "No agent configured"
        }
    }
}
