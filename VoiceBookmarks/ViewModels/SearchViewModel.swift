//
//  SearchViewModel.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import Combine
import SwiftUI

class SearchViewModel: ObservableObject {
    
    let searchService: any SearchServiceProviding
    let speechService: any SpeechServiceProtocol
    
    @Published var searchQuery: String = ""
    @Published var folders: [Folder] = []
    @Published var isLoading: Bool = false
    @Published var isRecording: Bool = false
    @Published var transcription: String = ""
    @Published var toast: ToastModifier.ToastItem?
    @Published var searchResults: [Bookmark] = []
    @Published var loadingMessage: String?
    @Published var currentDestination: SearchDestination?
    @Published var selectedFolder: Folder?
    @Published var showFileList: Bool = false
    @Published var showWebView: Bool = false
    @Published var commandHTML: String?
    @Published var selectedBookmark: Bookmark?
    
    private let logger = LoggerService.shared
    private var loadFoldersTask: Task<Void, Never>?
    
    private var currentPressSessionId: UUID?
    private var endDebounceTask: Task<Void, Never>?
    private var recordingWatchdogTask: Task<Void, Never>?
    private var receivedPartialForSession: Bool = false
    private var hasRetriedStartForSession: Bool = false
    private var startLatencyAt: Date?
    private var isRecordingStartInProgress: Bool = false
    private var accumulatedTranscription: String = ""
    private let transcriptionMerger = TranscriptionMerger()
    private let textPostProcessor = TextPostProcessor()
    
    init(
        searchService: any SearchServiceProviding,
        speechService: any SpeechServiceProtocol
    ) {
        self.searchService = searchService
        self.speechService = speechService
        
        guard !AppTestHostContext.isUnitTestHostedMainApp else { return }
        
        Task.detached(priority: .utility) { [weak speechService] in
            guard let service = speechService else { return }
            _ = await service.requestAuthorization()
            await service.prewarmAudioSession()
            await service.prewarmAudioEngine()
        }
    }
    
    func loadFolders() async {
        loadFoldersTask?.cancel()
        loadFoldersTask = Task {
            await MainActor.run {
                isLoading = true
                loadingMessage = "Загрузка папок..."
            }
            
            do {
                try Task.checkCancellation()
                let fetchedFolders = try await searchService.getFolders()
                
                try Task.checkCancellation()
                await MainActor.run {
                    if !Task.isCancelled {
                        folders = fetchedFolders
                        isLoading = false
                        loadingMessage = nil
                    }
                }
            } catch {
            await MainActor.run {
                    isLoading = false
                    loadingMessage = nil
                    logger.error("Ошибка загрузки папок: \(error)", category: .network)
                    toast = .error("Не удалось загрузить папки: \(error.localizedDescription)")
                }
            }
        }
        
        await loadFoldersTask?.value
    }
    
    func handleFolderTap(_ folder: Folder) {
        selectedFolder = folder
        Task {
            await loadFilesForFolder(folder)
        }
    }
    
