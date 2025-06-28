// SpeechRecognitionService.swift

import Foundation
import Speech
import AVFoundation
import CoreAudio

class SpeechRecognitionService {
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { _ in }
    }

    func startTranscribing(deviceID: AudioDeviceID) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            do {
                // ** THE DEFINITIVE FIX **
                // Access the .audioUnit property directly from the AVAudioInputNode.
                guard let audioUnit = self.audioEngine.inputNode.audioUnit else {
                    continuation.finish(throwing: NSError(domain: "SpeechServiceError", code: 8, userInfo: [NSLocalizedDescriptionKey: "Could not get audio unit."]))
                    return
                }
                
                var deviceID = deviceID
                let status = AudioUnitSetProperty(
                    audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &deviceID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                
                if status != noErr {
                    continuation.finish(throwing: NSError(domain: "SpeechServiceError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to set audio device."]))
                    return
                }

                let inputNode = self.audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)
                
                guard recordingFormat.channelCount > 0 else {
                    continuation.finish(throwing: NSError(domain: "SpeechServiceError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format."]))
                    return
                }

                let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                recognitionRequest.shouldReportPartialResults = true

                self.recognitionTask = self.speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                    if let result = result {
                        continuation.yield(result.bestTranscription.formattedString)
                        if result.isFinal { continuation.finish() }
                    } else if let error = error {
                        continuation.finish(throwing: error)
                    }
                }

                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    recognitionRequest.append(buffer)
                }

                self.audioEngine.prepare()
                try self.audioEngine.start()
                
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    func stopTranscribing() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionTask?.finish()
        recognitionTask = nil
    }
}

