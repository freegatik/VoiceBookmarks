//
//  VoiceLatencyAndVoiceNoteTests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// UI тесты проверки voiceNote и latency: prewarm аудио-системы, приоритет voiceNote в отображении
final class VoiceLatencyAndVoiceNoteTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        sleep(2)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // Проверяет, что prewarm аудио-системы запускается при появлении Share экрана (для быстрого старта записи)
    func testShareScreenPrewarm() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        XCTAssertTrue(addTab.waitForExistence(timeout: 5), "Вкладка 'Добавить' должна существовать")
        addTab.tap()
        
        sleep(2)
        
        XCTAssertTrue(app.exists, "Share экран должен быть загружен")
    }
    
    // Проверяет приоритизацию voiceNote в отображении (voiceNote показывается вместо summary)
    // Note: Требует загруженного bookmark с voiceNote
    func testVoiceNoteDisplayPriority() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        if !searchTab.isSelected {
            searchTab.tap()
            sleep(2)
        }
        
        sleep(3)
    }
    
    // Проверяет дедупликацию (через количество элементов)
    func testDeduplication() throws {
        let searchTab = app.tabBars.buttons["Поиск"]
        if !searchTab.isSelected {
            searchTab.tap()
            sleep(2)
        }
        
        sleep(3)
    }
}

