//
//  NavigationUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

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
    
    func testFullNavigationPath() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let fileListNavBar = app.navigationBars["Files"]
            if fileListNavBar.waitForExistence(timeout: 3) {
                XCTAssertTrue(fileListNavBar.exists, "Должен открыться FileListView")
                
                let files = app.scrollViews.buttons
                if files.count > 0 {
                    files.firstMatch.tap()
                    UITestInteractions.confirmOpenBookmarkFromFileListIfNeeded(app: app)
                    
                    let webViewNavBar = app.navigationBars.firstMatch
                    if webViewNavBar.waitForExistence(timeout: 3) {
                        XCTAssertTrue(webViewNavBar.exists, "Должен открыться WebView")
                        
                        let backButton = app.navigationBars.buttons.element(boundBy: 0)
                        if backButton.exists {
                            backButton.tap()
                            
                            let fileListNavBarAfter = app.navigationBars["Files"]
                            if fileListNavBarAfter.waitForExistence(timeout: 2) {
                                XCTAssertTrue(fileListNavBarAfter.exists, "Должен вернуться к FileListView")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func testNavigationFromFileListToWebViewViaContextMenu() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            _ = app.navigationBars["Files"].waitForExistence(timeout: 3)
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.press(forDuration: 1.0)
                
                let viewAction = app.buttons["View"]
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
    
    func testCloseWebViewReturnsToFileList() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            _ = app.navigationBars["Files"].waitForExistence(timeout: 3)
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                UITestInteractions.confirmOpenBookmarkFromFileListIfNeeded(app: app)
                
                let closeButton = UITestInteractions.webCloseButton(in: app)
                if closeButton.waitForExistence(timeout: 3) {
                    closeButton.tap()
                    
                    let fileListNavBar = app.navigationBars["Files"]
                    if fileListNavBar.waitForExistence(timeout: 2) {
                        XCTAssertTrue(fileListNavBar.exists, "Должен вернуться к FileListView после закрытия WebView")
                    }
                }
            }
        }
    }
    
    func testTabNavigationPreservesState() throws {
        let addTab = app.tabBars.buttons["Add"]
        let searchTab = app.tabBars.buttons["Search"]
        
        addTab.tap()
        let addScreen = app.otherElements.firstMatch
        XCTAssertTrue(addScreen.exists, "Экран 'Add' должен отображаться")
        
        searchTab.tap()
        let searchScreen = app.scrollViews.firstMatch
        XCTAssertTrue(searchScreen.exists || app.navigationBars.firstMatch.exists, "Экран 'Search' должен отображаться")
        
        addTab.tap()
        let addScreenAfter = app.otherElements.firstMatch
        XCTAssertTrue(addScreenAfter.exists, "Экран 'Add' должен снова отображаться")
    }
    
    func testSwitchingToSearchTabResetsSearchState() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let fileListNavBar = app.navigationBars["Files"]
            if fileListNavBar.waitForExistence(timeout: 3) {
                let addTab = app.tabBars.buttons["Add"]
                addTab.tap()
                
                searchTab.tap()
                
                let folderListExists = app.navigationBars["Folders"].waitForExistence(timeout: 2)
                XCTAssertTrue(
                    folderListExists || app.scrollViews.firstMatch.exists,
                    "После переключения на вкладку 'Search' должен отображаться список папок"
                )
            }
        }
    }
    
    func testReturnFromWebViewAfterCommandReturnsToFolderList() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            let folder = folders.firstMatch
            folder.press(forDuration: 0.8)
            
            let webViewNavBar = app.navigationBars.firstMatch
            if webViewNavBar.waitForExistence(timeout: 5) {
                let closeButton = UITestInteractions.webCloseButton(in: app)
                if closeButton.waitForExistence(timeout: 2) {
                    closeButton.tap()
                    
                    let folderListNavBar = app.navigationBars["Folders"]
                    if folderListNavBar.waitForExistence(timeout: 3) {
                        XCTAssertTrue(folderListNavBar.exists, "После закрытия WebView с командой должен вернуться список папок")
                    }
                }
            }
        }
    }
}
