//
//  MockBookmarkService.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
@testable import VoiceBookmarks

final class MockBookmarkServiceSuccess: BookmarkService {
    override func deleteBookmark(id: String) async throws -> Bool { true }
}

final class MockBookmarkServiceFailure: BookmarkService {
    override func deleteBookmark(id: String) async throws -> Bool { false }
}

import Foundation
@testable import VoiceBookmarks

class MockBookmarkService: BookmarkService {
    
    var deleteBookmarkCalled = false
    var deletedBookmarkId: String?
    var deleteBookmarkShouldSucceed = true
    var deleteBookmarkError: Error?
    
    var createBookmarkCalled = false
    var mockCreateResponse = false
    var shouldFail = false
    var createBookmarkError: Error?
    
    override init(
        networkService: NetworkService = NetworkService(),
        fileService: FileServiceProtocol = FileService.shared
    ) {
        super.init(networkService: networkService, fileService: fileService)
    }
    
    override func deleteBookmark(id: String) async throws -> Bool {
        deleteBookmarkCalled = true
        deletedBookmarkId = id
        
        if let error = deleteBookmarkError {
            throw error
        }
        
        return deleteBookmarkShouldSucceed
    }
    
    override func createBookmark(filePath: String, voiceNote: String?, summary: String?) async throws -> Bool {
        createBookmarkCalled = true
        
        if shouldFail, let error = createBookmarkError {
            throw error
        }
        
        if shouldFail {
            throw APIError.networkError(NSError(domain: "MockBookmarkService", code: -1))
        }
        
        return mockCreateResponse
    }
}

