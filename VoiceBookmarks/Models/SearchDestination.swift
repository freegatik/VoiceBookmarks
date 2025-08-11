//
//  SearchDestination.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
import Foundation

/// Навигационные точки: список файлов в папке или WebView с контентом/командой
/// 
/// Архитектура:
/// - Два типа навигации: fileList (список файлов в папке) и webView (просмотр контента/команды)
/// - Кастомная реализация Equatable для сравнения навигационных точек
/// - Используется для навигации в SearchView
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

// MARK: - Navigation destinations: folder file list or WebView for file/command HTML.

enum SearchDestination: Equatable {
    case fileList(Folder, [Bookmark])
    case webView(WebViewContent)
    
    static func == (lhs: SearchDestination, rhs: SearchDestination) -> Bool {
        switch (lhs, rhs) {
        case (.fileList(let lhsFolder, let lhsBookmarks), .fileList(let rhsFolder, let rhsBookmarks)):
            return lhsFolder.id == rhsFolder.id && lhsBookmarks.count == rhsBookmarks.count
        case (.webView(let lhsContent), .webView(let rhsContent)):
            switch (lhsContent, rhsContent) {
            case (.file(let lhsBookmark), .file(let rhsBookmark)):
                return lhsBookmark.id == rhsBookmark.id
            case (.command(let lhsHTML), .command(let rhsHTML)):
                return lhsHTML == rhsHTML
            default:
                return false
            }
        default:
            return false
        }
    }
}

