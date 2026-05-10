//
//  CommandResponse.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Command response: intent, HTML payload, supporting bookmarks.

struct CommandResponse: Codable {
    let intent: String
    let html: String
    let results: [Bookmark]
}
