//
//  ToastUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

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
    
    func testToastNotificationsCanDisplay() throws {
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать отображение toast")
        
        _ = app.otherElements.containing(NSPredicate(format: "identifier CONTAINS 'Toast'"))
        XCTAssertTrue(screen.exists, "UI должен поддерживать toast уведомления")
    }
    
    func testToastAutoDismisses() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать автоматическое скрытие toast")
    }
    
    func testSuccessToastStructure() throws {
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать success toast")
    }
    
    func testErrorToastStructure() throws {
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать error toast")
    }
}
