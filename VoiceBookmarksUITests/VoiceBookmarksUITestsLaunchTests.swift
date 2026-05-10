//
//  VoiceBookmarksUITestsLaunchTests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class VoiceBookmarksUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab Bar должен появиться при запуске")
        
        let addTab = app.tabBars.buttons["Add"]
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(addTab.exists, "Add tab should exist")
        XCTAssertTrue(searchTab.exists, "Вкладка 'Search' должна существовать")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
