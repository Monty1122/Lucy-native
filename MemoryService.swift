// MemoryService.swift

import Foundation

actor MemoryService {
    private var memories: [String] = []
    private let memoryFileURL: URL

    init() {
        do {
            let appSupportDir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let memoriesDir = appSupportDir.appendingPathComponent("Lucy")
            
            if !FileManager.default.fileExists(atPath: memoriesDir.path) {
                try FileManager.default.createDirectory(at: memoriesDir, withIntermediateDirectories: true)
            }
            
            self.memoryFileURL = memoriesDir.appendingPathComponent("memory.json")
        } catch {
            self.memoryFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("memory.json")
            print("Error finding Application Support directory: \(error). Using temporary location.")
        }
    }
    
    // ** THE FIX **
    // The setup() function must exist to be called.
    func setup() async {
        await loadMemoriesFromFile()
    }
    
    func remember(fact: String) {
        memories.append(fact)
        saveMemoriesToFile()
    }

    func forget(about subject: String) -> Bool {
        if let index = memories.firstIndex(where: { $0.lowercased().contains(subject.lowercased()) }) {
            memories.remove(at: index)
            saveMemoriesToFile()
            return true
        }
        return false
    }

    func getMemoriesAsString() -> String {
        return memories.joined(separator: "\n- ")
    }
    
    private func loadMemoriesFromFile() {
        guard FileManager.default.fileExists(atPath: memoryFileURL.path) else {
            self.memories = []
            return
        }
        do {
            let data = try Data(contentsOf: memoryFileURL)
            self.memories = try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("Failed to load memories from file: \(error)")
            self.memories = []
        }
    }
    
    private func saveMemoriesToFile() {
        do {
            let data = try JSONEncoder().encode(memories)
            try data.write(to: memoryFileURL, options: .atomic)
        } catch {
            print("Failed to save memories to file: \(error)")
        }
    }
}
