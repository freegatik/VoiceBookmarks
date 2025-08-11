//
//  WebViewContent.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
import Foundation

/// Контент для WebView: файл (закладка) или HTML команды
/// 
/// Архитектура:
/// - Два типа контента: файл (закладка) или HTML команды (результат поиска)
/// - Вычисляемые свойства для UI: title, canDelete
/// - Команды нельзя удалять (только просматривать)
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
            return "Результат команды"
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

