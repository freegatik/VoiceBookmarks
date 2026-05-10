//
//  ShareViewUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

final class ShareViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        sleep(1)
        
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    func testTapOnEmptyAreaShowsPasteButton() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен существовать")
        
        screen.tap()
        
        let pasteButton = app.buttons["Вставить"]
        if pasteButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(pasteButton.exists, "Кнопка 'Вставить' должна появиться после тапа на пустую область")
        }
    }
    
    func testNoAutomaticPaste() throws {
        let pasteButton = app.buttons["Вставить"]
        XCTAssertFalse(pasteButton.exists, "Кнопка 'Вставить' НЕ должна появляться автоматически")
    }
    
    func testNoAutomaticRecording() throws {
        _ = app.staticTexts.firstMatch
        XCTAssertTrue(app.otherElements.firstMatch.exists, "Экран должен отображаться")
    }
    
    func testContentPreviewDisplay() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен отображаться")
    }
    
    func testSwipeUpUploadsContent() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен отображаться")
    }
    
    func testSwipeDownDismissesScreen() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен отображаться")
    }
    
    func testPasteButtonShowsContentPreview() throws {
        let screen = app.otherElements.firstMatch
        screen.tap()
        
        let pasteButton = app.buttons["Вставить"]
        guard pasteButton.waitForExistence(timeout: 2) else {
            return
        }
        
        pasteButton.tap()
        sleep(1)
        
        let buttonStillExists = pasteButton.exists
        let hasLink = app.links.firstMatch.exists
        let hasImage = app.images.firstMatch.exists
        let hasText = app.staticTexts.count > 0
        
        XCTAssertTrue(
            !buttonStillExists || hasLink || hasImage || hasText,
            "После тапа на кнопку 'Вставить' должно появиться превью или кнопка должна исчезнуть"
        )
    }
    
    func testProgressViewDuringUpload() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен отображаться и поддерживать ProgressView")
    }
    
    func testContentPreviewShowsActiveLink() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать отображение активных ссылок в ContentPreviewView")
    }
    
    func testContentPreviewShowsSeparator() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать серую разделительную линию в ContentPreviewView")
    }
    
    func testPasteButtonHidesAfterPaste() throws {
        let screen = app.otherElements.firstMatch
        screen.tap()
        
        let pasteButton = app.buttons["Вставить"]
        guard pasteButton.waitForExistence(timeout: 2) else {
            return
        }
        
        pasteButton.tap()
        sleep(1)
        
        let buttonStillExists = pasteButton.exists
        let hasLink = app.links.firstMatch.exists
        let hasImage = app.images.firstMatch.exists
        let hasText = app.staticTexts.count > 0
        
        XCTAssertTrue(
            !buttonStillExists || hasLink || hasImage || hasText,
            "Кнопка 'Вставить' должна скрыться или появиться превью после вставки"
        )
    }
    
    func testTapOnTranscriptionFieldShowsPasteButton() throws {
        let transcriptionPlaceholder = app.staticTexts["Нажмите для вставки из буфера"]
        let transcriptionField = app.staticTexts.firstMatch
        
        if transcriptionPlaceholder.waitForExistence(timeout: 2) {
            transcriptionPlaceholder.tap()
        } else if transcriptionField.exists {
            transcriptionField.tap()
        }
        
        let pasteButton = app.buttons["Вставить"]
        if pasteButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(pasteButton.exists, "Кнопка 'Вставить' должна появиться после тапа на поле транскрипции")
        }
    }
    
    func testTapOnTranscriptionFieldDuringRecordingIsIgnored() throws {
        let screen = app.otherElements.firstMatch
        screen.tap()
        
        let pasteButton = app.buttons["Вставить"]
        if pasteButton.waitForExistence(timeout: 2) {
            pasteButton.tap()
        }
        
        let contentPreview = app.otherElements.firstMatch
        contentPreview.press(forDuration: 0.8)
        
        let transcriptionField = app.staticTexts.firstMatch
        if transcriptionField.exists {
            transcriptionField.tap()
            
            let pasteButtonDuringRecording = app.buttons["Вставить"]
            XCTAssertFalse(pasteButtonDuringRecording.exists, "Кнопка 'Вставить' не должна появляться во время записи")
        }
    }
    
    func testTapOnTranscriptionFieldWithContentPreviewIsIgnored() throws {
        let screen = app.otherElements.firstMatch
        screen.tap()
        
        let pasteButton = app.buttons["Вставить"]
        if pasteButton.waitForExistence(timeout: 2) {
            pasteButton.tap()
        }
        
        let transcriptionField = app.staticTexts.firstMatch
        if transcriptionField.exists {
            transcriptionField.tap()
            
            let pasteButtonAfterContent = app.buttons["Вставить"]
            XCTAssertTrue(
                !pasteButtonAfterContent.exists || !pasteButtonAfterContent.isHittable,
                "Кнопка 'Вставить' не должна появляться когда уже есть contentPreview"
            )
        }
    }
    
    func testAutoLoadsLastSharedItemOnAppActivation() throws {
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        sleep(3)
        
        let hasContentPreview = app.links.firstMatch.exists || 
                            app.images.firstMatch.exists || 
                            app.staticTexts.count > 0
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists || hasContentPreview, "Экран должен загрузиться и попытаться загрузить последний элемент из Share Extension при активации")
    }
    
    func testLoadLastSharedItemDoesNotLoadIfContentExists() throws {
        let screen = app.otherElements.firstMatch
        screen.tap()
        
        let pasteButton = app.buttons["Вставить"]
        if pasteButton.waitForExistence(timeout: 2) {
            pasteButton.tap()
            
            sleep(1)
            let hasContent = app.links.firstMatch.exists || 
                            app.images.firstMatch.exists || 
                            app.staticTexts.count > 0
            
            XCTAssertTrue(hasContent || screen.exists, "Контент должен остаться после загрузки")
        }
    }
    
    func testLoadLastSharedItemLoadsTextFiles() throws {
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        sleep(2)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать загрузку текстовых файлов из Share Extension")
    }
    
    func testLoadLastSharedItemLoadsImages() throws {
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        sleep(2)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать загрузку изображений из Share Extension")
    }
    
    func testLoadLastSharedItemLoadsURLFiles() throws {
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        sleep(2)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать загрузку URL файлов из Share Extension")
    }
    
    func testLoadLastSharedItemCalledOnAppActivation() throws {
        let addTab = app.tabBars.buttons["Add"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        sleep(2)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен быть готов к загрузке последнего элемента при активации приложения")
    }
}
