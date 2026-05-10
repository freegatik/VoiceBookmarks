//
//  ErrorStateViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import SwiftUI
@testable import VoiceBookmarks

final class ErrorStateViewTests: XCTestCase {
    
    func testErrorStateView_Init_WithMessage() {
        let view = ErrorStateView(message: "Test error", retryAction: nil)
        
        XCTAssertNotNil(view)
    }
    
    func testErrorStateView_DifferentMessages() {
        let messages = [
            "Error загрузки",
            "Не удалось подключиться",
            "Произошла ошибка",
            "Error сети"
        ]
        
        for message in messages {
            let view = ErrorStateView(message: message, retryAction: nil)
            XCTAssertNotNil(view)
        }
    }
    
    func testErrorStateView_EmptyMessage() {
        let view = ErrorStateView(message: "", retryAction: nil)
        
        XCTAssertNotNil(view)
    }
    
    func testErrorStateView_LongMessage() {
        let longMessage = "Очень длинное сообщение об ошибке, которое содержит много текста и должно корректно отображаться в интерфейсе приложения"
        let view = ErrorStateView(message: longMessage, retryAction: nil)
        
        XCTAssertNotNil(view)
    }
    
    func testErrorStateView_WithRetryAction() {
        let retryAction: () -> Void = { }
        let view = ErrorStateView(
            message: "Test error",
            retryAction: retryAction
        )
        
        XCTAssertNotNil(view)
        XCTAssertNotNil(view.retryAction)
    }
    
    func testErrorStateView_WithoutRetryAction() {
        let view = ErrorStateView(
            message: "Test error",
            retryAction: nil
        )
        
        XCTAssertNotNil(view)
        XCTAssertNil(view.retryAction)
    }
    
    func testErrorStateView_RetryAction_CallsCallback() {
        var retryCalled = false
        let retryAction: () -> Void = {
            retryCalled = true
        }
        let view = ErrorStateView(
            message: "Test error",
            retryAction: retryAction
        )
        
        XCTAssertNotNil(view)
        view.retryAction?()
        XCTAssertTrue(retryCalled, "Callback должен быть вызван")
    }
}
