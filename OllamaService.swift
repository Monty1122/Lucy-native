// OllamaService.swift

import Foundation

// Codable structs to match the JSON structure of the Ollama API responses.
struct OllamaTagsResponse: Codable {
    let models: [OllamaModelInfo]
}

struct OllamaModelInfo: Codable {
    let name: String
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [Message]
    let stream: Bool = false // We will use non-streaming for simplicity and stability
}

struct OllamaChatResponse: Codable {
    let message: Message
}

@MainActor
class OllamaService {
    private let baseURL = URL(string: "http://localhost:11434")!

    /// Fetches the list of available models from the Ollama server.
    func discoverModels() async -> [String] {
        let url = baseURL.appendingPathComponent("/api/tags")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            return response.models.map { $0.name }
        } catch {
            print("Error discovering Ollama models: \(error)")
            return ["Error: Ollama not reachable"]
        }
    }

    /// Generates a response from a specific Ollama model.
    func generateResponse(prompt: String, history: [Message], modelName: String) async throws -> String {
        let url = baseURL.appendingPathComponent("/api/chat")
        
        var fullHistory = history
        fullHistory.append(Message(role: "user", content: prompt))
        
        let requestBody = OllamaChatRequest(model: modelName, messages: fullHistory)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        
        return response.message.content
    }
}
