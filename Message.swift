// Message.swift

import Foundation

// A simple, top-level struct to represent a message in the conversation.
struct Message: Codable, Hashable {
    let role: String
    let content: String
}
