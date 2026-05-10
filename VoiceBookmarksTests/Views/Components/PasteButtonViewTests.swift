//
//  PasteButtonViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class PasteButtonViewTests: XCTestCase {
    func testPasteButton_CallsActionOnTap() {
        var called = false
        let view = PasteButtonView {
            called = true
        }
        XCTAssertNotNil(view)
        view.action()
        XCTAssertTrue(called)
    }
}

