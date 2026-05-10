//
//  APIError.swift
//  VoiceBookmarks
//
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
    
    
    /// Presents a readable message in alerts and toasts.
    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data from server"
        case .unauthorized:
            return "Authorization error"
        case .serverError(let message):
            return "Server error: \(message)"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode)"
        case .decodingError:
            return "JSON parsing error"
        case .networkError:
            return "Network error"
        }
    }
}
