//
//  APIError.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
import Foundation

/// Ошибки API: noData, unauthorized, serverError, httpError, decodingError, networkError
/// 
/// Архитектура:
/// - Централизованное представление всех типов ошибок API
/// - LocalizedError для преобразования технических ошибок в понятные сообщения
/// - Поддержка различных типов ошибок: сетевые, серверные, декодирование, авторизация
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - API errors: noData, unauthorized, serverError, httpError, decodingError, networkError.

enum APIError: Error, LocalizedError {
    case noData
    case unauthorized
    case serverError(message: String)
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    
    
    /// Преобразует технические ошибки в понятные сообщения для пользователя
    /// Используется для отображения ошибок в UI
    var errorDescription: String? {
        switch self {
        case .noData:
            return "Нет данных от сервера"
        case .unauthorized:
            return "Ошибка авторизации"
        case .serverError(let message):
            return "Ошибка сервера: \(message)"
        case .httpError(let statusCode):
            return "HTTP ошибка \(statusCode)"
        case .decodingError:
            return "Ошибка парсинга JSON"
        case .networkError:
            return "Ошибка сети"
        }
    }
}
