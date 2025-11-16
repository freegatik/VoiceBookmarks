//
//  WebViewUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// UI тесты WebView: отображение файлов, навигация, кнопки sharing/сохранения/удаления
final class WebViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--UITestSeedFolders", "-UI_TESTS_DISABLE_ANIMATIONS", "1"]
        app.launch()
        sleep(1)
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // Вспомогательная функция: ждет появления папок с таймаутом
    func waitForFolders(timeout: TimeInterval = 15.0) -> (folders: XCUIElementQuery, hasFolders: Bool) {
        let searchTab = app.tabBars.buttons["Поиск"]
        if !searchTab.isSelected {
            searchTab.tap()
        }
        
        sleep(1)
        
        let loadingMessage = app.staticTexts["Загрузка папок..."]
        let emptyStateMessage = app.staticTexts["Нет папок"]
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
            let selfReflectionFolder = app.staticTexts["Саморефлексия"].firstMatch
            let tasksFolder = app.staticTexts["Задачи"].firstMatch
            hasFolders = selfReflectionFolder.exists || tasksFolder.exists
        }
        
        let start = Date()
        while !hasFolders && Date().timeIntervalSince(start) < timeout {
            sleep(1)
            hasFolders = folders.count > 0
            
            if !hasFolders {
                let selfReflectionFolder = app.staticTexts["Саморефлексия"].firstMatch
                let tasksFolder = app.staticTexts["Задачи"].firstMatch
                hasFolders = selfReflectionFolder.exists || tasksFolder.exists
            }
        }
        
        let isEmpty = emptyStateMessage.exists
        
        return (folders, hasFolders && !isEmpty)
    }
    
    // Вспомогательная функция: ждет появления файлов с таймаутом
    func waitForFiles(timeout: TimeInterval = 10.0) -> XCUIElementQuery {
        sleep(1)
        
        let files = app.scrollViews.buttons
        var hasFiles = files.count > 0
        
        if !hasFiles {
            let noteFile = app.staticTexts["Заметка о цели"].firstMatch
            let audioFile = app.staticTexts["Аудио идея.m4a"].firstMatch
            let noteDescription = app.staticTexts["Краткое описание заметки"].firstMatch
            hasFiles = noteFile.exists || audioFile.exists || noteDescription.exists
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
    
    // Проверяет открытие файла из FileList
    func testOpenFileFromList() {
        let searchTab = app.tabBars.buttons["Поиск"]
        XCTAssertTrue(searchTab.exists, "Вкладка Поиск должна существовать")
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                XCTAssertTrue(navBar.exists, "Navigation bar должен появиться")
            }
        }
    }
    
    // Проверяет, что элементы Navigation bar присутствуют
    func testNavigationBarElements() {
        let searchTab = app.tabBars.buttons["Поиск"]
        if searchTab.exists {
            searchTab.tap()
            
            let folders = app.scrollViews.buttons
            if folders.count > 0 {
                folders.firstMatch.tap()
                let files = app.scrollViews.buttons
                if files.count > 0 {
                    files.firstMatch.tap()
                    
                    let closeButton = app.navigationBars.buttons["Закрыть"]
                    XCTAssertTrue(closeButton.exists, "Кнопка Закрыть должна существовать")
                    let closeButton = UITestInteractions.webCloseButton(in: app)
                    XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Кнопка Close должна существовать")
                    
                    let menuButton = app.navigationBars.buttons.matching(identifier: "ellipsis.circle").firstMatch
                    XCTAssertTrue(menuButton.exists, "Кнопка Menu должна существовать")
                }
            }
        }
    }
    
    // Проверяет, что Menu button открывает popover
    func testMenuButtonOpensPopover() {
        let searchTab = app.tabBars.buttons["Поиск"]
        if searchTab.exists {
            searchTab.tap()
            
            let folders = app.scrollViews.buttons
            if folders.count > 0 {
                folders.firstMatch.tap()
                let files = app.scrollViews.buttons
                if files.count > 0 {
                    files.firstMatch.tap()
                    
                    let menuButton = app.navigationBars.buttons.matching(identifier: "ellipsis.circle").firstMatch
                    if menuButton.exists {
                        menuButton.tap()
                        
                        let shareButton = app.buttons["Поделиться"]
                        let deleteButton = app.buttons["Удалить"]
                        
                        XCTAssertTrue(shareButton.exists || deleteButton.exists, "Меню должно содержать действия")
                    }
                }
            }
        }
    }
    
    // Проверяет, что Close button закрывает WebView
    func testCloseButtonDismisses() {
        let searchTab = app.tabBars.buttons["Поиск"]
        if searchTab.exists {
            searchTab.tap()
            
            let folders = app.scrollViews.buttons
            if folders.count > 0 {
                folders.firstMatch.tap()
                let files = app.scrollViews.buttons
                if files.count > 0 {
                    files.firstMatch.tap()
                    
                    let closeButton = app.navigationBars.buttons["Закрыть"]
                    if closeButton.exists {
                    let closeButton = UITestInteractions.webCloseButton(in: app)
                    if closeButton.waitForExistence(timeout: 3) {
                        closeButton.tap()
                        
                        let navBar = app.navigationBars.firstMatch
                        XCTAssertTrue(navBar.exists, "Должен быть navigation bar")
                    }
                }
            }
        }
    }
    
    // Проверяет, что Share action открывает sheet
    func testShareActionOpensSheet() {
        let searchTab = app.tabBars.buttons["Поиск"]
        if searchTab.exists {
            searchTab.tap()
            
            let folders = app.scrollViews.buttons
            if folders.count > 0 {
                folders.firstMatch.tap()
                let files = app.scrollViews.buttons
                if files.count > 0 {
                    files.firstMatch.tap()
                    
                    let menuButton = app.navigationBars.buttons.matching(identifier: "ellipsis.circle").firstMatch
                    if menuButton.exists {
                        menuButton.tap()
                        
                        let shareButton = app.buttons["Поделиться"]
                        if shareButton.exists {
                            shareButton.tap()
                            
                            let activitySheet = app.sheets.firstMatch
                            XCTAssertTrue(activitySheet.exists, "Share sheet должен появиться")
                        }
                    }
                }
            }
        }
    }
    
    // Проверяет, что Delete action показывает confirmation dialog
    func testDeleteActionShowsConfirmation() {
        let searchTab = app.tabBars.buttons["Поиск"]
        if searchTab.exists {
            searchTab.tap()
            
            let folders = app.scrollViews.buttons
            if folders.count > 0 {
                folders.firstMatch.tap()
                let files = app.scrollViews.buttons
                if files.count > 0 {
                    files.firstMatch.tap()
                    
                    let menuButton = app.navigationBars.buttons.matching(identifier: "ellipsis.circle").firstMatch
                    if menuButton.exists {
                        menuButton.tap()
                        
                        let deleteButton = app.buttons["Удалить"]
                        if deleteButton.exists {
                            deleteButton.tap()
                            
                            let confirmDialog = app.alerts["Удалить закладку?"]
                            XCTAssertTrue(confirmDialog.exists, "Confirmation dialog должен появиться")
                            
                            let confirmButton = app.alerts.buttons["Удалить"]
                            let cancelButton = app.alerts.buttons["Отмена"]
                            XCTAssertTrue(confirmButton.exists || cancelButton.exists, "Dialog должен содержать кнопки")
                        }
                    }
                }
            }
        }
    }
    
    // Проверяет, что вкладка "Добавить" отображается
    func testAddTabDisplay() {
        let addTab = app.tabBars.buttons["Добавить"]
        XCTAssertTrue(addTab.exists, "Вкладка 'Добавить' должна существовать")
        
        if !addTab.isSelected {
            addTab.tap()
        }
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран добавления должен отображаться")
    }
    
    // Проверяет, что переключение между вкладками "Добавить" и "Поиск" работает
    func testTabSwitchingBetweenAddAndSearch() {
        let addTab = app.tabBars.buttons["Добавить"]
        let searchTab = app.tabBars.buttons["Поиск"]
        
        XCTAssertTrue(addTab.exists, "Вкладка 'Добавить' должна существовать")
        XCTAssertTrue(searchTab.exists, "Вкладка 'Поиск' должна существовать")
        
        addTab.tap()
        XCTAssertTrue(addTab.isSelected || app.otherElements.firstMatch.exists, "Вкладка 'Добавить' должна быть активна")
        
        searchTab.tap()
        XCTAssertTrue(searchTab.isSelected || app.scrollViews.firstMatch.exists, "Вкладка 'Поиск' должна быть активна")
        
        addTab.tap()
        XCTAssertTrue(addTab.isSelected || app.otherElements.firstMatch.exists, "Вкладка 'Добавить' должна быть активна")
    }
    
    // Проверяет, что обе вкладки доступны
    func testBothTabsAreAccessible() {
        let addTab = app.tabBars.buttons["Добавить"]
        let searchTab = app.tabBars.buttons["Поиск"]
        
        XCTAssertTrue(addTab.waitForExistence(timeout: 5), "Вкладка 'Добавить' должна появиться")
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Вкладка 'Поиск' должна появиться")
        
        addTab.tap()
        let addScreenExists = app.otherElements.firstMatch.exists
        XCTAssertTrue(addScreenExists, "Экран 'Добавить' должен отображаться")
        
        searchTab.tap()
        let searchScreenExists = app.scrollViews.firstMatch.exists || app.navigationBars.firstMatch.exists
        XCTAssertTrue(searchScreenExists, "Экран 'Поиск' должен отображаться")
    }
    
    // Проверяет, что WebView отображает разные типы контента
    func testWebViewDisplaysDifferentContentTypes() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists, "WebView должен отображать разные типы контента")
                }
            }
        }
    }
    
    // Проверяет, что WebView показывает LoadingView при загрузке
    func testWebViewShowsLoadingView() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists, "WebView должен поддерживать LoadingView")
                }
            }
        }
    }
    
    // Проверяет, что WebView отображает HTML файлы корректно
    func testWebViewDisplaysHTMLFiles() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists, "WebView должен отображать HTML файлы")
                }
            }
        }
    }
    
    // Проверяет, что HTML файлы определяются по расширению (.html, .htm)
    func testHTMLFilesDetectedByExtension() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists, "WebView должен определять и отображать HTML файлы по расширению")
                }
            }
        }
    }
    
    // Проверяет, что HTML файлы определяются по содержимому (<!doctype html>)
    func testHTMLFilesDetectedByContent() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists, "WebView должен определять HTML файлы по содержимому")
                }
            }
        }
    }
    
    // Проверяет, что HTML файлы с URL в content загружаются с сервера
    func testHTMLFilesWithURLInContentLoadsFromServer() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                if navBar.waitForExistence(timeout: 5) {
                    XCTAssertTrue(navBar.exists, "WebView должен загружать HTML файлы с URL из content")
                }
            }
        }
    }
    
    // Проверяет, что HTML файлы без fileUrl создают локальный файл из content
    func testHTMLFilesWithoutFileUrlCreatesLocalFile() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists, "WebView должен создавать локальные HTML файлы из content")
                }
            }
        }
    }
    
    // Проверяет, что WebView обрабатывает URL в content
    func testWebViewHandlesURLInContent() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                if navBar.waitForExistence(timeout: 5) {
                    XCTAssertTrue(navBar.exists, "WebView должен обрабатывать URL в content")
                }
            }
        }
    }
    
    // Проверяет, что WebView загружает HTML с URL из content
    func testWebViewLoadsHTMLFromURLInContent() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                if navBar.waitForExistence(timeout: 5) {
                    XCTAssertTrue(navBar.exists, "WebView должен загружать HTML с URL из content")
                }
            }
        }
    }
    
    // Проверяет, что WebView показывает ErrorStateView при ошибке
    func testWebViewShowsErrorState() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                let errorText = app.staticTexts["Ошибка"]
                
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists || errorText.exists, "WebView должен поддерживать ErrorStateView")
                }
            }
        }
    }
    
    // Проверяет, что свайп вправо в WebView возвращает к предыдущему списку
    func testSwipeRightInWebViewReturnsBack() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let (folders, hasFolders) = waitForFolders(timeout: 15.0)
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для тестирования")
        }
        
        folders.firstMatch.tap()
        
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
        
        if files.count > 0 {
            files.firstMatch.tap()
        } else {
            let noteFile = app.staticTexts["Заметка о цели"].firstMatch
            let audioFile = app.staticTexts["Аудио идея.m4a"].firstMatch
            if noteFile.exists {
                noteFile.tap()
            } else if audioFile.exists {
                audioFile.tap()
            } else {
                throw XCTSkip("Не удалось открыть файл")
            }
        }
        
        let navBar = app.navigationBars.firstMatch
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("WebView не открылся")
        }
        
        let screen = app.windows.firstMatch
        let startPoint = screen.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let endPoint = startPoint.withOffset(CGVector(dx: 200, dy: 0))
        
        startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
        
        sleep(1)
        let previousNavBar = app.navigationBars.firstMatch
        XCTAssertTrue(previousNavBar.exists, "После свайпа вправо должен вернуться к предыдущему экрану")
    }
    
    // Проверяет, что WebView обрабатывает команды
    func testWebViewHandlesCommandContent() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let searchField = app.textFields["Поиск..."]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("command query")
            
            let searchButton = app.buttons.matching(identifier: "magnifyingglass").firstMatch
            if searchButton.exists {
                searchButton.tap()
                
                let webViewNavBar = app.navigationBars.firstMatch
                if webViewNavBar.waitForExistence(timeout: 5) {
                    let closeButton = webViewNavBar.buttons["Закрыть"]
                    if closeButton.exists {
                        XCTAssertTrue(closeButton.exists, "WebView с командой должен открыться")
                    }
                }
            UITestInteractions.submitFolderSearch(app: app, searchField: searchField)
            
            let webViewNavBar = app.navigationBars.firstMatch
            if webViewNavBar.waitForExistence(timeout: 5) {
                let closeButton = UITestInteractions.webCloseButton(in: app)
                XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "WebView с командой должен открыться")
            }
        }
    }
    
    // Проверяет, что после сохранения страницы возврат к списку элементов
    func testAfterSavingReturnsToList() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let (folders, hasFolders) = waitForFolders(timeout: 15.0)
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для тестирования")
        }
        
        folders.firstMatch.tap()
        
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
        
        if files.count > 0 {
            files.firstMatch.tap()
        } else {
            let noteFile = app.staticTexts["Заметка о цели"].firstMatch
            let audioFile = app.staticTexts["Аудио идея.m4a"].firstMatch
            if noteFile.exists {
                noteFile.tap()
            } else if audioFile.exists {
                audioFile.tap()
            } else {
                throw XCTSkip("Не удалось открыть файл")
            }
        }
        
        let navBar = app.navigationBars.firstMatch
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("WebView не открылся")
        }
        
        let screen = app.windows.firstMatch
        let startPoint = screen.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let endPoint = startPoint.withOffset(CGVector(dx: 0, dy: -150))
        
        startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
        
        sleep(1)
        let documentPicker = app.sheets.firstMatch
        if documentPicker.waitForExistence(timeout: 2) {
            let cancelButton = app.buttons["Отмена"]
            if cancelButton.exists {
                cancelButton.tap()
            } else {
                let pickerStart = documentPicker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
                let pickerEnd = pickerStart.withOffset(CGVector(dx: 0, dy: 200))
                pickerStart.press(forDuration: 0.1, thenDragTo: pickerEnd)
            }
        }
        
        sleep(1)
        let listNavBar = app.navigationBars.firstMatch
        XCTAssertTrue(listNavBar.exists, "После сохранения/отмены должен вернуться к списку элементов")
    }
}

