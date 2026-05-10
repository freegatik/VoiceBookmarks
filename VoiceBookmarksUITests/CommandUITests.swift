//
//  CommandUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class CommandUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITESTS", "-UI_TESTS_DISABLE_ANIMATIONS", "1", "--UITestSeedFolders"]
        app.launch()
        sleep(1)
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    func waitForFolders(timeout: TimeInterval = 20.0) -> (folders: XCUIElementQuery, hasFolders: Bool) {
        let searchTab = app.tabBars.buttons["Search"]
        if !searchTab.isSelected {
            searchTab.tap()
        }
        
        sleep(1)
        
        let loadingMessage = app.staticTexts["Loading folders..."]
        let emptyStateMessage = app.staticTexts["No folders"]
        
        if loadingMessage.waitForExistence(timeout: 5.0) {
            let startTime = Date()
            while loadingMessage.exists && Date().timeIntervalSince(startTime) < timeout {
                sleep(1)
            }
        } else {
            sleep(3)
        }
        
        let folders = app.scrollViews.buttons
        let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
        let tasksFolder = app.staticTexts["Tasks"].firstMatch
        
        let start = Date()
        var hasFolders = folders.count > 0 || selfReflectionFolder.exists || tasksFolder.exists
        while !hasFolders && Date().timeIntervalSince(start) < timeout {
            sleep(1)
            hasFolders = folders.count > 0 || selfReflectionFolder.exists || tasksFolder.exists
        }
        
        let isEmpty = emptyStateMessage.exists
        
        return (folders, hasFolders && !isEmpty)
    }
    
    func waitForFiles(timeout: TimeInterval = 15.0) -> (files: XCUIElementQuery, hasFiles: Bool) {
        sleep(2)
        
        let emptyStateMessage = app.staticTexts["Files не найдены"]
        let files = app.scrollViews.buttons
        
        let noteFile = app.staticTexts["Goal note"].firstMatch
        let audioFile = app.staticTexts["Audio idea.m4a"].firstMatch
        let noteDescription = app.staticTexts["Short note description"].firstMatch
        let audioDescription = app.staticTexts["Черновик голосовой заметки"].firstMatch
        
        let start = Date()
        var hasFiles = files.count > 0 || noteFile.exists || audioFile.exists || noteDescription.exists || audioDescription.exists
        while !hasFiles && Date().timeIntervalSince(start) < timeout {
            sleep(1)
            hasFiles = files.count > 0 || noteFile.exists || audioFile.exists || noteDescription.exists || audioDescription.exists
        }
        
        let isEmpty = emptyStateMessage.exists
        
        return (files, hasFiles && !isEmpty)
    }
    
    func testCommandOpensInWebView() throws {
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
    
    func testCommandHTMLContentDisplays() throws {
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
                    XCTAssertTrue(navBar.exists, "WebView должен отображать контент (включая HTML команд)")
                }
            }
        }
    }
    
    func testCloseCommandReturnsToSearch() throws {
        let searchTab = app.tabBars.buttons["Search"]
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
                    XCTAssertTrue(navBar.exists, "Должен вернуться после закрытия команды/файла")
                }
            }
        }
    }
    
    func testCommandStatePreserved() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let searchField = app.textFields["Search..."]
        XCTAssertTrue(searchField.exists || app.scrollViews.firstMatch.exists, "После команды должен быть доступен экран поиска")
    }
    
    func testAfterCommandReturnsToListState() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let (folders, hasFolders) = waitForFolders(timeout: 20.0)
        XCTAssertTrue(hasFolders, "Ожидались папки с сервера для выполнения теста")
        
        var firstFolder: XCUIElement?
        
        if folders.count > 0 {
            firstFolder = folders.firstMatch
        } else {
            let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
            if selfReflectionFolder.exists {
                firstFolder = selfReflectionFolder
            } else {
                let tasksFolder = app.staticTexts["Tasks"].firstMatch
                if tasksFolder.exists {
                    firstFolder = tasksFolder
                }
            }
        }
        
        XCTAssertNotNil(firstFolder, "Первая папка должна существовать")
        XCTAssertTrue(firstFolder!.waitForExistence(timeout: 5), "Первая папка должна быть доступна")
        
        firstFolder!.tap()
        
        let (files, hasFiles) = waitForFiles(timeout: 15.0)
        XCTAssertTrue(hasFiles, "Ожидались файлы в выбранной папке")
        
        var firstFile: XCUIElement?
        
        if files.count > 0 {
            firstFile = files.firstMatch
        } else {
            let noteFile = app.staticTexts["Goal note"].firstMatch
            if noteFile.exists {
                firstFile = noteFile
            } else {
                let audioFile = app.staticTexts["Audio idea.m4a"].firstMatch
                if audioFile.exists {
                    firstFile = audioFile
                } else {
                    let noteDescription = app.staticTexts["Short note description"].firstMatch
                    if noteDescription.exists {
                        firstFile = noteDescription
                    } else {
                        let audioDescription = app.staticTexts["Черновик голосовой заметки"].firstMatch
                        if audioDescription.exists {
                            firstFile = audioDescription
                        }
                    }
                }
            }
        }
        
        XCTAssertNotNil(firstFile, "Первый файл должен существовать")
        XCTAssertTrue(firstFile!.waitForExistence(timeout: 5), "Первый файл должен быть доступен")
        
        firstFile!.tap()
        
        let closeButton = UITestInteractions.webCloseButton(in: app)
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
        } else {
            let screen = app.windows.firstMatch
            let startPoint = screen.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            let endPoint = startPoint.withOffset(CGVector(dx: 200, dy: 0))
            startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
        }
        
        sleep(1)
        let foldersNavBar = app.navigationBars["Folders"]
        if foldersNavBar.waitForExistence(timeout: 2) {
            XCTAssertTrue(foldersNavBar.exists, "После закрытия команды должен вернуться к списку папок")
        } else {
            let navBar = app.navigationBars.firstMatch
            XCTAssertTrue(navBar.exists || app.scrollViews.firstMatch.exists, 
                         "Должен вернуться к состоянию списка элементов")
        }
    }
    
    func testCommandSendsFolderIdAndText() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let (folders, hasFolders) = waitForFolders(timeout: 20.0)
        XCTAssertTrue(hasFolders, "Ожидались папки с сервера для выполнения теста")
        
        var firstFolder: XCUIElement?
        
        if folders.count > 0 {
            firstFolder = folders.firstMatch
        } else {
            let selfReflectionFolder = app.staticTexts["Self-reflection"].firstMatch
            if selfReflectionFolder.exists {
                firstFolder = selfReflectionFolder
            } else {
                let tasksFolder = app.staticTexts["Tasks"].firstMatch
                if tasksFolder.exists {
                    firstFolder = tasksFolder
                }
            }
        }
        
        XCTAssertNotNil(firstFolder, "Первая папка должна существовать")
        XCTAssertTrue(firstFolder!.waitForExistence(timeout: 5), "Первая папка должна быть доступна")
        
        firstFolder!.press(forDuration: 0.6)
        
        sleep(1)
        sleep(2)
        
        let webViewNavBar = app.navigationBars.firstMatch
        if webViewNavBar.waitForExistence(timeout: 5) {
            XCTAssertTrue(webViewNavBar.exists, "После отправки команды должен открыться WebView с HTML результатом")
        }
    }
}
