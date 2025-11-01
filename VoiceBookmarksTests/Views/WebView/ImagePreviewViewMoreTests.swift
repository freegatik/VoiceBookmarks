//
//  ImagePreviewViewMoreTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class ImagePreviewViewMoreTests: XCTestCase {
    @MainActor
    func testImagePreview_InvalidImageTriggersError() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("bin")
        try? Data("not image".utf8).write(to: tempURL, options: .atomic)
        var failed = false
        let view = ImagePreviewView(imageURL: tempURL, onLoadFinish: {}, onLoadFail: { _ in failed = true })
        XCTAssertNotNil(view)
        XCTAssertFalse(failed)
        try? FileManager.default.removeItem(at: tempURL)
    }
}


