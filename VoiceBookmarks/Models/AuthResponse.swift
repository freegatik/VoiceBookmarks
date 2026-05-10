//
//  AuthResponse.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Response from anonymous registration: userId, anonymousId, status.

struct AuthResponse: Codable {
    let success: Bool
    let userId: String
    let anonymousId: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case userId
        case anonymousId
        case message
    }
}
