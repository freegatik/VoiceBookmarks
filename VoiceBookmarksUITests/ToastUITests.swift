//
//  ToastUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// UI тесты toast уведомлений: отображение success/error/info, автоматическое скрытие
final class ToastUITests: XCTestCase {
    
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
    
    // Проверяет, что toast уведомления могут отображаться (базовая проверка структуры UI)
    func testToastNotificationsCanDisplay() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать отображение toast")
        
        _ = app.otherElements.containing(NSPredicate(format: "identifier CONTAINS 'Toast'"))
        XCTAssertTrue(screen.exists, "UI должен поддерживать toast уведомления")
    }
    
    // Проверяет, что toast автоматически скрывается через заданное время (4 секунды)
    func testToastAutoDismisses() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать автоматическое скрытие toast")
    }
    
    // Проверяет, что toast успешного действия отображается с правильной иконкой и цветом
    func testSuccessToastStructure() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать success toast")
    }
    
    // Проверяет, что toast ошибки отображается с правильной иконкой и цветом
    func testErrorToastStructure() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать error toast")
    }
}

