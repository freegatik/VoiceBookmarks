//
//  AuthService.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Аутентификация: анонимная регистрация, сохранение userId в Keychain

class AuthService {
    
    let networkService: NetworkService
    let keychainService: KeychainServiceProtocol
    private let logger = LoggerService.shared
    
    init(
        networkService: NetworkService = NetworkService(),
        keychainService: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.networkService = networkService
        self.keychainService = keychainService
    }
    
    
    /// Получает userId из Keychain или создает новый через анонимную регистрацию
    /// Стратегия: сначала проверяем Keychain, только при отсутствии регистрируем нового пользователя
    func getOrCreateUserId() async throws -> String {
        
        if let existingUserId = keychainService.getUserId() {
            logger.info("UserId найден в Keychain: \(existingUserId)", category: .auth)
            networkService.setUserId(existingUserId)
            return existingUserId
        }
        
        logger.info("UserId не найден, начинаем регистрацию", category: .auth)
        let userId = try await anonymousRegister()
        
        let saved = await keychainService.saveUserId(userId)
        if !saved {
            logger.error("Не удалось сохранить userId в Keychain", category: .auth)
            throw APIError.serverError(message: "Ошибка сохранения userId")
        }
        
        networkService.setUserId(userId)
        
        return userId
    }
    
    
    /// Выполняет анонимную регистрацию на сервере
    /// Сервер возвращает уникальный UUID для пользователя
    private func anonymousRegister() async throws -> String {
        logger.info("Вызов POST /api/auth/anonymous", category: .auth)
        
        let response: AuthResponse = try await networkService.request(
            endpoint: Constants.API.Endpoints.auth,
            method: "POST",
            body: nil as String?
        )
        
        logger.info("Получен userId от сервера: \(response.userId)", category: .auth)
        return response.userId
    }
}
