//
//  ShareViewModel.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

class ShareViewModel: ObservableObject {
    
    @Published var isRecording: Bool = false
    @Published var transcription: String = ""
    @Published var showPasteButton: Bool = false
    @Published var pasteButtonPosition: CGPoint = .zero
    @Published var contentPreview: ClipboardContent?
    @Published var isUploading: Bool = false
    @Published var toast: ToastModifier.ToastItem?
    @Published var contentPreviewOffset: CGFloat = 0
    @Published var shouldDismiss: Bool = false
    
    private var isSwipeDownProcessing = false
    
    private var recordingStartTime: Date?
    private var currentClipboardContent: ClipboardContent?
    private var wasSwipeDown: Bool = false
    private var isUploadingContent: Bool = false
    private var isProcessingLongPressEnd: Bool = false
    private var hasSpeechAuthorization: Bool = false
    private var speechAuthorizationTask: Task<Bool, Never>?
    private var pendingVoiceNote: String?
    private var isRecordingStartInProgress: Bool = false
    private var recordingStartTask: Task<Void, Never>?
    private var hasRetriedStartForSession: Bool = false
    private var currentPressSessionId: UUID?
    private var accumulatedTranscription: String = ""
    private let transcriptionMerger = TranscriptionMerger()
    private let textPostProcessor = TextPostProcessor()
    
    private actor ProcessingFilePathsGuard {
        private var processingFilePaths = Set<String>()
        
        func contains(_ filePath: String) -> Bool {
            return processingFilePaths.contains(filePath)
        }
        
        func insert(_ filePath: String) -> Bool {
            if processingFilePaths.contains(filePath) {
                return false
            }
            processingFilePaths.insert(filePath)
            return true
        }
        
        func remove(_ filePath: String) {
            processingFilePaths.remove(filePath)
        }
    }
    
    private let processingFilePathsGuard = ProcessingFilePathsGuard()
    
    private let clipboardService: ClipboardServiceProtocol
    private let speechService: SpeechServiceProtocol
    private let bookmarkService: BookmarkService
    private let offlineQueue: OfflineQueueService
    private let logger = LoggerService.shared
    
    init(
        clipboardService: ClipboardServiceProtocol = ClipboardService.shared,
        speechService: SpeechServiceProtocol = SpeechService.shared,
        bookmarkService: BookmarkService = BookmarkService(),
        offlineQueue: OfflineQueueService = .shared
    ) {
        self.clipboardService = clipboardService
        self.speechService = speechService
        self.bookmarkService = bookmarkService
        self.offlineQueue = offlineQueue
    }
    
    
    func onAppear() {
        logger.info("ShareView появился на экране", category: .ui)
        
        guard !AppTestHostContext.isUnitTestHostedMainApp else { return }
        
        Task(priority: .userInitiated) {
            if let concrete = speechService as? SpeechService {
                async let prewarmTask: Void = {
                    await concrete.prewarmAudioSession()
                    await concrete.prewarmAudioEngine()
                }()
                
                let granted = await ensureSpeechAuthorization()
                if granted {
                    await prewarmTask
                    logger.info("Audio prewarm completed after authorization", category: .speech)
                } else {
                    await prewarmTask
                    logger.info("Audio prewarm completed (authorization pending)", category: .speech)
                }
            }
        }
    }
    
    
    /// Загружает последний файл из Share Extension для показа превью
    /// Используется для отображения контента, который был добавлен через Share Extension
    func loadLastSharedItemIfAny() {
        guard contentPreview == nil else { 
            logger.debug("contentPreview уже установлен, пропускаем loadLastSharedItemIfAny", category: .ui)
            return 
        }
        guard let last = SharedUserDefaults.getLastSharedItem() else { 
            logger.debug("Нет последнего элемента из Share Extension", category: .ui)
            return 
        }
        let path = last.filePath
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.warning("Файл из Share Extension отсутствует: \(url.path)", category: .ui)
            SharedUserDefaults.clearLastSharedItem()
            return
        }
        
        Task {
            logger.info("Загрузка файла из Share Extension для показа в contentPreview: \(url.path)", category: .ui)
            
            let tempFileURL: URL?
            do {
                let fileData = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: url)
                }.value
                
