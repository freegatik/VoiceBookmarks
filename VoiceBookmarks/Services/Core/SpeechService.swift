//
//  SpeechService.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import Speech
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

protocol SpeechServiceProtocol: AnyObject {
    func requestAuthorization() async -> Bool
    func startRecording(
        onPartialResult: @escaping (String) -> Void,
        taskHint: SFSpeechRecognitionTaskHint?,
        timeoutNoSpeech: TimeInterval?
    ) async throws
    func stopRecording() async -> String?
    func cancelRecording()
    func prewarmAudioSession() async
    func prewarmAudioEngine() async
}

// MARK: - Распознавание речи: on-device и серверное, таймауты, обработка ошибок
class SpeechService: SpeechServiceProtocol, @unchecked Sendable {
    
    static let shared = SpeechService()
    private let logger = LoggerService.shared
    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private let transcriptionMerger = TranscriptionMerger()
    
    enum RecordingState {
        case idle
        case recording
        case processing
    }
    
    var state: RecordingState = .idle
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionTimer: TimerProtocol?

    private var maxDurationTimer: TimerProtocol?

    private var partialResultCallback: ((String) -> Void)?
    private var finalTranscription: String = ""
    private var currentTimeoutNoSpeech: TimeInterval = Constants.Speech.timeoutNoSpeech
    private var hasReceivedAnyResult: Bool = false

    private var gracePeriodTimer: TimerProtocol?

    private var firstResultBuffer: String?

    private var firstResultBufferTask: Task<Void, Never>?

    private var gracePeriodStartTime: Date?

    private var pauseExtensionCount: Int = 0

    private let maxPauseExtensions: Int = 10

    private let timerFactory: TimerFactoryProtocol
    private var isTapInstalled = false
    private var isUsingOnDeviceRecognition = false
    private var forceServerRecognition = false

    private var isCancellingOrStopping = false
    private var isPrewarming = false

    private var sessionDeactivateTask: Task<Void, Never>?
    private var onDeviceFailureCooldownUntil: Date?

    private var isRestarting = false

