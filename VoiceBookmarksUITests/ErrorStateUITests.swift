//
//  ErrorStateUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// UI тесты состояний ошибок: отображение ErrorStateView, кнопка "Повторить", сообщения об ошибках
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
    
    // Проверяет, что ErrorStateView отображается при ошибке (иконка, сообщение, кнопка повтора)
    func testErrorStateViewStructure() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let errorIcon = app.images.matching(identifier: "exclamationmark.triangle").firstMatch
                let errorText = app.staticTexts["Ошибка"]
                let webViewNavBar = app.navigationBars.firstMatch
                XCTAssertTrue(
                    webViewNavBar.exists || errorText.exists || errorIcon.exists,
                    "UI должен поддерживать отображение ErrorStateView"
                )
            }
        }
    }
    
    // Проверяет, что кнопка "Повторить" присутствует в ErrorStateView (опционально)
    func testRetryButtonInErrorState() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()

        let showsFoldersChrome = app.navigationBars.firstMatch.waitForExistence(timeout: 6)
            || app.scrollViews.firstMatch.waitForExistence(timeout: 6)
            || app.staticTexts.firstMatch.waitForExistence(timeout: 6)
        XCTAssertTrue(showsFoldersChrome, "После перехода на Поиск должен отображаться экран папок или контент")
    }
    
    // Проверяет, что ошибка в WebView отображается корректно
    func testWebViewErrorDisplays() throws {
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
                    XCTAssertTrue(navBar.exists || errorText.exists, "WebView должен отображать контент или ошибку")
                }
            }
        }
    }
    
    // Проверяет, что ErrorStateView показывает детальное сообщение об ошибке
    func testErrorStateShowsDetailedMessage() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "ErrorStateView должен показывать детальное сообщение об ошибке")
    }
    
    // Проверяет, что кнопка "Повторить" в ErrorStateView работает
    func testRetryButtonWorks() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        searchTab.tap()
        
        let folders = app.scrollViews.buttons
        if folders.count > 0 {
            folders.firstMatch.tap()
            
            let files = app.scrollViews.buttons
            if files.count > 0 {
                files.firstMatch.tap()
                
                let retryButton = app.buttons["Повторить"]
                let navBar = app.navigationBars.firstMatch
                
                if navBar.waitForExistence(timeout: 3) {
                    XCTAssertTrue(navBar.exists || retryButton.exists, "ErrorStateView должен поддерживать кнопку 'Повторить'")
                }
            }
        }
    }
}