    func loadFilesForFolder(_ folder: Folder) async {
        await MainActor.run {
            isLoading = true
            loadingMessage = "Загрузка файлов..."
        }
        
        let categoryName = folder.fullPath
        
        do {
            let result = try await searchService.getBookmarksForFolder(category: categoryName)
            let deduped = deduplicateBookmarks(result.bookmarks)
            
            await MainActor.run {
                selectedFolder = folder
                searchResults = deduped
                navigateToFileList(folder: folder, results: deduped)
                isLoading = false
                loadingMessage = nil
            }
        } catch {
            await MainActor.run {
                isLoading = false
                loadingMessage = nil
                logger.error("Ошибка загрузки файлов для папки: \(error)", category: .network)
                toast = .error("Не удалось загрузить файлы: \(error.localizedDescription)")
            }
        }
    }
    
    
    /// Удаляет дубликаты закладок: выбирает лучшую по приоритету (voiceNote > длина описания > время)
    /// Стратегия: группирует по ключу (hash > fileUrl > нормализованное имя), выбирает лучшую, объединяет summary и voiceNote
    private func deduplicateBookmarks(_ bookmarks: [Bookmark]) -> [Bookmark] {
        logger.info("deduplicateBookmarks: получено \(bookmarks.count) bookmark с сервера", category: .network)
        
        for (idx, b) in bookmarks.enumerated() {
            let hasVoice = b.voiceNote != nil && !b.voiceNote!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasSummary = b.summary != nil && !b.summary!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasVoice && hasSummary {
                logger.debug("ДО дедупликации [\(idx)]: fileName=\(b.fileName), voiceNote=\(b.voiceNote!.prefix(50))..., summary=\(b.summary!.prefix(50))...", category: .network)
            } else if hasVoice {
                logger.debug("ДО дедупликации [\(idx)]: fileName=\(b.fileName), voiceNote=\(b.voiceNote!.prefix(50))..., summary=отсутствует", category: .network)
            } else if hasSummary {
                logger.warning("ДО дедупликации [\(idx)]: fileName=\(b.fileName), voiceNote=отсутствует, summary=\(b.summary!.prefix(50))... (сервер не вернул voiceNote?)", category: .network)
            } else {
                logger.debug("ДО дедупликации [\(idx)]: fileName=\(b.fileName), voiceNote=отсутствует, summary=отсутствует", category: .network)
            }
        }
        
        var bestByKey: [String: Bookmark] = [:]
        
        func key(for b: Bookmark) -> String {
            if let hash = b.contentHash, !hash.isEmpty {
                let key = "hash:\(hash)"
                logger.debug("Дедупликация: key для \(b.fileName) = \(key) (по contentHash)", category: .network)
                return key
            }
            if let url = b.fileUrl, !url.isEmpty {
                let key = "url:\(url)"
                logger.debug("Дедупликация: key для \(b.fileName) = \(key) (по fileUrl)", category: .network)
                return key
            }
            let key = "name:\(normalizedName(b.fileName)):\(b.contentType.rawValue)"
            logger.debug("Дедупликация: key для \(b.fileName) = \(key) (по normalizedName)", category: .network)
            return key
        }
        
        func score(_ b: Bookmark) -> (Int, Int, TimeInterval) {
            let hasVoice = (b.voiceNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? 1 : 0
            let voiceLen = b.voiceNote?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0
            let ts = b.timestamp.timeIntervalSince1970
            return (hasVoice, voiceLen, ts)
        }
        
        func normalizedName(_ name: String) -> String {
            let lower = name.lowercased()
            let noExt = (lower as NSString).deletingPathExtension
            let parts = noExt.split(separator: "_").map(String.init)
            let trimmed = parts.drop { part in
                part.count <= 4 || part.range(of: #"^[0-9a-f\-]+$"#, options: .regularExpression) != nil
            }.joined(separator: "_")
            return trimmed.isEmpty ? noExt : trimmed
        }
        
        for b in bookmarks {
            let k = key(for: b)
            if let existing = bestByKey[k] {
                let existingScore = score(existing)
                let newScore = score(b)
                
                logger.debug("Дедупликация: key=\(k), existingScore=(hasVoice:\(existingScore.0), voiceLen:\(existingScore.1), ts:\(existingScore.2)), newScore=(hasVoice:\(newScore.0), voiceLen:\(newScore.1), ts:\(newScore.2))", category: .network)
                
                if existingScore.0 == 1 && newScore.0 == 0 {
                    logger.debug("Дедупликация: сохраняем existing (имеет voiceNote, новый нет), key=\(k)", category: .network)
                    bestByKey[k] = existing
                } else if newScore.0 == 1 && existingScore.0 == 0 {
                    if let summary = existing.summary, !summary.isEmpty {
                        logger.debug("Дедупликация: объединяем (новый имеет voiceNote, existing имеет summary), key=\(k)", category: .network)
                        let merged = Bookmark(
                            id: b.id,
                            fileName: b.fileName,
                            contentType: b.contentType,
                            category: b.category,
                            voiceNote: b.voiceNote,
                            fileUrl: b.fileUrl ?? existing.fileUrl,
                            summary: summary, // Сохраняем summary из existing
                            content: b.content ?? existing.content,
                            contentHash: b.contentHash ?? existing.contentHash,
                            timestamp: b.timestamp > existing.timestamp ? b.timestamp : existing.timestamp,
                            totalChunks: b.totalChunks ?? existing.totalChunks,
                            distance: b.distance ?? existing.distance
                        )
                        bestByKey[k] = merged
                    } else {
                        logger.debug("Дедупликация: заменяем на новый (имеет voiceNote, existing нет), key=\(k)", category: .network)
                        bestByKey[k] = b
                    }
                } else if newScore > existingScore {
                    if newScore.0 == 1 && existingScore.0 == 1, let summary = existing.summary, !summary.isEmpty {
                        logger.debug("Дедупликация: объединяем (оба имеют voiceNote, новый лучше), key=\(k)", category: .network)
                        let merged = Bookmark(
                            id: b.id,
                            fileName: b.fileName,
                            contentType: b.contentType,
                            category: b.category,
                            voiceNote: b.voiceNote,
                            fileUrl: b.fileUrl ?? existing.fileUrl,
                            summary: summary, // Сохраняем summary из existing
                            content: b.content ?? existing.content,
                            contentHash: b.contentHash ?? existing.contentHash,
                            timestamp: b.timestamp > existing.timestamp ? b.timestamp : existing.timestamp,
                            totalChunks: b.totalChunks ?? existing.totalChunks,
                            distance: b.distance ?? existing.distance
                        )
                        bestByKey[k] = merged
                    } else {
                        logger.debug("Дедупликация: заменяем на новый (лучше по score), key=\(k)", category: .network)
                        bestByKey[k] = b
                    }
                } else if existingScore == newScore {
                    if existingScore.0 == 1 && newScore.0 == 1 {
                        if let summary = b.summary, !summary.isEmpty, existing.summary == nil || existing.summary!.isEmpty {
                            logger.debug("Дедупликация: объединяем (оба имеют voiceNote, новый имеет summary), key=\(k)", category: .network)
                            let isExistingNewer = existing.timestamp > b.timestamp
                            let merged = Bookmark(
                                id: isExistingNewer ? existing.id : b.id,
                                fileName: isExistingNewer ? existing.fileName : b.fileName,
                                contentType: isExistingNewer ? existing.contentType : b.contentType,
                                category: isExistingNewer ? existing.category : b.category,
                                voiceNote: isExistingNewer ? existing.voiceNote : b.voiceNote,
                                fileUrl: isExistingNewer ? (existing.fileUrl ?? b.fileUrl) : (b.fileUrl ?? existing.fileUrl),
                                summary: summary, // Сохраняем summary из b
                                content: isExistingNewer ? (existing.content ?? b.content) : (b.content ?? existing.content),
                                contentHash: isExistingNewer ? (existing.contentHash ?? b.contentHash) : (b.contentHash ?? existing.contentHash),
                                timestamp: isExistingNewer ? existing.timestamp : b.timestamp,
                                totalChunks: isExistingNewer ? (existing.totalChunks ?? b.totalChunks) : (b.totalChunks ?? existing.totalChunks),
                                distance: isExistingNewer ? (existing.distance ?? b.distance) : (b.distance ?? existing.distance)
                            )
                            bestByKey[k] = merged
                        } else {
                            logger.debug("Дедупликация: выбираем более новый (оба имеют voiceNote), key=\(k)", category: .network)
                            bestByKey[k] = existing.timestamp > b.timestamp ? existing : b
                        }
                    } else {
                        logger.debug("Дедупликация: выбираем более новый (оба не имеют voiceNote), key=\(k)", category: .network)
                        bestByKey[k] = existing.timestamp > b.timestamp ? existing : b
                    }
                } else {
                    if let summary = b.summary, !summary.isEmpty, existingScore.0 == 1 {
                        logger.debug("Дедупликация: объединяем (existing имеет voiceNote, новый имеет summary), key=\(k)", category: .network)
                        let isExistingNewer = existing.timestamp > b.timestamp
                        let voiceNoteToUse: String?
                        if newScore.0 == 1 {
                            voiceNoteToUse = isExistingNewer ? existing.voiceNote : b.voiceNote
                        } else {
                            voiceNoteToUse = existing.voiceNote
                        }
                        let merged = Bookmark(
                            id: isExistingNewer ? existing.id : b.id,
                            fileName: isExistingNewer ? existing.fileName : b.fileName,
                            contentType: isExistingNewer ? existing.contentType : b.contentType,
                            category: isExistingNewer ? existing.category : b.category,
                            voiceNote: voiceNoteToUse,
                            fileUrl: isExistingNewer ? (existing.fileUrl ?? b.fileUrl) : (b.fileUrl ?? existing.fileUrl),
                            summary: summary, // Сохраняем summary из b
                            content: isExistingNewer ? (existing.content ?? b.content) : (b.content ?? existing.content),
                            contentHash: isExistingNewer ? (existing.contentHash ?? b.contentHash) : (b.contentHash ?? existing.contentHash),
                            timestamp: isExistingNewer ? existing.timestamp : b.timestamp,
                            totalChunks: isExistingNewer ? (existing.totalChunks ?? b.totalChunks) : (b.totalChunks ?? existing.totalChunks),
                            distance: isExistingNewer ? (existing.distance ?? b.distance) : (b.distance ?? existing.distance)
                        )
                        bestByKey[k] = merged
                    } else {
                        logger.debug("Дедупликация: сохраняем existing (лучше по score), key=\(k)", category: .network)
                        bestByKey[k] = existing
                    }
                }
            } else {
                bestByKey[k] = b
            }
        }
        
        let result = Array(bestByKey.values).sorted {
            if $0.timestamp != $1.timestamp { return $0.timestamp > $1.timestamp }
            return $0.fileName.lowercased() < $1.fileName.lowercased()
        }
        
        logger.info("deduplicateBookmarks: после дедупликации осталось \(result.count) bookmark", category: .network)
        
        for (idx, b) in result.enumerated() {
            let hasVoice = b.voiceNote != nil && !b.voiceNote!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasSummary = b.summary != nil && !b.summary!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasVoice && hasSummary {
                logger.debug("после дедупликации [\(idx)]: fileName=\(b.fileName), voiceNote=\(b.voiceNote!.prefix(50))..., summary=\(b.summary!.prefix(50))...", category: .network)
            } else if hasVoice {
                logger.debug("после дедупликации [\(idx)]: fileName=\(b.fileName), voiceNote=\(b.voiceNote!.prefix(50))..., summary=отсутствует", category: .network)
            } else if hasSummary {
                logger.warning("после дедупликации [\(idx)]: fileName=\(b.fileName), voiceNote=отсутствует, summary=\(b.summary!.prefix(50))... (voiceNote потерян при дедупликации?)", category: .network)
            } else {
                logger.debug("после дедупликации [\(idx)]: fileName=\(b.fileName), voiceNote=отсутствует, summary=отсутствует", category: .network)
            }
        }
        
        return result
    }
    
    func handleFolderLongPressStarted(_ folder: Folder) {
        logger.info("Long press начался на папке: \(folder.name)", category: .ui)
        selectedFolder = folder
        
        if isRecording || isRecordingStartInProgress {
            logger.warning("Повторный запуск записи проигнорирован (isRecording=\(isRecording), isRecordingStartInProgress=\(isRecordingStartInProgress))", category: .speech)
            return
        }
        isRecordingStartInProgress = true
        currentPressSessionId = UUID()
        endDebounceTask?.cancel()
        hasRetriedStartForSession = false
        receivedPartialForSession = false
        startLatencyAt = Date()
        
        Task {
            defer { isRecordingStartInProgress = false }
            do {
                await MainActor.run { 
                    isRecording = true
                    transcription = ""
                    accumulatedTranscription = ""
                }
            
                            try await speechService.startRecording(
                                onPartialResult: { [weak self] partialText in
                                    guard let self else { return }
                                    Task(priority: .userInitiated) {
                                        await MainActor.run { self.receivedPartialForSession = true }
                                        
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
                                        }
                                    }
                                },
                    taskHint: .search,
                    timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                )
                
                
                let sessionId = currentPressSessionId
                recordingWatchdogTask?.cancel()
                recordingWatchdogTask = Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000) // Увеличено с 1.5с до 2.5с для более стабильной работы
                    let shouldRetry = await MainActor.run {
                        !receivedPartialForSession && isRecording && !hasRetriedStartForSession && sessionId == currentPressSessionId
                    }
                    if shouldRetry {
                        await MainActor.run {
                            hasRetriedStartForSession = true
                        }
                        logger.warning("Watchdog: нет partial за 2.5с, перезапуск записи", category: .speech)
                        
                        speechService.cancelRecording()
                        
                        await MainActor.run {
                            isRecording = false
                        }
                        
                        try? await Task.sleep(nanoseconds: 500_000_000) // Увеличено с 300мс до 500мс
                        
                        do {
                            try await speechService.startRecording(
                                onPartialResult: { [weak self] partialText in
                                    guard let self else { return }
                                    Task(priority: .userInitiated) {
                                        await MainActor.run { self.receivedPartialForSession = true }
                                        
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
                                        }
                                    }
                                },
                                taskHint: .search,
                                timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                            )
                            
                            await MainActor.run {
                                isRecording = true
                            }
                        } catch {
                            if let apiError = error as? APIError,
                               case .serverError(let message) = apiError,
                               message.contains("Запись уже активна") {
                                logger.warning("Watchdog: ошибка 'Запись уже активна' при перезапуске (folder), повторная попытка", category: .speech)
                                speechService.cancelRecording()
                                try? await Task.sleep(nanoseconds: 200_000_000) // 200мс
                                
                                if sessionId == currentPressSessionId {
                                    do {
                                        try await speechService.startRecording(
                                            onPartialResult: { [weak self] partialText in
                                                guard let self else { return }
                                                Task(priority: .userInitiated) {
                                                    await MainActor.run { self.receivedPartialForSession = true }
                                                    
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
                                                    } else {
                                                        self.logger.debug("Partial результат проигнорирован (дубликат/исправление): '\(partialText.prefix(30))...'", category: .speech)
                                                    }
                                                }
                                            },
                                            taskHint: .search,
                                            timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                                        )
                                        
                                        await MainActor.run {
                                            isRecording = true
                                        }
                                        logger.info("Watchdog: повторный перезапуск успешен после ошибки 'Запись уже активна' (folder)", category: .speech)
                                    } catch {
                                        await MainActor.run {
                                            isRecording = false
                                            logger.error("Watchdog: ошибка повторного перезапуска записи: \(error)", category: .speech)
                                        }
                                    }
                                } else {
                                    await MainActor.run {
                                        isRecording = false
                                        logger.debug("Watchdog: повторный перезапуск пропущен - пользователь отпустил кнопку (folder)", category: .speech)
                                    }
                                }
                            } else {
                            await MainActor.run {
                                isRecording = false
                                logger.error("Ошибка перезапуска записи: \(error)", category: .speech)
                                }
                            }
                        }
                    }
                }
                
