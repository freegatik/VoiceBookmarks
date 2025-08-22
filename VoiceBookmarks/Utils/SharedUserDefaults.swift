//
//  SharedUserDefaults.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - UserDefaults через App Group для обмена данными с Share Extension

final class SharedUserDefaults {
    
    private static let logger = LoggerService.shared
    private static var _sharedDefaults: UserDefaults?
    
    
    /// UserDefaults через App Group (для обмена данными между основным приложением и Share Extension)
    /// Ленивая инициализация с явной синхронизацией для избежания предупреждений CFPrefsPlistSource
    static var shared: UserDefaults? {
        if _sharedDefaults == nil {
            _sharedDefaults = UserDefaults(suiteName: Constants.AppGroups.identifier)
            if _sharedDefaults == nil {
                logger.error("Не удалось получить shared UserDefaults", category: .storage)
            } else {
                _sharedDefaults?.synchronize()
            }
        }
        return _sharedDefaults
    }
    
    
    /// Сохранение userId в shared UserDefaults (для доступа из Share Extension)
    static func saveUserId(_ userId: String) {
        logger.info("Сохранение userId в Shared UserDefaults", category: .storage)
        shared?.set(userId, forKey: Constants.AppGroups.userIdKey)
    }
    
    static func getUserId() -> String? {
        let userId = shared?.string(forKey: Constants.AppGroups.userIdKey)
        if let userId = userId {
            logger.debug("UserId получен из Shared: \(userId)", category: .storage)
        }
        return userId
    }
    
    
    /// Сохранение pending данных (временные данные для передачи между процессами)
    static func savePendingData(_ data: [String: Any]) {
        logger.info("Сохранение pending data в Shared", category: .storage)
        shared?.set(data, forKey: Constants.AppGroups.sharedDataKey)
    }
    
    static func getPendingData() -> [String: Any]? {
        let data = shared?.dictionary(forKey: Constants.AppGroups.sharedDataKey)
        if data != nil {
            logger.debug("Pending data получена из Shared", category: .storage)
        }
        return data
    }
    
    /// Очистка pending данных
    static func clearPendingData() {
        logger.debug("Очистка pending data", category: .storage)
        shared?.removeObject(forKey: Constants.AppGroups.sharedDataKey)
    }
    
    
    /// Запрос открытия вкладки Share (из Share Extension)
    static func requestShareTabSelection() {
        shared?.set(true, forKey: Constants.AppGroups.shareTabFlagKey)
    }
    
    static func consumeShareTabSelectionRequest() -> Bool {
        guard let defaults = shared else { return false }
        let shouldOpen = defaults.bool(forKey: Constants.AppGroups.shareTabFlagKey)
        if shouldOpen {
            defaults.set(false, forKey: Constants.AppGroups.shareTabFlagKey)
        }
        return shouldOpen
    }
    
    /// Сохранение времени попытки открытия host приложения (для отладки)
    static func setOpenHostAttempt(timestamp: TimeInterval) {
        shared?.set(timestamp, forKey: Constants.AppGroups.openHostAttemptKey)
    }
    
    static func getOpenHostAttempt() -> TimeInterval? {
        guard let defaults = shared else { return nil }
        let value = defaults.double(forKey: Constants.AppGroups.openHostAttemptKey)
        return value == 0 ? nil : value
    }
    
    
    /// Сохраняет файл в очередь Share Extension (используется, когда Core Data недоступен)
    /// Share Extension не может использовать Core Data напрямую, поэтому использует UserDefaults
    static func saveShareExtensionQueueItem(filePath: String, voiceNote: String? = nil, summary: String? = nil) -> Bool {
        guard let defaults = shared else {
            logger.error("Не удалось получить shared UserDefaults для сохранения очереди", category: .storage)
            return false
        }
        
        var queueItems = defaults.array(forKey: "share_extension_queue") as? [[String: Any]] ?? []
        
        let item: [String: Any] = [
            "id": UUID().uuidString,
            "filePath": filePath,
            "voiceNote": voiceNote ?? "",
            "summary": summary ?? "",
            "timestamp": Date().timeIntervalSince1970,
            "uploadAttempts": 0
        ]
        
        queueItems.append(item)
        
        defaults.set(queueItems, forKey: "share_extension_queue")
        
        
        logger.info("Файл сохранен в Share Extension очередь: \(filePath)", category: .storage)
        return true
    }
    
    /// Получает все элементы очереди Share Extension
    /// Основное приложение мигрирует эти элементы в Core Data при обработке очереди
    static func getShareExtensionQueueItems() -> [[String: Any]] {
        guard let defaults = shared else {
            return []
        }
        return defaults.array(forKey: "share_extension_queue") as? [[String: Any]] ?? []
    }
    
    /// Очищает очередь Share Extension (после миграции в Core Data)
    static func clearShareExtensionQueue() {
        shared?.removeObject(forKey: "share_extension_queue")
    }

    
    /// Сохраняет маркер последнего файла из Share Extension (для показа превью в основном приложении)
    /// Используется для отображения контента, который был добавлен через Share Extension
    static func setLastSharedItem(filePath: String) {
        guard let defaults = shared else { return }
        
        if filePath.isEmpty {
            clearLastSharedItem()
            return
        }
        
        let marker: [String: Any] = [
            "filePath": filePath,
            "timestamp": Date().timeIntervalSince1970
        ]
        defaults.set(marker, forKey: "last_shared_item")
    }
    
    static func getLastSharedItem() -> (filePath: String, timestamp: TimeInterval)? {
        guard let defaults = shared,
              let dict = defaults.dictionary(forKey: "last_shared_item"),
              let path = dict["filePath"] as? String,
              !path.isEmpty,
              let ts = dict["timestamp"] as? TimeInterval else {
            return nil
        }
        return (path, ts)
    }
    
    static func clearLastSharedItem() {
        guard let defaults = shared else { return }
        defaults.removeObject(forKey: "last_shared_item")
    }
}

