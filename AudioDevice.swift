// AudioDevice.swift

import Foundation
import CoreAudio // Import CoreAudio for AudioDeviceID

// Use the correct UInt32 type alias for the ID.
struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
}

