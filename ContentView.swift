import SwiftUI
import CoreAudio
import Combine

struct ContentView: View {
    @StateObject private var assistant = Assistant()
    
    // This state variable is essential for the NSEvent monitor to work correctly.
    @State private var isSpaceBarPressed = false

    var body: some View {
        VStack {
            // --- Picker Section ---
            HStack {
                Picker("Backend:", selection: $assistant.selectedBackend) {
                    ForEach(AIBackend.allCases) { backend in Text(backend.rawValue).tag(backend) }
                }
                if assistant.selectedBackend == .ollama {
                    Picker("Model:", selection: $assistant.selectedOllamaModel) {
                        ForEach(assistant.availableOllamaModels, id: \.self) { modelName in Text(modelName).tag(modelName as String?) }
                    }
                }
            }.padding(.horizontal)
            
            Picker("Microphone:", selection: $assistant.selectedInputID) {
                ForEach(assistant.availableInputs, id: \.self) { device in Text(device.name).tag(device.id as AudioDeviceID?) }
            }.padding(.horizontal)

            // ** THE NEW UI **
            // Add the Picker for voice selection.
            Picker("Voice:", selection: $assistant.selectedVoiceID) {
                ForEach(assistant.availableVoices) { voice in
                    Text(voice.name).tag(voice.id as String?)
                }
            }
            .padding(.horizontal)

            // --- The rest of the UI remains exactly the same ---
            ScrollViewReader { proxy in
                ScrollView {
                    Text(assistant.displayedText)
                        .font(.title)
                        .padding()
                        .id(1)
                }
                .onChange(of: assistant.displayedText) {
                    proxy.scrollTo(1, anchor: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Circle()
                .fill(assistant.isListening ? .red : (assistant.isSpeaking ? .orange : .blue))
                .frame(width: 100, height: 100)
                .overlay(Text(buttonLabel).foregroundColor(.white).font(.headline))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !assistant.isListening {
                                assistant.startListening()
                            }
                        }
                        .onEnded { _ in
                            if assistant.isListening {
                                assistant.stopListeningAndProcess()
                            }
                        }
                )
                .padding()
            
            HStack(spacing: 5) {
                Text(assistant.status)
                    .font(.body)
                
                if assistant.status == "Thinking..." {
                    Text(String(format: "%.1fs", assistant.thinkingTimeElapsed))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in }
                }
            }
            .padding(.bottom)
        }
        .frame(minWidth: 500, minHeight: 550) // Made slightly taller for the new pickers
        .onAppear(perform: setupKeyboardMonitoring)
    }
    
    private var buttonLabel: String {
        if assistant.isSpeaking { return "Stop" }
        if assistant.isListening { return "Listening..." }
        return "Press & Hold"
    }
    
    private func setupKeyboardMonitoring() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 49 {
                if !isSpaceBarPressed {
                    assistant.startListening()
                    isSpaceBarPressed = true
                }
                return nil
            }
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            if event.keyCode == 49 {
                if assistant.isListening {
                    assistant.stopListeningAndProcess()
                }
                isSpaceBarPressed = false
                return nil
            }
            return event
        }
    }
}
