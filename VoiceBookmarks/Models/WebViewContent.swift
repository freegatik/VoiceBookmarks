//
//  WebViewContent.swift
//  VoiceBookmarks
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Payload shown in WebView: bookmark file preview or command HTML.

enum WebViewContent {
    case file(Bookmark)
    case command(String)
    
    var title: String {
        switch self {
        case .file(let bookmark):
            return bookmark.fileName
        case .command:
            return "Command result"
        }
    }
    
    var canDelete: Bool {
        switch self {
        case .file:
            return true
        case .command:
            return false
        }
    }
}
