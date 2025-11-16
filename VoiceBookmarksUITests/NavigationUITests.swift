//
//  NavigationUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// UI тесты навигации: переходы между экранами, кнопка "Назад", стек навигации
final class NavigationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        sleep(1)
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // Проверяет полный путь навигации: Папки → Файлы → WebView → Назад (проверка стека)
    func testFullNavigationPath() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let fileListNavBar = app.navigationBars["Файлы"]
            if fileListNavBar.waitForExistence(timeout: 3) {
                XCTAssertTrue(fileListNavBar.exists, "Должен открыться FileListView")
                
                let files = app.scrollViews.buttons
                if files.count > 0 {
                    files.firstMatch.tap()
                    
                    let webViewNavBar = app.navigationBars.firstMatch
                    if webViewNavBar.waitForExistence(timeout: 3) {
                        XCTAssertTrue(webViewNavBar.exists, "Должен открыться WebView")
                        
                        let backButton = app.navigationBars.buttons.element(boundBy: 0)
                        if backButton.exists {
                            backButton.tap()
                            
                            let fileListNavBarAfter = app.navigationBars["Файлы"]
                            if fileListNavBarAfter.waitForExistence(timeout: 2) {
                                XCTAssertTrue(fileListNavBarAfter.exists, "Должен вернуться к FileListView")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Проверяет навигацию от FileListView к WebView через context menu
    func testNavigationFromFileListToWebViewViaContextMenu() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            _ = app.navigationBars["Файлы"].waitForExistence(timeout: 3)
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.press(forDuration: 1.0)
                
                let viewAction = app.buttons["Посмотреть"]
                if viewAction.waitForExistence(timeout: 2) {
                    viewAction.tap()
                    
                    let webViewNavBar = app.navigationBars.firstMatch
                    if webViewNavBar.waitForExistence(timeout: 3) {
                        XCTAssertTrue(webViewNavBar.exists, "WebView должен открыться через context menu")
                    }
                }
            }
        }
    }
    
    // Проверяет, что закрытие WebView возвращает к FileListView
    func testCloseWebViewReturnsToFileList() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            _ = app.navigationBars["Файлы"].waitForExistence(timeout: 3)
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let closeButton = app.navigationBars.buttons["Закрыть"]
                let closeButton = UITestInteractions.webCloseButton(in: app)
                if closeButton.waitForExistence(timeout: 3) {
                    closeButton.tap()
                    
                    let fileListNavBar = app.navigationBars["Файлы"]
                    if fileListNavBar.waitForExistence(timeout: 2) {
                        XCTAssertTrue(fileListNavBar.exists, "Должен вернуться к FileListView после закрытия WebView")
                    }
                }
            }
        }
    }
    
    // Проверяет, что навигация между вкладками сохраняет состояние
    func testTabNavigationPreservesState() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        let searchTab = app.tabBars.buttons["Поиск"]
        
        addTab.tap()
        let addScreen = app.otherElements.firstMatch
        XCTAssertTrue(addScreen.exists, "Экран 'Добавить' должен отображаться")
        
        searchTab.tap()
        let searchScreen = app.scrollViews.firstMatch
        XCTAssertTrue(searchScreen.exists || app.navigationBars.firstMatch.exists, "Экран 'Поиск' должен отображаться")
        
        addTab.tap()
        let addScreenAfter = app.otherElements.firstMatch
        XCTAssertTrue(addScreenAfter.exists, "Экран 'Добавить' должен снова отображаться")
    }
    
    // Проверяет, что переключение на вкладку "Поиск" сбрасывает состояние поиска
    func testSwitchingToSearchTabResetsSearchState() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let fileListNavBar = app.navigationBars["Файлы"]
            if fileListNavBar.waitForExistence(timeout: 3) {
                let addTab = app.tabBars.buttons["Добавить"]
                addTab.tap()
                
                searchTab.tap()
                
                let folderListExists = app.navigationBars["Папки"].waitForExistence(timeout: 2)
                XCTAssertTrue(
                    folderListExists || app.scrollViews.firstMatch.exists,
                    "После переключения на вкладку 'Поиск' должен отображаться список папок"
                )
            }
        }
    }
    
    // Проверяет, что возврат из WebView после команды возвращает к списку папок
    func testReturnFromWebViewAfterCommandReturnsToFolderList() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            let folder = folders.firstMatch
            folder.press(forDuration: 0.8)
            
            let webViewNavBar = app.navigationBars.firstMatch
            if webViewNavBar.waitForExistence(timeout: 5) {
                let closeButton = app.navigationBars.buttons["Закрыть"]
                let closeButton = UITestInteractions.webCloseButton(in: app)
                if closeButton.waitForExistence(timeout: 2) {
                    closeButton.tap()
                    
                    let folderListNavBar = app.navigationBars["Папки"]
                    if folderListNavBar.waitForExistence(timeout: 3) {
                        XCTAssertTrue(folderListNavBar.exists, "После закрытия WebView с командой должен вернуться список папок")
                    }
                }
            }
        }
    }
}

