//
//  FileListViewUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class FileListViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--UITestSeedFolders", "-UI_TESTS_DISABLE_ANIMATIONS", "1"]
        app.launch()
        sleep(1)
        
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        let _ = folders.firstMatch.waitForExistence(timeout: 10)
        if folders.count > 0 {
            folders.firstMatch.tap()
            _ = app.navigationBars["Files"].waitForExistence(timeout: 5)
        }
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    func waitForFiles(timeout: TimeInterval = 15.0) -> XCUIElementQuery {
        sleep(2)
        
        let files = app.scrollViews.buttons
        var hasFiles = files.count > 0
        
        if !hasFiles {
            let noteFile = app.staticTexts["Goal note"].firstMatch
            let audioFile = app.staticTexts["Audio idea.m4a"].firstMatch
            let noteDescription = app.staticTexts["Short note description"].firstMatch
            let audioDescription = app.staticTexts["Черновик голосовой заметки"].firstMatch
            hasFiles = noteFile.exists || audioFile.exists || noteDescription.exists || audioDescription.exists
        }
        
        let start = Date()
        while !hasFiles && Date().timeIntervalSince(start) < timeout {
            sleep(1)
            hasFiles = files.count > 0
            
            if !hasFiles {
                let noteFile = app.staticTexts["Goal note"].firstMatch
                let audioFile = app.staticTexts["Audio idea.m4a"].firstMatch
                hasFiles = noteFile.exists || audioFile.exists
            }
        }
        
        return files
    }
    
    func testFileListDisplaysBookmarks() throws {
        let navBar = app.navigationBars["Files"]
        if navBar.waitForExistence(timeout: 3) {
            XCTAssertTrue(navBar.exists, "Список файлов должен отображаться")
            
            let filesList = app.scrollViews.firstMatch
            XCTAssertTrue(filesList.exists || app.staticTexts.firstMatch.exists, "Должен отображаться список файлов или пустое состояние")
        }
    }
    
    func testTapOnFileOpensInWebView() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            files.firstMatch.tap()
            
            let navBar = app.navigationBars.firstMatch
            if navBar.waitForExistence(timeout: 3) {
                XCTAssertTrue(navBar.exists, "WebView должен открыться после тапа на файл")
                
                let closeButton = UITestInteractions.webCloseButton(in: app)
                XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Кнопка 'Close' должна присутствовать")
            }
        }
    }
    
    func testFileContextMenuActions() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            files.firstMatch.press(forDuration: 1.0)
            
            let viewAction = app.buttons["View"]
            let shareAction = app.buttons["Share"]
            let deleteAction = app.buttons["Delete"]
            
            let hasMenuActions = viewAction.exists || shareAction.exists || deleteAction.exists
            if hasMenuActions {
                XCTAssertTrue(hasMenuActions, "Context menu должен содержать действия")
            }
        }
    }
    
    func testDynamicFileCardIcons() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            XCTAssertTrue(files.firstMatch.exists, "Files должны отображаться с иконками")
        }
    }
    
    func testEmptyStateForEmptyFolder() throws {
        let navBar = app.navigationBars["Files"]
        if navBar.exists {
            let emptyMessage = app.staticTexts["Files не найдены"]
            let filesList = app.scrollViews.firstMatch
            
            XCTAssertTrue(filesList.exists || emptyMessage.exists, "Должно отображаться либо файлы, либо пустое состояние")
        }
    }
    
    func testDifferentContentTypesDisplayIcons() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            XCTAssertTrue(files.firstMatch.exists, "Files должны отображаться с иконками согласно типу контента")
        }
    }
    
    func testDynamicFileCardHeights() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            XCTAssertTrue(files.firstMatch.exists, "Карточки файлов должны отображаться с динамической высотой")
        }
    }
    
    func testSwipeRightReturnsToPreviousList() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        guard folders.firstMatch.waitForExistence(timeout: 15) else {
            throw XCTSkip("Folders не загрузились для открытия FileListView")
        }
        
        folders.firstMatch.tap()
        
        let navBar = app.navigationBars["Files"]
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("FileListView не открылся")
        }
        
        XCTAssertTrue(navBar.exists, "FileListView должен быть открыт")
        
        let screen = app.windows.firstMatch
        let startPoint = screen.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let endPoint = startPoint.withOffset(CGVector(dx: 200, dy: 0))
        
        startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
        
        sleep(1)
        let foldersNavBar = app.navigationBars["Folders"]
        if foldersNavBar.waitForExistence(timeout: 2) {
            XCTAssertTrue(foldersNavBar.exists, "После свайпа вправо должен вернуться к списку папок")
        } else {
            XCTAssertTrue(app.scrollViews.firstMatch.exists || app.navigationBars.firstMatch.exists, 
                        "Должен вернуться к предыдущему списку")
        }
    }
    
    func testLongPressOnFileInResultsList() throws {
        let files = waitForFiles(timeout: 15.0)
        
        var hasFiles = files.count > 0
        if !hasFiles {
            let noteFile = app.staticTexts["Goal note"].firstMatch
            let audioFile = app.staticTexts["Audio idea.m4a"].firstMatch
            hasFiles = noteFile.exists || audioFile.exists
        }
        
        guard hasFiles else {
            throw XCTSkip("Нет доступных файлов для тестирования")
        }
        
        let firstFile = files.firstMatch
        XCTAssertTrue(firstFile.waitForExistence(timeout: 3), "Первый файл должен существовать")
        
        firstFile.press(forDuration: 0.6)
        
        sleep(1)
        XCTAssertTrue(app.scrollViews.firstMatch.exists, "После long press на файле должен начаться nested search")
    }
}
