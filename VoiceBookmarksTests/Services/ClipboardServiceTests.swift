//
//  ClipboardServiceTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class ClipboardServiceTests: XCTestCase {
    
    var sut: ClipboardService!
    
    override func setUp() {
        super.setUp()
        sut = ClipboardService.shared
        sut.clearClipboard()
    }
    
    override func tearDown() {
        sut.clearClipboard()
        sut = nil
        super.tearDown()
    }
    
    func testClipboardService_Singleton_IsAccessible() {
        XCTAssertNotNil(ClipboardService.shared)
    }
    
    func testClipboardService_HasContent_ReturnsFalseWhenEmpty() {
        sut.clearClipboard()
        XCTAssertFalse(sut.hasContent())
    }
    
    func testClipboardService_GetContent_ReturnsNilWhenEmpty() {
        sut.clearClipboard()
        let content = sut.getClipboardContent()
        XCTAssertNil(content)
    }
    
    func testMockClipboardService_Works() {
        let mock = MockClipboardService()
        mock.mockContent = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        
        let content = mock.getClipboardContent()
        XCTAssertNotNil(content)
        XCTAssertEqual(content?.type, .text)
    }
    
    func testClipboardContent_TextType_IsCorrect() {
        let content = ClipboardContent(type: .text, text: "test", url: nil, image: nil)
        XCTAssertEqual(content.type, .text)
        XCTAssertNotNil(content.text)
    }
    
    func testClipboardContent_URLType_IsCorrect() {
        let testURL = URL(string: "https://example.com")
        let content = ClipboardContent(type: .url, text: nil, url: testURL, image: nil)
        XCTAssertEqual(content.type, .url)
        XCTAssertNotNil(content.url)
    }
    
    func testClipboardContent_ImageType_IsCorrect() {
        let testImage = UIImage()
        let content = ClipboardContent(type: .image, text: nil, url: nil, image: testImage)
        XCTAssertEqual(content.type, .image)
        XCTAssertNotNil(content.image)
    }
    
    func testClipboardService_ClearClipboard_DoesNotCrash() {
        XCTAssertNoThrow(sut.clearClipboard())
    }
    
    func testMockClipboardService_ClearClipboard_SetsFlag() {
        let mock = MockClipboardService()
        mock.clearClipboard()
        XCTAssertTrue(mock.clearClipboardCalled)
    }
    
    func testMockClipboardService_HasContent_ReturnsValue() {
        let mock = MockClipboardService()
        mock.hasContentValue = true
        XCTAssertTrue(mock.hasContent())
    }
}
