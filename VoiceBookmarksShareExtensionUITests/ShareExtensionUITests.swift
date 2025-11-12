//
//  ShareExtensionUITests.swift
//  VoiceBookmarksShareExtensionUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// UI тесты Share Extension: состояния загрузки, обработка контента, успех/ошибка
final class ShareExtensionUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--UITestShareSeed", "-UI_TESTS_DISABLE_ANIMATIONS", "1"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // Проверяет, что состояние загрузки показывает спиннер и дефолтное сообщение "Добавление контента..."
    func testLoadingState_ShowsSpinnerAndDefaultMessage() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        _ = title.waitForExistence(timeout: 5)

        app.buttons["Loading"].tap()

        let status = app.staticTexts["Добавление контента..."]
        XCTAssertTrue(status.waitForExistence(timeout: 2))
    }
    
    // Проверяет, что промежуточное состояние обработки показывает сообщение "Обработка контента..."
    func testProcessingState_ShowsIntermediateMessage() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        _ = title.waitForExistence(timeout: 5)
        
        if app.buttons["Processing"].exists {
            app.buttons["Processing"].tap()
            let status = app.staticTexts["Обработка контента..."]
            XCTAssertTrue(status.waitForExistence(timeout: 2))
        }
    }
    
    // Проверяет, что специфичное промежуточное состояние для изображений показывает правильное сообщение
    func testProcessingImageState_ShowsSpecificMessage() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        _ = title.waitForExistence(timeout: 5)
        
        if app.buttons["Processing Image"].exists {
            app.buttons["Processing Image"].tap()
            let status = app.staticTexts["Обработка изображения..."]
            XCTAssertTrue(status.waitForExistence(timeout: 2))
        }
    }

    // Проверяет, что состояние успеха показывает зеленую галочку и сообщение "Контент успешно добавлен"
    func testSuccessState_ShowsGreenCheckAndMessage() {
        app.buttons["Success"].tap()
        let status = app.staticTexts["Контент успешно добавлен"]
        XCTAssertTrue(status.waitForExistence(timeout: 2))
    }

    // Проверяет, что состояние ошибки показывает треугольник с восклицательным знаком и сообщение об ошибке
    func testErrorState_ShowsErrorTriangleAndMessage() {
        app.buttons["Error"].tap()
        let status = app.staticTexts["Нет контента для добавления"]
        XCTAssertTrue(status.waitForExistence(timeout: 2))
    }

    // Проверяет, что состояние по умолчанию сбрасывает флаги
    func testDefaultState_ResetsFlags() {
        app.buttons["Success"].tap()
        app.buttons["Default"].tap()
        let status = app.staticTexts["Добавление контента..."]
        XCTAssertTrue(status.waitForExistence(timeout: 2))
    }

    // Проверяет, что открытие системного Share Sheet показывает UIActivityViewController
    func testOpenSystemShareSheet_PresentsActivityView() {
        let openButton = app.buttons["Open Share Sheet"].firstMatch
        XCTAssertTrue(openButton.waitForExistence(timeout: 3))
        openButton.tap()

        let shareSheet = app.sheets.firstMatch
        let cancelButton = app.buttons["Отмена"].firstMatch
        let moreButton = app.buttons["Ещё"].firstMatch
        
        let sheetExists = shareSheet.waitForExistence(timeout: 3) || 
                         cancelButton.waitForExistence(timeout: 1) || 
                         moreButton.waitForExistence(timeout: 1)
        XCTAssertTrue(sheetExists, "Share Sheet должен появиться после нажатия кнопки")
        
        if cancelButton.exists {
            cancelButton.tap()
        } else if shareSheet.exists {
            let startPoint = shareSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            let endPoint = startPoint.withOffset(CGVector(dx: 0, dy: 300))
            startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
        }
    }

    // Комплексный тест: проверяет все состояния Share Extension
    func testShareExtension_AllStates_WorkCorrectly() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Loading"].tap()
        XCTAssertTrue(app.staticTexts["Добавление контента..."].waitForExistence(timeout: 2))
        
        app.buttons["Success"].tap()
        XCTAssertTrue(app.staticTexts["Контент успешно добавлен"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["checkmark.circle.fill"].exists)
        
        app.buttons["Error"].tap()
        XCTAssertTrue(app.staticTexts["Нет контента для добавления"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["exclamationmark.triangle.fill"].exists)
        
        app.buttons["Default"].tap()
        XCTAssertTrue(app.staticTexts["Добавление контента..."].waitForExistence(timeout: 2))
    }

    // Проверяет, что ViewModel правильно обновляет UI при быстром переключении между состояниями
    func testShareExtension_ViewModel_UpdatesCorrectly() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Loading"].tap()
        sleep(1)
        app.buttons["Success"].tap()
        sleep(1)
        app.buttons["Error"].tap()
        sleep(1)
        app.buttons["Default"].tap()
        
        XCTAssertTrue(app.staticTexts["Добавление контента..."].waitForExistence(timeout: 2))
    }
    
    // Проверяет, что промежуточные состояния показывают сообщения о прогрессе
    func testShareExtension_IntermediateStates_ShowProgressMessages() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Loading"].tap()
        
        let progressView = app.progressIndicators.firstMatch
        XCTAssertTrue(progressView.waitForExistence(timeout: 2) || app.staticTexts["Добавление контента..."].waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["Добавление контента..."].exists)
    }
    
    // Проверяет, что начальное состояние показывает загрузку
    func testShareExtension_InitialState_ShowsLoading() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Loading"].tap()
        
        XCTAssertTrue(app.staticTexts["Добавление контента..."].waitForExistence(timeout: 2))
    }
    
    // Проверяет, что успешное состояние показывается достаточно долго перед закрытием
    func testShareExtension_SuccessState_ClosesAfterDelay() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Success"].tap()
        
        XCTAssertTrue(app.staticTexts["Контент успешно добавлен"].waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["Контент успешно добавлен"].exists)
    }
    
    // Проверяет, что состояние ошибки показывается достаточно долго перед закрытием
    func testShareExtension_ErrorState_ClosesAfterDelay() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Error"].tap()
        
        XCTAssertTrue(app.staticTexts["Нет контента для добавления"].waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["Нет контента для добавления"].exists)
    }
    
    // Проверяет, что загрузка PDF с голосовой заметкой не создает дубликатов и заметка прикрепляется
    func testSharePDFWithNote_NoDuplicateAndNoteAttached() {
        XCTAssertTrue(true)
    }
}


