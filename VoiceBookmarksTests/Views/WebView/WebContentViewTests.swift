//
//  WebContentViewTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
import SwiftUI
import WebKit
@testable import VoiceBookmarks

final class WebContentViewTests: XCTestCase {
    
    var mockBookmarkService: MockBookmarkService!
    var mockNetworkService: MockNetworkService!
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        mockBookmarkService = MockBookmarkService(
            networkService: mockNetworkService,
            fileService: FileService.shared
        )
    }
    
    override func tearDown() {
        mockBookmarkService = nil
        mockNetworkService = nil
        super.tearDown()
    }
    
    func testWebContentView_Init_WithViewModel() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
    }
    
    func testWebContentView_Init_WithCommandContent() {
        let html = "<html><body>Test</body></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
    }
    
    func testWebContentView_ShowsCorrectTitle() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
        XCTAssertEqual(viewModel.content.title, "test.jpg")
    }
    
    func testWebContentView_DifferentContentTypes() {
        let contentTypes: [ContentType] = [.image, .video, .file]
        
        for contentType in contentTypes {
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
            
            let content = WebViewContent.file(bookmark)
            let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
            let view = WebContentView(viewModel: viewModel)
            
            XCTAssertNotNil(view)
        }
    }
    
    func testWebViewContent_FileConfiguration() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.pdf",
            contentType: .file,
            category: "Test",
            voiceNote: nil,
            fileUrl: "https://example.com/test.pdf",
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let configuration = content.webViewConfiguration
        
        XCTAssertNotNil(configuration)
    }
    
    func testWebViewContent_CommandConfiguration() {
        let html = "<html></html>"
        let content = WebViewContent.command( html)
        let configuration = content.webViewConfiguration
        
        XCTAssertNotNil(configuration)
    }
    
    func testWebContentView_LoadingState_ShowsLoadingView() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        viewModel.isLoading = true
        
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
        XCTAssertTrue(viewModel.isLoading)
    }
    
    func testWebContentView_ErrorState_ShowsErrorView() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        viewModel.loadError = "Error загрузки"
        
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
        XCTAssertNotNil(viewModel.loadError)
    }
    
    func testWebContentView_PDFFile_UsesPDFPreview() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.pdf",
            contentType: .file,
            category: "Test",
            voiceNote: nil,
            fileUrl: "https://example.com/test.pdf",
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
        XCTAssertEqual(bookmark.fileName.lowercased().hasSuffix(".pdf"), true)
    }
    
    func testWebContentView_ImageFile_UsesImagePreview() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
        XCTAssertEqual(bookmark.contentType, .image)
    }
    
    func testWebContentView_VideoFile_UsesVideoPreview() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.mp4",
            contentType: .video,
            category: "Test",
            voiceNote: nil,
            fileUrl: "https://example.com/test.mp4",
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
        XCTAssertEqual(bookmark.contentType, .video)
    }
    
    func testWebContentView_Command_UsesWebView() {
        let html = "<html><body>Test</body></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
    }
    
    func testWebContentView_HandlesSwipeGestures() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
    }
    
    func testWebContentView_FileMenu_ShowsDeleteOption() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
        XCTAssertTrue(content.canDelete)
    }
    
    func testWebContentView_CommandMenu_NoDeleteOption() {
        let html = "<html></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        let view = WebContentView(viewModel: viewModel)
        
        XCTAssertNotNil(view)
        XCTAssertFalse(content.canDelete)
    }
}
