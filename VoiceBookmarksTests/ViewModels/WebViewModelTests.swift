//
//  WebViewModelTests.swift
//  VoiceBookmarksTests
//
//  Created by Anton Soloviev on 09.05.2026.
//

import XCTest
@testable import VoiceBookmarks

final class WebViewModelTests: XCTestCase {
    
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
    
    func testWebViewModel_Init_WithFileContent() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        XCTAssertEqual(viewModel.content.title, "test.jpg")
        XCTAssertNotNil(viewModel.bookmark)
        XCTAssertEqual(viewModel.bookmark?.id, "test-id")
    }
    
    func testWebViewModel_Init_WithCommandContent() {
        let html = "<html><body>Test</body></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        XCTAssertEqual(viewModel.content.title, "Command result")
        XCTAssertNil(viewModel.bookmark)
    }
    
    func testWebViewModel_PrepareContent_ReturnsURLForFile() {
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
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://example.com/test.jpg")
    }
    
    func testWebViewModel_PrepareContent_CreatesHTMLFileForCommand() {
        let html = "<html><body>Test Command</body></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.pathExtension == "html")
        
        let fileExists = FileManager.default.fileExists(atPath: url?.path ?? "")
        XCTAssertTrue(fileExists)
    }
    
    func testWebViewModel_HandleShareAction_SetsItemsToShare() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.handleShareAction()
        
        XCTAssertTrue(viewModel.showShareSheet)
        XCTAssertFalse(viewModel.itemsToShare.isEmpty)
    }
    
    func testWebViewModel_HandleShareAction_ForFile_IncludesURL() {
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.handleShareAction()
        
        let hasURL = viewModel.itemsToShare.contains { $0 is URL }
        XCTAssertTrue(hasURL)
    }
    
    func testWebViewModel_HandleShareAction_ForCommand_IncludesHTML() {
        let html = "<html><body>Test</body></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.handleShareAction()
        
        let hasHTML = viewModel.itemsToShare.contains { $0 is String }
        XCTAssertTrue(hasHTML)
    }
    
    func testWebViewModel_HandleDeleteAction_ShowsConfirmation() {
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
        
        viewModel.handleDeleteAction()
        
        XCTAssertTrue(viewModel.showDeleteConfirmation)
    }
    
    func testWebViewModel_ConfirmDelete_CallsBookmarkService() async {
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
        
        await viewModel.confirmDelete()
        
        XCTAssertTrue(mockBookmarkService.deleteBookmarkCalled)
        XCTAssertEqual(mockBookmarkService.deletedBookmarkId, "test-id")
    }
    
    func testWebViewModel_ConfirmDelete_SetsShouldDismissOnSuccess() async {
        mockBookmarkService.deleteBookmarkShouldSucceed = true
        
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
        
        await viewModel.confirmDelete()
        
        XCTAssertTrue(viewModel.shouldDismiss)
        XCTAssertFalse(viewModel.showDeleteConfirmation)
    }
    
    func testWebViewModel_ConfirmDelete_SetsErrorOnFailure() async {
        mockBookmarkService.deleteBookmarkShouldSucceed = false
        
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
        
        await viewModel.confirmDelete()
        
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertFalse(viewModel.shouldDismiss)
    }
    
    func testWebViewContent_CanDelete_FileReturnsTrue() {
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
        
        let fileContent = WebViewContent.file(bookmark)
        XCTAssertTrue(fileContent.canDelete)
        
        let commandContent = WebViewContent.command( "<html></html>")
        XCTAssertFalse(commandContent.canDelete)
    }
    
    func testWebViewModel_LoadingDidFinish_SetsIsLoadingFalse() {
        let content = WebViewContent.command( "<html></html>")
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.isLoading = true
        viewModel.loadingDidFinish()
        
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testWebViewModel_LoadingDidFail_SetsError() {
        let content = WebViewContent.command( "<html></html>")
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let error = NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        viewModel.loadingDidFail(error: error)
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertEqual(viewModel.loadError, "Test error")
    }
    
    func testWebViewModel_PrepareFileContent_ImageWithoutFileUrl_CreatesHTMLFromContent() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.jpg",
            contentType: .image,
            category: "Test",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: "data:image/jpeg;base64,/9j/4AAQSkZJRg==",
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.pathExtension, "html")
        
        let fileExists = FileManager.default.fileExists(atPath: url?.path ?? "")
        XCTAssertTrue(fileExists)
    }
    
    func testWebViewModel_PrepareFileContent_ImageWithoutFileUrlOrContent_CreatesHTMLMessage() {
        let bookmark = Bookmark(
            id: "test-id",
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.pathExtension, "html")
        
        let fileExists = FileManager.default.fileExists(atPath: url?.path ?? "")
        XCTAssertTrue(fileExists)
    }
    
    func testWebViewModel_PrepareFileContent_FileWithEmptyFileUrl_CreatesErrorHTML() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.pdf",
            contentType: .file,
            category: "Test",
            voiceNote: nil,
            fileUrl: "",
            summary: nil,
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.pathExtension, "html")
        XCTAssertNotNil(viewModel.loadError)
        
        let fileExists = FileManager.default.fileExists(atPath: url?.path ?? "")
        XCTAssertTrue(fileExists)
    }
    
    func testWebViewModel_HandleSaveToFiles_ForFile_SetsUrlToSave() async throws {
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
        
        viewModel.handleSaveToFiles()
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertNotNil(viewModel.urlToSave)
        XCTAssertTrue(viewModel.showDocumentPicker)
    }
    
    func testWebViewModel_HandleSaveToFiles_ForCommand_CreatesHTMLFile() async throws {
        let html = "<html><body>Test</body></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.handleSaveToFiles()
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertNotNil(viewModel.urlToSave)
        XCTAssertTrue(viewModel.showDocumentPicker)
        
        if let url = viewModel.urlToSave {
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            XCTAssertTrue(fileExists)
        }
    }
    
    func testWebViewModel_HandleSaveToFiles_ForFileWithoutFileUrl_ShowsError() async throws {
        let bookmark = Bookmark(
            id: "test-id",
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
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.handleSaveToFiles()
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertNotNil(viewModel.loadError)
        XCTAssertNil(viewModel.urlToSave)
        XCTAssertFalse(viewModel.showDocumentPicker)
    }
    
    func testWebViewModel_HandleDeleteAction_ForCommand_DoesNotShowConfirmation() {
        let html = "<html></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.handleDeleteAction()
        
        XCTAssertFalse(viewModel.showDeleteConfirmation)
    }
    
    func testWebViewModel_ConfirmDelete_ForCommand_DoesNotDelete() async {
        let html = "<html></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        await viewModel.confirmDelete()
        
        XCTAssertFalse(mockBookmarkService.deleteBookmarkCalled)
    }
    
    func testWebViewModel_ConfirmDelete_WithoutBookmark_DoesNotDelete() async {
        let html = "<html></html>"
        let content = WebViewContent.command( html)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        viewModel.bookmark = nil
        
        await viewModel.confirmDelete()
        
        XCTAssertFalse(mockBookmarkService.deleteBookmarkCalled)
    }
    
    func testWebViewModel_PrepareFileContent_TextWithoutFileUrl_UsesContent() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.txt",
            contentType: .text,
            category: "Test",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: "Test content text",
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.pathExtension, "html")
    }
    
    func testWebViewModel_PrepareFileContent_TextWithEmptyFileUrl_UsesContent() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.txt",
            contentType: .text,
            category: "Test",
            voiceNote: nil,
            fileUrl: "",
            summary: nil,
            content: "Test content text",
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.pathExtension, "html")
    }
    
    func testWebViewModel_HandleShareAction_FileWithEmptyFileUrl_DoesNotAddURL() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.jpg",
            contentType: .image,
            category: "Test",
            voiceNote: nil,
            fileUrl: "",
            summary: "Test summary",
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.handleShareAction()
        
        XCTAssertTrue(viewModel.showShareSheet)
        let hasURL = viewModel.itemsToShare.contains { $0 is URL }
        XCTAssertFalse(hasURL)
        XCTAssertTrue(viewModel.itemsToShare.contains { ($0 as? String) == bookmark.fileName })
    }
    
    func testWebViewModel_HandleShareAction_FileWithSummary_AddsDescription() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.jpg",
            contentType: .image,
            category: "Test",
            voiceNote: nil,
            fileUrl: "https://example.com/test.jpg",
            summary: "Test summary description",
            content: nil,
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.handleShareAction()
        
        let hasDescription = viewModel.itemsToShare.contains { ($0 as? String) == "Test summary description" }
        XCTAssertTrue(hasDescription)
    }
    
    func testWebViewModel_HandleShareAction_FileWithoutSummary_DoesNotAddDescription() {
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
        
        viewModel.handleShareAction()
        
        XCTAssertEqual(viewModel.itemsToShare.count, 2)
    }
    
    func testWebViewModel_ConfirmDelete_SetsIsDeletingDuringDeletion() async {
        mockBookmarkService.deleteBookmarkShouldSucceed = true
        
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
        
        let deleteTask = Task {
            await viewModel.confirmDelete()
        }
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        await deleteTask.value
        
        XCTAssertFalse(viewModel.isDeleting)
    }
    
    func testWebViewModel_LoadingDidFail_SetsIsLoadingFalse() {
        let content = WebViewContent.command( "<html></html>")
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.isLoading = true
        let error = NSError(domain: "Test", code: -1)
        viewModel.loadingDidFail(error: error)
        
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testWebViewModel_CreateHTMLFile_HandlesWriteError() {
        let content = WebViewContent.command( "<html></html>")
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url)
    }
    
    func testWebViewModel_PrepareFileContent_HTMLFile_DetectsByExtension() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.html",
            contentType: .text,
            category: "Test",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: "<html><body>Test HTML</body></html>",
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url, "Должен создаться HTML файл")
        XCTAssertEqual(url?.pathExtension, "html", "Расширение должно быть html")
    }
    
    func testWebViewModel_PrepareFileContent_HTMLFile_DetectsByContent() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.txt",
            contentType: .text,
            category: "Test",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: "<!doctype html><html><body>Test HTML</body></html>",
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url, "Должен создаться HTML файл")
        XCTAssertEqual(url?.pathExtension, "html", "Расширение должно быть html")
    }
    
    func testWebViewModel_PrepareFileContent_HTMLFileWithURL_LoadsHTML() {
        let bookmark = Bookmark(
            id: "test-id",
            fileName: "test.html",
            contentType: .text,
            category: "Test",
            voiceNote: nil,
            fileUrl: nil,
            summary: nil,
            content: "https://example.com/page.html",
            contentHash: nil,
            timestamp: Date(),
            totalChunks: nil,
            distance: nil
        )
        
        let content = WebViewContent.file(bookmark)
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let url = viewModel.prepareContent()
        XCTAssertNotNil(url, "Должен создаться HTML файл с сообщением о загрузке")
    }
    
    func testWebViewModel_Cleanup_ResetsIsLoading() {
        let content = WebViewContent.command( "<html></html>")
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        viewModel.isLoading = true
        viewModel.cleanup()
        
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testWebViewModel_RequestHeaders_ReturnsHeadersForAPIDomain() {
        let content = WebViewContent.command( "<html></html>")
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        guard let apiBaseURL = URL(string: Constants.API.baseURL),
              let apiHost = apiBaseURL.host else {
            XCTFail("API baseURL должен быть валидным URL")
            return
        }
        
        let apiURL = URL(string: "\(Constants.API.baseURL)/test")!
        let headers = viewModel.requestHeaders(for: apiURL)
        
        if headers != nil {
            XCTAssertNotNil(headers?[Constants.API.Headers.userID], "Заголовки должны содержать userId для API домена")
        }
    }
    
    func testWebViewModel_RequestHeaders_ReturnsNilForNonAPIDomain() {
        let content = WebViewContent.command( "<html></html>")
        let viewModel = WebViewModel(content: content, bookmarkService: mockBookmarkService)
        
        let externalURL = URL(string: "https://example.com/file.jpg")!
        let headers = viewModel.requestHeaders(for: externalURL)
        
        XCTAssertNil(headers, "Заголовки не должны возвращаться для внешнего домена")
    }
}
