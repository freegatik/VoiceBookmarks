//
//  TranscriptionViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import SwiftUI
@testable import VoiceBookmarks

final class TranscriptionViewTests: XCTestCase {
    
    func testTranscriptionView_Init_WithText() {
        let view = TranscriptionView(text: "Test transcription")
        
        XCTAssertNotNil(view)
        XCTAssertEqual(view.text, "Test transcription")
    }
    
    func testTranscriptionView_EmptyText() {
        let view = TranscriptionView(text: "")
        
        XCTAssertNotNil(view)
        XCTAssertEqual(view.text, "", "Текст должен быть пустым")
    }
    
    func testTranscriptionView_LongText() {
        let longText = "Очень длинный текст транскрипции, который содержит много слов и должен корректно отображаться в интерфейсе приложения VoiceBookmarks"
        let view = TranscriptionView(text: longText)
        
        XCTAssertNotNil(view)
    }
    
    func testTranscriptionView_RussianText() {
        let russianText = "Привет, это тестовая транскрипция на русском языке"
        let view = TranscriptionView(text: russianText)
        
        XCTAssertNotNil(view)
    }
    
    func testTranscriptionView_SpecialCharacters() {
        let specialText = "Текст с \"кавычками\", (скобками) и - дефисами"
        let view = TranscriptionView(text: specialText)
        
        XCTAssertNotNil(view)
    }
    
    func testTranscriptionView_WithNumbers() {
        let textWithNumbers = "Найти файл номер 123 в папке 456"
        let view = TranscriptionView(text: textWithNumbers)
        
        XCTAssertNotNil(view)
        XCTAssertEqual(view.text, textWithNumbers)
    }
    
    func testTranscriptionView_OnTap_CallsCallback() {
        var tapCalled = false
        let view = TranscriptionView(
            text: "Test",
            onTap: {
                tapCalled = true
            }
        )
        
        XCTAssertNotNil(view)
        XCTAssertNotNil(view.onTap)
        view.onTap?()
        XCTAssertTrue(tapCalled, "onTap callback должен быть вызван")
    }
    
    func testTranscriptionView_WithoutOnTap() {
        let view = TranscriptionView(text: "Test", onTap: nil)
        
        XCTAssertNotNil(view)
        XCTAssertNil(view.onTap)
    }
}
