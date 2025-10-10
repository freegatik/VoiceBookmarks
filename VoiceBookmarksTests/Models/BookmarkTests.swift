//
//  BookmarkTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class BookmarkTests: XCTestCase {
    
    func testBookmark_DecodesFromJSON_Successfully() {
        let json = """
        {
            "id": "test-id-123",
            "fileName": "test.jpg",
            "contentType": "image",
            "category": "Tasks",
            "voiceNote": "Test voice note",
            "fileUrl": "https://example.com/test.jpg",
            "summary": "Test summary",
            "content": "Test content",
            "timestamp": "2025-10-28T10:00:00Z",
            "totalChunks": 5,
            "distance": 0.45
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let bookmark = try? decoder.decode(Bookmark.self, from: json)
        
        XCTAssertNotNil(bookmark)
        XCTAssertEqual(bookmark?.id, "test-id-123")
        XCTAssertEqual(bookmark?.fileName, "test.jpg")
        XCTAssertEqual(bookmark?.contentType, .image)
    }
    
    func testContentType_Audio_HasCorrectIconSize() {
        XCTAssertEqual(ContentType.audio.iconSize, 44)
    }
    
    func testContentType_Video_HasCorrectIconSize() {
        XCTAssertEqual(ContentType.video.iconSize, 60)
    }
    
    func testBookmark_DisplayDescription_ReturnsVoiceNote_WhenPresent() {
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.txt",
            contentType: .text,
            category: "Tasks",
            voiceNote: "Voice note text",
            fileUrl: nil,
            summary: "Summary text",
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        XCTAssertEqual(bookmark.displayDescription, "Voice note text")
    }
    
    func testBookmark_DisplayDescription_ReturnsSummary_WhenNoVoiceNote() {
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.txt",
            contentType: .text,
            category: "Tasks",
            voiceNote: nil,
            fileUrl: nil,
            summary: "Summary text",
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        XCTAssertEqual(bookmark.displayDescription, "Summary text")
    }
    
    func testBookmark_DynamicHeight_CalculatesCorrectly() {
        let bookmark = Bookmark(
            id: "1",
            fileName: "test.mp4",
            contentType: .video,
            category: "Tasks",
            voiceNote: "Test",
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let expectedHeight: CGFloat = 80 + ContentType.video.iconSize + 40
        XCTAssertEqual(bookmark.dynamicHeight, expectedHeight)
    }
    
    func testBookmark_DecodesISODate_Successfully() {
        let json = """
        {
            "id": "1",
            "fileName": "test.txt",
            "contentType": "text",
            "category": "Tasks",
            "timestamp": "2025-10-28T10:30:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let bookmark = try? decoder.decode(Bookmark.self, from: json)
        
        XCTAssertNotNil(bookmark)
        XCTAssertNotNil(bookmark?.timestamp)
    }
    
    
    func testContentType_AllCases_HaveIcons() {
        let types: [ContentType] = [.text, .audio, .video, .image, .file]
        
        for type in types {
            XCTAssertFalse(type.iconName.isEmpty)
        }
    }
    
    func testContentType_Text_HasCorrectIconSize() {
        XCTAssertEqual(ContentType.text.iconSize, 32)
    }
    
    func testContentType_Image_HasCorrectIconSize() {
        XCTAssertEqual(ContentType.image.iconSize, 52)
    }
    
    func testContentType_File_HasCorrectIconSize() {
        XCTAssertEqual(ContentType.file.iconSize, 40)
    }
    
    func testContentType_AllCases_HaveCorrectIconNames() {
        XCTAssertEqual(ContentType.text.iconName, "doc.text")
        XCTAssertEqual(ContentType.audio.iconName, "waveform")
        XCTAssertEqual(ContentType.video.iconName, "video")
        XCTAssertEqual(ContentType.image.iconName, "photo")
        XCTAssertEqual(ContentType.file.iconName, "doc")
    }
    
    func testBookmark_DynamicHeight_DiffersByContentType() {
        let videoBookmark = Bookmark(
            id: "1",
            fileName: "test.mp4",
            contentType: .video,
            category: "Tasks",
            voiceNote: "Test",
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let textBookmark = Bookmark(
            id: "2",
            fileName: "test.txt",
            contentType: .text,
            category: "Tasks",
            voiceNote: "Test",
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        XCTAssertGreaterThan(videoBookmark.dynamicHeight, textBookmark.dynamicHeight)
    }
}
