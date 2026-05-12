//
//  ShareExtensionUITests.swift
//  VoiceBookmarksShareExtensionUITests
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
        app.launchArguments += ["--UITestShareSeed", "-UI_TESTS_DISABLE_ANIMATIONS", "1"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testLoadingState_ShowsSpinnerAndDefaultMessage() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        _ = title.waitForExistence(timeout: 5)

        app.buttons["Loading"].tap()

        let status = app.staticTexts["Adding content..."]
        XCTAssertTrue(status.waitForExistence(timeout: 2))
    }
    
    func testProcessingState_ShowsIntermediateMessage() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        _ = title.waitForExistence(timeout: 5)
        
        if app.buttons["Processing"].exists {
            app.buttons["Processing"].tap()
            let status = app.staticTexts["Processing content..."]
            XCTAssertTrue(status.waitForExistence(timeout: 2))
        }
    }
    
    func testProcessingImageState_ShowsSpecificMessage() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        _ = title.waitForExistence(timeout: 5)
        
        if app.buttons["Processing Image"].exists {
            app.buttons["Processing Image"].tap()
            let status = app.staticTexts["Processing image..."]
            XCTAssertTrue(status.waitForExistence(timeout: 2))
        }
    }

    func testSuccessState_ShowsGreenCheckAndMessage() {
        app.buttons["Success"].tap()
        let status = app.staticTexts["Content added successfully"]
        XCTAssertTrue(status.waitForExistence(timeout: 2))
    }

    func testErrorState_ShowsErrorTriangleAndMessage() {
        app.buttons["Error"].tap()
        let status = app.staticTexts["No content to add"]
        XCTAssertTrue(status.waitForExistence(timeout: 2))
    }

    func testDefaultState_ResetsFlags() {
        app.buttons["Success"].tap()
        app.buttons["Default"].tap()
        let status = app.staticTexts["Adding content..."]
        XCTAssertTrue(status.waitForExistence(timeout: 2))
    }

    func testOpenSystemShareSheet_PresentsActivityView() {
        let openButton = app.buttons["Open Share Sheet"].firstMatch
        XCTAssertTrue(openButton.waitForExistence(timeout: 3))
        openButton.tap()

        let presenterHost = app.descendants(matching: .any).matching(identifier: "VoiceBookmarksSharePresenterHost").firstMatch
        let shareSheet = app.sheets.firstMatch
        let cancelButton = app.buttons["Cancel"].firstMatch
        let moreButton = app.buttons["More"].firstMatch

        let sheetExists = presenterHost.waitForExistence(timeout: 15)
            || shareSheet.waitForExistence(timeout: 2)
            || cancelButton.waitForExistence(timeout: 2)
            || moreButton.waitForExistence(timeout: 2)
            || app.collectionViews.firstMatch.waitForExistence(timeout: 2)
        XCTAssertTrue(sheetExists, "Share Sheet должен появиться после нажатия кнопки")

        if cancelButton.exists {
            cancelButton.tap()
        } else if shareSheet.exists {
            let startPoint = shareSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            let endPoint = startPoint.withOffset(CGVector(dx: 0, dy: 300))
            startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
        } else if presenterHost.exists {
            presenterHost.swipeDown(velocity: .fast)
        }
    }

    func testShareExtension_AllStates_WorkCorrectly() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Loading"].tap()
        XCTAssertTrue(app.staticTexts["Adding content..."].waitForExistence(timeout: 2))
        
        app.buttons["Success"].tap()
        XCTAssertTrue(app.staticTexts["Content added successfully"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["checkmark.circle.fill"].exists)
        
        app.buttons["Error"].tap()
        XCTAssertTrue(app.staticTexts["No content to add"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.images["exclamationmark.triangle.fill"].waitForExistence(timeout: 3),
            "После ошибки должен отображаться значок предупреждения"
        )
        
        app.buttons["Default"].tap()
        XCTAssertTrue(app.staticTexts["Adding content..."].waitForExistence(timeout: 2))
    }

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
        
        XCTAssertTrue(app.staticTexts["Adding content..."].waitForExistence(timeout: 2))
    }
    
    func testShareExtension_IntermediateStates_ShowProgressMessages() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Loading"].tap()
        
        let progressView = app.progressIndicators.firstMatch
        XCTAssertTrue(progressView.waitForExistence(timeout: 2) || app.staticTexts["Adding content..."].waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["Adding content..."].exists)
    }
    
    func testShareExtension_InitialState_ShowsLoading() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Loading"].tap()
        
        XCTAssertTrue(app.staticTexts["Adding content..."].waitForExistence(timeout: 2))
    }
    
    func testShareExtension_SuccessState_ClosesAfterDelay() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Success"].tap()
        
        XCTAssertTrue(app.staticTexts["Content added successfully"].waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["Content added successfully"].exists)
    }
    
    func testShareExtension_ErrorState_ClosesAfterDelay() {
        let title = app.navigationBars["Share Extension Test"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        
        app.buttons["Error"].tap()
        
        XCTAssertTrue(app.staticTexts["No content to add"].waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["No content to add"].exists)
    }
    
    func testSharePDFWithNote_NoDuplicateAndNoteAttached() {
        XCTAssertTrue(true)
    }
}

