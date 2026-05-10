//
//  BookmarkCacheService.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Кеш закладок: UserDefaults

class BookmarkCacheService {
    
    static let shared = BookmarkCacheService()
    
    private let logger = LoggerService.shared
    private let cacheValidityDuration: TimeInterval = 300

    
    private init() {}
    
    
    /// Генерация ключа для хранения закладок в UserDefaults
    private func cacheKey(for category: String) -> String {
        return "cached_bookmarks_\(category)"
    }
    
    /// Генерация ключа для хранения времени истечения кеша
    private func cacheExpirationKey(for category: String) -> String {
        return "cached_bookmarks_expiration_\(category)"
    }
    
    
    /// Сохраняет закладки в кеш с временем истечения (текущее время)
    /// Кеш действителен в течение cacheValidityDuration (5 минут)
    func saveBookmarks(_ bookmarks: [Bookmark], for category: String) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(bookmarks)
            
            UserDefaults.standard.set(data, forKey: cacheKey(for: category))
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheExpirationKey(for: category))
            
            logger.info("Закладки сохранены в кеш для категории \(category): \(bookmarks.count)", category: .storage)
        } catch {
            logger.error("Error сохранения закладок в кеш: \(error)", category: .storage)
        }
    }
    
    
    /// Получает закладки из кеша, если они еще действительны (не истекли)
    /// Возвращает nil если кеш отсутствует или истек
    func getCachedBookmarks(for category: String) -> [Bookmark]? {
        guard let expirationTime = UserDefaults.standard.object(forKey: cacheExpirationKey(for: category)) as? TimeInterval else {
            logger.debug("Кеш закладок для категории \(category) отсутствует", category: .storage)
            return nil
        }
        
        let currentTime = Date().timeIntervalSince1970
        let cacheAge = currentTime - expirationTime
        
        if cacheAge > cacheValidityDuration {
            logger.debug("Кеш закладок для категории \(category) истек (возраст: \(Int(cacheAge))с)", category: .storage)
            return nil
        }
        
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: category)) else {
            logger.debug("Не удалось прочитать кеш закладок для категории \(category)", category: .storage)
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let bookmarks = try decoder.decode([Bookmark].self, from: data)
            logger.debug("Закладки загружены из кеша для категории \(category): \(bookmarks.count), возраст: \(Int(cacheAge))с", category: .storage)
            return bookmarks
        } catch {
            logger.error("Error декодирования закладок из кеша: \(error)", category: .storage)
            return nil
        }
    }
    
    
    /// Очистка кеша для конкретной категории
    func clearCache(for category: String) {
        UserDefaults.standard.removeObject(forKey: cacheKey(for: category))
        UserDefaults.standard.removeObject(forKey: cacheExpirationKey(for: category))
        logger.info("Кеш закладок для категории \(category) очищен", category: .storage)
    }
    
    /// Очистка всего кеша закладок (всех категорий)
    func clearAllCache() {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("cached_bookmarks_") || key.hasPrefix("cached_bookmarks_expiration_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        logger.info("Весь кеш закладок очищен", category: .storage)
    }
    
    /// Принудительная очистка всего кеша (включая истекшие)
    func forceClearAllCache() {
        clearAllCache()
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("cached_bookmarks_expiration_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        logger.info("Принудительная очистка кеша закладок выполнена", category: .storage)
    }
}
