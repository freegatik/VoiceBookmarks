//
//  CommandResponse.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
import Foundation

/// Ответ команды: intent, HTML страница, результаты
/// 
/// Архитектура:
/// - intent: всегда "command" для команд
/// - html: HTML страница с результатом команды (генерируется AI)
/// - results: список закладок, использованных для генерации ответа
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Command response: intent, HTML payload, supporting bookmarks.

struct CommandResponse: Codable {
    let intent: String
    let html: String
    let results: [Bookmark]
}
