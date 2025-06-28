import SwiftUI
import CoreAudio

struct ContentView: View {
    @StateObject private var assistant = Assistant()
    
    // This state variable is essential for tracking the key press state.
    @State private var isSpaceBarPressed = false

    var body: some View {
        VStack {
            Picker("Microphone:", selection: $assistant.selectedInputID) {
                ForEach(assistant.availableInputs, id: \.self) { device in
                    Text(device.name).tag(device.id as AudioDeviceID?)
                }
            }
            .padding()

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
                .overlay(
                    Text(buttonLabel)
                        .foregroundColor(.white)
                        .font(.headline)
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if assistant.isSpeaking {
                                assistant.startListening()
                            } else if !assistant.isListening {
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
            
            Text(assistant.status)
                .font(.body)
                .padding(.bottom)
        }
        .frame(minWidth: 450, minHeight: 450)
        // ** THE DEFINITIVE FIX **
        // This modifier is called once when the view appears.
        // It sets up a robust, app-wide keyboard listener.
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Check if the space bar is pressed.
                if event.keyCode == 49 { // 49 is the key code for the space bar
                    if !isSpaceBarPressed {
                        assistant.startListening()
                        isSpaceBarPressed = true
                    }
                    // By returning nil, we "swallow" the event and prevent the beep.
                    return nil
                }
                // For any other key, we pass the event on.
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
    
    private var buttonLabel: String {
        if assistant.isSpeaking {
            return "Stop"
        } else if assistant.isListening {
            return "Listening..."
        } else {
            return "Press & Hold"
        }
    }
}
