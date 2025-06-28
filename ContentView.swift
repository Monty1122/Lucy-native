import SwiftUI
import CoreAudio // Import CoreAudio to use the AudioDeviceID type in the Picker tag

struct ContentView: View {
    @StateObject private var assistant = Assistant()

    var body: some View {
        VStack {
            // ** THE UI FIX **
            // This Picker will display the list of available microphones.
            Picker("Microphone:", selection: $assistant.selectedInputID) {
                // We loop over the availableInputs array from the Assistant.
                ForEach(assistant.availableInputs, id: \.self) { device in
                    // Use .tag to associate each Text view with its device ID.
                    Text(device.name).tag(device.id as AudioDeviceID?)
                }
            }
            .padding()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(assistant.displayedText)
                        .padding()
                        .id(1)
                }
                .onChange(of: assistant.displayedText) {
                    proxy.scrollTo(1, anchor: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Circle()
                .fill(assistant.isListening ? .red : .blue)
                .frame(width: 80, height: 80)
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
            
            Text(assistant.status)
                .font(.caption)
                .padding(.bottom)
        }
        .frame(minWidth: 400, minHeight: 400) // Made slightly taller for the picker
    }
}
