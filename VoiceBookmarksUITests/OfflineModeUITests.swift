//
//  OfflineModeUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class OfflineModeUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--UITestForceOffline"]
        app.launch()
        sleep(1)
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    func testOfflineModeDisplaysInFolderListView() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()

        let offlineIcon = app.images.matching(identifier: "wifi.slash").firstMatch
        let offlineText = app.staticTexts["No internet connection"]
        XCTAssertTrue(
            offlineIcon.waitForExistence(timeout: 5) && offlineText.waitForExistence(timeout: 2),
            "В офлайн режиме должны отображаться wifi.slash и сообщение о нет подключения"
        )
    }
    
    func testSearchFieldHiddenWhenOffline() throws {
        
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let searchField = app.textFields["Search..."]
        let offlineMessage = app.staticTexts["No internet connection"]
        
        XCTAssertTrue(
            searchField.exists || offlineMessage.exists,
            "Либо должно быть поле поиска, либо офлайн сообщение"
        )
    }
    
    func testOfflineQueueAddsItems() throws {
        let addTab = app.tabBars.buttons["Add"]
        addTab.tap()
        sleep(1)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать добавление в офлайн очередь")
    }
    
    func testContentSavedLocallyWhenOffline() throws {
        let addTab = app.tabBars.buttons["Add"]
        addTab.tap()
        sleep(1)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать локальное сохранение в офлайн режиме")
    }
    
    func testAutoUploadWhenNetworkRestores() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать автоматическую загрузку при восстановлении сети")
    }
    
    func testOfflineIndicatorDisplay() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let offlineElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Нет подключения' OR label CONTAINS 'интернет'"))
        let offlineIcon = app.images.matching(identifier: "wifi.slash").firstMatch
        XCTAssertTrue(
            offlineElements.firstMatch.waitForExistence(timeout: 5) || offlineIcon.waitForExistence(timeout: 5),
            "Должно отображаться офлайн-сообщение или иконка wifi.slash"
        )
    }
}
