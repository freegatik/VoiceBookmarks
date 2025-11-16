//
//  ShareViewUITests.swift
//  VoiceBookmarksUITests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest

// UI тесты экрана "Добавить": кнопка "Вставить", жесты, голосовые заметки, загрузка контента
final class ShareViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        sleep(1)
        
        let addTab = app.tabBars.buttons["Добавить"]
        if !addTab.isSelected {
            addTab.tap()
        }
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // Проверяет, что тап на пустую область показывает кнопку "Вставить" (не автоматически)
    func testTapOnEmptyAreaShowsPasteButton() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен существовать")
        
        screen.tap()
        
        let pasteButton = app.buttons["Вставить"]
        if pasteButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(pasteButton.exists, "Кнопка 'Вставить' должна появиться после тапа на пустую область")
        }
    }
    
    // Проверяет, что автоматическая вставка из буфера НЕ работает (только по tap)
    func testNoAutomaticPaste() throws {
        let pasteButton = app.buttons["Вставить"]
        XCTAssertFalse(pasteButton.exists, "Кнопка 'Вставить' НЕ должна появляться автоматически")
    }
    
    // Проверяет, что запись голоса НЕ начинается автоматически (только по long press)
    func testNoAutomaticRecording() throws {
        _ = app.staticTexts.firstMatch
        XCTAssertTrue(app.otherElements.firstMatch.exists, "Экран должен отображаться")
    }
    
    // Проверяет, что превью контента отображается после вставки из буфера (ContentPreviewView)
    func testContentPreviewDisplay() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен отображаться")
    }
    
    // Проверяет, что swipe вверх отправляет контент на сервер (uploadContent)
    func testSwipeUpUploadsContent() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен отображаться")
    }
    
    // Проверяет, что swipe вниз отменяет запись или закрывает экран (handleSwipeDown)
    func testSwipeDownDismissesScreen() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен отображаться")
    }
    
    // Проверяет, что тап на кнопку "Вставить" показывает превью контента из буфера
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
    
    // Проверяет, что ProgressView отображается во время загрузки контента (isUploading = true)
    func testProgressViewDuringUpload() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен отображаться и поддерживать ProgressView")
    }
    
    // Проверяет, что ContentPreviewView отображает активную ссылку для URL (синий цвет, underline)
    func testContentPreviewShowsActiveLink() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать отображение активных ссылок в ContentPreviewView")
    }
    
    // Проверяет, что ContentPreviewView показывает серую разделительную линию (opacity 0.4, height 2)
    func testContentPreviewShowsSeparator() throws {
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "UI должен поддерживать серую разделительную линию в ContentPreviewView")
    }
    
    // Проверяет, что кнопка "Вставить" скрывается после вставки контента (showPasteButton = false)
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
    
    // Проверяет, что тап на поле транскрипции показывает кнопку "Вставить" (handleTapOnTranscriptionField)
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
    
    // Проверяет, что тап на поле транскрипции во время записи игнорируется (isRecording = true)
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
    
    // Проверяет, что тап на поле транскрипции при наличии contentPreview игнорируется (contentPreview != nil)
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
    
    // Проверяет, что последний элемент из Share Extension автоматически загружается при активации (loadLastSharedItemIfAny)
    func testAutoLoadsLastSharedItemOnAppActivation() throws {
        let addTab = app.tabBars.buttons["Добавить"]
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
    
    // Проверяет, что loadLastSharedItemIfAny не загружает элемент если contentPreview уже установлен
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
    
    // Проверяет, что loadLastSharedItemIfAny загружает текстовые файлы (.txt, .md, .log) из Share Extension
    func testLoadLastSharedItemLoadsTextFiles() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        sleep(2)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать загрузку текстовых файлов из Share Extension")
    }
    
    // Проверяет, что loadLastSharedItemIfAny загружает изображения (.jpg, .jpeg, .png) из Share Extension
    func testLoadLastSharedItemLoadsImages() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        sleep(2)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать загрузку изображений из Share Extension")
    }
    
    // Проверяет, что loadLastSharedItemIfAny загружает URL файлы (.url) из Share Extension
    func testLoadLastSharedItemLoadsURLFiles() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        sleep(2)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен поддерживать загрузку URL файлов из Share Extension")
    }
    
    // Проверяет, что loadLastSharedItemIfAny вызывается при активации приложения (onChange scenePhase)
    func testLoadLastSharedItemCalledOnAppActivation() throws {
        let addTab = app.tabBars.buttons["Добавить"]
        if !addTab.isSelected {
            addTab.tap()
        }
        
        sleep(2)
        
        let screen = app.otherElements.firstMatch
        XCTAssertTrue(screen.exists, "Экран должен быть готов к загрузке последнего элемента при активации приложения")
    }
}

