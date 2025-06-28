// AIBackend.swift

import Foundation

// This enum defines the different AI choices available in the app.
// Making it CaseIterable allows us to loop through all cases easily in the UI.
// Making it Identifiable is required for it to be used in a SwiftUI Picker.
enum AIBackend: String, CaseIterable, Identifiable {
    case apple = "Apple Foundation Model"
    case ollama = "Ollama"
    
    var id: Self { self }
}
