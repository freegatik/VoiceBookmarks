//
//  SearchResponse.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Search API response: intent, results, optional HTML for commands.

struct SearchResponse: Codable {
    let intent: String
    let results: [Bookmark]
    let html: String?
}
