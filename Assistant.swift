// Assistant.swift

import Foundation
import SwiftUI
import Combine
import CoreAudio
import FoundationModels
import AVFoundation

@MainActor
class Assistant: ObservableObject {
    @Published var conversation: [Message] = []
    @Published var displayedText: String = "Welcome! Select a microphone and press the blue circle."
    @Published var isListening: Bool = false
    @Published var status: String = "Idle"
    @Published var isSpeaking: Bool = false
    
    @Published var availableInputs: [AudioDevice] = []
    @Published var selectedInputID: AudioDeviceID?
    
    @Published var selectedBackend: AIBackend = .apple
    @Published var selectedOllamaModel: String?
    @Published var availableOllamaModels: [String] = [] {
        didSet {
            if !availableOllamaModels.contains(where: { $0 == selectedOllamaModel }) {
                selectedOllamaModel = availableOllamaModels.first
            }
        }
    }
    
    @Published var thinkingTimeElapsed: TimeInterval = 0
    private var thinkingTimer: Timer?

    @Published var availableVoices: [VoiceProfile] = []
    @Published var selectedVoiceID: String?
    
    private let speechService = SpeechService()
    private let speechRecognitionService = SpeechRecognitionService()
    private let generativeAIService = GenerativeAIService()
    private let ollamaService = OllamaService()
    private let memoryService = MemoryService()
    
    private var speechServiceCancellable: AnyCancellable?
    private var transcriptionTask: Task<Void, Never>?

    init() {
        speechRecognitionService.requestPermission()
        discoverAudioDevices()
        discoverVoices()
        Task { await memoryService.setup() }
        
        speechServiceCancellable = speechService.$isSpeaking.sink { [weak self] speaking in
            self?.isSpeaking = speaking
        }
        
        loadOllamaModels()
    }
    
    func discoverVoices() {
        self.availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-") }
            .map { voice in
                let quality: String
                switch voice.quality {
                case .enhanced: quality = "Enhanced"
                case .premium: quality = "Premium"
                default: quality = "Default"
                }
                return VoiceProfile(id: voice.identifier, name: "\(voice.name) (\(quality))", quality: quality, language: voice.language)
            }
        self.selectedVoiceID = self.availableVoices.first(where: { $0.quality != "Default" })?.id ?? self.availableVoices.first?.id
    }
    
    func loadOllamaModels() {
        Task {
            let models = await ollamaService.discoverModels()
            self.availableOllamaModels = models
        }
    }
    
    func discoverAudioDevices() {
        var devices: [AudioDevice] = []
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var propertySize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize) == noErr else { return }
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs) == noErr else { return }
        for deviceID in deviceIDs {
            var inputStreamsSize: UInt32 = 0
            var inputStreamsAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeInput, mElement: 0)
            guard AudioObjectGetPropertyDataSize(deviceID, &inputStreamsAddress, 0, nil, &inputStreamsSize) == noErr, inputStreamsSize > 0 else { continue }
            var name: CFString = "" as CFString
            var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name) == noErr else { continue }
            devices.append(AudioDevice(id: deviceID, name: name as String))
        }
        var defaultAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var defaultID: AudioDeviceID = 0
        var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, &defaultSize, &defaultID) == noErr {
            self.selectedInputID = defaultID
        }
        self.availableInputs = devices
    }

    func startListening() {
        Task {
            guard !isListening else { return }
            if isSpeaking { speechService.stop(); return }
            guard let deviceID = selectedInputID else { self.status = "Error: No microphone selected."; return }
            isListening = true
            status = "Listening..."
            displayedText = ""
            transcriptionTask = Task {
                do {
                    for try await transcription in speechRecognitionService.startTranscribing(deviceID: deviceID) {
                        displayedText = transcription
                    }
                } catch {
                    displayedText = "Error during transcription: \(error.localizedDescription)"
                    isListening = false
                }
            }
        }
    }
    
    func stopListeningAndProcess() {
        guard isListening else { return }
        isListening = false
        status = "Thinking..."
        startThinkingTimer()
        speechRecognitionService.stopTranscribing()
        transcriptionTask?.cancel()
        
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            
            let userPrompt = self.displayedText
            guard !userPrompt.isEmpty else {
                self.status = "Idle"
                self.displayedText = "I didn't hear anything. Please try again."
                stopThinkingTimer()
                return
            }
            
            if userPrompt.lowercased().starts(with: "remember") {
                let fact = String(userPrompt.dropFirst("remember".count).trimmingCharacters(in: .whitespacesAndNewlines))
                await self.memoryService.remember(fact: fact)
                let confirmation = "Okay, I'll remember that."
                self.displayedText = confirmation
                self.speechService.speak(text: confirmation, voiceIdentifier: self.selectedVoiceID)
                self.status = "Idle"
                stopThinkingTimer()
                return
            } else if userPrompt.lowercased().starts(with: "forget") {
                let subject = String(userPrompt.dropFirst("forget".count).trimmingCharacters(in: .whitespacesAndNewlines))
                let success = await self.memoryService.forget(about: subject)
                let confirmation = success ? "Okay, I've forgotten that." : "I don't have a memory about that."
                self.displayedText = confirmation
                self.speechService.speak(text: confirmation, voiceIdentifier: self.selectedVoiceID)
                self.status = "Idle"
                stopThinkingTimer()
                return
            }
            
            self.conversation.append(.init(role: "user", content: userPrompt))
            
            do {
                let memories = await self.memoryService.getMemoriesAsString()
                var fullResponseText = ""
                let recentHistory = Array(self.conversation.suffix(6))
                
                switch self.selectedBackend {
                case .apple:
                    fullResponseText = try await self.generativeAIService.generateResponse(prompt: userPrompt, history: recentHistory, memories: memories)
                case .ollama:
                    guard let modelName = self.selectedOllamaModel else { throw NSError(domain: "OllamaError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Ollama model selected."]) }
                    fullResponseText = try await self.ollamaService.generateResponse(prompt: userPrompt, history: recentHistory, modelName: modelName)
                }
                
                stopThinkingTimer()
                self.displayedText = fullResponseText
                
                let cleanedText = self.cleanTextForSpeech(fullResponseText)
                
                // ** THE FIX **
                // This call now correctly passes the selected voice ID.
                self.speechService.speak(text: cleanedText, voiceIdentifier: self.selectedVoiceID)
                
                self.conversation.append(.init(role: "assistant", content: fullResponseText))
                self.status = "Idle"
                
            } catch {
                stopThinkingTimer()
                self.displayedText = "Error generating response."
                self.status = "Error"
            }
        }
    }
    
    private func startThinkingTimer() {
        thinkingTimeElapsed = 0
        thinkingTimer?.invalidate()
        thinkingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.thinkingTimeElapsed += 0.1
        }
    }

    private func stopThinkingTimer() {
        thinkingTimer?.invalidate()
        thinkingTimer = nil
    }
    
    private func cleanTextForSpeech(_ text: String) -> String {
        let pattern = "[^a-zA-Z0-9 .,?!']"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
