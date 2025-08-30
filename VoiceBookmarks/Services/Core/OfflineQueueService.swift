//
//  OfflineQueueService.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
@preconcurrency import CoreData
import Network
import SwiftUI

extension Notification.Name {
    static let offlineQueueDidChange = Notification.Name("offlineQueueDidChange")
}

// MARK: - Очередь загрузок: сохраняет файлы при ошибках сети, автоматически загружает при восстан…
class OfflineQueueService {
    
    static let shared = OfflineQueueService()
    
    private var bookmarkService: BookmarkService?
    private let persistenceController: PersistenceController
    private let logger = LoggerService.shared
    private let fileService = FileService.shared
    
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.voicebookmarks.network-monitor")
    
    private actor ProcessingLock {
        var isProcessing = false
        
        func tryAcquire() -> Bool {
            guard !isProcessing else { return false }
            isProcessing = true
            return true
        }
        
        func release() {
            isProcessing = false
        }
    }
    
    private let processingLock = ProcessingLock()
    
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
    
    private actor ProcessingFileHashesGuard {
        private var processingHashes = Set<String>()
        func insert(_ hash: String) -> Bool {
            if processingHashes.contains(hash) { return false }
            processingHashes.insert(hash)
            return true
        }
        func remove(_ hash: String) {
            processingHashes.remove(hash)
        }
        func contains(_ hash: String) -> Bool {
            return processingHashes.contains(hash)
        }
    }
    private let processingFileHashesGuard = ProcessingFileHashesGuard()
    
    
    /// Вычисляет хэш файла для проверки дубликатов
    private func computeHashOfFile(atPath path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        return fileService.computeContentHash(url: url)
    }
    
    /// Проверяет, есть ли файл с таким же хэшем в очереди (UserDefaults или Core Data)
    /// Используется для предотвращения дубликатов по содержимому
    private func isContentHashInQueue(_ hash: String) async -> Bool {
        let udItems = SharedUserDefaults.getShareExtensionQueueItems()
        for dict in udItems {
            if let path = dict["filePath"] as? String,
               let otherHash = computeHashOfFile(atPath: path),
               otherHash == hash {
                return true
            }
        }
        
        guard persistenceController.isReady else { return false }
        let context = persistenceController.newBackgroundContext()
        let localLogger = logger
        return await context.perform {
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
            do {
                let items = try context.fetch(fetch)
                for obj in items {
                    if let path = obj.value(forKey: "filePath") as? String,
                       let otherHash = FileService.shared.computeContentHash(url: URL(fileURLWithPath: path)),
                       otherHash == hash {
                        return true
                    }
                }
                return false
            } catch {
                localLogger.error("Ошибка fetch при поиске дубликата по хешу: \(error)", category: .offline)
                return false
            }
        }
    }
    
    func isFileProcessing(filePath: String) async -> Bool {
        return await processingFilePathsGuard.contains(filePath)
    }
    
    init(bookmarkService: BookmarkService? = nil, persistenceController: PersistenceController = .shared) {
        self.bookmarkService = bookmarkService
        self.persistenceController = persistenceController
    }
    
