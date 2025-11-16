//
//  VoiceBookmarksUITestsLaunchTests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// Тесты производительности запуска: время запуска приложения, инициализация Tab Bar, скриншот
final class VoiceBookmarksUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Проверяет, что приложение запускается и показывает Tab Bar в разумное время (таймаут 10 сек)
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab Bar должен появиться при запуске")
        
        let addTab = app.tabBars.buttons["Добавить"]
        let searchTab = app.tabBars.buttons["Поиск"]
        XCTAssertTrue(addTab.exists, "Вкладка 'Добавить' должна существовать")
        XCTAssertTrue(searchTab.exists, "Вкладка 'Поиск' должна существовать")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
