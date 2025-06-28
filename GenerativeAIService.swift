// GenerativeAIService.swift

import Foundation
import FoundationModels

@Generable
struct ModelResponse: Decodable, Sendable {
    let reply: String
}

@MainActor
class GenerativeAIService {

    private func createSession(with memories: String) -> LanguageModelSession {
        let instructions = Instructions {
            "You are a helpful assistant named Lucy. Your answers should be helpful and concise."
            "Remember these immutable facts:"
            " - \(memories)"
            "Provide your final response in the 'reply' field."
        }
        return LanguageModelSession(instructions: instructions)
    }

    func generateResponse(prompt: String, history: [Message], memories: String) -> LanguageModelSession.ResponseStream<ModelResponse> {
        
        let session = createSession(with: memories)
        
        let fullPrompt = history.map { "\($0.role): \($0.content)" }.joined(separator: "\n") + "\nuser: \(prompt)"
        
        let stream = session.streamResponse(
            generating: ModelResponse.self
        ) {
            fullPrompt
        }
        
        return stream
    }
}
