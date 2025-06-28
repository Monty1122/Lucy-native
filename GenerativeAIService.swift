// GenerativeAIService.swift

import Foundation
import FoundationModels

@MainActor
class GenerativeAIService {

    // This is a stateless function that uses the non-streaming API.
    func generateResponse(prompt: String, history: [Message], memories: String) async throws -> String {
        
        let session = LanguageModelSession()
        
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
        
        let response = try await session.respond(to: fullPrompt)
        return response.content
    }
}
