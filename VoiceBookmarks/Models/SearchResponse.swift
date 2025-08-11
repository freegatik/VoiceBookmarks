//
//  SearchResponse.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
import Foundation

/// Ответ поиска: intent, результаты, опциональный HTML
/// 
/// Архитектура:
/// - intent: "search" (обычный поиск) или "command" (команда с HTML ответом)
/// - results: список найденных закладок (для intent="search")
/// - html: опциональный HTML ответ (для intent="command")
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Search API response: intent, results, optional HTML for commands.

struct SearchResponse: Codable {
    let intent: String
    let results: [Bookmark]
    let html: String?
}
