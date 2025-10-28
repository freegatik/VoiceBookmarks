//
//  DynamicFileCardTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Solovev on 09.05.2026.
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import SwiftUI
@testable import VoiceBookmarks

final class DynamicFileCardTests: XCTestCase {
    
    func testDynamicFileCard_Init_WithBookmark() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.jpg",
            contentType: .image,
            category: "Test",
            voiceNote: nil,
            fileUrl: "https://example.com/test.jpg",
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let view = DynamicFileCard(bookmark: bookmark)
        
        XCTAssertNotNil(view)
        XCTAssertEqual(bookmark.contentType.iconName, "photo", "Image должен иметь иконку photo")
        XCTAssertEqual(bookmark.contentType.iconSize, 52, "Image должен иметь размер иконки 52")
    }
    
    func testDynamicFileCard_DifferentFileNames() {
        let fileNames = ["test.jpg", "document.pdf", "video.mp4", "audio.mp3", "text.txt"]
        
        for fileName in fileNames {
            let bookmark = Bookmark(
                id: "test-\(fileName)",
                fileName: fileName,
                contentType: .file,
                category: "Test",
                voiceNote: nil,
                fileUrl: "https://example.com/\(fileName)",
                summary: nil,
                content: nil,
                contentHash: nil,
                timestamp: Date(),
                totalChunks: nil,
                distance: nil
            )
            
            let view = DynamicFileCard(bookmark: bookmark)
            XCTAssertNotNil(view)
        }
    }
    
    func testDynamicFileCard_DifferentContentTypes() {
        let contentTypes: [ContentType] = [.image, .video, .audio, .text, .file]
        let expectedIcons = ["photo", "video", "waveform", "doc.text", "doc"]
        let expectedSizes: [CGFloat] = [52, 60, 44, 32, 40]
        
        for (index, contentType) in contentTypes.enumerated() {
            let bookmark = Bookmark(
                id: "test-\(contentType)",
                fileName: "test.\(contentType)",
                contentType: contentType,
                category: "Test",
                voiceNote: nil,
                fileUrl: "https://example.com/test",
                summary: nil,
                content: nil,
                contentHash: nil,
                timestamp: Date(),
                totalChunks: nil,
                distance: nil
            )
            
            let view = DynamicFileCard(bookmark: bookmark)
            XCTAssertNotNil(view)
            
            XCTAssertEqual(bookmark.contentType.iconName, expectedIcons[index], "Тип \(contentType) должен иметь иконку \(expectedIcons[index])")
            XCTAssertEqual(bookmark.contentType.iconSize, expectedSizes[index], "Тип \(contentType) должен иметь размер \(expectedSizes[index])")
        }
    }
    
    func testDynamicFileCard_WithoutFileUrl() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.txt",
            contentType: .text,
            category: "Test",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: "Test content",
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let view = DynamicFileCard(bookmark: bookmark)
        
        XCTAssertNotNil(view)
    }
    
    func testDynamicFileCard_WithSummary() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.jpg",
            contentType: .image,
            category: "Test",
            voiceNote: nil,
            fileUrl: "https://example.com/test.jpg",
            summary: "Test summary",
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let view = DynamicFileCard(bookmark: bookmark)
        
        XCTAssertNotNil(view)
        XCTAssertEqual(bookmark.displayDescription, "Test summary", "displayDescription должен использовать summary")
        XCTAssertGreaterThan(bookmark.dynamicHeight, 80, "dynamicHeight должен быть больше базового размера при наличии description")
    }
    
    func testDynamicFileCard_WithVoiceNote() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.mp3",
            contentType: .audio,
            category: "Test",
            voiceNote: "Voice note text",
            fileUrl: "https://example.com/test.mp3",
            summary: "Summary text",
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let view = DynamicFileCard(bookmark: bookmark)
        
        XCTAssertNotNil(view)
        XCTAssertEqual(bookmark.displayDescription, "Voice note text", "displayDescription должен использовать voiceNote вместо summary")
        XCTAssertGreaterThan(bookmark.dynamicHeight, 80, "dynamicHeight должен быть больше при наличии voiceNote")
    }
    
    func testDynamicFileCard_DynamicHeight() {
        let bookmarkWithoutDesc = Bookmark(
            id: "test-1",
            fileName: "test.jpg",
            contentType: .image,
            category: "Test",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let bookmarkWithDesc = Bookmark(
            id: "test-2",
            fileName: "test.jpg",
            contentType: .image,
            category: "Test",
            voiceNote: "Voice note",
            fileUrl: nil,
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let view1 = DynamicFileCard(bookmark: bookmarkWithoutDesc)
        let view2 = DynamicFileCard(bookmark: bookmarkWithDesc)
        
        XCTAssertNotNil(view1)
        XCTAssertNotNil(view2)
        
        XCTAssertGreaterThan(bookmarkWithDesc.dynamicHeight, bookmarkWithoutDesc.dynamicHeight, "Высота с description должна быть больше")
    }
}

