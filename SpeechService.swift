import Foundation
import AVFoundation

// By making this an actor, it safely manages its own state and execution.
actor SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    // Methods in an actor are isolated and must be called asynchronously.
    func speak(text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    // To check a property on an actor from the outside, we need a method.
    func isSpeaking() -> Bool {
        return synthesizer.isSpeaking
    }
}
