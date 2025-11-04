//
//  VoiceBookmarksTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class VoiceBookmarksTests: XCTestCase {

    func testAppInitialization() async throws {
        let networkService = NetworkService()
        XCTAssertNotNil(networkService)
        
        let keychainService = KeychainService.shared
        XCTAssertNotNil(keychainService)
        
        let authService = AuthService(
            networkService: networkService,
            keychainService: keychainService
        )
        XCTAssertNotNil(authService)
    }
    
    func testCoreServicesAvailable() async throws {
        let keychainService = KeychainService.shared
        XCTAssertNotNil(keychainService)
        
        let fileService = FileService.shared
        XCTAssertNotNil(fileService)
        
        let clipboardService = ClipboardService.shared
        XCTAssertNotNil(clipboardService)
        
        let offlineQueueService = OfflineQueueService.shared
        XCTAssertNotNil(offlineQueueService)
        
        let speechService = SpeechService.shared
        XCTAssertNotNil(speechService)
    }
    
    func testConstantsDefined() async throws {
        XCTAssertFalse(Constants.API.baseURL.isEmpty)
        XCTAssertFalse(Constants.CoreData.modelName.isEmpty)
        XCTAssertGreaterThan(Constants.Speech.longPressDuration, 0)
        XCTAssertGreaterThan(Constants.UI.animationDuration, 0)
    }
}
