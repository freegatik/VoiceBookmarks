//
//  MockKeychainService.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
@testable import VoiceBookmarks

class MockKeychainService: KeychainServiceProtocol {
    
    var mockUserId: String?
    var saveUserIdCalled = false
    var getUserIdCalled = false
    var deleteUserIdCalled = false
    
    func saveUserId(_ userId: String) async -> Bool {
        saveUserIdCalled = true
        mockUserId = userId
        return true
    }
    
    func getUserId() -> String? {
        getUserIdCalled = true
        return mockUserId
    }
    
    func deleteUserId() -> Bool {
        deleteUserIdCalled = true
        mockUserId = nil
        return true
    }
}