                tempFileURL = FileService.shared.saveToTemporaryDirectory(data: fileData, fileName: url.lastPathComponent)
                if tempFileURL == nil {
                    logger.error("Не удалось сохранить копию файла в временной директории", category: .ui)
                } else {
                    logger.info("Файл скопирован в временную директорию: \(tempFileURL!.path)", category: .ui)
                }
            } catch {
                logger.error("Error чтения файла для копирования: \(error)", category: .ui)
                tempFileURL = nil
            }
            
            let fileURLToUse = tempFileURL ?? url
            
            if ["txt", "md", "log"].contains(ext) {
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        try Data(contentsOf: fileURLToUse)
                    }.value
                    if let text = String(data: data, encoding: .utf8) {
                        await MainActor.run {
                            contentPreview = ClipboardContent(type: .text, text: text, url: nil, image: nil, fileURL: fileURLToUse)
                            logger.info("Загружен текстовый файл из Share Extension", category: .ui)
                        }
                    }
                } catch {
                    logger.error("Error чтения текстового файла: \(error)", category: .ui)
                }
            } else if ["jpg", "jpeg", "png"].contains(ext) {
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        try Data(contentsOf: fileURLToUse)
                    }.value
                    if let img = UIImage(data: data) {
                        await MainActor.run {
                            contentPreview = ClipboardContent(type: .image, text: nil, url: nil, image: img, fileURL: fileURLToUse)
                            logger.info("Загружено изображение из Share Extension", category: .ui)
                        }
                    }
                } catch {
                    logger.error("Error чтения изображения: \(error)", category: .ui)
                }
            } else if ext == "url" {
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        try Data(contentsOf: fileURLToUse)
                    }.value
                    if let txt = String(data: data, encoding: .utf8), let u = URL(string: txt.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        await MainActor.run {
                            contentPreview = ClipboardContent(type: .url, text: nil, url: u, image: nil, fileURL: fileURLToUse)
                            logger.info("Загружен URL из Share Extension", category: .ui)
                        }
                    }
                } catch {
                    logger.error("Error чтения URL файла: \(error)", category: .ui)
                }
            } else {
                await MainActor.run {
                    contentPreview = ClipboardContent(type: .unknown, text: url.lastPathComponent, url: nil, image: nil, fileURL: fileURLToUse)
                    logger.info("Загружен файл из Share Extension", category: .ui)
                }
            }
            await MainActor.run {
            SharedUserDefaults.clearLastSharedItem()
            }
        }
    }
    
    private func ensureSpeechAuthorization() async -> Bool {
        if await MainActor.run(body: { hasSpeechAuthorization }) {
            return true
        }
        
        if let existingTask = await MainActor.run(body: { speechAuthorizationTask }) {
            return await existingTask.value
        }
        
        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            let granted = await self.speechService.requestAuthorization()
            
            await MainActor.run {
                if granted {
                    self.hasSpeechAuthorization = true
                }
                self.speechAuthorizationTask = nil
            }
            
            return granted
        }
        
        await MainActor.run {
            speechAuthorizationTask = task
        }
        
        return await task.value
    }
    
    
    /// Преобразует технические ошибки в понятные сообщения для пользователя
    private func friendlyErrorMessage(for error: Error, fallback: String) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .httpError(let status) where status == 429:
                logger.warning("Получен ответ 429 (rate limit) при загрузке контента", category: .network)
                return "Сервер временно ограничил количество запросов. Подождите немного и попробуйте снова."
            case .serverError(let message) where message.lowercased().contains("limit"):
                logger.warning("Сервер сообщил об ограничении: \(message)", category: .network)
                return "Сервер сообщил о превышении лимита. Попробуйте другой запрос или повторите позже."
            default:
                break
            }
        }
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
            logger.warning("Таймаут при загрузке контента", category: .network)
            return "Не удалось дождаться ответа сервера. Проверьте соединение и попробуйте снова."
        }
        
        return fallback
    }
    
    
    /// Начало long press: запуск записи голоса с проверкой разрешений
    func handleLongPressStarted() {
        if isRecording {
            logger.warning("Повторный long press во время записи — игнор", category: .speech)
            return
        }
        if isRecordingStartInProgress {
            logger.warning("Запуск записи уже выполняется — игнор повторного старта", category: .speech)
            return
        }
        logger.info("Long press начался, запуск записи", category: .speech)
        
        currentPressSessionId = UUID()
        hasRetriedStartForSession = false
        
            recordingStartTask = Task {
            isRecordingStartInProgress = true
            defer { isRecordingStartInProgress = false }
            pendingVoiceNote = nil
            
            await MainActor.run {
                wasSwipeDown = false
                transcription = ""
                accumulatedTranscription = ""
            }
            
            let pressStartedAt = Date()
            
            let authorized = await ensureSpeechAuthorization()
            if !authorized {
                await MainActor.run {
                    toast = .error("Нет разрешения на микрофон")
                    logger.error("Нет разрешений для записи", category: .speech)
                }
                return
            }
            
            do {
            
                try await speechService.startRecording(
                    onPartialResult: { [weak self] partialText in
                    guard let self else { return }
                    Task(priority: .userInitiated) {
                        let oldAccumulated = await MainActor.run { self.accumulatedTranscription }
                        
                        var accumulatedCopy = oldAccumulated
                        let processed = self.transcriptionMerger.processPartialResult(
                            accumulated: &accumulatedCopy,
                            new: partialText,
                            textPostProcessor: self.textPostProcessor,
                            logger: self.logger
                        )
                        let finalAccumulated = accumulatedCopy
                        
                        if let processed = processed {
                            await MainActor.run {
                                self.accumulatedTranscription = finalAccumulated
                                self.transcription = processed
                            }
                            
                            if oldAccumulated.isEmpty || processed.count > oldAccumulated.count {
                                let wordCount = processed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                                if oldAccumulated.isEmpty {
                                    self.logger.info("Получен первый результат распознавания: '\(processed.prefix(50))...', длина \(processed.count) символов, слов: \(wordCount)", category: .speech)
                                } else {
                                    let added = processed.count - oldAccumulated.count
                                    self.logger.debug("Обновлен накопленный текст: добавлено \(added) символов, итого \(processed.count) символов", category: .speech)
                                }
                            }
                        }
                    }
                    },
                    taskHint: .dictation,
                    timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForDictation
                )
                
                await MainActor.run {
                    isRecording = true
                    recordingStartTime = Date()
                }
                let ms = Int(Date().timeIntervalSince(pressStartedAt) * 1000)
                logger.info("Запись голоса началась, задержка \(ms)мс, сессия \(currentPressSessionId?.uuidString ?? "неизвестна")", category: .speech)
                
                if ms > 500 {
                    logger.warning("Высокая задержка начала записи: \(ms)мс (ожидается менее 500мс)", category: .speech)
                } else {
                    logger.info("Задержка начала записи в норме: \(ms)мс", category: .speech)
                }
            } catch {
                let sessionId = currentPressSessionId
                
                logger.warning("Error при начале записи (ShareViewModel): \(error)", category: .speech)
                
                if let apiError = error as? APIError,
                   case .serverError(let message) = apiError,
                   message.contains("Запись уже активна") {
                    logger.warning("Обнаружена ошибка 'Запись уже активна' (ShareViewModel), принудительно сбрасываем состояние", category: .speech)
                    speechService.cancelRecording()
                    try? await Task.sleep(nanoseconds: 500_000_000)

                    
                    if sessionId == currentPressSessionId,
                       !hasRetriedStartForSession {
                        hasRetriedStartForSession = true
                        logger.info("Автоматический перезапуск записи после ошибки 'Запись уже активна' (ShareViewModel)", category: .speech)
                        
            do {
                try await speechService.startRecording(
                    onPartialResult: { [weak self] partialText in
                    guard let self else { return }
                    Task(priority: .userInitiated) {
                        let oldAccumulated = await MainActor.run { self.accumulatedTranscription }
                        
                        var accumulatedCopy = oldAccumulated
                        let processed = self.transcriptionMerger.processPartialResult(
                            accumulated: &accumulatedCopy,
                            new: partialText,
                            textPostProcessor: self.textPostProcessor,
                            logger: self.logger
                        )
                        let finalAccumulated = accumulatedCopy
                        
                        if let processed = processed {
                            await MainActor.run {
                                self.accumulatedTranscription = finalAccumulated
                                self.transcription = processed
                            }
                            
                            if oldAccumulated.isEmpty || processed.count > oldAccumulated.count {
                                let wordCount = processed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                                if oldAccumulated.isEmpty {
                                    self.logger.info("Получен первый результат распознавания: '\(processed.prefix(50))...', длина \(processed.count) символов, слов: \(wordCount)", category: .speech)
                                } else {
                                    let added = processed.count - oldAccumulated.count
                                    self.logger.debug("Обновлен накопленный текст: добавлено \(added) символов, итого \(processed.count) символов", category: .speech)
                                }
                            }
                        }
                    }
                    },
                    taskHint: .dictation,
                    timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForDictation
                )
                
                await MainActor.run {
                                isRecording = true
                            }
                            
                            logger.info("Автоматический перезапуск записи успешен (ShareViewModel)", category: .speech)
            } catch {
                            await MainActor.run {
                                isRecording = false
                                logger.error("Error автоматического перезапуска записи: \(error)", category: .speech)
                    toast = .error("Error записи голоса")
                            }
                        }
                    } else {
                        if sessionId != currentPressSessionId {
                            logger.debug("Перезапуск пропущен: пользователь отпустил кнопку (ShareViewModel)", category: .speech)
                        } else if hasRetriedStartForSession {
                            logger.debug("Перезапуск пропущен: уже был перезапуск в этой сессии (ShareViewModel)", category: .speech)
                        }
                        
                        await MainActor.run {
                    isRecording = false
                logger.error("Error начала записи: \(error)", category: .speech)
                            toast = .error("Error записи голоса")
                        }
                    }
                } else {
                    logger.warning("Error распознавания (не 'Запись уже активна'), пытаемся перезапустить запись (ShareViewModel)", category: .speech)
                    speechService.cancelRecording()
                    try? await Task.sleep(nanoseconds: 200_000_000)

                    
                    if sessionId == currentPressSessionId,
                       !hasRetriedStartForSession {
                        hasRetriedStartForSession = true
                        logger.info("Автоматический перезапуск записи после ошибки распознавания (ShareViewModel)", category: .speech)
                        
                        do {
                            try await speechService.startRecording(
                                onPartialResult: { [weak self] partialText in
                                    guard let self else { return }
                                    Task(priority: .userInitiated) {
                                        let oldAccumulated = await MainActor.run { self.accumulatedTranscription }
                                        
                                        var accumulatedCopy = oldAccumulated
                                        let processed = self.transcriptionMerger.processPartialResult(
                                            accumulated: &accumulatedCopy,
                                            new: partialText,
                                            textPostProcessor: self.textPostProcessor,
                                            logger: self.logger
                                        )
                                        let finalAccumulated = accumulatedCopy
                                        
                                        if let processed = processed {
                                            await MainActor.run {
                                                self.accumulatedTranscription = finalAccumulated
                                                self.transcription = processed
                                            }
                                            
                                            if oldAccumulated.isEmpty || processed.count > oldAccumulated.count {
                                                let wordCount = processed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                                                if oldAccumulated.isEmpty {
                                                    self.logger.info("Получен первый результат распознавания: '\(processed.prefix(50))...', длина \(processed.count) символов, слов: \(wordCount)", category: .speech)
                                            } else {
                                                    let added = processed.count - oldAccumulated.count
                                                    self.logger.debug("Обновлен накопленный текст: добавлено \(added) символов, итого \(processed.count) символов", category: .speech)
                                                }
                                            }
                                        }
                                    }
                                },
                                taskHint: .dictation,
                                timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForDictation
                            )
                            
                await MainActor.run {
                                isRecording = true
                            }
                            
                            logger.info("Автоматический перезапуск записи успешен после ошибки распознавания (ShareViewModel)", category: .speech)
                        } catch {
                            await MainActor.run {
                                isRecording = false
                                logger.error("Error автоматического перезапуска записи после ошибки распознавания: \(error)", category: .speech)
                    toast = .error("Error записи голоса")
                            }
                        }
                    } else {
                        await MainActor.run {
                    isRecording = false
                            logger.error("Error начала записи: \(error)", category: .speech)
                            toast = .error("Error записи голоса")
                        }
                    }
                }
            }
        }
    }
    
    /// Окончание long press: остановка записи и получение финального результата
    func handleLongPressEnded() {
        logger.info("Окончание long press", category: .speech)
        
        currentPressSessionId = nil
        
        if wasSwipeDown {
            wasSwipeDown = false
            isRecording = false
            transcription = ""
            accumulatedTranscription = ""
            pendingVoiceNote = nil
            return
        }
        
        let isTooShortPress: Bool = {
            if let start = recordingStartTime {
                return Date().timeIntervalSince(start) < 0.4
            }
            return true
        }()
        if isRecordingStartInProgress || isTooShortPress {
            logger.info("Завершение long press во время старта или слишком короткое нажатие — отмена записи", category: .speech)
            speechService.cancelRecording()
            isRecording = false
            transcription = ""
            accumulatedTranscription = ""
            pendingVoiceNote = nil
            isProcessingLongPressEnd = false
            return
        }
        
        if isProcessingLongPressEnd {
            logger.info("Обработка long press end уже идет", category: .ui)
            return
        }
        
        isProcessingLongPressEnd = true
        
        Task {
            let finalTranscription = await speechService.stopRecording()
            
            await MainActor.run {
                isRecording = false
                
                let finalText = finalTranscription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let accumulatedText = accumulatedTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
                let currentTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                
                logger.info("Завершение записи: финальный текст \(finalText.isEmpty ? "пуст" : "\(finalText.count) символов"), накопленный текст \(accumulatedText.isEmpty ? "пуст" : "\(accumulatedText.count) символов"), текущий текст \(currentTranscription.isEmpty ? "пуст" : "\(currentTranscription.count) символов")", category: .speech)
                
                let rawTextToUse: String
                if !finalText.isEmpty && !accumulatedText.isEmpty {
                    if let merged = self.transcriptionMerger.merge(accumulated: accumulatedText, new: finalText) {
                        rawTextToUse = merged
                        logger.info("Объединены финальный и накопленный тексты через merge: \(merged.count) символов", category: .speech)
                    } else {
                        rawTextToUse = accumulatedText.count > finalText.count ? accumulatedText : finalText
                        logger.info("Merge не сработал, используем более длинный текст: \(rawTextToUse.count) символов", category: .speech)
                    }
                } else if !accumulatedText.isEmpty && accumulatedText.count > finalText.count {
                    rawTextToUse = accumulatedText
                    logger.info("Используем накопленный текст (длиннее финального): \(accumulatedText.count) символов", category: .speech)
                } else if !finalText.isEmpty {
                    rawTextToUse = finalText
                    logger.info("Используем финальный текст: \(finalText.count) символов", category: .speech)
                } else if !accumulatedText.isEmpty {
                    rawTextToUse = accumulatedText
                    logger.info("Используем накопленный текст (финальный пуст): \(accumulatedText.count) символов", category: .speech)
                } else if !currentTranscription.isEmpty {
                    rawTextToUse = currentTranscription
                    logger.info("Используем текущий текст (финальный и накопленный пусты): \(currentTranscription.count) символов", category: .speech)
                } else {
                    transcription = ""
                    accumulatedTranscription = ""
                    pendingVoiceNote = nil
                    logger.warning("Все тексты пусты, речь не распознана", category: .speech)
                    GlobalToastManager.shared.showError("Речь не распознана. Попробуйте ещё раз.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.isProcessingLongPressEnd = false
                    }
                    return
                }
                
                let textToUse = self.textPostProcessor.process(rawTextToUse)
                
                if textToUse != rawTextToUse {
                    logger.info("Текст улучшен постобработкой: было \(rawTextToUse.count) символов, стало \(textToUse.count) символов", category: .speech)
                }
                
                transcription = textToUse
                accumulatedTranscription = textToUse
                pendingVoiceNote = textToUse
                
                logger.info("Итоговая голосовая заметка сохранена (после постобработки): \(textToUse.count) символов", category: .speech)
                
                transcription = ""
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.isProcessingLongPressEnd = false
                }
            }
        }
    }
    
    /// Swipe вверх: отправка контента на сервер или в офлайн очередь
    func handleSwipeUp() {
        if isProcessingLongPressEnd {
            logger.info("Swipe вверх игнорируется (обработка long press end)", category: .ui)
            return
        }
        
        if isUploadingContent {
            logger.warning("Swipe вверх игнорируется (загрузка уже идет)", category: .ui)
            return
        }
        
        if isUploading {
            logger.warning("Swipe вверх игнорируется (isUploading=true)", category: .ui)
            return
        }
        
        logger.info("Swipe вверх - отправка контента", category: .ui)
        Task { @MainActor in
            let voiceNoteToUpload: String?
            if let pending = pendingVoiceNote {
                logger.info("Используем pendingVoiceNote", category: .fileOperation)
                voiceNoteToUpload = pending
            } else {
                let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    logger.info("Используем transcription", category: .fileOperation)
                    voiceNoteToUpload = trimmed
                } else {
                    logger.warning("И pendingVoiceNote, и transcription пусты, voiceNoteToUpload будет nil", category: .fileOperation)
                    voiceNoteToUpload = nil
                }
            }
            
            let savedVoiceNote = voiceNoteToUpload
            
            logger.info("Вызов uploadContent с голосовой заметкой: \(savedVoiceNote?.isEmpty == false ? "\(savedVoiceNote!.count) символов" : "отсутствует")", category: .fileOperation)
            uploadContent(voiceNote: savedVoiceNote)
            
            pendingVoiceNote = nil
        }
    }
    
    /// Swipe вверх после завершения записи: ждет завершения обработки long press end
    func handleSwipeUpAfterRecording() {
        if isProcessingLongPressEnd {
            Task {
                var attempts = 0
                while isProcessingLongPressEnd && attempts < 20 {
                    try? await Task.sleep(nanoseconds: 100_000_000)

                    attempts += 1
                }
                await MainActor.run {
                    if !self.isProcessingLongPressEnd {
                        self.handleSwipeUp()
                    } else {
                        self.logger.warning("Таймаут ожидания завершения long press end, все равно вызываем handleSwipeUp()", category: .ui)
                        self.handleSwipeUp()
                    }
                }
            }
        } else {
            handleSwipeUp()
        }
    }
    
    /// Swipe вниз: отмена записи или очистка контента
    func handleSwipeDown() {
        guard !isSwipeDownProcessing else {
            logger.debug("Swipe вниз уже обрабатывается, пропускаем", category: .ui)
            return
        }
        
        isSwipeDownProcessing = true
        defer { isSwipeDownProcessing = false }
        
        logger.info("Swipe вниз", category: .ui)
        
        if isRecording {
            logger.info("Сброс записи голоса", category: .speech)
            wasSwipeDown = true
            speechService.cancelRecording()
            isRecording = false
            transcription = ""
            accumulatedTranscription = ""
            pendingVoiceNote = nil
        } else if contentPreview != nil || !transcription.isEmpty || currentClipboardContent != nil {
            logger.info("Очистка подготовленного контента", category: .ui)
            withAnimation(.easeInOut(duration: Constants.UI.animationDuration)) {
                contentPreview = nil
                contentPreviewOffset = 0
                transcription = ""
                showPasteButton = false
            }
            currentClipboardContent = nil
            pendingVoiceNote = nil
        } else {
            logger.info("Закрытие экрана Share", category: .ui)
            shouldDismiss = true
        }
    }
    
    func handleTapOnEmptyArea(at location: CGPoint) {
        logger.info("Tap на пустую область в точке: \(location)", category: .ui)
        
        guard contentPreview == nil else {
            logger.info("Контент уже есть, игнорируем tap", category: .ui)
            return
        }
        
        if clipboardService.hasContent() {
            pasteButtonPosition = location
            showPasteButton = true
            logger.info("Показываем кнопку Вставить в точке: \(location)", category: .ui)
        } else {
            logger.warning("Буфер обмена пустой, кнопка не показана", category: .ui)
            GlobalToastManager.shared.showError("Буфер обмена пустой")
        }
    }
    
    func handleTapOnTranscriptionField(at location: CGPoint) {
        logger.info("Tap на поле транскрипции в точке: \(location)", category: .ui)
        
        guard !isRecording else {
            logger.info("Идет запись, игнорируем tap", category: .ui)
            return
        }
        
        guard contentPreview == nil else {
            logger.info("Контент уже есть, игнорируем tap", category: .ui)
            return
        }
        
        if clipboardService.hasContent() {
            pasteButtonPosition = location
            showPasteButton = true
            logger.info("Показываем кнопку Вставить после тапа на поле транскрипции в точке: \(location)", category: .ui)
        } else {
            logger.warning("Буфер обмена пустой, кнопка не показана", category: .ui)
            GlobalToastManager.shared.showError("Буфер обмена пустой")
        }
    }
    
    func handlePasteButtonTap() {
        logger.info("Кнопка Вставить нажата", category: .ui)
        
        if let content = clipboardService.getClipboardContent() {
            contentPreview = content
            currentClipboardContent = content
            logger.info("Буфер прочитан: \(content.type)", category: .ui)
            showPasteButton = false
            return
        }
        
        Task {
            if let content = await clipboardService.getClipboardContentAsync() {
                await MainActor.run {
                    contentPreview = content
                    currentClipboardContent = content
                    logger.info("Буфер прочитан асинхронно: \(content.type)", category: .ui)
                    showPasteButton = false
                }
        } else {
                await MainActor.run {
            logger.warning("Буфер обмена пустой", category: .ui)
            GlobalToastManager.shared.showError("Буфер обмена пустой")
        showPasteButton = false
                }
            }
        }
    }
    
    func handleGestureEnded(translation: CGSize) {
        if isRecording || isProcessingLongPressEnd || isUploadingContent {
            return
        }
        
        if translation.height < -30 {
            handleSwipeUp()
        } else if translation.height > 30 {
            handleSwipeDown()
        }
    }
    
    
    /// Загружает контент на сервер или в офлайн очередь при ошибке сети
    /// Защищено от параллельного выполнения через isUploadingContent флаг
    @MainActor
    func uploadContent(voiceNote: String?) {
        logger.info("uploadContent вызван с voiceNote: \(voiceNote ?? "nil"), длина: \(voiceNote?.count ?? 0)", category: .fileOperation)
        
        if isUploadingContent {
            logger.warning("Загрузка уже идет (isUploadingContent=true), игнорируем повторный вызов", category: .fileOperation)
            return
        }
        
        if isUploading {
            logger.warning("Загрузка уже идет (isUploading=true), игнорируем повторный вызов", category: .fileOperation)
            return
        }
        
        let hasContent = contentPreview != nil
        let hasVoiceNote = voiceNote != nil && !voiceNote!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        guard hasContent || hasVoiceNote else {
            logger.warning("Попытка загрузки без контента, игнорируем", category: .fileOperation)
            GlobalToastManager.shared.showError("Нет контента для загрузки")
            return
        }
        
        isUploadingContent = true
        
        let fileNameForNotification: String = {
            if let content = contentPreview {
                switch content.type {
                case .text:
                    if let text = content.text, !text.isEmpty {
                        let preview = text.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines)
                        return preview.isEmpty ? "текст" : "\"\(preview)\(text.count > 30 ? "..." : "")\""
                    }
                    return "текст"
                case .url:
                    if let url = content.url {
                        if let host = url.host, !host.isEmpty {
                            return host
                        } else if !url.path.isEmpty {
                            return URL(fileURLWithPath: url.path).lastPathComponent
                        }
                    }
                    return "ссылка"
                case .image: return "изображение"
                case .unknown:
                    if let fileURL = content.fileURL {
                        return fileURL.lastPathComponent
                    }
                    if let text = content.text, !text.isEmpty {
                        return text.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return "файл"
                }
            } else if let voiceNote = voiceNote, !voiceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let preview = voiceNote.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines)
                return preview.isEmpty ? "голосовая заметка" : "\"\(preview)\(voiceNote.count > 30 ? "..." : "")\""
            }
            return "контент"
        }()
        
        let contentToUpload = contentPreview
        let savedVoiceNote = voiceNote
        
        if savedVoiceNote != nil {
            logger.info("voiceNote сохранен перед очисткой состояния", category: .fileOperation)
        } else {
            logger.warning("voiceNote = nil при входе в uploadContent", category: .fileOperation)
        }
        
        isUploading = false
        contentPreview = nil
        currentClipboardContent = nil
        transcription = ""
        pendingVoiceNote = nil
        contentPreviewOffset = 0
        isRecording = false
        
        Task { @MainActor in
            
            var currentProcessingFilePath: String? = nil
            
            do {
                let fileURL: URL
                let contentType: ContentType
                var summary: String?
                var voiceNotePayload: String?
                var isFileFromShareExtension: Bool = false
                
                if let content = contentToUpload {
                    if let existingFileURL = content.fileURL,
                       FileManager.default.fileExists(atPath: existingFileURL.path) {
                        fileURL = existingFileURL
                        isFileFromShareExtension = true
                        
                        let fileInQueue = await offlineQueue.isFileInQueue(filePath: fileURL.path)
                        if fileInQueue {
                            if let note = savedVoiceNote, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let updated = await MainActor.run {
                                    offlineQueue.updateQueuedItem(filePath: fileURL.path, voiceNote: note, summary: nil)
                                }
                                isUploadingContent = false
                                GlobalToastManager.shared.showSuccess(updated ? "Заметка добавлена к файлу в очереди" : "Файл уже в очереди на загрузку")
                                return
                            } else {
                                isUploadingContent = false
                                GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" уже в очереди на загрузку")
                                return
                            }
                        }
                        
                        let isProcessingInQueue = await offlineQueue.isFileProcessing(filePath: fileURL.path)
                        if isProcessingInQueue {
                            if let note = savedVoiceNote, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let updated = await MainActor.run {
                                    offlineQueue.updateQueuedItem(filePath: fileURL.path, voiceNote: note, summary: nil)
                                }
                                isUploadingContent = false
                                GlobalToastManager.shared.showSuccess(updated ? "Заметка добавлена к файлу в очереди" : "Контент уже обрабатывается")
                                return
                            } else {
                                isUploadingContent = false
                                GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" уже обрабатывается")
                                return
                            }
                        }
                        
                        let wasInserted = await processingFilePathsGuard.insert(fileURL.path)
                        
                        if !wasInserted {
                            isUploadingContent = false
                            
                            GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" уже обрабатывается")
                            
                            
                            return
                        }
                        
                        currentProcessingFilePath = fileURL.path
                        
                        let fileInQueueAfterInsert = await offlineQueue.isFileInQueue(filePath: fileURL.path)
                        if fileInQueueAfterInsert {
                            await processingFilePathsGuard.remove(fileURL.path)
                            currentProcessingFilePath = nil
                            
                            if let note = savedVoiceNote, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let updated = await MainActor.run {
                                    offlineQueue.updateQueuedItem(filePath: fileURL.path, voiceNote: note, summary: nil)
                                }
                                isUploadingContent = false
                                GlobalToastManager.shared.showSuccess(updated ? "Заметка добавлена к файлу в очереди" : "Content is already queued на загрузку")
                                return
                            } else {
                                isUploadingContent = false
                                GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" уже в очереди на загрузку")
                                return
                            }
                        }
                    } else {
                        if let originalFileURL = contentToUpload?.fileURL {
                            logger.warning("Файл из contentToUpload не найден: \(originalFileURL.path), проверяем contentPreview", category: .fileOperation)
                            
                            if let previewFileURL = contentPreview?.fileURL,
                               FileManager.default.fileExists(atPath: previewFileURL.path) {
                                do {
                                    let fileData = try Data(contentsOf: previewFileURL)
                                    guard let tempURL = FileService.shared.saveToTemporaryDirectory(data: fileData, fileName: originalFileURL.lastPathComponent) else {
                                        throw APIError.serverError(message: "Не удалось сохранить файл")
                                    }
                                    fileURL = tempURL
                                    isFileFromShareExtension = true
                                    logger.info("Файл скопирован из contentPreview: \(previewFileURL.path) -> \(tempURL.path), размер: \(fileData.count) байт", category: .fileOperation)
                                } catch {
                                    logger.error("Error копирования файла из contentPreview: \(error)", category: .fileOperation)
                                    throw APIError.serverError(message: "Не удалось скопировать файл из contentPreview: \(error.localizedDescription)")
                                }
                            } else {
                                logger.error("Оригинальный файл не найден ни в contentToUpload (\(originalFileURL.path)), ни в contentPreview (\(contentPreview?.fileURL?.path ?? "nil"))", category: .fileOperation)
                                throw APIError.serverError(message: "Файл не найден: \(originalFileURL.lastPathComponent)")
                            }
                        } else {
                            fileURL = try await saveClipboardContentToFile(content: content)
                        }
                        
                        let fileInQueueBeforeInsert = await offlineQueue.isFileInQueue(filePath: fileURL.path)
                        if fileInQueueBeforeInsert {
                            isUploadingContent = false
                            
                            FileService.shared.deleteFile(at: fileURL)
                            
                            GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" уже в очереди на загрузку")
                            
                            
                            return
                        }
                        
                        let isProcessingInQueue = await offlineQueue.isFileProcessing(filePath: fileURL.path)
                        if isProcessingInQueue {
                            isUploadingContent = false
                            
                            FileService.shared.deleteFile(at: fileURL)
                            
                            GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" уже обрабатывается")
                            
                            
                            return
                        }
                        
                        let wasInserted = await processingFilePathsGuard.insert(fileURL.path)
                        if wasInserted {
                            currentProcessingFilePath = fileURL.path
                            logger.info("Файл добавлен в Set обрабатываемых: \(fileURL.path)", category: .fileOperation)
                        } else {
                            logger.warning("Файл уже обрабатывается при сохранении (возможно, race condition), пропускаем загрузку: \(fileURL.path)", category: .fileOperation)
                            
                            FileService.shared.deleteFile(at: fileURL)
                            
                            isUploadingContent = false
                            
                            GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" уже обрабатывается")
                            
                            
                            return
                        }
                    }
                    
                    contentType = determineContentType(for: content.type, fileURL: fileURL)
                    logger.info("Определен contentType: \(contentType.rawValue) для файла \(fileURL.lastPathComponent)", category: .fileOperation)
                    
                    if let voiceNote = savedVoiceNote?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !voiceNote.isEmpty {
                        voiceNotePayload = voiceNote
                        logger.info("Голосовая заметка будет передана на сервер: \(voiceNote.count) символов, сервер сгенерирует описание автоматически", category: .fileOperation)
                    } else {
                        voiceNotePayload = nil
                        summary = nil
                        logger.warning("Голосовая заметка отсутствует или пуста, сервер сгенерирует описание автоматически", category: .fileOperation)
                    }
                } else if let voiceNote = savedVoiceNote, !voiceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let hasContentPreview = await MainActor.run { contentPreview != nil }
                    if hasContentPreview {
                        logger.error("contentToUpload == nil, но contentPreview != nil", category: .fileOperation)
                        throw APIError.serverError(message: "Error: файл был выбран, но contentToUpload потерялся. Не создаем текстовый файл из voiceNote.")
                    }
                    
                    logger.info("Создание текстовой заметки из голоса", category: .fileOperation)
                    let data = voiceNote.data(using: .utf8) ?? Data()
                    guard let url = FileService.shared.saveToTemporaryDirectory(data: data, fileName: "voice_note.txt") else {
                        throw APIError.serverError(message: "Не удалось сохранить голосовую заметку")
                    }
                    fileURL = url
                    contentType = .text
                    voiceNotePayload = voiceNote
                    summary = nil
                    
                    let wasInserted = await processingFilePathsGuard.insert(fileURL.path)
                    if wasInserted {
                        currentProcessingFilePath = fileURL.path
                    } else {
                        currentProcessingFilePath = fileURL.path
                    }
                } else {
                    logger.error("Нет контента после проверки", category: .fileOperation)
                    throw APIError.serverError(message: "Нет контента для загрузки")
                }
                
                if !isFileFromShareExtension {
                    let fileInQueue = await offlineQueue.isFileInQueue(filePath: fileURL.path)
                    if fileInQueue {
                        await processingFilePathsGuard.remove(fileURL.path)
                        currentProcessingFilePath = nil
                        
                        isUploadingContent = false
                        
                        GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" уже в очереди на загрузку")
                        
                        FileService.shared.deleteFile(at: fileURL)
                        
                        return
                    }
                }
                
                do {
                    if contentType == .audio && voiceNotePayload == nil {
                        logger.error("voiceNotePayload = nil для аудио файла", category: .fileOperation)
                    }
                    
                    let success = try await bookmarkService.createBookmark(
                        filePath: fileURL.path,
                        voiceNote: voiceNotePayload,
                        summary: summary
                    )
                    
                    if success {
                        await processingFilePathsGuard.remove(fileURL.path)
                        currentProcessingFilePath = nil
                        
                        isUploadingContent = false
                        
                        GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" успешно сохранен")
                        
                        logger.info("Контент успешно загружен на сервер", category: .fileOperation)
                        
                        if !isFileFromShareExtension {
                        FileService.shared.deleteFile(at: fileURL)
                        }
                    } else {
                        await processingFilePathsGuard.remove(fileURL.path)
                        currentProcessingFilePath = nil
                        throw APIError.serverError(message: "Загрузка не удалась")
                    }
                    
                } catch {
                    let finalFileURL: URL
                    if isFileFromShareExtension {
                        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.AppGroups.identifier),
                           fileURL.path.hasPrefix(appGroupURL.path) {
                            finalFileURL = fileURL
                        } else {
                            finalFileURL = try FileService.shared.copyToAppGroupContainer(from: fileURL)
                            FileService.shared.deleteFile(at: fileURL)
                        }
                    } else {
                        finalFileURL = try FileService.shared.copyToAppGroupContainer(from: fileURL)
                        FileService.shared.deleteFile(at: fileURL)
                    }
                    
                    let addedToQueue = offlineQueue.addToQueue(
                        filePath: finalFileURL.path,
                        voiceNote: voiceNotePayload,
                        summary: summary
                    )
                    
                    if addedToQueue {
                        await processingFilePathsGuard.remove(finalFileURL.path)
                        currentProcessingFilePath = nil
                        
                        isUploadingContent = false
                        
                        GlobalToastManager.shared.showSuccess("Контент \"\(fileNameForNotification)\" добавлен в очередь")
                    } else {
                        await processingFilePathsGuard.remove(finalFileURL.path)
                        currentProcessingFilePath = nil
                        throw APIError.serverError(message: "Не удалось добавить в очередь")
                    }
                }
                
            } catch {
                if let filePathToRemove = currentProcessingFilePath {
                    await processingFilePathsGuard.remove(filePathToRemove)
                    currentProcessingFilePath = nil
                }
                
                isUploadingContent = false
                
                let nsError = error as NSError
                let isTimeout = (nsError.domain == NSURLErrorDomain || nsError.domain == "kCFErrorDomainCFNetwork") && nsError.code == NSURLErrorTimedOut
                
                let fallback: String
                if isTimeout {
                    fallback = "Таймаут при загрузке \"\(fileNameForNotification)\". Файл добавлен в очередь и будет загружен автоматически при улучшении соединения."
                } else {
                    fallback = "Error загрузки \"\(fileNameForNotification)\": \(error.localizedDescription). Файл добавлен в очередь."
                }
                
                let message = friendlyErrorMessage(for: error, fallback: fallback)
                GlobalToastManager.shared.showError(message)
                logger.error("Error загрузки контента: \(error)", category: .fileOperation)
                
                if isTimeout {
                    logger.info("Таймаут при загрузке, файл должен быть добавлен в очередь автоматически", category: .fileOperation)
                }
            }
        }
    }
    
    private func saveClipboardContentToFile(content: ClipboardContent) async throws -> URL {
        let fileService = FileService.shared
        
        if let existingURL = content.fileURL,
           FileManager.default.fileExists(atPath: existingURL.path) {
            return existingURL
        }
        
        switch content.type {
        case .text:
            guard let text = content.text else {
                throw APIError.serverError(message: "Текст отсутствует")
            }
            let data = text.data(using: .utf8) ?? Data()
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let isHTML = trimmedText.hasPrefix("<!doctype") || trimmedText.hasPrefix("<html")
            let fileName = isHTML ? "webpage.html" : "text.txt"
            guard let url = fileService.saveToTemporaryDirectory(data: data, fileName: fileName) else {
                throw APIError.serverError(message: "Не удалось сохранить текст")
            }
            return url
            
        case .url:
            guard let url = content.url else {
                throw APIError.serverError(message: "URL отсутствует")
            }
            let data = url.absoluteString.data(using: .utf8) ?? Data()
            guard let fileURL = fileService.saveToTemporaryDirectory(data: data, fileName: "url.txt") else {
                throw APIError.serverError(message: "Не удалось сохранить URL")
            }
            return fileURL
            
        case .image:
            guard let image = content.image else {
                throw APIError.serverError(message: "Изображение отсутствует")
            }
            guard let imageData = fileService.compressImage(image) else {
                throw APIError.serverError(message: "Не удалось сжать изображение")
            }
            guard let url = fileService.saveToTemporaryDirectory(data: imageData, fileName: "image.jpg") else {
                throw APIError.serverError(message: "Не удалось сохранить изображение")
            }
            return url
            
        case .unknown:
            if let fileURL = content.fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                logger.info("Используем fileURL из contentPreview (тип unknown): \(fileURL.lastPathComponent)", category: .fileOperation)
                return fileURL
            }
            
            if let text = content.text, !text.isEmpty {
                let data = text.data(using: .utf8) ?? Data()
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let isHTML = trimmedText.hasPrefix("<!doctype") || trimmedText.hasPrefix("<html")
                
                let fileName: String
                if !isHTML && text.contains(".") && text.count < 100 {
                    fileName = text
                    logger.info("Используем имя файла из text: \(fileName)", category: .fileOperation)
                } else {
                    fileName = isHTML ? "webpage.html" : "file.txt"
                }
                
                guard let url = fileService.saveToTemporaryDirectory(data: data, fileName: fileName) else {
                    throw APIError.serverError(message: "Не удалось сохранить контент")
                }
                return url
            } else {
                throw APIError.serverError(message: "Неизвестный тип контента: нет данных для сохранения")
            }
        }
    }
    
    private func determineContentType(for clipboardType: ClipboardContent.ClipboardType, fileURL: URL? = nil) -> ContentType {
        if let fileURL = fileURL {
            let fileName = fileURL.lastPathComponent.lowercased()
            if fileName.hasSuffix(".html") || fileName.hasSuffix(".htm") {
                return .file
            }
        }
        
        switch clipboardType {
        case .text: return .text
        case .url: return .text
        case .image: return .image
        case .unknown: return .file
        }
    }
    
    private func resetState() {
        contentPreview = nil
        transcription = ""
        isRecording = false
        showPasteButton = false
        toast = nil
    }
    
    func cleanup() {
        logger.info("Cleanup ShareViewModel", category: .ui)
        
        if isRecording {
            logger.warning("Запись была активна при cleanup, принудительная остановка", category: .speech)
            speechService.cancelRecording()
            isRecording = false
            transcription = ""
        }
        
        isProcessingLongPressEnd = false
        wasSwipeDown = false
    }
    
}
