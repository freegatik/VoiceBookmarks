//
//  MockSearchService.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
@testable import VoiceBookmarks

final class MockSearchService: SearchServiceProviding {
    var mockFolders: [Folder] = []
    var mockSearchResponse: SearchResponse?
    var mockCommandResponse: CommandResponse?
    var mockError: Error?
    var getFoldersCalled = false
    var searchCalled = false
    var searchInFolderCalled = false
    var executeCommandCalled = false
    var getBookmarksForFolderCalled = false
    var mockBookmarksForFolder: [Bookmark] = []
    var lastQuery: String?
    var lastFolderId: String?
    var lastCategory: String?
    var capturedCommandQuery: String?
    var capturedBookmarkId: String?

    init() {}

    func getFolders() async throws -> [Folder] {
        getFoldersCalled = true
        if let error = mockError { throw error }
        return mockFolders
    }

    func search(query: String, folderId: String?, bookmarkId: String?) async throws -> SearchResponse {
        searchCalled = true
        lastQuery = query
        lastFolderId = folderId
        capturedBookmarkId = bookmarkId
        if let error = mockError { throw error }
        if let response = mockSearchResponse { return response }
        throw APIError.noData
    }

    func searchInFolder(folderId: String, query: String) async throws -> [Bookmark] {
        searchInFolderCalled = true
        lastFolderId = folderId
        lastQuery = query
        if let response = mockSearchResponse, response.intent == "search" {
            return response.results
        }
        return []
    }

    func executeCommand(query: String, folderId: String?, bookmarkId: String?) async throws -> CommandResponse {
        executeCommandCalled = true
        lastQuery = query
        lastFolderId = folderId
        capturedBookmarkId = bookmarkId
        capturedCommandQuery = query
        if let error = mockError { throw error }
        if let response = mockCommandResponse { return response }
        throw APIError.noData
    }

    func getBookmarksForFolder(category: String) async throws -> SearchService.CategoryBookmarksResult {
        getBookmarksForFolderCalled = true
        lastCategory = category
        if let error = mockError { throw error }
        return SearchService.CategoryBookmarksResult(bookmarks: mockBookmarksForFolder, actualCategory: category)
    }
}
