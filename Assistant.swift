// Assistant.swift

import Foundation
import SwiftUI
import Combine
import CoreAudio
import FoundationModels

@MainActor
class Assistant: ObservableObject {
    @Published var conversation: [Message] = []
    @Published var displayedText: String = "Welcome! Select a microphone and press the blue circle."
    @Published var isListening: Bool = false
    @Published var status: String = "Idle"
    
    @Published var availableInputs: [AudioDevice] = []
    @Published var selectedInputID: AudioDeviceID?
    
    @Published var isSpeaking: Bool = false

    private let speechService = SpeechService()
    private let speechRecognitionService = SpeechRecognitionService()
    private let generativeAIService = GenerativeAIService()
    private let memoryService = MemoryService()
    
    private var speechServiceCancellable: AnyCancellable?
    private var transcriptionTask: Task<Void, Never>?

    init() {
        speechRecognitionService.requestPermission()
        discoverAudioDevices()
        Task { await memoryService.setup() }
        
        speechServiceCancellable = speechService.$isSpeaking.sink { [weak self] speaking in
            self?.isSpeaking = speaking
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

            if isSpeaking {
                speechService.stop()
                return
            }
            
            guard let deviceID = selectedInputID else {
                self.status = "Error: No microphone selected."
                return
            }
            
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
        // This check ensures we don't process an empty transcription if the user just taps the button.
        guard isListening else { return }
        
        isListening = false
        status = "Thinking..."
        speechRecognitionService.stopTranscribing()
        transcriptionTask?.cancel()
        
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            
            let userPrompt = displayedText
            guard !userPrompt.isEmpty else {
                status = "Idle"
                displayedText = "I didn't hear anything. Please try again."
                return
            }
            
            conversation.append(.init(role: "user", content: userPrompt))
            
            do {
                let memories = await memoryService.getMemoriesAsString()
                let fullResponseText = try await generativeAIService.generateResponse(prompt: userPrompt, history: conversation, memories: memories)
                
                self.displayedText = fullResponseText
                
                // ** THE FIX **
                // Clean the text before speaking it.
                let cleanedText = cleanTextForSpeech(fullResponseText)
                speechService.speak(text: cleanedText)
                
                conversation.append(.init(role: "assistant", content: fullResponseText))
                status = "Idle"
            } catch {
                displayedText = "Error generating response."
                status = "Error"
            }
        }
    }
    
    /// A helper function to remove unwanted characters before speech.
    private func cleanTextForSpeech(_ text: String) -> String {
        // This regular expression will keep letters, numbers, spaces, and basic punctuation.
        // It will remove everything else.
        let pattern = "[^a-zA-Z0-9 .,?!']"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
