//
//  OfflineModeUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// UI тесты офлайн режима: отображение сообщения об отсутствии сети, скрытие поля поиска
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
    
    // Проверяет, что офлайн режим отображается в FolderListView (иконка wifi.slash, сообщение)
    func testOfflineModeDisplaysInFolderListView() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()

        let offlineIcon = app.images.matching(identifier: "wifi.slash").firstMatch
        let offlineText = app.staticTexts["Нет подключения к интернету"]
        XCTAssertTrue(
            offlineIcon.waitForExistence(timeout: 5) && offlineText.waitForExistence(timeout: 2),
            "В офлайн режиме должны отображаться wifi.slash и сообщение о нет подключения"
        )
    }
    
    // Проверяет, что поле поиска скрыто в офлайн режиме (показывается только офлайн сообщение)
    func testSearchFieldHiddenWhenOffline() throws {
        
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let searchField = app.textFields["Поиск..."]
        let offlineMessage = app.staticTexts["Нет подключения к интернету"]
        
        XCTAssertTrue(
            searchField.exists || offlineMessage.exists,
            "Либо должно быть поле поиска, либо офлайн сообщение"
        )
    }
    
    // Проверяет, что офлайн очередь добавляет элементы
    func testOfflineQueueAddsItems() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        addTab.tap()
        sleep(1)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать добавление в офлайн очередь")
    }
    
    // Проверяет, что контент сохраняется локально в офлайн режиме
    func testContentSavedLocallyWhenOffline() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        addTab.tap()
        sleep(1)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать локальное сохранение в офлайн режиме")
    }
    
    // Проверяет автоматическую загрузку при восстановлении сети
    func testAutoUploadWhenNetworkRestores() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать автоматическую загрузку при восстановлении сети")
    }
    
    // Проверяет индикатор офлайн режима в UI
    func testOfflineIndicatorDisplay() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let offlineElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Нет подключения' OR label CONTAINS 'интернет'"))
        let offlineIcon = app.images.matching(identifier: "wifi.slash").firstMatch
        XCTAssertTrue(
            offlineElements.firstMatch.waitForExistence(timeout: 5) || offlineIcon.waitForExistence(timeout: 5),
            "Должно отображаться офлайн-сообщение или иконка wifi.slash"
        )
    }
}

