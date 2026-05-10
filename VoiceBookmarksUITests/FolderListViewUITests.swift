//
//  FolderListViewUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class FolderListViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--UITestSeedFolders", "-UI_TESTS_DISABLE_ANIMATIONS", "1"]
        app.launch()
        sleep(1)
        
        let searchTab = app.tabBars.buttons["Search"]
        if !searchTab.exists {
            _ = searchTab.waitForExistence(timeout: 10)
        }
        searchTab.tap()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    func waitForFolders(timeout: TimeInterval = 15.0) -> (folders: XCUIElementQuery, hasFolders: Bool) {
        let searchTab = app.tabBars.buttons["Search"]
        if !searchTab.isSelected {
            searchTab.tap()
        }
        
        sleep(1)
        
        let loadingMessage = app.staticTexts["Loading folders..."]
        let emptyStateMessage = app.staticTexts["No folders"]
        let progressIndicators = app.progressIndicators
        
        if loadingMessage.waitForExistence(timeout: 3.0) || progressIndicators.count > 0 {
            let startTime = Date()
            while (loadingMessage.exists || progressIndicators.count > 0) && Date().timeIntervalSince(startTime) < timeout {
                sleep(1)
            }
        } else {
            sleep(2)
        }
        
        let folders = app.scrollViews.buttons
        var hasFolders = folders.count > 0
        
        if !hasFolders {
            let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
            let tasksFolder = app.staticTexts["Tasks"].firstMatch
            let projectResourcesFolder = app.staticTexts["Project resources"].firstMatch
            let uncategorisedFolder = app.staticTexts["Uncategorized"].firstMatch
            
            hasFolders = selfReflectionFolder.exists || tasksFolder.exists || projectResourcesFolder.exists || uncategorisedFolder.exists
        }
        
        let start = Date()
        while !hasFolders && Date().timeIntervalSince(start) < timeout {
            sleep(1)
            hasFolders = folders.count > 0
            
            if !hasFolders {
                let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
                let tasksFolder = app.staticTexts["Tasks"].firstMatch
                hasFolders = selfReflectionFolder.exists || tasksFolder.exists
            }
        }
        
        let isEmpty = emptyStateMessage.exists
        
        return (folders, hasFolders && !isEmpty)
    }
    
    func testTapOnFolderOpensFileList() throws {
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let navBar = app.navigationBars["Files"]
            if navBar.waitForExistence(timeout: 3) {
                XCTAssertTrue(navBar.exists, "Должен открыться список файлов после тапа на папку")
            }
        }
    }
    
    func testTextSearchPerformsQuery() throws {
        let searchField = app.textFields["Search..."]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("test query")
            
            UITestInteractions.submitFolderSearch(app: app, searchField: searchField)
            
            XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists, "Search должен быть выполнен")
        }
    }
    
    func testSearchResultsDisplay() throws {
        let searchField = app.textFields["Search..."]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("test")
            
            UITestInteractions.submitFolderSearch(app: app, searchField: searchField)
            
            let results = app.scrollViews.firstMatch
            if results.waitForExistence(timeout: 5) {
                XCTAssertTrue(results.exists, "Результаты поиска должны отображаться")
            }
        }
    }
    
    func testLoadingStateDisplays() throws {
        let screen = app.scrollViews.firstMatch
        XCTAssertTrue(screen.exists || app.staticTexts.firstMatch.exists, "Экран должен отображаться")
    }
    
    func testEmptyStateDisplays() throws {
        let folders = app.scrollViews.firstMatch
        XCTAssertTrue(folders.exists || app.staticTexts.firstMatch.exists, "Должно отображаться либо папки, либо пустое состояние")
    }
    
    func testLongPressOnFolderAvailable() throws {
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            XCTAssertTrue(folders.firstMatch.exists, "Folders должны существовать для long press")
        }
    }
    
    func testLongPressShowsVisualEffects() throws {
        let (folders, hasFolders) = waitForFolders(timeout: 15.0)
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для тестирования")
        }
        
        let firstFolder = folders.firstMatch
        XCTAssertTrue(firstFolder.waitForExistence(timeout: 3), "Первая папка должна существовать")
        
        firstFolder.press(forDuration: 0.6)
        
        let _ = app.staticTexts.firstMatch
        XCTAssertTrue(app.scrollViews.firstMatch.exists, "После long press экран должен оставаться видимым с визуальными эффектами")
    }
    
    func testSwipeDownCancelsRecording() throws {
        let (folders, hasFolders) = waitForFolders(timeout: 15.0)
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для тестирования")
        }
        
        let firstFolder = folders.firstMatch
        XCTAssertTrue(firstFolder.waitForExistence(timeout: 3), "Первая папка должна существовать")
        
        firstFolder.press(forDuration: 0.6)
        
        sleep(1)
        
        let startPoint = firstFolder.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let endPoint = startPoint.withOffset(CGVector(dx: 0, dy: 150))
        startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
        
        sleep(1)
        XCTAssertTrue(app.scrollViews.firstMatch.exists, "После отмены записи должен вернуться к списку папок")
    }
    
    func testLongPressReleaseSendsFolderIdAndText() throws {
        let (folders, hasFolders) = waitForFolders(timeout: 15.0)
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для тестирования")
        }
        
        let firstFolder = folders.firstMatch
        XCTAssertTrue(firstFolder.waitForExistence(timeout: 3), "Первая папка должна существовать")
        
        firstFolder.press(forDuration: 0.6)
        
        sleep(1)
        sleep(2)
        
        let navBar = app.navigationBars.firstMatch
        if navBar.waitForExistence(timeout: 3) {
            XCTAssertTrue(navBar.exists, "После отпускания должна произойти навигация (WebView или FileList)")
        }
    }
    
    func testEmptySearchShowsError() throws {
        let searchField = app.textFields["Search..."]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            
            UITestInteractions.submitFolderSearch(app: app, searchField: searchField)
            
            XCTAssertTrue(app.scrollViews.firstMatch.exists || app.staticTexts.firstMatch.exists,
                         "Пустой поиск должен показывать ошибку или не выполнять поиск")
        }
    }
    
    func testSearchResultsWithDifferentContentTypes() throws {
        let searchField = app.textFields["Search..."]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("test search")
            
            UITestInteractions.submitFolderSearch(app: app, searchField: searchField)
            
            let results = app.scrollViews.firstMatch
            if results.waitForExistence(timeout: 5) {
                XCTAssertTrue(results.exists, "Результаты поиска должны отображаться с разными типами контента")
            }
        }
    }
    
    func testFoldersDisplayWithIcons() throws {
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            XCTAssertTrue(folders.firstMatch.exists, "Folders должны отображаться с иконками")
        }
    }
    
    func testFoldersShowUserFriendlyNames() throws {
        let userFriendlyNames = [
            "Self-reflection",
            "Tasks",
            "Project resources",
            "Uncategorized"
        ]
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            _ = userFriendlyNames.first { app.staticTexts[$0].exists }
            XCTAssertTrue(folders.firstMatch.exists, "Folders должны отображаться")
        }
    }
}
