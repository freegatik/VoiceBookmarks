//
//  FolderCacheService.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Кеш папок: UserDefaults

class FolderCacheService {
    
    static let shared = FolderCacheService()
    
    private let logger = LoggerService.shared
    private let cacheKey = "cached_folders"
    private let cacheExpirationKey = "cached_folders_expiration"
    private let cacheValidityDuration: TimeInterval = 300 // Кеш действителен 5 минут
    
    private init() {}
    
    
    /// Сохраняет папки в кеш (пробует иерархию, fallback на плоский список)
    /// При ошибке кодирования иерархии сохраняет только имена папок
    func saveFolders(_ folders: [Folder]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(folders)
            UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheExpirationKey)
        
        logger.info("Папки сохранены в кеш: \(folders.count)", category: .storage)
        } catch {
            logger.error("Ошибка сохранения папок в кеш: \(error)", category: .storage)
            let folderNames = folders.map { $0.fullPath }
            UserDefaults.standard.set(folderNames, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheExpirationKey)
        }
    }
    
    
    /// Получает папки из кеша (пробует иерархию, fallback на плоский список)
    /// Возвращает nil если кеш отсутствует или истек
    func getCachedFolders() -> [Folder]? {
        guard let expirationTime = UserDefaults.standard.object(forKey: cacheExpirationKey) as? TimeInterval else {
            logger.debug("Кеш папок отсутствует", category: .storage)
            return nil
        }
        
        let currentTime = Date().timeIntervalSince1970
        let cacheAge = currentTime - expirationTime
        
        if cacheAge > cacheValidityDuration {
            logger.debug("Кеш папок истек", category: .storage)
            return nil
        }
        
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            do {
                let decoder = JSONDecoder()
                let folders = try decoder.decode([Folder].self, from: data)
                logger.debug("Папки загружены из кеша (иерархия): \(folders.count), возраст: \(Int(cacheAge))с", category: .storage)
                return folders
            } catch {
                logger.warning("Не удалось декодировать иерархию папок из кеша: \(error), пробуем fallback", category: .storage)
            }
        }
        
        guard let folderNames = UserDefaults.standard.array(forKey: cacheKey) as? [String] else {
            logger.debug("Не удалось прочитать кеш папок", category: .storage)
            return nil
        }
        
        let folders = folderNames.map { Folder(name: $0) }
        logger.debug("Папки загружены из кеша (плоский список): \(folders.count), возраст: \(Int(cacheAge))с", category: .storage)
        
        return folders
    }
    
    
    /// Очистка кеша папок
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheExpirationKey)
        logger.info("Кеш папок очищен", category: .storage)
    }
    
    /// Принудительная очистка кеша папок
    func forceClearCache() {
        clearCache()
        logger.info("Принудительная очистка кеша папок выполнена", category: .storage)
    }
}
