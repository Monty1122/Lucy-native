// GenerativeAIService.swift

import Foundation
import FoundationModels

@MainActor
class GenerativeAIService {

    // This is a stateless function that uses the most basic, non-streaming API.
    func generateResponse(prompt: String, history: [Message], memories: String) async throws -> String {
        
        // ** THE FIX **
        // Create a "vanilla" session with no instructions to avoid the sandbox error.
        let session = LanguageModelSession()
        
        // 1. Build the ENTIRE context into a single string.
        let fullPrompt = """
        You are a helpful assistant named Lucy.
        Remember these immutable facts:
        - \(memories)
        
        ---
        Conversation History:
        \(history.map { "\($0.role): \($0.content)" }.joined(separator: "\n"))
        ---
        
        New Request:
        user: \(prompt)
        assistant:
        """
        
        // 2. Call the session with the complete prompt.
        let response = try await session.respond(to: fullPrompt)
        
        // 3. Return the response content directly.
        return response.content
    }
}
