//
//  MockClipboardService.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import Foundation
@testable import VoiceBookmarks

class MockClipboardService: ClipboardServiceProtocol {
    
    var mockContent: ClipboardContent?
    var hasContentValue: Bool = false
    var hasContentResult: Bool = false

    var clearClipboardCalled = false
    
    func getClipboardContent() -> ClipboardContent? {
        return mockContent
    }

    func getClipboardContentAsync() async -> ClipboardContent? {
        mockContent
    }
    
    func hasContent() -> Bool {
        return hasContentResult || hasContentValue || mockContent != nil
    }
    
    func clearClipboard() {
        clearClipboardCalled = true
        mockContent = nil
        hasContentValue = false
        hasContentResult = false
    }
}
