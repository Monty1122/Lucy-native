// SpeechService.swift

import Foundation
import AVFoundation
import Combine

// This class is now an NSObject to be a delegate, and an ObservableObject to publish its state.
class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        // Set this class as the delegate to receive speech events.
        synthesizer.delegate = self
    }

    func speak(text: String) {
        // Don't speak if the text is empty.
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSpeaking = true
        let utterance = AVSpeechUtterance(string: text)
        
        // ** THE FIX for High-Quality Voice **
        // Find and use an "enhanced" quality voice if the user has one downloaded.
        let enhancedVoice = AVSpeechSynthesisVoice.speechVoices().first { voice in
            voice.language == "en-US" && voice.quality == .enhanced
        }
        utterance.voice = enhancedVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        
        // Adjust the rate for a more natural pace.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    // MARK: - AVSpeechSynthesizerDelegate Methods
    
    // This delegate method is called automatically when speech finishes naturally.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    
    // This delegate method is called automatically if speech is cancelled.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
