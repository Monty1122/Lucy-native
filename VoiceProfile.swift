// VoiceProfile.swift

import Foundation

// A simple, clean struct to represent a voice in our UI.
struct VoiceProfile: Identifiable, Hashable {
    let id: String // The voice identifier is a String.
    let name: String
    let quality: String // e.g., "Default", "Enhanced"
    let language: String
}