    func setBookmarkService(_ service: BookmarkService) {
        self.bookmarkService = service
        logger.info("BookmarkService установлен в OfflineQueueService", category: .offline)
        
        Task {
            await processQueue()
        }
    }
    
    
    /// Проверяет, находится ли файл в очереди (UserDefaults или Core Data)
    func isFileInQueue(filePath: String) async -> Bool {
        logger.debug("Проверка наличия файла в очереди: \(filePath)", category: .offline)
        
        let queueItems = SharedUserDefaults.getShareExtensionQueueItems()
        for item in queueItems {
            if let itemFilePath = item["filePath"] as? String, itemFilePath == filePath {
                logger.info("Файл найден в UserDefaults очереди: \(filePath)", category: .offline)
                return true
            }
        }
        
        guard persistenceController.isReady else {
            logger.debug("Core Data не готов, проверяем только UserDefaults", category: .offline)
            return false
        }
        
        let context = persistenceController.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        
        let checkLogger = logger
        
        return await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
            fetchRequest.predicate = NSPredicate(format: "filePath == %@", filePath)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                if !results.isEmpty {
                    checkLogger.info("Файл найден в Core Data очереди: \(filePath)", category: .offline)
                    return true
                } else {
                    checkLogger.debug("Файл не найден в Core Data очереди: \(filePath)", category: .offline)
                    return false
                }
            } catch {
                checkLogger.error("Ошибка проверки файла в Core Data очереди: \(error)", category: .offline)
                return false
            }
        }
    }
    
    
    /// Добавляет файл в очередь загрузки (проверяет дубликаты по пути и хэшу)
    /// Возвращает false если файл уже в очереди или произошла ошибка
    func addToQueue(filePath: String, voiceNote: String?, summary: String?) -> Bool {
        guard persistenceController.isReady else {
            logger.error("Core Data не готов (persistent stores не загружены)", category: .offline)
            return false
        }
        
        guard Thread.isMainThread else {
            logger.error("addToQueue должен вызываться с главного потока", category: .offline)
            return false
        }
        
        let context = persistenceController.viewContext
        
        let duplicateCheckRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
        duplicateCheckRequest.predicate = NSPredicate(format: "filePath == %@", filePath)
        duplicateCheckRequest.fetchLimit = 1
        
        do {
            let existingItems = try context.fetch(duplicateCheckRequest)
            if !existingItems.isEmpty {
                return false
            }
        } catch {
            logger.error("Ошибка проверки дубликатов в очереди: \(error)", category: .offline)
        }
        
        if let contentHash = computeHashOfFile(atPath: filePath) {
            let udItems = SharedUserDefaults.getShareExtensionQueueItems()
            for dict in udItems {
                if let path = dict["filePath"] as? String,
                   let otherHash = computeHashOfFile(atPath: path),
                   otherHash == contentHash {
                    return false
                }
            }
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
            do {
                let existing = try context.fetch(fetch)
                for obj in existing {
                    if let path = obj.value(forKey: "filePath") as? String,
                       let otherHash = computeHashOfFile(atPath: path),
                       otherHash == contentHash {
                        return false
                    }
                }
            } catch {
                logger.error("Ошибка проверки дубликата по хешу в Core Data: \(error)", category: .offline)
            }
        }
        
        let queueItems = SharedUserDefaults.getShareExtensionQueueItems()
        for item in queueItems {
            if let itemFilePath = item["filePath"] as? String, itemFilePath == filePath {
                return false
            }
        }
        
        guard let entity = NSEntityDescription.entity(forEntityName: "PendingUpload", in: context) else {
            logger.error("Не найдена сущность PendingUpload в Core Data модели", category: .offline)
            return false
        }
        
        let pendingUpload = NSManagedObject(entity: entity, insertInto: context)
        
        pendingUpload.setValue(UUID(), forKey: "id")
        pendingUpload.setValue(filePath, forKey: "filePath")
        pendingUpload.setValue(voiceNote, forKey: "voiceNote")
        pendingUpload.setValue(summary, forKey: "summary")
        pendingUpload.setValue(Date(), forKey: "timestamp")
        pendingUpload.setValue(Int16(0), forKey: "uploadAttempts")
        pendingUpload.setValue(nil, forKey: "lastError")
        
        do {
            try context.save()
            
            Task { @MainActor in
            notifyQueueChanged()
            }
            
            return true
        } catch {
            logger.error("Ошибка сохранения в очередь: \(error)", category: .offline)
            return false
        }
    }
    
    @MainActor
    func updateQueuedItem(filePath: String, voiceNote: String?, summary: String?) -> Bool {
        
        var updated = false
        
        if persistenceController.isReady {
            updated = updateQueuedItemInCoreData(filePath: filePath, voiceNote: voiceNote, summary: summary) || updated
        } else {
            logger.debug("Core Data не готов, пробуем обновить в UserDefaults", category: .offline)
        }
        
        let defaults = SharedUserDefaults.shared
        if let defaults = defaults {
            var queueItems = defaults.array(forKey: "share_extension_queue") as? [[String: Any]] ?? []
            var changed = false
            for index in queueItems.indices {
                if let path = queueItems[index]["filePath"] as? String, path == filePath {
                    if let vn = voiceNote {
                        queueItems[index]["voiceNote"] = vn
                    }
                    if let sm = summary {
                        queueItems[index]["summary"] = sm
                    }
                    changed = true
                    updated = true
                    logger.info("Элемент обновлен в UserDefaults очереди: \(filePath)", category: .offline)
                    break
                }
            }
            if changed {
                defaults.set(queueItems, forKey: "share_extension_queue")
            }
        }
        
        if updated { self.notifyQueueChanged() }
        
        return updated
    }
    
    private func updateQueuedItemInCoreData(filePath: String, voiceNote: String?, summary: String?) -> Bool {
        guard Thread.isMainThread else {
            logger.error("updateQueuedItemInCoreData должен вызываться с главного потока", category: .offline)
            return false
        }
        let context = persistenceController.viewContext
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
        fetchRequest.predicate = NSPredicate(format: "filePath == %@", filePath)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let obj = results.first else {
                return false
            }
            if let vn = voiceNote {
                obj.setValue(vn, forKey: "voiceNote")
            }
            if let sm = summary {
                obj.setValue(sm, forKey: "summary")
            }
            try context.save()
            logger.info("Элемент обновлен в Core Data: \(filePath)", category: .offline)
            return true
        } catch {
            logger.error("Ошибка обновления элемента в Core Data: \(error.localizedDescription)", category: .offline)
            return false
        }
    }
    
    
    /// Обрабатывает очередь: миграция из UserDefaults, загрузка с retry (до 3 попыток)
    /// Защищено от параллельного выполнения через ProcessingLock
    func processQueue() async {
        guard await processingLock.tryAcquire() else {
            logger.debug("processQueue уже выполняется, пропускаем параллельный вызов", category: .offline)
            return
        }
        
        defer {
            Task {
                await processingLock.release()
            }
        }
        
        await _processQueue()
    }
    
    private func _processQueue() async {
        
        guard persistenceController.isReady else {
            logger.warning("Core Data не готов, пропускаем обработку очереди", category: .offline)
            return
        }
        
        let migratedCount = await migrateShareExtensionQueueItems()
        
        guard let bookmarkService = bookmarkService else {
            logger.warning("BookmarkService не установлен", category: .offline)
            return
        }
        
        let context = persistenceController.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        if migratedCount > 0 {
            await context.perform {
                context.refreshAllObjects()
            }
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        let processLogger = logger
        
        let itemsToProcess: [(id: UUID, filePath: String, voiceNote: String?, summary: String?, attempts: Int16)] = await context.perform {
        do {
            let pendingUploads = try context.fetch(fetchRequest)
            
            if pendingUploads.isEmpty {
                    processLogger.info("Очередь пуста", category: .offline)
                    return []
            }
            
                processLogger.info("Обработка \(pendingUploads.count) элементов очереди", category: .offline)
            
                var items: [(id: UUID, filePath: String, voiceNote: String?, summary: String?, attempts: Int16)] = []
                
            var failedItems: [NSManagedObject] = []
            
            for pendingUpload in pendingUploads {
                let attempts = (pendingUpload.value(forKey: "uploadAttempts") as? Int16) ?? 0
                
                if attempts >= 3 {
                    failedItems.append(pendingUpload)
                    continue
                }
                
                    guard let id = pendingUpload.value(forKey: "id") as? UUID,
                          let filePath = pendingUpload.value(forKey: "filePath") as? String else {
                        processLogger.warning("Нет id или filePath, пропуск элемента", category: .offline)
                    continue
                }
                
                let voiceNote = pendingUpload.value(forKey: "voiceNote") as? String
                let summary = pendingUpload.value(forKey: "summary") as? String
                
                if let voiceNote = voiceNote, !voiceNote.isEmpty {
                    processLogger.info("Извлечен voiceNote из Core Data", category: .offline)
                } else {
                    processLogger.warning("Извлечен voiceNote из Core Data: nil (возможно, файл добавлен через Share Extension без заметки)", category: .offline)
                }
                
                    items.append((id: id, filePath: filePath, voiceNote: voiceNote, summary: summary, attempts: attempts))
                }
            
            if !failedItems.isEmpty {
                processLogger.info("Удаление \(failedItems.count) элементов с исчерпанными попытками", category: .offline)
                
                for failedItem in failedItems {
                    if let filePath = failedItem.value(forKey: "filePath") as? String {
                        let fileURL = URL(fileURLWithPath: filePath)
                        do {
                            try FileManager.default.removeItem(at: fileURL)
                        } catch {
                            processLogger.warning("Не удалось удалить файл \(filePath): \(error.localizedDescription)", category: .offline)
                        }
                    }
                    
                    context.delete(failedItem)
                }
                
                if context.hasChanges {
                    do {
                        try context.save()
                        processLogger.info("Удалено \(failedItems.count) элементов из очереди", category: .offline)
                    } catch {
                        processLogger.error("Ошибка удаления элементов: \(error.localizedDescription)", category: .offline)
                    }
                }
            }
                
                return items
            } catch {
                processLogger.error("Ошибка получения данных очереди: \(error)", category: .offline)
                return []
            }
        }
        
        guard !itemsToProcess.isEmpty else {
            return
        }
        
        for item in itemsToProcess {
            if Task.isCancelled {
                logger.info("Обработка очереди отменена", category: .offline)
                return
            }
            
            let wasInserted = await processingFilePathsGuard.insert(item.filePath)
            
            if !wasInserted {
                logger.warning("Файл уже обрабатывается, пропускаем: \(item.filePath)", category: .offline)
                continue
            }
            
            logger.info("Файл добавлен в Set обрабатываемых: \(item.filePath)", category: .offline)
            logger.info("Попытка загрузки \(item.attempts + 1)/3: \(item.filePath)", category: .offline)
            
            var processingHashToRemove: String? = nil
            if let hash = computeHashOfFile(atPath: item.filePath) {
                let hashInserted = await processingFileHashesGuard.insert(hash)
                if !hashInserted {
                    logger.warning("Хеш уже обрабатывается, пропускаем: \(item.filePath)", category: .offline)
                    continue
                }
                processingHashToRemove = hash
            }
                
            defer {
                Task {
                    await processingFilePathsGuard.remove(item.filePath)
                    logger.info("Файл удален из Set обрабатываемых: \(item.filePath)", category: .offline)
                    if let hash = processingHashToRemove {
                        await processingFileHashesGuard.remove(hash)
                        logger.info("Хеш удален из Set обрабатываемых", category: .offline)
                    }
                }
            }
            
            do {
                    let success = try await bookmarkService.createBookmark(
                    filePath: item.filePath,
                    voiceNote: item.voiceNote,
                    summary: item.summary
                    )
                    
                let updateLogger = logger
                
                let shouldNotify = await context.perform {
                    if success {
                        updateLogger.info("Файл успешно загружен, удаление из очереди", category: .offline)
                        
                        let deleteRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
                        deleteRequest.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
                        
                        do {
                            let objectsToDelete = try context.fetch(deleteRequest)
                            for obj in objectsToDelete {
                                context.delete(obj)
                        }
                        
                        let fileURL = URL(fileURLWithPath: item.filePath)
                            do {
                                try FileManager.default.removeItem(at: fileURL)
                            } catch {
                                updateLogger.warning("Не удалось удалить файл: \(error.localizedDescription)", category: .offline)
                            }
                            
                            if context.hasChanges {
                                try context.save()
                            }
                            
                            return true
                        } catch {
                            updateLogger.error("Ошибка удаления из очереди: \(error.localizedDescription)", category: .offline)
                            return false
                        }
                    } else {
                        let newAttempts = item.attempts + 1
                        let updateRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
                        updateRequest.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
                        
                        do {
                            let objectsToUpdate = try context.fetch(updateRequest)
                            for obj in objectsToUpdate {
                                obj.setValue(newAttempts, forKey: "uploadAttempts")
                                obj.setValue("Upload failed", forKey: "lastError")
                            }
                            
                            if context.hasChanges {
                                try context.save()
                            }
                            
                            updateLogger.warning("Загрузка не удалась, попытка \(newAttempts)/3", category: .offline)
                        } catch {
                            updateLogger.error("Ошибка обновления попыток: \(error.localizedDescription)", category: .offline)
                        }
                        return false
                    }
                }
                
                if shouldNotify {
                    Task { @MainActor in
                        notifyQueueChanged()
                    }
                }
                
            } catch {
                let errorLogger = logger
                
                await context.perform {
                    let newAttempts = item.attempts + 1
                    let updateRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
                    updateRequest.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
                    
                    do {
                        let objectsToUpdate = try context.fetch(updateRequest)
                        for obj in objectsToUpdate {
                            obj.setValue(newAttempts, forKey: "uploadAttempts")
                            obj.setValue(error.localizedDescription, forKey: "lastError")
                        }
                        
                        if context.hasChanges {
                            try context.save()
                        }
                    } catch {
                        errorLogger.error("Ошибка обновления после ошибки загрузки: \(error.localizedDescription)", category: .offline)
                }
                }
                
                logger.error("Ошибка загрузки: \(error)", category: .offline)
                
                let fileName = URL(fileURLWithPath: item.filePath).lastPathComponent
                let nsError = error as NSError
                let isTimeout = nsError.domain == "NSURLErrorDomain" && nsError.code == -1001
                let isLastAttempt = item.attempts + 1 >= 3
                
                if isLastAttempt {
                    Task { @MainActor in
                        if isTimeout {
                            GlobalToastManager.shared.showError("Файл \"\(fileName)\" не удалось загрузить из-за проблем с сетью. Файл сохранен в очередь и будет загружен позже.")
                        } else {
                            GlobalToastManager.shared.showError("Файл \"\(fileName)\" не удалось загрузить. Файл сохранен в очередь и будет загружен позже.")
                        }
                    }
                }
            }
            
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch is CancellationError {
                logger.info("Task отменен во время sleep", category: .offline)
                return
        } catch {
                logger.warning("Ошибка sleep: \(error.localizedDescription)", category: .offline)
            }
        }
        
    }
    
    
    /// Мигрирует элементы из UserDefaults (Share Extension) в Core Data
    /// Share Extension не может использовать Core Data напрямую, поэтому использует UserDefaults
    private func migrateShareExtensionQueueItems() async -> Int {
        let queueItems = SharedUserDefaults.getShareExtensionQueueItems()
        
        guard !queueItems.isEmpty else {
            return 0
        }
        
        guard persistenceController.isReady else {
            logger.warning("Core Data не готов для миграции, пропускаем", category: .offline)
            return 0
        }
        
        logger.info("Найдено \(queueItems.count) элементов в Share Extension очереди для миграции", category: .offline)
        
        let context = persistenceController.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        let migrationLogger = logger
        
        var migratedCount = 0
        
        return await context.perform {
            for itemDict in queueItems {
                guard let filePath = itemDict["filePath"] as? String else {
                    continue
                }
                
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
                fetchRequest.predicate = NSPredicate(format: "filePath == %@", filePath)
                
                do {
                    let existing = try context.fetch(fetchRequest)
                    if !existing.isEmpty {
                        migrationLogger.debug("Элемент с путем \(filePath) уже существует в Core Data, пропуск", category: .offline)
                        continue
                    }
                } catch {
                    migrationLogger.error("Ошибка проверки существующего элемента: \(error)", category: .offline)
                    continue
                }
                
                guard let entity = NSEntityDescription.entity(forEntityName: "PendingUpload", in: context) else {
                    migrationLogger.error("Не найдена сущность PendingUpload", category: .offline)
                    continue
                }
                
                let pendingUpload = NSManagedObject(entity: entity, insertInto: context)
                
                if let idString = itemDict["id"] as? String,
                   let uuid = UUID(uuidString: idString) {
                    pendingUpload.setValue(uuid, forKey: "id")
                } else {
                    pendingUpload.setValue(UUID(), forKey: "id")
                }
                
                pendingUpload.setValue(filePath, forKey: "filePath")
                pendingUpload.setValue(itemDict["voiceNote"] as? String, forKey: "voiceNote")
                pendingUpload.setValue(itemDict["summary"] as? String, forKey: "summary")
                
                if let timestamp = itemDict["timestamp"] as? TimeInterval {
                    pendingUpload.setValue(Date(timeIntervalSince1970: timestamp), forKey: "timestamp")
                } else {
                    pendingUpload.setValue(Date(), forKey: "timestamp")
                }
                
                if let attempts = itemDict["uploadAttempts"] as? Int {
                    pendingUpload.setValue(Int16(attempts), forKey: "uploadAttempts")
                } else {
                    pendingUpload.setValue(Int16(0), forKey: "uploadAttempts")
                }
                
                migratedCount += 1
            }
            
            guard migratedCount > 0 else {
                migrationLogger.info("Нет новых элементов для миграции", category: .offline)
                SharedUserDefaults.clearShareExtensionQueue()
                return 0
            }
            
            do {
                try context.save()
                migrationLogger.info("Успешно перенесено \(migratedCount) элементов из Share Extension очереди в Core Data", category: .offline)
                
                SharedUserDefaults.clearShareExtensionQueue()
                
                return migratedCount
            } catch {
                migrationLogger.error("Ошибка сохранения мигрированных элементов: \(error)", category: .offline)
                return 0
            }
        }
    }
    
    
    /// Сбрасывает счетчик попыток для неудачных загрузок (1-2 попытки) и запускает обработку
    /// Позволяет пользователю вручную повторить загрузку неудачных элементов
    func retryFailed() {
        logger.info("Retry неудачных загрузок", category: .offline)
        
        guard persistenceController.isReady else {
            logger.warning("Core Data не готов для retry", category: .offline)
            return
        }
        
        guard Thread.isMainThread else {
            logger.error("retryFailed должен вызываться с главного потока", category: .offline)
            return
        }
        
        let context = persistenceController.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
        fetchRequest.predicate = NSPredicate(format: "uploadAttempts > 0 AND uploadAttempts < 3")
        
        do {
            let failed = try context.fetch(fetchRequest)
            
            for item in failed {
                item.setValue(Int16(0), forKey: "uploadAttempts")
                item.setValue(nil, forKey: "lastError")
            }
            
            try context.save()
            logger.info("Сброшено \(failed.count) неудачных загрузок", category: .offline)
            
            Task {
                await processQueue()
            }
            
        } catch {
            logger.error("Ошибка retry: \(error)", category: .offline)
        }
    }
    
    func deleteItem(id: UUID) {
        logger.info("Удаление из очереди: \(id)", category: .offline)
        
        guard persistenceController.isReady else {
            logger.warning("Core Data не готов для удаления", category: .offline)
            return
        }
        
        guard Thread.isMainThread else {
            logger.error("deleteItem должен вызываться с главного потока", category: .offline)
            return
        }
        
        let context = persistenceController.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let items = try context.fetch(fetchRequest)
            
            for item in items {
                if let filePath = item.value(forKey: "filePath") as? String {
                    let fileURL = URL(fileURLWithPath: filePath)
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                    } catch {
                        self.logger.warning("Не удалось удалить файл из очереди: \(error.localizedDescription)", category: .offline)
                    }
                }
                
                context.delete(item)
            }
            
            try context.save()
            Task { @MainActor in
            notifyQueueChanged()
            }
            
            logger.info("Элемент удален из очереди", category: .offline)
        } catch {
            logger.error("Ошибка удаления: \(error)", category: .offline)
        }
    }
    
    func getAllPending() -> [NSManagedObject] {
        guard persistenceController.isReady else {
            logger.warning("Core Data не готов для получения списка", category: .offline)
            return []
        }
        
        guard Thread.isMainThread else {
            logger.error("getAllPending должен вызываться с главного потока", category: .offline)
            return []
        }
        
        let context = persistenceController.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            logger.error("Ошибка fetch очереди: \(error)", category: .offline)
            return []
        }
    }
    
    func getPendingCount() -> Int {
        guard persistenceController.isReady else {
            logger.warning("Core Data не готов для подсчета", category: .offline)
            return 0
        }
        
        guard Thread.isMainThread else {
            logger.error("getPendingCount должен вызываться с главного потока", category: .offline)
            return 0
        }
        
        let context = persistenceController.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PendingUpload")
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            logger.error("Ошибка подсчета очереди: \(error)", category: .offline)
            return 0
        }
    }
    
    
    /// Запускает мониторинг сети: автоматически обрабатывает очередь при восстановлении соединения
    /// Использует NWPathMonitor для отслеживания изменений сетевого подключения
    func startMonitoring() {
        logger.info("Запуск мониторинга сети", category: .offline)
        
        pathMonitor = NWPathMonitor()
        
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                self.logger.info("Сеть доступна, запуск обработки очереди", category: .offline)
                Task {
                    await self.processQueue()
                }
            } else {
                self.logger.warning("Сеть недоступна", category: .offline)
            }
        }
        
        pathMonitor?.start(queue: monitorQueue)
    }
    
    func stopMonitoring() {
        logger.info("Остановка мониторинга сети", category: .offline)
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    private func notifyQueueChanged() {
        NotificationCenter.default.post(name: .offlineQueueDidChange, object: nil)
    }
}