    private var isStartingTask = false

    
    private init(timerFactory: TimerFactoryProtocol = TimerFactory()) {
        self.timerFactory = timerFactory
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Constants.Speech.locale))
        
        if let recognizer = speechRecognizer {
            logger.info("SpeechService инициализирован с locale: \(Constants.Speech.locale), supportsOnDeviceRecognition: \(recognizer.supportsOnDeviceRecognition)", category: .speech)
        } else {
            logger.error("Не удалось создать SpeechRecognizer", category: .speech)
        }
    }
    
    #if DEBUG
    init(forTesting: Bool, timerFactory: TimerFactoryProtocol = TimerFactory()) {
        self.timerFactory = timerFactory
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Constants.Speech.locale))
        
        if let recognizer = speechRecognizer {
            logger.info("SpeechService инициализирован с locale: \(Constants.Speech.locale), supportsOnDeviceRecognition: \(recognizer.supportsOnDeviceRecognition)", category: .speech)
        } else {
            logger.error("Не удалось создать SpeechRecognizer", category: .speech)
        }
    }
    #endif
    
    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechStatus else {
            logger.error("Нет разрешения на распознавание речи", category: .speech)
            return false
        }
        
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        if speechStatus && micStatus {
            return true
        } else {
            logger.error("Нет разрешения на микрофон", category: .speech)
            return false
        }
    }
    
    
    /// Начало записи: настройка аудио сессии, выбор on-device/серверного распознавания, запуск таймеров
    func startRecording(
        onPartialResult: @escaping (String) -> Void,
        taskHint: SFSpeechRecognitionTaskHint? = nil,
        timeoutNoSpeech: TimeInterval? = nil
    ) async throws {
        guard state == .idle else {
            throw APIError.serverError(message: "Запись уже активна")
        }
        
        state = .recording
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            logger.error("SpeechRecognizer недоступен", category: .speech)
            state = .idle
            throw APIError.serverError(message: "Распознавание речи недоступно")
        }
        
        currentTimeoutNoSpeech = timeoutNoSpeech ?? Constants.Speech.timeoutNoSpeech
        
        triggerHaptic()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Error настройки аудио сессии: \(error)", category: .speech)
            state = .idle
            throw APIError.serverError(message: "Не удалось настроить аудио сессию")
        }
        
        let onDeviceAllowedByCooldown: Bool = {
            if let until = onDeviceFailureCooldownUntil {
                return Date() >= until
            }
            return true
        }()
        let prefersOnDevice = !forceServerRecognition
            && onDeviceAllowedByCooldown
            && (speechRecognizer?.supportsOnDeviceRecognition ?? false)
        recognitionRequest = makeRecognitionRequest(useOnDevice: prefersOnDevice, taskHint: taskHint)
        
        self.partialResultCallback = onPartialResult
        finalTranscription = ""
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        if isTapInstalled {
            logger.debug("Удаляем существующий tap перед установкой нового", category: .speech)
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, let request = self.recognitionRequest else { return }
            request.append(buffer)
        }
        isTapInstalled = true
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            logger.error("Error запуска audioEngine: \(error)", category: .speech)
            state = .idle
            recognitionRequest = nil
            recognitionTask = nil
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
            throw APIError.serverError(message: "Не удалось запустить запись")
        }
        
        startRecognitionTask(onPartialResult: onPartialResult)
        
        hasReceivedAnyResult = false
        pauseExtensionCount = 0

        firstResultBuffer = nil
        firstResultBufferTask?.cancel()
        firstResultBufferTask = nil
        gracePeriodStartTime = nil
        
        startGracePeriodTimer()
        startMaxDurationTimer()
        
    }
    
    func stopRecording() async -> String? {
        guard state != .idle else {
            return finalTranscription.isEmpty ? nil : finalTranscription
        }
        isCancellingOrStopping = true
        
        defer {
            state = .idle
            isCancellingOrStopping = false
            pauseExtensionCount = 0

            logger.debug("stopRecording: состояние сброшено в idle", category: .speech)
        }
        
        recognitionTimer?.invalidate()
        gracePeriodTimer?.invalidate()
        maxDurationTimer?.invalidate()
        
        recognitionRequest?.endAudio()
        
        var finalResult: String? = finalTranscription.isEmpty ? nil : finalTranscription
        if finalTranscription.isEmpty {
            try? await Task.sleep(nanoseconds: 300_000_000)
            finalResult = finalTranscription.isEmpty ? nil : finalTranscription
        }
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = nil
        
        isStartingTask = false
        
        scheduleAudioSessionDeactivation(after: 2.0)
        
        return finalResult
    }
    
    /// Cancel записи: остановка всех таймеров, очистка ресурсов
    func cancelRecording() {
        guard state != .idle else {
            recognitionTimer?.invalidate()
            gracePeriodTimer?.invalidate()
            maxDurationTimer?.invalidate()
            firstResultBufferTask?.cancel()
            firstResultBufferTask = nil
            firstResultBuffer = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            if isTapInstalled {
                audioEngine.inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            recognitionRequest?.endAudio()
            recognitionRequest = nil
            return
        }
        
        isCancellingOrStopping = true
        isRestarting = false
        isStartingTask = false
        
        recognitionTimer?.invalidate()
        gracePeriodTimer?.invalidate()
        maxDurationTimer?.invalidate()
        firstResultBufferTask?.cancel()
        firstResultBufferTask = nil
        firstResultBuffer = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        scheduleAudioSessionDeactivation(after: 2.0)
        
        state = .idle
        finalTranscription = ""
        partialResultCallback = nil
        hasReceivedAnyResult = false
        pauseExtensionCount = 0
        isCancellingOrStopping = false
        firstResultBuffer = nil
        firstResultBufferTask?.cancel()
        firstResultBufferTask = nil
        logger.debug("cancelRecording: состояние сброшено в idle", category: .speech)
    }
    
    
    /// Отложенная деактивация аудио сессии (soft linger) - позволяет быстро перезапустить запись
    /// Деактивируется только если состояние idle и нет прогрева
    private func scheduleAudioSessionDeactivation(after seconds: TimeInterval) {
        sessionDeactivateTask?.cancel()
        sessionDeactivateTask = Task { [weak self] in
            guard let self else { return }
            let ns = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            if self.state == .idle {
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    self.logger.debug("AudioSession деактивирован (soft linger \(seconds)s)", category: .speech)
                } catch {
                    self.logger.warning("Деактивация аудио сессии не удалась: \(error)", category: .speech)
                }
            }
        }
    }
    
    /// Тактильная обратная связь при начале записи
    private func triggerHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    
    /// Прогревает аудио сессию для быстрого старта записи
    /// Ускоряет инициализацию при первом запуске записи
    func prewarmAudioSession() async {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            logger.debug("AudioSession prewarm завершен", category: .speech)
        } catch {
            logger.warning("AudioSession prewarm не удался: \(error)", category: .speech)
        }
    }
    
    /// Прогревает audioEngine для быстрого старта записи (короткий запуск на 80мс)
    /// Инициализирует audioEngine и устанавливает временный tap для прогрева
    func prewarmAudioEngine() async {
        if state != .idle { return }
        if isCancellingOrStopping { return }
        if isPrewarming { return }

        isPrewarming = true
        defer {
            isPrewarming = false
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            if state != .idle {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                return
            }
            
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            
            if !isTapInstalled {
                inputNode.installTap(onBus: 0, bufferSize: 256, format: format) { _, _ in }
                isTapInstalled = true
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            try? await Task.sleep(nanoseconds: 80_000_000)
            
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            if isTapInstalled {
                inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            logger.debug("AudioEngine prewarm завершен", category: .speech)
        } catch {
            logger.warning("AudioEngine prewarm не удался: \(error)", category: .speech)
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            if isTapInstalled {
                audioEngine.inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    
    /// Создание запроса распознавания: выбор on-device или серверного распознавания
    private func makeRecognitionRequest(useOnDevice: Bool, taskHint: SFSpeechRecognitionTaskHint? = nil) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        let hint = taskHint ?? .dictation
        request.taskHint = hint
        
        if hint == .dictation {
        }
        
        if useOnDevice,
           let recognizer = speechRecognizer,
           recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            isUsingOnDeviceRecognition = true
            logger.debug("Используем on-device распознавание (taskHint: \(request.taskHint.rawValue))", category: .speech)
        } else {
            isUsingOnDeviceRecognition = false
            logger.debug("Используем серверное распознавание (taskHint: \(request.taskHint.rawValue))", category: .speech)
        }
        
        return request
    }
    
    
    /// Запуск задачи распознавания: обработка partial и final результатов, обработка ошибок
    private func startRecognitionTask(onPartialResult: @escaping (String) -> Void) {
        guard let recognizer = speechRecognizer else {
            logger.error("startRecognitionTask: SpeechRecognizer отсутствует", category: .speech)
            return
        }
        guard let request = recognitionRequest else {
            logger.error("startRecognitionTask: recognitionRequest отсутствует", category: .speech)
            return
        }
        
        if isStartingTask {
            logger.warning("startRecognitionTask уже выполняется, пропускаем повторный вызов", category: .speech)
            return
        }
        
        isStartingTask = true
        
        if let existingTask = recognitionTask {
            logger.debug("startRecognitionTask: отменяем существующую задачу перед созданием новой", category: .speech)
            existingTask.cancel()
            recognitionTask = nil
        }
        
        logger.debug("startRecognitionTask: создаем новую задачу распознавания", category: .speech)
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            self.isStartingTask = false
            
            if let error = error as NSError? {
                self.logger.warning("Error распознавания речи получена: \(error.localizedDescription), код: \(error.code), domain: \(error.domain)", category: .speech)
                
                if self.handleRecognitionError(error, onPartialResult: onPartialResult) {
                    return
                }
                
                let isCriticalError = error.domain == "kAFAssistantErrorDomain" && (error.code == 1100 || error.code == 1101 || error.code == 1102)
                self.logger.error("Error распознавания речи не обработана: \(error.localizedDescription), код: \(error.code), критическая: \(isCriticalError)", category: .speech)
                
                if isCriticalError && self.state != .idle {
                    if error.code == 1101 && self.isUsingOnDeviceRecognition {
                        self.logger.warning("Error 1101 через обычный handler, переключаемся на сервер", category: .speech)
                        self.onDeviceFailureCooldownUntil = Date().addingTimeInterval(60)
                        self.forceServerRecognition = true
                        DispatchQueue.main.async {
                            self.restartRecognition(useOnDevice: false, onPartialResult: onPartialResult)
                        }
                    } else {
                        self.logger.warning("Критическая ошибка распознавания, останавливаем запись", category: .speech)
                    self.cancelRecording()
                    }
                }
                return
            }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                self.finalTranscription = transcription
                
                let hasText = !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if hasText {
                    let wasFirstResult = !self.hasReceivedAnyResult
                    let hadReceivedAnyResultBefore = self.hasReceivedAnyResult
                    self.hasReceivedAnyResult = true
                    self.resetRecognitionTimer()
                    
                    if wasFirstResult {
                        let wordCount = transcription.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                        self.logger.info("Получен первый результат распознавания: '\(transcription.prefix(50))...', \(transcription.count) символов, \(wordCount) слов, сбрасываем таймер", category: .speech)
                        
                        if transcription.count < 3 {
                            self.logger.warning("Первый результат очень короткий (\(transcription.count) символов) - буферизуем и ждем следующий результат", category: .speech)
                            self.firstResultBuffer = transcription
                            
                            if let startTime = self.gracePeriodStartTime {
                                let elapsed = Date().timeIntervalSince(startTime)
                                if elapsed >= 12.0 && elapsed < 15.0 {
                                    self.logger.info("Первый результат получен в последние 3 секунды grace period и короткий - продлеваем grace period на 3 секунды", category: .speech)
                                    self.gracePeriodTimer?.invalidate()
                                    self.gracePeriodTimer = self.timerFactory.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                                        guard let self = self else { return }
                                        if !hadReceivedAnyResultBefore {
                                            self.startRecognitionTimer()
                                        }
                                    }
                                }
                            }
                            
                            self.firstResultBufferTask?.cancel()
                            
                            let callback = onPartialResult
                            let bufferedText = self.firstResultBuffer
                            let logger = self.logger
                            
                            self.firstResultBufferTask = Task { @MainActor [weak self] in
                                try? await Task.sleep(nanoseconds: 1_500_000_000)

                                guard let self = self, let buffered = bufferedText else { return }
                                logger.info("Таймаут буферизации первого результата, передаем: '\(buffered.prefix(50))...'", category: .speech)
                                self.firstResultBuffer = nil
                                callback(buffered)
                            }
                            return
                        }
                    } else {
                        if let buffered = self.firstResultBuffer {
                            self.logger.info("Получен следующий результат после буферизации, объединяем: '\(buffered)' + '\(transcription.prefix(30))...'", category: .speech)
                            self.firstResultBufferTask?.cancel()
                            self.firstResultBufferTask = nil
                            
                            if let merged = self.transcriptionMerger.merge(accumulated: buffered, new: transcription) {
                                self.firstResultBuffer = nil
                                DispatchQueue.main.async {
                                    onPartialResult(merged)
                                }
                            } else {
                                self.logger.debug("Буферизованный результат проигнорирован при слиянии (дубликат/исправление), передаем только новый", category: .speech)
                                self.firstResultBuffer = nil
                                DispatchQueue.main.async {
                                    onPartialResult(transcription)
                                }
                            }
                            return
                        }
                        self.logger.debug("Получен результат распознавания: '\(transcription.prefix(50))...', сбрасываем таймер", category: .speech)
                    }
                } else {
                    self.logger.debug("Получен пустой результат, таймер не сбрасываем, были результаты: \(self.hasReceivedAnyResult)", category: .speech)
                }
                
                DispatchQueue.main.async {
                    onPartialResult(transcription)
                }
                
                if result.isFinal {
                    self.logger.info("Распознавание завершено успешно, финальный текст: '\(transcription.prefix(100))...'", category: .speech)
                }
            }
        }
    }
    
    private func handleRecognitionError(_ error: NSError, onPartialResult: @escaping (String) -> Void) -> Bool {
        let domain = error.domain
        let code = error.code
        
        logger.info("Обработка ошибки распознавания: domain=\(domain), code=\(code), state=\(state), isUsingOnDeviceRecognition=\(isUsingOnDeviceRecognition), hasReceivedAnyResult=\(hasReceivedAnyResult)", category: .speech)
        
        if isCancellingOrStopping {
            logger.debug("Error получена во время отмены/остановки записи, игнорируем", category: .speech)
            return true
        }
        
        if domain == "kAFAssistantErrorDomain" {
            if isUsingOnDeviceRecognition && (code == 1100 || code == 1101 || code == 1102) {
                onDeviceFailureCooldownUntil = Date().addingTimeInterval(60)
                logger.warning("On-device распознавание недоступно (код \(code)), переключаемся на сервер на 60с", category: .speech)
                forceServerRecognition = true
                DispatchQueue.main.async { [weak self] in
                    self?.restartRecognition(useOnDevice: false, onPartialResult: onPartialResult)
                }
                return true
            }
            
            if code == 1110 {
                if hasReceivedAnyResult {
                    resetRecognitionTimer(resetPauseCount: false)
                    logger.debug("Error 1110 (пауза в речи): продлеваем таймер, запись продолжается", category: .speech)
                } else {
                    logger.debug("Error 1110 (пауза в речи): продолжаем ожидание первого слова (grace period)", category: .speech)
                }
                return true
            }
            
            if code == 1101 {
                if isUsingOnDeviceRecognition && state == .recording {
                    onDeviceFailureCooldownUntil = Date().addingTimeInterval(60)
                    logger.warning("On-device распознавание недоступно (код 1101), переключаемся на сервер на 60с", category: .speech)
                    forceServerRecognition = true
                    DispatchQueue.main.async { [weak self] in
                        self?.restartRecognition(useOnDevice: false, onPartialResult: onPartialResult)
                    }
                    return true
                } else if state == .recording {
                    logger.debug("Error 1101 во время записи (не on-device): продолжаем запись", category: .speech)
                    return true
                } else {
                    onDeviceFailureCooldownUntil = Date().addingTimeInterval(60)
                    logger.debug("Error 1101 (запись не активна): устанавливаем cooldown", category: .speech)
                    return true
                }
            }
        }
        
        if error.localizedDescription.contains("canceled") {
            logger.debug("Error отмены распознавания, игнорируем", category: .speech)
            return true
        }
        
        logger.warning("Error распознавания не обработана: domain=\(domain), code=\(code), description=\(error.localizedDescription)", category: .speech)
        return false
    }
    
    private func restartRecognition(useOnDevice: Bool, onPartialResult: @escaping (String) -> Void) {
        guard state == .recording else { return }
        
        if isRestarting {
            logger.warning("restartRecognition уже выполняется, пропускаем повторный вызов", category: .speech)
            return
        }
        
        isRestarting = true
        
        let taskHint = recognitionRequest?.taskHint
        let newRequest = makeRecognitionRequest(useOnDevice: useOnDevice, taskHint: taskHint)
        recognitionRequest = newRequest
        
        if let existingTask = recognitionTask {
            existingTask.cancel()
        recognitionTask = nil
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.isRestarting = false
            guard self.state == .recording else { return }
            self.startRecognitionTask(onPartialResult: onPartialResult)
        }
    }
    
    private func fallbackToOfflineRecognition(originalRequest: SFSpeechAudioBufferRecognitionRequest) async {
        guard let recognizer = speechRecognizer, recognizer.supportsOnDeviceRecognition else {
            await handleRecognitionError(error: NSError(domain: "SpeechService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Офлайн recognition недоступен"]))
            return
        }
        
        let offlineRequest = SFSpeechAudioBufferRecognitionRequest()
        offlineRequest.shouldReportPartialResults = true
        offlineRequest.requiresOnDeviceRecognition = true
        
        recognitionTask?.cancel()
        
        recognitionTask = recognizer.recognitionTask(with: offlineRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                self.finalTranscription = transcription
                
                if !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.hasReceivedAnyResult = true
                    self.resetRecognitionTimer()
                }
                
                DispatchQueue.main.async {
                    self.partialResultCallback?(transcription)
                }
            }
            
            if let error = error {
                self.logger.error("Error офлайн recognition: \(error.localizedDescription)", category: .speech)
                Task {
                    await self.handleRecognitionError(error: error)
                }
            }
        }
    }
    
    private func handleRecognitionError(error: Error) async {
        logger.error("Обработка ошибки распознавания: \(error.localizedDescription)", category: .speech)
        
        cancelRecording()
        
        DispatchQueue.main.async {
            self.partialResultCallback?("")
        }
    }
    
    private func startGracePeriodTimer() {
        let gracePeriod: TimeInterval = currentTimeoutNoSpeech == Constants.Speech.timeoutNoSpeechForDictation ? 15.0 : 3.0
        gracePeriodStartTime = Date()
        gracePeriodTimer = timerFactory.scheduledTimer(withTimeInterval: gracePeriod, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.hasReceivedAnyResult {
                self.logger.debug("Grace period истек, запускаем таймер отсутствия речи (результатов еще нет)", category: .speech)
                self.startRecognitionTimer()
            } else {
                self.logger.debug("Grace period истек, но уже есть результаты - таймер уже работает", category: .speech)
            }
        }
        logger.debug("Запущен grace period: \(gracePeriod) секунд для комфортного начала речи", category: .speech)
    }
    
    private func startRecognitionTimer() {
        recognitionTimer?.invalidate()
        let timeout = currentTimeoutNoSpeech
        logger.debug("Запуск таймера отсутствия речи: \(timeout) секунд, были результаты: \(hasReceivedAnyResult), продлений: \(pauseExtensionCount)", category: .speech)
        recognitionTimer = timerFactory.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.hasReceivedAnyResult {
                self.logger.warning("Таймаут: нет речи \(self.currentTimeoutNoSpeech) секунд (результатов не было), состояние \(self.state), останавливаем запись", category: .speech)
                if self.state == .recording {
            Task {
                _ = await self.stopRecording()
                    }
                }
            } else {
                if self.pauseExtensionCount >= self.maxPauseExtensions {
                    self.logger.warning("Таймаут: достигнуто максимальное количество продлений (\(self.maxPauseExtensions)), останавливаем запись после паузы", category: .speech)
                    if self.state == .recording {
                        Task {
                            _ = await self.stopRecording()
                        }
                    }
                } else {
                    self.logger.info("Таймаут: пауза в речи \(self.currentTimeoutNoSpeech) секунд (были результаты, продлеваем таймер \(self.pauseExtensionCount + 1)/\(self.maxPauseExtensions)), состояние \(self.state)", category: .speech)
                    if self.state == .recording {
                        self.pauseExtensionCount += 1
                        self.resetRecognitionTimer(resetPauseCount: false)
                    } else {
                        self.logger.warning("Не продлеваем таймер: состояние \(self.state) не равно recording", category: .speech)
                    }
                }
            }
        }
    }
    
    private func resetRecognitionTimer(resetPauseCount: Bool = true) {
        recognitionTimer?.invalidate()
        if resetPauseCount {
            pauseExtensionCount = 0
        }
        if hasReceivedAnyResult && state == .recording {
            if resetPauseCount {
                logger.debug("Перезапуск таймера: были результаты, состояние \(state), счетчик продлений сброшен", category: .speech)
            } else {
                logger.debug("Перезапуск таймера: продление паузы, состояние \(state), счетчик продлений: \(pauseExtensionCount)", category: .speech)
            }
            startRecognitionTimer()
        } else {
            logger.debug("Не перезапускаем таймер: были результаты \(hasReceivedAnyResult), состояние \(state)", category: .speech)
        }
    }
    
    private func startMaxDurationTimer() {
        maxDurationTimer = timerFactory.scheduledTimer(withTimeInterval: Constants.Speech.maxDuration, repeats: false) { [weak self] _ in
            self?.logger.warning("Достигнута максимальная длительность 5 минут", category: .speech)
            Task {
                _ = await self?.stopRecording()
            }
        }
    }
    
}
