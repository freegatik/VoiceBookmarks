//
//  KeychainService.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
import Security

protocol KeychainServiceProtocol {
    func saveUserId(_ userId: String) async -> Bool
    func getUserId() -> String?
    func deleteUserId() -> Bool
}

// MARK: - Хранение userId в Keychain
class KeychainService: KeychainServiceProtocol {
    
    static let shared = KeychainService()
    private let logger = LoggerService.shared
    private let userIdKey = Constants.Keychain.userIdKey
    
    private init() {}
    
    
    /// Сохраняет userId в Keychain (удаляет старый, если есть)
    /// Использует задержку для предотвращения race conditions при последовательных операциях
    func saveUserId(_ userId: String) async -> Bool {
        _ = deleteUserId()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        guard let data = userId.data(using: .utf8) else {
            logger.error("Не удалось конвертировать userId в Data", category: .storage)
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIdKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        var status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: userIdKey
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        }
        
        if status == errSecSuccess {
            logger.info("UserId успешно сохранен в Keychain", category: .storage)
            return true
        } else {
            logger.error("Error сохранения в Keychain: \(status)", category: .storage)
            return false
        }
    }
    
    
    /// Получение userId из Keychain
    func getUserId() -> String? {
        logger.debug("Чтение userId из Keychain", category: .storage)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIdKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data,
               let userId = String(data: data, encoding: .utf8) {
                logger.info("UserId найден в Keychain", category: .storage)
                return userId
            }
        }
        
        logger.debug("UserId не найден в Keychain", category: .storage)
        return nil
    }
    
    
    /// Удаление userId из Keychain
    /// Возвращает true даже если элемент не найден (уже удален)
    func deleteUserId() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIdKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            logger.debug("UserId удален из Keychain", category: .storage)
            return true
        } else if status == errSecItemNotFound {
            logger.debug("UserId не найден в Keychain (уже удален)", category: .storage)
            return true
        } else {
            logger.warning("Error удаления из Keychain: \(status)", category: .storage)
            return false
        }
    }
}