                if let startedAt = startLatencyAt {
                    let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
                    logger.info("Старт записи (folder) latency: ~\(ms)мс, session=\(currentPressSessionId?.uuidString ?? "nil")", category: .speech)
                }
            } catch {
                await MainActor.run { isRecording = false }
                let sessionId = currentPressSessionId
                
                if let apiError = error as? APIError,
                   case .serverError(let message) = apiError,
                   message.contains("Запись уже активна") {
                    logger.warning("Обнаружена ошибка 'Запись уже активна' (folder), принудительно сбрасываем состояние", category: .speech)
                    speechService.cancelRecording()
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500мс для полного сброса
                    
                    let shouldRetry = await MainActor.run {
                        sessionId == currentPressSessionId && !hasRetriedStartForSession
                    }
                    if shouldRetry {
                        await MainActor.run {
                            hasRetriedStartForSession = true
                        }
                        logger.info("Автоматический перезапуск записи после ошибки 'Запись уже активна' (folder)", category: .speech)
                        
                        do {
                            try await speechService.startRecording(
                                onPartialResult: { [weak self] partialText in
                                    guard let self else { return }
                                    Task(priority: .userInitiated) {
                                        await MainActor.run { self.receivedPartialForSession = true }
                                        
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
                                        }
                                    }
                                },
                                taskHint: .search,
                                timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                            )
                            
                            await MainActor.run {
                                isRecording = true
                            }
                            
                            let watchdogSessionId = currentPressSessionId
                            recordingWatchdogTask?.cancel()
                            recordingWatchdogTask = Task {
                                try? await Task.sleep(nanoseconds: 2_500_000_000)
                                let shouldRetry = await MainActor.run {
                                    !receivedPartialForSession && isRecording && !hasRetriedStartForSession && watchdogSessionId == currentPressSessionId
                                }
                                if shouldRetry {
                                    await MainActor.run {
                                        hasRetriedStartForSession = true
                                    }
                                    logger.warning("Watchdog: нет partial за 2.5с, перезапуск записи", category: .speech)
                                    
                                    speechService.cancelRecording()
                                    
                                    await MainActor.run {
                                        isRecording = false
                                    }
                                    
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    
                                    do {
                                        try await speechService.startRecording(
                                            onPartialResult: { [weak self] partialText in
                                                guard let self else { return }
                                                Task(priority: .userInitiated) {
                                                    await MainActor.run { self.receivedPartialForSession = true }
                                                    
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
                                                    }
                                                }
                                            },
                                            taskHint: .search,
                                            timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                                        )
                                        
                                        await MainActor.run {
                                            isRecording = true
                                        }
                                    } catch {
                                        await MainActor.run {
                                            isRecording = false
                                            logger.error("Ошибка перезапуска записи: \(error)", category: .speech)
                                        }
                                    }
                                }
                            }
                            
                            logger.info("Автоматический перезапуск записи успешен (folder)", category: .speech)
                        } catch {
                            await MainActor.run {
                                isRecording = false
                                logger.error("Ошибка автоматического перезапуска записи: \(error)", category: .speech)
                                toast = .error("Не удалось начать запись: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        if sessionId != currentPressSessionId {
                            logger.debug("Перезапуск пропущен: пользователь отпустил кнопку (folder)", category: .speech)
                        } else if hasRetriedStartForSession {
                            logger.debug("Перезапуск пропущен: уже был перезапуск в этой сессии (folder)", category: .speech)
                        }
                        
                        await MainActor.run {
                            isRecording = false
                            logger.error("Ошибка начала записи: \(error)", category: .speech)
                        }
                    }
                } else {
                    logger.warning("Ошибка распознавания (не 'Запись уже активна'), пытаемся перезапустить запись (folder)", category: .speech)
                    speechService.cancelRecording()
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200мс
                    
                    let shouldRetry = await MainActor.run {
                        sessionId == currentPressSessionId && !hasRetriedStartForSession
                    }
                    if shouldRetry {
                        await MainActor.run {
                            hasRetriedStartForSession = true
                        }
                        logger.info("Автоматический перезапуск записи после ошибки распознавания (folder)", category: .speech)
                        
                        do {
                            try await speechService.startRecording(
                                onPartialResult: { [weak self] partialText in
                                    guard let self else { return }
                                    Task(priority: .userInitiated) {
                                        await MainActor.run { self.receivedPartialForSession = true }
                                        
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
                                        }
                                    }
                                },
                                taskHint: .search,
                                timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                            )
                            
                            await MainActor.run {
                                isRecording = true
                            }
                            
                            let watchdogSessionId = currentPressSessionId
                            recordingWatchdogTask?.cancel()
                            recordingWatchdogTask = Task {
                                try? await Task.sleep(nanoseconds: 2_500_000_000)
                                let shouldRetry = await MainActor.run {
                                    !receivedPartialForSession && isRecording && !hasRetriedStartForSession && watchdogSessionId == currentPressSessionId
                                }
                                if shouldRetry {
                                    await MainActor.run {
                                        hasRetriedStartForSession = true
                                    }
                                    logger.warning("Watchdog: нет partial за 2.5с, перезапуск записи", category: .speech)
                                    
                                    speechService.cancelRecording()
                                    
                                    await MainActor.run {
                                        isRecording = false
                                    }
                                    
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    
                                    do {
                                        try await speechService.startRecording(
                                            onPartialResult: { [weak self] partialText in
                                                guard let self else { return }
                                                Task(priority: .userInitiated) {
                                                    await MainActor.run { self.receivedPartialForSession = true }
                                                    
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
                                                    }
                                                }
                                            },
                                            taskHint: .search,
                                            timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                                        )
                                        
                                        await MainActor.run {
                                            isRecording = true
                                        }
                                    } catch {
                                        await MainActor.run {
                                            isRecording = false
                                            logger.error("Ошибка перезапуска записи: \(error)", category: .speech)
                                        }
                                    }
                                }
                            }
                            
                            logger.info("Автоматический перезапуск записи успешен после ошибки распознавания (folder)", category: .speech)
                        } catch {
                            await MainActor.run {
                                isRecording = false
                                logger.error("Ошибка автоматического перезапуска записи после ошибки распознавания: \(error)", category: .speech)
                                toast = .error("Не удалось начать запись: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        await MainActor.run {
                            isRecording = false
                            logger.error("Ошибка начала записи: \(error)", category: .speech)
                            toast = .error("Не удалось начать запись: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    func handleFolderLongPressEnded() {
        logger.info("Long press завершен", category: .ui)
        
        Task {
            await MainActor.run {
                currentPressSessionId = nil
                receivedPartialForSession = false
                hasRetriedStartForSession = false
            }
            
            recordingWatchdogTask?.cancel()
            recordingWatchdogTask = nil
            
            let finalTranscription = await speechService.stopRecording()
            
            await MainActor.run {
                isRecording = false
                
                let finalText: String
                if let text = finalTranscription?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !text.isEmpty {
                    if let merged = transcriptionMerger.merge(accumulated: accumulatedTranscription, new: text) {
                        finalText = textPostProcessor.process(merged)
                    } else {
                        let rawText = accumulatedTranscription.isEmpty ? text : accumulatedTranscription
                        finalText = textPostProcessor.process(rawText)
                    }
                } else if !accumulatedTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalText = textPostProcessor.process(accumulatedTranscription)
                } else if !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalText = textPostProcessor.process(transcription)
                } else {
                    finalText = ""
                }
                
                transcription = finalText
                accumulatedTranscription = ""
                
                if !finalText.isEmpty {
                    if let folder = selectedFolder {
                        performSearch(query: finalText, folderId: folder.id)
                    }
                } else {
                    selectedFolder = nil
                }
            }
        }
    }
    
    func handleBookmarkLongPressStarted(_ bookmark: Bookmark) {
        logger.info("Long press начался на закладке: \(bookmark.fileName)", category: .ui)
        selectedBookmark = bookmark
        
        if isRecording || isRecordingStartInProgress {
            logger.warning("Повторный запуск записи (bookmark) проигнорирован (isRecording=\(isRecording), isRecordingStartInProgress=\(isRecordingStartInProgress))", category: .speech)
            return
        }
        isRecordingStartInProgress = true
        currentPressSessionId = UUID()
        endDebounceTask?.cancel()
        hasRetriedStartForSession = false
        receivedPartialForSession = false
        startLatencyAt = Date()
        
        Task {
            defer { isRecordingStartInProgress = false }
            do {
                await MainActor.run { 
                    isRecording = true
                    transcription = ""
                    accumulatedTranscription = ""
                }
            
                            try await speechService.startRecording(
                                onPartialResult: { [weak self] partialText in
                                    guard let self else { return }
                                    Task(priority: .userInitiated) {
                                        await MainActor.run { self.receivedPartialForSession = true }
                                        
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
                                        }
                                    }
                                },
                    taskHint: .search,
                    timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                )
                
                
                let sessionId = currentPressSessionId
                recordingWatchdogTask?.cancel()
                recordingWatchdogTask = Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000) // Увеличено с 1.5с до 2.5с для более стабильной работы
                    let shouldRetry = await MainActor.run {
                        !receivedPartialForSession && isRecording && !hasRetriedStartForSession && sessionId == currentPressSessionId
                    }
                    if shouldRetry {
                        await MainActor.run {
                            hasRetriedStartForSession = true
                        }
                        logger.warning("Watchdog: нет partial за 2.5с, перезапуск записи (bookmark)", category: .speech)
                        
                        speechService.cancelRecording()
                        
                        await MainActor.run {
                            isRecording = false
                        }
                        
                        try? await Task.sleep(nanoseconds: 500_000_000) // Увеличено с 300мс до 500мс
                        
                        do {
                            try await speechService.startRecording(
                                onPartialResult: { [weak self] partialText in
                                    guard let self else { return }
                                    Task(priority: .userInitiated) {
                                        await MainActor.run { self.receivedPartialForSession = true }
                                        
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
                                        }
                                    }
                                },
                                taskHint: .search,
                                timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                            )
                            
                            await MainActor.run {
                                isRecording = true
                            }
                        } catch {
                            if let apiError = error as? APIError,
                               case .serverError(let message) = apiError,
                               message.contains("Запись уже активна") {
                                logger.warning("Watchdog: ошибка 'Запись уже активна' при перезапуске (bookmark), повторная попытка", category: .speech)
                                speechService.cancelRecording()
                                try? await Task.sleep(nanoseconds: 200_000_000) // 200мс
                                
                                if sessionId == currentPressSessionId {
                                    do {
                                        try await speechService.startRecording(
                                            onPartialResult: { [weak self] partialText in
                                                guard let self else { return }
                                                Task(priority: .userInitiated) {
                                                    await MainActor.run { self.receivedPartialForSession = true }
                                                    
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
                                                    } else {
                                                        self.logger.debug("Partial результат проигнорирован (дубликат/исправление): '\(partialText.prefix(30))...'", category: .speech)
                                                    }
                                                }
                                            },
                                            taskHint: .search,
                                            timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                                        )
                                        
                                        await MainActor.run {
                                            isRecording = true
                                        }
                                        logger.info("Watchdog: повторный перезапуск успешен после ошибки 'Запись уже активна' (bookmark)", category: .speech)
                                    } catch {
                                        await MainActor.run {
                                            isRecording = false
                                            logger.error("Watchdog: ошибка повторного перезапуска записи: \(error)", category: .speech)
                                        }
                                    }
                                } else {
                                    await MainActor.run {
                                        isRecording = false
                                        logger.debug("Watchdog: повторный перезапуск пропущен - пользователь отпустил кнопку (bookmark)", category: .speech)
                                    }
                                }
                            } else {
                            await MainActor.run {
                                isRecording = false
                                logger.error("Ошибка перезапуска записи: \(error)", category: .speech)
                                }
                            }
                        }
                    }
                }
                
                if let startedAt = startLatencyAt {
                    let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
                    logger.info("Старт записи (bookmark) latency: ~\(ms)мс, session=\(currentPressSessionId?.uuidString ?? "nil")", category: .speech)
                }
            } catch {
                await MainActor.run { isRecording = false }
                let sessionId = currentPressSessionId
                
                if let apiError = error as? APIError,
                   case .serverError(let message) = apiError,
                   message.contains("Запись уже активна") {
                    logger.warning("Обнаружена ошибка 'Запись уже активна' (bookmark), принудительно сбрасываем состояние", category: .speech)
                    speechService.cancelRecording()
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500мс для полного сброса
                    
                    let shouldRetry = await MainActor.run {
                        sessionId == currentPressSessionId && !hasRetriedStartForSession
                    }
                    if shouldRetry {
                        await MainActor.run {
                            hasRetriedStartForSession = true
                        }
                        logger.info("Автоматический перезапуск записи после ошибки 'Запись уже активна' (bookmark)", category: .speech)
                        
                        do {
                            try await speechService.startRecording(
                                onPartialResult: { [weak self] partialText in
                                    guard let self else { return }
                                    Task(priority: .userInitiated) {
                                        await MainActor.run { self.receivedPartialForSession = true }
                                        
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
                                        }
                                    }
                                },
                                taskHint: .search,
                                timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                            )
                            
                            await MainActor.run {
                                isRecording = true
                            }
                            
                            let watchdogSessionId = currentPressSessionId
                            recordingWatchdogTask?.cancel()
                            recordingWatchdogTask = Task {
                                try? await Task.sleep(nanoseconds: 2_500_000_000)
                                let shouldRetry = await MainActor.run {
                                    !receivedPartialForSession && isRecording && !hasRetriedStartForSession && watchdogSessionId == currentPressSessionId
                                }
                                if shouldRetry {
                                    await MainActor.run {
                                        hasRetriedStartForSession = true
                                    }
                                    logger.warning("Watchdog: нет partial за 2.5с, перезапуск записи (bookmark)", category: .speech)
                                    
                                    speechService.cancelRecording()
                                    
                                    await MainActor.run {
                                        isRecording = false
                                    }
                                    
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    
                                    do {
                                        try await speechService.startRecording(
                                            onPartialResult: { [weak self] partialText in
                                                guard let self else { return }
                                                Task(priority: .userInitiated) {
                                                    await MainActor.run { self.receivedPartialForSession = true }
                                                    
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
                                                    }
                                                }
                                            },
                                            taskHint: .search,
                                            timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                                        )
                                        
                                        await MainActor.run {
                                            isRecording = true
                                        }
                                    } catch {
                                        await MainActor.run {
                                            isRecording = false
                                            logger.error("Ошибка перезапуска записи: \(error)", category: .speech)
                                        }
                                    }
                                }
                            }
                            
                            logger.info("Автоматический перезапуск записи успешен (bookmark)", category: .speech)
                        } catch {
                            await MainActor.run {
                                isRecording = false
                                logger.error("Ошибка автоматического перезапуска записи: \(error)", category: .speech)
                                toast = .error("Не удалось начать запись: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        if sessionId != currentPressSessionId {
                            logger.debug("Перезапуск пропущен: пользователь отпустил кнопку (bookmark)", category: .speech)
                        } else if hasRetriedStartForSession {
                            logger.debug("Перезапуск пропущен: уже был перезапуск в этой сессии (bookmark)", category: .speech)
                        }
                        
                        await MainActor.run {
                            isRecording = false
                            logger.error("Ошибка начала записи: \(error)", category: .speech)
                        }
                    }
                } else {
                    logger.warning("Ошибка распознавания (не 'Запись уже активна'), пытаемся перезапустить запись (bookmark)", category: .speech)
                    speechService.cancelRecording()
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200мс
                    
                    let shouldRetry = await MainActor.run {
                        sessionId == currentPressSessionId && !hasRetriedStartForSession
                    }
                    if shouldRetry {
                        await MainActor.run {
                            hasRetriedStartForSession = true
                        }
                        logger.info("Автоматический перезапуск записи после ошибки распознавания (bookmark)", category: .speech)
                        
                        do {
                            try await speechService.startRecording(
                                onPartialResult: { [weak self] partialText in
                                    guard let self else { return }
                                    Task(priority: .userInitiated) {
                                        await MainActor.run { self.receivedPartialForSession = true }
                                        
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
                                        }
                                    }
                                },
                                taskHint: .search,
                                timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                            )
                            
                            await MainActor.run {
                                isRecording = true
                            }
                            
                            let watchdogSessionId = currentPressSessionId
                            recordingWatchdogTask?.cancel()
                            recordingWatchdogTask = Task {
                                try? await Task.sleep(nanoseconds: 2_500_000_000)
                                let shouldRetry = await MainActor.run {
                                    !receivedPartialForSession && isRecording && !hasRetriedStartForSession && watchdogSessionId == currentPressSessionId
                                }
                                if shouldRetry {
                                    await MainActor.run {
                                        hasRetriedStartForSession = true
                                    }
                                    logger.warning("Watchdog: нет partial за 2.5с, перезапуск записи (bookmark)", category: .speech)
                                    
                                    speechService.cancelRecording()
                                    
                                    await MainActor.run {
                                        isRecording = false
                                    }
                                    
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    
                                    do {
                                        try await speechService.startRecording(
                                            onPartialResult: { [weak self] partialText in
                                                guard let self else { return }
                                                Task(priority: .userInitiated) {
                                                    await MainActor.run { self.receivedPartialForSession = true }
                                                    
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
                                                    }
                                                }
                                            },
                                            taskHint: .search,
                                            timeoutNoSpeech: Constants.Speech.timeoutNoSpeechForSearch
                                        )
                                        
                                        await MainActor.run {
                                            isRecording = true
                                        }
                                    } catch {
                                        await MainActor.run {
                                            isRecording = false
                                            logger.error("Ошибка перезапуска записи: \(error)", category: .speech)
                                        }
                                    }
                                }
                            }
                            
                            logger.info("Автоматический перезапуск записи успешен после ошибки распознавания (bookmark)", category: .speech)
                        } catch {
                            await MainActor.run {
                                isRecording = false
                                logger.error("Ошибка автоматического перезапуска записи после ошибки распознавания: \(error)", category: .speech)
                                toast = .error("Не удалось начать запись: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        await MainActor.run {
                            isRecording = false
                            logger.error("Ошибка начала записи: \(error)", category: .speech)
                            toast = .error("Не удалось начать запись: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    func handleSearchPressingChanged(isPressing: Bool) {
        if isPressing {
            endDebounceTask?.cancel()
            endDebounceTask = nil
            return
        }
        let sessionAtSchedule = currentPressSessionId
        endDebounceTask?.cancel()
        endDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard let self else { return }
            if sessionAtSchedule == currentPressSessionId, isRecording {
                await self.internalEndCurrentSession()
            }
        }
    }
    
    private func internalEndCurrentSession() async {
        logger.info("Long press завершен (debounced), session=\(currentPressSessionId?.uuidString ?? "nil")", category: .ui)
        
        await MainActor.run {
            currentPressSessionId = nil
            receivedPartialForSession = false
            hasRetriedStartForSession = false
        }
        
        recordingWatchdogTask?.cancel()
        recordingWatchdogTask = nil
        let finalTranscription = await speechService.stopRecording()
        
        await MainActor.run {
            isRecording = false
            
            let finalText: String
            if let text = finalTranscription?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                if let merged = transcriptionMerger.merge(accumulated: accumulatedTranscription, new: text) {
                    finalText = textPostProcessor.process(merged)
                } else {
                    let rawText = accumulatedTranscription.isEmpty ? text : accumulatedTranscription
                    finalText = textPostProcessor.process(rawText)
                }
            } else if !accumulatedTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finalText = textPostProcessor.process(accumulatedTranscription)
            } else if !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finalText = textPostProcessor.process(transcription)
            } else {
                finalText = ""
            }
            
            transcription = finalText
            accumulatedTranscription = ""
            
            if !finalText.isEmpty {
                if let folder = selectedFolder {
                    performSearch(query: finalText, folderId: folder.id)
                } else if let bookmark = selectedBookmark {
                    performSearch(query: finalText, folderId: nil, bookmarkId: bookmark.id)
                }
            }
        }
    }
    
    func handleBookmarkLongPressEnded() {
        logger.info("Long press завершен на закладке", category: .ui)
        
        Task {
            await MainActor.run {
                currentPressSessionId = nil
                receivedPartialForSession = false
                hasRetriedStartForSession = false
            }
            
            recordingWatchdogTask?.cancel()
            recordingWatchdogTask = nil
            
            let finalTranscription = await speechService.stopRecording()
            
            await MainActor.run {
                isRecording = false
                
                let finalText: String
                if let text = finalTranscription?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                    if let merged = transcriptionMerger.merge(accumulated: accumulatedTranscription, new: text) {
                        finalText = textPostProcessor.process(merged)
                    } else {
                        let rawText = accumulatedTranscription.isEmpty ? text : accumulatedTranscription
                        finalText = textPostProcessor.process(rawText)
                    }
                } else if !accumulatedTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalText = textPostProcessor.process(accumulatedTranscription)
                } else if !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalText = textPostProcessor.process(transcription)
                } else {
                    finalText = ""
                }
                
                transcription = finalText
                accumulatedTranscription = ""
                
                if !finalText.isEmpty {
                    if let bookmark = selectedBookmark {
                        performSearch(query: finalText, folderId: nil, bookmarkId: bookmark.id)
                    }
                } else {
                    selectedBookmark = nil
                }
            }
        }
    }
    
    func cancelRecording() {
        logger.info("Отмена записи", category: .speech)
        speechService.cancelRecording()
        Task { @MainActor in
            isRecording = false
            transcription = ""
            accumulatedTranscription = ""
            selectedFolder = nil
            selectedBookmark = nil
        }
    }
    
    func performTextSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            toast = .error("Введите запрос для поиска")
            return
        }
        
        searchQuery = trimmed
        performSearch(query: trimmed, folderId: nil)
    }
    
    func performSearch(query: String, folderId: String?, bookmarkId: String? = nil) {
        logger.info("Выполнение поиска: '\(query)', folderId: \(folderId ?? "nil"), bookmarkId: \(bookmarkId ?? "nil")", category: .network)

        Task {
            await MainActor.run {
                isLoading = true
            }

            do {
                let response = try await searchService.search(query: query, folderId: folderId, bookmarkId: bookmarkId)

                await MainActor.run {
                    isLoading = false

                    if response.intent == "search" {
                        searchResults = response.results
                        showFileList = true
                        showWebView = false
                        searchQuery = ""

                        if let folder = selectedFolder {
                            navigateToFileList(folder: folder, results: searchResults)
                        }
                    } else if response.intent == "command" {
                        if let html = response.html, !html.isEmpty {
                            commandHTML = html
                            showWebView = true
                            showFileList = false
                            currentDestination = .webView(.command(html))
                            searchQuery = ""
                        } else {
                            toast = .error("Пустой ответ команды")
                        }
                    } else {
                        toast = .error("Неизвестный тип ответа поиска")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    logger.error("Ошибка поиска: \(error)", category: .network)
                    toast = .error("Ошибка поиска: \(error.localizedDescription)")
                }
            }
        }
    }

    func executeCommand(query: String) async {
        logger.info("Выполнение команды: \(query)", category: .network)

        do {
            let response = try await searchService.executeCommand(query: query, folderId: selectedFolder?.id, bookmarkId: selectedBookmark?.id)

            await MainActor.run {
                commandHTML = response.html
                showWebView = true
                showFileList = false
                currentDestination = .webView(.command(response.html))
            }
        } catch {
            await MainActor.run {
                logger.error("Ошибка выполнения команды: \(error)", category: .network)
                toast = .error("Ошибка выполнения команды: \(error.localizedDescription)")
            }
        }
    }

    func navigateToFileList(folder: Folder, results: [Bookmark]) {
        currentDestination = .fileList(folder, results)
    }

    func navigateToWebView(content: WebViewContent) {
        currentDestination = .webView(content)
    }
    
    func navigateBack() {
        currentDestination = nil
        selectedFolder = nil
    }
    
    func resetSearch() {
        searchQuery = ""
        searchResults = []
        transcription = ""
        isRecording = false
        selectedFolder = nil
        currentDestination = nil
        showFileList = false
        showWebView = false
        commandHTML = nil
    }
}

