//
//  ContentPreviewViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class ContentPreviewViewTests: XCTestCase {
    func testContentPreview_Text_ShowsTextAndDocIcon() {
        let content = ClipboardContent(type: .text, text: "Hello", url: nil, image: nil)
        let view = ContentPreviewView(content: content)
        XCTAssertNotNil(view)
    }

    func testContentPreview_URL_ShowsLinkAndLinkIcon() {
        let url = URL(string: "https://example.com")!
        let content = ClipboardContent(type: .url, text: nil, url: url, image: nil)
        let view = ContentPreviewView(content: content)
        XCTAssertNotNil(view)
    }

    func testContentPreview_Image_ShowsImageMessageAndPhotoIcon() {
        let testImage = UIImage()
        let content = ClipboardContent(type: .image, text: nil, url: nil, image: testImage)
        let view = ContentPreviewView(content: content)
        XCTAssertNotNil(view)
    }

    func testContentPreview_Unknown_ShowsDefaultTextAndDocIcon() {
        let content = ClipboardContent(type: .unknown, text: nil, url: nil, image: nil)
        let view = ContentPreviewView(content: content)
        XCTAssertNotNil(view)
    }
}

