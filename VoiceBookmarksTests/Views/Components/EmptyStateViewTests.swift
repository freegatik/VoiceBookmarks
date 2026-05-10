//
//  EmptyStateViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import SwiftUI
@testable import VoiceBookmarks

final class EmptyStateViewTests: XCTestCase {
    
    func testEmptyStateView_Init_WithMessageAndIcon() {
        let view = EmptyStateView(
            message: "Test message",
            icon: "test.icon"
        )
        
        XCTAssertNotNil(view)
        XCTAssertEqual(view.message, "Test message")
        XCTAssertEqual(view.icon, "test.icon")
    }
    
    func testEmptyStateView_UsesCorrectParameters() {
        let message = "Files не найдены"
        let icon = "doc.badge.gearshape"
        
        let view = EmptyStateView(
            message: message,
            icon: icon
        )
        
        XCTAssertNotNil(view)
        XCTAssertEqual(view.message, message)
        XCTAssertEqual(view.icon, icon)
    }
    
    func testEmptyStateView_UsesDefaultIcon() {
        let view = EmptyStateView(message: "Test")
        
        XCTAssertNotNil(view)
        XCTAssertEqual(view.icon, "folder.badge.questionmark", "Должна использоваться дефолтная иконка")
    }
    
    func testEmptyStateView_DifferentMessages() {
        let messages = [
            "Files не найдены",
            "No folders",
            "Пусто",
            "Нет результатов"
        ]
        
        for message in messages {
            let view = EmptyStateView(
                message: message,
                icon: "doc"
            )
            XCTAssertNotNil(view)
        }
    }
    
    func testEmptyStateView_DifferentIcons() {
        let icons = [
            "doc.badge.gearshape",
            "folder",
            "tray",
            "doc.text"
        ]
        
        for icon in icons {
            let view = EmptyStateView(
                message: "Test",
                icon: icon
            )
            XCTAssertNotNil(view)
        }
    }
}
