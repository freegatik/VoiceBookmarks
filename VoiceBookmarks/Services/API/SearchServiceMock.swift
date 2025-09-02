//
//  SearchServiceMock.swift
//  VoiceBookmarks
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation

final class SearchServiceMock: SearchService {
    private let seededFolders: [Folder]
    private let seededBookmarksByFolder: [String: [Bookmark]]

    override init(networkService: NetworkService = NetworkService()) {
        let folders = [
            Folder(name: "SelfReflection"),
            Folder(name: "Tasks"),
            Folder(name: "ProjectResources"),
            Folder(name: "Uncategorised")
        ]
        self.seededFolders = folders

        let demoBookmarks: [Bookmark] = [
            Bookmark(
                id: UUID().uuidString,
                fileName: "Заметка о цели",
                contentType: .text,
                category: "SelfReflection",
                voiceNote: nil,
                fileUrl: nil,
                summary: "Краткое описание заметки",
                content: nil,
                contentHash: nil,
                timestamp: Date(),
                totalChunks: nil,
                distance: nil
            ),
            Bookmark(
                id: UUID().uuidString,
                fileName: "Аудио идея.m4a",
                contentType: .audio,
                category: "SelfReflection",
                voiceNote: nil,
                fileUrl: nil,
                summary: "Черновик голосовой заметки",
                content: nil,
                contentHash: nil,
                timestamp: Date(),
                totalChunks: nil,
                distance: nil
            )
        ]

        self.seededBookmarksByFolder = [
            "SelfReflection": demoBookmarks,
            "Tasks": [],
            "ProjectResources": [],
            "Uncategorised": []
        ]

        super.init(networkService: networkService)
    }

    override func getFolders() async throws -> [Folder] {
        return seededFolders
    }

    override func getBookmarksForFolder(category: String) async throws -> SearchService.CategoryBookmarksResult {
        let bookmarks = seededBookmarksByFolder[category] ?? []
        return SearchService.CategoryBookmarksResult(bookmarks: bookmarks, actualCategory: category)
    }

    override func search(query: String, folderId: String?, bookmarkId: String? = nil) async throws -> SearchResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.contains("command") {
            return SearchResponse(
                intent: "command",
                results: [],
                html: "<html><head><meta charset=\"utf-8\"></head><body><p>UITest command</p></body></html>"
            )
        }
        if let folderId = folderId, let list = seededBookmarksByFolder[folderId] {
            let filtered = list.filter { $0.fileName.localizedCaseInsensitiveContains(trimmed) || ($0.summary ?? "").localizedCaseInsensitiveContains(trimmed) }
            return SearchResponse(intent: "search", results: filtered, html: nil)
        }
        let all = seededBookmarksByFolder.values.flatMap { $0 }
        let filtered = all.filter { $0.fileName.localizedCaseInsensitiveContains(trimmed) || ($0.summary ?? "").localizedCaseInsensitiveContains(trimmed) }
        return SearchResponse(intent: "search", results: filtered, html: nil)
    }

    override func executeCommand(query: String, folderId: String? = nil, bookmarkId: String? = nil) async throws -> CommandResponse {
        CommandResponse(
            intent: "command",
            html: "<html><body><p>\(query)</p></body></html>",
            results: []
        )
    }
}


