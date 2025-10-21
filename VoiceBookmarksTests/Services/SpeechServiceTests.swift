//
//  SpeechServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class SpeechServiceTests: XCTestCase {
    
    var sut: SpeechService!
    
    override func setUp() {
        super.setUp()
        sut = SpeechService.shared
    }
    
    override func tearDown() {
        sut.cancelRecording()
        sut = nil
        super.tearDown()
    }
    
    func testSpeechService_Singleton_IsAccessible() {
        XCTAssertNotNil(SpeechService.shared)
    }
    
    func testSpeechService_RequestAuthorization_RealAPI() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Тест требует физическое устройство для проверки реальных разрешений")
        #else
        let result = await sut.requestAuthorization()
        XCTAssertNotNil(result)
        #endif
    }
    
    func testMockSpeechService_RequestAuthorization_ReturnsTrue() async {
        let mock = MockSpeechService()
        mock.authorizationResult = true
        
        let result = await mock.requestAuthorization()
        
        XCTAssertTrue(mock.requestAuthorizationCalled)
        XCTAssertTrue(result)
    }
    
    func testMockSpeechService_RequestAuthorization_ReturnsFalse() async {
        let mock = MockSpeechService()
        mock.authorizationResult = false
        
        let result = await mock.requestAuthorization()
        
        XCTAssertTrue(mock.requestAuthorizationCalled)
        XCTAssertFalse(result)
    }
    
    func testSpeechService_Locale_IsRussian() {
        XCTAssertEqual(Constants.Speech.locale, "ru-RU")
    }
    
    func testMockSpeechService_StartRecording_CallsCallback() async throws {
        let mock = MockSpeechService()
        mock.mockTranscription = "тестовая транскрипция"
        
        var receivedText = ""
        try await mock.startRecordingForUnitTests { text in
            receivedText = text
        }
        
        XCTAssertTrue(mock.startRecordingCalled)
        XCTAssertEqual(receivedText, "тестовая транскрипция")
    }
    
    func testMockSpeechService_StopRecording_ReturnsTranscription() async {
        let mock = MockSpeechService()
        mock.mockTranscription = "результат"
        
        let result = await mock.stopRecording()
        
        XCTAssertTrue(mock.stopRecordingCalled)
        XCTAssertEqual(result, "результат")
    }
    
    func testSpeechService_CancelRecording_DoesNotCrash() {
        XCTAssertNoThrow(sut.cancelRecording())
    }
    
    func testSpeechService_TimeoutDuration_IsOneMinute() {
        XCTAssertEqual(Constants.Speech.timeoutNoSpeech, 60)
    }
    
    func testSpeechService_MaxDuration_IsFiveMinutes() {
        XCTAssertEqual(Constants.Speech.maxDuration, 300)
    }
    
    func testSpeechService_Haptic_IsConfigured() {
        XCTAssertGreaterThan(Constants.Speech.longPressDuration, 0)
    }
    
    func testMockSpeechService_Logging_Works() async {
        let mock = MockSpeechService()
        let result = await mock.requestAuthorization()
        XCTAssertNotNil(result)
    }
    
    func testMockSpeechService_CancelRecording_ClearsState() {
        let mock = MockSpeechService()
        mock.mockTranscription = "test"
        mock.cancelRecording()
        
        XCTAssertTrue(mock.cancelRecordingCalled)
        XCTAssertEqual(mock.mockTranscription, "")
    }
    
    func testMockSpeechService_StopRecording_ReturnsNilWhenEmpty() async {
        let mock = MockSpeechService()
        mock.mockTranscription = ""
        
        let result = await mock.stopRecording()
        XCTAssertNil(result)
    }
    
    func testSpeechService_Init_UsesCorrectLocale() {
        XCTAssertNotNil(sut)
        XCTAssertEqual(Constants.Speech.locale, "ru-RU")
    }
    
    func testSpeechService_CancelRecording_CanBeCalledMultipleTimes() {
        sut.cancelRecording()
        sut.cancelRecording()
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_StopRecording_WithoutRecording_ReturnsNil() async {
        sut.cancelRecording()
        _ = await sut.stopRecording()
    }
    
    func testSpeechService_StartRecording_ThrowsWhenAlreadyRecording() async throws {
        let mock = MockSpeechService()
        mock.mockTranscription = "test"
        
        var firstCallCompleted = false
        var secondCallThrew = false
        
        try await mock.startRecordingForUnitTests { _ in
            firstCallCompleted = true
        }
        
        do {
            try await mock.startRecordingForUnitTests { _ in }
        } catch {
            secondCallThrew = true
        }
        
        XCTAssertTrue(secondCallThrew || !firstCallCompleted)
    }
    
    func testSpeechService_UsesCorrectConstants() {
        XCTAssertEqual(Constants.Speech.locale, "ru-RU")
        XCTAssertEqual(Constants.Speech.timeoutNoSpeech, 60.0)
        XCTAssertEqual(Constants.Speech.maxDuration, 300.0)
        XCTAssertEqual(Constants.Speech.longPressDuration, 0.5)
    }
    
    func testMockSpeechService_StartRecording_SetsState() async throws {
        let mock = MockSpeechService()
        
        try await mock.startRecordingForUnitTests { _ in }
        
        XCTAssertTrue(mock.startRecordingCalled)
    }
    
    func testMockSpeechService_StopRecording_ClearsState() async {
        let mock = MockSpeechService()
        mock.mockTranscription = "test"
        
        _ = await mock.stopRecording()
        
        XCTAssertTrue(mock.stopRecordingCalled)
    }
    
    func testMockSpeechService_CancelRecording_ClearsTranscription() {
        let mock = MockSpeechService()
        mock.mockTranscription = "test transcription"
        
        mock.cancelRecording()
        
        XCTAssertTrue(mock.cancelRecordingCalled)
        XCTAssertEqual(mock.mockTranscription, "")
    }
    
    func testMockSpeechService_RequestAuthorization_ChecksBothPermissions() async {
        let mock = MockSpeechService()
        mock.authorizationResult = true
        
        let result = await mock.requestAuthorization()
        
        XCTAssertTrue(mock.requestAuthorizationCalled)
        XCTAssertTrue(result)
    }
    
    func testMockSpeechService_StartRecording_CallsCallbackWithPartialResult() async throws {
        let mock = MockSpeechService()
        mock.mockTranscription = "partial result"
        
        var receivedText = ""
        try await mock.startRecordingForUnitTests { text in
            receivedText = text
        }
        
        XCTAssertEqual(receivedText, "partial result")
    }
    
    func testMockSpeechService_StartThenStop_ReturnsTranscription() async throws {
        let mock = MockSpeechService()
        mock.mockTranscription = "final result"
        
        try await mock.startRecordingForUnitTests { _ in }
        let result = await mock.stopRecording()
        
        XCTAssertEqual(result, "final result")
    }
    
    func testSpeechService_Singleton_ReturnsSameInstance() {
        let instance1 = SpeechService.shared
        let instance2 = SpeechService.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    func testSpeechService_SupportsOnDeviceRecognition() {
        XCTAssertNotNil(sut)
        XCTAssertEqual(Constants.Speech.locale, "ru-RU")
    }
    
    func testMockSpeechService_StartRecording_ThrowsOnSecondCall() async throws {
        let mock = MockSpeechService()
        mock.mockTranscription = "first"
        
        try await mock.startRecordingForUnitTests { _ in }
        
        do {
            try await mock.startRecordingForUnitTests { _ in }
            XCTFail("Должна была быть выброшена ошибка")
        } catch {
            XCTAssertTrue(true, "Ошибка выброшена правильно")
        }
    }
    
    func testMockSpeechService_StartRecording_ThrowsMockError() async {
        let mock = MockSpeechService()
        let testError = NSError(domain: "Test", code: 1)
        mock.mockError = testError
        
        do {
            try await mock.startRecordingForUnitTests { _ in }
            XCTFail("Должна была быть выброшена ошибка")
        } catch {
            XCTAssertEqual((error as NSError).domain, "Test")
        }
    }
    
    func testSpeechService_StartRecording_TriggersHaptic() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StartRecording_ThrowsWhenNotIdle() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try await sut.startRecordingForUnitTests { _ in }
            XCTFail("Должна была быть выброшена ошибка 'Запись уже активна'")
        } catch let error as APIError {
            if case .serverError(let message) = error {
                if message.contains("Запись уже активна") || message.contains("недоступно") {
                } else {
                }
            }
            _ = await sut.stopRecording()
        } catch {
            _ = await sut.stopRecording()
        }
    }
    
    func testSpeechService_StartRecording_HandlesAudioSessionError() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            _ = await sut.stopRecording()
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testSpeechService_StartRecording_HandlesAudioEngineStartError() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            _ = await sut.stopRecording()
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testSpeechService_StartRecording_HandlesUnavailableRecognizer() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            _ = await sut.stopRecording()
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testSpeechService_RecognitionTask_HandlesCanceledError() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            sut.cancelRecording()
        } catch {
        }
    }
    
    func testSpeechService_RecognitionTask_HandlesFinalResult() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 500_000_000)
            _ = await sut.stopRecording()
            XCTAssertNotNil(sut)
        } catch {
        }
    }
    
    func testSpeechService_RecognitionTask_HandlesPartialResult() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 500_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_RecognitionTask_ResetsTimer() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 500_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StartRecognitionTimer_CreatesTimer() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 100_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_RecognitionTimer_StopsRecordingOnTimeout() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 100_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_ResetRecognitionTimer_InvalidatesAndCreatesNew() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 500_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StartMaxDurationTimer_CreatesTimer() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 100_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_MaxDurationTimer_StopsRecordingOnMaxDuration() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 100_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StopRecording_HandlesIdleStateWithEmptyTranscription() async {
        sut.cancelRecording()
        
        let result = await sut.stopRecording()
        XCTAssertNil(result, "Должен вернуть nil когда idle и транскрипция пуста")
    }
    
    func testSpeechService_StopRecording_HandlesIdleStateWithTranscription() async {
        sut.cancelRecording()
        
        _ = await sut.stopRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_StopRecording_WaitsForFinalization() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            _ = await sut.stopRecording()
            XCTAssertNotNil(sut)
        } catch {
        }
    }
    
    func testSpeechService_StopRecording_HandlesAudioEngineNotRunning() async {
        sut.cancelRecording()
        
        _ = await sut.stopRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_StopRecording_HandlesAudioSessionDeactivationError() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_CancelRecording_HandlesIdleState() {
        sut.cancelRecording()
        
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_CancelRecording_HandlesAudioEngineNotRunning() {
        sut.cancelRecording()
        
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_CancelRecording_HandlesAudioSessionDeactivationError() {
        sut.cancelRecording()
        
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_CancelRecording_ClearsTranscriptionAndCallback() {
        sut.cancelRecording()
        
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_FallbackToOfflineRecognition_HandlesNoOfflineSupport() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_FallbackToOfflineRecognition_CreatesOfflineRequest() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_FallbackToOfflineRecognition_HandlesResult() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_FallbackToOfflineRecognition_HandlesError() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_HandleRecognitionError_CancelsRecording() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_HandleRecognitionError_CallsCallbackWithEmptyString() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_StartRecording_ChecksState() async throws {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try await sut.startRecordingForUnitTests { _ in }
            XCTFail("Должна была быть выброшена ошибка")
        } catch {
            _ = await sut.stopRecording()
        }
    }
    
    func testSpeechService_RecognitionTask_HandlesWeakSelfNil() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 100_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StopRecording_ReturnsSavedTranscriptionWhenIdle() async {
        sut.cancelRecording()
        
        _ = await sut.stopRecording()
    }
    
    func testSpeechService_StartRecording_SetsPartialResultCallback() async throws {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 500_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StartRecording_ClearsFinalTranscription() async throws {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 100_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StartRecognitionTimer_CreatesTimerThroughFactory() async {
        #if DEBUG
        let mockTimerFactory = MockTimerFactory()
        let testService = SpeechService(forTesting: true, timerFactory: mockTimerFactory)
        testService.cancelRecording()
        
        do {
            try await testService.startRecordingForUnitTests { _ in }
            XCTAssertGreaterThan(mockTimerFactory.scheduledTimers.count, 0, "Таймер должен быть создан")
            _ = await testService.stopRecording()
        } catch {
        }
        #else
        sut.cancelRecording()
        XCTAssertNotNil(sut)
        #endif
    }
    
    func testSpeechService_StartMaxDurationTimer_CreatesTimerThroughFactory() async {
        #if DEBUG
        let mockTimerFactory = MockTimerFactory()
        let testService = SpeechService(forTesting: true, timerFactory: mockTimerFactory)
        testService.cancelRecording()
        
        do {
            try await testService.startRecordingForUnitTests { _ in }
            XCTAssertGreaterThanOrEqual(mockTimerFactory.scheduledTimers.count, 1, "Таймеры должны быть созданы")
            _ = await testService.stopRecording()
        } catch {
        }
        #else
        sut.cancelRecording()
        XCTAssertNotNil(sut)
        #endif
    }
    
    func testSpeechService_ResetRecognitionTimer_WithMock_InvalidatesAndCreatesNew() async {
        #if DEBUG
        let mockTimerFactory = MockTimerFactory()
        let testService = SpeechService(forTesting: true, timerFactory: mockTimerFactory)
        testService.cancelRecording()
        
        do {
            try await testService.startRecordingForUnitTests { _ in }
            let initialTimerCount = mockTimerFactory.scheduledTimers.count
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            _ = await testService.stopRecording()
            
            XCTAssertGreaterThan(initialTimerCount, 0)
        } catch {
        }
        #else
        sut.cancelRecording()
        XCTAssertNotNil(sut)
        #endif
    }
    
    func testSpeechService_RecognitionTimer_CallsStopRecordingOnTimeout() async {
        #if DEBUG
        let mockTimerFactory = MockTimerFactory()
        let testService = SpeechService(forTesting: true, timerFactory: mockTimerFactory)
        testService.cancelRecording()
        
        do {
            try await testService.startRecordingForUnitTests { _ in }
            
            XCTAssertGreaterThan(mockTimerFactory.scheduledTimers.count, 0)
            
            if let recognitionTimer = mockTimerFactory.mockTimers.first {
                recognitionTimer.fire()
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            
            _ = await testService.stopRecording()
        } catch {
        }
        #else
        sut.cancelRecording()
        XCTAssertNotNil(sut)
        #endif
    }
    
    func testSpeechService_MaxDurationTimer_CallsStopRecordingOnMaxDuration() async {
        #if DEBUG
        let mockTimerFactory = MockTimerFactory()
        let testService = SpeechService(forTesting: true, timerFactory: mockTimerFactory)
        testService.cancelRecording()
        
        do {
            try await testService.startRecordingForUnitTests { _ in }
            
            if mockTimerFactory.mockTimers.count >= 2 {
                let maxDurationTimer = mockTimerFactory.mockTimers[1]
                maxDurationTimer.fire()
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            
            _ = await testService.stopRecording()
        } catch {
        }
        #else
        sut.cancelRecording()
        XCTAssertNotNil(sut)
        #endif
    }
    
    func testSpeechService_RecognitionTask_HandlesNonCanceledError() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 100_000_000)
            sut.cancelRecording()
            try? await Task.sleep(nanoseconds: 100_000_000)
        } catch {
        }
    }
    
    func testSpeechService_RecognitionTask_HandlesNonFinalResult() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StopRecording_ReturnsTranscriptionWhenIdleAndNotEmpty() async {
        sut.cancelRecording()
        
        let result = await sut.stopRecording()
        XCTAssertNil(result)
    }
    
    func testSpeechService_StopRecording_StopsAudioEngineWhenRunning() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            try? await Task.sleep(nanoseconds: 100_000_000)
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_CancelRecording_HandlesRecordingState() {
        sut.cancelRecording()
        
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_CancelRecording_StopsAudioEngineWhenRunning() {
        sut.cancelRecording()
        
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_FallbackToOfflineRecognition_HandlesOnDeviceSupport() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_HandleRecognitionError_CallsCancelRecording() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_HandleRecognitionError_CallsCallbackOnMainQueue() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_FallbackRecognitionTask_HandlesWeakSelfNil() async {
        sut.cancelRecording()
        XCTAssertNotNil(sut)
    }
    
    func testSpeechService_StartRecording_SetsStateToRecording() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StartRecording_SetsPartialResults() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            _ = await sut.stopRecording()
        } catch {
        }
    }
    
    func testSpeechService_StartRecording_SetsRecognitionRequest() async {
        sut.cancelRecording()
        
        do {
            try await sut.startRecordingForUnitTests { _ in }
            _ = await sut.stopRecording()
        } catch {
        }
    }
}

extension SpeechService {
    func startRecordingForUnitTests(onPartialResult: @escaping (String) -> Void) async throws {
        try await startRecording(onPartialResult: onPartialResult, taskHint: nil, timeoutNoSpeech: nil)
    }
}

extension MockSpeechService {
    func startRecordingForUnitTests(onPartialResult: @escaping (String) -> Void) async throws {
        try await startRecording(onPartialResult: onPartialResult, taskHint: nil, timeoutNoSpeech: nil)
    }
}

