//
//  MockSpeechService.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import Speech
@testable import VoiceBookmarks

class MockSpeechService: SpeechServiceProtocol {
    
    var authorizationResult: Bool = true
    var mockTranscription: String = ""
    var mockError: Error?
    var requestAuthorizationCalled = false
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var cancelRecordingCalled = false
    var partialResultCallback: ((String) -> Void)?
    private var isRecording = false
    
    func requestAuthorization() async -> Bool {
        requestAuthorizationCalled = true
        return authorizationResult
    }
    
    func startRecording(
        onPartialResult: @escaping (String) -> Void,
        taskHint: SFSpeechRecognitionTaskHint?,
        timeoutNoSpeech: TimeInterval?
    ) async throws {
        startRecordingCalled = true
        partialResultCallback = onPartialResult

        if let error = mockError {
            throw error
        }
        if isRecording {
            throw NSError(domain: "MockSpeechService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Already recording"])
        }
        isRecording = true

        if !mockTranscription.isEmpty {
            onPartialResult(mockTranscription)
        }
    }
    
    func stopRecording() async -> String? {
        stopRecordingCalled = true
        isRecording = false
        return mockTranscription.isEmpty ? nil : mockTranscription
    }
    
    func cancelRecording() {
        cancelRecordingCalled = true
        isRecording = false
        mockTranscription = ""
    }

    func prewarmAudioSession() async {}

    func prewarmAudioEngine() async {}
}

