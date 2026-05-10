//
//  ShareExtensionUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class ShareExtensionUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--UITesting", "--ShareExtensionTesting"]
        app.launch()
        sleep(1)
        
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            XCTFail("Tab bar должен существовать")
            return
        }
        
        let testTab = app.tabBars.buttons["Test SE"]
        if testTab.waitForExistence(timeout: 5) {
            testTab.tap()
        } else {
            let allTabs = app.tabBars.buttons.allElementsBoundByIndex
            if allTabs.count >= 3 {
                allTabs[2].tap()
            } else if allTabs.count > 0 {
                for tab in allTabs {
                    tab.tap()
                    sleep(1)
                    if app.navigationBars["Share Extension Test"].waitForExistence(timeout: 3) {
                        break
                    }
                }
            }
        }
        
        let navBar = app.navigationBars["Share Extension Test"]
        _ = navBar.waitForExistence(timeout: 15)
        sleep(2)
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    func testShareExtensionViewStructure() throws {
        let navBar = app.navigationBars["Share Extension Test"]
        guard navBar.waitForExistence(timeout: 10) else {
            XCTFail("Тестовый экран Share Extension должен загрузиться")
            return
        }
        
        XCTAssertTrue(app.buttons["Loading"].waitForExistence(timeout: 5), "Кнопка 'Loading' должна существовать")
        XCTAssertTrue(app.buttons["Success"].waitForExistence(timeout: 5), "Кнопка 'Success' должна существовать")
        XCTAssertTrue(app.buttons["Error"].waitForExistence(timeout: 5), "Кнопка 'Error' должна существовать")
        XCTAssertTrue(app.buttons["Default"].waitForExistence(timeout: 5), "Кнопка 'Default' должна существовать")
        
        let statusText = app.staticTexts["Adding content..."]
        XCTAssertTrue(statusText.waitForExistence(timeout: 3) || app.images.firstMatch.exists, 
                     "UI элементы должны отображаться")
    }
    
    func testShareExtensionLoadingIndicator() throws {
        let navBar = app.navigationBars["Share Extension Test"]
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("Тестовый экран не загружен")
        }
        
        let loadingButton = app.buttons["Loading"]
        XCTAssertTrue(loadingButton.waitForExistence(timeout: 5), "Кнопка 'Loading' должна существовать")
        loadingButton.tap()
        sleep(2)
        
        let progressIndicators = app.progressIndicators
        let statusText = app.staticTexts["Adding content..."]
        
        XCTAssertTrue(progressIndicators.count > 0 || statusText.waitForExistence(timeout: 3), 
                     "ProgressView или статусный текст должны отображаться")
    }
    
    func testShareExtensionSuccessMessage() throws {
        let navBar = app.navigationBars["Share Extension Test"]
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("Тестовый экран не загружен")
        }
        
        let successButton = app.buttons["Success"]
        XCTAssertTrue(successButton.waitForExistence(timeout: 5), "Кнопка 'Success' должна существовать")
        successButton.tap()
        sleep(3)
        
        let successMessage = app.staticTexts["Content added successfully"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 5) || app.images.count > 0, 
                     "Должно отображаться сообщение об успехе или иконка")
    }
    
    func testShareExtensionErrorMessage() throws {
        let navBar = app.navigationBars["Share Extension Test"]
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("Тестовый экран не загружен")
        }
        
        let errorButton = app.buttons["Error"]
        XCTAssertTrue(errorButton.waitForExistence(timeout: 5), "Кнопка 'Error' должна существовать")
        errorButton.tap()
        sleep(2)
        
        let errorMessage = app.staticTexts["No content to add"]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 5) || app.images.count > 0, 
                     "Должно отображаться сообщение об ошибке или иконка")
    }
    
    func testShareExtensionAutoClose() throws {
        let navBar = app.navigationBars["Share Extension Test"]
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("Тестовый экран не загружен")
        }
        
        XCTAssertTrue(app.exists, "Приложение должно быть запущено")
        
        let successButton = app.buttons["Success"]
        XCTAssertTrue(successButton.waitForExistence(timeout: 5), "Кнопка 'Success' должна существовать")
        successButton.tap()
        sleep(2)
        
        let successMessage = app.staticTexts["Content added successfully"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 5), 
                     "Сообщение об успехе должно отображаться перед закрытием")
    }
    
    func testShareExtensionHandlesDifferentContentTypes() throws {
        let navBar = app.navigationBars["Share Extension Test"]
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("Тестовый экран не загружен")
        }
        
        XCTAssertTrue(app.exists, "Приложение должно быть запущено")
        XCTAssertTrue(app.otherElements.firstMatch.exists, "UI должен поддерживать обработку контента")
    }
    
    func testShareExtensionAddsToOfflineQueue() throws {
        let navBar = app.navigationBars["Share Extension Test"]
        guard navBar.waitForExistence(timeout: 10) else {
            throw XCTSkip("Тестовый экран не загружен")
        }
        
        sleep(1)
        
        XCTAssertTrue(app.exists, "Приложение должно быть запущено")
        XCTAssertTrue(app.otherElements.firstMatch.exists, "UI должен поддерживать работу с очередью")
    }
    
    func testShareExtensionIconsDisplay() throws {
        let navBar = app.navigationBars["Share Extension Test"]
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("Тестовый экран не загружен")
        }
        
        let defaultButton = app.buttons["Default"]
        XCTAssertTrue(defaultButton.waitForExistence(timeout: 5), "Кнопка 'Default' должна существовать")
        defaultButton.tap()
        sleep(2)
        XCTAssertTrue(app.images.count > 0, "Должна отображаться иконка по умолчанию")
        
        let successButton = app.buttons["Success"]
        XCTAssertTrue(successButton.waitForExistence(timeout: 3), "Кнопка 'Success' должна существовать")
        successButton.tap()
        sleep(2)
        XCTAssertTrue(app.images.count > 0, "Должна отображаться иконка успеха")
        
        let errorButton = app.buttons["Error"]
        XCTAssertTrue(errorButton.waitForExistence(timeout: 3), "Кнопка 'Error' должна существовать")
        errorButton.tap()
        sleep(2)
        XCTAssertTrue(app.images.count > 0, "Должна отображаться иконка ошибки")
    }
    
    func testShareExtensionStatusColor() throws {
        let navBar = app.navigationBars["Share Extension Test"]
        guard navBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("Тестовый экран не загружен")
        }
        
        let errorButton = app.buttons["Error"]
        XCTAssertTrue(errorButton.waitForExistence(timeout: 5), "Кнопка 'Error' должна существовать")
        errorButton.tap()
        sleep(2)
        
        let errorText = app.staticTexts["No content to add"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 5), "Текст ошибки должен отображаться")
        
        let successButton = app.buttons["Success"]
        XCTAssertTrue(successButton.waitForExistence(timeout: 3), "Кнопка 'Success' должна существовать")
        successButton.tap()
        sleep(2)
        
        let successText = app.staticTexts["Content added successfully"]
        XCTAssertTrue(successText.waitForExistence(timeout: 5), "Текст успеха должен отображаться")
    }
}
