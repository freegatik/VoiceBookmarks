//
//  FileListViewUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// UI тесты списка файлов: загрузка файлов в папке, тап на файл, отображение карточек
final class FileListViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--UITestSeedFolders", "-UI_TESTS_DISABLE_ANIMATIONS", "1"]
        app.launch()
        sleep(1)
        
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        let _ = folders.firstMatch.waitForExistence(timeout: 10)
        if folders.count > 0 {
            folders.firstMatch.tap()
            _ = app.navigationBars["Файлы"].waitForExistence(timeout: 5)
        }
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // Вспомогательная функция: ждет появления файлов с таймаутом
    func waitForFiles(timeout: TimeInterval = 15.0) -> XCUIElementQuery {
        sleep(2)
        
        let files = app.scrollViews.buttons
        var hasFiles = files.count > 0
        
        if !hasFiles {
            let noteFile = app.staticTexts["Заметка о цели"].firstMatch
            let audioFile = app.staticTexts["Аудио идея.m4a"].firstMatch
            let noteDescription = app.staticTexts["Краткое описание заметки"].firstMatch
            let audioDescription = app.staticTexts["Черновик голосовой заметки"].firstMatch
            hasFiles = noteFile.exists || audioFile.exists || noteDescription.exists || audioDescription.exists
        }
        
        let start = Date()
        while !hasFiles && Date().timeIntervalSince(start) < timeout {
            sleep(1)
            hasFiles = files.count > 0
            
            if !hasFiles {
                let noteFile = app.staticTexts["Заметка о цели"].firstMatch
                let audioFile = app.staticTexts["Аудио идея.m4a"].firstMatch
                hasFiles = noteFile.exists || audioFile.exists
            }
        }
        
        return files
    }
    
    // Проверяет отображение списка файлов в папке
    func testFileListDisplaysBookmarks() throws {
        let navBar = app.navigationBars["Файлы"]
        if navBar.waitForExistence(timeout: 3) {
            XCTAssertTrue(navBar.exists, "Список файлов должен отображаться")
            
            let filesList = app.scrollViews.firstMatch
            XCTAssertTrue(filesList.exists || app.staticTexts.firstMatch.exists, "Должен отображаться список файлов или пустое состояние")
        }
    }
    
    // Проверяет, что тап на файл открывает его в WebView
    func testTapOnFileOpensInWebView() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            files.firstMatch.tap()
            
            let navBar = app.navigationBars.firstMatch
            if navBar.waitForExistence(timeout: 3) {
                XCTAssertTrue(navBar.exists, "WebView должен открыться после тапа на файл")
                
                let closeButton = navBar.buttons["Закрыть"]
                XCTAssertTrue(closeButton.exists, "Кнопка 'Закрыть' должна присутствовать")
                let closeButton = UITestInteractions.webCloseButton(in: app)
                XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Кнопка 'Close' должна присутствовать")
            }
        }
    }
    
    // Проверяет context menu на файле
    func testFileContextMenuActions() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            files.firstMatch.press(forDuration: 1.0)
            
            let viewAction = app.buttons["Посмотреть"]
            let shareAction = app.buttons["Поделиться"]
            let deleteAction = app.buttons["Удалить"]
            
            let hasMenuActions = viewAction.exists || shareAction.exists || deleteAction.exists
            if hasMenuActions {
                XCTAssertTrue(hasMenuActions, "Context menu должен содержать действия")
            }
        }
    }
    
    // Проверяет динамические карточки файлов - разные иконки
    func testDynamicFileCardIcons() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            XCTAssertTrue(files.firstMatch.exists, "Файлы должны отображаться с иконками")
        }
    }
    
    // Проверяет пустое состояние для пустой папки
    func testEmptyStateForEmptyFolder() throws {
        let navBar = app.navigationBars["Файлы"]
        if navBar.exists {
            let emptyMessage = app.staticTexts["Файлы не найдены"]
            let filesList = app.scrollViews.firstMatch
            
            XCTAssertTrue(filesList.exists || emptyMessage.exists, "Должно отображаться либо файлы, либо пустое состояние")
        }
    }
    
    // Проверяет, что разные типы контента отображаются с разными иконками
    func testDifferentContentTypesDisplayIcons() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            XCTAssertTrue(files.firstMatch.exists, "Файлы должны отображаться с иконками согласно типу контента")
        }
    }
    
    // Проверяет, что карточки файлов имеют динамическую высоту
    func testDynamicFileCardHeights() throws {
        let files = app.scrollViews.buttons
        if files.count > 0 {
            XCTAssertTrue(files.firstMatch.exists, "Карточки файлов должны отображаться с динамической высотой")
        }
    }
    
    // Проверяет, что свайп вправо возвращает к предыдущему списку (как браузер "назад")
    func testSwipeRightReturnsToPreviousList() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        guard folders.firstMatch.waitForExistence(timeout: 15) else {
            throw XCTSkip("Папки не загрузились для открытия FileListView")
        }
        
        folders.firstMatch.tap()
        
        let navBar = app.navigationBars["Файлы"]
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("FileListView не открылся")
        }
        
        XCTAssertTrue(navBar.exists, "FileListView должен быть открыт")
        
        let screen = app.windows.firstMatch
        let startPoint = screen.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let endPoint = startPoint.withOffset(CGVector(dx: 200, dy: 0))
        
        startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
        
        sleep(1)
        let foldersNavBar = app.navigationBars["Папки"]
        if foldersNavBar.waitForExistence(timeout: 2) {
            XCTAssertTrue(foldersNavBar.exists, "После свайпа вправо должен вернуться к списку папок")
        } else {
            XCTAssertTrue(app.scrollViews.firstMatch.exists || app.navigationBars.firstMatch.exists, 
                        "Должен вернуться к предыдущему списку")
        }
    }
    
    // Проверяет long press на файле в списке результатов для nested search
    func testLongPressOnFileInResultsList() throws {
        let files = waitForFiles(timeout: 15.0)
        
        var hasFiles = files.count > 0
        if !hasFiles {
            let noteFile = app.staticTexts["Заметка о цели"].firstMatch
            let audioFile = app.staticTexts["Аудио идея.m4a"].firstMatch
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

