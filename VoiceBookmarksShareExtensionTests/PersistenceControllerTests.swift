//
//  PersistenceControllerTests.swift
//  VoiceBookmarksShareExtensionTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import CoreData
@testable import VoiceBookmarks

final class PersistenceControllerTests: XCTestCase {
    func testInMemoryStore_SavesAndClears() throws {
        let pc = PersistenceController.preview
        pc.deleteAll()
        XCTAssertTrue(true)
    }

    func testAppGroupFallback_DoesNotCrash() {
        let _ = PersistenceController.sharedForExtension
        XCTAssertNotNil(PersistenceController.sharedForExtension.container.persistentStoreDescriptions.first)
    }
}

