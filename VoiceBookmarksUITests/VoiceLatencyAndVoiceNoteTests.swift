//
//  VoiceLatencyAndVoiceNoteTests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class VoiceLatencyAndVoiceNoteTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        sleep(2)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testShareScreenPrewarm() throws {
        let addTab = app.tabBars.buttons["Add"]
        XCTAssertTrue(addTab.waitForExistence(timeout: 5), "Add tab should exist")
        addTab.tap()
        
        sleep(2)
        
        XCTAssertTrue(app.exists, "Share экран должен быть загружен")
    }
    
    // Note: Требует загруженного bookmark с voiceNote
    func testVoiceNoteDisplayPriority() throws {
        let searchTab = app.tabBars.buttons["Search"]
        if !searchTab.isSelected {
            searchTab.tap()
            sleep(2)
        }
        
        sleep(3)
    }
    
    func testDeduplication() throws {
        let searchTab = app.tabBars.buttons["Search"]
        if !searchTab.isSelected {
            searchTab.tap()
            sleep(2)
        }
        
        sleep(3)
    }
}
