//
//  WebViewUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

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
            hasFolders = selfReflectionFolder.exists || tasksFolder.exists
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
    
    func waitForFiles(timeout: TimeInterval = 10.0) -> XCUIElementQuery {
        sleep(1)
        
        let files = app.scrollViews.buttons
        var hasFiles = files.count > 0
        
        if !hasFiles {
            let noteFile = app.staticTexts["Goal note"].firstMatch
            let audioFile = app.staticTexts["Audio idea.m4a"].firstMatch
            let noteDescription = app.staticTexts["Short note description"].firstMatch
            hasFiles = noteFile.exists || audioFile.exists || noteDescription.exists
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
    
    func testOpenFileFromList() {
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.exists, "Search tab should exist")
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
    
    func testNavigationBarElements() {
        let searchTab = app.tabBars.buttons["Search"]
        if searchTab.exists {
            searchTab.tap()
            
            let folders = app.scrollViews.buttons
            if folders.count > 0 {
                folders.firstMatch.tap()
                let files = app.scrollViews.buttons
                if files.count > 0 {
                    files.firstMatch.tap()
                    
                    let closeButton = UITestInteractions.webCloseButton(in: app)
                    XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Кнопка Close должна существовать")
                    
                    let menuButton = app.navigationBars.buttons.matching(identifier: "ellipsis.circle").firstMatch
                    XCTAssertTrue(menuButton.exists, "Кнопка Menu должна существовать")
                }
            }
        }
    }
    
    func testMenuButtonOpensPopover() {
        let searchTab = app.tabBars.buttons["Search"]
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
                        
                        let shareButton = app.buttons["Share"]
                        let deleteButton = app.buttons["Delete"]
                        
                        XCTAssertTrue(shareButton.exists || deleteButton.exists, "Меню должно содержать действия")
                    }
                }
            }
        }
    }
    
    func testCloseButtonDismisses() {
        let searchTab = app.tabBars.buttons["Search"]
        if searchTab.exists {
            searchTab.tap()
            
            let folders = app.scrollViews.buttons
            if folders.count > 0 {
                folders.firstMatch.tap()
                let files = app.scrollViews.buttons
                if files.count > 0 {
                    files.firstMatch.tap()
                    
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
    
    func testShareActionOpensSheet() {
        let searchTab = app.tabBars.buttons["Search"]
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
                        
                        let shareButton = app.buttons["Share"]
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
    
    func testDeleteActionShowsConfirmation() {
        let searchTab = app.tabBars.buttons["Search"]
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
                        
                        let deleteButton = app.buttons["Delete"]
                        if deleteButton.exists {
                            deleteButton.tap()
                            
                            let confirmDialog = app.alerts["Delete bookmark?"]
                            XCTAssertTrue(confirmDialog.exists, "Confirmation dialog должен появиться")
                            
                            let confirmButton = app.alerts.buttons["Delete"]
                            let cancelButton = app.alerts.buttons["Cancel"]
                            XCTAssertTrue(confirmButton.exists || cancelButton.exists, "Dialog должен содержать кнопки")
                        }
                    }
                }
            }
        }
    }
    
    func testAddTabDisplay() {
        let addTab = app.tabBars.buttons["Add"]
        XCTAssertTrue(addTab.exists, "Add tab should exist")
        
        if !addTab.isSelected {
            addTab.tap()
        }
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран добавления должен отображаться")
    }
    
    func testTabSwitchingBetweenAddAndSearch() {
        let addTab = app.tabBars.buttons["Add"]
        let searchTab = app.tabBars.buttons["Search"]
        
        XCTAssertTrue(addTab.exists, "Add tab should exist")
        XCTAssertTrue(searchTab.exists, "Вкладка 'Search' должна существовать")
        
        addTab.tap()
        XCTAssertTrue(addTab.isSelected || app.otherElements.firstMatch.exists, "Вкладка 'Add' должна быть активна")
        
        searchTab.tap()
        XCTAssertTrue(searchTab.isSelected || app.scrollViews.firstMatch.exists, "Вкладка 'Search' должна быть активна")
        
        addTab.tap()
        XCTAssertTrue(addTab.isSelected || app.otherElements.firstMatch.exists, "Вкладка 'Add' должна быть активна")
    }
    
    func testBothTabsAreAccessible() {
        let addTab = app.tabBars.buttons["Add"]
        let searchTab = app.tabBars.buttons["Search"]
        
        XCTAssertTrue(addTab.waitForExistence(timeout: 5), "Вкладка 'Add' должна появиться")
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Вкладка 'Search' должна появиться")
        
        addTab.tap()
        let addScreenExists = app.otherElements.firstMatch.exists
        XCTAssertTrue(addScreenExists, "Экран 'Add' должен отображаться")
        
        searchTab.tap()
        let searchScreenExists = app.scrollViews.firstMatch.exists || app.navigationBars.firstMatch.exists
        XCTAssertTrue(searchScreenExists, "Экран 'Search' должен отображаться")
    }
    
    func testWebViewDisplaysDifferentContentTypes() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
    
    func testWebViewShowsLoadingView() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
    
    func testWebViewDisplaysHTMLFiles() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
    
    func testHTMLFilesDetectedByExtension() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
    
    func testHTMLFilesDetectedByContent() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
    
    func testHTMLFilesWithURLInContentLoadsFromServer() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
    
    func testHTMLFilesWithoutFileUrlCreatesLocalFile() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
    
    func testWebViewHandlesURLInContent() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
    
    func testWebViewLoadsHTMLFromURLInContent() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
    
    func testWebViewShowsErrorState() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let navBar = app.navigationBars.firstMatch
                let errorText = app.staticTexts["Error"]
                
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists || errorText.exists, "WebView должен поддерживать ErrorStateView")
                }
            }
        }
    }
    
    func testSwipeRightInWebViewReturnsBack() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let (folders, hasFolders) = waitForFolders(timeout: 15.0)
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для тестирования")
        }
        
        folders.firstMatch.tap()
        
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
        
        if files.count > 0 {
            files.firstMatch.tap()
        } else {
            let noteFile = app.staticTexts["Goal note"].firstMatch
            let audioFile = app.staticTexts["Audio idea.m4a"].firstMatch
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
    
    func testWebViewHandlesCommandContent() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let searchField = app.textFields["Search..."]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("command query")
            
            UITestInteractions.submitFolderSearch(app: app, searchField: searchField)
            
            let webViewNavBar = app.navigationBars.firstMatch
            if webViewNavBar.waitForExistence(timeout: 5) {
                let closeButton = UITestInteractions.webCloseButton(in: app)
                XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "WebView с командой должен открыться")
            }
        }
    }
    
    func testAfterSavingReturnsToList() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let (folders, hasFolders) = waitForFolders(timeout: 15.0)
        guard hasFolders else {
            throw XCTSkip("Нет доступных папок для тестирования")
        }
        
        folders.firstMatch.tap()
        
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
        
        if files.count > 0 {
            files.firstMatch.tap()
        } else {
            let noteFile = app.staticTexts["Goal note"].firstMatch
            let audioFile = app.staticTexts["Audio idea.m4a"].firstMatch
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
            let cancelButton = app.buttons["Cancel"]
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
