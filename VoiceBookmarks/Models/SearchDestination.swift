//
//  SearchDestination.swift
//  VoiceBookmarks
//
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
