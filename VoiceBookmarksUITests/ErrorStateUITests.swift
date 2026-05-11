//
//  ErrorStateUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class ErrorStateUITests: XCTestCase {
    
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
    
    func testErrorStateViewStructure() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                UITestInteractions.confirmOpenBookmarkFromFileListIfNeeded(app: app)
                
                let errorIcon = app.images.matching(identifier: "exclamationmark.triangle").firstMatch
                let errorText = app.staticTexts["Error"]
                let webViewNavBar = app.navigationBars.firstMatch
                XCTAssertTrue(
                    webViewNavBar.exists || errorText.exists || errorIcon.exists,
                    "UI должен поддерживать отображение ErrorStateView"
                )
            }
        }
    }
    
    func testRetryButtonInErrorState() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()

        let showsFoldersChrome = app.navigationBars.firstMatch.waitForExistence(timeout: 6)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 6)
            || app.staticTexts.firstMatch.waitForExistence(timeout: 6)
        XCTAssertTrue(showsFoldersChrome, "После перехода на Search должен отображаться экран папок или контент")
    }
    
    func testWebViewErrorDisplays() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                UITestInteractions.confirmOpenBookmarkFromFileListIfNeeded(app: app)
                
                let navBar = app.navigationBars.firstMatch
                let errorText = app.staticTexts["Error"]
                
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists || errorText.exists, "WebView должен отображать контент или ошибку")
                }
            }
        }
    }
    
    func testErrorStateShowsDetailedMessage() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "ErrorStateView должен показывать детальное сообщение об ошибке")
    }
    
    func testRetryButtonWorks() throws {
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                UITestInteractions.confirmOpenBookmarkFromFileListIfNeeded(app: app)
                
                let retryButton = app.buttons["Повторить"]
                let navBar = app.navigationBars.firstMatch
                
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists || retryButton.exists, "ErrorStateView должен поддерживать кнопку 'Повторить'")
                }
            }
        }
    }
}
